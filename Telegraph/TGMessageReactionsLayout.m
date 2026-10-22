#import "TGMessageReactionsLayout.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGModernViewContext.h"
#import "TGModernViewModel.h"
#import "TGMessageViewModel.h"
#import "TGMessageViewsView.h"
#import "TGRichMessageInlineImageStore.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"

static NSString *const TGMessageReactionCustomPrefix = @"◆";
static NSString *const TGMessageReactionPaid = @"★";

TGMessageReactionsMetrics TGMessageReactionsCurrentMetrics(void)
{
    TGMessageReactionsMetrics metrics;
    if ([TGPresentation brandedIOS6Style])
    {
        OGConversationAppearance *appearance = [TGPresentation brandedIOS6ConversationAppearance];
        metrics.itemSpacing = appearance.reactionsSpacing;
        metrics.lineSpacing = appearance.reactionsSpacing;
        metrics.topSpacing = appearance.reactionsTopSpacing;
        metrics.timeSpacing = appearance.reactionsTimeSpacing;
        metrics.timeRowSpacing = appearance.reactionsSpacing;
        metrics.leadingOffset = 0.0f;
    }
    else
    {
        metrics.itemSpacing = TGMessageFontMetric(4.0f);
        metrics.lineSpacing = TGMessageFontMetric(4.0f);
        metrics.topSpacing = TGMessageFontMetric(3.0f);
        metrics.timeSpacing = TGMessageFontMetric(4.0f);
        metrics.timeRowSpacing = TGMessageFontMetric(1.0f);
        metrics.leadingOffset = -TGMessageFontMetric(1.0f);
    }
    return metrics;
}

@interface TGMessageReactionItem ()

- (instancetype)initWithReaction:(NSString *)reaction count:(NSInteger)count chosen:(bool)chosen;

@end

@implementation TGMessageReactionItem

- (instancetype)initWithReaction:(NSString *)reaction count:(NSInteger)count chosen:(bool)chosen
{
    self = [super init];
    if (self != nil)
    {
        _reaction = [reaction copy];
        _count = count;
        _chosen = chosen;
        _paid = [reaction isEqualToString:TGMessageReactionPaid];
        if ([reaction hasPrefix:TGMessageReactionCustomPrefix] && reaction.length > TGMessageReactionCustomPrefix.length)
            _customEmojiId = [[reaction substringFromIndex:TGMessageReactionCustomPrefix.length] longLongValue];
    }
    return self;
}

+ (NSString *)keyForReaction:(NSString *)reaction
{
    if (reaction.length == 0)
        return nil;
    return [[reaction stringByReplacingOccurrencesOfString:@"️" withString:@""] stringByReplacingOccurrencesOfString:@"︎" withString:@""];
}

+ (NSArray *)itemsWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction
{
    if (summary.length == 0)
        return @[];

    NSString *chosenKey = [self keyForReaction:chosenReaction];
    NSMutableArray *orderedKeys = [[NSMutableArray alloc] init];
    NSMutableDictionary *reactionByKey = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *countByKey = [[NSMutableDictionary alloc] init];
    for (NSString *part in [summary componentsSeparatedByString:@"  "])
    {
        NSRange separator = [part rangeOfString:@" " options:NSBackwardsSearch];
        NSString *reaction = separator.location == NSNotFound ? part : [part substringToIndex:separator.location];
        NSInteger count = separator.location == NSNotFound ? 1 : MAX(1, [[part substringFromIndex:separator.location + 1] integerValue]);
        NSString *key = [self keyForReaction:reaction];
        if (key.length == 0)
            continue;
        NSNumber *existing = countByKey[key];
        if (existing == nil)
        {
            [orderedKeys addObject:key];
            reactionByKey[key] = reaction;
            countByKey[key] = @(count);
        }
        else
            countByKey[key] = @(MAX([existing integerValue], count));
    }

    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:orderedKeys.count];
    for (NSString *key in orderedKeys)
        [items addObject:[[TGMessageReactionItem alloc] initWithReaction:reactionByKey[key] count:[countByKey[key] integerValue] chosen:chosenKey.length != 0 && [chosenKey isEqualToString:key]]];

    NSMutableArray *sorted = [[NSMutableArray alloc] initWithCapacity:items.count];
    NSMutableArray *regular = [[NSMutableArray alloc] initWithCapacity:items.count];
    for (TGMessageReactionItem *item in items)
    {
        if (item.paid)
            [sorted addObject:item];
        else
            [regular addObject:item];
    }
    [regular sortWithOptions:NSSortStable usingComparator:^NSComparisonResult(TGMessageReactionItem *lhs, TGMessageReactionItem *rhs)
    {
        NSInteger lhsCount = lhs.count - (lhs.chosen ? 1 : 0);
        NSInteger rhsCount = rhs.count - (rhs.chosen ? 1 : 0);
        if (lhsCount > rhsCount)
            return NSOrderedAscending;
        if (lhsCount < rhsCount)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    [sorted addObjectsFromArray:regular];
    return sorted;
}

@end

static UIColor *TGMessageReactionColor(uint32_t rgb)
{
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f green:((rgb >> 8) & 0xff) / 255.0f blue:(rgb & 0xff) / 255.0f alpha:1.0f];
}

