#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGImageMessageViewModel.h"
#import "TGMessageGroupedLayout.h"

#import <QuartzCore/QuartzCore.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGModernConversationItem.h"

#import "TGModernView.h"

#import "TGTelegraphConversationMessageAssetsSource.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"

#import "TGModernViewContext.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"

#import "TGModernLetteredAvatarViewModel.h"
#import "TGMessageImageViewModel.h"
#import "TGModernImageViewModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernDateViewModel.h"
#import "TGModernClockProgressViewModel.h"
#import "TGModernButtonViewModel.h"
#import "TGModernCheckButtonViewModel.h"

#import "TGModernRemoteImageView.h"

#import "TGMessageImageView.h"
#import "TGMessageImageViewTimestampView.h"

#import "TGInstantPreviewTouchAreaModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "TGContentBubbleViewModel.h"
#import "TGReplyHeaderModel.h"

#import "TGReusableLabel.h"

#import "TGTextMessageBackgroundViewModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernTextViewModel.h"

#import "TGContentBubbleViewModel.h"

#import "TGMessageViewsViewModel.h"
#import "TGModernButtonView.h"
#import "TGModernButtonViewModel.h"

#import "TGMessageReplyButtonsModel.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessageViewCountContentProperty.h"

#import "TGAudioWebpageFooterModel.h"

static inline bool TGIOS6ImagePeerIdLooksLikeModernRawChannel(int64_t peerId)
{
    return peerId <= ((int64_t)INT32_MIN) * 3 && peerId > ((int64_t)INT32_MIN) * 4;
}

static inline bool TGIOS6ImagePeerIdIsModernRawChannel(int64_t peerId)
{
    return TGIOS6ImagePeerIdLooksLikeModernRawChannel(peerId) && [TGDatabaseInstance() loadConversationWithId:peerId] != nil;
}
#import "TGArticleWebpageFooterModel.h"
#import "TGStickerWebpageFooterModel.h"
#import "TGMusicWebpageFooterModel.h"
#import "TGDocumentWebpageFooterModel.h"
#import "TGRoundVideoWebpageFooterModel.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"
#import "TGMessageReactionsLayout.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static const int TGIOS6SquareGroupedMediaInnerCorners = 1 << 8;
static const CGFloat TGImageMessageMinWidth = 170.0f;
static const CGFloat TGImageMessageMinHeight = 74.0f;
static const CGFloat TGImageMessageMaxHeightRatio = 380.0f / 300.0f;
static const CGFloat TGImageMessageCaptionHorizontalInset = 12.0f;

static bool TGIOS6ImageMessageHasDiscussionFooter(TGMessage *message)
{
    id property = [message.contentProperties objectForKey:@"ios6Discussion"];
    return [property isKindOfClass:[TGMessageDiscussionContentProperty class]] && ((TGMessageDiscussionContentProperty *)property).comments;
}

@interface TGImageMessageViewModel () <UIGestureRecognizerDelegate, TGDoubleTapGestureRecognizerDelegate, TGMessageImageViewDelegate>
{
    TGModernViewContext *_context;
    
    bool _incoming;
    TGMessageDeliveryState _deliveryState;
    bool _read;
    int _date;
    int32_t _messageLifetime;
    
    NSString *_legacyThumbnailCacheUri;
    CGSize _originalImageSize;
    bool _animateNextLayout;
    
    CGSize _imageSize;
    TGMessageGroupPositionFlags _imagePosition;
    bool _imageInsideGroupBubble;
    NSString *_measuredCaption;
    CGFloat _measuredCaptionMaxWidth;
    CGFloat _measuredCaptionWidth;
    CGFloat _measuredCaptionFontSize;
    CGFloat _measuredCaptionHorizontalInset;
    
    bool _hasAvatar;
    bool _isBot;
    bool _byAdmin;
    bool _savedMessage;
    
    float _progress;
    bool _progressVisible;
    
    bool _displayCaption;
    NSString *_messageCaption;
    NSArray *_messageTextCheckingResults;
    
    bool _isMessageViewed;
    NSTimeInterval _messageViewDate;
    
    TGDoubleTapGestureRecognizer *_boundDoubleTapRecognizer;
    TGDoubleTapGestureRecognizer *_boundBackgroundDoubleTapRecognizer;
    
    NSArray *_currentLinkSelectionViews;
    
    TGModernFlatteningViewModel *_adminContentModel;
    TGModernDateViewModel *_dateModel;
    TGModernClockProgressViewModel *_progressModel;
    TGModernImageViewModel *_checkFirstModel;
    TGModernImageViewModel *_checkSecondModel;
    TGModernTextViewModel *_authorSignatureModel;
    NSString *_authorSignature;
    
    bool _checkFirstEmbeddedInContent;
    bool _checkSecondEmbeddedInContent;
    
    TGModernImageViewModel *_unsentButtonModel;
    UITapGestureRecognizer *_unsentButtonTapRecognizer;
    
    TGInstantPreviewTouchAreaModel *_instantPreviewTouchAreaModel;
    
    UIImageView *_temporaryHighlightView;
    UIView *_ios6SingleImageGlossView;
    CAGradientLayer *_ios6SingleImageGlossLayer;
    CALayer *_ios6SingleImageGlossRimLayer;
    
    CGPoint _boundOffset;
    CGPoint _imageOrigin;
    
    NSTimer *_viewDateTimer;
    
    TGModernTextViewModel *_forwardedHeaderModel;
    TGModernTextViewModel *_authorNameModel;
    TGModernTextViewModel *_viaUserModel;
    TGUser *_viaUser;
    TGReplyHeaderModel *_replyHeaderModel;
    
    int32_t _replyMessageId;
    int64_t _forwardedPeerId;
    int32_t _forwardedMessageId;
    
    NSString *_caption;
    TGMessageViewCountContentProperty *_messageViews;
    TGMessageViewsViewModel *_messageViewsModel;
    TGModernLabelViewModel *_editedLabelModel;
    
    TGModernButtonViewModel *_actionButtonModel;
    
    TGMessage *_replyHeader;
    id _replyAuthor;
    id _forwardPeer;
    bool _isChannel;
    id _forwardAuthor;
    NSArray *_textCheckingResults;
    UIColor *_authorNameColor;
    
    TGMessageReplyButtonsModel *_replyButtonsModel;
    TGBotReplyMarkup *_replyMarkup;
    SMetaDisposable *_callbackButtonInProgressDisposable;
    bool _callbackButtonInProgressSubscribed;
    
    bool _isEdited;
    
    TGWebpageFooterModel *_webPageFooterModel;
    bool _boundToContainer;
    TGWebPageMediaAttachment *_webPage;
    bool _skipContentModelAnimation;

    TGMessageReactionsModel *_reactionsModel;
    
    TGModernButtonViewModel *_groupCheckAreaModel;
    TGModernCheckButtonViewModel *_groupCheckButtonModel;
    
}

@end

@implementation TGImageMessageViewModel

- (bool)discussionCommentsFooterIntegratedInBubble
{
    return _positionFlags == TGMessageGroupPositionNone || [self hasMainPosition];
}

- (CGRect)discussionCommentsBubbleFrame
{
    if (_backgroundModel != nil)
        return _backgroundModel.frame;
    return _imageModel.frame;
}

- (bool)_mediaReactionsInBubble
{
    return _reactionsModel.buttons.count != 0 && (_positionFlags == TGMessageGroupPositionNone || [self hasMainPosition]);
}

- (bool)_ios6RequiresBubbleBackground
{
    return ([self discussionCommentsFooterHeight] > FLT_EPSILON && [self discussionCommentsFooterIntegratedInBubble]) || [self _mediaReactionsInBubble];
}

- (bool)_ios6GroupHasBubbleFooter
{
    return _groupedLayout != nil && (_groupedLayout.discussion != nil || _groupedLayout.reactionSummary.length != 0);
}

- (bool)_groupHasBubble
{
    if (_groupedLayout == nil || _positionFlags == TGMessageGroupPositionNone || _positionFlags == TGMessageGroupPositionUnknown)
        return false;
    return _groupedLayout.caption.length != 0 || [self _ios6GroupHasBubbleFooter] || [self hasHeader];
}

- (bool)_ios6ClassicSingleImageGloss
{
    return [TGPresentation classicIOS6Style]
        && _positionFlags == TGMessageGroupPositionNone
        && _caption.length == 0
        && _replyHeader == nil
        && (_forwardPeer == nil || _context.isSavedMessages)
        && _viaUser == nil
        && _webPageFooterModel == nil
        && !(_authorPeer != nil && _context.isFeed);
}

- (void)_ios6UpdateSingleImageGlossFrame
{
    UIView *imageContainer = [_imageModel boundView];
    if (_ios6SingleImageGlossView == nil || imageContainer == nil)
        return;

    CGFloat sideInset = 7.0f;
    CGFloat glossHeight = MIN(18.0f, MAX(14.0f, imageContainer.bounds.size.height * 0.07f));
    _ios6SingleImageGlossView.frame = CGRectMake(sideInset, 1.0f, MAX(0.0f, imageContainer.bounds.size.width - sideInset * 2.0f), glossHeight);
    _ios6SingleImageGlossView.layer.cornerRadius = MIN(9.0f, glossHeight * 0.45f);
    _ios6SingleImageGlossLayer.frame = _ios6SingleImageGlossView.bounds;
    _ios6SingleImageGlossLayer.cornerRadius = _ios6SingleImageGlossView.layer.cornerRadius;
    _ios6SingleImageGlossRimLayer.frame = CGRectMake(5.0f, 0.5f, MAX(0.0f, _ios6SingleImageGlossView.bounds.size.width - 10.0f), 1.5f);
    _ios6SingleImageGlossRimLayer.cornerRadius = 0.75f;
}

- (void)_ios6EnsureSingleImageGloss
{
    if (![self _ios6ClassicSingleImageGloss])
        return;

    TGMessageImageViewContainer *imageContainer = (TGMessageImageViewContainer *)[_imageModel boundView];
    if (imageContainer == nil || imageContainer.imageView == nil)
        return;

    if (_ios6SingleImageGlossView == nil)
    {
        _ios6SingleImageGlossView = [[UIView alloc] initWithFrame:CGRectZero];
        _ios6SingleImageGlossView.userInteractionEnabled = false;
        _ios6SingleImageGlossView.backgroundColor = [UIColor clearColor];
        _ios6SingleImageGlossView.clipsToBounds = true;

        _ios6SingleImageGlossLayer = [CAGradientLayer layer];
        _ios6SingleImageGlossLayer.colors = @[
            (__bridge id)[[UIColor colorWithWhite:1.0f alpha:0.95f] CGColor],
            (__bridge id)[[UIColor colorWithWhite:1.0f alpha:0.68f] CGColor],
            (__bridge id)[[UIColor colorWithWhite:1.0f alpha:0.26f] CGColor],
            (__bridge id)[[UIColor colorWithWhite:1.0f alpha:0.0f] CGColor]
        ];
        _ios6SingleImageGlossLayer.locations = @[@0.0f, @0.18f, @0.56f, @1.0f];
        _ios6SingleImageGlossLayer.startPoint = CGPointMake(0.5f, 0.0f);
        _ios6SingleImageGlossLayer.endPoint = CGPointMake(0.5f, 1.0f);
        [_ios6SingleImageGlossView.layer addSublayer:_ios6SingleImageGlossLayer];

        _ios6SingleImageGlossRimLayer = [CALayer layer];
        _ios6SingleImageGlossRimLayer.backgroundColor = [[UIColor colorWithWhite:1.0f alpha:0.92f] CGColor];
        [_ios6SingleImageGlossView.layer addSublayer:_ios6SingleImageGlossRimLayer];
    }

    [imageContainer insertSubview:_ios6SingleImageGlossView aboveSubview:imageContainer.imageView];
    [self _ios6UpdateSingleImageGlossFrame];
}

static CTFontRef textFontForSize(CGFloat size)
{
    static CTFontRef font = NULL;
    static int cachedSize = 0;
    
    if ((int)size != cachedSize || font == NULL)
    {
        font = TGCoreTextSystemFontOfSize(size);
        cachedSize = (int)size;
    }
    
    return font;
}

- (instancetype)initWithMessage:(TGMessage *)message imageInfo:(TGImageInfo *)imageInfo authorPeer:(id)authorPeer context:(TGModernViewContext *)context forwardPeer:(id)forwardPeer forwardAuthor:(id)forwardAuthor forwardMessageId:(int32_t)forwardMessageId replyHeader:(TGMessage *)replyHeader replyAuthor:(id)replyAuthor viaUser:(TGUser *)viaUser
{
    return [self initWithMessage:message imageInfo:imageInfo authorPeer:authorPeer context:context forwardPeer:forwardPeer forwardAuthor:forwardAuthor forwardMessageId:forwardMessageId replyHeader:replyHeader replyAuthor:replyAuthor viaUser:viaUser caption:nil textCheckingResults:nil];
}

- (instancetype)initWithMessage:(TGMessage *)message imageInfo:(TGImageInfo *)imageInfo authorPeer:(id)authorPeer context:(TGModernViewContext *)context forwardPeer:(id)forwardPeer forwardAuthor:(id)forwardAuthor forwardMessageId:(int32_t)forwardMessageId replyHeader:(TGMessage *)replyHeader replyAuthor:(id)replyAuthor viaUser:(TGUser *)viaUser caption:(NSString *)caption textCheckingResults:(NSArray *)textCheckingResults
{
    return [self initWithMessage:message imageInfo:imageInfo authorPeer:authorPeer context:context forwardPeer:forwardPeer forwardAuthor:forwardAuthor forwardMessageId:forwardMessageId replyHeader:replyHeader replyAuthor:replyAuthor viaUser:viaUser caption:caption textCheckingResults:textCheckingResults webPage:nil];
}

- (instancetype)initWithMessage:(TGMessage *)message imageInfo:(TGImageInfo *)imageInfo authorPeer:(id)authorPeer context:(TGModernViewContext *)context forwardPeer:(id)forwardPeer forwardAuthor:(id)forwardAuthor forwardMessageId:(int32_t)forwardMessageId replyHeader:(TGMessage *)replyHeader replyAuthor:(id)replyAuthor viaUser:(TGUser *)viaUser caption:(NSString *)caption textCheckingResults:(NSArray *)textCheckingResults webPage:(TGWebPageMediaAttachment *)webPage {
    self = [super initWithAuthorPeer:authorPeer context:context];
    if (self != nil)
    {
        _callbackButtonInProgressDisposable = [[SMetaDisposable alloc] init];
        
        _previewEnabled = true;
        _canDownload = true;
        
        _context = context;
        
        _webPage = webPage;
        
        bool isChannel = [authorPeer isKindOfClass:[TGConversation class]];
        
        _authorPeerId = message.fromUid;
        _authorPeer = authorPeer;
        
        if (message.groupedId != 0)
            _positionFlags = TGMessageGroupPositionUnknown;
        
        if (message.isEdited && (_authorPeer == nil || ![_authorPeer isKindOfClass:[TGConversation class]] || !((TGConversation *)_authorPeer).isChannel || ((TGConversation *)_authorPeer).isChannelGroup)) {
            _isEdited = true;
        }
        
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
        
        _incoming = !message.outgoing;
        _incomingAppearance = _incoming || isChannel || _savedMessage;
        _deliveryState = message.deliveryState;
        _read = ![_context isMessageUnread:message];
        _date = (int32_t)message.date;
        _messageViews = message.viewCount;
        _message = message;
        _textCheckingResults = textCheckingResults;
        _byAdmin = [_context isByAdmin:_message];
        
        if ([authorPeer isKindOfClass:[TGUser class]]) {
            TGUser *author = authorPeer;
            _isBot = author.kind == TGUserKindBot || author.kind == TGUserKindSmartBot;
        }
        
        _replyHeader = replyHeader;
        _replyAuthor = replyAuthor;
        _forwardPeer = forwardPeer;
        _viaUser = viaUser;
        _isChannel = isChannel;
        _messageCaption = [caption copy];
        _messageTextCheckingResults = [textCheckingResults copy];
        _caption = _messageCaption;
        _forwardedMessageId = forwardMessageId;
        _forwardAuthor = forwardAuthor;
        
        NSString *imageUri = [self updatedImageUriForInfo:imageInfo];
        
        _hasAvatar = authorPeer != nil && ![authorPeer isKindOfClass:[TGConversation class]];
        if ([authorPeer isKindOfClass:[TGConversation class]]) {
            TGConversation *conversationAuthor = (TGConversation *)authorPeer;
            if (TGMessageViewModelShouldDisplayConversationAvatar(conversationAuthor, context)) {
                _hasAvatar = true;
            }
        }
        
        _needsEditingCheckButton = true;
        
        _mid = message.mid;
        _groupedId = message.groupedId;
        _deliveryState = message.deliveryState;
        _date = (int32_t)message.date;
        _messageLifetime = message.messageLifetime;
        
        CGSize imageSize = CGSizeZero;
        _imageModel = [[TGMessageImageViewModel alloc] init];
        [self updateImageUri:imageUri];
        [_imageModel setPresentation:_context.presentation];
        
        CGSize imageOriginalSize = CGSizeMake(1, 1);
        [imageInfo imageUrlForLargestSize:&imageOriginalSize];
        imageSize = imageOriginalSize;
        
        _imageModel.skipDrawInContext = true;
        
        CGSize renderSize = CGSizeZero;
        [TGImageMessageViewModel calculateImageSizesForImageSize:imageSize thumbnailSize:&imageSize renderSize:&renderSize squareAspect:message.messageLifetime > 0 && message.messageLifetime <= 60 && message.layer >= 17 && !_ignoreMessageLifetime];
        
        _originalImageSize = imageSize;
        
        _imageModel.frame = CGRectMake(0, 0, imageSize.width, imageSize.height);
        
        _reactionsModel = [[TGMessageReactionsModel alloc] initWithContext:context style:_incomingAppearance ? TGMessageReactionsStyleIncoming : TGMessageReactionsStyleOutgoing];
        if (message.groupedId == 0)
            [_reactionsModel updateWithMessage:message parent:nil viewStorage:nil container:nil];

        [self setupContentModel:nil];
        
        [self addSubmodel:_imageModel];
        [_reactionsModel moveToFrontInParent:self viewStorage:nil container:nil];
        
        if (_messageLifetime != 0 && message.layer >= 17)
        {
            _isMessageViewed = [context isSecretMessageViewed:_mid];
            _messageViewDate = [context secretMessageViewDate:_mid];
        }
        
        if (!_incoming)
        {
            if (_deliveryState == TGMessageDeliveryStateFailed)
            {
                [self addSubmodel:[self unsentButtonModel]];
            }
        }
        
        bool isBot = false;
        if ([authorPeer isKindOfClass:[TGUser class]]) {
            if (((TGUser *)authorPeer).kind == TGUserKindBot || ((TGUser *)authorPeer).kind ==  TGUserKindSmartBot) {
                isBot = true;
            }
        }
        
        bool forwardedFromChannel = false;
        
        if (_incomingAppearance && [forwardPeer isKindOfClass:[TGConversation class]]) {
            TGConversation *conversation = forwardPeer;
            if (conversation.isChannel && !conversation.isChannelGroup) {
                forwardedFromChannel = true;
            }
        }
        
        if (_incomingAppearance && ((_savedMessage && hasForwardPostId) || isChannel || _context.isBot || _context.isPublicGroup || isBot || forwardedFromChannel) && !_context.isAdminLog)
            [_backgroundModel setPartialMode:false];
        
        if (_incomingAppearance && ((_savedMessage && hasForwardPostId) || isChannel || _context.isBot || _context.isPublicGroup || isBot || forwardedFromChannel) && !_context.isAdminLog && (_savedMessage || ![TGPresentation brandedIOS6Style])) {
            _actionButtonModel = [[TGModernButtonViewModel alloc] init];
            _actionButtonModel.image = _savedMessage ? context.presentation.images.chatActionGoToImage : context.presentation.images.chatActionShareImage;
            _actionButtonModel.modernHighlight = true;
            _actionButtonModel.frame = CGRectMake(0.0f, 0.0f, 29.0f, 29.0f);
            [self addSubmodel:_actionButtonModel];
        }
        
        TGBotReplyMarkup *replyMarkup = message.replyMarkup;
        if (replyMarkup != nil && replyMarkup.isInline) {
            _replyMarkup = replyMarkup;
            _replyButtonsModel = [[TGMessageReplyButtonsModel alloc] initWithContext:context];
            id companionHandle = _context.companionHandle;
            int32_t messageId = _mid;
            _replyButtonsModel.buttonActivated = ^(TGBotReplyMarkupButton *button, NSInteger index) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{@"mid": @(messageId), @"command": button.text}];
                if (button.action != nil) {
                    dict[@"action"] = button.action;
                }
                dict[@"index"] = @(index);
                [companionHandle requestAction:@"activateCommand" options:dict];
            };
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:false];
            [self addSubmodel:_replyButtonsModel];
        }
    }
    return self;
}

