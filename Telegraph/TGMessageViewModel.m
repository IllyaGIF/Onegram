#import "TGMessageViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"

#import "TGModernViewContext.h"

#import "TGModernRemoteImageViewModel.h"
#import "TGModernButtonViewModel.h"
#import "TGMessageCommentsFooterViewModel.h"
#import "TGModernCheckButtonViewModel.h"

#import "TGMessageModernConversationItem.h"

#import "TGModernLetteredAvatarViewModel.h"

#import "TGModernImageViewModel.h"

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGPresentation.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static CGFloat preferredTextFontSize;

void TGMessageViewModelLayoutSetPreferredTextFontSize(CGFloat fontSize)
{
    preferredTextFontSize = fontSize;
}

bool TGMessageViewModelShouldDisplayConversationAvatar(TGConversation *author, TGModernViewContext *context)
{
    if (author == nil)
        return false;
    TGConversation *conversation = [context conversation];
    bool currentBroadcastChannel = author.isChannel && !author.isChannelGroup && conversation != nil && author.conversationId == conversation.conversationId;
    return !currentBroadcastChannel || context.isAdminLog || context.isSavedMessages || context.isFeed;
}

static TGMessageViewModelLayoutConstants currentMessageViewModelLayoutConstants;
static CGFloat currentMessageViewModelDefaultTextFontSize = 17.0f;

static CGFloat TGMessageDesktopDeviceScale(void)
{
    static CGFloat deviceScale = 1.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
            deviceScale = 1.1f;
        else
        {
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            CGFloat shortSide = MIN(screenSize.width, screenSize.height);
            if (shortSide <= 320.0f)
                deviceScale = 0.9f;
            else if (shortSide <= 375.0f)
                deviceScale = 0.95f;
            else
                deviceScale = 1.0f;
        }
    });
    return deviceScale;
}

CGFloat TGMessageDesktopScale(void)
{
    const TGMessageViewModelLayoutConstants *constants = TGGetMessageViewModelLayoutConstants();
    CGFloat textFactor = constants->textFontSize / MAX(1.0f, currentMessageViewModelDefaultTextFontSize);
    return TGMessageDesktopDeviceScale() * MAX(0.8f, MIN(1.4f, textFactor));
}

CGFloat TGMessageDesktopMetric(CGFloat desktopPixels)
{
    return TGRetinaFloor(desktopPixels * TGMessageDesktopScale());
}

CGFloat TGMessageFontScale(void)
{
    return TGGetMessageViewModelLayoutConstants()->textFontSize / 17.0f;
}

CGFloat TGMessageFontMetric(CGFloat points)
{
    return TGRetinaFloor(points * TGMessageFontScale());
}

const TGMessageViewModelLayoutConstants *TGGetMessageViewModelLayoutConstants()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        TGMessageViewModelLayoutConstants constants;
        
        CGFloat minTextFontSize = 0.0f;
        CGFloat maxTextFontSize = 0.0f;
        CGFloat defaultTextFontSize = 0.0f;
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            constants.topInset = 2.0f;
            constants.bottomInset = 2.0f;
            constants.topInsetCollapsed = 1.0f;
            constants.bottomInsetCollapsed = 0.0f;
            
            constants.leftInset = 4.0f;
            constants.rightInset = 4.0f;
            
            constants.leftImageInset = 9.0f;
            constants.rightImageInset = 9.0f;
            
            constants.avatarInset = 3.0f;
            
            constants.textBubblePaddingTop = 5.0f;
            constants.textBubblePaddingBottom = 5.0f;
            constants.textBubbleTextOffsetTop = 1.0f;
            
            constants.topPostInset = 2.0f;
            constants.bottomPostInset = 2.0f;
            
            minTextFontSize = 12.0f;
            maxTextFontSize = 26.0f;
            
            defaultTextFontSize = [TGPresentation brandedIOS6Style] ? [TGPresentation brandedIOS6ConversationAppearance].messageFont.pointSize : 17.0f;
        }
        else
        {
            constants.topInset = 3.0f;
            constants.bottomInset = 3.0f;
            constants.topInsetCollapsed = 1.0f;
            constants.bottomInsetCollapsed = 1.0f;
            
            constants.leftInset = 17.0f;
            constants.rightInset = 17.0f;
            
            constants.leftImageInset = 23.0f;
            constants.rightImageInset = 23.0f;
            
            constants.avatarInset = 11.0f;
            
            constants.topPostInset = 3.0f;
            constants.bottomPostInset = 3.0f;
            
            constants.textBubblePaddingTop = 5.0f;
            constants.textBubblePaddingBottom = 6.0f;
            constants.textBubbleTextOffsetTop = 1.0f + TGScreenPixel;
            
            minTextFontSize = 13.0f;
            maxTextFontSize = 26.0f;
            defaultTextFontSize = 17.0f;
        }
        
        if (iosMajorVersion() >= 7 && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            constants.textFontSize = MAX(minTextFontSize, MIN(maxTextFontSize, defaultTextFontSize));
        }
        else
        {
            if (preferredTextFontSize == 0)
                constants.textFontSize = defaultTextFontSize;
            else
                constants.textFontSize = MAX(minTextFontSize, MIN(maxTextFontSize, preferredTextFontSize));
        }
        
        currentMessageViewModelLayoutConstants = constants;
        currentMessageViewModelDefaultTextFontSize = defaultTextFontSize;
    });
    
    return &currentMessageViewModelLayoutConstants;
}

