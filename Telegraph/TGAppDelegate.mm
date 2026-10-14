#import "../OnegramRuntime/OGStartupDiagnostics.h"
#import "../OnegramPlatform/OGPlatformMedia.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponentsGlobals.h"
#import "TGAppDelegate.h"
#import "TGAlertView.h"
#import "TGRichMessageMediaAttachment.h"
#import "TGPollMediaAttachment.h"

#import <unistd.h>
#import <sys/utsname.h>
#import <QuartzCore/QuartzCore.h>
#include <stdlib.h>
#include <signal.h>
#include <fcntl.h>
#include <limits.h>
#include <string.h>
#include <stdio.h>
#include <sys/ucontext.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <dlfcn.h>
#include <stdint.h>
#include <vector>
#include <sys/xattr.h>


#import "../config.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGLegacyComponentsGlobalsProvider.h"
#import "TGNavigationBarMusicPlayerProvider.h"
#import "TGRemoteControlsManager.h"

#import "TGCommon.h"
#import "IOS6NotificationProbe.h"
#import "TGApplyUpdatesActor.h"
#import "TGPresentation.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramPlatform/OGPlatformVersion.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"
#import "../OnegramPlatform/OGPlatformText.h"
#import "../OnegramPlatform/OGMemoryCache.h"
#import "../OnegramRuntime/OGRuntime.h"
#include <libkern/OSAtomic.h>
#import "../OnegramRuntime/OGDatabaseRuntime.h"
#import "../legacy/TL/TLMetaClassStore.h"

@implementation NSArray (TGIOS6FirstObject)

- (id)firstObject
{
    return self.count == 0 ? nil : [self objectAtIndex:0];
}

@end

static NSString *TGIOS6PerfDeviceModel()
{
    struct utsname systemInfo;
    uname(&systemInfo);
    return [[NSString alloc] initWithUTF8String:systemInfo.machine] ?: @"?";
}

static NSString *TGIOS6PerfDeviceMarketingName(NSString *machine)
{
    static NSDictionary *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        names = @{
            @"iPhone3,1": @"iPhone 4", @"iPhone3,2": @"iPhone 4", @"iPhone3,3": @"iPhone 4",
            @"iPhone4,1": @"iPhone 4S",
            @"iPhone5,1": @"iPhone 5", @"iPhone5,2": @"iPhone 5",
            @"iPhone5,3": @"iPhone 5c", @"iPhone5,4": @"iPhone 5c",
            @"iPhone6,1": @"iPhone 5s", @"iPhone6,2": @"iPhone 5s",
            @"iPad2,1": @"iPad 2", @"iPad2,2": @"iPad 2", @"iPad2,3": @"iPad 2", @"iPad2,4": @"iPad 2",
            @"iPad2,5": @"iPad mini", @"iPad2,6": @"iPad mini", @"iPad2,7": @"iPad mini",
            @"iPad3,1": @"iPad 3", @"iPad3,2": @"iPad 3", @"iPad3,3": @"iPad 3",
            @"iPad3,4": @"iPad 4", @"iPad3,5": @"iPad 4", @"iPad3,6": @"iPad 4",
            @"iPod5,1": @"iPod touch 5"
        };
    });
    NSString *name = [names objectForKey:machine];
    return name ?: machine ?: @"?";
}

static NSString *TGIOS6PerfDeviceDescription()
{
    NSString *machine = TGIOS6PerfDeviceModel();
    NSString *name = TGIOS6PerfDeviceMarketingName(machine);
    if ([name isEqualToString:machine])
        return machine;
    return [NSString stringWithFormat:@"%@ (%@)", name, machine];
}

static NSString *TGIOS6BotContext()
{
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
    NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?";
    UIDevice *device = [UIDevice currentDevice];
    NSString *idiom = device.userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone";
    return [NSString stringWithFormat:@"version=%@ build=%@ os=%@ %@ idiom=%@ device=%@", version, build, device.systemName, device.systemVersion, idiom, TGIOS6PerfDeviceDescription()];
}

static const bool TGIOS6NotificationSettingsGateEnabled = false;

NSString *const TGIOS6BackgroundNotificationsEnabledKey = @"TGIOS6BackgroundNotificationsEnabled";
NSString *const TGIOS6APNsNotificationsEnabledKey = @"TGIOS6APNsNotificationsEnabled";

bool TGIOS6BackgroundNotificationsEnabled(void)
{
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:TGIOS6BackgroundNotificationsEnabledKey];
    return storedValue == nil ? true : [storedValue boolValue];
}

bool TGIOS6APNsNotificationsEnabled(void)
{
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:TGIOS6APNsNotificationsEnabledKey];
    return storedValue == nil ? false : [storedValue boolValue];
}

#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTProtoKit.h"

#import "TGUserDefaults.h"
#import "TGDatabase.h"
#import "TGMessage+Telegraph.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGSchema.h"
#import "TLRPCping.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageManager.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGCache.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGFont.h"

#import "TGTelegraphDialogListCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/SGraphListNode.h"
#import "TGImageDownloadActor.h"

#import "TGTelegraphConversationMessageAssetsSource.h"
#import "TGReusableLabel.h"

#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>

#import "TGLoginPhoneController.h"
#import "TGLoginPasswordController.h"
#import "TGLoginCodeController.h"
#import "TGLoginProfileController.h"

#import "TGApplication.h"

#import "TGPasscodeWindow.h"

#import "TGContentViewController.h"

#import "TGModernConversationController.h"
#import "TGGenericModernConversationCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryController.h"

#import "TGSecretModernConversationCompanion.h"

#import "TGForwardTargetController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "TGCustomAlertView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryModel.h"

#import "TGConversationAddMessagesActor.h"

#import <pthread.h>
#import <mach/mach.h>

#import <objc/runtime.h>

static bool TGClassicIOS6NativeNavigationImageName(NSString *name)
{
    NSString *stem = [[name lastPathComponent] stringByDeletingPathExtension];
    return [stem hasPrefix:@"BackButton"] || [stem hasPrefix:@"HeaderButton"] || [stem hasPrefix:@"MenuButton"] || [stem hasPrefix:@"ActionMenuButton"];
}

static bool TGClassicIOS6AllowImageNamedOverride(NSString *stem)
{
    if (![TGPresentation classicIOS6UsesPaletteAdaptedAssets])
        return true;

    return [stem hasPrefix:@"Banner"] || [stem hasPrefix:@"ConversationScrollDown"] || [stem hasPrefix:@"ConversationNewMessagesDivider"] || [stem hasPrefix:@"ConversationUnreadBadge"] || [stem hasPrefix:@"BlackCorners"] || [stem hasPrefix:@"BrowserFooter"] || [stem hasPrefix:@"CameraStripe"];
}

static UIColor *TGClassicIOS6TintColorForImageStem(NSString *stem)
{
    TGPresentation *presentation = [TGPresentation current];
    TGPresentationPallete *pallete = presentation != nil ? presentation.pallete : [TGPresentation currentSavedPallete];
    if (pallete == nil)
        return nil;

    if ([stem hasPrefix:@"Banner"] || [stem hasPrefix:@"BrowserFooter"] || [stem hasPrefix:@"CameraStripe"] || [stem hasPrefix:@"ConversationInputPanel"] || [stem hasPrefix:@"ConversationActionBar"])
        return pallete.barBackgroundColor;
    if ([stem hasPrefix:@"ConversationNewMessagesDivider"] || [stem hasPrefix:@"ConversationUnreadBadge"])
        return pallete.chatUnreadBackgroundColor;
    if ([stem hasPrefix:@"ConversationScrollDown"] || [stem hasPrefix:@"BlackCorners"])
        return pallete.selectionColor;
    return pallete.barBackgroundColor;
}

static UIImage *TGClassicIOS6OriginalImageNamed(NSString *name)
{
    if (!(TGCurrentInterfaceStyle() != 0) || name.length == 0 || TGClassicIOS6NativeNavigationImageName(name))
        return nil;

    static OGMemoryCache *imageCache = nil;
    static OGMemoryCache *themedCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        imageCache = [[OGMemoryCache alloc] initWithCountLimit:512 costLimit:8 * 1024 * 1024];
        themedCache = [[OGMemoryCache alloc] initWithCountLimit:256 costLimit:4 * 1024 * 1024];
    });

    NSString *component = [name lastPathComponent];
    NSString *extension = component.pathExtension.length == 0 ? @"png" : component.pathExtension;
    NSString *stem = [component stringByDeletingPathExtension];
    if (!TGClassicIOS6AllowImageNamedOverride(stem))
        return nil;
    CGFloat scale = [UIScreen mainScreen].scale;
    NSArray *resourceKey = @[name, @(scale)];
    id cached = [imageCache objectForKey:resourceKey];
    if (cached == [NSNull null])
        return nil;
    UIImage *image = cached;
    if (image == nil)
    {
        bool hasExplicitScale = [stem rangeOfString:@"@2x"].location != NSNotFound || [stem rangeOfString:@"@3x"].location != NSNotFound;
        NSString *resourceName = hasExplicitScale ? stem : (scale > 1.5f ? [stem stringByAppendingString:@"@2x"] : stem);
        NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:extension inDirectory:@"ClassicIOS6"];
        if (path.length == 0 && !hasExplicitScale)
        {
            resourceName = [stem stringByAppendingString:@"@2x"];
            path = [[NSBundle mainBundle] pathForResource:resourceName ofType:extension inDirectory:@"ClassicIOS6"];
        }
        image = path.length == 0 ? nil : [UIImage imageWithContentsOfFile:path];
        if (image != nil && [resourceName rangeOfString:@"@2x"].location != NSNotFound && image.CGImage != NULL)
            image = [UIImage imageWithCGImage:image.CGImage scale:2.0f orientation:UIImageOrientationUp];
        NSUInteger cost = image.CGImage == NULL ? 64 : CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage);
        [imageCache setObject:image ?: [NSNull null] forKey:resourceKey cost:cost];
    }
    if (image != nil && [TGPresentation classicIOS6UsesPaletteAdaptedAssets])
    {
        UIColor *tint = TGClassicIOS6TintColorForImageStem(stem);
        TGPresentation *presentation = [TGPresentation current];
        TGPresentationPallete *pallete = presentation != nil ? presentation.pallete : [TGPresentation currentSavedPallete];
        NSArray *themedKey = @[resourceKey, tint ?: [NSNull null], @(pallete.isDark)];
        UIImage *themed = [themedCache objectForKey:themedKey];
        if (themed == nil)
        {
            themed = [TGPresentation classicIOS6ThemedImage:image tintColor:tint alpha:0.8f];
            NSUInteger cost = themed.CGImage == NULL ? 64 : CGImageGetBytesPerRow(themed.CGImage) * CGImageGetHeight(themed.CGImage);
            [themedCache setObject:themed forKey:themedKey cost:cost];
        }
        image = themed;
    }
    return image;
}

@interface UIImage (OnegramClassicIOS6Resources)

@end
@implementation UIImage (OnegramClassicIOS6Resources)

+ (void)load
{
    @autoreleasepool
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            Method original = class_getClassMethod(self, @selector(imageNamed:));
            Method replacement = class_getClassMethod(self, @selector(onegramium_classicIOS6ImageNamed:));
            method_exchangeImplementations(original, replacement);
        });
    }
}

+ (UIImage *)onegramium_classicIOS6ImageNamed:(NSString *)name
{
    UIImage *classicImage = TGClassicIOS6OriginalImageNamed(name);
    return classicImage != nil ? classicImage : [self onegramium_classicIOS6ImageNamed:name];
}

@end

#import <AVFoundation/AVFoundation.h>

#include <inttypes.h>

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#import "TGPasscodeSettingsController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPasscodeEntryController.h"

#import "TGDropboxHelper.h"

#import "TGStickersSignals.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#import <LocalAuthentication/LocalAuthentication.h>
#endif

#import "TGStickerPackPreviewWindow.h"

#import "TGBotSignals.h"


#import "TGAccountSignals.h"
#import "TGServiceSignals.h"
#import "TGPushActionsRequestBuilder.h"

#import "TGGroupManagementSignals.h"
#import "TGChannelManagementSignals.h"

#import "TGSendMessageSignals.h"
#import "TGChatMessageListSignal.h"

#import "TGAudioSessionManager.h"

#import "TGApplicationMainWindow.h"

#import "TGRootController.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#import <CoreSpotlight/CoreSpotlight.h>
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#import <ContactsUI/ContactsUI.h>
#endif

#import "TGRecentPeersSignals.h"
#import "TGGlobalMessageSearchSignals.h"
#import "TGDialogListRecentPeers.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGKeyCommandController.h"
#import "TGEmbedPIPController.h"

#import "TGStickersMenu.h"
#import "TGProxyMenu.h"
#import "TGOnegramCoreController.h"
#import "../OnegramDante/OGDanteSocket.h"

#import "TGGroupInviteSheet.h"

#import "TGLoginResetAccountProtectedController.h"
#import "TGCancelAccountResetController.h"
#import "TGHashtagOverviewController.h"

#import "TGMediaSignals.h"

#import "UIImage+ImageEffects.h"
#import "TGUpdateConfigActor.h"

#import "TGWebAppController.h"
#import "TGPassportRequestController.h"

#import "../submodules/LegacyComponents/Pushkit/Pushkit.h"

#import "TGWebpageSignals.h"
#import "TGInstantPageController.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGCameraController.h"

#import "TGMessageUniqueIdContentProperty.h"

#import "TGCameraController+Shortcut.h"

#import "TGLegacyComponentsContext.h"

#import "TGGDPRNoticeController.h"
#import "TGUpdateAppController.h"

#import "TGPresentation.h"
#import "TGPassportSignals.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 && !defined(ONEGRAM_DISABLE_ICLOUD_ACCOUNT_SERVICES)
#import <CloudKit/CloudKit.h>
#endif
#import "TGICloudEmergencyDataSignals.h"

NSString *TGDeviceProximityStateChangedNotification = @"TGDeviceProximityStateChangedNotification";

CFAbsoluteTime applicationStartupTimestamp = 0;
CFAbsoluteTime mainLaunchTimestamp = 0;

TGAppDelegate *TGAppDelegateInstance = nil;
TGTelegraph *telegraph = nil;

#if defined(ONEGRAM_DIAGNOSTICS)
#include <mach/mach_time.h>
#include <sys/resource.h>
#include <limits.h>

static pthread_mutex_t TGDiagnosticLock = PTHREAD_MUTEX_INITIALIZER;
static uint64_t TGDiagnosticOrigin = 0;
static double TGDiagnosticTickSeconds = 0.0;
static volatile int32_t TGDiagnosticCollecting = 0;
static thread_t TGDiagnosticMainThreadPort = MACH_PORT_NULL;
static uintptr_t TGDiagnosticMainStackLow = 0;
static uintptr_t TGDiagnosticMainStackHigh = 0;
static CFRunLoopObserverRef TGDiagnosticObserver = NULL;
static bool TGDiagnosticUISettledReported = false;
static bool TGDiagnosticStagePending = false;
static bool TGDiagnosticDatabasePending = false;
static bool TGDiagnosticPingPending = false;
static double TGDiagnosticStageSent = 0.0;
static double TGDiagnosticDatabaseSent = 0.0;
static double TGDiagnosticPingSent = 0.0;
static double TGDiagnosticPingDelay = -1.0;

struct TGDiagnosticDatabaseSite {
    const char *file;
    int line;
    uint64_t count;
    double execution;
    double slowCPU;
    double maximumQueued;
};

struct TGDiagnosticStatistics {
    uint64_t databaseTasks;
    uint64_t databaseSlowTasks;
    uint64_t databaseUntrackedSlowTasks;
    double databaseExecution;
    double databaseSlowCPU;
    double maximumDatabaseQueued;
    uint64_t mainDatabaseWaits;
    double mainDatabaseWait;
    uint64_t mainReplies;
    uint64_t mainHitches;
    double mainHitchTime;
    double maximumMainDelay;
    uint64_t stageProbes;
    uint64_t databaseProbes;
    double maximumStageProbe;
    double maximumDatabaseProbe;
};

struct TGDiagnosticStartupState {
    bool syncSucceeded;
    bool networkNormal;
    bool uiNormal;
    bool visible;
    bool dialogsPresented;
    bool dialogsComplete;
    bool settled;
    bool uiWorkPending;
    bool verificationPending;
    bool ready;
    uint64_t generation;
    uint64_t verifiedGeneration;
    NSUInteger dialogCount;
    double readyTime;
};

static TGDiagnosticStatistics TGDiagnosticStats = {};
static TGDiagnosticDatabaseSite TGDiagnosticSites[32] = {};
static TGDiagnosticStartupState TGDiagnosticStartup = {};
static struct rusage TGDiagnosticInitialUsage;

NSTimeInterval OGStartupDiagnosticsTime(void)
{
    return (mach_absolute_time() - TGDiagnosticOrigin) * TGDiagnosticTickSeconds;
}

BOOL OGStartupDiagnosticsIsCollecting(void)
{
    return OSAtomicAdd32Barrier(0, &TGDiagnosticCollecting) != 0;
}

static bool TGDiagnosticReadyConditions(const TGDiagnosticStartupState *state)
{
    return state->syncSucceeded && state->networkNormal && state->uiNormal && state->visible && state->dialogsPresented && state->dialogsComplete && state->settled && !state->uiWorkPending;
}

void OGStartupDiagnosticsInitialize(uint64_t ticks, NSTimeInterval unixTime)
{
    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.denom == 0)
        return;
    TGDiagnosticOrigin = ticks;
    TGDiagnosticTickSeconds = (double)timebase.numer / (double)timebase.denom / 1000000000.0;
    getrusage(RUSAGE_SELF, &TGDiagnosticInitialUsage);
    OSAtomicCompareAndSwap32Barrier(0, 1, &TGDiagnosticCollecting);
    OGPlatformDiagnosticLog(@"STARTUP_ORIGIN pid=%d unix_ms=%.0f ticks=%llu", getpid(), unixTime * 1000.0, (unsigned long long)ticks);
}

void OGStartupDiagnosticsMark(const char *stage)
{
    if (OGStartupDiagnosticsIsCollecting())
        OGPlatformDiagnosticLog(@"STARTUP_PHASE name=%s elapsed_ms=%.0f", stage, OGStartupDiagnosticsTime() * 1000.0);
}

void OGStartupDiagnosticsSyncStarted(void)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    bool collecting = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready;
    if (collecting) {
        TGDiagnosticStartup.syncSucceeded = false;
        TGDiagnosticStartup.generation++;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (collecting)
        OGStartupDiagnosticsMark("sync_begin");
}

void OGStartupDiagnosticsSyncFinished(BOOL success, const char *source)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    bool collecting = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready;
    if (collecting) {
        TGDiagnosticStartup.syncSucceeded = success;
        TGDiagnosticStartup.generation++;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (collecting)
        OGPlatformDiagnosticLog(@"STARTUP_SYNC source=%s success=%d elapsed_ms=%.0f", source, success ? 1 : 0, OGStartupDiagnosticsTime() * 1000.0);
}

void OGStartupDiagnosticsNetworkState(int state)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    bool normal = state == 0;
    bool changed = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready && TGDiagnosticStartup.networkNormal != normal;
    if (changed) {
        TGDiagnosticStartup.networkNormal = normal;
        TGDiagnosticStartup.generation++;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (changed)
        OGPlatformDiagnosticLog(@"STARTUP_NETWORK state=%d elapsed_ms=%.0f", state, OGStartupDiagnosticsTime() * 1000.0);
}

void OGStartupDiagnosticsUIState(BOOL normal, BOOL visible)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    bool changed = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready && (TGDiagnosticStartup.uiNormal != (bool)normal || TGDiagnosticStartup.visible != (bool)visible);
    if (changed) {
        TGDiagnosticStartup.uiNormal = normal;
        TGDiagnosticStartup.visible = visible;
        TGDiagnosticStartup.settled = false;
        TGDiagnosticStartup.generation++;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (changed)
        OGPlatformDiagnosticLog(@"STARTUP_UI normal=%d visible=%d elapsed_ms=%.0f", normal ? 1 : 0, visible ? 1 : 0, OGStartupDiagnosticsTime() * 1000.0);
}

void OGStartupDiagnosticsDialogsPresented(NSUInteger count, BOOL complete)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    bool collecting = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready;
    bool first = collecting && !TGDiagnosticStartup.dialogsPresented;
    bool completed = collecting && complete && !TGDiagnosticStartup.dialogsComplete;
    if (collecting) {
        TGDiagnosticStartup.dialogsPresented = true;
        TGDiagnosticStartup.dialogsComplete = complete;
        TGDiagnosticStartup.dialogCount = count;
        TGDiagnosticStartup.settled = false;
        TGDiagnosticStartup.generation++;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (first || completed)
        OGPlatformDiagnosticLog(@"STARTUP_LIST complete=%d rows=%lu elapsed_ms=%.0f", complete ? 1 : 0, (unsigned long)count, OGStartupDiagnosticsTime() * 1000.0);
}

void OGStartupDiagnosticsUIWorkPending(BOOL pending)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    if (OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready && TGDiagnosticStartup.uiWorkPending != (bool)pending) {
        TGDiagnosticStartup.uiWorkPending = pending;
        TGDiagnosticStartup.settled = false;
        TGDiagnosticStartup.generation++;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
}

void OGStartupDiagnosticsRecordDatabaseTask(const char *file, int line, NSTimeInterval execution, NSTimeInterval slowCPU, NSTimeInterval queued)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    if (OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready) {
        TGDiagnosticStats.databaseTasks++;
        TGDiagnosticStats.databaseExecution += execution;
        TGDiagnosticStats.maximumDatabaseQueued = MAX(TGDiagnosticStats.maximumDatabaseQueued, queued);
        if (execution >= 0.05) {
            TGDiagnosticStats.databaseSlowTasks++;
            TGDiagnosticStats.databaseSlowCPU += slowCPU;
            bool tracked = false;
            for (NSUInteger i = 0; i < 32; i++) {
                TGDiagnosticDatabaseSite *site = &TGDiagnosticSites[i];
                if (site->file == NULL || (site->line == line && strcmp(site->file, file) == 0)) {
                    site->file = file;
                    site->line = line;
                    site->count++;
                    site->execution += execution;
                    site->slowCPU += slowCPU;
                    site->maximumQueued = MAX(site->maximumQueued, queued);
                    tracked = true;
                    break;
                }
            }
            if (!tracked)
                TGDiagnosticStats.databaseUntrackedSlowTasks++;
        }
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
}

void OGStartupDiagnosticsRecordMainDatabaseWait(NSTimeInterval duration)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    pthread_mutex_lock(&TGDiagnosticLock);
    if (OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready) {
        TGDiagnosticStats.mainDatabaseWaits++;
        TGDiagnosticStats.mainDatabaseWait += duration;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
}

static void TGDiagnosticRunLoopSettled(CFRunLoopObserverRef, CFRunLoopActivity, void *)
{
    if (!OGStartupDiagnosticsIsCollecting())
        return;
    bool report = false;
    NSUInteger rows = 0;
    pthread_mutex_lock(&TGDiagnosticLock);
    if (OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready && TGDiagnosticStartup.visible && TGDiagnosticStartup.dialogsPresented && !TGDiagnosticStartup.uiWorkPending) {
        TGDiagnosticStartup.settled = true;
        if (!TGDiagnosticUISettledReported) {
            TGDiagnosticUISettledReported = true;
            report = true;
            rows = TGDiagnosticStartup.dialogCount;
        }
        if (TGDiagnosticStartup.verificationPending && TGDiagnosticStartup.verifiedGeneration != 0 && TGDiagnosticStartup.verifiedGeneration != TGDiagnosticStartup.generation) {
            TGDiagnosticStartup.verificationPending = false;
            TGDiagnosticStartup.verifiedGeneration = 0;
        }
        if (TGDiagnosticStartup.verificationPending && TGDiagnosticStartup.verifiedGeneration == TGDiagnosticStartup.generation && TGDiagnosticReadyConditions(&TGDiagnosticStartup)) {
            TGDiagnosticStartup.ready = true;
            TGDiagnosticStartup.readyTime = OGStartupDiagnosticsTime();
        }
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (report)
        OGPlatformDiagnosticLog(@"STARTUP_UI_SETTLED elapsed_ms=%.0f rows=%lu", OGStartupDiagnosticsTime() * 1000.0, (unsigned long)rows);
}

static void TGDiagnosticVerifyReadiness(void)
{
    pthread_mutex_lock(&TGDiagnosticLock);
    bool verify = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready && !TGDiagnosticStartup.verificationPending && TGDiagnosticReadyConditions(&TGDiagnosticStartup);
    uint64_t generation = TGDiagnosticStartup.generation;
    if (verify) {
        TGDiagnosticStartup.verificationPending = true;
        TGDiagnosticStartup.verifiedGeneration = 0;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (!verify)
        return;
    [ActionStageInstance() dispatchOnStageQueue:^{
        [TGDatabaseInstance() dispatchOnDatabaseThread:^{
            [ActionStageInstance() dispatchOnStageQueue:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    pthread_mutex_lock(&TGDiagnosticLock);
                    if (OGStartupDiagnosticsIsCollecting() && TGDiagnosticStartup.generation == generation && TGDiagnosticReadyConditions(&TGDiagnosticStartup))
                        TGDiagnosticStartup.verifiedGeneration = generation;
                    else
                        TGDiagnosticStartup.verificationPending = false;
                    pthread_mutex_unlock(&TGDiagnosticLock);
                });
            }];
        } synchronous:false];
    }];
}

static double TGDiagnosticCPUTime(const struct timeval *value)
{
    return value->tv_sec + value->tv_usec / 1000000.0;
}

static void TGDiagnosticReport(BOOL final)
{
    double elapsed = OGStartupDiagnosticsTime();
    pthread_mutex_lock(&TGDiagnosticLock);
    TGDiagnosticStatistics stats = TGDiagnosticStats;
    TGDiagnosticStartupState state = TGDiagnosticStartup;
    TGDiagnosticDatabaseSite sites[32];
    memcpy(sites, TGDiagnosticSites, sizeof(sites));
    double stagePending = TGDiagnosticStagePending ? MAX(0.0, elapsed - TGDiagnosticStageSent) : 0.0;
    double databasePending = TGDiagnosticDatabasePending ? MAX(0.0, elapsed - TGDiagnosticDatabaseSent) : 0.0;
    double mainPending = TGDiagnosticPingPending ? MAX(0.0, elapsed - TGDiagnosticPingSent) : 0.0;
    if (final)
        OSAtomicCompareAndSwap32Barrier(1, 0, &TGDiagnosticCollecting);
    pthread_mutex_unlock(&TGDiagnosticLock);
    struct rusage usage;
    memset(&usage, 0, sizeof(usage));
    getrusage(RUSAGE_SELF, &usage);
    double cpu = MAX(0.0, TGDiagnosticCPUTime(&usage.ru_utime) + TGDiagnosticCPUTime(&usage.ru_stime) - TGDiagnosticCPUTime(&TGDiagnosticInitialUsage.ru_utime) - TGDiagnosticCPUTime(&TGDiagnosticInitialUsage.ru_stime));
    OGPlatformDiagnosticLog(@"STARTUP_STATS elapsed_ms=%.0f final=%d cpu_ms=%.0f db_tasks=%llu db_slow=%llu db_untracked_slow=%llu db_exec_ms=%.0f db_slow_cpu_ms=%.0f db_queue_max_ms=%.0f main_db_waits=%llu main_db_wait_ms=%.0f main_replies=%llu main_hitches=%llu main_hitch_ms=%.0f main_max_ms=%.0f main_pending_ms=%.0f stage_probes=%llu stage_probe_max_ms=%.0f stage_pending_ms=%.0f db_probes=%llu db_probe_max_ms=%.0f db_pending_ms=%.0f", elapsed * 1000.0, final ? 1 : 0, cpu * 1000.0, (unsigned long long)stats.databaseTasks, (unsigned long long)stats.databaseSlowTasks, (unsigned long long)stats.databaseUntrackedSlowTasks, stats.databaseExecution * 1000.0, stats.databaseSlowCPU * 1000.0, stats.maximumDatabaseQueued * 1000.0, (unsigned long long)stats.mainDatabaseWaits, stats.mainDatabaseWait * 1000.0, (unsigned long long)stats.mainReplies, (unsigned long long)stats.mainHitches, stats.mainHitchTime * 1000.0, stats.maximumMainDelay * 1000.0, mainPending * 1000.0, (unsigned long long)stats.stageProbes, stats.maximumStageProbe * 1000.0, stagePending * 1000.0, (unsigned long long)stats.databaseProbes, stats.maximumDatabaseProbe * 1000.0, databasePending * 1000.0);
    for (NSUInteger rank = 0; rank < 3; rank++) {
        NSUInteger best = 32;
        for (NSUInteger i = 0; i < 32; i++)
            if (sites[i].file != NULL && (best == 32 || sites[i].execution > sites[best].execution))
                best = i;
        if (best == 32)
            break;
        TGDiagnosticDatabaseSite site = sites[best];
        OGPlatformDiagnosticLog(@"STARTUP_DB_SITE elapsed_ms=%.0f file=%s line=%d count=%llu exec_ms=%.0f cpu_ms=%.0f queue_max_ms=%.0f", elapsed * 1000.0, site.file, site.line, (unsigned long long)site.count, site.execution * 1000.0, site.slowCPU * 1000.0, site.maximumQueued * 1000.0);
        sites[best].file = NULL;
    }
    if (final)
        OGPlatformDiagnosticLog(@"STARTUP_%s elapsed_ms=%.0f rows=%lu sync=%d network=%d ui=%d visible=%d list=%d complete=%d settled=%d ui_pending=%d", state.ready ? "READY" : "INCOMPLETE", (state.ready ? state.readyTime : elapsed) * 1000.0, (unsigned long)state.dialogCount, state.syncSucceeded ? 1 : 0, state.networkNormal ? 1 : 0, state.uiNormal ? 1 : 0, state.visible ? 1 : 0, state.dialogsPresented ? 1 : 0, state.dialogsComplete ? 1 : 0, state.settled ? 1 : 0, state.uiWorkPending ? 1 : 0);
    if (final)
        dispatch_async(dispatch_get_main_queue(), ^{
            if (TGDiagnosticObserver != NULL) {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), TGDiagnosticObserver, kCFRunLoopCommonModes);
                CFRelease(TGDiagnosticObserver);
                TGDiagnosticObserver = NULL;
            }
        });
}

static int TGDiagnosticSampleMainThread(uintptr_t *frames, int capacity)
{
    if (thread_suspend(TGDiagnosticMainThreadPort) != KERN_SUCCESS)
        return 0;
    int count = 0;
    uintptr_t pointer = 0;
#if defined(__arm64__)
    arm_thread_state64_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(TGDiagnosticMainThreadPort, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount) == KERN_SUCCESS) {
        frames[count++] = state.__pc;
        frames[count++] = state.__lr;
        pointer = state.__fp;
    }
#elif defined(__arm__)
    arm_thread_state_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE_COUNT;
    if (thread_get_state(TGDiagnosticMainThreadPort, ARM_THREAD_STATE, (thread_state_t)&state, &stateCount) == KERN_SUCCESS) {
        frames[count++] = state.__pc;
        frames[count++] = state.__lr;
        pointer = state.__r[7];
    }
#endif
    while (count != 0 && count < capacity && pointer >= TGDiagnosticMainStackLow && pointer <= TGDiagnosticMainStackHigh - 2 * sizeof(uintptr_t) && (pointer & (sizeof(uintptr_t) - 1)) == 0) {
        uintptr_t next = ((uintptr_t *)pointer)[0];
        uintptr_t address = ((uintptr_t *)pointer)[1];
        if (address == 0 || next <= pointer)
            break;
        frames[count++] = address;
        pointer = next;
    }
    thread_resume(TGDiagnosticMainThreadPort);
    return count;
}

static void TGDiagnosticLogRawStack(double delay)
{
    uintptr_t frames[12];
    int count = TGDiagnosticSampleMainThread(frames, 12);
    NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"STARTUP_STACK elapsed_ms=%.0f delay_ms=%.0f frames=", OGStartupDiagnosticsTime() * 1000.0, delay * 1000.0];
    for (int i = 0; i < count; i++) {
        uintptr_t address = frames[i] & ~(uintptr_t)1;
        Dl_info info;
        memset(&info, 0, sizeof(info));
        if (dladdr((const void *)address, &info) != 0 && info.dli_fname != NULL) {
            const char *name = strrchr(info.dli_fname, '/');
            [line appendFormat:@"%s%s+0x%lx", i == 0 ? "" : ",", name == NULL ? info.dli_fname : name + 1, (unsigned long)(address - (uintptr_t)info.dli_fbase)];
        } else {
            [line appendFormat:@"%s0x%lx", i == 0 ? "" : ",", (unsigned long)address];
        }
    }
    OGPlatformDiagnosticLog(@"%@", line);
}

static void TGDiagnosticSendQueueProbes(void)
{
    double sent = OGStartupDiagnosticsTime();
    pthread_mutex_lock(&TGDiagnosticLock);
    bool stage = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready && !TGDiagnosticStagePending;
    bool database = OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready && TGDiagnosticStartup.dialogsPresented && !TGDiagnosticDatabasePending;
    if (stage) {
        TGDiagnosticStagePending = true;
        TGDiagnosticStageSent = sent;
    }
    if (database) {
        TGDiagnosticDatabasePending = true;
        TGDiagnosticDatabaseSent = sent;
    }
    pthread_mutex_unlock(&TGDiagnosticLock);
    if (stage)
        [ActionStageInstance() dispatchOnStageQueue:^{
            double delay = OGStartupDiagnosticsTime() - sent;
            pthread_mutex_lock(&TGDiagnosticLock);
            if (OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready) {
                TGDiagnosticStats.stageProbes++;
                TGDiagnosticStats.maximumStageProbe = MAX(TGDiagnosticStats.maximumStageProbe, delay);
            }
            TGDiagnosticStagePending = false;
            pthread_mutex_unlock(&TGDiagnosticLock);
        }];
    if (database)
        [TGDatabaseInstance() dispatchOnDatabaseThread:^{
            double delay = OGStartupDiagnosticsTime() - sent;
            pthread_mutex_lock(&TGDiagnosticLock);
            if (OGStartupDiagnosticsIsCollecting() && !TGDiagnosticStartup.ready) {
                TGDiagnosticStats.databaseProbes++;
                TGDiagnosticStats.maximumDatabaseProbe = MAX(TGDiagnosticStats.maximumDatabaseProbe, delay);
            }
            TGDiagnosticDatabasePending = false;
            pthread_mutex_unlock(&TGDiagnosticLock);
        } synchronous:false];
}

static void *TGDiagnosticMonitorThreadMain(void *)
{
    pthread_t thread = pthread_self();
    int policy = 0;
    struct sched_param parameters;
    if (pthread_getschedparam(thread, &policy, &parameters) == 0) {
        int priority = sched_get_priority_min(policy);
        if (priority != -1) {
            parameters.sched_priority = priority;
            pthread_setschedparam(thread, policy, &parameters);
        }
    }
    thread_extended_policy_data_t extended;
    extended.timeshare = true;
    thread_policy_set(pthread_mach_thread_np(thread), THREAD_EXTENDED_POLICY, (thread_policy_t)&extended, THREAD_EXTENDED_POLICY_COUNT);
    double nextPing = 0.0;
    double nextProbe = 5.0;
    double nextReport = 10.0;
    double pingSent = 0.0;
    double lastStack = -30.0;
    int stacks = 0;
    bool sampled = false;
    while (OGStartupDiagnosticsIsCollecting()) {
        usleep(250000);
        @autoreleasepool {
            double now = OGStartupDiagnosticsTime();
            pthread_mutex_lock(&TGDiagnosticLock);
            bool ready = TGDiagnosticStartup.ready;
            double reply = TGDiagnosticPingDelay;
            TGDiagnosticPingDelay = -1.0;
            bool pending = TGDiagnosticPingPending;
            if (reply >= 0.0) {
                TGDiagnosticStats.mainReplies++;
                TGDiagnosticStats.maximumMainDelay = MAX(TGDiagnosticStats.maximumMainDelay, reply);
                if (reply >= 0.1) {
                    TGDiagnosticStats.mainHitches++;
                    TGDiagnosticStats.mainHitchTime += reply;
                }
                TGDiagnosticPingPending = false;
                pending = false;
                nextPing = now + 1.0;
            }
            pthread_mutex_unlock(&TGDiagnosticLock);
            if (ready || now >= 300.0) {
                TGDiagnosticReport(true);
                break;
            }
            if (pending && !sampled && now - pingSent >= 2.0 && stacks < 3 && now - lastStack >= 30.0) {
                sampled = true;
                lastStack = now;
                stacks++;
                TGDiagnosticLogRawStack(now - pingSent);
            }
            if (!pending && now >= nextPing) {
                pingSent = now;
                sampled = false;
                pthread_mutex_lock(&TGDiagnosticLock);
                TGDiagnosticPingPending = true;
                TGDiagnosticPingSent = now;
                pthread_mutex_unlock(&TGDiagnosticLock);
                dispatch_async(dispatch_get_main_queue(), ^{
                    double delay = OGStartupDiagnosticsTime() - now;
                    pthread_mutex_lock(&TGDiagnosticLock);
                    if (OGStartupDiagnosticsIsCollecting())
                        TGDiagnosticPingDelay = delay;
                    pthread_mutex_unlock(&TGDiagnosticLock);
                });
            }
            if (now >= nextProbe) {
                nextProbe = now + 5.0;
                TGDiagnosticSendQueueProbes();
            }
            if (now >= nextReport) {
                nextReport = now + 10.0;
                TGDiagnosticReport(false);
            }
            TGDiagnosticVerifyReadiness();
        }
    }
    return NULL;
}

static void TGStartMainThreadStallMonitor(void)
{
    static bool started = false;
    if (started || !OGStartupDiagnosticsIsCollecting())
        return;
    started = true;
    pthread_t mainThread = pthread_self();
    TGDiagnosticMainThreadPort = pthread_mach_thread_np(mainThread);
    TGDiagnosticMainStackHigh = (uintptr_t)pthread_get_stackaddr_np(mainThread);
    TGDiagnosticMainStackLow = TGDiagnosticMainStackHigh - (uintptr_t)pthread_get_stacksize_np(mainThread);
    TGDiagnosticObserver = CFRunLoopObserverCreate(NULL, kCFRunLoopBeforeWaiting, true, LONG_MAX, TGDiagnosticRunLoopSettled, NULL);
    if (TGDiagnosticObserver != NULL)
        CFRunLoopAddObserver(CFRunLoopGetMain(), TGDiagnosticObserver, kCFRunLoopCommonModes);
    else
        OGStartupDiagnosticsMark("observer_failed");
    pthread_t monitor;
    if (pthread_create(&monitor, NULL, TGDiagnosticMonitorThreadMain, NULL) == 0)
        pthread_detach(monitor);
    else {
        OGStartupDiagnosticsMark("monitor_failed");
        TGDiagnosticReport(true);
    }
}
#endif

static void TGEarlyLaunchPerf(NSString *stage)
{
#if defined(ONEGRAM_DIAGNOSTICS)
    OGStartupDiagnosticsMark(stage.UTF8String);
#endif
}

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED < 50000
#include <pthread.h>
#include <stdlib.h>
typedef struct TGDispatchSpecificCompatEntry {
    const void *key;
    void *context;
    dispatch_function_t destructor;
    struct TGDispatchSpecificCompatEntry *next;
} TGDispatchSpecificCompatEntry;
typedef struct TGDispatchSpecificCompatQueue {
    dispatch_queue_t queue;
    TGDispatchSpecificCompatEntry *head;
    struct TGDispatchSpecificCompatQueue *next;
} TGDispatchSpecificCompatQueue;
static pthread_mutex_t TGDispatchSpecificCompatMutex = PTHREAD_MUTEX_INITIALIZER;
static TGDispatchSpecificCompatQueue *TGDispatchSpecificCompatQueues = NULL;
extern "C" void TGDispatchQueueSetSpecificCompat(dispatch_queue_t queue, const void *key, void *context, dispatch_function_t destructor)
{
    if (queue == NULL || key == NULL)
        return;
    dispatch_function_t oldDestructor = NULL;
    void *oldContext = NULL;
    dispatch_queue_t queueToRelease = NULL;
    pthread_mutex_lock(&TGDispatchSpecificCompatMutex);
    TGDispatchSpecificCompatQueue **queueLink = &TGDispatchSpecificCompatQueues;
    TGDispatchSpecificCompatQueue *queueEntry = NULL;
    while (*queueLink != NULL)
    {
        if ((*queueLink)->queue == queue)
        {
            queueEntry = *queueLink;
            break;
        }
        queueLink = &(*queueLink)->next;
    }
    if (queueEntry == NULL && context != NULL)
    {
        queueEntry = (TGDispatchSpecificCompatQueue *)calloc(1, sizeof(TGDispatchSpecificCompatQueue));
        if (queueEntry != NULL)
        {
            dispatch_retain(queue);
            queueEntry->queue = queue;
            queueEntry->next = TGDispatchSpecificCompatQueues;
            TGDispatchSpecificCompatQueues = queueEntry;
            queueLink = &TGDispatchSpecificCompatQueues;
        }
    }
    if (queueEntry != NULL)
    {
        TGDispatchSpecificCompatEntry **entryLink = &queueEntry->head;
        TGDispatchSpecificCompatEntry *entry = NULL;
        while (*entryLink != NULL)
        {
            if ((*entryLink)->key == key)
            {
                entry = *entryLink;
                break;
            }
            entryLink = &(*entryLink)->next;
        }
        if (context == NULL)
        {
            if (entry != NULL)
            {
                *entryLink = entry->next;
                oldDestructor = entry->destructor;
                oldContext = entry->context;
                free(entry);
            }
            if (queueEntry->head == NULL)
            {
                TGDispatchSpecificCompatQueue **removeLink = &TGDispatchSpecificCompatQueues;
                while (*removeLink != NULL && *removeLink != queueEntry)
                    removeLink = &(*removeLink)->next;
                if (*removeLink == queueEntry)
                {
                    *removeLink = queueEntry->next;
                    queueToRelease = queueEntry->queue;
                    free(queueEntry);
                }
            }
        }
        else
        {
            if (entry == NULL)
            {
                entry = (TGDispatchSpecificCompatEntry *)calloc(1, sizeof(TGDispatchSpecificCompatEntry));
                if (entry != NULL)
                {
                    entry->key = key;
                    entry->next = queueEntry->head;
                    queueEntry->head = entry;
                }
            }
            if (entry != NULL)
            {
                if (entry->context != context)
                {
                    oldDestructor = entry->destructor;
                    oldContext = entry->context;
                }
                entry->context = context;
                entry->destructor = destructor;
            }
        }
    }
    pthread_mutex_unlock(&TGDispatchSpecificCompatMutex);
    if (oldDestructor != NULL && oldContext != NULL)
        oldDestructor(oldContext);
    if (queueToRelease != NULL)
        dispatch_release(queueToRelease);
}
extern "C" void *TGDispatchGetSpecificCompat(const void *key)
{
    if (key == NULL)
        return NULL;
    dispatch_queue_t currentQueue = dispatch_get_current_queue();
    if (currentQueue == NULL)
        return NULL;
    void *result = NULL;
    pthread_mutex_lock(&TGDispatchSpecificCompatMutex);
    TGDispatchSpecificCompatQueue *queueEntry = TGDispatchSpecificCompatQueues;
    while (queueEntry != NULL)
    {
        if (queueEntry->queue == currentQueue)
        {
            TGDispatchSpecificCompatEntry *entry = queueEntry->head;
            while (entry != NULL)
            {
                if (entry->key == key)
                {
                    result = entry->context;
                    break;
                }
                entry = entry->next;
            }
            break;
        }
        queueEntry = queueEntry->next;
    }
    pthread_mutex_unlock(&TGDispatchSpecificCompatMutex);
    return result;
}
#endif

static NSString *TGIOS6CrashReportEndpoint()
{
    return @"";
}

static NSString *TGIOS6CrashReportSecret()
{
    return @"";
}

static NSString *TGIOS6CrashReportPath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
    NSString *documentsPath = paths.count == 0 ? NSTemporaryDirectory() : [paths objectAtIndex:0];
    return [documentsPath stringByAppendingPathComponent:@"ios6_last_crash.txt"];
}

static NSString *TGIOS6SystemCrashMarkerPath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
    NSString *documentsPath = paths.count == 0 ? NSTemporaryDirectory() : [paths objectAtIndex:0];
    return [documentsPath stringByAppendingPathComponent:@"ios6_last_system_crash.txt"];
}

static NSString *TGIOS6CrashEscape(NSString *string)
{
    if (string == nil)
        return @"";
    NSString *escaped = [string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
    return escaped;
}

static NSString *TGIOS6CrashNormalizedMessage(NSString *message)
{
    if (message.length == 0)
        return @"";
    NSError *regexError = nil;
    NSRegularExpression *longPointerRegex = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-fA-F]{9,}" options:0 error:&regexError];
    if (longPointerRegex == nil)
        return message;
    return [longPointerRegex stringByReplacingMatchesInString:message options:0 range:NSMakeRange(0, message.length) withTemplate:@"0xADDR"];
}

static NSUncaughtExceptionHandler *TGIOS6PreviousUncaughtExceptionHandler = NULL;
static char TGIOS6SignalCrashPath[PATH_MAX] = {0};
static char TGIOS6SignalBreadcrumbPath[PATH_MAX] = {0};
static char TGIOS6CrashEnvironment[2048] = {0};
static size_t TGIOS6CrashEnvironmentLength = 0;
static uintptr_t TGIOS6ExecutableImageBase = 0;
static uintptr_t TGIOS6ExecutableImageEnd = 0;
static intptr_t TGIOS6ExecutableImageSlide = 0;
static volatile sig_atomic_t TGIOS6HandlingFatalSignal = 0;
static volatile sig_atomic_t TGIOS6ExceptionRecordedThisRun = 0;

#define TGIOS6_CRASH_IMAGE_MAX 256
#define TGIOS6_CRASH_IMAGE_NAME_MAX 96

typedef struct
{
    uintptr_t start;
    uintptr_t end;
    char name[TGIOS6_CRASH_IMAGE_NAME_MAX];
    size_t nameLength;
} TGIOS6CrashImageRange;

static TGIOS6CrashImageRange TGIOS6CrashImageRanges[TGIOS6_CRASH_IMAGE_MAX];
static size_t TGIOS6CrashImageRangeCount = 0;

static void TGIOS6WriteHexPointer(int fd, const void *pointer);

static void TGIOS6PrepareExecutableImageRange()
{
    const struct mach_header *header = _dyld_get_image_header(0);
    TGIOS6ExecutableImageBase = (uintptr_t)header;
    TGIOS6ExecutableImageSlide = _dyld_get_image_vmaddr_slide(0);
    TGIOS6ExecutableImageEnd = TGIOS6ExecutableImageBase;
    if (header == NULL)
        return;

    const uint8_t *cursor = (const uint8_t *)header + (header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
    const uint8_t *commandsEnd = cursor + header->sizeofcmds;
    for (uint32_t i = 0; i < header->ncmds; i++)
    {
        if ((size_t)(commandsEnd - cursor) < sizeof(struct load_command))
            break;
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(struct load_command) || command->cmdsize > (size_t)(commandsEnd - cursor))
            break;
        if (command->cmd == LC_SEGMENT && command->cmdsize >= sizeof(struct segment_command))
        {
            const struct segment_command *segment = (const struct segment_command *)command;
            uintptr_t segmentEnd = (uintptr_t)((intptr_t)segment->vmaddr + (intptr_t)segment->vmsize + TGIOS6ExecutableImageSlide);
            if (segmentEnd > TGIOS6ExecutableImageEnd)
                TGIOS6ExecutableImageEnd = segmentEnd;
        }
        else if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64))
        {
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
            uintptr_t segmentEnd = (uintptr_t)segment->vmaddr + (uintptr_t)segment->vmsize + TGIOS6ExecutableImageSlide;
            if (segmentEnd > TGIOS6ExecutableImageEnd)
                TGIOS6ExecutableImageEnd = segmentEnd;
        }
        cursor += command->cmdsize;
    }
}

static void TGIOS6PrepareLoadedImageRanges()
{
    TGIOS6CrashImageRangeCount = 0;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t imageIndex = 0; imageIndex < imageCount && TGIOS6CrashImageRangeCount < TGIOS6_CRASH_IMAGE_MAX; imageIndex++)
    {
        const struct mach_header *header = _dyld_get_image_header(imageIndex);
        if (header == NULL)
            continue;

        intptr_t slide = _dyld_get_image_vmaddr_slide(imageIndex);
        uintptr_t textStart = 0;
        uintptr_t textEnd = 0;
        const uint8_t *cursor = (const uint8_t *)header + (header->magic == MH_MAGIC_64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));
        const uint8_t *commandsEnd = cursor + header->sizeofcmds;
        for (uint32_t commandIndex = 0; commandIndex < header->ncmds; commandIndex++)
        {
            if ((size_t)(commandsEnd - cursor) < sizeof(struct load_command))
                break;
            const struct load_command *command = (const struct load_command *)cursor;
            if (command->cmdsize < sizeof(struct load_command) || command->cmdsize > (size_t)(commandsEnd - cursor))
                break;

            if (command->cmd == LC_SEGMENT && command->cmdsize >= sizeof(struct segment_command))
            {
                const struct segment_command *segment = (const struct segment_command *)command;
                if (strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) == 0)
                {
                    textStart = (uintptr_t)((intptr_t)segment->vmaddr + slide);
                    textEnd = textStart + (uintptr_t)segment->vmsize;
                    break;
                }
            }
            else if (command->cmd == LC_SEGMENT_64 && command->cmdsize >= sizeof(struct segment_command_64))
            {
                const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
                if (strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) == 0)
                {
                    textStart = (uintptr_t)((intptr_t)segment->vmaddr + slide);
                    textEnd = textStart + (uintptr_t)segment->vmsize;
                    break;
                }
            }
            cursor += command->cmdsize;
        }

        if (textStart == 0 || textEnd <= textStart)
            continue;

        const char *path = _dyld_get_image_name(imageIndex);
        const char *name = path;
        if (path != NULL)
        {
            const char *slash = strrchr(path, '/');
            if (slash != NULL && slash[1] != 0)
                name = slash + 1;
        }
        if (name == NULL || name[0] == 0)
            name = "?";

        TGIOS6CrashImageRange *range = &TGIOS6CrashImageRanges[TGIOS6CrashImageRangeCount++];
        range->start = textStart;
        range->end = textEnd;
        size_t nameLength = strlen(name);
        if (nameLength >= TGIOS6_CRASH_IMAGE_NAME_MAX)
            nameLength = TGIOS6_CRASH_IMAGE_NAME_MAX - 1;
        memcpy(range->name, name, nameLength);
        range->name[nameLength] = 0;
        range->nameLength = nameLength;
    }
}

static const TGIOS6CrashImageRange *TGIOS6CrashImageRangeForAddress(uintptr_t address)
{
    uintptr_t normalizedAddress = address & ~(uintptr_t)1;
    for (size_t i = 0; i < TGIOS6CrashImageRangeCount; i++)
    {
        const TGIOS6CrashImageRange *range = &TGIOS6CrashImageRanges[i];
        if (normalizedAddress >= range->start && normalizedAddress < range->end)
            return range;
    }
    return NULL;
}

static void TGIOS6PrepareCrashEnvironment()
{
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"] ?: @"?";
    NSString *build = [info objectForKey:@"CFBundleVersion"] ?: @"?";
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
    NSString *displayName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"Onegram";
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion] ?: @"?";

    struct utsname systemInfo;
    memset(&systemInfo, 0, sizeof(systemInfo));
    uname(&systemInfo);

    TGIOS6PrepareExecutableImageRange();
    TGIOS6PrepareLoadedImageRanges();

#if defined(ONEGRAM_ARMV6)
    const char *architecture = "armv6";
#elif defined(__arm__)
    const char *architecture = "armv7";
#elif defined(__arm64__)
    const char *architecture = "arm64";
#elif defined(__i386__)
    const char *architecture = "i386";
#elif defined(__x86_64__)
    const char *architecture = "x86_64";
#else
    const char *architecture = "unknown";
#endif

    int length = snprintf(TGIOS6CrashEnvironment, sizeof(TGIOS6CrashEnvironment),
        "CRASH app=%s\n"
        "CRASH version=%s\n"
        "CRASH build=%s\n"
        "CRASH bundle=%s\n"
        "CRASH device=%s\n"
        "CRASH os=%s\n"
        "CRASH arch=%s\n"
        "CRASH pid=%d\n"
        "CRASH image_base=0x%lx\n"
        "CRASH image_end=0x%lx\n"
        "CRASH image_slide=0x%lx\n",
        [displayName UTF8String],
        [version UTF8String],
        [build UTF8String],
        [bundleId UTF8String],
        systemInfo.machine,
        [systemVersion UTF8String],
        architecture,
        (int)getpid(),
        (unsigned long)TGIOS6ExecutableImageBase,
        (unsigned long)TGIOS6ExecutableImageEnd,
        (unsigned long)TGIOS6ExecutableImageSlide);
    if (length < 0)
        length = 0;
    if ((size_t)length >= sizeof(TGIOS6CrashEnvironment))
        length = (int)sizeof(TGIOS6CrashEnvironment) - 1;
    TGIOS6CrashEnvironmentLength = (size_t)length;
}

static void TGIOS6WriteRegisterLine(int fd, const char *name, uintptr_t value)
{
    write(fd, "CRASH ", 6);
    write(fd, name, strlen(name));
    write(fd, "=", 1);
    TGIOS6WriteHexPointer(fd, (const void *)value);
    write(fd, "\n", 1);
}

static void TGIOS6WriteImageAddressLine(int fd, const char *name, uintptr_t address)
{
    const TGIOS6CrashImageRange *range = TGIOS6CrashImageRangeForAddress(address);
    if (range == NULL)
        return;

    uintptr_t normalizedAddress = address & ~(uintptr_t)1;
    write(fd, "CRASH ", 6);
    write(fd, name, strlen(name));
    write(fd, "=", 1);
    write(fd, range->name, range->nameLength);
    write(fd, "+", 1);
    TGIOS6WriteHexPointer(fd, (const void *)(normalizedAddress - range->start));
    write(fd, "\n", 1);
}

static bool TGIOS6ReadCrashMemory(uintptr_t address, void *buffer, size_t length)
{
    if (address == 0 || length == 0 || address > UINTPTR_MAX - length)
        return false;

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    mach_vm_size_t bytesRead = 0;
#else
    vm_size_t bytesRead = 0;
#endif
    kern_return_t result = vm_read_overwrite(mach_task_self(), (vm_address_t)address,
        (vm_size_t)length, (vm_address_t)buffer, &bytesRead);
    return result == KERN_SUCCESS && bytesRead == length;
}

static void TGIOS6WriteSignalStack(int fd, uintptr_t pc, uintptr_t lr, uintptr_t sp)
{
    TGIOS6WriteImageAddressLine(fd, "pc_image", pc);
    TGIOS6WriteImageAddressLine(fd, "lr_image", lr);
    if (TGIOS6ExecutableImageBase != 0 && pc >= TGIOS6ExecutableImageBase && pc < TGIOS6ExecutableImageEnd)
        TGIOS6WriteRegisterLine(fd, "pc_app_offset", pc - TGIOS6ExecutableImageBase);
    if (TGIOS6ExecutableImageBase != 0 && lr >= TGIOS6ExecutableImageBase && lr < TGIOS6ExecutableImageEnd)
        TGIOS6WriteRegisterLine(fd, "lr_app_offset", lr - TGIOS6ExecutableImageBase);

    if (sp == 0)
        return;

    int stackAppCount = 0;
    int stackImageCount = 0;
    uintptr_t previousImageCandidate = 0;
    for (size_t i = 0; i < 64; i++)
    {
        size_t offset = i * sizeof(uintptr_t);
        uintptr_t candidate = 0;
        if (sp > UINTPTR_MAX - offset || !TGIOS6ReadCrashMemory(sp + offset, &candidate, sizeof(candidate)))
            break;
        uintptr_t normalizedCandidate = candidate & ~(uintptr_t)1;
        TGIOS6WriteRegisterLine(fd, "stack_raw", candidate);
        if (TGIOS6ExecutableImageBase != 0 && normalizedCandidate >= TGIOS6ExecutableImageBase && normalizedCandidate < TGIOS6ExecutableImageEnd && stackAppCount < 20)
        {
            TGIOS6WriteRegisterLine(fd, "stack_app", (uintptr_t)((intptr_t)normalizedCandidate - TGIOS6ExecutableImageSlide));
            stackAppCount++;
        }
        if (stackImageCount < 32 && normalizedCandidate != previousImageCandidate && TGIOS6CrashImageRangeForAddress(normalizedCandidate) != NULL)
        {
            TGIOS6WriteImageAddressLine(fd, "stack_image", normalizedCandidate);
            previousImageCandidate = normalizedCandidate;
            stackImageCount++;
        }
    }
}

#if defined(__arm64__)
static void TGIOS6WriteArm64Frames(int fd, uintptr_t fp, uintptr_t sp)
{
    for (int i = 0; i < 32; i++)
    {
        if (sp == 0 || fp < sp || fp - sp > 8 * 1024 * 1024 || (fp & 15) != 0)
            break;
        uintptr_t frame[2];
        if (!TGIOS6ReadCrashMemory(fp, frame, sizeof(frame)))
            break;
        uintptr_t returnAddress = frame[1];
        TGIOS6WriteRegisterLine(fd, "frame_lr", returnAddress);
        TGIOS6WriteImageAddressLine(fd, "frame_image", returnAddress);
        if (TGIOS6ExecutableImageBase != 0 && returnAddress >= TGIOS6ExecutableImageBase && returnAddress < TGIOS6ExecutableImageEnd)
            TGIOS6WriteRegisterLine(fd, "frame_app", (uintptr_t)((intptr_t)returnAddress - TGIOS6ExecutableImageSlide));
        if (frame[0] <= fp)
            break;
        fp = frame[0];
    }
}
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#import <objc/message.h>
#import <execinfo.h>
#import <float.h>
#import <stdlib.h>

typedef NSInteger TGIOS3BackgroundTaskIdentifier;
#define TGIOS3BackgroundTaskInvalid ((NSInteger)-1)

static bool TGIOS3SupportsBackgroundTasks(void)
{
    return [UIApplication instancesRespondToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)];
}

static TGIOS3BackgroundTaskIdentifier TGIOS3BeginBackgroundTask(UIApplication *application, void (^expirationHandler)(void))
{
    if (!TGIOS3SupportsBackgroundTasks())
        return TGIOS3BackgroundTaskInvalid;
    typedef NSInteger (*BeginBackgroundTaskMsgSend)(id, SEL, void (^)(void));
    return ((BeginBackgroundTaskMsgSend)objc_msgSend)(application, @selector(beginBackgroundTaskWithExpirationHandler:), expirationHandler);
}

static void TGIOS3EndBackgroundTask(UIApplication *application, TGIOS3BackgroundTaskIdentifier identifier)
{
    if (!TGIOS3SupportsBackgroundTasks() || identifier == TGIOS3BackgroundTaskInvalid)
        return;
    typedef void (*EndBackgroundTaskMsgSend)(id, SEL, NSInteger);
    ((EndBackgroundTaskMsgSend)objc_msgSend)(application, @selector(endBackgroundTask:), identifier);
}

static double TGIOS3BackgroundTimeRemaining(UIApplication *application)
{
    if (![UIApplication instancesRespondToSelector:@selector(backgroundTimeRemaining)])
        return DBL_MAX;
    typedef double (*BackgroundTimeRemainingMsgSend)(id, SEL);
    return ((BackgroundTimeRemainingMsgSend)objc_msgSend)(application, @selector(backgroundTimeRemaining));
}

static bool TGIOS3SupportsVoipKeepAlive(void)
{
    return [UIApplication instancesRespondToSelector:@selector(setKeepAliveTimeout:handler:)];
}

static bool TGIOS3SetKeepAliveTimeout(UIApplication *application, NSTimeInterval timeout, void (^handler)(void))
{
    if (!TGIOS3SupportsVoipKeepAlive())
        return false;
    typedef BOOL (*SetKeepAliveTimeoutMsgSend)(id, SEL, NSTimeInterval, void (^)(void));
    return ((SetKeepAliveTimeoutMsgSend)objc_msgSend)(application, @selector(setKeepAliveTimeout:handler:), timeout, handler) != NO;
}

static void TGIOS3ClearKeepAliveTimeout(UIApplication *application)
{
    if (!TGIOS3SupportsVoipKeepAlive())
        return;
    typedef void (*ClearKeepAliveTimeoutMsgSend)(id, SEL);
    ((ClearKeepAliveTimeoutMsgSend)objc_msgSend)(application, @selector(clearKeepAliveTimeout));
}
#else
typedef UIBackgroundTaskIdentifier TGIOS3BackgroundTaskIdentifier;
#define TGIOS3BackgroundTaskInvalid UIBackgroundTaskInvalid

static TGIOS3BackgroundTaskIdentifier TGIOS3BeginBackgroundTask(UIApplication *application, void (^expirationHandler)(void))
{
    return [application beginBackgroundTaskWithExpirationHandler:expirationHandler];
}

static void TGIOS3EndBackgroundTask(UIApplication *application, TGIOS3BackgroundTaskIdentifier identifier)
{
    if (identifier != TGIOS3BackgroundTaskInvalid)
        [application endBackgroundTask:identifier];
}

static double TGIOS3BackgroundTimeRemaining(UIApplication *application)
{
    return [application backgroundTimeRemaining];
}

static bool TGIOS3SetKeepAliveTimeout(UIApplication *application, NSTimeInterval timeout, void (^handler)(void))
{
    return [application setKeepAliveTimeout:timeout handler:handler];
}

static void TGIOS3ClearKeepAliveTimeout(UIApplication *application)
{
    [application clearKeepAliveTimeout];
}
#endif

static NSString *TGIOS6ExceptionStackSymbols(NSException *exception)
{
    if ([exception respondsToSelector:@selector(callStackSymbols)])
        return [[exception performSelector:@selector(callStackSymbols)] componentsJoinedByString:@"\n"];

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    void *frames[128];
    int frameCount = backtrace(frames, 128);
    if (frameCount <= 0)
        return nil;

    char **symbols = backtrace_symbols(frames, frameCount);
    if (symbols == NULL)
        return nil;

    NSMutableString *stack = [[NSMutableString alloc] initWithCapacity:frameCount * 64];
    for (int index = 0; index < frameCount; index++)
    {
        if (index > 0)
            [stack appendString:@"\n"];
        [stack appendFormat:@"%s", symbols[index]];
    }
    free(symbols);
    return stack;
#else
    return nil;
#endif
}

static void TGIOS6UncaughtExceptionHandler(NSException *exception)
{
    NSString *stack = TGIOS6ExceptionStackSymbols(exception);
    NSString *breadcrumbs = [NSString stringWithContentsOfFile:TGIOS6DiagnosticBreadcrumbPath() encoding:NSUTF8StringEncoding error:nil];
    if (breadcrumbs.length > 128 * 1024)
        breadcrumbs = [breadcrumbs substringFromIndex:breadcrumbs.length - 128 * 1024];

    NSString *environment = TGIOS6CrashEnvironmentLength != 0 ?
        [[NSString alloc] initWithBytes:TGIOS6CrashEnvironment length:TGIOS6CrashEnvironmentLength encoding:NSUTF8StringEncoding] : @"";
    NSString *message = [NSString stringWithFormat:
        @"%@CRASH type=exception\nCRASH context=%@\nCRASH name=%@\nCRASH reason=%@\nCRASH stack=%@\nCRASH context-begin\n%@CRASH context-end\n",
        environment ?: @"",
        TGIOS6BotContext(),
        exception.name ?: @"",
        exception.reason ?: @"",
        stack ?: @"",
        breadcrumbs ?: @""];

    TGIOS6ExceptionRecordedThisRun = 1;
    [message writeToFile:TGIOS6CrashReportPath() atomically:false encoding:NSUTF8StringEncoding error:nil];

    if (TGIOS6PreviousUncaughtExceptionHandler != NULL &&
        TGIOS6PreviousUncaughtExceptionHandler != &TGIOS6UncaughtExceptionHandler)
    {
        TGIOS6PreviousUncaughtExceptionHandler(exception);
    }
}

static void TGIOS6WriteSignalNumber(int fd, int value)
{
    char digits[16];
    int index = 0;
    unsigned int magnitude = value < 0 ? (unsigned int)(-(value + 1)) + 1U : (unsigned int)value;
    if (value < 0)
        write(fd, "-", 1);
    if (magnitude == 0)
    {
        const char zero = '0';
        write(fd, &zero, 1);
        return;
    }

    while (magnitude > 0 && index < (int)sizeof(digits))
    {
        digits[index++] = (char)('0' + (magnitude % 10));
        magnitude /= 10;
    }
    while (index > 0)
    {
        const char digit = digits[--index];
        write(fd, &digit, 1);
    }
}

static void TGIOS6WriteHexPointer(int fd, const void *pointer)
{
    uintptr_t value = (uintptr_t)pointer;
    static const char digits[] = "0123456789abcdef";
    char buffer[2 + sizeof(uintptr_t) * 2];
    int index = 0;
    buffer[index++] = '0';
    buffer[index++] = 'x';

    bool emitted = false;
    for (int shift = (int)(sizeof(uintptr_t) * 8) - 4; shift >= 0; shift -= 4)
    {
        unsigned int nibble = (unsigned int)((value >> shift) & 0xf);
        if (nibble != 0 || emitted || shift == 0)
        {
            buffer[index++] = digits[nibble];
            emitted = true;
        }
    }
    write(fd, buffer, index);
}

static void TGIOS6FatalSignalHandler(int signalNumber, siginfo_t *signalInfo, void *context)
{
    if (TGIOS6HandlingFatalSignal)
        _exit(128 + signalNumber);
    TGIOS6HandlingFatalSignal = 1;

    if (TGIOS6SignalCrashPath[0] != 0)
    {
        int flags = O_WRONLY | O_CREAT | (TGIOS6ExceptionRecordedThisRun ? O_APPEND : O_TRUNC);
        int fd = open(TGIOS6SignalCrashPath, flags, 0644);
        if (fd >= 0)
        {
            if (TGIOS6CrashEnvironmentLength != 0)
                write(fd, TGIOS6CrashEnvironment, TGIOS6CrashEnvironmentLength);

            static const char prefix[] = "CRASH type=signal\nCRASH signal=";
            static const char codePrefix[] = "\nCRASH code=";
            static const char addressPrefix[] = "\nCRASH address=";
            static const char contextPrefix[] = "\nCRASH context-begin\n";
            static const char contextSuffix[] = "CRASH context-end\n";
            write(fd, prefix, sizeof(prefix) - 1);
            TGIOS6WriteSignalNumber(fd, signalNumber);
            write(fd, codePrefix, sizeof(codePrefix) - 1);
            TGIOS6WriteSignalNumber(fd, signalInfo != NULL ? signalInfo->si_code : 0);
            write(fd, addressPrefix, sizeof(addressPrefix) - 1);
            TGIOS6WriteHexPointer(fd, signalInfo != NULL ? signalInfo->si_addr : NULL);
            write(fd, "\nCRASH tl_current=", 18);
            TGIOS6WriteHexPointer(fd, (const void *)(uintptr_t)(uint32_t)TGTLParserCurrentSignature);
            write(fd, "\nCRASH tl_last=", 15);
            TGIOS6WriteHexPointer(fd, (const void *)(uintptr_t)(uint32_t)TGTLParserLastSignature);
            write(fd, "\nCRASH tl_vector_signature=", 27);
            TGIOS6WriteHexPointer(fd, (const void *)(uintptr_t)(uint32_t)TGTLParserVectorItemSignature);
            write(fd, "\nCRASH tl_vector_index=", 23);
            TGIOS6WriteSignalNumber(fd, TGTLParserVectorItemIndex);
            write(fd, "\nCRASH tl_vector_count=", 23);
            TGIOS6WriteSignalNumber(fd, TGTLParserVectorItemCount);
            write(fd, "\n", 1);

            if (context != NULL && ((ucontext_t *)context)->uc_mcontext != NULL)
            {
                ucontext_t *ucontext = (ucontext_t *)context;
#if defined(__arm__)
#if __DARWIN_UNIX03
                uintptr_t pc = (uintptr_t)ucontext->uc_mcontext->__ss.__pc;
                uintptr_t lr = (uintptr_t)ucontext->uc_mcontext->__ss.__lr;
                uintptr_t sp = (uintptr_t)ucontext->uc_mcontext->__ss.__sp;
                TGIOS6WriteRegisterLine(fd, "pc", pc);
                TGIOS6WriteRegisterLine(fd, "lr", lr);
                TGIOS6WriteRegisterLine(fd, "sp", sp);
                TGIOS6WriteRegisterLine(fd, "fp", (uintptr_t)ucontext->uc_mcontext->__ss.__r[7]);
                TGIOS6WriteRegisterLine(fd, "r0", (uintptr_t)ucontext->uc_mcontext->__ss.__r[0]);
                TGIOS6WriteRegisterLine(fd, "r1", (uintptr_t)ucontext->uc_mcontext->__ss.__r[1]);
                TGIOS6WriteRegisterLine(fd, "r2", (uintptr_t)ucontext->uc_mcontext->__ss.__r[2]);
                TGIOS6WriteRegisterLine(fd, "r3", (uintptr_t)ucontext->uc_mcontext->__ss.__r[3]);
                TGIOS6WriteRegisterLine(fd, "r4", (uintptr_t)ucontext->uc_mcontext->__ss.__r[4]);
                TGIOS6WriteRegisterLine(fd, "r5", (uintptr_t)ucontext->uc_mcontext->__ss.__r[5]);
                TGIOS6WriteRegisterLine(fd, "r6", (uintptr_t)ucontext->uc_mcontext->__ss.__r[6]);
                TGIOS6WriteRegisterLine(fd, "r8", (uintptr_t)ucontext->uc_mcontext->__ss.__r[8]);
                TGIOS6WriteRegisterLine(fd, "r9", (uintptr_t)ucontext->uc_mcontext->__ss.__r[9]);
                TGIOS6WriteRegisterLine(fd, "r10", (uintptr_t)ucontext->uc_mcontext->__ss.__r[10]);
                TGIOS6WriteRegisterLine(fd, "r11", (uintptr_t)ucontext->uc_mcontext->__ss.__r[11]);
                TGIOS6WriteRegisterLine(fd, "r12", (uintptr_t)ucontext->uc_mcontext->__ss.__r[12]);
#else
                uintptr_t pc = (uintptr_t)ucontext->uc_mcontext->ss.pc;
                uintptr_t lr = (uintptr_t)ucontext->uc_mcontext->ss.lr;
                uintptr_t sp = (uintptr_t)ucontext->uc_mcontext->ss.sp;
                TGIOS6WriteRegisterLine(fd, "pc", pc);
                TGIOS6WriteRegisterLine(fd, "lr", lr);
                TGIOS6WriteRegisterLine(fd, "sp", sp);
                TGIOS6WriteRegisterLine(fd, "fp", (uintptr_t)ucontext->uc_mcontext->ss.r[7]);
                TGIOS6WriteRegisterLine(fd, "r0", (uintptr_t)ucontext->uc_mcontext->ss.r[0]);
                TGIOS6WriteRegisterLine(fd, "r1", (uintptr_t)ucontext->uc_mcontext->ss.r[1]);
                TGIOS6WriteRegisterLine(fd, "r2", (uintptr_t)ucontext->uc_mcontext->ss.r[2]);
                TGIOS6WriteRegisterLine(fd, "r3", (uintptr_t)ucontext->uc_mcontext->ss.r[3]);
                TGIOS6WriteRegisterLine(fd, "r4", (uintptr_t)ucontext->uc_mcontext->ss.r[4]);
                TGIOS6WriteRegisterLine(fd, "r5", (uintptr_t)ucontext->uc_mcontext->ss.r[5]);
                TGIOS6WriteRegisterLine(fd, "r6", (uintptr_t)ucontext->uc_mcontext->ss.r[6]);
                TGIOS6WriteRegisterLine(fd, "r8", (uintptr_t)ucontext->uc_mcontext->ss.r[8]);
                TGIOS6WriteRegisterLine(fd, "r9", (uintptr_t)ucontext->uc_mcontext->ss.r[9]);
                TGIOS6WriteRegisterLine(fd, "r10", (uintptr_t)ucontext->uc_mcontext->ss.r[10]);
                TGIOS6WriteRegisterLine(fd, "r11", (uintptr_t)ucontext->uc_mcontext->ss.r[11]);
                TGIOS6WriteRegisterLine(fd, "r12", (uintptr_t)ucontext->uc_mcontext->ss.r[12]);
#endif
                TGIOS6WriteSignalStack(fd, pc, lr, sp);
#elif defined(__arm64__)
#if __DARWIN_UNIX03
                const _STRUCT_ARM_THREAD_STATE64 *state = &ucontext->uc_mcontext->__ss;
                uintptr_t pc = (uintptr_t)state->__pc;
                uintptr_t lr = (uintptr_t)state->__lr;
                uintptr_t sp = (uintptr_t)state->__sp;
                uintptr_t fp = (uintptr_t)state->__fp;
                const uint64_t *registers = state->__x;
                TGIOS6WriteRegisterLine(fd, "far", (uintptr_t)ucontext->uc_mcontext->__es.__far);
                TGIOS6WriteRegisterLine(fd, "esr", (uintptr_t)ucontext->uc_mcontext->__es.__esr);
                TGIOS6WriteRegisterLine(fd, "cpsr", (uintptr_t)state->__cpsr);
#else
                const _STRUCT_ARM_THREAD_STATE64 *state = &ucontext->uc_mcontext->ss;
                uintptr_t pc = (uintptr_t)state->pc;
                uintptr_t lr = (uintptr_t)state->lr;
                uintptr_t sp = (uintptr_t)state->sp;
                uintptr_t fp = (uintptr_t)state->fp;
                const uint64_t *registers = state->x;
                TGIOS6WriteRegisterLine(fd, "far", (uintptr_t)ucontext->uc_mcontext->es.far);
                TGIOS6WriteRegisterLine(fd, "esr", (uintptr_t)ucontext->uc_mcontext->es.esr);
                TGIOS6WriteRegisterLine(fd, "cpsr", (uintptr_t)state->cpsr);
#endif
                TGIOS6WriteRegisterLine(fd, "pc", pc);
                TGIOS6WriteRegisterLine(fd, "lr", lr);
                TGIOS6WriteRegisterLine(fd, "sp", sp);
                TGIOS6WriteRegisterLine(fd, "fp", fp);
                for (int i = 0; i < 29; i++)
                {
                    char name[4] = {'x', (char)('0' + i / 10), (char)('0' + i % 10), 0};
                    if (i < 10)
                    {
                        name[1] = name[2];
                        name[2] = 0;
                    }
                    TGIOS6WriteRegisterLine(fd, name, (uintptr_t)registers[i]);
                }
                TGIOS6WriteSignalStack(fd, pc, lr, sp);
                TGIOS6WriteArm64Frames(fd, fp, sp);
#elif defined(__i386__)
#if __DARWIN_UNIX03
                TGIOS6WriteRegisterLine(fd, "pc", (uintptr_t)ucontext->uc_mcontext->__ss.__eip);
                TGIOS6WriteRegisterLine(fd, "sp", (uintptr_t)ucontext->uc_mcontext->__ss.__esp);
                TGIOS6WriteRegisterLine(fd, "fp", (uintptr_t)ucontext->uc_mcontext->__ss.__ebp);
#else
                TGIOS6WriteRegisterLine(fd, "pc", (uintptr_t)ucontext->uc_mcontext->ss.eip);
                TGIOS6WriteRegisterLine(fd, "sp", (uintptr_t)ucontext->uc_mcontext->ss.esp);
                TGIOS6WriteRegisterLine(fd, "fp", (uintptr_t)ucontext->uc_mcontext->ss.ebp);
#endif
#endif
            }

            write(fd, contextPrefix, sizeof(contextPrefix) - 1);

            if (TGIOS6SignalBreadcrumbPath[0] != 0)
            {
                int breadcrumbFd = open(TGIOS6SignalBreadcrumbPath, O_RDONLY);
                if (breadcrumbFd >= 0)
                {
                    off_t endOffset = lseek(breadcrumbFd, 0, SEEK_END);
                    const off_t maximumContextBytes = 128 * 1024;
                    off_t startOffset = endOffset > maximumContextBytes ? endOffset - maximumContextBytes : 0;
                    if (startOffset > 0)
                        lseek(breadcrumbFd, startOffset, SEEK_SET);
                    else
                        lseek(breadcrumbFd, 0, SEEK_SET);

                    char copyBuffer[2048];
                    ssize_t count = 0;
                    bool skipPartialLine = startOffset > 0;
                    while ((count = read(breadcrumbFd, copyBuffer, sizeof(copyBuffer))) > 0)
                    {
                        ssize_t begin = 0;
                        if (skipPartialLine)
                        {
                            while (begin < count && copyBuffer[begin] != '\n')
                                begin++;
                            if (begin < count)
                            {
                                begin++;
                                skipPartialLine = false;
                            }
                        }
                        if (!skipPartialLine && begin < count)
                            write(fd, copyBuffer + begin, (size_t)(count - begin));
                    }
                    close(breadcrumbFd);
                }
            }

            write(fd, contextSuffix, sizeof(contextSuffix) - 1);
            fsync(fd);
            close(fd);
        }
    }

    signal(signalNumber, SIG_DFL);
    if (signalInfo != NULL && signalInfo->si_code > 0 &&
        (signalNumber == SIGSEGV || signalNumber == SIGBUS || signalNumber == SIGILL || signalNumber == SIGFPE))
        return;
    raise(signalNumber);
    _exit(128 + signalNumber);
}

static void TGIOS6InstallCrashReporter()
{
    TGIOS6PrepareCrashEnvironment();
    TGIOS6PrepareDiagnosticBreadcrumbs();
    TGIOS6PreviousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&TGIOS6UncaughtExceptionHandler);

    const char *crashPath = [TGIOS6CrashReportPath() fileSystemRepresentation];
    if (crashPath != NULL)
    {
        strncpy(TGIOS6SignalCrashPath, crashPath, sizeof(TGIOS6SignalCrashPath) - 1);
        TGIOS6SignalCrashPath[sizeof(TGIOS6SignalCrashPath) - 1] = 0;
    }
    const char *breadcrumbPath = [TGIOS6DiagnosticBreadcrumbPath() fileSystemRepresentation];
    if (breadcrumbPath != NULL)
    {
        strncpy(TGIOS6SignalBreadcrumbPath, breadcrumbPath, sizeof(TGIOS6SignalBreadcrumbPath) - 1);
        TGIOS6SignalBreadcrumbPath[sizeof(TGIOS6SignalBreadcrumbPath) - 1] = 0;
    }

    struct sigaction action;
    memset(&action, 0, sizeof(action));
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = TGIOS6FatalSignalHandler;
    action.sa_flags = SA_SIGINFO;

    sigaction(SIGABRT, &action, NULL);
    sigaction(SIGSEGV, &action, NULL);
    sigaction(SIGBUS, &action, NULL);
    sigaction(SIGILL, &action, NULL);
    sigaction(SIGFPE, &action, NULL);
#if defined(ONEGRAM_DIAGNOSTICS) && ONEGRAM_DIAGNOSTICS
    struct sigaction previousPipeAction;
    if (sigaction(SIGPIPE, NULL, &previousPipeAction) == 0 && previousPipeAction.sa_handler == SIG_DFL)
        sigaction(SIGPIPE, &action, NULL);
#endif
#ifdef SIGTRAP
    sigaction(SIGTRAP, &action, NULL);
#endif
}

static void TGIOS6OpenNotificationPeer(int64_t peerId)
{
    if (peerId != 0 && [TGDatabaseInstance() loadConversationWithId:peerId] != nil)
        [[TGInterfaceManager instance] navigateToConversationWithId:peerId conversation:nil performActions:nil atMessage:nil clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:false animated:false];
}

static uintptr_t TGIOS6CrashRegisterValue(NSString *message, NSString *name)
{
    NSString *prefix = [NSString stringWithFormat:@"CRASH %@=0x", name];
    NSRange range = [message rangeOfString:prefix];
    if (range.location == NSNotFound)
        return 0;
    NSUInteger start = range.location + range.length;
    NSUInteger end = start;
    NSCharacterSet *hexSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    while (end < message.length && [hexSet characterIsMember:[message characterAtIndex:end]])
        end++;
    if (end == start)
        return 0;
    NSString *hexString = [message substringWithRange:NSMakeRange(start, end - start)];
    return (uintptr_t)strtoull([hexString UTF8String], NULL, 16);
}

static NSString *TGIOS6CrashSelectorName(uintptr_t selectorAddress)
{
    if (selectorAddress == 0)
        return nil;
    int classCount = objc_getClassList(NULL, 0);
    if (classCount <= 0)
        return nil;
    Class *classes = (Class *)malloc(sizeof(Class) * (NSUInteger)classCount);
    if (classes == NULL)
        return nil;
    classCount = objc_getClassList(classes, classCount);
    NSString *result = nil;
    for (int i = 0; i < classCount && result == nil; i++)
    {
        Class pair[2] = { classes[i], object_getClass(classes[i]) };
        for (int j = 0; j < 2 && result == nil; j++)
        {
            unsigned int count = 0;
            Method *methods = class_copyMethodList(pair[j], &count);
            for (unsigned int k = 0; k < count; k++)
            {
                SEL selector = method_getName(methods[k]);
                if ((uintptr_t)selector == selectorAddress)
                {
                    result = NSStringFromSelector(selector);
                    break;
                }
            }
            if (methods != NULL)
                free(methods);
        }
    }
    free(classes);
    return result;
}

static NSString *TGIOS6CrashResolvedSystemAddress(NSString *label, uintptr_t address, uintptr_t previousImageBase, uintptr_t previousImageEnd)
{
    uintptr_t normalizedAddress = address & ~(uintptr_t)1;
    if (normalizedAddress == 0 || (previousImageBase != 0 && normalizedAddress >= previousImageBase && normalizedAddress < previousImageEnd))
        return nil;

    Dl_info info;
    memset(&info, 0, sizeof(info));
    if (dladdr((const void *)normalizedAddress, &info) == 0 || info.dli_fname == NULL || info.dli_fbase == NULL)
        return nil;

    NSString *path = [NSString stringWithUTF8String:info.dli_fname];
    if (![path hasPrefix:@"/System/"] && ![path hasPrefix:@"/usr/lib/"])
        return nil;

    NSString *image = [path lastPathComponent];
    uintptr_t imageBase = (uintptr_t)info.dli_fbase;
    uintptr_t imageOffset = normalizedAddress >= imageBase ? normalizedAddress - imageBase : 0;
    if (info.dli_sname != NULL && info.dli_saddr != NULL)
    {
        NSString *symbol = [NSString stringWithUTF8String:info.dli_sname];
        uintptr_t symbolAddress = (uintptr_t)info.dli_saddr;
        uintptr_t symbolOffset = normalizedAddress >= symbolAddress ? normalizedAddress - symbolAddress : 0;
        return [NSString stringWithFormat:@"CRASH %@_resolved=%@+0x%lx %@+0x%lx\n", label, image ?: @"?", (unsigned long)imageOffset, symbol ?: @"?", (unsigned long)symbolOffset];
    }
    return [NSString stringWithFormat:@"CRASH %@_resolved=%@+0x%lx\n", label, image ?: @"?", (unsigned long)imageOffset];
}

static void TGIOS6SendPendingCrashReport()
{
    NSString *localPath = TGIOS6CrashReportPath();
    NSString *localMessage = [NSString stringWithContentsOfFile:localPath encoding:NSUTF8StringEncoding error:nil];
    if (localMessage.length != 0)
    {
        uintptr_t selectorAddress = TGIOS6CrashRegisterValue(localMessage, @"x1");
        if (selectorAddress == 0)
            selectorAddress = TGIOS6CrashRegisterValue(localMessage, @"r1");
        NSString *selectorName = TGIOS6CrashSelectorName(selectorAddress);
        if (selectorName.length != 0)
            localMessage = [localMessage stringByAppendingFormat:@"CRASH selector=%@\n", selectorName];

        uintptr_t previousImageBase = TGIOS6CrashRegisterValue(localMessage, @"image_base");
        uintptr_t previousImageEnd = TGIOS6CrashRegisterValue(localMessage, @"image_end");
        uintptr_t pc = TGIOS6CrashRegisterValue(localMessage, @"pc");
        uintptr_t lr = TGIOS6CrashRegisterValue(localMessage, @"lr");
        NSString *pcResolved = TGIOS6CrashResolvedSystemAddress(@"pc", pc, previousImageBase, previousImageEnd);
        NSString *lrResolved = TGIOS6CrashResolvedSystemAddress(@"lr", lr, previousImageBase, previousImageEnd);
        if (pcResolved.length != 0)
            localMessage = [localMessage stringByAppendingString:pcResolved];
        if (lrResolved.length != 0)
            localMessage = [localMessage stringByAppendingString:lrResolved];

        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:localPath error:nil];
        TGArchiveCrashLogText(localMessage, [attributes objectForKey:NSFileModificationDate]);
        TGLog(@"CRASH previous-begin\n%@CRASH previous-end", localMessage);
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:nil];
    }
    return;

    NSString *path = TGIOS6CrashReportPath();
    NSString *message = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (message.length == 0)
        return;
    
    NSString *messageWithContext = [NSString stringWithFormat:@"%@\n%@", TGIOS6BotContext(), TGIOS6CrashNormalizedMessage(message)];
    NSString *bodyString = [NSString stringWithFormat:@"secret=%@&event=%@&message=%@",
        TGIOS6CrashEscape(TGIOS6CrashReportSecret()),
        TGIOS6CrashEscape(@"client_crash"),
        TGIOS6CrashEscape(messageWithContext)];
    NSData *body = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:TGIOS6CrashReportEndpoint()];
    if (body == nil || url == nil)
        return;
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5.0];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:body];
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
    {
        NSHTTPURLResponse *httpResponse = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        NSString *responseBody = data.length == 0 ? @"" : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        TGLog(@"CRASH report status=%d error=%@ body=%@", httpResponse != nil ? (int)httpResponse.statusCode : 0, connectionError, responseBody);
        if (connectionError == nil && httpResponse.statusCode >= 200 && httpResponse.statusCode < 300)
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }];
}

static void TGIOS6SendLatestSystemCrashReport()
{
    return;

    NSString *directory = @"/var/mobile/Library/Logs/CrashReporter";
    NSArray *entries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    if (entries.count == 0)
        return;

    NSString *lastSentName = [NSString stringWithContentsOfFile:TGIOS6SystemCrashMarkerPath() encoding:NSUTF8StringEncoding error:nil];
    NSString *latestName = nil;
    NSDate *latestDate = nil;
    for (NSString *name in entries)
    {
        NSString *extension = [[name pathExtension] lowercaseString];
        if (![name hasPrefix:@"Telegram"] || (![@"ips" isEqualToString:extension] && ![@"crash" isEqualToString:extension]))
            continue;

        NSString *path = [directory stringByAppendingPathComponent:name];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        NSDate *date = [attributes objectForKey:NSFileModificationDate];
        if (date != nil && (latestDate == nil || [date compare:latestDate] == NSOrderedDescending))
        {
            latestDate = date;
            latestName = name;
        }
    }

    if (latestName.length == 0 || [latestName isEqualToString:lastSentName])
        return;

    NSString *path = [directory stringByAppendingPathComponent:latestName];
    NSString *report = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (report.length == 0)
        return;
    if ([report rangeOfString:@"dev.IllyaGIF.Onegram"].location == NSNotFound)
        return;

    NSString *currentBuild = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *jsonBuild = [NSString stringWithFormat:@"\"build_version\":\"%@\"", currentBuild ?: @""];
    NSString *jsonVersion = [NSString stringWithFormat:@"\"app_version\":\"%@\"", currentVersion ?: @""];
    NSString *legacyVersion = [NSString stringWithFormat:@"%@ (%@)", currentBuild ?: @"", currentVersion ?: @""];
    BOOL currentJSONReport = [report rangeOfString:jsonBuild].location != NSNotFound &&
        [report rangeOfString:jsonVersion].location != NSNotFound;
    BOOL currentLegacyReport = [report rangeOfString:legacyVersion].location != NSNotFound;
    if (!currentJSONReport && !currentLegacyReport)
    {
        [latestName writeToFile:TGIOS6SystemCrashMarkerPath() atomically:true encoding:NSUTF8StringEncoding error:nil];
        return;
    }

    NSString *message = [NSString stringWithFormat:@"%@\nsystem_report=%@\n\n%@", TGIOS6BotContext(), latestName, report];
    NSString *bodyString = [NSString stringWithFormat:@"secret=%@&event=%@&message=%@",
        TGIOS6CrashEscape(TGIOS6CrashReportSecret()),
        TGIOS6CrashEscape(@"client_crash_full"),
        TGIOS6CrashEscape(message)];
    NSData *body = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:TGIOS6CrashReportEndpoint()];
    if (body == nil || url == nil)
        return;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:body];
    [request setValue:@"application/x-www-form-urlencoded; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
    {
        NSHTTPURLResponse *httpResponse = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        if (connectionError == nil && httpResponse.statusCode >= 200 && httpResponse.statusCode < 300)
            [latestName writeToFile:TGIOS6SystemCrashMarkerPath() atomically:true encoding:NSUTF8StringEncoding error:nil];
        else
            TGLog(@"CRASH full report status=%d error=%@", httpResponse != nil ? (int)httpResponse.statusCode : 0, connectionError);
    }];
}

@interface CMGestureManager : NSObject {
    id _internal;
}

@property (copy) void(^gestureHandler)(int a, int b);

+ (BOOL)isGestureServiceAvailable;
+ (BOOL)isGestureServiceEnabled;
+ (void)setGestureServiceEnabled:(BOOL)arg1;

- (void)dealloc;
- (id )gestureHandler;
- (id)init;
- (id)initWithPriority:(int)arg1;
- (void)setGestureHandler:(void(^)(int a, int b))arg1;

@end

@interface TGAppDelegate () <AVAudioPlayerDelegate, PKPushRegistryDelegate>
{
    bool _inBackground;
    bool _ios6BackgroundLifecycleEntered;
    bool _enteringForeground;
    
    NSTimer *_foregroundResumeTimer;
    
    TGProgressWindow *_progressWindow;
    
    bool _didBecomeInactive;
    
    TGPasscodeWindow *_passcodeWindow;
    UIWindow *_blurredContentWindow;
    
    SMetaDisposable *_deviceLockedRequestDisposable;
    bool _didUpdateDeviceLocked;
    
    TGUser *_currentInviteBot;
    NSString *_currentInviteBotPayload;
    
    TGUser *_currentStartGameBot;
    NSString *_currentStartGame;
    
    SMetaDisposable *_recentPeersDisposable;
    SMetaDisposable *_termsOfServiceDisposable;

    SMetaDisposable *_ios6VoipHealthCheckDisposable;
    int32_t _ios6VoipHealthCheckGeneration;
    int32_t _ios6VoipHealthCheckAttempt;
    bool _ios6VoipHealthCheckPending;
    CFAbsoluteTime _ios6VoipLastTransportResetTime;
    CFAbsoluteTime _ios6VoipLastProactiveTransportRefreshTime;
    CFAbsoluteTime _ios6VoipLastScheduledHealthCheckTime;
    int32_t _ios6VoipLastPrimaryReceiveUptime;
    TGIOS3BackgroundTaskIdentifier _ios6VoipHealthCheckTaskIdentifier;
    bool _ios6VoipHealthCheckTaskActive;
    bool _ios6NotificationTransportAllowedForBackgroundSession;
    TGIOS3BackgroundTaskIdentifier _ios6ColdLaunchTaskIdentifier;
    bool _ios6ColdLaunchTaskActive;
    
    TGGroupInviteSheet *_groupInviteSheet;
    
    SVariable *_finishedLaunching;
    SVariable *_isActive;
    
    PKPushRegistry *_pushRegistry;
    bool _ios6LocalNotificationSettingsRegistered;
    SPipe *_localizationUpdatedPipe;
    SPipe *_statusBarPressedPipe;
}

@property (nonatomic) bool tokenAlreadyRequested;
@property (nonatomic) NSData *pushToken;
@property (nonatomic, strong) id<TGDeviceTokenListener> deviceTokenListener;

@property (nonatomic) TGIOS3BackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) NSTimer *backgroundTaskExpirationTimer;

@property (nonatomic, strong) NSMutableDictionary *loadedSoundSamples;

@property (nonatomic, strong) UIWebView *callingWebView;

@property (nonatomic, strong) AVAudioPlayer *currentAudioPlayer;
@property (nonatomic, strong) SMetaDisposable *currentAudioPlayerSession;


+ (void)movePathsToContainer;
+ (NSString *)documentsPath;
+ (NSString *)cachePath;

- (void)loadShowCallsTab;
- (void)_replyActionForPeerId:(int64_t)peerId mid:(int32_t)mid openKeyboard:(bool)openKeyboard responseInfo:(NSDictionary *)responseInfo completion:(void (^)())completion;
- (void)onBecomeInactive;
- (void)onBecomeActive;
- (bool)willBeLocked;
- (NSTimeInterval)ios6VoipHealthCheckInterval;
- (void)ios6PerformScheduledVoipHealthCheck;
- (void)ios6PrimaryTransportReceivedData:(NSNotification *)notification;
- (bool)ios6NotificationTransportAllowedWithSystemTypes:(UIRemoteNotificationType *)systemTypes privateEnabled:(bool *)privateEnabled groupEnabled:(bool *)groupEnabled;
- (BOOL)ios6InstallVoipKeepAliveForApplication:(UIApplication *)application source:(NSString *)source;
- (void)ios6StopNotificationTransport;
- (void)ios6EndColdLaunchTask;
- (void)ios6EndVoipHealthCheckTask;
- (void)ios6StartVoipHealthProbe:(int32_t)generation attempt:(int32_t)attempt timeout:(NSTimeInterval)timeout;
- (void)ios6FinishVoipHealthCheck:(int32_t)generation attempt:(int32_t)attempt success:(bool)success reason:(NSString *)reason;
- (void)disableAPNsNotificationRegistration;

@property (nonatomic, strong) void (^onSuccessfulAuthorization)(void);

@property (nonatomic, strong) void (^onSuccessfulLogin)(void);

@end

static NSString *TGLoginAppTitle(void)
{
    NSString *title = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
    if (title.length == 0)
        title = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    return title.length == 0 ? @"Telegram" : title;
}

static NSString *TGLoginTourText(NSString *text)
{
    NSString *result = text ?: @"";
    result = [result stringByReplacingOccurrencesOfString:@"Telegram" withString:TGLoginAppTitle()];
    result = [result stringByReplacingOccurrencesOfString:@"**" withString:@""];
    return result;
}

static UIImage *TGLoginTourImage(NSString *name, size_t maximumPixelSize)
{
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"png" inDirectory:@"Tour.bundle"];
    if (path.length == 0)
        return nil;
    if (OGPlatformUsesConstrainedBackgroundExecution())
        return OGPlatformThumbnailFromImageFile(path, maximumPixelSize);
    return [UIImage imageWithContentsOfFile:path];
}

static UIButton *TGLoginPrimaryButton(NSString *title)
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = UIColorRGB(0x168de2);
    button.layer.cornerRadius = 6.0f;
    button.layer.masksToBounds = true;
    button.showsTouchWhenHighlighted = OGPlatformControlAnimationsEnabled();
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.titleLabel.font = TGMediumSystemFontOfSize(18.0f);
    return button;
}

static NSString *TGLoginQRBase64UrlString(NSData *data)
{
    if (data.length == 0)
        return @"";

    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger length = data.length;
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:((length + 2) / 3) * 4];
    for (NSUInteger i = 0; i < length; i += 3)
    {
        uint32_t value = ((uint32_t)bytes[i]) << 16;
        NSUInteger remaining = length - i;
        if (remaining > 1)
            value |= ((uint32_t)bytes[i + 1]) << 8;
        if (remaining > 2)
            value |= bytes[i + 2];

        [result appendFormat:@"%c", table[(value >> 18) & 63]];
        [result appendFormat:@"%c", table[(value >> 12) & 63]];
        if (remaining > 1)
            [result appendFormat:@"%c", table[(value >> 6) & 63]];
        if (remaining > 2)
            [result appendFormat:@"%c", table[value & 63]];
    }

    [result replaceOccurrencesOfString:@"+" withString:@"-" options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0, result.length)];
    return result;
}

static NSString *TGLoginQRCodeJavaScript(void)
{
    static NSString *script = nil;
    if (script == nil)
    {
        static const char source[] =
#include "../thirdparty/RMIntro/platform/ios/TGIOS6QRCodeJavaScript.inc"
        ;
        script = [[NSString alloc] initWithBytes:source length:sizeof(source) - 1 encoding:NSUTF8StringEncoding];
    }
    return script;
}

@interface TGUIKitQRLoginController : UIViewController
{
    UILabel *_titleLabel;
    UILabel *_helpLabel;
    UIView *_qrContainerView;
    UIWebView *_qrWebView;
    UILabel *_statusLabel;
    UIButton *_phoneButton;
    NSTimer *_refreshTimer;
    NSObject *_requestToken;
    bool _requestInProgress;
    bool _refreshPending;
    bool _hasQrCode;
    bool _passwordControllerPresented;
}
@end

@implementation TGUIKitQRLoginController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        TGIOS6SetQRLoginFlowActive(true);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginTokenUpdated:) name:TGLoginTokenUpdatedNotification object:nil];
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = UIColorRGB(0x222222);
    _titleLabel.font = TGMediumSystemFontOfSize(25.0f);
    _titleLabel.text = TGLocalized(@"Login.QRTitle");
    [self.view addSubview:_titleLabel];

    _helpLabel = [[UILabel alloc] init];
    _helpLabel.backgroundColor = [UIColor clearColor];
    _helpLabel.textAlignment = NSTextAlignmentCenter;
    _helpLabel.textColor = UIColorRGB(0x777777);
    _helpLabel.font = TGSystemFontOfSize(14.0f);
    _helpLabel.numberOfLines = 0;
    _helpLabel.text = TGLocalized(@"Login.QRHelp");
    [self.view addSubview:_helpLabel];

    _qrContainerView = [[UIView alloc] init];
    _qrContainerView.backgroundColor = [UIColor whiteColor];
    _qrContainerView.layer.borderWidth = 1.0f;
    _qrContainerView.layer.borderColor = UIColorRGB(0xe3e6e8).CGColor;
    _qrContainerView.layer.cornerRadius = 8.0f;
    _qrContainerView.clipsToBounds = true;
    [self.view addSubview:_qrContainerView];

    _qrWebView = [[UIWebView alloc] init];
    _qrWebView.backgroundColor = [UIColor whiteColor];
    _qrWebView.opaque = false;
    _qrWebView.userInteractionEnabled = false;
    _qrWebView.hidden = true;
    _qrWebView.scalesPageToFit = false;
    [_qrContainerView addSubview:_qrWebView];

    _statusLabel = [[UILabel alloc] init];
    _statusLabel.backgroundColor = [UIColor clearColor];
    _statusLabel.textColor = UIColorRGB(0x8a8a8a);
    _statusLabel.font = TGSystemFontOfSize(13.0f);
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.text = TGLocalized(@"Login.QRLoading");
    [self.view addSubview:_statusLabel];

    _phoneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_phoneButton setTitle:TGLocalized(@"Login.PhoneLogin") forState:UIControlStateNormal];
    [_phoneButton setTitleColor:TGAccentColor() forState:UIControlStateNormal];
    _phoneButton.titleLabel.font = TGMediumSystemFontOfSize(17.0f);
    _phoneButton.showsTouchWhenHighlighted = OGPlatformControlAnimationsEnabled();
    [_phoneButton addTarget:self action:@selector(phoneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_phoneButton];

    [self layoutQrLoginViews];
}

- (void)layoutQrLoginViews
{
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    bool compact = height <= 480.0f;

    CGFloat titleTop = compact ? 4.0f : 14.0f;
    CGFloat titleHeight = compact ? 30.0f : 34.0f;
    _titleLabel.frame = CGRectMake(16.0f, titleTop, width - 32.0f, titleHeight);

    CGFloat helpTop = CGRectGetMaxY(_titleLabel.frame) + (compact ? 2.0f : 4.0f);
    CGFloat helpHeight = compact ? 34.0f : 44.0f;
    _helpLabel.frame = CGRectMake(22.0f, helpTop, width - 44.0f, helpHeight);

    CGFloat qrSize = MIN(width - (compact ? 116.0f : 76.0f), compact ? 158.0f : 190.0f);
    qrSize = MAX(132.0f, qrSize);
    CGFloat qrTop = CGRectGetMaxY(_helpLabel.frame) + (compact ? 4.0f : 10.0f);
    _qrContainerView.frame = CGRectMake(floor((width - qrSize) / 2.0f), qrTop, qrSize, qrSize);
    _qrWebView.frame = _qrContainerView.bounds;

    CGFloat statusTop = CGRectGetMaxY(_qrContainerView.frame) + 3.0f;
    _statusLabel.frame = CGRectMake(16.0f, statusTop, width - 32.0f, compact ? 18.0f : 20.0f);

    CGFloat phoneTop = CGRectGetMaxY(_statusLabel.frame) + (compact ? 1.0f : 6.0f);
    CGFloat phoneHeight = compact ? 40.0f : 44.0f;
    _phoneButton.frame = CGRectMake(16.0f, phoneTop, width - 32.0f, phoneHeight);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:false animated:false];
    TGIOS6SetQRLoginFlowActive(true);
    [self layoutQrLoginViews];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_passwordControllerPresented)
    {
        _passwordControllerPresented = false;
        return;
    }
    [self refreshQrLoginToken];
}

- (void)loginTokenUpdated:(__unused NSNotification *)notification
{
    [self refreshQrLoginToken];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_refreshTimer invalidate];
    _refreshTimer = nil;
    if (_requestToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:_requestToken softCancel:true];
        _requestToken = nil;
    }
    _requestInProgress = false;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self layoutQrLoginViews];
}

- (bool)renderQrLoginToken:(NSData *)token targetSize:(CGFloat)targetSize
{
    if (token.length == 0)
        return false;

    NSString *payload = [NSString stringWithFormat:@"tg://login?token=%@", TGLoginQRBase64UrlString(token)];
    NSString *script = TGLoginQRCodeJavaScript();
    if (script.length == 0)
        return false;

    int pixelSize = MAX(120, (int)floor(targetSize));
    NSString *html = [NSString stringWithFormat:
        @"<html><head><meta name='viewport' content='width=%d,initial-scale=1.0,maximum-scale=1.0,user-scalable=no'><style>html,body{margin:0;padding:0;width:%dpx;height:%dpx;background:#fff;overflow:hidden}#wrap{position:relative;width:%dpx;height:%dpx;overflow:hidden;background:#fff}canvas{position:absolute;display:block}</style></head><body><div id='wrap'><canvas id='q'></canvas></div><script>%@;var q=new QRCode(0,QRErrorCorrectLevel.M);q.addData('%@');q.make();var n=q.getModuleCount(),quiet=4,scale=Math.max(1,Math.floor(%d/(n+quiet*2))),size=(n+quiet*2)*scale,c=document.getElementById('q'),x=c.getContext('2d'),left=Math.floor((%d-size)/2),top=Math.floor((%d-size)/2);c.width=size;c.height=size;c.style.left=left+'px';c.style.top=top+'px';x.fillStyle='#fff';x.fillRect(0,0,size,size);x.fillStyle='#000';for(var r=0;r<n;r++){for(var col=0;col<n;col++){if(q.isDark(r,col))x.fillRect((col+quiet)*scale,(r+quiet)*scale,scale,scale);}}</script></body></html>",
        pixelSize, pixelSize, pixelSize, pixelSize, pixelSize, script, payload, pixelSize, pixelSize, pixelSize];

    [_qrWebView loadHTMLString:html baseURL:nil];
    _qrWebView.hidden = false;
    return true;
}

- (void)scheduleRefreshAtExpires:(int32_t)expires
{
    [_refreshTimer invalidate];
    _refreshTimer = nil;
    NSTimeInterval remoteNow = [[TGTelegramNetworking instance] approximateRemoteTime];
    NSTimeInterval delay = expires > 0 ? ((NSTimeInterval)expires - remoteNow - 3.0) : 20.0;
    delay = MAX(5.0, MIN(25.0, delay));
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(refreshTimerFired) userInfo:nil repeats:false];
}

- (void)refreshTimerFired
{
    _refreshTimer = nil;
    [self refreshQrLoginToken];
}

- (void)refreshQrLoginToken
{
    if (!self.isViewLoaded || self.view.window == nil)
        return;

    if (_requestInProgress)
    {
        _refreshPending = true;
        return;
    }

    TGTelegramNetworking *networking = [TGTelegramNetworking instance];
    [networking prepareForUnauthorizedRequests];

    _requestInProgress = true;
    _refreshPending = false;
    if (!_hasQrCode)
        _statusLabel.text = TGLocalized(@"Login.QRLoading");

    __unsafe_unretained TGUIKitQRLoginController *weakSelf = self;
    _requestToken = [TGTelegraphInstance doExportLoginTokenWithCompletion:^(NSData *token, int32_t expires, bool authorized, NSString *errorText)
    {
        TGDispatchOnMainThread(^{
            __strong TGUIKitQRLoginController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            strongSelf->_requestToken = nil;
            strongSelf->_requestInProgress = false;

            if (authorized)
            {
                TGIOS6SetQRLoginFlowActive(false);
                strongSelf->_statusLabel.text = TGLocalized(@"Login.QRAuthorized");
                [strongSelf->_refreshTimer invalidate];
                strongSelf->_refreshTimer = nil;
                [TGAppDelegateInstance presentMainController];
                return;
            }

            if (token.length != 0)
            {
                bool rendered = [strongSelf renderQrLoginToken:token targetSize:strongSelf->_qrContainerView.bounds.size.width];
                if (rendered)
                {
                    strongSelf->_hasQrCode = true;
                    strongSelf->_statusLabel.text = @"";
                    [strongSelf scheduleRefreshAtExpires:expires];
                }
                else
                {
                    strongSelf->_statusLabel.text = TGLocalized(@"Login.QRError");
                    [strongSelf scheduleRefreshAtExpires:0];
                }
            }
            else if ([errorText hasPrefix:@"SESSION_PASSWORD_NEEDED"])
            {
                [strongSelf->_refreshTimer invalidate];
                strongSelf->_refreshTimer = nil;
                strongSelf->_refreshPending = false;
                strongSelf->_statusLabel.text = @"";
                if (!strongSelf->_passwordControllerPresented)
                {
                    strongSelf->_passwordControllerPresented = true;
                    TGLoginPasswordController *passwordController = [[TGLoginPasswordController alloc] initForQrLogin];
                    [strongSelf.navigationController pushViewController:passwordController animated:true];
                }
                return;
            }
            else if ([errorText isEqualToString:@"AUTH_RESTART"])
            {
                strongSelf->_statusLabel.text = TGLocalized(@"Login.QRLoading");
                [strongSelf->_refreshTimer invalidate];
                strongSelf->_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:strongSelf selector:@selector(refreshTimerFired) userInfo:nil repeats:false];
            }
            else
            {
                strongSelf->_statusLabel.text = TGLocalized(@"Login.QRError");
                [strongSelf scheduleRefreshAtExpires:0];
            }

            if (strongSelf->_refreshPending)
            {
                strongSelf->_refreshPending = false;
                [strongSelf refreshQrLoginToken];
            }
        });
    }];
}

- (void)phoneButtonPressed
{
    TGIOS6SetQRLoginFlowActive(false);
    [self.navigationController pushViewController:[[TGLoginPhoneController alloc] init] animated:true];
}

- (void)dealloc
{
    TGIOS6SetQRLoginFlowActive(false);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_refreshTimer invalidate];
    if (_requestToken != nil)
        [TGTelegraphInstance cancelRequestByToken:_requestToken softCancel:true];
}

@end

UIViewController *TGCreateLoginQRController(void)
{
    Class controllerClass = NSClassFromString(@"TGIOS6QRLoginController");
    if (controllerClass != Nil)
        return [[controllerClass alloc] init];
    return [[TGUIKitQRLoginController alloc] init];
}

@interface TGUIKitLoginIntroController : UIViewController <UIScrollViewDelegate>
{
    UIScrollView *_pageScrollView;
    UIPageControl *_pageControl;
    UIButton *_startButton;
    UIButton *_onegramCoreButton;
    bool _onegramCoreButtonVisible;
    NSArray *_imageNames;
    NSMutableIndexSet *_loadedImagePages;
    NSArray *_pageViews;
    NSInteger _currentPage;
}
@end

@interface TGUIKitLoginIntroController (Private)
- (void)loadImageForPage:(NSUInteger)pageIndex;
- (void)prefetchRemainingImages;
- (void)updateOnegramCoreButton;
- (void)onegramCoreButtonPressed;
@end

@implementation TGUIKitLoginIntroController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        self.wantsFullScreenLayout = true;
    return self;
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];

    _pageScrollView = [[UIScrollView alloc] init];
    _pageScrollView.backgroundColor = [UIColor whiteColor];
    _pageScrollView.pagingEnabled = true;
    _pageScrollView.showsHorizontalScrollIndicator = false;
    _pageScrollView.showsVerticalScrollIndicator = false;
    _pageScrollView.bounces = true;
    _pageScrollView.delegate = self;
    [self.view addSubview:_pageScrollView];

    NSString *appTitle = TGLoginAppTitle();
    NSArray *titles = @[appTitle, TGLocalized(@"Tour.Title2"), TGLocalized(@"Tour.Title6"), TGLocalized(@"Tour.Title3"), TGLocalized(@"Tour.Title4"), TGLocalized(@"Tour.Title5")];
    NSArray *texts = @[TGLocalized(@"Tour.Text1"), TGLocalized(@"Tour.Text2"), TGLocalized(@"Tour.Text6"), TGLocalized(@"Tour.Text3"), TGLocalized(@"Tour.Text4"), TGLocalized(@"Tour.Text5")];
    _imageNames = @[@"TourLogo@2x", @"TourIcon1@2x", @"TourIcon5@2x", @"TourIcon2@2x", @"TourIcon3@2x", @"TourIcon4@2x"];
    _loadedImagePages = [[NSMutableIndexSet alloc] init];
    NSMutableArray *pages = [[NSMutableArray alloc] initWithCapacity:titles.count];

    for (NSUInteger i = 0; i < titles.count; i++)
    {
        UIView *page = [[UIView alloc] init];
        page.backgroundColor = [UIColor whiteColor];

        UIImageView *imageView = [[UIImageView alloc] initWithImage:nil];
        imageView.tag = 1;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [page addSubview:imageView];

        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.tag = 2;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = UIColorRGB(0x222222);
        titleLabel.font = TGMediumSystemFontOfSize(27.0f);
        titleLabel.text = TGLoginTourText([titles objectAtIndex:i]);
        [page addSubview:titleLabel];

        UILabel *descriptionLabel = [[UILabel alloc] init];
        descriptionLabel.tag = 3;
        descriptionLabel.backgroundColor = [UIColor clearColor];
        descriptionLabel.textAlignment = NSTextAlignmentCenter;
        descriptionLabel.textColor = UIColorRGB(0x777777);
        descriptionLabel.font = TGSystemFontOfSize(16.0f);
        descriptionLabel.numberOfLines = 0;
        descriptionLabel.text = TGLoginTourText([texts objectAtIndex:i]);
        [page addSubview:descriptionLabel];

        [_pageScrollView addSubview:page];
        [pages addObject:page];
    }
    _pageViews = pages;

    _pageControl = [[UIPageControl alloc] init];
    _pageControl.numberOfPages = _pageViews.count;
    _pageControl.currentPage = 0;
    [_pageControl addTarget:self action:@selector(pageControlChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_pageControl];

    _startButton = TGLoginPrimaryButton(TGLocalized(@"Tour.StartButton"));
    [_startButton addTarget:self action:@selector(startButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_startButton];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onegramCoreStateChanged:) name:OGOnegramCoreDidChangeNotification object:nil];
    _onegramCoreButton = [[UIButton alloc] initWithFrame:CGRectZero];
    _onegramCoreButton.adjustsImageWhenHighlighted = false;
    [_onegramCoreButton addTarget:self action:@selector(onegramCoreButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_onegramCoreButton];
    [self updateOnegramCoreButton];

    [self layoutIntroViews];
    [self loadImageForPage:0];
    [self prefetchRemainingImages];
}

- (void)loadImageForPage:(NSUInteger)pageIndex
{
    if (pageIndex >= _pageViews.count || pageIndex >= _imageNames.count || [_loadedImagePages containsIndex:pageIndex])
        return;

    [_loadedImagePages addIndex:pageIndex];
    UIView *page = [_pageViews objectAtIndex:pageIndex];
    UIImageView *imageView = (UIImageView *)[page viewWithTag:1];
    NSString *name = [_imageNames objectAtIndex:pageIndex];
    size_t maximumPixelSize = (size_t)ceilf(MAX(imageView.bounds.size.width, imageView.bounds.size.height));
    UIImage *image = TGLoginTourImage(name, maximumPixelSize);
    if (image != nil)
        imageView.image = image;
}

- (void)prefetchRemainingImages
{
    if (!OGPlatformUsesConstrainedBackgroundExecution())
    {
        for (NSUInteger i = 1; i < _pageViews.count; i++)
            [self loadImageForPage:i];
    }
}

- (void)layoutIntroViews
{
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat statusBarHeight = iosMajorVersion() >= 7 ? 0.0f : 20.0f;
    _onegramCoreButton.frame = CGRectMake(width - 52.0f, statusBarHeight + 4.0f, 44.0f, 44.0f);
    CGFloat buttonHeight = 46.0f;
    CGFloat buttonBottom = height <= 480.0f ? 14.0f : 22.0f;
    _startButton.frame = CGRectMake(20.0f, height - buttonBottom - buttonHeight, width - 40.0f, buttonHeight);
    _pageControl.frame = CGRectMake(20.0f, CGRectGetMinY(_startButton.frame) - 34.0f, width - 40.0f, 20.0f);

    CGFloat scrollHeight = CGRectGetMinY(_pageControl.frame) - 2.0f;
    _pageScrollView.frame = CGRectMake(0.0f, 0.0f, width, scrollHeight);
    _pageScrollView.contentSize = CGSizeMake(width * _pageViews.count, scrollHeight);

    CGFloat imageTop = height <= 480.0f ? 34.0f : 54.0f;
    CGFloat imageHeight = height <= 480.0f ? 150.0f : 190.0f;
    CGFloat titleTop = imageTop + imageHeight + (height <= 480.0f ? 8.0f : 18.0f);
    CGFloat descriptionTop = titleTop + 39.0f;

    for (NSUInteger i = 0; i < _pageViews.count; i++)
    {
        UIView *page = [_pageViews objectAtIndex:i];
        page.frame = CGRectMake(width * i, 0.0f, width, scrollHeight);
        UIImageView *imageView = (UIImageView *)[page viewWithTag:1];
        UILabel *titleLabel = (UILabel *)[page viewWithTag:2];
        UILabel *descriptionLabel = (UILabel *)[page viewWithTag:3];
        imageView.frame = CGRectMake(42.0f, imageTop, width - 84.0f, imageHeight);
        titleLabel.frame = CGRectMake(18.0f, titleTop, width - 36.0f, 34.0f);
        descriptionLabel.frame = CGRectMake(24.0f, descriptionTop, width - 48.0f, MAX(44.0f, scrollHeight - descriptionTop - 6.0f));
    }

    _pageScrollView.contentOffset = CGPointMake(width * _currentPage, 0.0f);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:true animated:false];
    _onegramCoreButtonVisible = true;
    [self updateOnegramCoreButton];
    [self layoutIntroViews];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _onegramCoreButtonVisible = false;
    _onegramCoreButton.hidden = true;
    [self.navigationController setNavigationBarHidden:false animated:false];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self layoutIntroViews];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.bounds.size.width <= 0.0f)
        return;
    NSInteger page = (NSInteger)floor((scrollView.contentOffset.x + scrollView.bounds.size.width * 0.5f) / scrollView.bounds.size.width);
    page = MAX(0, MIN((NSInteger)_pageViews.count - 1, page));
    _currentPage = page;
    [self loadImageForPage:(NSUInteger)page];
    _pageControl.currentPage = page;
}

- (void)pageControlChanged
{
    _currentPage = _pageControl.currentPage;
    [self loadImageForPage:(NSUInteger)_currentPage];
    [_pageScrollView setContentOffset:CGPointMake(_pageScrollView.bounds.size.width * _currentPage, 0.0f) animated:true];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OGOnegramCoreDidChangeNotification object:nil];
}

- (void)startButtonPressed
{
    [self.navigationController pushViewController:TGCreateLoginQRController() animated:true];
}

- (void)updateOnegramCoreButton
{
    _onegramCoreButton.hidden = !_onegramCoreButtonVisible || TGTelegraphInstance.clientUserId != 0;
    bool enabled = [[TGTelegramNetworking instance] onegramCoreMode] != OGOnegramCoreModeNone;
    [_onegramCoreButton setImage:[TGOnegramCoreController lockImageEnabled:enabled highlighted:false] forState:UIControlStateNormal];
    [_onegramCoreButton setImage:[TGOnegramCoreController lockImageEnabled:enabled highlighted:true] forState:UIControlStateHighlighted];
    _onegramCoreButton.accessibilityLabel = @"Onegram Core";
    _onegramCoreButton.accessibilityValue = [TGOnegramCoreController statusText];
}

- (void)onegramCoreButtonPressed
{
    if (_onegramCoreButton.hidden) return;
    [TGOnegramCoreController presentFromViewController:self];
}

- (void)onegramCoreStateChanged:(NSNotification *)notification
{
    [self updateOnegramCoreButton];
}

@end

static UIViewController *TGCreateLoginEntryController(void)
{
    Class introClass = NSClassFromString(@"RMIntroViewController");
    if (introClass != Nil && OGPlatformSupportsModernLoginIntro())
        return [[introClass alloc] init];
    return [[TGUIKitLoginIntroController alloc] init];
}

@implementation TGAppDelegate

static NSString *TGAppDelegateDocumentsPathCompat()
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
        path = paths.count == 0 ? NSTemporaryDirectory() : [paths objectAtIndex:0];
    });
    
    return path;
}

static NSUserDefaults *TGAppDelegateUserDefaultsCompat()
{
    return [NSUserDefaults standardUserDefaults];
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _localizationUpdatedPipe = [[SPipe alloc] init];
        _localizationUpdated = _localizationUpdatedPipe.signalProducer();
        _statusBarPressedPipe = [[SPipe alloc] init];
        _statusBarPressed = _statusBarPressedPipe.signalProducer();
        _finishedLaunching = [[SVariable alloc] init];
        _isActive = [[SVariable alloc] init];
        [_isActive set:[SSignal single:@true]];
        _backgroundTaskIdentifier = TGIOS3BackgroundTaskInvalid;
        _ios6VoipHealthCheckTaskIdentifier = TGIOS3BackgroundTaskInvalid;
        _ios6ColdLaunchTaskIdentifier = TGIOS3BackgroundTaskInvalid;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ios6PrimaryTransportReceivedData:) name:@"TGIOS6PrimaryTransportReceivedData" object:nil];
    }
    return self;
}

- (TGNavigationController *)loginNavigationController
{
    if (_loginNavigationController == nil)
    {
        UIViewController *rootController = TGCreateLoginEntryController();
        TGLog(@"AUTH login.entry=%@", NSStringFromClass([rootController class]));
        _loginNavigationController = [TGNavigationController navigationControllerWithControllers:@[rootController] navigationBarClass:[TGTransparentNavigationBar class] inhibitPresentation:true];
        _loginNavigationController.restrictLandscape = !TGIsPad();
        _loginNavigationController.disableInteractiveKeyboardTransition = true;
    }
    
    return _loginNavigationController;
}

static void overridenDrawRect(__unused id self, __unused SEL _cmd, __unused CGRect rect)
{
}

static unsigned int overrideIndexAbove(__unused id self, __unused SEL _cmd)
{
    return [(TGNavigationBar *)self indexAboveBackdropBackground];
}

- (bool)enableLogging
{
    NSNumber *logsEnabled = [[NSUserDefaults standardUserDefaults] objectForKey:@"__logsEnabled"];
    return [logsEnabled boolValue];
}

- (void)setEnableLogging:(bool)enableLogging
{
    [[NSUserDefaults standardUserDefaults] setObject:@(enableLogging) forKey:@"__logsEnabled"];
    TGLogSetEnabled(enableLogging);
}

- (UIResponder *)nextResponder
{
    if (_keyCommandController != nil)
        return _keyCommandController;
    else
        return [super nextResponder];
}

+ (NSUserDefaults *)userDefaults
{
    static dispatch_once_t onceToken;
    static NSUserDefaults *userDefaults;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 8)
        {
            userDefaults = [self _containerDefaults];
            [self movePasscodeAttemptsToContainer];
        }
        else
        {
            userDefaults = [NSUserDefaults standardUserDefaults];;
        }
    });
    return userDefaults;
}

+ (NSUserDefaults *)_containerDefaults
{
    return [[NSUserDefaults alloc] initWithSuiteName:[@"group." stringByAppendingString:[[NSBundle mainBundle] bundleIdentifier]]];
}

+ (void)movePasscodeAttemptsToContainer
{
    if (iosMajorVersion() < 8)
        return;
    
    NSUserDefaults *localDefaults = [NSUserDefaults standardUserDefaults];
    NSUserDefaults *containerDefaults = [self _containerDefaults];
    
    NSNumber *attempts = [localDefaults objectForKey:@"Passcode_invalidAttempts"];
    if (attempts != nil)
    {
        [containerDefaults setObject:attempts forKey:@"Passcode_invalidAttempts"];
        
        NSNumber *attemptDate = [localDefaults objectForKey:@"Passcode_invalidAttemptDate"];
        if (attemptDate != nil)
            [containerDefaults setObject:attemptDate forKey:@"Passcode_invalidAttemptDate"];
        [containerDefaults synchronize];
    
        [localDefaults removeObjectForKey:@"Passcode_invalidAttempts"];
        [localDefaults removeObjectForKey:@"Passcode_invalidAttemptDate"];
        [localDefaults synchronize];
    }
}


- (void)databaseOpenFailed:(NSNotification *)notification
{
    static bool presenting = false;
    if (presenting) return;
    presenting = true;
    NSError *error = notification.object;
    [TGAlertView presentAlertWithTitle:TGLocalized(@"Database.ErrorTitle") message:error.localizedDescription cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:TGLocalized(@"Database.Retry") completionBlock:^(bool retry)
    {
        presenting = false;
        if (retry) [TGDatabaseInstance() retryOpeningDatabase];
    }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseOpenFailed:) name:@"OnegramDatabaseOpenFailed" object:nil];

    NSDictionary *buildInfo = [[NSBundle mainBundle] infoDictionary];
    TGLog(@"ONEGRAM build=%@ arch=%@ diagnostics=%d transport=%s",
          [buildInfo objectForKey:@"OGOnegramBuildIdentifier"] ?: @"unrecorded",
          [buildInfo objectForKey:@"OGOnegramBuildArchitecture"] ?: @"unrecorded",
          [[buildInfo objectForKey:@"OGOnegramBuildDiagnostics"] boolValue], OGDanteSocketRevision());
#if defined(ONEGRAM_DIAGNOSTICS)
    TGStartMainThreadStallMonitor();
#endif
    TGEarlyLaunchPerf(@"didFinish.enter");
    OGPlatformInstallUIKitGuards();
    TGEarlyLaunchPerf(@"didFinish.uikitGuards");
    bool ios6ColdBackgroundApplicationLaunch =
    OGPlatformSupportsBackgroundVoipTransport() &&
    application.applicationState == UIApplicationStateBackground;
    if (!ios6ColdBackgroundApplicationLaunch)
    {
        OGRuntimeDispatchAfterStartupPhase(OGRuntimePriorityMaintenance, ^
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
            {
                [TGStickersSignals prewarmCachedStickerPacks];
            });
        });
    }
    
    bool ios6ColdBackgroundLaunch =
    ios6ColdBackgroundApplicationLaunch &&
    TGIOS6BackgroundNotificationsEnabled();
    
    if (ios6ColdBackgroundApplicationLaunch && !ios6ColdBackgroundLaunch)
    {
        _inBackground = true;
        _ios6NotificationTransportAllowedForBackgroundSession = false;
        TGIOS3ClearKeepAliveTimeout(application);
    }
    
    if (ios6ColdBackgroundLaunch)
    {
        _inBackground = true;
        _ios6NotificationTransportAllowedForBackgroundSession = true;
        
        __block TGIOS3BackgroundTaskIdentifier coldLaunchTaskIdentifier = TGIOS3BackgroundTaskInvalid;
        coldLaunchTaskIdentifier = TGIOS3BeginBackgroundTask(application, ^
                                    {
                                        IOS6NotificationProbe(@"LEASE", @"cold_launch_expiration id=%d", (int)coldLaunchTaskIdentifier);
                                        
                                        if ([NSThread isMainThread])
                                            [self ios6EndColdLaunchTask];
                                        else
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                [self ios6EndColdLaunchTask];
                                            });
                                    });
        
        if (coldLaunchTaskIdentifier != TGIOS3BackgroundTaskInvalid)
        {
            _ios6ColdLaunchTaskIdentifier = coldLaunchTaskIdentifier;
            _ios6ColdLaunchTaskActive = true;
        }
        
        BOOL provisionalKeepAliveInstalled = TGIOS3SetKeepAliveTimeout(application, 600.0, ^
                                              {
                                                  void (^wakeBlock)(void) = ^
                                                  {
                                                      if (_inBackground &&
                                                          [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
                                                      {
                                                          [self ios6PerformVoipHealthCheck];
                                                      }
                                                  };
                                                  
                                                  if ([NSThread isMainThread])
                                                      wakeBlock();
                                                  else
                                                      dispatch_async(dispatch_get_main_queue(), wakeBlock);
                                              });
        
        IOS6NotificationProbe(@"LIFECYCLE",
                              @"cold_launch_guard task=%d keepAlive=%d remaining=%.1f",
                              (int)coldLaunchTaskIdentifier,
                              provisionalKeepAliveInstalled ? 1 : 0,
                              TGIOS3BackgroundTimeRemaining(application));
    }
    
    TGIOS6InstallCrashReporter();
    TGEarlyLaunchPerf(@"didFinish.crashReporter");

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    if (iosMajorVersion() >= 9) {
        if ([effectiveLocalization().code isEqualToString:@"ar"]) {
            [UIView appearance].semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        } else {
            [UIView appearance].semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        }
    }
#endif
    [LegacyComponentsGlobals setProvider:[[TGLegacyComponentsGlobalsProvider alloc] init]];
    [TGViewController setDefaultContext:[TGLegacyComponentsContext shared]];
    [TGNavigationBar setMusicPlayerProvider:[[TGNavigationBarMusicPlayerProvider alloc] init]];
    TGEarlyLaunchPerf(@"didFinish.legacyGlobals");
    TGLocalization *launchLocalization = effectiveLocalization();
    void (^preloadLaunchFonts)(void) = ^
    {
        [launchLocalization preloadFallback];
        OGPlatformTextWarmFallbackFonts();
    };
    if (OGPlatformUsesConstrainedBackgroundExecution())
        OGRuntimeDispatchAfterStartupPhase(OGRuntimePriorityUtility, preloadLaunchFonts);
    else
        OGRuntimeDispatch(OGRuntimePriorityUserInitiated, preloadLaunchFonts);
    
    TGIsRetina();
    TGLogSetEnabled([self enableLogging]);

    
    if (OGPlatformSupportsBackgroundVoipTransport())
    {
        IOS6NotificationProbe(@"SESSION", @"launch version=%@ build=%@ state=%d",
                              [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?",
                              [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?",
                              (int)application.applicationState);
    }
    
    if (OGPlatformUsesConstrainedBackgroundExecution())
    {
        OGRuntimeDispatchAfterStartupPhase(OGRuntimePriorityMaintenance, ^
        {
            TGIOS6SendPendingCrashReport();
            TGIOS6SendLatestSystemCrashReport();
        });
    }
    else
    {
        TGIOS6SendPendingCrashReport();
        TGIOS6SendLatestSystemCrashReport();
    }
    TGEarlyLaunchPerf(@"didFinish.crashReportsSent");

    if ([TGAppDelegate respondsToSelector:@selector(movePathsToContainer)])
        [TGAppDelegate movePathsToContainer];
    
    NSString *documentsDirectory = TGAppDelegateDocumentsPathCompat();
    if (documentsDirectory.length != 0)
    {
        NSURL *documentsURL = [NSURL fileURLWithPath:documentsDirectory];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50100
        if (&NSURLIsExcludedFromBackupKey != NULL && [documentsURL respondsToSelector:@selector(setResourceValue:forKey:error:)])
        {
            @try
            {
                [documentsURL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:nil];
            }
            @catch (__unused NSException *exception)
            {
            }
        }
        else
#endif
        if (iosMajorVersion() == 5)
        {
            const char *filePath = [documentsDirectory fileSystemRepresentation];
            if (filePath != NULL)
            {
                uint8_t attributeValue = 1;
                setxattr(filePath, "com.apple.MobileBackup", &attributeValue, sizeof(attributeValue), 0, 0);
            }
        }
    }
    
    [TGMessage registerMediaAttachmentParser:TGActionMediaAttachmentType parser:[[TGActionMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGImageMediaAttachmentType parser:[[TGImageMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGLocationMediaAttachmentType parser:[[TGLocationMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGLocalMessageMetaMediaAttachmentType parser:[[TGLocalMessageMetaMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGVideoMediaAttachmentType parser:[[TGVideoMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGContactMediaAttachmentType parser:[[TGContactMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGForwardedMessageMediaAttachmentType parser:[[TGForwardedMessageMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGUnsupportedMediaAttachmentType parser:[[TGUnsupportedMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGDocumentMediaAttachmentType parser:[[TGDocumentMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGAudioMediaAttachmentType parser:[[TGAudioMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGReplyMessageMediaAttachmentType parser:[[TGReplyMessageMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGWebPageMediaAttachmentType parser:[[TGWebPageMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGReplyMarkupAttachmentType parser:[[TGReplyMarkupAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGMessageEntitiesAttachmentType parser:[[TGMessageEntitiesAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGBotContextResultAttachmentType parser:[[TGBotContextResultAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGViaUserAttachmentType parser:[[TGViaUserAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGGameAttachmentType parser:[[TGGameMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGInvoiceMediaAttachmentType parser:[[TGInvoiceMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGAuthorSignatureMediaAttachmentType parser:[[TGAuthorSignatureMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGRichMessageMediaAttachmentType parser:[[TGRichMessageMediaAttachment alloc] init]];
    [TGMessage registerMediaAttachmentParser:TGPollMediaAttachmentType parser:[[TGPollMediaAttachment alloc] init]];
    TGEarlyLaunchPerf(@"didFinish.mediaParsers");
    
    [TGDatabase setPasswordRequiredBlock:^TGDatabasePasswordCheckResultBlock (void (^verifyBlock)(NSString *), bool simple)
    {
        TGDispatchOnMainThread(^
        {
            if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
                [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait];
            if (_passcodeWindow == nil)
            {
                CGRect passcodeFrame = [UIScreen mainScreen].bounds;
                _passcodeWindow = [[TGPasscodeWindow alloc] initWithFrame:passcodeFrame];
                NSInteger initWithNumberOfInvalidAttempts = [[TGAppDelegateUserDefaultsCompat() objectForKey:@"Passcode_invalidAttempts"] integerValue];
                NSTimeInterval invalidAttemptDate = [[TGAppDelegateUserDefaultsCompat() objectForKey:@"Passcode_invalidAttemptDate"] doubleValue];
                TGPasscodeEntryController *controller = [[TGPasscodeEntryController alloc] initWithContext:[TGLegacyComponentsContext shared] style:TGPasscodeEntryControllerStyleTranslucent mode:simple ? TGPasscodeEntryControllerModeVerifySimple : TGPasscodeEntryControllerModeVerifyComplex cancelEnabled:false allowTouchId:false attemptData:[[TGPasscodeEntryAttemptData alloc] initWithNumberOfInvalidAttempts:initWithNumberOfInvalidAttempts dateOfLastInvalidAttempt:invalidAttemptDate] completion:^(NSString *passcode)
                {
                    verifyBlock(passcode);
                }];
                controller.updateAttemptData = ^(TGPasscodeEntryAttemptData *attemptData) {
                    [TGAppDelegateUserDefaultsCompat() setObject:@(attemptData.numberOfInvalidAttempts) forKey:@"Passcode_invalidAttempts"];
                    [TGAppDelegateUserDefaultsCompat() setObject:@(attemptData.dateOfLastInvalidAttempt) forKey:@"Passcode_invalidAttemptDate"];
                };
                
                _passcodeWindow.windowLevel = UIWindowLevelStatusBar - 0.0001f;
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller]];
                navigationController.restrictLandscape = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
                _passcodeWindow.rootViewController = navigationController;
                _passcodeWindow.hidden = false;
                [_passcodeWindow makeKeyAndVisible];
                [controller prepareForAppear];
            }
            else
            {
                _passcodeWindow.hidden = false;
                [_passcodeWindow makeKeyAndVisible];
                if (TGIsPad())
                    _passcodeWindow.frame = [UIScreen mainScreen].bounds;
                else
                    _passcodeWindow.frame = (CGRect){CGPointZero, TGScreenSize()};
                TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                controller.completion = ^(NSString *passcode)
                {
                    verifyBlock(passcode);
                };
                controller.checkCurrentPasscode = nil;
                controller.checkCurrentPasscodeAsync = nil;
                [controller resetMode:simple ? TGPasscodeEntryControllerModeVerifySimple : TGPasscodeEntryControllerModeVerifyComplex];
                [controller prepareForAppear];
            }
            
            [TGEmbedPIPController hide];
            
        });
        
        return ^(bool match)
        {
            TGDispatchOnMainThread(^
            {
                if (match)
                {
                    [_passcodeWindow endEditing:true];
                    TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                    
                    [TGAppDelegateUserDefaultsCompat() removeObjectForKey:@"Passcode_invalidAttempts"];
                    [TGAppDelegateUserDefaultsCompat() removeObjectForKey:@"Passcode_invalidAttemptDate"];
                    [TGAppDelegateUserDefaultsCompat() synchronize];
                    
                    [controller prepareForDisappear];
                    
                    [UIView animateWithDuration:0.3 delay:0 options:[TGViewController preferredAnimationCurve] << 16 animations:^
                    {
                        _passcodeWindow.frame = CGRectOffset(_passcodeWindow.frame, 0.0f, _passcodeWindow.frame.size.height);
                    } completion:^(__unused BOOL finished)
                    {
                        _passcodeWindow.hidden = true;
                    }];
                    
                    if (self.rootController.presentedViewController != nil)
                        [self.rootController.presentedViewController viewDidAppear:false];
                        
                    [TGEmbedPIPController restore];
                    [self resetRemoteDeviceLocked];
                    
                    if (self.onSuccessfulAuthorization != nil)
                    {
                        self.onSuccessfulAuthorization();
                        self.onSuccessfulAuthorization = nil;
                    }
                }
                else
                {
                    TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                    
                    [TGAppDelegateUserDefaultsCompat() setObject:@([controller invalidPasscodeAttempts] + 1) forKey:@"Passcode_invalidAttempts"];
                    [TGAppDelegateUserDefaultsCompat() setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"Passcode_invalidAttemptDate"];
                    [TGAppDelegateUserDefaultsCompat() synchronize];
                    
                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                }
            });
        };
    }];
    [TGDatabase setUpgradingBlock:^TGDatabaseUpgradeCompletedBlock ()
    {
        if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
            return nil;

        __block TGProgressWindow *progressWindow = nil;
        TGDispatchOnMainThread(^
        {
            progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            [progressWindow show:true];
        });
        
        return ^
        {
            TGDispatchOnMainThread(^
            {
                [progressWindow dismiss:true];
            });
        };
    }];
    
    [TGDatabase setLiveMessagesDispatchPath:@"/tg/conversations"];
    [TGDatabase setLiveUnreadCountDispatchPath:@"/tg/unreadCount"];
    TGEarlyLaunchPerf(@"didFinish.databaseHooks");

#if !defined(ONEGRAM_ARMV6)
    [[TGDatabase instance] markAllPendingMessagesAsFailed];
#endif

    _deviceProximityListeners = [[TGHolderSet alloc] init];
    _deviceProximityListeners.emptyStateChanged = ^(bool listenersExist)
    {
        if (listenersExist) {
            [UIDevice currentDevice].proximityMonitoringEnabled = true;
            bool deviceProximityState = [UIDevice currentDevice].proximityState;
            if (deviceProximityState) {
                _deviceProximityState = deviceProximityState;
                [[NSNotificationCenter defaultCenter] postNotificationName:TGDeviceProximityStateChangedNotification object:nil];
            }
        } else if (!TGAppDelegateInstance->_deviceProximityState) {
            [UIDevice currentDevice].proximityMonitoringEnabled = false;
            _deviceProximityState = false;
        }
    };
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceProximityStateDidChangeNotification object:[UIDevice currentDevice] queue:nil usingBlock:^(__unused NSNotification *notification)
    {
        _deviceProximityState = [UIDevice currentDevice].proximityState;
        if (!_deviceProximityState && _deviceProximityListeners.isEmpty) {
            [UIDevice currentDevice].proximityMonitoringEnabled = false;
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:TGDeviceProximityStateChangedNotification object:nil];
    }];
    
    [FFNotificationCenter setShouldRotateBlock:^ bool()
    {
        bool restrictPasscodeWindow = false;
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone && _passcodeWindow != nil && !_passcodeWindow.hidden && [UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait)
        {
            restrictPasscodeWindow = true;
        }

        UIViewController *rootController = _window.rootViewController;
        bool shouldRotate = true;
        if (rootController != nil)
        {
            if ([rootController respondsToSelector:@selector(shouldAutorotate)])
                shouldRotate = [rootController shouldAutorotate];
            else
                shouldRotate = [rootController shouldAutorotateToInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];
        }

        return shouldRotate && !restrictPasscodeWindow;
    }];
    
    TGEarlyLaunchPerf(@"didFinish.beforeFreedom");
    freedomInit();
    freedomUIKitInit();
    TGEarlyLaunchPerf(@"didFinish.afterFreedom");

    TGAppDelegateInstance = self;
    
    [TGPresentation refreshUIAppearance];
    
    if (!TGIsPad())
        [TGViewController disableAutorotation];
    
    _window = [[TGApplicationMainWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    TGEarlyLaunchPerf(@"didFinish.window");
    
    [(TGApplication *)application forceSetStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:false];
    TGEarlyLaunchPerf(@"didFinish.statusBar");
    
    if (iosMajorVersion() < 7)
    {
        FreedomDecoration instanceDecorations[] = {
            { .name = 0x7927c35dU,
              .imp = (IMP)&overridenDrawRect,
              .newIdentifier = FreedomIdentifierEmpty,
              .newEncoding = FreedomIdentifierEmpty
            },
            { .name = 0xc6dda86U,
              .imp = (IMP)&overrideIndexAbove,
              .newIdentifier = FreedomIdentifierEmpty,
              .newEncoding = FreedomIdentifierEmpty
            }
        };
        
        freedomClassAutoDecorate(0xf457bfb2U, NULL, 0, instanceDecorations, sizeof(instanceDecorations) / sizeof(instanceDecorations[0]));
    }
    TGEarlyLaunchPerf(@"didFinish.decorate");
    
    _loadedSoundSamples = [[NSMutableDictionary alloc] init];
    TGEarlyLaunchPerf(@"didFinish.soundSamples");
    
    _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
    TGEarlyLaunchPerf(@"didFinish.actionHandle");
    
    [ASActor registerActorClass:[TGImageDownloadActor class]];
    TGEarlyLaunchPerf(@"didFinish.imageActor");
    
    TGEarlyLaunchPerf(@"didFinish.beforeInterfaceManager");
    [TGInterfaceManager instance];
    TGEarlyLaunchPerf(@"didFinish.interfaceManager");

    TGEarlyLaunchPerf(@"didFinish.beforeTelegraph");
    telegraph = [[TGTelegraph alloc] init];
    TGEarlyLaunchPerf(@"didFinish.afterTelegraph");

    [TGHacks hackSetAnimationDuration];
    
    [self loadShowCallsTab];

    [self loadSettings];
    TGEarlyLaunchPerf(@"didFinish.settings");
    bool launchAuthorized = TGTelegraphInstance.clientUserId != 0 && TGTelegraphInstance.clientIsActivated;
    if (launchAuthorized && !OGPlatformUsesConstrainedBackgroundExecution())
        [TGTelegramNetworking prepareInstanceWithCompletion:nil];
    bool deferAuthorizedRoot = launchAuthorized && OGPlatformUsesConstrainedBackgroundExecution();
    if (deferAuthorizedRoot)
        (void)TGDatabaseInstance();

    if (deferAuthorizedRoot)
    {
        UIViewController *launchController = [[UIViewController alloc] init];
        launchController.view.backgroundColor = [UIColor blackColor];
        self.window.rootViewController = launchController;
    }
    else if (launchAuthorized || !OGPlatformUsesConstrainedBackgroundExecution())
    {
        _rootController = [[TGRootController alloc] init];
        self.window.rootViewController = launchAuthorized ? _rootController : [self loginNavigationController];
    }
    else
    {
        self.window.rootViewController = [self loginNavigationController];
    }

    TGLog(@"AUTH startup.route=%@ userId=%d activated=%d", launchAuthorized ? @"main" : @"login", TGTelegraphInstance.clientUserId, TGTelegraphInstance.clientIsActivated ? 1 : 0);

    if (!launchAuthorized)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [[TGTelegramNetworking instance] prepareForUnauthorizedRequests];
        }];
    }

    TGEarlyLaunchPerf(@"didFinish.rootController");
    self.window.backgroundColor = [UIColor blackColor];
    
    [self.window makeKeyAndVisible];
    TGEarlyLaunchPerf(@"didFinish.keyAndVisible");

    [TGPresentation startAutoNight];
    [TGPresentation prewarmBrandedIOS6ConversationSurfaces];

    if (_rootController != nil && [TGKeyCommandController keyCommandsSupported])
        _keyCommandController = [[TGKeyCommandController alloc] initWithRootController:_rootController];
    
    TGCache *sharedCache = [[TGCache alloc] init];
    [TGRemoteImageView setSharedCache:sharedCache];
    
    if ((launchAuthorized || !OGPlatformUsesConstrainedBackgroundExecution()) && ![TGDatabaseInstance() isEncryptionEnabled])
    {
        TGDispatchOnMainThread(^
        {
            [self displayUnlockWindowIfNeeded];
            TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
            [controller refreshTouchId];
        });
    }
    
    __block bool initialAuthorizationProcessed = false;
    __block bool initialNetworkingStarted = false;
    __block void (^pendingInitialDialogsDelivery)(void) = nil;

    void (^loadInitialDialogs)(void) = ^
    {
            if (!launchAuthorized && OGPlatformUsesConstrainedBackgroundExecution())
            {
                [ActionStageInstance() dispatchOnStageQueue:^
                {
                    [TGTelegraphInstance processUnauthorized];
                    NSDictionary *blockStateDict = [self loadLoginState];

                    OGPlatformDispatchOnMainThread(^
                    {
                        NSDictionary *stateDict = blockStateDict;
                        int currentDate = ((int)CFAbsoluteTimeGetCurrent());
                        int stateDate = [[stateDict objectForKey:@"date"] intValue];
                        if (currentDate - stateDate > 60 * 60 * 23 && [blockStateDict objectForKey:@"resetAccountState"] == nil)
                        {
                            stateDict = nil;
                            [self resetLoginState];
                        }

                        [self presentLoginController:false animated:false phoneNumber:[stateDict objectForKey:@"phoneNumber"] phoneCode:[stateDict objectForKey:@"phoneCode"] phoneCodeHash:[stateDict objectForKey:@"phoneCodeHash"] codeSentToTelegram:[[stateDict objectForKey:@"codeSentToTelegram"] boolValue] codeSentViaPhone:[[stateDict objectForKey:@"codeSentViaPhone"] boolValue] profileFirstName:[stateDict objectForKey:@"firstName"] profileLastName:[stateDict objectForKey:@"lastName"] resetAccountState:[blockStateDict objectForKey:@"resetAccountState"] termsOfService:[blockStateDict objectForKey:@"termsOfService"]];

                        if (!TGIsPad())
                        {
                            [TGViewController enableAutorotation];
                            [TGViewController attemptAutorotation];
                        }
                    });

                    [[TGTelegramNetworking instance] start];
                    if (ios6ColdBackgroundApplicationLaunch && !ios6ColdBackgroundLaunch)
                        [[TGTelegramNetworking instance] pause];
                    [_finishedLaunching set:[SSignal single:@true]];

                    if ([launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey] != nil)
                        [self processPossibleConfigUpdateNotification:[launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey]];
                }];
                return;
            }

        bool legacyConstrained = OGPlatformUsesConstrainedBackgroundExecution();
        int initialDialogLimit = legacyConstrained ? 18 : 50;
        if (legacyConstrained)
            OGDatabaseRuntimeBeginStartupCritical();
#if defined(ONEGRAM_DIAGNOSTICS)
        TGLog(@"STARTUP dialogs load requested limit=%d at=%.0fms", initialDialogLimit, (CFAbsoluteTimeGetCurrent() - mainLaunchTimestamp) * 1000.0);
#endif
        [TGDatabaseInstance() loadConversationListFromDate:INT32_MAX
                                                     limit:initialDialogLimit
                                    excludeConversationIds:nil
                                                  folderId:0
                                                completion:^(NSArray *dialogList, __unused bool loadedAllRegular)
         {
             
#if defined(ONEGRAM_DIAGNOSTICS)
             bool dialogListLoaded = [TGDatabaseInstance() customProperty:@"dialogListLoaded"].length != 0;
             TGLog(@"STARTUP dialogs loaded count=%d listLoaded=%d loadedAll=%d at=%.0fms", (int)dialogList.count, dialogListLoaded ? 1 : 0, loadedAllRegular ? 1 : 0, (CFAbsoluteTimeGetCurrent() - mainLaunchTimestamp) * 1000.0);
#endif
             
             NSMutableArray *filteredResult = [[NSMutableArray alloc] initWithArray:dialogList];
             [filteredResult sortUsingComparator:^NSComparisonResult(TGConversation *lhs, TGConversation *rhs) {
                 if (lhs.date > rhs.date) {
                     return NSOrderedAscending;
                 } else if (lhs.date < rhs.date) {
                     return NSOrderedDescending;
                 } else {
                     if (lhs.conversationId < rhs.conversationId) {
                         return NSOrderedDescending;
                     } else {
                         return NSOrderedAscending;
                     }
                 }
             }];
             
             SGraphListNode *node = [[SGraphListNode alloc] init];
             node.items = filteredResult;

             if (legacyConstrained && filteredResult.count != 0)
             {
                 NSMutableArray *initialUserIds = [[NSMutableArray alloc] init];
                 for (TGConversation *conversation in filteredResult)
                 {
                     if ([conversation isKindOfClass:[TGConversation class]] && conversation.conversationId > 0 && conversation.conversationId <= INT32_MAX)
                         [initialUserIds addObject:@((int32_t)conversation.conversationId)];
                 }
                 if (initialUserIds.count != 0)
                 {
                     OGRuntimeDispatch(OGRuntimePriorityUtility, ^
                     {
                         std::vector<int> userIds;
                         userIds.reserve(initialUserIds.count);
                         for (NSNumber *userId in initialUserIds)
                             userIds.push_back([userId intValue]);
                         [TGDatabaseInstance() loadUsers:userIds];
                     });
                 }
             }

             if (legacyConstrained)
                 OGDatabaseRuntimeEndStartupCritical();

             bool deferForegroundStartupServices = legacyConstrained && launchAuthorized && !ios6ColdBackgroundLaunch && !ios6ColdBackgroundApplicationLaunch;
             void (^deliverInitialDialogs)(void) = ^
             {
             [ActionStageInstance() dispatchOnStageQueue:^
             {
                 
                 [(id<ASWatcher>)_rootController.dialogListController.dialogListCompanion
                  actorCompleted:ASStatusSuccess
                  path:@"/tg/dialoglist/(0)"
                  result:node];
#if defined(ONEGRAM_DIAGNOSTICS)
                 TGLog(@"STARTUP cached dialogs delivered count=%d at=%.0fms", (int)filteredResult.count, (CFAbsoluteTimeGetCurrent() - mainLaunchTimestamp) * 1000.0);
#endif
#if defined(ONEGRAM_ARMV6)
                 TGDispatchAfter(2.0, dispatch_get_main_queue(), ^
                 {
                     [[TGDatabase instance] markAllPendingMessagesAsFailed];
                 });
#endif
                 
                 if (!deferForegroundStartupServices)
                 {
                     [TGTelegraphInstance.liveLocationManager restoreSessions];
                     [TGTelegraphInstance startPresenceUpdates];
                 }
                 
                 if (TGTelegraphInstance.clientUserId != 0 && TGTelegraphInstance.clientIsActivated)
                 {
                     if (!initialAuthorizationProcessed && !deferForegroundStartupServices)
                     {
                         initialAuthorizationProcessed = true;
                         [TGTelegraphInstance processAuthorizedWithUserId:TGTelegraphInstance.clientUserId clientIsActivated:TGTelegraphInstance.clientIsActivated];
                     }
                     id launchLocalNotification = OGPlatformLocalNotificationFromLaunchOptions(launchOptions);
                     
                     if (launchOptions[UIApplicationLaunchOptionsURLKey] != nil)
                     {
                         OGPlatformDispatchOnMainThread(^
                         {
                             [self handleOpenDocument:launchOptions[UIApplicationLaunchOptionsURLKey] animated:false keepStack:false bundleId:launchOptions[UIApplicationLaunchOptionsSourceApplicationKey]];
                         });
                     }
                     else if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] != nil)
                     {
                         OGPlatformDispatchOnMainThread(^
                         {
                             id nFromId = [launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] objectForKey:@"from_id"];
                             id nChatId = [launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] objectForKey:@"chat_id"];
                             id nContactId = [launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] objectForKey:@"contact_id"];
                             
                             int64_t peerId = 0;
                             
                             if (nFromId != nil && [TGSchema canCreateIntFromObject:nFromId])
                             {
                                 peerId = [TGSchema intFromObject:nFromId];
                             }
                             else if (nChatId != nil && [TGSchema canCreateIntFromObject:nChatId])
                             {
                                 peerId = -[TGSchema intFromObject:nChatId];
                             }
                             else if (nContactId != nil && [TGSchema canCreateIntFromObject:nContactId])
                             {
                                 peerId = [TGSchema intFromObject:nContactId];
                             }
                            
                             if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive)
                                 TGIOS6OpenNotificationPeer(peerId);
                         });
                     }
                     else if (launchLocalNotification != nil)
                     {
                         if ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive)
                         {
                             OGPlatformDispatchOnMainThread(^
                             {
                                 NSDictionary *userInfo = OGPlatformLocalNotificationUserInfo(launchLocalNotification);
                                 id cid = [userInfo objectForKey:@"cid"];
                                 if ([cid respondsToSelector:@selector(longLongValue)])
                                 {
                                     int64_t peerId = [cid longLongValue];
                                     TGIOS6OpenNotificationPeer(peerId);
                                 }
                             });
                         }
                     }
                     
                     TGDispatchOnMainThread(^
                     {
                         if (!TGIsPad())
                         {
                             [TGViewController enableAutorotation];
                             [TGViewController attemptAutorotation];
                         }
                     });
                 }
                 else
                 {
                     [TGTelegraphInstance processUnauthorized];
                     
                     NSDictionary *blockStateDict = [self loadLoginState];
                     
                     dispatch_async(dispatch_get_main_queue(), ^
                     {
                         NSDictionary *stateDict = blockStateDict;
                         
                         int currentDate = ((int)CFAbsoluteTimeGetCurrent());
                         int stateDate = [stateDict[@"date"] intValue];
                         if (currentDate - stateDate > 60 * 60 * 23 && blockStateDict[@"resetAccountState"] == nil)
                         {
                             stateDict = nil;
                             [self resetLoginState];
                         }
                         
                         [self presentLoginController:false animated:false phoneNumber:stateDict[@"phoneNumber"] phoneCode:stateDict[@"phoneCode"] phoneCodeHash:stateDict[@"phoneCodeHash"] codeSentToTelegram:[stateDict[@"codeSentToTelegram"] boolValue] codeSentViaPhone:[stateDict[@"codeSentViaPhone"] boolValue] profileFirstName:stateDict[@"firstName"] profileLastName:stateDict[@"lastName"] resetAccountState:blockStateDict[@"resetAccountState"] termsOfService:blockStateDict[@"termsOfService"]];
                         
                         if (!TGIsPad())
                         {
                             [TGViewController enableAutorotation];
                             [TGViewController attemptAutorotation];
                         }
                     });
                     
                     [[TGDatabase instance] dropDatabase];
                 }
                 
                 if (filteredResult.count > 0)
                 {
                     [TGDatabaseInstance() transactionCalculateUnreadChats];
                 }
                 
                 if (!deferForegroundStartupServices)
                 {
                     if (!initialNetworkingStarted)
                     {
                         initialNetworkingStarted = true;
                         [[TGTelegramNetworking instance] start];
                     }

                     if (ios6ColdBackgroundApplicationLaunch && !ios6ColdBackgroundLaunch)
                         [[TGTelegramNetworking instance] pause];

                     [_finishedLaunching set:[SSignal single:@true]];
                 }

                 if (ios6ColdBackgroundLaunch)
                 {
                     TGDispatchOnMainThread(^{
                         IOS6NotificationProbe(@"LIFECYCLE", @"cold_launch_bootstrap_ready state=%d network=%d",
                                               (int)[UIApplication sharedApplication].applicationState,
                                               [[TGTelegramNetworking instance] isNetworkAvailable] ? 1 : 0);
                         if (_inBackground && [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
                         {
                             [self ios6InstallVoipKeepAliveForApplication:[UIApplication sharedApplication] source:@"cold_launch_ready"];
                             if ([[TGTelegramNetworking instance] isNetworkAvailable])
                             {
                                 int32_t coldBootstrapUptime = (int32_t)OGPlatformSystemUptime();
                                 IOS6NotificationProbe(@"UPDATES", @"catchup_requested source=cold_bootstrap");
                                 [TGTelegraphInstance stateUpdateRequired];
                                 TGDispatchAfter(8.0, dispatch_get_main_queue(), ^
                                 {
                                     if (!_ios6ColdLaunchTaskActive ||
                                         !_inBackground ||
                                         [UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                                     {
                                         [self ios6EndColdLaunchTask];
                                         return;
                                     }

                                     bool receivedPrimaryData = _ios6VoipLastPrimaryReceiveUptime >= coldBootstrapUptime;
                                     if (receivedPrimaryData)
                                     {
                                         [self ios6EndColdLaunchTask];
                                         return;
                                     }

                                     IOS6NotificationProbe(@"SOCKET", @"primary_reset reason=no_cold_bootstrap_rx source=cold_launch");
                                     [[TGTelegramNetworking instance] resume];
                                     [[[TGTelegramNetworking instance] mtProto] requestSecureTransportReset];

                                     TGDispatchAfter(0.35, dispatch_get_main_queue(), ^
                                     {
                                         if (_ios6ColdLaunchTaskActive &&
                                             _inBackground &&
                                             [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
                                         {
                                             IOS6NotificationProbe(@"UPDATES", @"catchup_requested source=cold_bootstrap_reset");
                                             [TGTelegraphInstance stateUpdateRequired];
                                         }
                                     });

                                     TGDispatchAfter(5.0, dispatch_get_main_queue(), ^
                                     {
                                         [self ios6EndColdLaunchTask];
                                     });
                                 });
                             }
                             else
                             {
                                 TGDispatchAfter(12.0, dispatch_get_main_queue(), ^
                                 {
                                     if (_inBackground &&
                                         [UIApplication sharedApplication].applicationState != UIApplicationStateActive &&
                                         [[TGTelegramNetworking instance] isNetworkAvailable])
                                     {
                                         IOS6NotificationProbe(@"UPDATES", @"catchup_requested source=cold_network_recovered");
                                         [TGTelegraphInstance stateUpdateRequired];
                                     }
                                     [self ios6EndColdLaunchTask];
                                 });
                             }
                         }
                         else
                             [self ios6EndColdLaunchTask];
                     });
                 }
                 
                 if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] != nil)
                     [self processPossibleConfigUpdateNotification:launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey]];

                 if (deferForegroundStartupServices)
                 {
                     if (!initialAuthorizationProcessed)
                     {
                         initialAuthorizationProcessed = true;
                         [TGTelegraphInstance processAuthorizedWithUserId:TGTelegraphInstance.clientUserId clientIsActivated:TGTelegraphInstance.clientIsActivated];
                     }
                     if (!initialNetworkingStarted)
                     {
                         initialNetworkingStarted = true;
                         [[TGTelegramNetworking instance] start];
                     }
                     [_finishedLaunching set:[SSignal single:@true]];

                     OGRuntimeDispatchAfter(OGRuntimePriorityMaintenance, 2.0, ^
                     {
                         [ActionStageInstance() dispatchOnStageQueue:^
                         {
                             [TGTelegraphInstance.liveLocationManager restoreSessions];
                             [TGTelegraphInstance startPresenceUpdates];
                         }];
                     });
                 }
                 
             }];
             };

             OGPlatformDispatchOnMainThread(^
             {
#if defined(ONEGRAM_DIAGNOSTICS)
                 TGLog(@"STARTUP dialogs deliver root=%d companion=%@ at=%.0fms", _rootController != nil ? 1 : 0, NSStringFromClass([_rootController.dialogListController.dialogListCompanion class]), (CFAbsoluteTimeGetCurrent() - mainLaunchTimestamp) * 1000.0);
#endif
                 if (_rootController != nil)
                     deliverInitialDialogs();
                 else
                     pendingInitialDialogsDelivery = [deliverInitialDialogs copy];
             });
          }];
    };

    if (deferAuthorizedRoot)
    {
        OGPlatformDispatchAfterCurrentMainRunLoop(^
        {
            CFAbsoluteTime rootPhaseStart = CFAbsoluteTimeGetCurrent();
            _rootController = [[TGRootController alloc] init];
            rootPhaseStart = CFAbsoluteTimeGetCurrent();
            self.window.rootViewController = _rootController;
            if (launchAuthorized && OGPlatformUsesConstrainedBackgroundExecution() && !ios6ColdBackgroundLaunch && !ios6ColdBackgroundApplicationLaunch)
            {
                bool processAuthorization = !initialAuthorizationProcessed;
                bool startNetworking = !initialNetworkingStarted;
                initialAuthorizationProcessed = true;
                initialNetworkingStarted = true;
                if (processAuthorization || startNetworking)
                {
                    [TGTelegramNetworking prepareInstanceWithCompletion:^
                    {
                        if (processAuthorization)
                            [TGTelegraphInstance processAuthorizedWithUserId:TGTelegraphInstance.clientUserId clientIsActivated:TGTelegraphInstance.clientIsActivated];
                        if (startNetworking)
                        {
                            [ActionStageInstance() dispatchOnStageQueue:^
                            {
                                [[TGTelegramNetworking instance] start];
                            }];
                        }
                    }];
                }
            }
            loadInitialDialogs();
            bool deferServicesUntilDialogs = launchAuthorized && OGPlatformUsesConstrainedBackgroundExecution() && !ios6ColdBackgroundLaunch && !ios6ColdBackgroundApplicationLaunch;
            if (pendingInitialDialogsDelivery != nil)
            {
                void (^delivery)(void) = pendingInitialDialogsDelivery;
                pendingInitialDialogsDelivery = nil;
                delivery();
            }
            if (!deferServicesUntilDialogs && launchAuthorized && !initialAuthorizationProcessed)
            {
                initialAuthorizationProcessed = true;
                [TGTelegraphInstance processAuthorizedWithUserId:TGTelegraphInstance.clientUserId clientIsActivated:TGTelegraphInstance.clientIsActivated];
            }
            if (!deferServicesUntilDialogs && launchAuthorized && !initialNetworkingStarted)
            {
                initialNetworkingStarted = true;
                [ActionStageInstance() dispatchOnStageQueue:^
                {
                    [[TGTelegramNetworking instance] start];
                }];
            }
            if (OGPlatformUsesConstrainedBackgroundExecution())
            {
                OGRuntimeDispatchAfter(OGRuntimePriorityMaintenance, 30.0, ^
                {
                    TGPreloadEmojiPack();
                });
            }
            else
            {
                OGRuntimeDispatch(OGRuntimePriorityMaintenance, ^
                {
                    TGPreloadEmojiPack();
                });
            }
        });
    }
    else
    {
        loadInitialDialogs();
    }
    
    _foregroundResumeTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(checkForegroundResume) interval:2.0 repeat:true];
    
    TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
    {
        @try
        {
            [UIView setAnimationsEnabled:true];
            [CATransaction commit];
        }
        @catch (__unused NSException *exception)
        {
        }
    });
    
    if (iosMajorVersion() <= 6)
    {
        OGPlatformBeginReceivingRemoteControlEvents(application);
        [self becomeFirstResponder];
    }
    
    return true;
}

- (void)displayPrivacyNoticeIfNeeded
{
    if (_termsOfServiceDisposable == nil)
        _termsOfServiceDisposable = [[SMetaDisposable alloc] init];
    
    __weak TGAppDelegate *weakSelf = self;
    [_termsOfServiceDisposable setDisposable:[[[TGAccountSignals termsOfServiceUpdate] deliverOn:[SQueue mainQueue]] startWithNext:^(TGTermsOfService *termsOfService)
    {
        __strong TGAppDelegate *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (termsOfService != nil)
        {
            TGGDPRNoticeController *controller = [[TGGDPRNoticeController alloc] initWithTermsOfService:termsOfService];
            controller.presentation = strongSelf.rootController.presentation;
            
            TGNavigationController *navController = [TGNavigationController makeWithRootController:controller];
            navController.restrictLandscape = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
            [strongSelf.rootController presentViewController:navController animated:true completion:nil];
        }
    }]];
}

- (void)presentUpdateAppController:(TGUpdateAppInfo *)updateInfo
{
    TGUpdateAppController *controller = [[TGUpdateAppController alloc] initWithUpdateInfo:updateInfo];
    TGNavigationController *navController = [TGNavigationController makeWithRootController:controller];
    navController.restrictLandscape = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
    [self.rootController presentViewController:navController animated:true completion:nil];
}


- (void)checkForegroundResume
{
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
    {
        if (_passcodeWindow == nil || _passcodeWindow.hidden) {
            [[TGTelegramNetworking maybeInstance] resume];
        }
    }
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)__unused application
{
    TGLog(@"******* Memory warning ******");
    [[TGRemoteImageView sharedCache] clearCache:TGCacheMemory];
    TGClearEmojiImageCache();
}

- (void)applicationWillResignActive:(UIApplication *)__unused application
{
    if (OGPlatformSupportsBackgroundVoipTransport())
        IOS6NotificationProbe(@"LIFECYCLE", @"resign_active state=%d", (int)[UIApplication sharedApplication].applicationState);

    [TGDatabaseInstance() dispatchOnDatabaseThread:^
    {
        [TGDatabaseInstance() transactionCalculateUnreadChats];
        int unreadChatsCount = [TGDatabaseInstance() unreadChatsCount];
        int unreadChannelsCount = [TGDatabaseInstance() unreadChannelsCount];
        int unreadCount = MAX(0, unreadChatsCount) + MAX(0, unreadChannelsCount);
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unreadCount];
        });
    } synchronous:false];
    
    if ([self respondsToSelector:@selector(onBecomeInactive)])
        [self onBecomeInactive];
}

- (bool)isOrWillBeLocked
{
    NSNumber *nDeactivationDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"Passcode_deactivationDate"];
    bool displayByDeactivationTimeout = false;
    if (nDeactivationDate != nil)
    {
        int32_t lockTimeout = [self automaticLockTimeout];
        if (lockTimeout >= 0)
        {
            displayByDeactivationTimeout = [[NSDate date] timeIntervalSince1970] > ([nDeactivationDate doubleValue] + lockTimeout);
        }
    }
    
    return ([self isManuallyLocked] || displayByDeactivationTimeout || (_passcodeWindow != nil && !_passcodeWindow.hidden));
}

- (bool)isDisplayingPasscodeWindow
{
    return _passcodeWindow != nil && !_passcodeWindow.hidden;
}

- (void)displayUnlockWindowIfNeeded
{
    NSNumber *nDeactivationDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"Passcode_deactivationDate"];
    bool displayByDeactivationTimeout = false;
    if (nDeactivationDate != nil)
    {
        int32_t lockTimeout = [self automaticLockTimeout];
        if (lockTimeout >= 0)
        {
            displayByDeactivationTimeout = [[NSDate date] timeIntervalSince1970] > ([nDeactivationDate doubleValue] + lockTimeout);
        }
    }
    
    if ([self isManuallyLocked] || displayByDeactivationTimeout || [self willBeLocked])
    {
        bool isStrong = false;
        if ([TGDatabaseInstance() isPasswordSet:&isStrong])
        {
            if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
                [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait];
            
            TGPasscodeEntryControllerMode mode = (!isStrong) ? TGPasscodeEntryControllerModeVerifySimple : TGPasscodeEntryControllerModeVerifyComplex;
            if (_passcodeWindow == nil)
            {
                CGRect passcodeFrame = [UIScreen mainScreen].bounds;
                if (TGIsPad())
                    passcodeFrame = [UIScreen mainScreen].bounds;
                else
                    passcodeFrame = (CGRect){CGPointZero, TGScreenSize()};
                _passcodeWindow = [[TGPasscodeWindow alloc] initWithFrame:passcodeFrame];
                NSInteger initWithNumberOfInvalidAttempts = [[TGAppDelegateUserDefaultsCompat() objectForKey:@"Passcode_invalidAttempts"] integerValue];
                NSTimeInterval invalidAttemptDate = [[TGAppDelegateUserDefaultsCompat() objectForKey:@"Passcode_invalidAttemptDate"] doubleValue];
                TGPasscodeEntryController *controller = [[TGPasscodeEntryController alloc] initWithContext:[TGLegacyComponentsContext shared] style:TGPasscodeEntryControllerStyleTranslucent mode:mode cancelEnabled:false allowTouchId:[TGPasscodeSettingsController enableTouchId] attemptData:[[TGPasscodeEntryAttemptData alloc] initWithNumberOfInvalidAttempts:initWithNumberOfInvalidAttempts dateOfLastInvalidAttempt:invalidAttemptDate] completion:^(NSString *passcode)
                {
                    if ([TGDatabaseInstance() verifyPassword:passcode])
                    {
                        TGDispatchOnMainThread(^
                        {
                            [self setIsManuallyLocked:false];
                            
                            [_passcodeWindow endEditing:true];
                            TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                            [controller prepareForDisappear];

                            [UIView animateWithDuration:0.3 delay:0 options:[TGViewController preferredAnimationCurve] << 16 animations:^
                            {
                                _passcodeWindow.frame = CGRectOffset(_passcodeWindow.frame, 0.0f, _passcodeWindow.frame.size.height);
                            } completion:^(__unused BOOL finished)
                            {
                                _passcodeWindow.hidden = true;
                            }];
                            
                            if (self.rootController.presentedViewController != nil)
                                [self.rootController.presentedViewController viewDidAppear:false];
                            
                            [TGEmbedPIPController restore];
                            [self resetRemoteDeviceLocked];
                            
                            if (self.onSuccessfulAuthorization != nil)
                            {
                                self.onSuccessfulAuthorization();
                                self.onSuccessfulAuthorization = nil;
                            }
                        });
                    }
                }];
                controller.updateAttemptData = ^(TGPasscodeEntryAttemptData *attemptData) {
                    [TGAppDelegateUserDefaultsCompat() setObject:@(attemptData.numberOfInvalidAttempts) forKey:@"Passcode_invalidAttempts"];
                    [TGAppDelegateUserDefaultsCompat() setObject:@(attemptData.dateOfLastInvalidAttempt) forKey:@"Passcode_invalidAttemptDate"];
                };
                controller.touchIdCompletion = ^
                {
                    TGDispatchOnMainThread(^
                    {
                        [self setIsManuallyLocked:false];
                        
                        [_passcodeWindow endEditing:true];
                        TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                        [controller prepareForDisappear];
                        
                        [UIView animateWithDuration:0.3 delay:0 options:[TGViewController preferredAnimationCurve] << 16 animations:^
                        {
                            _passcodeWindow.frame = CGRectOffset(_passcodeWindow.frame, 0.0f, _passcodeWindow.frame.size.height);
                        } completion:^(__unused BOOL finished)
                        {
                            _passcodeWindow.hidden = true;
                        }];
                        
                        if (self.rootController.presentedViewController != nil)
                            [self.rootController.presentedViewController viewDidAppear:false];

                        [TGEmbedPIPController restore];
                        [self resetRemoteDeviceLocked];
                        
                        if (self.onSuccessfulAuthorization != nil)
                        {
                            self.onSuccessfulAuthorization();
                            self.onSuccessfulAuthorization = nil;
                        }
                    });
                };
                controller.checkCurrentPasscodeAsync = ^(NSString *passcode, void (^result)(bool))
                {
                    [TGDatabaseInstance() verifyPassword:passcode completion:result];
                };
                _passcodeWindow.windowLevel = UIWindowLevelStatusBar - 0.0001f;
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller]];
                navigationController.restrictLandscape = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone;
                _passcodeWindow.rootViewController = navigationController;
                _passcodeWindow.hidden = false;
                [_passcodeWindow makeKeyAndVisible];
                [controller prepareForAppear];
                
                if (!TGIsPad())
                {
                    navigationController.view.frame = (CGRect){CGPointZero, TGScreenSize()};;
                    controller.view.frame = (CGRect){CGPointZero, TGScreenSize()};;
                }
                
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                    [controller refreshTouchId];
            }
            else if (_passcodeWindow.hidden)
            {
                TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                controller.checkCurrentPasscodeAsync = ^(NSString *passcode, void (^result)(bool))
                {
                    [TGDatabaseInstance() verifyPassword:passcode completion:result];
                };
                controller.completion = ^(NSString *passcode)
                {
                    if ([TGDatabaseInstance() verifyPassword:passcode])
                    {
                        TGDispatchOnMainThread(^
                        {
                            [self setIsManuallyLocked:false];
                            
                            [_passcodeWindow endEditing:true];
                            TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                            [controller prepareForDisappear];
                            
                            [UIView animateWithDuration:0.3 delay:0 options:[TGViewController preferredAnimationCurve] << 16 animations:^
                             {
                                 _passcodeWindow.frame = CGRectOffset(_passcodeWindow.frame, 0.0f, _passcodeWindow.frame.size.height);
                             } completion:^(__unused BOOL finished)
                             {
                                 _passcodeWindow.hidden = true;
                             }];
                            
                            if (self.rootController.presentedViewController != nil)
                                [self.rootController.presentedViewController viewDidAppear:false];
                            
                            [TGEmbedPIPController restore];
                            [self resetRemoteDeviceLocked];
                            
                            if (self.onSuccessfulAuthorization != nil)
                            {
                                self.onSuccessfulAuthorization();
                                self.onSuccessfulAuthorization = nil;
                            }
                        });
                    }
                };
                controller.touchIdCompletion = ^
                {
                    TGDispatchOnMainThread(^
                    {
                        [self setIsManuallyLocked:false];
                        
                        [_passcodeWindow endEditing:true];
                        TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
                        [controller prepareForDisappear];
                        
                        [UIView animateWithDuration:0.3 delay:0 options:[TGViewController preferredAnimationCurve] << 16 animations:^
                        {
                            _passcodeWindow.frame = CGRectOffset(_passcodeWindow.frame, 0.0f, _passcodeWindow.frame.size.height);
                        } completion:^(__unused BOOL finished)
                        {
                            _passcodeWindow.hidden = true;
                        }];
                        
                        if (self.rootController.presentedViewController != nil)
                            [self.rootController.presentedViewController viewDidAppear:false];
                        
                        [TGEmbedPIPController restore];
                        [self resetRemoteDeviceLocked];
                        
                        if (self.onSuccessfulAuthorization != nil)
                        {
                            self.onSuccessfulAuthorization();
                            self.onSuccessfulAuthorization = nil;
                        }
                    });
                };
                [controller resetMode:mode];
                if (TGIsPad())
                    _passcodeWindow.frame = [UIScreen mainScreen].bounds;
                else
                    _passcodeWindow.frame = (CGRect){CGPointZero, TGScreenSize()};
                _passcodeWindow.hidden = false;
                [_passcodeWindow makeKeyAndVisible];
                [controller prepareForAppear];
                
                controller.allowTouchId = [TGPasscodeSettingsController enableTouchId];
                
                if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
                    [controller refreshTouchId];
            }
            
            [TGEmbedPIPController hide];
        }
    }
}

- (void)displayBlurredContentIfNeeded {
    if (_blurredContentWindow == nil && ![TGUpdateConfigActor cachedExperimentalPasscodeBlurDisabled]) {
        _blurredContentWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        if (iosMajorVersion() >= 7) {
            CGSize size = _blurredContentWindow.bounds.size;
            UIGraphicsBeginImageContextWithOptions(CGSizeMake((int)(size.width / 2.0f), (int)(size.height / 2.0f)), true, 1.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextScaleCTM(context, 0.5f, 0.5f);
            [self.window drawViewHierarchyInRect:self.window.bounds afterScreenUpdates:false];
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            image = [image applyScreenshotEffect];
            UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
            imageView.frame = CGRectMake(0.0f, 0.0f, size.width, size.height);
            imageView.contentMode = UIViewContentModeScaleToFill;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_blurredContentWindow addSubview:imageView];
        }
        
        _blurredContentWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _blurredContentWindow.windowLevel = 10000100.0f - 0.1f;
        _blurredContentWindow.backgroundColor = [UIColor whiteColor];
        _blurredContentWindow.hidden = false;
        
    }
}

- (void)hideBlurredContentIfNeeded {
    if (_blurredContentWindow != nil) {
        _blurredContentWindow.hidden = true;
        _blurredContentWindow = nil;
    }
}

- (void)applicationSignificantTimeChange:(UIApplication *)__unused application
{
    TGLog(@"***** Significant time change");
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [ActionStageInstance() dispatchResource:@"/system/significantTimeChange" resource:nil];
    }];
    
    [TGDatabaseInstance() processAndScheduleSelfDestruct];
    [TGDatabaseInstance() processAndScheduleMediaCleanup];
    [TGDatabaseInstance() processAndScheduleMute];
}

- (SSignal *)isActive
{
    return _isActive.signal;
}

- (NSTimeInterval)ios6VoipHealthCheckInterval
{
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSHourCalendarUnit fromDate:[NSDate date]];
    NSInteger hour = [components hour];
    return (hour >= 23 || hour < 7) ? 60.0 * 60.0 : 30.0 * 60.0;
}

- (void)ios6PrimaryTransportReceivedData:(NSNotification *)__unused notification
{
    _ios6VoipLastPrimaryReceiveUptime = (int32_t)OGPlatformSystemUptime();
}

- (void)ios6PerformScheduledVoipHealthCheck
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NSTimeInterval healthCheckInterval = [self ios6VoipHealthCheckInterval];
    if (_ios6VoipLastScheduledHealthCheckTime > 0.0 && now - _ios6VoipLastScheduledHealthCheckTime + 1.0 < healthCheckInterval)
        return;

    _ios6VoipLastScheduledHealthCheckTime = now;
    [self ios6PerformVoipHealthCheck];
}

- (BOOL)ios6InstallVoipKeepAliveForApplication:(UIApplication *)application source:(NSString *)source
{
    if (!OGPlatformSupportsBackgroundVoipTransport() ||
        _disableBackgroundMode ||
        application.applicationState == UIApplicationStateActive)
    {
        return false;
    }

    [self ios6CancelVoipHealthCheck];
    _ios6VoipLastProactiveTransportRefreshTime = CFAbsoluteTimeGetCurrent();

    UIRemoteNotificationType systemTypes = UIRemoteNotificationTypeNone;
    bool privateNotificationsEnabled = false;
    bool groupNotificationsEnabled = false;
    _ios6NotificationTransportAllowedForBackgroundSession = [self ios6NotificationTransportAllowedWithSystemTypes:&systemTypes privateEnabled:&privateNotificationsEnabled groupEnabled:&groupNotificationsEnabled];

    if (!_ios6NotificationTransportAllowedForBackgroundSession)
    {
        [self ios6StopNotificationTransport];
        return false;
    }

    _ios6VoipLastScheduledHealthCheckTime = CFAbsoluteTimeGetCurrent();

    BOOL keepAliveInstalled = TGIOS3SetKeepAliveTimeout(application, 600.0, ^
    {
        IOS6NotificationProbe(@"WAKE", @"keepalive_callback state=%d remaining=%.1f thread=%@",
                              (int)[UIApplication sharedApplication].applicationState,
                              TGIOS3BackgroundTimeRemaining([UIApplication sharedApplication]),
                              [NSThread isMainThread] ? @"main" : @"worker");
        if ([NSThread isMainThread])
            [self ios6PerformScheduledVoipHealthCheck];
        else
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self ios6PerformScheduledVoipHealthCheck];
            });
    });
    IOS6NotificationProbe(@"LIFECYCLE", @"keepalive_registered result=%d scheduler=600 healthInterval=%d source=%@",
                          keepAliveInstalled ? 1 : 0, (int)[self ios6VoipHealthCheckInterval], source ?: @"unknown");
    return keepAliveInstalled;
}

- (void)ios6EndColdLaunchTask
{
    if (!_ios6ColdLaunchTaskActive)
        return;

    TGIOS3BackgroundTaskIdentifier identifier = _ios6ColdLaunchTaskIdentifier;
    _ios6ColdLaunchTaskIdentifier = TGIOS3BackgroundTaskInvalid;
    _ios6ColdLaunchTaskActive = false;
    if (identifier != TGIOS3BackgroundTaskInvalid)
    {
        IOS6NotificationProbe(@"LEASE", @"cold_launch_end id=%d", (int)identifier);
        TGIOS3EndBackgroundTask([UIApplication sharedApplication], identifier);
    }
}

- (void)ios6CancelVoipHealthCheck
{
    _ios6VoipHealthCheckGeneration++;
    _ios6VoipHealthCheckAttempt = 0;
    _ios6VoipHealthCheckPending = false;
    if (_ios6VoipHealthCheckDisposable != nil)
        [_ios6VoipHealthCheckDisposable setDisposable:nil];
    [self ios6EndVoipHealthCheckTask];
}

- (bool)ios6NotificationTransportAllowedWithSystemTypes:(UIRemoteNotificationType *)systemTypes privateEnabled:(bool *)privateEnabled groupEnabled:(bool *)groupEnabled
{
    UIRemoteNotificationType enabledTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];

    if (!TGIOS6BackgroundNotificationsEnabled())
    {
        if (systemTypes != NULL)
            *systemTypes = enabledTypes;
        if (privateEnabled != NULL)
            *privateEnabled = false;
        if (groupEnabled != NULL)
            *groupEnabled = false;

        return TGTelegraphInstance.callManager.hasActiveCall;
    }

    if (!TGIOS6NotificationSettingsGateEnabled)
    {
        if (systemTypes != NULL)
            *systemTypes = enabledTypes;
        if (privateEnabled != NULL)
            *privateEnabled = true;
        if (groupEnabled != NULL)
            *groupEnabled = true;
        return true;
    }

    bool systemEnabled = (enabledTypes & (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)) != UIRemoteNotificationTypeNone;

    if (TGTelegraphInstance.callManager.hasActiveCall)
    {
        if (systemTypes != NULL)
            *systemTypes = enabledTypes;
        if (privateEnabled != NULL)
            *privateEnabled = false;
        if (groupEnabled != NULL)
            *groupEnabled = false;
        return true;
    }

    if (!systemEnabled)
    {
        if (systemTypes != NULL)
            *systemTypes = enabledTypes;
        if (privateEnabled != NULL)
            *privateEnabled = false;
        if (groupEnabled != NULL)
            *groupEnabled = false;
        return false;
    }

    NSNumber *privateMuteUntil = nil;
    NSNumber *groupMuteUntil = nil;
    [TGDatabaseInstance() loadPeerNotificationSettings:INT_MAX - 1 soundId:NULL muteUntil:&privateMuteUntil previewText:NULL messagesMuted:NULL notFound:NULL];
    [TGDatabaseInstance() loadPeerNotificationSettings:INT_MAX - 2 soundId:NULL muteUntil:&groupMuteUntil previewText:NULL messagesMuted:NULL notFound:NULL];

    bool privateCategoryEnabled = privateMuteUntil == nil || privateMuteUntil.longLongValue < INT_MAX;
    bool groupCategoryEnabled = groupMuteUntil == nil || groupMuteUntil.longLongValue < INT_MAX;

    if (systemTypes != NULL)
        *systemTypes = enabledTypes;
    if (privateEnabled != NULL)
        *privateEnabled = privateCategoryEnabled;
    if (groupEnabled != NULL)
        *groupEnabled = groupCategoryEnabled;

    return systemEnabled && (privateCategoryEnabled || groupCategoryEnabled);
}

- (void)ios6StopNotificationTransport
{
    if (TGTelegraphInstance.callManager.hasActiveCall)
    {
        [self ios6CancelVoipHealthCheck];
        return;
    }

    _ios6NotificationTransportAllowedForBackgroundSession = false;
    TGIOS3ClearKeepAliveTimeout([UIApplication sharedApplication]);
    [self ios6CancelVoipHealthCheck];
    [self ios6EndColdLaunchTask];
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive)
        [[TGTelegramNetworking instance] pause];
}

- (void)applyIOS6BackgroundNotificationsEnabled:(bool)enabled
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:TGIOS6BackgroundNotificationsEnabledKey];
    [defaults synchronize];

    UIApplication *application = [UIApplication sharedApplication];
    if (!enabled)
    {
        if ([application respondsToSelector:@selector(cancelAllLocalNotifications)])
            [application performSelector:@selector(cancelAllLocalNotifications)];
        application.applicationIconBadgeNumber = 0;
        [self ios6StopNotificationTransport];
    }
    else
    {
        [self ios6RegisterLocalNotificationSettings];
        if (OGPlatformSupportsBackgroundVoipTransport() &&
            application.applicationState != UIApplicationStateActive)
        {
            [[TGTelegramNetworking instance] resume];
            [self ios6InstallVoipKeepAliveForApplication:application source:@"settings_enabled"];
        }
    }
}

- (void)ios6EndVoipHealthCheckTask
{
    if (!_ios6VoipHealthCheckTaskActive)
        return;

    TGIOS3BackgroundTaskIdentifier identifier = _ios6VoipHealthCheckTaskIdentifier;
    _ios6VoipHealthCheckTaskIdentifier = TGIOS3BackgroundTaskInvalid;
    _ios6VoipHealthCheckTaskActive = false;
    if (identifier != TGIOS3BackgroundTaskInvalid)
    {
        IOS6NotificationProbe(@"LEASE", @"health_task_end id=%d", (int)identifier);
        TGIOS3EndBackgroundTask([UIApplication sharedApplication], identifier);
    }
}

- (void)ios6FinishVoipHealthCheck:(int32_t)generation attempt:(int32_t)attempt success:(bool)success reason:(NSString *)reason
{
    if (generation != _ios6VoipHealthCheckGeneration ||
        attempt != _ios6VoipHealthCheckAttempt ||
        !_ios6VoipHealthCheckPending)
    {
        return;
    }

    if (!success && _ios6VoipLastPrimaryReceiveUptime > 0)
    {
        int32_t receiveAge = MAX(0, (int32_t)OGPlatformSystemUptime() - _ios6VoipLastPrimaryReceiveUptime);
        if (receiveAge <= 6 && [[TGTelegramNetworking instance] isNetworkAvailable])
        {
            success = true;
            reason = @"recent_rx";
        }
    }

    IOS6NotificationProbe(@"HEALTH", @"probe_result generation=%d attempt=%d success=%d reason=%@ network=%d connecting=%d updating=%d",
                          generation, attempt, success ? 1 : 0, reason ?: @"none",
                          [[TGTelegramNetworking instance] isNetworkAvailable] ? 1 : 0,
                          [[TGTelegramNetworking instance] isConnecting] ? 1 : 0,
                          [[TGTelegramNetworking instance] isUpdating] ? 1 : 0);

    if (_ios6VoipHealthCheckDisposable != nil)
        [_ios6VoipHealthCheckDisposable setDisposable:nil];

    UIApplication *application = [UIApplication sharedApplication];
    if (!_inBackground || _disableBackgroundMode || application.applicationState == UIApplicationStateActive)
    {
        [self ios6CancelVoipHealthCheck];
        return;
    }

    if (success)
    {
        _ios6VoipHealthCheckPending = false;

        if (attempt != 0)
        {
            _ios6VoipLastProactiveTransportRefreshTime = CFAbsoluteTimeGetCurrent();
            IOS6NotificationProbe(@"UPDATES", @"catchup_requested source=recovered_transport");
            [TGTelegraphInstance stateUpdateRequired];

            TGDispatchAfter(1.5, dispatch_get_main_queue(), ^
            {
                [self ios6EndVoipHealthCheckTask];
            });
            return;
        }

        IOS6NotificationProbe(@"UPDATES", @"catchup_requested source=long_silence");
        [TGTelegraphInstance stateUpdateRequired];
        TGDispatchAfter(1.5, dispatch_get_main_queue(), ^
        {
            [self ios6EndVoipHealthCheckTask];
        });
        return;
    }

    if (attempt != 0)
    {
        _ios6VoipHealthCheckPending = false;
        TGLog(@"PUSH healthCheck recovery failed (%@)", reason ?: @"unknown");
        [self ios6EndVoipHealthCheckTask];
        return;
    }

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    static const CFTimeInterval minimumResetInterval = 120.0;
    if (_ios6VoipLastTransportResetTime > 0.0 && now - _ios6VoipLastTransportResetTime < minimumResetInterval)
    {
        _ios6VoipHealthCheckPending = false;
        IOS6NotificationProbe(@"HEALTH", @"reset_throttled reason=%@ age=%.1f", reason ?: @"failed", now - _ios6VoipLastTransportResetTime);
        [self ios6EndVoipHealthCheckTask];
        return;
    }

    _ios6VoipLastTransportResetTime = now;
    IOS6NotificationProbe(@"SOCKET", @"primary_reset reason=%@ source=health", reason ?: @"failed");
    _ios6VoipHealthCheckAttempt = 1;

    [[TGTelegramNetworking instance] resume];
    [[[TGTelegramNetworking instance] mtProto] requestSecureTransportReset];

    TGDispatchAfter(0.35, dispatch_get_main_queue(), ^
    {
        if (generation == _ios6VoipHealthCheckGeneration &&
            _ios6VoipHealthCheckPending &&
            _ios6VoipHealthCheckAttempt == 1 &&
            _inBackground &&
            !_disableBackgroundMode &&
            [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
        {
            [self ios6StartVoipHealthProbe:generation attempt:1 timeout:4.0];
        }
    });
}

- (void)ios6StartVoipHealthProbe:(int32_t)generation attempt:(int32_t)attempt timeout:(NSTimeInterval)timeout
{
    UIApplication *application = [UIApplication sharedApplication];
    if (generation != _ios6VoipHealthCheckGeneration ||
        !_ios6VoipHealthCheckPending ||
        !_inBackground ||
        _disableBackgroundMode ||
        application.applicationState == UIApplicationStateActive)
    {
        return;
    }

    _ios6VoipHealthCheckAttempt = attempt;

    IOS6NotificationProbe(@"HEALTH", @"probe_start generation=%d attempt=%d timeout=%.1f network=%d connecting=%d updating=%d",
                          generation, attempt, timeout,
                          [[TGTelegramNetworking instance] isNetworkAvailable] ? 1 : 0,
                          [[TGTelegramNetworking instance] isConnecting] ? 1 : 0,
                          [[TGTelegramNetworking instance] isUpdating] ? 1 : 0);

    if (_ios6VoipHealthCheckDisposable == nil)
        _ios6VoipHealthCheckDisposable = [[SMetaDisposable alloc] init];

    TLRPCping$ping *ping = [[TLRPCping$ping alloc] init];
    ping.ping_id = (((int64_t)arc4random()) << 32) | (int64_t)arc4random();

    id<SDisposable> disposable = [[[[TGTelegramNetworking instance] requestSignal:ping requestClass:(TGRequestClassHidesActivityIndicator | TGRequestClassFailOnServerErrors | TGRequestClassFailOnFloodErrors | TGRequestClassFailOnServerErrorsImmediately)] take:1] startWithNext:^(__unused id next)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self ios6FinishVoipHealthCheck:generation attempt:attempt success:true reason:nil];
        });
    } error:^(__unused id error)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self ios6FinishVoipHealthCheck:generation attempt:attempt success:false reason:@"error"];
        });
    } completed:^
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self ios6FinishVoipHealthCheck:generation attempt:attempt success:true reason:nil];
        });
    }];
    [_ios6VoipHealthCheckDisposable setDisposable:disposable];

    TGDispatchAfter(timeout, dispatch_get_main_queue(), ^
    {
        [self ios6FinishVoipHealthCheck:generation attempt:attempt success:false reason:@"timeout"];
    });
}

- (void)ios6PerformVoipHealthCheck
{
    UIApplication *application = [UIApplication sharedApplication];
    if (!_inBackground || _disableBackgroundMode || application.applicationState == UIApplicationStateActive)
        return;

    _ios6NotificationTransportAllowedForBackgroundSession = [self ios6NotificationTransportAllowedWithSystemTypes:NULL privateEnabled:NULL groupEnabled:NULL];
    IOS6NotificationProbe(@"WAKE", @"health_begin state=%d network=%d connecting=%d updating=%d allowed=%d",
                          (int)application.applicationState,
                          [[TGTelegramNetworking instance] isNetworkAvailable] ? 1 : 0,
                          [[TGTelegramNetworking instance] isConnecting] ? 1 : 0,
                          [[TGTelegramNetworking instance] isUpdating] ? 1 : 0,
                          _ios6NotificationTransportAllowedForBackgroundSession ? 1 : 0);
    if (!_ios6NotificationTransportAllowedForBackgroundSession)
    {
        [self ios6StopNotificationTransport];
        return;
    }

    int32_t currentUptime = (int32_t)OGPlatformSystemUptime();
    int32_t receiveAge = _ios6VoipLastPrimaryReceiveUptime > 0 ? MAX(0, currentUptime - _ios6VoipLastPrimaryReceiveUptime) : INT_MAX;
    if ([[TGTelegramNetworking instance] isNetworkAvailable] &&
        ![[TGTelegramNetworking instance] isConnecting] &&
        receiveAge <= (int32_t)[self ios6VoipHealthCheckInterval])
    {
        IOS6NotificationProbe(@"HEALTH", @"probe_skipped recentRx=%d", receiveAge);
        return;
    }

    [self ios6CancelVoipHealthCheck];
    _ios6VoipHealthCheckPending = true;
    int32_t generation = _ios6VoipHealthCheckGeneration;

    __block TGIOS3BackgroundTaskIdentifier taskIdentifier = TGIOS3BackgroundTaskInvalid;
    taskIdentifier = TGIOS3BeginBackgroundTask(application, ^
    {
        IOS6NotificationProbe(@"LEASE", @"health_task_expiration_handler id=%d", (int)taskIdentifier);
        if ([NSThread isMainThread])
        {
            if (_ios6VoipHealthCheckTaskActive && _ios6VoipHealthCheckTaskIdentifier == taskIdentifier)
                [self ios6CancelVoipHealthCheck];
        }
        else
        {
            dispatch_sync(dispatch_get_main_queue(), ^
            {
                if (_ios6VoipHealthCheckTaskActive && _ios6VoipHealthCheckTaskIdentifier == taskIdentifier)
                    [self ios6CancelVoipHealthCheck];
            });
        }
    });
    if (taskIdentifier != TGIOS3BackgroundTaskInvalid)
    {
        _ios6VoipHealthCheckTaskIdentifier = taskIdentifier;
        _ios6VoipHealthCheckTaskActive = true;
        IOS6NotificationProbe(@"LEASE", @"health_task_begin id=%d remaining=%.1f", (int)taskIdentifier, TGIOS3BackgroundTimeRemaining(application));
    }
    else
        IOS6NotificationProbe(@"LEASE", @"health_task_denied remaining=%.1f", TGIOS3BackgroundTimeRemaining(application));

    [[TGTelegramNetworking instance] resume];

    [self ios6StartVoipHealthProbe:generation attempt:0 timeout:4.0];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
#if defined(DEBUG) || defined(INTERNAL_RELEASE)
    TGLogSynchronize();
#endif
    
    bool voipTransport = OGPlatformSupportsBackgroundVoipTransport();
    if (voipTransport && _ios6BackgroundLifecycleEntered)
        return;

    if (voipTransport)
    {
        _ios6BackgroundLifecycleEntered = true;
        IOS6NotificationProbe(@"LIFECYCLE", @"background_enter state=%d remaining=%.1f", (int)application.applicationState, TGIOS3BackgroundTimeRemaining(application));
    }

    _inBackground = true;

    _ios6NotificationTransportAllowedForBackgroundSession = TGIOS6BackgroundNotificationsEnabled() || TGTelegraphInstance.callManager.hasActiveCall;

    if (iosMajorVersion() <= 6)
    {
        OGPlatformBeginReceivingRemoteControlEvents(application);
        [self becomeFirstResponder];
    }
    if (voipTransport)
    {
        [self ios6InstallVoipKeepAliveForApplication:application source:@"background_enter"];
        if (_ios6NotificationTransportAllowedForBackgroundSession)
            [[TGTelegramNetworking instance] resume];
    }
    
    [_isActive set:[SSignal single:@false]];
    
    self.onSuccessfulAuthorization = nil;
    self.onSuccessfulLogin = nil;
    
    if (_backgroundTaskExpirationTimer != nil && [_backgroundTaskExpirationTimer isValid])
    {
        [_backgroundTaskExpirationTimer invalidate];
        _backgroundTaskExpirationTimer = nil;
    }
    
    if (_backgroundTaskIdentifier != TGIOS3BackgroundTaskInvalid)
    {
        TGIOS3BackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
        _backgroundTaskIdentifier = TGIOS3BackgroundTaskInvalid;
        TGIOS3EndBackgroundTask(application, identifier);
    }

    _backgroundTaskIdentifier = TGIOS3BeginBackgroundTask(application, ^
    {
        if (voipTransport)
            IOS6NotificationProbe(@"LEASE", @"initial_task_expiration_handler id=%d", (int)_backgroundTaskIdentifier);
        if (_backgroundTaskExpirationTimer != nil)
        {
            if ([_backgroundTaskExpirationTimer isValid])
                [_backgroundTaskExpirationTimer invalidate];
            _backgroundTaskExpirationTimer = nil;
        }
        
        TGIOS3BackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
        _backgroundTaskIdentifier = TGIOS3BackgroundTaskInvalid;
        if (identifier != TGIOS3BackgroundTaskInvalid)
            TGIOS3EndBackgroundTask(application, identifier);
    });
    if (voipTransport)
        IOS6NotificationProbe(@"LEASE", @"initial_task_begin id=%d remaining=%.1f", (int)_backgroundTaskIdentifier, TGIOS3BackgroundTimeRemaining(application));
    
    _enteredBackgroundTime = CFAbsoluteTimeGetCurrent();
    
    double systemRemainingTime = TGIOS3BackgroundTimeRemaining(application);
    
    double maxBackgroundTime = MAX(15.0, MIN(40.0, TGIOS3BackgroundTimeRemaining(application) - 0.5 * 60.0));
    if (_disableBackgroundMode || (voipTransport && !_ios6NotificationTransportAllowedForBackgroundSession && !TGTelegraphInstance.callManager.hasActiveCall))
        maxBackgroundTime = 1;
    
#ifdef DEBUG
#endif
    
    TGLog(@"Background time remaining: %d m %d s", (int)(maxBackgroundTime / 60.0), ((int)maxBackgroundTime) % 60);
    
    _backgroundTaskExpirationTimer = [NSTimer timerWithTimeInterval:MAX(maxBackgroundTime - 3.5, 1.0) target:self selector:@selector(backgroundExpirationTimerEvent:) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:_backgroundTaskExpirationTimer forMode:NSRunLoopCommonModes];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [ActionStageInstance() removeWatcher:TGTelegraphInstance fromPath:@"/tg/service/updatepresence/(online)"];
        [ActionStageInstance() removeWatcher:TGTelegraphInstance fromPath:@"/tg/service/updatepresence/(offline)"];
        [ActionStageInstance() requestActor:@"/tg/service/updatepresence/(timeout)" options:nil watcher:TGTelegraphInstance];
    }];
    
    _didBecomeInactive = true;
    
    if ([self isManuallyLocked]) {
        [self displayUnlockWindowIfNeeded];
    }
    
    if ([self respondsToSelector:@selector(onBecomeInactive)])
        [self onBecomeInactive];
}

- (void)backgroundExpirationTimerEvent:(NSTimer *)__unused timer
{
    bool voipTransport = OGPlatformSupportsBackgroundVoipTransport();
    if (TGIOS6NotificationSettingsGateEnabled && voipTransport && _ios6NotificationTransportAllowedForBackgroundSession && !TGTelegraphInstance.callManager.hasActiveCall)
    {
        UIRemoteNotificationType enabledTypes = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        if ((enabledTypes & (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)) == UIRemoteNotificationTypeNone)
        {
            _ios6NotificationTransportAllowedForBackgroundSession = false;
            TGIOS3ClearKeepAliveTimeout([UIApplication sharedApplication]);
        }
    }
    bool preserveIos6NotificationTransport = voipTransport && !_disableBackgroundMode && _ios6NotificationTransportAllowedForBackgroundSession;
    if (voipTransport)
        IOS6NotificationProbe(@"LIFECYCLE", @"initial_task_expire preserve=%d network=%d connecting=%d updating=%d",
                              preserveIos6NotificationTransport ? 1 : 0,
                              [[TGTelegramNetworking instance] isNetworkAvailable] ? 1 : 0,
                              [[TGTelegramNetworking instance] isConnecting] ? 1 : 0,
                              [[TGTelegramNetworking instance] isUpdating] ? 1 : 0);
    if (preserveIos6NotificationTransport)
    {
    }
    else if (!voipTransport || !TGTelegraphInstance.callManager.hasActiveCall)
    {
        [[TGTelegramNetworking instance] pause];
    }
    
    _backgroundTaskExpirationTimer = nil;
    
    TGIOS3BackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
    
    _backgroundTaskIdentifier = TGIOS3BackgroundTaskInvalid;
    if (identifier == TGIOS3BackgroundTaskInvalid)
        TGLog(@"***** Strange. *****");
    
    if (identifier != TGIOS3BackgroundTaskInvalid)
    {
        TGDispatchAfter(3.0, dispatch_get_main_queue(), ^
        {
            TGIOS3EndBackgroundTask([UIApplication sharedApplication], identifier);
        });
    }
}

- (bool)backgroundTaskOngoing
{
    return (_backgroundTaskExpirationTimer != nil);
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    if (OGPlatformSupportsBackgroundVoipTransport())
        IOS6NotificationProbe(@"LIFECYCLE", @"foreground_enter network=%d connecting=%d updating=%d",
                              [[TGTelegramNetworking instance] isNetworkAvailable] ? 1 : 0,
                              [[TGTelegramNetworking instance] isConnecting] ? 1 : 0,
                              [[TGTelegramNetworking instance] isUpdating] ? 1 : 0);

    _enteringForeground = true;

    if (OGPlatformSupportsBackgroundVoipTransport())
    {
        _ios6BackgroundLifecycleEntered = false;
        TGIOS3ClearKeepAliveTimeout(application);
        [self ios6CancelVoipHealthCheck];
        [self ios6EndColdLaunchTask];
        _ios6VoipLastProactiveTransportRefreshTime = 0.0;
        _ios6VoipLastScheduledHealthCheckTime = 0.0;
        _ios6NotificationTransportAllowedForBackgroundSession = false;
        [[TGTelegramNetworking instance] resume];
        [[[TGTelegramNetworking instance] mtProto] requestSecureTransportReset];
    }
    dispatch_async(dispatch_get_main_queue(), ^
    {
        _inBackground = false;
        _enteringForeground = false;
    });
    
    if (_backgroundTaskIdentifier != TGIOS3BackgroundTaskInvalid)
    {
        TGIOS3BackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
        _backgroundTaskIdentifier = TGIOS3BackgroundTaskInvalid;
        TGIOS3EndBackgroundTask(application, identifier);
    }
    if (_backgroundTaskExpirationTimer != nil)
    {
        if ([_backgroundTaskExpirationTimer isValid])
            [_backgroundTaskExpirationTimer invalidate];
        _backgroundTaskExpirationTimer = nil;
    }
    
    if (_callingWebView != nil)
    {
        [_callingWebView stopLoading];
        _callingWebView = nil;
    }
    
    [[TGTelegramNetworking instance] resume];
    [TGDatabaseInstance() processAndScheduleMute];
}

- (void)applicationDidBecomeActive:(UIApplication *)__unused application
{
    OGRuntimeConfigureMainThread();
    if (OGPlatformSupportsBackgroundVoipTransport())
    {
        IOS6NotificationProbe(@"LIFECYCLE", @"became_active network=%d connecting=%d updating=%d",
                              [[TGTelegramNetworking instance] isNetworkAvailable] ? 1 : 0,
                              [[TGTelegramNetworking instance] isConnecting] ? 1 : 0,
                              [[TGTelegramNetworking instance] isUpdating] ? 1 : 0);
        [self ios6CancelVoipHealthCheck];
        [TGDatabaseInstance() ios6FlushDeferredBackgroundUpdates];
    }

    [self hideBlurredContentIfNeeded];
    
    [_isActive set:[SSignal single:@true]];
    
    if (_didBecomeInactive)
    {
        _didBecomeInactive = false;
        
        if ([self respondsToSelector:@selector(onBecomeActive)])
            [self onBecomeActive];
        
        if (_passcodeWindow != nil && [self isManuallyLocked])
        {
            [_window endEditing:true];
            
            TGPasscodeEntryController *controller = (TGPasscodeEntryController *)(((TGNavigationController *)_passcodeWindow.rootViewController).topViewController);
            [controller refreshTouchId];
        }
        
    }
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if ([ActionStageInstance() executingActorWithPath:@"/tg/service/updatepresence/(timeout)"] != nil)
        {
            [ActionStageInstance() removeWatcher:TGTelegraphInstance fromPath:@"/tg/service/updatepresence/(timeout)"];
        }
        else
        {
            [TGTelegraphInstance updatePresenceNow];
        }
    }];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event
{
    if (iosMajorVersion() <= 6)
        [[TGRemoteControlsManager instance] handleLegacyRemoteControlEvent:event];
}

- (void)applicationWillTerminate:(UIApplication *)__unused application
{
    if (OGPlatformSupportsBackgroundVoipTransport())
        IOS6NotificationProbe(@"LIFECYCLE", @"will_terminate");
    TGLogSynchronize();
}

- (void)resetLocalization
{
    [TGDateUtils reset];
    
    [_rootController localizationUpdated];
    [[TGInterfaceManager instance] localizationUpdated];
    
    _localizationUpdatedPipe.sink(@true);
}

- (void)performPhoneCall:(NSURL *)url
{
    NSURL *realUrl = url;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        if ([url.scheme isEqualToString:@"tel"])
        {
            realUrl = [NSURL URLWithString:[[url absoluteString] stringByReplacingOccurrencesOfString:@"tel:" withString:@"facetime:"]];
        }
    }
    
    [(TGApplication *)[TGApplication sharedApplication] nativeOpenURL:realUrl];
}

- (void)presentLoginController:(bool)clearControllerStates animated:(bool)animated phoneNumber:(NSString *)phoneNumber phoneCode:(NSString *)phoneCode phoneCodeHash:(NSString *)phoneCodeHash codeSentToTelegram:(bool)codeSentToTelegram codeSentViaPhone:(bool)codeSentViaPhone profileFirstName:(NSString *)profileFirstName profileLastName:(NSString *)profileLastName resetAccountState:(TGResetAccountState *)resetAccountState termsOfService:(TGTermsOfService *)termsOfService
{
    if (![[NSThread currentThread] isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self presentLoginController:clearControllerStates animated:animated phoneNumber:phoneNumber phoneCode:phoneCode phoneCodeHash:phoneCodeHash codeSentToTelegram:codeSentToTelegram codeSentViaPhone:codeSentViaPhone profileFirstName:profileFirstName profileLastName:profileLastName resetAccountState:resetAccountState termsOfService:termsOfService];
        });
        
        return;
    }
    else
    {
        TGNavigationController *loginNavigationController = [self loginNavigationController];
        NSMutableArray *viewControllers = [[loginNavigationController viewControllers] mutableCopy];
        
        if (phoneNumber.length != 0)
        {
            UIViewController *firstController = viewControllers.firstObject;
            [viewControllers removeAllObjects];
            if (firstController != nil) {
                [viewControllers addObject:firstController];
            }
            
            TGLoginPhoneController *phoneController = [[TGLoginPhoneController alloc] init];
            [(TGLoginPhoneController *)phoneController setPhoneNumber:phoneNumber];
            [viewControllers addObject:phoneController];
            
            NSMutableString *cleanPhone = [[NSMutableString alloc] init];
            for (int i = 0; i < (int)phoneNumber.length; i++)
            {
                unichar c = [phoneNumber characterAtIndex:i];
                if (c >= '0' && c <= '9')
                    [cleanPhone appendString:[[NSString alloc] initWithCharacters:&c length:1]];
            }
            
            if (resetAccountState != nil) {
                [viewControllers addObject:[[TGLoginResetAccountProtectedController alloc] initWithPhoneNumber:resetAccountState.phoneNumber protectedUntilDate:resetAccountState.protectedUntilDate]];
            } else if (phoneCode.length != 0 && phoneCodeHash.length != 0) {
                TGLoginProfileController *profileController = [[TGLoginProfileController alloc] initWithShowKeyboard:true phoneNumber:cleanPhone phoneCodeHash:phoneCodeHash phoneCode:phoneCode termsOfService:termsOfService];
                [viewControllers addObject:profileController];
            }
            else if (phoneCodeHash.length != 0)
            {
                TGLoginCodeController *codeController = [[TGLoginCodeController alloc] initWithShowKeyboard:true phoneNumber:cleanPhone phoneCodeHash:phoneCodeHash phoneTimeout:60.0 messageSentToTelegram:codeSentToTelegram messageSentViaPhone:codeSentViaPhone termsOfService:termsOfService];
                [viewControllers addObject:codeController];
            }
        }
        
        [loginNavigationController setViewControllers:viewControllers animated:animated];
        
        if (self.window.rootViewController != loginNavigationController)
        {
            [TGAppDelegateInstance.rootController resetControllers];
            [TGAppDelegateInstance.rootController dismissViewControllerAnimated:false completion:nil];
            self.window.rootViewController = loginNavigationController;
            [self.window makeKeyAndVisible];
        }
        
        if (clearControllerStates)
        {
            TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
            {
                [_rootController.mainTabsController setSelectedIndex:2];
                
                [_rootController.dialogListController.dialogListCompanion clearData];
                [_rootController.contactsController clearData];
                [_rootController.callsController clearData];
                
                [TGAppDelegateInstance.rootController clearContentControllers];
                
                [TGAppDelegateInstance resetControllerStack];
            });
        }
    }
}

- (void)presentMainController
{

    if (_rootController == nil)
    {
        _rootController = [[TGRootController alloc] init];
        if ([TGKeyCommandController keyCommandsSupported])
            _keyCommandController = [[TGKeyCommandController alloc] initWithRootController:_rootController];
        [TGTelegraphInstance.liveLocationManager restoreSessions];
        [TGTelegraphInstance startPresenceUpdates];
        OGPlatformDispatchOnMainThreadAfter(1.0, ^
        {
            [_rootController.callsController initialize];
        });
    }
    if (![[NSThread currentThread] isMainThread])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self presentMainController];
        });
        
        return;
    }
    
    TGNavigationController *loginNavigationController = self.loginNavigationController;
    if (self.window.rootViewController == loginNavigationController)
    {
        self.window.rootViewController = _rootController;
        [self.window makeKeyAndVisible];
        self.loginNavigationController = nil;
        if (self.onSuccessfulLogin != nil)
        {
            self.onSuccessfulLogin();
            self.onSuccessfulLogin = nil;
        }
        return;
    }

    self.loginNavigationController = nil;
    
    UIViewController *presentedViewController = nil;
    presentedViewController = TGAppDelegateInstance.rootController.presentedViewController;
    
    if (OGPlatformViewControllerIsTransitioning(presentedViewController))
    {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
        {
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            
            [self presentMainController];
        });
    }
    else
    {
        [TGAppDelegateInstance.rootController dismissViewControllerAnimated:[[UIApplication sharedApplication] applicationState] == UIApplicationStateActive completion:nil];
        
        if (self.onSuccessfulLogin != nil)
        {
            self.onSuccessfulLogin();
            self.onSuccessfulLogin = nil;
        }
    }
}

- (void)presentContentController:(UIViewController *)controller
{
    _contentWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _contentWindow.windowLevel = UIWindowLevelStatusBar - 0.1f;
    
    _contentWindow.rootViewController = controller;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [_contentWindow makeKeyAndVisible];
    });
}

- (void)dismissContentController
{
    if ([_contentWindow.rootViewController conformsToProtocol:@protocol(TGContentViewController)])
    {
        [(id<TGContentViewController>)_contentWindow.rootViewController contentControllerWillBeDismissed];
    }
    
    [_contentWindow.rootViewController viewWillDisappear:false];
    [_contentWindow.rootViewController viewDidDisappear:false];
    _contentWindow.rootViewController = nil;
    if (_contentWindow.isKeyWindow)
        [_contentWindow resignKeyWindow];
    [_window makeKeyWindow];
    _contentWindow = nil;
    
    UIViewController *topViewController = TGAppDelegateInstance.rootController.viewControllers.lastObject;
    if ([topViewController conformsToProtocol:@protocol(TGDestructableViewController)] && [topViewController respondsToSelector:@selector(contentControllerWillBeDismissed)]) {
        [(id<TGDestructableViewController>)topViewController contentControllerWillBeDismissed];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (!_window.isKeyWindow)
            [_window makeKeyWindow];
    });
}

- (void)openURLNative:(NSURL *)url
{
    [(TGApplication *)[UIApplication sharedApplication] openURL:url forceNative:true];
}

#pragma mark -

- (NSDictionary *)loadLoginState
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    NSString *documentsDirectory = TGAppDelegateDocumentsPathCompat();
    NSData *stateData = [[NSData alloc] initWithContentsOfFile:[documentsDirectory stringByAppendingPathComponent:@"state.data"]];
    
    if (stateData.length != 0)
    {
        NSInputStream *is = [[NSInputStream alloc] initWithData:stateData];
        [is open];
        
        uint8_t version = 0;
        [is read:(uint8_t *)&version maxLength:1];
        
        {
            int date = [is readInt32];
            if (date != 0)
                dict[@"date"] = @(date);
        }
        
        {
            NSString *phoneNumber = [is readString];
            if (phoneNumber.length != 0)
                dict[@"phoneNumber"] = phoneNumber;
        }
        
        {
            NSString *phoneCode = [is readString];
            if (phoneCode.length != 0)
                dict[@"phoneCode"] = phoneCode;
        }
        
        {
            NSString *phoneCodeHash = [is readString];
            if (phoneCodeHash.length != 0)
                dict[@"phoneCodeHash"] = phoneCodeHash;
        }
        
        {
            NSString *firstName = [is readString];
            if (firstName.length != 0)
                dict[@"firstName"] = firstName;
        }
        
        {
            NSString *lastName = [is readString];
            if (lastName.length != 0)
                dict[@"lastName"] = lastName;
        }
        
        {
            NSData *photo = [is readBytes];
            if (photo.length != 0)
                dict[@"photo"] = photo;
        }
        
        if (version >= 1)
        {
            dict[@"codeSentToTelegram"] = @([is readInt32] != 0);
            
            if (version >= 2) {
                dict[@"codeSentViaPhone"] = @([is readInt32] != 0);
                
                if (version >= 3) {
                    int32_t length = [is readInt32];
                    if (length != 0) {
                        TGResetAccountState *resetAccountState = [NSKeyedUnarchiver unarchiveObjectWithData:[is readData:length]];
                        if ([resetAccountState isKindOfClass:[TGResetAccountState class]]) {
                            dict[@"resetAccountState"] = resetAccountState;
                        }
                    }
                }
            }
        }
        
        [is close];
    }
    
    return dict;
}

- (void)resetLoginState
{
    NSString *documentsDirectory = TGAppDelegateDocumentsPathCompat();
    [[NSFileManager defaultManager] removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"state.data"] error:nil];
}

- (void)saveLoginStateWithDate:(int)date phoneNumber:(NSString *)phoneNumber phoneCode:(NSString *)phoneCode phoneCodeHash:(NSString *)phoneCodeHash codeSentToTelegram:(bool)codeSentToTelegram codeSentViaPhone:(bool)codeSentViaPhone firstName:(NSString *)firstName lastName:(NSString *)lastName photo:(NSData *)photo resetAccountState:(TGResetAccountState *)resetAccountState
{
    NSOutputStream *os = [[NSOutputStream alloc] initToMemory];
    [os open];
    
    uint8_t version = 3;
    [os write:&version maxLength:1];
    
    [os writeInt32:date];
    
    [os writeString:phoneNumber];
    [os writeString:phoneCode];
    [os writeString:phoneCodeHash];
    [os writeString:firstName];
    [os writeString:lastName];
    [os writeBytes:photo];
    [os writeInt32:codeSentToTelegram ? 1 : 0];
    [os writeInt32:codeSentViaPhone ? 1 : 0];
    
    if (resetAccountState != nil) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:resetAccountState];
        int32_t length = (int32_t)data.length;
        [os writeInt32:length];
        [os writeData:data];
    } else {
        [os writeInt32:0];
    }
    
    [os close];
    
    NSData *data = [os currentBytes];
    NSString *documentsDirectory = TGAppDelegateDocumentsPathCompat();
    [data writeToFile:[documentsDirectory stringByAppendingPathComponent:@"state.data"] atomically:true];
}

- (void)migrateSettings
{
    NSUserDefaults *legacyUserDefaults = [NSUserDefaults standardUserDefaults];
    TGUserDefaults *userDefaults = [TGUserDefaults standard];
    
    NSArray *keys = @
    [
     @"telegraphUserId",
     @"telegraphUserActivated",
     @"soundEnabled",
     @"outgoingSoundEnabled",
     @"vibrationEnabled",
     @"bannerEnabled",
     @"exclusiveConversationControllers",
     @"saveEditedPhotos",
     @"customChatBackground",
     @"useDifferentBackend",
     @"autoSavePhotosMode",
     @"autoPlayAudio",
     @"autoPlayAnimations",
     @"alwaysShowStickersMode",
     @"allowSecretWebpages",
     @"allowSecretWebpagesInitialized",
     @"secretInlineBotsInitialized",
     @"callsDataUsageMode",
     @"callsDisableP2P",
     @"callsDisableCallKit",
     @"callsUseProxy",
     @"contactsInhibitSync",
     @"stickersSuggestMode"
    ];
    
    for (NSString *key in keys)
    {
        id value = nil;
        if ((value = [legacyUserDefaults objectForKey:key]) != nil)
            [userDefaults setObject:value forKey:key];
    }
    [userDefaults synchronize];
    
    for (NSString *key in keys)
    {
        [legacyUserDefaults removeObjectForKey:key];
    }
    [legacyUserDefaults synchronize];
}

- (void)loadSettings
{
    NSUserDefaults *legacyUserDefaults = [NSUserDefaults standardUserDefaults];
    TGUserDefaults *userDefaults = [TGUserDefaults standard];
    
    int32_t userId = [[userDefaults objectForKey:@"telegraphUserId"] intValue];
    int32_t legacyUserId = [[legacyUserDefaults objectForKey:@"telegraphUserId"] intValue];
    
    if (userId == 0 && legacyUserId != 0)
        [self migrateSettings];

	    TGTelegraphInstance.clientUserId = [[userDefaults objectForKey:@"telegraphUserId"] intValue];
	    TGTelegraphInstance.clientIsActivated = [[userDefaults objectForKey:@"telegraphUserActivated"] boolValue];
        TGLog(@"AUTH settings.load userId=%d activated=%d legacyUserId=%d migrated=%d", TGTelegraphInstance.clientUserId, TGTelegraphInstance.clientIsActivated ? 1 : 0, legacyUserId, (userId == 0 && legacyUserId != 0) ? 1 : 0);
    
    id value = nil;
    if ((value = [userDefaults objectForKey:@"soundEnabled"]) != nil)
        _soundEnabled = [value boolValue];
    else
        _soundEnabled = true;
    
    if ((value = [userDefaults objectForKey:@"outgoingSoundEnabled"]) != nil)
        _outgoingSoundEnabled = [value boolValue];
    else
        _outgoingSoundEnabled = true;
    
    if ((value = [userDefaults objectForKey:@"vibrationEnabled"]) != nil)
        _vibrationEnabled = [value boolValue];
    else
        _vibrationEnabled = false;
    
    if ((value = [userDefaults objectForKey:@"bannerEnabled"]) != nil)
        _bannerEnabled = [value boolValue];
    else
        _bannerEnabled = true;
    
    if ((value = [userDefaults objectForKey:@"exclusiveConversationControllers"]) != nil)
        _exclusiveConversationControllers = [value boolValue];
    else
        _exclusiveConversationControllers = true;
    
    if ((value = [userDefaults objectForKey:@"saveEditedPhotos"]) != nil)
        _saveEditedPhotos = [value boolValue];
    else
        _saveEditedPhotos = true;
    
    _saveCapturedMedia = true;

    if ((value = [userDefaults objectForKey:@"customChatBackground"]) != nil)
        _customChatBackground = [value boolValue];
    else
    {
        _customChatBackground = false;
        
        NSString *imageUrl = @"wallpaper-original-pattern-default";
        NSString *thumbnailUrl = @"local://wallpaper-thumb-pattern-default";
        NSString *filePath = [[NSBundle mainBundle] pathForResource:imageUrl ofType:@"jpg"];
        int tintColor = 0x0c3259;
        
        if (filePath != nil)
        {
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            NSString *documentsDirectory = TGAppDelegateDocumentsPathCompat();
            NSString *wallpapersPath = [documentsDirectory stringByAppendingPathComponent:@"wallpapers"];
            [fileManager createDirectoryAtPath:wallpapersPath withIntermediateDirectories:true attributes:nil error:nil];
            
            [fileManager copyItemAtPath:filePath toPath:[wallpapersPath stringByAppendingPathComponent:@"_custom.jpg"] error:nil];
            [[thumbnailUrl dataUsingEncoding:NSUTF8StringEncoding] writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom-meta"] atomically:true];
            
            [(tintColor == -1 ? [NSData data] : [[NSData alloc] initWithBytes:&tintColor length:4]) writeToFile:[wallpapersPath stringByAppendingPathComponent:@"_custom_mono.dat"] atomically:true];
            
            _customChatBackground = true;
        }
    }

    if ((value = [userDefaults objectForKey:@"useDifferentBackend"]) != nil)
        _useDifferentBackend = [value boolValue];
    else
        _useDifferentBackend = true;
    
    if ((value = [userDefaults objectForKey:@"autoSavePhotosMode"]) != nil)
        _autoSavePhotosMode = (TGAutoDownloadMode)[value intValue];
    
    _autoDownloadPreferences = [self loadAutoDownloadPreferences];
    
    if ((value = [userDefaults objectForKey:@"autoPlayAudio"]) != nil)
        _autoPlayAudio = [value boolValue];
    else
        _autoPlayAudio = false;
    
    if ((value = [userDefaults objectForKey:@"autoPlayAnimations"]) != nil)
        _autoPlayAnimations = [value boolValue];
    else
        _autoPlayAnimations = cpuCoreCount() > 1;
    
    if (OGPlatformMediaDownloadsRequireUserAction())
    {
        _autoPlayAudio = false;
        _autoPlayAnimations = false;
    }

    if ((value = [userDefaults objectForKey:@"alwaysShowStickersMode"]) != nil)
        _alwaysShowStickersMode = [value intValue];
    else
        _alwaysShowStickersMode = false;
    
    if ((value = [userDefaults objectForKey:@"allowSecretWebpages"]) != nil)
        _allowSecretWebpages = [value intValue];
    else
        _allowSecretWebpages = false;
    
    if ((value = [userDefaults objectForKey:@"allowSecretWebpagesInitialized"]) != nil)
        _allowSecretWebpagesInitialized = [value intValue];
    else
        _allowSecretWebpagesInitialized = false;
    
    if ((value = [userDefaults objectForKey:@"secretInlineBotsInitialized"]) != nil)
        _secretInlineBotsInitialized = [value intValue];
    else
        _secretInlineBotsInitialized = false;
    
    if ((value = [userDefaults objectForKey:@"callsDataUsageMode"]) != nil)
        _callsDataUsageMode = [value intValue];
    else
        _callsDataUsageMode = 0;
    
    if ((value = [userDefaults objectForKey:@"callsDisableP2P"]) != nil)
        _callsP2PMode = [value intValue];
    else
        _callsP2PMode = false;
    
    if ((value = [userDefaults objectForKey:@"callsDisableCallKit"]) != nil)
        _callsDisableCallKit = [value boolValue];
    else
        _callsDisableCallKit = false;
    
    if ((value = [userDefaults objectForKey:@"callsUseProxy"]) != nil)
        _callsUseProxy = [value boolValue];
    else
        _callsUseProxy = false;
    
    if ((value = [userDefaults objectForKey:@"contactsInhibitSync"]) != nil)
        _contactsInhibitSync = [value boolValue];
    else
        _contactsInhibitSync = false;
    
    if ((value = [userDefaults objectForKey:@"stickersSuggestMode"]) != nil)
        _stickersSuggestMode = [value intValue];
    else
        _stickersSuggestMode = 0;
}

- (NSString *)autoDownloadPreferencesPath
{
    return [TGAppDelegateDocumentsPathCompat() stringByAppendingPathComponent:@"autoDownload.pref"];
}

- (TGAutoDownloadPreferences *)loadAutoDownloadPreferences
{
    TGAutoDownloadPreferences *preferences = [TGAutoDownloadPreferences defaultPreferences];
    
    NSData *preferencesData = [[NSData alloc] initWithContentsOfFile:[self autoDownloadPreferencesPath]];
    if (preferencesData.length != 0)
    {
        TGAutoDownloadPreferences *loadedPreferences = nil;
        @try {
            loadedPreferences = [NSKeyedUnarchiver unarchiveObjectWithData:preferencesData];
        } @catch (NSException *e) {
        }
        
        if (loadedPreferences != nil)
            preferences = loadedPreferences;
    }
    
    return preferences;
}

- (void)setAutoDownloadPreferences:(TGAutoDownloadPreferences *)autoDownloadPreferences
{
    if (autoDownloadPreferences == nil)
        return;
    
    _autoDownloadPreferences = autoDownloadPreferences;
    [[NSKeyedArchiver archivedDataWithRootObject:autoDownloadPreferences] writeToFile:[self autoDownloadPreferencesPath] atomically:true];
}

- (void)setAutoSavePhotosMode:(TGAutoDownloadMode)autoSavePhotosMode
{
    _autoSavePhotosMode = autoSavePhotosMode;
    
    TGUserDefaults *userDefaults = [TGUserDefaults standard];
    [userDefaults setObject:[NSNumber numberWithInt:_autoSavePhotosMode] forKey:@"autoSavePhotosMode"];
    [userDefaults synchronize];
}

- (void)saveSettings
{
    if (_autoDownloadPreferences == nil)
        return;
    
    TGUserDefaults *userDefaults = [TGUserDefaults standard];
    
	    [userDefaults setObject:[[NSNumber alloc] initWithInt:TGTelegraphInstance.clientUserId] forKey:@"telegraphUserId"];
	    [userDefaults setObject:[[NSNumber alloc] initWithBool:TGTelegraphInstance.clientIsActivated] forKey:@"telegraphUserActivated"];
        TGLog(@"AUTH settings.save userId=%d activated=%d", TGTelegraphInstance.clientUserId, TGTelegraphInstance.clientIsActivated ? 1 : 0);
    
    [userDefaults setObject:[NSNumber numberWithBool:_soundEnabled] forKey:@"soundEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_outgoingSoundEnabled] forKey:@"outgoingSoundEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_vibrationEnabled] forKey:@"vibrationEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_bannerEnabled] forKey:@"bannerEnabled"];
    [userDefaults setObject:[NSNumber numberWithBool:_exclusiveConversationControllers] forKey:@"exclusiveConversationControllers"];
    
    [userDefaults setObject:[NSNumber numberWithBool:_saveEditedPhotos] forKey:@"saveEditedPhotos"];
    [userDefaults setObject:[NSNumber numberWithBool:_saveCapturedMedia] forKey:@"saveCapturedMedia"];
    [userDefaults setObject:[NSNumber numberWithBool:_customChatBackground] forKey:@"customChatBackground"];

    [userDefaults setObject:[NSNumber numberWithBool:_useDifferentBackend] forKey:@"useDifferentBackend"];

    [userDefaults setObject:[NSNumber numberWithInt:TGBaseFontSize] forKey:@"baseFontSize"];
    
    [userDefaults setObject:[NSNumber numberWithBool:_autoPlayAudio] forKey:@"autoPlayAudio"];
    [userDefaults setObject:[NSNumber numberWithBool:_autoPlayAnimations] forKey:@"autoPlayAnimations"];
    
    [userDefaults setObject:[NSNumber numberWithInt:_alwaysShowStickersMode] forKey:@"alwaysShowStickersMode"];
    
    [userDefaults setObject:[NSNumber numberWithInt:_allowSecretWebpages] forKey:@"allowSecretWebpages"];
    [userDefaults setObject:[NSNumber numberWithInt:_allowSecretWebpagesInitialized] forKey:@"allowSecretWebpagesInitialized"];
    
    [userDefaults setObject:[NSNumber numberWithInt:_secretInlineBotsInitialized] forKey:@"secretInlineBotsInitialized"];
    
    [userDefaults setObject:[NSNumber numberWithInt:_callsDataUsageMode] forKey:@"callsDataUsageMode"];
    
    [userDefaults setObject:[NSNumber numberWithInt:_callsP2PMode] forKey:@"callsDisableP2P"];
    [userDefaults setObject:[NSNumber numberWithBool:_callsDisableCallKit] forKey:@"callsDisableCallKit"];
    [userDefaults setObject:[NSNumber numberWithBool:_callsUseProxy] forKey:@"callsUseProxy"];
    
    [userDefaults setObject:[NSNumber numberWithBool:_contactsInhibitSync] forKey:@"contactsInhibitSync"];
    
    [userDefaults setObject:[NSNumber numberWithInt:_stickersSuggestMode] forKey:@"stickersSuggestMode"];
    
    [userDefaults synchronize];
}

#pragma mark -

- (NSArray *)modernAlertSoundTitles
{
    return @[
        TGLocalized(@"NotificationsSound.None"),
        TGLocalized(@"NotificationsSound.Note"),
        TGLocalized(@"NotificationsSound.Aurora"),
        TGLocalized(@"NotificationsSound.Bamboo"),
        TGLocalized(@"NotificationsSound.Chord"),
        TGLocalized(@"NotificationsSound.Circles"),
        TGLocalized(@"NotificationsSound.Complete"),
        TGLocalized(@"NotificationsSound.Hello"),
        TGLocalized(@"NotificationsSound.Input"),
        TGLocalized(@"NotificationsSound.Keys"),
        TGLocalized(@"NotificationsSound.Popcorn"),
        TGLocalized(@"NotificationsSound.Pulse"),
        TGLocalized(@"NotificationsSound.Synth")
    ];
}

- (NSArray *)classicAlertSoundTitles
{
    return @[
        TGLocalized(@"NotificationsSound.Tritone"),
        TGLocalized(@"NotificationsSound.Tremolo"),
        TGLocalized(@"NotificationsSound.Alert"),
        TGLocalized(@"NotificationsSound.Bell"),
        TGLocalized(@"NotificationsSound.Calypso"),
        TGLocalized(@"NotificationsSound.Chime"),
        TGLocalized(@"NotificationsSound.Glass"),
        TGLocalized(@"NotificationsSound.Telegraph")
    ];
    static NSArray *soundArray = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        [array addObject:@"Tri-tone"];
        [array addObject:@"Tremolo"];
        [array addObject:@"Alert"];
        [array addObject:@"Bell"];
        [array addObject:@"Calypso"];
        [array addObject:@"Chime"];
        [array addObject:@"Glass"];
        [array addObject:@"Telegraph"];
        soundArray = array;
    });
    
    return soundArray;
}

- (void)playSound:(NSString *)name vibrate:(bool)vibrate
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
            return;
        
        if (name != nil && TGAppDelegateInstance.soundEnabled && ![[TGAudioSessionManager instance] notificationSoundsSuppressed])
        {
            static NSMutableDictionary *soundPlayed = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                soundPlayed = [[NSMutableDictionary alloc] init];
            });
            
            double lastTimeSoundPlayed = [[soundPlayed objectForKey:name] doubleValue];
            
            CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
            if (currentTime - lastTimeSoundPlayed < 0.25)
                return;
        
            [soundPlayed setObject:[[NSNumber alloc] initWithDouble:currentTime] forKey:name];
        
            NSNumber *soundId = [_loadedSoundSamples objectForKey:name];
            if (soundId == nil)
            {
                NSString *path = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], name];
                NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
                SystemSoundID sound;
                AudioServicesCreateSystemSoundID((__bridge CFURLRef)filePath, &sound);
                soundId = [NSNumber numberWithUnsignedLong:sound];
                [_loadedSoundSamples setObject:soundId forKey:name];
            }
            
            AudioServicesPlaySystemSound((SystemSoundID)[soundId unsignedLongValue]);
        }
        
        if (vibrate && TGAppDelegateInstance.vibrationEnabled)
        {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
    });
}

- (void)playNotificationSound:(NSString *)name
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if ([[TGAudioSessionManager instance] notificationSoundsSuppressed])
            return;
        _currentAudioPlayer.delegate = nil;
        _currentAudioPlayer = nil;
        
        NSError *error = nil;
        AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:OGPlatformBundleResourceURL([NSBundle mainBundle], name, @"m4a") error:&error];
        if (error == nil)
        {
            if (_currentAudioPlayerSession == nil)
                _currentAudioPlayerSession = [[SMetaDisposable alloc] init];
            [_currentAudioPlayerSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypePlayMusic interrupted:^
            {
                _currentAudioPlayer.delegate = nil;
                [_currentAudioPlayer stop];
                _currentAudioPlayer = nil;
            }]];
            
            _currentAudioPlayer = audioPlayer;
            audioPlayer.delegate = self;
            [audioPlayer play];
        }
    });
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)__unused flag
{
    if (player == _currentAudioPlayer)
    {
        _currentAudioPlayer.delegate = nil;
        _currentAudioPlayer = nil;
        
        [_currentAudioPlayerSession setDisposable:nil];
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)__unused player error:(NSError *)__unused error
{
    if (player == _currentAudioPlayer)
    {
        _currentAudioPlayer.delegate = nil;
        _currentAudioPlayer = nil;
    }
}

#pragma mark -

- (void)requestDeviceToken:(id<TGDeviceTokenListener>)listener
{

    if (!TGIOS6APNsNotificationsEnabled())
    {
        [listener deviceTokenRequestCompleted:nil];
        [self disableAPNsNotificationRegistration];
        return;
    }

    if (_tokenAlreadyRequested)
    {
        NSString *token = nil;
        if (_pushToken != nil)
        {
            token = [[_pushToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
            token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
        }
        [listener deviceTokenRequestCompleted:token];
        return;
    }
    
    _deviceTokenListener = listener;

    UIApplication *application = [UIApplication sharedApplication];
    if (OGPlatformRegisterUserNotificationSettings(application, [self ios6UserNotificationCategories]))
    {
        _ios6LocalNotificationSettingsRegistered = true;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        [application registerForRemoteNotifications];
        
        _pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        _pushRegistry.delegate = self;
        _pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
#endif
    }
    else
    {
        [application registerForRemoteNotificationTypes:(UIRemoteNotificationType)(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
}

- (NSArray *)ios6UserNotificationCategories
{
    bool textInputReply = iosMajorVersion() >= 9;
    bool exclusiveQuickReplySupported = ((iosMajorVersion() == 9 && iosMinorVersion() >= 1) || iosMajorVersion() > 9);
    
    id replyAction = OGPlatformCreateUserNotificationAction(@"reply", TGLocalized(@"Notification.Reply"), NO, !textInputReply, !textInputReply, textInputReply);
    id foregroundReplyAction = OGPlatformCreateUserNotificationAction(@"reply", TGLocalized(@"Notification.Reply"), NO, YES, YES, NO);
    id muteAction = OGPlatformCreateUserNotificationAction(@"mute", TGLocalized(@"Notification.Mute1h"), YES, NO, NO, NO);
    id minimalMuteAction = OGPlatformCreateUserNotificationAction(@"mute", TGLocalized(@"Notification.Mute1hMin"), YES, NO, NO, NO);
    id mute8Action = OGPlatformCreateUserNotificationAction(@"mute8h", [effectiveLocalization() getPluralized:@"MuteFor.Hours" count:8], YES, NO, NO, NO);
    id likeAction = OGPlatformCreateUserNotificationAction(@"like", @"👍", NO, NO, NO, NO);
    id callAction = OGPlatformCreateUserNotificationAction(@"call", TGLocalized(@"Notification.CallBack"), NO, YES, YES, NO);
    if (replyAction == nil || foregroundReplyAction == nil || muteAction == nil || minimalMuteAction == nil || mute8Action == nil || likeAction == nil || callAction == nil)
        return nil;
    
    id muteCategory = OGPlatformCreateUserNotificationCategory(@"m", exclusiveQuickReplySupported ? @[replyAction] : @[replyAction, muteAction], exclusiveQuickReplySupported ? @[replyAction] : @[replyAction, minimalMuteAction]);
    id replyCategory = OGPlatformCreateUserNotificationCategory(@"r", exclusiveQuickReplySupported ? @[replyAction] : @[replyAction, likeAction], exclusiveQuickReplySupported ? @[replyAction] : @[replyAction, likeAction]);
    id channelCategory = OGPlatformCreateUserNotificationCategory(@"c", @[muteAction, mute8Action], @[minimalMuteAction]);
    id callCategory = OGPlatformCreateUserNotificationCategory(@"p", @[callAction, foregroundReplyAction], @[callAction, foregroundReplyAction]);
    if (muteCategory == nil || replyCategory == nil || channelCategory == nil || callCategory == nil)
        return nil;
    
    return @[muteCategory, replyCategory, channelCategory, callCategory];
}

- (void)ios6RegisterLocalNotificationSettings
{
    if (_ios6LocalNotificationSettingsRegistered || !TGIOS6BackgroundNotificationsEnabled())
        return;
    if (OGPlatformRegisterUserNotificationSettings([UIApplication sharedApplication], [self ios6UserNotificationCategories]))
        _ios6LocalNotificationSettingsRegistered = true;
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)__unused notificationSettings
{
    if (TGIOS6APNsNotificationsEnabled())
        [application registerForRemoteNotifications];
    else
        [self disableAPNsNotificationRegistration];
}

- (void)application:(UIApplication*)__unused application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    if (!TGIOS6APNsNotificationsEnabled())
    {
        [_deviceTokenListener deviceTokenRequestCompleted:nil];
        _deviceTokenListener = nil;
        [self disableAPNsNotificationRegistration];
        return;
    }

    _tokenAlreadyRequested = true;
    _pushToken = deviceToken;
    
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    [_deviceTokenListener deviceTokenRequestCompleted:token];
    _deviceTokenListener = nil;
}

- (void)application:(UIApplication*)__unused application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    _tokenAlreadyRequested = true;
    
	TGLog(@"PUSH token failure bundle=%@ domain=%@ code=%d error=%@", [[NSBundle mainBundle] bundleIdentifier], error.domain, (int)error.code, error);
    [_deviceTokenListener deviceTokenRequestCompleted:nil];
    _deviceTokenListener = nil;
}

- (void)pushRegistry:(PKPushRegistry *)__unused registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type
{
    if (type != PKPushTypeVoIP)
        return;
    if (!TGIOS6APNsNotificationsEnabled())
    {
        [self disableAPNsNotificationRegistration];
        return;
    }
    
    NSString *token = [[credentials.token description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    [[TGAccountSignals registerDeviceToken:token voip:true] startWithNext:nil];
}

- (void)pushRegistry:(PKPushRegistry *)__unused registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)__unused type
{
#ifdef INTERNAL_RELEASE
    TGLog(@"voip push: %@", payload.dictionaryPayload);
#endif
    
    [self processPossibleAnnouncement:payload.dictionaryPayload];
    [self processPossibleLiveLocationRequest:payload.dictionaryPayload];
    [self processPossibleCallRequest:payload.dictionaryPayload];
    [self processPossibleConfigUpdateNotification:payload.dictionaryPayload];
}

- (void)application:(UIApplication *)__unused application didReceiveLocalNotification:(UILocalNotification *)notification
{
    if (!_inBackground || [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        return;
    
    int64_t peerId = [[OGPlatformLocalNotificationUserInfo(notification) objectForKey:@"cid"] longLongValue];
    TGIOS6OpenNotificationPeer(peerId);
}

- (void)application:(UIApplication *)__unused application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
#ifdef DEBUG
    TGLog(@"remoteNotification: %@", userInfo);
#endif
    
    [self processPossibleCloudKitNotification:userInfo];
    [self processPossibleConfigUpdateNotification:userInfo];
    [self processPossibleAnnouncement:userInfo];
    
    if (!_inBackground)
        return;
    
    [self processRemoteNotification:userInfo];
}

- (void)application:(UIApplication *)__unused application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    [self processPossibleCloudKitNotification:userInfo];
    [self processPossibleConfigUpdateNotification:userInfo];
    [self processPossibleAnnouncement:userInfo];
    
    if ([application applicationState] != UIApplicationStateActive)
    {
        if ([self isCurrentlyLocked] && (_passcodeWindow == nil || _passcodeWindow.hidden))
            [self displayUnlockWindowIfNeeded];
        
        [[TGTelegramNetworking instance] resume];
        
        if (completionHandler != nil)
        {
            [[TGTelegramNetworking instance] wakeUpWithCompletion:^
            {
                TGDispatchOnMainThread(^
                {
                    if (_inBackground)
                    {
                        if (!TGTelegraphInstance.callManager.hasActiveCall)
                        {
                            [[TGTelegramNetworking instance] pause];
                        }
                        
                        NSTimeInterval remainingTime = TGIOS3BackgroundTimeRemaining([UIApplication sharedApplication]);
                        if (remainingTime > 2.0) {
                            TGDispatchAfter(MIN(remainingTime, 5.0), dispatch_get_main_queue(), ^
                            {
                                completionHandler(UIBackgroundFetchResultNewData);
                            });
                        } else {
                            completionHandler(UIBackgroundFetchResultNewData);
                        }
                    }
                });
            }];
        }
    }
    else if (completionHandler != nil)
        completionHandler(UIBackgroundFetchResultNewData);
    
    if (!_inBackground || !_enteringForeground)
        return;
    
    [self processRemoteNotification:userInfo];
}

- (void)processRemoteNotification:(NSDictionary *)userInfo
{
    [self processRemoteNotification:userInfo removeView:nil];
}

- (void)processRemoteNotification:(NSDictionary *)userInfo removeView:(UIView *)removeView
{
    if (TGTelegraphInstance.clientUserId == 0)
    {
        [removeView removeFromSuperview];
        return;
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        return;
    
    id nFromId = [userInfo objectForKey:@"from_id"];
    id nChatId = [userInfo objectForKey:@"chat_id"];
    id nContactId = [userInfo objectForKey:@"contact_id"];
    id nChannelId = [userInfo objectForKey:@"channel_id"];
    
    int64_t conversationId = 0;
    
    if (nFromId != nil && [TGSchema canCreateIntFromObject:nFromId])
    {
        conversationId = [TGSchema intFromObject:nFromId];
    }
    else if (nChatId != nil && [TGSchema canCreateIntFromObject:nChatId])
    {
        conversationId = -[TGSchema intFromObject:nChatId];
    }
    else if (nContactId != nil && [TGSchema canCreateIntFromObject:nContactId])
    {
        conversationId = [TGSchema intFromObject:nContactId];
    }
    else if (nChannelId != nil && [TGSchema canCreateIntFromObject:nChannelId])
    {
        conversationId = TGPeerIdFromChannelId([TGSchema intFromObject:nChannelId]);
    }
    else
    {
        [removeView removeFromSuperview];
    }
    
    TGIOS6OpenNotificationPeer(conversationId);
}

- (void)processPossibleAnnouncement:(NSDictionary *)dict {
    if ([dict[@"announcement"] respondsToSelector:@selector(intValue)]) {
        NSDictionary *aps = dict[@"aps"];
        if ([aps respondsToSelector:@selector(objectForKey:)] && [aps[@"alert"] respondsToSelector:@selector(characterAtIndex:)]) {
            NSNumber *globalMessageSoundIdVal = nil;
            NSNumber *globalMessagePreviewTextVal = nil;
            NSNumber *globalMessageMuteUntilVal = nil;
            
            int globalMessageSoundId = 1;
            bool globalMessagePreviewText = true;
            int globalMessageMuteUntil = 0;
            bool notFound = false;
            [TGDatabaseInstance() loadPeerNotificationSettings:INT_MAX - 1 soundId:&globalMessageSoundIdVal muteUntil:&globalMessageMuteUntilVal previewText:&globalMessagePreviewTextVal messagesMuted:NULL notFound:&notFound];
            if (notFound) {
                globalMessageSoundId = 1;
                globalMessagePreviewText = true;
            }
            else {
                globalMessageSoundId = globalMessageSoundIdVal ? globalMessageSoundIdVal.intValue : 1;
                globalMessagePreviewText = globalMessagePreviewTextVal ? globalMessagePreviewTextVal.boolValue : true;
                globalMessageMuteUntil = globalMessageMuteUntilVal ? globalMessageMuteUntilVal.intValue : 0;
            }
            
            NSNumber *globalGroupSoundIdVal = nil;
            NSNumber *globalGroupPreviewTextVal = nil;
            NSNumber *globalGroupMuteUntilVal = nil;
            
            int globalGroupSoundId = 1;
            bool globalGroupPreviewText = true;
            int globalGroupMuteUntil = 0;
            notFound = false;
            [TGDatabaseInstance() loadPeerNotificationSettings:INT_MAX - 2 soundId:&globalGroupSoundIdVal muteUntil:&globalGroupMuteUntilVal previewText:&globalGroupPreviewTextVal messagesMuted:NULL notFound:&notFound];
            if (notFound) {
                globalGroupSoundId = 1;
                globalGroupPreviewText = true;
            } else {
                globalGroupSoundId = globalGroupSoundIdVal ? globalGroupSoundIdVal.intValue : 1;
                globalGroupPreviewText = globalGroupPreviewTextVal ? globalGroupPreviewTextVal.boolValue : true;
                globalGroupMuteUntil = globalGroupMuteUntilVal ? globalGroupMuteUntilVal.intValue : 0;
            }
            
            NSString *alert = aps[@"alert"];
            int32_t timestamp = (int32_t)[[NSDate date] timeIntervalSince1970];
            
            int uid = [TGTelegraphInstance createServiceUserIfNeeded];
            int32_t uniqueId = [dict[@"announcement"] intValue];
            
            [TGDatabaseInstance() loadMessagesFromConversation:uid maxMid:INT32_MAX maxDate:INT32_MAX maxLocalMid:INT32_MAX atMessageId:0 limit:20 extraUnread:false completion:^(NSArray *messages, __unused bool historyExistsBelow) {
                TGDispatchOnMainThread(^{
                    bool found = false;
                    for (TGMessage *message in messages) {
                        TGMessageUniqueIdContentProperty *prop = message.contentProperties[@"uniqueId"];
                        if (prop.value == uniqueId) {
                            found = true;
                            break;
                        }
                    }
                    
                    if (!found) {
                        TGMessage *message = [[TGMessage alloc] init];
                        message.mid = [[[TGDatabaseInstance() generateLocalMids:1] objectAtIndex:0] intValue];
                        
                        message.fromUid = uid;
                        message.toUid = TGTelegraphInstance.clientUserId;
                        message.date = timestamp;
                        message.outgoing = false;
                        message.cid = uid;
                        
                        message.text = alert;
                        message.contentProperties = @{@"uniqueId": [[TGMessageUniqueIdContentProperty alloc] initWithValue: uniqueId]};
                        
                        [TGDatabaseInstance() transactionAddMessages:@[message] updateConversationDatas:@{} notifyAdded:true];
                        
                        if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                            return;
                        }
                        
                        id localNotification = OGPlatformCreateLocalNotification();
                        if (localNotification == nil) {
                            return;
                        }
                        
                        TGUser *user = nil;
                        NSString *chatName = nil;
                        
                        int64_t notificationPeerId = 0;
                        
                        if (message.cid <= INT_MIN)
                        {
                            notificationPeerId = [TGDatabaseInstance() encryptedParticipantIdForConversationId:message.cid];
                        }
                        else if (message.cid > 0)
                        {
                            user = [TGDatabaseInstance() loadUser:(int)message.cid];
                            notificationPeerId = message.cid;
                        }
                        else
                        {
                            if (message.containsMention)
                                notificationPeerId = message.fromUid;
                            else
                                notificationPeerId = message.cid;
                            user = [TGDatabaseInstance() loadUser:(int)message.fromUid];
                            TGConversation *conversation = [TGDatabaseInstance() loadConversationWithIdCached:message.cid];
                            if (conversation != nil)
                                chatName = conversation.chatTitle;
                            else
                                chatName = [TGDatabaseInstance() loadConversationWithId:message.cid].chatTitle;
                        }
                        
                        if ([TGDatabaseInstance() isPeerMuted:notificationPeerId])
                            return;
                        
                        NSNumber *soundIdVal = nil;
                        int soundId = 1;
                        [TGDatabaseInstance() loadPeerNotificationSettings:notificationPeerId soundId:&soundIdVal muteUntil:NULL previewText:NULL messagesMuted:NULL notFound:NULL];
                        
                        if (soundIdVal != nil) {
                            soundId = soundIdVal.intValue;
                        } else {
                            soundId = (message.cid > 0 || message.cid <= INT_MIN) ? globalMessageSoundId : globalGroupSoundId;
                        }
                        
                        NSString *text = message.text;
                        bool attachmentFound = false;
                        
                        if (soundId > 0)
                            OGPlatformSetLocalNotificationSoundName(localNotification, [[NSString alloc] initWithFormat:@"%d.m4a", soundId]);
                        
                        if (message.cid <= INT_MIN)
                        {
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"ENCRYPTED_MESSAGE"), @""];
                        }
                        else if (message.cid > 0)
                        {
                            if (globalMessagePreviewText && !attachmentFound)
                                text = [[NSString alloc] initWithFormat:@"%@: %@", user.displayName, message.text];
                            else if (!attachmentFound)
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_NOTEXT"), user.displayName];
                        }
                        else
                        {
                            if (globalGroupPreviewText && !attachmentFound)
                                text = [[NSString alloc] initWithFormat:@"%@@%@: %@", user.displayName, chatName, message.text];
                            else if (!attachmentFound)
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_NOTEXT"), user.displayName, chatName];
                        }
                        
                        bool isLocked = [TGAppDelegateInstance isCurrentlyLocked];
                        if (isLocked)
                        {
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"LOCKED_MESSAGE"), @""];
                        }
                        
#ifdef INTERNAL_RELEASE
                        text = [@"[L] " stringByAppendingString:text];
#endif
                        OGPlatformSetLocalNotificationUserInfo(localNotification, [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:message.cid], @"cid", @(message.mid), @"mid", nil]);
                        
                        if (iosMajorVersion() >= 8 && !isLocked)
                        {
                            if (TGPeerIdIsGroup(message.cid))
                                OGPlatformSetLocalNotificationCategory(localNotification, @"m");
                            else if (TGPeerIdIsChannel(message.cid))
                                OGPlatformSetLocalNotificationCategory(localNotification, @"c");
                            else if (message.cid > INT_MIN)
                                OGPlatformSetLocalNotificationCategory(localNotification, @"r");
                        }
                        
                        [TGApplyUpdatesActor presentSafeLocalNotification:(UILocalNotification *)localNotification text:text];
                    }
                });
            }];
        }
    }
}

- (void)processPossibleLiveLocationRequest:(NSDictionary *)dict
{
    if (!([dict[@"aps"][@"alert"] isKindOfClass:[NSDictionary class]] && [dict[@"aps"][@"alert"][@"loc-key"] isEqualToString:@"GEO_LIVE_PENDING"]))
        return;
    
    [TGTelegraphInstance.liveLocationManager performInfrequentLocationUpdate:^(bool willPerform)
    {
        TGDispatchOnMainThread(^
        {
            if (willPerform)
            {
                if (_backgroundTaskIdentifier != TGIOS3BackgroundTaskInvalid)
                {
                    TGIOS3BackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
                    _backgroundTaskIdentifier = TGIOS3BackgroundTaskInvalid;
                    TGIOS3EndBackgroundTask([UIApplication sharedApplication], identifier);
                }
                if (_backgroundTaskExpirationTimer != nil)
                {
                    if ([_backgroundTaskExpirationTimer isValid])
                        [_backgroundTaskExpirationTimer invalidate];
                    _backgroundTaskExpirationTimer = nil;
                }
            }
        });
    }];
}

- (void)processPossibleCallRequest:(NSDictionary *)dict
{
    if (dict[@"call_id"] == nil)
        return;
    
    UIApplication *application = [UIApplication sharedApplication];
    if ([application applicationState] != UIApplicationStateActive)
    {
        TGIOS3BackgroundTaskIdentifier taskIdentifier = TGIOS3BeginBackgroundTask(application, ^
        {
            if (_inBackground)
            {
                [[TGTelegramNetworking instance] pause];
            }
        });
        
        if (_backgroundTaskIdentifier != TGIOS3BackgroundTaskInvalid)
        {
            TGIOS3BackgroundTaskIdentifier identifier = _backgroundTaskIdentifier;
            _backgroundTaskIdentifier = TGIOS3BackgroundTaskInvalid;
            TGIOS3EndBackgroundTask(application, identifier);
        }
        if (_backgroundTaskExpirationTimer != nil)
        {
            if ([_backgroundTaskExpirationTimer isValid])
                [_backgroundTaskExpirationTimer invalidate];
            _backgroundTaskExpirationTimer = nil;
        }
        
        [[[[[TGTelegraphInstance.callManager incomingCallInternalIds] take:1] mapToSignal:^SSignal *(NSNumber *internalId) {
            return [[TGTelegraphInstance.callManager endedIncomingCallInternalIds] filter:^bool(NSNumber *endedInternalId) {
                return [internalId isEqual:endedInternalId];
            }];
        }] deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next)
        {
            TGIOS3EndBackgroundTask(application, taskIdentifier);
            
            TGDispatchAfter(2.0, dispatch_get_main_queue(), ^
            {
                if (_inBackground)
                {
                    [[TGTelegramNetworking instance] pause];
                }
            });
        }];
        
        [[TGTelegramNetworking instance] resume];
        [[TGTelegramNetworking instance] wakeUpWithCompletion:^{}];
    }
}

- (void)processPossibleCloudKitNotification:(NSDictionary *)userInfo {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 && !defined(ONEGRAM_DISABLE_ICLOUD_ACCOUNT_SERVICES)
    if (iosMajorVersion() >= 10) {
        CKNotification *notification = [CKNotification notificationFromRemoteNotificationDictionary:userInfo];
        if (notification != nil) {
            [TGICloudEmergencyDataSignals processNotification:notification];
        }
    }
#else
    (void)userInfo;
#endif
}

- (void)processPossibleConfigUpdateNotification:(NSDictionary *)userInfo
{
    if (userInfo[@"dc"] != nil && [userInfo[@"dc"] respondsToSelector:@selector(intValue)] && userInfo[@"addr"] != nil && [userInfo[@"addr"] respondsToSelector:@selector(rangeOfString:)])
    {
        int datacenterId = [userInfo[@"dc"] intValue];
        
        NSString *addr = userInfo[@"addr"];
        NSRange range = [addr rangeOfString:@":"];
        if (range.location != NSNotFound)
        {
            NSString *ip = [addr substringWithRange:NSMakeRange(0, range.location)];
            int port = [[addr substringWithRange:NSMakeRange(range.location + 1, addr.length - range.location - 1)] intValue];
            
            
            if (ip.length != 0)
            {
                NSData *secret = nil;
                if ([userInfo[@"sec"] respondsToSelector:@selector(characterAtIndex:)]) {
                    secret = [(NSString *)userInfo[@"sec"] dataByDecodingHexString];
                }
                [[TGTelegramNetworking instance] mergeDatacenterAddress:datacenterId address:[[MTDatacenterAddress alloc] initWithIp:ip port:(uint16_t)(port == 0 ? 443 : port) preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:secret]];
            }
        }
    }
}

- (NSUInteger)application:(UIApplication *)__unused application supportedInterfaceOrientationsForWindow:(UIWindow *)__unused window
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? UIInterfaceOrientationMaskAllButUpsideDown : UIInterfaceOrientationMaskAll;
}

- (void)reloadSettingsController:(int)uid
{
    TGAccountSettingsController *accountSettingsController = [[TGAccountSettingsController alloc] initWithUid:uid];
    NSArray *currentViewControllers = _rootController.mainTabsController.viewControllers;
    NSUInteger index = NSNotFound;
    for (NSUInteger i = 0; i < currentViewControllers.count; i++)
    {
        if ([[currentViewControllers objectAtIndex:i] isKindOfClass:[TGAccountSettingsController class]])
        {
            index = i;
            break;
        }
    }

    _rootController.accountSettingsController = accountSettingsController;

    if (index != NSNotFound)
    {
        NSUInteger selectedIndex = [_rootController.mainTabsController logicalSelectedIndex];
        NSMutableArray *viewControllers = [currentViewControllers mutableCopy];
        [viewControllers replaceObjectAtIndex:index withObject:accountSettingsController];
        [_rootController.mainTabsController setViewControllers:viewControllers animated:false];
        if (selectedIndex < viewControllers.count)
            [_rootController.mainTabsController setSelectedIndex:selectedIndex];
    }
}

- (BOOL)application:(UIApplication *)__unused application openURL:(NSURL *)url sourceApplication:(NSString *)__unused sourceApplication annotation:(id)__unused annotation
{
    [self handleOpenDocument:url animated:false keepStack:false bundleId:sourceApplication];
    
    return true;
}

- (BOOL)application:(UIApplication *)__unused application openURL:(NSURL *)url options:(NSDictionary *)__unused options {
    [self handleOpenDocument:url animated:false keepStack:false bundleId:options[UIApplicationOpenURLOptionsSourceApplicationKey]];
    
    return true;
}

- (void)resetControllerStack
{
    [TGAppDelegateInstance.rootController clearContentControllers];
}

- (void)handleOpenDocument:(NSURL *)url animated:(bool)animated {
    [self handleOpenDocument:url animated:animated keepStack:false];
}

- (void)handleOpenDocument:(NSURL *)url animated:(bool)__unused animated keepStack:(bool)keepStack {
    [self handleOpenDocument:url animated:animated keepStack:keepStack bundleId:nil];
}

- (void)handleOpenDocument:(NSURL *)url animated:(bool)__unused animated keepStack:(bool)keepStack bundleId:(NSString *)bundleId
{
    bool isProxy = false;
    bool isPassport = false;
    
    if ([url.scheme isEqualToString:@"telegram"] || [url.scheme isEqualToString:@"tg"]) {
        NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:[url query]];
        
        if ([url.resourceSpecifier hasPrefix:@"//socks?"] || [url.resourceSpecifier hasPrefix:@"//proxy?"]) {
            isProxy = true;
        }
        
        if ([url.resourceSpecifier hasPrefix:@"//passport?"] || [url.resourceSpecifier hasPrefix:@"//passport/?"] || (([url.resourceSpecifier hasPrefix:@"//resolve?"] || [url.resourceSpecifier hasPrefix:@"//resolve/?"]) && [dict[@"domain"] respondsToSelector:@selector(characterAtIndex:)] && [dict[@"domain"] isEqualToString:@"telegrampassport"])) {
            isPassport = true;
        }
    }

    
    if ((TGTelegraphInstance.clientUserId != 0 && TGTelegraphInstance.clientIsActivated) || isProxy || isPassport)
    {
        if ([url isFileURL])
        {
            [self resetControllerStack];
            
            NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[url path] error:nil];
            
            if (attributes != nil)
            {
                int fileSize = [[attributes objectForKey:NSFileSize] intValue];
                
                TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithDocumentFile:url size:fileSize];
                TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[forwardController]];
                [TGAppDelegateInstance.rootController dismissViewControllerAnimated:false completion:nil];
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    [TGAppDelegateInstance.rootController presentViewController:navigationController animated:false completion:nil];
                });
            }
        }
        else if ([url.scheme isEqualToString:@"telegram"] || [url.scheme isEqualToString:@"tg"])
        {
            NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:[url query]];
            
            if ([url.host isEqualToString:@"share"])
            {
                NSMutableArray *uploadFileArray = [[NSMutableArray alloc] init];
                NSMutableArray *forwardMessageArray = [[NSMutableArray alloc] init];
                NSMutableArray *sendMessageArray = [[NSMutableArray alloc] init];
                
                NSString *groupName = [@"group." stringByAppendingString:[[NSBundle mainBundle] bundleIdentifier]];
                
                NSURL *groupURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupName];
                if (groupURL != nil)
                {
                    NSURL *inboxUrl = [groupURL URLByAppendingPathComponent:@"share-inbox" isDirectory:true];
                    
                    [[NSFileManager defaultManager] createDirectoryAtURL:inboxUrl withIntermediateDirectories:true attributes:nil error:nil];
                    
                    NSUInteger counter = 0;
                    while (true)
                    {
                        NSString *fileId = [[NSString alloc] initWithFormat:@"f%d", (int)counter];
                        if (dict[fileId] != nil)
                        {
                            NSURL *fileUrl = [inboxUrl URLByAppendingPathComponent:dict[fileId]];
                            
                            NSString *fileType = @"raw";
                            NSString *rawFileType = dict[[[NSString alloc] initWithFormat:@"t%d", (int)counter]];
                            
                            if ([rawFileType isEqualToString:@"i"])
                                fileType = @"image";
                            else if ([rawFileType isEqualToString:@"v"])
                                fileType = @"video";
                            
                            NSString *fileName = dict[[[NSString alloc] initWithFormat:@"n%d", (int)counter]];
                            
                            [uploadFileArray addObject:@{@"url": fileUrl, @"type": fileType, @"fileName": fileName == nil ? @"" : fileName}];
                            
                            counter++;
                        }
                        else
                        {
                            NSString *internalMessageIdString = dict[[[NSString alloc] initWithFormat:@"m%d", (int)counter]];
                            if (internalMessageIdString != nil)
                            {
                                TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:[internalMessageIdString intValue] peerId:0];
                                if (message == nil)
                                {
                                    message = [TGDatabaseInstance() loadMediaMessageWithMid:[internalMessageIdString intValue]];
                                }
                                
                                if (message != nil)
                                    [forwardMessageArray addObject:message];
                                
                                counter++;
                            }
                            else
                            {
                                NSString *urlString = dict[[[NSString alloc] initWithFormat:@"u%d", (int)counter]];
                                if (urlString != nil)
                                {
                                    TGMessage *message = [[TGMessage alloc] init];
                                    message.text = urlString;
                                    [sendMessageArray addObject:message];
                                    
                                    counter++;
                                }
                                else
                                    break;
                            }
                        }
                    }
                }
                
                if (uploadFileArray.count != 0)
                {
                    TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithDocumentFiles:uploadFileArray];
                    forwardController.controllerTitle = TGLocalized(@"Share.Title");
                    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[forwardController]];
                    
                    [_rootController clearContentControllers];
                    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                    {
                        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [_rootController presentViewController:navigationController animated:false completion:nil];
                    });
                }
                else if (forwardMessageArray.count != 0 || sendMessageArray.count != 0)
                {
                    TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithForwardMessages:forwardMessageArray sendMessages:sendMessageArray shareLink:nil showSecretChats:true];
                    
                    forwardController.controllerTitle = TGLocalized(@"Share.Title");
                    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[forwardController]];
                    
                    [_rootController clearContentControllers];
                    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                    {
                        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [_rootController presentViewController:navigationController animated:false completion:nil];
                    });
                }
            }
            else if ([url.host isEqualToString:@"msg"])
            {
                std::map<int, int> phoneIdToUid;
                [TGDatabaseInstance() loadRemoteContactUidsContactIds:phoneIdToUid];
                
                if ([dict[@"to"] respondsToSelector:@selector(characterAtIndex:)] && [(NSString *)dict[@"to"] length] != 0)
                {
                    int32_t phoneId = phoneMatchHash(dict[@"to"]);
                    
                    for (auto it : phoneIdToUid)
                    {
                        if (it.first == phoneId)
                        {
                            NSDictionary *actions = nil;
                            if ([dict[@"text"] respondsToSelector:@selector(characterAtIndex:)] && [(NSString *)dict[@"text"] length] != 0)
                            {
                                actions = @{@"text": dict[@"text"]};
                            }
                            [[TGInterfaceManager instance] navigateToConversationWithId:it.second conversation:nil performActions:actions animated:false];
                            
                            break;
                        }
                    }
                }
                else if ([dict[@"text"] respondsToSelector:@selector(characterAtIndex:)] && [(NSString *)dict[@"text"] length] != 0)
                {
                    TGMessage *message = [[TGMessage alloc] init];
                    message.text = dict[@"text"];
                    
                    TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithForwardMessages:nil sendMessages:@[message] shareLink:nil showSecretChats:true];
                    
                    [self resetControllerStack];
                    
                    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[forwardController]];
                    
                    [_rootController clearContentControllers];
                    [_rootController dismissViewControllerAnimated:false completion:nil];
                    
                    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                    {
                        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                    }
                    
                    [_rootController presentViewController:navigationController animated:false completion:nil];
                }
            }
            else if ([url.host isEqualToString:@"download-language"])
            {
                if ([dict[@"url"] respondsToSelector:@selector(characterAtIndex:)])
                {
                    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/downloadLocalization/(%d)", murMurHash32(dict[@"url"])] options:@{@"url": dict[@"url"]} flags:0 watcher:TGTelegraphInstance];
                }
            }
            else if (isPassport)
            {
                int32_t botId = [dict[@"bot_id"] respondsToSelector:@selector(intValue)] ? [dict[@"bot_id"] intValue] : 0;
                NSString *scope = [dict[@"scope"] respondsToSelector:@selector(characterAtIndex:)] ? dict[@"scope"] : nil;
                
                NSString *callbackUrl = dict[@"callback_url"];
                NSString *publicKey = dict[@"public_key"];
                
                NSString *payload = dict[@"payload"];
                NSString *nonce = dict[@"nonce"];
                
                __weak TGAppDelegate *weakSelf = self;
                void (^displayRequestBlock)(void) =
                ^{
                    __strong TGAppDelegate *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    TGRootController *rootController = strongSelf->_rootController;
                    if ([rootController.presentedViewController isKindOfClass:[TGNavigationController class]])
                    {
                        TGNavigationController *navigationController = (TGNavigationController *)rootController.presentedViewController;
                        if ([navigationController.topViewController isKindOfClass:[TGPassportRequestController class]])
                            return;
                    }
                    
                    TGPassportFormRequest *formRequest = [[TGPassportFormRequest alloc] initWithBotId:botId scope:scope publicKey:publicKey bundleId:bundleId callbackUrl:callbackUrl nonce:nonce payload:payload];
                    TGPassportRequestController *controller = [[TGPassportRequestController alloc] initWithFormRequest:formRequest];
                    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller]];
                    navigationController.restrictLandscape = true;
                    [rootController clearContentControllers];
                    [rootController dismissViewControllerAnimated:false completion:nil];
                    
                    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                    {
                        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                    }
                    
                    [rootController presentViewController:navigationController animated:true completion:nil];
                };
                
                if (TGTelegraphInstance.clientUserId != 0)
                {
                    dispatch_async(dispatch_get_main_queue(), ^
                    {
                        [TGCustomAlertView dismissAllAlertViews];
                    });
                    displayRequestBlock();
                }
                else
                {
                    NSString *error = @"USER_NOT_LOGGED_IN";
                    NSString *errorText = TGLocalized(@"Passport.NotLoggedInMessage");
                    
                    TGCustomAlertView *alertView = [TGCustomAlertView presentAlertWithTitle:nil message:errorText cancelButtonTitle:TGLocalized(@"Common.NotNow") okButtonTitle:TGLocalized(@"Common.OK") completionBlock:^(bool okButtonPressed)
                     {
                         if (okButtonPressed)
                         {
                             TGNavigationController *loginController = TGAppDelegateInstance.loginNavigationController;
                             if (TGAppDelegateInstance.window.rootViewController == loginController || loginController.presentingViewController != nil)
                             {
                                 if (![loginController.topViewController isKindOfClass:[TGLoginPhoneController class]])
                                     [loginController pushViewController:[[TGLoginPhoneController alloc] init] animated:true];
                             }
                             self.onSuccessfulLogin = [displayRequestBlock copy];
                         }
                         else if (callbackUrl.length > 0)
                         {
                             NSString *url = nil;
                             if ([callbackUrl hasPrefix:@"tgbot"]) {
                                 url = [NSString stringWithFormat:@"tgbot%d://passport/error?error=%@", botId, error];
                             } else {
                                 url = [TGPassportRequestController urlString:callbackUrl byAppendingQueryString:[NSString stringWithFormat:@"tg_passport=error&error=%@", error]];
                             }
                             [(TGApplication *)[TGApplication sharedApplication] nativeOpenURL:[NSURL URLWithString:url]];
                         }
                     }];
                    alertView.noActionOnDimTap = true;
                }
            }
            else if ([url.host isEqualToString:@"resolve"])
            {
                if ([dict[@"domain"] respondsToSelector:@selector(characterAtIndex:)])
                {
                    if (!keepStack || ![_rootController.presentedViewController isKindOfClass:[TGHashtagOverviewController class]])
                        [_rootController dismissViewControllerAnimated:false completion:nil];
                    
                    NSMutableDictionary *arguments = [[NSMutableDictionary alloc] init];
                    if (dict[@"start"] != nil)
                        arguments[@"start"] = dict[@"start"];
                    if (dict[@"startgroup"] != nil)
                        arguments[@"startgroup"] = dict[@"startgroup"];
                    if (dict[@"game"] != nil)
                        arguments[@"game"] = dict[@"game"];
                    if (dict[@"post"] != nil) {
                        arguments[@"messageId"] = @([dict[@"post"] intValue]);
                    }
                    if ([url.absoluteString rangeOfString:@"&single"].location != NSNotFound)
                        arguments[@"single"] = @true;
                    
                    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/resolveDomain/(%@)", dict[@"domain"]] options:@{@"domain": dict[@"domain"], @"arguments": arguments, @"keepStack": @(keepStack)} flags:0 watcher:TGTelegraphInstance];
                }
            }
            else if ([url.host isEqualToString:@"join"])
            {
                if ([dict[@"invite"] respondsToSelector:@selector(characterAtIndex:)])
                {
                    [_rootController dismissViewControllerAnimated:false completion:nil];
                    
                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                    [progressWindow show:true];
                    
                    [[[[TGGroupManagementSignals groupInvitationLinkInfo:dict[@"invite"]] deliverOn:[SQueue mainQueue]] onDispose:^
                    {
                        TGDispatchOnMainThread(^
                        {
                            [progressWindow dismiss:true];
                        });
                    }] startWithNext:^(TGGroupInvitationInfo *invitationInfo)
                    {
                        if (invitationInfo.alreadyAccepted && !invitationInfo.left)
                        {
                            if (invitationInfo.peerId != 0) {
                                [[TGInterfaceManager instance] navigateToConversationWithId:invitationInfo.peerId conversation:nil performActions:nil atMessage:nil clearStack:!keepStack openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
                            } else {
                                NSString *format = TGLocalized(@"GroupInfo.InvitationLinkAlreadyAccepted");
                                NSString *text = [[NSString alloc] initWithFormat:format, invitationInfo.title];
                                [TGCustomAlertView presentAlertWithTitle:nil message:text cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                            }
                        }
                        else
                        {
                            if (invitationInfo.users != nil && (!invitationInfo.isChannel || invitationInfo.isChannelGroup)) {
                                [_groupInviteSheet dismissAnimated:true completion:nil];
                                
                                _groupInviteSheet = [[TGGroupInviteSheet alloc] initWithTitle:invitationInfo.title photoUrlSmall:[invitationInfo.avatarInfo closestImageUrlWithSize:CGSizeZero resultingSize:NULL] userCount:invitationInfo.userCount users:invitationInfo.users join:^{
                                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                                    [progressWindow show:true];
                                    
                                    [[[[TGGroupManagementSignals acceptGroupInvitationLink:dict[@"invite"]] deliverOn:[SQueue mainQueue]] onDispose:^
                                      {
                                          TGDispatchOnMainThread(^
                                                                 {
                                                                     [progressWindow dismiss:true];
                                                                 });
                                      }] startWithNext:^(TGConversation *conversation)
                                     {
                                         [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:conversation.isChannel ? conversation : nil performActions:nil atMessage:nil clearStack:!keepStack openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
                                     } error:^(__unused id error)
                                     {
                                         NSString *text = TGLocalized(@"GroupInfo.InvitationLinkDoesNotExist");
                                         if ([error respondsToSelector:@selector(characterAtIndex:)])
                                         {
                                             if ([error isEqualToString:@"USERS_TOO_MUCH"])
                                                 text = TGLocalized(@"GroupInfo.InvitationLinkGroupFull");
                                         }
                                        [TGCustomAlertView presentAlertWithTitle:nil message:text cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                                     } completed:nil];
                                }];
                                _groupInviteSheet.dismissalBlock = ^{
                                    TGAppDelegateInstance->_groupInviteSheet.rootViewController = nil;
                                    TGAppDelegateInstance->_groupInviteSheet = nil;
                                };
                                
                                _groupInviteSheet.view.cancel = ^{
                                    [TGAppDelegateInstance->_groupInviteSheet dismissAnimated:true completion:nil];
                                    TGAppDelegateInstance->_groupInviteSheet = nil;
                                };
                                
                                [_groupInviteSheet showAnimated:true completion:nil];
                            } else {
                                NSString *format = TGLocalized(@"GroupInfo.InvitationLinkAcceptChannel");
                                NSString *text = [[NSString alloc] initWithFormat:format, invitationInfo.title];
                                [TGCustomAlertView presentAlertWithTitle:nil message:text cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.OK") completionBlock:^(bool okButtonPressed)
                                {
                                    if (okButtonPressed)
                                    {
                                        TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                                        [progressWindow show:true];
                                        
                                        [[[[TGGroupManagementSignals acceptGroupInvitationLink:dict[@"invite"]] deliverOn:[SQueue mainQueue]] onDispose:^
                                        {
                                            TGDispatchOnMainThread(^
                                            {
                                                [progressWindow dismiss:true];
                                            });
                                        }] startWithNext:^(TGConversation *conversation)
                                        {
                                            [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:conversation.isChannel ? conversation : nil performActions:nil atMessage:nil clearStack:!keepStack openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
                                        } error:^(__unused id error)
                                        {
                                            NSString *text = TGLocalized(@"GroupInfo.InvitationLinkDoesNotExist");
                                            if ([error respondsToSelector:@selector(characterAtIndex:)])
                                            {
                                                if ([error isEqualToString:@"USERS_TOO_MUCH"])
                                                    text = TGLocalized(@"GroupInfo.InvitationLinkGroupFull");
                                            }
                                            [TGCustomAlertView presentAlertWithTitle:nil message:text cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                                        } completed:nil];
                                    }
                                }];
                            }
                        }
                    } error:^(id error)
                    {
                        NSString *text = TGLocalized(@"GroupInfo.InvitationLinkDoesNotExist");
                        if ([error respondsToSelector:@selector(characterAtIndex:)])
                        {
                            if ([error isEqualToString:@"USER_ALREADY_PARTICIPANT"])
                                text = TGLocalized(@"GroupInfo.InvitationLinkAlreadyAccepted");
                        }
                        [TGCustomAlertView presentAlertWithTitle:nil message:text cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                    } completed:nil];
                }
            }
            else if ([url.host isEqualToString:@"addstickers"])
            {
                if ([dict[@"set"] respondsToSelector:@selector(characterAtIndex:)])
                {
                    TGStickerPackShortnameReference *packReference = [[TGStickerPackShortnameReference alloc] initWithShortName:dict[@"set"]];
                    [self previewStickerPackWithReference:packReference];
                }
            }
            else if ([url.host isEqualToString:@"msg_url"])
            {
                if ([dict[@"url"] respondsToSelector:@selector(characterAtIndex:)]) {
                    NSMutableDictionary *linkInfo = [[NSMutableDictionary alloc] init];
                    NSString *url = dict[@"url"];
                    if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"]) {
                        void (^presentForwardController)(TGForwardTargetController *) = ^(TGForwardTargetController *forwardController)
                        {
                            forwardController.skipConfirmation = true;
                            
                            [self resetControllerStack];
                            
                            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[forwardController]];
                            
                            [_rootController clearContentControllers];
                            [_rootController dismissViewControllerAnimated:false completion:nil];
                            
                            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                            {
                                navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                                navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                            }
                            
                            [_rootController presentViewController:navigationController animated:false completion:nil];
                        };
                        
                        NSURL *concreteURL = [NSURL URLWithString:url];
                        if ([concreteURL.host isEqualToString:@"telesco.pe"])
                        {
                            if (concreteURL.pathComponents.count >= 3)
                            {
                                NSString *username = concreteURL.pathComponents[1];
                                int32_t messageId = (int32_t)[concreteURL.pathComponents[2] integerValue];
                                
                                if (username.length > 0 && messageId != 0)
                                {
                                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
                                    [progressWindow showWithDelay:0.2];
                                    
                                    [[[TGChannelManagementSignals resolveChannelWithUsername:username] mapToSignal:^SSignal *(TGConversation *channel) {
                                        return [TGChannelManagementSignals preloadedChannelAtMessage:channel.conversationId messageId:messageId];
                                    }] startWithNext:^(TGConversation *channel)
                                    {
                                        TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:channel.conversationId];
                                        if (message != nil)
                                        {
                                            TGDispatchOnMainThread(^
                                            {
                                                [progressWindow dismiss:true];
                                                TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithForwardMessages:@[ message ] sendMessages:nil shareLink:nil showSecretChats:true];
                                                presentForwardController(forwardController);
                                            });
                                        }
                                    } error:^(__unused id error)
                                    {
                                        TGDispatchOnMainThread(^
                                        {
                                            [progressWindow dismiss:true];
                                        });
                                    } completed:nil];
                                    return;
                                }
                            }
                        }

                        linkInfo[@"url"] = url;
                        
                        if ([dict[@"text"] respondsToSelector:@selector(characterAtIndex:)]) {
                            linkInfo[@"text"] = dict[@"text"];
                        }
                        
                        TGForwardTargetController *forwardController = [[TGForwardTargetController alloc] initWithForwardMessages:nil sendMessages:nil shareLink:linkInfo showSecretChats:true];
                        presentForwardController(forwardController);
                    }
                }
            }
            else if ([url.host isEqualToString:@"confirmphone"])
            {
                if ([dict[@"hash"] respondsToSelector:@selector(characterAtIndex:)]) {
                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
                    [progressWindow showWithDelay:0.1];
                    [[[[TGAccountSignals requestConfirmationForPhoneWithHash:dict[@"hash"]] deliverOn:[SQueue mainQueue]] onDispose:^{
                        TGDispatchOnMainThread(^{
                            [progressWindow dismiss:true];
                        });
                    }] startWithNext:^(TGConfirmationCodeData *codeData) {
                        TGCancelAccountResetController *cancelResetController = [[TGCancelAccountResetController alloc] initWithPhoneHash:codeData.codeHash timeout:codeData.timeout];
                        
                        TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[cancelResetController]];
                        
                        [_rootController dismissViewControllerAnimated:false completion:nil];
                        
                        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                        {
                            navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
                            navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                        }
                        
                        [_rootController presentViewController:navigationController animated:true completion:nil];
                    } error:^(__unused id error) {
                        [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Login.UnknownError") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                    } completed:nil];
                }
            }
            else if ([url.host isEqualToString:@"user"])
            {
                if ([dict[@"id"] respondsToSelector:@selector(characterAtIndex:)])
                {
                    NSInteger uid = [dict[@"id"] integerValue];
                    [[TGInterfaceManager instance] navigateToConversationWithId:uid conversation:nil performActions:nil animated:false];
                }
            }
            else if ([url.host isEqualToString:@"gshare"])
            {
                if ([dict[@"h"] respondsToSelector:@selector(characterAtIndex:)])
                {
                    int64_t randomId = [(NSString *)dict[@"h"] longLongValue];
                    TGWebAppControllerShareGameData *shareData = ((TGApplication *)[UIApplication sharedApplication]).gameShareDict[@(randomId)];
                    if (shareData != nil) {
                        UIViewController *topController = self.rootController.viewControllers.lastObject;
                        if (self.rootController.presentedViewController != nil) {
                            topController = self.rootController.presentedViewController;
                        }
                        if (topController != nil) {
                            [TGWebAppController presentShare:shareData parentController:topController withScore:true];
                        }
                    }
                }
            }
            else if ([url.host isEqualToString:@"socks"]) {
                if ([dict[@"server"] respondsToSelector:@selector(characterAtIndex:)] && [dict[@"port"] respondsToSelector:@selector(intValue)]) {
                    NSString *username = nil;
                    NSString *password = nil;
                    
                    if ([dict[@"user"] respondsToSelector:@selector(characterAtIndex:)] && [dict[@"pass"] respondsToSelector:@selector(characterAtIndex:)]) {
                        username = dict[@"user"];
                        password = dict[@"pass"];
                    }
                    
                    TGProxyItem *proxy = [[TGProxyItem alloc] initWithServer:dict[@"server"] port:(uint16_t)[dict[@"port"] intValue] username:username password:password secret:nil];
                    UIViewController *controller = self.rootController;
                    if (controller.presentedViewController != nil)
                        controller = controller.presentedViewController;
                    __weak UIView *weakSourceView = controller.view;
                    [TGProxyMenu presentInParentController:(TGViewController *)controller menuController:nil proxy:proxy sourceView:controller.view sourceRect:^CGRect
                    {
                        __strong UIView *strongSourceView = weakSourceView;
                        return CGRectMake(CGRectGetMidX(strongSourceView.frame), CGRectGetMidY(strongSourceView.frame), 0, 0);
                    }];
                }
            }
            else if ([url.host isEqualToString:@"proxy"]) {
                [self.rootController.view endEditing:true];
                
                NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:[url query]];
                if ([dict[@"server"] respondsToSelector:@selector(characterAtIndex:)] && [dict[@"port"] respondsToSelector:@selector(intValue)]) {
                    NSString *secret = nil;
                    if ([dict[@"secret"] respondsToSelector:@selector(characterAtIndex:)]) {
                        secret = dict[@"secret"];
                    }
                    
                    TGProxyItem *proxy = [[TGProxyItem alloc] initWithServer:dict[@"server"] port:(uint16_t)[dict[@"port"] intValue] username:nil password:nil secret:secret];
                    UIViewController *controller = self.rootController;
                    if (controller.presentedViewController != nil)
                        controller = controller.presentedViewController;
                    __weak UIView *weakSourceView = controller.view;
                    [TGProxyMenu presentInParentController:(TGViewController *)controller menuController:nil proxy:proxy sourceView:controller.view sourceRect:^CGRect
                    {
                        __strong UIView *strongSourceView = weakSourceView;
                        return CGRectMake(CGRectGetMidX(strongSourceView.frame), CGRectGetMidY(strongSourceView.frame), 0, 0);
                    }];
                }
            }
            else {
                NSString *path = url.host;
                
                TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
                [progressWindow showWithDelay:0.1];

                [[[[TGServiceSignals deepLinkInfo:path] deliverOn:[SQueue mainQueue]] onDispose:^{
                    TGDispatchOnMainThread(^{
                        [progressWindow dismiss:true];
                    });
                }] startWithNext:^(TGDeepLinkInfo *linkInfo) {
                    NSString *cancelTitle = linkInfo.updateNeeded ? TGLocalized(@"Common.NotNow") : TGLocalized(@"Common.OK");
                    NSString *okTitle = linkInfo.updateNeeded ? TGLocalized(@"Application.Update") : nil;
                    [TGCustomAlertView presentAlertWithTitle:nil message:linkInfo.message cancelButtonTitle:cancelTitle okButtonTitle:okTitle completionBlock:^(bool okButtonPressed)
                    {
                        if (okButtonPressed)
                        {
                            NSNumber *appStoreId = @686449807;
#ifdef TELEGRAM_APPSTORE_ID
                            appStoreId = TELEGRAM_APPSTORE_ID;
#endif
                            NSURL *appStoreURL = [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@", appStoreId]];
                            [[UIApplication sharedApplication] openURL:appStoreURL];
                        }
                    }];
                } error:^(__unused id error) {
                    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"Login.UnknownError") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                } completed:nil];
            }
        }
        else if ([url.scheme isEqualToString:[TGDropboxHelper dropboxURLScheme]])
        {
            [TGDropboxHelper handleOpenURL:url];
        }
    }
}

- (NSString *)stickerPackShortname:(TGStickerPack *)stickerPack
{
    NSString *shortName = nil;
    if ([stickerPack.packReference isKindOfClass:[TGStickerPackIdReference class]])
        shortName = ((TGStickerPackIdReference *)stickerPack.packReference).shortName;
    else if ([stickerPack.packReference isKindOfClass:[TGStickerPackShortnameReference class]])
        shortName = ((TGStickerPackShortnameReference *)stickerPack.packReference).shortName;
    return shortName;
}

- (void)previewStickerPackWithReference:(id<TGStickerPackReference>)packReference
{
    UIViewController *controller = self.rootController;
    if (controller.presentedViewController != nil)
        controller = controller.presentedViewController;
    
    [controller.view endEditing:true];
    [TGStickersMenu presentInParentController:(TGViewController *)controller stickerPackReference:packReference showShareAction:false sendSticker:nil stickerPackRemoved:nil stickerPackHidden:nil sourceView:controller.view centered:true];
}

- (void)readyToApplyLocalizationFromFile:(NSString *)filePath warnings:(NSString *)warnings
{
    [TGCustomAlertView presentAlertWithTitle:nil message:warnings.length == 0 ? @"Apply Localization?" : [NSString stringWithFormat:@"%@\n\nApply Localization?", warnings] cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.OK") completionBlock:^(bool okButtonPressed)
    {
        if (okButtonPressed)
        {
            TGSetLocalizationFromFile(filePath);
            [TGAppDelegateInstance resetLocalization];
            
            [self resetControllerStack];
        }
    }];
}

- (BOOL)application:(UIApplication *)__unused application willContinueUserActivityWithType:(NSString *)userActivityType
{
    if ([userActivityType isEqualToString:@"dev.IllyaGIF.Onegram.conversation"]) {
        if (_progressWindow != nil) {
            [_progressWindow dismiss:true];
        }
        
        _progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_progressWindow show:true];
    }
    
    return true;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
- (BOOL)application:(UIApplication *)__unused application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))__unused restorationHandler
{
    [_progressWindow dismiss:true];
    
    if ([userActivity.activityType isEqualToString:@"NSUserActivityTypeBrowsingWeb"]) {
        [application openURL:userActivity.webpageURL];
    } else if ([userActivity.activityType isEqualToString:@"dev.IllyaGIF.Onegram.conversation"]) {
        if ([userActivity.userInfo[@"user_id"] intValue] == TGTelegraphInstance.clientUserId)
        {
            int64_t peerId = 0;
            
            if ([userActivity.userInfo[@"peer"][@"type"] isEqual:@"user"])
                peerId = [userActivity.userInfo[@"peer"][@"id"] intValue];
            else if ([userActivity.userInfo[@"peer"][@"type"] isEqual:@"group"])
                peerId = -[userActivity.userInfo[@"peer"][@"id"] intValue];
            
            if (peerId != 0)
            {
                [[TGInterfaceManager instance] navigateToConversationWithId:peerId conversation:nil performActions:userActivity.userInfo[@"text"] == nil ? nil : @{@"text": userActivity.userInfo[@"text"]} animated:false];
                
                bool didSetText = false;
                TGModernConversationController *controller = [[TGInterfaceManager instance] currentControllerWithPeerId:peerId];
                if (controller != nil)
                    didSetText = TGStringCompare(userActivity.userInfo[@"text"], [controller inputText]);
                
                if (didSetText)
                {
                    [userActivity getContinuationStreamsWithCompletionHandler:^(__unused NSInputStream *inputStream, NSOutputStream *outputStream, NSError *error)
                    {
                        if (error == nil)
                        {
                            @try {
                                [outputStream open];
                                [outputStream close];
                            }
                            @catch (NSException *exception) {
                            }
                            @finally {
                            }
                        }
                    }];
                }
            }
        }
    } else if ([userActivity.activityType isEqual:CSSearchableItemActionType]) {
        NSString *uniqueIdentifier = userActivity.userInfo[CSSearchableItemActivityIdentifier];
        if (uniqueIdentifier != nil) {
            int64_t peerId = [uniqueIdentifier longLongValue];
            if (peerId != 0) {
                if (peerId != 0) {
                    [[TGInterfaceManager instance] navigateToConversationWithId:peerId conversation:nil performActions:nil animated:false];
                }
            }
        }
    }
    
    return true;
}

#endif

- (void)handleOpenInstantView:(NSString *)url disableActions:(bool)disableActions {
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    [progressWindow showWithDelay:0.1];
    
    SSignal *signal = disableActions ? [TGWebpageSignals updatedWebpageForUrl:url] : [TGWebpageSignals webpagePreview:url];
    
    [[[[signal take:1] onDispose:^{
        TGDispatchOnMainThread(^{
            [progressWindow dismiss:true];
        });
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(TGWebPageMediaAttachment *webpage) {
        if (webpage.instantPage != nil) {
            if (TGAppDelegateInstance.rootController.presentedViewController != nil && ![TGAppDelegateInstance.rootController.presentedViewController isKindOfClass:[TGNavigationController class]]) {
                [TGAppDelegateInstance.rootController dismissViewControllerAnimated:false completion:nil];
            }
            TGInstantPageController *controller = [[TGInstantPageController alloc] initWithWebPage:webpage anchor:[url urlAnchorPart] peerId:0 messageId:0];
            controller.disableActions = disableActions;
            
            if ([TGAppDelegateInstance.rootController.presentedViewController isKindOfClass:[TGNavigationController class]])
            {
                [(TGNavigationController *)TGAppDelegateInstance.rootController.presentedViewController pushViewController:controller animated:true];
            }
            else
            {
                [TGAppDelegateInstance.rootController pushContentController:controller];
            }
        } else {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        }
    } error:^(__unused id error) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
    } completed:nil];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
- (void)application:(UIApplication *)__unused application didFailToContinueUserActivityWithType:(NSString *)__unused userActivityType error:(NSError *)__unused error
{
    [_progressWindow dismiss:true];
}

#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
- (void)application:(UIApplication *)__unused application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
    [_rootController.mainTabsController setSelectedIndex:2];
    
    if (_rootController.associatedWindowStack.count > 0)
    {
        for (TGOverlayControllerWindow *window in _rootController.associatedWindowStack)
        {
            if ([window isKindOfClass:[TGOverlayControllerWindow class]])
                [window dismiss];
        }
    }
    
    if ([shortcutItem.type isEqualToString:@"compose"])
    {
        [_rootController clearContentControllers];
        [_rootController.dialogListController.dialogListCompanion composeMessageAndOpenSearch:false];
    }
    else if ([shortcutItem.type isEqualToString:@"search"])
    {
        [_rootController clearContentControllers];
        [_rootController.dialogListController startSearch];
    }
    else if ([shortcutItem.type isEqualToString:@"camera"])
    {
        [_rootController clearContentControllers];
        [TGCameraController startShortcutCamera];
    }
    else if ([shortcutItem.type isEqualToString:@"conversation"])
    {
        NSDictionary *userInfo = shortcutItem.userInfo;
        NSNumber *cidValue = userInfo[@"cid"];
        if (cidValue != nil)
            [[TGInterfaceManager instance] navigateToConversationWithId:cidValue.longLongValue conversation:nil performActions:nil animated:false];
    }
    
    if (completionHandler != nil)
        completionHandler(true);
}

- (void)application:(UIApplication *)__unused application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo completionHandler:(void (^)())completionHandler
{
    [self application:application handleActionWithIdentifier:identifier forRemoteNotification:userInfo withResponseInfo:@{} completionHandler:completionHandler];
}

- (void)application:(UIApplication *)__unused application handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo withResponseInfo:( NSDictionary *)responseInfo completionHandler:( void (^)())completionHandler
{
    id nFromId = [userInfo objectForKey:@"from_id"];
    id nChatId = [userInfo objectForKey:@"chat_id"];
    id nContactId = [userInfo objectForKey:@"contact_id"];
    id nChannelId = [userInfo objectForKey:@"channel_id"];
    id nMid = [userInfo objectForKey:@"msg_id"];
    
    int64_t peerId = 0;
    int32_t mid = 0;
    
    if (nFromId != nil && [TGSchema canCreateIntFromObject:nFromId])
        peerId = [TGSchema intFromObject:nFromId];
    else if (nChatId != nil && [TGSchema canCreateIntFromObject:nChatId])
        peerId = -[TGSchema intFromObject:nChatId];
    else if (nContactId != nil && [TGSchema canCreateIntFromObject:nContactId])
        peerId = [TGSchema intFromObject:nContactId];
    else if (nChannelId != nil && [TGSchema canCreateIntFromObject:nChannelId])
        peerId = TGPeerIdFromChannelId([TGSchema intFromObject:nChannelId]);
    
    if (nMid != nil && [TGSchema canCreateIntFromObject:nMid])
        mid = [TGSchema intFromObject:nMid];
    
    [[_finishedLaunching.signal deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next)
    {
        if ([identifier isEqualToString:@"reply"])
            [self _replyActionForPeerId:peerId mid:mid openKeyboard:true responseInfo:responseInfo completion:completionHandler];
        else if ([identifier isEqualToString:@"like"])
            [self _likeActionForPeerId:peerId completion:completionHandler];
        else if ([identifier isEqualToString:@"mute"])
            [self _muteActionForPeerId:peerId duration:1 completion:completionHandler];
        else if ([identifier isEqualToString:@"mute8h"])
            [self _muteActionForPeerId:peerId duration:8 completion:completionHandler];
        else if ([identifier isEqualToString:@"call"])
            [self _callActionForPeerId:peerId completion:completionHandler];
        else if (completionHandler)
            completionHandler();
    }];
}

- (void)application:(UIApplication *)__unused application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification completionHandler:(void (^)())completionHandler
{
    [self application:application handleActionWithIdentifier:identifier forLocalNotification:notification withResponseInfo:@{} completionHandler:completionHandler];
}

- (void)application:(UIApplication *)__unused application handleActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)notification withResponseInfo:( NSDictionary *)responseInfo completionHandler:( void (^)())completionHandler
{
    NSDictionary *userInfo = OGPlatformLocalNotificationUserInfo(notification);
    int64_t peerId = [[userInfo objectForKey:@"cid"] longLongValue];
    int32_t mid = [[userInfo objectForKey:@"mid"] intValue];
    
    [[_finishedLaunching.signal deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next)
    {
        if ([identifier isEqualToString:@"reply"])
            [self _replyActionForPeerId:peerId mid:mid openKeyboard:true responseInfo:responseInfo completion:completionHandler];
        else if ([identifier isEqualToString:@"like"])
            [self _likeActionForPeerId:peerId completion:completionHandler];
        else if ([identifier isEqualToString:@"mute"])
            [self _muteActionForPeerId:peerId duration:1 completion:completionHandler];
        else if ([identifier isEqualToString:@"mute8h"])
            [self _muteActionForPeerId:peerId duration:8 completion:completionHandler];
        else if ([identifier isEqualToString:@"call"])
            [self _callActionForPeerId:peerId completion:completionHandler];
        else if (completionHandler)
            completionHandler();
    }];
}

- (void)_callActionForPeerId:(int64_t)peerId completion:(void (^)())completion
{
    if (peerId != 0)
        [[TGInterfaceManager instance] callPeerWithId:peerId];
    
    if (completion != nil)
        completion();
}

- (void)_replyActionForPeerId:(int64_t)peerId mid:(int32_t)mid openKeyboard:(bool)openKeyboard responseInfo:(NSDictionary *)responseInfo completion:(void (^)())completion
{
    if (iosMajorVersion() >= 9 && openKeyboard)
    {
        if (peerId == 0)
            return;
        
        int32_t replyToMid = 0;
        if (TGPeerIdIsGroup(peerId) || TGPeerIdIsChannel(peerId))
            replyToMid = mid;
        
        void (^suspendBlock)(bool) = ^(bool succeed)
        {
            if (succeed)
            {
                TGDispatchOnMainThread(^
                {
                    if (_inBackground && !TGTelegraphInstance.callManager.hasActiveCall)
                        [[TGTelegramNetworking instance] pause];
                    if (completion)
                        completion();
                });
            }
            else
            {
                [[TGTelegramNetworking instance] wakeUpWithCompletion:^
                {
                    TGDispatchOnMainThread(^
                    {
                        if (_inBackground && !TGTelegraphInstance.callManager.hasActiveCall)
                        {
                            [[TGTelegramNetworking instance] pause];
                            if (completion)
                                completion();
                        }
                    });
                }];
            }
        };
        
        NSString *text = responseInfo[UIUserNotificationActionResponseTypedTextKey];
        if ([text hasNonWhitespaceCharacters])
        {
            [[[[TGSendMessageSignals sendTextMessageWithPeerId:peerId text:text replyToMid:replyToMid] then:[[TGChatMessageListSignal readChatMessageListWithPeerId:peerId] delay:1.5 onQueue:[SQueue mainQueue]]] catch:^SSignal *(__unused id error)
            {
                suspendBlock(false);
                return nil;
            }] startWithNext:nil completed:^
            {
                suspendBlock(true);
            }];
            
            if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
                [[TGTelegramNetworking instance] resume];
        }
        else
        {
            suspendBlock(false);
        }
    }
    else
    {
        if (peerId != 0 && [TGDatabaseInstance() loadConversationWithId:peerId] != nil)
        {
            [[TGInterfaceManager instance] navigateToConversationWithId:peerId conversation:nil performActions:nil atMessage:nil clearStack:true openKeyboard:openKeyboard && (_passcodeWindow == nil || _passcodeWindow.hidden) canOpenKeyboardWhileInTransition:false animated:false];
        }
        
        if (completion)
            completion();
    }
}

- (void)_likeActionForPeerId:(int64_t)peerId completion:(void (^)())completion
{
    void (^suspendBlock)(bool) = ^(bool succeed)
    {
        if (succeed)
        {
            TGDispatchOnMainThread(^
            {
                if (_inBackground && !TGTelegraphInstance.callManager.hasActiveCall)
                    [[TGTelegramNetworking instance] pause];
                if (completion)
                    completion();
            });
        }
        else
        {
            [[TGTelegramNetworking instance] wakeUpWithCompletion:^
            {
                TGDispatchOnMainThread(^
                {
                    if (_inBackground && !TGTelegraphInstance.callManager.hasActiveCall)
                    {
                        [[TGTelegramNetworking instance] pause];
                        if (completion)
                            completion();
                    }
                });
            }];
        }
    };
    
    [[[[TGSendMessageSignals sendTextMessageWithPeerId:peerId text:@"👍" replyToMid:0] then:[[TGChatMessageListSignal readChatMessageListWithPeerId:peerId] delay:1.5 onQueue:[SQueue mainQueue]]] catch:^SSignal *(__unused id error)
    {
        suspendBlock(false);
        return nil;
    }] startWithNext:nil error: nil completed:^
    {
        suspendBlock(true);
    }];
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
        [[TGTelegramNetworking instance] resume];
}

- (void)_muteActionForPeerId:(int64_t)peerId duration:(NSInteger)duration completion:(void (^)())completion
{
    NSNumber *muteUntil = 0;
    [TGDatabaseInstance() loadPeerNotificationSettings:peerId soundId:NULL muteUntil:&muteUntil previewText:NULL messagesMuted:NULL notFound:NULL];
    
    int muteTime = (int)duration * 60 * 60;
    muteUntil = @(MAX(muteUntil.intValue, (int)[[TGTelegramNetworking instance] approximateRemoteTime] + muteTime));
    
    static int actionId = 0;
    
    void (^muteBlock)(int64_t, NSNumber *, NSNumber *) = ^(int64_t peerId, NSNumber *muteUntil, NSNumber *accessHash)
    {
        NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:@{ @"peerId": @(peerId), @"muteUntil": muteUntil }];
        if (accessHash != nil)
            options[@"accessHash"] = accessHash;
        
        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/changePeerSettings/(%" PRId64 ")/(muteAction%d)", peerId, actionId++] options:options watcher:TGTelegraphInstance];
    };
    
    if (TGPeerIdIsChannel(peerId))
    {
        [[[TGDatabaseInstance() existingChannel:peerId] take:1] startWithNext:^(TGConversation *channel)
        {
            muteBlock(peerId, muteUntil, @(channel.accessHash));
        }];
    }
    else
    {
        muteBlock(peerId, muteUntil, nil);
    }

    
    TGDispatchAfter(9.0, dispatch_get_main_queue(), ^
    {
        if (completion)
            completion();
    });
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
    {
        [[TGTelegramNetworking instance] resume];
        
        if (completion != nil)
        {
            [[TGTelegramNetworking instance] wakeUpWithCompletion:^
            {
                TGDispatchOnMainThread(^
                {
                    if (_inBackground && !TGTelegraphInstance.callManager.hasActiveCall)
                    {
                        [[TGTelegramNetworking instance] pause];
                        
                        if (completion != nil)
                            completion();
                    }
                });
            }];
        }
    }
}

- (bool)isManuallyLocked
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"Passcode_lockManually"] boolValue];
}

- (int32_t)automaticLockTimeout
{
    NSNumber *nLockTimeout = [[NSUserDefaults standardUserDefaults] objectForKey:@"Passcode_lockTimeout"];
    if (nLockTimeout == nil)
        return 1 * 60 * 60;
    return (int32_t)[nLockTimeout intValue];
}

- (void)setAutomaticLockTimeout:(int32_t)automaticLockTimeout
{
    [[NSUserDefaults standardUserDefaults] setObject:@(automaticLockTimeout) forKey:@"Passcode_lockTimeout"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setIsManuallyLocked:(bool)isLocked
{
    [[NSUserDefaults standardUserDefaults] setObject:@(isLocked) forKey:@"Passcode_lockManually"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [ActionStageInstance() dispatchResource:@"/databasePasswordChanged" resource:nil];
}

- (bool)isCurrentlyLocked
{
    return [self isCurrentlyLocked:NULL canBeLocked:NULL];
}

- (bool)isCurrentlyLocked:(bool *)byTimeout canBeLocked:(bool *)canBeLocked
{
    if ([TGDatabaseInstance() isPasswordSet:NULL])
    {
        if (canBeLocked) {
           *canBeLocked = true;
        }
        NSNumber *nDeactivationDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"Passcode_deactivationDate"];
        bool displayByDeactivationTimeout = false;
        if (nDeactivationDate != nil)
        {
            int32_t lockTimeout = [self automaticLockTimeout];
            if (lockTimeout >= 0)
            {
                displayByDeactivationTimeout = [[NSDate date] timeIntervalSince1970] > ([nDeactivationDate doubleValue] + lockTimeout);
                if (byTimeout)
                   *byTimeout = displayByDeactivationTimeout;
            }
        }
        
        return [self isManuallyLocked] || displayByDeactivationTimeout;
    }
    
    return false;
}

- (bool)willBeLocked {
    if ([TGDatabaseInstance() isPasswordSet:NULL]) {
        return true;
    }
    
    return false;
}

- (void)onBecomeInactive
{
    bool canBeLocked = false;
    bool isLocked = [self isCurrentlyLocked:NULL canBeLocked:&canBeLocked];
    if (isLocked)
    {
        [self setIsManuallyLocked:true];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Passcode_deactivationDate"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    else
    {
        [[NSUserDefaults standardUserDefaults] setObject:@([[NSDate date] timeIntervalSince1970]) forKey:@"Passcode_deactivationDate"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    if ([TGDatabaseInstance() isPasswordSet:NULL])
    {
        if (TGTelegraphInstance.clientUserId != 0)
        {
            TLRPCaccount_updateDeviceLocked$account_updateDeviceLocked *updateDeviceLocked = [[TLRPCaccount_updateDeviceLocked$account_updateDeviceLocked alloc] init];
            if ([self isManuallyLocked])
                updateDeviceLocked.period = 0;
            else
                updateDeviceLocked.period = [self automaticLockTimeout];
            
            if (_deviceLockedRequestDisposable == nil)
                _deviceLockedRequestDisposable = [[SMetaDisposable alloc] init];
            
            [_deviceLockedRequestDisposable setDisposable:[[[TGTelegramNetworking instance] requestSignal:updateDeviceLocked] startWithNext:^(__unused id next)
            {
            }]];
            
            _didUpdateDeviceLocked = true;
        }
    }
    
    if ([self willBeLocked]) {
        [self displayBlurredContentIfNeeded];
    }
}

- (void)onBecomeActive
{
    [self hideBlurredContentIfNeeded];
    
    if (_didUpdateDeviceLocked)
    {
        _didUpdateDeviceLocked = false;
        
        if (![self isCurrentlyLocked]) {
            [self resetRemoteDeviceLocked];
        }
    }
    
    if ([self isCurrentlyLocked])
    {
        [self setIsManuallyLocked:true];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Passcode_deactivationDate"];
        
        [self displayUnlockWindowIfNeeded];
    }
}

- (void)resetRemoteDeviceLocked
{
    if (TGTelegraphInstance.clientUserId != 0)
    {        
        TLRPCaccount_updateDeviceLocked$account_updateDeviceLocked *updateDeviceLocked = [[TLRPCaccount_updateDeviceLocked$account_updateDeviceLocked alloc] init];
        updateDeviceLocked.period = -1;
        
        if (_deviceLockedRequestDisposable == nil)
            _deviceLockedRequestDisposable = [[SMetaDisposable alloc] init];
        
        [_deviceLockedRequestDisposable setDisposable:[[[TGTelegramNetworking instance] requestSignal:updateDeviceLocked] startWithNext:^(__unused id next)
        {
            
        }]];
    }
}

+ (void)movePathsToContainer
{
    if (iosMajorVersion() >= 8)
    {
        NSString *groupName = [@"group." stringByAppendingString:[[NSBundle mainBundle] bundleIdentifier]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSURL *groupURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:groupName];
        if (groupURL != nil)
        {
            NSString *documentsPath = [[groupURL path] stringByAppendingPathComponent:@"Documents"];
            
            [fileManager createDirectoryAtPath:documentsPath withIntermediateDirectories:true attributes:nil error:NULL];
            
            NSString *defaultDocumentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
            NSArray *documentItems = [fileManager contentsOfDirectoryAtPath:defaultDocumentsPath error:nil];
            int documentFileCount = 0;
            for (NSString *fileName in documentItems)
            {
                documentFileCount++;
                [fileManager moveItemAtPath:[defaultDocumentsPath stringByAppendingPathComponent:fileName] toPath:[documentsPath stringByAppendingPathComponent:fileName] error:nil];
            }
            
            NSString *localizationPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0] stringByAppendingPathComponent:@"localization"];
            
            [fileManager copyItemAtPath:localizationPath toPath:[documentsPath stringByAppendingPathComponent:@"localization"] error:nil];
            
            
            NSString *cachesPath = [[groupURL path] stringByAppendingPathComponent:@"Caches"];
            
            [fileManager createDirectoryAtPath:cachesPath withIntermediateDirectories:true attributes:nil error:NULL];
            
            NSString *defaultCachesPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true)[0];
            NSArray *cacheItems = [fileManager contentsOfDirectoryAtPath:defaultCachesPath error:nil];
            int cacheFileCount = 0;
            for (NSString *fileName in cacheItems)
            {
                cacheFileCount++;
                [fileManager moveItemAtPath:[defaultCachesPath stringByAppendingPathComponent:fileName] toPath:[cachesPath stringByAppendingPathComponent:fileName] error:nil];
            }
            
        }
    }
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
                path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
        }
        else
            path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
    });
    
    return path;
}

+ (NSString *)cachePath
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
                NSString *cachePath = [[groupURL path] stringByAppendingPathComponent:@"Caches"];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:true attributes:nil error:NULL];
                
                path = cachePath;
            }
            else
                path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true)[0];
        }
        else
            path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true)[0];
    });
    
    return path;
}

- (void)inviteBotToGroup:(TGUser *)user payload:(NSString *)payload
{
    TGForwardTargetController *controller = [[TGForwardTargetController alloc] initWithSelectGroup];
    controller.watcherHandle = self.actionHandle;
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller] navigationBarClass:[TGWhiteNavigationBar class]];
    
    if ([_rootController.viewControllers.lastObject isKindOfClass:[TGModernConversationController class]]) {
        [(TGModernConversationController *)_rootController.viewControllers.lastObject endEditing];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [self resetControllerStack];
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [_rootController presentViewController:navigationController animated:true completion:nil];
    });
    
    _currentInviteBot = user;
    _currentInviteBotPayload = payload;
}

- (void)startGameInConversation:(NSString *)shortName user:(TGUser *)user {
    TGForwardTargetController *controller = [[TGForwardTargetController alloc] initWithSelectTarget:false];
    controller.watcherHandle = self.actionHandle;
    controller.controllerTitle = TGLocalized(@"Share.Title");
    
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller] navigationBarClass:[TGWhiteNavigationBar class]];
    
    if ([_rootController.viewControllers.lastObject isKindOfClass:[TGModernConversationController class]]) {
        [(TGModernConversationController *)_rootController.viewControllers.lastObject endEditing];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        [self resetControllerStack];
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [_rootController presentViewController:navigationController animated:true completion:nil];
    });
    
    _currentStartGameBot = user;
    _currentStartGame = shortName;
}

#endif

- (void)setupShortcutItems
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    if (iosMajorVersion() >= 10)
        [self setupMenuShortcutItems];
    else
        [self setupChatShortcutItems];
#endif
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
- (void)setupMenuShortcutItems
{
    if (TGTelegraphInstance.clientUserId != 0 && TGTelegraphInstance.clientIsActivated)
    {
        UIApplicationShortcutItem *searchItem = [[UIApplicationShortcutItem alloc] initWithType:@"search" localizedTitle:TGLocalized(@"Common.Search") localizedSubtitle:nil icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeSearch] userInfo:nil];
        
        UIApplicationShortcutItem *newItem = [[UIApplicationShortcutItem alloc] initWithType:@"compose" localizedTitle:TGLocalized(@"Compose.NewMessage") localizedSubtitle:nil icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeCompose] userInfo:nil];
        
        UIApplicationShortcutItem *cameraItem = [[UIApplicationShortcutItem alloc] initWithType:@"camera" localizedTitle:TGLocalized(@"Camera.Title") localizedSubtitle:nil icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeCapturePhoto] userInfo:nil];
        
        UIApplicationShortcutItem *cloudItem = [[UIApplicationShortcutItem alloc] initWithType:@"conversation" localizedTitle:TGLocalized(@"Conversation.SavedMessages") localizedSubtitle:nil icon:[UIApplicationShortcutIcon iconWithTemplateImageName:@"SavedMessagesIcon"] userInfo:@{ @"cid": @(TGTelegraphInstance.clientUserId) }];
        
        [UIApplication sharedApplication].shortcutItems = @[ searchItem, newItem, cameraItem, cloudItem ];
    }
    else
    {
        [UIApplication sharedApplication].shortcutItems = nil;
    }
}


- (void)setupChatShortcutItems
{
    if (iosMajorVersion() < 9 || [UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPhone)
        return;
    
    if (TGTelegraphInstance.clientUserId != 0 && TGTelegraphInstance.clientIsActivated)
    {
        UIApplicationShortcutItem *composeItem = [[UIApplicationShortcutItem alloc] initWithType:@"compose" localizedTitle:TGLocalized(@"Compose.NewMessage") localizedSubtitle:nil icon:[UIApplicationShortcutIcon iconWithType:UIApplicationShortcutIconTypeCompose] userInfo:nil];
        
        NSArray *shortcuts = @[ composeItem ];
        [UIApplication sharedApplication].shortcutItems = shortcuts;
        
        if (![TGDatabaseInstance() isPasswordSet:NULL])
        {
            if (_recentPeersDisposable != nil)
                [_recentPeersDisposable dispose];
            
            _recentPeersDisposable = [[SMetaDisposable alloc] init];
            
            SSignal *updatedRecentPeers = [[TGRecentPeersSignals updateRecentPeers] mapToSignal:^SSignal *(__unused id next) {
                return [SSignal complete];
            }];
            
            [_recentPeersDisposable setDisposable:[[[[SSignal mergeSignals:@[[TGGlobalMessageSearchSignals recentPeerResults:^id (id item, __unused bool recent)
            {
                if ([item isKindOfClass:[TGConversation class]] && ((TGConversation *)item).conversationId == TGTelegraphInstance.clientUserId)
                    return nil;
                
                return item;
            } ratedPeers:true], updatedRecentPeers]] map:^id(NSArray *results)
            {
                if (results.count == 0)
                    return nil;
                
                NSMutableArray *sections = [[NSMutableArray alloc] init];
                for (id result in results)
                {
                    if ([result isKindOfClass:[TGDialogListRecentPeers class]])
                    {
                        TGDialogListRecentPeers *recentPeers = result;
                        [sections addObject:@{@"items": @[recentPeers], @"type": @"recent"}];
                    }
                }
                
                if (sections.count == 0)
                    return nil;
                
                NSMutableArray *chatItems = [[NSMutableArray alloc] init];
                for (NSDictionary *section in sections)
                {
                    TGDialogListRecentPeers *recentPeers = [section[@"items"] firstObject];
                    for (id peer in recentPeers.peers)
                    {
                        UIApplicationShortcutItem *item = [TGAppDelegate shortcutItemForPeer:peer];
                        if (item != nil)
                            [chatItems addObject:item];
                        
                        if (chatItems.count == 3)
                            break;
                    }
                }
                
                if (chatItems.count == 0)
                    return nil;
                
                return chatItems;
            }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *chatShortcuts)
            {
                NSArray *finalShortcuts = [shortcuts arrayByAddingObjectsFromArray:chatShortcuts];
                [UIApplication sharedApplication].shortcutItems = finalShortcuts;
            }]];
        }
    }
    else
    {
        [UIApplication sharedApplication].shortcutItems = nil;
        
        [_recentPeersDisposable dispose];
        _recentPeersDisposable = nil;
    }
}

+ (UIApplicationShortcutItem *)shortcutItemForPeer:(id)peer
{
    NSString *title = @"";
    CNMutableContact *contact = nil;
    
    int64_t peerId = 0;
    
    if ([peer isKindOfClass:[TGConversation class]])
    {
        TGConversation *conversation = peer;
        peerId = conversation.conversationId;
        
        if (conversation.additionalProperties[@"user"] != nil)
        {
            TGUser *user = conversation.additionalProperties[@"user"];
            title = user.displayName;
            
            contact.givenName = user.firstName;
            contact.familyName = user.lastName;
        }
        else
        {
            title = conversation.chatTitle;
            contact.givenName = title;
        }
    }
    else if ([peer isKindOfClass:[TGUser class]])
    {
        TGUser *user = peer;
        peerId = user.uid;
        title = user.displayName;
        
        contact.givenName = user.firstName;
        contact.familyName = user.lastName;
    }
    
    UIApplicationShortcutIcon *icon = [UIApplicationShortcutIcon iconWithContact:contact];
    UIApplicationShortcutItem *item = [[UIApplicationShortcutItem alloc] initWithType:@"conversation" localizedTitle:title localizedSubtitle:nil icon:icon userInfo:@{ @"cid": @(peerId) }];
    
    return item;
}

#endif

- (NSString *)_callsTabFilePath
{
    return [TGAppDelegateDocumentsPathCompat() stringByAppendingPathComponent:@"enablecalls.tab"];
}

- (bool)callsTabFileExists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self _callsTabFilePath]];
}

- (void)loadShowCallsTab
{
    NSData *data = [NSData dataWithContentsOfFile:[self _callsTabFilePath]];
    bool flag = false;
    if (data.length != 0)
    {
        uint8_t show = 0;
        [data getBytes:&show length:1];
        if (show > 0)
            flag = true;
    }
    _showCallsTab = flag;
}

- (void)setShowCallsTab:(int)showCallsTab
{
    _showCallsTab = showCallsTab;
    
    uint8_t show = showCallsTab ? 1: 0;
    NSData *data = [NSData dataWithBytes:&show length:1];
    [data writeToFile:[self _callsTabFilePath] atomically:true];
}

- (void)resetCallsTab
{
    _showCallsTab = false;
    [[NSFileManager defaultManager] removeItemAtPath:[self _callsTabFilePath] error:NULL];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"userSelected"] || [action isEqualToString:@"conversationSelected"]) {
        if (_currentStartGame != nil) {
            int64_t peerId = 0;
            NSString *peerName = @"";
            if ([options isKindOfClass:[TGUser class]]) {
                peerId = ((TGUser *)options).uid;
                peerName = [((TGUser *)options) displayName];
            } else if ([options isKindOfClass:[TGConversation class]]) {
                peerId = ((TGConversation *)options).conversationId;
                peerName = [((TGConversation *)options) chatTitle];
            }
            
            NSString *formatString = TGPeerIdIsUser(peerId) ? TGLocalized(@"Target.ShareGameConfirmationPrivate") : TGLocalized(@"Target.ShareGameConfirmationGroup");
            [TGCustomAlertView presentAlertWithTitle:nil message:[NSString stringWithFormat:formatString, peerName] cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.OK") completionBlock:^(bool okButtonPressed) {
                if (okButtonPressed) {
                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                    [progressWindow show:true];
                    
                    [[[[TGBotSignals sendBotGame:_currentStartGame toPeerId:peerId botId:_currentStartGameBot.uid] deliverOn:[SQueue mainQueue]] onDispose:^
                    {
                        [progressWindow dismiss:true];
                    }] startWithNext:^(__unused id next)
                    {
                    } error:^(id error)
                    {
                        NSString *errorDescription = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
                        NSString *alertText = TGLocalized(@"ConversationProfile.UnknownAddMemberError");
                        if ([errorDescription isEqualToString:@"USER_ALREADY_PARTICIPANT"])
                            alertText = TGLocalized(@"Target.InviteToGroupErrorAlreadyInvited");
                        else if ([errorDescription isEqualToString:@"CHAT_ADMIN_REQUIRED"]) {
                            TGUser *botUser = [TGDatabaseInstance() loadUser:_currentStartGameBot.uid];
                            alertText = TGLocalized(@"Group.Members.AddMemberBotErrorNotAllowed");
                        }
                        
                        [TGCustomAlertView presentAlertWithTitle:nil message:alertText cancelButtonTitle:TGLocalized(@"Common.OK")  okButtonTitle:nil completionBlock:nil];
                    } completed:^{
                        [_rootController dismissViewControllerAnimated:true completion:nil];
                        [[TGInterfaceManager instance] navigateToConversationWithId:peerId conversation:nil];
                    }];
                    _currentStartGame = nil;
                }
            }];
        }
    }
    else if ([action isEqualToString:@"willForwardMessages"])
    {
        if (_currentInviteBot != nil) {
            int32_t uid = _currentInviteBot.uid;
            NSString *payload = _currentInviteBotPayload;
            _currentInviteBot = nil;
            _currentInviteBotPayload = nil;
            if (uid != 0 && payload.length != 0)
            {
                TGConversation *conversation = options[@"target"];
                if (![conversation isKindOfClass:[TGConversation class]])
                    return;
                
                TGProgressWindow *progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                [progressWindow show:true];
                
                [[[[TGBotSignals botInviteUserId:uid toPeerId:conversation.conversationId accessHash:conversation.accessHash payload:payload] deliverOn:[SQueue mainQueue]] onDispose:^
                {
                    [progressWindow dismiss:true];
                }] startWithNext:^(__unused id next)
                {
                    [[(UIViewController *)options[@"controller"] presentingViewController] dismissViewControllerAnimated:true completion:nil];
                    [[TGInterfaceManager instance] navigateToConversationWithId:conversation.conversationId conversation:nil];
                } error:^(id error)
                {
                    NSString *errorDescription = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
                    NSString *alertText = TGLocalized(@"ConversationProfile.UnknownAddMemberError");
                    if ([errorDescription isEqualToString:@"USER_ALREADY_PARTICIPANT"])
                        alertText = TGLocalized(@"Target.InviteToGroupErrorAlreadyInvited");
                    else if ([errorDescription isEqualToString:@"CHAT_ADMIN_REQUIRED"]) {
                        alertText = TGLocalized(@"Group.Members.AddMemberBotErrorNotAllowed");
                    }
                    
                    [TGCustomAlertView presentAlertWithTitle:nil message:alertText cancelButtonTitle:TGLocalized(@"Common.OK")  okButtonTitle:nil completionBlock:nil];
                } completed:nil];
            }
        }
    }
}

- (void)updatePushRegistration {
    if (!TGIOS6APNsNotificationsEnabled()) {
        [self disableAPNsNotificationRegistration];
        return;
    }

    if (_pushToken != nil) {
        NSString *token = [[_pushToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
        token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
        
        [[TGAccountSignals registerDeviceToken:token voip:false] startWithNext:nil];
    }
}

- (void)disableAPNsNotificationRegistration
{
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    _pushToken = nil;
    _tokenAlreadyRequested = false;

    if (_deviceTokenListener != nil)
        [_deviceTokenListener deviceTokenRequestCompleted:nil];
    _deviceTokenListener = nil;
}

- (void)applyIOS6APNsNotificationsEnabled:(bool)enabled
{
    bool effectiveEnabled = enabled;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:effectiveEnabled forKey:TGIOS6APNsNotificationsEnabledKey];
    [defaults synchronize];

    if (effectiveEnabled)
    {
        [ActionStageInstance() requestActor:@"/tg/service/settings/push/(subscribe)" options:nil watcher:TGTelegraphInstance];
    }
    else
    {
        NSString *token = nil;
        if (_pushToken != nil)
        {
            token = [[_pushToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
            token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
        }
        if (token.length != 0)
            [[TGAccountSignals unregisterDeviceToken:token voip:false] startWithNext:nil];
        [TGPushActionsRequestBuilder clearCachedDevicePushToken];
        [self disableAPNsNotificationRegistration];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    CGPoint location = [[event.allTouches anyObject] locationInView:self.window];
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    if (CGRectContainsPoint(statusBarFrame, location))
        _statusBarPressedPipe.sink(@true);
}

- (NSString *)applicationName
{
    NSString *appTitle = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
    if (appTitle == nil) {
        appTitle = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    }
    if (appTitle == nil) {
        appTitle = @"Telegram";
    }
    return appTitle;
}

@end

@interface UICollectionViewDisableForwardToUICollectionViewSentinel : NSObject @end @implementation UICollectionViewDisableForwardToUICollectionViewSentinel @end
