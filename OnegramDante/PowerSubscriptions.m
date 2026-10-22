#import "PowerSubscriptions.h"
#import "PowerConfig.h"
#import <Security/Security.h>
#import "OGDanteSupport.h"

NSString * const PowerSubscriptionsDidChangeNotification = @"PowerSubscriptionsDidChangeNotification";

static NSString * const kPWSubsKey = @"power_subscriptions";
static NSString * const kPWManualKey = @"power_configs";
static const NSTimeInterval kPWRefreshEvery = 3600;          
static const NSTimeInterval kPWRetryAfterFailure = 10 * 60;

@implementation PowerSubscriptions {
    dispatch_queue_t _queue;       
    volatile BOOL _refreshing;
    NSTimeInterval _lastAttempt;
    NSDictionary *_state;
    NSError *_storageError;
}

+ (PowerSubscriptions *)shared {
    static PowerSubscriptions *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[PowerSubscriptions alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("org.onegram.power.subscriptions", NULL);
        NSMutableDictionary *query = [self keychainQuery];
        [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
        CFTypeRef result = NULL;
        OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
        if (status == errSecSuccess) {
            id state = [NSPropertyListSerialization propertyListFromData:(NSData *)result mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
            if ([state isKindOfClass:[NSDictionary class]] &&
                [[state objectForKey:@"manual"] isKindOfClass:[NSArray class]] &&
                [[state objectForKey:@"subscriptions"] isKindOfClass:[NSArray class]]) _state = [state copy];
            else _storageError = [[NSError errorWithDomain:@"Onegram.Power" code:2 userInfo:[NSDictionary dictionaryWithObject:@"Не удалось прочитать сохранённые настройки Power" forKey:NSLocalizedDescriptionKey]] retain];
            CFRelease(result);
        } else if (status == errSecItemNotFound) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:
                [defaults objectForKey:kPWManualKey] ?: [NSArray array], @"manual",
                [defaults objectForKey:kPWSubsKey] ?: [NSArray array], @"subscriptions", nil];
            if ([self saveState:state error:NULL]) {
                [defaults removeObjectForKey:kPWManualKey];
                [defaults removeObjectForKey:kPWSubsKey];
                [defaults synchronize];
            }
        } else _storageError = [[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil] retain];
    }
    return self;
}

- (void)dealloc {
    dispatch_release(_queue);
    [_state release];
    [_storageError release];
    [super dealloc];
}

- (NSMutableDictionary *)keychainQuery {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
        (id)kSecClassGenericPassword, (id)kSecClass,
        @"Onegram.DantePower", (id)kSecAttrService,
        @"configuration", (id)kSecAttrAccount, nil];
}

- (NSError *)storageError { @synchronized (self) { return [[_storageError retain] autorelease]; } }

- (void)postChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:PowerSubscriptionsDidChangeNotification object:self];
}

- (NSArray *)configurationLinesInState:(NSDictionary *)state {
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[state objectForKey:@"manual"] ?: [NSArray array]];
    for (NSDictionary *subscription in [state objectForKey:@"subscriptions"]) [lines addObjectsFromArray:[subscription objectForKey:@"lines"]];
    return lines;
}

- (BOOL)saveState:(NSDictionary *)state error:(NSString **)error {
    if (!_state && _storageError) { if (error) *error = _storageError.localizedDescription; return NO; }
    NSString *selected = [state objectForKey:@"selected"];
    if (selected && ![[self configurationLinesInState:state] containsObject:selected]) {
        NSMutableDictionary *normalized = [NSMutableDictionary dictionaryWithDictionary:state];
        [normalized removeObjectForKey:@"selected"];
        state = normalized;
    }
    BOOL changed = ![[self configurationLinesInState:state] isEqual:[self configurationLinesInState:_state]] ||
        !([[_state objectForKey:@"selected"] isEqual:[state objectForKey:@"selected"]] || (![_state objectForKey:@"selected"] && ![state objectForKey:@"selected"]));
    NSString *description = nil;
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:state format:NSPropertyListBinaryFormat_v1_0 errorDescription:&description];
    OSStatus status = errSecParam;
    if (data) {
        NSMutableDictionary *query = [self keychainQuery];
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:data forKey:(id)kSecValueData];
        status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attributes);
        if (status == errSecItemNotFound) {
            [query addEntriesFromDictionary:attributes];
            status = SecItemAdd((CFDictionaryRef)query, NULL);
        }
    }
    [_storageError release];
    _storageError = nil;
    if (status == errSecSuccess) {
        [_state release];
        _state = [state copy];
        if (changed) [self performSelectorOnMainThread:@selector(postChange) withObject:nil waitUntilDone:NO];
    } else {
        _storageError = [[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:
            description ? [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey] : nil] retain];
        if (error) *error = _storageError.localizedDescription;
    }
    [description release];
    return status == errSecSuccess;
}

- (NSArray *)stored { return [_state objectForKey:@"subscriptions"] ?: [NSArray array]; }

- (BOOL)store:(NSArray *)subs error:(NSString **)error {
    NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:_state ?: [NSDictionary dictionary]];
    [state setObject:subs forKey:@"subscriptions"];
    return [self saveState:state error:error];
}

