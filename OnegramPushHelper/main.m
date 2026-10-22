#import <Foundation/Foundation.h>
#import <signal.h>

#import "OGPushDaemon.h"

int main(__unused int argc, __unused char *argv[])
{
    @autoreleasepool
    {
        OGPushDaemon *daemon = [[OGPushDaemon alloc] init];
        if (![daemon start])
            return 0;

        signal(SIGTERM, SIG_IGN);
        dispatch_source_t terminationSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(terminationSource, ^
        {
            [daemon stop];
            exit(0);
        });
        dispatch_resume(terminationSource);

        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
    return 1;
}
