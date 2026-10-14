#import "TGVideoCameraPipeline.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <libkern/OSAtomic.h>
#if __has_include(<CoreMedia/CoreMedia.h>)
#import <CoreMedia/CoreMedia.h>
#endif

#import "TGVideoCameraGLRenderer.h"

#import "TGVideoCameraMovieRecorder.h"
#import "TGMediaVideoConverter.h"
#import "../../../OnegramRuntime/OGRuntime.h"

typedef enum {
	TGVideoCameraRecordingStatusIdle = 0,
	TGVideoCameraRecordingStatusStartingRecording,
	TGVideoCameraRecordingStatusRecording,
	TGVideoCameraRecordingStatusStoppingRecording,
} TGVideoCameraRecordingStatus;

const NSInteger TGVideoCameraRetainedBufferCount = 16;

static bool TGVideoCameraPipelineUsesConstrainedProfile(void)
{
    return OGRuntimeSingleCoreDevice();
}

static int32_t TGVideoCameraPipelineFrameRate(void)
{
    if (iosMajorVersion() < 5)
        return 15;
    return TGVideoCameraPipelineUsesConstrainedProfile() ? 24 : 30;
}

static bool TGVideoCameraPipelineUsesStagedAudioStartup(void)
{
    return iosMajorVersion() < 7;
}

static NSString *TGVideoCameraPipelineSessionPreset(AVCaptureSession *session)
{
    if (iosMajorVersion() < 7)
    {
        if ([session canSetSessionPreset:AVCaptureSessionPreset640x480])
            return AVCaptureSessionPreset640x480;
        return AVCaptureSessionPresetMedium;
    }
    if (TGVideoCameraPipelineUsesConstrainedProfile())
    {
        if (&AVCaptureSessionPreset352x288 != NULL && [session canSetSessionPreset:AVCaptureSessionPreset352x288])
            return AVCaptureSessionPreset352x288;
        if ([session canSetSessionPreset:AVCaptureSessionPresetMedium])
            return AVCaptureSessionPresetMedium;
    }
    
    if ([session canSetSessionPreset:AVCaptureSessionPreset640x480])
        return AVCaptureSessionPreset640x480;
    return AVCaptureSessionPresetMedium;
}

static CGFloat TGVideoCameraPipelineMaximumOutputSide(void)
{
    if (TGVideoCameraPipelineUsesConstrainedProfile())
        return [TGMediaVideoConversionPresetSettings maximumSizeForPreset:TGMediaVideoConversionPresetVideoMessage].width;
    return CGFLOAT_MAX;
}

@protocol TGVideoCameraSessionExecuting <NSObject>

- (void)dispatch:(dispatch_block_t)block;
- (void)dispatchAsync:(dispatch_block_t)block;
- (bool)isCurrentQueue;

@end

@interface TGVideoCameraRunLoopExecutor : NSObject <TGVideoCameraSessionExecuting>
{
    NSThread *_thread;
    NSCondition *_condition;
    NSMutableArray *_tasks;
    bool _ready;
    bool _drainScheduled;
}

- (void)dispatch:(dispatch_block_t)block;
- (void)dispatchAsync:(dispatch_block_t)block;
- (bool)isCurrentQueue;

@end

@implementation TGVideoCameraRunLoopExecutor

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _condition = [[NSCondition alloc] init];
        _tasks = [[NSMutableArray alloc] init];
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadMain) object:nil];
        _thread.name = @"org.telegram.VideoCameraPipeline.session";
        [_condition lock];
        [_thread start];
        while (!_ready)
            [_condition wait];
        [_condition unlock];
    }
    return self;
}

