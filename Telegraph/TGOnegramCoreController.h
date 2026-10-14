#import "TGCollectionMenuController.h"

@interface TGOnegramCoreController : TGCollectionMenuController

- (instancetype)initModal:(bool)modal;

+ (void)presentFromViewController:(UIViewController *)viewController;
+ (NSString *)statusText;
+ (UIImage *)lockImageEnabled:(bool)enabled highlighted:(bool)highlighted;

@end
