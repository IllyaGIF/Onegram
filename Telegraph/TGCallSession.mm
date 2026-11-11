#import "TGCallSession.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <libkern/OSAtomic.h>

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#include <syslog.h>
#import "../submodules/MtProtoKit/MTProtoKit/MTProtoKit.h"

#import "TGAppDelegate.h"
#import "TGTelegramNetworking.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGAudioSessionManager.h"
#import "TGCallVideoCapturer.h"
#import "TGCallVideoView.h"

#import "TGCallUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"

#import "TGCallSignals.h"
#import "TGCallAudioPlayer.h"
#import "TGCallKitAdapter.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

#import "VoIPController.h"
#import "VoIPServerConfig.h"
#import "os/darwin/SetupLogging.h"

static NSString *OGCompatCurrentCallsConfig = nil;

@interface NSObject (OGCompatWebrtcDynamic)

+ (NSArray *)versionsWithIncludeReference:(bool)includeReference;
+ (void)applyServerConfig:(NSString *)data;
+ (bool)supportsVideoSending;
+ (bool)supportsVideoReceiving;

- (instancetype)initWithVersion:(NSString *)version customParameters:(NSString *)customParameters queue:(id)queue proxy:(id)proxy networkType:(int32_t)networkType dataSaving:(int32_t)dataSaving derivedState:(NSData *)derivedState key:(NSData *)key isOutgoing:(bool)isOutgoing connections:(NSArray *)connections maxLayer:(int32_t)maxLayer allowP2P:(bool)allowP2P allowTCP:(bool)allowTCP enableStunMarking:(bool)enableStunMarking logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath sendSignalingData:(void (^)(NSData *))sendSignalingData videoCapturer:(id)videoCapturer preferredVideoCodec:(NSString *)preferredVideoCodec audioInputDeviceId:(NSString *)audioInputDeviceId audioDevice:(id)audioDevice directConnection:(id)directConnection;
- (instancetype)initWithReflectorId:(uint8_t)reflectorId hasStun:(bool)hasStun hasTurn:(bool)hasTurn hasTcp:(bool)hasTcp ip:(NSString *)ip port:(int32_t)port username:(NSString *)username password:(NSString *)password;
- (void)setSignalBarsChanged:(void (^)(int32_t))signalBarsChanged;
- (void)setStateChanged:(void (^)(int32_t, int32_t, int32_t, int32_t, int32_t, float))stateChanged;
- (void)addSignalingData:(NSData *)data;
- (void)setIsMuted:(bool)isMuted;
- (void)setNetworkType:(int32_t)networkType;
- (void)setOutgoingVideoEnabled:(bool)enabled;
- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer;
- (void)setIncomingVideoView:(TGCallVideoView *)view;
- (void)stop:(void (^)(NSString *debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;

@end

static Class OGCompatWebrtcContextClass()
{
    return NSClassFromString(@"OngoingCallThreadLocalContextWebrtc");
}

@interface OGCompatMainQueue : NSObject

- (void)dispatch:(void (^)())block;
- (bool)isCurrent;
- (id)scheduleBlock:(void (^)())block after:(double)timeout;

@end

@implementation OGCompatMainQueue

- (void)dispatch:(void (^)())block
{
    if (block != nil)
        dispatch_async(dispatch_get_main_queue(), block);
}

- (bool)isCurrent
{
    return [[NSThread currentThread] isMainThread];
}

- (id)scheduleBlock:(void (^)())block after:(double)timeout
{
    __block bool cancelled = false;
    int64_t delayNanoseconds = (int64_t)(timeout * NSEC_PER_SEC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delayNanoseconds), dispatch_get_main_queue(), ^{
        if (cancelled == false && block != nil)
            block();
    });
    
    return [[SBlockDisposable alloc] initWithBlock:^{
        cancelled = true;
    }];
}

@end

static TGCallTransmissionState OGCompatTransmissionStateForCode(int32_t code)
{
    switch (code)
    {
        case 1:
            return TGCallTransmissionStateEstablished;
        case 2:
            return TGCallTransmissionStateFailed;
        case 3:
            return TGCallTransmissionStateReconnecting;
        default:
            return TGCallTransmissionStateInitializing;
    }
}

static int32_t OGCompatNetworkCodeForType(TGNetworkType networkType)
{
    switch (networkType)
    {
        case TGNetworkTypeGPRS:
            return 1;
        case TGNetworkTypeEdge:
            return 2;
        case TGNetworkType3G:
            return 3;
        case TGNetworkTypeLTE:
            return 4;
        default:
            return 0;
    }
}

static NSArray *OGCompatIpCandidates(NSString *ipv4, NSString *ipv6)
{
    return @[ipv4 ?: @"", ipv6 ?: @""];
}

static bool OGCompatPortIsValid(int port)
{
    return port > 0 && port <= 65535;
}

static NSString *OGCompatSelectLibraryVersion(NSArray *serverVersions, NSArray *supportedVersions)
{
    for (id candidate in serverVersions)
    {
        if ([candidate isKindOfClass:[NSString class]] && [supportedVersions containsObject:candidate])
            return candidate;
    }
    return nil;
}

static NSArray *OGCompatOrderedRelays(TGCallStateData *state)
{
    NSMutableArray *ordered = [[NSMutableArray alloc] init];
    TGCallConnectionDescription *primary = state.connection.defaultConnection;
    if (primary != nil)
        [ordered addObject:primary];
    for (TGCallConnectionDescription *alternative in state.connection.alternativeConnections)
    {
        if (alternative != nil)
            [ordered addObject:alternative];
    }
    return ordered;
}

static NSArray *OGCompatBuildWebrtcEndpoints(Class endpointClass, TGCallStateData *state)
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    void (^appendEndpoint)(id) = ^(id endpoint) {
        if (endpoint != nil)
            [result addObject:endpoint];
    };
    
    NSArray *relays = OGCompatOrderedRelays(state);
    
    NSMutableSet *knownIds = [[NSMutableSet alloc] init];
    for (TGCallConnectionDescription *relay in relays)
        [knownIds addObject:@(relay.identifier)];
    NSArray *sortedIds = [[knownIds allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableDictionary *compactIds = [[NSMutableDictionary alloc] init];
    for (NSUInteger position = 0; position < sortedIds.count && position < 255; position++)
        compactIds[sortedIds[position]] = @(position + 1);
    
    for (TGCallConnectionDescription *relay in relays)
    {
        NSNumber *compactId = compactIds[@(relay.identifier)];
        if (compactId == nil || !OGCompatPortIsValid(relay.port) || relay.peerTag.length < 16)
            continue;
        
        const uint8_t *tagBytes = static_cast<const uint8_t *>(relay.peerTag.bytes);
        NSMutableString *relayPassword = [[NSMutableString alloc] initWithCapacity:32];
        for (NSUInteger position = 0; position < 16; position++)
            [relayPassword appendFormat:@"%02x", tagBytes[position]];
        
        for (NSString *ip in OGCompatIpCandidates(relay.ipv4, relay.ipv6))
        {
            if (ip.length != 0)
                appendEndpoint([[endpointClass alloc] initWithReflectorId:[compactId unsignedCharValue] hasStun:false hasTurn:true hasTcp:relay.isTcp ip:ip port:relay.port username:@"reflector" password:relayPassword]);
        }
    }
    
    for (TGCallWebrtcConnectionDescription *direct in state.connection.webrtcConnections)
    {
        if (!OGCompatPortIsValid(direct.port))
            continue;
        for (NSString *ip in OGCompatIpCandidates(direct.ipv4, direct.ipv6))
        {
            if (ip.length != 0)
                appendEndpoint([[endpointClass alloc] initWithReflectorId:0 hasStun:direct.stun hasTurn:direct.turn hasTcp:false ip:ip port:direct.port username:direct.username ?: @"" password:direct.password ?: @""]);
        }
    }
    return result;
}

@interface OGCompatWebrtcRuntime : NSObject

@property (nonatomic, strong) id context;
@property (nonatomic, strong) OGCompatMainQueue *queue;
@property (nonatomic, readonly) bool started;
@property (nonatomic, copy) void (^remoteMediaChanged)(int32_t videoState, int32_t audioState);

+ (bool)supportsVideoSending;
+ (bool)supportsVideoReceiving;

- (bool)startWithState:(TGCallStateData *)state outgoing:(bool)outgoing logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath signalBarsChanged:(void (^)(int32_t))signalBarsChanged stateChanged:(void (^)(TGCallTransmissionState))stateChanged;
- (void)receiveSignalingData:(NSData *)data;
- (void)setMuted:(bool)muted;
- (void)setNetworkType:(int32_t)networkType;
- (void)setOutgoingVideoEnabled:(bool)enabled;
- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer;
- (void)setIncomingVideoView:(TGCallVideoView *)view;
- (void)stopWithCompletion:(void (^)(NSString *debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;

@end

@implementation OGCompatWebrtcRuntime {
    bool _started;
}

- (bool)started
{
    return _started ? true : false;
}

- (id)og_compat_contextHandling:(SEL)selector
{
    id current = self.context;
    return (current != nil && [current respondsToSelector:selector]) ? current : nil;
}

- (bool)startWithState:(TGCallStateData *)state outgoing:(bool)outgoing logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath signalBarsChanged:(void (^)(int32_t))signalBarsChanged stateChanged:(void (^)(TGCallTransmissionState))stateChanged
{
    Class contextClass = OGCompatWebrtcContextClass();
    Class connectionClass = NSClassFromString(@"OngoingCallConnectionDescriptionWebrtc");
    if (contextClass == nil || connectionClass == nil) {
        TGDiagnosticLog(@"CALL webrtc.runtime.missing contextClass=%@ connectionClass=%@", contextClass, connectionClass);
        return false;
    }
    
    NSArray *supportedVersions = [NSArray array];
    if ([contextClass respondsToSelector:@selector(versionsWithIncludeReference:)])
    {
        NSArray *reported = [(id)contextClass versionsWithIncludeReference:false];
        if ([reported isKindOfClass:[NSArray class]])
            supportedVersions = reported;
    }
    
    NSArray *serverVersions = state.connection.libraryVersions;
    if (![serverVersions isKindOfClass:[NSArray class]])
        serverVersions = [NSArray array];
    
    NSString *version = OGCompatSelectLibraryVersion(serverVersions, supportedVersions);
    if (version.length == 0)
    {
        TGDiagnosticLog(@"CALL webrtc.version.mismatch call=%lld server=%@ local=%@",
              state.callId,
              serverVersions,
              supportedVersions);
        return false;
    }
    
    if (state.connection.key.length != 256)
        return false;
    
    NSArray *endpoints = OGCompatBuildWebrtcEndpoints(connectionClass, state);
    if (endpoints.count == 0)
        return false;
    
    OGCompatMainQueue *queue = [[OGCompatMainQueue alloc] init];
    self.queue = queue;
    
    void (^sendSignalingData)(NSData *) = ^(NSData *data) {
        [[TGCallSignals sendSignalingDataForCallId:state.callId accessHash:state.accessHash data:data] startWithNext:nil error:^(id error) {
            TGDiagnosticLog(@"CALL webrtc.signaling.send.error call=%lld error=%@", state.callId, error);
        } completed:nil];
    };
    
    NSString *customParameters = state.connection.customParameters.length != 0 ? state.connection.customParameters : @"{}";
    
    int32_t maxLayer = state.connection.maxLayer > 0 ? state.connection.maxLayer : TGCallLegacyMaxLayer;
    id context = [[contextClass alloc] initWithVersion:version customParameters:customParameters queue:queue proxy:nil networkType:0 dataSaving:0 derivedState:[NSData data] key:state.connection.key isOutgoing:outgoing connections:endpoints maxLayer:maxLayer allowP2P:false allowTCP:true enableStunMarking:false logPath:logPath ?: @"" statsLogPath:statsLogPath ?: @"" sendSignalingData:sendSignalingData videoCapturer:nil preferredVideoCodec:nil audioInputDeviceId:@"" audioDevice:nil directConnection:nil];
    if (context == nil)
        return false;
    
    self.context = context;
    
    if ([context respondsToSelector:@selector(setStateChanged:)])
    {
        __weak OGCompatWebrtcRuntime *weakRuntime = self;
        [context setStateChanged:^(int32_t callState, int32_t __unused videoState, int32_t remoteVideoState, int32_t remoteAudioState, int32_t __unused remoteBatteryLevel, float __unused remotePreferredAspectRatio)
         {
             __strong OGCompatWebrtcRuntime *strongRuntime = weakRuntime;
             if (strongRuntime != nil && strongRuntime.remoteMediaChanged != nil)
                 strongRuntime.remoteMediaChanged(remoteVideoState, remoteAudioState);
             
             if (stateChanged != nil)
                 stateChanged(OGCompatTransmissionStateForCode(callState));
         }];
    }
    
    if ([context respondsToSelector:@selector(setSignalBarsChanged:)])
    {
        [context setSignalBarsChanged:^(int32_t bars)
         {
             if (signalBarsChanged != nil)
                 signalBarsChanged(bars);
         }];
    }
    
    _started = true;
    return true;
}

- (void)receiveSignalingData:(NSData *)data
{
    if (data.length == 0)
        return;
    [[self og_compat_contextHandling:@selector(addSignalingData:)] addSignalingData:data];
}

+ (bool)supportsVideoSending
{
    Class contextClass = OGCompatWebrtcContextClass();
    return contextClass != nil && [contextClass respondsToSelector:@selector(supportsVideoSending)] && [contextClass supportsVideoSending];
}

+ (bool)supportsVideoReceiving
{
    Class contextClass = OGCompatWebrtcContextClass();
    return contextClass != nil && [contextClass respondsToSelector:@selector(supportsVideoReceiving)] && [contextClass supportsVideoReceiving];
}

- (void)setOutgoingVideoEnabled:(bool)enabled
{
    [[self og_compat_contextHandling:@selector(setOutgoingVideoEnabled:)] setOutgoingVideoEnabled:enabled];
}

- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer
{
    [[self og_compat_contextHandling:@selector(setVideoCapturer:)] setVideoCapturer:capturer];
}

- (void)setIncomingVideoView:(TGCallVideoView *)view
{
    [[self og_compat_contextHandling:@selector(setIncomingVideoView:)] setIncomingVideoView:view];
}

- (void)setMuted:(bool)muted
{
    [[self og_compat_contextHandling:@selector(setIsMuted:)] setIsMuted:muted];
}

- (void)setNetworkType:(int32_t)networkType
{
    [[self og_compat_contextHandling:@selector(setNetworkType:)] setNetworkType:OGCompatNetworkCodeForType((TGNetworkType)networkType)];
}

- (void)stopWithCompletion:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion
{
    id finishing = self.context;
    _started = false;
    self.context = nil;
    
    if (finishing != nil && [finishing respondsToSelector:@selector(stop:)])
        [finishing stop:completion];
    else if (completion != nil)
        completion(@"", 0, 0, 0, 0);
}

@end

typedef enum
{
    TGCallToneUndefined,
    TGCallToneRingback,
    TGCallToneBusy,
    TGCallToneConnecting,
    TGCallToneFailed,
    TGCallToneEnded
} TGCallTone;

@interface VoIPControllerHolder : NSObject {
    tgvoip::VoIPController *_controller;
}

@property (nonatomic, assign, readonly) tgvoip::VoIPController *controller;

@end

@implementation VoIPControllerHolder

- (instancetype)initWithController:(tgvoip::VoIPController *)controller {
    self = [super init];
    if (self != nil) {
        _controller = controller;
    }
    return self;
}

- (tgvoip::VoIPController *)controller {
    return _controller;
}

@end

const NSTimeInterval TGCallReceiveTimeout = 90;
const NSTimeInterval TGCallRingTimeout = 90;
const NSTimeInterval TGCallConnectTimeout = 30;
const NSTimeInterval TGCallPacketTimeout = 10;

@interface TGCallAudioContext : NSObject

@property (nonatomic, readonly) NSArray *availableRoutes;
@property (nonatomic, readonly) TGAudioRoute *activeRoute;
@property (nonatomic, readonly) bool speaker;

- (instancetype)initWithAvailableRoutes:(NSArray *)availableRoutes activeRoute:(TGAudioRoute *)activeRoute speaker:(bool)speaker;

@end



@interface TGCallSession ()
{
    SMetaDisposable *_networkDisposable;
    SMetaDisposable *_disposable;
    SMetaDisposable *_timeoutDisposable;
    
    SVariable *_state;
    SPipe *_statePipe;
    TGCallState _currentState;
    
    SVariable *_transmissionState;
    SPipe *_transmissionPipe;
    TGCallTransmissionState _previousTransmissionState;
    
    SVariable *_signalBarsState;
    SPipe *_signalBarsPipe;
    
    SPipe *_audioTogglesPipe;
    SPipe *_audioContextPipe;
    
    bool _started;
    bool _discarded;
    NSNumber *_internalId;
    SAtomic *_controller;
    
    TGUser *_peer;
    
    CFAbsoluteTime _startTime;
    NSTimeInterval _callAcceptedTime;
    
    NSData *_keySha1;
    NSData *_keySha256;
    
    bool _playingRingtone;
    TGCallAudioPlayer *_audioPlayer;
    SMetaDisposable *_vibrateDisposable;
    
    bool _muted;
    bool _speaker;
    NSNumber *_targetSpeaker;
    NSNumber *_delayedSpeaker;
    OSSpinLock _speakerLock;
    
    TGObserverProxy *_applicationWillResignActiveProxy;
    TGObserverProxy *_applicationDidBecomeActiveProxy;
    
    id _notification;
    NSMutableArray *_pendingSignalingData;
    OGCompatWebrtcRuntime *_webrtcRuntime;

    SPipe *_videoPipe;
    bool _localVideoEnabled;
    int32_t _remoteVideoState;
    bool _remoteMuted;
    TGCallVideoCapturer *_videoCapturer;
    __weak TGCallVideoView *_incomingVideoView;
    bool _speakerForcedForVideo;
}

@property (nonatomic, copy) void (^hangUpCompletion)(void);

@end

@implementation TGCallSession

- (instancetype)initOutgoing:(bool)outgoing
{
    self = [super init];
    if (self != nil)
    {
        _outgoing = outgoing;
        
        _statePipe = [[SPipe alloc] init];
        _state = [[SVariable alloc] init];
        [_state set:_statePipe.signalProducer()];
        
        _transmissionPipe = [[SPipe alloc] init];
        _transmissionState = [[SVariable alloc] init];
        [_transmissionState set:_transmissionPipe.signalProducer()];
        _previousTransmissionState = TGCallTransmissionStateInitializing;
        
        _signalBarsPipe = [[SPipe alloc] init];
        _signalBarsState = [[SVariable alloc] init];
        [_signalBarsState set:_signalBarsPipe.signalProducer()];
        _signalBarsPipe.sink(@4);
        _pendingSignalingData = [[NSMutableArray alloc] init];
        
        _audioTogglesPipe = [[SPipe alloc] init];
        [self _updateAudioToggles];
        _videoPipe = [[SPipe alloc] init];
        
        _applicationWillResignActiveProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification];
        _applicationDidBecomeActiveProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification];
    }
    return self;
}

- (instancetype)initWithSignal:(SSignal *)signal outgoing:(bool)outgoing
{
    self = [self initOutgoing:outgoing];
    if (self != nil)
    {
        [self startWithSignal:signal];
    }
    return self;
}

- (void)dealloc
{
    [_videoCapturer stop];
    [_webrtcRuntime stopWithCompletion:nil];
    [_disposable dispose];
    [_networkDisposable dispose];
    [_timeoutDisposable dispose];
    [_vibrateDisposable dispose];
}

- (void)receiveSignalingData:(NSData *)data
{
    if (data.length == 0)
        return;
    
    OGCompatWebrtcRuntime *runtime = nil;
    @synchronized(self)
    {
        if (_webrtcRuntime != nil && _webrtcRuntime.started)
        {
            runtime = _webrtcRuntime;
        }
        else
        {
            if (_pendingSignalingData.count >= 64)
                [_pendingSignalingData removeObjectAtIndex:0];
            [_pendingSignalingData addObject:[data copy]];
        }
    }
    
    if (runtime != nil)
    {
        [runtime receiveSignalingData:data];
    }
}

- (void)_flushPendingSignalingData
{
    NSArray *pending = nil;
    OGCompatWebrtcRuntime *runtime = nil;
    @synchronized(self)
    {
        if (_webrtcRuntime == nil || !_webrtcRuntime.started || _pendingSignalingData.count == 0)
            return;
        runtime = _webrtcRuntime;
        pending = [_pendingSignalingData copy];
        [_pendingSignalingData removeAllObjects];
    }
    
    for (NSData *data in pending)
        [runtime receiveSignalingData:data];
}

- (void)markCallAcceptedTime
{
    _callAcceptedTime = CFAbsoluteTimeGetCurrent();
}

- (NSTimeInterval)callConnectionDuration
{
    if (_callAcceptedTime > DBL_EPSILON && _startTime > DBL_EPSILON)
        return _startTime - _callAcceptedTime;
    
    return 0.0;
}

- (void)startWithSignal:(SSignal *)signal
{
    [self _setCallSignal:signal];
}

- (void)_setCallSignal:(SSignal *)signal
{
    __weak TGCallSession *weakSelf = self;
    _disposable = [[SMetaDisposable alloc] init];
    [_disposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(TGCallStateData *next)
                                {
                                    __strong TGCallSession *strongSelf = weakSelf;
                                    if (strongSelf != nil)
                                        [strongSelf updateWithState:next];
                                } error:^(__unused id error)
                                {
                                    __strong TGCallSession *strongSelf = weakSelf;
                                    if (strongSelf == nil)
                                        return;
                                } completed:^
                                {
                                }]];
}

static void controllerStateCallback(tgvoip::VoIPController *controller, int state)
{
    TGCallSession *session = (__bridge TGCallSession *)controller->implData;
    [session controllerStateChanged:state];
}

static void loggingFunction(NSString *string)
{
}

- (void)_controllerInit
{
    _controller = [[SAtomic alloc] initWithValue:nil recursive:true];
    [_controller modify:^id(VoIPControllerHolder *current) {
        assert(current == nil);
        
        TGVoipLoggingFunction = &loggingFunction;
        
        tgvoip::VoIPController *controller = new tgvoip::VoIPController();
        controller->implData = (__bridge void *)self;
        
        tgvoip::VoIPController::Callbacks callbacks;
        callbacks.connectionStateChanged = &controllerStateCallback;
        callbacks.signalBarCountChanged = &signalBarsCallback;
        controller->SetCallbacks(callbacks);
        
        tgvoip::VoIPController::crypto.sha1 = &TGCallSha1;
        tgvoip::VoIPController::crypto.sha256 = &TGCallSha256;
        tgvoip::VoIPController::crypto.rand_bytes = &TGCallRandomBytes;
        tgvoip::VoIPController::crypto.aes_ige_encrypt = &TGCallAesIgeEncryptInplace;
        tgvoip::VoIPController::crypto.aes_ige_decrypt = &TGCallAesIgeDecryptInplace;
        tgvoip::VoIPController::crypto.aes_ctr_encrypt = &TGCallAesCtrEncrypt;
        
        return [[VoIPControllerHolder alloc] initWithController:controller];
    }];
}

- (void)og_compat_applyTransmissionState:(TGCallTransmissionState)newState
{
    TGDispatchOnMainThread(^
    {
        if (newState == _previousTransmissionState)
            return;
        
        if (newState == TGCallTransmissionStateEstablished && _startTime < DBL_EPSILON)
        {
            _startTime = CFAbsoluteTimeGetCurrent();
            
            if (self.onConnected != nil)
                self.onConnected();
        }
        
        _transmissionPipe.sink(@(newState));
        
        switch (newState)
        {
            case TGCallTransmissionStateReconnecting:
                if (_webrtcRuntime.started)
                    TGDiagnosticLog(@"CALL webrtc.skipTone reconnecting");
                else
                    [self playTone:TGCallToneConnecting];
                break;
                
            case TGCallTransmissionStateEstablished:
                [self stopAudio];
                break;
                
            case TGCallTransmissionStateFailed:
                [self playTone:TGCallToneEnded];
                [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
                break;
                
            default:
                break;
        }
        
        _previousTransmissionState = newState;
    });
}

- (void)controllerStateChanged:(int)state
{
    TGCallTransmissionState tranmissionState = TGCallTransmissionStateInitializing;
    switch (state)
    {
        case tgvoip::STATE_ESTABLISHED:
            tranmissionState = TGCallTransmissionStateEstablished;
            break;
            
        case tgvoip::STATE_FAILED:
            tranmissionState = TGCallTransmissionStateFailed;
            break;
            
        case tgvoip::STATE_RECONNECTING:
            tranmissionState = TGCallTransmissionStateReconnecting;
            break;
            
        default:
            break;
    }
    
    [self og_compat_applyTransmissionState:tranmissionState];
}

- (void)webrtcTransmissionStateChanged:(TGCallTransmissionState)tranmissionState
{
    [self og_compat_applyTransmissionState:tranmissionState];
}

#pragma mark - Signal Bars

static void signalBarsCallback(tgvoip::VoIPController *controller, int bars)
{
    TGCallSession *session = (__bridge TGCallSession *)controller->implData;
    [session signalBarsChanged:bars];
}

- (void)signalBarsChanged:(int)bars
{
    TGDispatchOnMainThread(^
                           {
                               _signalBarsPipe.sink(@(bars));
                           });
}

#pragma mark - Transmission

- (NSString *)callLogsPath
{
    NSString *path = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"calls"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil])
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:true attributes:nil error:nil];
    
    NSMutableArray *logs = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil] mutableCopy];
    if (logs.count > 20)
    {
        NSString *oldestLogPath = [path stringByAppendingPathComponent:logs.firstObject];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:oldestLogPath error:nil];
        NSDate *oldestDate = attributes.fileModificationDate;
        
        for (NSString *log in logs)
        {
            if ([log hasSuffix:@".log"])
            {
                NSString *logPath = [path stringByAppendingPathComponent:log];
                NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:logPath error:nil];
                NSDate *date = attributes.fileModificationDate;
                if ([date compare:oldestDate] == NSOrderedAscending)
                {
                    oldestLogPath = logPath;
                    oldestDate = date;
                }
            }
        }
        
        [[NSFileManager defaultManager] removeItemAtPath:oldestLogPath error:nil];
        [logs removeObject:oldestLogPath.lastPathComponent];
    }
    
    return path;
}

