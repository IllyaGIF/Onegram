#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponentsGlobals.h"
#import "TGPresentation.h"
#import "../OnegramPlatform/OGPlatformVersion.h"
#import "../OnegramRuntime/OGRuntime.h"
#include <stdlib.h>
#include <stdint.h>
#import "TGDefaultPresentationPallete.h"
#import "TGDayPresentationPallete.h"
#import "TGNightPresentationPallete.h"
#import "TGNightBluePresentationPallete.h"

#import "TGMediaStoreContext.h"
#import "TGAppDelegate.h"
#import "TGWallpaperManager.h"

#import "EDSunriseSet.h"

#import "TGModernConversationControllerDynamicTypeSignals.h"
#import "TGScreenBrightnessSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageBlur.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGFont.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGColorWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGBuiltinWallpaperInfo.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGNavigationBar.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGSearchBar.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMenuSheetController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGStickerKeyboardTabPanel.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGCheckButtonView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMediaAssetsController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLocationMapViewController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernConversationInputMicButton.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernConversationAssociatedInputPanel.h"

#import "TGPresentationAssets.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGNavigationAppearance.h"
#import "../OnegramUI/Core/OGTabBarAppearance.h"
#import "../OnegramUI/Core/OGDialogListAppearance.h"
#import "../OnegramUI/Core/OGConversationAppearance.h"
#import "../OnegramUI/Core/OGSearchBarAppearance.h"
#import "../OnegramUI/Core/OGContactListAppearance.h"
#import "../OnegramUI/Core/OGCommunitySheetAppearance.h"
#import "../OnegramUI/Core/OGSettingsAppearance.h"
#import "../OnegramUI/Core/OGAssets.h"
#import "../OnegramUI/Core/OGSurfaceStyle.h"
#import "../OnegramUI/Core/OGSurfaceRenderer.h"

@interface TGPresentationState : NSObject <NSCoding>

@property (nonatomic, readonly) int32_t pallete;
@property (nonatomic, readonly) int32_t userInfo;
@property (nonatomic, readonly) int32_t fontSize;

- (instancetype)initWithPallete:(int32_t)pallete userInfo:(int32_t)userInfo fontSize:(int32_t)fontSize;

@end

@implementation TGPresentation

- (TGNavigationBarPallete *)navigationBarPallete
{
    return [TGNavigationBarPallete palleteWithBackgroundColor:self.pallete.barBackgroundColor separatorColor:self.pallete.barSeparatorColor titleColor:self.pallete.navigationTitleColor tintColor:self.pallete.navigationButtonColor];
}

- (TGSearchBarPallete *)searchBarPallete
{
    OGSearchBarAppearance *searchBarAppearance = [TGPresentation brandedIOS6Style] ? [OGTheme brandedTheme].searchBarAppearance : nil;
    return [self searchBarPalleteWithAppearance:searchBarAppearance clearIcon:self.images.searchClearIcon];
}

- (TGSearchBarPallete *)contactSearchBarPallete
{
    OGSearchBarAppearance *appearance = [OGTheme brandedTheme].contactListAppearance.searchBarAppearance;
    UIImage *clearIcon = [TGPresentationAssets searchClearIcon:appearance.iconColor color:appearance.fieldSurfaceStyle.fillColor];
    return [self searchBarPalleteWithAppearance:appearance clearIcon:clearIcon];
}

- (TGSearchBarPallete *)searchBarPalleteWithAppearance:(OGSearchBarAppearance *)searchBarAppearance clearIcon:(UIImage *)clearIcon
{
    UIColor *textColor = searchBarAppearance.textColor ?: self.pallete.searchBarTextColor;
    UIColor *placeholderColor = searchBarAppearance.placeholderColor ?: self.pallete.searchBarPlaceholderColor;
    return [TGSearchBarPallete palleteWithDark:self.pallete.isDark backgroundColor:self.pallete.searchBarBackgroundColor highContrastBackgroundColor:self.pallete.searchBarMergedBackgroundColor textColor:textColor placeholderColor:placeholderColor clearIcon:clearIcon barBackgroundColor:self.pallete.barBackgroundColor barSeparatorColor:self.pallete.barSeparatorColor plainBackgroundColor:self.pallete.backgroundColor accentColor:self.pallete.accentColor accentContrastColor:self.pallete.accentContrastColor menuBackgroundColor:self.pallete.menuBackgroundColor segmentedControlBackgroundImage:self.images.segmentedControlBackgroundImage segmentedControlSelectedImage:self.images.segmentedControlSelectedImage segmentedControlHighlightedImage:self.images.segmentedControlHighlightedImage segmentedControlDividerImage:self.images.segmentedControlDividerImage];
}

- (TGSearchBarPallete *)keyboardSearchBarPallete
{
    return [TGSearchBarPallete palleteWithDark:self.pallete.isDark backgroundColor:self.pallete.chatInputKeyboardSearchBarColor highContrastBackgroundColor:self.pallete.chatInputKeyboardSearchBarColor textColor:self.pallete.searchBarTextColor placeholderColor:self.pallete.searchBarPlaceholderColor clearIcon:self.images.searchClearIcon barBackgroundColor:self.pallete.barBackgroundColor barSeparatorColor:[UIColor clearColor] plainBackgroundColor:[UIColor clearColor] accentColor:self.pallete.accentColor accentContrastColor:self.pallete.accentContrastColor menuBackgroundColor:self.pallete.menuBackgroundColor segmentedControlBackgroundImage:self.images.segmentedControlBackgroundImage segmentedControlSelectedImage:self.images.segmentedControlSelectedImage segmentedControlHighlightedImage:self.images.segmentedControlHighlightedImage segmentedControlDividerImage:self.images.segmentedControlDividerImage];
}

- (TGMenuSheetPallete *)menuSheetPallete
{
    return [TGMenuSheetPallete palleteWithDark:self.pallete.isDark backgroundColor:self.pallete.menuBackgroundColor selectionColor:self.pallete.menuSelectionColor separatorColor:self.pallete.menuSeparatorColor accentColor:self.pallete.menuAccentColor destructiveColor:self.pallete.menuDestructiveColor textColor:self.pallete.menuTextColor secondaryTextColor:self.pallete.menuSecondaryTextColor spinnerColor:self.pallete.menuSpinnerColor badgeTextColor:self.pallete.accentContrastColor badgeImage:self.images.shareBadgeImage cornersImage:self.images.menuCornersImage];
}

- (TGStickerKeyboardPallete *)stickerKeyboardPallete
{
    return [TGStickerKeyboardPallete palleteWithBackgroundColor:self.pallete.barBackgroundColor separatorColor:self.pallete.chatInputKeyboardBorderColor selectionColor:self.pallete.chatInputSelectionColor gifIcon:self.images.chatStickersGifIcon trendingIcon:self.images.chatStickersTrendingIcon favoritesIcon:self.images.chatStickersFavoritesIcon recentIcon:self.images.chatStickersRecentIcon settingsIcon:self.images.chatStickersSettingsIcon badge:self.images.chatStickersBadge badgeTextColor:self.pallete.accentContrastColor];
}

- (TGCheckButtonPallete *)checkButtonPallete
{
    return [TGCheckButtonPallete palleteWithDefaultBackgroundColor:self.pallete.checkButtonBackgroundColor accentBackgroundColor:self.pallete.accentColor defaultBorderColor:self.pallete.checkButtonBorderColor mediaBorderColor:[UIColor whiteColor] chatBorderColor:self.pallete.checkButtonChatBorderColor checkColor:self.pallete.accentContrastColor blueColor:self.pallete.checkButtonBlueColor barBackgroundColor:self.pallete.menuBackgroundColor];
}

- (TGMediaAssetsPallete *)mediaAssetsPallete
{
    return [TGMediaAssetsPallete palleteWithDark:self.pallete.isDark backgroundColor:self.pallete.backgroundColor selectionColor:self.pallete.selectionColor separatorColor:self.pallete.separatorColor textColor:self.pallete.textColor secondaryTextColor:self.pallete.secondaryTextColor accentColor:self.pallete.accentColor barBackgroundColor:self.pallete.barBackgroundColor barSeparatorColor:self.pallete.barSeparatorColor navigationTitleColor:self.pallete.navigationTitleColor badge:self.images.mediaBadgeImage badgeTextColor:self.pallete.accentContrastColor sendIconImage:self.images.chatInputSendIcon maybeAccentColor:self.pallete.maybeAccentColor];
}

- (TGLocationPallete *)locationPallete
{
    return [TGLocationPallete palleteWithBackgroundColor:self.pallete.menuBackgroundColor selectionColor:self.pallete.selectionColor separatorColor:self.pallete.separatorColor textColor:self.pallete.textColor secondaryTextColor:self.pallete.secondaryTextColor accentColor:self.pallete.accentColor destructiveColor:self.pallete.destructiveColor locationColor:self.pallete.locationAccentColor liveLocationColor:self.pallete.locationLiveColor iconColor:self.pallete.accentContrastColor sectionHeaderBackgroundColor:self.pallete.menuSectionHeaderBackgroundColor sectionHeaderTextColor:self.pallete.sectionHeaderTextColor searchBarPallete:self.searchBarPallete avatarPlaceholder:[self.images avatarPlaceholderWithDiameter:48.0f]];
}

- (TGModernConversationInputMicPallete *)micButtonPallete
{
    return [TGModernConversationInputMicPallete palleteWithDark:self.pallete.isDark buttonColor:self.pallete.chatInputSendButtonColor iconColor:self.pallete.chatInputSendButtonIconColor backgroundColor:self.pallete.barBackgroundColor borderColor:self.pallete.barSeparatorColor lockColor:self.pallete.secondaryTextColor textColor:self.pallete.textColor secondaryTextColor:self.pallete.secondaryTextColor recordingColor:self.pallete.chatInputRecordingColor];
}

- (TGConversationAssociatedInputPanelPallete *)associatedInputPanelPallete
{
    return [TGConversationAssociatedInputPanelPallete palleteWithDark:self.pallete.isDark backgroundColor:self.pallete.backgroundColor separatorColor:self.pallete.separatorColor selectionColor:self.pallete.selectionColor barBackgroundColor:self.pallete.barBackgroundColor barSeparatorColor:self.pallete.barSeparatorColor textColor:self.pallete.textColor secondaryTextColor:self.pallete.secondaryTextColor accentColor:self.pallete.accentColor placeholderBackgroundColor:nil placeholderIconColor:nil avatarPlaceholder:[self.images avatarPlaceholderWithDiameter:32.0f] closeIcon:self.images.replyCloseIcon largeCloseIcon:self.images.pinCloseIcon];
}

- (TGImageBorderPallete *)imageBorderPallete
{
    return [TGImageBorderPallete palleteWithBorderColor:self.pallete.chatImageBorderColor shadowColor:self.pallete.chatImageBorderShadowColor];
}

static TGPresentation *currentPresentation;
static TGPresentationState *currentState;
static SPipe *presentationPipe;
static CGFloat fontSize = 17.0f;
static bool useDynamicTypeFontSize = false;
static id<SDisposable> dynamicTypeDisposable;
static SPipe *fontPipe;

static TGPresentationAutoNightPreferences *autoNightPreferences;
static SPipe *autoNightPreferencesPipe;
static id<SDisposable> autoNightDisposable;
static NSString *const TGClassicIOS6StyleDefaultsKey = @"TGClassicIOS6Style";
static NSString *const TGInterfaceStyleDefaultsKey = @"TGInterfaceStyle";

static TGPresentationPallete *TGPresentationPalleteForInterfaceStyle(TGPresentationPallete *pallete)
{
    if (![TGPresentation brandedIOS6Style])
        return pallete;
    if ([pallete isMemberOfClass:[TGDefaultPresentationPallete class]] || [pallete isMemberOfClass:[TGNightPresentationPallete class]])
        return pallete;
    return pallete.isDark ? [[TGNightPresentationPallete alloc] init] : [[TGDefaultPresentationPallete alloc] init];
}

static bool TGPresentationPalletesMatch(TGPresentationPallete *lhs, TGPresentationPallete *rhs)
{
    if (lhs == rhs)
        return true;
    if (lhs == nil || rhs == nil || [lhs class] != [rhs class] || lhs.isDark != rhs.isDark)
        return false;
    UIColor *lhsAccent = lhs.accentColor;
    UIColor *rhsAccent = rhs.accentColor;
    return lhsAccent == rhsAccent || [lhsAccent isEqual:rhsAccent];
}

