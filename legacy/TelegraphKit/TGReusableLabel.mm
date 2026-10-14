#import "TGReusableLabel.h"
#import "../../OnegramPlatform/OGUnicode.h"
#import "../../OnegramPlatform/OGPlatformDispatch.h"
#import "../../OnegramRuntime/OGRuntime.h"

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../../OnegramPlatform/OGPlatformText.h"

#if defined(ONEGRAM_ARMV6)
#include <map>
typedef std::map<int, std::map<int, int> > TGReusableLabelLineOffsetMap;
#else
#include <tr1/unordered_map>
typedef std::tr1::unordered_map<int, std::tr1::unordered_map<int, int> > TGReusableLabelLineOffsetMap;
#endif
#include <vector>
#include <map>
#include <string>
#include <pthread.h>

typedef struct
{
    CGFloat ascent;
    CGFloat descent;
    CGFloat width;
} TGEmojiRunContext;

typedef struct
{
    NSRange sourceRange;
    NSRange displayRange;
} TGEmojiIndexMapping;

static const CGFloat TGOnegramEmojiScale = 0.8f;
static const CGFloat TGOnegramEmojiSpacing = 0.10f;

static void TGEmojiRunDeallocate(void *refCon)
{
    if (refCon != NULL)
        free(refCon);
}

static CGFloat TGEmojiRunGetAscent(void *refCon)
{
    return refCon == NULL ? 0.0f : ((TGEmojiRunContext *)refCon)->ascent;
}

static CGFloat TGEmojiRunGetDescent(void *refCon)
{
    return refCon == NULL ? 0.0f : ((TGEmojiRunContext *)refCon)->descent;
}

static CGFloat TGEmojiRunGetWidth(void *refCon)
{
    return refCon == NULL ? 0.0f : ((TGEmojiRunContext *)refCon)->width;
}

NSString *const TGReusableLabelRunDecorationAttributeName = @"TGReusableLabelRunDecoration";

@implementation TGReusableLabelRunDecoration

@end

CTRunDelegateRef TGReusableLabelCreateAttachmentRunDelegate(CGFloat ascent, CGFloat descent, CGFloat width)
{
    TGEmojiRunContext *context = (TGEmojiRunContext *)malloc(sizeof(TGEmojiRunContext));
    if (context == NULL)
        return NULL;
    context->ascent = MAX(0.0f, ascent);
    context->descent = MAX(0.0f, descent);
    context->width = MAX(0.0f, width);

    CTRunDelegateCallbacks callbacks;
    callbacks.version = kCTRunDelegateVersion1;
    callbacks.dealloc = TGEmojiRunDeallocate;
    callbacks.getAscent = TGEmojiRunGetAscent;
    callbacks.getDescent = TGEmojiRunGetDescent;
    callbacks.getWidth = TGEmojiRunGetWidth;

    CTRunDelegateRef delegate = CTRunDelegateCreate(&callbacks, context);
    if (delegate == NULL)
        free(context);
    return delegate;
}

CGFloat TGReusableLabelFirstBaselineOffset(CTFontRef font)
{
    if (font == NULL)
        return 0.0f;
    return CGFloor(CTFontGetAscent(font) + CTFontGetDescent(font));
}

static TGReusableLabelRunDecoration *TGReusableLabelRunDecorationForRun(CTRunRef run)
{
    CFDictionaryRef attributes = CTRunGetAttributes(run);
    if (attributes == NULL)
        return nil;
    id value = (__bridge id)CFDictionaryGetValue(attributes, (__bridge CFStringRef)TGReusableLabelRunDecorationAttributeName);
    return [value isKindOfClass:[TGReusableLabelRunDecoration class]] ? value : nil;
}

static void TGReusableLabelAddRoundedRect(CGContextRef context, CGRect rect, CGFloat radius)
{
    radius = MIN(radius, MIN(rect.size.width, rect.size.height) / 2.0f);
    if (radius <= 0.0f)
    {
        CGContextAddRect(context, rect);
        return;
    }
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    CGContextMoveToPoint(context, minX + radius, minY);
    CGContextAddArcToPoint(context, maxX, minY, maxX, maxY, radius);
    CGContextAddArcToPoint(context, maxX, maxY, minX, maxY, radius);
    CGContextAddArcToPoint(context, minX, maxY, minX, minY, radius);
    CGContextAddArcToPoint(context, minX, minY, maxX, minY, radius);
    CGContextClosePath(context);
}

static void TGReusableLabelDrawCover(CGContextRef context, CGRect rect, UIColor *color)
{
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeZero, 0.0f, NULL);
    CGContextSetFillColorWithColor(context, [color colorWithAlphaComponent:0.12f].CGColor);
    TGReusableLabelAddRoundedRect(context, rect, 3.0f);
    CGContextFillPath(context);

    CGContextSetFillColorWithColor(context, color.CGColor);
    uint32_t seed = ((uint32_t)lrintf(rect.origin.x * 7.0f) * 73856093u) ^ ((uint32_t)lrintf(rect.origin.y * 3.0f) * 19349663u) ^ ((uint32_t)lrintf(rect.size.width) * 83492791u);
    uint32_t width = (uint32_t)MAX(1.0f, CGFloor(rect.size.width));
    uint32_t height = (uint32_t)MAX(1.0f, CGFloor(rect.size.height));
    int count = (int)(rect.size.width * rect.size.height / 7.0f);
    CGFloat dot = TGScreenPixel * 2.0f;
    for (int i = 0; i < count; i++)
    {
        seed = seed * 1664525u + 1013904223u;
        CGFloat x = rect.origin.x + (CGFloat)((seed >> 8) % width);
        seed = seed * 1664525u + 1013904223u;
        CGFloat y = rect.origin.y + (CGFloat)((seed >> 8) % height);
        CGContextSetAlpha(context, 0.35f + 0.65f * (CGFloat)((seed >> 4) & 0xf) / 15.0f);
        CGContextFillRect(context, CGRectMake(x, y, dot, dot));
    }
    CGContextRestoreGState(context);
}

static void TGReusableLabelDrawMergedDecoration(CGContextRef context, TGReusableLabelRunDecoration *decoration, CGRect rect, CGFloat baseline, bool background)
{
    if (background)
    {
        if (decoration.backgroundColor == nil && decoration.backgroundBorderColor == nil)
            return;
        CGRect backgroundRect = CGRectInset(rect, -decoration.backgroundHorizontalOutset, -1.0f);
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, CGSizeZero, 0.0f, NULL);
        if (decoration.backgroundColor != nil)
        {
            CGContextSetFillColorWithColor(context, decoration.backgroundColor.CGColor);
            TGReusableLabelAddRoundedRect(context, backgroundRect, decoration.backgroundCornerRadius);
            CGContextFillPath(context);
        }
        if (decoration.backgroundBorderColor != nil)
        {
            CGContextSetStrokeColorWithColor(context, decoration.backgroundBorderColor.CGColor);
            CGContextSetLineWidth(context, TGScreenPixel);
            TGReusableLabelAddRoundedRect(context, CGRectInset(backgroundRect, TGScreenPixel / 2.0f, TGScreenPixel / 2.0f), decoration.backgroundCornerRadius);
            CGContextStrokePath(context);
        }
        CGContextRestoreGState(context);
        return;
    }

    if (decoration.strikethroughColor != nil)
    {
        CGFloat y = CGFloor((baseline - (baseline - rect.origin.y) * 0.32f) / TGScreenPixel) * TGScreenPixel;
        CGContextSaveGState(context);
        CGContextSetFillColorWithColor(context, decoration.strikethroughColor.CGColor);
        CGContextFillRect(context, CGRectMake(rect.origin.x, y, rect.size.width, MAX(1.0f, TGScreenPixel * 2.0f)));
        CGContextRestoreGState(context);
    }

    if (decoration.underlineColor != nil)
    {
        CGFloat y = CGFloor((baseline + MAX(1.0f, (CGRectGetMaxY(rect) - baseline) * 0.35f)) / TGScreenPixel) * TGScreenPixel;
        CGContextSaveGState(context);
        CGContextSetFillColorWithColor(context, decoration.underlineColor.CGColor);
        CGContextFillRect(context, CGRectMake(rect.origin.x, y, rect.size.width, MAX(1.0f, TGScreenPixel * 2.0f)));
        CGContextRestoreGState(context);
    }

    if (decoration.coverColor != nil)
        TGReusableLabelDrawCover(context, CGRectInset(rect, -1.0f, -1.0f), decoration.coverColor);
}

static bool TGReusableLabelRangeIsCovered(NSAttributedString *string, NSRange range)
{
    if (range.length == 0 || range.location >= string.length)
        return false;
    id value = [string attribute:TGReusableLabelRunDecorationAttributeName atIndex:range.location effectiveRange:NULL];
    return [value isKindOfClass:[TGReusableLabelRunDecoration class]] && ((TGReusableLabelRunDecoration *)value).coverColor != nil;
}

