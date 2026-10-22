#import "TGContentBubbleViewModel.h"
#import "IOS6FeatureProbe.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTelegraphConversationMessageAssetsSource.h"
#import "TGReusableLabel.h"
#import "TGModernConversationItem.h"
#import "TGTelegraph.h"

#import "TGTextMessageBackgroundViewModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernDateViewModel.h"
#import "TGModernLabelViewModel.h"
#import "TGModernClockProgressViewModel.h"
#import "TGModernTextViewModel.h"

#import "TGModernView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"

#import "TGReplyHeaderTextModel.h"
#import "TGReplyHeaderPhotoModel.h"
#import "TGReplyHeaderVideoModel.h"
#import "TGReplyHeaderAudioModel.h"
#import "TGReplyHeaderFileModel.h"
#import "TGReplyHeaderContactModel.h"
#import "TGReplyHeaderLocationModel.h"
#import "TGReplyHeaderStickerModel.h"
#import "TGReplyHeaderActionModel.h"
#import "TGPollMediaAttachment.h"

#import "TGArticleWebpageFooterModel.h"

#import "TGMessageViewsViewModel.h"
#import "TGMessageGroupedLayout.h"
#import "TGModernButtonViewModel.h"
#import "TGModernButtonView.h"


#import "TGMessageReplyButtonsModel.h"

#import "TGDocumentWebpageFooterModel.h"
#import "TGAudioWebpageFooterModel.h"
#import "TGMusicWebpageFooterModel.h"
#import "TGStickerWebpageFooterModel.h"
#import "TGRoundVideoWebpageFooterModel.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static const CGFloat TGContentBubbleBrandedChecksWidth = 16.0f;
static const CGFloat TGContentBubbleBrandedChecksSpacing = 3.0f;
static const CGFloat TGContentBubbleTailWidth = 6.0f;
static const CGFloat TGContentBubbleCheckSize = 11.0f;
static const CGFloat TGContentBubbleSecondCheckOffset = 4.0f;
#import "TGPresentationAssets.h"
#import "TGMessageReactionsLayout.h"

bool debugShowMessageIds = false;

@interface TGContentBubbleViewModel () <UIGestureRecognizerDelegate, TGDoubleTapGestureRecognizerDelegate>
{
    UITapGestureRecognizer *_unsentButtonTapRecognizer;
    TGDoubleTapGestureRecognizer *_boundDoubleTapRecognizer;
    
    TGModernImageViewModel *_broadcastIconModel;
    CGPoint _itemPosition;
    
    TGModernButtonViewModel *_actionButtonModel;
    TGBotReplyMarkup *_replyMarkup;
    
    bool _boundToContainer;
    bool _mediaIsAvailable;
    bool _mediaProgressVisible;
    float _mediaProgress;
    
    TGMessageReplyButtonsModel *_replyButtonsModel;
    SMetaDisposable *_callbackButtonInProgressDisposable;
    NSDictionary *_callbackButtonInProgress;
    bool _callbackButtonInProgressSubscribed;
    
    TGMessage *_message;
    
    bool _hasInvoice;
}

@end

static char TGContentBubbleViewModelDoubleTapRecognizerPoolKey;

@implementation TGContentBubbleViewModel

- (bool)discussionCommentsFooterIntegratedInBubble
{
    return true;
}

- (bool)reactionsShareTimeRow
{
    return _reactionsModel.buttons.count != 0;
}

+ (void)debugEnableShowMessageIds
{
    debugShowMessageIds = true;
}

- (instancetype)initWithMessage:(TGMessage *)message authorPeer:(id)authorPeer viaUser:(TGUser *)viaUser context:(TGModernViewContext *)context
{
    self = [super initWithAuthorPeer:authorPeer context:context];
    if (self != nil)
    {
        _callbackButtonInProgressDisposable = [[SMetaDisposable alloc] init];
        
        static TGTelegraphConversationMessageAssetsSource *assetsSource = nil;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            assetsSource = [TGTelegraphConversationMessageAssetsSource instance];
        });
        
        _needsEditingCheckButton = true;
        
        bool isChannel = [authorPeer isKindOfClass:[TGConversation class]];
        
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
        
        _message = message;
        _mid = message.mid;
        _incoming = !message.outgoing;
        _incomingAppearance = _incoming || isChannel || _savedMessage;
        _deliveryState = message.deliveryState;
        
        _read = ![_context isMessageUnread:message];
        _date = (int32_t)message.date;
        _messageViews = message.viewCount;
        _byAdmin = [_context isByAdmin:_message];
        
        _backgroundModel = [[TGTextMessageBackgroundViewModel alloc] initWithType:_incomingAppearance ? TGTextMessageBackgroundIncoming : TGTextMessageBackgroundOutgoing context:context];
        _backgroundModel.blendMode = kCGBlendModeCopy;
        _backgroundModel.skipDrawInContext = true;
        [self addSubmodel:_backgroundModel];
        
        _contentModel = [[TGModernFlatteningViewModel alloc] initWithContext:_context];
        _contentModel.allowSpecialUserInteraction = true;
        _contentModel.viewUserInteractionDisabled = true;
        [self addSubmodel:_contentModel];
        
        if (authorPeer != nil)
        {
            NSString *title = @"";
            if ([authorPeer isKindOfClass:[TGUser class]]) {
                if (_savedMessage && ((TGUser *)authorPeer).uid == TGTelegraphInstance.clientUserId)
                    title = TGLocalized(@"DialogList.You");
                else
                    title = ((TGUser *)authorPeer).displayName;
                
                if (title.length == 0 && ((TGUser *)authorPeer).userName.length != 0)
                    title = ((TGUser *)authorPeer).userName;
                if (title.length == 0)
                    title = [NSString stringWithFormat:@"%d", ((TGUser *)authorPeer).uid];
            } else if ([authorPeer isKindOfClass:[TGConversation class]]) {
                title = ((TGConversation *)authorPeer).chatTitle;
                if (title.length == 0)
                    title = [NSString stringWithFormat:@"%lld", ((TGConversation *)authorPeer).conversationId];
            }
            
            _authorNameModel = [[TGModernTextViewModel alloc] initWithText:title font:[assetsSource messageAuthorNameFont]];
            [_contentModel addSubmodel:_authorNameModel];
            
            if ([authorPeer isKindOfClass:[TGUser class]]) {
                _hasAvatar = true;
            } else if ([authorPeer isKindOfClass:[TGConversation class]]) {
                TGConversation *conversationAuthor = (TGConversation *)authorPeer;
                if (TGMessageViewModelShouldDisplayConversationAvatar(conversationAuthor, context)) {
                    _hasAvatar = true;
                }
            }
            
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
            _authorSignatureModel.textColor = _incomingAppearance ? context.presentation.pallete.chatIncomingDateColor : context.presentation.pallete.chatOutgoingDateColor;
            [_contentModel addSubmodel:_authorSignatureModel];
            
            if (_byAdmin)
            {
                _adminModel = [[TGModernTextViewModel alloc] initWithText:TGLocalized(@"Conversation.Admin") font:adminFont];
                _adminModel.textColor = context.presentation.pallete.chatIncomingDateColor;
                [_contentModel addSubmodel:_adminModel];
            }
        }
        
        if (viaUser != nil && viaUser.userName.length != 0) {
            NSString *formatString = TGLocalized(@"Conversation.MessageViaUser");
            NSString *viaUserName = [@"@" stringByAppendingString:viaUser.userName];
            NSRange range = [formatString rangeOfString:@"%@"];
            
            _viaUserModel = [[TGModernTextViewModel alloc] initWithText:[[NSString alloc] initWithFormat:formatString, viaUserName] font:[assetsSource messageAuthorNameFont]];
            if (range.location != NSNotFound) {
                _viaUserModel.textCheckingResults = @[[[TGTextCheckingResult alloc] initWithRange:NSMakeRange(range.location, viaUserName.length) type:TGTextCheckingResultTypeBold contents:nil]];
            }
            _viaUserModel.textColor = _incomingAppearance ? context.presentation.pallete.chatIncomingAccentColor : context.presentation.pallete.chatOutgoingAccentColor;
            [_contentModel addSubmodel:_viaUserModel];
            
            _viaUser = viaUser;
        }
        
        bool isBot = false;
        if ([authorPeer isKindOfClass:[TGUser class]]) {
            if (((TGUser *)authorPeer).kind == TGUserKindBot || ((TGUser *)authorPeer).kind ==  TGUserKindSmartBot) {
                isBot = true;
            }
        }
        
        bool hasGameAction = false;
        bool hasPayAction = false;
        TGBotReplyMarkup *replyMarkup = message.replyMarkup;
        if (replyMarkup != nil && replyMarkup.isInline) {
            for (TGBotReplyMarkupRow *row in replyMarkup.rows) {
                for (TGBotReplyMarkupButton *button in row.buttons) {
                    if ([button.action isKindOfClass:[TGBotReplyMarkupButtonActionGame class]]) {
                        hasGameAction = true;
                    }
                    if ([button.action isKindOfClass:[TGBotReplyMarkupButtonActionPurchase class]]) {
                        hasPayAction = true;
                    }
                }
            }
        }
        
        if (_incomingAppearance && ((_savedMessage && hasForwardPostId) || isChannel || _context.isBot || isBot || _context.isPublicGroup || hasGameAction || hasPayAction) && !_context.isAdminLog && !_inhibitShare)
            [_backgroundModel setPartialMode:false];
        
        if (_incomingAppearance && ((_savedMessage && hasForwardPostId) || isChannel || _context.isBot || isBot || _context.isPublicGroup || hasGameAction || hasPayAction) && !_context.isAdminLog && !_inhibitShare && (_savedMessage || ![TGPresentation brandedIOS6Style])) {
            _actionButtonModel = [[TGModernButtonViewModel alloc] init];
            _actionButtonModel.image = _savedMessage ? context.presentation.images.chatActionGoToImage : context.presentation.images.chatActionShareImage;
            _actionButtonModel.modernHighlight = true;
            _actionButtonModel.frame = CGRectMake(0.0f, 0.0f, 29.0f, 29.0f);
            if (!isChannel && !hasGameAction && !_savedMessage) {
                _actionButtonModel.hidden = true;
            }
            [self addSubmodel:_actionButtonModel];
        }
        
        int daytimeVariant = 0;
        NSString *dateText = [TGDateUtils stringForShortTime:(int)message.date daytimeVariant:&daytimeVariant];
        if (debugShowMessageIds) {
            dateText = [[NSString alloc] initWithFormat:@"%d", message.mid];
        }
        
        _dateModel = [[TGModernDateViewModel alloc] initWithText:dateText textColor:_incomingAppearance ? context.presentation.pallete.chatIncomingDateColor : context.presentation.pallete.chatOutgoingDateColor daytimeVariant:daytimeVariant];
        [_contentModel addSubmodel:_dateModel];

        _reactionsModel = [[TGMessageReactionsModel alloc] initWithContext:context style:_incomingAppearance ? TGMessageReactionsStyleIncoming : TGMessageReactionsStyleOutgoing];
        [_reactionsModel updateWithMessage:message parent:self viewStorage:nil container:nil];
        
        if (!_ignoreEditing && message.isEdited && !(context.isBot || ([_authorPeer isKindOfClass:[TGUser class]] && ((TGUser *)_authorPeer).kind != TGUserKindGeneric))) {
            _editedLabelModel = [[TGModernLabelViewModel alloc] initWithText:TGLocalized(@"Conversation.MessageEditedLabel") textColor:_dateModel.textColor font:[TGModernDateViewModel dateFont] maxWidth:CGFLOAT_MAX];
            [_contentModel addSubmodel:_editedLabelModel];
        }
        
        if (!_incoming && !(_incomingAppearance && _context.isSavedMessages))
        {            
            if (!_inhibitChecks)
            {
                UIImage *deliveredIcon = _context.presentation.images.chatDeliveredIcon;
                UIImage *readIcon = _context.presentation.images.chatReadIcon;
                _checkFirstModel = [[TGModernImageViewModel alloc] initWithImage:deliveredIcon];
                _checkSecondModel = [[TGModernImageViewModel alloc] initWithImage:readIcon];
            }
            
            if (_deliveryState == TGMessageDeliveryStatePending && !_inhibitChecks)
            {
                _progressModel = [[TGModernClockProgressViewModel alloc] initWithType:_incomingAppearance ? TGModernClockProgressTypeIncomingClock : TGModernClockProgressTypeOutgoingClock];
                _progressModel.presentation = context.presentation;
                [self addSubmodel:_progressModel];
                
                if (!_incomingAppearance) {
                    [self addSubmodel:_checkFirstModel];
                    [self addSubmodel:_checkSecondModel];
                }
                _checkFirstModel.alpha = 0.0f;
                _checkSecondModel.alpha = 0.0f;
            }
            else if (_deliveryState == TGMessageDeliveryStateFailed)
            {
                [self addSubmodel:[self unsentButtonModel]];
            }
            else if (_deliveryState == TGMessageDeliveryStateDelivered && !_inhibitChecks)
            {
                if (!_incomingAppearance)
                    [_contentModel addSubmodel:_checkFirstModel];
                _checkFirstEmbeddedInContent = true;
                
                if (_read || ([TGPresentation brandedIOS6Style] && _context.isSavedMessages))
                {
                    if (!_incomingAppearance)
                        [_contentModel addSubmodel:_checkSecondModel];
                    _checkSecondEmbeddedInContent = true;
                }
                else
                {
                    if (!_incomingAppearance)
                        [self addSubmodel:_checkSecondModel];
                    _checkSecondModel.alpha = 0.0f;
                }
            }
        }
        
        if (!_ignoreViews && _messageViews != nil) {
            _messageViewsModel = [[TGMessageViewsViewModel alloc] init];
            _messageViewsModel.presentation = context.presentation;
            _messageViewsModel.type = _incomingAppearance ? TGMessageViewsViewTypeIncoming : TGMessageViewsViewTypeOutgoing;
            _messageViewsModel.count = _messageViews.viewCount;
            [self addSubmodel:_messageViewsModel];
            _messageViewsModel.hidden = _deliveryState != TGMessageDeliveryStateDelivered;
            [_messageViewsModel sizeToFit];
        }
        
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
            
            bool hasReceipt = false;
            if (hasPayAction) {
                for (TGMediaAttachment *media in message.mediaAttachments) {
                    if (media.type == TGInvoiceMediaAttachmentType) {
                        hasReceipt = ((TGInvoiceMediaAttachment *)media).receiptMessageId != 0;
                        break;
                    }
                }
            }
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:hasReceipt];
            [self addSubmodel:_replyButtonsModel];
        }
    }
    return self;
}

