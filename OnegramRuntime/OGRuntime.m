#import "OGRuntime.h"
#import "OGDatabaseRuntime.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#include <float.h>
#include <unistd.h>
#include <pthread.h>
#include <sched.h>
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <mach/mach_time.h>
#include <mach/thread_switch.h>
#include <time.h>

static volatile int OGRuntimeInteractionFastFlag = 0;
static volatile int OGRuntimeStartupPhaseCompletedFlag = 0;
static const NSTimeInterval OGRuntimeStartupPhaseTimeout = 30.0;

@interface OGRuntimeState : NSObject
{
    dispatch_queue_t _stateQueue;
    dispatch_queue_t _interactiveQueue;
    dispatch_queue_t _userQueue;
    dispatch_queue_t _storageQueue;
    dispatch_queue_t _utilityQueue;
    dispatch_queue_t _maintenanceQueue;
    dispatch_queue_t _transferQueue;
    dispatch_queue_t _backgroundTargetQueue;
    NSMutableDictionary *_tokens;
    uint64_t _nextToken;
    NSUInteger _interactionCount;
    NSMutableDictionary *_preloadBlocks;
    NSMutableArray *_preloadKeys;
    NSUInteger _preloadKeyOffset;
    NSUInteger _preloadRunningCount;
    NSUInteger _preloadWorkerLimit;
    BOOL _preloadCoolingDown;
    BOOL _suspendsBackgroundWorkDuringInteraction;
    NSMutableArray *_startupDeferredTasks;
    BOOL _startupPhaseCompleted;
    uint64_t _startupPhaseTimeoutGeneration;
}
- (void)beginInteraction;
- (void)enqueuePreload:(id<NSCopying>)key block:(dispatch_block_t)block;
- (void)drainPreloads;
- (void)endInteraction;
- (BOOL)interactionActive;
- (dispatch_queue_t)queueForPriority:(OGRuntimePriority)priority;
- (dispatch_queue_t)transferQueue;
- (void)dispatchPriority:(OGRuntimePriority)priority block:(dispatch_block_t)block;
- (void)dispatchPriority:(OGRuntimePriority)priority after:(NSTimeInterval)delay block:(dispatch_block_t)block;
- (void)dispatchCoalesced:(NSString *)key priority:(OGRuntimePriority)priority delay:(NSTimeInterval)delay block:(dispatch_block_t)block;
- (void)cancelCoalesced:(NSString *)key;
- (void)dispatchAfterStartupPhase:(OGRuntimePriority)priority block:(dispatch_block_t)block;
- (void)completeStartupPhase:(NSString *)reason;
- (void)extendStartupPhase;
- (void)scheduleStartupPhaseTimeoutLocked;
- (uint64_t)nextToken;
@end

@implementation OGRuntimeState

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _stateQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.state", DISPATCH_QUEUE_SERIAL);
        _interactiveQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.interactive", DISPATCH_QUEUE_SERIAL);
        _userQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.user", DISPATCH_QUEUE_SERIAL);
        _storageQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.storage", DISPATCH_QUEUE_SERIAL);
        _utilityQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.utility", DISPATCH_QUEUE_SERIAL);
        _maintenanceQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.maintenance", DISPATCH_QUEUE_SERIAL);
        _transferQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.transfer", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_transferQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));

        int cpuCount = 1;
        size_t cpuSize = sizeof(cpuCount);
        if (sysctlbyname("hw.ncpu", &cpuCount, &cpuSize, NULL, 0) != 0 || cpuCount < 1)
            cpuCount = 1;

        _suspendsBackgroundWorkDuringInteraction = cpuCount == 1;

        dispatch_set_target_queue(_interactiveQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        dispatch_set_target_queue(_userQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));

        if (cpuCount <= 2)
        {
            _backgroundTargetQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.background", DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(_backgroundTargetQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_storageQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            dispatch_set_target_queue(_utilityQueue, _backgroundTargetQueue);
            dispatch_set_target_queue(_maintenanceQueue, _backgroundTargetQueue);
        }
        else
        {
            dispatch_set_target_queue(_storageQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_utilityQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_maintenanceQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        }

        _preloadBlocks = [[NSMutableDictionary alloc] init];
        _preloadKeys = [[NSMutableArray alloc] init];
        _preloadWorkerLimit = (NSUInteger)MIN(4, MAX(1, cpuCount - 1));
        if (OGPlatformUsesConstrainedBackgroundExecution())
            _preloadWorkerLimit = 1;
        _tokens = [[NSMutableDictionary alloc] init];
        _nextToken = 1;
        _startupDeferredTasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)beginInteraction
{
    dispatch_sync(_stateQueue, ^
    {
        _interactionCount++;
        OGRuntimeInteractionFastFlag = _interactionCount != 0 ? 1 : 0;
        if (_interactionCount == 1 && _suspendsBackgroundWorkDuringInteraction)
        {
            dispatch_suspend(_utilityQueue);
            dispatch_suspend(_maintenanceQueue);
        }
    });
}

