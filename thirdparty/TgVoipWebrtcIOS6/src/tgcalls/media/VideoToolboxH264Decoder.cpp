#include "media/VideoToolboxH264Decoder.h"

#if !defined(ONEGRAM_ARMV6)

#include "media/H264.h"
#include "Ios6DiagnosticLog.h"

#include <stdlib.h>
#include <string.h>

namespace tgcalls {

namespace {

void WriteLength(uint8_t *target, size_t length) {
    target[0] = (uint8_t)(length >> 24);
    target[1] = (uint8_t)(length >> 16);
    target[2] = (uint8_t)(length >> 8);
    target[3] = (uint8_t)length;
}

CFDictionaryRef CreatePixelBufferAttributes() {
    const int32_t format = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    CFNumberRef formatNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &format);
    CFDictionaryRef surface = CFDictionaryCreate(kCFAllocatorDefault, 0, 0, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    const void *keys[] = { kCVPixelBufferPixelFormatTypeKey, kCVPixelBufferIOSurfacePropertiesKey, kCVPixelBufferOpenGLESCompatibilityKey };
    const void *values[] = { formatNumber, surface, kCFBooleanTrue };
    CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(formatNumber);
    CFRelease(surface);
    return attributes;
}

}

bool VideoToolboxH264Decoder::isAvailable() {
    return VideoToolboxApi::shared().decoderAvailable;
}

VideoToolboxH264Decoder::VideoToolboxH264Decoder() :
_api(VideoToolboxApi::shared()),
_format(0),
_session(0),
_currentSink(0),
_currentRotation(0),
_currentTimestamp(0),
_produced(false) {
}

VideoToolboxH264Decoder::~VideoToolboxH264Decoder() {
    destroySession();
    if (_format != 0) {
        CFRelease(_format);
        _format = 0;
    }
}

void VideoToolboxH264Decoder::destroySession() {
    if (_session != 0) {
        _api.decompressionSessionWaitForAsynchronousFrames(_session);
        _api.decompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = 0;
    }
}

bool VideoToolboxH264Decoder::updateFormat(const std::vector<uint8_t> &sps, const std::vector<uint8_t> &pps) {
    if (_format != 0 && sps == _sps && pps == _pps) {
        return true;
    }
    const uint8_t *sets[2] = { &sps[0], &pps[0] };
    const size_t sizes[2] = { sps.size(), pps.size() };
    CMFormatDescriptionRef format = 0;
    if (_api.formatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, sets, sizes, 4, &format) != noErr || format == 0) {
        return false;
    }
    destroySession();
    if (_format != 0) {
        CFRelease(_format);
    }
    _format = (CMVideoFormatDescriptionRef)format;
    _sps = sps;
    _pps = pps;
    return true;
}

bool VideoToolboxH264Decoder::createSession() {
    if (_session != 0) {
        return true;
    }
    if (_format == 0) {
        return false;
    }
    CFDictionaryRef attributes = CreatePixelBufferAttributes();
    OGVTDecompressionOutputCallbackRecord callback;
    callback.decompressionOutputCallback = &VideoToolboxH264Decoder::outputCallback;
    callback.decompressionOutputRefCon = this;
    const OSStatus status = _api.decompressionSessionCreate(kCFAllocatorDefault, _format, 0, attributes, &callback, &_session);
    CFRelease(attributes);
    if (status != noErr) {
        syslog(LOG_ERR, "IOS6MEDIA vt.decoder.create.failed status=%d", (int)status);
        _session = 0;
        return false;
    }
    if (_api.decoderRealTime != 0) {
        _api.sessionSetProperty(_session, _api.decoderRealTime, kCFBooleanTrue);
    }
    return true;
}

void VideoToolboxH264Decoder::outputCallback(void *decompressionOutputRefCon, void *, OSStatus status, OGVTDecodeInfoFlags, CVImageBufferRef imageBuffer, CMTime, CMTime) {
    VideoToolboxH264Decoder *decoder = static_cast<VideoToolboxH264Decoder *>(decompressionOutputRefCon);
    if (decoder == 0 || status != noErr || imageBuffer == 0 || decoder->_currentSink == 0) {
        return;
    }
    VideoFrame frame;
    frame.buffer.reset(new NativeVideoBuffer(imageBuffer));
    frame.rotation = decoder->_currentRotation;
    frame.timestampMicros = decoder->_currentTimestamp;
    decoder->_produced = true;
    decoder->_currentSink->onVideoFrame(frame);
}

