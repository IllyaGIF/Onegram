#import "TGCloudTheme.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGColorWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGCustomImageWallpaperInfo.h"

#import "TL/TLMetaScheme.h"

#import "TGTLDynamic.h"
#import "TGSharedFileSignals.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "TGWallpaperManager.h"
#import "TGPresentation.h"
#import "TGPresentationPallete.h"
#import "TGDefaultPresentationPallete.h"
#import "TGDayPresentationPallete.h"
#import "TGNightPresentationPallete.h"
#import "TGNightBluePresentationPallete.h"
#import "TGPresentationCustomColors.h"
#import "TGCloudThemeWallpaper.h"

static NSString *const TGCloudThemeLegacyDefaultsKey = @"Onegram.Appearance.CloudTheme";
static NSString *const TGCloudThemeStoredThemesKey = @"Onegram.Appearance.CloudThemes";
static NSString *const TGCloudThemeActiveThemeKey = @"Onegram.Appearance.CloudThemeActive";

typedef struct {
    const char *selector;
    const char *atthemeKeys;
    const char *tgiosKeys;
    const char *atthemeBackdrop;
} TGCloudThemeColorMapping;

static const TGCloudThemeColorMapping TGCloudThemeColorMappings[] = {
    {"backgroundColor", "windowBackgroundWhite", "chatList.bg list.plainBg", NULL},
    {"textColor", "windowBackgroundWhiteBlackText", "list.primaryText", NULL},
    {"secondaryTextColor", "windowBackgroundWhiteGrayText windowBackgroundWhiteGrayText2", "list.secondaryText", NULL},
    {"accentColor", "windowBackgroundWhiteBlueText4 windowBackgroundWhiteBlueHeader chats_actionBackground", "list.accent root.navBar.accentText", NULL},
    {"maybeAccentColor", "windowBackgroundWhiteBlueText windowBackgroundWhiteBlueText4", "list.accent", NULL},
    {"accentContrastColor", "chats_actionIcon", "list.check.foreground", NULL},
    {"destructiveColor", "text_RedRegular text_RedBold", "list.destructive", NULL},
    {"selectionColor", "listSelectorSDK21", "list.itemHighlightedBg chatList.itemHighlightedBg", "windowBackgroundWhite"},
    {"separatorColor", "divider", "chatList.itemSeparator list.plainSeparator", NULL},
    {"linkColor", "windowBackgroundWhiteLinkText", "list.accent", NULL},
    {"checkButtonBorderColor", "checkboxSquareUnchecked", "list.check.stroke", NULL},
    {"checkButtonBackgroundColor", "checkboxSquareBackground checkbox", "list.check.fill", NULL},
    {"checkButtonCheckColor", "checkboxSquareCheck checkboxCheck", "list.check.foreground", NULL},
    {"checkButtonBlueColor", "checkbox checkboxSquareBackground", "list.check.fill", NULL},
    {"padSeparatorColor", "divider", "list.plainSeparator", NULL},
    {"barBackgroundColor", "actionBarDefault", "root.navBar.background", NULL},
    {"barSeparatorColor", "", "root.navBar.separator", NULL},
    {"sectionHeaderBackgroundColor", "graySection", "chatList.sectionHeaderBg", NULL},
    {"sectionHeaderTextColor", "key_graySectionText graySectionText", "chatList.sectionHeaderText", NULL},
    {"navigationTitleColor", "actionBarDefaultTitle", "root.navBar.primaryText", NULL},
    {"navigationSubtitleColor", "actionBarDefaultSubtitle", "root.navBar.secondaryText", NULL},
    {"navigationActiveSubtitleColor", "chat_status actionBarDefaultSubtitle", "root.navBar.accentText", NULL},
    {"navigationButtonColor", "actionBarDefaultIcon", "root.navBar.button", NULL},
    {"navigationDisabledButtonColor", "", "root.navBar.disabledButton", NULL},
    {"navigationBadgeColor", "chats_unreadCounter", "root.navBar.badgeFill", NULL},
    {"navigationBadgeTextColor", "chats_unreadCounterText", "root.navBar.badgeText", NULL},
    {"navigationBadgeBorderColor", "", "root.navBar.badgeStroke", NULL},
    {"navigationSpinnerColor", "actionBarDefaultIcon", "root.navBar.secondaryText", NULL},
    {"tabTextColor", "", "root.tabBar.text", NULL},
    {"tabIconColor", "", "root.tabBar.icon", NULL},
    {"tabActiveIconColor", "", "root.tabBar.selectedIcon", NULL},
    {"tabBadgeColor", "chats_unreadCounter", "root.tabBar.badgeBackground", NULL},
    {"tabBadgeTextColor", "chats_unreadCounterText", "root.tabBar.badgeText", NULL},
    {"tabBadgeBorderColor", "", "root.tabBar.badgeStroke", NULL},
    {"searchBarBackgroundColor", "dialogSearchBackground chat_emojiSearchBackground", "root.searchBar.inputFill", NULL},
    {"searchBarTextColor", "dialogSearchText windowBackgroundWhiteBlackText", "root.searchBar.inputText", NULL},
    {"searchBarPlaceholderColor", "dialogSearchHint windowBackgroundWhiteHintText", "root.searchBar.inputPlaceholderText", NULL},
    {"searchBarMergedBackgroundColor", "dialogSearchBackground chat_emojiSearchBackground", "root.searchBar.inputFill", NULL},
    {"searchBarClearIconColor", "dialogSearchIcon", "root.searchBar.inputClearButton", NULL},
    {"dialogTitleColor", "chats_name", "chatList.title", NULL},
    {"dialogNameColor", "chats_nameMessage", "chatList.authorName", NULL},
    {"dialogTextColor", "chats_message", "chatList.messageText", NULL},
    {"dialogDraftColor", "chats_draft", "chatList.messageDraftText", NULL},
    {"dialogDateColor", "chats_date", "chatList.dateText", NULL},
    {"dialogChecksColor", "chats_sentReadCheck chats_sentCheck", "chatList.checkmark", NULL},
    {"dialogVerifiedBackgroundColor", "chats_verifiedBackground", "chatList.verifiedIconBg", NULL},
    {"dialogVerifiedIconColor", "chats_verifiedCheck", "chatList.verifiedIconFg", NULL},
    {"dialogPinnedBackgroundColor", "chats_pinnedOverlay", "chatList.pinnedItemBg", "windowBackgroundWhite"},
    {"dialogPinnedIconColor", "chats_pinnedIcon", "chatList.pinnedBadge", NULL},
    {"dialogEncryptedColor", "chats_secretName", "chatList.secretTitle", NULL},
    {"dialogBadgeColor", "chats_unreadCounter", "chatList.unreadBadgeActiveBg", NULL},
    {"dialogBadgeTextColor", "chats_unreadCounterText", "chatList.unreadBadgeActiveText", NULL},
    {"dialogBadgeMutedColor", "chats_unreadCounterMuted", "chatList.unreadBadgeInactiveBg", NULL},
    {"dialogBadgeMutedTextColor", "chats_unreadCounterText", "chatList.unreadBadgeInactiveText", NULL},
    {"dialogUnsentColor", "chats_sentError", "chatList.failedFill", NULL},
    {"chatIncomingBubbleColor", "chat_inBubble", "chat.message.incoming.bubble.withWp.bg chat.message.incoming.bubble.withoutWp.bg", NULL},
    {"chatIncomingBubbleBorderColor", "chat_inBubble", "chat.message.incoming.bubble.withWp.stroke chat.message.incoming.bubble.withoutWp.stroke", NULL},
    {"chatIncomingHighlightedBubbleColor", "chat_inBubbleSelected", "chat.message.incoming.bubble.withWp.highlightedBg chat.message.incoming.bubble.withoutWp.highlightedBg", NULL},
    {"chatIncomingHighlightedBubbleBorderColor", "chat_inBubbleSelected", "chat.message.incoming.bubble.withWp.highlightedBg chat.message.incoming.bubble.withoutWp.highlightedBg", NULL},
    {"chatIncomingTextColor", "chat_messageTextIn", "chat.message.incoming.primaryText", NULL},
    {"chatIncomingSubtextColor", "chat_inReplyMessageText chat_inTimeText", "chat.message.incoming.secondaryText", NULL},
    {"chatIncomingAccentColor", "chat_inReplyNameText chat_inReplyLine", "chat.message.incoming.accentText", NULL},
    {"chatIncomingLinkColor", "chat_messageLinkIn", "chat.message.incoming.linkText", NULL},
    {"chatIncomingDateColor", "chat_inTimeText", "chat.message.incoming.secondaryText", NULL},
    {"chatIncomingButtonColor", "chat_inLoader", "chat.message.incoming.accentControl", NULL},
    {"chatIncomingButtonIconColor", "chat_inMediaIcon", "chat.message.incoming.mediaControlInnerBg chat.message.incoming.bubble.withWp.bg", NULL},
    {"chatIncomingLineColor", "chat_inReplyLine", "chat.message.incoming.accentControl", NULL},
    {"chatIncomingAudioBackgroundColor", "chat_inAudioSeekbar chat_inVoiceSeekbar", "chat.message.incoming.mediaInactiveControl", NULL},
    {"chatIncomingAudioForegroundColor", "chat_inAudioSeekbarFill chat_inVoiceSeekbarFill", "chat.message.incoming.mediaActiveControl", NULL},
    {"chatIncomingAudioDotColor", "chat_inAudioSeekbarFill chat_inVoiceSeekbarFill", "chat.message.incoming.mediaActiveControl", NULL},
    {"chatOutgoingBubbleColor", "chat_outBubble", "chat.message.outgoing.bubble.withWp.bg chat.message.outgoing.bubble.withoutWp.bg", NULL},
    {"chatOutgoingBubbleBorderColor", "chat_outBubble", "chat.message.outgoing.bubble.withWp.stroke chat.message.outgoing.bubble.withoutWp.stroke", NULL},
    {"chatOutgoingHighlightedBubbleColor", "chat_outBubbleSelected", "chat.message.outgoing.bubble.withWp.highlightedBg chat.message.outgoing.bubble.withoutWp.highlightedBg", NULL},
    {"chatOutgoingHighlightedBubbleBorderColor", "chat_outBubbleSelected", "chat.message.outgoing.bubble.withWp.highlightedBg chat.message.outgoing.bubble.withoutWp.highlightedBg", NULL},
    {"chatOutgoingTextColor", "chat_messageTextOut", "chat.message.outgoing.primaryText", NULL},
    {"chatOutgoingSubtextColor", "chat_outReplyMessageText chat_outTimeText", "chat.message.outgoing.secondaryText", NULL},
    {"chatOutgoingAccentColor", "chat_outReplyNameText chat_outReplyLine", "chat.message.outgoing.accentText", NULL},
    {"chatOutgoingLinkColor", "chat_messageLinkOut", "chat.message.outgoing.linkText", NULL},
    {"chatOutgoingDateColor", "chat_outTimeText", "chat.message.outgoing.secondaryText", NULL},
    {"chatOutgoingButtonColor", "chat_outLoader", "chat.message.outgoing.accentControl", NULL},
    {"chatOutgoingButtonIconColor", "chat_outMediaIcon", "chat.message.outgoing.mediaControlInnerBg chat.message.outgoing.bubble.withWp.bg", NULL},
    {"chatOutgoingLineColor", "chat_outReplyLine", "chat.message.outgoing.accentControl", NULL},
    {"chatOutgoingAudioBackgroundColor", "chat_outAudioSeekbar chat_outVoiceSeekbar", "chat.message.outgoing.mediaInactiveControl", NULL},
    {"chatOutgoingAudioForegroundColor", "chat_outAudioSeekbarFill chat_outVoiceSeekbarFill", "chat.message.outgoing.mediaActiveControl", NULL},
    {"chatOutgoingAudioDotColor", "chat_outAudioSeekbarFill chat_outVoiceSeekbarFill", "chat.message.outgoing.mediaActiveControl", NULL},
    {"chatIncomingCallSuccessfulColor", "calls_callReceivedGreenIcon", "", NULL},
    {"chatIncomingCallFailedColor", "calls_callReceivedRedIcon", "", NULL},
    {"chatOutgoingCallSuccessfulColor", "calls_callReceivedGreenIcon", "", NULL},
    {"chatOutgoingCallFailedColor", "calls_callReceivedRedIcon", "", NULL},
    {"chatUnreadBackgroundColor", "chat_unreadMessagesStartBackground", "chat.serviceMessage.unreadBarBg", NULL},
    {"chatUnreadBorderColor", "chat_unreadMessagesStartBackground", "chat.serviceMessage.unreadBarStroke", NULL},
    {"chatUnreadTextColor", "chat_unreadMessagesStartText", "chat.serviceMessage.unreadBarText", NULL},
    {"chatSystemBackgroundColor", "chat_serviceBackground", "chat.serviceMessage.components.withCustomWp.bg chat.serviceMessage.components.withDefaultWp.bg", NULL},
    {"chatSystemTextColor", "chat_serviceText", "chat.serviceMessage.components.withCustomWp.primaryText chat.serviceMessage.components.withDefaultWp.primaryText", NULL},
    {"chatActionBackgroundColor", "chat_serviceBackground", "chat.serviceMessage.components.withCustomWp.bg chat.serviceMessage.components.withDefaultWp.bg", NULL},
    {"chatActionIconColor", "chat_serviceIcon chat_serviceText", "chat.serviceMessage.components.withCustomWp.primaryText chat.serviceMessage.components.withDefaultWp.primaryText", NULL},
    {"chatReplyButtonBackgroundColor", "chat_serviceBackground", "chat.serviceMessage.components.withCustomWp.bg chat.serviceMessage.components.withDefaultWp.bg", NULL},
    {"chatReplyButtonHighlightedBackgroundColor", "chat_serviceBackgroundSelected", "chat.serviceMessage.components.withCustomWp.dateFillFloat chat.serviceMessage.components.withDefaultWp.dateFillFloat", NULL},
    {"chatReplyButtonIconColor", "chat_serviceIcon chat_serviceText", "chat.serviceMessage.components.withCustomWp.primaryText chat.serviceMessage.components.withDefaultWp.primaryText", NULL},
    {"chatChecksColor", "chat_outSentCheckRead chat_outSentCheck", "chat.message.outgoingCheck", NULL},
    {"chatChecksMediaColor", "chat_mediaSentCheck", "chat.message.mediaDateAndStatusText", NULL},
    {"chatInputBackgroundColor", "chat_messagePanelBackground", "chat.inputPanel.inputBg", NULL},
    {"chatInputBorderColor", "chat_messagePanelBackground", "chat.inputPanel.inputStroke", NULL},
    {"chatInputTextColor", "chat_messagePanelText", "chat.inputPanel.inputText_v2 chat.inputPanel.primaryText", NULL},
    {"chatInputPlaceholderColor", "chat_messagePanelHint", "chat.inputPanel.inputPlaceholder_v2", NULL},
    {"chatInputButtonColor", "chat_messagePanelIcons", "chat.inputPanel.panelControl_v2", NULL},
    {"chatInputFieldButtonColor", "chat_messagePanelIcons", "chat.inputPanel.inputControl_v2", NULL},
    {"chatInputSendButtonColor", "chat_messagePanelSend", "chat.inputPanel.actionControlBg", NULL},
    {"chatInputSendButtonIconColor", "", "chat.inputPanel.actionControlFg", NULL},
    {"chatInputKeyboardBackgroundColor", "chat_emojiPanelBackground", "chat.inputMediaPanel.stickersBg chat.inputMediaPanel.bg", NULL},
    {"chatInputKeyboardBorderColor", "chat_emojiPanelShadowLine", "chat.inputMediaPanel.panelSeparator", NULL},
    {"chatInputKeyboardHeaderColor", "chat_emojiPanelStickerSetName", "chat.inputMediaPanel.stickersSectionText", NULL},
    {"chatInputKeyboardSearchBarColor", "chat_emojiSearchBackground", "chat.inputMediaPanel.stickersSearchBg", NULL},
    {"chatInputKeyboardSearchBarTextColor", "chat_emojiSearchIcon", "chat.inputMediaPanel.stickersSearchPrimary", NULL},
    {"chatInputRecordingColor", "chat_recordedVoiceDot", "chat.inputPanel.mediaRecordDot", NULL},
    {"chatInputBotKeyboardBackgroundColor", "chat_emojiPanelBackground", "chat.inputButtonPanel.panelBg", NULL},
    {"chatInputBotKeyboardButtonColor", "chat_botKeyboardButtonBackground", "chat.inputButtonPanel.buttonBg", NULL},
    {"chatInputBotKeyboardButtonHighlightedColor", "chat_botKeyboardButtonBackgroundPressed", "chat.inputButtonPanel.buttonHighlightedBg", NULL},
    {"chatInputBotKeyboardButtonShadowColor", "", "chat.inputButtonPanel.buttonStroke", NULL},
    {"chatInputBotKeyboardButtonTextColor", "chat_botKeyboardButtonText", "chat.inputButtonPanel.buttonText", NULL},
    {"collectionMenuBackgroundColor", "windowBackgroundGray", "list.blocksBg", NULL},
    {"collectionMenuCellBackgroundColor", "windowBackgroundWhite", "list.itemBlocksBg", NULL},
    {"collectionMenuCellSelectionColor", "listSelectorSDK21", "list.itemHighlightedBg", "windowBackgroundWhite"},
    {"collectionMenuTextColor", "windowBackgroundWhiteBlackText", "list.primaryText", NULL},
    {"collectionMenuPlaceholderColor", "windowBackgroundWhiteHintText", "list.placeholderText", NULL},
    {"collectionMenuVariantColor", "windowBackgroundWhiteGrayText2 windowBackgroundWhiteGrayText", "list.secondaryText", NULL},
    {"collectionMenuAccentColor", "windowBackgroundWhiteBlueText4 windowBackgroundWhiteBlueText", "list.accent", NULL},
    {"collectionMenuDestructiveColor", "text_RedRegular", "list.destructive", NULL},
    {"collectionMenuSeparatorColor", "divider", "list.blocksSeparator", NULL},
    {"collectionMenuAccessoryColor", "windowBackgroundWhiteGrayIcon", "list.disclosureArrow", NULL},
    {"collectionMenuCommentColor", "windowBackgroundWhiteGrayText4 windowBackgroundWhiteGrayText", "list.freeText", NULL},
    {"collectionMenuBadgeColor", "chats_unreadCounter", "root.tabBar.badgeBackground", NULL},
    {"collectionMenuBadgeTextColor", "chats_unreadCounterText", "root.tabBar.badgeText", NULL},
    {"collectionMenuSwitchColor", "switchTrackChecked switch2TrackChecked", "list.switch.positive list.switch.content", NULL},
    {"collectionMenuCheckColor", "radioBackgroundChecked windowBackgroundWhiteBlueText4", "list.accent", NULL},
    {"collectionMenuSpinnerColor", "progressCircle", "list.secondaryText", NULL},
    {"menuBackgroundColor", "dialogBackground", "actionSheet.opaqueItemBg", NULL},
    {"menuSelectionColor", "dialogButtonSelector listSelectorSDK21", "actionSheet.opaqueItemHighlightedBg", "dialogBackground"},
    {"menuSeparatorColor", "dialogGrayLine divider", "actionSheet.opaqueItemSeparator", NULL},
    {"menuTextColor", "dialogTextBlack", "actionSheet.primaryText", NULL},
    {"menuSecondaryTextColor", "dialogTextGray3 dialogTextGray", "actionSheet.secondaryText", NULL},
    {"menuLinkColor", "dialogTextLink", "actionSheet.controlAccent", NULL},
    {"menuAccentColor", "dialogTextBlue dialogButton", "actionSheet.standardActionText", NULL},
    {"menuDestructiveColor", "text_RedBold text_RedRegular", "actionSheet.destructiveActionText", NULL},
    {"menuSpinnerColor", "dialogTextGray3", "actionSheet.secondaryText", NULL},
    {"menuSectionHeaderBackgroundColor", "dialogBackgroundGray", "actionSheet.opaqueItemBg", NULL},
    {"musicControlsColor", "player_button", "", NULL},
    {"locationPinColor", "location_sendLocationBackground", "", NULL},
    {"locationAccentColor", "location_actionActiveIcon", "", NULL},
    {"locationLiveColor", "location_sendLiveLocationBackground", "", NULL}
};

