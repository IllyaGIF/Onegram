#import "TGOnegramSettings.h"
#import "TGNotificationMessageViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGModernImageViewModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernTextViewModel.h"

#import "TGModernDataImageViewModel.h"
#import "TGModernDataImageView.h"

#import "TGModernRemoteImageView.h"

#import "TGReusableLabel.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDoubleTapGestureRecognizer.h"

#import "TGTelegraph.h"

#import "TGCurrencyFormatter.h"

#import "TGChannelAdminLogEntry.h"

#import "TGPresentation.h"
#import "TGCommunitySignals.h"
#import "TGModernButtonViewModel.h"
#import "TGAnimatedStickerViewModel.h"
#import "TGAnimatedStickerView.h"
#import "TGStickersSignals.h"
#import "TGStarGiftTileView.h"
#import "TGStarGiftMessageCardView.h"
#import "TGStarGift.h"
#import "../OnegramRuntime/OGPluginAvailability.h"
#if OG_PLUGINS_AVAILABLE
#import "../OnegramPlugins/OGPluginUI.h"
#endif

@interface TGNotificationMessageViewModel () <UIGestureRecognizerDelegate, TGDoubleTapGestureRecognizerDelegate>
{
    TGModernImageViewModel *_backgroundModel;
    TGModernFlatteningViewModel *_contentModel;
    TGModernTextViewModel *_textModel;
    TGModernDataImageViewModel *_imageModel;
    
    UITapGestureRecognizer *_tapRecognizer;
    TGDoubleTapGestureRecognizer *_boundDoubleTapRecognizer;
    TGDoubleTapGestureRecognizer *_boundImageTapRecognizer;
    
    int32_t _navigateToMessageId;
    int32_t _callForMessageId;
    TGStickerPackIdReference *_stickerPackReference;
    
    TGActionMediaAttachment *_actionMedia;
    TGMessage *_message;
    id _authorPeer;
    NSArray *_additionalUsers;
}

@end

#if OG_PLUGINS_AVAILABLE
@interface TGPluginServiceMessageViewModel ()
{
    TGMessage *_serviceMessage;
    NSDictionary *_description;
    TGModernImageViewModel *_serviceBackdrop;
    TGModernFlatteningViewModel *_serviceContent;
    TGModernTextViewModel *_serviceTitle;
    TGModernTextViewModel *_serviceSubtitle;
    TGModernTextViewModel *_serviceHint;
    TGModernTextViewModel *_serviceEmoji;
    TGAnimatedStickerViewModel *_serviceSticker;
    NSMutableArray *_serviceButtons;
    UILongPressGestureRecognizer *_serviceLongPress;
}

@end

static UIImage *TGPluginServiceGiftImage(CGSize size, bool dark, bool classic)
{
    static NSCache *images = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ images = [[NSCache alloc] init]; images.totalCostLimit = 3 * 1024 * 1024; });
    NSString *key = [[NSString alloc] initWithFormat:@"%d:%d:%d:%d", (int)size.width, (int)size.height, dark, classic];
    UIImage *image = [images objectForKey:key];
    if (image == nil)
    {
        UIColor *center = dark ? [UIColor colorWithRed:0.46f green:0.34f blue:0.20f alpha:1.0f] : [UIColor colorWithRed:1.0f green:0.91f blue:0.64f alpha:1.0f];
        UIColor *edge = dark ? [UIColor colorWithRed:0.30f green:0.23f blue:0.15f alpha:1.0f] : [UIColor colorWithRed:0.88f green:0.70f blue:0.39f alpha:1.0f];
        image = TGStarGiftBackdropImage(size, center, edge, classic ? 12.0f : 17.0f);
        if (image != nil)
            [images setObject:image forKey:key cost:(NSUInteger)(size.width * size.height * 4.0f)];
    }
    return image;
}

@implementation TGPluginServiceMessageViewModel

- (instancetype)initWithMessage:(TGMessage *)message description:(NSDictionary *)description context:(TGModernViewContext *)context
{
    self = [super initWithAuthorPeer:nil context:context];
    if (self != nil)
    {
        _mid = message.mid;
        _serviceMessage = message;
        _description = [description copy];
        bool gift = [_description[@"style"] isEqualToString:@"gift"];
        UIColor *primary = gift ? (context.presentation.pallete.isDark ? [UIColor colorWithRed:1.0f green:0.92f blue:0.73f alpha:1.0f] : [UIColor colorWithRed:0.32f green:0.22f blue:0.08f alpha:1.0f]) : context.presentation.pallete.chatSystemTextColor;
        _serviceBackdrop = [[TGModernImageViewModel alloc] initWithImage:context.presentation.images.chatSystemBackground];
        _serviceBackdrop.skipDrawInContext = true;
        [self addSubmodel:_serviceBackdrop];
        _serviceContent = [[TGModernFlatteningViewModel alloc] initWithContext:context];
        _serviceContent.viewUserInteractionDisabled = true;
        [self addSubmodel:_serviceContent];
        _serviceTitle = [[TGModernTextViewModel alloc] initWithText:_description[@"title"] font:TGCoreTextMediumFontOfSize(gift ? 16.0f : 14.0f)];
        _serviceTitle.alignment = NSTextAlignmentCenter;
        _serviceTitle.textColor = primary;
        _serviceTitle.layoutFlags = TGReusableLabelLayoutMultiline;
        [_serviceContent addSubmodel:_serviceTitle];
        NSString *subtitle = [_description[@"subtitle"] isKindOfClass:[NSString class]] ? _description[@"subtitle"] : @"";
        _serviceSubtitle = [[TGModernTextViewModel alloc] initWithText:subtitle font:TGCoreTextSystemFontOfSize(12.0f)];
        _serviceSubtitle.alignment = NSTextAlignmentCenter;
        _serviceSubtitle.textColor = primary;
        _serviceSubtitle.layoutFlags = TGReusableLabelLayoutMultiline;
        [_serviceContent addSubmodel:_serviceSubtitle];
        NSString *hint = [_description[@"hint"] isKindOfClass:[NSString class]] ? _description[@"hint"] : @"";
        _serviceHint = [[TGModernTextViewModel alloc] initWithText:hint font:TGCoreTextSystemFontOfSize(11.0f)];
        _serviceHint.alignment = NSTextAlignmentCenter;
        _serviceHint.textColor = primary;
        _serviceHint.layoutFlags = TGReusableLabelLayoutMultiline;
        [_serviceContent addSubmodel:_serviceHint];
        NSString *emoji = [_description[@"emoji"] isKindOfClass:[NSString class]] ? _description[@"emoji"] : @"";
        NSNumber *documentId = [_description[@"document_id"] isKindOfClass:[NSNumber class]] ? _description[@"document_id"] : nil;
        NSString *documentPath = [_description[@"document_path"] isKindOfClass:[NSString class]] ? _description[@"document_path"] : nil;
        NSString *documentFormat = [_description[@"document_format"] isKindOfClass:[NSString class]] ? [_description[@"document_format"] lowercaseString] : nil;
        if (documentId.longLongValue > 0 && [documentPath isAbsolutePath])
        {
            NSString *resolved = [[documentPath stringByStandardizingPath] stringByResolvingSymlinksInPath];
            NSString *home = [NSHomeDirectory() stringByResolvingSymlinksInPath];
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:resolved error:NULL];
            NSString *extension = [[resolved pathExtension] lowercaseString];
            if ([resolved hasPrefix:[home stringByAppendingString:@"/"]] && attributes != nil && [attributes fileSize] > 0 &&
                [attributes fileSize] <= 4 * 1024 * 1024 && [extension isEqualToString:documentFormat])
            {
                if ([extension isEqualToString:@"tgs"] || [extension isEqualToString:@"webm"])
                {
                    TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] init];
                    document.documentId = documentId.longLongValue;
                    document.documentUri = [[NSURL fileURLWithPath:resolved] absoluteString];
                    document.mimeType = [extension isEqualToString:@"tgs"] ? @"application/x-tgsticker" : @"video/webm";
                    _serviceSticker = [[TGAnimatedStickerViewModel alloc] initWithDocument:document placeholderUri:nil];
                    [self addSubmodel:_serviceSticker];
                }
            }
        }
        if (_serviceSticker == nil && documentId.longLongValue != 0)
        {
            NSDictionary *packs = [TGStickersSignals cachedStickerPacks];
            for (TGStickerPack *pack in packs[@"packs"])
            {
                for (TGDocumentMediaAttachment *document in pack.documents)
                {
                    if (document.documentId == documentId.longLongValue && [TGAnimatedStickerView isAnimatedStickerDocument:document])
                    {
                        _serviceSticker = [[TGAnimatedStickerViewModel alloc] initWithDocument:document placeholderUri:[TGAnimatedStickerView placeholderUriForDocument:document size:CGSizeMake(92.0f, 92.0f)]];
                        [self addSubmodel:_serviceSticker];
                        break;
                    }
                }
                if (_serviceSticker != nil)
                    break;
            }
        }
        if (_serviceSticker == nil && emoji.length != 0)
        {
            _serviceEmoji = [[TGModernTextViewModel alloc] initWithText:emoji font:TGCoreTextSystemFontOfSize(gift ? 42.0f : 28.0f)];
            _serviceEmoji.alignment = NSTextAlignmentCenter;
            [_serviceContent addSubmodel:_serviceEmoji];
        }
        _serviceButtons = [[NSMutableArray alloc] init];
        TGMessageViewModelReference *lifetime = [self lifetimeReference];
        for (NSDictionary *button in _description[@"buttons"])
        {
            NSString *identifier = button[@"identifier"];
            if (![identifier isKindOfClass:[NSString class]] || ![button[@"title"] isKindOfClass:[NSString class]])
                continue;
            TGModernButtonViewModel *buttonModel = [[TGModernButtonViewModel alloc] init];
            buttonModel.title = button[@"title"];
            buttonModel.font = [UIFont boldSystemFontOfSize:14.0f];
            buttonModel.titleColor = gift && context.presentation.pallete.isDark ? [UIColor whiteColor] : gift ? [UIColor colorWithRed:0.30f green:0.20f blue:0.05f alpha:1.0f] : context.presentation.pallete.chatSystemTextColor;
            buttonModel.backgroundImage = context.presentation.images.chatSystemBackground;
            buttonModel.modernHighlight = true;
            __weak TGModernButtonViewModel *weakButton = buttonModel;
            buttonModel.pressed = ^
            {
                [lifetime withValue:^(void *value)
                {
                    TGPluginServiceMessageViewModel *strongSelf = (__bridge TGPluginServiceMessageViewModel *)value;
                    if (strongSelf == nil)
                        return;
                    [weakButton setDisplayProgress:true animated:true];
                    OGPluginUIServiceMessageAction(strongSelf->_serviceMessage.cid, strongSelf->_mid,
                                                    strongSelf->_serviceMessage.text.length != 0 ? strongSelf->_serviceMessage.text : strongSelf->_serviceMessage.caption,
                                                    strongSelf->_serviceMessage.outgoing, [strongSelf->_serviceMessage.caption hasPrefix:@"tg-streaks:sync:offer"], identifier);
                }];
            };
            [_serviceButtons addObject:buttonModel];
            [self addSubmodel:buttonModel];
        }
    }
    return self;
}

- (CGRect)effectiveContentFrame
{
    return _serviceBackdrop.frame;
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    _serviceLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(serviceLongPressed:)];
    _serviceLongPress.minimumPressDuration = 0.5;
    [[_serviceBackdrop boundView] addGestureRecognizer:_serviceLongPress];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    [[_serviceBackdrop boundView] removeGestureRecognizer:_serviceLongPress];
    _serviceLongPress = nil;
    [super unbindView:viewStorage];
}

- (void)serviceLongPressed:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan)
        [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_serviceMessage.cid)}];
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    [_serviceBackdrop bindViewToContainer:container viewStorage:viewStorage];
    [_serviceBackdrop boundView].frame = CGRectOffset([_serviceBackdrop boundView].frame, itemPosition.x, itemPosition.y);
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    bool gift = [_description[@"style"] isEqualToString:@"gift"];
    CGFloat width = MIN(gift ? 270.0f : 300.0f, MAX(140.0f, containerSize.width - 36.0f));
    CGFloat padding = gift ? 18.0f : 12.0f;
    CGFloat inner = width - padding * 2.0f;
    CGFloat y = gift ? 13.0f : 7.0f;
    if (_serviceSticker != nil)
    {
        _serviceSticker.frame = CGRectMake(CGFloor((containerSize.width - 90.0f) / 2.0f), y, 90.0f, 90.0f);
        y += 96.0f;
    }
    else if (_serviceEmoji != nil)
    {
        [_serviceEmoji layoutForContainerSize:CGSizeMake(inner, 90.0f)];
        _serviceEmoji.frame = CGRectMake(CGFloor((inner - _serviceEmoji.frame.size.width) / 2.0f), y, _serviceEmoji.frame.size.width, _serviceEmoji.frame.size.height);
        y += _serviceEmoji.frame.size.height + 4.0f;
    }
    NSArray *models = @[_serviceTitle, _serviceSubtitle, _serviceHint];
    for (TGModernTextViewModel *label in models)
    {
        if (label.text.length == 0)
            continue;
        [label layoutForContainerSize:CGSizeMake(inner, CGFLOAT_MAX)];
        label.frame = CGRectMake(CGFloor((inner - label.frame.size.width) / 2.0f), y, label.frame.size.width, label.frame.size.height);
        y += label.frame.size.height + (label == _serviceTitle ? 8.0f : 7.0f);
    }
    if (_serviceButtons.count != 0)
        y += 3.0f;
    CGFloat height = y + (_serviceButtons.count != 0 ? 42.0f : 0.0f) + padding;
    CGFloat x = CGFloor((containerSize.width - width) / 2.0f);
    _serviceBackdrop.frame = CGRectMake(x, 3.0f, width, height);
    if (gift)
        _serviceBackdrop.image = TGPluginServiceGiftImage(CGSizeMake(width, height), _context.presentation.pallete.isDark, [TGPresentation classicIOS6Style]);
    _serviceContent.frame = CGRectMake(x + padding, 3.0f, inner, height);
    CGFloat buttonWidth = (_serviceButtons.count == 1 ? inner : (inner - 8.0f) / 2.0f);
    for (NSUInteger index = 0; index < _serviceButtons.count; index++)
    {
        TGModernButtonViewModel *button = _serviceButtons[index];
        button.frame = CGRectMake(x + padding + index * (buttonWidth + 8.0f), y + 3.0f, buttonWidth, 36.0f);
    }
    [_serviceContent setNeedsSubmodelContentsUpdate];
    [_serviceContent updateSubmodelContentsIfNeeded];
    self.frame = CGRectMake(0.0f, 0.0f, containerSize.width, height + 6.0f);
    [super layoutForContainerSize:containerSize];
}

