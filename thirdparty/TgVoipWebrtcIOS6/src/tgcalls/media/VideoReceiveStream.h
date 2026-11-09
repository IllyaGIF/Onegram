#ifndef TGCALLS_MEDIA_VIDEO_RECEIVE_STREAM_H
#define TGCALLS_MEDIA_VIDEO_RECEIVE_STREAM_H

#include "media/NackTracker.h"
#include "media/VideoDecoder.h"
#include "media/VideoFrameAssembler.h"
#include "media/WorkerThread.h"
#include "rtp/MediaPacket.h"
#include "rtp/RtpStatistics.h"
#include "v2/MediaNegotiator.h"

#include <deque>
#include <memory>
#include <vector>

namespace tgcalls {

class VideoDecodeThread;

class VideoReceiveStream : public WorkerThread {
public:
    struct Configuration {
        uint32_t ssrc = 0;
        uint32_t rtxSsrc = 0;
        uint32_t localSsrc = 0;
        std::vector<NegotiatedPayloadType> payloadTypes;
        rtp::RtpExtensionMap extensions;
    };

    struct Statistics {
        uint32_t framesReceived;
        uint32_t framesDecoded;
        uint32_t framesDropped;
        uint32_t keyframeRequests;
        uint32_t nacksSent;
        float decodeMillis;
        float decodeLoad;
        int width;
        int height;
        uint32_t receivedBitrate;
    };

    VideoReceiveStream(const Configuration &configuration, const std::shared_ptr<rtp::MediaPacketSink> &rtcpSink, const std::shared_ptr<VideoFrameSink> &frameSink);
    ~VideoReceiveStream() noexcept;

    const Configuration &configuration() const { return _configuration; }
    void enqueuePacket(rtp::MediaPacketRef &&packet);
    void setRtt(int64_t rttMicros);
    void setFallbackRotation(int degrees);
    void requestKeyframe();
    void onSenderReport(const rtp::RtcpSenderInfo &info, int64_t arrivalMicros);
    bool makeReportBlock(int64_t nowMicros, rtp::RtcpReportBlock *block);
    Statistics statistics();

protected:
    void runIteration(int64_t nowMicros) override;
    int64_t nextWakeMicros(int64_t nowMicros) override;
    bool hasPendingWork() override;

private:
    void processPacket(rtp::MediaPacket &packet, int64_t nowMicros);
    void handleAssemblerOutput(VideoFrameAssembler::Output &output, int64_t nowMicros);
    void sendNacks(int64_t nowMicros);
    void sendKeyframeRequestIfNeeded(int64_t nowMicros);
    void sendRtcp(rtp::MediaPacketRef &&packet);
    const NegotiatedPayloadType *payloadType(uint8_t id) const;

    Configuration _configuration;
    std::shared_ptr<rtp::MediaPacketSink> _rtcpSink;
    std::unique_ptr<VideoDecodeThread> _decoder;

    std::deque<rtp::MediaPacket *> _incoming;
    rtp::RtpReceiveStatistics _receiveStatistics;
    VideoFrameAssembler _assembler;
    NackTracker _nack;
    int64_t _rttMicros;
    int _fallbackRotation;
    bool _keyframeRequested;
    int64_t _lastKeyframeRequestMicros;
    uint8_t _firSequence;
    int64_t _nextNackMicros;
    uint32_t _framesReceived;
    uint32_t _keyframeRequests;
    uint32_t _nacksSent;
    uint64_t _bitrateWindowBytes;
    int64_t _bitrateWindowStart;
    uint32_t _receivedBitrate;
};

}

#endif
