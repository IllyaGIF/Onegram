#import "OGPlatformText.h"
#import <math.h>
#import "OGMemoryCache.h"
#import "OGFontCmap.h"
#import "OGUnicode.h"
#import <libkern/OSAtomic.h>

#if !OG_PLATFORM_HAS_CORETEXT

const CFStringRef kCTFontAttributeName = CFSTR("CTFont");
const CFStringRef kCTForegroundColorAttributeName = CFSTR("CTForegroundColor");
const CFStringRef kCTForegroundColorFromContextAttributeName = CFSTR("CTForegroundColorFromContext");
const CFStringRef kCTUnderlineStyleAttributeName = CFSTR("CTUnderlineStyle");
const CFStringRef kCTRunDelegateAttributeName = CFSTR("CTRunDelegate");

static NSString *const OGTextFontKey = @"f";
static NSString *const OGTextDelegateOwnerKey = @"o";

@interface OGPlatformRunDelegateOwner : NSObject
{
    CTRunDelegateCallbacks _callbacks;
    void *_refCon;
}
- (instancetype)initWithCallbacks:(const CTRunDelegateCallbacks *)callbacks refCon:(void *)refCon;
- (CGFloat)ascent;
- (CGFloat)descent;
- (CGFloat)width;
@end

@implementation OGPlatformRunDelegateOwner

- (instancetype)initWithCallbacks:(const CTRunDelegateCallbacks *)callbacks refCon:(void *)refCon
{
    self = [super init];
    if (self != nil)
    {
        _callbacks = *callbacks;
        _refCon = refCon;
    }
    return self;
}

- (void)dealloc
{
    if (_callbacks.dealloc != NULL)
        _callbacks.dealloc(_refCon);
}

- (CGFloat)ascent
{
    return _callbacks.getAscent == NULL ? 0.0f : _callbacks.getAscent(_refCon);
}

- (CGFloat)descent
{
    return _callbacks.getDescent == NULL ? 0.0f : _callbacks.getDescent(_refCon);
}

- (CGFloat)width
{
    return _callbacks.getWidth == NULL ? 0.0f : _callbacks.getWidth(_refCon);
}

@end

static id OGTextObject(CFTypeRef value)
{
    return value == NULL ? nil : (__bridge id)value;
}

static CFTypeRef OGTextCreateObject(id value)
{
    return value == nil ? NULL : (__bridge_retained CFTypeRef)value;
}

static UIFont *OGTextUIFont(CTFontRef font)
{
    id object = OGTextObject(font);
    if ([object isKindOfClass:[UIFont class]])
        return object;
    if ([object isKindOfClass:[NSDictionary class]])
    {
        id value = [object objectForKey:OGTextFontKey];
        if ([value isKindOfClass:[UIFont class]])
            return value;
    }
    return nil;
}

static UIFont *OGTextFontFromAttributes(NSDictionary *attributes)
{
    id value = [attributes objectForKey:(__bridge NSString *)kCTFontAttributeName];
    UIFont *font = OGTextUIFont((__bridge CTFontRef)value);
    if (font == nil)
    {
        value = [attributes objectForKey:@"NSFont"];
        if ([value isKindOfClass:[UIFont class]])
            font = value;
    }
    return font == nil ? [UIFont systemFontOfSize:12.0f] : font;
}

static BOOL OGTextIsHighSurrogate(unichar value)
{
    return value >= 0xd800 && value <= 0xdbff;
}

static BOOL OGTextIsLowSurrogate(unichar value)
{
    return value >= 0xdc00 && value <= 0xdfff;
}

static BOOL OGTextIsCombining(uint32_t value)
{
    return (value >= 0x0300 && value <= 0x036f) || (value >= 0x1ab0 && value <= 0x1aff) || (value >= 0x1dc0 && value <= 0x1dff) || (value >= 0x20d0 && value <= 0x20ff) || (value >= 0xfe20 && value <= 0xfe2f) || (value >= 0xfe00 && value <= 0xfe0f) || (value >= 0x1f3fb && value <= 0x1f3ff);
}

static BOOL OGTextCodePointIsRTL(uint32_t value)
{
    return (value >= 0x0590 && value <= 0x08ff) || (value >= 0xfb1d && value <= 0xfdff) || (value >= 0xfe70 && value <= 0xfeff) || (value >= 0x10800 && value <= 0x10fff);
}

static BOOL OGTextCodePointIsStrongLTR(uint32_t value)
{
    return (value >= 'A' && value <= 'Z') || (value >= 'a' && value <= 'z') || (value >= 0x00c0 && value <= 0x058f) || (value >= 0x0900 && value <= 0x1fff);
}

static OGPlatformRunDelegateOwner *OGTextRunDelegateOwner(NSDictionary *attributes)
{
    id delegate = [attributes objectForKey:(__bridge NSString *)kCTRunDelegateAttributeName];
    if (![delegate isKindOfClass:[NSDictionary class]])
        return nil;
    id owner = [delegate objectForKey:OGTextDelegateOwnerKey];
    return [owner isKindOfClass:[OGPlatformRunDelegateOwner class]] ? owner : nil;
}

enum
{
    OGTextCachePageShift = 8,
    OGTextCachePageSize = 1 << OGTextCachePageShift,
    OGTextCachePageMask = OGTextCachePageSize - 1,
    OGTextGlyphPageCount = 0x10000 >> OGTextCachePageShift,
    OGTextStackBufferLength = 320
};

static const uint16_t OGTextGlyphUnknown = 0xffff;
static const int32_t OGTextAdvanceUnknown = INT32_MIN;

@interface OGTextFontCmap : NSObject
{
@public
    NSData *_table;
    const uint8_t *_bytes;
    size_t _length;
    size_t _glyphCount;
    NSString *_fontName;
    CGFontRef volatile _font;
    CGFloat _unitsPerEm;
    uint16_t *volatile _glyphPages[OGTextGlyphPageCount];
    int32_t *volatile *_advancePages;
    size_t _advancePageCount;
}
@end

@implementation OGTextFontCmap

- (void)dealloc
{
    for (size_t index = 0; index < OGTextGlyphPageCount; index++)
        free(_glyphPages[index]);
    for (size_t index = 0; index < _advancePageCount; index++)
        free(_advancePages[index]);
    free((void *)_advancePages);
    if (_font != NULL)
        CGFontRelease(_font);
}

@end

static void *OGTextPublishCachePage(void *volatile *slot, void *page)
{
    if (page == NULL)
        return *slot;
    if (OSAtomicCompareAndSwapPtrBarrier(NULL, page, slot))
        return page;
    free(page);
    return *slot;
}

static OGTextFontCmap *OGTextFontCmapForName(NSString *fontName)
{
    if (fontName.length == 0)
        return nil;
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:256 costLimit:1536 * 1024];
    });
    OGTextFontCmap *cmap = [cache objectForKey:fontName];
    if (cmap != nil)
        return cmap;
    CGFontRef cgFont = CGFontCreateWithFontName((__bridge CFStringRef)fontName);
    if (cgFont == NULL)
        return nil;
    int unitsPerEm = CGFontGetUnitsPerEm(cgFont);
    CFDataRef table = CGFontCopyTableForTag(cgFont, 0x636d6170u);
    if (table == NULL || unitsPerEm <= 0)
    {
        if (table != NULL)
            CFRelease(table);
        CGFontRelease(cgFont);
        return nil;
    }
    cmap = [[OGTextFontCmap alloc] init];
    cmap->_table = (__bridge_transfer NSData *)table;
    cmap->_bytes = (const uint8_t *)cmap->_table.bytes;
    cmap->_length = cmap->_table.length;
    cmap->_glyphCount = CGFontGetNumberOfGlyphs(cgFont);
    cmap->_fontName = [fontName copy];
    cmap->_unitsPerEm = (CGFloat)unitsPerEm;
    CGFontRelease(cgFont);
    cmap->_advancePageCount = (cmap->_glyphCount + OGTextCachePageMask) >> OGTextCachePageShift;
    if (cmap->_advancePageCount != 0)
    {
        cmap->_advancePages = (int32_t *volatile *)calloc(cmap->_advancePageCount, sizeof(int32_t *));
        if (cmap->_advancePages == NULL)
            cmap->_advancePageCount = 0;
    }
    [cache setObject:cmap forKey:fontName cost:cmap->_length];
    return cmap;
}

static CGFontRef OGTextFontCmapFont(OGTextFontCmap *cmap)
{
    CGFontRef font = cmap->_font;
    if (font != NULL)
        return font;
    CGFontRef created = CGFontCreateWithFontName((__bridge CFStringRef)cmap->_fontName);
    if (created == NULL)
        return NULL;
    if (OSAtomicCompareAndSwapPtrBarrier(NULL, (void *)created, (void *volatile *)&cmap->_font))
        return created;
    CGFontRelease(created);
    return cmap->_font;
}

static uint32_t OGTextFontCmapLookupGlyph(OGTextFontCmap *cmap, uint32_t value)
{
    uint32_t glyph = OGFontCmapGlyph(cmap->_bytes, cmap->_length, value);
    return glyph < cmap->_glyphCount ? glyph : 0;
}

static uint32_t OGTextFontCmapGlyph(OGTextFontCmap *cmap, uint32_t value)
{
    if (value >= 0xd800 && value <= 0xdfff)
        return 0;
    if (value > 0xffff)
        return OGTextFontCmapLookupGlyph(cmap, value);
    uint16_t *page = cmap->_glyphPages[value >> OGTextCachePageShift];
    if (page == NULL)
    {
        uint16_t *created = (uint16_t *)malloc(OGTextCachePageSize * sizeof(uint16_t));
        if (created != NULL)
            memset(created, 0xff, OGTextCachePageSize * sizeof(uint16_t));
        page = (uint16_t *)OGTextPublishCachePage((void *volatile *)&cmap->_glyphPages[value >> OGTextCachePageShift], created);
        if (page == NULL)
            return OGTextFontCmapLookupGlyph(cmap, value);
    }
    uint16_t cached = page[value & OGTextCachePageMask];
    if (cached != OGTextGlyphUnknown)
        return cached;
    uint32_t glyph = OGTextFontCmapLookupGlyph(cmap, value);
    page[value & OGTextCachePageMask] = (uint16_t)glyph;
    return glyph;
}

static int32_t *OGTextFontCmapAdvancePage(OGTextFontCmap *cmap, CGGlyph glyph)
{
    size_t pageIndex = glyph >> OGTextCachePageShift;
    if (pageIndex >= cmap->_advancePageCount)
        return NULL;
    int32_t *page = cmap->_advancePages[pageIndex];
    if (page != NULL)
        return page;
    int32_t *created = (int32_t *)malloc(OGTextCachePageSize * sizeof(int32_t));
    if (created != NULL)
    {
        for (size_t index = 0; index < OGTextCachePageSize; index++)
            created[index] = OGTextAdvanceUnknown;
    }
    return (int32_t *)OGTextPublishCachePage((void *volatile *)&cmap->_advancePages[pageIndex], created);
}

static void OGTextFontCmapGlyphAdvances(OGTextFontCmap *cmap, const CGGlyph *glyphs, NSUInteger count, int *units)
{
    NSUInteger missing = 0;
    for (NSUInteger index = 0; index < count; index++)
    {
        int32_t *page = OGTextFontCmapAdvancePage(cmap, glyphs[index]);
        int32_t cached = page == NULL ? OGTextAdvanceUnknown : page[glyphs[index] & OGTextCachePageMask];
        if (cached == OGTextAdvanceUnknown)
            missing++;
        else
            units[index] = cached;
    }
    if (missing == 0)
        return;
    CGFontRef font = OGTextFontCmapFont(cmap);
    if (font == NULL)
    {
        for (NSUInteger index = 0; index < count; index++)
        {
            int32_t *page = OGTextFontCmapAdvancePage(cmap, glyphs[index]);
            if (page == NULL || page[glyphs[index] & OGTextCachePageMask] == OGTextAdvanceUnknown)
                units[index] = 0;
        }
        return;
    }
    CGGlyph *pending = (CGGlyph *)malloc(missing * sizeof(CGGlyph));
    int *pendingUnits = (int *)calloc(missing, sizeof(int));
    NSUInteger *positions = (NSUInteger *)malloc(missing * sizeof(NSUInteger));
    if (pending == NULL || pendingUnits == NULL || positions == NULL)
    {
        free(pending);
        free(pendingUnits);
        free(positions);
        CGFontGetGlyphAdvances(font, glyphs, count, units);
        return;
    }
    NSUInteger output = 0;
    for (NSUInteger index = 0; index < count; index++)
    {
        int32_t *page = OGTextFontCmapAdvancePage(cmap, glyphs[index]);
        if (page != NULL && page[glyphs[index] & OGTextCachePageMask] != OGTextAdvanceUnknown)
            continue;
        pending[output] = glyphs[index];
        positions[output] = index;
        output++;
    }
    CGFontGetGlyphAdvances(font, pending, output, pendingUnits);
    for (NSUInteger index = 0; index < output; index++)
    {
        units[positions[index]] = pendingUnits[index];
        int32_t *page = OGTextFontCmapAdvancePage(cmap, pending[index]);
        if (page != NULL)
            page[pending[index] & OGTextCachePageMask] = pendingUnits[index];
    }
    free(pending);
    free(pendingUnits);
    free(positions);
}

