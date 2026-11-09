#include "MediaManager.h"

#include "media/VideoEncoder.h"
#include "media/VideoProfile.h"
#include "rtp/RtpByteIO.h"
#include "rtp/RtpPacket.h"
#include "rtp/RtpTime.h"
#include "rtp/TransportFeedbackGenerator.h"
#include "Ios6DiagnosticLog.h"

#include <string.h>

namespace tgcalls {

namespace {

const int kTickIntervalMs = 100;
const unsigned int kRtcpReportTicks = 10;
const size_t kIncomingQueueLimit = 512;
const int64_t kMediaTimeoutMicros = 2500000;
const int64_t kRemoteReportTimeoutMicros = 6000000;
const int kAudioReserveBitrate = 48000;
const int kMinVideoBitrate = 30000;

class ScopedLock {
public:
    explicit ScopedLock(pthread_mutex_t *mutex) : _mutex(mutex) { pthread_mutex_lock(_mutex); }
    ~ScopedLock() { pthread_mutex_unlock(_mutex); }

private:
    pthread_mutex_t *_mutex;
};

std::string MakeCname() {
    static const char kAlphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string result;
    for (int i = 0; i < 16; ++i) {
        result.push_back(kAlphabet[arc4random() % 64]);
    }
    return result;
}

}

class MediaManager::Router : public MediaTransport::Receiver {
public:
    Router(rtc::Thread *thread, const std::weak_ptr<MediaManager> &owner) :
    _thread(thread),
    _owner(owner),
    _drainScheduled(false),
    _audioSsrc(0),
    _videoSsrc(0),
    _videoRtxSsrc(0),
    _dropped(0) {
        pthread_mutex_init(&_mutex, 0);
    }

    ~Router() noexcept {
        clear();
        pthread_mutex_destroy(&_mutex);
    }

    void setAudioRoute(uint32_t ssrc, const rtp::RtpExtensionMap &extensions) {
        ScopedLock lock(&_mutex);
        _audioSsrc = ssrc;
        _audioExtensions = extensions;
    }

    void setVideoRoute(const std::shared_ptr<VideoReceiveStream> &stream) {
        ScopedLock lock(&_mutex);
        _video = stream;
        if (stream) {
            _videoSsrc = stream->configuration().ssrc;
            _videoRtxSsrc = stream->configuration().rtxSsrc;
            _videoExtensions = stream->configuration().extensions;
        } else {
            _videoSsrc = 0;
            _videoRtxSsrc = 0;
            _videoExtensions.clear();
        }
    }

    rtp::TransportFeedbackGenerator &feedback() {
        return _feedback;
    }

    void onIncomingRtp(rtp::MediaPacketRef &&packet) override {
        std::shared_ptr<VideoReceiveStream> video;
        bool audio = false;
        {
            ScopedLock lock(&_mutex);
            const uint32_t ssrc = packet->ssrc;
            const rtp::RtpExtensionMap *extensions = 0;
            if (ssrc != 0 && ssrc == _audioSsrc) {
                audio = true;
                extensions = &_audioExtensions;
            } else if (ssrc != 0 && (ssrc == _videoSsrc || ssrc == _videoRtxSsrc)) {
                video = _video;
                extensions = &_videoExtensions;
            } else {
                ++_dropped;
                return;
            }
            rtp::RtpPacketView view;
            uint16_t transportSequence = 0;
            if (extensions->isRegistered(rtp::RtpExtensionTransportSequenceNumber) && view.parse(packet->data(), packet->size()) && extensions->readTransportSequenceNumber(view, &transportSequence)) {
                _feedback.onPacket(transportSequence, packet->timeMicros);
            }
        }
        if (audio) {
            packet->kind = rtp::MediaPacketAudio;
            enqueue(std::move(packet));
        } else if (video) {
            packet->kind = rtp::MediaPacketVideo;
            video->enqueuePacket(std::move(packet));
        }
    }

    void onIncomingRtcp(rtp::MediaPacketRef &&packet) override {
        enqueue(std::move(packet));
    }

