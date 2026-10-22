#import "OnegramIOS3Compatibility.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>
#include <regex.h>
#include <mach/mach.h>
#include <pthread.h>

static void OnegramIOS3InstallFallbackMethodsIntoClass(Class targetClass)
{
    static const char prefix[] = "onegramIOS3Fallback_";
    size_t prefixLength = sizeof(prefix) - 1;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(targetClass, &count);
    for (unsigned int index = 0; index < count; index++)
    {
        const char *name = sel_getName(method_getName(methods[index]));
        if (strncmp(name, prefix, prefixLength) != 0)
            continue;
        SEL selector = sel_registerName(name + prefixLength);
        if (class_getInstanceMethod(targetClass, selector) != NULL)
            continue;
        class_addMethod(targetClass, selector, method_getImplementation(methods[index]), method_getTypeEncoding(methods[index]));
    }
    free(methods);
}

static void OnegramIOS3InstallFallbackMethods(Class targetClass)
{
    OnegramIOS3InstallFallbackMethodsIntoClass(targetClass);
    OnegramIOS3InstallFallbackMethodsIntoClass(object_getClass(targetClass));
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000

static char OnegramIOS3WindowRootViewControllerKey;
static char OnegramIOS3OperationThreadPriorityKey;
static UIApplicationState OnegramIOS3ApplicationState = UIApplicationStateInactive;

@implementation UIWindow (OnegramIOS3RootViewControllerCompatibilityFallback)

- (UIViewController *)onegramIOS3Fallback_rootViewController
{
    return objc_getAssociatedObject(self, &OnegramIOS3WindowRootViewControllerKey);
}

- (void)onegramIOS3Fallback_setRootViewController:(UIViewController *)rootViewController
{
    UIViewController *currentController = objc_getAssociatedObject(self, &OnegramIOS3WindowRootViewControllerKey);
    if (currentController == rootViewController)
        return;

    if (currentController != nil && currentController.view.superview == self)
        [currentController.view removeFromSuperview];

    objc_setAssociatedObject(self, &OnegramIOS3WindowRootViewControllerKey, rootViewController, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (rootViewController != nil)
    {
        UIView *view = rootViewController.view;
        view.frame = self.bounds;
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:view];
    }
}

@end

@implementation UIViewController (OnegramIOS3LayoutLifecycleCompatibilityFallback)

- (void)onegramIOS3Fallback_viewWillLayoutSubviews
{
}

- (void)onegramIOS3Fallback_viewDidLayoutSubviews
{
}

@end

@interface OnegramIOS3BarButtonItemsToolbar : UIToolbar
@end

@implementation OnegramIOS3BarButtonItemsToolbar

- (void)drawRect:(CGRect)rect
{
}

@end

static CGFloat OnegramIOS3BarButtonItemWidth(UIBarButtonItem *item)
{
    if (item.customView != nil)
    {
        CGSize size = item.customView.bounds.size;
        if (size.width < 1.0f)
            size = [item.customView sizeThatFits:CGSizeMake(160.0f, 44.0f)];
        if (size.width > 0.0f)
            return size.width;
    }

    if (item.width > 0.0f)
        return item.width;

    if (item.title.length != 0)
    {
        CGSize size = [item.title sizeWithFont:[UIFont boldSystemFontOfSize:12.0f]];
        return MAX(30.0f, size.width + 20.0f);
    }

    if (item.image != nil)
        return MAX(30.0f, item.image.size.width + 20.0f);

    return 32.0f;
}

static UIBarButtonItem *OnegramIOS3CombinedRightBarButtonItem(NSArray *items)
{
    NSUInteger count = items.count;
    if (count == 0)
        return nil;
    if (count == 1)
        return [items objectAtIndex:0];

    NSMutableArray *toolbarItems = [[NSMutableArray alloc] initWithCapacity:count];
    CGFloat width = 0.0f;
    for (NSInteger index = (NSInteger)count - 1; index >= 0; index--)
    {
        UIBarButtonItem *item = [items objectAtIndex:(NSUInteger)index];
        [toolbarItems addObject:item];
        width += OnegramIOS3BarButtonItemWidth(item);
    }
    width += (count - 1) * 4.0f;

    OnegramIOS3BarButtonItemsToolbar *toolbar = [[OnegramIOS3BarButtonItemsToolbar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, 44.0f)];
    toolbar.opaque = NO;
    toolbar.backgroundColor = [UIColor clearColor];
    [toolbar setItems:toolbarItems animated:NO];
    [toolbarItems release];

    UIBarButtonItem *result = [[[UIBarButtonItem alloc] initWithCustomView:toolbar] autorelease];
    [toolbar release];
    return result;
}

@implementation UINavigationItem (OnegramIOS3ModernBarButtonCompatibilityFallback)

- (void)onegramIOS3Fallback_setRightBarButtonItems:(NSArray *)items animated:(BOOL)animated
{
    [self setRightBarButtonItem:OnegramIOS3CombinedRightBarButtonItem(items) animated:animated];
}

@end

@implementation UIApplication (OnegramIOS3ApplicationStateCompatibilityFallback)

+ (void)load
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(onegramIOS3DidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(onegramIOS3WillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

+ (void)onegramIOS3DidBecomeActive:(NSNotification *)notification
{
    OnegramIOS3ApplicationState = UIApplicationStateActive;
}

+ (void)onegramIOS3WillResignActive:(NSNotification *)notification
{
    OnegramIOS3ApplicationState = UIApplicationStateInactive;
}

- (UIApplicationState)onegramIOS3Fallback_applicationState
{
    return OnegramIOS3ApplicationState;
}

@end

@interface OnegramIOS3MainOperationQueue : NSOperationQueue
@end

@implementation OnegramIOS3MainOperationQueue

- (void)addOperation:(NSOperation *)operation
{
    if (operation == nil)
        return;
    if ([NSThread isMainThread])
        [operation start];
    else
        [operation performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
}

- (void)addOperations:(NSArray *)operations waitUntilFinished:(BOOL)wait
{
    for (NSOperation *operation in operations)
    {
        if (operation == nil)
            continue;
        if ([NSThread isMainThread])
            [operation start];
        else
            [operation performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:wait];
    }
}

@end

@implementation NSOperationQueue (OnegramIOS3MainQueueCompatibilityFallback)

+ (NSOperationQueue *)onegramIOS3Fallback_mainQueue
{
    static OnegramIOS3MainOperationQueue *queue = nil;
    @synchronized(self)
    {
        if (queue == nil)
            queue = [[OnegramIOS3MainOperationQueue alloc] init];
    }
    return queue;
}

@end

@implementation NSOperation (OnegramIOS3ThreadPriorityCompatibilityFallback)

- (double)onegramIOS3Fallback_threadPriority
{
    NSNumber *value = objc_getAssociatedObject(self, &OnegramIOS3OperationThreadPriorityKey);
    return value == nil ? 0.5 : [value doubleValue];
}

- (void)onegramIOS3Fallback_setThreadPriority:(double)threadPriority
{
    double value = MIN(1.0, MAX(0.0, threadPriority));
    objc_setAssociatedObject(self, &OnegramIOS3OperationThreadPriorityKey, [NSNumber numberWithDouble:value], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation NSBlockOperation

+ (instancetype)blockOperationWithBlock:(void (^)(void))block
{
    NSBlockOperation *operation = [[[self alloc] init] autorelease];
    [operation addExecutionBlock:block];
    return operation;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _onegramExecutionBlocks = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [_onegramExecutionBlocks release];
    [super dealloc];
}

- (void)addExecutionBlock:(void (^)(void))block
{
    if (block == nil)
        return;
    id copiedBlock = [block copy];
    @synchronized(self)
    {
        if (!_onegramStarted && ![self isExecuting] && ![self isFinished])
            [_onegramExecutionBlocks addObject:copiedBlock];
    }
    [copiedBlock release];
}

- (void)start
{
    @synchronized(self)
    {
        if (_onegramStarted || [self isExecuting] || [self isFinished])
            return;
        _onegramStarted = YES;
    }
    [super start];
}

- (NSArray *)executionBlocks
{
    @synchronized(self)
    {
        return [[_onegramExecutionBlocks copy] autorelease];
    }
}

- (void)main
{
    double previousPriority = [NSThread threadPriority];
    [NSThread setThreadPriority:self.threadPriority];
    NSArray *blocks = [self executionBlocks];
    for (id value in blocks)
    {
        if ([self isCancelled])
            break;
        void (^block)(void) = value;
        block();
    }
    [NSThread setThreadPriority:previousPriority];
}

@end

@interface OnegramIOS3URLConnectionDelivery : NSObject
{
    void (^_onegramHandler)(NSURLResponse *, NSData *, NSError *);
    NSURLResponse *_onegramResponse;
    NSData *_onegramData;
    NSError *_onegramError;
}
- (instancetype)initWithHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error;
- (void)invoke;
@end

@implementation OnegramIOS3URLConnectionDelivery

- (instancetype)initWithHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error
{
    self = [super init];
    if (self != nil)
    {
        _onegramHandler = [handler copy];
        _onegramResponse = [response retain];
        _onegramData = [data retain];
        _onegramError = [error retain];
    }
    return self;
}

- (void)dealloc
{
    [_onegramHandler release];
    [_onegramResponse release];
    [_onegramData release];
    [_onegramError release];
    [super dealloc];
}

- (void)invoke
{
    if (_onegramHandler != nil)
        _onegramHandler(_onegramResponse, _onegramData, _onegramError);
}

@end

@interface OnegramIOS3URLConnectionRequest : NSObject
{
    NSURLRequest *_onegramRequest;
    NSOperationQueue *_onegramQueue;
    void (^_onegramHandler)(NSURLResponse *, NSData *, NSError *);
}
- (instancetype)initWithRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue handler:(void (^)(NSURLResponse *, NSData *, NSError *))handler;
- (void)startAndRelease;
@end

@implementation OnegramIOS3URLConnectionRequest

- (instancetype)initWithRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue handler:(void (^)(NSURLResponse *, NSData *, NSError *))handler
{
    self = [super init];
    if (self != nil)
    {
        _onegramRequest = [request copy];
        _onegramQueue = [queue retain];
        _onegramHandler = [handler copy];
    }
    return self;
}

- (void)dealloc
{
    [_onegramRequest release];
    [_onegramQueue release];
    [_onegramHandler release];
    [super dealloc];
}

- (void)startAndRelease
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:_onegramRequest returningResponse:&response error:&error];
    if (_onegramHandler != nil)
    {
        OnegramIOS3URLConnectionDelivery *delivery = [[OnegramIOS3URLConnectionDelivery alloc] initWithHandler:_onegramHandler response:response data:data error:error];
        if (_onegramQueue != nil)
        {
            NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:delivery selector:@selector(invoke) object:nil];
            [_onegramQueue addOperation:operation];
            [operation release];
        }
        else
            [delivery invoke];
        [delivery release];
    }
    [self release];
    [pool drain];
}

@end

@implementation NSURLConnection (OnegramIOS3AsyncCompatibilityFallback)

+ (void)onegramIOS3Fallback_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler
{
    if (request == nil)
        return;
    OnegramIOS3URLConnectionRequest *operation = [[OnegramIOS3URLConnectionRequest alloc] initWithRequest:request queue:queue handler:handler];
    [NSThread detachNewThreadSelector:@selector(startAndRelease) toTarget:operation withObject:nil];
}

@end

@implementation NSUUID

+ (NSUUID *)UUID
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef string = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    NSUUID *result = [[[self alloc] initWithUUIDString:(NSString *)string] autorelease];
    if (string != NULL)
        CFRelease(string);
    if (uuid != NULL)
        CFRelease(uuid);
    return result;
}

- (instancetype)initWithUUIDString:(NSString *)string
{
    self = [super init];
    if (self != nil)
    {
        if (string == nil)
        {
            [self release];
            return nil;
        }
        CFUUIDRef uuid = CFUUIDCreateFromString(kCFAllocatorDefault, (CFStringRef)string);
        if (uuid == NULL)
        {
            [self release];
            return nil;
        }
        CFStringRef normalized = CFUUIDCreateString(kCFAllocatorDefault, uuid);
        _onegramUUIDString = [(NSString *)normalized copy];
        if (normalized != NULL)
            CFRelease(normalized);
        CFRelease(uuid);
    }
    return self;
}

- (void)dealloc
{
    [_onegramUUIDString release];
    [super dealloc];
}

- (NSString *)UUIDString
{
    return _onegramUUIDString;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSUInteger)hash
{
    return [_onegramUUIDString hash];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSUUID class]])
        return NO;
    return [_onegramUUIDString isEqualToString:[object UUIDString]];
}

- (NSString *)description
{
    return _onegramUUIDString;
}

@end

@interface OnegramIOS3NotificationDelivery : NSObject
{
    void (^_block)(NSNotification *);
    NSNotification *_notification;
}
- (instancetype)initWithBlock:(void (^)(NSNotification *))block notification:(NSNotification *)notification;
- (void)invoke;
@end

@implementation OnegramIOS3NotificationDelivery

- (instancetype)initWithBlock:(void (^)(NSNotification *))block notification:(NSNotification *)notification
{
    self = [super init];
    if (self != nil)
    {
        _block = [block copy];
        _notification = [notification retain];
    }
    return self;
}

- (void)dealloc
{
    [_block release];
    [_notification release];
    [super dealloc];
}

- (void)invoke
{
    if (_block != nil)
        _block(_notification);
}

@end

@interface OnegramIOS3NotificationBlockObserver : NSObject
{
    NSNotificationCenter *_center;
    NSOperationQueue *_queue;
    void (^_block)(NSNotification *);
}
- (instancetype)initWithCenter:(NSNotificationCenter *)center name:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue block:(void (^)(NSNotification *))block;
- (void)invalidate;
@end

@implementation OnegramIOS3NotificationBlockObserver

- (instancetype)initWithCenter:(NSNotificationCenter *)center name:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue block:(void (^)(NSNotification *))block
{
    self = [super init];
    if (self != nil)
    {
        _center = center;
        _queue = [queue retain];
        _block = [block copy];
        [_center addObserver:self selector:@selector(receiveNotification:) name:name object:object];
    }
    return self;
}

- (void)dealloc
{
    [_queue release];
    [_block release];
    [super dealloc];
}

- (void)receiveNotification:(NSNotification *)notification
{
    if (_block == nil)
        return;

    if (_queue == nil)
    {
        void (^block)(NSNotification *) = [_block copy];
        if (block != nil)
            block(notification);
        [block release];
    }
    else
    {
        OnegramIOS3NotificationDelivery *delivery = [[OnegramIOS3NotificationDelivery alloc] initWithBlock:_block notification:notification];
        NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:delivery selector:@selector(invoke) object:nil];
        [_queue addOperation:operation];
        [operation release];
        [delivery release];
    }
}

- (void)invalidate
{
    _center = nil;
    [_queue release];
    _queue = nil;
    [_block release];
    _block = nil;
}

@end

static char OnegramIOS3NotificationBlockObserversKey;
static void (*OnegramIOS3OriginalRemoveObserver)(id, SEL, id) = NULL;
static void (*OnegramIOS3OriginalRemoveObserverNameObject)(id, SEL, id, NSString *, id) = NULL;

