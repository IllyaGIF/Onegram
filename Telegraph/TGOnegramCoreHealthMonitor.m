#import "TGOnegramCoreHealthMonitor.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTProtoKit.h"
#import "../submodules/MtProtoKit/MTNetworkUsageManager.h"

#import "TGTelegramNetworking.h"
#import "TL/TLMetaScheme.h"

static const NSTimeInterval TGOnegramCoreHealthTick = 1.0;
static const NSTimeInterval TGOnegramCoreHealthPingInterval = 4.0;
static const NSTimeInterval TGOnegramCoreHealthPingTimeout = 10.0;
static const NSUInteger TGOnegramCoreHealthSampleCount = 3;
static const int TGOnegramCoreHealthUsageKeyCount = 28;

@interface TGOnegramCoreHealthTimerTarget : NSObject

@property (nonatomic, weak) TGOnegramCoreHealthMonitor *monitor;

@end

@interface TGOnegramCoreHealthMonitor ()
{
    NSTimer *_timer;
    MTNetworkUsageManager *_usageManager;
    NSArray *_usageKeys;
    id<MTDisposable> _usageDisposable;
    id<SDisposable> _pingDisposable;
    CFAbsoluteTime _pingStartTime;
    CFAbsoluteTime _lastPingTime;
    NSMutableArray *_samples;
    int64_t _lastIncomingBytes;
    int64_t _lastOutgoingBytes;
    CFAbsoluteTime _lastUsageTime;
    bool _running;
}

- (void)tick;

@end

@implementation TGOnegramCoreHealthTimerTarget

- (void)timerFired:(NSTimer *)__unused timer
{
    [_monitor tick];
}

@end

@implementation TGOnegramCoreHealthMonitor

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _samples = [[NSMutableArray alloc] init];
        _pingMilliseconds = -1;
        NSMutableArray *keys = [[NSMutableArray alloc] init];
        for (int key = 0; key < TGOnegramCoreHealthUsageKeyCount; key++)
            [keys addObject:@(key)];
        _usageKeys = keys;
    }
    return self;
}

- (void)dealloc
{
    [_timer invalidate];
    [_pingDisposable dispose];
    [_usageDisposable dispose];
}

- (void)start
{
    if (_running)
        return;
    _running = true;
    _usageManager = [[MTNetworkUsageManager alloc] initWithInfo:[[TGTelegramNetworking instance] dataUsageInfo]];
    _lastUsageTime = 0.0;
    TGOnegramCoreHealthTimerTarget *target = [[TGOnegramCoreHealthTimerTarget alloc] init];
    target.monitor = self;
    _timer = [NSTimer timerWithTimeInterval:TGOnegramCoreHealthTick target:target selector:@selector(timerFired:) userInfo:nil repeats:true];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    [self restart];
}

- (void)stop
{
    if (!_running)
        return;
    _running = false;
    [_timer invalidate];
    _timer = nil;
    [_pingDisposable dispose];
    _pingDisposable = nil;
    [_usageDisposable dispose];
    _usageDisposable = nil;
    _usageManager = nil;
}

- (void)restart
{
    [_pingDisposable dispose];
    _pingDisposable = nil;
    [_samples removeAllObjects];
    _pingMilliseconds = -1;
    _health = TGOnegramCoreHealthChecking;
    _lastPingTime = 0.0;
    [self notify];
    if (_running)
        [self sendPing];
}

- (void)notify
{
    if (_updated != nil)
        _updated();
}

- (void)tick
{
    if (!_running)
        return;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (_pingDisposable != nil)
    {
        if (now - _pingStartTime > TGOnegramCoreHealthPingTimeout)
        {
            [_pingDisposable dispose];
            _pingDisposable = nil;
            [_samples removeAllObjects];
            _pingMilliseconds = -1;
            _health = TGOnegramCoreHealthNoResponse;
            _lastPingTime = now;
            [self notify];
        }
    }
    else if (now - _lastPingTime >= TGOnegramCoreHealthPingInterval)
    {
        [self sendPing];
    }
    [self sampleUsage];
}

- (void)sendPing
{
    _pingStartTime = CFAbsoluteTimeGetCurrent();
    __weak TGOnegramCoreHealthMonitor *weakSelf = self;
    _pingDisposable = [[[[TGTelegramNetworking instance] requestSignal:[[TLRPChelp_getNearestDc$help_getNearestDc alloc] init]] deliverOn:[SQueue mainQueue]] startWithNext:nil error:^(__unused id error)
    {
        __strong TGOnegramCoreHealthMonitor *strongSelf = weakSelf;
        [strongSelf pingFinished:false];
    } completed:^
    {
        __strong TGOnegramCoreHealthMonitor *strongSelf = weakSelf;
        [strongSelf pingFinished:true];
    }];
}

- (void)pingFinished:(bool)success
{
    if (_pingDisposable == nil)
        return;
    _pingDisposable = nil;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    _lastPingTime = now;
    if (!success)
    {
        [_samples removeAllObjects];
        _pingMilliseconds = -1;
        _health = TGOnegramCoreHealthNoResponse;
        [self notify];
        return;
    }

    [_samples addObject:@((now - _pingStartTime) * 1000.0)];
    while (_samples.count > TGOnegramCoreHealthSampleCount)
        [_samples removeObjectAtIndex:0];
    NSArray *sorted = [_samples sortedArrayUsingSelector:@selector(compare:)];
    double median = [sorted[sorted.count / 2] doubleValue];
    _pingMilliseconds = (NSInteger)(median + 0.5);
    if (median < 250.0)
        _health = TGOnegramCoreHealthGood;
    else if (median < 700.0)
        _health = TGOnegramCoreHealthFair;
    else
        _health = TGOnegramCoreHealthPoor;
    [self notify];
}

- (void)sampleUsage
{
    if (_usageManager == nil || _usageDisposable != nil)
        return;
    __weak TGOnegramCoreHealthMonitor *weakSelf = self;
    _usageDisposable = [[_usageManager currentStatsForKeys:_usageKeys] startWithNext:^(NSDictionary *stats)
    {
        TGDispatchOnMainThread(^
        {
            __strong TGOnegramCoreHealthMonitor *strongSelf = weakSelf;
            [strongSelf usageSampled:stats];
        });
    }];
}

- (void)usageSampled:(NSDictionary *)stats
{
    _usageDisposable = nil;
    if (![stats isKindOfClass:[NSDictionary class]])
        return;
    int64_t incoming = 0;
    int64_t outgoing = 0;
    for (NSNumber *key in stats)
    {
        int64_t value = [stats[key] longLongValue];
        if ([key intValue] % 2 == 0)
            incoming += value;
        else
            outgoing += value;
    }

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (_lastUsageTime > 0.0 && now > _lastUsageTime && incoming >= _lastIncomingBytes && outgoing >= _lastOutgoingBytes)
    {
        double elapsed = now - _lastUsageTime;
        double incomingRate = (double)(incoming - _lastIncomingBytes) / elapsed;
        double outgoingRate = (double)(outgoing - _lastOutgoingBytes) / elapsed;
        _incomingBytesPerSecond = _incomingBytesPerSecond * 0.4 + incomingRate * 0.6;
        _outgoingBytesPerSecond = _outgoingBytesPerSecond * 0.4 + outgoingRate * 0.6;
        [self notify];
    }
    _lastIncomingBytes = incoming;
    _lastOutgoingBytes = outgoing;
    _lastUsageTime = now;
}

@end
