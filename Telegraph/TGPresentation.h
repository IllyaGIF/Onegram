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
@class UIFont;
@class UIColor;
@class UIBarButtonItem;
@class OGConversationAppearance;
@class OGDialogListAppearance;
@class OGContactListAppearance;
@class OGCommunitySheetAppearance;
@class OGSettingsAppearance;

typedef enum
{
    TGInterfaceStyleModern = 0,
    TGInterfaceStyleClassic = 1,
    TGInterfaceStyleFekla = 2
} TGInterfaceStyle;

typedef enum
{
    TGBrandedIOS6InputGlyphAttach = 0,
    TGBrandedIOS6InputGlyphAttachEdit = 1,
    TGBrandedIOS6InputGlyphSend = 2,
    TGBrandedIOS6InputGlyphConfirm = 3,
    TGBrandedIOS6InputGlyphMicrophone = 4,
    TGBrandedIOS6InputGlyphVideoMessage = 5
} TGBrandedIOS6InputGlyph;

typedef enum
{
    TGBrandedIOS6ActionIconJoin = 0,
    TGBrandedIOS6ActionIconMute = 1,
    TGBrandedIOS6ActionIconUnmute = 2,
    TGBrandedIOS6ActionIconShare = 3
} TGBrandedIOS6ActionIcon;

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
+ (UIImage *)brandedIOS6ShadowedBadgeImageForWidth:(CGFloat)width height:(CGFloat)height;
+ (NSString *)brandedIOS6BadgeTextForCount:(NSInteger)count;
+ (UIImage *)brandedIOS6NavigationBarBackgroundImageForSize:(CGSize)size overflow:(CGFloat)overflow gloss:(bool)gloss;
+ (UIImage *)brandedIOS6ContactNavigationBarImageForSize:(CGSize)size overflow:(CGFloat)overflow;
+ (UIImage *)brandedIOS6TabBarBackgroundImageForSize:(CGSize)size segmentFrames:(NSArray *)segmentFrames selectedIndex:(NSInteger)selectedIndex;
+ (UIImage *)brandedIOS6DialogAvatarOverlayImageForSize:(CGSize)size;
+ (OGDialogListAppearance *)brandedIOS6DialogListAppearance;
+ (UIImage *)brandedIOS6DialogCellBackgroundImage;
+ (UIImage *)brandedIOS6DialogCellBackgroundImageForHeight:(CGFloat)height;
+ (UIColor *)brandedIOS6DialogCellBackgroundColor;
+ (UIImage *)brandedIOS6DialogDisclosureImageUnread:(bool)unread;
+ (UIEdgeInsets)brandedIOS6DialogMentionImageOutsets;
+ (UIImage *)brandedIOS6DialogMentionImage;
+ (UIImage *)brandedIOS6DialogPinImage;
+ (UIImage *)brandedIOS6DialogFolderButtonImageForWidth:(CGFloat)width highlighted:(bool)highlighted selected:(bool)selected;
+ (UIColor *)brandedIOS6DialogListHeaderColorForSize:(CGSize)size;
+ (UIImage *)brandedIOS6SearchBarBackgroundImageForSize:(CGSize)size;
+ (UIColor *)brandedIOS6SearchBarBackdropColorForSize:(CGSize)size;
+ (UIImage *)brandedIOS6SearchBarFieldImageForSize:(CGSize)size;
+ (UIImage *)brandedIOS6SearchBarIconImage;
+ (UIImage *)brandedIOS6ContactSearchBarBackgroundImageForSize:(CGSize)size;
+ (UIImage *)brandedIOS6ContactSearchBarFieldImageForSize:(CGSize)size;
+ (UIImage *)brandedIOS6ContactSearchBarIconImage;
- (TGSearchBarPallete *)contactSearchBarPallete;
+ (UIOffset)brandedIOS6SearchBarIconOffset;
+ (UIOffset)brandedIOS6SearchBarPlaceholderOffset;
+ (OGContactListAppearance *)brandedIOS6ContactListAppearance;
+ (UIImage *)brandedIOS6ContactSectionHeaderImage;
+ (OGCommunitySheetAppearance *)brandedIOS6CommunitySheetAppearance;
+ (UIImage *)brandedIOS6CommunitySheetHeaderImageForWidth:(CGFloat)width;
+ (UIImage *)brandedIOS6CommunitySheetIndicatorImage;
+ (UIColor *)brandedIOS6DialogActionColorForSize:(CGSize)size slice:(CGRect)slice;
+ (OGConversationAppearance *)brandedIOS6ConversationAppearance;
+ (OGSettingsAppearance *)brandedIOS6SettingsAppearanceDark:(bool)dark;
+ (UIImage *)brandedIOS6BubbleImageOutgoing:(bool)outgoing highlighted:(bool)highlighted;
+ (UIImage *)brandedIOS6BubbleImageOutgoing:(bool)outgoing highlighted:(bool)highlighted voice:(bool)voice;
+ (UIEdgeInsets)brandedIOS6BubbleImageInsetsOutgoing:(bool)outgoing;
+ (UIImage *)brandedIOS6ConversationBackgroundImageForSize:(CGSize)size;
+ (UIImage *)brandedIOS6ConversationCardImageForSize:(CGSize)size topInset:(CGFloat)topInset bottomSafeInset:(CGFloat)bottomSafeInset frame:(CGRect *)frame;
+ (UIImage *)brandedIOS6ConversationCardEdgeImageWithBackground:(UIImage *)background card:(UIImage *)card cardImageFrame:(CGRect)cardImageFrame topInset:(CGFloat)topInset bottomSafeInset:(CGFloat)bottomSafeInset bottomEdge:(bool)bottomEdge frame:(CGRect *)frame;
+ (UIImage *)brandedIOS6InputPanelBackgroundImageForSize:(CGSize)size topOutset:(CGFloat *)topOutset;
+ (UIImage *)brandedIOS6InputButtonImageWithGlyph:(TGBrandedIOS6InputGlyph)glyph accentColor:(UIColor *)accentColor;
+ (UIImage *)brandedIOS6InputFieldImageWithOutsets:(UIEdgeInsets *)outsets;
+ (UIImage *)brandedIOS6ActionButtonImageHighlighted:(bool)highlighted outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)brandedIOS6ActionIconTemplate:(TGBrandedIOS6ActionIcon)icon;
+ (UIImage *)brandedIOS6ActionIconImage:(TGBrandedIOS6ActionIcon)icon outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)brandedIOS6ScrollButtonImageMentions:(bool)mentions;
+ (bool)brandedIOS6PinnedPanelAvailable;
+ (CGFloat)brandedIOS6PinnedPanelHeight;
+ (UIImage *)brandedIOS6PinnedPanelImageForSize:(CGSize)size outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)brandedIOS6PinnedPanelImageForSize:(CGSize)size joinedHeader:(bool)joinedHeader outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)brandedIOS6PinnedIndicatorImage;
+ (UIImage *)brandedIOS6PinnedBubbleImageForWidth:(CGFloat)width outsets:(UIEdgeInsets *)outsets;
+ (void)prewarmBrandedIOS6ConversationSurfaces;
+ (UIImage *)brandedIOS6PinnedIconImage;
+ (UIImage *)brandedIOS6PinnedCloseImage;
+ (UIImage *)brandedIOS6UnreadHeaderImageForWidth:(CGFloat)width;
+ (UIImage *)brandedIOS6CommentsAvatarOverlayImageWithOutsets:(UIEdgeInsets *)outsets;
+ (UIImage *)brandedIOS6CommentsChevronImage;
+ (UIImage *)brandedIOS6MessageViewsIconWithColor:(UIColor *)color;
+ (UIImage *)brandedIOS6ConversationAvatarOverlayImageForSize:(CGSize)size outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)brandedIOS6NavigationButtonImage:(bool)backButton highlighted:(bool)highlighted landscape:(bool)landscape width:(CGFloat)width;
+ (UIFont *)brandedIOS6NavigationTitleFont;
+ (UIColor *)brandedIOS6NavigationTitleColor;
+ (UIColor *)brandedIOS6NavigationTitleShadowColor;
+ (UIFont *)brandedIOS6NavigationButtonFont;
+ (UIColor *)brandedIOS6NavigationButtonShadowColor;
+ (CGFloat)brandedIOS6NavigationButtonWidthForTitle:(NSString *)title;
+ (UIBarButtonItem *)brandedIOS6BarButtonItemWithTitle:(NSString *)title target:(id)target action:(SEL)action;
+ (UIBarButtonItem *)brandedIOS6BarButtonItemWithTitle:(NSString *)title target:(id)target action:(SEL)action offset:(UIOffset)offset;
+ (UIBarButtonItem *)navigationBarButtonItemWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action;
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
