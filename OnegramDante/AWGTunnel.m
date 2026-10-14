#import "AWGTunnel.h"
#import "AWGConfig.h"
#import "AWGHandshake.h"
#import "AWGCrypto.h"
#import "AWGIPStack.h"
#import "monocypher.h"
#import "OGDanteSupport.h"
#import "OGDanteSOCKS.h"
#import "OGDanteSocket.h"

#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

static BOOL awgReadFull(int fd, uint8_t *buf, size_t len);
static BOOL awgWriteFull(int fd, const uint8_t *buf, size_t len);

static const size_t kWGTagLen = 16;

static const NSTimeInterval kAWGClientDrainTimeout = 180.0;

volatile uint32_t gAWGTxSent = 0, gAWGTxRetried = 0, gAWGTxDropped = 0;

static const NSUInteger kAWGSendBacklogCap = 262144;

int awg_grow_sockbuf(int fd, int opt, int want)
{
    for (int size = want; size >= 65536; size /= 2) {
        if (setsockopt(fd, SOL_SOCKET, opt, &size, sizeof(size)) == 0) {
            int got = 0; socklen_t len = sizeof(got);
            if (getsockopt(fd, SOL_SOCKET, opt, &got, &len) == 0) return got;
            return size;
        }
    }
    return 0;
}

static NSError *AWGTunnelMakeError(NSInteger code, NSString *description) {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(description ? description : @"")
                                                     forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"AWGTunnel" code:code userInfo:info];
}

@interface AWGTunnel () {
    volatile AWGTunnelState _state;
    AWGConfig *_config;
    AWGHandshake *_handshake;
    AWGHandshake *_previousHandshake;
    NSTimeInterval _previousHandshakeRetiredAt;
    AWGIPStack *_ipStack;
    int _udpFd;
    uint16_t _socksPort;
    int _socksListenFd;
    NSThread *_readThread;
    volatile int _utunFd;
    NSThread *_socksThread;
    volatile BOOL _running;
    volatile BOOL _stopping;
    NSDate *_handshakeDate;
    uint64_t _bytesSent;
    uint64_t _bytesReceived;
    uint64_t _sendCounter;
    uint64_t _recvCounter;
    uint64_t _maxRecvCounter;
    uint64_t _recvBitmap;
    BOOL _recvCounterInit;
    NSRecursiveLock *_writeLock;
    NSMutableDictionary *_socksClients;
    volatile BOOL _awakeTimerActive;
    volatile BOOL _readLoopExited;
    volatile BOOL _socksLoopExited;
    volatile NSTimeInterval _lastRxAt;
    volatile NSTimeInterval _lastTxAt;
}
@end

@implementation AWGTunnel

- (void)resetCounters {
    _sendCounter = 0;
    _recvCounter = 0;
    _maxRecvCounter = 0;
    _recvBitmap = 0;
    _recvCounterInit = NO;
}

