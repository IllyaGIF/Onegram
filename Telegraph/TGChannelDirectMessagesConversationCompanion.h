#import "TGChannelConversationCompanion.h"

@interface TGChannelDirectMessagesConversationCompanion : TGChannelConversationCompanion

@property (nonatomic, readonly) int64_t threadPeerId;

- (instancetype)initWithMonoforum:(TGConversation *)monoforum threadPeerId:(int64_t)threadPeerId;

@end
