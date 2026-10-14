#import "AWGHTTPSTransport.h"
#import "OGDanteSupport.h"
#import "OGDanteSocket.h"

#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/bio.h>
#include <pthread.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include <openssl/pem.h>
#include <openssl/x509v3.h>
#import "OGDanteTLSRoots.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTOnegramCoreTLSRoots.h"
#import "../submodules/MtProtoKit/thirdparty/AsyncSocket/GCDAsyncSocketOpenSSL.h"

NSString * const kAWGTransportErrorDomain = @"AWGHTTPSTransport";

static const useconds_t kFragmentGapUsec = 40000;

typedef struct {
    int fd;
    const char *sniHost;
    size_t sniLen;
    int mode;
} AWGTransportIO;

static BIO_METHOD *gAWGBIOMethod = NULL;
static pthread_once_t gAWGOpenSSLOnce = PTHREAD_ONCE_INIT;
static pthread_once_t gAWGBIOOnce = PTHREAD_ONCE_INIT;

NSString *AWGFragmentModeName(AWGFragmentMode mode) {
    switch (mode) {
        case AWGFragmentNone:       return @"no split";
        case AWGFragmentMidSNI:     return @"split mid-SNI";
        case AWGFragmentFirstByte:  return @"split after 1 byte";
        case AWGFragmentBeforeSNI:  return @"split before SNI";
        case AWGFragmentTiny:       return @"many tiny segments";
        case AWGFragmentMidSNISlow: return @"split mid-SNI, slow";
    }
    return @"?";
}

static void AWGOpenSSLInit(void) {
    GCDAsyncSocketInitializeOpenSSL();
}

static BOOL awgSendAll(int fd, const uint8_t *buf, size_t len) {
    size_t sent = 0;
    while (sent < len) {
        ssize_t n = OGDanteSocketSend(fd, buf + sent, len - sent);
        if (n > 0) {
            sent += (size_t)n;
            continue;
        }
        if (n < 0 && errno == EINTR) continue;
        return NO;
    }
    return YES;
}

static size_t awgFindSNI(const uint8_t *data, size_t len, const char *host, size_t hostLen) {
    size_t i;
    if (!host || hostLen < 4 || len < hostLen) return (size_t)-1;
    for (i = 0; i + hostLen <= len; i++) {
        if (memcmp(data + i, host, hostLen) == 0) return i;
    }
    return (size_t)-1;
}

static int awgBIOCreate(BIO *bio) {
    bio->init = 1;
    bio->ptr = NULL;
    bio->shutdown = 0;
    return 1;
}

static int awgBIODestroy(BIO *bio) {
    if (!bio) return 0;
    bio->ptr = NULL;
    bio->init = 0;
    return 1;
}

static int awgBIORead(BIO *bio, char *data, int length) {
    AWGTransportIO *io;
    ssize_t n;
    if (!bio || !data || length <= 0) return 0;
    io = (AWGTransportIO *)bio->ptr;
    if (!io || io->fd < 0) return -1;
    BIO_clear_retry_flags(bio);
    for (;;) {
        n = recv(io->fd, data, (size_t)length, 0);
        if (n > 0) return (int)n;
        if (n == 0) return 0;
        if (errno == EINTR) continue;
        if (errno == EAGAIN || errno == EWOULDBLOCK) BIO_set_retry_read(bio);
        return -1;
    }
}

