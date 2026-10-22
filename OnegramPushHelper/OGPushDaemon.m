#import "OGPushDaemon.h"

#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <libkern/OSAtomic.h>
#import <notify.h>
#import <signal.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <objc/message.h>

#import "OGPushHelperProtocol.h"
#import "OGPushSerialization.h"
#import "../OnegramLauncher/OGSystemApplication.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTApiEnvironment.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTContext.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTSerialization.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTFileBasedKeychain.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddressSet.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAddress.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTDatacenterAuthInfo.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTProto.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequestMessageService.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequest.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTIncomingMessage.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTOutgoingMessage.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTMessageTransaction.h"

typedef int (*OGPushLaunchApplicationFunction)(CFStringRef identifier, Boolean suspended);

static NSString *const OGPushLogPath = @"/var/mobile/Library/Logs/onegramd.log";
static NSString *const OGPushRotatedLogPath = @"/var/mobile/Library/Logs/onegramd.log.1";
static NSString *const OGPushKeychainDirectory = @"/var/mobile/Library/Onegram/daemon";
static NSString *const OGPushSystemApplicationDocumentsPath = @OGSystemApplicationMobileHomePath "/" OGSystemApplicationHomeRelativePath "/Documents";
static const unsigned long long OGPushLogSizeLimit = 256 * 1024;
static const NSTimeInterval OGPushHeartbeatInterval = 60.0;
static const CFAbsoluteTime OGPushWakeInterval = 20.0;
static const NSTimeInterval OGPushApplicationFinishingWindow = 120.0;
static const NSTimeInterval OGPushKeepaliveInterval = 60.0;
static const int32_t OGPushKeepaliveDisconnectDelay = 75;

enum
{
    OGPushRecentUpdateCapacity = 64
};

static void OGPushLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSData *data = [[[NSString alloc] initWithFormat:@"[onegramd %@] %@\n", [NSDate date], line] dataUsingEncoding:NSUTF8StringEncoding];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:OGPushLogPath error:NULL];
    if (attributes != nil && [attributes fileSize] > OGPushLogSizeLimit)
    {
        [fileManager removeItemAtPath:OGPushRotatedLogPath error:NULL];
        [fileManager moveItemAtPath:OGPushLogPath toPath:OGPushRotatedLogPath error:NULL];
        attributes = nil;
    }

    if (attributes == nil)
    {
        [data writeToFile:OGPushLogPath atomically:false];
        return;
    }

    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:OGPushLogPath];
    [handle seekToEndOfFile];
    [handle writeData:data];
    [handle closeFile];
}

static NSString *OGPushApplicationStatePath(NSString *documentsPath)
{
    return [[documentsPath stringByAppendingPathComponent:@OGPushHelperAuthInfoDirectoryName] stringByAppendingPathComponent:@OGPushHelperAppStateFileName];
}

static bool OGPushApplicationProcessIsRunning(pid_t pid, NSTimeInterval stateTime)
{
    if (pid <= 0)
        return false;

    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
    struct kinfo_proc info;
    size_t length = sizeof(info);
    memset(&info, 0, sizeof(info));
    if (sysctl(mib, 4, &info, &length, NULL, 0) != 0 || length == 0 || info.kp_proc.p_stat == SZOMB)
        return false;

    NSTimeInterval startTime = (NSTimeInterval)info.kp_proc.p_starttime.tv_sec + (NSTimeInterval)info.kp_proc.p_starttime.tv_usec / 1000000.0;
    return startTime <= stateTime + 1.0;
}

static bool OGPushDeviceSupportsMultitasking(void)
{
    UIDevice *device = [UIDevice currentDevice];
    SEL selector = @selector(isMultitaskingSupported);
    if (![device respondsToSelector:selector])
        return false;
    return ((BOOL (*)(id, SEL))objc_msgSend)(device, selector);
}

static OGPushLaunchApplicationFunction OGPushResolveLaunchApplicationFunction(void)
{
    void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    if (handle == NULL)
        return NULL;
    return (OGPushLaunchApplicationFunction)dlsym(handle, "SBSLaunchApplicationWithIdentifier");
}

static void OGPushApplicationStateChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo);
static void OGPushAuthInfoChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo);

@interface OGPushDaemon ()
{
    OGPushLaunchApplicationFunction _launchApplication;

