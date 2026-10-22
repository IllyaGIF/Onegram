

#import <Foundation/Foundation.h>

@interface TGPhoneUtils : NSObject

+ (void)prepareFormatter;
+ (NSString *)formatPhone:(NSString *)phone forceInternational:(bool)forceInternational;
+ (NSString *)formatPhoneUrl:(NSString *)phone;

+ (NSString *)cleanPhone:(NSString *)phone;
+ (NSString *)cleanInternationalPhone:(NSString *)phone forceInternational:(bool)forceInternational;

+ (bool)maybePhone:(NSString *)phone;

@end
