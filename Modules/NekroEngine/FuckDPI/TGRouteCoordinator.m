#import "TGRouteCoordinator.h"
#import "TGNekroCommand.h"
#import "TGWarpProfileStore.h"
#import "TGFuckDPILog.h"
#import "../../../Telegraph/TGProxySignals.h"
#import "../../../Telegraph/TGProxyItem.h"

#import <unistd.h>

NSString *const TGRouteStateChangedNotification = @"TGRouteStateChangedNotification";

static NSString *const kFuckDPIEnabledKey  = @"FuckDPIEnabled_v5";
static NSString *const kFuckDPIRouteKey    = @"FuckDPIWorkingRoute";
static NSString *const kFuckDPINameKey     = @"FuckDPIWorkingProfileName";
static NSString *const kFuckDPISelectedKey = @"FuckDPISelectedProfileIndex_v5";

static const NSTimeInterval kSettlePollInterval = 0.5;
static const NSTimeInterval kSettleTimeout      = 55.0;
static const NSTimeInterval kDataFailureGrace    = 7.0;

static const NSUInteger kEndpointsInFirstPass = 2;

static const NSTimeInterval kSupervisorInterval = 60.0;

static NSArray *TGLiveEndpoints(void)
{
    return [NSArray arrayWithObjects:
            @"188.114.96.1:4500",
            @"188.114.97.3:4500",
            @"188.114.97.1:854",
            @"162.159.193.1:1701",
            @"162.159.195.1:500",
            nil];
}

static NSString *TGTelegramRoutes(void)
{
    return @"91.108.4.0/22,"
            "91.108.8.0/22,"
            "91.108.12.0/22,"
            "91.108.16.0/22,"
            "91.108.20.0/22,"
            "91.108.56.0/22,"
            "91.105.192.0/23,"
            "149.154.160.0/20";
}

static BOOL TGEndpointIsDead(NSString *endpoint)
{
    return [endpoint rangeOfString:@"engage.cloudflareclient.com"].location != NSNotFound
        || [endpoint hasPrefix:@"162.159.192."];
}

static dispatch_queue_t TGRouteQueue(void)
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("org.onegram.fuckdpi.route", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@interface TGRouteCoordinator ()
{
    BOOL _engineRefused;
}
- (void)emit:(TGRouteState)state message:(NSString *)message;
- (BOOL)enableViaDaemon;
- (void)enableInternal;
@end

@implementation TGRouteCoordinator

+ (void)load
{
    FDPILog(@"=== FuckDPI Module Loaded into Process Memory ===");
}

+ (BOOL)isSupported
{
    return [TGNekroCommand isAvailable];
}

+ (BOOL)canBeOffered
{
    TGNekroAvailability availability = [TGNekroCommand availability];
    return availability == TGNekroReady || availability == TGNekroUnsupportedOS;
}

+ (NSString *)unsupportedReason
{
    switch ([TGNekroCommand availability])
    {
        case TGNekroReady:
            return nil;
        case TGNekroNotPrivileged:
            return @"Нет прав root";
        case TGNekroBridgeMissing:
            return @"Root bridge не установлен";
        case TGNekroUnsupportedOS:
            return @"Не поддерживается на этой версии iOS";
        case TGNekroMissing:
        default:
            return @"Помощник не найден";
    }
}

+ (void)forgetRememberedRoute
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kFuckDPIRouteKey];
    [defaults removeObjectForKey:kFuckDPINameKey];
    [defaults synchronize];
}

static dispatch_source_t g_supervisor = nil;
static BOOL g_autoStartPending = NO;

+ (void)startSupervisor
{
    dispatch_async(TGRouteQueue(), ^{
        if (g_supervisor != nil) return;

        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, TGRouteQueue());
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSupervisorInterval * NSEC_PER_SEC)),
                                  (uint64_t)(kSupervisorInterval * NSEC_PER_SEC),
                                  (uint64_t)(5 * NSEC_PER_SEC));
        dispatch_source_set_event_handler(timer, ^{
            if (![[NSUserDefaults standardUserDefaults] boolForKey:kFuckDPIEnabledKey]) return;
            if ([TGNekroCommand run:[NSArray arrayWithObject:@"netcheck"]] == 0) return;

            FDPILog(@"supervisor: route stopped carrying data — reconnecting");
            TGRouteCoordinator *c = [[TGRouteCoordinator alloc] init];
            c.stateChanged = ^(TGRouteState state, NSString *message) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:TGRouteStateChangedNotification
                                      object:nil
                                    userInfo:@{@"state": @(state), @"message": message ?: @""}];
                });
            };
            [c enableViaDaemon];
        });
        dispatch_resume(timer);
        g_supervisor = timer;
    });
}

