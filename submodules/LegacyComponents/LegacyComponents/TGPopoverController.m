#import "TGPopoverController.h"

@implementation TGPopoverController

- (instancetype)initWithContentViewController:(UIViewController *)viewController
{
    self = [super initWithContentViewController:viewController];
    if (self != nil)
    {
    }
    return self;
}

- (void)setContentSize:(CGSize)contentSize
{
    [self setPopoverContentSize:contentSize animated:false];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ([self.contentViewController respondsToSelector:@selector(setPreferredContentSize:)])
        [self.contentViewController setPreferredContentSize:contentSize];
    else
#endif
        self.contentViewController.contentSizeForViewInPopover = contentSize;
}

@end
