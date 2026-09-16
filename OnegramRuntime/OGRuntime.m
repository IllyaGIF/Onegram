#import "OGRuntime.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#include <float.h>

@interface OGRuntimeState : NSObject
{
    dispatch_queue_t _stateQueue;
    dispatch_queue_t _interactiveQueue;
    dispatch_queue_t _userQueue;
    dispatch_queue_t _storageQueue;
    dispatch_queue_t _utilityQueue;
    dispatch_queue_t _maintenanceQueue;
    dispatch_queue_t _backgroundTargetQueue;
    NSMutableDictionary *_tokens;
    uint64_t _nextToken;
    NSUInteger _interactionCount;
}
- (void)beginInteraction;
- (void)endInteraction;
- (BOOL)interactionActive;
- (dispatch_queue_t)queueForPriority:(OGRuntimePriority)priority;
- (void)dispatchPriority:(OGRuntimePriority)priority block:(dispatch_block_t)block;
- (void)dispatchPriority:(OGRuntimePriority)priority after:(NSTimeInterval)delay block:(dispatch_block_t)block;
- (void)dispatchCoalesced:(NSString *)key priority:(OGRuntimePriority)priority delay:(NSTimeInterval)delay block:(dispatch_block_t)block;
- (void)cancelCoalesced:(NSString *)key;
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

        int cpuCount = 1;
        size_t cpuSize = sizeof(cpuCount);
        if (sysctlbyname("hw.ncpu", &cpuCount, &cpuSize, NULL, 0) != 0 || cpuCount < 1)
            cpuCount = 1;

        dispatch_set_target_queue(_interactiveQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        dispatch_set_target_queue(_userQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));

        if (cpuCount <= 2)
        {
            _backgroundTargetQueue = dispatch_queue_create("dev.IllyaGIF.Onegram.runtime.background", DISPATCH_QUEUE_SERIAL);
            dispatch_set_target_queue(_backgroundTargetQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_storageQueue, _backgroundTargetQueue);
            dispatch_set_target_queue(_utilityQueue, _backgroundTargetQueue);
            dispatch_set_target_queue(_maintenanceQueue, _backgroundTargetQueue);
        }
        else
        {
            dispatch_set_target_queue(_storageQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_utilityQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
            dispatch_set_target_queue(_maintenanceQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        }

        _tokens = [[NSMutableDictionary alloc] init];
        _nextToken = 1;
    }
    return self;
}

- (void)beginInteraction
{
    dispatch_sync(_stateQueue, ^
    {
        _interactionCount++;
        if (_interactionCount == 1)
        {
            dispatch_suspend(_storageQueue);
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
        if (_interactionCount == 0)
        {
            dispatch_resume(_maintenanceQueue);
            dispatch_resume(_utilityQueue);
            dispatch_resume(_storageQueue);
        }
    });
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

void OGRuntimeBeginInteraction(void)
{
    [OGRuntimeSharedState() beginInteraction];
}

void OGRuntimeEndInteraction(void)
{
    [OGRuntimeSharedState() endInteraction];
}

BOOL OGRuntimeInteractionActive(void)
{
    return [OGRuntimeSharedState() interactionActive];
}

dispatch_queue_t OGRuntimeQueueForPriority(OGRuntimePriority priority)
{
    return [OGRuntimeSharedState() queueForPriority:priority];
}

void OGRuntimeDispatch(OGRuntimePriority priority, dispatch_block_t block)
{
    [OGRuntimeSharedState() dispatchPriority:priority block:block];
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