static void OnegramIOS3StoreNotificationBlockObserver(NSNotificationCenter *center, OnegramIOS3NotificationBlockObserver *observer)
{
    @synchronized(center)
    {
        NSMutableArray *observers = objc_getAssociatedObject(center, &OnegramIOS3NotificationBlockObserversKey);
        if (observers == nil)
        {
            observers = [NSMutableArray array];
            objc_setAssociatedObject(center, &OnegramIOS3NotificationBlockObserversKey, observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [observers addObject:observer];
    }
}

static void OnegramIOS3ForgetNotificationBlockObserver(NSNotificationCenter *center, OnegramIOS3NotificationBlockObserver *observer)
{
    @synchronized(center)
    {
        NSMutableArray *observers = objc_getAssociatedObject(center, &OnegramIOS3NotificationBlockObserversKey);
        [observers removeObjectIdenticalTo:observer];
        if ([observers count] == 0)
            objc_setAssociatedObject(center, &OnegramIOS3NotificationBlockObserversKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static id OnegramIOS3AddNotificationBlockObserver(NSNotificationCenter *center, SEL __unused selector, NSString *name, id object, NSOperationQueue *queue, void (^block)(NSNotification *))
{
    if (block == nil)
        return nil;

    OnegramIOS3NotificationBlockObserver *observer = [[[OnegramIOS3NotificationBlockObserver alloc] initWithCenter:center name:name object:object queue:queue block:block] autorelease];
    OnegramIOS3StoreNotificationBlockObserver(center, observer);
    return observer;
}

static void OnegramIOS3RemoveNotificationObserver(NSNotificationCenter *center, SEL selector, id observer)
{
    OnegramIOS3NotificationBlockObserver *blockObserver = [observer isKindOfClass:[OnegramIOS3NotificationBlockObserver class]] ? [observer retain] : nil;
    if (OnegramIOS3OriginalRemoveObserver != NULL)
        OnegramIOS3OriginalRemoveObserver(center, selector, observer);
    if (blockObserver != nil)
    {
        [blockObserver invalidate];
        OnegramIOS3ForgetNotificationBlockObserver(center, blockObserver);
        [blockObserver release];
    }
}

static void OnegramIOS3RemoveNotificationObserverNameObject(NSNotificationCenter *center, SEL selector, id observer, NSString *name, id object)
{
    OnegramIOS3NotificationBlockObserver *blockObserver = [observer isKindOfClass:[OnegramIOS3NotificationBlockObserver class]] ? [observer retain] : nil;
    if (OnegramIOS3OriginalRemoveObserverNameObject != NULL)
        OnegramIOS3OriginalRemoveObserverNameObject(center, selector, observer, name, object);
    if (blockObserver != nil)
    {
        [blockObserver invalidate];
        OnegramIOS3ForgetNotificationBlockObserver(center, blockObserver);
        [blockObserver release];
    }
}

@interface OnegramIOS3NotificationCenterCompatibilityInstaller : NSObject
@end

@implementation OnegramIOS3NotificationCenterCompatibilityInstaller

+ (void)load
{
    Class notificationCenterClass = [NSNotificationCenter class];
    SEL blockObserverSelector = @selector(addObserverForName:object:queue:usingBlock:);
    if ([notificationCenterClass instancesRespondToSelector:blockObserverSelector])
        return;

    class_addMethod(notificationCenterClass, blockObserverSelector, (IMP)OnegramIOS3AddNotificationBlockObserver, "@@:@@@@");

    Method removeObserverMethod = class_getInstanceMethod(notificationCenterClass, @selector(removeObserver:));
    if (removeObserverMethod != NULL)
    {
        OnegramIOS3OriginalRemoveObserver = (void (*)(id, SEL, id))method_getImplementation(removeObserverMethod);
        class_replaceMethod(notificationCenterClass, @selector(removeObserver:), (IMP)OnegramIOS3RemoveNotificationObserver, method_getTypeEncoding(removeObserverMethod));
    }

    Method removeObserverNameObjectMethod = class_getInstanceMethod(notificationCenterClass, @selector(removeObserver:name:object:));
    if (removeObserverNameObjectMethod != NULL)
    {
        OnegramIOS3OriginalRemoveObserverNameObject = (void (*)(id, SEL, id, NSString *, id))method_getImplementation(removeObserverNameObjectMethod);
        class_replaceMethod(notificationCenterClass, @selector(removeObserver:name:object:), (IMP)OnegramIOS3RemoveNotificationObserverNameObject, method_getTypeEncoding(removeObserverNameObjectMethod));
    }
}

@end

typedef struct
{
    void (^block)(void);
    CFRunLoopSourceRef source;
} OnegramIOS3RunLoopBlockContext;

static void OnegramIOS3RunLoopBlockRelease(const void *info)
{
    OnegramIOS3RunLoopBlockContext *context = (OnegramIOS3RunLoopBlockContext *)info;
    [(id)context->block release];
    free(context);
}

static void OnegramIOS3RunLoopBlockPerform(void *info)
{
    OnegramIOS3RunLoopBlockContext *context = (OnegramIOS3RunLoopBlockContext *)info;
    if (context->block != nil)
        context->block();
    if (context->source != NULL)
        CFRunLoopSourceInvalidate(context->source);
}

void CFRunLoopPerformBlock(CFRunLoopRef runLoop, CFTypeRef mode, void (^block)(void))
{
    if (runLoop == NULL || mode == NULL || block == nil)
        return;

    OnegramIOS3RunLoopBlockContext *context = calloc(1, sizeof(OnegramIOS3RunLoopBlockContext));
    context->block = [block copy];

    CFRunLoopSourceContext sourceContext = {0};
    sourceContext.info = context;
    sourceContext.release = OnegramIOS3RunLoopBlockRelease;
    sourceContext.perform = OnegramIOS3RunLoopBlockPerform;

    CFRunLoopSourceRef source = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    if (source == NULL)
    {
        [(id)context->block release];
        free(context);
        return;
    }

    context->source = source;
    CFRunLoopAddSource(runLoop, source, mode);
    CFRunLoopSourceSignal(source);
    CFRunLoopWakeUp(runLoop);
    CFRelease(source);
}

extern mach_port_t _dispatch_get_main_queue_port_4CF(void);
extern void _dispatch_main_queue_callback_4CF(mach_msg_header_t *message);

static CFMachPortRef OnegramIOS3DispatchMainQueuePort = NULL;

static void OnegramIOS3DispatchMainQueuePortCallback(CFMachPortRef port, void *message, CFIndex size, void *info)
{
    (void)port;
    (void)size;
    (void)info;
    _dispatch_main_queue_callback_4CF((mach_msg_header_t *)message);
}

@interface OnegramIOS3DispatchMainQueueInstaller : NSObject
@end

@implementation OnegramIOS3DispatchMainQueueInstaller

+ (void)load
{
    if (OnegramIOS3DispatchMainQueuePort != NULL)
        return;

    mach_port_t port = _dispatch_get_main_queue_port_4CF();
    if (port == MACH_PORT_NULL)
        return;

    CFMachPortContext context = {0, NULL, NULL, NULL, NULL};
    CFMachPortRef machPort = CFMachPortCreateWithPort(kCFAllocatorDefault, port, OnegramIOS3DispatchMainQueuePortCallback, &context, NULL);
    if (machPort == NULL)
        return;

    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, machPort, 0);
    if (source == NULL)
    {
        CFRelease(machPort);
        return;
    }

    OnegramIOS3DispatchMainQueuePort = machPort;
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CFRelease(source);
}

@end

@implementation CLPlacemark

- (instancetype)initWithLocation:(CLLocation *)location addressDictionary:(NSDictionary *)addressDictionary
{
    self = [super init];
    if (self != nil)
    {
        _location = [location retain];
        _addressDictionary = [addressDictionary copy];
    }
    return self;
}

- (void)dealloc
{
    [_location release];
    [_addressDictionary release];
    [super dealloc];
}

- (CLLocation *)location
{
    return _location;
}

- (NSDictionary *)addressDictionary
{
    return _addressDictionary;
}

- (NSString *)locality
{
    return [_addressDictionary objectForKey:@"City"];
}

@end

static void OnegramIOS3RoundedRectPath(CGMutablePathRef path, CGRect rect, UIRectCorner corners, CGSize radii)
{
    CGFloat rx = MIN(fabs(radii.width), fabs(rect.size.width) * 0.5f);
    CGFloat ry = MIN(fabs(radii.height), fabs(rect.size.height) * 0.5f);
    CGFloat k = 0.5522847498307936f;
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);

    CGPathMoveToPoint(path, NULL, minX + ((corners & UIRectCornerTopLeft) ? rx : 0.0f), minY);

    if (corners & UIRectCornerTopRight)
    {
        CGPathAddLineToPoint(path, NULL, maxX - rx, minY);
        CGPathAddCurveToPoint(path, NULL, maxX - rx + rx * k, minY, maxX, minY + ry - ry * k, maxX, minY + ry);
    }
    else
        CGPathAddLineToPoint(path, NULL, maxX, minY);

    if (corners & UIRectCornerBottomRight)
    {
        CGPathAddLineToPoint(path, NULL, maxX, maxY - ry);
        CGPathAddCurveToPoint(path, NULL, maxX, maxY - ry + ry * k, maxX - rx + rx * k, maxY, maxX - rx, maxY);
    }
    else
        CGPathAddLineToPoint(path, NULL, maxX, maxY);

    if (corners & UIRectCornerBottomLeft)
    {
        CGPathAddLineToPoint(path, NULL, minX + rx, maxY);
        CGPathAddCurveToPoint(path, NULL, minX + rx - rx * k, maxY, minX, maxY - ry + ry * k, minX, maxY - ry);
    }
    else
        CGPathAddLineToPoint(path, NULL, minX, maxY);

    if (corners & UIRectCornerTopLeft)
    {
        CGPathAddLineToPoint(path, NULL, minX, minY + ry);
        CGPathAddCurveToPoint(path, NULL, minX, minY + ry - ry * k, minX + rx - rx * k, minY, minX + rx, minY);
    }
    else
        CGPathAddLineToPoint(path, NULL, minX, minY);

    CGPathCloseSubpath(path);
}

@implementation UIBezierPath

+ (UIBezierPath *)bezierPath
{
    return [[[self alloc] init] autorelease];
}

+ (UIBezierPath *)bezierPathWithRect:(CGRect)rect
{
    UIBezierPath *path = [self bezierPath];
    CGPathAddRect(path->_onegramPath, NULL, rect);
    return path;
}

+ (UIBezierPath *)bezierPathWithOvalInRect:(CGRect)rect
{
    UIBezierPath *path = [self bezierPath];
    CGPathAddEllipseInRect(path->_onegramPath, NULL, rect);
    return path;
}

+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius
{
    return [self bezierPathWithRoundedRect:rect byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
}

+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii
{
    UIBezierPath *path = [self bezierPath];
    OnegramIOS3RoundedRectPath(path->_onegramPath, rect, corners, cornerRadii);
    return path;
}

+ (UIBezierPath *)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise
{
    UIBezierPath *path = [self bezierPath];
    CGPathAddArc(path->_onegramPath, NULL, center.x, center.y, radius, startAngle, endAngle, clockwise);
    return path;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _onegramPath = CGPathCreateMutable();
        _onegramLineWidth = 1.0f;
        _onegramLineCapStyle = kCGLineCapButt;
        _onegramLineJoinStyle = kCGLineJoinMiter;
    }
    return self;
}

- (void)dealloc
{
    if (_onegramPath != NULL)
        CGPathRelease(_onegramPath);
    [super dealloc];
}

- (CGPathRef)CGPath { return _onegramPath; }
- (CGFloat)lineWidth { return _onegramLineWidth; }
- (void)setLineWidth:(CGFloat)value { _onegramLineWidth = value; }
- (CGLineCap)lineCapStyle { return _onegramLineCapStyle; }
- (void)setLineCapStyle:(CGLineCap)value { _onegramLineCapStyle = value; }
- (CGLineJoin)lineJoinStyle { return _onegramLineJoinStyle; }
- (void)setLineJoinStyle:(CGLineJoin)value { _onegramLineJoinStyle = value; }
- (BOOL)usesEvenOddFillRule { return _onegramUsesEvenOddFillRule; }
- (void)setUsesEvenOddFillRule:(BOOL)value { _onegramUsesEvenOddFillRule = value; }

- (void)moveToPoint:(CGPoint)point
{
    CGPathMoveToPoint(_onegramPath, NULL, point.x, point.y);
}

- (void)addLineToPoint:(CGPoint)point
{
    CGPathAddLineToPoint(_onegramPath, NULL, point.x, point.y);
}

- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise
{
    CGPathAddArc(_onegramPath, NULL, center.x, center.y, radius, startAngle, endAngle, clockwise);
}

- (void)closePath
{
    CGPathCloseSubpath(_onegramPath);
}

- (void)appendPath:(UIBezierPath *)bezierPath
{
    if (bezierPath != nil)
        CGPathAddPath(_onegramPath, NULL, bezierPath.CGPath);
}

- (void)fill
{
    [self fillWithBlendMode:kCGBlendModeNormal alpha:1.0f];
}

- (void)fillWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, blendMode);
    CGContextSetAlpha(context, alpha);
    CGContextAddPath(context, _onegramPath);
    CGContextDrawPath(context, _onegramUsesEvenOddFillRule ? kCGPathEOFill : kCGPathFill);
    CGContextRestoreGState(context);
}

- (void)stroke
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;
    CGContextSaveGState(context);
    CGContextSetLineWidth(context, _onegramLineWidth);
    CGContextSetLineCap(context, _onegramLineCapStyle);
    CGContextSetLineJoin(context, _onegramLineJoinStyle);
    CGContextAddPath(context, _onegramPath);
    CGContextStrokePath(context);
    CGContextRestoreGState(context);
}

- (void)addClip
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;
    CGContextAddPath(context, _onegramPath);
    if (_onegramUsesEvenOddFillRule)
        CGContextEOClip(context);
    else
        CGContextClip(context);
}

@end

static NSInteger OnegramIOS3CompareArrayObjects(id lhs, id rhs, void *context)
{
    NSComparisonResult (^comparator)(id, id) = context;
    return comparator(lhs, rhs);
}

static NSInteger OnegramIOS3CompareStableArrayObjects(id lhs, id rhs, void *context)
{
    NSComparisonResult (^comparator)(id, id) = context;
    NSComparisonResult result = comparator([lhs objectAtIndex:0], [rhs objectAtIndex:0]);
    return result == NSOrderedSame ? [[lhs objectAtIndex:1] compare:[rhs objectAtIndex:1]] : result;
}

@implementation NSMutableArray (OnegramIOS3SortingCompatibilityFallback)

- (void)onegramIOS3Fallback_sortUsingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr
{
    [self sortWithOptions:0 usingComparator:cmptr];
}

- (void)onegramIOS3Fallback_sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr
{
    if (cmptr == nil || self.count < 2)
        return;

    if ((opts & NSSortStable) == 0)
    {
        [self sortUsingFunction:OnegramIOS3CompareArrayObjects context:cmptr];
        return;
    }

    NSMutableArray *indexed = [[NSMutableArray alloc] initWithCapacity:self.count];
    @try
    {
        NSUInteger index = 0;
        for (id object in self)
            [indexed addObject:[NSArray arrayWithObjects:object, [NSNumber numberWithUnsignedInteger:index++], nil]];
        [indexed sortUsingFunction:OnegramIOS3CompareStableArrayObjects context:cmptr];
        index = 0;
        for (NSArray *entry in indexed)
            [self replaceObjectAtIndex:index++ withObject:[entry objectAtIndex:0]];
    }
    @finally
    {
        [indexed release];
    }
}

@end


static BOOL OnegramIOS3TextCheckingWhitespace(unichar c)
{
    return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == 0x00a0;
}

static BOOL OnegramIOS3TextCheckingTokenBoundary(unichar c)
{
    return OnegramIOS3TextCheckingWhitespace(c) || c == '<' || c == '>' || c == '"' || c == 0x201c || c == 0x201d;
}

static BOOL OnegramIOS3TextCheckingLeadingDelimiter(unichar c)
{
    return c == '(' || c == '[' || c == '{' || c == '\'' || c == 0x2018 || c == 0x2019;
}

static BOOL OnegramIOS3TextCheckingTrailingDelimiter(unichar c)
{
    return c == '.' || c == ',' || c == '!' || c == '?' || c == ';' || c == ':' || c == '\'' || c == 0x2018 || c == 0x2019 || c == ']' || c == '}';
}

static BOOL OnegramIOS3TextCheckingASCIIAlpha(unichar c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static BOOL OnegramIOS3TextCheckingASCIIDigit(unichar c)
{
    return c >= '0' && c <= '9';
}

static BOOL OnegramIOS3TextCheckingSchemeCharacter(unichar c)
{
    return OnegramIOS3TextCheckingASCIIAlpha(c) || OnegramIOS3TextCheckingASCIIDigit(c) || c == '+' || c == '-' || c == '.';
}

static BOOL OnegramIOS3TextCheckingValidScheme(NSString *string, NSUInteger colon)
{
    if (colon == 0 || !OnegramIOS3TextCheckingASCIIAlpha([string characterAtIndex:0]))
        return NO;
    for (NSUInteger i = 1; i < colon; i++)
    {
        if (!OnegramIOS3TextCheckingSchemeCharacter([string characterAtIndex:i]))
            return NO;
    }
    return YES;
}

static BOOL OnegramIOS3TextCheckingValidIPv4(NSString *host)
{
    NSArray *parts = [host componentsSeparatedByString:@"."];
    if ([parts count] != 4)
        return NO;
    for (NSString *part in parts)
    {
        if ([part length] == 0 || [part length] > 3)
            return NO;
        NSInteger value = 0;
        for (NSUInteger i = 0; i < [part length]; i++)
        {
            unichar c = [part characterAtIndex:i];
            if (!OnegramIOS3TextCheckingASCIIDigit(c))
                return NO;
            value = value * 10 + (c - '0');
        }
        if (value > 255)
            return NO;
    }
    return YES;
}

static BOOL OnegramIOS3TextCheckingValidDomain(NSString *host)
{
    if ([host length] < 4 || [host hasPrefix:@"."] || [host hasSuffix:@"."])
        return NO;
    if (OnegramIOS3TextCheckingValidIPv4(host))
        return YES;

    NSRange lastDot = [host rangeOfString:@"." options:NSBackwardsSearch];
    if (lastDot.location == NSNotFound || lastDot.location == 0 || NSMaxRange(lastDot) >= [host length])
        return NO;

    NSString *tld = [host substringFromIndex:NSMaxRange(lastDot)];
    if ([tld hasPrefix:@"xn--"])
    {
        if ([tld length] <= 4)
            return NO;
    }
    else
    {
        if ([tld length] < 2 || [tld length] > 24)
            return NO;
        for (NSUInteger i = 0; i < [tld length]; i++)
        {
            if (!OnegramIOS3TextCheckingASCIIAlpha([tld characterAtIndex:i]))
                return NO;
        }
    }

    NSArray *labels = [host componentsSeparatedByString:@"."];
    for (NSString *label in labels)
    {
        if ([label length] == 0 || [label length] > 63 || [label hasPrefix:@"-"] || [label hasSuffix:@"-"])
            return NO;
        for (NSUInteger i = 0; i < [label length]; i++)
        {
            unichar c = [label characterAtIndex:i];
            if (!(OnegramIOS3TextCheckingASCIIAlpha(c) || OnegramIOS3TextCheckingASCIIDigit(c) || c == '-'))
                return NO;
        }
    }
    return YES;
}

static BOOL OnegramIOS3TextCheckingValidEmail(NSString *string)
{
    NSRange at = [string rangeOfString:@"@" options:NSBackwardsSearch];
    if (at.location == NSNotFound || at.location == 0 || NSMaxRange(at) >= [string length])
        return NO;
    if ([string rangeOfString:@"@" options:0 range:NSMakeRange(0, at.location)].location != NSNotFound)
        return NO;

    NSString *local = [string substringToIndex:at.location];
    NSString *host = [string substringFromIndex:NSMaxRange(at)];
    if ([local hasPrefix:@"."] || [local hasSuffix:@"."] || [local rangeOfString:@".."].location != NSNotFound)
        return NO;
    for (NSUInteger i = 0; i < [local length]; i++)
    {
        unichar c = [local characterAtIndex:i];
        if (!(OnegramIOS3TextCheckingASCIIAlpha(c) || OnegramIOS3TextCheckingASCIIDigit(c) || c == '.' || c == '_' || c == '%' || c == '+' || c == '-'))
            return NO;
    }
    return OnegramIOS3TextCheckingValidDomain(host);
}

static NSString *OnegramIOS3TextCheckingHostFromCandidate(NSString *candidate)
{
    NSUInteger end = [candidate length];
    for (NSUInteger i = 0; i < [candidate length]; i++)
    {
        unichar c = [candidate characterAtIndex:i];
        if (c == '/' || c == '?' || c == '#')
        {
            end = i;
            break;
        }
    }
    if (end == 0)
        return nil;
    NSString *hostPort = [candidate substringToIndex:end];
    NSRange colon = [hostPort rangeOfString:@":" options:NSBackwardsSearch];
    if (colon.location != NSNotFound)
    {
        NSString *port = [hostPort substringFromIndex:NSMaxRange(colon)];
        if ([port length] == 0)
            return nil;
        for (NSUInteger i = 0; i < [port length]; i++)
        {
            if (!OnegramIOS3TextCheckingASCIIDigit([port characterAtIndex:i]))
                return nil;
        }
        hostPort = [hostPort substringToIndex:colon.location];
    }
    return hostPort;
}

static NSURL *OnegramIOS3TextCheckingURLForCandidate(NSString *candidate)
{
    NSString *urlString = nil;
    NSRange colon = [candidate rangeOfString:@":"];
    if (colon.location != NSNotFound && OnegramIOS3TextCheckingValidScheme(candidate, colon.location))
    {
        NSString *scheme = [[candidate substringToIndex:colon.location] lowercaseString];
        if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"] || [scheme isEqualToString:@"ftp"] || [scheme isEqualToString:@"ftps"] || [scheme isEqualToString:@"mailto"])
            urlString = candidate;
    }

    if (urlString == nil && OnegramIOS3TextCheckingValidEmail(candidate))
    {
        urlString = [@"mailto:" stringByAppendingString:candidate];
    }
    else if (urlString == nil)
    {
        NSString *lower = [candidate lowercaseString];
        NSString *host = OnegramIOS3TextCheckingHostFromCandidate(candidate);
        if (host != nil && ([lower hasPrefix:@"www."] || OnegramIOS3TextCheckingValidDomain(host)))
            urlString = [@"http://" stringByAppendingString:candidate];
    }

    if (urlString == nil)
        return nil;
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil)
        url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return url;
}

static BOOL OnegramIOS3TextCheckingAllDigits(NSString *string)
{
    if ([string length] == 0)
        return NO;
    for (NSUInteger i = 0; i < [string length]; i++)
    {
        if (!OnegramIOS3TextCheckingASCIIDigit([string characterAtIndex:i]))
            return NO;
    }
    return YES;
}

static BOOL OnegramIOS3TextCheckingLooksLikeDateOrIPv4(NSString *candidate)
{
    if ([candidate rangeOfString:@" "].location != NSNotFound || [candidate rangeOfString:@"\t"].location != NSNotFound || [candidate rangeOfString:@"("].location != NSNotFound || [candidate rangeOfString:@")"].location != NSNotFound || [candidate rangeOfString:@"+"].location != NSNotFound)
        return NO;

    NSString *separator = nil;
    if ([candidate rangeOfString:@"."].location != NSNotFound && [candidate rangeOfString:@"-"].location == NSNotFound)
        separator = @".";
    else if ([candidate rangeOfString:@"-"].location != NSNotFound && [candidate rangeOfString:@"."].location == NSNotFound)
        separator = @"-";
    if (separator == nil)
        return NO;

    NSArray *groups = [candidate componentsSeparatedByString:separator];
    for (NSString *group in groups)
    {
        if (!OnegramIOS3TextCheckingAllDigits(group))
            return NO;
    }

    if ([separator isEqualToString:@"."] && [groups count] == 4)
    {
        BOOL ipv4 = YES;
        for (NSString *group in groups)
        {
            if ([group length] > 3 || [group integerValue] > 255)
            {
                ipv4 = NO;
                break;
            }
        }
        if (ipv4)
            return YES;
    }

    if ([groups count] == 3)
    {
        NSString *first = [groups objectAtIndex:0];
        NSString *second = [groups objectAtIndex:1];
        NSString *third = [groups objectAtIndex:2];
        if ([first length] == 4 && [second length] <= 2 && [third length] <= 2)
        {
            NSInteger month = [second integerValue];
            NSInteger day = [third integerValue];
            if (month >= 1 && month <= 12 && day >= 1 && day <= 31)
                return YES;
        }
        if ([third length] == 4 && [first length] <= 2 && [second length] <= 2)
        {
            NSInteger firstValue = [first integerValue];
            NSInteger secondValue = [second integerValue];
            if ((firstValue >= 1 && firstValue <= 31 && secondValue >= 1 && secondValue <= 12) || (firstValue >= 1 && firstValue <= 12 && secondValue >= 1 && secondValue <= 31))
                return YES;
        }
    }

    return NO;
}

static BOOL OnegramIOS3TextCheckingRangesOverlap(NSRange a, NSRange b)
{
    return a.location < NSMaxRange(b) && b.location < NSMaxRange(a);
}

static BOOL OnegramIOS3TextCheckingResultOverlaps(NSArray *results, NSRange range)
{
    for (OnegramIOS3TextCheckingResult *result in results)
    {
        if (OnegramIOS3TextCheckingRangesOverlap([result range], range))
            return YES;
    }
    return NO;
}

@implementation OnegramIOS3TextCheckingResult