static UIImage *TGClassicIOS6RecoloredImage(UIImage *image, UIColor *tintColor, CGFloat intensity)
{
    if (image == nil || tintColor == nil)
        return image;

    CGFloat scale = image.scale > FLT_EPSILON ? image.scale : 0.0f;
    CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(image.size, false, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [image drawInRect:rect];

    CGContextSetBlendMode(context, kCGBlendModeColor);
    CGContextSetFillColorWithColor(context, tintColor.CGColor);
    CGContextFillRect(context, rect);

    if (intensity > FLT_EPSILON)
    {
        CGContextSetBlendMode(context, kCGBlendModeMultiply);
        CGContextSetFillColorWithColor(context, [[tintColor colorWithAlphaComponent:MIN(1.0f, MAX(0.0f, intensity))] CGColor]);
        CGContextFillRect(context, rect);
    }

    [image drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0f];

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result == nil ? image : result;
}

+ (UIImage *)classicIOS6ResourceImage:(NSString *)name
{
    CGFloat scale = [UIScreen mainScreen].scale;
    bool retinaResource = scale > 1.5f;
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 160;
    });
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%d", name, retinaResource ? 2 : 1];
    UIImage *cachedImage = [cache objectForKey:cacheKey];
    if (cachedImage != nil)
        return cachedImage;

    NSString *resourceName = retinaResource ? [name stringByAppendingString:@"@2x"] : name;
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ClassicIOS6"];
    if (path.length == 0)
    {
        retinaResource = !retinaResource;
        resourceName = retinaResource ? [name stringByAppendingString:@"@2x"] : name;
        path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ClassicIOS6"];
    }

    UIImage *image = path.length == 0 ? nil : [UIImage imageWithContentsOfFile:path];
    if (image != nil && retinaResource && image.CGImage != NULL)
        image = [UIImage imageWithCGImage:image.CGImage scale:2.0f orientation:UIImageOrientationUp];
    if (image != nil)
        [cache setObject:image forKey:cacheKey];
    return image;
}

+ (UIImage *)brandedIOS6ResourceImage:(NSString *)name
{
    CGFloat scale = [UIScreen mainScreen].scale;
    bool retinaResource = scale > 1.5f;
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 96;
    });
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%d", name, retinaResource ? 2 : 1];
    UIImage *cachedImage = [cache objectForKey:cacheKey];
    if (cachedImage != nil)
        return cachedImage;

    NSString *resourceName = retinaResource ? [name stringByAppendingString:@"@2x"] : name;
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ios6style"];
    if (path.length == 0)
        path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png"];
    if (path.length == 0)
    {
        retinaResource = false;
        resourceName = name;
        path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ios6style"];
        if (path.length == 0)
            path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png"];
    }
    if (path.length == 0)
        path = [[NSBundle mainBundle] pathForResource:name ofType:@"jpg" inDirectory:@"ios6style"];
    if (path.length == 0)
        path = [[NSBundle mainBundle] pathForResource:name ofType:@"jpg"];

    UIImage *image = path.length == 0 ? nil : [UIImage imageWithContentsOfFile:path];
    if (image != nil && retinaResource && image.CGImage != NULL)
        image = [UIImage imageWithCGImage:image.CGImage scale:2.0f orientation:UIImageOrientationUp];
    if (image != nil)
        [cache setObject:image forKey:cacheKey];
    return image;
}

+ (UIImage *)brandedIOS6BadgeImage
{
    return [self brandedIOS6BadgeImageForWidth:18.0f height:18.0f];
}

+ (UIImage *)brandedIOS6BadgeImageForWidth:(CGFloat)width
{
    return [self brandedIOS6BadgeImageForWidth:width height:18.0f];
}

+ (UIImage *)brandedIOS6BadgeImageForWidth:(CGFloat)width height:(CGFloat)height
{
    height = MAX(1.0f, height);
    width = MAX(height, width);
    CGFloat scale = height / 18.0f;

    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });

    NSString *key = [NSString stringWithFormat:@"%.3f:%.3f", width, height];
    UIImage *cachedImage = nil;
    @synchronized(cache)
    {
        cachedImage = [cache objectForKey:key];
    }
    if (cachedImage != nil)
        return cachedImage;

    CGSize imageSize = CGSizeMake(width, height);
    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect bounds = CGRectMake(0.0f, 0.0f, imageSize.width, imageSize.height);
    UIBezierPath *outerPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:9.0f * scale];

    CGContextSaveGState(context);
    CGContextAddPath(context, outerPath.CGPath);
    CGContextClip(context);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat baseComponents[] = {
        198.0f / 255.0f, 1.0f / 255.0f, 1.0f / 255.0f, 1.0f,
        103.0f / 255.0f, 9.0f / 255.0f, 9.0f / 255.0f, 1.0f
    };
    CGFloat baseLocations[] = {0.0f, 1.0f};
    CGGradientRef baseGradient = CGGradientCreateWithColorComponents(colorSpace, baseComponents, baseLocations, 2);
    CGContextDrawLinearGradient(context, baseGradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, height), 0);
    CGGradientRelease(baseGradient);
    CGContextRestoreGState(context);

    CGContextSaveGState(context);
    CGContextAddPath(context, outerPath.CGPath);
    CGContextClip(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0.0f, 0.5f * scale), 1.0f * scale, UIColorRGBA(0x000000, 0.30f).CGColor);
    CGMutablePathRef shadowPath = CGPathCreateMutable();
    CGPathAddRect(shadowPath, NULL, CGRectInset(bounds, -10.0f * scale, -10.0f * scale));
    CGPathAddPath(shadowPath, NULL, outerPath.CGPath);
    CGContextAddPath(context, shadowPath);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextEOFillPath(context);
    CGPathRelease(shadowPath);
    CGContextRestoreGState(context);

    CGContextSaveGState(context);
    CGContextAddPath(context, outerPath.CGPath);
    CGContextClip(context);
    CGRect glossRect = CGRectMake((width - 31.0f * scale) / 2.0f - 0.5f * scale, -2.0f * scale, 31.0f * scale, 12.0f * scale);
    CGContextClipToRect(context, glossRect);
    CGFloat glossComponents[] = {
        1.0f, 1.0f, 1.0f, 0.80f,
        1.0f, 1.0f, 1.0f, 0.20f
    };
    CGFloat glossLocations[] = {0.0f, 1.0f};
    CGGradientRef glossGradient = CGGradientCreateWithColorComponents(colorSpace, glossComponents, glossLocations, 2);
    CGContextDrawLinearGradient(context, glossGradient, CGPointMake(0.0f, -2.0f * scale), CGPointMake(0.0f, 10.0f * scale), 0);
    CGGradientRelease(glossGradient);
    CGContextRestoreGState(context);

    CGColorSpaceRelease(colorSpace);

    CGRect borderRect = CGRectInset(bounds, 1.0f * scale, 1.0f * scale);
    UIBezierPath *borderPath = [UIBezierPath bezierPathWithRoundedRect:borderRect cornerRadius:8.0f * scale];
    [[UIColor whiteColor] setStroke];
    borderPath.lineWidth = 2.0f * scale;
    [borderPath stroke];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image != nil)
    {
        @synchronized(cache)
        {
            [cache setObject:image forKey:key];
        }
    }

    return image;
}

+ (UIImage *)brandedIOS6ShadowedBadgeImageForWidth:(CGFloat)width height:(CGFloat)height
{
    height = MAX(1.0f, height);
    width = MAX(height, width);

    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 32;
    });

    NSString *key = [[NSString alloc] initWithFormat:@"%.3f:%.3f", width, height];
    UIImage *cachedImage = [cache objectForKey:key];
    if (cachedImage != nil)
        return cachedImage;

    UIImage *badge = [self brandedIOS6BadgeImageForWidth:width height:height];
    if (badge == nil)
        return nil;

    CGFloat scale = height / 18.0f;
    CGFloat shadowBlur = 1.5f * scale;
    CGSize shadowOffset = CGSizeMake(0.0f, 2.0f * scale);
    CGFloat padding = CGCeil(shadowBlur * 2.0f + shadowOffset.height);
    CGSize imageSize = CGSizeMake(width + padding * 2.0f, height + padding * 2.0f);

    UIGraphicsBeginImageContextWithOptions(imageSize, false, badge.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlur, UIColorRGBA(0x000000, 0.80f).CGColor);
    [badge drawAtPoint:CGPointMake(padding, padding)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image != nil)
        [cache setObject:image forKey:key];
    return image;
}

+ (NSString *)brandedIOS6BadgeTextForCount:(NSInteger)count
{
    if (count <= 0)
        return @"";
    if (count > 99)
        return @"99+";
    return [NSString stringWithFormat:@"%ld", (long)count];
}

+ (UIImage *)brandedIOS6GrayIconImage:(NSString *)name
{
    if (name.length == 0)
        return nil;

    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });

    UIImage *cachedImage = cache[name];
    if (cachedImage != nil)
        return cachedImage;

    UIImage *source = [self brandedIOS6ResourceImage:name];
    if (source == nil)
        return nil;

    UIGraphicsBeginImageContextWithOptions(source.size, false, source.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {
        0.86f, 0.86f, 0.86f, 1.0f,
        0.48f, 0.48f, 0.48f, 1.0f
    };
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, source.size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    [source drawInRect:CGRectMake(0.0f, 0.0f, source.size.width, source.size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0f];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image != nil)
        cache[name] = image;
    return image;
}

