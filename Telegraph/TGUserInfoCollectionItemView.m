#import "TGUserInfoCollectionItemView.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGProfileAppearance.h"
#import "../OnegramUI/Profile/OGProfileHeader.h"
#import "../OnegramUI/Lists/OGSettingsCell.h"

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
    UIImageView *_brandedAvatarOverlayView;
    UIImageView *_brandedStatusBackgroundView;
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
        
        _brandedStatusBackgroundView = [[UIImageView alloc] init];
        _brandedStatusBackgroundView.hidden = true;
        [self addSubview:_brandedStatusBackgroundView];

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
        OGPlatformDisableSpellChecking(_firstNameField);
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
        OGPlatformDisableSpellChecking(_lastNameField);
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
        
        _callButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        _callButton.adjustsImageWhenHighlighted = false;
        _callButton.exclusiveTouch = true;
        _callButton.hidden = true;
        [_callButton addTarget:self action:@selector(callButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_callButton];

        OGTheme *brandedTheme = [OGTheme brandedTheme];
        OGProfileAppearance *profileAppearance = brandedTheme.profileAppearance;

        _brandedBackgroundView = [[UIImageView alloc] init];
        _brandedBackgroundView.hidden = true;
        [self.contentView insertSubview:_brandedBackgroundView atIndex:0];

        _brandedAvatarOverlayView = [[UIImageView alloc] init];
        _brandedAvatarOverlayView.hidden = true;
        [self insertSubview:_brandedAvatarOverlayView aboveSubview:_avatarView];

        _brandedAvatarReflectionView = [[UIImageView alloc] init];
        [OGProfileHeader applyLegacyReflectionStyleWithTheme:brandedTheme imageView:_brandedAvatarReflectionView];
        _brandedAvatarReflectionView.hidden = true;
        [self.contentView insertSubview:_brandedAvatarReflectionView aboveSubview:_brandedBackgroundView];

        _aboutTitleLabel = [[UILabel alloc] init];
        _aboutTitleLabel.backgroundColor = [UIColor clearColor];
        _aboutTitleLabel.text = [TGLocalized(@"Channel.Edit.AboutItem") stringByAppendingString:@":"];
        _aboutTitleLabel.font = TGSystemFontOfSize(profileAppearance.aboutTitleFontSize);
        _aboutTitleLabel.textColor = profileAppearance.aboutTitleColor;
        _aboutTitleLabel.hidden = true;
        [self addSubview:_aboutTitleLabel];

        _aboutLabel = [[UILabel alloc] init];
        _aboutLabel.backgroundColor = [UIColor clearColor];
        _aboutLabel.font = TGSystemFontOfSize(profileAppearance.aboutFontSize);
        _aboutLabel.textColor = profileAppearance.aboutColor;
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
    OGTheme *brandedTheme = [OGTheme brandedTheme];
    OGProfileAppearance *profileAppearance = brandedTheme.profileAppearance;

    CGFloat avatarPlaceholderFontSize = brandedIOS6Style ? profileAppearance.avatarPlaceholderFontSize : 28.0f;
    [_avatarView setSingleFontSize:avatarPlaceholderFontSize doubleFontSize:avatarPlaceholderFontSize useBoldFont:false];
    _brandedBackgroundView.hidden = !brandedIOS6Style;
    _brandedAvatarOverlayView.hidden = !brandedIOS6Style;
    _brandedStatusBackgroundView.hidden = !brandedIOS6Style;
    _brandedAvatarReflectionView.hidden = !brandedIOS6Style;
    if (brandedIOS6Style)
    {
        [OGProfileHeader applyLegacyAvatarStyleWithTheme:brandedTheme view:_avatarView];
        [OGProfileHeader applyLegacyReflectionStyleWithTheme:brandedTheme imageView:_brandedAvatarReflectionView];
    }
    self.backgroundView.hidden = brandedIOS6Style;
    self.selectedBackgroundView.hidden = brandedIOS6Style;
    _aboutTitleLabel.hidden = !brandedIOS6Style || _about.length == 0;
    _aboutLabel.hidden = !brandedIOS6Style || _about.length == 0;
    _callButton.hidden = !_showCall || brandedIOS6Style;
    _nameLabel.font = brandedIOS6Style ? [OGProfileHeader legacyNameFontWithTheme:brandedTheme size:profileAppearance.nameMaximumFontSize] : TGMediumSystemFontOfSize(20.0f);
    _nameLabel.shadowColor = brandedIOS6Style ? profileAppearance.nameShadowColor : nil;
    _nameLabel.shadowOffset = brandedIOS6Style ? profileAppearance.nameShadowOffset : CGSizeZero;
    _statusLabel.font = TGSystemFontOfSize(brandedIOS6Style ? profileAppearance.statusFontSize : 15.0f);
    _nameLabel.textColor = brandedIOS6Style ? profileAppearance.nameColor : (classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x111111) : presentation.pallete.collectionMenuTextColor);
    _phoneLabel.textColor = brandedIOS6Style ? profileAppearance.phoneColor : (classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor);
    _usernameLabel.textColor = brandedIOS6Style ? profileAppearance.usernameColor : (classicIOS6Style && !classicDarkStyle ? UIColorRGB(0x7f7f7f) : presentation.pallete.collectionMenuVariantColor);
    _verifiedIcon.image = presentation.images.profileVerifiedIcon;
    _premiumIcon.image = [TGPresentationAssets premiumBadgeIcon:16.0f];
    UIImage *disclosureImage = nil;
    if (brandedIOS6Style)
        disclosureImage = [OGSettingsCell legacyBrandedDisclosureImageWithTheme:brandedTheme];
    else if (classicIOS6Style)
        disclosureImage = [TGPresentation classicIOS6ResourceImage:@"MenuDisclosureIndicator"];
    else
        disclosureImage = presentation.images.collectionMenuDisclosureIcon;
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
    _profileMusicIconLabel.textColor = brandedIOS6Style ? profileAppearance.musicIconColor : presentation.pallete.accentColor;
    _profileMusicTextLabel.textColor = brandedIOS6Style ? profileAppearance.musicTextColor : presentation.pallete.collectionMenuTextColor;
    _profileMusicTextLabel.shadowColor = brandedIOS6Style ? profileAppearance.musicTextShadowColor : nil;
    _profileMusicTextLabel.shadowOffset = brandedIOS6Style ? profileAppearance.musicTextShadowOffset : CGSizeZero;
    _profileMusicArrowView.image = brandedIOS6Style ? [OGProfileHeader legacyMusicPlayImageWithTheme:brandedTheme outsets:NULL] : disclosureImage;
    [self setNeedsLayout];
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
    OGTheme *brandedTheme = [OGTheme brandedTheme];
    OGProfileAppearance *profileAppearance = brandedTheme.profileAppearance;
    _profileMusicButton.backgroundColor = brandedIOS6Style ? [UIColor clearColor] : [self.presentation.pallete.accentColor colorWithAlphaComponent:self.presentation.pallete.isDark ? 0.18f : 0.10f];
    _profileMusicButton.layer.cornerRadius = brandedIOS6Style ? 0.0f : 8.0f;
    _profileMusicButton.layer.borderWidth = 0.0f;
    _profileMusicButton.layer.borderColor = nil;
    _profileMusicButton.layer.mask = nil;
    _profileMusicIconLabel.textColor = brandedIOS6Style ? profileAppearance.musicIconColor : self.presentation.pallete.accentColor;
    _profileMusicTextLabel.textColor = brandedIOS6Style ? profileAppearance.musicTextColor : self.presentation.pallete.collectionMenuTextColor;
    _profileMusicTextLabel.shadowColor = brandedIOS6Style ? profileAppearance.musicTextShadowColor : nil;
    _profileMusicTextLabel.shadowOffset = brandedIOS6Style ? profileAppearance.musicTextShadowOffset : CGSizeZero;
    _profileMusicTextLabel.font = brandedIOS6Style ? TGSystemFontOfSize(profileAppearance.musicFontSize) : TGMediumSystemFontOfSize(14.0f);
    _profileMusicArrowView.image = brandedIOS6Style ? [OGProfileHeader legacyMusicPlayImageWithTheme:brandedTheme outsets:NULL] : self.presentation.images.collectionMenuDisclosureIcon;
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
        _brandedAvatarOverlayView.alpha = hidden ? 0.0f : 1.0f;
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
        _brandedAvatarOverlayView.alpha = alpha;
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
            _statusLabel.textColor = [OGTheme brandedTheme].profileAppearance.statusTextColor;
        else
            _statusLabel.textColor = active ? self.presentation.pallete.accentColor : self.presentation.pallete.collectionMenuVariantColor;
        [self setNeedsLayout];
    }
}