void TGUpdateMessageViewModelLayoutConstants(CGFloat baseFontPointSize)
{
    TGGetMessageViewModelLayoutConstants();
    
    CGFloat minTextFontSize = 0.0f;
    CGFloat maxTextFontSize = 0.0f;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        minTextFontSize = 12.0f;
        maxTextFontSize = 24.0f;
    }
    else
    {
        minTextFontSize = 13.0f;
        maxTextFontSize = 26.0f;
    }
        
    CGFloat fontSize = baseFontPointSize;
    currentMessageViewModelLayoutConstants.textFontSize = MAX(minTextFontSize, MIN(maxTextFontSize, fontSize));
}

static NSString *TGIOS6CommentsColorKey(UIColor *color)
{
    if (color == nil)
        return @"nil";
    CGColorRef cgColor = color.CGColor;
    size_t count = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *components = CGColorGetComponents(cgColor);
    NSMutableString *key = [[NSMutableString alloc] initWithCapacity:48];
    for (size_t i = 0; i < count; i++)
        [key appendFormat:@"%.4f,", components[i]];
    return key;
}

static NSCache *TGIOS6CommentsImageCache()
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 48;
    });
    return cache;
}

static UIImage *TGIOS6CommentsStandaloneBackgroundImage(UIColor *fillColor, UIColor *strokeColor, CGFloat cornerRadius)
{
    NSString *cacheKey = [NSString stringWithFormat:@"s|%@|%@|%.2f", TGIOS6CommentsColorKey(fillColor), TGIOS6CommentsColorKey(strokeColor), cornerRadius];
    UIImage *cachedImage = [TGIOS6CommentsImageCache() objectForKey:cacheKey];
    if (cachedImage != nil)
        return cachedImage;
    CGSize size = CGSizeMake(30.0f, 30.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);

    UIColor *fill = fillColor != nil ? fillColor : [UIColor colorWithWhite:0.94f alpha:1.0f];
    UIColor *stroke = strokeColor != nil ? strokeColor : [UIColor colorWithWhite:0.78f alpha:1.0f];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5f, 0.5f, 29.0f, 29.0f) cornerRadius:cornerRadius];
    [fill setFill];
    [path fill];
    [stroke setStroke];
    path.lineWidth = 1.0f;
    [path stroke];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if ([image respondsToSelector:@selector(resizableImageWithCapInsets:)])
        image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(14.0f, 14.0f, 14.0f, 14.0f)];
    else
        image = [image stretchableImageWithLeftCapWidth:14 topCapHeight:14];
    if (image != nil)
        [TGIOS6CommentsImageCache() setObject:image forKey:cacheKey];
    return image;
}

static UIImage *TGIOS6CommentsAttachedFooterImage(UIColor *highlightColor, UIColor *separatorColor, bool highlighted)
{
    NSString *cacheKey = [NSString stringWithFormat:@"a|%@|%@|%d", TGIOS6CommentsColorKey(highlightColor), TGIOS6CommentsColorKey(separatorColor), highlighted ? 1 : 0];
    UIImage *cachedImage = [TGIOS6CommentsImageCache() objectForKey:cacheKey];
    if (cachedImage != nil)
        return cachedImage;

    CGSize size = CGSizeMake(30.0f, 36.0f);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (highlighted && highlightColor != nil)
    {
        CGContextSetFillColorWithColor(context, highlightColor.CGColor);
        CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    }

    UIColor *separator = separatorColor != nil ? separatorColor : [UIColor colorWithWhite:0.0f alpha:0.12f];
    CGContextSetFillColorWithColor(context, separator.CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, TGScreenPixel));

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if ([image respondsToSelector:@selector(resizableImageWithCapInsets:)])
        image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(1.0f, 14.0f, 17.0f, 14.0f)];
    else
        image = [image stretchableImageWithLeftCapWidth:14 topCapHeight:1];
    if (image != nil)
        [TGIOS6CommentsImageCache() setObject:image forKey:cacheKey];
    return image;
}

static NSString *TGIOS6CommentsTitleForCount(int32_t count)
{
    if (count <= 0)
        return @"Оставить комментарий";

    int32_t value = count < 0 ? -count : count;
    int32_t mod100 = value % 100;
    int32_t mod10 = value % 10;
    NSString *word = @"комментариев";
    if (mod100 < 11 || mod100 > 14)
    {
        if (mod10 == 1)
            word = @"комментарий";
        else if (mod10 >= 2 && mod10 <= 4)
            word = @"комментария";
    }
    return [NSString stringWithFormat:@"%d %@", count, word];
}

@interface TGMessageViewModel ()
{
    int _uid;
    NSString *_firstName;
    NSString *_lastName;
    
    UITapGestureRecognizer *_boundAvatarTapRecognizer;
    
    TGModernButtonViewModel *_checkAreaModel;
    TGModernCheckButtonViewModel *_checkButtonModel;
    
    TGModernImageViewModel *_replyIconModel;
    
    UIImpactFeedbackGenerator *_feedbackGenerator;

    TGModernButtonViewModel *_ios6CommentsButtonModel;
    TGMessageCommentsFooterViewModel *_ios6CommentsFooterModel;
    bool _ios6CommentsEnabled;
    int32_t _ios6CommentsCount;
    int64_t _ios6CommentsChannelId;
    NSArray *_ios6CommentsRecentRepliers;
    int32_t _ios6CommentsMessageId;
}

@end

@implementation TGMessageViewModelReference

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _condition = [[NSCondition alloc] init];
    return self;
}

- (void)setValue:(TGMessageViewModel *)value
{
    [_condition lock];
    _value = value;
    [_condition unlock];
}

- (void)withValue:(void (^)(void *value))block
{
    if (block == nil)
        return;

    void *value = NULL;
    [_condition lock];
    __attribute__((objc_precise_lifetime)) __strong TGMessageViewModel *currentValue = _value;
    if (currentValue != nil)
    {
        _activeCallbacks++;
        value = (__bridge void *)currentValue;
    }
    [_condition unlock];

    if (value != NULL)
    {
        @try
        {
            block(value);
        }
        @finally
        {
            [_condition lock];
            if (_activeCallbacks != 0)
                _activeCallbacks--;
            if (_activeCallbacks == 0)
                [_condition broadcast];
            [_condition unlock];
        }
    }
}

