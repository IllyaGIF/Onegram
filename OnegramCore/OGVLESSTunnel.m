#import "OGVLESSTunnel.h"
#import "VLESSConfig.h"
#import "VLESSSelector.h"
#import "VLESSSession.h"
#import "VLESSSubscriptions.h"
#import "OGCoreSOCKS.h"
#import "OGCoreSocket.h"
#include <unistd.h>
#include <sys/socket.h>

static const NSUInteger OGVLESSRelayFailureLimit = 3;

@implementation OGVLESSTunnel {
    VLESSConfig *_config;
    VLESSSelector *_selector;
    NSMutableSet *_sessions;
    NSMutableSet *_clients;
    BOOL _connected;
    BOOL _stopped;
    NSUInteger _relayFailures;
}

- (id)init {
    self = [super init];
    if (self) {
        _clients = [[NSMutableSet alloc] init];
        _sessions = [[NSMutableSet alloc] init];
        _selector = [[VLESSSelector alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    [_config release];
    [_selector release];
    [_sessions release];
    [_clients release];
    [super dealloc];
}

- (BOOL)connected { @synchronized (self) { return _connected; } }
- (NSString *)serverName { @synchronized (self) { return [[_config.name retain] autorelease]; } }

- (BOOL)startWithError:(NSError **)error {
    VLESSSubscriptions *subscriptions = [VLESSSubscriptions shared];
    if (subscriptions.storageError) { if (error) *error = subscriptions.storageError; return NO; }
    [subscriptions refreshIfStale];
    NSMutableArray *configs = [NSMutableArray array];
    NSString *selectedLine = subscriptions.selectedLine;
    for (NSString *line in [subscriptions allLines]) {
        if (selectedLine && ![selectedLine isEqualToString:line]) continue;
        VLESSConfig *config = [VLESSConfig configFromURI:line];
        if (config) [configs addObject:config];
    }
    VLESSSelector *selector = _selector;
    VLESSConfig *selected = [selector chooseWorkingFrom:configs timeout:8];
    @synchronized (self) {
        if (selected && !_stopped) {
            _config = [selected retain];
            _connected = YES;
        }
        if (!_connected && error)
            *error = [NSError errorWithDomain:@"Onegram.VLESS" code:1 userInfo:
                [NSDictionary dictionaryWithObject:selector.lastReport forKey:NSLocalizedDescriptionKey]];
        return _connected;
    }
}

- (BOOL)checkHealth {
    VLESSSession *session;
    @synchronized (self) {
        if (_stopped || !_connected) return NO;
        session = [[VLESSSession alloc] initWithConfig:_config];
        [_sessions addObject:session];
    }
    VLProbeResult result = [session probeThroughHost:@"www.google.com" port:80 timeout:8 latencyMillis:NULL];
    if (result != VLProbeOK && result != VLProbeUnsupported)
        result = [session probeThroughHost:@"www.google.com" port:80 timeout:8 latencyMillis:NULL];
    @synchronized (self) {
        [_sessions removeObject:session];
        if (result == VLProbeOK) _relayFailures = 0;
        else _connected = NO;
    }
    [session release];
    return result == VLProbeOK;
}

- (void)stop {
    @synchronized (self) {
        _stopped = YES;
        _connected = NO;
        [_selector cancelSearch];
        for (VLESSSession *session in _sessions) [session cancel];
        for (NSNumber *client in _clients) shutdown([client intValue], SHUT_RDWR);
    }
}

- (void)handleSOCKSClient:(int)fd {
    int control = OGCoreSocketDuplicate(fd);
    if (control < 0) { close(fd); return; }
    NSNumber *key = [NSNumber numberWithInt:control];
    @synchronized (self) {
        if (!_connected || _stopped) { close(control); close(fd); return; }
        [_clients addObject:key];
    }
    OGCoreSOCKSRequest request;
    if (OGCoreReadSOCKSRequest(fd, &request)) {
        VLESSSession *session;
        @synchronized (self) {
            session = [[VLESSSession alloc] initWithConfig:_config];
            [_sessions addObject:session];
            if (_stopped) [session cancel];
        }
        const uint8_t success[] = {5, 0, 0, 1, 0, 0, 0, 0, 0, 0};
        NSData *reply = [NSData dataWithBytes:success length:sizeof(success)];
        BOOL handled = [session relayClient:fd host:[NSString stringWithUTF8String:request.host]
                                      port:request.port okReply:reply initialData:nil];
        @synchronized (self) {
            [_sessions removeObject:session];
            if (handled) _relayFailures = 0;
            else if (!_stopped && ++_relayFailures >= OGVLESSRelayFailureLimit) _connected = NO;
        }
        [session release];
        if (!handled) {
            const uint8_t failure[] = {5, 1, 0, 1, 0, 0, 0, 0, 0, 0};
            OGCoreSocketSend(fd, failure, sizeof(failure));
            close(fd);
        }
    } else close(fd);
    @synchronized (self) {
        [_clients removeObject:key];
        close(control);
    }
}

@end
