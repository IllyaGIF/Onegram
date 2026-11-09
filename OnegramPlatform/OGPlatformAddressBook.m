#import "OGPlatformAddressBook.h"

ABAddressBookRef OGPlatformAddressBookCreate(CFErrorRef *error)
{
    if (error != NULL)
        *error = NULL;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    return ABAddressBookCreateWithOptions(NULL, error);
#elif __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    if (ABAddressBookCreateWithOptions != NULL)
        return ABAddressBookCreateWithOptions(NULL, error);
    return ABAddressBookCreate();
#else
    return ABAddressBookCreate();
#endif
}

void OGPlatformAddressBookRequestAccess(ABAddressBookRef addressBook, OGPlatformAddressBookAccessCompletion completion)
{
    if (completion == nil)
        return;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
    ABAddressBookRequestAccessWithCompletion(addressBook, completion);
#elif __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    if (ABAddressBookRequestAccessWithCompletion != NULL)
        ABAddressBookRequestAccessWithCompletion(addressBook, completion);
    else
        completion(true, NULL);
#else
    completion(true, NULL);
#endif
}
