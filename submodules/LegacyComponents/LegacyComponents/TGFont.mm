#import "TGFont.h"

#import "LegacyComponentsInternal.h"
#import "NSObject+TGLock.h"

#import <CoreText/CoreText.h>
#import <map>
#import <vector>

UIFont *TGSystemFontOfSize(CGFloat size)
{
    if (iosMajorVersion() >= 7)
        return [UIFont systemFontOfSize:size];

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:size];
    if (font == nil)
        font = [UIFont systemFontOfSize:size];
    return font;
}

UIFont *TGMediumSystemFontOfSize(CGFloat size)
{
    if (iosMajorVersion() >= 9)
        return [UIFont boldSystemFontOfSize:size];

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
    if (font == nil)
        font = [UIFont boldSystemFontOfSize:size];
    return font;
}

UIFont *TGSemiboldSystemFontOfSize(CGFloat size)
{
    if (iosMajorVersion() >= 9)
        return [UIFont boldSystemFontOfSize:size];

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
    if (font == nil)
        font = [UIFont boldSystemFontOfSize:size];
    return font;
}

UIFont *TGBoldSystemFontOfSize(CGFloat size)
{
    if (iosMajorVersion() >= 7)
        return [UIFont boldSystemFontOfSize:size];

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
    if (font == nil)
        font = [UIFont boldSystemFontOfSize:size];
    return font;
}

UIFont *TGLightSystemFontOfSize(CGFloat size)
{
    if (iosMajorVersion() >= 9)
        return [UIFont systemFontOfSize:size];

    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:size];
    if (font == nil)
        font = [UIFont systemFontOfSize:size];
    return font;
}

UIFont *TGUltralightSystemFontOfSize(CGFloat size)
{
    NSString *fontName = iosMajorVersion() >= 7 ? @"HelveticaNeue-Thin" : @"HelveticaNeue-Light";
    UIFont *font = [UIFont fontWithName:fontName size:size];
    if (font == nil)
        font = [UIFont systemFontOfSize:size];
    return font;
}

UIFont *TGItalicSystemFontOfSize(CGFloat size)
{
    return [UIFont italicSystemFontOfSize:size];
}

UIFont *TGFixedSystemFontOfSize(CGFloat size)
{
    return [UIFont fontWithName:@"Courier" size:size];
}

UIFont *TGEmojiFontOfSize(CGFloat size)
{
    UIFont *font = [UIFont fontWithName:@"AppleColorEmoji" size:size];
    if (font == nil)
        font = TGSystemFontOfSize(size);
    return font;
}

struct TGEmojiTrieNode
{
    std::map<uint32_t, TGEmojiTrieNode *> children;
    bool terminal;

    TGEmojiTrieNode() : terminal(false)
    {
    }
};

static NSDictionary *TGEmojiPackIndex = nil;
static NSFileHandle *TGEmojiPackHandle = nil;
static NSCache *TGEmojiImageCache = nil;
static NSObject *TGEmojiFileLock = nil;
static TGEmojiTrieNode *TGEmojiTrieRoot = NULL;
static NSMutableDictionary *TGEmojiSupportCache = nil;
static NSString *const TGEmojiRenderModeDefaultsKey = @"TGEmojiRenderMode";

TGEmojiRenderMode TGCurrentEmojiRenderMode(void)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *value = [defaults objectForKey:TGEmojiRenderModeDefaultsKey];
    if (value == nil)
        return TGEmojiRenderModeCombined;

    NSInteger mode = [value integerValue];
    if (mode < TGEmojiRenderModeStockOnly || mode > TGEmojiRenderModeCombined)
        return TGEmojiRenderModeCombined;

    return (TGEmojiRenderMode)mode;
}

