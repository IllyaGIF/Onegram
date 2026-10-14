#import <Foundation/Foundation.h>

@class TGVCard;


@interface TGContactModel : NSObject

@property (nonatomic, strong, readonly) NSString *firstName;
@property (nonatomic, strong, readonly) NSString *lastName;

@property (nonatomic, strong, readonly) NSArray *phoneNumbers;

@property (nonatomic, strong, readonly) TGVCard *vcard;

- (instancetype)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumbers:(NSArray *)phoneNumbers vcard:(TGVCard *)vcard;

@end
