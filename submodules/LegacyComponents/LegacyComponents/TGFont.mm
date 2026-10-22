#import "TGFont.h"
#import "../../../OnegramRuntime/OGRuntime.h"
#import "../../../OnegramPlatform/OGPlatformDispatch.h"

#import "LegacyComponentsInternal.h"
#import "NSObject+TGLock.h"
#import "TGEmojiPackIndexTable.h"

#import <map>
#import <vector>
#import <string>

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

static NSDictionary *TGEmojiPackIndex = nil;
static bool TGEmojiPackIndexTableValid = false;
static NSFileHandle *TGEmojiPackHandle = nil;
static NSCache *TGEmojiImageCache = nil;
static NSObject *TGEmojiFileLock = nil;
static NSMutableDictionary *TGEmojiSupportCache = nil;
static NSObject *TGEmojiImageWorkLock = nil;
static NSMutableSet *TGEmojiImageWorkInFlight = nil;
static NSMutableDictionary *TGEmojiImageWorkCompletions = nil;

static NSString *const TGEmojiRenderModeDefaultsKey = @"TGEmojiRenderMode";

static volatile int TGEmojiStoredRenderMode = -1;

TGEmojiRenderMode TGCurrentEmojiRenderMode(void)
{
    int storedMode = TGEmojiStoredRenderMode;
    if (storedMode >= 0)
        return (TGEmojiRenderMode)storedMode;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *value = [defaults objectForKey:TGEmojiRenderModeDefaultsKey];
    TGEmojiRenderMode mode = TGEmojiRenderModeCombined;
    if (value != nil)
    {
        NSInteger storedValue = [value integerValue];
        if (storedValue >= TGEmojiRenderModeStockOnly && storedValue <= TGEmojiRenderModeCombined)
            mode = (TGEmojiRenderMode)storedValue;
    }
    
    TGEmojiStoredRenderMode = (int)mode;
    return mode;
}

void TGSetEmojiRenderMode(TGEmojiRenderMode mode)
{
    if (mode < TGEmojiRenderModeStockOnly || mode > TGEmojiRenderModeCombined)
        mode = TGEmojiRenderModeCombined;

    [[NSUserDefaults standardUserDefaults] setObject:@((NSInteger)mode) forKey:TGEmojiRenderModeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    TGEmojiStoredRenderMode = (int)mode;

    if (TGEmojiImageCache != nil)
        [TGEmojiImageCache removeAllObjects];
}

static void TGEmojiLoadPack(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *packPath = [[NSBundle mainBundle] pathForResource:@"OnegramEmoji" ofType:@"pack"];
        TGEmojiPackHandle = packPath == nil ? nil : [NSFileHandle fileHandleForReadingAtPath:packPath];
        if (TGEmojiPackHandle != nil)
        {
            NSDictionary *packAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:packPath error:NULL];
            TGEmojiPackIndexTableValid = [packAttributes fileSize] == TGEmojiPackIndexTablePackSize;
        }
        if (!TGEmojiPackIndexTableValid)
        {
            NSString *indexPath = [[NSBundle mainBundle] pathForResource:@"OnegramEmojiIndex" ofType:@"plist"];
            TGEmojiPackIndex = [NSDictionary dictionaryWithContentsOfFile:indexPath];
        }
        TGEmojiImageCache = [[NSCache alloc] init];
        TGEmojiImageCache.countLimit = iosMajorVersion() <= 3 ? 128 : 256;
        TGEmojiFileLock = [[NSObject alloc] init];
        TGEmojiSupportCache = [[NSMutableDictionary alloc] init];

    });
}

void TGPreloadEmojiPack(void)
{
    TGEmojiLoadPack();
}

void TGClearEmojiImageCache(void)
{
    if (TGEmojiImageCache != nil)
        [TGEmojiImageCache removeAllObjects];
}

