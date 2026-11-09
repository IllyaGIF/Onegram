#import "TGOnegramSettings.h"
#import "TGNightPresentationPallete.h"
#import "TGPresentationCustomColors.h"

#import <pthread.h>
#include <stdlib.h>
#import <Security/Security.h>

#import "../submodules/LegacyComponents/LegacyComponents/TGDateUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageInfo.h"

#import "TGPresentation.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

NSString *const TGOnegramSettingsDidChangeNotification = @"TGOnegramSettingsDidChangeNotification";
NSString *const TGOnegramSettingsChangedKey = @"key";

NSString *const TGOnegramSecretTranslatorDeepLKey = @"Onegram.Translator.DeepLKey";
NSString *const TGOnegramSecretTranslatorLLMKey = @"Onegram.Translator.LLMKey";
NSString *const TGOnegramSettingGeneralShowSeconds = @"Onegram.General.ShowSeconds";
NSString *const TGOnegramSettingGeneralTimeZoneManual = @"Onegram.General.TimeZoneManual";
NSString *const TGOnegramSettingGeneralTimeZoneOffset = @"Onegram.General.TimeZoneOffset";
NSString *const TGOnegramSettingGeneralExactNumbers = @"Onegram.General.ExactNumbers";
NSString *const TGOnegramSettingGeneralExactLastSeen = @"Onegram.General.ExactLastSeen";
NSString *const TGOnegramSettingGeneralFilterZalgo = @"Onegram.General.FilterZalgo";
NSString *const TGOnegramSettingGeneralNewChats = @"Onegram.General.NewChats";
NSString *const TGOnegramSettingGeneralHidePhone = @"Onegram.General.HidePhone";
NSString *const TGOnegramSettingInterfaceModern = @"Onegram.Interface.Modern";
NSString *const TGOnegramSettingGeneralShowPeerIds = @"Onegram.General.ShowPeerIds";
NSString *const TGOnegramSettingGeneralHideArchive = @"Onegram.General.HideArchive";
NSString *const TGOnegramSettingGeneralDisableUnarchiveSwipe = @"Onegram.General.DisableUnarchiveSwipe";
NSString *const TGOnegramSettingTranslatorShowButton = @"Onegram.Translator.ShowButton";
NSString *const TGOnegramSettingTranslatorProvider = @"Onegram.Translator.Provider";
NSString *const TGOnegramSettingTranslatorTargetLanguage = @"Onegram.Translator.TargetLanguage";
NSString *const TGOnegramSettingTranslatorSkipLanguages = @"Onegram.Translator.SkipLanguages";
NSString *const TGOnegramSettingTranslatorLLMEndpoint = @"Onegram.Translator.LLMEndpoint";
NSString *const TGOnegramSettingTranslatorLLMModel = @"Onegram.Translator.LLMModel";
NSString *const TGOnegramSettingChatListCompact = @"Onegram.ChatList.Compact";
NSString *const TGOnegramSettingChatListTitleMode = @"Onegram.ChatList.TitleMode";
NSString *const TGOnegramSettingChatListCustomTitle = @"Onegram.ChatList.CustomTitle";
NSString *const TGOnegramSettingChatListHideSearch = @"Onegram.ChatList.HideSearch";
NSString *const TGOnegramSettingChatListHideAllChatsTab = @"Onegram.ChatList.HideAllChatsTab";
NSString *const TGOnegramSettingMessagesBubbleRadius = @"Onegram.Messages.BubbleRadius";
NSString *const TGOnegramSettingMessagesStickerScale = @"Onegram.Messages.StickerScale";
NSString *const TGOnegramSettingMessagesHideStickerTime = @"Onegram.Messages.HideStickerTime";
NSString *const TGOnegramSettingMessagesAnimatedEmoji = @"Onegram.Messages.AnimatedEmoji";
NSString *const TGOnegramSettingMessagesAnimatedStickers = @"Onegram.Messages.AnimatedStickers";
NSString *const TGOnegramSettingMessagesReplyAuthorColor = @"Onegram.Messages.ReplyAuthorColor";
NSString *const TGOnegramSettingMessagesDoubleTapIncoming = @"Onegram.Messages.DoubleTapIncoming";
NSString *const TGOnegramSettingMessagesDoubleTapOutgoing = @"Onegram.Messages.DoubleTapOutgoing";
NSString *const TGOnegramSettingMessagesQuickReaction = @"Onegram.Messages.QuickReaction";
NSString *const TGOnegramSettingMessagesEditedPencil = @"Onegram.Messages.EditedPencil";
NSString *const TGOnegramSettingMessagesMenuScale = @"Onegram.Messages.MenuScale";
NSString *const TGOnegramSettingMessagesMenuHiddenActions = @"Onegram.Messages.MenuHiddenActions";
NSString *const TGOnegramSettingAppearanceAvatarRoundness = @"Onegram.Appearance.AvatarRoundness";
NSString *const TGOnegramSettingAppearanceRoundChatAvatar = @"Onegram.Appearance.RoundChatAvatar";
NSString *const TGOnegramSettingAppearanceSnowfall = @"Onegram.Appearance.Snowfall";
NSString *const TGOnegramSettingAppearanceNightSurface = @"Onegram.Appearance.NightSurface";
NSString *const TGOnegramSettingAppearanceSeparators = @"Onegram.Appearance.Separators";
NSString *const TGOnegramSettingConfirmCalls = @"Onegram.Confirm.Calls";
NSString *const TGOnegramSettingConfirmLinks = @"Onegram.Confirm.Links";
NSString *const TGOnegramSettingConfirmVoiceMessages = @"Onegram.Confirm.VoiceMessages";
NSString *const TGOnegramSettingMessagesDeleteForMe = @"Onegram.Messages.DeleteForMe";
NSString *const TGOnegramSettingMessagesNoLinkPreview = @"Onegram.Messages.NoLinkPreview";

