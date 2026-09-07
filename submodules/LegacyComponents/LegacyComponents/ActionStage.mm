#import "ActionStage.h"

#import "SSignalKitCompat/SSignalKit.h"

#import "LegacyComponentsInternal.h"

#import "ASActor.h"

#import <libkern/OSAtomic.h>

#include <vector>

static const char *graphQueueSpecific = "com.telegraph.graphdispatchqueue";

#define IOS6_ACTIONSTAGE_PERF_LOG(...) do { } while (0)

extern CFAbsoluteTime mainLaunchTimestamp;

static double ActionStageStartupTime()
{
    if (mainLaunchTimestamp <= 0.0)
        return 0.0;
    
    return CFAbsoluteTimeGetCurrent() - mainLaunchTimestamp;
}

static dispatch_queue_t mainGraphQueue = nil;
static dispatch_queue_t globalGraphQueue = nil;
static dispatch_queue_t highPriorityGraphQueue = nil;

static volatile OSSpinLock removeWatcherRequestsLock = OS_SPINLOCK_INIT;
static volatile OSSpinLock removeWatcherFromPathRequestsLock = OS_SPINLOCK_INIT;

@interface ActionStage ()
{
    std::vector<std::pair<ASHandle *, NSString *> > _removeWatcherFromPathRequests;
    std::vector<ASHandle *> _removeWatcherRequests;
}

@property (nonatomic, strong) NSMutableDictionary *requestQueues;

@property (nonatomic, strong) NSMutableDictionary *activeRequests;
@property (nonatomic, strong) NSMutableDictionary *cancelRequestTimers;

@property (nonatomic, strong) NSMutableDictionary *liveNodeWatchers;
@property (nonatomic, strong) NSMutableDictionary *actorMessagesWatchers;

@end

ActionStage *ActionStageInstance()
{
    static ActionStage *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
                      singleton = [[ActionStage alloc] init];
                  });
    
    return singleton;
}

@implementation ActionStage

#pragma mark - Singleton

#pragma mark - Implemetation

@synthesize requestQueues = _requestQueues;

@synthesize activeRequests = _activeRequests;
@synthesize cancelRequestTimers = _cancelRequestTimers;

@synthesize liveNodeWatchers = _liveNodeWatchers;
@synthesize actorMessagesWatchers = _actorMessagesWatchers;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _requestQueues = [[NSMutableDictionary alloc] init];
        
        _activeRequests = [[NSMutableDictionary alloc] init];
        _cancelRequestTimers = [[NSMutableDictionary alloc] init];
        
        _liveNodeWatchers = [[NSMutableDictionary alloc] init];
        _actorMessagesWatchers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (dispatch_queue_t)globalStageDispatchQueue
{
    if (mainGraphQueue == NULL)
    {
        mainGraphQueue = dispatch_queue_create("com.telegraph.graphdispatchqueue", 0);
        
        globalGraphQueue = dispatch_queue_create("com.telegraph.graphdispatchqueue-global", 0);
        dispatch_set_target_queue(globalGraphQueue, mainGraphQueue);
        
        highPriorityGraphQueue = dispatch_queue_create("com.telegraph.graphdispatchqueue-high", 0);
        dispatch_set_target_queue(highPriorityGraphQueue, mainGraphQueue);
        
        dispatch_queue_set_specific(mainGraphQueue, graphQueueSpecific, (void *)graphQueueSpecific, NULL);
        dispatch_queue_set_specific(globalGraphQueue, graphQueueSpecific, (void *)graphQueueSpecific, NULL);
        dispatch_queue_set_specific(highPriorityGraphQueue, graphQueueSpecific, (void *)graphQueueSpecific, NULL);
    }
    return globalGraphQueue;
}

- (bool)isCurrentQueueStageQueue
{
    return dispatch_get_specific(graphQueueSpecific) != NULL;
}

#ifdef DEBUG
- (void)dispatchOnStageQueueDebug:(const char *)function line:(int)line block:(dispatch_block_t)block
#else
- (void)dispatchOnStageQueue:(dispatch_block_t)block
#endif
{
    bool isGraphQueue = dispatch_get_specific(graphQueueSpecific) != NULL;
    
    if (isGraphQueue)
    {
#ifdef DEBUG
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
#endif
        
        block();
        
#ifdef DEBUG
        double execMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0;
        
        if (execMs >= 50.0)
        {
            IOS6_ACTIONSTAGE_PERF_LOG(@"STAGEEXEC t=%.3f INLINE caller=%s:%d exec=%.1fms",
                  ActionStageStartupTime(),
                  function,
                  line,
                  execMs);
        }
#endif
    }
    else
    {
#ifdef DEBUG
        CFAbsoluteTime queuedAt = CFAbsoluteTimeGetCurrent();
        
        dispatch_async([self globalStageDispatchQueue], ^
                       {
                           CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
                           double waitMs = (startedAt - queuedAt) * 1000.0;
                           
                           block();
                           
                           double execMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0;
                           
                           if (waitMs >= 100.0 || execMs >= 50.0)
                           {
                               IOS6_ACTIONSTAGE_PERF_LOG(@"STAGEEXEC t=%.3f NORMAL caller=%s:%d wait=%.1fms exec=%.1fms",
                                     ActionStageStartupTime(),
                                     function,
                                     line,
                                     waitMs,
                                     execMs);
                           }
                       });
#else
        dispatch_async([self globalStageDispatchQueue], block);
#endif
    }
}

