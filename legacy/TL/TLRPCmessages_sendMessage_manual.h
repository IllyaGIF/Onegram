#import "TLObject.h"
#import "TLMetaRpc.h"

#ifdef __cplusplus
extern "C" {
#endif
int32_t TGMessageSendFlags(int32_t flags, int32_t replyMessageId, int32_t topicId);
void TGSerializeMessageReply(NSOutputStream *stream, int32_t flags, int32_t replyMessageId, int32_t topicId);
#ifdef __cplusplus
}
#endif

@class TLInputPeer;
@class TLCodexPollValue;

@interface TLRPCmessages_sendMessage_manual : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t reply_to_msg_id;
@property (nonatomic) int32_t forumTopicId;
@property (nonatomic, strong) NSString *message;
@property (nonatomic) int64_t random_id;
@property (nonatomic, strong) NSArray *entities;

@end

@interface TLRPCmessages_sendReaction_manual : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t msg_id;
@property (nonatomic, strong) NSString *reaction;

@end

@interface TLAvailableReaction_manual : NSObject <TLObject>

@property (nonatomic) bool inactive;
@property (nonatomic) bool premium;
@property (nonatomic, strong) NSString *reaction;

@end

@interface TLmessages_AvailableReactions_manual : NSObject <TLObject>

@property (nonatomic, strong) NSArray *reactions;
@property (nonatomic, strong) NSArray *activeEmojis;

@end


@interface TLRPCmessages_getAvailableReactions_manual : TLMetaRpc

@property (nonatomic) int32_t hashValue;

@end

@interface TLRPCmessages_sendVote_manual : TLMetaRpc

@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t msg_id;
@property (nonatomic, strong) NSArray *options;

@end

@interface TLRPCmessages_getPollResults_manual : TLMetaRpc

@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t msg_id;
@property (nonatomic) int64_t poll_hash;

@end

@interface TLRPCmessages_editMessagePoll_manual : TLMetaRpc

@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t msg_id;
@property (nonatomic, strong) TLCodexPollValue *poll;
@property (nonatomic, strong) NSArray *correct_answers;

@end
