#import "TLMessage.h"
#import "TLMessageAction.h"

@class TLMessageAction;
@class TLPeer;
@class TGTLDynamicObject;

@interface TGStarGiftTLMessageAction : TLMessageAction

@property (nonatomic, strong) TGTLDynamicObject *giftAction;

@end

@interface TLMessage$modernMessageService : TLMessage

@property (nonatomic) int32_t flags;
@property (nonatomic) int64_t from_id;
@property (nonatomic) int64_t senderPeerId;
@property (nonatomic) int64_t saved_peer_id;
@property (nonatomic) TLPeer *to_id;
@property (nonatomic) int32_t reply_to_msg_id;
@property (nonatomic) int32_t date;
@property (nonatomic, strong) TLMessageAction *action;

@end