- (void)invalidate
{
    [_condition lock];
    _value = nil;
    while (_activeCallbacks != 0)
        [_condition wait];
    [_condition unlock];
}

@end

static char TGMessageViewModelReplyPanRecognizerPoolKey;
static char TGMessageViewModelAvatarTapRecognizerPoolKey;

@implementation TGMessageViewModel

- (void)dealloc
{
    TGModernViewModelRelinquishGestureRecognizer(_replyPanGestureRecognizer, &TGMessageViewModelReplyPanRecognizerPoolKey, self, @selector(replyPanGesture:));
    TGModernViewModelRelinquishGestureRecognizer(_boundAvatarTapRecognizer, &TGMessageViewModelAvatarTapRecognizerPoolKey, self, @selector(avatarTapGesture:));
    [self invalidateLifetimeReference];
    _ios6CommentsButtonModel.pressed = nil;
}

- (void)invalidateLifetimeReference
{
    [_lifetimeReference invalidate];
}

- (void)setGroupedMediaOffsetX:(CGFloat)x y:(CGFloat)y
{
    _groupedMediaOffsetX = x;
    _groupedMediaOffsetY = y;
}

- (CGFloat)groupedMediaOffsetX
{
    return _groupedMediaOffsetX;
}

- (CGFloat)groupedMediaOffsetY
{
    return _groupedMediaOffsetY;
}

- (TGMessageViewModelReference *)lifetimeReference
{
    if (_lifetimeReference == nil)
    {
        _lifetimeReference = [[TGMessageViewModelReference alloc] init];
        [_lifetimeReference setValue:self];
    }
    return _lifetimeReference;
}

- (instancetype)initWithAuthorPeer:(id)authorPeer context:(TGModernViewContext *)context
{
    self = [super init];
    if (self != nil)
    {
        self.hasNoView = true;
        _context = context;
        _authorPeer = authorPeer;
        
        UIImage *placeholder = [context.presentation.images avatarPlaceholderWithDiameter:40.0f];
        if (authorPeer != nil && [authorPeer isKindOfClass:[TGUser class]])
        {
            TGUser *author = authorPeer;
            _uid = author.uid;
            _firstName = author.firstName;
            _lastName = author.lastName;
            
            _avatarModel = [[TGModernLetteredAvatarViewModel alloc] initWithSize:CGSizeMake(38.0f, 38.0f) placeholder:placeholder];
            _avatarModel.skipDrawInContext = true;
            [self addSubmodel:_avatarModel];
        } else if ([authorPeer isKindOfClass:[TGConversation class]]) {
            TGConversation *author = authorPeer;
            if (TGMessageViewModelShouldDisplayConversationAvatar(author, context))
            {
                _firstName = author.chatTitle;
                _avatarModel = [[TGModernLetteredAvatarViewModel alloc] initWithSize:CGSizeMake(38.0f, 38.0f) placeholder:placeholder];
                _avatarModel.skipDrawInContext = true;
                [self addSubmodel:_avatarModel];
            }
        }
        
        if (iosMajorVersion() >= 10)
            _feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    }
    return self;
}

- (void)setAuthorAvatarUrl:(NSString *)authorAvatarUrl groupId:(int64_t)groupId
{
    if (authorAvatarUrl.length == 0)
        [_avatarModel setAvatarTitle:_firstName groupId:groupId];
    else
        [_avatarModel setAvatarUri:authorAvatarUrl];
}

- (void)setAuthorAvatarUrl:(NSString *)authorAvatarUrl
{
    if (authorAvatarUrl.length == 0)
        [_avatarModel setAvatarFirstName:_firstName lastName:_lastName uid:_uid];
    else
        [_avatarModel setAvatarUri:authorAvatarUrl];
}

- (void)setAuthorNameColor:(UIColor *)__unused authorNameColor
{
}

- (void)setAuthorSignature:(NSString *)__unused authorSignature {
}

- (void)_ios6UpdateCommentsButtonAssets
{
    if (_ios6CommentsButtonModel == nil)
        return;

    TGPresentationPallete *pallete = _context.presentation.pallete;
    bool incoming = _incomingAppearance;
    bool classic = [TGPresentation classicIOS6Style];
    bool paletteClassic = classic && [TGPresentation classicIOS6UsesPaletteAdaptedAssets];

    UIColor *fillColor = incoming ? pallete.chatIncomingBubbleColor : pallete.chatOutgoingBubbleColor;
    UIColor *highlightedFillColor = incoming ? pallete.chatIncomingHighlightedBubbleColor : pallete.chatOutgoingHighlightedBubbleColor;
    UIColor *strokeColor = incoming ? pallete.chatIncomingBubbleBorderColor : pallete.chatOutgoingBubbleBorderColor;
    UIColor *titleColor = incoming ? pallete.chatIncomingAccentColor : pallete.chatOutgoingAccentColor;

    if (classic && !paletteClassic)
    {
        fillColor = UIColorRGB(0xf7f7f7);
        highlightedFillColor = UIColorRGB(0xd9e2eb);
        strokeColor = UIColorRGB(0xaeb8c2);
        titleColor = UIColorRGB(0x315f8e);
    }

    UIColor *resolvedTitleColor = titleColor != nil ? titleColor : pallete.accentColor;
    if ([self discussionCommentsFooterIntegratedInBubble])
    {
        UIColor *separatorColor = [resolvedTitleColor colorWithAlphaComponent:classic ? 0.22f : 0.16f];
        UIImage *footerImage = TGIOS6CommentsAttachedFooterImage(nil, separatorColor, false);
        _ios6CommentsButtonModel.backgroundImage = footerImage;
        _ios6CommentsButtonModel.highlightedBackgroundImage = footerImage;
    }
    else
    {
        _ios6CommentsButtonModel.backgroundImage = TGIOS6CommentsStandaloneBackgroundImage(fillColor, strokeColor, classic ? 5.0f : 7.0f);
        _ios6CommentsButtonModel.highlightedBackgroundImage = TGIOS6CommentsStandaloneBackgroundImage(highlightedFillColor, strokeColor, classic ? 5.0f : 7.0f);
    }

    _ios6CommentsButtonModel.titleColor = resolvedTitleColor;
    _ios6CommentsButtonModel.font = classic ? [UIFont boldSystemFontOfSize:12.0f] : [UIFont boldSystemFontOfSize:13.0f];
    _ios6CommentsButtonModel.image = nil;
}

