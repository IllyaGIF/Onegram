#import "TGUserInfoButtonCollectionItemView.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSettingsAppearance.h"
#import "../OnegramUI/Core/OGProfileAppearance.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGUserInfoButtonCollectionItemView ()
{
    CALayer *_separatorLayer;
    
    UILabel *_titleLabel;
    UIImageView *_iconView;
    UIImageView *_arrowView;
    bool _centeredTitle;
    bool _showsDisclosureIndicator;
    NSString *_iconName;
}

@end

@implementation TGUserInfoButtonCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.selectionInsets = UIEdgeInsetsMake(TGScreenPixel, 0.0f, 0.0f, 0.0f);
        
        _separatorLayer = [[CALayer alloc] init];
        _separatorLayer.backgroundColor = TGSeparatorColor().CGColor;
        [self.backgroundView.layer addSublayer:_separatorLayer];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        [self addSubview:_titleLabel];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.hidden = true;
        [self addSubview:_iconView];

        _arrowView = [[UIImageView alloc] init];
        _arrowView.hidden = true;
        _showsDisclosureIndicator = true;
        [self addSubview:_arrowView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    _separatorLayer.backgroundColor = presentation.pallete.collectionMenuSeparatorColor.CGColor;
    OGTheme *theme = [OGTheme brandedTheme];
    OGSettingsAppearance *rowAppearance = theme.profileAppearance.actionRowAppearance;
    if (brandedIOS6Style)
        [OGSettingsCell applyLegacyBrandedTitleStyleWithAppearance:rowAppearance titleLabel:_titleLabel];
    else
    {
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
        _titleLabel.shadowColor = nil;
        _titleLabel.shadowOffset = CGSizeZero;
    }
    self.brandedGroupedAppearance = brandedIOS6Style ? rowAppearance : nil;
    self.classicIOS6HorizontalInset = brandedIOS6Style ? rowAppearance.groupedHorizontalInset : 9.0f;
    _arrowView.image = brandedIOS6Style ? [OGSettingsCell legacyBrandedDisclosureImageWithTheme:theme] : presentation.images.collectionMenuDisclosureIcon;
    _arrowView.hidden = !brandedIOS6Style || !_showsDisclosureIndicator;
    [self updateIcon];
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setTitleColor:(UIColor *)titleColor
{
    _titleLabel.textColor = titleColor;
}

- (void)setIconName:(NSString *)iconName
{
    _iconName = iconName;
    [self updateIcon];
}

- (void)updateIcon
{
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    OGTheme *theme = [OGTheme brandedTheme];
    OGSettingsAppearance *rowAppearance = theme.profileAppearance.actionRowAppearance;
    _iconView.image = brandedIOS6Style ? [OGSettingsCell legacyBrandedIconNamed:_iconName appearance:rowAppearance theme:theme] : nil;
    _iconView.hidden = !brandedIOS6Style || _iconView.image == nil;
    if (!_iconView.hidden)
        [OGSettingsCell applyLegacyBrandedIconStyleWithAppearance:rowAppearance iconView:_iconView];
    [self setNeedsLayout];
}

- (void)setCenteredTitle:(bool)centeredTitle
{
    _centeredTitle = centeredTitle;
    [self setNeedsLayout];
}

- (void)setShowsDisclosureIndicator:(bool)showsDisclosureIndicator
{
    _showsDisclosureIndicator = showsDisclosureIndicator;
    _arrowView.hidden = ![TGPresentation brandedIOS6Style] || !showsDisclosureIndicator;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];

    CGFloat separatorHeight = TGScreenPixel;
    CGFloat separatorInset = (brandedIOS6Style ? 0.0f : 15.0f) + self.safeAreaInset.left;
    _separatorLayer.hidden = brandedIOS6Style && [OGTheme brandedTheme].profileAppearance.actionRowAppearance.hidesInlineSeparator;
    _separatorLayer.frame = CGRectMake(separatorInset, bounds.size.height - separatorHeight, bounds.size.width - separatorInset, separatorHeight);

    if (brandedIOS6Style)
    {
        OGTheme *theme = [OGTheme brandedTheme];
        OGSettingsAppearance *appearance = theme.profileAppearance.actionRowAppearance;
        _arrowView.image = [OGSettingsCell legacyBrandedDisclosureImageWithTheme:theme];
        _arrowView.hidden = !_showsDisclosureIndicator;
        CGSize disclosureSize = _showsDisclosureIndicator && _arrowView.image != nil ? _arrowView.image.size : CGSizeZero;
        OGSettingsCellLegacyLayout layout;
        OGSettingsCellGetLegacyLayout(appearance, bounds, self.safeAreaInset, disclosureSize, _showsDisclosureIndicator ? OGSettingsCellAccessoryDisclosure : OGSettingsCellAccessoryNone, CGSizeZero, 0.0f, appearance.titleTrailingSpacing, &layout);
        _arrowView.frame = layout.accessoryFrame;
        if (_centeredTitle)
        {
            _titleLabel.textAlignment = NSTextAlignmentCenter;
            _titleLabel.frame = CGRectMake(self.safeAreaInset.left, layout.titleFrame.origin.y, MAX(0.0f, bounds.size.width - self.safeAreaInset.left - self.safeAreaInset.right), appearance.titleHeight);
        }
        else
        {
            _titleLabel.textAlignment = NSTextAlignmentLeft;
            _titleLabel.frame = layout.titleFrame;
        }
        if (_iconView.image != nil)
        {
            _iconView.frame = layout.iconFrame;
        }
        return;
    }

    _titleLabel.textAlignment = NSTextAlignmentLeft;
    CGFloat leftPadding = 15.0f + TGScreenPixel + self.safeAreaInset.left;
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(bounds.size.width - leftPadding - 30.0f - self.safeAreaInset.right, CGFLOAT_MAX)];
    CGFloat titleHeight = MAX(titleSize.height, ceilf(OGPlatformFontLineHeight(_titleLabel.font)));
    _titleLabel.frame = CGRectMake(leftPadding, CGFloor((bounds.size.height - titleHeight) / 2.0f), titleSize.width, titleHeight);
}

@end
