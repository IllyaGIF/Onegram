#import "PowerConfig.h"
#import "PowerVLESS.h"

static NSString *PWUnescape(NSString *s) {
    if (!s.length) return s;
    return [s stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: s;
}

static NSData *PWDecodeBase64(NSString *text) {
    static const int8_t table[128] = {
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,62,-1,63,   
        52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-1,-1,-1,
        -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,
        15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,63,
        -1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
        41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1
    };
    const char *in = [text UTF8String];
    if (!in) return nil;
    NSMutableData *out = [NSMutableData dataWithCapacity:strlen(in) * 3 / 4 + 3];
    uint32_t acc = 0;
    int bits = 0;
    for (const char *p = in; *p; p++) {
        unsigned char c = (unsigned char)*p;
        if (c == '=') break;
        if (c >= 128) continue;
        int v = table[c];
        if (v < 0) continue;              
        acc = (acc << 6) | (uint32_t)v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            uint8_t byte = (uint8_t)((acc >> bits) & 0xff);
            [out appendBytes:&byte length:1];
        }
    }
    return out.length ? out : nil;
}

static NSDictionary *PWParseQuery(NSString *query) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        if (!pair.length) continue;
        NSRange eq = [pair rangeOfString:@"="];
        if (eq.location == NSNotFound) {
            [out setObject:@"" forKey:[pair lowercaseString]];
            continue;
        }
        NSString *k = [[pair substringToIndex:eq.location] lowercaseString];
        NSString *v = PWUnescape([pair substringFromIndex:eq.location + 1]);
        if (k.length) [out setObject:v ?: @"" forKey:k];
    }
    return out;
}

@implementation PowerConfig

+ (instancetype)configFromURI:(NSString *)uri {
    NSString *s = [uri stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![[s lowercaseString] hasPrefix:@"vless://"]) return nil;
    s = [s substringFromIndex:8];

    PowerConfig *c = [[[PowerConfig alloc] init] autorelease];

    NSRange hash = [s rangeOfString:@"#"];
    if (hash.location != NSNotFound) {
        c.name = PWUnescape([s substringFromIndex:hash.location + 1]);
        s = [s substringToIndex:hash.location];
    }

    NSDictionary *q = nil;
    NSRange qm = [s rangeOfString:@"?"];
    if (qm.location != NSNotFound) {
        q = PWParseQuery([s substringFromIndex:qm.location + 1]);
        s = [s substringToIndex:qm.location];
    }

    NSRange at = [s rangeOfString:@"@" options:NSBackwardsSearch];
    if (at.location == NSNotFound) return nil;
    c.uuid = [s substringToIndex:at.location];
    NSString *hostPort = [s substringFromIndex:at.location + 1];

    uint8_t probe[PW_UUID_LEN];
    if (PWParseUUID([c.uuid UTF8String], probe) != PWVLESSOk) return nil;

    NSRange colon = [hostPort rangeOfString:@":" options:NSBackwardsSearch];
    if (colon.location == NSNotFound) return nil;
    c.host = [hostPort substringToIndex:colon.location];
    if ([c.host hasPrefix:@"["] && [c.host hasSuffix:@"]"]) {
        c.host = [c.host substringWithRange:NSMakeRange(1, c.host.length - 2)];
    }
    NSString *portText = [hostPort substringFromIndex:colon.location + 1];
    NSScanner *portScanner = [NSScanner scannerWithString:portText];
    int port = 0;
    if (![portScanner scanInt:&port] || !portScanner.isAtEnd) return nil;
    if (!c.host.length || port <= 0 || port > 65535) return nil;
    c.port = (uint16_t)port;

    NSString *security = [[q objectForKey:@"security"] lowercaseString] ?: @"none";
    if ([security isEqualToString:@"reality"]) c.security = PWSecurityReality;
    else if ([security isEqualToString:@"tls"] || [security isEqualToString:@"xtls"]) c.security = PWSecurityTLS;
    else if ([security isEqualToString:@"none"]) c.security = PWSecurityNone;
    else c.security = PWSecurityUnknown;

    NSString *type = [[q objectForKey:@"type"] lowercaseString] ?: @"tcp";
    if ([type isEqualToString:@"ws"]) c.transport = PWTransportWS;
    else if ([type isEqualToString:@"xhttp"] || [type isEqualToString:@"splithttp"]) c.transport = PWTransportXHTTP;
    else if ([type isEqualToString:@"grpc"]) c.transport = PWTransportGRPC;
    else if ([type isEqualToString:@"tcp"]) c.transport = PWTransportTCP;
    else c.transport = PWTransportUnknown;

    c.sni         = [q objectForKey:@"sni"] ?: [q objectForKey:@"peer"] ?: c.host;
    c.flow        = [q objectForKey:@"flow"] ?: @"";
    c.path        = [q objectForKey:@"path"] ?: @"/";
    c.hostHeader  = [q objectForKey:@"host"] ?: @"";
    c.publicKey   = [q objectForKey:@"pbk"] ?: @"";
    c.shortID     = [q objectForKey:@"sid"] ?: @"";
    c.fingerprint = [q objectForKey:@"fp"] ?: @"chrome";
    NSString *alpn = [q objectForKey:@"alpn"];
    c.alpn = alpn.length ? [alpn componentsSeparatedByString:@","] : nil;
    NSString *insecure = [q objectForKey:@"allowinsecure"];
    c.allowInsecure = [insecure isEqualToString:@"1"] || [[insecure lowercaseString] isEqualToString:@"true"];

    if (!c.name.length) c.name = [NSString stringWithFormat:@"%@:%u", c.host, c.port];
    return c;
}

