#import "OGPlatformText.h"
#import "OGPlatformVersion.h"
#import "OGUnicode.h"
#include <pthread.h>
#import "OGPlatformDispatch.h"

#if defined(ONEGRAM_DIAGNOSTICS)
void OGPlatformTextLogSlowLayout(const char *site, CFAttributedStringRef string, CFTimeInterval duration)
{
    if (duration < 0.1 || string == NULL)
        return;
    CFStringRef text = CFAttributedStringGetString(string);
    CFIndex length = text != NULL ? CFStringGetLength(text) : 0;
    NSMutableString *codes = [[NSMutableString alloc] init];
    for (CFIndex index = 0; index < length && codes.length < 400; index++)
    {
        UniChar character = CFStringGetCharacterAtIndex(text, index);
        if (character >= 0x80)
            [codes appendFormat:@"%04X ", (unsigned int)character];
    }
    OGPlatformDiagnosticLog(@"TEXTSLOW %s %.0fms length=%ld %@", site, duration * 1000.0, (long)length, codes);
}
#endif

#if OG_PLATFORM_HAS_CORETEXT

typedef struct
{
    uint32_t first;
    uint32_t last;
    const char *const *fonts;
} OGTextFallbackBlock;

static const char *const OGTextFallbackHebrewFonts[] = {"ArialHebrew", "ArialMT", NULL};
static const char *const OGTextFallbackArabicFonts[] = {"GeezaPro", NULL};
static const char *const OGTextFallbackThaiFonts[] = {"Thonburi", NULL};
static const char *const OGTextFallbackDevanagariFonts[] = {"DevanagariSangamMN", NULL};
static const char *const OGTextFallbackBengaliFonts[] = {"BanglaSangamMN", NULL};
static const char *const OGTextFallbackGurmukhiFonts[] = {"GurmukhiMN", NULL};
static const char *const OGTextFallbackGujaratiFonts[] = {"GujaratiSangamMN", NULL};
static const char *const OGTextFallbackOriyaFonts[] = {"OriyaSangamMN", NULL};
static const char *const OGTextFallbackTamilFonts[] = {"TamilSangamMN", NULL};
static const char *const OGTextFallbackTeluguFonts[] = {"TeluguSangamMN", NULL};
static const char *const OGTextFallbackKannadaFonts[] = {"KannadaSangamMN", NULL};
static const char *const OGTextFallbackMalayalamFonts[] = {"MalayalamSangamMN", NULL};
static const char *const OGTextFallbackSinhalaFonts[] = {"SinhalaSangamMN", NULL};
static const char *const OGTextFallbackHangulFonts[] = {"AppleSDGothicNeo-Medium", "AppleGothic", NULL};
static const char *const OGTextFallbackKanaFonts[] = {"HiraKakuProN-W3", "STHeitiSC-Light", NULL};
static const char *const OGTextFallbackHanFonts[] = {"STHeitiSC-Light", "STHeitiTC-Light", "HiraKakuProN-W3", NULL};
static const char *const OGTextFallbackSyllabicsFonts[] = {"EuphemiaUCAS", NULL};
static const char *const OGTextFallbackSymbolFonts[] = {"AppleColorEmoji", "ZapfDingbatsITC", "ArialMT", "Helvetica", "TimesNewRomanPSMT", NULL};
static const char *const OGTextFallbackEmojiFonts[] = {"AppleColorEmoji", NULL};
static const char *const OGTextFallbackGeneralFonts[] = {"Helvetica", "ArialMT", "TimesNewRomanPSMT", "Georgia", "CourierNewPSMT", "Verdana", "AppleColorEmoji", NULL};

