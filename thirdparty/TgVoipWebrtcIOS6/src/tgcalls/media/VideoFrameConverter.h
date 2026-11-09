#ifndef TGCALLS_MEDIA_VIDEO_FRAME_CONVERTER_H
#define TGCALLS_MEDIA_VIDEO_FRAME_CONVERTER_H

#include "VideoFrame.h"

#include <memory>
#include <stddef.h>
#include <stdint.h>

namespace tgcalls {

enum class RawVideoFormat {
    NV12VideoRange,
    NV12FullRange,
    BGRA,
    UYVY,
    YUY2
};

struct RawVideoImage {
    RawVideoFormat format;
    int width;
    int height;
    const uint8_t *planes[2];
    size_t strides[2];
};

struct VideoCropPlan {
    int x;
    int y;
    int width;
    int height;
    int outputWidth;
    int outputHeight;
};

void FitVideoSize(int width, int height, int maxWidth, int maxHeight, int *outWidth, int *outHeight);
VideoCropPlan PlanVideoCrop(int width, int height, int boxWidth, int boxHeight);
RawVideoImage CropRawVideoImage(const RawVideoImage &image, int x, int y, int width, int height);
std::shared_ptr<I420Buffer> ConvertToI420(const RawVideoImage &image, int width, int height);
std::shared_ptr<I420Buffer> ScaleI420(const I420Buffer &source, const VideoCropPlan &plan);

}

#endif