static int awgBIOWrite(BIO *bio, const char *data, int length) {
    AWGTransportIO *io;
    const uint8_t *buf;
    size_t len;
    if (!bio || !data || length <= 0) return 0;
    io = (AWGTransportIO *)bio->ptr;
    if (!io || io->fd < 0) return -1;
    BIO_clear_retry_flags(bio);
    buf = (const uint8_t *)data;
    len = (size_t)length;

    if (io->mode != AWGFragmentNone && len > 16) {
        int mode = io->mode;
        size_t sniAt;
        useconds_t gap = kFragmentGapUsec;
        size_t cuts[24];
        int cutCount = 0;
        size_t sent = 0;
        int i;
        io->mode = AWGFragmentNone;
        sniAt = awgFindSNI(buf, len, io->sniHost, io->sniLen);

        switch (mode) {
            case AWGFragmentMidSNI:
                cuts[cutCount++] = (sniAt != (size_t)-1) ? sniAt + io->sniLen / 2 : len / 2;
                break;
            case AWGFragmentFirstByte:
                cuts[cutCount++] = 1;
                break;
            case AWGFragmentBeforeSNI:
                cuts[cutCount++] = (sniAt != (size_t)-1 && sniAt > 0) ? sniAt : len / 3;
                break;
            case AWGFragmentMidSNISlow:
                cuts[cutCount++] = (sniAt != (size_t)-1) ? sniAt + io->sniLen / 2 : len / 2;
                gap = 250000;
                break;
            case AWGFragmentTiny: {
                size_t step = 6;
                size_t at = step;
                while (at < len && cutCount < 23) {
                    cuts[cutCount++] = at;
                    at += step;
                }
                gap = 12000;
                break;
            }
            default:
                break;
        }

        DLog(@"[AWG/TLS] %@: hello %lu bytes in %d segments",
             AWGFragmentModeName((AWGFragmentMode)mode), (unsigned long)len, cutCount + 1);

        for (i = 0; i < cutCount; i++) {
            size_t cut = cuts[i];
            if (cut <= sent || cut >= len) continue;
            if (!awgSendAll(io->fd, buf + sent, cut - sent)) return -1;
            usleep(gap);
            sent = cut;
        }
        if (sent < len && !awgSendAll(io->fd, buf + sent, len - sent)) return -1;
        return length;
    }

    if (!awgSendAll(io->fd, buf, len)) return -1;
    return length;
}

static long awgBIOCtrl(BIO *bio, int command, long num, void *ptr) {
    (void)bio;
    (void)num;
    (void)ptr;
    if (command == BIO_CTRL_FLUSH) return 1;
    return 0;
}

static void AWGCreateBIOMethod(void) {
    static BIO_METHOD method = {
        BIO_TYPE_SOURCE_SINK, "onegram-dante-socket", awgBIOWrite, awgBIORead,
        NULL, NULL, awgBIOCtrl, awgBIOCreate, awgBIODestroy, NULL
    };
    gAWGBIOMethod = &method;
}

static NSError *awgError(NSInteger code, NSString *message) {
    NSDictionary *info = nil;
    if (message) info = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:kAWGTransportErrorDomain code:code userInfo:info];
}

static NSError *awgOpenSSLError(NSInteger code, NSString *prefix) {
    unsigned long value = ERR_get_error();
    char buffer[256];
    NSString *message;
    if (value != 0) {
        ERR_error_string_n(value, buffer, sizeof(buffer));
        message = [NSString stringWithFormat:@"%@: %s", prefix, buffer];
    } else {
        message = prefix;
    }
    return awgError(code, message);
}

static NSRange awgRangeOfBytes(NSData *data, const void *needleBytes, NSUInteger needleLength) {
    const uint8_t *bytes;
    const uint8_t *needle;
    NSUInteger length;
    NSUInteger i;
    if (!data || !needleBytes || needleLength == 0) return NSMakeRange(NSNotFound, 0);
    bytes = (const uint8_t *)[data bytes];
    needle = (const uint8_t *)needleBytes;
    length = [data length];
    if (needleLength > length) return NSMakeRange(NSNotFound, 0);
    for (i = 0; i + needleLength <= length; i++) {
        if (memcmp(bytes + i, needle, needleLength) == 0) return NSMakeRange(i, needleLength);
    }
    return NSMakeRange(NSNotFound, 0);
}

