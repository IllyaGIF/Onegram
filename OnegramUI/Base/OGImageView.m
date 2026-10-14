#import "OGImageView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGAssets.h"

@implementation OGImageView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        _theme = [OGTheme currentTheme];
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    _theme = theme == nil ? [OGTheme currentTheme] : theme;
    [self applyTheme];
}

- (void)setAssetName:(NSString *)assetName
{
    _assetName = [assetName copy];
    [self reloadAsset];
}

- (void)reloadAsset
{
    self.image = [_theme.assets imageNamed:_assetName];
}

- (void)applyTheme
{
    [self reloadAsset];
}
@end
