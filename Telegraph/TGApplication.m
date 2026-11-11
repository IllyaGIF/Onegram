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

static Class OGCompatResolveSystemClass(NSString *name, Class stubClass)
{
    Class resolved = NSClassFromString(name);
    if (resolved == Nil)
    {
        NSString *frameworkPath = nil;
        if ([name hasPrefix:@"PH"])
            frameworkPath = @"/System/Library/Frameworks/Photos.framework/Photos";
        else if ([name hasPrefix:@"CN"])
            frameworkPath = @"/System/Library/Frameworks/Contacts.framework/Contacts";
        else if ([name isEqualToString:@"WCSession"])
            frameworkPath = @"/System/Library/Frameworks/WatchConnectivity.framework/WatchConnectivity";
        if (frameworkPath != nil)
            dlopen([frameworkPath fileSystemRepresentation], RTLD_LAZY | RTLD_LOCAL);

        resolved = NSClassFromString(name);
    }
    return (resolved == Nil || resolved == stubClass) ? Nil : resolved;
}

static IMP OGCompatSystemFactory(NSString *name, Class stubClass, SEL selector, Class *systemClassOut)
{
    Class resolved = OGCompatResolveSystemClass(name, stubClass);
    if (resolved == Nil || ![resolved respondsToSelector:selector])
        return NULL;
    *systemClassOut = resolved;
    return [resolved methodForSelector:selector];
}

#define OG_COMPAT_SYSTEM_CLASS_FORWARDING(systemName) \
+ (id)allocWithZone:(NSZone *)zone \
{ \
    Class resolved = OGCompatResolveSystemClass(@systemName, self); \
    return resolved != Nil ? [resolved allocWithZone:zone] : [super allocWithZone:zone]; \
} \
+ (id)forwardingTargetForSelector:(SEL)selector \
{ \
    Class resolved = OGCompatResolveSystemClass(@systemName, self); \
    return (resolved != Nil && [resolved respondsToSelector:selector]) ? resolved : nil; \
}

#define OG_COMPAT_FORWARDED_STUB(ClassName) \
@implementation ClassName \
OG_COMPAT_SYSTEM_CLASS_FORWARDING(#ClassName) \
@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
OG_COMPAT_FORWARDED_STUB(PHAsset)
OG_COMPAT_FORWARDED_STUB(PHAssetChangeRequest)
OG_COMPAT_FORWARDED_STUB(PHAssetCollection)
OG_COMPAT_FORWARDED_STUB(PHCachingImageManager)
OG_COMPAT_FORWARDED_STUB(PHFetchOptions)
OG_COMPAT_FORWARDED_STUB(PHImageManager)
OG_COMPAT_FORWARDED_STUB(PHImageRequestOptions)
OG_COMPAT_FORWARDED_STUB(PHObject)
OG_COMPAT_FORWARDED_STUB(PHPhotoLibrary)
OG_COMPAT_FORWARDED_STUB(PHVideoRequestOptions)
OG_COMPAT_FORWARDED_STUB(UIAlertController)
OG_COMPAT_FORWARDED_STUB(UIDocumentPickerViewController)
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
OG_COMPAT_FORWARDED_STUB(CNContactFormatter)
OG_COMPAT_FORWARDED_STUB(CNContactVCardSerialization)
OG_COMPAT_FORWARDED_STUB(CNLabeledValue)
OG_COMPAT_FORWARDED_STUB(CNMutableContact)
OG_COMPAT_FORWARDED_STUB(CNPhoneNumber)
OG_COMPAT_FORWARDED_STUB(PHAssetResource)
OG_COMPAT_FORWARDED_STUB(PHAssetResourceManager)
OG_COMPAT_FORWARDED_STUB(PHLivePhotoRequestOptions)
OG_COMPAT_FORWARDED_STUB(WCSession)
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation NSURLSessionConfiguration
OG_COMPAT_SYSTEM_CLASS_FORWARDING("NSURLSessionConfiguration")
+ (instancetype)defaultSessionConfiguration
{
    Class systemClass = Nil;
    IMP factory = OGCompatSystemFactory(@"NSURLSessionConfiguration", self, @selector(defaultSessionConfiguration), &systemClass);
    if (factory != NULL)
        return ((id (*)(id, SEL))factory)(systemClass, @selector(defaultSessionConfiguration));
    return [[self alloc] init];
}
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
@implementation NSURLSession
OG_COMPAT_SYSTEM_CLASS_FORWARDING("NSURLSession")
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration
{
    Class systemClass = Nil;
    IMP factory = OGCompatSystemFactory(@"NSURLSession", self, @selector(sessionWithConfiguration:), &systemClass);
    if (factory != NULL)
        return ((id (*)(id, SEL, id))factory)(systemClass, @selector(sessionWithConfiguration:), configuration);
    return [[self alloc] init];
}
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue
{
    Class systemClass = Nil;
    IMP factory = OGCompatSystemFactory(@"NSURLSession", self, @selector(sessionWithConfiguration:delegate:delegateQueue:), &systemClass);
    if (factory != NULL)
        return ((id (*)(id, SEL, id, id, id))factory)(systemClass, @selector(sessionWithConfiguration:delegate:delegateQueue:), configuration, delegate, queue);
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

OG_COMPAT_FORWARDED_STUB(NSURLSessionDataTask)

@implementation NSURLSessionTask
OG_COMPAT_SYSTEM_CLASS_FORWARDING("NSURLSessionTask")
- (void)cancel {}
- (void)resume {}
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000
@implementation UIImpactFeedbackGenerator
OG_COMPAT_SYSTEM_CLASS_FORWARDING("UIImpactFeedbackGenerator")
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
OG_COMPAT_SYSTEM_CLASS_FORWARDING("UIKeyCommand")
+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(NSUInteger)modifierFlags action:(SEL)action
{
    Class systemClass = Nil;
    IMP factory = iosMajorVersion() >= 7 ? OGCompatSystemFactory(@"UIKeyCommand", self, @selector(keyCommandWithInput:modifierFlags:action:), &systemClass) : NULL;
    if (factory != NULL)
        return ((id (*)(id, SEL, NSString *, NSUInteger, SEL))factory)(systemClass, @selector(keyCommandWithInput:modifierFlags:action:), input, modifierFlags, action);

    return [[self alloc] init];
}
@end
#endif

static NSCharacterSet *OGCompatIdentifierInvalidCharacters(void)
{
    static NSCharacterSet *invalid = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        invalid = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet];
    });
    return invalid;
}

