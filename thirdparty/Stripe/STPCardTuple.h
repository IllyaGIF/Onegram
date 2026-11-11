//
//  STPCardTuple.h
//  Stripe
//
//  Created by Jack Flintermann on 5/17/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OGStripeCompat.h"

NS_ASSUME_NONNULL_BEGIN

@class STPCard;

@interface STPCardTuple : NSObject

+ (instancetype)tupleWithSelectedCard:(STPCard *_Nullable)selectedCard
                                cards:(OG_COMPAT_GENERIC(NSArray, STPCard *)*_Nullable)cards;

@property(nonatomic, readonly)STPCard *_Nullable selectedCard;
@property(nonatomic, readonly)OG_COMPAT_GENERIC(NSArray, STPCard *) *cards;

@end

NS_ASSUME_NONNULL_END