void TGSetEmojiRenderMode(TGEmojiRenderMode mode)
{
    if (mode < TGEmojiRenderModeStockOnly || mode > TGEmojiRenderModeCombined)
        mode = TGEmojiRenderModeCombined;

    [[NSUserDefaults standardUserDefaults] setObject:@((NSInteger)mode) forKey:TGEmojiRenderModeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (TGEmojiImageCache != nil)
        [TGEmojiImageCache removeAllObjects];
}

static void TGEmojiLoadPack(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *indexPath = [[NSBundle mainBundle] pathForResource:@"OnegramEmojiIndex" ofType:@"plist"];
        NSString *packPath = [[NSBundle mainBundle] pathForResource:@"OnegramEmoji" ofType:@"pack"];
        TGEmojiPackIndex = [NSDictionary dictionaryWithContentsOfFile:indexPath];
        TGEmojiPackHandle = [NSFileHandle fileHandleForReadingAtPath:packPath];
        TGEmojiImageCache = [[NSCache alloc] init];
        TGEmojiImageCache.countLimit = 256;
        TGEmojiFileLock = [[NSObject alloc] init];
        TGEmojiSupportCache = [[NSMutableDictionary alloc] init];
        TGEmojiTrieRoot = new TGEmojiTrieNode();

        for (NSString *key in TGEmojiPackIndex)
        {
            TGEmojiTrieNode *node = TGEmojiTrieRoot;
            NSArray *parts = [key componentsSeparatedByString:@"-"];
            for (NSString *part in parts)
            {
                unsigned int value = 0;
                NSScanner *scanner = [NSScanner scannerWithString:part];
                if (![scanner scanHexInt:&value])
                {
                    node = NULL;
                    break;
                }

                TGEmojiTrieNode *next = NULL;
                std::map<uint32_t, TGEmojiTrieNode *>::iterator it = node->children.find(value);
                if (it == node->children.end())
                {
                    next = new TGEmojiTrieNode();
                    node->children[value] = next;
                }
                else
                {
                    next = it->second;
                }
                node = next;
            }

            if (node != NULL)
                node->terminal = true;
        }

        NSLog(@"EMOJI pack loaded=%d entries=%d", TGEmojiPackHandle != nil ? 1 : 0, (int)TGEmojiPackIndex.count);
    });
}

static bool TGEmojiReadCodepoint(NSString *text, NSUInteger index, uint32_t *codepoint, NSUInteger *length)
{
    if (text == nil || index >= text.length)
        return false;

    unichar high = [text characterAtIndex:index];
    uint32_t value = high;
    NSUInteger valueLength = 1;
    if (high >= 0xd800 && high <= 0xdbff && index + 1 < text.length)
    {
        unichar low = [text characterAtIndex:index + 1];
        if (low >= 0xdc00 && low <= 0xdfff)
        {
            value = 0x10000 + (((uint32_t)high - 0xd800) << 10) + ((uint32_t)low - 0xdc00);
            valueLength = 2;
        }
    }

    if (codepoint != NULL)
        *codepoint = value;
    if (length != NULL)
        *length = valueLength;
    return true;
}

static bool TGEmojiMayStartWithCodepoint(uint32_t codepoint)
{
    if (codepoint == 0x23 || codepoint == 0x2a || (codepoint >= 0x30 && codepoint <= 0x39) || codepoint == 0xa9 || codepoint == 0xae)
        return true;
    if ((codepoint >= 0x203c && codepoint <= 0x3299) || (codepoint >= 0x1f000 && codepoint <= 0x1ffff))
        return true;
    return false;
}

static NSString *TGEmojiPackKey(NSString *emoji)
{
    if (emoji.length == 0)
        return nil;

    NSMutableString *key = [[NSMutableString alloc] init];
    NSUInteger length = emoji.length;
    for (NSUInteger i = 0; i < length; )
    {
        uint32_t codepoint = 0;
        NSUInteger codepointLength = 0;
        if (!TGEmojiReadCodepoint(emoji, i, &codepoint, &codepointLength))
            break;
        i += codepointLength;

        if (codepoint == 0xfe0e || codepoint == 0xfe0f)
            continue;

        if (key.length != 0)
            [key appendString:@"-"];
        [key appendFormat:@"%x", (unsigned int)codepoint];
    }
    return key.length == 0 ? nil : key;
}

