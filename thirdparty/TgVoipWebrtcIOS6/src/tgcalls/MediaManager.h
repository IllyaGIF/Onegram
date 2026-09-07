#ifndef TGCALLS_MEDIA_MANAGER_H
#define TGCALLS_MEDIA_MANAGER_H

#ifdef TGCALLS_IOS6_AUDIO_ONLY

#include "Instance.h"
#include "Message.h"
#include "Stats.h"
#include "rtc_base/logging.h"

#include "../../../../submodules/libtgvoip/MediaStreamItf.h"
#include "../../../../submodules/libtgvoip/audio/AudioInput.h"
#include "../../../../submodules/libtgvoip/audio/AudioOutput.h"
#include "../../../../submodules/libtgvoip/os/darwin/AudioUnitIO.h"
#include "../../../../submodules/libtgvoip/JitterBuffer.h"
#include "../../../../submodules/libtgvoip/OpusDecoder.h"

extern "C" {
#include "opus.h"
}

#include <arpa/inet.h>
#include <algorithm>
#include <deque>
#include <memory>
#include <pthread.h>
#include <syslog.h>
#include <vector>

namespace tgcalls {

class MediaManager {
public:
	static rtc::Thread *getWorkerThread() {
		return nullptr;
	}

	MediaManager(
		rtc::Thread *,
		bool isOutgoing,
        ProtocolVersion,
		const MediaDevicesConfig &,
		std::shared_ptr<VideoCaptureInterface>,
		MessageCallback sendSignalingMessage,
		MessageCallback sendTransportMessage,
        std::function<void(int)> signalBarsUpdated,
        std::function<void(float)> audioLevelUpdated,
		std::function<webrtc::scoped_refptr<webrtc::AudioDeviceModule>(webrtc::TaskQueueFactory*)>,
        bool,
        std::vector<std::string>) :
		_isOutgoing(isOutgoing),
		_sendSignalingMessage(sendSignalingMessage),
		_sendTransportMessage(sendTransportMessage),
		_signalBarsUpdated(signalBarsUpdated),
		_audioLevelUpdated(audioLevelUpdated) {
		pthread_mutex_init(&_playoutMutex, NULL);
		pthread_mutex_init(&_outgoingPacketsMutex, NULL);
		pthread_cond_init(&_outgoingPacketsCond, NULL);
	}