- (instancetype)initWithConfig:(AWGConfig *)config {
    self = [super init];
    if (self) {
        _config = [config retain];
        _startsSOCKSListener = YES;
        _utunFd = -1;
        _handshake = [[AWGHandshake alloc] initWithConfig:config];
        _udpFd = -1;
        _socksListenFd = -1;
        _state = AWGTunnelStateIdle;
        _writeLock = [[NSRecursiveLock alloc] init];
        _socksClients = [[NSMutableDictionary alloc] init];
        [self resetCounters];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    [_config release];
    [_handshake release];
    [_previousHandshake release];
    [_ipStack release];
    [_readThread release];
    [_socksThread release];
    [_handshakeDate release];
    [_writeLock release];
    [_socksClients release];
    [super dealloc];
}


- (BOOL)startWithError:(NSError **)error {
    if (_state == AWGTunnelStateConnecting || _state == AWGTunnelStateConnected) {
        return YES;
    }
    _stopping = NO;
    [_handshake reset];
    _state = AWGTunnelStateConnecting;
    [self notifyState];

    NSError *localError = nil;
    DLog(@"[AWG] connecting to %@ (%@)", _config.peerEndpoint, _config.label);
    BOOL ok = [self setupUDPSocket:&localError];
    if (!ok) DLog(@"[AWG] socket setup failed: %@", [localError localizedDescription]);
    if (ok) {
        ok = [self performHandshakeWithError:&localError];
        if (!ok) {
            DLog(@"[AWG] handshake failed on %@: %@", _config.peerEndpoint, [localError localizedDescription]);
            [_handshake reset];
            if ([_config.preferredPorts count] > 1) {
                NSArray *parts = [_config.peerEndpoint componentsSeparatedByString:@":"];
                NSString *base = [parts count] > 0 ? [parts objectAtIndex:0] : _config.peerEndpoint;
                NSNumber *port = [_config.preferredPorts objectAtIndex:DanteRandomUniform((uint32_t)[_config.preferredPorts count])];
                _config.peerEndpoint = [NSString stringWithFormat:@"%@:%@", base, port];
                DLog(@"[AWG] retrying on %@", _config.peerEndpoint);
                if (_udpFd >= 0) { close(_udpFd); _udpFd = -1; }
                if ([self setupUDPSocket:&localError]) ok = [self performHandshakeWithError:&localError];
                if (!ok) DLog(@"[AWG] retry failed: %@", [localError localizedDescription]);
            }
        }
    }
    if (ok) {
        [_ipStack release];
        _ipStack = [[AWGIPStack alloc] initWithTunnel:self
                                            localIPv4:_config.ipv4Address
                                            localIPv6:_config.ipv6Address];
        for (NSString *raw in [_config.dnsServers componentsSeparatedByString:@","]) {
            NSString *candidate = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            struct in_addr probe;
            if ([candidate length] && inet_pton(AF_INET, [candidate UTF8String], &probe) == 1) {
                _ipStack.dnsServerIPv4 = candidate;
                break;
            }
        }
        _ipStack.tunnelMTU = _config.mtu >= 576 && _config.mtu <= 1500 ? _config.mtu : 1280;
        DLog(@"[AWG] tunnel DNS server: %@, MTU %lu", _ipStack.dnsServerIPv4, (unsigned long)_ipStack.tunnelMTU);
        if (_startsSOCKSListener) ok = [self startSOCKS5ProxyWithError:&localError];
    }
    if (ok) {
        [_writeLock lock];
        _state = AWGTunnelStateConnected;
        [_handshakeDate release];
        _handshakeDate = [[NSDate date] retain];
        [_writeLock unlock];
        [self notifyState];
    } else {
        _state = AWGTunnelStateFailed;
        [self notifyState];
        if (error) *error = localError;
    }
    return ok;
}

- (void)startAwakeTimer {
    _awakeTimerActive = _keepRadioAwake ? YES : NO;
}

- (void)stopAwakeTimer {
    _awakeTimerActive = NO;
}

- (void)stop {
    [self stopAwakeTimer];
    _stopping = YES;
    _running = NO;
    @synchronized(_socksClients) {
        for (NSNumber *fd in [_socksClients allValues]) shutdown([fd intValue], SHUT_RDWR);
    }

    int udpFd = _udpFd;
    int socksFd = _socksListenFd;
    if (udpFd >= 0) shutdown(udpFd, SHUT_RDWR);
    if (socksFd >= 0) shutdown(socksFd, SHUT_RDWR);

    NSThread *current = [NSThread currentThread];
    for (int i = 0; i < 250; i++) {
        BOOL readDone = !_readThread || _readThread == current || _readLoopExited;
        BOOL socksDone = !_socksThread || _socksThread == current || _socksLoopExited;
        if (readDone && socksDone) break;
        usleep(10000);
    }

    [_writeLock lock];
    if (udpFd >= 0) close(udpFd);
    if (socksFd >= 0) close(socksFd);
    _udpFd = -1;
    _socksListenFd = -1;
    [_writeLock unlock];

    [_readThread release];
    _readThread = nil;
    [_socksThread release];
    _socksThread = nil;
    _state = AWGTunnelStateIdle;
    [self notifyState];
}

- (void)rotateKeys {
    [_handshake reset];
    [self resetCounters];
    [self performHandshakeWithError:NULL];
}

- (NSTimeInterval)lastDataAt {
    return _lastRxAt;
}

- (NSTimeInterval)handshakeAge {
    [_writeLock lock];
    NSTimeInterval age = _handshakeDate ? -[_handshakeDate timeIntervalSinceNow] : 0;
    [_writeLock unlock];
    return age;
}


- (BOOL)setupUDPSocket:(NSError **)error {
    NSString *endpoint = _config.peerEndpoint;
    if (!endpoint) {
        if (error) *error = AWGTunnelMakeError(1, @"No endpoint configured");
        return NO;
    }

    NSString *host = nil;
    NSString *portStr = nil;
    if ([endpoint hasPrefix:@"["]) {
        NSRange closeBracket = [endpoint rangeOfString:@"]:"];
        if (closeBracket.location != NSNotFound) {
            host = [endpoint substringWithRange:NSMakeRange(1, closeBracket.location - 1)];
            portStr = [endpoint substringFromIndex:closeBracket.location + 2];
        }
    } else {
        NSRange colon = [endpoint rangeOfString:@":" options:NSBackwardsSearch];
        if (colon.location != NSNotFound) {
            host = [endpoint substringToIndex:colon.location];
            portStr = [endpoint substringFromIndex:colon.location + 1];
        }
    }
    if (!host || !portStr) {
        if (error) *error = AWGTunnelMakeError(2, @"Bad endpoint format");
        return NO;
    }

    struct addrinfo hints, *res = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;

    int rc = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res);
    if (rc != 0 || !res) {
        if (error) *error = AWGTunnelMakeError(3, [NSString stringWithFormat:@"DNS failed: %s", gai_strerror(rc)]);
        return NO;
    }

    _udpFd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (_udpFd < 0) {
        freeaddrinfo(res);
        if (error) *error = AWGTunnelMakeError(4, @"socket() failed");
        return NO;
    }

    int flags = fcntl(_udpFd, F_GETFL, 0);
    fcntl(_udpFd, F_SETFL, flags | O_NONBLOCK);

    int rcvbuf = awg_grow_sockbuf(_udpFd, SO_RCVBUF, 2097152);
    int sndbuf = awg_grow_sockbuf(_udpFd, SO_SNDBUF, 2097152);
    DLog(@"[AWG] буфер сокета: приём %d, отправка %d", rcvbuf, sndbuf);

    if (connect(_udpFd, res->ai_addr, res->ai_addrlen) != 0) {
        DLog(@"[AWG] UDP connect returned %d (%s)", errno, strerror(errno));
    }
    freeaddrinfo(res);
    return YES;
}


- (BOOL)performHandshakeWithError:(NSError **)error {
    return [self performHandshake:_handshake error:error];
}

