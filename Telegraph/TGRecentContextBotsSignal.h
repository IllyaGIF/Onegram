#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGRecentContextBotsSignal : NSObject

+ (void)clearRecentBots;
+ (void)addRecentBot:(int64_t)userId;
+ (SSignal *)recentBots;

+ (void)reloadForAccountSwitch;

@end