static BOOL OGTextFontCmapCoversString(OGTextFontCmap *cmap, NSString *text)
{
    if (cmap == nil)
        return NO;
    NSUInteger count = text.length;
    for (NSUInteger i = 0; i < count; i++)
    {
        uint32_t value = [text characterAtIndex:i];
        if (OGUnicodeIsHighSurrogate((uint16_t)value) && i + 1 < count && OGUnicodeIsLowSurrogate([text characterAtIndex:i + 1]))
            value = OGUnicodeScalarForSurrogatePair((uint16_t)value, [text characterAtIndex:++i]);
        if (value >= 0xd800 && value <= 0xdfff)
            return NO;
        if (OGTextFontCmapGlyph(cmap, value) == 0)
            return NO;
    }
    return YES;
}

typedef struct
{
    uint16_t base;
    uint16_t isolated;
    uint16_t final;
    uint16_t initial;
    uint16_t medial;
} OGTextArabicForms;

static const OGTextArabicForms OGTextArabicFormTable[] = {
    {0x0621, 0xfe80, 0, 0, 0},
    {0x0622, 0xfe81, 0xfe82, 0, 0},
    {0x0623, 0xfe83, 0xfe84, 0, 0},
    {0x0624, 0xfe85, 0xfe86, 0, 0},
    {0x0625, 0xfe87, 0xfe88, 0, 0},
    {0x0626, 0xfe89, 0xfe8a, 0xfe8b, 0xfe8c},
    {0x0627, 0xfe8d, 0xfe8e, 0, 0},
    {0x0628, 0xfe8f, 0xfe90, 0xfe91, 0xfe92},
    {0x0629, 0xfe93, 0xfe94, 0, 0},
    {0x062a, 0xfe95, 0xfe96, 0xfe97, 0xfe98},
    {0x062b, 0xfe99, 0xfe9a, 0xfe9b, 0xfe9c},
    {0x062c, 0xfe9d, 0xfe9e, 0xfe9f, 0xfea0},
    {0x062d, 0xfea1, 0xfea2, 0xfea3, 0xfea4},
    {0x062e, 0xfea5, 0xfea6, 0xfea7, 0xfea8},
    {0x062f, 0xfea9, 0xfeaa, 0, 0},
    {0x0630, 0xfeab, 0xfeac, 0, 0},
    {0x0631, 0xfead, 0xfeae, 0, 0},
    {0x0632, 0xfeaf, 0xfeb0, 0, 0},
    {0x0633, 0xfeb1, 0xfeb2, 0xfeb3, 0xfeb4},
    {0x0634, 0xfeb5, 0xfeb6, 0xfeb7, 0xfeb8},
    {0x0635, 0xfeb9, 0xfeba, 0xfebb, 0xfebc},
    {0x0636, 0xfebd, 0xfebe, 0xfebf, 0xfec0},
    {0x0637, 0xfec1, 0xfec2, 0xfec3, 0xfec4},
    {0x0638, 0xfec5, 0xfec6, 0xfec7, 0xfec8},
    {0x0639, 0xfec9, 0xfeca, 0xfecb, 0xfecc},
    {0x063a, 0xfecd, 0xfece, 0xfecf, 0xfed0},
    {0x0641, 0xfed1, 0xfed2, 0xfed3, 0xfed4},
    {0x0642, 0xfed5, 0xfed6, 0xfed7, 0xfed8},
    {0x0643, 0xfed9, 0xfeda, 0xfedb, 0xfedc},
    {0x0644, 0xfedd, 0xfede, 0xfedf, 0xfee0},
    {0x0645, 0xfee1, 0xfee2, 0xfee3, 0xfee4},
    {0x0646, 0xfee5, 0xfee6, 0xfee7, 0xfee8},
    {0x0647, 0xfee9, 0xfeea, 0xfeeb, 0xfeec},
    {0x0648, 0xfeed, 0xfeee, 0, 0},
    {0x0649, 0xfeef, 0xfef0, 0, 0},
    {0x064a, 0xfef1, 0xfef2, 0xfef3, 0xfef4},
    {0x067e, 0xfb56, 0xfb57, 0xfb58, 0xfb59},
    {0x0686, 0xfb7a, 0xfb7b, 0xfb7c, 0xfb7d},
    {0x0698, 0xfb8a, 0xfb8b, 0, 0},
    {0x06a9, 0xfb8e, 0xfb8f, 0xfb90, 0xfb91},
    {0x06af, 0xfb92, 0xfb93, 0xfb94, 0xfb95},
    {0x06cc, 0xfbfc, 0xfbfd, 0xfbfe, 0xfbff}
};

static const uint32_t OGTextRemovedScalar = 0xffffffffu;

static const OGTextArabicForms *OGTextArabicFormsForScalar(uint32_t value)
{
    size_t low = 0, high = sizeof(OGTextArabicFormTable) / sizeof(OGTextArabicFormTable[0]);
    while (low < high)
    {
        size_t middle = low + (high - low) / 2;
        if (OGTextArabicFormTable[middle].base < value)
            low = middle + 1;
        else
            high = middle;
    }
    if (low < sizeof(OGTextArabicFormTable) / sizeof(OGTextArabicFormTable[0]) && OGTextArabicFormTable[low].base == value)
        return &OGTextArabicFormTable[low];
    return NULL;
}

static BOOL OGTextArabicIsTransparent(uint32_t value)
{
    return (value >= 0x0610 && value <= 0x061a) || (value >= 0x064b && value <= 0x065f) || value == 0x0670 || (value >= 0x06d6 && value <= 0x06dc) || (value >= 0x06df && value <= 0x06e4) || value == 0x06e7 || value == 0x06e8 || (value >= 0x06ea && value <= 0x06ed);
}

static BOOL OGTextArabicJoinsForward(uint32_t value)
{
    if (value == 0x0640 || value == 0x200d)
        return YES;
    const OGTextArabicForms *forms = OGTextArabicFormsForScalar(value);
    return forms != NULL && forms->initial != 0;
}

static BOOL OGTextArabicJoinsBackward(uint32_t value)
{
    return value == 0x0640 || value == 0x200d || OGTextArabicFormsForScalar(value) != NULL;
}

static uint16_t OGTextArabicLamAlefLigature(uint32_t alef, BOOL final)
{
    switch (alef)
    {
        case 0x0622:
            return final ? 0xfef6 : 0xfef5;
        case 0x0623:
            return final ? 0xfef8 : 0xfef7;
        case 0x0625:
            return final ? 0xfefa : 0xfef9;
        case 0x0627:
            return final ? 0xfefc : 0xfefb;
        default:
            return 0;
    }
}

static void OGTextApplyArabicShaping(OGTextFontCmap *cmap, uint32_t *scalars, NSUInteger count)
{
    uint32_t *original = (uint32_t *)malloc(count * sizeof(uint32_t));
    if (original == NULL)
        return;
    memcpy(original, scalars, count * sizeof(uint32_t));
    for (NSUInteger index = 0; index < count; index++)
    {
        uint32_t value = original[index];
        if (scalars[index] == OGTextRemovedScalar)
            continue;
        const OGTextArabicForms *forms = OGTextArabicFormsForScalar(value);
        if (forms == NULL)
            continue;

        NSInteger previous = (NSInteger)index - 1;
        while (previous >= 0 && OGTextArabicIsTransparent(original[previous]))
            previous--;
        NSUInteger next = index + 1;
        while (next < count && OGTextArabicIsTransparent(original[next]))
            next++;
        BOOL joinsPrevious = previous >= 0 && OGTextArabicJoinsForward(original[previous]);
        BOOL joinsNext = next < count && OGTextArabicJoinsBackward(original[next]);

        if (value == 0x0644 && next < count)
        {
            uint16_t ligature = OGTextArabicLamAlefLigature(original[next], joinsPrevious);
            if (ligature != 0 && OGTextFontCmapGlyph(cmap, ligature) != 0)
            {
                scalars[index] = ligature;
                scalars[next] = OGTextRemovedScalar;
                continue;
            }
        }

        uint16_t form = 0;
        if (forms->initial != 0)
        {
            if (joinsPrevious && joinsNext)
                form = forms->medial;
            else if (joinsPrevious)
                form = forms->final;
            else if (joinsNext)
                form = forms->initial;
            else
                form = forms->isolated;
        }
        else
            form = joinsPrevious ? forms->final : forms->isolated;
        if (form != 0 && OGTextFontCmapGlyph(cmap, form) != 0)
            scalars[index] = form;
    }
    free(original);
}

static BOOL OGTextScalarIsInvisible(uint32_t value)
{
    return value < 0x20 || (value >= 0x7f && value <= 0x9f) || value == 0x00ad || (value >= 0x200b && value <= 0x200f) || (value >= 0x2028 && value <= 0x202e) || (value >= 0x2060 && value <= 0x2064) || (value >= 0xfe00 && value <= 0xfe0f) || value == 0xfeff;
}

static NSUInteger OGTextShapeCharacters(OGTextFontCmap *cmap, const unichar *units, NSUInteger length, CGGlyph *glyphs, bool *clusterStarts, NSUInteger *sources)
{
    if (length == 0)
        return 0;
    uint32_t stackScalars[OGTextStackBufferLength];
    NSUInteger stackSources[OGTextStackBufferLength];
    BOOL stack = length <= OGTextStackBufferLength;
    uint32_t *scalars = stack ? stackScalars : (uint32_t *)malloc(length * sizeof(uint32_t));
    NSUInteger *scalarSources = stack ? stackSources : (NSUInteger *)malloc(length * sizeof(NSUInteger));
    if (scalars == NULL || scalarSources == NULL)
    {
        if (!stack)
        {
            free(scalars);
            free(scalarSources);
        }
        return 0;
    }
    NSUInteger scalarCount = 0;
    BOOL arabic = NO;
    for (NSUInteger index = 0; index < length; index++)
    {
        NSUInteger source = index;
        uint32_t value = units[index];
        if (OGUnicodeIsHighSurrogate(units[index]) && index + 1 < length && OGUnicodeIsLowSurrogate(units[index + 1]))
        {
            value = OGUnicodeScalarForSurrogatePair(units[index], units[index + 1]);
            index++;
        }
        if (value >= 0x0600 && value <= 0x06ff)
            arabic = YES;
        scalarSources[scalarCount] = source;
        scalars[scalarCount++] = value;
    }
    if (arabic)
        OGTextApplyArabicShaping(cmap, scalars, scalarCount);

    NSUInteger glyphCount = 0;
    for (NSUInteger index = 0; index < scalarCount; index++)
    {
        uint32_t value = scalars[index];
        if (value == OGTextRemovedScalar || OGTextScalarIsInvisible(value))
            continue;
        glyphs[glyphCount] = (CGGlyph)OGTextFontCmapGlyph(cmap, value);
        if (clusterStarts != NULL)
            clusterStarts[glyphCount] = glyphCount == 0 || !(OGTextIsCombining(value) || OGTextArabicIsTransparent(value));
        if (sources != NULL)
            sources[glyphCount] = scalarSources[index];
        glyphCount++;
    }
    if (!stack)
    {
        free(scalars);
        free(scalarSources);
    }
    return glyphCount;
}

static NSUInteger OGTextShapeGlyphs(OGTextFontCmap *cmap, NSString *string, CGGlyph *glyphs, bool *clusterStarts)
{
    NSUInteger length = string.length;
    if (length == 0)
        return 0;
    unichar *units = (unichar *)malloc(length * sizeof(unichar));
    if (units == NULL)
        return 0;
    [string getCharacters:units range:NSMakeRange(0, length)];
    NSUInteger count = OGTextShapeCharacters(cmap, units, length, glyphs, clusterStarts, NULL);
    free(units);
    return count;
}

static CGFloat OGTextGlyphAdvances(OGTextFontCmap *cmap, CGFloat pointSize, const CGGlyph *glyphs, NSUInteger count, CGFloat *advances)
{
    if (count == 0)
        return 0.0f;
    int stackUnits[OGTextStackBufferLength];
    int *units = count <= OGTextStackBufferLength ? stackUnits : (int *)malloc(count * sizeof(int));
    if (units == NULL)
        return 0.0f;
    OGTextFontCmapGlyphAdvances(cmap, glyphs, count, units);
    CGFloat scale = pointSize / cmap->_unitsPerEm;
    CGFloat total = 0.0f;
    for (NSUInteger index = 0; index < count; index++)
    {
        CGFloat advance = (CGFloat)units[index] * scale;
        if (advances != NULL)
            advances[index] = advance;
        total += advance;
    }
    if (units != stackUnits)
        free(units);
    return total;
}