- (BOOL)performHandshake:(AWGHandshake *)handshake error:(NSError **)error {
    NSArray *datagrams = [handshake buildInitiationDatagrams];
    if (datagrams.count == 0) {
        if (error) *error = AWGTunnelMakeError(5, @"Failed to build initiation");
        return NO;
    }

    NSUInteger idx = 0;
    for (NSData *packet in datagrams) {
        if (OGDanteSocketSend(_udpFd, packet.bytes, packet.length) < 0) {
            if (error) *error = AWGTunnelMakeError(6, [NSString stringWithFormat:@"send() failed: %s", strerror(errno)]);
            return NO;
        }
        _bytesSent += packet.length;
        idx++;

        if (idx < datagrams.count) usleep(2000);
    }
    DLog(@"[AWG] sent %lu handshake datagrams (%lu junk/signature + initiation)",
         (unsigned long)datagrams.count, (unsigned long)(datagrams.count - 1));

    uint8_t buf[4096];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
    while ([deadline timeIntervalSinceNow] > 0 && !_stopping && _udpFd >= 0) {
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(_udpFd, &fds);
        struct timeval tv = {0, 200000};
        int rc = select(_udpFd + 1, &fds, NULL, NULL, &tv);
        if (rc <= 0) continue;

        ssize_t n = recv(_udpFd, buf, sizeof(buf), 0);
        if (n <= 0) continue;
        _bytesReceived += n;

        NSData *packet = [NSData dataWithBytes:buf length:(NSUInteger)n];
        NSError *attemptError = nil;
        if ([handshake processResponse:packet error:&attemptError]) {
            if (handshake == _handshake) {
                [_writeLock lock];
                [_handshakeDate release];
                _handshakeDate = [[NSDate date] retain];
                [self resetCounters];
                [_writeLock unlock];
                if (!_readThread) [self startReadThread];
            }
            return YES;
        }

        [self handleIncomingPacket:packet];
        [_ipStack flushPendingWork];
    }

    if (error) *error = AWGTunnelMakeError(7, @"Handshake timeout");
    return NO;
}


- (void)startReadThread {
    _running = YES;
    _readLoopExited = NO;
    if (_readThread) {
        [_readThread release];
        _readThread = nil;
    }
    _readThread = [[NSThread alloc] initWithTarget:self selector:@selector(readLoop) object:nil];
    [_readThread setStackSize:256 * 1024];
    [_readThread start];
    [self startAwakeTimer];
}

static const NSTimeInterval kAWGRekeyAfterSeconds = 110.0;

- (BOOL)rekeyInline {
    NSError *err = nil;
    DLog(@"[AWG] session is %.0fs old — rekeying", self.handshakeAge);

    AWGHandshake *next = [[AWGHandshake alloc] initWithConfig:_config];
    if ([self performHandshake:next error:&err]) {
        [_writeLock lock];
        [_previousHandshake release];
        _previousHandshake = _handshake;
        _previousHandshakeRetiredAt = [NSDate timeIntervalSinceReferenceDate];
        _handshake = next;
        [_handshakeDate release];
        _handshakeDate = [[NSDate date] retain];
        [self resetCounters];
        [self encryptAndSendLocked:[NSData data]];
        [_writeLock unlock];
        DLog(@"[AWG] rekeyed (confirmed with keepalive, retaining previous session for 30s grace period)");
        return YES;
    }
    [next release];
    DLog(@"[AWG] rekey failed, keeping the current session: %@", [err localizedDescription]);
    return NO;
}

@synthesize utunFd = _utunFd;

- (void)setUtunFd:(int)fd { _utunFd = fd; }
- (int)utunFd { return _utunFd; }

- (void)drainUtunLocked:(int)fd {
    uint8_t pkt[4096];
    for (int p = 0; p < 32; p++) {
        ssize_t n = read(fd, pkt, sizeof(pkt));
        if (n <= 0) break;
        if (n <= 4 || (pkt[4] >> 4) != 4) continue;
        [self encryptAndSendLocked:pkt + 4 length:(size_t)n - 4];
    }
}

