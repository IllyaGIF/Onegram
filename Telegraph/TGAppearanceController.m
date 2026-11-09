#import "TGAppearanceController.h"

#import "TGAppDelegate.h"


#import "TGHeaderCollectionItem.h"
#import "TGDisclosureActionCollectionItem.h"
#import "TGFontSizeCollectionItem.h"
#import "TGCheckCollectionItem.h"
#import "TGSwitchCollectionItem.h"
#import "TGAppearancePreviewCollectionItem.h"

#import "TGPresentation.h"
#import "TGDefaultPresentationPallete.h"
#import "TGDayPresentationPallete.h"
#import "TGNightPresentationPallete.h"
#import "TGNightBluePresentationPallete.h"

#import "TGWallpaperManager.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGColorWallpaperInfo.h"
#import "TGMessageViewModel.h"

#import "TGWallpaperListController.h"
#import "TGAppearanceAutoNightController.h"
#import "TGStickerPacksSettingsController.h"
#import "TGOnegramColorsController.h"
#import "TGOnegramSettings.h"
#import "TGSnowflakesView.h"
#import "TGCloudTheme.h"
#import "TGCloudThemeCollectionItem.h"
#import "TGOnegramNightSurfaceController.h"
#import "TGVariantCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGFont.h"

@interface TGAppearanceController () <ASWatcher, TGInterfaceRebuildRestorable>
{
    TGFontSizeCollectionItem *_sizeItem;
    
    TGDisclosureActionCollectionItem *_colorsItem;
    TGSwitchCollectionItem *_roundChatAvatarItem;
    TGSwitchCollectionItem *_snowfallItem;
    TGSwitchCollectionItem *_separatorsItem;
    TGVariantCollectionItem *_nightSurfaceItem;
    TGCollectionMenuSection *_previewSection;
    TGAppearancePreviewCollectionItem *_previewItem;
    TGDisclosureActionCollectionItem *_backgroundItem;
    TGCollectionMenuSection *_themeSection;
    TGCheckCollectionItem *_dayClassicItem;
    TGCheckCollectionItem *_dayItem;
    TGCheckCollectionItem *_nightItem;
    TGCheckCollectionItem *_nightBlueItem;
    NSMutableDictionary *_cloudThemeItems;
    
