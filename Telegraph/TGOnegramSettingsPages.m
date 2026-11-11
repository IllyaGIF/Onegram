#import "TGOnegramSettingsPages.h"
#import "TGAppDelegate.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGSwitchCollectionItem.h"
#import "TGOnegramSettings.h"
#import "TGTelegramNetworking.h"
#import "TGCustomAlertView.h"
#import "TLRPCmessages_sendMessage_manual.h"
#import "TLBool.h"
#import "TGMessageContextMenu.h"
#import "TGOnegramSliderCollectionItem.h"
#import "TGOnegramTranslator.h"
#import "TGCrashReportCenter.h"
#import "TGOnegramAvatarPreviewCollectionItem.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGReplyMessageMediaAttachment.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"
#import "TGAppearancePreviewCollectionItem.h"
#import "TGAnimatedEmojiStore.h"
#import "TGOnegramUpdateController.h"
#import "TGPluginsController.h"

NSArray *TGOnegramDoubleTapActions(bool outgoing)
{
    NSArray *actions = @[@"none", @"reply", @"reaction", @"forward", @"copy", @"translate"];
    return outgoing ? [actions arrayByAddingObject:@"edit"] : actions;
}

NSArray *TGOnegramMenuActionIdentifiers(void)
{
    return @[@"reply", @"copy", @"forward", @"pin", @"copyLink", @"reaction", @"select", @"report"];
}

static NSString *TGOnegramMenuActionTitle(NSString *identifier)
{
    return TGLocalized([@"OnegramSettings.Menu." stringByAppendingString:identifier]);
}

static NSString *TGOnegramDoubleTapTitle(NSString *identifier)
{
    return TGLocalized([@"OnegramSettings.DoubleTap." stringByAppendingString:identifier]);
}

static NSString *TGOnegramTimeZoneTitle(NSInteger minutes)
{
    NSInteger absolute = minutes < 0 ? -minutes : minutes;
    return [[NSString alloc] initWithFormat:@"UTC%@%02d:%02d", minutes < 0 ? @"−" : @"+", (int)(absolute / 60), (int)(absolute % 60)];
}

@interface TGOnegramRootSettingsController () <TGInterfaceRebuildRestorable>

@end

@implementation TGOnegramRootSettingsController

- (instancetype)init
{
    return [super initWithTitle:TGLocalized(@"OnegramSettings.Title")];
}

- (UIViewController *)controllerForInterfaceRebuild
{
    TGOnegramRootSettingsController *controller = [[TGOnegramRootSettingsController alloc] init];
    controller.presentation = [TGPresentation current];
    return controller;
}

- (void)pushSettingsController:(TGOnegramSettingsController *)controller
{
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (NSArray *)buildSections
{
    __weak TGOnegramRootSettingsController *weakSelf = self;
    NSMutableArray *sections = [[NSMutableArray alloc] init];

    [sections addObject:[self sectionWithHeader:nil items:@[
        [self actionWithTitle:TGLocalized(@"OnegramSettings.General") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGOnegramGeneralSettingsController alloc] init]];
        }],
        [self actionWithTitle:TGLocalized(@"OnegramSettings.ChatList") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGOnegramChatListSettingsController alloc] init]];
        }],
        [self actionWithTitle:TGLocalized(@"OnegramSettings.Messages") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGOnegramMessagesSettingsController alloc] init]];
        }],
        [self actionWithTitle:TGLocalized(@"OnegramSettings.Confirmations") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGOnegramConfirmationsSettingsController alloc] init]];
        }]
    ] footer:nil]];

#if OG_PLUGINS_AVAILABLE
    [sections addObject:[self sectionWithHeader:nil items:@[
        [self actionWithTitle:TGLocalized(@"OnegramPlugins.Title") variant:nil pressed:^
        {
            [weakSelf pushSettingsController:[[TGPluginsController alloc] init]];
        }]
    ] footer:nil]];
#endif

    [sections addObject:[self sectionWithHeader:nil items:@[
        [self actionWithTitle:TGLocalized(@"OnegramUpdate.Title") variant:[TGOnegramUpdateController statusVariant] pressed:^
        {
            [weakSelf pushSettingsController:[[TGOnegramUpdateController alloc] init]];
        }]
    ] footer:nil]];


    if (TGCurrentInterfaceStyle() != 0)
    {
        TGOnegramAvatarPreviewCollectionItem *previewItem = [[TGOnegramAvatarPreviewCollectionItem alloc] init];
        TGOnegramSliderCollectionItem *roundnessItem = [self sliderWithTitle:TGLocalized(@"OnegramSettings.AvatarRoundness") key:TGOnegramSettingAppearanceAvatarRoundness minimumValue:-1 maximumValue:100 formatter:^NSString *(NSInteger value)
        {
            return value < 0 ? TGLocalized(@"OnegramSettings.Default") : [[NSString alloc] initWithFormat:@"%d%%", (int)value];
        }];
        __weak TGOnegramAvatarPreviewCollectionItem *weakPreviewItem = previewItem;
        roundnessItem.valueChanged = ^(NSInteger value)
        {
            [TGLetteredAvatarView setCornerRoundness:value < 0 ? -1.0f : (CGFloat)value / 100.0f];
            [weakPreviewItem refresh];
        };
        [sections addObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.Avatars") items:@[previewItem, roundnessItem] footer:TGLocalized(@"OnegramSettings.AvatarsInfo")]];
    }

    return sections;
}

