#import "OGHelperDaemon.h"

#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <errno.h>
#import <libkern/OSAtomic.h>
#import <notify.h>
#import <signal.h>
#import <sys/stat.h>
#import <sys/sysctl.h>
#import <objc/message.h>
#import <pthread.h>
#import <stdio.h>

#import "OGHelperProtocol.h"
#import "OGHelperSerialization.h"
#import "../OnegramLauncher/OGSystemApplication.h"
#import "../OnegramRuntime/OGDiagnostics.h"

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
#import "../submodules/MtProtoKit/MTProtoKit/MTLogging.h"

#ifndef ONEGRAM_DIAGNOSTICS_DEFAULT
#error ONEGRAM_DIAGNOSTICS_DEFAULT must be provided by build.sh
#endif

typedef int (*OGHelperLaunchApplicationFunction)(CFStringRef identifier, Boolean suspended);

static NSString *const OGHelperKeychainDirectory = @"/var/mobile/Library/Onegram/daemon";
static NSString *const OGHelperSystemApplicationDocumentsPath = @OGSystemApplicationMobileHomePath "/" OGSystemApplicationHomeRelativePath "/Documents";
static const unsigned long long OGHelperLogSizeLimit = 256 * 1024;
static const NSTimeInterval OGHelperHeartbeatInterval = 60.0;
static const CFAbsoluteTime OGHelperWakeInterval = 20.0;
static const NSTimeInterval OGHelperApplicationFinishingWindow = 120.0;
static const NSTimeInterval OGHelperKeepaliveInterval = 60.0;
static const int32_t OGHelperKeepaliveDisconnectDelay = 75;
static const CFAbsoluteTime OGHelperStateRefreshInterval = 600.0;
static const NSTimeInterval OGHelperLaunchRetryDelay = 1.0;
static const NSUInteger OGHelperLaunchAttemptLimit = 6;

enum
{
    OGHelperRecentUpdateCapacity = 64
};

static pthread_mutex_t OGHelperLogMutex = PTHREAD_MUTEX_INITIALIZER;

static void OGHelperWriteLogLine(NSString *line)
{
    NSData *data = [[[NSString alloc] initWithFormat:@"[onegramd %@] %@\n", [NSDate date], line] dataUsingEncoding:NSUTF8StringEncoding];

    pthread_mutex_lock(&OGHelperLogMutex);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManager attributesOfItemAtPath:@OGHelperLogPath error:NULL];
    static CFAbsoluteTime lastRotation = 0;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (lastRotation == 0)
        lastRotation = now;
    if (attributes != nil && ([attributes fileSize] > OGHelperLogSizeLimit || now - lastRotation >= 3600.0))
    {
        NSString *name = [NSString stringWithFormat:@"onegramd.%@.log", [[NSProcessInfo processInfo] globallyUniqueString]];
        NSString *archive = [@OGHelperLogDirectoryPath stringByAppendingPathComponent:name];
        if ([fileManager moveItemAtPath:@OGHelperLogPath toPath:archive error:NULL])
        {
            attributes = nil;
            lastRotation = now;
        }
    }

    if (attributes == nil)
        [data writeToFile:@OGHelperLogPath atomically:false];
    else
    {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:@OGHelperLogPath];
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    }
    pthread_mutex_unlock(&OGHelperLogMutex);
}

static void OGHelperLogv(NSString *format, va_list args)
{
    @autoreleasepool
    {
        OGHelperWriteLogLine([[NSString alloc] initWithFormat:format arguments:args]);
    }
}

static void OGHelperLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    OGHelperLogv(format, args);
    va_end(args);
}

static void OGHelperDebugLog(NSString *format, ...)
{
    if (!OGDiagnosticsEnabled())
        return;
    va_list args;
    va_start(args, format);
    OGHelperLogv(format, args);
    va_end(args);
}

static void OGHelperProtocolLog(NSString *format, va_list args)
{
    OGHelperLogv([@"mtproto " stringByAppendingString:format], args);
}

static NSString *OGHelperApplicationStatePath(NSString *documentsPath)
{
    return [[documentsPath stringByAppendingPathComponent:@OGHelperAuthInfoDirectoryName] stringByAppendingPathComponent:@OGHelperAppStateFileName];
}

