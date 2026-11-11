#import "TGVariantCollectionItemView.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "TGSimpleImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGCollectionItemDescription.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"
#import "../OnegramUI/Core/OGTheme.h"


@interface TGVariantCollectionItemView ()
{
    UILabel *_titleLabel;
    UILabel *_variantLabel;
    UILabel *_descriptionLabel;
    TGSimpleImageView *_iconView;
    TGSimpleImageView *_variantIconView;
    TGSimpleImageView *_disclosureIndicator;
    CGFloat _minLeftPadding;
    bool _flexibleLayout;
    
    UIColor *_customTitleColor;
    UIColor *_customVariantColor;
    bool _brandedSettingsStyle;
    NSString *_brandedSettingsIconName;
}

@end

@implementation TGVariantCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17);
        [self addSubview:_titleLabel];
        
        _variantLabel = [[UILabel alloc] init];
        _variantLabel.textColor = UIColorRGB(0x929297);
        _variantLabel.backgroundColor = [UIColor clearColor];
        _variantLabel.font = TGSystemFontOfSize(17);
        [self addSubview:_variantLabel];
        
        _disclosureIndicator = [[TGSimpleImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 8.0f, 14.0f)];
        [self addSubview:_disclosureIndicator];
    }
    return self;
}

- (void)setDisclosureImage:(UIImage *)image
{
    _disclosureIndicator.image = image;
    if (image != nil)
    {
        CGRect frame = _disclosureIndicator.frame;
        frame.size = image.size;
        _disclosureIndicator.frame = frame;
    }
    [self setNeedsLayout];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    bool classicThemeStyle = [TGPresentation classicThemeStyle];
    bool classicDarkStyle = classicThemeStyle && presentation.pallete.isDark;
    _titleLabel.textColor = _customTitleColor ?: (classicThemeStyle && !classicDarkStyle ? UIColorRGB(0x111111) : presentation.pallete.collectionMenuTextColor);
    _variantLabel.textColor = _customVariantColor ?: (classicThemeStyle && !classicDarkStyle ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor);
    _descriptionLabel.textColor = classicThemeStyle && !classicDarkStyle ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor;
    UIImage *disclosureImage = classicThemeStyle ? [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"] : presentation.images.collectionMenuDisclosureIcon;
    if ([TGPresentation brandedIOS6Style])
        disclosureImage = [OGSettingsCell legacyBrandedDisclosureImageWithTheme:[OGTheme brandedTheme]] ?: disclosureImage;
    else if (classicDarkStyle)
        disclosureImage = [TGPresentation classicIOS6ThemedImage:disclosureImage tintColor:presentation.pallete.collectionMenuAccessoryColor alpha:0.82f];
    if ([TGPresentation brandedIOS6Style] && _brandedSettingsStyle)
    {
        OGTheme *theme = [OGTheme brandedTheme];
        [OGSettingsCell applyLegacyBrandedTitleStyleWithTheme:theme titleLabel:_titleLabel];
        _variantLabel.hidden = true;
        _iconView.image = _brandedSettingsIconName.length == 0 ? nil : [TGPresentation brandedIOS6ResourceImage:_brandedSettingsIconName];
        if (_iconView.image != nil)
            [OGSettingsCell applyLegacyBrandedIconStyleWithTheme:theme iconView:_iconView];
        disclosureImage = [OGSettingsCell legacyBrandedDisclosureImageWithTheme:theme] ?: disclosureImage;
    }
    else
    {
        _variantLabel.hidden = false;
    }
    [self setDisclosureImage:disclosureImage];
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
    [_titleLabel setNeedsDisplay];
}

- (void)setDescriptionText:(NSString *)descriptionText
{
    if (descriptionText.length == 0)
    {
        _descriptionLabel.hidden = true;
        _descriptionLabel.text = nil;
        [self setNeedsLayout];
        return;
    }
    if (_descriptionLabel == nil)
    {
        _descriptionLabel = TGCollectionItemDescriptionLabel();
        bool classicThemeStyle = [TGPresentation classicThemeStyle];
        _descriptionLabel.textColor = classicThemeStyle && !self.presentation.pallete.isDark ? UIColorRGB(0x7f7f7f) : self.presentation.pallete.collectionMenuVariantColor;
        [self addSubview:_descriptionLabel];
    }
    _descriptionLabel.hidden = false;
    _descriptionLabel.text = descriptionText;
    [self setNeedsLayout];
}

- (void)setTitleColor:(UIColor *)titleColor
{
    _customTitleColor = titleColor;
    _titleLabel.textColor = titleColor == nil ? self.presentation.pallete.collectionMenuTextColor : titleColor;
}

- (void)setVariant:(NSString *)variant variantColor:(UIColor *)variantColor
{
    _variantLabel.text = variant;
    _customVariantColor = variantColor;
    _variantLabel.textColor = variantColor == nil ? self.presentation.pallete.collectionMenuVariantColor : variantColor;
    [self setNeedsLayout];
    [_variantLabel setNeedsDisplay];
}

- (void)setIcon:(UIImage *)icon
{
    if (_iconView == nil && icon != nil)
    {
        _iconView = [[TGSimpleImageView alloc] initWithFrame:CGRectMake(15, (self.frame.size.height - 15) / 2, 29, 29)];
        _iconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_iconView];
    }
    
    if (!([TGPresentation brandedIOS6Style] && _brandedSettingsStyle))
        _iconView.image = icon;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    self.separatorInset = (icon != nil) ? 59.0f : 15.0f;
#endif
    
    [self setNeedsLayout];
}