- (void)dispatchOnHighPriorityQueue:(dispatch_block_t)block
{
    if ([self isCurrentQueueStageQueue])
    {
#ifdef DEBUG
        CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
#endif
        
        block();
        
#ifdef DEBUG
        double execMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0;
        
        if (execMs >= 50.0)
        {
            IOS6_ACTIONSTAGE_PERF_LOG(@"STAGEEXEC t=%.3f HIGH INLINE exec=%.1fms",
                  ActionStageStartupTime(),
                  execMs);
        }
#endif
    }
    else
    {
        if (highPriorityGraphQueue == NULL)
            [self globalStageDispatchQueue];
        
#ifdef DEBUG
        CFAbsoluteTime queuedAt = CFAbsoluteTimeGetCurrent();
        
        dispatch_async(highPriorityGraphQueue, ^
                       {
                           CFAbsoluteTime startedAt = CFAbsoluteTimeGetCurrent();
                           double waitMs = (startedAt - queuedAt) * 1000.0;
                           
                           block();
                           
                           double execMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1000.0;
                           
                           if (waitMs >= 100.0 || execMs >= 50.0)
                           {
                               IOS6_ACTIONSTAGE_PERF_LOG(@"STAGEEXEC t=%.3f HIGH wait=%.1fms exec=%.1fms",
                                     ActionStageStartupTime(),
                                     waitMs,
                                     execMs);
                           }
                       });
#else
        dispatch_async(highPriorityGraphQueue, block);
#endif
    }
}

- (void)dumpGraphState
{
    [self dispatchOnStageQueue:^
     {
         TGLegacyLog(@"%d live node watchers", _liveNodeWatchers.count);
         [_liveNodeWatchers enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSArray *watchers, __unused BOOL *stop)
          {
              TGLegacyLog(@"    %@", path);
              for (ASHandle *handle in watchers)
              {
                  if ([handle hasDelegate])
                      TGLegacyLog(@"        %@", handle);
              }
          }];
         TGLegacyLog(@"%d requests", _activeRequests.count);
         [_activeRequests enumerateKeysAndObjectsUsingBlock:^(NSString *path, __unused id obj, BOOL *stop)
          {
              TGLegacyLog(@"        %@", path);
          }];
     }];
}

- (NSFileManager *)globalFileManager
{
    static NSFileManager *fileManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
                      fileManager = [[NSFileManager alloc] init];
                  });
    
    return fileManager;
}