static bool OGHelperApplicationProcessIsRunning(pid_t pid, NSTimeInterval stateTime)
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

static bool OGHelperDeviceSupportsMultitasking(void)
{
    UIDevice *device = [UIDevice currentDevice];
    SEL selector = @selector(isMultitaskingSupported);
    if (![device respondsToSelector:selector])
        return false;
    return ((BOOL (*)(id, SEL))objc_msgSend)(device, selector);
}

static OGHelperLaunchApplicationFunction OGHelperResolveLaunchApplicationFunction(void)
{
    void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    if (handle == NULL)
        return NULL;
    return (OGHelperLaunchApplicationFunction)dlsym(handle, "SBSLaunchApplicationWithIdentifier");
}

static void OGHelperApplicationStateChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo);
static void OGHelperAuthInfoChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo);
static void OGHelperDiagnosticsChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo);

@interface OGHelperDaemon ()
{
    OGHelperLaunchApplicationFunction _launchApplication;

    bool _observersRegistered;

    bool _applicationReceivesUpdates;
    pid_t _terminatingApplicationPid;
    NSTimeInterval _scheduledFinishingDeadline;
    NSString *_applicationDocumentsPath;
    NSString *_applicationBundleIdentifier;
    pid_t _applicationPid;
    dispatch_source_t _applicationExitSource;

    NSTimer *_heartbeatTimer;
    CFAbsoluteTime _lastWakeTime;
    bool _wakeScheduled;
    NSUInteger _launchAttempt;
    NSUInteger _launchGeneration;

    uint64_t _recentUpdateDigests[OGHelperRecentUpdateCapacity];
    NSUInteger _recentUpdateCount;
    NSUInteger _recentUpdateCursor;

    bool _knownStateValid;
    int32_t _knownPts;
    int32_t _knownQts;
    int32_t _knownUnreadCount;
    bool _stateCheckInFlight;
    bool _stateCheckRepeat;
    CFAbsoluteTime _lastStateRequestTime;

    bool _connected;
    bool _connectionInterrupted;

    dispatch_source_t _keepaliveTimer;
    volatile int32_t _keepalivePending;

    MTContext *_context;
    MTProto *_mtProto;
    OGHelperSerialization *_serialization;
    MTRequestMessageService *_requestService;
    int64_t _connectedAuthKeyId;
    NSString *_connectedApiInitializationHash;
    bool _daemonFlagPosted;
}

- (void)applicationStateChanged;
- (void)authInfoChanged;
- (void)diagnosticsChanged;
- (void)writeLogSnapshot;
- (void)launchApplication;
- (bool)applicationReceivesUpdatesInState:(NSString *)applicationState since:(NSTimeInterval)stateTime;

@end

static void OGHelperApplicationStateChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo)
{
    [(__bridge OGHelperDaemon *)observer applicationStateChanged];
}

static void OGHelperAuthInfoChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo)
{
    [(__bridge OGHelperDaemon *)observer authInfoChanged];
}

static void OGHelperDiagnosticsChanged(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo)
{
    [(__bridge OGHelperDaemon *)observer diagnosticsChanged];
}

static NSData *OGHelperRecentLogData(NSData *data, NSDate *cutoff)
{
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (text == nil)
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (text == nil)
        return nil;
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";
    NSMutableString *result = [[NSMutableString alloc] init];
    bool include = false;
    for (NSString *line in [text componentsSeparatedByString:@"\n"])
    {
        if ([line hasPrefix:@"[onegramd "] && line.length >= 36)
        {
            NSDate *date = [formatter dateFromString:[line substringWithRange:NSMakeRange(10, 25)]];
            if (date != nil)
                include = [date compare:cutoff] != NSOrderedAscending;
        }
        if (include)
            [result appendFormat:@"%@\n", line];
    }
    return [result dataUsingEncoding:NSUTF8StringEncoding];
}

static void OGHelperLogSnapshotRequested(__unused CFNotificationCenterRef center, void *observer, __unused CFStringRef name, __unused const void *object, __unused CFDictionaryRef userInfo)
{
    OGHelperDaemon *daemon = (__bridge OGHelperDaemon *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{ [daemon writeLogSnapshot]; });
}

