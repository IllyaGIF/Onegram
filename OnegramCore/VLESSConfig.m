#import "VLESSConfig.h"
#import "VLESSProtocol.h"
#import "VLESSEncoding.h"
#import "OGCoreJSON.h"
#include <arpa/inet.h>

static NSString *VLUnescape(NSString *s) {
    if (!s.length) return s;
    return [s stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ?: s;
}

static NSData *VLDecodeBase64(NSString *text) {
    NSData *encoded = [text dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!encoded) return nil;
    NSMutableData *decoded = [NSMutableData dataWithLength:encoded.length];
    size_t length = 0;
    if (!VLDecodeBase64Bytes(encoded.bytes, encoded.length, decoded.mutableBytes, decoded.length, &length)) return nil;
    [decoded setLength:length];
    return decoded;
}

static NSString *VLString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSDictionary *VLDictionary(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

static NSArray *VLArray(id value) {
    return [value isKindOfClass:[NSArray class]] ? value : nil;
}

static NSString *VLEscape(NSString *text) {
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)text, NULL,
        CFSTR(":/?#[]@!$&'()*+,;=%"), kCFStringEncodingUTF8) autorelease];
}

static void VLAddJSONLines(id object, NSMutableArray *lines) {
    if ([object isKindOfClass:[NSArray class]]) {
        for (id entry in object) VLAddJSONLines(entry, lines);
        return;
    }
    NSDictionary *configuration = VLDictionary(object);
    NSArray *outbounds = VLArray([configuration objectForKey:@"outbounds"]);
    if (outbounds) {
        for (id outbound in outbounds) VLAddJSONLines(outbound, lines);
        return;
    }
    if (![[configuration objectForKey:@"protocol"] isEqual:@"vless"]) return;
    NSDictionary *stream = VLDictionary([configuration objectForKey:@"streamSettings"]);
    NSString *security = VLString([stream objectForKey:@"security"]) ?: @"none";
    NSDictionary *tls = VLDictionary([stream objectForKey:[security isEqualToString:@"reality"] ? @"realitySettings" : @"tlsSettings"]);
    NSDictionary *settings = VLDictionary([configuration objectForKey:@"settings"]);
    for (id item in VLArray([settings objectForKey:@"vnext"])) {
        NSDictionary *server = VLDictionary(item);
        NSString *host = VLString([server objectForKey:@"address"]);
        id portValue = [server objectForKey:@"port"];
        if (!host.length || ![portValue isKindOfClass:[NSNumber class]]) continue;
        NSInteger port = [portValue integerValue];
        if (port < 1 || port > 65535 || [portValue doubleValue] != port) continue;
        if ([host rangeOfString:@":"].location != NSNotFound) host = [NSString stringWithFormat:@"[%@]", host];
        for (id userValue in VLArray([server objectForKey:@"users"])) {
            NSDictionary *user = VLDictionary(userValue);
            NSString *uuid = VLString([user objectForKey:@"id"]);
            if (!uuid.length) continue;
            NSMutableDictionary *query = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                security, @"security", VLString([stream objectForKey:@"network"]) ?: @"tcp", @"type", nil];
            NSDictionary *values = [NSDictionary dictionaryWithObjectsAndKeys:
                VLString([tls objectForKey:@"serverName"]) ?: @"", @"sni",
                VLString([tls objectForKey:@"publicKey"]) ?: VLString([tls objectForKey:@"password"]) ?: @"", @"pbk",
                VLString([tls objectForKey:@"shortId"]) ?: @"", @"sid",
                VLString([tls objectForKey:@"fingerprint"]) ?: @"chrome", @"fp",
                VLString([user objectForKey:@"flow"]) ?: @"", @"flow",
                VLString([user objectForKey:@"encryption"]) ?: @"none", @"encryption", nil];
            [query addEntriesFromDictionary:values];
            NSArray *alpn = VLArray([tls objectForKey:@"alpn"]);
            BOOL validALPN = YES;
            for (id proto in alpn) if (!VLString(proto)) validALPN = NO;
            if (!validALPN) continue;
            if (alpn.count) [query setObject:[alpn componentsJoinedByString:@","] forKey:@"alpn"];
            if ([[tls objectForKey:@"allowInsecure"] isKindOfClass:[NSNumber class]] && [[tls objectForKey:@"allowInsecure"] boolValue]) [query setObject:@"1" forKey:@"allowinsecure"];
            NSDictionary *tcp = VLDictionary([stream objectForKey:@"tcpSettings"]);
            NSString *headerType = VLString([VLDictionary([tcp objectForKey:@"header"]) objectForKey:@"type"]);
            if (headerType) [query setObject:headerType forKey:@"headertype"];
            NSMutableArray *pairs = [NSMutableArray array];
            for (NSString *key in [[query allKeys] sortedArrayUsingSelector:@selector(compare:)])
                [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, VLEscape([query objectForKey:key])]];
            NSString *name = VLString([configuration objectForKey:@"remarks"]) ?: VLString([configuration objectForKey:@"tag"]) ?: host;
            NSString *line = [NSString stringWithFormat:@"vless://%@@%@:%ld?%@#%@", VLEscape(uuid), host, (long)port,
                [pairs componentsJoinedByString:@"&"], VLEscape(name)];
            if ([VLESSConfig configFromURI:line] && ![lines containsObject:line]) [lines addObject:line];
        }
    }
}