- (void)readLoop {
    uint8_t buf[4096];
    NSUInteger rekeyFailures = 0;
    NSTimeInterval nextRekeyAt = 0;
    NSTimeInterval nextAwakeAt = 0;
    while (_running) {
        NSAutoreleasePool *iterationPool = [[NSAutoreleasePool alloc] init];
        int udpFd = _udpFd;
        if (!_running || udpFd < 0) {
            [iterationPool drain];
            break;
        }

        NSTimeInterval nowTI = [NSDate timeIntervalSinceReferenceDate];
        const NSTimeInterval kAwakeInterval = 0.05;
        if (_awakeTimerActive && nowTI >= nextAwakeAt) {
            nextAwakeAt = nowTI + kAwakeInterval;
            if (nowTI - _lastTxAt >= kAwakeInterval) {
                [_writeLock lock];
                [self encryptAndSendLocked:[NSData data]];
                [_writeLock unlock];
            }
        }
        if (_state == AWGTunnelStateConnected && nowTI - _lastTxAt >= 25.0) {
            [_writeLock lock];
            [self encryptAndSendLocked:[NSData data]];
            [_writeLock unlock];
        }
        if (_handshakeDate && self.handshakeAge >= kAWGRekeyAfterSeconds && nowTI >= nextRekeyAt) {
            if ([self rekeyInline]) {
                rekeyFailures = 0;
                nextRekeyAt = 0;
            } else {
                ++rekeyFailures;
                nextRekeyAt = nowTI + MIN(60.0, 2.0 * (1 << MIN(rekeyFailures, 5)));
                if (rekeyFailures == 3) {
                    DLog(@"[AWG] giving up on this endpoint after 3 failed rekeys");
                    self->_state = AWGTunnelStateReconnecting;
                    [self notifyState];
                }
            }
        }

        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(udpFd, &fds);
        int utun = _utunFd;
        int maxFd = udpFd;
        if (utun >= 0) {
            FD_SET(utun, &fds);
            if (utun > maxFd) maxFd = utun;
        }
        struct timeval tv = {0, 20000};
        int rc = select(maxFd + 1, &fds, NULL, NULL, &tv);
        [_ipStack flushPendingWork];
        if (!_running) {
            [iterationPool drain];
            break;
        }
        if (rc <= 0) {
            [iterationPool drain];
            continue;
        }
        if (utun >= 0 && FD_ISSET(utun, &fds)) {
            [_writeLock lock];
            [self drainUtunLocked:utun];
            [_writeLock unlock];
        }
        if (!FD_ISSET(udpFd, &fds)) {
            [iterationPool drain];
            continue;
        }

        for (;;) {
            int count = 0;
            for (int p = 0; p < 128 && _running; p++) {
                ssize_t n = recv(udpFd, buf, sizeof(buf), 0);
                if (n <= 0) {
                    count = -1;
                    break;
                }
                count++;
                _bytesReceived += n;
                [self handleIncomingBytes:buf length:(size_t)n];
            }
            if (count < 128) break;
        }
        [iterationPool drain];
    }
    _readLoopExited = YES;
}

static void awgRxStat(int reason) {
    static uint32_t stats[6];
    static NSTimeInterval last;
    @synchronized ([AWGTunnel class]) {
        stats[reason]++;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - last >= 5.0) {
            last = now;
            DLog(@"[AWG rx] ok %u, до ключей %u, не транспорт %u, старый счётчик %u, не расшифр. %u, keepalive %u",
                 stats[0], stats[1], stats[2], stats[3], stats[4], stats[5]);
            memset(stats, 0, sizeof(stats));
        }
    }
}

- (void)handleIncomingBytes:(const uint8_t *)bytes length:(size_t)length {
    if (!_handshake.isEstablished) { awgRxStat(1); return; }

    uint64_t counter = 0;
    AWGHandshake *sessionHs = _handshake;
    BOOL isPreviousSession = NO;
    NSUInteger offset = [sessionHs transportPayloadOffsetForBytes:bytes length:length counter:&counter];
    if (offset == NSNotFound && _previousHandshake) {
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - _previousHandshakeRetiredAt < 30.0) {
            offset = [_previousHandshake transportPayloadOffsetForBytes:bytes length:length counter:&counter];
            if (offset != NSNotFound) {
                sessionHs = _previousHandshake;
                isPreviousSession = YES;
            }
        } else {
            [_previousHandshake release];
            _previousHandshake = nil;
        }
    }

    if (offset == NSNotFound) {
        awgRxStat(2);
        static NSTimeInterval lastDump;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (length >= 8 && now - lastDump > 5) {
            lastDump = now;
            DLog(@"[AWG rx] не транспорт: %lu байт, тип %u, получатель %u, наш индекс %u",
                 (unsigned long)length, (unsigned)bytes[0],
                 (unsigned)(bytes[4] | (bytes[5] << 8) | (bytes[6] << 16) | ((uint32_t)bytes[7] << 24)),
                 (unsigned)_handshake.localIndex);
        }
        return;
    }

    if (!isPreviousSession && _recvCounterInit) {
        if (counter > _maxRecvCounter) {

        } else {
            uint64_t diff = _maxRecvCounter - counter;
            if (diff >= 64) {
                awgRxStat(3);
                return;
            }
            if (_recvBitmap & (1ULL << diff)) {
                awgRxStat(3);
                return;
            }
        }
    }

    size_t cipherLen = length - offset;
    if (cipherLen < kWGTagLen) return;
    size_t plainLen = cipherLen - kWGTagLen;

    const uint8_t *cipher = bytes + offset;
    uint8_t plainBuf[2048];
    uint8_t *plainOut = (plainLen <= sizeof(plainBuf)) ? plainBuf : (uint8_t *)malloc(plainLen);

    uint8_t nonce[12];
    [AWGHandshake transportNonce:nonce forCounter:counter];

    crypto_aead_ctx ctx;
    crypto_aead_init_ietf(&ctx, [sessionHs.receivingKey bytes], nonce);
    int rc = crypto_aead_read(&ctx, plainOut, cipher + plainLen,
                              NULL, 0, cipher, plainLen);
    crypto_wipe(&ctx, sizeof(ctx));
    if (rc != 0) {
        if (plainOut != plainBuf) free(plainOut);
        awgRxStat(4);
        return;
    }

    if (!isPreviousSession) {
        if (!_recvCounterInit) {
            _recvCounterInit = YES;
            _maxRecvCounter = counter;
            _recvBitmap = 1ULL;
        } else if (counter > _maxRecvCounter) {
            uint64_t shift = counter - _maxRecvCounter;
            if (shift < 64) {
                _recvBitmap = (_recvBitmap << shift) | 1ULL;
            } else {
                _recvBitmap = 1ULL;
            }
            _maxRecvCounter = counter;
        } else {
            uint64_t diff = _maxRecvCounter - counter;
            _recvBitmap |= (1ULL << diff);
        }
    }

    if (plainLen == 0) {
        if (plainOut != plainBuf) free(plainOut);
        awgRxStat(5);
        return;
    }
    awgRxStat(0);
    _lastRxAt = [NSDate timeIntervalSinceReferenceDate];

    id<AWGRawPacketDelegate> rawDelegate = self.rawPacketDelegate;
    if (rawDelegate && ![_ipStack claimsIncomingPacket:plainOut length:plainLen]) {
        [rawDelegate awgDidReceiveRawPacket:plainOut length:plainLen];
        if (plainOut != plainBuf) free(plainOut);
        return;
    }

    [_ipStack handleIPPacketBytes:plainOut length:plainLen];
    if (plainOut != plainBuf) free(plainOut);
}