static UIColor *TGMessageReactionOpaqueColor(UIColor *color)
{
    return [color colorWithAlphaComponent:1.0f];
}

static void TGMessageReactionDrawPaidStar(CGContextRef context, CGRect rect)
{
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect) + rect.size.height * 0.04f);
    CGFloat outerRadius = rect.size.width * 0.5f;
    CGFloat innerRadius = outerRadius * 0.5f;
    CGMutablePathRef path = CGPathCreateMutable();
    for (int index = 0; index < 10; index++)
    {
        CGFloat radius = (index % 2 == 0) ? outerRadius : innerRadius;
        CGFloat angle = (CGFloat)(-M_PI_2 + index * M_PI / 5.0);
        CGPoint point = CGPointMake(center.x + radius * cosf(angle), center.y + radius * sinf(angle));
        if (index == 0)
            CGPathMoveToPoint(path, NULL, point.x, point.y);
        else
            CGPathAddLineToPoint(path, NULL, point.x, point.y);
    }
    CGPathCloseSubpath(path);

    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[8] = { 1.0f, 0.851f, 0.318f, 1.0f, 1.0f, 0.698f, 0.133f, 1.0f };
    CGFloat locations[2] = { 0.0f, 1.0f };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(rect.origin.x, rect.origin.y), CGPointMake(rect.origin.x, CGRectGetMaxY(rect)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(context);
    CGPathRelease(path);
}

static void TGMessageReactionDrawPlaceholder(CGContextRef context, CGRect rect, UIColor *color)
{
    CGFloat diameter = TGRetinaFloor(rect.size.width * 0.5f);
    CGRect dotRect = CGRectMake(rect.origin.x + TGRetinaFloor((rect.size.width - diameter) / 2.0f), rect.origin.y + TGRetinaFloor((rect.size.height - diameter) / 2.0f), diameter, diameter);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, dotRect);
}

static UIImage *TGMessageReactionEmojiImage(TGMessageReactionItem *item, CGFloat size)
{
    if (item.customEmojiId != 0)
        return [TGRichMessageInlineImageStore imageForKey:[TGRichMessageInlineImageStore customEmojiKey:item.customEmojiId]];
    if (item.paid)
        return nil;
    return TGEmojiImageOfSize(item.reaction, size);
}

