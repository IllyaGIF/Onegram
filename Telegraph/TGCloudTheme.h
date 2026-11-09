#import <UIKit/UIKit.h>

@class SSignal;
@class TGPresentationPallete;
@class TGWallpaperInfo;

typedef enum {
    TGCloudThemeBaseClassic = 0,
    TGCloudThemeBaseDay = 1,
    TGCloudThemeBaseNight = 2,
    TGCloudThemeBaseNightTinted = 3
} TGCloudThemeBase;

typedef enum {
    TGCloudThemeErrorGeneric = 0,
    TGCloudThemeErrorUnsupported = 1
} TGCloudThemeError;

@interface TGCloudTheme : NSObject

@property (nonatomic, strong, readonly) NSString *identifier;
@property (nonatomic, readonly) int64_t themeId;
@property (nonatomic, readonly) int64_t accessHash;
@property (nonatomic, strong, readonly) NSString *slug;
@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, readonly) TGCloudThemeBase base;
@property (nonatomic, strong, readonly) NSDictionary *colors;
@property (nonatomic, strong, readonly) UIColor *accentColor;

+ (bool)isThemeFileName:(NSString *)fileName mimeType:(NSString *)mimeType;
+ (SSignal *)themeWithSlug:(NSString *)slug;
+ (SSignal *)themeWithFileAtPath:(NSString *)path fileName:(NSString *)fileName;

- (TGPresentationPallete *)previewPallete;
- (TGWallpaperInfo *)wallpaperInfo;
- (Class)basePalleteClass;
- (void)install;
- (void)apply;

+ (NSArray *)storedThemes;
+ (NSString *)activeThemeIdentifier;
+ (void)resetInstalledTheme;
+ (bool)removeStoredThemeWithIdentifier:(NSString *)identifier;

@end
