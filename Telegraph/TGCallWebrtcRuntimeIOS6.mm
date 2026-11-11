#import <Foundation/Foundation.h>
#import "TGCommon.h"

#if !defined(TGCALLS_IOS6_AUDIO_ONLY)
#   define TGCALLS_IOS6_AUDIO_ONLY 1
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

static void OGCompatRegisterCallImplementations()
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

typedef void (^OGCompatSignalBarsBlock)(int32_t);
typedef void (^OGCompatFinishBlock)(NSString *, int64_t, int64_t, int64_t, int64_t);
typedef void (^OGCompatStateBlock)(int32_t, int32_t, int32_t, int32_t, int32_t, float);

@interface OGCompatWebrtcEventRelay : NSObject

@property (nonatomic, copy) OGCompatSignalBarsBlock signalBarsChanged;
@property (nonatomic, copy) OGCompatStateBlock stateChanged;

- (void)relaySignalBars:(int32_t)bars;
- (void)relayState:(int32_t)state;
- (void)relayRemoteVideo:(int32_t)videoState audio:(int32_t)audioState batteryLow:(bool)batteryLow;

@end

@implementation OGCompatWebrtcEventRelay {
    bool _stateKnown;
    int32_t _currentState;
    bool _barsKnown;
    int32_t _currentBars;
    int32_t _remoteVideo;
    int32_t _remoteAudio;
    int32_t _remoteLowBattery;
}

- (void)og_compat_onMain:(void (^)(void))work
{
    if ([NSThread isMainThread])
        work();
    else
        dispatch_async(dispatch_get_main_queue(), work);
}

- (void)og_compat_deliverState
{
    OGCompatStateBlock handler = _stateChanged;
    if (handler != nil)
        handler(_currentState, 0, _remoteVideo, _remoteAudio, _remoteLowBattery, 0.0f);
}

- (void)setStateChanged:(OGCompatStateBlock)stateChanged
{
    OGCompatStateBlock handler = [stateChanged copy];
    [self og_compat_onMain:^{
        _stateChanged = handler;
        if (_stateKnown)
            [self og_compat_deliverState];
    }];
}

- (void)setSignalBarsChanged:(OGCompatSignalBarsBlock)signalBarsChanged
{
    OGCompatSignalBarsBlock handler = [signalBarsChanged copy];
    [self og_compat_onMain:^{
        _signalBarsChanged = handler;
        if (_barsKnown && _signalBarsChanged != nil)
            _signalBarsChanged(_currentBars);
    }];
}

- (void)relaySignalBars:(int32_t)bars
{
    [self og_compat_onMain:^{
        _barsKnown = true;
        _currentBars = bars;
        OGCompatSignalBarsBlock handler = _signalBarsChanged;
        if (handler != nil)
            handler(bars);
    }];
}

- (void)relayState:(int32_t)state
{
    [self og_compat_onMain:^{
        _stateKnown = true;
        _currentState = state;
        [self og_compat_deliverState];
    }];
}

- (void)relayRemoteVideo:(int32_t)videoState audio:(int32_t)audioState batteryLow:(bool)batteryLow
{
    [self og_compat_onMain:^{
        _remoteVideo = videoState;
        _remoteAudio = audioState;
        _remoteLowBattery = batteryLow ? 1 : 0;
        if (_stateKnown)
            [self og_compat_deliverState];
    }];
}

@end

