#import "OGComposerView.h"
#import "OGComposerTextView.h"
#import "OGAttachButton.h"
#import "OGSendButton.h"
#import "OGVoiceButton.h"
#import "../../Core/OGTheme.h"
#import "../../Core/OGPalette.h"
#import "../../Core/OGGeometry.h"

@implementation OGComposerView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _attachButton = [[OGAttachButton alloc] initWithFrame:CGRectZero];
        _textView = [[OGComposerTextView alloc] initWithFrame:CGRectZero];
        _sendButton = [[OGSendButton alloc] initWithFrame:CGRectZero];
        _voiceButton = [[OGVoiceButton alloc] initWithFrame:CGRectZero];
        [self addSubview:_attachButton];
        [self addSubview:_textView];
        [self addSubview:_sendButton];
        [self addSubview:_voiceButton];
        [self setVoiceMode:NO];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    _attachButton.theme = self.theme;
    _textView.theme = self.theme;
    _sendButton.theme = self.theme;
    _voiceButton.theme = self.theme;
}

- (void)setVoiceMode:(BOOL)voiceMode
{
    _voiceMode = voiceMode;
    _sendButton.hidden = voiceMode;
    _voiceButton.hidden = !voiceMode;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    CGFloat button = MIN(40.0f, MAX(30.0f, h - 8.0f));
    _attachButton.frame = CGRectMake(4.0f, OGPixelFloor((h - button) * 0.5f), button, button);
    UIView *rightButton = _voiceMode ? (UIView *)_voiceButton : (UIView *)_sendButton;
    rightButton.frame = CGRectMake(self.bounds.size.width - button - 4.0f, OGPixelFloor((h - button) * 0.5f), button, button);
    _sendButton.frame = rightButton.frame;
    _voiceButton.frame = rightButton.frame;
    CGFloat left = CGRectGetMaxX(_attachButton.frame) + 4.0f;
    CGFloat right = CGRectGetMinX(rightButton.frame) - 4.0f;
    _textView.frame = CGRectMake(left, 4.0f, MAX(0.0f, right - left), MAX(0.0f, h - 8.0f));
}
@end
