#ifndef TGCALLS_MEDIA_VIDEO_SOURCE_H
#define TGCALLS_MEDIA_VIDEO_SOURCE_H

#include "VideoFrame.h"

#include <memory>
#include <pthread.h>

namespace tgcalls {

class VideoCaptureController {
public:
    virtual ~VideoCaptureController() {}
    virtual void setCaptureFormat(int width, int height, int fps) = 0;
};

class VideoSourceHub : public VideoFrameSink {
public:
    VideoSourceHub();
    ~VideoSourceHub();

    void setConsumer(const std::shared_ptr<VideoFrameSink> &consumer);
    void setController(const std::shared_ptr<VideoCaptureController> &controller);
    void requestFormat(int width, int height, int fps);
    void onVideoFrame(const VideoFrame &frame) override;

private:
    pthread_mutex_t _mutex;
    std::shared_ptr<VideoFrameSink> _consumer;
    std::shared_ptr<VideoCaptureController> _controller;
    bool _hasFormat;
    int _width;
    int _height;
    int _fps;
};

}

#endif