static void OGTextDrawGlyphRun(CGContextRef context, NSString *string, UIFont *font, CGPoint baseline, BOOL rtl)
{
    OGTextFontCmap *cmap = OGTextFontCmapForName(font.fontName);
    NSUInteger length = string.length;
    if (cmap == nil || length == 0)
        return;
    CGGlyph *glyphs = (CGGlyph *)malloc(length * sizeof(CGGlyph));
    bool *clusterStarts = (bool *)malloc(length * sizeof(bool));
    CGFloat *advances = (CGFloat *)malloc(length * sizeof(CGFloat));
    CGGlyph *visualGlyphs = (CGGlyph *)malloc(length * sizeof(CGGlyph));
    CGSize *visualAdvances = (CGSize *)malloc(length * sizeof(CGSize));
    if (glyphs != NULL && clusterStarts != NULL && advances != NULL && visualGlyphs != NULL && visualAdvances != NULL)
    {
        NSUInteger count = OGTextShapeGlyphs(cmap, string, glyphs, clusterStarts);
        OGTextGlyphAdvances(cmap, font.pointSize, glyphs, count, advances);
        NSUInteger output = 0;
        if (rtl)
        {
            NSUInteger end = count;
            while (end > 0)
            {
                NSUInteger start = end - 1;
                while (start > 0 && !clusterStarts[start])
                    start--;
                for (NSUInteger index = start; index < end; index++)
                {
                    visualGlyphs[output] = glyphs[index];
                    visualAdvances[output] = CGSizeMake(advances[index], 0.0f);
                    output++;
                }
                end = start;
            }
        }
        else
        {
            for (NSUInteger index = 0; index < count; index++)
            {
                visualGlyphs[output] = glyphs[index];
                visualAdvances[output] = CGSizeMake(advances[index], 0.0f);
                output++;
            }
        }
        CGFontRef cgFont = output != 0 ? OGTextFontCmapFont(cmap) : NULL;
        if (cgFont != NULL)
        {
            CGAffineTransform savedMatrix = CGContextGetTextMatrix(context);
            CGPoint savedPosition = CGContextGetTextPosition(context);
            CGContextSetFont(context, cgFont);
            CGContextSetFontSize(context, font.pointSize);
            CGContextSetTextDrawingMode(context, kCGTextFill);
            CGContextSetTextMatrix(context, CGAffineTransformMakeScale(1.0f, -1.0f));
            CGContextSetTextPosition(context, baseline.x, baseline.y);
            CGContextShowGlyphsWithAdvances(context, visualGlyphs, visualAdvances, output);
            CGContextSetTextMatrix(context, savedMatrix);
            CGContextSetTextPosition(context, savedPosition.x, savedPosition.y);
        }
    }
    free(glyphs);
    free(clusterStarts);
    free(advances);
    free(visualGlyphs);
    free(visualAdvances);
}

static uint32_t OGTextCodePointInCharacters(const unichar *characters, NSUInteger length, NSUInteger index, NSUInteger *count)
{
    unichar high = characters[index];
    if (OGTextIsHighSurrogate(high) && index + 1 < length && OGTextIsLowSurrogate(characters[index + 1]))
    {
        *count = 2;
        return OGUnicodeScalarForSurrogatePair(high, characters[index + 1]);
    }
    *count = 1;
    return high;
}

static NSUInteger OGTextClusterEndInCharacters(const unichar *characters, NSUInteger index, NSUInteger limit)
{
    NSUInteger count = 0;
    OGTextCodePointInCharacters(characters, limit, index, &count);
    NSUInteger cursor = MIN(limit, index + count);
    while (cursor < limit)
    {
        NSUInteger nextCount = 0;
        uint32_t value = OGTextCodePointInCharacters(characters, limit, cursor, &nextCount);
        if (OGTextIsCombining(value))
        {
            cursor = MIN(limit, cursor + nextCount);
            continue;
        }
        if (value == 0x200d && cursor + nextCount < limit)
        {
            cursor += nextCount;
            NSUInteger joinedCount = 0;
            OGTextCodePointInCharacters(characters, limit, cursor, &joinedCount);
            cursor = MIN(limit, cursor + joinedCount);
            continue;
        }
        break;
    }
    return cursor;
}

enum
{
    OGTextClusterRTL = 1 << 0,
    OGTextClusterStrongLTR = 1 << 1,
    OGTextClusterWhitespace = 1 << 2,
    OGTextClusterNewline = 1 << 3,
    OGTextClusterTab = 1 << 4
};

static BOOL OGTextCharacterIsNewline(unichar value)
{
    if (value < 0x80)
        return value >= 0x0a && value <= 0x0d;
    return value == 0x85 || value == 0x2028 || value == 0x2029;
}

static BOOL OGTextCharacterIsWhitespaceOrNewline(unichar value)
{
    if (value < 0x80)
        return value == 0x20 || (value >= 0x09 && value <= 0x0d);
    return CFCharacterSetIsCharacterMember(CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline), value);
}

static uint8_t OGTextClusterFlags(const unichar *characters, NSUInteger length)
{
    if (length == 0)
        return 0;
    uint8_t flags = 0;
    NSUInteger count = 0;
    uint32_t first = OGTextCodePointInCharacters(characters, length, 0, &count);
    if (OGTextCodePointIsRTL(first))
        flags |= OGTextClusterRTL;
    else if (OGTextCodePointIsStrongLTR(first))
        flags |= OGTextClusterStrongLTR;
    BOOL allWhitespace = YES;
    for (NSUInteger index = 0; index < length; index++)
    {
        if (!OGTextCharacterIsWhitespaceOrNewline(characters[index]))
            allWhitespace = NO;
        if (OGTextCharacterIsNewline(characters[index]))
            flags |= OGTextClusterNewline;
    }
    if (allWhitespace)
        flags |= OGTextClusterWhitespace;
    if (length == 1 && characters[0] == '\t')
        flags |= OGTextClusterTab;
    return flags;
}

@interface OGTextStyle : NSObject
{
@public
    NSDictionary *_attributes;
    UIFont *_font;
    OGTextFontCmap *_cmap;
    OGPlatformRunDelegateOwner *_owner;
    CGFloat _pointSize;
    CGFloat _ascent;
    CGFloat _descent;
    CGFloat _leading;
    CGFloat _tabWidth;
}
@end

@implementation OGTextStyle
@end

static OGTextStyle *OGTextStyleCreate(NSDictionary *attributes)
{
    OGTextStyle *style = [[OGTextStyle alloc] init];
    style->_attributes = attributes == nil ? [NSDictionary dictionary] : attributes;
    style->_font = OGTextFontFromAttributes(style->_attributes);
    style->_pointSize = style->_font.pointSize;
    style->_owner = OGTextRunDelegateOwner(style->_attributes);
    style->_tabWidth = -1.0f;
    if (style->_owner != nil)
    {
        style->_ascent = [style->_owner ascent];
        style->_descent = [style->_owner descent];
    }
    else
    {
        style->_ascent = MAX(0.0f, style->_font.ascender);
        style->_descent = MAX(0.0f, -style->_font.descender);
        style->_leading = MAX(0.0f, OGPlatformFontLineHeight(style->_font) - style->_font.ascender + style->_font.descender);
        style->_cmap = OGTextFontCmapForName(style->_font.fontName);
    }
    return style;
}

static CGFloat OGTextStyleWidthForCharacters(OGTextStyle *style, const unichar *characters, NSUInteger length)
{
    if (style->_owner != nil)
        return [style->_owner width];
    if (style->_cmap == nil || length == 0)
        return 0.0f;
    for (NSUInteger index = 0; index < length; index++)
    {
        if (OGTextCharacterIsNewline(characters[index]))
            return 0.0f;
    }
    CGGlyph stackGlyphs[OGTextStackBufferLength];
    CGGlyph *glyphs = length <= OGTextStackBufferLength ? stackGlyphs : (CGGlyph *)malloc(length * sizeof(CGGlyph));
    if (glyphs == NULL)
        return 0.0f;
    NSUInteger glyphCount = OGTextShapeCharacters(style->_cmap, characters, length, glyphs, NULL, NULL);
    CGFloat width = OGTextGlyphAdvances(style->_cmap, style->_pointSize, glyphs, glyphCount, NULL);
    if (glyphs != stackGlyphs)
        free(glyphs);
    return width;
}

static CGFloat OGTextStyleTabWidth(OGTextStyle *style)
{
    CGFloat tabWidth = style->_tabWidth;
    if (tabWidth < 0.0f)
    {
        static const unichar spaces[4] = {' ', ' ', ' ', ' '};
        tabWidth = OGTextStyleWidthForCharacters(style, spaces, 4);
        if (tabWidth <= 0.0f)
            tabWidth = MAX(1.0f, style->_pointSize * 2.0f);
        style->_tabWidth = tabWidth;
    }
    return tabWidth;
}

typedef struct
{
    CFIndex start;
    CFIndex end;
    NSUInteger location;
    NSUInteger length;
    CGFloat width;
    CGFloat x;
    uint32_t style;
    uint16_t source;
    uint8_t flags;
} OGTextClusterRecord;

static OGTextClusterRecord *OGTextAllocateRecords(NSUInteger count)
{
    return (OGTextClusterRecord *)malloc(MAX((NSUInteger)1, count) * sizeof(OGTextClusterRecord));
}

static void OGTextApplyTabWidths(OGTextClusterRecord *clusters, NSUInteger count, NSArray *styles, CGFloat offset)
{
    CGFloat position = offset;
    for (NSUInteger index = 0; index < count; index++)
    {
        OGTextClusterRecord *cluster = &clusters[index];
        if ((cluster->flags & OGTextClusterTab) != 0)
        {
            CGFloat tabWidth = OGTextStyleTabWidth([styles objectAtIndex:cluster->style]);
            CGFloat nextStop = (floorf(position / tabWidth) + 1.0f) * tabWidth;
            cluster->width = MAX(1.0f, nextStop - position);
        }
        position += cluster->width;
    }
}

enum
{
    OGTextChunkSoftLimit = 64,
    OGTextChunkHardLimit = 256,
    OGTextChunkClusterCapacity = 320
};

@interface OGTextTypesetter : NSObject
{
@public
    id _attributedString;
    NSString *_string;
    NSUInteger _length;
    unichar *_characters;
    uint32_t *_recordSlots;
    uint8_t *_measured;
    OGTextClusterRecord *_records;
    NSUInteger _recordCount;
    NSUInteger _recordCapacity;
    NSMutableArray *_styles;
    NSRange _styleRange;
    uint32_t _styleIndex;
    OSSpinLock _lock;
}
@end

@implementation OGTextTypesetter

- (instancetype)initWithAttributedString:(id)attributedString
{
    self = [super init];
    if (self != nil)
    {
        _attributedString = [attributedString copy];
        _string = [[_attributedString string] copy];
        if (_string == nil)
            _string = @"";
        _length = [_string length];
        _styles = [[NSMutableArray alloc] init];
        _styleRange = NSMakeRange(NSNotFound, 0);
        _lock = OS_SPINLOCK_INIT;
        if (_length != 0)
        {
            _characters = (unichar *)malloc(_length * sizeof(unichar));
            _recordSlots = (uint32_t *)calloc(_length, sizeof(uint32_t));
            _measured = (uint8_t *)calloc(_length, sizeof(uint8_t));
            if (_characters == NULL || _recordSlots == NULL || _measured == NULL)
                return nil;
            [_string getCharacters:_characters range:NSMakeRange(0, _length)];
        }
    }
    return self;
}

- (void)dealloc
{
    free(_characters);
    free(_recordSlots);
    free(_measured);
    free(_records);
}

@end

static OGTextTypesetter *OGTextTypesetterObject(CTTypesetterRef typesetter)
{
    id object = OGTextObject(typesetter);
    return [object isKindOfClass:[OGTextTypesetter class]] ? object : nil;
}