static const NSUInteger TGCloudThemeColorMappingCount = sizeof(TGCloudThemeColorMappings) / sizeof(TGCloudThemeColorMappings[0]);

static CGFloat TGCloudThemeLuminance(uint32_t color)
{
    return (0.299f * ((color >> 16) & 0xff) + 0.587f * ((color >> 8) & 0xff) + 0.114f * (color & 0xff)) / 255.0f;
}

static UIColor *TGCloudThemeColor(uint32_t color)
{
    uint32_t rgb = color & 0xffffff;
    return UIColorRGB(rgb);
}

static uint32_t TGCloudThemeMix(uint32_t foreground, uint32_t background, CGFloat amount)
{
    uint32_t result = 0xff000000;
    for (int shift = 0; shift <= 16; shift += 8)
    {
        CGFloat f = (CGFloat)((foreground >> shift) & 0xff);
        CGFloat b = (CGFloat)((background >> shift) & 0xff);
        result |= ((uint32_t)(f * amount + b * (1.0f - amount) + 0.5f) & 0xff) << shift;
    }
    return result;
}

static uint32_t TGCloudThemeComposite(uint32_t color, uint32_t backdrop)
{
    CGFloat alpha = ((color >> 24) & 0xff) / 255.0f;
    return TGCloudThemeMix(color, backdrop, alpha);
}

