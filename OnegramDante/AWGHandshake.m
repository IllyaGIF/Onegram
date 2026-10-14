#import "OGDanteSupport.h"
#import "AWGHandshake.h"
#import "AWGConfig.h"
#import "AWGCrypto.h"
#import "monocypher.h"
#import "blake2s.h"
#include <sys/time.h>

const NSUInteger kAWGInitiationLength   = 148;
const NSUInteger kAWGResponseLength     = 92;
const NSUInteger kAWGTransportHeaderLen = 16;

static const uint32_t kWGHandshakeInitiation = 1;
static const uint32_t kWGHandshakeResponse   = 2;
static const uint32_t kWGPacketData          = 4;

static const char kWGConstruction[] = "Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s";
static const char kWGIdentifier[]   = "WireGuard v1 zx2c4 Jason@zx2c4.com";
static const char kWGLabelMAC1[]    = "mac1----";

static NSError *AWGHandshakeMakeError(NSInteger code, NSString *description) {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(description ? description : @"")
                                                     forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:@"AWGHandshake" code:code userInfo:info];
}

@interface AWGHandshake () {
    AWGConfig *_config;

    uint8_t _staticPrivate[32];
    uint8_t _staticPublic[32];
    uint8_t _ephemeralPrivate[32];
    uint8_t _ephemeralPublic[32];
    uint8_t _remoteStaticPublic[32];
    uint8_t _presharedKey[32];
    uint8_t _mac1Key[32];

    uint8_t _chainingKey[32];
    uint8_t _handshakeHash[32];

    uint32_t _localIndex;
    uint32_t _remoteIndex;

    BOOL _haveStatic;
    BOOL _havePeer;
}
@end

@implementation AWGHandshake


static inline void store32le(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v);       p[1] = (uint8_t)(v >> 8);
    p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24);
}

