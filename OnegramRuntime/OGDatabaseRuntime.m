#import "OGDatabaseRuntime.h"
#import "OGRuntime.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "../thirdparty/sqlcipher/sqlite3.h"
#include <pthread.h>
#include <stdint.h>
#include <libkern/OSAtomic.h>
#include <sched.h>

typedef enum
{
    OGDatabaseRuntimeBoostNone = 0,
    OGDatabaseRuntimeBoostWaiter = 1,
    OGDatabaseRuntimeBoostMainWaiter = 2
} OGDatabaseRuntimeBoost;

static const int OGDatabaseRuntimeWaiterPriority = 33;

static BOOL OGDatabaseRuntimeIsConstrained(void)
{
    return OGPlatformUsesConstrainedBackgroundExecution();
}

static pthread_key_t OGDatabaseRuntimeSynchronousKey;
static pthread_once_t OGDatabaseRuntimeSynchronousKeyOnce = PTHREAD_ONCE_INIT;

static void OGDatabaseRuntimeCreateSynchronousKey(void)
{
    pthread_key_create(&OGDatabaseRuntimeSynchronousKey, NULL);
}

static void OGDatabaseRuntimeSetSynchronous(BOOL synchronous)
{
    pthread_once(&OGDatabaseRuntimeSynchronousKeyOnce, OGDatabaseRuntimeCreateSynchronousKey);
    pthread_setspecific(OGDatabaseRuntimeSynchronousKey, synchronous ? (void *)(uintptr_t)1 : NULL);
}

static BOOL OGDatabaseRuntimeCurrentTaskIsSynchronous(void)
{
    pthread_once(&OGDatabaseRuntimeSynchronousKeyOnce, OGDatabaseRuntimeCreateSynchronousKey);
    return pthread_getspecific(OGDatabaseRuntimeSynchronousKey) != NULL;
}

@interface OGDatabaseRuntimeTask : NSObject
{
@public
    dispatch_queue_t _queue;
    dispatch_block_t _block;
    dispatch_semaphore_t _semaphore;
    BOOL _synchronous;
    BOOL _mainThreadWaiter;
    BOOL _startupCritical;
    CFAbsoluteTime _submittedAt;
}
- (instancetype)initWithQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous mainThreadWaiter:(BOOL)mainThreadWaiter startupCritical:(BOOL)startupCritical block:(dispatch_block_t)block semaphore:(dispatch_semaphore_t)semaphore;
@end

@implementation OGDatabaseRuntimeTask

- (instancetype)initWithQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous mainThreadWaiter:(BOOL)mainThreadWaiter startupCritical:(BOOL)startupCritical block:(dispatch_block_t)block semaphore:(dispatch_semaphore_t)semaphore
{
    self = [super init];
    if (self != nil)
    {
        _queue = queue;
        _block = [block copy];
        _semaphore = semaphore;
        _synchronous = synchronous;
        _mainThreadWaiter = mainThreadWaiter;
        _startupCritical = startupCritical;
        _submittedAt = CACurrentMediaTime();
    }
    return self;
}

@end

@interface OGDatabaseRuntimeState : NSObject
{
    pthread_mutex_t _lock;
    NSMutableArray *_mainThreadTasks;
    NSMutableArray *_synchronousTasks;
    NSMutableArray *_startupCriticalTasks;
    NSMutableArray *_storageTasks;
    NSUInteger _startupCriticalCount;
    BOOL _running;
    BOOL _storageWakeScheduled;
    NSUInteger _priorityTaskBurst;
    CFAbsoluteTime _runningSubmittedAt;
    volatile int32_t _pendingPriorityTaskCount;
    pthread_t _runningThread;
    OGDatabaseRuntimeBoost _runningBoost;
    BOOL _runningThreadSchedulingSaved;
    int _runningThreadPolicy;
    struct sched_param _runningThreadParameters;
}
- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block;
- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block;
- (BOOL)priorityWorkPending;
- (void)beginStartupCritical;
- (void)endStartupCritical;
- (void)interactionStateChanged;
@end

@implementation OGDatabaseRuntimeState

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _mainThreadTasks = [[NSMutableArray alloc] init];
        _synchronousTasks = [[NSMutableArray alloc] init];
        _startupCriticalTasks = [[NSMutableArray alloc] init];
        _storageTasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (OGDatabaseRuntimeTask *)takeFirstTaskFromQueue:(NSMutableArray *)queue
{
    if (queue.count == 0)
        return nil;

    OGDatabaseRuntimeTask *task = [queue objectAtIndex:0];
    [queue removeObjectAtIndex:0];
    return task;
}