@end
#endif

static NSString *const TGStarGiftMessageExpandedKey = @"starGiftTextExpanded";
static NSString *const TGStarGiftMessagePlayedKey = @"starGiftAnimationPlayed";
static const int64_t TGStarGiftMessageNotificationsPeerId = 777000;
static const CGFloat TGStarGiftMessageWidth = 220.0f;
static const NSUInteger TGStarGiftMessageCollapsedLines = 4;

@interface TGStarGiftMessageCardModel : TGModernViewModel

@property (nonatomic, strong) TGStarGiftMessageCardContent *content;
@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic, copy) void (^pressed)(CGPoint point);
@property (nonatomic, copy) void (^buttonPressed)(void);
@property (nonatomic, copy) void (^creatorPressed)(void);
@property (nonatomic, copy) void (^longPressed)(void);
@property (nonatomic, copy) void (^stickerFinished)(void);

- (void)playStickerOnce;

@end

@implementation TGStarGiftMessageCardModel

- (Class)viewClass
{
    return [TGStarGiftMessageCardView class];
}

- (void)setContent:(TGStarGiftMessageCardContent *)content
{
    _content = content;
    [(TGStarGiftMessageCardView *)[self boundView] setContent:content];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    TGStarGiftMessageCardView *view = (TGStarGiftMessageCardView *)[self boundView];
    view.presentation = _presentation;
    view.pressed = _pressed;
    view.buttonPressed = _buttonPressed;
    view.creatorPressed = _creatorPressed;
    view.longPressed = _longPressed;
    view.stickerFinished = _stickerFinished;
    [view setContent:_content];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    TGStarGiftMessageCardView *view = (TGStarGiftMessageCardView *)[self boundView];
    view.pressed = nil;
    view.buttonPressed = nil;
    view.creatorPressed = nil;
    view.longPressed = nil;
    view.stickerFinished = nil;
    [super unbindView:viewStorage];
}

- (void)playStickerOnce
{
    [(TGStarGiftMessageCardView *)[self boundView] playStickerOnce];
}

@end

static NSString *TGStarGiftMessageFormat(NSString *format, NSArray *arguments, NSRange *ranges)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    NSUInteger length = format.length;
    NSUInteger sequentialIndex = 0;
    NSUInteger index = 0;
    while (index < length)
    {
        unichar character = [format characterAtIndex:index];
        if (character == '%' && index + 1 < length)
        {
            if ([format characterAtIndex:index + 1] == '%')
            {
                [result appendString:@"%"];
                index += 2;
                continue;
            }
            NSUInteger cursor = index + 1;
            NSUInteger number = 0;
            while (cursor < length && [format characterAtIndex:cursor] >= '0' && [format characterAtIndex:cursor] <= '9')
            {
                number = number * 10 + (NSUInteger)([format characterAtIndex:cursor] - '0');
                cursor++;
            }
            NSUInteger argumentIndex = sequentialIndex;
            if (cursor > index + 1 && cursor < length && [format characterAtIndex:cursor] == '$' && number > 0)
            {
                argumentIndex = number - 1;
                cursor++;
            }
            else
                cursor = index + 1;
            if (cursor < length && [format characterAtIndex:cursor] == '@' && argumentIndex < arguments.count)
            {
                NSString *argument = arguments[argumentIndex];
                ranges[argumentIndex] = NSMakeRange(result.length, argument.length);
                [result appendString:argument];
                sequentialIndex++;
                index = cursor + 1;
                continue;
            }
        }
        [result appendFormat:@"%C", character];
        index++;
    }
    return result;
}

