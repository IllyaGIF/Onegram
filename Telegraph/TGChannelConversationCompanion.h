#import "TGGenericModernConversationCompanion.h"

@class TGConversation;

@interface TGChannelConversationCompanion : TGGenericModernConversationCompanion

@property (nonatomic, strong, readonly) TGConversation *conversation;

- (instancetype)initWithConversation:(TGConversation *)conversation userActivities:(NSDictionary *)userActivities;

- (NSString *)titleForConversation:(TGConversation *)conversation;
- (void)applyAvatarForConversation:(TGConversation *)conversation;
- (void)updateStatus;
- (SSignal *)_requestPinnedMessages;

@end
