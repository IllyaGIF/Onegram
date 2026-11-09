/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGGroupInfoCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"


#import "../submodules/LegacyComponents/LegacyComponents/TGTextField.h"

#import "TGPresentation.h"
#import "TGReusableLabel.h"
#import "TGOnegramSettings.h"
#import "TGProfileHeaderLayout.h"
#import "TGStoryRingView.h"

@interface TGGroupInfoCollectionItemView ()
{
    bool _editing;
    
    bool _updatingTitle;
    bool _updatingAvatar;
    
    TGLetteredAvatarView *_avatarView;
    UIImageView *_avatarIconView;
    UIImageView *_avatarOverlay;
    UIActivityIndicatorView *_activityIndicator;
    
    UIImageView *_verifiedIcon;
    
    TGReusableLabel *_titleLabel;
    TGTextField *_titleField;
    UIView *_editingSeparator;
    
    int64_t _groupId;

    UILabel *_subtitleLabel;
    TGStoryRingView *_storyRingView;
    NSString *_avatarUri;
    CGFloat _avatarDiameter;
    bool _avatarShowsImage;
}

@end

@implementation TGGroupInfoCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {   
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(15, 10, 66, 66)];
        [_avatarView setSingleFontSize:28.0f doubleFontSize:28.0f useBoldFont:false];
        _avatarView.fadeTransition = true;
        _avatarView.userInteractionEnabled = true;
        [_avatarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapGesture:)]];
        [self addSubview:_avatarView];
        
        _avatarIconView = [[UIImageView alloc] init];
        [_avatarView addSubview:_avatarIconView];
        
        _titleLabel = [[TGReusableLabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.font = TGBoldSystemFontOfSize(20);
        _titleLabel.numberOfLines = 2;
        [self addSubview:_titleLabel];
    }
    return self;
}

- (void)dealloc
{
    _titleField.delegate = nil;
    [_titleField removeTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _subtitleLabel.textColor = presentation.pallete.collectionMenuVariantColor;
    _verifiedIcon.image = presentation.images.profileVerifiedIcon;
}

- (bool)usesModernLayout
{
    return !_editing && TGOnegramModernInterfaceEnabled();
}

- (CGFloat)currentAvatarDiameter
{
    return [self usesModernLayout] ? TGProfileHeaderAvatarSize : 64.0f;
}

- (void)setStoryRingState:(int)storyRingState
{
    if (storyRingState != TGStoryRingStateNone && _storyRingView == nil)
    {
        _storyRingView = [[TGStoryRingView alloc] init];
        _storyRingView.lineWidth = 3.0f;
        [self insertSubview:_storyRingView belowSubview:_avatarView];
    }
    _storyRingView.state = (TGStoryRingState)storyRingState;
    [self setNeedsLayout];
}

- (void)setSubtitle:(NSString *)subtitle
{
    if (_subtitleLabel == nil)
    {
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.backgroundColor = [UIColor clearColor];
        _subtitleLabel.font = TGProfileHeaderSubtitleFont();
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _subtitleLabel.textColor = self.presentation.pallete.collectionMenuVariantColor;
        [self addSubview:_subtitleLabel];
    }
    if (!TGStringCompare(_subtitleLabel.text, subtitle))
    {
        _subtitleLabel.text = subtitle;
        [self setNeedsLayout];
    }
}

- (id)avatarView
{
    return _avatarView;
}

- (void)setGroupId:(int64_t)groupId
{
    _groupId = groupId;
}

- (void)setIsVerified:(bool)isVerified {
    if (_isVerified != isVerified) {
        _isVerified = isVerified;
        
        if (_isVerified) {
            if (_verifiedIcon == nil) {
                _verifiedIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 16.0f, 16.0f)];
                _verifiedIcon.image = self.presentation.images.profileVerifiedIcon;
            }
            if (_verifiedIcon.superview == nil) {
                [self.contentView addSubview:_verifiedIcon];
            }
        } else if (_verifiedIcon.superview != nil) {
            [_verifiedIcon removeFromSuperview];
        }
        
        [self setNeedsLayout];
    }
}