static UIImage *TGBrandedIOS6BandImage(OGTheme *theme, OGSurfaceStyle *style, CGSize size)
{
    if (style == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    UIEdgeInsets outsets = [style dropShadowOutsets];
    return [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(size.width, size.height + outsets.bottom) bodyFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
}

static UIImage *TGBrandedIOS6GradientImage(UIImage *source, NSArray *colors)
{
    if (source == nil || colors.count < 2)
        return source;

    CGSize size = source.size;
    UIGraphicsBeginImageContextWithOptions(size, false, source.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSMutableArray *cgColors = [[NSMutableArray alloc] initWithCapacity:colors.count];
    for (UIColor *color in colors)
        [cgColors addObject:(__bridge id)color.CGColor];
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)cgColors, NULL);
    CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0.0f, size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    [source drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0f];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static OGSurfaceStyle *TGBrandedIOS6NavigationButtonStyle(OGNavigationAppearance *appearance, bool backButton, bool highlighted)
{
    if (backButton)
        return highlighted ? appearance.backButtonPressedSurfaceStyle : appearance.backButtonSurfaceStyle;
    return highlighted ? appearance.buttonPressedSurfaceStyle : appearance.buttonSurfaceStyle;
}

static UIImage *TGClassicIOS6NavigationButtonImage(bool backButton, bool highlighted, bool landscape)
{
    if ([TGPresentation brandedIOS6Style])
    {
        OGSurfaceStyle *style = TGBrandedIOS6NavigationButtonStyle([OGTheme brandedTheme].navigationAppearance, backButton, highlighted);
        UIImage *image = [TGPresentation brandedIOS6NavigationButtonImage:backButton highlighted:highlighted landscape:landscape width:0.0f];
        return [image resizableImageWithCapInsets:[style horizontalCapInsets]];
    }

    NSString *name = nil;
    if (backButton)
    {
        if (landscape)
            name = highlighted ? @"BackButton_Landscape_Pressed" : @"BackButton_Landscape";
        else
            name = highlighted ? @"BackButton_Pressed" : @"BackButton";
    }
    else
    {
        if (landscape)
            name = highlighted ? @"HeaderButton_Landscape_Pressed" : @"HeaderButton_Landscape";
        else
            name = highlighted ? @"HeaderButton_Pressed" : @"HeaderButton";
    }

    UIImage *image = [TGPresentation classicIOS6ResourceImage:name];
    if (image == nil)
        return nil;

    TGPresentationPallete *pallete = currentPresentation != nil ? currentPresentation.pallete : [TGPresentation currentSavedPallete];
    if (pallete.isDark)
        image = [TGPresentation classicIOS6ThemedImage:image tintColor:pallete.barBackgroundColor alpha:0.85f];

    CGFloat leftCap = backButton ? MIN(15.0f, image.size.width - 1.0f) : floor(image.size.width * 0.5f);
    return [image stretchableImageWithLeftCapWidth:(int)leftCap topCapHeight:0];
}

+ (UIImage *)brandedIOS6NavigationButtonImage:(bool)backButton highlighted:(bool)highlighted landscape:(bool)landscape width:(CGFloat)width
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGNavigationAppearance *appearance = theme.navigationAppearance;
    OGSurfaceStyle *style = TGBrandedIOS6NavigationButtonStyle(appearance, backButton, highlighted);
    CGFloat bodyHeight = landscape ? appearance.buttonLandscapeHeight : appearance.buttonHeight;
    CGFloat imageHeight = landscape ? appearance.buttonLandscapeImageHeight : appearance.buttonImageHeight;
    CGFloat imageWidth = width > FLT_EPSILON ? width : appearance.buttonImageWidth;
    return [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(imageWidth, imageHeight) bodyFrame:CGRectMake(0.0f, 0.0f, imageWidth, bodyHeight)];
}

+ (UIImage *)brandedIOS6NavigationBarBackgroundImageForSize:(CGSize)size overflow:(CGFloat)overflow gloss:(bool)gloss
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGNavigationAppearance *appearance = theme.navigationAppearance;
    OGSurfaceStyle *backgroundStyle = gloss && appearance.glossBackgroundSurfaceStyle != nil ? appearance.glossBackgroundSurfaceStyle : appearance.backgroundSurfaceStyle;
    UIImage *barImage = TGBrandedIOS6BandImage(theme, backgroundStyle, size);
    bool sheet = backgroundStyle.shape == OGSurfaceShapeSheet;
    if ((overflow < 1.0f && !sheet) || barImage == nil)
        return barImage;

    UIImage *overflowImage = TGBrandedIOS6BandImage(theme, appearance.statusBackgroundSurfaceStyle, CGSizeMake(size.width, sheet ? overflow + size.height : overflow));
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size.width, overflow + barImage.size.height), false, barImage.scale);
    [overflowImage drawAtPoint:CGPointZero];
    [barImage drawAtPoint:CGPointMake(0.0f, overflow)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)brandedIOS6TabBarBackgroundImageForSize:(CGSize)size segmentFrames:(NSArray *)segmentFrames selectedIndex:(NSInteger)selectedIndex
{
    if (size.width < 1.0f || size.height < 1.0f || segmentFrames.count == 0)
        return nil;
    OGTheme *theme = [OGTheme brandedTheme];
    OGSurfaceStyle *style = [theme.tabBarAppearance backgroundStyleWithSegmentFrames:segmentFrames selectedIndex:selectedIndex];
    return [theme.surfaceRenderer imageWithStyle:style size:size bodyFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
}

+ (UIImage *)brandedIOS6ContactNavigationBarImageForSize:(CGSize)size overflow:(CGFloat)overflow
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGContactListAppearance *appearance = theme.contactListAppearance;
    if (appearance.navigationSurfaceStyle == nil)
        return [self brandedIOS6NavigationBarBackgroundImageForSize:size overflow:overflow gloss:false];
    UIImage *barImage = TGBrandedIOS6BandImage(theme, appearance.navigationSurfaceStyle, size);
    if (barImage == nil)
        return nil;
    overflow = MAX(0.0f, overflow);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size.width, overflow + size.height), false, barImage.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, overflow));
    [barImage drawAtPoint:CGPointMake(0.0f, overflow)];
    CGContextSetStrokeColorWithColor(context, appearance.navigationStitchColor.CGColor);
    CGContextSetLineWidth(context, 1.0f);
    CGFloat dashLengths[] = {3.0f, 3.0f};
    CGContextSetLineDash(context, 0.0f, dashLengths, 2);
    CGContextMoveToPoint(context, 0.0f, overflow + 0.5f);
    CGContextAddLineToPoint(context, size.width, overflow + 0.5f);
    CGContextMoveToPoint(context, 0.0f, overflow + size.height - 0.5f);
    CGContextAddLineToPoint(context, size.width, overflow + size.height - 0.5f);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)brandedIOS6DialogAvatarOverlayImageForSize:(CGSize)size
{
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    OGTheme *theme = [OGTheme brandedTheme];
    return [theme.surfaceRenderer imageWithStyle:theme.dialogListAppearance.avatarOverlaySurfaceStyle size:size bodyFrame:CGRectMake(0.0f, 0.0f, size.width, size.height)];
}

+ (OGDialogListAppearance *)brandedIOS6DialogListAppearance
{
    return [OGTheme brandedTheme].dialogListAppearance;
}

+ (UIImage *)brandedIOS6DialogCellBackgroundImage
{
    return [self brandedIOS6DialogCellBackgroundImageForHeight:[OGTheme brandedTheme].dialogListAppearance.rowHeight];
}

+ (UIImage *)brandedIOS6DialogCellBackgroundImageForHeight:(CGFloat)height
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGSurfaceStyle *style = theme.dialogListAppearance.cellBackgroundSurfaceStyle;
    if (style == nil)
        return nil;
    UIImage *image = TGBrandedIOS6BandImage(theme, style, CGSizeMake(1.0f, height));
    return [image stretchableImageWithLeftCapWidth:0 topCapHeight:0];
}

+ (UIColor *)brandedIOS6DialogCellBackgroundColor
{
    return [OGTheme brandedTheme].dialogListAppearance.cellBackgroundSurfaceStyle.fillColor;
}

+ (UIImage *)brandedIOS6DialogDisclosureImageUnread:(bool)unread
{
    OGDialogListAppearance *appearance = [OGTheme brandedTheme].dialogListAppearance;
    return TGTintedImage([self classicIOS6ResourceImage:@"MenuDisclosureIndicator"], unread ? appearance.disclosureUnreadColor : appearance.disclosureColor);
}

+ (UIEdgeInsets)brandedIOS6DialogMentionImageOutsets
{
    CGFloat outset = 0.0f;
    for (OGSurfaceShadow *shadow in [OGTheme brandedTheme].dialogListAppearance.mentionShadows)
    {
        UIEdgeInsets shadowOutsets = [shadow outsets];
        outset = MAX(outset, MAX(MAX(shadowOutsets.top, shadowOutsets.bottom), MAX(shadowOutsets.left, shadowOutsets.right)));
    }
    return UIEdgeInsetsMake(outset, outset, outset, outset);
}

+ (UIImage *)brandedIOS6DialogMentionImage
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGDialogListAppearance *appearance = theme.dialogListAppearance;
    UIImage *glyph = [theme.surfaceRenderer glyphImageWithText:@"@" font:appearance.mentionFont opticalSize:appearance.mentionOpticalSize];
    if (glyph == nil)
        return nil;
    return [theme.surfaceRenderer iconImageWithTemplate:glyph gradientColors:appearance.mentionGradientColors locations:appearance.mentionGradientLocations shadows:appearance.mentionShadows outsets:[self brandedIOS6DialogMentionImageOutsets]];
}

+ (UIImage *)brandedIOS6DialogPinImage
{
    return TGBrandedIOS6GradientImage([self brandedIOS6ResourceImage:@"pin-angle-fill"], [OGTheme brandedTheme].dialogListAppearance.pinGradientColors);
}

+ (UIImage *)brandedIOS6DialogFolderButtonImageForWidth:(CGFloat)width highlighted:(bool)highlighted selected:(bool)selected
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGDialogListAppearance *appearance = theme.dialogListAppearance;
    OGSurfaceStyle *style = nil;
    if (selected && appearance.folderButtonSelectedSurfaceStyle != nil)
        style = highlighted ? appearance.folderButtonSelectedPressedSurfaceStyle : appearance.folderButtonSelectedSurfaceStyle;
    else
        style = highlighted ? appearance.folderButtonPressedSurfaceStyle : appearance.folderButtonSurfaceStyle;
    if (style == nil || width < 1.0f)
        return nil;
    UIEdgeInsets outsets = [style dropShadowOutsets];
    CGFloat height = appearance.folderButtonHeight;
    return [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(width, height + outsets.bottom) bodyFrame:CGRectMake(0.0f, 0.0f, width, height)];
}

+ (UIColor *)brandedIOS6DialogListHeaderColorForSize:(CGSize)size
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGDialogListAppearance *appearance = theme.dialogListAppearance;
    UIImage *image = TGBrandedIOS6BandImage(theme, appearance.headerSurfaceStyle, size);
    return image != nil ? [UIColor colorWithPatternImage:image] : appearance.headerColor;
}

+ (UIImage *)brandedIOS6SearchBarBackgroundImageForSize:(CGSize)size
{
    OGTheme *theme = [OGTheme brandedTheme];
    return TGBrandedIOS6BandImage(theme, theme.searchBarAppearance.backgroundSurfaceStyle, size);
}

+ (UIColor *)brandedIOS6SearchBarBackdropColorForSize:(CGSize)size
{
    UIColor *backdropColor = [OGTheme brandedTheme].searchBarAppearance.backdropColor;
    if (backdropColor != nil)
        return backdropColor;
    UIImage *image = [self brandedIOS6SearchBarBackgroundImageForSize:size];
    return image != nil ? [UIColor colorWithPatternImage:image] : nil;
}

+ (UIImage *)brandedIOS6SearchBarIconImage
{
    return [self searchBarIconImageWithAppearance:[OGTheme brandedTheme].searchBarAppearance];
}

+ (UIImage *)brandedIOS6ContactSearchBarIconImage
{
    return [self searchBarIconImageWithAppearance:[OGTheme brandedTheme].contactListAppearance.searchBarAppearance];
}

+ (UIImage *)searchBarIconImageWithAppearance:(OGSearchBarAppearance *)appearance
{
    UIColor *color = appearance.iconColor;
    CGFloat size = appearance.iconSize;
    CGFloat diameter = appearance.iconCircleDiameter;
    CGFloat lineWidth = appearance.iconLineWidth;
    if (color == nil || size < 1.0f || diameter < 1.0f || lineWidth <= 0.0f)
        return nil;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, lineWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGFloat halfLine = lineWidth / 2.0f;
    CGContextStrokeEllipseInRect(context, CGRectMake(halfLine, halfLine, diameter - lineWidth, diameter - lineWidth));
    CGFloat center = diameter / 2.0f;
    CGFloat handleStart = center + (center - halfLine) * (CGFloat)M_SQRT1_2;
    CGContextMoveToPoint(context, handleStart, handleStart);
    CGContextAddLineToPoint(context, size - halfLine, size - halfLine);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIOffset)brandedIOS6SearchBarIconOffset
{
    return [OGTheme brandedTheme].searchBarAppearance.iconOffset;
}

+ (UIOffset)brandedIOS6SearchBarPlaceholderOffset
{
    return [OGTheme brandedTheme].searchBarAppearance.placeholderOffset;
}

+ (UIImage *)brandedIOS6SearchBarFieldImageForSize:(CGSize)size
{
    return [self searchBarFieldImageForSize:size appearance:[OGTheme brandedTheme].searchBarAppearance];
}

+ (UIImage *)brandedIOS6ContactSearchBarBackgroundImageForSize:(CGSize)size
{
    OGTheme *theme = [OGTheme brandedTheme];
    return TGBrandedIOS6BandImage(theme, theme.contactListAppearance.searchBarAppearance.backgroundSurfaceStyle, size);
}

+ (UIImage *)brandedIOS6ContactSearchBarFieldImageForSize:(CGSize)size
{
    return [self searchBarFieldImageForSize:size appearance:[OGTheme brandedTheme].contactListAppearance.searchBarAppearance];
}

+ (UIImage *)searchBarFieldImageForSize:(CGSize)size appearance:(OGSearchBarAppearance *)appearance
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGSurfaceStyle *style = appearance.fieldSurfaceStyle;
    if (style == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    UIEdgeInsets outsets = [style dropShadowOutsets];
    CGFloat horizontalOutset = MAX(outsets.left, outsets.right);
    CGFloat verticalOutset = MAX(outsets.top, outsets.bottom);
    return [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(size.width + horizontalOutset * 2.0f, size.height + verticalOutset * 2.0f) bodyFrame:CGRectMake(horizontalOutset, verticalOutset, size.width, size.height)];
}