- (void)endInteraction
{
    dispatch_sync(_stateQueue, ^
    {
        if (_interactionCount == 0)
            return;

        _interactionCount--;
        OGRuntimeInteractionFastFlag = _interactionCount != 0 ? 1 : 0;
        if (_interactionCount == 0 && _suspendsBackgroundWorkDuringInteraction)
        {
            dispatch_resume(_maintenanceQueue);
            dispatch_resume(_utilityQueue);
        }
        [self drainPreloads];
    });
}

- (void)enqueuePreload:(id<NSCopying>)key block:(dispatch_block_t)block
{
    if (key == nil || block == nil)
        return;
    id<NSCopying> taskKey = [key copyWithZone:NULL];
    dispatch_block_t taskBlock = [block copy];
    dispatch_async(_stateQueue, ^
    {
        if ([_preloadBlocks objectForKey:taskKey] == nil)
            [_preloadKeys addObject:taskKey];
        [_preloadBlocks setObject:taskBlock forKey:taskKey];
        [self drainPreloads];
    });
}

- (void)drainPreloads
{
    if (_preloadCoolingDown || (_suspendsBackgroundWorkDuringInteraction && _interactionCount != 0))
        return;
    while (_preloadRunningCount < _preloadWorkerLimit && _preloadKeyOffset < _preloadKeys.count)
    {
        id<NSCopying> key = [_preloadKeys objectAtIndex:_preloadKeyOffset++];
        dispatch_block_t block = [_preloadBlocks objectForKey:key];
        [_preloadBlocks removeObjectForKey:key];
        if (block == nil)
            continue;
        _preloadRunningCount++;
        dispatch_block_t run = ^
        {
            BOOL deferred = _suspendsBackgroundWorkDuringInteraction && OGRuntimeInteractionActiveFast();
            if (!deferred)
            {
                @autoreleasepool
                {
                    block();
                }
            }
            dispatch_async(_stateQueue, ^
            {
                _preloadRunningCount--;
                if (deferred && [_preloadBlocks objectForKey:key] == nil)
                {
                    [_preloadKeys addObject:key];
                    [_preloadBlocks setObject:block forKey:key];
                }
                if (_suspendsBackgroundWorkDuringInteraction && _interactionCount != 0 && !OGPlatformUsesConstrainedBackgroundExecution())
                {
                    _preloadCoolingDown = YES;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.016 * NSEC_PER_SEC)), _stateQueue, ^
                    {
                        _preloadCoolingDown = NO;
                        [self drainPreloads];
                    });
                }
                else
                    [self drainPreloads];
            });
        };
        if (OGPlatformUsesConstrainedBackgroundExecution())
            OGPlatformDispatchAfterCurrentMainRunLoop(run);
        else
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), run);
    }
    if (_preloadKeyOffset == _preloadKeys.count)
    {
        [_preloadKeys removeAllObjects];
        _preloadKeyOffset = 0;
    }
    else if (_preloadKeyOffset >= 128)
    {
        [_preloadKeys removeObjectsInRange:NSMakeRange(0, _preloadKeyOffset)];
        _preloadKeyOffset = 0;
    }
}

- (BOOL)interactionActive
{
    __block BOOL value = NO;
    dispatch_sync(_stateQueue, ^
    {
        value = _interactionCount != 0;
    });
    return value;
}