- (void)dealloc {
    TGModernViewModelRelinquishGestureRecognizer(_boundDoubleTapRecognizer, &TGContentBubbleViewModelDoubleTapRecognizerPoolKey, self, @selector(messageDoubleTapGesture:));
    [_callbackButtonInProgressDisposable dispose];
}

- (void)setTemporaryHighlighted:(bool)temporaryHighlighted viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    if (temporaryHighlighted)
        [_backgroundModel setHighlightedIfBound];
    else
        [_backgroundModel clearHighlight];
}

- (void)setAuthorNameColor:(UIColor *)authorNameColor
{
    _authorNameModel.textColor = authorNameColor;
}

- (void)setAuthorSignature:(NSString *)authorSignature {
    _authorSignatureModel.text = [authorSignature stringByAppendingString:@","];
    _authorSignature = authorSignature;
}

- (void)setForwardHeader:(id)forwardPeer forwardAuthor:(id)forwardAuthor messageId:(int32_t)messageId forwardSignature:(NSString *)forwardSignature
{
    if (_context.isSavedMessages)
        return;
    
    if (_forwardedHeaderModel == nil)
    {
        static NSRange formatNameRange;
        
        static int localizationVersion = -1;
        if (localizationVersion != TGLocalizedStaticVersion)
            formatNameRange = [TGLocalized(@"Message.ForwardedMessage") rangeOfString:@"%@"];

        _forwardedMessageId = messageId;
        NSString *authorName = @"";
        if ([forwardPeer isKindOfClass:[TGUser class]]) {
            _forwardedPeerId = ((TGUser *)forwardPeer).uid;
            authorName = ((TGUser *)forwardPeer).displayName;
        } else if ([forwardPeer isKindOfClass:[TGConversation class]]) {
            _forwardedPeerId = ((TGConversation *)forwardPeer).conversationId;
            authorName = ((TGConversation *)forwardPeer).chatTitle;
        }
        
        if ([forwardAuthor isKindOfClass:[TGUser class]]) {
            authorName = [[NSString alloc] initWithFormat:@"%@ (%@)", authorName, ((TGUser *)forwardAuthor).displayName];
        } else if (forwardSignature != nil) {
            authorName = [[NSString alloc] initWithFormat:@"%@ (%@)", authorName, forwardSignature];
        }
        
        NSMutableArray *additionalAttributes = [[NSMutableArray alloc] init];
        NSMutableArray *textCheckingResults = [[NSMutableArray alloc] init];

        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageForwardNameFont], (__bridge NSString *)kCTFontAttributeName, nil];
        
        NSString *text = [[NSString alloc] initWithFormat:TGLocalized(@"Message.ForwardedMessage"), authorName];
        if (_viaUser != nil && _viaUser.userName.length != 0) {
            NSString *formatString = [@" " stringByAppendingString:TGLocalized(@"Conversation.MessageViaUser")];
            NSString *viaUserName = [@"@" stringByAppendingString:_viaUser.userName];
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
        if (formatNameRange.location != NSNotFound && authorName.length != 0)
        {
            NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
            [additionalAttributes addObjectsFromArray:@[[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes]];
        }
        
        _forwardedHeaderModel.additionalAttributes = additionalAttributes;
        _forwardedHeaderModel.textCheckingResults = textCheckingResults;
        
        [_contentModel addSubmodel:_forwardedHeaderModel];
        
        if (_incomingAppearance && [forwardPeer isKindOfClass:[TGConversation class]] && ![TGPresentation brandedIOS6Style]) {
            TGConversation *conversation = forwardPeer;
            if (conversation.isChannel && !conversation.isChannelGroup) {
                if (_actionButtonModel == nil) {
                    _actionButtonModel = [[TGModernButtonViewModel alloc] init];
                    _actionButtonModel.image = _context.presentation.images.chatActionShareImage;
                    _actionButtonModel.modernHighlight = true;
                    _actionButtonModel.frame = CGRectMake(0.0f, 0.0f, 29.0f, 29.0f);
                    [self addSubmodel:_actionButtonModel];
                }
                
                _actionButtonModel.hidden = false;
            }
        }
    }
    
    if (_viaUserModel != nil) {
        [_contentModel removeSubmodel:_viaUserModel viewStorage:nil];
        _viaUserModel = nil;
    }
}

