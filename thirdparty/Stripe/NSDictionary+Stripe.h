//
//  NSDictionary+Stripe.h
//  Stripe
//
//  Created by Jack Flintermann on 10/15/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (Stripe)

- (NSDictionary *_Nullable)stp_dictionaryByRemovingNullsValidatingRequiredFields:(NSArray *_Nonnull)requiredFields;

@end

void linkNSDictionaryCategory(void);
