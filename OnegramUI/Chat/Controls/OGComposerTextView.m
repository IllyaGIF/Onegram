#import "OGComposerTextView.h"
#import "../../Core/OGTheme.h"
#import "../../Core/OGPalette.h"
#import "../../Core/OGTypography.h"

@implementation OGComposerTextView
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
}

- (void)applyTheme
{
    self.backgroundColor = self.theme.palette.cardColor;
    self.textColor = self.theme.palette.primaryTextColor;
    self.font = self.theme.typography.messageFont;
}
@end
