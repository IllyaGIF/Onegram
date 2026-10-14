#import "TGLegacyComponentsGlobalsProvider.h"

#import "TGAccessChecker.h"

#import "TGAppDelegate.h"
#import "TGApplication.h"
#import "TGTelegraph.h"
#import "TGAudioSessionManager.h"
#import "TGAudioPlayer.h"
#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"

#import "TGStickersSignals.h"
#import "TGMaskStickersSignals.h"
#import "TGRecentMaskStickersSignal.h"

#import "TGWallpaperManager.h"

#import "TGSharedPhotoSignals.h"
#import "TGSharedMediaUtils.h"

#import "TGRemoteHttpLocationSignal.h"

#import "TGEmbedPIPController.h"

#import "TGPresentation.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"
#import "../OnegramUI/Core/OGTheme.h"
#import "../OnegramUI/Core/OGNavigationAppearance.h"

#import "../submodules/MtProtoKit/MTProtoKit/AFHTTPRequestOperation.h"

@interface AFHTTPRequestOperation (TG) <LegacyHTTPRequestOperation>

@end

@implementation AFHTTPRequestOperation (TG)

@dynamic outputStream;

@end

static __strong NSTimer *userInteractionEnableTimer = nil;
static bool userInteractionIgnoredByProvider = false;

@implementation TGLegacyComponentsGlobalsProvider

- (TGLocalization *)effectiveLocalization {
    return effectiveLocalization();
}

- (void)log:(NSString *)string {
}

- (UIViewController *)rootController {
    return TGAppDelegateInstance.rootController;
}

- (NSArray *)applicationWindows {
    return [[UIApplication sharedApplication] windows];
}

- (UIWindow *)applicationStatusBarWindow {
    static SEL selector = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *str1 = @"rs`str";
        NSString *str2 = @"A`qVhmcnv";
        
        selector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%@%@", TGEncodeText(str1, 1), TGEncodeText(str2, 1)]);
    });
    
    if ([[UIApplication sharedApplication] respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIWindow *window = [[UIApplication sharedApplication] performSelector:selector];
#pragma clang diagnostic pop
        return window;
    }
    return nil;
}

- (UIWindow *)applicationKeyboardWindow {
    static Class keyboardWindowClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 9) {
            keyboardWindowClass = NSClassFromString(TGEncodeText(@"VJSfnpufLfzcpbseXjoepx", -1));
        } else {
            keyboardWindowClass = NSClassFromString(TGEncodeText(@"VJUfyuFggfdutXjoepx", -1));
        }
    });
    
    for (UIWindow *window in [[UIApplication sharedApplication] windows])
    {
        if ([[window class] isEqual:keyboardWindowClass])
            return window;
    }
    
    return nil;
}

- (UIApplication *)applicationInstance {
    return [UIApplication sharedApplication];
}

- (UIInterfaceOrientation)applicationStatusBarOrientation {
    return [[UIApplication sharedApplication] statusBarOrientation];
}

- (CGRect)statusBarFrame {
    return [[UIApplication sharedApplication] statusBarFrame];
}

- (bool)isStatusBarHidden {
    return [[UIApplication sharedApplication] isStatusBarHidden];
}

- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    OGPlatformSetStatusBarHidden([UIApplication sharedApplication], hidden, animation);
}

- (UIStatusBarStyle)statusBarStyle {
    return [[UIApplication sharedApplication] statusBarStyle];
}

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated {
    [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle animated:animated];
}

- (void)forceStatusBarAppearanceUpdate {
    static void (*methodImpl)(id, SEL) = NULL;
    static dispatch_once_t onceToken;
    static SEL methodSelector = NULL;
    dispatch_once(&onceToken, ^
    {
        methodImpl = (void (*)(id, SEL))freedomImpl([UIApplication sharedApplication], 0xa7a8dd8a, NULL);
    });
    
    if (methodImpl != NULL)
        methodImpl([UIApplication sharedApplication], methodSelector);
}

- (void)disableUserInteractionFor:(NSTimeInterval)timeInterval
{
    if (userInteractionEnableTimer != nil)
    {
        [userInteractionEnableTimer invalidate];
        userInteractionEnableTimer = nil;
    }

    if (userInteractionIgnoredByProvider)
    {
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        userInteractionIgnoredByProvider = false;
    }
    
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    userInteractionIgnoredByProvider = true;
    
    userInteractionEnableTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval] interval:0 target:self selector:@selector(userInteractionEnableTimerEvent) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:userInteractionEnableTimer forMode:NSRunLoopCommonModes];
}

