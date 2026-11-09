#include "media/RtpVideoPacketizer.h"

#include "media/H264.h"

namespace tgcalls {

bool RtpVideoPacketizer::packetize(const EncodedVideoFrame &frame, size_t maxPayloadSize, uint16_t pictureId, std::vector<std::vector<uint8_t> > &payloads) {
    payloads.clear();
    if (frame.data.empty() || maxPayloadSize < 64) {
        return false;
    }
    switch (frame.codec) {
        case VideoCodecType::H264:
            return packetizeH264(frame, maxPayloadSize, payloads);
        case VideoCodecType::VP8:
            return packetizeVp8(frame, maxPayloadSize, pictureId, payloads);
        default:
            return false;
    }
}

bool RtpVideoPacketizer::packetizeH264(const EncodedVideoFrame &frame, size_t maxPayloadSize, std::vector<std::vector<uint8_t> > &payloads) {
    std::vector<h264::NalUnit> units;
    h264::SplitAnnexB(&frame.data[0], frame.data.size(), units);
    size_t index = 0;
    while (index < units.size()) {
        const h264::NalUnit &unit = units[index];
        if (unit.size == 0) {
            ++index;
            continue;
        }
        if (unit.size > maxPayloadSize) {
            const uint8_t header = unit.data[0];
            const uint8_t indicator = (uint8_t)((header & 0xE0) | h264::NalFuA);
            const uint8_t type = h264::NalTypeOf(header);
            const size_t remaining = unit.size - 1;
            const size_t capacity = maxPayloadSize - 2;
            const size_t count = (remaining + capacity - 1) / capacity;
            const size_t fragment = (remaining + count - 1) / count;
            size_t offset = 1;
            for (size_t i = 0; i < count; ++i) {
                const size_t length = offset + fragment > unit.size ? unit.size - offset : fragment;
                std::vector<uint8_t> payload;
                payload.reserve(length + 2);
                payload.push_back(indicator);
                uint8_t fuHeader = type;
                if (i == 0) {
                    fuHeader |= 0x80;
                }
                if (i + 1 == count) {
                    fuHeader |= 0x40;
                }
                payload.push_back(fuHeader);
                payload.insert(payload.end(), unit.data + offset, unit.data + offset + length);
                payloads.push_back(payload);
                offset += length;
            }
            ++index;
            continue;
        }
        size_t aggregated = 1 + 2 + unit.size;
        size_t last = index;
        while (last + 1 < units.size() && units[last + 1].size > 0 && aggregated + 2 + units[last + 1].size <= maxPayloadSize) {
            aggregated += 2 + units[last + 1].size;
            ++last;
        }
        if (last == index) {
            payloads.push_back(std::vector<uint8_t>(unit.data, unit.data + unit.size));
            ++index;
            continue;
        }
        std::vector<uint8_t> payload;
        payload.reserve(aggregated);
        uint8_t nri = 0;
        bool forbidden = false;
        for (size_t i = index; i <= last; ++i) {
            const uint8_t header = units[i].data[0];
            if ((header & 0x60) > nri) {
                nri = header & 0x60;
            }
            forbidden = forbidden || (header & 0x80) != 0;
        }
        payload.push_back((uint8_t)((forbidden ? 0x80 : 0x00) | nri | h264::NalStapA));
        for (size_t i = index; i <= last; ++i) {
            payload.push_back((uint8_t)(units[i].size >> 8));
            payload.push_back((uint8_t)units[i].size);
            payload.insert(payload.end(), units[i].data, units[i].data + units[i].size);
        }
        payloads.push_back(payload);
        index = last + 1;
    }
    return !payloads.empty();
}

bool RtpVideoPacketizer::packetizeVp8(const EncodedVideoFrame &frame, size_t maxPayloadSize, uint16_t pictureId, std::vector<std::vector<uint8_t> > &payloads) {
    const size_t descriptorSize = 4;
    const size_t capacity = maxPayloadSize - descriptorSize;
    const size_t count = (frame.data.size() + capacity - 1) / capacity;
    const size_t fragment = (frame.data.size() + count - 1) / count;
    size_t offset = 0;
    for (size_t i = 0; i < count; ++i) {
        const size_t length = offset + fragment > frame.data.size() ? frame.data.size() - offset : fragment;
        std::vector<uint8_t> payload;
        payload.reserve(descriptorSize + length);
        payload.push_back((uint8_t)(0x80 | (i == 0 ? 0x10 : 0x00)));
        payload.push_back(0x80);
        payload.push_back((uint8_t)(0x80 | ((pictureId >> 8) & 0x7F)));
        payload.push_back((uint8_t)pictureId);
        payload.insert(payload.end(), frame.data.begin() + offset, frame.data.begin() + offset + length);
        payloads.push_back(payload);
        offset += length;
    }
    return !payloads.empty();
}

}