@implementation OGHelperDaemon

- (bool)start
{
    OGDiagnosticsActivate(OGDiagnosticsComponentHelper, ONEGRAM_DIAGNOSTICS_DEFAULT);
    MTLogSetLoggingFunction(&OGHelperProtocolLog);
    OGHelperLog(@"starting pid=%d diagnostics=%d", (int)getpid(), OGDiagnosticsEnabled() ? 1 : 0);

    if (!OGHelperDeviceSupportsMultitasking())
    {
        OGHelperLog(@"device has no multitasking, background wake is impossible");
        return false;
    }

    _launchApplication = OGHelperResolveLaunchApplicationFunction();
    if (_launchApplication == NULL)
    {
        OGHelperLog(@"SBSLaunchApplicationWithIdentifier unavailable");
        return false;
    }

    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, (__bridge const void *)self, &OGHelperApplicationStateChanged, CFSTR(OGHelperApplicationStateNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, (__bridge const void *)self, &OGHelperAuthInfoChanged, CFSTR(OGHelperAuthInfoChangedNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, (__bridge const void *)self, &OGHelperDiagnosticsChanged, CFSTR(OGHelperDiagnosticsChangedNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, (__bridge const void *)self, &OGHelperLogSnapshotRequested, CFSTR(OGHelperLogSnapshotRequestNotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    _observersRegistered = true;

    _heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:OGHelperHeartbeatInterval target:self selector:@selector(heartbeat) userInfo:nil repeats:true];

    [self reconcile];
    return true;
}

- (void)stop
{
    OGHelperLog(@"stopping");

    if (_observersRegistered)
    {
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self);
        _observersRegistered = false;
    }
    [_heartbeatTimer invalidate];
    _heartbeatTimer = nil;
    [self stopObservingApplicationProcess];
    [self cancelPendingLaunch];
    [self disconnect];
    [self removeDaemonFlag];
}

- (NSString *)helperDirectoryPath
{
    NSString *documentsPath = [self applicationDocumentsPath];
    if (documentsPath == nil)
        return nil;
    return [documentsPath stringByAppendingPathComponent:@OGHelperAuthInfoDirectoryName];
}

- (void)writeDaemonFlag
{
    NSString *dir = [self helperDirectoryPath];
    if (dir == nil)
        return;
    NSString *path = [dir stringByAppendingPathComponent:@OGHelperDaemonFlagFileName];
    NSData *data = [[[NSString alloc] initWithFormat:@"%d %.0f %d", (int)getpid(), CFAbsoluteTimeGetCurrent(), OGDiagnosticsEnabled() ? 1 : 0] dataUsingEncoding:NSUTF8StringEncoding];
    if (![data writeToFile:path options:NSDataWritingAtomic error:NULL])
        return;
    [[NSFileManager defaultManager] setAttributes:@{@"NSFileProtectionKey": @"NSFileProtectionNone"} ofItemAtPath:path error:NULL];
    if (!_daemonFlagPosted)
    {
        _daemonFlagPosted = true;
        notify_post(OGHelperDaemonStateNotification);
    }
}

- (void)writeLogSnapshot
{
    NSString *directory = [self helperDirectoryPath];
    if (directory == nil || !OGDiagnosticsEnabled())
        return;
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ queue = dispatch_queue_create("dev.IllyaGIF.onegramd.log-snapshot", DISPATCH_QUEUE_SERIAL); });
    dispatch_async(queue, ^{
        @autoreleasepool
        {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *temporary = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@".push-%@.tmp", [[NSProcessInfo processInfo] globallyUniqueString]]];
            NSString *destination = [directory stringByAppendingPathComponent:@OGHelperLogSnapshotFileName];
            if (![fileManager createFileAtPath:temporary contents:nil attributes:nil])
                return;
            NSFileHandle *output = [NSFileHandle fileHandleForWritingAtPath:temporary];
            if (output == nil)
            {
                [fileManager removeItemAtPath:temporary error:NULL];
                return;
            }
            bool success = true;
            pthread_mutex_lock(&OGHelperLogMutex);
            @try
            {
                NSMutableArray *paths = [[NSMutableArray alloc] init];
                for (NSString *name in [fileManager contentsOfDirectoryAtPath:@OGHelperLogDirectoryPath error:NULL])
                    if ([name hasPrefix:@"onegramd."] && [name hasSuffix:@".log"] && ![name isEqualToString:@"onegramd.stderr.log"] && ![name isEqualToString:@"onegramd.log"])
                        [paths addObject:[@OGHelperLogDirectoryPath stringByAppendingPathComponent:name]];
                [paths sortUsingSelector:@selector(compare:)];
                [paths addObject:@OGHelperRotatedLogPath];
                [paths addObject:@OGHelperLogPath];
                [paths addObject:@OGHelperStandardErrorLogPath];
                NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-24.0 * 60.0 * 60.0];
                for (NSString *path in paths)
                {
                    @autoreleasepool
                    {
                        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:NULL];
                        NSDate *modified = [attributes fileModificationDate];
                        if (modified == nil)
                            continue;
                        bool standardError = [path isEqualToString:@OGHelperStandardErrorLogPath];
                        if ([modified compare:cutoff] == NSOrderedAscending)
                        {
                            if (![path isEqualToString:@OGHelperLogPath] && !standardError)
                                [fileManager removeItemAtPath:path error:NULL];
                            continue;
                        }
                        NSFileHandle *input = [NSFileHandle fileHandleForReadingAtPath:path];
                        if (input == nil)
                            continue;
                        if (standardError)
                        {
                            if ([attributes fileSize] != 0)
                            {
                                [output writeData:[[NSString stringWithFormat:@"=== %@ ===\n", path.lastPathComponent] dataUsingEncoding:NSUTF8StringEncoding]];
                                unsigned long long remaining = [attributes fileSize];
                                while (remaining != 0)
                                {
                                    NSData *chunk = [input readDataOfLength:(NSUInteger)MIN(remaining, 65536ULL)];
                                    if (chunk.length == 0)
                                        break;
                                    [output writeData:chunk];
                                    remaining -= chunk.length;
                                }
                                [output writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
                            }
                        }
                        else
                        {
                            NSData *data = OGHelperRecentLogData([input readDataToEndOfFile], cutoff);
                            if (data.length != 0)
                            {
                                [output writeData:[[NSString stringWithFormat:@"=== %@ ===\n", path.lastPathComponent] dataUsingEncoding:NSUTF8StringEncoding]];
                                [output writeData:data];
                            }
                        }
                        [input closeFile];
                    }
                }
                [output closeFile];
            }
            @catch (__unused NSException *exception)
            {
                success = false;
                [output closeFile];
            }
            @finally
            {
                pthread_mutex_unlock(&OGHelperLogMutex);
            }
            if (success)
            {
                [fileManager setAttributes:@{NSFilePosixPermissions: @0644, @"NSFileProtectionKey": @"NSFileProtectionNone"} ofItemAtPath:temporary error:NULL];
                success = rename(temporary.fileSystemRepresentation, destination.fileSystemRepresentation) == 0;
            }
            if (!success)
                [fileManager removeItemAtPath:temporary error:NULL];
        }
    });
}

