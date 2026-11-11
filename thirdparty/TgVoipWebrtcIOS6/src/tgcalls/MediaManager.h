#ifndef TGCALLS_MEDIA_MANAGER_H
#define TGCALLS_MEDIA_MANAGER_H

#ifdef TGCALLS_IOS6_AUDIO_ONLY

#include "Instance.h"
#include "Message.h"
#include "Stats.h"
#include "MediaTransport.h"
#include "rtc_base/thread.h"
#include "media/AudioChannel.h"
#include "media/BandwidthEstimator.h"
#include "media/VideoFrame.h"
#include "media/VideoReceiveStream.h"
#include "media/VideoSendStream.h"
#include "media/VideoSource.h"
#include "rtp/Rtcp.h"
#include "rtp/RtpStatistics.h"
#include "v2/MediaNegotiator.h"

#include <deque>
#include <memory>
#include <pthread.h>
#include <string>
#include <vector>

namespace tgcalls {

class MediaManager : public std::enable_shared_from_this<MediaManager> {
public:
	static rtc::Thread *getWorkerThread() { return nullptr; }

	MediaManager(
		rtc::Thread *thread,
		bool isOutgoing,
		ProtocolVersion protocolVersion,
		const MediaDevicesConfig &devicesConfig,
		std::shared_ptr<VideoCaptureInterface> videoCapture,
		MessageCallback sendSignalingMessage,
		MessageCallback sendTransportMessage,
		std::function<void(int)> signalBarsUpdated,
		std::function<void(float)> audioLevelUpdated,
		std::function<webrtc::scoped_refptr<webrtc::AudioDeviceModule>(webrtc::TaskQueueFactory*)> createAudioDeviceModule,
		bool enableHighBitrateVideo,
		std::vector<std::string> preferredCodecs,
		std::shared_ptr<MediaTransport> mediaTransport,
		std::shared_ptr<VideoSourceHub> outgoingVideoSource,
		std::shared_ptr<VideoSinkHub> incomingVideoSink);
	~MediaManager() noexcept;

	void start();
	void setIsConnected(bool isConnected);
	void setNegotiatedMedia(const NegotiatedMedia &media, uint32_t localAudioSsrc, uint32_t localVideoSsrc);
	void notifyPacketSent(const rtc::SentPacket &sentPacket) {}
	void setSendVideo(std::shared_ptr<VideoCaptureInterface> capture) {}
	void sendVideoDeviceUpdated() {}
	void setRequestedVideoAspect(float aspect) {}
	void setMuteOutgoingAudio(bool mute);
	void setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink) {}
	void receiveMessage(DecryptedMessage &&message) {}
	void remoteVideoStateUpdated(VideoState state) {}
	void setNetworkParameters(bool isLowCost, bool isLowDataRequested) {}
	void fillCallStats(CallStats &stats) {}
	void setAudioInputDevice(std::string id) {}
	void setAudioOutputDevice(std::string id) {}
	void setInputVolume(float level) {}
	void setOutputVolume(float level) {}
	void addExternalAudioSamples(std::vector<uint8_t> &&samples) {}

private:
	class Router;
	class RtcpReceiver;
	class SendObserver;
	friend class Router;
	friend class RtcpReceiver;

	void drainIncoming();
	void handleIncomingRtp(const rtp::MediaPacket &packet);
	void handleIncomingRtcp(const rtp::MediaPacket &packet);
	void scheduleTick(int delayMs);
	void tick();
	void sendTransportFeedback();
	void sendRtcpReport(int64_t nowMicros);
	void updateBitrates(int64_t nowMicros);
	void updateReceiveLimit(int64_t nowMicros);
	void updateSignalBars(int64_t nowMicros);
	void configureVideoReceive();
	void configureVideoSend();
	void logVideoStatistics(int64_t nowMicros);

