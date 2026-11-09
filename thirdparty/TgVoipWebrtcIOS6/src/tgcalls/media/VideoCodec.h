#ifndef TGCALLS_MEDIA_VIDEO_CODEC_H
#define TGCALLS_MEDIA_VIDEO_CODEC_H

#include <stdint.h>
#include <string>
#include <vector>

namespace tgcalls {

enum class VideoCodecType {
    Unknown,
    VP8,
    H264
};

VideoCodecType VideoCodecTypeFromName(const std::string &name);
const char *VideoCodecName(VideoCodecType type);

struct EncodedVideoFrame {
    VideoCodecType codec = VideoCodecType::Unknown;
    std::vector<uint8_t> data;
    bool keyframe = false;
    uint32_t rtpTimestamp = 0;
    int rotation = 0;
    int64_t receiveMicros = 0;
    int width = 0;
    int height = 0;
};

}

#endif
