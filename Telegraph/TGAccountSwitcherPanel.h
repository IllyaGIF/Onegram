#import <UIKit/UIKit.h>

@interface TGAccountSwitcherPanel : UIView

+ (TGAccountSwitcherPanel *)presentInView:(UIView *)view;
+ (UIButton *)cancelAddingAccountButtonWithTarget:(id)target action:(SEL)action;

- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion;

@end