- (NSString *)optionsHash:(NSDictionary *)options
{
    if (options.count == 0)
        return @"";
    
    NSMutableString *string = [[NSMutableString alloc] initWithString:@"#"];
    
    Class StringClass = [NSString class];
    NSArray *keys = [[options allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
                     {
                         if ([obj1 isKindOfClass:StringClass] && [obj2 isKindOfClass:StringClass])
                         {
                             return [(NSString *)obj1 compare:(NSString *)obj2];
                         }
                         else
                             return NSOrderedSame;
                     }];
    
    bool first = true;
    for (NSString *key in keys)
    {
        if (![key isKindOfClass:StringClass])
        {
            TGLegacyLog(@"Warning: optionsHash: key is not a string");
            continue;
        }
        
        if (first)
        {
            [string appendString:@","];
            first = false;
        }
        
        NSObject *value = [options objectForKey:key];
        if ([value respondsToSelector:@selector(stringValue)])
            [string appendFormat:@"%@=%@", key, value];
    }
    
    return string;
}

- (NSString *)genericStringForParametrizedPath:(NSString *)path
{
    if (path == nil)
        return @"";
    
    int length = (int)path.length;
    unichar newPath[path.length];
    int newLength = 0;
    
    SEL sel = @selector(characterAtIndex:);
    unichar (*characterAtIndexImp)(id, SEL, NSUInteger) = (unichar (*)(id, SEL, NSUInteger))[path methodForSelector:sel];
    
    bool skipCharacters = false;
    bool skippedCharacters = false;
    
    for (int i = 0; i < length; i++)
    {
        unichar c = characterAtIndexImp(path, sel, i);
        if (c == '(')
        {
            skipCharacters = true;
            skippedCharacters = true;
            newPath[newLength++] = '@';
        }
        else if (c == ')')
        {
            skipCharacters = false;
        }
        else if (!skipCharacters)
        {
            newPath[newLength++] = c;
        }
    }
    
    if (!skippedCharacters)
        return path;
    
    NSString *genericPath = [[NSString alloc] initWithCharacters:newPath length:newLength];
    return genericPath;
}

- (void)_requestGeneric:(bool)joinOnly inCurrentQueue:(bool)inCurrentQueue path:(NSString *)path options:(NSDictionary *)options flags:(int)flags watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    
    dispatch_block_t requestBlock = ^
    {
        CFAbsoluteTime actorRequestStart = CFAbsoluteTimeGetCurrent();
        
        if (![actionHandle hasDelegate])
        {
            TGLegacyLog(@"Error: %s:%d: actionHandle.delegate is nil", __PRETTY_FUNCTION__, __LINE__);
            return;
        }
        
        NSMutableDictionary *activeRequests = _activeRequests;
        NSMutableDictionary *cancelTimers = _cancelRequestTimers;
        
        NSString *genericPath = [self genericStringForParametrizedPath:path];
        
        NSMutableDictionary *requestInfo = nil;
        
        NSMutableDictionary *cancelRequestInfo = [cancelTimers objectForKey:path];
        if (cancelRequestInfo != nil)
        {
            STimer *timer = [cancelRequestInfo objectForKey:@"timer"];
            [timer invalidate];
            timer = nil;
            requestInfo = [cancelRequestInfo objectForKey:@"requestInfo"];
            [activeRequests setObject:requestInfo forKey:path];
            [cancelTimers removeObjectForKey:path];
            TGLegacyLog(@"Resuming request to \"%@\"", path);
        }
        
        if (requestInfo == nil)
            requestInfo = [activeRequests objectForKey:path];
        
        if (joinOnly && requestInfo == nil)
            return;
        
        if (requestInfo == nil)
        {
            ASActor *requestBuilder = [ASActor requestBuilderForGenericPath:genericPath path:path];
            
            if (requestBuilder != nil)
            {
                NSMutableArray *watchers = [[NSMutableArray alloc] initWithObjects:actionHandle, nil];
                
                requestInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                               requestBuilder, @"requestBuilder",
                               watchers, @"watchers",
                               nil];
                
                [activeRequests setObject:requestInfo forKey:path];
                
                CFAbsoluteTime prepareStart = CFAbsoluteTimeGetCurrent();
                
                [requestBuilder prepare:options];
                
                double prepareMs = (CFAbsoluteTimeGetCurrent() - prepareStart) * 1000.0;
                
                if (prepareMs >= 20.0)
                {
                    IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORPREP t=%.3f path=%@ class=%@ ms=%.1f",
                          ActionStageStartupTime(),
                          path,
                          NSStringFromClass([requestBuilder class]),
                          prepareMs);
                }
                
                bool executeNow = true;
                
                if (requestBuilder.requestQueueName != nil)
                {
                    NSMutableArray *requestQueue = [_requestQueues objectForKey:requestBuilder.requestQueueName];
                    
                    if (requestQueue == nil)
                    {
                        requestQueue = [[NSMutableArray alloc] initWithObjects:requestBuilder, nil];
                        [_requestQueues setObject:requestQueue forKey:requestBuilder.requestQueueName];
                    }
                    else
                    {
                        [requestQueue addObject:requestBuilder];
                        
                        if ([requestQueue count] > 1)
                        {
                            executeNow = false;
                            if (flags & TGActorRequestChangePriority)
                            {
                                if (requestQueue.count > 2)
                                {
                                    [requestQueue removeLastObject];
                                    [requestQueue insertObject:requestBuilder atIndex:1];
                                    
                                    TGLegacyLog(@"(Inserted actor with high priority (next in queue)");
                                }
                            }
                        }
                    }
                }
                
                if (executeNow)
                {
                    CFAbsoluteTime executeStart = CFAbsoluteTimeGetCurrent();
                    
                    [requestBuilder execute:options];
                    
                    double executeMs = (CFAbsoluteTimeGetCurrent() - executeStart) * 1000.0;
                    
                    if (executeMs >= 20.0)
                    {
                        IOS6_ACTIONSTAGE_PERF_LOG(@"ACTOREXEC t=%.3f path=%@ class=%@ ms=%.1f",
                              ActionStageStartupTime(),
                              path,
                              NSStringFromClass([requestBuilder class]),
                              executeMs);
                    }
                }
                else
                {
                    requestBuilder.storedOptions = options;
                }
            }
            else
            {
                TGLegacyLog(@"Error: request builder not found for \"%@\"", path);
            }
        }
        else
        {
            NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
            
            if (![watchers containsObject:actionHandle])
            {
                [watchers addObject:actionHandle];
            }
            
            ASActor *actor = [requestInfo objectForKey:@"requestBuilder"];
            
            if (actor.requestQueueName == nil)
            {
                CFAbsoluteTime joinedStart = CFAbsoluteTimeGetCurrent();
                
                [actor watcherJoined:actionHandle options:options waitingInActorQueue:false];
                
                double joinedMs = (CFAbsoluteTimeGetCurrent() - joinedStart) * 1000.0;
                
                if (joinedMs >= 20.0)
                {
                    IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORJOIN t=%.3f path=%@ class=%@ waiting=0 ms=%.1f",
                          ActionStageStartupTime(),
                          path,
                          NSStringFromClass([actor class]),
                          joinedMs);
                }
            }
            else
            {
                NSMutableArray *requestQueue = [_requestQueues objectForKey:actor.requestQueueName];
                
                if (requestQueue == nil || requestQueue.count == 0)
                {
                    CFAbsoluteTime joinedStart = CFAbsoluteTimeGetCurrent();
                    
                    [actor watcherJoined:actionHandle options:options waitingInActorQueue:false];
                    
                    double joinedMs = (CFAbsoluteTimeGetCurrent() - joinedStart) * 1000.0;
                    
                    if (joinedMs >= 20.0)
                    {
                        IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORJOIN t=%.3f path=%@ class=%@ waiting=0 ms=%.1f",
                              ActionStageStartupTime(),
                              path,
                              NSStringFromClass([actor class]),
                              joinedMs);
                    }
                }
                else
                {
                    bool waitingInActorQueue = [requestQueue objectAtIndex:0] != actor;
                    
                    CFAbsoluteTime joinedStart = CFAbsoluteTimeGetCurrent();
                    
                    [actor watcherJoined:actionHandle options:options waitingInActorQueue:waitingInActorQueue];
                    
                    double joinedMs = (CFAbsoluteTimeGetCurrent() - joinedStart) * 1000.0;
                    
                    if (joinedMs >= 20.0)
                    {
                        IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORJOIN t=%.3f path=%@ class=%@ waiting=%d ms=%.1f",
                              ActionStageStartupTime(),
                              path,
                              NSStringFromClass([actor class]),
                              waitingInActorQueue ? 1 : 0,
                              joinedMs);
                    }
                    
                    if (flags & TGActorRequestChangePriority)
                        [self changeActorPriority:path];
                }
            }
        }
        
        double actorRequestMs = (CFAbsoluteTimeGetCurrent() - actorRequestStart) * 1000.0;
        
        if (actorRequestMs >= 20.0)
        {
            IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORREQ t=%.3f path=%@ total=%.1fms",
                  ActionStageStartupTime(),
                  path,
                  actorRequestMs);
        }
    };
    
    if (inCurrentQueue)
        requestBlock();
    else
        [self dispatchOnStageQueue:requestBlock];
}

- (void)changeActorPriority:(NSString *)path
{
    [ActionStageInstance() dispatchOnStageQueue:^
     {
         NSDictionary *requestInfo = [_activeRequests objectForKey:path];
         
         if (requestInfo != nil)
         {
             ASActor *actor = [requestInfo objectForKey:@"requestBuilder"];
             
             if (actor.requestQueueName != nil)
             {
                 NSMutableArray *requestQueue = [_requestQueues objectForKey:actor.requestQueueName];
                 
                 if (requestQueue != nil && requestQueue.count != 0)
                 {
                     NSUInteger index = [requestQueue indexOfObject:actor];
                     
                     if (index != NSNotFound && index != 0 && index != 1)
                     {
                         [requestQueue removeObjectAtIndex:index];
                         [requestQueue insertObject:actor atIndex:1];
                         
                         TGLegacyLog(@"Changed actor %@ priority (next in %@)", path, actor.requestQueueName);
                     }
                 }
             }
         }
     }];
}

