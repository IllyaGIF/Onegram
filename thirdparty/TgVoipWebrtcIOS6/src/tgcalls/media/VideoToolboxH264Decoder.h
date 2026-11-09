#ifndef TGCALLS_MEDIA_VIDEO_TOOLBOX_H264_DECODER_H
#define TGCALLS_MEDIA_VIDEO_TOOLBOX_H264_DECODER_H

#if !defined(ONEGRAM_ARMV6)

#include "media/VideoDecoder.h"
#include "media/VideoToolboxApi.h"

#include <vector>

namespace tgcalls {

class VideoToolboxH264Decoder : public VideoDecoder {
public:
    static bool isAvailable();

    VideoToolboxH264Decoder();
    ~VideoToolboxH264Decoder();

    Result decode(const EncodedVideoFrame &frame, VideoFrameSink &sink) override;

private:
    static void outputCallback(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, OGVTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration);

    bool updateFormat(const std::vector<uint8_t> &sps, const std::vector<uint8_t> &pps);
    bool createSession();
    void destroySession();

    const VideoToolboxApi &_api;
    CMVideoFormatDescriptionRef _format;
    OGVTDecompressionSessionRef _session;
    std::vector<uint8_t> _sps;
    std::vector<uint8_t> _pps;
    std::vector<uint8_t> _sample;

    VideoFrameSink *_currentSink;
    int _currentRotation;
    int64_t _currentTimestamp;
    bool _produced;
};

}

#endif

#endif
