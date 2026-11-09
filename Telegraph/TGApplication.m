#import "TGApplication.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"

#import "../submodules/LegacyComponents/SafariServices/SafariServices.h"
#import "../submodules/LegacyComponents/Contacts/Contacts.h"
#import "../submodules/LegacyComponents/WatchConnectivity/WatchConnectivity.h"
#import "TGWebAppController.h"
#import "TGHashtagOverviewController.h"
#import "TGRootController.h"
#import "TGPluginHost.h"
#import <dlfcn.h>

#import <QuartzCore/QuartzCore.h>
#import "../OnegramPlatform/OGPlatformDispatch.h"

enum
{
    TGApplicationLoopPhaseOther = 0,
    TGApplicationLoopPhaseTimers = 1,
    TGApplicationLoopPhaseSources = 2,
    TGApplicationLoopPhaseCommit = 3,
    TGApplicationLoopPhaseCount = 4
};

typedef struct
{
    bool hasMinimumOffset;
    double minimumOffset;
    double windowStart;
    unsigned int events;
    unsigned int moves;
    unsigned int late;
    double ageTotal;
    double ageMaximum;
    double handleTotal;
    double handleMaximum;
    double loopBusy;
    double loopMaximum;
    unsigned int loops;
    unsigned int slowLoops;
    unsigned int slowReports;
    double phases[TGApplicationLoopPhaseCount];
} TGApplicationInputStatistics;

typedef struct
{
    double start;
    double phaseStart;
    int phase;
    double phases[TGApplicationLoopPhaseCount];
    double events;
    unsigned int eventCount;
} TGApplicationLoopIteration;

static TGApplicationInputStatistics TGApplicationInput = {};
static TGApplicationLoopIteration TGApplicationLoop = {};
static double TGApplicationLastTouch = 0.0;
static CFRunLoopObserverRef TGApplicationLoopPhaseObserver = NULL;
static CFRunLoopObserverRef TGApplicationLoopCommitObserver = NULL;

static void TGApplicationCloseLoopPhase(double now, int nextPhase)
{
    if (TGApplicationLoop.start <= 0.0)
        return;
    TGApplicationLoop.phases[TGApplicationLoop.phase] += now - TGApplicationLoop.phaseStart;
    TGApplicationLoop.phaseStart = now;
    TGApplicationLoop.phase = nextPhase;
}

static void TGApplicationFinishLoopIteration(double now)
{
    if (TGApplicationLoop.start <= 0.0)
        return;
    TGApplicationCloseLoopPhase(now, TGApplicationLoopPhaseOther);
    double busy = now - TGApplicationLoop.start;
    TGApplicationLoop.start = 0.0;
    if (TGApplicationInput.events == 0)
        return;
    TGApplicationInput.loopBusy += busy;
    TGApplicationInput.loopMaximum = MAX(TGApplicationInput.loopMaximum, busy);
    TGApplicationInput.loops++;
    for (int phase = 0; phase < TGApplicationLoopPhaseCount; phase++)
        TGApplicationInput.phases[phase] += TGApplicationLoop.phases[phase];
    if (busy < 0.1)
        return;
    TGApplicationInput.slowLoops++;
    if (now - TGApplicationLastTouch > 1.0 || TGApplicationInput.slowReports >= 20)
        return;
    TGApplicationInput.slowReports++;
    OGPlatformDiagnosticLog(@"LOOPSLOW busy_ms=%.0f timers_ms=%.0f sources_ms=%.0f events_ms=%.0f events=%u commit_ms=%.0f other_ms=%.0f", busy * 1000.0, TGApplicationLoop.phases[TGApplicationLoopPhaseTimers] * 1000.0, TGApplicationLoop.phases[TGApplicationLoopPhaseSources] * 1000.0, TGApplicationLoop.events * 1000.0, TGApplicationLoop.eventCount, TGApplicationLoop.phases[TGApplicationLoopPhaseCommit] * 1000.0, TGApplicationLoop.phases[TGApplicationLoopPhaseOther] * 1000.0);
}

static void TGApplicationLoopPhaseActivity(__unused CFRunLoopObserverRef observer, CFRunLoopActivity activity, __unused void *info)
{
    double now = CACurrentMediaTime();
    switch (activity)
    {
        case kCFRunLoopAfterWaiting:
            memset(&TGApplicationLoop, 0, sizeof(TGApplicationLoop));
            TGApplicationLoop.start = now;
            TGApplicationLoop.phaseStart = now;
            TGApplicationLoop.phase = TGApplicationLoopPhaseOther;
            break;
        case kCFRunLoopBeforeTimers:
            TGApplicationCloseLoopPhase(now, TGApplicationLoopPhaseTimers);
            break;
        case kCFRunLoopBeforeSources:
            TGApplicationCloseLoopPhase(now, TGApplicationLoopPhaseSources);
            break;
        case kCFRunLoopBeforeWaiting:
            TGApplicationCloseLoopPhase(now, TGApplicationLoopPhaseCommit);
            break;
        default:
            break;
    }
}

