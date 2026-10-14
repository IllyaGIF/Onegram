#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

FOUNDATION_EXPORT void OGPlatformDispatchOnMainThread(void (^block)(void));
FOUNDATION_EXPORT void OGPlatformDispatchAfterCurrentMainRunLoop(void (^block)(void));
FOUNDATION_EXPORT void OGPlatformDispatchOnMainThreadAfter(NSTimeInterval delay, void (^block)(void));
FOUNDATION_EXPORT dispatch_queue_t OGPlatformBackgroundQueue(void);
FOUNDATION_EXPORT dispatch_queue_t OGPlatformBackgroundLowQueue(void);
FOUNDATION_EXPORT bool OGPlatformUsesConstrainedBackgroundExecution(void);
FOUNDATION_EXPORT void OGPlatformDiagnosticLog(NSString *format, ...);
