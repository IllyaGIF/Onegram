#import "ASHandle.h"

#import "LegacyComponents.h"

#import "ASWatcher.h"

#import <pthread.h>

@interface ASHandle ()
{
    pthread_mutex_t _delegateMutex;
}

@end

@implementation ASHandle

@synthesize delegate = _delegate;
@synthesize releaseOnMainThread = _releaseOnMainThread;

- (void)_initializeDelegateMutex
{
    pthread_mutexattr_t attributes;
    pthread_mutexattr_init(&attributes);
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&_delegateMutex, &attributes);
    pthread_mutexattr_destroy(&attributes);
}

- (id)initWithDelegate:(id<ASWatcher>)delegate
{
    self = [super init];
    if (self != nil)
    {
        [self _initializeDelegateMutex];
        _delegate = delegate;
    }
    return self;
}

- (id)initWithDelegate:(id<ASWatcher>)delegate releaseOnMainThread:(bool)releaseOnMainThread
{
    self = [super init];
    if (self != nil)
    {
        [self _initializeDelegateMutex];
        _delegate = delegate;
        _releaseOnMainThread = releaseOnMainThread;
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_lock(&_delegateMutex);
    _delegate = nil;
    pthread_mutex_unlock(&_delegateMutex);
    pthread_mutex_destroy(&_delegateMutex);
}

- (void)reset
{
    pthread_mutex_lock(&_delegateMutex);
    _delegate = nil;
    pthread_mutex_unlock(&_delegateMutex);
}

- (bool)hasDelegate
{
    pthread_mutex_lock(&_delegateMutex);
    bool result = _delegate != nil;
    pthread_mutex_unlock(&_delegateMutex);
    return result;
}

- (id<ASWatcher>)delegate
{
    pthread_mutex_lock(&_delegateMutex);
    __strong id<ASWatcher> result = _delegate;
    pthread_mutex_unlock(&_delegateMutex);
    return result;
}

- (void)setDelegate:(id<ASWatcher>)delegate
{
    pthread_mutex_lock(&_delegateMutex);
    _delegate = delegate;
    pthread_mutex_unlock(&_delegateMutex);
}

- (void)requestAction:(NSString *)action options:(id)options
{
    pthread_mutex_lock(&_delegateMutex);
    __strong id<ASWatcher> delegate = _delegate;
    if (delegate != nil && [delegate respondsToSelector:@selector(actionStageActionRequested:options:)])
        [delegate actionStageActionRequested:action options:options];
    pthread_mutex_unlock(&_delegateMutex);
}

- (void)receiveActorMessage:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    pthread_mutex_lock(&_delegateMutex);
    __strong id<ASWatcher> delegate = _delegate;
    if (delegate != nil && [delegate respondsToSelector:@selector(actorMessageReceived:messageType:message:)])
        [delegate actorMessageReceived:path messageType:messageType message:message];
    pthread_mutex_unlock(&_delegateMutex);
}

- (void)notifyResourceDispatched:(NSString *)path resource:(id)resource
{
    [self notifyResourceDispatched:path resource:resource arguments:nil];
}

- (void)notifyResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)arguments
{
    pthread_mutex_lock(&_delegateMutex);
    __strong id<ASWatcher> delegate = _delegate;
    if (delegate != nil && [delegate respondsToSelector:@selector(actionStageResourceDispatched:resource:arguments:)])
        [delegate actionStageResourceDispatched:path resource:resource arguments:arguments];
    pthread_mutex_unlock(&_delegateMutex);
}

- (void)notifyActorCompleted:(int)status path:(NSString *)path result:(id)result
{
    pthread_mutex_lock(&_delegateMutex);
    __strong id<ASWatcher> delegate = _delegate;
    if (delegate != nil && [delegate respondsToSelector:@selector(actorCompleted:path:result:)])
        [delegate actorCompleted:status path:path result:result];
    pthread_mutex_unlock(&_delegateMutex);
}

- (void)notifyActorProgress:(NSString *)path progress:(float)progress
{
    pthread_mutex_lock(&_delegateMutex);
    __strong id<ASWatcher> delegate = _delegate;
    if (delegate != nil && [delegate respondsToSelector:@selector(actorReportedProgress:progress:)])
        [delegate actorReportedProgress:path progress:progress];
    pthread_mutex_unlock(&_delegateMutex);
}

@end