bool TGEmojiPackMatchAtIndex(NSString *text, NSUInteger index, NSRange *range)
{
    if (text == nil || index >= text.length)
        return false;

    uint32_t firstCodepoint = 0;
    if (!TGEmojiReadCodepoint(text, index, &firstCodepoint, NULL) || !TGEmojiMayStartWithCodepoint(firstCodepoint))
        return false;

    TGEmojiLoadPack();
    if (TGEmojiTrieRoot == NULL || TGEmojiPackIndex.count == 0)
        return false;

    TGEmojiTrieNode *node = TGEmojiTrieRoot;
    NSUInteger cursor = index;
    NSUInteger lastEnd = NSNotFound;
    bool textPresentation = false;
    int steps = 0;

    while (cursor < text.length && steps < 16)
    {
        uint32_t codepoint = 0;
        NSUInteger codepointLength = 0;
        if (!TGEmojiReadCodepoint(text, cursor, &codepoint, &codepointLength))
            break;

        if (codepoint == 0xfe0e)
        {
            textPresentation = true;
            cursor += codepointLength;
            if (lastEnd != NSNotFound)
                lastEnd = cursor;
            continue;
        }

        if (codepoint == 0xfe0f)
        {
            cursor += codepointLength;
            if (lastEnd != NSNotFound)
                lastEnd = cursor;
            continue;
        }

        std::map<uint32_t, TGEmojiTrieNode *>::iterator it = node->children.find(codepoint);
        if (it == node->children.end())
            break;

        node = it->second;
        cursor += codepointLength;
        steps++;
        if (node->terminal)
            lastEnd = cursor;
    }

    if (textPresentation || lastEnd == NSNotFound || lastEnd <= index)
        return false;

    if (range != NULL)
        *range = NSMakeRange(index, lastEnd - index);
    return true;
}

typedef struct
{
    uint32_t first;
    uint32_t last;
} TGEmojiCodepointRange;

static bool TGEmojiCodepointHasDefaultPresentation(uint32_t codepoint)
{
    static const TGEmojiCodepointRange ranges[] =
    {
        { 0x231a, 0x231b },
        { 0x23e9, 0x23ec },
        { 0x23f0, 0x23f0 },
        { 0x23f3, 0x23f3 },
        { 0x25fd, 0x25fe },
        { 0x2614, 0x2615 },
        { 0x2648, 0x2653 },
        { 0x267f, 0x267f },
        { 0x2693, 0x2693 },
        { 0x26a1, 0x26a1 },
        { 0x26aa, 0x26ab },
        { 0x26bd, 0x26be },
        { 0x26c4, 0x26c5 },
        { 0x26ce, 0x26ce },
        { 0x26d4, 0x26d4 },
        { 0x26ea, 0x26ea },
        { 0x26f2, 0x26f3 },
        { 0x26f5, 0x26f5 },
        { 0x26fa, 0x26fa },
        { 0x26fd, 0x26fd },
        { 0x2705, 0x2705 },
        { 0x270a, 0x270b },
        { 0x2728, 0x2728 },
        { 0x274c, 0x274c },
        { 0x274e, 0x274e },
        { 0x2753, 0x2755 },
        { 0x2757, 0x2757 },
        { 0x2795, 0x2797 },
        { 0x27b0, 0x27b0 },
        { 0x27bf, 0x27bf },
        { 0x2b1b, 0x2b1c },
        { 0x2b50, 0x2b50 },
        { 0x2b55, 0x2b55 },
        { 0x1f004, 0x1f004 },
        { 0x1f0cf, 0x1f0cf },
        { 0x1f18e, 0x1f18e },
        { 0x1f191, 0x1f19a },
        { 0x1f1e6, 0x1f1ff },
        { 0x1f201, 0x1f201 },
        { 0x1f21a, 0x1f21a },
        { 0x1f22f, 0x1f22f },
        { 0x1f232, 0x1f236 },
        { 0x1f238, 0x1f23a },
        { 0x1f250, 0x1f251 },
        { 0x1f300, 0x1f320 },
        { 0x1f32d, 0x1f335 },
        { 0x1f337, 0x1f37c },
        { 0x1f37e, 0x1f393 },
        { 0x1f3a0, 0x1f3ca },
        { 0x1f3cf, 0x1f3d3 },
        { 0x1f3e0, 0x1f3f0 },
        { 0x1f3f4, 0x1f3f4 },
        { 0x1f3f8, 0x1f43e },
        { 0x1f440, 0x1f440 },
        { 0x1f442, 0x1f4fc },
        { 0x1f4ff, 0x1f53d },
        { 0x1f54b, 0x1f54e },
        { 0x1f550, 0x1f567 },
        { 0x1f57a, 0x1f57a },
        { 0x1f595, 0x1f596 },
        { 0x1f5a4, 0x1f5a4 },
        { 0x1f5fb, 0x1f64f },
        { 0x1f680, 0x1f6c5 },
        { 0x1f6cc, 0x1f6cc },
        { 0x1f6d0, 0x1f6d2 },
        { 0x1f6d5, 0x1f6d8 },
        { 0x1f6dc, 0x1f6df },
        { 0x1f6eb, 0x1f6ec },
        { 0x1f6f4, 0x1f6fc },
        { 0x1f7e0, 0x1f7eb },
        { 0x1f7f0, 0x1f7f0 },
        { 0x1f90c, 0x1f93a },
        { 0x1f93c, 0x1f945 },
        { 0x1f947, 0x1f9ff },
        { 0x1fa70, 0x1fa7c },
        { 0x1fa80, 0x1fa8a },
        { 0x1fa8e, 0x1fac6 },
        { 0x1fac8, 0x1fac8 },
        { 0x1facd, 0x1fadc },
        { 0x1fadf, 0x1faea },
        { 0x1faef, 0x1faf8 },
    };

    int low = 0;
    int high = (int)(sizeof(ranges) / sizeof(ranges[0])) - 1;
    while (low <= high)
    {
        int middle = low + (high - low) / 2;
        if (codepoint < ranges[middle].first)
            high = middle - 1;
        else if (codepoint > ranges[middle].last)
            low = middle + 1;
        else
            return true;
    }
    return false;
}

