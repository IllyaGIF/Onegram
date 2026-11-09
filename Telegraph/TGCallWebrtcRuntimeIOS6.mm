#import <Foundation/Foundation.h>
#import "TGCommon.h"

#ifndef TGCALLS_IOS6_AUDIO_ONLY
#define TGCALLS_IOS6_AUDIO_ONLY 1
#endif

#include "../thirdparty/TgVoipWebrtcIOS6/include/tgcalls/TGIOS6CxxCompat.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/Instance.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/InstanceImpl.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/Ios6VideoCapabilities.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/VideoState.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/media/VideoFrame.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/media/VideoSource.h"

#import "TGCallVideoNative.h"

#include <array>
#include <memory>
#include <vector>

static void TGIOS6RegisterCallImplementations()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tgcalls::Register<tgcalls::InstanceImpl>();
    });
}

extern "C" void TGIOS6RunThreadTask(void (*task)(void *), void *context)
{
    @autoreleasepool {
        task(context);
    }
}

@interface TGIOS6WebrtcCallbackProxy : NSObject

@property (nonatomic, copy) void (^signalBarsChanged)(int32_t);
@property (nonatomic, copy) void (^stateChanged)(int32_t, int32_t, int32_t, int32_t, int32_t, float);

- (void)emitSignalBars:(int32_t)bars;
- (void)emitState:(int32_t)state;
- (void)emitRemoteVideoState:(int32_t)videoState audioState:(int32_t)audioState batteryLow:(bool)batteryLow;

@end

@implementation TGIOS6WebrtcCallbackProxy {
    bool _hasState;
    int32_t _lastState;
    bool _hasSignalBars;
    int32_t _lastSignalBars;
    int32_t _remoteVideoState;
    int32_t _remoteAudioState;
    int32_t _remoteBatteryLow;
}

- (void)notifyState
{
    if (_stateChanged != nil)
        _stateChanged(_lastState, 0, _remoteVideoState, _remoteAudioState, _remoteBatteryLow, 0.0f);
}

- (void)emitRemoteVideoState:(int32_t)videoState audioState:(int32_t)audioState batteryLow:(bool)batteryLow
{
    void (^update)(void) = ^{
        _remoteVideoState = videoState;
        _remoteAudioState = audioState;
        _remoteBatteryLow = batteryLow ? 1 : 0;
        if (_hasState)
            [self notifyState];
    };
    if ([NSThread isMainThread]) update();
    else dispatch_async(dispatch_get_main_queue(), update);
}

- (void)setStateChanged:(void (^)(int32_t, int32_t, int32_t, int32_t, int32_t, float))stateChanged
{
    void (^callback)(int32_t, int32_t, int32_t, int32_t, int32_t, float) = [stateChanged copy];
    void (^update)(void) = ^{
        _stateChanged = callback;
        if (_hasState)
            [self notifyState];
    };
    if ([NSThread isMainThread]) update();
    else dispatch_async(dispatch_get_main_queue(), update);
}

- (void)setSignalBarsChanged:(void (^)(int32_t))signalBarsChanged
{
    void (^callback)(int32_t) = [signalBarsChanged copy];
    void (^update)(void) = ^{
        _signalBarsChanged = callback;
        if (_hasSignalBars && _signalBarsChanged != nil)
            _signalBarsChanged(_lastSignalBars);
    };
    if ([NSThread isMainThread]) update();
    else dispatch_async(dispatch_get_main_queue(), update);
}

- (void)emitSignalBars:(int32_t)bars
{
    void (^update)(void) = ^{
        _hasSignalBars = true;
        _lastSignalBars = bars;
        if (_signalBarsChanged != nil)
            _signalBarsChanged(bars);
    };
    if ([NSThread isMainThread]) update();
    else dispatch_async(dispatch_get_main_queue(), update);
}

- (void)emitState:(int32_t)state
{
    void (^update)(void) = ^{
        _hasState = true;
        _lastState = state;
        [self notifyState];
    };
    if ([NSThread isMainThread]) update();
    else dispatch_async(dispatch_get_main_queue(), update);
}

@end