	void start() {
		if (_started) {
			return;
		}
		_started = true;
		int error = 0;
		_opusEncoder = opus_encoder_create(kPcmSampleRate, 1, OPUS_APPLICATION_VOIP, &error);
		if (_opusEncoder != NULL) {
			opus_encoder_ctl(_opusEncoder, OPUS_SET_BITRATE(32000));
			opus_encoder_ctl(_opusEncoder, OPUS_SET_COMPLEXITY(3));
			opus_encoder_ctl(_opusEncoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
			opus_encoder_ctl(_opusEncoder, OPUS_SET_INBAND_FEC(1));
			opus_encoder_ctl(_opusEncoder, OPUS_SET_PACKET_LOSS_PERC(10));
		}
		if (pthread_create(&_outgoingPacketsThread, NULL, &MediaManager::OutgoingPacketsThreadEntry, this) == 0) {
			_outgoingPacketsThreadStarted = true;
		}
		_audioUnit.reset(new tgvoip::audio::AudioUnitIO());

		if (_audioUnit.get() != NULL && !_audioUnit->IsFailed()) {
			_audioInput.reset(
				tgvoip::audio::AudioInput::Create(
					"default",
					_audioUnit.get()
				)
			);

			_audioOutput.reset(
				tgvoip::audio::AudioOutput::Create(
					"default",
					_audioUnit.get()
				)
			);

			if (_audioInput.get() != NULL) {
				_audioInput->Configure(kPcmSampleRate, 16, 1);
				_audioInput->SetCallback(
					&MediaManager::InputCallback,
					this
				);
			}

			if (_audioOutput.get() != NULL) {
				_audioOutput->Configure(kPcmSampleRate, 16, 1);
			}
		}

		RTC_LOG(LS_INFO)
			<< "IOS6WEBRTC media.audio.io.created unit="
			<< (_audioUnit ? 1 : 0)
			<< " unitFailed="
			<< ((_audioUnit && _audioUnit->IsFailed()) ? 1 : 0)
			<< " input="
			<< (_audioInput ? 1 : 0)
			<< " output="
			<< (_audioOutput ? 1 : 0);

		if (_isConnected) {
			if (_audioInput) {
				_audioInput->Start();
			}

			if (_audioOutput && _playoutReady) {
				_audioOutput->Start();
			}

			RTC_LOG(LS_INFO)
				<< "IOS6WEBRTC media.audio.io.startEarly inputOk="
				<< ((_audioInput && _audioInput->IsInitialized()) ? 1 : 0)
				<< " outputOk="
				<< ((_audioOutput && _audioOutput->IsInitialized()) ? 1 : 0);
		}

		syslog(LOG_NOTICE,
			"IOS6LAT media.clock pcmRate=%u frameSamples=%u frameMs=20 rtpClock=%u rtpStep=%u",
			(unsigned int)kPcmSampleRate,
			(unsigned int)kPcmFrameSamples,
			(unsigned int)kRtpClockRate,
			(unsigned int)kRtpFrameTicks);

		RTC_LOG(LS_INFO)
			<< "IOS6WEBRTC media.audio.start encoder="
			<< (_opusEncoder != NULL)
			<< " decoder="
			<< (_opusPlayoutDecoder ? 1 : 0)
			<< " input="
			<< (_audioInput ? 1 : 0)
			<< " output="
			<< (_audioOutput ? 1 : 0);
	}
	void setIsConnected(bool connected) {
		const bool wasConnected = _isConnected;

		_isConnected = connected;
		_outgoingAudioTransportEnabled = connected;

		RTC_LOG(LS_INFO)
			<< "IOS6WEBRTC media.audio.connected value="
			<< (_isConnected ? 1 : 0)
			<< " transport="
			<< (_outgoingAudioTransportEnabled ? 1 : 0);

		if (connected && !wasConnected) {
			if (_audioInput) {
				_audioInput->Start();
			}

			if (_audioOutput && _playoutReady) {
				_audioOutput->Start();
			}

			RTC_LOG(LS_INFO)
				<< "IOS6WEBRTC media.audio.io.started inputOk="
				<< ((_audioInput && _audioInput->IsInitialized()) ? 1 : 0)
				<< " outputOk="
				<< ((_audioOutput && _audioOutput->IsInitialized()) ? 1 : 0)
				<< " unitFailed="
				<< ((_audioUnit && _audioUnit->IsFailed()) ? 1 : 0);
		} else if (!connected && wasConnected) {
			pthread_mutex_lock(&_playoutMutex);
			if (_jitterBuffer) {
				_jitterBuffer->Reset();
			}
			pthread_mutex_unlock(&_playoutMutex);

			if (_audioInput) {
				_audioInput->Stop();
			}

			if (_audioOutput) {
				_audioOutput->Stop();
			}

			RTC_LOG(LS_INFO)
				<< "IOS6WEBRTC media.audio.io.disabled";
		}
	}

	void notifyPacketSent(const rtc::SentPacket &) {
	}
	void setSendVideo(std::shared_ptr<VideoCaptureInterface>) {
	}
	void sendVideoDeviceUpdated() {
	}
    void setRequestedVideoAspect(float) {
	}
	void setMuteOutgoingAudio(bool mute) {
		_muted = mute;
	}
	void setIncomingVideoOutput(std::weak_ptr<rtc::VideoSinkInterface<webrtc::VideoFrame>>) {
	}
	void receiveMessage(DecryptedMessage &&message) {
		if (_shuttingDown) {
			return;
		}
		const Message *wrapped = &message.message;
		if (const AudioDataMessage *audio = absl::get_if<AudioDataMessage>(&wrapped->data)) {
			handleIncomingRtp(audio->data);
		}
	}
    void remoteVideoStateUpdated(VideoState) {
	}
    void setNetworkParameters(bool, bool) {
	}
    void fillCallStats(CallStats &) {
	}

	void setAudioInputDevice(std::string) {
	}
	void setAudioOutputDevice(std::string) {
	}
	void setInputVolume(float) {
	}
	void setOutputVolume(float) {
	}
    void addExternalAudioSamples(std::vector<uint8_t> &&) {
	}

	~MediaManager() {
		_shuttingDown = true;
		pthread_mutex_lock(&_outgoingPacketsMutex);
		pthread_cond_signal(&_outgoingPacketsCond);
		pthread_mutex_unlock(&_outgoingPacketsMutex);
		if (_audioInput) {
			_audioInput->SetCallback(NULL, NULL);
			_audioInput->Stop();
		}
		if (_audioOutput) {
			_audioOutput->Stop();
		}
		pthread_mutex_lock(&_playoutMutex);
		if (_opusPlayoutDecoder) {
			_opusPlayoutDecoder->Stop();
			_opusPlayoutDecoder.reset();
		}
		_jitterBuffer.reset();
		_playoutReady = false;
		pthread_mutex_unlock(&_playoutMutex);
		if (_audioInput) {
			_audioInput.reset();
		}
		if (_audioOutput) {
			_audioOutput.reset();
		}
		_audioUnit.reset();
		if (_opusEncoder != NULL) {
			opus_encoder_destroy(_opusEncoder);
			_opusEncoder = NULL;
		}
		if (_outgoingPacketsThreadStarted) {
			pthread_join(_outgoingPacketsThread, NULL);
			_outgoingPacketsThreadStarted = false;
		}
		pthread_mutex_lock(&_outgoingPacketsMutex);
		_outgoingRtpPackets.clear();
		pthread_mutex_unlock(&_outgoingPacketsMutex);
		pthread_cond_destroy(&_outgoingPacketsCond);
		pthread_mutex_destroy(&_outgoingPacketsMutex);
		pthread_mutex_destroy(&_playoutMutex);
	}

private:
	static size_t InputCallback(unsigned char *data, size_t length, void *param) {
		if (param == NULL) {
			return 0;
		}
		return ((MediaManager *)param)->handleInputPcm(data, length);
	}


	size_t handleInputPcm(unsigned char *data, size_t length) {
		tickPlayoutJitter();
		if (_shuttingDown || !_isConnected || _muted || _opusEncoder == NULL || !_sendTransportMessage || length != kPcmFrameSamples * 2) {
			return 0;
		}
		if (!_outgoingAudioTransportEnabled) {
			return 0;
		}

		const opus_int16 *inputSamples = (const opus_int16 *)data;
		uint32_t peak = 0;
		uint64_t absSum = 0;
		for (int i = 0; i < kPcmFrameSamples; ++i) {
			const int sample = (int)inputSamples[i];
			const uint32_t magnitude = (uint32_t)(sample < 0 ? -sample : sample);
			if (magnitude > peak) peak = magnitude;
			absSum += magnitude;
		}

		unsigned char opusBuffer[512];
		int encoded = opus_encode(_opusEncoder, inputSamples, kPcmFrameSamples, opusBuffer, sizeof(opusBuffer));
		if (encoded <= 0) {
			return 0;
		}

		rtc::CopyOnWriteBuffer packet;
		unsigned char header[12];
		header[0] = 0x80;
		header[1] = (uint8_t)(111 | (_sentPackets == 0 ? 0x80 : 0x00));
		uint16_t seq = htons(_rtpSeq++);
		uint32_t timestamp = htonl(_rtpTimestamp);
		uint32_t ssrc = htonl(314366526U);
		memcpy(header + 2, &seq, sizeof(seq));
		memcpy(header + 4, &timestamp, sizeof(timestamp));
		memcpy(header + 8, &ssrc, sizeof(ssrc));
		packet.AppendData(header, sizeof(header));
		packet.AppendData(opusBuffer, (size_t)encoded);
		_rtpTimestamp += kRtpFrameTicks;

		std::vector<uint8_t> queuedPacket((const uint8_t *)packet.data(), (const uint8_t *)packet.data() + packet.size());
		size_t outgoingQueueDepth = 0;
		pthread_mutex_lock(&_outgoingPacketsMutex);
		if (!_shuttingDown) {
			while (_outgoingRtpPackets.size() >= 2) {
				_outgoingRtpPackets.pop_front();
				_outgoingDroppedPackets++;
			}
			_outgoingRtpPackets.push_back(queuedPacket);
			outgoingQueueDepth = _outgoingRtpPackets.size();
			pthread_cond_signal(&_outgoingPacketsCond);
		}
		pthread_mutex_unlock(&_outgoingPacketsMutex);
		_sentPackets++;
		if ((_sentPackets % 100) == 0) {
			syslog(LOG_NOTICE,
				"IOS6LAT capture packets=%u q=%lu dropped=%u opus=%d peak=%u avg=%u",
				(unsigned int)_sentPackets,
				(unsigned long)outgoingQueueDepth,
				(unsigned int)_outgoingDroppedPackets,
				encoded,
				(unsigned int)peak,
				(unsigned int)(absSum / (uint64_t)kPcmFrameSamples));
		}
		return 0;
	}

	static void *OutgoingPacketsThreadEntry(void *param) {
		((MediaManager *)param)->outgoingPacketsLoop();
		return NULL;
	}

	void outgoingPacketsLoop() {
		while (true) {
			std::vector<uint8_t> packetBytes;
			pthread_mutex_lock(&_outgoingPacketsMutex);
			while (!_shuttingDown && _outgoingRtpPackets.empty()) {
				pthread_cond_wait(&_outgoingPacketsCond, &_outgoingPacketsMutex);
			}
			if (_shuttingDown && _outgoingRtpPackets.empty()) {
				pthread_mutex_unlock(&_outgoingPacketsMutex);
				break;
			}
			packetBytes = _outgoingRtpPackets.front();
			_outgoingRtpPackets.pop_front();
			pthread_mutex_unlock(&_outgoingPacketsMutex);

			if (_shuttingDown || !_sendTransportMessage || packetBytes.empty()) {
				continue;
			}
			rtc::CopyOnWriteBuffer packet;
			packet.AppendData(packetBytes.data(), packetBytes.size());
			Message message;
			message.data = AudioDataMessage{ packet };
			_sendTransportMessage(std::move(message));
		}
	}

	void tickPlayoutJitter() {
		++_jitterTickCounter;
		if ((_jitterTickCounter % 5U) != 0U) {
			return;
		}
		std::tr1::shared_ptr<tgvoip::JitterBuffer> jitter;
		pthread_mutex_lock(&_playoutMutex);
		jitter = _jitterBuffer;
		pthread_mutex_unlock(&_playoutMutex);
		if (jitter) {
			jitter->Tick();
		}
	}

	bool configurePlayout(uint32_t frameDurationMs) {
		if (_audioOutput.get() == NULL || frameDurationMs < 20U || frameDurationMs > 80U || (frameDurationMs % 20U) != 0U) {
			return false;
		}

		pthread_mutex_lock(&_playoutMutex);
		if (_playoutReady && _playoutFrameDurationMs == frameDurationMs) {
			pthread_mutex_unlock(&_playoutMutex);
			return true;
		}

		if (_playoutReady && _audioOutput) {
			_audioOutput->Stop();
		}
		if (_opusPlayoutDecoder) {
			_opusPlayoutDecoder->Stop();
			_opusPlayoutDecoder.reset();
		}
		_jitterBuffer.reset();

		_jitterBuffer = std::tr1::shared_ptr<tgvoip::JitterBuffer>(
			new tgvoip::JitterBuffer(NULL, frameDurationMs)
		);
		if (frameDurationMs > 50U) {
			_jitterBuffer->SetMinPacketCount(3);
		} else if (frameDurationMs > 30U) {
			_jitterBuffer->SetMinPacketCount(4);
		} else {
			_jitterBuffer->SetMinPacketCount(6);
		}

		_opusPlayoutDecoder = std::tr1::shared_ptr<tgvoip::OpusDecoder>(
			new tgvoip::OpusDecoder(_audioOutput.get(), true, false)
		);
		_opusPlayoutDecoder->SetJitterBuffer(_jitterBuffer);
		_opusPlayoutDecoder->SetFrameDuration(frameDurationMs);
		_opusPlayoutDecoder->Start();
		_playoutFrameDurationMs = frameDurationMs;
		_playoutReady = true;
		const bool shouldStart = _isConnected && !_shuttingDown;
		pthread_mutex_unlock(&_playoutMutex);

		if (shouldStart && _audioOutput) {
			_audioOutput->Start();
		}

		syslog(LOG_NOTICE,
			"IOS6LAT playout.configure rate=%u frameMs=%u minPackets=%u",
			(unsigned int)kPcmSampleRate,
			(unsigned int)frameDurationMs,
			(unsigned int)(frameDurationMs > 50U ? 3U : (frameDurationMs > 30U ? 4U : 6U)));
		return true;
	}

	void handleIncomingRtp(const rtc::CopyOnWriteBuffer &packet) {
		if (_shuttingDown || packet.size() <= 12) {
			return;
		}

		const uint8_t *bytes = (const uint8_t *)packet.data();
		const size_t packetSize = packet.size();
		size_t headerLength = 12 + ((bytes[0] & 0x0f) * 4);
		if (packetSize < headerLength) {
			return;
		}

		if ((bytes[0] & 0x10) != 0) {
			if (packetSize < headerLength + 4) {
				return;
			}
			const uint16_t extensionWords =
				(uint16_t)(((uint16_t)bytes[headerLength + 2] << 8) |
					(uint16_t)bytes[headerLength + 3]);
			const size_t extensionLength = 4 + ((size_t)extensionWords * 4);
			if (packetSize < headerLength + extensionLength) {
				return;
			}
			headerLength += extensionLength;
		}

		size_t payloadEnd = packetSize;
		if ((bytes[0] & 0x20) != 0) {
			const uint8_t padding = bytes[packetSize - 1];
			if (padding == 0 || padding > payloadEnd - headerLength) {
				return;
			}
			payloadEnd -= padding;
		}
		if (payloadEnd <= headerLength) {
			return;
		}

		const unsigned char *opusPayload = bytes + headerLength;
		const opus_int32 opusLength = (opus_int32)(payloadEnd - headerLength);
		const int packetSamples = opus_packet_get_nb_samples(
			opusPayload,
			opusLength,
			kPcmSampleRate);
		if (packetSamples <= 0) {
			++_decodeErrors;
			return;
		}

		const uint32_t frameDurationMs =
			(uint32_t)(((uint64_t)packetSamples * 1000ULL) / (uint64_t)kPcmSampleRate);
		if (!configurePlayout(frameDurationMs)) {
			++_decodeErrors;
			return;
		}

		const uint16_t sequence =
			(uint16_t)(((uint16_t)bytes[2] << 8) | (uint16_t)bytes[3]);
		const uint32_t rtpTimestamp =
			((uint32_t)bytes[4] << 24) |
			((uint32_t)bytes[5] << 16) |
			((uint32_t)bytes[6] << 8) |
			(uint32_t)bytes[7];
		const uint32_t timestampMs =
			rtpTimestamp / (uint32_t)(kRtpClockRate / 1000);

		std::tr1::shared_ptr<tgvoip::JitterBuffer> jitter;
		pthread_mutex_lock(&_playoutMutex);
		jitter = _jitterBuffer;
		pthread_mutex_unlock(&_playoutMutex);
		if (!jitter) {
			return;
		}

		jitter->HandleInput(
			(unsigned char *)opusPayload,
			(size_t)opusLength,
			timestampMs,
			false);

		++_receivedPackets;
		if (_signalBarsUpdated && (_receivedPackets % 20) == 0) {
			_signalBarsUpdated(4);
		}
		if (_audioLevelUpdated && (_receivedPackets % 20) == 0) {
			_audioLevelUpdated(1.0f);
		}
		if ((_receivedPackets % 50) == 0) {
			syslog(LOG_NOTICE,
				"IOS6LAT playout packets=%u seq=%u frameMs=%u jitterPackets=%u jitterMs=%u minPackets=%d avgDelay=%.2f jitter=%.3f decodeErr=%u",
				(unsigned int)_receivedPackets,
				(unsigned int)sequence,
				(unsigned int)frameDurationMs,
				(unsigned int)jitter->GetCurrentDelay(),
				(unsigned int)(jitter->GetCurrentDelay() * frameDurationMs),
				jitter->GetMinPacketCount(),
				jitter->GetAverageDelay(),
				jitter->GetLastMeasuredJitter(),
				(unsigned int)_decodeErrors);
		}
	}

private:
	bool _isOutgoing = false;
	bool _started = false;
	bool _isConnected = false;
	bool _muted = false;
	bool _shuttingDown = false;
	bool _outgoingAudioTransportEnabled = false;
	uint16_t _rtpSeq = 1;
	uint32_t _rtpTimestamp = 0;
	uint32_t _sentPackets = 0;
	uint32_t _receivedPackets = 0;
	uint32_t _outgoingDroppedPackets = 0;
	uint32_t _decodeErrors = 0;
	uint32_t _jitterTickCounter = 0;
	OpusEncoder *_opusEncoder = NULL;
	std::tr1::shared_ptr<tgvoip::JitterBuffer> _jitterBuffer;
	std::tr1::shared_ptr<tgvoip::OpusDecoder> _opusPlayoutDecoder;
	uint32_t _playoutFrameDurationMs = 0;
	bool _playoutReady = false;
	MessageCallback _sendSignalingMessage;
	MessageCallback _sendTransportMessage;
	std::function<void(int)> _signalBarsUpdated;
	std::function<void(float)> _audioLevelUpdated;
	std::unique_ptr<tgvoip::audio::AudioUnitIO> _audioUnit;
	std::unique_ptr<tgvoip::audio::AudioInput> _audioInput;
	std::unique_ptr<tgvoip::audio::AudioOutput> _audioOutput;
	enum {
		kPcmSampleRate = 48000,
		kPcmFrameSamples = 960,
		kRtpClockRate = 48000,
		kRtpFrameTicks = 960
	};
	pthread_mutex_t _playoutMutex;
	pthread_t _outgoingPacketsThread;
	bool _outgoingPacketsThreadStarted = false;
	pthread_mutex_t _outgoingPacketsMutex;
	pthread_cond_t _outgoingPacketsCond;
	std::deque<std::vector<uint8_t> > _outgoingRtpPackets;
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
