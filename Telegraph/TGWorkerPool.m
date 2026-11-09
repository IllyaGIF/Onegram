#import "TGWorkerPool.h"

#import "TGWorkerTask.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@interface TGWorkerPool ()
{
    NSMutableDictionary *_queuedOperations;
    TG_SYNCHRONIZED_DEFINE(_queuedOperations);
}

- (void)executeTask:(TGWorkerTask *)task;

@end

@implementation TGWorkerPool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _queuedOperations = [[NSMutableDictionary alloc] init];
        TG_SYNCHRONIZED_INIT(_queuedOperations);
    }
    return self;
}

+ (NSOperationQueue *)processingQueue
{
    static NSOperationQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:2];
    });
    return queue;
}

- (void)addTask:(TGWorkerTask *)task
{
    if (task == nil)
        return;

    NSValue *key = [NSValue valueWithNonretainedObject:task];
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(executeTask:) object:task];
    [operation setQueuePriority:task.queuePriority];
    bool shouldSchedule = false;
    TG_SYNCHRONIZED_BEGIN(_queuedOperations);
    if ([_queuedOperations objectForKey:key] == nil)
    {
        [_queuedOperations setObject:operation forKey:key];
        shouldSchedule = true;
    }
    TG_SYNCHRONIZED_END(_queuedOperations);

    if (shouldSchedule)
        [[TGWorkerPool processingQueue] addOperation:operation];
}

- (void)executeTask:(TGWorkerTask *)task
{
    NSValue *key = [NSValue valueWithNonretainedObject:task];
    bool shouldExecute = false;
    TG_SYNCHRONIZED_BEGIN(_queuedOperations);
    NSOperation *operation = [_queuedOperations objectForKey:key];
    if (operation != nil)
    {
        shouldExecute = ![operation isCancelled];
        [_queuedOperations removeObjectForKey:key];
    }
    TG_SYNCHRONIZED_END(_queuedOperations);

    if (shouldExecute)
        [task execute];
}

- (void)removeTask:(TGWorkerTask *)task
{
    if (task == nil)
        return;

    NSValue *key = [NSValue valueWithNonretainedObject:task];
    TG_SYNCHRONIZED_BEGIN(_queuedOperations);
    NSOperation *operation = [_queuedOperations objectForKey:key];
    [_queuedOperations removeObjectForKey:key];
    TG_SYNCHRONIZED_END(_queuedOperations);

    [operation cancel];
}

@end