- (NSArray *)rejoinActionsWithGenericPathNow:(NSString *)genericPath prefix:(NSString *)prefix watcher:(id<ASWatcher>)watcher
{
    NSMutableDictionary *activeRequests = _activeRequests;
    NSMutableDictionary *cancelTimers = _cancelRequestTimers;
    
    NSMutableArray *rejoinPaths = [[NSMutableArray alloc] init];
    
    for (NSString *path in activeRequests.allKeys)
    {
        if ([path isEqualToString:genericPath] || ([[self genericStringForParametrizedPath:path] isEqualToString:genericPath] && (prefix.length == 0 || [path hasPrefix:prefix])))
        {
            [rejoinPaths addObject:path];
        }
    }
    
    for (NSString *path in cancelTimers.allKeys)
    {
        if ([[self genericStringForParametrizedPath:path] isEqualToString:genericPath] && [path hasPrefix:prefix])
        {
            [rejoinPaths addObject:path];
        }
    }
    
    for (NSString *path in rejoinPaths)
    {
        [self _requestGeneric:true inCurrentQueue:true path:path options:nil flags:0 watcher:watcher];
    }
    
    return rejoinPaths;
}

- (bool)isExecutingActorsWithGenericPath:(NSString *)genericPath
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        return nil;
    }
    
    __block bool result = false;
    
    [_activeRequests enumerateKeysAndObjectsUsingBlock:^(__unused NSString *path, NSDictionary *actionInfo, BOOL *stop)
     {
         ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
         
         if ([genericPath isEqualToString:[actor.class genericPath]])
         {
             result = true;
             
             if (stop != NULL)
                 *stop = true;
         }
     }];
    
    if (!result)
    {
        [_cancelRequestTimers enumerateKeysAndObjectsUsingBlock:^(__unused NSString *path, NSDictionary *actionInfo, BOOL *stop)
         {
             ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
             
             if ([genericPath isEqualToString:[actor.class genericPath]])
             {
                 result = true;
                 
                 if (stop != NULL)
                     *stop = true;
             }
         }];
    }
    
    return result;
}

- (bool)isExecutingActorsWithPathPrefix:(NSString *)pathPrefix
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        return nil;
    }
    
    __block bool result = false;
    
    [_activeRequests enumerateKeysAndObjectsUsingBlock:^(NSString *path, __unused id obj, BOOL *stop)
     {
         if ([path hasPrefix:pathPrefix])
         {
             result = true;
             
             if (stop != NULL)
                 *stop = true;
         }
     }];
    
    if (!result)
    {
        [_cancelRequestTimers enumerateKeysAndObjectsUsingBlock:^(NSString *path, __unused id obj, BOOL *stop)
         {
             if ([path hasPrefix:pathPrefix])
             {
                 result = true;
                 
                 if (stop != NULL)
                     *stop = true;
             }
         }];
    }
    
    return result;
}

- (NSArray *)executingActorsWithPathPrefix:(NSString *)pathPrefix
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        return nil;
    }
    
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    [_activeRequests enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSDictionary *actionInfo, __unused BOOL *stop)
     {
         if ([path hasPrefix:pathPrefix])
         {
             ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
             
             if (actor != nil)
                 [array addObject:actor];
         }
     }];
    
    [_cancelRequestTimers enumerateKeysAndObjectsUsingBlock:^(NSString *path, NSDictionary *actionInfo, __unused BOOL *stop)
     {
         if ([path hasPrefix:pathPrefix])
         {
             ASActor *actor = [actionInfo objectForKey:@"requestBuilder"];
             
             if (actor != nil)
                 [array addObject:actor];
         }
     }];
    
    return array;
}

- (ASActor *)executingActorWithPath:(NSString *)path
{
    if (![self isCurrentQueueStageQueue])
    {
        TGLegacyLog(@"%s should be called from graph queue", __PRETTY_FUNCTION__);
        return nil;
    }
    
    NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
    
    if (requestInfo != nil)
    {
        ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
        return requestBuilder;
    }
    
    NSMutableDictionary *cancelRequestInfo = [_cancelRequestTimers objectForKey:path];
    
    if (cancelRequestInfo != nil)
    {
        ASActor *requestBuilder = [[cancelRequestInfo objectForKey:@"requestInfo"] objectForKey:@"requestBuilder"];
        return requestBuilder;
    }
    
    return nil;
}

- (void)cancelActorTimeout:(NSString *)path
{
    NSMutableDictionary *cancelRequestInfo = [_cancelRequestTimers objectForKey:path];
    
    if (cancelRequestInfo != nil)
    {
        STimer *timer = [cancelRequestInfo objectForKey:@"timer"];
        [timer fireAndInvalidate];
        timer = nil;
        return;
    }
}

- (void)requestActor:(NSString *)action options:(NSDictionary *)options watcher:(id<ASWatcher>)watcher
{
    [self _requestGeneric:false inCurrentQueue:false path:action options:options flags:0 watcher:watcher];
}

- (void)requestActor:(NSString *)path options:(NSDictionary *)options flags:(int)flags watcher:(id<ASWatcher>)watcher
{
    [self _requestGeneric:false inCurrentQueue:false path:path options:options flags:flags watcher:watcher];
}

- (void)watchForPath:(NSString *)path watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    
    if (actionHandle == nil)
    {
        TGLegacyLog(@"Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
     {
         NSMutableArray *pathWatchers = [_liveNodeWatchers objectForKey:path];
         
         if (pathWatchers == nil)
         {
             pathWatchers = [[NSMutableArray alloc] init];
             [_liveNodeWatchers setObject:pathWatchers forKey:path];
         }
         
         if (![pathWatchers containsObject:actionHandle])
             [pathWatchers addObject:actionHandle];
     }];
}

