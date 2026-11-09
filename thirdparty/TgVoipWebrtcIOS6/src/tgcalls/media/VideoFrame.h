#ifndef TGCALLS_MEDIA_VIDEO_FRAME_H
#define TGCALLS_MEDIA_VIDEO_FRAME_H

#include <memory>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>

#if !defined(ONEGRAM_ARMV6)
#define TGCALLS_VIDEO_NATIVE_BUFFERS 1
#include <CoreVideo/CoreVideo.h>
#endif

namespace tgcalls {

enum class VideoFrameBufferType {
    Native,
    I420
};

class VideoFrameBuffer {
public:
    virtual ~VideoFrameBuffer() {}
    virtual VideoFrameBufferType type() const = 0;
    virtual int width() const = 0;
    virtual int height() const = 0;
};

class I420Buffer : public VideoFrameBuffer {
public:
    static std::shared_ptr<I420Buffer> create(int width, int height);

    ~I420Buffer();

    VideoFrameBufferType type() const override { return VideoFrameBufferType::I420; }
    int width() const override { return _width; }
    int height() const override { return _height; }

    uint8_t *dataY() { return _data; }
    uint8_t *dataU() { return _data + _offsetU; }
    uint8_t *dataV() { return _data + _offsetV; }
    const uint8_t *dataY() const { return _data; }
    const uint8_t *dataU() const { return _data + _offsetU; }
    const uint8_t *dataV() const { return _data + _offsetV; }
    int strideY() const { return _strideY; }
    int strideUV() const { return _strideUV; }

private:
    I420Buffer(int width, int height, uint8_t *data, size_t capacity);
    I420Buffer(const I420Buffer &) = delete;
    I420Buffer &operator=(const I420Buffer &) = delete;

    int _width;
    int _height;
    int _strideY;
    int _strideUV;
    size_t _offsetU;
    size_t _offsetV;
    uint8_t *_data;
    size_t _capacity;
};

#if TGCALLS_VIDEO_NATIVE_BUFFERS
class NativeVideoBuffer : public VideoFrameBuffer {
public:
    explicit NativeVideoBuffer(CVPixelBufferRef pixelBuffer);
    ~NativeVideoBuffer();

    VideoFrameBufferType type() const override { return VideoFrameBufferType::Native; }
    int width() const override { return _width; }
    int height() const override { return _height; }
    CVPixelBufferRef pixelBuffer() const { return _pixelBuffer; }

private:
    NativeVideoBuffer(const NativeVideoBuffer &) = delete;
    NativeVideoBuffer &operator=(const NativeVideoBuffer &) = delete;

    CVPixelBufferRef _pixelBuffer;
    int _width;
    int _height;
};
#endif

struct VideoFrame {
    std::shared_ptr<VideoFrameBuffer> buffer;
    int rotation = 0;
    bool mirrored = false;
    int64_t timestampMicros = 0;
};

class VideoFrameSink {
public:
    virtual ~VideoFrameSink() {}
    virtual void onVideoFrame(const VideoFrame &frame) = 0;
};

class VideoSinkHub : public VideoFrameSink {
public:
    VideoSinkHub();
    ~VideoSinkHub();

    void setSink(const std::shared_ptr<VideoFrameSink> &sink);
    void onVideoFrame(const VideoFrame &frame) override;

private:
    pthread_mutex_t _mutex;
    std::shared_ptr<VideoFrameSink> _sink;
};

}

#endif
