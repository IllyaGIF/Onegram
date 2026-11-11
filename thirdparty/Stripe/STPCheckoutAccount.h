//
//  STPCheckoutAccount.h
//  Stripe
//
//  Created by Jack Flintermann on 5/3/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STPCard.h"

@interface STPCheckoutAccount : NSObject

+ (instancetype _Nullable)accountWithData:(NSData *_Nullable)data
                             URLResponse:(NSURLResponse *_Nullable)response;

@property(nonatomic, readonly)NSString *_Nonnull email;
@property(nonatomic, readonly)NSString *_Nonnull phone;
@property(nonatomic, readonly)NSString *_Nonnull csrfToken;
@property(nonatomic, readonly)NSString *_Nonnull sessionID;
@property(nonatomic, readonly)STPCard *_Nonnull card;

@end