    bool _observersRegistered;

    bool _applicationReceivesUpdates;
    bool _launchAfterApplicationExit;
    NSTimeInterval _scheduledFinishingDeadline;
    NSString *_applicationDocumentsPath;
    NSString *_applicationBundleIdentifier;
    pid_t _applicationPid;
    dispatch_source_t _applicationExitSource;

    NSTimer *_heartbeatTimer;
    CFAbsoluteTime _lastWakeTime;
    bool _wakeScheduled;

    uint64_t _recentUpdateDigests[OGPushRecentUpdateCapacity];
    NSUInteger _recentUpdateCount;
    NSUInteger _recentUpdateCursor;

    bool _knownStateValid;
    int32_t _knownPts;
    int32_t _knownQts;
    int32_t _knownUnreadCount;
    bool _stateCheckInFlight;
    bool _stateCheckRepeat;

    dispatch_source_t _keepaliveTimer;
    volatile int32_t _keepalivePending;

    MTContext *_context;
    MTProto *_mtProto;
    OGPushSerialization *_serialization;
    MTRequestMessageService *_requestService;
    int64_t _connectedAuthKeyId;
    NSString *_connectedApiInitializationHash;
    bool _daemonFlagPosted;
}

- (void)applicationStateChanged;
- (void)authInfoChanged;
- (void)launchApplication;
- (bool)applicationReceivesUpdatesInState:(NSString *)applicationState since:(NSTimeInterval)stateTime;

@end

static void OGPushApplicationStateChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo)
{
    [(__bridge OGPushDaemon *)observer applicationStateChanged];
}

static void OGPushAuthInfoChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo)
{
    [(__bridge OGPushDaemon *)observer authInfoChanged];
}

@implementation OGPushDaemon

- (bool)start
{
    OGPushLog(@"starting pid=%d", (int)getpid());

    if (!OGPushDeviceSupportsMultitasking())
    {
        OGPushLog(@"device has no multitasking, background wake is impossible");
        return false;
    }

    _launchApplication = OGPushResolveLaunchApplicationFunction();
    if (_launchApplication == NULL)
    {
        OGPushLog(@"SBSLaunchApplicationWithIdentifier unavailable");
        return false;
    }

    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, (__bridge const void *)self, &OGPushApplicationStateChanged, CFSTR(OGPushHelperApplicationStateNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, (__bridge const void *)self, &OGPushAuthInfoChanged, CFSTR(OGPushHelperAuthInfoChangedNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    _observersRegistered = true;

    _heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:OGPushHeartbeatInterval target:self selector:@selector(heartbeat) userInfo:nil repeats:true];

    [self reconcile];
    return true;
}

- (void)stop
{
    OGPushLog(@"stopping");

    if (_observersRegistered)
    {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self);
        _observersRegistered = false;
    }
    [_heartbeatTimer invalidate];
    _heartbeatTimer = nil;
    [self stopObservingApplicationProcess];
    [self disconnect];
    [self removeDaemonFlag];
}

- (NSString *)helperDirectoryPath
{
    NSString *documentsPath = [self applicationDocumentsPath];
    if (documentsPath == nil)
        return nil;
    return [documentsPath stringByAppendingPathComponent:@OGPushHelperAuthInfoDirectoryName];
}

- (void)writeDaemonFlag
{
    NSString *dir = [self helperDirectoryPath];
    if (dir == nil)
        return;
    NSString *path = [dir stringByAppendingPathComponent:@OGPushHelperDaemonFlagFileName];
    NSData *data = [[[NSString alloc] initWithFormat:@"%d %.0f", (int)getpid(), CFAbsoluteTimeGetCurrent()] dataUsingEncoding:NSUTF8StringEncoding];
    if (![data writeToFile:path options:NSDataWritingAtomic error:NULL])
        return;
    [[NSFileManager defaultManager] setAttributes:@{@"NSFileProtectionKey": @"NSFileProtectionNone"} ofItemAtPath:path error:NULL];
    if (!_daemonFlagPosted)
    {
        _daemonFlagPosted = true;
        notify_post(OGPushHelperDaemonStateNotification);
    }
}

