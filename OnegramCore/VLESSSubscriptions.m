#import "VLESSSubscriptions.h"
#import "VLESSConfig.h"
#import <Security/Security.h>
#import "OGCoreSupport.h"

NSString * const VLESSSubscriptionsDidChangeNotification = @"VLESSSubscriptionsDidChangeNotification";

static NSString * const kVLKeychainService = @"Onegram.VLESS";
static NSString * const kVLLegacyKeychainService = @"Onegram.DantePower";
static NSString * const kVLKeychainAccount = @"configuration";
static NSString * const kVLLegacySubsKey = @"power_subscriptions";
static NSString * const kVLLegacyManualKey = @"power_configs";
static const NSTimeInterval kVLRefreshEvery = 3600;          
static const NSTimeInterval kVLRetryAfterFailure = 10 * 60;

static BOOL VLStringLines(id lines) {
    if (![lines isKindOfClass:[NSArray class]]) return NO;
    for (id line in lines) if (![line isKindOfClass:[NSString class]] || ![VLESSConfig configFromURI:line]) return NO;
    return YES;
}

static BOOL VLValidState(id value) {
    if (![value isKindOfClass:[NSDictionary class]] || !VLStringLines([value objectForKey:@"manual"])) return NO;
    id deviceID = [value objectForKey:@"deviceID"];
    if (deviceID && (![deviceID isKindOfClass:[NSString class]] || ![deviceID length])) return NO;
    id selected = [value objectForKey:@"selected"];
    if (selected && ![selected isKindOfClass:[NSString class]]) return NO;
    id subscriptions = [value objectForKey:@"subscriptions"];
    if (![subscriptions isKindOfClass:[NSArray class]]) return NO;
    for (id sub in subscriptions) {
        if (![sub isKindOfClass:[NSDictionary class]] || ![[sub objectForKey:@"url"] isKindOfClass:[NSString class]] ||
            !VLStringLines([sub objectForKey:@"lines"])) return NO;
        for (NSString *key in [NSArray arrayWithObjects:@"fetchedAt", @"triedAt", nil]) {
            id time = [sub objectForKey:key];
            if (time && ![time isKindOfClass:[NSNumber class]]) return NO;
        }
        id error = [sub objectForKey:@"lastError"];
        if (error && ![error isKindOfClass:[NSString class]]) return NO;
    }
    return YES;
}

@interface VLSubscriptionDownload : NSObject {
    NSMutableData *_body;
    NSHTTPURLResponse *_response;
    NSError *_error;
    BOOL _finished;
    NSUInteger _redirects;
}
- (NSData *)fetch:(NSURLRequest *)request response:(NSHTTPURLResponse **)response error:(NSError **)error;
@end

@implementation VLSubscriptionDownload
- (void)dealloc {
    [_body release]; [_response release]; [_error release];
    [super dealloc];
}
- (void)fail:(NSURLConnection *)connection message:(NSString *)message {
    [_error release];
    _error = [[NSError errorWithDomain:@"Onegram.VLESS.Subscription" code:1 userInfo:
        [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]] retain];
    _finished = YES;
    [connection cancel];
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    NSString *scheme = request.URL.scheme.lowercaseString;
    if (response && (++_redirects > 5 || ![scheme isEqualToString:@"https"] || request.URL.user.length || request.URL.password.length)) {
        [self fail:connection message:@"Недопустимое перенаправление подписки"];
        return nil;
    }
    return request;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if (![response isKindOfClass:[NSHTTPURLResponse class]] || response.expectedContentLength > 4 * 1024 * 1024) {
        [self fail:connection message:@"Ответ подписки слишком большой или имеет неверный формат"];
        return;
    }
    [_response release]; _response = [(NSHTTPURLResponse *)response retain];
    [_body setLength:0];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (data.length > 4 * 1024 * 1024 - _body.length) {
        [self fail:connection message:@"Подписка превышает 4 МБ"];
        return;
    }
    [_body appendData:data];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [_error release]; _error = [error retain]; _finished = YES;
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection { _finished = YES; }
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)response { return nil; }
- (NSData *)fetch:(NSURLRequest *)request response:(NSHTTPURLResponse **)response error:(NSError **)error {
    _body = [[NSMutableData alloc] init];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [connection start];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:20];
    while (connection && !_finished && deadline.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    if (!_finished) [self fail:connection message:@"Истекло время загрузки подписки"];
    [connection cancel];
    [connection release];
    if (response) *response = [[_response retain] autorelease];
    if (error) *error = [[_error retain] autorelease];
    return _error ? nil : [[_body retain] autorelease];
}
@end

