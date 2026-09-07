#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGPasscodeStatus : NSObject

@property (nonatomic, readonly) bool enabled;
@property (nonatomic, readonly) bool encrypted;

@end

@interface TGPasscodeSignals : NSObject

+ (SSignal *)passcodeStatus;

@end
