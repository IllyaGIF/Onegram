#import "VLESSSession.h"
#import "VLESSProtocol.h"
#import "VLESSReality.h"
#import "VLESSVision.h"
#import "VLESSEncoding.h"
#import "OGCoreSupport.h"

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
#import "OGCoreTLSRoots.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTOnegramCoreTLSRoots.h"
#import "OGCoreSocket.h"

typedef struct {
    int      fd;
    int      kind;
    SSL     *ssl;
    SSL_CTX *ctx;
    VLReality real;
    VLVision vision;
} VLLink;

static int VLConnectTCP(NSString *host, uint16_t port, NSTimeInterval timeout) {
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
        if (OGCoreSocketPrepare(fd) < 0 || fd >= FD_SETSIZE) { close(fd); continue; }
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

static void VLLinkClose(VLLink *link) {
    if (link->kind == 2) {
        vlRealityClose(&link->real);
    } else if (link->ssl) { SSL_shutdown(link->ssl); SSL_free(link->ssl); link->ssl = NULL; }
    if (link->ctx) { SSL_CTX_free(link->ctx); link->ctx = NULL; }
    if (link->fd >= 0) { close(link->fd); link->fd = -1; }
}

static BOOL VLLinkWriteRaw(VLLink *link, const uint8_t *bytes, size_t length);

static size_t VLVisionFrame(VLVision *v, const uint8_t *content, size_t contentLen,
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

static BOOL VLLinkWrite(VLLink *link, const uint8_t *bytes, size_t length) {
    if (link->vision.active && link->vision.padOut) {
        uint8_t frame[20480];
        size_t chunk = length > 16384 ? 16384 : length;
        size_t n = VLVisionFrame(&link->vision, bytes, chunk, frame, sizeof(frame));
        if (!n || !VLLinkWriteRaw(link, frame, n)) return NO;
        if (chunk == length) return YES;
        return VLLinkWriteRaw(link, bytes + chunk, length - chunk);
    }
    return VLLinkWriteRaw(link, bytes, length);
}

static BOOL VLLinkWriteRaw(VLLink *link, const uint8_t *bytes, size_t length) {
    if (link->kind == 2) return vlRealityWrite(&link->real, bytes, length) != 0;
    if (link->kind == 0) {
        size_t sent = 0;
        while (sent < length) {
            ssize_t n = OGCoreSocketSend(link->fd, bytes + sent, length - sent);
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
            ssize_t n = OGCoreSocketSend(link->fd, bytes + sent, length - sent);
            if (n > 0) { sent += (size_t)n; continue; }
            if (n < 0 && errno == EINTR) continue;
            return NO;
        }
    }
    return YES;
}

static ssize_t VLLinkReadRaw(VLLink *link, uint8_t *bytes, size_t capacity);

#define VL_AGAIN (-2)

static ssize_t VLLinkRead(VLLink *link, uint8_t *bytes, size_t capacity) {
    if (link->vision.directIn) {
        if (link->kind == 2 && vlRealityPending(&link->real)) return vlRealityRead(&link->real, bytes, capacity);
        if (link->ssl && SSL_pending(link->ssl) > 0) return VLLinkReadRaw(link, bytes, capacity);
        return recv(link->fd, bytes, capacity, 0);
    }
    for (;;) {
        if (link->vision.directIn) return recv(link->fd, bytes, capacity, 0);
        ssize_t n = VLLinkReadRaw(link, bytes, capacity);
        if (n <= 0 || !link->vision.active ||
            !link->vision.headerDone || link->vision.inDone) return n;
        ssize_t kept = VLVisionUnpad(&link->vision, bytes, (size_t)n);
        if (kept) return kept;
    }
}

static ssize_t VLLinkAfterVLESSHeader(VLLink *link, uint8_t *body, size_t length) {
    if (!link->vision.active || link->vision.headerDone) return length;
    link->vision.headerDone = 1;
    if (!length) return 0;
    return VLVisionUnpad(&link->vision, body, length);
}

static ssize_t VLLinkReadRaw(VLLink *link, uint8_t *bytes, size_t capacity) {
    if (link->kind == 2) return vlRealityRead(&link->real, bytes, capacity);
    if (link->kind == 0) return recv(link->fd, bytes, capacity, 0);
    if (link->ssl) {
        int n = SSL_read(link->ssl, bytes, (int)capacity);
        if (n > 0) return n;
        int err = SSL_get_error(link->ssl, n);
        if (err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE) return VL_AGAIN;
        if (err == SSL_ERROR_ZERO_RETURN) return 0;
        return -1;
    }
    return recv(link->fd, bytes, capacity, 0);
}

@implementation VLESSSession {
    VLESSConfig *_config;
    NSLock *_socketLock;
    int _socketControl;
    BOOL _cancelled;
}

- (instancetype)initWithConfig:(VLESSConfig *)config {
    self = [super init];
    if (self) {
        _config = [config retain];
        _socketLock = [[NSLock alloc] init];
        _socketControl = -1;
    }
    return self;
}

- (VLESSConfig *)config { return _config; }

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

- (BOOL)openLink:(VLLink *)link timeout:(NSTimeInterval)timeout failure:(VLProbeResult *)failure {
    link->fd = -1;
    link->kind = 0;
    link->ssl = NULL;
    link->ctx = NULL;
    memset(&link->vision, 0, sizeof(link->vision));
    if ([_config.flow isEqualToString:@"xtls-rprx-vision"] &&
        VLParseUUID([_config.uuid UTF8String], link->vision.uuid) == VLESSOk) {
        link->vision.active = 1;
        link->vision.padOut = 1;
    }

    [_socketLock lock];
    BOOL alreadyCancelled = _cancelled;
    [_socketLock unlock];
    if (alreadyCancelled || ![_config isSupported]) {
        if (failure) *failure = alreadyCancelled ? VLProbeNoRoute : VLProbeUnsupported;
        return NO;
    }
    link->fd = VLConnectTCP(_config.host, _config.port, timeout);
    if (link->fd < 0) {
        if (failure) *failure = VLProbeNoRoute;
        return NO;
    }

    [_socketLock lock];
    int control = OGCoreSocketDuplicate(link->fd);
    if (_socketControl >= 0) close(_socketControl);
    _socketControl = control;
    BOOL cancelled = _cancelled || control < 0;
    [_socketLock unlock];
    if (cancelled) {
        VLLinkClose(link);
        if (failure) *failure = VLProbeNoRoute;
        return NO;
    }
    if (_config.security == VLSecurityNone) return YES;

    if (_config.security == VLSecurityReality) {

        uint8_t pbk[32], sid[8];
        size_t keyLength = 0;
        memset(sid, 0, sizeof(sid));
        if (!VLDecodeBase64Bytes([_config.publicKey UTF8String], [_config.publicKey lengthOfBytesUsingEncoding:NSUTF8StringEncoding], pbk, sizeof(pbk), &keyLength) || keyLength != sizeof(pbk) ||
            !VLDecodeHexBytes([_config.shortID UTF8String], [_config.shortID lengthOfBytesUsingEncoding:NSUTF8StringEncoding], sid, sizeof(sid))) {
            if (failure) *failure = VLProbeUnsupported;
            VLLinkClose(link);
            return NO;
        }
        const char *sni = _config.sni.length ? [_config.sni UTF8String]
                                              : [_config.host UTF8String];
        NSMutableArray *alpn = [NSMutableArray array];
        for (NSString *p in _config.alpn) [alpn addObject:p];
        NSUInteger n = alpn.count;
        const char *alpnBuf[8];
        for (NSUInteger i = 0; i < n && i < 8; i++) alpnBuf[i] = [[alpn objectAtIndex:i] UTF8String];
        VLRealityResult rc = vlRealityConnect(&link->real, link->fd, sni, pbk, sid,
                                              n ? alpnBuf : NULL, MIN(n, 8),
                                              (long)timeout);
        if (rc != VLR_OK) {

            DLog(@"[vless] REALITY с %@ (%s) не встал: %d", _config.host, sni, (int)rc);
            if (failure) *failure = rc == VLR_IO ? VLProbeNoRoute
                                   : rc == VLR_AUTH ? VLProbeRejected
                                   : VLProbeTLSFailed;
            VLLinkClose(link);
            return NO;
        }
        link->kind = 2;
        return YES;
    }

    static dispatch_once_t once;
    dispatch_once(&once, ^{ SSL_library_init(); SSL_load_error_strings(); });

    SSL_CTX *ctx = SSL_CTX_new(SSLv23_client_method());
    if (!ctx) {
        if (failure) *failure = VLProbeTLSFailed;
        VLLinkClose(link);
        return NO;
    }

    SSL_CTX_set_verify(ctx, _config.allowInsecure ? SSL_VERIFY_NONE : SSL_VERIFY_PEER, NULL);
    const char *roots[] = {MTOnegramCoreTLSRoots, OGCoreTLSRoots};
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
        if (failure) *failure = VLProbeTLSFailed;
        VLLinkClose(link);
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
        VLLinkClose(link);
        if (failure) *failure = VLProbeTLSFailed;
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
        DLog(@"[vless] TLS не встал с %@ (%@)", _config.host, sni);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        if (failure) *failure = VLProbeTLSFailed;
        VLLinkClose(link);
        return NO;
    }
    DLog(@"[vless] %@: %s, %s", _config.host, SSL_get_version(ssl), SSL_get_cipher(ssl));
    link->ctx = ctx;
    link->ssl = ssl;
    link->kind = 1;
    return YES;
}

- (BOOL)sendHeaderOn:(VLLink *)link host:(NSString *)host port:(uint16_t)port
             payload:(const uint8_t *)payload length:(size_t)payloadLength {
    VLESSRequest request;
    memset(&request, 0, sizeof(request));
    if (VLParseUUID([_config.uuid UTF8String], request.uuid) != VLESSOk) return NO;
    request.command = VLCmdTCP;

    request.flow = link->vision.active ? "xtls-rprx-vision" : NULL;
    request.destination.port = port;

    struct in_addr v4;
    if (inet_pton(AF_INET, [host UTF8String], &v4) == 1) {
        request.destination.type = VLAddrIPv4;
        memcpy(request.destination.ip, &v4, 4);
    } else if (inet_pton(AF_INET6, [host UTF8String], request.destination.ip) == 1) {
        request.destination.type = VLAddrIPv6;
    } else {
        size_t hostLength = [host lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (!hostLength || hostLength >= sizeof(request.destination.domain)) return NO;
        request.destination.type = VLAddrDomain;
        memcpy(request.destination.domain, [host UTF8String], hostLength + 1);
    }

    uint8_t header[512];
    size_t headerLength = 0;
    if (VLBuildRequest(&request, header, sizeof(header), &headerLength) != VLESSOk) return NO;

    if (payloadLength) {
        size_t cap = headerLength + payloadLength + 16 + 5 + 256;
        uint8_t *joined = malloc(cap);
        if (!joined) return NO;
        memcpy(joined, header, headerLength);
        size_t total = headerLength;
        BOOL ok;
        if (link->vision.active && link->vision.padOut) {
            size_t n = VLVisionFrame(&link->vision, payload, payloadLength,
                                     joined + headerLength, cap - headerLength);
            if (!n) { free(joined); return NO; }
            total += n;
            ok = VLLinkWriteRaw(link, joined, total);
        } else {
            memcpy(joined + headerLength, payload, payloadLength);
            total += payloadLength;
            ok = VLLinkWrite(link, joined, total);
        }
        free(joined);
        return ok;
    }
    return VLLinkWriteRaw(link, header, headerLength);
}

- (VLProbeResult)probeThroughHost:(NSString *)host
                             port:(uint16_t)port
                          timeout:(NSTimeInterval)timeout
                     latencyMillis:(int *)latencyMillis {
    if (![_config isSupported]) return VLProbeUnsupported;

    struct timeval start, now;
    gettimeofday(&start, NULL);

    VLLink link;
    VLProbeResult failure = VLProbeNoRoute;
    if (![self openLink:&link timeout:timeout failure:&failure]) return failure;

    NSString *request = [NSString stringWithFormat:
        @"GET /generate_204 HTTP/1.1\r\nHost: %@\r\nUser-Agent: Mozilla/5.0\r\n"
         "Connection: close\r\n\r\n", host];
    const char *requestBytes = [request UTF8String];

    if (![self sendHeaderOn:&link host:host port:port
                    payload:(const uint8_t *)requestBytes length:strlen(requestBytes)]) {
        VLLinkClose(&link);
        return VLProbeRejected;
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
        ssize_t n = VLLinkRead(&link, buffer + have, sizeof(buffer) - have);
        if (n == VL_AGAIN) continue;
        if (n <= 0) break;
        have += (size_t)n;
        if (!headerParsed) {
            VLESSStatus parsed = VLParseResponse(buffer, have, &headerLength);
            if (parsed == VLESSNeedMoreData) continue;
            if (parsed != VLESSOk) { VLLinkClose(&link); return VLProbeRejected; }
            headerParsed = YES;

            memmove(buffer, buffer + headerLength, have - headerLength);
            have -= headerLength;
            ssize_t kept = VLLinkAfterVLESSHeader(&link, buffer, have);
            if (kept < 0) { VLLinkClose(&link); return VLProbeRejected; }
            have = (size_t)kept;
            headerLength = 0;
        }
        if (have >= 12) sawPayload = YES;
    }
    VLLinkClose(&link);
    if (!headerParsed || !sawPayload) {
        NSMutableString *dump = [NSMutableString string];
        for (size_t i = 0; i < have && i < 24; i++) [dump appendFormat:@"%02x ", buffer[i]];
        DLog(@"[vless] %@: заголовок %@, данных %lu (%@)", _config.name,
             headerParsed ? @"принят" : @"не разобран", (unsigned long)have, dump);
        return VLProbeRejected;
    }

    const uint8_t *body = buffer + headerLength;
    size_t bodyLength = have - headerLength;
    if (bodyLength < 12 || memcmp(body, "HTTP/1.", 7) != 0) return VLProbeRejected;
    if (memcmp(body + 9, "204", 3) != 0 && memcmp(body + 9, "200", 3) != 0) {
        DLog(@"[vless] %@: цель ответила «%.*s», путь не сквозной",
             _config.name, (int)MIN(bodyLength, (size_t)15), body);
        return VLProbeRejected;
    }

    gettimeofday(&now, NULL);
    if (latencyMillis) {
        *latencyMillis = (int)((now.tv_sec - start.tv_sec) * 1000 +
                               (now.tv_usec - start.tv_usec) / 1000);
    }
    return VLProbeOK;
}

- (BOOL)relayClient:(int)clientFd host:(NSString *)host port:(uint16_t)port
            okReply:(NSData *)okReply initialData:(NSData *)initialData {
    if (![_config isSupported] || clientFd < 0 || clientFd >= FD_SETSIZE) return NO;
    VLLink link;
    VLProbeResult failure;
    if (![self openLink:&link timeout:10.0 failure:&failure]) return NO;

    if (okReply.length) {
        const uint8_t *reply = okReply.bytes;
        size_t sent = 0;
        while (sent < okReply.length) {
            ssize_t w = OGCoreSocketSend(clientFd, reply + sent, okReply.length - sent);
            if (w > 0) { sent += (size_t)w; continue; }
            if (w < 0 && errno == EINTR) continue;
            break;
        }
        if (sent < okReply.length) { VLLinkClose(&link); return NO; }
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
        VLLinkClose(&link);
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
        BOOL pending = (link.ssl && SSL_pending(link.ssl) > 0) || (link.kind == 2 && vlRealityPending(&link.real) > 0);
        int ready = pending ? 1 : select(maxFd + 1, &r, NULL, NULL, NULL);
        if (pending) { FD_ZERO(&r); FD_SET(link.fd, &r); }
        if (ready < 0) { if (errno == EINTR) continue; break; }

        if (FD_ISSET(clientFd, &r)) {
            ssize_t n = recv(clientFd, buffer, sizeof(buffer), 0);
            if (n <= 0) break;
            if (!VLLinkWrite(&link, buffer, (size_t)n)) break;
        }
        if (FD_ISSET(link.fd, &r)) {
            ssize_t n = VLLinkRead(&link, buffer, sizeof(buffer));
            if (n == VL_AGAIN) continue;
            if (n <= 0) break;
            const uint8_t *out = buffer;
            size_t outLength = (size_t)n;
            if (!headerSkipped) {
                [responseHeader appendBytes:buffer length:outLength];
                size_t headerLength = 0;
                VLESSStatus parsed = VLParseResponse(responseHeader.bytes, responseHeader.length, &headerLength);
                if (parsed == VLESSNeedMoreData) continue;
                if (parsed != VLESSOk) break;
                headerSkipped = YES;
                out = (const uint8_t *)responseHeader.mutableBytes + headerLength;
                outLength = responseHeader.length - headerLength;
                ssize_t kept = VLLinkAfterVLESSHeader(&link, (uint8_t *)out, outLength);
                if (kept < 0) break;
                outLength = (size_t)kept;
                if (!outLength) continue;
            }
            size_t sent = 0;
            while (sent < outLength) {
                ssize_t w = OGCoreSocketSend(clientFd, out + sent, outLength - sent);
                if (w > 0) { sent += (size_t)w; continue; }
                if (w < 0 && errno == EINTR) continue;
                break;
            }
            if (sent < outLength) break;
        }
    }

    VLLinkClose(&link);
    close(clientFd);
    return YES;
}

@end