- (void)enableInstantPreview
{
    if (_instantPreviewTouchAreaModel == nil)
    {
        TGMessageViewModelReference *messageLifetimeReference1 = [self lifetimeReference];
        _instantPreviewTouchAreaModel = [[TGInstantPreviewTouchAreaModel alloc] init];
        _instantPreviewTouchAreaModel.touchesBeganAction = ^
        {
            [messageLifetimeReference1 withValue:^(void *value)
            {
                __strong TGImageMessageViewModel *strongSelf = (__bridge TGImageMessageViewModel *)value;
                if (strongSelf != nil)
                    [strongSelf activateMedia:true];
            }];
        };
        _instantPreviewTouchAreaModel.touchesCompletedAction = ^
        {
            [messageLifetimeReference1 withValue:^(void *value)
            {
                __strong TGImageMessageViewModel *strongSelf = (__bridge TGImageMessageViewModel *)value;
                if (strongSelf != nil)
                    [strongSelf deactivateMedia:true];
            }];
        };
        
        _instantPreviewTouchAreaModel.viewUserInteractionDisabled = !_mediaIsAvailable || _progressVisible;
        
        [self addSubmodel:_instantPreviewTouchAreaModel];
    }
}

- (NSString *)stringForLifetime:(int32_t)remainingSeconds
{
    return [TGStringUtils stringForShortMessageTimerSeconds:remainingSeconds];
}

- (NSString *)defaultAdditionalDataString
{
    if (self.isSecret)
    {
        if (_isMessageViewed)
        {
            if (ABS(_messageViewDate - DBL_EPSILON) > 0.0)
            {
                NSTimeInterval endTime = _messageViewDate + _messageLifetime;
                int remainingSeconds = MAX(0, (int)(endTime - CFAbsoluteTimeGetCurrent()));
                return [self stringForLifetime:remainingSeconds];
            }
            return [self stringForLifetime:0];
        }
        else
            return [self stringForLifetime:_messageLifetime];
    }
    
    return nil;
}

- (void)setIsSecret:(bool)isSecret
{
    _isSecret = isSecret;
    
    [self updateImageOverlay:false];
}

- (CGSize)mediaSourceSize
{
    return CGSizeZero;
}

- (bool)_usesSecretMediaAspect
{
    return _messageLifetime > 0 && _messageLifetime <= 60 && _message.layer >= 17 && !_ignoreMessageLifetime;
}

- (CGFloat)captionHorizontalInset
{
    if ([TGPresentation brandedIOS6Style] || [self _mediaReactionsInBubble] || _webPageFooterModel != nil)
        return TGImageMessageCaptionHorizontalInset;
    CGFloat bubbleExtraWidth = [TGPresentation classicIOS6Style] ? 4.0f : 0.0f;
    return 2.0f * TGMessageFontMetric(11.0f) + 6.0f - 9.0f - bubbleExtraWidth;
}

- (CGSize)_captionFittedMediaSize:(CGSize)defaultSize
{
    CGSize sourceSize = [self mediaSourceSize];
    CGFloat boundingWidth = 0.0f;
    if (_caption.length != 0 && _textModel != nil && _webPageFooterModel == nil && ![self _usesSecretMediaAspect] && sourceSize.width >= 1.0f && sourceSize.height >= 1.0f)
    {
        CGFloat maxWidth = [TGImageMessageViewModel maximumMediaSizeLarger:false].width;
        CGFloat fontSize = TGGetMessageViewModelLayoutConstants()->textFontSize;
        CGFloat horizontalInset = [self captionHorizontalInset];
        if (_measuredCaption != _caption || ABS(_measuredCaptionMaxWidth - maxWidth) > FLT_EPSILON || ABS(_measuredCaptionFontSize - fontSize) > FLT_EPSILON || ABS(_measuredCaptionHorizontalInset - horizontalInset) > FLT_EPSILON)
        {
            CGSize textSize = [self contentSizeForContainerSize:CGSizeMake(maxWidth - horizontalInset, CGFLOAT_MAX) needsContentsUpdate:NULL infoWidth:0.0f];
            _measuredCaption = _caption;
            _measuredCaptionMaxWidth = maxWidth;
            _measuredCaptionWidth = CGCeil(textSize.width);
            _measuredCaptionFontSize = fontSize;
            _measuredCaptionHorizontalInset = horizontalInset;
        }
        CGFloat desiredWidth = MIN(maxWidth, _measuredCaptionWidth + horizontalInset);
        if (desiredWidth > defaultSize.width + 1.0f)
            boundingWidth = desiredWidth;
    }
    
    if (ABS(boundingWidth - _mediaBoundingWidth) > FLT_EPSILON)
    {
        _mediaBoundingWidth = boundingWidth;
        [self updateImageUri:[self updatedImageUri]];
    }
    
    if (_mediaBoundingWidth < FLT_EPSILON)
        return defaultSize;
    
    CGSize fittedSize = CGSizeZero;
    [TGImageMessageViewModel calculateImageSizesForImageSize:sourceSize boundingWidth:_mediaBoundingWidth thumbnailSize:&fittedSize renderSize:NULL squareAspect:false larger:false];
    return fittedSize;
}

- (NSString *)updatedImageUri
{
    return [self updatedImageUriForMessage:_message];
}

- (NSString *)updatedImageUriForMessage:(TGMessage *)message
{
    return [self updatedImageUriForMessage:message outImageInfo:NULL];
}

- (NSString *)updatedImageUriForMessage:(TGMessage *)__unused message outImageInfo:(TGImageInfo **)__unused outImageInfo
{
    return nil;
}

- (NSString *)updatedImageUriForInfo:(TGImageInfo *)imageInfo
{    
    NSString *imageUri = [imageInfo imageUrlForLargestSize:NULL];
    
    bool classicMedia = [TGPresentation classicIOS6Style];
    bool classicGroupedMedia = classicMedia && _positionFlags != TGMessageGroupPositionNone && _positionFlags != TGMessageGroupPositionUnknown;
    if (classicMedia || (_positionFlags == TGMessageGroupPositionNone && ((_authorPeer != nil && _context.isFeed) || _replyHeader != nil || _caption.length != 0 || (_forwardPeer != nil && !_context.isSavedMessages) || _viaUser != nil || _webPage != nil || TGIOS6ImageMessageHasDiscussionFooter(_message) || [self _ios6RequiresBubbleBackground])) || (_positionFlags != TGMessageGroupPositionNone && (_backgroundModel != nil || [self hasHeader])) || [self _groupHasBubble])
        imageUri = [imageUri stringByAppendingString:@"&flat=1"];
    
    int positionFlags = [self visiblePositionFlags];
    if (classicGroupedMedia)
        positionFlags |= TGIOS6SquareGroupedMediaInnerCorners;
    if (positionFlags != 0)
        imageUri = [imageUri stringByAppendingFormat:@"&position=%d", positionFlags];
    
    return imageUri;
}

- (void)updateImageUri:(NSString *)imageUri
{
    if (OGPlatformMediaDownloadsRequireUserAction() && [imageUri hasPrefix:@"web-search-gallery://?"] && [imageUri rangeOfString:@"&cacheOnly=1"].location == NSNotFound)
        imageUri = [imageUri stringByAppendingString:@"&cacheOnly=1"];

    _legacyThumbnailCacheUri = nil;
    if (imageUri == nil) {
        imageUri = @"photo-thumbnail://?";
    } else if ([imageUri hasPrefix:@"photo-thumbnail://?"])
    {
        NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:[imageUri substringFromIndex:@"photo-thumbnail://?".length]];
        _legacyThumbnailCacheUri = dict[@"legacy-thumbnail-cache-url"];
    }
    else if ([imageUri hasPrefix:@"video-thumbnail://?"])
    {
        NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:[imageUri substringFromIndex:@"video-thumbnail://?".length]];
        _legacyThumbnailCacheUri = dict[@"legacy-thumbnail-cache-url"];
    }
    else if ([imageUri hasPrefix:@"animation-thumbnail://?"])
    {
        NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:[imageUri substringFromIndex:@"animation-thumbnail://?".length]];
        _legacyThumbnailCacheUri = dict[@"legacy-thumbnail-cache-url"];
    }
    
    [_imageModel setUri:imageUri];
}

- (void)setAuthorNameColor:(UIColor *)authorNameColor
{
    _authorNameModel.textColor = authorNameColor;
    _authorNameColor = authorNameColor;
}

- (void)setAuthorSignature:(NSString *)authorSignature {
    if (_caption.length != 0) {
        _authorSignatureModel.text = authorSignature;
    }
    _authorSignature = authorSignature;
    
    [_imageModel setTimestampString:[self timestampString] signatureString:[self signatureString] displayCheckmarks:!_incoming && !(_incomingAppearance && _context.isSavedMessages) && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:_messageViews != nil viewsValue:_messageViews.viewCount animated:false];
}

- (NSString *)signatureString
{
    return _authorSignature.length > 0 ? _authorSignature : (_isEdited && _positionFlags == TGMessageGroupPositionNone ? TGLocalized(@"Conversation.MessageEditedLabel") : nil);
}

+ (void)calculateImageSizesForImageSize:(in CGSize)imageSize thumbnailSize:(out CGSize *)thumbnailSize renderSize:(out CGSize *)renderSize squareAspect:(bool)squareAspect
{
    [self calculateImageSizesForImageSize:imageSize thumbnailSize:thumbnailSize renderSize:renderSize squareAspect:squareAspect larger:false];
}

+ (void)calculateImageSizesForImageSize:(in CGSize)imageSize thumbnailSize:(out CGSize *)thumbnailSize renderSize:(out CGSize *)renderSize squareAspect:(bool)squareAspect larger:(bool)larger
{
    [self calculateImageSizesForImageSize:imageSize boundingWidth:0.0f thumbnailSize:thumbnailSize renderSize:renderSize squareAspect:squareAspect larger:larger];
}

+ (CGSize)maximumMediaSizeLarger:(bool)larger
{
    CGFloat maxSide = 228.0f;
    static bool hasTallScreen = true;
    static bool hasLargeScreen = true;
    static bool hasVeryLargeScreen = true;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hasTallScreen = [TGViewController hasTallScreen];
        hasLargeScreen = [TGViewController hasLargeScreen];
        hasVeryLargeScreen = [TGViewController hasVeryLargeScreen];
    });
    if (hasVeryLargeScreen && !hasTallScreen) {
        maxSide += 71.0f;
    }
    else if (hasLargeScreen) {
        maxSide += 51.0f;
    }
    
    if (larger) {
        maxSide += 25.0f;
    }
    
    return CGSizeMake(maxSide, CGFloor(maxSide * TGImageMessageMaxHeightRatio));
}

static CGSize TGImageMessageAspectFitted(CGSize size, CGSize boundingSize)
{
    CGFloat scale = MIN(boundingSize.width / size.width, boundingSize.height / size.height);
    return CGSizeMake(CGFloor(size.width * scale), CGFloor(size.height * scale));
}

static CGSize TGImageMessageAspectFilled(CGSize size, CGSize boundingSize)
{
    CGFloat scale = MAX(boundingSize.width / size.width, boundingSize.height / size.height);
    return CGSizeMake(CGFloor(size.width * scale), CGFloor(size.height * scale));
}

+ (void)calculateImageSizesForImageSize:(in CGSize)imageSize boundingWidth:(CGFloat)boundingWidth thumbnailSize:(out CGSize *)thumbnailSize renderSize:(out CGSize *)renderSize squareAspect:(bool)squareAspect larger:(bool)larger
{
    if (imageSize.width < 1.0f || imageSize.height < 1.0f)
        imageSize = CGSizeMake(1.0f, 1.0f);
    if (squareAspect)
    {
        CGFloat squareSide = 180.0f;
        
        if (imageSize.width > imageSize.height)
        {
            if (renderSize)
               *renderSize = CGSizeMake(imageSize.width * squareSide / imageSize.height, squareSide);
        }
        else
        {
            if (renderSize)
               *renderSize = CGSizeMake(squareSide, imageSize.height * squareSide / imageSize.width);
        }
        
        if (thumbnailSize)
           *thumbnailSize = CGSizeMake(squareSide, squareSide);
        
        return;
    }
    
    CGSize maxSize = [self maximumMediaSizeLarger:larger];
    CGSize minSize = CGSizeMake(MIN(TGImageMessageMinWidth, maxSize.width), TGImageMessageMinHeight);
    
    if (imageSize.width < 1.0f || imageSize.height < 1.0f)
        imageSize = CGSizeMake(minSize.width, minSize.width);
    
    CGSize nativeSize = TGImageMessageAspectFitted(imageSize, CGSizeMake(maxSize.width, maxSize.width));
    CGSize maxFittedSize = TGImageMessageAspectFitted(nativeSize, maxSize);
    CGFloat width = MAX(minSize.width, MIN(nativeSize.width, MIN(maxFittedSize.width, maxSize.width)));
    if (boundingWidth > width)
        width = CGFloor(MIN(boundingWidth, maxSize.width));
    
    CGSize fittedSize = nativeSize.width > width ? CGSizeMake(width, CGFloor(nativeSize.height * width / nativeSize.width)) : nativeSize;
    CGFloat filledHeight = fittedSize.width < width ? CGFloor(fittedSize.height * width / fittedSize.width) : fittedSize.height;
    CGSize resultSize = CGSizeMake(width, MAX(minSize.height, MIN(filledHeight, maxSize.height)));
    
    if (renderSize != NULL)
        *renderSize = TGImageMessageAspectFilled(nativeSize, resultSize);
    if (thumbnailSize != NULL)
       *thumbnailSize = resultSize;
}

- (UIColor *)dateColor
{
    return [UIColor whiteColor];
}

- (int)clockProgressType
{
    return TGModernClockProgressTypeOutgoingMediaClock;
}

- (CGPoint)dateOffset
{
    return CGPointZero;
}

- (bool)instantPreviewGesture
{
    return false;
}

- (TGMessageGroupPositionFlags)visiblePositionFlags
{
    bool hasTopCorners = true;
    bool hasBottomCorners = true;
    
    bool hasCaption = _caption.length > 0 && _positionFlags == TGMessageGroupPositionNone;
    if (hasCaption || (_positionFlags == TGMessageGroupPositionNone && [self _ios6RequiresBubbleBackground]))
        hasBottomCorners = false;
    
    if (((!hasBottomCorners || _context.isFeed) && _authorPeer != nil) || _replyHeader != nil || (_forwardPeer != nil && !_context.isSavedMessages) || _viaUser != nil)
        hasTopCorners = false;
    
    if (_positionFlags != TGMessageGroupPositionNone && _positionFlags != TGMessageGroupPositionUnknown)
    {
        TGMessageGroupPositionFlags position = _positionFlags;
        if (!hasTopCorners)
            position &= ~TGMessageGroupPositionTop;
        if ([self _ios6GroupHasBubbleFooter] || _groupedLayout.caption.length != 0)
            position &= ~TGMessageGroupPositionBottom;
        if (position == TGMessageGroupPositionNone)
            position = TGMessageGroupPositionInside;
        return position;
    }
    
    TGMessageGroupPositionFlags position = TGMessageGroupPositionNone;
    if (!hasTopCorners && !hasBottomCorners)
    {
        position = TGMessageGroupPositionInside;
    }
    else
    {
        position = TGMessageGroupPositionLeft | TGMessageGroupPositionRight;
        if (hasTopCorners)
            position |= TGMessageGroupPositionTop;
        if (hasBottomCorners)
            position |= TGMessageGroupPositionBottom;
    }
    
    return position;
}

- (void)setTemporaryHighlighted:(bool)temporaryHighlighted viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    if (_backgroundModel != nil && _positionFlags == TGMessageGroupPositionNone)
    {
        if (temporaryHighlighted)
            [_backgroundModel setHighlightedIfBound];
        else
            [_backgroundModel clearHighlight];
    }

    if ([_imageModel boundView] != nil)
    {
        if (temporaryHighlighted)
        {
            if (_temporaryHighlightView == nil)
            {
                bool hasBackground = [self hasHeader] || _backgroundModel != nil;
                
                CGFloat inset = !hasBackground ? 1.0f : 0.0f;
                const int smallRadius = !hasBackground ? 3.0f : 3.0f;
                const int bigRadius = hasBackground ? 15.0f : 16.0f;
                
                int topLeftRadius = smallRadius;
                int topRightRadius = smallRadius;
                int bottomLeftRadius = smallRadius;
                int bottomRightRadius = smallRadius;
                
                int position = [self visiblePositionFlags];
                if (position == TGMessageGroupPositionNone)
                    topLeftRadius = topRightRadius = bottomLeftRadius = bottomRightRadius = bigRadius;
                else if (position == TGMessageGroupPositionInside)
                    topLeftRadius = topRightRadius = bottomLeftRadius = bottomRightRadius = smallRadius;
                
                if (position & TGMessageGroupPositionTop && position & TGMessageGroupPositionLeft)
                    topLeftRadius = bigRadius;
                if (position & TGMessageGroupPositionTop && position & TGMessageGroupPositionRight)
                    topRightRadius = bigRadius;
                if (position & TGMessageGroupPositionBottom && position & TGMessageGroupPositionLeft)
                    bottomLeftRadius = bigRadius;
                if (position & TGMessageGroupPositionBottom && position & TGMessageGroupPositionRight)
                    bottomRightRadius = bigRadius;
                
                CGFloat leftMax = MAX(topLeftRadius, bottomLeftRadius);
                CGFloat rightMax = MAX(topRightRadius, bottomRightRadius);
                CGFloat topMax = MAX(topLeftRadius, topRightRadius);
                CGFloat bottomMax = MAX(bottomLeftRadius, bottomRightRadius);
                CGRect rect = CGRectMake(0.0f, 0.0f, leftMax + rightMax, topMax + bottomMax);
                
                UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0f);
                CGContextRef context = UIGraphicsGetCurrentContext();
                CGContextSetFillColorWithColor(context, UIColorRGBA(0xffffff, 0.7f).CGColor);
                
                CGContextMoveToPoint(context, 0.0f, topLeftRadius);
                
                CGContextAddArcToPoint(context, 0.0f, 0.0f, topLeftRadius, 0.0f, topLeftRadius);
                CGContextAddLineToPoint(context, rect.size.width - topRightRadius, 0.0f);
                
                CGContextAddArcToPoint(context, rect.size.width, 0.0f, rect.size.width, topRightRadius, topRightRadius);
                CGContextAddLineToPoint(context, rect.size.width, rect.size.height - bottomRightRadius);
                
                CGContextAddArcToPoint(context, rect.size.width, rect.size.height, rect.size.width - bottomRightRadius, rect.size.height, bottomRightRadius);
                CGContextAddLineToPoint(context, bottomLeftRadius, rect.size.height);
                
                CGContextAddArcToPoint(context, 0.0f, rect.size.height, 0.0f, rect.size.height - bottomLeftRadius, bottomLeftRadius);
                CGContextAddLineToPoint(context, 0.0f, topLeftRadius);
                
                CGContextClosePath(context);
                CGContextFillPath(context);
                
                UIImage *highlightImage = UIGraphicsGetImageFromCurrentImageContext();
                UIEdgeInsets capInsets = UIEdgeInsetsMake(topMax, leftMax, bottomMax, rightMax);
                if ([highlightImage respondsToSelector:@selector(resizableImageWithCapInsets:resizingMode:)])
                    highlightImage = [highlightImage resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch];
                else
                    highlightImage = [highlightImage resizableImageWithCapInsets:capInsets];
                UIGraphicsEndImageContext();
                
                _temporaryHighlightView = [[UIImageView alloc] initWithImage:highlightImage];
                _temporaryHighlightView.frame = CGRectInset([_imageModel boundView].frame, inset, inset);
                [[_imageModel boundView].superview addSubview:_temporaryHighlightView];
            }
        }
        else if (_temporaryHighlightView != nil)
        {
            UIImageView *temporaryView = _temporaryHighlightView;
            [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionAllowAnimatedContent animations:^
            {
                temporaryView.alpha = 0.0f;
            } completion:^(__unused BOOL finished)
            {
                [temporaryView removeFromSuperview];
                
                if (_temporaryHighlightView == temporaryView)
                    _temporaryHighlightView = nil;
            }];
        }
    }
}

