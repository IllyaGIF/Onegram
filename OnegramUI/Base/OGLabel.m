#import "OGLabel.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGTypography.h"

@implementation OGLabel
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _theme = [OGTheme currentTheme];
        self.backgroundColor = [UIColor clearColor];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    _theme = theme == nil ? [OGTheme currentTheme] : theme;
    [self applyTheme];
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.textColor = _theme.palette.primaryTextColor;
    self.font = _theme.typography.bodyFont;
}
@end
