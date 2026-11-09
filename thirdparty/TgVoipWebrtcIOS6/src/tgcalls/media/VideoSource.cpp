#include "media/VideoSource.h"

namespace tgcalls {

VideoSourceHub::VideoSourceHub() :
_hasFormat(false),
_width(0),
_height(0),
_fps(0) {
    pthread_mutex_init(&_mutex, 0);
}

VideoSourceHub::~VideoSourceHub() {
    pthread_mutex_destroy(&_mutex);
}

void VideoSourceHub::setConsumer(const std::shared_ptr<VideoFrameSink> &consumer) {
    pthread_mutex_lock(&_mutex);
    _consumer = consumer;
    pthread_mutex_unlock(&_mutex);
}

void VideoSourceHub::setController(const std::shared_ptr<VideoCaptureController> &controller) {
    bool apply = false;
    int width = 0;
    int height = 0;
    int fps = 0;
    pthread_mutex_lock(&_mutex);
    _controller = controller;
    apply = _hasFormat && controller;
    width = _width;
    height = _height;
    fps = _fps;
    pthread_mutex_unlock(&_mutex);
    if (apply) {
        controller->setCaptureFormat(width, height, fps);
    }
}

void VideoSourceHub::requestFormat(int width, int height, int fps) {
    std::shared_ptr<VideoCaptureController> controller;
    pthread_mutex_lock(&_mutex);
    const bool changed = !_hasFormat || _width != width || _height != height || _fps != fps;
    _hasFormat = true;
    _width = width;
    _height = height;
    _fps = fps;
    controller = _controller;
    pthread_mutex_unlock(&_mutex);
    if (changed && controller) {
        controller->setCaptureFormat(width, height, fps);
    }
}

void VideoSourceHub::onVideoFrame(const VideoFrame &frame) {
    std::shared_ptr<VideoFrameSink> consumer;
    pthread_mutex_lock(&_mutex);
    consumer = _consumer;
    pthread_mutex_unlock(&_mutex);
    if (consumer) {
        consumer->onVideoFrame(frame);
    }
}

}