@end

@implementation TGOnegramGeneralSettingsController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGAutoDownloadPreferencesDidChangeNotification object:nil];
}

- (instancetype)init
{
    self = [super initWithTitle:TGLocalized(@"OnegramSettings.General")];
    if (self != nil)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automaticDownloadSettingsChanged:) name:TGAutoDownloadPreferencesDidChangeNotification object:nil];
    return self;
}

- (void)automaticDownloadSettingsChanged:(NSNotification *)notification
{
    __weak TGOnegramGeneralSettingsController *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong TGOnegramGeneralSettingsController *strongSelf = weakSelf;
        if (strongSelf.isViewLoaded && strongSelf.view.window != nil)
            [strongSelf rebuild];
    });
}

- (bool)rebuildsForSettingKey:(NSString *)key
{
    return [key hasPrefix:@"Onegram.Translator."] || [key isEqualToString:TGOnegramSettingGeneralTimeZoneManual] || [key isEqualToString:TGOnegramSettingGeneralTimeZoneOffset] || [key isEqualToString:TGOnegramSettingGeneralNewChats] || [key isEqualToString:TGOnegramSettingGeneralMessageMenuStyle];
}

- (NSArray *)buildSections
{
    __weak TGOnegramGeneralSettingsController *weakSelf = self;
    NSMutableArray *sections = [[NSMutableArray alloc] init];

    [sections addObject:[self sectionWithHeader:nil items:@[
        [self switchWithTitle:TGLocalized(@"ChatSettings.AutoDownloadEnabled") value:!TGAppDelegateInstance.autoDownloadPreferences.disabled toggled:^(bool value)
        {
            TGAutoDownloadPreferences *preferences = TGAppDelegateInstance.autoDownloadPreferences;
            if (value && (preferences.photos | preferences.videos | preferences.documents | preferences.gifs | preferences.voiceMessages | preferences.videoMessages) == TGAutoDownloadModeNone)
                preferences = [TGAutoDownloadPreferences defaultPreferences];
            TGAppDelegateInstance.autoDownloadPreferences = [preferences updateDisabled:!value];
        }]
    ] footer:TGLocalized(@"OnegramSettings.AutoDownload.AutomaticInfo")]];

    NSMutableArray *translatorItems = [[NSMutableArray alloc] init];
    [translatorItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.TranslateButton") key:TGOnegramSettingTranslatorShowButton description:TGLocalized(@"OnegramSettings.TranslateButtonInfo")]];
    [translatorItems addObject:[self choiceWithTitle:TGLocalized(@"OnegramSettings.TranslateProvider") key:TGOnegramSettingTranslatorProvider options:[TGOnegramTranslator providerTitles] description:TGLocalized(@"OnegramSettings.TranslateProviderInfo")]];

    NSString *target = [TGOnegramSettings stringForKey:TGOnegramSettingTranslatorTargetLanguage];
    [translatorItems addObject:[self actionWithTitle:TGLocalized(@"OnegramSettings.TranslateTarget") variant:target.length == 0 ? TGLocalized(@"OnegramSettings.TranslateTargetApp") : [TGOnegramTranslator displayNameForLanguage:target] description:TGLocalized(@"OnegramSettings.TranslateTargetInfo") pressed:^
    {
        __strong TGOnegramGeneralSettingsController *strongSelf = weakSelf;
        NSArray *codes = [TGOnegramTranslator languageCodes];
        NSMutableArray *options = [[NSMutableArray alloc] initWithObjects:TGLocalized(@"OnegramSettings.TranslateTargetApp"), nil];
        for (NSString *code in codes)
            [options addObject:[TGOnegramTranslator displayNameForLanguage:code]];
        NSString *current = [TGOnegramSettings stringForKey:TGOnegramSettingTranslatorTargetLanguage];
        NSUInteger index = [codes indexOfObject:current];
        [strongSelf pushChoiceWithTitle:TGLocalized(@"OnegramSettings.TranslateTarget") options:options selectedIndex:current.length == 0 || index == NSNotFound ? 0 : (NSInteger)index + 1 footer:nil completion:^(NSInteger selected)
        {
            [TGOnegramSettings setString:selected <= 0 ? @"" : codes[(NSUInteger)selected - 1] forKey:TGOnegramSettingTranslatorTargetLanguage];
        }];
    }]];

    NSArray *skipped = [TGOnegramSettings arrayForKey:TGOnegramSettingTranslatorSkipLanguages];
    [translatorItems addObject:[self actionWithTitle:TGLocalized(@"OnegramSettings.TranslateSkip") variant:skipped.count == 0 ? TGLocalized(@"OnegramSettings.None") : [[NSString alloc] initWithFormat:@"%d", (int)skipped.count] description:TGLocalized(@"OnegramSettings.TranslateSkipInfo") pressed:^
    {
        __strong TGOnegramGeneralSettingsController *strongSelf = weakSelf;
        NSArray *codes = [TGOnegramTranslator languageCodes];
        NSMutableArray *options = [[NSMutableArray alloc] init];
        NSMutableIndexSet *selected = [[NSMutableIndexSet alloc] init];
        NSArray *current = [TGOnegramSettings arrayForKey:TGOnegramSettingTranslatorSkipLanguages];
        [codes enumerateObjectsUsingBlock:^(NSString *code, NSUInteger index, __unused BOOL *stop)
        {
            [options addObject:[TGOnegramTranslator displayNameForLanguage:code]];
            if ([current containsObject:code])
                [selected addIndex:index];
        }];
        [strongSelf pushMultipleChoiceWithTitle:TGLocalized(@"OnegramSettings.TranslateSkip") options:options selectedIndices:selected footer:TGLocalized(@"OnegramSettings.TranslateSkipInfo") completion:^(NSIndexSet *indices)
        {
            NSMutableArray *values = [[NSMutableArray alloc] init];
            [indices enumerateIndexesUsingBlock:^(NSUInteger index, __unused BOOL *stop)
            {
                [values addObject:codes[index]];
            }];
            [TGOnegramSettings setArray:values forKey:TGOnegramSettingTranslatorSkipLanguages];
        }];
    }]];

    TGOnegramTranslatorProvider provider = (TGOnegramTranslatorProvider)[TGOnegramSettings integerForKey:TGOnegramSettingTranslatorProvider];
    if (provider == TGOnegramTranslatorProviderDeepL || provider == TGOnegramTranslatorProviderLLM)
    {
        NSString *secretKey = provider == TGOnegramTranslatorProviderDeepL ? TGOnegramSecretTranslatorDeepLKey : TGOnegramSecretTranslatorLLMKey;
        bool hasKey = [TGOnegramSettings secretForKey:secretKey].length != 0;
        [translatorItems addObject:[self actionWithTitle:TGLocalized(@"OnegramSettings.TranslateKey") variant:hasKey ? TGLocalized(@"OnegramSettings.KeySet") : TGLocalized(@"OnegramSettings.KeyMissing") description:TGLocalized(@"OnegramSettings.TranslateKeyInfo") pressed:^
        {
            __strong TGOnegramGeneralSettingsController *strongSelf = weakSelf;
            [strongSelf pushTextInputWithTitle:TGLocalized(@"OnegramSettings.TranslateKey") text:[TGOnegramSettings secretForKey:secretKey] placeholder:TGLocalized(@"OnegramSettings.TranslateKeyPlaceholder") secure:true footer:TGLocalized(provider == TGOnegramTranslatorProviderDeepL ? @"OnegramSettings.TranslateKeyDeepLInfo" : @"OnegramSettings.TranslateKeyLLMInfo") completion:^(NSString *text)
            {
                [TGOnegramSettings setSecret:text forKey:secretKey];
            }];
        }]];
    }
    if (provider == TGOnegramTranslatorProviderLLM)
    {
        [translatorItems addObject:[self actionWithTitle:TGLocalized(@"OnegramSettings.TranslateEndpoint") variant:[[NSURL URLWithString:[TGOnegramSettings stringForKey:TGOnegramSettingTranslatorLLMEndpoint]] host] ?: @"" description:TGLocalized(@"OnegramSettings.TranslateEndpointInfo") pressed:^
        {
            __strong TGOnegramGeneralSettingsController *strongSelf = weakSelf;
            [strongSelf pushTextInputWithTitle:TGLocalized(@"OnegramSettings.TranslateEndpoint") text:[TGOnegramSettings stringForKey:TGOnegramSettingTranslatorLLMEndpoint] placeholder:@"https://api.openai.com/v1" secure:false footer:TGLocalized(@"OnegramSettings.TranslateEndpointInfo") completion:^(NSString *text)
            {
                if (text.length != 0)
                    [TGOnegramSettings setString:text forKey:TGOnegramSettingTranslatorLLMEndpoint];
            }];
        }]];
        [translatorItems addObject:[self actionWithTitle:TGLocalized(@"OnegramSettings.TranslateModel") variant:[TGOnegramSettings stringForKey:TGOnegramSettingTranslatorLLMModel] pressed:^
        {
            __strong TGOnegramGeneralSettingsController *strongSelf = weakSelf;
            [strongSelf pushTextInputWithTitle:TGLocalized(@"OnegramSettings.TranslateModel") text:[TGOnegramSettings stringForKey:TGOnegramSettingTranslatorLLMModel] placeholder:@"gpt-4o-mini" secure:false footer:nil completion:^(NSString *text)
            {
                if (text.length != 0)
                    [TGOnegramSettings setString:text forKey:TGOnegramSettingTranslatorLLMModel];
            }];
        }]];
    }
    [sections addObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.TranslateHeader") items:translatorItems footer:nil]];

    bool manualZone = [TGOnegramSettings boolForKey:TGOnegramSettingGeneralTimeZoneManual];
    NSString *zoneVariant = manualZone ? TGOnegramTimeZoneTitle([TGOnegramSettings integerForKey:TGOnegramSettingGeneralTimeZoneOffset]) : TGLocalized(@"OnegramSettings.TimeZoneAutomatic");
    TGOnegramActionCollectionItem *zoneItem = [self actionWithTitle:TGLocalized(@"OnegramSettings.TimeZone") variant:zoneVariant description:TGLocalized(@"OnegramSettings.TimeZoneInfo") pressed:^
    {
        __strong TGOnegramGeneralSettingsController *strongSelf = weakSelf;
        NSMutableArray *offsets = [[NSMutableArray alloc] init];
        NSMutableArray *options = [[NSMutableArray alloc] initWithObjects:TGLocalized(@"OnegramSettings.TimeZoneAutomatic"), nil];
        for (NSInteger minutes = -12 * 60; minutes <= 14 * 60; minutes += 15)
        {
            [offsets addObject:@(minutes)];
            [options addObject:TGOnegramTimeZoneTitle(minutes)];
        }
        NSInteger selected = 0;
        if ([TGOnegramSettings boolForKey:TGOnegramSettingGeneralTimeZoneManual])
        {
            NSUInteger index = [offsets indexOfObject:@([TGOnegramSettings integerForKey:TGOnegramSettingGeneralTimeZoneOffset])];
            selected = index == NSNotFound ? 0 : (NSInteger)index + 1;
        }
        [strongSelf pushChoiceWithTitle:TGLocalized(@"OnegramSettings.TimeZone") options:options selectedIndex:selected footer:TGLocalized(@"OnegramSettings.TimeZoneInfo") completion:^(NSInteger index)
        {
            if (index > 0)
                [TGOnegramSettings setInteger:[offsets[(NSUInteger)index - 1] integerValue] forKey:TGOnegramSettingGeneralTimeZoneOffset];
            [TGOnegramSettings setBool:index > 0 forKey:TGOnegramSettingGeneralTimeZoneManual];
        }];
    }];
    if (TGOnegramModernInterfaceAvailable())
        [sections insertObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.Interface") items:@[
            [self switchWithTitle:TGLocalized(@"OnegramSettings.ModernInterface") key:TGOnegramSettingInterfaceModern description:TGLocalized(@"OnegramSettings.ModernInterfaceInfo")]
        ] footer:nil] atIndex:0];

    NSMutableArray *generalItems = [[NSMutableArray alloc] init];
    [generalItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.NewChats") key:TGOnegramSettingGeneralNewChats description:TGLocalized(@"OnegramSettings.NewChatsInfo")]];
    if ([TGOnegramSettings boolForKey:TGOnegramSettingGeneralNewChats])
        [generalItems addObject:[self choiceWithTitle:TGLocalized(@"OnegramSettings.MessageMenuStyle") key:TGOnegramSettingGeneralMessageMenuStyle options:@[TGLocalized(@"OnegramSettings.MessageMenuStyleIOS"), TGLocalized(@"OnegramSettings.MessageMenuStyleAndroid")] description:TGLocalized(@"OnegramSettings.MessageMenuStyleInfo")]];
    [generalItems addObjectsFromArray:@[
        [self switchWithTitle:TGLocalized(@"Appearance.NewGestures") value:[[NSUserDefaults standardUserDefaults] boolForKey:@"TGIOS6NewChatListGestures"] toggled:^(bool value)
        {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:value forKey:@"TGIOS6NewChatListGestures"];
            [defaults synchronize];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"TGIOS6NewChatListGesturesChanged" object:nil];
        }],
        [self switchWithTitle:TGLocalized(@"OnegramSettings.ShowSeconds") key:TGOnegramSettingGeneralShowSeconds description:TGLocalized(@"OnegramSettings.ShowSecondsInfo")],
        zoneItem,
        [self switchWithTitle:TGLocalized(@"OnegramSettings.ExactNumbers") key:TGOnegramSettingGeneralExactNumbers description:TGLocalized(@"OnegramSettings.ExactNumbersInfo")],
        [self switchWithTitle:TGLocalized(@"OnegramSettings.ExactLastSeen") key:TGOnegramSettingGeneralExactLastSeen description:TGLocalized(@"OnegramSettings.ExactLastSeenInfo")],
        [self switchWithTitle:TGLocalized(@"OnegramSettings.FilterZalgo") key:TGOnegramSettingGeneralFilterZalgo description:TGLocalized(@"OnegramSettings.FilterZalgoInfo")]
    ]];
    [sections addObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.General") items:generalItems footer:nil]];

    TGMessageMenuPreviewCollectionItem *menuPreview = [[TGMessageMenuPreviewCollectionItem alloc] init];
    menuPreview.menuScale = (CGFloat)[TGOnegramSettings integerForKey:TGOnegramSettingMessagesMenuScale] / 100.0f;
    __weak TGMessageMenuPreviewCollectionItem *weakMenuPreview = menuPreview;
    TGOnegramSliderCollectionItem *menuSize = [self sliderWithTitle:TGLocalized(@"OnegramSettings.MenuSize") key:TGOnegramSettingMessagesMenuScale minimumValue:70 maximumValue:130 formatter:^NSString *(NSInteger value)
    {
        return [NSString stringWithFormat:@"%ld%%", (long)value];
    }];
    menuSize.step = 5;
    menuSize.valueChanged = ^(NSInteger value)
    {
        weakMenuPreview.menuScale = (CGFloat)value / 100.0f;
    };
    [sections addObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.MessageMenu") items:@[menuPreview, menuSize] footer:TGLocalized(@"OnegramSettings.MenuSizeInfo")]];

    [sections addObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.Profile") items:@[
        [self switchWithTitle:TGLocalized(@"OnegramSettings.HidePhone") key:TGOnegramSettingGeneralHidePhone description:TGLocalized(@"OnegramSettings.HidePhoneInfo")],
        [self switchWithTitle:TGLocalized(@"OnegramSettings.ShowPeerIds") key:TGOnegramSettingGeneralShowPeerIds description:TGLocalized(@"OnegramSettings.ShowPeerIdsInfo")]
    ] footer:nil]];

    [sections addObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.Archive") items:@[
        [self switchWithTitle:TGLocalized(@"OnegramSettings.HideArchive") key:TGOnegramSettingGeneralHideArchive description:TGLocalized(@"OnegramSettings.HideArchiveInfo")],
        [self switchWithTitle:TGLocalized(@"OnegramSettings.DisableUnarchiveSwipe") key:TGOnegramSettingGeneralDisableUnarchiveSwipe description:TGLocalized(@"OnegramSettings.DisableUnarchiveSwipeInfo")]
    ] footer:nil]];

    TGSwitchCollectionItem *crashReportsItem = [self switchWithTitle:TGLocalized(@"OnegramSettings.CrashReportsToggle") value:[TGCrashReportCenter reportsEnabled] toggled:^(bool value)
    {
        [TGCrashReportCenter setReportsEnabled:value];
    }];
    crashReportsItem.descriptionText = TGLocalized(@"OnegramSettings.CrashReportsInfo");
    [sections addObject:[self sectionWithHeader:TGLocalized(@"OnegramSettings.CrashReports") items:@[crashReportsItem] footer:nil]];

    return sections;
}

