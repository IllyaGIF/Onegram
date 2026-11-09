#import <Foundation/Foundation.h>

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGConversation;
@class TGMessage;

@interface TGChannelDirectMessagesThread : NSObject

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t topMessageId;
@property (nonatomic, readonly) int32_t readInboxMaxId;
@property (nonatomic, readonly) int32_t readOutboxMaxId;
@property (nonatomic, readonly) int32_t unreadCount;
@property (nonatomic, readonly) bool unreadMark;
@property (nonatomic, strong, readonly) TGMessage *topMessage;

- (instancetype)initWithPeerId:(int64_t)peerId topMessageId:(int32_t)topMessageId topMessage:(TGMessage *)topMessage readInboxMaxId:(int32_t)readInboxMaxId readOutboxMaxId:(int32_t)readOutboxMaxId unreadCount:(int32_t)unreadCount unreadMark:(bool)unreadMark;

- (instancetype)threadByApplyingMessage:(TGMessage *)message;
- (instancetype)threadByReadingInboxUpTo:(int32_t)maxId;

@end

@interface TGChannelDirectMessagesThreadsPage : NSObject

@property (nonatomic, strong, readonly) NSArray *threads;
@property (nonatomic, readonly) bool hasMore;

@end

@interface TGChannelDirectMessagesSignals : NSObject

+ (TGConversation *)broadcastChannelForMonoforum:(TGConversation *)monoforum;
+ (bool)channelAcceptsDirectMessages:(TGConversation *)channel;
+ (bool)canManageDirectMessagesInChannel:(TGConversation *)channel;
+ (bool)canManageDirectMessagesInMonoforum:(TGConversation *)monoforum;

+ (SSignal *)monoforumForChannel:(TGConversation *)channel;
+ (SSignal *)threadsForMonoforum:(TGConversation *)monoforum after:(TGChannelDirectMessagesThread *)lastThread limit:(int32_t)limit;
+ (SSignal *)historyForMonoforum:(TGConversation *)monoforum peerId:(int64_t)peerId offsetId:(int32_t)offsetId limit:(int32_t)limit;
+ (SSignal *)readHistoryForMonoforum:(TGConversation *)monoforum peerId:(int64_t)peerId maxId:(int32_t)maxId;

@end