- (dispatch_queue_t)queueForPriority:(OGRuntimePriority)priority
{
    switch (priority)
    {
        case OGRuntimePriorityInteractive:
            return _interactiveQueue;
        case OGRuntimePriorityUserInitiated:
            return _userQueue;
        case OGRuntimePriorityStorage:
            return _storageQueue;
        case OGRuntimePriorityUtility:
            return _utilityQueue;
        case OGRuntimePriorityMaintenance:
        default:
            return _maintenanceQueue;
    }
}

- (dispatch_queue_t)transferQueue
{
    return _transferQueue;
}

- (void)dispatchPriority:(OGRuntimePriority)priority block:(dispatch_block_t)block
{
    if (block == nil)
        return;

    dispatch_async([self queueForPriority:priority], block);
}

- (void)dispatchPriority:(OGRuntimePriority)priority after:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    if (block == nil)
        return;

    if (delay <= DBL_EPSILON)
    {
        [self dispatchPriority:priority block:block];
        return;
    }

    int64_t nanoseconds = (int64_t)(delay * (NSTimeInterval)NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nanoseconds), [self queueForPriority:priority], block);
}

- (uint64_t)nextToken
{
    uint64_t token = _nextToken++;
    if (_nextToken == 0)
        _nextToken = 1;
    if (token == 0)
        token = _nextToken++;
    return token;
}

- (void)dispatchCoalesced:(NSString *)key priority:(OGRuntimePriority)priority delay:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    if (key.length == 0 || block == nil)
    {
        [self dispatchPriority:priority after:delay block:block];
        return;
    }

    NSString *taskKey = [key copy];
    dispatch_async(_stateQueue, ^
    {
        uint64_t token = [self nextToken];
        NSNumber *tokenValue = [NSNumber numberWithUnsignedLongLong:token];
        [_tokens setObject:tokenValue forKey:taskKey];

        NSTimeInterval safeDelay = delay < 0.0 ? 0.0 : delay;
        int64_t nanoseconds = (int64_t)(safeDelay * (NSTimeInterval)NSEC_PER_SEC);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nanoseconds), _stateQueue, ^
        {
            NSNumber *currentToken = [_tokens objectForKey:taskKey];
            if (currentToken == nil || [currentToken unsignedLongLongValue] != token)
                return;

            [_tokens removeObjectForKey:taskKey];
            dispatch_async([self queueForPriority:priority], block);
        });
    });
}

- (void)cancelCoalesced:(NSString *)key
{
    if (key.length == 0)
        return;

    NSString *taskKey = [key copy];
    dispatch_async(_stateQueue, ^
    {
        [_tokens removeObjectForKey:taskKey];
    });
}

- (void)completeStartupPhaseLocked:(NSString *)reason
{
    if (_startupPhaseCompleted)
        return;

    _startupPhaseCompleted = YES;
    OGRuntimeStartupPhaseCompletedFlag = 1;

    NSArray *tasks = _startupDeferredTasks;
    _startupDeferredTasks = [[NSMutableArray alloc] init];


    for (NSArray *task in tasks)
    {
        OGRuntimePriority priority = (OGRuntimePriority)[[task objectAtIndex:0] intValue];
        dispatch_block_t block = [task objectAtIndex:1];
        [self dispatchPriority:priority block:block];
    }
}

- (void)dispatchAfterStartupPhase:(OGRuntimePriority)priority block:(dispatch_block_t)block
{
    if (block == nil)
        return;

    dispatch_block_t deferredBlock = [block copy];
    dispatch_async(_stateQueue, ^
    {
        if (_startupPhaseCompleted)
        {
            [self dispatchPriority:priority block:deferredBlock];
            return;
        }

        [_startupDeferredTasks addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:(int)priority], deferredBlock, nil]];

        if (_startupPhaseTimeoutGeneration == 0)
            [self scheduleStartupPhaseTimeoutLocked];
    });
}

- (void)scheduleStartupPhaseTimeoutLocked
{
    _startupPhaseTimeoutGeneration++;
    uint64_t generation = _startupPhaseTimeoutGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(OGRuntimeStartupPhaseTimeout * (NSTimeInterval)NSEC_PER_SEC)), _stateQueue, ^
    {
        if (generation == _startupPhaseTimeoutGeneration)
            [self completeStartupPhaseLocked:@"timeout"];
    });
}

