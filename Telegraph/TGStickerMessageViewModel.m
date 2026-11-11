#import "TGOnegramSettings.h"
#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGStickerMessageViewModel.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"


#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGMessageImageViewModel.h"
#import "TGAnimatedStickerViewModel.h"
#import "TGAnimatedStickerView.h"

#import "TGModernConversationItem.h"

#import "TGTelegraphConversationMessageAssetsSource.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"

#import "TGModernViewContext.h"

#import "TGMessageImageView.h"

#import "TGModernImageViewModel.h"
#import "TGModernButtonViewModel.h"
#import "TGModernButtonView.h"

#import "TGContentBubbleViewModel.h"

#import "TGReplyHeaderModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernImageViewModel.h"

#import "TGMessageReplyButtonsModel.h"

#import "TGModernTextViewModel.h"

#import "TGPresentation.h"
#import "TGMessageReactionsLayout.h"
#import "TGPresentationAssets.h"

#import "TGAppDelegate.h"

static void TGBrandedIOS6UpdateStickerDeliveryPlate(TGModernImageViewModel *model, NSString *timeText, bool incomingAppearance, TGMessageDeliveryState deliveryState, bool read)
{
    if (model == nil)
        return;

    bool hidden = !incomingAppearance && deliveryState != TGMessageDeliveryStateDelivered;
    model.hidden = hidden;
    if (hidden)
        return;

    UIImage *image = [TGPresentationAssets brandedIOS6FlatDeliveryTagImage:timeText incoming:incomingAppearance read:read];
    model.image = image;
    CGRect frame = model.frame;
    frame.size = image.size;
    model.frame = frame;
    UIImageView *view = (UIImageView *)[model boundView];
    if (view != nil)
        view.image = image;
}

@interface TGStickerMessageViewModel () <TGDoubleTapGestureRecognizerDelegate, UIGestureRecognizerDelegate, TGMessageImageViewDelegate>
{
    bool _incoming;
    bool _read;
    TGMessageDeliveryState _deliveryState;
    bool _hasAvatar;
    CGSize _size;
    bool _savedMessage;
    
    float _progress;
    bool _progressVisible;
    bool _mediaIsAvailable;
    
    TGDocumentMediaAttachment *_document;
    TGMessageImageViewModel *_imageModel;
    TGAnimatedStickerViewModel *_animatedStickerModel;
    NSString *_placeholderEmoji;
    UILabel *_placeholderLabel;
    bool _placeholderEmojiTransient;
    
    UITapGestureRecognizer *_tapGestureRecognizer;
    TGDoubleTapGestureRecognizer *_boundDoubleTapRecognizer;
    UITapGestureRecognizer *_replyTapRecognizer;
    
    TGModernImageViewModel *_brandedDeliveryPlateModel;
    TGModernImageViewModel *_unsentButtonModel;
    UITapGestureRecognizer *_unsentButtonTapRecognizer;
    
    UIImageView *_temporaryHighlightView;
    
    TGModernFlatteningViewModel *_contentModel;
    TGModernImageViewModel *_replyBackgroundModel;
    TGReplyHeaderModel *_replyHeaderModel;
    TGModernTextViewModel *_replyHeaderViaUserModel;
    
    TGModernButtonViewModel *_actionButtonModel;
    
    int32_t _replyMessageId;
    TGMessageViewCountContentProperty *_messageViews;
    
    TGMessage *_message;
    NSString *_authorSignature;
    
    TGMessageReplyButtonsModel *_replyButtonsModel;
    TGBotReplyMarkup *_replyMarkup;
    SMetaDisposable *_callbackButtonInProgressDisposable;
    
    TGUser *_viaUser;

    TGMessageReactionsModel *_reactionsModel;
}

@end

@implementation TGStickerMessageViewModel

- (NSString *)emojiForStickerDocument:(TGDocumentMediaAttachment *)document
{
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
            return ((TGDocumentAttributeSticker *)attribute).alt;
    }
    
    return nil;
}

- (bool)documentUsesPosterUri:(TGDocumentMediaAttachment *)document
{
    NSArray *posterMimeTypes = @[@"video/webm", @"application/x-tgsticker"];
    NSArray *posterExtensions = @[@"webm", @"tgs"];
    return [posterMimeTypes containsObject:[document.mimeType lowercaseString]] || [posterExtensions containsObject:[[document.fileName pathExtension] lowercaseString]];
}

- (bool)keepsPlaceholderForDocument:(TGDocumentMediaAttachment *)document
{
    return false;
}

- (NSString *)currentStickerImageUriForDisplaySize:(CGSize)displaySize
{
    bool previewOnly = [self documentUsesPosterUri:_document];

    NSMutableString *imageUri = [[NSMutableString alloc] init];
    [imageUri appendString:previewOnly ? @"sticker-preview://?" : @"sticker://?"];
    if (_document.documentId != 0)
    {
        [imageUri appendFormat:@"&documentId=%" PRId64, _document.documentId];
        
        TGMediaOriginInfo *originInfo = _document.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:_document];
        if (originInfo != nil)
            [imageUri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
    }
    else
    {
        [imageUri appendFormat:@"&localDocumentId=%" PRId64, _document.localDocumentId];
    }
    [imageUri appendFormat:@"&accessHash=%" PRId64, _document.accessHash];
    [imageUri appendFormat:@"&datacenterId=%d", (int)_document.datacenterId];
    if (previewOnly)
    {
        NSString *thumbnailUri = [_document.thumbnailInfo imageUrlForLargestSize:NULL];
        if (thumbnailUri.length != 0)
            [imageUri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:thumbnailUri]];
        [imageUri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:[_document safeFileName]]];
        [imageUri appendFormat:@"&size=%d", (int)_document.size];
        if (_document.mimeType.length != 0)
            [imageUri appendFormat:@"&mimeType=%@", [TGStringUtils stringByEscapingForURL:_document.mimeType]];
        [imageUri appendFormat:@"&width=%d&height=%d&highQuality=1", (int)displaySize.width, (int)displaySize.height];
    }
    else
    {
        [imageUri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:_document.fileName]];
        [imageUri appendFormat:@"&size=%d", (int)_document.size];
        [imageUri appendFormat:@"&width=%d&height=%d", (int)displaySize.width, (int)displaySize.height];
        [imageUri appendFormat:@"&mime-type=%@", [TGStringUtils stringByEscapingForURL:_document.mimeType]];
        if (_document.documentUri.length != 0) {
            [imageUri appendFormat:@"&documentUri=%@", [TGStringUtils stringByEscapingForURL:_document.documentUri]];
        }
    }
    if (OGPlatformMediaDownloadsRequireUserAction())
        [imageUri appendString:@"&cacheOnly=1"];
    return imageUri;
}

static NSString *OGStickerFilesRootPath()
{
    static NSString *rootPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        rootPath = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });
    return rootPath;
}

