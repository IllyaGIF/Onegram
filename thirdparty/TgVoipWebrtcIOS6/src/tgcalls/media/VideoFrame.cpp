#include "media/VideoFrame.h"

#include <stdlib.h>
#include <string.h>
#include <vector>

namespace tgcalls {

namespace {

const size_t kAlignment = 16;
const size_t kMaxPooledBuffers = 12;

class PlanePool {
public:
    static PlanePool &shared() {
        static PlanePool *pool = new PlanePool();
        return *pool;
    }

    uint8_t *acquire(size_t size, size_t *capacity) {
        pthread_mutex_lock(&_mutex);
        for (size_t i = 0; i < _free.size(); ++i) {
            if (_free[i].capacity >= size && _free[i].capacity <= size + size / 4) {
                Entry entry = _free[i];
                _free.erase(_free.begin() + i);
                pthread_mutex_unlock(&_mutex);
                *capacity = entry.capacity;
                return entry.data;
            }
        }
        pthread_mutex_unlock(&_mutex);
        void *memory = 0;
        if (posix_memalign(&memory, kAlignment, size) != 0) {
            return 0;
        }
        *capacity = size;
        return static_cast<uint8_t *>(memory);
    }

    void release(uint8_t *data, size_t capacity) {
        pthread_mutex_lock(&_mutex);
        if (_free.size() < kMaxPooledBuffers) {
            Entry entry;
            entry.data = data;
            entry.capacity = capacity;
            _free.push_back(entry);
            data = 0;
        }
        pthread_mutex_unlock(&_mutex);
        free(data);
    }

private:
    struct Entry {
        uint8_t *data;
        size_t capacity;
    };

    PlanePool() {
        pthread_mutex_init(&_mutex, 0);
    }

    pthread_mutex_t _mutex;
    std::vector<Entry> _free;
};

int AlignedStride(int width) {
    return (width + (int)kAlignment - 1) & ~((int)kAlignment - 1);
}

}

std::shared_ptr<I420Buffer> I420Buffer::create(int width, int height) {
    if (width <= 0 || height <= 0 || width > 4096 || height > 4096) {
        return std::shared_ptr<I420Buffer>();
    }
    const int strideY = AlignedStride(width);
    const int strideUV = AlignedStride((width + 1) / 2);
    const size_t sizeY = (size_t)strideY * (size_t)height;
    const size_t sizeUV = (size_t)strideUV * (size_t)((height + 1) / 2);
    size_t capacity = 0;
    uint8_t *data = PlanePool::shared().acquire(sizeY + 2 * sizeUV, &capacity);
    if (data == 0) {
        return std::shared_ptr<I420Buffer>();
    }
    return std::shared_ptr<I420Buffer>(new I420Buffer(width, height, data, capacity));
}

I420Buffer::I420Buffer(int width, int height, uint8_t *data, size_t capacity) :
_width(width),
_height(height),
_strideY(AlignedStride(width)),
_strideUV(AlignedStride((width + 1) / 2)),
_data(data),
_capacity(capacity) {
    _offsetU = (size_t)_strideY * (size_t)height;
    _offsetV = _offsetU + (size_t)_strideUV * (size_t)((height + 1) / 2);
}

I420Buffer::~I420Buffer() {
    PlanePool::shared().release(_data, _capacity);
}

#if TGCALLS_VIDEO_NATIVE_BUFFERS
NativeVideoBuffer::NativeVideoBuffer(CVPixelBufferRef pixelBuffer) :
_pixelBuffer(pixelBuffer),
_width(0),
_height(0) {
    if (_pixelBuffer != 0) {
        CVPixelBufferRetain(_pixelBuffer);
        _width = (int)CVPixelBufferGetWidth(_pixelBuffer);
        _height = (int)CVPixelBufferGetHeight(_pixelBuffer);
    }
}

NativeVideoBuffer::~NativeVideoBuffer() {
    if (_pixelBuffer != 0) {
        CVPixelBufferRelease(_pixelBuffer);
    }
}
#endif

VideoSinkHub::VideoSinkHub() {
    pthread_mutex_init(&_mutex, 0);
}

VideoSinkHub::~VideoSinkHub() {
    pthread_mutex_destroy(&_mutex);
}

void VideoSinkHub::setSink(const std::shared_ptr<VideoFrameSink> &sink) {
    pthread_mutex_lock(&_mutex);
    _sink = sink;
    pthread_mutex_unlock(&_mutex);
}

void VideoSinkHub::onVideoFrame(const VideoFrame &frame) {
    std::shared_ptr<VideoFrameSink> sink;
    pthread_mutex_lock(&_mutex);
    sink = _sink;
    pthread_mutex_unlock(&_mutex);
    if (sink) {
        sink->onVideoFrame(frame);
    }
}

}