- (void)watchForPaths:(NSArray *)paths watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    
    if (actionHandle == nil)
    {
        TGLegacyLog(@"Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
     {
         for (NSString *path in paths)
         {
             NSMutableArray *pathWatchers = [_liveNodeWatchers objectForKey:path];
             
             if (pathWatchers == nil)
             {
                 pathWatchers = [[NSMutableArray alloc] init];
                 [_liveNodeWatchers setObject:pathWatchers forKey:path];
             }
             
             if (![pathWatchers containsObject:actionHandle])
                 [pathWatchers addObject:actionHandle];
         }
     }];
}

- (void)watchForGenericPath:(NSString *)path watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    
    if (actionHandle == nil)
    {
        TGLegacyLog(@"Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
     {
         NSString *genericPath = [self genericStringForParametrizedPath:path];
         NSMutableArray *pathWatchers = [_liveNodeWatchers objectForKey:genericPath];
         
         if (pathWatchers == nil)
         {
             pathWatchers = [[NSMutableArray alloc] init];
             [_liveNodeWatchers setObject:pathWatchers forKey:genericPath];
         }
         
         [pathWatchers addObject:actionHandle];
     }];
}

- (void)watchForMessagesToWatchersAtGenericPath:(NSString *)genericPath watcher:(id<ASWatcher>)watcher
{
    ASHandle *actionHandle = watcher.actionHandle;
    
    if (actionHandle == nil)
    {
        TGLegacyLog(@"Warning: actionHandle is nil in %s:%d", __PRETTY_FUNCTION__, __LINE__);
        return;
    }
    
    [self dispatchOnStageQueue:^
     {
         NSMutableArray *pathWatchers = [_actorMessagesWatchers objectForKey:genericPath];
         
         if (pathWatchers == nil)
         {
             pathWatchers = [[NSMutableArray alloc] init];
             [_actorMessagesWatchers setObject:pathWatchers forKey:genericPath];
         }
         
         [pathWatchers addObject:actionHandle];
     }];
}

- (void)removeRequestFromQueueAndProceedIfFirst:(NSString *)name fromRequestBuilder:(ASActor *)requestBuilder
{
    NSMutableArray *requestQueue = [_requestQueues objectForKey:requestBuilder.requestQueueName == nil ? name : requestBuilder.requestQueueName];
    
    if (requestQueue == nil)
    {
        TGLegacyLog(@"Warning: requestQueue is nil");
    }
    else
    {
        if (requestQueue.count == 0)
        {
            TGLegacyLog(@"Warning ***** request queue \"%@\" is empty.", requestBuilder.requestQueueName);
        }
        else
        {
            if ([requestQueue objectAtIndex:0] == requestBuilder)
            {
                [requestQueue removeObjectAtIndex:0];
                
                if (requestQueue.count != 0)
                {
                    ASActor *nextRequest = [requestQueue objectAtIndex:0];
                    id nextRequestOptions = nextRequest.storedOptions;
                    nextRequest.storedOptions = nil;
                    
                    if (nextRequest != nil && !nextRequest.cancelled)
                    {
                        CFAbsoluteTime executeStart = CFAbsoluteTimeGetCurrent();
                        
                        [nextRequest execute:nextRequestOptions];
                        
                        double executeMs = (CFAbsoluteTimeGetCurrent() - executeStart) * 1000.0;
                        
                        if (executeMs >= 20.0)
                        {
                            IOS6_ACTIONSTAGE_PERF_LOG(@"ACTOREXEC t=%.3f QUEUED path=%@ class=%@ ms=%.1f",
                                  ActionStageStartupTime(),
                                  nextRequest.path,
                                  NSStringFromClass([nextRequest class]),
                                  executeMs);
                        }
                    }
                }
                else
                {
                    [_requestQueues removeObjectForKey:requestBuilder.requestQueueName];
                }
            }
            else
            {
                if ([requestQueue containsObject:requestBuilder])
                {
                    [requestQueue removeObject:requestBuilder];
                }
                else
                {
                    TGLegacyLog(@"Warning request queue \"%@\" doesn't contain request to %@", requestBuilder.requestQueueName, requestBuilder.path);
                }
            }
        }
    }
}

- (void)removeWatcher:(id<ASWatcher>)watcher
{
    [self removeWatcherByHandle:watcher.actionHandle];
}

- (void)removeWatcherByHandle:(ASHandle *)actionHandle
{
    ASHandle *watcherGraphHandle = actionHandle;
    
    if (watcherGraphHandle == nil)
    {
        TGLegacyLog(@"Warning: graph handle is nil in removeWatcher");
        return;
    }
    
    bool alreadyExecuting = false;
    
    OSSpinLockLock(&removeWatcherRequestsLock);
    
    if (!_removeWatcherRequests.empty())
        alreadyExecuting = true;
    
    _removeWatcherRequests.push_back(watcherGraphHandle);
    
    OSSpinLockUnlock(&removeWatcherRequestsLock);
    
    if (alreadyExecuting && ![self isCurrentQueueStageQueue])
        return;
    
    [self dispatchOnHighPriorityQueue:^
     {
         CFAbsoluteTime removeStart = CFAbsoluteTimeGetCurrent();
         
         std::vector<ASHandle *> removeWatchers;
         
         OSSpinLockLock(&removeWatcherRequestsLock);
         removeWatchers.insert(removeWatchers.begin(), _removeWatcherRequests.begin(), _removeWatcherRequests.end());
         _removeWatcherRequests.clear();
         OSSpinLockUnlock(&removeWatcherRequestsLock);
         
         for (std::vector<ASHandle *>::iterator it = removeWatchers.begin(); it != removeWatchers.end(); it++)
         {
             ASHandle *actionHandle = *it;
             
             for (id key in [_activeRequests allKeys])
             {
                 NSMutableDictionary *requestInfo = [_activeRequests objectForKey:key];
                 NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
                 [watchers removeObject:actionHandle];
                 
                 if (watchers.count == 0)
                     [self scheduleCancelRequest:(NSString *)key];
             }
             
             NSMutableArray *keysToRemove = nil;
             
             for (NSString *key in [_liveNodeWatchers allKeys])
             {
                 NSMutableArray *watchers = [_liveNodeWatchers objectForKey:key];
                 [watchers removeObject:actionHandle];
                 
                 if (watchers.count == 0)
                 {
                     if (keysToRemove == nil)
                         keysToRemove = [[NSMutableArray alloc] init];
                     
                     [keysToRemove addObject:key];
                 }
             }
             
             if (keysToRemove != nil)
                 [_liveNodeWatchers removeObjectsForKeys:keysToRemove];
             
             keysToRemove = nil;
             
             for (NSString *key in [_actorMessagesWatchers allKeys])
             {
                 NSMutableArray *watchers = [_actorMessagesWatchers objectForKey:key];
                 [watchers removeObject:actionHandle];
                 
                 if (watchers.count == 0)
                 {
                     if (keysToRemove == nil)
                         keysToRemove = [[NSMutableArray alloc] init];
                     
                     [keysToRemove addObject:key];
                 }
             }
             
             if (keysToRemove != nil)
                 [_actorMessagesWatchers removeObjectsForKeys:keysToRemove];
         }
         
         double removeMs = (CFAbsoluteTimeGetCurrent() - removeStart) * 1000.0;
         
         if (removeMs >= 20.0)
         {
             IOS6_ACTIONSTAGE_PERF_LOG(@"WATCHERREMOVE t=%.3f count=%d ms=%.1f",
                   ActionStageStartupTime(),
                   (int)removeWatchers.size(),
                   removeMs);
         }
     }];
}