+ (OnegramIOS3TextCheckingResult *)linkCheckingResultWithRange:(NSRange)range URL:(NSURL *)url
{
    return [[[self alloc] initWithResultType:NSTextCheckingTypeLink range:range URL:url phoneNumber:nil] autorelease];
}

+ (OnegramIOS3TextCheckingResult *)phoneNumberCheckingResultWithRange:(NSRange)range phoneNumber:(NSString *)phoneNumber
{
    return [[[self alloc] initWithResultType:NSTextCheckingTypePhoneNumber range:range URL:nil phoneNumber:phoneNumber] autorelease];
}

+ (OnegramIOS3TextCheckingResult *)regularExpressionCheckingResultWithRanges:(NSArray *)ranges
{
    return [[[self alloc] initWithRanges:ranges] autorelease];
}

- (instancetype)initWithResultType:(NSTextCheckingType)resultType range:(NSRange)range URL:(NSURL *)url phoneNumber:(NSString *)phoneNumber
{
    self = [super init];
    if (self != nil)
    {
        _onegramResultType = resultType;
        _onegramRange = range;
        _onegramURL = [url retain];
        _onegramPhoneNumber = [phoneNumber copy];
        _onegramRanges = [[NSArray alloc] initWithObjects:[NSValue valueWithRange:range], nil];
    }
    return self;
}

- (instancetype)initWithRanges:(NSArray *)ranges
{
    self = [super init];
    if (self != nil)
    {
        _onegramResultType = NSTextCheckingTypeRegularExpression;
        _onegramRanges = [ranges copy];
        if ([_onegramRanges count] != 0)
            _onegramRange = [[_onegramRanges objectAtIndex:0] rangeValue];
        else
            _onegramRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (void)dealloc
{
    [_onegramURL release];
    [_onegramPhoneNumber release];
    [_onegramRanges release];
    [super dealloc];
}

- (NSTextCheckingType)resultType
{
    return _onegramResultType;
}

- (NSRange)range
{
    return _onegramRange;
}

- (NSURL *)URL
{
    return _onegramURL;
}

- (NSString *)phoneNumber
{
    return _onegramPhoneNumber;
}

- (OnegramIOS3TextCheckingResult *)resultByAdjustingRangesWithOffset:(NSInteger)offset
{
    if ([_onegramRanges count] > 1 || _onegramResultType == NSTextCheckingTypeRegularExpression)
    {
        NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:[_onegramRanges count]];
        for (NSValue *value in _onegramRanges)
        {
            NSRange range = [value rangeValue];
            if (range.location != NSNotFound)
            {
                NSInteger location = (NSInteger)range.location + offset;
                if (location < 0)
                    location = 0;
                range.location = (NSUInteger)location;
            }
            [ranges addObject:[NSValue valueWithRange:range]];
        }
        return [[[OnegramIOS3TextCheckingResult alloc] initWithRanges:ranges] autorelease];
    }
    NSInteger location = (NSInteger)_onegramRange.location + offset;
    if (location < 0)
        location = 0;
    return [[[OnegramIOS3TextCheckingResult alloc] initWithResultType:_onegramResultType range:NSMakeRange((NSUInteger)location, _onegramRange.length) URL:_onegramURL phoneNumber:_onegramPhoneNumber] autorelease];
}

- (NSUInteger)numberOfRanges
{
    return [_onegramRanges count];
}

- (NSRange)rangeAtIndex:(NSUInteger)idx
{
    if (idx >= [_onegramRanges count])
        return NSMakeRange(NSNotFound, 0);
    return [[_onegramRanges objectAtIndex:idx] rangeValue];
}

@end

@interface OnegramIOS3CacheEntry : NSObject
{
    id _onegramKey;
    id _onegramObject;
    NSUInteger _onegramCost;
    OnegramIOS3CacheEntry *_onegramPrevious;
    OnegramIOS3CacheEntry *_onegramNext;
}
- (instancetype)initWithKey:(id)key object:(id)object cost:(NSUInteger)cost;
@property (nonatomic, readonly, retain) id key;
@property (nonatomic, readonly, retain) id object;
@property (nonatomic, readonly) NSUInteger cost;
@property (nonatomic, assign) OnegramIOS3CacheEntry *previous;
@property (nonatomic, assign) OnegramIOS3CacheEntry *next;
@end

@implementation OnegramIOS3CacheEntry

- (instancetype)initWithKey:(id)key object:(id)object cost:(NSUInteger)cost
{
    self = [super init];
    if (self != nil)
    {
        _onegramKey = [key retain];
        _onegramObject = [object retain];
        _onegramCost = cost;
    }
    return self;
}

- (void)dealloc
{
    [_onegramKey release];
    [_onegramObject release];
    [super dealloc];
}

- (id)key
{
    return _onegramKey;
}

- (id)object
{
    return _onegramObject;
}

- (NSUInteger)cost
{
    return _onegramCost;
}

- (OnegramIOS3CacheEntry *)previous
{
    return _onegramPrevious;
}

- (void)setPrevious:(OnegramIOS3CacheEntry *)previous
{
    _onegramPrevious = previous;
}

- (OnegramIOS3CacheEntry *)next
{
    return _onegramNext;
}

- (void)setNext:(OnegramIOS3CacheEntry *)next
{
    _onegramNext = next;
}

@end

@implementation OnegramIOS3Cache

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _onegramEntriesByKey = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        if (_onegramEntriesByKey == NULL)
        {
            [self release];
            return nil;
        }
        _onegramLock = [[NSRecursiveLock alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onegramMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_onegramEntriesByKey != NULL)
        CFRelease(_onegramEntriesByKey);
    [_onegramLock release];
    [super dealloc];
}

- (void)onegramMemoryWarning:(NSNotification *)notification
{
    (void)notification;
    [self removeAllObjects];
}

- (OnegramIOS3CacheEntry *)onegramEntryForKey:(id)key
{
    if (key == nil || _onegramEntriesByKey == NULL)
        return nil;
    return (OnegramIOS3CacheEntry *)CFDictionaryGetValue(_onegramEntriesByKey, key);
}

- (NSUInteger)onegramEntryCount
{
    return _onegramEntriesByKey == NULL ? 0 : (NSUInteger)CFDictionaryGetCount(_onegramEntriesByKey);
}

- (void)onegramDetachEntry:(OnegramIOS3CacheEntry *)entry
{
    OnegramIOS3CacheEntry *previous = entry.previous;
    OnegramIOS3CacheEntry *next = entry.next;

    if (previous != nil)
        previous.next = next;
    else
        _onegramOldestEntry = next;

    if (next != nil)
        next.previous = previous;
    else
        _onegramNewestEntry = previous;

    entry.previous = nil;
    entry.next = nil;
}

- (void)onegramAppendEntry:(OnegramIOS3CacheEntry *)entry
{
    entry.previous = _onegramNewestEntry;
    entry.next = nil;

    if (_onegramNewestEntry != nil)
        _onegramNewestEntry.next = entry;
    else
        _onegramOldestEntry = entry;

    _onegramNewestEntry = entry;
}

- (void)onegramTouchEntry:(OnegramIOS3CacheEntry *)entry
{
    if (entry == nil || entry == _onegramNewestEntry)
        return;
    [self onegramDetachEntry:entry];
    [self onegramAppendEntry:entry];
}

- (void)onegramRemoveEntry:(OnegramIOS3CacheEntry *)entry
{
    if (entry == nil)
        return;

    if (_onegramTotalCost >= entry.cost)
        _onegramTotalCost -= entry.cost;
    else
        _onegramTotalCost = 0;

    [entry retain];
    [self onegramDetachEntry:entry];
    CFDictionaryRemoveValue(_onegramEntriesByKey, entry.key);
    [entry release];
}

- (void)onegramTrim
{
    while ((_onegramCountLimit != 0 && [self onegramEntryCount] > _onegramCountLimit) || (_onegramTotalCostLimit != 0 && _onegramTotalCost > _onegramTotalCostLimit))
    {
        OnegramIOS3CacheEntry *entry = _onegramOldestEntry;
        if (entry == nil)
            break;
        [self onegramRemoveEntry:entry];
    }
}

- (id)objectForKey:(id)key
{
    if (key == nil)
        return nil;
    [_onegramLock lock];
    OnegramIOS3CacheEntry *entry = [self onegramEntryForKey:key];
    id object = [[entry object] retain];
    [self onegramTouchEntry:entry];
    [_onegramLock unlock];
    return [object autorelease];
}

- (void)setObject:(id)object forKey:(id)key
{
    [self setObject:object forKey:key cost:0];
}

- (void)setObject:(id)object forKey:(id)key cost:(NSUInteger)cost
{
    if (object == nil || key == nil)
        return;
    [_onegramLock lock];
    OnegramIOS3CacheEntry *previous = [self onegramEntryForKey:key];
    if (previous != nil)
        [self onegramRemoveEntry:previous];

    OnegramIOS3CacheEntry *entry = [[OnegramIOS3CacheEntry alloc] initWithKey:key object:object cost:cost];
    CFDictionarySetValue(_onegramEntriesByKey, key, entry);
    [self onegramAppendEntry:entry];
    _onegramTotalCost += cost;
    [entry release];

    [self onegramTrim];
    [_onegramLock unlock];
}

- (void)removeObjectForKey:(id)key
{
    if (key == nil)
        return;
    [_onegramLock lock];
    [self onegramRemoveEntry:[self onegramEntryForKey:key]];
    [_onegramLock unlock];
}

- (void)removeAllObjects
{
    [_onegramLock lock];
    _onegramOldestEntry = nil;
    _onegramNewestEntry = nil;
    CFDictionaryRemoveAllValues(_onegramEntriesByKey);
    _onegramTotalCost = 0;
    [_onegramLock unlock];
}

- (NSUInteger)countLimit
{
    [_onegramLock lock];
    NSUInteger value = _onegramCountLimit;
    [_onegramLock unlock];
    return value;
}

- (void)setCountLimit:(NSUInteger)countLimit
{
    [_onegramLock lock];
    _onegramCountLimit = countLimit;
    [self onegramTrim];
    [_onegramLock unlock];
}

- (NSUInteger)totalCostLimit
{
    [_onegramLock lock];
    NSUInteger value = _onegramTotalCostLimit;
    [_onegramLock unlock];
    return value;
}

- (void)setTotalCostLimit:(NSUInteger)totalCostLimit
{
    [_onegramLock lock];
    _onegramTotalCostLimit = totalCostLimit;
    [self onegramTrim];
    [_onegramLock unlock];
}

@end


static NSUInteger OnegramIOS3RegexUTF16LengthForBytes(const char *bytes, size_t length)
{
    if (length == 0)
        return 0;
    NSString *string = [[[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] autorelease];
    return string == nil ? (NSUInteger)length : [string length];
}

static NSString *OnegramIOS3RegexNormalizePattern(NSString *pattern)
{
    return [pattern stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
}

@implementation OnegramIOS3RegularExpression

+ (OnegramIOS3RegularExpression *)regularExpressionWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error
{
    return [[[self alloc] initWithPattern:pattern options:options error:error] autorelease];
}

- (instancetype)initWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error
{
    self = [super init];
    if (self != nil)
    {
        _onegramPattern = [pattern copy];
        _onegramOptions = options;
        regex_t *compiled = calloc(1, sizeof(regex_t));
        NSString *normalizedPattern = OnegramIOS3RegexNormalizePattern(pattern == nil ? @"" : pattern);
        const char *utf8Pattern = [normalizedPattern UTF8String];
        int flags = REG_EXTENDED;
        if ((options & NSRegularExpressionCaseInsensitive) != 0)
            flags |= REG_ICASE;
        int result = regcomp(compiled, utf8Pattern == NULL ? "" : utf8Pattern, flags);
        if (result != 0)
        {
            if (error != NULL)
            {
                char buffer[256];
                regerror(result, compiled, buffer, sizeof(buffer));
                NSString *description = [NSString stringWithUTF8String:buffer];
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:2048 userInfo:[NSDictionary dictionaryWithObject:(description == nil ? @"Invalid regular expression" : description) forKey:NSLocalizedDescriptionKey]];
            }
            free(compiled);
            [_onegramPattern release];
            [self release];
            return nil;
        }
        _onegramCompiledExpression = compiled;
        _onegramCaptureCount = compiled->re_nsub;
    }
    return self;
}

- (void)dealloc
{
    if (_onegramCompiledExpression != NULL)
    {
        regex_t *compiled = (regex_t *)_onegramCompiledExpression;
        regfree(compiled);
        free(compiled);
    }
    [_onegramPattern release];
    [super dealloc];
}

- (NSString *)pattern
{
    return _onegramPattern;
}

- (NSRegularExpressionOptions)options
{
    return _onegramOptions;
}

- (NSUInteger)numberOfCaptureGroups
{
    return _onegramCaptureCount;
}

- (NSArray *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    (void)options;
    if (string == nil || _onegramCompiledExpression == NULL || range.location == NSNotFound || NSMaxRange(range) > [string length])
        return [NSArray array];
    NSString *subject = [string substringWithRange:range];
    NSData *data = [subject dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil)
        return [NSArray array];
    NSMutableData *terminatedData = [NSMutableData dataWithData:data];
    unsigned char zero = 0;
    [terminatedData appendBytes:&zero length:1];
    const char *bytes = (const char *)[terminatedData bytes];
    size_t byteLength = [data length];
    regex_t *compiled = (regex_t *)_onegramCompiledExpression;
    size_t matchCount = _onegramCaptureCount + 1;
    regmatch_t *matches = calloc(matchCount, sizeof(regmatch_t));
    NSMutableArray *results = [NSMutableArray array];
    size_t cursor = 0;
    BOOL firstAttempt = YES;
    while (cursor <= byteLength)
    {
        int flags = firstAttempt ? 0 : REG_NOTBOL;
        int status = regexec(compiled, bytes + cursor, matchCount, matches, flags);
        if (status != 0)
            break;
        if (matches[0].rm_so < 0 || matches[0].rm_eo < matches[0].rm_so)
            break;
        size_t absoluteStart = cursor + (size_t)matches[0].rm_so;
        size_t absoluteEnd = cursor + (size_t)matches[0].rm_eo;
        NSMutableArray *ranges = [NSMutableArray arrayWithCapacity:matchCount];
        for (size_t index = 0; index < matchCount; index++)
        {
            if (matches[index].rm_so < 0)
            {
                [ranges addObject:[NSValue valueWithRange:NSMakeRange(NSNotFound, 0)]];
                continue;
            }
            size_t captureStart = cursor + (size_t)matches[index].rm_so;
            size_t captureEnd = cursor + (size_t)matches[index].rm_eo;
            NSUInteger utf16Start = OnegramIOS3RegexUTF16LengthForBytes(bytes, captureStart);
            NSUInteger utf16End = OnegramIOS3RegexUTF16LengthForBytes(bytes, captureEnd);
            [ranges addObject:[NSValue valueWithRange:NSMakeRange(range.location + utf16Start, utf16End - utf16Start)]];
        }
        [results addObject:[OnegramIOS3TextCheckingResult regularExpressionCheckingResultWithRanges:ranges]];
        if (absoluteEnd > absoluteStart)
            cursor = absoluteEnd;
        else
        {
            if (absoluteEnd >= byteLength)
                break;
            cursor = absoluteEnd + 1;
            while (cursor < byteLength && (((const unsigned char *)bytes)[cursor] & 0xc0) == 0x80)
                cursor++;
        }
        firstAttempt = NO;
    }
    free(matches);
    return results;
}

- (OnegramIOS3TextCheckingResult *)firstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    NSArray *matches = [self matchesInString:string options:options range:range];
    return [matches count] == 0 ? nil : [matches objectAtIndex:0];
}

- (NSUInteger)numberOfMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    return [[self matchesInString:string options:options range:range] count];
}

- (NSRange)rangeOfFirstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    OnegramIOS3TextCheckingResult *result = [self firstMatchInString:string options:options range:range];
    return result == nil ? NSMakeRange(NSNotFound, 0) : [result range];
}

- (NSString *)onegramReplacementForTemplate:(NSString *)templ result:(OnegramIOS3TextCheckingResult *)result source:(NSString *)source
{
    NSMutableString *replacement = [NSMutableString string];
    NSUInteger length = [templ length];
    for (NSUInteger index = 0; index < length; index++)
    {
        unichar character = [templ characterAtIndex:index];
        if (character == '$' && index + 1 < length)
        {
            unichar digit = [templ characterAtIndex:index + 1];
            if (digit >= '0' && digit <= '9')
            {
                NSUInteger rangeIndex = (NSUInteger)(digit - '0');
                NSRange captureRange = [result rangeAtIndex:rangeIndex];
                if (captureRange.location != NSNotFound && NSMaxRange(captureRange) <= [source length])
                    [replacement appendString:[source substringWithRange:captureRange]];
                index++;
                continue;
            }
        }
        [replacement appendFormat:@"%C", character];
    }
    return replacement;
}

- (NSString *)stringByReplacingMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ
{
    if (string == nil)
        return nil;
    NSArray *matches = [self matchesInString:string options:options range:range];
    if ([matches count] == 0)
        return string;
    NSMutableString *result = [string mutableCopy];
    for (NSInteger index = (NSInteger)[matches count] - 1; index >= 0; index--)
    {
        OnegramIOS3TextCheckingResult *match = [matches objectAtIndex:(NSUInteger)index];
        NSRange matchRange = [match range];
        if (matchRange.location == NSNotFound || NSMaxRange(matchRange) > [result length])
            continue;
        NSString *replacement = [self onegramReplacementForTemplate:(templ == nil ? @"" : templ) result:match source:string];
        [result replaceCharactersInRange:matchRange withString:replacement];
    }
    return [result autorelease];
}

@end

@implementation OnegramIOS3DataDetector

+ (OnegramIOS3DataDetector *)dataDetectorWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error
{
    return [[[self alloc] initWithTypes:checkingTypes error:error] autorelease];
}

- (instancetype)initWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error
{
    self = [super init];
    if (self != nil)
        _onegramCheckingTypes = checkingTypes & (NSTextCheckingTypeLink | NSTextCheckingTypePhoneNumber);
    if (error != NULL)
        *error = nil;
    return self;
}

