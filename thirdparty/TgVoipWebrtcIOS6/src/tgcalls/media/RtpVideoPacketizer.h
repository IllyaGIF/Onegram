#ifndef TGCALLS_MEDIA_RTP_VIDEO_PACKETIZER_H
#define TGCALLS_MEDIA_RTP_VIDEO_PACKETIZER_H

#include "media/VideoCodec.h"

#include <stddef.h>
#include <stdint.h>
#include <vector>

namespace tgcalls {

class RtpVideoPacketizer {
public:
    static bool packetize(const EncodedVideoFrame &frame, size_t maxPayloadSize, uint16_t pictureId, std::vector<std::vector<uint8_t> > &payloads);

private:
    static bool packetizeH264(const EncodedVideoFrame &frame, size_t maxPayloadSize, std::vector<std::vector<uint8_t> > &payloads);
    static bool packetizeVp8(const EncodedVideoFrame &frame, size_t maxPayloadSize, uint16_t pictureId, std::vector<std::vector<uint8_t> > &payloads);
};

}

#endif