- (void)removeDaemonFlag
{
    NSString *dir = [self helperDirectoryPath];
    if (dir == nil)
        return;
    [[NSFileManager defaultManager] removeItemAtPath:[dir stringByAppendingPathComponent:@OGHelperDaemonFlagFileName] error:NULL];
    if (_daemonFlagPosted)
    {
        _daemonFlagPosted = false;
        notify_post(OGHelperDaemonStateNotification);
    }
}

- (bool)readApplicationProcess:(pid_t *)outPid stateTime:(NSTimeInterval *)outStateTime bundleIdentifier:(NSString **)outBundleIdentifier state:(NSString **)outState
{
    NSString *dir = [self helperDirectoryPath];
    if (dir == nil)
        return false;
    NSData *data = [NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@OGHelperAppStateFileName]];
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

- (void)diagnosticsChanged
{
    bool previous = OGDiagnosticsEnabled();
    OGDiagnosticsActivate(OGDiagnosticsComponentHelper, ONEGRAM_DIAGNOSTICS_DEFAULT);
    if (previous == OGDiagnosticsEnabled())
        return;
    OGHelperLog(@"diagnostics %@", OGDiagnosticsEnabled() ? @"enabled" : @"disabled");
    [self writeDaemonFlag];
}

- (void)authInfoChanged
{
    NSDictionary *authInfo = [self loadAuthInfo];
    MTDatacenterAuthInfo *datacenterAuthInfo = authInfo[@"authInfo"];
    MTApiEnvironment *apiEnvironment = [self apiEnvironmentFromAuthInfo:authInfo];
    if (_mtProto != nil && [datacenterAuthInfo isKindOfClass:[MTDatacenterAuthInfo class]] && datacenterAuthInfo.authKeyId == _connectedAuthKeyId && [apiEnvironment.apiInitializationHash isEqualToString:_connectedApiInitializationHash])
        return;

    OGHelperLog(@"auth info changed");
    [self disconnect];
    [self reconcile];
}