- (OGDatabaseRuntimeTask *)nextTaskLocked
{
    OGDatabaseRuntimeTask *task = [self takeFirstTaskFromQueue:_mainThreadTasks];
    if (task == nil && _priorityTaskBurst >= 8 && _startupCriticalCount == 0 && _startupCriticalTasks.count == 0 && _storageTasks.count != 0)
    {
        OGDatabaseRuntimeTask *oldest = _storageTasks[0];
        if (CACurrentMediaTime() - oldest->_submittedAt >= 2.0)
        {
            _priorityTaskBurst = 0;
            return [self takeFirstTaskFromQueue:_storageTasks];
        }
    }
    if (task == nil)
        task = [self takeFirstTaskFromQueue:_synchronousTasks];
    if (task == nil)
        task = [self takeFirstTaskFromQueue:_startupCriticalTasks];
    if (task != nil)
    {
        OSAtomicDecrement32Barrier(&_pendingPriorityTaskCount);
        _priorityTaskBurst++;
        return task;
    }

    if (OGRuntimeInteractionActiveFast() && _storageTasks.count != 0)
    {
        OGDatabaseRuntimeTask *oldest = _storageTasks[0];
        CFAbsoluteTime remaining = 1.0 - (CACurrentMediaTime() - oldest->_submittedAt);
        if (remaining > 0.0)
        {
            if (!_storageWakeScheduled)
            {
                _storageWakeScheduled = YES;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
                {
                    pthread_mutex_lock(&_lock);
                    _storageWakeScheduled = NO;
                    [self scheduleDrainLocked];
                    pthread_mutex_unlock(&_lock);
                });
            }
            return nil;
        }
    }
    _priorityTaskBurst = 0;
    return [self takeFirstTaskFromQueue:_storageTasks];
}

- (OGDatabaseRuntimeBoost)boostForTask:(OGDatabaseRuntimeTask *)task
{
    if (task->_mainThreadWaiter)
        return OGDatabaseRuntimeBoostMainWaiter;
    if (task->_synchronous || task->_startupCritical)
        return OGDatabaseRuntimeBoostWaiter;
    return OGDatabaseRuntimeBoostNone;
}

- (OGDatabaseRuntimeBoost)queuedWaiterBoostLocked
{
    if (_mainThreadTasks.count != 0)
        return OGDatabaseRuntimeBoostMainWaiter;
    if (_synchronousTasks.count != 0 || _startupCriticalTasks.count != 0)
        return OGDatabaseRuntimeBoostWaiter;
    return OGDatabaseRuntimeBoostNone;
}

- (void)boostRunningThreadLocked:(OGDatabaseRuntimeBoost)boost
{
    if (_runningThread == NULL || boost <= _runningBoost)
        return;
    if (!_runningThreadSchedulingSaved)
    {
        if (pthread_getschedparam(_runningThread, &_runningThreadPolicy, &_runningThreadParameters) != 0)
            return;
        _runningThreadSchedulingSaved = YES;
    }
    int priority = boost == OGDatabaseRuntimeBoostMainWaiter ? sched_get_priority_max(_runningThreadPolicy) - 1 : OGDatabaseRuntimeWaiterPriority;
    _runningBoost = boost;
    if (priority <= _runningThreadParameters.sched_priority)
        return;
    struct sched_param parameters = _runningThreadParameters;
    parameters.sched_priority = priority;
    pthread_setschedparam(_runningThread, _runningThreadPolicy, &parameters);
}

- (void)beginRunningTaskLocked:(OGDatabaseRuntimeTask *)task
{
    _runningThread = pthread_self();
    _runningBoost = OGDatabaseRuntimeBoostNone;
    _runningThreadSchedulingSaved = NO;
    OGDatabaseRuntimeBoost boost = [self boostForTask:task];
    OGDatabaseRuntimeBoost queuedBoost = [self queuedWaiterBoostLocked];
    [self boostRunningThreadLocked:queuedBoost > boost ? queuedBoost : boost];
}