- (void)extendStartupPhase
{
    dispatch_async(_stateQueue, ^
    {
        if (_startupPhaseCompleted)
            return;

        [self scheduleStartupPhaseTimeoutLocked];
    });
}

- (void)completeStartupPhase:(NSString *)reason
{
    NSString *completionReason = reason.length != 0 ? [reason copy] : @"unspecified";
    dispatch_async(_stateQueue, ^
    {
        [self completeStartupPhaseLocked:completionReason];
    });
}

@end

static OGRuntimeState *OGRuntimeSharedState(void)
{
    static OGRuntimeState *state = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        state = [[OGRuntimeState alloc] init];
    });
    return state;
}

void OGRuntimeConfigureMainThread(void)
{
    if (pthread_main_np() == 0)
        return;
    pthread_t thread = pthread_self();
    thread_act_t port = pthread_mach_thread_np(thread);
    
    int schedulingPolicy = 0;
    struct sched_param schedulingParameters;
    memset(&schedulingParameters, 0, sizeof(schedulingParameters));
    if (pthread_getschedparam(thread, &schedulingPolicy, &schedulingParameters) != 0)
        return;
    int maximumPriority = sched_get_priority_max(schedulingPolicy);
    
    thread_extended_policy_data_t currentPolicy;
    mach_msg_type_number_t count = THREAD_EXTENDED_POLICY_COUNT;
    boolean_t getDefault = FALSE;
    bool policyKnown = thread_policy_get(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&currentPolicy, &count, &getDefault) == KERN_SUCCESS;
    if (schedulingParameters.sched_priority == maximumPriority && policyKnown && !currentPolicy.timeshare)
        return;
    
#if defined(ONEGRAM_DIAGNOSTICS)
    int previousPriority = schedulingParameters.sched_priority;
    int previousTimeshare = policyKnown ? (int)currentPolicy.timeshare : -1;
#endif
    int priorityResult = 0;
    if (schedulingParameters.sched_priority != maximumPriority)
    {
        schedulingParameters.sched_priority = maximumPriority;
        priorityResult = pthread_setschedparam(thread, schedulingPolicy, &schedulingParameters);
    }
    thread_extended_policy_data_t policy;
    policy.timeshare = FALSE;
    kern_return_t result = thread_policy_set(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&policy, THREAD_EXTENDED_POLICY_COUNT);
#if defined(ONEGRAM_DIAGNOSTICS)
    OGPlatformDiagnosticLog(@"MAINPOLICY previousPriority=%d previousTimeshare=%d priority=%d priorityResult=%d fixed=1 result=%d", previousPriority, previousTimeshare, maximumPriority, priorityResult, (int)result);
#else
    (void)priorityResult;
    (void)result;
#endif
}

void OGRuntimeBeginInteraction(void)
{
    OGRuntimeConfigureMainThread();
    [OGRuntimeSharedState() beginInteraction];
    OGDatabaseRuntimeInteractionStateChanged();
}

void OGRuntimeEndInteraction(void)
{
    [OGRuntimeSharedState() endInteraction];
    OGDatabaseRuntimeInteractionStateChanged();
}

BOOL OGRuntimeInteractionActive(void)
{
    return [OGRuntimeSharedState() interactionActive];
}

BOOL OGRuntimeSingleCoreDevice(void)
{
    static BOOL singleCore = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        int cpuCount = 1;
        size_t cpuSize = sizeof(cpuCount);
        if (sysctlbyname("hw.ncpu", &cpuCount, &cpuSize, NULL, 0) != 0 || cpuCount < 1)
            cpuCount = 1;
        singleCore = cpuCount == 1;
    });
    return singleCore;
}

BOOL OGRuntimeInteractionActiveFast(void)
{
    return OGRuntimeInteractionFastFlag != 0;
}

static pthread_key_t OGRuntimeLatencyCriticalKey;
static pthread_once_t OGRuntimeLatencyCriticalKeyOnce = PTHREAD_ONCE_INIT;
static const int OGRuntimeLatencyCriticalPriority = 33;