@implementation VLESSSubscriptions {
    dispatch_queue_t _queue;       
    volatile BOOL _refreshing;
    NSTimeInterval _lastAttempt;
    NSDictionary *_state;
    NSError *_storageError;
}

+ (VLESSSubscriptions *)shared {
    static VLESSSubscriptions *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[VLESSSubscriptions alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("org.onegram.vless.subscriptions", NULL);
        CFTypeRef result = NULL;
        OSStatus status = OGCoreMoveKeychainItem(kVLLegacyKeychainService, kVLKeychainService, kVLKeychainAccount);
        if (status == errSecSuccess) {
            NSMutableDictionary *query = [self keychainQuery];
            [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
            status = SecItemCopyMatching((CFDictionaryRef)query, &result);
        }
        if (status == errSecSuccess) {
            id state = [NSPropertyListSerialization propertyListFromData:(NSData *)result mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
            if (VLValidState(state)) _state = [state copy];
            else _storageError = [[NSError errorWithDomain:@"Onegram.VLESS" code:2 userInfo:[NSDictionary dictionaryWithObject:@"Не удалось прочитать сохранённые настройки VLESS" forKey:NSLocalizedDescriptionKey]] retain];
            CFRelease(result);
        } else if (status == errSecItemNotFound) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSDictionary *state = [NSDictionary dictionaryWithObjectsAndKeys:
                [defaults objectForKey:kVLLegacyManualKey] ?: [NSArray array], @"manual",
                [defaults objectForKey:kVLLegacySubsKey] ?: [NSArray array], @"subscriptions", nil];
            if ([self saveState:state error:NULL]) {
                [defaults removeObjectForKey:kVLLegacyManualKey];
                [defaults removeObjectForKey:kVLLegacySubsKey];
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
        kVLKeychainService, (id)kSecAttrService,
        kVLKeychainAccount, (id)kSecAttrAccount, nil];
}

- (NSError *)storageError { @synchronized (self) { return [[_storageError retain] autorelease]; } }

- (void)postChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:VLESSSubscriptionsDidChangeNotification object:self];
}

- (NSArray *)configurationLinesInState:(NSDictionary *)state {
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[state objectForKey:@"manual"] ?: [NSArray array]];
    for (NSDictionary *subscription in [state objectForKey:@"subscriptions"]) [lines addObjectsFromArray:[subscription objectForKey:@"lines"]];
    return lines;
}

