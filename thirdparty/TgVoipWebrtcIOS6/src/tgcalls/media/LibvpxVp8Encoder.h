#ifndef TGCALLS_MEDIA_LIBVPX_VP8_ENCODER_H
#define TGCALLS_MEDIA_LIBVPX_VP8_ENCODER_H

#include "media/VideoEncoder.h"
#include "media/WorkerThread.h"

#include "vpx/vpx_encoder.h"

namespace tgcalls {

class LibvpxVp8Encoder : public VideoEncoder, private WorkerThread {
public:
    explicit LibvpxVp8Encoder(VideoEncoderCallback *callback);
    ~LibvpxVp8Encoder() noexcept;

    VideoCodecType codec() const override { return VideoCodecType::VP8; }
    bool isHardwareAccelerated() const override { return false; }
    void setRates(int bitrate, int fps) override;
    void setMaxResolution(int width, int height) override;
    void encode(const VideoFrame &frame, bool keyframe) override;

protected:
    void runIteration(int64_t nowMicros) override;
    int64_t nextWakeMicros(int64_t nowMicros) override;
    bool hasPendingWork() override;

private:
    LibvpxVp8Encoder(const LibvpxVp8Encoder &) = delete;
    LibvpxVp8Encoder &operator=(const LibvpxVp8Encoder &) = delete;

    std::shared_ptr<I420Buffer> prepareImage(const VideoFrame &frame, int maxWidth, int maxHeight);
    bool ensureEncoder(int width, int height, int bitrate, int fps);
    void applyRates(int bitrate, int fps);
    void destroyEncoder();

    VideoEncoderCallback *_callback;
    VideoFrame _pending;
    bool _hasPending;
    bool _pendingKeyframe;
    int _bitrate;
    int _fps;
    int _maxWidth;
    int _maxHeight;

    vpx_codec_ctx_t _context;
    vpx_codec_enc_cfg_t _configuration;
    bool _initialized;
    int _appliedBitrate;
    int _appliedFps;
    bool _hasPtsOrigin;
    int64_t _ptsOriginMicros;
    int64_t _lastPts;
    bool _reportedInputFailure;
};

}

#endif