@end

@implementation TGOnegramChatListSettingsController

- (instancetype)init
{
    return [super initWithTitle:TGLocalized(@"OnegramSettings.ChatList")];
}

- (bool)rebuildsForSettingKey:(NSString *)key
{
    return [key isEqualToString:TGOnegramSettingChatListTitleMode] || [key isEqualToString:TGOnegramSettingChatListCustomTitle];
}

- (NSArray *)buildSections
{
    __weak TGOnegramChatListSettingsController *weakSelf = self;
    NSArray *titleOptions = @[TGLocalized(@"OnegramSettings.ChatListTitleChats"), TGLocalized(@"OnegramSettings.ChatListTitleUsername"), TGLocalized(@"OnegramSettings.ChatListTitleName"), TGLocalized(@"OnegramSettings.ChatListTitleCustom")];
    NSInteger titleMode = [TGOnegramSettings integerForKey:TGOnegramSettingChatListTitleMode];
    NSString *custom = [TGOnegramSettings stringForKey:TGOnegramSettingChatListCustomTitle];
    TGOnegramActionCollectionItem *titleItem = [self choiceWithTitle:TGLocalized(@"OnegramSettings.ChatListTitle") key:TGOnegramSettingChatListTitleMode options:titleOptions description:TGLocalized(@"OnegramSettings.ChatListTitleInfo")];
    NSMutableArray *headerItems = [[NSMutableArray alloc] initWithObjects:titleItem, nil];
    if (titleMode == 3)
    {
        [headerItems addObject:[self actionWithTitle:TGLocalized(@"OnegramSettings.ChatListTitleText") variant:custom.length != 0 ? custom : TGLocalized(@"OnegramSettings.KeyMissing") pressed:^
        {
            __strong TGOnegramChatListSettingsController *strongSelf = weakSelf;
            [strongSelf pushTextInputWithTitle:TGLocalized(@"OnegramSettings.ChatListTitleText") text:[TGOnegramSettings stringForKey:TGOnegramSettingChatListCustomTitle] placeholder:TGLocalized(@"OnegramSettings.ChatListTitlePlaceholder") secure:false footer:nil completion:^(NSString *text)
            {
                [TGOnegramSettings setString:text forKey:TGOnegramSettingChatListCustomTitle];
            }];
        }]];
    }
    [headerItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.ChatListHideSearch") key:TGOnegramSettingChatListHideSearch description:TGLocalized(@"OnegramSettings.ChatListHideSearchInfo")]];
    [headerItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.ChatListHideAllChats") key:TGOnegramSettingChatListHideAllChatsTab description:TGLocalized(@"OnegramSettings.ChatListHideAllChatsInfo")]];

    return @[
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.ChatListView") items:@[
            [self switchWithTitle:TGLocalized(@"OnegramSettings.ChatListCompact") key:TGOnegramSettingChatListCompact description:TGLocalized(@"OnegramSettings.ChatListCompactInfo")]
        ] footer:nil],
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.ChatListHeader") items:headerItems footer:nil]
    ];
}

