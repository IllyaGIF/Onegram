#ifndef TGCALLS_MEDIA_VIDEO_TOOLBOX_API_H
#define TGCALLS_MEDIA_VIDEO_TOOLBOX_API_H

#if !defined(ONEGRAM_ARMV6)

#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>

namespace tgcalls {

typedef struct OpaqueOGVTDecompressionSession *OGVTDecompressionSessionRef;
typedef struct OpaqueOGVTCompressionSession *OGVTCompressionSessionRef;
typedef uint32_t OGVTDecodeInfoFlags;
typedef uint32_t OGVTDecodeFrameFlags;
typedef uint32_t OGVTEncodeInfoFlags;

typedef void (*OGVTDecompressionOutputCallback)(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, OGVTDecodeInfoFlags infoFlags, CVImageBufferRef imageBuffer, CMTime presentationTimeStamp, CMTime presentationDuration);
typedef void (*OGVTCompressionOutputCallback)(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, OGVTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer);

struct OGVTDecompressionOutputCallbackRecord {
    OGVTDecompressionOutputCallback decompressionOutputCallback;
    void *decompressionOutputRefCon;
};

enum {
    OGVTInvalidSessionErr = -12903,
    OGVTVideoDecoderMalfunctionErr = -12911,
    OGVTEncodeInfoFrameDropped = 1 << 1
};

struct VideoToolboxApi {
    OSStatus (*decompressionSessionCreate)(CFAllocatorRef, CMVideoFormatDescriptionRef, CFDictionaryRef, CFDictionaryRef, const OGVTDecompressionOutputCallbackRecord *, OGVTDecompressionSessionRef *);
    OSStatus (*decompressionSessionDecodeFrame)(OGVTDecompressionSessionRef, CMSampleBufferRef, OGVTDecodeFrameFlags, void *, OGVTDecodeInfoFlags *);
    void (*decompressionSessionInvalidate)(OGVTDecompressionSessionRef);
    OSStatus (*decompressionSessionWaitForAsynchronousFrames)(OGVTDecompressionSessionRef);
    OSStatus (*compressionSessionCreate)(CFAllocatorRef, int32_t, int32_t, CMVideoCodecType, CFDictionaryRef, CFDictionaryRef, CFAllocatorRef, OGVTCompressionOutputCallback, void *, OGVTCompressionSessionRef *);
    OSStatus (*compressionSessionEncodeFrame)(OGVTCompressionSessionRef, CVImageBufferRef, CMTime, CMTime, CFDictionaryRef, void *, OGVTEncodeInfoFlags *);
    void (*compressionSessionInvalidate)(OGVTCompressionSessionRef);
    OSStatus (*compressionSessionPrepareToEncodeFrames)(OGVTCompressionSessionRef);
    OSStatus (*compressionSessionCompleteFrames)(OGVTCompressionSessionRef, CMTime);
    OSStatus (*sessionSetProperty)(CFTypeRef, CFStringRef, CFTypeRef);
    OSStatus (*formatDescriptionCreateFromH264ParameterSets)(CFAllocatorRef, size_t, const uint8_t * const *, const size_t *, int, CMFormatDescriptionRef *);
    OSStatus (*formatDescriptionGetH264ParameterSetAtIndex)(CMFormatDescriptionRef, size_t, const uint8_t **, size_t *, size_t *, int *);

    CFStringRef decoderRealTime;
    CFStringRef realTime;
    CFStringRef profileLevel;
    CFStringRef allowFrameReordering;
    CFStringRef averageBitRate;
    CFStringRef dataRateLimits;
    CFStringRef maxKeyFrameInterval;
    CFStringRef maxKeyFrameIntervalDuration;
    CFStringRef expectedFrameRate;
    CFStringRef profileBaselineAutoLevel;
    CFStringRef profileMainAutoLevel;
    CFStringRef forceKeyFrame;

    bool decoderAvailable;
    bool encoderAvailable;

    static const VideoToolboxApi &shared();
};

}

#endif

#endif