- (NSString *)og_compat_callLogPathForState:(TGCallStateData *)state
{
    NSString *fileName = [NSString stringWithFormat:@"%lld-%lld.log", state.callId, state.accessHash];
    return [[self callLogsPath] stringByAppendingPathComponent:fileName];
}

- (void)og_compat_launchWebrtcForState:(TGCallStateData *)state
{
    NSString *logPath = [self og_compat_callLogPathForState:state];
    NSString *statsLogPath = [logPath stringByAppendingPathExtension:@"json"];
    if (_webrtcRuntime == nil)
        _webrtcRuntime = [[OGCompatWebrtcRuntime alloc] init];
    
    __weak TGCallSession *weakSession = self;
    _webrtcRuntime.remoteMediaChanged = ^(int32_t videoState, int32_t audioState) {
        [weakSession _remoteMediaChangedWithVideoState:videoState audioState:audioState];
    };
    void (^barsHandler)(int32_t) = ^(int32_t bars) {
        [weakSession signalBarsChanged:bars];
    };
    void (^stateHandler)(TGCallTransmissionState) = ^(TGCallTransmissionState transmissionState) {
        [weakSession webrtcTransmissionStateChanged:transmissionState];
    };
    
    if ([_webrtcRuntime startWithState:state outgoing:_outgoing logPath:logPath statsLogPath:statsLogPath signalBarsChanged:barsHandler stateChanged:stateHandler])
    {
        [self _flushPendingSignalingData];
        [_webrtcRuntime setMuted:_muted];
        [self _webrtcRuntimeDidStart];
        [self startNetworkTypeMonitoring];
        if (self.onStartedConnecting != nil)
            self.onStartedConnecting();
        return;
    }
    
    TGDiagnosticLog(@"CALL webrtc.engine.missing call=%lld storedWebRtc=%d usingLegacyLibtgvoip=0 signalingApiReady=1 hardBlock=1", state.callId, (int)state.connection.webrtcConnections.count);
    [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
}

- (void)og_compat_recordTrafficIncomingMobile:(int64_t)incomingMobile incomingWifi:(int64_t)incomingWifi outgoingMobile:(int64_t)outgoingMobile outgoingWifi:(int64_t)outgoingWifi
{
    MTNetworkUsageManager *usageManager = [[MTNetworkUsageManager alloc] initWithInfo:[[TGTelegramNetworking instance] mediaUsageInfoForType:TGNetworkMediaTypeTagCall]];
    [usageManager addIncomingBytes:(NSUInteger)incomingMobile interface:MTNetworkUsageManagerInterfaceWWAN];
    [usageManager addIncomingBytes:(NSUInteger)incomingWifi interface:MTNetworkUsageManagerInterfaceOther];
    
    [usageManager addOutgoingBytes:(NSUInteger)outgoingMobile interface:MTNetworkUsageManagerInterfaceWWAN];
    [usageManager addOutgoingBytes:(NSUInteger)outgoingWifi interface:MTNetworkUsageManagerInterfaceOther];
}

- (void)og_compat_uploadDebugLog:(NSString *)debugLog ifRequested:(bool)requested
{
    if (requested && _callId != 0 && self.accessHash != 0 && debugLog.length != 0)
        [[TGCallSignals saveCallDebug:_callId accessHash:self.accessHash data:debugLog] startWithNext:nil];
}

- (void)startTransmissionIfNeeded:(TGCallStateData *)state
{
    if (_started)
        return;
    
    _started = true;
    
    void (^block)(void) = ^
    {
        bool hasLegacyRelay = false;
        
        TGCallConnectionDescription *defaultConnection =
        state.connection.defaultConnection;
        
        if (defaultConnection != nil &&
            (defaultConnection.ipv4.length != 0 ||
             defaultConnection.ipv6.length != 0) &&
            defaultConnection.peerTag.length >= 16)
        {
            hasLegacyRelay = true;
        }
        
        if (!hasLegacyRelay)
        {
            for (TGCallConnectionDescription *connection
                 in state.connection.alternativeConnections)
            {
                if (connection != nil &&
                    (connection.ipv4.length != 0 ||
                     connection.ipv6.length != 0) &&
                    connection.peerTag.length >= 16)
                {
                    hasLegacyRelay = true;
                    break;
                }
            }
        }
        
        bool hasWebRtc =
        state.connection.webrtcConnections.count != 0;
        
        bool hasTgCallsProtocol =
        state.connection.libraryVersions.count != 0;
        
        bool useWebRtc =
        (hasWebRtc || hasLegacyRelay) && hasTgCallsProtocol;
        
        
        
        
        if (!useWebRtc)
        {
            [self playTone:TGCallToneConnecting];
        }
        
        SSignal *readySignal = [SSignal single:@true];
        if (_hasCallKit && _audioSessionActivated != nil)
            readySignal = _audioSessionActivated.signal;
        
        [[[[readySignal filter:^bool(NSNumber *value) {
            return value;
        }] timeout:10.5 onQueue:[SQueue mainQueue] orSignal:[SSignal single:@true]] take:1] startWithNext:^(__unused id next)
         {
             if (useWebRtc)
             {
                 [self og_compat_launchWebrtcForState:state];
                 return;
             }
             
             if (_controller == nil)
                 [self _controllerInit];
             
             __block bool didStartTransmission = false;
             [_controller with:^id(VoIPControllerHolder *controller) {
                 std::vector<tgvoip::Endpoint> endpoints;
                 NSArray *connections = OGCompatOrderedRelays(state);
                 
                 NSString *logPath = [self og_compat_callLogPathForState:state];
                 
                 for (TGCallConnectionDescription *connection in connections)
                 {
                     if (connection == nil)
                         continue;
                     
                     if (connection.peerTag.length < 16)
                     {
                         continue;
                     }
                     
                     if (iosMajorVersion() <= 6)
                     {
                         if (connection.ipv4.length == 0)
                         {
                             continue;
                         }
                         
                         
                         struct in_addr addrIpV4;
                         
                         if (inet_aton(connection.ipv4.UTF8String, &addrIpV4) == 0)
                         {
                             TGDiagnosticLog(@"CALL voip.endpoint.skip call=%lld id=%lld reason=invalidIPv4 ip=%@",
                                   state.callId,
                                   connection.identifier,
                                   connection.ipv4);
                             continue;
                         }
                         
                         
                         tgvoip::IPv4Address address(
                                                     std::string(connection.ipv4.UTF8String)
                                                     );
                         
                         
                         tgvoip::IPv6Address addressv6;
                         
                         unsigned char peerTag[16];
                         memset(peerTag, 0, sizeof(peerTag));
                         
                         [connection.peerTag getBytes:peerTag
                                                range:NSMakeRange(0, 16)];
                         
                         
                         tgvoip::Endpoint endpoint(
                                                   connection.identifier,
                                                   (uint16_t)connection.port,
                                                   address,
                                                   addressv6,
                                                   connection.isTcp ? tgvoip::Endpoint::TYPE_TCP_RELAY : tgvoip::Endpoint::TYPE_UDP_RELAY,
                                                   peerTag
                                                   );
                         
                         endpoints.push_back(endpoint);
                         
                         
                         continue;
                     }
                     
                     if (connection.ipv4.length == 0 &&
                         connection.ipv6.length == 0)
                     {
                         continue;
                     }
                     
                     tgvoip::IPv4Address address;
                     tgvoip::IPv6Address addressv6;
                     
                     if (connection.ipv4.length != 0)
                     {
                         struct in_addr addrIpV4;
                         
                         if (!inet_aton(connection.ipv4.UTF8String, &addrIpV4))
                         {
                             TGDiagnosticLog(@"CallSession: invalid ipv4 address %@",
                                   connection.ipv4);
                             continue;
                         }
                         
                         address =
                         tgvoip::IPv4Address(
                                             std::string(connection.ipv4.UTF8String)
                                             );
                     }
                     
                     if (connection.ipv6.length != 0)
                     {
                         struct in6_addr addrIpV6;
                         
                         if (!inet_pton(AF_INET6,
                                        connection.ipv6.UTF8String,
                                        &addrIpV6))
                         {
                             TGDiagnosticLog(@"CallSession: invalid ipv6 address %@",
                                   connection.ipv6);
                             continue;
                         }
                         
                         addressv6 =
                         tgvoip::IPv6Address(
                                             std::string(connection.ipv6.UTF8String)
                                             );
                     }
                     
                     unsigned char peerTag[16];
                     memset(peerTag, 0, sizeof(peerTag));
                     
                     [connection.peerTag getBytes:peerTag
                                            range:NSMakeRange(0, 16)];
                     
                     endpoints.push_back(
                                         tgvoip::Endpoint(
                                                          connection.identifier,
                                                          (uint16_t)connection.port,
                                                          address,
                                                          addressv6,
                                                          connection.isTcp ? tgvoip::Endpoint::TYPE_TCP_RELAY : tgvoip::Endpoint::TYPE_UDP_RELAY,
                                                          peerTag
                                                          )
                                         );
                 }
                 
                 
                 if (endpoints.empty())
                 {
                     
                     [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
                     return nil;
                 }
                 
                 tgvoip::VoIPController::Config config([TGCallSession callConnectTimeout], [TGCallSession callPacketTimeout], TGAppDelegateInstance.callsDataUsageMode, false, true, true);
                 
                 config.logFilePath = std::string([logPath UTF8String]);
                 
                 if (TGAppDelegateInstance.callsUseProxy)
                 {
                     MTSocksProxySettings *proxySettings = [[TGTelegramNetworking instance] context].apiEnvironment.socksProxySettings;
                     if (proxySettings != nil && proxySettings.secret.length == 0) {
                         std::string username = "";
                         if (proxySettings.username != nil) {
                             username = std::string(proxySettings.username.UTF8String);
                         }
                         std::string password = "";
                         if (proxySettings.password != nil) {
                             password = std::string(proxySettings.password.UTF8String);
                         }
                         
                         controller.controller->SetProxy(tgvoip::PROXY_SOCKS5, std::string(proxySettings.ip.UTF8String), proxySettings.port, username, password);
                     }
                 }
                 
                 NSData *phoneCallsP2PContactsData = [TGDatabaseInstance() customProperty:@"phoneCallsP2PContacts"];
                 int32_t phoneCallsP2PContacts = 0;
                 if (phoneCallsP2PContactsData.length == 4) {
                     [phoneCallsP2PContactsData getBytes:&phoneCallsP2PContacts];
                 }
                 
                 int32_t defaultMode = phoneCallsP2PContacts ? 3 : 2;
                 int32_t p2pMode = TGAppDelegateInstance.callsP2PMode;
                 if (p2pMode == 0)
                     p2pMode = defaultMode;
                 
                 bool allowP2P = false;
                 switch (p2pMode)
                 {
                     case 0:
                         allowP2P = [TGDatabaseInstance() uidIsRemoteContact:state.peerId];
                         break;
                         
                     case 2:
                         allowP2P = true;
                         break;
                         
                     default:
                         break;
                 }
                 
                 controller.controller->SetConfig(config);
                 
                 int32_t connectionMaxLayer =
                 state.connection.maxLayer > 0
                 ? state.connection.maxLayer
                 : TGCallLegacyMaxLayer;
                 
                 
                 if (state.connection.key.length != 256)
                 {
                     [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
                     return nil;
                 }
                 
                 controller.controller->SetEncryptionKey(
                                                         (char *)state.connection.key.bytes,
                                                         _outgoing
                                                         );
                 
                 controller.controller->SetRemoteEndpoints(
                                                           endpoints,
                                                           allowP2P,
                                                           connectionMaxLayer
                                                           );
                 
                 controller.controller->Start();
                 controller.controller->SetMicMute(_muted);
                 controller.controller->Connect();
                 
                 [self startNetworkTypeMonitoring];
                 
                 didStartTransmission = true;
                 
                 
                 return nil;
             }];
             
             if (didStartTransmission && self.onStartedConnecting != nil)
                 self.onStartedConnecting();
         }];
    };
    
    if (_hasCallKit)
        block();
    else
        [self setupAudioSession:block];
}

- (void)stopTransmission:(bool)sendDebugLog
{
    @synchronized(self)
    {
        [_pendingSignalingData removeAllObjects];
    }
    TGDispatchOnMainThread(^
    {
        [_videoCapturer stop];
        _localVideoEnabled = false;
        _remoteVideoState = 0;
        [self _updateVideoState];
    });
    if (_webrtcRuntime.started) {
        OGCompatWebrtcRuntime *runtime = _webrtcRuntime;
        _webrtcRuntime = nil;
        [runtime stopWithCompletion:^(NSString *debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile) {
            [self og_compat_recordTrafficIncomingMobile:bytesReceivedMobile incomingWifi:bytesReceivedWifi outgoingMobile:bytesSentMobile outgoingWifi:bytesSentWifi];
            [self og_compat_uploadDebugLog:debugLog ifRequested:sendDebugLog];
        }];
    }
    
    if (_controller == nil)
        return;
    
    [_controller modify:^id(VoIPControllerHolder *controller) {
        NSString *debugLog = @"";
        size_t debugLogLength = controller.controller->GetDebugLogLength();
        if (debugLogLength > 0)
        {
            char *buffer = (char *)malloc(debugLogLength + 1);
            if (buffer != NULL)
            {
                memset(buffer, 0, debugLogLength + 1);
                controller.controller->GetDebugLog(buffer);
                NSString *decodedDebugLog = [[NSString alloc] initWithUTF8String:buffer];
                if (decodedDebugLog != nil)
                    debugLog = decodedDebugLog;
                free(buffer);
            }
        }
        
        tgvoip::VoIPController::TrafficStats stats;
        controller.controller->GetStats(&stats);
        controller.controller->Stop();
        delete controller.controller;
        
        [self og_compat_recordTrafficIncomingMobile:stats.bytesRecvdMobile incomingWifi:stats.bytesRecvdWifi outgoingMobile:stats.bytesSentMobile outgoingWifi:stats.bytesSentWifi];
        [self og_compat_uploadDebugLog:debugLog ifRequested:sendDebugLog];
        
        return nil;
    }];
    _controller = nil;
}

- (void)startNetworkTypeMonitoring
{
    __weak TGCallSession *weakSelf = self;
    _networkDisposable = [[SMetaDisposable alloc] init];
    [_networkDisposable setDisposable:[[[TGTelegraphInstance.networkTypeManager networkTypeSignal] ignoreRepeated] startWithNext:^(NSNumber *next)
                                       {
                                           __strong TGCallSession *strongSelf = weakSelf;
                                           if (strongSelf == nil)
                                               return;
                                           
                                           TGNetworkType networkType = (TGNetworkType)next.integerValue;
                                           
                                           if (strongSelf->_webrtcRuntime.started)
                                               [strongSelf->_webrtcRuntime setNetworkType:(int32_t)networkType];
                                           
                                           if (strongSelf->_controller != nil)
                                           {
                                               int32_t legacyNetworkType = tgvoip::NET_TYPE_UNKNOWN;
                                               switch (networkType)
                                               {
                                                   case TGNetworkTypeGPRS:
                                                       legacyNetworkType = tgvoip::NET_TYPE_GPRS;
                                                       break;
                                                   case TGNetworkTypeEdge:
                                                       legacyNetworkType = tgvoip::NET_TYPE_EDGE;
                                                       break;
                                                   case TGNetworkType3G:
                                                       legacyNetworkType = tgvoip::NET_TYPE_3G;
                                                       break;
                                                   case TGNetworkTypeLTE:
                                                       legacyNetworkType = tgvoip::NET_TYPE_LTE;
                                                       break;
                                                   case TGNetworkTypeWiFi:
                                                       legacyNetworkType = tgvoip::NET_TYPE_WIFI;
                                                       break;
                                                   default:
                                                       break;
                                               }
                                               
                                               [strongSelf->_controller with:^id(VoIPControllerHolder *controller) {
                                                   controller.controller->SetNetworkType(legacyNetworkType);
                                                   return nil;
                                               }];
                                           }
                                       }]];
}

#pragma mark - Actions

- (void)acceptIncomingCall
{
    if (_internalId != nil)
    {
        [self markCallAcceptedTime];
        [TGTelegraphInstance.callManager acceptCallWithInternalId:_internalId];
    }
}

- (void)hangUpCurrentCallCompletion:(void (^)())completion
{
    self.hangUpCompletion = completion;
    [self hangUpCurrentCall:false];
}

- (void)hangUpCurrentCall
{
    [self hangUpCurrentCall:false];
}

- (void)hangUpCurrentCall:(bool)external
{
    _completed = external;
    [[[_state.signal take:1] timeout:0.5 onQueue:[SQueue mainQueue] orSignal:[SSignal single:nil]] startWithNext:^(TGCallStateData *next)
     {
         TGCallDiscardReason reason = TGCallDiscardReasonHangup;
         if (next.state != TGCallStateOngoing)
             reason = _outgoing ? TGCallDiscardReasonMissed : TGCallDiscardReasonBusy;
         
         [self _discardCurrentCallWithReason:reason];
     }];
}

- (void)_discardCurrentCallWithReason:(TGCallDiscardReason)reason
{
    if (_internalId == nil || _discarded)
        return;
    
    _discarded = true;
    [TGTelegraphInstance.callManager discardCallWithInternalId:_internalId reason:reason];
}

#pragma mark - Timeout

- (void)startTimeout:(NSTimeInterval)duration discardReason:(TGCallDiscardReason)discardReason
{
    if (_timeoutDisposable == nil)
        _timeoutDisposable = [[SMetaDisposable alloc] init];
    
    __weak TGCallSession *weakSelf = self;
    [_timeoutDisposable setDisposable:[[[SSignal complete] delay:duration onQueue:[SQueue mainQueue]] startWithNext:nil completed:^
                                       {
                                           __strong TGCallSession *strongSelf = weakSelf;
                                           if (strongSelf != nil)
                                               [strongSelf _discardCurrentCallWithReason:discardReason];
                                       }]];
}

- (void)invalidateTimeout
{
    [_timeoutDisposable setDisposable:nil];
}

+ (NSTimeInterval)callReceiveTimeout
{
    int32_t value = (int32_t)TGCallReceiveTimeout;
    NSData *data = [TGDatabaseInstance() customProperty:@"callReceiveTimeout"];
    if (data.length >= 4)
    {
        [data getBytes:&value length:4];
        value /= 1000;
    }
    return MAX(value, 90);
}

+ (NSTimeInterval)callRingTimeout
{
    int32_t value = (int32_t)TGCallRingTimeout;
    NSData *data = [TGDatabaseInstance() customProperty:@"callRingTimeout"];
    if (data.length >= 4)
    {
        [data getBytes:&value length:4];
        value /= 1000;
    }
    return value;
}

+ (NSTimeInterval)callConnectTimeout
{
    int32_t value = (int32_t)TGCallConnectTimeout;
    NSData *data = [TGDatabaseInstance() customProperty:@"callConnectTimeout"];
    if (data.length >= 4)
    {
        [data getBytes:&value length:4];
        value /= 1000;
    }
    return value;
}

+ (NSTimeInterval)callPacketTimeout
{
    int32_t value = (int32_t)TGCallPacketTimeout;
    NSData *data = [TGDatabaseInstance() customProperty:@"callPacketTimeout"];
    if (data.length >= 4)
    {
        [data getBytes:&value length:4];
        value /= 1000;
    }
    return value;
}

+ (void)applyCallsConfig:(NSString *)data
{
    if (![data isKindOfClass:[NSString class]] || data.length == 0)
        return;
    
    OGCompatCurrentCallsConfig = [data copy];
    
    Class contextClass = OGCompatWebrtcContextClass();
    if (contextClass != nil &&
        [contextClass respondsToSelector:@selector(applyServerConfig:)])
    {
        [(id)contextClass applyServerConfig:data];
    }
    
    NSData *jsonData = [data dataUsingEncoding:NSUTF8StringEncoding];
    if (jsonData == nil)
        return;
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    if (![dict isKindOfClass:[NSDictionary class]] || dict.count == 0)
        return;
    
    int capacity = (int)dict.count * 2;
    char **values = (char **)malloc(sizeof(char *) * capacity);
    if (values == NULL)
        return;
    
    memset(values, 0, sizeof(char *) * capacity);
    
    __block int index = 0;
    [dict enumerateKeysAndObjectsUsingBlock:^(id rawKey, id value, __unused BOOL *stop)
     {
         if (index + 1 >= capacity)
             return;
         
         NSString *key = [rawKey isKindOfClass:[NSString class]]
         ? (NSString *)rawKey
         : [NSString stringWithFormat:@"%@", rawKey];
         
         NSString *valueText = [NSString stringWithFormat:@"%@", value];
         
         const char *keyText = [key UTF8String];
         const char *valueTextValue = [valueText UTF8String];
         
         if (keyText == NULL || valueTextValue == NULL)
             return;
         
         size_t keyLength = strlen(keyText);
         size_t valueLength = strlen(valueTextValue);
         
         values[index] = (char *)malloc(keyLength + 1);
         values[index + 1] = (char *)malloc(valueLength + 1);
         
         if (values[index] == NULL || values[index + 1] == NULL)
         {
             if (values[index] != NULL)
             {
                 free(values[index]);
                 values[index] = NULL;
             }
             
             if (values[index + 1] != NULL)
             {
                 free(values[index + 1]);
                 values[index + 1] = NULL;
             }
             
             return;
         }
         
         memcpy(values[index], keyText, keyLength + 1);
         memcpy(values[index + 1], valueTextValue, valueLength + 1);
         index += 2;
     }];
    
    if (index != 0)
        tgvoip::ServerConfig::GetSharedInstance()->Update((const char **)values, index);
    
    for (int i = 0; i < capacity; i++)
    {
        if (values[i] != NULL)
            free(values[i]);
    }
    
    free(values);
}

#pragma mark - Notifications

- (bool)_isInBackground
{
    UIApplicationState applicationState = [UIApplication sharedApplication].applicationState;
    if ([UIApplication sharedApplication] == nil)
        applicationState = UIApplicationStateBackground;
    
    return applicationState != UIApplicationStateActive;
}

- (void)presentCallNotification:(int64_t)peerId
{
    if ([self _isInBackground])
    {
        id notification = OGPlatformCreateLocalNotification();
        if (notification == nil)
            return;
        
        TGUser *peer = [TGDatabaseInstance() loadUser:peerId];
        NSString *peerName = peer.displayName;
        if (peerName.length == 0)
            peerName = TGLocalized(@"Call.UnknownCaller");
        if (peerName.length == 0 || [peerName isEqualToString:@"Call.UnknownCaller"])
            peerName = @"Telegram";
        NSString *text = [NSString stringWithFormat:TGLocalized(@"PHONE_CALL_REQUEST"), peerName];
        
        NSNumber *globalMessageSoundIdVal = nil;
        int globalMessageSoundId = 1;
        bool notFound = false;
        
        [TGDatabaseInstance() loadPeerNotificationSettings:TGPeerIdNotificationDefaultsPrivate soundId:&globalMessageSoundIdVal muteUntil:NULL previewText:NULL messagesMuted:NULL notFound:&notFound];
        if (notFound) {
            globalMessageSoundId = 1;
        }
        else {
            globalMessageSoundId = globalMessageSoundIdVal ? globalMessageSoundIdVal.intValue : 1;
        }
        
        notFound = false;
        
        NSNumber *soundIdVal = nil;
        int soundId = 1;
        [TGDatabaseInstance() loadPeerNotificationSettings:peerId soundId:&soundIdVal muteUntil:NULL previewText:NULL messagesMuted:NULL notFound:&notFound];
        
        if (soundIdVal != nil) {
            soundId = soundIdVal.intValue;
        } else {
            soundId = globalMessageSoundId;
        }
        
        if (soundId > 0)
            OGPlatformSetLocalNotificationSoundName(notification, [[NSString alloc] initWithFormat:@"%d.m4a", soundId]);
        
#ifdef INTERNAL_RELEASE
        text = [@"[L] " stringByAppendingString:text];
#endif
        OGPlatformSetLocalNotificationAlertBody(notification, text);
        OGPlatformSetLocalNotificationUserInfo(notification, @{@"cid": @(peerId)});
        if (text != nil)
            OGPlatformPresentLocalNotificationNow([UIApplication sharedApplication], notification);
        
        _notification = notification;
    }
}

- (void)cancelLocalNotification
{
    if (_notification == nil)
        return;
    
    OGPlatformCancelLocalNotification([UIApplication sharedApplication], _notification);
    _notification = nil;
}

- (void)applicationWillResignActive:(NSNotification *)__unused notification
{
    if (_hasCallKit)
        return;
    
    if (_playingRingtone && _audioPlayer != nil)
        [self stopAudio];
}

- (void)applicationDidBecomeActive:(NSNotification *)__unused notification
{
    if (_hasCallKit)
        return;
    
    if (_playingRingtone && _audioPlayer == nil)
        [self _startRingtonePlayer];
}

#pragma mark - Audio

static id<SDisposable> audioSession;

+ (SQueue *)audioQueue
{
    static dispatch_once_t onceToken;
    static SQueue *queue;
    dispatch_once(&onceToken, ^
                  {
                      queue = [[SQueue alloc] init];
                  });
    return queue;
}

- (void)setupAudioSession
{
    [TGCallSession setupAudioSession:nil];
}

- (void)setupAudioSession:(void (^)(void))completion
{
    [TGCallSession setupAudioSession:completion];
}

- (void)resetAudioSession
{
    [TGCallSession resetAudioSession];
}

- (void)resetAudioSessionIfNeeded
{
    if (!_hasCallKit)
        [self resetAudioSession];
}

+ (void)setupAudioSession:(void (^)(void))completion
{
    [[self audioQueue] dispatch:^
     {
         if (audioSession != nil)
         {
             TGDispatchOnMainThread(^
                                    {
                                        if (completion != nil)
                                            completion();
                                    });
             return;
         }
         
         const CFAbsoluteTime startedTime = CFAbsoluteTimeGetCurrent();
         audioSession = [[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypeCall interrupted:^{}];
         
         if (iosMajorVersion() >= 6)
         {
             AVAudioSession *session = [AVAudioSession sharedInstance];
             [session setPreferredIOBufferDuration:[TGAudioSessionManager callPreferredIOBufferDuration] error:NULL];
         }
         else
         {
             Float32 duration = (Float32)[TGAudioSessionManager callPreferredIOBufferDuration];
             AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(duration), &duration);
         }
         syslog(LOG_NOTICE, "IOS6MEDIA audio.session ms=%d", (int)((CFAbsoluteTimeGetCurrent() - startedTime) * 1000.0));
         
         TGDispatchOnMainThread(^
                                {
                                    if (completion != nil)
                                        completion();
                                });
     }];
}

+ (void)resetAudioSession
{
    [[self audioQueue] dispatch:^
     {
         if (audioSession == nil)
             return;
         
         [audioSession dispose];
         audioSession = nil;
         
         if (iosMajorVersion() >= 6)
         {
             AVAudioSession *session = [AVAudioSession sharedInstance];
             [session setPreferredIOBufferDuration:0.0 error:NULL];
         }
     } synchronous:true];
}

+ (bool)hasMicrophoneAccess
{
    if (iosMajorVersion() < 7)
        return true;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    return [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio] == AVAuthorizationStatusAuthorized;
#else
    return true;
#endif
}

- (void)toggleMute
{
    [self setMuted:!_muted];
}

- (void)setMuted:(bool)muted
{
    _muted = muted;
    if (_controller != nil) {
        [_controller with:^id(VoIPControllerHolder *controller) {
            controller.controller->SetMicMute(_muted);
            return nil;
        }];
    }
    
    if (_webrtcRuntime.started)
        [_webrtcRuntime setMuted:_muted];
    
    [self _updateAudioToggles];
}

- (void)toggleSpeaker
{
    bool newValue = !_speaker;
    
    OSSpinLockLock(&_speakerLock);
    _targetSpeaker = @(newValue);
    _delayedSpeaker = _targetSpeaker;
    OSSpinLockUnlock(&_speakerLock);
    
    [[TGCallSession audioQueue] dispatch:^
     {
         TGAudioRoute *route = newValue ? [TGAudioRoute routeForSpeaker] : [TGAudioRoute routeForBuiltIn:false];
         if (route != nil)
             [[TGAudioSessionManager instance] applyRoute:route];
         
         TGDispatchOnMainThread(^
                                {
                                    OSSpinLockLock(&_speakerLock);
                                    _targetSpeaker = nil;
                                    OSSpinLockUnlock(&_speakerLock);
                                });
     }];
    
    [self _updateAudioToggles];
}

- (void)applyAudioRoute:(TGAudioRoute *)audioRoute
{
    [[TGCallSession audioQueue] dispatch:^
     {
         [[TGAudioSessionManager instance] applyRoute:audioRoute];
         if (!audioRoute.isLoudspeaker)
         {
             OSSpinLockLock(&_speakerLock);
             _speaker = false;
             OSSpinLockUnlock(&_speakerLock);
         }
         
         [self _updateAudioToggles];
     }];
}

- (void)_updateAudioToggles
{
    _audioTogglesPipe.sink(@true);
}

#pragma mark - Video

+ (bool)supportsVideoSending
{
    return [OGCompatWebrtcRuntime supportsVideoSending];
}

+ (bool)supportsVideoReceiving
{
    return [OGCompatWebrtcRuntime supportsVideoReceiving];
}

- (bool)localVideoEnabled
{
    return _localVideoEnabled;
}

- (TGCallVideoCapturer *)videoCapturer
{
    return _videoCapturer;
}

- (void)setOutgoingVideoEnabled:(bool)enabled
{
    TGDispatchOnMainThread(^
    {
        bool value = enabled && [TGCallSession supportsVideoSending];
        if (value == _localVideoEnabled)
            return;
        _localVideoEnabled = value;
        if (value)
        {
            if (_videoCapturer == nil)
                _videoCapturer = [[TGCallVideoCapturer alloc] initWithMediaQueue:[TGCallSession audioQueue]];
            [_videoCapturer start];
            [self _routeToSpeakerForVideo];
        }
        else
        {
            [_videoCapturer stop];
        }
        if (_webrtcRuntime.started)
        {
            if (value)
                [_webrtcRuntime setVideoCapturer:_videoCapturer];
            [_webrtcRuntime setOutgoingVideoEnabled:value];
        }
        [self _updateVideoState];
    });
}

- (void)switchCamera
{
    TGDispatchOnMainThread(^
    {
        [_videoCapturer switchCamera];
        [self _updateVideoState];
    });
}

- (void)setIncomingVideoView:(TGCallVideoView *)view
{
    TGDispatchOnMainThread(^
    {
        _incomingVideoView = view;
        if (_webrtcRuntime.started)
            [_webrtcRuntime setIncomingVideoView:view];
    });
}

- (void)_webrtcRuntimeDidStart
{
    TGDispatchOnMainThread(^
    {
        if (!_webrtcRuntime.started)
            return;
        if (_incomingVideoView != nil)
            [_webrtcRuntime setIncomingVideoView:_incomingVideoView];
        if (_localVideoEnabled)
        {
            [_webrtcRuntime setVideoCapturer:_videoCapturer];
            [_webrtcRuntime setOutgoingVideoEnabled:true];
        }
    });
}

- (void)_remoteMediaChangedWithVideoState:(int32_t)videoState audioState:(int32_t)audioState
{
    TGDispatchOnMainThread(^
    {
        const bool changed = _remoteVideoState != videoState || _remoteMuted != (audioState == 0);
        _remoteVideoState = videoState;
        _remoteMuted = audioState == 0;
        if (videoState == 1)
            [self _routeToSpeakerForVideo];
        if (changed)
            [self _updateVideoState];
    });
}

static bool TGCallOutputIsBuiltInReceiver()
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    if (iosMajorVersion() >= 6)
    {
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        NSArray *outputs = audioSession.currentRoute.outputs;
        for (AVAudioSessionPortDescription *output in outputs)
        {
            if (![output.portType isEqualToString:AVAudioSessionPortBuiltInReceiver])
                return false;
        }
        return outputs.count != 0;
    }
#endif
    CFStringRef routeString = NULL;
    UInt32 routeStringSize = sizeof(routeString);
    if (AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &routeStringSize, &routeString) != noErr || routeString == NULL)
        return false;
    bool receiver = CFStringFind(routeString, CFSTR("Receiver"), 0).location != kCFNotFound && CFStringFind(routeString, CFSTR("Headset"), 0).location == kCFNotFound;
    CFRelease(routeString);
    return receiver;
}

- (void)_routeToSpeakerForVideo
{
    if (_speakerForcedForVideo || _speaker)
        return;
    __weak TGCallSession *weakSelf = self;
    [[TGCallSession audioQueue] dispatch:^
    {
        if (!TGCallOutputIsBuiltInReceiver())
            return;
        TGDispatchOnMainThread(^
        {
            __strong TGCallSession *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_speakerForcedForVideo || strongSelf->_speaker)
                return;
            strongSelf->_speakerForcedForVideo = true;
            [strongSelf toggleSpeaker];
        });
    }];
}