- (BOOL)saveState:(NSDictionary *)state error:(NSString **)error {
    if (!VLValidState(state)) {
        if (!_state && !_storageError) _storageError = [[NSError errorWithDomain:@"Onegram.VLESS" code:2 userInfo:
            [NSDictionary dictionaryWithObject:@"Повреждены настройки VLESS" forKey:NSLocalizedDescriptionKey]] retain];
        if (error) *error = @"Повреждены настройки VLESS";
        return NO;
    }
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

- (NSString *)subscriptionDeviceID:(NSString **)error {
    @synchronized (self) {
        NSString *identifier = [_state objectForKey:@"deviceID"];
        if (identifier.length) return [[identifier retain] autorelease];
        if (!_state || _storageError) {
            if (error) *error = _storageError.localizedDescription ?: @"Настройки VLESS недоступны";
            return nil;
        }
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        if (!uuid) { if (error) *error = @"Не удалось создать идентификатор подписки"; return nil; }
        NSString *generated = [(NSString *)CFUUIDCreateString(NULL, uuid) autorelease];
        CFRelease(uuid);
        if (!generated.length) { if (error) *error = @"Не удалось создать идентификатор подписки"; return nil; }
        NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:_state];
        [state setObject:generated forKey:@"deviceID"];
        return [self saveState:state error:error] ? generated : nil;
    }
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
    NSArray *lines = [VLESSConfig linesFromText:text];
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

static NSString *VLHeader(NSHTTPURLResponse *response, NSString *name) {
    for (id key in response.allHeaderFields)
        if ([[key description] caseInsensitiveCompare:name] == NSOrderedSame) return [[response.allHeaderFields objectForKey:key] description];
    return nil;
}

static NSArray *VLFetchLines(NSString *urlText, NSString *deviceID, NSString **error) {
    NSURL *url = [NSURL URLWithString:[urlText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    if (!url.host.length || ![url.scheme.lowercaseString isEqualToString:@"https"] || url.user.length || url.password.length) {
        if (error) *error = @"Нужна ссылка подписки https:// без имени пользователя и пароля";
        return nil;
    }
    NSArray *agents = [NSArray arrayWithObjects:@"Onegram/1.0", @"v2rayN/7.0 (Onegram VLESS)", nil];
    NSString *failure = nil;
    for (NSString *agent in agents) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
        [request setValue:agent forHTTPHeaderField:@"User-Agent"];
        [request setValue:deviceID forHTTPHeaderField:@"x-hwid"];
        [request setValue:@"iOS" forHTTPHeaderField:@"x-device-os"];
        [request setValue:@"text/plain, application/json;q=0.9, */*;q=0.1" forHTTPHeaderField:@"Accept"];
        VLSubscriptionDownload *download = [[[VLSubscriptionDownload alloc] init] autorelease];
        NSHTTPURLResponse *response = nil;
        NSError *fetchError = nil;
        NSData *body = [download fetch:request response:&response error:&fetchError];
        if (fetchError) { failure = fetchError.localizedDescription; break; }
        NSInteger status = response.statusCode;
        if ([VLHeader(response, @"x-hwid-max-devices-reached") boolValue] || [VLHeader(response, @"x-hwid-limit") boolValue]) {
            failure = @"Провайдер отклонил подписку: требуется HWID или достигнут лимит устройств";
            break;
        }
        if ([VLHeader(response, @"x-hwid-not-supported") boolValue]) {
            failure = @"Подписка требует привязки устройства по HWID";
            break;
        }
        if (status < 200 || status >= 300) {
            failure = [NSString stringWithFormat:@"Сервер подписки вернул HTTP %ld", (long)status];
            break;
        }
        if (!body.length) {
            failure = status == 204 ? @"Сервер вернул HTTP 204 без списка серверов. Проверьте срок действия подписки и настройки доступа у провайдера" : @"Сервер вернул пустую подписку";
            continue;
        }
        NSString *text = [[[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] autorelease];
        if (!text) { failure = @"Подписка не является текстом UTF-8"; break; }
        NSArray *lines = [VLESSConfig linesFromText:text];
        if (lines.count) return lines;
        failure = @"В ответе нет конфигураций VLESS: ожидается список ссылок, Base64 или Xray JSON";
    }
    if (error) *error = failure ?: @"Не удалось загрузить подписку";
    return nil;
}

- (NSString *)addURL:(NSString *)url error:(NSString **)error {
    url = [url stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *err = nil;
    NSString *deviceID = [self subscriptionDeviceID:&err];
    NSArray *lines = deviceID ? VLFetchLines(url, deviceID, &err) : nil;
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
    OGCoreLog(@"[vless] subscription added, %lu servers", (unsigned long)lines.count);
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
    NSString *deviceID = [self subscriptionDeviceID:&err];
    NSArray *lines = deviceID ? VLFetchLines(url, deviceID, &err) : nil;
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
    OGCoreLog(@"[vless] %lu/%lu subscriptions synced, %lu servers (+%lu -%lu)", (unsigned long)(count - failed),
         (unsigned long)count, (unsigned long)total, (unsigned long)added, (unsigned long)removed);
    DLog(@"[vless] подписки обновлены: %@", [report componentsJoinedByString:@"; "]);
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
            if (now - fetched >= kVLRefreshEvery && (!failed || now - tried >= kVLRetryAfterFailure)) {
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
