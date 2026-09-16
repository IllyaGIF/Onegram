#import "TGDisclosureActionCollectionItemView.h"

#import "TGSimpleImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

@interface TGDisclosureActionCollectionItemView ()
{
    UILabel *_titleLabel;
    TGSimpleImageView *_iconView;
    TGSimpleImageView *_disclosureIndicator;
    
    UILabel *_badgeLabel;
    TGSimpleImageView *_badgeView;
    bool _hideArrow;
    bool _brandedProfileMusic;
    bool _brandedSettingsStyle;
    NSString *_brandedSettingsIconName;
}

@end

@implementation TGDisclosureActionCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.textAlignment = NSTextAlignmentLeft;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17);
        [self addSubview:_titleLabel];
        
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
    _titleLabel.textColor = classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x111111) : presentation.pallete.collectionMenuTextColor;
    UIImage *disclosureImage = classicIOS6Style ? [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"] : presentation.images.collectionMenuDisclosureIcon;
    if (classicDarkStyle)
        disclosureImage = [TGPresentation classicIOS6ThemedImage:disclosureImage tintColor:presentation.pallete.collectionMenuAccessoryColor alpha:0.82f];
    _disclosureIndicator.image = disclosureImage;
    if (disclosureImage != nil)
        _disclosureIndicator.frame = CGRectMake(0.0f, 0.0f, disclosureImage.size.width, disclosureImage.size.height);
    
    _badgeLabel.textColor = self.presentation.pallete.collectionMenuBadgeTextColor;
    _badgeView.image = self.presentation.images.collectionMenuBadgeImage;

    if ([TGPresentation brandedIOS6Style] && _brandedSettingsStyle)
    {
        _titleLabel.font = TGBoldSystemFontOfSize(18.0f);
        _titleLabel.textColor = UIColorRGB(0x000000);
        _titleLabel.shadowColor = UIColorRGBA(0x000000, 0.2f);
        _titleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _iconView.image = _brandedSettingsIconName.length == 0 ? nil : [TGPresentation brandedIOS6ResourceImage:_brandedSettingsIconName];
        UIImage *brandedDisclosureImage = [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"];
        if (brandedDisclosureImage != nil)
        {
            _disclosureIndicator.image = brandedDisclosureImage;
            _disclosureIndicator.frame = CGRectMake(0.0f, 0.0f, brandedDisclosureImage.size.width, brandedDisclosureImage.size.height);
        }
        _disclosureIndicator.hidden = false;
    }
    else if ([TGPresentation brandedIOS6Style] && _brandedProfileMusic)
    {
        _titleLabel.font = TGSystemFontOfSize(15.0f);
        _titleLabel.textColor = UIColorRGB(0x111111);
        UIImage *brandedDisclosureImage = presentation.images.collectionMenuDisclosureIcon;
        if (brandedDisclosureImage != nil)
        {
            _disclosureIndicator.image = brandedDisclosureImage;
            _disclosureIndicator.frame = CGRectMake(0.0f, 0.0f, brandedDisclosureImage.size.width, brandedDisclosureImage.size.height);
        }
        _disclosureIndicator.hidden = false;
    }
    else
    {
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _disclosureIndicator.hidden = _hideArrow;
    }
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    
    [self setNeedsLayout];
    
    [_titleLabel setNeedsDisplay];
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

- (void)setBadge:(NSString *)badge {
    if (badge != nil) {
        if (_badgeLabel == nil) {
            _badgeLabel = [[UILabel alloc] init];
            _badgeLabel.font = TGSystemFontOfSize(14);
            _badgeLabel.backgroundColor = [UIColor clearColor];
            _badgeLabel.textColor = self.presentation.pallete.collectionMenuBadgeTextColor;
            [self addSubview:_badgeLabel];
            
            _badgeView = [[TGSimpleImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
            _badgeView.image = self.presentation.images.collectionMenuBadgeImage;
            
            [self addSubview:_badgeView];
            [self addSubview:_badgeLabel];
        }
        _badgeLabel.text = badge;
        [_badgeLabel sizeToFit];
    } else {
        [_badgeView removeFromSuperview];
        _badgeView = nil;
        [_badgeLabel removeFromSuperview];
        _badgeLabel = nil;
    }
    
    [self setNeedsLayout];
}

- (void)setHideArrow:(bool)hideArrow
{
    _hideArrow = hideArrow;
    _disclosureIndicator.hidden = hideArrow && !([TGPresentation brandedIOS6Style] && _brandedProfileMusic);
}


- (void)setBrandedProfileMusic:(bool)brandedProfileMusic
{
    _brandedProfileMusic = brandedProfileMusic;
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
        _disclosureIndicator.hidden = false;
        _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 23.0f - self.safeAreaInset.right, CGFloor((bounds.size.height - _disclosureIndicator.frame.size.height) / 2.0f) + 1.0f, _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
        _badgeView.hidden = true;
        _badgeLabel.hidden = true;
        return;
    }

    if ([TGPresentation brandedIOS6Style] && _brandedProfileMusic)
    {
        _iconView.hidden = true;
        _titleLabel.font = TGSystemFontOfSize(15.0f);
        CGFloat titleHeight = MAX(22.0f, ceilf(_titleLabel.font.lineHeight));
        _titleLabel.frame = CGRectMake(21.0f + self.safeAreaInset.left, CGFloor((bounds.size.height - titleHeight) / 2.0f), bounds.size.width - 66.0f - self.safeAreaInset.left - self.safeAreaInset.right, titleHeight);
        _disclosureIndicator.hidden = false;
        _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 27.0f - self.safeAreaInset.right, CGFloor((bounds.size.height - _disclosureIndicator.frame.size.height) / 2.0f), _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
        _badgeView.hidden = true;
        _badgeLabel.hidden = true;
        return;
    }

    _iconView.hidden = false;
    _badgeView.hidden = false;
    _badgeLabel.hidden = false;
    CGFloat classicInset = [TGPresentation classicIOS6Style] ? 10.0f : 0.0f;
    
    if (_iconView.image != nil)
    {
        CGSize iconSize = _iconView.image.size;
        CGFloat iconCenterX = 29.0f + classicInset + self.safeAreaInset.left;
        _iconView.frame = CGRectMake(CGFloor(iconCenterX - iconSize.width / 2.0f), CGFloor((bounds.size.height - iconSize.height) / 2.0f), iconSize.width, iconSize.height);
    }
    
    CGFloat startingX = (_iconView.image != nil) ? 59.0f : 15.0f;
    startingX += classicInset + self.safeAreaInset.left;
    CGFloat titleHeight = MAX(24.0f, ceilf(_titleLabel.font.lineHeight));
    _titleLabel.frame = CGRectMake(startingX, CGFloor((bounds.size.height - titleHeight) / 2.0f), bounds.size.width - startingX - 40.0f - classicInset - self.safeAreaInset.right, titleHeight);
    _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 15 - classicInset - self.safeAreaInset.right, CGFloor((bounds.size.height - _disclosureIndicator.frame.size.height) / 2), _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
    
    if (_badgeLabel != nil) {
        CGSize labelSize = _badgeLabel.frame.size;
        CGFloat badgeWidth = MAX(20.0f, labelSize.width + 12.0);
        _badgeView.frame = CGRectMake((_disclosureIndicator.hidden ? bounds.size.width - self.safeAreaInset.right : CGRectGetMinX(_disclosureIndicator.frame)) - 10.0 - badgeWidth, CGFloor((bounds.size.height - 20.0f) / 2.0f), badgeWidth, 20.0f);
        _badgeLabel.frame = CGRectMake(CGRectGetMinX(_badgeView.frame) + TGRetinaFloor((badgeWidth - labelSize.width) / 2.0f), CGRectGetMinY(_badgeView.frame) + 1.0f + TGScreenPixel, labelSize.width, labelSize.height);
    }
}

@end