static void TGStarGiftMessageSetFormattedText(TGModernTextViewModel *model, NSString *format, NSArray *arguments, NSArray *peerIds, NSIndexSet *boldArguments, CTFontRef boldFont)
{
    NSRange ranges[4];
    for (NSUInteger index = 0; index < 4; index++)
        ranges[index] = NSMakeRange(NSNotFound, 0);
    NSArray *effectiveArguments = arguments.count > 4 ? [arguments subarrayWithRange:NSMakeRange(0, 4)] : arguments;
    NSString *text = TGStarGiftMessageFormat(format, effectiveArguments, ranges);
    NSMutableArray *attributes = [[NSMutableArray alloc] init];
    NSMutableArray *links = [[NSMutableArray alloc] init];
    NSArray *fontAttributes = @[(__bridge id)boldFont, (__bridge NSString *)kCTFontAttributeName];
    for (NSUInteger index = 0; index < effectiveArguments.count; index++)
    {
        if (ranges[index].location == NSNotFound || ranges[index].length == 0)
            continue;
        int64_t peerId = index < peerIds.count ? [peerIds[index] longLongValue] : 0;
        if (peerId != 0 || [boldArguments containsIndex:index])
        {
            [attributes addObject:[NSValue valueWithRange:ranges[index]]];
            [attributes addObject:fontAttributes];
        }
        if (peerId != 0)
            [links addObject:[NSTextCheckingResult linkCheckingResultWithRange:ranges[index] URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-peer://%lld", peerId]]]];
    }
    model.text = text;
    model.additionalAttributes = attributes.count != 0 ? attributes : nil;
    model.textCheckingResults = links.count != 0 ? links : nil;
}

static void TGStarGiftMessageSetPlainText(TGModernTextViewModel *model, NSString *text)
{
    model.text = text ?: @"";
    model.additionalAttributes = nil;
    model.textCheckingResults = nil;
}

static NSString *TGStarGiftMessagePeerName(int64_t peerId)
{
    if (peerId == 0)
        return nil;
    if (TGPeerIdIsUser(peerId))
        return [TGDatabaseInstance() loadUser:peerId].displayFirstName;
    return [TGDatabaseInstance() loadConversationWithId:peerId].chatTitle;
}

static NSString *TGStarGiftMessagePeerUsername(int64_t peerId)
{
    if (peerId == 0)
        return nil;
    if (TGPeerIdIsUser(peerId))
        return [TGDatabaseInstance() loadUser:peerId].userName;
    return [TGDatabaseInstance() loadConversationWithId:peerId].username;
}

static NSString *TGStarGiftMessageStars(int64_t stars)
{
    return [effectiveLocalization() getPluralized:@"OnegramGifts.ChatStars" count:(int32_t)MIN(stars, (int64_t)INT32_MAX)];
}

static bool TGStarGiftMessageTextIsEmpty(TGModernTextViewModel *model)
{
    return model.text.length == 0 || [model.text isEqualToString:@" "];
}

static CTFontRef TGStarGiftMessageSemiboldFont(CGFloat size)
{
    return TGCoreTextMediumFontOfSize(size);
}

@interface TGStarGiftMessageViewModel ()
{
    TGMessage *_giftMessage;
    id _giftAuthorPeer;
    TGActionMediaAttachment *_giftAction;
    TGModernImageViewModel *_labelBackground;
    TGModernFlatteningViewModel *_labelContent;
    TGModernTextViewModel *_labelText;
    TGStarGiftMessageCardModel *_card;
    TGModernFlatteningViewModel *_giftContent;
    TGModernTextViewModel *_titleText;
    TGModernTextViewModel *_subtitleText;
    TGModernTextViewModel *_creatorText;
    TGModernTextViewModel *_messageText;
    NSArray *_attributeTitleTexts;
    NSArray *_attributeValueTexts;
    UITapGestureRecognizer *_labelTap;
    UILongPressGestureRecognizer *_labelLongPress;

    bool _cover;
    bool _hasLabel;
    bool _hasAttributes;
    bool _hasMessage;
    bool _canExpand;
    NSString *_buttonTitle;
    NSString *_buttonOperation;
    NSString *_ribbonTitle;
    NSArray *_ribbonColors;
    UIColor *_primaryColor;
    UIColor *_subtitleColor;
    UIColor *_overlayColor;
    UIColor *_plateColor;
    UIColor *_bubbleColor;
    int64_t _creatorPeerId;
    int64_t _messagePeerId;
}

@end

@implementation TGStarGiftMessageViewModel

- (instancetype)initWithMessage:(TGMessage *)message actionMedia:(TGActionMediaAttachment *)actionMedia authorPeer:(id)authorPeer context:(TGModernViewContext *)context
{
    self = [super initWithAuthorPeer:nil context:context];
    if (self != nil)
    {
        _mid = message.mid;
        _giftMessage = message;
        _giftAuthorPeer = authorPeer;
        _giftAction = actionMedia;

        _labelBackground = [[TGModernImageViewModel alloc] initWithImage:context.presentation.images.chatSystemBackground];
        _labelBackground.skipDrawInContext = true;
        [self addSubmodel:_labelBackground];

        _labelContent = [[TGModernFlatteningViewModel alloc] initWithContext:context];
        _labelContent.viewUserInteractionDisabled = true;
        [self addSubmodel:_labelContent];

        _labelText = [[TGModernTextViewModel alloc] initWithText:@"" font:[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleFont]];
        _labelText.textColor = context.presentation.pallete.chatSystemTextColor;
        _labelText.linkColor = context.presentation.pallete.chatSystemTextColor;
        _labelText.layoutFlags = TGReusableLabelLayoutMultiline;
        _labelText.alignment = NSTextAlignmentCenter;
        [_labelContent addSubmodel:_labelText];

        _card = [[TGStarGiftMessageCardModel alloc] init];
        _card.presentation = context.presentation;
        [self addSubmodel:_card];

        _giftContent = [[TGModernFlatteningViewModel alloc] initWithContext:context];
        _giftContent.viewUserInteractionDisabled = true;
        [self addSubmodel:_giftContent];

        _titleText = [[TGModernTextViewModel alloc] initWithText:@"" font:TGStarGiftMessageSemiboldFont(15.0f)];
        _titleText.alignment = NSTextAlignmentCenter;
        _titleText.layoutFlags = TGReusableLabelLayoutMultiline;
        [_giftContent addSubmodel:_titleText];

        _subtitleText = [[TGModernTextViewModel alloc] initWithText:@"" font:TGCoreTextSystemFontOfSize(13.0f)];
        _subtitleText.alignment = NSTextAlignmentCenter;
        _subtitleText.layoutFlags = TGReusableLabelLayoutMultiline;
        [_giftContent addSubmodel:_subtitleText];

        _creatorText = [[TGModernTextViewModel alloc] initWithText:@"" font:TGCoreTextSystemFontOfSize(12.0f)];
        _creatorText.alignment = NSTextAlignmentCenter;
        _creatorText.layoutFlags = TGReusableLabelLayoutMultiline;
        _creatorText.maxNumberOfLines = 2;
        [_giftContent addSubmodel:_creatorText];

        _messageText = [[TGModernTextViewModel alloc] initWithText:@"" font:TGCoreTextSystemFontOfSize(13.0f)];
        _messageText.alignment = NSTextAlignmentLeft;
        _messageText.layoutFlags = TGReusableLabelLayoutMultiline;
        [_giftContent addSubmodel:_messageText];

        NSMutableArray *attributeTitleTexts = [[NSMutableArray alloc] init];
        NSMutableArray *attributeValueTexts = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < 3; index++)
        {
            TGModernTextViewModel *titleText = [[TGModernTextViewModel alloc] initWithText:@"" font:TGCoreTextSystemFontOfSize(13.0f)];
            titleText.layoutFlags = TGReusableLabelLayoutMultiline;
            titleText.maxNumberOfLines = 1;
            [_giftContent addSubmodel:titleText];
            [attributeTitleTexts addObject:titleText];
            TGModernTextViewModel *valueText = [[TGModernTextViewModel alloc] initWithText:@"" font:TGStarGiftMessageSemiboldFont(13.0f)];
            valueText.layoutFlags = TGReusableLabelLayoutMultiline;
            valueText.maxNumberOfLines = 1;
            [_giftContent addSubmodel:valueText];
            [attributeValueTexts addObject:valueText];
        }
        _attributeTitleTexts = attributeTitleTexts;
        _attributeValueTexts = attributeValueTexts;

        TGMessageViewModelReference *lifetime = [self lifetimeReference];
        _card.pressed = ^(CGPoint point)
        {
            [lifetime withValue:^(void *value)
            {
                [(__bridge TGStarGiftMessageViewModel *)value cardPressedAtPoint:point];
            }];
        };
        _card.buttonPressed = ^
        {
            [lifetime withValue:^(void *value)
            {
                [(__bridge TGStarGiftMessageViewModel *)value buttonPressed];
            }];
        };
        _card.creatorPressed = ^
        {
            [lifetime withValue:^(void *value)
            {
                [(__bridge TGStarGiftMessageViewModel *)value creatorPressed];
            }];
        };
        _card.longPressed = ^
        {
            [lifetime withValue:^(void *value)
            {
                [(__bridge TGStarGiftMessageViewModel *)value requestSelection];
            }];
        };
        _card.stickerFinished = ^
        {
            [lifetime withValue:^(void *value)
            {
                [(__bridge TGStarGiftMessageViewModel *)value stickerFinished];
            }];
        };
        [self updateGiftContent];
    }
    return self;
}

- (void)updateGiftContent
{
    TGStarGift *gift = _giftAction.actionData[@"gift"];
    NSDictionary *data = _giftAction.actionData;
    TGPresentation *presentation = _context.presentation;
    int64_t accountPeerId = TGTelegraphInstance.clientUserId;
    int64_t chatPeerId = _giftMessage.cid;
    bool notificationsChat = chatPeerId == TGStarGiftMessageNotificationsPeerId;
    bool incoming = chatPeerId == accountPeerId || !_giftMessage.outgoing;
    int64_t fromPeerId = [data[@"fromPeerId"] longLongValue];
    int64_t toPeerId = [data[@"toPeerId"] longLongValue];
    int64_t ownerPeerId = [data[@"ownerPeerId"] longLongValue];
    int64_t authorPeerId = 0;
    if ([_giftAuthorPeer isKindOfClass:[TGUser class]])
        authorPeerId = ((TGUser *)_giftAuthorPeer).uid;
    else if ([_giftAuthorPeer isKindOfClass:[TGConversation class]])
        authorPeerId = ((TGConversation *)_giftAuthorPeer).conversationId;
    if (authorPeerId == 0)
        authorPeerId = _giftMessage.outgoing ? accountPeerId : _giftMessage.fromUid;
    bool authorIsAccount = authorPeerId == accountPeerId;
    NSString *messageString = data[@"message"];
    int64_t convertStars = [data[@"convertStars"] longLongValue];
    int64_t upgradeStars = [data[@"upgradeStars"] longLongValue];
    int64_t resaleStars = [data[@"resaleStars"] longLongValue];
    bool upgraded = [data[@"upgraded"] boolValue];
    bool prepaidUpgrade = [data[@"prepaidUpgrade"] boolValue];
    CTFontRef labelBoldFont = [[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont];
    UIColor *white = [UIColor whiteColor];

    _primaryColor = presentation.pallete.chatSystemTextColor;
    _plateColor = presentation.pallete.chatSystemBackgroundColor ?: [[TGTelegraphConversationMessageAssetsSource instance] systemMessageBackgroundColor];
    _cover = false;
    _hasLabel = true;
    _hasAttributes = false;
    _hasMessage = false;
    _buttonTitle = TGLocalized(@"OnegramGifts.ChatView");
    _buttonOperation = @"view";
    _ribbonTitle = nil;
    _ribbonColors = nil;
    _creatorPeerId = 0;
    _messagePeerId = 0;
    UIColor *outerColor = nil;

    NSString *title = TGLocalized(@"OnegramGifts.Gift");
    NSString *creatorUsername = gift.releasedByPeerId != 0 ? TGStarGiftMessagePeerUsername(gift.releasedByPeerId) : nil;
    if (creatorUsername.length != 0)
        _creatorPeerId = gift.releasedByPeerId;

    TGStarGiftMessageSetPlainText(_subtitleText, @"");
    _subtitleText.font = TGCoreTextSystemFontOfSize(13.0f);

    switch (_giftAction.actionType)
    {
        case TGMessageActionStarGiftUnique:
        {
            NSString *giftTitle = [[NSString alloc] initWithFormat:@"%@ #%@", gift.title ?: @"", TGStarGiftFormattedNumber(gift.number)];
            bool selfChat = chatPeerId == accountPeerId;
            int64_t messagePeerId = fromPeerId != 0 ? fromPeerId : (authorPeerId != 0 ? authorPeerId : (!incoming ? accountPeerId : 0));
            if (selfChat)
                title = TGLocalized([data[@"craft"] boolValue] ? @"OnegramGifts.ChatCrafted" : (upgraded ? @"OnegramGifts.ChatUpgraded" : @"OnegramGifts.ChatPurchased"));
            else if (!notificationsChat && TGStarGiftMessagePeerName(messagePeerId).length != 0)
                title = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatFrom"), TGStarGiftMessagePeerName(messagePeerId)];

            _subtitleText.font = TGStarGiftMessageSemiboldFont(13.0f);
            TGStarGiftMessageSetPlainText(_subtitleText, giftTitle);
            _hasMessage = messageString.length != 0;
            _hasAttributes = !_hasMessage;
            _messagePeerId = messagePeerId;

            if ([data[@"fromOffer"] boolValue])
            {
                _ribbonTitle = incoming ? nil : TGLocalized(@"OnegramGifts.ChatRibbonSold");
                _ribbonColors = @[UIColorRGB(0xd9433a), UIColorRGB(0xff645b)];
            }
            else
                _ribbonTitle = TGLocalized(@"OnegramGifts.ChatRibbonGift");
            if (gift.burned)
            {
                _ribbonTitle = TGLocalized(@"OnegramGifts.ChatRibbonBurned");
                _ribbonColors = @[UIColorRGB(0xd9433a), UIColorRGB(0xff645b)];
                _buttonTitle = nil;
            }

            NSArray *attributeTitles = @[TGLocalized(@"OnegramGifts.Model"), TGLocalized(@"OnegramGifts.Backdrop"), TGLocalized(@"OnegramGifts.Pattern")];
            NSArray *attributeValues = @[gift.modelName ?: @"", gift.backdropName ?: @"", gift.patternName ?: @""];
            for (NSUInteger index = 0; index < 3; index++)
            {
                bool visible = _hasAttributes && [attributeValues[index] length] != 0;
                TGStarGiftMessageSetPlainText(_attributeTitleTexts[index], visible ? attributeTitles[index] : @"");
                TGStarGiftMessageSetPlainText(_attributeValueTexts[index], visible ? attributeValues[index] : @"");
            }

            if (gift.hasBackdrop)
            {
                _cover = true;
                outerColor = TGStarGiftColor(gift.backdropEdgeColor);
                _primaryColor = white;
                _subtitleColor = TGStarGiftMixedColor(TGStarGiftMultipliedColor(TGStarGiftColor(gift.backdropCenterColor), 1.0f, 1.02f, 1.25f), white, 0.3f);
                if (_ribbonColors == nil)
                    _ribbonColors = @[TGStarGiftMultipliedColor(outerColor, 0.97f, 1.45f, 0.89f), TGStarGiftMultipliedColor(outerColor, 1.01f, 1.22f, 1.04f)];
            }

            NSString *peerName = TGStarGiftMessagePeerName(chatPeerId) ?: @"";
            NSArray *chatPeerIds = @[@(chatPeerId)];
            if (upgraded)
            {
                if (notificationsChat)
                    TGStarGiftMessageSetPlainText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelUpgradeChannel"));
                else if (selfChat)
                    TGStarGiftMessageSetPlainText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelUpgradeSelf"));
                else if (authorIsAccount)
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(prepaidUpgrade ? @"OnegramGifts.ChatLabelUpgradePrepaidYou" : @"OnegramGifts.ChatLabelUpgradeYou"), @[peerName], chatPeerIds, nil, labelBoldFont);
                else
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(prepaidUpgrade ? @"OnegramGifts.ChatLabelUpgradePrepaid" : @"OnegramGifts.ChatLabelUpgrade"), @[peerName], chatPeerIds, nil, labelBoldFont);
            }
            else if ([data[@"fromOffer"] boolValue] && resaleStars > 0)
            {
                if (authorIsAccount)
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelOfferAcceptedYou"), @[giftTitle, peerName, TGStarGiftMessageStars(resaleStars)], @[@0, @(chatPeerId)], [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 3)], labelBoldFont);
                else
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelOfferAccepted"), @[peerName, giftTitle, TGStarGiftMessageStars(resaleStars)], chatPeerIds, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)], labelBoldFont);
            }
            else if (selfChat && [data[@"assigned"] boolValue])
                TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelAssigned"), @[giftTitle], nil, [NSIndexSet indexSetWithIndex:0], labelBoldFont);
            else if (notificationsChat && fromPeerId == 0)
                TGStarGiftMessageSetPlainText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSentSomeone"));
            else if (authorIsAccount)
            {
                if (resaleStars > 0)
                {
                    if (selfChat)
                        TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelBoughtForYourself"), @[TGStarGiftMessageStars(resaleStars)], nil, [NSIndexSet indexSetWithIndex:0], labelBoldFont);
                    else
                        TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelBoughtYou"), @[giftTitle, TGStarGiftMessageStars(resaleStars)], nil, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)], labelBoldFont);
                }
                else
                    TGStarGiftMessageSetPlainText(_labelText, TGLocalized([data[@"craft"] boolValue] ? @"OnegramGifts.ChatLabelCrafted" : @"OnegramGifts.ChatLabelTransferYou"));
            }
            else if (fromPeerId != 0 && TGStarGiftMessagePeerName(fromPeerId) != nil)
            {
                if (ownerPeerId != 0 && TGStarGiftMessagePeerName(ownerPeerId) != nil)
                {
                    if (fromPeerId == accountPeerId)
                        TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelTransferToChannelYou"), @[TGStarGiftMessagePeerName(ownerPeerId)], @[@(ownerPeerId)], nil, labelBoldFont);
                    else
                        TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelTransferToChannel"), @[TGStarGiftMessagePeerName(fromPeerId), TGStarGiftMessagePeerName(ownerPeerId)], @[@(fromPeerId), @(ownerPeerId)], nil, labelBoldFont);
                }
                else
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelTransfer"), @[TGStarGiftMessagePeerName(fromPeerId)], @[@(fromPeerId)], nil, labelBoldFont);
            }
            else if (resaleStars > 0)
                TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelBought"), @[peerName, giftTitle, TGStarGiftMessageStars(resaleStars)], chatPeerIds, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)], labelBoldFont);
            else
                TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelTransfer"), @[peerName], chatPeerIds, nil, labelBoldFont);
            break;
        }
        case TGMessageActionStarGift:
        {
            bool selfGift = chatPeerId == accountPeerId;
            if (notificationsChat && toPeerId != 0)
            {
                if (toPeerId == accountPeerId)
                    selfGift = true;
                else
                    incoming = false;
            }
            bool channelGift = TGPeerIdIsChannel(chatPeerId) || ownerPeerId != 0;
            int64_t recipientPeerId = toPeerId != 0 ? toPeerId : chatPeerId;
            if (selfGift)
                title = TGLocalized(@"OnegramGifts.ChatPurchased");
            else if (prepaidUpgrade && fromPeerId == ownerPeerId)
                title = TGLocalized(@"OnegramGifts.Gift");
            else if (fromPeerId != 0 && TGStarGiftMessagePeerName(fromPeerId).length != 0)
                title = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatFrom"), TGStarGiftMessagePeerName(fromPeerId)];
            else if (!incoming && TGStarGiftMessagePeerName(recipientPeerId).length != 0)
                title = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatFor"), TGStarGiftMessagePeerName(recipientPeerId)];

            if (messageString.length != 0)
                TGStarGiftMessageSetPlainText(_subtitleText, messageString);
            else if ([data[@"refunded"] boolValue])
                TGStarGiftMessageSetPlainText(_subtitleText, TGLocalized(@"OnegramGifts.ChatSubtitleRefunded"));
            else if (upgraded)
                TGStarGiftMessageSetPlainText(_subtitleText, TGLocalized(@"OnegramGifts.ChatSubtitleUpgraded"));
            else if (incoming)
            {
                if ([data[@"converted"] boolValue])
                    TGStarGiftMessageSetPlainText(_subtitleText, [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatSubtitleConverted"), TGStarGiftMessageStars(convertStars)]);
                else if (upgradeStars > 0)
                    TGStarGiftMessageSetPlainText(_subtitleText, TGLocalized(@"OnegramGifts.ChatSubtitleUpgrade"));
                else if (selfGift && [data[@"canUpgrade"] boolValue])
                    TGStarGiftMessageSetPlainText(_subtitleText, TGLocalized(@"OnegramGifts.ChatSubtitleSelf"));
                else if ([data[@"saved"] boolValue])
                    TGStarGiftMessageSetPlainText(_subtitleText, convertStars > 0 ? [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatSubtitleDisplaying"), TGStarGiftMessageStars(convertStars)] : TGLocalized(@"OnegramGifts.ChatSubtitleBotDisplaying"));
                else if (convertStars > 0)
                    TGStarGiftMessageSetPlainText(_subtitleText, [[NSString alloc] initWithFormat:TGLocalized(channelGift ? @"OnegramGifts.ChatSubtitleChannel" : @"OnegramGifts.ChatSubtitle"), TGStarGiftMessageStars(convertStars)]);
                else
                    TGStarGiftMessageSetPlainText(_subtitleText, TGLocalized(@"OnegramGifts.ChatSubtitleBot"));
            }
            else
            {
                NSString *recipientName = TGStarGiftMessagePeerName(recipientPeerId);
                if (recipientName.length == 0)
                    TGStarGiftMessageSetPlainText(_subtitleText, convertStars > 0 ? [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatSubtitle"), TGStarGiftMessageStars(convertStars)] : TGLocalized(@"OnegramGifts.ChatSubtitleBot"));
                else if (prepaidUpgrade)
                    TGStarGiftMessageSetPlainText(_subtitleText, [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatSubtitleUpgradePrepaid"), recipientName]);
                else if (upgradeStars > 0)
                    TGStarGiftMessageSetPlainText(_subtitleText, [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.ChatSubtitleUpgradeOther"), recipientName]);
                else if (convertStars > 0)
                    TGStarGiftMessageSetFormattedText(_subtitleText, TGLocalized(@"OnegramGifts.ChatSubtitleOther"), @[recipientName, [TGStarGiftMessageStars(convertStars) stringByReplacingOccurrencesOfString:@" " withString:@" "]], nil, [NSIndexSet indexSetWithIndex:1], TGStarGiftMessageSemiboldFont(13.0f));
                else
                    TGStarGiftMessageSetPlainText(_subtitleText, TGLocalized(@"OnegramGifts.ChatSubtitleOtherNoConvert"));
            }

            if (gift.availabilityTotal > 0)
                _ribbonTitle = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.LimitedRibbon"), gift.availabilityTotal > 9999 ? TGStarGiftCompactCount(gift.availabilityTotal) : [[NSString alloc] initWithFormat:@"%d", (int)gift.availabilityTotal]];
            if (incoming && upgradeStars > 0 && !upgraded)
            {
                _buttonTitle = TGLocalized(@"OnegramGifts.ChatUnpack");
                _buttonOperation = @"upgrade";
            }
            else if (prepaidUpgrade && !incoming)
                _buttonTitle = nil;

            int64_t finalPrice = gift.stars + ([data[@"upgradeSeparate"] boolValue] ? 0 : upgradeStars);
            NSString *authorName = TGStarGiftMessagePeerName(authorPeerId) ?: @"";
            NSArray *authorPeerIds = @[@(authorPeerId)];
            if (chatPeerId == TGStarGiftMessageNotificationsPeerId)
            {
                authorName = TGLocalized(@"OnegramGifts.ChatUnknownUser");
                authorPeerIds = nil;
            }
            if ([data[@"auctionAcquired"] boolValue])
                TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelAuctionAcquired"), @[TGStarGiftMessageStars(finalPrice)], nil, [NSIndexSet indexSetWithIndex:0], labelBoldFont);
            else if (notificationsChat && fromPeerId == 0)
                TGStarGiftMessageSetPlainText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSentSomeone"));
            else if (chatPeerId == accountPeerId)
                TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSelfBought"), @[TGStarGiftMessageStars(finalPrice)], nil, [NSIndexSet indexSetWithIndex:0], labelBoldFont);
            else if (authorIsAccount)
            {
                if (prepaidUpgrade && ownerPeerId != 0)
                {
                    NSString *ownerName = TGStarGiftMessagePeerName(ownerPeerId) ?: @"";
                    NSString *upgradePrice = TGStarGiftMessageStars(upgradeStars);
                    if (fromPeerId != 0 && fromPeerId != accountPeerId)
                    {
                        if (fromPeerId == ownerPeerId)
                            TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSentUpgradeYouUnknown"), @[upgradePrice, ownerName], @[@0, @(ownerPeerId)], [NSIndexSet indexSetWithIndex:0], labelBoldFont);
                        else
                            TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSentUpgradeYouOther"), @[upgradePrice, ownerName, TGStarGiftMessagePeerName(fromPeerId) ?: @""], @[@0, @(ownerPeerId), @(fromPeerId)], [NSIndexSet indexSetWithIndex:0], labelBoldFont);
                    }
                    else
                        TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSentUpgradeYou"), @[upgradePrice, ownerName], @[@0, @(ownerPeerId)], [NSIndexSet indexSetWithIndex:0], labelBoldFont);
                }
                else
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSentYou"), @[TGStarGiftMessageStars(finalPrice)], nil, [NSIndexSet indexSetWithIndex:0], labelBoldFont);
            }
            else if (ownerPeerId != 0)
            {
                if (prepaidUpgrade)
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSentUpgrade"), @[authorName, TGStarGiftMessageStars(upgradeStars)], authorPeerIds, [NSIndexSet indexSetWithIndex:1], labelBoldFont);
                else
                {
                    int64_t senderPeerId = fromPeerId != 0 && TGStarGiftMessagePeerName(fromPeerId) != nil ? fromPeerId : authorPeerId;
                    NSString *senderName = senderPeerId == authorPeerId ? authorName : TGStarGiftMessagePeerName(senderPeerId);
                    TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelChannelSent"), @[senderName ?: @"", TGStarGiftMessagePeerName(ownerPeerId) ?: @"", TGStarGiftMessageStars(finalPrice)], @[@(senderPeerId), @(ownerPeerId)], [NSIndexSet indexSetWithIndex:2], labelBoldFont);
                }
            }
            else
                TGStarGiftMessageSetFormattedText(_labelText, TGLocalized(@"OnegramGifts.ChatLabelSent"), @[authorName, TGStarGiftMessageStars(finalPrice)], authorPeerIds, [NSIndexSet indexSetWithIndex:1], labelBoldFont);
            break;
        }
        default:
        {
            _hasLabel = false;
            TGStarGiftMessageSetPlainText(_labelText, @"");
            if (gift.title.length != 0)
                title = gift.title;
            NSString *offerText = nil;
            if (_giftAction.actionType == TGMessageActionStarGiftPurchaseOffer)
                offerText = [data[@"accepted"] boolValue] ? TGLocalized(@"OnegramGifts.ChatOfferAccepted") : ([data[@"declined"] boolValue] ? TGLocalized(@"OnegramGifts.ChatOfferDeclined") : TGLocalized(@"OnegramGifts.ChatOffer"));
            else
                offerText = [data[@"expired"] boolValue] ? TGLocalized(@"OnegramGifts.ChatOfferExpired") : TGLocalized(@"OnegramGifts.ChatOfferDeclined");
            int64_t priceStars = [data[@"priceStars"] longLongValue];
            if (priceStars > 0)
                offerText = [[NSString alloc] initWithFormat:@"%@ · %@", offerText, TGStarGiftMessageStars(priceStars)];
            TGStarGiftMessageSetPlainText(_subtitleText, offerText);
            if (gift.unique && gift.hasBackdrop)
            {
                _cover = true;
                outerColor = TGStarGiftColor(gift.backdropEdgeColor);
                _primaryColor = white;
                _subtitleColor = TGStarGiftMixedColor(TGStarGiftMultipliedColor(TGStarGiftColor(gift.backdropCenterColor), 1.0f, 1.02f, 1.25f), white, 0.3f);
            }
            break;
        }
    }

    if (!_cover)
        _subtitleColor = _primaryColor;
    if (!_hasMessage || _giftAction.actionType != TGMessageActionStarGiftUnique)
    {
        _hasMessage = false;
        _messagePeerId = 0;
    }
    if (_giftAction.actionType != TGMessageActionStarGiftUnique)
    {
        _hasAttributes = false;
        for (NSUInteger index = 0; index < 3; index++)
        {
            TGStarGiftMessageSetPlainText(_attributeTitleTexts[index], @"");
            TGStarGiftMessageSetPlainText(_attributeValueTexts[index], @"");
        }
    }
    _overlayColor = presentation.pallete.isDark && !_cover ? [UIColor colorWithWhite:1.0f alpha:0.12f] : [UIColor colorWithWhite:0.0f alpha:0.12f];
    _bubbleColor = _cover && outerColor != nil ? TGStarGiftMixedColor(_subtitleColor, outerColor, 0.55f) : [_subtitleColor colorWithAlphaComponent:0.3f];

    TGStarGiftMessageSetPlainText(_titleText, title);
    _titleText.textColor = _primaryColor;
    _subtitleText.textColor = _giftAction.actionType == TGMessageActionStarGift && messageString.length != 0 ? _primaryColor : _subtitleColor;
    _subtitleText.linkColor = _subtitleText.textColor;
    for (TGModernTextViewModel *text in _attributeTitleTexts)
        text.textColor = _subtitleColor;
    for (TGModernTextViewModel *text in _attributeValueTexts)
        text.textColor = _primaryColor;
    _messageText.textColor = _primaryColor;
    TGStarGiftMessageSetPlainText(_messageText, _hasMessage ? messageString : @"");
    _creatorText.textColor = _primaryColor;
    if (_creatorPeerId != 0)
        TGStarGiftMessageSetFormattedText(_creatorText, TGLocalized(@"OnegramGifts.ChatReleasedBy"), @[[@"@" stringByAppendingString:creatorUsername]], nil, [NSIndexSet indexSetWithIndex:0], TGStarGiftMessageSemiboldFont(12.0f));
    else
        TGStarGiftMessageSetPlainText(_creatorText, @"");
}

- (bool)giftTextExpanded
{
    return [[_context richMessageExpandedKeysForMessageId:_mid peerId:_giftMessage.cid] containsObject:TGStarGiftMessageExpandedKey];
}

- (void)updateGiftTextExpanded:(bool)expanded
{
    NSMutableSet *keys = [[NSMutableSet alloc] initWithSet:[_context richMessageExpandedKeysForMessageId:_mid peerId:_giftMessage.cid]];
    if (expanded)
        [keys addObject:TGStarGiftMessageExpandedKey];
    else
        [keys removeObject:TGStarGiftMessageExpandedKey];
    [_context setRichMessageExpandedKeys:keys forMessageId:_mid peerId:_giftMessage.cid];
    [_context.companionHandle requestAction:@"richMessageStateChanged" options:@{@"mid": @(_mid), @"peerId": @(_giftMessage.cid)}];
}

- (void)requestGiftOperation:(NSString *)operation
{
    if (_giftAction.actionData[@"gift"] == nil)
        return;
    [_context.companionHandle requestAction:@"openStarGiftRequested" options:@{@"data": _giftAction.actionData ?: @{}, @"mid": @(_mid), @"peerId": @(_giftMessage.cid), @"fromPeerId": @(_giftMessage.fromUid), @"date": @(_giftMessage.date), @"outgoing": @(_giftMessage.outgoing), @"operation": operation}];
}

- (void)cardPressedAtPoint:(CGPoint)point
{
    CGPoint contentPoint = CGPointMake(point.x - 2.0f, point.y - 2.0f);
    if (_canExpand && ![self giftTextExpanded] && CGRectContainsPoint(_subtitleText.frame, contentPoint))
    {
        [self updateGiftTextExpanded:true];
        return;
    }
    [self requestGiftOperation:@"view"];
}

- (void)buttonPressed
{
    [self requestGiftOperation:_buttonOperation ?: @"view"];
}

- (void)creatorPressed
{
    if (_creatorPeerId != 0)
        [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(_creatorPeerId)}];
}

- (void)requestSelection
{
    [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_giftMessage.cid)}];
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    _mid = message.mid;
    _giftMessage = message;
    for (TGMediaAttachment *attachment in message.mediaAttachments)
    {
        if (attachment.type == TGActionMediaAttachmentType)
        {
            _giftAction = (TGActionMediaAttachment *)attachment;
            break;
        }
    }
    [self updateGiftContent];
    if (sizeUpdated != NULL)
        *sizeUpdated = true;
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];
}

- (CGRect)effectiveContentFrame
{
    return _card.frame;
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    [_labelBackground bindViewToContainer:container viewStorage:viewStorage];
    [_labelBackground boundView].frame = CGRectOffset([_labelBackground boundView].frame, itemPosition.x, itemPosition.y);
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    UIView *labelView = [_labelBackground boundView];
    _labelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(labelTapped:)];
    [labelView addGestureRecognizer:_labelTap];
    _labelLongPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(labelLongPressed:)];
    _labelLongPress.minimumPressDuration = 0.5;
    [labelView addGestureRecognizer:_labelLongPress];

    if (![[_context richMessageExpandedKeysForMessageId:_mid peerId:_giftMessage.cid] containsObject:TGStarGiftMessagePlayedKey])
        [_card playStickerOnce];
}

- (void)stickerFinished
{
    NSMutableSet *keys = [[NSMutableSet alloc] initWithSet:[_context richMessageExpandedKeysForMessageId:_mid peerId:_giftMessage.cid]];
    [keys addObject:TGStarGiftMessagePlayedKey];
    [_context setRichMessageExpandedKeys:keys forMessageId:_mid peerId:_giftMessage.cid];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    UIView *labelView = [_labelBackground boundView];
    [labelView removeGestureRecognizer:_labelTap];
    [labelView removeGestureRecognizer:_labelLongPress];
    _labelTap = nil;
    _labelLongPress = nil;
    [super unbindView:viewStorage];
}

- (void)labelTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateRecognized)
        return;
    CGPoint point = [recognizer locationInView:[_labelContent boundView]];
    NSString *link = [_labelText linkAtPoint:CGPointMake(point.x - _labelText.frame.origin.x, point.y - _labelText.frame.origin.y) regionData:NULL];
    if ([link hasPrefix:@"tg-peer://"])
    {
        int64_t peerId = [[link substringFromIndex:@"tg-peer://".length] longLongValue];
        if (peerId != 0)
        {
            [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(peerId)}];
            return;
        }
    }
    [self requestGiftOperation:@"view"];
}

- (void)labelLongPressed:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan)
        [self requestSelection];
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    CGFloat width = containerSize.width;
    CGFloat textWidth = TGStarGiftMessageWidth - 32.0f;
    CGFloat labelHeight = 0.0f;

    _labelBackground.alpha = _hasLabel ? 1.0f : 0.0f;
    if (_hasLabel)
    {
        [_labelText layoutForContainerSize:CGSizeMake(width - 32.0f, CGFLOAT_MAX)];
        CGSize labelSize = _labelText.frame.size;
        labelHeight = labelSize.height;
        CGFloat plateWidth = MAX(60.0f, labelSize.width + 14.0f);
        CGRect plateFrame = CGRectMake(CGFloor((width - plateWidth) / 2.0f), 3.0f, plateWidth, MAX(21.0f, labelSize.height + 4.0f));
        _labelBackground.frame = plateFrame;
        _labelContent.frame = CGRectMake(plateFrame.origin.x + 5.0f, -1.0f, plateWidth - 2.0f, labelSize.height + 6.0f);
        _labelText.frame = CGRectMake(2.0f, 3.0f, labelSize.width, labelSize.height);
    }
    else
    {
        [_labelText layoutForContainerSize:CGSizeMake(width - 32.0f, CGFLOAT_MAX)];
        _labelBackground.frame = CGRectZero;
        _labelContent.frame = CGRectZero;
    }

    [_titleText layoutForContainerSize:CGSizeMake(textWidth, CGFLOAT_MAX)];
    CGSize titleSize = _titleText.frame.size;

    _subtitleText.maxNumberOfLines = 0;
    [_subtitleText layoutForContainerSize:CGSizeMake(textWidth, CGFLOAT_MAX)];
    _canExpand = [_subtitleText measuredNumberOfLines] > TGStarGiftMessageCollapsedLines;
    if (_canExpand && ![self giftTextExpanded])
    {
        _subtitleText.maxNumberOfLines = TGStarGiftMessageCollapsedLines;
        [_subtitleText layoutForContainerSize:CGSizeMake(textWidth, CGFLOAT_MAX)];
    }
    CGSize subtitleSize = TGStarGiftMessageTextIsEmpty(_subtitleText) ? CGSizeZero : _subtitleText.frame.size;

    bool hasCreator = !TGStarGiftMessageTextIsEmpty(_creatorText);
    [_creatorText layoutForContainerSize:CGSizeMake(textWidth, CGFLOAT_MAX)];
    CGSize creatorSize = hasCreator ? _creatorText.frame.size : CGSizeZero;

    [_messageText layoutForContainerSize:CGSizeMake(TGStarGiftMessageWidth - 88.0f, CGFLOAT_MAX)];
    CGSize messageSize = CGSizeZero;
    CGSize bubbleSize = CGSizeZero;
    if (_hasMessage)
    {
        messageSize = _messageText.frame.size;
        bubbleSize = CGSizeMake(messageSize.width + 34.0f, MAX(messageSize.height + 14.0f, 35.0f));
    }

    bool uniqueLayout = _giftAction.actionType == TGMessageActionStarGiftUnique;
    CGFloat textSpacing = !uniqueLayout && hasCreator ? creatorSize.height + 13.0f : 0.0f;
    CGFloat giftHeight = titleSize.height + textSpacing + subtitleSize.height + 164.0f;
    if (_hasMessage)
        giftHeight += bubbleSize.height + 26.0f + (hasCreator ? creatorSize.height + 13.0f : 0.0f);
    else if (uniqueLayout)
        giftHeight += 70.0f + (hasCreator ? creatorSize.height + 13.0f : 0.0f);
    if (_buttonTitle.length != 0)
        giftHeight += 48.0f;

    CGFloat imageY = _hasLabel ? labelHeight + 13.0f : 2.0f;
    CGRect cardFrame = CGRectMake(TGScreenPixelFloor((width - TGStarGiftMessageWidth) / 2.0f) - 2.0f, imageY - 2.0f, TGStarGiftMessageWidth + 4.0f, giftHeight + 4.0f);
    CGFloat cardWidth = cardFrame.size.width;

    CGRect titleFrame = CGRectMake(TGScreenPixelFloor((cardWidth - titleSize.width) / 2.0f), 151.0f, titleSize.width, titleSize.height);
    _titleText.frame = titleFrame;
    CGRect subtitleFrame = CGRectMake(TGScreenPixelFloor((cardWidth - subtitleSize.width) / 2.0f), CGRectGetMaxY(titleFrame) + textSpacing, subtitleSize.width, subtitleSize.height);
    _subtitleText.frame = subtitleFrame;

    CGFloat attributesOffsetY = 0.0f;
    CGRect creatorFrame = CGRectZero;
    if (hasCreator)
    {
        CGSize pillSize = CGSizeMake(creatorSize.width + 18.0f, creatorSize.height + 3.0f);
        CGFloat pillY = uniqueLayout ? CGRectGetMaxY(subtitleFrame) + 5.0f : CGRectGetMaxY(titleFrame) + 4.0f;
        creatorFrame = CGRectMake(TGScreenPixelFloor((cardWidth - pillSize.width) / 2.0f), pillY, pillSize.width, pillSize.height);
        _creatorText.frame = CGRectMake(creatorFrame.origin.x + 9.0f, creatorFrame.origin.y + 1.0f + TGScreenPixel, creatorSize.width, creatorSize.height);
        attributesOffsetY = pillSize.height + 10.0f;
    }

    CGFloat attributeWidth = textWidth * 0.7f;
    for (NSUInteger index = 0; index < 3; index++)
    {
        [(TGModernTextViewModel *)_attributeTitleTexts[index] layoutForContainerSize:CGSizeMake(attributeWidth, CGFLOAT_MAX)];
        [(TGModernTextViewModel *)_attributeValueTexts[index] layoutForContainerSize:CGSizeMake(attributeWidth, CGFLOAT_MAX)];
    }
    if (_hasAttributes)
    {
        CGFloat attributeSpacing = 6.0f;
        CGFloat midpointSum = 0.0f;
        NSUInteger midpointCount = 0;
        for (NSUInteger index = 0; index < 3; index++)
        {
            TGModernTextViewModel *titleText = _attributeTitleTexts[index];
            TGModernTextViewModel *valueText = _attributeValueTexts[index];
            if (TGStarGiftMessageTextIsEmpty(titleText))
                continue;
            CGFloat totalWidth = titleText.frame.size.width + attributeSpacing + valueText.frame.size.width;
            midpointSum += (cardWidth - totalWidth) / 2.0f + titleText.frame.size.width + attributeSpacing / 2.0f;
            midpointCount++;
        }
        CGFloat middleX = midpointCount == 0 ? cardWidth / 2.0f : midpointSum / (CGFloat)midpointCount;
        for (NSUInteger index = 0; index < 3; index++)
        {
            TGModernTextViewModel *titleText = _attributeTitleTexts[index];
            TGModernTextViewModel *valueText = _attributeValueTexts[index];
            if (TGStarGiftMessageTextIsEmpty(titleText))
                continue;
            CGFloat rowY = CGRectGetMaxY(subtitleFrame) + attributesOffsetY + 10.0f + 22.0f * (CGFloat)index;
            titleText.frame = CGRectMake(middleX - attributeSpacing / 2.0f - titleText.frame.size.width, rowY, titleText.frame.size.width, titleText.frame.size.height);
            valueText.frame = CGRectMake(middleX + attributeSpacing / 2.0f, rowY, valueText.frame.size.width, valueText.frame.size.height);
        }
    }

    CGRect bubbleFrame = CGRectZero;
    CGRect avatarFrame = CGRectZero;
    if (_hasMessage)
    {
        CGFloat avatarSide = 22.0f;
        CGFloat rowOriginX = TGScreenPixelFloor((cardWidth - (avatarSide + bubbleSize.width)) / 2.0f);
        CGRect messageBubbleFrame = CGRectMake(rowOriginX + avatarSide, CGRectGetMaxY(subtitleFrame) + attributesOffsetY + 15.0f, bubbleSize.width, bubbleSize.height);
        bubbleFrame = CGRectOffset(messageBubbleFrame, -3.0f, 0.0f);
        _messageText.frame = CGRectMake(messageBubbleFrame.origin.x + TGScreenPixelFloor((messageBubbleFrame.size.width - messageSize.width) / 2.0f), messageBubbleFrame.origin.y + TGScreenPixelFloor((messageBubbleFrame.size.height - messageSize.height) / 2.0f), messageSize.width, messageSize.height);
        avatarFrame = CGRectMake(rowOriginX + 1.0f, CGRectGetMaxY(messageBubbleFrame) - avatarSide - 2.0f, avatarSide, avatarSide);
    }

    CGFloat buttonY = CGRectGetMaxY(subtitleFrame) + 10.0f;
    if (_hasMessage)
        buttonY = CGRectGetMaxY(subtitleFrame) + attributesOffsetY + 15.0f + bubbleSize.height + 18.0f;
    else if (_hasAttributes)
        buttonY = CGRectGetMaxY(subtitleFrame) + attributesOffsetY + 80.0f;

    CGFloat inset = 2.0f;
    TGStarGiftMessageCardContent *content = [[TGStarGiftMessageCardContent alloc] init];
    content.gift = _giftAction.actionData[@"gift"];
    content.cover = _cover;
    content.plateColor = _plateColor;
    content.overlayColor = _overlayColor;
    content.textColor = _primaryColor;
    content.ribbonTitle = _ribbonTitle;
    content.ribbonColors = _ribbonColors;
    content.buttonTitle = _buttonTitle;
    content.buttonOriginY = buttonY + inset;
    content.creatorFrame = hasCreator ? CGRectOffset(creatorFrame, inset, inset) : CGRectZero;
    content.bubbleFrame = _hasMessage ? CGRectOffset(bubbleFrame, inset, inset) : CGRectZero;
    content.bubbleColor = _bubbleColor;
    content.avatarFrame = _hasMessage ? CGRectOffset(avatarFrame, inset, inset) : CGRectZero;
    content.avatarPeerId = _messagePeerId;
    _card.frame = CGRectInset(cardFrame, -inset, -inset);
    _card.content = content;

    _giftContent.frame = cardFrame;
    [_labelContent setNeedsSubmodelContentsUpdate];
    [_labelContent updateSubmodelContentsIfNeeded];
    [_giftContent setNeedsSubmodelContentsUpdate];
    [_giftContent updateSubmodelContentsIfNeeded];

    self.frame = CGRectMake(0.0f, 0.0f, width, CGRectGetMaxY(cardFrame) + (_hasLabel ? 5.0f : 2.0f));
    [super layoutForContainerSize:containerSize];
}

