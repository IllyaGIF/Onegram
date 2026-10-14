#import "TGSwitchCollectionItemView.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGSettingsAppearance.h"
#import "../OnegramUI/Core/OGProfileAppearance.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGIconSwitchView.h"

#import "TGPresentation.h"

@interface TGSwitchCollectionItemView ()
{
    UILabel *_titleLabel;
    UISwitch *_switchView;
    bool _isEnabled;
    bool _isLocked;
    UIImageView *_iconView;
    bool _brandedUserInfoStyle;
    NSString *_iconName;
}

@end

@implementation TGSwitchCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {   
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17);
        _titleLabel.textAlignment = NSTextAlignmentLeft;
        [self addSubview:_titleLabel];
        
        if ([self isKindOfClass:[TGPermissionSwitchCollectionItemView class]] && iosMajorVersion() >= 8) {
            _switchView = [[TGIconSwitchView alloc] init];
        } else {
            _switchView = [[UISwitch alloc] init];
        }
        [_switchView addTarget:self action:@selector(switchValueChanged) forControlEvents:UIControlEventValueChanged];
        
        [self addSubview:_switchView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    if (_brandedUserInfoStyle && [TGPresentation brandedIOS6Style])
    {
        OGSettingsAppearance *rowAppearance = [OGTheme brandedTheme].profileAppearance.actionRowAppearance;
        [OGSettingsCell applyLegacyBrandedTitleStyleWithAppearance:rowAppearance titleLabel:_titleLabel];
        self.brandedGroupedAppearance = rowAppearance;
        self.classicIOS6HorizontalInset = rowAppearance.groupedHorizontalInset;
    }
    else
    {
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.shadowColor = nil;
        _titleLabel.shadowOffset = CGSizeZero;
        self.brandedGroupedAppearance = nil;
        self.classicIOS6HorizontalInset = 9.0f;
    }
    [self updateIcon];
    if (OGPlatformSetSwitchColors(_switchView, presentation.pallete.collectionMenuSwitchColor, presentation.pallete.collectionMenuSwitchColor != nil ? presentation.pallete.collectionMenuAccessoryColor : nil))
    {
        if ([_switchView isKindOfClass:[TGIconSwitchView class]])
            _switchView.backgroundColor = presentation.pallete.collectionMenuDestructiveColor;
    }
}

- (void)setFullSeparator:(bool)fullSeparator {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    self.separatorInset = fullSeparator ? 0.0f : 15.0f;
#endif
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
}

- (void)setIsOn:(bool)isOn animated:(bool)animated
{
    [_switchView setOn:isOn animated:animated];
}

- (void)setIsEnabled:(bool)isEnabled {
    _isEnabled = isEnabled;
    _titleLabel.alpha = isEnabled && !_isLocked ? 1.0f : 0.5f;
    _switchView.userInteractionEnabled = isEnabled;
    _switchView.alpha = isEnabled && !_isLocked ? 1.0f : 0.5f;
}

- (void)setIsLocked:(bool)isLocked {
    _isLocked = isLocked;
    _titleLabel.alpha = _isEnabled && !_isLocked ? 1.0f : 0.5f;
    _switchView.alpha = _isEnabled && !_isLocked ? 1.0f : 0.5f;
}


- (void)setIconName:(NSString *)iconName brandedUserInfoStyle:(bool)brandedUserInfoStyle
{
    _brandedUserInfoStyle = brandedUserInfoStyle;
    _iconName = iconName;
    if (self.presentation != nil)
        [self setPresentation:self.presentation];
    else
        [self updateIcon];
}

- (void)updateIcon
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGSettingsAppearance *rowAppearance = theme.profileAppearance.actionRowAppearance;
    UIImage *image = [TGPresentation brandedIOS6Style] && _brandedUserInfoStyle ? [OGSettingsCell legacyBrandedIconNamed:_iconName appearance:rowAppearance theme:theme] : nil;
    if (_iconView == nil && image != nil)
    {
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];
    }
    _iconView.image = image;
    _iconView.hidden = image == nil;
    if (image != nil)
        [OGSettingsCell applyLegacyBrandedIconStyleWithAppearance:rowAppearance iconView:_iconView];
    [self setNeedsLayout];
}

- (void)switchValueChanged
{
    id<TGSwitchCollectionItemViewDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(switchCollectionItemViewChangedValue:isOn:)])
        [delegate switchCollectionItemViewChangedValue:self isOn:_switchView.on];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect bounds = self.bounds;
    CGSize switchSize = _switchView.bounds.size;

    if (_brandedUserInfoStyle && [TGPresentation brandedIOS6Style])
    {
        OGSettingsAppearance *rowAppearance = [OGTheme brandedTheme].profileAppearance.actionRowAppearance;
        OGSettingsCellLegacyLayout layout;
        OGSettingsCellGetLegacyLayout(rowAppearance, bounds, self.safeAreaInset, switchSize, OGSettingsCellAccessoryControl, CGSizeZero, 0.0f, rowAppearance.titleTrailingSpacing, &layout);
        _switchView.frame = layout.accessoryFrame;
        _titleLabel.frame = layout.titleFrame;
        if (_iconView.image != nil)
        {
            _iconView.frame = layout.iconFrame;
        }
        return;
    }

    CGFloat switchY = CGFloor((bounds.size.height - switchSize.height) / 2.0f);
    CGFloat classicInset = [TGPresentation classicIOS6Style] ? 10.0f : 0.0f;
    _switchView.frame = CGRectMake(bounds.size.width - switchSize.width - 20.0f - self.safeAreaInset.right, switchY, switchSize.width, switchSize.height);
    CGFloat titleX = 15.0f + classicInset + self.safeAreaInset.left;
    CGFloat titleHeight = MAX(24.0f, ceilf(OGPlatformFontLineHeight(_titleLabel.font)));
    CGFloat titleY = CGFloor((bounds.size.height - titleHeight) / 2.0f);
    _titleLabel.frame = CGRectMake(titleX, titleY, MAX(0.0f, CGRectGetMinX(_switchView.frame) - titleX - 8.0f), titleHeight);
}

@end

@implementation TGPermissionSwitchCollectionItemView

@end