	rtc::Thread *_thread = nullptr;
	bool _started = false;
	bool _isConnected = false;
	std::function<void(int)> _signalBarsUpdated;
	std::function<void(float)> _audioLevelUpdated;
	std::shared_ptr<MediaTransport> _mediaTransport;
	std::shared_ptr<VideoSourceHub> _outgoingVideoSource;
	std::shared_ptr<VideoSinkHub> _incomingVideoSink;
	std::shared_ptr<Router> _router;
	std::shared_ptr<SendObserver> _sendObserver;
	std::unique_ptr<AudioChannel> _audioChannel;
	std::shared_ptr<VideoReceiveStream> _videoReceive;
	std::shared_ptr<VideoSendStream> _videoSend;
	std::unique_ptr<BandwidthEstimator> _bandwidthEstimator;
	NegotiatedMedia _media;
	uint32_t _localAudioSsrc = 0;
	uint32_t _localVideoSsrc = 0;
	std::string _cname;
	rtp::RttEstimator _rtt;
	float _remoteReportedLoss = 0.0f;
	int64_t _lastRemoteReportMicros = 0;
	int _signalBars = -1;
	bool _tickScheduled = false;
	unsigned int _tickCount = 0;
	float _receiveLimitFactor = 1.0f;
	int _receiveLimit = 0;
	int64_t _lastStatisticsLogMicros = 0;
};

} // namespace tgcalls

#else

#include "rtc_base/thread.h"
#include "rtc_base/copy_on_write_buffer.h"
#include "rtc_base/third_party/sigslot/sigslot.h"
#include "api/transport/field_trial_based_config.h"
#include "pc/rtp_sender.h"
#include "media/base/media_channel.h"
#include "pc/media_factory.h"
#include "api/environment/environment.h"

#include "Instance.h"
#include "Message.h"
#include "VideoCaptureInterface.h"
#include "Stats.h"

#include <functional>
#include <memory>

namespace webrtc {
class Call;
class RtcEventLogNull;
class TaskQueueFactory;
class VideoBitrateAllocatorFactory;
class VideoTrackSourceInterface;
class AudioDeviceModule;
} // namespace webrtc

namespace cricket {
class MediaEngineInterface;
class VoiceMediaChannel;
class VideoMediaChannel;
} // namespace cricket

namespace tgcalls {

class VideoSinkInterfaceProxyImpl;

class MediaManager : public sigslot::has_slots<>, public std::enable_shared_from_this<MediaManager> {
public:
	static rtc::Thread *getWorkerThread();

	MediaManager(
		rtc::Thread *thread,
		bool isOutgoing,
        ProtocolVersion protocolVersion,
		const MediaDevicesConfig &devicesConfig,
		std::shared_ptr<VideoCaptureInterface> videoCapture,
		MessageCallback sendSignalingMessage,
		MessageCallback sendTransportMessage,
        std::function<void(int)> signalBarsUpdated,
        std::function<void(float)> audioLevelUpdated,
		std::function<webrtc::scoped_refptr<webrtc::AudioDeviceModule>(webrtc::TaskQueueFactory*)> createAudioDeviceModule,
        bool enableHighBitrateVideo,
        std::vector<std::string> preferredCodecs);
	~MediaManager();

	void start();
	void setIsConnected(bool isConnected);
	void notifyPacketSent(const rtc::SentPacket &sentPacket);
	void setSendVideo(std::shared_ptr<VideoCaptureInterface> videoCapture);
	void sendVideoDeviceUpdated();
    void setRequestedVideoAspect(float aspect);
	void setMuteOutgoingAudio(bool mute);
	void setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>> sink);
	void receiveMessage(DecryptedMessage &&message);
    void remoteVideoStateUpdated(VideoState videoState);
    void setNetworkParameters(bool isLowCost, bool isDataSavingActive);
    void fillCallStats(CallStats &callStats);

	void setAudioInputDevice(std::string id);
	void setAudioOutputDevice(std::string id);
	void setInputVolume(float level);
	void setOutputVolume(float level);

    void addExternalAudioSamples(std::vector<uint8_t> &&samples);

private:
	struct SSRC {
		uint32_t incoming = 0;
		uint32_t outgoing = 0;
		uint32_t fecIncoming = 0;
		uint32_t fecOutgoing = 0;
	};

	class NetworkInterfaceImpl : public cricket::MediaChannelNetworkInterface {
	public:
		NetworkInterfaceImpl(MediaManager *mediaManager, bool isVideo);
        
		bool SendPacket(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) override;
		bool SendRtcp(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options) override;
		int SetOption(SocketType type, rtc::Socket::Option opt, int option) override;

	private:
		bool sendTransportMessage(rtc::CopyOnWriteBuffer *packet, const rtc::PacketOptions& options);

		MediaManager *_mediaManager = nullptr;
		bool _isVideo = false;

	};

	friend class MediaManager::NetworkInterfaceImpl;