static void OGRuntimeCreateLatencyCriticalKey(void)
{
    pthread_key_create(&OGRuntimeLatencyCriticalKey, NULL);
}

BOOL OGRuntimeCurrentThreadLatencyCritical(void)
{
    pthread_once(&OGRuntimeLatencyCriticalKeyOnce, OGRuntimeCreateLatencyCriticalKey);
    return pthread_getspecific(OGRuntimeLatencyCriticalKey) != NULL;
}

void OGRuntimePerformLatencyCritical(dispatch_block_t block)
{
    if (block == nil)
        return;
    pthread_once(&OGRuntimeLatencyCriticalKeyOnce, OGRuntimeCreateLatencyCriticalKey);
    uintptr_t depth = (uintptr_t)pthread_getspecific(OGRuntimeLatencyCriticalKey);
    pthread_setspecific(OGRuntimeLatencyCriticalKey, (const void *)(depth + 1));
    block();
    pthread_setspecific(OGRuntimeLatencyCriticalKey, (const void *)depth);
}

@interface OGRuntimeLatencyTask : NSObject
{
@public
    dispatch_block_t _block;
    dispatch_semaphore_t _semaphore;
}

@end

@implementation OGRuntimeLatencyTask

@end

static const uint64_t OGRuntimeLatencyYieldSliceNanoseconds = 4000000ULL;
static const mach_msg_timeout_t OGRuntimeLatencyYieldMilliseconds = 4;
static pthread_key_t OGRuntimeLatencyLaneKey;
static pthread_once_t OGRuntimeLatencyLaneKeyOnce = PTHREAD_ONCE_INIT;

typedef struct
{
    uint64_t lastYieldTime;
} OGRuntimeLatencyLaneThreadState;

static void OGRuntimeCreateLatencyLaneKey(void)
{
    pthread_key_create(&OGRuntimeLatencyLaneKey, NULL);
}

static uint64_t OGRuntimeAbsoluteNanoseconds(void)
{
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0)
        mach_timebase_info(&timebase);
    return mach_absolute_time() * timebase.numer / timebase.denom;
}

void OGRuntimeLatencyYield(void)
{
    pthread_once(&OGRuntimeLatencyLaneKeyOnce, OGRuntimeCreateLatencyLaneKey);
    OGRuntimeLatencyLaneThreadState *state = (OGRuntimeLatencyLaneThreadState *)pthread_getspecific(OGRuntimeLatencyLaneKey);
    if (state == NULL)
        return;
    uint64_t now = OGRuntimeAbsoluteNanoseconds();
    if (state->lastYieldTime != 0 && now - state->lastYieldTime < OGRuntimeLatencyYieldSliceNanoseconds)
        return;
    if (state->lastYieldTime != 0)
    {
        if (OGRuntimeInteractionFastFlag != 0)
        {
            struct timespec interval;
            interval.tv_sec = 0;
            interval.tv_nsec = (long)OGRuntimeLatencyYieldMilliseconds * 1000000L;
            nanosleep(&interval, NULL);
        }
        else
            thread_switch(MACH_PORT_NULL, SWITCH_OPTION_DEPRESS, OGRuntimeLatencyYieldMilliseconds);
    }
    state->lastYieldTime = OGRuntimeAbsoluteNanoseconds();
}

typedef struct
{
    pthread_mutex_t lock;
    pthread_cond_t condition;
    pthread_once_t once;
    void *tasks;
    pthread_t thread;
    bool started;
    const char *name;
} OGRuntimeLatencyLaneState;

static OGRuntimeLatencyLaneState OGRuntimeLatencyLanes[2] = {
    { PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, PTHREAD_ONCE_INIT, nil, NULL, false, "layout" },
    { PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, PTHREAD_ONCE_INIT, nil, NULL, false, "storage" }
};

