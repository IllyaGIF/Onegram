#import <Foundation/Foundation.h>

extern NSString * const kAWGTransportErrorDomain;

typedef NS_ENUM(NSInteger, AWGFragmentMode) {
    AWGFragmentNone = 0,
    AWGFragmentMidSNI,
    AWGFragmentFirstByte,
    AWGFragmentBeforeSNI,
    AWGFragmentTiny,
    AWGFragmentMidSNISlow
};

NSString *AWGFragmentModeName(AWGFragmentMode mode);

@interface AWGHTTPSTransport : NSObject

+ (NSData *)postToHost:(NSString *)host
             connectIP:(NSString *)connectIP
             socksPort:(uint16_t)socksPort
                  port:(uint16_t)port
                  path:(NSString *)path
                  body:(NSData *)body
               headers:(NSDictionary *)headers
          fragmentMode:(AWGFragmentMode)fragmentMode
            statusCode:(NSInteger *)outStatus
                 error:(NSError **)error;

@end