namespace {

tgcalls::NetworkType TGIOS6WebrtcNetworkType(int32_t networkType) {
    switch (networkType) {
        case 0:
            return tgcalls::NetworkType::WiFi;
        case 1:
            return tgcalls::NetworkType::Gprs;
        case 2:
            return tgcalls::NetworkType::Edge;
        case 3:
            return tgcalls::NetworkType::ThirdGeneration;
        case 4:
            return tgcalls::NetworkType::Lte;
        default:
            return tgcalls::NetworkType::Unknown;
    }
}

class TGIOS6WebrtcCppBridge {
public:
    TGIOS6WebrtcCppBridge(TGIOS6WebrtcCallbackProxy *callbackProxy) :
    _callbackProxy(callbackProxy),
    _outgoingVideoSource(new tgcalls::VideoSourceHub()),
    _incomingVideoSink(new tgcalls::VideoSinkHub()) {
        TGIOS6RegisterCallImplementations();
    }

    bool start(
        NSString *version,
        NSString *customParameters,
        NSData *key,
        bool isOutgoing,
        NSArray *connections,
        int32_t maxLayer,
        bool allowP2P,
        bool allowTCP,
        tgcalls::NetworkType networkType,
        void (^sendSignalingData)(NSData *),
        TGIOS6WebrtcCallbackProxy *callbackProxy) {
        if (key.length != tgcalls::EncryptionKey::kSize) {
            TGDiagnosticLog(@"WEBRTC cpp.start.fail badKeyLen=%d", (int)key.length);
            return false;
        }
        if (version.length == 0) {
            TGDiagnosticLog(@"CALL webrtc.start.fail missingVersion");
            return false;
        }

        tgcalls::Descriptor descriptor;
        descriptor.version = std::string(version.UTF8String);
        descriptor.config.customParameters = customParameters.length == 0 ? "{}" : std::string(customParameters.UTF8String);
        descriptor.config.maxApiLayer = maxLayer;
        descriptor.config.enableP2P = allowP2P;
        descriptor.config.allowTCP = allowTCP;
        descriptor.config.protocolVersion = descriptor.version == "5.0.0" ? tgcalls::ProtocolVersion::V1 : tgcalls::ProtocolVersion::V0;
        descriptor.initialNetworkType = networkType;

        std::shared_ptr<std::array<uint8_t, tgcalls::EncryptionKey::kSize>> keyValue(new std::array<uint8_t, tgcalls::EncryptionKey::kSize>());
        memcpy(keyValue->data(), key.bytes, tgcalls::EncryptionKey::kSize);
        descriptor.encryptionKey = tgcalls::EncryptionKey(keyValue, isOutgoing);

        for (id item in connections) {
            tgcalls::RtcServer server;
            NSNumber *reflectorId = [item valueForKey:@"reflectorId"];
            NSString *ip = [item valueForKey:@"ip"];
            NSNumber *port = [item valueForKey:@"port"];
            NSString *username = [item valueForKey:@"username"];
            NSString *password = [item valueForKey:@"password"];
            NSNumber *hasTurn = [item valueForKey:@"hasTurn"];
            NSNumber *hasTcp = [item valueForKey:@"hasTcp"];
            
            if (reflectorId != nil)
                server.id = (uint8_t)[reflectorId intValue];
            if (ip.length != 0)
                server.host = std::string([ip UTF8String]);
            if (port != nil)
                server.port = (uint16_t)[port intValue];
            if (username.length != 0)
                server.login = std::string([username UTF8String]);
            if (password.length != 0)
                server.password = std::string([password UTF8String]);
            if (hasTurn != nil)
                server.isTurn = [hasTurn boolValue];
            if (hasTcp != nil)
                server.isTcp = [hasTcp boolValue];
            if (!server.host.empty() && server.port != 0)
                descriptor.rtcServers.push_back(server);
        }
        

        void (^sendSignalingDataCopy)(NSData *) = [sendSignalingData copy];
        int emittedSignalingPackets = 0;
        int emittedCandidatePackets = 0;
        descriptor.signalingDataEmitted = [sendSignalingDataCopy, emittedSignalingPackets, emittedCandidatePackets](const std::vector<uint8_t> &data) mutable {
            if (sendSignalingDataCopy != nil && !data.empty()) {
                emittedSignalingPackets++;
                if (data.size() == 59) {
                    emittedCandidatePackets++;
                }
                NSData *payload = [[NSData alloc] initWithBytes:data.data() length:data.size()];
                const unsigned long payloadLength = (unsigned long)data.size();
                if ([NSThread isMainThread]) {
                    sendSignalingDataCopy(payload);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        sendSignalingDataCopy(payload);
                    });
                }
            }
        };
        descriptor.signalBarsUpdated = [callbackProxy](int bars) {
            [callbackProxy emitSignalBars:(int32_t)bars];
        };
        descriptor.stateUpdated = [callbackProxy](tgcalls::State state) {
            int32_t mapped = 0;
            if (state == tgcalls::State::Established)
                mapped = 1;
            else if (state == tgcalls::State::Failed)
                mapped = 2;
            else if (state == tgcalls::State::Reconnecting)
                mapped = 3;
            [callbackProxy emitState:mapped];
        };
        std::shared_ptr<bool> remoteBatteryLow(new bool(false));
        descriptor.remoteMediaStateUpdated = [callbackProxy, remoteBatteryLow](tgcalls::AudioState audioState, tgcalls::VideoState videoState) {
            int32_t mappedVideo = 0;
            if (videoState == tgcalls::VideoState::Active)
                mappedVideo = 1;
            else if (videoState == tgcalls::VideoState::Paused)
                mappedVideo = 2;
            [callbackProxy emitRemoteVideoState:mappedVideo audioState:audioState == tgcalls::AudioState::Muted ? 0 : 1 batteryLow:*remoteBatteryLow];
        };
        descriptor.remoteBatteryLevelIsLowUpdated = [remoteBatteryLow](bool batteryLow) {
            *remoteBatteryLow = batteryLow;
        };
        descriptor.outgoingVideoSource = _outgoingVideoSource;
        descriptor.incomingVideoSink = _incomingVideoSink;
        descriptor.remotePrefferedAspectRatioUpdated = [](float) {
        };
        descriptor.audioLevelUpdated = [](float) {
        };