+ (void)stopSupervisor
{
    dispatch_async(TGRouteQueue(), ^{
        if (g_supervisor == nil) return;
        dispatch_source_cancel(g_supervisor);
        g_supervisor = nil;
    });
}

+ (void)stopForBackground
{
    FDPILog(@"stopForBackground: leaving the tunnel up");
    [self stopSupervisor];
}

+ (void)unpinLegacyUserspaceProxy
{
    NSString *const kMigrationKey = @"FuckDPIUserspaceProxyCleared_v6";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kMigrationKey]) return;

    bool inactive = false;
    TGProxyItem *current = [TGProxySignals currentProxy:&inactive];
    if (current != nil && [current.server isEqualToString:@"127.0.0.1"] && current.port == 10850) {
        FDPILog(@"migration: clearing the 0.0.5 userspace SOCKS5 proxy");
        [TGProxySignals applyProxy:nil inactive:true];
    }

    [defaults setBool:YES forKey:kMigrationKey];
    [defaults synchronize];
}

+ (void)checkAndAutoStart
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self unpinLegacyUserspaceProxy];
    });

    if (![self isSupported]) {
        FDPILog(@"checkAndAutoStart: helper unusable (%@) — FuckDPI unavailable", [self unsupportedReason]);
        return;
    }

    @synchronized (self) {
        if (g_autoStartPending) {
            FDPILog(@"checkAndAutoStart: one already pending — skipping");
            return;
        }
        g_autoStartPending = YES;
    }

    dispatch_async(TGRouteQueue(), ^{
        @synchronized (self) { g_autoStartPending = NO; }

        BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kFuckDPIEnabledKey];
        FDPILog(@"checkAndAutoStart called, FuckDPI enabled status: %s", enabled ? "YES" : "NO");
        if (!enabled) return;

        TGRouteCoordinator *c = [[TGRouteCoordinator alloc] init];

        if ([TGNekroCommand run:[NSArray arrayWithObject:@"netcheck"]] == 0) {
            FDPILog(@"checkAndAutoStart: tunnel still up");
            [c emit:TGRouteStateConnected message:@"FuckDPI активен"];
        } else {
            [c enableInternal];
        }
        [TGRouteCoordinator startSupervisor];
    });
}

- (void)emit:(TGRouteState)state message:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.stateChanged != nil)
            self.stateChanged(state, message);
    });
}

- (NSDictionary *)profileFromConf:(NSString *)text
{
    NSMutableDictionary *profile = [NSMutableDictionary dictionary];
    NSCharacterSet *trim = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (NSString *rawLine in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
    {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:trim];
        if ([line length] == 0 || [line hasPrefix:@"#"] || [line hasPrefix:@";"] || [line hasPrefix:@"["])
            continue;

        NSRange equals = [line rangeOfString:@"="];
        if (equals.location == NSNotFound)
            continue;

        NSString *key = [[[line substringToIndex:equals.location] stringByTrimmingCharactersInSet:trim] lowercaseString];
        NSString *value = [[line substringFromIndex:equals.location + 1] stringByTrimmingCharactersInSet:trim];
        if ([value length] != 0)
            [profile setObject:value forKey:key];
    }
    return profile;
}

