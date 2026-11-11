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
    
    UIViewController *hosted = self.contentViewController;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ([hosted respondsToSelector:@selector(setPreferredContentSize:)])
    {
        [hosted setPreferredContentSize:contentSize];
        return;
    }
#endif
    hosted.contentSizeForViewInPopover = contentSize;
}

@end
