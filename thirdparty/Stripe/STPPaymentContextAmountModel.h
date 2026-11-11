//
//  STPPaymentContextAmountModel.h
//  Stripe
//
//  Created by Brian Dorfman on 8/16/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PKPaymentSummaryItem;
#import "OGStripeCompat.h"

#define FAUXPAS_IGNORED_IN_CLASS(...)

/**
 Internal model for STPPaymentContext's `paymentAmount` and 
 `paymentSummaryItems` properties.
 */
@interface STPPaymentContextAmountModel : NSObject
FAUXPAS_IGNORED_IN_CLASS(APIAvailability)

- (instancetype)initWithAmount:(NSInteger)paymentAmount;
- (instancetype)initWithPaymentSummaryItems:(OG_COMPAT_GENERIC(NSArray, PKPaymentSummaryItem *) *)paymentSummaryItems;

- (NSInteger)paymentAmountWithCurrency:(NSString *)paymentCurrency;
- (OG_COMPAT_GENERIC(NSArray, PKPaymentSummaryItem *) *)paymentSummaryItemsWithCurrency:(NSString *)paymentCurrency
                                                         companyName:(NSString *)companyName;

@end