- (void)endRunningTaskLocked
{
    if (_runningThreadSchedulingSaved && _runningBoost != OGDatabaseRuntimeBoostNone)
        pthread_setschedparam(_runningThread, _runningThreadPolicy, &_runningThreadParameters);
    _runningThread = NULL;
    _runningBoost = OGDatabaseRuntimeBoostNone;
    _runningThreadSchedulingSaved = NO;
}

- (void)scheduleDrainLocked
{
    if (_running)
        return;

    OGDatabaseRuntimeTask *task = [self nextTaskLocked];
    if (task == nil)
        return;

    _running = YES;
    _runningSubmittedAt = task->_submittedAt;

    dispatch_async(task->_queue, ^
    {
        pthread_mutex_lock(&_lock);
        [self beginRunningTaskLocked:task];
        pthread_mutex_unlock(&_lock);

        OGDatabaseRuntimeSetSynchronous(task->_synchronous || task->_startupCritical);

        @autoreleasepool
        {
            task->_block();
        }


        OGDatabaseRuntimeSetSynchronous(NO);

        if (task->_semaphore != NULL)
            dispatch_semaphore_signal(task->_semaphore);

        pthread_mutex_lock(&_lock);
        [self endRunningTaskLocked];
        _running = NO;
        if (_mainThreadTasks.count != 0 || _synchronousTasks.count != 0 || _startupCriticalTasks.count != 0)
        {
            [self scheduleDrainLocked];
        }
        else
        {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.002 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
            {
                pthread_mutex_lock(&_lock);
                [self scheduleDrainLocked];
                pthread_mutex_unlock(&_lock);
            });
        }
        pthread_mutex_unlock(&_lock);
    });
}

- (void)enqueueTaskLocked:(OGDatabaseRuntimeTask *)task
{
    if (task->_mainThreadWaiter)
        [_mainThreadTasks addObject:task];
    else if (task->_synchronous)
        [_synchronousTasks addObject:task];
    else if (task->_startupCritical)
        [_startupCriticalTasks addObject:task];
    else
        [_storageTasks addObject:task];

    if (task->_mainThreadWaiter || task->_synchronous || task->_startupCritical)
        OSAtomicIncrement32Barrier(&_pendingPriorityTaskCount);

    [self boostRunningThreadLocked:[self boostForTask:task]];
    [self scheduleDrainLocked];
}

- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    BOOL mainThreadWaiter = synchronous && [NSThread isMainThread];
    dispatch_semaphore_t semaphore = synchronous ? dispatch_semaphore_create(0) : NULL;
    pthread_mutex_lock(&_lock);
    BOOL startupCritical = _startupCriticalCount != 0;
    pthread_mutex_unlock(&_lock);
    OGDatabaseRuntimeTask *task = [[OGDatabaseRuntimeTask alloc] initWithQueue:queue synchronous:synchronous mainThreadWaiter:mainThreadWaiter startupCritical:startupCritical block:block semaphore:semaphore];

    if (synchronous)
    {
        pthread_mutex_lock(&_lock);
        [self enqueueTaskLocked:task];
        pthread_mutex_unlock(&_lock);

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(semaphore);
#endif
    }
    else
    {
        pthread_mutex_lock(&_lock);
        [self enqueueTaskLocked:task];
        pthread_mutex_unlock(&_lock);
    }
}

- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    OGDatabaseRuntimeTask *task = [[OGDatabaseRuntimeTask alloc] initWithQueue:queue synchronous:NO mainThreadWaiter:NO startupCritical:NO block:block semaphore:NULL];
    pthread_mutex_lock(&_lock);
    if (_runningSubmittedAt > 0.0)
        task->_submittedAt = MIN(task->_submittedAt, _runningSubmittedAt);
    [_storageTasks insertObject:task atIndex:0];
    [self scheduleDrainLocked];
    pthread_mutex_unlock(&_lock);
}

- (BOOL)priorityWorkPending
{
    return _pendingPriorityTaskCount > 0;
}

- (void)beginStartupCritical
{
    pthread_mutex_lock(&_lock);
    _startupCriticalCount++;
    pthread_mutex_unlock(&_lock);
}

- (void)endStartupCritical
{
    pthread_mutex_lock(&_lock);
    if (_startupCriticalCount != 0)
        _startupCriticalCount--;
    [self scheduleDrainLocked];
    pthread_mutex_unlock(&_lock);
}

- (void)interactionStateChanged
{
    pthread_mutex_lock(&_lock);
    [self scheduleDrainLocked];
    pthread_mutex_unlock(&_lock);
}

