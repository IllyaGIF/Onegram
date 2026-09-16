#import "TGUserInfoCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGTextField.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernButton.h"

#import "TGSynchronizeContactsActor.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"
#import "TGReusableLabel.h"
#import "TGMarqueeLabel.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"
#import <QuartzCore/QuartzCore.h>

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

extern void TGIOS6LoadCustomEmojiThumbnail(int64_t documentId, void (^completion)(NSString *thumbnailUri));

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryTransitionView.h"

static const int32_t TGMarkedUserId = 314366525;

static UIImage *TGBrandedIOS6LightMetalImage(void)
{
    static UIImage *result = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIImage *image = [TGPresentation brandedIOS6ResourceImage:@"metal1"];
        if (image != nil)
        {
            UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale);
            [[UIColor whiteColor] setFill];
            UIRectFill(CGRectMake(0.0f, 0.0f, image.size.width, image.size.height));
            [image drawInRect:CGRectMake(0.0f, 0.0f, image.size.width, image.size.height) blendMode:kCGBlendModeNormal alpha:0.46f];
            result = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
    });
    return result;
}

@interface TGLetteredAvatarView (TGModernGalleryTransition) <TGModernGalleryTransitionView>

@end

@implementation TGLetteredAvatarView (TGModernGalleryTransition)

- (UIImage *)transitionImage
{
    return self.image;
}

@end

@interface TGUserInfoCollectionItemView () <UITextFieldDelegate>
{
    TGLetteredAvatarView *_avatarView;
    TGReusableLabel *_nameLabel;
    UILabel *_statusLabel;
    UILabel *_phoneLabel;
    UILabel *_usernameLabel;
    UIImageView *_brandedBackgroundView;
    UIImageView *_brandedAvatarReflectionView;
    UIImage *_brandedReflectedAvatarImage;
    UILabel *_aboutTitleLabel;
    UILabel *_aboutLabel;
    NSString *_about;
    bool _showCall;
    CGSize _avatarOffset;
    CGSize _nameOffset;
    
    NSString *_firstName;
    NSString *_lastName;
    
    TGTextField *_firstNameField;
    TGTextField *_lastNameField;
    
    bool _editing;
    bool _showCameraIcon;
    
    bool _multilineName;
    
    UIView *_editingFirstNameSeparator;
    UIView *_editingLastNameSeparator;
    
    UIImageView *_avatarIconView;
    UIImageView *_avatarOverlay;
    UIActivityIndicatorView *_activityIndicator;
    bool _avatarPlaceholderDisabled;
    
    int32_t _uidForPlaceholderCalculation;
    
    UIImageView *_verifiedIcon;
    UIImageView *_premiumIcon;
    TGRemoteImageView *_emojiStatusView;
    UIImageView *_markedUserBadgeView;
    UIImageView *_disclosureIndicator;
    
    TGModernButton *_callButton;

    TGDocumentMediaAttachment *_profileMusicDocument;
    TGModernButton *_profileMusicButton;
    UILabel *_profileMusicIconLabel;
    UILabel *_profileMusicTextLabel;
    UIImageView *_profileMusicArrowView;
    UIView *_profileMusicSeparatorView;
    CGFloat _brandedDetailsTextScale;
}

@end