- (void)removeAllWatchersFromPath:(NSString *)path
{
    [self dispatchOnHighPriorityQueue:^
     {
         NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
         
         if (requestInfo != nil)
         {
             NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
             [watchers removeAllObjects];
             [self scheduleCancelRequest:path];
         }
     }];
}

- (void)removeWatcher:(id<ASWatcher>)watcher fromPath:(NSString *)path
{
    ASHandle *actionHandle = watcher.actionHandle;
    [self removeWatcherByHandle:actionHandle fromPath:path];
}

- (void)removeWatcherByHandle:(ASHandle *)watcherGraphHandle fromPath:(NSString *)watcherPath
{
    if (watcherGraphHandle == nil)
    {
        TGLegacyLog(@"Warning: graph handle is nil in removeWatcher:fromPath");
        return;
    }
    
    bool alreadyExecuting = false;
    
    OSSpinLockLock(&removeWatcherFromPathRequestsLock);
    
    if (!_removeWatcherFromPathRequests.empty())
        alreadyExecuting = true;
    
    _removeWatcherFromPathRequests.push_back(std::pair<ASHandle *, NSString *>(watcherGraphHandle, watcherPath));
    
    OSSpinLockUnlock(&removeWatcherFromPathRequestsLock);
    
    if (alreadyExecuting && ![self isCurrentQueueStageQueue])
        return;
    
    [self dispatchOnHighPriorityQueue:^
     {
         CFAbsoluteTime removeStart = CFAbsoluteTimeGetCurrent();
         
         std::vector<std::pair<ASHandle *, NSString *> > removeWatchersFromPath;
         
         OSSpinLockLock(&removeWatcherFromPathRequestsLock);
         removeWatchersFromPath.insert(removeWatchersFromPath.begin(), _removeWatcherFromPathRequests.begin(), _removeWatcherFromPathRequests.end());
         _removeWatcherFromPathRequests.clear();
         OSSpinLockUnlock(&removeWatcherFromPathRequestsLock);
         
         if (removeWatchersFromPath.size() > 1)
         {
             TGLegacyLog(@"Cancelled %ld requests at once", removeWatchersFromPath.size());
         }
         
         for (std::vector<std::pair<ASHandle *, NSString *> >::iterator it = removeWatchersFromPath.begin(); it != removeWatchersFromPath.end(); it++)
         {
             ASHandle *actionHandle = it->first;
             NSString *path = it->second;
             
             if (path == nil)
                 continue;
             
             NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
             
             if (requestInfo != nil)
             {
                 NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
                 
                 if ([watchers containsObject:actionHandle])
                     [watchers removeObject:actionHandle];
                 
                 if (watchers.count == 0)
                     [self scheduleCancelRequest:path];
             }
             
             NSMutableArray *watchers = [_liveNodeWatchers objectForKey:path];
             
             if ([watchers containsObject:actionHandle])
                 [watchers removeObject:actionHandle];
             
             if (watchers.count == 0)
                 [_liveNodeWatchers removeObjectForKey:path];
             
             watchers = [_actorMessagesWatchers objectForKey:path];
             
             if ([watchers containsObject:actionHandle])
                 [watchers removeObject:actionHandle];
             
             if (watchers.count == 0)
                 [_actorMessagesWatchers removeObjectForKey:path];
         }
         
         double removeMs = (CFAbsoluteTimeGetCurrent() - removeStart) * 1000.0;
         
         if (removeMs >= 20.0)
         {
             IOS6_ACTIONSTAGE_PERF_LOG(@"WATCHERREMOVEPATH t=%.3f count=%d ms=%.1f",
                   ActionStageStartupTime(),
                   (int)removeWatchersFromPath.size(),
                   removeMs);
         }
     }];
}

- (bool)requestActorStateNow:(NSString *)path
{
    if ([_activeRequests objectForKey:path] != nil)
        return true;
    
    return false;
}

- (void)dispatchResource:(NSString *)path resource:(id)resource
{
    [self dispatchResource:path resource:resource arguments:nil];
}

