#import "OGPlatformText.h"
#import <math.h>
#import "OGMemoryCache.h"
#import "OGFontCmap.h"
#import "OGUnicode.h"

#if !OG_PLATFORM_HAS_CORETEXT

const CFStringRef kCTFontAttributeName = CFSTR("CTFont");
const CFStringRef kCTForegroundColorAttributeName = CFSTR("CTForegroundColor");
const CFStringRef kCTForegroundColorFromContextAttributeName = CFSTR("CTForegroundColorFromContext");
const CFStringRef kCTUnderlineStyleAttributeName = CFSTR("CTUnderlineStyle");
const CFStringRef kCTRunDelegateAttributeName = CFSTR("CTRunDelegate");

static NSString *const OGTextFontKey = @"f";
static NSString *const OGTextAttributedStringKey = @"a";
static NSString *const OGTextClustersKey = @"c";
static NSString *const OGTextRunsKey = @"u";
static NSString *const OGTextAttributesKey = @"t";
static NSString *const OGTextStringKey = @"s";
static NSString *const OGTextStartKey = @"i";
static NSString *const OGTextEndKey = @"e";
static NSString *const OGTextXKey = @"x";
static NSString *const OGTextWidthKey = @"w";
static NSString *const OGTextAscentKey = @"n";
static NSString *const OGTextDescentKey = @"d";
static NSString *const OGTextLeadingKey = @"l";
static NSString *const OGTextRangeKey = @"r";
static NSString *const OGTextTrailingKey = @"q";
static NSString *const OGTextRTLKey = @"b";
static NSString *const OGTextDelegateOwnerKey = @"o";
static NSString *const OGTextJustifiedKey = @"j";

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

static uint32_t OGTextCodePoint(NSString *string, NSUInteger index, NSUInteger *length)
{
    unichar high = [string characterAtIndex:index];
    if (OGTextIsHighSurrogate(high) && index + 1 < [string length])
    {
        unichar low = [string characterAtIndex:index + 1];
        if (OGTextIsLowSurrogate(low))
        {
            if (length != NULL)
                *length = 2;
            return 0x10000 + (((uint32_t)high - 0xd800) << 10) + ((uint32_t)low - 0xdc00);
        }
    }
    if (length != NULL)
        *length = 1;
    return high;
}

static BOOL OGTextIsCombining(uint32_t value)
{
    return (value >= 0x0300 && value <= 0x036f) || (value >= 0x1ab0 && value <= 0x1aff) || (value >= 0x1dc0 && value <= 0x1dff) || (value >= 0x20d0 && value <= 0x20ff) || (value >= 0xfe20 && value <= 0xfe2f) || (value >= 0xfe00 && value <= 0xfe0f) || (value >= 0x1f3fb && value <= 0x1f3ff);
}

static NSUInteger OGTextClusterEnd(NSString *string, NSUInteger index, NSUInteger limit)
{
    NSUInteger length = 0;
    OGTextCodePoint(string, index, &length);
    NSUInteger cursor = MIN(limit, index + length);
    while (cursor < limit)
    {
        NSUInteger nextLength = 0;
        uint32_t value = OGTextCodePoint(string, cursor, &nextLength);
        if (OGTextIsCombining(value))
        {
            cursor = MIN(limit, cursor + nextLength);
            continue;
        }
        if (value == 0x200d && cursor + nextLength < limit)
        {
            cursor += nextLength;
            NSUInteger joinedLength = 0;
            OGTextCodePoint(string, cursor, &joinedLength);
            cursor = MIN(limit, cursor + joinedLength);
            continue;
        }
        break;
    }
    return cursor;
}

static BOOL OGTextCodePointIsRTL(uint32_t value)
{
    return (value >= 0x0590 && value <= 0x08ff) || (value >= 0xfb1d && value <= 0xfdff) || (value >= 0xfe70 && value <= 0xfeff) || (value >= 0x10800 && value <= 0x10fff);
}

static BOOL OGTextCodePointIsStrongLTR(uint32_t value)
{
    return (value >= 'A' && value <= 'Z') || (value >= 'a' && value <= 'z') || (value >= 0x00c0 && value <= 0x058f) || (value >= 0x0900 && value <= 0x1fff);
}

