#import "TGPresentationCustomColors.h"

#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"

#import "TGPresentation.h"
#import "TGPresentationPallete.h"
#import "TGDayPresentationPallete.h"
#import "TGOnegramSettings.h"

static NSString *const TGPresentationCustomColorsDefaultsKey = @"Onegram.Appearance.CustomColors";
static NSString *const TGPresentationCustomColorsThemeDefaultsKey = @"Onegram.Appearance.ThemeColors";
static const char *TGPresentationCustomColorsClassPrefix = "TGCustomColors_";
static const NSUInteger TGPresentationColorParameterMaxKeys = 28;

typedef struct {
    const char *identifier;
    TGPresentationColorSection section;
    TGPresentationColorPreview preview;
    const char *keys[TGPresentationColorParameterMaxKeys];
    const char *highlightKeys[4];
} TGPresentationColorParameterDefinition;

static const TGPresentationColorParameterDefinition TGPresentationColorParameterDefinitions[] = {
    {"Accent", TGPresentationColorSectionGeneral, TGPresentationColorPreviewAccent, {"accentColor", "maybeAccentColor", "linkColor", "navigationButtonColor", "navigationSpinnerColor", "navigationActiveSubtitleColor", "tabActiveIconColor", "collectionMenuAccentColor", "collectionMenuSwitchColor", "collectionMenuCheckColor", "collectionMenuSpinnerColor", "checkButtonBackgroundColor", "checkButtonBlueColor", "dialogChecksColor", "dialogBadgeColor", "tabBadgeColor", "chatInputSendButtonColor", "chatIncomingAccentColor", "chatIncomingLinkColor", "chatStickersBadgeColor", "menuAccentColor", "menuLinkColor", "locationAccentColor", "musicControlsColor", "callsOutgoingIconColor", NULL}, {NULL}},
    {"ScreenBackground", TGPresentationColorSectionGeneral, TGPresentationColorPreviewScreenBackground, {"collectionMenuBackgroundColor", NULL}, {NULL}},
    {"ListBackground", TGPresentationColorSectionGeneral, TGPresentationColorPreviewListBackground, {"backgroundColor", "collectionMenuCellBackgroundColor", "menuBackgroundColor", NULL}, {NULL}},
    {"Bars", TGPresentationColorSectionGeneral, TGPresentationColorPreviewBar, {"barBackgroundColor", "sectionHeaderBackgroundColor", "tabBadgeBorderColor", "navigationBadgeBorderColor", NULL}, {NULL}},
    {"BarTitle", TGPresentationColorSectionGeneral, TGPresentationColorPreviewBarTitle, {"navigationTitleColor", NULL}, {NULL}},
    {"TabIcons", TGPresentationColorSectionGeneral, TGPresentationColorPreviewTabIcons, {"tabIconColor", "tabTextColor", NULL}, {NULL}},
    {"Text", TGPresentationColorSectionGeneral, TGPresentationColorPreviewText, {"textColor", "collectionMenuTextColor", "menuTextColor", NULL}, {NULL}},
    {"SecondaryText", TGPresentationColorSectionGeneral, TGPresentationColorPreviewSecondaryText, {"secondaryTextColor", "collectionMenuVariantColor", "collectionMenuCommentColor", "menuSecondaryTextColor", "navigationSubtitleColor", NULL}, {NULL}},
    {"Separators", TGPresentationColorSectionGeneral, TGPresentationColorPreviewSeparator, {"separatorColor", "collectionMenuSeparatorColor", "barSeparatorColor", "menuSeparatorColor", NULL}, {NULL}},
    {"DialogTitle", TGPresentationColorSectionChatList, TGPresentationColorPreviewDialogTitle, {"dialogTitleColor", "dialogNameColor", NULL}, {NULL}},
    {"DialogText", TGPresentationColorSectionChatList, TGPresentationColorPreviewDialogText, {"dialogTextColor", NULL}, {NULL}},
    {"DialogDate", TGPresentationColorSectionChatList, TGPresentationColorPreviewDialogDate, {"dialogDateColor", NULL}, {NULL}},
    {"DialogBadge", TGPresentationColorSectionChatList, TGPresentationColorPreviewDialogBadge, {"dialogBadgeColor", "tabBadgeColor", "navigationBadgeColor", NULL}, {NULL}},
    {"DialogBadgeText", TGPresentationColorSectionChatList, TGPresentationColorPreviewDialogBadgeText, {"dialogBadgeTextColor", "tabBadgeTextColor", "navigationBadgeTextColor", NULL}, {NULL}},
    {"OutgoingBubble", TGPresentationColorSectionMessages, TGPresentationColorPreviewOutgoingBubble, {"chatOutgoingBubbleColor", "chatOutgoingBubbleBorderColor", NULL}, {"chatOutgoingHighlightedBubbleColor", "chatOutgoingHighlightedBubbleBorderColor", NULL}},
    {"OutgoingText", TGPresentationColorSectionMessages, TGPresentationColorPreviewOutgoingText, {"chatOutgoingTextColor", NULL}, {NULL}},
    {"OutgoingSecondary", TGPresentationColorSectionMessages, TGPresentationColorPreviewOutgoingSecondary, {"chatOutgoingDateColor", "chatOutgoingSubtextColor", "chatChecksColor", NULL}, {NULL}},
    {"OutgoingLink", TGPresentationColorSectionMessages, TGPresentationColorPreviewOutgoingLink, {"chatOutgoingLinkColor", "chatOutgoingAccentColor", "chatOutgoingLineColor", NULL}, {NULL}},
    {"IncomingBubble", TGPresentationColorSectionMessages, TGPresentationColorPreviewIncomingBubble, {"chatIncomingBubbleColor", "chatIncomingBubbleBorderColor", NULL}, {"chatIncomingHighlightedBubbleColor", "chatIncomingHighlightedBubbleBorderColor", NULL}},
    {"IncomingText", TGPresentationColorSectionMessages, TGPresentationColorPreviewIncomingText, {"chatIncomingTextColor", NULL}, {NULL}},
    {"IncomingSecondary", TGPresentationColorSectionMessages, TGPresentationColorPreviewIncomingSecondary, {"chatIncomingDateColor", "chatIncomingSubtextColor", NULL}, {NULL}},
    {"IncomingLink", TGPresentationColorSectionMessages, TGPresentationColorPreviewIncomingLink, {"chatIncomingLinkColor", "chatIncomingAccentColor", "chatIncomingLineColor", NULL}, {NULL}},
    {"SystemBackground", TGPresentationColorSectionMessages, TGPresentationColorPreviewSystemBackground, {"chatSystemBackgroundColor", NULL}, {NULL}},
    {"SystemText", TGPresentationColorSectionMessages, TGPresentationColorPreviewSystemText, {"chatSystemTextColor", NULL}, {NULL}},
    {"InputPanel", TGPresentationColorSectionMessages, TGPresentationColorPreviewInputPanel, {"chatInputBackgroundColor", NULL}, {NULL}},
    {"SendButton", TGPresentationColorSectionMessages, TGPresentationColorPreviewSendButton, {"chatInputSendButtonColor", NULL}, {NULL}}
};