- (bool)setDiscussionCommentsEnabled:(bool)enabled count:(int32_t)count channelId:(int64_t)channelId recentRepliers:(NSArray *)recentRepliers messageId:(int32_t)messageId
{
    int32_t resolvedCount = MAX(0, count);
    NSArray *resolvedRepliers = recentRepliers ?: @[];
    bool enabledChanged = _ios6CommentsEnabled != enabled;
    bool countChanged = _ios6CommentsCount != resolvedCount;
    bool channelChanged = _ios6CommentsChannelId != channelId;
    bool repliersChanged = !TGObjectCompare(_ios6CommentsRecentRepliers, resolvedRepliers);
    int32_t resolvedMessageId = messageId != 0 ? messageId : _mid;
    bool messageChanged = _ios6CommentsMessageId != resolvedMessageId;
    if (!enabledChanged && !countChanged && !channelChanged && !repliersChanged && !messageChanged)
        return false;

    _ios6CommentsEnabled = enabled;
    _ios6CommentsCount = resolvedCount;
    _ios6CommentsChannelId = channelId;
    _ios6CommentsRecentRepliers = [resolvedRepliers copy];
    _ios6CommentsMessageId = resolvedMessageId;

    bool createdButton = false;
    if (enabled && _ios6CommentsButtonModel == nil)
    {
        _ios6CommentsButtonModel = [[TGModernButtonViewModel alloc] init];
        _ios6CommentsButtonModel.modernHighlight = true;
        _ios6CommentsButtonModel.extendedEdgeInsets = UIEdgeInsetsMake(2.0f, 0.0f, 2.0f, 0.0f);

        [self addSubmodel:_ios6CommentsButtonModel];
        [self _ios6UpdateCommentsButtonAssets];
        createdButton = true;
    }

    bool createdFooter = false;
    if (enabled && _ios6CommentsFooterModel == nil && [TGPresentation brandedIOS6Style])
    {
        _ios6CommentsFooterModel = [[TGMessageCommentsFooterViewModel alloc] init];
        _ios6CommentsFooterModel.presentation = _context.presentation;
        _ios6CommentsFooterModel.title = TGLocalized(@"Conversation.CommentsFooterTitle");
        [self addSubmodel:_ios6CommentsFooterModel];
        createdFooter = true;
    }

    if (enabled && (createdButton || createdFooter || channelChanged || messageChanged))
    {
        id companionHandle = _context.companionHandle;
        int32_t discussionMessageId = _ios6CommentsMessageId;
        int64_t discussionChannelId = _ios6CommentsChannelId;
        void (^openComments)(void) = ^
        {
            [companionHandle requestAction:@"ios6OpenComments" options:@{
                @"mid": @(discussionMessageId),
                @"discussionChannelId": @(discussionChannelId)
            }];
        };
        _ios6CommentsButtonModel.pressed = openComments;
        _ios6CommentsFooterModel.pressed = openComments;
    }

    if (_ios6CommentsButtonModel != nil)
    {
        if (enabledChanged || createdButton)
            _ios6CommentsButtonModel.hidden = !enabled;
        if (enabled && (countChanged || createdButton))
            _ios6CommentsButtonModel.title = TGIOS6CommentsTitleForCount(_ios6CommentsCount);
    }

    if (_ios6CommentsFooterModel != nil)
    {
        if (enabledChanged || createdFooter)
            _ios6CommentsFooterModel.hidden = !enabled;
        if (enabled && (countChanged || createdFooter))
            _ios6CommentsFooterModel.count = _ios6CommentsCount;
        if (enabled && (repliersChanged || createdFooter))
            _ios6CommentsFooterModel.repliers = [TGMessageCommentsFooterReplier repliersWithPeerIds:_ios6CommentsRecentRepliers];
    }

    return enabledChanged || (enabled && (countChanged || repliersChanged));
}

- (bool)_ios6UsesBrandedCommentsFooter
{
    return _ios6CommentsFooterModel != nil && [TGPresentation brandedIOS6Style] && [self discussionCommentsFooterIntegratedInBubble];
}

- (CGFloat)discussionCommentsFooterHeight
{
    if (!_ios6CommentsEnabled)
        return 0.0f;
    if ([self _ios6UsesBrandedCommentsFooter])
        return [TGPresentation brandedIOS6ConversationAppearance].commentsFooterHeight;
    return 36.0f;
}