@implementation TGUserInfoCollectionItemView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {   
        _brandedDetailsTextScale = 1.0f;
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(15, 15 + TGScreenPixel, 66, 66)];
        [_avatarView setSingleFontSize:28.0f doubleFontSize:28.0f useBoldFont:false];
        _avatarView.fadeTransition = true;
        _avatarView.userInteractionEnabled = true;
        [_avatarView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapGesture:)]];
        [self addSubview:_avatarView];
        
        _nameLabel = [[TGReusableLabel alloc] init];
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.textColor = [UIColor blackColor];
        _nameLabel.font = TGMediumSystemFontOfSize(20);
        _nameLabel.numberOfLines = 1;
        [self addSubview:_nameLabel];
        
        _statusLabel = [[UILabel alloc] init];
        _statusLabel.backgroundColor = [UIColor clearColor];
        _statusLabel.font = TGSystemFontOfSize(15.0f);
        [self addSubview:_statusLabel];
        
        _firstNameField = [[TGTextField alloc] init];
        _firstNameField.placeholder = TGLocalized(@"UserInfo.FirstNamePlaceholder");
        _firstNameField.placeholderFont = TGSystemFontOfSize(17.0f);
        _firstNameField.placeholderColor = UIColorRGB(0xc7c7cd);
        [_firstNameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        _firstNameField.textColor = [UIColor blackColor];
        _firstNameField.font = TGSystemFontOfSize(17.0f);
        _firstNameField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        if (TGIsRTL())
            _firstNameField.textAlignment = NSTextAlignmentRight;
        else if (iosMajorVersion() >= 7)
            _firstNameField.textAlignment = NSTextAlignmentNatural;
        _firstNameField.alpha = 0.0f;
        _firstNameField.hidden = true;
        _firstNameField.autocorrectionType = UITextAutocorrectionTypeNo;
        if ([_firstNameField respondsToSelector:@selector(setSpellCheckingType:)])
            _firstNameField.spellCheckingType = UITextSpellCheckingTypeNo;
        [self addSubview:_firstNameField];
        
        _lastNameField = [[TGTextField alloc] init];
        _lastNameField.placeholder = TGLocalized(@"UserInfo.LastNamePlaceholder");
        _lastNameField.placeholderFont = TGSystemFontOfSize(17.0f);
        _lastNameField.placeholderColor = UIColorRGB(0xc7c7cd);
        [_lastNameField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        _lastNameField.textColor = [UIColor blackColor];
        _lastNameField.font = TGSystemFontOfSize(17.0f);
        _lastNameField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        if (TGIsRTL())
            _lastNameField.textAlignment = NSTextAlignmentRight;
        else if (iosMajorVersion() >= 7)
            _lastNameField.textAlignment = NSTextAlignmentNatural;
        _lastNameField.alpha = 0.0f;
        _lastNameField.hidden = true;
        _lastNameField.autocorrectionType = UITextAutocorrectionTypeNo;
        if ([_lastNameField respondsToSelector:@selector(setSpellCheckingType:)])
            _lastNameField.spellCheckingType = UITextSpellCheckingTypeNo;
        [self addSubview:_lastNameField];
        
        _editingFirstNameSeparator = [[UIView alloc] init];
        _editingFirstNameSeparator.backgroundColor = TGSeparatorColor();
        _editingFirstNameSeparator.hidden = true;
        _editingFirstNameSeparator.alpha = 0.0f;
        [self addSubview:_editingFirstNameSeparator];
        
        _editingLastNameSeparator = [[UIView alloc] init];
        _editingLastNameSeparator.backgroundColor = TGSeparatorColor();
        _editingLastNameSeparator.hidden = true;
        _editingLastNameSeparator.alpha = 0.0f;
        //[self addSubview:_editingLastNameSeparator];
        
        _callButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        _callButton.adjustsImageWhenHighlighted = false;
        _callButton.exclusiveTouch = true;
        _callButton.hidden = true;
        [_callButton addTarget:self action:@selector(callButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_callButton];

        _brandedBackgroundView = [[UIImageView alloc] initWithImage:[TGPresentation brandedIOS6ResourceImage:@"metal1"]];
        _brandedBackgroundView.contentMode = UIViewContentModeScaleToFill;
        _brandedBackgroundView.clipsToBounds = true;
        _brandedBackgroundView.layer.cornerRadius = 10.0f;
        _brandedBackgroundView.hidden = true;
        [self.contentView insertSubview:_brandedBackgroundView atIndex:0];

        _brandedAvatarReflectionView = [[UIImageView alloc] init];
        _brandedAvatarReflectionView.contentMode = UIViewContentModeScaleAspectFill;
        _brandedAvatarReflectionView.clipsToBounds = true;
        _brandedAvatarReflectionView.layer.cornerRadius = 10.0f;
        _brandedAvatarReflectionView.hidden = true;
        CAGradientLayer *reflectionMask = [CAGradientLayer layer];
        reflectionMask.colors = @[(id)UIColorRGBA(0xffffff, 0.0f).CGColor, (id)UIColorRGBA(0xffffff, 0.82f).CGColor];
        reflectionMask.locations = @[@0.0f, @1.0f];
        _brandedAvatarReflectionView.layer.mask = reflectionMask;
        [self.contentView insertSubview:_brandedAvatarReflectionView aboveSubview:_brandedBackgroundView];

        _aboutTitleLabel = [[UILabel alloc] init];
        _aboutTitleLabel.backgroundColor = [UIColor clearColor];
        _aboutTitleLabel.text = [TGLocalized(@"Channel.Edit.AboutItem") stringByAppendingString:@":"];
        _aboutTitleLabel.font = TGSystemFontOfSize(12.0f);
        _aboutTitleLabel.textColor = UIColorRGB(0x5a5a5a);
        _aboutTitleLabel.hidden = true;
        [self addSubview:_aboutTitleLabel];

        _aboutLabel = [[UILabel alloc] init];
        _aboutLabel.backgroundColor = [UIColor clearColor];
        _aboutLabel.font = TGSystemFontOfSize(10.0f);
        _aboutLabel.textColor = UIColorRGB(0x696969);
        _aboutLabel.numberOfLines = 2;
        _aboutLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _aboutLabel.hidden = true;
        [self addSubview:_aboutLabel];
    }
    return self;
}

- (void)dealloc
{
    _firstNameField.delegate = nil;
    [_firstNameField removeTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    _lastNameField.delegate = nil;
    [_lastNameField removeTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    
    bool classicIOS6Style = [TGPresentation classicIOS6Style];
    bool classicDarkStyle = classicIOS6Style && presentation.pallete.isDark;
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    [_avatarView setSingleFontSize:brandedIOS6Style ? 34.0f : 28.0f doubleFontSize:brandedIOS6Style ? 34.0f : 28.0f useBoldFont:false];
    _brandedBackgroundView.hidden = !brandedIOS6Style;
    _brandedAvatarReflectionView.hidden = !brandedIOS6Style;
    _brandedAvatarReflectionView.alpha = brandedIOS6Style ? 0.45f : 1.0f;
    _brandedBackgroundView.image = brandedIOS6Style ? TGBrandedIOS6LightMetalImage() : nil;
    _brandedBackgroundView.alpha = 1.0f;
    _brandedBackgroundView.layer.borderWidth = brandedIOS6Style ? TGScreenPixel : 0.0f;
    _brandedBackgroundView.layer.borderColor = brandedIOS6Style ? UIColorRGB(0x9d9d9d).CGColor : nil;
    self.backgroundView.hidden = brandedIOS6Style;
    self.selectedBackgroundView.hidden = brandedIOS6Style;
    _aboutTitleLabel.hidden = !brandedIOS6Style || _about.length == 0;
    _aboutLabel.hidden = !brandedIOS6Style || _about.length == 0;
    _callButton.hidden = !_showCall || brandedIOS6Style;
    _nameLabel.font = brandedIOS6Style ? TGBoldSystemFontOfSize(18.0f) : TGMediumSystemFontOfSize(20.0f);
    _statusLabel.font = TGSystemFontOfSize(brandedIOS6Style ? 11.0f : 15.0f);
    _nameLabel.textColor = classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x111111) : presentation.pallete.collectionMenuTextColor;
    _phoneLabel.textColor = classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor;
    _usernameLabel.textColor = classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor;
    _verifiedIcon.image = presentation.images.profileVerifiedIcon;
    _premiumIcon.image = [TGPresentationAssets premiumBadgeIcon:16.0f];
    UIImage *disclosureImage = classicIOS6Style ? [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"] : presentation.images.collectionMenuDisclosureIcon;
    if (classicDarkStyle)
        disclosureImage = [TGPresentation classicIOS6ThemedImage:disclosureImage tintColor:presentation.pallete.collectionMenuAccessoryColor alpha:0.82f];
    _disclosureIndicator.image = disclosureImage;
    
    _firstNameField.textColor = presentation.pallete.collectionMenuTextColor;
    _firstNameField.placeholderColor = presentation.pallete.collectionMenuPlaceholderColor;
    _lastNameField.textColor = presentation.pallete.collectionMenuTextColor;
    _lastNameField.placeholderColor = presentation.pallete.collectionMenuPlaceholderColor;
    
    _firstNameField.keyboardAppearance = presentation.pallete.isDark ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
    _lastNameField.keyboardAppearance = presentation.pallete.isDark ? UIKeyboardAppearanceAlert : UIKeyboardAppearanceDefault;
    
    _editingFirstNameSeparator.backgroundColor = presentation.pallete.collectionMenuSeparatorColor;
    _editingLastNameSeparator.backgroundColor = presentation.pallete.collectionMenuSeparatorColor;
    
    [_callButton setImage:presentation.images.profileCallIcon forState:UIControlStateNormal];

    _profileMusicButton.backgroundColor = brandedIOS6Style ? [UIColor clearColor] : [presentation.pallete.accentColor colorWithAlphaComponent:presentation.pallete.isDark ? 0.18f : 0.10f];
    _profileMusicIconLabel.textColor = presentation.pallete.accentColor;
    _profileMusicTextLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _profileMusicArrowView.image = disclosureImage;
    _profileMusicSeparatorView.backgroundColor = brandedIOS6Style ? UIColorRGBA(0x6f6f6f, 0.28f) : [UIColor clearColor];
    _profileMusicSeparatorView.hidden = !brandedIOS6Style;
}

static UIImage *TGBrandedIOS6ProfilePlayImage(void)
{
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize size = CGSizeMake(19.0f, 19.0f);
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGRect circleRect = CGRectMake(0.5f, 0.5f, 18.0f, 18.0f);
        CGContextSaveGState(context);
        CGContextAddEllipseInRect(context, circleRect);
        CGContextClip(context);
        CGFloat locations[] = {0.0f, 1.0f};
        CGFloat components[] = {0.50f, 0.50f, 0.50f, 1.0f, 0.20f, 0.20f, 0.20f, 1.0f};
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, 19.0f), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        CGContextRestoreGState(context);
        CGContextSetStrokeColorWithColor(context, UIColorRGBA(0x000000, 0.55f).CGColor);
        CGContextSetLineWidth(context, 1.0f);
        CGContextStrokeEllipseInRect(context, circleRect);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 7.0f, 5.5f);
        CGContextAddLineToPoint(context, 13.5f, 9.5f);
        CGContextAddLineToPoint(context, 7.0f, 13.5f);
        CGContextClosePath(context);
        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillPath(context);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

static NSString *TGIOS6ProfileMusicTitle(TGDocumentMediaAttachment *document)
{
    if (document == nil)
        return nil;

    NSString *title = nil;
    NSString *performer = nil;
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
        {
            TGDocumentAttributeAudio *audio = (TGDocumentAttributeAudio *)attribute;
            title = audio.title;
            performer = audio.performer;
            break;
        }
    }

    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    performer = [performer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (performer.length != 0 && title.length != 0)
        return [NSString stringWithFormat:@"%@ — %@", performer, title];
    if (title.length != 0)
        return title;
    if (performer.length != 0)
        return performer;
    if (document.fileName.length != 0)
        return document.fileName;
    return TGLocalized(@"Profile.Music");
}

- (void)profileMusicPressed
{
    if (_profileMusicDocument != nil)
        [_itemHandle requestAction:@"profileMusicTapped" options:_profileMusicDocument];
}

- (void)setProfileMusicDocument:(TGDocumentMediaAttachment *)document
{
    if (_profileMusicDocument == document || (_profileMusicDocument.documentId != 0 && _profileMusicDocument.documentId == document.documentId))
        return;

    _profileMusicDocument = document;
    if (_profileMusicDocument == nil)
    {
        [_profileMusicButton removeFromSuperview];
        _profileMusicButton = nil;
        _profileMusicIconLabel = nil;
        _profileMusicTextLabel = nil;
        _profileMusicArrowView = nil;
        _profileMusicSeparatorView = nil;
        [self setNeedsLayout];
        return;
    }

    if (_profileMusicButton == nil)
    {
        _profileMusicButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
        _profileMusicButton.adjustsImageWhenHighlighted = false;
        _profileMusicButton.exclusiveTouch = true;
        _profileMusicButton.layer.cornerRadius = 8.0f;
        _profileMusicButton.clipsToBounds = true;
        [_profileMusicButton addTarget:self action:@selector(profileMusicPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_profileMusicButton];

        _profileMusicSeparatorView = [[UIView alloc] initWithFrame:CGRectZero];
        _profileMusicSeparatorView.userInteractionEnabled = false;
        [_profileMusicButton addSubview:_profileMusicSeparatorView];

        _profileMusicIconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _profileMusicIconLabel.backgroundColor = [UIColor clearColor];
        _profileMusicIconLabel.font = TGBoldSystemFontOfSize(18.0f);
        _profileMusicIconLabel.textAlignment = NSTextAlignmentCenter;
        _profileMusicIconLabel.text = @"♫";
        _profileMusicIconLabel.userInteractionEnabled = false;
        [_profileMusicButton addSubview:_profileMusicIconLabel];

        TGMarqueeLabel *profileMusicTextLabel = [[TGMarqueeLabel alloc] initWithFrame:CGRectZero];
        profileMusicTextLabel.scrollDuration = 12.0f;
        profileMusicTextLabel.animationDelay = 1.2f;
        profileMusicTextLabel.fadeLength = 0.0f;
        profileMusicTextLabel.leadingBuffer = 0.0f;
        profileMusicTextLabel.trailingBuffer = 28.0f;
        _profileMusicTextLabel = profileMusicTextLabel;
        _profileMusicTextLabel.backgroundColor = [UIColor clearColor];
        _profileMusicTextLabel.font = TGMediumSystemFontOfSize(14.0f);
        _profileMusicTextLabel.numberOfLines = 1;
        _profileMusicTextLabel.lineBreakMode = NSLineBreakByClipping;
        _profileMusicTextLabel.userInteractionEnabled = false;
        [_profileMusicButton addSubview:_profileMusicTextLabel];

        _profileMusicArrowView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _profileMusicArrowView.userInteractionEnabled = false;
        [_profileMusicButton addSubview:_profileMusicArrowView];
    }

    _profileMusicTextLabel.text = TGIOS6ProfileMusicTitle(_profileMusicDocument);
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    _profileMusicButton.backgroundColor = brandedIOS6Style ? [UIColor clearColor] : [self.presentation.pallete.accentColor colorWithAlphaComponent:self.presentation.pallete.isDark ? 0.18f : 0.10f];
    _profileMusicButton.layer.cornerRadius = brandedIOS6Style ? 0.0f : 8.0f;
    _profileMusicButton.layer.borderWidth = 0.0f;
    _profileMusicButton.layer.borderColor = nil;
    _profileMusicButton.layer.mask = nil;
    _profileMusicSeparatorView.backgroundColor = brandedIOS6Style ? UIColorRGBA(0x6f6f6f, 0.28f) : [UIColor clearColor];
    _profileMusicSeparatorView.hidden = !brandedIOS6Style;
    _profileMusicIconLabel.textColor = brandedIOS6Style ? UIColorRGB(0x7c7c7c) : self.presentation.pallete.accentColor;
    _profileMusicTextLabel.textColor = self.presentation.pallete.collectionMenuTextColor;
    _profileMusicTextLabel.font = brandedIOS6Style ? TGSystemFontOfSize(16.2f) : TGMediumSystemFontOfSize(14.0f);
    if (brandedIOS6Style)
        _profileMusicTextLabel.textColor = [UIColor blackColor];
    _profileMusicArrowView.image = brandedIOS6Style ? [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"] : self.presentation.images.collectionMenuDisclosureIcon;
    [self setNeedsLayout];
}

- (void)setBrandedDetailsTextScale:(CGFloat)scale
{
    _brandedDetailsTextScale = scale > FLT_EPSILON ? scale : 1.0f;
    [self setNeedsLayout];
}

- (void)setMultilineName:(bool)multilineName
{
    _multilineName = multilineName;
    _nameLabel.numberOfLines = multilineName ? 2 : 1;
    [self setNeedsLayout];
}

- (void)setAvatarHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        _avatarView.alpha = hidden ? 0.0f : 1.0f;
        [UIView animateWithDuration:0.2 animations:^
        {
            _avatarOverlay.alpha = hidden ? 0.0f : 1.0f;;
            _avatarIconView.alpha = hidden ? 0.0f : 1.0f;;
        }];
    }
    else
    {
        CGFloat alpha = hidden ? 0.0f : 1.0f;
        _avatarView.alpha = alpha;
        _avatarOverlay.alpha = alpha;
        _avatarIconView.alpha = alpha;
    }
}

- (id)avatarView
{
    return _avatarView;
}

- (void)callButtonPressed
{
    [_itemHandle requestAction:@"callTapped" options:nil];
}

- (void)makeNameFieldFirstResponder
{
    [_firstNameField becomeFirstResponder];
}

- (void)setShowDisclosureIndicator:(bool)show
{
    if (_disclosureIndicator == nil && show)
    {
        _disclosureIndicator = [[UIImageView alloc] initWithImage:self.presentation.images.collectionMenuDisclosureIcon];
        [self addSubview:_disclosureIndicator];
    }
    else if (!show)
    {
        [_disclosureIndicator removeFromSuperview];
        _disclosureIndicator = nil;
    }
}

- (void)setFirstName:(NSString *)firstName lastName:(NSString *)lastName uidForPlaceholderCalculation:(int32_t)uidForPlaceholderCalculation
{
    _uidForPlaceholderCalculation = uidForPlaceholderCalculation;
    [self updateMarkedUserBadge];
    
    _firstName = firstName;
    _lastName = lastName;
    
    NSString *nameText = nil;
    NSString *displayFirstName = firstName;
    NSString *displayLastName = lastName;
    if (TGIsKorean())
    {
        displayFirstName = lastName;
        displayLastName = firstName;
    }
    
    NSString *prefix = self.customProperties[@"prefix"];
    NSString *middleName = self.customProperties[@"middleName"];
    NSString *suffix = self.customProperties[@"suffix"];
    
    NSMutableArray *nameComponents = [[NSMutableArray alloc] init];
    if (prefix != nil)
        [nameComponents addObject:prefix];
    if (displayFirstName != nil)
        [nameComponents addObject:displayFirstName];
    if (middleName != nil)
        [nameComponents addObject:middleName];
    if (displayLastName != nil)
        [nameComponents addObject:displayLastName];
    if (suffix != nil)
        [nameComponents addObject:suffix];
    
    nameText = [nameComponents componentsJoinedByString:@" "];
    
    if (!TGStringCompare(nameText, _nameLabel.text))
    {
        _nameLabel.text = nameText;
        
        if (_avatarPlaceholderDisabled)
            [_avatarView setFirstName:nil lastName:nil];
        else
            [_avatarView setFirstName:firstName lastName:lastName];
        
        [self setNeedsLayout];
    }
    
    if (!_editing)
    {
        if (!TGStringCompare(firstName, _firstNameField.text))
        {
            _firstNameField.text = firstName;
            [self setNeedsLayout];
        }
        
        if (!TGStringCompare(lastName, _lastNameField.text))
        {
            _lastNameField.text = lastName;
            [self setNeedsLayout];
        }
    }
}

- (void)setDisableAvatarPlaceholder:(bool)disable
{
    _avatarPlaceholderDisabled = disable;
    
    if (disable)
        [_avatarView setFirstName:nil lastName:nil];
}

- (void)setShowCameraIcon:(bool)show
{
    _showCameraIcon = show;
    if (show)
    {
        [self avatarOverlay].hidden = !show;
        [self avatarIconView].hidden = !show;
    }
    else
    {
        _avatarOverlay.hidden = !show;
        _avatarIconView.hidden = !show;
    }
}

- (void)setEditing:(bool)editing animated:(bool)animated
{
    if (_editing != editing)
    {
        _editing = editing;
        
        _verifiedIcon.hidden = _editing;
        _emojiStatusView.hidden = _editing || _emojiStatusDocumentId == 0;
        _premiumIcon.hidden = _editing || !_isPremium || _isVerified || _emojiStatusDocumentId != 0;
        [self updateMarkedUserBadge];
        
        if (editing)
        {
            _firstNameField.hidden = false;
            _lastNameField.hidden = false;
            _editingFirstNameSeparator.hidden = false;
            _editingLastNameSeparator.hidden = false;
            _callButton.userInteractionEnabled = false;
            
            if (animated)
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _nameLabel.alpha = 0.0f;
                    _statusLabel.alpha = 0.0f;
                    _callButton.alpha = 0.0f;
                    
                    _firstNameField.alpha = 1.0f;
                    _lastNameField.alpha = 1.0f;
                    _editingFirstNameSeparator.alpha = 1.0f;
                    _editingLastNameSeparator.alpha = 1.0f;
                }];
            }
            else
            {
                _nameLabel.alpha = 0.0f;
                _statusLabel.alpha = 0.0f;
                _callButton.alpha = 0.0f;
                
                _firstNameField.alpha = 1.0f;
                _lastNameField.alpha = 1.0f;
                _editingFirstNameSeparator.alpha = 1.0f;
                _editingLastNameSeparator.alpha = 1.0f;
            }
        }
        else
        {
            [self endEditing:true];
            
            _callButton.userInteractionEnabled = true;
            
            if (animated)
            {
                [UIView animateWithDuration:0.3 animations:^
                {
                    _nameLabel.alpha = 1.0f;
                    _statusLabel.alpha = 1.0f;
                    _callButton.alpha = 1.0f;
                    
                    _firstNameField.alpha = 0.0f;
                    _lastNameField.alpha = 0.0f;
                    _editingFirstNameSeparator.alpha = 0.0f;
                    _editingLastNameSeparator.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        _firstNameField.hidden = true;
                        _lastNameField.hidden = true;
                        _editingFirstNameSeparator.hidden = true;
                        _editingLastNameSeparator.hidden = true;
                    }
                }];
            }
            else
            {
                _nameLabel.alpha = 1.0f;
                _statusLabel.alpha = 1.0f;
                _callButton.alpha = 1.0f;
                
                _firstNameField.alpha = 0.0f;
                _lastNameField.alpha = 0.0f;
                _editingFirstNameSeparator.alpha = 0.0f;
                _editingLastNameSeparator.alpha = 0.0f;
                
                _firstNameField.hidden = true;
                _lastNameField.hidden = true;
                _editingFirstNameSeparator.hidden = true;
                _editingLastNameSeparator.hidden = true;
            }
        }
        
        if (_avatarPlaceholderDisabled)
            [_avatarView setFirstName:nil lastName:nil];
        else
            [_avatarView setFirstName:_editing ? _firstNameField.text : _firstName lastName:_editing ? _lastNameField.text : _lastName];
    }
}

