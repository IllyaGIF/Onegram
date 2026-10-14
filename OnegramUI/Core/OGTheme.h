#import <Foundation/Foundation.h>

@class OGPalette;
@class OGTypography;
@class OGMetrics;
@class OGAssets;
@class OGSettingsAppearance;
@class OGProfileAppearance;
@class OGNavigationAppearance;
@class OGTabBarAppearance;
@class OGDialogListAppearance;
@class OGConversationAppearance;
@class OGSearchBarAppearance;
@class OGContactListAppearance;
@class OGMusicPlayerAppearance;
@class OGMusicPlayerScreenAppearance;
@class OGCommunitySheetAppearance;
@class OGSurfaceRenderer;

typedef enum {
    OGThemeKindModern = 0,
    OGThemeKindClassic = 1,
    OGThemeKindBranded = 2
} OGThemeKind;

@interface OGTheme : NSObject
@property (nonatomic) OGThemeKind kind;
@property (nonatomic) BOOL dark;
@property (nonatomic, retain) OGPalette *palette;
@property (nonatomic, retain) OGTypography *typography;
@property (nonatomic, retain) OGMetrics *metrics;
@property (nonatomic, retain) OGAssets *assets;
@property (nonatomic, retain) OGSettingsAppearance *settingsAppearance;
@property (nonatomic, retain) OGProfileAppearance *profileAppearance;
@property (nonatomic, retain) OGNavigationAppearance *navigationAppearance;
@property (nonatomic, retain) OGTabBarAppearance *tabBarAppearance;
@property (nonatomic, retain) OGDialogListAppearance *dialogListAppearance;
@property (nonatomic, retain) OGConversationAppearance *conversationAppearance;
@property (nonatomic, retain) OGSearchBarAppearance *searchBarAppearance;
@property (nonatomic, retain) OGContactListAppearance *contactListAppearance;
@property (nonatomic, retain) OGMusicPlayerAppearance *musicPlayerAppearance;
@property (nonatomic, retain) OGMusicPlayerScreenAppearance *musicPlayerScreenAppearance;
@property (nonatomic, retain) OGCommunitySheetAppearance *communitySheetAppearance;
@property (nonatomic, retain) OGSurfaceRenderer *surfaceRenderer;
+ (OGTheme *)modernTheme;
+ (OGTheme *)classicTheme;
+ (OGTheme *)brandedTheme;
+ (OGTheme *)brandedThemeDark:(BOOL)dark;
+ (void)setBrandedThemeDark:(BOOL)dark;
+ (OGTheme *)currentTheme;
+ (void)setCurrentTheme:(OGTheme *)theme;
@end
