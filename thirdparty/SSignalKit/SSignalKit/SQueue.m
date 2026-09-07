#import "SQueue.h"
#import <sys/utsname.h>

static const void *SQueueSpecificKey = &SQueueSpecificKey;

extern CFAbsoluteTime mainLaunchTimestamp;

static double SQueueStartupTime()
{
    if (mainLaunchTimestamp <= 0.0)
        return 0.0;
    
    return CFAbsoluteTimeGetCurrent() - mainLaunchTimestamp;
}

static NSString *SQueueIOS6PerfBuildTag()
{
    static NSString *tag = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?";
                      NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"?";
                      
                      struct utsname systemInfo;
                      uname(&systemInfo);
                      
                      NSString *machine = [[NSString alloc] initWithUTF8String:systemInfo.machine] ?: @"?";
                      
                      tag = [[NSString alloc] initWithFormat:@"version=%@ build=%@ device=%@", version, build, machine];
                  });
    
    return tag;
}

static void SQueueIOS6PerfMaybeLog(NSString *queueName,
                                   id queue,
                                   bool synchronous,
                                   CFAbsoluteTime waitMs,
                                   CFAbsoluteTime execMs)
{
    (void)queueName;
    (void)queue;
    (void)synchronous;
    (void)waitMs;
    (void)execMs;
}

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
    
    if (_queueSpecific != NULL &&
        dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
    {
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
        
        block();
        
        CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
        
        SQueueIOS6PerfMaybeLog(
                               @"current",
                               self,
                               false,
                               0.0,
                               (finishedAt - startedAt) * 1000.0
                               );
    }
    else if (_specialIsMainQueue && [NSThread isMainThread])
    {
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
        
        block();
        
        CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
        
        SQueueIOS6PerfMaybeLog(
                               @"main-inline",
                               self,
                               false,
                               0.0,
                               (finishedAt - startedAt) * 1000.0
                               );
    }
    else
    {
        CFAbsoluteTime queuedAt = CFAbsoluteTimeGetCurrent();
        
        dispatch_async((dispatch_queue_t)_queue, ^
                       {
                           CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
                           
                           block();
                           
                           CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
                           
                           SQueueIOS6PerfMaybeLog(
                                                  _specialIsMainQueue
                                                  ? @"main"
                                                  : (_queueSpecific == NULL ? @"concurrent" : @"serial"),
                                                  self,
                                                  false,
                                                  (startedAt - queuedAt) * 1000.0,
                                                  (finishedAt - startedAt) * 1000.0
                                                  );
                       });
    }
}

- (void)dispatchSync:(dispatch_block_t)block
{
    if (block == nil)
        return;
    
    if (_queueSpecific != NULL &&
        dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
    {
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
        
        block();
        
        CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
        
        SQueueIOS6PerfMaybeLog(
                               @"current",
                               self,
                               true,
                               0.0,
                               (finishedAt - startedAt) * 1000.0
                               );
    }
    else if (_specialIsMainQueue && [NSThread isMainThread])
    {
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
        
        block();
        
        CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
        
        SQueueIOS6PerfMaybeLog(
                               @"main-inline",
                               self,
                               true,
                               0.0,
                               (finishedAt - startedAt) * 1000.0
                               );
    }
    else
    {
        CFAbsoluteTime queuedAt = CFAbsoluteTimeGetCurrent();
        
        dispatch_sync((dispatch_queue_t)_queue, ^
                      {
                          CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
                          
                          block();
                          
                          CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
                          
                          SQueueIOS6PerfMaybeLog(
                                                 _specialIsMainQueue
                                                 ? @"main"
                                                 : (_queueSpecific == NULL ? @"concurrent" : @"serial"),
                                                 self,
                                                 true,
                                                 (startedAt - queuedAt) * 1000.0,
                                                 (finishedAt - startedAt) * 1000.0
                                                 );
                      });
    }
}

- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous
{
    if (block == nil)
        return;
    
    if (_queueSpecific != NULL &&
        dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
    {
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
        
        block();
        
        CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
        
        SQueueIOS6PerfMaybeLog(
                               @"current",
                               self,
                               synchronous,
                               0.0,
                               (finishedAt - startedAt) * 1000.0
                               );
    }
    else if (_specialIsMainQueue && [NSThread isMainThread])
    {
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
        
        block();
        
        CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
        
        SQueueIOS6PerfMaybeLog(
                               @"main-inline",
                               self,
                               synchronous,
                               0.0,
                               (finishedAt - startedAt) * 1000.0
                               );
    }
    else
    {
        CFAbsoluteTime queuedAt = CFAbsoluteTimeGetCurrent();
        
        if (synchronous)
        {
            dispatch_sync((dispatch_queue_t)_queue, ^
                          {
                              CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
                              
                              block();
                              
                              CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
                              
                              SQueueIOS6PerfMaybeLog(
                                                     _specialIsMainQueue
                                                     ? @"main"
                                                     : (_queueSpecific == NULL ? @"concurrent" : @"serial"),
                                                     self,
                                                     true,
                                                     (startedAt - queuedAt) * 1000.0,
                                                     (finishedAt - startedAt) * 1000.0
                                                     );
                          });
        }
        else
        {
            dispatch_async((dispatch_queue_t)_queue, ^
                           {
                               CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
                               
                               block();
                               
                               CFAbsoluteTime finishedAt = CFAbsoluteTimeGetCurrent();
                               
                               SQueueIOS6PerfMaybeLog(
                                                      _specialIsMainQueue
                                                      ? @"main"
                                                      : (_queueSpecific == NULL ? @"concurrent" : @"serial"),
                                                      self,
                                                      false,
                                                      (startedAt - queuedAt) * 1000.0,
                                                      (finishedAt - startedAt) * 1000.0
                                                      );
                           });
        }
    }
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