#import "TGPresentation.h"
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
    return [TGSearchBarPallete palleteWithDark:self.pallete.isDark backgroundColor:self.pallete.searchBarBackgroundColor highContrastBackgroundColor:self.pallete.searchBarMergedBackgroundColor textColor:self.pallete.searchBarTextColor placeholderColor:self.pallete.searchBarPlaceholderColor clearIcon:self.images.searchClearIcon barBackgroundColor:self.pallete.barBackgroundColor barSeparatorColor:self.pallete.barSeparatorColor plainBackgroundColor:self.pallete.backgroundColor accentColor:self.pallete.accentColor accentContrastColor:self.pallete.accentContrastColor menuBackgroundColor:self.pallete.menuBackgroundColor segmentedControlBackgroundImage:self.images.segmentedControlBackgroundImage segmentedControlSelectedImage:self.images.segmentedControlSelectedImage segmentedControlHighlightedImage:self.images.segmentedControlHighlightedImage segmentedControlDividerImage:self.images.segmentedControlDividerImage];
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
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%d", name, retinaResource ? 2 : 1];
    UIImage *cachedImage = nil;
    @synchronized(cache)
    {
        cachedImage = cache[cacheKey];
    }
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
    {
        @synchronized(cache)
        {
            if (cache.count >= 160)
                [cache removeAllObjects];
            cache[cacheKey] = image;
        }
    }
    return image;
}

+ (UIImage *)brandedIOS6ResourceImage:(NSString *)name
{
    CGFloat scale = [UIScreen mainScreen].scale;
    bool retinaResource = scale > 1.5f;
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    NSString *cacheKey = [NSString stringWithFormat:@"%@:%d", name, retinaResource ? 2 : 1];
    UIImage *cachedImage = nil;
    @synchronized(cache)
    {
        cachedImage = cache[cacheKey];
    }
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
    {
        @synchronized(cache)
        {
            if (cache.count >= 96)
                [cache removeAllObjects];
            cache[cacheKey] = image;
        }
    }
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

static UIImage *TGClassicIOS6NavigationButtonImage(bool backButton, bool highlighted, bool landscape)
{
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

    CGFloat leftCap = backButton ? MIN(15.0f, image.size.width - 1.0f) : floor(image.size.width / 2.0f);
    return [image stretchableImageWithLeftCapWidth:(int)leftCap topCapHeight:0];
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

    currentPresentation = [[TGPresentation alloc] initWithPallete:[self palleteWithState:currentState]];

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
        if (next.integerValue > 0)
            [self switchToPallete:[self nightPalleteWithIndex:next.intValue] temporary:true];
        else
            [self switchToPallete:[self currentSavedPallete] temporary:true];
    }];
}

+ (void)switchToPallete:(TGPresentationPallete *)pallete
{
    [self switchToPallete:pallete temporary:false];
}

+ (void)switchToPallete:(TGPresentationPallete *)pallete temporary:(bool)temporary
{
    [TGCheckButtonView resetCache];
    [[TGMediaStoreContext instance] clearMemoryCache];
    
    currentPresentation = [[TGPresentation alloc] initWithPallete:pallete];
    presentationPipe.sink(currentPresentation);

    [self refreshUIAppearance];
    
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
}

+ (void)refreshUIAppearance
{
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
        bool classicDarkIOS6Style = classicIOS6Style && TGPresentation.current.pallete.isDark;

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
        [item setBackButtonTitlePositionAdjustment:UIOffsetMake(classicIOS6Style ? 1.0f : 5.0f, classicIOS6Style ? 0.0f : -1.0f) forBarMetrics:UIBarMetricsDefault];
        [item setBackButtonTitlePositionAdjustment:UIOffsetMake(classicIOS6Style ? 1.0f : 5.0f, classicIOS6Style ? -1.0f : -3.0f) forBarMetrics:UIBarMetricsLandscapePhone];
        [item setTitlePositionAdjustment:UIOffsetMake(0, classicIOS6Style ? 0.0f : 1.0f) forBarMetrics:UIBarMetricsDefault];

        UIColor *buttonTitleColor = classicIOS6Style ? [UIColor whiteColor] : TGPresentation.current.pallete.accentColor;
        UIColor *buttonShadowColor = classicIOS6Style ? (classicDarkIOS6Style ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f)) : [UIColor clearColor];
        UIFont *buttonFont = classicIOS6Style ? TGBoldSystemFontOfSize(12.0f) : TGSystemFontOfSize(16.0f);
        [item setTitleTextAttributes:@{UITextAttributeTextColor:buttonTitleColor, UITextAttributeTextShadowColor:buttonShadowColor, UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0.0f, classicIOS6Style ? -1.0f : 0.0f)], UITextAttributeFont:buttonFont} forState:UIControlStateNormal];
        [item setTitleTextAttributes:@{UITextAttributeTextColor:[buttonTitleColor colorWithAlphaComponent:0.75f], UITextAttributeTextShadowColor:buttonShadowColor, UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0.0f, classicIOS6Style ? -1.0f : 0.0f)], UITextAttributeFont:buttonFont} forState:UIControlStateHighlighted];

        UIColor *effectiveNavigationTitleColor = classicIOS6Style ? [UIColor whiteColor] : navigationTitleColor;
        UIColor *navigationTitleShadowColor = classicIOS6Style ? (classicDarkIOS6Style ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f)) : [UIColor clearColor];
        [[TGNavigationBar appearance] setTitleTextAttributes:@{UITextAttributeTextColor:effectiveNavigationTitleColor, UITextAttributeTextShadowColor:navigationTitleShadowColor, UITextAttributeTextShadowOffset:[NSValue valueWithUIOffset:UIOffsetMake(0.0f, classicIOS6Style ? -1.0f : 0.0f)], UITextAttributeFont:TGBoldSystemFontOfSize([TGPresentation brandedIOS6Style] ? 20.0f : 17.0f)}];
        [[TGNavigationBar appearance] setTitleVerticalPositionAdjustment:(TGIsRetina() ? 0.5f : 0.0f) forBarMetrics:UIBarMetricsDefault];
        [[TGNavigationBar appearance] setTitleVerticalPositionAdjustment:-1.0f forBarMetrics:UIBarMetricsLandscapePhone];
    }

    if (iosMajorVersion() >= 7)
    {
        [[UITextField appearance] setTintColor:TGPresentation.current.pallete.maybeAccentColor];
        [[UITextView appearance] setTintColor:TGPresentation.current.pallete.maybeAccentColor];
    }
}

+ (TGPresentation *)current
{
    return currentPresentation;
}

+ (TGInterfaceStyle)interfaceStyle
{
    if (![self classicIOS6StyleAvailable])
        return TGInterfaceStyleModern;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:TGInterfaceStyleDefaultsKey] == nil)
        return [defaults boolForKey:TGClassicIOS6StyleDefaultsKey] ? TGInterfaceStyleClassic : TGInterfaceStyleModern;

    NSInteger value = [defaults integerForKey:TGInterfaceStyleDefaultsKey];
    if (value < TGInterfaceStyleModern || value > TGInterfaceStyleFekla)
        return TGInterfaceStyleModern;
    return (TGInterfaceStyle)value;
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

    if (currentPresentation != nil)
        [self switchToPallete:currentPresentation.pallete temporary:true];
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
    return [self palleteWithState:currentState];
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
