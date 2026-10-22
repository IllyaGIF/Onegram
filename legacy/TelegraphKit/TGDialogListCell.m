#import "TGDialogListCell.h"
#import "TGCommon.h"
#import "OGPlatformText.h"
#import "OGPlatformGraphics.h"
#import "../../OnegramPlatform/OGMemoryCache.h"
#import "../../OnegramPlatform/OGPlatformDispatch.h"

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGReusableLabel.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGDateLabel.h"

#import "../../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"
#import "../../submodules/LegacyComponents/LegacyComponents/TGFont.h"

#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGTelegramNetworking.h"

#import "TGDialogListCellEditingControls.h"

#import "TGCurrencyFormatter.h"

#import "TGPresentation.h"
#import "TGPollMediaAttachment.h"
#import "../../OnegramUI/Core/OGDialogListAppearance.h"
#import "../../OnegramUI/Lists/OGDialogLayout.h"
#import "TGPresentationAssets.h"
#import "TGCommunityAppearance.h"
#import "TGCommunitySignals.h"

#import "TGSimpleImageView.h"

#include <math.h>

static bool TGDialogListClassicIOS6Style(void)
{
    return [TGPresentation classicIOS6Style];
}

static bool TGDialogListBrandedIOS6Style(void)
{
    return [TGPresentation brandedIOS6Style];
}

static CGFloat TGDialogListBrandedMentionWidth(TGPresentation *presentation)
{
    UIEdgeInsets outsets = [TGPresentation brandedIOS6DialogMentionImageOutsets];
    return MAX(0.0f, presentation.images.dialogBrandedMentionIcon.size.width - outsets.left - outsets.right);
}

static NSString *TGDialogListStartupLocalized(NSString *key)
{
    return OGPlatformUsesConstrainedBackgroundExecution() ? TGStartupLocalized(key) : TGLocalized(key);
}

static const CGFloat TGDialogListBrandedIOS6TitleFontSize = 15.6f;
static const CGFloat TGDialogListBrandedIOS6BodyFontSize = 12.0f;
static const CGFloat TGDialogListBrandedIOS6BadgeScale = 0.97f;
static const CGFloat TGDialogListBrandedIOS6BadgeSpacing = 6.0f;
static const CGFloat TGDialogListBrandedIOS6AccessoryCenterInset = 20.0f;

static CGFloat TGDialogListAvatarSize(void)
{
    if (TGDialogListBrandedIOS6Style())
        return 50.0f;
    return TGDialogListClassicIOS6Style() ? 52.0f : 62.0f;
}

static CGFloat TGDialogListAvatarInset(void)
{
    return TGDialogListBrandedIOS6Style() ? 6.0f : (TGDialogListClassicIOS6Style() ? 12.0f : 10.0f);
}

static CGFloat TGDialogListContentOffset(void)
{
    if (TGDialogListBrandedIOS6Style())
        return 61.0f;
    return TGDialogListClassicIOS6Style() ? 72.0f : 80.0f;
}

static UIColor *TGDialogListMessageTextColor(UIColor *defaultColor, bool unread)
{
    if (!TGDialogListBrandedIOS6Style())
        return defaultColor;
    OGDialogListAppearance *appearance = [TGPresentation brandedIOS6DialogListAppearance];
    return unread ? appearance.messageUnreadColor : appearance.messageColor;
}

static bool TGDialogListObjectsEqual(id lhs, id rhs)
{
    return lhs == rhs || [lhs isEqual:rhs];
}

static NSString *TGDialogListVisiblePreviewText(NSString *text)
{
    static const NSUInteger maximumLength = 160;
    if (!OGPlatformUsesConstrainedBackgroundExecution() || text.length <= maximumLength)
        return text;

    NSRange range = [text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, maximumLength)];
    return [[text substringWithRange:range] stringByAppendingString:@"…"];
}

static CGFloat TGDialogListTitleBaselineOffset(UIFont *font)
{
    if (iosMajorVersion() <= 3)
        return font.ascender;

    CTFontRef coreTextFont = TGCoreTextFontForUIFont(font);
    if (coreTextFont == NULL)
        return CGFloor(font.ascender - font.descender);
    CGFloat offset = TGReusableLabelFirstBaselineOffset(coreTextFont);
    CFRelease(coreTextFont);
    return offset;
}

static CGFloat TGDialogListTitleCapCenterOffset(UIFont *font)
{
    return TGDialogListTitleBaselineOffset(font) - OGPlatformFontCapHeight(font) / 2.0f;
}

static CGFloat TGDialogListPixelRound(CGFloat value)
{
    return TGScreenPixelFloor(value + TGScreenPixel / 2.0f);
}

static CGFloat TGDialogListCenteredOrigin(CGFloat center, CGFloat length)
{
    return TGDialogListPixelRound(center - length / 2.0f);
}

@interface TGDialogListTextLayoutKey : NSObject <NSCopying>
{
    NSString *_text;
    UIFont *_font;
    NSInteger _width;
    NSUInteger _maxLines;
    NSTextAlignment _alignment;
    TGEmojiRenderMode _emojiMode;
}
- (instancetype)initWithText:(NSString *)text font:(UIFont *)font width:(CGFloat)width maxLines:(NSUInteger)maxLines alignment:(NSTextAlignment)alignment;
@end

@implementation TGDialogListTextLayoutKey

- (instancetype)initWithText:(NSString *)text font:(UIFont *)font width:(CGFloat)width maxLines:(NSUInteger)maxLines alignment:(NSTextAlignment)alignment
{
    self = [super init];
    if (self != nil)
    {
        _text = [text copy];
        _font = font;
        _width = (NSInteger)llround(MAX(0.0, width) * [UIScreen mainScreen].scale);
        _maxLines = maxLines;
        _alignment = alignment;
        _emojiMode = TGCurrentEmojiRenderMode();
    }
    return self;
}

- (NSUInteger)hash
{
    return _text.hash ^ (_font.hash << 3) ^ ((NSUInteger)_width << 7) ^ (_maxLines << 19) ^ ((NSUInteger)_alignment << 27) ^ ((NSUInteger)_emojiMode << 29);
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[TGDialogListTextLayoutKey class]])
        return NO;
    TGDialogListTextLayoutKey *other = object;
    return _width == other->_width && _maxLines == other->_maxLines && _alignment == other->_alignment && _emojiMode == other->_emojiMode && [_font isEqual:other->_font] && [_text isEqualToString:other->_text];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

static NSUInteger TGDialogListTextCacheLimit(void)
{
    switch (devicePerformanceClass())
    {
        case TGPerformanceClassConstrained: return 512;
        case TGPerformanceClassBalanced: return 1024;
        case TGPerformanceClassFast: return 2048;
        case TGPerformanceClassHigh: return 4096;
    }
    return 512;
}

static OGMemoryCache *TGDialogListSharedTextLayoutCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSUInteger count = TGDialogListTextCacheLimit();
        cache = [[OGMemoryCache alloc] initWithCountLimit:count costLimit:count * 4096];
    });
    return cache;
}

static TGReusableLabelLayoutData *TGDialogListTextLayout(NSString *text, UIFont *font, CGFloat width, NSUInteger maxLines, NSTextAlignment alignment)
{
    if (text.length == 0 || font == nil || width <= 0.0f)
        return nil;

    text = [text copy];
    TGDialogListTextLayoutKey *cacheKey = [[TGDialogListTextLayoutKey alloc] initWithText:text font:font width:width maxLines:maxLines alignment:alignment];
    OGMemoryCache *cache = TGDialogListSharedTextLayoutCache();
    TGReusableLabelLayoutData *layout = [cache objectForKey:cacheKey];
    if (layout != nil)
        return layout;

    CTFontRef coreTextFont = TGCoreTextFontForUIFont(font);
    if (coreTextFont == NULL)
        return nil;

    layout = [TGReusableLabel calculateLayout:text additionalAttributes:nil textCheckingResults:nil font:coreTextFont textColor:nil linkColor:nil frame:CGRectZero orMaxWidth:width flags:TGReusableLabelLayoutMultiline | TGReusableLabelLayoutForegroundFromContext | TGReusableLabelLayoutBoundedTail textAlignment:alignment outIsRTL:NULL additionalTrailingWidth:0.0f maxNumberOfLines:maxLines numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
    CFRelease(coreTextFont);
    if (layout != nil)
        [cache setObject:layout forKey:cacheKey cost:1024 + text.length * sizeof(unichar) + maxLines * 256];
    return layout;
}

static CGSize TGDialogListTextSize(NSString *text, UIFont *font, CGFloat width, NSUInteger maxLines)
{
    TGReusableLabelLayoutData *layout = TGDialogListTextLayout(text, font, width, maxLines, NSTextAlignmentLeft);
    if (layout == nil)
        return CGSizeZero;

    CGSize size = layout.size;
    size.width = MIN(width, CGCeil(layout.drawingWidth));
    return size;
}

@interface TGDialogListTextMetricKey : NSObject <NSCopying>
{
@public
    NSString *text;
    UIFont *font;
    int32_t widthKey;
    int32_t maxLines;
    int32_t mode;
}
@end

@implementation TGDialogListTextMetricKey

- (NSUInteger)hash
{
    return text.hash ^ (font.hash << 3) ^ ((NSUInteger)(uint32_t)widthKey << 7) ^ ((NSUInteger)(uint32_t)maxLines << 19) ^ ((NSUInteger)(uint32_t)mode << 27);
}

- (id)copyWithZone:(NSZone *)zone
{
    TGDialogListTextMetricKey *copy = [[[self class] allocWithZone:zone] init];
    copy->text = text;
    copy->font = font;
    copy->widthKey = widthKey;
    copy->maxLines = maxLines;
    copy->mode = mode;
    return copy;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[TGDialogListTextMetricKey class]])
        return NO;
    TGDialogListTextMetricKey *other = object;
    return [font isEqual:other->font] && widthKey == other->widthKey && maxLines == other->maxLines && mode == other->mode && [text isEqualToString:other->text];
}

@end

@interface TGDialogListTextMetricValue : NSObject
{
@public
    CGSize size;
}
@end

@implementation TGDialogListTextMetricValue
@end

static OGMemoryCache *TGDialogListSharedTextMetricCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSUInteger count = TGDialogListTextCacheLimit();
        cache = [[OGMemoryCache alloc] initWithCountLimit:count costLimit:count * 512];
    });
    return cache;
}

static CGSize TGDialogListCoreTextSingleLineSize(NSString *text, UIFont *font)
{
    if (text.length == 0 || font == nil)
        return CGSizeZero;

    CTFontRef coreTextFont = TGCoreTextFontForUIFont(font);
    if (coreTextFont == NULL)
        return CGSizeZero;

    NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:(__bridge id)coreTextFont, (__bridge NSString *)kCTFontAttributeName, nil];
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    CTLineRef line = OGPlatformTextCreateLine((__bridge CFAttributedStringRef)attributedString);
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    double lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CFRelease(line);
    CFRelease(coreTextFont);

    return CGSizeMake(CGCeil((CGFloat)lineWidth), CGCeil(MAX(OGPlatformFontLineHeight(font), ascent + descent + leading)));
}

static CGSize TGDialogListCachedTextMetric(NSString *text, UIFont *font, CGFloat width, NSUInteger maxLines, int mode)
{
    if (text.length == 0 || font == nil)
        return CGSizeZero;

    TGDialogListTextMetricKey *key = [[TGDialogListTextMetricKey alloc] init];
    key->text = [text copy];
    key->font = font;
    key->widthKey = mode == 0 ? 0 : (int32_t)lrintf(MAX(0.0f, width) * 16.0f);
    key->maxLines = (int32_t)maxLines;
    key->mode = mode;

    OGMemoryCache *cache = TGDialogListSharedTextMetricCache();
    TGDialogListTextMetricValue *cachedValue = [cache objectForKey:key];
    if (cachedValue != nil)
        return cachedValue->size;

    CGSize result = CGSizeZero;
    if (mode == 1 || mode == 2)
        result = TGDialogListTextSize(text, font, width, maxLines);
    else
        result = TGDialogListCoreTextSingleLineSize(text, font);

    TGDialogListTextMetricValue *value = [[TGDialogListTextMetricValue alloc] init];
    value->size = result;
    [cache setObject:value forKey:key cost:128 + text.length * sizeof(unichar)];

    return result;
}

static const CGFloat TGDialogListUnboundedTextWidth = 4096.0f;

static CGFloat TGDialogListRenderedSingleLineWidth(NSString *text, UIFont *font)
{
    if (text.length == 0 || font == nil)
        return 0.0f;
    return CGCeil(TGDialogListCachedTextMetric(text, font, TGDialogListUnboundedTextWidth, 1, 1).width);
}

static CGFloat TGDialogListBrandedPreviewRightPadding(UIFont *font)
{
    if (font == nil)
        return 22.0f;

    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 8;
    });

    NSNumber *cached = [cache objectForKey:font];
    if (cached != nil)
        return [cached doubleValue];

    CGFloat padding = 22.0f + CGCeil(TGDialogListCachedTextMetric(@"ооооо", font, 0.0f, 1, 0).width);
    [cache setObject:[NSNumber numberWithDouble:padding] forKey:font];
    return padding;
}

static void TGDialogListDrawLayout(TGReusableLabelLayoutData *layout, CGRect rect)
{
    if (layout != nil)
    {
        [TGReusableLabel drawRichTextInRect:rect precalculatedLayout:layout linesRange:NSMakeRange(0, 0) shadowColor:nil shadowOffset:CGSizeZero];
    }
}

static bool TGDialogListRequiresPackEmoji(NSString *text)
{
    NSUInteger length = text.length;
    NSUInteger index = 0;
    while (index < length)
    {
        NSRange emojiRange = NSMakeRange(0, 0);
        if (TGEmojiPackMatchAtIndex(text, index, &emojiRange))
        {
            NSString *emoji = [text substringWithRange:emojiRange];
            if (TGEmojiNeedsPack(emoji))
                return true;
            index = NSMaxRange(emojiRange);
        }
        else
        {
            unichar value = [text characterAtIndex:index];
            if (value >= 0xd800 && value <= 0xdbff && index + 1 < length)
            {
                unichar low = [text characterAtIndex:index + 1];
                if (low >= 0xdc00 && low <= 0xdfff)
                {
                    index += 2;
                    continue;
                }
            }
            index++;
        }
    }
    return false;
}

static bool TGDialogListUseLegacyNativeText(NSString *text)
{
    return iosMajorVersion() <= 3 && text.length != 0 && !TGDialogListRequiresPackEmoji(text);
}

@interface TGDialogListLegacyTextRun : NSObject
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSString *emoji;
@property (nonatomic) CGFloat originX;
@property (nonatomic) CGFloat width;
@end

@implementation TGDialogListLegacyTextRun
@end

@interface TGDialogListLegacyTextLine : NSObject
@property (nonatomic, strong) NSMutableArray *runs;
@property (nonatomic) CGFloat width;
@end

@implementation TGDialogListLegacyTextLine

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _runs = [[NSMutableArray alloc] init];
    return self;
}

@end

@interface TGDialogListLegacyTextLayout : NSObject
@property (nonatomic, strong) NSArray *lines;
@property (nonatomic) CGFloat lineHeight;
@property (nonatomic) CGFloat emojiSize;
@end

@implementation TGDialogListLegacyTextLayout
@end

static OGMemoryCache *TGDialogListSharedLegacyTextLayoutCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:384 costLimit:1536 * 1024];
    });
    return cache;
}

static NSString *TGDialogListLegacyTextLayoutCacheKey(NSString *text, UIFont *font, CGFloat width, NSUInteger maxLines)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    NSInteger pixelWidth = (NSInteger)lrint(MAX(0.0f, width) * scale);
    NSInteger pixelFontSize = (NSInteger)lrint(font.pointSize * scale * 16.0f);
    return [NSString stringWithFormat:@"%@|%@|%ld|%ld|%lu", text, font.fontName, (long)pixelFontSize, (long)pixelWidth, (unsigned long)maxLines];
}

static CGFloat TGDialogListLegacyTextWidth(NSString *text, UIFont *font)
{
    if (text.length == 0 || font == nil)
        return 0.0f;
    return CGCeil(TGDialogListCachedTextMetric(text, font, 0.0f, 1, 0).width);
}

static void TGDialogListLegacyAppendTextRun(TGDialogListLegacyTextLine *line, NSString *text, UIFont *font)
{
    if (line == nil || text.length == 0)
        return;

    CGFloat textWidth = TGDialogListLegacyTextWidth(text, font);
    TGDialogListLegacyTextRun *lastRun = [line.runs lastObject];
    if (lastRun != nil && lastRun.emoji.length == 0)
    {
        lastRun.text = [lastRun.text stringByAppendingString:text];
        lastRun.width += textWidth;
        line.width += textWidth;
        return;
    }

    TGDialogListLegacyTextRun *run = [[TGDialogListLegacyTextRun alloc] init];
    run.text = text;
    run.originX = line.width;
    run.width = textWidth;
    [line.runs addObject:run];
    line.width += run.width;
}

static void TGDialogListLegacyAppendEmojiRun(TGDialogListLegacyTextLine *line, NSString *emoji, CGFloat emojiSize, CGFloat spacing)
{
    if (line == nil || emoji.length == 0)
        return;

    TGDialogListLegacyTextRun *run = [[TGDialogListLegacyTextRun alloc] init];
    run.emoji = emoji;
    TGPreloadEmojiImageOfSize(emoji, emojiSize, nil);
    run.originX = line.width;
    run.width = emojiSize + spacing;
    [line.runs addObject:run];
    line.width += run.width;
}

static void TGDialogListLegacyTrimTrailingWhitespace(TGDialogListLegacyTextLine *line, UIFont *font)
{
    while (line.runs.count != 0)
    {
        TGDialogListLegacyTextRun *run = [line.runs lastObject];
        if (run.emoji.length != 0 || run.text.length == 0)
            break;

        NSUInteger length = run.text.length;
        while (length != 0)
        {
            unichar value = [run.text characterAtIndex:length - 1];
            if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:value])
                break;
            length--;
        }

        if (length == run.text.length)
            break;
        if (length == 0)
        {
            [line.runs removeLastObject];
            TGDialogListLegacyTextRun *previous = [line.runs lastObject];
            line.width = previous == nil ? 0.0f : previous.originX + previous.width;
            continue;
        }

        run.text = [run.text substringToIndex:length];
        run.width = TGDialogListLegacyTextWidth(run.text, font);
        line.width = run.originX + run.width;
        break;
    }
}

static NSUInteger TGDialogListLegacyPrefixLengthThatFits(NSString *text, UIFont *font, CGFloat width)
{
    if (text.length == 0 || width <= 0.0f)
        return 0;

    NSUInteger index = 0;
    NSUInteger best = 0;
    while (index < text.length)
    {
        NSRange range = [text rangeOfComposedCharacterSequenceAtIndex:index];
        NSUInteger end = NSMaxRange(range);
        NSString *candidate = [text substringToIndex:end];
        if (TGDialogListLegacyTextWidth(candidate, font) > width)
            break;
        best = end;
        index = end;
    }
    return best;
}

static void TGDialogListLegacyApplyEllipsis(TGDialogListLegacyTextLine *line, UIFont *font, CGFloat maxWidth)
{
    if (line == nil || maxWidth <= 0.0f)
        return;

    TGDialogListLegacyTrimTrailingWhitespace(line, font);
    NSString *ellipsis = @"\u2026";
    CGFloat ellipsisWidth = TGDialogListLegacyTextWidth(ellipsis, font);

    while (line.runs.count != 0 && line.width + ellipsisWidth > maxWidth)
    {
        TGDialogListLegacyTextRun *run = [line.runs lastObject];
        if (run.emoji.length != 0)
        {
            [line.runs removeLastObject];
            TGDialogListLegacyTextRun *previous = [line.runs lastObject];
            line.width = previous == nil ? 0.0f : previous.originX + previous.width;
            continue;
        }

        if (run.text.length == 0)
        {
            [line.runs removeLastObject];
            continue;
        }

        NSRange range = [run.text rangeOfComposedCharacterSequenceAtIndex:run.text.length - 1];
        run.text = [run.text substringToIndex:range.location];
        if (run.text.length == 0)
        {
            [line.runs removeLastObject];
            TGDialogListLegacyTextRun *previous = [line.runs lastObject];
            line.width = previous == nil ? 0.0f : previous.originX + previous.width;
        }
        else
        {
            run.width = TGDialogListLegacyTextWidth(run.text, font);
            line.width = run.originX + run.width;
        }
    }

    if (ellipsisWidth > maxWidth)
        return;

    TGDialogListLegacyAppendTextRun(line, ellipsis, font);
}

static TGDialogListLegacyTextLayout *TGDialogListBuildLegacyTextLayout(NSString *text, UIFont *font, CGFloat width, NSUInteger maxLines)
{
    if (text.length == 0 || font == nil || width <= 0.0f || maxLines == 0)
        return nil;

    TGDialogListLegacyTextLayout *layout = [[TGDialogListLegacyTextLayout alloc] init];
    layout.lineHeight = CGCeil(OGPlatformFontLineHeight(font));
    layout.emojiSize = MAX(1.0f, font.pointSize * 0.8f);

    NSMutableArray *lines = [[NSMutableArray alloc] init];
    TGDialogListLegacyTextLine *line = [[TGDialogListLegacyTextLine alloc] init];
    [lines addObject:line];

    NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
    NSUInteger index = 0;
    bool truncated = false;

    while (index < text.length && !truncated)
    {
        NSRange emojiRange = NSMakeRange(0, 0);
        if (TGEmojiPackMatchAtIndex(text, index, &emojiRange))
        {
            NSString *emoji = [text substringWithRange:emojiRange];
            if (TGEmojiNeedsPack(emoji))
            {
                CGFloat spacing = 0.0f;
                NSRange nextEmojiRange = NSMakeRange(0, 0);
                if (NSMaxRange(emojiRange) < text.length && TGEmojiPackMatchAtIndex(text, NSMaxRange(emojiRange), &nextEmojiRange))
                {
                    NSString *nextEmoji = [text substringWithRange:nextEmojiRange];
                    if (TGEmojiNeedsPack(nextEmoji))
                        spacing = MAX(1.0f, font.pointSize * 0.1f);
                }

                CGFloat runWidth = layout.emojiSize + spacing;
                if (line.width > 0.0f && line.width + runWidth > width)
                {
                    TGDialogListLegacyTrimTrailingWhitespace(line, font);
                    if (lines.count >= maxLines)
                    {
                        truncated = true;
                        break;
                    }
                    line = [[TGDialogListLegacyTextLine alloc] init];
                    [lines addObject:line];
                }

                if (line.width + runWidth <= width || line.width == 0.0f)
                    TGDialogListLegacyAppendEmojiRun(line, emoji, layout.emojiSize, spacing);
                index = NSMaxRange(emojiRange);
                continue;
            }
        }

        unichar value = [text characterAtIndex:index];
        if (value == '\n' || value == '\r')
        {
            if (value == '\r' && index + 1 < text.length && [text characterAtIndex:index + 1] == '\n')
                index++;
            index++;
            TGDialogListLegacyTrimTrailingWhitespace(line, font);
            if (index < text.length)
            {
                if (lines.count >= maxLines)
                {
                    truncated = true;
                    break;
                }
                line = [[TGDialogListLegacyTextLine alloc] init];
                [lines addObject:line];
            }
            continue;
        }

        bool isWhitespace = [whitespace characterIsMember:value];
        NSUInteger tokenStart = index;
        if (isWhitespace)
        {
            while (index < text.length)
            {
                unichar current = [text characterAtIndex:index];
                if (current == '\n' || current == '\r' || ![whitespace characterIsMember:current])
                    break;
                index++;
            }
        }
        else
        {
            while (index < text.length)
            {
                unichar current = [text characterAtIndex:index];
                if (current == '\n' || current == '\r' || [whitespace characterIsMember:current])
                    break;
                NSRange nestedEmojiRange = NSMakeRange(0, 0);
                if (TGEmojiPackMatchAtIndex(text, index, &nestedEmojiRange))
                {
                    NSString *nestedEmoji = [text substringWithRange:nestedEmojiRange];
                    if (TGEmojiNeedsPack(nestedEmoji))
                        break;
                    index = NSMaxRange(nestedEmojiRange);
                    continue;
                }
                NSRange composedRange = [text rangeOfComposedCharacterSequenceAtIndex:index];
                index = NSMaxRange(composedRange);
            }
        }

        if (index == tokenStart)
        {
            NSRange composedRange = [text rangeOfComposedCharacterSequenceAtIndex:index];
            index = NSMaxRange(composedRange);
        }

        NSString *token = [text substringWithRange:NSMakeRange(tokenStart, index - tokenStart)];
        if (token.length == 0)
            continue;

        if (isWhitespace)
        {
            if (line.width == 0.0f)
                continue;
            CGFloat tokenWidth = TGDialogListLegacyTextWidth(token, font);
            if (line.width + tokenWidth <= width)
                TGDialogListLegacyAppendTextRun(line, token, font);
            else
            {
                TGDialogListLegacyTrimTrailingWhitespace(line, font);
                if (lines.count >= maxLines)
                {
                    truncated = index < text.length;
                    break;
                }
                line = [[TGDialogListLegacyTextLine alloc] init];
                [lines addObject:line];
            }
            continue;
        }

        NSString *remainingToken = token;
        while (remainingToken.length != 0)
        {
            CGFloat availableWidth = width - line.width;
            CGFloat tokenWidth = TGDialogListLegacyTextWidth(remainingToken, font);
            if (tokenWidth <= availableWidth)
            {
                TGDialogListLegacyAppendTextRun(line, remainingToken, font);
                remainingToken = @"";
                break;
            }

            if (line.width > 0.0f)
            {
                TGDialogListLegacyTrimTrailingWhitespace(line, font);
                if (lines.count >= maxLines)
                {
                    CGFloat ellipsisWidth = TGDialogListLegacyTextWidth(@"\u2026", font);
                    CGFloat prefixWidth = MAX(0.0f, width - line.width - ellipsisWidth);
                    NSUInteger prefixLength = TGDialogListLegacyPrefixLengthThatFits(remainingToken, font, prefixWidth);
                    if (prefixLength != 0)
                        TGDialogListLegacyAppendTextRun(line, [remainingToken substringToIndex:prefixLength], font);
                    truncated = true;
                    break;
                }
                line = [[TGDialogListLegacyTextLine alloc] init];
                [lines addObject:line];
                continue;
            }

            NSUInteger prefixLength = TGDialogListLegacyPrefixLengthThatFits(remainingToken, font, width);
            if (prefixLength == 0)
            {
                NSRange firstRange = [remainingToken rangeOfComposedCharacterSequenceAtIndex:0];
                prefixLength = NSMaxRange(firstRange);
            }

            NSString *prefix = [remainingToken substringToIndex:prefixLength];
            TGDialogListLegacyAppendTextRun(line, prefix, font);
            remainingToken = [remainingToken substringFromIndex:prefixLength];
            if (remainingToken.length != 0)
            {
                if (lines.count >= maxLines)
                {
                    truncated = true;
                    break;
                }
                line = [[TGDialogListLegacyTextLine alloc] init];
                [lines addObject:line];
            }
        }
    }

    TGDialogListLegacyTrimTrailingWhitespace(line, font);
    if (truncated && lines.count != 0)
        TGDialogListLegacyApplyEllipsis([lines lastObject], font, width);

    layout.lines = lines;
    return layout;
}