static bool TGEmojiStringUsesEmojiPresentation(NSString *emoji)
{
    if (emoji.length == 0)
        return false;

    uint32_t firstCodepoint = 0;
    if (!TGEmojiReadCodepoint(emoji, 0, &firstCodepoint, NULL))
        return false;

    bool explicitEmojiPresentation = false;
    bool explicitTextPresentation = false;
    bool keycap = false;
    NSUInteger length = emoji.length;
    for (NSUInteger index = 0; index < length; )
    {
        uint32_t codepoint = 0;
        NSUInteger codepointLength = 0;
        if (!TGEmojiReadCodepoint(emoji, index, &codepoint, &codepointLength))
            break;
        index += codepointLength;

        if (codepoint == 0xfe0f)
            explicitEmojiPresentation = true;
        else if (codepoint == 0xfe0e)
            explicitTextPresentation = true;
        else if (codepoint == 0x20e3)
            keycap = true;
    }

    if (explicitTextPresentation)
        return false;
    if (keycap)
        return true;
    if (firstCodepoint == 0x23 || firstCodepoint == 0x2a || (firstCodepoint >= 0x30 && firstCodepoint <= 0x39))
        return false;
    if (explicitEmojiPresentation)
        return true;
    return TGEmojiCodepointHasDefaultPresentation(firstCodepoint);
}

static bool TGEmojiPackContainsEmoji(NSString *emoji)
{
    if (emoji.length == 0)
        return false;

    TGEmojiLoadPack();
    NSString *key = TGEmojiPackKey(emoji);
    if (key.length == 0 || [TGEmojiPackIndex objectForKey:key] == nil)
        return false;
    if (!TGEmojiStringUsesEmojiPresentation(emoji))
        return false;

    return true;
}