static NSString *TGCloudThemeTrimmed(NSString *string)
{
    return [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static bool TGCloudThemeParseHex(NSString *string, uint32_t *value)
{
    if ([string hasPrefix:@"#"])
        string = [string substringFromIndex:1];
    if (string.length != 6 && string.length != 8)
        return false;
    for (NSUInteger i = 0; i < string.length; i++)
    {
        unichar c = [string characterAtIndex:i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')))
            return false;
    }
    uint32_t parsed = (uint32_t)strtoul([string UTF8String], NULL, 16);
    *value = string.length == 6 ? (0xff000000 | parsed) : parsed;
    return true;
}

static NSDictionary *TGCloudThemeParseAttheme(NSData *data, UIImage **wallpaperImage)
{
    const char *bytes = data.bytes;
    NSUInteger length = data.length;
    NSUInteger textLength = length;
    for (NSUInteger i = 0; i + 4 <= length; i++)
    {
        if ((i == 0 || bytes[i - 1] == '\n') && memcmp(bytes + i, "WPS\n", 4) == 0)
        {
            textLength = i;
            NSUInteger imageStart = i + 4;
            NSUInteger imageEnd = length;
            for (NSUInteger j = length; j >= imageStart + 4; j--)
            {
                if (memcmp(bytes + j - 4, "\nWPE", 4) == 0)
                {
                    imageEnd = j - 4;
                    break;
                }
            }
            if (wallpaperImage != NULL && imageEnd > imageStart)
                *wallpaperImage = [[UIImage alloc] initWithData:[data subdataWithRange:NSMakeRange(imageStart, imageEnd - imageStart)]];
            break;
        }
    }

    NSString *text = [[NSString alloc] initWithBytes:bytes length:textLength encoding:NSUTF8StringEncoding];
    if (text == nil)
        return nil;
    NSMutableDictionary *colors = [[NSMutableDictionary alloc] init];
    for (NSString *rawLine in [text componentsSeparatedByString:@"\n"])
    {
        NSString *line = TGCloudThemeTrimmed(rawLine);
        NSRange separator = [line rangeOfString:@"="];
        if (line.length == 0 || separator.location == NSNotFound || separator.location == 0)
            continue;
        NSString *key = TGCloudThemeTrimmed([line substringToIndex:separator.location]);
        NSString *value = TGCloudThemeTrimmed([line substringFromIndex:separator.location + 1]);
        if (value.length == 0)
            continue;
        uint32_t color = 0;
        if ([value hasPrefix:@"#"])
        {
            if (!TGCloudThemeParseHex(value, &color))
                continue;
        }
        else
        {
            char *end = NULL;
            long long parsed = strtoll([value UTF8String], &end, 10);
            if (end == NULL || *end != 0)
                continue;
            color = (uint32_t)(int32_t)parsed;
        }
        colors[key] = @(color);
    }
    return colors;
}

static NSDictionary *TGCloudThemeParseTgiosTheme(NSString *text)
{
    NSMutableDictionary *values = [[NSMutableDictionary alloc] init];
    NSMutableArray *path = [[NSMutableArray alloc] init];
    for (NSString *rawLine in [text componentsSeparatedByString:@"\n"])
    {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
        NSString *trimmed = TGCloudThemeTrimmed(line);
        if (trimmed.length == 0 || [trimmed hasPrefix:@"#"] || [trimmed hasPrefix:@"//"])
            continue;
        NSRange colon = [line rangeOfString:@":"];
        if (colon.location == NSNotFound)
            continue;
        NSUInteger indent = 0;
        while (indent < colon.location && [line characterAtIndex:indent] == ' ')
            indent++;
        NSUInteger level = indent / 2;
        while (path.count > level)
            [path removeLastObject];
        NSString *key = TGCloudThemeTrimmed([line substringToIndex:colon.location]);
        NSString *value = TGCloudThemeTrimmed([line substringFromIndex:colon.location + 1]);
        if (key.length == 0)
            continue;
        if (value.length == 0)
        {
            [path addObject:key];
            continue;
        }
        NSString *fullKey = path.count == 0 ? key : [[[path componentsJoinedByString:@"."] stringByAppendingString:@"."] stringByAppendingString:key];
        values[fullKey] = value;
    }
    return values;
}

static NSDictionary *TGCloudThemeTgiosColors(NSDictionary *values)
{
    NSMutableDictionary *colors = [[NSMutableDictionary alloc] init];
    for (NSString *key in values)
    {
        NSString *value = values[key];
        uint32_t color = 0;
        if ([[value lowercaseString] isEqualToString:@"clear"])
            colors[key] = @(0);
        else if (TGCloudThemeParseHex(value, &color))
            colors[key] = @(color);
    }
    return colors;
}

static NSMutableDictionary *TGCloudThemeMapColors(NSDictionary *source, bool attheme)
{
    NSMutableDictionary *colors = [[NSMutableDictionary alloc] init];
    for (NSUInteger i = 0; i < TGCloudThemeColorMappingCount; i++)
    {
        const TGCloudThemeColorMapping *mapping = &TGCloudThemeColorMappings[i];
        NSString *keys = [[NSString alloc] initWithUTF8String:attheme ? mapping->atthemeKeys : mapping->tgiosKeys];
        for (NSString *key in [keys componentsSeparatedByString:@" "])
        {
            NSNumber *value = key.length == 0 ? nil : source[key];
            if (value == nil)
                continue;
            uint32_t color = [value unsignedIntValue];
            if (attheme && mapping->atthemeBackdrop != NULL && ((color >> 24) & 0xff) != 0xff)
            {
                NSNumber *backdrop = source[[[NSString alloc] initWithUTF8String:mapping->atthemeBackdrop]];
                if (backdrop != nil)
                    color = TGCloudThemeComposite(color, TGCloudThemeComposite([backdrop unsignedIntValue], 0xffffffff));
            }
            colors[[[NSString alloc] initWithUTF8String:mapping->selector]] = @(color);
            break;
        }
    }
    return colors;
}

static NSArray *TGCloudThemeIntegerColors(NSArray *values)
{
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    for (NSNumber *value in values)
    {
        if ([value isKindOfClass:[NSNumber class]])
            [colors addObject:@([value unsignedIntValue] & 0xffffff)];
    }
    return colors;
}

static void TGCloudThemeSetColor(NSMutableDictionary *colors, NSArray *selectors, uint32_t argb)
{
    for (NSString *selector in selectors)
        colors[selector] = @(argb);
}

static CGSize TGCloudThemeWallpaperSize(void)
{
    CGSize size = [UIScreen mainScreen].bounds.size;
    return CGSizeMake(MIN(size.width, size.height), MAX(size.width, size.height));
}

@interface TGCloudThemeWallpaperSource : NSObject

@property (nonatomic, strong) NSArray *colors;
@property (nonatomic) int32_t rotation;
@property (nonatomic) int32_t intensity;
@property (nonatomic) bool hasIntensity;
@property (nonatomic) bool pattern;
@property (nonatomic, strong) NSString *slug;
@property (nonatomic, strong) TGDocumentMediaAttachment *document;
@property (nonatomic, strong) UIImage *image;

@end

@implementation TGCloudThemeWallpaperSource

@end

static TGDocumentMediaAttachment *TGCloudThemeDocumentWithDesc(id desc)
{
    if (![desc isKindOfClass:[TLDocument$document class]])
        return nil;
    TGDocumentMediaAttachment *document = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:desc];
    document.originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:((TLDocument$document *)desc).file_reference fileReferences:nil];
    return document;
}

static SSignal *TGCloudThemeDocumentData(TGDocumentMediaAttachment *document)
{
    return [[[TGSharedFileSignals documentData:document priority:true] mapToSignal:^SSignal *(NSArray *signals)
    {
        return signals.count != 0 ? signals[0] : [SSignal fail:nil];
    }] timeout:90.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:nil]];
}