static void TGReusableLabelDrawLineDecorations(CGContextRef context, CFArrayRef glyphRuns, CGPoint lineOrigin, bool background)
{
    CFIndex count = CFArrayGetCount(glyphRuns);
    TGReusableLabelRunDecoration *current = nil;
    CGRect currentRect = CGRectNull;
    for (CFIndex index = 0; index <= count; index++)
    {
        TGReusableLabelRunDecoration *decoration = nil;
        CGRect runRect = CGRectNull;
        if (index < count)
        {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, index);
            CFIndex glyphCount = CTRunGetGlyphCount(run);
            decoration = glyphCount == 0 ? nil : TGReusableLabelRunDecorationForRun(run);
            if (decoration != nil)
            {
                CGPoint position = CGPointZero;
                CTRunGetPositions(run, CFRangeMake(0, 1), &position);
                CGFloat ascent = 0.0f;
                CGFloat descent = 0.0f;
                CGFloat width = (CGFloat)CTRunGetTypographicBounds(run, CFRangeMake(0, glyphCount), &ascent, &descent, NULL);
                runRect = CGRectMake(lineOrigin.x + position.x, lineOrigin.y - ascent, width, ascent + descent);
                if (!background && decoration.drawContent != nil)
                {
                    CGContextSaveGState(context);
                    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
                    decoration.drawContent(context, runRect);
                    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, -1.0f));
                    CGContextRestoreGState(context);
                }
            }
        }

        if (current != nil && (decoration != current || ABS(CGRectGetMinX(runRect) - CGRectGetMaxX(currentRect)) > 0.5f))
        {
            TGReusableLabelDrawMergedDecoration(context, current, currentRect, lineOrigin.y, background);
            current = nil;
            currentRect = CGRectNull;
        }

        if (decoration != nil)
        {
            if (current == nil)
            {
                current = decoration;
                currentRect = runRect;
            }
            else
                currentRect = CGRectUnion(currentRect, runRect);
        }
    }
}

static bool TGNativeEmojiMetrics(CGFloat fontSize, CGFloat *ascent, CGFloat *descent, CGFloat *width)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });

    NSNumber *cacheKey = [NSNumber numberWithInt:(int)lrintf(fontSize * 10.0f)];
    NSDictionary *cached = nil;
    @synchronized(cache)
    {
        cached = [cache objectForKey:cacheKey];
    }

    if (cached != nil)
    {
        if (ascent != NULL)
            *ascent = [[cached objectForKey:@"ascent"] floatValue];
        if (descent != NULL)
            *descent = [[cached objectForKey:@"descent"] floatValue];
        if (width != NULL)
            *width = [[cached objectForKey:@"width"] floatValue];
        return true;
    }

    CTFontRef emojiFont = CTFontCreateWithName(CFSTR("AppleColorEmoji"), fontSize, NULL);
    if (emojiFont == NULL)
        return false;

    static const UTF32Char sampleCandidates[] = {0x1F600, 0x1F604, 0x1F60A};
    NSString *sampleText = nil;
    CFCharacterSetRef emojiCharacters = CTFontCopyCharacterSet(emojiFont);
    for (size_t index = 0; emojiCharacters != NULL && index < sizeof(sampleCandidates) / sizeof(sampleCandidates[0]); index++)
    {
        if (CFCharacterSetIsLongCharacterMember(emojiCharacters, sampleCandidates[index]))
        {
            UniChar units[2];
            OGUnicodeSurrogatePairForScalar(sampleCandidates[index], units);
            sampleText = [[NSString alloc] initWithCharacters:units length:2];
            break;
        }
    }
    if (emojiCharacters != NULL)
        CFRelease(emojiCharacters);
    if (sampleText == nil)
    {
        CFRelease(emojiFont);
        return false;
    }

    NSDictionary *attributes = [NSDictionary dictionaryWithObject:(__bridge id)emojiFont forKey:(__bridge NSString *)kCTFontAttributeName];
    NSAttributedString *sample = [[NSAttributedString alloc] initWithString:sampleText attributes:attributes];
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)sample);

    CGFloat measuredAscent = 0.0f;
    CGFloat measuredDescent = 0.0f;
    CGFloat measuredWidth = 0.0f;
    if (line != NULL)
    {
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        if (CFArrayGetCount(runs) != 0)
        {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, 0);
            CFIndex glyphCount = CTRunGetGlyphCount(run);
            if (glyphCount != 0)
                measuredWidth = (CGFloat)CTRunGetTypographicBounds(run, CFRangeMake(0, glyphCount), &measuredAscent, &measuredDescent, NULL);
        }
        CFRelease(line);
    }
    CFRelease(emojiFont);

    if (measuredAscent <= 0.0f || measuredWidth <= 0.0f)
        return false;

    NSDictionary *result = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat:measuredAscent], @"ascent",
        [NSNumber numberWithFloat:measuredDescent], @"descent",
        [NSNumber numberWithFloat:measuredWidth], @"width",
        nil];
    @synchronized(cache)
    {
        [cache setObject:result forKey:cacheKey];
    }

    if (ascent != NULL)
        *ascent = measuredAscent;
    if (descent != NULL)
        *descent = measuredDescent;
    if (width != NULL)
        *width = measuredWidth;
    return true;
}

static NSUInteger TGDisplayIndexForSourceIndex(const std::vector<TGEmojiIndexMapping> *mappings, NSUInteger sourceIndex, bool endBoundary)
{
    if (mappings == NULL || mappings->empty())
        return sourceIndex;

    NSUInteger removed = 0;
    for (std::vector<TGEmojiIndexMapping>::const_iterator it = mappings->begin(); it != mappings->end(); ++it)
    {
        NSUInteger sourceStart = it->sourceRange.location;
        NSUInteger sourceEnd = NSMaxRange(it->sourceRange);

        if (sourceIndex <= sourceStart)
            break;

        if (sourceIndex >= sourceEnd)
        {
            if (it->sourceRange.length > 1)
                removed += it->sourceRange.length - 1;
            continue;
        }

        return it->displayRange.location + (endBoundary ? 1 : 0);
    }

    return sourceIndex >= removed ? sourceIndex - removed : 0;
}

static NSRange TGDisplayRangeForSourceRange(const std::vector<TGEmojiIndexMapping> *mappings, NSRange sourceRange)
{
    if (sourceRange.location == NSNotFound)
        return sourceRange;

    NSUInteger start = TGDisplayIndexForSourceIndex(mappings, sourceRange.location, false);
    NSUInteger end = TGDisplayIndexForSourceIndex(mappings, NSMaxRange(sourceRange), true);
    if (end < start)
        end = start;
    return NSMakeRange(start, end - start);
}

static void TGPrepareEmojiAttributedString(NSMutableAttributedString *string, NSString *text, CGFloat fontSize, CGFloat fontAscent, CGFloat fontDescent, std::vector<TGEmojiIndexMapping> *mappings)
{
    if (mappings != NULL)
        mappings->clear();
    if (string.length == 0 || text.length == 0)
        return;

    NSMutableArray *emojiRanges = [[NSMutableArray alloc] init];
    NSMutableArray *emojiValues = [[NSMutableArray alloc] init];
    NSUInteger sourceIndex = 0;
    NSUInteger removed = 0;

    while (sourceIndex < text.length)
    {
        NSRange emojiRange = NSMakeRange(0, 0);
        if (TGEmojiPackMatchAtIndex(text, sourceIndex, &emojiRange))
        {
            NSString *emoji = [text substringWithRange:emojiRange];
            if (TGEmojiNeedsPack(emoji))
            {
                [emojiRanges addObject:[NSValue valueWithRange:emojiRange]];
                [emojiValues addObject:emoji];
                if (mappings != NULL)
                {
                    TGEmojiIndexMapping mapping;
                    mapping.sourceRange = emojiRange;
                    mapping.displayRange = NSMakeRange(emojiRange.location - removed, 1);
                    mappings->push_back(mapping);
                }
                if (emojiRange.length > 1)
                    removed += emojiRange.length - 1;
            }
            sourceIndex = NSMaxRange(emojiRange);
        }
        else
        {
            sourceIndex++;
        }
    }

    CGFloat sourceHeight = MAX(1.0f, fontAscent + fontDescent);
    CGFloat emojiAscent = 0.0f;
    CGFloat emojiDescent = 0.0f;
    CGFloat emojiWidth = 0.0f;
    if (!TGNativeEmojiMetrics(fontSize, &emojiAscent, &emojiDescent, &emojiWidth))
    {
        CGFloat emojiSize = MAX(1.0f, fontSize) * TGOnegramEmojiScale;
        emojiDescent = emojiSize * fontDescent / sourceHeight;
        emojiAscent = emojiSize - emojiDescent;
        emojiWidth = emojiSize;
    }
    else
    {
        emojiAscent *= TGOnegramEmojiScale;
        emojiDescent *= TGOnegramEmojiScale;
        emojiWidth *= TGOnegramEmojiScale;
    }

    for (NSInteger index = (NSInteger)emojiRanges.count - 1; index >= 0; index--)
    {
        NSRange sourceRange = [[emojiRanges objectAtIndex:(NSUInteger)index] rangeValue];
        NSString *emoji = [emojiValues objectAtIndex:(NSUInteger)index];
        NSDictionary *baseAttributes = sourceRange.location < string.length ? [string attributesAtIndex:sourceRange.location effectiveRange:NULL] : nil;
        NSMutableAttributedString *replacement = [[NSMutableAttributedString alloc] initWithString:@"\uFFFC" attributes:baseAttributes];

        CGFloat trailingSpacing = 0.0f;
        if ((NSUInteger)index + 1 < emojiRanges.count)
        {
            NSRange nextRange = [[emojiRanges objectAtIndex:(NSUInteger)index + 1] rangeValue];
            if (NSMaxRange(sourceRange) == nextRange.location)
                trailingSpacing = MAX(1.0f, fontSize * TGOnegramEmojiSpacing);
        }

        TGEmojiRunContext *context = (TGEmojiRunContext *)malloc(sizeof(TGEmojiRunContext));
        if (context == NULL)
            continue;
        context->ascent = emojiAscent;
        context->descent = emojiDescent;
        context->width = MAX(1.0f, emojiAscent + emojiDescent) + trailingSpacing;

        CTRunDelegateCallbacks callbacks;
        callbacks.version = kCTRunDelegateVersion1;
        callbacks.dealloc = TGEmojiRunDeallocate;
        callbacks.getAscent = TGEmojiRunGetAscent;
        callbacks.getDescent = TGEmojiRunGetDescent;
        callbacks.getWidth = TGEmojiRunGetWidth;

        CTRunDelegateRef delegate = CTRunDelegateCreate(&callbacks, context);
        if (delegate == NULL)
        {
            free(context);
            continue;
        }

        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)replacement, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate);
        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)replacement, CFRangeMake(0, 1), CFSTR("TGOnegramEmoji"), (__bridge CFStringRef)emoji);
        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)replacement, CFRangeMake(0, 1), CFSTR("TGOnegramEmojiTrailingSpacing"), (__bridge CFNumberRef)[NSNumber numberWithFloat:trailingSpacing]);
        [string replaceCharactersInRange:sourceRange withAttributedString:replacement];
        CFRelease(delegate);
    }
}