- (void)removeDaemonFlag
{
    NSString *dir = [self helperDirectoryPath];
    if (dir == nil)
        return;
    [[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:@OGPushHelperDaemonFlagFileName] error:NULL];
    if (_daemonFlagPosted)
    {
        _daemonFlagPosted = false;
        notify_post(OGPushHelperDaemonStateNotification);
    }
}

- (bool)readApplicationProcess:(pid_t *)outPid stateTime:(NSTimeInterval *)outStateTime bundleIdentifier:(NSString **)outBundleIdentifier state:(NSString **)outState
{
    NSString *dir = [self helperDirectoryPath];
    if (dir == nil)
        return false;
    NSData *data = [NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@OGPushHelperAppStateFileName]];
    if (data == nil)
        return false;
    id decoded = nil;
    @try { decoded = [NSKeyedUnarchiver unarchiveObjectWithData:data]; }
    @catch (__unused NSException *exception) { decoded = nil; }
    if (![decoded isKindOfClass:[NSDictionary class]])
        return false;
    NSDictionary *state = decoded;
    if (![state[@"pid"] isKindOfClass:[NSNumber class]] || ![state[@"time"] isKindOfClass:[NSNumber class]])
        return false;
    *outPid = (pid_t)[state[@"pid"] intValue];
    *outStateTime = [state[@"time"] doubleValue];
    if ([state[@"bundleIdentifier"] isKindOfClass:[NSString class]])
        *outBundleIdentifier = state[@"bundleIdentifier"];
    if ([state[@"state"] isKindOfClass:[NSString class]])
        *outState = state[@"state"];
    return true;
}

- (void)applicationStateChanged
{
    [self reconcile];
}

- (void)authInfoChanged
{
    NSDictionary *authInfo = [self loadAuthInfo];
    MTDatacenterAuthInfo *datacenterAuthInfo = authInfo[@"authInfo"];
    MTApiEnvironment *apiEnvironment = [self apiEnvironmentFromAuthInfo:authInfo];
    if (_mtProto != nil && [datacenterAuthInfo isKindOfClass:[MTDatacenterAuthInfo class]] && datacenterAuthInfo.authKeyId == _connectedAuthKeyId && [apiEnvironment.apiInitializationHash isEqualToString:_connectedApiInitializationHash])
        return;

    OGPushLog(@"auth info changed");
    [self disconnect];
    [self reconcile];
}

- (void)applicationProcessExited
{
    OGPushLog(@"application process %d exited", (int)_applicationPid);
    [self stopObservingApplicationProcess];
    if (_launchAfterApplicationExit)
    {
        _launchAfterApplicationExit = false;
        [self launchApplication];
        return;
    }
    [self disconnect];
    [self reconcile];
}

- (void)reconcile
{
    [self writeDaemonFlag];
    [self refreshApplicationState];

    if (_applicationReceivesUpdates)
    {
        [self disconnect];
        return;
    }

    if (_mtProto != nil)
        return;

    NSDictionary *authInfo = [self loadAuthInfo];
    if (authInfo != nil)
        [self connectWithAuthInfo:authInfo];
}

- (void)heartbeat
{
    [self reconcile];
}

- (bool)applicationReceivesUpdatesInState:(NSString *)applicationState since:(NSTimeInterval)stateTime
{
    if ([applicationState isEqualToString:@"suspended"])
        return false;
    if (![applicationState isEqualToString:@"finishing"])
        return true;

    NSTimeInterval deadline = stateTime + OGPushApplicationFinishingWindow;
    NSTimeInterval remaining = deadline - [[NSDate date] timeIntervalSince1970];
    if (remaining <= 0.0)
        return false;

    if (deadline != _scheduledFinishingDeadline)
    {
        _scheduledFinishingDeadline = deadline;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((remaining + 1.0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
        {
            [self reconcile];
        });
    }
    return true;
}

- (void)refreshApplicationState
{
    pid_t pid = 0;
    NSTimeInterval stateTime = 0.0;
    NSString *bundleIdentifier = nil;
    NSString *applicationState = nil;
    bool stateAvailable = [self readApplicationProcess:&pid stateTime:&stateTime bundleIdentifier:&bundleIdentifier state:&applicationState];
    if (bundleIdentifier != nil)
        _applicationBundleIdentifier = bundleIdentifier;

    bool alive = stateAvailable && OGPushApplicationProcessIsRunning(pid, stateTime);
    bool receivesUpdates = alive && [self applicationReceivesUpdatesInState:applicationState since:stateTime];
    if (receivesUpdates != _applicationReceivesUpdates)
        OGPushLog(@"application state=%@ alive=%d receiving=%d", applicationState != nil ? applicationState : @"legacy", alive ? 1 : 0, receivesUpdates ? 1 : 0);
    _applicationReceivesUpdates = receivesUpdates;
    if (!alive)
        pid = 0;

    if (pid == _applicationPid)
        return;

    [self stopObservingApplicationProcess];
    _applicationPid = pid;
    if (pid == 0)
        return;

    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)pid, DISPATCH_PROC_EXIT, dispatch_get_main_queue());
    if (source == NULL)
        return;

    dispatch_source_set_event_handler(source, ^
    {
        [self applicationProcessExited];
    });
    _applicationExitSource = source;
    dispatch_resume(source);
}