static TGCloudThemeWallpaperSource *TGCloudThemeWallpaperSourceWithObject(TGTLDynamicObject *wallpaper)
{
    if (![wallpaper isKindOfClass:[TGTLDynamicObject class]])
        return nil;
    TGCloudThemeWallpaperSource *source = [[TGCloudThemeWallpaperSource alloc] init];
    TGTLDynamicObject *settings = [wallpaper objectField:@"settings"];
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    for (NSString *name in @[@"background_color", @"second_background_color", @"third_background_color", @"fourth_background_color"])
    {
        if ([settings field:name] != nil)
            [colors addObject:@((uint32_t)[settings int32Field:name] & 0xffffff)];
    }
    source.colors = colors;
    source.rotation = [settings int32Field:@"rotation"];
    if ([settings field:@"intensity"] != nil)
    {
        source.intensity = [settings int32Field:@"intensity"];
        source.hasIntensity = true;
    }
    if ([wallpaper isConstructor:@"wallPaper"])
    {
        source.document = TGCloudThemeDocumentWithDesc([wallpaper field:@"document"]);
        source.pattern = [wallpaper flag:@"pattern"];
    }
    return source;
}

static SSignal *TGCloudThemeWallpaperWithSlug(NSString *slug)
{
    TGTLDynamicObject *input = [TGTLDynamicObject objectWithConstructor:@"inputWallPaperSlug" fields:@{@"slug": slug}];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"account.getWallPaper" parameters:@{@"wallpaper": input}] mapToSignal:^SSignal *(id result)
    {
        TGCloudThemeWallpaperSource *source = TGCloudThemeWallpaperSourceWithObject(result);
        return source != nil ? [SSignal single:source] : [SSignal fail:nil];
    }];
}

static id TGCloudThemeRenderWallpaper(TGCloudThemeWallpaperSource *source, NSData *data, CGSize size)
{
    if (data.length != 0 && !source.pattern)
    {
        UIImage *image = [[UIImage alloc] initWithData:data];
        if (image != nil)
            return image;
    }
    if (source.pattern && data.length != 0)
    {
        UIImage *image = TGCloudThemeWallpaperImage(source.colors, source.rotation, data, source.hasIntensity ? source.intensity : 50, size);
        if (image != nil)
            return image;
    }
    if (source.colors.count == 1)
        return source.colors[0];
    if (source.colors.count > 1)
        return TGCloudThemeWallpaperImage(source.colors, source.rotation, nil, 0, size);
    return nil;
}