typedef struct
{
    CFCharacterSetRef characterSet;
    std::map<UTF32Char, CTFontRef> *fallbacks;
} TGReusableLabelFontCoverage;

static pthread_mutex_t TGReusableLabelFallbackMutex = PTHREAD_MUTEX_INITIALIZER;

static std::map<std::string, TGReusableLabelFontCoverage> &TGReusableLabelFallbackCache(void)
{
    static std::map<std::string, TGReusableLabelFontCoverage> &cache = *new std::map<std::string, TGReusableLabelFontCoverage>();
    return cache;
}

static std::string TGReusableLabelFontKey(CTFontRef font)
{
    CFStringRef name = CTFontCopyPostScriptName(font);
    char nameBuffer[128] = { 0 };
    if (name != NULL)
    {
        CFStringGetCString(name, nameBuffer, sizeof(nameBuffer), kCFStringEncodingUTF8);
        CFRelease(name);
    }
    char keyBuffer[160];
    snprintf(keyBuffer, sizeof(keyBuffer), "%s/%d", nameBuffer, (int)lrint(CTFontGetSize(font) * 64.0f));
    return std::string(keyBuffer);
}

static TGReusableLabelFontCoverage *TGReusableLabelCoverageLocked(CTFontRef font, const std::string &key)
{
    std::map<std::string, TGReusableLabelFontCoverage> &cache = TGReusableLabelFallbackCache();
    std::map<std::string, TGReusableLabelFontCoverage>::iterator it = cache.find(key);
    if (it != cache.end())
        return &it->second;
    TGReusableLabelFontCoverage coverage;
    coverage.characterSet = CTFontCopyCharacterSet(font);
    coverage.fallbacks = new std::map<UTF32Char, CTFontRef>();
    cache[key] = coverage;
    return &cache[key];
}

static NSString *TGReusableLabelFallbackStorePath(void)
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *system = [[[UIDevice currentDevice] systemVersion] stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        path = [caches stringByAppendingPathComponent:[NSString stringWithFormat:@"OGFontFallback-%@.plist", system]];
    });
    return path;
}

static NSMutableDictionary *TGReusableLabelFallbackStoreLocked(void)
{
    static NSMutableDictionary *store = nil;
    if (store == nil)
    {
        NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:TGReusableLabelFallbackStorePath()];
        store = [[NSMutableDictionary alloc] initWithDictionary:[saved isKindOfClass:[NSDictionary class]] ? saved : @{}];
    }
    return store;
}

static bool TGReusableLabelFallbackStoreSaveScheduled = false;

static void TGReusableLabelFallbackStoreRememberLocked(NSString *entryKey, NSString *fontName)
{
    NSMutableDictionary *store = TGReusableLabelFallbackStoreLocked();
    if ([store[entryKey] isEqualToString:fontName])
        return;
    store[entryKey] = fontName;
    if (TGReusableLabelFallbackStoreSaveScheduled)
        return;
    TGReusableLabelFallbackStoreSaveScheduled = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        pthread_mutex_lock(&TGReusableLabelFallbackMutex);
        NSDictionary *snapshot = [TGReusableLabelFallbackStoreLocked() copy];
        TGReusableLabelFallbackStoreSaveScheduled = false;
        pthread_mutex_unlock(&TGReusableLabelFallbackMutex);
        [snapshot writeToFile:TGReusableLabelFallbackStorePath() atomically:true];
    });
}

static CTFontRef TGReusableLabelCreateNamedFont(NSString *fontName, CGFloat size)
{
    if (fontName.length == 0)
        return NULL;
    CTFontRef created = CTFontCreateWithName((__bridge CFStringRef)fontName, size, NULL);
    if (created == NULL)
        return NULL;
    CFStringRef createdName = CTFontCopyPostScriptName(created);
    bool matches = createdName != NULL && CFStringCompare(createdName, (__bridge CFStringRef)fontName, 0) == kCFCompareEqualTo;
    if (createdName != NULL)
        CFRelease(createdName);
    if (!matches)
    {
        CFRelease(created);
        return NULL;
    }
    return created;
}

static CTFontRef TGReusableLabelFallbackFont(CTFontRef font, const std::string &key, UTF32Char character)
{
    pthread_mutex_lock(&TGReusableLabelFallbackMutex);
    TGReusableLabelFontCoverage *coverage = TGReusableLabelCoverageLocked(font, key);
    std::map<UTF32Char, CTFontRef>::iterator it = coverage->fallbacks->find(character);
    if (it != coverage->fallbacks->end())
    {
        CTFontRef cached = it->second;
        pthread_mutex_unlock(&TGReusableLabelFallbackMutex);
        return cached;
    }
    NSString *entryKey = [[NSString alloc] initWithFormat:@"%s|%X", key.c_str(), (unsigned int)character];
    NSString *storedName = TGReusableLabelFallbackStoreLocked()[entryKey];
    pthread_mutex_unlock(&TGReusableLabelFallbackMutex);

    if (storedName != nil)
    {
        CTFontRef storedFont = TGReusableLabelCreateNamedFont(storedName, CTFontGetSize(font));
        if (storedFont != NULL)
        {
            pthread_mutex_lock(&TGReusableLabelFallbackMutex);
            coverage = TGReusableLabelCoverageLocked(font, key);
            it = coverage->fallbacks->find(character);
            if (it != coverage->fallbacks->end())
            {
                CFRelease(storedFont);
                storedFont = it->second;
            }
            else
                (*coverage->fallbacks)[character] = storedFont;
            pthread_mutex_unlock(&TGReusableLabelFallbackMutex);
            return storedFont;
        }
    }

    UniChar units[2];
    CFIndex unitCount = OGUnicodeSurrogatePairForScalar(character, units) ? 2 : 1;
    if (unitCount == 1)
        units[0] = (UniChar)character;
    CFStringRef characterString = CFStringCreateWithCharacters(kCFAllocatorDefault, units, unitCount);
    CTFontRef fallback = characterString != NULL ? CTFontCreateForString(font, characterString, CFRangeMake(0, unitCount)) : NULL;
    if (characterString != NULL)
        CFRelease(characterString);
    if (fallback != NULL)
    {
        CFCharacterSetRef fallbackSet = CTFontCopyCharacterSet(fallback);
        bool covers = fallbackSet != NULL && CFCharacterSetIsLongCharacterMember(fallbackSet, character);
        if (fallbackSet != NULL)
            CFRelease(fallbackSet);
        if (!covers || CFEqual(fallback, font))
        {
            CFRelease(fallback);
            fallback = NULL;
        }
    }
    bool lastResort = false;
    if (fallback == NULL)
    {
        fallback = CTFontCreateWithName(CFSTR("LastResort"), CTFontGetSize(font), NULL);
        if (fallback != NULL)
        {
            CFStringRef lastResortName = CTFontCopyPostScriptName(fallback);
            lastResort = lastResortName != NULL && CFStringCompare(lastResortName, CFSTR("LastResort"), 0) == kCFCompareEqualTo;
            if (lastResortName != NULL)
                CFRelease(lastResortName);
            if (!lastResort)
            {
                CFRelease(fallback);
                fallback = NULL;
            }
        }
    }

    pthread_mutex_lock(&TGReusableLabelFallbackMutex);
    coverage = TGReusableLabelCoverageLocked(font, key);
    it = coverage->fallbacks->find(character);
    if (it != coverage->fallbacks->end())
    {
        if (fallback != NULL)
            CFRelease(fallback);
        fallback = it->second;
    }
    else
    {
        (*coverage->fallbacks)[character] = fallback;
        if (fallback != NULL)
        {
            CFStringRef fallbackPostScriptName = CTFontCopyPostScriptName(fallback);
            if (fallbackPostScriptName != NULL)
            {
                TGReusableLabelFallbackStoreRememberLocked(entryKey, (__bridge NSString *)fallbackPostScriptName);
                CFRelease(fallbackPostScriptName);
            }
        }
    }
    pthread_mutex_unlock(&TGReusableLabelFallbackMutex);
    return fallback;
}

static CFCharacterSetRef TGReusableLabelFontCharacterSet(CTFontRef font, const std::string &key)
{
    pthread_mutex_lock(&TGReusableLabelFallbackMutex);
    CFCharacterSetRef characterSet = TGReusableLabelCoverageLocked(font, key)->characterSet;
    pthread_mutex_unlock(&TGReusableLabelFallbackMutex);
    return characterSet;
}