static inline uint32_t load32le(const uint8_t *p) {
    return ((uint32_t)p[0])       | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static inline void store64le(uint8_t *p, uint64_t v) {
    int i;
    for (i = 0; i < 8; i++) p[i] = (uint8_t)(v >> (8 * i));
}

static inline uint64_t load64le(const uint8_t *p) {
    uint64_t v = 0;
    int i;
    for (i = 7; i >= 0; i--) v = (v << 8) | p[i];
    return v;
}

static void randomBytes(uint8_t *buf, size_t len) {
    size_t i;
    for (i = 0; i < len; i++) buf[i] = (uint8_t)DanteRandomUniform(256);
}


static void wg_hash2(uint8_t out[32], const void *a, size_t alen, const void *b, size_t blen) {
    blake2s_state S;
    blake2s_init(&S, 32);
    if (alen) blake2s_update(&S, a, alen);
    if (blen) blake2s_update(&S, b, blen);
    blake2s_final(&S, out);
}

static void wg_mac(uint8_t out[16], const uint8_t key[32], const void *in, size_t inlen) {
    blake2s(out, 16, key, 32, in, inlen);
}

static void wg_kdf(uint8_t *out1, uint8_t *out2, uint8_t *out3,
                   const uint8_t key[32], const void *input, size_t inputLen) {
    uint8_t prk[32];
    uint8_t t1[32], t2[32];
    uint8_t buf[33];

    blake2s_hmac(prk, key, 32, input, inputLen);

    buf[0] = 0x01;
    blake2s_hmac(t1, prk, 32, buf, 1);
    if (out1) memcpy(out1, t1, 32);

    if (out2 || out3) {
        memcpy(buf, t1, 32);
        buf[32] = 0x02;
        blake2s_hmac(t2, prk, 32, buf, 33);
        if (out2) memcpy(out2, t2, 32);
    }
    if (out3) {
        memcpy(buf, t2, 32);
        buf[32] = 0x03;
        blake2s_hmac(out3, prk, 32, buf, 33);
    }

    crypto_wipe(prk, sizeof(prk));
    crypto_wipe(t1, sizeof(t1));
    crypto_wipe(t2, sizeof(t2));
    crypto_wipe(buf, sizeof(buf));
}

static void aead_encrypt(uint8_t *out, const uint8_t key[32], const uint8_t nonce12[12],
                         const uint8_t *plain, size_t plainLen,
                         const uint8_t *ad, size_t adLen) {
    crypto_aead_ctx ctx;
    crypto_aead_init_ietf(&ctx, key, nonce12);
    crypto_aead_write(&ctx, out, out + plainLen, ad, adLen, plain, plainLen);
    crypto_wipe(&ctx, sizeof(ctx));
}

static int aead_decrypt(uint8_t *out, const uint8_t key[32], const uint8_t nonce12[12],
                        const uint8_t *cipher, size_t plainLen,
                        const uint8_t *ad, size_t adLen) {
    crypto_aead_ctx ctx;
    int rc;
    crypto_aead_init_ietf(&ctx, key, nonce12);
    rc = crypto_aead_read(&ctx, out, cipher + plainLen, ad, adLen, cipher, plainLen);
    crypto_wipe(&ctx, sizeof(ctx));
    return rc;
}


- (instancetype)initWithConfig:(AWGConfig *)config {
    self = [super init];
    if (self) {
        _config = [config retain];
        [self reset];

        NSData *priv = [AWGCrypto base64Decode:config.privateKey];
        if (priv.length == 32) {
            memcpy(_staticPrivate, priv.bytes, 32);
            crypto_x25519_public_key(_staticPublic, _staticPrivate);
            _haveStatic = YES;
        }

        NSData *peerPub = [AWGCrypto base64Decode:config.peerPublicKey];
        if (peerPub.length == 32) {
            memcpy(_remoteStaticPublic, peerPub.bytes, 32);
            _havePeer = YES;

            wg_hash2(_mac1Key, kWGLabelMAC1, sizeof(kWGLabelMAC1) - 1, _remoteStaticPublic, 32);
        }

        memset(_presharedKey, 0, 32);
        if (config.presharedKey.length > 0) {
            NSData *psk = [AWGCrypto base64Decode:config.presharedKey];
            if (psk.length == 32) memcpy(_presharedKey, psk.bytes, 32);
        }
    }
    return self;
}

- (void)reset {
    _state = AWGHandshakeStateIdle;
    _localIndex = arc4random();
    _remoteIndex = 0;
    [_sendingKey release];
    _sendingKey = nil;
    [_receivingKey release];
    _receivingKey = nil;
    crypto_wipe(_chainingKey, sizeof(_chainingKey));
    crypto_wipe(_handshakeHash, sizeof(_handshakeHash));
    crypto_wipe(_ephemeralPrivate, sizeof(_ephemeralPrivate));
}

- (void)dealloc {
    crypto_wipe(_staticPrivate, sizeof(_staticPrivate));
    crypto_wipe(_ephemeralPrivate, sizeof(_ephemeralPrivate));
    crypto_wipe(_presharedKey, sizeof(_presharedKey));
    crypto_wipe(_chainingKey, sizeof(_chainingKey));
    [_config release];
    [_sendingKey release];
    [_receivingKey release];
    [super dealloc];
}


- (void)writeHeader:(uint8_t *)dst forType:(uint32_t)standardType {
    uint32_t value = standardType;
    switch (standardType) {
        case kWGHandshakeInitiation: if (_config.h1) value = (uint32_t)_config.h1; break;
        case kWGHandshakeResponse:   if (_config.h2) value = (uint32_t)_config.h2; break;
        case kWGPacketData:          if (_config.h4) value = (uint32_t)_config.h4; break;
        default: break;
    }
    store32le(dst, value);
}

- (void)applyReservedBytes:(uint8_t *)header {
    if (![_config hasReservedBytes]) return;
    uint8_t reserved[3];
    [_config copyReservedBytes:reserved];
    memcpy(header + 1, reserved, 3);
}

- (uint32_t)expectedHeaderValueForType:(uint32_t)standardType {
    switch (standardType) {
        case kWGHandshakeInitiation: return _config.h1 ? (uint32_t)_config.h1 : standardType;
        case kWGHandshakeResponse:   return _config.h2 ? (uint32_t)_config.h2 : standardType;
        case kWGPacketData:          return _config.h4 ? (uint32_t)_config.h4 : standardType;
        default: return standardType;
    }
}

- (BOOL)header:(const uint8_t *)bytes matchesType:(uint32_t)standardType {
    uint32_t expected = [self expectedHeaderValueForType:standardType];
    uint32_t actual = load32le(bytes);
    if (actual == expected) return YES;
    if ([_config hasReservedBytes] && expected < 256) {
        return (actual & 0xFFu) == expected;
    }
    return NO;
}


static NSData *decodeSignatureValue(NSString *raw) {
    if (raw.length == 0) return nil;
    NSString *s = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return nil;

    NSMutableData *out = [NSMutableData data];
    NSScanner *scanner = [NSScanner scannerWithString:s];
    [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL sawToken = NO;

    while (![scanner isAtEnd]) {
        NSUInteger restart = (NSUInteger)[scanner scanLocation];
        if (![scanner scanString:@"<" intoString:NULL]) break;

        NSString *body = nil;
        if (![scanner scanUpToString:@">" intoString:&body] || ![scanner scanString:@">" intoString:NULL]) {
            [scanner setScanLocation:(NSInteger)restart];
            break;
        }
        sawToken = YES;
        body = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        if ([[body lowercaseString] hasPrefix:@"b"]) {
            NSString *hex = [[body substringFromIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([[hex lowercaseString] hasPrefix:@"0x"]) hex = [hex substringFromIndex:2];
            NSUInteger i;
            for (i = 0; i + 1 < hex.length; i += 2) {
                unsigned int byte = 0;
                NSScanner *hs = [NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]];
                if (![hs scanHexInt:&byte]) break;
                uint8_t b = (uint8_t)byte;
                [out appendBytes:&b length:1];
            }
        } else if ([[body lowercaseString] hasPrefix:@"r"]) {
            NSInteger n = [[body substringFromIndex:1] integerValue];
            if (n > 0 && n <= 1024) {
                uint8_t buf[1024];
                randomBytes(buf, (size_t)n);
                [out appendBytes:buf length:(NSUInteger)n];
            }
        } else if ([[body lowercaseString] hasPrefix:@"t"]) {
            struct timeval tv;
            gettimeofday(&tv, NULL);
            uint8_t ts[4];
            store32le(ts, (uint32_t)tv.tv_sec);
            [out appendBytes:ts length:4];
        } else if ([[body lowercaseString] hasPrefix:@"c"]) {
            uint8_t ctr[4];
            store32le(ctr, 1);
            [out appendBytes:ctr length:4];
        }
    }

    if (sawToken) return out.length > 0 ? out : nil;

    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    if (s.length % 2 == 0 && [s rangeOfCharacterFromSet:nonHex].location == NSNotFound) {
        NSUInteger i;
        for (i = 0; i + 1 < s.length; i += 2) {
            unsigned int byte = 0;
            NSScanner *hs = [NSScanner scannerWithString:[s substringWithRange:NSMakeRange(i, 2)]];
            if (![hs scanHexInt:&byte]) break;
            uint8_t b = (uint8_t)byte;
            [out appendBytes:&b length:1];
        }
        return out.length > 0 ? out : nil;
    }
    return [s dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSArray *)signatureDatagrams {
    NSMutableArray *packets = [NSMutableArray array];
    NSArray *sigs = [NSArray arrayWithObjects:_config.i1 ?: @"", _config.i2 ?: @"", _config.i3 ?: @"",
                     _config.i4 ?: @"", _config.i5 ?: @"", nil];
    for (NSString *s in sigs) {
        NSData *blob = decodeSignatureValue(s);
        if (blob.length > 0) [packets addObject:blob];
    }
    return packets;
}

- (NSArray *)junkDatagrams {
    NSUInteger count = _config.junkCount;
    NSUInteger minLen = _config.junkMin;
    NSUInteger maxLen = _config.junkMax;
    if (count == 0) return [NSArray array];
    if (maxLen < minLen) maxLen = minLen;
    if (maxLen == 0) return [NSArray array];
    if (count > 32) count = 32;
    if (maxLen > 1400) maxLen = 1400;

    NSMutableArray *packets = [NSMutableArray arrayWithCapacity:count];
    NSUInteger i;
    for (i = 0; i < count; i++) {
        NSUInteger len = minLen;
        if (maxLen > minLen) len += (NSUInteger)DanteRandomUniform((uint32_t)(maxLen - minLen + 1));
        if (len == 0) continue;
        NSMutableData *d = [NSMutableData dataWithLength:len];
        randomBytes(d.mutableBytes, len);
        [packets addObject:d];
    }
    return packets;
}


- (NSArray *)buildInitiationDatagrams {
    if (!_haveStatic || !_havePeer) return nil;
    if (_state == AWGHandshakeStateEstablished) return nil;

    uint8_t initiation[148];
    memset(initiation, 0, sizeof(initiation));

    wg_hash2(_chainingKey, kWGConstruction, sizeof(kWGConstruction) - 1, NULL, 0);
    wg_hash2(_handshakeHash, _chainingKey, 32, kWGIdentifier, sizeof(kWGIdentifier) - 1);
    wg_hash2(_handshakeHash, _handshakeHash, 32, _remoteStaticPublic, 32);

    randomBytes(_ephemeralPrivate, 32);
    _ephemeralPrivate[0]  &= 248;
    _ephemeralPrivate[31] &= 127;
    _ephemeralPrivate[31] |= 64;
    crypto_x25519_public_key(_ephemeralPublic, _ephemeralPrivate);

    wg_kdf(_chainingKey, NULL, NULL, _chainingKey, _ephemeralPublic, 32);
    wg_hash2(_handshakeHash, _handshakeHash, 32, _ephemeralPublic, 32);

    uint8_t shared[32], key[32], nonce[12];
    memset(nonce, 0, sizeof(nonce));
    crypto_x25519(shared, _ephemeralPrivate, _remoteStaticPublic);
    wg_kdf(_chainingKey, key, NULL, _chainingKey, shared, 32);

    uint8_t encryptedStatic[48];
    aead_encrypt(encryptedStatic, key, nonce, _staticPublic, 32, _handshakeHash, 32);
    wg_hash2(_handshakeHash, _handshakeHash, 32, encryptedStatic, 48);

    crypto_x25519(shared, _staticPrivate, _remoteStaticPublic);
    wg_kdf(_chainingKey, key, NULL, _chainingKey, shared, 32);

    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t secs = (uint64_t)tv.tv_sec + 0x400000000000000aULL;
    uint32_t nanos = (uint32_t)tv.tv_usec * 1000;
    uint8_t timestamp[12];
    int i;
    for (i = 0; i < 8; i++) timestamp[i] = (uint8_t)(secs >> (56 - 8 * i));
    for (i = 0; i < 4; i++) timestamp[8 + i] = (uint8_t)(nanos >> (24 - 8 * i));

    uint8_t encryptedTimestamp[28];
    aead_encrypt(encryptedTimestamp, key, nonce, timestamp, 12, _handshakeHash, 32);
    wg_hash2(_handshakeHash, _handshakeHash, 32, encryptedTimestamp, 28);

    [self writeHeader:initiation forType:kWGHandshakeInitiation];
    store32le(initiation + 4, _localIndex);
    memcpy(initiation + 8, _ephemeralPublic, 32);
    memcpy(initiation + 40, encryptedStatic, 48);
    memcpy(initiation + 88, encryptedTimestamp, 28);

    uint8_t mac1[16];
    wg_mac(mac1, _mac1Key, initiation, 116);
    memcpy(initiation + 116, mac1, 16);
    memset(initiation + 132, 0, 16);

    [self applyReservedBytes:initiation];

    crypto_wipe(shared, sizeof(shared));
    crypto_wipe(key, sizeof(key));

    NSMutableData *initDatagram = [NSMutableData data];
    if (_config.s1 > 0 && _config.s1 <= 1024) {
        NSMutableData *pad = [NSMutableData dataWithLength:_config.s1];
        randomBytes(pad.mutableBytes, _config.s1);
        [initDatagram appendData:pad];
    }
    [initDatagram appendBytes:initiation length:sizeof(initiation)];

    NSMutableArray *datagrams = [NSMutableArray array];
    [datagrams addObjectsFromArray:[self signatureDatagrams]];
    [datagrams addObjectsFromArray:[self junkDatagrams]];
    [datagrams addObject:initDatagram];

    _state = AWGHandshakeStateInitSent;
    return datagrams;
}


- (BOOL)processResponse:(NSData *)packet error:(NSError **)error {
    if (_state != AWGHandshakeStateInitSent) {
        if (error) *error = AWGHandshakeMakeError(-1, @"Not in InitSent state");
        return NO;
    }

    NSUInteger offset = (_config.s2 > 0 && packet.length > _config.s2 + kAWGResponseLength - 1) ? _config.s2 : 0;
    if (packet.length < offset + kAWGResponseLength) {
        if (error) *error = AWGHandshakeMakeError(-2, @"Response too short");
        return NO;
    }

    const uint8_t *bytes = (const uint8_t *)packet.bytes + offset;
    if (![self header:bytes matchesType:kWGHandshakeResponse]) {
        if (error) *error = AWGHandshakeMakeError(-3, @"Not a handshake response");
        return NO;
    }

    uint32_t theirSender = load32le(bytes + 4);
    uint32_t theirReceiver = load32le(bytes + 8);
    if (theirReceiver != _localIndex) {
        if (error) *error = AWGHandshakeMakeError(-5, @"Response for another session");
        return NO;
    }

    uint8_t remoteEphemeral[32];
    memcpy(remoteEphemeral, bytes + 12, 32);
    const uint8_t *encryptedNothing = bytes + 44;

    uint8_t ck[32], h[32];
    memcpy(ck, _chainingKey, 32);
    memcpy(h, _handshakeHash, 32);

    wg_kdf(ck, NULL, NULL, ck, remoteEphemeral, 32);
    wg_hash2(h, h, 32, remoteEphemeral, 32);

    uint8_t shared[32];
    crypto_x25519(shared, _ephemeralPrivate, remoteEphemeral);
    wg_kdf(ck, NULL, NULL, ck, shared, 32);
    crypto_x25519(shared, _staticPrivate, remoteEphemeral);
    wg_kdf(ck, NULL, NULL, ck, shared, 32);

    uint8_t tau[32], key[32];
    wg_kdf(ck, tau, key, ck, _presharedKey, 32);
    wg_hash2(h, h, 32, tau, 32);

    uint8_t nonce[12];
    uint8_t emptyPlain[1];
    memset(nonce, 0, sizeof(nonce));
    if (aead_decrypt(emptyPlain, key, nonce, encryptedNothing, 0, h, 32) != 0) {
        crypto_wipe(ck, sizeof(ck));
        crypto_wipe(key, sizeof(key));
        crypto_wipe(shared, sizeof(shared));
        _state = AWGHandshakeStateFailed;
        if (error) *error = AWGHandshakeMakeError(-4, @"Handshake decryption failed");
        return NO;
    }
    wg_hash2(h, h, 32, encryptedNothing, 16);

    uint8_t sendKey[32], recvKey[32];
    wg_kdf(sendKey, recvKey, NULL, ck, NULL, 0);

    [_sendingKey release];
    _sendingKey = [[NSData alloc] initWithBytes:sendKey length:32];
    [_receivingKey release];
    _receivingKey = [[NSData alloc] initWithBytes:recvKey length:32];
    _remoteIndex = theirSender;
    memcpy(_chainingKey, ck, 32);
    memcpy(_handshakeHash, h, 32);
    _state = AWGHandshakeStateEstablished;

    crypto_wipe(ck, sizeof(ck));
    crypto_wipe(key, sizeof(key));
    crypto_wipe(tau, sizeof(tau));
    crypto_wipe(shared, sizeof(shared));
    crypto_wipe(sendKey, sizeof(sendKey));
    crypto_wipe(recvKey, sizeof(recvKey));
    crypto_wipe(_ephemeralPrivate, sizeof(_ephemeralPrivate));
    return YES;
}

- (BOOL)isEstablished {
    return _state == AWGHandshakeStateEstablished;
}


+ (void)transportNonce:(uint8_t *)out12 forCounter:(uint64_t)counter {
    memset(out12, 0, 4);
    store64le(out12 + 4, counter);
}

- (size_t)writeTransportHeader:(uint8_t *)outHeader counter:(uint64_t)counter {
    memset(outHeader, 0, 16);
    [self writeHeader:outHeader forType:kWGPacketData];
    store32le(outHeader + 4, _remoteIndex);
    store64le(outHeader + 8, counter);
    [self applyReservedBytes:outHeader];
    return 16;
}

- (NSData *)transportHeaderWithCounter:(uint64_t)counter {
    uint8_t header[16];
    [self writeTransportHeader:header counter:counter];
    return [NSData dataWithBytes:header length:sizeof(header)];
}

- (NSUInteger)transportPayloadOffsetForBytes:(const uint8_t *)bytes length:(size_t)length counter:(uint64_t *)outCounter {
    if (length < kAWGTransportHeaderLen + 16) return NSNotFound;
    if (![self header:bytes matchesType:kWGPacketData]) return NSNotFound;

    if (load32le(bytes + 4) != _localIndex) return NSNotFound;
    if (outCounter) *outCounter = load64le(bytes + 8);
    return kAWGTransportHeaderLen;
}

- (NSUInteger)transportPayloadOffsetForPacket:(NSData *)packet counter:(uint64_t *)outCounter {
    return [self transportPayloadOffsetForBytes:packet.bytes length:packet.length counter:outCounter];
}

@end
