#import "OGCoreSupport.h"
#import <Security/Security.h>
#include <stdarg.h>

void OGCoreLog(NSString *format, ...)
{
    if (!OGDiagnosticsEnabled())
        return;
    va_list arguments;
    va_start(arguments, format);
    NSLogv(format, arguments);
    va_end(arguments);
}

OSStatus OGCoreMoveKeychainItem(NSString *legacyService, NSString *service, NSString *account)
{
    NSDictionary *legacyQuery = [NSDictionary dictionaryWithObjectsAndKeys:
        (id)kSecClassGenericPassword, (id)kSecClass,
        legacyService, (id)kSecAttrService,
        account, (id)kSecAttrAccount, nil];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:service forKey:(id)kSecAttrService];
    OSStatus status = SecItemUpdate((CFDictionaryRef)legacyQuery, (CFDictionaryRef)attributes);
    if (status == errSecDuplicateItem) status = SecItemDelete((CFDictionaryRef)legacyQuery);
    return status == errSecItemNotFound ? errSecSuccess : status;
}

void OGCoreMoveUserDefaultsValue(NSString *legacyKey, NSString *key)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id value = [defaults objectForKey:legacyKey];
    if (value == nil) return;
    if ([defaults objectForKey:key] == nil) [defaults setObject:value forKey:key];
    [defaults removeObjectForKey:legacyKey];
    [defaults synchronize];
}