static const OGTextFallbackBlock OGTextFallbackBlocks[] = {
    {0x0590, 0x05FF, OGTextFallbackHebrewFonts},
    {0x0600, 0x06FF, OGTextFallbackArabicFonts},
    {0x0750, 0x077F, OGTextFallbackArabicFonts},
    {0x0900, 0x097F, OGTextFallbackDevanagariFonts},
    {0x0980, 0x09FF, OGTextFallbackBengaliFonts},
    {0x0A00, 0x0A7F, OGTextFallbackGurmukhiFonts},
    {0x0A80, 0x0AFF, OGTextFallbackGujaratiFonts},
    {0x0B00, 0x0B7F, OGTextFallbackOriyaFonts},
    {0x0B80, 0x0BFF, OGTextFallbackTamilFonts},
    {0x0C00, 0x0C7F, OGTextFallbackTeluguFonts},
    {0x0C80, 0x0CFF, OGTextFallbackKannadaFonts},
    {0x0D00, 0x0D7F, OGTextFallbackMalayalamFonts},
    {0x0D80, 0x0DFF, OGTextFallbackSinhalaFonts},
    {0x0E00, 0x0E7F, OGTextFallbackThaiFonts},
    {0x1100, 0x11FF, OGTextFallbackHangulFonts},
    {0x1400, 0x167F, OGTextFallbackSyllabicsFonts},
    {0x2000, 0x2BFF, OGTextFallbackSymbolFonts},
    {0x2E80, 0x2FDF, OGTextFallbackHanFonts},
    {0x3000, 0x303F, OGTextFallbackHanFonts},
    {0x3040, 0x30FF, OGTextFallbackKanaFonts},
    {0x3100, 0x312F, OGTextFallbackHanFonts},
    {0x3130, 0x318F, OGTextFallbackHangulFonts},
    {0x3190, 0x31EF, OGTextFallbackHanFonts},
    {0x31F0, 0x31FF, OGTextFallbackKanaFonts},
    {0x3200, 0x4DBF, OGTextFallbackHanFonts},
    {0x4E00, 0x9FFF, OGTextFallbackHanFonts},
    {0xAC00, 0xD7AF, OGTextFallbackHangulFonts},
    {0xE000, 0xF8FF, OGTextFallbackEmojiFonts},
    {0xF900, 0xFAFF, OGTextFallbackHanFonts},
    {0xFB1D, 0xFB4F, OGTextFallbackHebrewFonts},
    {0xFB50, 0xFDFF, OGTextFallbackArabicFonts},
    {0xFE30, 0xFE4F, OGTextFallbackHanFonts},
    {0xFE70, 0xFEFE, OGTextFallbackArabicFonts},
    {0xFF00, 0xFFEF, OGTextFallbackKanaFonts},
    {0x1F000, 0x1FAFF, OGTextFallbackEmojiFonts},
    {0x20000, 0x2FFFF, OGTextFallbackHanFonts},
};

static const char *const *OGTextFallbackFontsForCodePoint(uint32_t codePoint)
{
    size_t count = sizeof(OGTextFallbackBlocks) / sizeof(OGTextFallbackBlocks[0]);
    for (size_t index = 0; index < count; index++)
    {
        if (codePoint >= OGTextFallbackBlocks[index].first && codePoint <= OGTextFallbackBlocks[index].last)
            return OGTextFallbackBlocks[index].fonts;
    }
    if (codePoint >= 0x10000)
        return NULL;
    return OGTextFallbackGeneralFonts;
}

static bool OGTextCodePointIsInvisible(uint32_t codePoint)
{
    return (codePoint >= 0x0300 && codePoint <= 0x036F) ||
        (codePoint >= 0x180B && codePoint <= 0x180E) ||
        (codePoint >= 0x200B && codePoint <= 0x200F) ||
        (codePoint >= 0x202A && codePoint <= 0x202E) ||
        (codePoint >= 0x2060 && codePoint <= 0x206F) ||
        (codePoint >= 0x20D0 && codePoint <= 0x20FF) ||
        (codePoint >= 0xFE00 && codePoint <= 0xFE0F) ||
        (codePoint >= 0xFE20 && codePoint <= 0xFE2F) ||
        codePoint == 0xFEFF ||
        (codePoint >= 0xFFF0 && codePoint <= 0xFFFB) ||
        (codePoint >= 0x1F3FB && codePoint <= 0x1F3FF) ||
        (codePoint >= 0xE0000 && codePoint <= 0xE0FFF);
}

static pthread_mutex_t OGTextFallbackMutex = PTHREAD_MUTEX_INITIALIZER;
static CFMutableDictionaryRef OGTextFallbackNamedFonts = NULL;
static CFMutableDictionaryRef OGTextFallbackCodePointFonts = NULL;
static CFMutableDictionaryRef OGTextFallbackSizedFonts = NULL;
static CTFontRef OGTextFallbackDefaultFont = NULL;
static CFMutableDictionaryRef OGTextFallbackStoredChoices = NULL;
static bool OGTextFallbackStoreSaveScheduled = false;

