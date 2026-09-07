#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGRemoteHttpLocationSignal : NSObject

+ (SSignal *)dataForHttpLocation:(NSString *)httpLocation;
+ (SSignal *)jsonForHttpLocation:(NSString *)httpLocation;

@end