- (void)_updateVideoState
{
    _videoPipe.sink(@true);
}

- (void)_startRingtonePlayer
{
    _audioPlayer = [TGCallAudioPlayer playFileURL:[NSURL URLWithString:@"/Library/Ringtones/Opening.m4r"] loops:-1 completion:nil];
    
    _vibrateDisposable = [[SMetaDisposable alloc] init];
    [_vibrateDisposable setDisposable:[[[[SSignal single:nil] then:[[SSignal complete] delay:1.6 onQueue:[SQueue mainQueue]]] restart] startWithNext:^(__unused id next)
                                       {
                                           AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                                       }]];
}

- (void)playRingtone
{
    if ([TGCallKitAdapter callKitAvailable] || _audioPlayer != nil)
        return;
    
    _playingRingtone = true;
    if (![self _isInBackground])
        [self _startRingtonePlayer];
}

- (void)playTone:(TGCallTone)tone
{
    [self playTone:tone completion:nil];
}

- (void)playTone:(TGCallTone)tone completion:(void (^)(void))completion
{
    [self _playTone:[self _pathForTone:tone] loops:[self _loopsForTone:tone] completion:completion];
}

- (NSString *)_pathForTone:(TGCallTone)tone
{
    switch (tone)
    {
        case TGCallToneBusy:
            return [[NSBundle mainBundle] pathForResource:@"voip_busy" ofType:@"caf"];
            
        case TGCallToneRingback:
            return [[NSBundle mainBundle] pathForResource:@"voip_ringback" ofType:@"caf"];
            
        case TGCallToneConnecting:
            return [[NSBundle mainBundle] pathForResource:@"voip_connecting" ofType:@"mp3"];
            
        case TGCallToneFailed:
            return [[NSBundle mainBundle] pathForResource:@"voip_fail" ofType:@"caf"];
            
        case TGCallToneEnded:
            return [[NSBundle mainBundle] pathForResource:@"voip_end" ofType:@"caf"];
            
        default:
            return nil;
    }
}