static UIImage *TGMessageReactionPillImage(TGMessageReactionItem *item, TGMessageReactionsStyle style, TGPresentation *presentation)
{
    bool branded = [TGPresentation brandedIOS6Style];
    CGFloat height = branded ? 22.0f : TGMessageFontMetric(26.0f);
    CGFloat emojiSize = branded ? 16.0f : TGMessageFontMetric(20.0f);
    CGFloat paddingLeft = branded ? 6.0f : TGMessageFontMetric(6.0f);
    CGFloat paddingRight = branded ? 7.0f : TGMessageFontMetric(8.0f);
    CGFloat textSkip = branded ? 3.0f : TGMessageFontMetric(3.0f);
    UIFont *font = TGMediumSystemFontOfSize(branded ? 12.0f : TGMessageFontMetric(13.0f));

    UIImage *emojiImage = TGMessageReactionEmojiImage(item, emojiSize);
    NSString *countText = [TGMessageViewsView stringForCount:(int32_t)MAX(1, item.count)];

    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 192;
    });
    NSString *geometryKey = [NSString stringWithFormat:@"%.2f|%.2f|%.2f|%.2f|%.2f|%.2f", font.pointSize, height, emojiSize, paddingLeft, paddingRight, textSkip];
    NSString *cacheKey = [[NSString alloc] initWithFormat:@"%@|%@|%d|%d|%d|%@|%p|%d", item.reaction, countText, item.chosen ? 1 : 0, (int)style, branded ? 1 : 0, geometryKey, presentation, emojiImage != nil ? 1 : 0];
    UIImage *cached = [cache objectForKey:cacheKey];
    if (cached != nil)
        return cached;

    UIColor *background = nil;
    UIColor *foreground = nil;
    UIColor *placeholder = nil;
    if (style == TGMessageReactionsStyleService)
    {
        background = item.chosen ? presentation.pallete.chatSystemTextColor : presentation.pallete.chatSystemBackgroundColor;
        foreground = item.chosen ? TGMessageReactionOpaqueColor(presentation.pallete.chatSystemBackgroundColor) : presentation.pallete.chatSystemTextColor;
        placeholder = [foreground colorWithAlphaComponent:0.5f];
    }
    else
    {
        bool outgoing = style == TGMessageReactionsStyleOutgoing;
        UIColor *accent = item.paid ? TGMessageReactionColor(0xf0b400) : (outgoing ? presentation.pallete.chatOutgoingAccentColor : presentation.pallete.chatIncomingAccentColor);
        UIColor *bubble = outgoing ? presentation.pallete.chatOutgoingBubbleColor : presentation.pallete.chatIncomingBubbleColor;
        if (item.chosen)
        {
            background = TGMessageReactionOpaqueColor(accent);
            foreground = TGMessageReactionOpaqueColor(bubble);
            placeholder = [foreground colorWithAlphaComponent:0.6f];
        }
        else
        {
            background = [TGMessageReactionOpaqueColor(accent) colorWithAlphaComponent:outgoing ? 0.18f : 0.12f];
            foreground = item.paid ? TGMessageReactionColor(0xba7000) : TGMessageReactionOpaqueColor(accent);
            placeholder = outgoing ? presentation.pallete.chatOutgoingSubtextColor : presentation.pallete.chatIncomingSubtextColor;
        }
    }

    CGSize textSize = [countText sizeWithFont:font];
    CGFloat textWidth = CGCeil(textSize.width);
    CGSize size = CGSizeMake(CGCeil(paddingLeft + emojiSize + textSkip + textWidth + paddingRight), height);

    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, background.CGColor);
    CGContextAddPath(context, [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0f, 0.0f, size.width, size.height) cornerRadius:size.height / 2.0f].CGPath);
    CGContextFillPath(context);

    CGRect emojiRect = CGRectMake(paddingLeft, TGRetinaFloor((height - emojiSize) / 2.0f), emojiSize, emojiSize);
    if (item.paid)
        TGMessageReactionDrawPaidStar(context, CGRectInset(emojiRect, emojiSize * 0.06f, emojiSize * 0.06f));
    else if (emojiImage != nil)
        [emojiImage drawInRect:emojiRect];
    else
        TGMessageReactionDrawPlaceholder(context, emojiRect, placeholder);

    CGContextSetFillColorWithColor(context, foreground.CGColor);
    [countText drawAtPoint:CGPointMake(CGRectGetMaxX(emojiRect) + textSkip, TGRetinaFloor((height + font.capHeight) / 2.0f - font.ascender)) withFont:font];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (image != nil)
        [cache setObject:image forKey:cacheKey];
    return image;
}

@interface TGMessageReactionButtonModel ()
{
    TGMessageReactionsStyle _style;
    TGPresentation *_reactionPresentation;
    NSString *_pendingImageKey;
    CGFloat _imageScale;
}

- (void)refreshMetrics;

@end

@implementation TGMessageReactionButtonModel