static BOOL OGTextClusterIsWhitespace(NSString *string)
{
    if ([string length] == 0)
        return NO;
    for (NSUInteger i = 0; i < [string length]; i++)
    {
        if (![[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[string characterAtIndex:i]])
            return NO;
    }
    return YES;
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
    return [string sizeWithFont:font].width;
}

static NSMutableDictionary *OGTextCluster(NSString *string, NSDictionary *attributes, CFIndex start, CFIndex end)
{
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    CGFloat width = OGTextMeasure(string, attributes, &ascent, &descent, &leading);
    uint32_t first = [string length] == 0 ? 0 : OGTextCodePoint(string, 0, NULL);
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:string, OGTextStringKey, attributes, OGTextAttributesKey, [NSNumber numberWithLong:start], OGTextStartKey, [NSNumber numberWithLong:end], OGTextEndKey, [NSNumber numberWithFloat:width], OGTextWidthKey, [NSNumber numberWithFloat:ascent], OGTextAscentKey, [NSNumber numberWithFloat:descent], OGTextDescentKey, [NSNumber numberWithFloat:leading], OGTextLeadingKey, [NSNumber numberWithBool:OGTextCodePointIsRTL(first)], OGTextRTLKey, nil];
}

static NSArray *OGTextLogicalClusters(id attributedString, CFRange range)
{
    NSString *string = [attributedString string];
    NSUInteger length = [string length];
    NSUInteger start = MIN((NSUInteger)MAX((CFIndex)0, range.location), length);
    NSUInteger requestedEnd = range.length == 0 ? length : MIN(length, start + (NSUInteger)MAX((CFIndex)0, range.length));
    NSMutableArray *clusters = [NSMutableArray array];
    NSUInteger index = start;
    while (index < requestedEnd)
    {
        NSUInteger end = OGTextClusterEnd(string, index, requestedEnd);
        NSDictionary *attributes = OGTextAttributesAtIndex(attributedString, index);
        NSString *clusterString = [string substringWithRange:NSMakeRange(index, end - index)];
        [clusters addObject:OGTextCluster(clusterString, attributes, (CFIndex)index, (CFIndex)end)];
        index = end;
    }
    return clusters;
}

static void OGTextApplyTabWidths(NSArray *clusters, CGFloat offset)
{
    CGFloat position = offset;
    for (NSMutableDictionary *cluster in clusters)
    {
        NSString *string = [cluster objectForKey:OGTextStringKey];
        CGFloat width = [[cluster objectForKey:OGTextWidthKey] floatValue];
        if ([string isEqualToString:@"\t"])
        {
            NSDictionary *attributes = [cluster objectForKey:OGTextAttributesKey];
            CGFloat tabWidth = OGTextMeasure(@"    ", attributes, NULL, NULL, NULL);
            if (tabWidth <= 0.0f)
                tabWidth = MAX(1.0f, OGTextFontFromAttributes(attributes).pointSize * 2.0f);
            CGFloat nextStop = (floorf(position / tabWidth) + 1.0f) * tabWidth;
            width = MAX(1.0f, nextStop - position);
            [cluster setObject:[NSNumber numberWithFloat:width] forKey:OGTextWidthKey];
        }
        position += width;
    }
}

static BOOL OGTextBaseDirectionIsRTL(NSArray *clusters)
{
    for (NSDictionary *cluster in clusters)
    {
        NSString *string = [cluster objectForKey:OGTextStringKey];
        if ([string length] == 0)
            continue;
        uint32_t value = OGTextCodePoint(string, 0, NULL);
        if (OGTextCodePointIsRTL(value))
            return YES;
        if (OGTextCodePointIsStrongLTR(value))
            return NO;
    }
    return NO;
}