- (NSInteger)_loopsForTone:(TGCallTone)tone
{
    switch (tone)
    {
        case TGCallToneBusy:
            return 3;
            
        case TGCallToneRingback:
            return -1;
            
        case TGCallToneConnecting:
            return -1;
            
        case TGCallToneFailed:
            return 1;
            
        case TGCallToneEnded:
            return 1;
            
        default:
            return 0;
    }
}

- (void)_playTone:(NSString *)path loops:(NSInteger)loops completion:(void (^)(void))completion
{
    if (_audioPlayer != nil || path == nil)
        return;
    
    [self setupAudioSession];
    
    _audioPlayer = [TGCallAudioPlayer playFileURL:[NSURL URLWithString:path] loops:loops completion:completion];
}

- (void)stopAudio
{
    _playingRingtone = false;
    
    [_audioPlayer stop];
    _audioPlayer = nil;
    
    [_vibrateDisposable setDisposable:nil];
    _vibrateDisposable = nil;
}

#pragma mark - State

- (void)updateWithState:(TGCallStateData *)state
{
    _internalId = state.internalId;
    if (state.peerId != 0)
    {
        TGUser *resolvedPeer = [TGDatabaseInstance() loadUser:state.peerId];
        if (resolvedPeer != nil)
        {
            _peer = resolvedPeer;
        }
    }
    
    if (_callId == 0 && state.callId != 0)
        _callId = state.callId;
    
    if (_accessHash == 0 && state.accessHash != 0)
        _accessHash = state.accessHash;
    
    if (_keySha256 == nil && state.connection.keyHash != nil)
        _keySha256 = state.connection.keyHash;
    
    TGCallState previousState = _currentState;
    _currentState = state.state;
    
    switch (state.state)
    {
        case TGCallStateWaiting:
        {
            [self startTimeout:[TGCallSession callReceiveTimeout] discardReason:TGCallDiscardReasonMissedTimeout];
        }
            break;
            
        case TGCallStateWaitingReceived:
            [self startTimeout:[TGCallSession callRingTimeout] discardReason:TGCallDiscardReasonMissedTimeout];
            [self playTone:TGCallToneRingback];
            break;
            
        case TGCallStateHandshake:
        {
            [self startTimeout:[TGCallSession callRingTimeout] discardReason:TGCallDiscardReasonMissedTimeout];
            [self playRingtone];
        }
            break;
            
        case TGCallStateReady:
        {
            [self startTimeout:[TGCallSession callRingTimeout] discardReason:TGCallDiscardReasonMissedTimeout];
            [self playRingtone];
        }
            break;
            
        case TGCallStateAccepting:
        {
            [self invalidateTimeout];
            [self stopAudio];
        }
            break;
            
        case TGCallStateOngoing:
        {
            [self invalidateTimeout];
            [self stopAudio];
            [self startTransmissionIfNeeded:state];
        }
            break;
            
        case TGCallStateEnded:
        case TGCallStateEnding:
        case TGCallStateBusy:
        case TGCallStateNoAnswer:
        case TGCallStateMissed:
        {
            if (!_hungUpOutside)
                _hungUpOutside = state.hungUpOutside;
            
            [self invalidateTimeout];
            [self stopAudio];
            [self stopTransmission:state.needsDebug];
            
            [self cancelLocalNotification];
            
            void (^completeHangup)(void) = ^
            {
                if (self.hangUpCompletion == nil || state.state != TGCallStateEnded)
                    return;
                
                SSignal *readySignal = [SSignal single:@true];
                if ([TGCallKitAdapter callKitAvailable])
                    readySignal = _audioSessionDeactivated.signal;
                
                [[[[readySignal filter:^bool(NSNumber *value) {
                    return value;
                }] timeout:1.5 onQueue:[SQueue mainQueue] orSignal:[SSignal single:@true]] take:1] startWithNext:^(__unused id next)
                 {
                     void (^completion)(void) = [self.hangUpCompletion copy];
                     self.hangUpCompletion = nil;
                     completion();
                 }];
            };
            
            if (_outgoing && (state.state == TGCallStateBusy || state.state == TGCallStateNoAnswer))
            {
                [self playTone:TGCallToneBusy];
                TGDispatchAfter(2.0, dispatch_get_main_queue(), ^
                                {
                                    [self resetAudioSessionIfNeeded];
                                });
            }
            else
            {
                TGCallTone tone = TGCallToneEnded;
                if (state.error != nil)
                    tone = TGCallToneFailed;
                
                if (!_outgoing && (previousState == TGCallStateHandshake || previousState == TGCallStateReady || previousState == TGCallStateMissed || previousState == TGCallStateEnding))
                    tone = TGCallToneUndefined;
                
                if (state.state == TGCallStateEnded || state.state == TGCallStateEnding)
                {
                    [self playTone:tone];
                    TGDispatchAfter(2.0, dispatch_get_main_queue(), ^
                                    {
                                        [self resetAudioSessionIfNeeded];
                                    });
                }
                else
                {
                    [self resetAudioSessionIfNeeded];
                }
                
                completeHangup();
            }
        }
            break;
            
        default:
            break;
    }
    
    if (state.error != nil)
        TGDiagnosticLog(@"Call Session: failed with error: %@", state.error);
    
    _statePipe.sink(state);
}

