#ifndef TGCALLS_MEDIA_VIDEO_ENCODER_H
#define TGCALLS_MEDIA_VIDEO_ENCODER_H

#include "media/VideoCodec.h"
#include "media/VideoFrame.h"
#include "v2/MediaNegotiator.h"

#include <memory>
#include <vector>

namespace tgcalls {

class VideoEncoderCallback {
public:
    virtual ~VideoEncoderCallback() {}
    virtual void onEncodedFrame(const EncodedVideoFrame &frame, int64_t captureMicros, float encodeMillis) = 0;
};

class VideoEncoder {
public:
    virtual ~VideoEncoder() {}
    virtual VideoCodecType codec() const = 0;
    virtual bool isHardwareAccelerated() const = 0;
    virtual void setRates(int bitrate, int fps) = 0;
    virtual void setMaxResolution(int width, int height) = 0;
    virtual void encode(const VideoFrame &frame, bool keyframe) = 0;
};

std::unique_ptr<VideoEncoder> CreateVideoEncoder(VideoCodecType codec, VideoEncoderCallback *callback);
std::vector<VideoCodecSupport> SupportedVideoEncoders();

}

#endif