- (NSArray *)argumentsForProfile:(NSDictionary *)profile endpoint:(NSString *)endpoint
{
    NSString *host = endpoint;
    NSString *port = @"4500";
    NSRange colon = [endpoint rangeOfString:@":" options:NSBackwardsSearch];
    if (colon.location != NSNotFound)
    {
        host = [endpoint substringToIndex:colon.location];
        port = [endpoint substringFromIndex:colon.location + 1];
    }

    NSString *address = [profile objectForKey:@"address"];
    NSArray *addresses = [address componentsSeparatedByString:@","];
    NSString *ipv4 = @"172.16.0.2";
    NSString *ipv6 = @"";
    for (NSString *rawAddress in addresses)
    {
        NSString *one = [rawAddress stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSRange slash = [one rangeOfString:@"/"];
        if (slash.location != NSNotFound)
            one = [one substringToIndex:slash.location];
        if ([one length] == 0)
            continue;
        if ([one rangeOfString:@":"].location == NSNotFound)
            ipv4 = one;
        else
            ipv6 = one;
    }

    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:
        @"warp-tunnel",
        host,
        port,
        [profile objectForKey:@"privatekey"] ?: @"",
        [profile objectForKey:@"publickey"] ?: @"",
        ipv4,
        ipv6,
        [profile objectForKey:@"dns"] ?: @"1.1.1.1,8.8.8.8",
        [profile objectForKey:@"reserved"] ?: @"AAAA",
        [profile objectForKey:@"mtu"] ?: @"1280",
        [profile objectForKey:@"persistentkeepalive"] ?: @"25",
        nil];

    NSString *psk = [profile objectForKey:@"presharedkey"];
    if ([psk length] != 0)
        [arguments addObject:[NSString stringWithFormat:@"psk=%@", psk]];
    NSString *allowed = [profile objectForKey:@"allowedips"];
    if ([allowed length] != 0)
        [arguments addObject:[NSString stringWithFormat:@"allowedips=%@", allowed]];

    NSArray *awgKeys = [NSArray arrayWithObjects:@"jc", @"jmin", @"jmax", @"s1", @"s2", @"s3", @"s4",
        @"h1", @"h2", @"h3", @"h4", @"i1", @"i2", @"i3", @"i4", @"i5", nil];
    for (NSString *key in awgKeys)
    {
        NSString *value = [profile objectForKey:key];
        if ([value length] != 0)
            [arguments addObject:[NSString stringWithFormat:@"%@=%@", key, value]];
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FuckDPILoggingEnabled_v5"])
        [arguments addObject:@"dbg=1"];

    [arguments addObject:@"split=1"];
    [arguments addObject:[NSString stringWithFormat:@"routes=%@", TGTelegramRoutes()]];
    [arguments addObject:@"probe=149.154.167.51:443"];
    [arguments addObject:@"routeguard=0"];
    [arguments addObject:@"bindwarp=1"];
    [arguments addObject:@"kpatch=1"];
    [arguments addObject:@"surgery=0"];
    return arguments;
}

- (BOOL)waitForDataThroughEndpoint:(NSString *)endpoint
{
    NSDate *startupDeadline = [NSDate dateWithTimeIntervalSinceNow:kSettleTimeout];
    NSDate *dataFailureDeadline = nil;
    int net = 3;
    NSUInteger downSamples = 0;

    do {
        usleep((useconds_t)(kSettlePollInterval * 1000000));
        net = [TGNekroCommand run:[NSArray arrayWithObject:@"netcheck"]];
        if (net == 0)
            return YES;

        if (net == 3) {
            dataFailureDeadline = nil;
            downSamples = 0;
            continue;
        }

        if (net == 1) {
            if (dataFailureDeadline == nil)
                dataFailureDeadline = [NSDate dateWithTimeIntervalSinceNow:kDataFailureGrace];
            if ([dataFailureDeadline timeIntervalSinceNow] <= 0)
                break;
            continue;
        }

        if (net == 2) {
            downSamples++;
            if (downSamples >= 2)
                break;
        }
    } while ([startupDeadline timeIntervalSinceNow] > 0);

    FDPILog(@"daemon: netcheck via %@ = %d%@", endpoint, net,
            net == 1 ? @" (tunnel ready but carries no data)" :
            (net == 3 ? @" (tunnel startup timed out)" : @""));
    return NO;
}

- (BOOL)daemonTryProfile:(NSDictionary *)profile endpoint:(NSString *)endpoint
{
    FDPILog(@"spawn: stop via %@", [TGNekroCommand enginePath]);
    int stopped = [TGNekroCommand run:[NSArray arrayWithObject:@"stop"]];
    FDPILog(@"spawn: stop returned %d", stopped);

    if (stopped == TGNekroExitUnsupportedOS) {
        _engineRefused = YES;
        return NO;
    }

    FDPILog(@"spawn: warp-tunnel via %@", endpoint);
    int up = [TGNekroCommand run:[self argumentsForProfile:profile endpoint:endpoint]];
    FDPILog(@"spawn: warp-tunnel returned %d", up);
    if (up == TGNekroExitUnsupportedOS) {
        _engineRefused = YES;
        return NO;
    }
    if (up != 0) {
        FDPILog(@"daemon: warp-tunnel via %@ failed (exit %d)", endpoint, up);
        return NO;
    }

    return [self waitForDataThroughEndpoint:endpoint];
}

- (NSArray *)endpointsForConf:(NSDictionary *)parsed
{
    NSMutableArray *endpoints = [NSMutableArray array];
    NSString *own = [parsed objectForKey:@"endpoint"];
    if ([own length] != 0 && !TGEndpointIsDead(own))
        [endpoints addObject:own];
    for (NSString *ep in TGLiveEndpoints())
        if (![endpoints containsObject:ep]) [endpoints addObject:ep];
    return endpoints;
}

- (NSArray *)candidateRoutesForProfiles:(NSArray *)profiles
{
    NSInteger selected = [[NSUserDefaults standardUserDefaults] integerForKey:kFuckDPISelectedKey];

    NSMutableArray *indices = [NSMutableArray array];
    if (selected > 0 && (NSUInteger)(selected - 1) < profiles.count) {
        [indices addObject:@(selected - 1)];
    } else {
        for (NSUInteger i = 0; i < profiles.count; i++) [indices addObject:@(i)];
    }

    NSMutableArray *firstPass = [NSMutableArray array];
    NSMutableArray *rest = [NSMutableArray array];
    for (NSNumber *index in indices) {
        NSUInteger i = [index unsignedIntegerValue];
        NSDictionary *parsed = [self profileFromConf:[[profiles objectAtIndex:i] objectForKey:TGWarpProfileConf]];
        NSArray *endpoints = [self endpointsForConf:parsed];
        for (NSUInteger e = 0; e < endpoints.count; e++) {
            NSArray *route = [NSArray arrayWithObjects:index, [endpoints objectAtIndex:e], nil];
            [(e < kEndpointsInFirstPass ? firstPass : rest) addObject:route];
        }
    }

    NSMutableArray *routes = [NSMutableArray arrayWithArray:firstPass];
    [routes addObjectsFromArray:rest];

    NSString *remembered = [[NSUserDefaults standardUserDefaults] stringForKey:kFuckDPIRouteKey];
    if (remembered != nil) {
        for (NSUInteger i = 0; i < routes.count; i++) {
            NSArray *r = [routes objectAtIndex:i];
            NSString *key = [NSString stringWithFormat:@"%@|%@", [r objectAtIndex:0], [r objectAtIndex:1]];
            if ([key isEqualToString:remembered]) {
                [routes removeObjectAtIndex:i];
                [routes insertObject:r atIndex:0];
                break;
            }
        }
    }
    return routes;
}

- (BOOL)enableViaDaemon
{
    [self emit:TGRouteStateConnecting message:@"Запуск туннеля"];

    NSArray *profiles = [TGWarpProfileStore orderedProfiles];
    if (profiles.count == 0) {
        FDPILog(@"daemon: no profiles available");
        [self emit:TGRouteStateFailed message:@"Нет доступных профилей"];
        return NO;
    }

    NSArray *routes = [self candidateRoutesForProfiles:profiles];
    NSUInteger attempt = 0;
    _engineRefused = NO;
    for (NSArray *route in routes) {
        attempt++;
        NSUInteger idx = [[route objectAtIndex:0] unsignedIntegerValue];
        NSString *endpoint = [route objectAtIndex:1];
        NSDictionary *entry = [profiles objectAtIndex:idx];
        NSString *name = [entry objectForKey:TGWarpProfileName];

        [self emit:TGRouteStateSearching
           message:[NSString stringWithFormat:@"Поиск маршрута %lu из %lu…",
                    (unsigned long)attempt, (unsigned long)routes.count]];
        FDPILog(@"daemon: trying profile %@ via %@", name, endpoint);

        NSDictionary *parsed = [self profileFromConf:[entry objectForKey:TGWarpProfileConf]];
        if (![self daemonTryProfile:parsed endpoint:endpoint]) {
            if (_engineRefused) {
                FDPILog(@"daemon: engine refuses this OS (exit %d) — abandoning the route search",
                        TGNekroExitUnsupportedOS);
                return NO;
            }
            continue;
        }

        [[NSUserDefaults standardUserDefaults]
            setObject:[NSString stringWithFormat:@"%lu|%@", (unsigned long)idx, endpoint]
               forKey:kFuckDPIRouteKey];
        [[NSUserDefaults standardUserDefaults] setObject:name forKey:kFuckDPINameKey];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kFuckDPIEnabledKey];
        [[NSUserDefaults standardUserDefaults] synchronize];

        FDPILog(@"daemon: connected via %@ / %@", name, endpoint);
        [self emit:TGRouteStateConnected
           message:[NSString stringWithFormat:@"FuckDPI активен (%@)", name]];
        [TGRouteCoordinator startSupervisor];
        return YES;
    }

    [TGNekroCommand run:[NSArray arrayWithObject:@"stop"]];
    FDPILog(@"daemon: no profile carried traffic (%lu attempts)", (unsigned long)routes.count);
    return NO;
}