- (void)setStatus:(NSString *)status active:(bool)active
{
    if (!TGStringCompare(status, _statusLabel.text))
    {
        _statusLabel.text = status;
        if ([TGPresentation brandedIOS6Style])
            _statusLabel.textColor = active ? UIColorRGB(0x9b9b9b) : UIColorRGB(0xafafaf);
        else
            _statusLabel.textColor = active ? self.presentation.pallete.accentColor : self.presentation.pallete.collectionMenuVariantColor;
        [self setNeedsLayout];
    }
}

- (void)setAvatarUri:(NSString *)avatarUri animated:(bool)animated synchronous:(bool)synchronous
{
    CGFloat avatarDiameter = [TGPresentation brandedIOS6Style] ? 68.0f : 64.0f;
    UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:avatarDiameter];

    UIImage *currentPlaceholder = [_avatarView currentImage];
    if (currentPlaceholder == nil)
        currentPlaceholder = placeholder;
    
    if (avatarUri.length == 0)
    {
        int uid = _avatarPlaceholderDisabled ? 0 : _uidForPlaceholderCalculation;
        NSString *firstName = _avatarPlaceholderDisabled ? nil : _firstName;
        NSString *lastName = _avatarPlaceholderDisabled ? nil : _lastName;
        [_avatarView loadUserPlaceholderWithSize:CGSizeMake(avatarDiameter, avatarDiameter) uid:uid firstName:firstName lastName:lastName placeholder:placeholder];
    }
    else if (!TGStringCompare([_avatarView currentUrl], avatarUri))
    {
        _avatarView.fadeTransitionDuration = animated ? 0.3 : 0.1;
        _avatarView.contentHints = synchronous ? TGRemoteImageContentHintLoadFromDiskSynchronously : 0;
        [_avatarView loadImage:avatarUri filter:[TGPresentation brandedIOS6Style] ? @"scale:68x68" : @"circle:64x64" placeholder:currentPlaceholder forceFade:animated];
    }
}

