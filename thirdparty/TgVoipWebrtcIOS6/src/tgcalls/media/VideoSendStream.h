#ifndef TGCALLS_MEDIA_VIDEO_SEND_STREAM_H
#define TGCALLS_MEDIA_VIDEO_SEND_STREAM_H

#include "media/VideoEncoder.h"
#include "media/VideoProfile.h"
#include "media/VideoSource.h"
#include "rtp/MediaPacket.h"
#include "rtp/RtpPacket.h"
#include "rtp/RtpStatistics.h"

#include <memory>
#include <pthread.h>
#include <vector>

namespace tgcalls {

class VideoSendStream : public VideoFrameSink, public VideoEncoderCallback {
public:
    struct Configuration {
        uint32_t ssrc = 0;
        uint32_t rtxSsrc = 0;
        uint8_t payloadType = 0;
        bool hasRtx = false;
        uint8_t rtxPayloadType = 0;
        VideoCodecType codec = VideoCodecType::Unknown;
        rtp::RtpExtensionMap extensions;
    };

    struct Statistics {
        uint32_t framesCaptured;
        uint32_t framesEncoded;
        uint32_t framesDropped;
        uint32_t keyframes;
        uint32_t retransmissions;
        int width;
        int height;
        int fps;
        int targetBitrate;
        float encodeMillis;
    };

    VideoSendStream(const Configuration &configuration, const std::shared_ptr<rtp::MediaPacketSink> &transport, const std::shared_ptr<VideoSourceHub> &source);
    ~VideoSendStream() noexcept;

    bool isValid() const { return (bool)_encoder; }
    const Configuration &configuration() const { return _configuration; }

    void onVideoFrame(const VideoFrame &frame) override;
    void onEncodedFrame(const EncodedVideoFrame &frame, int64_t captureMicros, float encodeMillis) override;

    void onNack(const uint16_t *sequenceNumbers, size_t count, int64_t rttMicros);
    void requestKeyframe();
    void setTargetBitrate(int bitrate, int64_t nowMicros);
    bool makeSenderInfo(int64_t nowMicros, uint64_t ntpNow, rtp::RtcpSenderInfo *info);
    Statistics statistics();

private:
    enum { kHistorySize = 1024 };

    struct HistoryEntry {
        rtp::MediaPacketRef packet;
        uint16_t sequenceNumber;
        int64_t lastSentMicros;
    };

    void chooseStep(int bitrate, int64_t nowMicros);
    uint32_t rtpTimestamp(int64_t captureMicros);
    rtp::MediaPacketRef makeRetransmission(const rtp::MediaPacket &original);

    Configuration _configuration;
    std::shared_ptr<rtp::MediaPacketSink> _transport;
    std::shared_ptr<VideoSourceHub> _source;
    std::unique_ptr<VideoEncoder> _encoder;
    const VideoProfile &_profile;
    std::vector<VideoLadderStep> _ladder;

    pthread_mutex_t _mutex;
    HistoryEntry _history[kHistorySize];
    uint16_t _sequenceNumber;
    uint16_t _rtxSequenceNumber;
    uint16_t _pictureId;
    uint32_t _timestampBase;
    bool _hasTimestampOrigin;
    int64_t _timestampOriginMicros;
    rtp::RtpSendStatistics _sendStatistics;

    int _targetBitrate;
    size_t _step;
    int64_t _upgradeCandidateSinceMicros;
    int64_t _overloadSinceMicros;
    int64_t _blockUpgradeUntilMicros;
    size_t _overloadCeiling;
    int64_t _overloadCeilingUntilMicros;
    int64_t _overloadBackoffMicros;
    int64_t _lastCaptureMicros;
    bool _keyframeRequested;
    int64_t _lastKeyframeMicros;
    float _encodeMillis;

    uint32_t _framesCaptured;
    uint32_t _framesEncoded;
    uint32_t _framesDropped;
    uint32_t _keyframes;
    uint32_t _retransmissions;
};

}

#endif
