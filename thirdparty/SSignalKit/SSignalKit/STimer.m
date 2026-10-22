#import "STimer.h"

#import <pthread.h>

#import "SQueue.h"

@interface STimer ()
{
    pthread_mutex_t _lock;
    dispatch_source_t _timer;
    NSTimeInterval _timeout;
    NSTimeInterval _timeoutDate;
    bool _repeat;
    dispatch_block_t _completion;
    dispatch_queue_t _nativeQueue;
}

@end

@implementation STimer

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion queue:(SQueue *)queue
{
    dispatch_queue_t nativeQueue = (dispatch_queue_t)[queue _dispatch_queueRaw];
    
    return [self initWithTimeout:timeout
                          repeat:repeat
                      completion:completion
                     nativeQueue:nativeQueue];
}

- (id)initWithTimeout:(NSTimeInterval)timeout repeat:(bool)repeat completion:(dispatch_block_t)completion nativeQueue:(dispatch_queue_t)nativeQueue
{
    self = [super init];
    
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _timer = NULL;
        _timeoutDate = INT_MAX;
        _timeout = timeout;
        _repeat = repeat;
        _completion = [completion copy];
        _nativeQueue = nativeQueue;
        
        if (_nativeQueue != NULL)
            dispatch_retain(_nativeQueue);
    }
    
    return self;
}

- (void)dealloc
{
    [self _cancelTimer:[self _takeTimer]];
    
    if (_nativeQueue != NULL)
    {
        dispatch_release(_nativeQueue);
        _nativeQueue = NULL;
    }
    
    [_completion release];
    _completion = nil;
    
    pthread_mutex_destroy(&_lock);
    
    [super dealloc];
}

- (dispatch_source_t)_takeTimer
{
    pthread_mutex_lock(&_lock);
    dispatch_source_t timer = _timer;
    _timer = NULL;
    pthread_mutex_unlock(&_lock);
    return timer;
}

- (void)_cancelTimer:(dispatch_source_t)timer
{
    if (timer == NULL)
        return;
    dispatch_source_cancel(timer);
    dispatch_release(timer);
}

- (void)start
{
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _nativeQueue);
    if (timer != NULL)
    {
        uint64_t interval = _repeat ? (uint64_t)(_timeout * NSEC_PER_SEC) : DISPATCH_TIME_FOREVER;
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_timeout * NSEC_PER_SEC)), interval, 0);
        
        STimer *blockSelf = self;
        dispatch_source_set_event_handler(timer, ^
        {
            if (blockSelf->_completion != nil)
                blockSelf->_completion();
            
            if (!blockSelf->_repeat)
                [blockSelf _invalidateTimer:timer];
        });
    }
    
    pthread_mutex_lock(&_lock);
    dispatch_source_t previousTimer = _timer;
    _timer = timer;
    _timeoutDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + _timeout;
    pthread_mutex_unlock(&_lock);
    
    [self _cancelTimer:previousTimer];
    
    if (timer != NULL)
        dispatch_resume(timer);
}

- (void)_invalidateTimer:(dispatch_source_t)timer
{
    pthread_mutex_lock(&_lock);
    bool current = _timer == timer;
    if (current)
    {
        _timer = NULL;
        _timeoutDate = 0;
    }
    pthread_mutex_unlock(&_lock);
    
    if (current)
        [self _cancelTimer:timer];
}

- (void)fireAndInvalidate
{
    if (_completion != nil)
        _completion();
    
    [self invalidate];
}

- (void)invalidate
{
    pthread_mutex_lock(&_lock);
    dispatch_source_t timer = _timer;
    _timer = NULL;
    _timeoutDate = 0;
    pthread_mutex_unlock(&_lock);
    
    [self _cancelTimer:timer];
}

@end
