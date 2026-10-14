#import "UIScrollView+TGHacks.h"

#import <objc/message.h>

@implementation UIScrollView (TGHacks)

- (void)stopScrollingAnimation
{
    CGPoint offset = self.contentOffset;
    [self setContentOffset:offset animated:false];
    self.scrollEnabled = false;
    self.scrollEnabled = true;
    
}

@end