static uint32_t OGTextTypesetterStyleAtIndex(OGTextTypesetter *typesetter, NSUInteger index, NSUInteger *runLimit)
{
    if (typesetter->_styleRange.location != NSNotFound && NSLocationInRange(index, typesetter->_styleRange))
    {
        *runLimit = NSMaxRange(typesetter->_styleRange);
        return typesetter->_styleIndex;
    }
    NSRange range = NSMakeRange(NSNotFound, 0);
    NSDictionary *attributes = [typesetter->_attributedString attributesAtIndex:index effectiveRange:&range];
    if (attributes == nil)
        attributes = [NSDictionary dictionary];
    if (range.location == NSNotFound || range.location > index || NSMaxRange(range) <= index)
        range = NSMakeRange(index, 1);
    range = NSIntersectionRange(range, NSMakeRange(0, typesetter->_length));

    NSUInteger count = typesetter->_styles.count;
    NSUInteger found = NSNotFound;
    for (NSUInteger candidate = count; candidate > 0; candidate--)
    {
        if (((OGTextStyle *)[typesetter->_styles objectAtIndex:candidate - 1])->_attributes == attributes)
        {
            found = candidate - 1;
            break;
        }
    }
    if (found == NSNotFound)
    {
        for (NSUInteger candidate = count; candidate > 0; candidate--)
        {
            if ([((OGTextStyle *)[typesetter->_styles objectAtIndex:candidate - 1])->_attributes isEqual:attributes])
            {
                found = candidate - 1;
                break;
            }
        }
    }
    if (found == NSNotFound)
    {
        found = count;
        [typesetter->_styles addObject:OGTextStyleCreate(attributes)];
    }
    typesetter->_styleRange = range;
    typesetter->_styleIndex = (uint32_t)found;
    *runLimit = NSMaxRange(range);
    return (uint32_t)found;
}

static BOOL OGTextTypesetterReserveRecords(OGTextTypesetter *typesetter, NSUInteger additional)
{
    NSUInteger required = typesetter->_recordCount + additional;
    if (required <= typesetter->_recordCapacity)
        return YES;
    NSUInteger capacity = MAX(required, MAX((NSUInteger)32, typesetter->_recordCapacity * 2));
    OGTextClusterRecord *records = (OGTextClusterRecord *)realloc(typesetter->_records, capacity * sizeof(OGTextClusterRecord));
    if (records == NULL)
        return NO;
    typesetter->_records = records;
    typesetter->_recordCapacity = capacity;
    return YES;
}

static void OGTextTypesetterMeasureChunk(OGTextTypesetter *typesetter, NSUInteger start)
{
    const unichar *characters = typesetter->_characters;
    NSUInteger length = typesetter->_length;
    NSUInteger runLimit = start + 1;
    uint32_t styleIndex = OGTextTypesetterStyleAtIndex(typesetter, start, &runLimit);
    OGTextStyle *style = [typesetter->_styles objectAtIndex:styleIndex];

    NSUInteger ends[OGTextChunkClusterCapacity];
    CGFloat widths[OGTextChunkClusterCapacity];
    NSUInteger count = 0;
    NSUInteger cursor = start;
    while (cursor < runLimit && count < OGTextChunkClusterCapacity && (cursor == start || !typesetter->_measured[cursor]))
    {
        cursor = OGTextClusterEndInCharacters(characters, cursor, length);
        widths[count] = 0.0f;
        ends[count++] = cursor;
        NSUInteger units = cursor - start;
        if (units >= OGTextChunkHardLimit)
            break;
        if (units >= OGTextChunkSoftLimit && OGTextCharacterIsWhitespaceOrNewline(characters[cursor - 1]))
            break;
    }
    NSUInteger units = cursor - start;

    if (style->_owner != nil)
    {
        CGFloat width = [style->_owner width];
        for (NSUInteger index = 0; index < count; index++)
            widths[index] = width;
    }
    else if (style->_cmap != nil)
    {
        CGGlyph stackGlyphs[OGTextStackBufferLength];
        NSUInteger stackSources[OGTextStackBufferLength];
        CGFloat stackAdvances[OGTextStackBufferLength];
        BOOL stack = units <= OGTextStackBufferLength;
        CGGlyph *glyphs = stack ? stackGlyphs : (CGGlyph *)malloc(units * sizeof(CGGlyph));
        NSUInteger *sources = stack ? stackSources : (NSUInteger *)malloc(units * sizeof(NSUInteger));
        CGFloat *advances = stack ? stackAdvances : (CGFloat *)malloc(units * sizeof(CGFloat));
        if (glyphs != NULL && sources != NULL && advances != NULL)
        {
            NSUInteger glyphCount = OGTextShapeCharacters(style->_cmap, characters + start, units, glyphs, NULL, sources);
            OGTextGlyphAdvances(style->_cmap, style->_pointSize, glyphs, glyphCount, advances);
            NSUInteger clusterIndex = 0;
            for (NSUInteger glyph = 0; glyph < glyphCount; glyph++)
            {
                NSUInteger source = start + sources[glyph];
                while (clusterIndex + 1 < count && source >= ends[clusterIndex])
                    clusterIndex++;
                widths[clusterIndex] += advances[glyph];
            }
        }
        if (!stack)
        {
            free(glyphs);
            free(sources);
            free(advances);
        }
    }

    if (!OGTextTypesetterReserveRecords(typesetter, count))
        return;
    NSUInteger clusterStart = start;
    for (NSUInteger index = 0; index < count; index++)
    {
        OGTextClusterRecord *record = &typesetter->_records[typesetter->_recordCount];
        record->start = (CFIndex)clusterStart;
        record->end = (CFIndex)ends[index];
        record->location = clusterStart;
        record->length = ends[index] - clusterStart;
        record->flags = OGTextClusterFlags(characters + clusterStart, record->length);
        record->width = style->_owner == nil && (record->flags & OGTextClusterNewline) != 0 ? 0.0f : widths[index];
        record->x = 0.0f;
        record->style = styleIndex;
        record->source = 0;
        typesetter->_recordCount++;
        memset(typesetter->_measured + clusterStart, 1, record->length);
        typesetter->_recordSlots[clusterStart] = (uint32_t)typesetter->_recordCount;
        clusterStart = ends[index];
    }
}

static OGTextClusterRecord OGTextTypesetterClusterInRange(OGTextTypesetter *typesetter, NSUInteger index, NSUInteger limit)
{
    uint32_t slot = typesetter->_recordSlots[index];
    if (slot == 0 && !typesetter->_measured[index])
    {
        OGTextTypesetterMeasureChunk(typesetter, index);
        slot = typesetter->_recordSlots[index];
    }
    if (slot != 0 && (NSUInteger)typesetter->_records[slot - 1].end <= limit)
        return typesetter->_records[slot - 1];

    NSUInteger end = OGTextClusterEndInCharacters(typesetter->_characters, index, limit);
    NSUInteger runLimit = index + 1;
    uint32_t styleIndex = OGTextTypesetterStyleAtIndex(typesetter, index, &runLimit);
    OGTextStyle *style = [typesetter->_styles objectAtIndex:styleIndex];
    OGTextClusterRecord record;
    record.start = (CFIndex)index;
    record.end = (CFIndex)end;
    record.location = index;
    record.length = end - index;
    record.flags = OGTextClusterFlags(typesetter->_characters + index, record.length);
    record.width = OGTextStyleWidthForCharacters(style, typesetter->_characters + index, record.length);
    record.x = 0.0f;
    record.style = styleIndex;
    record.source = 0;
    return record;
}

@interface OGTextLineStorage : NSObject
{
@public
    OGTextClusterRecord *_clusters;
    NSUInteger _count;
    NSArray *_styles;
    NSArray *_sources;
}
@end

@implementation OGTextLineStorage

- (void)dealloc
{
    free(_clusters);
}

@end

@interface OGTextRun : NSObject
{
@public
    OGTextLineStorage *_storage;
    OGTextStyle *_style;
    NSUInteger _first;
    NSUInteger _count;
    CFRange _range;
    CGFloat _x;
    CGFloat _width;
    CGFloat _ascent;
    CGFloat _descent;
    CGFloat _leading;
    BOOL _rtl;
    BOOL _justified;
}
@end

@implementation OGTextRun
@end

@interface OGTextLine : NSObject
{
@public
    OGTextLineStorage *_storage;
    NSArray *_runs;
    CFRange _range;
    CGFloat _width;
    CGFloat _ascent;
    CGFloat _descent;
    CGFloat _leading;
    CGFloat _trailing;
}
@end

@implementation OGTextLine
@end

static OGTextLine *OGTextLineObject(CTLineRef line)
{
    id object = OGTextObject(line);
    return [object isKindOfClass:[OGTextLine class]] ? object : nil;
}

static OGTextRun *OGTextRunObject(CTRunRef run)
{
    id object = OGTextObject(run);
    return [object isKindOfClass:[OGTextRun class]] ? object : nil;
}

static OGTextRun *OGTextRunCreate(OGTextLineStorage *storage, NSUInteger first, NSUInteger count, BOOL rtl, CGFloat x, BOOL justified)
{
    OGTextRun *run = [[OGTextRun alloc] init];
    run->_storage = storage;
    run->_first = first;
    run->_count = count;
    run->_rtl = rtl;
    run->_x = x;
    run->_justified = justified;
    run->_style = count == 0 ? nil : [storage->_styles objectAtIndex:storage->_clusters[first].style];
    CFIndex minimum = LONG_MAX;
    CFIndex maximum = LONG_MIN;
    for (NSUInteger index = first; index < first + count; index++)
    {
        const OGTextClusterRecord *cluster = &storage->_clusters[index];
        run->_width += cluster->width;
        if (cluster->start >= 0)
        {
            minimum = MIN(minimum, cluster->start);
            maximum = MAX(maximum, cluster->end);
        }
    }
    if (run->_style != nil)
    {
        run->_ascent = run->_style->_ascent;
        run->_descent = run->_style->_descent;
        run->_leading = run->_style->_leading;
    }
    run->_range = minimum == LONG_MAX ? CFRangeMake(kCFNotFound, 0) : CFRangeMake(minimum, maximum - minimum);
    return run;
}

static CTLineRef OGTextLineCreate(const OGTextClusterRecord *logical, NSUInteger count, NSArray *styles, NSArray *sources, CFRange sourceRange, BOOL justified)
{
    OGTextLineStorage *storage = [[OGTextLineStorage alloc] init];
    storage->_clusters = OGTextAllocateRecords(count);
    NSUInteger *groupStarts = (NSUInteger *)malloc((count + 1) * sizeof(NSUInteger));
    if (storage->_clusters == NULL || groupStarts == NULL)
    {
        free(groupStarts);
        return NULL;
    }
    storage->_count = count;
    storage->_styles = styles;
    storage->_sources = sources;

    NSUInteger groupCount = 0;
    BOOL previousRTL = NO;
    uint32_t previousStyle = 0;
    CFIndex previousEnd = LONG_MIN;
    BOOL baseRTL = NO;
    BOOL baseResolved = NO;
    for (NSUInteger index = 0; index < count; index++)
    {
        const OGTextClusterRecord *cluster = &logical[index];
        BOOL rtl = (cluster->flags & OGTextClusterRTL) != 0;
        if (!baseResolved && (cluster->flags & (OGTextClusterRTL | OGTextClusterStrongLTR)) != 0)
        {
            baseRTL = rtl;
            baseResolved = YES;
        }
        if (groupCount == 0 || rtl != previousRTL || cluster->style != previousStyle || cluster->start < 0 || previousEnd < 0 || cluster->start != previousEnd)
        {
            groupStarts[groupCount++] = index;
            previousStyle = cluster->style;
            previousRTL = rtl;
        }
        previousEnd = cluster->end;
    }
    groupStarts[groupCount] = count;

    OGTextLine *line = [[OGTextLine alloc] init];
    line->_storage = storage;
    NSMutableArray *runs = [[NSMutableArray alloc] initWithCapacity:groupCount];
    CGFloat x = 0.0f;
    NSUInteger output = 0;
    for (NSUInteger step = 0; step < groupCount; step++)
    {
        NSUInteger group = baseRTL ? groupCount - 1 - step : step;
        NSUInteger begin = groupStarts[group];
        NSUInteger end = groupStarts[group + 1];
        BOOL rtl = (logical[begin].flags & OGTextClusterRTL) != 0;
        NSUInteger runFirst = output;
        CGFloat runX = x;
        for (NSUInteger offset = 0; offset < end - begin; offset++)
        {
            OGTextClusterRecord cluster = logical[rtl ? end - 1 - offset : begin + offset];
            cluster.x = x;
            x += cluster.width;
            storage->_clusters[output++] = cluster;
        }
        OGTextRun *run = OGTextRunCreate(storage, runFirst, end - begin, rtl, runX, justified);
        line->_ascent = MAX(line->_ascent, run->_ascent);
        line->_descent = MAX(line->_descent, run->_descent);
        line->_leading = MAX(line->_leading, run->_leading);
        [runs addObject:run];
    }
    free(groupStarts);
    for (NSUInteger index = count; index > 0; index--)
    {
        if ((logical[index - 1].flags & OGTextClusterWhitespace) == 0)
            break;
        line->_trailing += logical[index - 1].width;
    }
    line->_runs = runs;
    line->_width = x;
    line->_range = CFRangeMake(MAX((CFIndex)0, sourceRange.location), MAX((CFIndex)0, sourceRange.length));
    return (CTLineRef)OGTextCreateObject(line);
}