    TGDisclosureActionCollectionItem *_autoNightItem;
    TGSwitchCollectionItem *_callsTabItem;
    TGCheckCollectionItem *_interfaceModernItem;
    TGCheckCollectionItem *_interfaceClassicItem;
    TGCheckCollectionItem *_interfaceFeklaItem;
    TGCheckCollectionItem *_emojiStockItem;
    TGCheckCollectionItem *_emojiNewItem;
    TGCheckCollectionItem *_emojiCombinedItem;

}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGAppearanceController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.title = TGLocalized(@"Appearance.Title");
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Back") style:UIBarButtonItemStylePlain target:nil action:nil];
        
        TGCollectionMenuSection *fontSection = [[TGCollectionMenuSection alloc] initWithItems:@
        [
         [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.TextSize")],
         _sizeItem = [[TGFontSizeCollectionItem alloc] init]
        ]];
        
        __weak TGAppearanceController *weakSelf = self;
        _sizeItem.valueChanged = ^(int32_t value)
        {
            __strong TGAppearanceController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                CGFloat size = [strongSelf fontSizeForPosition:value];
                [TGPresentation setFontSize:size];
                TGUpdateMessageViewModelLayoutConstants(size);
                [strongSelf->_previewItem refreshMetrics];
            }
        };
        
        [[[TGPresentation fontSizeSignal] take:1] startWithNext:^(NSNumber *next)
        {
            __strong TGAppearanceController *strongSelf = weakSelf;
            if (strongSelf != nil) {
                int32_t position = [strongSelf positionForFontSize:next.floatValue];
                [strongSelf->_sizeItem setValue:position];
                
                TGUpdateMessageViewModelLayoutConstants(next.floatValue);
            }
        }];
        
        UIEdgeInsets topSectionInsets = fontSection.insets;
        topSectionInsets.top = 32.0f;
        fontSection.insets = topSectionInsets;
        [self.menuSections addSection:fontSection];
        
        _previewItem = [[TGAppearancePreviewCollectionItem alloc] init],
        _previewItem.heightChanged = ^ {
            __strong TGAppearanceController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf.collectionLayout invalidateLayout];
        };
        _previewItem.messages = [TGAppearanceController previewMessages];
        
        _colorsItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramColors.Title") action:@selector(colorsPressed)];
        _colorsItem.deselectAutomatically = true;
        
        _autoNightItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.AutoNightTheme") action:@selector(autoNightPressed)];
        
        _backgroundItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"Settings.ChatBackground") action:@selector(wallpapersPressed)];
        _backgroundItem.ignoreSeparatorInset = true;
        _previewSection = [[TGCollectionMenuSection alloc] initWithItems:@
        [
         [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.Preview")],
         _previewItem,
         _backgroundItem
        ]];
        [self.menuSections addSection:_previewSection];
        
        [self updateColorItem:TGPresentation.currentSavedPallete];
        
        _callsTabItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.CallsTabIcon") isOn:TGAppDelegateInstance.showCallsTab];
        _callsTabItem.interfaceHandle = _actionHandle;

        TGCollectionMenuSection *interfaceStyleSection = [[TGCollectionMenuSection alloc] initWithItems:@
        [
         [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.InterfaceStyle")],
         _callsTabItem,
         _interfaceModernItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.InterfaceStyleModern") action:@selector(interfaceModernPressed)],
         _interfaceClassicItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.InterfaceStyleClassic") action:@selector(interfaceClassicPressed)],
         _interfaceFeklaItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.InterfaceStyleFekla") action:@selector(interfaceFeklaPressed)]
        ]];
        [self.menuSections addSection:interfaceStyleSection];
        
        TGCollectionMenuSection *emojiSection = [[TGCollectionMenuSection alloc] initWithItems:@
        [
         [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.Emoji")],
         _emojiStockItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.EmojiStockOnly") action:@selector(emojiStockPressed)],
         _emojiNewItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.EmojiNewOnly") action:@selector(emojiNewPressed)],
         _emojiCombinedItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.EmojiCombined") action:@selector(emojiCombinedPressed)]
        ]];
        [self.menuSections addSection:emojiSection];

        if (![TGPresentation brandedIOS6Style])
        {
            _roundChatAvatarItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramAppearance.RoundChatAvatar") isOn:[TGOnegramSettings boolForKey:TGOnegramSettingAppearanceRoundChatAvatar]];
            _roundChatAvatarItem.interfaceHandle = _actionHandle;
            _snowfallItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramAppearance.Snowfall") isOn:TGSnowfallSettingEnabled()];
            _snowfallItem.interfaceHandle = _actionHandle;
            _separatorsItem = [[TGSwitchCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramAppearance.Separators") isOn:[TGOnegramSettings boolForKey:TGOnegramSettingAppearanceSeparators]];
            _separatorsItem.interfaceHandle = _actionHandle;
            _nightSurfaceItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramAppearance.NightSurface") variant:nil action:@selector(nightSurfacePressed)];
            [self updateNightSurfaceItem];
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[
                [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"OnegramAppearance.Extra")],
                _nightSurfaceItem,
                _separatorsItem,
                _roundChatAvatarItem,
                _snowfallItem,
                [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"OnegramAppearance.SnowfallInfo")]
            ]]];
        }

        if (TGOnegramModernInterfaceEnabled() && ![TGPresentation brandedIOS6Style])
        {
            TGDisclosureActionCollectionItem *stickersItem = [[TGDisclosureActionCollectionItem alloc] initWithTitle:TGLocalized(@"ChatSettings.Stickers") action:@selector(stickersPressed)];
            stickersItem.deselectAutomatically = true;
            [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[stickersItem]]];
        }

        _themeSection = [[TGCollectionMenuSection alloc] initWithItems:@
        [
         [[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.ColorTheme")],
         _dayClassicItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.ThemeDayClassic") action:@selector(dayClassicPressed)],
         _dayItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.ThemeDay") action:@selector(dayPressed)],
         _nightBlueItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.ThemeNightBlue") action:@selector(nightBluePressed)],
         _nightItem = [[TGCheckCollectionItem alloc] initWithTitle:TGLocalized(@"Appearance.ThemeNight") action:@selector(nightPressed)]
        ]];
        _cloudThemeItems = [[NSMutableDictionary alloc] init];
        [self.menuSections addSection:_themeSection];

        [self updateSelection];
        [self updateInterfaceStyleSelection];
        [self updateEmojiSelection];
        
        [ActionStageInstance() watchForPaths:@[@"/tg/assets/currentWallpaperInfo"] watcher:self];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self updateThemeItems];
    [self updateNightSurfaceItem];
    
    if (iosMajorVersion() < 8)
    {
        [_previewItem refreshMetrics];
        [self.collectionLayout invalidateLayout];
        [self.collectionView layoutSubviews];
    }
}