@end

static TGDocumentMediaAttachment *TGOnegramPreviewSticker(void)
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"OnegramPreviewSticker" ofType:@"tgs"];
    if (path.length == 0)
        return nil;
    TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] init];
    document.localDocumentId = 0x4f6e6567726d01LL;
    document.mimeType = @"application/x-tgsticker";
    document.documentUri = [[NSURL fileURLWithPath:path] absoluteString];
    document.attributes = @[
        [[TGDocumentAttributeFilename alloc] initWithFilename:@"OnegramPreviewSticker.tgs"],
        [[TGDocumentAttributeImageSize alloc] initWithSize:CGSizeMake(512.0f, 512.0f)],
        [[TGDocumentAttributeSticker alloc] initWithAlt:@"\U0001F44B" packReference:nil mask:nil]
    ];
    return document;
}

static TGMessage *TGOnegramPreviewMessage(int32_t mid, int32_t fromUid, bool outgoing, NSString *text, int32_t minutes)
{
    TGMessage *message = [[TGMessage alloc] init];
    message.mid = mid;
    message.fromUid = fromUid;
    message.outgoing = outgoing;
    message.text = text;
    message.date = 60 * minutes;
    message.deliveryState = TGMessageDeliveryStateDelivered;
    return message;
}

@interface TGOnegramMessagesSettingsController ()
{
    TGAppearancePreviewCollectionItem *_bubblePreviewItem;
    TGAppearancePreviewCollectionItem *_stickerPreviewItem;
    TGDocumentMediaAttachment *_previewSticker;
}

