#include "media/VideoSendStream.h"

#include "media/RtpVideoPacketizer.h"
#include "rtp/RtpByteIO.h"
#include "rtp/RtpTime.h"
#include "Ios6DiagnosticLog.h"

#include <string.h>

namespace tgcalls {

namespace {

const size_t kMaxRtpPacketSize = 1180;
const size_t kReservedHeaderSize = 32;
const int64_t kKeyframeIntervalMicros = 300000;
const int64_t kUpgradeDelayMicros = 4000000;
const int64_t kOverloadDelayMicros = 2000000;
const int64_t kUpgradeBlockMicros = 15000000;
const int64_t kResumeGapMicros = 1000000;
const int64_t kOverloadBackoffMicros = 30000000;
const int64_t kOverloadBackoffLimitMicros = 240000000;

class Lock {
public:
    explicit Lock(pthread_mutex_t *mutex) : _mutex(mutex) { pthread_mutex_lock(_mutex); }
    ~Lock() { pthread_mutex_unlock(_mutex); }

private:
    pthread_mutex_t *_mutex;
};

}

VideoSendStream::VideoSendStream(const Configuration &configuration, const std::shared_ptr<rtp::MediaPacketSink> &transport, const std::shared_ptr<VideoSourceHub> &source) :
_configuration(configuration),
_transport(transport),
_source(source),
_profile(VideoProfile::current()),
_sequenceNumber((uint16_t)arc4random()),
_rtxSequenceNumber((uint16_t)arc4random()),
_pictureId((uint16_t)(arc4random() & 0x7FFF)),
_timestampBase(arc4random()),
_hasTimestampOrigin(false),
_timestampOriginMicros(0),
_targetBitrate(0),
_step(0),
_upgradeCandidateSinceMicros(0),
_overloadSinceMicros(0),
_blockUpgradeUntilMicros(0),
_overloadCeiling(0),
_overloadCeilingUntilMicros(0),
_overloadBackoffMicros(kOverloadBackoffMicros),
_lastCaptureMicros(0),
_keyframeRequested(true),
_lastKeyframeMicros(0),
_encodeMillis(0.0f),
_framesCaptured(0),
_framesEncoded(0),
_framesDropped(0),
_keyframes(0),
_retransmissions(0) {
    pthread_mutex_init(&_mutex, 0);
    for (size_t i = 0; i < kHistorySize; ++i) {
        _history[i].sequenceNumber = 0;
        _history[i].lastSentMicros = 0;
    }
    _sendStatistics.reset(configuration.ssrc, 90000);
    _encoder = CreateVideoEncoder(configuration.codec, this);
    _ladder = (_encoder && !_encoder->isHardwareAccelerated()) ? _profile.softwareLadder : _profile.ladder;
    if (!_ladder.empty()) {
        _step = _profile.initialStepIndex(_ladder);
        const VideoLadderStep &step = _ladder[_step];
        _source->requestFormat(step.width, step.height, step.fps);
        if (_encoder) {
            _encoder->setMaxResolution(step.width, step.height);
            _encoder->setRates(_profile.startBitrate, step.fps);
        }
    }
    syslog(LOG_NOTICE, "IOS6MEDIA video.send.start ssrc=%u rtx=%u pt=%u codec=%s encoder=%d hardware=%d steps=%lu",
        (unsigned int)configuration.ssrc,
        (unsigned int)configuration.rtxSsrc,
        (unsigned int)configuration.payloadType,
        VideoCodecName(configuration.codec),
        _encoder ? 1 : 0,
        (_encoder && _encoder->isHardwareAccelerated()) ? 1 : 0,
        (unsigned long)_ladder.size());
}

VideoSendStream::~VideoSendStream() noexcept {
    _encoder.reset();
    pthread_mutex_destroy(&_mutex);
}

void VideoSendStream::onVideoFrame(const VideoFrame &frame) {
    if (!_encoder || !frame.buffer) {
        return;
    }
    bool keyframe = false;
    {
        Lock lock(&_mutex);
        ++_framesCaptured;
        const int fps = _ladder.empty() ? 30 : _ladder[_step].fps;
        const int64_t interval = 1000000 / (fps > 0 ? fps : 30);
        if (_lastCaptureMicros != 0 && frame.timestampMicros - _lastCaptureMicros < interval - interval / 6) {
            ++_framesDropped;
            return;
        }
        if (_lastCaptureMicros != 0 && frame.timestampMicros - _lastCaptureMicros > kResumeGapMicros) {
            _keyframeRequested = true;
            _lastKeyframeMicros = 0;
        }
        _lastCaptureMicros = frame.timestampMicros;
        const int64_t now = rtp::MonotonicMicros();
        if (_keyframeRequested && now - _lastKeyframeMicros >= kKeyframeIntervalMicros) {
            keyframe = true;
            _keyframeRequested = false;
            _lastKeyframeMicros = now;
        }
    }
    _encoder->encode(frame, keyframe);
}

uint32_t VideoSendStream::rtpTimestamp(int64_t captureMicros) {
    if (!_hasTimestampOrigin) {
        _hasTimestampOrigin = true;
        _timestampOriginMicros = captureMicros;
    }
    const int64_t elapsed = captureMicros - _timestampOriginMicros;
    return _timestampBase + (uint32_t)((elapsed * 9) / 100);
}

void VideoSendStream::onEncodedFrame(const EncodedVideoFrame &frame, int64_t captureMicros, float encodeMillis) {
    std::vector<std::vector<uint8_t> > payloads;
    uint16_t pictureId = 0;
    {
        Lock lock(&_mutex);
        pictureId = _pictureId;
        _pictureId = (uint16_t)((_pictureId + 1) & 0x7FFF);
    }
    if (!RtpVideoPacketizer::packetize(frame, kMaxRtpPacketSize - kReservedHeaderSize, pictureId, payloads)) {
        return;
    }
    std::vector<rtp::MediaPacket *> packets;
    packets.reserve(payloads.size());
    {
        Lock lock(&_mutex);
        _encodeMillis = _encodeMillis == 0.0f ? encodeMillis : _encodeMillis * 0.9f + encodeMillis * 0.1f;
        ++_framesEncoded;
        if (frame.keyframe) {
            ++_keyframes;
        }
        const uint32_t timestamp = rtpTimestamp(captureMicros);
        const int64_t now = rtp::MonotonicMicros();
        for (size_t i = 0; i < payloads.size(); ++i) {
            const bool last = i + 1 == payloads.size();
            rtp::MediaPacketRef packet = rtp::AllocateMediaPacket();
            rtp::RtpPacketWriter writer(packet->data(), packet->capacity() - rtp::MediaPacket::kTailroom);
            writer.setHeader(_configuration.payloadType, last, _sequenceNumber, timestamp, _configuration.ssrc);
            size_t transportOffset = 0;
            if (writer.addTransportSequenceNumber(_configuration.extensions, &transportOffset)) {
                packet->transportSequenceOffset = transportOffset;
            }
            size_t absSendTimeOffset = 0;
            if (writer.addAbsSendTime(_configuration.extensions, &absSendTimeOffset)) {
                packet->absSendTimeOffset = absSendTimeOffset;
            }
            if (last) {
                writer.addVideoRotation(_configuration.extensions, frame.rotation);
            }
            uint8_t *target = writer.payload();
            if (target == 0 || writer.payloadCapacity() < payloads[i].size()) {
                continue;
            }
            memcpy(target, &payloads[i][0], payloads[i].size());
            const size_t size = writer.finish(payloads[i].size());
            if (size == 0) {
                continue;
            }
            packet->setSize(size);
            packet->kind = rtp::MediaPacketVideo;
            packet->ssrc = _configuration.ssrc;
            packet->sequenceNumber = _sequenceNumber;
            packet->timeMicros = now;
            packet->isKeyframe = frame.keyframe;
            HistoryEntry &entry = _history[_sequenceNumber & (kHistorySize - 1)];
            entry.packet = packet.clone();
            entry.sequenceNumber = _sequenceNumber;
            entry.lastSentMicros = now;
            _sendStatistics.onPacketSent(timestamp, captureMicros, payloads[i].size());
            ++_sequenceNumber;
            packets.push_back(packet.release());
        }
    }
    for (size_t i = 0; i < packets.size(); ++i) {
        _transport->sendMediaPacket(rtp::MediaPacketRef(packets[i]));
    }
}

rtp::MediaPacketRef VideoSendStream::makeRetransmission(const rtp::MediaPacket &original) {
    rtp::RtpPacketView view;
    if (!view.parse(original.data(), original.size())) {
        return rtp::MediaPacketRef();
    }
    rtp::MediaPacketRef packet = rtp::AllocateMediaPacket();
    if (!_configuration.hasRtx || _configuration.rtxSsrc == 0) {
        if (!packet->assign(original.data(), original.size())) {
            return rtp::MediaPacketRef();
        }
        packet->transportSequenceOffset = original.transportSequenceOffset;
        packet->absSendTimeOffset = original.absSendTimeOffset;
        packet->ssrc = original.ssrc;
        packet->sequenceNumber = original.sequenceNumber;
    } else {
        const size_t header = view.headerSize();
        const size_t payload = view.payloadSize();
        if (header + 2 + payload > packet->capacity() - rtp::MediaPacket::kTailroom) {
            return rtp::MediaPacketRef();
        }
        uint8_t *data = packet->data();
        memcpy(data, original.data(), header);
        data[0] &= (uint8_t)~0x20;
        data[1] = (uint8_t)((data[1] & 0x80) | (_configuration.rtxPayloadType & 0x7F));
        rtp::WriteU16(data + 2, _rtxSequenceNumber);
        rtp::WriteU32(data + 8, _configuration.rtxSsrc);
        rtp::WriteU16(data + header, view.sequenceNumber());
        memcpy(data + header + 2, view.payload(), payload);
        packet->setSize(header + 2 + payload);
        packet->transportSequenceOffset = original.transportSequenceOffset;
        packet->absSendTimeOffset = original.absSendTimeOffset;
        packet->ssrc = _configuration.rtxSsrc;
        packet->sequenceNumber = _rtxSequenceNumber;
        ++_rtxSequenceNumber;
    }
    packet->kind = rtp::MediaPacketRetransmission;
    packet->timeMicros = rtp::MonotonicMicros();
    return packet;
}

void VideoSendStream::onNack(const uint16_t *sequenceNumbers, size_t count, int64_t rttMicros) {
    std::vector<rtp::MediaPacket *> packets;
    {
        Lock lock(&_mutex);
        const int64_t now = rtp::MonotonicMicros();
        const int64_t minimumInterval = rttMicros > 0 ? (rttMicros * 4) / 5 : 50000;
        for (size_t i = 0; i < count && packets.size() < 64; ++i) {
            HistoryEntry &entry = _history[sequenceNumbers[i] & (kHistorySize - 1)];
            if (!entry.packet || entry.sequenceNumber != sequenceNumbers[i]) {
                continue;
            }
            if (now - entry.lastSentMicros < minimumInterval) {
                continue;
            }
            rtp::MediaPacketRef retransmission = makeRetransmission(*entry.packet);
            if (!retransmission) {
                continue;
            }
            entry.lastSentMicros = now;
            ++_retransmissions;
            packets.push_back(retransmission.release());
        }
    }
    for (size_t i = 0; i < packets.size(); ++i) {
        _transport->sendMediaPacket(rtp::MediaPacketRef(packets[i]));
    }
}

void VideoSendStream::requestKeyframe() {
    Lock lock(&_mutex);
    _keyframeRequested = true;
}

void VideoSendStream::chooseStep(int bitrate, int64_t nowMicros) {
    if (_ladder.empty()) {
        return;
    }
    const size_t lastIndex = _ladder.size() - 1;
    size_t desired = lastIndex;
    for (size_t i = 0; i < _ladder.size(); ++i) {
        if (_ladder[i].minBitrate <= bitrate) {
            desired = i;
            break;
        }
    }
    const VideoLadderStep &current = _ladder[_step];
    const int fps = current.fps > 0 ? current.fps : 30;
    const float frameMillis = 1000.0f / (float)fps;
    if (_encodeMillis > frameMillis * 0.8f) {
        if (_overloadSinceMicros == 0) {
            _overloadSinceMicros = nowMicros;
        } else if (nowMicros - _overloadSinceMicros > kOverloadDelayMicros && _step < lastIndex) {
            if (desired <= _step) {
                desired = _step + 1;
            }
            _blockUpgradeUntilMicros = nowMicros + kUpgradeBlockMicros;
            _overloadCeiling = _step + 1;
            _overloadCeilingUntilMicros = nowMicros + _overloadBackoffMicros;
            _overloadBackoffMicros = _overloadBackoffMicros * 2 > kOverloadBackoffLimitMicros ? kOverloadBackoffLimitMicros : _overloadBackoffMicros * 2;
            _overloadSinceMicros = 0;
        }
    } else {
        _overloadSinceMicros = 0;
    }
    size_t next = _step;
    if (desired > _step) {
        if (bitrate < (current.minBitrate * 4) / 5 || desired > _step + 1 || nowMicros < _blockUpgradeUntilMicros) {
            next = desired;
        }
        _upgradeCandidateSinceMicros = 0;
    } else if (desired < _step) {
        const VideoLadderStep &better = _ladder[_step - 1];
        const bool capped = _step - 1 < _overloadCeiling && nowMicros < _overloadCeilingUntilMicros;
        if (bitrate >= (better.minBitrate * 5) / 4 && nowMicros >= _blockUpgradeUntilMicros && !capped) {
            if (_upgradeCandidateSinceMicros == 0) {
                _upgradeCandidateSinceMicros = nowMicros;
            } else if (nowMicros - _upgradeCandidateSinceMicros >= kUpgradeDelayMicros) {
                next = _step - 1;
                _upgradeCandidateSinceMicros = 0;
            }
        } else {
            _upgradeCandidateSinceMicros = 0;
        }
    } else {
        _upgradeCandidateSinceMicros = 0;
    }
    if (next != _step) {
        _step = next;
        _encodeMillis = 0.0f;
        _overloadSinceMicros = 0;
        const VideoLadderStep &step = _ladder[_step];
        syslog(LOG_NOTICE, "IOS6MEDIA video.send.step %dx%d@%d bitrate=%d", step.width, step.height, step.fps, bitrate);
        _source->requestFormat(step.width, step.height, step.fps);
    }
}

void VideoSendStream::setTargetBitrate(int bitrate, int64_t nowMicros) {
    int fps = 30;
    int width = 0;
    int height = 0;
    {
        Lock lock(&_mutex);
        if (bitrate > _profile.maxSendBitrate && _profile.maxSendBitrate > 0) {
            bitrate = _profile.maxSendBitrate;
        }
        _targetBitrate = bitrate;
        chooseStep(bitrate, nowMicros);
        if (!_ladder.empty()) {
            fps = _ladder[_step].fps;
            width = _ladder[_step].width;
            height = _ladder[_step].height;
        }
    }
    if (_encoder) {
        _encoder->setMaxResolution(width, height);
        _encoder->setRates(bitrate, fps);
    }
}

bool VideoSendStream::makeSenderInfo(int64_t nowMicros, uint64_t ntpNow, rtp::RtcpSenderInfo *info) {
    Lock lock(&_mutex);
    return _sendStatistics.makeSenderInfo(nowMicros, ntpNow, info);
}

VideoSendStream::Statistics VideoSendStream::statistics() {
    Lock lock(&_mutex);
    Statistics result;
    result.framesCaptured = _framesCaptured;
    result.framesEncoded = _framesEncoded;
    result.framesDropped = _framesDropped;
    result.keyframes = _keyframes;
    result.retransmissions = _retransmissions;
    result.width = _ladder.empty() ? 0 : _ladder[_step].width;
    result.height = _ladder.empty() ? 0 : _ladder[_step].height;
    result.fps = _ladder.empty() ? 0 : _ladder[_step].fps;
    result.targetBitrate = _targetBitrate;
    result.encodeMillis = _encodeMillis;
    return result;
}

}
