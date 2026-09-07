#import "TGCallSession.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <libkern/OSAtomic.h>

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "../submodules/MtProtoKit/MTProtoKit/MTProtoKit.h"

#import "TGAppDelegate.h"
#import "TGTelegramNetworking.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGAudioSessionManager.h"

#import "TGCallUtils.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"

#import "TGCallSignals.h"
#import "TGCallAudioPlayer.h"
#import "TGCallKitAdapter.h"

#import "VoIPController.h"
#import "VoIPServerConfig.h"
#import "os/darwin/SetupLogging.h"

static NSString *TGIOS6CurrentCallsConfig = nil;

@interface NSObject (TGCallWebrtcRuntimeDynamic)

+ (NSArray *)versionsWithIncludeReference:(bool)includeReference;
+ (void)applyServerConfig:(NSString *)data;

- (instancetype)initWithReflectorId:(uint8_t)reflectorId hasStun:(bool)hasStun hasTurn:(bool)hasTurn hasTcp:(bool)hasTcp ip:(NSString *)ip port:(int32_t)port username:(NSString *)username password:(NSString *)password;
- (instancetype)initWithVersion:(NSString *)version customParameters:(NSString *)customParameters queue:(id)queue proxy:(id)proxy networkType:(int32_t)networkType dataSaving:(int32_t)dataSaving derivedState:(NSData *)derivedState key:(NSData *)key isOutgoing:(bool)isOutgoing connections:(NSArray *)connections maxLayer:(int32_t)maxLayer allowP2P:(bool)allowP2P allowTCP:(bool)allowTCP enableStunMarking:(bool)enableStunMarking logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath sendSignalingData:(void (^)(NSData *))sendSignalingData videoCapturer:(id)videoCapturer preferredVideoCodec:(NSString *)preferredVideoCodec audioInputDeviceId:(NSString *)audioInputDeviceId audioDevice:(id)audioDevice directConnection:(id)directConnection;
- (void)setStateChanged:(void (^)(int32_t, int32_t, int32_t, int32_t, int32_t, float))stateChanged;
- (void)setSignalBarsChanged:(void (^)(int32_t))signalBarsChanged;

- (void)addSignalingData:(NSData *)data;
- (void)setIsMuted:(bool)isMuted;
- (void)setNetworkType:(int32_t)networkType;
- (void)stop:(void (^)(NSString *debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;

@end

@interface TGCallWebrtcQueue : NSObject
@end

@implementation TGCallWebrtcQueue

- (void)dispatch:(void (^)())block
{
    if (block != nil)
        dispatch_async(dispatch_get_main_queue(), block);
}

- (bool)isCurrent
{
    return [NSThread isMainThread];
}

- (id)scheduleBlock:(void (^)())block after:(double)timeout
{
    __block bool disposed = false;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!disposed && block != nil)
            block();
    });
    
    return [[SBlockDisposable alloc] initWithBlock:^{
        disposed = true;
    }];
}

@end

@interface TGCallWebrtcRuntime : NSObject {
    bool _started;
}

@property (nonatomic, strong) id context;
@property (nonatomic, strong) TGCallWebrtcQueue *queue;
@property (nonatomic, readonly) bool started;