- (void)setIdleTimerDisabled:(bool)value {
    [[UIApplication sharedApplication] setIdleTimerDisabled:value];
}

- (void)userInteractionEnableTimerEvent
{
    if (userInteractionIgnoredByProvider)
    {
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        userInteractionIgnoredByProvider = false;
    }
    
    userInteractionEnableTimer = nil;
}

- (void)pauseMusicPlayback {
    [TGTelegraphInstance.musicPlayer controlPause];
}

- (NSString *)dataStoragePath {
    return [TGAppDelegate documentsPath];
}

- (NSString *)dataCachePath {
    return [TGAppDelegate cachePath];
}

- (id<LegacyComponentsAccessChecker>)accessChecker {
    static TGAccessChecker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TGAccessChecker alloc] init];
    });
    return instance;
}

- (id<SDisposable>)requestAudioSession:(TGAudioSessionType)type interrupted:(void (^)())interrupted {
    return [[TGAudioSessionManager instance] requestSessionWithType:type interrupted:interrupted];
}

- (void)prepareAudioForVideoCapture:(void (^)(void))completion {
    void (^releaseSession)(void) = ^{
        [[TGAudioSessionManager instance] cancelCurrentSession];
        [[TGAudioPlayer _playerQueue] dispatchOnQueue:^{
            if (completion != nil)
                completion();
        }];
    };
    if (TGTelegraphInstance.musicPlayer != nil)
        [TGTelegraphInstance.musicPlayer controlPause:releaseSession];
    else
        releaseSession();
}

- (id<SDisposable>)suppressNotificationSoundsForCapture {
    return [[TGAudioSessionManager instance] suppressNotificationSounds];
}

- (SSignal *)stickerPacksSignal {
    return [TGStickersSignals stickerPacks];
}

- (SSignal *)maskStickerPacksSignal {
    return [TGMaskStickersSignals stickerPacks];
}

- (SSignal *)recentStickerMasksSignal {
    return [TGRecentMaskStickersSignal recentStickers];
}

- (TGWallpaperInfo *)currentWallpaperInfo {
    return [[TGWallpaperManager instance] currentWallpaperInfo];
}

- (UIImage *)currentWallpaperImage {
    return [[TGWallpaperManager instance] currentWallpaperImage];
}

- (bool)canOpenURL:(NSURL *)url {
    return [[UIApplication sharedApplication] canOpenURL:url];
}

- (void)openURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}

- (void)openURLNative:(NSURL *)url {
    [(TGApplication *)[UIApplication sharedApplication] openURL:url forceNative:true];
}

- (SThreadPool *)sharedMediaImageProcessingThreadPool {
    return [TGSharedMediaUtils sharedMediaImageProcessingThreadPool];
}

- (TGMemoryImageCache *)sharedMediaMemoryImageCache {
    return [TGSharedMediaUtils sharedMediaMemoryImageCache];
}

- (SSignal *)squarePhotoThumbnail:(TGImageMediaAttachment *)imageAttachment ofSize:(CGSize)size threadPool:(SThreadPool *)threadPool memoryCache:(TGMemoryImageCache *)memoryCache pixelProcessingBlock:(void (^)(void *, int, int, int))pixelProcessingBlock downloadLargeImage:(bool)downloadLargeImage placeholder:(SSignal *)placeholder {
    return [TGSharedPhotoSignals squarePhotoThumbnail:imageAttachment ofSize:size threadPool:threadPool memoryCache:memoryCache pixelProcessingBlock:pixelProcessingBlock downloadLargeImage:downloadLargeImage placeholder:placeholder];
}

- (NSString *)localDocumentDirectoryForLocalDocumentId:(int64_t)localDocumentId version:(int32_t)version
{
    NSString *documentsDirectory = [TGAppDelegate documentsPath];
    NSString *filesDirectory = [documentsDirectory stringByAppendingPathComponent:@"files"];
    NSString *versionString = @"";
    if (version > 0) {
        versionString = [NSString stringWithFormat:@"-%d", version];
    }
    return [[filesDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"local%llx", localDocumentId]] stringByAppendingString:versionString];
}

