#import "TGCallVideoNative.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/media/VideoFrame.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/media/VideoFrameConverter.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/media/VideoProfile.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/media/VideoSource.h"
#include "../thirdparty/TgVoipWebrtcIOS6/src/tgcalls/rtp/RtpTime.h"

#if !defined(ONEGRAM_ARMV6)
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#endif

#include <dlfcn.h>
#include <pthread.h>
#include <string.h>
#include <syslog.h>

@interface TGCallVideoCapturer ()

- (void)applyCaptureWidth:(int)width height:(int)height fps:(int)fps;

@end

namespace {

class TGCallVideoCaptureControllerImpl : public tgcalls::VideoCaptureController {
public:
    explicit TGCallVideoCaptureControllerImpl(TGCallVideoCapturer *capturer) : _capturer(capturer) {
        pthread_mutex_init(&_mutex, NULL);
    }

    ~TGCallVideoCaptureControllerImpl() {
        pthread_mutex_destroy(&_mutex);
    }

    void detach() {
        pthread_mutex_lock(&_mutex);
        _capturer = nil;
        pthread_mutex_unlock(&_mutex);
    }

    void setCaptureFormat(int width, int height, int fps) override {
        TGCallVideoCapturer *capturer = nil;
        pthread_mutex_lock(&_mutex);
        capturer = _capturer;
        pthread_mutex_unlock(&_mutex);
        [capturer applyCaptureWidth:width height:height fps:fps];
    }

private:
    pthread_mutex_t _mutex;
    __unsafe_unretained TGCallVideoCapturer *_capturer;
};

}

#if !defined(ONEGRAM_ARMV6)

@interface TGCallVideoCapturer () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _outputQueue;
    AVCaptureSession *_session;
    AVCaptureDeviceInput *_input;
    AVCaptureVideoDataOutput *_output;
    bool _running;
    bool _front;
    int _width;
    int _height;
    int _fps;
    pthread_mutex_t _mutex;
    std::shared_ptr<tgcalls::VideoFrameSink> _sink;
    std::shared_ptr<tgcalls::VideoFrameSink> _previewSink;
    std::shared_ptr<TGCallVideoCaptureControllerImpl> _controller;
    volatile int _orientation;
    id _orientationObserver;
    volatile uint32_t _capturedFrames;
    volatile uint32_t _startGeneration;
    volatile int64_t _operationStartedMicros;
    const char *volatile _operationName;
}
@end

@implementation TGCallVideoCapturer

+ (void)loadCameraInventory:(bool *)available frontAndBack:(bool *)frontAndBack
{
    static bool cachedAvailable = false;
    static bool cachedFrontAndBack = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (NSClassFromString(@"AVCaptureSession") == nil || NSClassFromString(@"AVCaptureVideoDataOutput") == nil)
            return;
        bool front = false;
        bool back = false;
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices)
        {
            if (device.position == AVCaptureDevicePositionFront)
                front = true;
            else if (device.position == AVCaptureDevicePositionBack)
                back = true;
        }
        cachedAvailable = devices.count != 0;
        cachedFrontAndBack = front && back;
    });
    *available = cachedAvailable;
    *frontAndBack = cachedFrontAndBack;
}

+ (bool)isAvailable
{
    bool available = false;
    bool frontAndBack = false;
    [self loadCameraInventory:&available frontAndBack:&frontAndBack];
    return available;
}

+ (bool)hasFrontAndBackCameras
{
    bool available = false;
    bool frontAndBack = false;
    [self loadCameraInventory:&available frontAndBack:&frontAndBack];
    return frontAndBack;
}

+ (OSType)pixelFormatForOutput:(AVCaptureVideoDataOutput *)output
{
    if ([output respondsToSelector:@selector(availableVideoCVPixelFormatTypes)])
    {
        NSArray *formats = output.availableVideoCVPixelFormatTypes;
        if ([formats containsObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)])
            return kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        if ([formats containsObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)])
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    }
    return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
}

+ (AVCaptureDevice *)deviceForFront:(bool)front
{
    AVCaptureDevice *fallback = nil;
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        if ((front && device.position == AVCaptureDevicePositionFront) || (!front && device.position == AVCaptureDevicePositionBack))
            return device;
        if (fallback == nil)
            fallback = device;
    }
    return fallback;
}

