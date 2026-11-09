#ifndef TGCALLS_MEDIA_VIDEO_TOOLBOX_H264_ENCODER_H
#define TGCALLS_MEDIA_VIDEO_TOOLBOX_H264_ENCODER_H

#if !defined(ONEGRAM_ARMV6)

#include "media/VideoEncoder.h"
#include "media/VideoToolboxApi.h"

#include <pthread.h>

namespace tgcalls {

class VideoToolboxH264Encoder : public VideoEncoder {
public:
    static bool isAvailable();

    explicit VideoToolboxH264Encoder(VideoEncoderCallback *callback);
    ~VideoToolboxH264Encoder();

    VideoCodecType codec() const override { return VideoCodecType::H264; }
    bool isHardwareAccelerated() const override { return true; }
    void setRates(int bitrate, int fps) override;
    void setMaxResolution(int, int) override {}
    void encode(const VideoFrame &frame, bool keyframe) override;

private:
    struct PendingFrame;

    static void outputCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, OGVTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer);
    void handleOutput(PendingFrame *pending, OSStatus status, CMSampleBufferRef sampleBuffer);
    bool ensureSession(int width, int height);
    void destroySession();
    void applyRates();

    const VideoToolboxApi &_api;
    VideoEncoderCallback *_callback;
    pthread_mutex_t _mutex;
    OGVTCompressionSessionRef _session;
    int _width;
    int _height;
    int _bitrate;
    int _fps;
    bool _ratesDirty;
};

}

#endif

#endif