static OGTextClusterRecord *OGTextLogicalClusters(OGTextLine *line, uint32_t styleOffset, uint16_t sourceOffset, BOOL detach)
{
    OGTextLineStorage *storage = line->_storage;
    NSUInteger count = storage->_count;
    OGTextClusterRecord *ordered = OGTextAllocateRecords(count);
    if (ordered == NULL)
        return NULL;
    NSUInteger attached = 0;
    for (NSUInteger index = 0; index < count; index++)
    {
        if (storage->_clusters[index].start >= 0)
            attached++;
    }
    NSUInteger attachedOutput = 0;
    NSUInteger detachedOutput = attached;
    for (NSUInteger index = 0; index < count; index++)
    {
        OGTextClusterRecord cluster = storage->_clusters[index];
        cluster.style += styleOffset;
        cluster.source = (uint16_t)(cluster.source + sourceOffset);
        if (cluster.start < 0)
        {
            ordered[detachedOutput++] = cluster;
            continue;
        }
        NSUInteger position = attachedOutput++;
        while (position > 0 && ordered[position - 1].start > cluster.start)
        {
            ordered[position] = ordered[position - 1];
            position--;
        }
        ordered[position] = cluster;
    }
    if (detach)
    {
        for (NSUInteger index = 0; index < count; index++)
        {
            ordered[index].start = -1;
            ordered[index].end = -1;
        }
    }
    return ordered;
}

static NSString *OGTextClustersString(OGTextLineStorage *storage, NSUInteger first, NSUInteger count, BOOL reverse)
{
    NSMutableString *string = nil;
    NSString *source = nil;
    NSRange pending = NSMakeRange(0, 0);
    for (NSUInteger step = 0; step < count; step++)
    {
        const OGTextClusterRecord *cluster = &storage->_clusters[reverse ? first + count - 1 - step : first + step];
        NSString *clusterSource = [storage->_sources objectAtIndex:cluster->source];
        if (clusterSource == source && NSMaxRange(pending) == cluster->location)
        {
            pending.length += cluster->length;
            continue;
        }
        if (source != nil && pending.length != 0)
        {
            if (string == nil)
                string = [[NSMutableString alloc] init];
            [string appendString:[source substringWithRange:pending]];
        }
        source = clusterSource;
        pending = NSMakeRange(cluster->location, cluster->length);
    }
    if (string == nil)
        return source == nil || pending.length == 0 ? @"" : [source substringWithRange:pending];
    if (source != nil && pending.length != 0)
        [string appendString:[source substringWithRange:pending]];
    return string;
}

CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix)
{
    NSString *fontName = [(__bridge NSString *)name copy];
    if (fontName.length == 0)
        return NULL;
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:256 costLimit:0];
    });
    NSArray *key = [[NSArray alloc] initWithObjects:fontName, [NSNumber numberWithFloat:(float)size], nil];
    NSDictionary *object = [cache objectForKey:key];
    if (object == nil)
    {
        UIFont *font = [UIFont fontWithName:fontName size:size];
        if (font == nil)
            return NULL;
        object = [NSDictionary dictionaryWithObject:font forKey:OGTextFontKey];
        [cache setObject:object forKey:key cost:1];
    }
    return (CTFontRef)OGTextCreateObject(object);
}

CFStringRef CTFontCopyPostScriptName(CTFontRef font)
{
    UIFont *uiFont = OGTextUIFont(font);
    return uiFont == nil ? NULL : (__bridge_retained CFStringRef)uiFont.fontName;
}

enum
{
    OGTextCoverageBitmapLength = 0x10000 / 8
};

static void OGTextCoverageMark(uint8_t *decided, uint8_t *present, uint32_t value, uint32_t glyph, size_t glyphCount)
{
    if (value > 0xffff || glyph == 0 || (value >= 0xd800 && value <= 0xdfff))
        return;
    uint8_t bit = (uint8_t)(1u << (value & 7));
    if ((decided[value >> 3] & bit) != 0)
        return;
    decided[value >> 3] |= bit;
    if (glyph < glyphCount)
        present[value >> 3] |= bit;
}

static void OGTextCoverageMarkSubtable(uint8_t *decided, uint8_t *present, const uint8_t *table, size_t length, size_t glyphCount)
{
    if (length < 2)
        return;
    uint16_t format = OGFontRead16(table);
    if (format == 0)
    {
        if (length < 262)
            return;
        for (uint32_t value = 0; value < 256; value++)
            OGTextCoverageMark(decided, present, value, table[6 + value], glyphCount);
    }
    else if (format == 4)
    {
        if (length < 16)
            return;
        size_t count = OGFontRead16(table + 6) / 2;
        if (count == 0 || count > (length - 16) / 8)
            return;
        const uint8_t *ends = table + 14;
        const uint8_t *starts = table + 16 + count * 2;
        const uint8_t *deltas = starts + count * 2;
        const uint8_t *offsets = deltas + count * 2;
        uint32_t covered = 0;
        for (size_t segment = 0; segment < count; segment++)
        {
            uint32_t start = MAX(covered, (uint32_t)OGFontRead16(starts + segment * 2));
            uint32_t end = OGFontRead16(ends + segment * 2);
            if (end < covered)
                continue;
            covered = end + 1;
            uint32_t segmentStart = OGFontRead16(starts + segment * 2);
            uint16_t delta = OGFontRead16(deltas + segment * 2);
            uint16_t offset = OGFontRead16(offsets + segment * 2);
            for (uint32_t value = start; value <= end; value++)
            {
                uint32_t glyph = 0;
                if (offset == 0)
                    glyph = (uint16_t)(value + delta);
                else
                {
                    size_t address = (size_t)(offsets - table) + segment * 2 + offset + (value - segmentStart) * 2;
                    if (address > length - 2)
                        break;
                    uint16_t raw = OGFontRead16(table + address);
                    glyph = raw == 0 ? 0 : (uint16_t)(raw + delta);
                }
                OGTextCoverageMark(decided, present, value, glyph, glyphCount);
            }
        }
    }
    else if (format == 6 || format == 10)
    {
        size_t header = format == 6 ? 10 : 20;
        if (length < header)
            return;
        uint32_t start = format == 6 ? OGFontRead16(table + 6) : OGFontRead32(table + 12);
        uint32_t count = format == 6 ? OGFontRead16(table + 8) : OGFontRead32(table + 16);
        if (count > (length - header) / 2 || start > 0xffff)
            return;
        uint32_t limit = MIN(count, 0x10000u - start);
        for (uint32_t index = 0; index < limit; index++)
            OGTextCoverageMark(decided, present, start + index, OGFontRead16(table + header + index * 2), glyphCount);
    }
    else if (format == 12 || format == 13)
    {
        if (length < 16)
            return;
        uint32_t count = OGFontRead32(table + 12);
        if (count > (length - 16) / 12)
            return;
        for (uint32_t index = 0; index < count; index++)
        {
            const uint8_t *group = table + 16 + index * 12;
            uint32_t start = OGFontRead32(group), end = MIN(OGFontRead32(group + 4), 0xffffu), glyph = OGFontRead32(group + 8);
            for (uint32_t value = start; value <= end; value++)
                OGTextCoverageMark(decided, present, value, format == 13 ? glyph : glyph + value - start, glyphCount);
        }
    }
}

static void OGTextCoverageAddBasicPlane(CFMutableCharacterSetRef characters, const uint8_t *bytes, size_t length, size_t glyphCount)
{
    if (bytes == NULL || length < 4)
        return;
    size_t recordCount = OGFontRead16(bytes + 2);
    if (recordCount > (length - 4) / 8)
        return;
    uint8_t *decided = (uint8_t *)calloc(OGTextCoverageBitmapLength * 2, 1);
    if (decided == NULL)
        return;
    uint8_t *present = decided + OGTextCoverageBitmapLength;
    for (size_t i = 0; i < recordCount; i++)
    {
        const uint8_t *record = bytes + 4 + i * 8;
        uint16_t platform = OGFontRead16(record), encoding = OGFontRead16(record + 2);
        if (platform != 0 && !(platform == 3 && (encoding == 1 || encoding == 10)))
            continue;
        size_t offset = OGFontRead32(record + 4);
        if (offset > length || length - offset < 4)
            continue;
        const uint8_t *table = bytes + offset;
        uint16_t format = OGFontRead16(table);
        bool longLength = format == 10 || format == 12 || format == 13;
        if (longLength && length - offset < 8)
            continue;
        size_t tableLength = longLength ? OGFontRead32(table + 4) : OGFontRead16(table + 2);
        if (tableLength > length - offset || tableLength < 4)
            continue;
        OGTextCoverageMarkSubtable(decided, present, table, tableLength, glyphCount);
    }
    uint32_t first = UINT32_MAX;
    for (uint32_t value = 0; value <= 0x10000; value++)
    {
        bool covered = value < 0x10000 && (present[value >> 3] & (1u << (value & 7))) != 0;
        if (covered && first == UINT32_MAX)
            first = value;
        else if (!covered && first != UINT32_MAX)
        {
            CFCharacterSetAddCharactersInRange(characters, CFRangeMake(first, value - first));
            first = UINT32_MAX;
        }
    }
    free(decided);
}

CFCharacterSetRef CTFontCopyCharacterSet(CTFontRef font)
{
    UIFont *uiFont = OGTextUIFont(font);
    if (uiFont == nil)
        return NULL;
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:48 costLimit:2 * 1024 * 1024];
    });
    id cached = [cache objectForKey:uiFont.fontName];
    if (cached != nil)
        return (CFCharacterSetRef)CFRetain((__bridge CFTypeRef)cached);
    OGTextFontCmap *cmap = OGTextFontCmapForName(uiFont.fontName);
    if (cmap == nil)
        return NULL;
    size_t glyphCount = cmap->_glyphCount;
    const uint8_t *bytes = (const uint8_t *)cmap->_table.bytes;
    size_t length = cmap->_table.length;
    CFMutableCharacterSetRef characters = CFCharacterSetCreateMutable(kCFAllocatorDefault);
    if (characters == NULL)
        return NULL;
    OGTextCoverageAddBasicPlane(characters, bytes, length, glyphCount);
    size_t recordCount = length >= 4 ? OGFontRead16(bytes + 2) : 0;
    if (length >= 4 && recordCount <= (length - 4) / 8)
    {
        for (size_t i = 0; i < recordCount; i++)
        {
            const uint8_t *record = bytes + 4 + i * 8;
            uint16_t platform = OGFontRead16(record), encoding = OGFontRead16(record + 2);
            if (platform != 0 && !(platform == 3 && encoding == 10))
                continue;
            size_t offset = OGFontRead32(record + 4);
            if (offset > length || length - offset < 16)
                continue;
            const uint8_t *table = bytes + offset;
            uint16_t format = OGFontRead16(table);
            size_t tableLength = OGFontRead32(table + 4);
            if (format == 10)
            {
                if (tableLength < 20 || tableLength > length - offset)
                    continue;
                uint32_t start = OGFontRead32(table + 12);
                size_t count = OGFontRead32(table + 16);
                if (count > (tableLength - 20) / 2)
                    continue;
                for (size_t j = 0; j < count; j++)
                {
                    uint64_t value = (uint64_t)start + j;
                    uint32_t glyph = OGFontRead16(table + 20 + j * 2);
                    if (value >= 0x10000 && value <= 0x10ffff && glyph != 0 && glyph < glyphCount)
                        CFCharacterSetAddCharactersInRange(characters, CFRangeMake((CFIndex)value, 1));
                }
                continue;
            }
            size_t count = OGFontRead32(table + 12);
            if ((format != 12 && format != 13) || tableLength < 16 || tableLength > length - offset || count > (tableLength - 16) / 12)
                continue;
            for (size_t j = 0; j < count; j++)
            {
                const uint8_t *group = table + 16 + j * 12;
                uint32_t start = OGFontRead32(group), end = OGFontRead32(group + 4), glyph = OGFontRead32(group + 8);
                uint32_t low = MAX(0x10000u, start), high = MIN(0x10ffffu, end);
                if (low > high)
                    continue;
                if (format == 13)
                {
                    if (glyph == 0 || glyph >= glyphCount)
                        continue;
                }
                else
                {
                    uint64_t firstGlyph = (uint64_t)glyph + low - start;
                    if (firstGlyph >= glyphCount)
                        continue;
                    if (firstGlyph == 0)
                    {
                        low++;
                        firstGlyph++;
                    }
                    if (firstGlyph >= glyphCount)
                        continue;
                    high = MIN(high, low + (uint32_t)(glyphCount - firstGlyph - 1));
                    if (low > high)
                        continue;
                }
                CFCharacterSetAddCharactersInRange(characters, CFRangeMake(low, high - low + 1));
            }
        }
    }
    [cache setObject:(__bridge id)characters forKey:uiFont.fontName cost:128 * 1024];
    return characters;
}

