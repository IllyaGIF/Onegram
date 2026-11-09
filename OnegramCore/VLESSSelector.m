#import "VLESSSelector.h"
#import "VLESSSession.h"
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <string.h>

static NSString * const kVLRememberedKey = @"vless_choice";
static NSString * const kVLLegacyRememberedKey = @"power_choice";
static NSString * const kVLHistoryKey = @"vless_history";
static NSString * const kVLLegacyHistoryKey = @"power_history";
static const NSUInteger kVLHistoryMax = 8;
static const NSUInteger kVLRememberedMax = 32;

static const NSTimeInterval kVLFailMemory = 15 * 60;

@implementation VLESSSelector {
    NSMutableDictionary *_failedAt;   
    BOOL _cancelSearch;
    NSUInteger _progressDone, _progressTotal;
    NSString *_lastReport;
}

+ (void)initialize {
    if (self != [VLESSSelector class]) return;
    OGCoreMoveUserDefaultsValue(kVLLegacyRememberedKey, kVLRememberedKey);
    OGCoreMoveUserDefaultsValue(kVLLegacyHistoryKey, kVLHistoryKey);
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

- (VLESSConfig *)chooseWorkingFrom:(NSArray *)configs
                           timeout:(NSTimeInterval)timeoutPerConfig {
    if (!configs.count) {
        [self setReport:@"Добавьте сервер или подписку VLESS"];
        return nil;
    }

    NSString *key = [self networkKey];
    NSDictionary *remembered = [[NSUserDefaults standardUserDefaults] objectForKey:kVLRememberedKey];
    NSString *winner = [remembered objectForKey:key];

    NSArray *history = [[NSUserDefaults standardUserDefaults] objectForKey:kVLHistoryKey] ?: @[];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSMutableDictionary *failed;
    @synchronized (self) {
        if (!_failedAt) _failedAt = [[NSMutableDictionary alloc] init];
        failed = [[_failedAt copy] autorelease];
    }
    NSMutableArray *first = [NSMutableArray array], *hist = [NSMutableArray array];
    NSMutableArray *rest = [NSMutableArray array], *recentFail = [NSMutableArray array];
    for (VLESSConfig *c in configs) {
        NSString *hp = [NSString stringWithFormat:@"%@:%u", c.host, c.port];
        NSNumber *when = [failed objectForKey:hp];
        BOOL recent = when && now - when.doubleValue < kVLFailMemory;
        if (winner.length && [hp isEqualToString:winner] && !recent) [first addObject:c];
        else if ([history containsObject:hp] && !recent) [hist addObject:c];
        else if (recent) [recentFail addObject:c];
        else [rest addObject:c];
    }
    [hist sortUsingComparator:^NSComparisonResult(VLESSConfig *a, VLESSConfig *b) {
        NSUInteger ia = [history indexOfObject:[NSString stringWithFormat:@"%@:%u", a.host, a.port]];
        NSUInteger ib = [history indexOfObject:[NSString stringWithFormat:@"%@:%u", b.host, b.port]];
        return ia < ib ? NSOrderedAscending : ia > ib ? NSOrderedDescending : NSOrderedSame;
    }];
    NSMutableArray *order = [NSMutableArray arrayWithArray:first];
    [order addObjectsFromArray:hist];
    [order addObjectsFromArray:rest];
    [order addObjectsFromArray:recentFail];
    DLog(@"[vless] очередь: в этой сети %lu, из истории %lu, прочих %lu, недавно не ответивших %lu",
         (unsigned long)first.count, (unsigned long)hist.count, (unsigned long)rest.count,
         (unsigned long)recentFail.count);

    NSMutableString *report = [NSMutableString stringWithFormat:@"сеть %@\n", key];
    int tried = 0;
    NSUInteger total = 0;
    for (VLESSConfig *c in order) if ([c isSupported]) total++;
    @synchronized (self) { _progressDone = 0; _progressTotal = total; }
    OGCoreLog(@"[vless] probing %lu servers", (unsigned long)total);
    for (VLESSConfig *c in order) {
        if ([self searchCancelled]) {
            OGCoreLog(@"[vless] probing cancelled");
            [self setReport:[report stringByAppendingString:@"прервано"]];
            return nil;
        }
        if (![c isSupported]) {
            [report appendFormat:@"  %@ — пропуск: %@\n", c.name, [c unsupportedReason]];
            continue;
        }
        tried++;
        VLESSSession *session = [[[VLESSSession alloc] initWithConfig:c] autorelease];
        int ms = -1;

        VLProbeResult r = [session probeThroughHost:@"www.google.com" port:80
                                            timeout:timeoutPerConfig
                                      latencyMillis:&ms];
        if ([self searchCancelled]) continue;
        @synchronized (self) { _progressDone = (NSUInteger)tried; }
        if (r == VLProbeOK) {
            OGCoreLog(@"[vless] server %d/%lu ok, %d ms", tried, (unsigned long)total, ms);
            @synchronized (self) { _progressTotal = 0; }
            [report appendFormat:@"  %@ — работает, %d мс\n", c.name, ms];
            [self setReport:report];
            DLog(@"[vless] подошла %@ (%d мс)", c.name, ms);

            NSString *hp = [NSString stringWithFormat:@"%@:%u", c.host, c.port];
            NSMutableDictionary *save = [NSMutableDictionary dictionaryWithDictionary:remembered.count && remembered.count < kVLRememberedMax ? remembered : @{}];
            [save setObject:hp forKey:key];
            [[NSUserDefaults standardUserDefaults] setObject:save forKey:kVLRememberedKey];
            NSMutableArray *h = [NSMutableArray arrayWithArray:history];
            [h removeObject:hp];
            [h insertObject:hp atIndex:0];
            while (h.count > kVLHistoryMax) [h removeLastObject];
            [[NSUserDefaults standardUserDefaults] setObject:h forKey:kVLHistoryKey];
            @synchronized (self) { [_failedAt removeObjectForKey:hp]; }
            [[NSUserDefaults standardUserDefaults] synchronize];
            return c;
        }
        NSString *why = r == VLProbeNoRoute ? @"сеть не пускает к серверу"
                      : r == VLProbeTLSFailed ? @"TLS не встал"
                      : r == VLProbeUnsupported ? @"не поддержано"
                      : @"сервер не ответил";
        [report appendFormat:@"  %@ — %@\n", c.name, why];
        @synchronized (self) {
            [_failedAt setObject:@([NSDate timeIntervalSinceReferenceDate])
                          forKey:[NSString stringWithFormat:@"%@:%u", c.host, c.port]];
        }
        OGCoreLog(@"[vless] server %d/%lu failed (%@)", tried, (unsigned long)total,
             r == VLProbeNoRoute ? @"blocked" : r == VLProbeTLSFailed ? @"handshake"
             : r == VLProbeRejected ? @"rejected" : @"timeout");
    }
    @synchronized (self) { _progressTotal = 0; }
    OGCoreLog(@"[vless] all %d servers failed", tried);

    [report appendFormat:@"проверено %d, рабочих нет", tried];
    [self setReport:report];
    DLog(@"[vless] рабочей конфигурации не нашлось (проверено %d)", tried);
    return nil;
}

@end
