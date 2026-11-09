#ifndef TGCALLS_RTP_STATISTICS_H
#define TGCALLS_RTP_STATISTICS_H

#include "rtp/Rtcp.h"

#include <stddef.h>
#include <stdint.h>

namespace tgcalls {
namespace rtp {

class RtpReceiveStatistics {
public:
    RtpReceiveStatistics();

    void reset(uint32_t ssrc, uint32_t clockRate);
    void onPacket(uint16_t sequenceNumber, uint32_t rtpTimestamp, int64_t arrivalMicros, size_t size, bool retransmitted);
    void onSenderReport(const RtcpSenderInfo &info, int64_t arrivalMicros);
    bool makeReportBlock(int64_t nowMicros, RtcpReportBlock *block);

    uint32_t ssrc() const { return _ssrc; }
    bool hasPackets() const { return _received != 0; }
    uint64_t packetsReceived() const { return _received; }
    uint64_t bytesReceived() const { return _bytes; }
    int64_t lastPacketMicros() const { return _lastArrivalMicros; }
    float jitterMillis() const;
    float recentLossRate() const { return _recentLossRate; }
    uint16_t highestSequence() const { return _maxSequence; }

private:
    uint32_t _ssrc;
    uint32_t _clockRate;
    bool _started;
    uint16_t _maxSequence;
    uint32_t _cycles;
    uint32_t _baseSequence;
    uint64_t _received;
    uint64_t _bytes;
    uint32_t _expectedPrior;
    uint64_t _receivedPrior;
    double _jitter;
    bool _hasTransit;
    int64_t _lastTransit;
    int64_t _lastArrivalMicros;
    uint32_t _lastSenderReportCompact;
    int64_t _lastSenderReportArrivalMicros;
    float _recentLossRate;
};

class RtpSendStatistics {
public:
    RtpSendStatistics();

    void reset(uint32_t ssrc, uint32_t clockRate);
    void onPacketSent(uint32_t rtpTimestamp, int64_t captureMicros, size_t payloadSize);
    bool makeSenderInfo(int64_t nowMicros, uint64_t ntpNow, RtcpSenderInfo *info) const;

    uint32_t ssrc() const { return _ssrc; }
    uint32_t packetsSent() const { return _packets; }

private:
    uint32_t _ssrc;
    uint32_t _clockRate;
    bool _hasPackets;
    uint32_t _packets;
    uint32_t _octets;
    uint32_t _lastRtpTimestamp;
    int64_t _lastCaptureMicros;
};

class RttEstimator {
public:
    RttEstimator();

    void onReportBlock(const RtcpReportBlock &block, uint64_t ntpNow);
    void onSample(int64_t rttMicros);
    bool hasValue() const { return _hasValue; }
    int64_t smoothedMicros() const { return _smoothedMicros; }
    int64_t lastMicros() const { return _lastMicros; }

private:
    bool _hasValue;
    int64_t _smoothedMicros;
    int64_t _lastMicros;
};

}
}

#endif