- (bool)stickerFilesExistForDocument:(TGDocumentMediaAttachment *)document
{
    NSString *folderName = nil;
    if (document.documentId != 0)
        folderName = [NSString stringWithFormat:@"%" PRIx64, document.documentId];
    else if (document.localDocumentId != 0)
        folderName = [NSString stringWithFormat:@"local%" PRIx64, document.localDocumentId];
    if (folderName.length == 0)
        return false;
    
    NSString *folderPath = [OGStickerFilesRootPath() stringByAppendingPathComponent:folderName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *name in @[document.fileName ?: @"", @"cached.bin", @"thumbnail.cached.bin"])
    {
        if ([fileManager fileExistsAtPath:[folderPath stringByAppendingPathComponent:name]])
            return true;
    }
    return false;
}

- (bool)boundImageIsPresent
{
    UIView *boundView = [_imageModel boundView];
    return [boundView isKindOfClass:[TGMessageImageViewContainer class]] && ((TGMessageImageViewContainer *)boundView).imageView.currentImage != nil;
}

- (void)refreshPlaceholderEmoji
{
    NSString *emoji = [self emojiForStickerDocument:_document];
    bool visible = false;
    bool transient = false;
    if (emoji.length != 0)
    {
        if (_animatedStickerModel != nil)
        {
            visible = OGPlatformMediaDownloadsRequireUserAction() && ![[NSFileManager defaultManager] fileExistsAtPath:[TGAnimatedStickerView filePathForDocument:_document]];
            transient = true;
        }
        else
        {
            bool permanent = [self keepsPlaceholderForDocument:_document];
            visible = permanent || ![self stickerFilesExistForDocument:_document];
            transient = !permanent;
        }
    }
    _placeholderEmoji = visible ? emoji : nil;
    _placeholderEmojiTransient = visible && transient;
    [self layoutPlaceholderLabel];
}

- (void)dismissPlaceholderEmoji
{
    _placeholderEmojiTransient = false;
    _placeholderEmoji = nil;
    [self layoutPlaceholderLabel];
}

- (UILabel *)makePlaceholderLabelInBounds:(CGRect)bounds
{
    UILabel *label = [[UILabel alloc] initWithFrame:bounds];
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = false;
    label.adjustsFontSizeToFitWidth = true;
    if ([label respondsToSelector:@selector(setMinimumScaleFactor:)])
        OGPlatformSetLabelMinimumScaleFactor(label, 0.5f);
    else
        label.minimumFontSize = label.font.pointSize * 0.5f;
    label.shadowColor = UIColorRGBA(0xffffff, 0.65f);
    label.shadowOffset = CGSizeMake(0.0f, 1.0f);
    return label;
}

- (void)layoutPlaceholderLabel
{
    UIView *containerView = [_imageModel boundView];
    if (_placeholderEmojiTransient && [self boundImageIsPresent])
    {
        _placeholderEmojiTransient = false;
        _placeholderEmoji = nil;
    }
    
    if (_placeholderEmoji.length == 0 || containerView == nil)
    {
        [_placeholderLabel removeFromSuperview];
        _placeholderLabel = nil;
        return;
    }
    
    if (_placeholderLabel == nil)
        _placeholderLabel = [self makePlaceholderLabelInBounds:containerView.bounds];
    
    _placeholderLabel.font = TGEmojiFontOfSize(68.0f);
    _placeholderLabel.text = _placeholderEmoji;
    _placeholderLabel.frame = containerView.bounds;
    
    if (_placeholderLabel.superview != containerView)
    {
        [_placeholderLabel removeFromSuperview];
        [containerView addSubview:_placeholderLabel];
    }
    [containerView bringSubviewToFront:_placeholderLabel];
}

- (CGSize)displaySizeForSize:(CGSize)size
{
    CGFloat scale = _context.stickerScale > FLT_EPSILON ? _context.stickerScale : (CGFloat)[TGOnegramSettings integerForKey:TGOnegramSettingMessagesStickerScale] / 100.0f;
    CGSize maxSize = CGSizeMake(CGFloor(160.0f * scale), CGFloor(170.0f * scale));
    return TGFitSize(CGSizeMake(size.width / 2.0f * scale, size.height / 2.0f * scale), maxSize);
}