static uint32_t OGTextFirstUncoveredScalar(OGTextFontCmap *cmap, NSString *text)
{
    NSUInteger count = text.length;
    for (NSUInteger i = 0; i < count; i++)
    {
        uint32_t value = [text characterAtIndex:i];
        if (OGUnicodeIsHighSurrogate((uint16_t)value) && i + 1 < count && OGUnicodeIsLowSurrogate([text characterAtIndex:i + 1]))
            value = OGUnicodeScalarForSurrogatePair((uint16_t)value, [text characterAtIndex:++i]);
        if (cmap == nil || (value >= 0xd800 && value <= 0xdfff) || OGTextFontCmapGlyph(cmap, value) == 0)
            return value;
    }
    return 0;
}

static BOOL OGTextFontNameCovers(NSString *name, NSString *text, uint32_t value)
{
    CGFontRef cgFont = CGFontCreateWithFontName((__bridge CFStringRef)name);
    if (cgFont == NULL)
        return NO;
    CFDataRef table = CGFontCopyTableForTag(cgFont, 0x636d6170u);
    CGFontRelease(cgFont);
    if (table == NULL)
        return NO;
    const uint8_t *bytes = CFDataGetBytePtr(table);
    size_t length = (size_t)CFDataGetLength(table);
    BOOL covered = YES;
    if (text == nil)
        covered = OGFontCmapGlyph(bytes, length, value) != 0;
    else
    {
        NSUInteger count = text.length;
        for (NSUInteger i = 0; i < count && covered; i++)
        {
            uint32_t scalar = [text characterAtIndex:i];
            if (OGUnicodeIsHighSurrogate((uint16_t)scalar) && i + 1 < count && OGUnicodeIsLowSurrogate([text characterAtIndex:i + 1]))
                scalar = OGUnicodeScalarForSurrogatePair((uint16_t)scalar, [text characterAtIndex:++i]);
            covered = !(scalar >= 0xd800 && scalar <= 0xdfff) && OGFontCmapGlyph(bytes, length, scalar) != 0;
        }
    }
    CFRelease(table);
    return covered;
}

static BOOL OGTextFontNameCoversScalar(NSString *name, uint32_t value)
{
    return OGTextFontNameCovers(name, nil, value);
}

static NSString *OGTextFallbackFontNameForScalar(uint32_t value, NSArray *names)
{
    static OGMemoryCache *scalarFonts = nil;
    static OGMemoryCache *blockFonts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        scalarFonts = [[OGMemoryCache alloc] initWithCountLimit:2048 costLimit:0];
        blockFonts = [[OGMemoryCache alloc] initWithCountLimit:512 costLimit:0];
    });

    NSNumber *scalarKey = [[NSNumber alloc] initWithUnsignedInt:value];
    id cached = [scalarFonts objectForKey:scalarKey];
    if (cached != nil)
        return [cached isKindOfClass:[NSString class]] ? cached : nil;

    NSNumber *blockKey = [[NSNumber alloc] initWithUnsignedInt:value >> 7];
    NSString *blockFont = [blockFonts objectForKey:blockKey];
    NSString *result = nil;
    if ([blockFont isKindOfClass:[NSString class]] && OGTextFontNameCoversScalar(blockFont, value))
        result = blockFont;
    else
    {
        for (NSString *name in names)
        {
            if ([name isEqualToString:blockFont] || !OGTextFontNameCoversScalar(name, value))
                continue;
            result = name;
            break;
        }
    }

    [scalarFonts setObject:result != nil ? (id)result : (id)[NSNull null] forKey:scalarKey cost:1];
    if (result != nil)
        [blockFonts setObject:result forKey:blockKey cost:1];
    return result;
}

CTFontRef CTFontCreateForString(CTFontRef font, CFStringRef string, CFRange range)
{
    NSString *text = (__bridge NSString *)string;
    UIFont *baseFont = OGTextUIFont(font);
    if (baseFont == nil || range.location < 0 || range.length < 0 || (NSUInteger)range.location > text.length || (NSUInteger)range.length > text.length - (NSUInteger)range.location)
        return NULL;
    text = [text substringWithRange:NSMakeRange((NSUInteger)range.location, (NSUInteger)range.length)];
    if (OGTextFontCmapCoversString(OGTextFontCmapForName(baseFont.fontName), text))
        return (CTFontRef)CFRetain(font);

    static OGMemoryCache *resolved = nil;
    static NSArray *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        resolved = [[OGMemoryCache alloc] initWithCountLimit:512 costLimit:0];
        NSMutableArray *available = [[NSMutableArray alloc] init];
        for (NSString *family in [UIFont familyNames])
            [available addObjectsFromArray:[UIFont fontNamesForFamilyName:family]];
        names = [available copy];
    });

    NSString *key = [[NSString alloc] initWithFormat:@"%@\n%@", baseFont.fontName, text];
    id cached = [resolved objectForKey:key];
    if ([cached isKindOfClass:[NSString class]])
    {
        CTFontRef candidate = CTFontCreateWithName((__bridge CFStringRef)cached, CTFontGetSize(font), NULL);
        if (candidate != NULL)
            return candidate;
    }
    else if (cached != nil)
        return NULL;

    uint32_t uncovered = OGTextFirstUncoveredScalar(OGTextFontCmapForName(baseFont.fontName), text);
    NSString *fallbackName = uncovered == 0 ? nil : OGTextFallbackFontNameForScalar(uncovered, names);
    if (fallbackName == nil)
    {
        [resolved setObject:[NSNull null] forKey:key cost:1];
        return NULL;
    }
    if (!OGTextFontCmapCoversString(OGTextFontCmapForName(fallbackName), text))
    {
        NSString *coveringName = nil;
        for (NSString *name in names)
        {
            if (OGTextFontNameCovers(name, text, 0))
            {
                coveringName = name;
                break;
            }
        }
        fallbackName = coveringName;
    }
    CTFontRef candidate = fallbackName == nil ? NULL : CTFontCreateWithName((__bridge CFStringRef)fallbackName, CTFontGetSize(font), NULL);
    [resolved setObject:candidate != NULL ? (id)fallbackName : (id)[NSNull null] forKey:key cost:1];
    return candidate;
}

CGFloat CTFontGetSize(CTFontRef font)
{
    return OGTextUIFont(font).pointSize;
}

CGFloat CTFontGetAscent(CTFontRef font)
{
    return MAX(0.0f, OGTextUIFont(font).ascender);
}

CGFloat CTFontGetDescent(CTFontRef font)
{
    return MAX(0.0f, -OGTextUIFont(font).descender);
}

CGFloat CTFontGetLeading(CTFontRef font)
{
    UIFont *uiFont = OGTextUIFont(font);
    if (uiFont == nil)
        return 0.0f;
    CGFontRef cgFont = CGFontCreateWithFontName((__bridge CFStringRef)uiFont.fontName);
    if (cgFont == NULL)
        return 0.0f;
    int unitsPerEm = CGFontGetUnitsPerEm(cgFont);
    CGFloat leading = unitsPerEm > 0 ? (CGFloat)CGFontGetLeading(cgFont) * uiFont.pointSize / (CGFloat)unitsPerEm : 0.0f;
    CGFontRelease(cgFont);
    return MAX(0.0f, leading);
}

CGFloat CTFontGetCapHeight(CTFontRef font)
{
    return OGPlatformFontCapHeight(OGTextUIFont(font));
}

CTTypesetterRef CTTypesetterCreateWithAttributedString(CFAttributedStringRef string)
{
    id attributedString = (__bridge id)string;
    if (attributedString == nil)
        return NULL;
    OGTextTypesetter *typesetter = [[OGTextTypesetter alloc] initWithAttributedString:attributedString];
    return (CTTypesetterRef)OGTextCreateObject(typesetter);
}

static CFIndex OGTextSuggestBreak(CTTypesetterRef typesetterRef, CFIndex startIndex, double width, BOOL wordBreak)
{
    OGTextTypesetter *typesetter = OGTextTypesetterObject(typesetterRef);
    if (typesetter == nil)
        return 0;
    NSUInteger length = typesetter->_length;
    NSUInteger start = MIN((NSUInteger)MAX((CFIndex)0, startIndex), length);
    if (start >= length)
        return 0;
    CGFloat used = 0.0f;
    NSUInteger index = start;
    NSUInteger lastBreak = NSNotFound;
    CFIndex result = (CFIndex)(length - start);
    OSSpinLockLock(&typesetter->_lock);
    while (index < length)
    {
        OGTextClusterRecord cluster = OGTextTypesetterClusterInRange(typesetter, index, length);
        NSUInteger end = (NSUInteger)cluster.end;
        if ((cluster.flags & OGTextClusterNewline) != 0)
        {
            result = (CFIndex)(end - start);
            break;
        }
        if (used + cluster.width > width && index > start)
        {
            result = (CFIndex)((wordBreak && lastBreak != NSNotFound ? lastBreak : index) - start);
            break;
        }
        if (used + cluster.width > width)
        {
            result = (CFIndex)(end - start);
            break;
        }
        used += cluster.width;
        if ((cluster.flags & OGTextClusterWhitespace) != 0)
            lastBreak = end;
        index = end;
    }
    OSSpinLockUnlock(&typesetter->_lock);
    return result;
}

CFIndex CTTypesetterSuggestLineBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width)
{
    return OGTextSuggestBreak(typesetter, startIndex, width, YES);
}

CFIndex CTTypesetterSuggestClusterBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width)
{
    return OGTextSuggestBreak(typesetter, startIndex, width, NO);
}

static CTLineRef OGTextCreateTypesetterLine(CTTypesetterRef typesetterRef, CFRange stringRange, CGFloat offset)
{
    OGTextTypesetter *typesetter = OGTextTypesetterObject(typesetterRef);
    if (typesetter == nil)
        return NULL;
    NSUInteger length = typesetter->_length;
    if (stringRange.location < 0 || (NSUInteger)stringRange.location > length)
        return NULL;
    NSUInteger start = (NSUInteger)stringRange.location;
    NSUInteger end = stringRange.length == 0 ? length : MIN(length, start + (NSUInteger)MAX((CFIndex)0, stringRange.length));
    OGTextClusterRecord *clusters = OGTextAllocateRecords(end - start);
    if (clusters == NULL)
        return NULL;
    NSUInteger count = 0;
    OSSpinLockLock(&typesetter->_lock);
    NSUInteger index = start;
    while (index < end)
    {
        clusters[count] = OGTextTypesetterClusterInRange(typesetter, index, end);
        index = (NSUInteger)clusters[count].end;
        count++;
    }
    NSArray *styles = [typesetter->_styles copy];
    OSSpinLockUnlock(&typesetter->_lock);
    OGTextApplyTabWidths(clusters, count, styles, offset);
    CTLineRef line = OGTextLineCreate(clusters, count, styles, [NSArray arrayWithObject:typesetter->_string], CFRangeMake((CFIndex)start, (CFIndex)(end - start)), NO);
    free(clusters);
    return line;
}

CTLineRef CTTypesetterCreateLine(CTTypesetterRef typesetter, CFRange stringRange)
{
    return OGTextCreateTypesetterLine(typesetter, stringRange, 0.0f);
}

CTLineRef CTTypesetterCreateLineWithOffset(CTTypesetterRef typesetter, CFRange stringRange, double offset)
{
    return OGTextCreateTypesetterLine(typesetter, stringRange, (CGFloat)offset);
}

CTLineRef CTLineCreateWithAttributedString(CFAttributedStringRef string)
{
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(string);
    if (typesetter == NULL)
        return NULL;
    CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(0, 0));
    CFRelease(typesetter);
    return line;
}

