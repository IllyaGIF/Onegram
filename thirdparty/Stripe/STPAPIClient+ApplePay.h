//
//  STPAPIClient+ApplePay.h
//  Stripe
//
//  Created by Jack Flintermann on 12/19/14.
//

#import <Foundation/Foundation.h>
#import "OGStripeCompat.h"
#if OG_COMPAT_STRIPE_HAS_PASSKIT
#import <PassKit/PassKit.h>

#import "STPAPIClient.h"

#define FAUXPAS_IGNORED_IN_FILE(...)
FAUXPAS_IGNORED_IN_FILE(APIAvailability)

/**
 *  STPAPIClient extensions to create Stripe tokens from Apple Pay PKPayment objects.
 */
@interface STPAPIClient (ApplePay)

/**
 *  Converts a PKPayment object into a Stripe token using the Stripe API.
 *
 *  @param payment     The user's encrypted payment information as returned from a PKPaymentAuthorizationViewController. Cannot be nil.
 *  @param completion  The callback to run with the returned Stripe token (and any errors that may have occurred).
 */
- (void)createTokenWithPayment:(PKPayment *_Nonnull)payment
                    completion:(STPTokenCompletionBlock _Nonnull)completion NS_AVAILABLE_IOS(8_0);

@end

#endif

void linkSTPAPIClientApplePayCategory(void);