- (instancetype)initWithMediaQueue:(SQueue *)mediaQueue
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, NULL);
        _sessionQueue = dispatch_queue_create("org.onegram.call.video.session", DISPATCH_QUEUE_SERIAL);
        if (mediaQueue != nil)
            dispatch_set_target_queue(_sessionQueue, (dispatch_queue_t)[mediaQueue _dispatch_queueRaw]);
        _outputQueue = dispatch_queue_create("org.onegram.call.video.capture", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_outputQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        _front = [TGCallVideoCapturer deviceForFront:true].position == AVCaptureDevicePositionFront;
        _width = 640;
        _height = 480;
        _fps = 30;
        tgcalls::VideoLadderStep step;
        if (tgcalls::VideoProfile::current().initialCaptureStep(step))
        {
            _width = step.width;
            _height = step.height;
            _fps = step.fps;
        }
        _session = [[AVCaptureSession alloc] init];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        if ([_session respondsToSelector:@selector(setAutomaticallyConfiguresApplicationAudioSession:)])
            _session.automaticallyConfiguresApplicationAudioSession = false;
#endif
        _output = [[AVCaptureVideoDataOutput alloc] init];
        _output.alwaysDiscardsLateVideoFrames = true;
        _output.videoSettings = @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @([TGCallVideoCapturer pixelFormatForOutput:_output]) };
        [_output setSampleBufferDelegate:self queue:_outputQueue];
        if ([_session canAddOutput:_output])
            [_session addOutput:_output];
        _controller.reset(new TGCallVideoCaptureControllerImpl(self));
        [self updateOrientation];
        __weak TGCallVideoCapturer *weakSelf = self;
        _orientationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *notification)
        {
            __strong TGCallVideoCapturer *strongSelf = weakSelf;
            [strongSelf updateOrientation];
        }];
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:_session];
        [center addObserver:self selector:@selector(sessionInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:_session];
        [center addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:_session];
        [center addObserver:self selector:@selector(sessionDidStopRunning:) name:AVCaptureSessionDidStopRunningNotification object:_session];
    }
    return self;
}

- (void)sessionRuntimeError:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    syslog(LOG_ERR, "IOS6MEDIA capture.error domain=%s code=%ld", error.domain.UTF8String ?: "", (long)error.code);
    [self performSessionOperation:"recover" block:^
    {
        if (_running && !_session.isRunning)
            [_session startRunning];
    }];
}

- (void)sessionDidStopRunning:(NSNotification *)__unused notification
{
    syslog(LOG_NOTICE, "IOS6MEDIA capture.stopped expected=%d", _running ? 0 : 1);
}

- (void)performSessionOperation:(const char *)name block:(dispatch_block_t)block
{
    dispatch_async(_sessionQueue, ^
    {
        const int64_t startedMicros = tgcalls::rtp::MonotonicMicros();
        _operationName = name;
        _operationStartedMicros = startedMicros;
        block();
        _operationStartedMicros = 0;
        const int elapsedMillis = (int)((tgcalls::rtp::MonotonicMicros() - startedMicros) / 1000);
        if (elapsedMillis >= 500)
            syslog(LOG_NOTICE, "IOS6MEDIA capture.slow op=%s ms=%d running=%d preset=%s", name, elapsedMillis, _session.isRunning ? 1 : 0, _session.sessionPreset.UTF8String ?: "");
    });
}

- (void)scheduleStallCheck:(uint32_t)generation frames:(uint32_t)frames attempt:(int)attempt
{
    __weak TGCallVideoCapturer *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        __strong TGCallVideoCapturer *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_startGeneration != generation || strongSelf->_capturedFrames != frames)
            return;
        const int64_t busyMicros = strongSelf->_operationStartedMicros;
        if (busyMicros != 0)
        {
            syslog(LOG_ERR, "IOS6MEDIA capture.stalled attempt=%d blocked=%s ms=%d", attempt, strongSelf->_operationName ?: "", (int)((tgcalls::rtp::MonotonicMicros() - busyMicros) / 1000));
            [strongSelf scheduleStallCheck:generation frames:frames attempt:attempt];
            return;
        }
        [strongSelf performSessionOperation:"restart" block:^
        {
            if (!strongSelf->_running || strongSelf->_startGeneration != generation || strongSelf->_capturedFrames != frames)
                return;
            AVCaptureConnection *connection = [strongSelf->_output connectionWithMediaType:AVMediaTypeVideo];
            syslog(LOG_ERR, "IOS6MEDIA capture.stalled attempt=%d running=%d connection=%d enabled=%d active=%d", attempt, strongSelf->_session.isRunning ? 1 : 0, connection != nil ? 1 : 0, connection.isEnabled ? 1 : 0, connection.isActive ? 1 : 0);
            if (attempt >= 2)
                return;
            [strongSelf->_session stopRunning];
            [strongSelf->_session startRunning];
            [strongSelf scheduleStallCheck:generation frames:strongSelf->_capturedFrames attempt:attempt + 1];
        }];
    });
}

- (void)sessionInterrupted:(NSNotification *)__unused notification
{
    syslog(LOG_NOTICE, "IOS6MEDIA capture.interrupted");
}

- (void)sessionInterruptionEnded:(NSNotification *)__unused notification
{
    syslog(LOG_NOTICE, "IOS6MEDIA capture.resumed");
    [self performSessionOperation:"resume" block:^
    {
        if (_running && !_session.isRunning)
            [_session startRunning];
    }];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:_orientationObserver];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    _controller->detach();
    [_output setSampleBufferDelegate:nil queue:NULL];
    AVCaptureSession *session = _session;
    dispatch_async(_sessionQueue, ^
    {
        [session stopRunning];
    });
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_sessionQueue);
    dispatch_release(_outputQueue);
#endif
    pthread_mutex_destroy(&_mutex);
}