- (TGModernImageViewModel *)unsentButtonModel
{
    if (_unsentButtonModel == nil)
    {
        UIImage *image = _context.presentation.images.chatUnsentIcon;
        _unsentButtonModel = [[TGModernImageViewModel alloc] initWithImage:image];
        _unsentButtonModel.frame = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
        _unsentButtonModel.extendedEdges = UIEdgeInsetsMake(6, 6, 6, 6);
        
        _unsentButtonModel.hidden = !(_positionFlags == TGMessageGroupPositionNone || (_positionFlags & TGMessageGroupPositionTop && _positionFlags & TGMessageGroupPositionLeft));
    }
    
    return _unsentButtonModel;
}

- (void)updateMediaAvailability:(bool)mediaIsAvailable viewStorage:(TGModernViewStorage *)__unused viewStorage delayDisplay:(bool)delayDisplay
{
    if (mediaIsAvailable && !_mediaIsAvailable && OGPlatformMediaDownloadsRequireUserAction())
        [_imageModel reloadImage:false];

    _mediaIsAvailable = mediaIsAvailable;
    
    if (mediaIsAvailable || !delayDisplay) {
        [self updateImageOverlay:false];
    }
}

- (void)updateTimestampVisibility:(bool (^)(int32_t))visibilityTest alwaysAnimated:(bool)alwaysAnimated
{
    if (_positionFlags & TGMessageGroupPositionBottom && _positionFlags & TGMessageGroupPositionRight)
    {
        bool currentVisible = visibilityTest(_mid);
        
        int32_t previousMid = _message.mid - 1;
        TGMessageGroupPositionFlags previousFlags = [_groupedLayout positionForMessageId:previousMid];
        bool previousVisible = previousMid != 0 && (previousFlags & TGMessageGroupPositionBottom) ? visibilityTest(previousMid) : true;
        
        int32_t beforePreviousMid = _message.mid - 2;
        TGMessageGroupPositionFlags beforePreviousFlags = [_groupedLayout positionForMessageId:beforePreviousMid];
        bool beforePreviousVisible = beforePreviousMid != 0 && (beforePreviousFlags & TGMessageGroupPositionBottom) ? visibilityTest(beforePreviousMid) : true;
        
        bool timestampHidden = [TGPresentation brandedIOS6Style] || !currentVisible || !previousVisible || !beforePreviousVisible;
        [_imageModel setTimestampHidden:timestampHidden animated:[TGPresentation brandedIOS6Style] ? false : (alwaysAnimated || !timestampHidden)];
    }
}

- (void)updateMediaVisibility
{
    _imageModel.mediaVisible = [_context isMediaVisibleInMessage:_mid peerId:_authorPeerId];
    
    [self updateTimestampVisibility:^bool(int32_t mid) {
        return [_context isMediaVisibleInMessage:mid peerId:_authorPeerId];
    } alwaysAnimated:false];
}

- (void)updateMessageFocus
{
    [self updateTimestampVisibility:^bool(int32_t mid) {
        return ![_context isFocusedOnMessage:mid peerId:_authorPeerId];
    } alwaysAnimated:false];
}

- (NSString *)timestampString {
    NSString *dateText = nil;
    if (debugShowMessageIds)
        dateText = [[NSString alloc] initWithFormat:@"%d", _mid];
    else
        dateText = [TGDateUtils stringForShortTime:_date];
    return dateText;
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];

    NSString *updatedReactionSummary = [TGMessageReactionsModel summaryForMessage:message];
    NSString *updatedChosenReaction = [TGMessageReactionsModel chosenReactionForMessage:message];
    if (_groupedLayout != nil)
    {
        if (_mid == _groupedLayout.mainMessageId)
            [_groupedLayout updateReactionSummary:updatedReactionSummary chosenReaction:updatedChosenReaction messageId:_mid];
        else
        {
            updatedReactionSummary = nil;
            updatedChosenReaction = nil;
        }
    }
    else if (message.groupedId != 0)
    {
        updatedReactionSummary = nil;
        updatedChosenReaction = nil;
    }
    _reactionsModel.messageId = _groupedLayout.mainMessageId != 0 ? _groupedLayout.mainMessageId : message.mid;
    if ([_reactionsModel updateWithSummary:updatedReactionSummary chosenReaction:updatedChosenReaction parent:self viewStorage:viewStorage container:[_imageModel boundView].superview])
    {
        if (sizeUpdated != NULL)
            *sizeUpdated = true;
    }

    NSString *previousCaption = _caption;
    NSString *messageCaption = message.caption;
    NSArray *messageTextCheckingResults = message.textCheckingResults;
    
    if (_nextCaption)
    {
        messageCaption = _nextCaption;
        _nextCaption = nil;
    }

    _messageCaption = [messageCaption copy];
    _messageTextCheckingResults = [messageTextCheckingResults copy];

    bool displaysGroupedCaption = _groupedLayout != nil && [self hasMainPosition];
    NSString *currentCaption = _groupedLayout == nil ? _messageCaption : (displaysGroupedCaption ? _groupedLayout.caption : nil);
    NSArray *currentTextCheckingResults = _groupedLayout == nil ? _messageTextCheckingResults : (displaysGroupedCaption ? _groupedLayout.captionTextCheckingResults : nil);
    
    bool previousEdited = _isEdited;
    if (message.isEdited && (_authorPeer == nil || ![_authorPeer isKindOfClass:[TGConversation class]] || !((TGConversation *)_authorPeer).isChannel || ((TGConversation *)_authorPeer).isChannelGroup)) {
        _isEdited = true;
    }
    
    if (!TGStringCompare(previousCaption, currentCaption) || !TGObjectCompare(_textCheckingResults, currentTextCheckingResults) || previousEdited != _isEdited) {
        _caption = currentCaption;
        _textCheckingResults = currentTextCheckingResults;
        
        if (_positionFlags == TGMessageGroupPositionNone || displaysGroupedCaption)
        {
            bool rebind = false;
            
            if (previousCaption.length == 0 && currentCaption.length != 0) {
                rebind = true;
            } else if (previousCaption.length != 0 && currentCaption.length == 0) {
                rebind = true;
            } else {
                _textModel.text = _caption;
                _textModel.textCheckingResults = currentTextCheckingResults;
                [_contentModel setNeedsSubmodelContentsUpdate];
            }
            
           *sizeUpdated = true;
            
            if (rebind) {
                UIView *container = _imageModel.boundView.superview;
                [self unbindView:viewStorage];
                
                [self setupContentModel:viewStorage];
                
                [self bindViewToContainer:container viewStorage:viewStorage];
                
                [_contentModel setNeedsSubmodelContentsUpdate];
                [_contentModel updateSubmodelContentsIfNeeded];
            } else if (_isEdited != previousEdited) {
                if (!_ignoreEditing && _isEdited && _dateModel != nil) {
                    _editedLabelModel = [[TGModernLabelViewModel alloc] initWithText:TGLocalized(@"Conversation.MessageEditedLabel") textColor:_dateModel.textColor font:[TGModernDateViewModel dateFont] maxWidth:CGFLOAT_MAX];
                    [_contentModel addSubmodel:_editedLabelModel];
                }
            }
        }
    }
    
    bool updated = false;
    TGImageInfo *updatedImageInfo;
    NSString *updatedImageUri = [self updatedImageUriForMessage:message outImageInfo:&updatedImageInfo];
    if (updatedImageUri != nil && ![updatedImageUri isEqualToString:_imageModel.uri])
    {
        [_contentModel setNeedsSubmodelContentsUpdate];
        [self updateImageUri:updatedImageUri];
        
        CGSize imageSize = CGSizeZero;
        CGSize imageOriginalSize = CGSizeMake(1, 1);
        [updatedImageInfo imageUrlForLargestSize:&imageOriginalSize];
        imageSize = imageOriginalSize;
        
        CGSize renderSize = CGSizeZero;
        [TGImageMessageViewModel calculateImageSizesForImageSize:imageSize thumbnailSize:&imageSize renderSize:&renderSize squareAspect:message.messageLifetime > 0 && message.messageLifetime <= 60 && message.layer >= 17 && !_ignoreMessageLifetime];
        
        if (!CGSizeEqualToSize(_originalImageSize, imageSize))
        {
            _animateNextLayout = true;
            _originalImageSize = imageSize;
           *sizeUpdated = true;
        }
        updated = true;
    }
    
    _mid = message.mid;
    _groupedId = message.groupedId;
    TGMessageViewCountContentProperty *viewCount = _message.viewCount;
    if (message.viewCount != nil) {
        viewCount = message.viewCount;
    }
    if (viewCount != message.viewCount) {
        _message = [message copy];
        _message.viewCount = viewCount;
    } else {
        _message = message;
    }
    
    bool byAdmin = [_context isByAdmin:message];
    if (_byAdmin != byAdmin)
    {
        _byAdmin = byAdmin;
        
        if (_byAdmin)
        {
            CTFontRef adminFont = NULL;
            if (iosMajorVersion() >= 7) {
                adminFont = TGIos6CreateCTFontFromUIFont(TGSystemFontOfSize(12.0f));
            } else {
                UIFont *font = TGSystemFontOfSize(12.0f);
                adminFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, nil);
            }
            
            if (_contentModel != nil)
            {
                _adminContentModel = [[TGModernFlatteningViewModel alloc] init];
                _adminContentModel.viewUserInteractionDisabled = true;
                [self insertSubmodel:_adminContentModel aboveSubmodel:_contentModel];
                [_adminContentModel bindViewToContainer:[_imageModel.boundView superview] viewStorage:viewStorage];
                
                _adminModel = [[TGModernTextViewModel alloc] initWithText:TGLocalized(@"Conversation.Admin") font:adminFont];
                _adminModel.textColor = _context.presentation.pallete.chatIncomingDateColor;
                [_adminContentModel addSubmodel:_adminModel];
            }
        }
        else
        {
            [self removeSubmodel:_adminContentModel viewStorage:viewStorage];
            [self removeSubmodel:_adminModel viewStorage:viewStorage];
        }
        
        if (sizeUpdated) {
           *sizeUpdated = true;
        }
    }
    
    bool messageUnread = [_context isMessageUnread:message];
    
    if (updated || _deliveryState != _message.deliveryState || (!_incoming && _read != !messageUnread) || (_messageViews != nil && _messageViews.viewCount != _message.viewCount.viewCount))
    {
        _messageViews = _message.viewCount;
        TGMessageViewModelLayoutConstants const *layoutConstants = TGGetMessageViewModelLayoutConstants();
        
        TGMessageDeliveryState previousDeliveryState = _deliveryState;
        _deliveryState = message.deliveryState;
        
        if (_messageViewsModel != nil) {
            _messageViewsModel.count = _message.viewCount.viewCount;
            _messageViewsModel.hidden = _deliveryState != TGMessageDeliveryStateDelivered;
        }
        
        bool previousRead = _read;
        _read = !messageUnread;
        
        bool hasCaption = _caption.length > 0 && (_positionFlags == TGMessageGroupPositionNone || [self hasMainPosition]);
        if (!hasCaption && _webPageFooterModel == nil)
        {
            [_imageModel setTimestampString:[self timestampString] signatureString:[self signatureString] displayCheckmarks:!_incoming && !(_incomingAppearance && _context.isSavedMessages) && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:_messageViews != nil viewsValue:_messageViews.viewCount animated:!updated];
            [_imageModel setDisplayTimestampProgress:_deliveryState == TGMessageDeliveryStatePending];
        }
        else
        {
            if (_date != (int32_t)message.date && !debugShowMessageIds)
            {
                _date = (int32_t)message.date;
                
                int daytimeVariant = 0;
                NSString *dateText = [TGDateUtils stringForShortTime:(int)message.date daytimeVariant:&daytimeVariant];
                [_dateModel setText:dateText daytimeVariant:daytimeVariant];
            }
        }
        
        if (_deliveryState == TGMessageDeliveryStateDelivered)
        {
            if (_caption.length > 0 || _webPageFooterModel != nil)
            {
                if (_progressModel != nil)
                {
                    [self removeSubmodel:_progressModel viewStorage:viewStorage];
                    _progressModel = nil;
                }
                
                _checkFirstModel.alpha = 1.0f;
                
                if (previousDeliveryState == TGMessageDeliveryStatePending && [_checkFirstModel boundView] != nil)
                {
                    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                    animation.fromValue = @(1.3f);
                    animation.toValue = @(1.0f);
                    animation.duration = 0.1;
                    animation.removedOnCompletion = true;
                    
                    [[_checkFirstModel boundView].layer addAnimation:animation forKey:@"transform.scale"];
                }
                
                if (_read)
                {
                    _checkSecondModel.alpha = 1.0f;
                    
                    if (!previousRead && [_checkSecondModel boundView] != nil)
                    {
                        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                        animation.fromValue = @(1.3f);
                        animation.toValue = @(1.0f);
                        animation.duration = 0.1;
                        animation.removedOnCompletion = true;
                        
                        [[_checkSecondModel boundView].layer addAnimation:animation forKey:@"transform.scale"];
                    }
                }
            }
            
            if (_unsentButtonModel != nil)
            {
                [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                _unsentButtonModel = nil;
            }
        }
        else if (_deliveryState == TGMessageDeliveryStateFailed)
        {
            if (_caption.length > 0 || _webPageFooterModel != nil)
            {
                if (_progressModel != nil)
                {
                    [self removeSubmodel:_progressModel viewStorage:viewStorage];
                    _progressModel = nil;
                }
                
                if (_checkFirstModel != nil)
                {
                    if (_checkFirstEmbeddedInContent)
                    {
                        [_contentModel removeSubmodel:_checkFirstModel viewStorage:viewStorage];
                        [_contentModel setNeedsSubmodelContentsUpdate];
                    }
                    else
                        [self removeSubmodel:_checkFirstModel viewStorage:viewStorage];
                }
                
                if (_checkSecondModel != nil)
                {
                    if (_checkSecondEmbeddedInContent)
                    {
                        [_contentModel removeSubmodel:_checkSecondModel viewStorage:viewStorage];
                        [_contentModel setNeedsSubmodelContentsUpdate];
                    }
                    else
                        [self removeSubmodel:_checkSecondModel viewStorage:viewStorage];
                }
            }
            
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
            if (_caption.length > 0 || _webPageFooterModel != nil)
            {
                if (_progressModel == nil)
                {
                    CGFloat unsentOffset = 0.0f;
                    if (!_incoming && previousDeliveryState == TGMessageDeliveryStateFailed)
                        unsentOffset = 29.0f;
                    
                    _progressModel = [[TGModernClockProgressViewModel alloc] initWithType:_incomingAppearance ? TGModernClockProgressTypeIncomingClock : TGModernClockProgressTypeOutgoingClock];
                    _progressModel.presentation = _context.presentation;
                    _progressModel.frame = CGRectMake(self.frame.size.width - 28 - layoutConstants->rightInset - unsentOffset, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
                    [self addSubmodel:_progressModel];
                    
                    if ([_contentModel boundView] != nil)
                    {
                        [_progressModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                    }
                }
                
                [_contentModel removeSubmodel:_checkFirstModel viewStorage:viewStorage];
                [_contentModel removeSubmodel:_checkSecondModel viewStorage:viewStorage];
                _checkFirstEmbeddedInContent = false;
                _checkSecondEmbeddedInContent = false;
                
                if (![self containsSubmodel:_checkFirstModel] && !_incomingAppearance)
                {
                    [self addSubmodel:_checkFirstModel];
                    
                    if ([_contentModel boundView] != nil)
                        [_checkFirstModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                }
                if (![self containsSubmodel:_checkSecondModel] && !_incomingAppearance)
                {
                    [self addSubmodel:_checkSecondModel];
                    
                    if ([_contentModel boundView] != nil)
                        [_checkSecondModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                }
                
                _checkFirstModel.alpha = 0.0f;
                _checkSecondModel.alpha = 0.0f;
            }
            
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
        
        if ((previousCaption.length == 0) != (_caption.length == 0)) {
            [self updateImageUri:[self updatedImageUri]];
        }
    }
    
    bool isMainModel = [self hasMainPosition];
    _actionButtonModel.hidden = _message.local || (_positionFlags != TGMessageGroupPositionNone && !isMainModel);
    
    TGBotReplyMarkup *replyMarkup = message.replyMarkup != nil && message.replyMarkup.isInline ? message.replyMarkup : nil;
    if (!TGObjectCompare(_replyMarkup, replyMarkup)) {
        _replyMarkup = replyMarkup;
        
        if (_replyButtonsModel == nil) {
            _replyButtonsModel = [[TGMessageReplyButtonsModel alloc] initWithContext:_context];
            id companionHandle = _context.companionHandle;
            int32_t messageId = _mid;
            _replyButtonsModel.buttonActivated = ^(TGBotReplyMarkupButton *button, NSInteger index) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{@"mid": @(messageId), @"command": button.text}];
                if (button.action != nil) {
                    dict[@"action"] = button.action;
                }
                dict[@"index"] = @(index);
                [companionHandle requestAction:@"activateCommand" options:dict];
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

    [_reactionsModel moveToFrontInParent:self viewStorage:viewStorage container:[_imageModel boundView].superview];
}

- (void)dealloc {
    _boundDoubleTapRecognizer.delegate = nil;
    [_boundDoubleTapRecognizer removeTarget:self action:@selector(messageDoubleTapGesture:)];
    _boundBackgroundDoubleTapRecognizer.delegate = nil;
    [_boundBackgroundDoubleTapRecognizer removeTarget:self action:@selector(backgroundDoubleTapGesture:)];
    TGMessageImageViewContainer *imageContainer = (TGMessageImageViewContainer *)[_imageModel boundView];
    if ([imageContainer isKindOfClass:[TGMessageImageViewContainer class]])
        imageContainer.imageView.delegate = nil;
    [self invalidateLifetimeReference];
    [_callbackButtonInProgressDisposable dispose];
}

- (void)_maybeRestructureStateModels:(TGModernViewStorage *)viewStorage
{
    if (!_incoming && [_contentModel boundView] == nil && !_incomingAppearance)
    {
        if (_deliveryState == TGMessageDeliveryStateDelivered)
        {
            if (!_checkFirstEmbeddedInContent)
            {
                if ([self.submodels containsObject:_checkFirstModel])
                {
                    _checkFirstEmbeddedInContent = true;
                    
                    [self removeSubmodel:_checkFirstModel viewStorage:viewStorage];
                    _checkFirstModel.frame = CGRectOffset(_checkFirstModel.frame, -_contentModel.frame.origin.x, -_contentModel.frame.origin.y);
                    [_contentModel addSubmodel:_checkFirstModel];
                }
            }
            
            if (_read && !_checkSecondEmbeddedInContent)
            {
                if ([self.submodels containsObject:_checkSecondModel])
                {
                    _checkSecondEmbeddedInContent = true;
                    
                    [self removeSubmodel:_checkSecondModel viewStorage:viewStorage];
                    _checkSecondModel.frame = CGRectOffset(_checkSecondModel.frame, -_contentModel.frame.origin.x, -_contentModel.frame.origin.y);
                    [_contentModel addSubmodel:_checkSecondModel];
                }
            }
        }
    }
}

- (void)updateProgress:(bool)progressVisible progress:(float)progress viewStorage:(TGModernViewStorage *)__unused viewStorage animated:(bool)animated
{
    [super updateProgress:progressVisible progress:progress viewStorage:viewStorage animated:animated];
    
    bool progressWasVisible = _progressVisible;
    float previousProgress = _progress;
    
    _progress = progress;
    _progressVisible = progressVisible;
    
    bool finalAnimated = ((progressWasVisible && !_progressVisible) || (_progressVisible && ABS(_progress - previousProgress) > FLT_EPSILON)) && animated;
    if (_positionFlags != TGMessageGroupPositionNone && [_message local] && _progress >= 1.0f - FLT_EPSILON)
        finalAnimated = animated;
    
    [self updateImageOverlay:finalAnimated];
}

- (void)updateMessageAttributes
{
    [super updateMessageAttributes];
    
    bool previousRead = _read;
    _read = ![_context isMessageUnread:_message];
    if (previousRead != _read) {
        if (_checkSecondModel != nil) {
            _checkSecondModel.alpha = 1.0f;
            
            if (!previousRead && [_checkSecondModel boundView] != nil) {
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                animation.fromValue = @(1.3f);
                animation.toValue = @(1.0f);
                animation.duration = 0.1;
                animation.removedOnCompletion = true;
                
                [[_checkSecondModel boundView].layer addAnimation:animation forKey:@"transform.scale"];
            }
        } else {
            [_imageModel setTimestampString:[self timestampString] signatureString:[self signatureString] displayCheckmarks:!_incoming && !(_incomingAppearance && _context.isSavedMessages) && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:_messageViews != nil viewsValue:_messageViews.viewCount animated:true];
        }
    }
    
    if (self.isSecret)
    {
        bool isMessageViewed = [_context isSecretMessageViewed:_mid];
        NSTimeInterval messageViewDate = [_context secretMessageViewDate:_mid];
        
        if (_isMessageViewed != isMessageViewed || ABS(_messageViewDate - messageViewDate) > DBL_EPSILON)
        {
            _isMessageViewed = isMessageViewed;
            _messageViewDate = messageViewDate;
            
            [self updateImageOverlay:false];
            
            if (_incoming && ABS(_messageViewDate) > DBL_EPSILON)
                [self _updateViewDateTimerIfVisible];
        }
    }
}

- (void)_updateViewDateTimerIfVisible
{
    [_viewDateTimer invalidate];
    _viewDateTimer = nil;
    
    if (_isMessageViewed && _incoming && ABS(_messageViewDate) > DBL_EPSILON && _imageModel.boundView != nil)
    {
        [_imageModel setAdditionalDataString:[self defaultAdditionalDataString]];
        [self updateImageOverlay:true];
        
        _viewDateTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(_updateViewDateTimerIfVisible) interval:0.5 repeat:false runLoopModes:NSRunLoopCommonModes];
    }
}

- (void)_invalidateViewDateTimer
{
    [_viewDateTimer invalidate];
    _viewDateTimer = nil;
}

- (void)updateImageOverlay:(bool)animated
{
    _instantPreviewTouchAreaModel.viewUserInteractionDisabled = !_mediaIsAvailable || _progressVisible;
    
    if (_progressVisible)
    {
        if (_positionFlags != TGMessageGroupPositionNone && [_message local] && _progress >= 1.0f - FLT_EPSILON)
        {
            [_imageModel setOverlayType:TGMessageImageViewOverlayCompleted animated:animated];
        }
        else
        {                
            [_imageModel setOverlayType:TGMessageImageViewOverlayProgress animated:false];
            [_imageModel setProgress:_progress animated:animated];
        }
    }
    else if (!_mediaIsAvailable)
    {
        if (_canDownload) {
            [_imageModel setOverlayType:TGMessageImageViewOverlayDownload animated:false];
        } else {
            [_imageModel setOverlayType:TGMessageImageViewOverlayNone animated:false];
        }
        [_imageModel setProgress:0.0f animated:false];
    }
    else
    {
        if (self.isSecret && _isMessageViewed && _incoming && ABS(_messageViewDate) > DBL_EPSILON)
        {
            NSTimeInterval endTime = _messageViewDate + _messageLifetime;
            int remainingSeconds = MAX(0, (int)(endTime - CFAbsoluteTimeGetCurrent()));
            
            [_imageModel setSecretProgress:(CGFloat)remainingSeconds / (CGFloat)_messageLifetime completeDuration:_messageLifetime animated:animated];
            [_imageModel setOverlayType:TGMessageImageViewOverlaySecretProgress];
        }
        else
            [_imageModel setOverlayType:[self defaultOverlayActionType] animated:animated];
    }
}

- (void)imageDataInvalidated:(NSString *)imageUrl
{
    if ([_legacyThumbnailCacheUri isEqualToString:imageUrl])
        [_imageModel reloadImage:false];
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    _boundOffset = itemPosition;
    
    [_backgroundModel bindViewToContainer:container viewStorage:viewStorage];
    [_backgroundModel boundView].frame = CGRectOffset([_backgroundModel boundView].frame, itemPosition.x, itemPosition.y);
    
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    
    [_imageModel bindViewToContainer:container viewStorage:viewStorage];
    [_imageModel boundView].frame = CGRectOffset([_imageModel boundView].frame, itemPosition.x, itemPosition.y);
    ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView.delegate = self;

    [self _ios6EnsureSingleImageGloss];
    [_reactionsModel bringToFrontInContainer:container];
    
    [_replyHeaderModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x + _contentModel.frame.origin.x + _replyHeaderModel.frame.origin.x, itemPosition.y + _contentModel.frame.origin.y + _replyHeaderModel.frame.origin.y)];
    
    [_replyButtonsModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x, itemPosition.y)];
    [self subscribeToCallbackButtonInProgress];
}

- (void)subscribeToCallbackButtonInProgress {
    if (_replyButtonsModel != nil && !_callbackButtonInProgressSubscribed) {
        _callbackButtonInProgressSubscribed = true;
        TGMessageReplyButtonsModel *replyButtonsModel = _replyButtonsModel;
        int32_t messageId = _mid;
        [_callbackButtonInProgressDisposable setDisposable:[[[_context callbackInProgress] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next) {
            if (next != nil) {
                if ([next[@"mid"] intValue] == messageId) {
                    [replyButtonsModel setButtonIndexInProgress:[next[@"buttonIndex"] intValue]];
                } else {
                    [replyButtonsModel setButtonIndexInProgress:NSNotFound];
                }
            } else {
                [replyButtonsModel setButtonIndexInProgress:NSNotFound];
            }
        }]];
    }
}

- (CGRect)effectiveContentFrame
{
    if (_backgroundModel != nil && _positionFlags == TGMessageGroupPositionNone)
        return _backgroundModel.frame;
    
    return _imageModel.frame;
}

- (CGRect)fullContentFrame
{
    if (_backgroundModel != nil)
        return _backgroundModel.frame;
    
    return _imageModel.frame;
}

- (UIView *)referenceViewForImageTransition
{
    return [_imageModel boundView];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    _boundOffset = CGPointZero;
    
    _boundToContainer = true;
    
    [self _maybeRestructureStateModels:viewStorage];
    
    [self updateEditingState:nil viewStorage:nil animationDelay:-1.0];
    
    [super bindViewToContainer:container viewStorage:viewStorage];
    [self _ios6EnsureSingleImageGloss];
    [_reactionsModel bringToFrontInContainer:container];
    
    [_replyHeaderModel bindSpecialViewsToContainer:_contentModel.boundView viewStorage:viewStorage atItemPosition:CGPointMake(_replyHeaderModel.frame.origin.x, _replyHeaderModel.frame.origin.y)];
    
    _boundDoubleTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(messageDoubleTapGesture:)];
    _boundDoubleTapRecognizer.delegate = self;
    [[_imageModel boundView] addGestureRecognizer:_boundDoubleTapRecognizer];
    
    if (_backgroundModel != nil)
    {
        _boundBackgroundDoubleTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(backgroundDoubleTapGesture:)];
        _boundBackgroundDoubleTapRecognizer.delegate = self;
        [[_backgroundModel boundView] addGestureRecognizer:_boundBackgroundDoubleTapRecognizer];
    }
    
    if (_unsentButtonModel != nil)
    {
        _unsentButtonTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unsentButtonTapGesture:)];
        [[_unsentButtonModel boundView] addGestureRecognizer:_unsentButtonTapRecognizer];
    }
    
    _imageModel.mediaVisible = [_context isMediaVisibleInMessage:_mid peerId:_authorPeerId];
    [_imageModel setOverlayDiameter:_positionFlags != TGMessageGroupPositionNone ? 32.0f : 50.0f];
    
    ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView.delegate = self;
    
    [self _updateViewDateTimerIfVisible];
    
    if (_actionButtonModel != nil) {
        [(TGModernButtonView *)_actionButtonModel.boundView addTarget:self action:@selector(actionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [(UIButton *)[_groupCheckAreaModel boundView] addTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [(UIButton *)[_groupCheckButtonModel boundView] addTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    [self subscribeToCallbackButtonInProgress];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    [self clearLinkSelection];
    
    _boundToContainer = false;
    
    _boundOffset = CGPointZero;
    
    [[_imageModel boundView] removeGestureRecognizer:_boundDoubleTapRecognizer];
    _boundDoubleTapRecognizer.delegate = nil;
    [_boundDoubleTapRecognizer removeTarget:self action:@selector(messageDoubleTapGesture:)];
    _boundDoubleTapRecognizer = nil;
    
    ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView.delegate = nil;
    
    if (_backgroundModel != nil)
    {
        [[_backgroundModel boundView] removeGestureRecognizer:_boundBackgroundDoubleTapRecognizer];
        _boundBackgroundDoubleTapRecognizer.delegate = nil;
        [_boundBackgroundDoubleTapRecognizer removeTarget:self action:@selector(backgroundDoubleTapGesture:)];
        _boundBackgroundDoubleTapRecognizer = nil;
    }
    
    if (_temporaryHighlightView != nil)
    {
        [_temporaryHighlightView removeFromSuperview];
        _temporaryHighlightView = nil;
    }

    if (_ios6SingleImageGlossView != nil)
    {
        [_ios6SingleImageGlossView removeFromSuperview];
        _ios6SingleImageGlossView = nil;
        _ios6SingleImageGlossLayer = nil;
        _ios6SingleImageGlossRimLayer = nil;
    }
    
    if (_unsentButtonModel != nil)
    {
        [[_unsentButtonModel boundView] removeGestureRecognizer:_unsentButtonTapRecognizer];
        _unsentButtonTapRecognizer = nil;
    }
    
    [self _invalidateViewDateTimer];
    
    if (_actionButtonModel != nil)
    {
        [(TGModernButtonView *)_actionButtonModel.boundView removeTarget:self action:@selector(actionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
    [(UIButton *)[_groupCheckAreaModel boundView] removeTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [(UIButton *)[_groupCheckButtonModel boundView] removeTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    
    [super unbindView:viewStorage];
    
    [_callbackButtonInProgressDisposable setDisposable:nil];
    _callbackButtonInProgressSubscribed = false;
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan)
    {
        [self clearLinkSelection];
    }
    
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if ([self instantPreviewGesture])
        {
            [_context.companionHandle requestAction:@"closeMediaRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        }
        else
        {
            if (recognizer.longTapped)
            {
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            }
            else
            {
                if (_mediaIsAvailable)
                {
                    [self activateMedia:[self isInstant]];
                }
                else
                    [_context.companionHandle requestAction:@"mediaDownloadRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            }
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateCancelled)
    {
        [_context.companionHandle requestAction:@"closeMediaRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
    }
}

- (void)backgroundDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan)
    {
        [self clearLinkSelection];
    }
    
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        CGPoint point = [recognizer locationInView:[_contentModel boundView]];
        NSString *linkCandidate = [_textModel linkAtPoint:CGPointMake(point.x - _textModel.frame.origin.x, point.y - _textModel.frame.origin.y) regionData:NULL];
        
        bool insideBackground = [self insideBackground:[recognizer locationInView:recognizer.view]];
        
        if (recognizer.longTapped)
        {
            if (linkCandidate != nil)
                [_context.companionHandle requestAction:@"openLinkWithOptionsRequested" options:@{@"url": linkCandidate}];
            else if (_positionFlags != TGMessageGroupPositionNone && insideBackground)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"groupedId": @(_message.groupedId), @"peerId": @(_authorPeerId)}];
            else
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        }
        else if (recognizer.doubleTapped)
        {
            if (_positionFlags != TGMessageGroupPositionNone && insideBackground)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"groupedId": @(_message.groupedId), @"peerId": @(_authorPeerId)}];
            else
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        }
        else if (linkCandidate != nil)
            [_context.companionHandle requestAction:@"openLinkRequested" options:@{@"url": linkCandidate, @"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        else if (_replyHeaderModel && CGRectContainsPoint(_replyHeaderModel.frame, point))
            [_context.companionHandle requestAction:@"navigateToMessage" options:@{@"mid": @(_replyMessageId), @"sourceMid": @(_mid)}];
        else if (_viaUserModel != nil && CGRectContainsPoint(_viaUserModel.frame, point)) {
            [_context.companionHandle requestAction:@"useContextBot" options:@{@"uid": @((int32_t)_viaUser.uid), @"username": _viaUser.userName == nil ? @"" : _viaUser.userName}];
        }
        else if (_forwardedHeaderModel && CGRectContainsPoint(_forwardedHeaderModel.frame, point)) {
            if (_viaUser != nil && [_forwardedHeaderModel linkAtPoint:CGPointMake(point.x - _forwardedHeaderModel.frame.origin.x, point.y - _forwardedHeaderModel.frame.origin.y) regionData:NULL]) {
                [_context.companionHandle requestAction:@"useContextBot" options:@{@"uid": @((int32_t)_viaUser.uid), @"username": _viaUser.userName == nil ? @"" : _viaUser.userName}];
            } else {
                if (TGPeerIdIsChannel(_forwardedPeerId)) {
                    [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(_forwardedPeerId), @"messageId": @(_forwardedMessageId)}];
                } else {
                    [_context.companionHandle requestAction:@"userAvatarTapped" options:@{@"uid": @((int32_t)_forwardedPeerId)}];
                }
            }
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]])
        return [super gestureRecognizerShouldBegin:gestureRecognizer];
    
    UIView *imageView = ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView;
    if (imageView != nil)
    {
        UIView *hitTestResult = [imageView hitTest:[gestureRecognizer locationInView:imageView] withEvent:nil];
        if ([hitTestResult isKindOfClass:[UIControl class]])
            return false;
        
        return true;
    }
    
    return false;
}

- (void)unsentButtonTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_context.companionHandle requestAction:@"showUnsentMessageMenu" options:@{@"mid": @(_mid)}];
    }
}

- (void)messageImageViewActionButtonPressed:(TGMessageImageView *)messageImageView withAction:(TGMessageImageViewActionType)action
{
    if (messageImageView == ((TGMessageImageViewContainer *)[_imageModel boundView]).imageView)
    {
        if (action == TGMessageImageViewActionCancelDownload)
            [self cancelMediaDownload];
        else
            [self actionButtonPressed];
    }
}

- (void)actionButtonPressed
{
    if (_mediaIsAvailable)
    {
        if (![self instantPreviewGesture])
        {
            [self activateMedia:[self isInstant]];
        }
    }
    else
        [_context.companionHandle requestAction:@"mediaDownloadRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
}

- (void)activateMedia
{
    [self activateMedia:false];
}

- (void)activateMedia:(bool)instant
{
    if (_previewEnabled)
        [_context.companionHandle requestAction:@"openMediaRequested" options:@{@"mid": @(_mid), @"instant": @(instant), @"peerId": @(_authorPeerId)}];
}

- (void)deactivateMedia:(bool)instant
{
    [_context.companionHandle requestAction:@"closeMediaRequested" options:@{@"mid": @(_mid), @"instant": @(instant), @"peerId": @(_authorPeerId)}];
}

- (void)cancelMediaDownload
{
    [_context.companionHandle requestAction:@"mediaProgressCancelRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
}

- (bool)gestureRecognizerShouldHandleLongTap:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer == _boundDoubleTapRecognizer)
        return ![self instantPreviewGesture];
    
    return true;
}

- (void)gestureRecognizer:(TGDoubleTapGestureRecognizer *)recognizer didBeginAtPoint:(CGPoint)point
{
    if (recognizer == _boundBackgroundDoubleTapRecognizer)
        [self updateLinkSelection:point];
}

- (void)gestureRecognizerDidFail:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    [self clearLinkSelection];
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)recognizer shouldFailTap:(CGPoint)__unused point
{
    if (recognizer == _boundDoubleTapRecognizer)
        return 3;
    
    if (recognizer == _boundBackgroundDoubleTapRecognizer)
    {
        CGPoint convertedPoint = [recognizer locationInView:[_contentModel boundView]];
        if (([_textModel linkAtPoint:CGPointMake(convertedPoint.x - _textModel.frame.origin.x, convertedPoint.y - _textModel.frame.origin.y) regionData:NULL] != nil || (_replyHeaderModel && CGRectContainsPoint(_replyHeaderModel.frame, convertedPoint)) || (_forwardedHeaderModel && CGRectContainsPoint(_forwardedHeaderModel.frame, convertedPoint)) ||
             (_viaUserModel && CGRectContainsPoint(_viaUserModel.frame, convertedPoint))))
            return 3;
    }

    return 0;
}

- (void)doubleTapGestureRecognizerSingleTapped:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
}

- (bool)gestureRecognizerShouldLetScrollViewStealTouches:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (bool)gestureRecognizerShouldFailOnMove:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer == _boundDoubleTapRecognizer)
        return ![self instantPreviewGesture];
        
    return true;
}