- (void)setAvatarImage:(UIImage *)avatarImage animated:(bool)__unused animated
{
    [_avatarView loadImage:avatarImage];
}

- (UIView *)avatarOverlay
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
    
    return _avatarOverlay;
}

- (UIImageView *)avatarIconView
{
    if (_avatarIconView == nil)
    {
        _avatarIconView = [[UIImageView alloc] initWithImage:TGImageNamed(@"SettingsCameraIcon")];
        _avatarIconView.center = CGPointMake(CGRectGetMidX(_avatarView.frame), CGRectGetMidY(_avatarView.frame));
        [self insertSubview:_avatarIconView aboveSubview:_avatarOverlay];
    }
    return _avatarIconView;
}

- (void)setUpdatingAvatar:(bool)updatingAvatar animated:(bool)animated
{
    if (updatingAvatar)
    {
        UIView *avatarOverlay = [self avatarOverlay];
        
        if (_activityIndicator == nil)
        {
            _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
            _activityIndicator.userInteractionEnabled = false;
            CGRect activityFrame = _activityIndicator.frame;
            activityFrame.origin = CGPointMake(_avatarView.frame.origin.x + CGFloor((_avatarView.frame.size.width - activityFrame.size.width) / 2.0f), _avatarView.frame.origin.y + CGFloor((_avatarView.frame.size.height - activityFrame.size.height) / 2.0f));
            _activityIndicator.frame = activityFrame;
            [self insertSubview:_activityIndicator aboveSubview:avatarOverlay];
        }
        
        _activityIndicator.hidden = false;
        [_activityIndicator startAnimating];
        
        if (animated)
        {
            avatarOverlay.alpha = 0.0f;
            _activityIndicator.alpha = 0.0f;
            [UIView animateWithDuration:0.3 animations:^
            {
                _avatarIconView.alpha = 0.0f;
                avatarOverlay.alpha = 1.0f;
                _activityIndicator.alpha = 1.0f;
            }];
        }
        else
        {
            _avatarIconView.alpha = 0.0f;
            avatarOverlay.alpha = 1.0f;
            _activityIndicator.alpha = 1.0f;
        }
    }
    else if (_avatarOverlay != nil)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                if (!_showCameraIcon)
                    _avatarOverlay.alpha = 0.0f;
                else
                    [self avatarIconView].alpha = 1.0f;
                _activityIndicator.alpha = 0.0f;
            } completion:^(BOOL finished) {
                if (finished)
                    [_activityIndicator stopAnimating];
            }];
        }
        else
        {
            if (!_showCameraIcon)
                _avatarOverlay.alpha = 0.0f;
            else
                [self avatarIconView].alpha = 1.0f;
            [_activityIndicator stopAnimating];
            _activityIndicator.alpha = 0.0f;
        }
    }
}