CTLineRef CTLineCreateTruncatedLine(CTLineRef lineRef, double width, CTLineTruncationType truncationType, CTLineRef truncationTokenRef)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    OGTextLine *truncationToken = OGTextLineObject(truncationTokenRef);
    if (line == nil || truncationToken == nil || width < 0.0)
        return NULL;
    if (line->_width <= width)
        return (CTLineRef)CFRetain(lineRef);
    OGTextLineStorage *lineStorage = line->_storage;
    OGTextLineStorage *tokenStorage = truncationToken->_storage;
    NSUInteger sourceCount = lineStorage->_count;
    NSUInteger tokenCount = tokenStorage->_count;
    OGTextClusterRecord *source = OGTextLogicalClusters(line, 0, 0, NO);
    OGTextClusterRecord *token = OGTextLogicalClusters(truncationToken, (uint32_t)lineStorage->_styles.count, (uint16_t)lineStorage->_sources.count, YES);
    OGTextClusterRecord *result = OGTextAllocateRecords(sourceCount + tokenCount);
    if (source == NULL || token == NULL || result == NULL)
    {
        free(source);
        free(token);
        free(result);
        return NULL;
    }
    CGFloat tokenWidth = 0.0f;
    for (NSUInteger index = 0; index < tokenCount; index++)
        tokenWidth += token[index].width;
    CTLineRef truncated = NULL;
    if (tokenWidth <= width)
    {
        CGFloat available = (CGFloat)width - tokenWidth;
        NSUInteger output = 0;
        if (truncationType == kCTLineTruncationStart)
        {
            CGFloat used = 0.0f;
            NSUInteger first = sourceCount;
            while (first > 0)
            {
                CGFloat clusterWidth = source[first - 1].width;
                if (used + clusterWidth > available)
                    break;
                used += clusterWidth;
                first--;
            }
            memcpy(result, token, tokenCount * sizeof(OGTextClusterRecord));
            output = tokenCount;
            memcpy(result + output, source + first, (sourceCount - first) * sizeof(OGTextClusterRecord));
            output += sourceCount - first;
        }
        else if (truncationType == kCTLineTruncationMiddle)
        {
            CGFloat leftUsed = 0.0f;
            CGFloat rightUsed = 0.0f;
            NSUInteger left = 0;
            NSUInteger right = sourceCount;
            BOOL takeLeft = YES;
            while (left < right)
            {
                CGFloat clusterWidth = source[takeLeft ? left : right - 1].width;
                if (leftUsed + rightUsed + clusterWidth > available)
                    break;
                if (takeLeft)
                {
                    leftUsed += clusterWidth;
                    left++;
                }
                else
                {
                    rightUsed += clusterWidth;
                    right--;
                }
                takeLeft = leftUsed > rightUsed;
            }
            memcpy(result, source, left * sizeof(OGTextClusterRecord));
            output = left;
            memcpy(result + output, token, tokenCount * sizeof(OGTextClusterRecord));
            output += tokenCount;
            memcpy(result + output, source + right, (sourceCount - right) * sizeof(OGTextClusterRecord));
            output += sourceCount - right;
        }
        else
        {
            CGFloat used = 0.0f;
            for (NSUInteger index = 0; index < sourceCount; index++)
            {
                if (used + source[index].width > available)
                    break;
                result[output++] = source[index];
                used += source[index].width;
            }
            memcpy(result + output, token, tokenCount * sizeof(OGTextClusterRecord));
            output += tokenCount;
        }
        NSArray *styles = [lineStorage->_styles arrayByAddingObjectsFromArray:tokenStorage->_styles];
        NSArray *sources = [lineStorage->_sources arrayByAddingObjectsFromArray:tokenStorage->_sources];
        truncated = OGTextLineCreate(result, output, styles, sources, line->_range, NO);
    }
    free(source);
    free(token);
    free(result);
    return truncated;
}

CTLineRef CTLineCreateJustifiedLine(CTLineRef lineRef, CGFloat justificationFactor, double justificationWidth)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    if (line == nil || justificationFactor < 0.0f || justificationFactor > 1.0f)
        return NULL;
    if (justificationWidth <= line->_width)
        return (CTLineRef)CFRetain(lineRef);
    OGTextLineStorage *storage = line->_storage;
    NSUInteger count = storage->_count;
    NSUInteger spaces = 0;
    for (NSUInteger index = 0; index < count; index++)
    {
        if ((storage->_clusters[index].flags & (OGTextClusterWhitespace | OGTextClusterNewline)) == OGTextClusterWhitespace)
            spaces++;
    }
    if (spaces == 0)
        return (CTLineRef)CFRetain(lineRef);
    OGTextClusterRecord *clusters = OGTextLogicalClusters(line, 0, 0, NO);
    if (clusters == NULL)
        return NULL;
    CGFloat extra = ((CGFloat)justificationWidth - line->_width) * justificationFactor / (CGFloat)spaces;
    for (NSUInteger index = 0; index < count; index++)
    {
        if ((clusters[index].flags & (OGTextClusterWhitespace | OGTextClusterNewline)) == OGTextClusterWhitespace)
            clusters[index].width += extra;
    }
    CTLineRef justified = OGTextLineCreate(clusters, count, storage->_styles, storage->_sources, line->_range, YES);
    free(clusters);
    return justified;
}

double CTLineGetTypographicBounds(CTLineRef lineRef, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    if (ascent != NULL)
        *ascent = line == nil ? 0.0f : line->_ascent;
    if (descent != NULL)
        *descent = line == nil ? 0.0f : line->_descent;
    if (leading != NULL)
        *leading = line == nil ? 0.0f : line->_leading;
    return line == nil ? 0.0 : (double)line->_width;
}

double CTLineGetTrailingWhitespaceWidth(CTLineRef lineRef)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    return line == nil ? 0.0 : (double)line->_trailing;
}

CFRange CTLineGetStringRange(CTLineRef lineRef)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    return line == nil ? CFRangeMake(0, 0) : line->_range;
}

CFArrayRef CTLineGetGlyphRuns(CTLineRef lineRef)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    return (__bridge CFArrayRef)(line == nil ? [NSArray array] : line->_runs);
}

CGFloat CTLineGetOffsetForStringIndex(CTLineRef lineRef, CFIndex charIndex, CGFloat *secondaryOffset)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    if (line == nil)
    {
        if (secondaryOffset != NULL)
            *secondaryOffset = 0.0f;
        return 0.0f;
    }
    OGTextLineStorage *storage = line->_storage;
    for (NSUInteger index = 0; index < storage->_count; index++)
    {
        const OGTextClusterRecord *cluster = &storage->_clusters[index];
        if (cluster->start < 0 || cluster->end < 0)
            continue;
        if (charIndex >= cluster->start && charIndex <= cluster->end)
        {
            BOOL rtl = (cluster->flags & OGTextClusterRTL) != 0;
            CGFloat x = cluster->x;
            CGFloat width = cluster->width;
            CGFloat primary = rtl ? (charIndex == cluster->start ? x + width : x) : (charIndex == cluster->end ? x + width : x);
            if (secondaryOffset != NULL)
                *secondaryOffset = rtl ? (charIndex == cluster->start ? x : x + width) : primary;
            return primary;
        }
    }
    CGFloat offset = charIndex <= line->_range.location ? 0.0f : line->_width;
    if (secondaryOffset != NULL)
        *secondaryOffset = offset;
    return offset;
}

CGFloat CTLineGetPenOffsetForFlush(CTLineRef line, CGFloat flushFactor, double flushWidth)
{
    return ((CGFloat)flushWidth - (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL)) * flushFactor;
}

static UIColor *OGTextColorFromAttributes(NSDictionary *attributes)
{
    id value = [attributes objectForKey:(__bridge NSString *)kCTForegroundColorAttributeName];
    if ([value isKindOfClass:[UIColor class]])
        return value;
    if (value != nil)
        return [UIColor colorWithCGColor:(__bridge CGColorRef)value];
    value = [attributes objectForKey:@"NSColor"];
    return [value isKindOfClass:[UIColor class]] ? value : nil;
}

static void OGTextDrawRun(OGTextRun *run, CGContextRef context, CGPoint origin)
{
    OGTextStyle *style = run->_style;
    if (style == nil || style->_owner != nil)
        return;
    NSDictionary *attributes = style->_attributes;
    UIFont *font = style->_font;
    UIColor *color = OGTextColorFromAttributes(attributes);
    BOOL fromContext = [[[attributes objectForKey:(__bridge NSString *)kCTForegroundColorFromContextAttributeName] description] boolValue];
    OGTextLineStorage *storage = run->_storage;
    CGContextSaveGState(context);
    if (!fromContext && color != nil)
    {
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextSetStrokeColorWithColor(context, color.CGColor);
    }
    if (run->_justified)
    {
        NSUInteger end = run->_first + run->_count;
        NSUInteger index = run->_first;
        while (index < end)
        {
            if ((storage->_clusters[index].flags & OGTextClusterWhitespace) != 0)
            {
                index++;
                continue;
            }
            NSUInteger wordEnd = index + 1;
            while (wordEnd < end && (storage->_clusters[wordEnd].flags & OGTextClusterWhitespace) == 0)
                wordEnd++;
            NSString *word = OGTextClustersString(storage, index, wordEnd - index, run->_rtl);
            OGTextDrawGlyphRun(context, word, font, CGPointMake(origin.x + storage->_clusters[index].x, origin.y), run->_rtl);
            index = wordEnd;
        }
    }
    else
        OGTextDrawGlyphRun(context, OGTextClustersString(storage, run->_first, run->_count, run->_rtl), font, CGPointMake(origin.x + run->_x, origin.y), run->_rtl);
    NSNumber *underline = [attributes objectForKey:(__bridge NSString *)kCTUnderlineStyleAttributeName];
    if (underline == nil)
        underline = [attributes objectForKey:@"NSUnderline"];
    if ([underline integerValue] != 0)
    {
        CGContextSetLineWidth(context, MAX(1.0f, font.pointSize / 14.0f));
        CGContextMoveToPoint(context, origin.x + run->_x, origin.y + 1.0f);
        CGContextAddLineToPoint(context, origin.x + run->_x + run->_width, origin.y + 1.0f);
        CGContextStrokePath(context);
    }
    CGContextRestoreGState(context);
}

void CTLineDraw(CTLineRef lineRef, CGContextRef context)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    if (line == nil || context == NULL)
        return;
    CGPoint origin = CGContextGetTextPosition(context);
    for (OGTextRun *run in line->_runs)
        OGTextDrawRun(run, context, origin);
}

CFDictionaryRef CTRunGetAttributes(CTRunRef runRef)
{
    OGTextRun *run = OGTextRunObject(runRef);
    if (run == nil)
        return NULL;
    return (__bridge CFDictionaryRef)(run->_style == nil ? [NSDictionary dictionary] : run->_style->_attributes);
}

CFIndex CTRunGetGlyphCount(CTRunRef runRef)
{
    OGTextRun *run = OGTextRunObject(runRef);
    return run == nil ? 0 : (CFIndex)run->_count;
}

static NSRange OGTextValidatedGlyphRange(NSUInteger count, CFRange range)
{
    NSUInteger location = range.location < 0 ? 0 : MIN((NSUInteger)range.location, count);
    NSUInteger length = range.length == 0 ? count - location : MIN((NSUInteger)MAX((CFIndex)0, range.length), count - location);
    return NSMakeRange(location, length);
}

double CTRunGetTypographicBounds(CTRunRef runRef, CFRange range, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    OGTextRun *run = OGTextRunObject(runRef);
    NSRange validRange = OGTextValidatedGlyphRange(run == nil ? 0 : run->_count, range);
    CGFloat width = 0.0f;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
        width += run->_storage->_clusters[run->_first + index].width;
    BOOL measured = validRange.length != 0;
    if (ascent != NULL)
        *ascent = measured ? run->_ascent : 0.0f;
    if (descent != NULL)
        *descent = measured ? run->_descent : 0.0f;
    if (leading != NULL)
        *leading = measured ? run->_leading : 0.0f;
    return width;
}

CFRange CTRunGetStringRange(CTRunRef runRef)
{
    OGTextRun *run = OGTextRunObject(runRef);
    return run == nil ? CFRangeMake(kCFNotFound, 0) : run->_range;
}

void CTRunGetStringIndices(CTRunRef runRef, CFRange range, CFIndex buffer[])
{
    OGTextRun *run = OGTextRunObject(runRef);
    if (run == nil || buffer == NULL)
        return;
    NSRange validRange = OGTextValidatedGlyphRange(run->_count, range);
    NSUInteger output = 0;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
        buffer[output++] = run->_storage->_clusters[run->_first + index].start;
}

void CTRunGetPositions(CTRunRef runRef, CFRange range, CGPoint buffer[])
{
    OGTextRun *run = OGTextRunObject(runRef);
    if (run == nil || buffer == NULL)
        return;
    NSRange validRange = OGTextValidatedGlyphRange(run->_count, range);
    NSUInteger output = 0;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
        buffer[output++] = CGPointMake(run->_storage->_clusters[run->_first + index].x, 0.0f);
}

void CTRunDraw(CTRunRef runRef, CGContextRef context, CFRange range)
{
    OGTextRun *run = OGTextRunObject(runRef);
    if (run == nil || context == NULL)
        return;
    NSRange validRange = OGTextValidatedGlyphRange(run->_count, range);
    if (validRange.length == 0)
        return;
    CGPoint origin = CGContextGetTextPosition(context);
    if (validRange.location == 0 && validRange.length == run->_count)
    {
        OGTextDrawRun(run, context, origin);
        return;
    }
    NSUInteger first = run->_first + validRange.location;
    OGTextDrawRun(OGTextRunCreate(run->_storage, first, validRange.length, run->_rtl, run->_storage->_clusters[first].x, run->_justified), context, origin);
}