@end

@implementation TGOnegramMessagesSettingsController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGAnimatedEmojiStoreDidUpdateNotification object:nil];
}

- (instancetype)init
{
    self = [super initWithTitle:TGLocalized(@"OnegramSettings.Messages")];
    if (self != nil)
    {
        __weak TGOnegramMessagesSettingsController *weakSelf = self;
        void (^heightChanged)(void) = ^
        {
            __strong TGOnegramMessagesSettingsController *strongSelf = weakSelf;
            [strongSelf.collectionLayout invalidateLayout];
        };

        _bubblePreviewItem = [[TGAppearancePreviewCollectionItem alloc] init];
        _bubblePreviewItem.heightChanged = heightChanged;
        _bubblePreviewItem.messages = [self bubblePreviewMessages];

        _previewSticker = TGOnegramPreviewSticker();
        _stickerPreviewItem = [[TGAppearancePreviewCollectionItem alloc] init];
        _stickerPreviewItem.heightChanged = heightChanged;
        _stickerPreviewItem.messages = [self stickerPreviewMessages];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(animatedEmojiStoreUpdated:) name:TGAnimatedEmojiStoreDidUpdateNotification object:nil];
    }
    return self;
}

- (void)animatedEmojiStoreUpdated:(NSNotification *)__unused notification
{
    if ([TGOnegramSettings boolForKey:TGOnegramSettingMessagesAnimatedEmoji])
        _stickerPreviewItem.messages = [self stickerPreviewMessages];
}