static NSString *OGCompatUnescapedRepeatedly(NSString *text)
{
    NSString *current = text;
    for (NSUInteger pass = 0; pass < 3 && current.length != 0; pass++)
    {
        NSString *next = [current stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (next.length == 0 || [next isEqualToString:current])
            break;
        current = next;
    }
    return current;
}

static NSString *OGCompatQueryParameter(NSURL *url, NSArray *acceptedNames)
{
    if (url.query.length == 0)
        return nil;

    for (NSString *pair in [url.query componentsSeparatedByString:@"&"])
    {
        NSRange equals = [pair rangeOfString:@"="];
        bool hasValue = equals.location != NSNotFound;
        NSString *name = [[OGCompatUnescapedRepeatedly(hasValue ? [pair substringToIndex:equals.location] : pair) lowercaseString] stringByReplacingOccurrencesOfString:@"+" withString:@" "];
        if (![acceptedNames containsObject:name])
            continue;

        NSString *value = hasValue ? [pair substringFromIndex:NSMaxRange(equals)] : @"";
        return OGCompatUnescapedRepeatedly([value stringByReplacingOccurrencesOfString:@"+" withString:@" "]);
    }
    return nil;
}

static BOOL OGCompatHostBelongsToDomain(NSString *host, NSString *domain)
{
    return [host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]];
}

static NSString *OGCompatYouTubeIdentifier(NSString *rawCandidate)
{
    NSString *candidate = OGCompatUnescapedRepeatedly(rawCandidate);
    if (candidate.length < 1)
        return nil;

    NSRange firstInvalid = [candidate rangeOfCharacterFromSet:OGCompatIdentifierInvalidCharacters()];
    if (firstInvalid.location == 0)
        return nil;
    if (firstInvalid.location != NSNotFound)
        candidate = [candidate substringToIndex:firstInvalid.location];

    return candidate.length != 11 ? nil : candidate;
}

