#import "OGOnegramCore.h"
#import "AWGConfig.h"
#import "OGPowerTunnel.h"
#import "PowerSubscriptions.h"
#import "AWGCrypto.h"
#import "AWGTunnel.h"
#import "AWGWarpRegistrar.h"
#import "OGDanteSocket.h"
#import <Security/Security.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <errno.h>
#include <arpa/inet.h>
#include <string.h>

NSString * const OGOnegramCoreDidChangeNotification = @"OGOnegramCoreDidChangeNotification";
static NSString * const OGCoreModeKey = @"OGOnegramCoreMode";
static NSString * const OGCorePreferredModeKey = @"OGOnegramCorePreferredMode";

static NSMutableDictionary *OGWarpKeychainQuery(void)
{
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            (id)kSecClassGenericPassword, (id)kSecClass,
            @"Onegram.DanteWARP", (id)kSecAttrService,
            @"identity", (id)kSecAttrAccount, nil];
}

static AWGConfig *OGLoadWarpConfig(NSError **error)
{
    NSMutableDictionary *query = OGWarpKeychainQuery();
    [query setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) return nil;
    if (status != errSecSuccess) {
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return nil;
    }
    AWGConfig *config = nil;
    @try {
        id object = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)result];
        if ([object isKindOfClass:[AWGConfig class]]) config = object;
    } @catch (NSException *exception) {
        config = nil;
    }
    CFRelease(result);
    struct in_addr address;
    NSString *ip = [[config.ipv4Address componentsSeparatedByString:@"/"] objectAtIndex:0];
    if ([AWGCrypto base64Decode:config.privateKey].length != 32 ||
        [AWGCrypto base64Decode:config.peerPublicKey].length != 32 ||
        !config.hasReservedBytes || !ip || inet_pton(AF_INET, [ip UTF8String], &address) != 1 ||
        config.peerEndpoint.length == 0) {
        if (error) *error = [NSError errorWithDomain:@"OnegramWARP" code:1
                                          userInfo:[NSDictionary dictionaryWithObject:@"Saved WARP identity is invalid" forKey:NSLocalizedDescriptionKey]];
        return nil;
    }
    return config;
}

static BOOL OGSaveWarpConfig(AWGConfig *config, NSError **error)
{
    NSMutableDictionary *query = OGWarpKeychainQuery();
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:config];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:data forKey:(id)kSecValueData];
    OSStatus status = SecItemUpdate((CFDictionaryRef)query, (CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        [query addEntriesFromDictionary:attributes];
        status = SecItemAdd((CFDictionaryRef)query, NULL);
    }
    if (status != errSecSuccess && error)
        *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    return status == errSecSuccess;
}

@interface OGOnegramCore () {
    NSCondition *_condition;
    OGOnegramCoreMode _mode;
    OGOnegramCoreMode _preferredMode;
    OGOnegramCoreState _state;
    NSError *_lastError;
    AWGTunnel *_activeTunnel;
    OGPowerTunnel *_activePower;
    OGPowerTunnel *_pendingPower;
    NSUInteger _generation;
    int _listener;
    uint16_t _socksPort;
    NSUInteger _clientCount;
    BOOL _powerProbeRequested;
    NSMutableSet *_webSocketConnections;
    NSError *_webSocketError;
}
- (void)updateWebSocketStateLocked;
@end

@implementation OGOnegramCore

+ (OGOnegramCore *)sharedCore
{
    static OGOnegramCore *core;
    @synchronized(self) {
        if (!core) core = [[self alloc] init];
    }
    return core;
}

- (id)init
{
    self = [super init];
    if (self) {
        _condition = [[NSCondition alloc] init];
        _listener = -1;
        _webSocketConnections = [[NSMutableSet alloc] init];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults objectForKey:OGCoreModeKey]) {
            NSNumber *previousMode = [defaults objectForKey:@"OGOnegramProxyMode"];
            NSInteger initialMode = previousMode != nil ? [previousMode integerValue] : ([defaults boolForKey:@"TGOnegramWebSocketEnabled"] ? OGOnegramCoreModeWebSocket : OGOnegramCoreModeNone);
            [defaults setInteger:initialMode forKey:OGCoreModeKey];
            [defaults synchronize];
        }
        NSInteger stored = [defaults integerForKey:OGCoreModeKey];
        _mode = stored >= OGOnegramCoreModeNone && stored <= OGOnegramCoreModeDantePower ? stored : OGOnegramCoreModeNone;
        NSInteger preferred = [defaults objectForKey:OGCorePreferredModeKey] != nil ? [defaults integerForKey:OGCorePreferredModeKey] : _mode;
        _preferredMode = preferred > OGOnegramCoreModeNone && preferred <= OGOnegramCoreModeDantePower ? preferred : OGOnegramCoreModeWebSocket;
        _state = _mode == OGOnegramCoreModeNone ? OGOnegramCoreStateDisabled : OGOnegramCoreStateConnecting;
        if (_mode == OGOnegramCoreModeDanteWARP || _mode == OGOnegramCoreModeDantePower) [self startListener];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(powerSettingsChanged:) name:PowerSubscriptionsDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(foreground:) name:@"UIApplicationWillEnterForegroundNotification" object:nil];
        [NSThread detachNewThreadSelector:@selector(worker) toTarget:self withObject:nil];
    }
    return self;
}