        @try {
            _instance = tgcalls::Meta::Create(descriptor.version, std::move(descriptor));
        } @catch (NSException *exception) {
            TGDiagnosticLog(@"WEBRTC cpp.create.exception name=%@ reason=%@", exception.name, exception.reason);
            return false;
        }
        if (!_instance) {
            TGDiagnosticLog(@"WEBRTC cpp.start.fail noInstance version=%@ servers=%d", version, (int)connections.count);
            return false;
        }

        return true;
    }

    void setMuted(bool muted) {
        if (_instance)
            _instance->setMuteMicrophone(muted);
    }

    void setOutgoingVideoEnabled(bool enabled) {
        if (_instance)
            _instance->setOutgoingVideoEnabled(enabled);
    }

    void setVideoCapturer(TGCallVideoCapturer *capturer) {
        if (_capturer != nil && _capturer != capturer)
            [_capturer setFrameSink:std::shared_ptr<tgcalls::VideoFrameSink>()];
        _capturer = capturer;
        if (capturer != nil) {
            [capturer setFrameSink:_outgoingVideoSource];
            _outgoingVideoSource->setController([capturer captureController]);
        } else {
            _outgoingVideoSource->setController(std::shared_ptr<tgcalls::VideoCaptureController>());
        }
    }

    void setIncomingVideoView(TGCallVideoView *view) {
        _incomingVideoSink->setSink(view != nil ? [view frameSink] : std::shared_ptr<tgcalls::VideoFrameSink>());
    }

    void detachVideo() {
        setVideoCapturer(nil);
        setIncomingVideoView(nil);
    }

    void setNetworkType(tgcalls::NetworkType networkType) {
        if (_instance)
            _instance->setNetworkType(networkType);
    }

    void receiveSignalingData(NSData *data) {
        if (!_instance || data.length == 0)
            return;

        std::vector<uint8_t> payload((const uint8_t *)data.bytes, (const uint8_t *)data.bytes + data.length);
        _instance->receiveSignalingData(payload);
    }

    void stop(void (^completion)(NSString *, int64_t, int64_t, int64_t, int64_t)) {
        detachVideo();
        if (!_instance) {
            if (completion != nil)
                completion(@"", 0, 0, 0, 0);
            return;
        }

        std::shared_ptr<std::unique_ptr<tgcalls::Instance>> stopping(new std::unique_ptr<tgcalls::Instance>(std::move(_instance)));
        (*stopping)->stop([stopping, completion](tgcalls::FinalState finalState) {
            if (completion != nil) {
                NSString *debugLog = [NSString stringWithUTF8String:finalState.debugLog.c_str()] ?: @"";
                const int64_t sentWifi = finalState.trafficStats.bytesSentWifi;
                const int64_t receivedWifi = finalState.trafficStats.bytesReceivedWifi;
                const int64_t sentMobile = finalState.trafficStats.bytesSentMobile;
                const int64_t receivedMobile = finalState.trafficStats.bytesReceivedMobile;
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(debugLog, sentWifi, receivedWifi, sentMobile, receivedMobile);
                });
            }
            stopping->reset();
        });
    }

