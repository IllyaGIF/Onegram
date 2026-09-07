#import "TGFont.h"

#import "LegacyComponentsInternal.h"
#import "NSObject+TGLock.h"

#import <CoreText/CoreText.h>
#import <map>

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
    
    if (iosMajorVersion() <= 5)
    {
        CTFontRef result = NULL;
        
        CTFontDescriptorRef baseDescriptor =
        CTFontDescriptorCreateWithNameAndSize(
                                              (__bridge CFStringRef)font.fontName,
                                              font.pointSize
                                              );
        
        CTFontDescriptorRef emojiDescriptor =
        CTFontDescriptorCreateWithNameAndSize(
                                              CFSTR("AppleColorEmoji"),
                                              font.pointSize
                                              );
        
        if (baseDescriptor != NULL && emojiDescriptor != NULL)
        {
            const void *cascadeValues[] =
            {
                emojiDescriptor
            };
            
            CFArrayRef cascadeList =
            CFArrayCreate(
                          kCFAllocatorDefault,
                          cascadeValues,
                          1,
                          &kCFTypeArrayCallBacks
                          );
            
            if (cascadeList != NULL)
            {
                const void *attributeKeys[] =
                {
                    kCTFontCascadeListAttribute
                };
                
                const void *attributeValues[] =
                {
                    cascadeList
                };
                
                CFDictionaryRef attributes =
                CFDictionaryCreate(
                                   kCFAllocatorDefault,
                                   attributeKeys,
                                   attributeValues,
                                   1,
                                   &kCFTypeDictionaryKeyCallBacks,
                                   &kCFTypeDictionaryValueCallBacks
                                   );
                
                if (attributes != NULL)
                {
                    CTFontDescriptorRef finalDescriptor =
                    CTFontDescriptorCreateCopyWithAttributes(
                                                             baseDescriptor,
                                                             attributes
                                                             );
                    
                    if (finalDescriptor != NULL)
                    {
                        result =
                        CTFontCreateWithFontDescriptor(
                                                       finalDescriptor,
                                                       font.pointSize,
                                                       NULL
                                                       );
                        
                        CFRelease(finalDescriptor);
                    }
                    
                    CFRelease(attributes);
                }
                
                CFRelease(cascadeList);
            }
        }
        
        if (emojiDescriptor != NULL)
            CFRelease(emojiDescriptor);
        
        if (baseDescriptor != NULL)
            CFRelease(baseDescriptor);
        
        if (result != NULL)
            return result;
    }
    
    return CTFontCreateWithName(
                                (__bridge CFStringRef)font.fontName,
                                font.pointSize,
                                NULL
                                );
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