@end

@implementation TGNotificationMessageViewModel

static TGUser *findUserInArray(int64_t uid, NSArray *array)
{
    for (TGUser *user in array)
    {
        if (user.uid == uid)
            return user;
    }
    
    return nil;
}

- (bool)setupText {
    id authorPeer = _authorPeer;
    TGActionMediaAttachment *actionMedia = _actionMedia;
    TGMessage *message = _message;
    NSArray *additionalUsers = _additionalUsers;
    
    NSString *actionText = nil;
    
    NSArray *additionalAttributes = nil;
    NSArray *textCheckingResults = nil;
    
    NSString *authorTitle = @"";
    NSString *authorShortTitle = @"";
    int64_t authorUid = 0;
    if ([authorPeer isKindOfClass:[TGUser class]]) {
        authorTitle = ((TGUser *)authorPeer).displayName;
        authorShortTitle = ((TGUser *)authorPeer).displayFirstName;
        authorUid = ((TGUser *)authorPeer).uid;
    } else if ([authorPeer isKindOfClass:[TGConversation class]]) {
        authorTitle = ((TGConversation *)authorPeer).chatTitle;
        authorShortTitle = authorTitle;
    }
    
    bool underlineLinks = false;
    
    switch (actionMedia.actionType)
    {
        case TGMessageActionChatEditTitle:
        {
            NSString *authorName = authorTitle;
            NSString *formatString = nil;
            NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
            if (TGPeerIdIsChannel(message.cid) && !_context.conversation.isChannelGroup) {
                formatString = TGLocalized(@"Channel.MessageTitleUpdated");
                actionText = [[NSString alloc] initWithFormat:formatString, actionMedia.actionData[@"title"]];
            } else {
                formatString = TGLocalized(@"Notification.ChangedGroupName");
                actionText = [[NSString alloc] initWithFormat:formatString, authorName, actionMedia.actionData[@"title"]];
                formatNameRange = [formatString rangeOfString:@"%@"];
            }
            
            if (formatNameRange.location != NSNotFound && authorUid != 0)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
            }
            
            break;
        }
        case TGMessageActionChatAddMember:
        case TGMessageActionChatDeleteMember:
        {
            NSString *authorName = authorTitle;
            
            if (actionMedia.actionData[@"uids"] != nil) {
                NSArray *uids = actionMedia.actionData[@"uids"];
                
                if (uids.count == 1 && authorUid == [((NSNumber *)uids[0]) longLongValue]) {
                    NSString *formatBase = TGLocalized(@"Notification.JoinedChat");
                    if (_context.isAdminLog && !_context.adminLogIsGroup) {
                        formatBase = TGLocalized(@"Notification.JoinedChannel");
                    }
                    
                    actionText = [[NSString alloc] initWithFormat:formatBase, authorName];
                    
                    NSRange formatNameRange = [formatBase rangeOfString:@"%@"];
                    if (formatNameRange.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else {
                    NSMutableString *subjectNames = [[NSMutableString alloc] init];
                    
                    NSMutableArray *subjectRangesAndUids = [[NSMutableArray alloc] init];
                    
                    for (NSNumber *nUid in uids) {
                        TGUser *user = findUserInArray([nUid longLongValue], additionalUsers);
                        if (user != nil) {
                            if (subjectNames.length != 0) {
                                [subjectNames appendString:@", "];
                            }
                            
                            [subjectRangesAndUids addObject:@[[NSValue valueWithRange:NSMakeRange(subjectNames.length, user.displayName.length)], @(user.uid)]];
                            [subjectNames appendString:user.displayName];
                        }
                    }
                    
                    NSString *formatString = TGLocalized(@"Notification.Invited");
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName, subjectNames];
                    
                    NSRange formatNameRange = [formatString rangeOfString:@"%@"];
                    if (formatNameRange.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        
                        NSMutableArray *multipleTextCheckingResults = [[NSMutableArray alloc] init];
                        NSMutableArray *multipleAdditionalAttributes = [[NSMutableArray alloc] init];
                        
                        NSUInteger multipleRangesOffset = formatNameRange.location + formatNameRange.length;
                        
                        {
                            NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                            [multipleAdditionalAttributes addObject:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)]];
                            [multipleAdditionalAttributes addObject:fontAttributes];
                            
                            multipleRangesOffset = formatNameRange.location + authorName.length - formatNameRange.length;
                            
                            [multipleTextCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]]];
                        }
                        
                        NSRange nextFormatNameRange = [formatString rangeOfString:@"%@" options:0 range:NSMakeRange(formatNameRange.location + formatNameRange.length, formatString.length - formatNameRange.location - formatNameRange.length)];
                        
                        if (nextFormatNameRange.location != NSNotFound) {
                            multipleRangesOffset += nextFormatNameRange.location;
                            
                            for (NSArray *record in subjectRangesAndUids) {
                                NSRange range = [(NSValue *)record[0] rangeValue];
                                range.location += multipleRangesOffset;
                                NSNumber *nUid = record[1];
                                
                                [multipleAdditionalAttributes addObject:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)]];
                                [multipleAdditionalAttributes addObject:fontAttributes];
                                
                                [multipleTextCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", [nUid longLongValue]]]]];
                            }
                        }
                        
                        textCheckingResults = multipleTextCheckingResults;
                        additionalAttributes = multipleAdditionalAttributes;
                    }
                }
            } else {
                TGUser *user = findUserInArray([actionMedia.actionData[@"uid"] longLongValue], additionalUsers);
                
                if (user.uid == authorUid)
                {
                    NSString *formatBase = TGLocalized(@"Notification.JoinedChat");
                    
                    if (actionMedia.actionType == TGMessageActionChatAddMember) {
                        formatBase = TGLocalized(@"Notification.JoinedChat");
                        if (_context.isAdminLog && !_context.adminLogIsGroup) {
                            formatBase = TGLocalized(@"Notification.JoinedChannel");
                        }
                    } else {
                        formatBase = TGLocalized(@"Notification.LeftChat");
                        if (_context.isAdminLog && !_context.adminLogIsGroup) {
                            formatBase = TGLocalized(@"Notification.LeftChannel");
                        }
                    }
                    
                    NSString *formatString = formatBase;
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    NSRange formatNameRange = [formatString rangeOfString:@"%@"];
                    if (formatNameRange.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", user.uid]]], nil];
                    }
                }
                else
                {
                    NSString *userName = user.displayName;
                    NSString *formatString = actionMedia.actionType == TGMessageActionChatAddMember ? TGLocalized(@"Notification.Invited") : TGLocalized(@"Notification.Kicked");
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName, userName];
                    
                    NSRange formatNameRangeFirst = [formatString rangeOfString:@"%@"];
                    NSRange formatNameRangeSecond = formatNameRangeFirst.location != NSNotFound ? [formatString rangeOfString:@"%@" options:0 range:NSMakeRange(formatNameRangeFirst.location + formatNameRangeFirst.length, formatString.length - (formatNameRangeFirst.location + formatNameRangeFirst.length))] : NSMakeRange(NSNotFound, 0);
                    
                    if (formatNameRangeFirst.location != NSNotFound && formatNameRangeSecond.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange rangeFirst = NSMakeRange(formatNameRangeFirst.location, authorName.length);
                        NSRange rangeSecond = NSMakeRange(rangeFirst.length - formatNameRangeFirst.length + formatNameRangeSecond.location, userName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&rangeFirst objCType:@encode(NSRange)], fontAttributes, [[NSValue alloc] initWithBytes:&rangeSecond objCType:@encode(NSRange)], fontAttributes, nil];
                        
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:rangeFirst URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], [NSTextCheckingResult linkCheckingResultWithRange:rangeSecond URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", user.uid]]], nil];
                    }
                }
            }
            
            break;
        }
        case TGMessageActionJoinedByLink:
        {
            NSString *authorName = authorTitle;
            NSString *formatString = [actionMedia.actionData[@"joinedByRequest"] boolValue] ? TGLocalized(@"Notification.JoinedChat") : TGLocalized(@"Notification.JoinedGroupByLink");
            actionText = [[NSString alloc] initWithFormat:formatString, authorName];
            NSRange formatNameRange = [formatString rangeOfString:@"%@"];
            if (formatNameRange.location != NSNotFound && authorUid != 0)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                
                textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
            }
            break;
        }
        case TGMessageActionCreateChat:
        {
            NSString *authorName = authorTitle;
            NSString *formatString = TGLocalized(@"Notification.CreatedChatWithTitle");
            actionText = [[NSString alloc] initWithFormat:formatString, authorName, actionMedia.actionData[@"title"]];
            
            NSRange formatNameRange = [formatString rangeOfString:@"%@"];
            if (formatNameRange.location != NSNotFound && authorUid != 0)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                
                textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
            }
            
            break;
        }
        case TGMessageActionChannelCreated:
        {
            actionText = TGLocalized(@"Notification.CreatedChannel");
            
            break;
        }
        case TGMessageActionGroupMigratedTo:
        {
            actionText = TGLocalized(@"Notification.ChannelMigratedFrom");
            break;
        }
        case TGMessageActionGroupActivated:
        {
            actionText = TGLocalized(@"Notification.GroupDeactivated");
            break;
        }
        case TGMessageActionGroupDeactivated:
        {
            actionText = TGLocalized(@"Notification.GroupActivated");
            break;
        }
        case TGMessageActionChannelMigratedFrom:
        {
            actionText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChannelMigratedFrom"), actionMedia.actionData[@"title"]];
            break;
        }
        case TGMessageActionChannelCommentsStatusChanged:
        {
            actionText = [actionMedia.actionData[@"enabled"] boolValue] ? TGLocalized(@"Channel.NotificationCommentsEnabled") : TGLocalized(@"Channel.NotificationCommentsDisabled");
            break;
        }
        case TGMessageActionText:
        {
            actionText = actionMedia.actionData[@"text"];
            break;
        }
        case TGMessageActionCommunityChanged:
        {
            bool broadcast = TGPeerIdIsChannel(message.cid) && !_context.conversation.isChannelGroup;
            NSString *authorName = [authorPeer isKindOfClass:[TGUser class]] ? authorTitle : nil;
            actionText = [TGCommunitySignals serviceTextForCommunityAction:actionMedia isChannel:broadcast authorName:authorName];
            break;
        }
        case TGMessageActionChannelInviter:
        {
            NSString *formatString = nil;
            if (_context.conversation.isChannelGroup) {
                formatString = TGLocalized(@"Notification.GroupInviter");
            } else {
                formatString = TGLocalized(@"Notification.ChannelInviter");
            }
            if (authorUid == [actionMedia.actionData[@"uid"] longLongValue] || [actionMedia.actionData[@"uid"] longLongValue] == TGTelegraphInstance.clientUserId) {
                if (_context.conversation.isChannelGroup) {
                    actionText = TGLocalized(@"Notification.GroupInviterSelf");
                } else {
                    actionText = TGLocalized(@"Notification.ChannelInviterSelf");
                }
            } else {
                int64_t inviterUid = [actionMedia.actionData[@"uid"] longLongValue];
                NSString *inviterName = nil;
                for (TGUser *user in additionalUsers) {
                    if (user.uid == inviterUid) {
                        inviterName = user.displayName;
                        break;
                    }
                }
                actionText = [[NSString alloc] initWithFormat:formatString, inviterName];
                
                NSRange formatNameRange = [formatString rangeOfString:@"%@"];
                if (formatNameRange.location != NSNotFound && inviterUid != 0)
                {
                    NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                    NSRange range = NSMakeRange(formatNameRange.location, inviterName.length);
                    additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                    
                    textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", inviterUid]]], nil];
                }
            }
            
            break;
        }
        case TGMessageActionCreateBroadcastList:
        {
            NSString *formatString = TGLocalized(@"Notification.CreatedBroadcastList");
            actionText = formatString;
            
            break;
        }
        case TGMessageActionChatEditPhoto:
        {
            NSString *authorName = authorTitle;
            
            TGImageMediaAttachment *imageAttachment = actionMedia.actionData[@"photo"];
            CGSize avatarSize = CGSizeMake(70, 70);
            NSString *imageUrl = [imageAttachment.imageInfo closestImageUrlWithSize:avatarSize resultingSize:&avatarSize];
            
            NSString *formatString = nil;
            NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
            
            if (_context.isAdminLog) {
                if (_context.adminLogIsGroup) {
                    formatString = imageUrl != nil ? TGLocalized(@"Group.MessagePhotoUpdated") : TGLocalized(@"Group.MessagePhotoRemoved");
                } else {
                    formatString = imageUrl != nil ? TGLocalized(@"Channel.MessagePhotoUpdated") : TGLocalized(@"Channel.MessagePhotoRemoved");
                }
            } else if (TGPeerIdIsChannel(message.cid)) {
                if (_context.conversation.isChannelGroup) {
                    formatString = imageUrl != nil ? TGLocalized(@"Group.MessagePhotoUpdated") : TGLocalized(@"Group.MessagePhotoRemoved");
                } else {
                    formatString = imageUrl != nil ? TGLocalized(@"Channel.MessagePhotoUpdated") : TGLocalized(@"Channel.MessagePhotoRemoved");
                }
            } else {
                formatString = imageUrl != nil ? TGLocalized(@"Notification.ChangedGroupPhoto") : TGLocalized(@"Notification.RemovedGroupPhoto");
                formatNameRange = [formatString rangeOfString:@"%@"];
            }
            
            actionText = [[NSString alloc] initWithFormat:formatString, authorName, actionMedia.actionData[@"title"]];
            
            
            if (formatNameRange.location != NSNotFound && authorUid != 0)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                
                textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
            }
            
            if (imageUrl != nil)
            {
                NSMutableString *imageUri = [[NSMutableString alloc] initWithString:@"peer-avatar-thumbnail://?"];
                
                [imageUri appendFormat:@"legacy-thumbnail-cache-url=%@", imageUrl];
                [imageUri appendFormat:@"&width=%d&height=%d", 64, 64];
                
                _imageModel = [[TGModernDataImageViewModel alloc] initWithUri:imageUri options:nil];
                [self addSubmodel:_imageModel];
            }
            
            break;
        }
        case TGMessageActionContactRegistered:
        {
            NSString *authorName = authorTitle;
            NSString *formatString = TGLocalized(@"Notification.Joined");
            actionText = [[NSString alloc] initWithFormat:formatString, authorName, actionMedia.actionData[@"title"]];
            
            NSRange formatNameRange = [formatString rangeOfString:@"%@"];
            if (formatNameRange.location != NSNotFound)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
            }
            
            break;
        }
        case TGMessageActionUserChangedPhoto:
        {
            NSString *authorName = authorTitle;
            
            NSString *formatString = TGLocalized(@"Notification.ChangedUserPhoto");
            
            actionText = [[NSString alloc] initWithFormat:formatString, authorName, actionMedia.actionData[@"title"]];
            
            NSRange formatNameRange = [formatString rangeOfString:@"%@"];
            if (formatNameRange.location != NSNotFound)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
            }
            
            break;
        }
        case TGMessageActionEncryptedChatMessageLifetime:
        {
            int messageLifetime = [actionMedia.actionData[@"messageLifetime"] intValue];
            
            if (messageLifetime == 0)
            {
                if (message.outgoing)
                    actionText = TGLocalized(@"Notification.MessageLifetimeRemovedOutgoing");
                else
                {
                    NSString *authorName = authorTitle;
                    NSString *formatString = TGLocalized(@"Notification.MessageLifetimeRemoved");
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    NSRange formatNameRange = [formatString rangeOfString:@"%1$@"];
                    if (formatNameRange.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                    }
                }
            }
            else
            {
                NSString *lifetimeString = [TGStringUtils stringForMessageTimerSeconds:messageLifetime];
                
                if (message.outgoing)
                    actionText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.MessageLifetimeChangedOutgoing"), lifetimeString];
                else
                {
                    NSString *authorName = authorTitle;
                    NSString *formatString = TGLocalized(@"Notification.MessageLifetimeChanged");
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName, lifetimeString];
                    
                    NSRange formatNameRange = [formatString rangeOfString:@"%1$@"];
                    if (formatNameRange.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                    }
                }
            }
            
            break;
        }
        case TGMessageActionEncryptedChatScreenshot:
        case TGMessageActionEncryptedChatMessageScreenshot:
        {
            if (message.outgoing) {
                actionText = TGLocalized(@"Notification.SecretChatMessageScreenshotSelf");
            }
            else
            {
                NSString *authorName = authorShortTitle;
                
                NSString *formatString = TGLocalized(@"Notification.SecretChatMessageScreenshot");
                actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                
                NSRange formatNameRange = [formatString rangeOfString:@"%1$@"];
                if (formatNameRange.location != NSNotFound)
                {
                    NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                    NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                    additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                }
            }
            
            break;
        }
        case TGMessageActionPinnedMessage:
        {
            TGMessage *replyMessage = nil;
            for (id attachment in message.mediaAttachments) {
                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                    break;
                }
            }
            
            _navigateToMessageId = replyMessage.mid;
            
            NSString *formatString = replyMessage != nil ? TGLocalized(@"Notification.PinnedTextMessage") : TGLocalized(@"Notification.PinnedDeletedMessage");
            for (id attachment in replyMessage.mediaAttachments) {
                if ([attachment isKindOfClass:[TGImageMediaAttachment class]]) {
                    formatString = TGLocalized(@"Notification.PinnedPhotoMessage");
                } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]]) {
                    if (((TGVideoMediaAttachment *)attachment).roundMessage)
                        formatString = TGLocalized(@"Notification.PinnedRoundMessage");
                    else
                        formatString = TGLocalized(@"Notification.PinnedVideoMessage");
                } else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
                    TGDocumentMediaAttachment *document = attachment;
                    if ([document isAnimated]) {
                        formatString = TGLocalized(@"Notification.PinnedAnimationMessage");
                    } else {
                        bool isSticker = false;
                        bool isAudio = false;
                        bool isVoice = false;
                        
                        for (id attribute in document.attributes) {
                            if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                                isAudio = true;
                                isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                            } else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]]) {
                                isSticker = true;
                            }
                        }
                        
                        if (isSticker) {
                            formatString = TGLocalized(@"Notification.PinnedStickerMessage");
                        } else if (isVoice) {
                            formatString = TGLocalized(@"Notification.PinnedAudioMessage");
                        } else {
                            formatString = TGLocalized(@"Notification.PinnedDocumentMessage");
                        }
                    }
                } else if ([attachment isKindOfClass:[TGLocationMediaAttachment class]]) {
                    TGLocationMediaAttachment *location = (TGLocationMediaAttachment *)attachment;
                    if (location.period > 0)
                        formatString = TGLocalized(@"Notification.PinnedLiveLocationMessage");
                    else
                        formatString = TGLocalized(@"Notification.PinnedLocationMessage");
                } else if ([attachment isKindOfClass:[TGContactMediaAttachment class]]) {
                    formatString = TGLocalized(@"Notification.PinnedContactMessage");
                } else if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
                    formatString = TGLocalized(@"PINNED_GAME");
                } else if ([attachment isKindOfClass:[TGInvoiceMediaAttachment class]]) {
                    formatString = TGLocalized(@"PINNED_INVOICE");
                }
            }
            
            NSString *authorName = authorTitle;
            NSString *text = replyMessage.text;
            if (text.length > 14) {
                text = [[text substringToIndex:14] stringByAppendingString:@"..."];
            }
            actionText = [[NSString alloc] initWithFormat:formatString, authorName, text];
            
            break;
        }
        case TGMessageActionGameScore:
        {
            TGMessage *replyMessage = nil;
            for (id attachment in message.mediaAttachments) {
                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                    _navigateToMessageId = ((TGReplyMessageMediaAttachment *)attachment).replyMessageId;
                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                    break;
                }
            }
            
            NSString *gameTitle = nil;
            for (id attachment in replyMessage.mediaAttachments) {
                if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
                    gameTitle = ((TGGameMediaAttachment *)attachment).title;
                    break;
                }
            }
            
            int scoreCount = (int)[actionMedia.actionData[@"score"] intValue];
            
            NSString *formatStringBase = @"";
            if (gameTitle != nil) {
                if (authorUid == TGTelegraphInstance.clientUserId) {
                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreSelfExtended_" value:scoreCount];
                } else {
                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreExtended_" value:scoreCount];
                }
            } else {
                if (authorUid == TGTelegraphInstance.clientUserId) {
                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreSelfSimple_" value:scoreCount];
                } else {
                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreSimple_" value:scoreCount];
                }
            }
            
            NSString *baseString = TGLocalized(formatStringBase);
            baseString = [baseString stringByReplacingOccurrencesOfString:@"%@" withString:@"{score}"];
            
            NSMutableString *formatString = [[NSMutableString alloc] initWithString:baseString];
            
            NSString *authorName = authorTitle;
            
            NSMutableArray *addAttributes = [[NSMutableArray alloc] init];
            NSMutableArray *addTextCheckingResults = [[NSMutableArray alloc] init];
            
            for (int i = 0; i < 3; i++) {
                NSRange nameRange = [formatString rangeOfString:@"{name}"];
                NSRange scoreRange = [formatString rangeOfString:@"{score}"];
                NSRange gameTitleRange = [formatString rangeOfString:@"{game}"];
                
                if (nameRange.location != NSNotFound) {
                    if (scoreRange.location == NSNotFound || scoreRange.location > nameRange.location) {
                        scoreRange.location = NSNotFound;
                    }
                    if (gameTitleRange.location == NSNotFound || gameTitleRange.location > nameRange.location) {
                        gameTitleRange.location = NSNotFound;
                    }
                }
                
                if (scoreRange.location != NSNotFound) {
                    if (nameRange.location == NSNotFound || nameRange.location > scoreRange.location) {
                        nameRange.location = NSNotFound;
                    }
                    if (gameTitleRange.location == NSNotFound || gameTitleRange.location > scoreRange.location) {
                        gameTitleRange.location = NSNotFound;
                    }
                }
                
                if (gameTitleRange.location != NSNotFound) {
                    if (scoreRange.location == NSNotFound || scoreRange.location > gameTitleRange.location) {
                        scoreRange.location = NSNotFound;
                    }
                    if (nameRange.location == NSNotFound || nameRange.location > gameTitleRange.location) {
                        nameRange.location = NSNotFound;
                    }
                }
                
                if (nameRange.location != NSNotFound) {
                    [formatString replaceCharactersInRange:nameRange withString:authorName];
                    
                    NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                    NSRange fixedRange = NSMakeRange(nameRange.location, authorName.length);
                    [addAttributes addObject:[[NSValue alloc] initWithBytes:&fixedRange objCType:@encode(NSRange)]];
                    [addAttributes addObject:fontAttributes];
                    
                    [addTextCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:fixedRange URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]]];
                }
                
                if (scoreRange.location != NSNotFound) {
                    [formatString replaceCharactersInRange:scoreRange withString:[NSString stringWithFormat:@"%d", scoreCount]];
                }
                
                if (gameTitleRange.location != NSNotFound) {
                    [formatString replaceCharactersInRange:gameTitleRange withString:gameTitle ?: @""];
                    
                    NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                    NSRange fixedRange = NSMakeRange(gameTitleRange.location, gameTitle.length);
                    [addAttributes addObject:[[NSValue alloc] initWithBytes:&fixedRange objCType:@encode(NSRange)]];
                    [addAttributes addObject:fontAttributes];
                    
                }
            }
            
            additionalAttributes = addAttributes;
            textCheckingResults = addTextCheckingResults;
            actionText = formatString;
            
            break;
        }
        case TGMessageActionPhoneCall:
        {
            _callForMessageId = message.mid;
            
            bool outgoing = authorUid == TGTelegraphInstance.clientUserId;
            int reason = [actionMedia.actionData[@"reason"] intValue];
            bool missed = reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
            
            NSString *type = TGLocalized(missed ? (outgoing ? @"Notification.CallCanceled" : @"Notification.CallMissed") : (outgoing ? @"Notification.CallOutgoing" : @"Notification.CallIncoming"));
            
            int callDuration = [message.actionInfo.actionData[@"duration"] intValue];
            NSString *duration = missed || callDuration < 1 ? nil : [TGStringUtils stringForCallDurationSeconds:callDuration];
            NSString *title = duration != nil ? [NSString stringWithFormat:TGLocalized(@"Notification.CallTimeFormat"), type, duration] : type;
            NSString *time = [TGDateUtils stringForShortTime:(int)message.date daytimeVariant:NULL];
            
            NSString *formatString = TGLocalized(@"Notification.CallFormat");
            actionText = [[NSString alloc] initWithFormat:formatString, title, time];
            
            NSRange typeRange = [actionText rangeOfString:type];
            if (typeRange.location != NSNotFound)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&typeRange objCType:@encode(NSRange)], fontAttributes, nil];
            }
            break;
        }
        case TGMessageActionBotAllowed:
        {
            NSString *formatString = TGLocalized(@"AuthSessions.Message");
            NSString *domainName = actionMedia.actionData[@"domain"];
            
            actionText = [[NSString alloc] initWithFormat:formatString, domainName];
            
            NSRange formatDomainRange = [formatString rangeOfString:@"%@"];
            if (formatDomainRange.location != NSNotFound && domainName.length > 0)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatDomainRange.location, domainName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                
                textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"http://%@", domainName]]], nil];
                
                underlineLinks = true;
            }
        }
            break;
        case TGMessageActionSecureValuesSent:
        {
            NSString *formatString = TGLocalized(@"Notification.PassportValuesSentMessage");
            NSString *authorName = [additionalUsers.firstObject displayName];
            
            NSArray *components = [actionMedia.actionData[@"values"] componentsSeparatedByString:@","];
            NSString *values = @"";
            bool hasIdentity = false;
            bool hasAddress = false;
            for (NSString *component in components)
            {
                NSString *value = nil;
                if ([component isEqualToString:@"personal_details"])
                {
                    value = TGLocalized(@"Notification.PassportValuePersonalDetails");
                }
                else if ([component isEqualToString:@"passport"] || [component isEqualToString:@"identity_card"] || [component isEqualToString:@"driver_license"] || [component isEqualToString:@"internal_passport"])
                {
                    if (!hasIdentity)
                    {
                        value = TGLocalized(@"Notification.PassportValueProofOfIdentity");
                        hasIdentity = true;
                    }
                    else
                    {
                        continue;
                    }
                        
                }
                else if ([component isEqualToString:@"address"])
                {
                    value = TGLocalized(@"Notification.PassportValueAddress");
                }
                else if ([component isEqualToString:@"utility_bill"] || [component isEqualToString:@"bank_statement"] || [component isEqualToString:@"rental_agreement"] || [component isEqualToString:@"passport_registration"] || [component isEqualToString:@"temporary_registration"])
                {
                    if (!hasAddress)
                    {
                        value = TGLocalized(@"Notification.PassportValueProofOfAddress");
                        hasAddress = true;
                    }
                    else
                    {
                        continue;
                    }
                }
                else if ([component isEqualToString:@"phone"])
                {
                    value = TGLocalized(@"Notification.PassportValuePhone");
                }
                else if ([component isEqualToString:@"email"])
                {
                    value = TGLocalized(@"Notification.PassportValueEmail");
                }
                
                if (values.length == 0)
                    values = value ?: @"";
                else
                    values = [values stringByAppendingString:[NSString stringWithFormat:@", %@", value]];
            }
            
            actionText = [[NSString alloc] initWithFormat:formatString, authorName, values];
            
            
            NSRange formatNameRange = [formatString rangeOfString:@"%1$@"];
            if (formatNameRange.location != NSNotFound)
            {
                NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
            }
            
        }
            break;
        case TGMessageActionPaymentSent: {
            TGMessage *replyMessage = nil;
            for (id attachment in message.mediaAttachments) {
                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                    _navigateToMessageId = ((TGReplyMessageMediaAttachment *)attachment).replyMessageId;
                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                    break;
                }
            }
            
            NSString *stringAmount = [[TGCurrencyFormatter shared] formatAmount:[_actionMedia.actionData[@"totalAmount"] longLongValue] currency:_actionMedia.actionData[@"currency"]];
            
            if (replyMessage != nil) {
                NSString *invoiceTitle = nil;
                for (id attachment in replyMessage.mediaAttachments) {
                    if ([attachment isKindOfClass:[TGInvoiceMediaAttachment class]]) {
                        invoiceTitle = ((TGInvoiceMediaAttachment *)attachment).title;
                        break;
                    }
                }
                
                NSString *formatStringBase = @"Notification.PaymentSent";
                
                NSMutableString *formatString = [[NSMutableString alloc] initWithString:TGLocalized(formatStringBase)];
                
                NSString *authorName = findUserInArray(replyMessage.fromUid, additionalUsers).displayName;
                if (authorName == nil) {
                    authorName = @"";
                }
                
                NSMutableArray *addAttributes = [[NSMutableArray alloc] init];
                NSMutableArray *addTextCheckingResults = [[NSMutableArray alloc] init];
                
                for (int i = 0; i < 3; i++) {
                    NSRange nameRange = [formatString rangeOfString:@"{name}"];
                    NSRange amountRange = [formatString rangeOfString:@"{amount}"];
                    NSRange titleRange = [formatString rangeOfString:@"{title}"];
                    
                    if (nameRange.location != NSNotFound) {
                        if (amountRange.location == NSNotFound || amountRange.location > nameRange.location) {
                            amountRange.location = NSNotFound;
                        }
                        if (titleRange.location == NSNotFound || titleRange.location > nameRange.location) {
                            titleRange.location = NSNotFound;
                        }
                    }
                    
                    if (amountRange.location != NSNotFound) {
                        if (nameRange.location == NSNotFound || nameRange.location > amountRange.location) {
                            nameRange.location = NSNotFound;
                        }
                        if (titleRange.location == NSNotFound || titleRange.location > amountRange.location) {
                            titleRange.location = NSNotFound;
                        }
                    }
                    
                    if (titleRange.location != NSNotFound) {
                        if (amountRange.location == NSNotFound || amountRange.location > titleRange.location) {
                            amountRange.location = NSNotFound;
                        }
                        if (nameRange.location == NSNotFound || nameRange.location > titleRange.location) {
                            nameRange.location = NSNotFound;
                        }
                    }
                    
                    if (nameRange.location != NSNotFound) {
                        [formatString replaceCharactersInRange:nameRange withString:authorName];
                        
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange fixedRange = NSMakeRange(nameRange.location, authorName.length);
                        [addAttributes addObject:[[NSValue alloc] initWithBytes:&fixedRange objCType:@encode(NSRange)]];
                        [addAttributes addObject:fontAttributes];
                        
                        [addTextCheckingResults addObject:[NSTextCheckingResult linkCheckingResultWithRange:fixedRange URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]]];
                    }
                    
                    if (amountRange.location != NSNotFound) {
                        [formatString replaceCharactersInRange:amountRange withString:stringAmount];
                        
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange fixedRange = NSMakeRange(amountRange.location, stringAmount.length);
                        [addAttributes addObject:[[NSValue alloc] initWithBytes:&fixedRange objCType:@encode(NSRange)]];
                        [addAttributes addObject:fontAttributes];
                    }
                    
                    if (titleRange.location != NSNotFound) {
                        [formatString replaceCharactersInRange:titleRange withString:invoiceTitle];
                        
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange fixedRange = NSMakeRange(titleRange.location, invoiceTitle.length);
                        [addAttributes addObject:[[NSValue alloc] initWithBytes:&fixedRange objCType:@encode(NSRange)]];
                        [addAttributes addObject:fontAttributes];
                    }
                }
                
                additionalAttributes = addAttributes;
                textCheckingResults = addTextCheckingResults;
                actionText = formatString;
            } else {
                actionText = [[NSString alloc] initWithFormat:TGLocalized(@"Message.PaymentSent"), stringAmount];
            }
            
            break;
        }
        case TGMessageActionCustom: {
            TGMediaAttachment *expiredMedia = actionMedia.actionData[@"expiredMedia"];
            id<TGChannelAdminLogEntryContent> content = actionMedia.actionData[@"adminLogEntryContent"];
            
            if (expiredMedia != nil) {
                if ([expiredMedia isKindOfClass:[TGImageMediaAttachment class]]) {
                    actionText = TGLocalized(@"Message.ImageExpired");
                } else if ([expiredMedia isKindOfClass:[TGDocumentMediaAttachment class]]) {
                    actionText = TGLocalized(@"Message.VideoExpired");
                } else if ([expiredMedia isKindOfClass:[TGVideoMediaAttachment class]]) {
                    actionText = TGLocalized(@"Message.VideoExpired");
                }
            } else if (content != nil) {
                if ([content isKindOfClass:[TGChannelAdminLogEntryToggleBan class]]) {
                    TGChannelAdminLogEntryToggleBan *value = (TGChannelAdminLogEntryToggleBan *)content;
                    
                    TGUser *user = findUserInArray([actionMedia.actionData[@"uid"] longLongValue], additionalUsers);
                    
                    NSMutableString *updates = [[NSMutableString alloc] init];
                    if (value.previousRights.banReadMessages != value.rights.banReadMessages) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.banReadMessages) {
                            [updates appendString:@"+"];
                        } else {
                            [updates appendString:@"-"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.BanReadMessages")];
                    }
                    if (value.previousRights.banSendMessages != value.rights.banSendMessages) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.banSendMessages) {
                            [updates appendString:@"+"];
                        } else {
                            [updates appendString:@"-"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.BanSendMessages")];
                    }
                    if (value.previousRights.banSendMedia != value.rights.banSendMedia) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.banSendMedia) {
                            [updates appendString:@"+"];
                        } else {
                            [updates appendString:@"-"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.BanSendMedia")];
                    }
                    if (value.previousRights.banSendStickers != value.rights.banSendStickers) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.banSendStickers) {
                            [updates appendString:@"+"];
                        } else {
                            [updates appendString:@"-"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.BanSendStickers")];
                    }
                    if (value.previousRights.banEmbedLinks != value.rights.banEmbedLinks) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.banEmbedLinks) {
                            [updates appendString:@"+"];
                        } else {
                            [updates appendString:@"-"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.BanEmbedLinks")];
                    }
                    
                    NSString *userName = user.displayName;
                    NSString *formatString = TGLocalized(@"Channel.AdminLog.MessageRestricted");
                    actionText = [[NSString alloc] initWithFormat:formatString, authorTitle, userName, updates];
                    
                    NSRange formatNameRangeFirst = [formatString rangeOfString:@"%@"];
                    NSRange formatNameRangeSecond = formatNameRangeFirst.location != NSNotFound ? [formatString rangeOfString:@"%@" options:0 range:NSMakeRange(formatNameRangeFirst.location + formatNameRangeFirst.length, formatString.length - (formatNameRangeFirst.location + formatNameRangeFirst.length))] : NSMakeRange(NSNotFound, 0);
                    
                    if (formatNameRangeFirst.location != NSNotFound && formatNameRangeSecond.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange rangeFirst = NSMakeRange(formatNameRangeFirst.location, authorTitle.length);
                        NSRange rangeSecond = NSMakeRange(rangeFirst.length - formatNameRangeFirst.length + formatNameRangeSecond.location, userName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&rangeFirst objCType:@encode(NSRange)], fontAttributes, [[NSValue alloc] initWithBytes:&rangeSecond objCType:@encode(NSRange)], fontAttributes, nil];
                        
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:rangeFirst URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], [NSTextCheckingResult linkCheckingResultWithRange:rangeSecond URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", user.uid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryToggleAdmin class]]) {
                    TGChannelAdminLogEntryToggleAdmin *value = (TGChannelAdminLogEntryToggleAdmin *)content;
                    
                    TGUser *user = findUserInArray([actionMedia.actionData[@"uid"] longLongValue], additionalUsers);
                    
                    NSMutableString *updates = [[NSMutableString alloc] init];
                    if (value.previousRights.canChangeInfo != value.rights.canChangeInfo) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canChangeInfo) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanChangeInfo")];
                    }
                    if (value.previousRights.canPostMessages != value.rights.canPostMessages) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canPostMessages) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanSendMessages")];
                    }
                    if (value.previousRights.canDeleteMessages != value.rights.canDeleteMessages) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canDeleteMessages) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanDeleteMessages")];
                    }
                    if (value.previousRights.canBanUsers != value.rights.canBanUsers) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canBanUsers) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanBanUsers")];
                    }
                    if (value.previousRights.canInviteUsers != value.rights.canInviteUsers) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canInviteUsers) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanInviteUsers")];
                    }
                    if (value.previousRights.canChangeInviteLink != value.rights.canChangeInviteLink) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canChangeInviteLink) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanChangeInviteLink")];
                    }
                    if (value.previousRights.canPinMessages != value.rights.canPinMessages) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canPinMessages) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanPinMessages")];
                    }
                    if (value.previousRights.canAddAdmins != value.rights.canAddAdmins) {
                        if (updates.length != 0) {
                            [updates appendString:@", "];
                        }
                        if (value.previousRights.canAddAdmins) {
                            [updates appendString:@"-"];
                        } else {
                            [updates appendString:@"+"];
                        }
                        [updates appendString:TGLocalized(@"Channel.AdminLog.CanAddAdmins")];
                    }
                    
                    NSString *userName = user.displayName;
                    NSString *formatString = TGLocalized(@"Channel.AdminLog.MessageAdmin");
                    actionText = [[NSString alloc] initWithFormat:formatString, authorTitle, userName, updates];
                    
                    NSRange formatNameRangeFirst = [formatString rangeOfString:@"%@"];
                    NSRange formatNameRangeSecond = formatNameRangeFirst.location != NSNotFound ? [formatString rangeOfString:@"%@" options:0 range:NSMakeRange(formatNameRangeFirst.location + formatNameRangeFirst.length, formatString.length - (formatNameRangeFirst.location + formatNameRangeFirst.length))] : NSMakeRange(NSNotFound, 0);
                    
                    if (formatNameRangeFirst.location != NSNotFound && formatNameRangeSecond.location != NSNotFound)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange rangeFirst = NSMakeRange(formatNameRangeFirst.location, authorTitle.length);
                        NSRange rangeSecond = NSMakeRange(rangeFirst.length - formatNameRangeFirst.length + formatNameRangeSecond.location, userName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&rangeFirst objCType:@encode(NSRange)], fontAttributes, [[NSValue alloc] initWithBytes:&rangeSecond objCType:@encode(NSRange)], fontAttributes, nil];
                        
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:rangeFirst URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], [NSTextCheckingResult linkCheckingResultWithRange:rangeSecond URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", user.uid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryChangeInvites class]]) {
                    TGChannelAdminLogEntryChangeInvites *value = (TGChannelAdminLogEntryChangeInvites *)content;
                    
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    if (value.value) {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageToggleInvitesOn");
                        formatNameRange = [formatString rangeOfString:@"%@"];
                    } else {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageToggleInvitesOff");
                        formatNameRange = [formatString rangeOfString:@"%@"];
                    }
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryChangeSignatures class]]) {
                    TGChannelAdminLogEntryChangeSignatures *value = (TGChannelAdminLogEntryChangeSignatures *)content;
                    
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    if (value.value) {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageToggleSignaturesOn");
                        formatNameRange = [formatString rangeOfString:@"%@"];
                    } else {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageToggleSignaturesOff");
                        formatNameRange = [formatString rangeOfString:@"%@"];
                    }
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryChangeUsername class]]) {
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    if (((TGChannelAdminLogEntryChangeUsername *)content).username.length != 0) {
                        if (_context.conversation.isChannelGroup) {
                            formatString = TGLocalized(@"Channel.AdminLog.MessageChangedGroupUsername");
                            formatNameRange = [formatString rangeOfString:@"%@"];
                        } else {
                            formatString = TGLocalized(@"Channel.AdminLog.MessageChangedChannelUsername");
                            formatNameRange = [formatString rangeOfString:@"%@"];
                        }
                    } else {
                        if (_context.conversation.isChannelGroup) {
                            formatString = TGLocalized(@"Channel.AdminLog.MessageRemovedGroupUsername");
                            formatNameRange = [formatString rangeOfString:@"%@"];
                        } else {
                            formatString = TGLocalized(@"Channel.AdminLog.MessageRemovedChannelUsername");
                            formatNameRange = [formatString rangeOfString:@"%@"];
                        }
                    }
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryChangeAbout class]]) {
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    if (_context.conversation.isChannelGroup) {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageChangedGroupAbout");
                        formatNameRange = [formatString rangeOfString:@"%@"];
                    } else {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageChangedChannelAbout");
                        formatNameRange = [formatString rangeOfString:@"%@"];
                    }
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryEditMessage class]]) {
                    TGChannelAdminLogEntryEditMessage *value = (TGChannelAdminLogEntryEditMessage *)content;
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    formatString = TGLocalized(@"Channel.AdminLog.MessageEdited");
                    bool isMedia = false;
                    int64_t previousId = 0;
                    int64_t currentId = 0;
                    for (id media in value.previousMessage.mediaAttachments) {
                        if ([media isKindOfClass:[TGImageMediaAttachment class]]) {
                            previousId = ((TGImageMediaAttachment *)media).imageId;
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGVideoMediaAttachment class]]) {
                            previousId = ((TGVideoMediaAttachment *)media).videoId;
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGDocumentMediaAttachment class]]) {
                            previousId = ((TGDocumentMediaAttachment *)media).documentId;
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGAudioMediaAttachment class]]) {
                            previousId = ((TGAudioMediaAttachment *)media).audioId;
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGLocationMediaAttachment class]]) {
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGContactMediaAttachment class]]) {
                            isMedia = true;
                        }
                    }
                    for (id media in value.message.mediaAttachments) {
                        if ([media isKindOfClass:[TGImageMediaAttachment class]]) {
                            currentId = ((TGImageMediaAttachment *)media).imageId;
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGVideoMediaAttachment class]]) {
                            currentId = ((TGVideoMediaAttachment *)media).videoId;
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGDocumentMediaAttachment class]]) {
                            currentId = ((TGDocumentMediaAttachment *)media).documentId;
                            isMedia = true;
                        } else if ([media isKindOfClass:[TGAudioMediaAttachment class]]) {
                            currentId = ((TGAudioMediaAttachment *)media).audioId;
                            isMedia = true;
                        }
                    }
                    if (isMedia && previousId == currentId) {
                        formatString = TGLocalized(@"Channel.AdminLog.CaptionEdited");
                    }
                    formatNameRange = [formatString rangeOfString:@"%@"];
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryDeleteMessage class]]) {
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    formatString = TGLocalized(@"Channel.AdminLog.MessageDeleted");
                    formatNameRange = [formatString rangeOfString:@"%@"];
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryChangePinnedMessage class]]) {
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    TGChannelAdminLogEntryDeleteMessage *concrete = (TGChannelAdminLogEntryDeleteMessage *)content;
                    if (concrete.message != nil) {
                        formatString = TGLocalized(@"Channel.AdminLog.MessagePinned");
                    } else {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageUnpinned");
                    }
                    formatNameRange = [formatString rangeOfString:@"%@"];
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryChangeStickerPack class]]) {
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    TGChannelAdminLogEntryChangeStickerPack *concrete = (TGChannelAdminLogEntryChangeStickerPack *)content;
                    if (concrete.stickerPack != nil) {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageChangedGroupStickerPack");
                        _stickerPackReference = concrete.stickerPack;
                    } else {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageRemovedGroupStickerPack");
                    }
                    formatNameRange = [formatString rangeOfString:@"%@"];
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                } else if ([content isKindOfClass:[TGChannelAdminLogEntryTogglePreHistoryHidden class]]) {
                    NSString *authorName = authorTitle;
                    NSString *formatString = nil;
                    NSRange formatNameRange = NSMakeRange(NSNotFound, 0);
                    TGChannelAdminLogEntryTogglePreHistoryHidden *concrete = (TGChannelAdminLogEntryTogglePreHistoryHidden *)content;
                    if (concrete.value) {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageGroupPreHistoryHidden");
                    } else {
                        formatString = TGLocalized(@"Channel.AdminLog.MessageGroupPreHistoryVisible");
                    }
                    formatNameRange = [formatString rangeOfString:@"%@"];
                    actionText = [[NSString alloc] initWithFormat:formatString, authorName];
                    
                    if (formatNameRange.location != NSNotFound && authorUid != 0)
                    {
                        NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleBoldFont], (__bridge NSString *)kCTFontAttributeName, nil];
                        NSRange range = NSMakeRange(formatNameRange.location, authorName.length);
                        additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
                        textCheckingResults = [[NSArray alloc] initWithObjects:[NSTextCheckingResult linkCheckingResultWithRange:range URL:[[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"tg-user://%lld", authorUid]]], nil];
                    }
                }
            }
            break;
        }
        case TGMessageActionClearChat:
            actionText = @"";
        default:
            break;
    }
    
    if (!TGStringCompare(_textModel.text, actionText)) {
        _textModel.text = actionText;
        _textModel.additionalAttributes = additionalAttributes;
        _textModel.textCheckingResults = textCheckingResults;
        if (underlineLinks) {
            _textModel.layoutFlags |= TGReusableLabelLayoutHighlightLinks;
        }
        
        return true;
    }
    
    return false;
}

