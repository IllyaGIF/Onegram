#import "OGTextMessageView.h"
#import "../../Base/OGLabel.h"
#import "../../Core/OGTheme.h"
#import "../../Core/OGTypography.h"
#import "../../../OnegramPlatform/OGPlatformText.h"

@implementation OGTextMessageView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _textLabel = [[OGLabel alloc] initWithFrame:CGRectZero];
        _textLabel.numberOfLines = 0;
        _textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:_textLabel];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    _textLabel.theme = self.theme;
    [self applyTheme];
}

- (void)applyTheme
{
    [super applyTheme];
    self.backgroundColor = [UIColor clearColor];
    _textLabel.font = self.theme.typography.messageFont;
}

- (void)setText:(NSString *)text
{
    _text = [text copy];
    _textLabel.text = _text;
    [self setNeedsLayout];
}

- (CGSize)contentSizeThatFits:(CGSize)size
{
    CGSize measured = OGPlatformTextSize(_text, _textLabel.font, size, UILineBreakModeWordWrap);
    return CGSizeMake(ceilf(measured.width), ceilf(measured.height));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _textLabel.frame = self.bounds;
}
@end