+ (UIColor *)brandedIOS6DialogActionColorForSize:(CGSize)size slice:(CGRect)slice
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGDialogListAppearance *appearance = theme.dialogListAppearance;
    UIImage *image = TGBrandedIOS6BandImage(theme, appearance.actionSurfaceStyle, size);
    if (image != nil)
    {
        CGFloat scale = image.scale;
        CGRect pixelSlice = CGRectIntegral(CGRectMake(slice.origin.x * scale, slice.origin.y * scale, slice.size.width * scale, slice.size.height * scale));
        CGImageRef sliceImage = CGImageCreateWithImageInRect(image.CGImage, pixelSlice);
        if (sliceImage != NULL)
        {
            UIImage *patternImage = [UIImage imageWithCGImage:sliceImage scale:scale orientation:UIImageOrientationUp];
            CGImageRelease(sliceImage);
            return [UIColor colorWithPatternImage:patternImage];
        }
    }
    UIImage *patternImage = appearance.actionPatternAssetName.length == 0 ? nil : [self brandedIOS6ResourceImage:appearance.actionPatternAssetName];
    return patternImage != nil ? [UIColor colorWithPatternImage:patternImage] : appearance.actionFallbackColor;
}

+ (OGContactListAppearance *)brandedIOS6ContactListAppearance
{
    return [OGTheme brandedTheme].contactListAppearance;
}

+ (UIImage *)brandedIOS6ContactSectionHeaderImage
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGContactListAppearance *appearance = theme.contactListAppearance;
    return TGBrandedIOS6BandImage(theme, appearance.sectionHeaderSurfaceStyle, CGSizeMake(1.0f, appearance.sectionHeaderHeight));
}

+ (OGCommunitySheetAppearance *)brandedIOS6CommunitySheetAppearance
{
    return [OGTheme brandedTheme].communitySheetAppearance;
}

+ (UIImage *)brandedIOS6CommunitySheetHeaderImageForWidth:(CGFloat)width
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGCommunitySheetAppearance *appearance = theme.communitySheetAppearance;
    return TGBrandedIOS6BandImage(theme, appearance.headerSurfaceStyle, CGSizeMake(width, appearance.headerHeight));
}

+ (UIImage *)brandedIOS6CommunitySheetIndicatorImage
{
    UIImage *image = TGTintedImage([self classicIOS6ResourceImage:@"MenuDisclosureIndicator"], [OGTheme brandedTheme].communitySheetAppearance.indicatorColor);
    if (image == nil)
        return nil;
    return [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:UIImageOrientationLeft];
}

+ (OGConversationAppearance *)brandedIOS6ConversationAppearance
{
    return [OGTheme brandedTheme].conversationAppearance;
}

+ (OGSettingsAppearance *)brandedIOS6SettingsAppearanceDark:(bool)dark
{
    return [OGTheme brandedThemeDark:dark].settingsAppearance;
}

+ (UIEdgeInsets)brandedIOS6BubbleImageInsetsOutgoing:(bool)outgoing
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    return outgoing ? appearance.outgoingBubbleImageInsets : appearance.incomingBubbleImageInsets;
}

+ (UIImage *)brandedIOS6BubbleImageOutgoing:(bool)outgoing highlighted:(bool)highlighted
{
    return [self brandedIOS6BubbleImageOutgoing:outgoing highlighted:highlighted voice:false];
}

+ (UIImage *)brandedIOS6BubbleImageOutgoing:(bool)outgoing highlighted:(bool)highlighted voice:(bool)voice
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    OGSurfaceStyle *style = outgoing ? (highlighted ? appearance.outgoingHighlightedBubbleSurfaceStyle : appearance.outgoingBubbleSurfaceStyle) : (highlighted ? appearance.incomingHighlightedBubbleSurfaceStyle : appearance.incomingBubbleSurfaceStyle);
    if (voice)
        style = outgoing ? (highlighted ? appearance.voiceOutgoingHighlightedBubbleSurfaceStyle : appearance.voiceOutgoingBubbleSurfaceStyle) : (highlighted ? appearance.voiceIncomingHighlightedBubbleSurfaceStyle : appearance.voiceIncomingBubbleSurfaceStyle);
    UIEdgeInsets insets = outgoing ? appearance.outgoingBubbleImageInsets : appearance.incomingBubbleImageInsets;
    CGSize body = appearance.bubbleImageBodySize;
    CGSize size = CGSizeMake(insets.left + body.width + insets.right, insets.top + body.height + insets.bottom);
    UIImage *image = [theme.surfaceRenderer imageWithStyle:style size:size bodyFrame:CGRectMake(insets.left, insets.top, body.width, body.height)];
    NSInteger leftCap = (NSInteger)(insets.left + CGFloor(body.width / 2.0f));
    NSInteger topCap = (NSInteger)(insets.top + CGFloor(body.height / 2.0f));
    return [image stretchableImageWithLeftCapWidth:leftCap topCapHeight:topCap];
}

static CGRect TGBrandedIOS6ConversationCardFrame(OGConversationAppearance *appearance, CGSize size, CGFloat topInset, CGFloat bottomSafeInset)
{
    CGFloat horizontalInset = appearance.backgroundCardHorizontalInset;
    return CGRectMake(horizontalInset, topInset, size.width - horizontalInset * 2.0f, size.height - topInset - appearance.inputPanelHeight - bottomSafeInset);
}

static void TGBrandedIOS6AddRoundedRectPath(CGContextRef context, CGRect rect, CGFloat radius)
{
    radius = MIN(radius, MIN(rect.size.width, rect.size.height) * 0.5f);
    CGContextMoveToPoint(context, CGRectGetMinX(rect) + radius, CGRectGetMinY(rect));
    CGContextAddArcToPoint(context, CGRectGetMaxX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMaxY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMaxX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMaxY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMinX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMinY(rect), radius);
    CGContextAddArcToPoint(context, CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMinY(rect), radius);
    CGContextClosePath(context);
}

static UIImage *TGBrandedIOS6SurfaceImage(OGTheme *theme, OGSurfaceStyle *style, CGSize size, UIEdgeInsets *outsets)
{
    if (style == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    UIEdgeInsets styleOutsets = [style dropShadowOutsets];
    styleOutsets = UIEdgeInsetsMake(ceilf(styleOutsets.top), ceilf(styleOutsets.left), ceilf(styleOutsets.bottom), ceilf(styleOutsets.right));
    if (outsets != NULL)
        *outsets = styleOutsets;
    CGSize imageSize = CGSizeMake(styleOutsets.left + size.width + styleOutsets.right, styleOutsets.top + size.height + styleOutsets.bottom);
    return [theme.surfaceRenderer imageWithStyle:style size:imageSize bodyFrame:CGRectMake(styleOutsets.left, styleOutsets.top, size.width, size.height)];
}

+ (bool)brandedIOS6PinnedPanelAvailable
{
    return [self brandedIOS6Style] && [OGTheme brandedTheme].conversationAppearance.pinnedPanelSurfaceStyle != nil;
}

+ (CGFloat)brandedIOS6PinnedPanelHeight
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    UIEdgeInsets outsets = appearance.pinnedPanelSurfaceStyle != nil ? [appearance.pinnedPanelSurfaceStyle dropShadowOutsets] : UIEdgeInsetsZero;
    return appearance.pinnedPanelHeight + ceilf(outsets.bottom);
}

+ (UIImage *)brandedIOS6PinnedPanelImageForSize:(CGSize)size outsets:(UIEdgeInsets *)outsets
{
    return [self brandedIOS6PinnedPanelImageForSize:size joinedHeader:false outsets:outsets];
}

+ (UIImage *)brandedIOS6PinnedPanelImageForSize:(CGSize)size joinedHeader:(bool)joinedHeader outsets:(UIEdgeInsets *)outsets
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGSurfaceStyle *style = joinedHeader ? theme.conversationAppearance.joinedPinnedPanelSurfaceStyle : theme.conversationAppearance.pinnedPanelSurfaceStyle;
    return TGBrandedIOS6SurfaceImage(theme, style, size, outsets);
}

+ (UIImage *)brandedIOS6PinnedIndicatorImage
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    return TGBrandedIOS6SurfaceImage(theme, appearance.pinnedIndicatorSurfaceStyle, appearance.pinnedIndicatorFrame.size, NULL);
}

static UIImage *TGBrandedIOS6PinnedBubbleImage(OGTheme *theme, CGFloat width, UIEdgeInsets *outsets)
{
    OGConversationAppearance *appearance = theme.conversationAppearance;
    OGSurfaceStyle *style = appearance.pinnedBubbleSurfaceStyle;
    if (style == nil || width < 1.0f)
        return nil;
    UIEdgeInsets insets = appearance.pinnedBubbleImageInsets;
    if (outsets != NULL)
        *outsets = insets;
    CGSize body = CGSizeMake(width, appearance.pinnedBubbleHeight);
    return [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(insets.left + body.width + insets.right, insets.top + body.height + insets.bottom) bodyFrame:CGRectMake(insets.left, insets.top, body.width, body.height)];
}

+ (UIImage *)brandedIOS6PinnedBubbleImageForWidth:(CGFloat)width outsets:(UIEdgeInsets *)outsets
{
    return TGBrandedIOS6PinnedBubbleImage([OGTheme brandedTheme], width, outsets);
}

+ (void)prewarmBrandedIOS6ConversationSurfaces
{
    if (![self brandedIOS6Style])
        return;
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
    CGFloat bodyWidth = MAX(0.0f, screenSize.width - appearance.backgroundCardHorizontalInset * 2.0f);
    CGFloat bubbleWidth = MAX(0.0f, bodyWidth - appearance.pinnedBubbleLeft - appearance.pinnedBubbleRightInset);
    OGRuntimeDispatchAfterStartupPhase(OGRuntimePriorityUtility, ^
    {
        @autoreleasepool
        {
            TGBrandedIOS6BandImage(theme, appearance.backgroundSurfaceStyle, screenSize);
            TGBrandedIOS6SurfaceImage(theme, appearance.pinnedPanelSurfaceStyle, CGSizeMake(bodyWidth, appearance.pinnedPanelHeight), NULL);
            TGBrandedIOS6SurfaceImage(theme, appearance.joinedPinnedPanelSurfaceStyle, CGSizeMake(bodyWidth, appearance.pinnedPanelHeight), NULL);
            TGBrandedIOS6PinnedBubbleImage(theme, bubbleWidth, NULL);
        }
    });
}

+ (UIImage *)brandedIOS6PinnedIconImage
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    if (appearance.pinnedIconAssetName.length == 0)
        return nil;
    return TGBrandedIOS6GradientImage([self brandedIOS6ResourceImage:appearance.pinnedIconAssetName], appearance.pinnedIconColors);
}

+ (UIImage *)brandedIOS6PinnedCloseImage
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    CGSize size = appearance.pinnedCloseSize;
    if (appearance.pinnedCloseColor == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    CGFloat inset = appearance.pinnedCloseGlyphInset;
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, appearance.pinnedCloseColor.CGColor);
    CGContextSetLineWidth(context, appearance.pinnedCloseLineWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextMoveToPoint(context, inset, inset);
    CGContextAddLineToPoint(context, size.width - inset, size.height - inset);
    CGContextMoveToPoint(context, size.width - inset, inset);
    CGContextAddLineToPoint(context, inset, size.height - inset);
    CGContextStrokePath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)brandedIOS6CommentsAvatarOverlayImageWithOutsets:(UIEdgeInsets *)outsets
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    return TGBrandedIOS6SurfaceImage(theme, appearance.commentsAvatarOverlaySurfaceStyle, CGSizeMake(appearance.commentsAvatarSize, appearance.commentsAvatarSize), outsets);
}

+ (UIImage *)brandedIOS6CommentsChevronImage
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    UIImage *image = [theme.assets imageNamed:appearance.commentsChevronAssetName inDirectory:appearance.commentsChevronResourceDirectory];
    if (image == nil || appearance.commentsChevronColors.count == 0)
        return image;
    return [theme.surfaceRenderer iconImageWithTemplate:image gradientColors:appearance.commentsChevronColors locations:appearance.commentsChevronLocations shadow:nil outsets:UIEdgeInsetsZero];
}

+ (UIImage *)brandedIOS6MessageViewsIconWithColor:(UIColor *)color
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    return [TGPresentationAssets chatMessageViewsIconWithTemplate:[self brandedIOS6ResourceImage:appearance.viewsIconAssetName] color:color];
}