static TGDialogListLegacyTextLayout *TGDialogListLegacyTextLayoutForText(NSString *text, UIFont *font, CGFloat width, NSUInteger maxLines)
{
    if (text.length == 0 || font == nil || width <= 0.0f || maxLines == 0)
        return nil;

    NSString *cacheKey = TGDialogListLegacyTextLayoutCacheKey(text, font, width, maxLines);
    OGMemoryCache *cache = TGDialogListSharedLegacyTextLayoutCache();
    TGDialogListLegacyTextLayout *layout = [cache objectForKey:cacheKey];
    if (layout != nil)
        return layout;

    layout = TGDialogListBuildLegacyTextLayout(text, font, width, maxLines);
    if (layout != nil)
        [cache setObject:layout forKey:cacheKey cost:1024 + text.length * sizeof(unichar)];
    return layout;
}

static void TGDialogListDrawLegacyEmojiText(TGDialogListLegacyTextLayout *layout, UIFont *font, UIColor *color, CGRect rect, NSTextAlignment alignment, UIImage *(^emojiProvider)(NSString *, CGFloat))
{
    if (layout == nil || font == nil || rect.size.width <= 0.0f || rect.size.height <= 0.0f)
        return;

    UIColor *resolvedColor = color == nil ? [UIColor blackColor] : color;
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context != NULL)
    {
        CGContextSaveGState(context);
        CGContextClipToRect(context, rect);
    }
    [resolvedColor set];
    NSUInteger lineIndex = 0;
    for (TGDialogListLegacyTextLine *line in layout.lines)
    {
        CGFloat lineY = rect.origin.y + layout.lineHeight * lineIndex;
        if (lineY >= CGRectGetMaxY(rect))
            break;

        CGFloat lineOffset = 0.0f;
        if (alignment == NSTextAlignmentCenter)
            lineOffset = CGFloor((rect.size.width - line.width) / 2.0f);
        else if (alignment == NSTextAlignmentRight)
            lineOffset = rect.size.width - line.width;
        lineOffset = MAX(0.0f, lineOffset);

        for (TGDialogListLegacyTextRun *run in line.runs)
        {
            CGFloat runX = rect.origin.x + lineOffset + run.originX;
            if (run.emoji.length != 0)
            {
                UIImage *emojiImage = emojiProvider == nil ? nil : emojiProvider(run.emoji, layout.emojiSize);
                if (emojiImage != nil)
                {
                    CGFloat imageY = lineY + CGFloor((layout.lineHeight - layout.emojiSize) / 2.0f);
                    [emojiImage drawInRect:CGRectMake(runX, imageY, layout.emojiSize, layout.emojiSize)];
                }
            }
            else if (run.text.length != 0)
            {
                CGRect runRect = CGRectMake(runX, lineY, MAX(1.0f, run.width + 2.0f), layout.lineHeight);
                [run.text drawInRect:runRect withFont:font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft];
            }
        }
        lineIndex++;
    }
    if (context != NULL)
        CGContextRestoreGState(context);
}

static void TGDialogListDrawLegacyNativeText(NSString *text, UIFont *font, UIColor *color, CGRect rect, NSUInteger maxLines, NSTextAlignment alignment)
{
    if (text.length == 0 || font == nil || rect.size.width <= 0.0f || rect.size.height <= 0.0f)
        return;

    UIColor *resolvedColor = color == nil ? [UIColor blackColor] : color;
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context != NULL)
    {
        CGContextSaveGState(context);
        CGContextClipToRect(context, rect);
    }
    [resolvedColor set];
    UILineBreakMode lineBreakMode = maxLines > 1 ? UILineBreakModeWordWrap : UILineBreakModeTailTruncation;
    [text drawInRect:rect withFont:font lineBreakMode:lineBreakMode alignment:(UITextAlignment)alignment];
    if (context != NULL)
        CGContextRestoreGState(context);
}

@interface TGDialogListTextView : UIView
{
    TGReusableLabelLayoutData *_titleLayout;
    TGReusableLabelLayoutData *_textLayout;
    TGReusableLabelLayoutData *_authorNameLayout;
    TGReusableLabelLayoutData *_typingLayout;
    TGDialogListLegacyTextLayout *_legacyTitleLayout;
    TGDialogListLegacyTextLayout *_legacyTextLayout;
    TGDialogListLegacyTextLayout *_legacyAuthorNameLayout;
    TGDialogListLegacyTextLayout *_legacyTypingLayout;
    TGReusableLabelLayoutData *_statusLayout;
    TGDialogListLegacyTextLayout *_legacyStatusLayout;
    NSMutableSet *_pendingLegacyEmojiImages;
    bool _missedEmoji;
}
@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic, strong) NSString *title;
@property (nonatomic) CGRect titleFrame;
@property (nonatomic, strong) UIFont *titleFont;
@property (nonatomic, strong) UIImage *mediaIcon;
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) UIColor *textColor;
@property (nonatomic, strong) UIColor *actionTextColor;
@property (nonatomic) CGRect textFrame;
@property (nonatomic, strong) UIFont *textFont;
@property (nonatomic , strong) NSString *authorName;
@property (nonatomic) CGRect authorNameFrame;
@property (nonatomic, strong) UIFont *authorNameFont;
@property (nonatomic, strong) UIColor *authorNameColor;

@property (nonatomic) CGRect typingFrame;
@property (nonatomic) bool showTyping;
@property (nonatomic, strong) NSString *typingText;

@property (nonatomic) bool isMultichat;
@property (nonatomic) bool isEncrypted;
@property (nonatomic) bool isMuted;
@property (nonatomic) bool isVerified;

@property (nonatomic, strong) NSString *statusText;
@property (nonatomic, strong) UIFont *statusFont;
@property (nonatomic, strong) UIColor *statusColor;
@property (nonatomic) CGRect statusFrame;

@property (nonatomic, strong, readonly) UIColor *backdropColor;

- (void)setBackdropColor:(UIColor *)backdropColor image:(UIImage *)backdropImage imageFrame:(CGRect)backdropImageFrame;

@end

@implementation TGDialogListTextView
{
    UIImage *_backdropImage;
    CGRect _backdropImageFrame;
}

- (void)setBackdropColor:(UIColor *)backdropColor image:(UIImage *)backdropImage imageFrame:(CGRect)backdropImageFrame
{
    if (backdropColor == nil)
    {
        backdropImage = nil;
        backdropImageFrame = CGRectZero;
    }
    if (backdropImage == nil)
        backdropImageFrame = CGRectZero;

    bool colorChanged = _backdropColor != backdropColor && ![_backdropColor isEqual:backdropColor];
    if (!colorChanged && _backdropImage == backdropImage && CGRectEqualToRect(_backdropImageFrame, backdropImageFrame))
        return;

    _backdropColor = backdropColor;
    _backdropImage = backdropImage;
    _backdropImageFrame = backdropImageFrame;
    self.opaque = backdropColor != nil;
    [self setNeedsDisplay];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emojiImagesLoaded:) name:TGReusableLabelEmojiImagesLoadedNotification object:nil];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGReusableLabelEmojiImagesLoadedNotification object:nil];
}

- (void)emojiImagesLoaded:(NSNotification *)__unused notification
{
    if (_missedEmoji)
    {
        _missedEmoji = false;
        [self setNeedsDisplay];
    }
}

- (UIImage *)legacyEmojiImageForEmoji:(NSString *)emoji size:(CGFloat)size
{
    UIImage *image = TGEmojiCachedImageOfSize(emoji, size);
    if (image != nil)
        return image;

    if (_pendingLegacyEmojiImages == nil)
        _pendingLegacyEmojiImages = [[NSMutableSet alloc] init];

    NSString *pendingKey = [NSString stringWithFormat:@"%@/%d", emoji, (int)lrintf(size * 10.0f)];
    if (![_pendingLegacyEmojiImages containsObject:pendingKey])
    {
        [_pendingLegacyEmojiImages addObject:pendingKey];
        __weak TGDialogListTextView *weakSelf = self;
        NSString *completionKey = [pendingKey copy];
        TGPreloadEmojiImageOfSize(emoji, size, ^
        {
            TGDialogListTextView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            [strongSelf->_pendingLegacyEmojiImages removeObject:completionKey];
            [strongSelf setNeedsDisplay];
        });
    }

    return nil;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    if (_presentation != presentation)
    {
        _presentation = presentation;
        _titleLayout = nil;
        _textLayout = nil;
        _authorNameLayout = nil;
        _typingLayout = nil;
        _legacyTitleLayout = nil;
        _legacyTextLayout = nil;
        _legacyAuthorNameLayout = nil;
        _legacyTypingLayout = nil;
    }
}

- (void)setTitle:(NSString *)title
{
    if (_title != title && ![_title isEqualToString:title])
    {
        _title = title;
        _titleLayout = nil;
        _legacyTitleLayout = nil;
    }
}

- (void)setTitleFrame:(CGRect)titleFrame
{
    if (!CGRectEqualToRect(_titleFrame, titleFrame))
    {
        _titleFrame = titleFrame;
        _titleLayout = nil;
        _legacyTitleLayout = nil;
    }
}

- (void)setStatusText:(NSString *)statusText
{
    if (_statusText != statusText && ![_statusText isEqualToString:statusText])
    {
        _statusText = statusText;
        _statusLayout = nil;
        _legacyStatusLayout = nil;
        [self setNeedsDisplay];
    }
}

- (void)setStatusFont:(UIFont *)statusFont
{
    if (_statusFont != statusFont && ![_statusFont isEqual:statusFont])
    {
        _statusFont = statusFont;
        _statusLayout = nil;
        _legacyStatusLayout = nil;
        [self setNeedsDisplay];
    }
}

- (void)setStatusColor:(UIColor *)statusColor
{
    if (_statusColor != statusColor && ![_statusColor isEqual:statusColor])
    {
        _statusColor = statusColor;
        [self setNeedsDisplay];
    }
}

- (void)setStatusFrame:(CGRect)statusFrame
{
    if (!CGRectEqualToRect(_statusFrame, statusFrame))
    {
        if (ABS(_statusFrame.size.width - statusFrame.size.width) > FLT_EPSILON)
        {
            _statusLayout = nil;
            _legacyStatusLayout = nil;
        }
        _statusFrame = statusFrame;
        [self setNeedsDisplay];
    }
}

- (void)setTitleFont:(UIFont *)titleFont
{
    if (_titleFont != titleFont && ![_titleFont isEqual:titleFont])
    {
        _titleFont = titleFont;
        _titleLayout = nil;
        _legacyTitleLayout = nil;
    }
}

- (void)setMediaIcon:(UIImage *)mediaIcon
{
    if (_mediaIcon != mediaIcon)
    {
        _mediaIcon = mediaIcon;
        _textLayout = nil;
        _legacyTextLayout = nil;
    }
}

- (void)setText:(NSString *)text
{
    if (_text != text && ![_text isEqualToString:text])
    {
        _text = text;
        _textLayout = nil;
        _legacyTextLayout = nil;
    }
}

- (void)setTextColor:(UIColor *)textColor
{
    if (![_textColor isEqual:textColor])
    {
        _textColor = textColor;
        _textLayout = nil;
    }
}

- (void)setTextFont:(UIFont *)textFont
{
    if (_textFont != textFont && ![_textFont isEqual:textFont])
    {
        _textFont = textFont;
        _textLayout = nil;
        _typingLayout = nil;
        _legacyTextLayout = nil;
        _legacyTypingLayout = nil;
    }
}

- (void)setActionTextColor:(UIColor *)actionTextColor
{
    if (![_actionTextColor isEqual:actionTextColor])
    {
        _actionTextColor = actionTextColor;
        _typingLayout = nil;
    }
}

- (void)setTextFrame:(CGRect)textFrame
{
    if (!CGRectEqualToRect(_textFrame, textFrame))
    {
        _textFrame = textFrame;
        _textLayout = nil;
        _legacyTextLayout = nil;
    }
}

- (void)setAuthorName:(NSString *)authorName
{
    if (_authorName != authorName && ![_authorName isEqualToString:authorName])
    {
        _authorName = authorName;
        _authorNameLayout = nil;
        _textLayout = nil;
        _legacyAuthorNameLayout = nil;
        _legacyTextLayout = nil;
    }
}

- (void)setAuthorNameFrame:(CGRect)authorNameFrame
{
    if (!CGRectEqualToRect(_authorNameFrame, authorNameFrame))
    {
        _authorNameFrame = authorNameFrame;
        _authorNameLayout = nil;
        _legacyAuthorNameLayout = nil;
    }
}

- (void)setAuthorNameFont:(UIFont *)authorNameFont
{
    if (_authorNameFont != authorNameFont && ![_authorNameFont isEqual:authorNameFont])
    {
        _authorNameFont = authorNameFont;
        _authorNameLayout = nil;
        _legacyAuthorNameLayout = nil;
    }
}

- (void)setAuthorNameColor:(UIColor *)authorNameColor
{
    if (![_authorNameColor isEqual:authorNameColor])
    {
        _authorNameColor = authorNameColor;
        _authorNameLayout = nil;
    }
}

- (void)setTypingFrame:(CGRect)typingFrame
{
    if (!CGRectEqualToRect(_typingFrame, typingFrame))
    {
        _typingFrame = typingFrame;
        _typingLayout = nil;
        _legacyTypingLayout = nil;
    }
}

- (void)setTypingText:(NSString *)typingText
{
    if (_typingText != typingText && ![_typingText isEqualToString:typingText])
    {
        _typingText = typingText;
        _typingLayout = nil;
        _legacyTypingLayout = nil;
    }
}

- (void)setIsEncrypted:(bool)isEncrypted
{
    if (_isEncrypted != isEncrypted)
    {
        _isEncrypted = isEncrypted;
        _titleLayout = nil;
        _legacyTitleLayout = nil;
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    TGReusableLabelResetMissedEmoji();

    if (_backdropColor != nil)
    {
        CGContextSetFillColorWithColor(context, _backdropColor.CGColor);
        CGContextFillRect(context, rect);
        if (_backdropImage != nil)
            [_backdropImage drawInRect:_backdropImageFrame];
    }

    CGRect frame = self.frame;
    CGRect titleFrame = CGRectOffset(_titleFrame, -frame.origin.x, -frame.origin.y);
    CGRect textFrame = CGRectOffset(_textFrame, -frame.origin.x, -frame.origin.y);
    CGRect authorNameFrame = CGRectOffset(_authorNameFrame, -frame.origin.x, -frame.origin.y);
    CGRect typingFrame = CGRectOffset(_typingFrame, -frame.origin.x, -frame.origin.y);
    bool useStableTextDrawing = iosMajorVersion() >= 7;
    UIImage *(^emojiProvider)(NSString *, CGFloat) = ^UIImage *(NSString *emoji, CGFloat size)
    {
        return [self legacyEmojiImageForEmoji:emoji size:size];
    };
    
    if (_isEncrypted)
    {
        UIImage *image = _presentation.images.dialogEncryptedIcon;
        [image drawAtPoint:CGPointMake(1.0f, 6.0f) blendMode:kCGBlendModeNormal alpha:1.0f];
    }
    
    CGContextSetFillColorWithColor(context, _isEncrypted ? _presentation.pallete.dialogEncryptedColor.CGColor : _presentation.pallete.dialogTitleColor.CGColor);
    if (CGRectIntersectsRect(rect, titleFrame))
    {
        UIColor *titleColor = _isEncrypted ? _presentation.pallete.dialogEncryptedColor : _presentation.pallete.dialogTitleColor;
        bool legacyIOS3Title = iosMajorVersion() <= 3;
        bool nativeTitle = TGDialogListUseLegacyNativeText(_title);
        if (legacyIOS3Title)
        {
            if (nativeTitle)
                TGDialogListDrawLegacyNativeText(_title, _titleFont, titleColor, titleFrame, 1, NSTextAlignmentLeft);
            else
            {
                if (_legacyTitleLayout == nil)
                    _legacyTitleLayout = TGDialogListLegacyTextLayoutForText(_title, _titleFont, titleFrame.size.width, 1);
                TGDialogListDrawLegacyEmojiText(_legacyTitleLayout, _titleFont, titleColor, titleFrame, NSTextAlignmentLeft, emojiProvider);
            }
        }
        else
        {
            if (_titleLayout == nil)
                _titleLayout = TGDialogListTextLayout(_title, _titleFont, titleFrame.size.width, 1, NSTextAlignmentLeft);
            TGDialogListDrawLayout(_titleLayout, titleFrame);
        }
    }

    CGRect statusFrame = CGRectOffset(_statusFrame, -frame.origin.x, -frame.origin.y);
    if (_statusText.length != 0 && _statusFont != nil && _statusColor != nil && statusFrame.size.width > 0.0f && CGRectIntersectsRect(rect, statusFrame))
    {
        CGContextSetFillColorWithColor(context, _statusColor.CGColor);
        if (iosMajorVersion() <= 3)
        {
            if (TGDialogListUseLegacyNativeText(_statusText))
                TGDialogListDrawLegacyNativeText(_statusText, _statusFont, _statusColor, statusFrame, 1, NSTextAlignmentLeft);
            else
            {
                if (_legacyStatusLayout == nil)
                    _legacyStatusLayout = TGDialogListLegacyTextLayoutForText(_statusText, _statusFont, statusFrame.size.width, 1);
                TGDialogListDrawLegacyEmojiText(_legacyStatusLayout, _statusFont, _statusColor, statusFrame, NSTextAlignmentLeft, emojiProvider);
            }
        }
        else
        {
            if (_statusLayout == nil)
                _statusLayout = TGDialogListTextLayout(_statusText, _statusFont, statusFrame.size.width, 1, NSTextAlignmentLeft);
            TGDialogListDrawLayout(_statusLayout, statusFrame);
        }
    }
    
    if (_showTyping)
    {
        CGContextSetFillColorWithColor(context, _actionTextColor.CGColor);
        
        bool legacyIOS3Typing = iosMajorVersion() <= 3;
        bool nativeTyping = TGDialogListUseLegacyNativeText(_typingText);
        if (legacyIOS3Typing)
        {
            if (nativeTyping)
                TGDialogListDrawLegacyNativeText(_typingText, _textFont, _actionTextColor, typingFrame, 1, NSTextAlignmentLeft);
            else
            {
                if (_legacyTypingLayout == nil)
                    _legacyTypingLayout = TGDialogListLegacyTextLayoutForText(_typingText, _textFont, typingFrame.size.width, 1);
                TGDialogListDrawLegacyEmojiText(_legacyTypingLayout, _textFont, _actionTextColor, typingFrame, NSTextAlignmentLeft, emojiProvider);
            }
        }
        else
        {
            if (_typingLayout == nil)
                _typingLayout = TGDialogListTextLayout(_typingText, _textFont, typingFrame.size.width, 1, NSTextAlignmentLeft);
            TGDialogListDrawLayout(_typingLayout, typingFrame);
        }
    }
    else
    {
        if (CGRectIntersectsRect(rect, textFrame))
        {
            CGContextSetFillColorWithColor(context, _textColor.CGColor);
            
            if (_mediaIcon != nil)
            {
                [_mediaIcon drawAtPoint:CGPointMake(textFrame.origin.x, textFrame.origin.y + 1.0f + TGScreenPixel) blendMode:kCGBlendModeNormal alpha:1.0f];
                textFrame = CGRectMake(textFrame.origin.x + 19, textFrame.origin.y, textFrame.size.width - 19, textFrame.size.height);
            }
            
            NSUInteger maxLines = TGDialogListBrandedIOS6Style() ? (_authorName.length == 0 ? 2 : 1) : (textFrame.size.height >= 30.0f ? 2 : 1);
            bool legacyIOS3Text = iosMajorVersion() <= 3;
            bool nativeText = TGDialogListUseLegacyNativeText(_text);
            if (legacyIOS3Text)
            {
                if (nativeText)
                    TGDialogListDrawLegacyNativeText(_text, _textFont, _textColor, textFrame, maxLines, NSTextAlignmentLeft);
                else
                {
                    if (_legacyTextLayout == nil)
                        _legacyTextLayout = TGDialogListLegacyTextLayoutForText(_text, _textFont, textFrame.size.width, maxLines);
                    TGDialogListDrawLegacyEmojiText(_legacyTextLayout, _textFont, _textColor, textFrame, NSTextAlignmentLeft, emojiProvider);
                }
            }
            else
            {
                if (_textLayout == nil)
                    _textLayout = TGDialogListTextLayout(_text, _textFont, textFrame.size.width, maxLines, NSTextAlignmentLeft);
                TGDialogListDrawLayout(_textLayout, textFrame);
            }
            
        }
    
        if (_authorName != nil && _authorName.length != 0)
        {
            CGContextSetFillColorWithColor(context, _authorNameColor == nil ? [UIColor blackColor].CGColor : [_authorNameColor CGColor]);
            if (CGRectIntersectsRect(rect, authorNameFrame))
            {
                NSTextAlignment alignment = TGDialogListBrandedIOS6Style() || useStableTextDrawing ? NSTextAlignmentLeft : NSTextAlignmentRight;
                UIColor *authorColor = _authorNameColor == nil ? [UIColor blackColor] : _authorNameColor;
                bool legacyIOS3Author = iosMajorVersion() <= 3;
                bool nativeAuthor = TGDialogListUseLegacyNativeText(_authorName);
                if (legacyIOS3Author)
                {
                    if (nativeAuthor)
                        TGDialogListDrawLegacyNativeText(_authorName, _authorNameFont, authorColor, authorNameFrame, 1, alignment);
                    else
                    {
                        if (_legacyAuthorNameLayout == nil)
                            _legacyAuthorNameLayout = TGDialogListLegacyTextLayoutForText(_authorName, _authorNameFont, authorNameFrame.size.width, 1);
                        TGDialogListDrawLegacyEmojiText(_legacyAuthorNameLayout, _authorNameFont, authorColor, authorNameFrame, alignment, emojiProvider);
                    }
                }
                else
                {
                    if (_authorNameLayout == nil)
                        _authorNameLayout = TGDialogListTextLayout(_authorName, _authorNameFont, authorNameFrame.size.width, 1, alignment);
                    TGDialogListDrawLayout(_authorNameLayout, authorNameFrame);
                }
                
            }
        }
    }
    _missedEmoji = TGReusableLabelMissedEmoji();
}

@end

#pragma mark - Cell

@interface TGDialogListCellGeometryCacheEntry : NSObject
{
@public
    int64_t conversationId;
    CGSize size;
    CGFloat contentOffset;
    CGFloat contentWidth;
    TGPresentation *presentation;
    bool brandedStyle;
    bool classicStyle;
    NSString *unreadText;
    UIFont *unreadFont;
    bool unreadCountHidden;
    bool pinnedHidden;
    bool mentionHidden;
    bool deliveryErrorVisible;
    bool pendingVisible;
    bool deliveryStatusVisible;
    NSString *dateText;
    bool hasDate;
    bool isAd;
    NSString *statusText;
    UIFont *statusFont;
    bool statusHidden;
    bool isEncrypted;
    bool isMuted;
    bool isVerified;
    bool premiumVisible;
    NSString *titleText;
    UIFont *titleFont;
    NSString *typingText;
    UIFont *typingFont;
    bool typingVisible;
    NSString *authorName;
    bool hideAuthorName;
    NSString *messageText;
    NSString *renderedMessageText;
    UIFont *messageFont;
    CGRect textViewFrame;
    CGRect unreadBackgroundFrame;
    CGRect pinnedFrame;
    CGRect unreadLabelFrame;
    CGRect mentionFrame;
    CGRect deliveryErrorFrame;
    CGRect dateFrame;
    CGRect deliveredFrame;
    CGRect readFrame;
    CGRect pendingFrame;
    CGRect statusFrame;
    CGRect typingFrame;
    CGRect typingDotsFrame;
    CGRect authorFrame;
    CGRect verifiedFrame;
    CGRect premiumFrame;
    CGRect muteFrame;
    CGRect titleFrame;
    CGRect messageFrame;
}
@end

@implementation TGDialogListCellGeometryCacheEntry
@end

static OGMemoryCache *TGDialogListCellGeometryCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:TGDialogListTextCacheLimit() / 2 costLimit:2 * 1024 * 1024];
    });
    return cache;
}