- (void)setPreviewView:(TGCallVideoView *)view
{
    std::shared_ptr<tgcalls::VideoFrameSink> sink = view != nil ? [view frameSink] : std::shared_ptr<tgcalls::VideoFrameSink>();
    pthread_mutex_lock(&_mutex);
    _previewSink = sink;
    pthread_mutex_unlock(&_mutex);
}

- (bool)usesFrontCamera
{
    return _front;
}

- (void)updateOrientation
{
    switch ([UIDevice currentDevice].orientation)
    {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            _orientation = (int)[UIDevice currentDevice].orientation;
            break;
        default:
            if (_orientation == 0)
                _orientation = (int)UIDeviceOrientationPortrait;
            break;
    }
}

- (int)rotationForFront:(bool)front
{
    switch ((UIDeviceOrientation)_orientation)
    {
        case UIDeviceOrientationPortraitUpsideDown:
            return 270;
        case UIDeviceOrientationLandscapeLeft:
            return front ? 180 : 0;
        case UIDeviceOrientationLandscapeRight:
            return front ? 0 : 180;
        default:
            return 90;
    }
}

- (NSString *)presetForWidth:(int)width height:(int)height
{
    NSMutableArray *candidates = [[NSMutableArray alloc] init];
    const int pixels = width * height;
    if (pixels >= 1280 * 720)
        [candidates addObject:AVCaptureSessionPreset1280x720];
    if (pixels >= 960 * 540 && iosMajorVersion() >= 5)
        [candidates addObject:AVCaptureSessionPresetiFrame960x540];
    if (pixels >= 640 * 480)
        [candidates addObject:AVCaptureSessionPreset640x480];
    if (pixels >= 480 * 360)
        [candidates addObject:AVCaptureSessionPresetMedium];
    if (pixels >= 352 * 288 && iosMajorVersion() >= 5)
        [candidates addObject:AVCaptureSessionPreset352x288];
    [candidates addObject:AVCaptureSessionPresetLow];
    for (NSString *preset in candidates)
    {
        if ([_session canSetSessionPreset:preset])
            return preset;
    }
    return AVCaptureSessionPresetLow;
}

- (void)applyFrameRate:(int)fps device:(AVCaptureDevice *)device
{
    if (fps <= 0 || device == nil)
        return;
    const CMTime duration = CMTimeMake(1, fps);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if ([device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)])
    {
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            bool supported = false;
            for (AVFrameRateRange *range in device.activeFormat.videoSupportedFrameRateRanges)
            {
                if (range.maxFrameRate >= fps && range.minFrameRate <= fps)
                    supported = true;
            }
            if (supported)
            {
                device.activeVideoMinFrameDuration = duration;
                device.activeVideoMaxFrameDuration = duration;
            }
            [device unlockForConfiguration];
        }
        return;
    }
#endif
    AVCaptureConnection *connection = [_output connectionWithMediaType:AVMediaTypeVideo];
    if ([connection respondsToSelector:@selector(isVideoMinFrameDurationSupported)] && connection.isVideoMinFrameDurationSupported)
        connection.videoMinFrameDuration = duration;
}

- (void)configureSession
{
    AVCaptureDevice *device = [TGCallVideoCapturer deviceForFront:_front];
    if (device == nil)
        return;
    [_session beginConfiguration];
    if (_input == nil || _input.device != device)
    {
        AVCaptureDeviceInput *previous = _input;
        if (previous != nil)
            [_session removeInput:previous];
        if ([_session canSetSessionPreset:AVCaptureSessionPresetLow])
            _session.sessionPreset = AVCaptureSessionPresetLow;
        NSError *error = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (input != nil && [_session canAddInput:input])
        {
            [_session addInput:input];
            _input = input;
            syslog(LOG_NOTICE, "IOS6MEDIA capture.device front=%d", device.position == AVCaptureDevicePositionFront ? 1 : 0);
        }
        else
        {
            syslog(LOG_ERR, "IOS6MEDIA capture.input.failed front=%d domain=%s code=%ld", _front ? 1 : 0, error.domain.UTF8String ?: "", (long)error.code);
            _input = nil;
            if (previous != nil && [_session canAddInput:previous])
            {
                [_session addInput:previous];
                _input = previous;
                _front = previous.device.position == AVCaptureDevicePositionFront;
                device = previous.device;
            }
        }
    }
    NSString *preset = [self presetForWidth:_width height:_height];
    if (![_session.sessionPreset isEqualToString:preset])
        _session.sessionPreset = preset;
    [_session commitConfiguration];
    [self applyFrameRate:_fps device:device];
}

- (void)applyCaptureWidth:(int)width height:(int)height fps:(int)fps
{
    [self performSessionOperation:"format" block:^
    {
        _width = width;
        _height = height;
        _fps = fps;
        if (_running)
            [self configureSession];
    }];
}

