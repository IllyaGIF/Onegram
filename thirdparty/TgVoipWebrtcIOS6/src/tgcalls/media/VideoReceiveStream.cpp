#include "media/VideoReceiveStream.h"

#include "rtp/Rtcp.h"
#include "rtp/RtpByteIO.h"
#include "rtp/RtpPacket.h"
#include "rtp/RtpTime.h"
#include "Ios6DiagnosticLog.h"

#include <string.h>

namespace tgcalls {

namespace {

const size_t kIncomingLimit = 1024;
const size_t kDecodeQueueLimit = 6;
const int64_t kNackIntervalMicros = 20000;
const int64_t kKeyframeRequestIntervalMicros = 400000;
const int64_t kIdleWakeMicros = 100000;

}

class VideoDecodeThread : public WorkerThread {
public:
    VideoDecodeThread(const std::shared_ptr<VideoFrameSink> &sink) :
    _sink(sink),
    _codec(VideoCodecType::Unknown),
    _waitingForKeyframe(true),
    _keyframeNeeded(false),
    _decoded(0),
    _dropped(0),
    _decodeMillis(0.0f),
    _load(0.0f),
    _width(0),
    _height(0),
    _lastFrameMicros(0) {
    }

    ~VideoDecodeThread() noexcept {
        stop();
    }

    void push(const EncodedVideoFrame &frame) {
        ScopedMutex lock(&_mutex);
        if (_queue.size() >= kDecodeQueueLimit) {
            _dropped += (uint32_t)_queue.size();
            _queue.clear();
            _waitingForKeyframe = true;
            _keyframeNeeded = true;
            _load = 1.0f;
        }
        _queue.push_back(frame);
        wake();
    }

    bool takeKeyframeNeeded() {
        ScopedMutex lock(&_mutex);
        const bool result = _keyframeNeeded;
        _keyframeNeeded = false;
        return result;
    }

    void fillStatistics(VideoReceiveStream::Statistics &statistics) {
        ScopedMutex lock(&_mutex);
        statistics.framesDecoded = _decoded;
        statistics.framesDropped = _dropped;
        statistics.decodeMillis = _decodeMillis;
        statistics.decodeLoad = _load;
        statistics.width = _width;
        statistics.height = _height;
    }

protected:
    bool hasPendingWork() override {
        return !_queue.empty();
    }

    int64_t nextWakeMicros(int64_t nowMicros) override {
        return nowMicros + 1000000;
    }

