#import "PowerSelector.h"
#import "PowerSession.h"
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <string.h>

static NSString * const kPWRememberedKey = @"power_choice";

static NSString * const kPWHistoryKey = @"power_history";
static const NSUInteger kPWHistoryMax = 8;
static const NSUInteger kPWRememberedMax = 32;

static const NSTimeInterval kPWFailMemory = 15 * 60;

@implementation PowerSelector {
    NSMutableDictionary *_failedAt;   
    BOOL _cancelSearch;
    NSUInteger _progressDone, _progressTotal;
    NSString *_lastReport;
}

- (void)dealloc {
    [_failedAt release]; [_lastReport release];
    [super dealloc];
}

- (NSString *)lastReport { @synchronized (self) { return [[_lastReport retain] autorelease] ?: @""; } }
- (void)setReport:(NSString *)report { @synchronized (self) { [_lastReport release]; _lastReport = [report copy]; } }
- (NSUInteger)progressDone { @synchronized (self) { return _progressDone; } }
- (NSUInteger)progressTotal { @synchronized (self) { return _progressTotal; } }

- (NSString *)networkKey {
    struct ifaddrs *interfaces = NULL;
    NSMutableArray *addresses = [NSMutableArray array];
    if (getifaddrs(&interfaces) == 0) {
        for (struct ifaddrs *item = interfaces; item; item = item->ifa_next) {
            if (!item->ifa_addr || !(item->ifa_flags & IFF_UP) || (item->ifa_flags & IFF_LOOPBACK)) continue;
            if (item->ifa_addr->sa_family != AF_INET) continue;
            NSString *entry;
            if (strncmp(item->ifa_name, "pdp_ip", 6) == 0) entry = [NSString stringWithUTF8String:item->ifa_name];
            else {
                char host[NI_MAXHOST];
                if (getnameinfo(item->ifa_addr, sizeof(struct sockaddr_in), host, sizeof(host), NULL, 0, NI_NUMERICHOST) != 0) continue;
                entry = [NSString stringWithFormat:@"%s:%s", item->ifa_name, host];
            }
            if (![addresses containsObject:entry]) [addresses addObject:entry];
        }
        freeifaddrs(interfaces);
    }
    [addresses sortUsingSelector:@selector(compare:)];
    return addresses.count ? [addresses componentsJoinedByString:@"|"] : @"нет сети";
}

- (BOOL)searchCancelled { @synchronized (self) { return _cancelSearch; } }

- (void)cancelSearch {
    @synchronized (self) { _cancelSearch = YES; }
    @synchronized (self) { _progressTotal = 0; }
}

