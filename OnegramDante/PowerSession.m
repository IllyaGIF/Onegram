#import "PowerSession.h"
#import "PowerVLESS.h"
#import "PowerReality.h"
#import "OGDanteSupport.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/x509v3.h>
#import "OGDanteTLSRoots.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTOnegramCoreTLSRoots.h"
#import "OGDanteSocket.h"

typedef struct {
    int     active;           
    int     padOut;           
    uint8_t uuid[16];
    int     uuidSent;

    int     headerDone;
    int     inStarted;
    int     inDone;

    int     directIn;
    int     remainingCommand, remainingContent, remainingPadding, currentCommand;
} PWVision;

typedef struct {
    int      fd;
    int      kind;     
    SSL     *ssl;      
    SSL_CTX *ctx;
    PWReality real;    
    PWVision vision;
} PWLink;

static int PWConnectTCP(NSString *host, uint16_t port, NSTimeInterval timeout) {
    struct addrinfo hints, *addresses = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    char service[8];
    snprintf(service, sizeof(service), "%u", port);
    if (getaddrinfo([host UTF8String], service, &hints, &addresses) != 0) return -1;
    NSTimeInterval deadline = [NSDate timeIntervalSinceReferenceDate] + timeout;
    int connected = -1;
    for (struct addrinfo *address = addresses; address; address = address->ai_next) {
        NSTimeInterval remaining = deadline - [NSDate timeIntervalSinceReferenceDate];
        if (remaining <= 0) break;
        int fd = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        if (fd < 0) continue;
        if (OGDanteSocketPrepare(fd) < 0 || fd >= FD_SETSIZE) { close(fd); continue; }
        int flags = fcntl(fd, F_GETFL, 0);
        if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) { close(fd); continue; }
        int yes = 1;
        setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));
        int result = connect(fd, address->ai_addr, address->ai_addrlen);
        BOOL ready = result == 0;
        while (!ready && result < 0 && errno == EINPROGRESS) {
            remaining = deadline - [NSDate timeIntervalSinceReferenceDate];
            if (remaining <= 0) break;
            fd_set writable;
            FD_ZERO(&writable); FD_SET(fd, &writable);
            struct timeval wait = {(time_t)remaining, (suseconds_t)((remaining - (time_t)remaining) * 1e6)};
            int count = select(fd + 1, NULL, &writable, NULL, &wait);
            if (count < 0 && errno == EINTR) { errno = EINPROGRESS; continue; }
            if (count > 0) {
                int error = 0;
                socklen_t length = sizeof(error);
                ready = getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) == 0 && error == 0;
            }
            break;
        }
        if (!ready || fcntl(fd, F_SETFL, flags) < 0) { close(fd); continue; }
        struct timeval ioTimeout = {(time_t)timeout, (suseconds_t)((timeout - (time_t)timeout) * 1e6)};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &ioTimeout, sizeof(ioTimeout));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &ioTimeout, sizeof(ioTimeout));
        connected = fd;
        break;
    }
    freeaddrinfo(addresses);
    return connected;
}

static void PWLinkClose(PWLink *link) {
    if (link->kind == 2) {
        pwRealityClose(&link->real);
    } else if (link->ssl) { SSL_shutdown(link->ssl); SSL_free(link->ssl); link->ssl = NULL; }
    if (link->ctx) { SSL_CTX_free(link->ctx); link->ctx = NULL; }
    if (link->fd >= 0) { close(link->fd); link->fd = -1; }
}

static BOOL PWLinkWriteRaw(PWLink *link, const uint8_t *bytes, size_t length);