static const NSUInteger TGPresentationColorParameterCount = sizeof(TGPresentationColorParameterDefinitions) / sizeof(TGPresentationColorParameterDefinitions[0]);

@interface TGPresentationColorParameter ()
{
@public
    NSUInteger _definitionIndex;
}

@end

@implementation TGPresentationColorParameter

- (instancetype)initWithDefinitionIndex:(NSUInteger)index
{
    self = [super init];
    if (self != nil)
    {
        const TGPresentationColorParameterDefinition *definition = &TGPresentationColorParameterDefinitions[index];
        _definitionIndex = index;
        _identifier = [[NSString alloc] initWithUTF8String:definition->identifier];
        _section = definition->section;
        _preview = definition->preview;
    }
    return self;
}

- (NSString *)title
{
    return TGLocalized([@"OnegramColors." stringByAppendingString:_identifier]);
}

- (SEL)primarySelector
{
    return sel_registerName(TGPresentationColorParameterDefinitions[_definitionIndex].keys[0]);
}

@end

typedef struct {
    __unsafe_unretained id receiver;
    __unsafe_unretained Class superClass;
} TGPresentationCustomColorsSuper;

static pthread_mutex_t TGPresentationCustomColorsMutex = PTHREAD_MUTEX_INITIALIZER;
static NSDictionary *TGPresentationCustomColorsStorage = nil;
static NSDictionary *TGPresentationCustomColorsThemeStorage = nil;
static NSUInteger TGPresentationCustomColorsPreviewCounter = 0;
static CFMutableDictionaryRef TGPresentationCustomColorsResolved = NULL;
static NSMutableDictionary *TGPresentationCustomColorsSubclasses = nil;

