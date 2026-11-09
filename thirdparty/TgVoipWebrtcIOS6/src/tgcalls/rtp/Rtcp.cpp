#include "rtp/Rtcp.h"

#include "rtp/RtpByteIO.h"

#include <algorithm>
#include <string.h>

namespace tgcalls {
namespace rtp {

namespace {

const uint8_t kRtcpSenderReport = 200;
const uint8_t kRtcpReceiverReport = 201;
const uint8_t kRtcpSourceDescription = 202;
const uint8_t kRtcpBye = 203;
const uint8_t kRtcpTransportFeedback = 205;
const uint8_t kRtcpPayloadFeedback = 206;

const uint8_t kFeedbackGenericNack = 1;
const uint8_t kFeedbackTransportCc = 15;
const uint8_t kFeedbackPli = 1;
const uint8_t kFeedbackFir = 4;
const uint8_t kFeedbackApplication = 15;

const size_t kReportBlockSize = 24;
const size_t kMaxNackSequences = 512;

const uint8_t kSymbolNotReceived = 0;
const uint8_t kSymbolSmallDelta = 1;
const uint8_t kSymbolLargeDelta = 2;

void ReadReportBlock(const uint8_t *p, RtcpReportBlock *block) {
    block->sourceSsrc = ReadU32(p);
    block->fractionLost = p[4];
    block->cumulativeLost = ReadS24(p + 5);
    block->extendedHighestSequence = ReadU32(p + 8);
    block->jitter = ReadU32(p + 12);
    block->lastSenderReport = ReadU32(p + 16);
    block->delaySinceLastSenderReport = ReadU32(p + 20);
}

void ParseReportBlocks(uint32_t senderSsrc, const uint8_t *p, size_t available, uint8_t count, RtcpHandler &handler) {
    for (uint8_t i = 0; i < count && available >= kReportBlockSize; ++i) {
        RtcpReportBlock block;
        ReadReportBlock(p, &block);
        handler.onReportBlock(senderSsrc, block);
        p += kReportBlockSize;
        available -= kReportBlockSize;
    }
}

void ParseNack(uint32_t senderSsrc, uint32_t mediaSsrc, const uint8_t *fci, size_t size, RtcpHandler &handler) {
    uint16_t sequences[kMaxNackSequences];
    size_t count = 0;
    for (size_t offset = 0; offset + 4 <= size; offset += 4) {
        const uint16_t packetId = ReadU16(fci + offset);
        const uint16_t bitmask = ReadU16(fci + offset + 2);
        if (count < kMaxNackSequences) {
            sequences[count++] = packetId;
        }
        for (int bit = 0; bit < 16; ++bit) {
            if ((bitmask & (1 << bit)) != 0 && count < kMaxNackSequences) {
                sequences[count++] = (uint16_t)(packetId + bit + 1);
            }
        }
    }
    if (count != 0) {
        handler.onNack(senderSsrc, mediaSsrc, sequences, count);
    }
}

void ParseRemb(uint32_t senderSsrc, const uint8_t *fci, size_t size, RtcpHandler &handler) {
    if (size < 8 || memcmp(fci, "REMB", 4) != 0) {
        return;
    }
    const uint8_t count = fci[4];
    const uint8_t exponent = fci[5] >> 2;
    const uint32_t mantissa = ((uint32_t)(fci[5] & 0x03) << 16) | ((uint32_t)fci[6] << 8) | (uint32_t)fci[7];
    if (8 + (size_t)count * 4 > size || exponent > 46) {
        return;
    }
    uint32_t ssrcs[255];
    for (uint8_t i = 0; i < count; ++i) {
        ssrcs[i] = ReadU32(fci + 8 + (size_t)i * 4);
    }
    handler.onReceiverEstimatedMaxBitrate(senderSsrc, (uint64_t)mantissa << exponent, ssrcs, count);
}

}

bool LooksLikeRtcp(const uint8_t *data, size_t size) {
    return size >= 8 && (data[0] >> 6) == 2 && data[1] >= 192 && data[1] <= 223;
}

bool ParseRtcp(const uint8_t *data, size_t size, RtcpHandler &handler) {
    size_t offset = 0;
    bool parsedAny = false;
    while (offset + 4 <= size) {
        const uint8_t *header = data + offset;
        if ((header[0] >> 6) != 2) {
            return parsedAny;
        }
        const bool padding = (header[0] & 0x20) != 0;
        const uint8_t count = header[0] & 0x1F;
        const uint8_t type = header[1];
        const size_t length = ((size_t)ReadU16(header + 2) + 1) * 4;
        if (offset + length > size) {
            return parsedAny;
        }
        size_t bodySize = length - 4;
        if (padding && bodySize != 0) {
            const size_t paddingSize = header[length - 1];
            if (paddingSize > bodySize) {
                return parsedAny;
            }
            bodySize -= paddingSize;
        }
        const uint8_t *body = header + 4;
        switch (type) {
            case kRtcpSenderReport: {
                if (bodySize >= 24) {
                    const uint32_t senderSsrc = ReadU32(body);
                    RtcpSenderInfo info;
                    info.ntpTimestamp = ReadU64(body + 4);
                    info.rtpTimestamp = ReadU32(body + 12);
                    info.packetCount = ReadU32(body + 16);
                    info.octetCount = ReadU32(body + 20);
                    handler.onSenderReport(senderSsrc, info);
                    ParseReportBlocks(senderSsrc, body + 24, bodySize - 24, count, handler);
                }
                break;
            }
            case kRtcpReceiverReport: {
                if (bodySize >= 4) {
                    ParseReportBlocks(ReadU32(body), body + 4, bodySize - 4, count, handler);
                }
                break;
            }
            case kRtcpBye: {
                for (uint8_t i = 0; i < count && (size_t)(i + 1) * 4 <= bodySize; ++i) {
                    handler.onBye(ReadU32(body + (size_t)i * 4));
                }
                break;
            }
            case kRtcpTransportFeedback: {
                if (bodySize >= 8) {
                    const uint32_t senderSsrc = ReadU32(body);
                    const uint32_t mediaSsrc = ReadU32(body + 4);
                    if (count == kFeedbackGenericNack) {
                        ParseNack(senderSsrc, mediaSsrc, body + 8, bodySize - 8, handler);
                    } else if (count == kFeedbackTransportCc) {
                        handler.onTransportFeedback(senderSsrc, mediaSsrc, body + 8, bodySize - 8);
                    }
                }
                break;
            }
            case kRtcpPayloadFeedback: {
                if (bodySize >= 8) {
                    const uint32_t senderSsrc = ReadU32(body);
                    const uint32_t mediaSsrc = ReadU32(body + 4);
                    if (count == kFeedbackPli) {
                        handler.onPictureLossIndication(senderSsrc, mediaSsrc);
                    } else if (count == kFeedbackFir) {
                        for (size_t fci = 8; fci + 8 <= bodySize; fci += 8) {
                            handler.onFullIntraRequest(senderSsrc, ReadU32(body + fci), body[fci + 4]);
                        }
                    } else if (count == kFeedbackApplication) {
                        ParseRemb(senderSsrc, body + 8, bodySize - 8, handler);
                    }
                }
                break;
            }
            case kRtcpSourceDescription:
            default:
                break;
        }
        parsedAny = true;
        offset += length;
    }
    return parsedAny;
}

TransportFeedback::TransportFeedback() :
_baseSequence(0),
_feedbackSequence(0),
_referenceMicros(0) {
}

bool TransportFeedback::parse(const uint8_t *fci, size_t size) {
    _packets.clear();
    if (size < 8) {
        return false;
    }
    _baseSequence = ReadU16(fci);
    const uint16_t statusCount = ReadU16(fci + 2);
    _referenceMicros = (int64_t)ReadS24(fci + 4) * kReferenceTickMicros;
    _feedbackSequence = fci[7];
    if (statusCount == 0) {
        return false;
    }
    std::vector<uint8_t> symbols;
    symbols.reserve(statusCount);
    size_t offset = 8;
    while (symbols.size() < statusCount) {
        if (offset + 2 > size) {
            return false;
        }
        const uint16_t chunk = ReadU16(fci + offset);
        offset += 2;
        if ((chunk & 0x8000) == 0) {
            const uint8_t symbol = (uint8_t)((chunk >> 13) & 0x03);
            const size_t run = chunk & 0x1FFF;
            for (size_t i = 0; i < run && symbols.size() < statusCount; ++i) {
                symbols.push_back(symbol);
            }
        } else if ((chunk & 0x4000) == 0) {
            for (int i = 13; i >= 0 && symbols.size() < statusCount; --i) {
                symbols.push_back((uint8_t)((chunk >> i) & 0x01));
            }
        } else {
            for (int i = 6; i >= 0 && symbols.size() < statusCount; --i) {
                symbols.push_back((uint8_t)((chunk >> (i * 2)) & 0x03));
            }
        }
    }
    _packets.reserve(statusCount);
    int64_t arrival = _referenceMicros;
    for (size_t i = 0; i < symbols.size(); ++i) {
        PacketStatus status;
        status.sequenceNumber = (uint16_t)(_baseSequence + i);
        status.received = false;
        status.arrivalMicros = 0;
        if (symbols[i] == kSymbolSmallDelta) {
            if (offset + 1 > size) {
                return false;
            }
            arrival += (int64_t)fci[offset] * kDeltaTickMicros;
            offset += 1;
            status.received = true;
            status.arrivalMicros = arrival;
        } else if (symbols[i] == kSymbolLargeDelta) {
            if (offset + 2 > size) {
                return false;
            }
            arrival += (int64_t)(int16_t)ReadU16(fci + offset) * kDeltaTickMicros;
            offset += 2;
            status.received = true;
            status.arrivalMicros = arrival;
        } else if (symbols[i] != kSymbolNotReceived) {
            return false;
        }
        _packets.push_back(status);
    }
    return true;
}

TransportFeedbackBuilder::TransportFeedbackBuilder() :
_started(false),
_feedbackSequence(0),
_baseSequence(0),
_nextSequence(0),
_referenceTicks(0),
_lastArrivalTicks(0),
_deltaBytes(0) {
}

void TransportFeedbackBuilder::reset(uint8_t feedbackSequence) {
    _started = false;
    _feedbackSequence = feedbackSequence;
    _symbols.clear();
    _deltas.clear();
    _deltaBytes = 0;
}

void TransportFeedbackBuilder::appendSymbol(uint8_t symbol) {
    _symbols.push_back(symbol);
}

bool TransportFeedbackBuilder::addReceivedPacket(uint16_t sequenceNumber, int64_t arrivalMicros) {
    const int64_t arrivalTicks = arrivalMicros / TransportFeedback::kDeltaTickMicros;
    if (!_started) {
        _started = true;
        _baseSequence = sequenceNumber;
        _nextSequence = sequenceNumber;
        _referenceTicks = (int32_t)(arrivalMicros / TransportFeedback::kReferenceTickMicros);
        _lastArrivalTicks = (int64_t)_referenceTicks * (TransportFeedback::kReferenceTickMicros / TransportFeedback::kDeltaTickMicros);
    }
    const uint16_t gap = (uint16_t)(sequenceNumber - _nextSequence);
    if (gap >= 0x8000 || _symbols.size() + gap + 1 > 0xFFFF) {
        return false;
    }
    const int64_t delta = arrivalTicks - _lastArrivalTicks;
    if (delta < -32768 || delta > 32767) {
        return false;
    }
    for (uint16_t i = 0; i < gap; ++i) {
        appendSymbol(kSymbolNotReceived);
    }
    if (delta >= 0 && delta <= 255) {
        appendSymbol(kSymbolSmallDelta);
        _deltaBytes += 1;
    } else {
        appendSymbol(kSymbolLargeDelta);
        _deltaBytes += 2;
    }
    _deltas.push_back((int16_t)delta);
    _lastArrivalTicks = arrivalTicks;
    _nextSequence = (uint16_t)(sequenceNumber + 1);
    return true;
}

size_t TransportFeedbackBuilder::estimatedSize() const {
    return 8 + ((_symbols.size() + 6) / 7) * 2 + _deltaBytes + 3;
}

size_t TransportFeedbackBuilder::serialize(uint8_t *fci, size_t capacity) const {
    if (_symbols.empty() || capacity < 8) {
        return 0;
    }
    WriteU16(fci, _baseSequence);
    WriteU16(fci + 2, (uint16_t)_symbols.size());
    WriteU24(fci + 4, (uint32_t)_referenceTicks & 0x00FFFFFFU);
    fci[7] = _feedbackSequence;
    size_t offset = 8;
    size_t index = 0;
    const size_t count = _symbols.size();
    while (index < count) {
        size_t run = 1;
        while (index + run < count && run < 0x1FFF && _symbols[index + run] == _symbols[index]) {
            ++run;
        }
        uint16_t chunk = 0;
        if (run >= 14 || index + run == count) {
            chunk = (uint16_t)(((uint16_t)_symbols[index] << 13) | (uint16_t)run);
            index += run;
        } else {
            bool binary = true;
            for (size_t i = index; i < count && i < index + 14; ++i) {
                if (_symbols[i] > kSymbolSmallDelta) {
                    binary = false;
                    break;
                }
            }
            if (binary) {
                chunk = 0x8000;
                for (size_t i = 0; i < 14; ++i) {
                    const uint8_t symbol = index + i < count ? _symbols[index + i] : 0;
                    chunk |= (uint16_t)(symbol << (13 - i));
                }
                index += 14;
            } else {
                chunk = 0xC000;
                for (size_t i = 0; i < 7; ++i) {
                    const uint8_t symbol = index + i < count ? _symbols[index + i] : 0;
                    chunk |= (uint16_t)(symbol << ((6 - i) * 2));
                }
                index += 7;
            }
        }
        if (offset + 2 > capacity) {
            return 0;
        }
        WriteU16(fci + offset, chunk);
        offset += 2;
    }
    size_t deltaIndex = 0;
    for (size_t i = 0; i < count; ++i) {
        if (_symbols[i] == kSymbolSmallDelta) {
            if (offset + 1 > capacity) {
                return 0;
            }
            fci[offset++] = (uint8_t)_deltas[deltaIndex++];
        } else if (_symbols[i] == kSymbolLargeDelta) {
            if (offset + 2 > capacity) {
                return 0;
            }
            WriteU16(fci + offset, (uint16_t)_deltas[deltaIndex++]);
            offset += 2;
        }
    }
    while ((offset & 3) != 0) {
        if (offset >= capacity) {
            return 0;
        }
        fci[offset++] = 0;
    }
    return offset;
}

RtcpWriter::RtcpWriter(uint8_t *buffer, size_t capacity) :
_buffer(buffer),
_capacity(capacity),
_size(0) {
}

uint8_t *RtcpWriter::begin(uint8_t countOrFormat, uint8_t packetType, size_t bodySize) {
    const size_t total = 4 + bodySize;
    if ((total & 3) != 0 || _size + total > _capacity) {
        return 0;
    }
    uint8_t *header = _buffer + _size;
    header[0] = (uint8_t)(0x80 | (countOrFormat & 0x1F));
    header[1] = packetType;
    WriteU16(header + 2, (uint16_t)(total / 4 - 1));
    _size += total;
    return header + 4;
}

void RtcpWriter::writeReportBlock(uint8_t *target, const RtcpReportBlock &block) {
    WriteU32(target, block.sourceSsrc);
    target[4] = block.fractionLost;
    int32_t lost = block.cumulativeLost;
    if (lost > 0x7FFFFF) {
        lost = 0x7FFFFF;
    } else if (lost < -0x800000) {
        lost = -0x800000;
    }
    WriteU24(target + 5, (uint32_t)lost & 0x00FFFFFFU);
    WriteU32(target + 8, block.extendedHighestSequence);
    WriteU32(target + 12, block.jitter);
    WriteU32(target + 16, block.lastSenderReport);
    WriteU32(target + 20, block.delaySinceLastSenderReport);
}

bool RtcpWriter::addSenderReport(uint32_t ssrc, const RtcpSenderInfo &info, const RtcpReportBlock *blocks, size_t count) {
    if (count > 31) {
        count = 31;
    }
    uint8_t *body = begin((uint8_t)count, kRtcpSenderReport, 24 + count * kReportBlockSize);
    if (body == 0) {
        return false;
    }
    WriteU32(body, ssrc);
    WriteU64(body + 4, info.ntpTimestamp);
    WriteU32(body + 12, info.rtpTimestamp);
    WriteU32(body + 16, info.packetCount);
    WriteU32(body + 20, info.octetCount);
    for (size_t i = 0; i < count; ++i) {
        writeReportBlock(body + 24 + i * kReportBlockSize, blocks[i]);
    }
    return true;
}

bool RtcpWriter::addReceiverReport(uint32_t ssrc, const RtcpReportBlock *blocks, size_t count) {
    if (count > 31) {
        count = 31;
    }
    uint8_t *body = begin((uint8_t)count, kRtcpReceiverReport, 4 + count * kReportBlockSize);
    if (body == 0) {
        return false;
    }
    WriteU32(body, ssrc);
    for (size_t i = 0; i < count; ++i) {
        writeReportBlock(body + 4 + i * kReportBlockSize, blocks[i]);
    }
    return true;
}

bool RtcpWriter::addSourceDescription(uint32_t ssrc, const char *cname) {
    size_t length = strlen(cname);
    if (length > 255) {
        length = 255;
    }
    const size_t chunk = (4 + 2 + length + 1 + 3) & ~(size_t)3;
    uint8_t *body = begin(1, kRtcpSourceDescription, chunk);
    if (body == 0) {
        return false;
    }
    memset(body, 0, chunk);
    WriteU32(body, ssrc);
    body[4] = 1;
    body[5] = (uint8_t)length;
    memcpy(body + 6, cname, length);
    return true;
}

bool RtcpWriter::addNack(uint32_t senderSsrc, uint32_t mediaSsrc, const uint16_t *sequences, size_t count) {
    if (count == 0) {
        return false;
    }
    std::vector<uint16_t> sorted(sequences, sequences + count);
    std::sort(sorted.begin(), sorted.end(), [](uint16_t lhs, uint16_t rhs) {
        return IsNewerSequence(rhs, lhs);
    });
    std::vector<uint32_t> items;
    size_t index = 0;
    while (index < sorted.size()) {
        const uint16_t packetId = sorted[index];
        uint16_t bitmask = 0;
        ++index;
        while (index < sorted.size()) {
            const uint16_t distance = (uint16_t)(sorted[index] - packetId);
            if (distance == 0) {
                ++index;
                continue;
            }
            if (distance > 16) {
                break;
            }
            bitmask |= (uint16_t)(1 << (distance - 1));
            ++index;
        }
        items.push_back(((uint32_t)packetId << 16) | bitmask);
    }
    uint8_t *body = begin(kFeedbackGenericNack, kRtcpTransportFeedback, 8 + items.size() * 4);
    if (body == 0) {
        return false;
    }
    WriteU32(body, senderSsrc);
    WriteU32(body + 4, mediaSsrc);
    for (size_t i = 0; i < items.size(); ++i) {
        WriteU32(body + 8 + i * 4, items[i]);
    }
    return true;
}

bool RtcpWriter::addPictureLossIndication(uint32_t senderSsrc, uint32_t mediaSsrc) {
    uint8_t *body = begin(kFeedbackPli, kRtcpPayloadFeedback, 8);
    if (body == 0) {
        return false;
    }
    WriteU32(body, senderSsrc);
    WriteU32(body + 4, mediaSsrc);
    return true;
}

bool RtcpWriter::addFullIntraRequest(uint32_t senderSsrc, uint32_t mediaSsrc, uint8_t sequence) {
    uint8_t *body = begin(kFeedbackFir, kRtcpPayloadFeedback, 16);
    if (body == 0) {
        return false;
    }
    WriteU32(body, senderSsrc);
    WriteU32(body + 4, 0);
    WriteU32(body + 8, mediaSsrc);
    body[12] = sequence;
    body[13] = 0;
    body[14] = 0;
    body[15] = 0;
    return true;
}

bool RtcpWriter::addReceiverEstimatedMaxBitrate(uint32_t senderSsrc, uint64_t bitrate, const uint32_t *ssrcs, size_t count) {
    if (count > 255) {
        count = 255;
    }
    uint8_t *body = begin(kFeedbackApplication, kRtcpPayloadFeedback, 16 + count * 4);
    if (body == 0) {
        return false;
    }
    uint8_t exponent = 0;
    uint64_t mantissa = bitrate;
    while (mantissa > 0x3FFFFULL) {
        mantissa >>= 1;
        ++exponent;
    }
    WriteU32(body, senderSsrc);
    WriteU32(body + 4, 0);
    memcpy(body + 8, "REMB", 4);
    body[12] = (uint8_t)count;
    body[13] = (uint8_t)((exponent << 2) | (uint8_t)(mantissa >> 16));
    body[14] = (uint8_t)(mantissa >> 8);
    body[15] = (uint8_t)mantissa;
    for (size_t i = 0; i < count; ++i) {
        WriteU32(body + 16 + i * 4, ssrcs[i]);
    }
    return true;
}

bool RtcpWriter::addTransportFeedback(uint32_t senderSsrc, uint32_t mediaSsrc, const TransportFeedbackBuilder &builder) {
    if (_size + 12 > _capacity) {
        return false;
    }
    uint8_t *header = _buffer + _size;
    const size_t fciSize = builder.serialize(header + 12, _capacity - _size - 12);
    if (fciSize == 0) {
        return false;
    }
    header[0] = (uint8_t)(0x80 | kFeedbackTransportCc);
    header[1] = kRtcpTransportFeedback;
    WriteU16(header + 2, (uint16_t)((12 + fciSize) / 4 - 1));
    WriteU32(header + 4, senderSsrc);
    WriteU32(header + 8, mediaSsrc);
    _size += 12 + fciSize;
    return true;
}

}
}
