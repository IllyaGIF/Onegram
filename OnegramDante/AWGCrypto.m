#import "OGDanteSupport.h"
#import "AWGCrypto.h"
#import "monocypher.h"

@implementation AWGCrypto

+ (NSData *)generatePrivateKey {
    uint8_t priv[32];

    FILE *f = fopen("/dev/urandom", "r");
    if (!f) return nil;
    size_t n = fread(priv, 1, sizeof(priv), f);
    fclose(f);
    if (n != sizeof(priv)) return nil;

    priv[0]  &= 248;
    priv[31] &= 127;
    priv[31] |= 64;
    return [NSData dataWithBytes:priv length:32];
}

+ (NSData *)publicKeyFromPrivateKey:(NSData *)privateKey {
    if ([privateKey length] != 32) return nil;
    uint8_t pub[32];
    crypto_x25519_public_key(pub, [privateKey bytes]);
    return [NSData dataWithBytes:pub length:32];
}

+ (NSString *)base64Encode:(NSData *)data {
    if (!data) return nil;
    static const char tbl[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    NSMutableString *out = [NSMutableString string];
    const uint8_t *bytes = [data bytes];
    NSUInteger len = [data length];
    NSUInteger i = 0;
    while (i + 3 <= len) {
        uint32_t v = (bytes[i] << 16) | (bytes[i+1] << 8) | bytes[i+2];
        [out appendFormat:@"%c%c%c%c",
            tbl[(v >> 18) & 63], tbl[(v >> 12) & 63],
            tbl[(v >> 6) & 63], tbl[v & 63]];
        i += 3;
    }
    if (i < len) {
        uint32_t v = bytes[i] << 16;
        int rem = (int)(len - i);
        if (rem == 2) v |= bytes[i+1] << 8;
        [out appendFormat:@"%c%c", tbl[(v >> 18) & 63], tbl[(v >> 12) & 63]];
        if (rem == 2) [out appendFormat:@"%c", tbl[(v >> 6) & 63]];
        else [out appendString:@"="];
        [out appendString:@"="];
    }
    return out;
}

+ (NSData *)base64Decode:(NSString *)string {
    if (!string) return nil;
    NSData *ascii = [string dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!ascii || ascii.length % 4) return nil;
    const uint8_t *bytes = ascii.bytes;
    NSMutableData *result = [NSMutableData data];
    for (NSUInteger i = 0; i < ascii.length; i += 4) {
        uint32_t value = 0;
        NSUInteger padding = 0;
        for (NSUInteger j = 0; j < 4; j++) {
            uint8_t c = bytes[i + j];
            int digit;
            if (c >= 'A' && c <= 'Z') digit = c - 'A';
            else if (c >= 'a' && c <= 'z') digit = c - 'a' + 26;
            else if (c >= '0' && c <= '9') digit = c - '0' + 52;
            else if (c == '+') digit = 62;
            else if (c == '/') digit = 63;
            else if (c == '=' && j >= 2 && i + 4 == ascii.length) { digit = 0; padding++; }
            else return nil;
            if (padding && c != '=') return nil;
            value = (value << 6) | (uint32_t)digit;
        }
        if ((padding == 1 && (value & 255)) || (padding == 2 && (value & 65535))) return nil;
        uint8_t decoded[3] = {value >> 16, value >> 8, value};
        [result appendBytes:decoded length:3 - padding];
    }
    return result;
}

@end
