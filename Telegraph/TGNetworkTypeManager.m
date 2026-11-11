#import "TGNetworkTypeManager.h"
#import <QuartzCore/QuartzCore.h>
#import "TGAppDelegate.h"

#import "Reachability.h"

#import <libkern/OSAtomic.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"

static OSSpinLock TGTransferPolicyLock = OS_SPINLOCK_INIT;
static OGTransferPolicy TGCurrentTransferPolicy;

static void TGEnsureTransferPolicy(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OGTransferPolicyReset(&TGCurrentTransferPolicy, 0, cpuCoreCount() <= 1, CACurrentMediaTime());
    });
}

@interface TGObserverBlockProxy : TGObserverProxy

@property (nonatomic, copy) void (^block)(void);

- (instancetype)initWithName:(NSString *)name block:(void (^)(void))block;

@end


@interface TGNetworkTypeManager ()
{
    id<SDisposable> _disposable;
    SPipe *_pipe;
    OSSpinLock _lock;
    TGNetworkType _type;
}
@end

@implementation TGNetworkTypeManager

+ (OGTransferParameters)transferParametersForUpload:(bool)upload
{
    TGEnsureTransferPolicy();
    OSSpinLockLock(&TGTransferPolicyLock);
    OGTransferParameters parameters = OGTransferPolicyParameters(&TGCurrentTransferPolicy, upload, CACurrentMediaTime());
    OSSpinLockUnlock(&TGTransferPolicyLock);
    return parameters;
}

+ (void)recordTransferBytes:(int64_t)bytes started:(NSTimeInterval)started upload:(bool)upload generation:(uint32_t)generation
{
    TGEnsureTransferPolicy();
    OSSpinLockLock(&TGTransferPolicyLock);
    OGTransferPolicyRecordSuccess(&TGCurrentTransferPolicy, upload, generation, bytes, started, CACurrentMediaTime());
    OSSpinLockUnlock(&TGTransferPolicyLock);
}

+ (void)recordTransferFailureForUpload:(bool)upload generation:(uint32_t)generation
{
    TGEnsureTransferPolicy();
    OSSpinLockLock(&TGTransferPolicyLock);
    OGTransferPolicyRecordFailure(&TGCurrentTransferPolicy, upload, generation, CACurrentMediaTime());
    OSSpinLockUnlock(&TGTransferPolicyLock);
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _type = TGNetworkTypeNone;
        
        _pipe = [[SPipe alloc] init];
        
        __weak TGNetworkTypeManager *weakSelf = self;
        _disposable = [[[TGNetworkTypeManager networkTypeSignal] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
        {
            __strong TGNetworkTypeManager *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            OSSpinLockLock(&_lock);
            TGNetworkType previousType = strongSelf->_type;
            strongSelf->_type = (TGNetworkType)[next integerValue];
            OSSpinLockUnlock(&_lock);
            
            if (previousType != strongSelf->_type)
            {
                TGNetworkType type = strongSelf->_type;
                int networkClass = type == TGNetworkTypeWiFi || type == TGNetworkTypeLTE ? 3 : (type == TGNetworkType3G ? 2 : 1);
                TGEnsureTransferPolicy();
                OSSpinLockLock(&TGTransferPolicyLock);
                OGTransferPolicyReset(&TGCurrentTransferPolicy, networkClass, cpuCoreCount() <= 1, CACurrentMediaTime());
                OSSpinLockUnlock(&TGTransferPolicyLock);
                [TGAppDelegateInstance refreshAutomaticMediaDownloads];
            }
            strongSelf->_pipe.sink(next);
        }];
    }
    return self;
}

- (TGNetworkType)networkType
{
    TGNetworkType type = TGNetworkTypeNone;
    OSSpinLockLock(&_lock);
    type = _type;
    OSSpinLockUnlock(&_lock);
    return type;
}

- (SSignal *)networkTypeSignal
{
    return [[SSignal single:@([self networkType])] then:_pipe.signalProducer()];
}