- (void)setCollapseFlags:(int)collapseFlags
{
    if (_collapseFlags != collapseFlags)
    {
        _collapseFlags = collapseFlags;
        if (!(collapseFlags & TGModernConversationItemCollapseBottom) && [_authorPeer isKindOfClass:[TGConversation class]]) {
            [_backgroundModel setPartialMode:false];
        } else {
            [_backgroundModel setPartialMode:collapseFlags & TGModernConversationItemCollapseBottom];
        }
    }
}

- (bool)hasMainPosition
{
    return (_positionFlags & TGMessageGroupPositionLeft && _positionFlags & TGMessageGroupPositionTop);
}

- (void)setPositionFlags:(int)positionFlags
{
    int previousFlags = _positionFlags;
    if (_positionFlags != positionFlags)
    {
        _positionFlags = positionFlags;
        
        bool groupHasCaption = _groupedLayout != nil && _groupedLayout.caption.length != 0;
        if (_backgroundModel != nil || groupHasCaption || (positionFlags != TGMessageGroupPositionNone && !(positionFlags & TGMessageGroupPositionBottom && positionFlags & TGMessageGroupPositionRight)))
            _imageModel.timestampHidden = true;
        else
            _imageModel.timestampHidden = false;
        
        _editingCheckButtonGrowTransition = positionFlags != TGMessageGroupPositionNone;
        [_imageModel setTimestampUnlimitedWidth:(positionFlags & TGMessageGroupPositionBottom && positionFlags & TGMessageGroupPositionRight)];
        
        bool isMainModel = [self hasMainPosition];
        _avatarModel.hidden = (positionFlags != TGMessageGroupPositionNone && !isMainModel);
        _actionButtonModel.hidden = _message.local || (positionFlags != TGMessageGroupPositionNone && !isMainModel);
        _unsentButtonModel.hidden = !(_positionFlags == TGMessageGroupPositionNone || (_positionFlags & TGMessageGroupPositionTop && _positionFlags & TGMessageGroupPositionLeft));
        
        bool hadNoPosition = previousFlags == TGMessageGroupPositionNone || previousFlags == TGMessageGroupPositionUnknown;
        bool switchingToNoPosition = positionFlags == TGMessageGroupPositionNone;
        bool changingPosition = (previousFlags != TGMessageGroupPositionNone && positionFlags != TGMessageGroupPositionNone);
        if (hadNoPosition || switchingToNoPosition || changingPosition)
        {
            TGModernViewStorage *viewStorage = [[TGModernViewStorage alloc] init];
            UIView *container = _imageModel.boundView.superview;
            [self unbindView:viewStorage];
            
            bool hadContentModel = _contentModel;
            [self setupContentModel:viewStorage];
            if (_contentModel != nil)
            {
                [_contentModel setNeedsSubmodelContentsUpdate];
                if (!hadContentModel || (previousFlags != TGMessageGroupPositionNone && _positionFlags == TGMessageGroupPositionNone))
                    _skipContentModelAnimation = true;
            }
            if (container != nil)
                [self bindViewToContainer:container viewStorage:viewStorage];
        }
    }
    
    [_imageModel setOverlayDiameter:positionFlags != TGMessageGroupPositionNone ? 32.0f : 50.0f];
}

