#import "TGVariantCollectionItemView.h"
#import "TGSimpleImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGVariantCollectionItemView ()
{
    UILabel *_titleLabel;
    UILabel *_variantLabel;
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

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    bool classicIOS6Style = [TGPresentation classicIOS6Style];
    bool classicDarkStyle = classicIOS6Style && presentation.pallete.isDark;
    _titleLabel.textColor = _customTitleColor ?: (classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x111111) : presentation.pallete.collectionMenuTextColor);
    _variantLabel.textColor = _customVariantColor ?: (classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor);
    UIImage *disclosureImage = classicIOS6Style ? [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"] : presentation.images.collectionMenuDisclosureIcon;
    if (classicDarkStyle)
        disclosureImage = [TGPresentation classicIOS6ThemedImage:disclosureImage tintColor:presentation.pallete.collectionMenuAccessoryColor alpha:0.82f];
    _disclosureIndicator.image = disclosureImage;
    if ([TGPresentation brandedIOS6Style] && _brandedSettingsStyle)
    {
        _titleLabel.font = TGBoldSystemFontOfSize(18.0f);
        _titleLabel.textColor = UIColorRGB(0x000000);
        _titleLabel.shadowColor = UIColorRGBA(0x000000, 0.2f);
        _titleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _variantLabel.hidden = true;
        _iconView.image = _brandedSettingsIconName.length == 0 ? nil : [TGPresentation brandedIOS6ResourceImage:_brandedSettingsIconName];
        _disclosureIndicator.image = [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"];
    }
    else
    {
        _variantLabel.hidden = false;
    }
    if (disclosureImage != nil)
        _disclosureIndicator.frame = CGRectMake(0.0f, 0.0f, disclosureImage.size.width, disclosureImage.size.height);
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
    [_titleLabel setNeedsDisplay];
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
        _iconView.image = _brandedSettingsIconName.length == 0 ? nil : [TGPresentation brandedIOS6ResourceImage:_brandedSettingsIconName];
        _iconView.hidden = _iconView.image == nil;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.frame = CGRectMake(17.0f + self.safeAreaInset.left, CGFloor((bounds.size.height - 16.0f) / 2.0f) + 1.0f, 16.0f, 16.0f);
        _iconView.layer.shadowColor = [UIColor blackColor].CGColor;
        _iconView.layer.shadowOpacity = 0.1f;
        _iconView.layer.shadowRadius = 0.5f;
        _iconView.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _titleLabel.font = TGBoldSystemFontOfSize(18.0f);
        _titleLabel.textColor = UIColorRGB(0x000000);
        _titleLabel.shadowColor = UIColorRGBA(0x000000, 0.2f);
        _titleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _titleLabel.frame = CGRectMake(43.0f + self.safeAreaInset.left, 7.0f, MAX(0.0f, bounds.size.width - 90.0f - self.safeAreaInset.left - self.safeAreaInset.right), 22.0f);
        _variantLabel.hidden = true;
        _disclosureIndicator.hidden = false;
        _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 23.0f - self.safeAreaInset.right, CGFloor((bounds.size.height - _disclosureIndicator.frame.size.height) / 2.0f) + 1.0f, _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
        return;
    }

    CGFloat classicInset = [TGPresentation classicIOS6Style] ? 10.0f : 0.0f;
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
    CGFloat titleHeight = MAX(titleSize.height, ceilf(_titleLabel.font.lineHeight));
    CGFloat variantHeight = MAX(variantSize.height, ceilf(_variantLabel.font.lineHeight));
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
        _variantIconView.frame = CGRectMake(CGRectGetMinX(_variantLabel.frame) - 8.0 - _variantIconView.image.size.width, CGFloor(self.frame.size.height - _variantIconView.image.size.height) / 2, _variantIconView.image.size.width, _variantIconView.image.size.height);
    }
}

@end