namespace {

tgcalls::NetworkType OGCompatNetworkType(int32_t networkType)
{
    static const tgcalls::NetworkType table[] = {
        tgcalls::NetworkType::WiFi,
        tgcalls::NetworkType::Gprs,
        tgcalls::NetworkType::Edge,
        tgcalls::NetworkType::ThirdGeneration,
        tgcalls::NetworkType::Lte
    };
    if (networkType >= 0 && networkType < (int32_t)(sizeof(table) / sizeof(table[0])))
        return table[networkType];
    return tgcalls::NetworkType::Unknown;
}

int32_t OGCompatStateCode(tgcalls::State state)
{
    switch (state) {
        case tgcalls::State::Established:
            return 1;
        case tgcalls::State::Failed:
            return 2;
        case tgcalls::State::Reconnecting:
            return 3;
        default:
            return 0;
    }
}

bool OGCompatAssignText(id item, NSString *field, std::string &target)
{
    NSString *text = [item valueForKey:field];
    if (text.length == 0)
        return false;
    target = std::string([text UTF8String]);
    return true;
}

bool OGCompatAssignNumber(id item, NSString *field, NSNumber **value)
{
    *value = [item valueForKey:field];
    return *value != nil;
}

bool OGCompatReadRelayServer(id item, tgcalls::RtcServer &server)
{
    NSNumber *number = nil;
    if (OGCompatAssignNumber(item, @"reflectorId", &number))
        server.id = (uint8_t)[number intValue];
    OGCompatAssignText(item, @"ip", server.host);
    if (OGCompatAssignNumber(item, @"port", &number))
        server.port = (uint16_t)[number intValue];
    OGCompatAssignText(item, @"username", server.login);
    OGCompatAssignText(item, @"password", server.password);
    if (OGCompatAssignNumber(item, @"hasTurn", &number))
        server.isTurn = [number boolValue];
    if (OGCompatAssignNumber(item, @"hasTcp", &number))
        server.isTcp = [number boolValue];
    return !server.host.empty() && server.port != 0;
}

class OGCompatCallBridge {
public:
    OGCompatCallBridge(OGCompatWebrtcEventRelay *relay) :
    _relay(relay),
    _outgoingVideoSource(new tgcalls::VideoSourceHub()),
    _incomingVideoSink(new tgcalls::VideoSinkHub()) {
        OGCompatRegisterCallImplementations();
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
        OGCompatWebrtcEventRelay *relay) {
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
        descriptor.initialNetworkType = networkType;

        tgcalls::Config &config = descriptor.config;
        config.customParameters = customParameters.length == 0 ? "{}" : std::string(customParameters.UTF8String);
        config.maxApiLayer = maxLayer;
        config.enableP2P = allowP2P;
        config.allowTCP = allowTCP;
        config.protocolVersion = descriptor.version == "5.0.0" ? tgcalls::ProtocolVersion::V1 : tgcalls::ProtocolVersion::V0;

        typedef std::array<uint8_t, tgcalls::EncryptionKey::kSize> KeyBytes;
        std::shared_ptr<KeyBytes> keyValue(new KeyBytes());
        [key getBytes:keyValue->data() length:tgcalls::EncryptionKey::kSize];
        descriptor.encryptionKey = tgcalls::EncryptionKey(keyValue, isOutgoing);

        for (id item in connections) {
            tgcalls::RtcServer server;
            if (OGCompatReadRelayServer(item, server))
                descriptor.rtcServers.push_back(server);
        }

        void (^signalingSink)(NSData *) = [sendSignalingData copy];
        descriptor.signalingDataEmitted = [signalingSink](const std::vector<uint8_t> &data) {
            if (signalingSink == nil || data.empty())
                return;
            NSData *payload = [NSData dataWithBytes:data.data() length:data.size()];
            if ([NSThread isMainThread]) {
                signalingSink(payload);
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    signalingSink(payload);
                });
            }
        };
        descriptor.signalBarsUpdated = [relay](int bars) {
            [relay relaySignalBars:(int32_t)bars];
        };
        descriptor.stateUpdated = [relay](tgcalls::State state) {
            [relay relayState:OGCompatStateCode(state)];
        };