- (void)setVariantIcon:(UIImage *)variantIcon {
    if (_variantIconView == nil && variantIcon != nil) {
        _variantIconView = [[TGSimpleImageView alloc] init];
        _variantIconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_variantIconView];
    } else if (variantIcon == nil) {
        [_variantIconView removeFromSuperview];
        _variantIconView = nil;
    }
    
    _variantIconView.image = variantIcon;
    
    [self setNeedsLayout];
}

- (void)setEnabled:(bool)enabled {
    self.userInteractionEnabled = enabled;
    
    UIColor *color = _customTitleColor ?: self.presentation.pallete.collectionMenuTextColor;
    _titleLabel.textColor = enabled ? color : [color colorWithAlphaComponent:0.56f];
}

- (void)setHideArrow:(bool)hideArrow {
    _disclosureIndicator.hidden = hideArrow;
}

- (void)setMinLeftPadding:(CGFloat)minLeftPadding {
    _minLeftPadding = minLeftPadding;
    [self setNeedsLayout];
}


- (void)setFlexibleLayout:(bool)flexibleLayout {
    _flexibleLayout = flexibleLayout;
    [self setNeedsLayout];
}

- (void)setBrandedSettingsStyle:(bool)brandedSettingsStyle iconName:(NSString *)iconName
{
    _brandedSettingsStyle = brandedSettingsStyle;
    _brandedSettingsIconName = iconName;
    if (_iconView == nil && iconName.length != 0)
    {
        _iconView = [[TGSimpleImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];
    }
    if (self.presentation != nil)
        [self setPresentation:self.presentation];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    if ([TGPresentation brandedIOS6Style] && _brandedSettingsStyle)
    {
        _iconView.hidden = _iconView.image == nil;
        _variantLabel.hidden = true;
        _disclosureIndicator.hidden = false;
        [OGSettingsCell applyLegacyBrandedStyleWithTheme:[OGTheme brandedTheme] titleLabel:_titleLabel iconView:_iconView disclosureView:_disclosureIndicator bounds:bounds safeAreaInsets:self.safeAreaInset];
        return;
    }

    bool hasDescription = _descriptionLabel != nil && !_descriptionLabel.hidden;
    if (hasDescription)
        bounds.size.height = 44.0f;
    CGFloat classicInset = [TGPresentation classicThemeStyle] ? 10.0f : 0.0f;
    CGFloat width = bounds.size.width - self.safeAreaInset.left - self.safeAreaInset.right - classicInset * 2.0f;
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    CGSize variantSize = [_variantLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    if (_flexibleLayout) {
        variantSize = [_variantLabel.text sizeWithFont:_variantLabel.font];
        variantSize.width = CGCeil(variantSize.width);
        variantSize.height = CGCeil(variantSize.height);
    }
    
    _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 15 - classicInset - self.safeAreaInset.right, CGFloor((bounds.size.height - _disclosureIndicator.frame.size.height) / 2), _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
    
    CGFloat disclosureWidth = _disclosureIndicator.hidden ? 0.0f: _disclosureIndicator.frame.size.width;
    
    CGFloat startingX = (_iconView.image != nil) ? 59.0f : 15.0f;
    startingX += classicInset + self.safeAreaInset.left;
    
    CGFloat indicatorSpacing = _disclosureIndicator.hidden ? 0.0f : 10.0f;
    CGFloat labelSpacing = 8.0f;
    CGFloat availableWidth = bounds.size.width - disclosureWidth - 12.0f - startingX - indicatorSpacing - self.safeAreaInset.right;
    CGFloat titleHeight = MAX(titleSize.height, ceilf(OGPlatformFontLineHeight(_titleLabel.font)));
    CGFloat variantHeight = MAX(variantSize.height, ceilf(OGPlatformFontLineHeight(_variantLabel.font)));
    CGFloat titleY =  CGFloor((bounds.size.height - titleHeight) / 2.0f) + TGRetinaPixel;
    CGFloat variantY =  CGFloor((bounds.size.height - variantHeight) / 2.0f) + TGRetinaPixel;
    
    if (_flexibleLayout) {
        _titleLabel.frame = CGRectMake(startingX, titleY, titleSize.width, titleHeight);
        
        CGFloat variantWidth = MIN(CGFloor(availableWidth / 2.0f), MIN(availableWidth - titleSize.width - 25.0f, variantSize.width));
        
        CGFloat variantOffset = startingX + availableWidth - variantWidth;
        _variantLabel.frame = CGRectMake(variantOffset, variantY, variantWidth, variantHeight);
    }
    else if (titleSize.width + labelSpacing + variantSize.width <= availableWidth)
    {
        _titleLabel.frame = CGRectMake(startingX, titleY, titleSize.width, titleHeight);
        CGFloat variantOffset = startingX + availableWidth - variantSize.width;
        if (_minLeftPadding > FLT_EPSILON) {
            variantOffset = MAX(startingX + titleSize.width + 4.0, _minLeftPadding + self.safeAreaInset.left);
            variantSize = CGSizeMake(availableWidth - variantOffset, variantSize.height);
        }
        _variantLabel.frame = CGRectMake(variantOffset, variantY, variantSize.width, variantHeight);
    }
    else if (titleSize.width > variantSize.width)
    {
        CGFloat titleWidth = CGFloor(availableWidth * 3.0f / 4.0f) - labelSpacing;
        _titleLabel.frame = CGRectMake(startingX, titleY, titleWidth, titleHeight);
        CGFloat variantWidth = MIN(variantSize.width, availableWidth - titleWidth - labelSpacing);
        _variantLabel.frame = CGRectMake(startingX + availableWidth - variantWidth, variantY, variantWidth, variantHeight);
    }
    else
    {
        CGFloat variantWidth = CGFloor(availableWidth / 2.0f) - labelSpacing;
        CGFloat variantOffset = startingX + availableWidth - variantWidth;
        if (_minLeftPadding > FLT_EPSILON) {
            variantOffset = MAX(startingX + titleSize.width + 4.0, _minLeftPadding + self.safeAreaInset.left);
        }
        _variantLabel.frame = CGRectMake(variantOffset, variantY, variantWidth, variantHeight);
        CGFloat titleWidth = MIN(titleSize.width, availableWidth - variantWidth - labelSpacing);
        _titleLabel.frame = CGRectMake(startingX, titleY, titleWidth, titleHeight);
    }
    
    if (_iconView.image != nil)
    {
        CGSize iconSize = _iconView.image.size;
        CGFloat iconCenterX = 29.0f + classicInset + self.safeAreaInset.left;
        _iconView.frame = CGRectMake(CGFloor(iconCenterX - iconSize.width / 2.0f), CGFloor((bounds.size.height - iconSize.height) / 2.0f), iconSize.width, iconSize.height);
    }
    
    if (_variantIconView.image != nil) {
        _variantIconView.frame = CGRectMake(CGRectGetMinX(_variantLabel.frame) - 8.0 - _variantIconView.image.size.width, CGFloor(bounds.size.height - _variantIconView.image.size.height) / 2, _variantIconView.image.size.width, _variantIconView.image.size.height);
    }
    
    if (hasDescription)
    {
        CGFloat descriptionX = startingX;
        CGFloat descriptionWidth = MAX(0.0f, self.bounds.size.width - descriptionX - 15.0f - classicInset - self.safeAreaInset.right);
        _descriptionLabel.frame = CGRectMake(descriptionX, TGCollectionItemDescriptionVariantTop, descriptionWidth, TGCollectionItemDescriptionTextHeight(_descriptionLabel.text, descriptionWidth));
    }
}

@end
