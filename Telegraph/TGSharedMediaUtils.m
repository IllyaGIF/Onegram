#import "TGSharedMediaUtils.h"

#import "TGMediaStoreContext.h"
#import "../OnegramPlatform/OGMemoryCache.h"
#import <sys/utsname.h>

static bool OGCompatIsLowPowerMediaHardware(void)
{
    static bool lowPower = false;
    static dispatch_once_t probeToken;
    dispatch_once(&probeToken, ^
    {
        struct utsname name;
        memset(&name, 0, sizeof(name));
        uname(&name);
        NSString *model = [NSString stringWithUTF8String:name.machine] ?: @"";
        for (NSString *prefix in @[@"iPhone2,", @"iPhone3,", @"iPod4,", @"iPad1,"])
        {
            if ([model hasPrefix:prefix])
            {
                lowPower = true;
                break;
            }
        }
    });
    return lowPower;
}

@implementation TGSharedMediaUtils

+ (TGMemoryImageCache *)sharedMediaMemoryImageCache
{
    static TGMemoryImageCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        float factor = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? 3.0f : 1.0f;
        instance = [[TGMemoryImageCache alloc] initWithSoftMemoryLimit:OGMemoryCacheBudget((NSUInteger)(2 * 1024 * 1024 * factor)) hardMemoryLimit:OGMemoryCacheBudget((NSUInteger)(3 * 1024 * 1024 * factor))];
    });
    return instance;
}

+ (EMInMemoryImageCache *)inMemoryImageCache
{
    static EMInMemoryImageCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        float factor = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad ? 3.0f : 1.0f;
        instance = [[EMInMemoryImageCache alloc] initWithMaxResidentSize:(NSUInteger)(4 * 1024 * 1024 * factor)];
    });
    return instance;
}

+ (SThreadPool *)sharedMediaImageProcessingThreadPool
{
    static SThreadPool *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = OGCompatIsLowPowerMediaHardware() ? [[SThreadPool alloc] initWithThreadCount:1 threadPriority:0.25] : [[SThreadPool alloc] init];
    });
    return instance;
}

+ (TGModernCache *)sharedMediaTemporaryPersistentCache
{
    return [[TGMediaStoreContext instance] temporaryFilesCache];
}

@end
