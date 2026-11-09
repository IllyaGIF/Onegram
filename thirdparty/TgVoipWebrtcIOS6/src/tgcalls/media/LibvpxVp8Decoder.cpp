#include "media/LibvpxVp8Decoder.h"

#include "media/SystemInfo.h"
#include "Ios6DiagnosticLog.h"

#include "vpx/vp8dx.h"

#include <string.h>

namespace tgcalls {

namespace {

void CopyPlane(const uint8_t *source, int sourceStride, uint8_t *destination, int destinationStride, int width, int height) {
    for (int row = 0; row < height; ++row) {
        memcpy(destination, source, (size_t)width);
        source += sourceStride;
        destination += destinationStride;
    }
}

}

LibvpxVp8Decoder::LibvpxVp8Decoder() :
_initialized(false) {
    memset(&_context, 0, sizeof(_context));
}

LibvpxVp8Decoder::~LibvpxVp8Decoder() {
    destroyContext();
}

bool LibvpxVp8Decoder::ensureContext() {
    if (_initialized) {
        return true;
    }
    vpx_codec_dec_cfg_t configuration;
    memset(&configuration, 0, sizeof(configuration));
    configuration.threads = ProcessorCount() > 1 ? 2 : 1;
    const vpx_codec_err_t status = vpx_codec_dec_init(&_context, vpx_codec_vp8_dx(), &configuration, 0);
    if (status != VPX_CODEC_OK) {
        syslog(LOG_ERR, "IOS6MEDIA vpx.decoder.create.failed status=%d", (int)status);
        return false;
    }
    _initialized = true;
    syslog(LOG_NOTICE, "IOS6MEDIA vpx.decoder.created threads=%u", (unsigned int)configuration.threads);
    return true;
}

void LibvpxVp8Decoder::destroyContext() {
    if (_initialized) {
        vpx_codec_destroy(&_context);
        _initialized = false;
    }
}

VideoDecoder::Result LibvpxVp8Decoder::decode(const EncodedVideoFrame &frame, VideoFrameSink &sink) {
    if (frame.data.empty()) {
        return Skipped;
    }
    if (!ensureContext()) {
        return Failed;
    }
    const vpx_codec_err_t status = vpx_codec_decode(&_context, &frame.data[0], (unsigned int)frame.data.size(), 0, 0);
    if (status != VPX_CODEC_OK) {
        syslog(LOG_ERR, "IOS6MEDIA vpx.decoder.decode.failed status=%d key=%d", (int)status, frame.keyframe ? 1 : 0);
        if (status == VPX_CODEC_MEM_ERROR || status == VPX_CODEC_ERROR) {
            destroyContext();
        }
        return Failed;
    }
    bool produced = false;
    vpx_codec_iter_t iterator = 0;
    while (const vpx_image_t *image = vpx_codec_get_frame(&_context, &iterator)) {
        if (image->fmt != VPX_IMG_FMT_I420 || image->d_w == 0 || image->d_h == 0) {
            continue;
        }
        const int width = (int)image->d_w;
        const int height = (int)image->d_h;
        std::shared_ptr<I420Buffer> buffer = I420Buffer::create(width, height);
        if (!buffer) {
            return Failed;
        }
        const int chromaWidth = (width + 1) / 2;
        const int chromaHeight = (height + 1) / 2;
        CopyPlane(image->planes[VPX_PLANE_Y], image->stride[VPX_PLANE_Y], buffer->dataY(), buffer->strideY(), width, height);
        CopyPlane(image->planes[VPX_PLANE_U], image->stride[VPX_PLANE_U], buffer->dataU(), buffer->strideUV(), chromaWidth, chromaHeight);
        CopyPlane(image->planes[VPX_PLANE_V], image->stride[VPX_PLANE_V], buffer->dataV(), buffer->strideUV(), chromaWidth, chromaHeight);
        VideoFrame output;
        output.buffer = buffer;
        output.rotation = frame.rotation < 0 ? 0 : frame.rotation;
        output.timestampMicros = frame.receiveMicros;
        sink.onVideoFrame(output);
        produced = true;
    }
    return produced ? Decoded : Skipped;
}

}
