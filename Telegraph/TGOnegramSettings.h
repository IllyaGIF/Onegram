#import <Foundation/Foundation.h>

extern NSString *const TGOnegramSettingsDidChangeNotification;
extern NSString *const TGOnegramSettingsChangedKey;

extern NSString *const TGOnegramSecretTranslatorDeepLKey;
extern NSString *const TGOnegramSecretTranslatorLLMKey;
extern NSString *const TGOnegramSettingGeneralShowSeconds;
extern NSString *const TGOnegramSettingGeneralTimeZoneManual;
extern NSString *const TGOnegramSettingGeneralTimeZoneOffset;
extern NSString *const TGOnegramSettingGeneralExactNumbers;
extern NSString *const TGOnegramSettingGeneralExactLastSeen;
extern NSString *const TGOnegramSettingGeneralFilterZalgo;
extern NSString *const TGOnegramSettingGeneralHidePhone;
extern NSString *const TGOnegramSettingGeneralNewChats;
extern NSString *const TGOnegramSettingGeneralMessageMenuStyle;
extern NSString *const TGOnegramSettingInterfaceModern;
extern NSString *const TGOnegramSettingGeneralShowPeerIds;
extern NSString *const TGOnegramSettingGeneralHideArchive;
extern NSString *const TGOnegramSettingGeneralDisableUnarchiveSwipe;
extern NSString *const TGOnegramSettingTranslatorShowButton;
extern NSString *const TGOnegramSettingTranslatorProvider;
extern NSString *const TGOnegramSettingTranslatorTargetLanguage;
extern NSString *const TGOnegramSettingTranslatorSkipLanguages;
extern NSString *const TGOnegramSettingTranslatorLLMEndpoint;
extern NSString *const TGOnegramSettingTranslatorLLMModel;
extern NSString *const TGOnegramSettingChatListCompact;
extern NSString *const TGOnegramSettingChatListTitleMode;
extern NSString *const TGOnegramSettingChatListCustomTitle;
extern NSString *const TGOnegramSettingChatListHideSearch;
extern NSString *const TGOnegramSettingChatListHideAllChatsTab;
extern NSString *const TGOnegramSettingChatListFolderTags;
extern NSString *const TGOnegramSettingMessagesBubbleRadius;
extern NSString *const TGOnegramSettingMessagesStickerScale;
extern NSString *const TGOnegramSettingMessagesHideStickerTime;
extern NSString *const TGOnegramSettingMessagesAnimatedEmoji;
extern NSString *const TGOnegramSettingMessagesAnimatedStickers;
extern NSString *const TGOnegramSettingMessagesReplyAuthorColor;
extern NSString *const TGOnegramSettingMessagesDoubleTapIncoming;
extern NSString *const TGOnegramSettingMessagesDoubleTapOutgoing;
extern NSString *const TGOnegramSettingMessagesQuickReaction;
extern NSString *const TGOnegramSettingMessagesEditedPencil;
extern NSString *const TGOnegramSettingMessagesMenuHiddenActions;
extern NSString *const TGOnegramSettingMessagesMenuScale;
extern NSString *const TGOnegramSettingAppearanceAvatarRoundness;
extern NSString *const TGOnegramSettingAppearanceRoundChatAvatar;
extern NSString *const TGOnegramSettingAppearanceSnowfall;
extern NSString *const TGOnegramSettingAppearanceNightSurface;
extern NSString *const TGOnegramSettingAppearanceSeparators;
extern NSString *const TGOnegramSettingConfirmCalls;
extern NSString *const TGOnegramSettingConfirmLinks;
extern NSString *const TGOnegramSettingConfirmVoiceMessages;
extern NSString *const TGOnegramSettingMessagesDeleteForMe;
extern NSString *const TGOnegramSettingMessagesNoLinkPreview;

@interface TGOnegramSettings : NSObject

+ (void)startApplyingRuntimeSettings;

+ (bool)boolForKey:(NSString *)key;
+ (void)setBool:(bool)value forKey:(NSString *)key;

+ (NSInteger)integerForKey:(NSString *)key;
+ (void)setInteger:(NSInteger)value forKey:(NSString *)key;

+ (NSString *)stringForKey:(NSString *)key;
+ (void)setString:(NSString *)value forKey:(NSString *)key;

+ (NSArray *)arrayForKey:(NSString *)key;
+ (void)setArray:(NSArray *)value forKey:(NSString *)key;

+ (void)resetValueForKey:(NSString *)key;

+ (NSString *)secretForKey:(NSString *)key;
+ (void)setSecret:(NSString *)secret forKey:(NSString *)key;

@end

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGOnegramDisplayText(NSString *text);
NSString *TGOnegramEditedLabel(void);
bool TGOnegramSettingAffectsMessageAppearance(NSString *key);
NSString *TGOnegramOwnPhoneDisplay(NSString *formattedPhone);
bool TGOnegramUsesExactNumbers(void);
bool TGOnegramModernInterfaceAvailable(void);
bool TGOnegramModernInterfaceEnabled(void);
int32_t TGOnegramDatacenterForPhotoUrl(NSString *photoUrl);
NSString *TGOnegramExactCountString(int64_t count);

#ifdef __cplusplus
}
#endif