    void runIteration(int64_t) override {
        EncodedVideoFrame frame;
        {
            ScopedMutex lock(&_mutex);
            if (_queue.empty()) {
                return;
            }
            frame = _queue.front();
            _queue.pop_front();
        }
        if (frame.codec != _codec || !_decoderInstance) {
            _decoderInstance = CreateVideoDecoder(frame.codec);
            _codec = frame.codec;
            ScopedMutex lock(&_mutex);
            _waitingForKeyframe = true;
        }
        bool waiting = false;
        {
            ScopedMutex lock(&_mutex);
            if (_waitingForKeyframe && frame.keyframe) {
                _waitingForKeyframe = false;
            }
            waiting = _waitingForKeyframe;
            if (waiting) {
                _keyframeNeeded = true;
                ++_dropped;
            }
        }
        if (waiting || !_decoderInstance) {
            return;
        }
        const int64_t start = rtp::MonotonicMicros();
        const VideoDecoder::Result result = _decoderInstance->decode(frame, *_sink);
        const int64_t finish = rtp::MonotonicMicros();
        ScopedMutex lock(&_mutex);
        const float elapsed = (float)(finish - start) / 1000.0f;
        _decodeMillis = _decodeMillis == 0.0f ? elapsed : _decodeMillis * 0.9f + elapsed * 0.1f;
        if (_lastFrameMicros != 0 && frame.receiveMicros > _lastFrameMicros) {
            const float interval = (float)(frame.receiveMicros - _lastFrameMicros) / 1000.0f;
            if (interval > 1.0f) {
                const float load = elapsed / interval;
                _load = _load * 0.9f + (load > 1.5f ? 1.5f : load) * 0.1f;
            }
        }
        _lastFrameMicros = frame.receiveMicros;
        if (frame.width > 0 && frame.height > 0) {
            _width = frame.width;
            _height = frame.height;
        }
        if (result == VideoDecoder::Failed) {
            _waitingForKeyframe = true;
            _keyframeNeeded = true;
        } else if (result == VideoDecoder::Decoded) {
            ++_decoded;
        }
    }

private:
    std::shared_ptr<VideoFrameSink> _sink;
    std::deque<EncodedVideoFrame> _queue;
    std::unique_ptr<VideoDecoder> _decoderInstance;
    VideoCodecType _codec;
    bool _waitingForKeyframe;
    bool _keyframeNeeded;
    uint32_t _decoded;
    uint32_t _dropped;
    float _decodeMillis;
    float _load;
    int _width;
    int _height;
    int64_t _lastFrameMicros;
};

VideoReceiveStream::VideoReceiveStream(const Configuration &configuration, const std::shared_ptr<rtp::MediaPacketSink> &rtcpSink, const std::shared_ptr<VideoFrameSink> &frameSink) :
_configuration(configuration),
_rtcpSink(rtcpSink),
_decoder(new VideoDecodeThread(frameSink)),
_rttMicros(0),
_fallbackRotation(0),
_keyframeRequested(true),
_lastKeyframeRequestMicros(0),
_firSequence(0),
_nextNackMicros(0),
_framesReceived(0),
_keyframeRequests(0),
_nacksSent(0),
_bitrateWindowBytes(0),
_bitrateWindowStart(0),
_receivedBitrate(0) {
    _receiveStatistics.reset(configuration.ssrc, 90000);
    _decoder->start(1);
    start(2);
    syslog(LOG_NOTICE, "IOS6MEDIA video.receive.start ssrc=%u rtx=%u payloads=%lu",
        (unsigned int)configuration.ssrc,
        (unsigned int)configuration.rtxSsrc,
        (unsigned long)configuration.payloadTypes.size());
}

VideoReceiveStream::~VideoReceiveStream() noexcept {
    stop();
    _decoder.reset();
    while (!_incoming.empty()) {
        rtp::MediaPacketRef dropped(_incoming.front());
        _incoming.pop_front();
    }
}

void VideoReceiveStream::enqueuePacket(rtp::MediaPacketRef &&packet) {
    rtp::MediaPacketRef dropped;
    ScopedMutex lock(&_mutex);
    if (_incoming.size() >= kIncomingLimit) {
        dropped = rtp::MediaPacketRef(_incoming.front());
        _incoming.pop_front();
    }
    _incoming.push_back(packet.release());
    wake();
}

void VideoReceiveStream::setRtt(int64_t rttMicros) {
    ScopedMutex lock(&_mutex);
    _rttMicros = rttMicros;
}

void VideoReceiveStream::setFallbackRotation(int degrees) {
    ScopedMutex lock(&_mutex);
    _fallbackRotation = degrees;
}

void VideoReceiveStream::requestKeyframe() {
    ScopedMutex lock(&_mutex);
    _keyframeRequested = true;
    wake();
}

void VideoReceiveStream::onSenderReport(const rtp::RtcpSenderInfo &info, int64_t arrivalMicros) {
    ScopedMutex lock(&_mutex);
    _receiveStatistics.onSenderReport(info, arrivalMicros);
}

bool VideoReceiveStream::makeReportBlock(int64_t nowMicros, rtp::RtcpReportBlock *block) {
    ScopedMutex lock(&_mutex);
    return _receiveStatistics.hasPackets() && _receiveStatistics.makeReportBlock(nowMicros, block);
}

VideoReceiveStream::Statistics VideoReceiveStream::statistics() {
    Statistics result;
    memset(&result, 0, sizeof(result));
    {
        ScopedMutex lock(&_mutex);
        result.framesReceived = _framesReceived;
        result.keyframeRequests = _keyframeRequests;
        result.nacksSent = _nacksSent;
        result.receivedBitrate = _receivedBitrate;
    }
    _decoder->fillStatistics(result);
    return result;
}

bool VideoReceiveStream::hasPendingWork() {
    return !_incoming.empty() || _keyframeRequested;
}

int64_t VideoReceiveStream::nextWakeMicros(int64_t nowMicros) {
    if (_nack.pendingCount() != 0) {
        return _nextNackMicros > nowMicros ? _nextNackMicros : nowMicros + kNackIntervalMicros;
    }
    return nowMicros + kIdleWakeMicros;
}

const NegotiatedPayloadType *VideoReceiveStream::payloadType(uint8_t id) const {
    for (size_t i = 0; i < _configuration.payloadTypes.size(); ++i) {
        if (_configuration.payloadTypes[i].id == id) {
            return &_configuration.payloadTypes[i];
        }
    }
    return 0;
}

void VideoReceiveStream::runIteration(int64_t nowMicros) {
    std::deque<rtp::MediaPacket *> packets;
    {
        ScopedMutex lock(&_mutex);
        packets.swap(_incoming);
    }
    for (size_t i = 0; i < packets.size(); ++i) {
        rtp::MediaPacketRef packet(packets[i]);
        processPacket(*packet, nowMicros);
    }
    if (_decoder->takeKeyframeNeeded()) {
        ScopedMutex lock(&_mutex);
        _keyframeRequested = true;
    }
    if (nowMicros >= _nextNackMicros) {
        sendNacks(nowMicros);
        _nextNackMicros = nowMicros + kNackIntervalMicros;
    }
    sendKeyframeRequestIfNeeded(nowMicros);
}

void VideoReceiveStream::processPacket(rtp::MediaPacket &packet, int64_t nowMicros) {
    rtp::RtpPacketView view;
    if (!view.parse(packet.data(), packet.size())) {
        return;
    }
    VideoFrameAssembler::PacketInfo info;
    info.payload = view.payload();
    info.payloadSize = view.payloadSize();
    info.sequenceNumber = view.sequenceNumber();
    info.timestamp = view.timestamp();
    info.marker = view.marker();
    info.arrivalMicros = packet.timeMicros;
    info.rotation = -1;
    int rotation = 0;
    if (_configuration.extensions.readVideoRotation(view, &rotation)) {
        info.rotation = rotation;
    }
    const NegotiatedPayloadType *payload = 0;
    bool retransmitted = false;
    if (view.ssrc() == _configuration.rtxSsrc && _configuration.rtxSsrc != 0) {
        payload = 0;
        for (size_t i = 0; i < _configuration.payloadTypes.size(); ++i) {
            if (_configuration.payloadTypes[i].hasRtx && _configuration.payloadTypes[i].rtxId == view.payloadType()) {
                payload = &_configuration.payloadTypes[i];
            }
        }
        if (payload == 0 || view.payloadSize() < 2) {
            return;
        }
        info.sequenceNumber = rtp::ReadU16(view.payload());
        info.payload = view.payload() + 2;
        info.payloadSize = view.payloadSize() - 2;
        retransmitted = true;
    } else if (view.ssrc() == _configuration.ssrc) {
        payload = payloadType(view.payloadType());
        if (payload == 0) {
            return;
        }
    } else {
        return;
    }
    info.codec = VideoCodecTypeFromName(payload->name);
    if (info.codec == VideoCodecType::Unknown) {
        return;
    }
    {
        ScopedMutex lock(&_mutex);
        if (!retransmitted) {
            _receiveStatistics.onPacket(view.sequenceNumber(), view.timestamp(), packet.timeMicros, packet.size(), false);
        }
        if (_bitrateWindowStart == 0) {
            _bitrateWindowStart = nowMicros;
        }
        _bitrateWindowBytes += packet.size();
        if (nowMicros - _bitrateWindowStart >= 1000000) {
            _receivedBitrate = (uint32_t)((_bitrateWindowBytes * 8 * 1000000) / (uint64_t)(nowMicros - _bitrateWindowStart));
            _bitrateWindowBytes = 0;
            _bitrateWindowStart = nowMicros;
        }
    }
    VideoFrameAssembler::Output output;
    if (!_nack.onPacket(info.sequenceNumber, nowMicros)) {
        _assembler.requireKeyframe(output);
    }
    _assembler.insert(info, output);
    handleAssemblerOutput(output, nowMicros);
}

void VideoReceiveStream::handleAssemblerOutput(VideoFrameAssembler::Output &output, int64_t) {
    int fallbackRotation = 0;
    {
        ScopedMutex lock(&_mutex);
        fallbackRotation = _fallbackRotation;
        if (output.keyframeRequired) {
            _keyframeRequested = true;
        }
    }
    for (size_t i = 0; i < output.frames.size(); ++i) {
        EncodedVideoFrame &frame = output.frames[i];
        if (frame.rotation < 0) {
            frame.rotation = fallbackRotation;
        }
        if (frame.keyframe) {
            ScopedMutex lock(&_mutex);
            _keyframeRequested = false;
        }
        {
            ScopedMutex lock(&_mutex);
            ++_framesReceived;
        }
        _decoder->push(frame);
    }
    if (_assembler.hasLastFrame()) {
        _nack.dropOlderThan((uint16_t)(_assembler.lastFrameEnd() + 1));
    }
}

void VideoReceiveStream::sendNacks(int64_t nowMicros) {
    int64_t rtt = 0;
    {
        ScopedMutex lock(&_mutex);
        rtt = _rttMicros;
    }
    std::vector<uint16_t> requests;
    std::vector<uint16_t> abandoned;
    _nack.collect(nowMicros, rtt, requests, abandoned);
    if (!abandoned.empty()) {
        VideoFrameAssembler::Output output;
        for (size_t i = 0; i < abandoned.size(); ++i) {
            _assembler.abandon(abandoned[i], output);
        }
        handleAssemblerOutput(output, nowMicros);
    }
    if (requests.empty()) {
        return;
    }
    bool nackNegotiated = false;
    for (size_t i = 0; i < _configuration.payloadTypes.size(); ++i) {
        nackNegotiated = nackNegotiated || _configuration.payloadTypes[i].nack;
    }
    if (!nackNegotiated) {
        return;
    }
    rtp::MediaPacketRef packet = rtp::AllocateMediaPacket();
    rtp::RtcpWriter writer(packet->data(), packet->capacity() - rtp::MediaPacket::kTailroom);
    if (!writer.addNack(_configuration.localSsrc, _configuration.ssrc, &requests[0], requests.size())) {
        return;
    }
    packet->setSize(writer.size());
    {
        ScopedMutex lock(&_mutex);
        _nacksSent += (uint32_t)requests.size();
    }
    sendRtcp(std::move(packet));
}

void VideoReceiveStream::sendKeyframeRequestIfNeeded(int64_t nowMicros) {
    {
        ScopedMutex lock(&_mutex);
        if (!_keyframeRequested || nowMicros - _lastKeyframeRequestMicros < kKeyframeRequestIntervalMicros) {
            return;
        }
        _lastKeyframeRequestMicros = nowMicros;
        ++_keyframeRequests;
    }
    bool pli = false;
    bool fir = false;
    for (size_t i = 0; i < _configuration.payloadTypes.size(); ++i) {
        pli = pli || _configuration.payloadTypes[i].pictureLossIndication;
        fir = fir || _configuration.payloadTypes[i].fullIntraRequest;
    }
    rtp::MediaPacketRef packet = rtp::AllocateMediaPacket();
    rtp::RtcpWriter writer(packet->data(), packet->capacity() - rtp::MediaPacket::kTailroom);
    bool written = false;
    if (pli || !fir) {
        written = writer.addPictureLossIndication(_configuration.localSsrc, _configuration.ssrc);
    } else {
        written = writer.addFullIntraRequest(_configuration.localSsrc, _configuration.ssrc, _firSequence++);
    }
    if (!written) {
        return;
    }
    packet->setSize(writer.size());
    sendRtcp(std::move(packet));
}

void VideoReceiveStream::sendRtcp(rtp::MediaPacketRef &&packet) {
    packet->kind = rtp::MediaPacketRtcp;
    packet->ssrc = _configuration.localSsrc;
    packet->timeMicros = rtp::MonotonicMicros();
    _rtcpSink->sendMediaPacket(std::move(packet));
}

}
