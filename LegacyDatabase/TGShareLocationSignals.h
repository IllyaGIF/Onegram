#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGShareLocationSignals : NSObject

+ (SSignal *)locationMessageContentForURL:(NSURL *)url;
+ (bool)isLocationURL:(NSURL *)url;

@end
