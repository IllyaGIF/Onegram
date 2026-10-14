#import "TGContactModel.h"
#import "TGLegacyDatabasePhoneUtils.h"

@implementation TGContactModel

- (instancetype)initWithFirstName:(NSString *)firstName lastName:(NSString *)lastName phoneNumbers:(NSArray *)phoneNumbers vcard:(TGVCard *)vcard
{
    self = [super init];
    if (self != nil)
    {
        _firstName = firstName;
        _lastName = lastName;
        _phoneNumbers = phoneNumbers;
        _vcard = vcard;
    }
    return self;
}

@end