- (void)setAvatarOffset:(CGSize)avatarOffset
{
    _avatarOffset = avatarOffset;
    
    [self setNeedsLayout];
}

- (void)setNameOffset:(CGSize)nameOffset
{
    _nameOffset = nameOffset;
    
    [self setNeedsLayout];
}

- (void)setShowCall:(bool)showCall
{
    _showCall = showCall;
    _callButton.hidden = !showCall || [TGPresentation brandedIOS6Style];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect bounds = self.bounds;
    if ([TGPresentation brandedIOS6Style] && !_editing)
    {
        bool hasAbout = _about.length > 0;
        bool hasMusic = _profileMusicButton != nil;
        bool hasPhone = _phoneLabel.text.length > 0;
        bool hasUsername = _usernameLabel.text.length > 0;
        CGFloat cardTop = 14.0f;
        CGFloat cardInnerHeight = hasAbout ? 122.0f : 74.0f;
        CGFloat musicY = cardTop + cardInnerHeight;
        CGFloat cardHeight = cardInnerHeight + (hasMusic ? 39.0f : 0.0f);
        CGFloat cardX = 13.0f + self.safeAreaInset.left;
        CGFloat cardWidth = bounds.size.width - 27.0f - self.safeAreaInset.left - self.safeAreaInset.right;
        CGFloat cardInset = 9.0f;

        _brandedBackgroundView.frame = CGRectMake(cardX, cardTop, cardWidth, cardHeight);
        _brandedBackgroundView.layer.shadowColor = [UIColor blackColor].CGColor;
        _brandedBackgroundView.layer.shadowOpacity = 0.12f;
        _brandedBackgroundView.layer.shadowRadius = 1.5f;
        _brandedBackgroundView.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);

        _avatarView.frame = CGRectMake(cardX + cardInset, cardTop + 6.0f, 68.0f, 68.0f);
        _avatarView.clipsToBounds = true;
        _avatarView.layer.cornerRadius = 10.0f;
        _avatarView.layer.borderWidth = TGScreenPixel;
        _avatarView.layer.borderColor = UIColorRGB(0x9b9b9b).CGColor;

        UIImage *currentAvatarImage = [_avatarView currentImage];
        if (currentAvatarImage != _brandedReflectedAvatarImage)
        {
            _brandedReflectedAvatarImage = currentAvatarImage;
            _brandedAvatarReflectionView.image = currentAvatarImage;
        }
        CGFloat reflectionY = cardTop + 74.0f;
        CGFloat reflectionHeight = MAX(0.0f, musicY - reflectionY);
        _brandedAvatarReflectionView.hidden = currentAvatarImage == nil || reflectionHeight < 1.0f;
        _brandedAvatarReflectionView.frame = CGRectMake(CGRectGetMinX(_avatarView.frame), reflectionY, 68.0f, reflectionHeight);
        _brandedAvatarReflectionView.transform = CGAffineTransformMakeScale(1.0f, -1.0f);
        CAGradientLayer *reflectionMask = (CAGradientLayer *)_brandedAvatarReflectionView.layer.mask;
        reflectionMask.frame = _brandedAvatarReflectionView.bounds;

        CGFloat textX = CGRectGetMaxX(_avatarView.frame) + 8.0f;
        CGFloat textRight = CGRectGetMaxX(_brandedBackgroundView.frame) - 13.0f;
        CGFloat statusWidth = 0.0f;
        CGFloat statusX = 0.0f;
        if (_statusLabel.text.length > 0)
        {
            CGSize statusSize = [_statusLabel.text sizeWithFont:TGSystemFontOfSize(8.0f) constrainedToSize:CGSizeMake(90.0f, 13.0f)];
            statusWidth = MIN(90.0f, MAX(33.0f, ceilf(statusSize.width) + 8.0f));
            statusX = textRight - statusWidth;
        }
        CGFloat textRightForName = statusWidth > FLT_EPSILON ? statusX - 8.0f : textRight;
        CGFloat textWidth = MAX(0.0f, textRightForName - textX);
        CGFloat nameFontSize = 20.0f;
        _nameLabel.font = TGBoldSystemFontOfSize(nameFontSize);
        CGSize fullNameSize = [_nameLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 29.0f)];
        while (fullNameSize.width > textWidth && nameFontSize > 17.0f)
        {
            nameFontSize -= 1.0f;
            _nameLabel.font = TGBoldSystemFontOfSize(nameFontSize);
            fullNameSize = [_nameLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 29.0f)];
        }
        CGFloat nameWidth = MIN(textWidth, ceilf(fullNameSize.width));
        _nameLabel.frame = CGRectMake(textX, cardTop + 4.0f, MAX(textWidth, nameWidth), 24.0f);

        if (_statusLabel.text.length > 0)
        {
            statusX = MIN(statusX, textX + nameWidth + 4.0f);
            _statusLabel.font = TGSystemFontOfSize(8.0f);
            _statusLabel.textAlignment = NSTextAlignmentCenter;
            _statusLabel.textColor = [UIColor whiteColor];
            _statusLabel.backgroundColor = UIColorRGB(0x555555);
            _statusLabel.layer.cornerRadius = 6.5f;
            _statusLabel.clipsToBounds = true;
            _statusLabel.frame = CGRectMake(statusX, cardTop + 12.0f, statusWidth, 13.0f);
        }
        else
        {
            _statusLabel.backgroundColor = [UIColor clearColor];
            _statusLabel.frame = CGRectZero;
        }

        if (_phoneLabel != nil)
        {
            _phoneLabel.hidden = !hasPhone;
            _phoneLabel.font = TGSystemFontOfSize(10.0f);
            _phoneLabel.textColor = UIColorRGB(0x5a5a5a);
            _phoneLabel.frame = hasPhone ? CGRectMake(textX, cardTop + 31.0f, MAX(0.0f, textRight - textX), 14.0f) : CGRectZero;
        }
        if (_usernameLabel != nil)
        {
            _usernameLabel.hidden = !hasUsername;
            _usernameLabel.font = TGSystemFontOfSize(10.0f);
            _usernameLabel.textColor = UIColorRGB(0x447ca4);
            CGFloat usernameY = hasPhone ? cardTop + 46.0f : cardTop + 31.0f;
            _usernameLabel.frame = hasUsername ? CGRectMake(textX, usernameY, MAX(0.0f, textRight - textX), 14.0f) : CGRectZero;
        }

        _aboutTitleLabel.hidden = !hasAbout;
        _aboutLabel.hidden = !hasAbout;
        if (hasAbout)
        {
            _aboutTitleLabel.font = TGSystemFontOfSize(12.0f);
            _aboutLabel.font = TGSystemFontOfSize(10.0f);
            _aboutTitleLabel.frame = CGRectMake(textX, cardTop + 79.0f, MAX(0.0f, textRight - textX), 17.0f);
            _aboutLabel.frame = CGRectMake(textX, cardTop + 96.0f, MAX(0.0f, textRight - textX), 18.0f);
        }

        _callButton.frame = CGRectMake(bounds.size.width - 57.0f - self.safeAreaInset.right, 29.0f, 44.0f, 44.0f);

        if (_profileMusicButton != nil)
        {
            CGFloat musicX = cardX;
            CGFloat musicWidth = cardWidth;
            _profileMusicButton.frame = CGRectMake(musicX, musicY, musicWidth, 39.0f);
            _profileMusicButton.layer.mask = nil;
            _profileMusicButton.layer.shadowOpacity = 0.0f;
            _profileMusicButton.layer.shadowRadius = 0.0f;
            _profileMusicButton.layer.shadowOffset = CGSizeZero;
            _profileMusicArrowView.layer.shadowOpacity = 0.0f;
            _profileMusicArrowView.layer.shadowRadius = 0.0f;
            _profileMusicArrowView.layer.shadowOffset = CGSizeZero;
            _profileMusicSeparatorView.hidden = false;
            _profileMusicSeparatorView.frame = CGRectMake(0.0f, 0.0f, musicWidth, TGScreenPixel);
            _profileMusicIconLabel.hidden = true;
            _profileMusicArrowView.image = TGBrandedIOS6ProfilePlayImage();
            _profileMusicArrowView.frame = CGRectMake(musicWidth - 26.0f, 9.0f, 19.0f, 19.0f);
            _profileMusicTextLabel.font = TGSystemFontOfSize(15.0f);
            _profileMusicTextLabel.frame = CGRectMake(8.0f, 0.0f, MAX(0.0f, musicWidth - 42.0f), 40.0f);
        }

        _avatarOverlay.frame = _avatarView.frame;
        _avatarIconView.center = CGPointMake(CGRectGetMidX(_avatarView.frame), CGRectGetMidY(_avatarView.frame));
        return;
    }
    CGFloat classicInset = [TGPresentation classicIOS6Style] ? 10.0f : 0.0f;
    
    _avatarView.frame = CGRectMake(15.0f + classicInset + _avatarOffset.width + self.safeAreaInset.left, 16.0f + _avatarOffset.height, 66.0f, 66.0f);
    
    _callButton.frame = CGRectMake(self.frame.size.width - 57.0f - classicInset - self.safeAreaInset.right, 25.0f, _callButton.frame.size.width, _callButton.frame.size.height);
    
    _disclosureIndicator.frame = CGRectMake(bounds.size.width - _disclosureIndicator.frame.size.width - 15 - classicInset - self.safeAreaInset.right, CGFloor((bounds.size.height - _disclosureIndicator.frame.size.height) / 2), _disclosureIndicator.frame.size.width, _disclosureIndicator.frame.size.height);
    
    CGFloat maxNameWidth = bounds.size.width - 92 - 14 - classicInset * 2.0f - self.safeAreaInset.left - self.safeAreaInset.right;
    CGFloat maxStatusWidth = bounds.size.width - 92 - 14 - classicInset * 2.0f - self.safeAreaInset.left - self.safeAreaInset.right;
    
    if (_verifiedIcon.superview != nil && !_verifiedIcon.hidden)
        maxNameWidth -= _verifiedIcon.bounds.size.width + 5.0f;
    if (_premiumIcon.superview != nil && !_premiumIcon.hidden)
        maxNameWidth -= _premiumIcon.bounds.size.width + 5.0f;
    if (_emojiStatusView.superview != nil && !_emojiStatusView.hidden)
        maxNameWidth -= _emojiStatusView.bounds.size.width + 5.0f;
    if (_markedUserBadgeView.superview != nil && !_markedUserBadgeView.hidden)
        maxNameWidth -= 67.0f;
    if (!_callButton.hidden) {
        maxNameWidth -= 54.0f;
        maxStatusWidth -= 54.0f;
    }
    
    if (_disclosureIndicator != nil) {
        maxStatusWidth -= 40.0f;
    }
    
    CGSize nameSize = [_nameLabel sizeThatFits:CGSizeMake(maxNameWidth, CGFLOAT_MAX)];
    nameSize.width = MIN(nameSize.width, maxNameWidth);
    if (nameSize.height < FLT_EPSILON)
    {
        NSString *currentText = _nameLabel.text;
        _nameLabel.text = @" ";
        nameSize = [_nameLabel sizeThatFits:CGSizeMake(maxNameWidth, CGFLOAT_MAX)];
        _nameLabel.text = currentText;
    }
    
    CGFloat nameY = (_statusLabel.text.length > 0 || _phoneLabel != nil || _usernameLabel != nil) ? 81.0f : 98.0f;
    
    nameSize.width = MIN(nameSize.width, maxNameWidth);
    CGRect nameLabelFrame = CGRectMake(92 + classicInset + _nameOffset.width + self.safeAreaInset.left, floor((nameY - nameSize.height) / 2.0f) + _nameOffset.height, nameSize.width, nameSize.height);
    _nameLabel.frame = nameLabelFrame;
    
    
    CGSize statusLabelSize = [_statusLabel sizeThatFits:CGSizeMake(maxStatusWidth, 1000)];
    statusLabelSize.width = MIN(statusLabelSize.width, maxStatusWidth);
    CGRect statusLabelFrame = CGRectMake(92 + classicInset + _nameOffset.width + self.safeAreaInset.left, CGRectGetMaxY(nameLabelFrame) + 2.0f, statusLabelSize.width, statusLabelSize.height);
    _statusLabel.frame = statusLabelFrame;
    
    if (_phoneLabel != nil)
    {
        CGSize phoneLabelSize = [_phoneLabel sizeThatFits:CGSizeMake(maxStatusWidth, 1000)];
        phoneLabelSize.width = MIN(phoneLabelSize.width, maxStatusWidth);
        CGRect phoneLabelFrame = CGRectMake(92 + classicInset + _nameOffset.width + self.safeAreaInset.left, 53 + _nameOffset.height, phoneLabelSize.width, phoneLabelSize.height);
        _phoneLabel.frame = phoneLabelFrame;
    }
    
    if (_usernameLabel != nil)
    {
        CGSize usernameLabelSize = [_usernameLabel sizeThatFits:CGSizeMake(maxStatusWidth, 1000)];
        usernameLabelSize.width = MIN(usernameLabelSize.width, maxStatusWidth);
        
        _nameLabel.frame = CGRectOffset(_nameLabel.frame, 0.0f, -11.0f);
        _phoneLabel.frame = CGRectOffset(_phoneLabel.frame, 0.0f, -11.0f);
        
        CGRect usernameLabelFrame = CGRectMake(92 + classicInset + _nameOffset.width + self.safeAreaInset.left, 62 + _nameOffset.height + TGScreenPixel, usernameLabelSize.width, usernameLabelSize.height);
        _usernameLabel.frame = usernameLabelFrame;
        
    }
    
    CGFloat fieldLeftPadding = 100.0f + classicInset + self.safeAreaInset.left;
    
    CGRect firstNameFieldFrame = CGRectMake(fieldLeftPadding + 13.0f, 12 + TGScreenPixel, bounds.size.width - fieldLeftPadding - 14.0f - 13.0f - classicInset - self.safeAreaInset.right, 30);
    _firstNameField.frame = firstNameFieldFrame;
    
    CGRect lastNameFieldFrame = CGRectMake(fieldLeftPadding + 13.0f, 56 + TGScreenPixel, bounds.size.width - fieldLeftPadding - 14.0f - 13.0f - classicInset - self.safeAreaInset.right, 30);
    _lastNameField.frame = lastNameFieldFrame;
    
    CGFloat separatorHeight = TGScreenPixel;
    _editingFirstNameSeparator.frame = CGRectMake(fieldLeftPadding, 49.0f, bounds.size.width - fieldLeftPadding - classicInset - self.safeAreaInset.right, separatorHeight);
    _editingLastNameSeparator.frame = CGRectMake(fieldLeftPadding, 88.0f, bounds.size.width - fieldLeftPadding - classicInset - self.safeAreaInset.right, separatorHeight);
    
    if (_verifiedIcon.superview != nil && !_verifiedIcon.hidden) {
        _verifiedIcon.frame = CGRectOffset(_verifiedIcon.bounds, nameLabelFrame.origin.x + nameLabelFrame.size.width + 4.0f, nameLabelFrame.origin.y + 4.0f + TGScreenPixel);
    }
    if (_premiumIcon.superview != nil && !_premiumIcon.hidden) {
        _premiumIcon.frame = CGRectOffset(_premiumIcon.bounds, nameLabelFrame.origin.x + nameLabelFrame.size.width + 4.0f, nameLabelFrame.origin.y + 3.0f + TGScreenPixel);
    }
    if (_emojiStatusView.superview != nil && !_emojiStatusView.hidden) {
        CGFloat emojiX = nameLabelFrame.origin.x + nameLabelFrame.size.width + 4.0f;
        if (_verifiedIcon.superview != nil && !_verifiedIcon.hidden)
            emojiX = CGRectGetMaxX(_verifiedIcon.frame) + 3.0f;
        _emojiStatusView.frame = CGRectMake(emojiX, nameLabelFrame.origin.y + 2.0f + TGScreenPixel, 20.0f, 20.0f);
    }
    if (_markedUserBadgeView.superview != nil && !_markedUserBadgeView.hidden) {
        CGFloat badgeX = nameLabelFrame.origin.x + nameLabelFrame.size.width + 4.0f;
        if (_verifiedIcon.superview != nil && !_verifiedIcon.hidden)
            badgeX = CGRectGetMaxX(_verifiedIcon.frame) + 3.0f;
        if (_premiumIcon.superview != nil && !_premiumIcon.hidden)
            badgeX = CGRectGetMaxX(_premiumIcon.frame) + 3.0f;
        if (_emojiStatusView.superview != nil && !_emojiStatusView.hidden)
            badgeX = CGRectGetMaxX(_emojiStatusView.frame) + 3.0f;
        _markedUserBadgeView.frame = CGRectMake(badgeX, nameLabelFrame.origin.y + 1.0f, 62.0f, 26.0f);
    }
    
    if (_profileMusicButton != nil)
    {
        CGFloat musicX = 15.0f + classicInset + self.safeAreaInset.left;
        CGFloat musicWidth = bounds.size.width - musicX - 15.0f - classicInset - self.safeAreaInset.right;
        _profileMusicButton.frame = CGRectMake(musicX, 98.0f, musicWidth, 36.0f);
        _profileMusicIconLabel.frame = CGRectMake(8.0f, 0.0f, 28.0f, 36.0f);
        _profileMusicTextLabel.frame = CGRectMake(39.0f, 0.0f, MAX(0.0f, musicWidth - 49.0f), 36.0f);
    }

    _avatarOverlay.frame = _avatarView.frame;
    _avatarIconView.center = CGPointMake(CGRectGetMidX(_avatarView.frame), CGRectGetMidY(_avatarView.frame));
}