static TGDialogListCellGeometryCacheEntry *TGDialogListCellGeometryCacheGet(int64_t conversationId)
{
    return conversationId == 0 ? nil : [TGDialogListCellGeometryCache() objectForKey:@(conversationId)];
}

static void TGDialogListCellGeometryCachePut(TGDialogListCellGeometryCacheEntry *entry)
{
    if (entry == nil || entry->conversationId == 0)
        return;
    NSUInteger cost = 1024 + (entry->titleText.length + entry->messageText.length + entry->renderedMessageText.length + entry->authorName.length + entry->typingText.length + entry->statusText.length) * sizeof(unichar);
    [TGDialogListCellGeometryCache() setObject:entry forKey:@(entry->conversationId) cost:cost];
}

@interface TGDialogListCell () <UIGestureRecognizerDelegate>
{
    CALayer *_separatorLayer;
    UIImageView *_communityIndicatorView;
    
    UIImage *_unreadBackgroundImage;
    UIImage *_unreadMutedBackgroundImage;
    UIImage *_unseenMentionsImage;
    
    NSMutableArray *_avatarViews;
    bool _fastScrolling;
    CGSize _fastLayoutSize;
    CGFloat _fastLayoutContentOffset;
    CGFloat _fastLayoutContentWidth;
    NSString *_layoutUnreadText;
    UIFont *_layoutUnreadFont;
    CGFloat _layoutUnreadTextWidth;
    NSString *_layoutDateText;
    CGSize _layoutDateTextSize;
    NSString *_layoutStatusText;
    UIFont *_layoutStatusFont;
    CGFloat _layoutStatusWidth;
    NSString *_layoutTitleText;
    UIFont *_layoutTitleFont;
    CGFloat _layoutTitleWidth;
    NSString *_layoutTypingText;
    UIFont *_layoutTypingFont;
    CGFloat _layoutTypingWidth;
    CGSize _layoutTypingSize;
    NSString *_layoutMessageText;
    UIFont *_layoutMessageFont;
    CGFloat _layoutMessageWidth;
    CGSize _layoutMessageSize;
    NSString *_messageText;
    NSString *_authorName;
    NSString *_sourceMessageText;
    NSString *_sourceAuthorName;
    bool _hasResetSnapshot;
    TGPresentation *_resetPresentation;
    NSString *_resetSourceMessageText;
    NSArray *_resetSourceMessageAttachments;
    NSDictionary *_resetSourcePreparedPreview;
    NSDictionary *_resetSourceUsers;
    NSString *_resetSourceAuthorName;
    NSString *_resetSourceEncryptionFirstName;
    int64_t _resetSourceConversationId;
    int _resetSourceIsSavedMessages;
    int _resetSourceEncryptionStatus;
    bool _resetSourceIsGroupChat;
    bool _resetSourceRawText;
    bool _resetSourceIsChannel;
    bool _resetSourceIsChannelGroup;
    bool _resetSourceIsEncrypted;
    bool _resetSourceEncryptionOutgoing;
    bool _resetSourceAuthorIsSelf;
    bool _resetSourceOutgoing;
    bool _resetBrandedStyle;
    bool _resetClassicStyle;
    NSString *_resetAvatarUrl;
    NSArray *_resetAvatarTitleLetters;
    NSArray *_resetFeedChatIds;
    NSArray *_resetFeedChatTitles;
    NSArray *_resetFeedAvatarUrls;
    NSString *_resetAvatarTitleText;
    int64_t _resetAvatarConversationId;
    int _resetAvatarIsSavedMessages;
    int _resetAvatarEncryptedUserId;
    bool _resetAvatarIsFeed;
    bool _resetAvatarHasExplicitContent;
    bool _resetAvatarIsEncrypted;
    bool _resetAvatarIsBroadcast;
    NSString *_resetPreparedMessageText;
    UIColor *_resetPreparedMessageTextColor;
    UIImage *_resetPreparedMediaIcon;
    bool _resetPreparedHideAuthorName;
    uint32_t _editingControlsState;
    bool _editingControlsStateValid;
}

@property (nonatomic, strong) TGDialogListCellEditingControls *wrapView;

@property (nonatomic, strong) TGDialogListTextView *textView;

@property (nonatomic, strong) TGLetteredAvatarView *avatarView;
@property (nonatomic, strong) UIImageView *brandedAvatarOverlayView;
@property (nonatomic, strong) UIImageView *brandedBackgroundView;
@property (nonatomic, strong) UIImageView *authorAvatarStrokeView;

@property (nonatomic, strong) TGDateLabel *dateLabel;

@property (nonatomic, strong) UIImageView *unreadCountBackgrond;
@property (nonatomic, strong) UIImageView *unseenMentionsView;
@property (nonatomic, strong) UIImageView *pinnedBackgrond;
@property (nonatomic, strong) UIImageView *brandedDisclosureView;
@property (nonatomic, strong) TGLabel *unreadCountLabel;

@property (nonatomic, strong) UIImageView *deliveryErrorBackgrond;

@property (nonatomic, strong) UIImageView *deliveredCheckmark;
@property (nonatomic, strong) UIImageView *readCheckmark;
@property (nonatomic, strong) UIImageView *pendingIndicator;

@property (nonatomic, strong) NSString *dateString;

@property (nonatomic) int validViews;
@property (nonatomic) CGSize validSize;

@property (nonatomic) bool hideAuthorName;

@property (nonatomic) bool editingIsActive;

@property (nonatomic, strong) UIImage *mediaIcon;

@property (nonatomic, strong) UIColor *messageTextColor;

@property (nonatomic, strong) UIImageView *muteIcon;
@property (nonatomic, strong) UIImageView *verifiedIcon;
@property (nonatomic, strong) UIImageView *premiumIcon;

@property (nonatomic, strong) UIView *typingDotsContainer;
@property (nonatomic) bool animatingTyping;
@property (nonatomic, strong) NSTimer *typingDotsTimer;
@property (nonatomic) int typingDotsAnimationStep;

@end

@implementation TGDialogListCell

+ (CGFloat)communityContentInsetForContainerWidth:(CGFloat)containerWidth
{
    return [TGCommunityAppearance contentInsetForContainerWidth:containerWidth avatarInset:TGDialogListAvatarInset()];
}

+ (uint64_t)renderCacheGeneration
{
    return TGDialogListSharedTextLayoutCache().evictionGeneration + TGDialogListSharedLegacyTextLayoutCache().evictionGeneration + TGDialogListSharedTextMetricCache().evictionGeneration;
}

- (void)applyBrandedBadgeAppearance
{
    CGSize badgeSize = _unreadCountBackgrond.bounds.size;
    UIImage *badgeImage = [TGPresentation brandedIOS6ShadowedBadgeImageForWidth:badgeSize.width height:badgeSize.height];
    if (_unreadCountBackgrond.image != badgeImage)
        _unreadCountBackgrond.image = badgeImage;
    _unreadCountLabel.textAlignment = NSTextAlignmentCenter;
}

- (bool)brandedStatusVisible
{
    return TGDialogListBrandedIOS6Style() && _textView.statusText.length != 0 && _textView.statusFont != nil;
}

- (void)layoutBrandedBadgesWithTitleRect:(CGRect)titleRect badgeSize:(CGSize)badgeSize
{
    CGFloat titleLineMaxX = CGRectGetMaxX(titleRect);
    if (_isVerified)
        titleLineMaxX = CGRectGetMaxX(_verifiedIcon.frame);
    else if (_premiumIcon.superview != nil)
        titleLineMaxX = CGRectGetMaxX(_premiumIcon.frame);
    if ([self brandedStatusVisible])
        titleLineMaxX = CGRectGetMaxX(_textView.statusFrame);
    if (_isMuted)
        titleLineMaxX = CGRectGetMaxX(_muteIcon.frame);

    CGFloat titleCenterY = titleRect.origin.y + TGDialogListTitleCapCenterOffset(_textView.titleFont);

    CGFloat nextX = titleLineMaxX + TGDialogListBrandedIOS6BadgeSpacing;
    if (!_unreadCountBackgrond.hidden)
    {
        CGRect badgeFrame = CGRectMake(nextX, TGDialogListCenteredOrigin(titleCenterY, badgeSize.height), badgeSize.width, badgeSize.height);
        if (!CGRectEqualToRect(_unreadCountBackgrond.frame, badgeFrame))
            _unreadCountBackgrond.frame = badgeFrame;
        [self applyBrandedBadgeAppearance];

        CGRect labelFrame = badgeFrame;
        labelFrame.origin.y += TGScreenPixel;
        if (!CGRectEqualToRect(_unreadCountLabel.frame, labelFrame))
            _unreadCountLabel.frame = labelFrame;
        nextX = CGRectGetMaxX(badgeFrame) + TGDialogListBrandedIOS6BadgeSpacing;
    }

    CGSize mentionSize = _unseenMentionsView.image.size;
    UIEdgeInsets mentionOutsets = [TGPresentation brandedIOS6DialogMentionImageOutsets];
    CGRect mentionFrame = CGRectMake(nextX - mentionOutsets.left, TGDialogListCenteredOrigin(titleCenterY, mentionSize.height), mentionSize.width, mentionSize.height);
    if (!CGRectEqualToRect(_unseenMentionsView.frame, mentionFrame))
        _unseenMentionsView.frame = mentionFrame;
}

- (TGDialogListCellGeometryCacheEntry *)cachedGeometryForSize:(CGSize)size contentOffset:(CGFloat)contentOffset contentWidth:(CGFloat)contentWidth
{
    TGDialogListCellGeometryCacheEntry *entry = TGDialogListCellGeometryCacheGet(_conversationId);
    if (entry == nil)
        return nil;
    if (!CGSizeEqualToSize(entry->size, size) || ABS(entry->contentOffset - contentOffset) > FLT_EPSILON || ABS(entry->contentWidth - contentWidth) > FLT_EPSILON)
        return nil;
    if (entry->presentation != _presentation || entry->brandedStyle != TGDialogListBrandedIOS6Style() || entry->classicStyle != TGDialogListClassicIOS6Style())
        return nil;
    if (!TGDialogListObjectsEqual(entry->unreadText, _unreadCountLabel.text ?: @"") || !TGDialogListObjectsEqual(entry->unreadFont, _unreadCountLabel.font))
        return nil;
    if (entry->unreadCountHidden != _unreadCountBackgrond.hidden || entry->pinnedHidden != _pinnedBackgrond.hidden || entry->mentionHidden != _unseenMentionsView.hidden)
        return nil;
    bool deliveryErrorVisible = _deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil;
    if (entry->deliveryErrorVisible != deliveryErrorVisible)
        return nil;
    bool pendingVisible = _pendingIndicator != nil && !_pendingIndicator.hidden;
    if (entry->pendingVisible != pendingVisible)
        return nil;
    bool deliveryStatusVisible = !_deliveredCheckmark.hidden || !_readCheckmark.hidden || pendingVisible;
    if (entry->deliveryStatusVisible != deliveryStatusVisible)
        return nil;
    if (!TGDialogListObjectsEqual(entry->dateText, _dateLabel.rawDateText ?: @"") || entry->hasDate != (_date != 0) || entry->isAd != _isAd)
        return nil;
    if (!TGDialogListObjectsEqual(entry->statusText, _textView.statusText ?: @"") || !TGDialogListObjectsEqual(entry->statusFont, _textView.statusFont) || entry->statusHidden != ![self brandedStatusVisible])
        return nil;
    if (entry->isEncrypted != _isEncrypted || entry->isMuted != _isMuted || entry->isVerified != _isVerified || entry->premiumVisible != (_premiumIcon.superview != nil))
        return nil;
    if (!TGDialogListObjectsEqual(entry->titleText, _titleText) || !TGDialogListObjectsEqual(entry->titleFont, _textView.titleFont))
        return nil;
    bool typingVisible = _typingDotsContainer.superview != nil;
    if (!TGDialogListObjectsEqual(entry->typingText, _textView.typingText ?: @"") || !TGDialogListObjectsEqual(entry->typingFont, _textView.textFont) || entry->typingVisible != typingVisible)
        return nil;
    if (!TGDialogListObjectsEqual(entry->authorName, _authorName) || entry->hideAuthorName != _hideAuthorName)
        return nil;
    if (!TGDialogListObjectsEqual(entry->messageText, _messageText) || !TGDialogListObjectsEqual(entry->renderedMessageText, _textView.text) || !TGDialogListObjectsEqual(entry->messageFont, _textView.textFont))
        return nil;
    return entry;
}

- (void)applyCachedGeometry:(TGDialogListCellGeometryCacheEntry *)entry size:(CGSize)size contentOffset:(CGFloat)contentOffset contentWidth:(CGFloat)contentWidth
{
    if (!CGRectEqualToRect(_textView.frame, entry->textViewFrame))
    {
        _textView.frame = entry->textViewFrame;
        [_textView setNeedsDisplay];
    }
    if (!CGRectEqualToRect(_unreadCountBackgrond.frame, entry->unreadBackgroundFrame))
        _unreadCountBackgrond.frame = entry->unreadBackgroundFrame;
    if (TGDialogListBrandedIOS6Style())
        [self applyBrandedBadgeAppearance];
    if (!CGRectEqualToRect(_pinnedBackgrond.frame, entry->pinnedFrame))
        _pinnedBackgrond.frame = entry->pinnedFrame;
    if (!CGRectEqualToRect(_unreadCountLabel.frame, entry->unreadLabelFrame))
        _unreadCountLabel.frame = entry->unreadLabelFrame;
    if (!CGRectEqualToRect(_unseenMentionsView.frame, entry->mentionFrame))
        _unseenMentionsView.frame = entry->mentionFrame;
    if (entry->deliveryErrorVisible && _deliveryErrorBackgrond != nil && !CGRectEqualToRect(_deliveryErrorBackgrond.frame, entry->deliveryErrorFrame))
        _deliveryErrorBackgrond.frame = entry->deliveryErrorFrame;
    if (!CGRectEqualToRect(_dateLabel.frame, entry->dateFrame))
        _dateLabel.frame = entry->dateFrame;
    if (!CGRectEqualToRect(_deliveredCheckmark.frame, entry->deliveredFrame))
        _deliveredCheckmark.frame = entry->deliveredFrame;
    if (!CGRectEqualToRect(_readCheckmark.frame, entry->readFrame))
        _readCheckmark.frame = entry->readFrame;
    if (_pendingIndicator != nil && !CGRectEqualToRect(_pendingIndicator.frame, entry->pendingFrame))
        _pendingIndicator.frame = entry->pendingFrame;
    _textView.statusFrame = entry->statusFrame;
    _textView.typingFrame = entry->typingFrame;
    if (entry->typingVisible && _typingDotsContainer != nil && !CGRectEqualToRect(_typingDotsContainer.frame, entry->typingDotsFrame))
        _typingDotsContainer.frame = entry->typingDotsFrame;
    if (!CGRectEqualToRect(_textView.authorNameFrame, entry->authorFrame))
        _textView.authorNameFrame = entry->authorFrame;
    if (_verifiedIcon != nil && !CGRectEqualToRect(_verifiedIcon.frame, entry->verifiedFrame))
        _verifiedIcon.frame = entry->verifiedFrame;
    if (_premiumIcon != nil && !CGRectEqualToRect(_premiumIcon.frame, entry->premiumFrame))
        _premiumIcon.frame = entry->premiumFrame;
    if (_muteIcon != nil && !CGRectEqualToRect(_muteIcon.frame, entry->muteFrame))
        _muteIcon.frame = entry->muteFrame;
    _textView.titleFrame = entry->titleFrame;
    _textView.textFrame = entry->messageFrame;
    _validSize = size;
    _fastLayoutSize = self.bounds.size;
    _fastLayoutContentOffset = contentOffset;
    _fastLayoutContentWidth = contentWidth;
}

- (void)storeGeometryForSize:(CGSize)size contentOffset:(CGFloat)contentOffset contentWidth:(CGFloat)contentWidth
{
    if (_conversationId == 0)
        return;
    TGDialogListCellGeometryCacheEntry *entry = [[TGDialogListCellGeometryCacheEntry alloc] init];
    entry->conversationId = _conversationId;
    entry->size = size;
    entry->contentOffset = contentOffset;
    entry->contentWidth = contentWidth;
    entry->presentation = _presentation;
    entry->brandedStyle = TGDialogListBrandedIOS6Style();
    entry->classicStyle = TGDialogListClassicIOS6Style();
    entry->unreadText = [_unreadCountLabel.text ?: @"" copy];
    entry->unreadFont = _unreadCountLabel.font;
    entry->unreadCountHidden = _unreadCountBackgrond.hidden;
    entry->pinnedHidden = _pinnedBackgrond.hidden;
    entry->mentionHidden = _unseenMentionsView.hidden;
    entry->deliveryErrorVisible = _deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil;
    entry->pendingVisible = _pendingIndicator != nil && !_pendingIndicator.hidden;
    entry->deliveryStatusVisible = !_deliveredCheckmark.hidden || !_readCheckmark.hidden || entry->pendingVisible;
    entry->dateText = [_dateLabel.rawDateText ?: @"" copy];
    entry->hasDate = _date != 0;
    entry->isAd = _isAd;
    entry->statusText = [_textView.statusText ?: @"" copy];
    entry->statusFont = _textView.statusFont;
    entry->statusHidden = ![self brandedStatusVisible];
    entry->isEncrypted = _isEncrypted;
    entry->isMuted = _isMuted;
    entry->isVerified = _isVerified;
    entry->premiumVisible = _premiumIcon.superview != nil;
    entry->titleText = [_titleText copy];
    entry->titleFont = _textView.titleFont;
    entry->typingText = [_textView.typingText ?: @"" copy];
    entry->typingFont = _textView.textFont;
    entry->typingVisible = _typingDotsContainer.superview != nil;
    entry->authorName = _authorName;
    entry->hideAuthorName = _hideAuthorName;
    entry->messageText = [_messageText copy];
    entry->renderedMessageText = [_textView.text copy];
    entry->messageFont = _textView.textFont;
    entry->textViewFrame = _textView.frame;
    entry->unreadBackgroundFrame = _unreadCountBackgrond.frame;
    entry->pinnedFrame = _pinnedBackgrond.frame;
    entry->unreadLabelFrame = _unreadCountLabel.frame;
    entry->mentionFrame = _unseenMentionsView.frame;
    entry->deliveryErrorFrame = _deliveryErrorBackgrond == nil ? CGRectZero : _deliveryErrorBackgrond.frame;
    entry->dateFrame = _dateLabel.frame;
    entry->deliveredFrame = _deliveredCheckmark.frame;
    entry->readFrame = _readCheckmark.frame;
    entry->pendingFrame = _pendingIndicator == nil ? CGRectZero : _pendingIndicator.frame;
    entry->statusFrame = _textView.statusFrame;
    entry->typingFrame = _textView.typingFrame;
    entry->typingDotsFrame = _typingDotsContainer == nil ? CGRectZero : _typingDotsContainer.frame;
    entry->authorFrame = _textView.authorNameFrame;
    entry->verifiedFrame = _verifiedIcon == nil ? CGRectZero : _verifiedIcon.frame;
    entry->premiumFrame = _premiumIcon == nil ? CGRectZero : _premiumIcon.frame;
    entry->muteFrame = _muteIcon == nil ? CGRectZero : _muteIcon.frame;
    entry->titleFrame = _textView.titleFrame;
    entry->messageFrame = _textView.textFrame;
    TGDialogListCellGeometryCachePut(entry);
}

- (void)setMessageText:(NSString *)messageText
{
    _sourceMessageText = messageText;
    _messageText = messageText;
}

- (NSString *)messageText
{
    return _sourceMessageText;
}

- (void)setAuthorName:(NSString *)authorName
{
    _sourceAuthorName = authorName;
    _authorName = authorName;
}

- (NSString *)authorName
{
    return _sourceAuthorName;
}

