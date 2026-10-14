#import "AWGWarpRegistrar.h"
#import "AWGConfig.h"
#import "AWGCrypto.h"
#import "AWGHTTPSTransport.h"
#import "DanteJSON.h"
#import "OGDanteSupport.h"
#include <unistd.h>
#include <arpa/inet.h>

NSString * const kAWGWarpErrorDomain = @"AWGWarpRegistrar";

static NSString * const kWarpRegURL = @"https://api.cloudflareclient.com/v0a4471/reg";
static NSString * const kWarpClientVer = @"a-6.30-3596";
static NSString * const kWarpUserAgent = @"okhttp/3.12.1";
static NSString * const kWarpRelayDefaultsKey = @"awg_warp_relay_url";

static NSString * const kWarpAPIPinnedIPs[] = {
    @"104.16.192.82", @"104.16.24.84"
};
#define kWarpAPIPinnedCount (sizeof(kWarpAPIPinnedIPs) / sizeof(kWarpAPIPinnedIPs[0]))

static NSString * const kWarpPrefixes[] = {
    @"162.159.192", @"162.159.193", @"162.159.195",
    @"188.114.96", @"188.114.97", @"188.114.98", @"188.114.99",
    @"8.6.112", @"8.34.70", @"8.34.146", @"8.35.211",
    @"8.39.125", @"8.39.204", @"8.39.214", @"8.47.69"
};
static const NSUInteger kWarpPrefixCount = sizeof(kWarpPrefixes) / sizeof(kWarpPrefixes[0]);

static const uint16_t kWarpPorts[] = {
    500, 854, 859, 864, 878, 880, 890, 891, 894, 903,
    908, 928, 934, 939, 942, 945, 946, 955, 968, 987,
    988, 1002, 1010, 1014, 1018, 1070, 1074, 1180, 1387, 1701,
    1843, 2371, 2408, 2506, 3138, 3476, 3581, 3854, 4177, 4198,
    4500, 5279, 5956, 7103, 7152, 7156, 7281, 7559, 8319, 8742,
    8854, 8886
};
static const NSUInteger kWarpPortCount = sizeof(kWarpPorts) / sizeof(kWarpPorts[0]);

static NSError *AWGWarpError(NSInteger code, NSString *message) {
    NSDictionary *info = [NSDictionary dictionaryWithObject:(message ? message : @"WARP registration failed")
                                                       forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:kAWGWarpErrorDomain code:code userInfo:info];
}

static NSDictionary *AWGWarpRoute(NSString *ip, AWGFragmentMode mode, uint16_t socks, NSString *name) {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            (ip ? ip : @""), @"ip",
            [NSNumber numberWithInteger:(NSInteger)mode], @"mode",
            [NSNumber numberWithUnsignedInt:(unsigned int)socks], @"socks",
            (name ? name : @""), @"name",
            nil];
}

static NSData *sipSignature(NSString *text) {
    NSString *crlf = [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\r\n"];
    return [crlf dataUsingEncoding:NSUTF8StringEncoding];
}

static NSString *hexSignature(NSData *data) {
    NSMutableString *hex = [NSMutableString stringWithString:@"<b 0x"];
    const uint8_t *b = [data bytes];
    NSUInteger i;
    for (i = 0; i < [data length]; i++) [hex appendFormat:@"%02x", b[i]];
    [hex appendString:@">"];
    return hex;
}

static NSString *randomInstallID(void) {
    static const char *alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:22];
    NSUInteger i;
    for (i = 0; i < 22; i++) [s appendFormat:@"%c", alphabet[DanteRandomUniform(62)]];
    return s;
}