static int awgSocksConnect(uint16_t socksPort, NSString *host, uint16_t port, NSError **error) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    int yes = 1;
    struct timeval tv;
    struct sockaddr_in addr;
    uint8_t greet[3] = {0x05, 0x01, 0x00};
    uint8_t reply[2] = {0, 0};
    const char *hostUTF8;
    size_t hostLen;
    NSMutableData *req;
    uint8_t head[4] = {0x05, 0x01, 0x00, 0x03};
    uint8_t lenByte;
    uint16_t portBE;
    uint8_t connectReply[10];

    if (fd < 0) {
        if (error) *error = awgError(-20, @"socket() failed");
        return -1;
    }

    if (OGDanteSocketPrepare(fd) < 0) {
        if (error) *error = awgError(-20, @"Cannot configure SOCKS socket");
        close(fd);
        return -1;
    }
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));
    tv.tv_sec = 20;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(socksPort);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        if (error) *error = awgError(-21, @"Cannot reach the local SOCKS5 proxy");
        return -1;
    }

    if (!awgSendAll(fd, greet, 3) || recv(fd, reply, 2, MSG_WAITALL) != 2 ||
        reply[0] != 0x05 || reply[1] != 0x00) {
        close(fd);
        if (error) *error = awgError(-22, @"SOCKS5 greeting refused");
        return -1;
    }

    hostUTF8 = [host UTF8String];
    hostLen = strlen(hostUTF8);
    if (hostLen > 255) {
        close(fd);
        if (error) *error = awgError(-23, @"Host too long");
        return -1;
    }

    req = [NSMutableData data];
    lenByte = (uint8_t)hostLen;
    portBE = htons(port);
    [req appendBytes:head length:4];
    [req appendBytes:&lenByte length:1];
    [req appendBytes:hostUTF8 length:hostLen];
    [req appendBytes:&portBE length:2];

    memset(connectReply, 0, sizeof(connectReply));
    if (!awgSendAll(fd, [req bytes], [req length]) ||
        recv(fd, connectReply, sizeof(connectReply), MSG_WAITALL) != (ssize_t)sizeof(connectReply) ||
        connectReply[0] != 0x05 || connectReply[1] != 0x00) {
        close(fd);
        if (error) *error = awgError(-24, [NSString stringWithFormat:@"SOCKS5 CONNECT refused (code %u)",
                                           (unsigned)connectReply[1]]);
        return -1;
    }

    DLog(@"[AWG/TLS] tunnelled to %@:%u through the local SOCKS5 proxy", host, (unsigned)port);
    return fd;
}

@implementation AWGHTTPSTransport

+ (NSData *)postViaSOCKS:(uint16_t)socksPort
                    host:(NSString *)host
                    port:(uint16_t)port
                    path:(NSString *)path
                    body:(NSData *)body
                 headers:(NSDictionary *)headers
              statusCode:(NSInteger *)outStatus
                   error:(NSError **)error {
    int fd = awgSocksConnect(socksPort, host, port, error);
    if (fd < 0) return nil;
    return [self runTLSOnSocket:fd host:host path:path body:body headers:headers
                   fragmentMode:AWGFragmentNone statusCode:outStatus error:error];
}