static void TGEmojiEnsureImageWorkState(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        TGEmojiImageWorkLock = [[NSObject alloc] init];
        TGEmojiImageWorkInFlight = [[NSMutableSet alloc] init];
        TGEmojiImageWorkCompletions = [[NSMutableDictionary alloc] init];
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

static bool TGEmojiPackAvailable(void)
{
    return TGEmojiPackIndexTableValid || TGEmojiPackIndex.count != 0;
}

static int TGEmojiPackCompareCodepoints(uint32_t const *lhs, uint32_t lhsCount, uint32_t const *rhs, uint32_t rhsCount)
{
    uint32_t count = lhsCount < rhsCount ? lhsCount : rhsCount;
    for (uint32_t i = 0; i < count; i++)
    {
        if (lhs[i] != rhs[i])
            return lhs[i] < rhs[i] ? -1 : 1;
    }
    if (lhsCount == rhsCount)
        return 0;
    return lhsCount < rhsCount ? -1 : 1;
}

static bool TGEmojiPackLookup(uint32_t const *codepoints, NSUInteger count, uint32_t *packOffset, uint32_t *packLength)
{
    if (count == 0)
        return false;

    if (TGEmojiPackIndexTableValid)
    {
        if (count > TGEmojiPackIndexTableMaxCodepoints)
            return false;

        uint32_t lower = 0;
        uint32_t upper = TGEmojiPackIndexTableCount;
        while (lower < upper)
        {
            uint32_t middle = lower + (upper - lower) / 2;
            TGEmojiPackIndexTableEntry const *entry = &TGEmojiPackIndexTableEntries[middle];
            int comparison = TGEmojiPackCompareCodepoints(TGEmojiPackIndexTableCodepoints + entry->codepointsOffset, entry->codepointsCount, codepoints, (uint32_t)count);
            if (comparison == 0)
            {
                if (packOffset != NULL)
                    *packOffset = entry->packOffset;
                if (packLength != NULL)
                    *packLength = entry->packLength;
                return true;
            }
            if (comparison < 0)
                lower = middle + 1;
            else
                upper = middle;
        }
        return false;
    }

    if (TGEmojiPackIndex.count == 0)
        return false;

    NSMutableString *key = [[NSMutableString alloc] init];
    for (NSUInteger i = 0; i < count; i++)
    {
        if (i != 0)
            [key appendString:@"-"];
        [key appendFormat:@"%x", (unsigned int)codepoints[i]];
    }

    NSData *entry = [TGEmojiPackIndex objectForKey:key];
    if (entry == nil)
        return false;
    if (packOffset == NULL && packLength == NULL)
        return true;
    if (entry.length != 8)
        return false;

    uint32_t values[2] = {0, 0};
    [entry getBytes:values length:sizeof(values)];
    if (packOffset != NULL)
        *packOffset = CFSwapInt32BigToHost(values[0]);
    if (packLength != NULL)
        *packLength = CFSwapInt32BigToHost(values[1]);
    return true;
}

static NSUInteger TGEmojiPackCodepoints(NSString *emoji, uint32_t *codepoints, NSUInteger capacity)
{
    NSUInteger count = 0;
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

        if (count == capacity)
            return 0;
        codepoints[count++] = codepoint;
    }
    return count;
}

static const NSUInteger TGEmojiKeyBufferCapacity = 192;

static NSUInteger TGEmojiKeyAppendHex(unichar *buffer, NSUInteger position, uint32_t value)
{
    static const char digits[] = "0123456789abcdef";
    unichar reversed[8];
    NSUInteger count = 0;
    do
    {
        reversed[count++] = (unichar)digits[value & 0xf];
        value >>= 4;
    } while (value != 0 && count < 8);
    
    if (position + count > TGEmojiKeyBufferCapacity)
        return NSNotFound;
    
    while (count != 0)
        buffer[position++] = reversed[--count];
    return position;
}

static NSUInteger TGEmojiKeyAppendDecimal(unichar *buffer, NSUInteger position, long value)
{
    if (position == NSNotFound)
        return NSNotFound;
    
    unsigned long magnitude = value < 0 ? (unsigned long)(-(value + 1)) + 1 : (unsigned long)value;
    unichar reversed[24];
    NSUInteger count = 0;
    do
    {
        reversed[count++] = (unichar)('0' + (magnitude % 10));
        magnitude /= 10;
    } while (magnitude != 0 && count < 24);
    
    if (position + count + (value < 0 ? 2 : 1) > TGEmojiKeyBufferCapacity)
        return NSNotFound;
    
    buffer[position++] = '/';
    if (value < 0)
        buffer[position++] = '-';
    while (count != 0)
        buffer[position++] = reversed[--count];
    return position;
}