static NSDictionary *VLParseQuery(NSString *query) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        if (!pair.length) continue;
        NSRange eq = [pair rangeOfString:@"="];
        if (eq.location == NSNotFound) {
            [out setObject:@"" forKey:[pair lowercaseString]];
            continue;
        }
        NSString *k = [VLUnescape([pair substringToIndex:eq.location]) lowercaseString];
        NSString *v = VLUnescape([pair substringFromIndex:eq.location + 1]);
        if (k.length) [out setObject:v ?: @"" forKey:k];
    }
    return out;
}

@implementation VLESSConfig

+ (instancetype)configFromURI:(NSString *)uri {
    if (![uri isKindOfClass:[NSString class]] || uri.length > 16384) return nil;
    NSString *s = [uri stringByTrimmingCharactersInSet:
                   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![[s lowercaseString] hasPrefix:@"vless://"]) return nil;
    s = [s substringFromIndex:8];

    VLESSConfig *c = [[[VLESSConfig alloc] init] autorelease];

    NSRange hash = [s rangeOfString:@"#"];
    if (hash.location != NSNotFound) {
        c.name = VLUnescape([s substringFromIndex:hash.location + 1]);
        s = [s substringToIndex:hash.location];
    }

    NSDictionary *q = nil;
    NSRange qm = [s rangeOfString:@"?"];
    if (qm.location != NSNotFound) {
        q = VLParseQuery([s substringFromIndex:qm.location + 1]);
        s = [s substringToIndex:qm.location];
    }

    NSRange at = [s rangeOfString:@"@" options:NSBackwardsSearch];
    if (at.location == NSNotFound) return nil;
    c.uuid = VLUnescape([s substringToIndex:at.location]);
    NSString *hostPort = [s substringFromIndex:at.location + 1];
    if ([hostPort hasSuffix:@"/"]) hostPort = [hostPort substringToIndex:hostPort.length - 1];

    if ([c.uuid rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) return nil;
    uint8_t probe[VL_UUID_LEN];
    if (VLParseUUID([c.uuid UTF8String], probe) != VLESSOk) return nil;

    NSRange colon = [hostPort rangeOfString:@":" options:NSBackwardsSearch];
    if (colon.location == NSNotFound) return nil;
    c.host = [hostPort substringToIndex:colon.location];
    if ([c.host hasPrefix:@"["] && [c.host hasSuffix:@"]"]) {
        c.host = [c.host substringWithRange:NSMakeRange(1, c.host.length - 2)];
    }
    struct in6_addr ipv6;
    if ([c.host rangeOfString:@":"].location != NSNotFound &&
        (![hostPort hasPrefix:@"["] || inet_pton(AF_INET6, [c.host UTF8String], &ipv6) != 1)) return nil;
    if ([c.host rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) return nil;
    if ([c.host rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" /?#@[]\\\r\n\t"]].location != NSNotFound) return nil;
    NSString *portText = [hostPort substringFromIndex:colon.location + 1];
    if (!portText.length || [portText rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location != NSNotFound) return nil;
    NSScanner *portScanner = [NSScanner scannerWithString:portText];
    int port = 0;
    if (![portScanner scanInt:&port] || !portScanner.isAtEnd) return nil;
    if (!c.host.length || port <= 0 || port > 65535) return nil;
    c.port = (uint16_t)port;

    NSString *security = [[q objectForKey:@"security"] lowercaseString] ?: @"none";
    if ([security isEqualToString:@"reality"]) c.security = VLSecurityReality;
    else if ([security isEqualToString:@"tls"]) c.security = VLSecurityTLS;
    else if ([security isEqualToString:@"none"]) c.security = VLSecurityNone;
    else c.security = VLSecurityUnknown;

    NSString *type = [[q objectForKey:@"type"] lowercaseString] ?: @"tcp";
    if ([type isEqualToString:@"ws"]) c.transport = VLTransportWS;
    else if ([type isEqualToString:@"xhttp"] || [type isEqualToString:@"splithttp"]) c.transport = VLTransportXHTTP;
    else if ([type isEqualToString:@"grpc"]) c.transport = VLTransportGRPC;
    else if ([type isEqualToString:@"tcp"] || [type isEqualToString:@"raw"]) c.transport = VLTransportTCP;
    else c.transport = VLTransportUnknown;

    NSString *serverName = [q objectForKey:@"sni"];
    if (!serverName.length) serverName = [q objectForKey:@"peer"];
    c.sni         = serverName.length ? serverName : c.host;
    c.flow        = [q objectForKey:@"flow"] ?: @"";
    c.encryption  = [q objectForKey:@"encryption"] ?: @"none";
    c.headerType  = [q objectForKey:@"headertype"] ?: @"none";
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
    if (![text isKindOfClass:[NSString class]] || text.length > 4 * 1024 * 1024) return [NSArray array];
    NSString *body = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([body hasPrefix:@"\uFEFF"]) body = [body substringFromIndex:1];
    if ([body rangeOfString:@"://"].location == NSNotFound && body.length > 16) {
        NSData *decoded = VLDecodeBase64(body);
        NSString *inner = decoded ? [[[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding] autorelease] : nil;
        if (inner.length) body = inner;
    }
    NSMutableArray *out = [NSMutableArray array];
    if ([body hasPrefix:@"["] || [body hasPrefix:@"{"]) {
        id json = OGCoreJSONObjectWithData([body dataUsingEncoding:NSUTF8StringEncoding], NULL);
        VLAddJSONLines(json, out);
        return out;
    }
    for (NSString *raw in [body componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!t.length || [t hasPrefix:@"#"] || [out containsObject:t]) continue;
        if ([VLESSConfig configFromURI:t]) [out addObject:t];
    }
    return out;
}

- (BOOL)isSupported {
    return [self unsupportedReason] == nil;
}

- (NSString *)unsupportedReason {
    if (![self.encryption isEqualToString:@"none"]) return @"Не поддерживается указанный режим шифрования VLESS";
    if (![self.headerType isEqualToString:@"none"]) return @"Не поддерживается маскировка заголовков TCP";
    if (self.flow.length && ![self.flow isEqualToString:@"xtls-rprx-vision"]) return @"Неизвестный flow VLESS";
    if (self.flow.length && self.security == VLSecurityNone) return @"Vision требует TLS или Reality";
    if (!self.sni.length || [self.sni lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 253 ||
        [self.sni rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound ||
        [self.sni rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound) return @"Некорректное имя сервера TLS";
    if (self.alpn.count > 8) return @"Слишком много протоколов ALPN";
    NSUInteger alpnSize = 0;
    for (NSString *proto in self.alpn) {
        NSUInteger size = [proto lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        if (!size || size > 255 || alpnSize + size + 1 > 256) return @"Некорректный список ALPN";
        alpnSize += size + 1;
    }
    if (self.security == VLSecurityUnknown) return @"Неизвестный режим защиты VLESS";
    if (self.transport == VLTransportUnknown) return @"Неизвестный транспорт VLESS";
    if (self.transport != VLTransportTCP) {
        return @"пока только прямой TCP, без WebSocket и gRPC";
    }
    if (self.security == VLSecurityReality) {

        NSData *key = VLDecodeBase64(self.publicKey);
        uint8_t zero[32] = {0}, shortID[8];
        if (key.length != 32 || memcmp(key.bytes, zero, 32) == 0) return @"Некорректный pbk Reality (ожидается ключ X25519)";
        if (!VLDecodeHexBytes([self.shortID UTF8String], [self.shortID lengthOfBytesUsingEncoding:NSUTF8StringEncoding], shortID, sizeof(shortID))) return @"Некорректный sid Reality";
    }

    return nil;
}

- (NSString *)summary {
    NSString *sec = self.security == VLSecurityReality ? @"reality"
                  : self.security == VLSecurityTLS ? @"tls" : @"без шифра";
    NSString *tr = self.transport == VLTransportWS ? @"ws"
                 : self.transport == VLTransportXHTTP ? @"xhttp"
                 : self.transport == VLTransportGRPC ? @"grpc" : @"tcp";
    return [NSString stringWithFormat:@"%@:%u, %@/%@%@", self.host,
            self.port, sec, tr, self.flow.length ? [@", " stringByAppendingString:self.flow] : @""];
}

- (void)dealloc
{
    [_name release]; [_host release]; [_uuid release]; [_sni release];
    [_flow release]; [_path release]; [_hostHeader release]; [_publicKey release];
    [_shortID release]; [_fingerprint release]; [_alpn release];
    [_encryption release]; [_headerType release];
    [super dealloc];
}

@end