- (void)dispatchResource:(NSString *)path resource:(id)resource arguments:(id)arguments
{
    [self dispatchOnStageQueue:^
     {
         CFAbsoluteTime resourceStart = CFAbsoluteTimeGetCurrent();
         
         NSString *genericPath = [self genericStringForParametrizedPath:path];
         
         NSArray *watchers = [[_liveNodeWatchers objectForKey:path] copy];
         
         if (watchers != nil)
         {
             for (ASHandle *handle in watchers)
             {
                 CFAbsoluteTime callbackStart = CFAbsoluteTimeGetCurrent();
                 [handle notifyResourceDispatched:path resource:resource arguments:arguments];
                 double callbackMs = (CFAbsoluteTimeGetCurrent() - callbackStart) * 1000.0;
                 if (callbackMs >= 20.0)
                     IOS6_ACTIONSTAGE_PERF_LOG(@"RESOURCECALLBACK t=%.3f path=%@ ms=%.1f", ActionStageStartupTime(), path, callbackMs);
             }
         }
         
         if (![genericPath isEqualToString:path])
         {
             watchers = [[_liveNodeWatchers objectForKey:genericPath] copy];
             
             if (watchers != nil)
             {
                 for (ASHandle *handle in watchers)
                 {
                     CFAbsoluteTime callbackStart = CFAbsoluteTimeGetCurrent();
                     [handle notifyResourceDispatched:path resource:resource arguments:arguments];
                     double callbackMs = (CFAbsoluteTimeGetCurrent() - callbackStart) * 1000.0;
                     if (callbackMs >= 20.0)
                         IOS6_ACTIONSTAGE_PERF_LOG(@"RESOURCECALLBACK t=%.3f path=%@ generic=%@ ms=%.1f", ActionStageStartupTime(), path, genericPath, callbackMs);
                 }
             }
         }
         
         double resourceMs = (CFAbsoluteTimeGetCurrent() - resourceStart) * 1000.0;
         
         if (resourceMs >= 20.0)
         {
             IOS6_ACTIONSTAGE_PERF_LOG(@"RESOURCEDONE t=%.3f path=%@ total=%.1fms",
                   ActionStageStartupTime(),
                   path,
                   resourceMs);
         }
     }];
}

- (void)actionCompleted:(NSString *)action result:(id)result
{
    [self dispatchOnStageQueue:^
     {
         CFAbsoluteTime completedStart = CFAbsoluteTimeGetCurrent();
         
         NSMutableDictionary *requestInfo = [_activeRequests objectForKey:action];
         
         if (requestInfo != nil)
         {
             ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
             
             NSMutableArray *actionWatchers = [requestInfo objectForKey:@"watchers"];
             [_activeRequests removeObjectForKey:action];
             
             for (ASHandle *handle in actionWatchers)
             {
                 CFAbsoluteTime callbackStart = CFAbsoluteTimeGetCurrent();
                 [handle notifyActorCompleted:ASStatusSuccess path:action result:result];
                 double callbackMs = (CFAbsoluteTimeGetCurrent() - callbackStart) * 1000.0;
                 if (callbackMs >= 20.0)
                     IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORCALLBACK t=%.3f path=%@ ms=%.1f", ActionStageStartupTime(), action, callbackMs);
             }
             
             [actionWatchers removeAllObjects];
             
             if (requestBuilder == nil)
             {
                 TGLegacyLog(@"Warning ***** requestBuilder is nil");
             }
             else if (requestBuilder.requestQueueName != nil)
             {
                 [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName
                                            fromRequestBuilder:requestBuilder];
             }
         }
         
         double completedMs = (CFAbsoluteTimeGetCurrent() - completedStart) * 1000.0;
         
         if (completedMs >= 20.0)
         {
             IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORDONE t=%.3f path=%@ total=%.1fms",
                   ActionStageStartupTime(),
                   action,
                   completedMs);
         }
     }];
}

- (void)dispatchMessageToWatchers:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    [self dispatchOnStageQueue:^
     {
         CFAbsoluteTime messageStart = CFAbsoluteTimeGetCurrent();
         
         NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
         
         if (requestInfo != nil)
         {
             NSArray *actionWatchersCopy = [[requestInfo objectForKey:@"watchers"] copy];
             
             for (ASHandle *handle in actionWatchersCopy)
             {
                 CFAbsoluteTime callbackStart = CFAbsoluteTimeGetCurrent();
                 
                 [handle receiveActorMessage:path messageType:messageType message:message];
                 
                 double callbackMs = (CFAbsoluteTimeGetCurrent() - callbackStart) * 1000.0;
                 
                 if (callbackMs >= 20.0)
                 {
                     IOS6_ACTIONSTAGE_PERF_LOG(@"MESSAGECALLBACK t=%.3f path=%@ type=%@ ms=%.1f",
                           ActionStageStartupTime(),
                           path,
                           messageType,
                           callbackMs);
                 }
             }
         }
         
         if (_actorMessagesWatchers.count != 0)
         {
             NSString *genericPath = [self genericStringForParametrizedPath:path];
             NSArray *messagesWatchersCopy = [[_actorMessagesWatchers objectForKey:genericPath] copy];
             
             if (messagesWatchersCopy != nil)
             {
                 for (ASHandle *handle in messagesWatchersCopy)
                 {
                     CFAbsoluteTime callbackStart = CFAbsoluteTimeGetCurrent();
                     
                     [handle receiveActorMessage:path messageType:messageType message:message];
                     
                     double callbackMs = (CFAbsoluteTimeGetCurrent() - callbackStart) * 1000.0;
                     
                     if (callbackMs >= 20.0)
                     {
                         IOS6_ACTIONSTAGE_PERF_LOG(@"MESSAGECALLBACK t=%.3f path=%@ generic=%@ type=%@ ms=%.1f",
                               ActionStageStartupTime(),
                               path,
                               genericPath,
                               messageType,
                               callbackMs);
                     }
                 }
             }
         }
         
         double messageMs = (CFAbsoluteTimeGetCurrent() - messageStart) * 1000.0;
         
         if (messageMs >= 20.0)
         {
             IOS6_ACTIONSTAGE_PERF_LOG(@"MESSAGEDONE t=%.3f path=%@ type=%@ total=%.1fms",
                   ActionStageStartupTime(),
                   path,
                   messageType,
                   messageMs);
         }
     }];
}