- (instancetype)initWithMessage:(TGMessage *)message document:(TGDocumentMediaAttachment *)document size:(CGSize)size authorPeer:(id)authorPeer context:(TGModernViewContext *)context replyHeader:(TGMessage *)replyHeader replyPeer:(id)replyPeer viaUser:(TGUser *)viaUser
{
    self = [super initWithAuthorPeer:authorPeer context:context];
    if (self != nil)
    {
        _callbackButtonInProgressDisposable = [[SMetaDisposable alloc] init];
        
        _mid = message.mid;
        _authorPeerId = message.fromUid;
        _incoming = !message.outgoing;
        _read = ![_context isMessageUnread:message];
        _deliveryState = message.deliveryState;
        _hasAvatar = authorPeer != nil && [authorPeer isKindOfClass:[TGUser class]];
        if ([authorPeer isKindOfClass:[TGConversation class]]) {
            TGConversation *conversationAuthor = (TGConversation *)authorPeer;
            if (TGMessageViewModelShouldDisplayConversationAvatar(conversationAuthor, context)) {
                _hasAvatar = true;
            }
        }
        _messageViews = message.viewCount;
        _message = message;
        
        _needsEditingCheckButton = true;
        
        _document = document;
        
        _size = size;
        
        TGForwardedMessageMediaAttachment *forwardAttachment = nil;
        for (TGMediaAttachment *attachment in message.mediaAttachments)
        {
            if (attachment.type == TGForwardedMessageMediaAttachmentType)
            {
                forwardAttachment = (TGForwardedMessageMediaAttachment *)attachment;
                break;
            }
        }
        _savedMessage = forwardAttachment != nil && context.isSavedMessages && forwardAttachment.forwardSourcePeerId != message.cid;
        bool hasForwardPostId = forwardAttachment.forwardPostId != 0 || forwardAttachment.forwardMid != 0;
        
        _incomingAppearance = _incoming || [authorPeer isKindOfClass:[TGConversation class]] || _savedMessage;
        
        _imageModel = [[TGMessageImageViewModel alloc] init];
        [_imageModel setPresentation:_context.presentation];
        _imageModel.expectExtendedEdges = true;
        
        UIColor *overlayBackgroundColor = context.presentation.pallete.chatSystemBackgroundColor ?: [[TGTelegraphConversationMessageAssetsSource instance] systemMessageBackgroundColor];
        _imageModel.overlayBackgroundColorHint = UIColorRGBA(0x000000, 0.4f);
        _imageModel.timestampTextColor = context.presentation.pallete.chatSystemTextColor;
        _imageModel.timestampColor = overlayBackgroundColor;
        _imageModel.serviceTimestampStyle = true;
        
        CGSize displaySize = [self displaySizeForSize:_size];
        
        NSString *imageUri = [self currentStickerImageUriForDisplaySize:displaySize];
        bool animatedSticker = [TGAnimatedStickerView isAnimatedStickerDocument:_document];
        
        if (animatedSticker)
        {
            _animatedStickerModel = [[TGAnimatedStickerViewModel alloc] initWithDocument:_document placeholderUri:imageUri];
            _animatedStickerModel.frame = CGRectMake(0.0f, 0.0f, displaySize.width, displaySize.height);
            [self addSubmodel:_animatedStickerModel];
            [self updateAnimationPlayback];
            TGMessageViewModelReference *animationLifetimeReference = [self lifetimeReference];
            _animatedStickerModel.readyBlock = ^
            {
                [animationLifetimeReference withValue:^(void *value)
                {
                    __strong TGStickerMessageViewModel *strongSelf = (__bridge TGStickerMessageViewModel *)value;
                    if (strongSelf != nil && strongSelf->_placeholderEmoji != nil)
                        [strongSelf dismissPlaceholderEmoji];
                }];
            };
        }
        else
            [_imageModel setUri:imageUri];
        [self refreshPlaceholderEmoji];
        
        _imageModel.frame = CGRectMake(0.0f, 0.0f, displaySize.width, displaySize.height);
        _imageModel.skipDrawInContext = true;
        [self addSubmodel:_imageModel];

        if ([TGPresentation brandedIOS6Style])
        {
            UIImage *deliveryPlateImage = [TGPresentationAssets brandedIOS6FlatDeliveryTagImage:[TGDateUtils stringForShortTime:(int)message.date] incoming:_incomingAppearance read:(_read || _context.isSavedMessages)];
            _brandedDeliveryPlateModel = [[TGModernImageViewModel alloc] initWithImage:deliveryPlateImage];
            _brandedDeliveryPlateModel.hidden = !_incomingAppearance && _deliveryState != TGMessageDeliveryStateDelivered;
            [_brandedDeliveryPlateModel sizeToFit];
            [self addSubmodel:_brandedDeliveryPlateModel];
        }
        
        _imageModel.flexibleTimestamp = true;
        _imageModel.timestampHidden = [TGPresentation brandedIOS6Style] || [TGOnegramSettings boolForKey:TGOnegramSettingMessagesHideStickerTime];
        [_imageModel setTimestampString:([TGPresentation brandedIOS6Style] ? nil : [TGDateUtils stringForShortTime:(int)message.date]) signatureString:nil displayCheckmarks:![TGPresentation brandedIOS6Style] && !_incoming && !(_incomingAppearance && _context.isSavedMessages) && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:![TGPresentation brandedIOS6Style] && _messageViews != nil viewsValue:_messageViews.viewCount animated:false];
        [_imageModel setDisplayTimestampProgress:![TGPresentation brandedIOS6Style] && _deliveryState == TGMessageDeliveryStatePending];
        [_imageModel setIsBroadcast:message.isBroadcast];
        
        TGMessageViewModelReference *messageLifetimeReference2 = [self lifetimeReference];
        _imageModel.completionBlock = ^(__unused TGImageView *imageView)
        {
            [messageLifetimeReference2 withValue:^(void *value)
            {
                __strong TGStickerMessageViewModel *strongSelf = (__bridge TGStickerMessageViewModel *)value;
                if (strongSelf != nil)
                {
                    if (strongSelf->_progressVisible)
                        [strongSelf updateProgressInternal:false progress:1.0f animated:true];

                    if (strongSelf->_placeholderEmojiTransient && (!OGPlatformMediaDownloadsRequireUserAction() || [strongSelf stickerFilesExistForDocument:strongSelf->_document]))
                        [strongSelf dismissPlaceholderEmoji];
                }
            }];
        };
        
        if (!_incoming)
        {
            if (_deliveryState == TGMessageDeliveryStatePending)
            {
            }
            else if (_deliveryState == TGMessageDeliveryStateFailed)
            {
                [self addSubmodel:[self unsentButtonModel]];
            }
            else if (_deliveryState == TGMessageDeliveryStateDelivered)
            {
            }
        }
        
        _viaUser = viaUser;
        
        if (replyHeader != nil)
        {
            _replyMessageId = replyHeader.mid;
            
            _replyBackgroundModel = [[TGModernImageViewModel alloc] initWithImage:context.presentation.images.chatReplyBackground];
            _replyBackgroundModel.skipDrawInContext = true;
            [self addSubmodel:_replyBackgroundModel];
            
            _contentModel = [[TGModernFlatteningViewModel alloc] init];
            [self addSubmodel:_contentModel];
            
            _replyHeaderModel = [TGContentBubbleViewModel replyHeaderModelFromMessage:replyHeader peer:replyPeer incoming:_incomingAppearance system:true presentation:context.presentation];
            [_contentModel addSubmodel:_replyHeaderModel];
            
            if (viaUser != nil && viaUser.userName.length != 0) {
                NSString *formatString = TGLocalized(@"Conversation.MessageViaUser");
                NSString *viaUserName = [@"@" stringByAppendingString:viaUser.userName];
                NSRange range = [formatString rangeOfString:@"%@"];
                
                _replyHeaderViaUserModel = [[TGModernTextViewModel alloc] initWithText:[[NSString alloc] initWithFormat:formatString, viaUserName] font:[[TGTelegraphConversationMessageAssetsSource instance] messageAuthorNameFont]];
                if (range.location != NSNotFound) {
                    _replyHeaderViaUserModel.textCheckingResults = @[[[TGTextCheckingResult alloc] initWithRange:NSMakeRange(range.location, viaUserName.length) type:TGTextCheckingResultTypeBold contents:nil]];
                }
                _replyHeaderViaUserModel.textColor = [UIColor whiteColor];
                [_contentModel addSubmodel:_replyHeaderViaUserModel];
                
                _viaUser = viaUser;
            }
        } else if (viaUser != nil && viaUser.userName.length != 0) {
            _replyBackgroundModel = [[TGModernImageViewModel alloc] initWithImage:[[TGTelegraphConversationMessageAssetsSource instance] systemReplyBackground]];
            _replyBackgroundModel.skipDrawInContext = true;
            [self addSubmodel:_replyBackgroundModel];
            
            _contentModel = [[TGModernFlatteningViewModel alloc] init];
            [self addSubmodel:_contentModel];
            
            NSString *formatString = TGLocalized(@"Conversation.MessageViaUser");
            NSString *viaUserName = [@"@" stringByAppendingString:viaUser.userName];
            NSRange range = [formatString rangeOfString:@"%@"];
            
            _replyHeaderViaUserModel = [[TGModernTextViewModel alloc] initWithText:[[NSString alloc] initWithFormat:formatString, viaUserName] font:[[TGTelegraphConversationMessageAssetsSource instance] messageAuthorNameFont]];
            if (range.location != NSNotFound) {
                _replyHeaderViaUserModel.textCheckingResults = @[[[TGTextCheckingResult alloc] initWithRange:NSMakeRange(range.location, viaUserName.length) type:TGTextCheckingResultTypeBold contents:nil]];
            }
            _replyHeaderViaUserModel.textColor = [UIColor whiteColor];
            [_contentModel addSubmodel:_replyHeaderViaUserModel];
            
            _viaUser = viaUser;
        }
        
        if (_incomingAppearance && _savedMessage && hasForwardPostId) {
            _actionButtonModel = [[TGModernButtonViewModel alloc] init];
            _actionButtonModel.image = [[TGTelegraphConversationMessageAssetsSource instance] systemGoToButton];
            _actionButtonModel.modernHighlight = true;
            _actionButtonModel.frame = CGRectMake(0.0f, 0.0f, 29.0f, 29.0f);
            [self addSubmodel:_actionButtonModel];
        }
        
        TGBotReplyMarkup *replyMarkup = message.replyMarkup;
        if (replyMarkup != nil && replyMarkup.isInline) {
            _replyMarkup = replyMarkup;
            _replyButtonsModel = [[TGMessageReplyButtonsModel alloc] initWithContext:context];
            TGMessageViewModelReference *messageLifetimeReference3 = [self lifetimeReference];
            _replyButtonsModel.buttonActivated = ^(TGBotReplyMarkupButton *button, NSInteger index) {
                [messageLifetimeReference3 withValue:^(void *value)
                {
                    __strong TGStickerMessageViewModel *strongSelf = (__bridge TGStickerMessageViewModel *)value;
                    if (strongSelf != nil) {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{@"mid": @(strongSelf->_mid), @"command": button.text}];
                        if (button.action != nil) {
                            dict[@"action"] = button.action;
                        }
                        dict[@"index"] = @(index);
                        [strongSelf->_context.companionHandle requestAction:@"activateCommand" options:dict];
                    }
                }];
            };
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:false];
            [self addSubmodel:_replyButtonsModel];
        }

        _reactionsModel = [[TGMessageReactionsModel alloc] initWithContext:context style:TGMessageReactionsStyleService];
        [_reactionsModel updateWithMessage:message parent:self viewStorage:nil container:nil];
    }
    return self;
}