static bool TGEmojiNativeGlyphSupported(NSString *emoji)
{
    if (emoji.length == 0)
        return false;

    NSNumber *cached = nil;
    @synchronized(TGEmojiSupportCache)
    {
        cached = [TGEmojiSupportCache objectForKey:emoji];
    }
    if (cached != nil)
        return [cached boolValue];

    CTFontRef emojiFont = CTFontCreateWithName(CFSTR("AppleColorEmoji"), 20.0f, NULL);
    bool supported = false;
    if (emojiFont != NULL)
    {
        CFStringRef emojiFontName = CTFontCopyPostScriptName(emojiFont);
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:(__bridge id)emojiFont forKey:(__bridge NSString *)kCTFontAttributeName];
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:emoji attributes:attributes];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString);
        if (line != NULL)
        {
            CFArrayRef runs = CTLineGetGlyphRuns(line);
            CFIndex totalGlyphCount = 0;
            bool hasMissingGlyph = false;
            bool usesEmojiFont = true;
            CFIndex runCount = CFArrayGetCount(runs);
            for (CFIndex runIndex = 0; runIndex < runCount; runIndex++)
            {
                CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, runIndex);
                CFDictionaryRef runAttributes = CTRunGetAttributes(run);
                CTFontRef runFont = (CTFontRef)CFDictionaryGetValue(runAttributes, kCTFontAttributeName);
                CFStringRef runFontName = runFont == NULL ? NULL : CTFontCopyPostScriptName(runFont);
                if (emojiFontName == NULL || runFontName == NULL || !CFEqual(emojiFontName, runFontName))
                    usesEmojiFont = false;
                if (runFontName != NULL)
                    CFRelease(runFontName);

                CFIndex glyphCount = CTRunGetGlyphCount(run);
                totalGlyphCount += glyphCount;
                if (glyphCount != 0)
                {
                    std::vector<CGGlyph> glyphs((size_t)glyphCount);
                    CTRunGetGlyphs(run, CFRangeMake(0, glyphCount), &glyphs[0]);
                    for (CFIndex glyphIndex = 0; glyphIndex < glyphCount; glyphIndex++)
                    {
                        if (glyphs[(size_t)glyphIndex] == 0)
                        {
                            hasMissingGlyph = true;
                            break;
                        }
                    }
                }
            }
            supported = totalGlyphCount == 1 && !hasMissingGlyph && usesEmojiFont;
            CFRelease(line);
        }
        if (emojiFontName != NULL)
            CFRelease(emojiFontName);
        CFRelease(emojiFont);
    }

    @synchronized(TGEmojiSupportCache)
    {
        [TGEmojiSupportCache setObject:[NSNumber numberWithBool:supported] forKey:emoji];
    }
    return supported;
}

bool TGEmojiNeedsPack(NSString *emoji)
{
    if (!TGEmojiPackContainsEmoji(emoji))
        return false;

    TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
    if (mode == TGEmojiRenderModeStockOnly)
        return false;

    return true;
}

static CGSize TGEmojiVisiblePixelSize(UIImage *image)
{
    if (image == nil || image.CGImage == NULL)
        return CGSizeZero;

    CGImageRef cgImage = image.CGImage;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0)
        return CGSizeZero;

    uint8_t *alpha = (uint8_t *)calloc(width * height, sizeof(uint8_t));
    if (alpha == NULL)
        return CGSizeZero;

    CGContextRef context = CGBitmapContextCreate(alpha, width, height, 8, width, NULL, kCGImageAlphaOnly);
    if (context == NULL)
    {
        free(alpha);
        return CGSizeZero;
    }

    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, width, height), cgImage);

    size_t minX = width;
    size_t minY = height;
    size_t maxX = 0;
    size_t maxY = 0;
    bool found = false;

    for (size_t y = 0; y < height; y++)
    {
        uint8_t *row = alpha + y * width;
        for (size_t x = 0; x < width; x++)
        {
            if (row[x] > 8)
            {
                if (!found)
                {
                    minX = maxX = x;
                    minY = maxY = y;
                    found = true;
                }
                else
                {
                    if (x < minX)
                        minX = x;
                    if (x > maxX)
                        maxX = x;
                    if (y < minY)
                        minY = y;
                    if (y > maxY)
                        maxY = y;
                }
            }
        }
    }

    CGContextRelease(context);
    free(alpha);

    if (!found)
        return CGSizeZero;

    return CGSizeMake((CGFloat)(maxX - minX + 1), (CGFloat)(maxY - minY + 1));
}