        std::shared_ptr<bool> peerBatteryLow(new bool(false));
        descriptor.remoteMediaStateUpdated = [relay, peerBatteryLow](tgcalls::AudioState audioState, tgcalls::VideoState videoState) {
            int32_t videoCode = 0;
            if (videoState == tgcalls::VideoState::Active)
                videoCode = 1;
            else if (videoState == tgcalls::VideoState::Paused)
                videoCode = 2;
            int32_t audioCode = audioState == tgcalls::AudioState::Muted ? 0 : 1;
            [relay relayRemoteVideo:videoCode audio:audioCode batteryLow:*peerBatteryLow];
        };
        descriptor.remoteBatteryLevelIsLowUpdated = [peerBatteryLow](bool batteryLow) {
            *peerBatteryLow = batteryLow;
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

        const uint8_t *bytes = (const uint8_t *)data.bytes;
        std::vector<uint8_t> packet(bytes, bytes + data.length);
        _instance->receiveSignalingData(packet);
    }

    void stop(OGCompatFinishBlock completion) {
        detachVideo();
        if (!_instance) {
            if (completion != nil)
                completion(@"", 0, 0, 0, 0);
            return;
        }

        typedef std::unique_ptr<tgcalls::Instance> InstanceHolder;
        std::shared_ptr<InstanceHolder> stopping(new InstanceHolder(std::move(_instance)));
        (*stopping)->stop([stopping, completion](tgcalls::FinalState finalState) {
            if (completion != nil) {
                NSString *debugLog = [NSString stringWithUTF8String:finalState.debugLog.c_str()] ?: @"";
                const tgcalls::TrafficStats &stats = finalState.trafficStats;
                const int64_t sentWifi = stats.bytesSentWifi;
                const int64_t receivedWifi = stats.bytesReceivedWifi;
                const int64_t sentMobile = stats.bytesSentMobile;
                const int64_t receivedMobile = stats.bytesReceivedMobile;
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(debugLog, sentWifi, receivedWifi, sentMobile, receivedMobile);
                });
            }
            stopping->reset();
        });
    }

private:
    std::unique_ptr<tgcalls::Instance> _instance;
    OGCompatWebrtcEventRelay *_relay;
    std::shared_ptr<tgcalls::VideoSourceHub> _outgoingVideoSource;
    std::shared_ptr<tgcalls::VideoSinkHub> _incomingVideoSink;
    TGCallVideoCapturer *_capturer;
};

}

@interface OngoingCallConnectionDescriptionWebrtc : NSObject

@property (nonatomic, assign) uint8_t reflectorId;
@property (nonatomic, assign) int32_t port;
@property (nonatomic, assign) bool hasStun;
@property (nonatomic, assign) bool hasTurn;
@property (nonatomic, assign) bool hasTcp;
@property (nonatomic, strong) NSString *ip;
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
        _port = port;
        _hasStun = hasStun;
        _hasTurn = hasTurn;
        _hasTcp = hasTcp;
        _ip = [ip copy];
        _username = [username copy];
        _password = [password copy];
    }
    return self;
}

- (NSString *)description
{
    NSString *flags = [NSString stringWithFormat:@"stun=%d turn=%d tcp=%d", _hasStun ? 1 : 0, _hasTurn ? 1 : 0, _hasTcp ? 1 : 0];
    return [NSString stringWithFormat:@"<WebrtcConnection id=%d ip=%@ port=%d %@ user=%@ passLen=%d>",
            (int)_reflectorId, _ip, _port, flags, _username, (int)_password.length];
}

@end

@interface OngoingCallThreadLocalContextWebrtc : NSObject

@property (nonatomic, copy) OGCompatSignalBarsBlock signalBarsChanged;
@property (nonatomic, copy) OGCompatStateBlock stateChanged;