- (NSString *)selectedLine {
    @synchronized (self) { return [[[_state objectForKey:@"selected"] retain] autorelease]; }
}

- (BOOL)selectLine:(NSString *)line error:(NSString **)error {
    @synchronized (self) {
        if (line && ![[self allLines] containsObject:line]) { if (error) *error = @"Сервер отсутствует в списке"; return NO; }
        NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:_state ?: [NSDictionary dictionary]];
        if (line) [state setObject:line forKey:@"selected"];
        else [state removeObjectForKey:@"selected"];
        return [self saveState:state error:error];
    }
}

- (NSArray *)manualLines {
    @synchronized (self) { return [[[_state objectForKey:@"manual"] retain] autorelease] ?: [NSArray array]; }
}

- (BOOL)addText:(NSString *)text error:(NSString **)error {
    NSArray *lines = [PowerConfig linesFromText:text];
    if (!lines.count) { if (error) *error = @"Не найдено корректных ссылок vless://"; return NO; }
    @synchronized (self) {
        NSMutableArray *manual = [NSMutableArray arrayWithArray:[self manualLines]];
        for (NSString *line in lines) if (![manual containsObject:line]) [manual addObject:line];
        NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:_state ?: [NSDictionary dictionary]];
        [state setObject:manual forKey:@"manual"];
        return [self saveState:state error:error];
    }
}

- (BOOL)removeManualLine:(NSString *)line error:(NSString **)error {
    @synchronized (self) {
        NSMutableArray *manual = [NSMutableArray arrayWithArray:[self manualLines]];
        [manual removeObject:line];
        NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:_state ?: [NSDictionary dictionary]];
        [state setObject:manual forKey:@"manual"];
        return [self saveState:state error:error];
    }
}

- (NSArray *)allLines {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSArray *manual = [self manualLines];
    for (NSString *l in manual) if (![seen containsObject:l]) { [seen addObject:l]; [out addObject:l]; }
    @synchronized (self) {
        for (NSDictionary *sub in [self stored]) {
            for (NSString *l in [sub objectForKey:@"lines"]) {
                if (![seen containsObject:l]) { [seen addObject:l]; [out addObject:l]; }
            }
        }
    }
    return out;
}

- (NSArray *)subscriptions {
    NSMutableArray *out = [NSMutableArray array];
    @synchronized (self) {
        for (NSDictionary *sub in [self stored]) {
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:sub];
            [d setObject:@([[sub objectForKey:@"lines"] count]) forKey:@"count"];
            [d removeObjectForKey:@"lines"];
            [out addObject:d];
        }
    }
    return out;
}

- (BOOL)removeAtIndex:(NSUInteger)index error:(NSString **)error {
    @synchronized (self) {
        NSMutableArray *subs = [NSMutableArray arrayWithArray:[self stored]];
        if (index >= subs.count) return NO;
        [subs removeObjectAtIndex:index];
        return [self store:subs error:error];
    }
}

static NSArray *PWFetchLines(NSString *urlText, NSString **error) {
    NSURL *url = [NSURL URLWithString:urlText];
    if (!url.host.length || !([url.scheme.lowercaseString isEqualToString:@"https"] || [url.scheme.lowercaseString isEqualToString:@"http"])) { if (error) *error = @"это не URL"; return nil; }
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:20];
    NSURLResponse *response = nil;
    NSError *err = nil;
    NSData *body = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
    NSInteger code = [response isKindOfClass:[NSHTTPURLResponse class]]
                   ? [(NSHTTPURLResponse *)response statusCode] : 0;
    if (!body.length || (code && code != 200)) {
        if (error) *error = err.localizedDescription ?: [NSString stringWithFormat:@"HTTP %ld", (long)code];
        return nil;
    }
    NSString *text = [[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] autorelease];
    if (!text) { if (error) *error = @"ответ не похож на текст"; return nil; }

    NSArray *lines = [PowerConfig linesFromText:text];
    if (!lines.count) { if (error) *error = @"в списке ни одного сервера"; return nil; }
    return lines;
}

- (NSString *)addURL:(NSString *)url error:(NSString **)error {
    NSString *err = nil;
    NSArray *lines = PWFetchLines(url, &err);
    if (!lines) { if (error) *error = err; return nil; }
    NSUInteger total;
    @synchronized (self) {
        NSMutableArray *subs = [NSMutableArray arrayWithArray:[self stored]];
        NSDictionary *entry = @{ @"url": url, @"lines": lines,
                                 @"fetchedAt": @([NSDate timeIntervalSinceReferenceDate]) };
        NSUInteger existing = NSNotFound;
        for (NSUInteger i = 0; i < subs.count; i++) {
            if ([[[subs objectAtIndex:i] objectForKey:@"url"] isEqualToString:url]) { existing = i; break; }
        }
        if (existing != NSNotFound) [subs replaceObjectAtIndex:existing withObject:entry];
        else [subs addObject:entry];
        NSMutableArray *manual = [NSMutableArray arrayWithArray:[self manualLines]];
        [manual removeObjectsInArray:lines];
        NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:_state ?: [NSDictionary dictionary]];
        [state setObject:manual forKey:@"manual"];
        [state setObject:subs forKey:@"subscriptions"];
        if (![self saveState:state error:error]) return nil;
        total = subs.count;
    }
    OGDanteLog(@"[power] subscription added, %lu servers", (unsigned long)lines.count);
    return [NSString stringWithFormat:@"серверов %lu, подписок %lu", (unsigned long)lines.count, (unsigned long)total];
}