- (void)threadMain
{
    @autoreleasepool
    {
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        NSPort *port = [NSPort port];
        [runLoop addPort:port forMode:NSDefaultRunLoopMode];
        [_condition lock];
        _ready = true;
        [_condition signal];
        [_condition unlock];
        while (true)
        {
            @autoreleasepool
            {
                [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
            }
        }
    }
}

- (bool)isCurrentQueue
{
    return [NSThread currentThread] == _thread;
}

- (void)dispatch:(dispatch_block_t)block
{
    if (block == nil)
        return;
    if ([self isCurrentQueue])
        block();
    else
        [self dispatchAsync:block];
}

- (void)dispatchAsync:(dispatch_block_t)block
{
    if (block == nil)
        return;
    [_condition lock];
    [_tasks addObject:[block copy]];
    bool schedule = !_drainScheduled;
    _drainScheduled = true;
    [_condition unlock];
    if (schedule)
        [self performSelector:@selector(drainTask) onThread:_thread withObject:nil waitUntilDone:false modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

- (void)drainTask
{
    [_condition lock];
    dispatch_block_t task = nil;
    if (_tasks.count != 0)
    {
        task = [_tasks objectAtIndex:0];
        [_tasks removeObjectAtIndex:0];
    }
    [_condition unlock];
    @autoreleasepool
    {
        if (task != nil)
            task();
    }
    [_condition lock];
    bool schedule = _tasks.count != 0;
    _drainScheduled = schedule;
    [_condition unlock];
    if (schedule)
        [self performSelector:@selector(drainTask) onThread:_thread withObject:nil waitUntilDone:false modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

@end

@interface TGVideoCameraDispatchExecutor : NSObject <TGVideoCameraSessionExecuting>
{
    SQueue *_queue;
}

@end

@implementation TGVideoCameraDispatchExecutor

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _queue = [[SQueue alloc] init];
    return self;
}

- (void)dispatch:(dispatch_block_t)block
{
    [_queue dispatch:block];
}

- (void)dispatchAsync:(dispatch_block_t)block
{
    if (block != nil)
        dispatch_async((dispatch_queue_t)[_queue _dispatch_queueRaw], block);
}

- (bool)isCurrentQueue
{
    return [_queue isCurrentQueue];
}

@end

@interface TGVideoCameraPipeline () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, TGVideoCameraMovieRecorderDelegate>
{
	AVCaptureSession *_captureSession;
    
	AVCaptureDevice *_videoDevice;
    AVCaptureConnection *_videoConnection;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    
    AVCaptureDevice *_audioDevice;
	AVCaptureConnection *_audioConnection;
    AVCaptureDeviceInput *_audioInput;
    AVCaptureAudioDataOutput *_audioOutput;
    
	AVCaptureVideoOrientation _videoBufferOrientation;
    AVCaptureDevicePosition _preferredPosition;
	bool _running;
    bool _starting;
	bool _startCaptureSessionOnEnteringForeground;
	id _applicationWillEnterForegroundObserver;
	
    dispatch_queue_t _audioDataOutputQueue;
	dispatch_queue_t _videoDataOutputQueue;
	
	TGVideoCameraGLRenderer *_renderer;
	bool _renderingEnabled;
	
	TGVideoCameraMovieRecorder *_recorder;
	NSURL *_recordingURL;
	TGVideoCameraRecordingStatus _recordingStatus;
    UIImage *_recordingThumbnail;
		
	__weak id<TGVideoCameraPipelineDelegate> _delegate;
	dispatch_queue_t _delegateCallbackQueue;
    
    NSTimeInterval _resultDuration;
    
    CVPixelBufferRef _previousPixelBuffer;
    int32_t _repeatingCount;
    
    NSMutableData *_audioBuffer;
    int32_t _micLevelPeak;
    int _micLevelPeakCount;
    
    TGMediaVideoConversionPreset _preset;
    
    bool _liveUpload;
    id<TGLiveUploadInterface> _watcher;
    id _liveUploadData;
    
    OSSpinLock _recordLock;
    bool _startRecordAfterFormatBuffer;
    bool _stopRecordAfterPreparing;
    
    CVPixelBufferRef _currentPreviewPixelBuffer;
    NSMutableDictionary *_thumbnails;
    
    NSTimeInterval _firstThumbnailTime;
    NSTimeInterval _previousThumbnailTime;
    
    id<TGLiveUploadInterface> _liveUploadInterface;
    bool _stopRunningPending;
    void (^_stopRunningCompletion)(void);
    
    CFAbsoluteTime _startRunningTime;
    CFAbsoluteTime _captureSetupTime;
    bool _receivedFirstVideoFrame;
    bool _receivedFirstAudioSample;
    bool _sessionRecoveryAttempted;
    bool _captureFailureReported;
    AVCaptureVideoPreviewLayer *_previewLayer;
    CFAbsoluteTime _statsWindowStart;
    NSUInteger _statsReceivedFrames;
    NSUInteger _statsRenderedFrames;
    NSUInteger _statsDroppedFrames;
    CFAbsoluteTime _statsRenderTime;
    bool _previewCallbackPending;
    bool _videoPipelineFailed;
    STimer *_startupTimer;
    NSUInteger _failedRenderFrameCount;
}

@property (nonatomic, strong) __attribute__((NSObject)) CMFormatDescriptionRef outputVideoFormatDescription;
@property (nonatomic, strong) __attribute__((NSObject)) CMFormatDescriptionRef outputAudioFormatDescription;

- (bool)stopRecordingOnCameraQueue;
- (void)finishStoppingCaptureSession;
- (void)startRecordingWhenFormatsAvailable;
- (void)startPreparedCaptureSession;
- (bool)addAudioInputWithError:(NSError **)error;
- (void)startAudioCaptureAfterVideo;
- (void)startStartupTimerForPhase:(NSString *)phase;
- (void)configureVideoOutputPixelFormat;
+ (id<TGVideoCameraSessionExecuting> )cameraQueue;

@end

@implementation TGVideoCameraPipeline

- (instancetype)initWithDelegate:(id<TGVideoCameraPipelineDelegate>)delegate position:(AVCaptureDevicePosition)position callbackQueue:(dispatch_queue_t)queue liveUploadInterface:(id<TGLiveUploadInterface>)liveUploadInterface
{
	self = [super init];
	if (self != nil)
	{
        _liveUploadInterface = liveUploadInterface;
        _preferredPosition = position;
		
		_videoDataOutputQueue = dispatch_queue_create("org.telegram.VideoCameraPipeline.video", DISPATCH_QUEUE_SERIAL);
        _audioDataOutputQueue = dispatch_queue_create("org.telegram.VideoCameraPipeline.audio", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(_videoDataOutputQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
		
				
		_delegate = delegate;
		_delegateCallbackQueue = queue;
#if !OS_OBJECT_USE_OBJC
        dispatch_retain(_delegateCallbackQueue);
#endif
        
        _thumbnails = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[self destroyCaptureSession];
    if (_currentPreviewPixelBuffer != NULL)
        CFRelease(_currentPreviewPixelBuffer);
    if (_previousPixelBuffer != NULL)
        CFRelease(_previousPixelBuffer);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_videoDataOutputQueue);
    dispatch_release(_audioDataOutputQueue);
    dispatch_release(_delegateCallbackQueue);
#endif
}

- (void)startRunning
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        if (_running || _starting || _stopRunningPending || _captureFailureReported)
            return;
        _starting = true;
        _startRunningTime = CFAbsoluteTimeGetCurrent();
        _receivedFirstVideoFrame = false;
        _receivedFirstAudioSample = false;
		_videoPipelineFailed = false;
		[self setupCaptureSession];
        _captureSetupTime = CFAbsoluteTimeGetCurrent() - _startRunningTime;
        if (_captureSession == nil)
        {
            _starting = false;
            return;
        }
        if (self.usesNativePreview)
        {
            [self invokeDelegateCallbackAsync:^{
                bool prepared = [_delegate capturePipelineDidPrepareToStartRunning:self];
                [[TGVideoCameraPipeline cameraQueue] dispatch:^{
                    if (!prepared)
                    {
                        [self stopRunning];
                        return;
                    }
                    [self startPreparedCaptureSession];
                }];
            }];
        }
        else
            [self startPreparedCaptureSession];
	}];
}

- (void)startPreparedCaptureSession
{
    if (!_starting || _captureSession == nil || _stopRunningPending || _captureFailureReported)
        return;
    _starting = false;
    [_captureSession startRunning];
    _running = _captureSession.running;
    if (!_running)
    {
        [self handleNonRecoverableCaptureSessionRuntimeError:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedFailureReasonErrorKey: @"The capture session could not start."}]];
        return;
    }
    [self startStartupTimerForPhase:TGVideoCameraPipelineUsesStagedAudioStartup() ? @"video" : @"audio-video"];
}

- (void)startStartupTimerForPhase:(NSString *)phase
{
    [_startupTimer invalidate];
    __weak TGVideoCameraPipeline *weakSelf = self;
    AVCaptureSession *session = _captureSession;
    bool videoPhase = [phase isEqualToString:@"video"];
    NSTimeInterval remainingStartupTime = 10.0;
    TGLegacyLog(@"VIDEOMESSAGE waiting for formats phase=%@ timeout=%.0fms", phase, remainingStartupTime * 1000.0);
    _startupTimer = [[STimer alloc] initWithTimeout:remainingStartupTime repeat:false completion:^{
        [[TGVideoCameraPipeline cameraQueue] dispatchAsync:^{
            TGVideoCameraPipeline *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_captureSession == session && strongSelf->_running && !strongSelf->_stopRunningPending && !strongSelf->_captureFailureReported && (videoPhase ? strongSelf.outputVideoFormatDescription == NULL : (strongSelf.outputAudioFormatDescription == NULL || strongSelf.outputVideoFormatDescription == NULL)))
            {
                NSString *reason = [NSString stringWithFormat:@"The capture session did not deliver its formats during %@ startup.", phase];
                [strongSelf handleNonRecoverableCaptureSessionRuntimeError:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedFailureReasonErrorKey: reason}]];
            }
        }];
    } nativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [_startupTimer start];
}

- (bool)usesNativePreview
{
    return iosMajorVersion() < 5 || TGVideoCameraPipelineUsesConstrainedProfile();
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    @synchronized (self)
    {
        return _previewLayer;
    }
}

- (void)stopRunning
{
    [self stopRunningWithCompletion:nil];
}