static NSString *OGTextFallbackStorePath(void)
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *caches = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *system = [[[UIDevice currentDevice] systemVersion] stringByReplacingOccurrencesOfString:@"." withString:@"_"];
        path = [caches stringByAppendingPathComponent:[NSString stringWithFormat:@"OGTextFallback-%@.plist", system]];
    });
    return path;
}

static CFMutableDictionaryRef OGTextFallbackStoredChoicesLocked(void)
{
    if (OGTextFallbackStoredChoices != NULL)
        return OGTextFallbackStoredChoices;
    OGTextFallbackStoredChoices = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:OGTextFallbackStorePath()];
    if ([stored isKindOfClass:[NSDictionary class]])
    {
        for (NSString *key in stored)
        {
            NSString *name = stored[key];
            if (![key isKindOfClass:[NSString class]] || ![name isKindOfClass:[NSString class]])
                continue;
            unsigned int codePoint = 0;
            if (![[NSScanner scannerWithString:key] scanHexInt:&codePoint] || codePoint == 0)
                continue;
            CFDictionarySetValue(OGTextFallbackStoredChoices, (const void *)(uintptr_t)codePoint, name.length != 0 ? (__bridge CFTypeRef)name : (CFTypeRef)kCFNull);
        }
    }
    return OGTextFallbackStoredChoices;
}

static void OGTextFallbackSaveStore(void)
{
    NSMutableDictionary *snapshot = [[NSMutableDictionary alloc] init];
    pthread_mutex_lock(&OGTextFallbackMutex);
    OGTextFallbackStoreSaveScheduled = false;
    CFDictionaryRef choices = OGTextFallbackStoredChoices;
    CFIndex count = choices != NULL ? CFDictionaryGetCount(choices) : 0;
    if (count != 0)
    {
        const void **keys = (const void **)malloc((size_t)count * sizeof(void *));
        const void **values = (const void **)malloc((size_t)count * sizeof(void *));
        if (keys != NULL && values != NULL)
        {
            CFDictionaryGetKeysAndValues(choices, keys, values);
            for (CFIndex index = 0; index < count; index++)
            {
                NSString *key = [NSString stringWithFormat:@"%lx", (unsigned long)(uintptr_t)keys[index]];
                snapshot[key] = values[index] == kCFNull ? @"" : [(__bridge NSString *)values[index] copy];
            }
        }
        free(keys);
        free(values);
    }
    pthread_mutex_unlock(&OGTextFallbackMutex);
    if (snapshot.count != 0)
        [snapshot writeToFile:OGTextFallbackStorePath() atomically:YES];
}

static void OGTextFallbackRememberChoiceLocked(uint32_t codePoint, CTFontRef font)
{
    CFMutableDictionaryRef choices = OGTextFallbackStoredChoicesLocked();
    CFTypeRef value = (CFTypeRef)kCFNull;
    CFStringRef name = font != NULL ? CTFontCopyPostScriptName(font) : NULL;
    if (name != NULL)
        value = name;
    CFDictionarySetValue(choices, (const void *)(uintptr_t)codePoint, value);
    if (name != NULL)
        CFRelease(name);
    if (OGTextFallbackStoreSaveScheduled)
        return;
    OGTextFallbackStoreSaveScheduled = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        @autoreleasepool
        {
            OGTextFallbackSaveStore();
        }
    });
}

static bool OGTextFontCoversUnits(CTFontRef font, const UniChar *units, CFIndex count)
{
    if (font == NULL)
        return false;
    CGGlyph glyphs[2] = {0, 0};
    return CTFontGetGlyphsForCharacters(font, units, glyphs, count);
}

static CTFontRef OGTextFallbackNamedFontLocked(const char *name)
{
    if (OGTextFallbackNamedFonts == NULL)
        OGTextFallbackNamedFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, name, kCFStringEncodingASCII);
    if (key == NULL)
        return NULL;
    CFTypeRef cached = CFDictionaryGetValue(OGTextFallbackNamedFonts, key);
    if (cached != NULL)
    {
        CFRelease(key);
        return cached == kCFNull ? NULL : (CTFontRef)cached;
    }

    CTFontRef font = CTFontCreateWithName(key, 16.0f, NULL);
    if (font != NULL)
    {
        CFStringRef postScriptName = CTFontCopyPostScriptName(font);
        bool matches = postScriptName != NULL && CFStringCompare(postScriptName, key, 0) == kCFCompareEqualTo;
        if (postScriptName != NULL)
            CFRelease(postScriptName);
        if (!matches)
        {
            CFRelease(font);
            font = NULL;
        }
    }
    CFDictionarySetValue(OGTextFallbackNamedFonts, key, font != NULL ? (CFTypeRef)font : (CFTypeRef)kCFNull);
    if (font != NULL)
        CFRelease(font);
    CFRelease(key);
    return font;
}