- (NSArray *)bubblePreviewMessages
{
    TGMessage *replyMessage = TGOnegramPreviewMessage(1, 2, false, TGLocalized(@"OnegramSettings.PreviewReply"), 18 * 60 + 19);

    TGReplyMessageMediaAttachment *replyAttachment = [[TGReplyMessageMediaAttachment alloc] init];
    replyAttachment.replyMessageId = replyMessage.mid;
    replyAttachment.replyMessage = replyMessage;

    TGMessage *incomingMessage = TGOnegramPreviewMessage(2, 1, false, TGLocalized(@"OnegramSettings.PreviewIncoming"), 18 * 60 + 20);
    incomingMessage.mediaAttachments = @[replyAttachment];

    TGMessage *outgoingMessage = TGOnegramPreviewMessage(3, 2, true, TGLocalized(@"OnegramSettings.PreviewOutgoing"), 18 * 60 + 21);
    outgoingMessage.isEdited = true;
    outgoingMessage.editDate = outgoingMessage.date + 60;

    return @[outgoingMessage, incomingMessage];
}

- (NSArray *)stickerPreviewMessages
{
    TGMessage *emojiMessage = TGOnegramPreviewMessage(4, 1, false, @"\U0001F44D", 18 * 60 + 21);
    if (_previewSticker == nil)
        return @[emojiMessage];
    TGMessage *stickerMessage = TGOnegramPreviewMessage(5, 2, true, @"", 18 * 60 + 22);
    stickerMessage.mediaAttachments = @[_previewSticker];
    return @[stickerMessage, emojiMessage];
}

- (bool)rebuildsForSettingKey:(NSString *)key
{
    return [key isEqualToString:TGOnegramSettingMessagesDoubleTapIncoming] || [key isEqualToString:TGOnegramSettingMessagesDoubleTapOutgoing] || [key isEqualToString:TGOnegramSettingMessagesQuickReaction];
}