- (void)stopRunningWithCompletion:(void (^)(void))completion
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        if (_stopRunningPending)
            return;

        _stopRunningPending = true;
        _starting = false;
        _stopRunningCompletion = [completion copy];
        _running = false;

        OSSpinLockLock(&_recordLock);
        _startRecordAfterFormatBuffer = false;
        OSSpinLockUnlock(&_recordLock);

        [_videoOutput setSampleBufferDelegate:nil queue:NULL];
        [_audioOutput setSampleBufferDelegate:nil queue:NULL];

        if (_videoDataOutputQueue != NULL)
            dispatch_sync(_videoDataOutputQueue, ^{});
        if (_audioDataOutputQueue != NULL)
            dispatch_sync(_audioDataOutputQueue, ^{});

        if (![self stopRecordingOnCameraQueue])
            [self finishStoppingCaptureSession];
	}];
}

- (void)finishStoppingCaptureSession
{
    if (!_stopRunningPending)
        return;

    [_captureSession stopRunning];
    [self destroyVideoPipeline];
    self.outputAudioFormatDescription = NULL;
    [self destroyCaptureSession];

    void (^completion)(void) = _stopRunningCompletion;
    _stopRunningCompletion = nil;
    _stopRunningPending = false;

    if (completion != nil)
        completion();
}

- (void)setupCaptureSession
{
	if (_captureSession != nil)
		return;
	
    if (_renderer == nil)
        _renderer = [[TGVideoCameraGLRenderer alloc] init];
	_captureSession = [[AVCaptureSession alloc] init];	
    if (iosMajorVersion() >= 7)
    {
        SEL useApplicationSession = NSSelectorFromString(@"setUsesApplicationAudioSession:");
        SEL configureApplicationSession = NSSelectorFromString(@"setAutomaticallyConfiguresApplicationAudioSession:");
        if ([_captureSession respondsToSelector:useApplicationSession])
        {
            void (*setUsesApplicationSession)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[_captureSession methodForSelector:useApplicationSession];
            setUsesApplicationSession(_captureSession, useApplicationSession, YES);
        }
        if ([_captureSession respondsToSelector:configureApplicationSession])
        {
            void (*setConfiguresApplicationSession)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[_captureSession methodForSelector:configureApplicationSession];
            setConfiguresApplicationSession(_captureSession, configureApplicationSession, NO);
        }
    }

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionNotification:) name:nil object:_captureSession];
    __weak TGVideoCameraPipeline *weakSelf = self;
	_applicationWillEnterForegroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:[[LegacyComponentsGlobals provider] applicationInstance] queue:nil usingBlock:^(__unused NSNotification *note)
    {
		[weakSelf applicationWillEnterForeground];
	}];

    [_captureSession beginConfiguration];

    NSError *audioDeviceError = nil;
    if (!TGVideoCameraPipelineUsesStagedAudioStartup() && ![self addAudioInputWithError:&audioDeviceError])
    {
        [_captureSession commitConfiguration];
        [self handleNonRecoverableCaptureSessionRuntimeError:audioDeviceError ?: [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorDeviceNotConnected userInfo:nil]];
        return;
    }


    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == _preferredPosition)
        {
            videoDevice = device;
            break;
        }
    }
    
    _renderer.mirror = (videoDevice.position == AVCaptureDevicePositionFront);
    _renderer.orientation = _orientation;
    
	NSError *videoDeviceError = nil;
	_videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:&videoDeviceError];
	if (_videoInput != nil && [_captureSession canAddInput:_videoInput])
    {
		[_captureSession addInput:_videoInput];
        _videoDevice = videoDevice;
	}
	else
    {
        [_captureSession commitConfiguration];
		[self handleNonRecoverableCaptureSessionRuntimeError:videoDeviceError ?: [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorDeviceNotConnected userInfo:nil]];
		return;
	}
	
	_videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoOutput.alwaysDiscardsLateVideoFrames = iosMajorVersion() < 5 || TGVideoCameraPipelineUsesConstrainedProfile();

	[_videoOutput setSampleBufferDelegate:self queue:_videoDataOutputQueue];
	
    if (![_captureSession canAddOutput:_videoOutput])
    {
        [_captureSession commitConfiguration];
        [self handleNonRecoverableCaptureSessionRuntimeError:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:nil]];
        return;
    }
    [_captureSession addOutput:_videoOutput];
	
	_videoConnection = TGAVCaptureConnectionWithMediaType(_videoOutput, AVMediaTypeVideo);
    
    _captureSession.sessionPreset = TGVideoCameraPipelineSessionPreset(_captureSession);
    [_captureSession commitConfiguration];
    _videoConnection = TGAVCaptureConnectionWithMediaType(_videoOutput, AVMediaTypeVideo);
    _audioConnection = TGAVCaptureConnectionWithMediaType(_audioOutput, AVMediaTypeAudio);
    if ([_captureSession.outputs containsObject:_videoOutput])
        [self configureVideoOutputPixelFormat];

    if (self.usesNativePreview)
    {
        AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
        @synchronized (self)
        {
            _previewLayer = previewLayer;
        }
    }
    
    [self _configureFPS];
	
    [self _enableLowLightBoost];
    [self _enableVideoStabilization];

    
	_videoBufferOrientation = _videoConnection.videoOrientation;
	
	return;
}

- (void)configureVideoOutputPixelFormat
{
    OSType pixelFormat = kCVPixelFormatType_32BGRA;
    if (iosMajorVersion() >= 5)
    {
        NSArray *formats = [_videoOutput availableVideoCVPixelFormatTypes];
        if ([formats containsObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)])
            pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
        else if ([formats containsObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)])
            pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    }
    _videoOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(pixelFormat) };
}

- (void)destroyCaptureSession
{
    [_startupTimer invalidate];
    _startupTimer = nil;
	if (_captureSession)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_captureSession];
		
		[[NSNotificationCenter defaultCenter] removeObserver:_applicationWillEnterForegroundObserver];
		_applicationWillEnterForegroundObserver = nil;

        [_videoOutput setSampleBufferDelegate:nil queue:NULL];
        [_audioOutput setSampleBufferDelegate:nil queue:NULL];

        [_captureSession beginConfiguration];
        if (_videoOutput != nil && [_captureSession.outputs containsObject:_videoOutput])
            [_captureSession removeOutput:_videoOutput];
        if (_videoInput != nil && [_captureSession.inputs containsObject:_videoInput])
            [_captureSession removeInput:_videoInput];
        if (_audioOutput != nil && [_captureSession.outputs containsObject:_audioOutput])
            [_captureSession removeOutput:_audioOutput];
        if (_audioInput != nil && [_captureSession.inputs containsObject:_audioInput])
            [_captureSession removeInput:_audioInput];
        [_captureSession commitConfiguration];

        _audioInput = nil;
        _audioDevice = nil;
        _audioOutput = nil;
        _audioConnection = nil;

        _videoInput = nil;
        _videoDevice = nil;
        _videoOutput = nil;
        _videoConnection = nil;

		_captureSession = nil;
        @synchronized (self)
        {
            _previewLayer.session = nil;
            _previewLayer = nil;
        }
	}
}