- (void)applicationProcessExited:(pid_t)pid
{
    if (pid != _applicationPid)
        return;

    OGHelperLog(@"application process %d exited", (int)pid);
    [self trackApplicationProcess:0];
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
    static CFAbsoluteTime lastCleanup = 0;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (lastCleanup == 0 || now - lastCleanup >= 3600.0)
    {
        lastCleanup = now;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            @autoreleasepool
            {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                pthread_mutex_lock(&OGHelperLogMutex);
                for (NSString *name in [fileManager contentsOfDirectoryAtPath:@OGHelperLogDirectoryPath error:NULL])
                {
                    if (!([name hasPrefix:@"onegramd."] && [name hasSuffix:@".log"]) && ![name isEqualToString:@"onegramd.log.1"])
                        continue;
                    if ([name isEqualToString:@"onegramd.log"] || [name isEqualToString:@"onegramd.stderr.log"])
                        continue;
                    NSString *path = [@OGHelperLogDirectoryPath stringByAppendingPathComponent:name];
                    NSDate *modified = [[fileManager attributesOfItemAtPath:path error:NULL] fileModificationDate];
                    if (modified != nil && -[modified timeIntervalSinceNow] > 24.0 * 60.0 * 60.0)
                        [fileManager removeItemAtPath:path error:NULL];
                }
                pthread_mutex_unlock(&OGHelperLogMutex);
            }
        });
    }
    [self reconcile];

    if (_mtProto != nil && _connected && CFAbsoluteTimeGetCurrent() - _lastStateRequestTime >= OGHelperStateRefreshInterval)
        [self requestUpdatesState:true];
}

- (bool)applicationReceivesUpdatesInState:(NSString *)applicationState since:(NSTimeInterval)stateTime
{
    if ([applicationState isEqualToString:@"suspended"])
        return false;
    if (![applicationState isEqualToString:@"finishing"])
        return true;

    NSTimeInterval deadline = stateTime + OGHelperApplicationFinishingWindow;
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

    bool alive = stateAvailable && OGHelperApplicationProcessIsRunning(pid, stateTime);
    bool receivesUpdates = alive && [self applicationReceivesUpdatesInState:applicationState since:stateTime];
    if (receivesUpdates != _applicationReceivesUpdates)
        OGHelperDebugLog(@"application state=%@ alive=%d receiving=%d", applicationState != nil ? applicationState : @"legacy", alive ? 1 : 0, receivesUpdates ? 1 : 0);
    _applicationReceivesUpdates = receivesUpdates;
    [self trackApplicationProcess:alive ? pid : 0];
}