private:
    std::unique_ptr<tgcalls::Instance> _instance;
    TGIOS6WebrtcCallbackProxy *_callbackProxy;
    std::shared_ptr<tgcalls::VideoSourceHub> _outgoingVideoSource;
    std::shared_ptr<tgcalls::VideoSinkHub> _incomingVideoSink;
    TGCallVideoCapturer *_capturer;
};

}

@interface OngoingCallConnectionDescriptionWebrtc : NSObject

@property (nonatomic, assign) uint8_t reflectorId;
@property (nonatomic, assign) bool hasStun;
@property (nonatomic, assign) bool hasTurn;
@property (nonatomic, assign) bool hasTcp;
@property (nonatomic, strong) NSString *ip;
@property (nonatomic, assign) int32_t port;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;

- (instancetype)initWithReflectorId:(uint8_t)reflectorId hasStun:(bool)hasStun hasTurn:(bool)hasTurn hasTcp:(bool)hasTcp ip:(NSString *)ip port:(int32_t)port username:(NSString *)username password:(NSString *)password;

@end

@implementation OngoingCallConnectionDescriptionWebrtc

- (instancetype)initWithReflectorId:(uint8_t)reflectorId hasStun:(bool)hasStun hasTurn:(bool)hasTurn hasTcp:(bool)hasTcp ip:(NSString *)ip port:(int32_t)port username:(NSString *)username password:(NSString *)password
{
    self = [super init];
    if (self != nil) {
        _reflectorId = reflectorId;
        _hasStun = hasStun;
        _hasTurn = hasTurn;
        _hasTcp = hasTcp;
        _ip = [ip copy];
        _port = port;
        _username = [username copy];
        _password = [password copy];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<WebrtcConnection id=%d ip=%@ port=%d stun=%d turn=%d tcp=%d user=%@ passLen=%d>",
            (int)_reflectorId, _ip, _port, _hasStun ? 1 : 0, _hasTurn ? 1 : 0, _hasTcp ? 1 : 0, _username, (int)_password.length];
}

@end

@interface OngoingCallThreadLocalContextWebrtc : NSObject

@property (nonatomic, copy) void (^signalBarsChanged)(int32_t);
@property (nonatomic, copy) void (^stateChanged)(int32_t, int32_t, int32_t, int32_t, int32_t, float);

