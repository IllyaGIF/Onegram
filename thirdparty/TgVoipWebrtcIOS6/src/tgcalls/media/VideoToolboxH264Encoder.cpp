#include "media/VideoToolboxH264Encoder.h"

#if !defined(ONEGRAM_ARMV6)

#include "media/H264.h"
#include "rtp/RtpTime.h"
#include "Ios6DiagnosticLog.h"

#include <string.h>

namespace tgcalls {

struct VideoToolboxH264Encoder::PendingFrame {
    int64_t captureMicros;
    int64_t submitMicros;
    int rotation;
};

namespace {

void SetInt(const VideoToolboxApi &api, OGVTCompressionSessionRef session, CFStringRef key, int32_t value) {
    if (key == 0) {
        return;
    }
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &value);
    api.sessionSetProperty(session, key, number);
    CFRelease(number);
}

uint32_t ReadLength(const uint8_t *data, int size) {
    uint32_t value = 0;
    for (int i = 0; i < size; ++i) {
        value = (value << 8) | data[i];
    }
    return value;
}

}

bool VideoToolboxH264Encoder::isAvailable() {
    return VideoToolboxApi::shared().encoderAvailable;
}

VideoToolboxH264Encoder::VideoToolboxH264Encoder(VideoEncoderCallback *callback) :
_api(VideoToolboxApi::shared()),
_callback(callback),
_session(0),
_width(0),
_height(0),
_bitrate(300000),
_fps(30),
_ratesDirty(true) {
    pthread_mutex_init(&_mutex, 0);
}

VideoToolboxH264Encoder::~VideoToolboxH264Encoder() {
    pthread_mutex_lock(&_mutex);
    destroySession();
    pthread_mutex_unlock(&_mutex);
    pthread_mutex_destroy(&_mutex);
}

void VideoToolboxH264Encoder::destroySession() {
    if (_session != 0) {
        _api.compressionSessionCompleteFrames(_session, kCMTimeInvalid);
        _api.compressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = 0;
    }
}

bool VideoToolboxH264Encoder::ensureSession(int width, int height) {
    if (_session != 0 && width == _width && height == _height) {
        return true;
    }
    destroySession();
    const int32_t format = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    CFNumberRef formatNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &format);
    CFDictionaryRef surface = CFDictionaryCreate(kCFAllocatorDefault, 0, 0, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    const void *keys[] = { kCVPixelBufferPixelFormatTypeKey, kCVPixelBufferIOSurfacePropertiesKey };
    const void *values[] = { formatNumber, surface };
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(formatNumber);
    CFRelease(surface);
    const OSStatus status = _api.compressionSessionCreate(kCFAllocatorDefault, width, height, kCMVideoCodecType_H264, 0, attributes, 0, &VideoToolboxH264Encoder::outputCallback, this, &_session);
    CFRelease(attributes);
    if (status != noErr || _session == 0) {
        syslog(LOG_ERR, "IOS6MEDIA vt.encoder.create.failed status=%d size=%dx%d", (int)status, width, height);
        _session = 0;
        return false;
    }
    _api.sessionSetProperty(_session, _api.realTime, kCFBooleanTrue);
    _api.sessionSetProperty(_session, _api.profileLevel, _api.profileBaselineAutoLevel);
    _api.sessionSetProperty(_session, _api.allowFrameReordering, kCFBooleanFalse);
    SetInt(_api, _session, _api.maxKeyFrameInterval, 600);
    SetInt(_api, _session, _api.maxKeyFrameIntervalDuration, 20);
    _api.compressionSessionPrepareToEncodeFrames(_session);
    _width = width;
    _height = height;
    _ratesDirty = true;
    syslog(LOG_NOTICE, "IOS6MEDIA vt.encoder.created size=%dx%d", width, height);
    return true;
}

void VideoToolboxH264Encoder::applyRates() {
    if (_session == 0 || !_ratesDirty) {
        return;
    }
    _ratesDirty = false;
    SetInt(_api, _session, _api.averageBitRate, _bitrate);
    SetInt(_api, _session, _api.expectedFrameRate, _fps);
    const int64_t bytesPerSecond = (int64_t)_bitrate * 3 / 16;
    CFNumberRef bytes = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &bytesPerSecond);
    const double seconds = 1.0;
    CFNumberRef duration = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &seconds);
    const void *values[] = { bytes, duration };
    CFArrayRef limits = CFArrayCreate(kCFAllocatorDefault, values, 2, &kCFTypeArrayCallBacks);
    _api.sessionSetProperty(_session, _api.dataRateLimits, limits);
    CFRelease(limits);
    CFRelease(bytes);
    CFRelease(duration);
}

void VideoToolboxH264Encoder::setRates(int bitrate, int fps) {
    pthread_mutex_lock(&_mutex);
    if (bitrate != _bitrate || fps != _fps) {
        _bitrate = bitrate;
        _fps = fps;
        _ratesDirty = true;
    }
    pthread_mutex_unlock(&_mutex);
}

