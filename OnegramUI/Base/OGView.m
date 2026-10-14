#import "OGView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"

@implementation OGView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _theme = [OGTheme currentTheme];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    _theme = theme == nil ? [OGTheme currentTheme] : theme;
    [self applyTheme];
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.backgroundColor = _theme.palette.backgroundColor;
}
@end