- (void)captureSessionNotification:(NSNotification *)notification
{
    TGLegacyLog(@"VIDEOMESSAGE session %@ error=%@", notification.name, notification.userInfo[AVCaptureSessionErrorKey]);
    [[TGVideoCameraPipeline cameraQueue] dispatchAsync:^
    {
        if (notification.object != _captureSession)
            return;
		if ([notification.name isEqualToString:AVCaptureSessionWasInterruptedNotification])
		{
			[self captureSessionDidStopRunning];
		}
		else if ([notification.name isEqualToString:AVCaptureSessionRuntimeErrorNotification])
		{
			[self captureSessionDidStopRunning];
			
			NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
			if (error.code == AVErrorDeviceIsNotAvailableInBackground)
			{
				if (_running)
					_startCaptureSessionOnEnteringForeground = true;
			}
			else if (error.code == AVErrorMediaServicesWereReset)
            {
				[self handleRecoverableCaptureSessionRuntimeError:error];
			}
			else
			{
				[self handleNonRecoverableCaptureSessionRuntimeError:error];
			}
		}
    }];
}

- (void)handleRecoverableCaptureSessionRuntimeError:(NSError *)error
{
    if (!_running)
        return;
    if (_sessionRecoveryAttempted || _recordingStatus != TGVideoCameraRecordingStatusIdle || _stopRunningPending)
    {
        [self handleNonRecoverableCaptureSessionRuntimeError:error];
        return;
    }
    _sessionRecoveryAttempted = true;
    _running = false;
    [_videoOutput setSampleBufferDelegate:nil queue:NULL];
    [_audioOutput setSampleBufferDelegate:nil queue:NULL];
    [_captureSession stopRunning];
    [self destroyVideoPipeline];
    dispatch_sync(_audioDataOutputQueue, ^{
        self.outputAudioFormatDescription = NULL;
    });
    [self destroyCaptureSession];
    [self startRunning];
}

- (void)handleNonRecoverableCaptureSessionRuntimeError:(NSError *)error
{
    if (_captureFailureReported)
        return;
    _captureFailureReported = true;
	_running = false;
    _starting = false;
    [_startupTimer invalidate];
    _startupTimer = nil;
    [self invokeDelegateCallbackAsync:^{
        [_delegate capturePipeline:self didStopRunningWithError:error];
    }];
    OSSpinLockLock(&_recordLock);
    _startRecordAfterFormatBuffer = false;
    OSSpinLockUnlock(&_recordLock);
    [_videoOutput setSampleBufferDelegate:nil queue:NULL];
    [_audioOutput setSampleBufferDelegate:nil queue:NULL];
    [_captureSession stopRunning];
    [self stopRecording];
    [self destroyVideoPipeline];
	[self destroyCaptureSession];
	
}

- (void)captureSessionDidStopRunning
{
	[self stopRecording];
	[self destroyVideoPipeline];
}

- (void)applicationWillEnterForeground
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
		if (_startCaptureSessionOnEnteringForeground)
		{
			_startCaptureSessionOnEnteringForeground = false;
			if (_running)
				[_captureSession startRunning];
		}
    }];
}

- (void)setupVideoPipelineWithInputFormatDescription:(CMFormatDescriptionRef)inputFormatDescription
{
	[_renderer prepareForInputWithFormatDescription:inputFormatDescription outputRetainedBufferCountHint:TGVideoCameraPipelineUsesConstrainedProfile() ? 4 : TGVideoCameraRetainedBufferCount maximumOutputSide:TGVideoCameraPipelineMaximumOutputSide()];
    OSSpinLockLock(&_recordLock);
    self.outputVideoFormatDescription = _renderer.outputFormatDescription;
    OSSpinLockUnlock(&_recordLock);
    if (self.outputVideoFormatDescription == NULL && !_videoPipelineFailed)
    {
        _videoPipelineFailed = true;
        [[TGVideoCameraPipeline cameraQueue] dispatch:^{
            [self handleNonRecoverableCaptureSessionRuntimeError:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorInvalidSourceMedia userInfo:nil]];
        }];
    }
}

- (void)destroyVideoPipeline
{
	dispatch_sync(_videoDataOutputQueue, ^
    {
		self.outputVideoFormatDescription = NULL;
		[_renderer reset];
        
        if (_currentPreviewPixelBuffer != NULL)
        {
            CFRelease(_currentPreviewPixelBuffer);
            _currentPreviewPixelBuffer = NULL;
        }

        if (_previousPixelBuffer != NULL)
        {
            CFRelease(_previousPixelBuffer);
            _previousPixelBuffer = NULL;
        }
	});
}

- (void)videoPipelineDidRunOutOfBuffers
{
	[self invokeDelegateCallbackAsync:^
    {
		[_delegate capturePipelineDidRunOutOfPreviewBuffers:self];
	}];
}

- (void)setRenderingEnabled:(bool)renderingEnabled
{
	@synchronized (self)
    {
		_renderingEnabled = renderingEnabled;
	}
}

