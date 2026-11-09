#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

typedef void (^OGPlatformAddressBookAccessCompletion)(bool granted, CFErrorRef error);

FOUNDATION_EXPORT ABAddressBookRef OGPlatformAddressBookCreate(CFErrorRef *error);
FOUNDATION_EXPORT void OGPlatformAddressBookRequestAccess(ABAddressBookRef addressBook, OGPlatformAddressBookAccessCompletion completion);
