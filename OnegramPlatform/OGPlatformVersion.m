#import "OGPlatformVersion.h"
#include <pthread.h>
#import <mach/mach_time.h>
#import <dlfcn.h>

NSInteger OGPlatformMajorVersion(void)
{
    static NSInteger value = -1;
    if (value >= 0)
        return value;
    @synchronized([UIDevice class])
    {
        if (value < 0)
        {
            NSString *version = [[UIDevice currentDevice] systemVersion];
            NSRange range = [version rangeOfString:@"."];
            NSString *major = range.location == NSNotFound ? version : [version substringToIndex:range.location];
            value = [major integerValue];
            if (value < 0)
                value = 0;
        }
    }
    return value;
}

BOOL OGPlatformSupportsBackgroundVoipTransport(void)
{
    static NSInteger value = -1;
    if (value >= 0)
        return value != 0;
    @synchronized([UIApplication class])
    {
        if (value < 0)
            value = OGPlatformMajorVersion() <= 9 && [UIApplication instancesRespondToSelector:NSSelectorFromString(@"setKeepAliveTimeout:handler:")] ? 1 : 0;
    }
    return value != 0;
}

BOOL OGPlatformSystemVersionAtLeast(CGFloat version)
{
    static double value = -1.0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = [[[UIDevice currentDevice] systemVersion] doubleValue];
    });
    return value + 0.0001 >= version;
}

NSTimeInterval OGPlatformSystemUptime(void)
{
    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != 0 || timebase.denom == 0)
        return 0.0;
    return ((double)mach_absolute_time() * (double)timebase.numer / (double)timebase.denom) / 1000000000.0;
}

CGFloat OGPlatformScreenScale(void)
{
    UIScreen *screen = [UIScreen mainScreen];
    SEL selector = NSSelectorFromString(@"scale");
    if ([screen respondsToSelector:selector])
    {
        CGFloat (*function)(id, SEL) = (CGFloat (*)(id, SEL))[screen methodForSelector:selector];
        if (function != NULL)
        {
            CGFloat scale = function(screen, selector);
            if (scale >= 1.0f)
                return scale;
        }
    }
    return 1.0f;
}

NSString *OGPlatformScreenBrightnessDidChangeNotification(void)
{
    return @"UIScreenBrightnessDidChangeNotification";
}

CGFloat OGPlatformScreenBrightness(void)
{
    UIScreen *screen = [UIScreen mainScreen];
    SEL selector = NSSelectorFromString(@"brightness");
    if ([screen respondsToSelector:selector])
    {
        CGFloat (*function)(id, SEL) = (CGFloat (*)(id, SEL))[screen methodForSelector:selector];
        if (function != NULL)
            return MIN(1.0f, MAX(0.0f, function(screen, selector)));
    }
    CFPropertyListRef value = CFPreferencesCopyAppValue(CFSTR("SBBacklightLevel2"), CFSTR("com.apple.springboard"));
    CGFloat brightness = 0.5f;
    if (value != NULL)
    {
        if (CFGetTypeID(value) == CFNumberGetTypeID())
        {
            float storedBrightness = (float)brightness;
            CFNumberGetValue((CFNumberRef)value, kCFNumberFloatType, &storedBrightness);
            brightness = storedBrightness;
        }
        CFRelease(value);
    }
    return MIN(1.0f, MAX(0.0f, brightness));
}

void OGPlatformSetScreenBrightness(CGFloat brightness)
{
    brightness = MIN(1.0f, MAX(0.0f, brightness));
    UIScreen *screen = [UIScreen mainScreen];
    SEL selector = NSSelectorFromString(@"setBrightness:");
    if ([screen respondsToSelector:selector])
    {
        void (*function)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[screen methodForSelector:selector];
        if (function != NULL)
            function(screen, selector, brightness);
        return;
    }
    void *graphicsServices = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_LAZY | RTLD_LOCAL);
    void (*setBacklightLevel)(float) = graphicsServices == NULL ? NULL : (void (*)(float))dlsym(graphicsServices, "GSEventSetBacklightLevel");
    if (setBacklightLevel != NULL)
        setBacklightLevel((float)brightness);
    float storedBrightness = (float)brightness;
    CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &storedBrightness);
    if (value != NULL)
    {
        CFPreferencesSetAppValue(CFSTR("SBBacklightLevel2"), value, CFSTR("com.apple.springboard"));
        CFPreferencesAppSynchronize(CFSTR("com.apple.springboard"));
        CFRelease(value);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:OGPlatformScreenBrightnessDidChangeNotification() object:screen];
}

BOOL OGPlatformClassAvailable(NSString *className)
{
    if ([className length] == 0)
        return NO;
    return NSClassFromString(className) != Nil;
}

BOOL OGPlatformObjectResponds(id object, NSString *selectorName)
{
    if (object == nil || [selectorName length] == 0)
        return NO;
    return [object respondsToSelector:NSSelectorFromString(selectorName)];
}

BOOL OGPlatformSupportsRegionalIndicatorEmoji(void)
{
    return OGPlatformMajorVersion() >= 5;
}

static pthread_mutex_t OGPlatformDefaultsCacheLock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary *OGPlatformDefaultsCache = nil;

static NSNumber *OGPlatformCachedDefault(NSString *key)
{
    if (key == nil)
        return nil;
    pthread_mutex_lock(&OGPlatformDefaultsCacheLock);
    if (OGPlatformDefaultsCache == nil)
    {
        OGPlatformDefaultsCache = [[NSMutableDictionary alloc] init];
        [[NSNotificationCenter defaultCenter] addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            pthread_mutex_lock(&OGPlatformDefaultsCacheLock);
            [OGPlatformDefaultsCache removeAllObjects];
            pthread_mutex_unlock(&OGPlatformDefaultsCacheLock);
        }];
    }
    id value = OGPlatformDefaultsCache[key];
    pthread_mutex_unlock(&OGPlatformDefaultsCacheLock);
    if (value == nil)
    {
        id stored = [[NSUserDefaults standardUserDefaults] objectForKey:key];
        value = [stored isKindOfClass:[NSNumber class]] ? stored : (stored != nil && [stored respondsToSelector:@selector(integerValue)] ? @([stored integerValue]) : [NSNull null]);
        pthread_mutex_lock(&OGPlatformDefaultsCacheLock);
        OGPlatformDefaultsCache[key] = value;
        pthread_mutex_unlock(&OGPlatformDefaultsCacheLock);
    }
    return value == [NSNull null] ? nil : value;
}

BOOL OGPlatformCachedBoolDefault(NSString *key)
{
    return [OGPlatformCachedDefault(key) boolValue];
}

NSInteger OGPlatformCachedIntegerDefault(NSString *key, NSInteger missingValue)
{
    NSNumber *value = OGPlatformCachedDefault(key);
    return value != nil ? [value integerValue] : missingValue;
}
