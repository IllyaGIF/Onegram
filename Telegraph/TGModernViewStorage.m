#import "TGModernViewStorage.h"

#import "TGModernView.h"

@interface TGModernViewStorage ()
{
    NSMutableDictionary *_viewsByIdentifier;
    NSMutableDictionary *_resurrectionViewsByIdentifier;
    NSMutableDictionary *_stateViewsByIdentifier;
    NSMutableDictionary *_resurrectionStateViewsByIdentifier;
    CFMutableDictionaryRef _viewStateKeys;
    CFMutableDictionaryRef _parkedViews;
    
    bool _resurrectionEnabled;
}

@end

@implementation TGModernViewStorage

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _viewsByIdentifier = [[NSMutableDictionary alloc] init];
        _resurrectionViewsByIdentifier = [[NSMutableDictionary alloc] init];
        _stateViewsByIdentifier = [[NSMutableDictionary alloc] init];
        _resurrectionStateViewsByIdentifier = [[NSMutableDictionary alloc] init];
        _viewStateKeys = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
        _parkedViews = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    }
    return self;
}

- (void)dealloc
{
    [self _releaseParkedViews];
    if (_viewStateKeys != NULL)
        CFRelease(_viewStateKeys);
    if (_parkedViews != NULL)
        CFRelease(_parkedViews);
}

- (void)_releaseParkedViews
{
    if (_parkedViews == NULL || CFDictionaryGetCount(_parkedViews) == 0)
        return;
    CFIndex count = CFDictionaryGetCount(_parkedViews);
    const void **keys = (const void **)malloc(sizeof(void *) * (size_t)count);
    const void **values = (const void **)malloc(sizeof(void *) * (size_t)count);
    if (keys != NULL && values != NULL)
    {
        CFDictionaryGetKeysAndValues(_parkedViews, keys, values);
        CFDictionaryRemoveAllValues(_parkedViews);
        for (CFIndex index = 0; index < count; index++)
        {
            UIView *view = (__bridge UIView *)keys[index];
            [view removeFromSuperview];
            view.hidden = values[index] != NULL;
        }
    }
    else
        CFDictionaryRemoveAllValues(_parkedViews);
    free(keys);
    free(values);
}

- (void)_unparkView:(UIView *)view
{
    const void *wasHidden = NULL;
    if (CFDictionaryGetValueIfPresent(_parkedViews, (__bridge const void *)view, &wasHidden))
    {
        CFDictionaryRemoveValue(_parkedViews, (__bridge const void *)view);
        view.hidden = wasHidden != NULL;
    }
}

- (void)_addView:(UIView<TGModernView> *)view identifier:(NSString *)identifier toQueues:(NSMutableDictionary *)queues stateQueues:(NSMutableDictionary *)stateQueues
{
    NSMutableArray *enqueuedViews = [queues objectForKey:identifier];
    if (enqueuedViews == nil)
    {
        enqueuedViews = [[NSMutableArray alloc] init];
        [queues setObject:enqueuedViews forKey:identifier];
    }
    [enqueuedViews addObject:view];
    
    NSString *stateKey = [view viewStateIdentifier];
    if (stateKey != nil)
    {
        NSMutableDictionary *stateViews = [stateQueues objectForKey:identifier];
        if (stateViews == nil)
        {
            stateViews = [[NSMutableDictionary alloc] init];
            [stateQueues setObject:stateViews forKey:identifier];
        }
        NSMutableArray *matchingViews = [stateViews objectForKey:stateKey];
        if (matchingViews == nil)
        {
            matchingViews = [[NSMutableArray alloc] init];
            [stateViews setObject:matchingViews forKey:stateKey];
        }
        [matchingViews addObject:view];
        CFDictionarySetValue(_viewStateKeys, (__bridge const void *)view, (__bridge const void *)stateKey);
    }
    else
        CFDictionaryRemoveValue(_viewStateKeys, (__bridge const void *)view);
}

- (void)_forgetStateOfView:(UIView<TGModernView> *)view identifier:(NSString *)identifier stateQueues:(NSMutableDictionary *)stateQueues
{
    NSString *stateKey = (__bridge NSString *)CFDictionaryGetValue(_viewStateKeys, (__bridge const void *)view);
    if (stateKey == nil)
        return;
    
    NSMutableDictionary *stateViews = [stateQueues objectForKey:identifier];
    NSMutableArray *matchingViews = [stateViews objectForKey:stateKey];
    if (matchingViews != nil)
    {
        [matchingViews removeObjectIdenticalTo:view];
        if (matchingViews.count == 0)
            [stateViews removeObjectForKey:stateKey];
    }
    CFDictionaryRemoveValue(_viewStateKeys, (__bridge const void *)view);
}

