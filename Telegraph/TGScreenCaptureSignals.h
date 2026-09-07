#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGScreenCaptureSignals : NSObject

+ (SSignal *)screenshotTakenSignal;
+ (SSignal *)screenCapturedSignal;

@end