- (void)stickersPressed
{
    TGStickerPacksSettingsController *controller = [[TGStickerPacksSettingsController alloc] initWithEditing:false masksMode:false];
    [self.navigationController pushViewController:controller animated:true];
}

- (void)wallpapersPressed
{
    if ([TGPresentation brandedIOS6Style])
        return;

    TGWallpaperListController *controller = [[TGWallpaperListController alloc] init];
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)colorsPressed
{
    TGOnegramColorsController *controller = [[TGOnegramColorsController alloc] init];
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)autoNightPressed
{
    TGAppearanceAutoNightController *controller = [[TGAppearanceAutoNightController alloc] init];
    controller.presentation = self.presentation;
    [self.navigationController pushViewController:controller animated:true];
}

- (void)updateColorItem:(TGPresentationPallete *)pallete
{
    bool fekla = [TGPresentation brandedIOS6Style];
    bool autoNightVisible = [pallete isKindOfClass:[TGDefaultPresentationPallete class]];

    NSMutableArray *items = [NSMutableArray arrayWithObjects:_previewSection.items.firstObject, _previewItem, nil];
    if (!fekla)
        [items addObject:_backgroundItem];
    if (!fekla)
        [items addObject:_colorsItem];
    if (autoNightVisible)
        [items addObject:_autoNightItem];

    if (![_previewSection.items isEqualToArray:items])
    {
        [_previewSection replaceItems:items];
        [self.collectionView reloadData];
    }
}

- (void)dayClassicPressed
{
    if (_dayClassicItem.isChecked)
        return;
    
    [self setPallete:[TGDefaultPresentationPallete new] wallpaper:[self builtinWallpaper]];
}

- (void)dayPressed
{
    if (_dayItem.isChecked)
        return;

    TGPresentationPallete *pallete = [TGDayPresentationPallete new];
    [self setPallete:pallete wallpaper:[self colorWallpaperForPallete:pallete]];
}

- (void)nightPressed
{
    if (_nightItem.isChecked)
        return;
    
    TGPresentationPallete *pallete = [TGNightPresentationPallete new];
    [self setPallete:pallete wallpaper:[self colorWallpaperForPallete:pallete]];
}

- (void)applyCloudTheme:(TGCloudTheme *)theme
{
    if ([[TGCloudTheme activeThemeIdentifier] isEqualToString:theme.identifier])
        return;
    [TGAppDelegateInstance rebuildInterfaceApplyingChange:^
    {
        [theme apply];
    }];
    [self updateThemeItems];
    [self updateColorItem:TGPresentation.currentSavedPallete];
}