- (UIView<TGModernView> *)_dequeueViewFromQueues:(NSMutableDictionary *)queues stateQueues:(NSMutableDictionary *)stateQueues withIdentifier:(NSString *)identifier viewStateIdentifier:(NSString *)viewStateIdentifier preferredSuperview:(UIView *)preferredSuperview
{
    NSMutableArray *enqueuedViews = [queues objectForKey:identifier];
    if (enqueuedViews.count == 0)
        return nil;
    
    UIView<TGModernView> *view = nil;
    NSMutableArray *matchingViews = nil;
    if (viewStateIdentifier != nil)
        matchingViews = [[stateQueues objectForKey:identifier] objectForKey:viewStateIdentifier];
    
    if (preferredSuperview != nil)
    {
        for (UIView<TGModernView> *candidate in matchingViews)
        {
            if (candidate.superview == preferredSuperview)
            {
                view = candidate;
                break;
            }
        }
        if (view == nil && matchingViews.count == 0)
        {
            for (NSInteger index = (NSInteger)enqueuedViews.count - 1; index >= 0; index--)
            {
                UIView<TGModernView> *candidate = enqueuedViews[(NSUInteger)index];
                if (candidate.superview == preferredSuperview)
                {
                    view = candidate;
                    break;
                }
            }
        }
    }
    
    if (view == nil && matchingViews.count != 0)
        view = [matchingViews objectAtIndex:0];
    
    if (view == nil)
        view = [enqueuedViews lastObject];
    
    [self _forgetStateOfView:view identifier:identifier stateQueues:stateQueues];
    [enqueuedViews removeObjectIdenticalTo:view];
    [self _unparkView:view];
    return view;
}

- (UIView<TGModernView> *)dequeueViewWithIdentifier:(NSString *)identifier viewStateIdentifier:(NSString *)viewStateIdentifier
{
    return [self dequeueViewWithIdentifier:identifier viewStateIdentifier:viewStateIdentifier preferredSuperview:nil];
}

- (UIView<TGModernView> *)dequeueViewWithIdentifier:(NSString *)identifier viewStateIdentifier:(NSString *)viewStateIdentifier preferredSuperview:(UIView *)preferredSuperview
{
    UIView<TGModernView> *view = nil;
    if (_resurrectionViewsByIdentifier.count != 0)
        view = [self _dequeueViewFromQueues:_resurrectionViewsByIdentifier stateQueues:_resurrectionStateViewsByIdentifier withIdentifier:identifier viewStateIdentifier:viewStateIdentifier preferredSuperview:preferredSuperview];
    if (view == nil)
        view = [self _dequeueViewFromQueues:_viewsByIdentifier stateQueues:_stateViewsByIdentifier withIdentifier:identifier viewStateIdentifier:viewStateIdentifier preferredSuperview:preferredSuperview];
    
    return view;
}

- (void)parkView:(UIView<TGModernView> *)view
{
    if (view == nil)
        return;
    if (view.superview != nil && view.window != nil && [view viewIdentifier] != nil)
    {
        if (!CFDictionaryContainsKey(_parkedViews, (__bridge const void *)view))
            CFDictionarySetValue(_parkedViews, (__bridge const void *)view, view.hidden ? (const void *)1 : NULL);
        view.hidden = true;
    }
    else
    {
        [self _unparkView:view];
        [view removeFromSuperview];
    }
    [self enqueueView:view];
}

- (void)enqueueView:(UIView<TGModernView> *)view
{
    NSString *identifier = [view viewIdentifier];
    if (identifier == nil)
    {
        TGLog(@"***** enqueueView: view doesn't have valid identifier");
        return;
    }
    
    if (!_resurrectionEnabled)
        [view willBecomeRecycled];
    
    if (_resurrectionEnabled)
        [self _addView:view identifier:identifier toQueues:_resurrectionViewsByIdentifier stateQueues:_resurrectionStateViewsByIdentifier];
    else
        [self _addView:view identifier:identifier toQueues:_viewsByIdentifier stateQueues:_stateViewsByIdentifier];
}

- (void)allowResurrectionForOperations:(dispatch_block_t)block
{
    _resurrectionEnabled = true;
    
    block();
    
    _resurrectionEnabled = false;
    
    [_resurrectionViewsByIdentifier enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, NSArray *views, __unused BOOL *stop)
    {
        for (UIView<TGModernView> *view in views)
        {
            [self _forgetStateOfView:view identifier:identifier stateQueues:_resurrectionStateViewsByIdentifier];
            [view willBecomeRecycled];
            [self _addView:view identifier:identifier toQueues:_viewsByIdentifier stateQueues:_stateViewsByIdentifier];
        }
    }];
    
    [_resurrectionViewsByIdentifier removeAllObjects];
    [_resurrectionStateViewsByIdentifier removeAllObjects];
}

- (void)clear
{
    [self _releaseParkedViews];
    [_viewsByIdentifier removeAllObjects];
    [_resurrectionViewsByIdentifier removeAllObjects];
    [_stateViewsByIdentifier removeAllObjects];
    [_resurrectionStateViewsByIdentifier removeAllObjects];
    CFDictionaryRemoveAllValues(_viewStateKeys);
    _resurrectionEnabled = false;
}

@end