static UIImage *TGNormalizeEmojiImage(UIImage *sourceImage, CGFloat size)
{
    if (sourceImage == nil || sourceImage.CGImage == NULL || size <= 0.0f)
        return nil;

    size_t pixelWidth = CGImageGetWidth(sourceImage.CGImage);
    size_t pixelHeight = CGImageGetHeight(sourceImage.CGImage);
    if (pixelWidth == 0 || pixelHeight == 0)
        return nil;

    CGSize visibleSize = TGEmojiVisiblePixelSize(sourceImage);
    CGFloat visibleExtent = MAX(visibleSize.width, visibleSize.height);
    if (visibleExtent <= 0.0f)
        return nil;

    CGFloat scale = size * 0.96f / visibleExtent;

    CGSize drawSize = CGSizeMake((CGFloat)pixelWidth * scale, (CGFloat)pixelHeight * scale);
    CGRect drawRect = CGRectMake(CGFloor((size - drawSize.width) / 2.0f), CGFloor((size - drawSize.height) / 2.0f), drawSize.width, drawSize.height);

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), false, 0.0f);
    [sourceImage drawInRect:drawRect];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

static UIImage *TGNativeEmojiImageOfSize(NSString *emoji, CGFloat size)
{
    if (emoji.length == 0 || size <= 0.0f)
        return nil;
    if (!TGEmojiStringUsesEmojiPresentation(emoji))
        return nil;
    if (!TGEmojiNativeGlyphSupported(emoji))
        return nil;

    UIFont *font = TGEmojiFontOfSize(size);
    if (font == nil)
        return nil;

    CGSize glyphSize = [emoji sizeWithFont:font];
    CGSize canvasSize = CGSizeMake(MAX(size, CGCeil(glyphSize.width)) + 4.0f, MAX(size, CGCeil(glyphSize.height)) + 4.0f);
    UIGraphicsBeginImageContextWithOptions(canvasSize, false, 1.0f);
    CGFloat drawX = CGFloor((canvasSize.width - glyphSize.width) / 2.0f);
    CGFloat drawY = CGFloor((canvasSize.height - glyphSize.height) / 2.0f);
    [emoji drawAtPoint:CGPointMake(drawX, drawY) withFont:font];
    UIImage *sourceImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return TGNormalizeEmojiImage(sourceImage, size);
}

static UIImage *TGPackEmojiImageOfSize(NSString *emoji, CGFloat size)
{
    if (emoji.length == 0 || size <= 0.0f)
        return nil;

    TGEmojiLoadPack();

    NSString *key = TGEmojiPackKey(emoji);
    if (key.length == 0)
        return nil;

    NSData *entry = [TGEmojiPackIndex objectForKey:key];
    if (entry.length != 8 || TGEmojiPackHandle == nil)
        return nil;

    uint32_t values[2] = {0, 0};
    [entry getBytes:values length:sizeof(values)];
    uint32_t offset = CFSwapInt32BigToHost(values[0]);
    uint32_t length = CFSwapInt32BigToHost(values[1]);
    if (length == 0)
        return nil;

    NSData *pngData = nil;
    @synchronized(TGEmojiFileLock)
    {
        [TGEmojiPackHandle seekToFileOffset:offset];
        pngData = [TGEmojiPackHandle readDataOfLength:length];
    }
    if (pngData.length != length)
        return nil;

    UIImage *sourceImage = [UIImage imageWithData:pngData];
    if (sourceImage == nil)
        return nil;

    return TGNormalizeEmojiImage(sourceImage, size);
}

UIImage *TGEmojiImageOfSize(NSString *emoji, CGFloat size)
{
    if (emoji.length == 0 || size <= 0.0f)
        return nil;

    TGEmojiLoadPack();

    NSString *key = TGEmojiPackKey(emoji);
    if (key.length == 0)
        return nil;

    TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
    NSString *cacheKey = [NSString stringWithFormat:@"%@/%d/%d/%ld", key, (int)lrintf(size * 10.0f), (int)[UIScreen mainScreen].scale, (long)mode];
    UIImage *cached = [TGEmojiImageCache objectForKey:cacheKey];
    if (cached != nil)
        return cached;

    UIImage *result = nil;
    if (mode == TGEmojiRenderModeStockOnly)
    {
        result = TGNativeEmojiImageOfSize(emoji, size);
    }
    else if (mode == TGEmojiRenderModeNewOnly)
    {
        result = TGPackEmojiImageOfSize(emoji, size);
    }
    else
    {
        result = TGNativeEmojiImageOfSize(emoji, size);
        if (result == nil)
            result = TGPackEmojiImageOfSize(emoji, size);
    }

    if (result != nil)
        [TGEmojiImageCache setObject:result forKey:cacheKey];
    return result;
}

