#import "OGTheme.h"
#import "OGPalette.h"
#import "OGTypography.h"
#import "OGMetrics.h"
#import "OGAssets.h"
#import "OGSettingsAppearance.h"
#import "OGProfileAppearance.h"
#import "OGNavigationAppearance.h"
#import "OGTabBarAppearance.h"
#import "OGMusicPlayerScreenAppearance.h"
#import "OGDialogListAppearance.h"
#import "OGConversationAppearance.h"
#import "OGSearchBarAppearance.h"
#import "OGContactListAppearance.h"
#import "OGMusicPlayerAppearance.h"
#import "OGCommunitySheetAppearance.h"
#import "OGSurfaceRenderer.h"
#import "../../OnegramPlatform/OGPlatformVersion.h"

static OGTheme *OGCurrentTheme = nil;
static BOOL OGBrandedThemeDark = NO;

@implementation OGTheme

+ (OGTheme *)themeForKind:(OGThemeKind)kind dark:(BOOL)dark
{
    BOOL branded = kind == OGThemeKindBranded;
    OGTheme *theme = [[OGTheme alloc] init];
    theme.kind = kind;
    theme.dark = dark;

    OGPalette *palette = [[OGPalette alloc] init];
    palette.backgroundColor = [UIColor colorWithWhite:0.93f alpha:1.0f];
    palette.cardColor = [UIColor whiteColor];
    palette.primaryTextColor = branded ? [UIColor blackColor] : [UIColor colorWithWhite:0.07f alpha:1.0f];
    palette.secondaryTextColor = [UIColor colorWithWhite:0.45f alpha:1.0f];
    palette.accentColor = [UIColor colorWithRed:0.16f green:0.47f blue:0.72f alpha:1.0f];
    palette.separatorColor = [UIColor colorWithWhite:0.44f alpha:0.28f];
    palette.selectionColor = [UIColor colorWithWhite:0.82f alpha:1.0f];
    palette.accessoryColor = [UIColor colorWithWhite:0.48f alpha:1.0f];
    palette.badgeTextColor = [UIColor whiteColor];
    palette.badgeColor = [UIColor colorWithRed:0.776f green:0.004f blue:0.004f alpha:1.0f];
    palette.badgeTopColor = [UIColor colorWithRed:0.776f green:0.004f blue:0.004f alpha:1.0f];
    palette.badgeBottomColor = [UIColor colorWithRed:0.404f green:0.035f blue:0.035f alpha:1.0f];
    palette.badgeBorderColor = [UIColor whiteColor];
    palette.badgeGlossColor = [UIColor colorWithWhite:1.0f alpha:0.32f];
    palette.badgeShadowColor = [UIColor colorWithWhite:0.0f alpha:0.42f];
    palette.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
    palette.presenceOnlineColor = [UIColor colorWithRed:0.20f green:0.72f blue:0.25f alpha:1.0f];
    palette.incomingBubbleColor = [UIColor whiteColor];
    palette.outgoingBubbleColor = [UIColor colorWithRed:0.82f green:0.93f blue:0.78f alpha:1.0f];
    palette.messageMetaColor = [UIColor colorWithWhite:0.42f alpha:1.0f];
    theme.palette = palette;

    OGTypography *typography = [[OGTypography alloc] init];
    typography.bodyFont = [UIFont systemFontOfSize:17.0f];
    typography.secondaryFont = [UIFont systemFontOfSize:15.0f];
    typography.settingsTitleFont = branded ? [UIFont boldSystemFontOfSize:18.0f] : [UIFont systemFontOfSize:17.0f];
    typography.dialogTitleFont = [UIFont boldSystemFontOfSize:16.0f];
    typography.dialogPreviewFont = [UIFont systemFontOfSize:14.0f];
    typography.dialogDateFont = [UIFont systemFontOfSize:12.0f];
    typography.messageFont = [UIFont systemFontOfSize:16.0f];
    typography.messageMetaFont = [UIFont systemFontOfSize:11.0f];
    typography.badgeFont = [UIFont boldSystemFontOfSize:12.0f];
    typography.navigationTitleFont = [UIFont boldSystemFontOfSize:20.0f];
    typography.sectionHeaderFont = [UIFont boldSystemFontOfSize:13.0f];
    theme.typography = typography;

    CGFloat scale = OGPlatformScreenScale();
    OGMetrics *metrics = [[OGMetrics alloc] init];
    metrics.pixel = 1.0f / MAX(1.0f, scale);
    metrics.navigationBarHeight = 44.0f;
    metrics.tabBarHeight = 49.0f;
    metrics.settingsRowHeight = 44.0f;
    metrics.settingsIconX = 17.0f;
    metrics.settingsIconSize = 16.0f;
    metrics.settingsTitleX = 43.0f;
    metrics.settingsTitleY = 7.0f;
    metrics.settingsTitleHeight = 22.0f;
    metrics.settingsAccessoryRight = 23.0f;
    metrics.settingsControlRight = 14.0f;
    metrics.settingsVerticalOffset = 1.0f;
    metrics.iconShadowOpacity = 0.10f;
    metrics.iconShadowRadius = 0.5f;
    metrics.iconShadowOffset = CGSizeMake(0.0f, 1.0f);
    metrics.badgeMinimumWidth = 18.0f;
    metrics.badgeHeight = 18.0f;
    metrics.badgeHorizontalPadding = 5.0f;
    metrics.badgeBorderWidth = MAX(metrics.pixel, 2.0f / MAX(1.0f, scale));
    metrics.badgeTextVerticalOffset = -1.0f;
    metrics.badgeShadowOffset = metrics.pixel;
    metrics.avatarSize = 40.0f;
    metrics.dialogRowHeight = 72.0f;
    metrics.dialogHorizontalInset = 8.0f;
    metrics.listHorizontalInset = 8.0f;
    metrics.listIconSpacing = 10.0f;
    metrics.listAccessorySpacing = 8.0f;
    metrics.separatorHeight = metrics.pixel;
    metrics.presenceDiameter = 10.0f;
    theme.metrics = metrics;

    OGAssets *assets = [[OGAssets alloc] init];
    theme.assets = assets;
    theme.surfaceRenderer = [[OGSurfaceRenderer alloc] initWithAssets:assets];

    if (kind == OGThemeKindBranded)
    {
        theme.settingsAppearance = [OGSettingsAppearance brandedAppearanceDark:dark];
        theme.profileAppearance = [OGProfileAppearance brandedAppearanceDark:dark];
        theme.navigationAppearance = [OGNavigationAppearance brandedAppearanceDark:dark];
        theme.tabBarAppearance = [OGTabBarAppearance brandedAppearance];
        theme.dialogListAppearance = [OGDialogListAppearance brandedAppearanceDark:dark];
        theme.conversationAppearance = [OGConversationAppearance brandedAppearanceDark:dark];
        theme.searchBarAppearance = [OGSearchBarAppearance brandedAppearanceDark:dark];
        theme.contactListAppearance = [OGContactListAppearance brandedAppearanceDark:dark];
        theme.musicPlayerAppearance = [OGMusicPlayerAppearance brandedAppearanceDark:dark];
        theme.musicPlayerScreenAppearance = [OGMusicPlayerScreenAppearance brandedAppearance];
        theme.communitySheetAppearance = [OGCommunitySheetAppearance brandedAppearanceDark:dark navigationAppearance:theme.navigationAppearance];
    }
    else if (kind == OGThemeKindClassic)
    {
        theme.settingsAppearance = [OGSettingsAppearance classicAppearance];
        theme.profileAppearance = [OGProfileAppearance classicAppearance];
        theme.navigationAppearance = [OGNavigationAppearance classicAppearance];
    }
    else
    {
        theme.settingsAppearance = [OGSettingsAppearance modernAppearance];
        theme.profileAppearance = [OGProfileAppearance modernAppearance];
        theme.navigationAppearance = [OGNavigationAppearance modernAppearance];
    }

    return theme;
}