+ (NSDictionary *)preparedPreviewForConversationId:(int64_t)conversationId messageText:(NSString *)messageText attachments:(NSArray *)attachments isSavedMessages:(int)isSavedMessages isGroupChat:(bool)isGroupChat isChannel:(bool)isChannel isChannelGroup:(bool)isChannelGroup isEncrypted:(bool)isEncrypted encryptionStatus:(int)encryptionStatus encryptionOutgoing:(bool)encryptionOutgoing encryptionFirstName:(NSString *)encryptionFirstName
{
    NSString *preparedText = messageText;
    int colorRole = 0;
    bool hideAuthorName = !isGroupChat || (isChannel && !isChannelGroup);
    bool attachmentFound = false;

    if (isSavedMessages == 2)
    {
        preparedText = TGDialogListStartupLocalized(@"DialogList.SavedMessagesHelp");
        colorRole = 1;
    }
    else if (attachments.count != 0)
    {
        for (TGMediaAttachment *attachment in attachments)
        {
            if (attachment.type == TGActionMediaAttachmentType)
                return nil;
            else if (attachment.type == TGImageMediaAttachmentType)
            {
                TGImageMediaAttachment *imageMediaAttachment = (TGImageMediaAttachment *)attachment;
                NSString *caption = preparedText.length > 0 ? preparedText : imageMediaAttachment.caption;
                if (imageMediaAttachment.imageId == 0 && imageMediaAttachment.localImageId == 0)
                {
                    preparedText = TGDialogListStartupLocalized(@"Message.ImageExpired");
                    colorRole = 2;
                }
                else if (caption.length > 0)
                {
                    bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"🖼 "];
                    preparedText = addEmoji ? [@"🖼 " stringByAppendingString:caption] : caption;
                    colorRole = 0;
                }
                else
                {
                    preparedText = TGDialogListStartupLocalized(@"Message.Photo");
                    colorRole = 2;
                }
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGVideoMediaAttachmentType)
            {
                TGVideoMediaAttachment *videoMediaAttachment = (TGVideoMediaAttachment *)attachment;
                NSString *caption = preparedText.length > 0 ? preparedText : videoMediaAttachment.caption;
                if (videoMediaAttachment.videoId == 0 && videoMediaAttachment.localVideoId == 0)
                {
                    preparedText = TGDialogListStartupLocalized(@"Message.VideoExpired");
                    colorRole = 2;
                }
                else if (caption.length > 0)
                {
                    bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"📹 "];
                    preparedText = addEmoji ? [@"📹 " stringByAppendingString:caption] : caption;
                    colorRole = 0;
                }
                else
                {
                    preparedText = videoMediaAttachment.roundMessage ? TGDialogListStartupLocalized(@"Message.VideoMessage") : TGDialogListStartupLocalized(@"Message.Video");
                    colorRole = 2;
                }
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGLocationMediaAttachmentType)
            {
                preparedText = ((TGLocationMediaAttachment *)attachment).period > 0 ? TGDialogListStartupLocalized(@"Message.LiveLocation") : TGDialogListStartupLocalized(@"Message.Location");
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGContactMediaAttachmentType)
            {
                preparedText = TGDialogListStartupLocalized(@"Message.Contact");
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGPollMediaAttachmentType)
            {
                preparedText = [(TGPollMediaAttachment *)attachment previewText];
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGDocumentMediaAttachmentType)
            {
                TGDocumentMediaAttachment *documentAttachment = (TGDocumentMediaAttachment *)attachment;
                NSString *caption = preparedText.length > 0 ? preparedText : documentAttachment.caption;
                bool isAnimated = false;
                bool isSticker = false;
                bool isVoice = false;
                NSString *musicText = nil;
                NSString *stickerRepresentation = nil;
                for (id attribute in documentAttachment.attributes)
                {
                    if ([attribute isKindOfClass:[TGDocumentAttributeAnimated class]])
                        isAnimated = true;
                    else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                    {
                        isSticker = true;
                        stickerRepresentation = ((TGDocumentAttributeSticker *)attribute).alt;
                    }
                    else if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]])
                    {
                        isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                        if (!isVoice)
                        {
                            NSString *artist = ((TGDocumentAttributeAudio *)attribute).performer;
                            NSString *title = ((TGDocumentAttributeAudio *)attribute).title;
                            if (artist.length != 0 && title.length != 0)
                                musicText = [[artist stringByAppendingString:@" — "] stringByAppendingString:title];
                            else if (artist.length != 0)
                                musicText = artist;
                            else if (title.length != 0)
                                musicText = title;
                        }
                    }
                }

                if (TGPeerIdIsSecretChat(conversationId) && [documentAttachment.mimeType isEqualToString:@"video/mp4"] && documentAttachment.size < 1024 * 1024)
                    isAnimated = true;

                if (isSticker)
                {
                    preparedText = stickerRepresentation.length == 0 ? TGDialogListStartupLocalized(@"Message.Sticker") : [[NSString alloc] initWithFormat:@"%@ %@", stickerRepresentation, TGDialogListStartupLocalized(@"Message.Sticker")];
                    colorRole = 0;
                }
                else if (isAnimated)
                {
                    preparedText = TGDialogListStartupLocalized(@"Message.Animation");
                    colorRole = 2;
                }
                else if (isVoice)
                {
                    preparedText = TGDialogListStartupLocalized(@"Message.Audio");
                    colorRole = 2;
                }
                else if (musicText != nil)
                {
                    preparedText = musicText;
                    colorRole = 2;
                }
                else
                {
                    NSString *fileName = documentAttachment.fileName;
                    if (caption.length > 0)
                    {
                        bool addEmoji = ![caption hasPrefix:@"📎 "];
                        preparedText = addEmoji ? [@"📎 " stringByAppendingString:caption] : caption;
                    }
                    else if (fileName.length != 0)
                        preparedText = fileName;
                    else
                        preparedText = TGDialogListStartupLocalized(@"Message.File");
                    colorRole = 2;
                }
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGAudioMediaAttachmentType)
            {
                preparedText = TGDialogListStartupLocalized(@"Message.Audio");
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGGameAttachmentType)
            {
                preparedText = [@"🎮 " stringByAppendingString:((TGGameMediaAttachment *)attachment).title ?: @""];
                colorRole = 2;
                attachmentFound = true;
                break;
            }
            else if (attachment.type == TGInvoiceMediaAttachmentType)
            {
                preparedText = ((TGInvoiceMediaAttachment *)attachment).title ?: @"";
                colorRole = 2;
                attachmentFound = true;
                break;
            }
        }
    }

    if (!attachmentFound && isSavedMessages != 2)
        colorRole = 0;

    if (preparedText.length == 0 && isEncrypted)
    {
        colorRole = 1;
        if (encryptionStatus == 1)
            preparedText = [[NSString alloc] initWithFormat:TGDialogListStartupLocalized(@"DialogList.AwaitingEncryption"), encryptionFirstName ?: @""];
        else if (encryptionStatus == 2)
            preparedText = TGDialogListStartupLocalized(@"DialogList.EncryptionProcessing");
        else if (encryptionStatus == 3)
            preparedText = TGDialogListStartupLocalized(@"DialogList.EncryptionRejected");
        else if (encryptionStatus == 4)
        {
            if (encryptionOutgoing)
                preparedText = [[NSString alloc] initWithFormat:TGDialogListStartupLocalized(@"DialogList.EncryptedChatStartedOutgoing"), encryptionFirstName ?: @""];
            else
                preparedText = [[NSString alloc] initWithFormat:TGDialogListStartupLocalized(@"DialogList.EncryptedChatStartedIncoming"), encryptionFirstName ?: @""];
        }
    }

    return @{ @"text": preparedText ?: @"", @"colorRole": @(colorRole), @"hideAuthor": @(hideAuthorName) };
}

+ (void)prewarmTitleText:(NSString *)titleText messageText:(NSString *)messageText authorName:(NSString *)authorName statusText:(NSString *)statusText width:(CGFloat)width presentation:(TGPresentation *)presentation unread:(bool)unread unreadCount:(int)unreadCount serviceUnreadCount:(int)serviceUnreadCount unreadMark:(bool)unreadMark unreadMentionCount:(int)unreadMentionCount pinned:(bool)pinned muted:(bool)muted verified:(bool)verified premium:(bool)premium deliveryState:(TGMessageDeliveryState)deliveryState dateText:(NSString *)dateText encrypted:(bool)encrypted showsDeliveryStatus:(bool)showsDeliveryStatus branded:(bool)branded classic:(bool)classic
{
    if (presentation == nil || width <= 0.0f)
        return;

    messageText = TGDialogListVisiblePreviewText(messageText);
    CGFloat contentX = branded ? 61.0f : (classic ? 72.0f : 80.0f);
    UIFont *titleFont = branded ? TGBoldSystemFontOfSize(TGDialogListBrandedIOS6TitleFontSize) : TGMediumSystemFontOfSize(16.0f);
    UIFont *bodyFont = TGSystemFontOfSize(branded ? TGDialogListBrandedIOS6BodyFontSize : 15.0f);
    UIFont *badgeFont = branded ? TGBoldSystemFontOfSize(11.0f * TGDialogListBrandedIOS6BadgeScale) : (classic ? TGBoldSystemFontOfSize(12.0f) : TGSystemFontOfSize(14.0f));
    int totalUnreadCount = unreadCount + serviceUnreadCount;
    bool deliveryFailed = deliveryState == TGMessageDeliveryStateFailed;
    bool showBadge = !deliveryFailed && (totalUnreadCount > 0 || unreadMark);
    bool showPinned = !deliveryFailed && !showBadge && pinned;
    bool showMention = !deliveryFailed && unreadMentionCount > 0 && (totalUnreadCount > 0 || unreadMark || unread);
    NSString *badgeText = totalUnreadCount > 0 ? (branded ? [TGPresentation brandedIOS6BadgeTextForCount:totalUnreadCount] : (totalUnreadCount < 1000 ? [NSString stringWithFormat:@"%d", totalUnreadCount] : [NSString stringWithFormat:@"%dK", totalUnreadCount / 1000])) : @"";
    CGFloat badgeTextWidth = badgeText.length == 0 ? 9.0f : TGDialogListCachedTextMetric(badgeText, badgeFont, 0.0f, 1, 0).width;
    CGFloat badgeWidth = branded ? MAX(18.0f * TGDialogListBrandedIOS6BadgeScale, badgeTextWidth + 10.0f * TGDialogListBrandedIOS6BadgeScale) : MAX(20.0f, badgeTextWidth + 11.0f);
    CGFloat statusWidth = branded && statusText.length != 0 ? MIN(103.2f, TGDialogListCachedTextMetric(statusText, bodyFont, 0.0f, 1, 0).width) : 0.0f;
    CGFloat dateFontSize = TGIsPad() ? 15.0f : (branded ? 10.0f : 14.0f);
    UIFont *dateFont = TGSystemFontOfSize(dateFontSize);
    CGSize dateSize = [TGDateLabel measureDateText:dateText dateFont:dateFont textFont:dateFont amWidth:TGIsPad() ? 25.0f : 24.0f pmWidth:TGIsPad() ? 25.0f : 24.0f];
    OGDialogLayoutInput input = {0};
    input.width = width;
    input.contentInset = contentX;
    input.dateOrigin = width - (int)dateSize.width - 11.0f;
    input.statusWidth = statusWidth;
    input.badgeWidth = badgeWidth;
    input.mentionWidth = branded ? TGDialogListBrandedMentionWidth(presentation) : presentation.images.dialogMentionedIcon.size.width;
    input.verifiedWidth = verified ? presentation.images.dialogVerifiedIcon.size.width : 0.0f;
    input.premiumWidth = premium && !verified ? [TGPresentationAssets premiumBadgeIcon:14.0f].size.width : 0.0f;
    input.previewPadding = branded ? TGDialogListBrandedPreviewRightPadding(bodyFont) : 0.0f;
    input.branded = branded;
    input.encrypted = encrypted;
    input.muted = muted;
    input.muteWidth = presentation.images.dialogMutedIcon.size.width;
    input.unreadBadge = showBadge;
    input.pinned = showPinned;
    input.mention = showMention;
    input.deliveryError = deliveryFailed;
    input.deliveryStatus = showsDeliveryStatus;
    OGDialogHorizontalLayout geometry = OGDialogHorizontalLayoutMake(input);
    CGFloat titleTextWidth = TGDialogListRenderedSingleLineWidth(titleText, titleFont);
    if (iosMajorVersion() <= 3 && TGDialogListRequiresPackEmoji(titleText))
    {
        TGDialogListLegacyTextLayout *layout = TGDialogListLegacyTextLayoutForText(titleText, titleFont, geometry.maximumTitleWidth, 1);
        TGDialogListLegacyTextLine *line = layout.lines.count == 0 ? nil : layout.lines[0];
        titleTextWidth = line.width;
    }
    CGFloat titleWidth = OGDialogTitleWidth(geometry, titleTextWidth);
    if (iosMajorVersion() <= 3 && TGDialogListRequiresPackEmoji(titleText))
        TGDialogListLegacyTextLayoutForText(titleText, titleFont, titleWidth, 1);
    else if (iosMajorVersion() > 3)
        TGDialogListTextLayout(titleText, titleFont, titleWidth, 1, NSTextAlignmentLeft);

    NSUInteger maxLines = branded ? (authorName.length == 0 ? 2 : 1) : 2;
    if (iosMajorVersion() <= 3 && TGDialogListRequiresPackEmoji(messageText))
        TGDialogListLegacyTextLayoutForText(messageText, bodyFont, geometry.previewWidth, maxLines);
    else if (iosMajorVersion() <= 3)
        TGDialogListCachedTextMetric(messageText, bodyFont, geometry.previewWidth, maxLines, 1);
    else
        TGDialogListTextLayout(messageText, bodyFont, geometry.previewWidth, maxLines, NSTextAlignmentLeft);
    if (authorName.length != 0)
    {
        if (iosMajorVersion() <= 3 && TGDialogListRequiresPackEmoji(authorName))
            TGDialogListLegacyTextLayoutForText(authorName, bodyFont, geometry.authorWidth, 1);
        else if (iosMajorVersion() > 3)
        {
            NSTextAlignment alignment = branded || iosMajorVersion() >= 7 ? NSTextAlignmentLeft : NSTextAlignmentRight;
            TGDialogListTextLayout(authorName, bodyFont, geometry.authorWidth, 1, alignment);
        }
    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier assetsSource:(id<TGDialogListCellAssetsSource>)assetsSource
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
    {
        if (iosMajorVersion() >= 7)
        {
            self.contentView.superview.clipsToBounds = false;
        }
        
        if (iosMajorVersion() <= 6) {
            _separatorLayer = [[CALayer alloc] init];
            _separatorLayer.backgroundColor = TGSeparatorColor().CGColor;
            [self.layer addSublayer:_separatorLayer];
        }
        
        _wrapView = [[TGDialogListCellEditingControls alloc] init];
        _wrapView.clipsToBounds = true;
        [self addSubview:_wrapView];
        
        __weak TGDialogListCell *weakSelf = self;
        _wrapView.requestDelete = ^{
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_deleteConversation) {
                    strongSelf->_deleteConversation(strongSelf->_conversationId);
                }
            }
        };
        _wrapView.toggleMute = ^(bool mute) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_toggleMuteConversation) {
                    strongSelf->_toggleMuteConversation(strongSelf->_conversationId, mute);
                }
            }
        };
        _wrapView.togglePinned = ^(bool pin) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_togglePinConversation) {
                    strongSelf->_togglePinConversation(strongSelf->_conversationId, pin);
                }
            }
        };
        _wrapView.toggleGrouped = ^(bool group) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_toggleGroupConversation) {
                    strongSelf->_toggleGroupConversation(strongSelf->_conversationId, group);
                }
            }
        };
        _wrapView.toggleRead = ^(bool read) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0) {
                if (strongSelf->_toggleReadConversation) {
                    strongSelf->_toggleReadConversation(strongSelf->_conversationId, read);
                }
            }
        };
        _wrapView.openCommunity = ^{
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0 && strongSelf->_linkedCommunityId != 0 && strongSelf->_openCommunity) {
                strongSelf->_openCommunity(strongSelf->_conversationId);
            }
        };
        _wrapView.toggleArchived = ^(bool archived) {
            __strong TGDialogListCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_conversationId != 0 && strongSelf->_toggleArchiveConversation) {
                strongSelf->_toggleArchiveConversation(strongSelf->_conversationId, archived);
            }
        };
        
        UIView *selectedView = [[UIView alloc] init];
        self.selectedBackgroundView = selectedView;
        
        _assetsSource = assetsSource;

        _textView = [[TGDialogListTextView alloc] initWithFrame:CGRectMake(73, 2, self.frame.size.width - 73, 46)];
        _textView.contentMode = UIViewContentModeLeft;
        _textView.titleFont = TGDialogListBrandedIOS6Style() ? TGBoldSystemFontOfSize(TGDialogListBrandedIOS6TitleFontSize) : TGMediumSystemFontOfSize(16.0f);
        _textView.textFont = TGSystemFontOfSize(TGDialogListBrandedIOS6Style() ? TGDialogListBrandedIOS6BodyFontSize : 15.0f);
        _textView.authorNameFont = TGSystemFontOfSize(TGDialogListBrandedIOS6Style() ? TGDialogListBrandedIOS6BodyFontSize : 15.0f);
        _textView.opaque = false;
        _textView.backgroundColor = nil;
        
        [_wrapView addSubview:_textView];
        
        _dateString = [[NSMutableString alloc] initWithCapacity:16];
        
        CGFloat dateFontSize = TGDialogListBrandedIOS6Style() ? 10.0f : 14.0f;
        CGFloat amWidth = 24.0f;
        if (TGIsPad())
        {
            dateFontSize = 15.0f;
            amWidth = 25.0f;
        }
        
        _dateLabel = [[TGDateLabel alloc] init];
        _dateLabel.amWidth = amWidth;
        _dateLabel.pmWidth = amWidth;
        _dateLabel.dstOffset = 0.0f;
        _dateLabel.dateFont = TGSystemFontOfSize(dateFontSize);
        _dateLabel.dateTextFont = TGSystemFontOfSize(dateFontSize);
        _dateLabel.dateLabelFont = TGSystemFontOfSize(dateFontSize);
        _dateLabel.textColor = UIColorRGB(0x595959);
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.opaque = false;
        [_wrapView addSubview:_dateLabel];
        
        bool fadeTransition = cpuCoreCount() > 1;
        
        CGFloat avatarSize = TGDialogListAvatarSize();
        CGFloat avatarX = TGDialogListAvatarInset();
        CGFloat avatarY = TGDialogListBrandedIOS6Style() ? 5.0f : (TGDialogListClassicIOS6Style() ? 12.0f : 7.0f);
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(avatarX, avatarY, avatarSize, avatarSize)];
        [_avatarView setSingleFontSize:TGDialogListBrandedIOS6Style() ? 21.0f : (TGDialogListClassicIOS6Style() ? 24.0f : 28.0f) doubleFontSize:TGDialogListBrandedIOS6Style() ? 16.0f : (TGDialogListClassicIOS6Style() ? 18.0f : 21.0f) useBoldFont:false];
        if (TGDialogListClassicIOS6Style())
        {
            _avatarView.clipsToBounds = true;
            _avatarView.layer.cornerRadius = TGDialogListBrandedIOS6Style() ? 8.0f : 7.0f;
        }
        _avatarView.fadeTransition = fadeTransition;
        [_wrapView addSubview:_avatarView];

        
        _unreadCountLabel = [[TGLabel alloc] initWithFrame:CGRectMake(0, 0, 50, 20)];
        _unreadCountLabel.textColor = [UIColor whiteColor];
        _unreadCountLabel.font = TGSystemFontOfSize(14);
        
        [_wrapView addSubview:_unreadCountLabel];
        
        _unreadCountLabel.backgroundColor = [UIColor clearColor];
        
        _validSize = CGSizeZero;
    }
    return self;
}

- (void)dealloc
{
    [_avatarView cancelLoading];
    
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
}

- (void)setPresentation:(TGPresentation *)presentation
{
    bool reset = _presentation != nil;
    if (presentation == _presentation)
        return;
    
    _presentation = presentation;
    _textView.titleFont = TGDialogListBrandedIOS6Style() ? TGBoldSystemFontOfSize(TGDialogListBrandedIOS6TitleFontSize) : TGMediumSystemFontOfSize(16.0f);
    _textView.textFont = TGSystemFontOfSize(TGDialogListBrandedIOS6Style() ? TGDialogListBrandedIOS6BodyFontSize : 15.0f);
    _textView.authorNameFont = _textView.textFont;
    CGFloat dateFontSize = TGIsPad() ? 15.0f : (TGDialogListBrandedIOS6Style() ? 10.0f : 14.0f);
    _dateLabel.dateFont = TGSystemFontOfSize(dateFontSize);
    _dateLabel.dateTextFont = _dateLabel.dateFont;
    _dateLabel.dateLabelFont = _dateLabel.dateFont;
    _validSize = CGSizeZero;
    
    if (TGDialogListClassicIOS6Style())
    {
        bool darkStyle = presentation.pallete.isDark;
        self.backgroundColor = darkStyle ? presentation.pallete.backgroundColor : [UIColor whiteColor];
        self.selectedBackgroundView.backgroundColor = darkStyle ? presentation.pallete.selectionColor : UIColorRGB(0xd8e5f1);
        _separatorLayer.backgroundColor = darkStyle ? [UIColor clearColor].CGColor : UIColorRGB(0xd4d4d4).CGColor;
        _separatorLayer.hidden = darkStyle;
        if (TGDialogListBrandedIOS6Style())
        {
            CGFloat badgeFontSize = 11.0f * TGDialogListBrandedIOS6BadgeScale;
            UIFont *badgeFont = TGBoldSystemFontOfSize(badgeFontSize);
            _unreadCountLabel.font = badgeFont != nil ? badgeFont : TGBoldSystemFontOfSize(badgeFontSize);
            _unreadCountLabel.shadowColor = [UIColor clearColor];
            _unreadCountLabel.shadowOffset = CGSizeZero;
        }
        else
        {
            _unreadCountLabel.font = TGBoldSystemFontOfSize(12.0f);
            _unreadCountLabel.shadowColor = UIColorRGBA(0x000000, 0.55f);
            _unreadCountLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        }
        _unreadCountLabel.textColor = [UIColor whiteColor];
    }
    else
    {
        self.backgroundColor = presentation.pallete.backgroundColor;
        self.selectedBackgroundView.backgroundColor = presentation.pallete.selectionColor;
        _separatorLayer.backgroundColor = presentation.pallete.barSeparatorColor.CGColor;
        _separatorLayer.hidden = false;
        _unreadCountLabel.font = TGSystemFontOfSize(14.0f);
        _unreadCountLabel.shadowColor = [UIColor clearColor];
        _unreadCountLabel.shadowOffset = CGSizeZero;
    }
    
    _textView.presentation = presentation;
    [_textView setNeedsDisplay];
    
    CGFloat brandedBadgeHeight = 18.0f * TGDialogListBrandedIOS6BadgeScale;
    UIImage *brandedBadgeImage = [TGPresentation brandedIOS6ShadowedBadgeImageForWidth:brandedBadgeHeight height:brandedBadgeHeight];
    _unreadBackgroundImage = TGDialogListBrandedIOS6Style() ? brandedBadgeImage : presentation.images.dialogBadgeImage;
    _unreadMutedBackgroundImage = TGDialogListBrandedIOS6Style() ? brandedBadgeImage : presentation.images.dialogMutedBadgeImage;
    
    bool resetButtons = _wrapView.presentation != nil && presentation != _wrapView.presentation;
    _wrapView.presentation = presentation;
    if (resetButtons)
        [_wrapView resetButtons];
    
    if (_unreadCountBackgrond == nil)
    {
        _unreadCountBackgrond = [[TGSimpleImageView alloc] initWithImage:_unreadBackgroundImage];
        [_wrapView addSubview:_unreadCountBackgrond];
        
        [_unreadCountLabel.superview bringSubviewToFront:_unreadCountLabel];
    }
    else
    {
        _unreadCountBackgrond.image = _unreadBackgroundImage;
    }
    _unreadCountBackgrond.contentMode = TGDialogListBrandedIOS6Style() ? UIViewContentModeCenter : UIViewContentModeScaleToFill;
    
    if (_unseenMentionsView == nil)
    {
        _unseenMentionsView = [[TGSimpleImageView alloc] initWithImage:TGDialogListBrandedIOS6Style() ? presentation.images.dialogBrandedMentionIcon : presentation.images.dialogMentionedIcon];
        [_wrapView addSubview:_unseenMentionsView];
    }
    else
    {
        _unseenMentionsView.image = TGDialogListBrandedIOS6Style() ? presentation.images.dialogBrandedMentionIcon : presentation.images.dialogMentionedIcon;
    }
    
    if (_pinnedBackgrond == nil)
    {
        _pinnedBackgrond = [[TGSimpleImageView alloc] initWithImage:TGDialogListBrandedIOS6Style() ? presentation.images.dialogBrandedPinIcon : presentation.images.dialogPinnedIcon];
        [_wrapView addSubview:_pinnedBackgrond];
    }
    else
    {
        _pinnedBackgrond.image = TGDialogListBrandedIOS6Style() ? presentation.images.dialogBrandedPinIcon : presentation.images.dialogPinnedIcon;
    }

    if (TGDialogListBrandedIOS6Style())
    {
        if (_brandedDisclosureView == nil)
        {
            _brandedDisclosureView = [[TGSimpleImageView alloc] initWithImage:presentation.images.dialogBrandedDisclosureIcon];
            [_wrapView addSubview:_brandedDisclosureView];
        }
        _brandedDisclosureView.hidden = false;
        _dateLabel.textColor = [TGPresentation brandedIOS6DialogListAppearance].dateColor;
    }
    else
    {
        _brandedDisclosureView.hidden = true;
    }

    if (TGDialogListBrandedIOS6Style())
    {
        _textView.statusFont = TGSystemFontOfSize(TGDialogListBrandedIOS6BodyFontSize);
        _textView.statusColor = [TGPresentation brandedIOS6DialogListAppearance].statusColor;
        _textView.statusText = _statusText;

        if (_brandedAvatarOverlayView == nil)
        {
            _brandedAvatarOverlayView = [[UIImageView alloc] initWithFrame:_avatarView.bounds];
            _brandedAvatarOverlayView.userInteractionEnabled = false;
            _brandedAvatarOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_avatarView addSubview:_brandedAvatarOverlayView];
        }
        _brandedAvatarOverlayView.image = [TGPresentation brandedIOS6DialogAvatarOverlayImageForSize:_avatarView.bounds.size];
        _brandedAvatarOverlayView.hidden = false;
    }
    else
    {
        _textView.statusText = nil;
        _textView.statusFrame = CGRectZero;
        _brandedAvatarOverlayView.hidden = true;
    }
    
    _muteIcon.image = presentation.images.dialogMutedIcon;
    _deliveryErrorBackgrond.image = presentation.images.dialogUnsentIcon;
    _pendingIndicator.image = presentation.images.dialogPendingIcon;
    _verifiedIcon.image = presentation.images.dialogVerifiedIcon;
    _premiumIcon.image = [TGPresentationAssets premiumBadgeIcon:14.0f];
    
    if (_deliveredCheckmark == nil)
    {
        _deliveredCheckmark = [[TGSimpleImageView alloc] initWithImage:presentation.images.dialogDeliveredIcon];
        [_wrapView addSubview:_deliveredCheckmark];
    }
    else
    {
        _deliveredCheckmark.image = presentation.images.dialogDeliveredIcon;
    }
    
    if (_readCheckmark == nil)
    {
        _readCheckmark = [[TGSimpleImageView alloc] initWithImage:presentation.images.dialogReadIcon];
        [_wrapView addSubview:_readCheckmark];
    }
    else
    {
        _readCheckmark.image = presentation.images.dialogReadIcon;
    }
    
    if (reset)
        [self resetView:false];
}

