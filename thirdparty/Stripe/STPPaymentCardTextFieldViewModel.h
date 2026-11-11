//
//  STPPaymentCardTextFieldViewModel.h
//  Stripe
//
//  Created by Jack Flintermann on 7/21/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "STPCard.h"
#import "STPCardValidator.h"

typedef NS_ENUM(NSInteger, STPCardFieldType) {
    STPCardFieldTypeNumber,
    STPCardFieldTypeExpiration,
    STPCardFieldTypeCVC,
};

@interface STPPaymentCardTextFieldViewModel : NSObject

@property(nonatomic, readwrite, copy)NSString *_Nullable cardNumber;
@property(nonatomic, readwrite, copy)NSString *_Nullable rawExpiration;
@property(nonatomic, readonly)NSString *_Nullable expirationMonth;
@property(nonatomic, readonly)NSString *_Nullable expirationYear;
@property(nonatomic, readwrite, copy)NSString *_Nullable cvc;
@property(nonatomic, readonly) STPCardBrand brand;

- (NSString *_Nonnull)defaultPlaceholder;
- (NSString *_Nullable)numberWithoutLastDigits;

- (BOOL)isValid;

- (STPCardValidationState)validationStateForField:(STPCardFieldType)fieldType;

@end