- (void)start
{
    [self performSessionOperation:"start" block:^
    {
        if (_running)
            return;
        _running = true;
        ++_startGeneration;
        [self configureSession];
        const int64_t startedMicros = tgcalls::rtp::MonotonicMicros();
        [_session startRunning];
        syslog(LOG_NOTICE, "IOS6MEDIA capture.start running=%d input=%d preset=%s requested=%dx%d@%d ms=%d format=%08x", _session.isRunning ? 1 : 0, _input != nil ? 1 : 0, _session.sessionPreset.UTF8String ?: "", _width, _height, _fps, (int)((tgcalls::rtp::MonotonicMicros() - startedMicros) / 1000), (unsigned int)[_output.videoSettings[(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey] unsignedIntValue]);
        [self scheduleStallCheck:_startGeneration frames:_capturedFrames attempt:0];
    }];
}

- (void)stop
{
    [self performSessionOperation:"stop" block:^
    {
        if (!_running)
            return;
        _running = false;
        ++_startGeneration;
        [_session stopRunning];
    }];
}

- (void)switchCamera
{
    [self performSessionOperation:"switch" block:^
    {
        _front = !_front;
        if (_running)
            [self configureSession];
    }];
}

- (void)setFrameSink:(std::shared_ptr<tgcalls::VideoFrameSink>)sink
{
    pthread_mutex_lock(&_mutex);
    _sink = sink;
    pthread_mutex_unlock(&_mutex);
}

- (std::shared_ptr<tgcalls::VideoCaptureController>)captureController
{
    return _controller;
}

- (void)captureOutput:(AVCaptureOutput *)__unused captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)__unused connection
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (imageBuffer == NULL)
        return;
    if (_capturedFrames++ == 0)
        syslog(LOG_NOTICE, "IOS6MEDIA capture.first size=%dx%d format=%08x", (int)CVPixelBufferGetWidth(imageBuffer), (int)CVPixelBufferGetHeight(imageBuffer), (unsigned int)CVPixelBufferGetPixelFormatType(imageBuffer));
    std::shared_ptr<tgcalls::VideoFrameSink> sink;
    std::shared_ptr<tgcalls::VideoFrameSink> previewSink;
    pthread_mutex_lock(&_mutex);
    sink = _sink;
    previewSink = _previewSink;
    pthread_mutex_unlock(&_mutex);
    if (!sink && !previewSink)
        return;
    const bool front = _front;
    tgcalls::VideoFrame frame;
    frame.buffer.reset(new tgcalls::NativeVideoBuffer(imageBuffer));
    frame.rotation = [self rotationForFront:front];
    frame.mirrored = front;
    frame.timestampMicros = tgcalls::rtp::MonotonicMicros();
    if (previewSink)
        previewSink->onVideoFrame(frame);
    if (sink)
        sink->onVideoFrame(frame);
}

@end

#else