- (void)refreshState
{
    dispatch_async(TGRouteQueue(), ^{
        if (![TGRouteCoordinator isSupported]) {
            [self emit:TGRouteStateDisabled message:[TGRouteCoordinator unsupportedReason]];
            return;
        }

        if (![[NSUserDefaults standardUserDefaults] boolForKey:kFuckDPIEnabledKey]) {
            [self emit:TGRouteStateDisabled message:@"Выключено"];
            return;
        }

        [self emit:TGRouteStateSearching message:@"Проверка маршрута…"];
        if ([TGNekroCommand run:[NSArray arrayWithObject:@"netcheck"]] == 0) {
            NSString *name = [[NSUserDefaults standardUserDefaults] stringForKey:kFuckDPINameKey] ?: @"AWG/WARP";
            [self emit:TGRouteStateConnected
               message:[NSString stringWithFormat:@"FuckDPI активен (%@)", name]];
            [TGRouteCoordinator startSupervisor];
        } else {
            [self enableInternal];
        }
    });
}

- (void)enable
{
    dispatch_async(TGRouteQueue(), ^{
        [self enableInternal];
    });
}

- (void)enableInternal
{
    FDPILog(@"enableInternal starting");

    if (![TGRouteCoordinator isSupported]) {
        FDPILog(@"enableInternal: helper unusable (%@)", [TGRouteCoordinator unsupportedReason]);
        [self emit:TGRouteStateFailed message:[TGRouteCoordinator unsupportedReason]];
        return;
    }

    if ([self enableViaDaemon])
        return;

    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFuckDPIEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self emit:TGRouteStateFailed
       message:_engineRefused
            ? @"Движок не поддерживает эту версию iOS"
            : @"Все WARP-профили недоступны"];
}

- (void)disable
{
    dispatch_async(TGRouteQueue(), ^{
        [self emit:TGRouteStateConnecting message:@"Отключение"];
        [TGRouteCoordinator stopSupervisor];

        int rc = [TGNekroCommand run:[NSArray arrayWithObject:@"stop"]];
        int still = [TGNekroCommand run:[NSArray arrayWithObject:@"netcheck"]];
        if (still == 0) {
            FDPILog(@"disable: stop exit=%d but netcheck=0 — retrying stop", rc);
            rc = [TGNekroCommand run:[NSArray arrayWithObject:@"stop"]];
            still = [TGNekroCommand run:[NSArray arrayWithObject:@"netcheck"]];
        }
        FDPILog(@"disable: stop exit=%d, netcheck after=%d%@",
                rc, still, still == 0 ? @" — STILL UP" : @"");

        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kFuckDPIEnabledKey];
        [[NSUserDefaults standardUserDefaults] synchronize];

        [self emit:TGRouteStateDisabled message:@"Выключено"];
    });
}

@end
