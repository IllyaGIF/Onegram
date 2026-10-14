#import <Foundation/Foundation.h>

@class AWGConfig;

extern NSString * const kAWGWarpErrorDomain;

@interface AWGWarpRegistrar : NSObject

+ (AWGConfig *)generateConfigWithError:(NSError **)error;
+ (AWGConfig *)generateConfigWithPrivateKey:(NSString *)privateKeyBase64 error:(NSError **)error;
+ (AWGConfig *)generateConfigWithPrivateKey:(NSString *)privateKeyBase64 socksPort:(uint16_t)socksPort error:(NSError **)error;

+ (NSString *)randomWarpEndpoint;
+ (NSArray *)warpPrefixes;
+ (void)rotateEndpointForConfig:(AWGConfig *)config;
+ (void)applyWarpObfuscationProfile:(AWGConfig *)config;

@end