- (void)dealloc {
    ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView.delegate = nil;
    [self invalidateLifetimeReference];
    [_callbackButtonInProgressDisposable dispose];
}

- (void)setAuthorSignature:(NSString *)authorSignature {
    _authorSignature = authorSignature;
    [_imageModel setTimestampString:([TGPresentation brandedIOS6Style] ? nil : [TGDateUtils stringForShortTime:(int)_message.date]) signatureString:([TGPresentation brandedIOS6Style] ? nil : authorSignature) displayCheckmarks:![TGPresentation brandedIOS6Style] && !_incoming && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:![TGPresentation brandedIOS6Style] && _messageViews != nil viewsValue:_messageViews.viewCount animated:false];
}

- (void)updateAssets
{
    [super updateAssets];
    
}

- (TGModernImageViewModel *)unsentButtonModel
{
    if (_unsentButtonModel == nil)
    {
        UIImage *image = _context.presentation.images.chatUnsentIcon;
        _unsentButtonModel = [[TGModernImageViewModel alloc] initWithImage:image];
        _unsentButtonModel.frame = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
        _unsentButtonModel.extendedEdges = UIEdgeInsetsMake(6, 6, 6, 6);
    }
    
    return _unsentButtonModel;
}

- (void)updateProgressInternal:(bool)progressVisible progress:(float)progress animated:(bool)animated
{
    bool progressWasVisible = _progressVisible;
    float previousProgress = _progress;
    
    _progress = progress;
    _progressVisible = progressVisible;
    
    [self updateImageOverlay:((progressWasVisible && !_progressVisible) || (_progressVisible && ABS(_progress - previousProgress) > FLT_EPSILON)) && animated];
}

- (void)updateImageOverlay:(bool)animated
{
    if (_progressVisible)
    {
        [_imageModel setOverlayType:OGPlatformMediaDownloadsRequireUserAction() ? TGMessageImageViewOverlayProgress : TGMessageImageViewOverlayProgressNoCancel animated:false];
        [_imageModel setProgress:_progress animated:animated];
    }
    else if (OGPlatformMediaDownloadsRequireUserAction() && !_mediaIsAvailable)
    {
        [_imageModel setOverlayType:TGMessageImageViewOverlayDownload animated:false];
    }
    else
    {
        [_imageModel setOverlayType:TGMessageImageViewOverlayNone animated:animated];
    }
}

- (void)updateMediaAvailability:(bool)mediaIsAvailable viewStorage:(TGModernViewStorage *)viewStorage delayDisplay:(bool)delayDisplay
{
    [super updateMediaAvailability:mediaIsAvailable viewStorage:viewStorage delayDisplay:delayDisplay];
    bool becameAvailable = mediaIsAvailable && !_mediaIsAvailable;
    _mediaIsAvailable = mediaIsAvailable;
    if (OGPlatformMediaDownloadsRequireUserAction())
    {
        if (becameAvailable)
            [_imageModel reloadImage:false];
        [self updateImageOverlay:false];
    }
}

- (void)updateProgress:(bool)progressVisible progress:(float)progress viewStorage:(TGModernViewStorage *)viewStorage animated:(bool)animated
{
    [super updateProgress:progressVisible progress:progress viewStorage:viewStorage animated:animated];
    if (OGPlatformMediaDownloadsRequireUserAction())
        [self updateProgressInternal:progressVisible progress:progress animated:animated];
}