static void TGReusableLabelAssignFallbackFonts(NSMutableAttributedString *string)
{
    NSUInteger length = string.length;
    if (length == 0)
        return;

    if (OGPlatformTextUsesManagedFallback())
    {
        OGPlatformTextApplyManagedFallback((__bridge CFMutableAttributedStringRef)string);
        return;
    }

    NSString *text = string.string;
    std::vector<UniChar> units(length);
    [text getCharacters:units.data() range:NSMakeRange(0, length)];

    struct FallbackEdit
    {
        NSRange range;
        CTFontRef font;
    };
    std::vector<FallbackEdit> edits;

    NSUInteger runStart = 0;
    while (runStart < length)
    {
        NSRange runRange = NSMakeRange(0, 0);
        CTFontRef runFont = (__bridge CTFontRef)[string attribute:(__bridge NSString *)kCTFontAttributeName atIndex:runStart effectiveRange:&runRange];
        NSUInteger runEnd = MIN(length, NSMaxRange(runRange));
        if (runEnd <= runStart)
            runEnd = runStart + 1;
        if (runFont != NULL)
        {
            bool needsKey = false;
            for (NSUInteger index = runStart; index < runEnd; index++)
            {
                if (units[index] >= 0x0400)
                {
                    needsKey = true;
                    break;
                }
            }
            if (needsKey)
            {
                std::string key = TGReusableLabelFontKey(runFont);
                CFCharacterSetRef characterSet = TGReusableLabelFontCharacterSet(runFont, key);
                NSUInteger index = runStart;
                while (index < runEnd)
                {
                    UTF32Char character = units[index];
                    NSUInteger characterLength = 1;
                    if (OGUnicodeIsHighSurrogate(units[index]) && index + 1 < runEnd && OGUnicodeIsLowSurrogate(units[index + 1]))
                    {
                        character = OGUnicodeScalarForSurrogatePair(units[index], units[index + 1]);
                        characterLength = 2;
                    }
                    if (character >= 0x0080 && characterSet != NULL && !CFCharacterSetIsLongCharacterMember(characterSet, character))
                    {
                        CTFontRef fallback = TGReusableLabelFallbackFont(runFont, key, character);
                        if (fallback != NULL)
                        {
                            if (!edits.empty() && edits.back().font == fallback && NSMaxRange(edits.back().range) == index)
                                edits.back().range.length += characterLength;
                            else
                            {
                                FallbackEdit edit;
                                edit.range = NSMakeRange(index, characterLength);
                                edit.font = fallback;
                                edits.push_back(edit);
                            }
                        }
                    }
                    index += characterLength;
                }
            }
        }
        runStart = runEnd;
    }

    for (std::vector<FallbackEdit>::iterator it = edits.begin(); it != edits.end(); ++it)
        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(it->range.location, it->range.length), kCTFontAttributeName, it->font);
}

@interface TGReusableLabelLayoutData ()
{
    TGReusableLabelLineOffsetMap _lineOffsets;
    std::vector<TGLinePosition> _lineOrigins;
    
    std::vector<TGLinkData> _links;
    std::vector<TGEmojiIndexMapping> _emojiMappings;
}

@property (nonatomic, strong) NSArray *textLines;
@property (nonatomic) bool hasCustomDrawing;
@property (nonatomic) CGSize drawingSize;
@property (nonatomic) CGPoint drawingOffset;
@property (nonatomic, strong) NSString *text;

@property (nonatomic) CGFloat fontLineHeight;
@property (nonatomic) CGFloat fontLineSpacing;

- (TGReusableLabelLineOffsetMap *)lineOffsets;
- (std::vector<TGEmojiIndexMapping> *)emojiMappings;

@end

NSString *const TGReusableLabelEmojiImagesLoadedNotification = @"TGReusableLabelEmojiImagesLoadedNotification";

static bool TGReusableLabelMissedEmojiFlag = false;

void TGReusableLabelResetMissedEmoji(void)
{
    TGReusableLabelMissedEmojiFlag = false;
}

bool TGReusableLabelMissedEmoji(void)
{
    return TGReusableLabelMissedEmojiFlag;
}

static UIImage *TGReusableLabelEmojiImage(NSString *emoji, CGFloat size)
{
    if (!OGRuntimeInteractionActiveFast() || ![NSThread isMainThread])
        return TGEmojiImageOfSize(emoji, size);

    UIImage *image = TGEmojiCachedImageOfSize(emoji, size);
    if (image != nil)
        return image;

    TGReusableLabelMissedEmojiFlag = true;
    TGPreloadEmojiImageOfSize(emoji, size, ^
    {
        static bool notificationPending = false;
        if (notificationPending)
            return;
        notificationPending = true;
        dispatch_async(dispatch_get_main_queue(), ^
        {
            notificationPending = false;
            [[NSNotificationCenter defaultCenter] postNotificationName:TGReusableLabelEmojiImagesLoadedNotification object:nil];
        });
    });
    return nil;
}

@implementation TGReusableLabelLayoutData

- (CGFloat)drawingWidth
{
    return _drawingSize.width;
}

- (TGReusableLabelLineOffsetMap *)lineOffsets
{
    return &_lineOffsets;
}

- (std::vector<TGLinePosition> *)lineOrigins
{
    return &_lineOrigins;
}

- (std::vector<TGLinkData> *)links
{
    return &_links;
}

- (std::vector<TGEmojiIndexMapping> *)emojiMappings
{
    return &_emojiMappings;
}

- (NSString *)linkAtPoint:(CGPoint)point topRegion:(CGRect *)topRegion middleRegion:(CGRect *)middleRegion bottomRegion:(CGRect *)bottomRegion hiddenLink:(bool *)hiddenLink linkText:(NSString *__autoreleasing *)linkText
{
    if (!_links.empty())
    {
        for (std::vector<TGLinkData>::iterator it = _links.begin(); it != _links.end(); it++)
        {
            if ((it->topRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->topRegion, -2, -2), point)) || (it->middleRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->middleRegion, -2, -2), point)) || (it->bottomRegion.size.height != 0 && CGRectContainsPoint(CGRectInset(it->bottomRegion, -2, -2), point)))
            {
                if (topRegion != NULL)
                    *topRegion = it->topRegion;
                if (middleRegion != NULL)
                    *middleRegion = it->middleRegion;
                if (bottomRegion != NULL)
                    *bottomRegion = it->bottomRegion;
                if (hiddenLink) {
                    *hiddenLink = it->hidden;
                }
                if (linkText) {
                    *linkText = it->text;
                }
                return it->url;
            }
        }
    }
    return nil;
}

- (void)enumerateSearchRegionsForString:(NSString *)string withBlock:(void (^)(CGRect))block
{
    if (string.length == 0)
        return;
    
    static NSCharacterSet *alphaSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        alphaSet = [NSCharacterSet alphanumericCharacterSet];
    });
    
    NSUInteger length = _text.length;
    for (NSUInteger offset = 0; offset != NSNotFound && offset < length; )
    {
        NSRange range = [_text rangeOfString:string options:NSCaseInsensitiveSearch range:NSMakeRange(offset, length - offset)];
        if (range.location == NSNotFound)
            break;
        offset = range.location + range.length;
        if (range.location > 0)
        {
            unichar c = [_text characterAtIndex:range.location - 1];
            if ([alphaSet characterIsMember:c])
                continue;
        }
        
        int lineIndex = -1;
        for (id bridgedLine in _textLines)
        {
            lineIndex++;
            CTLineRef line = (__bridge CTLineRef)bridgedLine;
            
            CFRange lineRange = CTLineGetStringRange(line);
            CGPoint lineOrigin = CGPointMake(_lineOrigins[lineIndex].horizontalOffset, _lineOrigins[lineIndex].offset);
            NSRange displayRange = TGDisplayRangeForSourceRange(&_emojiMappings, range);
            NSRange intersectionRange = NSIntersectionRange(displayRange, NSMakeRange(lineRange.location, lineRange.length));
            if (intersectionRange.length != 0)
            {
                CGFloat startX = 0.0f;
                CGFloat endX = 0.0f;
                
                {
                    startX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location, NULL) + lineOrigin.x);
                    endX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location + intersectionRange.length, NULL) + lineOrigin.x);
                }
                
                if (startX > endX)
                {
                    CGFloat tmp = startX;
                    startX = endX;
                    endX = tmp;
                }
                
                CGRect region = CGRectMake(CGCeil(startX - 3), CGCeil(lineOrigin.y - _fontLineHeight + _fontLineHeight * 0.1f), CGCeil(endX - startX + 6), CGCeil(_fontLineSpacing));
                if (block)
                    block(region);
            }
        }
    }
}

@end

@interface TGReusableLabel ()

@end

@implementation TGReusableLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _reuseIdentifier = @"ReusableLabel";
    }
    return self;
}

- (void)setHighlighted:(bool)highlighted
{
    if (highlighted != _highlighted)
    {
        _highlighted = highlighted;
        [self setNeedsDisplay];
    }
}

- (void)setFrame:(CGRect)frame
{
    if (!CGSizeEqualToSize(self.frame.size, frame.size))
    {
        [self setNeedsDisplay];
    }
    [super setFrame:frame];
}

- (void)setText:(NSString *)text
{
    if (text != _text)
    {
        _text = text;
        [self setNeedsDisplay];
    }
}