- (void)stopObservingApplicationProcess
{
    _applicationPid = 0;
    if (_applicationExitSource == NULL)
        return;

    dispatch_source_cancel(_applicationExitSource);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_applicationExitSource);
#endif
    _applicationExitSource = NULL;
}

- (NSString *)applicationDocumentsPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (_applicationDocumentsPath != nil && [fileManager fileExistsAtPath:OGPushApplicationStatePath(_applicationDocumentsPath)])
        return _applicationDocumentsPath;

    NSMutableArray *candidates = [[NSMutableArray alloc] initWithObjects:OGPushSystemApplicationDocumentsPath, nil];
    for (NSString *root in @[@"/var/mobile/Containers/Data/Application", @"/var/mobile/Applications"])
    {
        for (NSString *entry in [fileManager contentsOfDirectoryAtPath:root error:NULL])
            [candidates addObject:[[root stringByAppendingPathComponent:entry] stringByAppendingPathComponent:@"Documents"]];
    }

    NSString *discoveredPath = nil;
    NSDate *discoveredDate = nil;
    for (NSString *documentsPath in candidates)
    {
        NSDate *modified = [[fileManager attributesOfItemAtPath:OGPushApplicationStatePath(documentsPath) error:NULL] fileModificationDate];
        if (modified != nil && (discoveredDate == nil || [modified compare:discoveredDate] == NSOrderedDescending))
        {
            discoveredPath = documentsPath;
            discoveredDate = modified;
        }
    }

    if (discoveredPath != nil && ![discoveredPath isEqualToString:_applicationDocumentsPath])
    {
        OGPushLog(@"application container %@", discoveredPath);
        _daemonFlagPosted = false;
    }
    _applicationDocumentsPath = discoveredPath;
    return discoveredPath;
}

- (NSDictionary *)loadAuthInfo
{
    NSString *documentsPath = [self applicationDocumentsPath];
    if (documentsPath == nil)
    {
        OGPushLog(@"application state not found");
        return nil;
    }

    NSString *authInfoPath = [[documentsPath stringByAppendingPathComponent:@OGPushHelperAuthInfoDirectoryName] stringByAppendingPathComponent:@OGPushHelperAuthInfoFileName];
    NSData *data = [NSData dataWithContentsOfFile:authInfoPath];
    if (data == nil)
    {
        OGPushLog(@"auth info is not available yet");
        return nil;
    }

    id decoded = nil;
    @try
    {
        decoded = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch (__unused NSException *exception)
    {
        decoded = nil;
    }

    if (![decoded isKindOfClass:[NSDictionary class]])
    {
        OGPushLog(@"auth info is unreadable");
        return nil;
    }

    return decoded;
}

- (NSString *)keychainDirectory
{
    [[NSFileManager defaultManager] createDirectoryAtPath:OGPushKeychainDirectory withIntermediateDirectories:true attributes:@{NSFilePosixPermissions: @(S_IRWXU)} error:NULL];
    return OGPushKeychainDirectory;
}

- (void)seedAddressSets:(MTContext *)context isTestingEnvironment:(bool)isTestingEnvironment
{
    NSDictionary *seedAddresses = isTestingEnvironment ? @{@1: @"149.154.175.10", @2: @"149.154.167.40"} : @{@1: @"149.154.175.50", @2: @"149.154.167.51", @3: @"149.154.175.100", @4: @"149.154.167.91", @5: @"149.154.171.5"};
    for (NSNumber *datacenterId in seedAddresses)
    {
        MTDatacenterAddress *address = [[MTDatacenterAddress alloc] initWithIp:seedAddresses[datacenterId] port:443 preferForMedia:false restrictToTcp:false cdn:false preferForProxy:false secret:nil];
        [context setSeedAddressSetForDatacenterWithId:[datacenterId integerValue] seedAddressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[address]]];
    }
}