+ (NSData *)postToHost:(NSString *)host
             connectIP:(NSString *)connectIP
             socksPort:(uint16_t)socksPort
                  port:(uint16_t)port
                  path:(NSString *)path
                  body:(NSData *)body
               headers:(NSDictionary *)headers
          fragmentMode:(AWGFragmentMode)fragmentMode
            statusCode:(NSInteger *)outStatus
                 error:(NSError **)error {
    struct addrinfo hints;
    struct addrinfo *res = NULL;
    char portStr[8];
    NSString *dialTarget;
    int rc;
    int fd;
    int yes = 1;
    struct timeval tv;
    char ipbuf[INET_ADDRSTRLEN];
    struct sockaddr_in *sin;

    if (outStatus) *outStatus = 0;
    if ([host length] == 0) {
        if (error) *error = awgError(-1, @"No host");
        return nil;
    }

    if (socksPort > 0) {
        return [self postViaSOCKS:socksPort host:host port:port path:path
                             body:body headers:headers statusCode:outStatus error:error];
    }

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    snprintf(portStr, sizeof(portStr), "%u", (unsigned)port);
    dialTarget = [connectIP length] ? connectIP : host;
    if ([connectIP length]) hints.ai_flags = AI_NUMERICHOST;

    rc = getaddrinfo([dialTarget UTF8String], portStr, &hints, &res);
    if (rc != 0 || !res) {
        if (error) *error = awgError(-2, [NSString stringWithFormat:@"Cannot resolve %@: %s", dialTarget, gai_strerror(rc)]);
        return nil;
    }

    fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (fd < 0) {
        freeaddrinfo(res);
        if (error) *error = awgError(-3, @"socket() failed");
        return nil;
    }

    if (OGDanteSocketPrepare(fd) < 0) {
        if (error) *error = awgError(-3, @"Cannot configure HTTPS socket");
        close(fd);
        freeaddrinfo(res);
        return nil;
    }
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &yes, sizeof(yes));
    tv.tv_sec = 2;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof(tv));

    memset(ipbuf, 0, sizeof(ipbuf));
    sin = (struct sockaddr_in *)res->ai_addr;
    inet_ntop(AF_INET, &sin->sin_addr, ipbuf, sizeof(ipbuf));

    int flags = fcntl(fd, F_GETFL, 0);
    fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    rc = connect(fd, res->ai_addr, res->ai_addrlen);
    if (rc < 0 && errno == EINPROGRESS) {
        fd_set writes;
        FD_ZERO(&writes);
        FD_SET(fd, &writes);
        struct timeval connectTimeout = {8, 0};
        rc = select(fd + 1, NULL, &writes, NULL, &connectTimeout);
        int socketError = ETIMEDOUT;
        socklen_t errorLength = sizeof(socketError);
        if (rc > 0) getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &errorLength);
        if (socketError) { errno = socketError; rc = -1; }
    }
    fcntl(fd, F_SETFL, flags);
    if (rc < 0) {
        freeaddrinfo(res);
        close(fd);
        if (error) *error = awgError(-4, [NSString stringWithFormat:@"connect(%s:%u) failed: %s", ipbuf, (unsigned)port, strerror(errno)]);
        return nil;
    }
    freeaddrinfo(res);

    DLog(@"[AWG/TLS] connected to %@ (%s:%u), %@",
         host, ipbuf, (unsigned)port, AWGFragmentModeName(fragmentMode));

    return [self runTLSOnSocket:fd host:host path:path body:body headers:headers
                   fragmentMode:fragmentMode statusCode:outStatus error:error];
}