static SSignal *TGCloudThemeResolveWallpaper(TGCloudThemeWallpaperSource *source, CGSize size)
{
    if (source == nil)
        return [SSignal single:[NSNull null]];
    if (source.image != nil)
        return [SSignal single:source.image];
    if (source.document == nil && source.slug.length != 0)
    {
        return [[[TGCloudThemeWallpaperWithSlug(source.slug) map:^id(TGCloudThemeWallpaperSource *resolved)
        {
            if (source.colors.count != 0)
            {
                resolved.colors = source.colors;
                resolved.rotation = source.rotation;
            }
            if (source.hasIntensity)
            {
                resolved.intensity = source.intensity;
                resolved.hasIntensity = true;
            }
            return resolved;
        }] catch:^SSignal *(__unused id error)
        {
            TGCloudThemeWallpaperSource *fallback = [[TGCloudThemeWallpaperSource alloc] init];
            fallback.colors = source.colors;
            fallback.rotation = source.rotation;
            return [SSignal single:fallback];
        }] mapToSignal:^SSignal *(TGCloudThemeWallpaperSource *resolved)
        {
            return TGCloudThemeResolveWallpaper(resolved, size);
        }];
    }
    if (source.document != nil)
    {
        return [[TGCloudThemeDocumentData(source.document) map:^id(NSData *data)
        {
            return TGCloudThemeRenderWallpaper(source, data, size) ?: [NSNull null];
        }] catch:^SSignal *(__unused id error)
        {
            return [SSignal single:TGCloudThemeRenderWallpaper(source, nil, size) ?: [NSNull null]];
        }];
    }
    return [[SSignal defer:^SSignal *
    {
        return [SSignal single:TGCloudThemeRenderWallpaper(source, nil, size) ?: [NSNull null]];
    }] startOn:[SQueue concurrentDefaultQueue]];
}

static SSignal *TGCloudThemeRequest(NSString *slug, NSString *format)
{
    TGTLDynamicObject *input = [TGTLDynamicObject objectWithConstructor:@"inputThemeSlug" fields:@{@"slug": slug}];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"account.getTheme" parameters:@{@"format": format, @"theme": input}] mapToSignal:^SSignal *(id result)
    {
        if (![result isKindOfClass:[TGTLDynamicObject class]] || ![(TGTLDynamicObject *)result isConstructor:@"theme"])
            return [SSignal fail:@(TGCloudThemeErrorGeneric)];
        return [SSignal single:result];
    }];
}

@interface TGCloudTheme ()
{
    TGCloudThemeWallpaperSource *_wallpaperSource;
    UIImage *_wallpaperImage;
    NSNumber *_wallpaperColor;
    TGWallpaperInfo *_wallpaperInfo;
    TGPresentationPallete *_previewPallete;
    NSString *_wallpaperFileName;
}

@property (nonatomic, strong) NSString *identifier;

@property (nonatomic) int64_t themeId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic, strong) NSString *slug;
@property (nonatomic, strong) NSString *title;
@property (nonatomic) TGCloudThemeBase base;
@property (nonatomic, strong) NSDictionary *colors;
@property (nonatomic, strong) UIColor *accentColor;

@end

@implementation TGCloudTheme

+ (bool)isThemeFileName:(NSString *)fileName mimeType:(NSString *)mimeType
{
    NSString *extension = [[fileName pathExtension] lowercaseString];
    if ([extension isEqualToString:@"attheme"] || [extension isEqualToString:@"tgios-theme"])
        return true;
    NSString *mime = [mimeType lowercaseString];
    return [mime isEqualToString:@"application/x-tgtheme-android"] || [mime isEqualToString:@"application/x-tgtheme-ios"];
}