- (void)updateMessageAttributes
{
    [super updateMessageAttributes];
    
    bool previousRead = _read;
    _read = ![_context isMessageUnread:_message];
    if (previousRead != _read) {
        TGBrandedIOS6UpdateStickerDeliveryPlate(_brandedDeliveryPlateModel, [TGDateUtils stringForShortTime:(int)_message.date], _incomingAppearance, _deliveryState, _read || _context.isSavedMessages);
        [_imageModel setTimestampString:([TGPresentation brandedIOS6Style] ? nil : [TGDateUtils stringForShortTime:(int)_message.date]) signatureString:([TGPresentation brandedIOS6Style] ? nil : _authorSignature) displayCheckmarks:![TGPresentation brandedIOS6Style] && !_incoming && !(_incomingAppearance && _context.isSavedMessages) && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:![TGPresentation brandedIOS6Style] && _messageViews != nil viewsValue:_messageViews.viewCount animated:true];
        [_imageModel setDisplayTimestampProgress:![TGPresentation brandedIOS6Style] && _deliveryState == TGMessageDeliveryStatePending];
    }
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];

    if ([_reactionsModel updateWithMessage:message parent:self viewStorage:viewStorage container:[_imageModel boundView].superview])
    {
        if (sizeUpdated != NULL)
            *sizeUpdated = true;
    }
    
    _mid = message.mid;
    _message = message;
    
    bool messageUnread = [_context isMessageUnread:message];
    
    if (_deliveryState != message.deliveryState || (!_incoming && _read != !messageUnread) || (_messageViews != nil && _messageViews.viewCount != message.viewCount.viewCount))
    {
        _messageViews = message.viewCount;
        _deliveryState = message.deliveryState;
        _read = !messageUnread;
        TGBrandedIOS6UpdateStickerDeliveryPlate(_brandedDeliveryPlateModel, [TGDateUtils stringForShortTime:(int)message.date], _incomingAppearance, _deliveryState, _read || _context.isSavedMessages);
        
        [_imageModel setTimestampString:([TGPresentation brandedIOS6Style] ? nil : [TGDateUtils stringForShortTime:(int)message.date]) signatureString:([TGPresentation brandedIOS6Style] ? nil : _authorSignature) displayCheckmarks:![TGPresentation brandedIOS6Style] && !_incoming && !(_incomingAppearance && _context.isSavedMessages) && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:![TGPresentation brandedIOS6Style] && _messageViews != nil viewsValue:_messageViews.viewCount animated:true];
        [_imageModel setDisplayTimestampProgress:![TGPresentation brandedIOS6Style] && _deliveryState == TGMessageDeliveryStatePending];
        
        if (_deliveryState == TGMessageDeliveryStateDelivered)
        {
            if (_unsentButtonModel != nil)
            {
                [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                _unsentButtonModel = nil;
            }
        }
        else if (_deliveryState == TGMessageDeliveryStateFailed)
        {
            if (_unsentButtonModel == nil)
            {
                [self addSubmodel:[self unsentButtonModel]];
                if ([_imageModel boundView] != nil)
                    [_unsentButtonModel bindViewToContainer:[_imageModel boundView].superview viewStorage:viewStorage];
                _unsentButtonModel.frame = CGRectOffset(_unsentButtonModel.frame, self.frame.size.width + _unsentButtonModel.frame.size.width, self.frame.size.height - _unsentButtonModel.frame.size.height - ((_collapseFlags & TGModernConversationItemCollapseBottom) ? 5 : 6));
                
                _unsentButtonTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unsentButtonTapGesture:)];
                [[_unsentButtonModel boundView] addGestureRecognizer:_unsentButtonTapRecognizer];
            }
            
            if (self.frame.size.width > FLT_EPSILON)
            {
                if ([_imageModel boundView] != nil)
                {
                    [UIView animateWithDuration:0.2 animations:^
                    {
                        [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                    }];
                }
                else
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
            }
        }
        else if (_deliveryState == TGMessageDeliveryStatePending)
        {
            if (_unsentButtonModel != nil)
            {
                UIView<TGModernView> *unsentView = [_unsentButtonModel boundView];
                if (unsentView != nil)
                {
                    [unsentView removeGestureRecognizer:_unsentButtonTapRecognizer];
                    _unsentButtonTapRecognizer = nil;
                }
                
                if (unsentView != nil)
                {
                    [viewStorage allowResurrectionForOperations:^
                    {
                        [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                        
                        UIView *restoredView = [viewStorage dequeueViewWithIdentifier:[unsentView viewIdentifier] viewStateIdentifier:[unsentView viewStateIdentifier]];
                        
                        if (restoredView != nil)
                        {
                            [[_imageModel boundView].superview addSubview:restoredView];
                            
                            [UIView animateWithDuration:0.2 animations:^
                            {
                                restoredView.frame = CGRectOffset(restoredView.frame, restoredView.frame.size.width + 9, 0.0f);
                                restoredView.alpha = 0.0f;
                            } completion:^(__unused BOOL finished)
                            {
                                [viewStorage enqueueView:restoredView];
                            }];
                        }
                    }];
                }
                else
                    [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                
                _unsentButtonModel = nil;
            }
            
            if (self.frame.size.width > FLT_EPSILON)
            {
                if ([_imageModel boundView] != nil)
                {
                    [UIView animateWithDuration:0.2 animations:^
                    {
                        [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                    }];
                }
                else
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
            }
        }
    }
    
    for (id attachment in message.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]])
        {
            _document = attachment;
        }
    }
    
    CGSize displaySize = [self displaySizeForSize:_size];
    
    NSString *imageUri = [self currentStickerImageUriForDisplaySize:displaySize];
    
    if (_animatedStickerModel != nil)
        [_animatedStickerModel setDocument:_document placeholderUri:imageUri];
    else
        [_imageModel setUri:imageUri];
    [self refreshPlaceholderEmoji];
    
    TGBotReplyMarkup *replyMarkup = message.replyMarkup != nil && message.replyMarkup.isInline ? message.replyMarkup : nil;
    if (!TGObjectCompare(_replyMarkup, replyMarkup)) {
        _replyMarkup = replyMarkup;
        
        if (_replyButtonsModel == nil) {
            _replyButtonsModel = [[TGMessageReplyButtonsModel alloc] initWithContext:_context];
            TGMessageViewModelReference *messageLifetimeReference4 = [self lifetimeReference];
            _replyButtonsModel.buttonActivated = ^(TGBotReplyMarkupButton *button, NSInteger index) {
                [messageLifetimeReference4 withValue:^(void *value)
                {
                    __strong TGStickerMessageViewModel *strongSelf = (__bridge TGStickerMessageViewModel *)value;
                    if (strongSelf != nil) {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{@"mid": @(strongSelf->_mid), @"command": button.text}];
                        if (button.action != nil) {
                            dict[@"action"] = button.action;
                        }
                        dict[@"index"] = @(index);
                        [strongSelf->_context.companionHandle requestAction:@"activateCommand" options:dict];
                    }
                }];
            };
            
            [self addSubmodel:_replyButtonsModel];
        }
        if (_imageModel.boundView != nil) {
            [_replyButtonsModel unbindView:viewStorage];
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:false];
            [_replyButtonsModel bindViewToContainer:_imageModel.boundView.superview viewStorage:viewStorage];
        } else {
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:false];
        }
        if (sizeUpdated) {
            *sizeUpdated = true;
        }
    }
}

- (CGRect)effectiveContentFrame
{
    return _imageModel.frame;
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    
    if (_animatedStickerModel != nil)
    {
        [_animatedStickerModel bindViewToContainer:container viewStorage:viewStorage];
        [_animatedStickerModel boundView].frame = CGRectOffset([_animatedStickerModel boundView].frame, itemPosition.x, itemPosition.y);
    }
    [_imageModel bindViewToContainer:container viewStorage:viewStorage];
    [_imageModel boundView].frame = CGRectOffset([_imageModel boundView].frame, itemPosition.x, itemPosition.y);
    
    [self layoutPlaceholderLabel];
    [_reactionsModel bringToFrontInContainer:container];

    _replyBackgroundModel.parentOffset = itemPosition;
    [_replyBackgroundModel bindViewToContainer:container viewStorage:viewStorage];
    
    _contentModel.parentOffset = itemPosition;
    [_contentModel bindViewToContainer:container viewStorage:viewStorage];
    
    [_replyHeaderModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x + _contentModel.frame.origin.x + _replyHeaderModel.frame.origin.x, itemPosition.y + _contentModel.frame.origin.y + _replyHeaderModel.frame.origin.y)];
    
    [_replyButtonsModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x, itemPosition.y)];
    
    [self subscribeToCallbackButtonInProgress];
}

