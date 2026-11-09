#ifndef TGCALLS_MEDIA_VIDEO_FRAME_ASSEMBLER_H
#define TGCALLS_MEDIA_VIDEO_FRAME_ASSEMBLER_H

#include "media/VideoCodec.h"

#include <stddef.h>
#include <stdint.h>
#include <vector>

namespace tgcalls {

class VideoFrameAssembler {
public:
    struct Output {
        std::vector<EncodedVideoFrame> frames;
        bool keyframeRequired = false;
    };

    struct PacketInfo {
        VideoCodecType codec;
        const uint8_t *payload;
        size_t payloadSize;
        uint16_t sequenceNumber;
        uint32_t timestamp;
        bool marker;
        int rotation;
        int64_t arrivalMicros;
    };

    VideoFrameAssembler();

    void reset();
    void insert(const PacketInfo &packet, Output &output);
    void abandon(uint16_t sequenceNumber, Output &output);
    void requireKeyframe(Output &output);
    bool waitingForKeyframe() const { return _waitingForKeyframe; }
    bool hasLastFrame() const { return _hasLastFrame; }
    uint16_t lastFrameEnd() const { return _lastFrameEnd; }

private:
    enum { kCapacity = 1024 };

    struct Slot {
        bool used;
        bool padding;
        bool begin;
        bool keyframe;
        bool marker;
        uint16_t sequenceNumber;
        uint32_t timestamp;
        int rotation;
        int width;
        int height;
        int64_t arrivalMicros;
        VideoCodecType codec;
        std::vector<uint8_t> data;
    };

    Slot &slot(uint16_t sequenceNumber) { return _slots[sequenceNumber & (kCapacity - 1)]; }
    bool isPresent(uint16_t sequenceNumber) { Slot &s = slot(sequenceNumber); return s.used && s.sequenceNumber == sequenceNumber; }
    bool depacketize(const PacketInfo &packet, Slot &target);
    bool depacketizeVp8(const uint8_t *payload, size_t size, Slot &target);
    bool depacketizeH264(const uint8_t *payload, size_t size, Slot &target);
    void assemble(Output &output);
    bool findKeyframeStart(uint16_t *start);
    void releaseOlderThan(uint16_t sequenceNumber);
    void clearAll();

    std::vector<Slot> _slots;
    bool _hasLastFrame;
    uint16_t _lastFrameEnd;
    bool _waitingForKeyframe;
    bool _hasNewest;
    uint16_t _newest;
};

}

#endif