- (void)trackApplicationProcess:(pid_t)pid
{
    if (pid == _applicationPid)
        return;

    pid_t previousPid = _applicationPid;
    [self stopObservingApplicationProcess];

    if (pid > 0)
    {
        _applicationPid = pid;
        [self cancelPendingLaunch];
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, (uintptr_t)pid, DISPATCH_PROC_EXIT, dispatch_get_main_queue());
        if (source != NULL)
        {
            dispatch_source_set_event_handler(source, ^
            {
                [self applicationProcessExited:pid];
            });
            _applicationExitSource = source;
            dispatch_resume(source);
        }
    }

    if (_terminatingApplicationPid == 0 || _terminatingApplicationPid != previousPid)
        return;

    _terminatingApplicationPid = 0;
    if (pid > 0)
        OGHelperLog(@"application restarted as process %d", (int)pid);
    else
        [self launchApplication];
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
    if (_applicationDocumentsPath != nil && [fileManager fileExistsAtPath:OGHelperApplicationStatePath(_applicationDocumentsPath)])
        return _applicationDocumentsPath;

    NSMutableArray *candidates = [[NSMutableArray alloc] initWithObjects:OGHelperSystemApplicationDocumentsPath, nil];
    for (NSString *root in @[@"/var/mobile/Containers/Data/Application", @"/var/mobile/Applications"])
    {
        for (NSString *entry in [fileManager contentsOfDirectoryAtPath:root error:NULL])
            [candidates addObject:[[root stringByAppendingPathComponent:entry] stringByAppendingPathComponent:@"Documents"]];
    }

    NSString *discoveredPath = nil;
    NSDate *discoveredDate = nil;
    for (NSString *documentsPath in candidates)
    {
        NSDate *modified = [[fileManager attributesOfItemAtPath:OGHelperApplicationStatePath(documentsPath) error:NULL] fileModificationDate];
        if (modified != nil && (discoveredDate == nil || [modified compare:discoveredDate] == NSOrderedDescending))
        {
            discoveredPath = documentsPath;
            discoveredDate = modified;
        }
    }

    if (discoveredPath != nil && ![discoveredPath isEqualToString:_applicationDocumentsPath])
    {
        OGHelperLog(@"application container %@", discoveredPath);
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
        OGHelperLog(@"application state not found");
        return nil;
    }

    NSString *authInfoPath = [[documentsPath stringByAppendingPathComponent:@OGHelperAuthInfoDirectoryName] stringByAppendingPathComponent:@OGHelperAuthInfoFileName];
    NSData *data = [NSData dataWithContentsOfFile:authInfoPath];
    if (data == nil)
    {
        OGHelperLog(@"auth info is not available yet");
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
        OGHelperLog(@"auth info is unreadable");
        return nil;
    }

    return decoded;
}

- (NSString *)keychainDirectory
{
    [[NSFileManager defaultManager] createDirectoryAtPath:OGHelperKeychainDirectory withIntermediateDirectories:true attributes:@{NSFilePosixPermissions: @(S_IRWXU)} error:NULL];
    return OGHelperKeychainDirectory;
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
        OGHelperLog(@"auth info is incomplete");
        return false;
    }

    NSInteger datacenterId = [datacenterIdValue integerValue];
    OGHelperSerialization *serialization = [[OGHelperSerialization alloc] initWithLayer:[apiEnvironment.layer unsignedIntegerValue]];

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

    OGHelperLog(@"listening for updates dc=%d testing=%d layer=%d", (int)datacenterId, isTestingEnvironment ? 1 : 0, (int)[serialization currentLayer]);

    [self requestUpdatesState:false];
    [self startKeepalive];

    return true;
}