static CTFontRef OGTextFallbackFontForCodePointLocked(uint32_t codePoint, const UniChar *units, CFIndex count)
{
    if (OGTextFallbackCodePointFonts == NULL)
        OGTextFallbackCodePointFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    CFTypeRef cached = CFDictionaryGetValue(OGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint);
    if (cached != NULL)
        return cached == kCFNull ? NULL : (CTFontRef)cached;

    CFTypeRef stored = CFDictionaryGetValue(OGTextFallbackStoredChoicesLocked(), (const void *)(uintptr_t)codePoint);
    if (stored == kCFNull)
    {
        CFDictionarySetValue(OGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint, kCFNull);
        return NULL;
    }
    if (stored != NULL)
    {
        char name[128];
        if (CFStringGetCString((CFStringRef)stored, name, sizeof(name), kCFStringEncodingASCII))
        {
            CTFontRef storedFont = OGTextFallbackNamedFontLocked(name);
            if (OGTextFontCoversUnits(storedFont, units, count))
            {
                CFDictionarySetValue(OGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint, storedFont);
                return storedFont;
            }
        }
    }

    CTFontRef result = NULL;
    const char *const *fonts = OGTextFallbackFontsForCodePoint(codePoint);
    for (size_t index = 0; fonts != NULL && fonts[index] != NULL && result == NULL; index++)
    {
        CTFontRef candidate = OGTextFallbackNamedFontLocked(fonts[index]);
        if (OGTextFontCoversUnits(candidate, units, count))
            result = candidate;
    }
    CFDictionarySetValue(OGTextFallbackCodePointFonts, (const void *)(uintptr_t)codePoint, result != NULL ? (CFTypeRef)result : (CFTypeRef)kCFNull);
    OGTextFallbackRememberChoiceLocked(codePoint, result);
    return result;
}

static CTFontRef OGTextFallbackCreateVerifiedFont(CFStringRef name)
{
    CTFontRef font = CTFontCreateWithName(name, 16.0f, NULL);
    if (font == NULL)
        return NULL;
    CFStringRef postScriptName = CTFontCopyPostScriptName(font);
    bool matches = postScriptName != NULL && CFStringCompare(postScriptName, name, 0) == kCFCompareEqualTo;
    if (postScriptName != NULL)
        CFRelease(postScriptName);
    if (!matches)
    {
        CFRelease(font);
        return NULL;
    }
    return font;
}

static void OGTextUnitsForCodePoint(uint32_t codePoint, UniChar *units, CFIndex *count)
{
    if (codePoint >= 0x10000)
    {
        uint32_t value = codePoint - 0x10000;
        units[0] = (UniChar)(0xD800 + (value >> 10));
        units[1] = (UniChar)(0xDC00 + (value & 0x3FF));
        *count = 2;
    }
    else
    {
        units[0] = (UniChar)codePoint;
        *count = 1;
    }
}