- (NSArray *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range
{
    (void)options;
    if (string == nil || range.location == NSNotFound || range.location >= [string length] || range.length == 0)
        return [NSArray array];

    NSUInteger stringLength = [string length];
    NSUInteger limit = range.length > stringLength - range.location ? stringLength : range.location + range.length;
    NSMutableArray *results = [NSMutableArray array];

    if ((_onegramCheckingTypes & NSTextCheckingTypeLink) != 0)
    {
        NSUInteger index = range.location;
        while (index < limit)
        {
            while (index < limit && OnegramIOS3TextCheckingTokenBoundary([string characterAtIndex:index]))
                index++;
            NSUInteger tokenStart = index;
            while (index < limit && !OnegramIOS3TextCheckingTokenBoundary([string characterAtIndex:index]))
                index++;
            NSUInteger tokenEnd = index;

            while (tokenStart < tokenEnd && OnegramIOS3TextCheckingLeadingDelimiter([string characterAtIndex:tokenStart]))
                tokenStart++;
            while (tokenEnd > tokenStart && OnegramIOS3TextCheckingTrailingDelimiter([string characterAtIndex:tokenEnd - 1]))
                tokenEnd--;
            while (tokenEnd > tokenStart && [string characterAtIndex:tokenEnd - 1] == ')')
            {
                NSUInteger opens = 0;
                NSUInteger closes = 0;
                for (NSUInteger i = tokenStart; i < tokenEnd; i++)
                {
                    unichar c = [string characterAtIndex:i];
                    if (c == '(')
                        opens++;
                    else if (c == ')')
                        closes++;
                }
                if (closes <= opens)
                    break;
                tokenEnd--;
            }

            if (tokenEnd > tokenStart)
            {
                NSRange tokenRange = NSMakeRange(tokenStart, tokenEnd - tokenStart);
                NSString *candidate = [string substringWithRange:tokenRange];
                NSURL *url = OnegramIOS3TextCheckingURLForCandidate(candidate);
                if (url != nil)
                    [results addObject:[OnegramIOS3TextCheckingResult linkCheckingResultWithRange:tokenRange URL:url]];
            }
        }
    }

    if ((_onegramCheckingTypes & NSTextCheckingTypePhoneNumber) != 0)
    {
        NSUInteger index = range.location;
        while (index < limit)
        {
            unichar first = [string characterAtIndex:index];
            BOOL possibleStart = OnegramIOS3TextCheckingASCIIDigit(first) || first == '+' || first == '(';
            if (!possibleStart)
            {
                index++;
                continue;
            }

            if (index > range.location)
            {
                unichar previous = [string characterAtIndex:index - 1];
                if (OnegramIOS3TextCheckingASCIIAlpha(previous) || OnegramIOS3TextCheckingASCIIDigit(previous))
                {
                    index++;
                    continue;
                }
            }

            NSUInteger end = index;
            NSUInteger digitCount = 0;
            while (end < limit)
            {
                unichar c = [string characterAtIndex:end];
                if (OnegramIOS3TextCheckingASCIIDigit(c))
                {
                    digitCount++;
                    end++;
                    continue;
                }
                if (c == '+' && end == index)
                {
                    end++;
                    continue;
                }
                if (c == ' ' || c == '\t' || c == 0x00a0 || c == '-' || c == '(' || c == ')' || c == '.')
                {
                    end++;
                    continue;
                }
                break;
            }

            NSUInteger trimmedEnd = end;
            while (trimmedEnd > index)
            {
                unichar c = [string characterAtIndex:trimmedEnd - 1];
                if (OnegramIOS3TextCheckingASCIIDigit(c))
                    break;
                trimmedEnd--;
            }

            if (digitCount >= 7 && digitCount <= 15 && trimmedEnd > index)
            {
                if (trimmedEnd == limit || !(OnegramIOS3TextCheckingASCIIAlpha([string characterAtIndex:trimmedEnd]) || OnegramIOS3TextCheckingASCIIDigit([string characterAtIndex:trimmedEnd])))
                {
                    NSRange phoneRange = NSMakeRange(index, trimmedEnd - index);
                    if (!OnegramIOS3TextCheckingResultOverlaps(results, phoneRange))
                    {
                        NSString *phoneNumber = [string substringWithRange:phoneRange];
                        if (!OnegramIOS3TextCheckingLooksLikeDateOrIPv4(phoneNumber))
                            [results addObject:[OnegramIOS3TextCheckingResult phoneNumberCheckingResultWithRange:phoneRange phoneNumber:phoneNumber]];
                    }
                }
            }

            index = end > index ? end : index + 1;
        }
    }

    [results sortUsingComparator:^NSComparisonResult(id aObject, id bObject) {
        OnegramIOS3TextCheckingResult *a = aObject;
        OnegramIOS3TextCheckingResult *b = bObject;
        if ([a range].location < [b range].location)
            return NSOrderedAscending;
        if ([a range].location > [b range].location)
            return NSOrderedDescending;
        if ([a range].length > [b range].length)
            return NSOrderedAscending;
        if ([a range].length < [b range].length)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];

    return results;
}

- (void)enumerateMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range usingBlock:(void (^)(OnegramIOS3TextCheckingResult *result, NSMatchingFlags flags, BOOL *stop))block
{
    if (block == nil)
        return;
    BOOL stop = NO;
    for (OnegramIOS3TextCheckingResult *result in [self matchesInString:string options:options range:range])
    {
        block(result, 0, &stop);
        if (stop)
            break;
    }
}

@end

@interface OnegramIOS3AnimationCompletionTarget : NSObject
{
    void (^_completion)(BOOL);
}
- (instancetype)initWithCompletion:(void (^)(BOOL))completion;
- (void)fire:(NSTimer *)timer;
@end

@implementation OnegramIOS3AnimationCompletionTarget

- (instancetype)initWithCompletion:(void (^)(BOOL))completion
{
    self = [super init];
    if (self != nil)
        _completion = [completion copy];
    return self;
}

- (void)dealloc
{
    [_completion release];
    [super dealloc];
}

- (void)fire:(NSTimer *)timer
{
    if (_completion != nil)
        _completion(YES);
    [self release];
}

@end

static NSString *const OnegramIOS3KeyframeAnimationStackKey = @"OnegramIOS3KeyframeAnimationStack";

static NSMutableArray *OnegramIOS3KeyframeAnimationStack(void)
{
    NSMutableDictionary *dictionary = [[NSThread currentThread] threadDictionary];
    NSMutableArray *stack = [dictionary objectForKey:OnegramIOS3KeyframeAnimationStackKey];
    if (stack == nil)
    {
        stack = [NSMutableArray array];
        [dictionary setObject:stack forKey:OnegramIOS3KeyframeAnimationStackKey];
    }
    return stack;
}

static const void *OnegramIOS3GestureRecognizerRegistryKey = &OnegramIOS3GestureRecognizerRegistryKey;
static const void *OnegramIOS3GestureRecognizerViewKey = &OnegramIOS3GestureRecognizerViewKey;

static UIView *OnegramIOS3GestureRecognizerView(id gestureRecognizer)
{
    return objc_getAssociatedObject(gestureRecognizer, OnegramIOS3GestureRecognizerViewKey);
}

static void OnegramIOS3SetGestureRecognizerView(id gestureRecognizer, UIView *view)
{
    objc_setAssociatedObject(gestureRecognizer, OnegramIOS3GestureRecognizerViewKey, view, OBJC_ASSOCIATION_ASSIGN);
}

@interface OnegramIOS3GestureRecognizerRegistry : NSObject
{
    UIView *_view;
    NSMutableArray *_recognizers;
    NSArray *_recognizerSnapshot;
}
- (instancetype)initWithView:(UIView *)view;
- (NSArray *)recognizerSnapshot;
- (void)onegramUpdateRecognizerSnapshot;
- (void)addRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)removeRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end

@implementation OnegramIOS3GestureRecognizerRegistry

- (instancetype)initWithView:(UIView *)view
{
    self = [super init];
    if (self != nil)
    {
        _view = view;
        _recognizers = [[NSMutableArray alloc] init];
        _recognizerSnapshot = [[NSArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    for (UIGestureRecognizer *gestureRecognizer in _recognizers)
    {
        if (OnegramIOS3GestureRecognizerView(gestureRecognizer) == _view)
            OnegramIOS3SetGestureRecognizerView(gestureRecognizer, nil);
    }
    [_recognizers release];
    [_recognizerSnapshot release];
    [super dealloc];
}

- (NSArray *)recognizerSnapshot
{
    return _recognizerSnapshot;
}

- (void)onegramUpdateRecognizerSnapshot
{
    NSArray *snapshot = [_recognizers copy];
    [_recognizerSnapshot release];
    _recognizerSnapshot = snapshot;
}

- (void)addRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer != nil && ![_recognizers containsObject:gestureRecognizer])
    {
        [_recognizers addObject:gestureRecognizer];
        [self onegramUpdateRecognizerSnapshot];
    }
}

- (void)removeRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer != nil && [_recognizers containsObject:gestureRecognizer])
    {
        [_recognizers removeObject:gestureRecognizer];
        [self onegramUpdateRecognizerSnapshot];
    }
}

@end

static OnegramIOS3GestureRecognizerRegistry *OnegramIOS3GestureRecognizerRegistryForView(UIView *view, BOOL create)
{
    OnegramIOS3GestureRecognizerRegistry *registry = objc_getAssociatedObject(view, OnegramIOS3GestureRecognizerRegistryKey);
    if (registry == nil && create)
    {
        registry = [[OnegramIOS3GestureRecognizerRegistry alloc] initWithView:view];
        objc_setAssociatedObject(view, OnegramIOS3GestureRecognizerRegistryKey, registry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [registry release];
        registry = objc_getAssociatedObject(view, OnegramIOS3GestureRecognizerRegistryKey);
    }
    return registry;
}

@interface OnegramIOS3GestureTargetAction : NSObject
{
@public
    id target;
    SEL action;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action;

@end

@implementation OnegramIOS3GestureTargetAction

- (instancetype)initWithTarget:(id)value action:(SEL)selector
{
    self = [super init];
    if (self != nil)
    {
        target = value;
        action = selector;
    }
    return self;
}

@end

@implementation UIGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super init];
    if (self != nil)
    {
        _onegramTargetActions = [[NSMutableArray alloc] init];
        [self addTarget:target action:action];
        _onegramState = UIGestureRecognizerStatePossible;
        _onegramEnabled = YES;
        _onegramCancelsTouchesInView = YES;
    }
    return self;
}

- (void)dealloc
{
    [_onegramTargetActions release];
    [_onegramTouches release];
    [super dealloc];
}

- (void)addTarget:(id)target action:(SEL)action
{
    if (target == nil || action == NULL)
        return;
    for (OnegramIOS3GestureTargetAction *targetAction in _onegramTargetActions)
    {
        if (targetAction->target == target && targetAction->action == action)
            return;
    }
    OnegramIOS3GestureTargetAction *targetAction = [[OnegramIOS3GestureTargetAction alloc] initWithTarget:target action:action];
    [_onegramTargetActions addObject:targetAction];
    [targetAction release];
}

- (void)removeTarget:(id)target action:(SEL)action
{
    for (NSInteger index = (NSInteger)[_onegramTargetActions count] - 1; index >= 0; index--)
    {
        OnegramIOS3GestureTargetAction *targetAction = [_onegramTargetActions objectAtIndex:(NSUInteger)index];
        if ((target == nil || targetAction->target == target) && (action == NULL || targetAction->action == action))
            [_onegramTargetActions removeObjectAtIndex:(NSUInteger)index];
    }
}

- (id<UIGestureRecognizerDelegate>)delegate { return _onegramDelegate; }
- (void)setDelegate:(id<UIGestureRecognizerDelegate>)delegate { _onegramDelegate = delegate; }
- (UIGestureRecognizerState)state { return _onegramState; }
- (UIView *)view { return OnegramIOS3GestureRecognizerView(self); }
- (BOOL)isEnabled { return _onegramEnabled; }
- (void)setEnabled:(BOOL)enabled
{
    _onegramEnabled = enabled;
    if (!enabled)
    {
        if (_onegramState == UIGestureRecognizerStateBegan || _onegramState == UIGestureRecognizerStateChanged)
            self.state = UIGestureRecognizerStateCancelled;
        [self reset];
    }
}
- (BOOL)cancelsTouchesInView { return _onegramCancelsTouchesInView; }
- (void)setCancelsTouchesInView:(BOOL)value { _onegramCancelsTouchesInView = value; }
- (BOOL)delaysTouchesBegan { return _onegramDelaysTouchesBegan; }
- (void)setDelaysTouchesBegan:(BOOL)value { _onegramDelaysTouchesBegan = value; }
- (BOOL)delaysTouchesEnded { return _onegramDelaysTouchesEnded; }
- (void)setDelaysTouchesEnded:(BOOL)value { _onegramDelaysTouchesEnded = value; }

- (void)setState:(UIGestureRecognizerState)state
{
    if (_onegramState == state)
        return;
    if (_onegramState == UIGestureRecognizerStatePossible && state == UIGestureRecognizerStateBegan && [_onegramDelegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && ![_onegramDelegate gestureRecognizerShouldBegin:self])
        state = UIGestureRecognizerStateFailed;
    _onegramState = state;
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged || state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateRecognized)
    {
        NSArray *targetActions = [[_onegramTargetActions copy] autorelease];
        for (OnegramIOS3GestureTargetAction *targetAction in targetActions)
        {
            if (targetAction->target != nil && targetAction->action != NULL && [targetAction->target respondsToSelector:targetAction->action])
                ((void (*)(id, SEL, id))objc_msgSend)(targetAction->target, targetAction->action, self);
        }
    }
}

- (CGPoint)locationInView:(UIView *)view
{
    UITouch *touch = [_onegramTouches anyObject];
    return touch == nil ? CGPointZero : [touch locationInView:view];
}

- (NSUInteger)numberOfTouches { return [_onegramTouches count]; }

- (CGPoint)locationOfTouch:(NSUInteger)touchIndex inView:(UIView *)view
{
    NSArray *touches = [_onegramTouches allObjects];
    return touchIndex < [touches count] ? [[touches objectAtIndex:touchIndex] locationInView:view] : CGPointZero;
}

- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)otherGestureRecognizer { }

- (void)reset
{
    self.state = UIGestureRecognizerStatePossible;
    [_onegramTouches release];
    _onegramTouches = nil;
}

- (void)onegramSetTouches:(NSSet *)touches
{
    if (_onegramTouches != touches)
    {
        [_onegramTouches release];
        _onegramTouches = [touches copy];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event { [self onegramSetTouches:touches]; }
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event { [self onegramSetTouches:touches]; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { [self onegramSetTouches:touches]; }
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event { [self onegramSetTouches:touches]; self.state = UIGestureRecognizerStateCancelled; }
- (void)onegramDelayedReset:(id)unused { [self reset]; }

@end

@implementation UIPanGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
    {
        _onegramMinimumNumberOfTouches = 1;
        _onegramMaximumNumberOfTouches = NSUIntegerMax;
    }
    return self;
}

- (NSUInteger)minimumNumberOfTouches { return _onegramMinimumNumberOfTouches; }
- (void)setMinimumNumberOfTouches:(NSUInteger)value { _onegramMinimumNumberOfTouches = value; }
- (NSUInteger)maximumNumberOfTouches { return _onegramMaximumNumberOfTouches; }
- (void)setMaximumNumberOfTouches:(NSUInteger)value { _onegramMaximumNumberOfTouches = value; }

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    _onegramStartLocation = [touch locationInView:self.view];
    _onegramCurrentLocation = _onegramStartLocation;
    _onegramTranslation = CGPointZero;
    _onegramVelocity = CGPointZero;
    _onegramLastTimestamp = [touch timestamp];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    NSTimeInterval timestamp = [touch timestamp];
    NSTimeInterval delta = timestamp - _onegramLastTimestamp;
    if (delta > 0.0)
        _onegramVelocity = CGPointMake((location.x - _onegramCurrentLocation.x) / delta, (location.y - _onegramCurrentLocation.y) / delta);
    _onegramCurrentLocation = location;
    _onegramTranslation = CGPointMake(location.x - _onegramStartLocation.x, location.y - _onegramStartLocation.y);
    _onegramLastTimestamp = timestamp;
    CGFloat distanceSquared = _onegramTranslation.x * _onegramTranslation.x + _onegramTranslation.y * _onegramTranslation.y;
    if (self.state == UIGestureRecognizerStatePossible && distanceSquared >= 9.0f)
        self.state = UIGestureRecognizerStateBegan;
    else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
        self.state = UIGestureRecognizerStateChanged;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    self.state = (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
}

- (CGPoint)translationInView:(UIView *)view { return _onegramTranslation; }
- (void)setTranslation:(CGPoint)translation inView:(UIView *)view { _onegramTranslation = translation; _onegramStartLocation = CGPointMake(_onegramCurrentLocation.x - translation.x, _onegramCurrentLocation.y - translation.y); }
- (CGPoint)velocityInView:(UIView *)view { return _onegramVelocity; }

@end

static CGFloat OnegramIOS3GestureDistance(UITouch *firstTouch, UITouch *secondTouch, UIView *view)
{
    CGPoint first = [firstTouch locationInView:view];
    CGPoint second = [secondTouch locationInView:view];
    CGFloat dx = second.x - first.x;
    CGFloat dy = second.y - first.y;
    return sqrtf(dx * dx + dy * dy);
}

static CGFloat OnegramIOS3GestureAngle(UITouch *firstTouch, UITouch *secondTouch, UIView *view)
{
    CGPoint first = [firstTouch locationInView:view];
    CGPoint second = [secondTouch locationInView:view];
    return atan2f(second.y - first.y, second.x - first.x);
}

static CGFloat OnegramIOS3NormalizedAngleDelta(CGFloat value)
{
    const CGFloat pi = 3.14159265358979323846f;
    while (value > pi)
        value -= pi * 2.0f;
    while (value < -pi)
        value += pi * 2.0f;
    return value;
}

@implementation UIPinchGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
        _scale = 1.0f;
    return self;
}

- (CGFloat)scale { return _scale; }
- (void)setScale:(CGFloat)scale { _scale = scale; }
- (CGFloat)velocity { return _onegramPinchVelocity; }

- (void)onegramPreparePinchTouches
{
    if (_onegramPinchFirstTouch != nil && _onegramPinchSecondTouch != nil)
        return;
    NSArray *touches = [_onegramTouches allObjects];
    if ([touches count] < 2)
        return;
    _onegramPinchFirstTouch = [touches objectAtIndex:0];
    _onegramPinchSecondTouch = [touches objectAtIndex:1];
    _onegramPreviousDistance = OnegramIOS3GestureDistance(_onegramPinchFirstTouch, _onegramPinchSecondTouch, self.view);
    _onegramPinchLastTimestamp = MAX([_onegramPinchFirstTouch timestamp], [_onegramPinchSecondTouch timestamp]);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self onegramPreparePinchTouches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self onegramPreparePinchTouches];
    if (_onegramPinchFirstTouch == nil || _onegramPinchSecondTouch == nil || _onegramPreviousDistance <= 0.0f)
        return;

    CGFloat distance = OnegramIOS3GestureDistance(_onegramPinchFirstTouch, _onegramPinchSecondTouch, self.view);
    NSTimeInterval timestamp = MAX([_onegramPinchFirstTouch timestamp], [_onegramPinchSecondTouch timestamp]);
    NSTimeInterval deltaTime = timestamp - _onegramPinchLastTimestamp;
    CGFloat relativeScale = distance / _onegramPreviousDistance;
    _scale *= relativeScale;
    _onegramPinchVelocity = deltaTime > 0.0 ? (relativeScale - 1.0f) / deltaTime : 0.0f;
    _onegramPreviousDistance = distance;
    _onegramPinchLastTimestamp = timestamp;

    if (self.state == UIGestureRecognizerStatePossible)
        self.state = UIGestureRecognizerStateBegan;
    else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
        self.state = UIGestureRecognizerStateChanged;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    self.state = (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
    _onegramPinchFirstTouch = nil;
    _onegramPinchSecondTouch = nil;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    _onegramPinchFirstTouch = nil;
    _onegramPinchSecondTouch = nil;
}

- (CGPoint)locationInView:(UIView *)view
{
    if (_onegramPinchFirstTouch == nil || _onegramPinchSecondTouch == nil)
        return [super locationInView:view];
    CGPoint first = [_onegramPinchFirstTouch locationInView:view];
    CGPoint second = [_onegramPinchSecondTouch locationInView:view];
    return CGPointMake((first.x + second.x) * 0.5f, (first.y + second.y) * 0.5f);
}

- (void)reset
{
    [super reset];
    _scale = 1.0f;
    _onegramPinchVelocity = 0.0f;
    _onegramPreviousDistance = 0.0f;
    _onegramPinchLastTimestamp = 0.0;
    _onegramPinchFirstTouch = nil;
    _onegramPinchSecondTouch = nil;
}

@end

@implementation UIRotationGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    return self;
}

- (CGFloat)rotation { return _rotation; }
- (void)setRotation:(CGFloat)rotation { _rotation = rotation; }
- (CGFloat)velocity { return _onegramRotationVelocity; }

- (void)onegramPrepareRotationTouches
{
    if (_onegramRotationFirstTouch != nil && _onegramRotationSecondTouch != nil)
        return;
    NSArray *touches = [_onegramTouches allObjects];
    if ([touches count] < 2)
        return;
    _onegramRotationFirstTouch = [touches objectAtIndex:0];
    _onegramRotationSecondTouch = [touches objectAtIndex:1];
    _onegramPreviousAngle = OnegramIOS3GestureAngle(_onegramRotationFirstTouch, _onegramRotationSecondTouch, self.view);
    _onegramRotationLastTimestamp = MAX([_onegramRotationFirstTouch timestamp], [_onegramRotationSecondTouch timestamp]);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self onegramPrepareRotationTouches];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self onegramPrepareRotationTouches];
    if (_onegramRotationFirstTouch == nil || _onegramRotationSecondTouch == nil)
        return;

    CGFloat angle = OnegramIOS3GestureAngle(_onegramRotationFirstTouch, _onegramRotationSecondTouch, self.view);
    CGFloat delta = OnegramIOS3NormalizedAngleDelta(angle - _onegramPreviousAngle);
    NSTimeInterval timestamp = MAX([_onegramRotationFirstTouch timestamp], [_onegramRotationSecondTouch timestamp]);
    NSTimeInterval deltaTime = timestamp - _onegramRotationLastTimestamp;
    _rotation += delta;
    _onegramRotationVelocity = deltaTime > 0.0 ? delta / deltaTime : 0.0f;
    _onegramPreviousAngle = angle;
    _onegramRotationLastTimestamp = timestamp;

    if (self.state == UIGestureRecognizerStatePossible)
    {
        if (fabsf(_rotation) >= 0.01f)
            self.state = UIGestureRecognizerStateBegan;
    }
    else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)
    {
        self.state = UIGestureRecognizerStateChanged;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    self.state = (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) ? UIGestureRecognizerStateEnded : UIGestureRecognizerStateFailed;
    _onegramRotationFirstTouch = nil;
    _onegramRotationSecondTouch = nil;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    _onegramRotationFirstTouch = nil;
    _onegramRotationSecondTouch = nil;
}