namespace {

typedef CVImageBufferRef (*TGCallSampleBufferGetImageBufferFunction)(CMSampleBufferRef);
typedef CVReturn (*TGCallPixelBufferLockFunction)(CVPixelBufferRef, CVOptionFlags);
typedef OSType (*TGCallPixelBufferGetFormatFunction)(CVPixelBufferRef);
typedef size_t (*TGCallPixelBufferGetSizeFunction)(CVPixelBufferRef);
typedef Boolean (*TGCallPixelBufferIsPlanarFunction)(CVPixelBufferRef);
typedef void *(*TGCallPixelBufferGetBaseAddressFunction)(CVPixelBufferRef);
typedef void *(*TGCallPixelBufferGetPlaneAddressFunction)(CVPixelBufferRef, size_t);
typedef size_t (*TGCallPixelBufferGetPlaneSizeFunction)(CVPixelBufferRef, size_t);
typedef void *(*TGCallQueueCreateFunction)(const char *, void *);
typedef void (*TGCallQueueSyncFunction)(void *, void *, void (*)(void *));
typedef void (*TGCallQueueReleaseFunction)(void *);

const OSType TGCallPixelFormatNV12VideoRange = 0x34323076;
const OSType TGCallPixelFormatNV12FullRange = 0x34323066;
const OSType TGCallPixelFormatBGRA = 0x42475241;
const OSType TGCallPixelFormatUYVY = 0x32767579;
const OSType TGCallPixelFormatYUY2 = 0x79757673;
const CVOptionFlags TGCallPixelBufferLockReadOnly = 1;
const NSInteger TGCallCaptureDevicePositionBack = 1;
const NSInteger TGCallCaptureDevicePositionFront = 2;

struct TGCallCaptureApi {
    bool available;
    TGCallSampleBufferGetImageBufferFunction sampleBufferGetImageBuffer;
    TGCallPixelBufferLockFunction lockBaseAddress;
    TGCallPixelBufferLockFunction unlockBaseAddress;
    TGCallPixelBufferGetFormatFunction getPixelFormatType;
    TGCallPixelBufferGetSizeFunction getWidth;
    TGCallPixelBufferGetSizeFunction getHeight;
    TGCallPixelBufferIsPlanarFunction isPlanar;
    TGCallPixelBufferGetSizeFunction getPlaneCount;
    TGCallPixelBufferGetBaseAddressFunction getBaseAddress;
    TGCallPixelBufferGetSizeFunction getBytesPerRow;
    TGCallPixelBufferGetPlaneAddressFunction getBaseAddressOfPlane;
    TGCallPixelBufferGetPlaneSizeFunction getBytesPerRowOfPlane;
    TGCallQueueCreateFunction queueCreate;
    TGCallQueueSyncFunction queueSync;
    TGCallQueueReleaseFunction queueRelease;
    __unsafe_unretained NSString *mediaTypeVideo;
    __unsafe_unretained NSString *presetMedium;
    __unsafe_unretained NSString *presetLow;
    Class sessionClass;
    Class deviceClass;
    Class deviceInputClass;
    Class videoDataOutputClass;
};

pthread_once_t TGCallCaptureApiOnce = PTHREAD_ONCE_INIT;
TGCallCaptureApi TGCallCaptureApiShared;

template <typename Function>
bool TGCallResolve(void *library, const char *name, Function *function)
{
    void *symbol = library != NULL ? dlsym(library, name) : NULL;
    *function = reinterpret_cast<Function>(symbol);
    return symbol != NULL;
}

bool TGCallResolveString(void *library, const char *name, __unsafe_unretained NSString **value)
{
    NSString *__unsafe_unretained *symbol = library != NULL ? (NSString *__unsafe_unretained *)dlsym(library, name) : NULL;
    *value = symbol != NULL ? *symbol : nil;
    return *value != nil;
}

void TGCallLoadCaptureApi()
{
    TGCallCaptureApi &api = TGCallCaptureApiShared;
    api.available = false;
    api.sessionClass = NSClassFromString(@"AVCaptureSession");
    api.deviceClass = NSClassFromString(@"AVCaptureDevice");
    api.deviceInputClass = NSClassFromString(@"AVCaptureDeviceInput");
    api.videoDataOutputClass = NSClassFromString(@"AVCaptureVideoDataOutput");
    if (api.sessionClass == Nil || api.deviceClass == Nil || api.deviceInputClass == Nil || api.videoDataOutputClass == Nil)
        return;
    void *foundation = dlopen("/System/Library/Frameworks/AVFoundation.framework/AVFoundation", RTLD_LAZY);
    void *media = dlopen("/System/Library/Frameworks/CoreMedia.framework/CoreMedia", RTLD_LAZY);
    void *video = dlopen("/System/Library/Frameworks/CoreVideo.framework/CoreVideo", RTLD_LAZY);
    void *system = dlopen("/usr/lib/libSystem.B.dylib", RTLD_LAZY);
    bool resolved = true;
    resolved &= TGCallResolveString(foundation, "AVMediaTypeVideo", &api.mediaTypeVideo);
    resolved &= TGCallResolveString(foundation, "AVCaptureSessionPresetMedium", &api.presetMedium);
    resolved &= TGCallResolveString(foundation, "AVCaptureSessionPresetLow", &api.presetLow);
    resolved &= TGCallResolve(media, "CMSampleBufferGetImageBuffer", &api.sampleBufferGetImageBuffer);
    resolved &= TGCallResolve(video, "CVPixelBufferLockBaseAddress", &api.lockBaseAddress);
    resolved &= TGCallResolve(video, "CVPixelBufferUnlockBaseAddress", &api.unlockBaseAddress);
    resolved &= TGCallResolve(video, "CVPixelBufferGetPixelFormatType", &api.getPixelFormatType);
    resolved &= TGCallResolve(video, "CVPixelBufferGetWidth", &api.getWidth);
    resolved &= TGCallResolve(video, "CVPixelBufferGetHeight", &api.getHeight);
    resolved &= TGCallResolve(video, "CVPixelBufferIsPlanar", &api.isPlanar);
    resolved &= TGCallResolve(video, "CVPixelBufferGetPlaneCount", &api.getPlaneCount);
    resolved &= TGCallResolve(video, "CVPixelBufferGetBaseAddress", &api.getBaseAddress);
    resolved &= TGCallResolve(video, "CVPixelBufferGetBytesPerRow", &api.getBytesPerRow);
    resolved &= TGCallResolve(video, "CVPixelBufferGetBaseAddressOfPlane", &api.getBaseAddressOfPlane);
    resolved &= TGCallResolve(video, "CVPixelBufferGetBytesPerRowOfPlane", &api.getBytesPerRowOfPlane);
    resolved &= TGCallResolve(system, "dispatch_queue_create", &api.queueCreate);
    resolved &= TGCallResolve(system, "dispatch_sync_f", &api.queueSync);
    resolved &= TGCallResolve(system, "dispatch_release", &api.queueRelease);
    api.available = resolved;
}

const TGCallCaptureApi &TGCallCapture()
{
    pthread_once(&TGCallCaptureApiOnce, &TGCallLoadCaptureApi);
    return TGCallCaptureApiShared;
}

void TGCallDrainQueue(void *)
{
}

bool TGCallRawFormat(OSType format, tgcalls::RawVideoFormat *result)
{
    switch (format)
    {
        case TGCallPixelFormatNV12VideoRange:
            *result = tgcalls::RawVideoFormat::NV12VideoRange;
            return true;
        case TGCallPixelFormatNV12FullRange:
            *result = tgcalls::RawVideoFormat::NV12FullRange;
            return true;
        case TGCallPixelFormatBGRA:
            *result = tgcalls::RawVideoFormat::BGRA;
            return true;
        case TGCallPixelFormatUYVY:
            *result = tgcalls::RawVideoFormat::UYVY;
            return true;
        case TGCallPixelFormatYUY2:
            *result = tgcalls::RawVideoFormat::YUY2;
            return true;
        default:
            return false;
    }
}

}

