#ifndef TGCALLS_MEDIA_AUDIO_CHANNEL_H
#define TGCALLS_MEDIA_AUDIO_CHANNEL_H

#include "rtp/MediaPacket.h"
#include "rtp/RtpPacket.h"
#include "rtp/RtpStatistics.h"

#include "../../../../../submodules/libtgvoip/audio/AudioInput.h"
#include "../../../../../submodules/libtgvoip/audio/AudioOutput.h"
#include "../../../../../submodules/libtgvoip/os/darwin/AudioUnitIO.h"
#include "../../../../../submodules/libtgvoip/JitterBuffer.h"
#include "../../../../../submodules/libtgvoip/OpusDecoder.h"

extern "C" {
#include "opus.h"
}

#include <functional>
#include <memory>
#include <pthread.h>
#include <stdint.h>

namespace tgcalls {

class AudioChannel {
public:
    struct OutgoingConfiguration {
        uint32_t ssrc;
        uint8_t payloadType;
        rtp::RtpExtensionMap extensions;
    };

    explicit AudioChannel(const std::shared_ptr<rtp::MediaPacketSink> &sink);
    ~AudioChannel();

    void start();
    void setConnected(bool connected);
    void setMuted(bool muted);
    void setOutgoingConfiguration(const OutgoingConfiguration &configuration);
    void setIncoming(uint32_t ssrc, uint8_t payloadType);

    uint32_t incomingSsrc() const { return _incomingSsrc; }
    bool handleIncomingRtp(const rtp::RtpPacketView &packet, int64_t arrivalMicros);

    bool makeSenderInfo(int64_t nowMicros, uint64_t ntpNow, rtp::RtcpSenderInfo *info) const;
    uint32_t outgoingSsrc() const;
    rtp::RtpReceiveStatistics &receiveStatistics() { return _receiveStatistics; }
    float outputLevel() const;

private:
    enum {
        kSampleRate = 48000,
        kFrameSamples = 960,
        kRtpFrameTicks = 960,
        kTimestampBaseMarginTicks = kSampleRate * 60,
        kOutgoingPacketLimit = 2
    };

    AudioChannel(const AudioChannel &) = delete;
    AudioChannel &operator=(const AudioChannel &) = delete;

    static size_t inputCallback(unsigned char *data, size_t length, void *context);
    size_t handleInputPcm(unsigned char *data, size_t length);
    bool configurePlayout(uint32_t frameDurationMs);
    void tickPlayoutJitter();

    std::shared_ptr<rtp::MediaPacketSink> _sink;
    bool _started;
    bool _connected;
    bool _muted;
    bool _shuttingDown;

    mutable pthread_mutex_t _outgoingMutex;
    OutgoingConfiguration _outgoing;
    uint16_t _sequenceNumber;
    uint32_t _timestamp;
    bool _sentFirstPacket;
    rtp::RtpSendStatistics _sendStatistics;
    OpusEncoder *_encoder;

    pthread_mutex_t _playoutMutex;
    std::tr1::shared_ptr<tgvoip::JitterBuffer> _jitterBuffer;
    std::tr1::shared_ptr<tgvoip::OpusDecoder> _decoder;
    uint32_t _playoutFrameDurationMs;
    bool _playoutReady;
    uint32_t _jitterTicks;

    uint32_t _incomingSsrc;
    uint8_t _incomingPayloadType;
    bool _hasTimestampBase;
    uint32_t _timestampBase;
    rtp::RtpReceiveStatistics _receiveStatistics;
    uint32_t _decodeErrors;

    std::unique_ptr<tgvoip::audio::AudioUnitIO> _audioUnit;
    std::unique_ptr<tgvoip::audio::AudioInput> _audioInput;
    std::unique_ptr<tgvoip::audio::AudioOutput> _audioOutput;
};

}

#endif
