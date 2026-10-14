#import "OGPlatformDispatch.h"
#import "OGPlatformVersion.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

void OGPlatformDispatchOnMainThread(void (^block)(void))
{
    if (block == nil)
        return;
    if ([NSThread isMainThread])
    {
        block();
        return;
    }
    if (OGPlatformMajorVersion() <= 3)
    {
        CFRunLoopRef runLoop = CFRunLoopGetMain();
        CFRunLoopPerformBlock(runLoop, kCFRunLoopCommonModes, block);
        CFRunLoopWakeUp(runLoop);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), block);
}

void OGPlatformDispatchAfterCurrentMainRunLoop(void (^block)(void))
{
    if (block == nil)
        return;
    if (OGPlatformMajorVersion() <= 3)
    {
        CFRunLoopRef runLoop = CFRunLoopGetMain();
        CFRunLoopPerformBlock(runLoop, kCFRunLoopCommonModes, block);
        CFRunLoopWakeUp(runLoop);
        return;
    }
    dispatch_async(dispatch_get_main_queue(), block);
}


bool OGPlatformUsesConstrainedBackgroundExecution(void)
{
    return OGPlatformMajorVersion() <= 3;
}

dispatch_queue_t OGPlatformBackgroundQueue(void)
{
    if (!OGPlatformUsesConstrainedBackgroundExecution())
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.legacy-background", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

dispatch_queue_t OGPlatformBackgroundLowQueue(void)
{
    if (!OGPlatformUsesConstrainedBackgroundExecution())
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.legacy-background-low", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    });
    return queue;
}

void OGPlatformDispatchOnMainThreadAfter(NSTimeInterval delay, void (^block)(void))
{
    if (block == nil)
        return;
    if (delay <= 0.0)
    {
        OGPlatformDispatchOnMainThread(block);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        @autoreleasepool
        {
            OGPlatformDispatchOnMainThread(block);
        }
    });
}

static dispatch_queue_t OGPlatformDiagnosticLogQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("org.onegram.diagnostic.syslog", NULL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    });
    return queue;
}

void OGPlatformDiagnosticLog(NSString *format, ...)
{
    if (format == nil)
        return;
    va_list arguments;
    va_start(arguments, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    dispatch_async(OGPlatformDiagnosticLogQueue(), ^
    {
        NSLog(@"%@", message);
    });
}