static size_t PWVisionFrame(PWVision *v, const uint8_t *content, size_t contentLen,
                            uint8_t *out, size_t outCap) {
    size_t padLen = (size_t)(arc4random() & 0xff);
    size_t need = (v->uuidSent ? 0 : 16) + 5 + contentLen + padLen;
    if (need > outCap) {
        if ((v->uuidSent ? 0 : 16) + 5 + contentLen > outCap) return 0;
        padLen = outCap - ((v->uuidSent ? 0 : 16) + 5 + contentLen);
    }
    size_t n = 0;
    if (!v->uuidSent) { memcpy(out, v->uuid, 16); n = 16; v->uuidSent = 1; }
    out[n++] = 1;                                    
    out[n++] = (uint8_t)(contentLen >> 8);
    out[n++] = (uint8_t)contentLen;
    out[n++] = (uint8_t)(padLen >> 8);
    out[n++] = (uint8_t)padLen;
    if (contentLen) { memcpy(out + n, content, contentLen); n += contentLen; }
    for (size_t i = 0; i < padLen; i++) out[n++] = (uint8_t)(arc4random() & 0xff);
    v->padOut = 0;                                   
    return n;
}

static size_t PWVisionUnpad(PWVision *v, uint8_t *buf, size_t n) {
    if (v->inDone) return n;
    if (!v->inStarted) {

        if (n < 21 || memcmp(buf, v->uuid, 16) != 0) { v->inDone = 1; return n; }
        memmove(buf, buf + 16, n - 16);
        n -= 16;
        v->inStarted = 1;
        v->remainingCommand = 5;
        v->remainingContent = 0;
        v->remainingPadding = 0;
    }
    size_t at = 0, put = 0;
    while (at < n) {
        if (v->remainingCommand > 0) {
            uint8_t d = buf[at++];
            switch (v->remainingCommand) {
                case 5: v->currentCommand = d; break;
                case 4: v->remainingContent = (int)d << 8; break;
                case 3: v->remainingContent |= d; break;
                case 2: v->remainingPadding = (int)d << 8; break;
                case 1: v->remainingPadding |= d; break;
            }
            v->remainingCommand--;
        } else if (v->remainingContent > 0) {
            size_t take = n - at;
            if (take > (size_t)v->remainingContent) take = (size_t)v->remainingContent;
            memmove(buf + put, buf + at, take);
            put += take; at += take;
            v->remainingContent -= (int)take;
        } else if (v->remainingPadding > 0) {
            size_t skip = n - at;
            if (skip > (size_t)v->remainingPadding) skip = (size_t)v->remainingPadding;
            at += skip;
            v->remainingPadding -= (int)skip;
        }
        if (v->remainingCommand <= 0 && v->remainingContent <= 0 && v->remainingPadding <= 0) {
            if (v->currentCommand == 0) {
                v->remainingCommand = 5;             
            } else {
                v->inDone = 1;                       
                if (v->currentCommand == 2) v->directIn = 1;
                size_t rest = n - at;
                if (rest) { memmove(buf + put, buf + at, rest); put += rest; }
                return put;
            }
        }
    }
    return put;
}

static BOOL PWLinkWrite(PWLink *link, const uint8_t *bytes, size_t length) {
    if (link->vision.active && link->vision.padOut) {
        uint8_t frame[20480];
        size_t chunk = length > 16384 ? 16384 : length;
        size_t n = PWVisionFrame(&link->vision, bytes, chunk, frame, sizeof(frame));
        if (!n || !PWLinkWriteRaw(link, frame, n)) return NO;
        if (chunk == length) return YES;
        return PWLinkWriteRaw(link, bytes + chunk, length - chunk);
    }
    return PWLinkWriteRaw(link, bytes, length);
}

static BOOL PWLinkWriteRaw(PWLink *link, const uint8_t *bytes, size_t length) {
    if (link->kind == 2) return pwRealityWrite(&link->real, bytes, length) != 0;
    if (link->kind == 0) {
        size_t sent = 0;
        while (sent < length) {
            ssize_t n = OGDanteSocketSend(link->fd, bytes + sent, length - sent);
            if (n > 0) { sent += (size_t)n; continue; }
            if (n < 0 && errno == EINTR) continue;
            return NO;
        }
        return YES;
    }
    size_t sent = 0;
    while (sent < length) {
        if (link->ssl) {
            int n = SSL_write(link->ssl, bytes + sent, (int)(length - sent));
            if (n > 0) { sent += (size_t)n; continue; }
            int err = SSL_get_error(link->ssl, n);
            if (err == SSL_ERROR_WANT_WRITE || err == SSL_ERROR_WANT_READ) continue;
            return NO;
        } else {
            ssize_t n = OGDanteSocketSend(link->fd, bytes + sent, length - sent);
            if (n > 0) { sent += (size_t)n; continue; }
            if (n < 0 && errno == EINTR) continue;
            return NO;
        }
    }
    return YES;
}