@protocol TGCallLegacyCaptureDeviceClass <NSObject>

- (NSArray *)devicesWithMediaType:(NSString *)mediaType;
- (id)defaultDeviceWithMediaType:(NSString *)mediaType;

@end

@protocol TGCallLegacyCaptureDevice <NSObject>

- (NSInteger)position;

@end

@protocol TGCallLegacyCaptureDeviceInputClass <NSObject>

- (id)deviceInputWithDevice:(id)device error:(NSError **)error;

@end

@protocol TGCallLegacyCaptureDeviceInput <NSObject>

- (id)device;

@end

@protocol TGCallLegacyCaptureSession <NSObject>

- (BOOL)canSetSessionPreset:(NSString *)preset;
- (NSString *)sessionPreset;
- (void)setSessionPreset:(NSString *)preset;
- (BOOL)canAddInput:(id)input;
- (void)addInput:(id)input;
- (void)removeInput:(id)input;
- (BOOL)canAddOutput:(id)output;
- (void)addOutput:(id)output;
- (void)beginConfiguration;
- (void)commitConfiguration;
- (void)startRunning;
- (void)stopRunning;

@end

@protocol TGCallLegacyCaptureVideoDataOutput <NSObject>

- (void)setAlwaysDiscardsLateVideoFrames:(BOOL)discards;
- (void)setMinFrameDuration:(CMTime)duration;
- (void)setSampleBufferDelegate:(id)delegate queue:(void *)queue;

@end

@interface TGCallVideoCapturer ()
{
    dispatch_queue_t _sessionQueue;
    void *_outputQueue;
    id<TGCallLegacyCaptureSession> _session;
    id<TGCallLegacyCaptureDeviceInput> _input;
    id<TGCallLegacyCaptureVideoDataOutput> _output;
    bool _running;
    bool _front;
    int _width;
    int _height;
    int _fps;
    int64_t _lastFrameMicros;
    bool _reportedUnsupportedFormat;
    uint32_t _capturedFrames;
    pthread_mutex_t _mutex;
    std::shared_ptr<tgcalls::VideoFrameSink> _sink;
    std::shared_ptr<tgcalls::VideoFrameSink> _previewSink;
    std::shared_ptr<TGCallVideoCaptureControllerImpl> _controller;
    volatile int _orientation;
}

- (void)captureOutput:(id)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(id)connection;

@end

@implementation TGCallVideoCapturer

+ (void)loadCameraInventory:(bool *)available frontAndBack:(bool *)frontAndBack
{
    static bool cachedAvailable = false;
    static bool cachedFrontAndBack = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        const TGCallCaptureApi &api = TGCallCapture();
        if (!api.available)
            return;
        id<TGCallLegacyCaptureDeviceClass> deviceClass = api.deviceClass;
        bool front = false;
        bool back = false;
        NSArray *devices = [deviceClass devicesWithMediaType:api.mediaTypeVideo];
        for (id<TGCallLegacyCaptureDevice> device in devices)
        {
            if (device.position == TGCallCaptureDevicePositionFront)
                front = true;
            else if (device.position == TGCallCaptureDevicePositionBack)
                back = true;
        }
        cachedAvailable = devices.count != 0;
        cachedFrontAndBack = front && back;
    });
    *available = cachedAvailable;
    *frontAndBack = cachedFrontAndBack;
}

+ (bool)isAvailable
{
    bool available = false;
    bool frontAndBack = false;
    [self loadCameraInventory:&available frontAndBack:&frontAndBack];
    return available;
}

+ (bool)hasFrontAndBackCameras
{
    bool available = false;
    bool frontAndBack = false;
    [self loadCameraInventory:&available frontAndBack:&frontAndBack];
    return frontAndBack;
}

+ (id<TGCallLegacyCaptureDevice>)deviceForFront:(bool)front
{
    const TGCallCaptureApi &api = TGCallCapture();
    if (!api.available)
        return nil;
    id<TGCallLegacyCaptureDeviceClass> deviceClass = api.deviceClass;
    id<TGCallLegacyCaptureDevice> fallback = nil;
    for (id<TGCallLegacyCaptureDevice> device in [deviceClass devicesWithMediaType:api.mediaTypeVideo])
    {
        const NSInteger position = device.position;
        if ((front && position == TGCallCaptureDevicePositionFront) || (!front && position == TGCallCaptureDevicePositionBack))
            return device;
        if (fallback == nil)
            fallback = device;
    }
    return fallback;
}