+ (TGReplyHeaderModel *)replyHeaderModelFromMessage:(TGMessage *)replyHeader peer:(id)peer incoming:(bool)incoming system:(bool)system presentation:(TGPresentation *)presentation
{
    bool isSecret = replyHeader.messageLifetime > 0 && replyHeader.messageLifetime <= 60;
    for (id attachment in replyHeader.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGImageMediaAttachment class]])
        {
            return [[TGReplyHeaderPhotoModel alloc] initWithPeer:peer imageMedia:isSecret ? nil : (TGImageMediaAttachment *)attachment incoming:incoming system:system presentation:presentation];
        }
        else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]])
        {
            return [[TGReplyHeaderVideoModel alloc] initWithPeer:peer videoMedia:isSecret ? nil : (TGVideoMediaAttachment *)attachment incoming:incoming system:system presentation:presentation];
        }
        else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]])
        {
            bool isSticker = false;
            for (id attribute in ((TGDocumentMediaAttachment *)attachment).attributes)
            {
                if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                {
                    isSticker = true;
                    break;
                }
            }
            
            if (isSticker)
            {
                return [[TGReplyHeaderStickerModel alloc] initWithPeer:peer fileMedia:(TGDocumentMediaAttachment *)attachment incoming:incoming system:system presentation:presentation];
            }
            else
            {
                return [[TGReplyHeaderFileModel alloc] initWithPeer:peer fileMedia:(TGDocumentMediaAttachment *)attachment incoming:incoming system:system presentation:presentation];
            }
        }
        else if ([attachment isKindOfClass:[TGLocationMediaAttachment class]])
        {
            return [[TGReplyHeaderLocationModel alloc] initWithPeer:peer latitude:((TGLocationMediaAttachment *)attachment).latitude longitude:((TGLocationMediaAttachment *)attachment).longitude period:((TGLocationMediaAttachment *)attachment).period incoming:incoming system:system presentation:presentation];
        }
        else if ([attachment isKindOfClass:[TGContactMediaAttachment class]])
        {
            return [[TGReplyHeaderContactModel alloc] initWithPeer:peer incoming:incoming system:system presentation:presentation];
        }
        else if ([attachment isKindOfClass:[TGPollMediaAttachment class]])
        {
            return [[TGReplyHeaderTextModel alloc] initWithPeer:peer text:[(TGPollMediaAttachment *)attachment previewText] incoming:incoming system:system presentation:presentation];
        }
        else if ([attachment isKindOfClass:[TGAudioMediaAttachment class]])
        {
            return [[TGReplyHeaderAudioModel alloc] initWithPeer:peer audioMedia:(TGAudioMediaAttachment *)attachment incoming:incoming system:system presentation:presentation];
        }
        else if ([attachment isKindOfClass:[TGActionMediaAttachment class]])
        {
            return [[TGReplyHeaderActionModel alloc] initWithPeer:peer actionMedia:(TGActionMediaAttachment *)attachment otherAttachments:replyHeader.mediaAttachments incoming:incoming system:system presentation:presentation];
        }
        else if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
            TGGameMediaAttachment *gameMedia = (TGGameMediaAttachment *)attachment;
            if (gameMedia.photo != nil) {
                return [[TGReplyHeaderPhotoModel alloc] initWithPeer:peer imageMedia:gameMedia.photo incoming:incoming system:system caption:gameMedia.title presentation:presentation];
            } else if (gameMedia.document != nil) {
                return [[TGReplyHeaderFileModel alloc] initWithPeer:peer fileMedia:gameMedia.document incoming:incoming system:system caption:gameMedia.title presentation:presentation];
            } else {
                return [[TGReplyHeaderTextModel alloc] initWithPeer:peer text:((TGGameMediaAttachment *)attachment).title incoming:incoming system:system presentation:presentation];
            }
        } else if ([attachment isKindOfClass:[TGInvoiceMediaAttachment class]]) {
            TGWebPageMediaAttachment *invoiceMedia = [(TGInvoiceMediaAttachment *)attachment webpage];
            if (invoiceMedia.photo != nil) {
                return [[TGReplyHeaderPhotoModel alloc] initWithPeer:peer imageMedia:invoiceMedia.photo incoming:incoming system:system caption:invoiceMedia.title presentation:presentation];
            } else if (invoiceMedia.document != nil) {
                return [[TGReplyHeaderFileModel alloc] initWithPeer:peer fileMedia:invoiceMedia.document incoming:incoming system:system caption:invoiceMedia.title presentation:presentation];
            } else {
                return [[TGReplyHeaderTextModel alloc] initWithPeer:peer text:((TGInvoiceMediaAttachment *)attachment).title incoming:incoming system:system presentation:presentation];
            }
        } else if ([attachment isKindOfClass:[TGInvoiceMediaAttachment class]]) {
            TGInvoiceMediaAttachment *invoiceMedia = (TGInvoiceMediaAttachment *)attachment;
            return [[TGReplyHeaderTextModel alloc] initWithPeer:peer text:invoiceMedia.title incoming:incoming system:system presentation:presentation];
        }
    }
    
    return [[TGReplyHeaderTextModel alloc] initWithPeer:peer text:replyHeader.text incoming:incoming system:system presentation:presentation];
}