    void take(std::deque<rtp::MediaPacket *> &target) {
        ScopedLock lock(&_mutex);
        target.swap(_queue);
        _drainScheduled = false;
    }

    void clear() {
        std::deque<rtp::MediaPacket *> pending;
        {
            ScopedLock lock(&_mutex);
            pending.swap(_queue);
            _video.reset();
        }
        for (size_t i = 0; i < pending.size(); ++i) {
            rtp::MediaPacketRef dropped(pending[i]);
        }
    }

private:
    void enqueue(rtp::MediaPacketRef &&packet) {
        bool schedule = false;
        rtp::MediaPacketRef dropped;
        {
            ScopedLock lock(&_mutex);
            if (_queue.size() >= kIncomingQueueLimit) {
                dropped = rtp::MediaPacketRef(_queue.front());
                _queue.pop_front();
                ++_dropped;
            }
            _queue.push_back(packet.release());
            if (!_drainScheduled) {
                _drainScheduled = true;
                schedule = true;
            }
        }
        if (schedule) {
            const std::weak_ptr<MediaManager> owner = _owner;
            _thread->PostTask([owner]() {
                if (const std::shared_ptr<MediaManager> strong = owner.lock()) {
                    strong->drainIncoming();
                }
            });
        }
    }

    rtc::Thread *_thread;
    std::weak_ptr<MediaManager> _owner;
    pthread_mutex_t _mutex;
    std::deque<rtp::MediaPacket *> _queue;
    bool _drainScheduled;
    uint32_t _audioSsrc;
    uint32_t _videoSsrc;
    uint32_t _videoRtxSsrc;
    rtp::RtpExtensionMap _audioExtensions;
    rtp::RtpExtensionMap _videoExtensions;
    std::shared_ptr<VideoReceiveStream> _video;
    rtp::TransportFeedbackGenerator _feedback;
    uint32_t _dropped;
};

class MediaManager::SendObserver : public MediaTransport::SendObserver {
public:
    explicit SendObserver(BandwidthEstimator *estimator) : _estimator(estimator) {
    }

    void onPacketSent(const MediaTransport::SentPacketInfo &info) override {
        if (info.hasTransportSequenceNumber) {
            _estimator->onPacketSent(info.transportSequenceNumber, info.sendTimeMicros, info.size);
        }
    }

private:
    BandwidthEstimator *_estimator;
};

class MediaManager::RtcpReceiver : public rtp::RtcpHandler {
public:
    RtcpReceiver(MediaManager *manager, int64_t arrivalMicros) : _manager(manager), _arrivalMicros(arrivalMicros) {
    }

    void onSenderReport(uint32_t senderSsrc, const rtp::RtcpSenderInfo &info) override {
        if (_manager->_audioChannel && senderSsrc == _manager->_audioChannel->incomingSsrc() && senderSsrc != 0) {
            _manager->_audioChannel->receiveStatistics().onSenderReport(info, _arrivalMicros);
        }
        if (_manager->_videoReceive && senderSsrc == _manager->_videoReceive->configuration().ssrc) {
            _manager->_videoReceive->onSenderReport(info, _arrivalMicros);
        }
    }

    void onReportBlock(uint32_t, const rtp::RtcpReportBlock &block) override {
        const bool audio = block.sourceSsrc == _manager->_localAudioSsrc && _manager->_localAudioSsrc != 0;
        const bool video = _manager->_videoSend && block.sourceSsrc == _manager->_videoSend->configuration().ssrc;
        if (!audio && !video) {
            return;
        }
        _manager->_rtt.onReportBlock(block, rtp::NtpNow());
        if (audio || !_manager->_audioChannel->receiveStatistics().hasPackets()) {
            _manager->_remoteReportedLoss = (float)block.fractionLost / 256.0f;
            _manager->_lastRemoteReportMicros = _arrivalMicros;
        }
        if (_manager->_rtt.hasValue()) {
            _manager->_bandwidthEstimator->onRtt(_manager->_rtt.smoothedMicros());
        }
    }