void OGPlatformTextWarmFallbackFonts(void)
{
    if (!OGPlatformTextUsesManagedFallback())
        return;

    NSMutableDictionary *namesToCodePoints = [[NSMutableDictionary alloc] init];
    pthread_mutex_lock(&OGTextFallbackMutex);
    CFMutableDictionaryRef choices = OGTextFallbackStoredChoicesLocked();
    CFIndex count = CFDictionaryGetCount(choices);
    if (count != 0)
    {
        const void **keys = (const void **)malloc((size_t)count * sizeof(void *));
        const void **values = (const void **)malloc((size_t)count * sizeof(void *));
        if (keys != NULL && values != NULL)
        {
            CFDictionaryGetKeysAndValues(choices, keys, values);
            for (CFIndex index = 0; index < count; index++)
            {
                if (values[index] == kCFNull)
                    continue;
                NSString *name = [(__bridge NSString *)values[index] copy];
                if (OGTextFallbackNamedFonts != NULL && CFDictionaryGetValue(OGTextFallbackNamedFonts, (__bridge CFStringRef)name) != NULL)
                    continue;
                NSMutableArray *codePoints = namesToCodePoints[name];
                if (codePoints == nil)
                {
                    codePoints = [[NSMutableArray alloc] init];
                    namesToCodePoints[name] = codePoints;
                }
                [codePoints addObject:@((uint32_t)(uintptr_t)keys[index])];
            }
        }
        free(keys);
        free(values);
    }
    pthread_mutex_unlock(&OGTextFallbackMutex);

    for (NSString *name in namesToCodePoints)
    {
        @autoreleasepool
        {
            CTFontRef font = OGTextFallbackCreateVerifiedFont((__bridge CFStringRef)name);
            NSArray *codePoints = namesToCodePoints[name];
            bool covers = false;
            if (font != NULL && codePoints.count != 0)
            {
                UniChar units[2] = {0, 0};
                CFIndex unitCount = 0;
                OGTextUnitsForCodePoint([codePoints[0] unsignedIntValue], units, &unitCount);
                covers = OGTextFontCoversUnits(font, units, unitCount);
            }

            pthread_mutex_lock(&OGTextFallbackMutex);
            if (OGTextFallbackNamedFonts == NULL)
                OGTextFallbackNamedFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
            if (CFDictionaryGetValue(OGTextFallbackNamedFonts, (__bridge CFStringRef)name) == NULL)
                CFDictionarySetValue(OGTextFallbackNamedFonts, (__bridge CFStringRef)name, font != NULL ? (CFTypeRef)font : (CFTypeRef)kCFNull);
            CTFontRef shared = (CTFontRef)CFDictionaryGetValue(OGTextFallbackNamedFonts, (__bridge CFStringRef)name);
            if (covers && shared != NULL && (CFTypeRef)shared != kCFNull)
            {
                if (OGTextFallbackCodePointFonts == NULL)
                    OGTextFallbackCodePointFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
                for (NSNumber *codePoint in codePoints)
                {
                    const void *key = (const void *)(uintptr_t)[codePoint unsignedIntValue];
                    if (CFDictionaryGetValue(OGTextFallbackCodePointFonts, key) == NULL)
                        CFDictionarySetValue(OGTextFallbackCodePointFonts, key, shared);
                }
            }
            pthread_mutex_unlock(&OGTextFallbackMutex);
            if (font != NULL)
                CFRelease(font);
        }
    }
}

static CTFontRef OGTextFallbackSizedFontLocked(CTFontRef font, CGFloat size)
{
    if (OGTextFallbackSizedFonts == NULL)
        OGTextFallbackSizedFonts = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFStringRef postScriptName = CTFontCopyPostScriptName(font);
    if (postScriptName == NULL)
        return NULL;
    CFStringRef key = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@/%ld"), postScriptName, (long)lrint(size * 64.0f));
    CFRelease(postScriptName);
    if (key == NULL)
        return NULL;
    CTFontRef sized = (CTFontRef)CFDictionaryGetValue(OGTextFallbackSizedFonts, key);
    if (sized == NULL)
    {
        sized = CTFontCreateCopyWithAttributes(font, size, NULL, NULL);
        if (sized != NULL)
        {
            CFDictionarySetValue(OGTextFallbackSizedFonts, key, sized);
            CFRelease(sized);
        }
    }
    CFRelease(key);
    return sized;
}

static CTFontRef OGTextFallbackDefaultFontLocked(void)
{
    if (OGTextFallbackDefaultFont == NULL)
        OGTextFallbackDefaultFont = CTFontCreateWithName(CFSTR("Helvetica"), 12.0f, NULL);
    return OGTextFallbackDefaultFont;
}

static UniChar OGTextFallbackFillerForFontLocked(CTFontRef font, CTFontRef *outFillerFont)
{
    static const UniChar candidates[] = {0x200B, 0xFEFF, 0x2060};
    *outFillerFont = NULL;
    for (size_t index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++)
    {
        if (OGTextFontCoversUnits(font, &candidates[index], 1))
            return candidates[index];
    }
    for (size_t index = 0; index < sizeof(candidates) / sizeof(candidates[0]); index++)
    {
        CTFontRef fallback = OGTextFallbackFontForCodePointLocked(candidates[index], &candidates[index], 1);
        if (fallback != NULL)
        {
            *outFillerFont = fallback;
            return candidates[index];
        }
    }
    return ' ';
}