- (instancetype)initWithVersion:(NSString *)version customParameters:(NSString *)customParameters queue:(id)queue proxy:(id)proxy networkType:(int32_t)networkType dataSaving:(int32_t)dataSaving derivedState:(NSData *)derivedState key:(NSData *)key isOutgoing:(bool)isOutgoing connections:(NSArray *)connections maxLayer:(int32_t)maxLayer allowP2P:(bool)allowP2P allowTCP:(bool)allowTCP enableStunMarking:(bool)enableStunMarking logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath sendSignalingData:(void (^)(NSData *))sendSignalingData videoCapturer:(id)videoCapturer preferredVideoCodec:(NSString *)preferredVideoCodec audioInputDeviceId:(NSString *)audioInputDeviceId audioDevice:(id)audioDevice directConnection:(id)directConnection;
- (void)addSignalingData:(NSData *)data;
- (void)setIsMuted:(bool)isMuted;
+ (bool)supportsVideoSending;
+ (bool)supportsVideoReceiving;
- (void)setOutgoingVideoEnabled:(bool)enabled;
- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer;
- (void)setIncomingVideoView:(TGCallVideoView *)view;
- (void)setNetworkType:(int32_t)networkType;
- (void)stop:(void (^)(NSString *debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;

@end

@implementation OngoingCallThreadLocalContextWebrtc {
    NSString *_version;
    NSString *_customParameters;
    NSData *_key;
    NSArray *_connections;
    bool _isOutgoing;
    void (^_sendSignalingData)(NSData *);
    TGIOS6WebrtcCallbackProxy *_callbackProxy;
    TGIOS6WebrtcCppBridge *_cppBridge;
}

+ (NSArray *)versionsWithIncludeReference:(bool)includeReference
{
    TGIOS6RegisterCallImplementations();
    NSMutableArray *versions = [[NSMutableArray alloc] init];
    const std::vector<std::string> registeredVersions = tgcalls::Meta::Versions();
    for (auto it = registeredVersions.rbegin(); it != registeredVersions.rend(); ++it) {
        NSString *version = [NSString stringWithUTF8String:it->c_str()];
        if (version.length != 0)
            [versions addObject:version];
    }
    return versions;
}

+ (bool)supportsVideoSending
{
    return tgcalls::Ios6CanSendVideo() && [TGCallVideoCapturer isAvailable];
}

+ (bool)supportsVideoReceiving
{
    return tgcalls::Ios6CanReceiveVideo();
}

- (void)setOutgoingVideoEnabled:(bool)enabled
{
    if (_cppBridge != NULL)
        _cppBridge->setOutgoingVideoEnabled(enabled);
}

- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer
{
    if (_cppBridge != NULL)
        _cppBridge->setVideoCapturer(capturer);
}

- (void)setIncomingVideoView:(TGCallVideoView *)view
{
    if (_cppBridge != NULL)
        _cppBridge->setIncomingVideoView(view);
}

- (instancetype)initWithVersion:(NSString *)version customParameters:(NSString *)customParameters queue:(id)queue proxy:(id)proxy networkType:(int32_t)networkType dataSaving:(int32_t)dataSaving derivedState:(NSData *)derivedState key:(NSData *)key isOutgoing:(bool)isOutgoing connections:(NSArray *)connections maxLayer:(int32_t)maxLayer allowP2P:(bool)allowP2P allowTCP:(bool)allowTCP enableStunMarking:(bool)enableStunMarking logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath sendSignalingData:(void (^)(NSData *))sendSignalingData videoCapturer:(id)videoCapturer preferredVideoCodec:(NSString *)preferredVideoCodec audioInputDeviceId:(NSString *)audioInputDeviceId audioDevice:(id)audioDevice directConnection:(id)directConnection
{
    self = [super init];
    if (self != nil) {
        _version = [version copy];
        _customParameters = [customParameters copy];
        _key = [key copy];
        _connections = [connections copy];
        _isOutgoing = isOutgoing;
        _sendSignalingData = [sendSignalingData copy];
        _callbackProxy = [[TGIOS6WebrtcCallbackProxy alloc] init];
        
        _cppBridge = new TGIOS6WebrtcCppBridge(_callbackProxy);
        bool started = _cppBridge->start(_version, _customParameters, _key, _isOutgoing, _connections, maxLayer, allowP2P, allowTCP, TGIOS6WebrtcNetworkType(networkType), _sendSignalingData, _callbackProxy);
        if (!started) {
            delete _cppBridge;
            _cppBridge = NULL;
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_cppBridge != NULL)
        _cppBridge->detachVideo();
    delete _cppBridge;
    _cppBridge = NULL;
}

- (void)setSignalBarsChanged:(void (^)(int32_t))signalBarsChanged
{
    _signalBarsChanged = [signalBarsChanged copy];
    _callbackProxy.signalBarsChanged = _signalBarsChanged;
}

- (void)setStateChanged:(void (^)(int32_t, int32_t, int32_t, int32_t, int32_t, float))stateChanged
{
    _stateChanged = [stateChanged copy];
    _callbackProxy.stateChanged = _stateChanged;
}

- (void)addSignalingData:(NSData *)data
{
    if (_cppBridge != NULL)
        _cppBridge->receiveSignalingData(data);
}

- (void)setIsMuted:(bool)isMuted
{
    if (_cppBridge != NULL)
        _cppBridge->setMuted(isMuted);
}

- (void)setNetworkType:(int32_t)networkType
{
    if (_cppBridge != NULL)
        _cppBridge->setNetworkType(TGIOS6WebrtcNetworkType(networkType));
}

- (void)stop:(void (^)(NSString *, int64_t, int64_t, int64_t, int64_t))completion
{
    if (_cppBridge != NULL)
        _cppBridge->stop(completion);
    else if (completion != nil)
        completion(@"", 0, 0, 0, 0);
}

@end
