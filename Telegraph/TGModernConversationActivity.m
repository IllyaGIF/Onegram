#import "TGModernConversationActivity.h"

#import "ATQueue.h"
#import "TGTimer.h"

@interface TGModernConversationActivityHolder : NSObject

@property (nonatomic, strong) TGModernConversationActivity *activity;

@end

@interface TGModernConversationActivityReference : NSObject

@property (nonatomic, weak) TGModernConversationActivity *value;

@end

@implementation TGModernConversationActivityReference

@end

static TGModernConversationActivity *TGModernConversationActivityResolveReference(TGModernConversationActivityReference *reference)
{
    TGModernConversationActivity *activity = nil;
    @synchronized (reference)
    {
        activity = reference.value;
    }
    return activity;
}

@implementation TGModernConversationActivityHolder

- (void)dealloc
{
    TGModernConversationActivity *activity = _activity;
    if (activity.onDelete)
        activity.onDelete(activity);
}

@end

@interface TGModernConversationActivity ()
{
    ATQueue *_timeoutQueue;
    TGTimer *_timer;
    TGTimer *_tickTimer;
    NSTimeInterval _tickInterval;
    TGModernConversationActivityReference *_lifetimeReference;
}

@end

@implementation TGModernConversationActivity

- (instancetype)initWithType:(NSString *)type priority:(NSInteger)priority tickInterval:(NSTimeInterval)tickInterval timeout:(NSTimeInterval)timeout timeoutQueue:(ATQueue *)timeoutQueue
{
    self = [super init];
    if (self != nil)
    {
        _type = type;
        _priority = priority;
        _tickInterval = tickInterval;
        _timeout = timeout;
        
        _timeoutQueue = timeoutQueue;
        _lifetimeReference = [[TGModernConversationActivityReference alloc] init];
        _lifetimeReference.value = self;
        TGModernConversationActivityReference *reference = _lifetimeReference;
        
        if (timeout > DBL_EPSILON)
        {
            _timer = [[TGTimer alloc] initWithTimeout:timeout repeat:false completion:^
            {
                TGModernConversationActivity *activity = TGModernConversationActivityResolveReference(reference);
                if (activity != nil)
                    [activity _onTimeout];
            } queue:[timeoutQueue nativeQueue]];
            [_timer start];
        }
        else
            [self _startTickTimer];
    }
    return self;
}

- (void)dealloc
{
    @synchronized (_lifetimeReference)
    {
        _lifetimeReference.value = nil;
    }
    TGTimer *timer = _timer;
    TGTimer *tickTimer = _tickTimer;
    if (timer != nil || tickTimer != nil)
    {
        [_timeoutQueue dispatch:^
        {
            [timer invalidate];
            [tickTimer invalidate];
        }];
    }
}

- (void)resetTimeout
{
    [_timeoutQueue dispatch:^
    {
        [_timer resetTimeout:_timeout];
        
        if (_tickTimer == nil)
            [self _startTickTimer];
    }];
}

- (void)_startTickTimer
{
    [_tickTimer invalidate];
    
    TGModernConversationActivityReference *reference = _lifetimeReference;
    _tickTimer = [[TGTimer alloc] initWithTimeout:_tickInterval repeat:true completion:^
    {
        TGModernConversationActivity *activity = TGModernConversationActivityResolveReference(reference);
        if (activity != nil && activity.onTick)
            activity.onTick(activity);
    } queue:[_timeoutQueue nativeQueue]];
    [_tickTimer start];
}

- (void)_onTimeout
{
    if (_onDelete)
        _onDelete(self);
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGModernConversationActivity class]] && TGStringCompare(((TGModernConversationActivity *)object)->_type, _type) && ((TGModernConversationActivity *)object)->_priority == _priority && ABS(((TGModernConversationActivity *)object)->_timeout - _timeout) < DBL_EPSILON;
}

- (id)holder
{
    TGModernConversationActivityHolder *holder = [[TGModernConversationActivityHolder alloc] init];;
    holder.activity = self;
    return holder;
}

@end