static ssize_t PWLinkReadRaw(PWLink *link, uint8_t *bytes, size_t capacity);

#define PW_AGAIN (-2)

static ssize_t PWLinkRead(PWLink *link, uint8_t *bytes, size_t capacity) {
    if (link->vision.directIn) {
        if (link->kind == 2 && pwRealityPending(&link->real)) return pwRealityRead(&link->real, bytes, capacity);
        if (link->ssl && SSL_pending(link->ssl) > 0) return PWLinkReadRaw(link, bytes, capacity);
        return recv(link->fd, bytes, capacity, 0);
    }
    for (;;) {
        ssize_t n = PWLinkReadRaw(link, bytes, capacity);
        if (n <= 0 || !link->vision.active ||
            !link->vision.headerDone || link->vision.inDone) return n;
        size_t kept = PWVisionUnpad(&link->vision, bytes, (size_t)n);
        if (kept) return (ssize_t)kept;              
    }
}

static size_t PWLinkAfterVLESSHeader(PWLink *link, uint8_t *body, size_t length) {
    if (!link->vision.active || link->vision.headerDone) return length;
    link->vision.headerDone = 1;
    if (!length) return 0;
    return PWVisionUnpad(&link->vision, body, length);
}

static ssize_t PWLinkReadRaw(PWLink *link, uint8_t *bytes, size_t capacity) {
    if (link->kind == 2) return pwRealityRead(&link->real, bytes, capacity);
    if (link->kind == 0) return recv(link->fd, bytes, capacity, 0);
    if (link->ssl) {
        int n = SSL_read(link->ssl, bytes, (int)capacity);
        if (n > 0) return n;
        int err = SSL_get_error(link->ssl, n);
        if (err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE) return PW_AGAIN;
        if (err == SSL_ERROR_ZERO_RETURN) return 0;
        return -1;
    }
    return recv(link->fd, bytes, capacity, 0);
}

static int PWBase64Value(unichar c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;

    if (c == '+' || c == '-') return 62;
    if (c == '/' || c == '_') return 63;
    return -1;
}

static BOOL PWDecodeBase64(NSString *text, uint8_t *out, size_t outLen) {
    if (!text.length) return NO;
    NSMutableData *d = [NSMutableData data];
    uint32_t acc = 0;
    int nbits = 0;
    for (NSUInteger i = 0; i < text.length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '=') break;
        int v = PWBase64Value(c);
        if (v < 0) continue;  
        acc = (acc << 6) | v;
        nbits += 6;
        if (nbits >= 8) {
            nbits -= 8;
            uint8_t b = (uint8_t)(acc >> nbits);
            [d appendBytes:&b length:1];
        }
    }
    if (d.length != outLen) return NO;
    memcpy(out, d.bytes, outLen);
    return YES;
}

static BOOL PWDecodeHex(NSString *text, uint8_t *out, size_t outLen);

static BOOL PWDecodeShortID(NSString *text, uint8_t out[8]) {
    memset(out, 0, 8);
    if (!text.length) return YES;
    if (text.length > 16 || (text.length % 2) != 0) return NO;
    return PWDecodeHex(text, out, text.length / 2);
}

static BOOL PWDecodeHex(NSString *text, uint8_t *out, size_t outLen) {
    if (text.length != outLen * 2) return NO;
    for (size_t i = 0; i < outLen; i++) {
        unsigned v = 0;
        NSScanner *s = [NSScanner scannerWithString:[text substringWithRange:
                     NSMakeRange(i * 2, 2)]];
        if (![s scanHexInt:&v] || v > 0xff) return NO;
        out[i] = (uint8_t)v;
    }
    return YES;
}