- (void)updateMarkedUserBadge
{
    bool shouldShowBadge = _uidForPlaceholderCalculation == TGMarkedUserId && !_editing;
    if (!shouldShowBadge)
    {
        [_markedUserBadgeView removeFromSuperview];
        _markedUserBadgeView = nil;
        [self setNeedsLayout];
        return;
    }

    if (_markedUserBadgeView == nil)
    {
        UIImage *badgeImage = [UIImage imageNamed:@"ZikfolvStatusBadge"];
        if (badgeImage == nil)
            return;

        _markedUserBadgeView = [[UIImageView alloc] initWithImage:badgeImage];
        _markedUserBadgeView.contentMode = UIViewContentModeScaleAspectFit;
        _markedUserBadgeView.userInteractionEnabled = false;
        [self addSubview:_markedUserBadgeView];
    }

    _markedUserBadgeView.hidden = false;
    [self setNeedsLayout];
}

#pragma mark -

- (void)avatarTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_itemHandle requestAction:@"avatarTapped" options:nil];
    }
}

- (void)textFieldDidChange:(UITextField *)textField
{
    if (textField == _firstNameField || textField == _lastNameField)
    {
        if (textField.text.length > 64)
            textField.text = [textField.text substringToIndex:64];
     
        if (_editing)
        {
            NSString *nameText = nil;
            if (_firstNameField.text.length != 0 && _lastNameField.text.length != 0)
                nameText = [[NSString alloc] initWithFormat:@"%@ %@", _firstNameField.text, _lastNameField.text];
            else if (_firstNameField.text != nil)
                nameText = _firstNameField.text;
            else if (_lastNameField.text != nil)
                nameText = _lastNameField.text;
            
            _nameLabel.text = nameText;
            
            if (_editing)
                [_avatarView setFirstName:_firstNameField.text lastName:_lastNameField.text];
            
            [self setNeedsLayout];
            
            [_itemHandle requestAction:@"editingNameChanged" options:@{@"field": textField == _firstNameField ? @"firstName" : @"lastName", @"text": textField.text == nil ? @"" : textField.text}];
        }
    }
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

        if (_premiumIcon != nil)
            _premiumIcon.hidden = _editing || !_isPremium || _isVerified || _emojiStatusDocumentId != 0;
        
        [self setNeedsLayout];
    }
}