- (CGSize)sizeThatFits:(CGSize)size
{
    if (_text.length == 0 || _font == nil)
        return CGSizeZero;

    if (iosMajorVersion() < 7)
    {
        CTFontRef coreTextFont = TGCoreTextFontForUIFont(_font);
        if (coreTextFont != NULL)
        {
            TGReusableLabelLayoutData *layout = [TGReusableLabel calculateLayout:_text additionalAttributes:nil textCheckingResults:nil font:coreTextFont textColor:_textColor ?: [UIColor blackColor] linkColor:nil frame:CGRectZero orMaxWidth:size.width flags:TGReusableLabelLayoutMultiline textAlignment:_textAlignment outIsRTL:NULL additionalTrailingWidth:0.0f maxNumberOfLines:_numberOfLines <= 0 ? 0 : (NSUInteger)_numberOfLines numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
            CFRelease(coreTextFont);
            if (layout != nil)
                return CGSizeMake(MIN(size.width, CGCeil(layout.drawingSize.width)), MIN(size.height, CGCeil(layout.size.height)));
        }
    }

    CGSize result = [_text sizeWithFont:_font constrainedToSize:size lineBreakMode:(_numberOfLines == 1 ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping)];
    return CGSizeMake(CGCeil(result.width), CGCeil(result.height));
}

+ (void)preloadData
{
}

+ (TGReusableLabelLayoutData *)calculateLayout:(NSString *)text additionalAttributes:(NSArray *)additionalAttributes textCheckingResults:(NSArray *)textCheckingResults font:(CTFontRef)font textColor:(UIColor *)textColor linkColor:(UIColor *)linkColor frame:(CGRect)frame orMaxWidth:(float)maxWidth flags:(int)flags textAlignment:(NSTextAlignment)textAlignment outIsRTL:(bool *)outIsRTL
{
    return [self calculateLayout:text additionalAttributes:additionalAttributes textCheckingResults:textCheckingResults font:font textColor:textColor linkColor:linkColor frame:frame orMaxWidth:maxWidth flags:flags textAlignment:textAlignment outIsRTL:outIsRTL additionalTrailingWidth:0.0f maxNumberOfLines:0 numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
}

+ (TGReusableLabelLayoutData *)calculateLayout:(NSString *)text additionalAttributes:(NSArray *)additionalAttributes textCheckingResults:(NSArray *)textCheckingResults font:(CTFontRef)font textColor:(UIColor *)textColor linkColor:(UIColor *)linkColor frame:(CGRect)frame orMaxWidth:(float)maxWidth flags:(int)flags textAlignment:(NSTextAlignment)textAlignment outIsRTL:(bool *)outIsRTL additionalTrailingWidth:(CGFloat)additionalTrailingWidth maxNumberOfLines:(NSUInteger)maxNumberOfLines numberOfLinesToInset:(NSUInteger)numberOfLinesToInset linesInset:(CGFloat)linesInset containsEmptyNewline:(bool *)containsEmptyNewline additionalLineSpacing:(CGFloat)additionalLineSpacing ellipsisString:(NSString *)ellipsisString underlineAllLinks:(bool)underlineAllLinks
{
    if (font == NULL || text == nil)
        return nil;
    
    bool justify = textAlignment == NSTextAlignmentJustified;
    if (justify) {
        textAlignment = NSTextAlignmentLeft;
    }
    
    static bool needToOffsetEmoji = false;
    static bool needToOffsetEmojiInitialized = false;
    static bool enableUnderline = true;
    if (!needToOffsetEmojiInitialized)
    {
        needToOffsetEmojiInitialized = true;
        needToOffsetEmoji = iosMajorVersion() < 6;
        enableUnderline = !(iosMajorVersion() == 7 && (iosMinorVersion() == 0 || iosMinorVersion() == 1));
    }
    
    TGReusableLabelLayoutData *layout = [[TGReusableLabelLayoutData alloc] init];
    layout.text = text;
    
    CGFloat fontSize = CTFontGetSize(font);
    CGFloat fontAscent = CTFontGetAscent(font);
    CGFloat fontDescent = CTFontGetDescent(font);
    
    CGFloat fontLineHeight = TGReusableLabelFirstBaselineOffset(font);
    CGFloat fontLineSpacing = CGFloor(fontLineHeight * 1.12f + additionalLineSpacing);
    
    layout.fontLineHeight = fontLineHeight;
    layout.fontLineSpacing = fontLineSpacing;
    
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (__bridge NSString *)kCTFontAttributeName, nil];
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    
    if (flags & TGReusableLabelLayoutForegroundFromContext)
        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(0, string.length), kCTForegroundColorFromContextAttributeName, kCFBooleanTrue);
    else if (textColor != NULL)
        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(0, string.length), kCTForegroundColorAttributeName, textColor.CGColor);
    
    if (additionalAttributes != nil)
    {
        int count = (int)additionalAttributes.count;
        for (int i = 0; i < count; i += 2)
        {
            NSRange range = NSMakeRange(0, 0);
            [(NSValue *)[additionalAttributes objectAtIndex:i] getValue:&range];
            NSArray *attributes = [additionalAttributes objectAtIndex:i + 1];
            
            if (range.location + range.length <= string.length)
            {
                CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(range.location, range.length), (__bridge CFStringRef)[attributes objectAtIndex:1], (__bridge CFTypeRef)[attributes objectAtIndex:0]);
            }
        }
    }
    
    CTFontRef boldFont = NULL;
    CTFontRef ultraBoldFont = NULL;
    CTFontRef italicFont = NULL;
    CTFontRef fixedFont = NULL;
    
    NSRange *pLinkRanges = NULL;
    int linkRangeActualCount = 0;
    
    if (textCheckingResults != nil && textCheckingResults.count != 0)
    {
        NSNumber *underlineStyle = [[NSNumber alloc] initWithInt:kCTUnderlineStyleSingle];
        
        int index = -1;
        for (id match in textCheckingResults)
        {
            NSRange linkRange = [match range];
            if (linkRange.location == NSNotFound || linkRange.location + linkRange.length > string.length) {
                continue;
            }
            
            
            bool useRange = false;
            bool useRangeUnderline = false;
            
            if ([match isKindOfClass:[NSTextCheckingResult class]])
            {
                NSString *url = ((NSTextCheckingResult *)match).resultType == NSTextCheckingTypePhoneNumber ? [[NSString alloc] initWithFormat:@"tel:%@", ((NSTextCheckingResult *)match).phoneNumber] : [((NSTextCheckingResult *)match).URL absoluteString];
                bool hidden = [(NSTextCheckingResult *)match isTelegramHiddenLink];
                NSString *linkText = nil;
                if (linkRange.location < text.length) {
                    NSRange fixedLinkRange = NSMakeRange(linkRange.location, MIN(text.length - linkRange.location, linkRange.location + linkRange.length));
                    if (fixedLinkRange.length > 0) {
                        linkText = [text substringWithRange:fixedLinkRange];
                    }
                }
                layout.links->push_back(TGLinkData(linkRange, url, linkText, hidden));
                
                if (flags & TGReusableLabelLayoutHighlightLinks && linkColor != NULL && !TGReusableLabelRangeIsCovered(string, linkRange))
                {
                    CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, linkColor.CGColor);
                    
                    if (enableUnderline) {
                        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTUnderlineStyleAttributeName, (__bridge CFNumberRef)underlineStyle);
                    }
                }
                
                useRange = true;
            }
            else if ([match isKindOfClass:[TGTextCheckingResult class]])
            {
                NSString *url = nil;
                
                switch (((TGTextCheckingResult *)match).type)
                {
                    case TGTextCheckingResultTypeMention:
                    {
                        url = [[NSString alloc] initWithFormat:@"mention://%@", ((TGTextCheckingResult *)match).contents];
                        useRange = true;
                        useRangeUnderline = underlineAllLinks;
                        break;
                    }
                    case TGTextCheckingResultTypeHashtag:
                    {
                        url = [[NSString alloc] initWithFormat:@"hashtag://%@", ((TGTextCheckingResult *)match).contents];
                        useRange = true;
                        useRangeUnderline = underlineAllLinks;
                        break;
                    }
                    case TGTextCheckingResultTypeCashtag:
                    {
                        url = [[NSString alloc] initWithFormat:@"cashtag://%@", ((TGTextCheckingResult *)match).contents];
                        useRange = true;
                        useRangeUnderline = underlineAllLinks;
                        break;
                    }
                    case TGTextCheckingResultTypeCommand:
                    {
                        if (flags & TGReusableLabelLayoutHighlightCommands)
                        {
                            useRange = true;
                            url = [[NSString alloc] initWithFormat:@"command://%@", ((TGTextCheckingResult *)match).contents];
                            useRangeUnderline = underlineAllLinks;
                        }
                        break;
                    }
                    case TGTextCheckingResultTypeCode:
                    {
                        if (fixedFont == nil) {
                            fixedFont = TGCoreTextFixedFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, fixedFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeItalic:
                    {
                        if (italicFont == nil) {
                            italicFont = TGCoreTextItalicFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, italicFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeBold:
                    {
                        if (boldFont == nil) {
                            boldFont = TGCoreTextBoldFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, boldFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeColor:
                    {
                        if (((TGTextCheckingResult *)match).value != nil) {
                            UIColor *color = ((TGTextCheckingResult *)match).value;
                            CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, color.CGColor);
                        }
                        
                        break;
                    }
                    case TGTextCheckingResultTypeUltraBold:
                    {
                        if (ultraBoldFont == nil) {
                            ultraBoldFont = TGCoreTextBoldFontOfSize(fontSize);
                        }
                        
                        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTFontAttributeName, ultraBoldFont);
                        
                        break;
                    }
                    case TGTextCheckingResultTypeLink:
                    {
                        url = ((TGTextCheckingResult *)match).contents;
                        useRange = true;
                        useRangeUnderline = ((TGTextCheckingResult *)match).highlightAsLink || underlineAllLinks;
                        
                        break;
                    }
                }
                
                if (useRange)
                {
                    NSString *linkText = nil;
                    if (linkRange.location < text.length) {
                        NSRange fixedLinkRange = NSMakeRange(linkRange.location, MIN(text.length - linkRange.location, linkRange.location + linkRange.length));
                        if (fixedLinkRange.length > 0) {
                            linkText = [text substringWithRange:fixedLinkRange];
                        }
                    }
                    layout.links->push_back(TGLinkData(linkRange, url, linkText, false));
                
                    if (flags & TGReusableLabelLayoutHighlightLinks && linkColor != NULL && !TGReusableLabelRangeIsCovered(string, linkRange))
                    {
                        CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTForegroundColorAttributeName, linkColor.CGColor);
                        
                        if (enableUnderline && useRangeUnderline) {
                            CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(linkRange.location, linkRange.length), kCTUnderlineStyleAttributeName, (__bridge CFNumberRef)underlineStyle);
                        }
                    }
                }
            }
            
            if (useRange)
            {
                if (pLinkRanges == NULL)
                {
                    pLinkRanges = new NSRange[(int)textCheckingResults.count];
                }
                
                pLinkRanges[++index] = linkRange;
                linkRangeActualCount++;
            }
        }
    }
    
    if (additionalAttributes != nil)
    {
        NSUInteger length = string.length;
        NSUInteger index = 0;
        while (index < length)
        {
            NSRange effectiveRange = NSMakeRange(index, 1);
            id value = [string attribute:TGReusableLabelRunDecorationAttributeName atIndex:index effectiveRange:&effectiveRange];
            if ([value isKindOfClass:[TGReusableLabelRunDecoration class]] && ((TGReusableLabelRunDecoration *)value).drawContent != nil)
            {
                layout.hasCustomDrawing = true;
                if (pLinkRanges == NULL)
                    break;
                CFAttributedStringSetAttribute((__bridge CFMutableAttributedStringRef)string, CFRangeMake(effectiveRange.location, effectiveRange.length), kCTForegroundColorAttributeName, [UIColor clearColor].CGColor);
            }
            index = MAX(index + 1, NSMaxRange(effectiveRange));
        }
    }

    TGPrepareEmojiAttributedString(string, text, fontSize, fontAscent, fontDescent, [layout emojiMappings]);
    if (pLinkRanges != NULL)
    {
        for (int i = 0; i < linkRangeActualCount; i++)
            pLinkRanges[i] = TGDisplayRangeForSourceRange([layout emojiMappings], pLinkRanges[i]);
    }

    NSArray *resultLines = nil;
    std::vector<TGLinePosition> *pLineOrigins = layout.lineOrigins;
    bool resultHadRTL = false;
    CGRect resultRect = CGRectZero;
    
    if (flags & TGReusableLabelLayoutMultiline)
    {
        CGRect rect = CGRectZero;
        rect.origin = frame.origin;
        
        pLineOrigins->erase(pLineOrigins->begin(), pLineOrigins->end());
        
        NSMutableArray *textLines = [[NSMutableArray alloc] init];
        
        bool hadRTL = false;
        
        CGFloat lastLineWidth = 0.0f;
        
        TGReusableLabelAssignFallbackFonts(string);
#if defined(ONEGRAM_DIAGNOSTICS)
        CFAbsoluteTime typesetterStart = CFAbsoluteTimeGetCurrent();
#endif
        CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)string);