static UIColor *TGPresentationCustomColorsHighlighted(UIColor *color)
{
    CGFloat hue = 0.0f, saturation = 0.0f, brightness = 0.0f, alpha = 0.0f;
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    size_t count = CGColorGetNumberOfComponents(color.CGColor);
    CGFloat red = components[0];
    CGFloat green = count >= 3 ? components[1] : red;
    CGFloat blue = count >= 3 ? components[2] : red;
    alpha = components[count - 1];
    CGFloat maxValue = MAX(red, MAX(green, blue));
    CGFloat minValue = MIN(red, MIN(green, blue));
    brightness = maxValue;
    saturation = maxValue > FLT_EPSILON ? (maxValue - minValue) / maxValue : 0.0f;
    if (maxValue - minValue > FLT_EPSILON)
    {
        CGFloat delta = maxValue - minValue;
        if (maxValue == red)
            hue = (green - blue) / delta + (green < blue ? 6.0f : 0.0f);
        else if (maxValue == green)
            hue = (blue - red) / delta + 2.0f;
        else
            hue = (red - green) / delta + 4.0f;
        hue /= 6.0f;
    }
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness * 0.87f alpha:alpha];
}

static NSDictionary *TGPresentationCustomColorsLoadStorage(void)
{
    if (TGPresentationCustomColorsStorage == nil)
    {
        NSDictionary *stored = [[NSUserDefaults standardUserDefaults] objectForKey:TGPresentationCustomColorsDefaultsKey];
        TGPresentationCustomColorsStorage = [stored isKindOfClass:[NSDictionary class]] ? stored : @{};
    }
    return TGPresentationCustomColorsStorage;
}

static NSDictionary *TGPresentationCustomColorsLoadThemeStorage(void)
{
    if (TGPresentationCustomColorsThemeStorage == nil)
    {
        NSDictionary *stored = [[NSUserDefaults standardUserDefaults] objectForKey:TGPresentationCustomColorsThemeDefaultsKey];
        TGPresentationCustomColorsThemeStorage = [stored isKindOfClass:[NSDictionary class]] ? stored : @{};
    }
    return TGPresentationCustomColorsThemeStorage;
}

static UIColor *TGPresentationCustomColorsColorWithARGB(uint32_t argb)
{
    uint32_t rgb = argb & 0xffffff;
    CGFloat alpha = ((argb >> 24) & 0xff) / 255.0f;
    return UIColorRGBA(rgb, alpha);
}

static void TGPresentationCustomColorsFillThemeColors(CFMutableDictionaryRef map, NSDictionary *colors)
{
    if (![colors isKindOfClass:[NSDictionary class]])
        return;
    for (NSString *selectorName in colors)
    {
        NSNumber *value = colors[selectorName];
        if (![selectorName isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSNumber class]])
            continue;
        CFDictionarySetValue(map, sel_registerName([selectorName UTF8String]), (__bridge const void *)TGPresentationCustomColorsColorWithARGB([value unsignedIntValue]));
    }
}