static NSUInteger TGEmojiWritePackKey(NSString *emoji, unichar *buffer)
{
    NSUInteger position = 0;
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
        
        if (position != 0)
        {
            if (position + 1 > TGEmojiKeyBufferCapacity)
                return NSNotFound;
            buffer[position++] = '-';
        }
        position = TGEmojiKeyAppendHex(buffer, position, codepoint);
        if (position == NSNotFound)
            return NSNotFound;
    }
    return position;
}

static NSString *TGEmojiPackKey(NSString *emoji)
{
    if (emoji.length == 0)
        return nil;
    
    unichar buffer[TGEmojiKeyBufferCapacity];
    NSUInteger keyLength = TGEmojiWritePackKey(emoji, buffer);
    if (keyLength != NSNotFound)
        return keyLength == 0 ? nil : [[NSString alloc] initWithCharacters:buffer length:keyLength];

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
    if (!TGEmojiPackAvailable())
        return false;
    uint32_t codepoints[16];
    NSUInteger codepointsCount = 0;
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

        codepoints[codepointsCount++] = codepoint;
        cursor += codepointLength;
        steps++;
        if (TGEmojiPackLookup(codepoints, codepointsCount, NULL, NULL))
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
    uint32_t codepoints[16];
    NSUInteger codepointsCount = TGEmojiPackCodepoints(emoji, codepoints, sizeof(codepoints) / sizeof(codepoints[0]));
    if (!TGEmojiPackLookup(codepoints, codepointsCount, NULL, NULL))
        return false;
    if (!TGEmojiStringUsesEmojiPresentation(emoji))
        return false;

    return true;
}

#if OG_PLATFORM_HAS_CORETEXT
static bool TGEmojiFontContainsCharacters(CTFontRef font, NSString *emoji)
{
    CFCharacterSetRef characters = CTFontCopyCharacterSet(font);
    if (characters == NULL)
        return false;

    bool supported = true;
    for (NSUInteger index = 0; index < emoji.length; )
    {
        uint32_t codepoint = 0;
        NSUInteger length = 0;
        if (!TGEmojiReadCodepoint(emoji, index, &codepoint, &length))
        {
            supported = false;
            break;
        }
        index += length;

        if (codepoint == 0x200d || codepoint == 0xfe0e || codepoint == 0xfe0f || (codepoint >= 0xe0020 && codepoint <= 0xe007f))
            continue;
        if (!CFCharacterSetIsLongCharacterMember(characters, codepoint))
        {
            supported = false;
            break;
        }
    }

    CFRelease(characters);
    return supported;
}
#endif

static bool TGEmojiNativeGlyphSupported(NSString *emoji)
{
#if OG_PLATFORM_HAS_CORETEXT
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
        if (!TGEmojiFontContainsCharacters(emojiFont, emoji))
        {
            CFRelease(emojiFont);
            @synchronized(TGEmojiSupportCache)
            {
                [TGEmojiSupportCache setObject:[NSNumber numberWithBool:false] forKey:emoji];
            }
            return false;
        }

        NSString *layoutEmoji = emoji;
        if (iosMajorVersion() >= 4 && iosMajorVersion() < 7)
        {
            NSMutableString *visibleEmoji = [[NSMutableString alloc] initWithCapacity:emoji.length];
            for (NSUInteger index = 0; index < emoji.length; )
            {
                uint32_t codepoint = 0;
                NSUInteger length = 0;
                if (!TGEmojiReadCodepoint(emoji, index, &codepoint, &length))
                    break;
                if (!(codepoint == 0x200d || codepoint == 0xfe0e || codepoint == 0xfe0f || (codepoint >= 0xe0020 && codepoint <= 0xe007f)))
                    [visibleEmoji appendString:[emoji substringWithRange:NSMakeRange(index, length)]];
                index += length;
            }
            layoutEmoji = visibleEmoji;
        }

        CFStringRef emojiFontName = CTFontCopyPostScriptName(emojiFont);
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:(__bridge id)emojiFont forKey:(__bridge NSString *)kCTFontAttributeName];
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:layoutEmoji attributes:attributes];
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
#else
    return false;