+ (SSignal *)networkTypeSignal
{
    SSignal *reachabilitySignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        Reachability *reachability = [Reachability reachabilityForInternetConnection];
        [reachability startNotifier];
        
        [subscriber putNext:@(reachability.currentReachabilityStatus)];
        reachability.reachabilityChanged = ^(NetworkStatus status)
        {
            [subscriber putNext:@(status)];
        };
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            __strong Reachability *strongReachability = reachability;
            [strongReachability stopNotifier];
        }];
    }];
    
    
    SSignal *cellNetworkSignal = [SSignal complete];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() >= 7)
    {
        cellNetworkSignal = [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            CTTelephonyNetworkInfo *telephonyInfo = [CTTelephonyNetworkInfo new];
            NSString *(^radioTechnology)(void) = ^NSString *
            {
                SEL radioSelector = NSSelectorFromString(@"currentRadioAccessTechnology");
                NSString *current = [telephonyInfo respondsToSelector:radioSelector] ? [telephonyInfo valueForKey:@"currentRadioAccessTechnology"] : nil;
                return current ?: @"";
            };
            [subscriber putNext:radioTechnology()];
            
            TGObserverBlockProxy *observer = [[TGObserverBlockProxy alloc] initWithName:@"CTRadioAccessTechnologyDidChangeNotification" block:^
            {
                [subscriber putNext:radioTechnology()];
            }];
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                [telephonyInfo description];
                [observer description];
            }];
        }] map:^id(NSString *networkType)
        {
            static NSDictionary *generations = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                generations = @{
                    @"CTRadioAccessTechnologyGPRS": @(TGNetworkTypeGPRS),
                    @"CTRadioAccessTechnologyEdge": @(TGNetworkTypeEdge),
                    @"CTRadioAccessTechnologyCDMA1x": @(TGNetworkTypeEdge),
                    @"CTRadioAccessTechnologyLTE": @(TGNetworkTypeLTE),
                    @"CTRadioAccessTechnologyWCDMA": @(TGNetworkType3G),
                    @"CTRadioAccessTechnologyHSDPA": @(TGNetworkType3G),
                    @"CTRadioAccessTechnologyHSUPA": @(TGNetworkType3G),
                    @"CTRadioAccessTechnologyCDMAEVDORev0": @(TGNetworkType3G),
                    @"CTRadioAccessTechnologyCDMAEVDORevA": @(TGNetworkType3G),
                    @"CTRadioAccessTechnologyCDMAEVDORevB": @(TGNetworkType3G),
                    @"CTRadioAccessTechnologyeHRPD": @(TGNetworkType3G)
                };
            });
            NSNumber *known = generations[networkType];
            if (known != nil)
                return known;
            
            return @(TGNetworkTypeUnknown);
        }];
    }
    else
    {
        cellNetworkSignal = [SSignal single:@(TGNetworkTypeEdge)];
    }
#else
    cellNetworkSignal = [SSignal single:@(TGNetworkTypeEdge)];
#endif
    
    return [[SSignal combineSignals:@[reachabilitySignal, cellNetworkSignal]] map:^NSNumber *(NSArray *values)
    {
        NSInteger reachability = [[values objectAtIndex:0] integerValue];
        NSNumber *networkType = values.lastObject;
        
        if (reachability == ReachableViaWWAN)
            return networkType;
        else if (reachability == ReachableViaWiFi)
            return @(TGNetworkTypeWiFi);
        else if (reachability == NotReachable)
            return @(TGNetworkTypeNone);
        
        return @(TGNetworkTypeUnknown);
    }];
}

@end


@implementation TGObserverBlockProxy

- (instancetype)initWithName:(NSString *)name block:(void (^)(void))block
{
    self = [self initWithTarget:self targetSelector:@selector(handleNotification) name:name];
    if (self != nil)
    {
        self.block = block;
    }
    return self;
}

- (void)handleNotification
{
    if (self.block != nil)
        self.block();
}

@end