- (instancetype)initWithMessage:(TGMessage *)message actionMedia:(TGActionMediaAttachment *)actionMedia authorPeer:(id)authorPeer additionalUsers:(NSArray *)additionalUsers context:(TGModernViewContext *)context
{
    self = [super initWithAuthorPeer:nil context:context];
    if (self != nil)
    {
        _mid = message.mid;
        _authorPeer = authorPeer;
        _additionalUsers = additionalUsers;
        _actionMedia = actionMedia;
        _message = message;
        
        _backgroundModel = [[TGModernImageViewModel alloc] initWithImage:context.presentation.images.chatSystemBackground];
        _backgroundModel.skipDrawInContext = true;
        [self addSubmodel:_backgroundModel];
        
        _contentModel = [[TGModernFlatteningViewModel alloc] initWithContext:_context];
        _contentModel.viewUserInteractionDisabled = true;
        [self addSubmodel:_contentModel];
        
        _textModel = [[TGModernTextViewModel alloc] initWithText:@"" font:[[TGTelegraphConversationMessageAssetsSource instance] messageActionTitleFont]];
        _textModel.textColor = context.presentation.pallete.chatSystemTextColor;
        _textModel.linkColor = context.presentation.pallete.chatSystemTextColor;
        _textModel.layoutFlags = TGReusableLabelLayoutMultiline;
        _textModel.alignment = NSTextAlignmentCenter;
        
        [self setupText];
        
        [_contentModel addSubmodel:_textModel];
    }
    return self;
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    _mid = message.mid;
    _message = message;
    for (id attachment in message.mediaAttachments) {
        if ([attachment isKindOfClass:[TGActionMediaAttachment class]]) {
            _actionMedia = attachment;
            break;
        }
    }
    
    if ([self setupText]) {
        if (sizeUpdated) {
            *sizeUpdated = true;
        }
    }
    
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];
}