- (void)handleIncomingPacket:(NSData *)packet {
    [self handleIncomingBytes:packet.bytes length:packet.length];
}

- (void)sendTunnelPacketBytes:(const uint8_t *)bytes length:(size_t)length {
    [_writeLock lock];
    [self encryptAndSendLocked:bytes length:length];
    [_writeLock unlock];
}

- (void)sendTunnelPacket:(NSData *)packet {
    [self sendTunnelPacketBytes:packet.bytes length:packet.length];
}

- (void)sendRawIPPacket:(const uint8_t *)bytes length:(size_t)length {
    [_writeLock lock];
    [self encryptAndSendLocked:bytes length:length];
    [_writeLock unlock];
}

- (void)sendRawIPPackets:(const AWGRawPacket *)packets count:(size_t)count {
    if (count == 0) return;
    [_writeLock lock];
    for (size_t i = 0; i < count; i++) {
        [self encryptAndSendLocked:packets[i].bytes length:packets[i].length];
    }
    [_writeLock unlock];
}

- (void)bindToInterfaceIndex:(unsigned)index {
    [_writeLock lock];
    if (_udpFd >= 0 && index != 0) {
        int idx = (int)index;
        if (setsockopt(_udpFd, IPPROTO_IP, 25, &idx, sizeof(idx)) != 0) {
            DLog(@"[AWG] IP_BOUND_IF %u: %s", index, strerror(errno));
        }
    }
    [_writeLock unlock];
}

- (void)encryptAndSendLocked:(NSData *)packet {
    [self encryptAndSendLocked:packet.bytes length:packet.length];
}

- (void)encryptAndSendLocked:(const void *)packetBytes length:(size_t)packetLen {
    if (_state != AWGTunnelStateConnected || !_handshake.isEstablished || _udpFd < 0) return;
    uint64_t c = _sendCounter;
    uint8_t outBuf[2048];
    if (16 + packetLen + kWGTagLen > sizeof(outBuf)) return;

    size_t hdrLen = [_handshake writeTransportHeader:outBuf counter:c];

    uint8_t nonce[12];
    [AWGHandshake transportNonce:nonce forCounter:c];

    crypto_aead_ctx ctx;
    crypto_aead_init_ietf(&ctx, [_handshake.sendingKey bytes], nonce);
    crypto_aead_write(&ctx, outBuf + hdrLen, outBuf + hdrLen + packetLen,
                      NULL, 0, packetBytes, packetLen);
    crypto_wipe(&ctx, sizeof(ctx));

    size_t totalLen = hdrLen + packetLen + kWGTagLen;
    ssize_t sent = OGDanteSocketSend(_udpFd, outBuf, totalLen);
    if (sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == ENOBUFS)) {
        gAWGTxRetried++;
        fd_set wfds;
        FD_ZERO(&wfds);
        FD_SET(_udpFd, &wfds);
        struct timeval tv = {0, 15000};
        if (select(_udpFd + 1, NULL, &wfds, NULL, &tv) > 0) {
            sent = OGDanteSocketSend(_udpFd, outBuf, totalLen);
        }
    }
    if (sent > 0) gAWGTxSent++; else gAWGTxDropped++;
    _sendCounter++;
    if (sent > 0) {
        _bytesSent += (NSUInteger)sent;
        _lastTxAt = [NSDate timeIntervalSinceReferenceDate];
    }
}