- (bool)renderingEnabled
{
	@synchronized (self)
    {
		return _renderingEnabled;
	}
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)__unused connection
{
	CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
	
	if (captureOutput == _videoOutput)
	{
        if (!_receivedFirstVideoFrame)
        {
            _receivedFirstVideoFrame = true;
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
            if (TGVideoCameraPipelineUsesStagedAudioStartup())
            {
                AVCaptureSession *session = _captureSession;
                [[TGVideoCameraPipeline cameraQueue] dispatch:^{
                    if (_captureSession == session && _running && !_stopRunningPending && !_captureFailureReported)
                        [self startAudioCaptureAfterVideo];
                }];
            }
            [self invokeDelegateCallbackAsync:^{
                [_delegate capturePipelineDidStartRunning:self];
            }];
        }
        
        bool configuredVideoFormat = self.outputVideoFormatDescription != NULL;
		if (!configuredVideoFormat && !_videoPipelineFailed)
			[self setupVideoPipelineWithInputFormatDescription:formatDescription];

        if (self.outputVideoFormatDescription != NULL)
            [self renderVideoSampleBuffer:sampleBuffer];

        OSSpinLockLock(&_recordLock);
        bool waitingForFormats = _startRecordAfterFormatBuffer;
        OSSpinLockUnlock(&_recordLock);
        if (waitingForFormats)
        {
            [[TGVideoCameraPipeline cameraQueue] dispatch:^{
                [self startRecordingWhenFormatsAvailable];
            }];
        }
	}
	else if (captureOutput == _audioOutput)
	{
        if (!_receivedFirstAudioSample)
        {
            _receivedFirstAudioSample = true;
        }
		OSSpinLockLock(&_recordLock);
        self.outputAudioFormatDescription = formatDescription;
        OSSpinLockUnlock(&_recordLock);
		
		@synchronized (self)
        {
			if (_recordingStatus == TGVideoCameraRecordingStatusRecording)
				[_recorder appendAudioSampleBuffer:sampleBuffer];
		}

        CMBlockBufferRef blockBuffer = NULL;
        AudioBufferList audioBufferList;
        OSStatus audioResult = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
        const AudioStreamBasicDescription *description = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
        if (audioResult == noErr && description != NULL && description->mFormatID == kAudioFormatLinearPCM && description->mBitsPerChannel == 16 && (description->mFormatFlags & kAudioFormatFlagIsSignedInteger))
        {
            for (uint32_t i = 0; i < audioBufferList.mNumberBuffers; i++)
                [self processWaveformPreview:audioBufferList.mBuffers[i].mData count:audioBufferList.mBuffers[i].mDataByteSize / sizeof(int16_t)];
        }
        if (blockBuffer != NULL)
            CFRelease(blockBuffer);

        OSSpinLockLock(&_recordLock);
        bool waitingForFormats = _startRecordAfterFormatBuffer;
        OSSpinLockUnlock(&_recordLock);
        if (waitingForFormats)
        {
            [[TGVideoCameraPipeline cameraQueue] dispatch:^{
                [self startRecordingWhenFormatsAvailable];
            }];
        }
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)__unused sampleBuffer fromConnection:(AVCaptureConnection *)__unused connection
{
    if (captureOutput == _videoOutput)
        _statsDroppedFrames++;
}

- (void)reportFrameStatisticsWithRenderTime:(CFAbsoluteTime)renderTime rendered:(bool)rendered
{
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    if (_statsWindowStart < DBL_EPSILON)
        _statsWindowStart = currentTime;
    
    _statsReceivedFrames++;
    if (rendered)
    {
        _statsRenderedFrames++;
        _statsRenderTime += renderTime;
    }
    
    CFAbsoluteTime windowDuration = currentTime - _statsWindowStart;
    if (windowDuration < 2.0)
        return;
    
    
    _statsWindowStart = currentTime;
    _statsReceivedFrames = 0;
    _statsRenderedFrames = 0;
    _statsDroppedFrames = 0;
    _statsRenderTime = 0.0;
}

- (void)processWaveformPreview:(int16_t const *)samples count:(int)count {
    for (int i = 0; i < count; i++) {
        int32_t sample = samples[i];
        if (sample < 0) {
            sample = -sample;
        }
    
        if (_micLevelPeak < sample) {
            _micLevelPeak = sample;
        }
        _micLevelPeakCount++;
        
        if (_micLevelPeakCount >= 1200) {
            if (_micLevel) {
                CGFloat level = (CGFloat)_micLevelPeak / 4000.0;
                _micLevel(level);
            }
            _micLevelPeak = 0;
            _micLevelPeakCount = 0;
        }
    }
}

- (UIImage *)imageFromImageBuffer:(CVPixelBufferRef)imageBuffer
{
    if (imageBuffer == NULL || CVPixelBufferGetPixelFormatType(imageBuffer) != kCVPixelFormatType_32BGRA || CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess)
        return nil;
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGImageRef cgImage = context != NULL ? CGBitmapContextCreateImage(context) : NULL;
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    if (context != NULL)
        CGContextRelease(context);
    if (colorSpace != NULL)
        CGColorSpaceRelease(colorSpace);
    if (cgImage == NULL)
        return nil;
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return image;
}


- (void)renderVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (self.usesNativePreview)
    {
        bool recording = false;
        @synchronized (self)
        {
            recording = _recordingStatus == TGVideoCameraRecordingStatusRecording;
        }
        
        if (!recording)
        {
            [self reportFrameStatisticsWithRenderTime:0.0 rendered:false];
            return;
        }
    }
    
	CVPixelBufferRef renderedPixelBuffer = NULL;
	CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CFAbsoluteTime renderStart = CFAbsoluteTimeGetCurrent();
    
	@synchronized (_renderer)
	{
		if (self.renderingEnabled)
        {
            bool repeatingFrames = false;
            @synchronized (self)
            {
                if (_recorder.paused)
                {
                    _recorder.paused = false;
                    if (_previousPixelBuffer != NULL)
                    {
                        _repeatingCount = 11;
                        [_renderer setPreviousPixelBuffer:_previousPixelBuffer];
                        CFRelease(_previousPixelBuffer);
                        _previousPixelBuffer = NULL;
                    }
                }
                
                if (_repeatingCount > 0)
                {
                    repeatingFrames = true;
                    _repeatingCount--;
                }
                
                CGFloat opacity = 1.0f;
                if (_repeatingCount < 10)
                    opacity = _repeatingCount / 9.0f;

                [_renderer setOpacity:opacity];
                
                if (_repeatingCount == 0)
                    [_renderer setPreviousPixelBuffer:NULL];
            }
            
			CVPixelBufferRef sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
			renderedPixelBuffer = [_renderer copyRenderedPixelBuffer:sourcePixelBuffer];
            [self reportFrameStatisticsWithRenderTime:CFAbsoluteTimeGetCurrent() - renderStart rendered:renderedPixelBuffer != NULL];
            
            @synchronized (self)
            {
                if (_recordingStatus == TGVideoCameraRecordingStatusRecording && renderedPixelBuffer != NULL && _recordingThumbnail == nil)
                {
                    UIImage *image = [self imageFromImageBuffer:renderedPixelBuffer];
                    _recordingThumbnail = image;
                }
                
                if (_recordingStatus == TGVideoCameraRecordingStatusRecording && renderedPixelBuffer != NULL && !repeatingFrames)
                {
                    NSTimeInterval currentTime = CMTimeGetSeconds(timestamp);
                    if (_previousThumbnailTime < DBL_EPSILON)
                    {
                        _firstThumbnailTime = currentTime;
                        _previousThumbnailTime = currentTime;
                        
                        [self storeThumbnailWithPixelBuffer:renderedPixelBuffer time:0.0];
                    }
                    else
                    {
                        NSTimeInterval relativeThumbnailTime = _previousThumbnailTime - _firstThumbnailTime;
                        NSTimeInterval interval = MAX(0.1, relativeThumbnailTime / 10.0);
                        
                        if (currentTime - _previousThumbnailTime >= interval)
                        {
                            [self storeThumbnailWithPixelBuffer:renderedPixelBuffer time:relativeThumbnailTime];
                            _previousThumbnailTime = currentTime;
                        }
                    }
                }
                
                if (!repeatingFrames)
                {
                    if (_previousPixelBuffer != NULL)
                    {
                        CFRelease(_previousPixelBuffer);
                        _previousPixelBuffer = NULL;
                    }
                    
                    _previousPixelBuffer = sourcePixelBuffer;
                    CFRetain(sourcePixelBuffer);
                }
            }
		}
		else
        {
			return;
		}
	}
	
	if (renderedPixelBuffer)
	{
        _failedRenderFrameCount = 0;
		@synchronized (self)
		{
            if (!self.usesNativePreview)
			    [self outputPreviewPixelBuffer:renderedPixelBuffer];
            
			if (_recordingStatus == TGVideoCameraRecordingStatusRecording)
				[_recorder appendVideoPixelBuffer:renderedPixelBuffer withPresentationTime:timestamp];
		}
		
		CFRelease(renderedPixelBuffer);
	}
	else
	{
		[self videoPipelineDidRunOutOfBuffers];
        _failedRenderFrameCount++;
        if (_failedRenderFrameCount >= (NSUInteger)TGVideoCameraPipelineFrameRate() && !_videoPipelineFailed)
        {
            _videoPipelineFailed = true;
            [[TGVideoCameraPipeline cameraQueue] dispatch:^{
                [self handleNonRecoverableCaptureSessionRuntimeError:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorInvalidSourceMedia userInfo:@{NSLocalizedFailureReasonErrorKey: @"The capture renderer could not produce video frames."}]];
            }];
        }
	}
}