+ (NSString *)titleWithFileName:(NSString *)fileName
{
    NSString *title = [[fileName stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    return TGCloudThemeTrimmed(title);
}

+ (TGCloudTheme *)themeWithAtthemeData:(NSData *)data
{
    UIImage *image = nil;
    NSDictionary *source = TGCloudThemeParseAttheme(data, &image);
    NSNumber *background = source[@"windowBackgroundWhite"];
    if (source.count == 0 || background == nil)
        return nil;

    NSMutableDictionary *colors = TGCloudThemeMapColors(source, true);
    uint32_t backgroundColor = [background unsignedIntValue];
    TGCloudThemeBase base = TGCloudThemeBaseClassic;
    if (TGCloudThemeLuminance(backgroundColor) < 0.5f)
    {
        CGFloat red = ((backgroundColor >> 16) & 0xff) / 255.0f;
        CGFloat blue = (backgroundColor & 0xff) / 255.0f;
        base = blue - red > 0.06f ? TGCloudThemeBaseNightTinted : TGCloudThemeBaseNight;
    }

    NSNumber *bar = source[@"actionBarDefault"];
    NSNumber *icon = source[@"actionBarDefaultIcon"];
    if (bar != nil && icon != nil)
    {
        uint32_t barColor = TGCloudThemeComposite([bar unsignedIntValue], backgroundColor);
        uint32_t inactive = TGCloudThemeMix([icon unsignedIntValue], barColor, 0.55f);
        colors[@"tabIconColor"] = @(inactive);
        colors[@"tabTextColor"] = @(inactive);
        NSNumber *accent = colors[@"accentColor"];
        NSNumber *title = source[@"actionBarDefaultTitle"] ?: icon;
        bool accentVisible = accent != nil && fabs(TGCloudThemeLuminance([accent unsignedIntValue]) - TGCloudThemeLuminance(barColor)) >= 0.25f;
        colors[@"tabActiveIconColor"] = accentVisible ? accent : title;
    }

    TGCloudTheme *theme = [[TGCloudTheme alloc] init];
    theme.base = base;
    theme.colors = colors;
    NSNumber *accent = colors[@"accentColor"];
    theme.accentColor = accent != nil ? TGCloudThemeColor([accent unsignedIntValue]) : nil;

    TGCloudThemeWallpaperSource *wallpaper = nil;
    if (image != nil)
    {
        wallpaper = [[TGCloudThemeWallpaperSource alloc] init];
        wallpaper.image = image;
    }
    else if (source[@"chat_wallpaper"] != nil)
    {
        NSMutableArray *wallpaperColors = [[NSMutableArray alloc] initWithObjects:@([source[@"chat_wallpaper"] unsignedIntValue] & 0xffffff), nil];
        for (NSString *key in @[@"chat_wallpaper_gradient_to1", @"chat_wallpaper_gradient_to2", @"chat_wallpaper_gradient_to3"])
        {
            NSNumber *value = source[key];
            if (value == nil && [key isEqualToString:@"chat_wallpaper_gradient_to1"])
                value = source[@"chat_wallpaper_gradient_to"];
            if (value != nil)
                [wallpaperColors addObject:@([value unsignedIntValue] & 0xffffff)];
        }
        wallpaper = [[TGCloudThemeWallpaperSource alloc] init];
        wallpaper.colors = wallpaperColors;
        wallpaper.rotation = (int32_t)[source[@"chat_wallpaper_gradient_rotation"] intValue];
    }
    theme->_wallpaperSource = wallpaper;
    return theme;
}

+ (TGCloudThemeWallpaperSource *)wallpaperSourceWithTgiosValue:(NSString *)value
{
    if (value.length == 0 || [[value lowercaseString] isEqualToString:@"builtin"])
        return nil;
    TGCloudThemeWallpaperSource *source = [[TGCloudThemeWallpaperSource alloc] init];
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    bool hasRotation = false;
    NSArray *components = [value componentsSeparatedByString:@" "];
    for (NSUInteger i = 0; i < components.count; i++)
    {
        NSString *component = components[i];
        uint32_t color = 0;
        if (component.length == 0 || [component isEqualToString:@"motion"] || [component isEqualToString:@"blur"])
            continue;
        if (i == 0 && component.length > 8)
            source.slug = component;
        else if (TGCloudThemeParseHex(component, &color))
            [colors addObject:@(color & 0xffffff)];
        else if (component.length <= 4 && [component intValue] != 0)
        {
            if (!source.hasIntensity)
            {
                int32_t intensity = (int32_t)[component intValue];
                source.intensity = (intensity >= -100 && intensity <= 100) ? intensity : 50;
                source.hasIntensity = true;
            }
            else if (!hasRotation)
            {
                source.rotation = (int32_t)[component intValue];
                hasRotation = true;
            }
        }
    }
    source.colors = colors;
    source.pattern = source.slug != nil && colors.count != 0;
    if (source.slug == nil && colors.count == 0)
        return nil;
    return source;
}

+ (TGCloudTheme *)themeWithTgiosString:(NSString *)string
{
    NSDictionary *values = TGCloudThemeParseTgiosTheme(string);
    if (values.count == 0)
        return nil;
    NSMutableDictionary *colors = TGCloudThemeMapColors(TGCloudThemeTgiosColors(values), false);
    if (colors.count == 0)
        return nil;

    NSString *basedOn = [values[@"basedOn"] lowercaseString];
    TGCloudThemeBase base = TGCloudThemeBaseClassic;
    if ([basedOn isEqualToString:@"day"])
        base = TGCloudThemeBaseDay;
    else if ([basedOn isEqualToString:@"night"])
        base = TGCloudThemeBaseNight;
    else if ([basedOn isEqualToString:@"nighttinted"])
        base = TGCloudThemeBaseNightTinted;
    else if (basedOn == nil && [[values[@"dark"] lowercaseString] isEqualToString:@"true"])
        base = TGCloudThemeBaseNight;

    TGCloudTheme *theme = [[TGCloudTheme alloc] init];
    theme.base = base;
    theme.colors = colors;
    NSNumber *accent = colors[@"accentColor"];
    theme.accentColor = accent != nil ? TGCloudThemeColor([accent unsignedIntValue]) : nil;
    NSString *name = values[@"name"];
    if (name.length != 0)
        theme.title = name;
    theme->_wallpaperSource = [self wallpaperSourceWithTgiosValue:values[@"chat.defaultWallpaper"]];
    return theme;
}

+ (TGCloudTheme *)themeWithSettings:(TGTLDynamicObject *)settings
{
    if (![settings isKindOfClass:[TGTLDynamicObject class]])
        return nil;
    TGTLDynamicObject *baseTheme = [settings objectField:@"base_theme"];
    TGCloudThemeBase base = TGCloudThemeBaseClassic;
    if ([baseTheme isConstructor:@"baseThemeDay"] || [baseTheme isConstructor:@"baseThemeArctic"])
        base = TGCloudThemeBaseDay;
    else if ([baseTheme isConstructor:@"baseThemeNight"])
        base = TGCloudThemeBaseNight;
    else if ([baseTheme isConstructor:@"baseThemeTinted"])
        base = TGCloudThemeBaseNightTinted;

    uint32_t accent = (uint32_t)[settings int32Field:@"accent_color"] & 0xffffff;
    NSMutableDictionary *colors = [[NSMutableDictionary alloc] init];
    if (base != TGCloudThemeBaseDay)
        TGCloudThemeSetColor(colors, [TGPresentationCustomColors selectorNamesForParameterIdentifier:@"Accent"], 0xff000000 | accent);

    NSArray *messageColors = TGCloudThemeIntegerColors([settings arrayField:@"message_colors"]);
    if (messageColors.count != 0)
    {
        CGFloat r = 0.0f, g = 0.0f, b = 0.0f;
        for (NSNumber *value in messageColors)
        {
            uint32_t color = [value unsignedIntValue];
            r += (color >> 16) & 0xff;
            g += (color >> 8) & 0xff;
            b += color & 0xff;
        }
        CGFloat count = (CGFloat)messageColors.count;
        uint32_t bubble = 0xff000000 | ((uint32_t)(r / count) << 16) | ((uint32_t)(g / count) << 8) | (uint32_t)(b / count);
        bool lightBubble = TGCloudThemeLuminance(bubble) > 0.65f;
        uint32_t text = lightBubble ? 0xff000000 : 0xffffffff;
        uint32_t secondary = TGCloudThemeMix(text, bubble, 0.6f);
        uint32_t outgoingAccent = [settings field:@"outbox_accent_color"] != nil ? (0xff000000 | ((uint32_t)[settings int32Field:@"outbox_accent_color"] & 0xffffff)) : text;
        TGCloudThemeSetColor(colors, [TGPresentationCustomColors selectorNamesForParameterIdentifier:@"OutgoingBubble"], bubble);
        TGCloudThemeSetColor(colors, @[@"chatOutgoingHighlightedBubbleColor", @"chatOutgoingHighlightedBubbleBorderColor"], TGCloudThemeMix(lightBubble ? 0xff000000 : 0xffffffff, bubble, 0.12f));
        TGCloudThemeSetColor(colors, @[@"chatOutgoingTextColor"], text);
        TGCloudThemeSetColor(colors, @[@"chatOutgoingSubtextColor", @"chatOutgoingDateColor", @"chatChecksColor"], secondary);
        TGCloudThemeSetColor(colors, @[@"chatOutgoingLinkColor", @"chatOutgoingAccentColor", @"chatOutgoingLineColor", @"chatOutgoingButtonColor", @"chatOutgoingAudioForegroundColor", @"chatOutgoingAudioDotColor"], outgoingAccent);
        TGCloudThemeSetColor(colors, @[@"chatOutgoingButtonIconColor"], bubble);
        TGCloudThemeSetColor(colors, @[@"chatOutgoingAudioBackgroundColor"], TGCloudThemeMix(outgoingAccent, bubble, 0.3f));
    }

    TGCloudTheme *theme = [[TGCloudTheme alloc] init];
    theme.base = base;
    theme.colors = colors;
    theme.accentColor = UIColorRGB(accent);
    theme->_wallpaperSource = TGCloudThemeWallpaperSourceWithObject([settings objectField:@"wallpaper"]);
    return theme;
}

+ (TGCloudTheme *)themeWithData:(NSData *)data fileName:(NSString *)fileName mimeType:(NSString *)mimeType
{
    if (data.length == 0)
        return nil;
    NSString *extension = [[fileName pathExtension] lowercaseString];
    bool ios = [extension isEqualToString:@"tgios-theme"] || [[mimeType lowercaseString] isEqualToString:@"application/x-tgtheme-ios"];
    bool android = [extension isEqualToString:@"attheme"] || [[mimeType lowercaseString] isEqualToString:@"application/x-tgtheme-android"];
    TGCloudTheme *theme = nil;
    if (!android)
    {
        NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (string != nil && (ios || [string rangeOfString:@"\nchat:"].location != NSNotFound || [string rangeOfString:@"basedOn:"].location != NSNotFound))
            theme = [self themeWithTgiosString:string];
    }
    if (theme == nil && !ios)
        theme = [self themeWithAtthemeData:data];
    if (theme != nil && theme.title.length == 0)
        theme.title = [self titleWithFileName:fileName];
    return theme;
}

+ (SSignal *)themeSignalWithObject:(TGTLDynamicObject *)object allowSettings:(bool)allowSettings preferDark:(bool)preferDark
{
    TGCloudTheme *(^applyObject)(TGCloudTheme *) = ^TGCloudTheme *(TGCloudTheme *theme)
    {
        theme.themeId = [object int64Field:@"id"];
        theme.accessHash = [object int64Field:@"access_hash"];
        theme.slug = [object stringField:@"slug"];
        NSString *title = [object stringField:@"title"];
        if (title.length != 0)
            theme.title = title;
        return theme;
    };

    TGDocumentMediaAttachment *document = TGCloudThemeDocumentWithDesc([object field:@"document"]);
    if (document != nil && [self isThemeFileName:document.fileName mimeType:document.mimeType])
    {
        return [[TGCloudThemeDocumentData(document) catch:^SSignal *(__unused id error)
        {
            return [SSignal fail:@(TGCloudThemeErrorGeneric)];
        }] mapToSignal:^SSignal *(NSData *data)
        {
            TGCloudTheme *theme = [self themeWithData:data fileName:document.fileName mimeType:document.mimeType];
            if (theme == nil)
                return [SSignal fail:@(TGCloudThemeErrorUnsupported)];
            return [SSignal single:applyObject(theme)];
        }];
    }

    NSArray *settings = [object arrayField:@"settings"];
    if (allowSettings && settings.count != 0)
    {
        TGTLDynamicObject *selectedSettings = settings.firstObject;
        for (TGTLDynamicObject *candidate in settings)
        {
            if (![candidate isKindOfClass:[TGTLDynamicObject class]])
                continue;
            TGTLDynamicObject *baseTheme = [candidate objectField:@"base_theme"];
            bool dark = [baseTheme isConstructor:@"baseThemeNight"] || [baseTheme isConstructor:@"baseThemeTinted"];
            if (dark == preferDark)
            {
                selectedSettings = candidate;
                break;
            }
        }
        TGCloudTheme *theme = [self themeWithSettings:selectedSettings];
        if (theme != nil)
            return [SSignal single:applyObject(theme)];
    }
    return nil;
}

+ (SSignal *)themeWithSlug:(NSString *)slug
{
    if (slug.length == 0)
        return [SSignal fail:@(TGCloudThemeErrorGeneric)];
    CGSize size = TGCloudThemeWallpaperSize();
    bool preferDark = [TGPresentation current].pallete.isDark;
    return [[TGCloudThemeRequest(slug, @"ios") mapToSignal:^SSignal *(TGTLDynamicObject *object)
    {
        SSignal *signal = [self themeSignalWithObject:object allowSettings:true preferDark:preferDark];
        if (signal != nil)
            return signal;
        return [TGCloudThemeRequest(slug, @"android") mapToSignal:^SSignal *(TGTLDynamicObject *androidObject)
        {
            return [self themeSignalWithObject:androidObject allowSettings:false preferDark:preferDark] ?: [SSignal fail:@(TGCloudThemeErrorUnsupported)];
        }];
    }] mapToSignal:^SSignal *(TGCloudTheme *theme)
    {
        return [theme resolvedSignalWithSize:size];
    }];
}

+ (SSignal *)themeWithFileAtPath:(NSString *)path fileName:(NSString *)fileName
{
    CGSize size = TGCloudThemeWallpaperSize();
    return [[[SSignal defer:^SSignal *
    {
        TGCloudTheme *theme = [self themeWithData:[[NSData alloc] initWithContentsOfFile:path] fileName:fileName mimeType:nil];
        return theme != nil ? [SSignal single:theme] : [SSignal fail:@(TGCloudThemeErrorUnsupported)];
    }] startOn:[SQueue concurrentDefaultQueue]] mapToSignal:^SSignal *(TGCloudTheme *theme)
    {
        return [theme resolvedSignalWithSize:size];
    }];
}

- (SSignal *)resolvedSignalWithSize:(CGSize)size
{
    return [TGCloudThemeResolveWallpaper(_wallpaperSource, size) map:^id(id wallpaper)
    {
        if ([wallpaper isKindOfClass:[UIImage class]])
            _wallpaperImage = wallpaper;
        else if ([wallpaper isKindOfClass:[NSNumber class]])
            _wallpaperColor = wallpaper;
        _wallpaperSource = nil;
        return self;
    }];
}

- (bool)isDark
{
    return _base == TGCloudThemeBaseNight || _base == TGCloudThemeBaseNightTinted;
}

- (TGPresentationPallete *)basePallete
{
    switch (_base)
    {
        case TGCloudThemeBaseDay:
            return _accentColor != nil ? [TGDayPresentationPallete dayPalleteWithAccentColor:_accentColor] : [[TGDayPresentationPallete alloc] init];
        case TGCloudThemeBaseNight:
            return [[TGNightPresentationPallete alloc] init];
        case TGCloudThemeBaseNightTinted:
            return [[TGNightBluePresentationPallete alloc] init];
        default:
            return [[TGDefaultPresentationPallete alloc] init];
    }
}

- (TGPresentationPallete *)previewPallete
{
    if (_previewPallete == nil)
        _previewPallete = [TGPresentationCustomColors previewPalleteWithPallete:[self basePallete] themeColors:_colors];
    return _previewPallete;
}

- (TGWallpaperInfo *)wallpaperInfo
{
    if (_wallpaperInfo != nil)
        return _wallpaperInfo;
    if (_wallpaperImage == nil && _wallpaperFileName != nil)
        _wallpaperImage = [[UIImage alloc] initWithContentsOfFile:[[TGCloudTheme storageDirectory] stringByAppendingPathComponent:_wallpaperFileName]];
    if (_wallpaperImage != nil)
    {
        _wallpaperInfo = [[TGCustomImageWallpaperInfo alloc] initWithImage:_wallpaperImage];
        return _wallpaperInfo;
    }
    NSNumber *color = _wallpaperColor;
    if (color == nil)
    {
        if (![self isDark])
        {
            _wallpaperInfo = [[TGWallpaperManager instance] builtinWallpaperList].firstObject;
            return _wallpaperInfo;
        }
        color = _colors[@"backgroundColor"] ?: @(TGColorHexCode([self previewPallete].backgroundColor));
    }
    uint32_t rgb = [color unsignedIntValue] & 0xffffff;
    if (TGCloudThemeLuminance(rgb) < 0.5f)
        _wallpaperInfo = [[TGColorWallpaperInfo alloc] initWithColor:rgb tintColor:0xffffff systemAlpha:0.2f buttonsAlpha:0.3f highlightedButtonAlpha:0.45f progressAlpha:0.3f];
    else
        _wallpaperInfo = [[TGColorWallpaperInfo alloc] initWithColor:rgb];
    return _wallpaperInfo;
}

+ (NSString *)storageDirectory
{
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) firstObject];
    NSString *directory = [documents stringByAppendingPathComponent:@"onegram-themes"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:NULL];
    return directory;
}