- (MTApiEnvironment *)apiEnvironmentFromAuthInfo:(NSDictionary *)authInfo
{
    NSDictionary *description = authInfo[@"apiEnvironment"];
    if (![description isKindOfClass:[NSDictionary class]])
        return nil;

    NSNumber *apiId = description[@"apiId"];
    NSString *appVersion = description[@"appVersion"];
    NSNumber *layer = description[@"layer"];
    NSString *langPack = description[@"langPack"];
    NSString *langPackCode = description[@"langPackCode"];
    NSString *systemLangCode = description[@"systemLangCode"];
    if (![apiId isKindOfClass:[NSNumber class]] || ![appVersion isKindOfClass:[NSString class]] || ![layer isKindOfClass:[NSNumber class]] || ![langPack isKindOfClass:[NSString class]] || ![systemLangCode isKindOfClass:[NSString class]])
        return nil;
    if (langPackCode != nil && ![langPackCode isKindOfClass:[NSString class]])
        return nil;

    MTApiEnvironment *apiEnvironment = [[MTApiEnvironment alloc] init];
    apiEnvironment.apiId = [apiId intValue];
    apiEnvironment.appVersion = appVersion;
    apiEnvironment.layer = layer;
    apiEnvironment.langPack = langPack;
    apiEnvironment.disableUpdates = false;
    return [[apiEnvironment withUpdatedLangPackCode:langPackCode] withUpdatedSystemLangCode:systemLangCode];
}

- (bool)connectWithAuthInfo:(NSDictionary *)authInfo
{
    NSNumber *datacenterIdValue = authInfo[@"datacenterId"];
    MTDatacenterAuthInfo *datacenterAuthInfo = authInfo[@"authInfo"];
    NSDictionary *addressSets = authInfo[@"addressSets"];
    bool isTestingEnvironment = [authInfo[@"isTesting"] boolValue];
    MTApiEnvironment *apiEnvironment = [self apiEnvironmentFromAuthInfo:authInfo];

    if (![datacenterIdValue isKindOfClass:[NSNumber class]] || ![datacenterAuthInfo isKindOfClass:[MTDatacenterAuthInfo class]] || apiEnvironment == nil)
    {
        OGPushLog(@"auth info is incomplete");
        return false;
    }

    NSInteger datacenterId = [datacenterIdValue integerValue];
    OGPushSerialization *serialization = [[OGPushSerialization alloc] initWithLayer:[apiEnvironment.layer unsignedIntegerValue]];

    MTContext *context = [[MTContext alloc] initWithSerialization:serialization apiEnvironment:apiEnvironment isTestingEnvironment:isTestingEnvironment useTempAuthKeys:false];

    [context performBatchUpdates:^
    {
        [self seedAddressSets:context isTestingEnvironment:isTestingEnvironment];
    }];

    context.keychain = [MTFileBasedKeychain unencryptedKeychainWithName:@"onegramd" documentsPath:[self keychainDirectory]];

    [context performBatchUpdates:^
    {
        MTDatacenterAuthInfo *storedAuthInfo = [context authInfoForDatacenterWithId:datacenterId];
        if (storedAuthInfo != nil && storedAuthInfo.authKeyId == datacenterAuthInfo.authKeyId)
            [context updateAuthInfoForDatacenterWithId:datacenterId authInfo:[storedAuthInfo withUpdatedAuthKeyAttributes:datacenterAuthInfo.authKeyAttributes]];
        else
            [context updateAuthInfoForDatacenterWithId:datacenterId authInfo:datacenterAuthInfo];

        for (NSNumber *addressDatacenterId in addressSets)
        {
            MTDatacenterAddressSet *addressSet = addressSets[addressDatacenterId];
            if ([addressSet isKindOfClass:[MTDatacenterAddressSet class]])
                [context updateAddressSetForDatacenterWithId:[addressDatacenterId integerValue] addressSet:addressSet forceUpdateSchemes:true];
        }
    }];

    _context = context;
    _serialization = serialization;
    _mtProto = [[MTProto alloc] initWithContext:context datacenterId:datacenterId usageCalculationInfo:nil];
    _mtProto.useTempAuthKeys = false;
    _requestService = [[MTRequestMessageService alloc] initWithContext:context];
    [_mtProto addMessageService:_requestService];
    [_mtProto addMessageService:self];
    [_mtProto resume];
    _connectedAuthKeyId = datacenterAuthInfo.authKeyId;
    _connectedApiInitializationHash = apiEnvironment.apiInitializationHash;

    OGPushLog(@"listening for updates dc=%d testing=%d layer=%d", (int)datacenterId, isTestingEnvironment ? 1 : 0, (int)[serialization currentLayer]);

    [self requestUpdatesState:false];
    [self startKeepalive];

    return true;
}

