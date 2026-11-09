#include "media/LibvpxVp8Encoder.h"

#include "media/SystemInfo.h"
#include "media/VideoFrameConverter.h"
#include "media/VideoProfile.h"
#include "rtp/RtpTime.h"
#include "Ios6DiagnosticLog.h"

#include "vpx/vp8cx.h"

#include <string.h>

namespace tgcalls {

namespace {

const int kTimebase = 90000;

void WrapI420(vpx_image_t *image, I420Buffer &buffer) {
    vpx_img_wrap(image, VPX_IMG_FMT_I420, (unsigned int)buffer.width(), (unsigned int)buffer.height(), 1, buffer.dataY());
    image->planes[VPX_PLANE_Y] = buffer.dataY();
    image->planes[VPX_PLANE_U] = buffer.dataU();
    image->planes[VPX_PLANE_V] = buffer.dataV();
    image->stride[VPX_PLANE_Y] = buffer.strideY();
    image->stride[VPX_PLANE_U] = buffer.strideUV();
    image->stride[VPX_PLANE_V] = buffer.strideUV();
}

int MaxIntraBitratePercent(int fps) {
    const int percent = 600 / 2 * fps / 10;
    return percent < 300 ? 300 : percent;
}

}

LibvpxVp8Encoder::LibvpxVp8Encoder(VideoEncoderCallback *callback) :
_callback(callback),
_hasPending(false),
_pendingKeyframe(false),
_bitrate(300000),
_fps(30),
_maxWidth(0),
_maxHeight(0),
_initialized(false),
_appliedBitrate(0),
_appliedFps(0),
_hasPtsOrigin(false),
_ptsOriginMicros(0),
_lastPts(-1),
_reportedInputFailure(false) {
    memset(&_context, 0, sizeof(_context));
    memset(&_configuration, 0, sizeof(_configuration));
    start(1);
}

LibvpxVp8Encoder::~LibvpxVp8Encoder() noexcept {
    stop();
    destroyEncoder();
}

void LibvpxVp8Encoder::setRates(int bitrate, int fps) {
    ScopedMutex lock(&_mutex);
    _bitrate = bitrate > 0 ? bitrate : _bitrate;
    _fps = fps > 0 ? fps : _fps;
}

void LibvpxVp8Encoder::setMaxResolution(int width, int height) {
    ScopedMutex lock(&_mutex);
    _maxWidth = width;
    _maxHeight = height;
}

void LibvpxVp8Encoder::encode(const VideoFrame &frame, bool keyframe) {
    if (!frame.buffer) {
        return;
    }
    {
        ScopedMutex lock(&_mutex);
        _pending = frame;
        _hasPending = true;
        _pendingKeyframe = _pendingKeyframe || keyframe;
    }
    wake();
}

bool LibvpxVp8Encoder::hasPendingWork() {
    return _hasPending;
}

int64_t LibvpxVp8Encoder::nextWakeMicros(int64_t nowMicros) {
    return nowMicros + 1000000;
}

void LibvpxVp8Encoder::destroyEncoder() {
    if (_initialized) {
        vpx_codec_destroy(&_context);
        _initialized = false;
    }
}

bool LibvpxVp8Encoder::ensureEncoder(int width, int height, int bitrate, int fps) {
    if (_initialized && (int)_configuration.g_w == width && (int)_configuration.g_h == height) {
        return true;
    }
    destroyEncoder();
    if (vpx_codec_enc_config_default(vpx_codec_vp8_cx(), &_configuration, 0) != VPX_CODEC_OK) {
        return false;
    }
    const int processors = ProcessorCount();
    _configuration.g_w = (unsigned int)width;
    _configuration.g_h = (unsigned int)height;
    _configuration.g_timebase.num = 1;
    _configuration.g_timebase.den = kTimebase;
    _configuration.g_threads = (processors > 1 && width * height >= 640 * 360) ? 2 : 1;
    _configuration.g_pass = VPX_RC_ONE_PASS;
    _configuration.g_lag_in_frames = 0;
    _configuration.g_error_resilient = 0;
    _configuration.rc_end_usage = VPX_CBR;
    _configuration.rc_target_bitrate = (unsigned int)(bitrate / 1000);
    _configuration.rc_resize_allowed = 0;
    _configuration.rc_dropframe_thresh = 30;
    _configuration.rc_min_quantizer = 2;
    _configuration.rc_max_quantizer = 56;
    _configuration.rc_undershoot_pct = 100;
    _configuration.rc_overshoot_pct = 15;
    _configuration.rc_buf_initial_sz = 500;
    _configuration.rc_buf_optimal_sz = 600;
    _configuration.rc_buf_sz = 1000;
    _configuration.kf_mode = VPX_KF_AUTO;
    _configuration.kf_min_dist = 0;
    _configuration.kf_max_dist = 3000;
    const vpx_codec_err_t status = vpx_codec_enc_init(&_context, vpx_codec_vp8_cx(), &_configuration, 0);
    if (status != VPX_CODEC_OK) {
        syslog(LOG_ERR, "IOS6MEDIA vpx.encoder.create.failed status=%d size=%dx%d", (int)status, width, height);
        return false;
    }
    _initialized = true;
    vpx_codec_control(&_context, VP8E_SET_CPUUSED, VideoProfile::current().softwareEncoderSpeed);
    vpx_codec_control(&_context, VP8E_SET_NOISE_SENSITIVITY, 0);
    vpx_codec_control(&_context, VP8E_SET_STATIC_THRESHOLD, 1);
    vpx_codec_control(&_context, VP8E_SET_TOKEN_PARTITIONS, (int)VP8_ONE_TOKENPARTITION);
    vpx_codec_control(&_context, VP8E_SET_MAX_INTRA_BITRATE_PCT, MaxIntraBitratePercent(fps));
    _appliedBitrate = bitrate;
    _appliedFps = fps;
    syslog(LOG_NOTICE, "IOS6MEDIA vpx.encoder.created size=%dx%d threads=%u speed=%d", width, height, _configuration.g_threads, VideoProfile::current().softwareEncoderSpeed);
    return true;
}

void LibvpxVp8Encoder::applyRates(int bitrate, int fps) {
    if (!_initialized) {
        return;
    }
    if (bitrate != _appliedBitrate) {
        _configuration.rc_target_bitrate = (unsigned int)(bitrate / 1000);
        if (vpx_codec_enc_config_set(&_context, &_configuration) == VPX_CODEC_OK) {
            _appliedBitrate = bitrate;
        }
    }
    if (fps != _appliedFps) {
        vpx_codec_control(&_context, VP8E_SET_MAX_INTRA_BITRATE_PCT, MaxIntraBitratePercent(fps));
        _appliedFps = fps;
    }
}

std::shared_ptr<I420Buffer> LibvpxVp8Encoder::prepareImage(const VideoFrame &frame, int maxWidth, int maxHeight) {
    VideoFrameBuffer &source = *frame.buffer;
    const VideoCropPlan plan = PlanVideoCrop(source.width(), source.height(), maxWidth, maxHeight);
    if (source.type() == VideoFrameBufferType::I420) {
        std::shared_ptr<I420Buffer> planar = std::static_pointer_cast<I420Buffer>(frame.buffer);
        if (plan.x == 0 && plan.y == 0 && plan.outputWidth == planar->width() && plan.outputHeight == planar->height()) {
            return planar;
        }
        return ScaleI420(*planar, plan);
    }
#if TGCALLS_VIDEO_NATIVE_BUFFERS
    CVPixelBufferRef pixelBuffer = static_cast<NativeVideoBuffer &>(source).pixelBuffer();
    RawVideoImage image;
    memset(&image, 0, sizeof(image));
    switch (CVPixelBufferGetPixelFormatType(pixelBuffer)) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            image.format = RawVideoFormat::NV12FullRange;
            break;
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            image.format = RawVideoFormat::NV12VideoRange;
            break;
        case kCVPixelFormatType_32BGRA:
            image.format = RawVideoFormat::BGRA;
            break;
        case kCVPixelFormatType_422YpCbCr8:
            image.format = RawVideoFormat::UYVY;
            break;
        case kCVPixelFormatType_422YpCbCr8_yuvs:
            image.format = RawVideoFormat::YUY2;
            break;
        default:
            if (!_reportedInputFailure) {
                _reportedInputFailure = true;
                syslog(LOG_ERR, "IOS6MEDIA vpx.encoder.format.unsupported format=%08x", (unsigned int)CVPixelBufferGetPixelFormatType(pixelBuffer));
            }
            return std::shared_ptr<I420Buffer>();
    }
    if (CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) {
        return std::shared_ptr<I420Buffer>();
    }
    image.width = source.width();
    image.height = source.height();
    if (CVPixelBufferIsPlanar(pixelBuffer)) {
        const size_t planes = CVPixelBufferGetPlaneCount(pixelBuffer);
        for (size_t i = 0; i < planes && i < 2; ++i) {
            image.planes[i] = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, i));
            image.strides[i] = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, i);
        }
    } else {
        image.planes[0] = static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(pixelBuffer));
        image.strides[0] = CVPixelBufferGetBytesPerRow(pixelBuffer);
    }
    std::shared_ptr<I420Buffer> result = ConvertToI420(CropRawVideoImage(image, plan.x, plan.y, plan.width, plan.height), plan.outputWidth, plan.outputHeight);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    return result;