- (void)outputPreviewPixelBuffer:(CVPixelBufferRef)previewPixelBuffer
{
    if (_currentPreviewPixelBuffer != NULL)
    {
        CFRelease(_currentPreviewPixelBuffer);
        _currentPreviewPixelBuffer = NULL;
    }
    
    _currentPreviewPixelBuffer = previewPixelBuffer;
    CFRetain(_currentPreviewPixelBuffer);
    if (_previewCallbackPending)
        return;
    _previewCallbackPending = true;
    
    [self invokeDelegateCallbackAsync:^
    {
		CVPixelBufferRef currentPreviewPixelBuffer = NULL;
		@synchronized (self)
		{
            _previewCallbackPending = false;
			currentPreviewPixelBuffer = _currentPreviewPixelBuffer;
			if (currentPreviewPixelBuffer != NULL)
            {
				CFRetain(currentPreviewPixelBuffer);
                if (_currentPreviewPixelBuffer != NULL)
                {
                    CFRelease(_currentPreviewPixelBuffer);
                    _currentPreviewPixelBuffer = NULL;
                }
			}
		}
		
		if (currentPreviewPixelBuffer != NULL)
        {
			[_delegate capturePipeline:self previewPixelBufferReadyForDisplay:currentPreviewPixelBuffer];
			CFRelease(currentPreviewPixelBuffer);
		}
	}];
}

- (void)storeThumbnailWithPixelBuffer:(CVPixelBufferRef)imageBuffer time:(NSTimeInterval)time
{
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    size_t cropX = (size_t)((width - height) / 2.0);
    size_t cropY = 0;
    size_t cropWidth = height;
    size_t cropHeight = height;
    size_t outWidth = 66;
    size_t outHeight = 66;

    CVPixelBufferLockBaseAddress(imageBuffer,0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    size_t startPosition = cropY * bytesPerRow + 4 * cropX;
    unsigned char *sourceData = (unsigned char *)baseAddress + startPosition;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreateWithData(NULL, outWidth, outHeight, 8, outWidth * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, NULL, nil);
    
    unsigned char *outImg = CGBitmapContextGetData(context);
    
    bool scaled = TGScaleARGB8888Buffer(sourceData, cropWidth, cropHeight, bytesPerRow, outImg, outWidth, outHeight, outWidth * 4, false);
    if (!scaled)
        TGLegacyLog(@"Video Message thumbnail generation error");
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    
    _thumbnails[@(time)] = image;
}

- (void)startRecordingWhenFormatsAvailable
{
    OSSpinLockLock(&_recordLock);
    bool start = _startRecordAfterFormatBuffer && self.outputVideoFormatDescription != NULL && self.outputAudioFormatDescription != NULL;
    if (start)
        _startRecordAfterFormatBuffer = false;
    OSSpinLockUnlock(&_recordLock);
    if (start)
    {
        [self startRecording:_recordingURL preset:_preset liveUpload:_liveUpload];
    }
}

- (void)startRecording:(NSURL *)url preset:(TGMediaVideoConversionPreset)preset liveUpload:(bool)liveUpload
{
    if (![[TGVideoCameraPipeline cameraQueue] isCurrentQueue])
    {
        [[TGVideoCameraPipeline cameraQueue] dispatch:^{
            [self startRecording:url preset:preset liveUpload:liveUpload];
        }];
        return;
    }
    if (_stopRunningPending || _captureSession == nil || _videoPipelineFailed)
        return;
    _recordingURL = url;
    _preset = preset;
    _liveUpload = liveUpload;
    
    OSSpinLockLock(&_recordLock);
    if (self.outputAudioFormatDescription == NULL || self.outputVideoFormatDescription == NULL)
    {
        _startRecordAfterFormatBuffer = true;
        OSSpinLockUnlock(&_recordLock);
        return;
    }
    OSSpinLockUnlock(&_recordLock);
    [_startupTimer invalidate];
    _startupTimer = nil;
    
	@synchronized (self)
	{
		if (_recordingStatus != TGVideoCameraRecordingStatusIdle)
			return;

        _stopRecordAfterPreparing = false;
		
		[self transitionToRecordingStatus:TGVideoCameraRecordingStatusStartingRecording error:nil];
	}
	
	dispatch_queue_t callbackQueue = dispatch_queue_create("org.telegram.VideoCameraPipeline.recorder", DISPATCH_QUEUE_SERIAL);
	TGVideoCameraMovieRecorder *recorder = [[TGVideoCameraMovieRecorder alloc] initWithURL:_recordingURL delegate:self callbackQueue:callbackQueue];
#if !OS_OBJECT_USE_OBJC
    dispatch_release(callbackQueue);
#endif
	
    NSDictionary *audioSettings = [TGMediaVideoConversionPresetSettings audioSettingsForPreset:preset];
	[recorder addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:audioSettings];

    _videoTransform = [self transformForOrientation:self.orientation];

    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(self.outputVideoFormatDescription);
    CGSize size = CGSizeMake(dimensions.width, dimensions.height);
    NSDictionary *videoSettings = [TGMediaVideoConversionPresetSettings videoSettingsForPreset:preset dimensions:size];
	[recorder addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription transform:CGAffineTransformIdentity settings:videoSettings];
	_recorder = recorder;
	
	[recorder prepareToRecord];
}

- (bool)stopRecordingOnCameraQueue
{
    @synchronized (self)
    {
        if (_recordingStatus == TGVideoCameraRecordingStatusStartingRecording)
        {
            _stopRecordAfterPreparing = true;
            return true;
        }

        if (_recordingStatus == TGVideoCameraRecordingStatusStoppingRecording)
            return true;

        if (_recordingStatus != TGVideoCameraRecordingStatusRecording)
            return false;

        [self transitionToRecordingStatus:TGVideoCameraRecordingStatusStoppingRecording error:nil];
    }

    _resultDuration = _recorder.videoDuration;
    [_recorder finishRecording];
    return true;
}

- (void)stopRecording
{
    OSSpinLockLock(&_recordLock);
    _startRecordAfterFormatBuffer = false;
    OSSpinLockUnlock(&_recordLock);

    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        [self stopRecordingOnCameraQueue];
    }];
}

- (bool)isRecording
{
    return _recorder != nil && !_recorder.paused;
}