- (CGPoint)locationInView:(UIView *)view
{
    if (_onegramRotationFirstTouch == nil || _onegramRotationSecondTouch == nil)
        return [super locationInView:view];
    CGPoint first = [_onegramRotationFirstTouch locationInView:view];
    CGPoint second = [_onegramRotationSecondTouch locationInView:view];
    return CGPointMake((first.x + second.x) * 0.5f, (first.y + second.y) * 0.5f);
}

- (void)reset
{
    [super reset];
    _rotation = 0.0f;
    _onegramRotationVelocity = 0.0f;
    _onegramPreviousAngle = 0.0f;
    _onegramRotationLastTimestamp = 0.0;
    _onegramRotationFirstTouch = nil;
    _onegramRotationSecondTouch = nil;
}

@end

@implementation UISwipeGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
        _onegramDirection = UISwipeGestureRecognizerDirectionRight;
    return self;
}

- (UISwipeGestureRecognizerDirection)direction
{
    return _onegramDirection;
}

- (void)setDirection:(UISwipeGestureRecognizerDirection)direction
{
    _onegramDirection = direction;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    _onegramSwipeStartLocation = touch == nil ? CGPointZero : [touch locationInView:self.view];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    if (touch == nil)
    {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }

    CGPoint endLocation = [touch locationInView:self.view];
    CGFloat dx = endLocation.x - _onegramSwipeStartLocation.x;
    CGFloat dy = endLocation.y - _onegramSwipeStartLocation.y;
    CGFloat absoluteX = dx < 0.0f ? -dx : dx;
    CGFloat absoluteY = dy < 0.0f ? -dy : dy;
    UISwipeGestureRecognizerDirection detectedDirection = 0;

    if (MAX(absoluteX, absoluteY) >= 24.0f)
    {
        if (absoluteX >= absoluteY)
            detectedDirection = dx >= 0.0f ? UISwipeGestureRecognizerDirectionRight : UISwipeGestureRecognizerDirectionLeft;
        else
            detectedDirection = dy >= 0.0f ? UISwipeGestureRecognizerDirectionDown : UISwipeGestureRecognizerDirectionUp;
    }

    self.state = (detectedDirection != 0 && (_onegramDirection & detectedDirection) != 0) ? UIGestureRecognizerStateRecognized : UIGestureRecognizerStateFailed;
}

@end

@implementation UITapGestureRecognizer
@synthesize numberOfTapsRequired = _numberOfTapsRequired;
@synthesize numberOfTouchesRequired = _numberOfTouchesRequired;
- (instancetype)initWithTarget:(id)target action:(SEL)action { self = [super initWithTarget:target action:action]; if (self != nil) { _numberOfTapsRequired = 1; _numberOfTouchesRequired = 1; } return self; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event { [super touchesEnded:touches withEvent:event]; self.state = UIGestureRecognizerStateRecognized; }
@end

@implementation UILongPressGestureRecognizer
@synthesize numberOfTapsRequired = _numberOfTapsRequired;
@synthesize numberOfTouchesRequired = _numberOfTouchesRequired;
@synthesize minimumPressDuration = _minimumPressDuration;
@synthesize allowableMovement = _allowableMovement;
- (instancetype)initWithTarget:(id)target action:(SEL)action { self = [super initWithTarget:target action:action]; if (self != nil) { _numberOfTouchesRequired = 1; _minimumPressDuration = 0.5; _allowableMovement = 10.0f; } return self; }
@end

@implementation UIView (OnegramIOS3GestureCompatibility)

- (NSArray *)gestureRecognizers
{
    OnegramIOS3GestureRecognizerRegistry *registry = OnegramIOS3GestureRecognizerRegistryForView(self, NO);
    if (registry == nil)
        return [NSArray array];
    return [[[registry recognizerSnapshot] copy] autorelease];
}

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == nil)
        return;

    [gestureRecognizer retain];
    UIView *currentView = OnegramIOS3GestureRecognizerView(gestureRecognizer);
    if (currentView != nil && currentView != self)
        [currentView removeGestureRecognizer:gestureRecognizer];

    OnegramIOS3GestureRecognizerRegistry *registry = OnegramIOS3GestureRecognizerRegistryForView(self, YES);
    [registry addRecognizer:gestureRecognizer];
    OnegramIOS3SetGestureRecognizerView(gestureRecognizer, self);
    [gestureRecognizer release];
}

- (void)removeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == nil)
        return;

    [gestureRecognizer retain];
    OnegramIOS3GestureRecognizerRegistry *registry = OnegramIOS3GestureRecognizerRegistryForView(self, NO);

    if (OnegramIOS3GestureRecognizerView(gestureRecognizer) == self)
        OnegramIOS3SetGestureRecognizerView(gestureRecognizer, nil);

    [registry removeRecognizer:gestureRecognizer];

    if (registry != nil && [[registry recognizerSnapshot] count] == 0)
        objc_setAssociatedObject(self, OnegramIOS3GestureRecognizerRegistryKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [gestureRecognizer release];
}

@end

static void OnegramIOS3DispatchGestureTouches(UIView *view, NSSet *touches, UIEvent *event)
{
    if (view == nil || [touches count] == 0)
        return;

    BOOL hasBegan = NO;
    BOOL hasMoved = NO;
    BOOL hasEnded = NO;
    BOOL hasCancelled = NO;
    for (UITouch *touch in touches)
    {
        switch ([touch phase])
        {
            case UITouchPhaseBegan: hasBegan = YES; break;
            case UITouchPhaseMoved: hasMoved = YES; break;
            case UITouchPhaseEnded: hasEnded = YES; break;
            case UITouchPhaseCancelled: hasCancelled = YES; break;
            default: break;
        }
    }

    for (UIView *current = view; current != nil; current = [current superview])
    {
        OnegramIOS3GestureRecognizerRegistry *registry = OnegramIOS3GestureRecognizerRegistryForView(current, NO);
        if (registry == nil)
            continue;

        NSArray *recognizers = [[registry recognizerSnapshot] retain];
        for (UIGestureRecognizer *recognizer in recognizers)
        {
            if (![recognizer isKindOfClass:[UIGestureRecognizer class]] || ![recognizer isEnabled])
                continue;

            BOOL accepted = YES;
            id<UIGestureRecognizerDelegate> delegate = recognizer.delegate;
            if ([delegate respondsToSelector:@selector(gestureRecognizer:shouldReceiveTouch:)])
            {
                for (UITouch *touch in touches)
                {
                    if (![delegate gestureRecognizer:recognizer shouldReceiveTouch:touch])
                    {
                        accepted = NO;
                        break;
                    }
                }
            }
            if (!accepted)
                continue;

            if (hasCancelled)
                [recognizer touchesCancelled:touches withEvent:event];
            else if (hasEnded)
                [recognizer touchesEnded:touches withEvent:event];
            else if (hasMoved)
                [recognizer touchesMoved:touches withEvent:event];
            else if (hasBegan)
                [recognizer touchesBegan:touches withEvent:event];

            if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateRecognized || recognizer.state == UIGestureRecognizerStateFailed || recognizer.state == UIGestureRecognizerStateCancelled)
            {
                if ([recognizer respondsToSelector:@selector(onegramDelayedReset:)])
                    [recognizer performSelector:@selector(onegramDelayedReset:) withObject:nil afterDelay:0.0];
                else if ([recognizer respondsToSelector:@selector(reset)])
                    [recognizer performSelector:@selector(reset) withObject:nil afterDelay:0.0];
            }
        }
        [recognizers release];
    }
}

@implementation UIWindow (OnegramIOS3GestureEventCompatibility)

+ (void)load
{
    Method original = class_getInstanceMethod(self, @selector(sendEvent:));
    Method replacement = class_getInstanceMethod(self, @selector(onegram_sendEvent:));
    if (original != NULL && replacement != NULL)
        method_exchangeImplementations(original, replacement);
}

- (void)onegram_sendEvent:(UIEvent *)event
{
    NSSet *allTouches = [event allTouches];
    NSUInteger touchCount = [allTouches count];

    if (touchCount == 1)
    {
        UITouch *touch = [allTouches anyObject];
        OnegramIOS3DispatchGestureTouches([touch view], allTouches, event);
    }
    else if (touchCount > 1)
    {
        NSMutableDictionary *touchesByView = [NSMutableDictionary dictionary];
        for (UITouch *touch in allTouches)
        {
            UIView *view = [touch view];
            if (view == nil)
                continue;
            NSValue *key = [NSValue valueWithNonretainedObject:view];
            NSMutableSet *touches = [touchesByView objectForKey:key];
            if (touches == nil)
            {
                touches = [NSMutableSet set];
                [touchesByView setObject:touches forKey:key];
            }
            [touches addObject:touch];
        }

        for (NSValue *key in touchesByView)
            OnegramIOS3DispatchGestureTouches([key nonretainedObjectValue], [touchesByView objectForKey:key], event);
    }

    [self onegram_sendEvent:event];
}

@end


@implementation UIView (OnegramIOS3AnimationCompatibilityFallback)

+ (void)onegramIOS3Fallback_performWithoutAnimation:(void (^)(void))actionsWithoutAnimation
{
    BOOL animationsEnabled = [self areAnimationsEnabled];
    [self setAnimationsEnabled:NO];
    @try
    {
        if (actionsWithoutAnimation != nil)
            actionsWithoutAnimation();
    }
    @finally
    {
        [self setAnimationsEnabled:animationsEnabled];
    }
}

+ (void)onegramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations
{
    [self beginAnimations:nil context:NULL];
    [self setAnimationDuration:duration];
    if (animations != nil)
        animations();
    [self commitAnimations];
}

+ (void)onegramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self animateWithDuration:duration delay:0.0 options:0 animations:animations completion:completion];
}

+ (void)onegramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self beginAnimations:nil context:NULL];
    [self setAnimationDuration:duration];
    [self setAnimationDelay:delay];
    [self setAnimationBeginsFromCurrentState:(options & (1UL << 2)) != 0];
    [self setAnimationRepeatAutoreverses:(options & (1UL << 4)) != 0];
    if ((options & (1UL << 3)) != 0)
        [self setAnimationRepeatCount:1.0e30f];

    NSUInteger curve = (options >> 16) & 3U;
    switch (curve)
    {
        case 1: [self setAnimationCurve:UIViewAnimationCurveEaseIn]; break;
        case 2: [self setAnimationCurve:UIViewAnimationCurveEaseOut]; break;
        case 3: [self setAnimationCurve:UIViewAnimationCurveLinear]; break;
        default: [self setAnimationCurve:UIViewAnimationCurveEaseInOut]; break;
    }

    if (animations != nil)
        animations();
    [self commitAnimations];

    if (completion != nil && (options & (1UL << 3)) == 0)
    {
        OnegramIOS3AnimationCompletionTarget *target = [[OnegramIOS3AnimationCompletionTarget alloc] initWithCompletion:completion];
        [NSTimer scheduledTimerWithTimeInterval:MAX(0.0, delay + duration) target:target selector:@selector(fire:) userInfo:nil repeats:NO];
    }
}

+ (void)onegramIOS3Fallback_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)__unused dampingRatio initialSpringVelocity:(CGFloat)__unused velocity options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self animateWithDuration:duration delay:delay options:options animations:animations completion:completion];
}

+ (void)onegramIOS3Fallback_animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    NSMutableArray *stack = OnegramIOS3KeyframeAnimationStack();
    NSDictionary *context = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble:duration], @"duration",
        [NSNumber numberWithDouble:delay], @"delay",
        [NSNumber numberWithUnsignedInteger:options], @"options",
        nil];
    [stack addObject:context];
    @try
    {
        if (animations != nil)
            animations();
    }
    @finally
    {
        [stack removeLastObject];
    }

    if (completion != nil)
    {
        OnegramIOS3AnimationCompletionTarget *target = [[OnegramIOS3AnimationCompletionTarget alloc] initWithCompletion:completion];
        [NSTimer scheduledTimerWithTimeInterval:MAX(0.0, delay + duration) target:target selector:@selector(fire:) userInfo:nil repeats:NO];
    }
}

+ (void)onegramIOS3Fallback_addKeyframeWithRelativeStartTime:(double)frameStartTime relativeDuration:(double)frameDuration animations:(void (^)(void))animations
{
    NSArray *stack = OnegramIOS3KeyframeAnimationStack();
    NSDictionary *context = [stack lastObject];
    if (context == nil)
    {
        if (animations != nil)
            animations();
        return;
    }

    NSTimeInterval duration = [[context objectForKey:@"duration"] doubleValue];
    NSTimeInterval delay = [[context objectForKey:@"delay"] doubleValue];
    NSUInteger options = [[context objectForKey:@"options"] unsignedIntegerValue];
    [self animateWithDuration:MAX(0.0, duration * frameDuration) delay:MAX(0.0, delay + duration * frameStartTime) options:options animations:animations completion:nil];
}

+ (void)onegramIOS3Fallback_transitionWithView:(UIView *)view duration:(NSTimeInterval)duration options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL))completion
{
    [self beginAnimations:nil context:NULL];
    [self setAnimationDuration:duration];
    [self setAnimationBeginsFromCurrentState:(options & (1UL << 2)) != 0];

    NSUInteger curve = (options >> 16) & 3U;
    switch (curve)
    {
        case 1: [self setAnimationCurve:UIViewAnimationCurveEaseIn]; break;
        case 2: [self setAnimationCurve:UIViewAnimationCurveEaseOut]; break;
        case 3: [self setAnimationCurve:UIViewAnimationCurveLinear]; break;
        default: [self setAnimationCurve:UIViewAnimationCurveEaseInOut]; break;
    }

    NSUInteger transition = (options >> 20) & 7U;
    switch (transition)
    {
        case 1: [self setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:view cache:YES]; break;
        case 2: [self setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:view cache:YES]; break;
        case 3: [self setAnimationTransition:UIViewAnimationTransitionCurlUp forView:view cache:YES]; break;
        case 4: [self setAnimationTransition:UIViewAnimationTransitionCurlDown forView:view cache:YES]; break;
        default: break;
    }

    if (animations != nil)
        animations();
    [self commitAnimations];

    if (completion != nil)
    {
        OnegramIOS3AnimationCompletionTarget *target = [[OnegramIOS3AnimationCompletionTarget alloc] initWithCompletion:completion];
        [NSTimer scheduledTimerWithTimeInterval:MAX(0.0, duration) target:target selector:@selector(fire:) userInfo:nil repeats:NO];
    }
}

@end


static const void *OnegramIOS3ChildViewControllersKey = &OnegramIOS3ChildViewControllersKey;
static const void *OnegramIOS3ParentViewControllerKey = &OnegramIOS3ParentViewControllerKey;
static const void *OnegramIOS3AppearanceTransitionStackKey = &OnegramIOS3AppearanceTransitionStackKey;
static BOOL OnegramIOS3HasOriginalParentViewController = NO;

@interface UIViewController (OnegramIOS3ContainmentCompatibilityImplementation)
- (void)removeChildViewController:(UIViewController *)childController;
- (NSArray *)onegramIOS3_childViewControllers;
- (void)onegramIOS3_addChildViewController:(UIViewController *)childController;
- (void)onegramIOS3_removeFromParentViewController;
- (void)onegramIOS3_willMoveToParentViewController:(UIViewController *)parent;
- (void)onegramIOS3_didMoveToParentViewController:(UIViewController *)parent;
- (void)onegramIOS3_beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated;
- (void)onegramIOS3_endAppearanceTransition;
@end

@implementation UIViewController (OnegramIOS3ContainmentCompatibility)

+ (void)load
{
    Method original = class_getInstanceMethod(self, @selector(parentViewController));
    Method replacement = class_getInstanceMethod(self, @selector(onegramIOS3_parentViewController));
    if (original != NULL && replacement != NULL)
    {
        OnegramIOS3HasOriginalParentViewController = YES;
        method_exchangeImplementations(original, replacement);
    }
    else if (replacement != NULL)
        class_addMethod(self, @selector(parentViewController), method_getImplementation(replacement), method_getTypeEncoding(replacement));

    SEL selectors[] = {
        @selector(childViewControllers),
        @selector(addChildViewController:),
        @selector(removeFromParentViewController),
        @selector(willMoveToParentViewController:),
        @selector(didMoveToParentViewController:),
        @selector(beginAppearanceTransition:animated:),
        @selector(endAppearanceTransition)
    };
    SEL replacements[] = {
        @selector(onegramIOS3_childViewControllers),
        @selector(onegramIOS3_addChildViewController:),
        @selector(onegramIOS3_removeFromParentViewController),
        @selector(onegramIOS3_willMoveToParentViewController:),
        @selector(onegramIOS3_didMoveToParentViewController:),
        @selector(onegramIOS3_beginAppearanceTransition:animated:),
        @selector(onegramIOS3_endAppearanceTransition)
    };

    for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(selectors[0]); index++)
    {
        if (class_getInstanceMethod(self, selectors[index]) != NULL)
            continue;
        Method method = class_getInstanceMethod(self, replacements[index]);
        if (method != NULL)
            class_addMethod(self, selectors[index], method_getImplementation(method), method_getTypeEncoding(method));
    }
}

- (UIViewController *)onegramIOS3_parentViewController
{
    UIViewController *parent = objc_getAssociatedObject(self, OnegramIOS3ParentViewControllerKey);
    if (parent != nil)
        return parent;
    if (OnegramIOS3HasOriginalParentViewController)
        return [self onegramIOS3_parentViewController];
    return nil;
}

- (NSArray *)onegramIOS3_childViewControllers
{
    NSMutableArray *children = objc_getAssociatedObject(self, OnegramIOS3ChildViewControllersKey);
    if (children != nil)
        return [[children copy] autorelease];
    if ([self isKindOfClass:[UINavigationController class]])
        return [(UINavigationController *)self viewControllers];
    if ([self isKindOfClass:[UITabBarController class]])
        return [(UITabBarController *)self viewControllers];
    return [NSArray array];
}