- (NSTimeInterval)duration
{
    if (_startTime > DBL_EPSILON)
        return CFAbsoluteTimeGetCurrent() - _startTime;
    return 0.0;
}

- (SSignal *)stateSignal
{
    __weak TGCallSession *weakSelf = self;
    
    SSignal *combinedSignal = [SSignal combineSignals:@[_state.signal, _signalBarsState.signal, [self audioContextSignal], _transmissionState.signal, _audioTogglesPipe.signalProducer(), _videoPipe.signalProducer()] withInitialStates:@[ [NSNull null], @0, [NSNull null], @0, @0, @0 ]];
    
    return [[combinedSignal deliverOn:[SQueue mainQueue]] map:^id(NSArray *values)
            {
                __strong TGCallSession *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return nil;
                
                TGCallStateData *stateData = [values[0] isKindOfClass:[NSNull class]] ? nil : (TGCallStateData *)values[0];
                if (stateData != nil && stateData.peerId != 0)
                {
                    TGUser *resolvedPeer = [TGDatabaseInstance() loadUser:stateData.peerId];
                    if (resolvedPeer != nil)
                    {
                        strongSelf->_peer = resolvedPeer;
                    }
                }
                NSInteger signalBars = [values[1] integerValue];
                TGCallAudioContext *audioContext = [values[2] isKindOfClass:[NSNull class]] ? nil : (TGCallAudioContext *)values[2];
                TGCallTransmissionState transmissionState = (TGCallTransmissionState)[values[3] integerValue];
                
                bool muted = strongSelf->_muted;
                bool speaker = strongSelf->_targetSpeaker ? strongSelf->_targetSpeaker.boolValue : audioContext.speaker;
                
                return [[TGCallSessionState alloc] initWithOutgoing:strongSelf->_outgoing callStateData:stateData transmissionState:transmissionState peer:strongSelf->_peer keySha256:strongSelf->_keySha256 startTime:strongSelf->_startTime signalBars:signalBars mute:muted speaker:speaker audioRoutes:audioContext.availableRoutes activeAudioRoute:audioContext.activeRoute isVideoCall:strongSelf.isVideoCall canSendVideo:[TGCallSession supportsVideoSending] localVideoEnabled:strongSelf->_localVideoEnabled remoteVideoActive:strongSelf->_remoteVideoState == 1 remoteVideoPaused:strongSelf->_remoteVideoState == 2 remoteMuted:strongSelf->_remoteMuted];
            }];
}