- (void)disconnect
{
    if (_mtProto == nil)
        return;

    OGPushLog(@"releasing update stream");

    [self stopKeepalive];
    [_mtProto removeMessageService:self];
    [_mtProto removeMessageService:_requestService];
    [_mtProto stop];
    [_context cleanup];

    _requestService = nil;
    _mtProto = nil;
    _serialization = nil;
    _context = nil;
    _knownStateValid = false;
    _stateCheckInFlight = false;
    _stateCheckRepeat = false;
    _connectedAuthKeyId = 0;
    _connectedApiInitializationHash = nil;
}

- (void)requestUpdatesState:(bool)check
{
    MTProto *mtProto = _mtProto;
    if (mtProto == nil)
        return;
    if (check)
    {
        if (_stateCheckInFlight)
        {
            _stateCheckRepeat = true;
            return;
        }
        _stateCheckInFlight = true;
    }

    NSData *payload = nil;
    OGPushUpdatesStateParser parser = [_serialization requestUpdatesState:&payload];
    MTRequest *request = [[MTRequest alloc] init];
    [request setPayload:payload metadata:@"updates.getState" responseParser:parser];
    request.completed = ^(id result, __unused NSTimeInterval timestamp, id error)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self updatesStateReceived:[result isKindOfClass:[NSDictionary class]] ? result : nil error:error mtProto:mtProto check:check];
        });
    };
    [_requestService addRequest:request];
}

- (void)updatesStateReceived:(NSDictionary *)state error:(id)error mtProto:(MTProto *)mtProto check:(bool)check
{
    if (_mtProto != mtProto)
        return;
    if (check)
        _stateCheckInFlight = false;

    if (state == nil)
    {
        OGPushLog(@"updates.getState failed: %@", error);
        if (check)
            [self requestApplicationWake];
    }
    else
    {
        int32_t pts = [state[@"pts"] intValue];
        int32_t qts = [state[@"qts"] intValue];
        int32_t unreadCount = [state[@"unreadCount"] intValue];
        bool advanced = !_knownStateValid || pts > _knownPts || qts > _knownQts || unreadCount > _knownUnreadCount;
        _knownStateValid = true;
        _knownPts = pts;
        _knownQts = qts;
        _knownUnreadCount = unreadCount;
        if (check)
        {
            OGPushLog(@"update state check pts=%d qts=%d unread=%d advanced=%d", (int)pts, (int)qts, (int)unreadCount, advanced ? 1 : 0);
            if (advanced)
                [self requestApplicationWake];
        }
        else
            OGPushLog(@"update stream active pts=%d qts=%d unread=%d", (int)pts, (int)qts, (int)unreadCount);
    }

    if (check && _stateCheckRepeat)
    {
        _stateCheckRepeat = false;
        [self requestUpdatesState:true];
    }
}

- (bool)rememberUpdateDigest:(uint64_t)digest
{
    for (NSUInteger index = 0; index < _recentUpdateCount; index++)
    {
        if (_recentUpdateDigests[index] == digest)
            return false;
    }
    _recentUpdateDigests[_recentUpdateCursor] = digest;
    _recentUpdateCursor = (_recentUpdateCursor + 1) % OGPushRecentUpdateCapacity;
    if (_recentUpdateCount < OGPushRecentUpdateCapacity)
        _recentUpdateCount++;
    return true;
}