typedef struct {
    NSInteger minimum;
    NSInteger maximum;
} TGOnegramSettingRange;

static pthread_mutex_t TGOnegramSettingsMutex = PTHREAD_MUTEX_INITIALIZER;

static NSValue *TGOnegramSettingRangeValue(NSInteger minimum, NSInteger maximum)
{
    TGOnegramSettingRange range = { minimum, maximum };
    return [NSValue valueWithBytes:&range objCType:@encode(TGOnegramSettingRange)];
}

static bool TGOnegramIsStackedMark(unichar character)
{
    return (character >= 0x0300 && character <= 0x036F) || (character >= 0x0483 && character <= 0x0489) || (character >= 0x1AB0 && character <= 0x1AFF) || (character >= 0x1DC0 && character <= 0x1DFF) || (character >= 0x20D0 && character <= 0x20FF) || (character >= 0xFE20 && character <= 0xFE2F);
}

NSString *TGOnegramDisplayText(NSString *text)
{
    if (text.length < 4 || ![TGOnegramSettings boolForKey:TGOnegramSettingGeneralFilterZalgo])
        return text;
    NSUInteger length = text.length;
    unichar *buffer = (unichar *)malloc(sizeof(unichar) * length);
    if (buffer == NULL)
        return text;
    [text getCharacters:buffer range:NSMakeRange(0, length)];
    bool changed = false;
    NSUInteger run = 0;
    for (NSUInteger index = 0; index < length; index++)
    {
        if (TGOnegramIsStackedMark(buffer[index]))
        {
            run++;
            if (run > 2)
            {
                buffer[index] = 0x2060;
                changed = true;
            }
        }
        else
        {
            run = 0;
        }
    }
    NSString *result = changed ? [[NSString alloc] initWithCharacters:buffer length:length] : text;
    free(buffer);
    return result;
}

NSString *TGOnegramOwnPhoneDisplay(NSString *formattedPhone)
{
    if (formattedPhone.length == 0 || ![TGOnegramSettings boolForKey:TGOnegramSettingGeneralHidePhone])
        return formattedPhone;
    NSMutableString *result = [[NSMutableString alloc] init];
    for (NSUInteger index = 0; index < formattedPhone.length; index++)
    {
        unichar character = [formattedPhone characterAtIndex:index];
        if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:character])
            [result appendString:@" "];
        else
            [result appendString:@"\u2022"];
    }
    return result;
}

