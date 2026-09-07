#import "TGCollectionMenuController.h"
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import "TGPassportForm.h"

@interface TGPassportPhoneCodeController : TGCollectionMenuController

- (instancetype)initWithPhoneNumber:(NSString *)phoneNumber phoneCodeHash:(NSString *)phoneCodeHash callTimeout:(NSTimeInterval)callTimeout settings:(SVariable *)settings completionBlock:(void (^)(TGPassportDecryptedValue *))completionBlock;

@end