+ (NSArray *)linesFromText:(NSString *)text {
    NSString *body = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([body rangeOfString:@"://"].location == NSNotFound && body.length > 16) {
        NSData *decoded = PWDecodeBase64(body);
        NSString *inner = decoded ? [[[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding] autorelease] : nil;
        if (inner.length) body = inner;
    }
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *raw in [body componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!t.length || [t hasPrefix:@"#"] || [out containsObject:t]) continue;
        if ([PowerConfig configFromURI:t]) [out addObject:t];
    }
    return out;
}

+ (NSArray *)configsFromText:(NSString *)text {
    if (!text.length) return @[];
    NSString *body = [text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if ([body rangeOfString:@"://"].location == NSNotFound && body.length > 16) {
        NSData *decoded = PWDecodeBase64(body);
        NSString *inner = decoded ? [[[NSString alloc] initWithData:decoded
                                                          encoding:NSUTF8StringEncoding] autorelease] : nil;
        if (inner.length) body = inner;
    }

    NSMutableArray *out = [NSMutableArray array];
    for (NSString *line in [body componentsSeparatedByCharactersInSet:
                            [NSCharacterSet newlineCharacterSet]]) {
        PowerConfig *c = [PowerConfig configFromURI:line];
        if (c) [out addObject:c];
    }
    return out;
}

- (BOOL)isSupported {
    return [self unsupportedReason] == nil;
}

- (NSString *)unsupportedReason {
    if (self.security == PWSecurityUnknown) return @"Неизвестный режим защиты VLESS";
    if (self.transport == PWTransportUnknown) return @"Неизвестный транспорт VLESS";
    if (self.transport != PWTransportTCP) {
        return @"пока только прямой TCP, без WebSocket и gRPC";
    }
    if (self.security == PWSecurityReality) {

        if (!self.publicKey.length) return @"в ссылке нет pbk (публичного ключа)";
        if (self.shortID.length > 16 || self.shortID.length % 2) return @"Некорректный sid Reality";
    }

    return nil;
}

- (NSString *)summary {
    NSString *sec = self.security == PWSecurityReality ? @"reality"
                  : self.security == PWSecurityTLS ? @"tls" : @"без шифра";
    NSString *tr = self.transport == PWTransportWS ? @"ws"
                 : self.transport == PWTransportXHTTP ? @"xhttp"
                 : self.transport == PWTransportGRPC ? @"grpc" : @"tcp";
    return [NSString stringWithFormat:@"%@:%u, %@/%@%@", self.host,
            self.port, sec, tr, self.flow.length ? [@", " stringByAppendingString:self.flow] : @""];
}

- (void)dealloc
{
    [_name release]; [_host release]; [_uuid release]; [_sni release];
    [_flow release]; [_path release]; [_hostHeader release]; [_publicKey release];
    [_shortID release]; [_fingerprint release]; [_alpn release];
    [super dealloc];
}

@end