+ (UIImage *)brandedIOS6UnreadHeaderImageForWidth:(CGFloat)width
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    return TGBrandedIOS6SurfaceImage(theme, appearance.unreadHeaderSurfaceStyle, CGSizeMake(width, appearance.unreadHeaderHeight), NULL);
}

+ (UIImage *)brandedIOS6ConversationBackgroundImageForSize:(CGSize)size
{
    OGTheme *theme = [OGTheme brandedTheme];
    return TGBrandedIOS6BandImage(theme, theme.conversationAppearance.backgroundSurfaceStyle, size);
}

+ (UIImage *)brandedIOS6ConversationCardImageForSize:(CGSize)size topInset:(CGFloat)topInset bottomSafeInset:(CGFloat)bottomSafeInset frame:(CGRect *)frame
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    OGSurfaceStyle *cardStyle = appearance.backgroundCardSurfaceStyle;
    if (cardStyle == nil)
        return nil;

    CGRect cardFrame = TGBrandedIOS6ConversationCardFrame(appearance, size, topInset, bottomSafeInset);
    if (cardFrame.size.width < 1.0f || cardFrame.size.height < 1.0f)
        return nil;

    UIEdgeInsets outsets = [cardStyle dropShadowOutsets];
    UIImage *card = [theme.surfaceRenderer imageWithStyle:cardStyle size:CGSizeMake(outsets.left + cardFrame.size.width + outsets.right, outsets.top + cardFrame.size.height + outsets.bottom) bodyFrame:CGRectMake(outsets.left, outsets.top, cardFrame.size.width, cardFrame.size.height)];
    if (card != nil && frame != NULL)
        *frame = CGRectMake(cardFrame.origin.x - outsets.left, cardFrame.origin.y - outsets.top, card.size.width, card.size.height);
    return card;
}

+ (UIImage *)brandedIOS6ConversationCardEdgeImageWithBackground:(UIImage *)background card:(UIImage *)card cardImageFrame:(CGRect)cardImageFrame topInset:(CGFloat)topInset bottomSafeInset:(CGFloat)bottomSafeInset bottomEdge:(bool)bottomEdge frame:(CGRect *)frame
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    OGSurfaceStyle *cardStyle = appearance.backgroundCardSurfaceStyle;
    if (background == nil || card == nil || cardStyle == nil)
        return nil;

    CGSize size = background.size;
    CGRect cardFrame = TGBrandedIOS6ConversationCardFrame(appearance, size, topInset, bottomSafeInset);
    CGFloat radius = cardStyle.cornerRadius;
    if (radius < 1.0f || cardFrame.size.width < radius * 2.0f || cardFrame.size.height < radius * 2.0f)
        return nil;

    CGFloat bandHeight = ceilf(radius);
    CGRect bandFrame = CGRectMake(0.0f, bottomEdge ? CGRectGetMaxY(cardFrame) - bandHeight : CGRectGetMinY(cardFrame), size.width, bandHeight);
    UIGraphicsBeginImageContextWithOptions(bandFrame.size, false, background.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [background drawAtPoint:CGPointMake(0.0f, -bandFrame.origin.y)];
    [card drawAtPoint:CGPointMake(cardImageFrame.origin.x, cardImageFrame.origin.y - bandFrame.origin.y)];
    CGContextSetBlendMode(context, kCGBlendModeClear);
    TGBrandedIOS6AddRoundedRectPath(context, CGRectOffset(cardFrame, 0.0f, -bandFrame.origin.y), radius);
    CGContextFillPath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (frame != NULL)
        *frame = bandFrame;
    return image;
}

+ (UIImage *)brandedIOS6ScrollButtonImageMentions:(bool)mentions
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    if (appearance.scrollButtonFillColor == nil || appearance.scrollButtonGlyphColor == nil)
        return nil;
    return [TGPresentationAssets chatScrollButtonWithFillColor:appearance.scrollButtonFillColor glyphColor:appearance.scrollButtonGlyphColor lineWidth:appearance.scrollButtonGlyphLineWidth mentions:mentions];
}

+ (UIImage *)brandedIOS6InputPanelBackgroundImageForSize:(CGSize)size topOutset:(CGFloat *)topOutset
{
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    OGTheme *theme = [OGTheme brandedTheme];
    OGSurfaceStyle *style = theme.conversationAppearance.inputPanelSurfaceStyle;
    UIEdgeInsets outsets = [style dropShadowOutsets];
    if (topOutset != NULL)
        *topOutset = outsets.top;
    return [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(size.width, outsets.top + size.height) bodyFrame:CGRectMake(0.0f, outsets.top, size.width, size.height)];
}

+ (UIImage *)brandedIOS6InputButtonImageWithGlyph:(TGBrandedIOS6InputGlyph)glyph accentColor:(UIColor *)accentColor
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    UIColor *color = appearance.inputButtonIconColor;
    CGFloat glyphScale = appearance.inputButtonGlyphScale;
    CGFloat lineWidth = appearance.inputButtonGlyphLineWidth;
    OGSurfaceShadow *shadow = appearance.inputSendGlyphShadow;
    UIImage *glyphImage = nil;
    switch (glyph)
    {
        case TGBrandedIOS6InputGlyphAttach:
            glyphImage = [TGPresentationAssets inputPanelAttachGlyph:color accentColor:nil scale:glyphScale lineWidth:lineWidth];
            shadow = appearance.inputAttachGlyphShadow;
            break;
        case TGBrandedIOS6InputGlyphAttachEdit:
            glyphImage = [TGPresentationAssets inputPanelAttachGlyph:color accentColor:accentColor scale:glyphScale lineWidth:lineWidth];
            shadow = appearance.inputAttachGlyphShadow;
            break;
        case TGBrandedIOS6InputGlyphSend:
            glyphImage = [TGPresentationAssets inputPanelSendGlyph:color scale:glyphScale];
            break;
        case TGBrandedIOS6InputGlyphConfirm:
            glyphImage = [TGPresentationAssets inputPanelConfirmGlyph:color scale:glyphScale lineWidth:lineWidth];
            break;
        case TGBrandedIOS6InputGlyphMicrophone:
            glyphImage = [TGPresentationAssets inputPanelMicrophoneGlyph:color scale:glyphScale lineWidth:lineWidth];
            break;
        case TGBrandedIOS6InputGlyphVideoMessage:
            glyphImage = [TGPresentationAssets inputPanelVideoMessageGlyph:color scale:glyphScale lineWidth:lineWidth];
            break;
    }

    UIEdgeInsets padding = appearance.inputPanelPadding;
    CGFloat side = appearance.inputButtonSize;
    CGSize size = CGSizeMake(padding.left + side + padding.right, appearance.inputPanelHeight);
    CGRect bodyFrame = CGRectMake(padding.left, padding.top, side, side);
    UIImage *chrome = [theme.surfaceRenderer imageWithStyle:appearance.inputButtonSurfaceStyle size:size bodyFrame:bodyFrame];
    if (glyphImage == nil)
        return chrome;

    UIEdgeInsets glyphOutsets = [shadow outsets];
    UIImage *icon = [theme.surfaceRenderer iconImageWithTemplate:glyphImage gradientColors:@[color, color] locations:@[@0.0f, @1.0f] shadow:shadow outsets:glyphOutsets];
    UIGraphicsBeginImageContextWithOptions(size, false, chrome.scale);
    [chrome drawAtPoint:CGPointZero];
    [icon drawAtPoint:CGPointMake(CGRectGetMinX(bodyFrame) + CGFloor((side - glyphImage.size.width) / 2.0f) - glyphOutsets.left, CGRectGetMinY(bodyFrame) + CGFloor((side - glyphImage.size.height) / 2.0f) - glyphOutsets.top)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)brandedIOS6InputFieldImageWithOutsets:(UIEdgeInsets *)outsets
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    OGSurfaceStyle *style = appearance.inputFieldSurfaceStyle;
    UIEdgeInsets styleOutsets = [style dropShadowOutsets];
    if (outsets != NULL)
        *outsets = styleOutsets;
    CGFloat height = appearance.inputFieldHeight;
    CGFloat width = style.cornerRadius * 2.0f + 1.0f;
    UIImage *image = [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(styleOutsets.left + width + styleOutsets.right, styleOutsets.top + height + styleOutsets.bottom) bodyFrame:CGRectMake(styleOutsets.left, styleOutsets.top, width, height)];
    return [image stretchableImageWithLeftCapWidth:(NSInteger)(styleOutsets.left + style.cornerRadius) topCapHeight:(NSInteger)(styleOutsets.top + style.cornerRadius)];
}

+ (UIImage *)brandedIOS6ActionButtonImageHighlighted:(bool)highlighted outsets:(UIEdgeInsets *)outsets
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    OGSurfaceStyle *style = highlighted ? appearance.actionButtonHighlightedSurfaceStyle : appearance.actionButtonSurfaceStyle;
    UIEdgeInsets capInsets = [style horizontalCapInsets];
    UIEdgeInsets styleOutsets = UIEdgeInsetsZero;
    UIImage *image = TGBrandedIOS6SurfaceImage(theme, style, CGSizeMake(capInsets.left + 1.0f + capInsets.right, appearance.actionButtonHeight), &styleOutsets);
    if (outsets != NULL)
        *outsets = styleOutsets;
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, styleOutsets.left + capInsets.left, 0.0f, styleOutsets.right + capInsets.right)];
}

+ (UIImage *)brandedIOS6ActionIconTemplate:(TGBrandedIOS6ActionIcon)icon
{
    OGConversationAppearance *appearance = [OGTheme brandedTheme].conversationAppearance;
    switch (icon)
    {
        case TGBrandedIOS6ActionIconJoin:
        {
            static UIImage *joinTemplate = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                joinTemplate = [TGPresentationAssets actionPanelJoinIcon:[UIColor blackColor]];
            });
            return joinTemplate;
        }
        case TGBrandedIOS6ActionIconMute:
            return [self brandedIOS6ResourceImage:appearance.actionMuteIconAssetName];
        case TGBrandedIOS6ActionIconUnmute:
            return [self brandedIOS6ResourceImage:appearance.actionUnmuteIconAssetName];
        case TGBrandedIOS6ActionIconShare:
            return [self brandedIOS6ResourceImage:appearance.actionShareIconAssetName];
    }
    return nil;
}

+ (UIImage *)brandedIOS6ActionIconImage:(TGBrandedIOS6ActionIcon)icon outsets:(UIEdgeInsets *)outsets
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGConversationAppearance *appearance = theme.conversationAppearance;
    OGSurfaceShadow *shadow = appearance.actionButtonIconShadow;
    UIEdgeInsets iconOutsets = shadow != nil ? [shadow outsets] : UIEdgeInsetsZero;
    if (outsets != NULL)
        *outsets = iconOutsets;
    return [theme.surfaceRenderer iconImageWithTemplate:[self brandedIOS6ActionIconTemplate:icon] gradientColors:appearance.actionButtonIconColors locations:appearance.actionButtonIconLocations shadow:shadow outsets:iconOutsets];
}

+ (UIImage *)brandedIOS6ConversationAvatarOverlayImageForSize:(CGSize)size outsets:(UIEdgeInsets *)outsets
{
    OGTheme *theme = [OGTheme brandedTheme];
    OGSurfaceStyle *style = theme.conversationAppearance.avatarOverlaySurfaceStyle;
    UIEdgeInsets styleOutsets = [style dropShadowOutsets];
    if (outsets != NULL)
        *outsets = styleOutsets;
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    return [theme.surfaceRenderer imageWithStyle:style size:CGSizeMake(styleOutsets.left + size.width + styleOutsets.right, styleOutsets.top + size.height + styleOutsets.bottom) bodyFrame:CGRectMake(styleOutsets.left, styleOutsets.top, size.width, size.height)];
}

+ (UIFont *)brandedIOS6NavigationTitleFont
{
    return [OGTheme brandedTheme].navigationAppearance.titleFont;
}

+ (UIColor *)brandedIOS6NavigationTitleColor
{
    return [OGTheme brandedTheme].navigationAppearance.titleColor;
}

+ (UIColor *)brandedIOS6NavigationTitleShadowColor
{
    return [OGTheme brandedTheme].navigationAppearance.titleShadowColor;
}

