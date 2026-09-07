#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

typedef enum {
    TGTwoStepRecoveryErrorInvalidCode,
    TGTwoStepRecoveryErrorCodeExpired,
    TGTwoStepRecoveryErrorFlood
} TGTwoStepRecoveryError;

@interface TGTwoStepRecoverySignals : NSObject

+ (SSignal *)requestPasswordRecovery;
+ (SSignal *)recoverPasswordWithCode:(NSString *)code;

@end
