//
//  UIViewController+Stripe_KeyboardAvoiding.h
//  Stripe
//
//  Created by Jack Flintermann on 4/15/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^STPKeyboardFrameBlock)(CGRect keyboardFrame, UIView *_Nullable currentlyEditedField);

@interface UIViewController (Stripe_KeyboardAvoiding)

- (void)stp_beginObservingKeyboardAndInsettingScrollView:(UIScrollView *_Nullable)scrollView
                                           onChangeBlock:(STPKeyboardFrameBlock _Nullable)block;

@end

void linkUIViewControllerKeyboardAvoidingCategory(void);

NS_ASSUME_NONNULL_END
