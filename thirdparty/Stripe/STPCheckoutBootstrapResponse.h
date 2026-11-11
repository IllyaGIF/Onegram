//
//  STPCheckoutBootstrapResponse.h
//  Stripe
//
//  Created by Jack Flintermann on 5/4/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STPAPIClient;

@interface STPCheckoutBootstrapResponse : NSObject

+ (instancetype _Nullable)bootstrapResponseWithData:(NSData *_Nullable)data
                                       URLResponse:(NSURLResponse *_Nullable)response;

@property(nonatomic, readonly)BOOL liveMode;
@property(nonatomic, readonly)BOOL accountsDisabled;
@property(nonatomic, readonly)NSString *_Nonnull sessionID;
@property(nonatomic, readonly)NSString *_Nonnull csrfToken;
@property(nonatomic, readonly)STPAPIClient *_Nonnull tokenClient;

@end