@implementation PowerSession {
    PowerConfig *_config;
    NSLock *_socketLock;
    int _socketControl;
    BOOL _cancelled;
}

- (instancetype)initWithConfig:(PowerConfig *)config {
    self = [super init];
    if (self) {
        _config = [config retain];
        _socketLock = [[NSLock alloc] init];
        _socketControl = -1;
    }
    return self;
}

- (PowerConfig *)config { return _config; }

- (void)dealloc {
    if (_socketControl >= 0) close(_socketControl);
    [_socketLock release];
    [_config release];
    [super dealloc];
}

- (void)cancel {
    [_socketLock lock];
    _cancelled = YES;
    if (_socketControl >= 0) shutdown(_socketControl, SHUT_RDWR);
    [_socketLock unlock];
}

- (BOOL)openLink:(PWLink *)link timeout:(NSTimeInterval)timeout failure:(PWProbeResult *)failure {
    link->fd = -1;
    link->kind = 0;
    link->ssl = NULL;
    link->ctx = NULL;
    memset(&link->vision, 0, sizeof(link->vision));
    if ([_config.flow hasPrefix:@"xtls-rprx-vision"] &&
        PWParseUUID([_config.uuid UTF8String], link->vision.uuid) == PWVLESSOk) {
        link->vision.active = 1;
        link->vision.padOut = 1;
    }

    link->fd = PWConnectTCP(_config.host, _config.port, timeout);
    if (link->fd < 0) {
        if (failure) *failure = PWProbeNoRoute;
        return NO;
    }

    [_socketLock lock];
    int control = OGDanteSocketDuplicate(link->fd);
    if (_socketControl >= 0) close(_socketControl);
    _socketControl = control;
    BOOL cancelled = _cancelled || control < 0;
    [_socketLock unlock];
    if (cancelled) {
        PWLinkClose(link);
        if (failure) *failure = PWProbeNoRoute;
        return NO;
    }
    if (_config.security == PWSecurityNone) return YES;

    if (_config.security == PWSecurityReality) {

        uint8_t pbk[32], sid[8];
        if (!PWDecodeBase64(_config.publicKey, pbk, 32) ||
            !PWDecodeShortID(_config.shortID, sid)) {
            if (failure) *failure = PWProbeUnsupported;
            PWLinkClose(link);
            return NO;
        }
        const char *sni = _config.sni.length ? [_config.sni UTF8String]
                                              : [_config.host UTF8String];
        NSMutableArray *alpn = [NSMutableArray array];
        for (NSString *p in _config.alpn) [alpn addObject:p];
        NSUInteger n = alpn.count;
        const char *alpnBuf[8];
        for (NSUInteger i = 0; i < n && i < 8; i++) alpnBuf[i] = [[alpn objectAtIndex:i] UTF8String];
        PWRealityResult rc = pwRealityConnect(&link->real, link->fd, sni, pbk, sid,
                                              n ? alpnBuf : NULL, MIN(n, 8),
                                              (long)timeout);
        if (rc != PWR_OK) {
            
            DLog(@"[power] REALITY с %@ (%s) не встал: %d", _config.host, sni, (int)rc);
            if (failure) *failure = rc == PWR_IO ? PWProbeNoRoute
                                   : rc == PWR_AUTH ? PWProbeRejected
                                   : PWProbeTLSFailed;
            PWLinkClose(link);
            return NO;
        }
        link->kind = 2;
        return YES;
    }

    static dispatch_once_t once;
    dispatch_once(&once, ^{ SSL_library_init(); SSL_load_error_strings(); });

    SSL_CTX *ctx = SSL_CTX_new(SSLv23_client_method());
    if (!ctx) {
        if (failure) *failure = PWProbeTLSFailed;
        PWLinkClose(link);
        return NO;
    }

    SSL_CTX_set_verify(ctx, _config.allowInsecure ? SSL_VERIFY_NONE : SSL_VERIFY_PEER, NULL);
    const char *roots[] = {MTOnegramCoreTLSRoots, OGDanteTLSRoots};
    for (NSUInteger i = 0; i < sizeof(roots) / sizeof(roots[0]); i++) {
        BIO *certificates = BIO_new_mem_buf((void *)roots[i], -1);
        X509 *certificate;
        while (certificates && (certificate = PEM_read_bio_X509(certificates, NULL, NULL, NULL))) {
            X509_STORE_add_cert(SSL_CTX_get_cert_store(ctx), certificate);
            X509_free(certificate);
        }
        BIO_free(certificates);
    }
    ERR_clear_error();
    SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_TLSv1 | SSL_OP_NO_TLSv1_1 | SSL_OP_NO_COMPRESSION);

    SSL *ssl = SSL_new(ctx);
    if (!ssl) {
        SSL_CTX_free(ctx);
        if (failure) *failure = PWProbeTLSFailed;
        PWLinkClose(link);
        return NO;
    }
    SSL_set_fd(ssl, link->fd);

    NSString *sni = _config.sni.length ? _config.sni : _config.host;
    const char *serverName = [sni UTF8String];
    X509_VERIFY_PARAM *parameters = SSL_get0_param(ssl);
    X509_VERIFY_PARAM_set_hostflags(parameters, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
    unsigned char address[16];
    BOOL numeric = inet_pton(AF_INET, serverName, address) == 1 || inet_pton(AF_INET6, serverName, address) == 1;
    if ((!_config.allowInsecure && (numeric ? X509_VERIFY_PARAM_set1_ip_asc(parameters, serverName) : X509_VERIFY_PARAM_set1_host(parameters, serverName, 0)) != 1) ||
        (!numeric && SSL_set_tlsext_host_name(ssl, serverName) != 1)) {
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        PWLinkClose(link);
        if (failure) *failure = PWProbeTLSFailed;
        return NO;
    }

    if (_config.alpn.count) {
        uint8_t wire[256];
        size_t n = 0;
        for (NSString *proto in _config.alpn) {
            const char *p = [proto UTF8String];
            size_t l = strlen(p);
            if (!l || l > 255 || n + 1 + l > sizeof(wire)) continue;
            wire[n++] = (uint8_t)l;
            memcpy(wire + n, p, l);
            n += l;
        }
        if (n) SSL_set_alpn_protos(ssl, wire, (unsigned)n);
    }

    if (SSL_connect(ssl) != 1) {
        DLog(@"[power] TLS не встал с %@ (%@)", _config.host, sni);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        if (failure) *failure = PWProbeTLSFailed;
        PWLinkClose(link);
        return NO;
    }
    DLog(@"[power] %@: %s, %s", _config.host, SSL_get_version(ssl), SSL_get_cipher(ssl));
    link->ctx = ctx;
    link->ssl = ssl;
    link->kind = 1;
    return YES;
}