#endif
}

bool TGEmojiNeedsPack(NSString *emoji)
{
    if (!TGEmojiPackContainsEmoji(emoji))
        return false;

    TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
    if (mode == TGEmojiRenderModeStockOnly)
        return false;
    if (mode == TGEmojiRenderModeCombined && TGEmojiStringUsesEmojiPresentation(emoji) && TGEmojiNativeGlyphSupported(emoji))
        return false;

    return true;
}

static CGRect TGEmojiVisiblePixelBounds(UIImage *image)
{
    if (image == nil || image.CGImage == NULL)
        return CGRectZero;

    CGImageRef cgImage = image.CGImage;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0)
        return CGRectZero;

    uint8_t *alpha = (uint8_t *)calloc(width * height, sizeof(uint8_t));
    if (alpha == NULL)
        return CGRectZero;

    CGContextRef context = CGBitmapContextCreate(alpha, width, height, 8, width, NULL, kCGImageAlphaOnly);
    if (context == NULL)
    {
        free(alpha);
        return CGRectZero;
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
        return CGRectZero;

    return CGRectMake((CGFloat)minX, (CGFloat)minY, (CGFloat)(maxX - minX + 1), (CGFloat)(maxY - minY + 1));
}

static void TGEmojiBitmapDataRelease(void *info, const void *data, size_t size)
{
    (void)info;
    (void)size;
    free((void *)data);
}

static UIImage *TGNormalizeEmojiImage(UIImage *sourceImage, CGFloat size)
{
    if (sourceImage == nil || sourceImage.CGImage == NULL || size <= 0.0f)
        return nil;

    size_t pixelWidth = CGImageGetWidth(sourceImage.CGImage);
    size_t pixelHeight = CGImageGetHeight(sourceImage.CGImage);
    if (pixelWidth == 0 || pixelHeight == 0)
        return nil;

    CGRect visibleBounds = TGEmojiVisiblePixelBounds(sourceImage);
    CGFloat visibleExtent = MAX(visibleBounds.size.width, visibleBounds.size.height);
    if (visibleExtent <= 0.0f)
        return nil;

    CGImageRef visibleImage = CGImageCreateWithImageInRect(sourceImage.CGImage, visibleBounds);
    if (visibleImage == NULL)
        return nil;

    CGFloat scale = size * 0.96f / visibleExtent;

    CGSize drawSize = CGSizeMake(visibleBounds.size.width * scale, visibleBounds.size.height * scale);
    CGRect drawRect = CGRectMake(CGFloor((size - drawSize.width) / 2.0f), CGFloor((size - drawSize.height) / 2.0f), drawSize.width, drawSize.height);

    UIImage *result = nil;
    if (iosMajorVersion() < 4)
    {
        size_t outputWidth = (size_t)MAX(1.0f, CGCeil(size));
        size_t outputHeight = outputWidth;
        size_t bytesPerRow = outputWidth * 4;
        uint8_t *pixels = (uint8_t *)calloc(outputHeight, bytesPerRow);
        if (pixels != NULL)
        {
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            if (colorSpace != NULL)
            {
                CGContextRef context = CGBitmapContextCreate(pixels, outputWidth, outputHeight, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
                if (context != NULL)
                {
                    CGContextClearRect(context, CGRectMake(0.0f, 0.0f, outputWidth, outputHeight));
                    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
                    CGContextTranslateCTM(context, 0.0f, (CGFloat)outputHeight);
                    CGContextScaleCTM(context, 1.0f, -1.0f);
                    CGContextSaveGState(context);
                    CGContextTranslateCTM(context, CGRectGetMidX(drawRect), CGRectGetMidY(drawRect));
                    CGContextScaleCTM(context, 1.0f, -1.0f);
                    CGContextTranslateCTM(context, -CGRectGetMidX(drawRect), -CGRectGetMidY(drawRect));
                    CGContextDrawImage(context, drawRect, visibleImage);
                    CGContextRestoreGState(context);
                    CGContextRelease(context);

                    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, pixels, outputHeight * bytesPerRow, TGEmojiBitmapDataRelease);
                    if (provider != NULL)
                    {
                        CGImageRef image = CGImageCreate(outputWidth, outputHeight, 8, 32, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
                        if (image != NULL)
                        {
                            result = [UIImage imageWithCGImage:image];
                            CGImageRelease(image);
                        }
                        CGDataProviderRelease(provider);
                        pixels = NULL;
                    }
                }
                CGColorSpaceRelease(colorSpace);
            }
            if (pixels != NULL)
                free(pixels);
        }
    }
    else
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), false, 0.0f);
        [[[UIImage alloc] initWithCGImage:visibleImage] drawInRect:drawRect];
        result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    CGImageRelease(visibleImage);
    return result;
}