#if defined(ONEGRAM_DIAGNOSTICS)
        OGPlatformTextLogSlowLayout("label", (__bridge CFAttributedStringRef)string, CFAbsoluteTimeGetCurrent() - typesetterStart);
#endif
        
        CFIndex lastIndex = 0;
        float currentLineOffset = 0;
        
        while (true)
        {
            CGFloat currentMaxWidth = maxWidth;
            CGFloat currentLineInset = 0.0f;
            if (numberOfLinesToInset != 0 && textLines.count < numberOfLinesToInset)
            {
                currentMaxWidth -= linesInset;
                currentLineInset = linesInset;
            }
            
            CFIndex lineCharacterCount = CTTypesetterSuggestLineBreak(typesetter, lastIndex, currentMaxWidth);
            
            if (pLinkRanges != NULL && flags & TGReusableLabelLayoutHighlightLinks)
            {
                CFIndex endIndex = lastIndex + lineCharacterCount;
                
                for (int i = 0; i < linkRangeActualCount; i++)
                {
                    if (pLinkRanges[i].location < (NSUInteger)endIndex && pLinkRanges[i].location + pLinkRanges[i].length >= (NSUInteger)endIndex)
                    {
                        lineCharacterCount = MAX(lineCharacterCount, CTTypesetterSuggestClusterBreak(typesetter, lastIndex, currentMaxWidth));
                        
                        if (pLinkRanges[i].location > (NSUInteger)lastIndex && lineCharacterCount < (CFIndex)(pLinkRanges[i].location + pLinkRanges[i].length - (NSUInteger)lastIndex))
                        {
                            lineCharacterCount = pLinkRanges[i].location - lastIndex;
                        }
                        
                        break;
                    }
                }
            }
            
            if (lineCharacterCount > 0)
            {
                CTLineRef line = NULL;
                
                if (maxNumberOfLines != 0 && textLines.count == maxNumberOfLines - 1)
                {
                    NSString *plainString = string.string;
                    NSUInteger stringLength = plainString.length;
                    CFIndex remainingCharacterCount = (CFIndex)stringLength - lastIndex;
                    bool boundedTailTruncation = (OGPlatformUsesConstrainedBackgroundExecution() || (flags & TGReusableLabelLayoutBoundedTail)) && !(flags & TGReusableLabelTruncateInTheMiddle) && remainingCharacterCount > lineCharacterCount;

                    CFIndex truncationLimit = lineCharacterCount;
                    bool textContinues = boundedTailTruncation;
                    if (!boundedTailTruncation)
                    {
                        NSRange paragraphBreak = [plainString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:0 range:NSMakeRange((NSUInteger)lastIndex, (NSUInteger)remainingCharacterCount)];
                        if (paragraphBreak.location == NSNotFound)
                            truncationLimit = remainingCharacterCount;
                        else
                        {
                            truncationLimit = (CFIndex)paragraphBreak.location - lastIndex;
                            NSUInteger followingIndex = NSMaxRange(paragraphBreak);
                            textContinues = [plainString rangeOfCharacterFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet] options:0 range:NSMakeRange(followingIndex, stringLength - followingIndex)].location != NSNotFound;
                        }
                    }

                    NSMutableDictionary *truncationTokenAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (__bridge NSString *)kCTFontAttributeName, (__bridge id)textColor.CGColor, (__bridge NSString *)kCTForegroundColorAttributeName, nil];
                    if (flags & TGReusableLabelLayoutForegroundFromContext)
                        truncationTokenAttributes[(__bridge NSString *)kCTForegroundColorFromContextAttributeName] = @(true);

                    static NSString *tokenString = nil;
                    static dispatch_once_t tokenOnce;
                    dispatch_once(&tokenOnce, ^
                    {
                        unichar tokenChar = 0x2026;
                        tokenString = [[NSString alloc] initWithCharacters:&tokenChar length:1];
                    });

                    NSAttributedString *truncationTokenString = [[NSAttributedString alloc] initWithString:ellipsisString == nil ? tokenString : ellipsisString attributes:truncationTokenAttributes];
                    line = OGPlatformCreateTruncatedLine(typesetter, (__bridge CFAttributedStringRef)string, CFRangeMake(lastIndex, truncationLimit), 100.0, currentMaxWidth, (flags & TGReusableLabelTruncateInTheMiddle) ? kCTLineTruncationMiddle : kCTLineTruncationEnd, (__bridge CFAttributedStringRef)truncationTokenString, textContinues);
                }
                else
                {
                    line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(lastIndex, lineCharacterCount), 100.0);
                }
                
                if (line != NULL)
                {
                    [textLines addObject:(__bridge id)line];
                
                    bool rightAligned = false;
                    
                    CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                    if (CFArrayGetCount(glyphRuns) != 0)
                    {
                        if (CTRunGetStatus((CTRunRef)CFArrayGetValueAtIndex(glyphRuns, 0)) & kCTRunStatusRightToLeft)
                            rightAligned = true;
                    }
                    
                    hadRTL |= rightAligned;
                    
                    CGFloat lineWidth = (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL) - (CGFloat)CTLineGetTrailingWhitespaceWidth(line) + currentLineInset;
                    
                    TGLinePosition linePosition = {.offset = (CGFloat)(currentLineOffset + fontLineHeight), .horizontalOffset = 0.0f, .alignment = (uint8_t)(textAlignment == NSTextAlignmentCenter ? 1 : (rightAligned ? 2 : 0)), .lineWidth = lineWidth};
                    pLineOrigins->push_back(linePosition);
                    
                    currentLineOffset += fontLineSpacing;
                    rect.size.height += fontLineSpacing;
                    rect.size.width = MAX(rect.size.width, lineWidth);
                    
                    CFRelease(line);
                    
                    lastLineWidth = lineWidth;
                    
                    lastIndex += lineCharacterCount;
                }
                else
                    break;
            }
            else
                break;
            
            if (maxNumberOfLines != 0 && textLines.count == maxNumberOfLines)
                break;
        }
        
        if (additionalTrailingWidth > FLT_EPSILON)
        {
            if (textLines.count == 1)
            {
                if (lastLineWidth + additionalTrailingWidth <= maxWidth)
                {
                    rect.size.width += additionalTrailingWidth;
                    if (pLineOrigins->at(textLines.count - 1).alignment == 2)
                    {
                        pLineOrigins->at(textLines.count - 1).horizontalOffset -= additionalTrailingWidth;
                    }
                }
                else
                {
                    rect.size.height += fontLineHeight * 0.7f;
                    if (containsEmptyNewline)
                        *containsEmptyNewline = true;
                }
            }
            else if (textLines.count != 0)
            {
                if (rect.size.width - lastLineWidth < additionalTrailingWidth)
                {
                    if (lastLineWidth + additionalTrailingWidth <= maxWidth)
                    {
                        if (pLineOrigins->at(textLines.count - 1).alignment == 2)
                        {
                            rect.size.height += fontLineHeight * 0.7f;
                            if (containsEmptyNewline)
                                *containsEmptyNewline = true;
                            rect.size.width = MAX(rect.size.width, additionalTrailingWidth - 12);
                        }
                        else
                            rect.size.width = lastLineWidth + additionalTrailingWidth;
                    }
                    else
                    {
                        rect.size.height += fontLineHeight * 0.7f;
                        if (containsEmptyNewline)
                            *containsEmptyNewline = true;
                    
                        if (rect.size.width < additionalTrailingWidth - 12)
                            rect.size.width = additionalTrailingWidth - 12;
                    }
                }
                else
                {
                    if (pLineOrigins->at(textLines.count - 1).alignment == 2)
                    {
                        rect.size.height += fontLineHeight * 0.7f;
                        if (containsEmptyNewline)
                            *containsEmptyNewline = true;
                    }
                }
            }
        }
        
        if ((flags & TGReusableLabelLayoutOffsetLastLine) && textLines.count != 0) {
            pLineOrigins->at(textLines.count - 1).offset += 2.0f;
            rect.size.height += 3.0f;
        }
        
        layout.size = CGSizeMake(CGFloor(rect.size.width), CGFloor(rect.size.height + fontLineHeight * 0.1f));
        layout.drawingSize = rect.size;
        
        if (justify) {
            NSMutableArray *justifiedLines = [[NSMutableArray alloc] init];
            for (NSInteger i = 0; i < (NSInteger)textLines.count; i++) {
                if (i != (NSInteger)textLines.count - 1) {
                    CGFloat width = layout.size.width;
                    if (i < (NSInteger)numberOfLinesToInset) {
                        width -= linesInset;
                    }
                    
                    CTLineRef line = CTLineCreateJustifiedLine((__bridge CTLineRef)textLines[i], 1.0f, width);
                    if (line != NULL) {
                        [justifiedLines addObject:(__bridge id)line];
                        CFRelease(line);
                    } else {
                        [justifiedLines addObject:textLines[i]];
                    }
                } else {
                    [justifiedLines addObject:textLines[i]];
                }
            }
            textLines = justifiedLines;
        }
        
        layout.textLines = textLines;
        
        if (typesetter != NULL)
            CFRelease(typesetter);
        
        resultLines = textLines;
        resultHadRTL = hadRTL;
        resultRect = rect;
    }
    else
    {
        CGRect rect = CGRectZero;
        rect.origin = frame.origin;
        
        pLineOrigins->erase(pLineOrigins->begin(), pLineOrigins->end());
        
        NSMutableArray *textLines = [[NSMutableArray alloc] init];
        
        NSMutableDictionary *truncationTokenAttributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:(__bridge id)font, (__bridge NSString *)kCTFontAttributeName, (__bridge id)textColor.CGColor, (__bridge NSString *)kCTForegroundColorAttributeName, nil];
        if (flags & TGReusableLabelLayoutForegroundFromContext)
            truncationTokenAttributes[(__bridge NSString *)kCTForegroundColorFromContextAttributeName] = @(true);

        static NSString *tokenString = nil;
        static dispatch_once_t tokenOnce;
        dispatch_once(&tokenOnce, ^
        {
            unichar tokenChar = 0x2026;
            tokenString = [[NSString alloc] initWithCharacters:&tokenChar length:1];
        });
        
        NSAttributedString *truncationTokenString = [[NSAttributedString alloc] initWithString:ellipsisString == nil ? tokenString : ellipsisString attributes:truncationTokenAttributes];
        
        TGReusableLabelAssignFallbackFonts(string);
        CTLineRef line = OGPlatformCreateTruncatedLine(NULL, (__bridge CFAttributedStringRef)string, CFRangeMake(0, (CFIndex)string.length), 0.0, maxWidth, (flags & TGReusableLabelTruncateInTheMiddle) ? kCTLineTruncationMiddle : kCTLineTruncationEnd, (__bridge CFAttributedStringRef)truncationTokenString, false);
        
        if (line != NULL)
        {
            CGFloat lineWidth = (float)CTLineGetTypographicBounds(line, NULL, NULL, NULL) - (float)CTLineGetTrailingWhitespaceWidth(line);
            
            TGLinePosition linePosition = {.offset = 0.0f + fontLineHeight, .horizontalOffset = 0.0f, .alignment = 0, .lineWidth = lineWidth};
            pLineOrigins->push_back(linePosition);
            
            layout.size = CGSizeMake(lineWidth, fontLineSpacing);
            layout.drawingSize = layout.size;
            
            [textLines addObject:(__bridge id)line];
            layout.textLines = textLines;
            
            CFRelease(line);
        }
        
        resultLines = textLines;
        resultRect = rect;
    }
    
    if (!layout.links->empty())
    {
        std::vector<TGLinkData>::iterator linksBegin = layout.links->begin();
        std::vector<TGLinkData>::iterator linksEnd = layout.links->end();
        
        CGSize layoutSize = layout.size;
        layoutSize.height -= 1;
        
        int numberOfLines = (int)resultLines.count;
        for (int iLine = 0; iLine < numberOfLines; iLine++)
        {
            CTLineRef line = (__bridge CTLineRef)[resultLines objectAtIndex:iLine];
            CFRange lineRange = CTLineGetStringRange(line);
            
            TGLinePosition const &linePosition = pLineOrigins->at(iLine);
            CGPoint lineOrigin = CGPointMake(linePosition.alignment == 0 ? 0.0f : ((float)CTLineGetPenOffsetForFlush(line, linePosition.alignment == 1 ? 0.5f : 1.0f, resultRect.size.width)) + linePosition.horizontalOffset, linePosition.offset);
            
            for (std::vector<TGLinkData>::iterator it = linksBegin; it != linksEnd; it++)
            {
                NSRange displayLinkRange = TGDisplayRangeForSourceRange([layout emojiMappings], it->range);
                NSRange intersectionRange = NSIntersectionRange(displayLinkRange, NSMakeRange(lineRange.location, lineRange.length));
                if (intersectionRange.length != 0)
                {
                    CGFloat startX = 0.0f;
                    CGFloat endX = 0.0f;
                 
                    if (resultHadRTL)
                    {
                        bool appliedAnyPosition = false;
                        
                        CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
                        int glyphRunCount = (int)CFArrayGetCount(glyphRuns);
                        for (int iRun = 0; iRun < glyphRunCount; iRun++)
                        {
                            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, iRun);
                            CFIndex glyphCount = CTRunGetGlyphCount(run);
                            if (glyphCount > 0)
                            {
                                CFIndex startIndex = 0;
                                CFIndex endIndex = 0;
                                
                                CTRunGetStringIndices(run, CFRangeMake(0, 1), &startIndex);
                                CTRunGetStringIndices(run, CFRangeMake(glyphCount - 1, 1), &endIndex);
                                
                                if (startIndex >= (CFIndex)displayLinkRange.location && endIndex < (CFIndex)(displayLinkRange.location + displayLinkRange.length))
                                {
                                    CGPoint leftPosition = CGPointZero;
                                    CGPoint rightPosition = CGPointZero;
                                    
                                    CTRunGetPositions(run, CFRangeMake(0, 1), &leftPosition);
                                    float runWidth = (float)CTRunGetTypographicBounds(run, CFRangeMake(0, glyphCount), NULL, NULL, NULL);
                                    rightPosition.x = leftPosition.x + runWidth;
                                    
                                    if (!appliedAnyPosition)
                                    {
                                        appliedAnyPosition = true;
                                        
                                        startX = leftPosition.x;
                                        endX = rightPosition.x;
                                    }
                                    else
                                    {
                                        if (leftPosition.x < startX)
                                            startX = leftPosition.x;
                                        if (rightPosition.x > endX)
                                            endX = rightPosition.x;
                                    }
                                }
                            }
                        }
                        
                        startX = CGFloor(startX + lineOrigin.x);
                        endX = CGCeil(endX + lineOrigin.x);
                    }
                    else
                    {
                        startX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location, NULL) + lineOrigin.x);
                        endX = CGCeil(CTLineGetOffsetForStringIndex(line, intersectionRange.location + intersectionRange.length, NULL) + lineOrigin.x);
                    }
                    
                    if (startX > endX)
                    {
                        CGFloat tmp = startX;
                        startX = endX;
                        endX = tmp;
                    }
                    
                    bool tillEndOfLine = false;
                    if (intersectionRange.location + intersectionRange.length >= (NSUInteger)(lineRange.location + lineRange.length) && ABS(endX - layoutSize.width) < 16)
                    {
                        tillEndOfLine = true;
                        endX = layoutSize.width + lineOrigin.x;
                    }
                    CGRect region = CGRectMake(CGCeil(startX - 3), CGCeil(lineOrigin.y - fontLineHeight + fontLineHeight * 0.1f), CGCeil(endX - startX + 6), CGCeil(fontLineSpacing));
                    
                    if (it->topRegion.size.height == 0)
                        it->topRegion = region;
                    else
                    {
                        if (it->middleRegion.size.height == 0)
                            it->middleRegion = region;
                        else if (intersectionRange.location == (NSUInteger)lineRange.location && intersectionRange.length == (NSUInteger)lineRange.length && tillEndOfLine)
                            it->middleRegion.size.height += region.size.height;
                        else
                            it->bottomRegion = region;
                    }
                }
            }
        }
    }
    
    if (pLinkRanges != NULL)
        delete[] pLinkRanges;
    
    if (outIsRTL != NULL)
        *outIsRTL = resultHadRTL;
    
    return layout;
}