- (void)prepareForReuse
{
    [self stopTypingAnimation];
    _fastScrolling = false;
    [_wrapView setExpanded:false animated:false];
    
    [super prepareForReuse];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    bool wasSelected = self.selected;
    
    [super setSelected:selected animated:animated];
    [self updateTextBackdrop];
    
    if ((selected && !wasSelected))
    {
        [self adjustOrdering];
    }
    
    if ((selected && !wasSelected) || (!selected && wasSelected))
    {
        UIView *selectedView = self.selectedBackgroundView;
        if (selectedView != nil && (self.selected || self.highlighted))
        {
            CGFloat separatorHeight = TGScreenPixel;
            selectedView.frame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, self.frame.size.height + separatorHeight);
        }
        
        if (TGIsPad() && _separatorLayer != nil)
        {
            bool hidden = (TGDialogListClassicIOS6Style() && _presentation.pallete.isDark) || self.selected || self.highlighted;
            if (_separatorLayer.hidden != hidden)
            {
                [CATransaction begin];
                [CATransaction setDisableActions:true];
                _separatorLayer.hidden = hidden;
                [CATransaction commit];
            }
        }
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    bool wasHighlighted = self.highlighted;
    
    [super setHighlighted:highlighted animated:animated];
    [self updateTextBackdrop];
    
    if ((highlighted && !wasHighlighted))
    {
        [self adjustOrdering];
    }
    
    if ((highlighted && !wasHighlighted) || (!highlighted && wasHighlighted))
    {
        UIView *selectedView = self.selectedBackgroundView;
        if (selectedView != nil && (self.selected || self.highlighted))
        {
            CGFloat separatorHeight = TGScreenPixel;
            selectedView.frame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, self.frame.size.height + separatorHeight);
        }
        
        if (TGIsPad() && _separatorLayer != nil)
        {
            bool hidden = (TGDialogListClassicIOS6Style() && _presentation.pallete.isDark) || self.selected || self.highlighted;
            if (_separatorLayer.hidden != hidden)
            {
                [CATransaction begin];
                [CATransaction setDisableActions:true];
                _separatorLayer.hidden = hidden;
                [CATransaction commit];
            }
        }
    }
}

- (void)adjustOrdering
{
    UIView *selectedView = self.selectedBackgroundView;
    if (selectedView != nil)
    {
        CGFloat separatorHeight = TGScreenPixel;
        selectedView.frame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, self.frame.size.height + separatorHeight);
    }
    
    if ([self.superview isKindOfClass:[UITableView class]])
    {
        Class UITableViewCellClass = [UITableViewCell class];
        Class UISearchBarClass = [UISearchBar class];
        int maxCellIndex = 0;
        int index = -1;
        int selfIndex = 0;
        for (UIView *view in self.superview.subviews)
        {
            index++;
            if ([view isKindOfClass:UITableViewCellClass] || [view isKindOfClass:UISearchBarClass])
            {
                maxCellIndex = index;
                
                if (view == self)
                    selfIndex = index;
            }
        }
        
        if (selfIndex < maxCellIndex)
        {
            [self.superview insertSubview:self atIndex:maxCellIndex];
        }
    }
}

- (void)setFastScrolling:(bool)fastScrolling
{
    if (_fastScrolling == fastScrolling)
        return;

    _fastScrolling = fastScrolling;
}

- (void)refreshEditingControls
{
    if (_isSavedMessages == 2 || _isAd)
    {
        [_wrapView setLeftButtonTypes:@[] rightButtonTypes:@[]];
    }
    else
    {
        bool groupable = _isChannel && !_isChannelGroup;
        [_wrapView setLeftButtonTypes:_linkedCommunityId != 0 ? @[@(TGDialogListCellEditingControlsCommunity)] : @[] rightButtonTypes:editingButtonTypes(_isMuted, !_isFeedChannels, _pinnedToTop, !_isEncrypted && !_isSavedMessages && !_isFeed, groupable, _groupedInFeed, _isArchived, _isAd)];
    }
}

#if defined(ONEGRAM_DIAGNOSTICS)
- (NSString *)diagnosticState
{
    CGRect cellFrame = self.frame;
    CGRect wrapFrame = _wrapView.frame;
    CGRect textFrame = _textView.frame;
    CGRect avatarFrame = _avatarView.frame;
    return [[NSString alloc] initWithFormat:@"peer=%lld tag=%d title=%d cell=%.0f,%.0f,%.0f,%.0f h=%d a=%.2f content=%d/%.2f wrap=%.0f,%.0f,%.0f,%.0f h=%d a=%.2f super=%d expanded=%d text=%.0f,%.0f,%.0f,%.0f h=%d a=%.2f contents=%d super=%d avatar=%.0f,%.0f,%.0f,%.0f h=%d a=%.2f image=%d fast=%d", _conversationId, self.reuseTag != 0 ? 1 : 0, (int)self.titleText.length, cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height, self.hidden ? 1 : 0, self.alpha, self.contentView.hidden ? 1 : 0, self.contentView.alpha, wrapFrame.origin.x, wrapFrame.origin.y, wrapFrame.size.width, wrapFrame.size.height, _wrapView.hidden ? 1 : 0, _wrapView.alpha, _wrapView.superview != nil ? 1 : 0, [_wrapView isExpanded] ? 1 : 0, textFrame.origin.x, textFrame.origin.y, textFrame.size.width, textFrame.size.height, _textView.hidden ? 1 : 0, _textView.alpha, _textView.layer.contents != nil ? 1 : 0, _textView.superview != nil ? 1 : 0, avatarFrame.origin.x, avatarFrame.origin.y, avatarFrame.size.width, avatarFrame.size.height, _avatarView.hidden ? 1 : 0, _avatarView.alpha, _avatarView.image != nil ? 1 : 0, _fastScrolling ? 1 : 0];
}
#endif

- (void)resumeDeferredContent
{
    if (_fastScrolling || self.reuseTag == 0)
        return;

    [self refreshEditingControls];

    if (_isFeed)
    {
        UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:29.0f];
        NSInteger index = 0;
        for (NSString *uri in _feedAvatarUrls)
        {
            TGLetteredAvatarView *avatarView = [self dequeueAvatarViewForIndex:index];
            if (uri.length == 0)
            {
                [avatarView loadGroupPlaceholderWithSize:CGSizeMake(29.0f, 29.0f) conversationId:[_feedChatIds[index] longLongValue] title:_feedChatTitles[index] placeholder:placeholder];
            }
            else if (![avatarView.currentUrl isEqualToString:uri])
            {
                [avatarView loadImage:uri filter:@"circle:29x29" placeholder:(avatarView.currentImage != nil ? avatarView.currentImage : placeholder)];
            }
            index++;
        }
        return;
    }

    if (_isSavedMessages || _avatarUrl.length == 0 || _hasExplicitContent)
        return;

    CGFloat avatarSize = TGDialogListAvatarSize();
    NSString *avatarFilter = TGDialogListBrandedIOS6Style() ? @"scale:50x50" : (TGDialogListClassicIOS6Style() ? @"scale:52x52" : @"circle:62x62");
    if (![_avatarView.currentUrl isEqualToString:_avatarUrl])
    {
        UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:avatarSize];
        [_avatarView loadImage:_avatarUrl filter:avatarFilter placeholder:(_avatarView.currentImage != nil ? _avatarView.currentImage : placeholder) forceFade:false];
    }
}

- (void)setTypingString:(NSString *)typingString
{
    [self setTypingString:typingString animated:false];
}

- (void)setTypingString:(NSString *)typingString animated:(bool)__unused animated
{
    _typingString = typingString;
    
    if (((_textView.typingText == nil) != (typingString == nil)) || (typingString != nil) != _textView.showTyping || ![_textView.typingText isEqualToString:typingString])
    {
        _textView.showTyping = typingString != nil;
        _textView.typingText = typingString;
        
        if (typingString != nil)
            [self startTypingAnimation:false];
        else
            [self stopTypingAnimation];
        
        [_textView setNeedsDisplay];
        _validSize = CGSizeZero;
        [self setNeedsLayout];
    }
}

- (void)collectCachedPhotos:(NSMutableDictionary *)dict
{
    [_avatarView tryFillCache:dict];
}

- (UIView *)typingDotsContainer
{
    if (_typingDotsContainer == nil)
    {
        _typingDotsContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        
        for (int i = 0; i < 3; i++)
        {
            UILabel *typingDot = [[UILabel alloc] init];
            typingDot.tag = 100 + i;
            typingDot.text = @".";
            typingDot.textColor = _presentation.pallete.dialogTextColor;
            typingDot.font = _textView.textFont;
            typingDot.backgroundColor = [UIColor clearColor];
            typingDot.frame = CGRectMake(4 * i, 0, 4, 10);
            typingDot.alpha = i == 0 ? 0.0f : 0.0f;
            
            [_typingDotsContainer addSubview:typingDot];
        }
    }
    
    return _typingDotsContainer;
}

- (void)restartAnimations:(bool)force
{
    if (_animatingTyping)
    {
        _animatingTyping = false;
        
        if (_typingDotsTimer != nil)
        {
            [_typingDotsTimer invalidate];
            _typingDotsTimer = nil;
        }
    }
    
    if (_textView.showTyping)
        [self startTypingAnimation:force];
}

- (void)stopAnimations
{
    [self stopTypingAnimation];
}

- (void)startTypingAnimation:(bool)force
{
    if (!_animatingTyping)
    {
        UIView *typingDotsContainer = [self typingDotsContainer];
        
        _animatingTyping = true;
        
        if (typingDotsContainer.superview == nil)
        {
            [_wrapView addSubview:typingDotsContainer];
            _validSize = CGSizeZero;
            [self layoutSubviews];
        }
        
        if (self.window != nil)
        {
            UIApplicationState state = [UIApplication sharedApplication].applicationState;
            if (state == UIApplicationStateActive || state == UIApplicationStateInactive || force)
                [self _loopTypingAnimation];
        }
    }
}

- (void)stopTypingAnimation
{
    if (_animatingTyping)
    {
        _animatingTyping = false;
        
        if (_typingDotsTimer != nil)
        {
            [_typingDotsTimer invalidate];
            _typingDotsTimer = nil;
        }
        
        [_typingDotsContainer removeFromSuperview];
    }
}

- (void)_loopTypingAnimation
{
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
    
    _typingDotsAnimationStep = 0;
    [self _typingAnimationStep];
}

- (void)_typingAnimationStep
{
    if (_typingDotsTimer != nil)
    {
        [_typingDotsTimer invalidate];
        _typingDotsTimer = nil;
    }
    
    _typingDotsAnimationStep++;
    
    for (UIView *dotView in _typingDotsContainer.subviews)
    {
        if (dotView.tag >= 100)
        {
            int dotIndex = (int)(dotView.tag - 100);
            if (TGIsRTL())
                dotIndex = 2 - dotIndex;
            
            dotView.alpha = dotIndex < (_typingDotsAnimationStep - 1) ? 1.0f : 0.0f;
        }
    }
    
    if (_typingDotsAnimationStep > 3)
    {
        _typingDotsTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(_loopTypingAnimation) interval:0.22 repeat:false];
    }
    else
    {
        _typingDotsTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(_typingAnimationStep) interval:_typingDotsAnimationStep == 1 ? 0.22 : 0.12 repeat:false];
    }
}

static NSArray *editingButtonTypes(bool muted, bool pinnable, bool pinned, bool mutable, bool groupable, bool grouped, bool archived, bool isAd) {
    if (TGDialogListBrandedIOS6Style())
    {
        NSMutableArray *buttons = [[NSMutableArray alloc] init];
        if (!isAd)
            [buttons addObject:archived ? @(TGDialogListCellEditingControlsUnarchive) : @(TGDialogListCellEditingControlsArchive)];
        if (pinnable && !isAd)
            [buttons addObject:pinned ? @(TGDialogListCellEditingControlsUnpin) : @(TGDialogListCellEditingControlsPin)];
        if (mutable && !isAd && !muted)
            [buttons addObject:@(TGDialogListCellEditingControlsMute)];
        if (!isAd)
            [buttons addObject:@(TGDialogListCellEditingControlsDelete)];
        return buttons;
    }

    static dispatch_once_t onceToken;
    static NSMutableDictionary *buttonTypes;
    dispatch_once(&onceToken, ^{
        buttonTypes = [[NSMutableDictionary alloc] init];
    });
    
    TGDialogListCellEditingControlButton key = 0;
    if (pinnable && !isAd)
        key |= pinned ? TGDialogListCellEditingControlsUnpin : TGDialogListCellEditingControlsPin;
    
    if (mutable && !isAd && !muted)
        key |= TGDialogListCellEditingControlsMute;
    
    if (groupable && !isAd)
        key |= grouped ? TGDialogListCellEditingControlsUngroup : TGDialogListCellEditingControlsGroup;
    
    if (!isAd) {
        key |= archived ? TGDialogListCellEditingControlsUnarchive : TGDialogListCellEditingControlsArchive;
        key |= TGDialogListCellEditingControlsDelete;
    }

    if (buttonTypes[@(key)] != nil)
        return buttonTypes[@(key)];
    
    NSMutableArray *buttons = [[NSMutableArray alloc] init];
    if (pinnable && !isAd)
        [buttons addObject:pinned ? @(TGDialogListCellEditingControlsUnpin) : @(TGDialogListCellEditingControlsPin)];
    
    if (mutable && !isAd && !muted)
        [buttons addObject:@(TGDialogListCellEditingControlsMute)];
    
    
    if (!isAd)
        [buttons addObject:archived ? @(TGDialogListCellEditingControlsUnarchive) : @(TGDialogListCellEditingControlsArchive)];
    [buttons addObject:@(TGDialogListCellEditingControlsDelete)];
    
    buttonTypes[@(key)] = buttons;
    return buttons;
}

- (UIImage *)brandedBackgroundImage
{
    if (!TGDialogListBrandedIOS6Style())
        return nil;
    return _presentation.images.dialogBrandedBackgroundImage;
}

- (void)updateBrandedBackground
{
    UIImage *image = [self brandedBackgroundImage];
    if (image == nil)
    {
        if (_brandedBackgroundView != nil && self.backgroundView == _brandedBackgroundView)
            self.backgroundView = nil;
        return;
    }
    if (_brandedBackgroundView == nil)
    {
        _brandedBackgroundView = [[UIImageView alloc] init];
        _brandedBackgroundView.opaque = true;
        _brandedBackgroundView.userInteractionEnabled = false;
    }
    if (_brandedBackgroundView.image != image)
        _brandedBackgroundView.image = image;
    if (self.backgroundView != _brandedBackgroundView)
        self.backgroundView = _brandedBackgroundView;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    [self updateTextBackdrop];
}

- (void)updateTextBackdrop
{
    UIColor *color = nil;
    UIImage *image = nil;
    CGRect imageFrame = CGRectZero;
    if (!self.highlighted && !self.selected && !self.editing)
    {
        UIColor *backgroundColor = self.backgroundColor;
        CGColorRef backgroundCGColor = backgroundColor.CGColor;
        if (backgroundCGColor != NULL && CGColorGetPattern(backgroundCGColor) == NULL && CGColorGetAlpha(backgroundCGColor) >= 1.0f)
        {
            color = backgroundColor;
            if (_brandedBackgroundView != nil && self.backgroundView == _brandedBackgroundView)
            {
                CGRect textFrame = _textView.frame;
                CGRect backgroundFrame = _brandedBackgroundView.frame;
                image = _brandedBackgroundView.image;
                imageFrame = CGRectMake(0.0f, backgroundFrame.origin.y - _wrapView.frame.origin.y - textFrame.origin.y, textFrame.size.width, backgroundFrame.size.height);
            }
        }
    }
    [_textView setBackdropColor:color image:image imageFrame:imageFrame];
}

- (UIColor *)preferredBackgroundColor
{
    if ([self brandedBackgroundImage] != nil)
        return [TGPresentation brandedIOS6DialogCellBackgroundColor];
    return _pinnedToTop || _isAd || _isSavedMessages == 2 ? _presentation.pallete.dialogPinnedBackgroundColor : _presentation.pallete.backgroundColor;
}