static UIImage *TGNativeEmojiImageOfSizeCurrentThread(NSString *emoji, CGFloat size)
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

static UIImage *TGNativeEmojiImageOfSize(NSString *emoji, CGFloat size)
{
    if (iosMajorVersion() < 4 && ![NSThread isMainThread])
        return nil;

    return TGNativeEmojiImageOfSizeCurrentThread(emoji, size);
}

static NSData *TGPackEmojiData(NSString *emoji)
{
    if (emoji.length == 0)
        return nil;

    TGEmojiLoadPack();

    uint32_t codepoints[16];
    NSUInteger codepointsCount = TGEmojiPackCodepoints(emoji, codepoints, sizeof(codepoints) / sizeof(codepoints[0]));
    uint32_t offset = 0;
    uint32_t length = 0;
    if (!TGEmojiPackLookup(codepoints, codepointsCount, &offset, &length) || TGEmojiPackHandle == nil)
        return nil;

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

    return pngData;
}

static UIImage *TGPackEmojiImageFromData(NSData *pngData, CGFloat size)
{
    if (pngData.length == 0 || size <= 0.0f)
        return nil;

    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pngData);
    if (provider == NULL)
        return nil;
    CGImageRef image = CGImageCreateWithPNGDataProvider(provider, NULL, false, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    if (image == NULL)
        return nil;
    UIImage *sourceImage = [UIImage imageWithCGImage:image];
    CGImageRelease(image);

    return TGNormalizeEmojiImage(sourceImage, size);
}

static UIImage *TGPackEmojiImageOfSize(NSString *emoji, CGFloat size)
{
    return TGPackEmojiImageFromData(TGPackEmojiData(emoji), size);
}

static NSString *TGEmojiImageCacheKey(NSString *emoji, CGFloat size)
{
    if (emoji.length == 0 || size <= 0.0f)
        return nil;

    static int screenScale = 0;
    if (screenScale == 0)
        screenScale = MAX(1, (int)[UIScreen mainScreen].scale);
    
    TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
    unichar buffer[TGEmojiKeyBufferCapacity];
    NSUInteger keyLength = TGEmojiWritePackKey(emoji, buffer);
    if (keyLength != NSNotFound && keyLength != 0)
    {
        keyLength = TGEmojiKeyAppendDecimal(buffer, keyLength, (long)lrintf(size * 10.0f));
        keyLength = TGEmojiKeyAppendDecimal(buffer, keyLength, (long)screenScale);
        keyLength = TGEmojiKeyAppendDecimal(buffer, keyLength, (long)mode);
        if (keyLength != NSNotFound)
            return [[NSString alloc] initWithCharacters:buffer length:keyLength];
    }
    
    NSString *key = TGEmojiPackKey(emoji);
    if (key.length == 0)
        return nil;

    return [NSString stringWithFormat:@"%@/%d/%d/%ld", key, (int)lrintf(size * 10.0f), screenScale, (long)mode];
}

UIImage *TGEmojiCachedImageOfSize(NSString *emoji, CGFloat size)
{
    if (TGEmojiImageCache == nil)
        return nil;

    NSString *cacheKey = TGEmojiImageCacheKey(emoji, size);
    if (cacheKey.length == 0)
        return nil;

    return [TGEmojiImageCache objectForKey:cacheKey];
}

