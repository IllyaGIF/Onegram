#import "OGButton.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGTypography.h"
#import "../Core/OGAssets.h"
#import "../../OnegramPlatform/OGPlatformUIKit.h"

@implementation OGButton
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _theme = [OGTheme currentTheme];
        OGPlatformSetExclusiveTouch(self, YES);
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    _theme = theme == nil ? [OGTheme currentTheme] : theme;
    [self applyTheme];
}

- (void)setNormalAssetName:(NSString *)normalAssetName
{
    _normalAssetName = [normalAssetName copy];
    [self setBackgroundImage:[_theme.assets imageNamed:_normalAssetName] forState:UIControlStateNormal];
}

- (void)setHighlightedAssetName:(NSString *)highlightedAssetName
{
    _highlightedAssetName = [highlightedAssetName copy];
    [self setBackgroundImage:[_theme.assets imageNamed:_highlightedAssetName] forState:UIControlStateHighlighted];
}

- (void)applyTheme
{
    [self setTitleColor:_theme.palette.primaryTextColor forState:UIControlStateNormal];
    [self setTitleColor:[_theme.palette.primaryTextColor colorWithAlphaComponent:0.55f] forState:UIControlStateDisabled];
    self.titleLabel.font = _theme.typography.bodyFont;
    if ([_normalAssetName length] != 0)
        [self setBackgroundImage:[_theme.assets imageNamed:_normalAssetName] forState:UIControlStateNormal];
    if ([_highlightedAssetName length] != 0)
        [self setBackgroundImage:[_theme.assets imageNamed:_highlightedAssetName] forState:UIControlStateHighlighted];
}
@end
