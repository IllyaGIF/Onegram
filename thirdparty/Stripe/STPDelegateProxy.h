//
//  STPDelegateProxy.h
//  Stripe
//
//  Created by Jack Flintermann on 10/20/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OGStripeCompat.h"

@interface STPDelegateProxy OG_COMPAT_TYPE_PARAMETERS(__covariant DelegateType:NSObject<NSObject> *) : NSObject

@property(nonatomic, unsafe_unretained)OG_COMPAT_TYPE_PARAMETER(DelegateType, id) delegate;
- (instancetype)init;

@end
