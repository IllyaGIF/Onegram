#include "media/AudioChannel.h"

#include "rtp/RtpTime.h"
#include "Ios6DiagnosticLog.h"

#include <string.h>

namespace tgcalls {

namespace {

class ScopedLock {
public:
    explicit ScopedLock(pthread_mutex_t *mutex) : _mutex(mutex) { pthread_mutex_lock(_mutex); }
    ~ScopedLock() { pthread_mutex_unlock(_mutex); }

private:
    pthread_mutex_t *_mutex;
};

}

AudioChannel::AudioChannel(const std::shared_ptr<rtp::MediaPacketSink> &sink) :
_sink(sink),
_started(false),
_connected(false),
_muted(false),
_shuttingDown(false),
_sequenceNumber((uint16_t)arc4random()),
_timestamp(arc4random()),
_sentFirstPacket(false),
_encoder(0),
_playoutFrameDurationMs(0),
_playoutReady(false),
_jitterTicks(0),
_incomingSsrc(0),
_incomingPayloadType(0),
_hasTimestampBase(false),
_timestampBase(0),
_decodeErrors(0) {
    pthread_mutex_init(&_outgoingMutex, 0);
    pthread_mutex_init(&_playoutMutex, 0);
    _outgoing.ssrc = 0;
    _outgoing.payloadType = 111;
}

AudioChannel::~AudioChannel() {
    _shuttingDown = true;
    if (_audioInput) {
        _audioInput->SetCallback(0, 0);
        _audioInput->Stop();
    }
    if (_audioOutput) {
        _audioOutput->Stop();
    }
    if (_audioUnit) {
        _audioUnit->Stop();
    }
    {
        ScopedLock lock(&_playoutMutex);
        if (_decoder) {
            _decoder->Stop();
            _decoder.reset();
        }
        _jitterBuffer.reset();
        _playoutReady = false;
    }
    _audioInput.reset();
    _audioOutput.reset();
    _audioUnit.reset();
    {
        ScopedLock lock(&_outgoingMutex);
        if (_encoder != 0) {
            opus_encoder_destroy(_encoder);
            _encoder = 0;
        }
    }
    pthread_mutex_destroy(&_playoutMutex);
    pthread_mutex_destroy(&_outgoingMutex);
}

void AudioChannel::start() {
    if (_started) {
        return;
    }
    _started = true;
    int error = 0;
    OpusEncoder *encoder = opus_encoder_create(kSampleRate, 1, OPUS_APPLICATION_VOIP, &error);
    if (encoder != 0) {
        opus_encoder_ctl(encoder, OPUS_SET_BITRATE(32000));
        opus_encoder_ctl(encoder, OPUS_SET_COMPLEXITY(3));
        opus_encoder_ctl(encoder, OPUS_SET_SIGNAL(OPUS_SIGNAL_VOICE));
        opus_encoder_ctl(encoder, OPUS_SET_INBAND_FEC(1));
        opus_encoder_ctl(encoder, OPUS_SET_PACKET_LOSS_PERC(10));
    }
    {
        ScopedLock lock(&_outgoingMutex);
        _encoder = encoder;
    }
    _audioUnit.reset(new tgvoip::audio::AudioUnitIO());
    if (_audioUnit && !_audioUnit->IsFailed()) {
        _audioInput.reset(tgvoip::audio::AudioInput::Create("default", _audioUnit.get()));
        _audioOutput.reset(tgvoip::audio::AudioOutput::Create("default", _audioUnit.get()));
        if (_audioInput) {
            _audioInput->Configure(kSampleRate, 16, 1);
            _audioInput->SetCallback(&AudioChannel::inputCallback, this);
        }
        if (_audioOutput) {
            _audioOutput->Configure(kSampleRate, 16, 1);
        }
    }
    syslog(LOG_NOTICE, "IOS6MEDIA audio.start encoder=%d unit=%d input=%d output=%d",
        encoder != 0 ? 1 : 0,
        (_audioUnit && !_audioUnit->IsFailed()) ? 1 : 0,
        _audioInput ? 1 : 0,
        _audioOutput ? 1 : 0);
    if (_connected) {
        _connected = false;
        setConnected(true);
    }
}

void AudioChannel::setConnected(bool connected) {
    if (_connected == connected) {
        return;
    }
    _connected = connected;
    if (!_started) {
        return;
    }
    if (connected) {
        if (_audioInput) {
            _audioInput->Start();
        }
        bool playoutReady = false;
        {
            ScopedLock lock(&_playoutMutex);
            playoutReady = _playoutReady;
        }
        if (_audioOutput && playoutReady) {
            _audioOutput->Start();
        }
    } else {
        {
            ScopedLock lock(&_playoutMutex);
            if (_jitterBuffer) {
                _jitterBuffer->Reset();
            }
        }
        if (_audioInput) {
            _audioInput->Stop();
        }
        if (_audioOutput) {
            _audioOutput->Stop();
        }
    }
}

void AudioChannel::setMuted(bool muted) {
    _muted = muted;
}

void AudioChannel::setOutgoingConfiguration(const OutgoingConfiguration &configuration) {
    ScopedLock lock(&_outgoingMutex);
    if (_outgoing.ssrc != configuration.ssrc) {
        _sendStatistics.reset(configuration.ssrc, kSampleRate);
        _sentFirstPacket = false;
    }
    _outgoing = configuration;
}

uint32_t AudioChannel::outgoingSsrc() const {
    ScopedLock lock(&_outgoingMutex);
    return _outgoing.ssrc;
}

void AudioChannel::setIncoming(uint32_t ssrc, uint8_t payloadType) {
    if (_incomingSsrc != ssrc) {
        _receiveStatistics.reset(ssrc, kSampleRate);
        _hasTimestampBase = false;
    }
    _incomingSsrc = ssrc;
    _incomingPayloadType = payloadType;
}

size_t AudioChannel::inputCallback(unsigned char *data, size_t length, void *context) {
    if (context == 0) {
        return 0;
    }
    return static_cast<AudioChannel *>(context)->handleInputPcm(data, length);
}

size_t AudioChannel::handleInputPcm(unsigned char *data, size_t length) {
    tickPlayoutJitter();
    if (_shuttingDown || !_connected || length != kFrameSamples * 2) {
        return 0;
    }
    static const opus_int16 kSilence[kFrameSamples] = { 0 };
    const opus_int16 *samples = _muted ? kSilence : (const opus_int16 *)data;
    rtp::MediaPacketRef packet = rtp::AllocateMediaPacket();
    {
        ScopedLock lock(&_outgoingMutex);
        if (_encoder == 0 || _outgoing.ssrc == 0) {
            return 0;
        }
        rtp::RtpPacketWriter writer(packet->data(), packet->capacity() - rtp::MediaPacket::kTailroom);
        writer.setHeader(_outgoing.payloadType, !_sentFirstPacket, _sequenceNumber, _timestamp, _outgoing.ssrc);
        size_t transportOffset = 0;
        if (writer.addTransportSequenceNumber(_outgoing.extensions, &transportOffset)) {
            packet->transportSequenceOffset = transportOffset;
        }
        uint8_t *payload = writer.payload();
        if (payload == 0) {
            return 0;
        }
        const opus_int32 capacity = (opus_int32)std::min<size_t>(writer.payloadCapacity(), 1275);
        const int encoded = opus_encode(_encoder, samples, kFrameSamples, payload, capacity);
        if (encoded <= 0) {
            return 0;
        }
        const size_t size = writer.finish((size_t)encoded);
        if (size == 0) {
            return 0;
        }
        packet->setSize(size);
        packet->kind = rtp::MediaPacketAudio;
        packet->ssrc = _outgoing.ssrc;
        packet->sequenceNumber = _sequenceNumber;
        packet->timeMicros = rtp::MonotonicMicros();
        _sendStatistics.onPacketSent(_timestamp, packet->timeMicros, (size_t)encoded);
        _sentFirstPacket = true;
        ++_sequenceNumber;
        _timestamp += kRtpFrameTicks;
    }
    _sink->sendMediaPacket(std::move(packet));
    return 0;
}

bool AudioChannel::makeSenderInfo(int64_t nowMicros, uint64_t ntpNow, rtp::RtcpSenderInfo *info) const {
    ScopedLock lock(&_outgoingMutex);
    return _sendStatistics.makeSenderInfo(nowMicros, ntpNow, info);
}

void AudioChannel::tickPlayoutJitter() {
    ++_jitterTicks;
    if ((_jitterTicks % 5U) != 0U) {
        return;
    }
    std::tr1::shared_ptr<tgvoip::JitterBuffer> jitter;
    {
        ScopedLock lock(&_playoutMutex);
        jitter = _jitterBuffer;
    }
    if (jitter) {
        jitter->Tick();
    }
}

bool AudioChannel::configurePlayout(uint32_t frameDurationMs) {
    if (!_audioOutput || frameDurationMs < 20U || frameDurationMs > 80U || (frameDurationMs % 20U) != 0U) {
        return false;
    }
    bool replacing = false;
    {
        ScopedLock lock(&_playoutMutex);
        if (_playoutReady && _playoutFrameDurationMs == frameDurationMs) {
            return true;
        }
        replacing = _playoutReady || _decoder;
    }
    if (replacing) {
        _audioOutput->Stop();
        if (_audioUnit) {
            _audioUnit->Stop();
        }
    }
    bool shouldStart = false;
    {
        ScopedLock lock(&_playoutMutex);
        if (_decoder) {
            _decoder->Stop();
            _decoder.reset();
        }
        _jitterBuffer = std::tr1::shared_ptr<tgvoip::JitterBuffer>(new tgvoip::JitterBuffer(0, frameDurationMs));
        _jitterBuffer->SetMinPacketCount(frameDurationMs > 50U ? 3 : (frameDurationMs > 30U ? 4 : 6));
        _decoder = std::tr1::shared_ptr<tgvoip::OpusDecoder>(new tgvoip::OpusDecoder(_audioOutput.get(), true, false));
        _decoder->SetJitterBuffer(_jitterBuffer);
        _decoder->SetFrameDuration(frameDurationMs);
        _decoder->Start();
        _playoutFrameDurationMs = frameDurationMs;
        _playoutReady = true;
        shouldStart = _connected && !_shuttingDown;
    }
    if (shouldStart) {
        _audioOutput->Start();
    } else if (replacing && _connected && !_shuttingDown && _audioInput) {
        _audioInput->Start();
    }
    syslog(LOG_NOTICE, "IOS6MEDIA audio.playout frameMs=%u replaced=%d", (unsigned int)frameDurationMs, replacing ? 1 : 0);
    return true;
}

bool AudioChannel::handleIncomingRtp(const rtp::RtpPacketView &packet, int64_t arrivalMicros) {
    if (_shuttingDown || packet.ssrc() != _incomingSsrc || packet.payloadType() != _incomingPayloadType || packet.payloadSize() == 0) {
        return false;
    }
    _receiveStatistics.onPacket(packet.sequenceNumber(), packet.timestamp(), arrivalMicros, packet.size(), false);
    const unsigned char *payload = packet.payload();
    const opus_int32 payloadSize = (opus_int32)packet.payloadSize();
    const int samples = opus_packet_get_nb_samples(payload, payloadSize, kSampleRate);
    if (samples <= 0) {
        ++_decodeErrors;
        return false;
    }
    const uint32_t frameDurationMs = (uint32_t)(((uint64_t)samples * 1000ULL) / (uint64_t)kSampleRate);
    if (!configurePlayout(frameDurationMs)) {
        ++_decodeErrors;
        return false;
    }
    if (!_hasTimestampBase) {
        _timestampBase = packet.timestamp() - kTimestampBaseMarginTicks;
        _hasTimestampBase = true;
    }
    const uint32_t timestampMs = (packet.timestamp() - _timestampBase) / (uint32_t)(kSampleRate / 1000);
    std::tr1::shared_ptr<tgvoip::JitterBuffer> jitter;
    {
        ScopedLock lock(&_playoutMutex);
        jitter = _jitterBuffer;
    }
    if (!jitter) {
        return false;
    }
    jitter->HandleInput((unsigned char *)payload, (size_t)payloadSize, timestampMs, false);
    return true;
}

float AudioChannel::outputLevel() const {
    return _audioOutput ? _audioOutput->GetLevel() : 0.0f;
}

}