- (void)chooseQuickReaction
{
    TLRPCmessages_getAvailableReactions_manual *request = [[TLRPCmessages_getAvailableReactions_manual alloc] init];
    request.hashValue = 0;
    __weak TGOnegramMessagesSettingsController *weakSelf = self;
    [[[[TGTelegramNetworking instance] requestSignal:request] deliverOn:[SQueue mainQueue]] startWithNext:^(TLmessages_AvailableReactions_manual *result)
    {
        TGOnegramMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        NSArray *emojis = [result isKindOfClass:[TLmessages_AvailableReactions_manual class]] ? result.activeEmojis : nil;
        if (emojis.count == 0)
        {
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramSettings.ReactionsLoadFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            return;
        }
        NSString *preferred = [TGOnegramSettings stringForKey:TGOnegramSettingMessagesQuickReaction];
        NSUInteger selected = [emojis indexOfObject:preferred];
        [strongSelf pushChoiceWithTitle:TGLocalized(@"OnegramSettings.QuickReaction") options:emojis selectedIndex:selected == NSNotFound ? -1 : (NSInteger)selected footer:TGLocalized(@"OnegramSettings.QuickReactionInfo") completion:^(NSInteger index)
        {
            if (index < 0 || index >= (NSInteger)emojis.count)
                return;
            NSString *reaction = emojis[(NSUInteger)index];
            TLRPCmessages_setDefaultReaction_manual *setRequest = [[TLRPCmessages_setDefaultReaction_manual alloc] init];
            setRequest.reaction = reaction;
            [[[[TGTelegramNetworking instance] requestSignal:setRequest] deliverOn:[SQueue mainQueue]] startWithNext:^(TLBool *result)
            {
                if ([result boolValue])
                    [TGOnegramSettings setString:reaction forKey:TGOnegramSettingMessagesQuickReaction];
                else
                    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramSettings.QuickReactionSaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            } error:^(__unused id error)
            {
                [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramSettings.QuickReactionSaveFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            } completed:nil];
        }];
    } error:^(__unused id error)
    {
        if (weakSelf != nil)
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"OnegramSettings.ReactionsLoadFailed") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    } completed:nil];
}

- (void)settingDidChange:(NSString *)key
{
    if ([key isEqualToString:TGOnegramSettingMessagesReplyAuthorColor] || [key isEqualToString:TGOnegramSettingMessagesEditedPencil])
        _bubblePreviewItem.messages = [self bubblePreviewMessages];
    else if ([key isEqualToString:TGOnegramSettingMessagesStickerScale])
        _stickerPreviewItem.stickerScale = 0.0f;
    else if ([key isEqualToString:TGOnegramSettingMessagesHideStickerTime] || [key isEqualToString:TGOnegramSettingMessagesAnimatedEmoji] || [key isEqualToString:TGOnegramSettingMessagesAnimatedStickers])
        _stickerPreviewItem.messages = [self stickerPreviewMessages];
}