static void OGRuntimeConfigureLatencyThread(const char *name)
{
    pthread_t thread = pthread_self();
    thread_act_t port = pthread_mach_thread_np(thread);
    int schedulingPolicy = 0;
    struct sched_param parameters;
    memset(&parameters, 0, sizeof(parameters));
    int priorityResult = -1;
    if (pthread_getschedparam(thread, &schedulingPolicy, &parameters) == 0)
    {
        parameters.sched_priority = MIN(OGRuntimeLatencyCriticalPriority, sched_get_priority_max(schedulingPolicy) - 1);
        priorityResult = pthread_setschedparam(thread, schedulingPolicy, &parameters);
    }
    thread_extended_policy_data_t policy;
    policy.timeshare = FALSE;
    kern_return_t policyResult = thread_policy_set(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&policy, THREAD_EXTENDED_POLICY_COUNT);
#if defined(ONEGRAM_DIAGNOSTICS)
    thread_extended_policy_data_t currentPolicy;
    mach_msg_type_number_t count = THREAD_EXTENDED_POLICY_COUNT;
    boolean_t getDefault = FALSE;
    kern_return_t getResult = thread_policy_get(port, THREAD_EXTENDED_POLICY, (thread_policy_t)&currentPolicy, &count, &getDefault);
    int currentPriority = -1;
    policy_rr_info_data_t fixedInfo;
    count = POLICY_RR_INFO_COUNT;
    if (thread_info(port, THREAD_SCHED_RR_INFO, (thread_info_t)&fixedInfo, &count) == KERN_SUCCESS)
        currentPriority = fixedInfo.base_priority;
    else
    {
        policy_timeshare_info_data_t timeshareInfo;
        count = POLICY_TIMESHARE_INFO_COUNT;
        if (thread_info(port, THREAD_SCHED_TIMESHARE_INFO, (thread_info_t)&timeshareInfo, &count) == KERN_SUCCESS)
            currentPriority = timeshareInfo.base_priority;
    }
    OGPlatformDiagnosticLog(@"LATENCYTHREAD lane=%s priority=%d priorityResult=%d policyResult=%d timeshare=%d", name, currentPriority, priorityResult, (int)policyResult, getResult == KERN_SUCCESS ? (int)currentPolicy.timeshare : -1);
#else
    (void)name;
    (void)priorityResult;
    (void)policyResult;
#endif
}

static void *OGRuntimeLatencyThreadMain(void *context)
{
    OGRuntimeLatencyLaneState *lane = (OGRuntimeLatencyLaneState *)context;
    pthread_once(&OGRuntimeLatencyCriticalKeyOnce, OGRuntimeCreateLatencyCriticalKey);
    pthread_setspecific(OGRuntimeLatencyCriticalKey, (const void *)1);
    pthread_once(&OGRuntimeLatencyLaneKeyOnce, OGRuntimeCreateLatencyLaneKey);
    OGRuntimeLatencyLaneThreadState *threadState = (OGRuntimeLatencyLaneThreadState *)calloc(1, sizeof(OGRuntimeLatencyLaneThreadState));
    pthread_setspecific(OGRuntimeLatencyLaneKey, threadState);
    @autoreleasepool
    {
        OGRuntimeConfigureLatencyThread(lane->name);
    }
    while (true)
    {
        pthread_mutex_lock(&lane->lock);
        NSMutableArray *tasks = (__bridge NSMutableArray *)lane->tasks;
        while (tasks.count == 0)
            pthread_cond_wait(&lane->condition, &lane->lock);
        OGRuntimeLatencyTask *task = [tasks objectAtIndex:0];
        [tasks removeObjectAtIndex:0];
        pthread_mutex_unlock(&lane->lock);
        
        if (threadState != NULL)
            threadState->lastYieldTime = 0;
        @autoreleasepool
        {
            task->_block();
        }
        dispatch_semaphore_signal(task->_semaphore);
    }
    return NULL;
}

static void OGRuntimeStartLatencyLane(OGRuntimeLatencyLaneState *lane)
{
    lane->tasks = (__bridge_retained void *)[[NSMutableArray alloc] init];
    pthread_attr_t attributes;
    pthread_attr_init(&attributes);
    pthread_attr_setdetachstate(&attributes, PTHREAD_CREATE_DETACHED);
    pthread_attr_setstacksize(&attributes, 1024 * 1024);
    lane->started = pthread_create(&lane->thread, &attributes, OGRuntimeLatencyThreadMain, lane) == 0;
    pthread_attr_destroy(&attributes);
}

static void OGRuntimeStartLayoutLatencyLane(void)
{
    OGRuntimeStartLatencyLane(&OGRuntimeLatencyLanes[OGRuntimeLatencyLaneLayout]);
}