- (instancetype)initWithItem:(TGMessageReactionItem *)item style:(TGMessageReactionsStyle)style presentation:(TGPresentation *)presentation pressed:(void (^)(TGMessageReactionItem *))pressed
{
    self = [super init];
    if (self != nil)
    {
        _item = item;
        _style = style;
        _reactionPresentation = presentation;
        self.modernHighlight = true;
        self.extendedEdgeInsets = UIEdgeInsetsMake(2.0f, 1.0f, 2.0f, 1.0f);
        if (pressed != nil && !item.paid)
        {
            void (^pressedBlock)(TGMessageReactionItem *) = [pressed copy];
            self.pressed = ^
            {
                pressedBlock(item);
            };
        }
        [self updateImage];

        if (item.customEmojiId != 0 && [TGRichMessageInlineImageStore imageForKey:[TGRichMessageInlineImageStore customEmojiKey:item.customEmojiId]] == nil)
        {
            int64_t documentId = item.customEmojiId;
            _pendingImageKey = [TGRichMessageInlineImageStore customEmojiKey:documentId];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inlineImageLoaded:) name:TGRichMessageInlineImageLoadedNotification object:nil];
            [TGRichMessageInlineImageStore requestImageForKey:_pendingImageKey signalGenerator:^SSignal *
            {
                return [TGRichMessageInlineImageStore customEmojiImageSignal:documentId];
            }];
        }
    }
    return self;
}

- (void)dealloc
{
    if (_pendingImageKey != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:self name:TGRichMessageInlineImageLoadedNotification object:nil];
}

- (void)updateImage
{
    _imageScale = TGMessageFontScale();
    UIImage *image = TGMessageReactionPillImage(_item, _style, _reactionPresentation);
    self.image = image;
    self.frame = (CGRect){self.frame.origin, image.size};
}

- (void)refreshMetrics
{
    if (fabs(_imageScale - TGMessageFontScale()) > FLT_EPSILON)
        [self updateImage];
}

- (void)inlineImageLoaded:(NSNotification *)notification
{
    if (_pendingImageKey == nil || ![notification.userInfo[@"key"] isEqualToString:_pendingImageKey])
        return;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGRichMessageInlineImageLoadedNotification object:nil];
    _pendingImageKey = nil;
    [self updateImage];
}

@end

@interface TGMessageReactionsLayout ()
{
    NSArray *_frames;
}

@end

@interface TGMessageReactionsModel ()
{
    TGModernViewContext *_context;
    TGMessageReactionsStyle _style;
    NSString *_summary;
    NSString *_chosenReaction;
}

@end

@implementation TGMessageReactionsModel

+ (NSString *)summaryForMessage:(TGMessage *)message
{
    id value = message.contentProperties[@"ios6ReactionSummary"];
    if ([value isKindOfClass:[TGMessageReactionSummaryContentProperty class]])
        return ((TGMessageReactionSummaryContentProperty *)value).summary;
    if ([value isKindOfClass:[NSString class]])
        return value;
    return nil;
}

+ (NSString *)chosenReactionForMessage:(TGMessage *)message
{
    id value = message.contentProperties[@"ios6ReactionSummary"];
    if ([value isKindOfClass:[TGMessageReactionSummaryContentProperty class]])
        return ((TGMessageReactionSummaryContentProperty *)value).chosenReaction;
    return nil;
}

- (instancetype)initWithContext:(TGModernViewContext *)context style:(TGMessageReactionsStyle)style
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _style = style;
        _buttons = @[];
    }
    return self;
}

- (bool)updateWithMessage:(TGMessage *)message parent:(TGModernViewModel *)parent viewStorage:(TGModernViewStorage *)viewStorage container:(UIView *)container
{
    _messageId = message.mid;
    return [self updateWithSummary:[TGMessageReactionsModel summaryForMessage:message] chosenReaction:[TGMessageReactionsModel chosenReactionForMessage:message] parent:parent viewStorage:viewStorage container:container];
}