- (void)updateMediaVisibility
{
    _imageModel.alpha = [_context isMediaVisibleInMessage:_mid peerId:_authorPeerId] ? 1.0f : 0.0f;
}

- (CGRect)effectiveContentFrame
{
    return _backgroundModel.frame;
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    
    [_backgroundModel bindViewToContainer:container viewStorage:viewStorage];
    [_backgroundModel boundView].frame = CGRectOffset([_backgroundModel boundView].frame, itemPosition.x, itemPosition.y);
    
    if (_imageModel != nil)
    {
        [_imageModel bindViewToContainer:container viewStorage:viewStorage];
        [_imageModel boundView].frame = CGRectOffset([_imageModel boundView].frame, itemPosition.x, itemPosition.y);
    }
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    _boundDoubleTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(messageDoubleTapGesture:)];
    _boundDoubleTapRecognizer.longPressDuration = [TGOnegramSettings boolForKey:TGOnegramSettingGeneralNewChats] ? 0.5 : 1.5;
    _boundDoubleTapRecognizer.delegate = self;
    
    UIView *backgroundView = [_backgroundModel boundView];
    [backgroundView addGestureRecognizer:_boundDoubleTapRecognizer];
    
    if (_callForMessageId != 0)
    {
        _tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)];
        [backgroundView addGestureRecognizer:_tapRecognizer];
    }
    
    if (_imageModel != nil)
    {
        _boundImageTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(imageDoubleTapGesture:)];
        _boundImageTapRecognizer.longPressDuration = [TGOnegramSettings boolForKey:TGOnegramSettingGeneralNewChats] ? 0.5 : 1.5;
        _boundImageTapRecognizer.delegate = self;
        
        UIView *imageView = [_imageModel boundView];
        [imageView addGestureRecognizer:_boundImageTapRecognizer];
    }
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    UIView *backgroundView = [_backgroundModel boundView];
    [backgroundView removeGestureRecognizer:_boundDoubleTapRecognizer];
    _boundDoubleTapRecognizer.delegate = nil;
    _boundDoubleTapRecognizer = nil;
    
    if (_imageModel != nil)
    {
        UIView *imageView = [_imageModel boundView];
        [imageView removeGestureRecognizer:_boundImageTapRecognizer];
        _boundImageTapRecognizer.delegate = nil;
        _boundImageTapRecognizer = nil;
    }
    
    if (_callForMessageId != 0)
    {
        [backgroundView removeGestureRecognizer:_tapRecognizer];
        _tapRecognizer = nil;
    }
    
    [super unbindView:viewStorage];
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan)
    {
        if (recognizer.state == UIGestureRecognizerStateRecognized)
        {
            CGPoint point = [recognizer locationInView:[_contentModel boundView]];
            NSString *linkCandidate = [_textModel linkAtPoint:CGPointMake(point.x - _textModel.frame.origin.x, point.y - _textModel.frame.origin.y) regionData:NULL];
            
            if (recognizer.longTapped || recognizer.doubleTapped)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            else if (linkCandidate != nil)
                [_context.companionHandle requestAction:@"openLinkRequested" options:@{@"url": linkCandidate}];
            else if (_navigateToMessageId != 0) {
                [_context.companionHandle requestAction:@"navigateToMessage" options:@{@"mid": @(_navigateToMessageId), @"sourceMid": @(_mid)}];
            } else if (_stickerPackReference != nil) {
                [_context.companionHandle requestAction:@"showStickerPack" options:@{@"stickerPack": _stickerPackReference}];
            }
        }
    }
}