- (instancetype)initWithMediaQueue:(SQueue *)mediaQueue
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, NULL);
        _controller.reset(new TGCallVideoCaptureControllerImpl(self));
        _width = 192;
        _height = 144;
        _fps = 12;
        tgcalls::VideoLadderStep step;
        if (tgcalls::VideoProfile::current().initialCaptureStep(step))
        {
            _width = step.width;
            _height = step.height;
            _fps = step.fps;
        }
        _orientation = (int)UIDeviceOrientationPortrait;
        const TGCallCaptureApi &api = TGCallCapture();
        if (api.available)
        {
            _sessionQueue = dispatch_queue_create("org.onegram.call.video.session", DISPATCH_QUEUE_SERIAL);
            if (mediaQueue != nil)
                dispatch_set_target_queue(_sessionQueue, (dispatch_queue_t)[mediaQueue _dispatch_queueRaw]);
            _outputQueue = api.queueCreate("org.onegram.call.video.capture", NULL);
            _front = [TGCallVideoCapturer deviceForFront:true].position == TGCallCaptureDevicePositionFront;
            _session = [[api.sessionClass alloc] init];
            _output = [[api.videoDataOutputClass alloc] init];
            [_output setAlwaysDiscardsLateVideoFrames:true];
            [_output setSampleBufferDelegate:self queue:_outputQueue];
            if ([_session canAddOutput:_output])
                [_session addOutput:_output];
            [self updateOrientation];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
            [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        }
    }
    return self;
}

- (void)dealloc
{
    _controller->detach();
    if (_session != nil)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
        const TGCallCaptureApi &api = TGCallCapture();
        [_output setSampleBufferDelegate:nil queue:NULL];
        api.queueSync(_outputQueue, NULL, &TGCallDrainQueue);
        api.queueRelease(_outputQueue);
        id<TGCallLegacyCaptureSession> session = _session;
        dispatch_async(_sessionQueue, ^
        {
            [session stopRunning];
        });
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_sessionQueue);
#endif
    }
    pthread_mutex_destroy(&_mutex);
}

- (void)setPreviewView:(TGCallVideoView *)view
{
    std::shared_ptr<tgcalls::VideoFrameSink> sink = view != nil ? [view frameSink] : std::shared_ptr<tgcalls::VideoFrameSink>();
    pthread_mutex_lock(&_mutex);
    _previewSink = sink;
    pthread_mutex_unlock(&_mutex);
}

- (bool)usesFrontCamera
{
    return _front;
}

- (void)deviceOrientationChanged:(NSNotification *)__unused notification
{
    [self updateOrientation];
}

- (void)updateOrientation
{
    switch ([UIDevice currentDevice].orientation)
    {
        case UIDeviceOrientationPortrait:
        case UIDeviceOrientationPortraitUpsideDown:
        case UIDeviceOrientationLandscapeLeft:
        case UIDeviceOrientationLandscapeRight:
            _orientation = (int)[UIDevice currentDevice].orientation;
            break;
        default:
            break;
    }
}

- (int)rotationForFront:(bool)front
{
    switch ((UIDeviceOrientation)_orientation)
    {
        case UIDeviceOrientationPortraitUpsideDown:
            return 270;
        case UIDeviceOrientationLandscapeLeft:
            return front ? 180 : 0;
        case UIDeviceOrientationLandscapeRight:
            return front ? 0 : 180;
        default:
            return 90;
    }
}

- (void)configureSession
{
    const TGCallCaptureApi &api = TGCallCapture();
    id<TGCallLegacyCaptureDevice> device = [TGCallVideoCapturer deviceForFront:_front];
    if (device == nil)
        return;
    [_session beginConfiguration];
    if (_input == nil || _input.device != device)
    {
        id<TGCallLegacyCaptureDeviceInput> previous = _input;
        if (previous != nil)
            [_session removeInput:previous];
        if ([_session canSetSessionPreset:api.presetLow])
            [_session setSessionPreset:api.presetLow];
        id<TGCallLegacyCaptureDeviceInputClass> inputClass = api.deviceInputClass;
        NSError *error = nil;
        id<TGCallLegacyCaptureDeviceInput> input = [inputClass deviceInputWithDevice:device error:&error];
        if (input != nil && [_session canAddInput:input])
        {
            [_session addInput:input];
            _input = input;
            syslog(LOG_NOTICE, "IOS6MEDIA capture.device front=%d", device.position == TGCallCaptureDevicePositionFront ? 1 : 0);
        }
        else
        {
            syslog(LOG_ERR, "IOS6MEDIA capture.input.failed front=%d domain=%s code=%ld", _front ? 1 : 0, error.domain.UTF8String ?: "", (long)error.code);
            _input = nil;
            if (previous != nil && [_session canAddInput:previous])
            {
                [_session addInput:previous];
                _input = previous;
                id<TGCallLegacyCaptureDevice> previousDevice = previous.device;
                _front = previousDevice.position == TGCallCaptureDevicePositionFront;
            }
        }
    }
    NSString *preset = _width * _height > 192 * 144 && [_session canSetSessionPreset:api.presetMedium] ? api.presetMedium : api.presetLow;
    if ([_session canSetSessionPreset:preset] && ![[_session sessionPreset] isEqualToString:preset])
        [_session setSessionPreset:preset];
    [_session commitConfiguration];
    if (_fps > 0 && [_output respondsToSelector:@selector(setMinFrameDuration:)])
        [_output setMinFrameDuration:CMTimeMake(1, _fps)];
}