- (SSignal *)audioContextSignal
{
    __weak TGCallSession *weakSelf = self;
    return [[[SSignal combineSignals:@[_state.signal, _transmissionState.signal, [TGAudioSessionManager routeChange], _audioTogglesPipe.signalProducer(), [[[SSignal single:@true] delay:1.0 onQueue:[SQueue concurrentDefaultQueue]] restart]] withInitialStates:@[ [NSNull null], @0, @0, @0, @0 ]] deliverOn:[TGCallSession audioQueue]] map:^id(__unused NSArray *values)
            {
                __strong TGCallSession *strongSelf = weakSelf;
                
                TGCallStateData *stateData = [values[0] isKindOfClass:[NSNull class]] ? nil : (TGCallStateData *)values[0];
                TGCallState currentState = stateData.state;
                
                OSSpinLockLock(&_speakerLock);
                NSArray *inputs = nil;
                NSArray *outputs = nil;
                NSMutableArray *audioRoutes = [[NSMutableArray alloc] init];
                TGAudioRoute *activeRoute = nil;
                bool hasHeadphones = false;
                bool legacySpeaker = false;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
                AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                if (iosMajorVersion() >= 7)
                {
                    inputs = audioSession.availableInputs;
                    outputs = audioSession.currentRoute.outputs;
                }
                else if (iosMajorVersion() >= 6)
                {
                    outputs = audioSession.currentRoute.outputs;
                }
                else
                {
                    CFDictionaryRef routeDescription = NULL;
                    UInt32 routeDescriptionSize = sizeof(routeDescription);
                    if (AudioSessionGetProperty(kAudioSessionProperty_AudioRouteDescription, &routeDescriptionSize, &routeDescription) == noErr && routeDescription != NULL)
                    {
                        CFArrayRef routeOutputs = (CFArrayRef)CFDictionaryGetValue(routeDescription, kAudioSession_AudioRouteKey_Outputs);
                        if (routeOutputs != NULL)
                        {
                            CFIndex count = CFArrayGetCount(routeOutputs);
                            for (CFIndex i = 0; i < count; i++)
                            {
                                CFDictionaryRef output = (CFDictionaryRef)CFArrayGetValueAtIndex(routeOutputs, i);
                                CFStringRef type = (CFStringRef)CFDictionaryGetValue(output, kAudioSession_AudioRouteKey_Type);
                                if (type == NULL)
                                    continue;
                                
                                if (CFEqual(type, kAudioSessionOutputRoute_BuiltInSpeaker))
                                    legacySpeaker = true;
                                else if (CFEqual(type, kAudioSessionOutputRoute_Headphones) || CFEqual(type, kAudioSessionOutputRoute_BluetoothHFP) || CFEqual(type, kAudioSessionOutputRoute_BluetoothA2DP))
                                    hasHeadphones = true;
                            }
                        }
                        CFRelease(routeDescription);
                    }
                }
#else
                CFStringRef routeString = NULL;
                UInt32 routeStringSize = sizeof(routeString);
                if (AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &routeStringSize, &routeString) == noErr && routeString != NULL)
                {
                    if (CFStringFind(routeString, CFSTR("Speaker"), 0).location != kCFNotFound)
                        legacySpeaker = true;
                    if (CFStringFind(routeString, CFSTR("Headphone"), 0).location != kCFNotFound ||
                        CFStringFind(routeString, CFSTR("Headset"), 0).location != kCFNotFound ||
                        CFStringFind(routeString, CFSTR("Bluetooth"), 0).location != kCFNotFound)
                        hasHeadphones = true;
                }
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
                bool speaker = legacySpeaker;
#else
                bool speaker = iosMajorVersion() < 6 ? legacySpeaker : strongSelf->_speaker;
#endif
                NSNumber *targetSpeaker = strongSelf->_targetSpeaker;
                NSNumber *delayedSpeaker = strongSelf->_delayedSpeaker;
                if (targetSpeaker != nil)
                {
                    speaker = targetSpeaker.boolValue;
                }
                else if (currentState == TGCallStateWaitingReceived || currentState == TGCallStateOngoing)
                {
                    strongSelf->_delayedSpeaker = nil;
                    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
                    if (iosMajorVersion() >= 6)
                    {
                        speaker = false;
                        
                        for (AVAudioSessionPortDescription *output in outputs)
                        {
                            if ([output.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker])
                            {
                                speaker = true;
                                break;
                            }
                        }
                    }
                    else
                    {
                        speaker = legacySpeaker;
                    }
#endif
                }
                else if (delayedSpeaker != nil)
                {
                    speaker = delayedSpeaker.boolValue;
                }
                
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
                for (AVAudioSessionPortDescription *input in inputs)
                {
                    if ([input.portType isEqualToString:AVAudioSessionPortBuiltInMic])
                        continue;
                    
                    if ([input.portType isEqualToString:AVAudioSessionPortHeadsetMic])
                    {
                        hasHeadphones = true;
                        continue;
                    }
                    
                    TGAudioRoute *route = [TGAudioRoute routeWithDescription:input];
                    [audioRoutes addObject:route];
                    
                    if (iosMajorVersion() >= 6)
                    {
                        for (AVAudioSessionPortDescription *currentInput in audioSession.currentRoute.inputs)
                        {
                            if ([currentInput.UID isEqualToString:input.UID])
                                activeRoute = route;
                        }
                    }
                }
#endif
                OSSpinLockUnlock(&_speakerLock);
                
                TGAudioRoute *builtInRoute = [TGAudioRoute routeForBuiltIn:hasHeadphones];
                [audioRoutes addObject:builtInRoute];
                TGAudioRoute *speakerRoute = [TGAudioRoute routeForSpeaker];
                if (speakerRoute != nil)
                {
                    [audioRoutes addObject:speakerRoute];
                    if (speaker)
                        activeRoute = speakerRoute;
                }
                
                if (activeRoute == nil)
                    activeRoute = builtInRoute;
                
                OSSpinLockLock(&_speakerLock);
                strongSelf->_speaker = speaker;
                OSSpinLockUnlock(&_speakerLock);
                
                return [[TGCallAudioContext alloc] initWithAvailableRoutes:audioRoutes activeRoute:activeRoute speaker:speaker];
            }];
}