- (void)imageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan)
    {
        if (recognizer.state == UIGestureRecognizerStateRecognized)
        {
            if (recognizer.longTapped)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            else
                [_context.companionHandle requestAction:@"openMediaRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
        }
    }
}

- (void)tapGesture:(UITapGestureRecognizer *)__unused recognizer
{
    if (_callForMessageId != 0) {
        [_context.companionHandle requestAction:@"callRequested" options:@{@"mid": @(_callForMessageId)}];
    }
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)recognizer shouldFailTap:(CGPoint)__unused point
{
    if (recognizer == _boundImageTapRecognizer)
        return 3;
    else if ([_textModel linkAtPoint:point regionData:nil] != nil || _navigateToMessageId != 0 || _stickerPackReference != nil)
        return 3;
    
    return false;
}

- (bool)gestureRecognizerShouldHandleLongTap:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    [_textModel layoutForContainerSize:CGSizeMake(containerSize.width - 30.0f, containerSize.height)];
    
    CGSize textSize = _textModel.frame.size;
    
    CGFloat backgroundWidth = MAX(60.0f, textSize.width + 14.0f);
    CGRect backgroundFrame = CGRectMake(CGFloor((containerSize.width - backgroundWidth) / 2.0f), 3.0f, backgroundWidth, MAX(21.0f, textSize.height + 4.0f));
    _backgroundModel.frame = backgroundFrame;
    
    _contentModel.frame = CGRectMake(backgroundFrame.origin.x + 7.0f - 2.0f, 1.0f - 2.0f, backgroundWidth - 6.0f + 4.0f, textSize.height + 2.0f + 4.0f);
    _textModel.frame = CGRectMake(2.0f, 3.0f, textSize.width, textSize.height);
    
    if (_imageModel != nil)
    {
        _imageModel.frame = CGRectMake(CGFloor((containerSize.width - 64.0f) / 2.0f), backgroundFrame.origin.y + backgroundFrame.size.height + 3.0f, 64.0f, 64.0f);
    }
    
    if (_textModel.text.length == 0 || [_textModel.text isEqual:@" "]) {
        _backgroundModel.alpha = 0.0f;
        self.frame = CGRectMake(0, 0, containerSize.width, 1.0f);
    } else {
        _backgroundModel.alpha = 1.0f;
        self.frame = CGRectMake(0, 0, containerSize.width, backgroundFrame.size.height + 6 + (_imageModel != nil ? 68 : 0));
    }
    
    [_contentModel setNeedsSubmodelContentsUpdate];
    [_contentModel updateSubmodelContentsIfNeeded];
    
    [super layoutForContainerSize:containerSize];
}

- (UIView *)referenceViewForImageTransition
{
    return [_imageModel boundView];
}

- (bool)isPreviewableAtPoint:(CGPoint)point
{
    return CGRectContainsPoint(_imageModel.frame, point);
}

@end