static CFDictionaryRef TGPresentationCustomColorsResolvedLocked(Class dynamicClass)
{
    if (TGPresentationCustomColorsResolved == NULL)
        TGPresentationCustomColorsResolved = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    CFDictionaryRef resolved = (CFDictionaryRef)CFDictionaryGetValue(TGPresentationCustomColorsResolved, (__bridge const void *)dynamicClass);
    if (resolved != NULL)
        return resolved;

    NSString *baseName = NSStringFromClass(class_getSuperclass(dynamicClass));
    CFMutableDictionaryRef map = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
    TGPresentationCustomColorsFillThemeColors(map, TGPresentationCustomColorsLoadThemeStorage()[baseName]);
    NSDictionary *themeColors = TGPresentationCustomColorsLoadStorage()[baseName];
    if ([themeColors isKindOfClass:[NSDictionary class]])
    {
        for (NSUInteger i = 0; i < TGPresentationColorParameterCount; i++)
        {
            const TGPresentationColorParameterDefinition *definition = &TGPresentationColorParameterDefinitions[i];
            NSNumber *value = themeColors[[[NSString alloc] initWithUTF8String:definition->identifier]];
            if (![value isKindOfClass:[NSNumber class]])
                continue;
            UIColor *color = UIColorRGB([value unsignedIntValue]);
            for (NSUInteger k = 0; k < TGPresentationColorParameterMaxKeys && definition->keys[k] != NULL; k++)
                CFDictionarySetValue(map, sel_registerName(definition->keys[k]), (__bridge const void *)color);
            if (definition->highlightKeys[0] == NULL)
                continue;
            UIColor *highlighted = TGPresentationCustomColorsHighlighted(color);
            for (NSUInteger k = 0; k < 4 && definition->highlightKeys[k] != NULL; k++)
                CFDictionarySetValue(map, sel_registerName(definition->highlightKeys[k]), (__bridge const void *)highlighted);
        }
    }
    CFDictionarySetValue(TGPresentationCustomColorsResolved, (__bridge const void *)dynamicClass, map);
    CFRelease(map);
    return map;
}

static UIColor *TGPresentationCustomColorsResolvedColor(Class dynamicClass, SEL selector)
{
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    UIColor *color = (__bridge UIColor *)CFDictionaryGetValue(TGPresentationCustomColorsResolvedLocked(dynamicClass), selector);
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);
    return color;
}

static void TGPresentationCustomColorsInvalidateLocked(NSString *baseName)
{
    Class subclass = TGPresentationCustomColorsSubclasses[baseName];
    if (TGPresentationCustomColorsResolved != NULL && subclass != Nil)
        CFDictionaryRemoveValue(TGPresentationCustomColorsResolved, (__bridge const void *)subclass);
}

static Class TGPresentationCustomColorsBaseClass(id pallete)
{
    Class cls = object_getClass(pallete);
    if (strncmp(class_getName(cls), TGPresentationCustomColorsClassPrefix, strlen(TGPresentationCustomColorsClassPrefix)) == 0)
        return class_getSuperclass(cls);
    return cls;
}

static id TGPresentationCustomColorsSuperValue(id pallete, SEL selector)
{
    Class baseClass = TGPresentationCustomColorsBaseClass(pallete);
    TGPresentationCustomColorsSuper superInfo;
    superInfo.receiver = pallete;
    superInfo.superClass = baseClass;
    return ((id (*)(TGPresentationCustomColorsSuper *, SEL))objc_msgSendSuper)(&superInfo, selector);
}

static volatile int TGPresentationCustomColorsSeparatorsState = -1;

static bool TGPresentationCustomColorsSeparatorsHidden(void)
{
    int state = TGPresentationCustomColorsSeparatorsState;
    if (state < 0)
    {
        state = [TGOnegramSettings boolForKey:TGOnegramSettingAppearanceSeparators] ? 0 : 1;
        TGPresentationCustomColorsSeparatorsState = state;
    }
    return state == 1;
}

static bool TGPresentationCustomColorsIsSeparatorSelector(SEL selector)
{
    static SEL selectors[6];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        selectors[0] = @selector(separatorColor);
        selectors[1] = @selector(padSeparatorColor);
        selectors[2] = @selector(barSeparatorColor);
        selectors[3] = @selector(collectionMenuSeparatorColor);
        selectors[4] = @selector(menuSeparatorColor);
        selectors[5] = @selector(chatInputKeyboardBorderColor);
    });
    for (NSUInteger i = 0; i < sizeof(selectors) / sizeof(selectors[0]); i++)
    {
        if (selectors[i] == selector)
            return true;
    }
    return false;
}