- (void)actionFailed:(NSString *)action reason:(int)reason
{
    [self dispatchOnStageQueue:^
     {
         CFAbsoluteTime failedStart = CFAbsoluteTimeGetCurrent();
         
         NSMutableDictionary *requestInfo = [_activeRequests objectForKey:action];
         
         if (requestInfo != nil)
         {
             ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
             
             NSMutableArray *actionWatchers = [requestInfo objectForKey:@"watchers"];
             [_activeRequests removeObjectForKey:action];
             
             for (ASHandle *handle in actionWatchers)
             {
                 CFAbsoluteTime callbackStart = CFAbsoluteTimeGetCurrent();
                 [handle notifyActorCompleted:reason path:action result:nil];
                 double callbackMs = (CFAbsoluteTimeGetCurrent() - callbackStart) * 1000.0;
                 if (callbackMs >= 20.0)
                     IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORFAILCALLBACK t=%.3f path=%@ reason=%d ms=%.1f", ActionStageStartupTime(), action, reason, callbackMs);
             }
             
             [actionWatchers removeAllObjects];
             
             if (requestBuilder == nil)
             {
                 TGLegacyLog(@"Warning ***** requestBuilder is nil");
             }
             else if (requestBuilder.requestQueueName != nil)
             {
                 [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName
                                            fromRequestBuilder:requestBuilder];
             }
         }
         
         double failedMs = (CFAbsoluteTimeGetCurrent() - failedStart) * 1000.0;
         
         if (failedMs >= 20.0)
         {
             IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORFAIL t=%.3f path=%@ reason=%d total=%.1fms",
                   ActionStageStartupTime(),
                   action,
                   reason,
                   failedMs);
         }
     }];
}

- (void)nodeRetrieved:(NSString *)path node:(SGraphNode *)node
{
    [self actionCompleted:path result:node];
}

- (void)nodeRetrieveProgress:(NSString *)path progress:(float)progress
{
    [self dispatchOnStageQueue:^
     {
         NSMutableDictionary *requestInfo = [_activeRequests objectForKey:path];
         
         if (requestInfo == nil)
             requestInfo = [_activeRequests objectForKey:path];
         
         if (requestInfo != nil)
         {
             NSMutableArray *watchers = [requestInfo objectForKey:@"watchers"];
             
             for (ASHandle *handle in watchers)
             {
                 CFAbsoluteTime callbackStart = CFAbsoluteTimeGetCurrent();
                 [handle notifyActorProgress:path progress:progress];
                 double callbackMs = (CFAbsoluteTimeGetCurrent() - callbackStart) * 1000.0;
                 if (callbackMs >= 20.0)
                     IOS6_ACTIONSTAGE_PERF_LOG(@"PROGRESSCALLBACK t=%.3f path=%@ ms=%.1f", ActionStageStartupTime(), path, callbackMs);
             }
         }
     }];
}

- (void)nodeRetrieveFailed:(NSString *)path
{
    [self actionFailed:path reason:-1];
}

- (void)scheduleCancelRequest:(NSString *)path
{
    NSMutableDictionary *activeRequests = _activeRequests;
    NSMutableDictionary *cancelTimers = _cancelRequestTimers;
    
    NSMutableDictionary *requestInfo = [activeRequests objectForKey:path];
    NSMutableDictionary *cancelRequestInfo = [cancelTimers objectForKey:path];
    
    if (requestInfo != nil && cancelRequestInfo == nil)
    {
        ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
        NSTimeInterval cancelTimeout = requestBuilder.cancelTimeout;
        
        if (cancelTimeout <= DBL_EPSILON)
        {
            [activeRequests removeObjectForKey:path];
            
            [requestBuilder cancel];
            if (requestBuilder.requestQueueName != nil)
            {
                [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName
                                           fromRequestBuilder:requestBuilder];
            }
        }
        else
        {
            TGLegacyLog(@"Will cancel request to \"%@\" in %f s", path, cancelTimeout);
            
            NSDictionary *cancelDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                        path, @"path",
                                        [NSNumber numberWithInt:0], @"type",
                                        nil];
            
            STimer *timer = [[STimer alloc] initWithTimeout:cancelTimeout
                                                     repeat:false
                                                 completion:^
                             {
                                 [self performCancelRequest:cancelDict];
                             }
                                                nativeQueue:[ActionStageInstance() globalStageDispatchQueue]];
            
            cancelRequestInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                 requestInfo, @"requestInfo",
                                 nil];
            
            [cancelRequestInfo setObject:timer forKey:@"timer"];
            [cancelTimers setObject:cancelRequestInfo forKey:path];
            [activeRequests removeObjectForKey:path];
            
            [timer start];
        }
    }
}

- (void)performCancelRequest:(NSDictionary *)cancelDict
{
    NSString *path = [cancelDict objectForKey:@"path"];
    
    [self dispatchOnStageQueue:^
     {
         NSMutableDictionary *cancelTimers = _cancelRequestTimers;
         
         NSMutableDictionary *cancelRequestInfo = [cancelTimers objectForKey:path];
         
         if (cancelRequestInfo == nil)
         {
             TGLegacyLog(@"Warning: cancelNodeRequestTimerEvent: \"%@\": no cancel info found", path);
             return;
         }
         
         NSDictionary *requestInfo = [cancelRequestInfo objectForKey:@"requestInfo"];
         ASActor *requestBuilder = [requestInfo objectForKey:@"requestBuilder"];
         
         if (requestBuilder == nil)
         {
             TGLegacyLog(@"Warning: active request builder for \"%@\" not fond, cannot cancel request", path);
         }
         else
         {
             CFAbsoluteTime cancelStart = CFAbsoluteTimeGetCurrent();
             
             [requestBuilder cancel];
             
             double cancelMs = (CFAbsoluteTimeGetCurrent() - cancelStart) * 1000.0;
             
             if (cancelMs >= 20.0)
             {
                 IOS6_ACTIONSTAGE_PERF_LOG(@"ACTORCANCEL t=%.3f path=%@ class=%@ ms=%.1f",
                       ActionStageStartupTime(),
                       path,
                       NSStringFromClass([requestBuilder class]),
                       cancelMs);
             }
             if (requestBuilder.requestQueueName != nil)
             {
                 [self removeRequestFromQueueAndProceedIfFirst:requestBuilder.requestQueueName
                                            fromRequestBuilder:requestBuilder];
             }
         }
         
         [cancelTimers removeObjectForKey:path];
     }];
}

@end