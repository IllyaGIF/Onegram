#ifndef TGCALLS_MEDIA_VIDEO_DECODER_H
#define TGCALLS_MEDIA_VIDEO_DECODER_H

#include "media/VideoCodec.h"
#include "media/VideoFrame.h"
#include "v2/MediaNegotiator.h"

#include <memory>
#include <vector>

namespace tgcalls {

class VideoDecoder {
public:
    enum Result {
        Decoded,
        Skipped,
        Failed
    };

    virtual ~VideoDecoder() {}
    virtual Result decode(const EncodedVideoFrame &frame, VideoFrameSink &sink) = 0;
};

std::unique_ptr<VideoDecoder> CreateVideoDecoder(VideoCodecType codec);
std::vector<VideoCodecSupport> SupportedVideoDecoders();

}

#endif