static void OGRuntimeStartStorageLatencyLane(void)
{
    OGRuntimeStartLatencyLane(&OGRuntimeLatencyLanes[OGRuntimeLatencyLaneStorage]);
}

void OGRuntimePerformOnLatencyLane(OGRuntimeLatencyLane laneIndex, dispatch_block_t block)
{
    if (block == nil)
        return;
    OGRuntimeLatencyLaneState *lane = &OGRuntimeLatencyLanes[laneIndex == OGRuntimeLatencyLaneStorage ? OGRuntimeLatencyLaneStorage : OGRuntimeLatencyLaneLayout];
    pthread_once(&lane->once, laneIndex == OGRuntimeLatencyLaneStorage ? OGRuntimeStartStorageLatencyLane : OGRuntimeStartLayoutLatencyLane);
    if (!lane->started || pthread_main_np() != 0 || pthread_equal(pthread_self(), lane->thread))
    {
        OGRuntimePerformLatencyCritical(block);
        return;
    }
    
    OGRuntimeLatencyTask *task = [[OGRuntimeLatencyTask alloc] init];
    task->_block = [block copy];
    task->_semaphore = dispatch_semaphore_create(0);
    
    pthread_mutex_lock(&lane->lock);
    [(__bridge NSMutableArray *)lane->tasks addObject:task];
    pthread_cond_signal(&lane->condition);
    pthread_mutex_unlock(&lane->lock);
    
    dispatch_semaphore_wait(task->_semaphore, DISPATCH_TIME_FOREVER);
    dispatch_release(task->_semaphore);
    task->_semaphore = NULL;
}

dispatch_block_t OGRuntimeLatencyCriticalBlock(dispatch_block_t block)
{
    if (block == nil)
        return nil;
    dispatch_block_t copiedBlock = [block copy];
    return [^
    {
        OGRuntimePerformLatencyCritical(copiedBlock);
    } copy];
}

void OGRuntimeCooperateWithInteraction(void)
{
    if (OGRuntimeCurrentThreadLatencyCritical())
    {
        OGRuntimeLatencyYield();
        return;
    }
    if (OGRuntimeInteractionFastFlag == 0)
        return;
    if ([NSThread isMainThread])
        return;
    usleep(1000);
}

dispatch_queue_t OGRuntimeTransferQueue(void)
{
    return [OGRuntimeSharedState() transferQueue];
}


dispatch_queue_t OGRuntimeQueueForPriority(OGRuntimePriority priority)
{
    return [OGRuntimeSharedState() queueForPriority:priority];
}

void OGRuntimeDispatch(OGRuntimePriority priority, dispatch_block_t block)
{
    [OGRuntimeSharedState() dispatchPriority:priority block:block];
}

void OGRuntimeDispatchPreload(id<NSCopying> key, dispatch_block_t block)
{
    [OGRuntimeSharedState() enqueuePreload:key block:block];
}

void OGRuntimeDispatchAfter(OGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block)
{
    [OGRuntimeSharedState() dispatchPriority:priority after:delay block:block];
}

void OGRuntimeDispatchCoalesced(NSString *key, OGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block)
{
    [OGRuntimeSharedState() dispatchCoalesced:key priority:priority delay:delay block:block];
}

void OGRuntimeCancelCoalesced(NSString *key)
{
    [OGRuntimeSharedState() cancelCoalesced:key];
}

void OGRuntimeDispatchAfterStartupPhase(OGRuntimePriority priority, dispatch_block_t block)
{
    [OGRuntimeSharedState() dispatchAfterStartupPhase:priority block:block];
}

void OGRuntimeCompleteStartupPhase(NSString *reason)
{
    if (OGRuntimeStartupPhaseCompletedFlag != 0)
        return;

    [OGRuntimeSharedState() completeStartupPhase:reason];
}

void OGRuntimeExtendStartupPhase(void)
{
    if (OGRuntimeStartupPhaseCompletedFlag != 0)
        return;

    [OGRuntimeSharedState() extendStartupPhase];
}

BOOL OGRuntimeStartupPhaseCompleted(void)
{
    return OGRuntimeStartupPhaseCompletedFlag != 0;
}
