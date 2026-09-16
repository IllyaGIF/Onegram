#import "TGSwitchCollectionItemView.h"

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
        _titleLabel.font = TGBoldSystemFontOfSize(18.0f);
        _titleLabel.textColor = UIColorRGB(0x000000);
        _titleLabel.shadowColor = UIColorRGBA(0x000000, 0.2f);
        _titleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        self.classicIOS6HorizontalInset = 9.0f;
    }
    else
    {
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.shadowColor = nil;
        _titleLabel.shadowOffset = CGSizeZero;
        self.classicIOS6HorizontalInset = 9.0f;
    }
    if ([_switchView isKindOfClass:[UISwitch class]] && [_switchView respondsToSelector:@selector(setOnTintColor:)])
    {
        _switchView.onTintColor = presentation.pallete.collectionMenuSwitchColor;
        if ([_switchView isKindOfClass:[TGIconSwitchView class]])
            _switchView.backgroundColor = presentation.pallete.collectionMenuDestructiveColor;
        if (presentation.pallete.collectionMenuSwitchColor != nil)
            _switchView.tintColor = presentation.pallete.collectionMenuAccessoryColor;
        else
            _switchView.tintColor = nil;
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
    UIImage *image = iconName.length == 0 ? nil : ([TGPresentation brandedIOS6Style] && brandedUserInfoStyle ? [TGPresentation brandedIOS6ResourceImage:iconName] : nil);
    if (_iconView == nil && image != nil)
    {
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];
    }
    _iconView.image = image;
    _iconView.hidden = image == nil;
    if (_brandedUserInfoStyle && [TGPresentation brandedIOS6Style])
    {
        _titleLabel.font = TGBoldSystemFontOfSize(18.0f);
        _titleLabel.textColor = UIColorRGB(0x000000);
        _titleLabel.shadowColor = UIColorRGBA(0x000000, 0.2f);
        _titleLabel.shadowOffset = CGSizeMake(0.0f, 1.0f);
        self.classicIOS6HorizontalInset = 9.0f;
    }
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
    CGFloat switchY = CGFloor((bounds.size.height - switchSize.height) / 2.0f);
    CGFloat switchRightInset = _brandedUserInfoStyle && [TGPresentation brandedIOS6Style] ? 14.0f : 20.0f;
    _switchView.frame = CGRectMake(bounds.size.width - switchSize.width - switchRightInset - self.safeAreaInset.right, switchY, switchSize.width, switchSize.height);
    CGFloat titleX = 15.0f + self.safeAreaInset.left;
    if (_brandedUserInfoStyle && [TGPresentation brandedIOS6Style])
    {
        if (_iconView.image != nil)
        {
            _iconView.frame = CGRectMake(17.0f + self.safeAreaInset.left, CGFloor((bounds.size.height - 16.0f) / 2.0f) + 1.0f, 16.0f, 16.0f);
            _iconView.layer.shadowColor = [UIColor blackColor].CGColor;
            _iconView.layer.shadowOpacity = 0.1f;
            _iconView.layer.shadowRadius = 0.5f;
            _iconView.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
        }
        titleX = 43.0f + self.safeAreaInset.left;
    }
    CGFloat titleHeight = _brandedUserInfoStyle && [TGPresentation brandedIOS6Style] ? 22.0f : MAX(24.0f, ceilf(_titleLabel.font.lineHeight));
    CGFloat titleY = _brandedUserInfoStyle && [TGPresentation brandedIOS6Style] ? 7.0f : CGFloor((bounds.size.height - titleHeight) / 2.0f);
    _titleLabel.frame = CGRectMake(titleX, titleY, MAX(0.0f, CGRectGetMinX(_switchView.frame) - titleX - 8.0f), titleHeight);
}

@end

@implementation TGPermissionSwitchCollectionItemView

@end
