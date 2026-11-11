#import "TGModernConversationTitlePanel.h"

@interface TGPaidMessagesFeeTitlePanel : TGModernConversationTitlePanel

@property (nonatomic, copy) void (^removeFeePressed)(void);

- (void)setUserName:(NSString *)userName stars:(int64_t)stars;

@end