- (void)applyCaptureWidth:(int)width height:(int)height fps:(int)fps
{
    pthread_mutex_lock(&_mutex);
    _width = width;
    _height = height;
    _fps = fps;
    pthread_mutex_unlock(&_mutex);
    if (_session == nil)
        return;
    dispatch_async(_sessionQueue, ^
    {
        if (_running)
            [self configureSession];
    });
}

- (void)start
{
    if (_session == nil)
        return;
    dispatch_async(_sessionQueue, ^
    {
        if (_running)
            return;
        _running = true;
        [self configureSession];
        [_session startRunning];
        syslog(LOG_NOTICE, "IOS6MEDIA capture.start input=%d requested=%dx%d@%d", _input != nil ? 1 : 0, _width, _height, _fps);
    });
}

- (void)stop
{
    if (_session == nil)
        return;
    dispatch_async(_sessionQueue, ^
    {
        if (!_running)
            return;
        _running = false;
        [_session stopRunning];
    });
}

- (void)switchCamera
{
    if (_session == nil || ![TGCallVideoCapturer hasFrontAndBackCameras])
        return;
    dispatch_async(_sessionQueue, ^
    {
        _front = !_front;
        if (_running)
            [self configureSession];
    });
}

- (void)setFrameSink:(std::shared_ptr<tgcalls::VideoFrameSink>)sink
{
    pthread_mutex_lock(&_mutex);
    _sink = sink;
    pthread_mutex_unlock(&_mutex);
}

- (std::shared_ptr<tgcalls::VideoCaptureController>)captureController
{
    return _controller;
}

- (void)captureOutput:(id)__unused captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(id)__unused connection
{
    const TGCallCaptureApi &api = TGCallCapture();
    std::shared_ptr<tgcalls::VideoFrameSink> sink;
    std::shared_ptr<tgcalls::VideoFrameSink> previewSink;
    int maxWidth = 0;
    int maxHeight = 0;
    int fps = 0;
    pthread_mutex_lock(&_mutex);
    sink = _sink;
    previewSink = _previewSink;
    maxWidth = _width;
    maxHeight = _height;
    fps = _fps;
    pthread_mutex_unlock(&_mutex);
    if (!sink && !previewSink)
        return;
    const int64_t now = tgcalls::rtp::MonotonicMicros();
    if (fps > 0 && _lastFrameMicros != 0)
    {
        const int64_t interval = 1000000 / fps;
        if (now - _lastFrameMicros < interval - interval / 6)
            return;
    }
    CVImageBufferRef imageBuffer = api.sampleBufferGetImageBuffer(sampleBuffer);
    if (imageBuffer == NULL)
        return;
    tgcalls::RawVideoImage image;
    memset(&image, 0, sizeof(image));
    const OSType format = api.getPixelFormatType(imageBuffer);
    if (_capturedFrames++ == 0)
        syslog(LOG_NOTICE, "IOS6MEDIA capture.first size=%dx%d format=%08x", (int)api.getWidth(imageBuffer), (int)api.getHeight(imageBuffer), (unsigned int)format);
    if (!TGCallRawFormat(format, &image.format))
    {
        if (!_reportedUnsupportedFormat)
        {
            _reportedUnsupportedFormat = true;
            syslog(LOG_ERR, "IOS6MEDIA capture.format.unsupported format=%08x", (unsigned int)format);
        }
        return;
    }
    if (api.lockBaseAddress(imageBuffer, TGCallPixelBufferLockReadOnly) != 0)
        return;
    image.width = (int)api.getWidth(imageBuffer);
    image.height = (int)api.getHeight(imageBuffer);
    if (api.isPlanar(imageBuffer))
    {
        const size_t planes = api.getPlaneCount(imageBuffer);
        for (size_t i = 0; i < planes && i < 2; ++i)
        {
            image.planes[i] = static_cast<const uint8_t *>(api.getBaseAddressOfPlane(imageBuffer, i));
            image.strides[i] = api.getBytesPerRowOfPlane(imageBuffer, i);
        }
    }
    else
    {
        image.planes[0] = static_cast<const uint8_t *>(api.getBaseAddress(imageBuffer));
        image.strides[0] = api.getBytesPerRow(imageBuffer);
    }
    const tgcalls::VideoCropPlan plan = tgcalls::PlanVideoCrop(image.width, image.height, maxWidth, maxHeight);
    std::shared_ptr<tgcalls::I420Buffer> buffer = tgcalls::ConvertToI420(tgcalls::CropRawVideoImage(image, plan.x, plan.y, plan.width, plan.height), plan.outputWidth, plan.outputHeight);
    api.unlockBaseAddress(imageBuffer, TGCallPixelBufferLockReadOnly);
    if (!buffer)
        return;
    _lastFrameMicros = now;
    const bool front = _front;
    tgcalls::VideoFrame frame;
    frame.buffer = buffer;
    frame.rotation = [self rotationForFront:front];
    frame.mirrored = front;
    frame.timestampMicros = now;
    if (previewSink)
        previewSink->onVideoFrame(frame);
    if (sink)
        sink->onVideoFrame(frame);
}

@end

#endif
