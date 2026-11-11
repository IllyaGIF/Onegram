//
//  STPCardTuple.m
//  Stripe
//
//  Created by Jack Flintermann on 5/17/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPCardTuple.h"
#import "OGStripeCompat.h"

@interface STPCardTuple()

@property(nonatomic)STPCard *_Nullable selectedCard;
@property(nonatomic)OG_COMPAT_GENERIC(NSArray, STPCard *) *cards;

@end

@implementation STPCardTuple

+ (instancetype)tupleWithSelectedCard:(STPCard *)selectedCard
                                cards:(OG_COMPAT_GENERIC(NSArray, STPCard *)*)cards {
    STPCardTuple *tuple = [self new];
    tuple.selectedCard = selectedCard;
    tuple.cards = cards ?: @[];
    return tuple;
}

@end