static CFIndex OGTextFallbackCompatibilityReplacement(CTFontRef font, const UniChar *units, CFIndex count, UniChar *replacement)
{
    CFMutableStringRef string = CFStringCreateMutable(kCFAllocatorDefault, 0);
    if (string == NULL)
        return 0;
    CFStringAppendCharacters(string, units, count);
    CFStringNormalize(string, kCFStringNormalizationFormKC);
    CFIndex length = CFStringGetLength(string);
    CFIndex result = 0;
    if (length > 0 && length <= count)
    {
        UniChar normalized[2] = {0, 0};
        CFStringGetCharacters(string, CFRangeMake(0, length), normalized);
        bool changed = length != count || normalized[0] != units[0];
        bool covered = true;
        for (CFIndex index = 0; index < length && covered; index++)
        {
            if (normalized[index] >= 0x80 && !OGTextFontCoversUnits(font, &normalized[index], 1))
                covered = false;
        }
        if (changed && covered)
        {
            replacement[0] = normalized[0];
            if (length > 1)
                replacement[1] = normalized[1];
            result = length;
        }
    }
    CFRelease(string);
    return result;
}

bool OGPlatformTextUsesManagedFallback(void)
{
    static int value = -1;
    if (value < 0)
    {
        NSInteger majorVersion = OGPlatformMajorVersion();
        value = majorVersion >= 4 && majorVersion < 7 ? 1 : 0;
    }
    return value == 1;
}

void OGPlatformTextApplyManagedFallback(CFMutableAttributedStringRef string)
{
    if (string == NULL || !OGPlatformTextUsesManagedFallback())
        return;

    CFStringRef text = CFAttributedStringGetString(string);
    CFIndex length = text != NULL ? CFStringGetLength(text) : 0;
    if (length == 0)
        return;

    UniChar stackUnits[512];
    UniChar *units = length <= 512 ? stackUnits : (UniChar *)malloc((size_t)length * sizeof(UniChar));
    if (units == NULL)
        return;
    CFStringGetCharacters(text, CFRangeMake(0, length), units);

    CFIndex firstNonAscii = 0;
    while (firstNonAscii < length && units[firstNonAscii] < 0x80)
        firstNonAscii++;
    if (firstNonAscii == length)
    {
        if (units != stackUnits)
            free(units);
        return;
    }

    pthread_mutex_lock(&OGTextFallbackMutex);
    CFIndex index = 0;
    while (index < length)
    {
        CFRange runRange = CFRangeMake(0, 0);
        CTFontRef runFont = (CTFontRef)CFAttributedStringGetAttribute(string, index, kCTFontAttributeName, &runRange);
        CFIndex runEnd = runRange.location + runRange.length;
        if (runEnd <= index || runEnd > length)
            runEnd = length;
        if (runFont == NULL)
            runFont = OGTextFallbackDefaultFontLocked();
        if (runFont != NULL)
            CFRetain(runFont);
        CGFloat runSize = runFont != NULL ? CTFontGetSize(runFont) : 12.0f;

        while (index < runEnd)
        {
            UniChar unit = units[index];
            CFIndex count = 1;
            uint32_t codePoint = unit;
            if (OGUnicodeIsHighSurrogate(unit) && index + 1 < runEnd && OGUnicodeIsLowSurrogate(units[index + 1]))
            {
                count = 2;
                codePoint = OGUnicodeScalarForSurrogatePair(unit, units[index + 1]);
            }

            if (codePoint < 0x80 || OGTextFontCoversUnits(runFont, units + index, count))
            {
                index += count;
                continue;
            }

            CTFontRef fallback = OGTextFallbackFontForCodePointLocked(codePoint, units + index, count);
            if (fallback != NULL)
            {
                CTFontRef sized = OGTextFallbackSizedFontLocked(fallback, runSize);
                if (sized != NULL)
                    CFAttributedStringSetAttribute(string, CFRangeMake(index, count), kCTFontAttributeName, sized);
                index += count;
                continue;
            }

            bool invisible = OGTextCodePointIsInvisible(codePoint);
            UniChar replacement[2] = {' ', ' '};
            CFIndex replacementLength = invisible ? 0 : OGTextFallbackCompatibilityReplacement(runFont, units + index, count, replacement);
            CTFontRef fillerFont = NULL;
            UniChar filler = OGTextFallbackFillerForFontLocked(runFont, &fillerFont);
            if (replacementLength == 0)
            {
                replacement[0] = invisible ? filler : ' ';
                replacementLength = 1;
            }
            for (CFIndex fillIndex = replacementLength; fillIndex < count; fillIndex++)
                replacement[fillIndex] = filler;

            CFStringRef replacementString = CFStringCreateWithCharacters(kCFAllocatorDefault, replacement, count);
            if (replacementString != NULL)
            {
                CFAttributedStringReplaceString(string, CFRangeMake(index, count), replacementString);
                CFRelease(replacementString);
                if (fillerFont != NULL)
                {
                    CTFontRef sizedFiller = OGTextFallbackSizedFontLocked(fillerFont, runSize);
                    for (CFIndex fillIndex = 0; fillIndex < count && sizedFiller != NULL; fillIndex++)
                    {
                        if (replacement[fillIndex] == filler)
                            CFAttributedStringSetAttribute(string, CFRangeMake(index + fillIndex, 1), kCTFontAttributeName, sizedFiller);
                    }
                }
            }
            index += count;
        }
        if (runFont != NULL)
            CFRelease(runFont);
    }
    pthread_mutex_unlock(&OGTextFallbackMutex);

    if (units != stackUnits)
        free(units);
}