static id TGPresentationCustomColorsGetter(id self, SEL _cmd)
{
    if (TGPresentationCustomColorsSeparatorsHidden() && TGPresentationCustomColorsIsSeparatorSelector(_cmd))
        return [UIColor clearColor];
    UIColor *color = TGPresentationCustomColorsResolvedColor(object_getClass(self), _cmd);
    if (color != nil)
        return color;
    return TGPresentationCustomColorsSuperValue(self, _cmd);
}

static Class TGPresentationCustomColorsClassMethod(id self, SEL __unused _cmd)
{
    return TGPresentationCustomColorsBaseClass(self);
}

static BOOL TGPresentationCustomColorsIsMemberOfClass(id self, SEL __unused _cmd, Class cls)
{
    return TGPresentationCustomColorsBaseClass(self) == cls;
}

static Class TGPresentationCustomColorsCreateSubclassLocked(Class baseClass, NSString *name)
{
    Class subclass = objc_allocateClassPair(baseClass, [name UTF8String], 0);
    if (subclass == Nil)
        return Nil;
    unsigned int propertyCount = 0;
    objc_property_t *properties = class_copyPropertyList([TGPresentationPallete class], &propertyCount);
    for (unsigned int i = 0; i < propertyCount; i++)
    {
        const char *attributes = property_getAttributes(properties[i]);
        if (attributes == NULL || strstr(attributes, "T@\"UIColor\"") != attributes)
            continue;
        class_addMethod(subclass, sel_registerName(property_getName(properties[i])), (IMP)TGPresentationCustomColorsGetter, "@@:");
    }
    free(properties);
    class_addMethod(subclass, @selector(class), (IMP)TGPresentationCustomColorsClassMethod, "#@:");
    class_addMethod(subclass, @selector(isMemberOfClass:), (IMP)TGPresentationCustomColorsIsMemberOfClass, "c@:#");
    objc_registerClassPair(subclass);
    return subclass;
}

static Class TGPresentationCustomColorsSubclass(Class baseClass)
{
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    if (TGPresentationCustomColorsSubclasses == nil)
        TGPresentationCustomColorsSubclasses = [[NSMutableDictionary alloc] init];
    NSString *baseName = NSStringFromClass(baseClass);
    Class subclass = TGPresentationCustomColorsSubclasses[baseName];
    if (subclass == Nil)
    {
        subclass = TGPresentationCustomColorsCreateSubclassLocked(baseClass, [[NSString alloc] initWithFormat:@"%s%@", TGPresentationCustomColorsClassPrefix, baseName]);
        if (subclass != Nil)
            TGPresentationCustomColorsSubclasses[baseName] = subclass;
    }
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);
    return subclass;
}

@implementation TGPresentationCustomColors

+ (NSArray *)parameters
{
    static NSArray *parameters = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:TGPresentationColorParameterCount];
        for (NSUInteger i = 0; i < TGPresentationColorParameterCount; i++)
            [array addObject:[[TGPresentationColorParameter alloc] initWithDefinitionIndex:i]];
        parameters = array;
    });
    return parameters;
}

+ (NSArray *)parametersInSection:(TGPresentationColorSection)section
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (TGPresentationColorParameter *parameter in [self parameters])
    {
        if (parameter.section == section)
            [result addObject:parameter];
    }
    return result;
}