- (void)subscribeToCallbackButtonInProgress {
    if (_replyButtonsModel != nil) {
        TGMessageViewModelReference *messageLifetimeReference5 = [self lifetimeReference];
        [_callbackButtonInProgressDisposable setDisposable:[[[_context callbackInProgress] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next) {
            [messageLifetimeReference5 withValue:^(void *value)
            {
                __strong TGStickerMessageViewModel *strongSelf = (__bridge TGStickerMessageViewModel *)value;
                if (strongSelf != nil) {
                    if (next != nil) {
                        if ([next[@"mid"] intValue] == strongSelf->_mid) {
                            [strongSelf->_replyButtonsModel setButtonIndexInProgress:[next[@"buttonIndex"] intValue]];
                        } else {
                            [strongSelf->_replyButtonsModel setButtonIndexInProgress:NSNotFound];
                        }
                    } else {
                        [strongSelf->_replyButtonsModel setButtonIndexInProgress:NSNotFound];
                    }
                }
            }];
        }]];
    }
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [self updateEditingState:nil viewStorage:nil animationDelay:-1.0];
    
    _replyBackgroundModel.parentOffset = CGPointZero;
    _contentModel.parentOffset = CGPointZero;
    
    [super bindViewToContainer:container viewStorage:viewStorage];
    [_reactionsModel bringToFrontInContainer:container];
    
    ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView.delegate = self;

    [_replyHeaderModel bindSpecialViewsToContainer:_contentModel.boundView viewStorage:viewStorage atItemPosition:CGPointMake(_replyHeaderModel.frame.origin.x, _replyHeaderModel.frame.origin.y)];
    
    _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(messageTapGesture:)];
    _tapGestureRecognizer.delegate = self;
    
    _boundDoubleTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(messageDoubleTapGesture:)];
    _boundDoubleTapRecognizer.longPressDuration = [TGOnegramSettings boolForKey:TGOnegramSettingGeneralNewChats] ? 0.5 : 1.5;
    _boundDoubleTapRecognizer.consumeSingleTap = false;
    _boundDoubleTapRecognizer.delegate = self;
    
    if (_contentModel != nil)
    {
        _replyTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(replyHeaderTapGesture:)];
        [[_contentModel boundView] addGestureRecognizer:_replyTapRecognizer];
    }
    
    if (_unsentButtonModel != nil)
    {
        _unsentButtonTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unsentButtonTapGesture:)];
        [[_unsentButtonModel boundView] addGestureRecognizer:_unsentButtonTapRecognizer];
    }
    
    if (_actionButtonModel != nil) {
        [(TGModernButtonView *)_actionButtonModel.boundView addTarget:self action:@selector(actionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
    UIView *backgroundView = [_imageModel boundView];
    [backgroundView addGestureRecognizer:_tapGestureRecognizer];
    [backgroundView addGestureRecognizer:_boundDoubleTapRecognizer];
    if ([TGOnegramSettings boolForKey:TGOnegramSettingGeneralNewChats])
        [_tapGestureRecognizer requireGestureRecognizerToFail:_boundDoubleTapRecognizer];
    
    [self layoutPlaceholderLabel];
    
    [self subscribeToCallbackButtonInProgress];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView.delegate = nil;
    UIView *imageView = [_imageModel boundView];
    [imageView removeGestureRecognizer:_tapGestureRecognizer];
    _tapGestureRecognizer.delegate = nil;
    _tapGestureRecognizer = nil;
    
    [imageView removeGestureRecognizer:_boundDoubleTapRecognizer];
    _boundDoubleTapRecognizer.delegate = nil;
    _boundDoubleTapRecognizer = nil;
    
    [[_contentModel boundView] removeGestureRecognizer:_replyTapRecognizer];
    _replyTapRecognizer = nil;
    
    [_placeholderLabel removeFromSuperview];
    _placeholderLabel = nil;
    
    if (_temporaryHighlightView != nil)
    {
        [_temporaryHighlightView removeFromSuperview];
        _temporaryHighlightView = nil;
    }
    
    if (_unsentButtonModel != nil)
    {
        [[_unsentButtonModel boundView] removeGestureRecognizer:_unsentButtonTapRecognizer];
        _unsentButtonTapRecognizer = nil;
    }
    
    if (_actionButtonModel != nil)
    {
        [(TGModernButtonView *)_actionButtonModel.boundView removeTarget:self action:@selector(actionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [super unbindView:viewStorage];
    
    [_callbackButtonInProgressDisposable setDisposable:nil];
}

- (void)actionPressed {
    if (_savedMessage)
    {
        int64_t peerId = 0;
        int32_t messageId = 0;
        for (TGMediaAttachment *attachment in _message.mediaAttachments)
        {
            if (attachment.type == TGForwardedMessageMediaAttachmentType)
            {
                peerId = ((TGForwardedMessageMediaAttachment *)attachment).forwardSourcePeerId ? : ((TGForwardedMessageMediaAttachment *)attachment).forwardPeerId;
                messageId = ((TGForwardedMessageMediaAttachment *)attachment).forwardMid ?: ((TGForwardedMessageMediaAttachment *)attachment).forwardPostId;
                break;
            }
        }
        
        [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(peerId), @"messageId": @(messageId)}];
    }
}

- (void)unsentButtonTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_context.companionHandle requestAction:@"showUnsentMessageMenu" options:@{@"mid": @(_mid)}];
    }
}

- (void)replyHeaderTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded)
    {
        CGPoint location = [recognizer locationInView:_contentModel.boundView];
        if (_replyHeaderViaUserModel != nil && (CGRectContainsPoint(_replyHeaderViaUserModel.frame, location) || _replyHeaderModel == nil)) {
            [_context.companionHandle requestAction:@"useContextBot" options:@{@"uid": @(_viaUser.uid), @"username": _viaUser.userName == nil ? @"" : _viaUser.userName}];
        } else if (_replyHeaderModel != nil) {
            [_context.companionHandle requestAction:@"navigateToMessage" options:@{@"mid": @(_replyMessageId), @"sourceMid": @(_mid)}];
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if (OGPlatformMediaDownloadsRequireUserAction() && (gestureRecognizer == _tapGestureRecognizer || gestureRecognizer == _boundDoubleTapRecognizer))
    {
        UIView *container = [_imageModel boundView];
        for (UIView *view = touch.view; view != nil && view != container; view = view.superview)
        {
            if ([view isKindOfClass:[UIControl class]])
                return false;
        }
    }
    return true;
}

- (void)messageImageViewActionButtonPressed:(TGMessageImageView *)messageImageView withAction:(TGMessageImageViewActionType)action
{
    if (!OGPlatformMediaDownloadsRequireUserAction() || messageImageView != ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView)
        return;

    if (action == TGMessageImageViewActionCancelDownload)
        [_context.companionHandle requestAction:@"mediaProgressCancelRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    else if (action == TGMessageImageViewActionDownload && !_mediaIsAvailable && !_progressVisible)
        [_context.companionHandle requestAction:@"mediaDownloadRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
}

- (void)setAnimatedEmoji:(bool)animatedEmoji
{
    _animatedEmoji = animatedEmoji;
    [self updateAnimationPlayback];
}

- (void)updateAnimationPlayback
{
    bool autoplay = _animatedEmoji || [TGOnegramSettings boolForKey:TGOnegramSettingMessagesAnimatedStickers];
    _animatedStickerModel.autoplay = autoplay;
    _animatedStickerModel.loops = autoplay && !_animatedEmoji;
}

- (void)messageTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (_animatedEmoji || (_animatedStickerModel != nil && !_animatedStickerModel.autoplay && !_animatedStickerModel.playing))
        {
            [_animatedStickerModel restart];
            return;
        }
        if (OGPlatformMediaDownloadsRequireUserAction() && !_mediaIsAvailable)
        {
            if (!_progressVisible)
                [_context.companionHandle requestAction:@"mediaDownloadRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            return;
        }
        [_context.companionHandle requestAction:@"stickerPackInfoRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    }
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (recognizer.longTapped)
            [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        else if (recognizer.doubleTapped)
            [_context.companionHandle requestAction:@"messageDoubleTapped" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    }
}

- (bool)gestureRecognizerShouldHandleLongTap:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (void)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer didBeginAtPoint:(CGPoint)__unused point
{
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer shouldFailTap:(CGPoint)__unused point
{
    return 0;
}

- (void)doubleTapGestureRecognizerSingleTapped:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
}

- (bool)gestureRecognizerShouldLetScrollViewStealTouches:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (bool)gestureRecognizerShouldFailOnMove:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (void)setTemporaryHighlighted:(bool)temporaryHighlighted viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    if (iosMajorVersion() >= 7)
    {
        TGImageView *imageView = ((TGMessageImageViewContainer *)_imageModel.boundView).imageView;
        if (imageView.currentImage != nil)
        {
            if (temporaryHighlighted)
            {
                if (_temporaryHighlightView == nil)
                {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
                    UIImage *highlightImage = [imageView.currentImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
#else
                    UIImage *highlightImage = imageView.currentImage;
#endif
                    _temporaryHighlightView = [[UIImageView alloc] initWithImage:highlightImage];
                    _temporaryHighlightView.frame = [_imageModel boundView].frame;
                    _temporaryHighlightView.tintColor = UIColorRGBA(0x000000, 0.2f);
                    [[_imageModel boundView].superview addSubview:_temporaryHighlightView];
                }
            }
            else if (_temporaryHighlightView != nil)
            {
                UIImageView *temporaryView = _temporaryHighlightView;
                [UIView animateWithDuration:0.4 animations:^
                {
                    temporaryView.alpha = 0.0f;
                } completion:^(__unused BOOL finished)
                {
                    [temporaryView removeFromSuperview];
                }];
                _temporaryHighlightView = nil;
            }
        }
    }
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    bool isPost = _authorPeer != nil && [_authorPeer isKindOfClass:[TGConversation class]];
    TGMessageViewModelLayoutConstants const *layoutConstants = TGGetMessageViewModelLayoutConstants();
    
    CGFloat topSpacing = (_collapseFlags & TGModernConversationItemCollapseTop) ? layoutConstants->topInsetCollapsed : layoutConstants->topInset;
    CGFloat bottomSpacing = (_collapseFlags & TGModernConversationItemCollapseBottom) ? layoutConstants->bottomInsetCollapsed : layoutConstants->bottomInset;
    
    if (isPost) {
        topSpacing = layoutConstants->topPostInset;
        bottomSpacing = layoutConstants->bottomPostInset;
    }
    
    CGFloat avatarOffset = 0.0f;
    if (_hasAvatar)
        avatarOffset = 38.0f;
    
    CGFloat unsentOffset = 0.0f;
    if (!_incomingAppearance && _deliveryState == TGMessageDeliveryStateFailed)
        unsentOffset = 29.0f;
    
    CGRect imageFrame = CGRectMake(_incomingAppearance ? (avatarOffset + layoutConstants->leftImageInset) : (containerSize.width - _imageModel.frame.size.width - layoutConstants->rightImageInset - unsentOffset), topSpacing, _imageModel.frame.size.width, _imageModel.frame.size.height);
    if (_incomingAppearance && _editing)
        imageFrame.origin.x += 42.0f;
    
    if (!_editing && fabs(_replyPanOffset) > FLT_EPSILON)
        imageFrame.origin.x += _replyPanOffset;
    
    _imageModel.frame = imageFrame;
    _animatedStickerModel.frame = imageFrame;

    if (_brandedDeliveryPlateModel != nil)
    {
        _brandedDeliveryPlateModel.hidden = !_incomingAppearance && _deliveryState != TGMessageDeliveryStateDelivered;
        if (!_brandedDeliveryPlateModel.hidden)
        {
            UIImage *deliveryImage = [TGPresentationAssets brandedIOS6FlatDeliveryTagImage:[TGDateUtils stringForShortTime:(int)_message.date] incoming:_incomingAppearance read:(_read || _context.isSavedMessages)];
            _brandedDeliveryPlateModel.image = deliveryImage;
            CGSize deliverySize = deliveryImage.size;
            _brandedDeliveryPlateModel.frame = [TGPresentationAssets brandedIOS6DeliveryTagFrameForMessageFrame:imageFrame tagSize:deliverySize incoming:_incomingAppearance];
        }
    }

    CGFloat reactionExtraHeight = 0.0f;
    TGMessageReactionsLayout *reactionsLayout = [_reactionsModel layoutWithMaximumWidth:imageFrame.size.width trailingWidth:0.0f trailingHeight:0.0f];
    if (reactionsLayout != nil)
        reactionExtraHeight = TGMessageReactionsCurrentMetrics().topSpacing + reactionsLayout.size.height;
    [_reactionsModel applyLayout:reactionsLayout origin:CGPointMake(CGRectGetMinX(imageFrame), CGRectGetMaxY(imageFrame) + TGMessageReactionsCurrentMetrics().topSpacing)];
    
    if (_placeholderLabel != nil)
        _placeholderLabel.frame = CGRectMake(0.0f, 0.0f, imageFrame.size.width, imageFrame.size.height);
    
    if (_contentModel != nil)
    {
        CGFloat availableWidth = containerSize.width - imageFrame.size.width - 40.0f - avatarOffset;
        
        bool updateContent = false;
        CGRect contentFrame = CGRectZero;
        if (_replyHeaderModel != nil) {
            [_replyHeaderModel layoutForContainerSize:CGSizeMake(availableWidth, 0.0f) updateContent:&updateContent];
            contentFrame = CGRectMake(0.0f, 0.0f, _replyHeaderModel.frame.size.width + 17.0f, _replyHeaderModel.frame.size.height + 5.0f);
            
            if (_replyHeaderViaUserModel != nil) {
                if ([_replyHeaderViaUserModel layoutNeedsUpdatingForContainerSize:CGSizeMake(availableWidth, 0.0f)]) {
                    updateContent = true;
                    [_replyHeaderViaUserModel layoutForContainerSize:CGSizeMake(availableWidth, 0.0f)];
                }
                
                _replyHeaderViaUserModel.frame = CGRectMake(5.0f, 2.0f, _replyHeaderViaUserModel.frame.size.width, _replyHeaderViaUserModel.frame.size.height);
                contentFrame.size.height += _replyHeaderViaUserModel.frame.size.height + 4.0f;
                contentFrame.size.width = MAX(contentFrame.size.width, _replyHeaderViaUserModel.frame.size.width + 14.0f);
            }
        } else {
            if (_replyHeaderViaUserModel != nil) {
                if ([_replyHeaderViaUserModel layoutNeedsUpdatingForContainerSize:CGSizeMake(availableWidth, 0.0f)]) {
                    updateContent = true;
                    [_replyHeaderViaUserModel layoutForContainerSize:CGSizeMake(availableWidth, 0.0f)];
                }
                
                _replyHeaderViaUserModel.frame = CGRectMake(5.0f, 2.0f, _replyHeaderViaUserModel.frame.size.width, _replyHeaderViaUserModel.frame.size.height);
                contentFrame.size.width = _replyHeaderViaUserModel.frame.size.width + 14.0f;
                contentFrame.size.height += _replyHeaderViaUserModel.frame.size.height + 9.0f;
            }
        }
        
        if (_incomingAppearance)
            contentFrame.origin.x = containerSize.width - contentFrame.size.width - 7.0f;
        else
            contentFrame.origin.x = 9.0f + (_editing ? 42.0f : 0.0f);
        
        contentFrame.origin.y = 0.0f;
        
        _contentModel.frame = contentFrame;
        _replyHeaderModel.frame = CGRectMake(7.0f, _replyHeaderViaUserModel == nil ? 0.0f : (_replyHeaderViaUserModel.frame.size.height + 2.0), _replyHeaderModel.frame.size.width, _replyHeaderModel.frame.size.height);
        _replyBackgroundModel.frame = CGRectMake(contentFrame.origin.x, contentFrame.origin.y + 3.0f, contentFrame.size.width - 2.0f, contentFrame.size.height - 5.0f);
        
        if ((_incomingAppearance && _replyBackgroundModel.frame.origin.x < CGRectGetMaxX(imageFrame)) || (!_incomingAppearance && CGRectGetMaxX(_replyBackgroundModel.frame) > imageFrame.origin.x))
        {
            _contentModel.alpha = 0.0f;
            _replyBackgroundModel.alpha = 0.0f;
        }
        else
        {
            _contentModel.alpha = 1.0f;
            _replyBackgroundModel.alpha = 1.0f;
        }
        
        if (updateContent)
        {
            [_contentModel setNeedsSubmodelContentsUpdate];
            [_contentModel updateSubmodelContentsIfNeeded];
        }
    }
    
    if (_unsentButtonModel != nil)
    {
        _unsentButtonModel.frame = CGRectMake(containerSize.width - _unsentButtonModel.frame.size.width - 9, _imageModel.frame.size.height + topSpacing + bottomSpacing - _unsentButtonModel.frame.size.height - ((_collapseFlags & TGModernConversationItemCollapseBottom) ? 5 : 6), _unsentButtonModel.frame.size.width, _unsentButtonModel.frame.size.height);
    }
    
    if (_actionButtonModel != nil)
    {
        _actionButtonModel.frame = CGRectOffset(_actionButtonModel.bounds, CGRectGetMaxX(imageFrame) + 7.0f, CGRectGetMaxY(imageFrame) - 29.0f - 1.0f);
    }
    
    CGFloat replyButtonsHeight = 0.0f;
    if (_replyButtonsModel != nil) {
        CGRect backgroundFrame = _imageModel.frame;
        
        CGFloat replyButtonsAvailableWidth = _incomingAppearance ? (containerSize.width - 38.0f - backgroundFrame.origin.x) : (CGRectGetMaxX(backgroundFrame) - 38.0f);
        [_replyButtonsModel layoutForContainerSize:CGSizeMake(MAX(backgroundFrame.size.width + 10.0f, MIN([_replyButtonsModel minimumWidth], replyButtonsAvailableWidth)), containerSize.height)];
        
        CGSize buttonsSize = _replyButtonsModel.frame.size;
        CGFloat buttonsAnchorX = _incomingAppearance ? backgroundFrame.origin.x : (CGRectGetMaxX(backgroundFrame) - buttonsSize.width);
        CGFloat buttonsShiftX = _incomingAppearance ? -5.0f : 5.0f;
        _replyButtonsModel.frame = CGRectMake(buttonsAnchorX + buttonsShiftX, CGRectGetMaxY(backgroundFrame) + reactionExtraHeight, buttonsSize.width, buttonsSize.height);
        replyButtonsHeight = _replyButtonsModel.frame.size.height;
        self.avatarOffset = replyButtonsHeight;
    }
    
    CGRect frame = self.frame;
    CGFloat stackedHeight = topSpacing + _imageModel.frame.size.height + bottomSpacing + reactionExtraHeight + replyButtonsHeight;
    frame.size = CGSizeMake(containerSize.width, stackedHeight);
    self.frame = frame;
    
    [super layoutForContainerSize:containerSize];
}

- (void)avatarTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        int64_t peerId = _message.fromUid;
        bool peer = !TGPeerIdIsUser(peerId);
        if (_context.isSavedMessages)
        {
            for (TGMediaAttachment *attachment in _message.mediaAttachments)
            {
                if (attachment.type == TGForwardedMessageMediaAttachmentType)
                {
                    peerId = ((TGForwardedMessageMediaAttachment *)attachment).forwardPeerId;
                    peer = true;
                    break;
                }
            }
        }
        
        if (peer)
        {
            [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(peerId), @"messageId": @(_mid), @"chat": @(_context.isSavedMessages)}];
        }
        else
        {
            [_context.companionHandle requestAction:@"userAvatarTapped" options:@{@"uid": @(peerId), @"mid": @(_mid)}];
        }
    }
}

@end
