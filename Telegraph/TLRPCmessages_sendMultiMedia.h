#import "TLMetaRpc.h"

@class TLInputPeer;


@interface TLRPCmessages_sendMultiMedia : TLMetaRpc

@property (nonatomic) int32_t flags;
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t reply_to_msg_id;
@property (nonatomic, strong) NSArray *multi_media;

@end
