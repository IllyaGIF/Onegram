//
//  UIViewController+Stripe_ParentViewController.h
//  Stripe
//
//  Created by Jack Flintermann on 1/12/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (Stripe_ParentViewController)

- (UIViewController *_Nullable)stp_parentViewControllerOfClass:(Class _Nonnull)klass;
- (BOOL)stp_isTopNavigationController;
- (BOOL)stp_isAtRootOfNavigationController;
- (UIViewController *_Nullable)stp_previousViewControllerInNavigation;

@end

void linkUIViewControllerParentViewControllerCategory(void);