- (void)setAvatarUri:(NSString *)avatarUri animated:(bool)animated
{
    _avatarUri = avatarUri;
    _avatarShowsImage = false;
    CGFloat diameter = [self currentAvatarDiameter];
    bool diameterChanged = fabs(_avatarDiameter - diameter) > FLT_EPSILON;
    if (diameterChanged)
    {
        _avatarDiameter = diameter;
        CGFloat fontSize = diameter > 64.0f ? 42.0f : 28.0f;
        [_avatarView setSingleFontSize:fontSize doubleFontSize:fontSize useBoldFont:false];
    }
    UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:diameter];
    UIImage *currentPlaceholder = [_avatarView currentImage];
    if (currentPlaceholder == nil)
        currentPlaceholder = placeholder;
    
    if (avatarUri.length == 0)
        [_avatarView loadGroupPlaceholderWithSize:CGSizeMake(diameter, diameter) conversationId:_groupId title:_isBroadcast ? @"" : _titleLabel.text placeholder:placeholder];
    else if (diameterChanged || !TGStringCompare([_avatarView currentUrl], avatarUri))
    {
        _avatarView.fadeTransitionDuration = animated ? 0.3 : 0.1;
        [_avatarView loadImage:avatarUri filter:[[NSString alloc] initWithFormat:@"circle:%.0fx%.0f", diameter, diameter] placeholder:currentPlaceholder forceFade:animated];
    }
}

- (void)updateAvatarForCurrentLayout
{
    if (_avatarShowsImage || _avatarDiameter < FLT_EPSILON || fabs(_avatarDiameter - [self currentAvatarDiameter]) < FLT_EPSILON)
        return;
    [self setAvatarUri:_avatarUri animated:false];
}

- (void)setAvatarImage:(UIImage *)avatarImage animated:(bool)__unused animated
{
    _avatarShowsImage = true;
    if (avatarImage == nil) {
        static UIImage *placeholder = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^ {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(64.0f, 64.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, UIColorRGB(0xd8d8d8).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0, 0.0, 64.0f, 64.0f));
            UIImage *iconImage = TGImageNamed(@"CreateGroupAvatarPlaceholderIcon.png");
            [iconImage drawAtPoint:CGPointMake(CGFloor((64.0f - iconImage.size.width) / 2.0f) + TGRetinaPixel, CGFloor((64.0f - iconImage.size.height) / 2.0f))];
            placeholder = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        [_avatarView loadImage:placeholder];
    } else {
        [_avatarView loadImage:avatarImage];
    }
}

- (void)setTitle:(NSString *)title
{
    if (!TGStringCompare(title, _titleLabel.text))
        _titleLabel.text = title;
    
    if (!_editing && !TGStringCompare(title, _titleField.text))
        _titleField.text = title;
    
    if (!_isBroadcast && _groupId != 0)
        [_avatarView setTitle:title];
    
    [self setNeedsLayout];
}

- (void)setUpdatingTitle:(bool)updatingTitle animated:(bool)__unused animated
{
    _updatingTitle = updatingTitle;
    
    _titleField.enabled = !_updatingTitle;
}

