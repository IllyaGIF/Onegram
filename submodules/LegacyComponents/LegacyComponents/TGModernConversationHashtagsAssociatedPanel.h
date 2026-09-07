#import "TGModernConversationAssociatedInputPanel.h"

#import "SSignalKitCompat/SSignalKit.h"

@interface TGModernConversationHashtagsAssociatedPanel : TGModernConversationAssociatedInputPanel

@property (nonatomic, copy) void (^hashtagSelected)(NSString *);

- (void)setHashtagListSignal:(SSignal *)hashtagListSignal;

@end