- (CGFloat)discussionCommentsFooterMinimumWidth
{
    if (!_ios6CommentsEnabled)
        return 0.0f;

    if ([self _ios6UsesBrandedCommentsFooter])
    {
        OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
        UIEdgeInsets bubbleInsets = [TGPresentation brandedIOS6BubbleImageInsetsOutgoing:!_incomingAppearance];
        NSUInteger avatarCount = MIN(_ios6CommentsRecentRepliers.count, appearance.commentsAvatarMaximumCount);
        CGFloat titleX = avatarCount == 0 ? appearance.commentsTitleLeftWithoutAvatars : (appearance.commentsAvatarLeft + appearance.commentsAvatarStep * (avatarCount - 1) + appearance.commentsAvatarSize + appearance.commentsTitleSpacing);
        CGFloat titleWidth = ceilf([TGLocalized(@"Conversation.CommentsFooterTitle") sizeWithFont:appearance.commentsTitleFont].width);
        CGFloat countWidth = _ios6CommentsCount > 0 ? (ceilf([[NSString stringWithFormat:@"+%d", (int)_ios6CommentsCount] sizeWithFont:appearance.commentsCountFont].width) + appearance.commentsCountSpacing) : 0.0f;
        CGFloat chevronWidth = [TGPresentation brandedIOS6CommentsChevronImage].size.width;
        return bubbleInsets.left + titleX + titleWidth + appearance.commentsCountSpacing + countWidth + chevronWidth + appearance.commentsChevronRightInset + bubbleInsets.right;
    }

    UIFont *font = _ios6CommentsButtonModel.font;
    if (font == nil)
        font = [TGPresentation classicIOS6Style] ? [UIFont boldSystemFontOfSize:12.0f] : [UIFont boldSystemFontOfSize:13.0f];
    NSString *title = TGIOS6CommentsTitleForCount(_ios6CommentsCount);
    CGSize titleSize = [title sizeWithFont:font];
    return MAX(132.0f, titleSize.width + 48.0f);
}

- (bool)discussionCommentsFooterIntegratedInBubble
{
    return false;
}

- (CGRect)discussionCommentsBubbleFrame
{
    return [self effectiveContentFrame];
}

- (bool)brandedCommentsFooterTop:(CGFloat *)footerTop bubbleFrame:(CGRect)bubbleFrame
{
    if (!_ios6CommentsEnabled || ![self _ios6UsesBrandedCommentsFooter])
        return false;

    UIEdgeInsets bubbleInsets = [TGPresentation brandedIOS6BubbleImageInsetsOutgoing:!_incomingAppearance];
    if (footerTop != NULL)
        *footerTop = CGRectGetMaxY(bubbleFrame) - bubbleInsets.bottom - [self discussionCommentsFooterHeight];
    return true;
}

- (bool)brandedCommentsCountRight:(CGFloat *)countRight bubbleFrame:(CGRect)bubbleFrame
{
    if (!_ios6CommentsEnabled || _ios6CommentsCount <= 0 || ![self _ios6UsesBrandedCommentsFooter])
        return false;

    OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
    UIEdgeInsets bubbleInsets = [TGPresentation brandedIOS6BubbleImageInsetsOutgoing:!_incomingAppearance];
    CGFloat chevronWidth = [TGPresentation brandedIOS6CommentsChevronImage].size.width;
    if (countRight != NULL)
        *countRight = CGRectGetMaxX(bubbleFrame) - bubbleInsets.right - appearance.commentsChevronRightInset - chevronWidth - appearance.commentsCountSpacing;
    return true;
}

- (void)updateAssets
{
    [self _ios6UpdateCommentsButtonAssets];
}

- (void)refreshMetrics
{
}

- (void)updateSearchText:(bool)__unused animated
{
}

- (void)updateMessage:(TGMessage *)__unused message viewStorage:(TGModernViewStorage *)__unused viewStorage sizeUpdated:(bool *)__unused sizeUpdated
{
}

- (void)relativeBoundsUpdated:(CGRect)__unused bounds
{
}

- (void)imageDataInvalidated:(NSString *)__unused imageUrl
{
}

- (CGRect)effectiveContentFrame
{
    return CGRectZero;
}

- (CGRect)fullContentFrame
{
    return [self effectiveContentFrame];
}

- (UIView *)referenceViewForImageTransition
{
    return nil;
}

- (void)setTemporaryHighlighted:(bool)__unused temporaryHighlighted viewStorage:(TGModernViewStorage *)__unused viewStorage
{
}

- (void)clearHighlights
{
}

- (void)updateProgress:(bool)__unused progressVisible progress:(float)__unused progress viewStorage:(TGModernViewStorage *)__unused viewStorage animated:(bool)__unused animated
{
}

- (void)updateMediaAvailability:(bool)__unused mediaIsAvailable viewStorage:(TGModernViewStorage *)__unused viewStorage delayDisplay:(bool)__unused delayDisplay
{
}

- (void)updateMediaVisibility
{
}

- (void)updateMessageFocus
{
}

- (void)prepareForAsynchronousContentDrawing
{
}

- (TGModernLetteredAvatarViewModel *)conversationAvatarModel
{
    return (_collapseFlags & TGModernConversationItemCollapseBottom) ? nil : _avatarModel;
}

- (void)updateMessageAttributes
{
}

- (void)updateMessageVisibility
{
}

- (void)updateInlineMediaContext
{
}

- (void)updateAnimationsEnabled
{
}

- (void)stopInlineMedia:(int32_t)__unused excludeMid
{
}

- (void)resumeInlineMedia
{
}

- (void)activateDeferredInlineMedia
{
}

- (NSString *)linkAtPoint:(CGPoint)__unused point {
    return nil;
}

- (bool)isPreviewableAtPoint:(CGPoint)__unused point {
    return false;
}

