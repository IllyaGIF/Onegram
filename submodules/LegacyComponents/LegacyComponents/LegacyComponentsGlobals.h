#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LegacyComponentsIos6Compat.h"

#import "LegacyComponentsAccessChecker.h"
#import "LegacyHTTPRequestOperation.h"

@class SSignal;
@class SThreadPool;
@protocol SDisposable;
@class TGLocalization;
@class UIViewController;
@class TGWallpaperInfo;
@class TGMemoryImageCache;
@class TGImageMediaAttachment;
@class TGNavigationBarPallete;
@class TGMenuSheetPallete;
@class TGMediaAssetsPallete;
@class TGImageBorderPallete;
@class TGCheckButtonPallete;

typedef enum {
    TGNavigationBarBackgroundVariantDefault = 0,
    TGNavigationBarBackgroundVariantGloss = 1,
    TGNavigationBarBackgroundVariantContacts = 2
} TGNavigationBarBackgroundVariant;

typedef enum {
    TGAudioSessionTypePlayVoice,
    TGAudioSessionTypePlayMusic,
    TGAudioSessionTypePlayVideo,
    TGAudioSessionTypePlayEmbedVideo,
    TGAudioSessionTypePlayAndRecord,
    TGAudioSessionTypePlayAndRecordHeadphones,
    TGAudioSessionTypeCall
} TGAudioSessionType;

@protocol LegacyComponentsGlobalsProvider <NSObject>

- (TGLocalization *)effectiveLocalization;
- (void)log:(NSString *)string;
- (NSArray *)applicationWindows;
- (UIWindow *)applicationStatusBarWindow;
- (UIWindow *)applicationKeyboardWindow;
- (UIApplication *)applicationInstance;

- (UIInterfaceOrientation)applicationStatusBarOrientation;
- (CGRect)statusBarFrame;
- (bool)isStatusBarHidden;
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation;
- (UIStatusBarStyle)statusBarStyle;
- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated;
- (void)forceStatusBarAppearanceUpdate;

- (bool)canOpenURL:(NSURL *)url;
- (void)openURL:(NSURL *)url;
- (void)openURLNative:(NSURL *)url;

- (void)disableUserInteractionFor:(NSTimeInterval)timeInterval;
- (void)setIdleTimerDisabled:(bool)value;

- (void)pauseMusicPlayback;
- (void)prepareAudioForVideoCapture:(void (^)(void))completion;
- (id<SDisposable>)suppressNotificationSoundsForCapture;

- (NSString *)dataStoragePath;
- (NSString *)dataCachePath;

- (id<LegacyComponentsAccessChecker>)accessChecker;

- (SSignal *)stickerPacksSignal;
- (SSignal *)maskStickerPacksSignal;
- (SSignal *)recentStickerMasksSignal;

- (id<SDisposable>)requestAudioSession:(TGAudioSessionType)type interrupted:(void (^)())interrupted;

- (TGWallpaperInfo *)currentWallpaperInfo;
- (UIImage *)currentWallpaperImage;

- (SThreadPool *)sharedMediaImageProcessingThreadPool;
- (TGMemoryImageCache *)sharedMediaMemoryImageCache;
- (SSignal *)squarePhotoThumbnail:(TGImageMediaAttachment *)imageAttachment ofSize:(CGSize)size threadPool:(SThreadPool *)threadPool memoryCache:(TGMemoryImageCache *)memoryCache pixelProcessingBlock:(void (^)(void *, int, int, int))pixelProcessingBlock downloadLargeImage:(bool)downloadLargeImage placeholder:(SSignal *)placeholder;

- (NSString *)localDocumentDirectoryForLocalDocumentId:(int64_t)localDocumentId version:(int32_t)version;
- (NSString *)localDocumentDirectoryForDocumentId:(int64_t)documentId version:(int32_t)version;

- (SSignal *)jsonForHttpLocation:(NSString *)httpLocation;
- (SSignal *)dataForHttpLocation:(NSString *)httpLocation;

- (NSOperation<LegacyHTTPRequestOperation> *)makeHTTPRequestOperationWithRequest:(NSURLRequest *)request;

- (void)pausePictureInPicturePlayback;
- (void)resumePictureInPicturePlayback;
- (void)maybeReleaseVolumeOverlay;

- (TGNavigationBarPallete *)navigationBarPallete;
- (TGMenuSheetPallete *)menuSheetPallete;
- (TGMediaAssetsPallete *)mediaAssetsPallete;
- (TGCheckButtonPallete *)checkButtonPallete;

@optional
- (bool)useNativeActionSheets;
- (TGImageBorderPallete *)imageBorderPallete;
- (UIImage *)brandedIOS6NavigationBarBackgroundImageForSize:(CGSize)size overflow:(CGFloat)overflow variant:(TGNavigationBarBackgroundVariant)variant;
- (UIImage *)brandedIOS6NavigationBarBackButtonImageForWidth:(CGFloat)width highlighted:(bool)highlighted;
- (UIColor *)brandedIOS6NavigationBarTintColor;
- (bool)brandedIOS6NavigationBarHidesBottomStripe;
- (UIFont *)brandedIOS6NavigationBarTitleFont;
- (UIColor *)brandedIOS6NavigationBarTitleShadowColor;
- (UIFont *)brandedIOS6NavigationBarButtonFont;
- (UIColor *)brandedIOS6NavigationBarButtonShadowColor;
- (UIColor *)brandedIOS6NavigationBarTitleColor;
- (UIColor *)brandedIOS6NavigationBarButtonTitleColor;
- (UIImage *)brandedIOS6SearchBarBackgroundImageForSize:(CGSize)size;
- (UIImage *)brandedIOS6SearchBarFieldImageForSize:(CGSize)size;
- (UIImage *)brandedIOS6SearchBarIconImage;
- (UIOffset)brandedIOS6SearchBarIconOffset;
- (UIOffset)brandedIOS6SearchBarPlaceholderOffset;

@end

@interface LegacyComponentsGlobals : NSObject

+ (void)setProvider:(id<LegacyComponentsGlobalsProvider>)provider;
+ (id<LegacyComponentsGlobalsProvider>)provider;

@end

#ifdef __cplusplus
extern "C" {
#endif
UIImage *TGComponentsImageNamed(NSString *name);
NSString *TGComponentsPathForResource(NSString *name, NSString *type);
#ifdef __cplusplus
}
#endif

FOUNDATION_EXPORT NSInteger TGCurrentInterfaceStyle(void);
