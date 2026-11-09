#include "media/VideoToolboxApi.h"

#if !defined(ONEGRAM_ARMV6)

#include <dlfcn.h>
#include <pthread.h>
#include <string.h>

namespace tgcalls {

namespace {

pthread_once_t loadOnce = PTHREAD_ONCE_INIT;
VideoToolboxApi loadedApi;

template <typename T>
bool LoadFunction(void *handle, const char *name, T *target) {
    *target = reinterpret_cast<T>(dlsym(handle, name));
    return *target != 0;
}

bool LoadConstant(void *handle, const char *name, CFStringRef *target) {
    CFStringRef *symbol = reinterpret_cast<CFStringRef *>(dlsym(handle, name));
    *target = symbol != 0 ? *symbol : 0;
    return *target != 0;
}

void LoadApi() {
    memset(&loadedApi, 0, sizeof(loadedApi));
    if (kCFCoreFoundationVersionNumber < 1140.10) {
        return;
    }
    void *toolbox = dlopen("/System/Library/Frameworks/VideoToolbox.framework/VideoToolbox", RTLD_LAZY);
    void *media = dlopen("/System/Library/Frameworks/CoreMedia.framework/CoreMedia", RTLD_LAZY);
    if (toolbox == 0 || media == 0) {
        return;
    }
    bool common = true;
    common &= LoadFunction(toolbox, "VTSessionSetProperty", &loadedApi.sessionSetProperty);
    common &= LoadFunction(media, "CMVideoFormatDescriptionCreateFromH264ParameterSets", &loadedApi.formatDescriptionCreateFromH264ParameterSets);
    common &= LoadFunction(media, "CMVideoFormatDescriptionGetH264ParameterSetAtIndex", &loadedApi.formatDescriptionGetH264ParameterSetAtIndex);
    LoadConstant(toolbox, "kVTDecompressionPropertyKey_RealTime", &loadedApi.decoderRealTime);

    bool decoder = common;
    decoder &= LoadFunction(toolbox, "VTDecompressionSessionCreate", &loadedApi.decompressionSessionCreate);
    decoder &= LoadFunction(toolbox, "VTDecompressionSessionDecodeFrame", &loadedApi.decompressionSessionDecodeFrame);
    decoder &= LoadFunction(toolbox, "VTDecompressionSessionInvalidate", &loadedApi.decompressionSessionInvalidate);
    decoder &= LoadFunction(toolbox, "VTDecompressionSessionWaitForAsynchronousFrames", &loadedApi.decompressionSessionWaitForAsynchronousFrames);
    loadedApi.decoderAvailable = decoder;

    bool encoder = common;
    encoder &= LoadFunction(toolbox, "VTCompressionSessionCreate", &loadedApi.compressionSessionCreate);
    encoder &= LoadFunction(toolbox, "VTCompressionSessionEncodeFrame", &loadedApi.compressionSessionEncodeFrame);
    encoder &= LoadFunction(toolbox, "VTCompressionSessionInvalidate", &loadedApi.compressionSessionInvalidate);
    encoder &= LoadFunction(toolbox, "VTCompressionSessionPrepareToEncodeFrames", &loadedApi.compressionSessionPrepareToEncodeFrames);
    encoder &= LoadFunction(toolbox, "VTCompressionSessionCompleteFrames", &loadedApi.compressionSessionCompleteFrames);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_RealTime", &loadedApi.realTime);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_ProfileLevel", &loadedApi.profileLevel);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_AllowFrameReordering", &loadedApi.allowFrameReordering);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_AverageBitRate", &loadedApi.averageBitRate);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_DataRateLimits", &loadedApi.dataRateLimits);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_MaxKeyFrameInterval", &loadedApi.maxKeyFrameInterval);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration", &loadedApi.maxKeyFrameIntervalDuration);
    encoder &= LoadConstant(toolbox, "kVTCompressionPropertyKey_ExpectedFrameRate", &loadedApi.expectedFrameRate);
    encoder &= LoadConstant(toolbox, "kVTProfileLevel_H264_Baseline_AutoLevel", &loadedApi.profileBaselineAutoLevel);
    LoadConstant(toolbox, "kVTProfileLevel_H264_Main_AutoLevel", &loadedApi.profileMainAutoLevel);
    encoder &= LoadConstant(toolbox, "kVTEncodeFrameOptionKey_ForceKeyFrame", &loadedApi.forceKeyFrame);
    loadedApi.encoderAvailable = encoder;
}

}

const VideoToolboxApi &VideoToolboxApi::shared() {
    pthread_once(&loadOnce, &LoadApi);
    return loadedApi;
}

}

#endif
