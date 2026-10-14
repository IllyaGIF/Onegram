
#import <Foundation/Foundation.h>

@protocol MTKeychain;

@interface TGKeychainImport : NSObject

+ (void)importKeychain:(id<MTKeychain>)keychain clientUserId:(int32_t)clientUserId;
+ (void)clearLegacyKeychain;

@end