static NSDictionary *OGTextRunFromClusters(NSArray *clusters, BOOL rtl, CGFloat x, BOOL justified)
{
    CGFloat width = 0.0f;
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    CFIndex minimum = LONG_MAX;
    CFIndex maximum = 0;
    NSMutableString *string = [NSMutableString string];
    NSArray *logicalClusters = rtl ? [[clusters reverseObjectEnumerator] allObjects] : clusters;
    for (NSDictionary *cluster in logicalClusters)
        [string appendString:[cluster objectForKey:OGTextStringKey]];
    for (NSDictionary *cluster in clusters)
    {
        width += [[cluster objectForKey:OGTextWidthKey] floatValue];
        ascent = MAX(ascent, [[cluster objectForKey:OGTextAscentKey] floatValue]);
        descent = MAX(descent, [[cluster objectForKey:OGTextDescentKey] floatValue]);
        leading = MAX(leading, [[cluster objectForKey:OGTextLeadingKey] floatValue]);
        minimum = MIN(minimum, [[cluster objectForKey:OGTextStartKey] longValue]);
        maximum = MAX(maximum, [[cluster objectForKey:OGTextEndKey] longValue]);
    }
    NSDictionary *attributes = [clusters count] == 0 ? [NSDictionary dictionary] : [[clusters objectAtIndex:0] objectForKey:OGTextAttributesKey];
    return [NSDictionary dictionaryWithObjectsAndKeys:clusters, OGTextClustersKey, attributes, OGTextAttributesKey, string, OGTextStringKey, [NSNumber numberWithFloat:x], OGTextXKey, [NSNumber numberWithFloat:width], OGTextWidthKey, [NSNumber numberWithFloat:ascent], OGTextAscentKey, [NSNumber numberWithFloat:descent], OGTextDescentKey, [NSNumber numberWithFloat:leading], OGTextLeadingKey, [NSValue valueWithRange:NSMakeRange(minimum == LONG_MAX ? 0 : (NSUInteger)minimum, maximum >= minimum ? (NSUInteger)(maximum - minimum) : 0)], OGTextRangeKey, [NSNumber numberWithBool:rtl], OGTextRTLKey, [NSNumber numberWithBool:justified], OGTextJustifiedKey, nil];
}

static CFTypeRef OGTextLineFromClusters(NSArray *logicalClusters, CFRange sourceRange, BOOL justified)
{
    NSMutableArray *directionalGroups = [NSMutableArray array];
    NSMutableArray *current = nil;
    NSDictionary *previousAttributes = nil;
    BOOL previousRTL = NO;
    CFIndex previousEnd = LONG_MIN;
    for (NSMutableDictionary *cluster in logicalClusters)
    {
        NSDictionary *attributes = [cluster objectForKey:OGTextAttributesKey];
        BOOL rtl = [[cluster objectForKey:OGTextRTLKey] boolValue];
        CFIndex start = [[cluster objectForKey:OGTextStartKey] longValue];
        CFIndex end = [[cluster objectForKey:OGTextEndKey] longValue];
        if (current == nil || rtl != previousRTL || ![attributes isEqual:previousAttributes] || start < 0 || previousEnd < 0 || start != previousEnd)
        {
            current = [NSMutableArray array];
            [directionalGroups addObject:current];
            previousAttributes = attributes;
            previousRTL = rtl;
        }
        [current addObject:cluster];
        previousEnd = end;
    }
    if (OGTextBaseDirectionIsRTL(logicalClusters))
        directionalGroups = [NSMutableArray arrayWithArray:[[directionalGroups reverseObjectEnumerator] allObjects]];
    NSMutableArray *visualClusters = [NSMutableArray array];
    NSMutableArray *runs = [NSMutableArray array];
    CGFloat x = 0.0f;
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    for (NSArray *group in directionalGroups)
    {
        BOOL rtl = [[[group objectAtIndex:0] objectForKey:OGTextRTLKey] boolValue];
        NSArray *visualGroup = rtl ? [[group reverseObjectEnumerator] allObjects] : group;
        for (NSMutableDictionary *cluster in visualGroup)
        {
            [cluster setObject:[NSNumber numberWithFloat:x] forKey:OGTextXKey];
            x += [[cluster objectForKey:OGTextWidthKey] floatValue];
            ascent = MAX(ascent, [[cluster objectForKey:OGTextAscentKey] floatValue]);
            descent = MAX(descent, [[cluster objectForKey:OGTextDescentKey] floatValue]);
            leading = MAX(leading, [[cluster objectForKey:OGTextLeadingKey] floatValue]);
            [visualClusters addObject:cluster];
        }
        NSDictionary *run = OGTextRunFromClusters(visualGroup, rtl, [[[visualGroup objectAtIndex:0] objectForKey:OGTextXKey] floatValue], justified);
        [runs addObject:run];
    }
    CGFloat trailing = 0.0f;
    for (NSDictionary *cluster in [logicalClusters reverseObjectEnumerator])
    {
        if (!OGTextClusterIsWhitespace([cluster objectForKey:OGTextStringKey]))
            break;
        trailing += [[cluster objectForKey:OGTextWidthKey] floatValue];
    }
    NSDictionary *line = [NSDictionary dictionaryWithObjectsAndKeys:visualClusters, OGTextClustersKey, runs, OGTextRunsKey, [NSNumber numberWithFloat:x], OGTextWidthKey, [NSNumber numberWithFloat:ascent], OGTextAscentKey, [NSNumber numberWithFloat:descent], OGTextDescentKey, [NSNumber numberWithFloat:leading], OGTextLeadingKey, [NSValue valueWithRange:NSMakeRange((NSUInteger)MAX((CFIndex)0, sourceRange.location), (NSUInteger)MAX((CFIndex)0, sourceRange.length))], OGTextRangeKey, [NSNumber numberWithFloat:trailing], OGTextTrailingKey, nil];
    return OGTextCreateObject(line);
}