void VideoToolboxH264Encoder::encode(const VideoFrame &frame, bool keyframe) {
    if (!frame.buffer || frame.buffer->type() != VideoFrameBufferType::Native) {
        return;
    }
    CVPixelBufferRef pixelBuffer = static_cast<NativeVideoBuffer *>(frame.buffer.get())->pixelBuffer();
    pthread_mutex_lock(&_mutex);
    if (!ensureSession(frame.buffer->width(), frame.buffer->height())) {
        pthread_mutex_unlock(&_mutex);
        return;
    }
    applyRates();
    CFDictionaryRef properties = 0;
    if (keyframe) {
        const void *keys[] = { _api.forceKeyFrame };
        const void *values[] = { kCFBooleanTrue };
        properties = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    }
    PendingFrame *pending = new PendingFrame();
    pending->captureMicros = frame.timestampMicros;
    pending->submitMicros = rtp::MonotonicMicros();
    pending->rotation = frame.rotation;
    OGVTEncodeInfoFlags flags = 0;
    const OSStatus status = _api.compressionSessionEncodeFrame(_session, pixelBuffer, CMTimeMake(frame.timestampMicros, 1000000), kCMTimeInvalid, properties, pending, &flags);
    if (properties != 0) {
        CFRelease(properties);
    }
    if (status != noErr) {
        delete pending;
        if (status == OGVTInvalidSessionErr) {
            destroySession();
        }
    }
    pthread_mutex_unlock(&_mutex);
}

void VideoToolboxH264Encoder::outputCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, OGVTEncodeInfoFlags, CMSampleBufferRef sampleBuffer) {
    VideoToolboxH264Encoder *encoder = static_cast<VideoToolboxH264Encoder *>(outputCallbackRefCon);
    PendingFrame *pending = static_cast<PendingFrame *>(sourceFrameRefCon);
    if (encoder != 0) {
        encoder->handleOutput(pending, status, sampleBuffer);
    }
    delete pending;
}

void VideoToolboxH264Encoder::handleOutput(PendingFrame *pending, OSStatus status, CMSampleBufferRef sampleBuffer) {
    if (pending == 0 || status != noErr || sampleBuffer == 0 || !CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    bool keyframe = true;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    if (attachments != 0 && CFArrayGetCount(attachments) > 0) {
        CFDictionaryRef attachment = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        keyframe = !CFDictionaryContainsKey(attachment, kCMSampleAttachmentKey_NotSync);
    }
    EncodedVideoFrame frame;
    frame.codec = VideoCodecType::H264;
    frame.keyframe = keyframe;
    frame.rotation = pending->rotation;
    CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
    int nalLengthSize = 4;
    if (format != 0) {
        size_t count = 0;
        const uint8_t *set = 0;
        size_t setSize = 0;
        if (_api.formatDescriptionGetH264ParameterSetAtIndex(format, 0, &set, &setSize, &count, &nalLengthSize) != noErr) {
            nalLengthSize = 4;
        }
        if (keyframe) {
            for (size_t i = 0; i < count; ++i) {
                if (_api.formatDescriptionGetH264ParameterSetAtIndex(format, i, &set, &setSize, 0, 0) == noErr && set != 0) {
                    h264::AppendAnnexB(frame.data, set, setSize);
                }
            }
        }
    }
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
    if (block == 0 || nalLengthSize < 1 || nalLengthSize > 4) {
        return;
    }
    size_t totalLength = CMBlockBufferGetDataLength(block);
    std::vector<uint8_t> contiguous;
    char *pointer = 0;
    size_t lengthAtOffset = 0;
    if (CMBlockBufferGetDataPointer(block, 0, &lengthAtOffset, &totalLength, &pointer) != kCMBlockBufferNoErr || lengthAtOffset != totalLength) {
        contiguous.resize(totalLength);
        if (totalLength == 0 || CMBlockBufferCopyDataBytes(block, 0, totalLength, &contiguous[0]) != kCMBlockBufferNoErr) {
            return;
        }
        pointer = (char *)&contiguous[0];
    }
    const uint8_t *bytes = (const uint8_t *)pointer;
    size_t offset = 0;
    frame.data.reserve(frame.data.size() + totalLength + 16);
    while (offset + (size_t)nalLengthSize <= totalLength) {
        const uint32_t nalSize = ReadLength(bytes + offset, nalLengthSize);
        offset += (size_t)nalLengthSize;
        if (nalSize == 0 || offset + nalSize > totalLength) {
            break;
        }
        h264::AppendAnnexB(frame.data, bytes + offset, nalSize);
        offset += nalSize;
    }
    if (frame.data.empty()) {
        return;
    }
    const float encodeMillis = (float)(rtp::MonotonicMicros() - pending->submitMicros) / 1000.0f;
    _callback->onEncodedFrame(frame, pending->captureMicros, encodeMillis);
}

}

#endif
