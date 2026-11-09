#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@class TGConversation;

@interface TGChannelDirectMessagesController : TGViewController

@property (nonatomic, readonly) int64_t monoforumPeerId;

- (instancetype)initWithMonoforum:(TGConversation *)monoforum;

@end