- (void)disconnect
{
    if (_mtProto == nil)
        return;

    OGHelperLog(@"releasing update stream");

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
    _connected = false;
    _connectionInterrupted = false;
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
    _lastStateRequestTime = CFAbsoluteTimeGetCurrent();

    NSData *payload = nil;
    OGHelperUpdatesStateParser parser = [_serialization requestUpdatesState:&payload];
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
        OGHelperLog(@"updates.getState failed: %@", error);
        if (check)
            [self requestApplicationWake];
    }
    else
    {
        int32_t pts = [state[@"pts"] intValue];
        int32_t qts = [state[@"qts"] intValue];
        int32_t unreadCount = [state[@"unreadCount"] intValue];
        bool advanced = !_knownStateValid || qts > _knownQts || unreadCount > _knownUnreadCount;
        _knownStateValid = true;
        _knownPts = pts;
        _knownQts = qts;
        _knownUnreadCount = unreadCount;
        if (check)
        {
            OGHelperDebugLog(@"update state check pts=%d qts=%d unread=%d advanced=%d", (int)pts, (int)qts, (int)unreadCount, advanced ? 1 : 0);
            if (advanced)
                [self requestApplicationWake];
        }
        else
            OGHelperLog(@"update stream active pts=%d qts=%d unread=%d", (int)pts, (int)qts, (int)unreadCount);
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
    _recentUpdateCursor = (_recentUpdateCursor + 1) % OGHelperRecentUpdateCapacity;
    if (_recentUpdateCount < OGHelperRecentUpdateCapacity)
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
    uint64_t interval = (uint64_t)(OGHelperKeepaliveInterval * NSEC_PER_SEC);
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
    MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:[OGHelperSerialization pingDelayDisconnectPayloadWithPingId:pingId disconnectDelay:OGHelperKeepaliveDisconnectDelay] metadata:@"ping_delay_disconnect"];
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
    if (_mtProto == nil || _applicationReceivesUpdates || _terminatingApplicationPid != 0)
        return;

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime delay = _lastWakeTime + OGHelperWakeInterval - now;
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

    pid_t pid = _applicationPid;
    if (pid > 0)
    {
        OGHelperLog(@"terminating suspended application process %d", (int)pid);
        if (kill(pid, SIGKILL) == 0)
        {
            _terminatingApplicationPid = pid;
            return;
        }
        int error = errno;
        OGHelperLog(@"terminating application process %d failed errno=%d", (int)pid, error);
        if (error != ESRCH)
            return;
        [self trackApplicationProcess:0];
    }

    [self launchApplication];
}

- (void)launchApplication
{
    [self cancelPendingLaunch];
    [self attemptApplicationLaunch];
}

- (void)cancelPendingLaunch
{
    _launchGeneration++;
    _launchAttempt = 0;
}

- (void)attemptApplicationLaunch
{
    NSString *bundleIdentifier = _applicationBundleIdentifier != nil ? _applicationBundleIdentifier : @OGHelperApplicationBundleIdentifier;
    int result = _launchApplication((__bridge CFStringRef)bundleIdentifier, true);
    _launchAttempt++;
    OGHelperLog(@"background launch requested %@ result=%d attempt=%u", bundleIdentifier, result, (unsigned int)_launchAttempt);
    if (result == 0)
    {
        [self cancelPendingLaunch];
        return;
    }
    if (_launchAttempt >= OGHelperLaunchAttemptLimit)
    {
        OGHelperLog(@"background launch abandoned after %u attempts", (unsigned int)_launchAttempt);
        [self cancelPendingLaunch];
        return;
    }

    NSUInteger generation = _launchGeneration;
    NSTimeInterval delay = OGHelperLaunchRetryDelay * (double)(1u << (_launchAttempt - 1));
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        if (generation != _launchGeneration)
            return;
        [self refreshApplicationState];
        if (generation != _launchGeneration || _applicationReceivesUpdates)
            return;
        [self attemptApplicationLaunch];
    });
}

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message
{
    if (![message.body isKindOfClass:[OGHelperIncomingObject class]])
        return;
    OGHelperIncomingObject *object = message.body;
    if (!object.requiresApplication && !object.requiresStateCheck)
        return;

    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (_mtProto != mtProto)
            return;
        if (object.requiresStateCheck)
        {
            OGHelperDebugLog(@"update stream gap signature=%08x", (unsigned int)object.signature);
            [self requestUpdatesState:true];
            return;
        }
        if (![self rememberUpdateDigest:object.digest])
        {
            OGHelperDebugLog(@"repeated update ignored signature=%08x", (unsigned int)object.signature);
            return;
        }
        OGHelperDebugLog(@"update requires application signature=%08x", (unsigned int)object.signature);
        [self requestApplicationWake];
    });
}

- (void)mtProtoConnectionStateChanged:(MTProto *)mtProto isConnected:(bool)isConnected
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (_mtProto != mtProto || _connected == isConnected)
            return;

        OGHelperDebugLog(@"connection state isConnected=%d", isConnected ? 1 : 0);
        _connected = isConnected;
        if (!isConnected)
        {
            _connectionInterrupted = _knownStateValid;
            return;
        }
        if (!_connectionInterrupted)
            return;

        _connectionInterrupted = false;
        [self requestUpdatesState:true];
    });
}

@end