- (void)setUpdatingAvatar:(bool)updatingAvatar animated:(bool)__unused animated
{
    _updatingAvatar = updatingAvatar;
    
    if (_updatingAvatar)
    {
        if (_avatarOverlay == nil)
        {
            static UIImage *overlayImage = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                UIGraphicsBeginImageContextWithOptions(CGSizeMake(64.0f, 64.0f), false, 0.0f);
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.5f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, 64.0f, 64.0f));
                
                overlayImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
            });
            
            _avatarOverlay = [[UIImageView alloc] initWithImage:overlayImage];
            _avatarOverlay.frame = _avatarView.frame;
            _avatarOverlay.userInteractionEnabled = false;
            [self insertSubview:_avatarOverlay aboveSubview:_avatarView];
        }
        
        if (_activityIndicator == nil)
        {
            _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            _activityIndicator.userInteractionEnabled = false;
            CGRect activityFrame = _activityIndicator.frame;
            activityFrame.origin = CGPointMake(_avatarView.frame.origin.x + CGFloor((_avatarView.frame.size.width - activityFrame.size.width) / 2.0f), _avatarView.frame.origin.y + CGFloor((_avatarView.frame.size.height - activityFrame.size.height) / 2.0f));
            _activityIndicator.frame = activityFrame;
            [self insertSubview:_activityIndicator aboveSubview:_avatarOverlay];
        }
        
        _activityIndicator.hidden = false;
        [_activityIndicator startAnimating];
        
        if (animated)
        {
            _avatarOverlay.alpha = 0.0f;
            _activityIndicator.alpha = 0.0f;
            [UIView animateWithDuration:0.3 animations:^
            {
                _avatarOverlay.alpha = 1.0f;
                _activityIndicator.alpha = 1.0f;
            }];
        }
        else
        {
            _avatarOverlay.alpha = 1.0f;
            _activityIndicator.alpha = 1.0f;
        }
    }
    else if (_avatarOverlay != nil)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                _avatarOverlay.alpha = 0.0f;
                _activityIndicator.alpha = 0.0f;
            } completion:^(BOOL finished) {
                if (finished)
                    [_activityIndicator stopAnimating];
            }];
        }
        else
        {
            _avatarOverlay.alpha = 0.0f;
            [_activityIndicator stopAnimating];
            _activityIndicator.alpha = 0.0f;
        }
    }
}

- (void)setIsBroadcast:(bool)isBroadcast
{
    if (_isBroadcast != isBroadcast)
    {
        _isBroadcast = isBroadcast;
        
        _avatarIconView.image = _isBroadcast ? TGImageNamed(@"BroadcastLargeAvatarIcon.png") : nil;
        
        [self setNeedsLayout];
    }
}