- (SSignal *)debugSignal
{
    __weak TGCallSession *weakSelf = self;
    return [[[SSignal defer:^SSignal *{
        __strong TGCallSession *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_controller == nil)
            return [SSignal complete];
        
        NSArray *debugValues = [strongSelf->_controller with:^id(VoIPControllerHolder *controller) {
            NSString *versionString = [NSString stringWithUTF8String:controller.controller->GetVersion()];
            auto rawDebugString = controller.controller->GetDebugString();
            NSString *debugString = [NSString stringWithUTF8String:rawDebugString.c_str()];
            return @[debugString, versionString];
        }];
        return [SSignal single:[NSString stringWithFormat:@"libtgvoip v%@\n%@", debugValues[1], debugValues[0]]];
    }] then:[[SSignal complete] delay:0.5 onQueue:[SQueue mainQueue]]] restart];
}

- (SSignal *)levelSignal
{
    __weak TGCallSession *weakSelf = self;
    return [[[SSignal defer:^SSignal *{
        __strong TGCallSession *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_controller == nil)
            return [SSignal complete];
        
        NSNumber *level = [strongSelf->_controller with:^id(VoIPControllerHolder *controller) {
            CGFloat value = MIN(1.0f, MAX(0.0f, controller.controller->GetOutputLevel()));
            return @(value);
        }];
        return [SSignal single:level];
    }] then:[[SSignal complete] delay:0.1 onQueue:[SQueue mainQueue]]] restart];
}