- (void)setGroupedLayout:(TGMessageGroupedLayout *)groupedLayout
{
    _groupedLayout = groupedLayout;
    
    TGMessageGroupPositionFlags position = [groupedLayout positionForMessageId:_message.mid];
    bool isMainModel = groupedLayout == nil || ((position & TGMessageGroupPositionTop) && (position & TGMessageGroupPositionLeft));
    NSString *displayCaption = groupedLayout == nil ? _messageCaption : (isMainModel ? groupedLayout.caption : nil);
    NSArray *displayTextCheckingResults = groupedLayout == nil ? _messageTextCheckingResults : (isMainModel ? groupedLayout.captionTextCheckingResults : nil);
    bool captionChanged = !TGStringCompare(_caption, displayCaption) || !TGObjectCompare(_textCheckingResults, displayTextCheckingResults);
    _caption = [displayCaption copy];
    _textCheckingResults = [displayTextCheckingResults copy];
    NSString *groupReactionSummary = groupedLayout == nil ? [TGMessageReactionsModel summaryForMessage:_message] : (isMainModel ? groupedLayout.reactionSummary : nil);
    NSString *groupChosenReaction = groupedLayout == nil ? [TGMessageReactionsModel chosenReactionForMessage:_message] : (isMainModel ? groupedLayout.chosenReaction : nil);
    _reactionsModel.messageId = groupedLayout.mainMessageId != 0 ? groupedLayout.mainMessageId : _mid;
    [_reactionsModel updateWithSummary:groupReactionSummary chosenReaction:groupChosenReaction parent:self viewStorage:nil container:[_imageModel boundView].superview];

    if (_positionFlags == position && isMainModel && captionChanged && position != TGMessageGroupPositionUnknown)
    {
        TGModernViewStorage *viewStorage = [[TGModernViewStorage alloc] init];
        UIView *container = _imageModel.boundView.superview;
        [self unbindView:viewStorage];
        [self setupContentModel:viewStorage];
        if (container != nil)
            [self bindViewToContainer:container viewStorage:viewStorage];
    }

    if (_positionFlags == position && isMainModel && _contentModel != nil)
    {
        if (self.frame.size.width > FLT_EPSILON)
            [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
    }
}

- (CGSize)contentSizeForContainerSize:(CGSize)containerSize needsContentsUpdate:(bool *)needsContentsUpdate infoWidth:(CGFloat)infoWidth {
    int layoutFlags = TGReusableLabelLayoutMultiline | TGReusableLabelLayoutHighlightLinks;
    
    if (_context.commandsEnabled || _isBot)
        layoutFlags |= TGReusableLabelLayoutHighlightCommands;
    
    CGFloat textTrailingWidth = _webPageFooterModel == nil ? infoWidth : 0.0f;
    bool updateContents = [_textModel layoutNeedsUpdatingForContainerSize:containerSize additionalTrailingWidth:textTrailingWidth layoutFlags:layoutFlags];
    _textModel.layoutFlags = layoutFlags;
    _textModel.additionalTrailingWidth = textTrailingWidth;
    if (updateContents)
        [_textModel layoutForContainerSize:containerSize];
    
    if (needsContentsUpdate != NULL && updateContents)
       *needsContentsUpdate = true;
    
    CGSize size = _textModel.frame.size;
    
    if (_webPageFooterModel != nil) {
        bool webpageNeedsContentsUpdate = false;
        CGSize webpageSize = [_webPageFooterModel contentSizeForContainerSize:containerSize contentSize:containerSize infoWidth:infoWidth needsContentsUpdate:&webpageNeedsContentsUpdate];
        if (needsContentsUpdate != NULL && webpageNeedsContentsUpdate)
            *needsContentsUpdate = true;
        size.height += webpageSize.height;
        if (_caption.length == 0) {
            size.height -= 19.0f;
        }
    }
    
    return size;
}

- (bool)hasHeader
{
    return (_positionFlags == TGMessageGroupPositionNone && (_replyHeaderModel != nil || _forwardedHeaderModel)) || (_positionFlags != TGMessageGroupPositionNone && (_replyHeader != nil || (_forwardPeer != nil && !_context.isSavedMessages) || (_authorPeer != nil && _context.isFeed)));
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    if (_positionFlags != TGMessageGroupPositionUnknown && (_backgroundModel != nil) != [self _requiresContentModel])
    {
        TGModernViewStorage *viewStorage = [[TGModernViewStorage alloc] init];
        UIView *container = _imageModel.boundView.superview;
        if (container != nil)
            [self unbindView:viewStorage];
        [self setupContentModel:viewStorage];
        if (container != nil)
            [self bindViewToContainer:container viewStorage:viewStorage];
        [self updateImageUri:[self updatedImageUri]];
    }

    bool isPost = _authorPeer != nil && [_authorPeer isKindOfClass:[TGConversation class]];
    bool classicIOS6Style = [TGPresentation classicIOS6Style];
    
    TGMessageViewModelLayoutConstants const *layoutConstants = TGGetMessageViewModelLayoutConstants();
    
    CGFloat topSpacing = (_collapseFlags & TGModernConversationItemCollapseTop) ? layoutConstants->topInsetCollapsed : layoutConstants->topInset;
    CGFloat bottomSpacing = (_collapseFlags & TGModernConversationItemCollapseBottom) ? layoutConstants->bottomInsetCollapsed : layoutConstants->bottomInset;
    bool mediaReactions = [self _mediaReactionsInBubble] && _backgroundModel != nil;
    
    if (isPost) {
        topSpacing = layoutConstants->topPostInset;
        bottomSpacing = layoutConstants->bottomPostInset;
    }
    
    CGSize headerSize = CGSizeZero;
    
    CGSize contentSize = _imageModel.frame.size;
    if (self.groupedLayout != nil)
        contentSize = [self.groupedLayout dimensions];
    else
    {
        contentSize = _originalImageSize;
        if (classicIOS6Style && [[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad)
        {
            bool mediaHasText = _caption.length != 0 || _webPageFooterModel != nil;
            CGFloat targetMediaWidth = floorf(containerSize.width * (mediaHasText ? 0.70f : 0.50f));
            if (contentSize.width > FLT_EPSILON && fabs(contentSize.width - targetMediaWidth) > FLT_EPSILON)
            {
                CGFloat scale = targetMediaWidth / contentSize.width;
                contentSize = CGSizeMake(targetMediaWidth, ceilf(contentSize.height * scale));
            }
        }
        else
            contentSize = [self _captionFittedMediaSize:contentSize];
    }
    
    bool updated = fabs(_imageModel.frame.size.width - contentSize.width) > FLT_EPSILON || fabs(_imageModel.frame.size.height - contentSize.height) > FLT_EPSILON;
    bool hasHeader = [self hasHeader];
    bool hasCaption = _caption.length > 0 && (_positionFlags == TGMessageGroupPositionNone || [self hasMainPosition]);
    
    if (hasHeader || hasCaption || _authorNameModel != nil || _viaUserModel != nil || _webPageFooterModel != nil)
    {
        topSpacing += 3.0f - TGScreenPixel;
        bottomSpacing += 6.0f;
        
        if (_authorNameModel != nil)
        {
            CGFloat maxWidth = contentSize.width - 11.0f;
            CGFloat maxNameWidth = _viaUserModel == nil ? maxWidth : (maxWidth - 40.0f);
            
            if (_authorNameModel.frame.size.width < FLT_EPSILON || updated) {
                [_authorNameModel layoutForContainerSize:CGSizeMake(maxNameWidth, 0.0f)];
            }
            
            CGRect authorNameFrame = _authorNameModel.frame;
            authorNameFrame.origin = CGPointMake(3.0f, 1.0f + TGScreenPixel);
            _authorNameModel.frame = authorNameFrame;
            
            headerSize = CGSizeMake(_authorNameModel.frame.size.width, _authorNameModel.frame.size.height + 1.0f);
            
            if (_viaUserModel != nil) {
                [_viaUserModel layoutForContainerSize:CGSizeMake(maxWidth - _authorNameModel.frame.size.width, 0.0f)];
                CGRect viaUserFrame = _viaUserModel.frame;
                viaUserFrame.origin = CGPointMake(CGRectGetMaxX(_authorNameModel.frame) + 4.0f, 1.0f + TGScreenPixel);
                _viaUserModel.frame = viaUserFrame;
                
                headerSize.width += viaUserFrame.size.width + 4.0f;
            }
            
            if ((_replyHeaderModel == nil && _forwardedHeaderModel == nil)) {
                if (_caption.length > 0 || _webPageFooterModel != nil) {
                    headerSize.height += 7.0f;
                } else {
                    headerSize.height += 4.0f;
                }
            }
            
            if (_adminModel != nil) {
                [_adminModel layoutForContainerSize:CGSizeMake(maxWidth - _authorNameModel.frame.size.width - _viaUserModel.frame.size.width, CGFLOAT_MAX)];
                [_adminContentModel setNeedsSubmodelContentsUpdate];
            }
        } else if (_viaUserModel != nil) {
            [_viaUserModel layoutForContainerSize:CGSizeMake(320.0f - 80.0f - (_hasAvatar ? 38.0f : 0.0f), 0.0f)];
            
            CGRect viaUserFrame = _viaUserModel.frame;
            viaUserFrame.origin = CGPointMake(1.0f, 1.0f + TGScreenPixel);
            _viaUserModel.frame = viaUserFrame;
            
            headerSize = CGSizeMake(_viaUserModel.frame.size.width, _viaUserModel.frame.size.height + 1.0f);
            
            if ((_replyHeaderModel == nil && _forwardedHeaderModel == nil)) {
                if (_caption.length > 0 || _webPageFooterModel != nil) {
                    headerSize.height += 7.0f;
                } else {
                    headerSize.height += 4.0f;
                }
            }
        }
        
        if (_forwardedHeaderModel != nil)
        {
            if (_forwardedHeaderModel.frame.size.width < FLT_EPSILON || updated)
                [_forwardedHeaderModel layoutForContainerSize:CGSizeMake(contentSize.width - 11.0f, 0.0f)];
            
            CGRect forwardedHeaderFrame = _forwardedHeaderModel.frame;
            forwardedHeaderFrame.origin = CGPointMake(4.0f - TGScreenPixel, (_authorNameModel != nil ? 2.0f : 2.0f) + headerSize.height);
            _forwardedHeaderModel.frame = forwardedHeaderFrame;
            
            headerSize.height += forwardedHeaderFrame.size.height + 6;
            headerSize.width = MAX(headerSize.width, forwardedHeaderFrame.size.width + 4.0f);
        }
        
        if (_replyHeaderModel != nil)
        {
            if (_replyHeaderModel.frame.size.width < FLT_EPSILON || updated)
                [_replyHeaderModel layoutForContainerSize:CGSizeMake(contentSize.width - 11.0f, 0.0f)];
            
            CGRect replyHeaderFrame = _replyHeaderModel.frame;
            replyHeaderFrame.origin = CGPointMake(4.0f - TGScreenPixel, headerSize.height + 1.0f);
            _replyHeaderModel.frame = replyHeaderFrame;
            
            headerSize.height += replyHeaderFrame.size.height + 6;
            headerSize.width = MAX(headerSize.width, replyHeaderFrame.size.width + 4.0f);
        }
    }
    
    CGFloat avatarOffset = 0.0f;
    if (_hasAvatar)
        avatarOffset = 38.0f;
    
    CGFloat unsentOffset = 0.0f;
    if (!_incoming && _deliveryState == TGMessageDeliveryStateFailed)
        unsentOffset = 29.0f;
    
    CGRect imageFrame = _imageModel.frame;
    CGFloat leftOffset = _incomingAppearance ? (avatarOffset + layoutConstants->leftImageInset) : (containerSize.width - contentSize.width - layoutConstants->rightImageInset - unsentOffset);
    CGPoint layoutOrigin = CGPointMake(leftOffset, topSpacing + (isPost ? 2.0f : 0.0f));
    if (self.groupedLayout != nil)
    {
        if (!_editing && fabs(_replyPanOffset) > FLT_EPSILON)
            layoutOrigin.x += _replyPanOffset;
        
        CGRect inGroupFrame = [self.groupedLayout frameForMessageId:_message.mid];
        CGPoint mediaOrigin = layoutOrigin;
        if (![self hasMainPosition])
        {
            if (self.groupedLayout.hasMediaOrigin)
                mediaOrigin = CGPointMake(self.groupedLayout.mediaOrigin.x + (layoutOrigin.x - leftOffset), self.groupedLayout.mediaOrigin.y);
            else
                mediaOrigin = CGPointMake(layoutOrigin.x + _groupedMediaOffsetX, layoutOrigin.y + _groupedMediaOffsetY);
        }
        imageFrame = CGRectMake(mediaOrigin.x + inGroupFrame.origin.x, mediaOrigin.y + inGroupFrame.origin.y, inGroupFrame.size.width, inGroupFrame.size.height);
        
        TGMessageGroupPositionFlags visiblePosition = [self visiblePositionFlags];
        bool insideGroupBubble = [self _groupHasBubble];
        if (_imagePosition != visiblePosition || _imageInsideGroupBubble != insideGroupBubble || fabs(_imageSize.width - imageFrame.size.width) > FLT_EPSILON || fabs(_imageSize.height - imageFrame.size.height) > FLT_EPSILON)
        {
            _imageSize = imageFrame.size;
            _imagePosition = visiblePosition;
            _imageInsideGroupBubble = insideGroupBubble;
            [self updateImageUri:[self updatedImageUri]];
        }
        
        if (_incomingAppearance && _editing)
            imageFrame.origin.x += 42.0f;
        
        if (hasHeader && [self hasMainPosition])
        {
            if (_incomingAppearance)
                imageFrame.origin.x += 2.0f;
            else
                imageFrame.origin.x -= 2.0f;
            
            imageFrame.origin.y += headerSize.height;
        }
    }
    else
    {
        imageFrame = CGRectMake(_incomingAppearance ? (avatarOffset + layoutConstants->leftImageInset) : (containerSize.width - contentSize.width - layoutConstants->rightImageInset - unsentOffset), topSpacing + (isPost ? 2.0f : 0.0f), contentSize.width, contentSize.height);
        if (_incomingAppearance && _editing)
        {
            imageFrame.origin.x += 42.0f;
            
            if (_temporaryHighlightView != nil)
            {
                CGFloat inset = _backgroundModel == nil ? 1.0f : 0.0f;
                _temporaryHighlightView.frame = CGRectInset(imageFrame, inset, inset);
            }
        }
        
        if (!_editing && fabs(_replyPanOffset) > FLT_EPSILON)
            imageFrame.origin.x += _replyPanOffset;
        
        if (_authorNameModel != nil || _replyHeaderModel != nil || _forwardedHeaderModel || _caption.length > 0 || _viaUserModel != nil || _webPageFooterModel != nil)
        {
            if (_incomingAppearance)
                imageFrame.origin.x += 2.0f;
            else
                imageFrame.origin.x -= 2.0f;
            
            imageFrame.origin.y += headerSize.height;
        }
        
        if (_imagePosition != TGMessageGroupPositionNone || _imageSize.width > FLT_EPSILON)
        {
            _imageSize = CGSizeZero;
            _imagePosition = TGMessageGroupPositionNone;
            _imageInsideGroupBubble = false;
            [self updateImageUri:[self updatedImageUri]];
        }
        
        layoutOrigin = imageFrame.origin;
        contentSize = imageFrame.size;
    }

    CGRect captionMediaFrame = imageFrame;
    if (self.groupedLayout != nil)
    {
        CGRect inGroupFrame = [self.groupedLayout frameForMessageId:_message.mid];
        captionMediaFrame = CGRectMake(imageFrame.origin.x - inGroupFrame.origin.x,
            imageFrame.origin.y - inGroupFrame.origin.y,
            self.groupedLayout.dimensions.width,
            self.groupedLayout.dimensions.height);
    }

    CGFloat classicMediaBubbleExtraWidth = classicIOS6Style ? 4.0f : 0.0f;
    CGFloat classicCaptionBottomInset = classicIOS6Style && hasCaption ? 4.0f : 0.0f;
    CGRect displayedImageFrame = imageFrame;
    if (classicIOS6Style && hasCaption && self.groupedLayout == nil)
        displayedImageFrame.origin.x += _incomingAppearance ? (2.0f * TGScreenPixel) : (-2.0f * TGScreenPixel);
    
    if (_animateNextLayout)
    {
        _animateNextLayout = false;
        [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 | UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionLayoutSubviews animations:^{
            _imageModel.frame = displayedImageFrame;
        } completion:nil];
    }
    else
    {
        _imageModel.frame = displayedImageFrame;
    }
    [self _ios6UpdateSingleImageGlossFrame];

    CGSize contentContainerSize = CGSizeMake(contentSize.width, 0.0f);
    bool standardCaptionLayout = hasCaption && ![TGPresentation brandedIOS6Style] && !mediaReactions && _webPageFooterModel == nil;
    CGFloat captionLeft = captionMediaFrame.origin.x - (_incomingAppearance ? 7.0f : 2.0f) + TGMessageFontMetric(11.0f) + (_incomingAppearance ? 6.0f : 0.0f);
    CGFloat captionRight = captionMediaFrame.origin.x - (_incomingAppearance ? 7.0f : 2.0f) + contentSize.width + 9.0f + classicMediaBubbleExtraWidth - TGMessageFontMetric(11.0f) - (_incomingAppearance ? 0.0f : 6.0f);
    CTFontRef statusFont = standardCaptionLayout && !isPost && _messageViewsModel == nil ? [TGModernDateViewModel inlineDateFont] : [TGModernDateViewModel dateFont];
    bool statusFontUpdated = [_dateModel updateFont:statusFont];
    if ([_editedLabelModel updateFont:statusFont])
        statusFontUpdated = true;
    [_messageViewsModel sizeToFit];
    CGFloat captionStatusWidth = standardCaptionLayout && !_incomingAppearance && _deliveryState != TGMessageDeliveryStateFailed ? TGMessageFontMetric(20.0f) : 0.0f;
    
    bool hasSignature = false;
    if (_authorSignature.length != 0) {
        hasSignature = true;
        if (standardCaptionLayout && (_authorSignatureModel.font == NULL || !CFEqual(_authorSignatureModel.font, statusFont))) {
            _authorSignatureModel.font = statusFont;
            statusFontUpdated = true;
        }
        CGFloat signatureWidth = contentContainerSize.width - _messageViewsModel.frame.size.width - _editedLabelModel.frame.size.width - _dateModel.frame.size.width - 20.0f;
        if (standardCaptionLayout) {
            _authorSignatureModel.maxNumberOfLines = 1;
            signatureWidth = captionRight - captionLeft - _dateModel.frame.size.width - captionStatusWidth - TGMessageFontMetric(7.0f);
            if (_messageViewsModel != nil)
                signatureWidth -= _messageViewsModel.frame.size.width + TGMessageFontMetric(3.0f);
            if (_editedLabelModel != nil)
                signatureWidth -= _editedLabelModel.frame.size.width + TGMessageFontMetric(3.0f);
            signatureWidth = MAX(1.0f, signatureWidth);
            if ([_authorSignatureModel layoutNeedsUpdatingForContainerSize:CGSizeMake(signatureWidth, CGFLOAT_MAX)])
                statusFontUpdated = true;
        }
        [_authorSignatureModel layoutForContainerSize:CGSizeMake(signatureWidth, CGFLOAT_MAX)];
    } else {
        _authorSignatureModel.frame = CGRectZero;
    }
    
    CGSize textSize = CGSizeZero;
    CGFloat infoWidth = 0.0f;
    if (![TGPresentation brandedIOS6Style])
    {
        if (!_incoming) {
            if (_messageViews == nil) {
                infoWidth += 12.0f;
            } else {
                infoWidth += MAX(0.0f, 12.0f - _messageViewsModel.frame.size.width);
                if (!isPost) {
                    infoWidth += 12.0f;
                }
            }
        }
        infoWidth += _dateModel.frame.size.width + 10.0f;
    }
    if (_editedLabelModel != nil) {
        infoWidth += _editedLabelModel.frame.size.width + 4.0f;
    }
    
    if (hasSignature) {
        infoWidth += _authorSignatureModel.frame.size.width + 6.0f;
    }
    
    if (_messageViews != nil) {
        infoWidth += _messageViewsModel.frame.size.width + ([TGPresentation brandedIOS6Style] ? 6.0f : TGMessageFontMetric(3.0f));
    }
    if (standardCaptionLayout) {
        infoWidth = _dateModel.frame.size.width + captionStatusWidth + TGMessageFontMetric(4.0f);
        if (_editedLabelModel != nil)
            infoWidth += _editedLabelModel.frame.size.width + TGMessageFontMetric(3.0f);
        if (hasSignature)
            infoWidth += _authorSignatureModel.frame.size.width + TGMessageFontMetric(3.0f);
        if (_messageViewsModel != nil)
            infoWidth += _messageViewsModel.frame.size.width + TGMessageFontMetric(3.0f);
    }
    bool updateContent = false;
    if (hasCaption)
    {
        CGFloat captionWidth = standardCaptionLayout ? captionRight - captionLeft : captionMediaFrame.size.width - TGImageMessageCaptionHorizontalInset;
        textSize = [self contentSizeForContainerSize:CGSizeMake(captionWidth, containerSize.height) needsContentsUpdate:&updateContent infoWidth:mediaReactions ? 0.0f : infoWidth];
        textSize.height += 5.0;
        CGRect textFrame = _textModel.frame;
        textFrame.origin = CGPointMake(3.0f, CGRectGetMaxY(captionMediaFrame) - 3.0f + TGScreenPixel);
        
        if (_caption.length == 0 && _webPageFooterModel != nil) {
            textFrame.origin.y -= 19.0f;
        }
        
        if (isPost)
            textFrame.origin.y -= 2.0;
        if (standardCaptionLayout) {
            CGFloat contentOriginY = topSpacing + (isPost ? 2.0f : 0.0f);
            CGFloat firstBaselineOffset = TGReusableLabelFirstBaselineOffset(_textModel.font);
            textFrame.origin.x = captionLeft - imageFrame.origin.x - 3.0f - TGScreenPixel;
            textFrame.origin.y = TGRetinaFloor(CGRectGetMaxY(captionMediaFrame) + TGMessageFontMetric(6.0f) + TGScreenPixel - firstBaselineOffset + CTFontGetAscent(_textModel.font) - contentOriginY);
        }
        
        _textModel.frame = textFrame;
    }
    
    if (_webPageFooterModel != nil && _positionFlags == TGMessageGroupPositionNone) {
        bool bottomInset = false;
        [_webPageFooterModel layoutForContainerSize:contentContainerSize contentSize:contentContainerSize infoWidth:mediaReactions ? 0.0f : infoWidth needsContentUpdate:&updateContent bottomInset:&bottomInset];
        _webPageFooterModel.frame = CGRectMake(_textModel.frame.origin.x, _caption.length > 0 ? CGRectGetMaxY(_textModel.frame) : imageFrame.origin.y + imageFrame.size.height - 6.0f, _webPageFooterModel.frame.size.width, _webPageFooterModel.frame.size.height);
        
        if (!hasCaption)
            textSize.height += _webPageFooterModel.frame.size.height + 4.0f;
    }
    if (statusFontUpdated)
        updateContent = true;
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    CGFloat dateCapHeight = CGFloor((CGFloat)CTFontGetCapHeight(statusFont));
    CGFloat standardDateBaselineInset = 13.0f + (TGIsLocaleArabic() ? 1.0f : 0.0f);
    TGMessageReactionsLayout *mediaReactionsLayout = nil;
    bool mediaReactionsShareTimeRow = false;
    CGFloat mediaReactionsTop = 0.0f;
    CGFloat mediaReactionsDateShift = 0.0f;
    CGFloat mediaReactionsBottomSpace = 0.0f;
    CGFloat mediaReactionsAttachedHeight = 0.0f;
    if (mediaReactions)
    {
        TGMessageReactionsMetrics reactionsMetrics = TGMessageReactionsCurrentMetrics();
        mediaReactionsShareTimeRow = (hasCaption || _webPageFooterModel != nil) && _dateModel != nil;
        CGFloat trailingWidth = 0.0f;
        if (mediaReactionsShareTimeRow)
        {
            trailingWidth = (_incomingAppearance ? 19.0f : 27.0f) + _dateModel.frame.size.width;
            if (_editedLabelModel != nil)
                trailingWidth += _editedLabelModel.frame.size.width + 4.0f;
            if (hasSignature)
                trailingWidth += _authorSignatureModel.frame.size.width + 6.0f;
            if (_messageViewsModel != nil)
                trailingWidth += _messageViewsModel.frame.size.width + (brandedIOS6Style ? 6.0f : TGMessageFontMetric(3.0f));

            CGFloat probeBubbleRight = captionMediaFrame.origin.x - (_incomingAppearance ? 7.0f : 2.0f) + contentSize.width + 9.0f + classicMediaBubbleExtraWidth;
            CGFloat probeCountRight = 0.0f;
            if ([self brandedCommentsCountRight:&probeCountRight bubbleFrame:CGRectMake(0.0f, 0.0f, probeBubbleRight, 0.0f)])
            {
                CGFloat contentRight = imageFrame.origin.x + 3.0f + TGScreenPixel + contentSize.width + 1.0f;
                CGFloat defaultInfoRight = contentRight - (_incomingAppearance ? 19.0f : 8.0f) - TGScreenPixel;
                trailingWidth += MAX(0.0f, defaultInfoRight - probeCountRight);
            }
        }

        mediaReactionsLayout = [_reactionsModel layoutWithMaximumWidth:captionMediaFrame.size.width - TGImageMessageCaptionHorizontalInset trailingWidth:trailingWidth trailingHeight:mediaReactionsShareTimeRow ? _dateModel.frame.size.height : 0.0f];

        if (mediaReactionsShareTimeRow)
        {
            CGFloat contentHeight = CGRectGetMaxY(captionMediaFrame) + 1.0f + TGScreenPixel + textSize.height;
            CGFloat textBottom = hasCaption ? CGRectGetMaxY(_textModel.frame) : 0.0f;
            if (_webPageFooterModel != nil)
                textBottom = MAX(textBottom, CGRectGetMaxY(_webPageFooterModel.frame));
            CGFloat standardDateBottom = 24.0f + (TGIsLocaleArabic() ? 1.0f : 0.0f);
            CGFloat dateHeight = _dateModel.frame.size.height;
            CGFloat bottomSpace = brandedIOS6Style ? MAX(0.0f, standardDateBottom - dateHeight) : standardDateBaselineInset;
            mediaReactionsTop = textBottom + reactionsMetrics.topSpacing;
            CGFloat targetContentHeight = mediaReactionsTop + mediaReactionsLayout.size.height + bottomSpace;
            textSize.height += targetContentHeight - contentHeight;
            if (brandedIOS6Style)
                mediaReactionsDateShift = (mediaReactionsTop + mediaReactionsLayout.size.height - dateHeight) - (targetContentHeight - standardDateBottom);
            else
                mediaReactionsDateShift = TGRetinaFloor(mediaReactionsTop + CGRectGetMidY(mediaReactionsLayout.trailingFrame) + dateCapHeight / 2.0f) - (targetContentHeight - standardDateBaselineInset);
        }
        else
        {
            CGFloat bubbleBottomInset = [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6BubbleImageInsetsOutgoing:!_incomingAppearance].bottom : layoutConstants->textBubblePaddingBottom;
            mediaReactionsBottomSpace = bubbleBottomInset + reactionsMetrics.topSpacing;
            mediaReactionsAttachedHeight = reactionsMetrics.topSpacing + mediaReactionsLayout.size.height + mediaReactionsBottomSpace;
            textSize.height += mediaReactionsAttachedHeight;
        }
    }
    
    CGFloat commentsFooterHeight = [self discussionCommentsFooterIntegratedInBubble] ? [self discussionCommentsFooterHeight] : 0.0f;
    CGRect backgroundFrame = CGRectMake(captionMediaFrame.origin.x - (_incomingAppearance ? 7.0f : 2.0f), topSpacing - 2.0f + (isPost ? 2.0f : 0.0f), contentSize.width + 9.0f + classicMediaBubbleExtraWidth, contentSize.height + 2.0f + topSpacing + headerSize.height + textSize.height + classicCaptionBottomInset);
    if (commentsFooterHeight > FLT_EPSILON)
    {
        backgroundFrame.size.height += commentsFooterHeight;
    }
    if (standardCaptionLayout) {
        CGFloat contentOriginY = backgroundFrame.origin.y + 2.0f;
        CGFloat textBottom = _textModel.frame.origin.y + _textModel.lastLineBaseline + CTFontGetDescent(_textModel.font);
        CGFloat statusBottom = _textModel.frame.origin.y + _textModel.trailingBaseline + CTFontGetDescent(statusFont);
        CGFloat captionBottom = TGRetinaFloor(contentOriginY + MAX(textBottom, statusBottom) + TGMessageFontMetric(6.0f) - TGScreenPixel);
        CGFloat captionHeight = captionBottom - backgroundFrame.origin.y + commentsFooterHeight;
        textSize.height += captionHeight - backgroundFrame.size.height;
        backgroundFrame.size.height = captionHeight;
    }
    _backgroundModel.frame = backgroundFrame;
    
    if (_textModel == nil && (hasHeader || _viaUserModel != nil || _authorNameModel != nil) && (self.groupedLayout == nil || [self hasMainPosition]))
    {
        CGRect imageFrame = _imageModel.frame;
        if (self.groupedLayout != nil)
        {
            CGRect inGroupFrame = [self.groupedLayout frameForMessageId:_message.mid];
            imageFrame.origin.y = CGRectGetMaxY(backgroundFrame) - commentsFooterHeight - mediaReactionsAttachedHeight - self.groupedLayout.dimensions.height + inGroupFrame.origin.y - 2;
        }
        else
        {
            imageFrame.origin.y = CGRectGetMaxY(backgroundFrame) - commentsFooterHeight - mediaReactionsAttachedHeight - _imageModel.frame.size.height - 2;
        }
        _imageModel.frame = imageFrame;
        displayedImageFrame = imageFrame;
    }

    if (self.groupedLayout != nil && [self hasMainPosition])
    {
        CGRect inGroupFrame = [self.groupedLayout frameForMessageId:_message.mid];
        _groupedMediaOffsetX = _imageModel.frame.origin.x - layoutOrigin.x - inGroupFrame.origin.x;
        _groupedMediaOffsetY = _imageModel.frame.origin.y - layoutOrigin.y - inGroupFrame.origin.y;
        CGFloat replyPanShift = (!_editing && fabs(_replyPanOffset) > FLT_EPSILON) ? _replyPanOffset : 0.0f;
        CGFloat editingShift = (_incomingAppearance && _editing) ? 42.0f : 0.0f;
        self.groupedLayout.mediaOrigin = CGPointMake(_imageModel.frame.origin.x - inGroupFrame.origin.x - replyPanShift - editingShift, _imageModel.frame.origin.y - inGroupFrame.origin.y);
    }
    
    _imageOrigin = CGPointMake(_imageModel.frame.origin.x, _imageModel.frame.origin.y);
    if (_editing && _incomingAppearance)
        _imageOrigin.x -= 42.0f;
    
    if (_backgroundModel == nil) {
        if (_actionButtonModel != nil) {
            _actionButtonModel.frame = CGRectOffset(_actionButtonModel.bounds, layoutOrigin.x + contentSize.width + 7.0f, layoutOrigin.y + contentSize.height - 29.0f - 1.0f);
        }
    } else {
        if (_actionButtonModel != nil) {
            _actionButtonModel.frame = CGRectOffset(_actionButtonModel.bounds, CGRectGetMaxX(backgroundFrame) + 7.0f, CGRectGetMaxY(backgroundFrame) - 29.0f - 1.0f);
        }
    }
    
    CGRect contentModelFrame = CGRectMake(imageFrame.origin.x + 3.0f + TGScreenPixel, backgroundFrame.origin.y + 2.0f, 0, 0);
    if (self.groupedLayout == nil || hasCaption)
    {
        contentModelFrame.size = CGSizeMake(contentSize.width + 1.0f, CGRectGetMaxY(captionMediaFrame) + 1.0f + TGScreenPixel + textSize.height);
        if (standardCaptionLayout)
            contentModelFrame.size.height = CGRectGetMaxY(backgroundFrame) - commentsFooterHeight - contentModelFrame.origin.y;
    }
    else
    {
        contentModelFrame.size = headerSize;
        if ((_contentModel.frame.size.width - contentModelFrame.size.width) > FLT_EPSILON)
            [_contentModel setNeedsSubmodelContentsUpdate];
    }
    
    if (_skipContentModelAnimation)
    {
        _skipContentModelAnimation = false;
        [UIView performWithoutAnimation:^
        {
            _contentModel.frame = contentModelFrame;
        }];
    }
    else
    {
         _contentModel.frame = contentModelFrame;
    }
    _adminContentModel.frame = CGRectMake(_backgroundModel.frame.origin.x + _backgroundModel.frame.size.width - _adminModel.frame.size.width - 1.0f - 11.0f, _contentModel.frame.origin.y + 3.0f + TGScreenPixel, _adminModel.frame.size.width, _adminModel.frame.size.height);
    _adminModel.frame = CGRectMake(0.0f, 0.0f, _adminModel.frame.size.width, _adminModel.frame.size.height);
    
    CGFloat limit = _viaUserModel != nil ? _contentModel.frame.origin.x + CGRectGetMaxX(_viaUserModel.frame) + 10.0f : _contentModel.frame.origin.x + CGRectGetMaxX(_authorNameModel.frame) + 10.0f;
    if (_adminModel.frame.origin.x < limit)
        _adminModel.hidden = true;
    
    _instantPreviewTouchAreaModel.frame = imageFrame;
    
    CGFloat footerAdjustment = 0.0f;
    if (hasCaption || _webPageFooterModel != nil)
    {
        CGFloat dateOffset = -3.0f + mediaReactionsDateShift;
        CGFloat dateY = brandedIOS6Style ? (_contentModel.frame.size.height - 21.0f - (TGIsLocaleArabic() ? 1.0f : 0.0f) + dateOffset) : (_contentModel.frame.size.height - standardDateBaselineInset + mediaReactionsDateShift - _dateModel.frame.size.height);
        CGFloat dateX = _contentModel.frame.size.width - (_incomingAppearance ? 12.0f : 20.0f) - _dateModel.frame.size.width - 7.0f - TGScreenPixel;
        if (standardCaptionLayout) {
            dateX = captionRight - _contentModel.frame.origin.x - captionStatusWidth - _dateModel.frame.size.width;
            dateY = TGRetinaFloor(_textModel.frame.origin.y + _textModel.trailingBaseline) - _dateModel.frame.size.height;
        }
        _dateModel.frame = CGRectMake(dateX, dateY, _dateModel.frame.size.width, _dateModel.frame.size.height);
        CGFloat dateBaselineY = CGRectGetMaxY(_dateModel.frame);
        CGFloat infoItemSpacing = brandedIOS6Style ? 4.0f : TGMessageFontMetric(3.0f);
        
        CGFloat brandedDateShiftX = 0.0f;
        if (brandedIOS6Style)
        {
            CGFloat brandedFooterTop = 0.0f;
            if ([self brandedCommentsFooterTop:&brandedFooterTop bubbleFrame:backgroundFrame])
            {
                CGFloat dateBottom = _contentModel.frame.origin.y + CGRectGetMaxY(_dateModel.frame);
                footerAdjustment = brandedFooterTop - [TGPresentation brandedIOS6ConversationAppearance].commentsTimeBottomSpacing - dateBottom;
                backgroundFrame.size.height -= footerAdjustment;
                _backgroundModel.frame = backgroundFrame;
            }
            
            CGFloat brandedCountRight = 0.0f;
            if ([self brandedCommentsCountRight:&brandedCountRight bubbleFrame:backgroundFrame])
            {
                CGRect dateFrame = _dateModel.frame;
                CGFloat infoRight = _incomingAppearance ? CGRectGetMaxX(dateFrame) : _contentModel.frame.size.width - 8.0f - TGScreenPixel;
                brandedDateShiftX = CGFloor(brandedCountRight - _contentModel.frame.origin.x - infoRight);
                dateFrame.origin.x += brandedDateShiftX;
                _dateModel.frame = dateFrame;
            }
        }
        
        _editedLabelModel.frame = CGRectMake(_dateModel.frame.origin.x - _editedLabelModel.frame.size.width - infoItemSpacing, dateBaselineY - _editedLabelModel.frame.size.height, _editedLabelModel.frame.size.width, _editedLabelModel.frame.size.height);
        
        CGFloat signatureSize = (hasSignature ? (_authorSignatureModel.frame.size.width + 8.0f) : 0.0f);
        
        if (_progressModel != nil) {
            if (standardCaptionLayout && !_incomingAppearance) {
                CGFloat clockSize = TGMessageFontMetric(15.0f);
                _progressModel.frame = CGRectMake(captionRight - clockSize, _contentModel.frame.origin.y + dateBaselineY - CGRound((dateCapHeight + clockSize) / 2.0f), clockSize, clockSize);
            } else if (_incomingAppearance) {
                _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - _dateModel.frame.size.width - 29 - unsentOffset - TGScreenPixel - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 20 + 1.0f - TGScreenPixel + dateOffset, 15, 15);
            } else {
                _progressModel.frame = CGRectMake(containerSize.width - 28 - layoutConstants->rightInset - unsentOffset - TGScreenPixel - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 20 + 1.0f + dateOffset, 15, 15);
            }
        }
        
        if (_authorSignature.length != 0) {
            CGFloat minX = _dateModel.frame.origin.x;
            if (_editedLabelModel != nil) {
                minX = _editedLabelModel.frame.origin.x;
            }
            CGFloat signatureY = brandedIOS6Style ? (_dateModel.frame.origin.y - 1.0f) : (dateBaselineY - _authorSignatureModel.frame.size.height);
            if (standardCaptionLayout)
                signatureY = dateBaselineY - _authorSignatureModel.lastLineBaseline;
            _authorSignatureModel.frame = CGRectMake(minX - _authorSignatureModel.frame.size.width - (brandedIOS6Style ? 6.0f : infoItemSpacing), signatureY, _authorSignatureModel.frame.size.width, _authorSignatureModel.frame.size.height);
        } else {
            _authorSignatureModel.frame = CGRectZero;
        }
        
        if (_messageViewsModel != nil) {
            CGFloat minX = _dateModel.frame.origin.x;
            if (_editedLabelModel != nil) {
                minX = _editedLabelModel.frame.origin.x;
            }
            if (_authorSignature.length != 0) {
                minX = _authorSignatureModel.frame.origin.x;
            }
            CGFloat viewsY = dateBaselineY - _messageViewsModel.baselineOffset;
            CGFloat viewsSpacing = brandedIOS6Style ? 6.0f : TGMessageFontMetric(3.0f);
            _messageViewsModel.frame = CGRectMake(minX - _messageViewsModel.frame.size.width - viewsSpacing + _contentModel.frame.origin.x, viewsY + _contentModel.frame.origin.y, _messageViewsModel.frame.size.width, _messageViewsModel.frame.size.height);
        }
        
        CGPoint stateOffset = _contentModel.frame.origin;
        CGFloat checksY = brandedIOS6Style ? (_contentModel.frame.size.height - 17 + TGScreenPixel + dateOffset) : (dateBaselineY - CGRound((dateCapHeight + 11.0f) / 2.0f));
        if (_checkFirstModel != nil)
            _checkFirstModel.frame = CGRectMake((_checkFirstEmbeddedInContent ? 0.0f : stateOffset.x) + _contentModel.frame.size.width - 17 - 7.0f - TGScreenPixel + brandedDateShiftX, (_checkFirstEmbeddedInContent ? 0.0f : stateOffset.y) + checksY, 12, 11);
        
        if (_checkSecondModel != nil)
            _checkSecondModel.frame = CGRectMake((_checkSecondEmbeddedInContent ? 0.0f : stateOffset.x) + _contentModel.frame.size.width - 13 - 7.0f - TGScreenPixel + brandedDateShiftX, (_checkSecondEmbeddedInContent ? 0.0f : stateOffset.y) + checksY, 12, 11);
        if (standardCaptionLayout) {
            CGFloat checksRight = captionRight - _contentModel.frame.origin.x;
            if (_checkFirstModel != nil)
                _checkFirstModel.frame = CGRectMake((_checkFirstEmbeddedInContent ? 0.0f : stateOffset.x) + checksRight - 17.0f, (_checkFirstEmbeddedInContent ? 0.0f : stateOffset.y) + checksY, 12.0f, 11.0f);
            if (_checkSecondModel != nil)
                _checkSecondModel.frame = CGRectMake((_checkSecondEmbeddedInContent ? 0.0f : stateOffset.x) + checksRight - 13.0f, (_checkSecondEmbeddedInContent ? 0.0f : stateOffset.y) + checksY, 12.0f, 11.0f);
        }

        if (!brandedIOS6Style && mediaReactionsShareTimeRow && commentsFooterHeight > FLT_EPSILON)
        {
            CGFloat statusBottomInset = TGMessageFontMetric(3.0f) + layoutConstants->textBubbleTextOffsetTop + (CGFloat)CTFontGetDescent(statusFont);
            CGFloat statusBottom = _contentModel.frame.origin.y + dateBaselineY + statusBottomInset;
            CGFloat reactionsBottom = _contentModel.frame.origin.y + mediaReactionsTop + mediaReactionsLayout.size.height + TGMessageFontMetric(3.0f);
            CGFloat footerTop = CGFloor(CGRectGetMaxY(backgroundFrame) - commentsFooterHeight);
            CGFloat targetFooterTop = CGFloor(MAX(statusBottom, reactionsBottom));
            footerAdjustment = MAX(0.0f, footerTop - targetFooterTop);
            backgroundFrame.size.height -= footerAdjustment;
            _backgroundModel.frame = backgroundFrame;

            CGRect drawingFrame = _contentModel.frame;
            drawingFrame.size.height = MIN(drawingFrame.size.height, CGRectGetMaxY(backgroundFrame) - commentsFooterHeight - drawingFrame.origin.y);
            _contentModel.frame = drawingFrame;
        }
    }

    if (ABS(footerAdjustment) > FLT_EPSILON && _actionButtonModel != nil)
        _actionButtonModel.frame = CGRectOffset(_actionButtonModel.bounds, CGRectGetMaxX(backgroundFrame) + 7.0f, CGRectGetMaxY(backgroundFrame) - 29.0f - 1.0f);

    if (mediaReactionsLayout != nil)
    {
        CGFloat reactionsY = mediaReactionsShareTimeRow ? (_contentModel.frame.origin.y + mediaReactionsTop) : (CGRectGetMaxY(backgroundFrame) - commentsFooterHeight - mediaReactionsBottomSpace - mediaReactionsLayout.size.height);
        [_reactionsModel applyLayout:mediaReactionsLayout origin:CGPointMake(_contentModel.frame.origin.x + 3.0f, reactionsY)];
        [_reactionsModel bringToFrontInContainer:[_imageModel boundView].superview];
    }
    else
        [_reactionsModel applyLayout:nil origin:CGPointZero];
    
    if (_unsentButtonModel != nil)
    {
        _unsentButtonModel.frame = CGRectMake(containerSize.width - _unsentButtonModel.frame.size.width - 9, contentSize.height + topSpacing + bottomSpacing + headerSize.height + textSize.height + classicCaptionBottomInset + commentsFooterHeight - footerAdjustment - _unsentButtonModel.frame.size.height - ((_collapseFlags & TGModernConversationItemCollapseBottom) ? 5 : 6), _unsentButtonModel.frame.size.width, _unsentButtonModel.frame.size.height);
    }
    
    CGFloat replyButtonsHeight = 0.0f;
    if (_replyButtonsModel != nil) {
        CGRect backgroundFrame = _imageModel.frame;
        CGFloat backgroundExtension = 10.0f;
        if (_backgroundModel != nil) {
            backgroundFrame = _backgroundModel.frame;
            backgroundExtension = 5.0f;
        }
        
        CGFloat replyButtonsAvailableWidth = _incomingAppearance ? (containerSize.width - 38.0f - backgroundFrame.origin.x) : (CGRectGetMaxX(backgroundFrame) - 38.0f);
        [_replyButtonsModel layoutForContainerSize:CGSizeMake(MAX(backgroundFrame.size.width + backgroundExtension, MIN([_replyButtonsModel minimumWidth], replyButtonsAvailableWidth)), containerSize.height)];
        
        _replyButtonsModel.frame = CGRectMake((_incomingAppearance ? backgroundFrame.origin.x : (CGRectGetMaxX(backgroundFrame) - _replyButtonsModel.frame.size.width)) + (_backgroundModel == nil ? (_incomingAppearance ? -5.0f : 5.0f) : 0.0f), CGRectGetMaxY(backgroundFrame), _replyButtonsModel.frame.size.width, _replyButtonsModel.frame.size.height);
        replyButtonsHeight = _replyButtonsModel.frame.size.height;
        self.avatarOffset = replyButtonsHeight;
    }
    else
    {
        self.avatarOffset = 7.0f;
    }
    
    CGRect frame = self.frame;
    frame.size = CGSizeMake(containerSize.width, contentSize.height + topSpacing + bottomSpacing + headerSize.height + textSize.height + classicCaptionBottomInset + 1.0f + commentsFooterHeight - footerAdjustment + replyButtonsHeight);
    self.frame = frame;
    
    if (updateContent)
        [_contentModel setNeedsSubmodelContentsUpdate];
    [_contentModel updateSubmodelContentsIfNeeded];
    [_adminContentModel updateSubmodelContentsIfNeeded];
    
    [super layoutForContainerSize:containerSize];
}

- (CGRect)editingCheckButtonFrame
{
    if (_positionFlags == TGMessageGroupPositionNone)
        return [super editingCheckButtonFrame];
    
    return CGRectMake(_imageOrigin.x + _imageModel.frame.size.width - 30.0f - 5.0f + (_incomingAppearance ? 42.0f : 0.0f), _imageOrigin.y + 5.0f, 30.0f, 30.0f);
}

- (CGRect)editingCheckAreaFrame
{
    if (_positionFlags == TGMessageGroupPositionNone)
        return [super editingCheckButtonFrame];
    
    return CGRectOffset(_imageModel.frame, _incomingAppearance ? 42.0f : 0.0f, 0.0f);
}

- (int)defaultOverlayActionType
{
    return _isSecret ? (_isMessageViewed ? TGMessageImageViewOverlaySecretViewed : TGMessageImageViewOverlaySecret) : TGMessageImageViewOverlayNone;
}

- (void)refreshMetrics
{
    if (_textModel != nil)
        [_textModel setFont:textFontForSize(TGGetMessageViewModelLayoutConstants()->textFontSize)];
}

- (void)clearLinkSelection
{
    for (UIView *linkView in _currentLinkSelectionViews)
    {
        [linkView removeFromSuperview];
    }
    _currentLinkSelectionViews = nil;
}

- (void)updateLinkSelection:(CGPoint)point
{
    if ([_contentModel boundView] != nil)
    {
        [self clearLinkSelection];
        
        CGPoint offset = CGPointMake(_contentModel.frame.origin.x - _backgroundModel.frame.origin.x, _contentModel.frame.origin.y - _backgroundModel.frame.origin.y);
        
        NSArray *regionData = nil;
        NSString *link = [_textModel linkAtPoint:CGPointMake(point.x - _textModel.frame.origin.x - offset.x, point.y - _textModel.frame.origin.y - offset.y) regionData:&regionData];
        
        CGPoint regionOffset = CGPointZero;
        
        if (link != nil)
        {
            CGRect topRegion = regionData.count > 0 ? [regionData[0] CGRectValue] : CGRectZero;
            CGRect middleRegion = regionData.count > 1 ? [regionData[1] CGRectValue] : CGRectZero;
            CGRect bottomRegion = regionData.count > 2 ? [regionData[2] CGRectValue] : CGRectZero;
            
            topRegion.origin = CGPointMake(topRegion.origin.x + regionOffset.x, topRegion.origin.y + regionOffset.y);
            middleRegion.origin = CGPointMake(middleRegion.origin.x + regionOffset.x, middleRegion.origin.y + regionOffset.y);
            bottomRegion.origin = CGPointMake(bottomRegion.origin.x + regionOffset.x, bottomRegion.origin.y + regionOffset.y);
            
            UIImageView *topView = nil;
            UIImageView *middleView = nil;
            UIImageView *bottomView = nil;
            
            UIImageView *topCornerLeft = nil;
            UIImageView *topCornerRight = nil;
            UIImageView *bottomCornerLeft = nil;
            UIImageView *bottomCornerRight = nil;
            
            NSMutableArray *linkHighlightedViews = [[NSMutableArray alloc] init];
            
            topView = [[UIImageView alloc] init];
            middleView = [[UIImageView alloc] init];
            bottomView = [[UIImageView alloc] init];
            
            topCornerLeft = [[UIImageView alloc] init];
            topCornerRight = [[UIImageView alloc] init];
            bottomCornerLeft = [[UIImageView alloc] init];
            bottomCornerRight = [[UIImageView alloc] init];
            
            if (topRegion.size.height != 0)
            {
                topView.hidden = false;
                topView.frame = topRegion;
                if (middleRegion.size.height == 0 && bottomRegion.size.height == 0)
                    topView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
                else
                    topView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
            }
            else
            {
                topView.hidden = true;
                topView.frame = CGRectZero;
            }
            
            if (middleRegion.size.height != 0)
            {
                middleView.hidden = false;
                middleView.frame = middleRegion;
                if (bottomRegion.size.height == 0)
                    middleView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
                else
                    middleView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
            }
            else
            {
                middleView.hidden = true;
                middleView.frame = CGRectZero;
            }
            
            if (bottomRegion.size.height != 0)
            {
                bottomView.hidden = false;
                bottomView.frame = bottomRegion;
                bottomView.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkFull];
            }
            else
            {
                bottomView.hidden = true;
                bottomView.frame = CGRectZero;
            }
            
            topCornerLeft.hidden = true;
            topCornerRight.hidden = true;
            bottomCornerLeft.hidden = true;
            bottomCornerRight.hidden = true;
            
            if (topRegion.size.height != 0 && middleRegion.size.height != 0)
            {
                if (topRegion.origin.x == middleRegion.origin.x)
                {
                    topCornerLeft.hidden = false;
                    topCornerLeft.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerLR];
                    topCornerLeft.frame = CGRectMake(topRegion.origin.x, topRegion.origin.y + topRegion.size.height - 3.5f, 4, 7);
                }
                else if (topRegion.origin.x < middleRegion.origin.x + middleRegion.size.width - 3.5f)
                {
                    topCornerLeft.hidden = false;
                    topCornerLeft.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerBT];
                    topCornerLeft.frame = CGRectMake(topRegion.origin.x - 3.5f, topRegion.origin.y + topRegion.size.height - 4, 7, 4);
                }
                
                if (topRegion.origin.x + topRegion.size.width == middleRegion.origin.x + middleRegion.size.width)
                {
                    topCornerRight.hidden = false;
                    topCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerRL];
                    topCornerRight.frame = CGRectMake(topRegion.origin.x + topRegion.size.width - 4, topRegion.origin.y + topRegion.size.height - 3.5f, 4, 7);
                }
                else if (topRegion.origin.x + topRegion.size.width < middleRegion.origin.x + middleRegion.size.width - 3.5f)
                {
                    topCornerRight.hidden = false;
                    topCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerBT];
                    topCornerRight.frame = CGRectMake(topRegion.origin.x + topRegion.size.width - 3.5f, topRegion.origin.y + topRegion.size.height - 4, 7, 4);
                }
                else if (bottomRegion.size.height == 0 && topRegion.origin.x < middleRegion.origin.x + middleRegion.size.width - 3.5f && topRegion.origin.x + topRegion.size.width > middleRegion.origin.x + middleRegion.size.width + 3.5f)
                {
                    topCornerRight.hidden = false;
                    topCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerTB];
                    topCornerRight.frame = CGRectMake(middleRegion.origin.x + middleRegion.size.width - 3.5f, middleRegion.origin.y, 7, 4);
                }
            }
            
            if (middleRegion.size.height != 0 && bottomRegion.size.height != 0)
            {
                if (middleRegion.origin.x == bottomRegion.origin.x)
                {
                    bottomCornerLeft.hidden = false;
                    bottomCornerLeft.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerLR];
                    bottomCornerLeft.frame = CGRectMake(middleRegion.origin.x, middleRegion.origin.y + middleRegion.size.height - 3.5f, 4, 7);
                }
                
                if (bottomRegion.origin.x + bottomRegion.size.width < middleRegion.origin.x + middleRegion.size.width - 3.5f)
                {
                    bottomCornerRight.hidden = false;
                    bottomCornerRight.image = [[TGTelegraphConversationMessageAssetsSource instance] messageLinkCornerTB];
                    bottomCornerRight.frame = CGRectMake(bottomRegion.origin.x + bottomRegion.size.width - 3.5f, bottomRegion.origin.y, 7, 4);
                }
            }
            
            if (!topView.hidden)
                [linkHighlightedViews addObject:topView];
            if (!middleView.hidden)
                [linkHighlightedViews addObject:middleView];
            if (!bottomView.hidden)
                [linkHighlightedViews addObject:bottomView];
            
            if (!topCornerLeft.hidden)
                [linkHighlightedViews addObject:topCornerLeft];
            if (!topCornerRight.hidden)
                [linkHighlightedViews addObject:topCornerRight];
            if (!bottomCornerLeft.hidden)
                [linkHighlightedViews addObject:bottomCornerLeft];
            if (!bottomCornerRight.hidden)
                [linkHighlightedViews addObject:bottomCornerRight];
            
            for (UIView *partView in linkHighlightedViews)
            {
                partView.frame = CGRectOffset(partView.frame, _textModel.frame.origin.x, _textModel.frame.origin.y + 1);
                [[_contentModel boundView] addSubview:partView];
            }
            
            _currentLinkSelectionViews = linkHighlightedViews;
        }
    }
}