+ (TGCloudThemeBase)baseForPalleteClassName:(NSString *)className
{
    if ([className isEqualToString:NSStringFromClass([TGDayPresentationPallete class])])
        return TGCloudThemeBaseDay;
    if ([className isEqualToString:NSStringFromClass([TGNightPresentationPallete class])])
        return TGCloudThemeBaseNight;
    if ([className isEqualToString:NSStringFromClass([TGNightBluePresentationPallete class])])
        return TGCloudThemeBaseNightTinted;
    return TGCloudThemeBaseClassic;
}

+ (NSMutableArray *)storedRecords
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *stored = [defaults objectForKey:TGCloudThemeStoredThemesKey];
    NSMutableArray *records = [[NSMutableArray alloc] init];
    for (NSDictionary *record in [stored isKindOfClass:[NSArray class]] ? stored : @[])
    {
        if ([record isKindOfClass:[NSDictionary class]] && [record[@"id"] isKindOfClass:[NSString class]])
            [records addObject:record];
    }

    NSDictionary *legacy = [defaults objectForKey:TGCloudThemeLegacyDefaultsKey];
    if ([legacy isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *themeColors = [TGPresentationCustomColors themeColorsByPalleteClassName];
        NSString *className = themeColors.allKeys.firstObject;
        if (className != nil && records.count == 0)
        {
            NSDictionary *colors = themeColors[className];
            NSString *slug = [legacy[@"slug"] isKindOfClass:[NSString class]] ? legacy[@"slug"] : nil;
            NSMutableDictionary *record = [[NSMutableDictionary alloc] init];
            record[@"id"] = slug.length != 0 ? [@"slug:" stringByAppendingString:slug] : @"local:migrated";
            record[@"title"] = [legacy[@"title"] isKindOfClass:[NSString class]] ? legacy[@"title"] : @"";
            if (slug.length != 0)
                record[@"slug"] = slug;
            record[@"base"] = @([self baseForPalleteClassName:className]);
            record[@"colors"] = colors;
            if ([colors[@"accentColor"] isKindOfClass:[NSNumber class]])
                record[@"accent"] = @([colors[@"accentColor"] unsignedIntValue] & 0xffffff);
            [records addObject:record];
            [defaults setObject:record[@"id"] forKey:TGCloudThemeActiveThemeKey];
        }
        [defaults removeObjectForKey:TGCloudThemeLegacyDefaultsKey];
        [defaults setObject:records forKey:TGCloudThemeStoredThemesKey];
        [defaults synchronize];
    }
    return records;
}

