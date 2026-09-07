#import "TGModernConversationActivityManager.h"

#import "ATQueue.h"
#import "TGTimer.h"

#import "TGModernConversationActivity.h"

@class TGModernConversationActivityManager;

@interface TGModernConversationActivityManagerReference : NSObject

@property (nonatomic, weak) TGModernConversationActivityManager *value;

@end

@implementation TGModernConversationActivityManagerReference

@end

static TGModernConversationActivityManager *TGModernConversationActivityManagerResolveReference(TGModernConversationActivityManagerReference *reference)
{
    TGModernConversationActivityManager *manager = nil;
    @synchronized (reference)
    {
        manager = reference.value;
    }
    return manager;
}

@interface TGModernConversationActivityManager ()
{
    NSMutableArray *_activityList;
    NSString *_previousActivityType;
    TGModernConversationActivityManagerReference *_lifetimeReference;
}

@end

@implementation TGModernConversationActivityManager

+ (ATQueue *)activityManagerQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] init];
    });
    
    return queue;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _activityList = [[NSMutableArray alloc] init];
        _lifetimeReference = [[TGModernConversationActivityManagerReference alloc] init];
        _lifetimeReference.value = self;
    }
    return self;
}

- (void)dealloc
{
    @synchronized (_lifetimeReference)
    {
        _lifetimeReference.value = nil;
    }
}

- (TGModernConversationActivity *)_topActivity
{
    if (_activityList.count == 0)
        return nil;
    
    NSInteger highestPriority = NSIntegerMin;
    for (TGModernConversationActivity *activity in _activityList)
    {
        if (activity.priority > highestPriority)
            highestPriority = activity.priority;
    }
    
    for (TGModernConversationActivity *activity in _activityList.reverseObjectEnumerator)
    {
        if (activity.priority == highestPriority)
            return activity;
    }
    
    return nil;
}

- (void)_activityUpdated
{
    TGModernConversationActivity *topActivity = [self _topActivity];
    if (topActivity != nil)
    {
        if (_sendActivityUpdate)
            _sendActivityUpdate(topActivity.type, _previousActivityType);
    } else if (_previousActivityType != nil) {
        if (_sendActivityUpdate)
            _sendActivityUpdate(nil, _previousActivityType);
    }
    _previousActivityType = topActivity.type;
}

- (id)addActivityWithType:(NSString *)type priority:(NSInteger)priority
{
    return [self _addActivityWithType:type priority:priority timeout:0.0].holder;
}

- (void)addActivityWithType:(NSString *)type priority:(NSInteger)priority timeout:(NSTimeInterval)timeout
{
    [self _addActivityWithType:type priority:priority timeout:timeout];
}

- (TGModernConversationActivity *)_addActivityWithType:(NSString *)type priority:(NSInteger)priority timeout:(NSTimeInterval)timeout
{
    TGModernConversationActivity *activity = [[TGModernConversationActivity alloc] initWithType:type priority:priority tickInterval:5.0 timeout:timeout timeoutQueue:[TGModernConversationActivityManager activityManagerQueue]];
    
    [[TGModernConversationActivityManager activityManagerQueue] dispatch:^
    {
        TGModernConversationActivityManagerReference *reference = _lifetimeReference;
        if (![_activityList containsObject:activity])
        {
            activity.onDelete = ^(TGModernConversationActivity *activity)
            {
                TGModernConversationActivityManager *manager = TGModernConversationActivityManagerResolveReference(reference);
                if (manager != nil)
                    [manager removeActivity:activity];
            };
            activity.onTick = ^(TGModernConversationActivity *activity)
            {
                TGModernConversationActivityManager *manager = TGModernConversationActivityManagerResolveReference(reference);
                if (manager != nil)
                    [manager tickActivity:activity];
            };
            TGModernConversationActivity *lastTopActivity = [self _topActivity];
            [_activityList addObject:activity];
            if (!TGObjectCompare(lastTopActivity, [self _topActivity]))
                [self _activityUpdated];
        }
        else
        {
            NSUInteger index = [_activityList indexOfObject:activity];
            if (index != NSNotFound)
                [((TGModernConversationActivity *)_activityList[index]) resetTimeout];
        }
    }];
    
    return activity;
}

- (void)removeActivityWithType:(NSString *)type
{
    [[TGModernConversationActivityManager activityManagerQueue] dispatch:^
    {
        for (TGModernConversationActivity *activity in _activityList)
        {
            if ([activity.type isEqualToString:type])
            {
                [self removeActivity:activity];
                break;
            }
        }
    }];
}

- (void)tickActivity:(TGModernConversationActivity *)activity
{
    if (activity == nil)
        return;
    
    [[TGModernConversationActivityManager activityManagerQueue] dispatch:^
    {
        if ([activity isEqual:[self _topActivity]])
        {
            if (_sendActivityUpdate)
                _sendActivityUpdate(activity.type, _previousActivityType);
            _previousActivityType = activity.type;
        }
    }];
}

- (void)removeActivity:(TGModernConversationActivity *)activity
{
    [[TGModernConversationActivityManager activityManagerQueue] dispatch:^
    {
        if ([_activityList containsObject:activity])
        {
            TGModernConversationActivity *lastTopActivity = [self _topActivity];
            [_activityList removeObject:activity];
            if (!TGObjectCompare(lastTopActivity, [self _topActivity]))
                [self _activityUpdated];
        }
    }];
}

@end