- (bool)startWithState:(TGCallStateData *)state outgoing:(bool)outgoing logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath signalBarsChanged:(void (^)(int32_t))signalBarsChanged stateChanged:(void (^)(TGCallTransmissionState))stateChanged;
- (void)receiveSignalingData:(NSData *)data;
- (void)setMuted:(bool)muted;
- (void)setNetworkType:(int32_t)networkType;
- (void)stopWithCompletion:(void (^)(NSString *debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;
@end

@implementation TGCallWebrtcRuntime

- (bool)started
{
    return _started;
}

- (bool)startWithState:(TGCallStateData *)state outgoing:(bool)outgoing logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath signalBarsChanged:(void (^)(int32_t))signalBarsChanged stateChanged:(void (^)(TGCallTransmissionState))stateChanged
{
    Class contextClass = NSClassFromString(@"OngoingCallThreadLocalContextWebrtc");
    Class connectionClass = NSClassFromString(@"OngoingCallConnectionDescriptionWebrtc");
    if (contextClass == nil || connectionClass == nil) {
        TGLog(@"CALL webrtc.runtime.missing contextClass=%@ connectionClass=%@", contextClass, connectionClass);
        return false;
    }
    
    NSArray *supportedVersions = [NSArray array];
    if ([contextClass respondsToSelector:@selector(versionsWithIncludeReference:)])
    {
        NSArray *versions = [(id)contextClass versionsWithIncludeReference:false];
        if ([versions isKindOfClass:[NSArray class]])
            supportedVersions = versions;
    }
    
    NSArray *serverVersions = state.connection.libraryVersions;
    if (![serverVersions isKindOfClass:[NSArray class]])
        serverVersions = [NSArray array];
    
    TGLog(@"CALL webrtc.version.negotiate call=%lld server=%@ local=%@ minLayer=%d maxLayer=%d",
          state.callId,
          serverVersions,
          supportedVersions,
          state.connection.minLayer,
          state.connection.maxLayer);
    
    NSString *version = nil;
    for (id candidateObject in serverVersions)
    {
        if (![candidateObject isKindOfClass:[NSString class]])
            continue;
        
        NSString *candidate = (NSString *)candidateObject;
        if ([supportedVersions containsObject:candidate])
        {
            version = candidate;
            break;
        }
    }
    
    if (version.length == 0)
    {
        TGLog(@"CALL webrtc.version.mismatch call=%lld server=%@ local=%@",
              state.callId,
              serverVersions,
              supportedVersions);
        return false;
    }
    
    if (state.connection.key.length != 256)
    {
        TGLog(@"CALL webrtc.runtime.badKey call=%lld keyLen=%d",
              state.callId,
              (int)state.connection.key.length);
        return false;
    }
    
    TGLog(@"CALL webrtc.version.selected call=%lld version=%@",
          state.callId,
          version);
    
    NSMutableArray *connections = [[NSMutableArray alloc] init];
    for (TGCallWebrtcConnectionDescription *connection in state.connection.webrtcConnections) {
        NSString *ip = connection.ipv4.length != 0 ? connection.ipv4 : connection.ipv6;
        if (ip.length == 0 || connection.port == 0)
            continue;
        
        id webRtcConnection = [[connectionClass alloc] initWithReflectorId:(uint8_t)(connection.identifier & 0xff)
                                                                   hasStun:connection.stun
                                                                   hasTurn:connection.turn
                                                                    hasTcp:false
                                                                        ip:ip
                                                                      port:connection.port
                                                                  username:connection.username ?: @""
                                                                  password:connection.password ?: @""];
        if (webRtcConnection != nil)
            [connections addObject:webRtcConnection];
    }
    
    if (connections.count == 0) {
        TGLog(@"CALL webrtc.runtime.noConnections call=%lld", state.callId);
        return false;
    }
    
    TGCallWebrtcQueue *queue = [[TGCallWebrtcQueue alloc] init];
    self.queue = queue;
    
    void (^sendSignalingData)(NSData *) = ^(NSData *data) {
        TGLog(@"CALL webrtc.signaling.emit call=%lld dataLen=%d", state.callId, (int)data.length);
        [[TGCallSignals sendSignalingDataForCallId:state.callId accessHash:state.accessHash data:data] startWithNext:nil error:^(id error) {
            TGLog(@"CALL webrtc.signaling.send.error call=%lld error=%@", state.callId, error);
        } completed:nil];
    };
    
    NSString *customParameters = state.connection.customParameters;
    if (customParameters.length == 0)
        customParameters = @"{}";
    
    TGLog(@"CALL webrtc.runtime.customParameters call=%lld stateLen=%d finalLen=%d",
          state.callId,
          (int)state.connection.customParameters.length,
          (int)customParameters.length);
    
    id context = [[contextClass alloc] initWithVersion:version
                                      customParameters:customParameters
                                                 queue:queue
                                                 proxy:nil
                                           networkType:0
                                            dataSaving:0
                                          derivedState:[NSData data]
                                                   key:state.connection.key
                                            isOutgoing:outgoing
                                           connections:connections
                                              maxLayer:(state.connection.maxLayer > 0 ? state.connection.maxLayer : TGCallLegacyMaxLayer)
                                              allowP2P:false
                                              allowTCP:true
                                     enableStunMarking:false
                                               logPath:logPath ?: @""
                                          statsLogPath:statsLogPath ?: @""
                                     sendSignalingData:sendSignalingData
                                         videoCapturer:nil
                                   preferredVideoCodec:nil
                                    audioInputDeviceId:@""
                                           audioDevice:nil
                                      directConnection:nil];
    if (context == nil) {
        TGLog(@"CALL webrtc.runtime.initNil call=%lld version=%@", state.callId, version);
        return false;
    }
    
    self.context = context;
    
    if ([context respondsToSelector:@selector(setStateChanged:)])
    {
        [context setStateChanged:^(int32_t callState, int32_t videoState, int32_t remoteVideoState, int32_t remoteAudioState, int32_t remoteBatteryLevel, float remotePreferredAspectRatio)
         {
             TGCallTransmissionState transmissionState = TGCallTransmissionStateInitializing;
             
             switch (callState)
             {
                 case 1:
                     transmissionState = TGCallTransmissionStateEstablished;
                     break;
                     
                 case 2:
                     transmissionState = TGCallTransmissionStateFailed;
                     break;
                     
                 case 3:
                     transmissionState = TGCallTransmissionStateReconnecting;
                     break;
                     
                 default:
                     break;
             }
             
             if (stateChanged != nil)
                 stateChanged(transmissionState);
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
    
    TGLog(@"CALL webrtc.runtime.callbacks.active call=%lld", state.callId);
    TGLog(@"CALL webrtc.runtime.start call=%lld version=%@ connections=%d customParametersLen=%d", state.callId, version, (int)connections.count, (int)customParameters.length);
    _started = true;
    return true;
}

- (void)receiveSignalingData:(NSData *)data
{
    if (data.length == 0 || self.context == nil)
        return;
    
    TGLog(@"CALL webrtc.signaling.receive.forward dataLen=%d", (int)data.length);
    if ([self.context respondsToSelector:@selector(addSignalingData:)])
        [self.context addSignalingData:data];
}

- (void)setMuted:(bool)muted
{
    if (self.context != nil && [self.context respondsToSelector:@selector(setIsMuted:)])
        [self.context setIsMuted:muted];
}

- (void)setNetworkType:(int32_t)networkType
{
    if (self.context == nil || ![self.context respondsToSelector:@selector(setNetworkType:)])
        return;
    
    int32_t mappedType = 0;
    switch ((TGNetworkType)networkType)
    {
        case TGNetworkTypeGPRS:
            mappedType = 1;
            break;
        case TGNetworkTypeEdge:
            mappedType = 2;
            break;
        case TGNetworkType3G:
            mappedType = 3;
            break;
        case TGNetworkTypeLTE:
            mappedType = 4;
            break;
        case TGNetworkTypeWiFi:
        default:
            mappedType = 0;
            break;
    }
    
    [self.context setNetworkType:mappedType];
}

- (void)stopWithCompletion:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion
{
    id context = self.context;
    self.context = nil;
    _started = false;
    
    if (context != nil && [context respondsToSelector:@selector(stop:)]) {
        [context stop:completion];
    } else if (completion != nil) {
        completion(@"", 0, 0, 0, 0);
    }
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


@interface TGCallSessionData : NSObject

@property (nonatomic, readonly) TGCallStateData *stateData;
@property (nonatomic, readonly) TGCallAudioContext *audioContext;

- (instancetype)initWithStateData:(TGCallStateData *)stateData audioContext:(TGCallAudioContext *)audioContext;

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
    
    UILocalNotification *_notification;
    NSUInteger _receivedSignalingPackets;
    NSMutableArray *_pendingSignalingData;
    TGCallWebrtcRuntime *_webrtcRuntime;
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
    
    _receivedSignalingPackets++;
    TGCallWebrtcRuntime *runtime = nil;
    int32_t pendingCount = 0;
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
            pendingCount = (int32_t)_pendingSignalingData.count;
        }
    }
    
    if (runtime != nil)
    {
        TGLog(@"CALL signaling.session.forward call=%lld access=%lld packet=%d dataLen=%d", _callId, _accessHash, (int)_receivedSignalingPackets, (int)data.length);
        [runtime receiveSignalingData:data];
    }
    else
    {
        TGLog(@"CALL signaling.session.buffer call=%lld packet=%d dataLen=%d pending=%d", _callId, (int)_receivedSignalingPackets, (int)data.length, pendingCount);
    }
}

- (void)_flushPendingSignalingData
{
    NSArray *pending = nil;
    TGCallWebrtcRuntime *runtime = nil;
    @synchronized(self)
    {
        if (_webrtcRuntime == nil || !_webrtcRuntime.started || _pendingSignalingData.count == 0)
            return;
        runtime = _webrtcRuntime;
        pending = [_pendingSignalingData copy];
        [_pendingSignalingData removeAllObjects];
    }
    
    TGLog(@"CALL signaling.session.flush call=%lld count=%d", _callId, (int)pending.count);
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
    TGLog(@"%@", string);
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
    
    TGDispatchOnMainThread(^
                           {
                               if (tranmissionState == _previousTransmissionState)
                                   return;
                               
                               if (tranmissionState == TGCallTransmissionStateEstablished && _startTime < DBL_EPSILON)
                               {
                                   _startTime = CFAbsoluteTimeGetCurrent();
                                   
                                   if (self.onConnected != nil)
                                       self.onConnected();
                               }
                               
                               _transmissionPipe.sink(@(tranmissionState));
                               
                               if (tranmissionState == TGCallTransmissionStateReconnecting)
                               {
                                   if (_webrtcRuntime.started)
                                       TGLog(@"CALL webrtc.skipTone reconnecting");
                                   else
                                       [self playTone:TGCallToneConnecting];
                               }
                               else if (tranmissionState == TGCallTransmissionStateEstablished)
                               {
                                   [self stopAudio];
                               }
                               else if (tranmissionState == TGCallTransmissionStateFailed)
                               {
                                   [self playTone:TGCallToneEnded];
                                   [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
                               }
                               
                               _previousTransmissionState = tranmissionState;
                           });
}

- (void)webrtcTransmissionStateChanged:(TGCallTransmissionState)tranmissionState
{
    TGDispatchOnMainThread(^
                           {
                               if (tranmissionState == _previousTransmissionState)
                                   return;
                               
                               if (tranmissionState == TGCallTransmissionStateEstablished && _startTime < DBL_EPSILON)
                               {
                                   _startTime = CFAbsoluteTimeGetCurrent();
                                   
                                   if (self.onConnected != nil)
                                       self.onConnected();
                               }
                               
                               _transmissionPipe.sink(@(tranmissionState));
                               
                               if (tranmissionState == TGCallTransmissionStateReconnecting)
                               {
                                   if (_webrtcRuntime.started)
                                       TGLog(@"CALL webrtc.skipTone reconnecting");
                                   else
                                       [self playTone:TGCallToneConnecting];
                               }
                               else if (tranmissionState == TGCallTransmissionStateEstablished)
                               {
                                   [self stopAudio];
                               }
                               else if (tranmissionState == TGCallTransmissionStateFailed)
                               {
                                   [self playTone:TGCallToneEnded];
                                   [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
                               }
                               
                               _previousTransmissionState = tranmissionState;
                           });
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
        hasWebRtc && hasTgCallsProtocol;
        
        bool useLegacyLibtgvoip =
        !useWebRtc && hasLegacyRelay;
        
        TGLog(@"CALL transmission.protocol call=%lld min=%d max=%d versions=%@",
              state.callId,
              state.connection.minLayer,
              state.connection.maxLayer,
              state.connection.libraryVersions);
        
        TGLog(@"CALL transmission.select call=%lld legacy=%d webrtc=%d versions=%@ engine=%@",
              state.callId,
              hasLegacyRelay ? 1 : 0,
              hasWebRtc ? 1 : 0,
              state.connection.libraryVersions,
              useWebRtc ? @"webrtc" : (useLegacyLibtgvoip ? @"libtgvoip" : @"none"));
        
        if (useWebRtc)
        {
            TGLog(@"CALL webrtc.skipTone connecting");
        }
        else
        {
            [self playTone:TGCallToneConnecting];
        }
        
        SSignal *readySignal = [SSignal single:@true];
        if ([TGCallKitAdapter callKitAvailable] && !_outgoing && _audioSessionActivated != nil)
            readySignal = _audioSessionActivated.signal;
        
        [[[[readySignal filter:^bool(NSNumber *value) {
            return value;
        }] timeout:10.5 onQueue:[SQueue mainQueue] orSignal:[SSignal single:@true]] take:1] startWithNext:^(__unused id next)
         {
             if (useWebRtc)
             {
                 TGLog(@"CALL webrtc.only.prepare call=%lld endpoints=%d customParameters=%@", state.callId, (int)state.connection.webrtcConnections.count, state.connection.customParameters);
                 for (TGCallWebrtcConnectionDescription *connection in state.connection.webrtcConnections) {
                     TGLog(@"CALL webrtc.endpoint id=%lld flags=%d turn=%d stun=%d ip=%@ ipv6=%@ port=%d user=%@ passLen=%d",
                           connection.identifier,
                           connection.flags,
                           connection.turn ? 1 : 0,
                           connection.stun ? 1 : 0,
                           connection.ipv4,
                           connection.ipv6,
                           connection.port,
                           connection.username,
                           (int)connection.password.length);
                 }
                 
                 NSString *logPath = [[self callLogsPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%lld-%lld.log", state.callId, state.accessHash]];
                 NSString *statsLogPath = [logPath stringByAppendingString:@".json"];
                 if (_webrtcRuntime == nil)
                     _webrtcRuntime = [[TGCallWebrtcRuntime alloc] init];
                 
                 __weak TGCallSession *weakSession = self;
                 bool runtimeStarted = [_webrtcRuntime startWithState:state outgoing:_outgoing logPath:logPath statsLogPath:statsLogPath signalBarsChanged:^(int32_t bars) {
                     __strong TGCallSession *strongSession = weakSession;
                     if (strongSession != nil)
                         [strongSession signalBarsChanged:bars];
                 } stateChanged:^(TGCallTransmissionState transmissionState) {
                     __strong TGCallSession *strongSession = weakSession;
                     if (strongSession != nil)
                         [strongSession webrtcTransmissionStateChanged:transmissionState];
                 }];
                 
                 if (runtimeStarted) {
                     [self _flushPendingSignalingData];
                     [_webrtcRuntime setMuted:_muted];
                     [self startNetworkTypeMonitoring];
                     TGLog(@"CALL webrtc.runtime.active call=%lld legacyControllerSkipped=1", state.callId);
                     if (self.onStartedConnecting != nil)
                         self.onStartedConnecting();
                     return;
                 }
                 
                 TGLog(@"CALL webrtc.engine.missing call=%lld storedWebRtc=%d usingLegacyLibtgvoip=0 signalingApiReady=1 hardBlock=1", state.callId, (int)state.connection.webrtcConnections.count);
                 [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
                 return;
             }
             
             if (_controller == nil)
                 [self _controllerInit];
             
             __block bool didStartTransmission = false;
             [_controller with:^id(VoIPControllerHolder *controller) {
                 std::vector<tgvoip::Endpoint> endpoints;
                 NSMutableArray *connections = [[NSMutableArray alloc] init];
                 if (state.connection.defaultConnection != nil)
                     [connections addObject:state.connection.defaultConnection];
                 for (TGCallConnectionDescription *connection in state.connection.alternativeConnections) {
                     if (connection != nil)
                         [connections addObject:connection];
                 }
                 TGLog(@"CALL voip.start.prepare call=%lld default=%@ alt=%d total=%d webrtc=%d customParametersLen=%d", state.callId, state.connection.defaultConnection, (int)state.connection.alternativeConnections.count, (int)connections.count, (int)state.connection.webrtcConnections.count, (int)state.connection.customParameters.length);
                 if (useWebRtc)
                 {
                     TGLog(@"CALL webrtc.engine.prepare call=%lld endpoints=%d customParameters=%@", state.callId, (int)state.connection.webrtcConnections.count, state.connection.customParameters);
                     for (TGCallWebrtcConnectionDescription *connection in state.connection.webrtcConnections) {
                         TGLog(@"CALL webrtc.endpoint id=%lld flags=%d turn=%d stun=%d ip=%@ ipv6=%@ port=%d user=%@ passLen=%d",
                               connection.identifier,
                               connection.flags,
                               connection.turn ? 1 : 0,
                               connection.stun ? 1 : 0,
                               connection.ipv4,
                               connection.ipv6,
                               connection.port,
                               connection.username,
                               (int)connection.password.length);
                     }
                 }
                 
                 NSString *logPath = [[self callLogsPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%lld-%lld.log", state.callId, state.accessHash]];
                 NSString *statsLogPath = [logPath stringByAppendingString:@".json"];
                 
                 if (useWebRtc)
                 {
                     if (_webrtcRuntime == nil)
                         _webrtcRuntime = [[TGCallWebrtcRuntime alloc] init];
                     
                     __weak TGCallSession *weakSession = self;
                     bool runtimeStarted = [_webrtcRuntime startWithState:state outgoing:_outgoing logPath:logPath statsLogPath:statsLogPath signalBarsChanged:^(int32_t bars) {
                         __strong TGCallSession *strongSession = weakSession;
                         if (strongSession != nil)
                             [strongSession signalBarsChanged:bars];
                     } stateChanged:^(TGCallTransmissionState transmissionState) {
                         __strong TGCallSession *strongSession = weakSession;
                         if (strongSession != nil)
                             [strongSession webrtcTransmissionStateChanged:transmissionState];
                     }];
                     
                     if (runtimeStarted) {
                         [self _flushPendingSignalingData];
                         [_webrtcRuntime setMuted:_muted];
                         [self startNetworkTypeMonitoring];
                         TGLog(@"CALL webrtc.runtime.active call=%lld legacySkipped=1", state.callId);
                         didStartTransmission = true;
                         return nil;
                     }
                     
                     TGLog(@"CALL webrtc.engine.missing call=%lld storedWebRtc=%d usingLegacyLibtgvoip=0 signalingApiReady=1 hardBlock=1", state.callId, (int)state.connection.webrtcConnections.count);
                     [self _discardCurrentCallWithReason:TGCallDiscardReasonDisconnect];
                     return nil;
                 }
                 
                 for (TGCallConnectionDescription *connection in connections)
                 {
                     if (connection == nil)
                         continue;
                     
                     if (connection.peerTag.length < 16)
                     {
                         TGLog(@"CALL voip.endpoint.skip call=%lld id=%lld reason=peerTag peerTagLen=%d",
                               state.callId,
                               connection.identifier,
                               (int)connection.peerTag.length);
                         continue;
                     }
                     
                     if (iosMajorVersion() <= 6)
                     {
                         if (connection.ipv4.length == 0)
                         {
                             TGLog(@"CALL voip.endpoint.skip call=%lld id=%lld reason=noIPv4 ios5=1",
                                   state.callId,
                                   connection.identifier);
                             continue;
                         }
                         
                         TGLog(@"CALL voip.endpoint.ios5.before call=%lld id=%lld ip=%@ port=%d peerTagLen=%d",
                               state.callId,
                               connection.identifier,
                               connection.ipv4,
                               connection.port,
                               (int)connection.peerTag.length);
                         
                         struct in_addr addrIpV4;
                         
                         if (inet_aton(connection.ipv4.UTF8String, &addrIpV4) == 0)
                         {
                             TGLog(@"CALL voip.endpoint.skip call=%lld id=%lld reason=invalidIPv4 ip=%@",
                                   state.callId,
                                   connection.identifier,
                                   connection.ipv4);
                             continue;
                         }
                         
                         TGLog(@"CALL voip.endpoint.ios5.ipv4.valid call=%lld id=%lld",
                               state.callId,
                               connection.identifier);
                         
                         tgvoip::IPv4Address address(
                                                     std::string(connection.ipv4.UTF8String)
                                                     );
                         
                         TGLog(@"CALL voip.endpoint.ios5.ipv4.created call=%lld id=%lld",
                               state.callId,
                               connection.identifier);
                         
                         tgvoip::IPv6Address addressv6;
                         
                         unsigned char peerTag[16];
                         memset(peerTag, 0, sizeof(peerTag));
                         
                         [connection.peerTag getBytes:peerTag
                                                range:NSMakeRange(0, 16)];
                         
                         TGLog(@"CALL voip.endpoint.ios5.push.before call=%lld id=%lld",
                               state.callId,
                               connection.identifier);
                         
                         tgvoip::Endpoint endpoint(
                                                   connection.identifier,
                                                   (uint16_t)connection.port,
                                                   address,
                                                   addressv6,
                                                   tgvoip::Endpoint::TYPE_UDP_RELAY,
                                                   peerTag
                                                   );
                         
                         endpoints.push_back(endpoint);
                         
                         TGLog(@"CALL voip.endpoint.ios5.push.after call=%lld id=%lld total=%d",
                               state.callId,
                               connection.identifier,
                               (int)endpoints.size());
                         
                         continue;
                     }
                     
                     if (connection.ipv4.length == 0 &&
                         connection.ipv6.length == 0)
                     {
                         TGLog(@"CALL voip.endpoint.skip call=%lld id=%lld reason=noAddress",
                               state.callId,
                               connection.identifier);
                         continue;
                     }
                     
                     tgvoip::IPv4Address address;
                     tgvoip::IPv6Address addressv6;
                     
                     if (connection.ipv4.length != 0)
                     {
                         struct in_addr addrIpV4;
                         
                         if (!inet_aton(connection.ipv4.UTF8String, &addrIpV4))
                         {
                             TGLog(@"CallSession: invalid ipv4 address %@",
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
                             TGLog(@"CallSession: invalid ipv6 address %@",
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
                                                          tgvoip::Endpoint::TYPE_UDP_RELAY,
                                                          peerTag
                                                          )
                                         );
                 }
                 
                 TGLog(@"CALL voip.start.endpoints call=%lld count=%d",
                       state.callId,
                       (int)endpoints.size());
                 
                 if (endpoints.empty())
                 {
                     TGLog(@"CALL voip.start.block no endpoints call=%lld connection=%@",
                           state.callId,
                           state.connection);
                     
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
                         allowP2P = [TGDatabaseInstance() uidIsRemoteContact:(int32_t)state.peerId];
                         break;
                         
                     case 2:
                         allowP2P = true;
                         break;
                         
                     default:
                         break;
                 }
                 TGLog(@"CALL voip.allowP2P call=%lld peer=%lld mode=%d allow=%d forced=0", state.callId, state.peerId, p2pMode, allowP2P ? 1 : 0);
                 
                 controller.controller->SetConfig(config);
                 
                 int32_t connectionMaxLayer =
                 state.connection.maxLayer > 0
                 ? state.connection.maxLayer
                 : TGCallLegacyMaxLayer;
                 
                 TGLog(@"CALL voip.engine.start call=%lld endpoints=%d keyLen=%d outgoing=%d minLayer=%d maxLayer=%d",
                       state.callId,
                       (int)endpoints.size(),
                       (int)state.connection.key.length,
                       _outgoing ? 1 : 0,
                       state.connection.minLayer,
                       connectionMaxLayer);
                 
                 if (state.connection.key.length != 256)
                 {
                     TGLog(@"CALL voip.engine.badKey call=%lld keyLen=%d",
                           state.callId,
                           (int)state.connection.key.length);
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
                 
                 TGLog(@"CALL voip.engine.started call=%lld", state.callId);
                 
                 return nil;
             }];
             
             if (didStartTransmission && self.onStartedConnecting != nil)
                 self.onStartedConnecting();
         }];
    };
    
    if ([TGCallKitAdapter callKitAvailable])
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
    if (_webrtcRuntime.started) {
        TGCallWebrtcRuntime *runtime = _webrtcRuntime;
        _webrtcRuntime = nil;
        [runtime stopWithCompletion:^(NSString *debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile) {
            MTNetworkUsageManager *usageManager = [[MTNetworkUsageManager alloc] initWithInfo:[[TGTelegramNetworking instance] mediaUsageInfoForType:TGNetworkMediaTypeTagCall]];
            [usageManager addIncomingBytes:(NSUInteger)bytesReceivedMobile interface:MTNetworkUsageManagerInterfaceWWAN];
            [usageManager addIncomingBytes:(NSUInteger)bytesReceivedWifi interface:MTNetworkUsageManagerInterfaceOther];
            
            [usageManager addOutgoingBytes:(NSUInteger)bytesSentMobile interface:MTNetworkUsageManagerInterfaceWWAN];
            [usageManager addOutgoingBytes:(NSUInteger)bytesSentWifi interface:MTNetworkUsageManagerInterfaceOther];
            
            if (sendDebugLog && _callId != 0 && self.accessHash != 0 && debugLog.length != 0)
                [[TGCallSignals saveCallDebug:_callId accessHash:self.accessHash data:debugLog] startWithNext:nil];
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
        
        MTNetworkUsageManager *usageManager = [[MTNetworkUsageManager alloc] initWithInfo:[[TGTelegramNetworking instance] mediaUsageInfoForType:TGNetworkMediaTypeTagCall]];
        [usageManager addIncomingBytes:(NSUInteger)stats.bytesRecvdMobile interface:MTNetworkUsageManagerInterfaceWWAN];
        [usageManager addIncomingBytes:(NSUInteger)stats.bytesRecvdWifi interface:MTNetworkUsageManagerInterfaceOther];
        
        [usageManager addOutgoingBytes:(NSUInteger)stats.bytesSentMobile interface:MTNetworkUsageManagerInterfaceWWAN];
        [usageManager addOutgoingBytes:(NSUInteger)stats.bytesSentWifi interface:MTNetworkUsageManagerInterfaceOther];
        
        if (sendDebugLog && _callId != 0 && self.accessHash != 0 && debugLog.length != 0)
            [[TGCallSignals saveCallDebug:_callId accessHash:self.accessHash data:debugLog] startWithNext:nil];
        
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
    if (value < 90)
        value = 90;
    return value;
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
    
    TGIOS6CurrentCallsConfig = [data copy];
    
    Class contextClass = NSClassFromString(@"OngoingCallThreadLocalContextWebrtc");
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
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        
        TGUser *peer = [TGDatabaseInstance() loadUser:(int)peerId];
        NSString *peerName = peer.displayName;
        if (peerName.length == 0)
            peerName = TGLocalized(@"Call.UnknownCaller");
        if (peerName.length == 0 || [peerName isEqualToString:@"Call.UnknownCaller"])
            peerName = @"Telegram";
        NSString *text = [NSString stringWithFormat:TGLocalized(@"PHONE_CALL_REQUEST"), peerName];
        
        NSNumber *globalMessageSoundIdVal = nil;
        int globalMessageSoundId = 1;
        bool notFound = false;
        
        [TGDatabaseInstance() loadPeerNotificationSettings:INT_MAX - 1 soundId:&globalMessageSoundIdVal muteUntil:NULL previewText:NULL messagesMuted:NULL notFound:&notFound];
        if (notFound) {
            globalMessageSoundId = 1;
        }
        else {
            globalMessageSoundId = globalMessageSoundIdVal ? globalMessageSoundIdVal.intValue : 1;
        }
        
        notFound = false;
        
        NSNumber *soundIdVal = nil;
        int soundId = 1;
        [TGDatabaseInstance() loadPeerNotificationSettings:(int32_t)peerId soundId:&soundIdVal muteUntil:NULL previewText:NULL messagesMuted:NULL notFound:&notFound];
        
        if (soundIdVal != nil) {
            soundId = soundIdVal.intValue;
        } else {
            soundId = globalMessageSoundId;
        }
        
        if (soundId > 0)
            notification.soundName = [[NSString alloc] initWithFormat:@"%d.m4a", soundId];
        
#ifdef INTERNAL_RELEASE
        text = [@"[L] " stringByAppendingString:text];
#endif
        notification.alertBody = text;
        notification.userInfo = @{@"cid": @(peerId)};
        
        if (text != nil)
            [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        
        _notification = notification;
    }
}

- (void)cancelLocalNotification
{
    if (_notification == nil)
        return;
    
    [[UIApplication sharedApplication] cancelLocalNotification:_notification];
    _notification = nil;
}

- (void)applicationWillResignActive:(NSNotification *)__unused notification
{
    if ([TGCallKitAdapter callKitAvailable])
        return;
    
    if (_playingRingtone && _audioPlayer != nil)
        [self stopAudio];
}

- (void)applicationDidBecomeActive:(NSNotification *)__unused notification
{
    if ([TGCallKitAdapter callKitAvailable])
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
    if (![TGCallKitAdapter callKitAvailable])
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
         
         audioSession = [[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypeCall interrupted:^{}];
         
         if (iosMajorVersion() >= 6)
         {
             AVAudioSession *session = [AVAudioSession sharedInstance];
             [session setPreferredIOBufferDuration:0.005 error:NULL];
         }
         else
         {
             Float32 duration = 0.005f;
             AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(duration), &duration);
         }
         
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
    
    return [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio] == AVAuthorizationStatusAuthorized;
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
        TGUser *resolvedPeer = [TGDatabaseInstance() loadUser:(int32_t)state.peerId];
        if (resolvedPeer != nil)
        {
            bool logResolved = (_peer == nil || _peer.displayName.length == 0) && resolvedPeer.displayName.length != 0;
            _peer = resolvedPeer;
            if (logResolved)
                TGLog(@"CALL session.peer.resolved uid=%d name=%@", resolvedPeer.uid, resolvedPeer.displayName);
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
        TGLog(@"Call Session: failed with error: %@", state.error);
    
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
    
    SSignal *combinedSignal = [SSignal combineSignals:@[_state.signal, _signalBarsState.signal, [self audioContextSignal], _transmissionState.signal, _audioTogglesPipe.signalProducer()] withInitialStates:@[ [NSNull null], @0, [NSNull null], @0, @0 ]];
    
    return [[combinedSignal deliverOn:[SQueue mainQueue]] map:^id(NSArray *values)
            {
                __strong TGCallSession *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return nil;
                
                TGCallStateData *stateData = [values[0] isKindOfClass:[NSNull class]] ? nil : (TGCallStateData *)values[0];
                if (stateData != nil && stateData.peerId != 0)
                {
                    TGUser *resolvedPeer = [TGDatabaseInstance() loadUser:(int32_t)stateData.peerId];
                    if (resolvedPeer != nil)
                    {
                        bool logResolved = (strongSelf->_peer == nil || strongSelf->_peer.displayName.length == 0) && resolvedPeer.displayName.length != 0;
                        strongSelf->_peer = resolvedPeer;
                        if (logResolved)
                            TGLog(@"CALL session.peer.refresh uid=%d name=%@", resolvedPeer.uid, resolvedPeer.displayName);
                    }
                }
                NSInteger signalBars = [values[1] integerValue];
                TGCallAudioContext *audioContext = [values[2] isKindOfClass:[NSNull class]] ? nil : (TGCallAudioContext *)values[2];
                TGCallTransmissionState transmissionState = (TGCallTransmissionState)[values[3] integerValue];
                
                bool muted = strongSelf->_muted;
                bool speaker = strongSelf->_targetSpeaker ? strongSelf->_targetSpeaker.boolValue : audioContext.speaker;
                
                return [[TGCallSessionState alloc] initWithOutgoing:strongSelf->_outgoing callStateData:stateData transmissionState:transmissionState peer:strongSelf->_peer keySha256:strongSelf->_keySha256 startTime:strongSelf->_startTime signalBars:signalBars mute:muted speaker:speaker audioRoutes:audioContext.availableRoutes activeAudioRoute:audioContext.activeRoute];
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
                AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                
                NSArray *inputs = nil;
                NSArray *outputs = nil;
                
                if (iosMajorVersion() >= 7)
                {
                    inputs = audioSession.availableInputs;
                    outputs = audioSession.currentRoute.outputs;
                }
                else if (iosMajorVersion() >= 6)
                {
                    outputs = audioSession.currentRoute.outputs;
                }
                
                NSMutableArray *audioRoutes = [[NSMutableArray alloc] init];
                TGAudioRoute *activeRoute = nil;
                bool hasHeadphones = false;
                bool legacySpeaker = false;
                
                if (iosMajorVersion() < 6)
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
                
                bool speaker = iosMajorVersion() < 6 ? legacySpeaker : strongSelf->_speaker;
                NSNumber *targetSpeaker = strongSelf->_targetSpeaker;
                NSNumber *delayedSpeaker = strongSelf->_delayedSpeaker;
                if (targetSpeaker != nil)
                {
                    speaker = targetSpeaker.boolValue;
                }
                else if (currentState == TGCallStateWaitingReceived || currentState == TGCallStateOngoing)
                {
                    strongSelf->_delayedSpeaker = nil;
                    
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
                }
                else if (delayedSpeaker != nil)
                {
                    speaker = delayedSpeaker.boolValue;
                }
                
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

- (instancetype)initWithOutgoing:(bool)outgoing callStateData:(TGCallStateData *)stateData transmissionState:(TGCallTransmissionState)transmissionState peer:(TGUser *)peer keySha256:(NSData *)keySha256 startTime:(CFAbsoluteTime)startTime signalBars:(NSInteger)signalBars mute:(bool)mute speaker:(bool)speaker audioRoutes:(NSArray *)audioRoutes activeAudioRoute:(TGAudioRoute *)activeAudioRoute
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


@implementation TGCallSessionData

- (instancetype)initWithStateData:(TGCallStateData *)stateData audioContext:(TGCallAudioContext *)audioContext
{
    self = [super init];
    if (self != nil)
    {
        _stateData = stateData;
        _audioContext = audioContext;
    }
    return self;
}

@end