+ (OGTheme *)brandedTheme
{
    BOOL dark = NO;
    @synchronized(self)
    {
        dark = OGBrandedThemeDark;
    }
    return [self brandedThemeDark:dark];
}

+ (OGTheme *)brandedThemeDark:(BOOL)dark
{
    static OGTheme *lightTheme = nil;
    static OGTheme *darkTheme = nil;
    @synchronized(self)
    {
        if (dark)
        {
            if (darkTheme == nil)
                darkTheme = [self themeForKind:OGThemeKindBranded dark:YES];
            return darkTheme;
        }
        if (lightTheme == nil)
            lightTheme = [self themeForKind:OGThemeKindBranded dark:NO];
        return lightTheme;
    }
}

+ (void)setBrandedThemeDark:(BOOL)dark
{
    @synchronized(self)
    {
        OGBrandedThemeDark = dark;
    }
}

+ (OGTheme *)classicTheme
{
    static OGTheme *theme = nil;
    @synchronized(self)
    {
        if (theme == nil)
            theme = [self themeForKind:OGThemeKindClassic dark:NO];
    }
    return theme;
}

+ (OGTheme *)modernTheme
{
    static OGTheme *theme = nil;
    @synchronized(self)
    {
        if (theme == nil)
            theme = [self themeForKind:OGThemeKindModern dark:NO];
    }
    return theme;
}

+ (OGTheme *)currentTheme
{
    @synchronized(self)
    {
        if (OGCurrentTheme == nil)
            OGCurrentTheme = [self modernTheme];
        return OGCurrentTheme;
    }
}

+ (void)setCurrentTheme:(OGTheme *)theme
{
    @synchronized(self)
    {
        OGCurrentTheme = theme == nil ? [self modernTheme] : theme;
    }
}
@end
