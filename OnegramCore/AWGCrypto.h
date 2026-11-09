#import <Foundation/Foundation.h>

@interface AWGCrypto : NSObject

+ (NSData *)generatePrivateKey;
+ (NSData *)publicKeyFromPrivateKey:(NSData *)privateKey;

+ (NSString *)base64Encode:(NSData *)data;
+ (NSData *)base64Decode:(NSString *)string;

@end
