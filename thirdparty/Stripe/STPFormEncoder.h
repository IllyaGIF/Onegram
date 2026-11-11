//
//  STPFormEncoder.h
//  Stripe
//
//  Created by Jack Flintermann on 1/8/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class STPCardParams, STPBankAccountParams;
@protocol STPFormEncodable;

@interface STPFormEncoder : NSObject

+ (NSData *_Nonnull)formEncodedDataForObject:(NSObject<STPFormEncodable> *_Nonnull)object;

+ (NSString *_Nonnull)stringByURLEncoding:(NSString *_Nonnull)string;

+ (NSString *_Nonnull)stringByReplacingSnakeCaseWithCamelCase:(NSString *_Nonnull)input;

+ (NSString *_Nonnull)queryStringFromParameters:(NSDictionary *_Nonnull)parameters;

@end
