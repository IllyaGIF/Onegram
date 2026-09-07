#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGRecentContextBotsSignal : NSObject

+ (void)clearRecentBots;
+ (void)addRecentBot:(int32_t)userId;
+ (SSignal *)recentBots;

@end
