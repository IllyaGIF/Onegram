#import "TGModernConversationActionInputPanel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import "../submodules/LegacyComponents/LegacyComponents/ASHandle.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static TGBrandedIOS6ActionIcon TGModernConversationActionInputPanelBrandedIcon(TGModernConversationActionInputPanelIcon icon)
{
    switch (icon)
    {
        case TGModernConversationActionInputPanelIconMute:
            return TGBrandedIOS6ActionIconMute;
        case TGModernConversationActionInputPanelIconUnmute:
            return TGBrandedIOS6ActionIconUnmute;
        case TGModernConversationActionInputPanelIconShare:
            return TGBrandedIOS6ActionIconShare;
        default:
            return TGBrandedIOS6ActionIconJoin;
    }
}

@interface TGModernConversationActionInputPanel ()
{
    UIEdgeInsets _safeAreaInset;
    
    NSString *_action;
    NSString *_secondaryAction;
    
    CALayer *_stripeLayer;
    UIImageView *_brandedBackgroundView;
    CGSize _brandedBackgroundSize;
    CGFloat _brandedBackgroundTopOutset;
    
    TGModernButton *_actionButton;
    UIImageView *_iconView;
    UIEdgeInsets _iconOutsets;
    UIFont *_defaultTitleFont;
    
    TGModernButton *_secondaryButton;
    UIImageView *_secondaryIconView;
    UIEdgeInsets _secondaryIconOutsets;
    
    UIEdgeInsets _brandedButtonOutsets;
    
    TGActivityIndicatorView *_activityIndicator;
    
    TGModernConversationActionInputPanelIcon _icon;
    TGModernConversationActionInputPanelIcon _secondaryIcon;
    UIColor *_actionColor;
    bool _destructive;
    bool _branded;
}

@end

@implementation TGModernConversationActionInputPanel

