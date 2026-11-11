//
//  UIView+Stripe_FirstResponder.h
//  Stripe
//
//  Created by Jack Flintermann on 4/15/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Stripe_FirstResponder)

- (UIView *_Nullable)stp_findFirstResponder;

@end

void linkUIViewFirstResponderCategory(void);