static NSArray *OGTextCopyClusters(CFTypeRef line)
{
    NSArray *clusters = [OGTextObject(line) objectForKey:OGTextClustersKey];
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[clusters count]];
    for (NSDictionary *cluster in clusters)
        [result addObject:[NSMutableDictionary dictionaryWithDictionary:cluster]];
    return result;
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
    CGFontRef cgFont = CGFontCreateWithFontName((__bridge CFStringRef)uiFont.fontName);
    if (cgFont == NULL)
        return NULL;
    size_t glyphCount = CGFontGetNumberOfGlyphs(cgFont);
    CFDataRef cmap = CGFontCopyTableForTag(cgFont, 0x636d6170u);
    CGFontRelease(cgFont);
    if (cmap == NULL)
        return NULL;
    const uint8_t *bytes = CFDataGetBytePtr(cmap);
    size_t length = (size_t)CFDataGetLength(cmap);
    CFMutableCharacterSetRef characters = CFCharacterSetCreateMutable(kCFAllocatorDefault);
    if (characters == NULL)
    {
        CFRelease(cmap);
        return NULL;
    }
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
    CFRelease(cmap);
    [cache setObject:(__bridge id)characters forKey:uiFont.fontName cost:128 * 1024];
    return characters;
}

static BOOL OGTextFontCoversString(CTFontRef font, NSString *text)
{
    CFCharacterSetRef characters = CTFontCopyCharacterSet(font);
    if (characters == NULL)
        return NO;
    BOOL covered = YES;
    for (NSUInteger i = 0; i < text.length; i++)
    {
        uint32_t value = [text characterAtIndex:i];
        if (OGUnicodeIsHighSurrogate((uint16_t)value) && i + 1 < text.length && OGUnicodeIsLowSurrogate([text characterAtIndex:i + 1]))
            value = OGUnicodeScalarForSurrogatePair((uint16_t)value, [text characterAtIndex:++i]);
        if (!CFCharacterSetIsLongCharacterMember(characters, value))
        {
            covered = NO;
            break;
        }
    }
    CFRelease(characters);
    return covered;
}

CTFontRef CTFontCreateForString(CTFontRef font, CFStringRef string, CFRange range)
{
    NSString *text = (__bridge NSString *)string;
    if (font == NULL || range.location < 0 || range.length < 0 || (NSUInteger)range.location > text.length || (NSUInteger)range.length > text.length - (NSUInteger)range.location)
        return NULL;
    text = [text substringWithRange:NSMakeRange((NSUInteger)range.location, (NSUInteger)range.length)];
    if (OGTextFontCoversString(font, text))
        return (CTFontRef)CFRetain(font);
    static NSArray *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSMutableArray *available = [[NSMutableArray alloc] init];
        for (NSString *family in [UIFont familyNames])
            [available addObjectsFromArray:[UIFont fontNamesForFamilyName:family]];
        names = [available copy];
    });
    for (NSString *name in names)
    {
        CTFontRef candidate = CTFontCreateWithName((__bridge CFStringRef)name, CTFontGetSize(font), NULL);
        if (candidate == NULL)
            continue;
        if (OGTextFontCoversString(candidate, text))
            return candidate;
        CFRelease(candidate);
    }
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

CTTypesetterRef CTTypesetterCreateWithAttributedString(CFAttributedStringRef string)
{
    id attributedString = (__bridge id)string;
    if (attributedString == nil)
        return NULL;
    return (CTTypesetterRef)OGTextCreateObject([NSDictionary dictionaryWithObject:attributedString forKey:OGTextAttributedStringKey]);
}