UIImage *TGEmojiImageOfSize(NSString *emoji, CGFloat size)
{
    if (emoji.length == 0 || size <= 0.0f)
        return nil;

    TGEmojiLoadPack();

    NSString *cacheKey = TGEmojiImageCacheKey(emoji, size);
    if (cacheKey.length == 0)
        return nil;

    UIImage *cached = [TGEmojiImageCache objectForKey:cacheKey];
    if (cached != nil)
        return cached;

    TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
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

static NSArray *TGEmojiFinishImageWork(NSString *cacheKey)
{
    NSArray *completions = nil;
    @synchronized(TGEmojiImageWorkLock)
    {
        [TGEmojiImageWorkInFlight removeObject:cacheKey];
        completions = [[TGEmojiImageWorkCompletions objectForKey:cacheKey] copy];
        [TGEmojiImageWorkCompletions removeObjectForKey:cacheKey];
    }
    return completions;
}

static void TGEmojiRunImageWorkCompletions(NSArray *completions)
{
    if (completions.count == 0)
        return;

    for (void (^block)(void) in completions)
        block();
}

static void TGEmojiFinishLegacyImageRender(NSString *cacheKey, UIImage *image)
{
    OGPlatformDispatchOnMainThread(^
    {
        if (image != nil)
            [TGEmojiImageCache setObject:image forKey:cacheKey];
        NSArray *completions = TGEmojiFinishImageWork(cacheKey);
        if (image != nil)
            TGEmojiRunImageWorkCompletions(completions);
    });
}

static void TGEmojiRenderLegacyPackImage(CGFloat size, NSString *cacheKey, NSData *packData)
{
    OGRuntimeDispatch(OGRuntimePriorityUtility, ^
    {
        @autoreleasepool
        {
            TGEmojiFinishLegacyImageRender(cacheKey, TGPackEmojiImageFromData(packData, size));
        }
    });
}

static void TGEmojiScheduleLegacyNativeImageRender(NSString *emoji, CGFloat size, NSString *cacheKey, NSData *packData)
{
    OGPlatformDispatchOnMainThread(^
    {
        if (OGRuntimeInteractionActiveFast())
        {
            OGPlatformDispatchOnMainThreadAfter(0.08, ^
            {
                TGEmojiScheduleLegacyNativeImageRender(emoji, size, cacheKey, packData);
            });
            return;
        }

        UIImage *result = TGNativeEmojiImageOfSizeCurrentThread(emoji, size);
        if (result == nil && TGCurrentEmojiRenderMode() != TGEmojiRenderModeStockOnly)
        {
            TGEmojiRenderLegacyPackImage(size, cacheKey, packData);
            return;
        }
        TGEmojiFinishLegacyImageRender(cacheKey, result);
    });
}

static void TGEmojiScheduleLegacyImageRender(NSString *emoji, CGFloat size, NSString *cacheKey, NSData *packData)
{
    UIImage *cached = [TGEmojiImageCache objectForKey:cacheKey];
    if (cached != nil)
    {
        TGEmojiFinishLegacyImageRender(cacheKey, cached);
        return;
    }

    TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
    if (mode != TGEmojiRenderModeNewOnly && TGEmojiStringUsesEmojiPresentation(emoji) && TGEmojiNativeGlyphSupported(emoji))
    {
        TGEmojiScheduleLegacyNativeImageRender(emoji, size, cacheKey, packData);
        return;
    }

    TGEmojiFinishLegacyImageRender(cacheKey, mode == TGEmojiRenderModeStockOnly ? nil : TGPackEmojiImageFromData(packData, size));
}

void TGPreloadEmojiImageOfSize(NSString *emoji, CGFloat size, void (^completion)(void))
{
    if (emoji.length == 0 || size <= 0.0f)
        return;

    UIImage *cached = TGEmojiCachedImageOfSize(emoji, size);
    if (cached != nil)
    {
        if (completion != nil)
            OGPlatformDispatchOnMainThread(completion);
        return;
    }

    NSString *cacheKey = TGEmojiImageCacheKey(emoji, size);
    if (cacheKey.length == 0)
        return;

    TGEmojiEnsureImageWorkState();

    __block bool shouldStart = false;
    @synchronized(TGEmojiImageWorkLock)
    {
        if (completion != nil)
        {
            NSMutableArray *completions = [TGEmojiImageWorkCompletions objectForKey:cacheKey];
            if (completions == nil)
            {
                completions = [[NSMutableArray alloc] init];
                [TGEmojiImageWorkCompletions setObject:completions forKey:cacheKey];
            }
            [completions addObject:[completion copy]];
        }

        if (![TGEmojiImageWorkInFlight containsObject:cacheKey])
        {
            [TGEmojiImageWorkInFlight addObject:cacheKey];
            shouldStart = true;
        }
    }

    if (!shouldStart)
        return;

    NSString *emojiValue = [emoji copy];
    if (iosMajorVersion() < 4)
    {
        OGRuntimeDispatch(OGRuntimePriorityUtility, ^
        {
            @autoreleasepool
            {
                TGEmojiLoadPack();
                TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
                NSData *packData = mode == TGEmojiRenderModeStockOnly ? nil : TGPackEmojiData(emojiValue);
                TGEmojiScheduleLegacyImageRender(emojiValue, size, cacheKey, packData);
            }
        });
        return;
    }

    OGRuntimeDispatchPreload([@"emoji:" stringByAppendingString:cacheKey], ^
    {
        @autoreleasepool
        {
            UIImage *result = TGEmojiImageOfSize(emojiValue, size);
            NSArray *completions = TGEmojiFinishImageWork(cacheKey);
            if (result != nil && completions.count != 0)
            {
                OGPlatformDispatchOnMainThread(^
                {
                    TGEmojiRunImageWorkCompletions(completions);
                });
            }
        }
    });
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

#if OG_PLATFORM_HAS_CORETEXT
    if (iosMajorVersion() < 6)
        return CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);

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
#else
    return CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
#endif
}