+ (UIFont *)brandedIOS6NavigationButtonFont
{
    return [OGTheme brandedTheme].navigationAppearance.buttonFont;
}

+ (UIColor *)brandedIOS6NavigationButtonShadowColor
{
    return [OGTheme brandedTheme].navigationAppearance.buttonShadowColor;
}

+ (CGFloat)brandedIOS6NavigationButtonWidthForTitle:(NSString *)title
{
    OGNavigationAppearance *appearance = [OGTheme brandedTheme].navigationAppearance;
    CGFloat titleWidth = CGCeil([title sizeWithFont:appearance.buttonFont].width);
    return MAX(appearance.buttonMinimumWidth, titleWidth + appearance.buttonHorizontalPadding * 2.0f);
}

+ (UIBarButtonItem *)brandedIOS6BarButtonItemWithTitle:(NSString *)title target:(id)target action:(SEL)action
{
    if (iosMajorVersion() >= 5)
    {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleBordered target:target action:action];
        item.width = [self brandedIOS6NavigationButtonWidthForTitle:title];
        return item;
    }

    return [[UIBarButtonItem alloc] initWithCustomView:[self brandedIOS6NavigationButtonWithTitle:title target:target action:action]];
}

+ (UIBarButtonItem *)brandedIOS6BarButtonItemWithTitle:(NSString *)title target:(id)target action:(SEL)action offset:(UIOffset)offset
{
    if (ABS(offset.horizontal) <= FLT_EPSILON && ABS(offset.vertical) <= FLT_EPSILON)
        return [self brandedIOS6BarButtonItemWithTitle:title target:target action:action];

    UIButton *button = [self brandedIOS6NavigationButtonWithTitle:title target:target action:action];
    CGSize buttonSize = button.frame.size;
    CGFloat horizontalPadding = ABS(offset.horizontal);
    CGFloat verticalPadding = ABS(offset.vertical) * 2.0f;
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, buttonSize.width + horizontalPadding, buttonSize.height + verticalPadding)];
    container.backgroundColor = [UIColor clearColor];
    button.frame = CGRectMake(offset.horizontal > 0.0f ? horizontalPadding : 0.0f, offset.vertical > 0.0f ? verticalPadding : 0.0f, buttonSize.width, buttonSize.height);
    [container addSubview:button];
    return [[UIBarButtonItem alloc] initWithCustomView:container];
}

+ (UIBarButtonItem *)navigationBarButtonItemWithTitle:(NSString *)title style:(UIBarButtonItemStyle)style target:(id)target action:(SEL)action
{
    UIOffset offset = [self brandedIOS6Style] ? [OGTheme brandedTheme].settingsAppearance.navigationButtonOffset : UIOffsetMake(0.0f, 0.0f);
    if (ABS(offset.horizontal) > FLT_EPSILON || ABS(offset.vertical) > FLT_EPSILON)
        return [self brandedIOS6BarButtonItemWithTitle:title target:target action:action offset:offset];
    return [[UIBarButtonItem alloc] initWithTitle:title style:style target:target action:action];
}

+ (UIButton *)brandedIOS6NavigationButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action
{
    CGFloat width = [self brandedIOS6NavigationButtonWidthForTitle:title];
    OGNavigationAppearance *appearance = [OGTheme brandedTheme].navigationAppearance;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0.0f, 0.0f, width, appearance.buttonImageHeight);
    button.titleLabel.font = appearance.buttonFont;
    button.titleLabel.shadowOffset = CGSizeMake(appearance.buttonShadowOffset.horizontal, appearance.buttonShadowOffset.vertical);
    button.titleEdgeInsets = UIEdgeInsetsMake(0.0f, 0.0f, appearance.buttonImageHeight - appearance.buttonHeight, 0.0f);
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:appearance.buttonTitleColor forState:UIControlStateNormal];
    [button setTitleColor:[appearance.buttonTitleColor colorWithAlphaComponent:appearance.buttonHighlightedAlpha] forState:UIControlStateHighlighted];
    [button setTitleShadowColor:appearance.buttonShadowColor forState:UIControlStateNormal];
    [button setBackgroundImage:[self brandedIOS6NavigationButtonImage:false highlighted:false landscape:false width:width] forState:UIControlStateNormal];
    [button setBackgroundImage:[self brandedIOS6NavigationButtonImage:false highlighted:true landscape:false width:width] forState:UIControlStateHighlighted];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (instancetype)initWithPallete:(TGPresentationPallete *)pallete
{
    self = [super init];
    if (self != nil)
    {
        _currentId = arc4random();
        _pallete = pallete;
        _images = [TGPresentationImages imagesWithPallete:pallete];
    }
    return self;
}

+ (instancetype)presentationWithPallete:(TGPresentationPallete *)pallete
{
    return [[self alloc] initWithPallete:pallete];
}

+ (instancetype)defaultPresentation
{
    return [self presentationWithPallete:[[TGDefaultPresentationPallete alloc] init]];
}

+ (NSString *)documentsPath
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      if (iosMajorVersion() >= 8)
                      {
                          NSString *groupName = [@"group." stringByAppendingString:[[NSBundle mainBundle] bundleIdentifier]];
                          
                          NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupName];
                          
                          if (groupURL != nil)
                          {
                              NSString *documentsPath = [[groupURL path] stringByAppendingPathComponent:@"Documents"];
                              
                              [[NSFileManager defaultManager] createDirectoryAtPath:documentsPath withIntermediateDirectories:true attributes:nil error:NULL];
                              
                              path = documentsPath;
                          }
                          else
                          {
                              NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
                              
                              if ([paths count] != 0)
                                  path = [paths objectAtIndex:0];
                          }
                      }
                      else
                      {
                          NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
                          
                          if ([paths count] != 0)
                              path = [paths objectAtIndex:0];
                      }
                  });
    
    return path;
}

+ (NSString *)presentationPath
{
    return [[self documentsPath] stringByAppendingPathComponent:@"presentation.dat"];
}

+ (NSString *)autoNightPreferencesPath
{
    return [[self documentsPath] stringByAppendingPathComponent:@"autonight.dat"];
}

+ (int32_t)indexForPallete:(TGPresentationPallete *)pallete
{
    if ([pallete isKindOfClass:[TGDayPresentationPallete class]])
        return 1;
    if ([pallete isKindOfClass:[TGNightPresentationPallete class]])
        return 2;
    if ([pallete isKindOfClass:[TGNightBluePresentationPallete class]])
        return 3;
    
    return 0;
}

+ (TGPresentationPallete *)nightPalleteWithIndex:(int32_t)index
{
    switch (index)
    {
        case 2:
            return [[TGNightPresentationPallete alloc] init];
        default:
            return [[TGNightBluePresentationPallete alloc] init];
    }
}

+ (TGPresentationPallete *)palleteWithState:(TGPresentationState *)state
{
    if (state == nil)
        return [[TGDefaultPresentationPallete alloc] init];
    
    switch (state.pallete)
    {
        case 1:
            return [TGDayPresentationPallete dayPalleteWithAccentColor:UIColorRGB(state.userInfo)];
        case 2:
            return [[TGNightPresentationPallete alloc] init];
        case 3:
            return [[TGNightBluePresentationPallete alloc] init];
        default:
            return [[TGDefaultPresentationPallete alloc] init];
    }
}

+ (CGFloat)fontSizeWithState:(TGPresentationState *)state
{
    if (state == nil || state.fontSize == 0)
        return 0.0f;
    
    return state.fontSize;
}

+ (TGPresentationState *)loadState
{
    NSData *data = [NSData dataWithContentsOfFile:[self presentationPath]];
    if (data.length == 0)
        return nil;
    
    TGPresentationState *state = nil;
    @try {
        state = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (NSException *e) {
        
    }
    return state;
}

+ (void)saveCurrentState
{
    int32_t userInfo = [currentPresentation.pallete isKindOfClass:[TGDayPresentationPallete class]] ? TGColorHexCode(currentPresentation.pallete.accentColor) : 0;
    currentState = [[TGPresentationState alloc] initWithPallete:[self indexForPallete:currentPresentation.pallete] userInfo:userInfo fontSize:useDynamicTypeFontSize ? 0 : (int32_t)fontSize];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:currentState];
    [data writeToFile:[self presentationPath] atomically:true];
}

+ (TGPresentationAutoNightPreferences *)loadAutoNightPreferences
{
    NSData *data = [NSData dataWithContentsOfFile:[self autoNightPreferencesPath]];
    if (data.length == 0)
        return nil;
    
    TGPresentationAutoNightPreferences *state = nil;
    @try {
        state = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (NSException *e) {
        
    }
    return state;
}

+ (NSNumber *)isAutoNightActivated
{
    if (autoNightPreferences.mode == TGPresentationAutoNightModeDisabled)
        return nil;
    
    __block bool value = false;
    [[[self autoNightThemeSignal] take:1] startWithNext:^(id next)
    {
        value = [next intValue] != 0;
    }];
    
    return @(value);
}

+ (SSignal *)autoNightPreferences
{
    return [[SSignal single:autoNightPreferences] then:autoNightPreferencesPipe.signalProducer()];
}

+ (void)updateAutoNightPreferences:(TGPresentationAutoNightPreferences *(^)(TGPresentationAutoNightPreferences *))updateBlock
{
    autoNightPreferences = updateBlock(autoNightPreferences);
    autoNightPreferencesPipe.sink(autoNightPreferences);
    
    [self saveAutoNightPreferences];
}

+ (void)saveAutoNightPreferences
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:autoNightPreferences];
    [data writeToFile:[self autoNightPreferencesPath] atomically:true];
}

+ (SSignal *)scheduledAutoNightSignal:(int32_t)startTime endTime:(int32_t)endTime
{
    bool (^check)(void) = ^bool
    {
        NSDate *currentDate = [NSDate date];
        
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDateComponents *components = [cal components:(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:currentDate];
        
        [components setHour:0];
        [components setMinute:0];
        [components setSecond:0];
        
        NSDate *startDate = [cal dateFromComponents:components];
        NSTimeInterval secs = [currentDate timeIntervalSinceDate:startDate];
        
        if (startTime > endTime)
            return secs >= startTime || secs < endTime;
        else
            return secs >= startTime && secs < endTime;
    };
    
    SSignal *timerSignal = [[[[SSignal single:nil] map:^NSNumber *(__unused id value)
    {
        return @(check());
    }] then:[[SSignal complete] delay:60.0 onQueue:[SQueue mainQueue]]] restart];
    
    return [[SSignal single:@(check())] then:timerSignal];
}

+ (int)_timeForDate:(NSDate *)date
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ) fromDate:date];
    
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    
    NSDate *startDate = [cal dateFromComponents:components];
    NSTimeInterval secs = [date timeIntervalSinceDate:startDate];
    return (int)secs;
}

+ (SSignal *)autoNightThemeSignal
{
    return [[self autoNightPreferences] mapToSignal:^SSignal *(TGPresentationAutoNightPreferences *preferences)
    {
        if (preferences.mode == TGPresentationAutoNightModeBrightness)
        {
            SSignal *decisionSignal = [[TGScreenBrightnessSignals brightnessSignal] map:^NSNumber *(NSNumber *brightness)
            {
                return @(brightness.doubleValue < preferences.brightnessThreshold ? preferences.preferredPalette : 0);
            }];
            
            SSignal *throttledSignal = [[[decisionSignal ignoreRepeated] reduceLeftWithPassthrough:nil with:^id(id value, id next, void (^passthrough)(id))
            {
                if (value == nil)
                    passthrough([SSignal single:next]);
                else
                    passthrough([[SSignal single:next] delay:2.0 onQueue:[SQueue mainQueue]]);
                
                return @true;
            }] switchToLatest];
            
            return [TGAppDelegateInstance.isActive mapToSignal:^SSignal *(NSNumber *active)
            {
                if (active.boolValue)
                    return throttledSignal;
                else
                    return [SSignal never];
            }];
        }
        else if (preferences.mode == TGPresentationAutoNightModeScheduled)
        {
            return [[self scheduledAutoNightSignal:preferences.scheduleStart endTime:preferences.scheduleEnd] map:^id(NSNumber *value) {
                return @(value.boolValue ? preferences.preferredPalette : 0);
            }];
        }
        else if (preferences.mode == TGPresentationAutoNightModeSunsetSunrise)
        {
            EDSunriseSet *calculator = [[EDSunriseSet alloc] initWithDate:[NSDate date] timezone:[NSTimeZone localTimeZone] latitude:preferences.latitude longitude:preferences.longitude];
            int32_t start = [self _timeForDate:calculator.sunset];
            int32_t end = [self _timeForDate:calculator.sunrise];
            return [[self scheduledAutoNightSignal:start endTime:end] map:^id(NSNumber *value) {
                return @(value.boolValue ? preferences.preferredPalette : 0);
            }];
        }
        else
        {
            return [SSignal single:@0];
        }
    }];
}