- (void)setReplyHeader:(TGMessage *)replyHeader peer:(id)peer
{
    _replyHeaderModel = [TGContentBubbleViewModel replyHeaderModelFromMessage:replyHeader peer:peer incoming:_incomingAppearance system:false presentation:_context.presentation];
    if (_replyHeaderModel != nil)
        [_contentModel addSubmodel:_replyHeaderModel];
    _replyMessageId = replyHeader.mid;
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
            [_webPageFooterModel updateMediaProgressVisible:_mediaProgressVisible mediaProgress:_mediaProgress animated:false];
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (isMusic) {
            _webPageFooterModel = [[TGMusicWebpageFooterModel alloc] initWithContext:_context messageId:_mid authorPeerId:_authorPeerId incoming:_incomingAppearance webPage:webPage hasViews:_messageViews != nil];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            [_webPageFooterModel updateMediaProgressVisible:_mediaProgressVisible mediaProgress:_mediaProgress animated:false];
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (isSticker) {
            _webPageFooterModel = [[TGStickerWebpageFooterModel alloc] initWithContext:_context incoming:_incomingAppearance webPage:webPage hasViews:_messageViews != nil];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            [_webPageFooterModel updateMediaProgressVisible:_mediaProgressVisible mediaProgress:_mediaProgress animated:false];
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (isRoundVideo) {
            _webPageFooterModel = [[TGRoundVideoWebpageFooterModel alloc] initWithContext:_context messageId:_mid incoming:_incomingAppearance webPage:webPage];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            [_webPageFooterModel updateMediaProgressVisible:_mediaProgressVisible mediaProgress:_mediaProgress animated:false];
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else if (webPage.photo == nil && webPage.document != nil && !isAnimationOrVideo) {
            _webPageFooterModel = [[TGDocumentWebpageFooterModel alloc] initWithContext:_context incoming:_incomingAppearance webPage:webPage hasViews:_messageViews != nil];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            [_webPageFooterModel updateMediaProgressVisible:_mediaProgressVisible mediaProgress:_mediaProgress animated:false];
            _webPageFooterModel.boundToContainer = _boundToContainer;
            [_contentModel addSubmodel:_webPageFooterModel];
        } else {
            _webPageFooterModel = [[TGArticleWebpageFooterModel alloc] initWithContext:_context incoming:_incomingAppearance webPage:webPage imageInText:imageInText invoice:invoice];
            _webPageFooterModel.mediaIsAvailable = _mediaIsAvailable;
            [_webPageFooterModel updateMediaProgressVisible:_mediaProgressVisible mediaProgress:_mediaProgress animated:false];
            _webPageFooterModel.boundToContainer = _boundToContainer;
            __weak TGContentBubbleViewModel *weakSelf = self;
            ((TGArticleWebpageFooterModel *)_webPageFooterModel).instantPagePressed = ^{
                __strong TGContentBubbleViewModel *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf instantPageButtonPressed];
                }
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
        [_webPageFooterModel bindSpecialViewsToContainer:_contentModel.boundView viewStorage:viewStorage atItemPosition:CGPointMake(_itemPosition.x + _webPageFooterModel.frame.origin.x, _itemPosition.y + _webPageFooterModel.frame.origin.y)];
    }
    
    _actionButtonModel.hidden = webPage == nil;
    _hasInvoice = invoice != nil;
}

- (void)instantPageButtonPressed {
    
}

- (UIView *)referenceViewForImageTransition
{
    return [_webPageFooterModel referenceViewForImageTransition];
}

- (void)updateMediaVisibility
{
    [_webPageFooterModel setMediaVisible:[_context isMediaVisibleInMessage:_mid peerId:_authorPeerId]];
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

- (void)updateMediaAvailability:(bool)mediaIsAvailable viewStorage:(TGModernViewStorage *)__unused viewStorage delayDisplay:(bool)delayDisplay {
    [super updateMediaAvailability:mediaIsAvailable viewStorage:viewStorage delayDisplay:delayDisplay];
    
    _mediaIsAvailable = mediaIsAvailable;
    _webPageFooterModel.mediaIsAvailable = mediaIsAvailable;
}

- (void)updateProgress:(bool)progressVisible progress:(float)progress viewStorage:(TGModernViewStorage *)viewStorage animated:(bool)animated {
    [super updateProgress:progressVisible progress:progress viewStorage:viewStorage animated:animated];
    
    _mediaProgressVisible = progressVisible;
    _mediaProgress = progress;
    
    if (_webPageFooterModel != nil) {
        [_webPageFooterModel updateMediaProgressVisible:progressVisible mediaProgress:progress animated:animated];
    }
}

- (void)updateMessageAttributes {
    [super updateMessageAttributes];
    
    bool previousRead = _read;

    _read = ![_context isMessageUnread:_message];
    
    if (_read != previousRead) {
        if (_read) {
            _checkSecondModel.alpha = 1.0f;
            
            if (!previousRead && [_checkSecondModel boundView] != nil) {
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                animation.fromValue = @(1.3f);
                animation.toValue = @(1.0f);
                animation.duration = 0.1;
                animation.removedOnCompletion = true;
                
                [[_checkSecondModel boundView].layer addAnimation:animation forKey:@"transform.scale"];
            }
        }
    }
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];

    if ([_reactionsModel updateWithMessage:message parent:self viewStorage:viewStorage container:[_contentModel boundView].superview])
    {
        if (sizeUpdated)
            *sizeUpdated = true;
    }
    
    bool hadReceipt = false;
    for (TGMediaAttachment *media in _message.mediaAttachments) {
        if (media.type == TGInvoiceMediaAttachmentType) {
            hadReceipt = ((TGInvoiceMediaAttachment *)media).receiptMessageId != 0;
            break;
        }
    }
    
    _message = message;
    _mid = message.mid;
    
    if (_messageViewsModel != nil) {
        _messageViewsModel.count = message.viewCount.viewCount;
        CGFloat previousWidth = _messageViewsModel.frame.size.width;
        [_messageViewsModel sizeToFit];
        if (ABS(previousWidth - _messageViewsModel.frame.size.width) > FLT_EPSILON) {
            if (sizeUpdated) {
               *sizeUpdated = true;
            }
        }
    }
    
    TGWebPageMediaAttachment *webPage = nil;
    TGInvoiceMediaAttachment *invoice = nil;
    for (id attachment in message.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGWebPageMediaAttachment class]])
        {
            webPage = attachment;
        } else if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
            webPage = [((TGGameMediaAttachment *)attachment) webPageWithText:message.text entities:message.entities];
        } else if ([attachment isKindOfClass:[TGInvoiceMediaAttachment class]]) {
            webPage = [((TGInvoiceMediaAttachment *)attachment) webpage];
            invoice = attachment;
        }
    }
    
    if (webPage != nil) {
        if (_webPageFooterModel == nil) {
            if (![_webPage isEqual:webPage])
            {
                if (webPage.title.length != 0 || webPage.pageDescription.length != 0 || webPage.siteName.length != 0 || [webPage.photo.imageInfo imageUrlForLargestSize:NULL] != nil || [webPage.document.thumbnailInfo imageUrlForLargestSize:NULL] != nil) {
                    [self setWebPageFooter:webPage invoice:invoice viewStorage:viewStorage];
                    if (sizeUpdated)
                       *sizeUpdated = true;
                }
            }
        } else if (![_webPage isEqual:webPage])
        {
            [_contentModel removeSubmodel:_webPageFooterModel viewStorage:viewStorage];
            _webPageFooterModel = nil;
            
            [self setWebPageFooter:webPage invoice:invoice viewStorage:viewStorage];
            if (sizeUpdated)
               *sizeUpdated = true;
        }
        else {
            [_webPageFooterModel updateMessageId:_mid];
        }
    }
    
    if (webPage == nil && _webPageFooterModel != nil) {
        [_contentModel removeSubmodel:_webPageFooterModel viewStorage:viewStorage];
        _webPageFooterModel = nil;
        
        [self setWebPageFooter:nil invoice:invoice viewStorage:viewStorage];
        if (sizeUpdated)
           *sizeUpdated = true;
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
            
            _adminModel = [[TGModernTextViewModel alloc] initWithText:TGLocalized(@"Conversation.Admin") font:adminFont];
            _adminModel.textColor = _context.presentation.pallete.chatIncomingDateColor;
            [_contentModel addSubmodel:_adminModel];
        }
        else
        {
            [_contentModel removeSubmodel:_adminModel viewStorage:viewStorage];
        }
        
        [_contentModel setNeedsSubmodelContentsUpdate];
        
        if (sizeUpdated) {
           *sizeUpdated = true;
        }
    }
    
    bool messageUnread = [_context isMessageUnread:message];
    
    if (_deliveryState != message.deliveryState || (!_incoming && !(_incomingAppearance && _context.isSavedMessages) && _read != !messageUnread))
    {
        TGMessageViewModelLayoutConstants const *layoutConstants = TGGetMessageViewModelLayoutConstants();
        
        TGMessageDeliveryState previousDeliveryState = _deliveryState;
        _deliveryState = message.deliveryState;
        
        if (_messageViewsModel != nil) {
            _messageViewsModel.hidden = _deliveryState != TGMessageDeliveryStateDelivered;
        }
        
        bool previousRead = _read;
        _read = !messageUnread;
        
        if (_date != (int32_t)message.date && !debugShowMessageIds)
        {
            _date = (int32_t)message.date;
            
            int daytimeVariant = 0;
            NSString *dateText = [TGDateUtils stringForShortTime:(int)message.date daytimeVariant:&daytimeVariant];
            [_dateModel setText:dateText daytimeVariant:daytimeVariant];
        }
        
        if (_deliveryState == TGMessageDeliveryStateDelivered)
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
            
            if (_unsentButtonModel != nil)
            {
                [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                _unsentButtonModel = nil;
            }
        }
        else if (_deliveryState == TGMessageDeliveryStateFailed)
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
            
            if (_unsentButtonModel == nil)
            {
                [self addSubmodel:[self unsentButtonModel]];
                if ([_contentModel boundView] != nil)
                    [_unsentButtonModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                _unsentButtonModel.frame = CGRectOffset(_unsentButtonModel.frame, self.frame.size.width + _unsentButtonModel.frame.size.width, self.frame.size.height - _unsentButtonModel.frame.size.height - ((_collapseFlags & TGModernConversationItemCollapseBottom) ? 5 : 6));
                
                _unsentButtonTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unsentButtonTapGesture:)];
                [[_unsentButtonModel boundView] addGestureRecognizer:_unsentButtonTapRecognizer];
            }
            
            if (self.frame.size.width > FLT_EPSILON)
            {
                if ([_contentModel boundView] != nil)
                {
                    [UIView animateWithDuration:0.2 animations:^
                     {
                         [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                     }];
                }
                else
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
            }
            
            [_contentModel updateSubmodelContentsIfNeeded];
        }
        else if (_deliveryState == TGMessageDeliveryStatePending)
        {
            if (_progressModel == nil)
            {
                CGFloat unsentOffset = 0.0f;
                if (!_incomingAppearance && previousDeliveryState == TGMessageDeliveryStateFailed)
                    unsentOffset = 29.0f;
                
                bool hasSignature = false;
                if (_authorSignature.length != 0) {
                    hasSignature = true;
                }
                CGFloat signatureSize = (hasSignature ? (_authorSignatureModel.frame.size.width + 8.0f) : 0.0f);
                
                _progressModel = [[TGModernClockProgressViewModel alloc] initWithType:_incomingAppearance ? TGModernClockProgressTypeIncomingClock : TGModernClockProgressTypeOutgoingClock];
                _progressModel.presentation = _context.presentation;
                if (_incomingAppearance) {
                    _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - _dateModel.frame.size.width - 27.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
                } else {
                    _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - 23.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
                }
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
            
            if (!_incomingAppearance && !_inhibitChecks) {
                if (![self containsSubmodel:_checkFirstModel])
                {
                    [self addSubmodel:_checkFirstModel];
                    
                    if ([_contentModel boundView] != nil)
                        [_checkFirstModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                }
                if (![self containsSubmodel:_checkSecondModel])
                {
                    [self addSubmodel:_checkSecondModel];
                    
                    if ([_contentModel boundView] != nil)
                        [_checkSecondModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                }
            }
            
            _checkFirstModel.alpha = 0.0f;
            _checkSecondModel.alpha = 0.0f;
            
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
                             [[_contentModel boundView].superview addSubview:restoredView];
                             
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
                if ([_contentModel boundView] != nil)
                {
                    [UIView animateWithDuration:0.2 animations:^
                     {
                         [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                     }];
                }
                else
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
            }
            
            [_contentModel setNeedsSubmodelContentsUpdate];
            [_contentModel updateSubmodelContentsIfNeeded];
        }
    }
    
    TGBotReplyMarkup *replyMarkup = message.replyMarkup != nil && message.replyMarkup.isInline ? message.replyMarkup : nil;
    if (!TGObjectCompare(_replyMarkup, replyMarkup) || hadReceipt != (invoice.receiptMessageId != 0)) {
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
        
        bool hasReceipt = false;
        if (invoice != nil) {
            hasReceipt = invoice.receiptMessageId != 0;
        }
        
        if (_backgroundModel.boundView != nil) {
            [_replyButtonsModel unbindView:viewStorage];
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:hasReceipt];
            [_replyButtonsModel bindViewToContainer:_backgroundModel.boundView.superview viewStorage:viewStorage];
        } else {
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:hasReceipt];
        }
        if (sizeUpdated) {
           *sizeUpdated = true;
        }
    }
    
    if (!_ignoreEditing && message.isEdited && !(_context.isBot || ([_authorPeer isKindOfClass:[TGUser class]] && ((TGUser *)_authorPeer).kind != TGUserKindGeneric)) && (_authorPeer == nil || ![_authorPeer isKindOfClass:[TGConversation class]] || !((TGConversation *)_authorPeer).isChannel || ((TGConversation *)_authorPeer).isChannelGroup)) {
        if (_editedLabelModel == nil) {
            _editedLabelModel = [[TGModernLabelViewModel alloc] initWithText:TGLocalized(@"Conversation.MessageEditedLabel") textColor:_dateModel.textColor font:[TGModernDateViewModel dateFont] maxWidth:CGFLOAT_MAX];
            [_contentModel addSubmodel:_editedLabelModel];
            
            if (sizeUpdated) {
               *sizeUpdated = true;
            }
        }
    }
}

- (void)updateEditingState:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage animationDelay:(NSTimeInterval)animationDelay
{
    bool editing = _context.editing;
    if (editing != _editing)
    {
        [super updateEditingState:container viewStorage:viewStorage animationDelay:animationDelay];
        
        _backgroundModel.viewUserInteractionDisabled = _editing;
    }
}

- (void)prepareForAsynchronousContentDrawing
{
    if ([_contentModel boundView] == nil)
        [self _maybeRestructureStateModels:nil];
}