- (void)setEditing:(bool)editing animated:(bool)__unused animated
{
    if (_editing != editing)
    {
        _editing = editing;
        
        _verifiedIcon.hidden = _editing;
        
        if (_editing)
        {
            if (_titleField == nil)
            {
                _titleField = [[TGTextField alloc] init];
                [_titleField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
                _titleField.textColor = self.presentation.pallete.collectionMenuTextColor;
                _titleField.keyboardAppearance = self.presentation.pallete.isDark ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
                _titleField.font = TGSystemFontOfSize(20);
                _titleField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
                _titleField.enabled = !_updatingTitle;
                if (_isBroadcast) {
                    _titleField.placeholder = TGLocalized(@"GroupInfo.BroadcastListNamePlaceholder");
                } else if (_isChannel) {
                    _titleField.placeholder = TGLocalized(@"GroupInfo.ChannelListNamePlaceholder");
                } else {
                    _titleField.placeholder = TGLocalized(@"GroupInfo.GroupNamePlaceholder");
                }
                _titleField.placeholderColor = self.presentation.pallete.collectionMenuPlaceholderColor;
                _titleField.placeholderFont = _titleField.font;
                if (TGIsRTL())
                    _titleField.textAlignment = NSTextAlignmentRight;
                else if (iosMajorVersion() >= 7)
                    _titleField.textAlignment = NSTextAlignmentNatural;
            }
            
            if (_editingSeparator == nil)
            {
                _editingSeparator = [[UIView alloc] init];
                _editingSeparator.backgroundColor = self.presentation.pallete.collectionMenuSeparatorColor;
                _editingSeparator.userInteractionEnabled = false;
                [self addSubview:_editingSeparator];
            }
            
            if ([_titleField superview] == nil)
                [self addSubview:_titleField];
            
            _titleField.text = _titleLabel.text;
            
            if (animated)
            {
                _titleField.alpha = 0.0f;
                _editingSeparator.alpha = 0.0f;
                
                [UIView animateWithDuration:0.25 animations:^
                {
                    _titleField.alpha = 1.0f;
                    _editingSeparator.alpha = 1.0f;
                }];
                
                [UIView animateWithDuration:0.25 delay:0.05 options:0 animations:^
                {
                    _titleLabel.alpha = 0.0f;
                } completion:nil];
                
                [self setNeedsLayout];
            }
            else
            {
                _titleField.alpha = 1.0f;
                _titleLabel.alpha = 0.0f;
                _editingSeparator.alpha = 1.0f;
                
                [self setNeedsLayout];
            }
        }
        else
        {
            [_titleField resignFirstResponder];
            
            if (animated)
            {
                [UIView animateWithDuration:0.25 animations:^
                {
                    _titleLabel.alpha = 1.0f;
                    _editingSeparator.alpha = 0.0f;
                }];
                
                [UIView animateWithDuration:0.25 delay:0.05 options:0 animations:^
                {
                    _titleField.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                        [_titleField removeFromSuperview];
                }];
            }
            else
            {
                _titleField.alpha = 0.0f;
                _titleLabel.alpha = 1.0f;
                _editingSeparator.alpha = 0.0f;
                [_titleField removeFromSuperview];
            }
            
            if (!_isBroadcast && _groupId != 0)
                [_avatarView setTitle:_titleLabel.text];
        }
    }
}

- (void)makeNameFieldFirstResponder
{
    [_titleField becomeFirstResponder];
}

- (void)textFieldDidChange:(UITextField *)textField
{
    id<TGGroupInfoCollectionItemViewDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(groupInfoViewHasChangedEditedTitle:title:)])
        [delegate groupInfoViewHasChangedEditedTitle:self title:textField.text];
    
    if (_editing && !_isBroadcast && _groupId != 0)
        [_avatarView setTitle:textField.text];
}

#pragma mark -

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    
    if ([self usesModernLayout])
    {
        [self layoutModernHeader];
        return;
    }
    
    self.backgroundView.hidden = false;
    _subtitleLabel.hidden = true;
    _storyRingView.hidden = true;
    _titleLabel.font = TGBoldSystemFontOfSize(20);
    _titleLabel.numberOfLines = 2;
    _avatarView.frame = CGRectMake(15 + self.safeAreaInset.left, 10, 66, 66);
    [self updateAvatarForCurrentLayout];
    _avatarOverlay.frame = _avatarView.frame;
    
    CGSize iconSize = _avatarIconView.image.size;
    _avatarIconView.frame = (CGRect){{CGFloor((_avatarView.frame.size.width - iconSize.width) / 2.0f), CGFloor((_avatarView.frame.size.height - iconSize.height) / 2.0f + 1.0f)}, iconSize};
    
    CGFloat maxTitleWidth = bounds.size.width - 92 - 14 - self.safeAreaInset.left - self.safeAreaInset.right;
    
    if (_verifiedIcon.superview != nil) {
        maxTitleWidth -= _verifiedIcon.bounds.size.width + 5.0f;
    }
    
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(maxTitleWidth, CGFLOAT_MAX)];
    titleSize.width = MIN(titleSize.width, maxTitleWidth);
    if (titleSize.height < FLT_EPSILON)
    {
        NSString *currentText = _titleLabel.text;
        _titleLabel.text = @" ";
        titleSize = [_titleLabel sizeThatFits:CGSizeMake(maxTitleWidth, CGFLOAT_MAX)];
        _titleLabel.text = currentText;
    }
    
    titleSize.width = MIN(titleSize.width, maxTitleWidth);
    CGRect titleLabelFrame = CGRectMake(92 + self.safeAreaInset.left, floor((93.0f - titleSize.height) / 2.0f) - 2.0f, titleSize.width, titleSize.height);
    _titleLabel.frame = titleLabelFrame;
    
    _titleField.frame = CGRectMake(titleLabelFrame.origin.x, 22, maxTitleWidth, 44);
    
    if (_verifiedIcon.superview != nil) {
        _verifiedIcon.frame = CGRectOffset(_verifiedIcon.bounds, titleLabelFrame.origin.x + titleSize.width + 4.0f, titleLabelFrame.origin.y + 5.0f + TGRetinaPixel);
    }
    
    _editingSeparator.frame = CGRectMake(92.0f + self.safeAreaInset.left, 62.0f, bounds.size.width - 92.0f - self.safeAreaInset.left, TGScreenPixel);
}