- (void)setEmojiStatusDocumentId:(int64_t)emojiStatusDocumentId
{
    if (_emojiStatusDocumentId == emojiStatusDocumentId)
        return;

    _emojiStatusDocumentId = emojiStatusDocumentId;
    if (emojiStatusDocumentId == 0)
    {
        [_emojiStatusView cancelLoading];
        [_emojiStatusView removeFromSuperview];
        _emojiStatusView = nil;
        if (_premiumIcon != nil)
            _premiumIcon.hidden = _editing || !_isPremium || _isVerified;
        [self setNeedsLayout];
        return;
    }

    if (_premiumIcon != nil)
        _premiumIcon.hidden = true;

    if (_emojiStatusView == nil)
    {
        _emojiStatusView = [[TGRemoteImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 20.0f, 20.0f)];
        _emojiStatusView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_emojiStatusView];
    }
    [_emojiStatusView cancelLoading];
    _emojiStatusView.hidden = true;

    __weak TGUserInfoCollectionItemView *weakSelf = self;
    TGIOS6LoadCustomEmojiThumbnail(emojiStatusDocumentId, ^(NSString *thumbnailUri)
    {
        TGUserInfoCollectionItemView *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_emojiStatusDocumentId != emojiStatusDocumentId || thumbnailUri.length == 0)
            return;
        [strongSelf->_emojiStatusView loadImage:thumbnailUri filter:nil placeholder:nil];
        strongSelf->_emojiStatusView.hidden = strongSelf->_editing;
        [strongSelf setNeedsLayout];
    });
}