- (NSArray *)buildSections
{
    __weak TGOnegramMessagesSettingsController *weakSelf = self;

    NSMutableArray *incomingTitles = [[NSMutableArray alloc] init];
    for (NSString *action in TGOnegramDoubleTapActions(false))
        [incomingTitles addObject:TGOnegramDoubleTapTitle(action)];
    NSMutableArray *outgoingTitles = [[NSMutableArray alloc] init];
    for (NSString *action in TGOnegramDoubleTapActions(true))
        [outgoingTitles addObject:TGOnegramDoubleTapTitle(action)];

    NSMutableArray *bubbleItems = [[NSMutableArray alloc] initWithObjects:_bubblePreviewItem, nil];
    if (TGCurrentInterfaceStyle() == 0)
    {
        TGPresentationPallete *pallete = (self.presentation ?: [TGPresentation current]).pallete;
        NSInteger themeRadius = (NSInteger)lroundf((float)[TGPresentationAssets defaultChatBubbleRadius]);
        NSInteger maximumRadius = MAX((NSInteger)15, themeRadius);
        NSInteger storedRadius = [TGOnegramSettings integerForKey:TGOnegramSettingMessagesBubbleRadius];
        TGOnegramSliderCollectionItem *radiusItem = [[TGOnegramSliderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramSettings.BubbleRadius") minimumValue:0 maximumValue:maximumRadius value:storedRadius < 0 ? themeRadius : MIN(storedRadius, maximumRadius)];
        radiusItem.reversed = true;
        radiusItem.valueFormatter = ^NSString *(NSInteger value)
        {
            return value == themeRadius ? TGLocalized(@"OnegramSettings.Default") : [[NSString alloc] initWithFormat:@"%d", (int)value];
        };
        radiusItem.valueChanged = ^(NSInteger value)
        {
            __strong TGOnegramMessagesSettingsController *strongSelf = weakSelf;
            if (strongSelf != nil)
                strongSelf->_bubblePreviewItem.messagePresentation = [TGPresentation presentationWithPallete:pallete bubbleRadius:value == themeRadius ? -1 : value];
        };
        radiusItem.valueCommitted = ^(NSInteger value)
        {
            [TGOnegramSettings setInteger:value == themeRadius ? -1 : value forKey:TGOnegramSettingMessagesBubbleRadius];
        };
        [bubbleItems addObject:radiusItem];
    }
    [bubbleItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.ReplyAuthorColor") key:TGOnegramSettingMessagesReplyAuthorColor description:TGLocalized(@"OnegramSettings.ReplyAuthorColorInfo")]];
    [bubbleItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.EditedPencil") key:TGOnegramSettingMessagesEditedPencil description:TGLocalized(@"OnegramSettings.EditedPencilInfo")]];

    NSMutableArray *stickerItems = [[NSMutableArray alloc] init];
    [stickerItems addObject:_stickerPreviewItem];
    TGOnegramSliderCollectionItem *stickerItem = [self sliderWithTitle:TGLocalized(@"OnegramSettings.StickerSize") key:TGOnegramSettingMessagesStickerScale minimumValue:50 maximumValue:130 formatter:^NSString *(NSInteger value)
    {
        return [[NSString alloc] initWithFormat:@"%d%%", (int)value];
    }];
    stickerItem.step = 5;
    stickerItem.valueChanged = ^(NSInteger value)
    {
        __strong TGOnegramMessagesSettingsController *strongSelf = weakSelf;
        if (strongSelf != nil)
            strongSelf->_stickerPreviewItem.stickerScale = (CGFloat)value / 100.0f;
    };
    [stickerItems addObject:stickerItem];
    if (![TGPresentation brandedIOS6Style])
        [stickerItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.HideStickerTime") key:TGOnegramSettingMessagesHideStickerTime description:TGLocalized(@"OnegramSettings.HideStickerTimeInfo")]];
    [stickerItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.AnimatedStickers") key:TGOnegramSettingMessagesAnimatedStickers description:TGLocalized(@"OnegramSettings.AnimatedStickersInfo")]];
    [stickerItems addObject:[self switchWithTitle:TGLocalized(@"OnegramSettings.AnimatedEmoji") key:TGOnegramSettingMessagesAnimatedEmoji description:TGLocalized(@"OnegramSettings.AnimatedEmojiInfo")]];

    NSMutableArray *menuItems = [[NSMutableArray alloc] init];
    for (NSString *identifier in TGOnegramMenuActionIdentifiers())
    {
        bool visible = ![[TGOnegramSettings arrayForKey:TGOnegramSettingMessagesMenuHiddenActions] containsObject:identifier];
        [menuItems addObject:[self switchWithTitle:TGOnegramMenuActionTitle(identifier) value:visible toggled:^(bool value)
        {
            NSMutableArray *hidden = [[TGOnegramSettings arrayForKey:TGOnegramSettingMessagesMenuHiddenActions] mutableCopy];
            [hidden removeObject:identifier];
            if (!value)
                [hidden addObject:identifier];
            [TGOnegramSettings setArray:hidden forKey:TGOnegramSettingMessagesMenuHiddenActions];
        }]];
    }

    return @[
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.Bubbles") items:bubbleItems footer:TGLocalized(@"OnegramSettings.BubblesInfo")],
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.Stickers") items:stickerItems footer:TGLocalized(@"OnegramSettings.StickersInfo")],
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.DoubleTap") items:@[
            [self choiceWithTitle:TGLocalized(@"OnegramSettings.DoubleTapIncoming") key:TGOnegramSettingMessagesDoubleTapIncoming options:incomingTitles],
            [self choiceWithTitle:TGLocalized(@"OnegramSettings.DoubleTapOutgoing") key:TGOnegramSettingMessagesDoubleTapOutgoing options:outgoingTitles],
            [self actionWithTitle:TGLocalized(@"OnegramSettings.QuickReaction") variant:[TGOnegramSettings stringForKey:TGOnegramSettingMessagesQuickReaction] description:TGLocalized(@"OnegramSettings.QuickReactionInfo") pressed:^
            {
                [weakSelf chooseQuickReaction];
            }]
        ] footer:TGLocalized(@"OnegramSettings.DoubleTapInfo")],
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.MessageMenu") items:menuItems footer:TGLocalized(@"OnegramSettings.MessageMenuInfo")]
    ];
}

@end

@implementation TGOnegramConfirmationsSettingsController

- (instancetype)init
{
    return [super initWithTitle:TGLocalized(@"OnegramSettings.Confirmations")];
}

- (NSArray *)buildSections
{
    NSArray *linkOptions = @[TGLocalized(@"OnegramSettings.ConfirmLinksNever"), TGLocalized(@"OnegramSettings.ConfirmLinksHidden"), TGLocalized(@"OnegramSettings.ConfirmLinksAlways")];
    return @[
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.Confirmations") items:@[
            [self switchWithTitle:TGLocalized(@"OnegramSettings.ConfirmCalls") key:TGOnegramSettingConfirmCalls description:TGLocalized(@"OnegramSettings.ConfirmCallsInfo")],
            [self switchWithTitle:TGLocalized(@"OnegramSettings.ConfirmVoice") key:TGOnegramSettingConfirmVoiceMessages description:TGLocalized(@"OnegramSettings.ConfirmVoiceInfo")],
            [self choiceWithTitle:TGLocalized(@"OnegramSettings.ConfirmLinks") key:TGOnegramSettingConfirmLinks options:linkOptions description:TGLocalized(@"OnegramSettings.ConfirmLinksInfo")]
        ] footer:nil],
        [self sectionWithHeader:TGLocalized(@"OnegramSettings.Sending") items:@[
            [self switchWithTitle:TGLocalized(@"OnegramSettings.NoLinkPreview") key:TGOnegramSettingMessagesNoLinkPreview description:TGLocalized(@"OnegramSettings.NoLinkPreviewInfo")],
            [self switchWithTitle:TGLocalized(@"OnegramSettings.DeleteForMe") key:TGOnegramSettingMessagesDeleteForMe description:TGLocalized(@"OnegramSettings.DeleteForMeInfo")]
        ] footer:nil]
    ];
}

@end