- (void)drawRect:(CGRect)__unused rect
{
    if (_richText)
        [TGReusableLabel drawRichTextInRect:self.bounds precalculatedLayout:_precalculatedLayout linesRange:NSMakeRange(0, 0) shadowColor:_shadowColor shadowOffset:_shadowOffset];
    else
        [TGReusableLabel drawTextInRect:self.bounds text:_text richText:_richText font:_font highlighted:_highlighted textColor:_textColor highlightedColor:_highlightedTextColor shadowColor:_shadowColor shadowOffset:_shadowOffset numberOfLines:_numberOfLines];
}

+ (void)drawTextInRect:(CGRect)rect text:(NSString *)text richText:(bool)richText font:(UIFont *)font highlighted:(bool)highlighted textColor:(UIColor *)textColor highlightedColor:(UIColor *)highlightedColor shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset numberOfLines:(int)numberOfLines
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!richText)
    {
        UIColor *effectiveColor = (highlighted && highlightedColor != nil) ? highlightedColor : textColor;
        UIColor *shadow = highlighted ? nil : shadowColor;

        if (iosMajorVersion() < 7)
        {
            CTFontRef coreTextFont = TGCoreTextFontForUIFont(font);
            if (coreTextFont != NULL)
            {
                TGReusableLabelLayoutData *layout = [TGReusableLabel calculateLayout:text additionalAttributes:nil textCheckingResults:nil font:coreTextFont textColor:effectiveColor linkColor:nil frame:CGRectZero orMaxWidth:rect.size.width flags:TGReusableLabelLayoutMultiline textAlignment:NSTextAlignmentLeft outIsRTL:NULL additionalTrailingWidth:0.0f maxNumberOfLines:numberOfLines <= 0 ? 0 : (NSUInteger)numberOfLines numberOfLinesToInset:0 linesInset:0.0f containsEmptyNewline:NULL additionalLineSpacing:0.0f ellipsisString:nil underlineAllLinks:false];
                CFRelease(coreTextFont);
                if (layout != nil)
                {
                    [TGReusableLabel drawRichTextInRect:rect precalculatedLayout:layout linesRange:NSMakeRange(0, 0) shadowColor:shadow shadowOffset:shadowOffset];
                    return;
                }
            }
        }

        CGContextSetFillColorWithColor(context, effectiveColor.CGColor);
        if (shadowColor != nil)
            CGContextSetShadowWithColor(context, shadowOffset, 0, shadow.CGColor);

        CGRect textRect = rect;
        [text drawInRect:textRect withFont:font lineBreakMode:(numberOfLines == 0 ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail)];
    }
}

