#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGMessage;
@class TGPollMediaAttachment;
@class TGPollResults;

@interface TGPollSignals : NSObject

+ (SSignal *)voteWithPeerId:(int64_t)peerId accessHash:(int64_t)accessHash messageId:(int32_t)messageId options:(NSArray *)options;
+ (SSignal *)pollResultsWithPeerId:(int64_t)peerId accessHash:(int64_t)accessHash messageId:(int32_t)messageId pollHash:(int64_t)pollHash;
+ (SSignal *)closePoll:(TGPollMediaAttachment *)poll peerId:(int64_t)peerId accessHash:(int64_t)accessHash messageId:(int32_t)messageId;

+ (void)registerPollId:(int64_t)pollId peerId:(int64_t)peerId messageId:(int32_t)messageId;
+ (NSArray *)messagesByApplyingPollUpdates:(NSArray *)updates baseMessages:(NSArray *)baseMessages;
+ (NSArray *)messageUpdatesForPollUpdates:(NSArray *)updates baseMessages:(NSArray *)baseMessages;
+ (TGMessage *)message:(TGMessage *)message byApplyingPoll:(TGPollMediaAttachment *)poll pollId:(int64_t)pollId results:(TGPollResults *)results;

@end