- (void)removeCloudTheme:(TGCloudTheme *)theme
{
    bool wasActive = [TGCloudTheme removeStoredThemeWithIdentifier:theme.identifier];
    [_cloudThemeItems removeObjectForKey:theme.identifier];
    if (!wasActive)
    {
        [self updateThemeItems];
        return;
    }
    Class palleteClass = [theme basePalleteClass];
    TGPresentationPallete *pallete = [[palleteClass alloc] init];
    bool classic = palleteClass == [TGDefaultPresentationPallete class];
    [self setPallete:pallete wallpaper:classic ? [self builtinWallpaper] : [self colorWallpaperForPallete:pallete]];
}

- (void)nightSurfacePressed
{
    [self.navigationController pushViewController:[[TGOnegramNightSurfaceController alloc] init] animated:true];
}

- (void)updateNightSurfaceItem
{
    if (_nightSurfaceItem == nil)
        return;
    NSInteger tone = [TGOnegramSettings integerForKey:TGOnegramSettingAppearanceNightSurface];
    _nightSurfaceItem.variant = TGLocalized([[NSString alloc] initWithFormat:@"OnegramAppearance.NightSurface.%d", (int)tone]);
}

- (void)nightBluePressed
{
    if (_nightBlueItem.isChecked)
        return;
    
    TGPresentationPallete *pallete = [TGNightBluePresentationPallete new];
    [self setPallete:pallete wallpaper:[self colorWallpaperForPallete:pallete]];
}

- (void)updateEmojiRenderMode:(TGEmojiRenderMode)mode
{
    if (TGCurrentEmojiRenderMode() == mode)
        return;

    TGSetEmojiRenderMode(mode);
    [self updateEmojiSelection];
    [_previewItem refreshMetrics];
    [self.collectionView reloadData];
}

- (void)emojiStockPressed
{
    [self updateEmojiRenderMode:TGEmojiRenderModeStockOnly];
}

- (void)emojiNewPressed
{
    [self updateEmojiRenderMode:TGEmojiRenderModeNewOnly];
}

- (void)emojiCombinedPressed
{
    [self updateEmojiRenderMode:TGEmojiRenderModeCombined];
}

- (TGWallpaperInfo *)builtinWallpaper
{
    if ([TGPresentation brandedIOS6Style])
        return nil;
    return [[TGWallpaperManager instance] builtinWallpaperList].firstObject;
}

- (TGWallpaperInfo *)colorWallpaperForPallete:(TGPresentationPallete *)pallete
{
    if ([TGPresentation brandedIOS6Style])
        return nil;
    return [[TGColorWallpaperInfo alloc] initWithColor:TGColorHexCode(pallete.backgroundColor)];
}

- (void)setPallete:(TGPresentationPallete *)pallete wallpaper:(TGWallpaperInfo *)wallpaper
{
    [TGAppDelegateInstance rebuildInterfaceApplyingChange:^
    {
        if (wallpaper != nil)
            [[TGWallpaperManager instance] setCurrentWallpaperWithInfo:wallpaper];
        [TGCloudTheme resetInstalledTheme];
        [TGPresentation switchToPallete:pallete];
    }];
    [self updateThemeItems];
    [self updateColorItem:pallete];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"switchItemChanged"] && options[@"item"] == _roundChatAvatarItem)
    {
        [TGOnegramSettings setBool:_roundChatAvatarItem.isOn forKey:TGOnegramSettingAppearanceRoundChatAvatar];
    }
    else if ([action isEqualToString:@"switchItemChanged"] && options[@"item"] == _separatorsItem)
    {
        [TGOnegramSettings setBool:_separatorsItem.isOn forKey:TGOnegramSettingAppearanceSeparators];
    }
    else if ([action isEqualToString:@"switchItemChanged"] && options[@"item"] == _snowfallItem)
    {
        [TGOnegramSettings setInteger:_snowfallItem.isOn ? 1 : 0 forKey:TGOnegramSettingAppearanceSnowfall];
    }
    else if ([action isEqualToString:@"switchItemChanged"] && options[@"item"] == _callsTabItem)
    {
        TGAppDelegateInstance.showCallsTab = _callsTabItem.isOn;
        [TGAppDelegateInstance.rootController.mainTabsController setCallsHidden:!_callsTabItem.isOn animated:true];
    }
}