- (PowerConfig *)chooseWorkingFrom:(NSArray *)configs
                           timeout:(NSTimeInterval)timeoutPerConfig {
    if (!configs.count) {
        [self setReport:@"Добавьте сервер или подписку Power"];
        return nil;
    }

    NSString *key = [self networkKey];
    NSDictionary *remembered = [[NSUserDefaults standardUserDefaults] objectForKey:kPWRememberedKey];
    NSString *winner = [remembered objectForKey:key];

    NSArray *history = [[NSUserDefaults standardUserDefaults] objectForKey:kPWHistoryKey] ?: @[];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSMutableDictionary *failed;
    @synchronized (self) {
        if (!_failedAt) _failedAt = [[NSMutableDictionary alloc] init];
        failed = [[_failedAt copy] autorelease];
    }
    NSMutableArray *first = [NSMutableArray array], *hist = [NSMutableArray array];
    NSMutableArray *rest = [NSMutableArray array], *recentFail = [NSMutableArray array];
    for (PowerConfig *c in configs) {
        NSString *hp = [NSString stringWithFormat:@"%@:%u", c.host, c.port];
        NSNumber *when = [failed objectForKey:hp];
        BOOL recent = when && now - when.doubleValue < kPWFailMemory;
        if (winner.length && [hp isEqualToString:winner] && !recent) [first addObject:c];
        else if ([history containsObject:hp] && !recent) [hist addObject:c];
        else if (recent) [recentFail addObject:c];
        else [rest addObject:c];
    }
    [hist sortUsingComparator:^NSComparisonResult(PowerConfig *a, PowerConfig *b) {
        NSUInteger ia = [history indexOfObject:[NSString stringWithFormat:@"%@:%u", a.host, a.port]];
        NSUInteger ib = [history indexOfObject:[NSString stringWithFormat:@"%@:%u", b.host, b.port]];
        return ia < ib ? NSOrderedAscending : ia > ib ? NSOrderedDescending : NSOrderedSame;
    }];
    NSMutableArray *order = [NSMutableArray arrayWithArray:first];
    [order addObjectsFromArray:hist];
    [order addObjectsFromArray:rest];
    [order addObjectsFromArray:recentFail];
    DLog(@"[power] очередь: в этой сети %lu, из истории %lu, прочих %lu, недавно не ответивших %lu",
         (unsigned long)first.count, (unsigned long)hist.count, (unsigned long)rest.count,
         (unsigned long)recentFail.count);

    NSMutableString *report = [NSMutableString stringWithFormat:@"сеть %@\n", key];
    int tried = 0;
    NSUInteger total = 0;
    for (PowerConfig *c in order) if ([c isSupported]) total++;
    @synchronized (self) { _progressDone = 0; _progressTotal = total; }
    OGDanteLog(@"[power] probing %lu servers", (unsigned long)total);
    for (PowerConfig *c in order) {
        if ([self searchCancelled]) {
            OGDanteLog(@"[power] probing cancelled");
            [self setReport:[report stringByAppendingString:@"прервано"]];
            return nil;
        }
        if (![c isSupported]) {
            [report appendFormat:@"  %@ — пропуск: %@\n", c.name, [c unsupportedReason]];
            continue;
        }
        tried++;
        PowerSession *session = [[[PowerSession alloc] initWithConfig:c] autorelease];
        int ms = -1;

        PWProbeResult r = [session probeThroughHost:@"www.google.com" port:80
                                            timeout:timeoutPerConfig
                                      latencyMillis:&ms];
        if ([self searchCancelled]) continue;
        @synchronized (self) { _progressDone = (NSUInteger)tried; }
        if (r == PWProbeOK) {
            OGDanteLog(@"[power] server %d/%lu ok, %d ms", tried, (unsigned long)total, ms);
            @synchronized (self) { _progressTotal = 0; }
            [report appendFormat:@"  %@ — работает, %d мс\n", c.name, ms];
            [self setReport:report];
            DLog(@"[power] подошла %@ (%d мс)", c.name, ms);

            NSString *hp = [NSString stringWithFormat:@"%@:%u", c.host, c.port];
            NSMutableDictionary *save = [NSMutableDictionary dictionaryWithDictionary:remembered.count && remembered.count < kPWRememberedMax ? remembered : @{}];
            [save setObject:hp forKey:key];
            [[NSUserDefaults standardUserDefaults] setObject:save forKey:kPWRememberedKey];
            NSMutableArray *h = [NSMutableArray arrayWithArray:history];
            [h removeObject:hp];
            [h insertObject:hp atIndex:0];
            while (h.count > kPWHistoryMax) [h removeLastObject];
            [[NSUserDefaults standardUserDefaults] setObject:h forKey:kPWHistoryKey];
            @synchronized (self) { [_failedAt removeObjectForKey:hp]; }
            [[NSUserDefaults standardUserDefaults] synchronize];
            return c;
        }
        NSString *why = r == PWProbeNoRoute ? @"сеть не пускает к серверу"
                      : r == PWProbeTLSFailed ? @"TLS не встал"
                      : r == PWProbeUnsupported ? @"не поддержано"
                      : @"сервер не ответил";
        [report appendFormat:@"  %@ — %@\n", c.name, why];
        @synchronized (self) {
            [_failedAt setObject:@([NSDate timeIntervalSinceReferenceDate])
                          forKey:[NSString stringWithFormat:@"%@:%u", c.host, c.port]];
        }
        OGDanteLog(@"[power] server %d/%lu failed (%@)", tried, (unsigned long)total,
             r == PWProbeNoRoute ? @"blocked" : r == PWProbeTLSFailed ? @"handshake"
             : r == PWProbeRejected ? @"rejected" : @"timeout");
    }
    @synchronized (self) { _progressTotal = 0; }
    OGDanteLog(@"[power] all %d servers failed", tried);

    [report appendFormat:@"проверено %d, рабочих нет", tried];
    [self setReport:report];
    DLog(@"[power] рабочей конфигурации не нашлось (проверено %d)", tried);
    return nil;
}

@end