+ (NSData *)runTLSOnSocket:(int)fd
                      host:(NSString *)host
                      path:(NSString *)path
                      body:(NSData *)body
                   headers:(NSDictionary *)headers
              fragmentMode:(AWGFragmentMode)fragmentMode
                statusCode:(NSInteger *)outStatus
                     error:(NSError **)error {
    const char *hostUTF8 = [host UTF8String];
    AWGTransportIO io;
    SSL_CTX *ctx = NULL;
    SSL *ssl = NULL;
    BIO *readBIO = NULL;
    BIO *writeBIO = NULL;
    int rc;
    int sslError;
    NSMutableString *request;
    NSEnumerator *keyEnumerator;
    NSString *key;
    NSMutableData *out;
    const uint8_t *outBytes;
    NSUInteger outLength;
    NSUInteger sent;
    NSMutableData *raw;
    uint8_t buffer[4096];
    NSDate *deadline;
    const char separator[4] = {'\r', '\n', '\r', '\n'};
    NSRange headEnd;
    NSString *head;
    NSInteger code = 0;
    NSArray *headLines;
    NSData *payload;
    NSUInteger payloadStart;

    pthread_once(&gAWGOpenSSLOnce, AWGOpenSSLInit);
    pthread_once(&gAWGBIOOnce, AWGCreateBIOMethod);

    if (!gAWGBIOMethod) {
        close(fd);
        if (error) *error = awgError(-5, @"OpenSSL BIO initialization failed");
        return nil;
    }

    memset(&io, 0, sizeof(io));
    io.fd = fd;
    io.sniHost = hostUTF8;
    io.sniLen = strlen(hostUTF8);
    io.mode = (int)fragmentMode;

    ctx = SSL_CTX_new(TLSv1_2_client_method());
    if (!ctx) {
        close(fd);
        if (error) *error = awgOpenSSLError(-5, @"SSL_CTX_new failed");
        return nil;
    }

    SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, NULL);
    SSL_CTX_set_verify_depth(ctx, 8);
    SSL_CTX_set_options(ctx, SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_COMPRESSION);
    const char *roots[] = {MTOnegramCoreTLSRoots, OGDanteTLSRoots};
    for (NSUInteger i = 0; i < sizeof(roots) / sizeof(roots[0]); i++) {
        BIO *certificates = BIO_new_mem_buf((void *)roots[i], -1);
        X509 *certificate;
        while (certificates && (certificate = PEM_read_bio_X509(certificates, NULL, NULL, NULL))) {
            X509_STORE_add_cert(SSL_CTX_get_cert_store(ctx), certificate);
            X509_free(certificate);
        }
        BIO_free(certificates);
        ERR_clear_error();
    }

    ssl = SSL_new(ctx);
    if (!ssl) {
        SSL_CTX_free(ctx);
        close(fd);
        if (error) *error = awgOpenSSLError(-5, @"SSL_new failed");
        return nil;
    }

    readBIO = BIO_new(gAWGBIOMethod);
    writeBIO = BIO_new(gAWGBIOMethod);
    if (!readBIO || !writeBIO) {
        if (readBIO) BIO_free(readBIO);
        if (writeBIO) BIO_free(writeBIO);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        close(fd);
        if (error) *error = awgOpenSSLError(-5, @"BIO_new failed");
        return nil;
    }

    readBIO->ptr = &io;
    readBIO->init = 1;
    writeBIO->ptr = &io;
    writeBIO->init = 1;
    SSL_set_bio(ssl, readBIO, writeBIO);
    readBIO = NULL;
    writeBIO = NULL;

    X509_VERIFY_PARAM *parameters = SSL_get0_param(ssl);
    X509_VERIFY_PARAM_set_hostflags(parameters, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
    if (X509_VERIFY_PARAM_set1_host(parameters, hostUTF8, 0) != 1 || SSL_set_tlsext_host_name(ssl, hostUTF8) != 1) {
        if (error) *error = awgError(-8, @"Unable to configure TLS hostname verification");
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        close(fd);
        return nil;
    }
    deadline = [NSDate dateWithTimeIntervalSinceNow:15.0];

    for (;;) {
        rc = SSL_connect(ssl);
        if (rc == 1) break;
        sslError = SSL_get_error(ssl, rc);
        if ((sslError == SSL_ERROR_WANT_READ || sslError == SSL_ERROR_WANT_WRITE) && [deadline timeIntervalSinceNow] > 0) {
            usleep(5000);
            continue;
        }
        DLog(@"[AWG/TLS] handshake failed: %d", sslError);
        if (error) *error = awgOpenSSLError(-8, [NSString stringWithFormat:@"TLS handshake failed (%d)", sslError]);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        close(fd);
        return nil;
    }

    DLog(@"[AWG/TLS] negotiated %s, %s", SSL_get_version(ssl), SSL_get_cipher(ssl));

    request = [NSMutableString stringWithFormat:
               @"POST %@ HTTP/1.1\r\nHost: %@\r\nConnection: close\r\nContent-Length: %lu\r\n",
               [path length] ? path : @"/", host, (unsigned long)[body length]];
    keyEnumerator = [headers keyEnumerator];
    while ((key = [keyEnumerator nextObject])) {
        [request appendFormat:@"%@: %@\r\n", key, [headers objectForKey:key]];
    }
    [request appendString:@"\r\n"];

    out = [NSMutableData dataWithData:[request dataUsingEncoding:NSUTF8StringEncoding]];
    if ([body length]) [out appendData:body];
    outBytes = (const uint8_t *)[out bytes];
    outLength = [out length];
    sent = 0;

    while (sent < outLength) {
        rc = SSL_write(ssl, outBytes + sent, (int)(outLength - sent));
        if (rc > 0) {
            sent += (NSUInteger)rc;
            continue;
        }
        sslError = SSL_get_error(ssl, rc);
        if ((sslError == SSL_ERROR_WANT_READ || sslError == SSL_ERROR_WANT_WRITE) && [deadline timeIntervalSinceNow] > 0) continue;
        if (error) *error = awgOpenSSLError(-9, [NSString stringWithFormat:@"SSL_write failed (%d)", sslError]);
        SSL_shutdown(ssl);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        close(fd);
        return nil;
    }

    raw = [NSMutableData data];
    deadline = [NSDate dateWithTimeIntervalSinceNow:15.0];
    for (;;) {
        rc = SSL_read(ssl, buffer, sizeof(buffer));
        if (rc > 0) {
            [raw appendBytes:buffer length:(NSUInteger)rc];
            if ([raw length] > 4 * 1024 * 1024) break;
            if ([deadline timeIntervalSinceNow] <= 0) break;
            continue;
        }
        sslError = SSL_get_error(ssl, rc);
        if (sslError == SSL_ERROR_ZERO_RETURN) break;
        if (sslError == SSL_ERROR_WANT_READ || sslError == SSL_ERROR_WANT_WRITE) {
            if ([deadline timeIntervalSinceNow] <= 0) {
                DLog(@"[AWG/TLS] response read timed out after %lu bytes", (unsigned long)[raw length]);
                break;
            }
            usleep(20000);
            continue;
        }
        break;
    }

    SSL_shutdown(ssl);
    SSL_free(ssl);
    SSL_CTX_free(ctx);
    close(fd);

    if ([raw length] == 0) {
        if (error) *error = awgError(-6, @"Empty response");
        return nil;
    }

    headEnd = awgRangeOfBytes(raw, separator, sizeof(separator));
    if (headEnd.location == NSNotFound) {
        if (error) *error = awgError(-7, @"Malformed HTTP response");
        return nil;
    }

    head = [[NSString alloc] initWithData:[raw subdataWithRange:NSMakeRange(0, headEnd.location)]
                                  encoding:NSUTF8StringEncoding];
    headLines = [head componentsSeparatedByString:@"\r\n"];
    if ([headLines count] > 0) {
        NSArray *statusParts = [[headLines objectAtIndex:0] componentsSeparatedByString:@" "];
        if ([statusParts count] > 1) code = [[statusParts objectAtIndex:1] integerValue];
    }
    if (outStatus) *outStatus = code;

    payloadStart = headEnd.location + headEnd.length;
    payload = [raw subdataWithRange:NSMakeRange(payloadStart, [raw length] - payloadStart)];
    if ([head rangeOfString:@"chunked" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        payload = [self dechunk:payload];
    }

    DLog(@"[AWG/TLS] HTTP %ld, %lu bytes of body (raw %lu)",
         (long)code, (unsigned long)[payload length], (unsigned long)[raw length]);
    for (NSString *line in headLines) {
        NSString *lower = [line lowercaseString];
        if ([lower hasPrefix:@"content-length"] || [lower hasPrefix:@"transfer-encoding"] ||
            [lower hasPrefix:@"connection"] || [lower hasPrefix:@"content-encoding"]) {
            DLog(@"[AWG/TLS]   %@", line);
        }
    }
    if (!payload) {
        if (error) *error = awgError(-7, @"Incomplete chunked response");
    } else {
        for (NSString *line in headLines) {
            if ([[line lowercaseString] hasPrefix:@"content-length:"]) {
                NSInteger expected = [[line substringFromIndex:15] integerValue];
                if (expected < 0 || (NSUInteger)expected != payload.length) {
                    if (error) *error = awgError(-7, @"Incomplete HTTP response");
                    payload = nil;
                }
            }
        }
    }
    [head release];
    return payload;
}

+ (NSData *)dechunk:(NSData *)data {
    NSMutableData *out = [NSMutableData data];
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    NSUInteger offset = 0;
    while (offset < length) {
        NSUInteger end = offset;
        while (end + 1 < length && !(bytes[end] == '\r' && bytes[end + 1] == '\n')) end++;
        if (end + 1 >= length || end == offset || end - offset >= 32) return nil;
        char line[32];
        memcpy(line, bytes + offset, end - offset);
        line[end - offset] = 0;
        char *tail;
        errno = 0;
        unsigned long size = strtoul(line, &tail, 16);
        if (errno || tail == line || (*tail && *tail != ';')) return nil;
        offset = end + 2;
        if (!size) return out;
        if (offset > length || size > length - offset || length - offset - size < 2) return nil;
        if (bytes[offset + size] != '\r' || bytes[offset + size + 1] != '\n') return nil;
        [out appendBytes:bytes + offset length:(NSUInteger)size];
        offset += size + 2;
    }
    return nil;
}

@end