- (instancetype)initWithVersion:(NSString *)version customParameters:(NSString *)customParameters queue:(id)queue proxy:(id)proxy networkType:(int32_t)networkType dataSaving:(int32_t)dataSaving derivedState:(NSData *)derivedState key:(NSData *)key isOutgoing:(bool)isOutgoing connections:(NSArray *)connections maxLayer:(int32_t)maxLayer allowP2P:(bool)allowP2P allowTCP:(bool)allowTCP enableStunMarking:(bool)enableStunMarking logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath sendSignalingData:(void (^)(NSData *))sendSignalingData videoCapturer:(id)videoCapturer preferredVideoCodec:(NSString *)preferredVideoCodec audioInputDeviceId:(NSString *)audioInputDeviceId audioDevice:(id)audioDevice directConnection:(id)directConnection;
+ (bool)supportsVideoSending;
+ (bool)supportsVideoReceiving;
- (void)addSignalingData:(NSData *)data;
- (void)setIsMuted:(bool)isMuted;
- (void)setOutgoingVideoEnabled:(bool)enabled;
- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer;
- (void)setIncomingVideoView:(TGCallVideoView *)view;
- (void)setNetworkType:(int32_t)networkType;
- (void)stop:(OGCompatFinishBlock)completion;

@end

@implementation OngoingCallThreadLocalContextWebrtc {
    OGCompatWebrtcEventRelay *_relay;
    OGCompatCallBridge *_bridge;
}

+ (NSArray *)versionsWithIncludeReference:(bool)includeReference
{
    OGCompatRegisterCallImplementations();
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

- (instancetype)initWithVersion:(NSString *)version customParameters:(NSString *)customParameters queue:(id)queue proxy:(id)proxy networkType:(int32_t)networkType dataSaving:(int32_t)dataSaving derivedState:(NSData *)derivedState key:(NSData *)key isOutgoing:(bool)isOutgoing connections:(NSArray *)connections maxLayer:(int32_t)maxLayer allowP2P:(bool)allowP2P allowTCP:(bool)allowTCP enableStunMarking:(bool)enableStunMarking logPath:(NSString *)logPath statsLogPath:(NSString *)statsLogPath sendSignalingData:(void (^)(NSData *))sendSignalingData videoCapturer:(id)videoCapturer preferredVideoCodec:(NSString *)preferredVideoCodec audioInputDeviceId:(NSString *)audioInputDeviceId audioDevice:(id)audioDevice directConnection:(id)directConnection
{
    self = [super init];
    if (self != nil) {
        _relay = [[OGCompatWebrtcEventRelay alloc] init];

        _bridge = new OGCompatCallBridge(_relay);
        if (!_bridge->start(version, customParameters, key, isOutgoing, connections, maxLayer, allowP2P, allowTCP, OGCompatNetworkType(networkType), sendSignalingData, _relay)) {
            delete _bridge;
            _bridge = NULL;
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_bridge != NULL)
        _bridge->detachVideo();
    delete _bridge;
    _bridge = NULL;
}

- (void)setSignalBarsChanged:(OGCompatSignalBarsBlock)signalBarsChanged
{
    _relay.signalBarsChanged = signalBarsChanged;
    _signalBarsChanged = [signalBarsChanged copy];
}

- (void)setStateChanged:(OGCompatStateBlock)stateChanged
{
    _relay.stateChanged = stateChanged;
    _stateChanged = [stateChanged copy];
}

- (void)addSignalingData:(NSData *)data
{
    if (_bridge != NULL)
        _bridge->receiveSignalingData(data);
}

- (void)setIsMuted:(bool)isMuted
{
    if (_bridge != NULL)
        _bridge->setMuted(isMuted);
}

- (void)setOutgoingVideoEnabled:(bool)enabled
{
    if (_bridge != NULL)
        _bridge->setOutgoingVideoEnabled(enabled);
}

- (void)setVideoCapturer:(TGCallVideoCapturer *)capturer
{
    if (_bridge != NULL)
        _bridge->setVideoCapturer(capturer);
}

- (void)setIncomingVideoView:(TGCallVideoView *)view
{
    if (_bridge != NULL)
        _bridge->setIncomingVideoView(view);
}

- (void)setNetworkType:(int32_t)networkType
{
    if (_bridge != NULL)
        _bridge->setNetworkType(OGCompatNetworkType(networkType));
}

- (void)stop:(OGCompatFinishBlock)completion
{
    if (_bridge != NULL)
        _bridge->stop(completion);
    else if (completion != nil)
        completion(@"", 0, 0, 0, 0);
}

@end