- (NSString *)localDocumentDirectoryForDocumentId:(int64_t)documentId version:(int32_t)version
{
    NSString *documentsDirectory = [TGAppDelegate documentsPath];
    NSString *filesDirectory = [documentsDirectory stringByAppendingPathComponent:@"files"];
    NSString *versionString = @"";
    if (version > 0) {
        versionString = [NSString stringWithFormat:@"-%d", version];
    }
    return [[filesDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%llx", documentId]]  stringByAppendingString:versionString];
}

- (SSignal *)jsonForHttpLocation:(NSString *)httpLocation {
    return [TGRemoteHttpLocationSignal jsonForHttpLocation:httpLocation];
}

- (SSignal *)dataForHttpLocation:(NSString *)httpLocation {
    return [TGRemoteHttpLocationSignal dataForHttpLocation:httpLocation];
}

- (NSOperation<LegacyHTTPRequestOperation> *)makeHTTPRequestOperationWithRequest:(NSURLRequest *)request {
    return [[AFHTTPRequestOperation alloc] initWithRequest:request];
}

- (void)pausePictureInPicturePlayback {
    [TGEmbedPIPController pausePictureInPicturePlayback];
}

- (void)resumePictureInPicturePlayback {
    [TGEmbedPIPController resumePictureInPicturePlayback];
}

- (void)maybeReleaseVolumeOverlay {
    [TGEmbedPIPController maybeReleaseVolumeOverlay];
}

- (TGNavigationBarPallete *)navigationBarPallete
{
    return TGPresentation.current.navigationBarPallete;
}

- (UIImage *)brandedIOS6NavigationBarBackgroundImageForSize:(CGSize)size overflow:(CGFloat)overflow variant:(TGNavigationBarBackgroundVariant)variant
{
    if (variant == TGNavigationBarBackgroundVariantContacts)
        return [TGPresentation brandedIOS6ContactNavigationBarImageForSize:size overflow:overflow];
    return [TGPresentation brandedIOS6NavigationBarBackgroundImageForSize:size overflow:overflow gloss:variant == TGNavigationBarBackgroundVariantGloss];
}

- (UIImage *)brandedIOS6NavigationBarBackButtonImageForWidth:(CGFloat)width highlighted:(bool)highlighted
{
    return [TGPresentation brandedIOS6NavigationButtonImage:true highlighted:highlighted landscape:false width:width];
}

- (UIFont *)brandedIOS6NavigationBarTitleFont
{
    return [TGPresentation brandedIOS6NavigationTitleFont];
}

- (UIColor *)brandedIOS6NavigationBarTitleShadowColor
{
    return [TGPresentation brandedIOS6NavigationTitleShadowColor];
}

- (UIFont *)brandedIOS6NavigationBarButtonFont
{
    return [TGPresentation brandedIOS6NavigationButtonFont];
}

- (UIColor *)brandedIOS6NavigationBarButtonShadowColor
{
    return [TGPresentation brandedIOS6NavigationButtonShadowColor];
}

- (UIColor *)brandedIOS6NavigationBarTintColor
{
    return [OGTheme brandedTheme].navigationAppearance.tintColor;
}

- (bool)brandedIOS6NavigationBarHidesBottomStripe
{
    return [OGTheme brandedTheme].navigationAppearance.hidesBottomStripe;
}

- (UIColor *)brandedIOS6NavigationBarTitleColor
{
    return [OGTheme brandedTheme].navigationAppearance.titleColor;
}

- (UIColor *)brandedIOS6NavigationBarButtonTitleColor
{
    return [OGTheme brandedTheme].navigationAppearance.buttonTitleColor;
}

- (UIImage *)brandedIOS6SearchBarBackgroundImageForSize:(CGSize)size
{
    return [TGPresentation brandedIOS6SearchBarBackgroundImageForSize:size];
}

- (UIImage *)brandedIOS6SearchBarFieldImageForSize:(CGSize)size
{
    return [TGPresentation brandedIOS6SearchBarFieldImageForSize:size];
}

- (UIImage *)brandedIOS6SearchBarIconImage
{
    return [TGPresentation brandedIOS6SearchBarIconImage];
}

- (UIOffset)brandedIOS6SearchBarIconOffset
{
    return [TGPresentation brandedIOS6SearchBarIconOffset];
}

- (UIOffset)brandedIOS6SearchBarPlaceholderOffset
{
    return [TGPresentation brandedIOS6SearchBarPlaceholderOffset];
}

- (TGMenuSheetPallete *)menuSheetPallete
{
    return TGPresentation.current.menuSheetPallete;
}

- (bool)useNativeActionSheets
{
    return iosMajorVersion() < 7 || [TGPresentation classicIOS6Style];
}

- (TGMediaAssetsPallete *)mediaAssetsPallete
{
    return TGPresentation.current.mediaAssetsPallete;
}

- (TGImageBorderPallete *)imageBorderPallete
{
    return TGPresentation.current.imageBorderPallete;
}

- (TGCheckButtonPallete *)checkButtonPallete
{
    return TGPresentation.current.checkButtonPallete;
}

@end