+ (TGPresentationPallete *)palleteApplyingCustomColors:(TGPresentationPallete *)pallete
{
    if (pallete == nil)
        return nil;
    Class baseClass = TGPresentationCustomColorsBaseClass(pallete);
    if (object_getClass(pallete) != baseClass)
        return pallete;
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    NSString *baseName = NSStringFromClass(baseClass);
    NSDictionary *userColors = TGPresentationCustomColorsLoadStorage()[baseName];
    NSDictionary *themeColors = TGPresentationCustomColorsLoadThemeStorage()[baseName];
    bool hasColors = ([userColors isKindOfClass:[NSDictionary class]] && userColors.count != 0) || ([themeColors isKindOfClass:[NSDictionary class]] && themeColors.count != 0);
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);
    if (!hasColors && !TGPresentationCustomColorsSeparatorsHidden())
        return pallete;
    Class subclass = TGPresentationCustomColorsSubclass(baseClass);
    if (subclass != Nil)
        object_setClass(pallete, subclass);
    return pallete;
}

+ (void)setSeparatorsHidden:(bool)hidden
{
    TGPresentationCustomColorsSeparatorsState = hidden ? 1 : 0;
}

+ (bool)isNativeAccentParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete
{
    return parameter->_definitionIndex == 0 && [TGPresentationCustomColorsBaseClass(pallete) isSubclassOfClass:[TGDayPresentationPallete class]];
}

+ (NSNumber *)storedValueForParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete
{
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    NSDictionary *themeColors = TGPresentationCustomColorsLoadStorage()[NSStringFromClass(TGPresentationCustomColorsBaseClass(pallete))];
    NSNumber *value = [themeColors isKindOfClass:[NSDictionary class]] ? themeColors[parameter.identifier] : nil;
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);
    return [value isKindOfClass:[NSNumber class]] ? value : nil;
}

+ (UIColor *)colorForParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete
{
    if (pallete == nil || parameter == nil)
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(pallete, [parameter primarySelector]);
}

+ (UIColor *)defaultColorForParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete
{
    if (pallete == nil || parameter == nil)
        return nil;
    if ([self isNativeAccentParameter:parameter pallete:pallete])
        return [[TGDayPresentationPallete alloc] init].accentColor;
    if (object_getClass(pallete) == TGPresentationCustomColorsBaseClass(pallete))
        return [self colorForParameter:parameter pallete:pallete];
    return TGPresentationCustomColorsSuperValue(pallete, [parameter primarySelector]);
}

+ (bool)hasCustomColorForParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete
{
    if ([self isNativeAccentParameter:parameter pallete:pallete])
        return TGColorHexCode(pallete.accentColor) != TGColorHexCode([self defaultColorForParameter:parameter pallete:pallete]);
    return [self storedValueForParameter:parameter pallete:pallete] != nil;
}

+ (bool)hasCustomColorsForPallete:(TGPresentationPallete *)pallete
{
    for (TGPresentationColorParameter *parameter in [self parameters])
    {
        if ([self hasCustomColorForParameter:parameter pallete:pallete])
            return true;
    }
    return false;
}