- (void)setIsPremium:(bool)isPremium
{
    if (_isPremium == isPremium)
        return;

    _isPremium = isPremium;

    bool shouldShow = _isPremium && !_isVerified && _emojiStatusDocumentId == 0 && !_editing;
    if (shouldShow)
    {
        if (_premiumIcon == nil)
        {
            _premiumIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 16.0f, 16.0f)];
            _premiumIcon.image = [TGPresentationAssets premiumBadgeIcon:16.0f];
            _premiumIcon.contentMode = UIViewContentModeScaleAspectFit;
        }
        _premiumIcon.hidden = false;
        if (_premiumIcon.superview == nil)
            [self.contentView addSubview:_premiumIcon];
    }
    else
    {
        _premiumIcon.hidden = true;
    }

    [self setNeedsLayout];
}

- (void)setAbout:(NSString *)about
{
    _about = about;
    _aboutLabel.text = about;
    bool hidden = ![TGPresentation brandedIOS6Style] || about.length == 0;
    _aboutTitleLabel.hidden = hidden;
    _aboutLabel.hidden = hidden;
    [self setNeedsLayout];
}

- (void)setPhoneNumber:(NSString *)phoneNumber
{
    if (_phoneLabel == nil && phoneNumber.length > 0)
    {
        _phoneLabel = [[UILabel alloc] init];
        _phoneLabel.backgroundColor = [UIColor clearColor];
        _phoneLabel.font = TGSystemFontOfSize(15.0f);
        _phoneLabel.textColor = [TGPresentation brandedIOS6Style] ? UIColorRGB(0x707070) : self.presentation.pallete.collectionMenuVariantColor;
        [self addSubview:_phoneLabel];
    }
    
    if (_phoneLabel != nil)
    {
        _phoneLabel.text = phoneNumber;
        _phoneLabel.hidden = phoneNumber.length == 0;
        [self setNeedsLayout];
    }
}

- (void)setUsername:(NSString *)username
{
    if (_usernameLabel == nil && username.length > 0)
    {
        _usernameLabel = [[UILabel alloc] init];
        _usernameLabel.backgroundColor = [UIColor clearColor];
        _usernameLabel.font = TGSystemFontOfSize(15.0f);
        _usernameLabel.textColor = [TGPresentation brandedIOS6Style] ? UIColorRGB(0x447ca4) : self.presentation.pallete.collectionMenuVariantColor;
        [self addSubview:_usernameLabel];
    }
    
    if (_usernameLabel != nil)
    {
        _usernameLabel.text = username;
        _usernameLabel.hidden = username.length == 0;
        [self setNeedsLayout];
    }
}

- (void)copyPhoneNumber:(id)__unused sender
{
    [[UIPasteboard generalPasteboard] setString:_phoneLabel.text];
}

- (void)copyUsername:(id)__unused sender
{
    [[UIPasteboard generalPasteboard] setString:_usernameLabel.text];
}

@end
