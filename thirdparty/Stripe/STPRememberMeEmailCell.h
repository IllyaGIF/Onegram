//
//  STPRememberMeEmailCell.h
//  Stripe
//
//  Created by Jack Flintermann on 5/20/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPAddressFieldTableViewCell.h"
#import "STPPaymentActivityIndicatorView.h"

@interface STPRememberMeEmailCell : STPAddressFieldTableViewCell

@property(nonatomic, unsafe_unretained, readonly)STPPaymentActivityIndicatorView *activityIndicator;

- (instancetype)initWithDelegate:(id<STPAddressFieldTableViewCellDelegate>)delegate;

@end
