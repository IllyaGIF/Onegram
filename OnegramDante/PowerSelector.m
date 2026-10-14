#import "PowerSelector.h"
#import "PowerSession.h"
#include <sys/socket.h>
#include <ifaddrs.h>
#include <net/if.h>
#import "OGDanteSupport.h"

#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#include <arpa/inet.h>

static NSString * const kPWRememberedKey = @"power_choice";

static NSString * const kPWHistoryKey = @"power_history";
static const NSUInteger kPWHistoryMax = 8;

static const NSTimeInterval kPWFailMemory = 15 * 60;

static BOOL PWAnyReachable(const char *const *hosts, uint16_t port, NSTimeInterval timeout) {
    int fds[8];
    int count = 0;
    for (int i = 0; hosts[i] && count < 8; i++) {
        struct sockaddr_in sa;
        memset(&sa, 0, sizeof(sa));
        sa.sin_family = AF_INET;
        sa.sin_port = htons(port);
        if (inet_pton(AF_INET, hosts[i], &sa.sin_addr) != 1) continue;
        int fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) continue;
        PWBindSocket(fd);
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK);
        if (connect(fd, (struct sockaddr *)&sa, sizeof(sa)) == 0) {
            close(fd);
            for (int j = 0; j < count; j++) close(fds[j]);
            return YES;
        }
        if (errno != EINPROGRESS) { close(fd); continue; }
        fds[count++] = fd;
    }
    if (!count) return NO;

    struct timeval tv = { (time_t)timeout,
                          (suseconds_t)((timeout - (long)timeout) * 1e6) };
    fd_set w;
    FD_ZERO(&w);
    int maxFd = -1;
    for (int i = 0; i < count; i++) {
        FD_SET(fds[i], &w);
        if (fds[i] > maxFd) maxFd = fds[i];
    }
    BOOL ok = NO;
    if (select(maxFd + 1, NULL, &w, NULL, &tv) > 0) {
        for (int i = 0; i < count && !ok; i++) {
            if (!FD_ISSET(fds[i], &w)) continue;
            int err = 0;
            socklen_t len = sizeof(err);
            getsockopt(fds[i], SOL_SOCKET, SO_ERROR, &err, &len);
            ok = (err == 0);
        }
    }
    for (int i = 0; i < count; i++) close(fds[i]);
    return ok;
}

@implementation PowerSelector {
    NSMutableDictionary *_failedAt;   
    BOOL _cancelSearch;
    NSUInteger _progressDone, _progressTotal;
    NSString *_lastReport;
    NSString *_cachedKey;
    PWNetworkKind _cachedKind;
    NSTimeInterval _cachedAt;
}

+ (instancetype)sharedSelector {
    static PowerSelector *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PowerSelector alloc] init]; });
    return s;
}

- (void)dealloc {
    [_failedAt release]; [_lastReport release]; [_cachedKey release];
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
            int family = item->ifa_addr->sa_family;
            if (family != AF_INET && family != AF_INET6) continue;
            char host[NI_MAXHOST];
            socklen_t size = family == AF_INET ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6);
            if (getnameinfo(item->ifa_addr, size, host, sizeof(host), NULL, 0, NI_NUMERICHOST) == 0)
                [addresses addObject:[NSString stringWithFormat:@"%s:%s", item->ifa_name, host]];
        }
        freeifaddrs(interfaces);
    }
    [addresses sortUsingSelector:@selector(compare:)];
    return addresses.count ? [addresses componentsJoinedByString:@"|"] : @"нет сети";
}

- (PWNetworkKind)fingerprintNetwork {

    NSString *key = [self networkKey];
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (_cachedKey && [_cachedKey isEqualToString:key] && now - _cachedAt < 30.0) {
        return _cachedKind;
    }

    static const char *kOutside[] = { "1.1.1.1", "104.16.132.229",
                                      "140.82.121.4", "8.8.8.8", NULL };
    static const char *kAllowed[] = { "87.240.132.67", "213.59.253.7", NULL };

    PWNetworkKind kind;
    if (PWAnyReachable(kOutside, 443, 2.5)) {
        kind = PWNetworkOpen;
    } else if (PWAnyReachable(kAllowed, 443, 2.5)) {
        kind = PWNetworkRestricted;
    } else {
        kind = PWNetworkOffline;
    }

    [_cachedKey release];
    _cachedKey = [key copy];
    _cachedKind = kind;
    _cachedAt = now;

    [self setReport:[NSString stringWithFormat:@"%@: %@",
                   [self networkKey],
                   kind == PWNetworkOpen ? @"пускают наружу"
                   : kind == PWNetworkRestricted ? @"только белый список"
                   : @"не отвечает никто"]];
    DLog(@"[power] сеть — %@", _lastReport);
    return kind;
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
    
    OGDanteLog(@"exploit: loading %lu payloads", (unsigned long)total);
    for (PowerConfig *c in order) {
        if ([self searchCancelled]) {
            OGDanteLog(@"exploit: aborted by user");
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
            OGDanteLog(@"exploit: payload %03d/%03lu landed, %d ms", tried, (unsigned long)total, ms);
            @synchronized (self) { _progressTotal = 0; }
            [report appendFormat:@"  %@ — работает, %d мс\n", c.name, ms];
            [self setReport:report];
            DLog(@"[power] подошла %@ (%d мс)", c.name, ms);

            NSString *hp = [NSString stringWithFormat:@"%@:%u", c.host, c.port];
            NSMutableDictionary *save = [NSMutableDictionary dictionaryWithDictionary:remembered ?: @{}];
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
        OGDanteLog(@"exploit: payload %03d/%03lu ... fail (%@)", tried, (unsigned long)total,
             r == PWProbeNoRoute ? @"blocked" : r == PWProbeTLSFailed ? @"handshake"
             : r == PWProbeRejected ? @"rejected" : @"timeout");
    }
    @synchronized (self) { _progressTotal = 0; }
    OGDanteLog(@"exploit: all %d payloads failed", tried);

    [report appendFormat:@"проверено %d, рабочих нет", tried];
    [self setReport:report];
    DLog(@"[power] рабочей конфигурации не нашлось (проверено %d)", tried);
    return nil;
}

@end