@end

@interface OGDatabaseMainPriorityTask : NSObject
{
@public
    dispatch_queue_t _queue;
    dispatch_block_t _block;
    dispatch_semaphore_t _semaphore;
    BOOL _mainAsync;
    BOOL _mainWaiter;
}
@end

@implementation OGDatabaseMainPriorityTask
@end

static const CFTimeInterval OGDatabaseMainPriorityDrainBudget = 0.008;

@interface OGDatabaseMainPriorityState : NSObject
{
    pthread_mutex_t _lock;
    NSMutableArray *_tasks;
    BOOL _running;
    volatile int32_t _pendingMainWaiterCount;
}
- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block;
- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block;
- (BOOL)priorityWorkPending;
@end

@implementation OGDatabaseMainPriorityState

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _tasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)drainOnQueue:(dispatch_queue_t)queue
{
    CFAbsoluteTime drainStart = CACurrentMediaTime();
    for (;;)
    {
        pthread_mutex_lock(&_lock);
        if (_tasks.count == 0)
        {
            _running = NO;
            pthread_mutex_unlock(&_lock);
            return;
        }

        OGDatabaseMainPriorityTask *task = [_tasks objectAtIndex:0];
        if (task->_queue != queue || (!task->_mainWaiter && CACurrentMediaTime() - drainStart >= OGDatabaseMainPriorityDrainBudget))
        {
            dispatch_queue_t nextQueue = task->_queue;
            pthread_mutex_unlock(&_lock);
            dispatch_async(nextQueue, ^
            {
                [self drainOnQueue:nextQueue];
            });
            return;
        }

        [_tasks removeObjectAtIndex:0];
        if (task->_mainWaiter)
            OSAtomicDecrement32Barrier(&_pendingMainWaiterCount);
        pthread_mutex_unlock(&_lock);

        @autoreleasepool
        {
            task->_block();
        }

        if (task->_semaphore != NULL)
            dispatch_semaphore_signal(task->_semaphore);
    }
}

- (void)dispatchQueue:(dispatch_queue_t)queue synchronous:(BOOL)synchronous block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    BOOL mainThread = [NSThread isMainThread];
    OGDatabaseMainPriorityTask *task = [[OGDatabaseMainPriorityTask alloc] init];
    task->_queue = queue;
    task->_block = [block copy];
    task->_semaphore = synchronous ? dispatch_semaphore_create(0) : NULL;
    task->_mainAsync = mainThread && !synchronous;
    task->_mainWaiter = mainThread && synchronous;
    dispatch_semaphore_t semaphore = task->_semaphore;

    BOOL startDrain = NO;
    pthread_mutex_lock(&_lock);
    if (task->_mainWaiter)
    {
        NSUInteger insertIndex = 0;
        for (NSUInteger index = _tasks.count; index > 0; index--)
        {
            if (((OGDatabaseMainPriorityTask *)[_tasks objectAtIndex:index - 1])->_mainAsync)
            {
                insertIndex = index;
                break;
            }
        }
        [_tasks insertObject:task atIndex:insertIndex];
        OSAtomicIncrement32Barrier(&_pendingMainWaiterCount);
    }
    else
    {
        [_tasks addObject:task];
    }
    if (!_running)
    {
        _running = YES;
        startDrain = YES;
    }
    pthread_mutex_unlock(&_lock);
    task = nil;

    if (startDrain)
    {
        dispatch_async(queue, ^
        {
            [self drainOnQueue:queue];
        });
    }

    if (semaphore != NULL)
    {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(semaphore);
#endif
    }
}

- (void)dispatchContinuationOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    if (queue == NULL || block == nil)
        return;

    OGDatabaseMainPriorityTask *task = [[OGDatabaseMainPriorityTask alloc] init];
    task->_queue = queue;
    task->_block = [block copy];

    BOOL startDrain = NO;
    pthread_mutex_lock(&_lock);
    NSUInteger insertIndex = 0;
    NSUInteger count = _tasks.count;
    while (insertIndex < count)
    {
        OGDatabaseMainPriorityTask *queuedTask = [_tasks objectAtIndex:insertIndex];
        if (!queuedTask->_mainWaiter && !queuedTask->_mainAsync)
            break;
        insertIndex++;
    }
    [_tasks insertObject:task atIndex:insertIndex];
    if (!_running)
    {
        _running = YES;
        startDrain = YES;
    }
    pthread_mutex_unlock(&_lock);

    if (startDrain)
    {
        dispatch_async(queue, ^
        {
            [self drainOnQueue:queue];
        });
    }
}