- (void)resetView:(bool)keepState
{
    NSString *sourceMessageText = _sourceMessageText;
    NSString *sourceAuthorName = _sourceAuthorName;
    bool brandedStyle = TGDialogListBrandedIOS6Style();
    bool classicStyle = TGDialogListClassicIOS6Style();
    bool presentationChanged = !_hasResetSnapshot || _resetPresentation != _presentation || _resetBrandedStyle != brandedStyle || _resetClassicStyle != classicStyle;
    bool previewDirty = !_hasResetSnapshot || presentationChanged || _resetSourceConversationId != _conversationId || _resetSourceIsSavedMessages != _isSavedMessages || _resetSourceEncryptionStatus != _encryptionStatus || _resetSourceIsGroupChat != _isGroupChat || _resetSourceRawText != _rawText || _resetSourceIsChannel != _isChannel || _resetSourceIsChannelGroup != _isChannelGroup || _resetSourceIsEncrypted != _isEncrypted || _resetSourceEncryptionOutgoing != _encryptionOutgoing || _resetSourceAuthorIsSelf != _authorIsSelf || _resetSourceOutgoing != _outgoing || !TGDialogListObjectsEqual(_resetSourceMessageText, sourceMessageText) || !TGDialogListObjectsEqual(_resetSourceMessageAttachments, _messageAttachments) || !TGDialogListObjectsEqual(_resetSourcePreparedPreview, _preparedPreview) || !TGDialogListObjectsEqual(_resetSourceUsers, _users) || !TGDialogListObjectsEqual(_resetSourceAuthorName, sourceAuthorName) || !TGDialogListObjectsEqual(_resetSourceEncryptionFirstName, _encryptionFirstName);
    bool avatarDirty = !_hasResetSnapshot || presentationChanged || _resetAvatarConversationId != _conversationId || _resetAvatarIsSavedMessages != _isSavedMessages || _resetAvatarEncryptedUserId != _encryptedUserId || _resetAvatarIsFeed != _isFeed || _resetAvatarHasExplicitContent != _hasExplicitContent || _resetAvatarIsEncrypted != _isEncrypted || _resetAvatarIsBroadcast != _isBroadcast || !TGDialogListObjectsEqual(_resetAvatarUrl, _avatarUrl) || !TGDialogListObjectsEqual(_resetAvatarTitleLetters, _titleLetters) || !TGDialogListObjectsEqual(_resetFeedChatIds, _feedChatIds) || !TGDialogListObjectsEqual(_resetFeedChatTitles, _feedChatTitles) || !TGDialogListObjectsEqual(_resetFeedAvatarUrls, _feedAvatarUrls) || !TGDialogListObjectsEqual(_resetAvatarTitleText, _titleText);
    bool needsTextDisplay = false;
    bool needsLayout = false;

    if (self.selectionStyle != UITableViewCellSelectionStyleBlue)
        self.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    int totalUnreadCount = _unreadCount + _serviceUnreadCount;
    uint32_t editingControlsState = 0;
    editingControlsState |= (_isSavedMessages == 2 ? 1u : 0u) << 0;
    editingControlsState |= (_isAd ? 1u : 0u) << 1;
    editingControlsState |= (_isMuted ? 1u : 0u) << 2;
    editingControlsState |= (_isFeedChannels ? 1u : 0u) << 3;
    editingControlsState |= (_pinnedToTop ? 1u : 0u) << 4;
    editingControlsState |= (_isEncrypted ? 1u : 0u) << 5;
    editingControlsState |= (_isSavedMessages ? 1u : 0u) << 6;
    editingControlsState |= (_isFeed ? 1u : 0u) << 7;
    editingControlsState |= (_isChannel ? 1u : 0u) << 8;
    editingControlsState |= (_isChannelGroup ? 1u : 0u) << 9;
    editingControlsState |= (_groupedInFeed ? 1u : 0u) << 10;
    editingControlsState |= (_isArchived ? 1u : 0u) << 11;
    editingControlsState |= (_linkedCommunityId != 0 ? 1u : 0u) << 12;

    if (!_fastScrolling && (!_editingControlsStateValid || _editingControlsState != editingControlsState))
    {
        [self refreshEditingControls];
        _editingControlsState = editingControlsState;
        _editingControlsStateValid = true;
    }
    
    UIColor *backgroundColor = [self preferredBackgroundColor];
    if (![self.backgroundColor isEqual:backgroundColor])
        self.backgroundColor = backgroundColor;
    [self updateBrandedBackground];
    [self updateTextBackdrop];
    
    int currentDate = (int)[[TGTelegramNetworking instance] approximateRemoteTime];
    NSString *dateString = _date == 0 || _isSavedMessages == 2 ? nil : [TGDateUtils stringForMessageListDate:(int)_date relativeToDate:currentDate];
    if (_isAd)
        dateString = TGLocalized(@"DialogList.AdLabel");
    if (!TGDialogListObjectsEqual(_dateString, dateString))
    {
        _dateString = dateString;
        needsLayout = true;
    }

    if (!TGDialogListObjectsEqual(_textView.title, _titleText))
    {
        _textView.title = _titleText;
        needsTextDisplay = true;
        needsLayout = true;
    }
    if (brandedStyle && !TGDialogListObjectsEqual(_textView.statusText, _statusText))
    {
        _textView.statusText = _statusText;
        needsLayout = true;
    }
    if (_textView.isVerified != _isVerified)
    {
        _textView.isVerified = _isVerified;
        needsTextDisplay = true;
        needsLayout = true;
    }
    
    UIColor *normalTextColor = _presentation.pallete.dialogTextColor;
    UIColor *actionTextColor = _presentation.pallete.dialogTextColor;
    UIColor *mediaTextColor = _presentation.pallete.dialogTextColor;
    
    if (previewDirty)
    {
        _messageText = sourceMessageText;
        _authorName = sourceAuthorName;
    NSDictionary *preparedPreview = _preparedPreview;
    if (preparedPreview != nil)
    {
        _messageText = preparedPreview[@"text"];
        _hideAuthorName = [preparedPreview[@"hideAuthor"] boolValue];
        int colorRole = [preparedPreview[@"colorRole"] intValue];
        _messageTextColor = colorRole == 1 ? actionTextColor : (colorRole == 2 ? mediaTextColor : normalTextColor);
        _mediaIcon = nil;
    }
    else
    {
    bool attachmentFound = false;
    _hideAuthorName = !_isGroupChat || _rawText || (_isChannel && !_isChannelGroup);
    
    if (_isSavedMessages == 2)
    {
        _messageText = TGLocalized(@"DialogList.SavedMessagesHelp");
        _messageTextColor = actionTextColor;
    }
    else
    {
        if (_messageAttachments != nil && _messageAttachments.count != 0)
        {
            for (TGMediaAttachment *attachment in _messageAttachments)
            {
                if (attachment.type == TGActionMediaAttachmentType)
                {
                    _mediaIcon = nil;
                    TGActionMediaAttachment *actionAttachment = (TGActionMediaAttachment *)attachment;
                    switch (actionAttachment.actionType)
                    {
                        case TGMessageActionChatEditTitle:
                        {
                            if (TGPeerIdIsChannel(_conversationId) || TGPeerIdIsAd(_conversationId)) {
                                _messageText = _isChannelGroup ? TGLocalized(@"Notification.RenamedGroup") : TGLocalized(@"Notification.RenamedChannel");
                            } else {
                                TGUser *user = [_users objectForKey:@"author"];
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RenamedChat"), user.displayName];
                            }
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChatEditPhoto:
                        {
                            if (TGPeerIdIsChannel(_conversationId) || TGPeerIdIsAd(_conversationId)) {
                                if (_isChannelGroup) {
                                    if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil) {
                                        _messageText = TGLocalized(@"Group.MessagePhotoRemoved");
                                    } else {
                                        _messageText = TGLocalized(@"Group.MessagePhotoUpdated");
                                    }
                                } else {
                                    if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil) {
                                        _messageText = TGLocalized(@"Channel.MessagePhotoRemoved");
                                    } else {
                                        _messageText = TGLocalized(@"Channel.MessagePhotoUpdated");
                                    }
                                }
                            } else {
                                TGUser *user = [_users objectForKey:@"author"];
                                if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedGroupPhoto"), user.displayName];
                                else
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedGroupPhoto"), user.displayName];
                            }
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionUserChangedPhoto:
                        {
                            TGUser *user = [_users objectForKey:@"author"];
                            if ([(TGImageMediaAttachment *)[actionAttachment.actionData objectForKey:@"photo"] imageInfo] == nil)
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.RemovedUserPhoto"), user.displayFirstName];
                            else
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChangedUserPhoto"), user.displayFirstName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChatAddMember:
                        {
                            NSArray *uids = actionAttachment.actionData[@"uids"];
                            if (uids != nil) {
                                TGUser *authorUser = [_users objectForKey:@"author"];
                                NSMutableArray *subjectUsers = [[NSMutableArray alloc] init];
                                for (NSNumber *nUid in uids) {
                                    TGUser *user = [_users objectForKey:nUid];
                                    if (user != nil) {
                                        [subjectUsers addObject:user];
                                    }
                                }
                                
                                if (subjectUsers.count == 1 && authorUser.uid == ((TGUser *)subjectUsers[0]).uid) {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedChat"), authorUser.displayName];
                                } else {
                                    NSMutableString *subjectNames = [[NSMutableString alloc] init];
                                    for (TGUser *user in subjectUsers) {
                                        if (subjectNames.length != 0) {
                                            [subjectNames appendString:@", "];
                                        }
                                        [subjectNames appendString:user.displayName];
                                    }
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Invited"), authorUser.displayName, subjectNames];
                                }
                                _messageTextColor = actionTextColor;
                                attachmentFound = true;
                                
                                _hideAuthorName = true;
                            } else {
                                NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                                if (nUid != nil)
                                {
                                    TGUser *authorUser = [_users objectForKey:@"author"];
                                    TGUser *subjectUser = [_users objectForKey:nUid];
                                    if (authorUser.uid == subjectUser.uid)
                                        _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedChat"), authorUser.displayName];
                                    else
                                        _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Invited"), authorUser.displayName, subjectUser.displayName];
                                    _messageTextColor = actionTextColor;
                                    attachmentFound = true;
                                    
                                    _hideAuthorName = true;
                                }
                            }
                            
                            break;
                        }
                        case TGMessageActionJoinedByLink:
                        {
                            TGUser *authorUser = [_users objectForKey:@"author"];
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.JoinedGroupByLink"), authorUser.displayName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChatDeleteMember:
                        {
                            NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                            if (nUid != nil)
                            {
                                TGUser *authorUser = [_users objectForKey:@"author"];
                                TGUser *subjectUser = [_users objectForKey:nUid];
                                if (authorUser.uid == subjectUser.uid)
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.LeftChat"), authorUser.displayName];
                                else
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Kicked"), authorUser.displayName, subjectUser.displayName];
                                _messageTextColor = actionTextColor;
                                attachmentFound = true;
                                
                                _hideAuthorName = true;
                            }
                            
                            break;
                        }
                        case TGMessageActionCreateChat:
                        {
                            TGUser *user = [_users objectForKey:@"author"];
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.CreatedChat"), user.displayName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChannelCreated:
                        {
                            _messageText = TGLocalized(@"Notification.CreatedChannel");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionGroupMigratedTo:
                        {
                            _messageText = TGLocalized(@"Notification.ChannelMigratedFrom");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionGroupActivated:
                        {
                            _messageText = TGLocalized(@"Notification.GroupDeactivated");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionGroupDeactivated:
                        {
                            _messageText = TGLocalized(@"Notification.GroupActivated");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChannelMigratedFrom:
                        {
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChannelMigratedFrom"), actionAttachment.actionData[@"title"]];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionChannelInviter:
                        {
                            TGUser *user = [_users objectForKey:@"author"];
                            if ([actionAttachment.actionData[@"uid"] intValue] == user.uid) {
                                if (_isChannelGroup) {
                                    _messageText = TGLocalized(@"Notification.GroupInviterSelf");
                                } else {
                                    _messageText = TGLocalized(@"Notification.ChannelInviterSelf");
                                }
                            } else {
                                int32_t inviterUid = [actionAttachment.actionData[@"uid"] intValue];
                                NSString *inviterName = nil;
                                TGUser *user = _users[@(inviterUid)];
                                if (user.uid == inviterUid) {
                                    inviterName = user.displayName;
                                }
                                
                                if (_isChannelGroup) {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.GroupInviter"), inviterName];
                                } else {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.ChannelInviter"), inviterName];
                                }
                            }
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionCreateBroadcastList:
                        {
                            _messageText = TGLocalized(@"Notification.CreatedBroadcastList");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionContactRequest:
                        {
                            _messageText = [[NSString alloc] initWithFormat:@"%@ sent contact request", _authorName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionAcceptContactRequest:
                        {
                            _messageText = [[NSString alloc] initWithFormat:@"%@ accepted contact request", _authorName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionContactRegistered:
                        {
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.Joined"), _authorName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            _hideAuthorName = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatRequest:
                        {
                            _messageText = TGLocalized(@"Notification.EncryptedChatRequested");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatAccept:
                        {
                            _messageText = TGLocalized(@"Notification.EncryptedChatAccepted");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatDecline:
                        {
                            _messageText = TGLocalized(@"Notification.EncryptedChatRejected");
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatMessageLifetime:
                        {
                            int messageLifetime = [actionAttachment.actionData[@"messageLifetime"] intValue];
                            
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            
                            if (messageLifetime == 0)
                            {
                                if (_outgoing)
                                    _messageText = TGLocalized(@"Notification.MessageLifetimeRemovedOutgoing");
                                else
                                {
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.MessageLifetimeRemoved"), _encryptionFirstName];
                                }
                            }
                            else
                            {
                                NSString *lifetimeString = [TGStringUtils stringForMessageTimerSeconds:messageLifetime];
                                
                                if (_outgoing)
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.MessageLifetimeChangedOutgoing"), lifetimeString];
                                else
                                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.MessageLifetimeChanged"), _encryptionFirstName, lifetimeString];
                            }
                            
                            break;
                        }
                        case TGMessageActionEncryptedChatScreenshot:
                        case TGMessageActionEncryptedChatMessageScreenshot:
                        {
                            if (_encryptionFirstName.length != 0) {
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.SecretChatMessageScreenshot"), _encryptionFirstName];
                            } else {
                                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Notification.SecretChatScreenshot"), _encryptionFirstName];
                            }
                            
                            break;
                        }
                        case TGMessageActionPinnedMessage:
                        {
                            TGMessage *replyMessage = nil;
                            for (id attachment in _messageAttachments) {
                                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                                    break;
                                }
                            }
                            
                            NSString *formatString = TGLocalized(@"Message.PinnedTextMessage");
                            for (id attachment in replyMessage.mediaAttachments) {
                                if ([attachment isKindOfClass:[TGImageMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedPhotoMessage");
                                } else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedVideoMessage");
                                } else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]]) {
                                    TGDocumentMediaAttachment *document = attachment;
                                    if ([document isAnimated]) {
                                        formatString = TGLocalized(@"Message.PinnedAnimationMessage");
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
                                            formatString = TGLocalized(@"Message.PinnedStickerMessage");
                                        } else if (isVoice) {
                                            formatString = TGLocalized(@"Message.PinnedAudioMessage");
                                        } else {
                                            formatString = TGLocalized(@"Message.PinnedDocumentMessage");
                                        }
                                    }
                                } else if ([attachment isKindOfClass:[TGLocationMediaAttachment class]]) {
                                    TGLocationMediaAttachment *location = (TGLocationMediaAttachment *)attachment;
                                    if (location.period > 0)
                                        formatString = TGLocalized(@"Message.PinnedLiveLocationMessage");
                                    else
                                        formatString = TGLocalized(@"Message.PinnedLocationMessage");
                                } else if ([attachment isKindOfClass:[TGContactMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedContactMessage");
                                } else if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedGame");
                                }  else if ([attachment isKindOfClass:[TGInvoiceMediaAttachment class]]) {
                                    formatString = TGLocalized(@"Message.PinnedInvoice");
                                }
                            }
                            
                            _messageText = [NSString stringWithFormat:formatString, replyMessage.text];
                            _messageTextColor = mediaTextColor;
                            
                            break;
                        }
                        case TGMessageActionGameScore:
                        {
                            TGMessage *replyMessage = nil;
                            for (TGMediaAttachment *attachment in _messageAttachments) {
                                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                                }
                            }
                            
                            NSString *gameTitle = nil;
                            for (id attachment in replyMessage.mediaAttachments) {
                                if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
                                    gameTitle = ((TGGameMediaAttachment *)attachment).title;
                                    break;
                                }
                            }
                            
                            int scoreCount = (int)[actionAttachment.actionData[@"score"] intValue];
                            
                            NSString *formatStringBase = @"";
                            if (_authorIsSelf) {
                                if (gameTitle != nil) {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreSelfExtended_" value:scoreCount];
                                } else {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreSelfSimple_" value:scoreCount];
                                }
                            } else {
                                if (gameTitle != nil) {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreExtended_" value:scoreCount];
                                } else {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"Notification.GameScoreSimple_" value:scoreCount];
                                }
                            }
                            
                            NSString *baseString = TGLocalized(formatStringBase);
                            baseString = [baseString stringByReplacingOccurrencesOfString:@"%@" withString:@"{score}"];
                            
                            NSMutableString *formatString = [[NSMutableString alloc] initWithString:baseString];
                            
                            NSRange scoreRange = [formatString rangeOfString:@"{score}"];
                            if (scoreRange.location != NSNotFound) {
                                [formatString replaceCharactersInRange:scoreRange withString:[NSString stringWithFormat:@"%d", scoreCount]];
                            }
                            
                            NSRange gameTitleRange = [formatString rangeOfString:@"{game}"];
                            if (gameTitleRange.location != NSNotFound) {
                                [formatString replaceCharactersInRange:gameTitleRange withString:gameTitle];
                            }
                            
                            _messageText = formatString;
                            _messageTextColor = mediaTextColor;
                            break;
                        }
                        case TGMessageActionPhoneCall:
                        {
                            bool outgoing = _authorIsSelf;
                            int reason = [actionAttachment.actionData[@"reason"] intValue];
                            bool missed = reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
                            
                            NSString *type = TGLocalized(missed ? (outgoing ? @"Notification.CallCanceled" : @"Notification.CallMissed") : (outgoing ? @"Notification.CallOutgoing" : @"Notification.CallIncoming"));
                            int callDuration = [actionAttachment.actionData[@"duration"] intValue];
                            NSString *duration = missed || callDuration < 1 ? nil : [TGStringUtils stringForCallDurationSeconds:callDuration];
                            NSString *title = duration != nil ? [NSString stringWithFormat:TGLocalized(@"Notification.CallTimeFormat"), type, duration] : type;
                            _messageText = title;
                            _messageTextColor = actionTextColor;
                            break;
                        }
                        case TGMessageActionPaymentSent: {
                            NSString *string = [[TGCurrencyFormatter shared] formatAmount:[actionAttachment.actionData[@"totalAmount"] longLongValue] currency:actionAttachment.actionData[@"currency"]];
                            _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"Message.PaymentSent"), string];
                            _messageTextColor = actionTextColor;
                            break;
                        }
                        case TGMessageActionCommunityChanged:
                        {
                            bool broadcast = _isChannel && !_isChannelGroup;
                            _messageText = [TGCommunitySignals serviceTextForCommunityAction:actionAttachment isChannel:broadcast authorName:broadcast ? nil : _authorName];
                            _messageTextColor = actionTextColor;
                            attachmentFound = true;
                            _hideAuthorName = true;
                            break;
                        }
                        case TGMessageActionText:
                        {
                            _messageText = actionAttachment.actionData[@"text"];
                            _messageTextColor = actionTextColor;
                            break;
                        }
                        case TGMessageActionBotAllowed:
                        {
                            _messageText = [NSString stringWithFormat:TGLocalized(@"AuthSessions.Message"), actionAttachment.actionData[@"domain"]];
                            _messageTextColor = actionTextColor;
                        }
                        case TGMessageActionSecureValuesSent:
                        {
                            NSString *formatString = TGLocalized(@"Notification.PassportValuesSentMessage");
                            NSString *authorName = [_users[@(_conversationId)] displayName];
                            
                            NSArray *components = [actionAttachment.actionData[@"values"] componentsSeparatedByString:@","];
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
                            
                            if (values.length > 0)
                                _messageText = [[NSString alloc] initWithFormat:formatString, authorName, values];
                            else
                                _messageText = @"";
                            _messageTextColor = actionTextColor;
                        }
                            break;
                        default:
                            break;
                    }
                }
                else if (attachment.type == TGImageMediaAttachmentType)
                {
                    TGImageMediaAttachment *imageMediaAttachment = (TGImageMediaAttachment *)attachment;
                    NSString *caption = _messageText.length > 0 ? _messageText : imageMediaAttachment.caption;
                    if (imageMediaAttachment.imageId == 0 && imageMediaAttachment.localImageId == 0) {
                        _messageText = TGLocalized(@"Message.ImageExpired");
                        _messageTextColor = mediaTextColor;
                    }
                    else if (caption.length > 0)
                    {
                        bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"🖼 "];
                        _messageText = addEmoji ? [@"🖼 " stringByAppendingString:caption] : caption;
                        _messageTextColor = normalTextColor;
                    }
                    else
                    {
                        _messageText = TGLocalized(@"Message.Photo");
                        _messageTextColor = mediaTextColor;
                    }
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGVideoMediaAttachmentType)
                {
                    TGVideoMediaAttachment *videoMediaAttachment = (TGVideoMediaAttachment *)attachment;
                    NSString *caption = _messageText.length > 0 ? _messageText : videoMediaAttachment.caption;
                    if (videoMediaAttachment.videoId == 0 && videoMediaAttachment.localVideoId == 0) {
                        _messageText = TGLocalized(@"Message.VideoExpired");
                        _messageTextColor = mediaTextColor;
                    }
                    else if (caption.length > 0)
                    {
                        bool addEmoji = iosMajorVersion() >= 9 && ![caption hasPrefix:@"📹 "];
                        _messageText = addEmoji ? [@"📹 " stringByAppendingString:caption] : caption;
                        _messageTextColor = normalTextColor;
                    }
                    else
                    {
                        _messageText = videoMediaAttachment.roundMessage ? TGLocalized(@"Message.VideoMessage") : TGLocalized(@"Message.Video");
                        _messageTextColor = mediaTextColor;
                    }
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGLocationMediaAttachmentType)
                {
                    TGLocationMediaAttachment *locationMediaAttachment = (TGLocationMediaAttachment *)attachment;
                    if (locationMediaAttachment.period > 0)
                        _messageText = TGLocalized(@"Message.LiveLocation");
                    else
                        _messageText = TGLocalized(@"Message.Location");
                    _messageTextColor = mediaTextColor;
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGContactMediaAttachmentType)
                {
                    _messageText = TGLocalized(@"Message.Contact");
                    _messageTextColor = mediaTextColor;
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGPollMediaAttachmentType)
                {
                    _messageText = [(TGPollMediaAttachment *)attachment previewText];
                    _messageTextColor = mediaTextColor;
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGDocumentMediaAttachmentType)
                {
                    TGDocumentMediaAttachment *documentAttachment = (TGDocumentMediaAttachment *)attachment;
                    
                    NSString *caption = _messageText.length > 0 ? _messageText : documentAttachment.caption;
                    bool isAnimated = false;
                    CGSize imageSize = CGSizeZero;
                    bool isSticker = false;
                    bool isVoice = false;
                    NSString *musicText = nil;
                    NSString *stickerRepresentation = nil;
                    for (id attribute in documentAttachment.attributes)
                    {
                        if ([attribute isKindOfClass:[TGDocumentAttributeAnimated class]])
                        {
                            isAnimated = true;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]])
                        {
                            imageSize = ((TGDocumentAttributeImageSize *)attribute).size;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
                            imageSize = ((TGDocumentAttributeVideo *)attribute).size;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                        {
                            isSticker = true;
                            stickerRepresentation = ((TGDocumentAttributeSticker *)attribute).alt;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                            isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                            if (!isVoice) {
                                NSString *artist = ((TGDocumentAttributeAudio *)attribute).performer;
                                NSString *title = ((TGDocumentAttributeAudio *)attribute).title;
                                if (artist.length != 0 && title.length != 0) {
                                    musicText = [[artist stringByAppendingString:@" — "] stringByAppendingString:title];
                                } else if (artist.length != 0) {
                                    musicText = artist;
                                } else if (title.length != 0) {
                                    musicText = title;
                                }
                            }
                        }
                    }
                    
                    if (TGPeerIdIsSecretChat(_conversationId) && [documentAttachment.mimeType isEqualToString:@"video/mp4"] && documentAttachment.size < 1024 * 1024) {
                        isAnimated = true;
                    }
                    
                    if (isSticker)
                    {
                        if (stickerRepresentation.length == 0)
                            _messageText = TGLocalized(@"Message.Sticker");
                        else
                            _messageText = [[NSString alloc] initWithFormat:@"%@ %@", stickerRepresentation, TGLocalized(@"Message.Sticker")];
                        _mediaIcon = nil;
                    }
                    else if (isAnimated) {
                        _messageText = TGLocalized(@"Message.Animation");
                        _messageTextColor = mediaTextColor;
                        attachmentFound = true;
                    }
                    else if (isVoice) {
                        _messageText = TGLocalized(@"Message.Audio");
                        _messageTextColor = mediaTextColor;
                        attachmentFound = true;
                    }
                    else if (musicText != nil) {
                        _messageText = musicText;
                        _messageTextColor = mediaTextColor;
                        attachmentFound = true;
                    }
                    else
                    {
                        NSString *fileName = ((TGDocumentMediaAttachment *)attachment).fileName;
                        if (caption.length > 0)
                        {
                            bool addEmoji = ![caption hasPrefix:@"📎 "];
                            _messageText = addEmoji ? [@"📎 " stringByAppendingString:caption] : caption;
                        }
                        else if (fileName.length != 0)
                            _messageText = fileName;
                        else
                            _messageText = TGLocalized(@"Message.File");
                        
                        _messageTextColor = mediaTextColor;
                        attachmentFound = true;
                    }
                    break;
                }
                else if (attachment.type == TGAudioMediaAttachmentType)
                {
                    _messageText = TGLocalized(@"Message.Audio");
                    _messageTextColor = mediaTextColor;
                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGGameAttachmentType) {
                    _messageText = [@"🎮 " stringByAppendingString:((TGGameMediaAttachment *)attachment).title];
                    _messageTextColor = mediaTextColor;
                    attachmentFound = true;
                    break;
                } else if (attachment.type == TGInvoiceMediaAttachmentType) {
                    _messageText = [@"" stringByAppendingString:((TGInvoiceMediaAttachment *)attachment).title];
                    _messageTextColor = mediaTextColor;
                    attachmentFound = true;
                    break;
                }
            }
        }
    }
    
    if (!attachmentFound)
    {
        _messageTextColor = normalTextColor;
        _mediaIcon = nil;
    }
    
    if (_messageText.length == 0)
    {
        _messageTextColor = actionTextColor;
        if (_isEncrypted)
        {
            if (_encryptionStatus == 1)
                _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.AwaitingEncryption"), _encryptionFirstName];
            else if (_encryptionStatus == 2)
                _messageText = TGLocalized(@"DialogList.EncryptionProcessing");
            else if (_encryptionStatus == 3)
                _messageText = TGLocalized(@"DialogList.EncryptionRejected");
            else if (_encryptionStatus == 4)
            {
                if (_encryptionOutgoing)
                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedOutgoing"), _encryptionFirstName];
                else
                    _messageText = [[NSString alloc] initWithFormat:TGLocalized(@"DialogList.EncryptedChatStartedIncoming"), _encryptionFirstName];
            }
        }
    }
    
    }
        _messageText = TGDialogListVisiblePreviewText(_messageText);
        _resetPreparedMessageText = _messageText;
        _resetPreparedMessageTextColor = _messageTextColor;
        _resetPreparedMediaIcon = _mediaIcon;
        _resetPreparedHideAuthorName = _hideAuthorName;
    }
    else
    {
        _messageText = _resetPreparedMessageText;
        _messageTextColor = _resetPreparedMessageTextColor;
        _mediaIcon = _resetPreparedMediaIcon;
        _hideAuthorName = _resetPreparedHideAuthorName;
    }

    _authorName = sourceAuthorName;
    NSString *renderedMessageText = _messageText;
    UIColor *renderedTextColor = TGDialogListMessageTextColor(_messageTextColor, _unread);
    NSString *renderedAuthorName = _hideAuthorName ? nil : sourceAuthorName;
    UIColor *renderedAuthorColor = self.presentation.pallete.dialogNameColor;

    if (_draft != nil && ![_draft isEmpty] && totalUnreadCount == 0)
    {
        renderedMessageText = TGDialogListVisiblePreviewText(_draft.text);
        renderedTextColor = brandedStyle ? [TGPresentation brandedIOS6DialogListAppearance].messageColor : _messageTextColor;
        renderedAuthorName = TGLocalized(@"DialogList.Draft");
        renderedAuthorColor = self.presentation.pallete.dialogDraftColor;
        _hideAuthorName = false;
        _authorName = renderedAuthorName;
    }
    
    if (!TGDialogListObjectsEqual(_textView.text, renderedMessageText))
    {
        _textView.text = renderedMessageText;
        needsTextDisplay = true;
        needsLayout = true;
    }
    if (![_textView.textColor isEqual:renderedTextColor])
    {
        _textView.textColor = renderedTextColor;
        needsTextDisplay = true;
    }
    if (![_textView.actionTextColor isEqual:actionTextColor])
    {
        _textView.actionTextColor = actionTextColor;
        needsTextDisplay = true;
    }
    if (_textView.mediaIcon != _mediaIcon)
    {
        _textView.mediaIcon = _mediaIcon;
        needsTextDisplay = true;
        needsLayout = true;
    }
    if (!TGDialogListObjectsEqual(_textView.authorName, renderedAuthorName))
    {
        _textView.authorName = renderedAuthorName;
        needsTextDisplay = true;
        needsLayout = true;
    }
    if (![_textView.authorNameColor isEqual:renderedAuthorColor])
    {
        _textView.authorNameColor = renderedAuthorColor;
        needsTextDisplay = true;
    }

    bool showUnreadBadge = totalUnreadCount > 0 || _unreadMark;
    bool showUnreadCount = totalUnreadCount > 0;
    bool showPinned = !showUnreadBadge && _pinnedToTop;
    bool showMention = _unreadMentionCount > 0 && (totalUnreadCount > 0 || _unreadMark || _unread);
    bool deliveryFailed = _deliveryState == TGMessageDeliveryStateFailed;
    if (deliveryFailed)
    {
        showUnreadBadge = false;
        showUnreadCount = false;
        showPinned = false;
        showMention = false;
    }

    if (_unreadCountBackgrond.hidden == showUnreadBadge)
    {
        _unreadCountBackgrond.hidden = !showUnreadBadge;
        needsLayout = true;
    }
    if (_unreadCountLabel.hidden == showUnreadCount)
    {
        _unreadCountLabel.hidden = !showUnreadCount;
        needsLayout = true;
    }
    if (_pinnedBackgrond.hidden == showPinned)
    {
        _pinnedBackgrond.hidden = !showPinned;
        needsLayout = true;
    }
    if (_unseenMentionsView.hidden == showMention)
    {
        _unseenMentionsView.hidden = !showMention;
        needsLayout = true;
    }

    if (showUnreadCount)
    {
        NSString *unreadText = nil;
        if (brandedStyle)
            unreadText = [TGPresentation brandedIOS6BadgeTextForCount:totalUnreadCount];
        else if (TGIsLocaleArabic())
            unreadText = [TGStringUtils stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%d", totalUnreadCount]];
        else if (totalUnreadCount < 1000)
            unreadText = [[NSString alloc] initWithFormat:@"%d", totalUnreadCount];
        else
            unreadText = [[NSString alloc] initWithFormat:@"%dK", totalUnreadCount / 1000];

        if (!TGDialogListObjectsEqual(_unreadCountLabel.text, unreadText))
        {
            _unreadCountLabel.text = unreadText;
            needsLayout = true;
        }
    }

    if (_unreadCountBackgrond != nil && showUnreadBadge)
    {
        UIImage *unreadBackground = _isMuted ? _unreadMutedBackgroundImage : _unreadBackgroundImage;
        if (_unreadCountBackgrond.image != unreadBackground)
            _unreadCountBackgrond.image = unreadBackground;

        UIColor *badgeTextColor = brandedStyle ? [UIColor whiteColor] : (_isMuted ? _presentation.pallete.dialogBadgeMutedTextColor : _presentation.pallete.dialogBadgeTextColor);
        if (![_unreadCountLabel.textColor isEqual:badgeTextColor])
            _unreadCountLabel.textColor = badgeTextColor;
    }

    if (deliveryFailed)
    {
        if (_deliveryErrorBackgrond == nil)
        {
            _deliveryErrorBackgrond = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogUnsentIcon];
            [_wrapView addSubview:_deliveryErrorBackgrond];
            needsLayout = true;
        }
        else if (_deliveryErrorBackgrond.superview == nil)
        {
            [_wrapView addSubview:_deliveryErrorBackgrond];
            needsLayout = true;
        }
    }
    else if (_deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil)
    {
        [_deliveryErrorBackgrond removeFromSuperview];
        needsLayout = true;
    }
    
    if (avatarDirty)
    {
        needsLayout = true;
        if (self.isFeed)
        {
            if (!_avatarView.hidden)
                _avatarView.hidden = true;

            UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:29.0f];
            NSInteger i = 0;
            for (NSString *uri in _feedAvatarUrls)
            {
                TGLetteredAvatarView *avatarView = [self dequeueAvatarViewForIndex:i];

                if (uri.length == 0)
                {
                    [avatarView loadGroupPlaceholderWithSize:CGSizeMake(29.0f, 29.0f) conversationId:[_feedChatIds[i] longLongValue] title:_feedChatTitles[i] placeholder:placeholder];
                }
                else if (_fastScrolling)
                {
                    UIImage *cachedAvatar = [TGRemoteImageView imageFromCache:uri filter:@"circle:29x29" cache:nil];
                    [avatarView loadImage:cachedAvatar != nil ? cachedAvatar : placeholder];
                }
                else if (![avatarView.currentUrl isEqualToString:uri])
                {
                    [avatarView loadImage:uri filter:@"circle:29x29" placeholder:nil];
                }
                i++;
            }
        }
        else
        {
            if (_avatarView.hidden)
                _avatarView.hidden = false;

            CGFloat avatarSize = TGDialogListAvatarSize();
            UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:avatarSize];
            if (_isSavedMessages)
            {
                [_avatarView loadSavedMessagesWithSize:CGSizeMake(avatarSize, avatarSize) placeholder:placeholder];
            }
            else if (_avatarUrl.length != 0 && !_hasExplicitContent)
            {
                _avatarView.fadeTransitionDuration = keepState ? 0.3 : 0.14;
                NSString *avatarFilter = brandedStyle ? @"scale:50x50" : (classicStyle ? @"scale:52x52" : @"circle:62x62");

                if (_fastScrolling)
                {
                    UIImage *cachedAvatar = [TGRemoteImageView imageFromCache:_avatarUrl filter:avatarFilter cache:nil];
                    if (cachedAvatar != nil)
                        [_avatarView loadImage:cachedAvatar];
                    else
                        [_avatarView loadImage:placeholder];
                }
                else if (![_avatarView.currentUrl isEqualToString:_avatarUrl])
                {
                    if (keepState)
                        [_avatarView loadImage:_avatarUrl filter:avatarFilter placeholder:(_avatarView.currentImage != nil ? _avatarView.currentImage : placeholder) forceFade:true];
                    else
                        [_avatarView loadImage:_avatarUrl filter:avatarFilter placeholder:placeholder forceFade:false];
                }
            }
            else
            {
                _avatarView.fadeTransitionDuration = 0.14;

                if (_isEncrypted || _conversationId > 0)
                {
                    NSString *firstName = nil;
                    NSString *lastName = nil;
                    if (_titleLetters.count >= 2)
                    {
                        firstName = _titleLetters[0];
                        lastName = _titleLetters[1];
                    }
                    else if (_titleLetters.count == 1)
                    {
                        firstName = _titleLetters[0];
                    }

                    [_avatarView loadUserPlaceholderWithSize:CGSizeMake(avatarSize, avatarSize) uid:_isEncrypted ? _encryptedUserId : (int32_t)_conversationId firstName:firstName lastName:lastName placeholder:placeholder];
                }
                else
                {
                    [_avatarView loadGroupPlaceholderWithSize:CGSizeMake(avatarSize, avatarSize) conversationId:_conversationId title:_isBroadcast ? @"" : _titleText placeholder:placeholder];
                }
            }
        }
    }
    
    if (_textView.isMultichat != _isGroupChat)
    {
        _textView.isMultichat = _isGroupChat;
        needsTextDisplay = true;
        needsLayout = true;
    }
    if (_textView.isEncrypted != _isEncrypted)
    {
        _textView.isEncrypted = _isEncrypted;
        needsTextDisplay = true;
        needsLayout = true;
    }
    
    if (!TGDialogListObjectsEqual(_dateLabel.rawDateText, _dateString))
    {
        _dateLabel.dateText = _dateString;
        needsLayout = true;
    }
    
    if (_editingIsActive)
        _editingIsActive = false;

    bool showDeliveredCheckmark = false;
    bool showReadCheckmark = false;
    bool showPendingIndicator = false;
    if (_outgoing && (_draft == nil || [_draft isEmpty] || totalUnreadCount != 0) && !self.isSavedMessages)
    {
        if (!brandedStyle)
        {
            if (_deliveryState == TGMessageDeliveryStateDelivered && !_unread)
                showReadCheckmark = true;
            else if (_deliveryState == TGMessageDeliveryStateDelivered && _unread)
                showDeliveredCheckmark = true;
        }
        showPendingIndicator = _deliveryState == TGMessageDeliveryStatePending;
    }

    if (_deliveredCheckmark.hidden == showDeliveredCheckmark)
    {
        _deliveredCheckmark.hidden = !showDeliveredCheckmark;
        needsLayout = true;
    }
    if (_readCheckmark.hidden == showReadCheckmark)
    {
        _readCheckmark.hidden = !showReadCheckmark;
        needsLayout = true;
    }
    if (showPendingIndicator && _pendingIndicator == nil)
    {
        _pendingIndicator = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogPendingIcon];
        [_wrapView addSubview:_pendingIndicator];
        needsLayout = true;
    }
    if (_pendingIndicator != nil && _pendingIndicator.hidden == showPendingIndicator)
    {
        _pendingIndicator.hidden = !showPendingIndicator;
        needsLayout = true;
    }
    
    if (_isMuted)
    {
        if (_muteIcon == nil)
            _muteIcon = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogMutedIcon];
        
        if (_muteIcon.superview == nil)
        {
            [_wrapView addSubview:_muteIcon];
            needsLayout = true;
        }
    }
    else if (_muteIcon != nil && _muteIcon.superview != nil)
    {
        [_muteIcon removeFromSuperview];
        needsLayout = true;
    }
    
    if (_isVerified)
    {
        if (_verifiedIcon == nil)
            _verifiedIcon = [[TGSimpleImageView alloc] initWithImage:_presentation.images.dialogVerifiedIcon];
        if (_verifiedIcon.superview == nil)
        {
            [_wrapView addSubview:_verifiedIcon];
            needsLayout = true;
        }
    }
    else if (_verifiedIcon != nil && _verifiedIcon.superview != nil)
    {
        [_verifiedIcon removeFromSuperview];
        needsLayout = true;
    }

    bool showPremiumBadge = _isPremium && !_isVerified && !_isSavedMessages;
    if (showPremiumBadge)
    {
        if (_premiumIcon == nil)
            _premiumIcon = [[TGSimpleImageView alloc] initWithImage:[TGPresentationAssets premiumBadgeIcon:14.0f]];
        if (_premiumIcon.superview == nil)
        {
            [_wrapView addSubview:_premiumIcon];
            needsLayout = true;
        }
    }
    else if (_premiumIcon != nil && _premiumIcon.superview != nil)
    {
        [_premiumIcon removeFromSuperview];
        needsLayout = true;
    }
    
    if (needsTextDisplay)
        [_textView setNeedsDisplay];
    if (needsLayout)
    {
        _validSize = CGSizeZero;
        [self setNeedsLayout];
    }

    _resetPresentation = _presentation;
    _resetSourceMessageText = sourceMessageText;
    _resetSourceMessageAttachments = _messageAttachments;
    _resetSourcePreparedPreview = _preparedPreview;
    _resetSourceUsers = _users;
    _resetSourceAuthorName = sourceAuthorName;
    _resetSourceEncryptionFirstName = _encryptionFirstName;
    _resetSourceConversationId = _conversationId;
    _resetSourceIsSavedMessages = _isSavedMessages;
    _resetSourceEncryptionStatus = _encryptionStatus;
    _resetSourceIsGroupChat = _isGroupChat;
    _resetSourceRawText = _rawText;
    _resetSourceIsChannel = _isChannel;
    _resetSourceIsChannelGroup = _isChannelGroup;
    _resetSourceIsEncrypted = _isEncrypted;
    _resetSourceEncryptionOutgoing = _encryptionOutgoing;
    _resetSourceAuthorIsSelf = _authorIsSelf;
    _resetSourceOutgoing = _outgoing;
    _resetBrandedStyle = brandedStyle;
    _resetClassicStyle = classicStyle;
    _resetAvatarUrl = _avatarUrl;
    _resetAvatarTitleLetters = _titleLetters;
    _resetFeedChatIds = _feedChatIds;
    _resetFeedChatTitles = _feedChatTitles;
    _resetFeedAvatarUrls = _feedAvatarUrls;
    _resetAvatarTitleText = _titleText;
    _resetAvatarConversationId = _conversationId;
    _resetAvatarIsSavedMessages = _isSavedMessages;
    _resetAvatarEncryptedUserId = _encryptedUserId;
    _resetAvatarIsFeed = _isFeed;
    _resetAvatarHasExplicitContent = _hasExplicitContent;
    _resetAvatarIsEncrypted = _isEncrypted;
    _resetAvatarIsBroadcast = _isBroadcast;
    _hasResetSnapshot = true;
    [self updateCommunityIndicator];
}

- (void)updateCommunityIndicator
{
    if (_linkedCommunityId == 0 || _presentation == nil)
    {
        _communityIndicatorView.hidden = true;
        return;
    }

    CGSize size = self.bounds.size;
    CGFloat width = [TGCommunityAppearance indicatorWidthForContainerWidth:size.width];
    UIImage *image = [TGCommunityAppearance indicatorImageWithWidth:width presentation:_presentation];

    if (_communityIndicatorView == nil)
    {
        _communityIndicatorView = [[UIImageView alloc] init];
        _communityIndicatorView.userInteractionEnabled = false;
        [self addSubview:_communityIndicatorView];
    }

    if (_communityIndicatorView.image != image)
        _communityIndicatorView.image = image;
    _communityIndicatorView.hidden = false;
    if (self.subviews.lastObject != _communityIndicatorView)
        [self bringSubviewToFront:_communityIndicatorView];

    CGRect frame = CGRectMake(self.contentView.frame.origin.x, 0.0f, width, size.height);
    if (!CGRectEqualToRect(_communityIndicatorView.frame, frame))
        _communityIndicatorView.frame = frame;
}

- (void)setLinkedCommunityId:(int64_t)linkedCommunityId
{
    if (_linkedCommunityId == linkedCommunityId)
        return;
    bool presenceChanged = (_linkedCommunityId == 0) != (linkedCommunityId == 0);
    _linkedCommunityId = linkedCommunityId;
    if (presenceChanged)
    {
        _validSize = CGSizeZero;
        _fastLayoutSize = CGSizeZero;
        _editingControlsStateValid = false;
        [self setNeedsLayout];
    }
    [self updateCommunityIndicator];
}

- (TGLetteredAvatarView *)dequeueAvatarViewForIndex:(NSInteger)index
{
    if (_avatarViews == nil)
        _avatarViews = [[NSMutableArray alloc] init];
    
    if ((NSInteger)_avatarViews.count < index + 1)
    {
        CGRect frame = CGRectZero;
        CGPoint origin = _avatarView.frame.origin;
        switch (index)
        {
            case 0:
                frame = CGRectMake(origin.x, origin.y, 29.0f, 29.0f);
                break;
                
            case 1:
                frame = CGRectMake(origin.x + 29.0f + 2.0f + TGScreenPixel, origin.y, 29.0f, 29.0f);
                break;
                
            case 2:
                frame = CGRectMake(origin.x, origin.y + 29.0f + 2.0f + TGScreenPixel, 29.0f, 29.0f);
                break;
                
            case 3:
                frame = CGRectMake(origin.x + 29.0f + 2.0f + TGScreenPixel, origin.y + 29.0f + 2.0f + TGScreenPixel, 29.0f, 29.0f);
                break;
                
            default:
                break;
        }
        
        TGLetteredAvatarView *avatarView = [[TGLetteredAvatarView alloc] initWithFrame:frame];
        [avatarView setSingleFontSize:17.0f doubleFontSize:17.0f useBoldFont:true];
        [_avatarViews addObject:avatarView];
        [_wrapView addSubview:avatarView];
        
        return avatarView;
    }
    
    return _avatarViews[index];
}

- (void)dismissEditingControls:(bool)__unused animated
{
}

- (void)setIsLastCell:(bool)isLastCell {
    if (_isLastCell != isLastCell) {
        _isLastCell = isLastCell;
        _validSize = CGSizeZero;
        [self setNeedsLayout];
    }
}

- (void)layoutSubviews
{
    [self layoutCellSubviews];
}

- (void)layoutCellSubviews
{
#undef TG_TIMESTAMP_DEFINE
#undef TG_TIMESTAMP_MEASURE
    
#define TG_TIMESTAMP_DEFINE(x)
#define TG_TIMESTAMP_MEASURE(x)
    
    TG_TIMESTAMP_DEFINE(cellLayout);
    
    TG_TIMESTAMP_MEASURE(cellLayout);

    CGFloat contentOffset = self.contentView.frame.origin.x;
    CGFloat contentWidth = self.contentView.frame.size.width;
    if (OGPlatformUsesConstrainedBackgroundExecution() && _fastScrolling && !CGSizeEqualToSize(_validSize, CGSizeZero) && CGSizeEqualToSize(_fastLayoutSize, self.bounds.size) && ABS(_fastLayoutContentOffset - contentOffset) < FLT_EPSILON && ABS(_fastLayoutContentWidth - contentWidth) < FLT_EPSILON)
    {
        return;
    }

    [super layoutSubviews];

    contentOffset = self.contentView.frame.origin.x;
    contentWidth = self.contentView.frame.size.width;
    CGFloat communityInset = _linkedCommunityId == 0 ? 0.0f : [TGDialogListCell communityContentInsetForContainerWidth:self.bounds.size.width];
    if (_fastScrolling && !CGSizeEqualToSize(_validSize, CGSizeZero) && CGSizeEqualToSize(_fastLayoutSize, self.bounds.size) && ABS(_fastLayoutContentOffset - contentOffset) < FLT_EPSILON && ABS(_fastLayoutContentWidth - contentWidth) < FLT_EPSILON)
    {
        return;
    }
    
    if ((_disableActions || contentOffset > FLT_EPSILON) && [_wrapView isExpanded]) {
        [_wrapView setExpanded:false animated:false];
    }
    [_wrapView setExpandable:contentOffset <= FLT_EPSILON || _disableActions];
    
    if (iosMajorVersion() >= 7)
    {
        static Class separatorClass = nil;
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^{
            separatorClass = NSClassFromString(TGEncodeText(@"`VJUbcmfWjfxDfmmTfqbsbupsWjfx", -1));
        });
        for (UIView *subview in self.subviews) {
            if (subview.class == separatorClass) {
                CGRect frame = subview.frame;
                if (_isLastCell) {
                    frame.size.width = self.bounds.size.width;
                    frame.origin.x = 0.0f;
                } else {
                    if (contentOffset > FLT_EPSILON) {
                        frame.size.width = self.bounds.size.width - 116.0f;
                        frame.origin.x = 116.0f;
                    } else {
                        CGFloat contentX = TGDialogListContentOffset() + communityInset;
                        frame.size.width = self.bounds.size.width - contentX;
                        frame.origin.x = contentX;
                    }
                }
                if (!CGRectEqualToRect(subview.frame, frame)) {
                    subview.frame = frame;
                }
                break;
            }
        }
    }
    
    TG_TIMESTAMP_MEASURE(cellLayout);
    
    CGFloat separatorHeight = TGScreenPixel;
    
    CGSize rawSize = self.frame.size;
    
    UIView *selectedView = self.selectedBackgroundView;
    if (selectedView != nil) {
        CGRect selectedFrame = CGRectMake(0, -separatorHeight, selectedView.frame.size.width, rawSize.height + separatorHeight);
        if (!CGRectEqualToRect(selectedView.frame, selectedFrame))
            selectedView.frame = selectedFrame;
    }
    
    TG_TIMESTAMP_MEASURE(cellLayout);
    
    CGRect backgroundFrame = CGRectMake(0.0f, 0.0f, rawSize.width, rawSize.height);
    if (!CGRectEqualToRect(self.backgroundView.frame, backgroundFrame))
        self.backgroundView.frame = backgroundFrame;
    
    static CGSize screenSize;
    static CGFloat widescreenWidth;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        screenSize = TGScreenSize();
        widescreenWidth = MAX(screenSize.width, screenSize.height);
    });
    
    CGFloat safeInset = 0.0f;
    if (iosMajorVersion() >= 11 && [self respondsToSelector:@selector(safeAreaInsets)])
    {
        UIEdgeInsets (*safeAreaInsetsImp)(id, SEL) = (UIEdgeInsets (*)(id, SEL))[self methodForSelector:@selector(safeAreaInsets)];
        safeInset = safeAreaInsetsImp(self, @selector(safeAreaInsets)).left;
    }
    
    if (contentOffset > safeInset + FLT_EPSILON && (_pinnedToTop || _isAd)) {
        if (_pinnedBackgrond.alpha >= FLT_EPSILON) {
            _pinnedBackgrond.alpha = 0.0f;
            _unreadCountBackgrond.alpha = 0.0f;
            _unseenMentionsView.alpha = 0.0f;
            _dateLabel.alpha = 0.0f;
            _readCheckmark.alpha = 0.0f;
            _deliveredCheckmark.alpha = 0.0f;
            _unreadCountLabel.alpha = 0.0f;
        }
    } else if (_pinnedBackgrond.alpha <= 1.0f - FLT_EPSILON) {
        _pinnedBackgrond.alpha = 1.0f;
        _unreadCountBackgrond.alpha = 1.0f;
        _unseenMentionsView.alpha = 1.0f;
        _dateLabel.alpha = 1.0f;
        _readCheckmark.alpha = 1.0f;
        _deliveredCheckmark.alpha = 1.0f;
        _unreadCountLabel.alpha = 1.0f;
    }
    
    CGSize size = rawSize;
    if (!TGIsPad())
    {
        if ([TGViewController hasTallScreen])
        {
            size.width = contentWidth;
        }
        else
        {
            if (rawSize.width >= widescreenWidth - FLT_EPSILON)
                size.width = screenSize.height - contentOffset;
            else
                size.width = screenSize.width - contentOffset;
        }
    }
    else
        size.width = rawSize.width - contentOffset;
    size.width = MAX(0.0f, size.width - communityInset);
    
    TG_TIMESTAMP_MEASURE(cellLayout);
    
    CGFloat contentX = TGDialogListContentOffset();
    CGFloat separatorOffset = contentX + communityInset;
    
    if (_separatorLayer != nil) {
        bool disabledActions = [CATransaction disableActions];
        [CATransaction setDisableActions:true];
        CGRect separatorFrame = CGRectMake(separatorOffset, size.height - separatorHeight, rawSize.width - separatorOffset + 256.0f, separatorHeight);
        if (!CGRectEqualToRect(_separatorLayer.frame, separatorFrame))
            _separatorLayer.frame = separatorFrame;
        [CATransaction setDisableActions:disabledActions];
    }
    
    CGRect wrapFrame = CGRectMake(contentOffset + communityInset, 0.0f, size.width, size.height);
    if (!CGRectEqualToRect(_wrapView.frame, wrapFrame))
        _wrapView.frame = wrapFrame;
    [self updateCommunityIndicator];

    CGFloat avatarSize = TGDialogListAvatarSize();
    CGFloat avatarX = TGDialogListAvatarInset();
    CGFloat avatarY = TGDialogListBrandedIOS6Style() ? 5.0f : (TGDialogListClassicIOS6Style() ? 12.0f : 7.0f);
    CGRect avatarFrame = CGRectMake(avatarX, avatarY, avatarSize, avatarSize);
    if (!CGRectEqualToRect(_avatarView.frame, avatarFrame))
        _avatarView.frame = avatarFrame;
    if (TGDialogListBrandedIOS6Style() && _brandedAvatarOverlayView != nil && !CGSizeEqualToSize(_brandedAvatarOverlayView.image.size, avatarFrame.size))
        _brandedAvatarOverlayView.image = [TGPresentation brandedIOS6DialogAvatarOverlayImageForSize:avatarFrame.size];

    if (TGDialogListBrandedIOS6Style() && _brandedDisclosureView != nil)
    {
        UIImage *disclosureImage = _unread ? _presentation.images.dialogBrandedDisclosureUnreadIcon : _presentation.images.dialogBrandedDisclosureIcon;
        if (_brandedDisclosureView.image != disclosureImage)
            _brandedDisclosureView.image = disclosureImage;
        CGSize disclosureSize = disclosureImage.size;
        CGFloat disclosureY = CGFloor(CGRectGetMidY(_avatarView.frame) - disclosureSize.height / 2.0f);
        CGRect disclosureFrame = CGRectMake(TGDialogListCenteredOrigin(size.width - TGDialogListBrandedIOS6AccessoryCenterInset, disclosureSize.width), disclosureY, disclosureSize.width, disclosureSize.height);
        if (!CGRectEqualToRect(_brandedDisclosureView.frame, disclosureFrame))
            _brandedDisclosureView.frame = disclosureFrame;
    }
    
    if (!CGSizeEqualToSize(_validSize, size))
    {
        if (_fastScrolling)
        {
            TGDialogListCellGeometryCacheEntry *cachedGeometry = [self cachedGeometryForSize:size contentOffset:contentOffset contentWidth:contentWidth];
            if (cachedGeometry != nil)
            {
                [self applyCachedGeometry:cachedGeometry size:size contentOffset:contentOffset contentWidth:contentWidth];
                [self updateTextBackdrop];
                return;
            }
        }

        if (_textView != nil)
        {
            if (TGDialogListBrandedIOS6Style())
            {
                CGRect textViewFrame = CGRectMake(contentX, 0.0f, size.width - contentX, 62.0f);
                if (!CGRectEqualToRect(_textView.frame, textViewFrame))
                {
                    _textView.frame = textViewFrame;
                    [_textView setNeedsDisplay];
                }
            }
            else if (!CGSizeEqualToSize(_textView.frame.size, CGRectMake(contentX - 1.0f, 6, size.width - (contentX - 1.0f), 62).size))
            {
                _textView.frame = CGRectMake(contentX, 6, size.width - contentX, 62);
                [_textView setNeedsDisplay];
            }
        }
        
        
        NSString *unreadText = _unreadCountLabel.text == nil ? @"" : _unreadCountLabel.text;
        UIFont *unreadFont = _unreadCountLabel.font;
        if (!TGDialogListObjectsEqual(_layoutUnreadText, unreadText) || _layoutUnreadFont != unreadFont)
        {
            _layoutUnreadText = unreadText;
            _layoutUnreadFont = unreadFont;
            _layoutUnreadTextWidth = unreadText.length == 0 ? 0.0f : TGDialogListCachedTextMetric(unreadText, unreadFont, 0.0f, 1, 0).width;
        }
        CGFloat countTextWidth = _unreadCountLabel.hidden ? 9.0f : _layoutUnreadTextWidth;
        
        CGFloat brandedBadgeHeight = 18.0f * TGDialogListBrandedIOS6BadgeScale;
        CGFloat brandedBadgeHorizontalPadding = 10.0f * TGDialogListBrandedIOS6BadgeScale;
        CGFloat backgroundWidth = TGDialogListBrandedIOS6Style() ? MAX(brandedBadgeHeight, countTextWidth + brandedBadgeHorizontalPadding) : MAX(20.0f, countTextWidth + 11.0f);
        CGRect unreadCountBackgroundFrame = TGDialogListBrandedIOS6Style() ? CGRectMake(0.0f, 0.0f, backgroundWidth, brandedBadgeHeight) : CGRectMake(size.width - 11.0f - backgroundWidth, 38.0f, backgroundWidth, 20.0f);
        if (!TGDialogListBrandedIOS6Style() && !CGRectEqualToRect(_unreadCountBackgrond.frame, unreadCountBackgroundFrame))
            _unreadCountBackgrond.frame = unreadCountBackgroundFrame;
        CGFloat brandedAccessoryCenterX = CGRectGetMidX(_brandedDisclosureView.frame);
        CGRect pinnedFrame = TGDialogListBrandedIOS6Style() ? CGRectMake(TGDialogListCenteredOrigin(brandedAccessoryCenterX, 16.0f), 4.0f, 16.0f, 16.0f) : CGRectMake(size.width - 14.0f - 20.0f, 39.0f, 20.0f, 20.0f);
        if (!CGRectEqualToRect(_pinnedBackgrond.frame, pinnedFrame))
            _pinnedBackgrond.frame = pinnedFrame;
        if (!TGDialogListBrandedIOS6Style())
        {
            CGRect unreadCountLabelFrame = _unreadCountLabel.frame;
            unreadCountLabelFrame.origin = CGPointMake(unreadCountBackgroundFrame.origin.x + TGScreenPixelFloor(((unreadCountBackgroundFrame.size.width - countTextWidth) / 2.0f)), unreadCountBackgroundFrame.origin.y + 1.0f - TGScreenPixel);
            if (!CGRectEqualToRect(_unreadCountLabel.frame, unreadCountLabelFrame))
                _unreadCountLabel.frame = unreadCountLabelFrame;

            CGRect unseenMentionsFrame = _unreadCountBackgrond.hidden && _pinnedBackgrond.hidden ? CGRectMake(size.width - 11.0f - 20.0f, 38.0f, 20.0f, 20.0f) : CGRectMake(unreadCountBackgroundFrame.origin.x - 6.0f - 20.0f, unreadCountBackgroundFrame.origin.y, 20.0f, 20.0f);
            if (!CGRectEqualToRect(_unseenMentionsView.frame, unseenMentionsFrame))
                _unseenMentionsView.frame = unseenMentionsFrame;
        }
        
        TG_TIMESTAMP_MEASURE(cellLayout);
        
        if (_deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil)
        {
            CGRect deliveryErrorFrame = _deliveryErrorBackgrond.frame;
            deliveryErrorFrame = CGRectMake(size.width - 14.0f - TGScreenPixel - deliveryErrorFrame.size.width, 38.0f + TGScreenPixel, deliveryErrorFrame.size.width, deliveryErrorFrame.size.height);
            if (!CGRectEqualToRect(_deliveryErrorBackgrond.frame, deliveryErrorFrame))
                _deliveryErrorBackgrond.frame = deliveryErrorFrame;
            
        }
        
        NSString *layoutDateText = _dateLabel.rawDateText == nil ? @"" : _dateLabel.rawDateText;
        if (!TGDialogListObjectsEqual(_layoutDateText, layoutDateText))
        {
            _layoutDateText = layoutDateText;
            _layoutDateTextSize = [_dateLabel measureTextSize];
        }
        CGSize dateTextSize = _layoutDateTextSize;

        CGFloat dateWidth = _date == 0 ? 0 : (int)(dateTextSize.width);
        CGRect dateFrame = TGDialogListBrandedIOS6Style() ? CGRectMake(MIN(TGDialogListCenteredOrigin(brandedAccessoryCenterX, dateWidth), size.width - 8.0f - dateWidth), 48.0f, CGCeil(dateTextSize.width), 15.0f) : CGRectMake(size.width - dateWidth - 11.0f + (contentOffset > FLT_EPSILON ? 4.0f : 0.0f), 10.0f + TGScreenPixel - (TGIsPad() ? 1.0f : 0.0f), _isAd ? dateTextSize.width : 75, 20);
        if (!CGRectEqualToRect(_dateLabel.frame, dateFrame))
            _dateLabel.frame = dateFrame;
        bool showsDeliveryStatus = !_deliveredCheckmark.hidden || !_readCheckmark.hidden || (_pendingIndicator != nil && !_pendingIndicator.hidden);
        CGFloat brandedStatusWidth = 0.0f;
        if ([self brandedStatusVisible])
        {
            NSString *statusText = _textView.statusText;
            UIFont *statusFont = _textView.statusFont;
            if (!TGDialogListObjectsEqual(_layoutStatusText, statusText) || _layoutStatusFont != statusFont)
            {
                _layoutStatusText = statusText;
                _layoutStatusFont = statusFont;
                _layoutStatusWidth = statusText.length == 0 ? 0.0f : CGCeil(TGDialogListCachedTextMetric(statusText, statusFont, 0.0f, 1, 0).width);
            }
            brandedStatusWidth = MIN(103.2f, _layoutStatusWidth);
        }
        OGDialogLayoutInput input = {0};
        input.width = size.width;
        input.contentInset = contentX;
        input.dateOrigin = dateFrame.origin.x;
        input.statusWidth = brandedStatusWidth;
        input.badgeWidth = unreadCountBackgroundFrame.size.width;
        input.mentionWidth = TGDialogListBrandedIOS6Style() ? TGDialogListBrandedMentionWidth(_presentation) : _unseenMentionsView.image.size.width;
        input.verifiedWidth = _isVerified ? _verifiedIcon.bounds.size.width : 0.0f;
        input.premiumWidth = _premiumIcon.superview != nil ? _premiumIcon.bounds.size.width : 0.0f;
        input.previewPadding = TGDialogListBrandedIOS6Style() ? TGDialogListBrandedPreviewRightPadding(_textView.textFont) : 0.0f;
        input.branded = TGDialogListBrandedIOS6Style();
        input.encrypted = _isEncrypted;
        input.muted = _isMuted;
        input.muteWidth = _presentation.images.dialogMutedIcon.size.width;
        input.unreadBadge = !_unreadCountBackgrond.hidden;
        input.pinned = !_pinnedBackgrond.hidden;
        input.mention = !_unseenMentionsView.hidden;
        input.deliveryError = _deliveryErrorBackgrond != nil && _deliveryErrorBackgrond.superview != nil;
        input.deliveryStatus = showsDeliveryStatus;
        OGDialogHorizontalLayout geometry = OGDialogHorizontalLayoutMake(input);
        CGFloat titleLabelWidth = geometry.maximumTitleWidth;
        CGFloat groupChatIconWidth = geometry.titleOrigin - contentX;

        UIFont *titleFont = _textView.titleFont;
        CGFloat titleTextWidth = 0.0f;
        if (iosMajorVersion() <= 3 && TGDialogListRequiresPackEmoji(_titleText))
        {
            TGDialogListLegacyTextLayout *titleLayout = TGDialogListLegacyTextLayoutForText(_titleText, titleFont, MAX(1.0f, titleLabelWidth), 1);
            TGDialogListLegacyTextLine *titleLine = titleLayout.lines.count == 0 ? nil : [titleLayout.lines objectAtIndex:0];
            titleTextWidth = titleLine == nil ? 0.0f : titleLine.width;
        }
        else
        {
            if (!TGDialogListObjectsEqual(_layoutTitleText, _titleText) || _layoutTitleFont != titleFont)
            {
                _layoutTitleText = _titleText;
                _layoutTitleFont = titleFont;
                _layoutTitleWidth = TGDialogListRenderedSingleLineWidth(_titleText, titleFont);
            }
            titleTextWidth = _layoutTitleWidth;
        }
        titleLabelWidth = OGDialogTitleWidth(geometry, titleTextWidth);
        
        TG_TIMESTAMP_MEASURE(cellLayout);
        
        CGFloat checkmarkY = TGDialogListBrandedIOS6Style() ? 31.0f : 13.0f;
        CGRect deliveredFrame = CGRectMake(dateFrame.origin.x - 16, checkmarkY, 14, 11);
        if (!CGRectEqualToRect(_deliveredCheckmark.frame, deliveredFrame))
            _deliveredCheckmark.frame = deliveredFrame;
        CGRect readFrame = CGRectMake(dateFrame.origin.x - 20, checkmarkY, 18, 11);
        if (!CGRectEqualToRect(_readCheckmark.frame, readFrame))
            _readCheckmark.frame = readFrame;

        if (_pendingIndicator != nil)
        {
            CGRect pendingFrame = CGRectMake(dateFrame.origin.x - 16, 13, 12, 12);
            if (!CGRectEqualToRect(_pendingIndicator.frame, pendingFrame))
                _pendingIndicator.frame = pendingFrame;
        }
        
        CGFloat titleBaselineOffset = TGDialogListTitleBaselineOffset(titleFont);
        CGFloat brandedTitleY = 2.0f;
        CGFloat brandedTitleHeight = CGCeil(OGPlatformFontLineHeight(_textView.titleFont));
        CGFloat brandedBodyHeight = CGCeil(OGPlatformFontLineHeight(_textView.textFont));
        CGFloat dateBaseline = dateFrame.origin.y + _dateLabel.dateFont.ascender;
        CGFloat titleY = TGDialogListBrandedIOS6Style() ? brandedTitleY : TGDialogListPixelRound(dateBaseline - titleBaselineOffset);
        CGRect titleRect = CGRectMake(contentX + groupChatIconWidth, titleY, titleLabelWidth, TGDialogListBrandedIOS6Style() ? brandedTitleHeight : 20.0f);
        if ([self brandedStatusVisible])
        {
            UIFont *statusFont = _textView.statusFont;
            CGFloat statusHeight = CGCeil(OGPlatformFontLineHeight(statusFont));
            CGFloat statusY = TGDialogListPixelRound(titleRect.origin.y + titleBaselineOffset - TGDialogListTitleBaselineOffset(statusFont));
            CGFloat statusX = CGRectGetMaxX(titleRect) + 2.0f;
            if (_isVerified)
                statusX += _verifiedIcon.bounds.size.width + 7.0f;
            else if (_premiumIcon.superview != nil)
                statusX += _premiumIcon.bounds.size.width + 7.0f;
            _textView.statusFrame = CGRectMake(statusX, statusY, brandedStatusWidth, statusHeight);
        }
        else
            _textView.statusFrame = CGRectZero;

        CGFloat brandedMessageY = brandedTitleY + brandedTitleHeight;
        CGFloat brandedMessageHeight = MAX(brandedBodyHeight, 62.0f - brandedMessageY);
        CGRect messageRect = CGRectMake(contentX, TGDialogListBrandedIOS6Style() ? brandedMessageY : 30.0f - TGScreenPixel, geometry.previewWidth, TGDialogListBrandedIOS6Style() ? brandedMessageHeight : 40.0f);
        
        CGRect typingRect = messageRect;
        typingRect.size.width -= 12;
        if (TGIsRTL())
            typingRect.origin.x += 12.0f;
        _textView.typingFrame = typingRect;
        
        if (_typingDotsContainer.superview != nil)
        {
            NSString *typingText = _textView.typingText == nil ? @"" : _textView.typingText;
            UIFont *typingFont = _textView.textFont;
            CGFloat typingWidth = typingRect.size.width;
            if (!TGDialogListObjectsEqual(_layoutTypingText, typingText) || _layoutTypingFont != typingFont || ABS(_layoutTypingWidth - typingWidth) > FLT_EPSILON)
            {
                _layoutTypingText = typingText;
                _layoutTypingFont = typingFont;
                _layoutTypingWidth = typingWidth;
                if (iosMajorVersion() <= 3 && TGDialogListRequiresPackEmoji(typingText))
                {
                    TGDialogListLegacyTextLayout *typingLayout = TGDialogListLegacyTextLayoutForText(typingText, typingFont, MAX(1.0f, typingWidth), 1);
                    TGDialogListLegacyTextLine *typingLine = typingLayout.lines.count == 0 ? nil : [typingLayout.lines objectAtIndex:0];
                    _layoutTypingSize = CGSizeMake(typingLine == nil ? 0.0f : typingLine.width, typingLayout == nil ? 0.0f : typingLayout.lineHeight);
                }
                else
                {
                    _layoutTypingSize = TGDialogListBrandedIOS6Style() ? TGDialogListCachedTextMetric(typingText, typingFont, 0.0f, 1, 0) : TGDialogListCachedTextMetric(typingText, typingFont, typingWidth, 1, 2);
                }
            }
            CGSize typingSize = _layoutTypingSize;

            CGRect typingDotsFrame = _typingDotsContainer.frame;
            typingDotsFrame.origin.x = TGIsRTL() ? messageRect.origin.x : (typingRect.origin.x + typingSize.width);
            typingDotsFrame.origin.y = typingRect.origin.y + 4;
            if (!CGRectEqualToRect(_typingDotsContainer.frame, typingDotsFrame))
                _typingDotsContainer.frame = typingDotsFrame;
        }
        
        if (_authorName != nil && !_hideAuthorName)
        {
            CGFloat authorNameY = 29.0f + TGScreenPixel;
            if (TGDialogListBrandedIOS6Style())
                authorNameY = brandedMessageY;
            else if (!TGDialogListClassicIOS6Style() && iosMajorVersion() >= 7)
                authorNameY = 26.0f;
            _textView.authorNameFrame = CGRectMake(contentX, authorNameY, geometry.authorWidth, TGDialogListBrandedIOS6Style() ? brandedBodyHeight : 20.0f);
            
            CGFloat authorLineHeight = TGDialogListBrandedIOS6Style() ? brandedBodyHeight : 12.0f;
            messageRect.origin.y += TGDialogListBrandedIOS6Style() ? authorLineHeight : (iosMajorVersion() >= 7 ? (16 + TGScreenPixel) : 17);
            messageRect.size.height -= authorLineHeight;
        }

        TG_TIMESTAMP_MEASURE(cellLayout);
        
        titleRect.size.width = titleLabelWidth;
        
        if (!TGDialogListBrandedIOS6Style() && iosMajorVersion() < 7 && _authorName != nil && !_hideAuthorName)
        {
            UIFont *messageFont = _textView.textFont;
            CGFloat messageWidth = messageRect.size.width;
            NSString *layoutMessageText = _textView.text;
            if (!TGDialogListObjectsEqual(_layoutMessageText, layoutMessageText) || _layoutMessageFont != messageFont || ABS(_layoutMessageWidth - messageWidth) > FLT_EPSILON)
            {
                _layoutMessageText = layoutMessageText;
                _layoutMessageFont = messageFont;
                _layoutMessageWidth = messageWidth;
                if (iosMajorVersion() <= 3 && TGDialogListRequiresPackEmoji(layoutMessageText))
                {
                    TGDialogListLegacyTextLayout *messageLayout = TGDialogListLegacyTextLayoutForText(layoutMessageText, messageFont, MAX(1.0f, messageWidth), 2);
                    _layoutMessageSize = CGSizeMake(messageWidth, messageLayout == nil ? 0.0f : messageLayout.lineHeight * messageLayout.lines.count);
                }
                else if (iosMajorVersion() <= 3)
                {
                    _layoutMessageSize = TGDialogListCachedTextMetric(layoutMessageText, messageFont, messageWidth, 2, 1);
                }
                else
                {
                    _layoutMessageSize = TGDialogListTextSize(layoutMessageText, messageFont, messageWidth, 2);
                }
            }
            if (_layoutMessageSize.height < 20.0f)
                messageRect.origin.y += 9;
        }
        
        CGFloat titleIconCenterY = titleRect.origin.y + titleBaselineOffset - OGPlatformFontCapHeight(titleFont) / 2.0f;
        if (_isVerified) {
            CGRect verifiedRect = _verifiedIcon.bounds;
            verifiedRect.origin = CGPointMake(titleRect.origin.x + titleRect.size.width + 4.0f, TGDialogListCenteredOrigin(titleIconCenterY, verifiedRect.size.height));
            if (!CGRectEqualToRect(_verifiedIcon.frame, verifiedRect))
                _verifiedIcon.frame = verifiedRect;
        } else if (_premiumIcon.superview != nil) {
            CGRect premiumRect = _premiumIcon.bounds;
            premiumRect.origin = CGPointMake(titleRect.origin.x + titleRect.size.width + 4.0f, TGDialogListCenteredOrigin(titleIconCenterY, premiumRect.size.height));
            if (!CGRectEqualToRect(_premiumIcon.frame, premiumRect))
                _premiumIcon.frame = premiumRect;
        }
        
        if (_isMuted)
        {
            CGRect muteRect = _muteIcon.frame;
            CGFloat muteX = titleRect.origin.x + titleRect.size.width + 3.0f;
            if (_isVerified)
                muteX += _verifiedIcon.bounds.size.width + 7.0f;
            else if (_premiumIcon.superview != nil)
                muteX += _premiumIcon.bounds.size.width + 7.0f;
            if ([self brandedStatusVisible])
                muteX = CGRectGetMaxX(_textView.statusFrame) + 3.0f;
            CGFloat muteY = TGDialogListCenteredOrigin(titleIconCenterY, muteRect.size.height);
            muteRect.origin = CGPointMake(muteX, muteY);
            if (!CGRectEqualToRect(_muteIcon.frame, muteRect))
                _muteIcon.frame = muteRect;
        }
        
        if (TGDialogListBrandedIOS6Style())
            [self layoutBrandedBadgesWithTitleRect:titleRect badgeSize:unreadCountBackgroundFrame.size];

        _textView.titleFrame = titleRect;
        _textView.textFrame = messageRect;

        _validSize = size;
        _fastLayoutSize = self.bounds.size;
        _fastLayoutContentOffset = contentOffset;
        _fastLayoutContentWidth = contentWidth;
        [self storeGeometryForSize:size contentOffset:contentOffset contentWidth:contentWidth];
        
        TG_TIMESTAMP_MEASURE(cellLayout);
    }
    [self updateTextBackdrop];
}

#pragma mark -

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    bool wasEditing = self.isEditing;
    [super setEditing:editing animated:animated];
    [self updateTextBackdrop];
    if (animated && wasEditing != editing) {
        UIImage *brandedBackgroundImage = [self brandedBackgroundImage];
        UIView *snapshotWrappingView = brandedBackgroundImage != nil ? [[UIImageView alloc] initWithImage:brandedBackgroundImage] : [[UIView alloc] init];
        snapshotWrappingView.frame = _wrapView.bounds;
        snapshotWrappingView.backgroundColor = self.backgroundColor;
        UIView *snapshotView = [_textView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = _textView.frame;
        [snapshotWrappingView addSubview:snapshotView];
        [_wrapView insertSubview:snapshotWrappingView aboveSubview:_textView];
        [UIView animateWithDuration:0.3 animations:^{
            snapshotWrappingView.alpha = 0.0f;
        } completion:^(__unused BOOL finished) {
            [snapshotWrappingView removeFromSuperview];
        }];
    }
}

- (bool)showingDeleteConfirmationButton
{
    return false;
}

- (bool)isEditingControlsExpanded {
    return [_wrapView isExpanded];
}

- (bool)isEditingControlsTracking {
    return [_wrapView isTracking];
}

- (void)setEditingConrolsExpanded:(bool)expanded animated:(bool)animated {
    [_wrapView setExpanded:expanded animated:animated];
}

- (void)setSwipeActionsEnabled:(bool)enabled {
    [_wrapView setCommunitySwipeEnabled:!enabled && _linkedCommunityId != 0];
    [_wrapView setSwipeGesturesEnabled:enabled];
}

- (void)resetLocalization
{
    _hasResetSnapshot = false;
    _editingControlsStateValid = false;
    _dateLabel.dateText = @"";
}

- (UIView *)avatarSnapshotView
{
    return [_avatarView snapshotViewAfterScreenUpdates:false];
}

- (CGRect)avatarFrame
{
    CGRect frame = self.bounds;
    frame.size.width = CGRectGetMaxX(_avatarView.frame) + _avatarView.frame.origin.x + _wrapView.frame.origin.x;
    
    return frame;
}

- (CGRect)textContentFrame
{
    return self.bounds;
}

- (void)animateHighlight
{
    if (self.selected)
        return;
    
    [self setHighlighted:true];
    
    TGDispatchAfter(0.2, dispatch_get_main_queue(), ^
    {
        [self setHighlighted:false animated:true];
    });
}

@end