- (OGOnegramCoreMode)mode { [_condition lock]; OGOnegramCoreMode value = _mode; [_condition unlock]; return value; }
- (OGOnegramCoreMode)preferredMode { [_condition lock]; OGOnegramCoreMode value = _preferredMode; [_condition unlock]; return value; }
- (OGOnegramCoreState)state { [_condition lock]; OGOnegramCoreState value = _state; [_condition unlock]; return value; }
- (uint16_t)socksPort { [_condition lock]; uint16_t value = _socksPort; [_condition unlock]; return value; }
- (NSError *)lastError { [_condition lock]; NSError *value = [[_lastError retain] autorelease]; [_condition unlock]; return value; }

- (void)postChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OGOnegramCoreDidChangeNotification object:self];
}

- (void)notifyChange
{
    [self performSelectorOnMainThread:@selector(postChange) withObject:nil waitUntilDone:NO];
}

- (void)setMode:(OGOnegramCoreMode)mode
{
    if (mode < OGOnegramCoreModeNone || mode > OGOnegramCoreModeDantePower) return;
    [_condition lock];
    _mode = mode;
    _generation++;
    [_pendingPower stop];
    [_activePower stop];
    [_activePower release];
    _activePower = nil;
    [_activeTunnel release];
    _activeTunnel = nil;
    [_lastError release];
    _lastError = nil;
    [_webSocketError release];
    _webSocketError = nil;
    _state = mode == OGOnegramCoreModeNone ? OGOnegramCoreStateDisabled : OGOnegramCoreStateConnecting;
    if (mode == OGOnegramCoreModeWebSocket) [self updateWebSocketStateLocked];
    if (mode == OGOnegramCoreModeDanteWARP || mode == OGOnegramCoreModeDantePower) [self startListener];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:mode forKey:OGCoreModeKey];
    if (mode != OGOnegramCoreModeNone) {
        _preferredMode = mode;
        [defaults setInteger:mode forKey:OGCorePreferredModeKey];
    }
    [defaults setBool:mode == OGOnegramCoreModeWebSocket forKey:@"TGOnegramWebSocketEnabled"];
    [defaults synchronize];
    [_condition broadcast];
    [_condition unlock];
    [self notifyChange];
}

- (void)reconnect { [self setMode:self.mode]; }

- (void)updateWebSocketStateLocked
{
    if (_mode != OGOnegramCoreModeWebSocket) return;
    [_lastError release];
    if (_webSocketConnections.count != 0) {
        _state = OGOnegramCoreStateConnected;
        _lastError = nil;
    } else if (_webSocketError != nil) {
        _state = OGOnegramCoreStateFailed;
        _lastError = [_webSocketError retain];
    } else {
        _state = OGOnegramCoreStateConnecting;
        _lastError = nil;
    }
}

- (void)webSocketConnectionOpened:(id)connection
{
    if (connection == nil) return;
    [_condition lock];
    [_webSocketConnections addObject:connection];
    [_webSocketError release];
    _webSocketError = nil;
    [self updateWebSocketStateLocked];
    [_condition unlock];
    [self notifyChange];
}

- (void)webSocketConnectionClosed:(id)connection
{
    if (connection == nil) return;
    [_condition lock];
    [_webSocketConnections removeObject:connection];
    [self updateWebSocketStateLocked];
    [_condition unlock];
    [self notifyChange];
}

- (void)webSocketUnavailableWithError:(NSError *)error
{
    [_condition lock];
    [_webSocketError release];
    _webSocketError = [error retain];
    [self updateWebSocketStateLocked];
    [_condition unlock];
    [self notifyChange];
}

- (void)powerSettingsChanged:(NSNotification *)notification {
    if (self.mode == OGOnegramCoreModeDantePower) [self reconnect];
}