static CFIndex OGTextSuggestBreak(CTTypesetterRef typesetter, CFIndex startIndex, double width, BOOL wordBreak)
{
    id attributedString = [OGTextObject(typesetter) objectForKey:OGTextAttributedStringKey];
    NSString *string = [attributedString string];
    NSUInteger length = [string length];
    NSUInteger start = MIN((NSUInteger)MAX((CFIndex)0, startIndex), length);
    if (start >= length)
        return 0;
    CGFloat used = 0.0f;
    NSUInteger index = start;
    NSUInteger lastBreak = NSNotFound;
    while (index < length)
    {
        NSUInteger end = OGTextClusterEnd(string, index, length);
        NSString *clusterString = [string substringWithRange:NSMakeRange(index, end - index)];
        NSDictionary *attributes = OGTextAttributesAtIndex(attributedString, index);
        CGFloat clusterWidth = OGTextMeasure(clusterString, attributes, NULL, NULL, NULL);
        BOOL newline = [clusterString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound;
        if (newline)
            return (CFIndex)(end - start);
        if (used + clusterWidth > width && index > start)
            return (CFIndex)((wordBreak && lastBreak != NSNotFound ? lastBreak : index) - start);
        if (used + clusterWidth > width)
            return (CFIndex)(end - start);
        used += clusterWidth;
        if (OGTextClusterIsWhitespace(clusterString))
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

static CTLineRef OGTextCreateTypesetterLine(CTTypesetterRef typesetter, CFRange stringRange, CGFloat offset)
{
    id attributedString = [OGTextObject(typesetter) objectForKey:OGTextAttributedStringKey];
    if (attributedString == nil)
        return NULL;
    NSUInteger length = [attributedString length];
    CFRange range = stringRange;
    if (range.location < 0 || (NSUInteger)range.location > length)
        return NULL;
    if (range.length == 0)
        range.length = (CFIndex)length - range.location;
    range.length = MIN(range.length, (CFIndex)length - range.location);
    NSArray *clusters = OGTextLogicalClusters(attributedString, range);
    OGTextApplyTabWidths(clusters, offset);
    return (CTLineRef)OGTextLineFromClusters(clusters, range, NO);
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

static NSArray *OGTextLogicalOrder(NSArray *clusters)
{
    NSMutableArray *result = [NSMutableArray arrayWithArray:clusters];
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        CFIndex leftIndex = [[left objectForKey:OGTextStartKey] longValue];
        CFIndex rightIndex = [[right objectForKey:OGTextStartKey] longValue];
        if (leftIndex < 0 && rightIndex >= 0)
            return NSOrderedDescending;
        if (rightIndex < 0 && leftIndex >= 0)
            return NSOrderedAscending;
        if (leftIndex < rightIndex)
            return NSOrderedAscending;
        if (leftIndex > rightIndex)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return result;
}

CTLineRef CTLineCreateTruncatedLine(CTLineRef line, double width, CTLineTruncationType truncationType, CTLineRef truncationToken)
{
    if (line == NULL || truncationToken == NULL || width < 0.0)
        return NULL;
    if (CTLineGetTypographicBounds(line, NULL, NULL, NULL) <= width)
        return (CTLineRef)CFRetain(line);
    NSArray *source = OGTextLogicalOrder(OGTextCopyClusters(line));
    NSArray *tokenSource = OGTextLogicalOrder(OGTextCopyClusters(truncationToken));
    NSMutableArray *token = [NSMutableArray arrayWithCapacity:[tokenSource count]];
    CGFloat tokenWidth = 0.0f;
    for (NSMutableDictionary *cluster in tokenSource)
    {
        [cluster setObject:[NSNumber numberWithLong:-1] forKey:OGTextStartKey];
        [cluster setObject:[NSNumber numberWithLong:-1] forKey:OGTextEndKey];
        tokenWidth += [[cluster objectForKey:OGTextWidthKey] floatValue];
        [token addObject:cluster];
    }
    if (tokenWidth > width)
        return NULL;
    CGFloat available = (CGFloat)width - tokenWidth;
    NSMutableArray *result = [NSMutableArray array];
    if (truncationType == kCTLineTruncationStart)
    {
        CGFloat used = 0.0f;
        NSMutableArray *suffix = [NSMutableArray array];
        for (NSDictionary *cluster in [source reverseObjectEnumerator])
        {
            CGFloat clusterWidth = [[cluster objectForKey:OGTextWidthKey] floatValue];
            if (used + clusterWidth > available)
                break;
            [suffix insertObject:cluster atIndex:0];
            used += clusterWidth;
        }
        [result addObjectsFromArray:token];
        [result addObjectsFromArray:suffix];
    }
    else if (truncationType == kCTLineTruncationMiddle)
    {
        CGFloat leftUsed = 0.0f;
        CGFloat rightUsed = 0.0f;
        NSUInteger left = 0;
        NSUInteger right = [source count];
        BOOL takeLeft = YES;
        while (left < right)
        {
            NSDictionary *cluster = takeLeft ? [source objectAtIndex:left] : [source objectAtIndex:right - 1];
            CGFloat clusterWidth = [[cluster objectForKey:OGTextWidthKey] floatValue];
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
        if (left != 0)
            [result addObjectsFromArray:[source subarrayWithRange:NSMakeRange(0, left)]];
        [result addObjectsFromArray:token];
        if (right < [source count])
            [result addObjectsFromArray:[source subarrayWithRange:NSMakeRange(right, [source count] - right)]];
    }
    else
    {
        CGFloat used = 0.0f;
        for (NSDictionary *cluster in source)
        {
            CGFloat clusterWidth = [[cluster objectForKey:OGTextWidthKey] floatValue];
            if (used + clusterWidth > available)
                break;
            [result addObject:cluster];
            used += clusterWidth;
        }
        [result addObjectsFromArray:token];
    }
    NSRange range = [[OGTextObject(line) objectForKey:OGTextRangeKey] rangeValue];
    return (CTLineRef)OGTextLineFromClusters(result, CFRangeMake((CFIndex)range.location, (CFIndex)range.length), NO);
}

CTLineRef CTLineCreateJustifiedLine(CTLineRef line, CGFloat justificationFactor, double justificationWidth)
{
    if (line == NULL || justificationFactor < 0.0f || justificationFactor > 1.0f)
        return NULL;
    CGFloat currentWidth = (CGFloat)CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    if (justificationWidth <= currentWidth)
        return (CTLineRef)CFRetain(line);
    NSMutableArray *clusters = [NSMutableArray arrayWithArray:OGTextLogicalOrder(OGTextCopyClusters(line))];
    NSMutableArray *spaces = [NSMutableArray array];
    for (NSMutableDictionary *cluster in clusters)
    {
        if (OGTextClusterIsWhitespace([cluster objectForKey:OGTextStringKey]) && [[cluster objectForKey:OGTextStringKey] rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location == NSNotFound)
            [spaces addObject:cluster];
    }
    if ([spaces count] == 0)
        return (CTLineRef)CFRetain(line);
    CGFloat extra = ((CGFloat)justificationWidth - currentWidth) * justificationFactor / [spaces count];
    for (NSMutableDictionary *cluster in spaces)
        [cluster setObject:[NSNumber numberWithFloat:[[cluster objectForKey:OGTextWidthKey] floatValue] + extra] forKey:OGTextWidthKey];
    NSRange range = [[OGTextObject(line) objectForKey:OGTextRangeKey] rangeValue];
    return (CTLineRef)OGTextLineFromClusters(clusters, CFRangeMake((CFIndex)range.location, (CFIndex)range.length), YES);
}

double CTLineGetTypographicBounds(CTLineRef line, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    NSDictionary *object = OGTextObject(line);
    if (ascent != NULL)
        *ascent = [[object objectForKey:OGTextAscentKey] floatValue];
    if (descent != NULL)
        *descent = [[object objectForKey:OGTextDescentKey] floatValue];
    if (leading != NULL)
        *leading = [[object objectForKey:OGTextLeadingKey] floatValue];
    return [[object objectForKey:OGTextWidthKey] doubleValue];
}

double CTLineGetTrailingWhitespaceWidth(CTLineRef line)
{
    return [[OGTextObject(line) objectForKey:OGTextTrailingKey] doubleValue];
}

CFRange CTLineGetStringRange(CTLineRef line)
{
    NSRange range = [[OGTextObject(line) objectForKey:OGTextRangeKey] rangeValue];
    return CFRangeMake((CFIndex)range.location, (CFIndex)range.length);
}

CFArrayRef CTLineGetGlyphRuns(CTLineRef line)
{
    return (__bridge CFArrayRef)[OGTextObject(line) objectForKey:OGTextRunsKey];
}

CGFloat CTLineGetOffsetForStringIndex(CTLineRef line, CFIndex charIndex, CGFloat *secondaryOffset)
{
    NSArray *clusters = [OGTextObject(line) objectForKey:OGTextClustersKey];
    CGFloat lineWidth = [[OGTextObject(line) objectForKey:OGTextWidthKey] floatValue];
    for (NSDictionary *cluster in clusters)
    {
        CFIndex start = [[cluster objectForKey:OGTextStartKey] longValue];
        CFIndex end = [[cluster objectForKey:OGTextEndKey] longValue];
        if (start < 0 || end < 0)
            continue;
        CGFloat x = [[cluster objectForKey:OGTextXKey] floatValue];
        CGFloat width = [[cluster objectForKey:OGTextWidthKey] floatValue];
        BOOL rtl = [[cluster objectForKey:OGTextRTLKey] boolValue];
        if (charIndex >= start && charIndex <= end)
        {
            CGFloat primary = rtl ? (charIndex == start ? x + width : x) : (charIndex == end ? x + width : x);
            if (secondaryOffset != NULL)
                *secondaryOffset = rtl ? (charIndex == start ? x : x + width) : primary;
            return primary;
        }
    }
    CFRange range = CTLineGetStringRange(line);
    if (secondaryOffset != NULL)
        *secondaryOffset = charIndex <= range.location ? 0.0f : lineWidth;
    return charIndex <= range.location ? 0.0f : lineWidth;
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

static void OGTextDrawRun(NSDictionary *run, CGContextRef context, CGPoint origin)
{
    NSDictionary *attributes = [run objectForKey:OGTextAttributesKey];
    if (OGTextRunDelegateOwner(attributes) != nil)
        return;
    BOOL justified = [[[run objectForKey:OGTextJustifiedKey] description] boolValue];
    UIFont *font = OGTextFontFromAttributes(attributes);
    UIColor *color = OGTextColorFromAttributes(attributes);
    BOOL fromContext = [[[attributes objectForKey:(__bridge NSString *)kCTForegroundColorFromContextAttributeName] description] boolValue];
    NSArray *clusters = [run objectForKey:OGTextClustersKey];
    CGContextSaveGState(context);
    UIGraphicsPushContext(context);
    if (!fromContext && color != nil)
        [color set];
    if (justified)
    {
        BOOL rtl = [[[run objectForKey:OGTextRTLKey] description] boolValue];
        NSUInteger index = 0;
        while (index < [clusters count])
        {
            NSDictionary *cluster = [clusters objectAtIndex:index];
            NSString *string = [cluster objectForKey:OGTextStringKey];
            if (OGTextClusterIsWhitespace(string))
            {
                index++;
                continue;
            }
            NSUInteger end = index + 1;
            while (end < [clusters count] && !OGTextClusterIsWhitespace([[clusters objectAtIndex:end] objectForKey:OGTextStringKey]))
                end++;
            NSArray *wordClusters = [clusters subarrayWithRange:NSMakeRange(index, end - index)];
            NSArray *logicalWordClusters = rtl ? [[wordClusters reverseObjectEnumerator] allObjects] : wordClusters;
            NSMutableString *word = [NSMutableString string];
            for (NSDictionary *wordCluster in logicalWordClusters)
                [word appendString:[wordCluster objectForKey:OGTextStringKey]];
            CGFloat x = [[[wordClusters objectAtIndex:0] objectForKey:OGTextXKey] floatValue];
            [word drawAtPoint:CGPointMake(origin.x + x, origin.y - font.ascender) withFont:font];
            index = end;
        }
    }
    else
    {
        CGFloat x = [[run objectForKey:OGTextXKey] floatValue];
        [[run objectForKey:OGTextStringKey] drawAtPoint:CGPointMake(origin.x + x, origin.y - font.ascender) withFont:font];
    }
    NSNumber *underline = [attributes objectForKey:(__bridge NSString *)kCTUnderlineStyleAttributeName];
    if (underline == nil)
        underline = [attributes objectForKey:@"NSUnderline"];
    if ([underline integerValue] != 0)
    {
        CGFloat x = [[run objectForKey:OGTextXKey] floatValue];
        CGFloat width = [[run objectForKey:OGTextWidthKey] floatValue];
        CGContextSetLineWidth(context, MAX(1.0f, font.pointSize / 14.0f));
        CGContextMoveToPoint(context, origin.x + x, origin.y + 1.0f);
        CGContextAddLineToPoint(context, origin.x + x + width, origin.y + 1.0f);
        CGContextStrokePath(context);
    }
    UIGraphicsPopContext();
    CGContextRestoreGState(context);
}

void CTLineDraw(CTLineRef line, CGContextRef context)
{
    if (line == NULL || context == NULL)
        return;
    CGPoint origin = CGContextGetTextPosition(context);
    for (NSDictionary *run in [OGTextObject(line) objectForKey:OGTextRunsKey])
        OGTextDrawRun(run, context, origin);
}

CFDictionaryRef CTRunGetAttributes(CTRunRef run)
{
    return (__bridge CFDictionaryRef)[OGTextObject(run) objectForKey:OGTextAttributesKey];
}

CFIndex CTRunGetGlyphCount(CTRunRef run)
{
    return (CFIndex)[[OGTextObject(run) objectForKey:OGTextClustersKey] count];
}

static NSRange OGTextValidatedGlyphRange(NSArray *clusters, CFRange range)
{
    NSUInteger location = range.location < 0 ? 0 : MIN((NSUInteger)range.location, [clusters count]);
    NSUInteger length = range.length == 0 ? [clusters count] - location : MIN((NSUInteger)MAX((CFIndex)0, range.length), [clusters count] - location);
    return NSMakeRange(location, length);
}

double CTRunGetTypographicBounds(CTRunRef run, CFRange range, CGFloat *ascent, CGFloat *descent, CGFloat *leading)
{
    NSArray *clusters = [OGTextObject(run) objectForKey:OGTextClustersKey];
    NSRange validRange = OGTextValidatedGlyphRange(clusters, range);
    CGFloat width = 0.0f;
    CGFloat maximumAscent = 0.0f;
    CGFloat maximumDescent = 0.0f;
    CGFloat maximumLeading = 0.0f;
    for (NSDictionary *cluster in [clusters subarrayWithRange:validRange])
    {
        width += [[cluster objectForKey:OGTextWidthKey] floatValue];
        maximumAscent = MAX(maximumAscent, [[cluster objectForKey:OGTextAscentKey] floatValue]);
        maximumDescent = MAX(maximumDescent, [[cluster objectForKey:OGTextDescentKey] floatValue]);
        maximumLeading = MAX(maximumLeading, [[cluster objectForKey:OGTextLeadingKey] floatValue]);
    }
    if (ascent != NULL)
        *ascent = maximumAscent;
    if (descent != NULL)
        *descent = maximumDescent;
    if (leading != NULL)
        *leading = maximumLeading;
    return width;
}

CFRange CTRunGetStringRange(CTRunRef run)
{
    NSRange range = [[OGTextObject(run) objectForKey:OGTextRangeKey] rangeValue];
    return CFRangeMake((CFIndex)range.location, (CFIndex)range.length);
}

void CTRunGetStringIndices(CTRunRef run, CFRange range, CFIndex buffer[])
{
    if (buffer == NULL)
        return;
    NSArray *clusters = [OGTextObject(run) objectForKey:OGTextClustersKey];
    NSRange validRange = OGTextValidatedGlyphRange(clusters, range);
    NSUInteger output = 0;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
        buffer[output++] = [[[clusters objectAtIndex:index] objectForKey:OGTextStartKey] longValue];
}

void CTRunGetPositions(CTRunRef run, CFRange range, CGPoint buffer[])
{
    if (buffer == NULL)
        return;
    NSArray *clusters = [OGTextObject(run) objectForKey:OGTextClustersKey];
    NSRange validRange = OGTextValidatedGlyphRange(clusters, range);
    NSUInteger output = 0;
    for (NSUInteger index = validRange.location; index < NSMaxRange(validRange); index++)
        buffer[output++] = CGPointMake([[[clusters objectAtIndex:index] objectForKey:OGTextXKey] floatValue], 0.0f);
}

void CTRunDraw(CTRunRef run, CGContextRef context, CFRange range)
{
    if (run == NULL || context == NULL)
        return;
    NSDictionary *object = OGTextObject(run);
    NSArray *clusters = [object objectForKey:OGTextClustersKey];
    NSRange validRange = OGTextValidatedGlyphRange(clusters, range);
    if (validRange.length == 0)
        return;
    CGPoint origin = CGContextGetTextPosition(context);
    if (validRange.location == 0 && validRange.length == [clusters count])
    {
        OGTextDrawRun(object, context, origin);
        return;
    }
    NSArray *subclusters = [clusters subarrayWithRange:validRange];
    BOOL rtl = [[[object objectForKey:OGTextRTLKey] description] boolValue];
    BOOL justified = [[[object objectForKey:OGTextJustifiedKey] description] boolValue];
    CGFloat x = [[[subclusters objectAtIndex:0] objectForKey:OGTextXKey] floatValue];
    OGTextDrawRun(OGTextRunFromClusters(subclusters, rtl, x, justified), context, origin);
}

CTRunStatus CTRunGetStatus(CTRunRef run)
{
    return [[[OGTextObject(run) objectForKey:OGTextRTLKey] description] boolValue] ? kCTRunStatusRightToLeft : kCTRunStatusNoStatus;
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