+ (void)initialize
{
    if (self != [TGPresentation class])
        return;

    currentState = [self loadState];
    if (currentState == nil)
        currentState = [[TGPresentationState alloc] initWithPallete:0 userInfo:0 fontSize:0];
    presentationPipe = [[SPipe alloc] init];

    TGPresentationPallete *initialPallete = TGPresentationPalleteForInterfaceStyle([self palleteWithState:currentState]);
    [OGTheme setBrandedThemeDark:initialPallete.isDark];
    currentPresentation = [[TGPresentation alloc] initWithPallete:initialPallete];

    fontSize = currentState.fontSize;
    fontPipe = [[SPipe alloc] init];
    if (fontSize < FLT_EPSILON)
        [self _resetFontSize];

    autoNightPreferences = [self loadAutoNightPreferences];
    if (autoNightPreferences == nil)
        autoNightPreferences = [TGPresentationAutoNightPreferences defaultAutoNight];
    autoNightPreferencesPipe = [[SPipe alloc] init];
}

+ (void)startAutoNight
{
    if (autoNightDisposable != nil)
        return;

    autoNightDisposable = [[[self autoNightThemeSignal] ignoreRepeated] startWithNext:^(NSNumber *next)
    {
        TGPresentationPallete *pallete = next.integerValue > 0 ? [self nightPalleteWithIndex:next.intValue] : [self currentSavedPallete];
        if (currentPresentation != nil && TGPresentationPalletesMatch(TGPresentationPalleteForInterfaceStyle(pallete), currentPresentation.pallete))
            return;
        [self switchToPallete:pallete temporary:true];
    }];
}

+ (void)switchToPallete:(TGPresentationPallete *)pallete
{
    [self switchToPallete:pallete temporary:false];
}