- (void)movieRecorderDidFinishPreparing:(TGVideoCameraMovieRecorder *)__unused recorder
{
	bool stopAfterPreparing = false;
	@synchronized (self)
	{
		if (_recordingStatus != TGVideoCameraRecordingStatusStartingRecording)
			return;
		
		[self transitionToRecordingStatus:TGVideoCameraRecordingStatusRecording error:nil];
        stopAfterPreparing = _stopRecordAfterPreparing;
        _stopRecordAfterPreparing = false;
        
        if (_liveUpload)
        {
            _watcher = _liveUploadInterface;
            [_watcher setupWithFileURL:_recordingURL];
        }
	}

    if (stopAfterPreparing)
    {
        [self stopRecording];
    }
}

- (void)movieRecorder:(TGVideoCameraMovieRecorder *)__unused recorder didFailWithError:(NSError *)error
{
	@synchronized (self)
	{
		_stopRecordAfterPreparing = false;
		_recorder = nil;
		[self transitionToRecordingStatus:TGVideoCameraRecordingStatusIdle error:error];
	}

    if (_stopRunningPending)
    {
        [[TGVideoCameraPipeline cameraQueue] dispatch:^
        {
            [self finishStoppingCaptureSession];
        }];
    }
}

- (void)movieRecorderDidFinishRecording:(TGVideoCameraMovieRecorder *)__unused recorder
{
	@synchronized (self)
	{
		if (_recordingStatus != TGVideoCameraRecordingStatusStoppingRecording)
            return;
	}
	
	_recorder = nil;
    _stopRecordAfterPreparing = false;
    
    if (_watcher != nil)
        _liveUploadData = [_watcher fileUpdated:true];
    
    [self transitionToRecordingStatus:TGVideoCameraRecordingStatusIdle error:nil];

    if (_stopRunningPending)
    {
        [[TGVideoCameraPipeline cameraQueue] dispatch:^
        {
            [self finishStoppingCaptureSession];
        }];
    }
}

- (void)transitionToRecordingStatus:(TGVideoCameraRecordingStatus)newStatus error:(NSError *)error
{
	TGVideoCameraRecordingStatus oldStatus = _recordingStatus;
	_recordingStatus = newStatus;
    TGLegacyLog(@"VIDEOMESSAGE recording status %d -> %d after %.0fms error=%@", (int)oldStatus, (int)newStatus, (CFAbsoluteTimeGetCurrent() - _startRunningTime) * 1000.0, error);
    
	if (newStatus != oldStatus)
	{
		dispatch_block_t delegateCallbackBlock = nil;
		
		if (error && newStatus == TGVideoCameraRecordingStatusIdle)
		{
			delegateCallbackBlock = ^{ [_delegate capturePipeline:self recordingDidFailWithError:error]; };
		}
		else
		{
			if ((oldStatus == TGVideoCameraRecordingStatusStartingRecording) && (newStatus == TGVideoCameraRecordingStatusRecording))
				delegateCallbackBlock = ^{ [_delegate capturePipelineRecordingDidStart:self]; };
			else if ((oldStatus == TGVideoCameraRecordingStatusRecording) && (newStatus == TGVideoCameraRecordingStatusStoppingRecording))
				delegateCallbackBlock = ^{ [_delegate capturePipelineRecordingWillStop:self]; };
			else if ((oldStatus == TGVideoCameraRecordingStatusStoppingRecording) && (newStatus == TGVideoCameraRecordingStatusIdle))
				delegateCallbackBlock = ^{ [_delegate capturePipelineRecordingDidStop:self duration:_resultDuration liveUploadData:_liveUploadData thumbnailImage:_recordingThumbnail thumbnails:_thumbnails]; };
		}
		
		if (delegateCallbackBlock != nil)
			[self invokeDelegateCallbackAsync:delegateCallbackBlock];
	}
}

- (void)invokeDelegateCallbackAsync:(dispatch_block_t)callbackBlock
{
	dispatch_async(_delegateCallbackQueue, ^
    {
		@autoreleasepool
        {
			callbackBlock();
		}
	});
}

- (CGAffineTransform)transformForOrientation:(AVCaptureVideoOrientation)orientation
{
	CGAffineTransform transform = CGAffineTransformIdentity;
		
	CGFloat orientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(orientation);
	CGFloat videoOrientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(_videoBufferOrientation);
	
	CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
	transform = CGAffineTransformMakeRotation(angleOffset);
    
	return transform;
}

static CGFloat angleOffsetFromPortraitOrientationToOrientation(AVCaptureVideoOrientation orientation)
{
	CGFloat angle = 0.0;
	
	switch (orientation)
	{
        case AVCaptureVideoOrientationPortrait:
            angle = 0.0;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            angle = -M_PI_2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
        default:
            break;
	}
	
	return angle;
}

- (NSTimeInterval)videoDuration
{
    return _recorder.videoDuration;
}

- (void)setCameraPosition:(AVCaptureDevicePosition)position
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        if (!_running || _stopRunningPending)
            return;
        AVCaptureDevice *deviceForTargetPosition = nil;
        for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
        {
            if (device.position == position)
            {
                deviceForTargetPosition = device;
                break;
            }
        }
        NSError *error = nil;
        AVCaptureDeviceInput *newVideoInput = deviceForTargetPosition == nil ? nil : [[AVCaptureDeviceInput alloc] initWithDevice:deviceForTargetPosition error:&error];
        if (newVideoInput == nil)
        {
            [self handleNonRecoverableCaptureSessionRuntimeError:error ?: [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorDeviceNotConnected userInfo:nil]];
            return;
        }
        [_videoOutput setSampleBufferDelegate:nil queue:NULL];
        [_audioOutput setSampleBufferDelegate:nil queue:NULL];
        dispatch_sync(_videoDataOutputQueue, ^{});
        dispatch_sync(_audioDataOutputQueue, ^{});
        @synchronized (self)
        {
            _recorder.paused = true;
        }
        [_captureSession beginConfiguration];
        [_captureSession removeInput:_videoInput];
        bool added = [_captureSession canAddInput:newVideoInput];
        if (added)
        {
            [_captureSession addInput:newVideoInput];
            _videoInput = newVideoInput;
            _videoDevice = deviceForTargetPosition;
            _captureSession.sessionPreset = TGVideoCameraPipelineSessionPreset(_captureSession);
        }
        else
            [_captureSession addInput:_videoInput];
        [_captureSession commitConfiguration];
        if (!added)
        {
            [self handleNonRecoverableCaptureSessionRuntimeError:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedFailureReasonErrorKey: @"The capture session rejected the selected camera input."}]];
            return;
        }
        @synchronized (_renderer)
        {
            _renderer.mirror = _videoDevice.position == AVCaptureDevicePositionFront;
            _renderer.orientation = _orientation;
        }
        _videoConnection = TGAVCaptureConnectionWithMediaType(_videoOutput, AVMediaTypeVideo);
        [self _configureFPS];
        [self _enableLowLightBoost];
        [self _enableVideoStabilization];
        _videoBufferOrientation = _videoConnection.videoOrientation;
        [_videoOutput setSampleBufferDelegate:self queue:_videoDataOutputQueue];
        [_audioOutput setSampleBufferDelegate:self queue:_audioDataOutputQueue];
    }];
}


