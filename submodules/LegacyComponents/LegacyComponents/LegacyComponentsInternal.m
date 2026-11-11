#define ONEGRAM_LOG_IMPLEMENTATION 1
#import "LegacyComponentsInternal.h"

#import "TGLocalization.h"
#import "OGPlatformVersion.h"
#import "OGPlatformDispatch.h"
#import "OGMemoryCache.h"

#import <UIKit/UIKit.h>

#import <sys/sysctl.h>

TGLocalization *legacyEffectiveLocalization() {
    return [[LegacyComponentsGlobals provider] effectiveLocalization];
}

NSString *TGLocalized(NSString *s) {
    TGLocalization *localization = legacyEffectiveLocalization();
    if (localization == nil) {
        static TGLocalization *bundledLocalization = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *code = [[[NSBundle mainBundle] preferredLocalizations] firstObject];
            if (code.length == 0 || [code isEqualToString:@"Base"])
                code = @"en";
            bundledLocalization = [[TGLocalization alloc] initWithVersion:0 code:code preparedDict:@{} isActive:false];
        });
        localization = bundledLocalization;
    }
    return [localization get:s];
}

bool TGObjectCompare(id obj1, id obj2) {
    if (obj1 == nil && obj2 == nil)
        return true;
    
    return [obj1 isEqual:obj2];
}

bool TGStringCompare(NSString *s1, NSString *s2) {
    if (s1.length == 0 && s2.length == 0)
        return true;
    
    if ((s1 == nil) != (s2 == nil))
        return false;
    
    return s1 == nil || [s1 isEqualToString:s2];
}

#undef TGLegacyLog
void TGLegacyLog(NSString *format, ...)
{
    if (!OGDiagnosticsEnabled())
        return;
    va_list L;
    va_start(L, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:L];
    va_end(L);
    [[LegacyComponentsGlobals provider] log:string];
}

int iosMajorVersion()
{
    return (int)OGPlatformMajorVersion();
}

int iosMinorVersion()
{
    static bool initialized = false;
    static int version = 0;
    if (!initialized)
    {
        NSString *versionString = [[UIDevice currentDevice] systemVersion];
        NSRange range = [versionString rangeOfString:@"."];
        if (range.location != NSNotFound)
            version = [[versionString substringFromIndex:range.location + 1] intValue];
        
        initialized = true;
    }
    return version;
}

NSString *TGEncodeText(NSString *string, int key)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < (int)[string length]; i++)
    {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

int deviceMemorySize()
{
    static int memorySize = 0;
    if (memorySize == 0)
    {
        size_t len = sizeof(uint64_t);
        uint64_t nmem = 0;
        if (sysctlbyname("hw.memsize", &nmem, &len, NULL, 0) != 0 || nmem == 0)
            nmem = 512ULL * 1024ULL * 1024ULL;
        memorySize = (int)(nmem / (1024ULL * 1024ULL));
        if (memorySize <= 0)
            memorySize = 512;
    }
    return memorySize;
}

int cpuCoreCount()
{
    static int count = 0;
    if (count == 0)
    {
        size_t len = sizeof(uint32_t);
        uint32_t ncpu = 0;
        if (sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0) != 0 || ncpu == 0)
            ncpu = 1;
        count = (int)ncpu;
    }
    
    return count;
}


void TGDispatchOnMainThread(dispatch_block_t block)
{
    OGPlatformDispatchOnMainThread(block);
}

void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), queue, block);
}

static NSBundle *frameworkBundle() {
    static NSBundle *currentBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        currentBundle = [NSBundle bundleForClass:[LegacyComponentsGlobals class]];
        NSString *updatedPath = [[currentBundle bundlePath] stringByAppendingPathComponent:@"LegacyComponentsResources.bundle"];
        currentBundle = [NSBundle bundleWithPath:updatedPath];
    });
    return currentBundle;
}

static OGMemoryCache *TGComponentsImageCache(void) {
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[OGMemoryCache alloc] initWithCountLimit:384 costLimit:OGMemoryCacheBudget(6u * 1024u * 1024u)];
    });
    return cache;
}

static UIImage *TGComponentsLoadImageNamed(NSString *name) {
    UIImage *image = nil;
    if ([name pathExtension].length != 0) {
        NSString *file = [frameworkBundle() pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]];
        if (file.length != 0)
            image = [UIImage imageWithContentsOfFile:file];
    }
    
    if (image == nil)
        image = [UIImage imageNamed:[@"LegacyComponentsResources.bundle/" stringByAppendingString:name]];
    return image != nil ? image : [UIImage imageNamed:name];
}

UIImage *TGComponentsImageNamed(NSString *name) {
    if (name.length == 0)
        return nil;
    OGMemoryCache *cache = TGComponentsImageCache();
    id cached = [cache objectForKey:name];
    if (cached != nil)
        return cached == [NSNull null] ? nil : (UIImage *)cached;
    UIImage *image = TGComponentsLoadImageNamed(name);
    if (image != nil) {
        CGFloat scale = image.scale > 0.0f ? image.scale : 1.0f;
        NSUInteger cost = (NSUInteger)MAX(1.0f, image.size.width * scale * image.size.height * scale * 4.0f);
        [cache setObject:image forKey:name cost:cost];
    } else {
        [cache setObject:[NSNull null] forKey:name cost:64];
    }
    return image;
}

NSString *TGComponentsPathForResource(NSString *name, NSString *type) {
    return [frameworkBundle() pathForResource:name ofType:type];
}