- (void)updateAssets {
    [super updateAssets];
    
    _actionButtonModel.image = _savedMessage ? _context.presentation.images.chatActionGoToImage : _context.presentation.images.chatActionShareImage;
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
    else
    {
        if (_positionFlags != TGMessageGroupPositionNone)
            [_context.companionHandle requestAction:@"fastForwardMessage" options:@{@"groupedId": @(_message.groupedId), @"peerId": @(_message.cid)}];
        else
            [_context.companionHandle requestAction:@"fastForwardMessage" options:@{@"mid": @(_mid), @"peerId": @(_message.cid)}];
    }
}

- (bool)_requiresContentModel
{
    bool displaysGroupedCaption = _caption.length != 0 && [self hasMainPosition];
    return (_positionFlags == TGMessageGroupPositionNone && ((_authorPeer != nil && _context.isFeed) || _replyHeader != nil || _caption.length != 0 || (_forwardPeer != nil && !_context.isSavedMessages) || _viaUser != nil || _webPageFooterModel != nil || TGIOS6ImageMessageHasDiscussionFooter(_message) || [self _ios6RequiresBubbleBackground])) || (_positionFlags & TGMessageGroupPositionTop && _positionFlags & TGMessageGroupPositionLeft && ([self hasHeader] || displaysGroupedCaption || [self _ios6RequiresBubbleBackground]));
}