int32_t TGOnegramDatacenterForPhotoUrl(NSString *photoUrl)
{
    if (photoUrl.length == 0)
        return 0;
    if ([photoUrl hasPrefix:@"peerphoto:"])
    {
        NSArray *components = [photoUrl componentsSeparatedByString:@":"];
        return components.count > 1 ? [components[1] intValue] : 0;
    }
    int datacenterId = 0;
    int64_t volumeId = 0;
    int localId = 0;
    int64_t secret = 0;
    return extractFileUrlComponents(photoUrl, &datacenterId, &volumeId, &localId, &secret) ? datacenterId : 0;
}

NSString *TGOnegramEditedLabel(void)
{
    return [TGOnegramSettings boolForKey:TGOnegramSettingMessagesEditedPencil] ? @"\u270E" : TGLocalized(@"Conversation.MessageEditedLabel");
}

bool TGOnegramSettingAffectsMessageAppearance(NSString *key)
{
    static NSSet *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        keys = [[NSSet alloc] initWithObjects:TGOnegramSettingMessagesAnimatedEmoji, TGOnegramSettingMessagesAnimatedStickers, TGOnegramSettingMessagesStickerScale, TGOnegramSettingMessagesHideStickerTime, TGOnegramSettingMessagesReplyAuthorColor, TGOnegramSettingMessagesEditedPencil, nil];
    });
    return key != nil && [keys containsObject:key];
}

bool TGOnegramUsesExactNumbers(void)
{
    return [TGOnegramSettings boolForKey:TGOnegramSettingGeneralExactNumbers];
}

bool TGOnegramModernInterfaceAvailable(void)
{
    return TGCurrentInterfaceStyle() == 0;
}

bool TGOnegramModernInterfaceEnabled(void)
{
    return TGOnegramModernInterfaceAvailable() && [TGOnegramSettings boolForKey:TGOnegramSettingInterfaceModern];
}

NSString *TGOnegramExactCountString(int64_t count)
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.usesGroupingSeparator = true;
    });
    @synchronized (formatter)
    {
        return [formatter stringFromNumber:@(count)] ?: [[NSString alloc] initWithFormat:@"%lld", count];
    }
}

@implementation TGOnegramSettings

+ (void)startApplyingRuntimeSettings
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        [self applyRuntimeSettings];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(runtimeSettingsChanged:) name:TGOnegramSettingsDidChangeNotification object:nil];
    });
}

+ (void)runtimeSettingsChanged:(NSNotification *)notification
{
    [self applyRuntimeSettings];
    [self runtimeSettingChanged:notification.userInfo[TGOnegramSettingsChangedKey]];
}

+ (void)runtimeSettingChanged:(NSString *)key
{
    if ([key isEqualToString:TGOnegramSettingMessagesBubbleRadius])
        [TGPresentation refreshAssets];
    else if ([key isEqualToString:TGOnegramSettingAppearanceNightSurface] || [key isEqualToString:TGOnegramSettingAppearanceSeparators])
        [TGPresentation reloadCustomColors];
}

+ (void)applyRuntimeSettings
{
    [TGDateUtils setShowsSeconds:[self boolForKey:TGOnegramSettingGeneralShowSeconds]];
    [TGDateUtils setPrefersExactLastSeen:[self boolForKey:TGOnegramSettingGeneralExactLastSeen]];
    [TGDateUtils setTimeZoneOffsetOverride:[self boolForKey:TGOnegramSettingGeneralTimeZoneManual] minutes:[self integerForKey:TGOnegramSettingGeneralTimeZoneOffset]];
    NSInteger roundness = [self integerForKey:TGOnegramSettingAppearanceAvatarRoundness];
    [TGLetteredAvatarView setCornerRoundness:roundness < 0 ? -1.0f : (CGFloat)roundness / 100.0f];
    [TGNightPresentationPallete setSurfaceTone:[self integerForKey:TGOnegramSettingAppearanceNightSurface]];
    [TGPresentationCustomColors setSeparatorsHidden:![self boolForKey:TGOnegramSettingAppearanceSeparators]];
}