	void setPeerVideoFormats(VideoFormatsMessage &&peerFormats);

	bool computeIsSendingVideo() const;
    void configureSendingVideoIfNeeded();
	void checkIsSendingVideoChanged(bool wasSending);
	bool videoCodecsNegotiated() const;

    int getMaxVideoBitrate() const;
    int getMaxAudioBitrate() const;
    void adjustBitratePreferences(bool resetStartBitrate);
    bool computeIsReceivingVideo() const;
    void checkIsReceivingVideoChanged(bool wasReceiving);

	void setOutgoingVideoState(VideoState state);
	void setOutgoingAudioState(AudioState state);
	void sendVideoParametersMessage();
	void sendOutgoingMediaStateMessage();

	webrtc::scoped_refptr<webrtc::AudioDeviceModule> createAudioDeviceModule();

    void beginStatsTimer(int timeoutMs);
    void beginLevelsTimer(int timeoutMs);
    void collectStats();

	rtc::Thread *_thread = nullptr;
	std::unique_ptr<webrtc::RtcEventLogNull> _eventLog;

	MessageCallback _sendSignalingMessage;
	MessageCallback _sendTransportMessage;
    std::function<void(int)> _signalBarsUpdated;
    std::function<void(float)> _audioLevelUpdated;
	std::function<webrtc::scoped_refptr<webrtc::AudioDeviceModule>(webrtc::TaskQueueFactory*)> _createAudioDeviceModule;

	SSRC _ssrcAudio;
	SSRC _ssrcVideo;
	bool _enableFlexfec = true;

    ProtocolVersion _protocolVersion;

	bool _isConnected = false;
    bool _didConnectOnce = false;
	bool _readyToReceiveVideo = false;
    bool _didConfigureVideo = false;
	AudioState _outgoingAudioState = AudioState::Active;
	VideoState _outgoingVideoState = VideoState::Inactive;

	VideoFormatsMessage _myVideoFormats;
	std::vector<cricket::VideoCodec> _videoCodecs;
	absl::optional<cricket::VideoCodec> _videoCodecOut;

    webrtc::Environment _webrtcEnvironment;
    std::unique_ptr<webrtc::MediaFactory> _mediaFactory;
    std::unique_ptr<cricket::MediaEngineInterface> _mediaEngine;
	std::unique_ptr<webrtc::Call> _call;
	webrtc::LocalAudioSinkAdapter _audioSource;
	webrtc::scoped_refptr<webrtc::AudioDeviceModule> _audioDeviceModule;
	std::unique_ptr<cricket::VoiceMediaSendChannelInterface> _audioSendChannel;
    std::unique_ptr<cricket::VoiceMediaReceiveChannelInterface> _audioReceiveChannel;
	std::unique_ptr<cricket::VideoMediaSendChannelInterface> _videoSendChannel;
    bool _haveVideoSendChannel = false;
    std::unique_ptr<cricket::VideoMediaReceiveChannelInterface> _videoReceiveChannel;
	std::unique_ptr<webrtc::VideoBitrateAllocatorFactory> _videoBitrateAllocatorFactory;
	std::shared_ptr<VideoCaptureInterface> _videoCapture;
	std::shared_ptr<bool> _videoCaptureGuard;
    bool _isScreenCapture = false;
    std::shared_ptr<VideoSinkInterfaceProxyImpl> _incomingVideoSinkProxy;
    webrtc::RtpHeaderExtensionMap _audioRtpHeaderExtensionMap;
    webrtc::RtpHeaderExtensionMap _videoRtpHeaderExtensionMap;

    float _localPreferredVideoAspectRatio = 0.0f;
    float _preferredAspectRatio = 0.0f;
    bool _enableHighBitrateVideo = false;
    bool _isLowCostNetwork = false;
    bool _isDataSavingActive = false;

    float _currentAudioLevel = 0.0f;
    float _currentMyAudioLevel = 0.0f;

	std::unique_ptr<MediaManager::NetworkInterfaceImpl> _audioNetworkInterface;
	std::unique_ptr<MediaManager::NetworkInterfaceImpl> _videoNetworkInterface;

    std::vector<CallStatsBitrateRecord> _bitrateRecords;

    std::vector<float> _externalAudioSamples;
    webrtc::Mutex _externalAudioSamplesMutex;
};

} // namespace tgcalls

#endif

#endif
