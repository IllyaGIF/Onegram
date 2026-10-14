#import "../../Base/OGView.h"
@class OGComposerTextView;
@class OGAttachButton;
@class OGSendButton;
@class OGVoiceButton;
@interface OGComposerView : OGView
@property (nonatomic, retain, readonly) OGComposerTextView *textView;
@property (nonatomic, retain, readonly) OGAttachButton *attachButton;
@property (nonatomic, retain, readonly) OGSendButton *sendButton;
@property (nonatomic, retain, readonly) OGVoiceButton *voiceButton;
@property (nonatomic) BOOL voiceMode;
@end