+ (void)switchToPallete:(TGPresentationPallete *)pallete temporary:(bool)temporary
{
    pallete = TGPresentationPalleteForInterfaceStyle(pallete);

    [TGCheckButtonView resetCache];
    [[TGMediaStoreContext instance] clearMemoryCache];
    
    [OGTheme setBrandedThemeDark:pallete.isDark];
    currentPresentation = [[TGPresentation alloc] initWithPallete:pallete];
    presentationPipe.sink(currentPresentation);

    [self refreshUIAppearance];
    [self prewarmBrandedIOS6ConversationSurfaces];
    
    if (!temporary)
    {
        [self saveCurrentState];
    }
    else
    {
        TGWallpaperInfo *savedWallpaper = [[TGWallpaperManager instance] savedWallpaperInfo];
        bool isDefaultWallpaper = [savedWallpaper isKindOfClass:[TGColorWallpaperInfo class]] || ([savedWallpaper isKindOfClass:[TGBuiltinWallpaperInfo class]] && [(TGBuiltinWallpaperInfo *)savedWallpaper isDefault]);
        
        if (pallete.isDark && isDefaultWallpaper)
        {
            TGColorWallpaperInfo *info = [[TGColorWallpaperInfo alloc] initWithColor:TGColorHexCode(pallete.backgroundColor)];
            [[TGWallpaperManager instance] setCurrentWallpaperWithInfo:info temporary:true];
        }
        else
        {
            [[TGWallpaperManager instance] restoreCurrentWallpaper];
        }
        
        TGViewController *rootController = TGAppDelegateInstance.rootController;
        if (rootController.isViewLoaded && rootController.view.window != nil && [UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        {
            UIView *snapshotView = [rootController.view snapshotViewAfterScreenUpdates:false];
            [rootController.view addSubview:snapshotView];
            
            [UIView animateWithDuration:0.2 animations:^
            {
                snapshotView.alpha = 0.0f;
                [rootController setNeedsStatusBarAppearanceUpdate];
            } completion:^(__unused BOOL finished)
            {
                [snapshotView removeFromSuperview];
            }];
        }
        else if (rootController.isViewLoaded)
            [rootController setNeedsStatusBarAppearanceUpdate];
    }
}

+ (void)refreshUIAppearance
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
    return;
#else
    if (iosMajorVersion() < 5)
        return;

    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 30), false, 0.0f);
        UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        UIColor *navigationButtonColor = TGPresentation.current.pallete.navigationButtonColor;
        UIColor *navigationTitleColor = TGPresentation.current.pallete.navigationTitleColor;
        UIBarButtonItem *item = [UIBarButtonItem appearanceWhenContainedIn:[TGNavigationBar class], nil];
        bool classicIOS6Style = [TGPresentation classicIOS6Style];
        bool brandedIOS6Style = [TGPresentation brandedIOS6Style];
        bool classicDarkIOS6Style = classicIOS6Style && TGPresentation.current.pallete.isDark;
        OGNavigationAppearance *navigationAppearance = brandedIOS6Style ? [OGTheme brandedTheme].navigationAppearance : nil;

        if (classicIOS6Style)
        {
            UIImage *buttonImage = TGClassicIOS6NavigationButtonImage(false, false, false);
            UIImage *buttonHighlightedImage = TGClassicIOS6NavigationButtonImage(false, true, false);
            UIImage *buttonLandscapeImage = TGClassicIOS6NavigationButtonImage(false, false, true);
            UIImage *buttonLandscapeHighlightedImage = TGClassicIOS6NavigationButtonImage(false, true, true);
            [item setBackgroundImage:buttonImage ?: transparentImage forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [item setBackgroundImage:buttonHighlightedImage ?: buttonImage ?: transparentImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [item setBackgroundImage:buttonLandscapeImage ?: buttonImage ?: transparentImage forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
            [item setBackgroundImage:buttonLandscapeHighlightedImage ?: buttonLandscapeImage ?: buttonHighlightedImage ?: buttonImage ?: transparentImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
        }
        else
        {
            [item setBackgroundImage:transparentImage forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
            [item setBackgroundImage:transparentImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
            [item setBackgroundImage:transparentImage forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
            [item setBackgroundImage:transparentImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
        }

        UIImage *backImage = classicIOS6Style ? TGClassicIOS6NavigationButtonImage(true, false, false) : TGTintedImage([UIImage imageNamed:@"NavigationBackButton.png"], navigationButtonColor);
        UIImage *backHighlightedImage = classicIOS6Style ? TGClassicIOS6NavigationButtonImage(true, true, false) : TGTintedImage([UIImage imageNamed:@"NavigationBackButton_Highlighted.png"], navigationButtonColor);
        UIImage *backLandscapeImage = classicIOS6Style ? TGClassicIOS6NavigationButtonImage(true, false, true) : TGTintedImage([UIImage imageNamed:@"NavigationBackButtonLandscape.png"], navigationButtonColor);
        UIImage *backLandscapeHighlightedImage = classicIOS6Style ? TGClassicIOS6NavigationButtonImage(true, true, true) : TGTintedImage([UIImage imageNamed:@"NavigationBackButtonLandscape_Highlighted.png"], navigationButtonColor);

        UIImage *backButtonImage = classicIOS6Style ? backImage : [backImage stretchableImageWithLeftCapWidth:(int)backImage.size.width topCapHeight:0];
        UIImage *backButtonHighlightedImage = classicIOS6Style ? backHighlightedImage : [backHighlightedImage stretchableImageWithLeftCapWidth:(int)backHighlightedImage.size.width topCapHeight:0];
        UIImage *backButtonLandscapeImage = classicIOS6Style ? backLandscapeImage : [backLandscapeImage stretchableImageWithLeftCapWidth:(int)backLandscapeImage.size.width topCapHeight:0];
        UIImage *backButtonLandscapeHighlightedImage = classicIOS6Style ? backLandscapeHighlightedImage : [backLandscapeHighlightedImage stretchableImageWithLeftCapWidth:(int)backLandscapeHighlightedImage.size.width topCapHeight:0];
        [item setBackButtonBackgroundImage:backButtonImage forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [item setBackButtonBackgroundImage:backButtonHighlightedImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [item setBackButtonBackgroundImage:backButtonLandscapeImage forState:UIControlStateNormal barMetrics:UIBarMetricsLandscapePhone];
        [item setBackButtonBackgroundImage:backButtonLandscapeHighlightedImage forState:UIControlStateHighlighted barMetrics:UIBarMetricsLandscapePhone];
        UIOffset backButtonTitleOffset = brandedIOS6Style ? navigationAppearance.backButtonTitleOffset : UIOffsetMake(classicIOS6Style ? 1.0f : 5.0f, classicIOS6Style ? 0.0f : -1.0f);
        UIOffset backButtonLandscapeTitleOffset = brandedIOS6Style ? navigationAppearance.backButtonLandscapeTitleOffset : UIOffsetMake(classicIOS6Style ? 1.0f : 5.0f, classicIOS6Style ? -1.0f : -3.0f);
        UIOffset buttonTitleOffset = brandedIOS6Style ? navigationAppearance.buttonTitleOffset : UIOffsetMake(0.0f, classicIOS6Style ? 0.0f : 1.0f);
        [item setBackButtonTitlePositionAdjustment:backButtonTitleOffset forBarMetrics:UIBarMetricsDefault];
        [item setBackButtonTitlePositionAdjustment:backButtonLandscapeTitleOffset forBarMetrics:UIBarMetricsLandscapePhone];
        [item setTitlePositionAdjustment:buttonTitleOffset forBarMetrics:UIBarMetricsDefault];

        UIColor *buttonTitleColor = brandedIOS6Style ? navigationAppearance.buttonTitleColor : (classicIOS6Style ? [UIColor whiteColor] : TGPresentation.current.pallete.accentColor);
        UIColor *buttonShadowColor = brandedIOS6Style ? navigationAppearance.buttonShadowColor : (classicIOS6Style ? (classicDarkIOS6Style ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f)) : [UIColor clearColor]);
        UIFont *buttonFont = brandedIOS6Style ? navigationAppearance.buttonFont : (classicIOS6Style ? TGBoldSystemFontOfSize(12.0f) : TGSystemFontOfSize(16.0f));
        UIOffset buttonShadowOffset = brandedIOS6Style ? navigationAppearance.buttonShadowOffset : UIOffsetMake(0.0f, classicIOS6Style ? -1.0f : 0.0f);
        CGFloat highlightedButtonAlpha = brandedIOS6Style ? navigationAppearance.buttonHighlightedAlpha : 0.75f;
        [item setTitleTextAttributes:@{UITextAttributeTextColor:buttonTitleColor, UITextAttributeTextShadowColor:buttonShadowColor, UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:buttonShadowOffset], UITextAttributeFont:buttonFont} forState:UIControlStateNormal];
        [item setTitleTextAttributes:@{UITextAttributeTextColor:[buttonTitleColor colorWithAlphaComponent:highlightedButtonAlpha], UITextAttributeTextShadowColor:buttonShadowColor, UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:buttonShadowOffset], UITextAttributeFont:buttonFont} forState:UIControlStateHighlighted];

        UIColor *effectiveNavigationTitleColor = brandedIOS6Style ? navigationAppearance.titleColor : (classicIOS6Style ? [UIColor whiteColor] : navigationTitleColor);
        UIColor *navigationTitleShadowColor = brandedIOS6Style ? navigationAppearance.titleShadowColor : (classicIOS6Style ? (classicDarkIOS6Style ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f)) : [UIColor clearColor]);
        UIOffset navigationTitleShadowOffset = brandedIOS6Style ? navigationAppearance.titleShadowOffset : UIOffsetMake(0.0f, classicIOS6Style ? -1.0f : 0.0f);
        UIFont *navigationTitleFont = brandedIOS6Style ? navigationAppearance.titleFont : TGBoldSystemFontOfSize(17.0f);
        [[TGNavigationBar appearance] setTitleTextAttributes:@{UITextAttributeTextColor:effectiveNavigationTitleColor, UITextAttributeTextShadowColor:navigationTitleShadowColor, UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:navigationTitleShadowOffset], UITextAttributeFont:navigationTitleFont}];
        CGFloat titleVerticalOffset = brandedIOS6Style ? (TGIsRetina() ? navigationAppearance.titleRetinaVerticalOffset : navigationAppearance.titleVerticalOffset) : (TGIsRetina() ? 0.5f : 0.0f);
        CGFloat titleLandscapeVerticalOffset = brandedIOS6Style ? navigationAppearance.titleLandscapeVerticalOffset : -1.0f;
        [[TGNavigationBar appearance] setTitleVerticalPositionAdjustment:titleVerticalOffset forBarMetrics:UIBarMetricsDefault];
        [[TGNavigationBar appearance] setTitleVerticalPositionAdjustment:titleLandscapeVerticalOffset forBarMetrics:UIBarMetricsLandscapePhone];
    }

    if (iosMajorVersion() >= 7)
    {
        [[UITextField appearance] setTintColor:TGPresentation.current.pallete.maybeAccentColor];
        [[UITextView appearance] setTintColor:TGPresentation.current.pallete.maybeAccentColor];
    }
#endif
}

+ (TGPresentation *)current
{
    return currentPresentation;
}

static volatile int32_t TGPresentationCachedInterfaceStyle = -1;

+ (TGInterfaceStyle)interfaceStyle
{
    int32_t cached = TGPresentationCachedInterfaceStyle;
    if (cached >= 0)
        return (TGInterfaceStyle)cached;

    TGInterfaceStyle style = [self uncachedInterfaceStyle];
    TGPresentationCachedInterfaceStyle = (int32_t)style;
    return style;
}

+ (TGInterfaceStyle)uncachedInterfaceStyle
{
    if (![self classicIOS6StyleAvailable])
        return TGInterfaceStyleModern;

    return (TGInterfaceStyle)TGCurrentInterfaceStyle();
}

+ (void)setInterfaceStyle:(TGInterfaceStyle)style
{
    if (style < TGInterfaceStyleModern || style > TGInterfaceStyleFekla)
        style = TGInterfaceStyleModern;

    if ([self interfaceStyle] == style)
        return;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:style forKey:TGInterfaceStyleDefaultsKey];
    [defaults setBool:style != TGInterfaceStyleModern forKey:TGClassicIOS6StyleDefaultsKey];
    [defaults synchronize];
    TGPresentationCachedInterfaceStyle = -1;

    if (currentPresentation != nil)
    {
        TGPresentationPallete *pallete = [self currentSavedPallete];
        if (currentPresentation.pallete.isDark && !pallete.isDark)
            pallete = [self nightPalleteWithIndex:autoNightPreferences.preferredPalette];
        [self switchToPallete:pallete temporary:true];
    }
}

+ (bool)classicIOS6Style
{
    return [self interfaceStyle] != TGInterfaceStyleModern;
}

+ (bool)brandedIOS6Style
{
    return [self interfaceStyle] == TGInterfaceStyleFekla;
}

+ (bool)classicIOS6StyleAvailable
{
    return true;
}

+ (void)setClassicIOS6Style:(bool)enabled
{
    [self setInterfaceStyle:enabled ? TGInterfaceStyleClassic : TGInterfaceStyleModern];
}


+ (bool)classicIOS6UsesPaletteAdaptedAssets
{
    if (![self classicIOS6Style] || [self brandedIOS6Style])
        return false;

    TGPresentationPallete *pallete = currentPresentation != nil ? currentPresentation.pallete : [self currentSavedPallete];
    if (pallete == nil)
        pallete = [[TGDefaultPresentationPallete alloc] init];

    return ![pallete isMemberOfClass:[TGDefaultPresentationPallete class]];
}

+ (UIImage *)classicIOS6ThemedImage:(UIImage *)image tintColor:(UIColor *)tintColor
{
    return [self classicIOS6ThemedImage:image tintColor:tintColor alpha:0.7f];
}

+ (UIImage *)classicIOS6ThemedImage:(UIImage *)image tintColor:(UIColor *)tintColor alpha:(CGFloat)alpha
{
    if (image == nil || tintColor == nil || ![self classicIOS6UsesPaletteAdaptedAssets])
        return image;

    TGPresentationPallete *pallete = currentPresentation != nil ? currentPresentation.pallete : [self currentSavedPallete];
    CGFloat intensity = pallete.isDark ? MAX(0.45f, alpha) : MIN(0.55f, MAX(0.18f, alpha * 0.6f));
    return TGClassicIOS6RecoloredImage(image, tintColor, intensity);
}

+ (TGPresentationPallete *)currentSavedPallete
{
    return TGPresentationPalleteForInterfaceStyle([self palleteWithState:currentState]);
}

+ (SSignal *)signal
{
    return [[SSignal single:[self current]] then:presentationPipe.signalProducer()];
}

+ (SSignal *)fontSizeSignal
{
    return [[SSignal single:@(fontSize)] then:fontPipe.signalProducer()];
}

+ (CGFloat)fontSize
{
    return fontSize;
}

+ (void)setFontSize:(CGFloat)newFontSize
{
    fontSize = newFontSize;
    useDynamicTypeFontSize = false;
    
    fontPipe.sink(@(fontSize));
    
    [self saveCurrentState];
}

+ (void)resetFontSize
{
    [self _resetFontSize];
    fontPipe.sink(@(fontSize));
    
    [self saveCurrentState];
}

+ (void)_resetFontSize
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7)
    {
        useDynamicTypeFontSize = true;
        fontSize = [UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize;
        if (dynamicTypeDisposable == nil)
        {
            dynamicTypeDisposable = [[TGModernConversationControllerDynamicTypeSignals dynamicTypeBaseFontPointSize] startWithNext:^(NSNumber *next)
            {
                if (useDynamicTypeFontSize)
                {
                    fontSize = next.floatValue;
                    fontPipe.sink(next);
                }
            }];
        }
    }
    else
#endif
    {
        fontSize = 17.0f;
    }
}

@end


@implementation UIColor (HSB)

- (UIColor *)colorWithHueMultiplier:(CGFloat)hueMultiplier saturationMultiplier:(CGFloat)saturationMultiplier brightnessMultiplier:(CGFloat)brightnessMultiplier
{
    CGFloat currentHue = 0.0f;
    CGFloat currentSaturation = 0.0f;
    CGFloat currentBrightness = 0.0f;
    CGFloat currentAlpha = 0.0f;
    
    if (TGColorGetHSBA(self, &currentHue, &currentSaturation, &currentBrightness, &currentAlpha))
    {
        return [UIColor colorWithHue:currentHue * hueMultiplier saturation:currentSaturation * saturationMultiplier brightness:currentBrightness * brightnessMultiplier alpha:currentAlpha];
    }
    else
    {
        return self;
    }
}

- (int32_t)hexCode
{
    return (int32_t)TGColorHexCode(self);
}

@end


@implementation TGPresentationState

- (instancetype)initWithPallete:(int32_t)pallete userInfo:(int32_t)userInfo fontSize:(int32_t)fontSize
{
    self = [super init];
    if (self != nil)
    {
        _pallete = pallete;
        _userInfo = userInfo;
        _fontSize = fontSize;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _pallete = [aDecoder decodeInt32ForKey:@"p"];
        _userInfo = [aDecoder decodeInt32ForKey:@"u"];
        _fontSize = [aDecoder decodeInt32ForKey:@"f"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:_pallete forKey:@"p"];
    [aCoder encodeInt32:_userInfo forKey:@"u"];
    [aCoder encodeInt32:_fontSize forKey:@"f"];
}

@end

const CGFloat TGPresentationDefaultBrightnessThreshold = 0.25f;

@implementation TGPresentationAutoNightPreferences

- (instancetype)initWithMode:(TGPresentationAutoNightMode)mode brightnessThreshold:(CGFloat)brightnessThreshold scheduleStart:(int32_t)scheduleStart scheduleEnd:(int32_t)scheduleEnd latitude:(CGFloat)latitude longitude:(CGFloat)longitude cachedLocationName:(NSString *)cachedLocationName preferredPalette:(int32_t)preferredPallete
{
    self = [super init];
    if (self != nil)
    {
        _mode = mode;
        _brightnessThreshold = brightnessThreshold;
        _scheduleStart = scheduleStart;
        _scheduleEnd = scheduleEnd;
        _latitude = latitude;
        _longitude = longitude;
        _cachedLocationName = cachedLocationName;
        _preferredPalette = preferredPallete;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _mode = [aDecoder decodeInt32ForKey:@"m"];
        _brightnessThreshold = [aDecoder decodeDoubleForKey:@"b"];
        _scheduleStart = [aDecoder decodeInt32ForKey:@"ss"];
        _scheduleEnd = [aDecoder decodeInt32ForKey:@"se"];
        _latitude = [aDecoder decodeDoubleForKey:@"lat"];
        _longitude = [aDecoder decodeDoubleForKey:@"lon"];
        _cachedLocationName = [aDecoder decodeObjectForKey:@"loc"];
        _preferredPalette = [aDecoder decodeInt32ForKey:@"p"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:_mode forKey:@"m"];
    [aCoder encodeDouble:_brightnessThreshold forKey:@"b"];
    [aCoder encodeInt32:_scheduleStart forKey:@"ss"];
    [aCoder encodeInt32:_scheduleEnd forKey:@"se"];
    [aCoder encodeDouble:_latitude forKey:@"lat"];
    [aCoder encodeDouble:_longitude forKey:@"lon"];
    [aCoder encodeObject:_cachedLocationName forKey:@"loc"];
    [aCoder encodeInt32:_preferredPalette forKey:@"p"];
}

+ (instancetype)defaultAutoNight
{
    return [[TGPresentationAutoNightPreferences alloc] initWithMode:TGPresentationAutoNightModeDisabled brightnessThreshold:TGPresentationDefaultBrightnessThreshold scheduleStart:79200 scheduleEnd:32400 latitude:0.0 longitude:0.0 cachedLocationName:nil preferredPalette:3];
}

- (instancetype)disabledAutoNight
{
    return [[TGPresentationAutoNightPreferences alloc] initWithMode:TGPresentationAutoNightModeDisabled brightnessThreshold:TGPresentationDefaultBrightnessThreshold scheduleStart:self.scheduleStart scheduleEnd:self.scheduleEnd latitude:self.latitude longitude:self.longitude cachedLocationName:self.cachedLocationName preferredPalette:self.preferredPalette];
}

- (instancetype)brightnessModeWithThreshold:(CGFloat)threshold
{
    return [[TGPresentationAutoNightPreferences alloc] initWithMode:TGPresentationAutoNightModeBrightness brightnessThreshold:threshold scheduleStart:self.scheduleStart scheduleEnd:self.scheduleEnd latitude:self.latitude longitude:self.longitude cachedLocationName:self.cachedLocationName preferredPalette:self.preferredPalette];
}

- (instancetype)scheduledModeWithStart:(int32_t)start end:(int32_t)end
{
    return [[TGPresentationAutoNightPreferences alloc] initWithMode:TGPresentationAutoNightModeScheduled brightnessThreshold:TGPresentationDefaultBrightnessThreshold scheduleStart:start scheduleEnd:end latitude:self.latitude longitude:self.longitude cachedLocationName:self.cachedLocationName preferredPalette:self.preferredPalette];
}

- (instancetype)sunsetSunriseModeWithLatitude:(CGFloat)latitude longitude:(CGFloat)longitude cachedLocationName:(NSString *)cachedLocationName
{
    return [[TGPresentationAutoNightPreferences alloc] initWithMode:TGPresentationAutoNightModeSunsetSunrise brightnessThreshold:TGPresentationDefaultBrightnessThreshold scheduleStart:self.scheduleStart scheduleEnd:self.scheduleEnd latitude:latitude longitude:longitude cachedLocationName:cachedLocationName preferredPalette:self.preferredPalette];
}

- (instancetype)preferredPalette:(int32_t)palette
{
    return [[TGPresentationAutoNightPreferences alloc] initWithMode:self.mode brightnessThreshold:self.brightnessThreshold scheduleStart:self.scheduleStart scheduleEnd:self.scheduleEnd latitude:self.latitude longitude:self.longitude cachedLocationName:self.cachedLocationName preferredPalette:palette];
}

@end
