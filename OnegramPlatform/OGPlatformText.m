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

static NSDictionary *OGTextAttributesAtIndex(id attributedString, NSUInteger index)
{
    if (index >= (NSUInteger)[attributedString length])
        return [NSDictionary dictionary];
    NSDictionary *attributes = [attributedString attributesAtIndex:index effectiveRange:NULL];
    return attributes == nil ? [NSDictionary dictionary] : attributes;
}

static OGPlatformRunDelegateOwner *OGTextRunDelegateOwner(NSDictionary *attributes)
{
    id delegate = [attributes objectForKey:(__bridge NSString *)kCTRunDelegateAttributeName];
    if (![delegate isKindOfClass:[NSDictionary class]])
        return nil;
    id owner = [delegate objectForKey:OGTextDelegateOwnerKey];
    return [owner isKindOfClass:[OGPlatformRunDelegateOwner class]] ? owner : nil;
}

@interface OGTextFontCmap : NSObject
{
@public
    NSData *_table;
    size_t _glyphCount;
    CGFontRef _font;
    CGFloat _unitsPerEm;
}
@end

@implementation OGTextFontCmap

- (void)dealloc
{
    if (_font != NULL)
        CGFontRelease(_font);
}

@end

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
    cmap->_glyphCount = CGFontGetNumberOfGlyphs(cgFont);
    cmap->_font = cgFont;
    cmap->_unitsPerEm = (CGFloat)unitsPerEm;
    [cache setObject:cmap forKey:fontName cost:cmap->_table.length];
    return cmap;
}

static BOOL OGTextFontCmapCoversString(OGTextFontCmap *cmap, NSString *text)
{
    if (cmap == nil)
        return NO;
    const uint8_t *bytes = (const uint8_t *)cmap->_table.bytes;
    size_t length = cmap->_table.length;
    NSUInteger count = text.length;
    for (NSUInteger i = 0; i < count; i++)
    {
        uint32_t value = [text characterAtIndex:i];
        if (OGUnicodeIsHighSurrogate((uint16_t)value) && i + 1 < count && OGUnicodeIsLowSurrogate([text characterAtIndex:i + 1]))
            value = OGUnicodeScalarForSurrogatePair((uint16_t)value, [text characterAtIndex:++i]);
        if (value >= 0xd800 && value <= 0xdfff)
            return NO;
        uint32_t glyph = OGFontCmapGlyph(bytes, length, value);
        if (glyph == 0 || glyph >= cmap->_glyphCount)
            return NO;
    }
    return YES;
}