- (void)onegramIOS3_addChildViewController:(UIViewController *)childController
{
    if (childController == nil || childController == self)
        return;

    UIViewController *oldParent = objc_getAssociatedObject(childController, OnegramIOS3ParentViewControllerKey);
    if (oldParent != nil && oldParent != self)
        [childController removeFromParentViewController];

    NSMutableArray *children = objc_getAssociatedObject(self, OnegramIOS3ChildViewControllersKey);
    if (children == nil)
    {
        children = [NSMutableArray array];
        objc_setAssociatedObject(self, OnegramIOS3ChildViewControllersKey, children, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (![children containsObject:childController])
    {
        [childController willMoveToParentViewController:self];
        [children addObject:childController];
        objc_setAssociatedObject(childController, OnegramIOS3ParentViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
        [childController didMoveToParentViewController:self];
    }
}

- (void)onegramIOS3_removeFromParentViewController
{
    UIViewController *parent = [self parentViewController];
    if (parent == nil)
        return;
    [self willMoveToParentViewController:nil];
    NSMutableArray *children = objc_getAssociatedObject(parent, OnegramIOS3ChildViewControllersKey);
    [children removeObjectIdenticalTo:self];
    if ([parent respondsToSelector:@selector(removeChildViewController:)])
        [parent removeChildViewController:self];
    objc_setAssociatedObject(self, OnegramIOS3ParentViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
    [self didMoveToParentViewController:nil];
}

- (void)onegramIOS3_willMoveToParentViewController:(UIViewController *)parent
{
}

- (void)onegramIOS3_didMoveToParentViewController:(UIViewController *)parent
{
}

- (void)onegramIOS3_beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated
{
    NSMutableArray *stack = objc_getAssociatedObject(self, OnegramIOS3AppearanceTransitionStackKey);
    if (stack == nil)
    {
        stack = [NSMutableArray array];
        objc_setAssociatedObject(self, OnegramIOS3AppearanceTransitionStackKey, stack, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [stack addObject:[NSArray arrayWithObjects:[NSNumber numberWithBool:isAppearing], [NSNumber numberWithBool:animated], nil]];

    if (isAppearing)
        [self viewWillAppear:animated];
    else
        [self viewWillDisappear:animated];
}

- (void)onegramIOS3_endAppearanceTransition
{
    NSMutableArray *stack = objc_getAssociatedObject(self, OnegramIOS3AppearanceTransitionStackKey);
    if ([stack count] == 0)
        return;

    NSArray *transition = [stack lastObject];
    BOOL isAppearing = [[transition objectAtIndex:0] boolValue];
    BOOL animated = [[transition objectAtIndex:1] boolValue];
    [stack removeLastObject];

    if (isAppearing)
        [self viewDidAppear:animated];
    else
        [self viewDidDisappear:animated];

    if ([stack count] == 0)
        objc_setAssociatedObject(self, OnegramIOS3AppearanceTransitionStackKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static const void *OnegramIOS3PopoverContentSizeKey = &OnegramIOS3PopoverContentSizeKey;

@implementation UIViewController (OnegramIOS3PopoverCompatibilityFallback)

- (CGSize)onegramIOS3Fallback_contentSizeForViewInPopover
{
    NSValue *value = objc_getAssociatedObject(self, OnegramIOS3PopoverContentSizeKey);
    return value == nil ? CGSizeZero : [value CGSizeValue];
}
- (void)onegramIOS3Fallback_setContentSizeForViewInPopover:(CGSize)size
{
    objc_setAssociatedObject(self, OnegramIOS3PopoverContentSizeKey, [NSValue valueWithCGSize:size], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@end

@implementation UIPopoverBackgroundView
+ (CGFloat)arrowHeight { return 0.0f; }
+ (CGFloat)arrowBase { return 0.0f; }
+ (UIEdgeInsets)contentViewInsets { return UIEdgeInsetsZero; }
- (CGFloat)arrowOffset { return 0.0f; }
- (void)setArrowOffset:(CGFloat)value { }
- (UIPopoverArrowDirection)arrowDirection { return UIPopoverArrowDirectionUnknown; }
- (void)setArrowDirection:(UIPopoverArrowDirection)value { }
+ (BOOL)wantsDefaultContentAppearance { return YES; }
@end

@implementation UIPopoverController

- (instancetype)initWithContentViewController:(UIViewController *)viewController
{
    self = [super init];
    if (self != nil)
        _onegramContentViewController = [viewController retain];
    return self;
}

- (void)dealloc
{
    [_onegramContentViewController release];
    [super dealloc];
}

- (UIViewController *)contentViewController { return _onegramContentViewController; }
- (void)setContentViewController:(UIViewController *)controller { if (_onegramContentViewController != controller) { [_onegramContentViewController release]; _onegramContentViewController = [controller retain]; } }
- (id<UIPopoverControllerDelegate>)delegate { return _onegramPopoverDelegate; }
- (void)setDelegate:(id<UIPopoverControllerDelegate>)delegate { _onegramPopoverDelegate = delegate; }
- (CGSize)popoverContentSize { return _onegramPopoverContentSize; }
- (void)setPopoverContentSize:(CGSize)size { _onegramPopoverContentSize = size; }
- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated { _onegramPopoverContentSize = size; }
- (Class)popoverBackgroundViewClass { return Nil; }
- (void)setPopoverBackgroundViewClass:(Class)value { }

- (void)presentPopoverFromRect:(CGRect)rect inView:(UIView *)view permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated
{
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (window != nil && _onegramContentViewController != nil)
    {
        UIView *contentView = [_onegramContentViewController view];
        if (!CGSizeEqualToSize(_onegramPopoverContentSize, CGSizeZero))
            contentView.frame = CGRectMake(0.0f, 0.0f, _onegramPopoverContentSize.width, _onegramPopoverContentSize.height);
        contentView.center = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds));
        [window addSubview:contentView];
    }
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)item permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated
{
    [self presentPopoverFromRect:CGRectZero inView:nil permittedArrowDirections:arrowDirections animated:animated];
}

- (void)dismissPopoverAnimated:(BOOL)animated
{
    [[_onegramContentViewController view] removeFromSuperview];
    if ([_onegramPopoverDelegate respondsToSelector:@selector(popoverControllerDidDismissPopover:)])
        [_onegramPopoverDelegate popoverControllerDidDismissPopover:self];
}

@end

#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@implementation UINib

+ (UINib *)nibWithNibName:(NSString *)name bundle:(NSBundle *)bundle
{
    UINib *nib = [[[self alloc] init] autorelease];
    nib->_name = [name copy];
    nib->_bundle = [bundle retain];
    return nib;
}

- (void)dealloc
{
    [_name release];
    [_bundle release];
    [super dealloc];
}

- (NSArray *)instantiateWithOwner:(id)owner options:(NSDictionary *)options
{
    NSBundle *bundle = _bundle == nil ? [NSBundle mainBundle] : _bundle;
    return [bundle loadNibNamed:_name owner:owner options:options];
}

@end
#endif

void (*OnegramIOS3OffMainGraphicsHandler)(const void *caller) = NULL;

void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale)
{
    if (OnegramIOS3OffMainGraphicsHandler != NULL && !pthread_main_np())
        OnegramIOS3OffMainGraphicsHandler(__builtin_return_address(0));
    UIGraphicsBeginImageContext(size);
}

static UIImage *OnegramIOS3ImageWithCGImageOrientation(CGImageRef cgImage, UIImageOrientation orientation)
{
    if (cgImage == NULL)
        return nil;

    CGFloat width = (CGFloat)CGImageGetWidth(cgImage);
    CGFloat height = (CGFloat)CGImageGetHeight(cgImage);
    BOOL sideward = orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight || orientation == UIImageOrientationLeftMirrored || orientation == UIImageOrientationRightMirrored;
    CGSize outputSize = sideward ? CGSizeMake(height, width) : CGSizeMake(width, height);

    UIGraphicsBeginImageContext(outputSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGAffineTransform transform = CGAffineTransformIdentity;

    switch (orientation)
    {
        case UIImageOrientationUpMirrored:
            transform = CGAffineTransformMake(-1.0f, 0.0f, 0.0f, 1.0f, width, 0.0f);
            break;
        case UIImageOrientationDown:
            transform = CGAffineTransformMake(-1.0f, 0.0f, 0.0f, -1.0f, width, height);
            break;
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, height);
            break;
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformMake(0.0f, 1.0f, 1.0f, 0.0f, 0.0f, 0.0f);
            break;
        case UIImageOrientationRight:
            transform = CGAffineTransformMake(0.0f, 1.0f, -1.0f, 0.0f, height, 0.0f);
            break;
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformMake(0.0f, -1.0f, -1.0f, 0.0f, height, width);
            break;
        case UIImageOrientationLeft:
            transform = CGAffineTransformMake(0.0f, -1.0f, 1.0f, 0.0f, 0.0f, width);
            break;
        case UIImageOrientationUp:
        default:
            break;
    }

    CGContextConcatCTM(context, transform);
    UIImage *sourceImage = [UIImage imageWithCGImage:cgImage];
    [sourceImage drawInRect:CGRectMake(0.0f, 0.0f, width, height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@implementation UIImage (OnegramIOS3ScaleCompatibilityFallback)

- (CGFloat)onegramIOS3Fallback_scale
{
    return 1.0f;
}

+ (UIImage *)onegramIOS3Fallback_imageWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    return [[[self alloc] initWithCGImage:cgImage scale:scale orientation:orientation] autorelease];
}

- (instancetype)onegramIOS3Fallback_initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    if (cgImage == NULL)
    {
        [self release];
        return nil;
    }

    CGFloat normalizedScale = scale > 0.0f ? scale : 1.0f;
    if (normalizedScale == 1.0f && orientation == UIImageOrientationUp)
        return [self initWithCGImage:cgImage];

    UIImage *image = orientation == UIImageOrientationUp ? [UIImage imageWithCGImage:cgImage] : OnegramIOS3ImageWithCGImageOrientation(cgImage, orientation);
    if (image == nil || image.CGImage == NULL)
    {
        [self release];
        return nil;
    }

    if (normalizedScale == 1.0f)
        return [self initWithCGImage:image.CGImage];

    CGSize targetSize = CGSizeMake(MAX(1.0f, (CGFloat)CGImageGetWidth(image.CGImage) / normalizedScale), MAX(1.0f, (CGFloat)CGImageGetHeight(image.CGImage) / normalizedScale));
    UIGraphicsBeginImageContext(targetSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context != NULL)
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (scaledImage == nil || scaledImage.CGImage == NULL)
    {
        [self release];
        return nil;
    }
    return [self initWithCGImage:scaledImage.CGImage];
}

- (UIImage *)onegramIOS3Fallback_resizableImageWithCapInsets:(UIEdgeInsets)capInsets
{
    NSInteger left = (NSInteger)floor(capInsets.left);
    NSInteger top = (NSInteger)floor(capInsets.top);
    NSInteger maxLeft = MAX(0, (NSInteger)floor(self.size.width) - 1);
    NSInteger maxTop = MAX(0, (NSInteger)floor(self.size.height) - 1);
    left = MAX(0, MIN(left, maxLeft));
    top = MAX(0, MIN(top, maxTop));
    return [self stretchableImageWithLeftCapWidth:left topCapHeight:top];
}

@end

@implementation UIScreen (OnegramIOS3ScaleCompatibilityFallback)

- (CGFloat)onegramIOS3Fallback_scale
{
    return 1.0f;
}

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@implementation UIDevice (OnegramIOS3InterfaceIdiomCompatibilityFallback)

- (UIUserInterfaceIdiom)onegramIOS3Fallback_userInterfaceIdiom
{
    return UIUserInterfaceIdiomPhone;
}

@end

static char OnegramIOS3ModalPresentationStyleKey;
static char OnegramIOS3PresentingViewControllerKey;

@implementation UIViewController (OnegramIOS3PresentationCompatibilityFallback)

- (void)onegramIOS3Fallback_setModalPresentationStyle:(UIModalPresentationStyle)modalPresentationStyle
{
    objc_setAssociatedObject(self, &OnegramIOS3ModalPresentationStyleKey, [NSNumber numberWithInteger:modalPresentationStyle], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIModalPresentationStyle)onegramIOS3Fallback_modalPresentationStyle
{
    NSNumber *value = objc_getAssociatedObject(self, &OnegramIOS3ModalPresentationStyleKey);
    return value == nil ? UIModalPresentationFullScreen : (UIModalPresentationStyle)[value integerValue];
}

- (UIViewController *)onegramIOS3Fallback_presentedViewController
{
    return self.modalViewController;
}

- (UIViewController *)onegramIOS3Fallback_presentingViewController
{
    UIViewController *presenter = objc_getAssociatedObject(self, &OnegramIOS3PresentingViewControllerKey);
    if (presenter != nil)
        return presenter;

    UIViewController *parent = self.parentViewController;
    while (parent != nil && parent != self)
    {
        presenter = objc_getAssociatedObject(parent, &OnegramIOS3PresentingViewControllerKey);
        if (presenter != nil)
            return presenter;
        UIViewController *nextParent = parent.parentViewController;
        if (nextParent == parent)
            break;
        parent = nextParent;
    }

    return nil;
}

- (void)onegramIOS3Fallback_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)animated completion:(void (^)(void))completion
{
    if (viewControllerToPresent != nil)
        objc_setAssociatedObject(viewControllerToPresent, &OnegramIOS3PresentingViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
    [self presentModalViewController:viewControllerToPresent animated:animated];
    if (completion != nil)
        completion();
}

- (void)onegramIOS3Fallback_dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion
{
    UIViewController *presenter = [self presentingViewController];
    if (presenter != nil)
    {
        objc_setAssociatedObject(self, &OnegramIOS3PresentingViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
        [presenter dismissModalViewControllerAnimated:animated];
    }
    else
    {
        UIViewController *presented = self.modalViewController;
        if (presented != nil)
            objc_setAssociatedObject(presented, &OnegramIOS3PresentingViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
        [self dismissModalViewControllerAnimated:animated];
    }
    if (completion != nil)
        completion();
}

@end
#endif


@implementation TGIOS3OrderedSet

- (instancetype)initWithArray:(NSArray *)array
{
    self = [super init];
    if (self != nil)
    {
        NSMutableArray *objects = [[NSMutableArray alloc] init];
        for (id object in array)
        {
            if (![objects containsObject:object])
                [objects addObject:object];
        }
        _onegramObjects = [objects copy];
        [objects release];
    }
    return self;
}

- (void)dealloc
{
    [_onegramObjects release];
    [super dealloc];
}

- (NSUInteger)count
{
    return [_onegramObjects count];
}

- (NSArray *)array
{
    return _onegramObjects;
}

- (id)objectAtIndex:(NSUInteger)index
{
    return [_onegramObjects objectAtIndex:index];
}

- (BOOL)containsObject:(id)object
{
    return [_onegramObjects containsObject:object];
}

- (NSArray *)allObjects
{
    return _onegramObjects;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len
{
    return [_onegramObjects countByEnumeratingWithState:state objects:buffer count:len];
}

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@implementation TGIOS3MutableParagraphStyle

@synthesize lineSpacing = _lineSpacing;
@synthesize lineBreakMode = _lineBreakMode;
@synthesize alignment = _alignment;
@synthesize paragraphSpacing = _paragraphSpacing;
@synthesize firstLineHeadIndent = _firstLineHeadIndent;
@synthesize lineHeightMultiple = _lineHeightMultiple;

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _lineBreakMode = NSLineBreakByWordWrapping;
        _alignment = NSTextAlignmentLeft;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    TGIOS3MutableParagraphStyle *copy = [[[self class] allocWithZone:zone] init];
    copy.lineSpacing = _lineSpacing;
    copy.lineBreakMode = _lineBreakMode;
    copy.alignment = _alignment;
    copy.paragraphSpacing = _paragraphSpacing;
    copy.firstLineHeadIndent = _firstLineHeadIndent;
    copy.lineHeightMultiple = _lineHeightMultiple;
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

@end
#endif

@interface TGIOS3AttributedString ()
{
@protected
    NSUInteger _onegramRunCount;
    NSUInteger _onegramRunCapacity;
    NSUInteger *_onegramRunStarts;
    NSDictionary **_onegramRunAttributes;
}
- (void)onegram_ensureRunCapacity:(NSUInteger)capacity;
- (void)onegram_insertRunAtIndex:(NSUInteger)index start:(NSUInteger)start attributes:(NSDictionary *)attributes;
- (void)onegram_removeRunsInRange:(NSRange)runRange;
- (NSUInteger)onegram_runEnd:(NSUInteger)index;
- (NSUInteger)onegram_runIndexForLocation:(NSUInteger)location;
- (NSUInteger)onegram_splitAtLocation:(NSUInteger)location;
- (void)onegram_normalizeRuns;
- (void)onegram_replaceCharactersInRange:(NSRange)range withString:(NSString *)string attributes:(NSDictionary *)attributes;
@end

@implementation TGIOS3AttributedString

- (instancetype)init
{
    return [self initWithString:@""];
}

- (instancetype)initWithString:(NSString *)string
{
    return [self initWithString:string attributes:nil];
}

- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes
{
    self = [super init];
    if (self != nil)
    {
        _onegramString = [(string == nil ? @"" : string) mutableCopy];
        if ([_onegramString length] != 0)
            [self onegram_insertRunAtIndex:0 start:0 attributes:attributes];
    }
    return self;
}

- (instancetype)initWithAttributedString:(TGIOS3AttributedString *)attributedString
{
    self = [self initWithString:[attributedString string] attributes:nil];
    if (self != nil)
    {
        [self onegram_removeRunsInRange:NSMakeRange(0, _onegramRunCount)];
        NSUInteger index = 0;
        NSUInteger length = [attributedString length];
        while (index < length)
        {
            NSRange range = NSMakeRange(index, 1);
            NSDictionary *attributes = [attributedString attributesAtIndex:index effectiveRange:&range];
            if (range.location != index || range.length == 0)
                range = NSMakeRange(index, 1);
            [self onegram_insertRunAtIndex:_onegramRunCount start:index attributes:attributes];
            index = NSMaxRange(range);
        }
        [self onegram_normalizeRuns];
    }
    return self;
}

- (void)dealloc
{
    [self onegram_removeRunsInRange:NSMakeRange(0, _onegramRunCount)];
    free(_onegramRunStarts);
    free(_onegramRunAttributes);
    [_onegramString release];
    [super dealloc];
}

- (void)onegram_ensureRunCapacity:(NSUInteger)capacity
{
    if (capacity <= _onegramRunCapacity)
        return;
    NSUInteger newCapacity = MAX(capacity, MAX((NSUInteger)4, _onegramRunCapacity * 2));
    NSUInteger *starts = (NSUInteger *)realloc(_onegramRunStarts, newCapacity * sizeof(NSUInteger));
    if (starts == NULL)
        return;
    _onegramRunStarts = starts;
    NSDictionary **attributes = (NSDictionary **)realloc(_onegramRunAttributes, newCapacity * sizeof(NSDictionary *));
    if (attributes == NULL)
        return;
    _onegramRunAttributes = attributes;
    _onegramRunCapacity = newCapacity;
}

- (void)onegram_insertRunAtIndex:(NSUInteger)index start:(NSUInteger)start attributes:(NSDictionary *)attributes
{
    [self onegram_ensureRunCapacity:_onegramRunCount + 1];
    if (_onegramRunCount + 1 > _onegramRunCapacity)
        return;
    memmove(_onegramRunStarts + index + 1, _onegramRunStarts + index, (_onegramRunCount - index) * sizeof(NSUInteger));
    memmove(_onegramRunAttributes + index + 1, _onegramRunAttributes + index, (_onegramRunCount - index) * sizeof(NSDictionary *));
    _onegramRunStarts[index] = start;
    _onegramRunAttributes[index] = [(attributes == nil ? [NSDictionary dictionary] : attributes) copy];
    _onegramRunCount++;
}

- (void)onegram_removeRunsInRange:(NSRange)runRange
{
    if (runRange.length == 0)
        return;
    for (NSUInteger index = runRange.location; index < NSMaxRange(runRange); index++)
        [_onegramRunAttributes[index] release];
    NSUInteger tail = _onegramRunCount - NSMaxRange(runRange);
    memmove(_onegramRunStarts + runRange.location, _onegramRunStarts + NSMaxRange(runRange), tail * sizeof(NSUInteger));
    memmove(_onegramRunAttributes + runRange.location, _onegramRunAttributes + NSMaxRange(runRange), tail * sizeof(NSDictionary *));
    _onegramRunCount -= runRange.length;
}

- (NSUInteger)onegram_runEnd:(NSUInteger)index
{
    return index + 1 < _onegramRunCount ? _onegramRunStarts[index + 1] : [_onegramString length];
}

- (NSUInteger)onegram_runIndexForLocation:(NSUInteger)location
{
    NSUInteger low = 0;
    NSUInteger high = _onegramRunCount;
    while (high - low > 1)
    {
        NSUInteger middle = low + (high - low) / 2;
        if (_onegramRunStarts[middle] <= location)
            low = middle;
        else
            high = middle;
    }
    return low;
}

- (NSUInteger)onegram_splitAtLocation:(NSUInteger)location
{
    if (location >= [_onegramString length] || _onegramRunCount == 0)
        return _onegramRunCount;
    NSUInteger index = [self onegram_runIndexForLocation:location];
    if (_onegramRunStarts[index] == location)
        return index;
    [self onegram_insertRunAtIndex:index + 1 start:location attributes:_onegramRunAttributes[index]];
    return index + 1;
}

- (void)onegram_normalizeRuns
{
    NSUInteger index = 0;
    while (index < _onegramRunCount)
    {
        if ([self onegram_runEnd:index] <= _onegramRunStarts[index])
        {
            [self onegram_removeRunsInRange:NSMakeRange(index, 1)];
            continue;
        }
        if (index > 0 && [_onegramRunAttributes[index - 1] isEqual:_onegramRunAttributes[index]])
        {
            [self onegram_removeRunsInRange:NSMakeRange(index, 1)];
            continue;
        }
        index++;
    }
}

- (void)onegram_replaceCharactersInRange:(NSRange)range withString:(NSString *)string attributes:(NSDictionary *)attributes
{
    NSDictionary *runAttributes = [(attributes == nil ? [NSDictionary dictionary] : attributes) copy];
    NSString *replacement = [(string == nil ? @"" : string) copy];
    NSUInteger length = [_onegramString length];
    NSUInteger location = MIN(range.location, length);
    NSUInteger end = MIN(MAX(NSMaxRange(range), location), length);
    NSUInteger first = [self onegram_splitAtLocation:location];
    NSUInteger last = [self onegram_splitAtLocation:end];
    [self onegram_removeRunsInRange:NSMakeRange(first, last - first)];
    [_onegramString replaceCharactersInRange:NSMakeRange(location, end - location) withString:replacement];
    NSUInteger replacementLength = [replacement length];
    for (NSUInteger index = first; index < _onegramRunCount; index++)
        _onegramRunStarts[index] = _onegramRunStarts[index] - (end - location) + replacementLength;
    if (replacementLength != 0)
        [self onegram_insertRunAtIndex:first start:location attributes:runAttributes];
    [self onegram_normalizeRuns];
    [replacement release];
    [runAttributes release];
}

- (NSString *)string
{
    return _onegramString;
}

- (NSUInteger)length
{
    return [_onegramString length];
}

- (CGSize)size
{
    CGFloat width = 0.0f;
    CGFloat height = 0.0f;
    NSUInteger index = 0;
    while (index < [self length])
    {
        NSRange range = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&range];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        if (![font isKindOfClass:[UIFont class]])
            font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        NSString *substring = [_onegramString substringWithRange:range];
        CGSize runSize = [substring sizeWithFont:font];
        width += runSize.width;
        height = MAX(height, runSize.height);
        index = NSMaxRange(range);
    }
    return CGSizeMake(width, height);
}

- (void)drawAtPoint:(CGPoint)point
{
    CGFloat x = point.x;
    NSUInteger index = 0;
    while (index < [self length])
    {
        NSRange range = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&range];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        if (![font isKindOfClass:[UIFont class]])
            font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
        UIColor *color = [attributes objectForKey:@"NSColor"];
        if ([color isKindOfClass:[UIColor class]])
            [color set];
        NSString *substring = [_onegramString substringWithRange:range];
        [substring drawAtPoint:CGPointMake(x, point.y) withFont:font];
        x += [substring sizeWithFont:font].width;
        index = NSMaxRange(range);
    }
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    if (location >= [_onegramString length] || _onegramRunCount == 0)
    {
        if (range != NULL)
            *range = NSMakeRange(NSNotFound, 0);
        return [NSDictionary dictionary];
    }
    NSUInteger index = [self onegram_runIndexForLocation:location];
    if (range != NULL)
        *range = NSMakeRange(_onegramRunStarts[index], [self onegram_runEnd:index] - _onegramRunStarts[index]);
    return _onegramRunAttributes[index];
}

- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    return [[self attributesAtIndex:location effectiveRange:range] objectForKey:attributeName];
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit
{
    NSRange effectiveRange = NSMakeRange(NSNotFound, 0);
    NSDictionary *attributes = [self attributesAtIndex:location effectiveRange:&effectiveRange];
    if (range != NULL)
        *range = effectiveRange.location == NSNotFound ? effectiveRange : NSIntersectionRange(effectiveRange, rangeLimit);
    return attributes;
}

- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit
{
    if (location >= [_onegramString length] || _onegramRunCount == 0)
    {
        if (range != NULL)
            *range = NSMakeRange(NSNotFound, 0);
        return nil;
    }
    NSUInteger index = [self onegram_runIndexForLocation:location];
    id value = [_onegramRunAttributes[index] objectForKey:attributeName];
    if (range != NULL)
    {
        NSUInteger first = index;
        while (first > 0)
        {
            id candidate = [_onegramRunAttributes[first - 1] objectForKey:attributeName];
            if (candidate != value && ![candidate isEqual:value])
                break;
            first--;
        }
        NSUInteger last = index;
        while (last + 1 < _onegramRunCount)
        {
            id candidate = [_onegramRunAttributes[last + 1] objectForKey:attributeName];
            if (candidate != value && ![candidate isEqual:value])
                break;
            last++;
        }
        NSUInteger lowerBound = MIN(rangeLimit.location, [_onegramString length]);
        NSUInteger upperBound = MIN(NSMaxRange(rangeLimit), [_onegramString length]);
        NSUInteger start = MAX(_onegramRunStarts[first], lowerBound);
        NSUInteger end = MIN([self onegram_runEnd:last], upperBound);
        *range = NSMakeRange(start, end > start ? end - start : 0);
    }
    return value;
}

- (TGIOS3AttributedString *)attributedSubstringFromRange:(NSRange)range
{
    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    TGIOS3MutableAttributedString *result = [[[TGIOS3MutableAttributedString alloc] initWithString:[_onegramString substringWithRange:validRange]] autorelease];
    NSUInteger index = validRange.location;
    while (index < NSMaxRange(validRange))
    {
        NSRange runRange = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&runRange];
        NSRange intersection = NSIntersectionRange(runRange, validRange);
        if (intersection.length == 0)
            break;
        [result setAttributes:attributes range:NSMakeRange(intersection.location - validRange.location, intersection.length)];
        index = NSMaxRange(intersection);
    }
    return result;
}

- (BOOL)isEqualToAttributedString:(TGIOS3AttributedString *)other
{
    if (other == nil || [self length] != [other length] || ![[self string] isEqualToString:[other string]])
        return NO;
    NSUInteger index = 0;
    while (index < [self length])
    {
        NSRange range = NSMakeRange(index, 1);
        NSRange otherRange = NSMakeRange(index, 1);
        NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&range];
        NSDictionary *otherAttributes = [other attributesAtIndex:index effectiveRange:&otherRange];
        if (![attributes isEqual:otherAttributes])
            return NO;
        index = MIN(NSMaxRange(range), NSMaxRange(otherRange));
    }
    return YES;
}

- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(NSUInteger)opts usingBlock:(void (^)(NSDictionary *, NSRange, BOOL *))block
{
    if (block == nil)
        return;
    NSRange validRange = NSIntersectionRange(enumerationRange, NSMakeRange(0, [self length]));
    BOOL stop = NO;
    if ((opts & (1 << 1)) != 0)
    {
        NSUInteger index = NSMaxRange(validRange);
        while (index > validRange.location && !stop)
        {
            index--;
            NSRange effectiveRange;
            NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&effectiveRange];
            effectiveRange = NSIntersectionRange(effectiveRange, validRange);
            block(attributes, effectiveRange, &stop);
            index = effectiveRange.location;
        }
    }
    else
    {
        NSUInteger index = validRange.location;
        while (index < NSMaxRange(validRange) && !stop)
        {
            NSRange effectiveRange;
            NSDictionary *attributes = [self attributesAtIndex:index effectiveRange:&effectiveRange];
            effectiveRange = NSIntersectionRange(effectiveRange, validRange);
            block(attributes, effectiveRange, &stop);
            index = NSMaxRange(effectiveRange);
        }
    }
}

- (void)enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(NSUInteger)opts usingBlock:(void (^)(id, NSRange, BOOL *))block
{
    if (block == nil)
        return;
    [self enumerateAttributesInRange:enumerationRange options:opts usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
        block([attributes objectForKey:attrName], range, stop);
    }];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[TGIOS3MutableAttributedString allocWithZone:zone] initWithAttributedString:self];
}

@end

@implementation TGIOS3MutableAttributedString

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string
{
    NSUInteger location = MIN(range.location, [self length]);
    NSDictionary *attributes = location < [self length] ? [self attributesAtIndex:location effectiveRange:NULL] : [NSDictionary dictionary];
    [self onegram_replaceCharactersInRange:range withString:string attributes:attributes];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range
{
    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    if (validRange.length == 0)
        return;
    NSDictionary *runAttributes = [(attributes == nil ? [NSDictionary dictionary] : attributes) copy];
    NSUInteger first = [self onegram_splitAtLocation:validRange.location];
    NSUInteger last = [self onegram_splitAtLocation:NSMaxRange(validRange)];
    [self onegram_removeRunsInRange:NSMakeRange(first, last - first)];
    [self onegram_insertRunAtIndex:first start:validRange.location attributes:runAttributes];
    [self onegram_normalizeRuns];
    [runAttributes release];
}

- (void)onegram_updateAttributesInRange:(NSRange)range usingBlock:(void (^)(NSMutableDictionary *attributes))block
{
    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    if (validRange.length == 0)
        return;
    NSUInteger first = [self onegram_splitAtLocation:validRange.location];
    NSUInteger last = [self onegram_splitAtLocation:NSMaxRange(validRange)];
    for (NSUInteger index = first; index < last; index++)
    {
        NSMutableDictionary *attributes = [_onegramRunAttributes[index] mutableCopy];
        block(attributes);
        [_onegramRunAttributes[index] release];
        _onegramRunAttributes[index] = [attributes copy];
        [attributes release];
    }
    [self onegram_normalizeRuns];
}

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range
{
    if (name == nil || value == nil)
        return;
    [self onegram_updateAttributesInRange:range usingBlock:^(NSMutableDictionary *attributes)
    {
        [attributes setObject:value forKey:name];
    }];
}

- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)range
{
    if ([attributes count] == 0)
        return;
    [self onegram_updateAttributesInRange:range usingBlock:^(NSMutableDictionary *current)
    {
        [current addEntriesFromDictionary:attributes];
    }];
}

- (void)removeAttribute:(NSString *)name range:(NSRange)range
{
    if (name == nil)
        return;
    [self onegram_updateAttributesInRange:range usingBlock:^(NSMutableDictionary *attributes)
    {
        [attributes removeObjectForKey:name];
    }];
}

- (void)appendAttributedString:(TGIOS3AttributedString *)attributedString
{
    [self insertAttributedString:attributedString atIndex:[self length]];
}

- (void)insertAttributedString:(TGIOS3AttributedString *)attributedString atIndex:(NSUInteger)index
{
    if (attributedString == nil || index > [self length])
        return;
    TGIOS3AttributedString *source = attributedString == self ? [[self copy] autorelease] : attributedString;
    [self onegram_replaceCharactersInRange:NSMakeRange(index, 0) withString:[source string] attributes:nil];
    NSUInteger offset = 0;
    NSUInteger length = [source length];
    while (offset < length)
    {
        NSRange range = NSMakeRange(offset, 1);
        NSDictionary *attributes = [source attributesAtIndex:offset effectiveRange:&range];
        if (range.location != offset || range.length == 0)
            range = NSMakeRange(offset, 1);
        NSUInteger end = MIN(NSMaxRange(range), length);
        [self setAttributes:attributes range:NSMakeRange(index + offset, end - offset)];
        offset = end;
    }
}

- (void)deleteCharactersInRange:(NSRange)range
{
    [self replaceCharactersInRange:range withString:@""];
}

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(TGIOS3AttributedString *)attributedString
{
    TGIOS3AttributedString *source = attributedString == self ? [[self copy] autorelease] : attributedString;
    NSUInteger location = MIN(range.location, [self length]);
    NSUInteger end = MIN(MAX(NSMaxRange(range), location), [self length]);
    [self deleteCharactersInRange:NSMakeRange(location, end - location)];
    [self insertAttributedString:source atIndex:location];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[TGIOS3AttributedString allocWithZone:zone] initWithAttributedString:self];
}

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000

static BOOL OnegramIOS3IsLowSurrogate(unichar value)
{
    return value >= 0xdc00 && value <= 0xdfff;
}

static BOOL OnegramIOS3IsHighSurrogate(unichar value)
{
    return value >= 0xd800 && value <= 0xdbff;
}

static uint32_t OnegramIOS3CodePointAtIndex(NSString *string, NSUInteger index, NSUInteger *length)
{
    unichar high = [string characterAtIndex:index];
    if (OnegramIOS3IsHighSurrogate(high) && index + 1 < [string length])
    {
        unichar low = [string characterAtIndex:index + 1];
        if (OnegramIOS3IsLowSurrogate(low))
        {
            if (length != NULL)
                *length = 2;
            return (((uint32_t)high - 0xd800) << 10) + ((uint32_t)low - 0xdc00) + 0x10000;
        }
    }
    if (length != NULL)
        *length = 1;
    return high;
}

static BOOL OnegramIOS3IsCombiningCodePoint(uint32_t value)
{
    return (value >= 0x0300 && value <= 0x036f) ||
        (value >= 0x1ab0 && value <= 0x1aff) ||
        (value >= 0x1dc0 && value <= 0x1dff) ||
        (value >= 0x20d0 && value <= 0x20ff) ||
        (value >= 0xfe20 && value <= 0xfe2f) ||
        (value >= 0xfe00 && value <= 0xfe0f) ||
        (value >= 0x1f3fb && value <= 0x1f3ff) ||
        (value >= 0xe0100 && value <= 0xe01ef);
}

static NSRange OnegramIOS3ComposedRange(NSString *string, NSUInteger index, NSUInteger limit)
{
    NSUInteger scalarLength = 0;
    OnegramIOS3CodePointAtIndex(string, index, &scalarLength);
    NSUInteger end = MIN(index + scalarLength, limit);
    while (end < limit)
    {
        NSUInteger nextLength = 0;
        uint32_t next = OnegramIOS3CodePointAtIndex(string, end, &nextLength);
        if (OnegramIOS3IsCombiningCodePoint(next))
        {
            end = MIN(end + nextLength, limit);
            continue;
        }
        if (next == 0x200d)
        {
            end = MIN(end + nextLength, limit);
            if (end < limit)
            {
                NSUInteger joinedLength = 0;
                OnegramIOS3CodePointAtIndex(string, end, &joinedLength);
                end = MIN(end + joinedLength, limit);
            }
            continue;
        }
        break;
    }
    return NSMakeRange(index, end - index);
}

@implementation NSString (OnegramIOS3EnumerationCompatibilityFallback)

- (void)onegramIOS3Fallback_enumerateSubstringsInRange:(NSRange)range options:(NSStringEnumerationOptions)opts usingBlock:(void (^)(NSString *, NSRange, NSRange, BOOL *))block
{
    if (block == nil)
        return;

    NSRange validRange = NSIntersectionRange(range, NSMakeRange(0, [self length]));
    if ((opts & 0xff) != NSStringEnumerationByComposedCharacterSequences)
    {
        BOOL stop = NO;
        NSString *substring = [self substringWithRange:validRange];
        block((opts & NSStringEnumerationSubstringNotRequired) != 0 ? nil : substring, validRange, validRange, &stop);
        return;
    }

    NSMutableArray *ranges = [NSMutableArray array];
    NSUInteger index = validRange.location;
    NSUInteger limit = NSMaxRange(validRange);
    while (index < limit)
    {
        NSRange composedRange = OnegramIOS3ComposedRange(self, index, limit);
        [ranges addObject:[NSValue valueWithRange:composedRange]];
        index = NSMaxRange(composedRange);
    }

    BOOL stop = NO;
    if ((opts & NSStringEnumerationReverse) != 0)
    {
        NSUInteger count = [ranges count];
        while (count > 0 && !stop)
        {
            NSRange composedRange = [[ranges objectAtIndex:--count] rangeValue];
            NSString *substring = (opts & NSStringEnumerationSubstringNotRequired) != 0 ? nil : [self substringWithRange:composedRange];
            block(substring, composedRange, composedRange, &stop);
        }
    }
    else
    {
        for (NSValue *value in ranges)
        {
            NSRange composedRange = [value rangeValue];
            NSString *substring = (opts & NSStringEnumerationSubstringNotRequired) != 0 ? nil : [self substringWithRange:composedRange];
            block(substring, composedRange, composedRange, &stop);
            if (stop)
                break;
        }
    }
}

- (void)onegramIOS3Fallback_enumerateLinesUsingBlock:(void (^)(NSString *, BOOL *))block
{
    if (block == nil)
        return;

    NSUInteger length = [self length];
    NSUInteger start = 0;
    BOOL stop = NO;

    while (start < length && !stop)
    {
        NSUInteger end = start;
        while (end < length)
        {
            unichar character = [self characterAtIndex:end];
            if (character == '\r' || character == '\n')
                break;
            end++;
        }

        block([self substringWithRange:NSMakeRange(start, end - start)], &stop);
        if (stop || end >= length)
            break;

        unichar separator = [self characterAtIndex:end++];
        if (separator == '\r' && end < length && [self characterAtIndex:end] == '\n')
            end++;
        start = end;
    }
}

@end

static char OnegramIOS3LabelAttributedTextKey;

@implementation UILabel (OnegramIOS3AttributedTextCompatibilityFallback)

- (TGIOS3AttributedString *)onegramIOS3Fallback_attributedText
{
    return objc_getAssociatedObject(self, &OnegramIOS3LabelAttributedTextKey);
}

- (void)onegramIOS3Fallback_setAttributedText:(TGIOS3AttributedString *)attributedText
{
    objc_setAssociatedObject(self, &OnegramIOS3LabelAttributedTextKey, attributedText, OBJC_ASSOCIATION_COPY);
    self.text = [attributedText string];
    if ([attributedText length] != 0)
    {
        NSDictionary *attributes = [attributedText attributesAtIndex:0 effectiveRange:NULL];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        UIColor *color = [attributes objectForKey:@"NSColor"];
        id paragraphStyle = [attributes objectForKey:@"NSParagraphStyle"];
        if (font != nil)
            self.font = font;
        if (color != nil)
            self.textColor = color;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
        if ([paragraphStyle isKindOfClass:[TGIOS3MutableParagraphStyle class]])
        {
            self.lineBreakMode = (UILineBreakMode)[paragraphStyle lineBreakMode];
            self.textAlignment = (UITextAlignment)[paragraphStyle alignment];
        }
#endif
    }
}

@end

static int OnegramIOS3JSONHexDigit(unichar c)
{
    if (c >= '0' && c <= '9')
        return (int)(c - '0');
    if (c >= 'a' && c <= 'f')
        return (int)(c - 'a') + 10;
    if (c >= 'A' && c <= 'F')
        return (int)(c - 'A') + 10;
    return -1;
}

@interface OnegramIOS3JSONParser : NSObject
{
    NSString *_onegramString;
    NSUInteger _onegramIndex;
    NSUInteger _onegramLength;
    NSJSONReadingOptions _onegramOptions;
    NSError **_onegramError;
}
- (instancetype)initWithString:(NSString *)string options:(NSJSONReadingOptions)options error:(NSError **)error;
- (void)skipWhitespace;
- (BOOL)consumeLiteral:(NSString *)literal;
- (NSString *)parseString;
- (NSNumber *)parseNumber;
- (id)parseArray;
- (id)parseObject;
- (id)parseValue;
- (id)parse;
@end

@implementation OnegramIOS3JSONParser

- (instancetype)initWithString:(NSString *)string options:(NSJSONReadingOptions)options error:(NSError **)error
{
    self = [super init];
    if (self != nil)
    {
        _onegramString = [string copy];
        _onegramLength = [_onegramString length];
        _onegramOptions = options;
        _onegramError = error;
        if (_onegramError != NULL)
            *_onegramError = nil;
    }
    return self;
}

- (void)dealloc
{
    [_onegramString release];
    [super dealloc];
}

- (void)setError:(NSString *)description
{
    if (_onegramError != NULL && *_onegramError == nil)
    {
        NSDictionary *userInfo = description == nil ? nil : [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
        *_onegramError = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:userInfo];
    }
}

- (void)skipWhitespace
{
    while (_onegramIndex < _onegramLength)
    {
        unichar c = [_onegramString characterAtIndex:_onegramIndex];
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == 0xfeff)
            _onegramIndex++;
        else
            break;
    }
}

- (BOOL)consumeLiteral:(NSString *)literal
{
    NSUInteger length = [literal length];
    if (_onegramIndex + length > _onegramLength)
        return NO;
    if (![[_onegramString substringWithRange:NSMakeRange(_onegramIndex, length)] isEqualToString:literal])
        return NO;
    _onegramIndex += length;
    return YES;
}

- (NSString *)parseString
{
    if (_onegramIndex >= _onegramLength || [_onegramString characterAtIndex:_onegramIndex] != '"')
        return nil;
    _onegramIndex++;
    NSMutableString *result = [NSMutableString string];
    while (_onegramIndex < _onegramLength)
    {
        unichar c = [_onegramString characterAtIndex:_onegramIndex++];
        if (c == '"')
        {
            if ((_onegramOptions & NSJSONReadingMutableLeaves) != 0)
                return [NSMutableString stringWithString:result];
            return [NSString stringWithString:result];
        }
        if (c < 0x20)
        {
            [self setError:@"Invalid control character in JSON string"];
            return nil;
        }
        if (c != '\\')
        {
            [result appendFormat:@"%C", c];
            continue;
        }
        if (_onegramIndex >= _onegramLength)
        {
            [self setError:@"Invalid escape sequence in JSON string"];
            return nil;
        }
        unichar escape = [_onegramString characterAtIndex:_onegramIndex++];
        switch (escape)
        {
            case '"': [result appendString:@"\""]; break;
            case '\\': [result appendString:@"\\"]; break;
            case '/': [result appendString:@"/"]; break;
            case 'b': [result appendFormat:@"%C", (unichar)'\b']; break;
            case 'f': [result appendFormat:@"%C", (unichar)'\f']; break;
            case 'n': [result appendFormat:@"%C", (unichar)'\n']; break;
            case 'r': [result appendFormat:@"%C", (unichar)'\r']; break;
            case 't': [result appendFormat:@"%C", (unichar)'\t']; break;
            case 'u':
            {
                if (_onegramIndex + 4 > _onegramLength)
                {
                    [self setError:@"Invalid Unicode escape in JSON string"];
                    return nil;
                }
                unsigned int value = 0;
                for (NSUInteger i = 0; i < 4; i++)
                {
                    int digit = OnegramIOS3JSONHexDigit([_onegramString characterAtIndex:_onegramIndex + i]);
                    if (digit < 0)
                    {
                        [self setError:@"Invalid Unicode escape in JSON string"];
                        return nil;
                    }
                    value = (value << 4) | (unsigned int)digit;
                }
                _onegramIndex += 4;
                unichar high = (unichar)value;
                if (high >= 0xd800 && high <= 0xdbff)
                {
                    if (_onegramIndex + 6 > _onegramLength || [_onegramString characterAtIndex:_onegramIndex] != '\\' || [_onegramString characterAtIndex:_onegramIndex + 1] != 'u')
                    {
                        [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                        return nil;
                    }
                    _onegramIndex += 2;
                    unsigned int lowValue = 0;
                    for (NSUInteger i = 0; i < 4; i++)
                    {
                        int digit = OnegramIOS3JSONHexDigit([_onegramString characterAtIndex:_onegramIndex + i]);
                        if (digit < 0)
                        {
                            [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                            return nil;
                        }
                        lowValue = (lowValue << 4) | (unsigned int)digit;
                    }
                    _onegramIndex += 4;
                    unichar low = (unichar)lowValue;
                    if (low < 0xdc00 || low > 0xdfff)
                    {
                        [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                        return nil;
                    }
                    [result appendFormat:@"%C%C", high, low];
                }
                else if (high >= 0xdc00 && high <= 0xdfff)
                {
                    [self setError:@"Invalid Unicode surrogate pair in JSON string"];
                    return nil;
                }
                else
                    [result appendFormat:@"%C", high];
                break;
            }
            default:
                [self setError:@"Invalid escape sequence in JSON string"];
                return nil;
        }
    }
    [self setError:@"Unterminated JSON string"];
    return nil;
}

- (NSNumber *)parseNumber
{
    NSUInteger start = _onegramIndex;
    if (_onegramIndex < _onegramLength && [_onegramString characterAtIndex:_onegramIndex] == '-')
        _onegramIndex++;
    if (_onegramIndex >= _onegramLength)
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    unichar c = [_onegramString characterAtIndex:_onegramIndex];
    if (c == '0')
    {
        _onegramIndex++;
        if (_onegramIndex < _onegramLength)
        {
            unichar next = [_onegramString characterAtIndex:_onegramIndex];
            if (next >= '0' && next <= '9')
            {
                [self setError:@"Invalid JSON number"];
                return nil;
            }
        }
    }
    else if (c >= '1' && c <= '9')
    {
        while (_onegramIndex < _onegramLength)
        {
            unichar digit = [_onegramString characterAtIndex:_onegramIndex];
            if (digit < '0' || digit > '9')
                break;
            _onegramIndex++;
        }
    }
    else
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    BOOL floating = NO;
    if (_onegramIndex < _onegramLength && [_onegramString characterAtIndex:_onegramIndex] == '.')
    {
        floating = YES;
        _onegramIndex++;
        NSUInteger digitsStart = _onegramIndex;
        while (_onegramIndex < _onegramLength)
        {
            unichar digit = [_onegramString characterAtIndex:_onegramIndex];
            if (digit < '0' || digit > '9')
                break;
            _onegramIndex++;
        }
        if (_onegramIndex == digitsStart)
        {
            [self setError:@"Invalid JSON number"];
            return nil;
        }
    }
    if (_onegramIndex < _onegramLength)
    {
        unichar exponent = [_onegramString characterAtIndex:_onegramIndex];
        if (exponent == 'e' || exponent == 'E')
        {
            floating = YES;
            _onegramIndex++;
            if (_onegramIndex < _onegramLength)
            {
                unichar sign = [_onegramString characterAtIndex:_onegramIndex];
                if (sign == '+' || sign == '-')
                    _onegramIndex++;
            }
            NSUInteger digitsStart = _onegramIndex;
            while (_onegramIndex < _onegramLength)
            {
                unichar digit = [_onegramString characterAtIndex:_onegramIndex];
                if (digit < '0' || digit > '9')
                    break;
                _onegramIndex++;
            }
            if (_onegramIndex == digitsStart)
            {
                [self setError:@"Invalid JSON number"];
                return nil;
            }
        }
    }
    NSString *numberString = [_onegramString substringWithRange:NSMakeRange(start, _onegramIndex - start)];
    const char *utf8 = [numberString UTF8String];
    if (utf8 == NULL)
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    if (!floating)
    {
        char *end = NULL;
        long long value = strtoll(utf8, &end, 10);
        if (end == NULL || *end != '\0')
        {
            [self setError:@"Invalid JSON number"];
            return nil;
        }
        return [NSNumber numberWithLongLong:value];
    }
    char *end = NULL;
    double value = strtod(utf8, &end);
    if (end == NULL || *end != '\0' || !isfinite(value))
    {
        [self setError:@"Invalid JSON number"];
        return nil;
    }
    return [NSNumber numberWithDouble:value];
}

- (id)parseArray
{
    _onegramIndex++;
    NSMutableArray *result = [NSMutableArray array];
    [self skipWhitespace];
    if (_onegramIndex < _onegramLength && [_onegramString characterAtIndex:_onegramIndex] == ']')
    {
        _onegramIndex++;
        return (_onegramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSArray arrayWithArray:result];
    }
    while (_onegramIndex < _onegramLength)
    {
        id value = [self parseValue];
        if (value == nil)
            return nil;
        [result addObject:value];
        [self skipWhitespace];
        if (_onegramIndex >= _onegramLength)
            break;
        unichar c = [_onegramString characterAtIndex:_onegramIndex++];
        if (c == ']')
            return (_onegramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSArray arrayWithArray:result];
        if (c != ',')
        {
            [self setError:@"Expected comma in JSON array"];
            return nil;
        }
        [self skipWhitespace];
    }
    [self setError:@"Unterminated JSON array"];
    return nil;
}

- (id)parseObject
{
    _onegramIndex++;
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [self skipWhitespace];
    if (_onegramIndex < _onegramLength && [_onegramString characterAtIndex:_onegramIndex] == '}')
    {
        _onegramIndex++;
        return (_onegramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSDictionary dictionaryWithDictionary:result];
    }
    while (_onegramIndex < _onegramLength)
    {
        if ([_onegramString characterAtIndex:_onegramIndex] != '"')
        {
            [self setError:@"Expected string key in JSON object"];
            return nil;
        }
        NSString *key = [self parseString];
        if (key == nil)
            return nil;
        [self skipWhitespace];
        if (_onegramIndex >= _onegramLength || [_onegramString characterAtIndex:_onegramIndex] != ':')
        {
            [self setError:@"Expected colon in JSON object"];
            return nil;
        }
        _onegramIndex++;
        [self skipWhitespace];
        id value = [self parseValue];
        if (value == nil)
            return nil;
        [result setObject:value forKey:key];
        [self skipWhitespace];
        if (_onegramIndex >= _onegramLength)
            break;
        unichar c = [_onegramString characterAtIndex:_onegramIndex++];
        if (c == '}')
            return (_onegramOptions & NSJSONReadingMutableContainers) != 0 ? result : [NSDictionary dictionaryWithDictionary:result];
        if (c != ',')
        {
            [self setError:@"Expected comma in JSON object"];
            return nil;
        }
        [self skipWhitespace];
    }
    [self setError:@"Unterminated JSON object"];
    return nil;
}

- (id)parseValue
{
    [self skipWhitespace];
    if (_onegramIndex >= _onegramLength)
    {
        [self setError:@"Unexpected end of JSON input"];
        return nil;
    }
    unichar c = [_onegramString characterAtIndex:_onegramIndex];
    if (c == '"')
        return [self parseString];
    if (c == '{')
        return [self parseObject];
    if (c == '[')
        return [self parseArray];
    if (c == 't')
    {
        if ([self consumeLiteral:@"true"])
            return [NSNumber numberWithBool:YES];
    }
    else if (c == 'f')
    {
        if ([self consumeLiteral:@"false"])
            return [NSNumber numberWithBool:NO];
    }
    else if (c == 'n')
    {
        if ([self consumeLiteral:@"null"])
            return [NSNull null];
    }
    else if (c == '-' || (c >= '0' && c <= '9'))
        return [self parseNumber];
    [self setError:@"Invalid JSON value"];
    return nil;
}

- (id)parse
{
    [self skipWhitespace];
    id result = [self parseValue];
    if (result == nil)
        return nil;
    [self skipWhitespace];
    if (_onegramIndex != _onegramLength)
    {
        [self setError:@"Trailing data after JSON value"];
        return nil;
    }
    if ((_onegramOptions & NSJSONReadingAllowFragments) == 0 && ![result isKindOfClass:[NSArray class]] && ![result isKindOfClass:[NSDictionary class]])
    {
        [self setError:@"Top-level JSON value must be an array or object"];
        return nil;
    }
    return result;
}

@end

static void OnegramIOS3JSONAppendIndent(NSMutableString *output, NSUInteger depth)
{
    for (NSUInteger i = 0; i < depth; i++)
        [output appendString:@"  "];
}

static void OnegramIOS3JSONAppendString(NSMutableString *output, NSString *string)
{
    [output appendString:@"\""];
    NSUInteger length = [string length];
    for (NSUInteger i = 0; i < length; i++)
    {
        unichar c = [string characterAtIndex:i];
        switch (c)
        {
            case '"': [output appendString:@"\\\""]; break;
            case '\\': [output appendString:@"\\\\"]; break;
            case '\b': [output appendString:@"\\b"]; break;
            case '\f': [output appendString:@"\\f"]; break;
            case '\n': [output appendString:@"\\n"]; break;
            case '\r': [output appendString:@"\\r"]; break;
            case '\t': [output appendString:@"\\t"]; break;
            default:
                if (c < 0x20 || c == 0x2028 || c == 0x2029)
                    [output appendFormat:@"\\u%04x", c];
                else
                    [output appendFormat:@"%C", c];
                break;
        }
    }
    [output appendString:@"\""];
}

static BOOL OnegramIOS3JSONAppendObject(NSMutableString *output, id object, NSJSONWritingOptions options, NSUInteger depth, NSError **error)
{
    BOOL pretty = (options & NSJSONWritingPrettyPrinted) != 0;
    if (object == nil || object == [NSNull null])
    {
        [output appendString:@"null"];
        return YES;
    }

    if ([object isKindOfClass:[NSString class]])
    {
        OnegramIOS3JSONAppendString(output, object);
        return YES;
    }

    if ([object isKindOfClass:[NSNumber class]])
    {
        if (object == (id)kCFBooleanTrue)
            [output appendString:@"true"];
        else if (object == (id)kCFBooleanFalse)
            [output appendString:@"false"];
        else
        {
            const char *type = [object objCType];
            if (type != NULL && (type[0] == 'f' || type[0] == 'd'))
            {
                double value = [object doubleValue];
                if (!isfinite(value))
                {
                    if (error != NULL)
                        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
                    return NO;
                }
            }
            [output appendString:[object stringValue]];
        }
        return YES;
    }

    if ([object isKindOfClass:[NSArray class]])
    {
        [output appendString:@"["];
        NSUInteger count = [object count];
        for (NSUInteger i = 0; i < count; i++)
        {
            if (i != 0)
                [output appendString:@","];
            if (pretty)
            {
                [output appendString:@"\n"];
                OnegramIOS3JSONAppendIndent(output, depth + 1);
            }
            if (!OnegramIOS3JSONAppendObject(output, [object objectAtIndex:i], options, depth + 1, error))
                return NO;
        }
        if (pretty && count != 0)
        {
            [output appendString:@"\n"];
            OnegramIOS3JSONAppendIndent(output, depth);
        }
        [output appendString:@"]"];
        return YES;
    }

    if ([object isKindOfClass:[NSDictionary class]])
    {
        [output appendString:@"{"];
        NSArray *keys = [object allKeys];
        NSUInteger count = [keys count];
        for (NSUInteger i = 0; i < count; i++)
        {
            id key = [keys objectAtIndex:i];
            if (![key isKindOfClass:[NSString class]])
            {
                if (error != NULL)
                    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
                return NO;
            }
            if (i != 0)
                [output appendString:@","];
            if (pretty)
            {
                [output appendString:@"\n"];
                OnegramIOS3JSONAppendIndent(output, depth + 1);
            }
            OnegramIOS3JSONAppendString(output, key);
            [output appendString:pretty ? @": " : @":"];
            if (!OnegramIOS3JSONAppendObject(output, [object objectForKey:key], options, depth + 1, error))
                return NO;
        }
        if (pretty && count != 0)
        {
            [output appendString:@"\n"];
            OnegramIOS3JSONAppendIndent(output, depth);
        }
        [output appendString:@"}"];
        return YES;
    }

    if (error != NULL)
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
    return NO;
}

@implementation NSJSONSerialization

+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error
{
    if (error != NULL)
        *error = nil;
    if (data == nil)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
        return nil;
    }

    NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if (string == nil)
        string = [[[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding] autorelease];
    if (string == nil)
    {
        if (error != NULL)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:3840 userInfo:nil];
        return nil;
    }

    OnegramIOS3JSONParser *parser = [[[OnegramIOS3JSONParser alloc] initWithString:string options:opt error:error] autorelease];
    return [parser parse];
}

+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error
{
    NSMutableString *output = [NSMutableString string];
    if (!OnegramIOS3JSONAppendObject(output, obj, opt, 0, error))
        return nil;
    return [output dataUsingEncoding:NSUTF8StringEncoding];
}

+ (BOOL)isValidJSONObject:(id)obj
{
    if (![obj isKindOfClass:[NSArray class]] && ![obj isKindOfClass:[NSDictionary class]])
        return NO;
    NSError *error = nil;
    return [self dataWithJSONObject:obj options:0 error:&error] != nil;
}

@end

@implementation NSFileManager (OnegramIOS3URLCompatibilityFallback)

- (BOOL)onegramIOS3Fallback_removeItemAtURL:(NSURL *)URL error:(NSError **)error
{
    NSString *path = [URL path];
    if (path == nil)
        return NO;
    return [self removeItemAtPath:path error:error];
}

- (BOOL)onegramIOS3Fallback_createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    NSString *path = [url path];
    if (path == nil)
        return NO;
    return [self createDirectoryAtPath:path withIntermediateDirectories:createIntermediates attributes:attributes error:error];
}

- (NSURL *)onegramIOS3Fallback_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier
{
    return nil;
}

@end

@implementation NSURL (OnegramIOS3PathCompatibilityFallback)

- (NSURL *)onegramIOS3Fallback_URLByAppendingPathComponent:(NSString *)pathComponent
{
    if (pathComponent == nil)
        return self;

    if ([[self scheme] isEqualToString:@"file"])
    {
        NSString *path = [[self path] stringByAppendingPathComponent:pathComponent];
        return path == nil ? nil : [NSURL fileURLWithPath:path];
    }

    NSString *base = [self absoluteString];
    if (base == nil)
        return nil;
    if (![base hasSuffix:@"/"])
        base = [base stringByAppendingString:@"/"];
    NSString *escaped = [pathComponent stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return [NSURL URLWithString:[base stringByAppendingString:escaped != nil ? escaped : pathComponent]];
}

- (NSURL *)onegramIOS3Fallback_URLByAppendingPathComponent:(NSString *)pathComponent isDirectory:(BOOL)isDirectory
{
    if (pathComponent == nil || [pathComponent length] == 0)
        return self;

    NSString *component = pathComponent;
    if (isDirectory && ![component hasSuffix:@"/"])
        component = [component stringByAppendingString:@"/"];

    if ([[self scheme] isEqualToString:@"file"])
    {
        NSString *path = [[self path] stringByAppendingPathComponent:component];
        return path == nil ? nil : [NSURL fileURLWithPath:path];
    }

    return [self URLByAppendingPathComponent:component];
}

- (NSString *)onegramIOS3Fallback_pathExtension
{
    return [[self path] pathExtension];
}

- (NSString *)onegramIOS3Fallback_lastPathComponent
{
    return [[self path] lastPathComponent];
}

- (NSArray *)onegramIOS3Fallback_pathComponents
{
    return [[self path] pathComponents];
}

@end

@implementation NSData (OnegramIOS3ReadingWritingCompatibilityFallback)

- (instancetype)onegramIOS3Fallback_initWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    (void)readOptionsMask;
    id result = [self initWithContentsOfURL:url];
    if (result == nil && errorPtr != NULL)
        *errorPtr = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:256 userInfo:nil];
    return result;
}

- (instancetype)onegramIOS3Fallback_initWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    (void)readOptionsMask;
    id result = [self initWithContentsOfFile:path];
    if (result == nil && errorPtr != NULL)
        *errorPtr = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:256 userInfo:nil];
    return result;
}

+ (NSData *)onegramIOS3Fallback_dataWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    return [[[self alloc] initWithContentsOfURL:url options:readOptionsMask error:errorPtr] autorelease];
}