- (BOOL)sendHeaderOn:(PWLink *)link host:(NSString *)host port:(uint16_t)port
             payload:(const uint8_t *)payload length:(size_t)payloadLength {
    PWVLESSRequest request;
    memset(&request, 0, sizeof(request));
    if (PWParseUUID([_config.uuid UTF8String], request.uuid) != PWVLESSOk) return NO;
    request.command = PWCmdTCP;

    request.flow = link->vision.active ? "xtls-rprx-vision" : NULL;
    request.destination.port = port;

    struct in_addr v4;
    if (inet_pton(AF_INET, [host UTF8String], &v4) == 1) {
        request.destination.type = PWAddrIPv4;
        memcpy(request.destination.ip, &v4, 4);
    } else {
        request.destination.type = PWAddrDomain;
        strlcpy(request.destination.domain, [host UTF8String],
                sizeof(request.destination.domain));
    }

    uint8_t header[512];
    size_t headerLength = 0;
    if (PWBuildRequest(&request, header, sizeof(header), &headerLength) != PWVLESSOk) return NO;

    if (payloadLength) {
        size_t cap = headerLength + payloadLength + 16 + 5 + 256;
        uint8_t *joined = malloc(cap);
        if (!joined) return NO;
        memcpy(joined, header, headerLength);
        size_t total = headerLength;
        BOOL ok;
        if (link->vision.active && link->vision.padOut) {
            size_t n = PWVisionFrame(&link->vision, payload, payloadLength,
                                     joined + headerLength, cap - headerLength);
            if (!n) { free(joined); return NO; }
            total += n;
            ok = PWLinkWriteRaw(link, joined, total);
        } else {
            memcpy(joined + headerLength, payload, payloadLength);
            total += payloadLength;
            ok = PWLinkWrite(link, joined, total);
        }
        free(joined);
        return ok;
    }
    return PWLinkWriteRaw(link, header, headerLength);
}