- (NSString *)refreshIndex:(NSUInteger)i added:(NSUInteger *)addedOut removed:(NSUInteger *)removedOut failed:(BOOL *)failedOut {
    NSDictionary *sub;
    @synchronized (self) {
        NSArray *subs = [self stored];
        if (i >= subs.count) return nil;
        sub = [[[subs objectAtIndex:i] retain] autorelease];
    }
    NSString *url = [sub objectForKey:@"url"];
    NSString *err = nil;
    NSArray *lines = PWFetchLines(url, &err);
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    @synchronized (self) {
        NSMutableArray *subs = [NSMutableArray arrayWithArray:[self stored]];
        
        NSUInteger at = NSNotFound;
        for (NSUInteger k = 0; k < subs.count; k++) {
            if ([[[subs objectAtIndex:k] objectForKey:@"url"] isEqualToString:url]) { at = k; break; }
        }
        if (at == NSNotFound) return nil;
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:[subs objectAtIndex:at]];
        [d setObject:@(now) forKey:@"triedAt"];
        if (!lines) {
            if (failedOut) *failedOut = YES;
            [d setObject:err ?: @"ошибка" forKey:@"lastError"];
            [subs replaceObjectAtIndex:at withObject:d];
            if (![self store:subs error:&err]) return err;
            return [NSString stringWithFormat:@"%@ — не обновилась (%@), оставлен прежний список", url, err];
        }
        NSArray *old = [d objectForKey:@"lines"] ?: @[];
        NSUInteger added = 0, removed = 0;
        for (NSString *l in lines) if (![old containsObject:l]) added++;
        for (NSString *l in old) if (![lines containsObject:l]) removed++;
        [d setObject:lines forKey:@"lines"];
        [d setObject:@(now) forKey:@"fetchedAt"];
        [d removeObjectForKey:@"lastError"];
        [subs replaceObjectAtIndex:at withObject:d];
        if (![self store:subs error:&err]) return err;
        if (addedOut) *addedOut += added;
        if (removedOut) *removedOut += removed;
        return [NSString stringWithFormat:@"%@ — %lu серверов (+%lu −%lu)", url,
                (unsigned long)lines.count, (unsigned long)added, (unsigned long)removed];
    }
}

- (NSString *)refreshAllOnQueue {
    NSUInteger count;
    @synchronized (self) { count = [self stored].count; }
    if (!count) return @"Подписок нет";
    NSMutableArray *report = [NSMutableArray array];
    NSUInteger added = 0, removed = 0, failed = 0;
    for (NSUInteger i = 0; i < count; i++) {
        BOOL subscriptionFailed = NO;
        NSString *r = [self refreshIndex:i added:&added removed:&removed failed:&subscriptionFailed];
        if (r) [report addObject:r];
        if (subscriptionFailed) failed++;
    }
    NSUInteger total = [self allLines].count;
    OGDanteLog(@"[power] %lu/%lu subscriptions synced, %lu servers (+%lu -%lu)", (unsigned long)(count - failed),
         (unsigned long)count, (unsigned long)total, (unsigned long)added, (unsigned long)removed);
    DLog(@"[power] подписки обновлены: %@", [report componentsJoinedByString:@"; "]);
    NSString *summary = failed == count
        ? @"Подписки не обновились"
        : [NSString stringWithFormat:@"Серверов %lu (+%lu −%lu)", (unsigned long)total,
           (unsigned long)added, (unsigned long)removed];
    return [[@[summary] arrayByAddingObjectsFromArray:report] componentsJoinedByString:@"\n"];
}

- (NSString *)refreshAllNow {
    __block NSString *r;
    dispatch_sync(_queue, ^{ @autoreleasepool { r = [[self refreshAllOnQueue] copy]; } });
    return [r autorelease];
}

- (void)refreshIfStale {
    @synchronized (self) {
    if (_refreshing) return;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - _lastAttempt < 60) return;                 
    BOOL due = NO;
    @synchronized (self) {
        for (NSDictionary *sub in [self stored]) {
            double fetched = [[sub objectForKey:@"fetchedAt"] doubleValue];
            double tried = [[sub objectForKey:@"triedAt"] doubleValue];
            BOOL failed = [sub objectForKey:@"lastError"] != nil;
            if (now - fetched >= kPWRefreshEvery && (!failed || now - tried >= kPWRetryAfterFailure)) {
                due = YES;
                break;
            }
        }
    }
    if (!due) return;
    _refreshing = YES;
    _lastAttempt = now;
    }
    dispatch_async(_queue, ^{
        @autoreleasepool {
            [self refreshAllOnQueue];
            @synchronized (self) { self->_refreshing = NO; }
        }
    });
}

@end