- (void)_maybeRestructureStateModels:(TGModernViewStorage *)viewStorage
{
    if (!_incoming && !_inhibitChecks && [_contentModel boundView] == nil && !_incomingAppearance)
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
            
            if ((_read || ([TGPresentation brandedIOS6Style] && _context.isSavedMessages)) && !_checkSecondEmbeddedInContent)
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

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    
    _itemPosition = itemPosition;
    
    [_backgroundModel bindViewToContainer:container viewStorage:viewStorage];
    [_backgroundModel boundView].frame = CGRectOffset([_backgroundModel boundView].frame, itemPosition.x, itemPosition.y);
    
    [_replyHeaderModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x + _contentModel.frame.origin.x + _replyHeaderModel.frame.origin.x, itemPosition.y + _contentModel.frame.origin.y + _replyHeaderModel.frame.origin.y)];
    
    [_webPageFooterModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x + _contentModel.frame.origin.x + _webPageFooterModel.frame.origin.x, itemPosition.y + _contentModel.frame.origin.y + _webPageFooterModel.frame.origin.y)];
    
    [_replyButtonsModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x, itemPosition.y)];
    
    [self subscribeToCallbackButtonInProgress];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [self _maybeRestructureStateModels:viewStorage];
    
    _boundToContainer = true;
    _itemPosition = CGPointZero;
    
    [self updateEditingState:nil viewStorage:nil animationDelay:-1.0];
    
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    [_replyHeaderModel bindSpecialViewsToContainer:_contentModel.boundView viewStorage:viewStorage atItemPosition:CGPointMake(_replyHeaderModel.frame.origin.x, _replyHeaderModel.frame.origin.y)];
    
    _webPageFooterModel.boundToContainer = true;
    [_webPageFooterModel bindSpecialViewsToContainer:_contentModel.boundView viewStorage:viewStorage atItemPosition:CGPointMake(_webPageFooterModel.frame.origin.x, _webPageFooterModel.frame.origin.y)];
    
    _boundDoubleTapRecognizer = TGModernViewModelAcquireGestureRecognizer([_backgroundModel boundView], &TGContentBubbleViewModelDoubleTapRecognizerPoolKey, [TGDoubleTapGestureRecognizer class], self, @selector(messageDoubleTapGesture:));
    _boundDoubleTapRecognizer.cancelsTouchesInView = true;
    _boundDoubleTapRecognizer.delegate = self;
    _boundDoubleTapRecognizer.avoidControls = true;
    
    if (_unsentButtonModel != nil)
    {
        _unsentButtonTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unsentButtonTapGesture:)];
        [[_unsentButtonModel boundView] addGestureRecognizer:_unsentButtonTapRecognizer];
    }
    
    if (_actionButtonModel != nil) {
        [(TGModernButtonView *)_actionButtonModel.boundView addTarget:self action:@selector(actionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
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

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    TGModernViewModelRelinquishGestureRecognizer(_boundDoubleTapRecognizer, &TGContentBubbleViewModelDoubleTapRecognizerPoolKey, self, @selector(messageDoubleTapGesture:));
    _boundDoubleTapRecognizer = nil;
    
    if (_unsentButtonModel != nil)
    {
        [[_unsentButtonModel boundView] removeGestureRecognizer:_unsentButtonTapRecognizer];
        _unsentButtonTapRecognizer = nil;
    }
    
    if (_actionButtonModel != nil)
    {
        [(TGModernButtonView *)_actionButtonModel.boundView removeTarget:self action:@selector(actionPressed) forControlEvents:UIControlEventTouchUpInside];
    }
    
    _boundToContainer = false;
    _webPageFooterModel.boundToContainer = false;
    
    [super unbindView:viewStorage];
    
    [_callbackButtonInProgressDisposable setDisposable:nil];
    _callbackButtonInProgressSubscribed = false;
}

- (void)relativeBoundsUpdated:(CGRect)bounds
{
    [super relativeBoundsUpdated:bounds];
    
    [_contentModel updateSubmodelContentsForVisibleRect:CGRectOffset(bounds, -_contentModel.frame.origin.x, -_contentModel.frame.origin.y)];
}

- (CGRect)effectiveContentFrame
{
    return _backgroundModel.frame;
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan)
    {
        if (recognizer.state == UIGestureRecognizerStateRecognized)
        {
            CGPoint point = [recognizer locationInView:[_contentModel boundView]];
            
            if (recognizer.longTapped)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            else if (recognizer.doubleTapped)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            else if (_forwardedHeaderModel && CGRectContainsPoint(_forwardedHeaderModel.frame, point)) {
                if (TGPeerIdIsChannel(_forwardedPeerId)) {
                    [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(_forwardedPeerId), @"messageId": @(_forwardedMessageId)}];
                } else {
                    [_context.companionHandle requestAction:@"userAvatarTapped" options:@{@"uid": @((int32_t)_forwardedPeerId)}];
                }
            }
            else if (_replyHeaderModel && CGRectContainsPoint(_replyHeaderModel.frame, point))
                [_context.companionHandle requestAction:@"navigateToMessage" options:@{@"mid": @(_replyMessageId), @"sourceMid": @(_mid)}];
        }
    }
}

- (void)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer didBeginAtPoint:(CGPoint)__unused point
{
}

- (void)gestureRecognizerDidFail:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
}

- (void)unsentButtonTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_context.companionHandle requestAction:@"showUnsentMessageMenu" options:@{@"mid": @(_mid)}];
    }
}

- (bool)gestureRecognizerShouldHandleLongTap:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer shouldFailTap:(CGPoint)__unused point
{
    return 0;
}

- (void)doubleTapGestureRecognizerSingleTapped:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
}

- (void)setCollapseFlags:(int)collapseFlags
{
    if (_collapseFlags != collapseFlags)
    {
        _collapseFlags = collapseFlags;
        if ([_authorPeer isKindOfClass:[TGConversation class]]) {
            [_backgroundModel setPartialMode:false];
        } else {
            [_backgroundModel setPartialMode:collapseFlags & TGModernConversationItemCollapseBottom];
        }
    }
}

- (void)layoutContentForHeaderHeight:(CGFloat)headerHeight
{
}

- (void)layoutContentForHeaderHeight:(CGFloat)headerHeight containerSize:(CGSize)containerSize {
    [self layoutContentForHeaderHeight:headerHeight];
}

- (bool)usesInlineMessageLayout
{
    return ![TGPresentation brandedIOS6Style] && ![_authorPeer isKindOfClass:[TGConversation class]] && ![self reactionsShareTimeRow] && _messageViewsModel == nil;
}