- (PWProbeResult)probeThroughHost:(NSString *)host
                             port:(uint16_t)port
                          timeout:(NSTimeInterval)timeout
                     latencyMillis:(int *)latencyMillis {
    if (![_config isSupported]) return PWProbeUnsupported;

    struct timeval start, now;
    gettimeofday(&start, NULL);

    PWLink link;
    PWProbeResult failure = PWProbeNoRoute;
    if (![self openLink:&link timeout:timeout failure:&failure]) return failure;

    NSString *request = [NSString stringWithFormat:
        @"GET /generate_204 HTTP/1.1\r\nHost: %@\r\nUser-Agent: Mozilla/5.0\r\n"
         "Connection: close\r\n\r\n", host];
    const char *requestBytes = [request UTF8String];

    if (![self sendHeaderOn:&link host:host port:port
                    payload:(const uint8_t *)requestBytes length:strlen(requestBytes)]) {
        PWLinkClose(&link);
        return PWProbeRejected;
    }

    struct timeval tv = { (time_t)timeout, 0 };
    setsockopt(link.fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    uint8_t buffer[4096];
    size_t have = 0;
    size_t headerLength = 0;
    BOOL headerParsed = NO;
    BOOL sawPayload = NO;
    NSTimeInterval deadline = [NSDate timeIntervalSinceReferenceDate] + timeout;
    while (!sawPayload && [NSDate timeIntervalSinceReferenceDate] < deadline) {
        if (have >= sizeof(buffer)) break;
        ssize_t n = PWLinkRead(&link, buffer + have, sizeof(buffer) - have);
        if (n == PW_AGAIN) continue;
        if (n <= 0) break;
        have += (size_t)n;
        if (!headerParsed) {
            PWVLESSStatus parsed = PWParseResponse(buffer, have, &headerLength);
            if (parsed == PWVLESSNeedMoreData) continue;
            if (parsed != PWVLESSOk) { PWLinkClose(&link); return PWProbeRejected; }
            headerParsed = YES;

            memmove(buffer, buffer + headerLength, have - headerLength);
            have -= headerLength;
            have = PWLinkAfterVLESSHeader(&link, buffer, have);
            headerLength = 0;
        }
        if (have > 0) sawPayload = YES;
    }
    PWLinkClose(&link);
    if (!headerParsed || !sawPayload) {
        NSMutableString *dump = [NSMutableString string];
        for (size_t i = 0; i < have && i < 24; i++) [dump appendFormat:@"%02x ", buffer[i]];
        DLog(@"[power] %@: заголовок %@, данных %lu (%@)", _config.name,
             headerParsed ? @"принят" : @"не разобран", (unsigned long)have, dump);
        return PWProbeRejected;
    }

    const uint8_t *body = buffer + headerLength;
    size_t bodyLength = have - headerLength;
    if (bodyLength < 12 || memcmp(body, "HTTP/1.", 7) != 0) return PWProbeRejected;
    if (memcmp(body + 9, "204", 3) != 0 && memcmp(body + 9, "200", 3) != 0) {
        DLog(@"[power] %@: цель ответила «%.*s», путь не сквозной",
             _config.name, (int)MIN(bodyLength, (size_t)15), body);
        return PWProbeRejected;
    }

    gettimeofday(&now, NULL);
    if (latencyMillis) {
        *latencyMillis = (int)((now.tv_sec - start.tv_sec) * 1000 +
                               (now.tv_usec - start.tv_usec) / 1000);
    }
    return PWProbeOK;
}

- (BOOL)relayClient:(int)clientFd host:(NSString *)host port:(uint16_t)port
            okReply:(NSData *)okReply initialData:(NSData *)initialData {
    PWLink link;
    PWProbeResult failure;
    if (![self openLink:&link timeout:10.0 failure:&failure]) return NO;

    if (okReply.length) {
        const uint8_t *reply = okReply.bytes;
        size_t sent = 0;
        while (sent < okReply.length) {
            ssize_t w = OGDanteSocketSend(clientFd, reply + sent, okReply.length - sent);
            if (w > 0) { sent += (size_t)w; continue; }
            if (w < 0 && errno == EINTR) continue;
            break;
        }
        if (sent < okReply.length) { PWLinkClose(&link); return NO; }
    }

    uint8_t first[4096];
    const uint8_t *firstBytes = first;
    size_t firstLength = 0;
    if (initialData.length) {
        firstBytes = initialData.bytes;
        firstLength = initialData.length;
    } else {
        struct timeval tv = { 5, 0 };
        setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        ssize_t n = recv(clientFd, first, sizeof(first), 0);
        firstLength = n > 0 ? (size_t)n : 0;
        tv.tv_sec = 0;
        setsockopt(clientFd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    }

    if (![self sendHeaderOn:&link host:host port:port
                    payload:firstBytes length:firstLength]) {
        PWLinkClose(&link);
        close(clientFd);
        return YES;                                  
    }

    BOOL headerSkipped = NO;
    NSMutableData *responseHeader = [NSMutableData data];
    uint8_t buffer[16384];
    for (;;) {
        fd_set r;
        FD_ZERO(&r);
        FD_SET(clientFd, &r);
        FD_SET(link.fd, &r);
        int maxFd = clientFd > link.fd ? clientFd : link.fd;
        BOOL pending = (link.ssl && SSL_pending(link.ssl) > 0) || (link.kind == 2 && pwRealityPending(&link.real) > 0);
        int ready = pending ? 1 : select(maxFd + 1, &r, NULL, NULL, NULL);
        if (pending) { FD_ZERO(&r); FD_SET(link.fd, &r); }
        if (ready < 0) { if (errno == EINTR) continue; break; }

        if (FD_ISSET(clientFd, &r)) {
            ssize_t n = recv(clientFd, buffer, sizeof(buffer), 0);
            if (n <= 0) break;
            if (!PWLinkWrite(&link, buffer, (size_t)n)) break;
        }
        if (FD_ISSET(link.fd, &r)) {
            ssize_t n = PWLinkRead(&link, buffer, sizeof(buffer));
            if (n == PW_AGAIN) continue;
            if (n <= 0) break;
            const uint8_t *out = buffer;
            size_t outLength = (size_t)n;
            if (!headerSkipped) {
                [responseHeader appendBytes:buffer length:outLength];
                size_t headerLength = 0;
                PWVLESSStatus parsed = PWParseResponse(responseHeader.bytes, responseHeader.length, &headerLength);
                if (parsed == PWVLESSNeedMoreData) continue;
                if (parsed != PWVLESSOk) break;
                headerSkipped = YES;
                out = (const uint8_t *)responseHeader.mutableBytes + headerLength;
                outLength = responseHeader.length - headerLength;
                outLength = PWLinkAfterVLESSHeader(&link, (uint8_t *)out, outLength);
                if (!outLength) continue;
            }
            size_t sent = 0;
            while (sent < outLength) {
                ssize_t w = OGDanteSocketSend(clientFd, out + sent, outLength - sent);
                if (w > 0) { sent += (size_t)w; continue; }
                if (w < 0 && errno == EINTR) continue;
                break;
            }
            if (sent < outLength) break;
        }
    }

    PWLinkClose(&link);
    close(clientFd);
    return YES;
}

@end