- (void)setAvatarUri:(NSString *)avatarUri animated:(bool)animated synchronous:(bool)synchronous
{
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    CGFloat avatarDiameter = brandedIOS6Style ? [OGTheme brandedTheme].profileAppearance.avatarSize : 64.0f;
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
        NSString *filter = brandedIOS6Style ? [NSString stringWithFormat:@"scale:%.0fx%.0f", avatarDiameter, avatarDiameter] : @"circle:64x64";
        [_avatarView loadImage:avatarUri filter:filter placeholder:currentPlaceholder forceFade:animated];
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
        OGTheme *theme = [OGTheme brandedTheme];
        OGProfileAppearance *appearance = theme.profileAppearance;
        bool hasAbout = _about.length > 0;
        bool hasMusic = _profileMusicButton != nil;
        bool hasPhone = _phoneLabel.text.length > 0;
        bool hasUsername = _usernameLabel.text.length > 0;
        CGFloat cardTop = appearance.cardTop;
        CGFloat cardInnerHeight = hasAbout ? appearance.cardInnerHeightWithAbout : appearance.cardInnerHeight;
        CGFloat musicY = cardTop + cardInnerHeight;
        CGFloat cardHeight = cardInnerHeight + (hasMusic ? appearance.musicHeight : 0.0f);
        CGFloat cardX = appearance.cardLeft + self.safeAreaInset.left;
        CGFloat cardWidth = bounds.size.width - appearance.cardLeft - appearance.cardRight - self.safeAreaInset.left - self.safeAreaInset.right;

        UIEdgeInsets cardOutsets = UIEdgeInsetsZero;
        _brandedBackgroundView.image = [OGProfileHeader legacyCardImageWithTheme:theme size:CGSizeMake(cardWidth, cardHeight) hasMusic:hasMusic outsets:&cardOutsets];
        _brandedBackgroundView.frame = CGRectMake(cardX - cardOutsets.left, cardTop - cardOutsets.top, cardWidth + cardOutsets.left + cardOutsets.right, cardHeight + cardOutsets.top + cardOutsets.bottom);

        _avatarView.frame = CGRectMake(cardX + appearance.avatarInset, cardTop + appearance.avatarTop, appearance.avatarSize, appearance.avatarSize);
        UIEdgeInsets avatarOutsets = UIEdgeInsetsZero;
        _brandedAvatarOverlayView.hidden = false;
        _brandedAvatarOverlayView.image = [OGProfileHeader legacyAvatarOverlayImageWithTheme:theme size:_avatarView.frame.size outsets:&avatarOutsets];
        _brandedAvatarOverlayView.frame = CGRectMake(CGRectGetMinX(_avatarView.frame) - avatarOutsets.left, CGRectGetMinY(_avatarView.frame) - avatarOutsets.top, _avatarView.frame.size.width + avatarOutsets.left + avatarOutsets.right, _avatarView.frame.size.height + avatarOutsets.top + avatarOutsets.bottom);

        UIImage *currentAvatarImage = [_avatarView currentImage];
        if (currentAvatarImage != _brandedReflectedAvatarImage)
        {
            _brandedReflectedAvatarImage = currentAvatarImage;
            _brandedAvatarReflectionView.image = currentAvatarImage;
        }
        CGFloat reflectionY = cardTop + appearance.reflectionTop;
        CGFloat reflectionFadeHeight = appearance.reflectionMaskLength * appearance.avatarSize;
        _brandedAvatarReflectionView.hidden = currentAvatarImage == nil || musicY - reflectionY < reflectionFadeHeight;
        _brandedAvatarReflectionView.transform = CGAffineTransformIdentity;
        _brandedAvatarReflectionView.frame = CGRectMake(CGRectGetMinX(_avatarView.frame), reflectionY, appearance.avatarSize, appearance.avatarSize);
        _brandedAvatarReflectionView.transform = CGAffineTransformMakeScale(1.0f, -1.0f);
        CAGradientLayer *reflectionMask = (CAGradientLayer *)_brandedAvatarReflectionView.layer.mask;
        reflectionMask.frame = _brandedAvatarReflectionView.bounds;

        CGFloat textX = CGRectGetMaxX(_avatarView.frame) + appearance.textGap;
        CGFloat textRight = cardX + cardWidth - appearance.textRightInset;
        CGFloat statusWidth = 0.0f;
        CGFloat statusX = 0.0f;
        if (_statusLabel.text.length > 0)
        {
            CGSize statusSize = [_statusLabel.text sizeWithFont:TGSystemFontOfSize(appearance.statusFontSize) constrainedToSize:CGSizeMake(appearance.statusMaximumWidth, appearance.statusHeight)];
            statusWidth = MIN(appearance.statusMaximumWidth, MAX(appearance.statusMinimumWidth, ceilf(statusSize.width) + appearance.statusHorizontalPadding));
            statusX = cardX + cardWidth - appearance.statusRightInset - statusWidth;
        }
        CGFloat textRightForName = statusWidth > FLT_EPSILON ? statusX - appearance.statusNameGap : textRight;
        CGFloat textWidth = MAX(0.0f, textRightForName - textX);
        CGFloat nameFontSize = appearance.nameMaximumFontSize;
        _nameLabel.font = [OGProfileHeader legacyNameFontWithTheme:theme size:nameFontSize];
        CGSize fullNameSize = [_nameLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, appearance.nameMeasureHeight)];
        while (fullNameSize.width > textWidth && nameFontSize > appearance.nameMinimumFontSize)
        {
            nameFontSize -= 1.0f;
            _nameLabel.font = [OGProfileHeader legacyNameFontWithTheme:theme size:nameFontSize];
            fullNameSize = [_nameLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, appearance.nameMeasureHeight)];
        }
        _nameLabel.textColor = appearance.nameColor;
        _nameLabel.shadowColor = appearance.nameShadowColor;
        _nameLabel.shadowOffset = appearance.nameShadowOffset;
        _nameLabel.frame = CGRectMake(textX, cardTop + appearance.nameTop, textWidth, appearance.nameFrameHeight);

        if (_statusLabel.text.length > 0)
        {
            CGRect statusFrame = CGRectMake(statusX, cardTop + appearance.statusTop, statusWidth, appearance.statusHeight);
            UIEdgeInsets statusOutsets = UIEdgeInsetsZero;
            _brandedStatusBackgroundView.hidden = false;
            _brandedStatusBackgroundView.image = [OGProfileHeader legacyStatusBackgroundImageWithTheme:theme size:statusFrame.size outsets:&statusOutsets];
            _brandedStatusBackgroundView.frame = CGRectMake(statusFrame.origin.x - statusOutsets.left, statusFrame.origin.y - statusOutsets.top, statusFrame.size.width + statusOutsets.left + statusOutsets.right, statusFrame.size.height + statusOutsets.top + statusOutsets.bottom);
            _statusLabel.font = TGSystemFontOfSize(appearance.statusFontSize);
            _statusLabel.textAlignment = NSTextAlignmentCenter;
            _statusLabel.textColor = appearance.statusTextColor;
            _statusLabel.shadowColor = appearance.statusTextShadowColor;
            _statusLabel.shadowOffset = appearance.statusTextShadowOffset;
            _statusLabel.backgroundColor = [UIColor clearColor];
            _statusLabel.layer.cornerRadius = 0.0f;
            _statusLabel.clipsToBounds = false;
            _statusLabel.frame = CGRectMake(statusFrame.origin.x, statusFrame.origin.y + appearance.statusTextTop, statusFrame.size.width, appearance.statusTextHeight);
        }
        else
        {
            _brandedStatusBackgroundView.hidden = true;
            _statusLabel.backgroundColor = [UIColor clearColor];
            _statusLabel.frame = CGRectZero;
        }

        if (_phoneLabel != nil)
        {
            _phoneLabel.hidden = !hasPhone;
            _phoneLabel.font = TGSystemFontOfSize(appearance.phoneFontSize);
            _phoneLabel.textColor = appearance.phoneColor;
            _phoneLabel.frame = hasPhone ? CGRectMake(textX, cardTop + appearance.phoneTop, MAX(0.0f, textRight - textX), appearance.secondaryLineHeight) : CGRectZero;
        }
        if (_usernameLabel != nil)
        {
            _usernameLabel.hidden = !hasUsername;
            _usernameLabel.font = TGSystemFontOfSize(appearance.usernameFontSize);
            _usernameLabel.textColor = appearance.usernameColor;
            CGFloat usernameY = cardTop + (hasPhone ? appearance.usernameTopWithPhone : appearance.usernameTop);
            _usernameLabel.frame = hasUsername ? CGRectMake(textX, usernameY, MAX(0.0f, textRight - textX), appearance.secondaryLineHeight) : CGRectZero;
        }

        _aboutTitleLabel.hidden = !hasAbout;
        _aboutLabel.hidden = !hasAbout;
        if (hasAbout)
        {
            _aboutTitleLabel.font = TGSystemFontOfSize(appearance.aboutTitleFontSize);
            _aboutTitleLabel.textColor = appearance.aboutTitleColor;
            _aboutLabel.font = TGSystemFontOfSize(appearance.aboutFontSize);
            _aboutLabel.textColor = appearance.aboutColor;
            _aboutTitleLabel.frame = CGRectMake(textX, cardTop + appearance.aboutTitleTop, MAX(0.0f, textRight - textX), appearance.aboutTitleHeight);
            _aboutLabel.frame = CGRectMake(textX, cardTop + appearance.aboutTop, MAX(0.0f, textRight - textX), appearance.aboutHeight);
        }

        _callButton.frame = CGRectMake(bounds.size.width - 57.0f - self.safeAreaInset.right, 29.0f, 44.0f, 44.0f);

        if (_profileMusicButton != nil)
        {
            CGFloat musicX = cardX;
            CGFloat musicWidth = cardWidth;
            _profileMusicButton.frame = CGRectMake(musicX, musicY, musicWidth, appearance.musicHeight);
            _profileMusicButton.layer.mask = nil;
            OGPlatformApplyViewShadow(_profileMusicButton, nil, 0.0f, 0.0f, CGSizeZero);
            OGPlatformApplyViewShadow(_profileMusicArrowView, nil, 0.0f, 0.0f, CGSizeZero);
            _profileMusicIconLabel.hidden = true;
            UIEdgeInsets playOutsets = UIEdgeInsetsZero;
            _profileMusicArrowView.image = [OGProfileHeader legacyMusicPlayImageWithTheme:theme outsets:&playOutsets];
            _profileMusicArrowView.frame = CGRectMake(musicWidth - appearance.musicArrowRight - appearance.musicArrowSize - playOutsets.left, appearance.musicArrowTop - playOutsets.top, appearance.musicArrowSize + playOutsets.left + playOutsets.right, appearance.musicArrowSize + playOutsets.top + playOutsets.bottom);
            _profileMusicTextLabel.font = TGSystemFontOfSize(appearance.musicFontSize);
            _profileMusicTextLabel.textColor = appearance.musicTextColor;
            _profileMusicTextLabel.shadowColor = appearance.musicTextShadowColor;
            _profileMusicTextLabel.shadowOffset = appearance.musicTextShadowOffset;
            _profileMusicTextLabel.frame = CGRectMake(appearance.musicTextLeft, appearance.musicTextTop, MAX(0.0f, musicWidth - appearance.musicTextLeft - appearance.musicTextRight), appearance.musicTextHeight);
        }

        _avatarOverlay.frame = _avatarView.frame;
        _avatarIconView.center = CGPointMake(CGRectGetMidX(_avatarView.frame), CGRectGetMidY(_avatarView.frame));
        return;
    }
    _brandedAvatarOverlayView.hidden = true;
    _brandedStatusBackgroundView.hidden = true;
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
        bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
        OGProfileAppearance *appearance = [OGTheme brandedTheme].profileAppearance;
        _phoneLabel.font = TGSystemFontOfSize(brandedIOS6Style ? appearance.phoneFontSize : 15.0f);
        _phoneLabel.textColor = brandedIOS6Style ? appearance.phoneColor : self.presentation.pallete.collectionMenuVariantColor;
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
        bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
        OGProfileAppearance *appearance = [OGTheme brandedTheme].profileAppearance;
        _usernameLabel.font = TGSystemFontOfSize(brandedIOS6Style ? appearance.usernameFontSize : 15.0f);
        _usernameLabel.textColor = brandedIOS6Style ? appearance.usernameColor : self.presentation.pallete.collectionMenuVariantColor;
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