+ (NSData *)onegramIOS3Fallback_dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr
{
    return [[[self alloc] initWithContentsOfFile:path options:readOptionsMask error:errorPtr] autorelease];
}

- (BOOL)onegramIOS3Fallback_writeToURL:(NSURL *)url options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)errorPtr
{
    BOOL result = [self writeToURL:url atomically:(writeOptionsMask & NSDataWritingAtomic) != 0];
    if (!result && errorPtr != NULL)
        *errorPtr = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:512 userInfo:nil];
    return result;
}

@end

static char OnegramIOS3ButtonAttributedTitlesKey;

@implementation UIButton (OnegramIOS3AttributedTitleCompatibilityFallback)

- (void)onegramIOS3Fallback_setAttributedTitle:(id)title forState:(UIControlState)state
{
    NSMutableDictionary *titles = objc_getAssociatedObject(self, &OnegramIOS3ButtonAttributedTitlesKey);
    if (titles == nil)
    {
        titles = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &OnegramIOS3ButtonAttributedTitlesKey, titles, OBJC_ASSOCIATION_RETAIN);
    }

    NSNumber *key = [NSNumber numberWithUnsignedInteger:state];
    if (title != nil)
        [titles setObject:title forKey:key];
    else
        [titles removeObjectForKey:key];

    NSString *string = [title respondsToSelector:@selector(string)] ? [title string] : nil;
    [self setTitle:string forState:state];

    if ([title respondsToSelector:@selector(length)] && [title length] != 0 && [title respondsToSelector:@selector(attributesAtIndex:effectiveRange:)])
    {
        NSDictionary *attributes = [title attributesAtIndex:0 effectiveRange:NULL];
        UIColor *color = [attributes objectForKey:@"NSColor"];
        UIFont *font = [attributes objectForKey:@"NSFont"];
        if (color != nil)
            [self setTitleColor:color forState:state];
        if (font != nil)
            self.titleLabel.font = font;
    }
}

- (id)onegramIOS3Fallback_attributedTitleForState:(UIControlState)state
{
    NSDictionary *titles = objc_getAssociatedObject(self, &OnegramIOS3ButtonAttributedTitlesKey);
    return [titles objectForKey:[NSNumber numberWithUnsignedInteger:state]];
}

@end

#endif

@interface OnegramIOS3FallbackMethodInstaller : NSObject
@end

@implementation OnegramIOS3FallbackMethodInstaller

+ (void)load
{
    Class classes[] = {
        [NSOperationQueue class],
        [NSOperation class],
        [NSURLConnection class],
        [NSMutableArray class],
        [NSString class],
        [NSFileManager class],
        [NSURL class],
        [NSData class],
        [UIApplication class],
        [UIWindow class],
        [UIViewController class],
        [UINavigationItem class],
        [UIView class],
        [UIDevice class],
        [UILabel class],
        [UIImage class],
        [UIScreen class],
        [UIButton class]
    };
    for (NSUInteger index = 0; index < sizeof(classes) / sizeof(classes[0]); index++)
        OnegramIOS3InstallFallbackMethods(classes[index]);
}

@end
