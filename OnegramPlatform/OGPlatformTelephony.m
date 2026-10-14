#import "OGPlatformTelephony.h"

#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <objc/message.h>

static id OGPlatformTelephonyObject(id object, NSString *selectorName)
{
    SEL selector = NSSelectorFromString(selectorName);
    if (object == nil || ![object respondsToSelector:selector])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static id OGPlatformNetworkInfo(void)
{
    Class networkInfoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    return networkInfoClass == Nil ? nil : [[networkInfoClass alloc] init];
}

static NSString *OGPlatformModernCarrierValue(NSString *selectorName)
{
    id networkInfo = OGPlatformNetworkInfo();
    id carrier = OGPlatformTelephonyObject(networkInfo, @"subscriberCellularProvider");
    id value = OGPlatformTelephonyObject(carrier, selectorName);
    return [value isKindOfClass:[NSString class]] ? [value copy] : nil;
}

static void *OGPlatformLegacyCoreTelephony(void)
{
    static void *handle = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/CoreTelephony.framework/CoreTelephony", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

static NSString *OGPlatformLegacySIMValue(const char *symbolName)
{
    void *handle = OGPlatformLegacyCoreTelephony();
    if (handle == NULL)
        return nil;
    CFStringRef (*function)(CFAllocatorRef) = (CFStringRef (*)(CFAllocatorRef))dlsym(handle, symbolName);
    if (function == NULL)
        return nil;
    CFStringRef value = function(kCFAllocatorDefault);
    return value == NULL ? nil : (__bridge_transfer NSString *)value;
}

NSString *OGPlatformCarrierISOCountryCode(void)
{
    return OGPlatformModernCarrierValue(@"isoCountryCode");
}

NSString *OGPlatformCarrierMobileCountryCode(void)
{
    NSString *value = OGPlatformModernCarrierValue(@"mobileCountryCode");
    return value != nil ? value : OGPlatformLegacySIMValue("CTSIMSupportCopyMobileSubscriberCountryCode");
}

NSString *OGPlatformCarrierMobileNetworkCode(void)
{
    NSString *value = OGPlatformModernCarrierValue(@"mobileNetworkCode");
    return value != nil ? value : OGPlatformLegacySIMValue("CTSIMSupportCopyMobileSubscriberNetworkCode");
}

BOOL OGPlatformIsOnPhoneCall(void)
{
    Class callCenterClass = NSClassFromString(@"CTCallCenter");
    if (callCenterClass != Nil)
    {
        id callCenter = [[callCenterClass alloc] init];
        id calls = OGPlatformTelephonyObject(callCenter, @"currentCalls");
        for (id call in calls)
        {
            NSString *state = OGPlatformTelephonyObject(call, @"callState");
            if ([state isEqualToString:@"CTCallStateConnected"])
                return YES;
        }
        return NO;
    }

    void *handle = OGPlatformLegacyCoreTelephony();
    if (handle == NULL)
        return NO;
    CFArrayRef (*function)(CFAllocatorRef) = (CFArrayRef (*)(CFAllocatorRef))dlsym(handle, "CTCopyCurrentCalls");
    if (function == NULL)
        return NO;
    CFArrayRef calls = function(kCFAllocatorDefault);
    BOOL result = calls != NULL && CFArrayGetCount(calls) != 0;
    if (calls != NULL)
        CFRelease(calls);
    return result;
}