static NSString *OGCompatYouTubeVideoId(NSURL *url, NSUInteger depth)
{
    NSString *host = [url.host lowercaseString];
    if (url == nil || depth > 3 || host.length == 0)
        return nil;

    BOOL shortHost = OGCompatHostBelongsToDomain(host, @"youtu.be");
    BOOL youtubeHost = OGCompatHostBelongsToDomain(host, @"youtube.com") || OGCompatHostBelongsToDomain(host, @"youtube-nocookie.com");
    if (!(shortHost || youtubeHost))
        return nil;

    NSArray *pathParts = [url.path componentsSeparatedByString:@"/"];
    NSString *rawIdentifier = nil;

    if (youtubeHost && [@[@"/redirect", @"/attribution_link"] containsObject:[url.path lowercaseString]])
    {
        NSString *wrapped = OGCompatQueryParameter(url, @[@"u", @"url", @"q"]);
        if (wrapped.length != 0)
        {
            if ([wrapped hasPrefix:@"//"])
                wrapped = [@"https:" stringByAppendingString:wrapped];
            else if ([wrapped hasPrefix:@"/"])
                wrapped = [@"https://www.youtube.com" stringByAppendingString:wrapped];
            else if ([wrapped rangeOfString:@"://"].location == NSNotFound)
                wrapped = [@"https://" stringByAppendingString:wrapped];

            NSString *innerId = OGCompatYouTubeVideoId([NSURL URLWithString:wrapped], depth + 1);
            if (innerId.length != 0)
                return innerId;
        }
    }

    if (shortHost)
    {
        NSUInteger partIndex = 0;
        while (partIndex < pathParts.count && [pathParts[partIndex] length] == 0)
            partIndex++;
        if (partIndex < pathParts.count)
            rawIdentifier = pathParts[partIndex];
    }
    else
    {
        rawIdentifier = OGCompatQueryParameter(url, @[@"v"]);
        if (rawIdentifier.length < 1)
        {
            NSArray *markers = @[@"shorts", @"live", @"embed", @"v"];
            for (NSUInteger index = 0; index + 1 < pathParts.count; index++)
            {
                if ([markers containsObject:[[pathParts objectAtIndex:index] lowercaseString]])
                {
                    rawIdentifier = [pathParts objectAtIndex:index + 1];
                    break;
                }
            }
        }
    }
    return OGCompatYouTubeIdentifier(rawIdentifier);
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
    void (^touchTracker)(UITouch *) = _touchTracker;
    if (touchTracker != nil && event.type == UIEventTypeTouches)
    {
        UITouch *touch = [[event allTouches] anyObject];
        if (touch != nil)
            touchTracker(touch);
    }
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
    NSPredicate *nonEmpty = [NSPredicate predicateWithFormat:@"length > 0"];
    NSArray *components = [[url.path componentsSeparatedByString:@"/"] filteredArrayUsingPredicate:nonEmpty];
    if (components.count < 2 || ![[components[0] lowercaseString] isEqualToString:@"addtheme"])
        return nil;
    NSString *slug = components[1];
    return [slug rangeOfCharacterFromSet:OGCompatIdentifierInvalidCharacters()].location == NSNotFound ? slug : nil;
}

- (NSString *)telegramMeLinkFromText:(NSString *)text startPrivatePayload:(__autoreleasing NSString **)startPrivatePayload startGroupPayload:(__autoreleasing NSString **)startGroupPayload gamePayload:(__autoreleasing NSString **)gamePayload freeToken:(__autoreleasing NSString **)freeToken groupedSingle:(bool *)groupedSingle
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
                NSMutableDictionary *dict = [[TGStringUtils argumentDictionaryInUrlString:arguments] mutableCopy];
                if ([dict[@"free"] isKindOfClass:[NSString class]])
                {
                    if (freeToken)
                        *freeToken = dict[@"free"];
                    [dict removeObjectForKey:@"free"];
                }
                if (dict.count == 1 && (dict[@"start"] != nil || dict[@"startgroup"] || dict[@"game"]))
                {
                    if (startPrivatePayload)
                       *startPrivatePayload = dict[@"start"];
                    if (startGroupPayload)
                       *startGroupPayload = dict[@"startgroup"];
                    if (gamePayload)
                       *gamePayload = dict[@"game"];
                }
                else if (dict.count != 0)
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
                NSMutableDictionary *dict = [[TGStringUtils argumentDictionaryInUrlString:arguments] mutableCopy];
                if ([dict[@"free"] isKindOfClass:[NSString class]])
                {
                    if (freeToken)
                        *freeToken = dict[@"free"];
                    [dict removeObjectForKey:@"free"];
                }
                if (dict.count == 1 && (dict[@"start"] != nil || dict[@"startgroup"] || dict[@"game"]))
                {
                    if (startPrivatePayload)
                       *startPrivatePayload = dict[@"start"];
                    if (startGroupPayload)
                       *startGroupPayload = dict[@"startgroup"];
                    if (gamePayload)
                       *gamePayload = dict[@"game"];
                }
                else if (dict.count != 0)
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

    NSString *normalizedScheme = [url.scheme lowercaseString];
    if ([@[@"http", @"https"] containsObject:normalizedScheme])
    {
        NSString *videoId = OGCompatYouTubeVideoId(url, 0);
        if (videoId.length != 0)
        {
            for (NSString *appScheme in @[@"youtube", @"vnd.youtube"])
            {
                NSURL *appURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://watch?v=%@", appScheme, videoId]];
                if ([super canOpenURL:appURL])
                    return [super openURL:appURL];
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
    NSString *freeToken = nil;
    bool groupedSingle = false;
    NSString *telegramMeLink = [self telegramMeLinkFromText:rawAbsoluteString startPrivatePayload:&startPrivatePayload startGroupPayload:&startGroupPayload gamePayload:&gamePayload freeToken:&freeToken groupedSingle:&groupedSingle];
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
        if (freeToken.length != 0)
            [internalUrl appendFormat:@"&free=%@", [TGStringUtils stringByEscapingForURL:freeToken]];
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
