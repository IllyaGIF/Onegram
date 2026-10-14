#import <Foundation/Foundation.h>

#import "LegacyComponentsInternal.h"
#import "OGPlatformVersion.h"

#import "TGLocalization.h"

static id<LegacyComponentsGlobalsProvider> _provider;

@implementation LegacyComponentsGlobals

+ (void)setProvider:(id<LegacyComponentsGlobalsProvider>)provider {
    _provider = provider;
}

+ (id<LegacyComponentsGlobalsProvider>)provider {
    return _provider;
}

@end

NSInteger TGCurrentInterfaceStyle(void)
{
    NSInteger value = OGPlatformCachedIntegerDefault(@"TGInterfaceStyle", -1);
    if (value == -1)
        return OGPlatformCachedBoolDefault(@"TGClassicIOS6Style") ? 1 : 0;
    return value >= 0 && value <= 2 ? value : 0;
}
