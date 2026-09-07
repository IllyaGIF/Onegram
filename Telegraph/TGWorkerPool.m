#import "TGWorkerPool.h"

#import "TGWorker.h"
#import "TGWorkerTask.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@interface TGWorkerPool ()
{
    NSMutableArray *_taskList;
    TG_SYNCHRONIZED_DEFINE(_taskList);
}

@end

@implementation TGWorkerPool

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _taskList = [[NSMutableArray alloc] init];
        TG_SYNCHRONIZED_INIT(_taskList);
    }
    return self;
}

+ (ASQueue *)processingQueue
{
    static ASQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ASQueue alloc] initWithName:"org.telegram.workerPoolQueue"];
    });
    return queue;
}

- (void)addTask:(TGWorkerTask *)task
{
    TG_SYNCHRONIZED_BEGIN(_taskList);
    if (![_taskList containsObject:task])
        [_taskList addObject:task];
    TG_SYNCHRONIZED_END(_taskList);
    
    TGWorkerTask *queuedTask = task;
    
    [[TGWorkerPool processingQueue] dispatchOnQueue:^
    {
        bool executeTask = false;
        TG_SYNCHRONIZED_BEGIN(_taskList);
        if ([_taskList containsObject:queuedTask])
        {
            executeTask = true;
            [_taskList removeObject:queuedTask];
        }
        TG_SYNCHRONIZED_END(_taskList);
        
        if (executeTask)
            [queuedTask execute];
    }];
}

- (void)removeTask:(TGWorkerTask *)task
{
    TG_SYNCHRONIZED_BEGIN(_taskList);
    [_taskList removeObject:task];
    TG_SYNCHRONIZED_END(_taskList);
}

@end