- (int64_t)peerId
{
    return _peer.uid;
}

#pragma mark - Debug

- (void)setDebugBitrate:(NSInteger)bitrate
{
    if (_controller == nil)
        return;
    
    [_controller with:^id(VoIPControllerHolder *controller) {
        controller.controller->DebugCtl(1, (int)bitrate);
        return nil;
    }];
}

- (void)setDebugPacketLoss:(NSInteger)packetLossPercent
{
    if (_controller == nil)
        return;
    
    [_controller with:^id(VoIPControllerHolder *controller) {
        controller.controller->DebugCtl(2, (int)packetLossPercent);
        return nil;
    }];
}

- (void)setDebugP2PEnabled:(bool)enabled
{
    if (_controller == nil)
        return;
    
    [_controller with:^id(VoIPControllerHolder *controller) {
        controller.controller->DebugCtl(3, enabled);
        return nil;
    }];
}

@end


@implementation TGCallSessionState

- (instancetype)initWithOutgoing:(bool)outgoing callStateData:(TGCallStateData *)stateData transmissionState:(TGCallTransmissionState)transmissionState peer:(TGUser *)peer keySha256:(NSData *)keySha256 startTime:(CFAbsoluteTime)startTime signalBars:(NSInteger)signalBars mute:(bool)mute speaker:(bool)speaker audioRoutes:(NSArray *)audioRoutes activeAudioRoute:(TGAudioRoute *)activeAudioRoute isVideoCall:(bool)isVideoCall canSendVideo:(bool)canSendVideo localVideoEnabled:(bool)localVideoEnabled remoteVideoActive:(bool)remoteVideoActive remoteVideoPaused:(bool)remoteVideoPaused remoteMuted:(bool)remoteMuted
{
    self = [super init];
    if (self != nil)
    {
        _outgoing = outgoing;
        _stateData = stateData;
        _state = stateData.state;
        _transmissionState = transmissionState;
        _peer = peer;
        _keySha256 = keySha256;
        _startTime = startTime;
        _signalBars = signalBars;
        _mute = mute;
        _speaker = speaker;
        _audioRoutes = audioRoutes;
        _activeAudioRoute = activeAudioRoute;
        _isVideoCall = isVideoCall;
        _canSendVideo = canSendVideo;
        _localVideoEnabled = localVideoEnabled;
        _remoteVideoActive = remoteVideoActive;
        _remoteVideoPaused = remoteVideoPaused;
        _remoteMuted = remoteMuted;
    }
    return self;
}

@end


@implementation TGCallAudioContext

- (instancetype)initWithAvailableRoutes:(NSArray *)availableRoutes activeRoute:(TGAudioRoute *)activeRoute speaker:(bool)speaker
{
    self = [super init];
    if (self != nil)
    {
        _availableRoutes = availableRoutes;
        _activeRoute = activeRoute;
        _speaker = speaker;
    }
    return self;
}

@end