static uint32_t OGTextFontCmapGlyph(OGTextFontCmap *cmap, uint32_t value)
{
    if (value >= 0xd800 && value <= 0xdfff)
        return 0;
    uint32_t glyph = OGFontCmapGlyph((const uint8_t *)cmap->_table.bytes, cmap->_table.length, value);
    return glyph < cmap->_glyphCount ? glyph : 0;
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
    uint32_t *scalars = (uint32_t *)malloc(length * sizeof(uint32_t));
    NSUInteger *scalarSources = (NSUInteger *)malloc(length * sizeof(NSUInteger));
    if (scalars == NULL || scalarSources == NULL)
    {
        free(scalars);
        free(scalarSources);
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
    free(scalars);
    free(scalarSources);
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
    int *units = (int *)calloc(count, sizeof(int));
    if (units == NULL)
        return 0.0f;
    CGFontGetGlyphAdvances(cmap->_font, glyphs, count, units);
    CGFloat scale = pointSize / cmap->_unitsPerEm;
    CGFloat total = 0.0f;
    for (NSUInteger index = 0; index < count; index++)
    {
        advances[index] = (CGFloat)units[index] * scale;
        total += advances[index];
    }
    free(units);
    return total;
}

static CGFloat OGTextGlyphRunWidth(NSString *string, UIFont *font)
{
    OGTextFontCmap *cmap = OGTextFontCmapForName(font.fontName);
    NSUInteger length = string.length;
    if (cmap == nil || length == 0)
        return 0.0f;
    if (length == 1)
    {
        unichar value = [string characterAtIndex:0];
        if (!(value >= 0x0600 && value <= 0x06ff) && !OGUnicodeIsHighSurrogate(value) && !OGUnicodeIsLowSurrogate(value))
        {
            if (OGTextScalarIsInvisible(value))
                return 0.0f;
            CGGlyph glyph = (CGGlyph)OGTextFontCmapGlyph(cmap, value);
            int advance = 0;
            CGFontGetGlyphAdvances(cmap->_font, &glyph, 1, &advance);
            return (CGFloat)advance * font.pointSize / cmap->_unitsPerEm;
        }
    }
    CGGlyph *glyphs = (CGGlyph *)malloc(length * sizeof(CGGlyph));
    bool *clusterStarts = (bool *)malloc(length * sizeof(bool));
    CGFloat *advances = (CGFloat *)malloc(length * sizeof(CGFloat));
    CGFloat width = 0.0f;
    if (glyphs != NULL && clusterStarts != NULL && advances != NULL)
    {
        NSUInteger count = OGTextShapeGlyphs(cmap, string, glyphs, clusterStarts);
        width = OGTextGlyphAdvances(cmap, font.pointSize, glyphs, count, advances);
    }
    free(glyphs);
    free(clusterStarts);
    free(advances);
    return width;
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
        if (output != 0)
        {
            CGAffineTransform savedMatrix = CGContextGetTextMatrix(context);
            CGPoint savedPosition = CGContextGetTextPosition(context);
            CGContextSetFont(context, cmap->_font);
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

static CGFloat OGTextMeasure(NSString *string, NSDictionary *attributes, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    OGPlatformRunDelegateOwner *owner = OGTextRunDelegateOwner(attributes);
    if (owner != nil)
    {
        if (ascent != NULL)
            *ascent = [owner ascent];
        if (descent != NULL)
            *descent = [owner descent];
        if (leading != NULL)
            *leading = 0.0f;
        return [owner width];
    }
    UIFont *font = OGTextFontFromAttributes(attributes);
    if (ascent != NULL)
        *ascent = MAX(0.0f, font.ascender);
    if (descent != NULL)
        *descent = MAX(0.0f, -font.descender);
    if (leading != NULL)
        *leading = MAX(0.0f, OGPlatformFontLineHeight(font) - font.ascender + font.descender);
    if ([string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound)
        return 0.0f;
    return OGTextGlyphRunWidth(string, font);
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
    CFCharacterSetRef whitespace = CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline);
    CFCharacterSetRef newline = CFCharacterSetGetPredefined(kCFCharacterSetNewline);
    BOOL allWhitespace = YES;
    for (NSUInteger index = 0; index < length; index++)
    {
        if (!CFCharacterSetIsCharacterMember(whitespace, characters[index]))
            allWhitespace = NO;
        if (CFCharacterSetIsCharacterMember(newline, characters[index]))
            flags |= OGTextClusterNewline;
    }
    if (allWhitespace)
        flags |= OGTextClusterWhitespace;
    if (length == 1 && characters[0] == '\t')
        flags |= OGTextClusterTab;
    return flags;
}

@interface OGTextCluster : NSObject
{
@public
    NSString *_source;
    NSDictionary *_attributes;
    NSRange _characters;
    CFIndex _start;
    CFIndex _end;
    CGFloat _width;
    CGFloat _x;
    CGFloat _ascent;
    CGFloat _descent;
    CGFloat _leading;
    uint8_t _flags;
}
@end

@implementation OGTextCluster
@end

static OGTextCluster *OGTextClusterCopy(OGTextCluster *cluster)
{
    OGTextCluster *copy = [[OGTextCluster alloc] init];
    copy->_source = cluster->_source;
    copy->_attributes = cluster->_attributes;
    copy->_characters = cluster->_characters;
    copy->_start = cluster->_start;
    copy->_end = cluster->_end;
    copy->_width = cluster->_width;
    copy->_x = cluster->_x;
    copy->_ascent = cluster->_ascent;
    copy->_descent = cluster->_descent;
    copy->_leading = cluster->_leading;
    copy->_flags = cluster->_flags;
    return copy;
}

static OGTextCluster *OGTextClusterCreateMeasured(NSString *source, const unichar *characters, NSRange range, NSDictionary *attributes)
{
    OGTextCluster *cluster = [[OGTextCluster alloc] init];
    cluster->_source = source;
    cluster->_attributes = attributes;
    cluster->_characters = range;
    cluster->_start = (CFIndex)range.location;
    cluster->_end = (CFIndex)NSMaxRange(range);
    cluster->_flags = OGTextClusterFlags(characters + range.location, range.length);
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    cluster->_width = OGTextMeasure([source substringWithRange:range], attributes, &ascent, &descent, &leading);
    cluster->_ascent = ascent;
    cluster->_descent = descent;
    cluster->_leading = leading;
    return cluster;
}

static NSString *OGTextClustersString(NSArray *clusters, BOOL reverse)
{
    NSMutableString *string = nil;
    NSString *source = nil;
    NSRange pending = NSMakeRange(0, 0);
    NSEnumerator *enumerator = reverse ? [clusters reverseObjectEnumerator] : [clusters objectEnumerator];
    for (OGTextCluster *cluster in enumerator)
    {
        if (cluster->_source == source && NSMaxRange(pending) == cluster->_characters.location)
        {
            pending.length += cluster->_characters.length;
            continue;
        }
        if (source != nil && pending.length != 0)
        {
            if (string == nil)
                string = [[NSMutableString alloc] init];
            [string appendString:[source substringWithRange:pending]];
        }
        source = cluster->_source;
        pending = cluster->_characters;
    }
    if (string == nil)
        return source == nil || pending.length == 0 ? @"" : [source substringWithRange:pending];
    if (source != nil && pending.length != 0)
        [string appendString:[source substringWithRange:pending]];
    return string;
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
    OGTextCluster * __unsafe_unretained *_clusterAtStart;
    uint8_t *_measured;
    NSMutableArray *_clusters;
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
        _length = [_string length];
        _clusters = [[NSMutableArray alloc] init];
        _lock = OS_SPINLOCK_INIT;
        if (_length != 0)
        {
            _characters = (unichar *)malloc(_length * sizeof(unichar));
            _clusterAtStart = (OGTextCluster * __unsafe_unretained *)calloc(_length, sizeof(OGTextCluster *));
            _measured = (uint8_t *)calloc(_length, sizeof(uint8_t));
            if (_characters == NULL || _clusterAtStart == NULL || _measured == NULL)
                return nil;
            [_string getCharacters:_characters range:NSMakeRange(0, _length)];
        }
    }
    return self;
}

- (void)dealloc
{
    free(_characters);
    free(_clusterAtStart);
    free(_measured);
}

@end

static OGTextTypesetter *OGTextTypesetterObject(CTTypesetterRef typesetter)
{
    id object = OGTextObject(typesetter);
    return [object isKindOfClass:[OGTextTypesetter class]] ? object : nil;
}

static void OGTextTypesetterMeasureChunk(OGTextTypesetter *typesetter, NSUInteger start)
{
    const unichar *characters = typesetter->_characters;
    NSUInteger length = typesetter->_length;
    NSRange attributesRange = NSMakeRange(NSNotFound, 0);
    NSDictionary *attributes = [typesetter->_attributedString attributesAtIndex:start effectiveRange:&attributesRange];
    if (attributes == nil)
        attributes = [NSDictionary dictionary];
    NSUInteger runLimit = attributesRange.location != NSNotFound && attributesRange.location <= start && NSMaxRange(attributesRange) > start ? MIN(length, NSMaxRange(attributesRange)) : start + 1;

    CFCharacterSetRef whitespace = CFCharacterSetGetPredefined(kCFCharacterSetWhitespaceAndNewline);
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
        if (units >= OGTextChunkSoftLimit && CFCharacterSetIsCharacterMember(whitespace, characters[cursor - 1]))
            break;
    }
    NSUInteger units = cursor - start;

    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    OGPlatformRunDelegateOwner *owner = OGTextRunDelegateOwner(attributes);
    if (owner != nil)
    {
        ascent = [owner ascent];
        descent = [owner descent];
        CGFloat width = [owner width];
        for (NSUInteger index = 0; index < count; index++)
            widths[index] = width;
    }
    else
    {
        UIFont *font = OGTextFontFromAttributes(attributes);
        ascent = MAX(0.0f, font.ascender);
        descent = MAX(0.0f, -font.descender);
        leading = MAX(0.0f, OGPlatformFontLineHeight(font) - font.ascender + font.descender);
        OGTextFontCmap *cmap = OGTextFontCmapForName(font.fontName);
        if (cmap != nil)
        {
            CGGlyph *glyphs = (CGGlyph *)malloc(units * sizeof(CGGlyph));
            NSUInteger *sources = (NSUInteger *)malloc(units * sizeof(NSUInteger));
            CGFloat *advances = (CGFloat *)malloc(units * sizeof(CGFloat));
            if (glyphs != NULL && sources != NULL && advances != NULL)
            {
                NSUInteger glyphCount = OGTextShapeCharacters(cmap, characters + start, units, glyphs, NULL, sources);
                OGTextGlyphAdvances(cmap, font.pointSize, glyphs, glyphCount, advances);
                NSUInteger clusterIndex = 0;
                for (NSUInteger glyph = 0; glyph < glyphCount; glyph++)
                {
                    NSUInteger source = start + sources[glyph];
                    while (clusterIndex + 1 < count && source >= ends[clusterIndex])
                        clusterIndex++;
                    widths[clusterIndex] += advances[glyph];
                }
            }
            free(glyphs);
            free(sources);
            free(advances);
        }
    }

    NSUInteger clusterStart = start;
    for (NSUInteger index = 0; index < count; index++)
    {
        OGTextCluster *cluster = [[OGTextCluster alloc] init];
        cluster->_source = typesetter->_string;
        cluster->_attributes = attributes;
        cluster->_characters = NSMakeRange(clusterStart, ends[index] - clusterStart);
        cluster->_start = (CFIndex)clusterStart;
        cluster->_end = (CFIndex)ends[index];
        cluster->_flags = OGTextClusterFlags(characters + clusterStart, ends[index] - clusterStart);
        cluster->_width = owner == nil && (cluster->_flags & OGTextClusterNewline) != 0 ? 0.0f : widths[index];
        cluster->_ascent = ascent;
        cluster->_descent = descent;
        cluster->_leading = leading;
        [typesetter->_clusters addObject:cluster];
        memset(typesetter->_measured + clusterStart, 1, ends[index] - clusterStart);
        OSMemoryBarrier();
        typesetter->_clusterAtStart[clusterStart] = cluster;
        clusterStart = ends[index];
    }
}

static OGTextCluster *OGTextTypesetterClusterAtIndex(OGTextTypesetter *typesetter, NSUInteger index)
{
    OGTextCluster *cluster = typesetter->_clusterAtStart[index];
    if (cluster != nil)
        return cluster;
    OSSpinLockLock(&typesetter->_lock);
    cluster = typesetter->_clusterAtStart[index];
    if (cluster == nil && !typesetter->_measured[index])
    {
        OGTextTypesetterMeasureChunk(typesetter, index);
        cluster = typesetter->_clusterAtStart[index];
    }
    OSSpinLockUnlock(&typesetter->_lock);
    return cluster;
}

static OGTextCluster *OGTextTypesetterClusterInRange(OGTextTypesetter *typesetter, NSUInteger index, NSUInteger limit)
{
    OGTextCluster *cluster = OGTextTypesetterClusterAtIndex(typesetter, index);
    if (cluster != nil && (NSUInteger)cluster->_end <= limit)
        return cluster;
    NSUInteger end = OGTextClusterEndInCharacters(typesetter->_characters, index, limit);
    return OGTextClusterCreateMeasured(typesetter->_string, typesetter->_characters, NSMakeRange(index, end - index), OGTextAttributesAtIndex(typesetter->_attributedString, index));
}

static void OGTextApplyTabWidths(NSArray *clusters, CGFloat offset)
{
    CGFloat position = offset;
    for (OGTextCluster *cluster in clusters)
    {
        if ((cluster->_flags & OGTextClusterTab) != 0)
        {
            CGFloat tabWidth = OGTextMeasure(@"    ", cluster->_attributes, NULL, NULL, NULL);
            if (tabWidth <= 0.0f)
                tabWidth = MAX(1.0f, OGTextFontFromAttributes(cluster->_attributes).pointSize * 2.0f);
            CGFloat nextStop = (floorf(position / tabWidth) + 1.0f) * tabWidth;
            cluster->_width = MAX(1.0f, nextStop - position);
        }
        position += cluster->_width;
    }
}

@interface OGTextRun : NSObject
{
@public
    NSArray *_clusters;
    NSDictionary *_attributes;
    NSString *_string;
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
    NSArray *_clusters;
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

static OGTextRun *OGTextRunCreate(NSArray *visualClusters, BOOL rtl, CGFloat x, BOOL justified)
{
    OGTextRun *run = [[OGTextRun alloc] init];
    run->_clusters = visualClusters;
    run->_rtl = rtl;
    run->_x = x;
    run->_justified = justified;
    CFIndex minimum = LONG_MAX;
    CFIndex maximum = LONG_MIN;
    for (OGTextCluster *cluster in visualClusters)
    {
        run->_width += cluster->_width;
        run->_ascent = MAX(run->_ascent, cluster->_ascent);
        run->_descent = MAX(run->_descent, cluster->_descent);
        run->_leading = MAX(run->_leading, cluster->_leading);
        if (cluster->_start >= 0)
        {
            minimum = MIN(minimum, cluster->_start);
            maximum = MAX(maximum, cluster->_end);
        }
    }
    run->_range = minimum == LONG_MAX ? CFRangeMake(kCFNotFound, 0) : CFRangeMake(minimum, maximum - minimum);
    run->_attributes = visualClusters.count == 0 ? [NSDictionary dictionary] : ((OGTextCluster *)[visualClusters objectAtIndex:0])->_attributes;
    run->_string = OGTextClustersString(visualClusters, rtl);
    return run;
}

static CTLineRef OGTextLineCreate(NSArray *logicalClusters, CFRange sourceRange, BOOL justified)
{
    NSMutableArray *groups = [[NSMutableArray alloc] init];
    NSMutableArray *current = nil;
    NSDictionary *previousAttributes = nil;
    BOOL previousRTL = NO;
    CFIndex previousEnd = LONG_MIN;
    BOOL baseRTL = NO;
    BOOL baseResolved = NO;
    for (OGTextCluster *cluster in logicalClusters)
    {
        BOOL rtl = (cluster->_flags & OGTextClusterRTL) != 0;
        if (!baseResolved && (cluster->_flags & (OGTextClusterRTL | OGTextClusterStrongLTR)) != 0)
        {
            baseRTL = rtl;
            baseResolved = YES;
        }
        NSDictionary *attributes = cluster->_attributes;
        if (current == nil || rtl != previousRTL || (attributes != previousAttributes && ![attributes isEqual:previousAttributes]) || cluster->_start < 0 || previousEnd < 0 || cluster->_start != previousEnd)
        {
            current = [[NSMutableArray alloc] init];
            [groups addObject:current];
            previousAttributes = attributes;
            previousRTL = rtl;
        }
        [current addObject:cluster];
        previousEnd = cluster->_end;
    }

    OGTextLine *line = [[OGTextLine alloc] init];
    NSMutableArray *visualClusters = [[NSMutableArray alloc] initWithCapacity:logicalClusters.count];
    NSMutableArray *runs = [[NSMutableArray alloc] initWithCapacity:groups.count];
    CGFloat x = 0.0f;
    NSEnumerator *groupEnumerator = baseRTL ? [groups reverseObjectEnumerator] : [groups objectEnumerator];
    for (NSArray *group in groupEnumerator)
    {
        BOOL rtl = (((OGTextCluster *)[group objectAtIndex:0])->_flags & OGTextClusterRTL) != 0;
        NSArray *visualGroup = rtl ? [[group reverseObjectEnumerator] allObjects] : group;
        CGFloat runX = x;
        for (OGTextCluster *cluster in visualGroup)
        {
            cluster->_x = x;
            x += cluster->_width;
            line->_ascent = MAX(line->_ascent, cluster->_ascent);
            line->_descent = MAX(line->_descent, cluster->_descent);
            line->_leading = MAX(line->_leading, cluster->_leading);
            [visualClusters addObject:cluster];
        }
        [runs addObject:OGTextRunCreate(visualGroup, rtl, runX, justified)];
    }
    for (OGTextCluster *cluster in [logicalClusters reverseObjectEnumerator])
    {
        if ((cluster->_flags & OGTextClusterWhitespace) == 0)
            break;
        line->_trailing += cluster->_width;
    }
    line->_clusters = visualClusters;
    line->_runs = runs;
    line->_width = x;
    line->_range = CFRangeMake(MAX((CFIndex)0, sourceRange.location), MAX((CFIndex)0, sourceRange.length));
    return (CTLineRef)OGTextCreateObject(line);
}

static NSMutableArray *OGTextCopyClusters(OGTextLine *line)
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:line->_clusters.count];
    for (OGTextCluster *cluster in line->_clusters)
        [result addObject:OGTextClusterCopy(cluster)];
    return result;
}