- (CGFloat)baseHeight
{
    if ([TGPresentation brandedIOS6Style])
        return [TGPresentation brandedIOS6ConversationAppearance].actionPanelHeight;
    
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 45.0f : 56.0f;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, frame.size.width, [self baseHeight])];
    if (self)
    {
        self.backgroundColor = UIColorRGB(0xf7f7f7);
        
        _stripeLayer = [[CALayer alloc] init];
        _stripeLayer.backgroundColor = UIColorRGB(0xb2b2b2).CGColor;
        [self.layer addSublayer:_stripeLayer];
        
        _actionButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        _actionButton.adjustsImageWhenDisabled = false;
        _actionButton.adjustsImageWhenHighlighted = false;
        [_actionButton addTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_actionButton];
        _defaultTitleFont = _actionButton.titleLabel.font;
        
        _iconView = [[UIImageView alloc] init];
        _iconView.userInteractionEnabled = false;
        
        _secondaryButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        _secondaryButton.adjustsImageWhenDisabled = false;
        _secondaryButton.adjustsImageWhenHighlighted = false;
        _secondaryButton.hidden = true;
        [_secondaryButton addTarget:self action:@selector(secondaryButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_secondaryButton];
        
        _secondaryIconView = [[UIImageView alloc] init];
        _secondaryIconView.userInteractionEnabled = false;
        [_secondaryButton addSubview:_secondaryIconView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    _branded = [TGPresentation brandedIOS6Style];
    if (_branded)
    {
        if (_brandedBackgroundView == nil)
        {
            _brandedBackgroundView = [[UIImageView alloc] init];
            _brandedBackgroundView.userInteractionEnabled = false;
            [self insertSubview:_brandedBackgroundView atIndex:0];
        }
        _brandedBackgroundView.hidden = false;
        _brandedBackgroundSize = CGSizeZero;
        _stripeLayer.hidden = true;
        self.backgroundColor = [TGPresentation brandedIOS6ConversationAppearance].inputPanelExtensionColor;
    }
    else
    {
        _brandedBackgroundView.hidden = true;
        _stripeLayer.hidden = false;
        _stripeLayer.backgroundColor = presentation.pallete.barSeparatorColor.CGColor;
        self.backgroundColor = presentation.pallete.barBackgroundColor;
    }
    
    if (_destructive)
        _actionColor = presentation.pallete.destructiveColor;
    
    [self updateButtonAppearance];
    [self setNeedsLayout];
}

- (void)setActionWithTitle:(NSString *)title action:(NSString *)action
{
    _destructive = true;
    [self setActionWithTitle:title action:action color:self.presentation.pallete.destructiveColor];
}

- (void)setActionWithTitle:(NSString *)title action:(NSString *)action color:(UIColor *)color
{
    [self setActionWithTitle:title action:action color:color icon:TGModernConversationActionInputPanelIconNone];
}

- (void)setActionWithTitle:(NSString *)title action:(NSString *)action color:(UIColor *)color icon:(TGModernConversationActionInputPanelIcon)icon
{
    _action = action;
    _actionColor = color;
    _icon = icon;
    
    [_actionButton setTitle:title forState:UIControlStateNormal];
    
    [self updateButtonAppearance];
    [self setNeedsLayout];
}

- (void)setSecondaryAction:(NSString *)action icon:(TGModernConversationActionInputPanelIcon)icon
{
    _secondaryAction = action;
    _secondaryIcon = icon;
    _secondaryButton.hidden = action == nil;
    
    [self updateButtonAppearance];
    [self setNeedsLayout];
}

- (UIImage *)modernIconImage:(TGModernConversationActionInputPanelIcon)icon
{
    UIColor *accentColor = self.presentation.pallete.accentColor;
    if (accentColor == nil)
        return nil;
    
    switch (icon)
    {
        case TGModernConversationActionInputPanelIconJoin:
            return [TGPresentationAssets actionPanelJoinIcon:accentColor];
        case TGModernConversationActionInputPanelIconShare:
            return TGTintedImage([TGPresentation brandedIOS6ActionIconTemplate:TGBrandedIOS6ActionIconShare], accentColor);
        default:
            return nil;
    }
}

- (void)updateButtonAppearance
{
    if (_branded)
    {
        OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
        UIEdgeInsets buttonOutsets = UIEdgeInsetsZero;
        UIImage *backgroundImage = [TGPresentation brandedIOS6ActionButtonImageHighlighted:false outsets:&buttonOutsets];
        UIImage *highlightedBackgroundImage = [TGPresentation brandedIOS6ActionButtonImageHighlighted:true outsets:NULL];
        _brandedButtonOutsets = buttonOutsets;
        
        for (TGModernButton *button in @[_actionButton, _secondaryButton])
        {
            button.modernHighlight = false;
            [button setBackgroundImage:backgroundImage forState:UIControlStateNormal];
            [button setBackgroundImage:highlightedBackgroundImage forState:UIControlStateHighlighted];
        }
        
        _actionButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _actionButton.titleLabel.font = appearance.actionButtonFont;
        _actionButton.titleLabel.shadowOffset = appearance.actionButtonTitleShadowOffset;
        [_actionButton setTitleColor:appearance.actionButtonTitleColor];
        [_actionButton setTitleShadowColor:appearance.actionButtonTitleShadowColor forState:UIControlStateNormal];
        
        UIEdgeInsets iconOutsets = UIEdgeInsetsZero;
        _iconView.image = _icon == TGModernConversationActionInputPanelIconNone ? nil : [TGPresentation brandedIOS6ActionIconImage:TGModernConversationActionInputPanelBrandedIcon(_icon) outsets:&iconOutsets];
        _iconOutsets = iconOutsets;
        
        UIEdgeInsets secondaryIconOutsets = UIEdgeInsetsZero;
        _secondaryIconView.image = _secondaryIcon == TGModernConversationActionInputPanelIconNone ? nil : [TGPresentation brandedIOS6ActionIconImage:TGModernConversationActionInputPanelBrandedIcon(_secondaryIcon) outsets:&secondaryIconOutsets];
        _secondaryIconOutsets = secondaryIconOutsets;
    }
    else
    {
        _brandedButtonOutsets = UIEdgeInsetsZero;
        
        for (TGModernButton *button in @[_actionButton, _secondaryButton])
        {
            [button setBackgroundImage:nil forState:UIControlStateNormal];
            [button setBackgroundImage:nil forState:UIControlStateHighlighted];
            button.modernHighlight = true;
        }
        
        _actionButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        _actionButton.titleLabel.font = _defaultTitleFont;
        _actionButton.titleLabel.shadowOffset = CGSizeZero;
        [_actionButton setTitleShadowColor:nil forState:UIControlStateNormal];
        if (_actionColor != nil)
            [_actionButton setTitleColor:_actionColor];
        
        _iconView.image = [self modernIconImage:_icon];
        _iconOutsets = UIEdgeInsetsZero;
        
        _secondaryIconView.image = [self modernIconImage:_secondaryIcon];
        _secondaryIconOutsets = UIEdgeInsetsZero;
    }
    
    [_iconView sizeToFit];
    [_secondaryIconView sizeToFit];
    
    if (_iconView.image != nil)
    {
        if (_iconView.superview != _actionButton)
            [_actionButton addSubview:_iconView];
    }
    else
        [_iconView removeFromSuperview];
}

- (void)setActivity:(bool)activity
{
    _actionButton.userInteractionEnabled = !activity;
    
    if (activity)
    {
        if (_activityIndicator == nil)
        {
            _activityIndicator = [[TGActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            _activityIndicator.color = self.presentation.pallete.secondaryTextColor;
        }
        
        if (_activityIndicator.superview == nil)
        {
            [self addSubview:_activityIndicator];
            [_activityIndicator startAnimating];
            [self setNeedsLayout];
        }
    }
    else
    {
        [_activityIndicator stopAnimating];
        [_activityIndicator removeFromSuperview];
    }
}

- (void)adjustForSize:(CGSize)size keyboardHeight:(CGFloat)keyboardHeight duration:(NSTimeInterval)duration animationCurve:(int)animationCurve contentAreaHeight:(CGFloat)contentAreaHeight safeAreaInset:(UIEdgeInsets)safeAreaInset
{
    [self _adjustForSize:size keyboardHeight:keyboardHeight duration:duration animationCurve:animationCurve contentAreaHeight:contentAreaHeight safeAreaInset:safeAreaInset];
}

- (void)_adjustForSize:(CGSize)size keyboardHeight:(CGFloat)keyboardHeight duration:(NSTimeInterval)duration animationCurve:(int)animationCurve contentAreaHeight:(CGFloat)__unused contentAreaHeight safeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    
    dispatch_block_t block = ^
    {
        CGSize messageAreaSize = size;
        
        self.frame = CGRectMake(0, messageAreaSize.height - keyboardHeight - [self baseHeight] - safeAreaInset.bottom, messageAreaSize.width, [self baseHeight] + safeAreaInset.bottom);
        [self layoutSubviews];
    };
    
    if (duration > DBL_EPSILON)
        [UIView animateWithDuration:duration delay:0 options:animationCurve << 16 animations:block completion:nil];
    else
        block();
}

- (void)changeToSize:(CGSize)size keyboardHeight:(CGFloat)keyboardHeight duration:(NSTimeInterval)duration contentAreaHeight:(CGFloat)contentAreaHeight safeAreaInset:(UIEdgeInsets)safeAreaInset
{
    [self _adjustForSize:size keyboardHeight:keyboardHeight duration:duration animationCurve:0 contentAreaHeight:contentAreaHeight safeAreaInset:safeAreaInset];
}

- (CGSize)iconGlyphSize:(UIImageView *)iconView outsets:(UIEdgeInsets)outsets
{
    if (iconView.image == nil)
        return CGSizeZero;
    
    CGSize size = iconView.image.size;
    return CGSizeMake(size.width - outsets.left - outsets.right, size.height - outsets.top - outsets.bottom);
}

- (void)layoutBrandedButtonsWithBaseHeight:(CGFloat)baseHeight
{
    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    CGSize size = self.frame.size;
    
    if (!CGSizeEqualToSize(_brandedBackgroundSize, CGSizeMake(size.width, baseHeight)))
    {
        CGFloat topOutset = 0.0f;
        _brandedBackgroundView.image = [TGPresentation brandedIOS6InputPanelBackgroundImageForSize:CGSizeMake(size.width, baseHeight) topOutset:&topOutset];
        _brandedBackgroundTopOutset = topOutset;
        _brandedBackgroundSize = CGSizeMake(size.width, baseHeight);
    }
    _brandedBackgroundView.frame = CGRectMake(0.0f, -_brandedBackgroundTopOutset, size.width, baseHeight + _brandedBackgroundTopOutset);
    
    CGFloat buttonHeight = appearance.actionButtonHeight;
    CGFloat buttonTop = CGFloor((baseHeight - buttonHeight) / 2.0f);
    CGFloat spacing = appearance.actionButtonSpacing;
    CGFloat contentInset = appearance.actionButtonContentInset;
    CGFloat contentWidth = size.width - _safeAreaInset.left - _safeAreaInset.right;
    CGFloat secondaryWidth = _secondaryAction != nil ? appearance.actionIconButtonWidth + spacing : 0.0f;
    
    CGSize iconSize = [self iconGlyphSize:_iconView outsets:_iconOutsets];
    CGFloat iconWidth = iconSize.width > FLT_EPSILON ? iconSize.width + appearance.actionButtonIconSpacing : 0.0f;
    CGFloat titleWidth = CGCeil([_actionButton.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, buttonHeight)].width);
    
    CGFloat maximumPrimaryWidth = MAX(0.0f, contentWidth - spacing * 2.0f - secondaryWidth);
    CGFloat primaryWidth = MIN(maximumPrimaryWidth, MAX(appearance.actionButtonMinimumWidth, contentInset * 2.0f + titleWidth + iconWidth));
    titleWidth = MIN(titleWidth, MAX(0.0f, primaryWidth - contentInset * 2.0f - iconWidth));
    
    CGFloat originX = _safeAreaInset.left + CGFloor((contentWidth - primaryWidth - secondaryWidth) / 2.0f);
    UIEdgeInsets outsets = _brandedButtonOutsets;
    
    _actionButton.frame = CGRectMake(originX - outsets.left, buttonTop - outsets.top, primaryWidth + outsets.left + outsets.right, buttonHeight + outsets.top + outsets.bottom);
    CGFloat titleLeft = CGFloor((primaryWidth - titleWidth - iconWidth) / 2.0f);
    _actionButton.contentEdgeInsets = UIEdgeInsetsMake(outsets.top, outsets.left + titleLeft, outsets.bottom, outsets.right + primaryWidth - titleLeft - titleWidth);
    
    if (_iconView.image != nil)
    {
        _iconView.frame = CGRectMake(outsets.left + titleLeft + titleWidth + appearance.actionButtonIconSpacing - _iconOutsets.left, outsets.top + CGFloor((buttonHeight - iconSize.height) / 2.0f) - _iconOutsets.top, _iconView.image.size.width, _iconView.image.size.height);
    }
    
    if (_secondaryAction != nil)
    {
        CGFloat secondaryButtonWidth = appearance.actionIconButtonWidth;
        _secondaryButton.frame = CGRectMake(originX + primaryWidth + spacing - outsets.left, buttonTop - outsets.top, secondaryButtonWidth + outsets.left + outsets.right, buttonHeight + outsets.top + outsets.bottom);
        
        CGSize secondaryIconSize = [self iconGlyphSize:_secondaryIconView outsets:_secondaryIconOutsets];
        _secondaryIconView.frame = CGRectMake(outsets.left + CGFloor((secondaryButtonWidth - secondaryIconSize.width) / 2.0f) - _secondaryIconOutsets.left, outsets.top + CGFloor((buttonHeight - secondaryIconSize.height) / 2.0f) - _secondaryIconOutsets.top, _secondaryIconView.image.size.width, _secondaryIconView.image.size.height);
    }
}

- (void)layoutModernButtonsWithBaseHeight:(CGFloat)baseHeight
{
    CGSize size = self.frame.size;
    CGFloat secondaryWidth = _secondaryAction != nil ? baseHeight : 0.0f;
    
    _actionButton.frame = CGRectMake(secondaryWidth, 0.0f, size.width - secondaryWidth * 2.0f, baseHeight);
    
    if (_iconView.image != nil)
    {
        CGSize titleSize = [_actionButton.titleLabel sizeThatFits:_actionButton.bounds.size];
        [_actionButton setContentEdgeInsets:UIEdgeInsetsMake(0.0f, _iconView.frame.size.width + 9.0f, 0.0f, 0.0f)];
        _iconView.frame = CGRectOffset(_iconView.bounds, CGFloor(_actionButton.frame.size.width - titleSize.width - _iconView.frame.size.width - 9.0f) / 2.0f, CGFloor(_actionButton.frame.size.height - _iconView.frame.size.height) / 2.0f);
    }
    else
    {
        [_actionButton setContentEdgeInsets:UIEdgeInsetsZero];
    }
    
    if (_secondaryAction != nil)
    {
        _secondaryButton.frame = CGRectMake(size.width - _safeAreaInset.right - secondaryWidth, 0.0f, secondaryWidth, baseHeight);
        _secondaryIconView.frame = CGRectOffset(_secondaryIconView.bounds, CGFloor((secondaryWidth - _secondaryIconView.frame.size.width) / 2.0f), CGFloor((baseHeight - _secondaryIconView.frame.size.height) / 2.0f));
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat baseHeight = [self baseHeight];
    
    _stripeLayer.frame = CGRectMake(0.0f, -TGScreenPixel, self.frame.size.width, TGScreenPixel);
    
    if (_branded)
        [self layoutBrandedButtonsWithBaseHeight:baseHeight];
    else
        [self layoutModernButtonsWithBaseHeight:baseHeight];
    
    _activityIndicator.frame = CGRectMake(self.frame.size.width - _activityIndicator.frame.size.width - 12.0f - _safeAreaInset.right, CGFloor((baseHeight - _activityIndicator.frame.size.height) / 2.0f), _activityIndicator.frame.size.width, _activityIndicator.frame.size.height);
}

- (void)actionButtonPressed
{
    if (_action != nil)
        [_companionHandle requestAction:@"actionPanelAction" options:@{@"action": _action}];
}

- (void)secondaryButtonPressed
{
    if (_secondaryAction != nil)
        [_companionHandle requestAction:@"actionPanelAction" options:@{@"action": _secondaryAction}];
}

@end