CTRunStatus CTRunGetStatus(CTRunRef runRef)
{
    OGTextRun *run = OGTextRunObject(runRef);
    return run != nil && run->_rtl ? kCTRunStatusRightToLeft : kCTRunStatusNoStatus;
}

CTRunDelegateRef CTRunDelegateCreate(const CTRunDelegateCallbacks *callbacks, void *refCon)
{
    if (callbacks == NULL || callbacks->version != kCTRunDelegateVersion1)
        return NULL;
    OGPlatformRunDelegateOwner *owner = [[OGPlatformRunDelegateOwner alloc] initWithCallbacks:callbacks refCon:refCon];
    NSDictionary *delegate = [NSDictionary dictionaryWithObject:owner forKey:OGTextDelegateOwnerKey];
    return (CTRunDelegateRef)OGTextCreateObject(delegate);
}

void OGPlatformAttributedStringSetAttribute(CFMutableAttributedStringRef string, CFRange range, CFStringRef name, CFTypeRef value)
{
    id attributedString = (__bridge id)string;
    if (attributedString == nil || name == NULL || value == NULL || range.location < 0 || range.length < 0)
        return;
    NSUInteger length = [attributedString length];
    if ((NSUInteger)range.location > length)
        return;
    NSRange validRange = NSIntersectionRange(NSMakeRange((NSUInteger)range.location, (NSUInteger)range.length), NSMakeRange(0, length));
    [attributedString addAttribute:(__bridge NSString *)name value:(__bridge id)value range:validRange];
}

#endif

static CGFloat OGTextLineVisibleWidth(CTLineRef line)
{
    return (CGFloat)(CTLineGetTypographicBounds(line, NULL, NULL, NULL) - CTLineGetTrailingWhitespaceWidth(line));
}

static CFIndex OGTextComposedBoundaryBefore(NSString *text, CFIndex index, CFIndex lower)
{
    if (index <= lower)
        return lower;
    CFIndex location = (CFIndex)[text rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)(index - 1)].location;
    return MAX(lower, MIN(location, index - 1));
}

static CFIndex OGTextComposedBoundaryAfter(NSString *text, CFIndex index, CFIndex upper)
{
    if (index >= upper)
        return upper;
    CFIndex end = (CFIndex)NSMaxRange([text rangeOfComposedCharacterSequenceAtIndex:(NSUInteger)index]);
    return MIN(upper, MAX(end, index + 1));
}

static CFIndex OGTextTrimTrailingWhitespace(NSString *text, CFIndex lower, CFIndex end)
{
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    while (end > lower && [whitespace characterIsMember:[text characterAtIndex:(NSUInteger)(end - 1)]])
        end--;
    return end;
}

static CTLineRef OGTextCreateLineInSubstring(id source, CFIndex start, CFIndex headEnd, id token, CFIndex tailStart, CFIndex limit, double offset)
{
    id composed = [[source attributedSubstringFromRange:NSMakeRange(0, (NSUInteger)headEnd)] mutableCopy];
    if (composed == nil)
        return NULL;
    if (token != nil)
        [composed appendAttributedString:token];
    if (tailStart < limit)
        [composed appendAttributedString:[source attributedSubstringFromRange:NSMakeRange((NSUInteger)tailStart, (NSUInteger)(limit - tailStart))]];
    CFIndex length = (CFIndex)[composed length];
    if (length == start)
        return CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)[composed attributedSubstringFromRange:NSMakeRange((NSUInteger)start, 0)]);
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)composed);
    if (typesetter == NULL)
        return NULL;
    CTLineRef line = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(start, length - start), offset);
    CFRelease(typesetter);
    return line;
}

static CTLineRef OGTextCreateTruncatedLineInRange(CTTypesetterRef typesetter, id source, CFIndex start, CFIndex limit, double offset, double width, CTLineTruncationType truncationType, id token)
{
    CTLineRef tokenLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)token);
    if (tokenLine == NULL)
        return NULL;
    CGFloat tokenWidth = (CGFloat)CTLineGetTypographicBounds(tokenLine, NULL, NULL, NULL);
    CFRelease(tokenLine);
    if (tokenWidth > width)
        return NULL;

    NSString *text = [source string];
    CGFloat available = (CGFloat)width - tokenWidth;

    CFIndex headEnd = start;
    if (truncationType != kCTLineTruncationStart && limit > start)
    {
        CGFloat headBudget = truncationType == kCTLineTruncationMiddle ? available / 2.0f : available;
        if (headBudget > 0.0f)
        {
            CFIndex count = CTTypesetterSuggestClusterBreak(typesetter, start, headBudget);
            headEnd = start + MAX((CFIndex)0, MIN(count, limit - start));
        }
        if (truncationType == kCTLineTruncationEnd)
            headEnd = OGTextTrimTrailingWhitespace(text, start, headEnd);
    }

    CFIndex tailStart = limit;
    if (truncationType != kCTLineTruncationEnd && limit > headEnd)
    {
        CGFloat headWidth = 0.0f;
        if (headEnd > start)
        {
            CTLineRef headLine = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(start, headEnd - start), offset);
            if (headLine != NULL)
            {
                headWidth = (CGFloat)CTLineGetTypographicBounds(headLine, NULL, NULL, NULL);
                CFRelease(headLine);
            }
        }
        CGFloat tailBudget = available - headWidth;
        if (tailBudget > 0.0f)
        {
            CTLineRef tailLine = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(headEnd, limit - headEnd), offset);
            if (tailLine != NULL)
            {
                CGFloat endOffset = CTLineGetOffsetForStringIndex(tailLine, limit, NULL);
                CFIndex candidate = limit;
                while (candidate > headEnd)
                {
                    CFIndex previous = OGTextComposedBoundaryBefore(text, candidate, headEnd);
                    if (fabs((double)(endOffset - CTLineGetOffsetForStringIndex(tailLine, previous, NULL))) > (double)tailBudget)
                        break;
                    candidate = previous;
                }
                tailStart = candidate;
                CFRelease(tailLine);
            }
        }
    }

    while (true)
    {
        CTLineRef line = OGTextCreateLineInSubstring(source, start, headEnd, token, tailStart, limit, offset);
        if (line == NULL)
            return NULL;
        if ((headEnd == start && tailStart == limit) || OGTextLineVisibleWidth(line) <= (CGFloat)width)
            return line;
        CFRelease(line);
        if (tailStart < limit && (headEnd == start || limit - tailStart >= headEnd - start))
            tailStart = OGTextComposedBoundaryAfter(text, tailStart, limit);
        else
        {
            headEnd = OGTextComposedBoundaryBefore(text, headEnd, start);
            if (truncationType == kCTLineTruncationEnd)
                headEnd = OGTextTrimTrailingWhitespace(text, start, headEnd);
        }
    }
}

CTLineRef OGPlatformCreateTruncatedLine(CTTypesetterRef typesetter, CFAttributedStringRef string, CFRange range, double offset, double width, CTLineTruncationType truncationType, CFAttributedStringRef truncationToken, bool forceTruncationToken)
{
    id source = (__bridge id)string;
    id token = (__bridge id)truncationToken;
    if (source == nil || token == nil || width < 0.0)
        return NULL;
    CFIndex length = (CFIndex)[source length];
    if (range.location < 0 || range.length < 0 || range.location > length)
        return NULL;
    CFIndex start = range.location;
    CFIndex limit = MIN(length, start + range.length);

    if (!forceTruncationToken && limit == start)
        return OGTextCreateLineInSubstring(source, start, start, nil, limit, limit, offset);

    CTTypesetterRef ownTypesetter = NULL;
    if (typesetter == NULL)
    {
        ownTypesetter = CTTypesetterCreateWithAttributedString(string);
        if (ownTypesetter == NULL)
            return NULL;
        typesetter = ownTypesetter;
    }

    CTLineRef result = NULL;
    if (!forceTruncationToken)
    {
        CTLineRef full = CTTypesetterCreateLineWithOffset(typesetter, CFRangeMake(start, limit - start), offset);
        if (full != NULL)
        {
            if (OGTextLineVisibleWidth(full) <= (CGFloat)width)
                result = full;
            else
                CFRelease(full);
        }
    }
    if (result == NULL)
        result = OGTextCreateTruncatedLineInRange(typesetter, source, start, limit, offset, width, truncationType, token);

    if (ownTypesetter != NULL)
        CFRelease(ownTypesetter);
    return result;
}

NSString *OGPlatformDateFormatFromTemplate(NSString *templateString, NSUInteger options, NSLocale *locale)
{
    SEL selector = NSSelectorFromString(@"dateFormatFromTemplate:options:locale:");
    Class formatterClass = [NSDateFormatter class];
    if ([formatterClass respondsToSelector:selector])
    {
        NSString *(*function)(id, SEL, NSString *, NSUInteger, NSLocale *) = (NSString *(*)(id, SEL, NSString *, NSUInteger, NSLocale *))[formatterClass methodForSelector:selector];
        if (function != NULL)
        {
            NSString *format = function(formatterClass, selector, templateString, options, locale);
            if ([format length] != 0)
                return format;
        }
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (locale != nil)
        [formatter setLocale:locale];

    BOOL wantsTime = [templateString rangeOfString:@"H"].location != NSNotFound || [templateString rangeOfString:@"h"].location != NSNotFound || [templateString rangeOfString:@"m"].location != NSNotFound || [templateString rangeOfString:@"s"].location != NSNotFound;
    if (wantsTime)
    {
        [formatter setDateStyle:NSDateFormatterNoStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    }
    else
    {
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterNoStyle];
    }

    SEL dateFormatSelector = NSSelectorFromString(@"dateFormat");
    if ([formatter respondsToSelector:dateFormatSelector])
    {
        NSString *(*function)(id, SEL) = (NSString *(*)(id, SEL))[formatter methodForSelector:dateFormatSelector];
        if (function != NULL)
        {
            NSString *format = function(formatter, dateFormatSelector);
            if ([format length] != 0)
                return format;
        }
    }

    if (wantsTime)
        return @"HH:mm";
    return @"M/d/yy";
}

NSString *OGPlatformLocalizedStringFromDate(NSDate *date, NSDateFormatterStyle dateStyle, NSDateFormatterStyle timeStyle)
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = dateStyle;
    formatter.timeStyle = timeStyle;
    return [formatter stringFromDate:date];
}

BOOL OGPlatformLanguageIsRightToLeft(NSString *languageCode)
{
    if ([languageCode length] == 0)
        return NO;
    NSString *value = [languageCode lowercaseString];
    NSRange dash = [value rangeOfString:@"-"];
    NSRange underscore = [value rangeOfString:@"_"];
    NSUInteger cut = NSNotFound;
    if (dash.location != NSNotFound)
        cut = dash.location;
    if (underscore.location != NSNotFound && (cut == NSNotFound || underscore.location < cut))
        cut = underscore.location;
    if (cut != NSNotFound)
        value = [value substringToIndex:cut];
    return [value isEqualToString:@"ar"] || [value isEqualToString:@"he"] || [value isEqualToString:@"fa"] || [value isEqualToString:@"ur"] || [value isEqualToString:@"ps"] || [value isEqualToString:@"dv"] || [value isEqualToString:@"ku"] || [value isEqualToString:@"yi"];
}

CGSize OGPlatformTextSize(NSString *text, UIFont *font, CGSize constrainedSize, UILineBreakMode lineBreakMode)
{
    if ([text length] == 0 || font == nil)
        return CGSizeZero;
    return [text sizeWithFont:font constrainedToSize:constrainedSize lineBreakMode:lineBreakMode];
}

CGFloat OGPlatformFontLineHeight(UIFont *font)
{
    if (font == nil)
        return 0.0f;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    return font.lineHeight;
#else
    CGFloat height = font.leading;
    return height > 0.0f && isfinite(height) ? height : MAX(0.0f, font.ascender - font.descender);
#endif
}

CGFloat OGPlatformFontCapHeight(UIFont *font)
{
    if (font == nil)
        return 0.0f;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    if ([font respondsToSelector:@selector(capHeight)])
        return font.capHeight;
#endif
    CGFontRef cgFont = CGFontCreateWithFontName((__bridge CFStringRef)font.fontName);
    if (cgFont == NULL)
        return 0.0f;
    int unitsPerEm = CGFontGetUnitsPerEm(cgFont);
    CGFloat capHeight = unitsPerEm > 0 ? (CGFloat)CGFontGetCapHeight(cgFont) * font.pointSize / (CGFloat)unitsPerEm : 0.0f;
    CGFontRelease(cgFont);
    return capHeight;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@implementation NSSortDescriptor (OnegramIOS3Compatibility)

+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending
{
    return [[self alloc] initWithKey:key ascending:ascending];
}

+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector
{
    return [[self alloc] initWithKey:key ascending:ascending selector:selector];
}

@end
#endif
