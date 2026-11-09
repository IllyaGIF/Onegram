#ifndef TGCALLS_RTP_RTCP_H
#define TGCALLS_RTP_RTCP_H

#include <stddef.h>
#include <stdint.h>
#include <vector>

namespace tgcalls {
namespace rtp {

struct RtcpReportBlock {
    uint32_t sourceSsrc;
    uint8_t fractionLost;
    int32_t cumulativeLost;
    uint32_t extendedHighestSequence;
    uint32_t jitter;
    uint32_t lastSenderReport;
    uint32_t delaySinceLastSenderReport;
};

struct RtcpSenderInfo {
    uint64_t ntpTimestamp;
    uint32_t rtpTimestamp;
    uint32_t packetCount;
    uint32_t octetCount;
};

class TransportFeedback {
public:
    enum { kDeltaTickMicros = 250, kReferenceTickMicros = 64000 };

    struct PacketStatus {
        uint16_t sequenceNumber;
        bool received;
        int64_t arrivalMicros;
    };

    TransportFeedback();

    bool parse(const uint8_t *fci, size_t size);

    uint16_t baseSequence() const { return _baseSequence; }
    uint8_t feedbackSequence() const { return _feedbackSequence; }
    int64_t referenceMicros() const { return _referenceMicros; }
    const std::vector<PacketStatus> &packets() const { return _packets; }

private:
    uint16_t _baseSequence;
    uint8_t _feedbackSequence;
    int64_t _referenceMicros;
    std::vector<PacketStatus> _packets;
};

class TransportFeedbackBuilder {
public:
    TransportFeedbackBuilder();

    void reset(uint8_t feedbackSequence);
    bool isEmpty() const { return _symbols.empty(); }
    bool addReceivedPacket(uint16_t sequenceNumber, int64_t arrivalMicros);
    size_t serialize(uint8_t *fci, size_t capacity) const;
    size_t estimatedSize() const;

private:
    void appendSymbol(uint8_t symbol);

    bool _started;
    uint8_t _feedbackSequence;
    uint16_t _baseSequence;
    uint16_t _nextSequence;
    int32_t _referenceTicks;
    int64_t _lastArrivalTicks;
    std::vector<uint8_t> _symbols;
    std::vector<int16_t> _deltas;
    size_t _deltaBytes;
};

class RtcpHandler {
public:
    virtual ~RtcpHandler() {}
    virtual void onSenderReport(uint32_t senderSsrc, const RtcpSenderInfo &info) {}
    virtual void onReportBlock(uint32_t senderSsrc, const RtcpReportBlock &block) {}
    virtual void onNack(uint32_t senderSsrc, uint32_t mediaSsrc, const uint16_t *sequences, size_t count) {}
    virtual void onPictureLossIndication(uint32_t senderSsrc, uint32_t mediaSsrc) {}
    virtual void onFullIntraRequest(uint32_t senderSsrc, uint32_t mediaSsrc, uint8_t sequence) {}
    virtual void onReceiverEstimatedMaxBitrate(uint32_t senderSsrc, uint64_t bitrate, const uint32_t *ssrcs, size_t count) {}
    virtual void onTransportFeedback(uint32_t senderSsrc, uint32_t mediaSsrc, const uint8_t *fci, size_t size) {}
    virtual void onBye(uint32_t ssrc) {}
};

bool ParseRtcp(const uint8_t *data, size_t size, RtcpHandler &handler);
bool LooksLikeRtcp(const uint8_t *data, size_t size);

class RtcpWriter {
public:
    RtcpWriter(uint8_t *buffer, size_t capacity);

    bool addSenderReport(uint32_t ssrc, const RtcpSenderInfo &info, const RtcpReportBlock *blocks, size_t count);
    bool addReceiverReport(uint32_t ssrc, const RtcpReportBlock *blocks, size_t count);
    bool addSourceDescription(uint32_t ssrc, const char *cname);
    bool addNack(uint32_t senderSsrc, uint32_t mediaSsrc, const uint16_t *sequences, size_t count);
    bool addPictureLossIndication(uint32_t senderSsrc, uint32_t mediaSsrc);
    bool addFullIntraRequest(uint32_t senderSsrc, uint32_t mediaSsrc, uint8_t sequence);
    bool addReceiverEstimatedMaxBitrate(uint32_t senderSsrc, uint64_t bitrate, const uint32_t *ssrcs, size_t count);
    bool addTransportFeedback(uint32_t senderSsrc, uint32_t mediaSsrc, const TransportFeedbackBuilder &builder);

    size_t size() const { return _size; }
    size_t remaining() const { return _capacity - _size; }

private:
    uint8_t *begin(uint8_t countOrFormat, uint8_t packetType, size_t bodySize);
    void writeReportBlock(uint8_t *target, const RtcpReportBlock &block);

    uint8_t *_buffer;
    size_t _capacity;
    size_t _size;
};

}
}

#endif