- (void)updateEditingState:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage animationDelay:(NSTimeInterval)animationDelay
{
    if (!_needsEditingCheckButton)
        return;
    
    bool editing = _context.editing;
    
    if (editing != _editing)
    {
        _editing = editing;
        
        if (_editing)
        {
            if (_checkAreaModel == nil)
            {
                _checkAreaModel = [[TGModernButtonViewModel alloc] init];
                _checkAreaModel.skipDrawInContext = true;
                _checkAreaModel.frame = [self editingCheckAreaFrame];
                [self addSubmodel:_checkAreaModel];
                
                if (container != nil)
                {
                    [_checkAreaModel bindViewToContainer:container viewStorage:viewStorage];
                    
                    [(UIButton *)[_checkAreaModel boundView] addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                }
            }
        }
        else if (_checkAreaModel != nil)
        {
            if ([_checkAreaModel boundView] != nil)
            {
                [(UIButton *)[_checkAreaModel boundView] removeTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            }
            
            [self removeSubmodel:_checkAreaModel viewStorage:viewStorage];
            _checkAreaModel = nil;
        }
        
        if (animationDelay > -FLT_EPSILON && container != nil)
        {
            UIView<TGModernView> *checkView = nil;
            
            if (_editing)
            {
                if (_checkButtonModel == nil)
                {
                    _checkButtonModel = [[TGModernCheckButtonViewModel alloc] initWithFrame:self.editingCheckButtonFrame];
                    _checkButtonModel.isChecked = [_context isMessageChecked:_mid peerId:_authorPeerId];
                    [self addSubmodel:_checkButtonModel];
                    
                    if (container != nil)
                    {
                        [_checkButtonModel bindViewToContainer:container viewStorage:viewStorage];
                        
                        [(UIButton *)[_checkButtonModel boundView] addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                    }
                }
                
                if (_editingCheckButtonGrowTransition)
                {
                    [_checkButtonModel boundView].center = CGPointMake(CGRectGetMidX(_checkButtonModel.frame) - (_incomingAppearance ? 42.0f : 0.0f), CGRectGetMidY(_checkButtonModel.frame));
                    [_checkButtonModel boundView].transform = CGAffineTransformMakeScale(0.001, 0.001);
                }
                else
                {
                    [_checkButtonModel boundView].frame = CGRectOffset(_checkButtonModel.frame, -49.0f, 0.0f);
                }
            }
            else if (_checkButtonModel != nil)
            {
                if ([_checkButtonModel boundView] != nil)
                {
                    [(UIButton *)[_checkButtonModel boundView] removeTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                }
                
                [self removeSubmodel:_checkButtonModel viewStorage:viewStorage];
                checkView = [_checkButtonModel _dequeueView:viewStorage];
                checkView.frame = _checkButtonModel.frame;
                [container addSubview:checkView];
                _checkButtonModel = nil;
            }
            
            UIViewAnimationOptions options = UIViewAnimationOptionAllowAnimatedContent;
            if (iosMajorVersion() >= 7)
                options |= 7 << 16;
            [UIView animateWithDuration:MAX(0.025, 0.18 - animationDelay) delay:animationDelay options:options animations:^
            {
                if (self.frame.size.width > FLT_EPSILON)
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                
                if (_editingCheckButtonGrowTransition)
                {
                    if (_editing)
                    {
                        [_checkButtonModel boundView].center = CGPointMake(CGRectGetMidX(_checkButtonModel.frame), CGRectGetMidY(_checkButtonModel.frame));
                        [_checkButtonModel boundView].transform = CGAffineTransformIdentity;
                    }
                    else
                    {
                        checkView.center = CGPointMake(checkView.center.x - (_incomingAppearance ? 42.0f : 0.0f), checkView.center.y);
                        checkView.transform = CGAffineTransformMakeScale(0.001, 0.001);
                    }
                }
                else
                {
                    if (_editing)
                        [_checkButtonModel boundView].frame = _checkButtonModel.frame;
                    else
                        checkView.frame = CGRectOffset(checkView.frame, -49.0f, 0.0f);
                }
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
            
            if (_editing)
            {
                if (_checkButtonModel == nil)
                {
                    _checkButtonModel = [[TGModernCheckButtonViewModel alloc] initWithFrame:self.editingCheckButtonFrame];
                    _checkButtonModel.isChecked = [_context isMessageChecked:_mid peerId:_authorPeerId];
                    [self addSubmodel:_checkButtonModel];
                
                    if (container != nil)
                    {
                        [_checkButtonModel bindViewToContainer:container viewStorage:viewStorage];
                        
                        [(UIButton *)[_checkButtonModel boundView] addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                    }
                }
            }
            else if (_checkButtonModel != nil)
            {
                if ([_checkButtonModel boundView] != nil)
                {
                    [(UIButton *)[_checkButtonModel boundView] removeTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
                }
                
                [self removeSubmodel:_checkButtonModel viewStorage:viewStorage];
                _checkButtonModel = nil;
            }
        }
    }
    else if (editing)
        _checkButtonModel.isChecked = [_context isMessageChecked:_mid peerId:_authorPeerId];
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{   
    if (_avatarModel != nil)
    {
        [_avatarModel bindViewToContainer:container viewStorage:viewStorage];
        [_avatarModel boundView].frame = CGRectOffset([_avatarModel boundView].frame, itemPosition.x, itemPosition.y);
    }
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    if (_avatarModel != nil)
        _boundAvatarTapRecognizer = TGModernViewModelAcquireGestureRecognizer([_avatarModel boundView], &TGMessageViewModelAvatarTapRecognizerPoolKey, [UITapGestureRecognizer class], self, @selector(avatarTapGesture:));
    
    if (_checkButtonModel != nil)
        [(UIButton *)[_checkButtonModel boundView] addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    if (_checkAreaModel != nil)
        [(UIButton *)[_checkAreaModel boundView] addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    _replyPanGestureRecognizer = TGModernViewModelAcquireGestureRecognizer(container, &TGMessageViewModelReplyPanRecognizerPoolKey, [UIPanGestureRecognizer class], self, @selector(replyPanGesture:));
    _replyPanGestureRecognizer.delegate = self;
}

- (void)moveViewToContainer:(UIView *)container
{
    bool hadReplyPanGestureRecognizer = _replyPanGestureRecognizer != nil;
    TGModernViewModelRelinquishGestureRecognizer(_replyPanGestureRecognizer, &TGMessageViewModelReplyPanRecognizerPoolKey, self, @selector(replyPanGesture:));
    _replyPanGestureRecognizer = nil;
    
    [super moveViewToContainer:container];
    
    if (hadReplyPanGestureRecognizer)
    {
        _replyPanGestureRecognizer = TGModernViewModelAcquireGestureRecognizer(container, &TGMessageViewModelReplyPanRecognizerPoolKey, [UIPanGestureRecognizer class], self, @selector(replyPanGesture:));
        _replyPanGestureRecognizer.delegate = self;
    }
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    if (_avatarModel != nil)
    {
        TGModernViewModelRelinquishGestureRecognizer(_boundAvatarTapRecognizer, &TGMessageViewModelAvatarTapRecognizerPoolKey, self, @selector(avatarTapGesture:));
        _boundAvatarTapRecognizer = nil;
    }
    
    _replyPanOffset = 0.0f;
    TGModernViewModelRelinquishGestureRecognizer(_replyPanGestureRecognizer, &TGMessageViewModelReplyPanRecognizerPoolKey, self, @selector(replyPanGesture:));
    _replyPanGestureRecognizer = nil;
    
    if (_checkButtonModel != nil)
        [(UIButton *)[_checkButtonModel boundView] removeTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    if (_checkAreaModel != nil)
        [(UIButton *)[_checkAreaModel boundView] removeTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    [super unbindView:viewStorage];
}

- (void)avatarTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_context.companionHandle requestAction:@"userAvatarTapped" options:@{@"uid": @(_uid), @"mid": @(_mid)}];
    }
}

- (void)updateReplySwipeInteraction:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage ended:(bool)ended
{
    CGFloat inset = _avatarModel != nil ? 0.0f : 0.0f;
    if (!ended)
    {
        if (_replyIconModel == nil)
        {
            CGFloat x = _replyPanOffset > 0 ? inset : self.frame.size.width;

            _replyIconModel = [[TGModernImageViewModel alloc] initWithImage:_context.presentation.images.chatActionReplyImage];
            _replyIconModel.frame = CGRectMake(x, CGFloor((self.frame.size.height - 33.0f) / 2.0f), 33.0f, 33.0f);
            _replyIconModel.skipDrawInContext = true;
            [self addSubmodel:_replyIconModel];
            
            if (container != nil)
                [_replyIconModel bindViewToContainer:container viewStorage:viewStorage];
            
            _replyIconModel.alpha = 0.0f;
            [_replyIconModel boundView].transform = CGAffineTransformMakeScale(0.01f, 0.01f);
        }
    }
    else
    {
        UIView<TGModernView> *iconView = nil;
        
        [self removeSubmodel:_replyIconModel viewStorage:viewStorage];
        iconView = [_replyIconModel _dequeueView:viewStorage];
        
        CGFloat x = _replyPanOffset > 0 ? inset + _replyPanOffset / 2.0f : self.frame.size.width + _replyPanOffset / 2.0f;
        iconView.center = CGPointMake(x, self.frame.size.height / 2.0f);
        [container addSubview:iconView];
        _replyIconModel = nil;
        
        [UIView animateWithDuration:0.2 delay:0.0 options:(iosMajorVersion() >= 7 ? (7 << 16) : 0) | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            CGFloat x = _replyPanOffset > 0 ? inset : self.frame.size.width;
            _replyPanOffset = 0.0f;
            
            if (self.frame.size.width > FLT_EPSILON)
                [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
            
            iconView.center = CGPointMake(x, self.frame.size.height / 2.0f);
            iconView.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
            iconView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            if (iconView != nil)
            {
                [iconView removeFromSuperview];
                iconView.transform = CGAffineTransformIdentity;
                iconView.alpha = 1.0f;
                [viewStorage enqueueView:iconView];
            }
        }];
    }
}

- (void)setExplicitReplyPanOffset:(CGFloat)replyPanOffset ended:(bool)ended
{
    _replyPanOffset = replyPanOffset;
    if (!ended)
    {
        [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
    }
    else
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:(iosMajorVersion() >= 7 ? (7 << 16) : 0) | UIViewAnimationOptionBeginFromCurrentState animations:^
         {
             _replyPanOffset = 0.0f;
             
             if (self.frame.size.width > FLT_EPSILON)
                 [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
         } completion:nil];
    }
}

- (void)replyPanGesture:(UIPanGestureRecognizer *)recognizer
{
    CGFloat inset = _avatarModel != nil ? 0.0f : 0.0f;
    const CGFloat activationOffset = 45.0f;
    bool ended = false;
    if (recognizer.state == UIGestureRecognizerStateChanged)
    {
        CGFloat translation = [recognizer translationInView:recognizer.view.superview].x * -1.0f;
        _replyPanOffset = MAX(TGIsRTL() ? 0.0f : -80.0f, MIN(TGIsRTL() ? 80.0f : 0.0f, _replyPanOffset + translation));
        [recognizer setTranslation:CGPointZero inView:recognizer.view.superview];
        
        if (fabs(_replyPanOffset) >= activationOffset)
        {
            if (_replyIconModel == nil)
                _context.replySwipeInteraction(_mid, false);
            
            if (_replyIconModel.alpha < FLT_EPSILON)
            {
                [_feedbackGenerator impactOccurred];
                
                void (^animationBlock)(void) = ^
                {
                    [_replyIconModel boundView].transform = CGAffineTransformIdentity;
                    _replyIconModel.alpha = 1.0f;
                };
                
                if (iosMajorVersion() >= 7)
                {
                    [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.4 initialSpringVelocity:0.2 options:kNilOptions animations:animationBlock completion:nil];
                }
                else
                {
                    [UIView animateWithDuration:0.2 animations:animationBlock];
                }
            }
        }
        else
        {
            if (_replyIconModel == nil)
                [_feedbackGenerator prepare];
            
            _replyIconModel.alpha = (float)fabs(_replyPanOffset / activationOffset);
        }
        
        CGFloat x = _replyPanOffset > 0 ? inset + _replyPanOffset / 2.0f : self.frame.size.width + _replyPanOffset / 2.0f;
        [_replyIconModel boundView].center = CGPointMake(x, self.frame.size.height / 2.0f);
        
        [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
    }
    else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled)
    {
        if (recognizer.state == UIGestureRecognizerStateEnded && fabs(_replyPanOffset) > activationOffset)
            [_context.companionHandle requestAction:@"replyRequested" options:@{@"mid": @(_mid), @"interactive": @true}];
        
        _context.replySwipeInteraction(_mid, true);
        ended = true;
    }
    
    if (_positionFlags != TGMessageGroupPositionNone)
        _context.replySwipeGrouped(_mid, _groupedId, _replyPanOffset, ended);
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _replyPanGestureRecognizer)
    {
        if (_editing)
            return false;
            
        UIPanGestureRecognizer *panGestureRecognizer = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [panGestureRecognizer velocityInView:gestureRecognizer.view];
        if (fabs(velocity.y) > fabs(velocity.x) || ((TGIsRTL() && velocity.x < FLT_EPSILON) || (!TGIsRTL() && velocity.x > FLT_EPSILON)))
            return false;
        
        return _context.canReplyToMessageId(_mid);
    }
    return true;
}

- (void)checkButtonPressed
{
    if (_checkButtonModel != nil)
    {
        _checkButtonModel.isChecked = !_checkButtonModel.isChecked;
        [_context.companionHandle requestAction:@"messageSelectionChanged" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId), @"selected": @(_checkButtonModel.isChecked)}];
    }
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    CGFloat contentHeight = self.frame.size.height;

    bool brandedCommentsFooter = _ios6CommentsEnabled && [self _ios6UsesBrandedCommentsFooter];
    _ios6CommentsFooterModel.hidden = !brandedCommentsFooter;
    if (brandedCommentsFooter)
    {
        _ios6CommentsButtonModel.hidden = true;
        CGRect bubbleFrame = [self discussionCommentsBubbleFrame];
        UIEdgeInsets bubbleInsets = [TGPresentation brandedIOS6BubbleImageInsetsOutgoing:!_incomingAppearance];
        CGFloat footerHeight = [self discussionCommentsFooterHeight];
        _ios6CommentsFooterModel.frame = CGRectMake(bubbleFrame.origin.x + bubbleInsets.left, CGRectGetMaxY(bubbleFrame) - bubbleInsets.bottom - footerHeight, MAX(1.0f, bubbleFrame.size.width - bubbleInsets.left - bubbleInsets.right), footerHeight);
    }
    else if (_ios6CommentsEnabled && _ios6CommentsButtonModel != nil)
    {
        _ios6CommentsButtonModel.hidden = false;
        if ([self discussionCommentsFooterIntegratedInBubble])
        {
            CGRect bubbleFrame = [self discussionCommentsBubbleFrame];
            CGFloat footerHeight = [self discussionCommentsFooterHeight];
            if (bubbleFrame.size.width > FLT_EPSILON && bubbleFrame.size.height >= footerHeight)
            {
                _ios6CommentsButtonModel.frame = CGRectMake(CGFloor(bubbleFrame.origin.x + 1.0f),
                                                             CGFloor(CGRectGetMaxY(bubbleFrame) - footerHeight),
                                                             CGFloor(MAX(1.0f, bubbleFrame.size.width - 2.0f)),
                                                             footerHeight);
            }
        }
        else
        {
            CGFloat horizontalInset = 12.0f + (_editing ? 42.0f : 0.0f);
            CGFloat footerWidth = MIN(260.0f, MAX(140.0f, containerSize.width - horizontalInset - 12.0f));
            CGFloat footerX = _incomingAppearance ? horizontalInset : MAX(horizontalInset, containerSize.width - footerWidth - 12.0f);
            footerX += _replyPanOffset;
            _ios6CommentsButtonModel.frame = CGRectMake(CGFloor(footerX), CGFloor(contentHeight + 2.0f), CGFloor(footerWidth), 30.0f);
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, contentHeight + 36.0f);
            contentHeight = self.frame.size.height;
        }
    }

    if (_avatarModel != nil)
    {
        _avatarModel.frame = CGRectMake(TGGetMessageViewModelLayoutConstants()->avatarInset + (_editing ? 42.0f : 0.0f) + _replyPanOffset, contentHeight - 38 - _avatarOffset, 38, 38);
        _avatarModel.alpha = (_collapseFlags & TGModernConversationItemCollapseBottom) ? 0.0f : 1.0f;
    }
    
    if (_checkButtonModel != nil && !_editingCheckButtonGrowTransition)
        _checkButtonModel.frame = self.editingCheckButtonFrame;
    
    if (_checkAreaModel != nil && !_editingCheckButtonGrowTransition)
        _checkAreaModel.frame = self.bounds;
}

- (CGRect)editingCheckButtonFrame
{
    return CGRectMake(11.0f, CGFloor((self.frame.size.height - 30.0f) / 2.0f), 30.0f, 30.0f);
}

- (CGRect)editingCheckAreaFrame
{
    return self.bounds;
}

- (bool (^)(CGPoint))pointInside
{
    return nil;
}

@end