+ (NSDictionary *)defaults
{
    static NSDictionary *defaults = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        defaults = @{
            TGOnegramSettingGeneralShowSeconds: @false,
            TGOnegramSettingGeneralTimeZoneManual: @false,
            TGOnegramSettingGeneralTimeZoneOffset: @0,
            TGOnegramSettingGeneralExactNumbers: @false,
            TGOnegramSettingGeneralExactLastSeen: @false,
            TGOnegramSettingGeneralFilterZalgo: @false,
            TGOnegramSettingGeneralHidePhone: @false,
            TGOnegramSettingGeneralNewChats: @true,
            TGOnegramSettingInterfaceModern: @false,
            TGOnegramSettingGeneralShowPeerIds: @false,
            TGOnegramSettingGeneralHideArchive: @false,
            TGOnegramSettingGeneralDisableUnarchiveSwipe: @false,
            TGOnegramSettingTranslatorShowButton: @false,
            TGOnegramSettingTranslatorProvider: @0,
            TGOnegramSettingTranslatorTargetLanguage: @"",
            TGOnegramSettingTranslatorSkipLanguages: @[],
            TGOnegramSettingTranslatorLLMEndpoint: @"https://api.openai.com/v1",
            TGOnegramSettingTranslatorLLMModel: @"gpt-4o-mini",
            TGOnegramSettingChatListCompact: @false,
            TGOnegramSettingChatListTitleMode: @0,
            TGOnegramSettingChatListCustomTitle: @"",
            TGOnegramSettingChatListHideSearch: @false,
            TGOnegramSettingChatListHideAllChatsTab: @false,
            TGOnegramSettingMessagesBubbleRadius: @(-1),
            TGOnegramSettingMessagesStickerScale: @100,
            TGOnegramSettingMessagesHideStickerTime: @false,
            TGOnegramSettingMessagesAnimatedEmoji: @true,
            TGOnegramSettingMessagesAnimatedStickers: @true,
            TGOnegramSettingMessagesReplyAuthorColor: @false,
            TGOnegramSettingMessagesDoubleTapIncoming: @0,
            TGOnegramSettingMessagesDoubleTapOutgoing: @0,
            TGOnegramSettingMessagesQuickReaction: @"❤️",
            TGOnegramSettingMessagesEditedPencil: @false,
            TGOnegramSettingMessagesMenuHiddenActions: @[],
            TGOnegramSettingMessagesMenuScale: @85,
            TGOnegramSettingAppearanceAvatarRoundness: @(-1),
            TGOnegramSettingAppearanceRoundChatAvatar: @false,
            TGOnegramSettingAppearanceSnowfall: @(-1),
            TGOnegramSettingAppearanceNightSurface: @0,
            TGOnegramSettingAppearanceSeparators: @true,
            TGOnegramSettingConfirmCalls: @false,
            TGOnegramSettingConfirmLinks: @0,
            TGOnegramSettingConfirmVoiceMessages: @false,
            TGOnegramSettingMessagesDeleteForMe: @false,
            TGOnegramSettingMessagesNoLinkPreview: @false
        };
    });
    return defaults;
}

+ (NSDictionary *)ranges
{
    static NSDictionary *ranges = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        ranges = @{
            TGOnegramSettingGeneralTimeZoneOffset: TGOnegramSettingRangeValue(-720, 840),
            TGOnegramSettingTranslatorProvider: TGOnegramSettingRangeValue(0, 3),
            TGOnegramSettingChatListTitleMode: TGOnegramSettingRangeValue(0, 3),
            TGOnegramSettingMessagesBubbleRadius: TGOnegramSettingRangeValue(-1, 16),
            TGOnegramSettingMessagesStickerScale: TGOnegramSettingRangeValue(50, 130),
            TGOnegramSettingMessagesMenuScale: TGOnegramSettingRangeValue(70, 110),
            TGOnegramSettingMessagesDoubleTapIncoming: TGOnegramSettingRangeValue(0, 5),
            TGOnegramSettingMessagesDoubleTapOutgoing: TGOnegramSettingRangeValue(0, 6),
            TGOnegramSettingAppearanceAvatarRoundness: TGOnegramSettingRangeValue(-1, 100),
            TGOnegramSettingAppearanceSnowfall: TGOnegramSettingRangeValue(-1, 1),
            TGOnegramSettingAppearanceNightSurface: TGOnegramSettingRangeValue(0, 4),
            TGOnegramSettingConfirmLinks: TGOnegramSettingRangeValue(0, 2)
        };
    });
    return ranges;
}

