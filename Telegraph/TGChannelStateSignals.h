#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGChannelStateSignals : NSObject

+ (void)addChannelUpdates:(int64_t)peerId updates:(NSArray *)updates;
+ (SSignal *)updatedChannel:(int64_t)peerId;
+ (void)clearChannelStates;
+ (void)resumeChannelStates;
+ (void)requestChannelPoll:(int64_t)peerId;
+ (SSignal *)pollOnce:(int64_t)peerId;
+ (SSignal *)pollOnce:(int64_t)peerId limit:(int32_t)limit;
+ (SSignal *)addInviterMessage:(int64_t)peerId accessHash:(int64_t)accessHash;
+ (SSignal *)validateMessageRanges:(int64_t)peerId pts:(int32_t)pts validPts:(int32_t)validPts messageRanges:(NSArray *)messageRanges;

+ (void)reloadForAccountSwitch;

@end
