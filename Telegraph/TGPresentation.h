#import <Foundation/Foundation.h>
#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import "TGPresentationPallete.h"
#import "TGPresentationImages.h"

@class TGNavigationBarPallete;
@class TGSearchBarPallete;
@class TGMenuSheetPallete;
@class TGStickerKeyboardPallete;
@class TGCheckButtonPallete;
@class TGMediaAssetsPallete;
@class TGLocationPallete;
@class TGModernConversationInputMicPallete;
@class TGConversationAssociatedInputPanelPallete;
@class TGImageBorderPallete;

@class TGPresentationAutoNightPreferences;
@class UIImage;

typedef enum
{
    TGInterfaceStyleModern = 0,
    TGInterfaceStyleClassic = 1,
    TGInterfaceStyleFekla = 2
} TGInterfaceStyle;

@interface TGPresentation : NSObject

@property (nonatomic, readonly) TGPresentationPallete *pallete;
@property (nonatomic, readonly) TGPresentationImages *images;

@property (nonatomic, readonly) int32_t currentId;

- (TGNavigationBarPallete *)navigationBarPallete;
- (TGSearchBarPallete *)searchBarPallete;
- (TGSearchBarPallete *)keyboardSearchBarPallete;
- (TGMenuSheetPallete *)menuSheetPallete;
- (TGStickerKeyboardPallete *)stickerKeyboardPallete;
- (TGCheckButtonPallete *)checkButtonPallete;
- (TGMediaAssetsPallete *)mediaAssetsPallete;
- (TGLocationPallete *)locationPallete;
- (TGModernConversationInputMicPallete *)micButtonPallete;
- (TGConversationAssociatedInputPanelPallete *)associatedInputPanelPallete;
- (TGImageBorderPallete *)imageBorderPallete;

+ (void)refreshUIAppearance;
+ (void)startAutoNight;
+ (void)switchToPallete:(TGPresentationPallete *)pallete;
+ (TGPresentation *)current;
+ (SSignal *)signal;

+ (bool)classicIOS6StyleAvailable;
+ (TGInterfaceStyle)interfaceStyle;
+ (void)setInterfaceStyle:(TGInterfaceStyle)style;
+ (bool)classicIOS6Style;
+ (bool)brandedIOS6Style;
+ (void)setClassicIOS6Style:(bool)enabled;
+ (bool)classicIOS6UsesPaletteAdaptedAssets;
+ (UIImage *)classicIOS6ResourceImage:(NSString *)name;
+ (UIImage *)brandedIOS6ResourceImage:(NSString *)name;
+ (UIImage *)brandedIOS6GrayIconImage:(NSString *)name;
+ (UIImage *)brandedIOS6BadgeImage;
+ (UIImage *)brandedIOS6BadgeImageForWidth:(CGFloat)width;
+ (UIImage *)brandedIOS6BadgeImageForWidth:(CGFloat)width height:(CGFloat)height;
+ (NSString *)brandedIOS6BadgeTextForCount:(NSInteger)count;
+ (UIImage *)classicIOS6ThemedImage:(UIImage *)image tintColor:(UIColor *)tintColor;
+ (UIImage *)classicIOS6ThemedImage:(UIImage *)image tintColor:(UIColor *)tintColor alpha:(CGFloat)alpha;

+ (TGPresentationPallete *)currentSavedPallete;

+ (SSignal *)autoNightPreferences;
+ (void)updateAutoNightPreferences:(TGPresentationAutoNightPreferences *(^)(TGPresentationAutoNightPreferences *))updateBlock;
+ (NSNumber *)isAutoNightActivated;

+ (instancetype)defaultPresentation;

+ (SSignal *)fontSizeSignal;
+ (CGFloat)fontSize;
+ (void)setFontSize:(CGFloat)newFontSize;
+ (void)resetFontSize;

@end


typedef enum
{
    TGPresentationAutoNightModeDisabled,
    TGPresentationAutoNightModeBrightness,
    TGPresentationAutoNightModeScheduled,
    TGPresentationAutoNightModeSunsetSunrise
} TGPresentationAutoNightMode;

@interface TGPresentationAutoNightPreferences : NSObject <NSCoding>

@property (nonatomic, readonly) TGPresentationAutoNightMode mode;

@property (nonatomic, readonly) CGFloat brightnessThreshold;

@property (nonatomic, readonly) int32_t scheduleStart;
@property (nonatomic, readonly) int32_t scheduleEnd;

@property (nonatomic, readonly) CGFloat latitude;
@property (nonatomic, readonly) CGFloat longitude;
@property (nonatomic, readonly) NSString *cachedLocationName;

@property (nonatomic, readonly) int32_t preferredPalette;

- (instancetype)initWithMode:(TGPresentationAutoNightMode)mode brightnessThreshold:(CGFloat)brightnessThreshold scheduleStart:(int32_t)scheduleStart scheduleEnd:(int32_t)scheduleEnd latitude:(CGFloat)latitude longitude:(CGFloat)longitude cachedLocationName:(NSString *)cachedLocationName preferredPalette:(int32_t)preferredPallete;

+ (instancetype)defaultAutoNight;
- (instancetype)disabledAutoNight;
- (instancetype)brightnessModeWithThreshold:(CGFloat)threshold;
- (instancetype)scheduledModeWithStart:(int32_t)start end:(int32_t)end;
- (instancetype)sunsetSunriseModeWithLatitude:(CGFloat)latitude longitude:(CGFloat)longitude cachedLocationName:(NSString *)cachedLocationName;
- (instancetype)preferredPalette:(int32_t)palette;

@end


@interface UIColor (HSB)

- (UIColor *)colorWithHueMultiplier:(CGFloat)hueMultiplier saturationMultiplier:(CGFloat)saturationMultiplier brightnessMultiplier:(CGFloat)brightnessMultiplier;
- (int32_t)hexCode;

@end