static NSMutableArray *OGTextLogicalOrder(NSArray *clusters)
{
    NSMutableArray *ordered = [[NSMutableArray alloc] initWithCapacity:clusters.count];
    NSMutableArray *detached = [[NSMutableArray alloc] init];
    for (OGTextCluster *cluster in clusters)
    {
        if (cluster->_start < 0)
            [detached addObject:cluster];
        else
            [ordered addObject:cluster];
    }
    [ordered sortUsingComparator:^NSComparisonResult(OGTextCluster *left, OGTextCluster *right)
    {
        if (left->_start < right->_start)
            return NSOrderedAscending;
        if (left->_start > right->_start)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    [ordered addObjectsFromArray:detached];
    return ordered;
}

CTFontRef CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *matrix)
{
    NSString *fontName = (__bridge NSString *)name;
    UIFont *font = [UIFont fontWithName:fontName size:size];
    if (font == nil)
        return NULL;
    NSDictionary *object = [NSDictionary dictionaryWithObject:font forKey:OGTextFontKey];
    return (CTFontRef)OGTextCreateObject(object);
}

CFStringRef CTFontCopyPostScriptName(CTFontRef font)
{
    UIFont *uiFont = OGTextUIFont(font);
    return uiFont == nil ? NULL : (__bridge_retained CFStringRef)uiFont.fontName;
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
    uint32_t first = UINT32_MAX;
    for (uint32_t value = 0; value <= 0x10000; value++)
    {
        uint32_t glyph = value < 0x10000 ? OGFontCmapGlyph(bytes, length, value) : 0;
        bool present = glyph != 0 && glyph < glyphCount && !(value >= 0xd800 && value <= 0xdfff);
        if (present && first == UINT32_MAX)
            first = value;
        else if (!present && first != UINT32_MAX)
        {
            CFCharacterSetAddCharactersInRange(characters, CFRangeMake(first, value - first));
            first = UINT32_MAX;
        }
    }
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

    for (NSString *name in names)
    {
        if (!OGTextFontCmapCoversString(OGTextFontCmapForName(name), text))
            continue;
        CTFontRef candidate = CTFontCreateWithName((__bridge CFStringRef)name, CTFontGetSize(font), NULL);
        if (candidate == NULL)
            continue;
        [resolved setObject:name forKey:key cost:1];
        return candidate;
    }
    [resolved setObject:[NSNull null] forKey:key cost:1];
    return NULL;
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
    while (index < length)
    {
        OGTextCluster *cluster = OGTextTypesetterClusterInRange(typesetter, index, length);
        NSUInteger end = (NSUInteger)cluster->_end;
        if ((cluster->_flags & OGTextClusterNewline) != 0)
            return (CFIndex)(end - start);
        CGFloat clusterWidth = cluster->_width;
        if (used + clusterWidth > width && index > start)
            return (CFIndex)((wordBreak && lastBreak != NSNotFound ? lastBreak : index) - start);
        if (used + clusterWidth > width)
            return (CFIndex)(end - start);
        used += clusterWidth;
        if ((cluster->_flags & OGTextClusterWhitespace) != 0)
            lastBreak = end;
        index = end;
    }
    return (CFIndex)(length - start);
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
    NSMutableArray *clusters = [[NSMutableArray alloc] init];
    NSUInteger index = start;
    while (index < end)
    {
        OGTextCluster *cluster = OGTextTypesetterClusterInRange(typesetter, index, end);
        [clusters addObject:OGTextClusterCopy(cluster)];
        index = (NSUInteger)cluster->_end;
    }
    OGTextApplyTabWidths(clusters, offset);
    return OGTextLineCreate(clusters, CFRangeMake((CFIndex)start, (CFIndex)(end - start)), NO);
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
    NSArray *source = OGTextLogicalOrder(OGTextCopyClusters(line));
    NSArray *token = OGTextLogicalOrder(OGTextCopyClusters(truncationToken));
    CGFloat tokenWidth = 0.0f;
    for (OGTextCluster *cluster in token)
    {
        cluster->_start = -1;
        cluster->_end = -1;
        tokenWidth += cluster->_width;
    }
    if (tokenWidth > width)
        return NULL;
    CGFloat available = (CGFloat)width - tokenWidth;
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (truncationType == kCTLineTruncationStart)
    {
        CGFloat used = 0.0f;
        NSUInteger first = source.count;
        while (first > 0)
        {
            CGFloat clusterWidth = ((OGTextCluster *)[source objectAtIndex:first - 1])->_width;
            if (used + clusterWidth > available)
                break;
            used += clusterWidth;
            first--;
        }
        [result addObjectsFromArray:token];
        [result addObjectsFromArray:[source subarrayWithRange:NSMakeRange(first, source.count - first)]];
    }
    else if (truncationType == kCTLineTruncationMiddle)
    {
        CGFloat leftUsed = 0.0f;
        CGFloat rightUsed = 0.0f;
        NSUInteger left = 0;
        NSUInteger right = source.count;
        BOOL takeLeft = YES;
        while (left < right)
        {
            OGTextCluster *cluster = [source objectAtIndex:takeLeft ? left : right - 1];
            if (leftUsed + rightUsed + cluster->_width > available)
                break;
            if (takeLeft)
            {
                leftUsed += cluster->_width;
                left++;
            }
            else
            {
                rightUsed += cluster->_width;
                right--;
            }
            takeLeft = leftUsed > rightUsed;
        }
        [result addObjectsFromArray:[source subarrayWithRange:NSMakeRange(0, left)]];
        [result addObjectsFromArray:token];
        [result addObjectsFromArray:[source subarrayWithRange:NSMakeRange(right, source.count - right)]];
    }
    else
    {
        CGFloat used = 0.0f;
        for (OGTextCluster *cluster in source)
        {
            if (used + cluster->_width > available)
                break;
            [result addObject:cluster];
            used += cluster->_width;
        }
        [result addObjectsFromArray:token];
    }
    return OGTextLineCreate(result, line->_range, NO);
}

CTLineRef CTLineCreateJustifiedLine(CTLineRef lineRef, CGFloat justificationFactor, double justificationWidth)
{
    OGTextLine *line = OGTextLineObject(lineRef);
    if (line == nil || justificationFactor < 0.0f || justificationFactor > 1.0f)
        return NULL;
    if (justificationWidth <= line->_width)
        return (CTLineRef)CFRetain(lineRef);
    NSArray *clusters = OGTextLogicalOrder(OGTextCopyClusters(line));
    NSUInteger spaces = 0;
    for (OGTextCluster *cluster in clusters)
    {
        if ((cluster->_flags & (OGTextClusterWhitespace | OGTextClusterNewline)) == OGTextClusterWhitespace)
            spaces++;
    }
    if (spaces == 0)
        return (CTLineRef)CFRetain(lineRef);
    CGFloat extra = ((CGFloat)justificationWidth - line->_width) * justificationFactor / (CGFloat)spaces;
    for (OGTextCluster *cluster in clusters)
    {
        if ((cluster->_flags & (OGTextClusterWhitespace | OGTextClusterNewline)) == OGTextClusterWhitespace)
            cluster->_width += extra;
    }
    return OGTextLineCreate(clusters, line->_range, YES);
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
    for (OGTextCluster *cluster in line->_clusters)
    {
        if (cluster->_start < 0 || cluster->_end < 0)
            continue;
        if (charIndex >= cluster->_start && charIndex <= cluster->_end)
        {
            BOOL rtl = (cluster->_flags & OGTextClusterRTL) != 0;
            CGFloat x = cluster->_x;
            CGFloat width = cluster->_width;
            CGFloat primary = rtl ? (charIndex == cluster->_start ? x + width : x) : (charIndex == cluster->_end ? x + width : x);
            if (secondaryOffset != NULL)
                *secondaryOffset = rtl ? (charIndex == cluster->_start ? x : x + width) : primary;
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
    NSDictionary *attributes = run->_attributes;
    if (OGTextRunDelegateOwner(attributes) != nil)
        return;
    UIFont *font = OGTextFontFromAttributes(attributes);
    UIColor *color = OGTextColorFromAttributes(attributes);
    BOOL fromContext = [[[attributes objectForKey:(__bridge NSString *)kCTForegroundColorFromContextAttributeName] description] boolValue];
    NSArray *clusters = run->_clusters;
    CGContextSaveGState(context);
    if (!fromContext && color != nil)
    {
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextSetStrokeColorWithColor(context, color.CGColor);
    }
    if (run->_justified)
    {
        NSUInteger count = clusters.count;
        NSUInteger index = 0;
        while (index < count)
        {
            if ((((OGTextCluster *)[clusters objectAtIndex:index])->_flags & OGTextClusterWhitespace) != 0)
            {
                index++;
                continue;
            }
            NSUInteger end = index + 1;
            while (end < count && (((OGTextCluster *)[clusters objectAtIndex:end])->_flags & OGTextClusterWhitespace) == 0)
                end++;
            NSArray *word = [clusters subarrayWithRange:NSMakeRange(index, end - index)];
            CGFloat x = ((OGTextCluster *)[word objectAtIndex:0])->_x;
            OGTextDrawGlyphRun(context, OGTextClustersString(word, run->_rtl), font, CGPointMake(origin.x + x, origin.y), run->_rtl);
            index = end;
        }
    }
    else
        OGTextDrawGlyphRun(context, run->_string, font, CGPointMake(origin.x + run->_x, origin.y), run->_rtl);
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
    return (__bridge CFDictionaryRef)(run == nil ? nil : run->_attributes);
}

CFIndex CTRunGetGlyphCount(CTRunRef runRef)
{
    OGTextRun *run = OGTextRunObject(runRef);
    return run == nil ? 0 : (CFIndex)run->_clusters.count;
}

static NSRange OGTextValidatedGlyphRange(NSArray *clusters, CFRange range)
{
    NSUInteger location = range.location < 0 ? 0 : MIN((NSUInteger)range.location, clusters.count);
    NSUInteger length = range.length == 0 ? clusters.count - location : MIN((NSUInteger)MAX((CFIndex)0, range.length), clusters.count - location);
    return NSMakeRange(location, length);
}

double CTRunGetTypographicBounds(CTRunRef runRef, CFRange range, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    OGTextRun *run = OGTextRunObject(runRef);
    NSArray *clusters = run == nil ? [NSArray array] : run->_clusters;
    NSRange validRange = OGTextValidatedGlyphRange(clusters, range);
    CGFloat width = 0.0f;
    CGFloat maximumAscent = 0.0f;
    CGFloat maximumDescent = 0.0f;
    CGFloat maximumLeading = 0.0f;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
    {
        OGTextCluster *cluster = [clusters objectAtIndex:index];
        width += cluster->_width;
        maximumAscent = MAX(maximumAscent, cluster->_ascent);
        maximumDescent = MAX(maximumDescent, cluster->_descent);
        maximumLeading = MAX(maximumLeading, cluster->_leading);
    }
    if (ascent != NULL)
        *ascent = maximumAscent;
    if (descent != NULL)
        *descent = maximumDescent;
    if (leading != NULL)
        *leading = maximumLeading;
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
    NSRange validRange = OGTextValidatedGlyphRange(run->_clusters, range);
    NSUInteger output = 0;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
        buffer[output++] = ((OGTextCluster *)[run->_clusters objectAtIndex:index])->_start;
}

void CTRunGetPositions(CTRunRef runRef, CFRange range, CGPoint buffer[])
{
    OGTextRun *run = OGTextRunObject(runRef);
    if (run == nil || buffer == NULL)
        return;
    NSRange validRange = OGTextValidatedGlyphRange(run->_clusters, range);
    NSUInteger output = 0;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
        buffer[output++] = CGPointMake(((OGTextCluster *)[run->_clusters objectAtIndex:index])->_x, 0.0f);
}

void CTRunDraw(CTRunRef runRef, CGContextRef context, CFRange range)
{
    OGTextRun *run = OGTextRunObject(runRef);
    if (run == nil || context == NULL)
        return;
    NSRange validRange = OGTextValidatedGlyphRange(run->_clusters, range);
    if (validRange.length == 0)
        return;
    CGPoint origin = CGContextGetTextPosition(context);
    if (validRange.location == 0 && validRange.length == run->_clusters.count)
    {
        OGTextDrawRun(run, context, origin);
        return;
    }
    NSArray *subclusters = [run->_clusters subarrayWithRange:validRange];
    OGTextDrawRun(OGTextRunCreate(subclusters, run->_rtl, ((OGTextCluster *)[subclusters objectAtIndex:0])->_x, run->_justified), context, origin);
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
