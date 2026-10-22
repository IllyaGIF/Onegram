#import "TGCollectionMenuController.h"

@interface TGOnegramCoreController : TGCollectionMenuController

- (instancetype)initModal:(bool)modal;

+ (void)presentFromViewController:(UIViewController *)viewController;
+ (NSString *)statusText;
+ (UIImage *)lockImageEnabled:(bool)enabled highlighted:(bool)highlighted;
+ (UIButton *)lockButtonWithTarget:(id)target action:(SEL)action;
+ (void)updateLockButton:(UIButton *)button;

@end