- (bool)updateWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction parent:(TGModernViewModel *)parent viewStorage:(TGModernViewStorage *)viewStorage container:(UIView *)container
{
    if (TGStringCompare(_summary, summary) && TGStringCompare(_chosenReaction, chosenReaction))
        return false;

    _summary = [summary copy];
    _chosenReaction = [chosenReaction copy];

    for (TGMessageReactionButtonModel *button in _buttons)
    {
        if ([parent containsSubmodel:button])
            [parent removeSubmodel:button viewStorage:viewStorage];
    }

    __weak TGMessageReactionsModel *weakSelf = self;
    void (^pressed)(TGMessageReactionItem *) = ^(TGMessageReactionItem *item)
    {
        __strong TGMessageReactionsModel *strongSelf = weakSelf;
        if (strongSelf == nil || item.reaction.length == 0)
            return;
        [strongSelf->_context.companionHandle requestAction:@"ios6ReactionTapped" options:@{ @"mid": @(strongSelf->_messageId), @"reaction": item.reaction, @"remove": @(item.chosen) }];
    };

    NSMutableArray *buttons = [[NSMutableArray alloc] init];
    for (TGMessageReactionItem *item in [TGMessageReactionItem itemsWithSummary:_summary chosenReaction:_chosenReaction])
    {
        if (!item.paid && item.customEmojiId == 0 && [item.reaction hasPrefix:TGMessageReactionCustomPrefix])
            continue;
        TGMessageReactionButtonModel *button = [[TGMessageReactionButtonModel alloc] initWithItem:item style:_style presentation:_context.presentation pressed:pressed];
        [parent addSubmodel:button];
        [buttons addObject:button];
    }
    _buttons = buttons;

    if (container != nil)
    {
        for (TGMessageReactionButtonModel *button in _buttons)
        {
            if ([button boundView] == nil)
                [button bindViewToContainer:container viewStorage:viewStorage];
        }
        [self bringToFrontInContainer:container];
    }
    return true;
}

- (void)bringToFrontInContainer:(UIView *)container
{
    for (TGMessageReactionButtonModel *button in _buttons)
    {
        UIView *view = [button boundView];
        if (view != nil && view.superview == container)
            [container bringSubviewToFront:view];
    }
}

- (void)moveToFrontInParent:(TGModernViewModel *)parent viewStorage:(TGModernViewStorage *)viewStorage container:(UIView *)container
{
    for (TGMessageReactionButtonModel *button in _buttons)
    {
        if ([parent containsSubmodel:button])
            [parent removeSubmodel:button viewStorage:viewStorage];
        [parent addSubmodel:button];
        if (container != nil && [button boundView] == nil)
            [button bindViewToContainer:container viewStorage:viewStorage];
    }
    if (container != nil)
        [self bringToFrontInContainer:container];
}

- (TGMessageReactionsLayout *)layoutWithMaximumWidth:(CGFloat)maximumWidth trailingWidth:(CGFloat)trailingWidth trailingHeight:(CGFloat)trailingHeight
{
    if (_buttons.count == 0)
        return nil;
    TGMessageReactionsMetrics metrics = TGMessageReactionsCurrentMetrics();
    NSMutableArray *sizes = [[NSMutableArray alloc] initWithCapacity:_buttons.count];
    for (TGMessageReactionButtonModel *button in _buttons)
    {
        [button refreshMetrics];
        [sizes addObject:[NSValue valueWithCGSize:button.frame.size]];
    }
    return [TGMessageReactionsLayout layoutWithItemSizes:sizes maximumWidth:maximumWidth - metrics.leadingOffset trailingWidth:trailingWidth trailingHeight:trailingHeight itemSpacing:metrics.itemSpacing lineSpacing:metrics.lineSpacing trailingSpacing:metrics.timeSpacing trailingLineSpacing:metrics.timeRowSpacing];
}

- (void)applyLayout:(TGMessageReactionsLayout *)layout origin:(CGPoint)origin
{
    CGFloat leadingOffset = TGMessageReactionsCurrentMetrics().leadingOffset;
    NSUInteger index = 0;
    for (TGMessageReactionButtonModel *button in _buttons)
    {
        button.hidden = layout == nil;
        if (layout != nil)
            button.frame = CGRectOffset([layout frameForItemAtIndex:index], origin.x + leadingOffset, origin.y);
        index++;
    }
}

@end

@implementation TGMessageReactionsLayout

