#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGUserSignal : NSObject

+ (SSignal *)userWithUserId:(int64_t)userId;
+ (SSignal *)updatedUserCachedDataWithUserId:(int64_t)userId;
+ (SSignal *)profileSavedMusicWithUserId:(int64_t)userId;
+ (SSignal *)groupsInCommon:(int64_t)userId;

@end