CTFontRef TGCoreTextFontForUIFont(UIFont *font);

@implementation TGFont

+ (UIFont *)systemFontOfSize:(CGFloat)size
{
    return TGSystemFontOfSize(size);
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size
{
    return TGBoldSystemFontOfSize(size);
}

+ (UIFont *)roundedFontOfSize:(CGFloat)size
{
    return [UIFont fontWithName:@".SFCompactRounded-Semibold" size:size];
}

@end

static CTFontRef TGCreateCoreTextFont(UIFont *font)
{
    if (font == nil)
        return NULL;

    CTFontRef result = NULL;
    CTFontDescriptorRef baseDescriptor = CTFontDescriptorCreateWithNameAndSize((__bridge CFStringRef)font.fontName, font.pointSize);
    UIFont *appleEmojiFont = [UIFont fontWithName:@"AppleColorEmoji" size:font.pointSize];
    UIFont *notoSansFont = [UIFont fontWithName:@"NotoSans-Regular" size:font.pointSize];
    UIFont *notoMathFont = [UIFont fontWithName:@"NotoSansMath-Regular" size:font.pointSize];
    UIFont *notoSymbolsFont = [UIFont fontWithName:@"NotoSansSymbols2-Regular" size:font.pointSize];
    CTFontDescriptorRef appleEmojiDescriptor = appleEmojiFont == nil ? NULL : CTFontDescriptorCreateWithNameAndSize((__bridge CFStringRef)appleEmojiFont.fontName, font.pointSize);
    CTFontDescriptorRef notoSansDescriptor = notoSansFont == nil ? NULL : CTFontDescriptorCreateWithNameAndSize((__bridge CFStringRef)notoSansFont.fontName, font.pointSize);
    CTFontDescriptorRef notoMathDescriptor = notoMathFont == nil ? NULL : CTFontDescriptorCreateWithNameAndSize((__bridge CFStringRef)notoMathFont.fontName, font.pointSize);
    CTFontDescriptorRef notoSymbolsDescriptor = notoSymbolsFont == nil ? NULL : CTFontDescriptorCreateWithNameAndSize((__bridge CFStringRef)notoSymbolsFont.fontName, font.pointSize);

    static dispatch_once_t logOnceToken;
    dispatch_once(&logOnceToken, ^
    {
        NSLog(@"UNICODE fonts appleEmoji=%d notoSans=%d notoMath=%d notoSymbols=%d", appleEmojiFont != nil ? 1 : 0, notoSansFont != nil ? 1 : 0, notoMathFont != nil ? 1 : 0, notoSymbolsFont != nil ? 1 : 0);
    });

    if (iosMajorVersion() >= 6 && baseDescriptor != NULL)
    {
        const void *cascadeValues[4];
        CFIndex cascadeCount = 0;
        if (appleEmojiDescriptor != NULL)
            cascadeValues[cascadeCount++] = appleEmojiDescriptor;
        if (notoSansDescriptor != NULL)
            cascadeValues[cascadeCount++] = notoSansDescriptor;
        if (notoMathDescriptor != NULL)
            cascadeValues[cascadeCount++] = notoMathDescriptor;
        if (notoSymbolsDescriptor != NULL)
            cascadeValues[cascadeCount++] = notoSymbolsDescriptor;

        if (cascadeCount != 0)
        {
            CFArrayRef cascadeList = CFArrayCreate(kCFAllocatorDefault, cascadeValues, cascadeCount, &kCFTypeArrayCallBacks);
            if (cascadeList != NULL)
            {
                const void *attributeKeys[] = { kCTFontCascadeListAttribute };
                const void *attributeValues[] = { cascadeList };
                CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, attributeKeys, attributeValues, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                if (attributes != NULL)
                {
                    CTFontDescriptorRef finalDescriptor = CTFontDescriptorCreateCopyWithAttributes(baseDescriptor, attributes);
                    if (finalDescriptor != NULL)
                    {
                        result = CTFontCreateWithFontDescriptor(finalDescriptor, font.pointSize, NULL);
                        CFRelease(finalDescriptor);
                    }
                    CFRelease(attributes);
                }
                CFRelease(cascadeList);
            }
        }
    }

    if (notoSymbolsDescriptor != NULL)
        CFRelease(notoSymbolsDescriptor);
    if (notoMathDescriptor != NULL)
        CFRelease(notoMathDescriptor);
    if (notoSansDescriptor != NULL)
        CFRelease(notoSansDescriptor);
    if (appleEmojiDescriptor != NULL)
        CFRelease(appleEmojiDescriptor);
    if (baseDescriptor != NULL)
        CFRelease(baseDescriptor);

    if (result != NULL)
        return result;

    return CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
}

CTFontRef TGCoreTextFontForUIFont(UIFont *font)
{
    return TGCreateCoreTextFont(font);
}

static std::map<int, CTFontRef> systemFontCache;
static std::map<int, CTFontRef> lightFontCache;
static std::map<int, CTFontRef> mediumFontCache;
static std::map<int, CTFontRef> boldFontCache;
static std::map<int, CTFontRef> fixedFontCache;
static std::map<int, CTFontRef> italicFontCache;
static TG_SYNCHRONIZED_DEFINE(systemFontCache) = PTHREAD_MUTEX_INITIALIZER;

CTFontRef TGCoreTextSystemFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    
    auto it = systemFontCache.find(key);
    
    if (it != systemFontCache.end())
    {
        result = it->second;
    }
    else
    {
        UIFont *systemFont = TGSystemFontOfSize(size);
        result = TGCreateCoreTextFont(systemFont);
        systemFontCache[key] = result;
    }
    
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextLightFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    
    auto it = lightFontCache.find(key);
    
    if (it != lightFontCache.end())
    {
        result = it->second;
    }
    else
    {
        UIFont *systemFont = TGLightSystemFontOfSize(size);
        result = TGCreateCoreTextFont(systemFont);
        lightFontCache[key] = result;
    }
    
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextMediumFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    
    auto it = mediumFontCache.find(key);
    
    if (it != mediumFontCache.end())
    {
        result = it->second;
    }
    else
    {
        UIFont *systemFont = TGMediumSystemFontOfSize(size);
        result = TGCreateCoreTextFont(systemFont);
        mediumFontCache[key] = result;
    }
    
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextBoldFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    
    auto it = boldFontCache.find(key);
    
    if (it != boldFontCache.end())
    {
        result = it->second;
    }
    else
    {
        UIFont *systemFont = TGBoldSystemFontOfSize(size);
        result = TGCreateCoreTextFont(systemFont);
        boldFontCache[key] = result;
    }
    
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextFixedFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    
    auto it = fixedFontCache.find(key);
    
    if (it != fixedFontCache.end())
    {
        result = it->second;
    }
    else
    {
        CGFloat fixedSize = CGFloor(size * 2.0f) / 2.0f;
        UIFont *fixedFont = TGFixedSystemFontOfSize(fixedSize);
        result = TGCreateCoreTextFont(fixedFont);
        fixedFontCache[key] = result;
    }
    
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}

CTFontRef TGCoreTextItalicFontOfSize(CGFloat size)
{
    int key = (int)(size * 2.0f);
    CTFontRef result = NULL;
    
    TG_SYNCHRONIZED_BEGIN(systemFontCache);
    
    auto it = italicFontCache.find(key);
    
    if (it != italicFontCache.end())
    {
        result = it->second;
    }
    else
    {
        UIFont *systemFont = TGItalicSystemFontOfSize(size);
        result = TGCreateCoreTextFont(systemFont);
        italicFontCache[key] = result;
    }
    
    TG_SYNCHRONIZED_END(systemFontCache);
    
    return result;
}