- (BOOL)priorityWorkPending
{
    return _pendingMainWaiterCount > 0;
}

@end

static BOOL OGDatabaseRuntimeUsesMainPriority(void)
{
    static BOOL value = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = !OGDatabaseRuntimeIsConstrained() && OGRuntimeSingleCoreDevice();
    });
    return value;
}

static OGDatabaseMainPriorityState *OGDatabaseRuntimeMainPriorityState(void)
{
    static OGDatabaseMainPriorityState *state = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        state = [[OGDatabaseMainPriorityState alloc] init];
    });
    return state;
}

static OGDatabaseRuntimeState *OGDatabaseRuntimeSharedState(void)
{
    static OGDatabaseRuntimeState *state = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        state = [[OGDatabaseRuntimeState alloc] init];
    });
    return state;
}

void OGDatabaseRuntimeDispatch(dispatch_queue_t queue, BOOL synchronous, dispatch_block_t block)
{
    if (block == nil)
        return;

    if (!OGDatabaseRuntimeIsConstrained())
    {
        if (OGDatabaseRuntimeUsesMainPriority())
            [OGDatabaseRuntimeMainPriorityState() dispatchQueue:queue synchronous:synchronous block:block];
        else if (synchronous)
            dispatch_sync(queue, block);
        else
            dispatch_async(queue, block);
        return;
    }

    [OGDatabaseRuntimeSharedState() dispatchQueue:queue synchronous:synchronous block:block];
}

BOOL OGDatabaseRuntimePriorityWorkPending(void)
{
    if (OGDatabaseRuntimeIsConstrained())
        return [OGDatabaseRuntimeSharedState() priorityWorkPending];
    if (OGDatabaseRuntimeUsesMainPriority())
        return [OGDatabaseRuntimeMainPriorityState() priorityWorkPending];
    return NO;
}

void OGDatabaseRuntimeDispatchContinuation(dispatch_queue_t queue, dispatch_block_t block)
{
    if (block == nil)
        return;

    if (OGDatabaseRuntimeIsConstrained())
        [OGDatabaseRuntimeSharedState() dispatchContinuationOnQueue:queue block:block];
    else if (OGDatabaseRuntimeUsesMainPriority())
        [OGDatabaseRuntimeMainPriorityState() dispatchContinuationOnQueue:queue block:block];
    else
        dispatch_async(queue, block);
}

void OGDatabaseRuntimeBeginStartupCritical(void)
{
    if (!OGDatabaseRuntimeIsConstrained())
        return;
    [OGDatabaseRuntimeSharedState() beginStartupCritical];
}

void OGDatabaseRuntimeEndStartupCritical(void)
{
    if (!OGDatabaseRuntimeIsConstrained())
        return;
    [OGDatabaseRuntimeSharedState() endStartupCritical];
}

void OGDatabaseRuntimeInteractionStateChanged(void)
{
    if (!OGDatabaseRuntimeIsConstrained())
        return;

    [OGDatabaseRuntimeSharedState() interactionStateChanged];
}

void OGDatabaseRuntimeCooperateDuringInteraction(void)
{
    if (!OGDatabaseRuntimeIsConstrained())
        return;
    if (!OGRuntimeInteractionActiveFast())
        return;
    if (OGDatabaseRuntimeCurrentTaskIsSynchronous() || [OGDatabaseRuntimeSharedState() priorityWorkPending])
        return;

    OGRuntimeCooperateWithInteraction();
}

static int OGDatabaseRuntimeProgressHandler(void *context)
{
    (void)context;

    if (!OGDatabaseRuntimeIsConstrained())
        return 0;

    OGRuntimeLatencyYield();

    if (!OGRuntimeInteractionActiveFast())
        return 0;

    if (!OGDatabaseRuntimeCurrentTaskIsSynchronous() && ![OGDatabaseRuntimeSharedState() priorityWorkPending])
        OGRuntimeCooperateWithInteraction();

    return 0;
}

void OGDatabaseRuntimeConfigureSQLite(struct sqlite3 *database)
{
    if (database == NULL || !OGDatabaseRuntimeIsConstrained())
        return;

    sqlite3_progress_handler(database, 512, OGDatabaseRuntimeProgressHandler, NULL);
}