+ (void)saveRecords:(NSArray *)records
{
    [[NSUserDefaults standardUserDefaults] setObject:records forKey:TGCloudThemeStoredThemesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (TGCloudTheme *)themeWithRecord:(NSDictionary *)record
{
    TGCloudTheme *theme = [[TGCloudTheme alloc] init];
    theme.identifier = record[@"id"];
    theme.title = [record[@"title"] isKindOfClass:[NSString class]] ? record[@"title"] : @"";
    theme.slug = [record[@"slug"] isKindOfClass:[NSString class]] ? record[@"slug"] : nil;
    theme.themeId = [record[@"themeId"] longLongValue];
    theme.accessHash = [record[@"accessHash"] longLongValue];
    theme.base = (TGCloudThemeBase)[record[@"base"] intValue];
    theme.colors = [record[@"colors"] isKindOfClass:[NSDictionary class]] ? record[@"colors"] : @{};
    if ([record[@"accent"] isKindOfClass:[NSNumber class]])
        theme.accentColor = TGCloudThemeColor([record[@"accent"] unsignedIntValue]);
    if ([record[@"wallpaperColor"] isKindOfClass:[NSNumber class]])
        theme->_wallpaperColor = record[@"wallpaperColor"];
    if ([record[@"wallpaperFile"] isKindOfClass:[NSString class]])
        theme->_wallpaperFileName = record[@"wallpaperFile"];
    return theme;
}

- (NSDictionary *)recordWithIdentifier:(NSString *)identifier
{
    NSMutableDictionary *record = [[NSMutableDictionary alloc] init];
    record[@"id"] = identifier;
    record[@"title"] = _title ?: @"";
    if (_slug.length != 0)
        record[@"slug"] = _slug;
    if (_themeId != 0)
    {
        record[@"themeId"] = @(_themeId);
        record[@"accessHash"] = @(_accessHash);
    }
    record[@"base"] = @(_base);
    record[@"colors"] = _colors ?: @{};
    if (_accentColor != nil)
        record[@"accent"] = @(TGColorHexCode(_accentColor) & 0xffffff);
    if (_wallpaperColor != nil)
        record[@"wallpaperColor"] = _wallpaperColor;

    if (_wallpaperImage != nil && _wallpaperFileName == nil)
    {
        NSCharacterSet *invalid = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
        NSString *fileName = [[[identifier componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"] stringByAppendingPathExtension:@"jpg"];
        NSData *data = UIImageJPEGRepresentation(_wallpaperImage, 0.92f);
        if (data != nil && [data writeToFile:[[TGCloudTheme storageDirectory] stringByAppendingPathComponent:fileName] atomically:true])
            _wallpaperFileName = fileName;
    }
    if (_wallpaperFileName != nil)
        record[@"wallpaperFile"] = _wallpaperFileName;
    return record;
}

+ (NSArray *)storedThemes
{
    NSMutableArray *themes = [[NSMutableArray alloc] init];
    for (NSDictionary *record in [self storedRecords])
        [themes addObject:[self themeWithRecord:record]];
    return themes;
}

+ (NSString *)activeThemeIdentifier
{
    [self storedRecords];
    NSString *identifier = [[NSUserDefaults standardUserDefaults] objectForKey:TGCloudThemeActiveThemeKey];
    return [identifier isKindOfClass:[NSString class]] ? identifier : nil;
}

- (void)store
{
    NSMutableArray *records = [TGCloudTheme storedRecords];
    NSUInteger existingIndex = NSNotFound;
    for (NSUInteger i = 0; i < records.count; i++)
    {
        NSDictionary *record = records[i];
        bool sameIdentifier = _identifier != nil && [record[@"id"] isEqualToString:_identifier];
        bool sameSlug = _slug.length != 0 && [record[@"slug"] isEqualToString:_slug];
        bool sameFile = _slug.length == 0 && [record[@"slug"] length] == 0 && [record[@"title"] isEqualToString:_title ?: @""];
        if (sameIdentifier || sameSlug || sameFile)
        {
            existingIndex = i;
            break;
        }
    }
    if (existingIndex != NSNotFound)
    {
        NSDictionary *existing = records[existingIndex];
        NSString *existingFile = existing[@"wallpaperFile"];
        if (_identifier == nil)
            _identifier = existing[@"id"];
        if ([existingFile isKindOfClass:[NSString class]] && ![existingFile isEqualToString:_wallpaperFileName ?: @""])
            [[NSFileManager defaultManager] removeItemAtPath:[[TGCloudTheme storageDirectory] stringByAppendingPathComponent:existingFile] error:NULL];
    }
    if (_identifier == nil)
        _identifier = _slug.length != 0 ? [@"slug:" stringByAppendingString:_slug] : [[NSString alloc] initWithFormat:@"local:%08x%08x", arc4random(), arc4random()];
    NSDictionary *record = [self recordWithIdentifier:_identifier];
    if (existingIndex != NSNotFound)
        [records replaceObjectAtIndex:existingIndex withObject:record];
    else
        [records addObject:record];
    [TGCloudTheme saveRecords:records];
}

- (void)apply
{
    TGPresentationPallete *pallete = [self basePallete];
    [TGPresentationCustomColors setThemeColors:_colors forPalleteClass:[pallete class]];
    if (_identifier != nil)
    {
        [[NSUserDefaults standardUserDefaults] setObject:_identifier forKey:TGCloudThemeActiveThemeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    TGWallpaperInfo *wallpaperInfo = [self wallpaperInfo];
    if (wallpaperInfo != nil && ![TGPresentation brandedIOS6Style])
        [[TGWallpaperManager instance] setCurrentWallpaperWithInfo:wallpaperInfo];
    [TGPresentation switchToPallete:pallete];
}

- (void)install
{
    [self store];
    [self apply];

    if (_themeId != 0)
    {
        TGTLDynamicObject *input = [TGTLDynamicObject objectWithConstructor:@"inputTheme" fields:@{@"id": @(_themeId), @"access_hash": @(_accessHash)}];
        [[TGTLDynamicRpc requestSignalWithMethod:@"account.installTheme" parameters:@{@"theme": input, @"format": @"ios"}] startWithNext:nil error:nil completed:nil];
    }
}

+ (void)resetInstalledTheme
{
    if ([self activeThemeIdentifier] == nil)
        return;
    [TGPresentationCustomColors setThemeColors:nil forPalleteClass:Nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGCloudThemeActiveThemeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (bool)removeStoredThemeWithIdentifier:(NSString *)identifier
{
    if (identifier == nil)
        return false;
    NSMutableArray *records = [self storedRecords];
    for (NSUInteger i = 0; i < records.count; i++)
    {
        NSDictionary *record = records[i];
        if (![record[@"id"] isEqualToString:identifier])
            continue;
        NSString *file = record[@"wallpaperFile"];
        if ([file isKindOfClass:[NSString class]])
            [[NSFileManager defaultManager] removeItemAtPath:[[self storageDirectory] stringByAppendingPathComponent:file] error:NULL];
        [records removeObjectAtIndex:i];
        [self saveRecords:records];
        bool wasActive = [[self activeThemeIdentifier] isEqualToString:identifier];
        if (wasActive)
            [self resetInstalledTheme];
        return wasActive;
    }
    return false;
}

- (Class)basePalleteClass
{
    return [[self basePallete] class];
}

@end
