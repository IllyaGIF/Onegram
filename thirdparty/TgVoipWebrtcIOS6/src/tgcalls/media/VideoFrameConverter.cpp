#include "VideoFrameConverter.h"

#include <string.h>
#include <vector>

namespace tgcalls {

namespace {

struct RangeTables {
    uint8_t luma[256];
    uint8_t chroma[256];

    RangeTables() {
        for (int i = 0; i < 256; ++i) {
            luma[i] = (uint8_t)(16 + (i * 219 + 127) / 255);
            const int centered = (i - 128) * 224;
            chroma[i] = (uint8_t)(128 + (centered >= 0 ? (centered + 127) / 255 : (centered - 127) / 255));
        }
    }
};

const RangeTables &Tables() {
    static const RangeTables *tables = new RangeTables();
    return *tables;
}

inline uint8_t Clamp(int value) {
    return (uint8_t)(value < 0 ? 0 : (value > 255 ? 255 : value));
}

void ConvertNV12(const RawVideoImage &image, I420Buffer &target, bool fullRange) {
    const RangeTables &tables = Tables();
    const int width = image.width;
    const int height = image.height;
    for (int row = 0; row < height; ++row) {
        const uint8_t *source = image.planes[0] + (size_t)row * image.strides[0];
        uint8_t *destination = target.dataY() + (size_t)row * (size_t)target.strideY();
        if (fullRange) {
            for (int x = 0; x < width; ++x) {
                destination[x] = tables.luma[source[x]];
            }
        } else {
            memcpy(destination, source, (size_t)width);
        }
    }
    const int chromaWidth = (width + 1) / 2;
    const int chromaHeight = (height + 1) / 2;
    for (int row = 0; row < chromaHeight; ++row) {
        const uint8_t *source = image.planes[1] + (size_t)row * image.strides[1];
        uint8_t *u = target.dataU() + (size_t)row * (size_t)target.strideUV();
        uint8_t *v = target.dataV() + (size_t)row * (size_t)target.strideUV();
        if (fullRange) {
            for (int x = 0; x < chromaWidth; ++x) {
                u[x] = tables.chroma[source[2 * x]];
                v[x] = tables.chroma[source[2 * x + 1]];
            }
        } else {
            for (int x = 0; x < chromaWidth; ++x) {
                u[x] = source[2 * x];
                v[x] = source[2 * x + 1];
            }
        }
    }
}

void ConvertBGRA(const RawVideoImage &image, I420Buffer &target) {
    const int width = image.width;
    const int height = image.height;
    for (int row = 0; row < height; row += 2) {
        const uint8_t *top = image.planes[0] + (size_t)row * image.strides[0];
        const bool hasBottom = row + 1 < height;
        const uint8_t *bottom = hasBottom ? top + image.strides[0] : top;
        uint8_t *yTop = target.dataY() + (size_t)row * (size_t)target.strideY();
        uint8_t *yBottom = hasBottom ? yTop + target.strideY() : yTop;
        uint8_t *u = target.dataU() + (size_t)(row / 2) * (size_t)target.strideUV();
        uint8_t *v = target.dataV() + (size_t)(row / 2) * (size_t)target.strideUV();
        for (int x = 0; x < width; x += 2) {
            const bool hasRight = x + 1 < width;
            const uint8_t *pixels[4] = { top + 4 * x, hasRight ? top + 4 * x + 4 : top + 4 * x, bottom + 4 * x, hasRight ? bottom + 4 * x + 4 : bottom + 4 * x };
            int r = 0;
            int g = 0;
            int b = 0;
            for (int i = 0; i < 4; ++i) {
                const int pb = pixels[i][0];
                const int pg = pixels[i][1];
                const int pr = pixels[i][2];
                r += pr;
                g += pg;
                b += pb;
                const uint8_t luma = (uint8_t)(((66 * pr + 129 * pg + 25 * pb + 128) >> 8) + 16);
                if (i == 0) {
                    yTop[x] = luma;
                } else if (i == 1 && hasRight) {
                    yTop[x + 1] = luma;
                } else if (i == 2 && hasBottom) {
                    yBottom[x] = luma;
                } else if (i == 3 && hasBottom && hasRight) {
                    yBottom[x + 1] = luma;
                }
            }
            r = (r + 2) >> 2;
            g = (g + 2) >> 2;
            b = (b + 2) >> 2;
            u[x / 2] = Clamp(((-38 * r - 74 * g + 112 * b + 128) >> 8) + 128);
            v[x / 2] = Clamp(((112 * r - 94 * g - 18 * b + 128) >> 8) + 128);
        }
    }
}

void ConvertPacked422(const RawVideoImage &image, I420Buffer &target, bool uyvy) {
    const int width = image.width;
    const int height = image.height;
    const int lumaOffset = uyvy ? 1 : 0;
    const int uOffset = uyvy ? 0 : 1;
    const int vOffset = uyvy ? 2 : 3;
    for (int row = 0; row < height; row += 2) {
        const uint8_t *top = image.planes[0] + (size_t)row * image.strides[0];
        const bool hasBottom = row + 1 < height;
        const uint8_t *bottom = hasBottom ? top + image.strides[0] : top;
        uint8_t *yTop = target.dataY() + (size_t)row * (size_t)target.strideY();
        uint8_t *yBottom = yTop + target.strideY();
        uint8_t *u = target.dataU() + (size_t)(row / 2) * (size_t)target.strideUV();
        uint8_t *v = target.dataV() + (size_t)(row / 2) * (size_t)target.strideUV();
        for (int x = 0; x < width; x += 2) {
            const int offset = x * 2;
            const bool hasRight = x + 1 < width;
            yTop[x] = top[offset + lumaOffset];
            if (hasRight) {
                yTop[x + 1] = top[offset + lumaOffset + 2];
            }
            if (hasBottom) {
                yBottom[x] = bottom[offset + lumaOffset];
                if (hasRight) {
                    yBottom[x + 1] = bottom[offset + lumaOffset + 2];
                }
            }
            u[x / 2] = (uint8_t)((top[offset + uOffset] + bottom[offset + uOffset] + 1) >> 1);
            v[x / 2] = (uint8_t)((top[offset + vOffset] + bottom[offset + vOffset] + 1) >> 1);
        }
    }
}

void ScalePlane(const uint8_t *source, int sourceStride, int sourceStep, int sourceWidth, int sourceHeight, uint8_t *destination, int destinationStride, int width, int height) {
    if (sourceWidth == width && sourceHeight == height && sourceStep == 1) {
        for (int row = 0; row < height; ++row) {
            memcpy(destination + (size_t)row * (size_t)destinationStride, source + (size_t)row * (size_t)sourceStride, (size_t)width);
        }
        return;
    }
    std::vector<int> columnBegin((size_t)width);
    std::vector<int> columnCount((size_t)width);
    int maxColumns = 1;
    for (int x = 0; x < width; ++x) {
        const int begin = (int)(((int64_t)x * sourceWidth) / width);
        const int end = (int)(((int64_t)(x + 1) * sourceWidth) / width);
        columnBegin[(size_t)x] = begin * sourceStep;
        columnCount[(size_t)x] = end > begin ? end - begin : 1;
        if (columnCount[(size_t)x] > maxColumns) {
            maxColumns = columnCount[(size_t)x];
        }
    }
    std::vector<uint32_t> reciprocal((size_t)maxColumns + 1);
    std::vector<uint32_t> sums((size_t)width);
    for (int y = 0; y < height; ++y) {
        const int rowBegin = (int)(((int64_t)y * sourceHeight) / height);
        const int rowEnd = (int)(((int64_t)(y + 1) * sourceHeight) / height);
        const int rows = rowEnd > rowBegin ? rowEnd - rowBegin : 1;
        for (int columns = 1; columns <= maxColumns; ++columns) {
            const uint32_t count = (uint32_t)(rows * columns);
            reciprocal[(size_t)columns] = (65536u + count / 2) / count;
        }
        memset(&sums[0], 0, sums.size() * sizeof(uint32_t));
        for (int sourceRow = rowBegin; sourceRow < rowBegin + rows; ++sourceRow) {
            const uint8_t *line = source + (size_t)sourceRow * (size_t)sourceStride;
            for (int x = 0; x < width; ++x) {
                const uint8_t *pixel = line + columnBegin[(size_t)x];
                uint32_t sum = 0;
                for (int column = 0; column < columnCount[(size_t)x]; ++column) {
                    sum += pixel[column * sourceStep];
                }
                sums[(size_t)x] += sum;
            }
        }
        uint8_t *output = destination + (size_t)y * (size_t)destinationStride;
        for (int x = 0; x < width; ++x) {
            output[x] = (uint8_t)((sums[(size_t)x] * reciprocal[(size_t)columnCount[(size_t)x]] + 32768u) >> 16);
        }
    }
}

std::shared_ptr<I420Buffer> ScaleNV12(const RawVideoImage &image, int width, int height) {
    std::shared_ptr<I420Buffer> scaled = I420Buffer::create(width, height);
    if (!scaled) {
        return scaled;
    }
    const int sourceChromaWidth = (image.width + 1) / 2;
    const int sourceChromaHeight = (image.height + 1) / 2;
    const int chromaWidth = (width + 1) / 2;
    const int chromaHeight = (height + 1) / 2;
    ScalePlane(image.planes[0], (int)image.strides[0], 1, image.width, image.height, scaled->dataY(), scaled->strideY(), width, height);
    ScalePlane(image.planes[1], (int)image.strides[1], 2, sourceChromaWidth, sourceChromaHeight, scaled->dataU(), scaled->strideUV(), chromaWidth, chromaHeight);
    ScalePlane(image.planes[1] + 1, (int)image.strides[1], 2, sourceChromaWidth, sourceChromaHeight, scaled->dataV(), scaled->strideUV(), chromaWidth, chromaHeight);
    if (image.format == RawVideoFormat::NV12FullRange) {
        const RangeTables &tables = Tables();
        for (int row = 0; row < height; ++row) {
            uint8_t *line = scaled->dataY() + (size_t)row * (size_t)scaled->strideY();
            for (int x = 0; x < width; ++x) {
                line[x] = tables.luma[line[x]];
            }
        }
        for (int row = 0; row < chromaHeight; ++row) {
            uint8_t *u = scaled->dataU() + (size_t)row * (size_t)scaled->strideUV();
            uint8_t *v = scaled->dataV() + (size_t)row * (size_t)scaled->strideUV();
            for (int x = 0; x < chromaWidth; ++x) {
                u[x] = tables.chroma[u[x]];
                v[x] = tables.chroma[v[x]];
            }
        }
    }
    return scaled;
}

}

void FitVideoSize(int width, int height, int maxWidth, int maxHeight, int *outWidth, int *outHeight) {
    int resultWidth = width;
    int resultHeight = height;
    if (maxWidth > 0 && maxHeight > 0 && (width > maxWidth || height > maxHeight)) {
        if ((int64_t)width * maxHeight > (int64_t)height * maxWidth) {
            resultWidth = maxWidth;
            resultHeight = (int)(((int64_t)height * maxWidth + width / 2) / width);
        } else {
            resultHeight = maxHeight;
            resultWidth = (int)(((int64_t)width * maxHeight + height / 2) / height);
        }
    }
    resultWidth &= ~1;
    resultHeight &= ~1;
    *outWidth = resultWidth < 2 ? 2 : resultWidth;
    *outHeight = resultHeight < 2 ? 2 : resultHeight;
}

VideoCropPlan PlanVideoCrop(int width, int height, int boxWidth, int boxHeight) {
    VideoCropPlan plan;
    plan.x = 0;
    plan.y = 0;
    plan.width = width & ~1;
    plan.height = height & ~1;
    if (boxWidth > 0 && boxHeight > 0 && plan.width > 0 && plan.height > 0) {
        if ((int64_t)plan.width * boxHeight > (int64_t)plan.height * boxWidth) {
            const int cropped = (int)(((int64_t)plan.height * boxWidth) / boxHeight) & ~1;
            plan.x = ((plan.width - cropped) / 2) & ~1;
            plan.width = cropped;
        } else if ((int64_t)plan.width * boxHeight < (int64_t)plan.height * boxWidth) {
            const int cropped = (int)(((int64_t)plan.width * boxHeight) / boxWidth) & ~1;
            plan.y = ((plan.height - cropped) / 2) & ~1;
            plan.height = cropped;
        }
    }
    if (boxWidth > 0 && boxHeight > 0 && boxWidth <= plan.width && boxHeight <= plan.height) {
        plan.outputWidth = boxWidth & ~1;
        plan.outputHeight = boxHeight & ~1;
    } else {
        plan.outputWidth = plan.width;
        plan.outputHeight = plan.height;
    }
    if (plan.outputWidth < 2) {
        plan.outputWidth = 2;
    }
    if (plan.outputHeight < 2) {
        plan.outputHeight = 2;
    }
    return plan;
}

RawVideoImage CropRawVideoImage(const RawVideoImage &image, int x, int y, int width, int height) {
    RawVideoImage result = image;
    x &= ~1;
    y &= ~1;
    result.width = width;
    result.height = height;
    switch (image.format) {
        case RawVideoFormat::NV12VideoRange:
        case RawVideoFormat::NV12FullRange:
            result.planes[0] = image.planes[0] + (size_t)y * image.strides[0] + (size_t)x;
            result.planes[1] = image.planes[1] != 0 ? image.planes[1] + (size_t)(y / 2) * image.strides[1] + (size_t)x : 0;
            break;
        case RawVideoFormat::BGRA:
            result.planes[0] = image.planes[0] + (size_t)y * image.strides[0] + (size_t)x * 4;
            break;
        case RawVideoFormat::UYVY:
        case RawVideoFormat::YUY2:
            result.planes[0] = image.planes[0] + (size_t)y * image.strides[0] + (size_t)x * 2;
            break;
    }
    return result;
}

std::shared_ptr<I420Buffer> ConvertToI420(const RawVideoImage &image, int width, int height) {
    if (image.width <= 0 || image.height <= 0 || image.planes[0] == 0 || width <= 0 || height <= 0 || width > image.width || height > image.height) {
        return std::shared_ptr<I420Buffer>();
    }
    const bool planar = image.format == RawVideoFormat::NV12VideoRange || image.format == RawVideoFormat::NV12FullRange;
    if (planar && image.planes[1] == 0) {
        return std::shared_ptr<I420Buffer>();
    }
    if (planar && (width != image.width || height != image.height)) {
        return ScaleNV12(image, width, height);
    }
    std::shared_ptr<I420Buffer> full = I420Buffer::create(image.width, image.height);
    if (!full) {
        return full;
    }
    switch (image.format) {
        case RawVideoFormat::NV12VideoRange:
            ConvertNV12(image, *full, false);
            break;
        case RawVideoFormat::NV12FullRange:
            ConvertNV12(image, *full, true);
            break;
        case RawVideoFormat::BGRA:
            ConvertBGRA(image, *full);
            break;
        case RawVideoFormat::UYVY:
            ConvertPacked422(image, *full, true);
            break;
        case RawVideoFormat::YUY2:
            ConvertPacked422(image, *full, false);
            break;
    }
    if (width == image.width && height == image.height) {
        return full;
    }
    VideoCropPlan plan;
    plan.x = 0;
    plan.y = 0;
    plan.width = image.width;
    plan.height = image.height;
    plan.outputWidth = width;
    plan.outputHeight = height;
    return ScaleI420(*full, plan);
}

std::shared_ptr<I420Buffer> ScaleI420(const I420Buffer &source, const VideoCropPlan &plan) {
    const int x = plan.x & ~1;
    const int y = plan.y & ~1;
    if (plan.outputWidth <= 0 || plan.outputHeight <= 0 || plan.width <= 0 || plan.height <= 0 || x + plan.width > source.width() || y + plan.height > source.height() || plan.outputWidth > plan.width || plan.outputHeight > plan.height) {
        return std::shared_ptr<I420Buffer>();
    }
    std::shared_ptr<I420Buffer> scaled = I420Buffer::create(plan.outputWidth, plan.outputHeight);
    if (!scaled) {
        return scaled;
    }
    ScalePlane(source.dataY() + (size_t)y * (size_t)source.strideY() + (size_t)x, source.strideY(), 1, plan.width, plan.height, scaled->dataY(), scaled->strideY(), plan.outputWidth, plan.outputHeight);
    const size_t chromaOffset = (size_t)(y / 2) * (size_t)source.strideUV() + (size_t)(x / 2);
    const int sourceChromaWidth = (plan.width + 1) / 2;
    const int sourceChromaHeight = (plan.height + 1) / 2;
    const int chromaWidth = (plan.outputWidth + 1) / 2;
    const int chromaHeight = (plan.outputHeight + 1) / 2;
    ScalePlane(source.dataU() + chromaOffset, source.strideUV(), 1, sourceChromaWidth, sourceChromaHeight, scaled->dataU(), scaled->strideUV(), chromaWidth, chromaHeight);
    ScalePlane(source.dataV() + chromaOffset, source.strideUV(), 1, sourceChromaWidth, sourceChromaHeight, scaled->dataV(), scaled->strideUV(), chromaWidth, chromaHeight);
    return scaled;
}

}