- (void)setInterfaceStyle:(TGInterfaceStyle)style
{
    if ([TGPresentation interfaceStyle] == style)
        return;

    [TGAppDelegateInstance rebuildInterfaceApplyingChange:^
    {
        [TGPresentation setInterfaceStyle:style];
    }];
}

- (UIViewController *)controllerForInterfaceRebuild
{
    return [[TGAppearanceController alloc] init];
}

- (void)interfaceModernPressed
{
    [self setInterfaceStyle:TGInterfaceStyleModern];
}

- (void)interfaceClassicPressed
{
    [self setInterfaceStyle:TGInterfaceStyleClassic];
}

- (void)interfaceFeklaPressed
{
    [self setInterfaceStyle:TGInterfaceStyleFekla];
}

- (void)updateInterfaceStyleSelection
{
    TGInterfaceStyle style = [TGPresentation interfaceStyle];
    _interfaceModernItem.isChecked = style == TGInterfaceStyleModern;
    _interfaceClassicItem.isChecked = style == TGInterfaceStyleClassic;
    _interfaceFeklaItem.isChecked = style == TGInterfaceStyleFekla;

    bool fekla = style == TGInterfaceStyleFekla;
    _dayClassicItem.title = TGLocalized(fekla ? @"Appearance.ThemeWhite" : @"Appearance.ThemeDayClassic");
    _nightItem.title = TGLocalized(fekla ? @"Appearance.ThemeBlack" : @"Appearance.ThemeNight");
    [self updateThemeItems];
    [self updateColorItem:TGPresentation.currentSavedPallete];
}

- (void)updateThemeItems
{
    bool fekla = [TGPresentation interfaceStyle] == TGInterfaceStyleFekla;
    NSMutableArray *items = [[NSMutableArray alloc] initWithObjects:_themeSection.items.firstObject, _dayClassicItem, nil];
    if (!fekla)
        [items addObjectsFromArray:@[_dayItem, _nightBlueItem]];
    [items addObject:_nightItem];
    if (!fekla)
    {
        NSMutableSet *identifiers = [[NSMutableSet alloc] init];
        __weak TGAppearanceController *weakSelf = self;
        for (TGCloudTheme *theme in [TGCloudTheme storedThemes])
        {
            if (theme.identifier == nil)
                continue;
            [identifiers addObject:theme.identifier];
            TGCloudThemeCollectionItem *item = _cloudThemeItems[theme.identifier];
            if (item == nil)
            {
                item = [[TGCloudThemeCollectionItem alloc] init];
                _cloudThemeItems[theme.identifier] = item;
            }
            item.title = theme.title.length != 0 ? theme.title : TGLocalized(@"OnegramTheme.Installed");
            item.pressed = ^
            {
                __strong TGAppearanceController *strongSelf = weakSelf;
                [strongSelf applyCloudTheme:theme];
            };
            item.removeRequested = ^
            {
                __strong TGAppearanceController *strongSelf = weakSelf;
                [strongSelf removeCloudTheme:theme];
            };
            [items addObject:item];
        }
        for (NSString *identifier in [_cloudThemeItems allKeys])
        {
            if (![identifiers containsObject:identifier])
                [_cloudThemeItems removeObjectForKey:identifier];
        }
    }
    if (![_themeSection.items isEqualToArray:items])
    {
        [_themeSection replaceItems:items];
        if (self.isViewLoaded)
            [self.collectionView reloadData];
    }
    [self updateSelection];
}