VideoDecoder::Result VideoToolboxH264Decoder::decode(const EncodedVideoFrame &frame, VideoFrameSink &sink) {
    std::vector<h264::NalUnit> units;
    h264::SplitAnnexB(frame.data.empty() ? 0 : &frame.data[0], frame.data.size(), units);
    std::vector<uint8_t> sps;
    std::vector<uint8_t> pps;
    size_t sampleSize = 0;
    for (size_t i = 0; i < units.size(); ++i) {
        const uint8_t type = h264::NalTypeOf(units[i].data[0]);
        if (type == h264::NalSps) {
            sps.assign(units[i].data, units[i].data + units[i].size);
        } else if (type == h264::NalPps) {
            pps.assign(units[i].data, units[i].data + units[i].size);
        } else if (type != h264::NalAud) {
            sampleSize += 4 + units[i].size;
        }
    }
    if (!sps.empty() && !pps.empty() && !updateFormat(sps, pps)) {
        return Failed;
    }
    if (sampleSize == 0) {
        return Skipped;
    }
    if (_format == 0 || !createSession()) {
        return Failed;
    }
    uint8_t *memory = static_cast<uint8_t *>(malloc(sampleSize));
    if (memory == 0) {
        return Failed;
    }
    size_t offset = 0;
    for (size_t i = 0; i < units.size(); ++i) {
        const uint8_t type = h264::NalTypeOf(units[i].data[0]);
        if (type == h264::NalSps || type == h264::NalPps || type == h264::NalAud) {
            continue;
        }
        WriteLength(memory + offset, units[i].size);
        memcpy(memory + offset + 4, units[i].data, units[i].size);
        offset += 4 + units[i].size;
    }
    CMBlockBufferRef block = 0;
    if (CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, memory, sampleSize, kCFAllocatorMalloc, 0, 0, sampleSize, 0, &block) != kCMBlockBufferNoErr) {
        free(memory);
        return Failed;
    }
    CMSampleTimingInfo timing;
    timing.duration = kCMTimeInvalid;
    timing.presentationTimeStamp = CMTimeMake((int64_t)frame.rtpTimestamp, 90000);
    timing.decodeTimeStamp = kCMTimeInvalid;
    CMSampleBufferRef sample = 0;
    const OSStatus sampleStatus = CMSampleBufferCreate(kCFAllocatorDefault, block, true, 0, 0, _format, 1, 1, &timing, 1, &sampleSize, &sample);
    CFRelease(block);
    if (sampleStatus != noErr || sample == 0) {
        return Failed;
    }
    _currentSink = &sink;
    _currentRotation = frame.rotation < 0 ? 0 : frame.rotation;
    _currentTimestamp = frame.receiveMicros;
    _produced = false;
    OGVTDecodeInfoFlags flags = 0;
    OSStatus status = _api.decompressionSessionDecodeFrame(_session, sample, 0, 0, &flags);
    if (status == OGVTInvalidSessionErr || status == OGVTVideoDecoderMalfunctionErr) {
        destroySession();
        if (createSession()) {
            status = _api.decompressionSessionDecodeFrame(_session, sample, 0, 0, &flags);
        }
    }
    if (status == noErr && _session != 0) {
        _api.decompressionSessionWaitForAsynchronousFrames(_session);
    }
    CFRelease(sample);
    _currentSink = 0;
    if (status != noErr) {
        syslog(LOG_ERR, "IOS6MEDIA vt.decoder.decode.failed status=%d key=%d", (int)status, frame.keyframe ? 1 : 0);
        if (status == OGVTInvalidSessionErr) {
            destroySession();
        }
        return Failed;
    }
    return _produced ? Decoded : Skipped;
}

}

#endif
