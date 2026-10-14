#import <Foundation/Foundation.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#import <PassKit/PassKit.h>
#else
#ifndef PKAddressFieldNone
typedef NSUInteger PKAddressField;
#endif
@class PKPayment;
@class PKPaymentRequest;
#endif