- (BOOL)startSOCKS5ProxyWithError:(NSError **)error {
    _socksListenFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_socksListenFd < 0) {
        if (error) *error = AWGTunnelMakeError(9, @"SOCKS socket() failed");
        return NO;
    }

    int reuse = 1;
    setsockopt(_socksListenFd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = htons(_preferredSOCKSPort);
    if (_preferredSOCKSPort && bind(_socksListenFd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        DLog(@"[AWG] SOCKS-порт %u занят (%s), беру любой свободный",
             _preferredSOCKSPort, strerror(errno));
        addr.sin_port = 0;
    } else if (_preferredSOCKSPort) {
        goto bound;
    }
    if (bind(_socksListenFd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(_socksListenFd);
        _socksListenFd = -1;
        if (error) *error = AWGTunnelMakeError(10, @"SOCKS bind() failed");
        return NO;
    }
bound:;
    socklen_t alen = sizeof(addr);
    if (getsockname(_socksListenFd, (struct sockaddr *)&addr, &alen) == 0) {
        _socksPort = ntohs(addr.sin_port);
    }
    if (listen(_socksListenFd, 128) != 0) {
        close(_socksListenFd);
        _socksListenFd = -1;
        if (error) *error = AWGTunnelMakeError(11, @"SOCKS listen() failed");
        return NO;
    }

    DLog(@"[AWG] SOCKS5 proxy listening on 127.0.0.1:%u", _socksPort);
    _socksLoopExited = NO;
    if (_socksThread) {
        [_socksThread release];
        _socksThread = nil;
    }
    _socksThread = [[NSThread alloc] initWithTarget:self selector:@selector(socksAcceptLoop) object:nil];
    [_socksThread setStackSize:128 * 1024];
    [_socksThread start];
    return YES;
}

- (void)socksAcceptLoop {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    {
        while (_running && _socksListenFd >= 0) {
            NSAutoreleasePool *iteration = [[NSAutoreleasePool alloc] init];
            struct sockaddr_in clientAddr;
            socklen_t clen = sizeof(clientAddr);
            int client = accept(_socksListenFd, (struct sockaddr *)&clientAddr, &clen);
            if (client < 0) { [iteration drain]; continue; }
            if (OGDanteSocketPrepare(client) < 0) {
                close(client);
                [iteration drain];
                continue;
            }
            int one = 1;
            setsockopt(client, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
            int bufSize = 256 * 1024;
            setsockopt(client, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
            setsockopt(client, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));

            NSThread *t = [[NSThread alloc] initWithTarget:self
                                                  selector:@selector(socksClientThread:)
                                                    object:[NSNumber numberWithInt:client]];
            t.stackSize = 256 * 1024;
            [t start];
            [t release];
            [iteration drain];
        }
    }
    [pool drain];
    _socksLoopExited = YES;
}

- (void)socksClientThread:(NSNumber *)fd {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self handleSOCKSClient:[fd intValue]];
    [pool drain];
}

- (void)handleSOCKSClient:(int)clientFd {
    uint8_t buf[512];
    if (!awgReadFull(clientFd, buf, 1)) { close(clientFd); return; }
    if (buf[0] != 5) {
        [self handleHTTPClient:clientFd firstByte:buf[0]];
        return;
    }
    OGDanteSOCKSRequest request;
    if (!OGDanteReadSOCKSRequest(clientFd, &request)) { close(clientFd); return; }
    NSString *host = [NSString stringWithUTF8String:request.host];
    uint16_t port = request.port;
    uint8_t fail[10] = {5, 1, 0, 1, 0, 0, 0, 0, 0, 0};
    if (!host.length || !_running) {
        awgWriteFull(clientFd, fail, sizeof(fail));
        close(clientFd);
        return;
    }
    uint8_t ok[10] = {5, 0, 0, 1, 0, 0, 0, 0, 0, 0};
    [self relayClient:clientFd host:host port:port
              okReply:[NSData dataWithBytes:ok length:sizeof(ok)]
            failReply:[NSData dataWithBytes:fail length:sizeof(fail)] initialData:nil];
}

- (void)handleHTTPClient:(int)clientFd firstByte:(uint8_t)firstByte {
    NSMutableData *header = [NSMutableData dataWithBytes:&firstByte length:1];
    BOOL complete = NO;
    while (header.length < 16384) {
        uint8_t byte;
        if (!awgReadFull(clientFd, &byte, 1)) break;
        [header appendBytes:&byte length:1];
        if (header.length >= 4 && !memcmp((const uint8_t *)header.bytes + header.length - 4, "\r\n\r\n", 4)) { complete = YES; break; }
    }
    NSString *text = complete ? [[[NSString alloc] initWithData:header encoding:NSISOLatin1StringEncoding] autorelease] : nil;
    NSArray *lines = [text componentsSeparatedByString:@"\r\n"];
    NSArray *request = lines.count ? [[lines objectAtIndex:0] componentsSeparatedByString:@" "] : nil;
    NSString *host = nil;
    uint16_t port = 0;
    NSData *initial = nil;
    NSData *ok = nil;
    NSData *failure = [@"HTTP/1.1 502 Bad Gateway\r\nConnection: close\r\nContent-Length: 0\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    if (request.count == 3 && [[request objectAtIndex:0] isEqualToString:@"CONNECT"]) {
        NSString *authority = [request objectAtIndex:1];
        NSRange colon = [authority rangeOfString:@":" options:NSBackwardsSearch];
        if (colon.location != NSNotFound) {
            host = [authority substringToIndex:colon.location];
            NSInteger number = [[authority substringFromIndex:colon.location + 1] integerValue];
            if (number > 0 && number <= 65535) port = (uint16_t)number;
        }
        ok = [@"HTTP/1.1 200 Connection Established\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding];
    } else if (request.count == 3) {
        NSURL *url = [NSURL URLWithString:[request objectAtIndex:1]];
        if ([[[url scheme] lowercaseString] isEqualToString:@"http"]) {
            host = url.host;
            NSInteger number = url.port ? [url.port integerValue] : 80;
            if (number > 0 && number <= 65535) port = (uint16_t)number;
            NSString *path = url.path.length ? url.path : @"/";
            if (url.query.length) path = [path stringByAppendingFormat:@"?%@", url.query];
            NSMutableString *forwarded = [NSMutableString stringWithFormat:@"%@ %@ %@\r\n", [request objectAtIndex:0], path, [request objectAtIndex:2]];
            for (NSUInteger i = 1; i < lines.count; i++) {
                NSString *line = [lines objectAtIndex:i];
                if (!line.length) break;
                NSString *lower = [line lowercaseString];
                if ([lower hasPrefix:@"proxy-"] || [lower hasPrefix:@"connection:"]) continue;
                [forwarded appendFormat:@"%@\r\n", line];
            }
            [forwarded appendString:@"Connection: close\r\n\r\n"];
            initial = [forwarded dataUsingEncoding:NSISOLatin1StringEncoding];
        }
    }
    if (!host.length || !port || !_running) {
        awgWriteFull(clientFd, failure.bytes, failure.length);
        close(clientFd);
        return;
    }
    [self relayClient:clientFd host:host port:port okReply:ok failReply:failure initialData:initial];
}


- (void)adoptTransparentClient:(int)fd host:(NSString *)host port:(uint16_t)port {
    int one = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
    int bufSize = 1048576;
    setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
    setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));

    NSThread *t = [[NSThread alloc] initWithTarget:self
                                          selector:@selector(transparentClientThread:)
                                            object:[NSArray arrayWithObjects:[NSNumber numberWithInt:fd], host, [NSNumber numberWithUnsignedShort:port], nil]];
    t.stackSize = 256 * 1024;
    [t start];
    [t release];
}

- (void)transparentClientThread:(NSArray *)args {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self relayClient:[[args objectAtIndex:0] intValue]
                 host:[args objectAtIndex:1]
                 port:(uint16_t)[[args objectAtIndex:2] unsignedShortValue]
              okReply:nil failReply:nil initialData:nil];
    [pool drain];
}

