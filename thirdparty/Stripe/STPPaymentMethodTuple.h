//
//  STPPaymentMethodTuple.h
//  Stripe
//
//  Created by Jack Flintermann on 5/17/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OGStripeCompat.h"
#import "STPCardTuple.h"
#import "STPPaymentMethod.h"

NS_ASSUME_NONNULL_BEGIN

@interface STPPaymentMethodTuple : NSObject

+ (instancetype)tupleWithPaymentMethods:(OG_COMPAT_GENERIC(NSArray, id<STPPaymentMethod>) *)paymentMethods
                  selectedPaymentMethod:(id<STPPaymentMethod>)selectedPaymentMethod;

+ (instancetype)tupleWithCardTuple:(STPCardTuple *)cardTuple
                   applePayEnabled:(BOOL)applePayEnabled;

@property(nonatomic, readonly)id<STPPaymentMethod> _Nullable selectedPaymentMethod;
@property(nonatomic, readonly)OG_COMPAT_GENERIC(NSArray, id<STPPaymentMethod>) *paymentMethods;

@end

NS_ASSUME_NONNULL_END
