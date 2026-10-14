#import "TLMetaRpc.h"

@class TLInputPeer;
@class TLMessageEntity;


@interface TLRPCmessages_saveDraft : TLMetaRpc

@property (nonatomic) bool no_webpage;
@property (nonatomic) int32_t reply_to_msg_id;
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic, strong) NSString *message;
@property (nonatomic, strong) NSArray *entities;

@end