+ (void)drawRichTextInRect:(CGRect)rect precalculatedLayout:(TGReusableLabelLayoutData *)precalculatedLayout linesRange:(NSRange)linesRange shadowColor:(UIColor *)shadowColor shadowOffset:(CGSize)shadowOffset
{
    CFArrayRef lines = (__bridge CFArrayRef)precalculatedLayout.textLines;
    if (lines == nil)
    {
#if TARGET_IPHONE_SIMULATOR
        TGLog(@"%s:%d: warning: lines is nil", __PRETTY_FUNCTION__, __LINE__);
#endif
        
        return;
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    if (shadowColor != nil)
        CGContextSetShadowWithColor(context, shadowOffset, 0, shadowColor.CGColor);
    
    CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, -1.0f));
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
    
    CGRect clipRect = CGContextGetClipBoundingBox(context);
    
    NSInteger numberOfLines = CFArrayGetCount(lines);
    
    if (linesRange.length == 0)
        linesRange = NSMakeRange(0, numberOfLines);
    
    const std::vector<TGLinePosition> *pLineOrigins = precalculatedLayout.lineOrigins;
    
    CGFloat cullingMargin = 4.0f + (shadowColor != nil ? MAX(ABS(shadowOffset.width), ABS(shadowOffset.height)) : 0.0f);
    CGFloat clipMinY = CGRectGetMinY(clipRect) - cullingMargin;
    CGFloat clipMaxY = CGRectGetMaxY(clipRect) + cullingMargin;
    bool useClipLineCulling = !CGRectIsNull(clipRect) && !CGRectIsInfinite(clipRect);
    
    for (CFIndex lineIndex = linesRange.location; lineIndex < (CFIndex)(linesRange.location + linesRange.length); lineIndex++)
    {
        CTLineRef line = (CTLineRef)CFArrayGetValueAtIndex(lines, lineIndex);
        
        TGLinePosition const &linePosition = pLineOrigins->at(lineIndex);
        
        CGFloat horizontalOffset = 0.0f;
        switch (linePosition.alignment)
        {
            case 1:
                horizontalOffset = CGFloor((rect.size.width - linePosition.lineWidth) / 2.0f);
                break;
            case 2:
                horizontalOffset = rect.size.width - linePosition.lineWidth;
                break;
            default:
                break;
        }
        
        CGPoint lineOrigin = CGPointMake(horizontalOffset + linePosition.horizontalOffset, linePosition.offset);
        
        if (useClipLineCulling)
        {
            CGFloat lineAscent = 0.0f;
            CGFloat lineDescent = 0.0f;
            CGFloat lineLeading = 0.0f;
            CTLineGetTypographicBounds(line, &lineAscent, &lineDescent, &lineLeading);
            if (lineOrigin.y + lineDescent + lineLeading < clipMinY || lineOrigin.y - lineAscent > clipMaxY)
                continue;
        }
        
        CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
        CFIndex glyphRunCount = CFArrayGetCount(glyphRuns);
        TGReusableLabelDrawLineDecorations(context, glyphRuns, lineOrigin, true);

        for (CFIndex runIndex = 0; runIndex < glyphRunCount; runIndex++)
        {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, runIndex);
            CFDictionaryRef attributes = CTRunGetAttributes(run);
            if (attributes != NULL && CFDictionaryGetValue(attributes, kCTRunDelegateAttributeName) != NULL)
                continue;
            CGContextSaveGState(context);
            CGContextSetTextPosition(context, lineOrigin.x, lineOrigin.y);
            CTRunDraw(run, context, CFRangeMake(0, 0));
            CGContextRestoreGState(context);
        }

        for (CFIndex runIndex = 0; runIndex < glyphRunCount; runIndex++)
        {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(glyphRuns, runIndex);
            CFDictionaryRef attributes = CTRunGetAttributes(run);
            CFStringRef emojiValue = (CFStringRef)CFDictionaryGetValue(attributes, CFSTR("TGOnegramEmoji"));
            CFNumberRef trailingSpacingValue = (CFNumberRef)CFDictionaryGetValue(attributes, CFSTR("TGOnegramEmojiTrailingSpacing"));
            CFIndex emojiGlyphCount = CTRunGetGlyphCount(run);
            if (emojiValue == NULL || emojiGlyphCount == 0)
                continue;
            if (TGReusableLabelRunDecorationForRun(run).coverColor != nil)
                continue;

            CGPoint runPosition = CGPointZero;
            CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
            CGFloat ascent = 0.0f;
            CGFloat descent = 0.0f;
            CGFloat runWidth = (CGFloat)CTRunGetTypographicBounds(run, CFRangeMake(0, emojiGlyphCount), &ascent, &descent, NULL);
            CGFloat imageSize = MAX(1.0f, ascent + descent);
            CGFloat trailingSpacing = 0.0f;
            if (trailingSpacingValue != NULL)
                CFNumberGetValue(trailingSpacingValue, kCFNumberCGFloatType, &trailingSpacing);
            CGFloat contentWidth = MAX(1.0f, runWidth - trailingSpacing);
            UIImage *emojiImage = TGReusableLabelEmojiImage((__bridge NSString *)emojiValue, imageSize);
            if (emojiImage != nil)
            {
                CGFloat imageX = lineOrigin.x + runPosition.x + (contentWidth - imageSize) / 2.0f;
                CGFloat imageY = lineOrigin.y - ascent;
                [emojiImage drawInRect:CGRectMake(imageX, imageY, imageSize, imageSize)];
            }
        }

        TGReusableLabelDrawLineDecorations(context, glyphRuns, lineOrigin, false);
    }

    CGContextRestoreGState(context);
}

@end