- (void)foreground:(NSNotification *)notification
{
    [_condition lock];
    if (_mode == OGOnegramCoreModeDantePower) {
        _powerProbeRequested = YES;
        [_condition broadcast];
    }
    if (_mode == OGOnegramCoreModeDanteWARP &&
        ((_activeTunnel && (_activeTunnel.handshakeAge >= 110 || _activeTunnel.state != AWGTunnelStateConnected)) || _state == OGOnegramCoreStateFailed)) {
        _generation++;
        [_activeTunnel release];
        _activeTunnel = nil;
        _state = OGOnegramCoreStateConnecting;
        [_condition broadcast];
    }
    [_condition unlock];
    [self notifyChange];
}

- (void)startListener
{
    if (_listener >= 0) return;
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    socklen_t length = sizeof(address);
    if (fd < 0 || bind(fd, (struct sockaddr *)&address, length) != 0 ||
        listen(fd, 32) != 0 || getsockname(fd, (struct sockaddr *)&address, &length) != 0) {
        int failure = errno;
        if (fd >= 0) close(fd);
        _state = OGOnegramCoreStateFailed;
        [_lastError release];
        _lastError = [[NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:nil] retain];
        return;
    }
    _listener = fd;
    _socksPort = ntohs(address.sin_port);
    [NSThread detachNewThreadSelector:@selector(acceptClients) toTarget:self withObject:nil];
}

- (void)acceptClients
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    for (;;) {
        NSAutoreleasePool *iteration = [[NSAutoreleasePool alloc] init];
        [_condition lock];
        while (_clientCount >= 32) [_condition wait];
        [_condition unlock];
        int fd = accept(_listener, NULL, NULL);
        if (fd < 0) {
            if (errno != EINTR) {
                [_condition lock];
                [_condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
                [_condition unlock];
            }
            [iteration drain];
            continue;
        }
        if (OGDanteSocketPrepare(fd) < 0) {
            close(fd);
            [iteration drain];
            continue;
        }
        struct timeval timeout = {20, 0};
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
        [_condition lock];
        _clientCount++;
        [_condition unlock];
        NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(serveClient:) object:[NSNumber numberWithInt:fd]];
        [thread setStackSize:256 * 1024];
        [thread start];
        [thread release];
        [iteration drain];
    }
    [pool drain];
}

- (void)serveClient:(NSNumber *)number
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int fd = [number intValue];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:25];
    [_condition lock];
    NSUInteger generation = _generation;
    while (!_activeTunnel && !_activePower && (_mode == OGOnegramCoreModeDanteWARP || _mode == OGOnegramCoreModeDantePower) &&
           generation == _generation && [deadline timeIntervalSinceNow] > 0)
        [_condition waitUntilDate:deadline];
    AWGTunnel *tunnel = [_activeTunnel retain];
    OGPowerTunnel *power = [_activePower retain];
    [_condition unlock];
    if (tunnel) [tunnel handleSOCKSClient:fd];
    else if (power) [power handleSOCKSClient:fd];
    else close(fd);
    [power release];
    [tunnel release];
    [_condition lock];
    _clientCount--;
    [_condition broadcast];
    [_condition unlock];
    [pool drain];
}

