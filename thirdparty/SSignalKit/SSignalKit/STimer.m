#import "STimer.h"

#import "SQueue.h"

@interface STimer ()
{
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
    if (_timer != NULL)
    {
        dispatch_source_cancel(_timer);
        dispatch_release(_timer);
        _timer = NULL;
    }
    
    if (_nativeQueue != NULL)
    {
        dispatch_release(_nativeQueue);
        _nativeQueue = NULL;
    }
    
    [_completion release];
    _completion = nil;
    
    [super dealloc];
}

- (void)start
{
    if (_timer != NULL)
    {
        dispatch_source_cancel(_timer);
        dispatch_release(_timer);
        _timer = NULL;
    }
    
    _timeoutDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + _timeout;
    
    _timer = dispatch_source_create(
                                    DISPATCH_SOURCE_TYPE_TIMER,
                                    0,
                                    0,
                                    _nativeQueue
                                    );
    
    if (_timer == NULL)
        return;
    
    uint64_t interval = _repeat
    ? (uint64_t)(_timeout * NSEC_PER_SEC)
    : DISPATCH_TIME_FOREVER;
    
    dispatch_source_set_timer(
                              _timer,
                              dispatch_time(
                                            DISPATCH_TIME_NOW,
                                            (int64_t)(_timeout * NSEC_PER_SEC)
                                            ),
                              interval,
                              0
                              );
    
    STimer *blockSelf = self;
    
    dispatch_source_set_event_handler(_timer, ^
                                      {
                                          STimer *strongSelf = blockSelf;
                                          
                                          if (strongSelf == nil)
                                              return;
                                          
                                          if (strongSelf->_completion != nil)
                                              strongSelf->_completion();
                                          
                                          if (!strongSelf->_repeat)
                                              [strongSelf invalidate];
                                      });
    
    dispatch_resume(_timer);
}

- (void)fireAndInvalidate
{
    if (_completion != nil)
        _completion();
    
    [self invalidate];
}

- (void)invalidate
{
    _timeoutDate = 0;
    
    if (_timer != NULL)
    {
        dispatch_source_cancel(_timer);
        dispatch_release(_timer);
        _timer = NULL;
    }
}

@end