- (void)setupContentModel:(TGModernViewStorage *)viewStorage {
    if (_positionFlags == TGMessageGroupPositionUnknown)
        return;
    
    [self removeContentModel:viewStorage];

    if ([self _requiresContentModel])
    {
        static TGTelegraphConversationMessageAssetsSource *assetsSource = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            assetsSource = [TGTelegraphConversationMessageAssetsSource instance];
        });
        
        _backgroundModel = [[TGTextMessageBackgroundViewModel alloc] initWithType:(_incomingAppearance) ? TGTextMessageBackgroundIncoming : TGTextMessageBackgroundOutgoing context:_context];
        [self insertSubmodel:_backgroundModel belowSubmodel:_imageModel];
        if (_isChannel) {
            [_backgroundModel setPartialMode:false];
        }
        
        _contentModel = [[TGModernFlatteningViewModel alloc] init];
        _contentModel.viewUserInteractionDisabled = true;
        [self insertSubmodel:_contentModel aboveSubmodel:_backgroundModel];
        
        if (_forwardPeer != nil && !_context.isSavedMessages)
        {
            static NSRange formatNameRange;
            
            static int localizationVersion = -1;
            if (localizationVersion != TGLocalizedStaticVersion)
                formatNameRange = [TGLocalized(@"Message.ForwardedMessage") rangeOfString:@"%@"];
            
            NSString *authorName = @"";
            
            if ([_forwardPeer isKindOfClass:[TGUser class]]) {
                _forwardedPeerId = ((TGUser *)_forwardPeer).uid;
                authorName = ((TGUser *)_forwardPeer).displayName;
            } else if ([_forwardPeer isKindOfClass:[TGConversation class]]) {
                _forwardedPeerId = ((TGConversation *)_forwardPeer).conversationId;
                authorName = ((TGConversation *)_forwardPeer).chatTitle;
            }
            
            if ([_forwardAuthor isKindOfClass:[TGUser class]]) {
                authorName = [[NSString alloc] initWithFormat:@"%@ (%@)", authorName, ((TGUser *)_forwardAuthor).displayName];
            }
            
            NSString *text = [[NSString alloc] initWithFormat:TGLocalized(@"Message.ForwardedMessage"), authorName];
            
            NSMutableArray *additionalAttributes = [[NSMutableArray alloc] init];
            NSMutableArray *textCheckingResults = [[NSMutableArray alloc] init];
            
            NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageForwardNameFont], (__bridge NSString *)kCTFontAttributeName, nil];
            
            if (_viaUser != nil) {
                NSString *formatString = [@" " stringByAppendingString:TGLocalized(@"Conversation.MessageViaUser")];
                NSString *viaUserName = [@"@" stringByAppendingString:_viaUser.userName == nil ? @"" : _viaUser.userName];
                NSRange range = [formatString rangeOfString:@"%@"];
                NSString *finalString = [[NSString alloc] initWithFormat:formatString, viaUserName];
                
                if (range.location != NSNotFound) {
                    range.location += text.length;
                    range.length = viaUserName.length;
                    [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:range type:TGTextCheckingResultTypeLink contents:@"via"]];
                    [textCheckingResults addObject:[[TGTextCheckingResult alloc] initWithRange:range type:TGTextCheckingResultTypeUltraBold contents:nil]];
                }
                
                text = [text stringByAppendingString:finalString];
            }
            
            _forwardedHeaderModel = [[TGModernTextViewModel alloc] initWithText:text font:[[TGTelegraphConversationMessageAssetsSource instance] messageForwardTitleFont]];
            _forwardedHeaderModel.textColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingAccentColor : _context.presentation.pallete.chatOutgoingAccentColor;
            _forwardedHeaderModel.layoutFlags = TGReusableLabelLayoutMultiline;
            _forwardedHeaderModel.textCheckingResults = textCheckingResults;
            if (formatNameRange.location != NSNotFound && authorName.length != 0)
            {
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                [additionalAttributes addObjectsFromArray:@[[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes]];
            }
            _forwardedHeaderModel.additionalAttributes = additionalAttributes;
            
            [_contentModel addSubmodel:_forwardedHeaderModel];
        }
        
        if (_authorPeer != nil)
        {
            NSString *title = @"";
            if ([_authorPeer isKindOfClass:[TGUser class]]) {
                if (_savedMessage && ((TGUser *)_authorPeer).uid == TGTelegraphInstance.clientUserId)
                    title = TGLocalized(@"DialogList.You");
                else
                    title = ((TGUser *)_authorPeer).displayName;
            } else if ([_authorPeer isKindOfClass:[TGConversation class]]) {
                title = ((TGConversation *)_authorPeer).chatTitle;
            }
            _authorNameModel = [[TGModernTextViewModel alloc] initWithText:title font:[[TGTelegraphConversationMessageAssetsSource instance] messageAuthorNameFont]];
            [_contentModel addSubmodel:_authorNameModel];
            _authorNameModel.textColor = _authorNameColor;
            
            static CTFontRef dateFont = NULL;
            static CTFontRef adminFont = NULL;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                if (iosMajorVersion() >= 7) {
                    dateFont = TGIos6CreateCTFontFromUIFont(TGItalicSystemFontOfSize(12.0f));
                    adminFont = TGIos6CreateCTFontFromUIFont(TGSystemFontOfSize(12.0f));
                } else {
                    UIFont *font = TGItalicSystemFontOfSize(12.0f);
                    dateFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, nil);
                    
                    font = TGSystemFontOfSize(12.0f);
                    adminFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, nil);
                }
            });
            _authorSignatureModel = [[TGModernTextViewModel alloc] initWithText:@"" font:dateFont];
            _authorSignatureModel.ellipsisString = @"\u2026,";
            _authorSignatureModel.textColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingDateColor : _context.presentation.pallete.chatOutgoingDateColor;
            [_contentModel addSubmodel:_authorSignatureModel];
            
            if (_byAdmin)
            {
                _adminContentModel = [[TGModernFlatteningViewModel alloc] init];
                _adminContentModel.viewUserInteractionDisabled = true;
                [self insertSubmodel:_adminContentModel aboveSubmodel:_contentModel];
                [_adminContentModel bindViewToContainer:[_imageModel.boundView superview] viewStorage:viewStorage];
                
                _adminModel = [[TGModernTextViewModel alloc] initWithText:TGLocalized(@"Conversation.Admin") font:adminFont];
                _adminModel.textColor = _context.presentation.pallete.chatIncomingDateColor;
                [_adminContentModel addSubmodel:_adminModel];
            }
        }
        
        if (_viaUser != nil && _forwardedHeaderModel == nil) {
            NSString *formatString = TGLocalized(@"Conversation.MessageViaUser");
            NSString *viaUserName = [@"@" stringByAppendingString:_viaUser.userName != nil ? _viaUser.userName : @""];
            NSRange range = [formatString rangeOfString:@"%@"];
            
            _viaUserModel = [[TGModernTextViewModel alloc] initWithText:[[NSString alloc] initWithFormat:formatString, viaUserName] font:[[TGTelegraphConversationMessageAssetsSource instance] messageAuthorNameFont]];
            if (range.location != NSNotFound) {
                _viaUserModel.textCheckingResults = @[[[TGTextCheckingResult alloc] initWithRange:NSMakeRange(range.location, viaUserName.length) type:TGTextCheckingResultTypeBold contents:nil]];
            }
            _viaUserModel.textColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingAccentColor : _context.presentation.pallete.chatOutgoingAccentColor;
            [_contentModel addSubmodel:_viaUserModel];
        }
        
        if (_replyHeader != nil)
        {
            _replyMessageId = _replyHeader.mid;
            
            _replyHeaderModel = [TGContentBubbleViewModel replyHeaderModelFromMessage:_replyHeader peer:_replyAuthor incoming:_incomingAppearance system:false presentation:_context.presentation];
            _replyHeaderModel.frame = CGRectOffset(_replyHeaderModel.frame, 4.0f - TGScreenPixel, 1.0f);
            [_contentModel addSubmodel:_replyHeaderModel];
        }
        
        bool hasCaption = _caption.length > 0 && (_positionFlags == TGMessageGroupPositionNone || [self hasMainPosition]);
        
        if (_caption.length != 0) {
            _authorSignatureModel.text = _authorSignature;
        }
        
        if (hasCaption || _webPageFooterModel != nil)
        {
            int daytimeVariant = 0;
            NSString *dateText = [TGDateUtils stringForShortTime:(int)_message.date daytimeVariant:&daytimeVariant];
            _dateModel = [[TGModernDateViewModel alloc] initWithText:dateText textColor:_incomingAppearance ? _context.presentation.pallete.chatIncomingDateColor : _context.presentation.pallete.chatOutgoingDateColor daytimeVariant:daytimeVariant];
            _dateModel.hidden = false;
            [_contentModel addSubmodel:_dateModel];
            
            if (!_incoming)
            {
                _checkFirstModel = [[TGModernImageViewModel alloc] initWithImage:_context.presentation.images.chatDeliveredIcon];
                _checkSecondModel = [[TGModernImageViewModel alloc] initWithImage:_context.presentation.images.chatReadIcon];
                
                if (_deliveryState == TGMessageDeliveryStatePending)
                {
                    _progressModel = [[TGModernClockProgressViewModel alloc] initWithType:_incomingAppearance ? TGModernClockProgressTypeIncomingClock : TGModernClockProgressTypeOutgoingClock];
                    _progressModel.presentation = _context.presentation;
                    [self addSubmodel:_progressModel];
                    
                    if (!_incomingAppearance) {
                        [self insertSubmodel:_checkFirstModel aboveSubmodel:_contentModel];
                        [self insertSubmodel:_checkSecondModel aboveSubmodel:_contentModel];
                    }
                    _checkFirstModel.alpha = 0.0f;
                    _checkSecondModel.alpha = 0.0f;
                }
                else if (_deliveryState == TGMessageDeliveryStateDelivered)
                {
                    if (!_incomingAppearance) {
                        [_contentModel addSubmodel:_checkFirstModel];
                    }
                    _checkFirstEmbeddedInContent = true;
                    
                    if (!_incomingAppearance) {
                        if (_read)
                        {
                            [_contentModel addSubmodel:_checkSecondModel];
                            _checkSecondEmbeddedInContent = true;
                        }
                        else
                        {
                            [self insertSubmodel:_checkSecondModel aboveSubmodel:_contentModel];
                            _checkSecondModel.alpha = 0.0f;
                        }
                    }
                }
            }
            
            _textModel = [[TGModernTextViewModel alloc] initWithText:_caption font:_captionFont != NULL ? _captionFont : textFontForSize(TGGetMessageViewModelLayoutConstants()->textFontSize)];
            _textModel.underlineAllLinks = _incomingAppearance ? _context.presentation.pallete.underlineAllIncomingLinks : _context.presentation.pallete.underlineAllOutgoingLinks;
            _textModel.textCheckingResults = _textCheckingResults;
            _textModel.textColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingTextColor : _context.presentation.pallete.chatOutgoingTextColor;
            _textModel.linkColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingLinkColor : _context.presentation.pallete.chatOutgoingLinkColor;
            if (_message.isBroadcast)
                _textModel.additionalTrailingWidth += 10.0f;
            [_contentModel addSubmodel:_textModel];
            
            if (_messageViews != nil) {
                _messageViewsModel = [[TGMessageViewsViewModel alloc] init];
                _messageViewsModel.presentation = _context.presentation;
                _messageViewsModel.type = _incomingAppearance ? TGMessageViewsViewTypeIncoming : TGMessageViewsViewTypeOutgoing;
                _messageViewsModel.count = _messageViews.viewCount;
                [_messageViewsModel sizeToFit];
                [self addSubmodel:_messageViewsModel];
                _messageViewsModel.hidden = _deliveryState != TGMessageDeliveryStateDelivered;
            }
            
            if (!_ignoreEditing && _isEdited) {
                _editedLabelModel = [[TGModernLabelViewModel alloc] initWithText:TGLocalized(@"Conversation.MessageEditedLabel") textColor:_dateModel.textColor font:[TGModernDateViewModel dateFont] maxWidth:CGFLOAT_MAX];
                [_contentModel addSubmodel:_editedLabelModel];
            }
        }
        
        if (_webPageFooterModel != nil) {
            [_contentModel addSubmodel:_webPageFooterModel];
        }
        
        if (!hasCaption && _webPageFooterModel == nil && (_positionFlags == TGMessageGroupPositionNone || (_positionFlags & TGMessageGroupPositionBottom && _positionFlags & TGMessageGroupPositionRight)))
        {
            [_imageModel setTimestampString:[self timestampString] signatureString:[self signatureString] displayCheckmarks:!_incoming && !(_incomingAppearance && _context.isSavedMessages) && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:_messageViews != nil viewsValue:_messageViews.viewCount animated:false];
            [_imageModel setDisplayTimestampProgress:_deliveryState == TGMessageDeliveryStatePending];
            _imageModel.timestampHidden = false;
        }
        else
        {
            _imageModel.timestampHidden = true;
        }
    } else {
        [self removeContentModel:viewStorage];
    }

    [_reactionsModel moveToFrontInParent:self viewStorage:viewStorage container:[_imageModel boundView].superview];
}