- (CGSize)contentSizeForContainerSize:(CGSize)__unused containerSize needsContentsUpdate:(bool *)__unused needsContentsUpdate infoWidth:(CGFloat)__unused infoWidth
{
    return CGSizeZero;
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    bool isPost = _authorPeer != nil && [_authorPeer isKindOfClass:[TGConversation class]];
    
    TGMessageViewModelLayoutConstants const *layoutConstants = TGGetMessageViewModelLayoutConstants();
    
    bool isRTL = TGIsRTL();
    
    CGFloat topSpacing = (_collapseFlags & TGModernConversationItemCollapseTop) ? layoutConstants->topInsetCollapsed : layoutConstants->topInset;
    CGFloat bottomSpacing = (_collapseFlags & TGModernConversationItemCollapseBottom) ? layoutConstants->bottomInsetCollapsed : layoutConstants->bottomInset;
    
    if (isPost) {
        topSpacing = layoutConstants->topPostInset;
        bottomSpacing = layoutConstants->bottomPostInset;
    }
    
    bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
    bool classicIOS6Style = [TGPresentation classicIOS6Style];
    bool inlineMessageLayout = [self usesInlineMessageLayout];
    bool hasReactions = [self reactionsShareTimeRow];
    OGConversationAppearance *brandedAppearance = brandedIOS6Style ? [TGPresentation brandedIOS6ConversationAppearance] : nil;
    UIEdgeInsets brandedBubbleInsets = brandedIOS6Style ? [TGPresentation brandedIOS6BubbleImageInsetsOutgoing:!_incomingAppearance] : UIEdgeInsetsZero;
    UIEdgeInsets brandedBubblePadding = brandedAppearance.bubbleContentPadding;
    CGFloat contentLeftInset = inlineMessageLayout ? (_incomingAppearance ? 14.0f : 8.0f) : (brandedIOS6Style ? (brandedBubbleInsets.left + brandedBubblePadding.left - 1.0f) : (TGMessageFontMetric(11.0f) + (_incomingAppearance ? TGContentBubbleTailWidth : 0.0f) - 1.0f));
    CGFloat contentTrailingInset = brandedIOS6Style ? (brandedBubbleInsets.right + brandedAppearance.bubbleTimeTrailingInset) : (TGMessageFontMetric(11.0f) + (_incomingAppearance ? 0.0f : TGContentBubbleTailWidth));
    CGFloat backgroundHorizontalChrome = inlineMessageLayout ? 25.0f : (contentLeftInset + 1.0f + contentTrailingInset);
    CGFloat avatarOffset = _hasAvatar ? 38.0f : 0.0f;
    CGFloat unsentOffset = !_incomingAppearance && _deliveryState == TGMessageDeliveryStateFailed ? 29.0f : 0.0f;
    CGFloat editingInset = !brandedIOS6Style && _incomingAppearance && _editing ? 42.0f : 0.0f;
    CGFloat maximumAvailableWidth = MAX(1.0f, containerSize.width - layoutConstants->leftInset - layoutConstants->rightInset - avatarOffset - unsentOffset - editingInset);
    bool hasActionButton = _actionButtonModel != nil && !_actionButtonModel.hidden;
    CGFloat contentHorizontalInset = brandedIOS6Style && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? 52.0f : 80.0f;
    CGSize contentContainerSize = CGSizeMake(MIN(420.0f, containerSize.width - contentHorizontalInset - (_hasAvatar ? 38.0f : 0.0f)), containerSize.height);
    if (hasActionButton) {
        contentContainerSize.width -= 20.0f;
    }
    CGFloat maximumBubbleWidth = maximumAvailableWidth;
    if (!brandedIOS6Style)
    {
        CGFloat widthFill = containerSize.width <= 500.0f ? containerSize.width - 36.0f : CGFloor(containerSize.width * (TGIsPad() ? 0.65f : 0.85f));
        maximumBubbleWidth = MIN(maximumAvailableWidth, widthFill - 9.0f - avatarOffset - unsentOffset - editingInset - (hasActionButton ? 10.0f : 0.0f));
        if (hasActionButton)
            maximumBubbleWidth = MIN(maximumBubbleWidth, maximumAvailableWidth - _actionButtonModel.frame.size.width - 7.0f);
        maximumBubbleWidth = MAX(1.0f, maximumBubbleWidth);
        contentContainerSize.width = MAX(1.0f, maximumBubbleWidth - backgroundHorizontalChrome);
    }
    
    bool updateContents = false;
    CTFontRef dateFont = inlineMessageLayout ? [TGModernDateViewModel inlineDateFont] : [TGModernDateViewModel dateFont];
    if ([_dateModel updateFont:dateFont])
        updateContents = true;
    if ([_editedLabelModel updateFont:dateFont])
        updateContents = true;
    [_messageViewsModel sizeToFit];
    CGFloat infoItemSpacing = brandedIOS6Style || inlineMessageLayout ? 4.0f : TGMessageFontMetric(3.0f);
    CGFloat statusWidth = !_incomingAppearance && _deliveryState != TGMessageDeliveryStateFailed ? TGMessageFontMetric(_deliveryState == TGMessageDeliveryStatePending ? 19.0f : 20.0f) : 0.0f;
    
    bool hasSignature = false;
    if (_authorSignature.length != 0) {
        hasSignature = true;
        CGFloat signatureWidth = contentContainerSize.width - 96.0f;
        if (!brandedIOS6Style)
        {
            if (_authorSignatureModel.font == NULL || !CFEqual(_authorSignatureModel.font, dateFont))
            {
                _authorSignatureModel.font = dateFont;
                updateContents = true;
            }
            _authorSignatureModel.maxNumberOfLines = 1;
            signatureWidth = contentContainerSize.width - _dateModel.frame.size.width - statusWidth - infoItemSpacing;
            if (_editedLabelModel != nil)
                signatureWidth -= _editedLabelModel.frame.size.width + infoItemSpacing;
            if (_messageViewsModel != nil)
                signatureWidth -= _messageViewsModel.frame.size.width + infoItemSpacing;
        }
        signatureWidth = MAX(1.0f, signatureWidth);
        if ([_authorSignatureModel layoutNeedsUpdatingForContainerSize:CGSizeMake(signatureWidth, CGFLOAT_MAX)]) {
            updateContents = true;
            [_authorSignatureModel layoutForContainerSize:CGSizeMake(signatureWidth, CGFLOAT_MAX)];
        }
    } else {
        _authorSignatureModel.frame = CGRectZero;
    }
    
    CGFloat infoWidth = 0.0f;
    if (inlineMessageLayout) {
        infoWidth = _dateModel.frame.size.width + 10.0f + (_incoming ? 0.0f : 12.0f);
        if (_editedLabelModel != nil)
            infoWidth += _editedLabelModel.frame.size.width + 4.0f;
        if (hasSignature)
            infoWidth += _authorSignatureModel.frame.size.width + 6.0f;
    } else if (brandedIOS6Style) {
        if (!_incoming) {
            if (_messageViews == nil) {
                infoWidth += 20.0f;
            } else {
                infoWidth += MAX(0.0f, 20.0f - _messageViewsModel.frame.size.width);
                if (!isPost) {
                    infoWidth += 20.0f;
                }
            }
        }
        infoWidth += _dateModel.frame.size.width + 10.0f;
        if (_editedLabelModel != nil) {
            infoWidth += _editedLabelModel.frame.size.width + 4.0f;
        }
        if (hasSignature) {
            infoWidth += _authorSignatureModel.frame.size.width + 6.0f;
        }
        if (_messageViews != nil) {
            infoWidth += _messageViewsModel.frame.size.width + 6.0f;
        }
    } else {
        infoWidth = _dateModel.frame.size.width + statusWidth;
        if (_editedLabelModel != nil) {
            infoWidth += _editedLabelModel.frame.size.width + infoItemSpacing;
        }
        if (hasSignature) {
            infoWidth += _authorSignatureModel.frame.size.width + infoItemSpacing;
        }
        if (_messageViews != nil) {
            infoWidth += _messageViewsModel.frame.size.width + infoItemSpacing;
        }
    }
    
    CGFloat layoutInfoWidth = hasReactions ? 0.0f : infoWidth + ((brandedIOS6Style || inlineMessageLayout) ? 0.0f : TGMessageFontMetric(4.0f));
    
    CGFloat maxHeaderWidth = contentContainerSize.width;
    bool alreadyMeasuredWebPage = false;
    bool webpageOnly = false;
    bool alreadyMeasuredWebpageHasBottomInset = false;
    if ([_webPageFooterModel fitContentToWebpage])
    {
        alreadyMeasuredWebPage = true;
        [_webPageFooterModel layoutForContainerSize:CGSizeMake(contentContainerSize.width, contentContainerSize.height) contentSize:CGSizeZero infoWidth:layoutInfoWidth needsContentUpdate:&updateContents bottomInset:&alreadyMeasuredWebpageHasBottomInset];
        maxHeaderWidth = _webPageFooterModel.frame.size.width;
    }
    webpageOnly = alreadyMeasuredWebPage || _hasInvoice;
    
    CGSize headerSize = CGSizeZero;
    if (_authorNameModel != nil)
    {
        CGFloat maxWidth = maxHeaderWidth;
        CGFloat maxNameWidth = _viaUserModel == nil ? maxWidth : maxWidth - 46.0f;
        
        if ([_authorNameModel layoutNeedsUpdatingForContainerSize:CGSizeMake(MAX(1.0f, maxNameWidth), 0.0f)])
            [_authorNameModel layoutForContainerSize:CGSizeMake(maxNameWidth, 0.0f)];
        
        CGRect authorNameFrame = _authorNameModel.frame;
        authorNameFrame.origin = CGPointMake(1.0f, 1.0f + TGScreenPixel);
        _authorNameModel.frame = authorNameFrame;
        
        headerSize = CGSizeMake(_authorNameModel.frame.size.width, _authorNameModel.frame.size.height + 1.0f);
        
        if (_viaUserModel != nil) {
            [_viaUserModel layoutForContainerSize:CGSizeMake(maxWidth - _authorNameModel.frame.size.width, 0.0f)];
            CGRect viaUserFrame = _viaUserModel.frame;
            viaUserFrame.origin = CGPointMake(CGRectGetMaxX(_authorNameModel.frame) + 4.0f, 1.0f + TGScreenPixel);
            _viaUserModel.frame = viaUserFrame;
            
            headerSize.width += viaUserFrame.size.width + 4.0f;
        }
        
        if (_adminModel != nil) {
            [_adminModel layoutForContainerSize:CGSizeMake(maxWidth - _authorNameModel.frame.size.width - _viaUserModel.frame.size.width, CGFLOAT_MAX)];
            headerSize.width += _adminModel.frame.size.width + 12.0f;
            updateContents = true;
        }
    } else if (_viaUserModel != nil) {
        [_viaUserModel layoutForContainerSize:CGSizeMake(contentContainerSize.width, 0.0f)];
        
        CGRect viaUserFrame = _viaUserModel.frame;
        viaUserFrame.origin = CGPointMake(1.0f, 1.0f + TGScreenPixel);
        _viaUserModel.frame = viaUserFrame;
        
        headerSize = CGSizeMake(_viaUserModel.frame.size.width, _viaUserModel.frame.size.height + 1.0f);
    }
    
    if (_forwardedHeaderModel != nil)
    {
        [_forwardedHeaderModel layoutForContainerSize:contentContainerSize];
        CGRect forwardedHeaderFrame = _forwardedHeaderModel.frame;
        forwardedHeaderFrame.origin = CGPointMake(1.0f, headerSize.height + 1.0f);
        _forwardedHeaderModel.frame = forwardedHeaderFrame;
        
        headerSize.height += forwardedHeaderFrame.size.height;
        headerSize.width = MAX(headerSize.width, forwardedHeaderFrame.size.width);
    }
    
    if (_replyHeaderModel != nil)
    {
        bool updateContent = false;
        [_replyHeaderModel layoutForContainerSize:contentContainerSize updateContent:&updateContent];
        if (updateContent)
            updateContents = true;
        CGRect replyHeaderFrame = _replyHeaderModel.frame;
        replyHeaderFrame.origin = CGPointMake(1.0f, headerSize.height + 1.0f);
        _replyHeaderModel.frame = replyHeaderFrame;
        
        headerSize.height += replyHeaderFrame.size.height - 1.0f;
        headerSize.width = MAX(headerSize.width, replyHeaderFrame.size.width);
    }
    
    CGFloat contentContainerWidth = contentContainerSize.width;
    CGSize contentSize = CGSizeZero;
    
    headerSize.width = MAX(headerSize.width, infoWidth - ((brandedIOS6Style || inlineMessageLayout) ? 10.0f : 0.0f));
    
    CGSize webPageSize = CGSizeZero;
    if (_webPageFooterModel != nil)
    {
        bool webpageHasBottomInset = false;
        if ([_webPageFooterModel preferWebpageSize])
        {
            if (alreadyMeasuredWebPage) {
                webpageHasBottomInset = alreadyMeasuredWebpageHasBottomInset;
            } else {
                [_webPageFooterModel layoutForContainerSize:CGSizeMake(contentContainerWidth, contentContainerSize.height) contentSize:CGSizeZero infoWidth:layoutInfoWidth needsContentUpdate:&updateContents bottomInset:&webpageHasBottomInset];
            }
            
            CGSize fittedContentSize = [self contentSizeForContainerSize:CGSizeMake(_webPageFooterModel.frame.size.width, contentContainerSize.height) needsContentsUpdate:&updateContents infoWidth:0.0f];
            contentContainerWidth = _webPageFooterModel.frame.size.width;
            contentSize = fittedContentSize;
        }
        else
        {
            contentSize = [self contentSizeForContainerSize:CGSizeMake(contentContainerWidth, contentContainerSize.height) needsContentsUpdate:&updateContents infoWidth:0.0f];
            
            [_webPageFooterModel layoutForContainerSize:CGSizeMake(contentContainerWidth, contentContainerSize.height) contentSize:contentSize infoWidth:layoutInfoWidth needsContentUpdate:&updateContents bottomInset:&webpageHasBottomInset];
        }
        
        webPageSize = _webPageFooterModel.frame.size;
        if ([_webPageFooterModel preferWebpageSize])
            contentContainerWidth = webPageSize.width;
        
        headerSize.width = MAX(headerSize.width, webPageSize.width);
        
        if (hasSignature && !webpageHasBottomInset) {
            webPageSize.height += 14.0f;
        }
    }
    else
    {
        contentSize = [self contentSizeForContainerSize:CGSizeMake(contentContainerWidth, contentContainerSize.height) needsContentsUpdate:&updateContents infoWidth:layoutInfoWidth];
    }
    
    CGFloat replyButtonsMinimumWidth = 0.0f;
    if (_replyButtonsModel != nil) {
        replyButtonsMinimumWidth = [_replyButtonsModel minimumWidth];
        contentSize.width = MAX(contentSize.width, MIN(contentContainerWidth + 14.0f, replyButtonsMinimumWidth));
    }
    
    TGMessageReactionsLayout *reactionsLayout = nil;
    CGFloat reactionsTrailingWidth = infoWidth;
    if (hasReactions)
    {
        CGFloat probeBubbleWidth = 1000.0f;
        CGFloat probeCountRight = 0.0f;
        if (brandedIOS6Style && [self brandedCommentsCountRight:&probeCountRight bubbleFrame:CGRectMake(0.0f, 0.0f, probeBubbleWidth, 0.0f)])
            reactionsTrailingWidth += MAX(0.0f, probeBubbleWidth - probeCountRight - contentTrailingInset);
        reactionsLayout = [_reactionsModel layoutWithMaximumWidth:contentContainerWidth trailingWidth:reactionsTrailingWidth trailingHeight:_dateModel.frame.size.height];
    }
    CGFloat backgroundWidth = MAX(brandedIOS6Style ? 60.0f : 40.0f, MAX(MAX(headerSize.width, contentSize.width) + backgroundHorizontalChrome, infoWidth + (brandedIOS6Style ? 20.0f : backgroundHorizontalChrome)));
    if (inlineMessageLayout)
        backgroundWidth = MAX(60.0f, MAX(headerSize.width, contentSize.width) + backgroundHorizontalChrome);
    CGFloat commentsFooterHeight = [self discussionCommentsFooterHeight];
    if (commentsFooterHeight > FLT_EPSILON)
    {
        backgroundWidth = MAX(backgroundWidth, MIN(maximumBubbleWidth, [self discussionCommentsFooterMinimumWidth]));
    }
    if (reactionsLayout != nil)
        backgroundWidth = MAX(backgroundWidth, MIN(maximumBubbleWidth, reactionsLayout.size.width + backgroundHorizontalChrome));
    if (!brandedIOS6Style)
    {
        backgroundWidth = MIN(backgroundWidth, maximumBubbleWidth);
        if (hasReactions)
            reactionsLayout = [_reactionsModel layoutWithMaximumWidth:MAX(1.0f, backgroundWidth - backgroundHorizontalChrome) trailingWidth:reactionsTrailingWidth trailingHeight:_dateModel.frame.size.height];
    }
    CGFloat reactionsBlockHeight = reactionsLayout != nil ? (TGMessageReactionsCurrentMetrics().topSpacing + reactionsLayout.size.height) : 0.0f;
    CGFloat backgroundVerticalPadding = inlineMessageLayout ? (layoutConstants->textBubblePaddingTop + layoutConstants->textBubblePaddingBottom) : (brandedIOS6Style ? (brandedBubbleInsets.top + brandedBubblePadding.top + brandedBubblePadding.bottom + brandedBubbleInsets.bottom) : TGMessageFontMetric(12.0f));
    CGRect backgroundFrame = CGRectMake(_incomingAppearance ? (avatarOffset + layoutConstants->leftInset) : (containerSize.width - backgroundWidth - layoutConstants->rightInset - unsentOffset), topSpacing, backgroundWidth, MAX(((_hasAvatar && webPageSize.height <= FLT_EPSILON) ? 44.0f : (webpageOnly ? 0.0 : ((brandedIOS6Style || inlineMessageLayout) ? 30.0f : 35.0f))), headerSize.height + contentSize.height + backgroundVerticalPadding));
    if (classicIOS6Style && !brandedIOS6Style)
    {
        backgroundFrame.size.height += 7.0f;
    }
    if (_incomingAppearance && _editing)
        backgroundFrame.origin.x += 42.0f;
    
    if (!_editing && fabs(_replyPanOffset) > FLT_EPSILON)
        backgroundFrame.origin.x += _replyPanOffset;
    
    if (contentSize.height <= FLT_EPSILON && _webPageFooterModel == nil) {
        backgroundFrame.size.height -= 10.0f;
    }
    
    if (_webPageFooterModel != nil)
    {
        backgroundFrame.size.height += webPageSize.height;
    }
    backgroundFrame.size.height += reactionsBlockHeight;
    if (commentsFooterHeight > FLT_EPSILON)
    {
        backgroundFrame.size.height += commentsFooterHeight;
    }

    CGSize previousContentModelSize = _contentModel.frame.size;
    CGFloat contentWidth = inlineMessageLayout ? MAX(32.0f, MAX(headerSize.width, contentSize.width) + 2.0f + (_incomingAppearance ? 0.0f : 5.0f)) : MAX(32.0f, backgroundFrame.size.width - contentLeftInset - contentTrailingInset);
    CGFloat contentTop = inlineMessageLayout ? topSpacing + 2.0f : (brandedIOS6Style ? (topSpacing + brandedBubbleInsets.top + brandedBubblePadding.top - layoutConstants->textBubbleTextOffsetTop) : (topSpacing + TGMessageFontMetric(6.0f) - layoutConstants->textBubbleTextOffsetTop));
    CGFloat contentBottomPadding = inlineMessageLayout ? 5.0f : layoutConstants->textBubbleTextOffsetTop;
    CGFloat contentHeight = MAX(headerSize.height + contentSize.height + contentBottomPadding, (_hasAvatar && webPageSize.height <= FLT_EPSILON) ? 30.0f : (webpageOnly ? 0.0f : 14.0f)) + webPageSize.height + reactionsBlockHeight;
    if (!brandedIOS6Style && !inlineMessageLayout)
        contentHeight = MAX(contentHeight, backgroundFrame.size.height - commentsFooterHeight - (contentTop - topSpacing) - TGMessageFontMetric(6.0f));
    CGFloat statusVerticalOffset = !brandedIOS6Style && reactionsLayout != nil ? TGMessageFontMetric(3.0f) : 0.0f;
    CGFloat contentDrawingHeight = contentHeight + statusVerticalOffset;
    if (_inhibitContentAnimation)
    {
        [UIView performWithoutAnimation:^
        {
             _contentModel.frame = CGRectMake(backgroundFrame.origin.x + contentLeftInset, contentTop, contentWidth, contentDrawingHeight);
        }];
    }
    else
    {
        _contentModel.frame = CGRectMake(backgroundFrame.origin.x + contentLeftInset, contentTop, contentWidth, contentDrawingHeight);
    }
    if (!CGSizeEqualToSize(_contentModel.frame.size, previousContentModelSize)) {
        updateContents = true;
    }
    
    _backgroundModel.frame = backgroundFrame;
    
    if (_actionButtonModel != nil) {
        _actionButtonModel.frame = CGRectOffset(_actionButtonModel.bounds, CGRectGetMaxX(backgroundFrame) + 7.0f, CGRectGetMaxY(backgroundFrame) - 29.0f - 1.0f);
    }
    
    if (_webPageFooterModel != nil)
    {
        [_webPageFooterModel updateSpecialViewsPositions:CGPointMake(_itemPosition.x + _webPageFooterModel.frame.origin.x, _itemPosition.y + headerSize.height + contentSize.height)];
        
        [_webPageFooterModel layoutForContainerSize:contentContainerSize contentSize:contentSize infoWidth:layoutInfoWidth needsContentUpdate:&updateContents bottomInset:NULL];
        
        _webPageFooterModel.frame = CGRectMake(0.0f, headerSize.height + contentSize.height, _webPageFooterModel.frame.size.width, _webPageFooterModel.frame.size.height);
    }
    
    _adminModel.frame = CGRectMake(_contentModel.frame.size.width - _adminModel.frame.size.width - 3.0f, 3.0f + TGScreenPixel, _adminModel.frame.size.width, _adminModel.frame.size.height);
    
    if (_authorNameModel != nil)
    {
        CGRect authorModelFrame = _authorNameModel.frame;
        authorModelFrame.origin.x = isRTL ? (_contentModel.frame.size.width - authorModelFrame.size.width - 1.0f) : 1.0f;
        _authorNameModel.frame = authorModelFrame;
        
        CGRect viaUserFrame = _viaUserModel.frame;
        viaUserFrame.origin.x = isRTL ? authorModelFrame.origin.x - viaUserFrame.size.width - 4.0f : (CGRectGetMaxX(authorModelFrame) + 4.0f);
        _viaUserModel.frame = viaUserFrame;
        
        CGRect adminModelFrame = _adminModel.frame;
        adminModelFrame.origin.x = isRTL ? 1.0f : _contentModel.frame.size.width - _adminModel.frame.size.width - 3.0f;
        adminModelFrame.origin.y = 3.0f + TGScreenPixel;
        _adminModel.frame = adminModelFrame;
    } else if (_viaUserModel != nil) {
        CGRect viaUserFrame = _viaUserModel.frame;
        viaUserFrame.origin.x = isRTL ? (_contentModel.frame.size.width - viaUserFrame.size.width - 1.0f) : 1.0f;
        _viaUserModel.frame = viaUserFrame;
    }
    
    if (_forwardedHeaderModel != nil)
    {
        CGRect forwardedHeaderFrame = _forwardedHeaderModel.frame;
        forwardedHeaderFrame.origin.x = isRTL ? (_contentModel.frame.size.width - forwardedHeaderFrame.size.width - 1.0f) : 1.0f;
        _forwardedHeaderModel.frame = forwardedHeaderFrame;
    }
    
    if (_replyHeaderModel != nil)
    {
        CGRect replyHeaderFrame = _replyHeaderModel.frame;
        replyHeaderFrame.origin.x = isRTL ? (_contentModel.frame.size.width - replyHeaderFrame.size.width - 1.0f) : 1.0f;
        _replyHeaderModel.frame = replyHeaderFrame;
    }
    
    [self layoutContentForHeaderHeight:headerSize.height containerSize:CGSizeMake(contentWidth, contentHeight)];
    
    CGFloat dateCapHeight = CGFloor((CGFloat)CTFontGetCapHeight(dateFont));
    CGFloat infoRight = _contentModel.frame.size.width;
    CGFloat dateRightInset = inlineMessageLayout ? (_incomingAppearance ? 3.0f + TGScreenPixel : 20.0f) : (brandedIOS6Style ? (_incomingAppearance ? 0.0f : TGContentBubbleBrandedChecksWidth + TGContentBubbleBrandedChecksSpacing) : statusWidth);
    CGFloat dateX = _contentModel.frame.size.width - dateRightInset - _dateModel.frame.size.width;
    CGFloat dateBaseline = TGRetinaFloor(CGRectGetMaxY(backgroundFrame) - commentsFooterHeight - TGMessageFontMetric(6.0f) - _contentModel.frame.origin.y - (CGFloat)CTFontGetDescent(dateFont));
    CGFloat dateY = brandedIOS6Style ? (_contentModel.frame.size.height - brandedAppearance.bubbleTimeRowHeight) : (dateBaseline - _dateModel.frame.size.height);
    if (inlineMessageLayout)
        dateY = contentHeight - TGMessageFontMetric(18.0f) - (TGIsLocaleArabic() ? 1.0f : 0.0f);
    CGFloat reactionsTop = 0.0f;
    if (reactionsLayout != nil)
    {
        reactionsTop = contentHeight - contentBottomPadding - reactionsLayout.size.height;
        if (brandedIOS6Style)
            dateY = reactionsTop + reactionsLayout.size.height - _dateModel.frame.size.height;
        else
            dateY = TGRetinaFloor(reactionsTop + CGRectGetMaxY(reactionsLayout.trailingFrame) - (CGFloat)CTFontGetDescent(dateFont)) - _dateModel.frame.size.height;
    }
    dateY += statusVerticalOffset;
    CGFloat brandedFooterTop = 0.0f;
    if (brandedIOS6Style && [self brandedCommentsFooterTop:&brandedFooterTop bubbleFrame:backgroundFrame])
    {
        CGFloat dateBottom = _contentModel.frame.origin.y + dateY + _dateModel.frame.size.height;
        backgroundFrame.size.height -= brandedFooterTop - brandedAppearance.commentsTimeBottomSpacing - dateBottom;
        _backgroundModel.frame = backgroundFrame;
        if (_actionButtonModel != nil)
            _actionButtonModel.frame = CGRectOffset(_actionButtonModel.bounds, CGRectGetMaxX(backgroundFrame) + 7.0f, CGRectGetMaxY(backgroundFrame) - 29.0f - 1.0f);
    }
    CGFloat dateShiftX = 0.0f;
    CGFloat brandedCountRight = 0.0f;
    if (brandedIOS6Style && [self brandedCommentsCountRight:&brandedCountRight bubbleFrame:backgroundFrame])
    {
        CGFloat alignedDateX = CGFloor(brandedCountRight - _contentModel.frame.origin.x - dateRightInset - _dateModel.frame.size.width);
        dateShiftX = alignedDateX - dateX;
        dateX = alignedDateX;
    }
    _dateModel.frame = CGRectMake(dateX, dateY, _dateModel.frame.size.width, _dateModel.frame.size.height);

    [_reactionsModel applyLayout:reactionsLayout origin:CGPointMake(_contentModel.frame.origin.x + 1.0f, _contentModel.frame.origin.y + reactionsTop)];
    
    _editedLabelModel.frame = CGRectMake(_dateModel.frame.origin.x - _editedLabelModel.frame.size.width - infoItemSpacing, CGRectGetMaxY(_dateModel.frame) - _editedLabelModel.frame.size.height, _editedLabelModel.frame.size.width, _editedLabelModel.frame.size.height);
    
    if (_broadcastIconModel != nil)
    {
        _broadcastIconModel.frame = (CGRect){{_dateModel.frame.origin.x - 5.0f - _broadcastIconModel.frame.size.width, _dateModel.frame.origin.y + 3.0f + TGScreenPixel}, _broadcastIconModel.frame.size};
    }
    
    CGFloat signatureSize = (hasSignature ? (_authorSignatureModel.frame.size.width + 8.0f) : 0.0f);
    
    CGFloat dateBaselineY = CGRectGetMaxY(_dateModel.frame);
    if (_progressModel != nil) {
        if (!brandedIOS6Style && !inlineMessageLayout && !_incomingAppearance) {
            CGFloat clockSize = TGMessageFontMetric(15.0f);
            _progressModel.frame = CGRectMake(_contentModel.frame.origin.x + infoRight - clockSize, _contentModel.frame.origin.y + dateBaselineY - CGRound((dateCapHeight + clockSize) / 2.0f), clockSize, clockSize);
        } else if (_incomingAppearance) {
            _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - _dateModel.frame.size.width - 27.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
        } else {
            _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - 23.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
        }
    }
    
    if (_authorSignature.length != 0) {
        CGFloat minX = _dateModel.frame.origin.x;
        if (_editedLabelModel != nil) {
            minX = _editedLabelModel.frame.origin.x;
        }
        CGFloat signatureY = brandedIOS6Style ? (_dateModel.frame.origin.y - 1.0f) : (dateBaselineY - _authorSignatureModel.frame.size.height);
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
        CGFloat viewsSpacing = brandedIOS6Style ? 6.0f : infoItemSpacing;
        _messageViewsModel.frame = CGRectMake(minX - _messageViewsModel.frame.size.width - viewsSpacing + _contentModel.frame.origin.x, viewsY + _contentModel.frame.origin.y, _messageViewsModel.frame.size.width, _messageViewsModel.frame.size.height);
    }
    
    CGPoint stateOffset = _contentModel.frame.origin;
    CGFloat checkWidth = brandedIOS6Style ? 12.0f : TGMessageFontMetric(12.0f);
    CGFloat checkHeight = brandedIOS6Style ? TGContentBubbleCheckSize : TGMessageFontMetric(TGContentBubbleCheckSize);
    CGFloat checksY = brandedIOS6Style ? CGFloor(CGRectGetMidY(_dateModel.frame) - 5.5f) : (dateBaselineY - CGRound((dateCapHeight + checkHeight) / 2.0f));
    if (inlineMessageLayout)
        checksY = contentHeight - 14.0f + TGScreenPixel;
    CGFloat secondCheckRightInset = checkWidth;
    CGFloat firstCheckRightInset = brandedIOS6Style ? TGContentBubbleBrandedChecksWidth : (secondCheckRightInset + TGMessageFontMetric(TGContentBubbleSecondCheckOffset));
    if (inlineMessageLayout) {
        firstCheckRightInset = 17.0f;
        secondCheckRightInset = 13.0f;
        checkWidth = 12.0f;
        checkHeight = 11.0f;
    }
    if (_checkFirstModel != nil)
        _checkFirstModel.frame = CGRectMake((_checkFirstEmbeddedInContent ? 0.0f : stateOffset.x) + _contentModel.frame.size.width - firstCheckRightInset + dateShiftX, (_checkFirstEmbeddedInContent ? 0.0f : stateOffset.y) + checksY, checkWidth, checkHeight);
    
    if (_checkSecondModel != nil)
        _checkSecondModel.frame = CGRectMake((_checkSecondEmbeddedInContent ? 0.0f : stateOffset.x) + _contentModel.frame.size.width - secondCheckRightInset + dateShiftX, (_checkSecondEmbeddedInContent ? 0.0f : stateOffset.y) + checksY, checkWidth, checkHeight);

    if (_unsentButtonModel != nil)
    {
        _unsentButtonModel.frame = CGRectMake(containerSize.width - _unsentButtonModel.frame.size.width - 9, backgroundFrame.size.height + topSpacing + bottomSpacing - _unsentButtonModel.frame.size.height - ((_collapseFlags & TGModernConversationItemCollapseBottom) ? 5 : 6), _unsentButtonModel.frame.size.width, _unsentButtonModel.frame.size.height);
    }
    
    CGFloat replyButtonsHeight = 0.0f;
    if (_replyButtonsModel != nil) {
        CGRect backgroundFrame = _backgroundModel.frame;
        CGFloat backgroundExtension = 5.0f;
        
        CGFloat replyButtonsAvailableWidth = _incomingAppearance ? (containerSize.width - 44.0f - backgroundFrame.origin.x) : (CGRectGetMaxX(backgroundFrame) - 44.0f);
        [_replyButtonsModel layoutForContainerSize:CGSizeMake(MAX(backgroundFrame.size.width + backgroundExtension, MIN([_replyButtonsModel minimumWidth], replyButtonsAvailableWidth)), containerSize.height)];
        
        _replyButtonsModel.frame = CGRectMake((_incomingAppearance ? backgroundFrame.origin.x : (CGRectGetMaxX(backgroundFrame) - _replyButtonsModel.frame.size.width)) + (_backgroundModel == nil ? (_incomingAppearance ? -5.0f : 5.0f) : 0.0f), CGRectGetMaxY(backgroundFrame), _replyButtonsModel.frame.size.width, _replyButtonsModel.frame.size.height);
        replyButtonsHeight = _replyButtonsModel.frame.size.height;
        self.avatarOffset = replyButtonsHeight;
    }
    
    self.frame = CGRectMake(0, 0, containerSize.width, backgroundFrame.size.height + topSpacing + bottomSpacing + replyButtonsHeight);
    
    bool tiledMode = _contentModel.frame.size.height > TGModernFlatteningViewModelTilingLimit;
    [_contentModel setTiledMode:tiledMode];
    self.needsRelativeBoundsUpdates = tiledMode;
    
    if (updateContents)
    {
        [_contentModel setNeedsSubmodelContentsUpdate];
        [_contentModel updateSubmodelContentsIfNeeded];
    }
    
    [super layoutForContainerSize:containerSize];
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
        NSDictionary *options = self.groupedLayout.documentGroup ? @{@"groupedId": @(_message.groupedId), @"peerId": @(_message.cid)} : @{@"mid": @(_mid), @"peerId": @(_message.cid)};
        [_context.companionHandle requestAction:@"fastForwardMessage" options:options];
    }
}

- (void)imageDataInvalidated:(NSString *)imageUrl {
    [_webPageFooterModel imageDataInvalidated:imageUrl];
}

- (void)stopInlineMedia:(int32_t)excludeMid
{
    [_webPageFooterModel stopInlineMedia:excludeMid];
}

- (void)resumeInlineMedia {
    [_webPageFooterModel resumeInlineMedia];
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