+ (void)updateStorage:(void (^)(NSMutableDictionary *themeColors))block pallete:(TGPresentationPallete *)pallete
{
    NSString *themeKey = NSStringFromClass(TGPresentationCustomColorsBaseClass(pallete));
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    NSMutableDictionary *storage = [[NSMutableDictionary alloc] initWithDictionary:TGPresentationCustomColorsLoadStorage()];
    NSDictionary *currentTheme = storage[themeKey];
    NSMutableDictionary *themeColors = [[NSMutableDictionary alloc] initWithDictionary:[currentTheme isKindOfClass:[NSDictionary class]] ? currentTheme : @{}];
    block(themeColors);
    if (themeColors.count == 0)
        [storage removeObjectForKey:themeKey];
    else
        storage[themeKey] = themeColors;
    TGPresentationCustomColorsStorage = storage;
    TGPresentationCustomColorsInvalidateLocked(themeKey);
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);

    [[NSUserDefaults standardUserDefaults] setObject:storage forKey:TGPresentationCustomColorsDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (void)setColor:(UIColor *)color forParameter:(TGPresentationColorParameter *)parameter pallete:(TGPresentationPallete *)pallete
{
    if (pallete == nil || parameter == nil)
        return;

    if ([self isNativeAccentParameter:parameter pallete:pallete])
    {
        [TGPresentation switchToPallete:color == nil ? [[TGDayPresentationPallete alloc] init] : [TGDayPresentationPallete dayPalleteWithAccentColor:color]];
        return;
    }

    NSString *identifier = parameter.identifier;
    [self updateStorage:^(NSMutableDictionary *themeColors)
    {
        if (color == nil)
            [themeColors removeObjectForKey:identifier];
        else
            themeColors[identifier] = @(TGColorHexCode(color));
    } pallete:pallete];
    [TGPresentation reloadCustomColors];
}

+ (void)setThemeColors:(NSDictionary *)colors forPalleteClass:(Class)palleteClass
{
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    for (NSString *baseName in TGPresentationCustomColorsLoadThemeStorage())
        TGPresentationCustomColorsInvalidateLocked(baseName);
    NSDictionary *storage = colors.count != 0 && palleteClass != Nil ? @{NSStringFromClass(palleteClass): colors} : @{};
    TGPresentationCustomColorsThemeStorage = storage;
    if (palleteClass != Nil)
        TGPresentationCustomColorsInvalidateLocked(NSStringFromClass(palleteClass));
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);

    [[NSUserDefaults standardUserDefaults] setObject:storage forKey:TGPresentationCustomColorsThemeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSDictionary *)themeColorsByPalleteClassName
{
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    NSDictionary *storage = [TGPresentationCustomColorsLoadThemeStorage() copy];
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);
    return storage;
}

+ (TGPresentationPallete *)previewPalleteWithPallete:(TGPresentationPallete *)pallete themeColors:(NSDictionary *)colors
{
    if (pallete == nil)
        return nil;
    Class baseClass = TGPresentationCustomColorsBaseClass(pallete);
    pthread_mutex_lock(&TGPresentationCustomColorsMutex);
    TGPresentationCustomColorsPreviewCounter++;
    NSString *name = [[NSString alloc] initWithFormat:@"%sPreview%lu_%@", TGPresentationCustomColorsClassPrefix, (unsigned long)TGPresentationCustomColorsPreviewCounter, NSStringFromClass(baseClass)];
    Class subclass = TGPresentationCustomColorsCreateSubclassLocked(baseClass, name);
    if (subclass != Nil)
    {
        if (TGPresentationCustomColorsResolved == NULL)
            TGPresentationCustomColorsResolved = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        CFMutableDictionaryRef map = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        TGPresentationCustomColorsFillThemeColors(map, colors);
        CFDictionarySetValue(TGPresentationCustomColorsResolved, (__bridge const void *)subclass, map);
        CFRelease(map);
    }
    pthread_mutex_unlock(&TGPresentationCustomColorsMutex);
    if (subclass != Nil && object_getClass(pallete) == baseClass)
        object_setClass(pallete, subclass);
    return pallete;
}

+ (NSArray *)selectorNamesForParameterIdentifier:(NSString *)identifier
{
    for (NSUInteger i = 0; i < TGPresentationColorParameterCount; i++)
    {
        const TGPresentationColorParameterDefinition *definition = &TGPresentationColorParameterDefinitions[i];
        if (strcmp(definition->identifier, [identifier UTF8String]) != 0)
            continue;
        NSMutableArray *names = [[NSMutableArray alloc] init];
        for (NSUInteger k = 0; k < TGPresentationColorParameterMaxKeys && definition->keys[k] != NULL; k++)
            [names addObject:[[NSString alloc] initWithUTF8String:definition->keys[k]]];
        return names;
    }
    return @[];
}

+ (void)resetColorsForPallete:(TGPresentationPallete *)pallete
{
    if (pallete == nil)
        return;
    [self updateStorage:^(NSMutableDictionary *themeColors)
    {
        [themeColors removeAllObjects];
    } pallete:pallete];
    if ([TGPresentationCustomColorsBaseClass(pallete) isSubclassOfClass:[TGDayPresentationPallete class]])
        [TGPresentation switchToPallete:[[TGDayPresentationPallete alloc] init]];
    else
        [TGPresentation reloadCustomColors];
}

@end