- (void)updateSelection
{
    TGPresentationPallete *savedPallete = TGPresentation.currentSavedPallete;
    NSString *activeIdentifier = [TGCloudTheme activeThemeIdentifier];
    bool cloudTheme = false;
    for (NSString *identifier in _cloudThemeItems)
    {
        TGCloudThemeCollectionItem *item = _cloudThemeItems[identifier];
        bool active = [identifier isEqualToString:activeIdentifier] && [_themeSection.items containsObject:item];
        item.isChecked = active;
        cloudTheme = cloudTheme || active;
    }
    _dayClassicItem.isChecked = !cloudTheme && [savedPallete isMemberOfClass:[TGDefaultPresentationPallete class]];
    _dayItem.isChecked = !cloudTheme && [savedPallete isMemberOfClass:[TGDayPresentationPallete class]];
    _nightItem.isChecked = !cloudTheme && [savedPallete isMemberOfClass:[TGNightPresentationPallete class]];
    _nightBlueItem.isChecked = !cloudTheme && [savedPallete isMemberOfClass:[TGNightBluePresentationPallete class]];
}

- (void)updateEmojiSelection
{
    TGEmojiRenderMode mode = TGCurrentEmojiRenderMode();
    _emojiStockItem.isChecked = mode == TGEmojiRenderModeStockOnly;
    _emojiNewItem.isChecked = mode == TGEmojiRenderModeNewOnly;
    _emojiCombinedItem.isChecked = mode == TGEmojiRenderModeCombined;
}

+ (NSArray *)previewMessages
{
    TGUser *replyAuthor = [[TGUser alloc] init];
    replyAuthor.firstName = TGLocalized(@"Appearance.PreviewReplyAuthor");
    replyAuthor.uid = 2;
    
    TGMessage *replyMessage = [[TGMessage alloc] init];
    replyMessage.mid = 1;
    replyMessage.fromUid = 2;
    replyMessage.text = TGLocalized(@"Appearance.PreviewReplyText");
    replyMessage.date = 60 * (60 * 18 + 19);
    
    TGReplyMessageMediaAttachment *replyMessageAttachment = [[TGReplyMessageMediaAttachment alloc] init];
    replyMessageAttachment.replyMessageId = replyMessage.mid;
    replyMessageAttachment.replyMessage = replyMessage;
    
    TGMessage *firstMessage = [[TGMessage alloc] init];
    firstMessage.mid = 2;
    firstMessage.fromUid = 1;
    firstMessage.text = TGLocalized(@"Appearance.PreviewIncomingText");
    firstMessage.date = 60 * (60 * 18 + 20);
    firstMessage.mediaAttachments = @[replyMessageAttachment];
    
    TGMessage *secondMessage = [[TGMessage alloc] init];
    secondMessage.mid = 3;
    secondMessage.fromUid = 2;
    secondMessage.outgoing = true;
    secondMessage.text = TGLocalized(@"Appearance.PreviewOutgoingText");
    secondMessage.date = 60 * (60 * 18 + 20);
    
    return @[ secondMessage, firstMessage ];
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)__unused resource arguments:(id)__unused arguments
{
    if ([path isEqualToString:@"/tg/assets/currentWallpaperInfo"])
    {
        TGDispatchOnMainThread(^
        {
            [_previewItem updateWallpaper];
            if ([self.presentation.pallete isKindOfClass:[TGDayPresentationPallete class]])
                [_previewItem reset];
        });
    }
}

+ (NSArray *)fontSizes
{
    return @[ @14.0f, @15.0f, @16.0f, @17.0f, @19.0f, @23.0f, @26.0f ];
}

- (CGFloat)fontSizeForPosition:(int32_t)position
{
    if (position < 0 || position > (int32_t)[TGAppearanceController fontSizes].count)
        return 17.0f;
    
    return [[TGAppearanceController fontSizes][position] floatValue];
}

- (int32_t)positionForFontSize:(CGFloat)fontSize
{
    int32_t bestIndex = 3;
    CGFloat bestDelta = FLT_MAX;
    
    NSArray *fontSizes = [TGAppearanceController fontSizes];
    for (int32_t i = 0; i < (int32_t)fontSizes.count; i++)
    {
        CGFloat size = [fontSizes[i] floatValue];
        CGFloat delta = (CGFloat)fabs(size - fontSize);
        if (delta < bestDelta)
        {
            bestDelta = delta;
            bestIndex = i;
        }
    }
    
    return bestIndex;
}

@end
