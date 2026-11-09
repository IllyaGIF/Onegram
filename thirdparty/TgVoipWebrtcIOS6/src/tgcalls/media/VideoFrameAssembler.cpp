#include "media/VideoFrameAssembler.h"

#include "media/H264.h"
#include "rtp/RtpByteIO.h"

#include <string.h>

namespace tgcalls {

VideoFrameAssembler::VideoFrameAssembler() :
_slots(kCapacity),
_hasLastFrame(false),
_lastFrameEnd(0),
_waitingForKeyframe(true),
_hasNewest(false),
_newest(0) {
    clearAll();
}

void VideoFrameAssembler::clearAll() {
    for (size_t i = 0; i < _slots.size(); ++i) {
        _slots[i].used = false;
        _slots[i].data.clear();
    }
}

void VideoFrameAssembler::reset() {
    clearAll();
    _hasLastFrame = false;
    _lastFrameEnd = 0;
    _waitingForKeyframe = true;
    _hasNewest = false;
}

void VideoFrameAssembler::requireKeyframe(Output &output) {
    if (!_waitingForKeyframe) {
        _waitingForKeyframe = true;
    }
    output.keyframeRequired = true;
}

bool VideoFrameAssembler::depacketizeVp8(const uint8_t *payload, size_t size, Slot &target) {
    if (size < 1) {
        return false;
    }
    size_t offset = 1;
    const bool extended = (payload[0] & 0x80) != 0;
    const bool start = (payload[0] & 0x10) != 0;
    const uint8_t partition = payload[0] & 0x07;
    if (extended) {
        if (offset >= size) {
            return false;
        }
        const uint8_t flags = payload[offset++];
        if (flags & 0x80) {
            if (offset >= size) {
                return false;
            }
            const bool longPictureId = (payload[offset] & 0x80) != 0;
            offset += longPictureId ? 2 : 1;
        }
        if (flags & 0x40) {
            offset += 1;
        }
        if (flags & 0x30) {
            offset += 1;
        }
    }
    if (offset >= size) {
        return false;
    }
    const uint8_t *frame = payload + offset;
    const size_t frameSize = size - offset;
    target.begin = start && partition == 0;
    target.keyframe = target.begin && (frame[0] & 0x01) == 0;
    if (target.keyframe && frameSize >= 10 && frame[3] == 0x9D && frame[4] == 0x01 && frame[5] == 0x2A) {
        target.width = (int)((((uint16_t)frame[7] << 8) | (uint16_t)frame[6]) & 0x3FFF);
        target.height = (int)((((uint16_t)frame[9] << 8) | (uint16_t)frame[8]) & 0x3FFF);
    }
    target.data.assign(frame, frame + frameSize);
    return true;
}

bool VideoFrameAssembler::depacketizeH264(const uint8_t *payload, size_t size, Slot &target) {
    if (size < 1) {
        return false;
    }
    target.data.clear();
    const uint8_t type = h264::NalTypeOf(payload[0]);
    if (type >= 1 && type <= 23) {
        if (type == h264::NalIdr) {
            target.keyframe = true;
        }
        if (type == h264::NalSps) {
            target.keyframe = true;
            h264::ParseSpsResolution(payload, size, &target.width, &target.height);
        }
        target.begin = type == h264::NalSps || type == h264::NalPps || type == h264::NalAud || type == h264::NalSei ||
            ((type == h264::NalSlice || type == h264::NalIdr) && size > 1 && (payload[1] & 0x80) != 0);
        h264::AppendAnnexB(target.data, payload, size);
        return true;
    }
    if (type == h264::NalStapA) {
        size_t offset = 1;
        bool first = true;
        while (offset + 2 <= size) {
            const size_t length = rtp::ReadU16(payload + offset);
            offset += 2;
            if (length == 0 || offset + length > size) {
                return false;
            }
            const uint8_t *nal = payload + offset;
            const uint8_t nalType = h264::NalTypeOf(nal[0]);
            if (nalType == h264::NalIdr) {
                target.keyframe = true;
            }
            if (nalType == h264::NalSps) {
                target.keyframe = true;
                h264::ParseSpsResolution(nal, length, &target.width, &target.height);
            }
            if (first) {
                target.begin = nalType == h264::NalSps || nalType == h264::NalPps || nalType == h264::NalAud || nalType == h264::NalSei ||
                    ((nalType == h264::NalSlice || nalType == h264::NalIdr) && length > 1 && (nal[1] & 0x80) != 0);
                first = false;
            }
            h264::AppendAnnexB(target.data, nal, length);
            offset += length;
        }
        return !target.data.empty();
    }
    if (type == h264::NalFuA) {
        if (size < 3) {
            return false;
        }
        const uint8_t header = payload[1];
        const uint8_t nalType = header & 0x1F;
        const bool start = (header & 0x80) != 0;
        if (start) {
            const uint8_t nalHeader = (uint8_t)((payload[0] & 0xE0) | nalType);
            static const uint8_t kStartCode[4] = { 0, 0, 0, 1 };
            target.data.insert(target.data.end(), kStartCode, kStartCode + 4);
            target.data.push_back(nalHeader);
            target.begin = (nalType == h264::NalSlice || nalType == h264::NalIdr) && (payload[2] & 0x80) != 0;
            target.keyframe = nalType == h264::NalIdr;
        }
        target.data.insert(target.data.end(), payload + 2, payload + size);
        return true;
    }
    return false;
}

bool VideoFrameAssembler::depacketize(const PacketInfo &packet, Slot &target) {
    target.begin = false;
    target.keyframe = false;
    target.width = 0;
    target.height = 0;
    switch (packet.codec) {
        case VideoCodecType::VP8:
            return depacketizeVp8(packet.payload, packet.payloadSize, target);
        case VideoCodecType::H264:
            return depacketizeH264(packet.payload, packet.payloadSize, target);
        default:
            return false;
    }
}

void VideoFrameAssembler::insert(const PacketInfo &packet, Output &output) {
    const uint16_t sequence = packet.sequenceNumber;
    if (_hasLastFrame && !rtp::IsNewerSequence(sequence, _lastFrameEnd)) {
        return;
    }
    if (_hasNewest && rtp::IsNewerSequence(sequence, _newest) && (uint16_t)(sequence - _newest) >= kCapacity) {
        clearAll();
        _hasLastFrame = false;
        requireKeyframe(output);
    }
    if (_hasLastFrame && (uint16_t)(sequence - _lastFrameEnd) >= kCapacity) {
        clearAll();
        _hasLastFrame = false;
        requireKeyframe(output);
    }
    Slot &target = slot(sequence);
    if (target.used) {
        if (target.sequenceNumber == sequence) {
            return;
        }
        clearAll();
        _hasLastFrame = false;
        requireKeyframe(output);
    }
    target.padding = packet.payloadSize == 0;
    if (!target.padding && !depacketize(packet, target)) {
        return;
    }
    if (target.padding) {
        target.data.clear();
        target.begin = true;
        target.keyframe = false;
        target.width = 0;
        target.height = 0;
    }
    target.used = true;
    target.sequenceNumber = sequence;
    target.timestamp = packet.timestamp;
    target.marker = packet.marker || target.padding;
    target.rotation = packet.rotation;
    target.arrivalMicros = packet.arrivalMicros;
    target.codec = packet.codec;
    if (!_hasNewest || rtp::IsNewerSequence(sequence, _newest)) {
        _newest = sequence;
        _hasNewest = true;
    }
    if (!_hasLastFrame && !target.padding) {
        output.keyframeRequired = output.keyframeRequired || _waitingForKeyframe;
    }
    assemble(output);
}

bool VideoFrameAssembler::findKeyframeStart(uint16_t *start) {
    bool found = false;
    uint16_t best = 0;
    for (size_t i = 0; i < _slots.size(); ++i) {
        const Slot &candidate = _slots[i];
        if (!candidate.used || candidate.padding || !candidate.begin || !candidate.keyframe) {
            continue;
        }
        if (_hasLastFrame && !rtp::IsNewerSequence(candidate.sequenceNumber, _lastFrameEnd)) {
            continue;
        }
        if (!found || rtp::IsNewerSequence(best, candidate.sequenceNumber)) {
            best = candidate.sequenceNumber;
            found = true;
        }
    }
    if (found) {
        *start = best;
    }
    return found;
}

void VideoFrameAssembler::releaseOlderThan(uint16_t sequenceNumber) {
    for (size_t i = 0; i < _slots.size(); ++i) {
        Slot &candidate = _slots[i];
        if (candidate.used && rtp::IsNewerSequence(sequenceNumber, candidate.sequenceNumber)) {
            candidate.used = false;
            candidate.data.clear();
        }
    }
}

void VideoFrameAssembler::assemble(Output &output) {
    for (;;) {
        uint16_t start = 0;
        if (_hasLastFrame && !_waitingForKeyframe) {
            start = (uint16_t)(_lastFrameEnd + 1);
            if (!isPresent(start)) {
                return;
            }
        } else if (!findKeyframeStart(&start)) {
            return;
        }
        Slot &first = slot(start);
        if (first.padding) {
            first.used = false;
            _lastFrameEnd = start;
            _hasLastFrame = true;
            continue;
        }
        const uint32_t timestamp = first.timestamp;
        uint16_t end = start;
        bool complete = false;
        for (uint16_t count = 0; count < kCapacity; ++count) {
            const uint16_t sequence = (uint16_t)(start + count);
            if (!isPresent(sequence)) {
                return;
            }
            Slot &current = slot(sequence);
            if (current.timestamp != timestamp || current.padding) {
                if (count == 0) {
                    return;
                }
                end = (uint16_t)(sequence - 1);
                complete = true;
                break;
            }
            if (current.marker) {
                end = sequence;
                complete = true;
                break;
            }
            const uint16_t next = (uint16_t)(sequence + 1);
            if (isPresent(next) && slot(next).timestamp != timestamp) {
                end = sequence;
                complete = true;
                break;
            }
        }
        if (!complete) {
            return;
        }
        EncodedVideoFrame frame;
        frame.codec = first.codec;
        frame.rtpTimestamp = timestamp;
        frame.receiveMicros = first.arrivalMicros;
        frame.rotation = -1;
        size_t total = 0;
        for (uint16_t sequence = start;; ++sequence) {
            total += slot(sequence).data.size();
            if (sequence == end) {
                break;
            }
        }
        frame.data.reserve(total);
        for (uint16_t sequence = start;; ++sequence) {
            Slot &current = slot(sequence);
            frame.data.insert(frame.data.end(), current.data.begin(), current.data.end());
            frame.keyframe = frame.keyframe || current.keyframe;
            if (current.width > 0 && current.height > 0) {
                frame.width = current.width;
                frame.height = current.height;
            }
            if (current.rotation >= 0) {
                frame.rotation = current.rotation;
            }
            if (current.arrivalMicros > frame.receiveMicros) {
                frame.receiveMicros = current.arrivalMicros;
            }
            current.used = false;
            current.data.clear();
            if (sequence == end) {
                break;
            }
        }
        if (_waitingForKeyframe) {
            releaseOlderThan(start);
            _waitingForKeyframe = false;
        }
        _hasLastFrame = true;
        _lastFrameEnd = end;
        output.frames.push_back(frame);
    }
}

void VideoFrameAssembler::abandon(uint16_t sequenceNumber, Output &output) {
    if (!_hasLastFrame || _waitingForKeyframe) {
        return;
    }
    if (rtp::IsNewerSequence(sequenceNumber, _lastFrameEnd)) {
        requireKeyframe(output);
        assemble(output);
    }
}

}
