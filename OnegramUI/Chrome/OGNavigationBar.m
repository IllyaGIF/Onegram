#import "OGNavigationBar.h"
#import "OGNavigationButton.h"
#import "../Base/OGImageView.h"
#import "../Base/OGLabel.h"
#import "../Core/OGTheme.h"
#import "../Core/OGTypography.h"
#import "../Core/OGPalette.h"
#import "../Core/OGGeometry.h"
#import "../Core/OGNavigationAppearance.h"
#import "../Core/OGAssets.h"

@implementation OGNavigationBar
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _backgroundView = [[OGImageView alloc] initWithFrame:self.bounds];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _titleLabel = [[OGLabel alloc] initWithFrame:CGRectZero];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _leftButton = [[OGNavigationButton alloc] initWithFrame:CGRectZero];
        _rightButton = [[OGNavigationButton alloc] initWithFrame:CGRectZero];
        [self addSubview:_backgroundView];
        [self addSubview:_titleLabel];
        [self addSubview:_leftButton];
        [self addSubview:_rightButton];
        [self applyTheme];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    _backgroundView.theme = self.theme;
    _titleLabel.theme = self.theme;
    _leftButton.theme = self.theme;
    _rightButton.theme = self.theme;
    [self applyTheme];
}

- (void)setBackgroundAssetDirectory:(NSString *)backgroundAssetDirectory
{
    _backgroundAssetDirectory = [backgroundAssetDirectory copy];
    [self reloadBackgroundAsset];
}

- (void)setBackgroundAssetName:(NSString *)backgroundAssetName
{
    _backgroundAssetName = [backgroundAssetName copy];
    [self reloadBackgroundAsset];
}

- (void)reloadBackgroundAsset
{
    if ([_backgroundAssetDirectory length] == 0)
        _backgroundView.image = [self.theme.assets imageNamed:_backgroundAssetName];
    else
        _backgroundView.image = [self.theme.assets imageNamed:_backgroundAssetName inDirectory:_backgroundAssetDirectory];
}

- (void)applyTheme
{
    [super applyTheme];
    OGNavigationAppearance *appearance = self.theme.navigationAppearance;
    _titleLabel.font = appearance.titleFont;
    _titleLabel.textColor = appearance.titleColor;
    _titleLabel.shadowColor = appearance.titleShadowColor;
    _titleLabel.shadowOffset = CGSizeMake(appearance.titleShadowOffset.horizontal, appearance.titleShadowOffset.vertical);
    _leftButton.titleLabel.font = appearance.buttonFont;
    _rightButton.titleLabel.font = appearance.buttonFont;
    [_leftButton setTitleColor:appearance.buttonTitleColor forState:UIControlStateNormal];
    [_rightButton setTitleColor:appearance.buttonTitleColor forState:UIControlStateNormal];
    [_leftButton setTitleColor:[appearance.buttonTitleColor colorWithAlphaComponent:appearance.buttonHighlightedAlpha] forState:UIControlStateHighlighted];
    [_rightButton setTitleColor:[appearance.buttonTitleColor colorWithAlphaComponent:appearance.buttonHighlightedAlpha] forState:UIControlStateHighlighted];
    _leftButton.titleLabel.shadowColor = appearance.buttonShadowColor;
    _leftButton.titleLabel.shadowOffset = CGSizeMake(appearance.buttonShadowOffset.horizontal, appearance.buttonShadowOffset.vertical);
    _rightButton.titleLabel.shadowColor = appearance.buttonShadowColor;
    _rightButton.titleLabel.shadowOffset = CGSizeMake(appearance.buttonShadowOffset.horizontal, appearance.buttonShadowOffset.vertical);
    _backgroundAssetDirectory = [appearance.backgroundResourceDirectory copy];
    _backgroundAssetName = [appearance.backgroundAssetName copy];
    [self reloadBackgroundAsset];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat buttonWidth = 72.0f;
    _leftButton.frame = CGRectMake(4.0f, 0.0f, buttonWidth, self.bounds.size.height);
    _rightButton.frame = CGRectMake(MAX(0.0f, self.bounds.size.width - buttonWidth - 4.0f), 0.0f, buttonWidth, self.bounds.size.height);
    CGFloat left = CGRectGetMaxX(_leftButton.frame) + 4.0f;
    CGFloat right = CGRectGetMinX(_rightButton.frame) - 4.0f;
    _titleLabel.frame = CGRectMake(left, 0.0f, MAX(0.0f, right - left), self.bounds.size.height);
}
@end
