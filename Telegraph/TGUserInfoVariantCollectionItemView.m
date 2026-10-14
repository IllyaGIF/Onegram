#import "TGUserInfoVariantCollectionItemView.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSettingsAppearance.h"
#import "../OnegramUI/Core/OGProfileAppearance.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGUserInfoVariantCollectionItemView ()
{
    CALayer *_separatorLayer;
    
    UILabel *_titleLabel;
    UILabel *_variantLabel;
    UIImageView *_arrowView;
    
    UIImageView *_variantImageView;
    UIImageView *_iconView;
    NSString *_iconName;
}

@end

@implementation TGUserInfoVariantCollectionItemView

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
        _titleLabel.textColor = [UIColor blackColor];
        [self addSubview:_titleLabel];
        
        _variantLabel = [[UILabel alloc] init];
        _variantLabel.backgroundColor = [UIColor clearColor];
        _variantLabel.font = TGSystemFontOfSize(17.0f);
        _variantLabel.textColor = UIColorRGB(0x8e8e93);
        [self addSubview:_variantLabel];
        
        _arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 8.0f, 14.0f)];
        [self addSubview:_arrowView];

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.hidden = true;
        [self addSubview:_iconView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
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
    if (brandedIOS6Style)
        [OGSettingsCell applyLegacyBrandedVariantStyleWithTheme:theme variantLabel:_variantLabel];
    else
    {
        _variantLabel.textColor = presentation.pallete.collectionMenuVariantColor;
        _variantLabel.font = TGSystemFontOfSize(17.0f);
    }
    _separatorLayer.backgroundColor = presentation.pallete.collectionMenuSeparatorColor.CGColor;
    _arrowView.image = brandedIOS6Style ? [OGSettingsCell legacyBrandedDisclosureImageWithTheme:theme] : presentation.images.collectionMenuDisclosureIcon;
    self.brandedGroupedAppearance = brandedIOS6Style ? rowAppearance : nil;
    self.classicIOS6HorizontalInset = brandedIOS6Style ? rowAppearance.groupedHorizontalInset : 9.0f;
    [self updateIcon];
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setVariant:(NSString *)variant
{
    _variantLabel.text = variant;
    [self setNeedsLayout];
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

- (void)setVariantImage:(UIImage *)variantImage
{
    if (variantImage != nil)
    {
        if (_variantImageView == nil)
        {
            _variantImageView = [[UIImageView alloc] init];
            [self addSubview:_variantImageView];
        }
        _variantImageView.image = variantImage;
        [_variantImageView sizeToFit];
        _variantImageView.hidden = false;
    }
    else
        _variantImageView.hidden = true;
    
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    CGFloat separatorHeight = TGScreenPixel;
    CGFloat separatorInset = ([TGPresentation brandedIOS6Style] ? 0.0f : 15.0f) + self.safeAreaInset.left;
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    _separatorLayer.hidden = brandedIOS6Style && [OGTheme brandedTheme].profileAppearance.actionRowAppearance.hidesInlineSeparator;
    _separatorLayer.frame = CGRectMake(separatorInset, bounds.size.height - separatorHeight, bounds.size.width - separatorInset, separatorHeight);
    
    CGFloat leftPadding = (brandedIOS6Style ? [OGTheme brandedTheme].profileAppearance.actionRowAppearance.titleX : 15.0f + TGScreenPixel) + self.safeAreaInset.left;
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(bounds.size.width - leftPadding - self.safeAreaInset.right - 10.0f, CGFLOAT_MAX)];
    CGFloat titleHeight = MAX(titleSize.height, ceilf(OGPlatformFontLineHeight(_titleLabel.font)));
    _titleLabel.frame = CGRectMake(leftPadding, CGFloor((bounds.size.height - titleHeight) / 2.0f), titleSize.width, titleHeight);
    
    CGSize variantSize = [_variantLabel sizeThatFits:CGSizeMake(bounds.size.width - leftPadding - self.safeAreaInset.right - 10.0f, CGFLOAT_MAX)];
    CGFloat variantHeight = MAX(variantSize.height, ceilf(OGPlatformFontLineHeight(_variantLabel.font)));
    _variantLabel.frame = CGRectMake(bounds.size.width - 34.0f - variantSize.width - self.safeAreaInset.right, CGFloor((bounds.size.height - variantHeight) / 2.0f), variantSize.width, variantHeight);
    
    if (_variantImageView != nil)
    {
        _variantImageView.frame = CGRectMake(bounds.size.width - 34.0f - _variantImageView.frame.size.width - self.safeAreaInset.right, CGFloor((bounds.size.height - _variantImageView.frame.size.height) / 2.0f), _variantImageView.frame.size.width, _variantImageView.frame.size.height);
    }
    
    CGSize arrowSize = _arrowView.bounds.size;
    _arrowView.frame = CGRectMake(bounds.size.width - 15.0f - arrowSize.width - self.safeAreaInset.right, CGFloor((bounds.size.height - arrowSize.height) / 2.0f), arrowSize.width, arrowSize.height);
    if (brandedIOS6Style)
    {
        OGTheme *theme = [OGTheme brandedTheme];
        OGSettingsAppearance *appearance = theme.profileAppearance.actionRowAppearance;
        BOOL usesVariantImage = _variantImageView != nil && !_variantImageView.hidden;
        CGFloat brandedVariantHeight = MAX(variantSize.height, ceilf(OGPlatformFontLineHeight(_variantLabel.font)));
        CGSize trailingSize = usesVariantImage ? _variantImageView.frame.size : CGSizeMake(variantSize.width, brandedVariantHeight);
        CGFloat trailingVerticalOffset = usesVariantImage ? 0.0f : appearance.variantVerticalOffset;
        _arrowView.image = [OGSettingsCell legacyBrandedDisclosureImageWithTheme:theme];
        CGSize disclosureSize = _arrowView.image == nil ? CGSizeZero : _arrowView.image.size;
        OGSettingsCellLegacyLayout layout;
        OGSettingsCellGetLegacyLayout(appearance, bounds, self.safeAreaInset, disclosureSize, OGSettingsCellAccessoryDisclosure, trailingSize, trailingVerticalOffset, appearance.titleTrailingSpacing, &layout);
        if (_iconView.image != nil)
        {
            _iconView.frame = layout.iconFrame;
        }
        _arrowView.frame = layout.accessoryFrame;
        if (usesVariantImage)
            _variantImageView.frame = layout.trailingFrame;
        else
            _variantLabel.frame = layout.trailingFrame;
        _titleLabel.frame = layout.titleFrame;
    }
}

@end
