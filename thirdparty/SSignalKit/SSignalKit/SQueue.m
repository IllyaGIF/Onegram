#import "SQueue.h"

static const void *SQueueSpecificKey = &SQueueSpecificKey;

@interface SQueue ()
{
    void *_queue;
    void *_queueSpecific;
    bool _specialIsMainQueue;
    bool _ownsQueue;
}

@end

@implementation SQueue

+ (SQueue *)mainQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_main_queue() queueSpecific:NULL];
                      queue->_specialIsMainQueue = true;
                  });
    
    return queue;
}

+ (SQueue *)concurrentDefaultQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) queueSpecific:NULL];
                  });
    
    return queue;
}

+ (SQueue *)concurrentBackgroundQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) queueSpecific:NULL];
                  });
    
    return queue;
}

+ (SQueue *)wrapConcurrentNativeQueue:(dispatch_queue_t)nativeQueue
{
    return [[SQueue alloc] initWithNativeQueue:nativeQueue queueSpecific:NULL];
}

- (instancetype)init
{
    dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
    
    dispatch_queue_set_specific(
                                queue,
                                SQueueSpecificKey,
                                (__bridge void *)self,
                                NULL
                                );
    
    self = [self initWithNativeQueue:queue queueSpecific:(__bridge void *)self];
    
    if (self != nil)
        _ownsQueue = true;
    
    return self;
}

- (instancetype)initWithNativeQueue:(dispatch_queue_t)queue queueSpecific:(void *)queueSpecific
{
    self = [super init];
    
    if (self != nil)
    {
        _queue = (void *)queue;
        _queueSpecific = queueSpecific;
        _ownsQueue = false;
    }
    
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    if (_ownsQueue && _queue != NULL)
    {
        dispatch_release((dispatch_queue_t)_queue);
        _queue = NULL;
    }
#endif
}

- (void *)_dispatch_queueRaw
{
    return _queue;
}

- (void)dispatch:(dispatch_block_t)block
{
    if (block == nil)
        return;
    
    if (_queueSpecific != NULL && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
        block();
    else if (_specialIsMainQueue && [NSThread isMainThread])
        block();
    else
        dispatch_async((dispatch_queue_t)_queue, block);
}

- (void)dispatchSync:(dispatch_block_t)block
{
    if (block == nil)
        return;
    
    if (_queueSpecific != NULL && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
        block();
    else if (_specialIsMainQueue && [NSThread isMainThread])
        block();
    else
        dispatch_sync((dispatch_queue_t)_queue, block);
}

- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous
{
    if (block == nil)
        return;
    
    if (_queueSpecific != NULL && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
        block();
    else if (_specialIsMainQueue && [NSThread isMainThread])
        block();
    else if (synchronous)
        dispatch_sync((dispatch_queue_t)_queue, block);
    else
        dispatch_async((dispatch_queue_t)_queue, block);
}

- (bool)isCurrentQueue
{
    if (_queueSpecific != NULL &&
        dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
    {
        return true;
    }
    
    if (_specialIsMainQueue && [NSThread isMainThread])
        return true;
    
    return false;
}

@end