#import "UIViewController+Proxy.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <objc/runtime.h>

static const void *TGProxyDismissControllerKey = &TGProxyDismissControllerKey;
static bool TGProxyHasNativePresentingViewController = false;

static UIViewController *TGProxyTopContainerController(UIViewController *controller)
{
    UIViewController *currentController = controller;
    while (currentController.parentViewController != nil)
        currentController = currentController.parentViewController;
    return currentController;
}

static UIViewController *TGProxyLegacyPresentingViewController(UIViewController *controller)
{
    UIViewController *targetController = TGProxyTopContainerController(controller);
    UIViewController *currentController = [UIApplication sharedApplication].keyWindow.rootViewController;

    while (currentController != nil)
    {
        UIViewController *modalController = currentController.modalViewController;
        if (modalController == targetController)
            return currentController;
        if (modalController == nil)
            break;
        currentController = modalController;
    }

    return nil;
}

@interface TGProxyPresentingController : UIViewController

@property (nonatomic, copy, readonly) void (^block)(bool);

@end

@implementation TGProxyPresentingController

- (instancetype)initWithBlock:(void (^)(bool))block {
    self = [super init];
    if (self != nil) {
        _block = [block copy];
    }
    return self;
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if (_block) {
        _block(flag);
        if (completion) {
            completion();
        }
    }
}

@end

@implementation UIViewController (Proxy)

+ (void)load {
    @autoreleasepool
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Method presentingMethod = class_getInstanceMethod([UIViewController class], @selector(presentingViewController));
            Method proxyMethod = class_getInstanceMethod([UIViewController class], @selector(_proxy_presentingViewController));
            TGProxyHasNativePresentingViewController = presentingMethod != nil;

            if (TGProxyHasNativePresentingViewController)
                SwizzleInstanceMethod([UIViewController class], @selector(presentingViewController), @selector(_proxy_presentingViewController));
            else if (proxyMethod != nil)
                class_addMethod([UIViewController class], @selector(presentingViewController), method_getImplementation(proxyMethod), method_getTypeEncoding(proxyMethod));
        });
    }
}

- (void)setProxyDismissBlock:(void (^)(bool))block {
    objc_setAssociatedObject(self, TGProxyDismissControllerKey, [[TGProxyPresentingController alloc] initWithBlock:[block copy]], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)_proxy_presentingViewController {
    TGProxyPresentingController *controller = objc_getAssociatedObject(self, TGProxyDismissControllerKey);
    if (controller != nil) {
        return controller;
    }
    if (TGProxyHasNativePresentingViewController)
        return [self _proxy_presentingViewController];

    return TGProxyLegacyPresentingViewController(self);
}

@end