+ (NSMutableDictionary *)cache
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    return cache;
}

+ (id)valueForKey:(NSString *)key ofClass:(Class)valueClass
{
    pthread_mutex_lock(&TGOnegramSettingsMutex);
    NSMutableDictionary *cache = [self cache];
    id value = cache[key];
    if (value == nil)
    {
        value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        if (![value isKindOfClass:valueClass])
            value = [self defaults][key];
        if (value == nil)
            value = [NSNull null];
        cache[key] = value;
    }
    pthread_mutex_unlock(&TGOnegramSettingsMutex);
    return value == [NSNull null] ? nil : value;
}

+ (void)storeValue:(id)value forKey:(NSString *)key
{
    pthread_mutex_lock(&TGOnegramSettingsMutex);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (value == nil)
        [userDefaults removeObjectForKey:key];
    else
        [userDefaults setObject:value forKey:key];
    [[self cache] removeObjectForKey:key];
    pthread_mutex_unlock(&TGOnegramSettingsMutex);
    [userDefaults synchronize];

    void (^post)(void) = ^
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:TGOnegramSettingsDidChangeNotification object:nil userInfo:@{TGOnegramSettingsChangedKey: key}];
    };
    if ([NSThread isMainThread])
        post();
    else
        dispatch_async(dispatch_get_main_queue(), post);
}

+ (bool)boolForKey:(NSString *)key
{
    return [[self valueForKey:key ofClass:[NSNumber class]] boolValue];
}

+ (void)setBool:(bool)value forKey:(NSString *)key
{
    [self storeValue:@(value) forKey:key];
}

+ (NSInteger)clampedInteger:(NSInteger)value forKey:(NSString *)key
{
    NSValue *rangeValue = [self ranges][key];
    if (rangeValue == nil)
        return value;
    TGOnegramSettingRange range;
    [rangeValue getValue:&range];
    return MAX(range.minimum, MIN(range.maximum, value));
}

+ (NSInteger)integerForKey:(NSString *)key
{
    return [self clampedInteger:[[self valueForKey:key ofClass:[NSNumber class]] integerValue] forKey:key];
}

+ (void)setInteger:(NSInteger)value forKey:(NSString *)key
{
    [self storeValue:@([self clampedInteger:value forKey:key]) forKey:key];
}

+ (NSString *)stringForKey:(NSString *)key
{
    return [self valueForKey:key ofClass:[NSString class]] ?: @"";
}

+ (void)setString:(NSString *)value forKey:(NSString *)key
{
    [self storeValue:[value copy] forKey:key];
}

+ (NSArray *)arrayForKey:(NSString *)key
{
    return [self valueForKey:key ofClass:[NSArray class]] ?: @[];
}

+ (void)setArray:(NSArray *)value forKey:(NSString *)key
{
    [self storeValue:[value copy] forKey:key];
}

+ (void)resetValueForKey:(NSString *)key
{
    [self storeValue:nil forKey:key];
}

+ (NSMutableDictionary *)secretQueryForKey:(NSString *)key
{
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecAttrService] = @"Onegram.Settings";
    query[(__bridge id)kSecAttrAccount] = key;
    return query;
}

+ (NSString *)secretForKey:(NSString *)key
{
    NSMutableDictionary *query = [self secretQueryForKey:key];
    query[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess || result == NULL)
        return @"";
    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

+ (void)setSecret:(NSString *)secret forKey:(NSString *)key
{
    NSMutableDictionary *query = [self secretQueryForKey:key];
    SecItemDelete((__bridge CFDictionaryRef)query);
    if (secret.length != 0)
    {
        query[(__bridge id)kSecValueData] = [secret dataUsingEncoding:NSUTF8StringEncoding];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
#endif
        SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:TGOnegramSettingsDidChangeNotification object:nil userInfo:@{TGOnegramSettingsChangedKey: key}];
}

@end
