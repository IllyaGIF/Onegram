#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGUserSignal : NSObject

+ (SSignal *)userWithUserId:(int32_t)userId;
+ (SSignal *)updatedUserCachedDataWithUserId:(int32_t)userId;
+ (SSignal *)profileSavedMusicWithUserId:(int32_t)userId;
+ (SSignal *)groupsInCommon:(int32_t)userId;

@end
