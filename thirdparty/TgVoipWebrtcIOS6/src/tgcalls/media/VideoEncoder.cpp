#include "media/VideoEncoder.h"

#include "media/LibvpxVp8Encoder.h"
#include "media/VideoToolboxH264Encoder.h"

namespace tgcalls {

std::unique_ptr<VideoEncoder> CreateVideoEncoder(VideoCodecType codec, VideoEncoderCallback *callback) {
#if !defined(ONEGRAM_ARMV6)
    if (codec == VideoCodecType::H264 && VideoToolboxH264Encoder::isAvailable()) {
        return std::unique_ptr<VideoEncoder>(new VideoToolboxH264Encoder(callback));
    }
#endif
    if (codec == VideoCodecType::VP8) {
        return std::unique_ptr<VideoEncoder>(new LibvpxVp8Encoder(callback));
    }
    return std::unique_ptr<VideoEncoder>();
}

std::vector<VideoCodecSupport> SupportedVideoEncoders() {
    std::vector<VideoCodecSupport> result;
#if !defined(ONEGRAM_ARMV6)
    if (VideoToolboxH264Encoder::isAvailable()) {
        VideoCodecSupport h264;
        h264.name = "H264";
        h264.parameters.push_back(std::make_pair(std::string("level-asymmetry-allowed"), std::string("1")));
        h264.parameters.push_back(std::make_pair(std::string("packetization-mode"), std::string("1")));
        h264.parameters.push_back(std::make_pair(std::string("profile-level-id"), std::string("42e01f")));
        result.push_back(h264);
    }
#endif
    VideoCodecSupport vp8;
    vp8.name = "VP8";
    result.push_back(vp8);
    return result;
}

}