#else
    return std::shared_ptr<I420Buffer>();
#endif
}

void LibvpxVp8Encoder::runIteration(int64_t) {
    VideoFrame frame;
    bool keyframe = false;
    int bitrate = 0;
    int fps = 0;
    int maxWidth = 0;
    int maxHeight = 0;
    {
        ScopedMutex lock(&_mutex);
        if (!_hasPending) {
            return;
        }
        frame = _pending;
        _pending = VideoFrame();
        _hasPending = false;
        keyframe = _pendingKeyframe;
        _pendingKeyframe = false;
        bitrate = _bitrate;
        fps = _fps;
        maxWidth = _maxWidth;
        maxHeight = _maxHeight;
    }
    const int64_t started = rtp::MonotonicMicros();
    std::shared_ptr<I420Buffer> buffer = prepareImage(frame, maxWidth, maxHeight);
    if (!buffer) {
        if (!_reportedInputFailure) {
            _reportedInputFailure = true;
            syslog(LOG_ERR, "IOS6MEDIA vpx.encoder.input.failed type=%d size=%dx%d", (int)frame.buffer->type(), frame.buffer->width(), frame.buffer->height());
        }
        return;
    }
    const int width = buffer->width();
    const int height = buffer->height();
    if (!ensureEncoder(width, height, bitrate, fps)) {
        return;
    }
    applyRates(bitrate, fps);
    vpx_image_t image;
    memset(&image, 0, sizeof(image));
    WrapI420(&image, *buffer);
    if (!_hasPtsOrigin) {
        _hasPtsOrigin = true;
        _ptsOriginMicros = frame.timestampMicros;
    }
    int64_t pts = (frame.timestampMicros - _ptsOriginMicros) * kTimebase / 1000000;
    if (pts <= _lastPts) {
        pts = _lastPts + 1;
    }
    _lastPts = pts;
    const unsigned long duration = (unsigned long)(kTimebase / (fps > 0 ? fps : 30));
    const vpx_codec_err_t status = vpx_codec_encode(&_context, &image, (vpx_codec_pts_t)pts, duration, keyframe ? VPX_EFLAG_FORCE_KF : 0, VPX_DL_REALTIME);
    buffer.reset();
    frame.buffer.reset();
    if (status != VPX_CODEC_OK) {
        syslog(LOG_ERR, "IOS6MEDIA vpx.encoder.encode.failed status=%d", (int)status);
        destroyEncoder();
        return;
    }
    EncodedVideoFrame output;
    output.codec = VideoCodecType::VP8;
    output.rotation = frame.rotation;
    output.width = width;
    output.height = height;
    vpx_codec_iter_t iterator = 0;
    while (const vpx_codec_cx_pkt_t *packet = vpx_codec_get_cx_data(&_context, &iterator)) {
        if (packet->kind != VPX_CODEC_CX_FRAME_PKT || packet->data.frame.sz == 0) {
            continue;
        }
        const uint8_t *bytes = static_cast<const uint8_t *>(packet->data.frame.buf);
        output.data.insert(output.data.end(), bytes, bytes + packet->data.frame.sz);
        output.keyframe = output.keyframe || (packet->data.frame.flags & VPX_FRAME_IS_KEY) != 0;
    }
    if (output.data.empty()) {
        return;
    }
    const float encodeMillis = (float)(rtp::MonotonicMicros() - started) / 1000.0f;
    _callback->onEncodedFrame(output, frame.timestampMicros, encodeMillis);
}

}