- (void)layoutModernHeader
{
    CGRect bounds = self.bounds;
    self.backgroundView.hidden = true;
    _avatarView.frame = TGProfileHeaderAvatarFrame(bounds);
    [self updateAvatarForCurrentLayout];
    _avatarOverlay.frame = _avatarView.frame;
    _storyRingView.hidden = _storyRingView.state == TGStoryRingStateNone;
    [_storyRingView layoutAroundFrame:_avatarView.frame spacing:2.5f];
    _activityIndicator.center = CGPointMake(CGRectGetMidX(_avatarView.frame), CGRectGetMidY(_avatarView.frame));

    CGSize iconSize = _avatarIconView.image.size;
    _avatarIconView.frame = (CGRect){{CGFloor((_avatarView.frame.size.width - iconSize.width) / 2.0f), CGFloor((_avatarView.frame.size.height - iconSize.height) / 2.0f + 1.0f)}, iconSize};

    CGFloat horizontalInset = 15.0f;
    CGFloat contentLeft = horizontalInset + self.safeAreaInset.left;
    CGFloat contentWidth = MAX(0.0f, bounds.size.width - contentLeft - horizontalInset - self.safeAreaInset.right);
    bool showsVerified = _verifiedIcon.superview != nil && !_verifiedIcon.hidden;
    CGFloat badgeWidth = showsVerified ? _verifiedIcon.bounds.size.width + 4.0f : 0.0f;

    if (_titleLabel.font != TGProfileHeaderTitleFont())
        _titleLabel.font = TGProfileHeaderTitleFont();
    _titleLabel.numberOfLines = 1;
    CGFloat titleLineHeight = TGProfileHeaderTitleLineHeight();
    CGFloat maxTitleWidth = MAX(0.0f, contentWidth - badgeWidth);
    CGSize titleSize = [_titleLabel sizeThatFits:CGSizeMake(maxTitleWidth, titleLineHeight)];
    titleSize.width = MIN(CGCeil(titleSize.width), maxTitleWidth);
    CGFloat titleTop = TGProfileHeaderTitleTop();
    CGFloat titleX = contentLeft + CGFloor((contentWidth - titleSize.width - badgeWidth) / 2.0f);
    _titleLabel.frame = CGRectMake(titleX, titleTop + CGFloor((titleLineHeight - titleSize.height) / 2.0f), titleSize.width, titleSize.height);
    if (showsVerified)
    {
        CGSize verifiedSize = _verifiedIcon.bounds.size;
        _verifiedIcon.frame = CGRectMake(CGRectGetMaxX(_titleLabel.frame) + 4.0f, titleTop + CGFloor((titleLineHeight - verifiedSize.height) / 2.0f), verifiedSize.width, verifiedSize.height);
    }

    _subtitleLabel.hidden = _subtitleLabel.text.length == 0;
    _subtitleLabel.frame = CGRectMake(contentLeft, TGProfileHeaderSubtitleTop(), contentWidth, TGProfileHeaderSubtitleLineHeight());
}

#pragma mark -

- (void)avatarTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        id<TGGroupInfoCollectionItemViewDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(groupInfoViewHasTappedAvatar:)])
            [delegate groupInfoViewHasTappedAvatar:self];
    }
}

@end