- (void)runPowerGeneration:(NSUInteger)generation
{
    [_condition lock];
    if (generation != _generation || _mode != OGOnegramCoreModeDantePower) { [_condition unlock]; return; }
    [self startListener];
    NSError *error = _socksPort ? nil : [[_lastError retain] autorelease];
    _state = OGOnegramCoreStateConnecting;
    _powerProbeRequested = NO;
    [_condition unlock];
    [self notifyChange];
    OGPowerTunnel *power = [[OGPowerTunnel alloc] init];
    [_condition lock];
    if (generation != _generation || _mode != OGOnegramCoreModeDantePower) {
        [_condition unlock];
        [power release];
        return;
    }
    _pendingPower = [power retain];
    [_condition unlock];
    BOOL connected = !error && [power startWithError:&error];
    [_condition lock];
    [_pendingPower release];
    _pendingPower = nil;
    if (generation == _generation && _mode == OGOnegramCoreModeDantePower) {
        if (connected) _activePower = [power retain];
        _state = connected ? OGOnegramCoreStateConnected : OGOnegramCoreStateFailed;
        [_lastError release];
        _lastError = [error retain];
        [_condition broadcast];
    }
    [_condition unlock];
    [self notifyChange];
    [_condition lock];
    NSDate *nextProbe = [NSDate dateWithTimeIntervalSinceNow:30];
    while (connected && generation == _generation && _mode == OGOnegramCoreModeDantePower && power.connected) {
        [_condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        if ((_powerProbeRequested || [nextProbe timeIntervalSinceNow] <= 0) && generation == _generation) {
            _powerProbeRequested = NO;
            [_condition unlock];
            [power checkHealth];
            nextProbe = [NSDate dateWithTimeIntervalSinceNow:30];
            [_condition lock];
        }
    }
    if (_activePower == power) {
        [_activePower release]; _activePower = nil;
        if (generation == _generation) {
            _state = OGOnegramCoreStateFailed;
            [_lastError release];
            _lastError = [[NSError errorWithDomain:@"Onegram.Power" code:3 userInfo:
                [NSDictionary dictionaryWithObject:@"Соединение Power прервано. Повторный выбор сервера…" forKey:NSLocalizedDescriptionKey]] retain];
        }
    }
    [_condition unlock];
    [power stop];
    [power release];
    [self notifyChange];
    [_condition lock];
    NSDate *retryAt = [NSDate dateWithTimeIntervalSinceNow:10];
    while (generation == _generation && _mode == OGOnegramCoreModeDantePower && !_powerProbeRequested && [retryAt timeIntervalSinceNow] > 0)
        [_condition waitUntilDate:retryAt];
    _powerProbeRequested = NO;
    [_condition unlock];
}

- (void)worker
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    AWGConfig *config = nil;
    AWGTunnel *tunnel = nil;
    NSUInteger attempts = 0;
    for (;;) {
        NSAutoreleasePool *iteration = [[NSAutoreleasePool alloc] init];
        [_condition lock];
        while (_mode != OGOnegramCoreModeDanteWARP && _mode != OGOnegramCoreModeDantePower) [_condition wait];
        if (_mode == OGOnegramCoreModeDantePower) {
            NSUInteger powerGeneration = _generation;
            [_condition unlock];
            [self runPowerGeneration:powerGeneration];
            [iteration drain];
            continue;
        }
        NSUInteger generation = _generation;
        [self startListener];
        NSError *error = _socksPort ? nil : [[_lastError retain] autorelease];
        _state = OGOnegramCoreStateConnecting;
        [_lastError release];
        _lastError = nil;
        [_condition unlock];
        [self notifyChange];
        if (!config && !error) config = [OGLoadWarpConfig(&error) retain];
        if (!config && !error) {
            config = [[AWGWarpRegistrar generateConfigWithError:&error] retain];
            if (config && !OGSaveWarpConfig(config, &error)) {
                [config release];
                config = nil;
            }
        }
        [_condition lock];
        BOOL current = generation == _generation && _mode == OGOnegramCoreModeDanteWARP;
        [_condition unlock];
        if (config && current && self.socksPort) {
            if (attempts) [AWGWarpRegistrar rotateEndpointForConfig:config];
            tunnel = [[AWGTunnel alloc] initWithConfig:config];
            tunnel.startsSOCKSListener = NO;
            if (![tunnel startWithError:&error]) {
                [tunnel stop];
                [tunnel release];
                tunnel = nil;
            }
        }
        [_condition lock];
        current = generation == _generation && _mode == OGOnegramCoreModeDanteWARP;
        if (current) {
            _activeTunnel = [tunnel retain];
            _state = tunnel ? OGOnegramCoreStateConnected : OGOnegramCoreStateFailed;
            [_lastError release];
            _lastError = [error retain];
            [_condition broadcast];
        }
        [_condition unlock];
        [self notifyChange];
        if (tunnel) attempts = 0;
        [_condition lock];
        while (tunnel && generation == _generation && _mode == OGOnegramCoreModeDanteWARP &&
               tunnel.state == AWGTunnelStateConnected) {
            NSDate *deadline = [[NSDate alloc] initWithTimeIntervalSinceNow:1];
            [_condition waitUntilDate:deadline];
            [deadline release];
        }
        if (_activeTunnel == tunnel) {
            [_activeTunnel release];
            _activeTunnel = nil;
        }
        [_condition unlock];
        [tunnel stop];
        [tunnel release];
        tunnel = nil;
        [_condition lock];
        if (generation == _generation && _mode == OGOnegramCoreModeDanteWARP) {
            attempts++;
            NSDate *retryAt = [NSDate dateWithTimeIntervalSinceNow:MIN(30, 2 * MIN(attempts, 15))];
            while (generation == _generation && _mode == OGOnegramCoreModeDanteWARP && [retryAt timeIntervalSinceNow] > 0)
                [_condition waitUntilDate:retryAt];
        }
        if (generation != _generation || _mode != OGOnegramCoreModeDanteWARP) attempts = 0;
        [_condition unlock];
        [iteration drain];
    }
    [config release];
    [pool drain];
}

@end