- (void)startKeepalive
{
    if (_keepaliveTimer != NULL)
        return;
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    if (timer == NULL)
        return;
    uint64_t interval = (uint64_t)(OGPushKeepaliveInterval * NSEC_PER_SEC);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)interval), interval, 5 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^
    {
        [self sendKeepalive];
    });
    _keepaliveTimer = timer;
    dispatch_resume(timer);
}

- (void)stopKeepalive
{
    if (_keepaliveTimer == NULL)
        return;
    dispatch_source_cancel(_keepaliveTimer);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_keepaliveTimer);
#endif
    _keepaliveTimer = NULL;
    OSAtomicCompareAndSwap32Barrier(1, 0, &_keepalivePending);
}

- (void)sendKeepalive
{
    if (_mtProto == nil)
        return;
    OSAtomicCompareAndSwap32Barrier(0, 1, &_keepalivePending);
    [_mtProto requestTransportTransaction];
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)__unused mtProto
{
    if (!OSAtomicCompareAndSwap32Barrier(1, 0, &_keepalivePending))
        return nil;

    int64_t pingId = 0;
    arc4random_buf(&pingId, sizeof(pingId));
    MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:[OGPushSerialization pingDelayDisconnectPayloadWithPingId:pingId disconnectDelay:OGPushKeepaliveDisconnectDelay] metadata:@"ping_delay_disconnect"];
    message.requiresConfirmation = false;

    volatile int32_t *pending = &_keepalivePending;
    MTMessageTransaction *transaction = [[MTMessageTransaction alloc] initWithMessagePayload:@[message] prepared:nil failed:^
    {
        OSAtomicCompareAndSwap32Barrier(0, 1, pending);
    } completion:^(NSDictionary *messageInternalIdToTransactionId, __unused NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
    {
        if (messageInternalIdToTransactionId[message.internalId] == nil)
            OSAtomicCompareAndSwap32Barrier(0, 1, pending);
    }];
    transaction.requiresEncryption = true;
    return transaction;
}

- (void)requestApplicationWake
{
    if (_mtProto == nil || _applicationReceivesUpdates || _launchAfterApplicationExit)
        return;

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime delay = _lastWakeTime + OGPushWakeInterval - now;
    if (delay > 0.0)
    {
        if (!_wakeScheduled)
        {
            _wakeScheduled = true;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
            {
                _wakeScheduled = false;
                [self requestApplicationWake];
            });
        }
        return;
    }
    _lastWakeTime = now;

    if (_applicationPid > 0)
    {
        OGPushLog(@"terminating suspended application process %d", (int)_applicationPid);
        _launchAfterApplicationExit = true;
        if (kill(_applicationPid, SIGKILL) == 0)
            return;
        _launchAfterApplicationExit = false;
    }

    [self launchApplication];
}

- (void)launchApplication
{
    NSString *bundleIdentifier = _applicationBundleIdentifier != nil ? _applicationBundleIdentifier : @OGPushHelperApplicationBundleIdentifier;
    int result = _launchApplication((__bridge CFStringRef)bundleIdentifier, true);
    OGPushLog(@"background launch requested %@ result=%d", bundleIdentifier, result);
}

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message
{
    if (![message.body isKindOfClass:[OGPushIncomingObject class]])
        return;
    OGPushIncomingObject *object = message.body;
    if (!object.requiresApplication && !object.requiresStateCheck)
        return;

    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (_mtProto != mtProto)
            return;
        if (object.requiresStateCheck)
        {
            OGPushLog(@"update stream gap signature=%08x", (unsigned int)object.signature);
            [self requestUpdatesState:true];
            return;
        }
        if (![self rememberUpdateDigest:object.digest])
        {
            OGPushLog(@"repeated update ignored signature=%08x", (unsigned int)object.signature);
            return;
        }
        OGPushLog(@"update requires application signature=%08x", (unsigned int)object.signature);
        [self requestApplicationWake];
    });
}

- (void)mtProtoConnectionStateChanged:(__unused MTProto *)mtProto isConnected:(bool)isConnected
{
    OGPushLog(@"connection state isConnected=%d", isConnected ? 1 : 0);
}

@end
