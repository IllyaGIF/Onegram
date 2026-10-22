#import <dispatch/dispatch.h>

#undef dispatch_queue_set_specific
#undef dispatch_get_specific

void TGDispatchQueueSetSpecificCompat(dispatch_queue_t queue, const void *key, void *context, dispatch_function_t destructor)
{
    dispatch_queue_set_specific(queue, key, context, destructor);
}

void *TGDispatchGetSpecificCompat(const void *key)
{
    return dispatch_get_specific(key);
}