    void onNack(uint32_t, uint32_t mediaSsrc, const uint16_t *sequences, size_t count) override {
        if (_manager->_videoSend && mediaSsrc == _manager->_videoSend->configuration().ssrc) {
            _manager->_videoSend->onNack(sequences, count, _manager->_rtt.hasValue() ? _manager->_rtt.smoothedMicros() : 0);
        }
    }

    void onPictureLossIndication(uint32_t, uint32_t mediaSsrc) override {
        if (_manager->_videoSend && mediaSsrc == _manager->_videoSend->configuration().ssrc) {
            _manager->_videoSend->requestKeyframe();
        }
    }

    void onFullIntraRequest(uint32_t, uint32_t mediaSsrc, uint8_t) override {
        if (_manager->_videoSend && mediaSsrc == _manager->_videoSend->configuration().ssrc) {
            _manager->_videoSend->requestKeyframe();
        }
    }

    void onReceiverEstimatedMaxBitrate(uint32_t, uint64_t bitrate, const uint32_t *, size_t) override {
        _manager->_bandwidthEstimator->onReceiverEstimate(bitrate, _arrivalMicros);
    }

    void onTransportFeedback(uint32_t, uint32_t, const uint8_t *fci, size_t size) override {
        rtp::TransportFeedback feedback;
        if (feedback.parse(fci, size)) {
            _manager->_bandwidthEstimator->onTransportFeedback(feedback, _arrivalMicros);
        }
    }

private:
    MediaManager *_manager;
    int64_t _arrivalMicros;
};

MediaManager::MediaManager(
	rtc::Thread *thread,
	bool,
	ProtocolVersion,
	const MediaDevicesConfig &,
	std::shared_ptr<VideoCaptureInterface>,
	MessageCallback,
	MessageCallback,
	std::function<void(int)> signalBarsUpdated,
	std::function<void(float)> audioLevelUpdated,
	std::function<webrtc::scoped_refptr<webrtc::AudioDeviceModule>(webrtc::TaskQueueFactory*)>,
	bool,
	std::vector<std::string>,
	std::shared_ptr<MediaTransport> mediaTransport,
	std::shared_ptr<VideoSourceHub> outgoingVideoSource,
	std::shared_ptr<VideoSinkHub> incomingVideoSink) :
_thread(thread),
_signalBarsUpdated(signalBarsUpdated),
_audioLevelUpdated(audioLevelUpdated),
_mediaTransport(mediaTransport),
_outgoingVideoSource(outgoingVideoSource),
_incomingVideoSink(incomingVideoSink),
_cname(MakeCname()) {
	_audioChannel.reset(new AudioChannel(_mediaTransport));
	const VideoProfile &profile = VideoProfile::current();
	BandwidthEstimator::Configuration configuration;
	configuration.startBitrate = (profile.startBitrate > 0 ? profile.startBitrate : 300000) + kAudioReserveBitrate;
	configuration.maxBitrate = (profile.maxSendBitrate > 0 ? profile.maxSendBitrate : 300000) + kAudioReserveBitrate;
	_bandwidthEstimator.reset(new BandwidthEstimator(configuration));
	_receiveLimit = profile.maxReceiveBitrate;
	syslog(LOG_NOTICE, "IOS6MEDIA profile machine=%s send=%d maxSend=%d maxReceive=%d steps=%lu",
		profile.machine.c_str(),
		profile.canSend ? 1 : 0,
		profile.maxSendBitrate,
		profile.maxReceiveBitrate,
		(unsigned long)profile.ladder.size());
}

MediaManager::~MediaManager() noexcept {
	_mediaTransport->setReceiver(std::shared_ptr<MediaTransport::Receiver>());
	_mediaTransport->setSendObserver(std::shared_ptr<MediaTransport::SendObserver>());
	if (_router) {
		_router->clear();
	}
	if (_outgoingVideoSource) {
		_outgoingVideoSource->setConsumer(std::shared_ptr<VideoFrameSink>());
	}
	_videoSend.reset();
	_videoReceive.reset();
	_audioChannel.reset();
}

void MediaManager::start() {
	if (_started) {
		return;
	}
	_started = true;
	_router.reset(new Router(_thread, shared_from_this()));
	_sendObserver.reset(new SendObserver(_bandwidthEstimator.get()));
	_mediaTransport->setReceiver(_router);
	_mediaTransport->setSendObserver(_sendObserver);
	_audioChannel->start();
	if (_isConnected) {
		_audioChannel->setConnected(true);
	}
	setNegotiatedMedia(_media, _localAudioSsrc, _localVideoSsrc);
	scheduleTick(kTickIntervalMs);
}

void MediaManager::setIsConnected(bool isConnected) {
	if (_isConnected == isConnected) {
		return;
	}
	_isConnected = isConnected;
	_audioChannel->setConnected(isConnected);
	if (isConnected && _videoReceive) {
		_videoReceive->requestKeyframe();
	}
	syslog(LOG_NOTICE, "IOS6MEDIA media.connected value=%d", isConnected ? 1 : 0);
}

void MediaManager::setMuteOutgoingAudio(bool mute) {
	_audioChannel->setMuted(mute);
}

void MediaManager::setNegotiatedMedia(const NegotiatedMedia &media, uint32_t localAudioSsrc, uint32_t localVideoSsrc) {
	_media = media;
	_localAudioSsrc = localAudioSsrc;
	_localVideoSsrc = localVideoSsrc;

	AudioChannel::OutgoingConfiguration outgoing;
	outgoing.ssrc = localAudioSsrc;
	outgoing.payloadType = 111;
	if (media.outgoingAudio.active && !media.outgoingAudio.payloadTypes.empty()) {
		outgoing.payloadType = media.outgoingAudio.payloadTypes[0].id;
		if (media.outgoingAudio.payloadTypes[0].transportFeedback) {
			outgoing.extensions = media.outgoingAudio.extensions;
		}
	}
	_audioChannel->setOutgoingConfiguration(outgoing);

	if (media.incomingAudio.active && !media.incomingAudio.payloadTypes.empty()) {
		_audioChannel->setIncoming(media.incomingAudio.ssrc, media.incomingAudio.payloadTypes[0].id);
	} else {
		_audioChannel->setIncoming(0, 0);
	}
	if (!_started) {
		return;
	}
	_router->setAudioRoute(media.incomingAudio.active ? media.incomingAudio.ssrc : 0, media.incomingAudio.extensions);
	configureVideoReceive();
	configureVideoSend();
	syslog(LOG_NOTICE, "IOS6MEDIA media.negotiated revision=%u inAudio=%u/%d outAudio=%u/%d inVideo=%u/%d outVideo=%u/%d",
		(unsigned int)media.revision,
		(unsigned int)media.incomingAudio.ssrc,
		media.incomingAudio.active ? 1 : 0,
		(unsigned int)localAudioSsrc,
		media.outgoingAudio.active ? 1 : 0,
		(unsigned int)media.incomingVideo.ssrc,
		media.incomingVideo.active ? 1 : 0,
		(unsigned int)media.outgoingVideo.ssrc,
		media.outgoingVideo.active ? 1 : 0);
}

void MediaManager::configureVideoReceive() {
	const NegotiatedStream &stream = _media.incomingVideo;
	if (!stream.active || stream.payloadTypes.empty()) {
		if (_videoReceive) {
			_router->setVideoRoute(std::shared_ptr<VideoReceiveStream>());
			_videoReceive.reset();
		}
		return;
	}
	if (_videoReceive) {
		const VideoReceiveStream::Configuration &current = _videoReceive->configuration();
		bool samePayloads = current.payloadTypes.size() == stream.payloadTypes.size();
		for (size_t i = 0; samePayloads && i < stream.payloadTypes.size(); ++i) {
			samePayloads = current.payloadTypes[i].id == stream.payloadTypes[i].id && current.payloadTypes[i].rtxId == stream.payloadTypes[i].rtxId;
		}
		if (current.ssrc == stream.ssrc && current.rtxSsrc == stream.rtxSsrc && samePayloads) {
			return;
		}
		_router->setVideoRoute(std::shared_ptr<VideoReceiveStream>());
		_videoReceive.reset();
	}
	VideoReceiveStream::Configuration configuration;
	configuration.ssrc = stream.ssrc;
	configuration.rtxSsrc = stream.rtxSsrc;
	configuration.localSsrc = _localVideoSsrc != 0 ? _localVideoSsrc : _localAudioSsrc;
	configuration.payloadTypes = stream.payloadTypes;
	configuration.extensions = stream.extensions;
	_videoReceive.reset(new VideoReceiveStream(configuration, _mediaTransport, _incomingVideoSink));
	if (_rtt.hasValue()) {
		_videoReceive->setRtt(_rtt.smoothedMicros());
	}
	_router->setVideoRoute(_videoReceive);
}

void MediaManager::configureVideoSend() {
	const NegotiatedStream &stream = _media.outgoingVideo;
	const NegotiatedPayloadType *chosen = 0;
	if (stream.active) {
		const std::vector<VideoCodecSupport> encoders = SupportedVideoEncoders();
		for (size_t i = 0; i < encoders.size() && chosen == 0; ++i) {
			for (size_t j = 0; j < stream.payloadTypes.size(); ++j) {
				if (VideoCodecTypeFromName(stream.payloadTypes[j].name) == VideoCodecTypeFromName(encoders[i].name)) {
					chosen = &stream.payloadTypes[j];
					break;
				}
			}
		}
	}
	if (chosen == 0) {
		if (_videoSend) {
			_outgoingVideoSource->setConsumer(std::shared_ptr<VideoFrameSink>());
			_videoSend.reset();
			_mediaTransport->setPacingRate(0);
		}
		return;
	}
	if (_videoSend) {
		const VideoSendStream::Configuration &current = _videoSend->configuration();
		if (current.ssrc == stream.ssrc && current.payloadType == chosen->id && current.rtxSsrc == stream.rtxSsrc) {
			return;
		}
		_outgoingVideoSource->setConsumer(std::shared_ptr<VideoFrameSink>());
		_videoSend.reset();
	}
	VideoSendStream::Configuration configuration;
	configuration.ssrc = stream.ssrc;
	configuration.rtxSsrc = chosen->hasRtx ? stream.rtxSsrc : 0;
	configuration.payloadType = chosen->id;
	configuration.hasRtx = chosen->hasRtx;
	configuration.rtxPayloadType = chosen->rtxId;
	configuration.codec = VideoCodecTypeFromName(chosen->name);
	configuration.extensions = stream.extensions;
	_videoSend.reset(new VideoSendStream(configuration, _mediaTransport, _outgoingVideoSource));
	if (!_videoSend->isValid()) {
		_videoSend.reset();
		return;
	}
	_outgoingVideoSource->setConsumer(_videoSend);
	updateBitrates(rtp::MonotonicMicros());
}

void MediaManager::drainIncoming() {
	if (!_router) {
		return;
	}
	std::deque<rtp::MediaPacket *> packets;
	_router->take(packets);
	for (size_t i = 0; i < packets.size(); ++i) {
		rtp::MediaPacketRef packet(packets[i]);
		if (packet->kind == rtp::MediaPacketRtcp) {
			handleIncomingRtcp(*packet);
		} else {
			handleIncomingRtp(*packet);
		}
	}
}

void MediaManager::handleIncomingRtp(const rtp::MediaPacket &packet) {
	rtp::RtpPacketView view;
	if (!view.parse(packet.data(), packet.size())) {
		return;
	}
	if (packet.kind == rtp::MediaPacketAudio) {
		_audioChannel->handleIncomingRtp(view, packet.timeMicros);
	}
}

void MediaManager::handleIncomingRtcp(const rtp::MediaPacket &packet) {
	RtcpReceiver receiver(this, packet.timeMicros);
	rtp::ParseRtcp(packet.data(), packet.size(), receiver);
}

void MediaManager::scheduleTick(int delayMs) {
	if (_tickScheduled) {
		return;
	}
	_tickScheduled = true;
	const std::weak_ptr<MediaManager> weak(shared_from_this());
	_thread->PostDelayedTask([weak]() {
		const std::shared_ptr<MediaManager> strong = weak.lock();
		if (!strong) {
			return;
		}
		strong->_tickScheduled = false;
		strong->tick();
		strong->scheduleTick(kTickIntervalMs);
	}, webrtc::TimeDelta::Millis(delayMs));
}

void MediaManager::tick() {
	const int64_t now = rtp::MonotonicMicros();
	++_tickCount;
	if (_isConnected && _mediaTransport->isReady()) {
		sendTransportFeedback();
	}
	_bandwidthEstimator->process(now);
	updateBitrates(now);
	if ((_tickCount % kRtcpReportTicks) == 0) {
		updateReceiveLimit(now);
		sendRtcpReport(now);
		updateSignalBars(now);
		logVideoStatistics(now);
		if (_videoReceive && _rtt.hasValue()) {
			_videoReceive->setRtt(_rtt.smoothedMicros());
		}
	}
}

void MediaManager::sendTransportFeedback() {
	const uint32_t sender = _localVideoSsrc != 0 ? _localVideoSsrc : _localAudioSsrc;
	const uint32_t media = _videoReceive ? _videoReceive->configuration().ssrc : _media.incomingAudio.ssrc;
	for (int i = 0; i < 4 && _router->feedback().hasPending(); ++i) {
		rtp::MediaPacketRef packet = _router->feedback().buildPacket(sender, media);
		if (!packet) {
			break;
		}
		packet->timeMicros = rtp::MonotonicMicros();
		_mediaTransport->sendMediaPacket(std::move(packet));
	}
}

void MediaManager::updateBitrates(int64_t nowMicros) {
	const int total = _bandwidthEstimator->targetBitrate();
	int video = total - kAudioReserveBitrate;
	if (video < kMinVideoBitrate) {
		video = kMinVideoBitrate;
	}
	if (_videoSend) {
		_videoSend->setTargetBitrate(video, nowMicros);
		_mediaTransport->setPacingRate((total * 5) / 2);
	}
}

void MediaManager::updateReceiveLimit(int64_t) {
	if (!_videoReceive) {
		return;
	}
	const VideoReceiveStream::Statistics statistics = _videoReceive->statistics();
	if (statistics.decodeLoad > 0.85f) {
		_receiveLimitFactor *= 0.85f;
		if (_receiveLimitFactor < 0.2f) {
			_receiveLimitFactor = 0.2f;
		}
	} else if (statistics.decodeLoad < 0.5f && _receiveLimitFactor < 1.0f) {
		_receiveLimitFactor *= 1.05f;
		if (_receiveLimitFactor > 1.0f) {
			_receiveLimitFactor = 1.0f;
		}
	}
	const VideoProfile &profile = VideoProfile::current();
	_receiveLimit = (int)((float)profile.maxReceiveBitrate * _receiveLimitFactor);
}

void MediaManager::sendRtcpReport(int64_t now) {
	if (!_isConnected || _localAudioSsrc == 0 || !_mediaTransport->isReady()) {
		return;
	}
	rtp::RtcpReportBlock blocks[2];
	size_t blockCount = 0;
	rtp::RtpReceiveStatistics &audioStatistics = _audioChannel->receiveStatistics();
	if (_audioChannel->incomingSsrc() != 0 && audioStatistics.hasPackets() && audioStatistics.makeReportBlock(now, &blocks[blockCount])) {
		++blockCount;
	}
	if (_videoReceive && _videoReceive->makeReportBlock(now, &blocks[blockCount])) {
		++blockCount;
	}
	rtp::MediaPacketRef packet = rtp::AllocateMediaPacket();
	rtp::RtcpWriter writer(packet->data(), packet->capacity() - rtp::MediaPacket::kTailroom);
	const uint64_t ntp = rtp::NtpNow();
	rtp::RtcpSenderInfo senderInfo;
	bool written = false;
	if (_audioChannel->makeSenderInfo(now, ntp, &senderInfo)) {
		written = writer.addSenderReport(_localAudioSsrc, senderInfo, blocks, blockCount);
	} else {
		written = writer.addReceiverReport(_localAudioSsrc, blocks, blockCount);
	}
	if (!written || !writer.addSourceDescription(_localAudioSsrc, _cname.c_str())) {
		return;
	}
	if (_videoSend && _videoSend->makeSenderInfo(now, ntp, &senderInfo)) {
		writer.addSenderReport(_videoSend->configuration().ssrc, senderInfo, 0, 0);
	}
	if (_videoReceive && _receiveLimit > 0) {
		const uint32_t ssrc = _videoReceive->configuration().ssrc;
		writer.addReceiverEstimatedMaxBitrate(_localVideoSsrc != 0 ? _localVideoSsrc : _localAudioSsrc, (uint64_t)_receiveLimit, &ssrc, 1);
	}
	packet->setSize(writer.size());
	packet->kind = rtp::MediaPacketRtcp;
	packet->ssrc = _localAudioSsrc;
	packet->timeMicros = now;
	_mediaTransport->sendMediaPacket(std::move(packet));
}

void MediaManager::logVideoStatistics(int64_t nowMicros) {
	if (nowMicros - _lastStatisticsLogMicros < 5000000 || (!_videoReceive && !_videoSend)) {
		return;
	}
	_lastStatisticsLogMicros = nowMicros;
	if (_videoReceive) {
		const VideoReceiveStream::Statistics statistics = _videoReceive->statistics();
		syslog(LOG_NOTICE, "IOS6MEDIA video.receive frames=%u decoded=%u dropped=%u size=%dx%d decodeMs=%.1f load=%.2f bitrate=%u limit=%d pli=%u nack=%u",
			statistics.framesReceived,
			statistics.framesDecoded,
			statistics.framesDropped,
			statistics.width,
			statistics.height,
			statistics.decodeMillis,
			statistics.decodeLoad,
			statistics.receivedBitrate,
			_receiveLimit,
			statistics.keyframeRequests,
			statistics.nacksSent);
	}
	if (_videoSend) {
		const VideoSendStream::Statistics statistics = _videoSend->statistics();
		syslog(LOG_NOTICE, "IOS6MEDIA video.send captured=%u frames=%u dropped=%u keyframes=%u rtx=%u step=%dx%d@%d target=%d encodeMs=%.1f loss=%.3f rtt=%d",
			statistics.framesCaptured,
			statistics.framesEncoded,
			statistics.framesDropped,
			statistics.keyframes,
			statistics.retransmissions,
			statistics.width,
			statistics.height,
			statistics.fps,
			statistics.targetBitrate,
			statistics.encodeMillis,
			_bandwidthEstimator->lossRate(),
			_rtt.hasValue() ? (int)(_rtt.smoothedMicros() / 1000) : -1);
	}
}

void MediaManager::updateSignalBars(int64_t nowMicros) {
	int bars = 4;
	if (!_isConnected) {
		bars = _signalBars < 0 ? -1 : _signalBars;
	} else {
		const rtp::RtpReceiveStatistics &audioStatistics = _audioChannel->receiveStatistics();
		const bool receiving = audioStatistics.hasPackets() && nowMicros - audioStatistics.lastPacketMicros() < kMediaTimeoutMicros;
		float loss = audioStatistics.recentLossRate();
		if (_lastRemoteReportMicros != 0 && nowMicros - _lastRemoteReportMicros < kRemoteReportTimeoutMicros && _remoteReportedLoss > loss) {
			loss = _remoteReportedLoss;
		}
		const int64_t rtt = _rtt.hasValue() ? _rtt.smoothedMicros() : 0;
		const float jitter = audioStatistics.jitterMillis();
		if (!receiving && audioStatistics.hasPackets()) {
			bars = 1;
		} else if (loss > 0.10f || rtt > 1000000 || jitter > 120.0f) {
			bars = 1;
		} else if (loss > 0.05f || rtt > 600000 || jitter > 60.0f) {
			bars = 2;
		} else if (loss > 0.02f || rtt > 350000 || jitter > 30.0f) {
			bars = 3;
		}
	}
	if (bars >= 0 && bars != _signalBars) {
		_signalBars = bars;
		if (_signalBarsUpdated) {
			_signalBarsUpdated(bars);
		}
	}
}

}