static NSString *tosTimestamp(void) {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    [fmt setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    [fmt setLocale:locale];
    NSString *result = [[fmt stringFromDate:[NSDate date]] retain];
    [locale release];
    [fmt release];
    return [result autorelease];
}

@implementation AWGWarpRegistrar

+ (NSString *)randomWarpEndpoint {
    NSString *prefix = kWarpPrefixes[DanteRandomUniform((uint32_t)kWarpPrefixCount)];
    uint32_t host = 1 + DanteRandomUniform(10);
    uint16_t port = kWarpPorts[DanteRandomUniform((uint32_t)kWarpPortCount)];
    return [NSString stringWithFormat:@"%@.%u:%u", prefix, (unsigned)host, (unsigned)port];
}

+ (NSArray *)warpPrefixes {
    NSMutableArray *all = [NSMutableArray array];
    NSUInteger i;
    for (i = 0; i < kWarpPrefixCount; i++) [all addObject:kWarpPrefixes[i]];
    return all;
}

+ (void)rotateEndpointForConfig:(AWGConfig *)config {
    if (!config) return;
    NSString *old = [[config peerEndpoint] retain];
    NSString *next = nil;
    NSRange colon = [old rangeOfString:@":" options:NSBackwardsSearch];
    NSString *host = ([old length] > 0 && colon.location != NSNotFound) ? [old substringToIndex:colon.location] : nil;
    NSArray *preferredPorts = [config preferredPorts];
    if ([host length] > 0 && [preferredPorts count] > 1) {
        NSUInteger tries = 0;
        do {
            NSNumber *port = [preferredPorts objectAtIndex:DanteRandomUniform((uint32_t)[preferredPorts count])];
            next = [NSString stringWithFormat:@"%@:%@", host, port];
        } while ([next isEqualToString:old] && ++tries < 8);
    }
    if ([next length] == 0 || [next isEqualToString:old]) {
        next = [self randomWarpEndpoint];
        if ([next isEqualToString:old]) next = [self randomWarpEndpoint];
    }
    [config setPeerEndpoint:next];
    DLog(@"[AWG] endpoint rotated: %@ -> %@", old ? old : @"(none)", next);
    [old release];
}

+ (void)applyWarpObfuscationProfile:(AWGConfig *)config {
    if (!config) return;
    config.junkCount = 4;
    config.junkMin = 40;
    config.junkMax = 70;
    config.s1 = 0;
    config.s2 = 0;
    config.s3 = 0;
    config.s4 = 0;
    config.h1 = 1;
    config.h2 = 2;
    config.h3 = 3;
    config.h4 = 4;
    config.mtu = 1280;
    config.allowedIPs = @"0.0.0.0/0, ::/0";
    config.dnsServers = @"1.1.1.1, 1.0.0.1, 2606:4700:4700::1111, 2606:4700:4700::1001";

    NSString *invite =
        @"INVITE sip:bob@biloxi.com SIP/2.0\n"
        @"Via: SIP/2.0/UDP pc33.atlanta.com;branch=z9hG4bK776asdhds\n"
        @"Max-Forwards: 70\n"
        @"To: Bob <sip:bob@biloxi.com>\n"
        @"From: Alice <sip:alice@atlanta.com>;tag=1928301774\n"
        @"Call-ID: a84b4c76e66710@pc33.atlanta.com\n"
        @"CSeq: 314159 INVITE\n"
        @"Contact: <sip:alice@pc33.atlanta.com>\n"
        @"Content-Type: application/sdp\n"
        @"Content-Length: 0\n\n";

    NSString *trying =
        @"SIP/2.0 100 Trying\n"
        @"Via: SIP/2.0/UDP pc33.atlanta.com;branch=z9hG4bK776asdhds\n"
        @"To: Bob <sip:bob@biloxi.com>\n"
        @"From: Alice <sip:alice@atlanta.com>;tag=1928301774\n"
        @"Call-ID: a84b4c76e66710@pc33.atlanta.com\n"
        @"CSeq: 314159 INVITE\n"
        @"Content-Length: 0\n\n";

    config.i1 = hexSignature(sipSignature(invite));
    config.i2 = hexSignature(sipSignature(trying));
    config.i3 = nil;
    config.i4 = nil;
    config.i5 = nil;
}

+ (AWGConfig *)generateConfigWithError:(NSError **)error {
    return [self generateConfigWithPrivateKey:nil error:error];
}

+ (AWGConfig *)generateConfigWithPrivateKey:(NSString *)privateKeyBase64 error:(NSError **)error {
    return [self generateConfigWithPrivateKey:privateKeyBase64 socksPort:0 error:error];
}

+ (AWGConfig *)generateConfigWithPrivateKey:(NSString *)privateKeyBase64 socksPort:(uint16_t)socksPort error:(NSError **)error {
    NSString *privateKey = privateKeyBase64;
    NSString *publicKey = nil;

    if ([privateKey length] > 0) {
        NSData *priv = [AWGCrypto base64Decode:privateKey];
        if ([priv length] != 32) privateKey = nil;
        else publicKey = [AWGCrypto base64Encode:[AWGCrypto publicKeyFromPrivateKey:priv]];
    }
    if ([privateKey length] == 0) {
        NSData *priv = [AWGCrypto generatePrivateKey];
        if (!priv) {
            if (error) *error = AWGWarpError(-13, @"Unable to generate WARP identity");
            return nil;
        }
        privateKey = [AWGCrypto base64Encode:priv];
        publicKey = [AWGCrypto base64Encode:[AWGCrypto publicKeyFromPrivateKey:priv]];
    }

    NSString *urlString = [[NSUserDefaults standardUserDefaults] stringForKey:kWarpRelayDefaultsKey];
    if ([urlString length] == 0) urlString = kWarpRegURL;

    NSDictionary *body = [NSDictionary dictionaryWithObjectsAndKeys:
                          (publicKey ? publicKey : @""), @"key",
                          randomInstallID(), @"install_id",
                          @"", @"fcm_token",
                          tosTimestamp(), @"tos",
                          @"iPhone", @"model",
                          @"", @"serial_number",
                          @"en_US", @"locale",
                          @"Android", @"type",
                          nil];

    NSError *jsonError = nil;
    NSData *payload = DanteJSONDataWithObject(body, &jsonError);
    if (!payload) {
        if (error) *error = jsonError;
        return nil;
    }

    NSURL *url = [NSURL URLWithString:urlString];
    if (![[[url scheme] lowercaseString] isEqualToString:@"https"] || !url.host.length) {
        if (error) *error = AWGWarpError(-14, @"WARP registration requires HTTPS");
        return nil;
    }
    NSString *reqHost = [url host];
    if ([reqHost length] == 0) reqHost = @"api.cloudflareclient.com";
    NSString *reqPath = [url path];
    if ([reqPath length] == 0) reqPath = @"/v0a4471/reg";
    if ([[url query] length] > 0) reqPath = [NSString stringWithFormat:@"%@?%@", reqPath, [url query]];
    uint16_t reqPort = [url port] ? (uint16_t)[[url port] unsignedShortValue] : ([[url scheme] isEqualToString:@"http"] ? 80 : 443);

    NSDictionary *hdrs = [NSDictionary dictionaryWithObjectsAndKeys:
                           @"application/json; charset=UTF-8", @"Content-Type",
                           kWarpClientVer, @"CF-Client-Version",
                           kWarpUserAgent, @"User-Agent",
                           @"application/json", @"Accept",
                           nil];

    DLog(@"[AWG] registering WARP identity at %@", urlString);

    NSData *response = nil;
    NSError *lastError = nil;
    NSArray *modes = [NSArray arrayWithObjects:
                      [NSNumber numberWithInteger:AWGFragmentNone],
                      [NSNumber numberWithInteger:AWGFragmentTiny], nil];
    NSMutableArray *plan = [NSMutableArray array];
    if (socksPort) [plan addObject:AWGWarpRoute(@"", AWGFragmentNone, socksPort, @"through the live tunnel")];

    NSMutableArray *targets = [NSMutableArray arrayWithObject:@""];
    if ([reqHost isEqualToString:@"api.cloudflareclient.com"]) {
        NSUInteger pin;
        for (pin = 0; pin < kWarpAPIPinnedCount; pin++) [targets addObject:kWarpAPIPinnedIPs[pin]];
    }

    for (NSString *target in targets) {
        for (NSNumber *modeNumber in modes) {
            AWGFragmentMode mode = (AWGFragmentMode)[modeNumber integerValue];
            NSString *name = [NSString stringWithFormat:@"%@ + %@",
                              [target length] ? target : @"system DNS",
                              AWGFragmentModeName(mode)];
            [plan addObject:AWGWarpRoute(target, mode, 0, name)];
        }
    }

    for (NSDictionary *route in plan) {
        NSError *attemptError = nil;
        NSInteger attemptStatus = 0;
        NSString *pinned = [route objectForKey:@"ip"];
        uint16_t routeSocks = (uint16_t)[[route objectForKey:@"socks"] unsignedShortValue];
        AWGFragmentMode mode = (AWGFragmentMode)[[route objectForKey:@"mode"] integerValue];

        NSData *data = [AWGHTTPSTransport postToHost:reqHost
                                           connectIP:[pinned length] ? pinned : nil
                                           socksPort:routeSocks
                                                port:reqPort
                                                path:reqPath
                                                body:payload
                                             headers:hdrs
                                        fragmentMode:mode
                                          statusCode:&attemptStatus
                                               error:&attemptError];
        if (data && attemptStatus >= 200 && attemptStatus < 300) {
            response = data;
            DLog(@"[AWG] registration path: %@ (HTTP %ld)", [route objectForKey:@"name"], (long)attemptStatus);
            break;
        }

        if (attemptError) {
            lastError = attemptError;
        } else {
            lastError = AWGWarpError(attemptStatus, [NSString stringWithFormat:@"HTTP %ld", (long)attemptStatus]);
        }
        DLog(@"[AWG] route \"%@\" failed: %@", [route objectForKey:@"name"], [lastError localizedDescription]);
    }

    AWGConfig *config = nil;
    NSError *finalError = lastError;
    if (response) {
        NSError *parseError = nil;
        config = [AWGWarpRegistrar configFromRegistrationData:response privateKey:privateKey error:&parseError];
        if (!config) {
            finalError = parseError;
            DLog(@"[AWG] WARP response unusable: %@", [parseError localizedDescription]);
        }
    }

    if (!config && !finalError) finalError = AWGWarpError(-13, @"WARP registration produced no usable response");
    if (!config && error) *error = finalError;
    return config;
}

+ (AWGConfig *)configFromRegistrationData:(NSData *)data
                               privateKey:(NSString *)privateKey
                                    error:(NSError **)error {
    NSError *jsonError = nil;
    id root = DanteJSONObjectWithData(data, &jsonError);
    if (![root isKindOfClass:[NSDictionary class]]) {
        if (error) *error = jsonError ? jsonError : AWGWarpError(-10, @"Malformed registration response");
        return nil;
    }

    NSDictionary *cfg = [(NSDictionary *)root objectForKey:@"config"];
    if (![cfg isKindOfClass:[NSDictionary class]]) {
        if (error) *error = AWGWarpError(-11, @"Response carries no config");
        return nil;
    }

    NSArray *peers = [cfg objectForKey:@"peers"];
    NSDictionary *peer = nil;
    if ([peers isKindOfClass:[NSArray class]] && [peers count] > 0) {
        id firstPeer = [peers objectAtIndex:0];
        if ([firstPeer isKindOfClass:[NSDictionary class]]) peer = firstPeer;
    }

    NSString *peerPub = [peer objectForKey:@"public_key"];
    if (![peerPub isKindOfClass:[NSString class]] || [AWGCrypto base64Decode:peerPub].length != 32) {
        if (error) *error = AWGWarpError(-12, @"Response carries no peer key");
        return nil;
    }

    AWGConfig *config = [AWGConfig configWithDefaults];
    config.label = @"Cloudflare WARP";
    config.privateKey = privateKey;
    config.publicKey = [AWGCrypto base64Encode:[AWGCrypto publicKeyFromPrivateKey:[AWGCrypto base64Decode:privateKey]]];
    config.peerPublicKey = peerPub;

    NSString *clientID = [cfg objectForKey:@"client_id"];
    if ([clientID isKindOfClass:[NSString class]]) config.warpClientID = clientID;

    NSDictionary *iface = [cfg objectForKey:@"interface"];
    NSDictionary *addrs = [iface isKindOfClass:[NSDictionary class]] ? [iface objectForKey:@"addresses"] : nil;
    if ([addrs isKindOfClass:[NSDictionary class]]) {
        NSString *v4Address = [addrs objectForKey:@"v4"];
        NSString *v6Address = [addrs objectForKey:@"v6"];
        if ([v4Address isKindOfClass:[NSString class]] && [v4Address length] > 0) {
            config.ipv4Address = [v4Address stringByAppendingString:@"/32"];
        }
        if ([v6Address isKindOfClass:[NSString class]] && [v6Address length] > 0) {
            config.ipv6Address = [v6Address stringByAppendingString:@"/128"];
        }
    }

    NSDictionary *endpoint = [peer objectForKey:@"endpoint"];
    NSString *v4Endpoint = [endpoint isKindOfClass:[NSDictionary class]] ? [endpoint objectForKey:@"v4"] : nil;
    NSString *host = nil;
    if ([v4Endpoint isKindOfClass:[NSString class]]) {
        NSRange colon = [v4Endpoint rangeOfString:@":" options:NSBackwardsSearch];
        host = colon.location != NSNotFound ? [v4Endpoint substringToIndex:colon.location] : v4Endpoint;
    }

    NSArray *returnedPorts = [endpoint isKindOfClass:[NSDictionary class]] ? [endpoint objectForKey:@"ports"] : nil;
    NSMutableArray *ports = [NSMutableArray array];
    if ([returnedPorts isKindOfClass:[NSArray class]]) {
        for (id candidate in returnedPorts) {
            if (![candidate isKindOfClass:[NSNumber class]]) continue;
            NSInteger number = [candidate integerValue];
            if (number > 0 && number <= 65535) [ports addObject:candidate];
        }
    }
    if ([host length] > 0 && [ports isKindOfClass:[NSArray class]] && [ports count] > 0) {
        config.preferredPorts = ports;
        NSNumber *port = [ports objectAtIndex:DanteRandomUniform((uint32_t)[ports count])];
        config.peerEndpoint = [NSString stringWithFormat:@"%@:%@", host, port];
    } else if ([host length] > 0) {
        uint16_t port = kWarpPorts[DanteRandomUniform((uint32_t)kWarpPortCount)];
        config.peerEndpoint = [NSString stringWithFormat:@"%@:%u", host, (unsigned)port];
    } else {
        config.peerEndpoint = [self randomWarpEndpoint];
    }

    struct in_addr address;
    NSString *ipv4 = [[config.ipv4Address componentsSeparatedByString:@"/"] objectAtIndex:0];
    if (![config hasReservedBytes] || !ipv4 || inet_pton(AF_INET, [ipv4 UTF8String], &address) != 1 || ![addrs isKindOfClass:[NSDictionary class]] || ![[addrs objectForKey:@"v4"] isKindOfClass:[NSString class]]) {
        if (error) *error = AWGWarpError(-15, @"Incomplete WARP registration response");
        return nil;
    }
    [self applyWarpObfuscationProfile:config];
    DLog(@"[AWG] WARP identity ready: %@ via %@ (client_id %@)",
         config.ipv4Address, config.peerEndpoint, config.warpClientID ? config.warpClientID : @"none");
    return config;
}

@end
