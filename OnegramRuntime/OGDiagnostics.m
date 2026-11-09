#import "OGDiagnostics.h"
#import "OGDiagnosticsLogging.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <notify.h>

#import "../OnegramHelper/OGHelperProtocol.h"

bool OGDiagnosticsActive = false;

NSString *const OGDiagnosticsFirstDialogFrameNotification = @"OGDiagnosticsFirstDialogFrameNotification";

static NSMutableDictionary *OGDiagnosticsTimingStarts = nil;
static NSMutableSet *OGDiagnosticsTimingRecorded = nil;
static NSMutableSet *OGDiagnosticsTimingPendingFrames = nil;
static bool OGDiagnosticsFirstDialogFrameScheduled = false;

@interface OGDiagnosticsFrameProbe : NSObject

@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, copy) NSString *scenario;
@property (nonatomic) bool firstDialogFrame;
@property (nonatomic) bool once;
@property (nonatomic) NSUInteger ticks;

- (void)tick:(CADisplayLink *)link;

@end

@interface OGDiagnosticsForegroundProbe : NSObject

@end

static bool OGDiagnosticsForegroundPending = false;

@implementation OGDiagnosticsForegroundProbe

+ (void)load
{
    if ([NSBundle bundleForClass:self] != [NSBundle mainBundle])
        return;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [center addObserver:self selector:@selector(didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

+ (void)willEnterForeground:(NSNotification *)__unused notification
{
    OGDiagnosticsForegroundPending = true;
    OGDiagnosticsTimingBegin("foreground_first_frame");
}

+ (void)didBecomeActive:(NSNotification *)__unused notification
{
    if (!OGDiagnosticsForegroundPending)
        return;
    OGDiagnosticsForegroundPending = false;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (window != nil && window.rootViewController != nil)
        OGDiagnosticsTimingAfterFrame("foreground_first_frame", window.rootViewController.view, false, false);
}

@end

void OGDiagnosticsTimingBegin(const char *scenario)
{
    if (!OGDiagnosticsEnabled() || scenario == NULL)
        return;
    @synchronized ([OGDiagnosticsFrameProbe class])
    {
        if (OGDiagnosticsTimingStarts == nil)
            OGDiagnosticsTimingStarts = [[NSMutableDictionary alloc] init];
        OGDiagnosticsTimingStarts[[NSString stringWithUTF8String:scenario]] = @(CFAbsoluteTimeGetCurrent());
    }
}

void OGDiagnosticsTimingBeginOnce(const char *scenario)
{
    if (!OGDiagnosticsEnabled() || scenario == NULL)
        return;
    @synchronized ([OGDiagnosticsFrameProbe class])
    {
        NSString *key = [NSString stringWithUTF8String:scenario];
        if ([OGDiagnosticsTimingRecorded containsObject:key] || OGDiagnosticsTimingStarts[key] != nil)
            return;
        if (OGDiagnosticsTimingStarts == nil)
            OGDiagnosticsTimingStarts = [[NSMutableDictionary alloc] init];
        OGDiagnosticsTimingStarts[key] = @(CFAbsoluteTimeGetCurrent());
    }
}

void OGDiagnosticsTimingEnd(const char *scenario)
{
    if (!OGDiagnosticsEnabled() || scenario == NULL)
        return;
    double milliseconds = -1.0;
    @synchronized ([OGDiagnosticsFrameProbe class])
    {
        NSString *key = [NSString stringWithUTF8String:scenario];
        NSNumber *start = OGDiagnosticsTimingStarts[key];
        if (start != nil)
        {
            milliseconds = (CFAbsoluteTimeGetCurrent() - [start doubleValue]) * 1000.0;
            [OGDiagnosticsTimingStarts removeObjectForKey:key];
            if (OGDiagnosticsTimingRecorded == nil)
                OGDiagnosticsTimingRecorded = [[NSMutableSet alloc] init];
            [OGDiagnosticsTimingRecorded addObject:key];
        }
    }
    if (milliseconds >= 0.0)
        NSLog(@"TIMING %s %.1f", scenario, milliseconds);
}

void OGDiagnosticsTimingRecordOnce(const char *scenario, double milliseconds)
{
    if (!OGDiagnosticsEnabled() || scenario == NULL || milliseconds < 0.0)
        return;
    bool record = false;
    @synchronized ([OGDiagnosticsFrameProbe class])
    {
        NSString *key = [NSString stringWithUTF8String:scenario];
        if (![OGDiagnosticsTimingRecorded containsObject:key])
        {
            if (OGDiagnosticsTimingRecorded == nil)
                OGDiagnosticsTimingRecorded = [[NSMutableSet alloc] init];
            [OGDiagnosticsTimingRecorded addObject:key];
            record = true;
        }
    }
    if (record)
        NSLog(@"TIMING %s %.1f", scenario, milliseconds);
}

void OGDiagnosticsTimingAfterFrame(const char *scenario, UIView *view, bool firstDialogFrame, bool once)
{
    if (![NSThread isMainThread] || view == nil || (!firstDialogFrame && !OGDiagnosticsEnabled()))
        return;
    NSString *key = scenario != NULL ? [NSString stringWithUTF8String:scenario] : nil;
    if (once)
    {
        @synchronized ([OGDiagnosticsFrameProbe class])
        {
            if (key == nil || OGDiagnosticsTimingStarts[key] == nil ||
                [OGDiagnosticsTimingRecorded containsObject:key] || [OGDiagnosticsTimingPendingFrames containsObject:key])
                return;
            if (OGDiagnosticsTimingPendingFrames == nil)
                OGDiagnosticsTimingPendingFrames = [[NSMutableSet alloc] init];
            [OGDiagnosticsTimingPendingFrames addObject:key];
        }
    }
    if (firstDialogFrame)
    {
        @synchronized ([OGDiagnosticsFrameProbe class])
        {
            if (OGDiagnosticsFirstDialogFrameScheduled)
                return;
            OGDiagnosticsFirstDialogFrameScheduled = true;
        }
    }
    OGDiagnosticsFrameProbe *probe = [[OGDiagnosticsFrameProbe alloc] init];
    probe.view = view;
    probe.scenario = key;
    probe.firstDialogFrame = firstDialogFrame;
    probe.once = once;
    probe.displayLink = [CADisplayLink displayLinkWithTarget:probe selector:@selector(tick:)];
    [probe.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

@implementation OGDiagnosticsFrameProbe

- (void)tick:(CADisplayLink *)link
{
    if (++_ticks < 2)
        return;
    OGDiagnosticsFrameProbe *probe = self;
    [link invalidate];
    probe.displayLink = nil;
    if (probe.once)
    {
        @synchronized ([OGDiagnosticsFrameProbe class])
        {
            [OGDiagnosticsTimingPendingFrames removeObject:probe.scenario];
        }
    }
    if (probe.view.window == nil)
    {
        if (probe.firstDialogFrame)
        {
            @synchronized ([OGDiagnosticsFrameProbe class])
            {
                OGDiagnosticsFirstDialogFrameScheduled = false;
            }
        }
        return;
    }
    if (probe.scenario != nil)
        OGDiagnosticsTimingEnd(probe.scenario.UTF8String);
    if (probe.firstDialogFrame)
        [[NSNotificationCenter defaultCenter] postNotificationName:OGDiagnosticsFirstDialogFrameNotification object:nil];
}

@end

static NSString *OGDiagnosticsKey(OGDiagnosticsComponent component)
{
    switch (component)
    {
        case OGDiagnosticsComponentOnegram:
            return @OGHelperDiagnosticsOnegramKey;
        case OGDiagnosticsComponentHelper:
            return @OGHelperDiagnosticsHelperKey;
    }
    return nil;
}

static NSDictionary *OGDiagnosticsReadSettings(void)
{
    NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:@OGHelperDiagnosticsSettingsPath];
    return [settings isKindOfClass:[NSDictionary class]] ? settings : nil;
}

bool OGDiagnosticsOverride(OGDiagnosticsComponent component, bool *value)
{
    @autoreleasepool
    {
        NSString *key = OGDiagnosticsKey(component);
        id stored = key == nil ? nil : [OGDiagnosticsReadSettings() objectForKey:key];
        if (![stored isKindOfClass:[NSNumber class]])
            return false;
        if (value != NULL)
            *value = [stored boolValue];
        return true;
    }
}

bool OGDiagnosticsSetOverride(OGDiagnosticsComponent component, bool value)
{
    @autoreleasepool
    {
        NSString *key = OGDiagnosticsKey(component);
        if (key == nil)
            return false;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager createDirectoryAtPath:@OGHelperSharedDirectoryPath withIntermediateDirectories:true attributes:nil error:NULL])
            return false;
        NSMutableDictionary *settings = [[NSMutableDictionary alloc] initWithDictionary:OGDiagnosticsReadSettings() ?: @{}];
        [settings setObject:[NSNumber numberWithBool:value] forKey:key];
        if (![settings writeToFile:@OGHelperDiagnosticsSettingsPath atomically:true])
            return false;
        notify_post(OGHelperDiagnosticsChangedNotification);
        return true;
    }
}

bool OGDiagnosticsResolve(OGDiagnosticsComponent component, bool buildDefault)
{
    bool value = buildDefault;
    OGDiagnosticsOverride(component, &value);
    return value;
}

void OGDiagnosticsActivate(OGDiagnosticsComponent component, bool buildDefault)
{
    OGDiagnosticsActive = OGDiagnosticsResolve(component, buildDefault);
}