static std::map<std::string, CTFontRef> &genericFontCache = *new std::map<std::string, CTFontRef>();
static pthread_mutex_t genericFontCacheMutex = PTHREAD_MUTEX_INITIALIZER;

CTFontRef TGCoreTextFontForUIFont(UIFont *font)
{
    if (font == nil)
        return NULL;

    const char *fontName = [font.fontName UTF8String];
    if (fontName == NULL)
        return TGCreateCoreTextFont(font);

    char keyBuffer[256];
    snprintf(keyBuffer, sizeof(keyBuffer), "%s/%d", fontName, (int)lrint(font.pointSize * 64.0f));
    std::string key(keyBuffer);

    pthread_mutex_lock(&genericFontCacheMutex);
    std::map<std::string, CTFontRef>::iterator it = genericFontCache.find(key);
    if (it != genericFontCache.end())
    {
        CTFontRef result = it->second;
        CFRetain(result);
        pthread_mutex_unlock(&genericFontCacheMutex);
        return result;
    }
    pthread_mutex_unlock(&genericFontCacheMutex);

    CTFontRef created = TGCreateCoreTextFont(font);
    if (created == NULL)
        return NULL;

    pthread_mutex_lock(&genericFontCacheMutex);
    it = genericFontCache.find(key);
    if (it == genericFontCache.end())
    {
        genericFontCache[key] = created;
        CFRetain(created);
    }
    else
    {
        CFRelease(created);
        created = it->second;
        CFRetain(created);
    }
    pthread_mutex_unlock(&genericFontCacheMutex);
    return created;
}

static std::map<int, CTFontRef> &systemFontCache = *new std::map<int, CTFontRef>();
static std::map<int, CTFontRef> &lightFontCache = *new std::map<int, CTFontRef>();
static std::map<int, CTFontRef> &mediumFontCache = *new std::map<int, CTFontRef>();
static std::map<int, CTFontRef> &boldFontCache = *new std::map<int, CTFontRef>();
static std::map<int, CTFontRef> &fixedFontCache = *new std::map<int, CTFontRef>();
static std::map<int, CTFontRef> &italicFontCache = *new std::map<int, CTFontRef>();
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
