#import "TLMetaRpc.h"

@class TLInputPeer;


@interface TLRPCmessages_sendMultiMedia : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t reply_to_msg_id;
@property (nonatomic) int32_t forumTopicId;
@property (nonatomic, strong) TLInputPeer *monoforumPeer;
@property (nonatomic, strong) TLInputPeer *sendAs;
@property (nonatomic) int64_t allowPaidStars;
@property (nonatomic, strong) NSArray *multi_media;

@end