- (void)adoptProxiedClient:(int)fd host:(NSString *)host port:(uint16_t)port
                   okReply:(NSData *)okReply failReply:(NSData *)failReply
               initialData:(NSData *)initialData {
    NSMutableArray *args = [NSMutableArray arrayWithObjects:[NSNumber numberWithInt:fd], host, [NSNumber numberWithUnsignedShort:port],
                            okReply ?: [NSNull null], failReply ?: [NSNull null],
                            initialData ?: [NSNull null], nil];
    NSThread *t = [[NSThread alloc] initWithTarget:self
                                          selector:@selector(proxiedClientThread:)
                                            object:args];
    t.stackSize = 256 * 1024;
    [t start];
    [t release];
}

- (void)proxiedClientThread:(NSArray *)args {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    id ok = [args objectAtIndex:3], fail = [args objectAtIndex:4], initial = [args objectAtIndex:5];
    [self relayClient:[[args objectAtIndex:0] intValue]
                 host:[args objectAtIndex:1]
                 port:(uint16_t)[[args objectAtIndex:2] unsignedShortValue]
              okReply:(ok == [NSNull null] ? nil : ok)
            failReply:(fail == [NSNull null] ? nil : fail)
          initialData:(initial == [NSNull null] ? nil : initial)];
    [pool drain];
}

- (void)relayProxiedClientInline:(int)fd host:(NSString *)host port:(uint16_t)port
                         okReply:(NSData *)okReply failReply:(NSData *)failReply
                     initialData:(NSData *)initialData {
    [self relayClient:fd host:host port:port okReply:okReply failReply:failReply initialData:initialData];
}

- (NSData *)relayDNSQuery:(NSData *)query {
    if (!_ipStack || !_running) return nil;
    NSData *answer = [_ipStack relayDNSQuery:query timeout:2.5];
    if (!answer) answer = [_ipStack relayDNSQuery:query timeout:2.5];
    return answer;
}

- (void)closeRelayClient:(int)clientFd connectionID:(uint32_t)connectionID {
    @synchronized(_socksClients) {
        [_socksClients removeObjectForKey:[NSNumber numberWithUnsignedInt:connectionID]];
        shutdown(clientFd, SHUT_RDWR);
        close(clientFd);
    }
    [_ipStack closeTCPConnectionAndDrain:connectionID];
}

- (void)relayClient:(int)clientFd host:(NSString *)host port:(uint16_t)port
            okReply:(NSData *)okReply failReply:(NSData *)failReply initialData:(NSData *)initialData {
    if (OGDanteSocketPrepare(clientFd) < 0) {
        close(clientFd);
        return;
    }
    BOOL socks = (okReply.length == 10);

    if (port == 53) {
        if (!okReply || awgWriteFull(clientFd, okReply.bytes, okReply.length))
            [self serveDNSOverTCPForClient:clientFd socks:NO];
        close(clientFd);
        return;
    }

    uint32_t connID = [_ipStack openTCPToHost:host port:port];
    if (connID == 0) {
        if (failReply) awgWriteFull(clientFd, failReply.bytes, failReply.length);
        close(clientFd);
        return;
    }

    @synchronized(_socksClients) {
        [_socksClients setObject:[NSNumber numberWithInt:clientFd] forKey:[NSNumber numberWithUnsignedInt:connID]];
    }
    [_ipStack setClientFd:clientFd forConnectionID:connID];

    if (![_ipStack waitForConnection:connID timeout:12.0]) {
        DLog(@"[AWG] %@: %@:%u did not come up", socks ? @"SOCKS5" : (okReply || failReply ? @"proxy" : @"redirect"), host, port);
        if (failReply) awgWriteFull(clientFd, failReply.bytes, failReply.length);
        [self closeRelayClient:clientFd connectionID:connID];
        return;
    }

    if (okReply) {
        if (!awgWriteFull(clientFd, okReply.bytes, okReply.length)) {
            [self closeRelayClient:clientFd connectionID:connID];
            return;
        }
    }
    if (initialData.length) [_ipStack sendTCPData:initialData connectionID:connID];

    struct timeval noTimeout = {0, 0};
    setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, &noTimeout, sizeof(noTimeout));
    uint8_t buf[16384];
    int sinceCheck = 8;
    while (_running) {

        if (++sinceCheck >= 8) {
            sinceCheck = 0;
            int waited = 0;
            while (_running && [_ipStack sendBacklogForConnection:connID] > kAWGSendBacklogCap
                   && waited < 60000) {
                usleep(2000);
                waited += 2;
            }
        }
        ssize_t n = read(clientFd, buf, sizeof(buf));
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) {
            DLogVerbose(@"[AWG relay] conn %u clientFd %d: client closed / read %ld (errno=%d)",
                 connID, clientFd, (long)n, errno);
            break;
        }
        NSAutoreleasePool *iteration = [[NSAutoreleasePool alloc] init];
        NSData *data = [NSData dataWithBytes:buf length:(NSUInteger)n];
        [_ipStack sendTCPData:data connectionID:connID];
        [iteration drain];
    }
    [self closeRelayClient:clientFd connectionID:connID];
}

