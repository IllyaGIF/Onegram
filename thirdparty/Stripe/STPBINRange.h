//
//  STPBINRange.h
//  Stripe
//
//  Created by Jack Flintermann on 5/24/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OGStripeCompat.h"
#import "STPCardBrand.h"

NS_ASSUME_NONNULL_BEGIN

@interface STPBINRange : NSObject

@property(nonatomic, readonly)NSUInteger length;
@property(nonatomic, readonly)STPCardBrand brand;

+ (OG_COMPAT_GENERIC(NSArray, STPBINRange *) *)allRanges;
+ (OG_COMPAT_GENERIC(NSArray, STPBINRange *) *)binRangesForNumber:(NSString *)number;
+ (OG_COMPAT_GENERIC(NSArray, STPBINRange *) *)binRangesForBrand:(STPCardBrand)brand;
+ (instancetype)mostSpecificBINRangeForNumber:(NSString *)number;

@end

NS_ASSUME_NONNULL_END
