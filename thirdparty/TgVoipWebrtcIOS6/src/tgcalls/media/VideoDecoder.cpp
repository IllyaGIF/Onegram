#include "media/VideoDecoder.h"

#include "media/LibvpxVp8Decoder.h"
#include "media/VideoToolboxH264Decoder.h"

namespace tgcalls {

std::unique_ptr<VideoDecoder> CreateVideoDecoder(VideoCodecType codec) {
#if !defined(ONEGRAM_ARMV6)
    if (codec == VideoCodecType::H264 && VideoToolboxH264Decoder::isAvailable()) {
        return std::unique_ptr<VideoDecoder>(new VideoToolboxH264Decoder());
    }
#endif
    if (codec == VideoCodecType::VP8) {
        return std::unique_ptr<VideoDecoder>(new LibvpxVp8Decoder());
    }
    return std::unique_ptr<VideoDecoder>();
}

std::vector<VideoCodecSupport> SupportedVideoDecoders() {
    std::vector<VideoCodecSupport> result;
#if !defined(ONEGRAM_ARMV6)
    if (VideoToolboxH264Decoder::isAvailable()) {
        VideoCodecSupport h264;
        h264.name = "H264";
        h264.parameters.push_back(std::make_pair(std::string("packetization-mode"), std::string("1")));
        result.push_back(h264);
    }
#endif
    VideoCodecSupport vp8;
    vp8.name = "VP8";
    result.push_back(vp8);
    return result;
}

}