static BOOL awgReadFull(int fd, uint8_t *buf, size_t len) {
    size_t got = 0;
    while (got < len) {
        ssize_t n = read(fd, buf + got, len - got);
        if (n > 0) { got += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return NO;
    }
    return YES;
}

static BOOL awgWriteFull(int fd, const uint8_t *buf, size_t len) {
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = OGDanteSocketSend(fd, buf + sent, len - sent);
        if (n > 0) { sent += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return NO;
    }
    return YES;
}

- (void)serveDNSOverTCPForClient:(int)clientFd socks:(BOOL)socks {
    uint8_t okReply[10] = {0x05, 0x00, 0x00, 0x01, 0,0,0,0, 0,0};
    if (socks && !awgWriteFull(clientFd, okReply, sizeof(okReply))) return;

    uint8_t lenBuf[2];
    uint8_t query[65535];
    while (_running && awgReadFull(clientFd, lenBuf, 2)) {
        size_t qlen = ((size_t)lenBuf[0] << 8) | lenBuf[1];
        if (qlen < 12 || !awgReadFull(clientFd, query, qlen)) break;
        NSAutoreleasePool *iteration = [[NSAutoreleasePool alloc] init];
        NSData *q = [NSData dataWithBytes:query length:qlen];
        NSData *answer = [self relayDNSQuery:q];
        if (!answer) {
            DLog(@"[AWG] DNS/TCP: нет ответа от резолвера через туннель");
            [iteration drain];
            break;
        }
        uint8_t alen[2] = { (uint8_t)(answer.length >> 8), (uint8_t)answer.length };
        BOOL written = awgWriteFull(clientFd, alen, 2) &&
            awgWriteFull(clientFd, answer.bytes, answer.length);
        [iteration drain];
        if (!written) break;
    }
}

- (void)deliverData:(NSData *)data toFd:(int)clientFd connectionID:(uint32_t)connectionID {
    int fd = -1;
    @synchronized(_socksClients) {
        NSNumber *fdNum = [_socksClients objectForKey:[NSNumber numberWithUnsignedInt:connectionID]];
        if (!fdNum || (clientFd >= 0 && clientFd != [fdNum intValue])) return;
        fd = OGDanteSocketDuplicate([fdNum intValue]);
        if (fd < 0) shutdown([fdNum intValue], SHUT_RDWR);
    }
    if (fd < 0) return;
    @try {
        if (data.length == 0) {

            shutdown(fd, SHUT_RDWR);
            return;
        }

        const uint8_t *bytes = data.bytes;
        size_t total = data.length;
        size_t sent = 0;
        NSTimeInterval deadline = [NSDate timeIntervalSinceReferenceDate] + kAWGClientDrainTimeout;

        while (sent < total) {
            ssize_t written = OGDanteSocketSend(fd, bytes + sent, total - sent);
            if (written > 0) { sent += (size_t)written; continue; }
            if (written < 0 && (errno == EINTR)) continue;
            if (written < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                if ([NSDate timeIntervalSinceReferenceDate] >= deadline) {

                    DLog(@"[AWG] клиент %u не читает %.0f с — закрываю соединение",
                         connectionID, kAWGClientDrainTimeout);

                    shutdown(fd, SHUT_RDWR);
                    return;
                }

                fd_set wfds;
                if (fd >= FD_SETSIZE) {
                    shutdown(fd, SHUT_RDWR);
                    return;
                }
                FD_ZERO(&wfds);
                FD_SET(fd, &wfds);
                struct timeval tv = {0, 10000};
                select(fd + 1, NULL, &wfds, NULL, &tv);
                continue;
            }
            DLog(@"[AWG] write to client %u (fd %d) failed: %s", connectionID, fd, strerror(errno));
            shutdown(fd, SHUT_RDWR);
            break;
        }
    } @finally {
        close(fd);
    }
}

- (void)deliverData:(NSData *)data toConnection:(uint32_t)connectionID {
    [self deliverData:data toFd:-1 connectionID:connectionID];
}


- (void)notifyState {
    if ([_delegate respondsToSelector:@selector(tunnelDidChangeState:)]) {
        [_delegate tunnelDidChangeState:_state];
    }
}

- (NSString *)resolveHostThroughTunnel:(NSString *)host {
    if (!_ipStack || host.length == 0) return nil;
    uint32_t ip = [_ipStack resolveIPv4:host];
    if (ip == 0) return nil;
    return [NSString stringWithFormat:@"%u.%u.%u.%u",
            ip & 0xff, (ip >> 8) & 0xff, (ip >> 16) & 0xff, (ip >> 24) & 0xff];
}

@end