- (void)_enableLowLightBoost
{
    [self _reconfigureDevice:_videoDevice withBlock:^(AVCaptureDevice *device)
    {
        if ([device respondsToSelector:@selector(isLowLightBoostSupported)] && [device isLowLightBoostSupported] && [device respondsToSelector:@selector(setAutomaticallyEnablesLowLightBoostWhenAvailable:)])
            [device setAutomaticallyEnablesLowLightBoostWhenAvailable:true];
    }];
}

- (void)_enableVideoStabilization
{
    AVCaptureConnection *videoConnection = TGAVCaptureConnectionWithMediaType(_videoOutput, AVMediaTypeVideo);
    if (videoConnection == nil)
        return;

    SEL supportedModeSelector = NSSelectorFromString(@"isVideoStabilizationModeSupported:");
    SEL preferredModeSelector = NSSelectorFromString(@"setPreferredVideoStabilizationMode:");
    bool stabilizationConfigured = false;
    if ([videoConnection respondsToSelector:supportedModeSelector] && [videoConnection respondsToSelector:preferredModeSelector])
    {
        BOOL (*isModeSupported)(id, SEL, NSInteger) = (BOOL (*)(id, SEL, NSInteger))[videoConnection methodForSelector:supportedModeSelector];
        void (*setPreferredMode)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))[videoConnection methodForSelector:preferredModeSelector];
        if (isModeSupported(videoConnection, supportedModeSelector, 1))
        {
            setPreferredMode(videoConnection, preferredModeSelector, 1);
            stabilizationConfigured = true;
        }
    }
    if (!stabilizationConfigured && [videoConnection respondsToSelector:@selector(isVideoStabilizationSupported)] && [videoConnection isVideoStabilizationSupported] && [videoConnection respondsToSelector:@selector(setEnablesVideoStabilizationWhenAvailable:)])
    {
        [videoConnection setEnablesVideoStabilizationWhenAvailable:true];
    }
}

- (void)_reconfigureDevice:(AVCaptureDevice *)device withBlock:(void (^)(AVCaptureDevice *device))block
{
    if (block == nil)
        return;
    
    NSError *error = nil;
    if (![device lockForConfiguration:&error])
    {
        TGLegacyLog(@"ERROR: failed to reconfigure camera: %@", error);
        return;
    }
    block(device);
    [device unlockForConfiguration];
    
    if (error != nil)
        TGLegacyLog(@"ERROR: failed to reconfigure camera: %@", error);
}

- (bool)addAudioInputWithError:(NSError **)error
{
    if (_audioInput != nil && _audioOutput != nil)
        return true;
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *inputError = nil;
    AVCaptureDeviceInput *audioInput = audioDevice == nil ? nil : [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&inputError];
    if (audioInput == nil || ![_captureSession canAddInput:audioInput])
    {
        if (error != NULL)
            *error = inputError ?: [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorDeviceNotConnected userInfo:@{NSLocalizedFailureReasonErrorKey: @"The capture session could not connect its microphone input."}];
        return false;
    }
    [_captureSession addInput:audioInput];
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    if (![_captureSession canAddOutput:audioOutput])
    {
        [_captureSession removeInput:audioInput];
        if (error != NULL)
            *error = [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedFailureReasonErrorKey: @"The capture session rejected its audio data output."}];
        return false;
    }
    [_captureSession addOutput:audioOutput];
    _audioDevice = audioDevice;
    _audioInput = audioInput;
    _audioOutput = audioOutput;
    [audioOutput setSampleBufferDelegate:self queue:_audioDataOutputQueue];
    return true;
}

- (void)startAudioCaptureAfterVideo
{
    if (!_running || _captureSession == nil || _stopRunningPending || _captureFailureReported || _audioInput != nil)
        return;
    [self startStartupTimerForPhase:@"audio"];
    [_captureSession beginConfiguration];
    NSError *error = nil;
    bool added = [self addAudioInputWithError:&error];
    [_captureSession commitConfiguration];
    if (!added)
    {
        [self handleNonRecoverableCaptureSessionRuntimeError:error];
        return;
    }
    _audioConnection = TGAVCaptureConnectionWithMediaType(_audioOutput, AVMediaTypeAudio);
    _videoConnection = TGAVCaptureConnectionWithMediaType(_videoOutput, AVMediaTypeVideo);
    if (_audioConnection == nil || !_audioConnection.enabled)
    {
        [self handleNonRecoverableCaptureSessionRuntimeError:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedFailureReasonErrorKey: @"The capture session did not create an enabled microphone connection."}]];
        return;
    }
    [self _configureFPS];
    _videoBufferOrientation = _videoConnection.videoOrientation;
}

- (void)_removeAudioInput
{
    if (_audioDevice == nil)
        return;
    
    [_captureSession removeInput:_audioInput];
    _audioInput = nil;
    
    [_audioOutput setSampleBufferDelegate:nil queue:NULL];
    [_captureSession removeOutput:_audioOutput];
    _audioOutput = nil;
    
    _audioDevice = nil;
}

- (void)_configureFPS
{
    if (iosMajorVersion() < 7)
        return;
    CMTime frameDuration = CMTimeMake(1, TGVideoCameraPipelineFrameRate());
    bool configuredDevice = false;

    if ([_videoDevice respondsToSelector:NSSelectorFromString(@"setActiveVideoMaxFrameDuration:")] && [_videoDevice respondsToSelector:NSSelectorFromString(@"setActiveVideoMinFrameDuration:")])
    {
        configuredDevice = true;
        [self _reconfigureDevice:_videoDevice withBlock:^(AVCaptureDevice *device)
        {
            [device setValue:[NSValue valueWithCMTime:frameDuration] forKey:@"activeVideoMaxFrameDuration"];
            [device setValue:[NSValue valueWithCMTime:frameDuration] forKey:@"activeVideoMinFrameDuration"];
        }];
    }

    if (!configuredDevice && [_videoConnection respondsToSelector:@selector(setVideoMinFrameDuration:)] && _videoConnection.supportsVideoMinFrameDuration)
    {
        configuredDevice = true;
        _videoConnection.videoMinFrameDuration = frameDuration;
        if ([_videoConnection respondsToSelector:@selector(setVideoMaxFrameDuration:)] && _videoConnection.supportsVideoMaxFrameDuration)
            _videoConnection.videoMaxFrameDuration = kCMTimeInvalid;
    }

    if (!configuredDevice && [_videoOutput respondsToSelector:@selector(setMinFrameDuration:)])
        _videoOutput.minFrameDuration = frameDuration;
}

+ (bool)cameraPositionChangeAvailable
{
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1;
}

+ (id<TGVideoCameraSessionExecuting> )cameraQueue
{
    static dispatch_once_t onceToken;
    static id<TGVideoCameraSessionExecuting> queue = nil;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() < 7)
            queue = [[TGVideoCameraRunLoopExecutor alloc] init];
        else
            queue = [[TGVideoCameraDispatchExecutor alloc] init];
    });
    
    return queue;
}

@end