+ (instancetype)layoutWithItemSizes:(NSArray *)itemSizes maximumWidth:(CGFloat)maximumWidth trailingWidth:(CGFloat)trailingWidth trailingHeight:(CGFloat)trailingHeight itemSpacing:(CGFloat)itemSpacing lineSpacing:(CGFloat)lineSpacing trailingSpacing:(CGFloat)trailingSpacing trailingLineSpacing:(CGFloat)trailingLineSpacing
{
    if (itemSizes.count == 0)
        return nil;

    CGFloat availableWidth = MAX(1.0f, maximumWidth);
    bool hasTrailing = trailingWidth > FLT_EPSILON;

    NSMutableArray *lines = [[NSMutableArray alloc] init];
    NSMutableArray *lineWidths = [[NSMutableArray alloc] init];
    NSMutableArray *currentLine = nil;
    CGFloat currentWidth = 0.0f;
    for (NSUInteger index = 0; index < itemSizes.count; index++)
    {
        CGFloat itemWidth = MIN([itemSizes[index] CGSizeValue].width, availableWidth);
        if (currentLine == nil || currentWidth + itemSpacing + itemWidth > availableWidth)
        {
            if (currentLine != nil)
            {
                [lines addObject:currentLine];
                [lineWidths addObject:@(currentWidth)];
            }
            currentLine = [[NSMutableArray alloc] init];
            currentWidth = 0.0f;
        }
        currentWidth += (currentLine.count != 0 ? itemSpacing : 0.0f) + itemWidth;
        [currentLine addObject:@(index)];
    }
    [lines addObject:currentLine];
    [lineWidths addObject:@(currentWidth)];

    CGFloat lastLineWidth = [[lineWidths lastObject] floatValue];
    bool trailingOnLastLine = !hasTrailing || lastLineWidth + trailingSpacing + trailingWidth <= availableWidth;

    NSMutableArray *frames = [[NSMutableArray alloc] initWithCapacity:itemSizes.count];
    for (NSUInteger index = 0; index < itemSizes.count; index++)
        [frames addObject:[NSValue valueWithCGRect:CGRectZero]];

    CGFloat y = 0.0f;
    CGFloat width = 0.0f;
    CGRect trailingFrame = CGRectZero;
    for (NSUInteger lineIndex = 0; lineIndex < lines.count; lineIndex++)
    {
        NSArray *line = lines[lineIndex];
        bool isLastLine = lineIndex == lines.count - 1;
        CGFloat lineHeight = 0.0f;
        for (NSNumber *itemIndex in line)
            lineHeight = MAX(lineHeight, [itemSizes[[itemIndex unsignedIntegerValue]] CGSizeValue].height);
        if (isLastLine && trailingOnLastLine && hasTrailing)
            lineHeight = MAX(lineHeight, trailingHeight);

        CGFloat x = 0.0f;
        for (NSNumber *itemIndex in line)
        {
            CGSize itemSize = [itemSizes[[itemIndex unsignedIntegerValue]] CGSizeValue];
            itemSize.width = MIN(itemSize.width, availableWidth);
            frames[[itemIndex unsignedIntegerValue]] = [NSValue valueWithCGRect:CGRectMake(x, y + floorf((lineHeight - itemSize.height) / 2.0f), itemSize.width, itemSize.height)];
            x += itemSize.width + itemSpacing;
        }

        CGFloat lineWidth = [lineWidths[lineIndex] floatValue];
        if (isLastLine && trailingOnLastLine && hasTrailing)
        {
            trailingFrame = CGRectMake(availableWidth - trailingWidth, y + lineHeight - trailingHeight, trailingWidth, trailingHeight);
            lineWidth += trailingSpacing + trailingWidth;
        }
        width = MAX(width, lineWidth);

        y += lineHeight;
        if (!isLastLine)
            y += lineSpacing;
    }

    if (!trailingOnLastLine)
    {
        trailingFrame = CGRectMake(MAX(0.0f, availableWidth - trailingWidth), y + trailingLineSpacing, trailingWidth, trailingHeight);
        y += trailingLineSpacing + trailingHeight;
        width = MAX(width, trailingWidth);
    }

    TGMessageReactionsLayout *layout = [[TGMessageReactionsLayout alloc] init];
    layout->_frames = frames;
    layout->_trailingFrame = trailingFrame;
    layout->_size = CGSizeMake(ceilf(width), ceilf(y));
    return layout;
}

- (CGRect)frameForItemAtIndex:(NSUInteger)index
{
    if (index >= _frames.count)
        return CGRectZero;
    return [_frames[index] CGRectValue];
}

@end