- (void)removeContentModel:(TGModernViewStorage *)viewStorage {
    [self removeSubmodel:_backgroundModel viewStorage:viewStorage];
    _backgroundModel = nil;
    
    [self removeSubmodel:_contentModel viewStorage:viewStorage];
    
    _forwardedHeaderModel = nil;
    _authorNameModel = nil;
    _textModel = nil;
    _dateModel = nil;
    _authorSignatureModel = nil;
    
    [self removeSubmodel:_messageViewsModel viewStorage:viewStorage];
    _messageViewsModel = nil;
    
    [_contentModel removeSubmodel:_editedLabelModel viewStorage:viewStorage];
    
    [self removeSubmodel:_checkFirstModel viewStorage:viewStorage];
    _checkFirstModel = nil;
    
    [self removeSubmodel:_checkSecondModel viewStorage:viewStorage];
    _checkSecondModel = nil;
    
    [self removeSubmodel:_progressModel viewStorage:viewStorage];
    _progressModel = nil;
    
    [self removeSubmodel:_adminContentModel viewStorage:viewStorage];
    _adminContentModel = nil;
    
    [self removeSubmodel:_adminModel viewStorage:viewStorage];
    _adminModel = nil;
    
    [_imageModel setTimestampString:[self timestampString] signatureString:[self signatureString] displayCheckmarks:!_incoming && _deliveryState != TGMessageDeliveryStateFailed checkmarkValue:(_incoming ? 0 : ((_deliveryState == TGMessageDeliveryStateDelivered ? 1 : 0) + (_read ? 1 : 0))) displayViews:_messageViews != nil viewsValue:_messageViews.viewCount animated:false];
    [_imageModel setDisplayTimestampProgress:_deliveryState == TGMessageDeliveryStatePending];
    
    if ((_groupedLayout != nil && _groupedLayout.caption.length != 0) || (_positionFlags != TGMessageGroupPositionNone && !(_positionFlags & TGMessageGroupPositionBottom && _positionFlags & TGMessageGroupPositionRight)))
        _imageModel.timestampHidden = true;
    else
        _imageModel.timestampHidden = false;
    
    _contentModel = nil;
    [_reactionsModel moveToFrontInParent:self viewStorage:viewStorage container:[_imageModel boundView].superview];
}

- (void)setWebPageFooter:(TGWebPageMediaAttachment *)webPage invoice:(TGInvoiceMediaAttachment *)invoice viewStorage:(TGModernViewStorage *)viewStorage
{
    _webPage = webPage;
    if (webPage.url.length == 0 && ![webPage.pageType isEqualToString:@"game"] && ![webPage.pageType isEqualToString:@"invoice"] && ![webPage.pageType isEqualToString:@"message"])
    {
    }
    else
    {
        bool isAnimationOrVideo = false;
        bool imageInText = true;
        if ([webPage.pageType isEqualToString:@"photo"] || [webPage.pageType isEqualToString:@"video"] || [webPage.pageType isEqualToString:@"gif"] || [webPage.pageType isEqualToString:@"game"] || [webPage.pageType isEqualToString:@"invoice"] || [webPage.pageType isEqualToString:@"message"] || [webPage.pageType isEqualToString:@"telegram_album"]) {
            imageInText = false;
            isAnimationOrVideo = true;
        } else if ([webPage.pageType isEqualToString:@"article"]) {
            CGSize imageSize = CGSizeZero;
            [webPage.photo.imageInfo imageUrlForLargestSize:&imageSize];
            if (imageSize.width > 400.0f && webPage.instantPage != nil) {
                imageInText = false;
            }
        }
        
        if ([webPage.document.mimeType isEqualToString:@"image/gif"]) {
            imageInText = false;
        }
        
        bool isMusic = false;
        bool isVoice = false;
        bool isSticker = false;
        bool isRoundVideo = false;
        
        for (id attribute in webPage.document.attributes) {
            if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                if (((TGDocumentAttributeAudio *)attribute).isVoice) {
                    isVoice = true;
                } else {
                    isMusic = true;
                }
            } else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
                if (((TGDocumentAttributeVideo *)attribute).isRoundMessage) {
                    isRoundVideo = true;
                }
                else {
                    isAnimationOrVideo = true;
                }
            } else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]]) {
                isSticker = true;
            }
        }
        
        if (isVoice) {
            _webPageFooterModel = [[TGAudioWebpageFooterModel alloc] initWithContext:_context messageId:_mid authorPeerId:_authorPeerId incoming:_incomingAppearance webPage:webPage hasViews:_messageViews != nil];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (isMusic) {
            _webPageFooterModel = [[TGMusicWebpageFooterModel alloc] initWithContext:_context messageId:_mid authorPeerId:_authorPeerId incoming:_incomingAppearance webPage:webPage hasViews:_messageViews != nil];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (isSticker) {
            _webPageFooterModel = [[TGStickerWebpageFooterModel alloc] initWithContext:_context incoming:_incomingAppearance webPage:webPage hasViews:_messageViews != nil];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (isRoundVideo) {
            _webPageFooterModel = [[TGRoundVideoWebpageFooterModel alloc] initWithContext:_context messageId:_mid incoming:_incomingAppearance webPage:webPage];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (webPage.photo == nil && webPage.document != nil && !isAnimationOrVideo) {
            _webPageFooterModel = [[TGDocumentWebpageFooterModel alloc] initWithContext:_context incoming:_incomingAppearance webPage:webPage hasViews:_messageViews != nil];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else {
            if (TGPeerIdIsAdminLog(_message.cid) && !TGIOS6ImagePeerIdIsModernRawChannel(_message.cid))
                imageInText = true;
            
            _webPageFooterModel = [[TGArticleWebpageFooterModel alloc] initWithContext:_context incoming:_incomingAppearance webPage:webPage imageInText:imageInText invoice:invoice];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            _webPageFooterModel.boundToContainer = _boundToContainer;
            TGMessageViewModelReference *messageLifetimeReference2 = [self lifetimeReference];
            ((TGArticleWebpageFooterModel *)_webPageFooterModel).instantPagePressed = ^{
                [messageLifetimeReference2 withValue:^(void *value)
                {
                    __strong TGImageMessageViewModel *strongSelf = (__bridge TGImageMessageViewModel *)value;
                    if (strongSelf != nil) {
                        [strongSelf instantPageButtonPressed];
                    }
                }];
            };
            id companionHandle = _context.companionHandle;
            NSString *webPageUrl = [webPage.url copy];
            ((TGArticleWebpageFooterModel *)_webPageFooterModel).viewGroupPressed = ^{
                if (webPageUrl != nil) {
                    [companionHandle requestAction:@"openLinkRequested" options:@{@"url": webPageUrl}];
                }
            };
            [_contentModel addSubmodel:_webPageFooterModel];
        }
    }
    
    if ([_contentModel boundView] != nil)
    {
        [_webPageFooterModel bindSpecialViewsToContainer:_contentModel.boundView viewStorage:viewStorage atItemPosition:CGPointMake(_boundOffset.x + _webPageFooterModel.frame.origin.x, _boundOffset.y + _webPageFooterModel.frame.origin.y)];
    }
    
    [self setupContentModel:viewStorage];
}

- (void)instantPageButtonPressed {
    
}

- (bool)isInstant {
    return false;
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

- (bool (^)(CGPoint))pointInside
{
    if (_positionFlags == TGMessageGroupPositionNone)
        return nil;
    
    return ^bool (CGPoint point)
    {
        for (TGModernButtonViewModel *button in _reactionsModel.buttons)
        {
            if (!button.hidden && CGRectContainsPoint(button.frame, point))
                return true;
        }
        return CGRectContainsPoint(_imageModel.frame, point) || (_groupCheckButtonModel != nil && CGRectContainsPoint(_groupCheckButtonModel.frame, point)) || [self insideGroupCheckArea:point] || [self insideBackground:point] || (!_avatarModel.hidden && CGRectContainsPoint(_avatarModel.frame, point)) || (!_actionButtonModel.hidden && CGRectContainsPoint(_actionButtonModel.frame, point)) || (!_unsentButtonModel.hidden && CGRectContainsPoint(_unsentButtonModel.frame, point)) || (_replyHeaderModel != nil && CGRectContainsPoint(CGRectOffset(_replyHeaderModel.frame, _contentModel.frame.origin.x, _contentModel.frame.origin.y), point)) || (_forwardedHeaderModel != nil && CGRectContainsPoint(CGRectOffset(_forwardedHeaderModel.frame, _contentModel.frame.origin.x, _contentModel.frame.origin.y), point)) || (_unsentButtonModel != nil && CGRectContainsPoint(_unsentButtonModel.frame, point));
    };
}

- (bool)insideGroupCheckArea:(CGPoint)point
{
    if (_groupCheckAreaModel == nil)
        return false;
    
    if (point.x < _imageModel.frame.origin.x)
        return true;
    
    if (point.x > _imageModel.frame.origin.x + self.groupedLayout.dimensions.width)
        return true;
    
    return false;
}

- (bool)insideBackground:(CGPoint)point
{
    if (_backgroundModel == nil)
        return false;
    
    if (!CGRectContainsPoint(_backgroundModel.frame, point))
        return false;
    
    CGRect frame = [_groupedLayout frameForMessageId:_message.mid];
    CGPoint offset = CGPointMake(_imageModel.frame.origin.x - frame.origin.x, _imageModel.frame.origin.y - frame.origin.y);
    
    __block bool hitOtherMessage = false;
    [_groupedLayout enumerateMessageFrames:^(int32_t messageId, CGRect frame)
    {
        if (messageId == _message.mid || hitOtherMessage)
            return;
        
        CGRect messageFrame = CGRectOffset(frame, offset.x, offset.y);
        if (CGRectContainsPoint(messageFrame, point))
            hitOtherMessage = true;
    }];
    
    return !hitOtherMessage;
}

- (void)updateEditingState:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage animationDelay:(NSTimeInterval)animationDelay
{
    if (!_needsEditingCheckButton)
        return;
    
    if (_positionFlags & TGMessageGroupPositionTop && _positionFlags & TGMessageGroupPositionLeft)
    {
        bool editing = _context.editing;
        
        if (editing != _editing)
        {
            if (editing)
            {
                if (_groupCheckAreaModel == nil)
                {
                    _groupCheckAreaModel = [[TGModernButtonViewModel alloc] init];
                    _groupCheckAreaModel.skipDrawInContext = true;
                    _groupCheckAreaModel.frame = [super editingCheckAreaFrame];
                    [self addSubmodel:_groupCheckAreaModel];
                    
                    if (container != nil)
                    {
                        [_groupCheckAreaModel bindViewToContainer:container viewStorage:viewStorage];
                        
                        [(UIButton *)[_groupCheckAreaModel boundView] addTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                    }
                }
            }
            else if (_groupCheckAreaModel != nil)
            {
                if ([_groupCheckAreaModel boundView] != nil)
                {
                    [(UIButton *)[_groupCheckAreaModel boundView] removeTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                }
                
                [self removeSubmodel:_groupCheckAreaModel viewStorage:viewStorage];
                _groupCheckAreaModel = nil;
            }
            
            if (animationDelay > -FLT_EPSILON && container != nil)
            {
                UIView<TGModernView> *checkView = nil;
                
                if (editing)
                {
                    if (_groupCheckButtonModel == nil)
                    {
                        _groupCheckButtonModel = [[TGModernCheckButtonViewModel alloc] initWithFrame:[super editingCheckButtonFrame]];
                        _groupCheckButtonModel.isChecked = [_context isGroupChecked:_message.groupedId];
                        [self addSubmodel:_groupCheckButtonModel];
                        
                        if (container != nil)
                        {
                            [_groupCheckButtonModel bindViewToContainer:container viewStorage:viewStorage];
                            
                            [(UIButton *)[_groupCheckButtonModel boundView] addTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                        }
                    }
                    
                    [_groupCheckButtonModel boundView].frame = CGRectOffset(_groupCheckButtonModel.frame, -49.0f, 0.0f);
                }
                else if (_groupCheckButtonModel != nil)
                {
                    if ([_groupCheckButtonModel boundView] != nil)
                    {
                        [(UIButton *)[_groupCheckButtonModel boundView] removeTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                    }
                    
                    [self removeSubmodel:_groupCheckButtonModel viewStorage:viewStorage];
                    checkView = [_groupCheckButtonModel _dequeueView:viewStorage];
                    checkView.frame = _groupCheckButtonModel.frame;
                    [container addSubview:checkView];
                    _groupCheckButtonModel = nil;
                }
                
                UIViewAnimationOptions options = UIViewAnimationOptionAllowAnimatedContent;
                if (iosMajorVersion() >= 7)
                    options |= 7 << 16;
                [UIView animateWithDuration:MAX(0.025, 0.18 - animationDelay) delay:animationDelay options:options animations:^
                {
                    if (self.frame.size.width > FLT_EPSILON)
                        [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                    
                    if (editing)
                        [_groupCheckButtonModel boundView].frame = _groupCheckButtonModel.frame;
                    else
                        checkView.frame = CGRectOffset(checkView.frame, -49.0f, 0.0f);
                } completion:^(__unused BOOL finished)
                {
                    if (checkView != nil)
                    {
                        [checkView removeFromSuperview];
                        checkView.transform = CGAffineTransformIdentity;
                        [viewStorage enqueueView:checkView];
                    }
                }];
            }
            else
            {
                if (self.frame.size.width > FLT_EPSILON)
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                
                if (editing)
                {
                    if (_groupCheckButtonModel == nil)
                    {
                        _groupCheckButtonModel = [[TGModernCheckButtonViewModel alloc] initWithFrame:[super editingCheckButtonFrame]];
                        _groupCheckButtonModel.isChecked = [_context isGroupChecked:_message.groupedId];
                        [self addSubmodel:_groupCheckButtonModel];
                        
                        if (container != nil)
                        {
                            [_groupCheckButtonModel bindViewToContainer:container viewStorage:viewStorage];
                            
                            [(UIButton *)[_groupCheckButtonModel boundView] addTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                        }
                    }
                }
                else if (_groupCheckButtonModel != nil)
                {
                    if ([_groupCheckButtonModel boundView] != nil)
                    {
                        [(UIButton *)[_groupCheckButtonModel boundView] removeTarget:self action:@selector(groupCheckButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                    }
                    
                    [self removeSubmodel:_groupCheckButtonModel viewStorage:viewStorage];
                    _groupCheckButtonModel = nil;
                }
            }
        }
        else if (editing)
            _groupCheckButtonModel.isChecked = [_context isGroupChecked:_message.groupedId];
    }
    
    [super updateEditingState:container viewStorage:viewStorage animationDelay:animationDelay];
}

- (void)groupCheckButtonPressed
{
    if (_groupCheckButtonModel != nil)
    {
        _groupCheckButtonModel.isChecked = !_groupCheckButtonModel.isChecked;
        [_context.companionHandle requestAction:@"messageGroupSelectionChanged" options:@{@"groupedId": @(_message.groupedId), @"selected": @(_groupCheckButtonModel.isChecked)}];
    }
}

@end