static void TGApplicationLoopCommitActivity(__unused CFRunLoopObserverRef observer, __unused CFRunLoopActivity activity, __unused void *info)
{
    TGApplicationFinishLoopIteration(CACurrentMediaTime());
}

static void TGApplicationInstallLoopObservers(void)
{
    if (TGApplicationLoopPhaseObserver != NULL)
        return;
    TGApplicationLoopPhaseObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAfterWaiting | kCFRunLoopBeforeTimers | kCFRunLoopBeforeSources | kCFRunLoopBeforeWaiting, true, 1999999, TGApplicationLoopPhaseActivity, NULL);
    TGApplicationLoopCommitObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting | kCFRunLoopExit, true, 2000001, TGApplicationLoopCommitActivity, NULL);
    if (TGApplicationLoopPhaseObserver != NULL)
        CFRunLoopAddObserver(CFRunLoopGetMain(), TGApplicationLoopPhaseObserver, kCFRunLoopCommonModes);
    if (TGApplicationLoopCommitObserver != NULL)
        CFRunLoopAddObserver(CFRunLoopGetMain(), TGApplicationLoopCommitObserver, kCFRunLoopCommonModes);
}

static void TGApplicationRecordInput(double arrival, double offset, double handled, bool moved)
{
    TGApplicationInputStatistics *statistics = &TGApplicationInput;
    TGApplicationInstallLoopObservers();
    TGApplicationLastTouch = arrival;
    TGApplicationLoop.events += handled;
    TGApplicationLoop.eventCount++;
    if (!statistics->hasMinimumOffset || offset < statistics->minimumOffset)
    {
        statistics->minimumOffset = offset;
        statistics->hasMinimumOffset = true;
    }
    double age = MAX(0.0, offset - statistics->minimumOffset);
    if (statistics->events == 0)
        statistics->windowStart = arrival;
    statistics->events++;
    if (moved)
        statistics->moves++;
    if (age >= 0.05)
        statistics->late++;
    statistics->ageTotal += age;
    statistics->ageMaximum = MAX(statistics->ageMaximum, age);
    statistics->handleTotal += handled;
    statistics->handleMaximum = MAX(statistics->handleMaximum, handled);
    double window = arrival - statistics->windowStart;
    if (window < 5.0)
        return;
    OGPlatformDiagnosticLog(@"INPUT window_ms=%.0f events=%u moves=%u late=%u age_avg_ms=%.1f age_max_ms=%.1f handle_avg_ms=%.1f handle_max_ms=%.1f handle_total_ms=%.0f loops=%u slow=%u loop_busy_ms=%.0f loop_max_ms=%.0f timers_ms=%.0f sources_ms=%.0f commit_ms=%.0f other_ms=%.0f", window * 1000.0, statistics->events, statistics->moves, statistics->late, statistics->ageTotal * 1000.0 / statistics->events, statistics->ageMaximum * 1000.0, statistics->handleTotal * 1000.0 / statistics->events, statistics->handleMaximum * 1000.0, statistics->handleTotal * 1000.0, statistics->loops, statistics->slowLoops, statistics->loopBusy * 1000.0, statistics->loopMaximum * 1000.0, statistics->phases[TGApplicationLoopPhaseTimers] * 1000.0, statistics->phases[TGApplicationLoopPhaseSources] * 1000.0, statistics->phases[TGApplicationLoopPhaseCommit] * 1000.0, statistics->phases[TGApplicationLoopPhaseOther] * 1000.0);
    double minimumOffset = statistics->minimumOffset;
    memset(statistics, 0, sizeof(*statistics));
    statistics->hasMinimumOffset = true;
    statistics->minimumOffset = minimumOffset;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation UIPercentDrivenInteractiveTransition
- (void)updateInteractiveTransition:(CGFloat)percentComplete {}
- (void)cancelInteractiveTransition {}
- (void)finishInteractiveTransition {}
@end
#endif

void TGAssert(bool value)
{
    if (!value)
        NSLog(@"TGAssert failed");
}

static Class TGIOS6RuntimeSystemClass(NSString *name, Class compatibilityClass)
{
    Class systemClass = NSClassFromString(name);
    if (systemClass == Nil)
    {
        if ([name hasPrefix:@"PH"])
            dlopen("/System/Library/Frameworks/Photos.framework/Photos", RTLD_LAZY | RTLD_LOCAL);
        else if ([name hasPrefix:@"CN"])
            dlopen("/System/Library/Frameworks/Contacts.framework/Contacts", RTLD_LAZY | RTLD_LOCAL);
        else if ([name isEqualToString:@"WCSession"])
            dlopen("/System/Library/Frameworks/WatchConnectivity.framework/WatchConnectivity", RTLD_LAZY | RTLD_LOCAL);

        systemClass = NSClassFromString(name);
    }
    if (systemClass == Nil || systemClass == compatibilityClass)
        return Nil;
    return systemClass;
}

#define TGIOS6_RUNTIME_PROXY_METHODS(systemName) \
+ (id)allocWithZone:(NSZone *)zone \
{ \
    Class systemClass = TGIOS6RuntimeSystemClass(@systemName, self); \
    if (systemClass != Nil) \
        return [systemClass allocWithZone:zone]; \
    return [super allocWithZone:zone]; \
} \
+ (id)forwardingTargetForSelector:(SEL)selector \
{ \
    Class systemClass = TGIOS6RuntimeSystemClass(@systemName, self); \
    if (systemClass != Nil && [systemClass respondsToSelector:selector]) \
        return systemClass; \
    return nil; \
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation NSURLSessionConfiguration
TGIOS6_RUNTIME_PROXY_METHODS("NSURLSessionConfiguration")
+ (instancetype)defaultSessionConfiguration
{
    Class systemClass = TGIOS6RuntimeSystemClass(@"NSURLSessionConfiguration", self);
    SEL selector = @selector(defaultSessionConfiguration);
    if (systemClass != Nil && [systemClass respondsToSelector:selector])
    {
        IMP implementation = [systemClass methodForSelector:selector];
        id (*function)(id, SEL) = (void *)implementation;
        return function(systemClass, selector);
    }
    return [[self alloc] init];
}
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation NSURLSession
TGIOS6_RUNTIME_PROXY_METHODS("NSURLSession")
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
{
    Class systemClass = TGIOS6RuntimeSystemClass(@"NSURLSession", self);
    SEL selector = @selector(sessionWithConfiguration:);
    if (systemClass != Nil && [systemClass respondsToSelector:selector])
    {
        IMP implementation = [systemClass methodForSelector:selector];
        id (*function)(id, SEL, id) = (void *)implementation;
        return function(systemClass, selector, configuration);
    }
    return [[self alloc] init];
}
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue
{
    Class systemClass = TGIOS6RuntimeSystemClass(@"NSURLSession", self);
    SEL selector = @selector(sessionWithConfiguration:delegate:delegateQueue:);
    if (systemClass != Nil && [systemClass respondsToSelector:selector])
    {
        IMP implementation = [systemClass methodForSelector:selector];
        id (*function)(id, SEL, id, id, id) = (void *)implementation;
        return function(systemClass, selector, configuration, delegate, queue);
    }
    return [[self alloc] init];
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
{
    return nil;
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
{
    return nil;
}
- (void)invalidateAndCancel {}
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation NSURLSessionTask
TGIOS6_RUNTIME_PROXY_METHODS("NSURLSessionTask")
- (void)resume {}
- (void)cancel {}
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation NSURLSessionDataTask
TGIOS6_RUNTIME_PROXY_METHODS("NSURLSessionDataTask")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000
@implementation UIImpactFeedbackGenerator
TGIOS6_RUNTIME_PROXY_METHODS("UIImpactFeedbackGenerator")
- (instancetype)initWithStyle:(NSInteger)style
{
    return [super init];
}
- (void)prepare {}
- (void)impactOccurred {}
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation UIKeyCommand
TGIOS6_RUNTIME_PROXY_METHODS("UIKeyCommand")
+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(NSUInteger)modifierFlags action:(SEL)action
{
    if (iosMajorVersion() >= 7)
    {
        Class systemKeyCommandClass = NSClassFromString(@"UIKeyCommand");
        SEL factorySelector = @selector(keyCommandWithInput:modifierFlags:action:);
        if (systemKeyCommandClass != Nil && systemKeyCommandClass != [self class] &&
            [systemKeyCommandClass respondsToSelector:factorySelector])
        {
            IMP implementation = [systemKeyCommandClass methodForSelector:factorySelector];
            id (*factory)(id, SEL, NSString *, NSUInteger, SEL) = (void *)implementation;
            return factory(systemKeyCommandClass, factorySelector, input, modifierFlags, action);
        }
    }

    return [[self alloc] init];
}
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation UIAlertController
TGIOS6_RUNTIME_PROXY_METHODS("UIAlertController")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation UIDocumentPickerViewController
TGIOS6_RUNTIME_PROXY_METHODS("UIDocumentPickerViewController")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHObject
TGIOS6_RUNTIME_PROXY_METHODS("PHObject")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHAsset
TGIOS6_RUNTIME_PROXY_METHODS("PHAsset")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHAssetChangeRequest
TGIOS6_RUNTIME_PROXY_METHODS("PHAssetChangeRequest")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHAssetCollection
TGIOS6_RUNTIME_PROXY_METHODS("PHAssetCollection")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation PHAssetResource
TGIOS6_RUNTIME_PROXY_METHODS("PHAssetResource")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation PHAssetResourceManager
TGIOS6_RUNTIME_PROXY_METHODS("PHAssetResourceManager")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHCachingImageManager
TGIOS6_RUNTIME_PROXY_METHODS("PHCachingImageManager")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHFetchOptions
TGIOS6_RUNTIME_PROXY_METHODS("PHFetchOptions")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHImageManager
TGIOS6_RUNTIME_PROXY_METHODS("PHImageManager")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHImageRequestOptions
TGIOS6_RUNTIME_PROXY_METHODS("PHImageRequestOptions")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation PHLivePhotoRequestOptions
TGIOS6_RUNTIME_PROXY_METHODS("PHLivePhotoRequestOptions")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHPhotoLibrary
TGIOS6_RUNTIME_PROXY_METHODS("PHPhotoLibrary")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
@implementation PHVideoRequestOptions
TGIOS6_RUNTIME_PROXY_METHODS("PHVideoRequestOptions")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation CNContactFormatter
TGIOS6_RUNTIME_PROXY_METHODS("CNContactFormatter")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation CNContactVCardSerialization
TGIOS6_RUNTIME_PROXY_METHODS("CNContactVCardSerialization")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation CNLabeledValue
TGIOS6_RUNTIME_PROXY_METHODS("CNLabeledValue")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation CNMutableContact
TGIOS6_RUNTIME_PROXY_METHODS("CNMutableContact")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation CNPhoneNumber
TGIOS6_RUNTIME_PROXY_METHODS("CNPhoneNumber")
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
@implementation WCSession
TGIOS6_RUNTIME_PROXY_METHODS("WCSession")
@end
#endif

static NSString *TGIos6YouTubeDecodedString(NSString *string)
{
    NSString *result = string;
    for (NSUInteger i = 0; i < 3 && result.length != 0; i++)
    {
        NSString *decoded = [result stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (decoded.length == 0 || [decoded isEqualToString:result])
            break;
        result = decoded;
    }
    return result;
}

static NSString *TGIos6YouTubeQueryValue(NSURL *url, NSArray *names)
{
    NSString *query = url.query;
    if (query.length == 0)
        return nil;

    for (NSString *item in [query componentsSeparatedByString:@"&"])
    {
        NSRange separator = [item rangeOfString:@"="];
        NSString *rawKey = separator.location == NSNotFound ? item : [item substringToIndex:separator.location];
        NSString *key = [[TGIos6YouTubeDecodedString(rawKey) lowercaseString] stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        if (![names containsObject:key])
            continue;

        NSString *rawValue = separator.location == NSNotFound ? @"" : [item substringFromIndex:separator.location + 1];
        return TGIos6YouTubeDecodedString([rawValue stringByReplacingOccurrencesOfString:@"+" withString:@" "]);
    }
    return nil;
}

static BOOL TGIos6YouTubeHostMatches(NSString *host, NSString *domain)
{
    if ([host isEqualToString:domain])
        return YES;
    return [host hasSuffix:[@"." stringByAppendingString:domain]];
}

static NSString *TGIos6YouTubeValidatedVideoId(NSString *candidate)
{
    candidate = TGIos6YouTubeDecodedString(candidate);
    if (candidate.length == 0)
        return nil;

    NSCharacterSet *invalidCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet];
    NSRange invalidRange = [candidate rangeOfCharacterFromSet:invalidCharacters];
    if (invalidRange.location == 0)
        return nil;
    if (invalidRange.location != NSNotFound)
        candidate = [candidate substringToIndex:invalidRange.location];

    return candidate.length == 11 ? candidate : nil;
}

static NSString *TGIos6YouTubeVideoIdFromURL(NSURL *url, NSUInteger depth)
{
    if (url == nil || depth > 3)
        return nil;

    NSString *host = [url.host lowercaseString];
    if (host.length == 0)
        return nil;

    BOOL shortHost = TGIos6YouTubeHostMatches(host, @"youtu.be");
    BOOL youtubeHost = TGIos6YouTubeHostMatches(host, @"youtube.com") || TGIos6YouTubeHostMatches(host, @"youtube-nocookie.com");
    if (!shortHost && !youtubeHost)
        return nil;

    if (youtubeHost)
    {
        NSString *lowerPath = [url.path lowercaseString];
        if ([lowerPath isEqualToString:@"/redirect"] || [lowerPath isEqualToString:@"/attribution_link"])
        {
            NSString *wrappedString = TGIos6YouTubeQueryValue(url, @[@"u", @"url", @"q"]);
            if (wrappedString.length != 0)
            {
                if ([wrappedString hasPrefix:@"//"])
                    wrappedString = [@"https:" stringByAppendingString:wrappedString];
                else if ([wrappedString hasPrefix:@"/"])
                    wrappedString = [@"https://www.youtube.com" stringByAppendingString:wrappedString];
                else if ([wrappedString rangeOfString:@"://"].location == NSNotFound)
                    wrappedString = [@"https://" stringByAppendingString:wrappedString];

                NSString *wrappedId = TGIos6YouTubeVideoIdFromURL([NSURL URLWithString:wrappedString], depth + 1);
                if (wrappedId.length != 0)
                    return wrappedId;
            }
        }
    }

    NSString *candidate = nil;
    if (shortHost)
    {
        for (NSString *component in [url.path componentsSeparatedByString:@"/"])
        {
            if (component.length != 0)
            {
                candidate = component;
                break;
            }
        }
    }
    else
    {
        candidate = TGIos6YouTubeQueryValue(url, @[@"v"]);
        if (candidate.length == 0)
        {
            NSArray *components = [url.path componentsSeparatedByString:@"/"];
            for (NSUInteger index = 0; index + 1 < components.count; index++)
            {
                NSString *component = [[components objectAtIndex:index] lowercaseString];
                if ([component isEqualToString:@"shorts"] || [component isEqualToString:@"live"] || [component isEqualToString:@"embed"] || [component isEqualToString:@"v"])
                {
                    candidate = [components objectAtIndex:index + 1];
                    break;
                }
            }
        }
    }
    return TGIos6YouTubeValidatedVideoId(candidate);
}

@interface TGApplication ()
{
}

@end

@implementation TGApplication

- (id)init
{
    self = [super init];
    if (self != nil)
    {
    }
    return self;
}

- (void)sendEvent:(UIEvent *)event
{
    if (!OGDiagnosticsEnabled() || event.type != UIEventTypeTouches)
    {
        [super sendEvent:event];
        return;
    }
    double arrival = CACurrentMediaTime();
    double offset = arrival - event.timestamp;
    bool moved = false;
    bool transition = false;
    for (UITouch *touch in [event allTouches])
    {
        UITouchPhase phase = touch.phase;
        if (phase == UITouchPhaseMoved)
            moved = true;
        else if (phase != UITouchPhaseStationary)
            transition = true;
    }
    [super sendEvent:event];
    TGApplicationRecordInput(arrival, offset, CACurrentMediaTime() - arrival, moved && !transition);
}

- (NSMutableDictionary *)gameShareDict {
    if (_gameShareDict == nil) {
        _gameShareDict = [[NSMutableDictionary alloc] init];
    }
    return _gameShareDict;
}

- (NSString *)addThemeSlugFromURL:(NSURL *)url
{
    NSString *scheme = [url.scheme lowercaseString];
    NSString *host = [url.host lowercaseString];
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
        return nil;
    if (![host isEqualToString:@"t.me"] && ![host isEqualToString:@"telegram.me"] && ![host isEqualToString:@"telegram.dog"])
        return nil;
    NSMutableArray *components = [[NSMutableArray alloc] init];
    for (NSString *component in [url.path componentsSeparatedByString:@"/"])
    {
        if (component.length != 0)
            [components addObject:component];
    }
    if (components.count < 2 || ![[components[0] lowercaseString] isEqualToString:@"addtheme"])
        return nil;
    NSString *slug = components[1];
    NSCharacterSet *invalidCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet];
    return [slug rangeOfCharacterFromSet:invalidCharacters].location == NSNotFound ? slug : nil;
}

- (NSString *)telegramMeLinkFromText:(NSString *)text startPrivatePayload:(__autoreleasing NSString **)startPrivatePayload startGroupPayload:(__autoreleasing NSString **)startGroupPayload gamePayload:(__autoreleasing NSString **)gamePayload groupedSingle:(bool *)groupedSingle
{
    NSString *pattern = @"https?:\\/\\/(telegram\\.me|t\\.me|telegram\\.dog)\\/([a-zA-Z0-9_\\/]+)(\\?.*)?$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
    if (match != nil)
    {
        NSString *arguments = ([match numberOfRanges] >= 3 && [match rangeAtIndex:3].location != NSNotFound) ? [[text substringWithRange:[match rangeAtIndex:3]] substringFromIndex:1] : nil;
        if (arguments.length != 0)
        {
            if ([arguments isEqualToString:@"single"])
            {
                if (groupedSingle)
                   *groupedSingle = true;
            }
            else
            {
                NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:arguments];
                if (dict.count == 1 && (dict[@"start"] != nil || dict[@"startgroup"] || dict[@"game"]))
                {
                    if (startPrivatePayload)
                       *startPrivatePayload = dict[@"start"];
                    if (startGroupPayload)
                       *startGroupPayload = dict[@"startgroup"];
                    if (gamePayload)
                       *gamePayload = dict[@"game"];
                }
                else
                    return nil;
            }
        }
        return [text substringWithRange:[match rangeAtIndex:2]];
    }
    
    {
        NSString *pattern = @"https?:\\/\\/t\\.me\\/([a-zA-Z0-9_\\/]+)(\\?.*)?$";
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
        NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
        if (match != nil)
        {
            NSString *arguments = ([match numberOfRanges] >= 2 && [match rangeAtIndex:2].location != NSNotFound) ? [[text substringWithRange:[match rangeAtIndex:2]] substringFromIndex:1] : nil;
            if (arguments.length != 0)
            {
                NSDictionary *dict = [TGStringUtils argumentDictionaryInUrlString:arguments];
                if (dict.count == 1 && (dict[@"start"] != nil || dict[@"startgroup"] || dict[@"game"]))
                {
                    if (startPrivatePayload)
                       *startPrivatePayload = dict[@"start"];
                    if (startGroupPayload)
                       *startGroupPayload = dict[@"startgroup"];
                    if (gamePayload)
                       *gamePayload = dict[@"game"];
                }
                else
                    return nil;
            }
            return [text substringWithRange:[match rangeAtIndex:1]];
        }
    }
    return nil;
}

- (NSString *)shareLinkFromText:(NSString *)text {
    NSString *pattern = @"https?:\\/\\/telegram\\.me\\/share\\/url\\?(.*)$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
    if (match != nil) {
        NSString *arguments = ([match numberOfRanges] >= 1 && [match rangeAtIndex:1].location != NSNotFound) ? [text substringWithRange:[match rangeAtIndex:1]] : nil;
        if (arguments.length != 0)
        {
            return arguments;
        }
        return [text substringWithRange:[match rangeAtIndex:1]];
    }
    
    {
        NSString *pattern = @"https?:\\/\\/t\\.me\\/share\\/url\\?(.*)$";
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
        NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
        if (match != nil) {
            NSString *arguments = ([match numberOfRanges] >= 1 && [match rangeAtIndex:1].location != NSNotFound) ? [text substringWithRange:[match rangeAtIndex:1]] : nil;
            if (arguments.length != 0)
            {
                return arguments;
            }
            return [text substringWithRange:[match rangeAtIndex:1]];
        }
    }
    
    return nil;
}

- (NSString *)proxyLinkFromText:(NSString *)text {
    NSString *pattern = @"(https|http)?:\\/\\/(telegram|t)\\.me\\/proxy\\?(.*)$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
    if (match != nil) {
        NSString *arguments = ([match numberOfRanges] >= 3 && [match rangeAtIndex:3].location != NSNotFound) ? [text substringWithRange:[match rangeAtIndex:3]] : nil;
        if (arguments.length != 0) {
            return arguments;
        }
    }
    
    return nil;
}

- (NSString *)socksLinkFromText:(NSString *)text {
    NSString *pattern = @"(https|http)?:\\/\\/(telegram|t)\\.me\\/socks\\?(.*)$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, [text length])];
    if (match != nil) {
        NSString *arguments = ([match numberOfRanges] >= 3 && [match rangeAtIndex:3].location != NSNotFound) ? [text substringWithRange:[match rangeAtIndex:3]] : nil;
        if (arguments.length != 0) {
            return arguments;
        }
    }
    
    return nil;
}

- (BOOL)openURL:(NSURL *)url forceNative:(BOOL)forceNative {
    return [self openURL:url forceNative:forceNative keepStack:false];
}

- (BOOL)openURL:(NSURL *)url forceNative:(BOOL)__unused forceNative keepStack:(bool)keepStack
{
#if OG_PLUGINS_AVAILABLE
    __block BOOL result = true;
    [TGPluginHost resolveLink:url completion:^(NSURL *resolved)
    {
        if (resolved == nil)
            return;
        result = [self routeURL:resolved keepStack:keepStack];
        [TGPluginHost completeLink:resolved];
    }];
    return result;
#else
    return [self routeURL:url keepStack:keepStack];
#endif
}

- (BOOL)routeURL:(NSURL *)url keepStack:(bool)keepStack
{
    if (url.absoluteString.length == 0)
        return true;
    
    if (url.scheme.length == 0) {
        url = [NSURL URLWithString:[@"http://" stringByAppendingString:[url absoluteString]]];
    }

    NSString *lowercaseScheme = [url.scheme lowercaseString];
    if ([lowercaseScheme isEqualToString:@"http"] || [lowercaseScheme isEqualToString:@"https"])
    {
        NSString *youtubeVideoId = TGIos6YouTubeVideoIdFromURL(url, 0);
        if (youtubeVideoId.length != 0)
        {
            NSArray *applicationSchemes = @[@"youtube", @"vnd.youtube"];
            for (NSString *applicationScheme in applicationSchemes)
            {
                NSURL *applicationUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@://watch?v=%@", applicationScheme, youtubeVideoId]];
                if ([super canOpenURL:applicationUrl])
                    return [super openURL:applicationUrl];
            }
        }
    }
    
    NSString *rawAbsoluteString = url.absoluteString;
    NSString *absolutePrefixString = [url.absoluteString lowercaseString];
    if ([absolutePrefixString hasPrefix:@"tel:"] || [absolutePrefixString hasPrefix:@"facetime:"])
    {
        [TGAppDelegateInstance performPhoneCall:url];
        return true;
    }
    
    if ([url.scheme isEqualToString:@"tg"] || [url.scheme isEqualToString:@"telegram"])
    {
        [(TGAppDelegate *)self.delegate handleOpenDocument:url animated:true];
        return true;
    }
    
    NSString *themeSlug = [self addThemeSlugFromURL:url];
    if (themeSlug.length != 0)
    {
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://addtheme?slug=%@", themeSlug];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"http://telegram.me/addstickers/"])
    {
        NSString *stickerPackHash = [rawAbsoluteString substringFromIndex:@"http://telegram.me/addstickers/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://addstickers?set=%@", stickerPackHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"http://t.me/addstickers/"])
    {
        NSString *stickerPackHash = [rawAbsoluteString substringFromIndex:@"http://t.me/addstickers/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://addstickers?set=%@", stickerPackHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"https://telegram.me/addstickers/"])
    {
        NSString *stickerPackHash = [rawAbsoluteString substringFromIndex:@"https://telegram.me/addstickers/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://addstickers?set=%@", stickerPackHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"https://t.me/addstickers/"])
    {
        NSString *stickerPackHash = [rawAbsoluteString substringFromIndex:@"https://t.me/addstickers/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://addstickers?set=%@", stickerPackHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"https://telegram.me/addstickers/"])
    {
        NSString *stickerPackHash = [rawAbsoluteString substringFromIndex:@"https://telegram.me/addstickers/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://addstickers?set=%@", stickerPackHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    
    if ([absolutePrefixString hasPrefix:@"http://t.me/joinchat/"])
    {
        NSString *groupHash = [rawAbsoluteString substringFromIndex:@"http://t.me/joinchat/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://join?invite=%@", groupHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true keepStack:keepStack];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"https://telegram.me/joinchat/"])
    {
        NSString *groupHash = [rawAbsoluteString substringFromIndex:@"https://telegram.me/joinchat/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://join?invite=%@", groupHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true keepStack:keepStack];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"https://t.me/joinchat/"])
    {
        NSString *groupHash = [rawAbsoluteString substringFromIndex:@"https://t.me/joinchat/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://join?invite=%@", groupHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true keepStack:keepStack];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"t.me/joinchat/"])
    {
        NSString *groupHash = [rawAbsoluteString substringFromIndex:@"t.me/joinchat/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://join?invite=%@", groupHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true keepStack:keepStack];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"telegram.me/joinchat/"])
    {
        NSString *groupHash = [rawAbsoluteString substringFromIndex:@"telegram.me/joinchat/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://join?invite=%@", groupHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true keepStack:keepStack];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"http://telegram.me/joinchat/"])
    {
        NSString *groupHash = [rawAbsoluteString substringFromIndex:@"http://telegram.me/joinchat/".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://join?invite=%@", groupHash];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true keepStack:keepStack];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"https://telegram.me/confirmphone?"])
    {
        NSString *arguments = [rawAbsoluteString substringFromIndex:@"https://telegram.me/confirmphone?".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://confirmphone?%@", arguments];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    if ([absolutePrefixString hasPrefix:@"https://t.me/confirmphone?"])
    {
        NSString *arguments = [rawAbsoluteString substringFromIndex:@"https://t.me/confirmphone?".length];
        NSString *internalUrl = [[NSString alloc] initWithFormat:@"tg://confirmphone?%@", arguments];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    NSString *startPrivatePayload = nil;
    NSString *startGroupPayload = nil;
    NSString *gamePayload = nil;
    bool groupedSingle = false;
    NSString *telegramMeLink = [self telegramMeLinkFromText:rawAbsoluteString startPrivatePayload:&startPrivatePayload startGroupPayload:&startGroupPayload gamePayload:&gamePayload groupedSingle:&groupedSingle];
    if (telegramMeLink.length != 0 && ![telegramMeLink isEqualToString:@"iv"])
    {
        NSString *domainName = telegramMeLink;
        NSString *postId = nil;
        NSRange slashRange = [telegramMeLink rangeOfString:@"/"];
        if (slashRange.location != NSNotFound) {
            domainName = [telegramMeLink substringToIndex:slashRange.location];
            postId = [telegramMeLink substringFromIndex:slashRange.location + 1];
        }
        NSMutableString *internalUrl = nil;
        if (postId.length == 0) {
            internalUrl = [[NSMutableString alloc] initWithFormat:@"tg://resolve?domain=%@", domainName];
        } else {
            internalUrl = [[NSMutableString alloc] initWithFormat:@"tg://resolve?domain=%@&post=%@", domainName, postId];
        }
        
        if (groupedSingle)
             [internalUrl appendString:@"&single"];
        
        if (startPrivatePayload.length != 0 || startGroupPayload.length != 0 || gamePayload != nil)
        {
            if (startPrivatePayload.length != 0)
                [internalUrl appendFormat:@"&start=%@", startPrivatePayload];
            if (startGroupPayload.length != 0)
                [internalUrl appendFormat:@"&startgroup=%@", startGroupPayload];
            if (gamePayload.length != 0)
                [internalUrl appendFormat:@"&game=%@", gamePayload];
        }
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true keepStack:keepStack];
        return true;
    }
    
    NSString *shareLinkFromText = [self shareLinkFromText:rawAbsoluteString];
    if (shareLinkFromText.length != 0) {
        NSMutableString *internalUrl = [[NSMutableString alloc] initWithFormat:@"tg://msg_url?%@", shareLinkFromText];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    NSString *socksLink = [self socksLinkFromText:rawAbsoluteString];
    if (socksLink.length != 0) {
        NSMutableString *internalUrl = [[NSMutableString alloc] initWithFormat:@"tg://socks?%@", socksLink];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    NSString *proxyLink = [self proxyLinkFromText:rawAbsoluteString];
    if (proxyLink.length != 0) {
        NSMutableString *internalUrl = [[NSMutableString alloc] initWithFormat:@"tg://proxy?%@", proxyLink];
        [(TGAppDelegate *)self.delegate handleOpenDocument:[NSURL URLWithString:internalUrl] animated:true];
        return true;
    }
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone && iosMajorVersion() >= 9 && ([url.scheme isEqual:@"http"] || [url.scheme isEqual:@"https"])) {
        
        UIViewController *parentController = TGAppDelegateInstance.window.rootViewController;
        if ([parentController.presentedViewController isKindOfClass:[TGHashtagOverviewController class]])
        {
            parentController = parentController.presentedViewController;
        }
        
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:false];
                [parentController presentViewController:controller animated:true completion:nil];
            });
        } else {
            SFSafariViewController *controller = [[SFSafariViewController alloc] initWithURL:url entersReaderIfAvailable:false];
            [parentController presentViewController:controller animated:true completion:nil];
        }
        return true;
    }
    
    return [super openURL:url];
}

- (BOOL)openURL:(NSURL *)url
{
    return [self openURL:url forceNative:false];
}

- (BOOL)nativeOpenURL:(NSURL *)url
{
    return [super openURL:url];
}

- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle
{
    [self setStatusBarStyle:statusBarStyle animated:false];
}

- (void)setStatusBarStyle:(UIStatusBarStyle)__unused statusBarStyle animated:(BOOL)__unused animated
{
}

- (void)setStatusBarHidden:(BOOL)statusBarHidden
{
    [self setStatusBarHidden:statusBarHidden withAnimation:UIStatusBarAnimationNone];
}

- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation
{
    if (_processStatusBarHiddenRequests)
    {
        
        [self forceSetStatusBarHidden:hidden withAnimation:animation];
    }
}

- (void)forceSetStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated
{
    [super setStatusBarStyle:statusBarStyle animated:animated];
}

- (void)forceSetStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 32000
    [super setStatusBarHidden:hidden withAnimation:animation];
#else
    [super setStatusBarHidden:hidden animated:animation != UIStatusBarAnimationNone];
#endif
}

@end
