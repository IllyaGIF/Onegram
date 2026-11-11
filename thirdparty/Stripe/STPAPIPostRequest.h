//
//  STPAPIPostRequest.h
//  Stripe
//
//  Created by Jack Flintermann on 10/14/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STPAPIResponseDecodable.h"
#import "OGStripeCompat.h"
@class STPAPIClient;

@interface STPAPIPostRequest OG_COMPAT_TYPE_PARAMETERS(__covariant ResponseType:id<STPAPIResponseDecodable>) : NSObject

typedef void(^STPAPIPostResponseBlock)(OG_COMPAT_TYPE_PARAMETER(ResponseType, id<STPAPIResponseDecodable>) object, NSHTTPURLResponse *response, NSError *error);

+ (void)startWithAPIClient:(STPAPIClient *)apiClient
                  endpoint:(NSString *)endpoint
                  postData:(NSData *)postData
                serializer:(Class<STPAPIResponseDecodable>)serializer
                completion:(STPAPIPostResponseBlock)completion;

@end