static CFAttributedStringRef OGPlatformTextCreateManagedString(CFAttributedStringRef string)
{
    if (string == NULL || !OGPlatformTextUsesManagedFallback())
        return NULL;
    CFStringRef text = CFAttributedStringGetString(string);
    CFIndex length = text != NULL ? CFStringGetLength(text) : 0;
    bool hasNonAscii = false;
    if (length > 0)
    {
        CFStringInlineBuffer buffer;
        CFStringInitInlineBuffer(text, &buffer, CFRangeMake(0, length));
        for (CFIndex index = 0; index < length; index++)
        {
            if (CFStringGetCharacterFromInlineBuffer(&buffer, index) >= 0x80)
            {
                hasNonAscii = true;
                break;
            }
        }
    }
    if (!hasNonAscii)
        return NULL;
    CFMutableAttributedStringRef copy = CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, string);
    if (copy == NULL)
        return NULL;
    OGPlatformTextApplyManagedFallback(copy);
    return copy;
}

CTLineRef OGPlatformTextCreateLine(CFAttributedStringRef string)
{
#if defined(ONEGRAM_DIAGNOSTICS)
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
#endif
    CFAttributedStringRef managed = OGPlatformTextCreateManagedString(string);
    CTLineRef line = CTLineCreateWithAttributedString(managed != NULL ? managed : string);
#if defined(ONEGRAM_DIAGNOSTICS)
    OGPlatformTextLogSlowLayout("line", managed != NULL ? managed : string, CFAbsoluteTimeGetCurrent() - start);
#endif
    if (managed != NULL)
        CFRelease(managed);
    return line;
}

CTTypesetterRef OGPlatformTextCreateTypesetter(CFAttributedStringRef string)
{
#if defined(ONEGRAM_DIAGNOSTICS)
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
#endif
    CFAttributedStringRef managed = OGPlatformTextCreateManagedString(string);
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(managed != NULL ? managed : string);
#if defined(ONEGRAM_DIAGNOSTICS)
    OGPlatformTextLogSlowLayout("typesetter", managed != NULL ? managed : string, CFAbsoluteTimeGetCurrent() - start);
#endif
    if (managed != NULL)
        CFRelease(managed);
    return typesetter;
}

#else

bool OGPlatformTextUsesManagedFallback(void)
{
    return false;
}

void OGPlatformTextWarmFallbackFonts(void)
{
}

void OGPlatformTextApplyManagedFallback(CFMutableAttributedStringRef string)
{
    (void)string;
}

CTLineRef OGPlatformTextCreateLine(CFAttributedStringRef string)
{
    return CTLineCreateWithAttributedString(string);
}

CTTypesetterRef OGPlatformTextCreateTypesetter(CFAttributedStringRef string)
{
    return CTTypesetterCreateWithAttributedString(string);
}

#endif
