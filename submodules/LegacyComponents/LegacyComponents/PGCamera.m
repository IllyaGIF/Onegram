#import "PGCamera.h"
#import "OGPlatformMedia.h"

#import "LegacyComponentsInternal.h"

#import "PGCameraCaptureSession.h"
#import "PGCameraMovieWriter.h"
#import "PGCameraDeviceAngleSampler.h"

#import "SSignalKitCompat/SSignalKit.h"

#import "TGCameraPreviewView.h"

NSString *const PGCameraFlashActiveKey = @"flashActive";
NSString *const PGCameraFlashAvailableKey = @"flashAvailable";
NSString *const PGCameraTorchActiveKey = @"torchActive";
NSString *const PGCameraTorchAvailableKey = @"torchAvailable";
NSString *const PGCameraAdjustingFocusKey = @"adjustingFocus";

@interface PGCamera ()
{
    dispatch_queue_t cameraProcessingQueue;
    dispatch_queue_t audioProcessingQueue;
    
    AVCaptureDevice *_microphone;
    AVCaptureVideoDataOutput *videoOutput;
    AVCaptureAudioDataOutput *audioOutput;
    
    PGCameraDeviceAngleSampler *_deviceAngleSampler;
    
    bool _subscribedForCameraChanges;
    
    bool _invalidated;
    bool _wasCapturingOnEnterBackground;
    
    bool _capturing;
    bool _moment;
    
    TGCameraPreviewView *_previewView;
    
    NSTimeInterval _captureStartTime;
}
@end

@implementation PGCamera

- (instancetype)init
{
    return [self initWithMode:PGCameraModePhoto position:PGCameraPositionUndefined];
}

- (instancetype)initWithMode:(PGCameraMode)mode position:(PGCameraPosition)position
{
    self = [super init];
    if (self != nil)
    {
        _captureSession = [[PGCameraCaptureSession alloc] initWithMode:mode position:position];
        _deviceAngleSampler = [[PGCameraDeviceAngleSampler alloc] init];
        [_deviceAngleSampler startMeasuring];
        
        __weak PGCamera *weakSelf = self;
        self.captureSession.requestPreviewIsMirrored = ^bool
        {
            __strong PGCamera *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_previewView == nil)
                return false;
#if defined(ONEGRAM_ARMV6)
            return false;
#else
            TGCameraPreviewView *previewView = strongSelf->_previewView;
            return OGPlatformCaptureConnectionIsVideoMirrored(previewView.captureConnection);
#endif
        };
#if !defined(ONEGRAM_ARMV6)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleEnteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:nil];
#endif
    }
    return self;
}

- (void)dealloc
{
    [_deviceAngleSampler stopMeasuring];
    [self _unsubscribeFromCameraChanges];
    
    self.captureSession.requestPreviewIsMirrored = nil;
    
#if !defined(ONEGRAM_ARMV6)
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:nil];
#endif
}

- (void)handleEnteredBackground:(NSNotification *)__unused notification
{
    if (self.isCapturing)
        _wasCapturingOnEnterBackground = true;
    
    [self stopCaptureForPause:true completion:nil];
}

- (void)handleEnteredForeground:(NSNotification *)__unused notification
{
    if (_wasCapturingOnEnterBackground)
    {
        _wasCapturingOnEnterBackground = false;
        [self startCaptureForResume:true completion:nil];
    }
}

- (void)handleRuntimeError:(NSNotification *)notification
{
#if !defined(ONEGRAM_ARMV6)
    TGLegacyLog(@"ERROR: Camera runtime error: %@", notification.userInfo[AVCaptureSessionErrorKey]);

    __weak PGCamera *weakSelf = self;
    TGDispatchAfter(1.5f, (dispatch_queue_t)[[PGCamera cameraQueue] _dispatch_queueRaw], ^
    {
        __strong PGCamera *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_invalidated)
            return;
        
        [strongSelf _unsubscribeFromCameraChanges];
        
        for (AVCaptureInput *input in strongSelf.captureSession.inputs)
            [strongSelf.captureSession removeInput:input];
        for (AVCaptureOutput *output in strongSelf.captureSession.outputs)
            [strongSelf.captureSession removeOutput:output];
        
        [strongSelf.captureSession performInitialConfigurationWithCompletion:^
        {
            __strong PGCamera *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf _subscribeForCameraChanges];
        }];
    });
#else
    (void)notification;
#endif
}

- (void)handleInterrupted:(NSNotification *)notification
{
#if !defined(ONEGRAM_ARMV6)
    if (iosMajorVersion() < 9)
        return;
    
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    TGLegacyLog(@"WARNING: Camera was interrupted with reason %d", reason);
    if (self.captureInterrupted != nil)
        self.captureInterrupted(reason);
#else
    (void)notification;
#endif
}

- (void)_subscribeForCameraChanges
{
    if (_subscribedForCameraChanges)
        return;

    _subscribedForCameraChanges = true;
#if !defined(ONEGRAM_ARMV6)
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraFlashActiveKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraFlashAvailableKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraTorchActiveKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraTorchAvailableKey options:NSKeyValueObservingOptionNew context:NULL];
    [self.captureSession.videoDevice addObserver:self forKeyPath:PGCameraAdjustingFocusKey options:NSKeyValueObservingOptionNew context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaChanged:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.captureSession.videoDevice];
#endif
}

- (void)_unsubscribeFromCameraChanges
{
    if (!_subscribedForCameraChanges)
        return;

    _subscribedForCameraChanges = false;
#if !defined(ONEGRAM_ARMV6)
    @try {
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraFlashActiveKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraFlashAvailableKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraTorchActiveKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraTorchAvailableKey];
        [self.captureSession.videoDevice removeObserver:self forKeyPath:PGCameraAdjustingFocusKey];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.captureSession.videoDevice];
    } @catch(NSException *e) { }
#endif
}

- (void)attachPreviewView:(TGCameraPreviewView *)previewView
{
    TGCameraPreviewView *currentPreviewView = _previewView;
    if (currentPreviewView != nil)
        [currentPreviewView invalidate];
    
    _previewView = previewView;
    [previewView setupWithCamera:self];

    __weak PGCamera *weakSelf = self;
    [[PGCamera cameraQueue] dispatch:^
    {
        __strong PGCamera *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf->_invalidated)
            return;

        [strongSelf.captureSession performInitialConfigurationWithCompletion:^
        {
            __strong PGCamera *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf _subscribeForCameraChanges];
        }];
    }];
}

#pragma mark -

- (bool)isCapturing
{
    return _capturing;
}

- (void)startCaptureForResume:(bool)resume completion:(void (^)(void))completion
{
    if (_invalidated)
        return;
    
    [[PGCamera cameraQueue] dispatch:^
    {
        if (self.captureSession.isRunning)
            return;
        
        _capturing = true;
        
#if !TARGET_IPHONE_SIMULATOR
        [self.captureSession startRunning];
#endif
        
        if (_captureStartTime < FLT_EPSILON)
            _captureStartTime = CFAbsoluteTimeGetCurrent();

        TGDispatchOnMainThread(^
        {
            if (self.captureStarted != nil)
                self.captureStarted(resume);
            
            if (completion != nil)
                completion();
        });
    }];
}

- (void)stopCaptureForPause:(bool)pause completion:(void (^)(void))completion
{
    if (_invalidated)
        return;
    
    if (!pause)
        _invalidated = true;
    
    
    [[PGCamera cameraQueue] dispatch:^
    {
        if (_invalidated)
        {
            [self.captureSession beginConfiguration];
            
            [self.captureSession resetFlashMode];
            
            TGLegacyLog(@"Camera: stop capture invalidated");
            TGCameraPreviewView *previewView = _previewView;
            if (previewView != nil)
                [previewView invalidate];
            
#if !defined(ONEGRAM_ARMV6)
            for (AVCaptureInput *input in self.captureSession.inputs)
                [self.captureSession removeInput:input];
            for (AVCaptureOutput *output in self.captureSession.outputs)
                [self.captureSession removeOutput:output];
#endif
            
#if !TARGET_IPHONE_SIMULATOR
            [self.captureSession commitConfiguration];
#endif
        }
        
#if !TARGET_IPHONE_SIMULATOR
        [self.captureSession stopRunning];
#endif
        
        _capturing = false;
        
        TGDispatchOnMainThread(^
        {
            if (_invalidated)
                _previewView = nil;
            
            if (self.captureStopped != nil)
                self.captureStopped(pause);
        });
        
        if (completion != nil)
            completion();
    }];
}

- (bool)isResetNeeded
{
    return self.captureSession.isResetNeeded;
}

- (void)resetSynchronous:(bool)synchronous completion:(void (^)(void))completion
{
    [self resetTerminal:false synchronous:synchronous completion:completion];
}

- (void)resetTerminal:(bool)__unused terminal synchronous:(bool)synchronous completion:(void (^)(void))completion
{
    void (^block)(void) = ^
    {
        [self _unsubscribeFromCameraChanges];
        [self.captureSession reset];
        [self _subscribeForCameraChanges];
        
        if (completion != nil)
            completion();
    };
    
    if (synchronous)
        [[PGCamera cameraQueue] dispatchSync:block];
    else
        [[PGCamera cameraQueue] dispatch:block];
}

#pragma mark - 

- (void)captureNextFrameCompletion:(void (^)(UIImage * image))completion
{
    [self.captureSession captureNextFrameCompletion:completion];
}

- (UIImage *)normalizeImageOrientation:(UIImage *)image
{
    if (image.imageOrientation == UIImageOrientationUp) {
        return image;
    }
    
    CGRect newRect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    
    UIGraphicsBeginImageContextWithOptions(newRect.size, true, image.scale);
    [image drawInRect:newRect];
    
    UIImage *normalized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return normalized;
}

- (void)takePhotoWithCompletion:(void (^)(UIImage *result, PGCameraShotMetadata *metadata))completion
{
#if defined(ONEGRAM_ARMV6)
    [self captureNextFrameCompletion:^(UIImage *image)
    {
        if (image == nil)
            return;
        PGCameraShotMetadata *metadata = [[PGCameraShotMetadata alloc] init];
        UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
        if (self.requestedCurrentInterfaceOrientation != nil)
            orientation = self.requestedCurrentInterfaceOrientation(NULL);
        metadata.deviceAngle = [PGCameraShotMetadata relativeDeviceAngleFromAngle:_deviceAngleSampler.currentDeviceAngle orientation:orientation];
        if (completion != nil)
            completion([self normalizeImageOrientation:image], metadata);
    }];
#else
    bool videoMirrored = !self.disableResultMirroring ? OGPlatformCaptureConnectionIsVideoMirrored(_previewView.captureConnection) : false;
    
    [[PGCamera cameraQueue] dispatch:^
    {
        if (!self.captureSession.isRunning || self.captureSession.imageOutput.isCapturingStillImage || _invalidated)
            return;
        
        void (^takePhoto)(void) = ^
        {
            AVCaptureConnection *imageConnection = TGAVCaptureConnectionWithMediaType(self.captureSession.imageOutput, AVMediaTypeVideo);
            OGPlatformSetCaptureConnectionVideoMirrored(imageConnection, videoMirrored);
            
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            if (self.requestedCurrentInterfaceOrientation != nil)
                orientation = self.requestedCurrentInterfaceOrientation(NULL);
            
            [imageConnection setVideoOrientation:[PGCamera _videoOrientationForInterfaceOrientation:orientation mirrored:false]];
            
            [self.captureSession.imageOutput captureStillImageAsynchronouslyFromConnection:self.captureSession.imageOutput.connections.firstObject completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
            {
                if (imageDataSampleBuffer != NULL && error == nil)
                {
                    NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    UIImage *image = [[UIImage alloc] initWithData:imageData];
                    
                    if (self.cameraMode == PGCameraModeSquare)
                    {
                        CGFloat shorterSide = MIN(image.size.width, image.size.height);
                        CGFloat longerSide = MAX(image.size.width, image.size.height);
                        
                        CGRect cropRect = CGRectMake(CGFloor((longerSide - shorterSide) / 2.0f), 0, shorterSide, shorterSide);
                        CGImageRef croppedCGImage = CGImageCreateWithImageInRect(image.CGImage, cropRect);
                        image = [UIImage imageWithCGImage:croppedCGImage scale:image.scale orientation:image.imageOrientation];
                        CGImageRelease(croppedCGImage);
                    }
                    
                    PGCameraShotMetadata *metadata = [[PGCameraShotMetadata alloc] init];
                    metadata.deviceAngle = [PGCameraShotMetadata relativeDeviceAngleFromAngle:_deviceAngleSampler.currentDeviceAngle orientation:orientation];
                    
                    image = [self normalizeImageOrientation:image];
                    
                    if (completion != nil)
                        completion(image, metadata);
                }
            }];
        };
        
        NSTimeInterval delta = CFAbsoluteTimeGetCurrent() - _captureStartTime;
        if (CFAbsoluteTimeGetCurrent() - _captureStartTime > 0.4)
            takePhoto();
        else
            TGDispatchAfter(0.4 - delta, (dispatch_queue_t)[[PGCamera cameraQueue] _dispatch_queueRaw], takePhoto);
    }];
#endif
}

- (void)startVideoRecordingForMoment:(bool)moment completion:(void (^)(NSURL *, CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success))completion
{
    [[PGCamera cameraQueue] dispatch:^
    {
        if (!self.captureSession.isRunning || _invalidated)
            return;
        
        void (^startRecording)(void) = ^
        {
            UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
            bool mirrored = false;
            
            if (self.requestedCurrentInterfaceOrientation != nil)
                orientation = self.requestedCurrentInterfaceOrientation(&mirrored);
            
            _moment = moment;
            
            [self.captureSession startVideoRecordingWithOrientation:[PGCamera _videoOrientationForInterfaceOrientation:orientation mirrored:mirrored] mirrored:mirrored completion:completion];
            
            TGDispatchOnMainThread(^
            {
                if (self.reallyBeganVideoRecording != nil)
                    self.reallyBeganVideoRecording(moment);
            });
        };
        
        NSTimeInterval delta = CFAbsoluteTimeGetCurrent() - _captureStartTime;
        if (CFAbsoluteTimeGetCurrent() - _captureStartTime > 0.8)
            startRecording();
        else
            TGDispatchAfter(0.8 - delta, (dispatch_queue_t)[[PGCamera cameraQueue] _dispatch_queueRaw], startRecording);
        
        TGDispatchOnMainThread(^
        {
            if (self.beganVideoRecording != nil)
                self.beganVideoRecording(moment);
        });
    }];
}

- (void)stopVideoRecording
{
    [[PGCamera cameraQueue] dispatch:^
    {
        [self.captureSession stopVideoRecording];
        
        TGDispatchOnMainThread(^
        {
            if (self.finishedVideoRecording != nil)
                self.finishedVideoRecording(_moment);
        });
    }];
}

- (bool)isRecordingVideo
{
    return self.captureSession.movieWriter.isRecording;
}

- (NSTimeInterval)videoRecordingDuration
{
    return self.captureSession.movieWriter.currentDuration;
}

#pragma mark - Mode

- (PGCameraMode)cameraMode
{
    return self.captureSession.currentMode;
}

- (void)setCameraMode:(PGCameraMode)cameraMode
{
    if (self.disabled || self.captureSession.currentMode == cameraMode)
        return;
    
    __weak PGCamera *weakSelf = self;
    void(^commitBlock)(void) = ^
    {
        __strong PGCamera *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [[PGCamera cameraQueue] dispatch:^
        {
            strongSelf.captureSession.currentMode = cameraMode;
             
            if (strongSelf.finishedModeChange != nil)
                strongSelf.finishedModeChange();
            
            if (strongSelf.autoStartVideoRecording && strongSelf.onAutoStartVideoRecording != nil)
            {
                TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
                {
                    strongSelf.onAutoStartVideoRecording();                    
                });
            }
            
            strongSelf.autoStartVideoRecording = false;
        }];
    };
    
    if (self.beganModeChange != nil)
        self.beganModeChange(cameraMode, commitBlock);
}

#pragma mark - Focus and Exposure

- (void)subjectAreaChanged:(NSNotification *)__unused notification
{
    [self resetFocusPoint];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)__unused object change:(NSDictionary *)__unused change context:(void *)__unused context
{
    TGDispatchOnMainThread(^
    {
        if ([keyPath isEqualToString:PGCameraAdjustingFocusKey])
        {
            bool adjustingFocus = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
            
            if (adjustingFocus && self.beganAdjustingFocus != nil)
                self.beganAdjustingFocus();
            else if (!adjustingFocus && self.finishedAdjustingFocus != nil)
                self.finishedAdjustingFocus();
        }
        else if ([keyPath isEqualToString:PGCameraFlashActiveKey] || [keyPath isEqualToString:PGCameraTorchActiveKey])
        {
            bool active = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
            
            if (self.flashActivityChanged != nil)
                self.flashActivityChanged(active);
        }
        else if ([keyPath isEqualToString:PGCameraFlashAvailableKey] || [keyPath isEqualToString:PGCameraTorchAvailableKey])
        {
            bool available = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
            
            if (self.flashAvailabilityChanged != nil)
                self.flashAvailabilityChanged(available);
        }
    });
}

- (bool)supportsExposurePOI
{
#if defined(ONEGRAM_ARMV6)
    return false;
#else
    return [self.captureSession.videoDevice isExposurePointOfInterestSupported];
#endif
}

- (bool)supportsFocusPOI
{
#if defined(ONEGRAM_ARMV6)
    return false;
#else
    return [self.captureSession.videoDevice isFocusPointOfInterestSupported];
#endif
}

- (void)resetFocusPoint
{
    const CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    [self _setFocusPoint:centerPoint focusMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeContinuousAutoExposure monitorSubjectAreaChange:false];
}

- (void)setFocusPoint:(CGPoint)point
{
    [self _setFocusPoint:point focusMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose monitorSubjectAreaChange:true];
}

- (void)_setFocusPoint:(CGPoint)point focusMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode monitorSubjectAreaChange:(bool)monitorSubjectAreaChange
{
    [[PGCamera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setFocusPoint:point focusMode:focusMode exposureMode:exposureMode monitorSubjectAreaChange:monitorSubjectAreaChange];
    }];
}

- (bool)supportsExposureTargetBias
{
#if defined(ONEGRAM_ARMV6)
    return false;
#else
    return [self.captureSession.videoDevice respondsToSelector:NSSelectorFromString(@"setExposureTargetBias:completionHandler:")];
#endif
}

- (void)beginExposureTargetBiasChange
{
    [[PGCamera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setFocusPoint:self.captureSession.focusPoint focusMode:AVCaptureFocusModeLocked exposureMode:AVCaptureExposureModeLocked monitorSubjectAreaChange:false];
    }];
}

- (void)setExposureTargetBias:(CGFloat)bias
{
    [[PGCamera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setExposureTargetBias:bias];
    }];
}

- (void)endExposureTargetBiasChange
{
    [[PGCamera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setFocusPoint:self.captureSession.focusPoint focusMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose monitorSubjectAreaChange:true];
    }];
}

#pragma mark - Flash

- (bool)hasFlash
{
#if defined(ONEGRAM_ARMV6)
    return false;
#else
    return self.captureSession.videoDevice.hasFlash;
#endif
}

- (bool)flashActive
{
#if defined(ONEGRAM_ARMV6)
    return false;
#else
    if (self.cameraMode == PGCameraModeVideo || self.cameraMode == PGCameraModeClip)
        return self.captureSession.videoDevice.torchActive;
    return self.captureSession.videoDevice.flashActive;
#endif
}

- (bool)flashAvailable
{
#if defined(ONEGRAM_ARMV6)
    return false;
#else
    if (self.cameraMode == PGCameraModeVideo || self.cameraMode == PGCameraModeClip)
        return self.captureSession.videoDevice.torchAvailable;
    return self.captureSession.videoDevice.flashAvailable;
#endif
}

- (PGCameraFlashMode)flashMode
{
    return self.captureSession.currentFlashMode;
}

- (void)setFlashMode:(PGCameraFlashMode)flashMode
{
    [[PGCamera cameraQueue] dispatch:^
    {
        self.captureSession.currentFlashMode = flashMode;
    }];
}

#pragma mark - Position

- (PGCameraPosition)togglePosition
{
#if defined(ONEGRAM_ARMV6)
    if (![PGCamera hasFrontCamera] || self.disabled)
        return self.captureSession.currentCameraPosition;
    PGCameraPosition targetCameraPosition = self.captureSession.currentCameraPosition == PGCameraPositionFront ? PGCameraPositionRear : PGCameraPositionFront;
    void (^commitBlock)(void) = ^
    {
        self.captureSession.currentCameraPosition = targetCameraPosition;
        if (self.finishedPositionChange != nil)
            self.finishedPositionChange();
    };
    if (self.beganPositionChange != nil)
        self.beganPositionChange(false, false, commitBlock);
    return targetCameraPosition;
#else
    if ([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count < 2 || self.disabled)
        return self.captureSession.currentCameraPosition;
    
    [self _unsubscribeFromCameraChanges];
    
    PGCameraPosition targetCameraPosition = PGCameraPositionFront;
    if (self.captureSession.currentCameraPosition == PGCameraPositionFront)
        targetCameraPosition = PGCameraPositionRear;
    
    AVCaptureDevice *targetDevice = [PGCameraCaptureSession _deviceWithCameraPosition:targetCameraPosition];
    
    __weak PGCamera *weakSelf = self;
    void(^commitBlock)(void) = ^
    {
        __strong PGCamera *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [[PGCamera cameraQueue] dispatch:^
        {
            [strongSelf.captureSession setCurrentCameraPosition:targetCameraPosition];
             
            if (strongSelf.finishedPositionChange != nil)
                strongSelf.finishedPositionChange();
             
            [strongSelf setZoomLevel:0.0f];
            [strongSelf _subscribeForCameraChanges];
        }];
    };
    
    if (self.beganPositionChange != nil)
        self.beganPositionChange(targetDevice.hasFlash, [PGCameraCaptureSession _isZoomAvailableForDevice:targetDevice], commitBlock);
    
    return targetCameraPosition;
#endif
}

#pragma mark - Zoom

- (bool)isZoomAvailable
{
    return self.captureSession.isZoomAvailable;
}

- (CGFloat)zoomLevel
{
    return self.captureSession.zoomLevel;
}

- (void)setZoomLevel:(CGFloat)zoomLevel
{
    zoomLevel = MAX(0.0f, MIN(1.0f, zoomLevel));
    
    [[PGCamera cameraQueue] dispatch:^
    {
        if (self.disabled)
            return;
        
        [self.captureSession setZoomLevel:zoomLevel];
    }];
}

#pragma mark - Device Angle

- (void)startDeviceAngleMeasuring
{
    [_deviceAngleSampler startMeasuring];
}

- (void)stopDeviceAngleMeasuring
{
    [_deviceAngleSampler stopMeasuring];
}

#pragma mark - Availability

+ (bool)cameraAvailable
{
#if TARGET_IPHONE_SIMULATOR
    return false;
#endif
    
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

+ (bool)hasRearCamera
{
#if defined(ONEGRAM_ARMV6)
    return [self cameraAvailable];
#else
    return ([PGCameraCaptureSession _deviceWithCameraPosition:PGCameraPositionRear] != nil);
#endif
}

+ (bool)hasFrontCamera
{
#if defined(ONEGRAM_ARMV6)
    return false;
#else
    return ([PGCameraCaptureSession _deviceWithCameraPosition:PGCameraPositionFront] != nil);
#endif
}

+ (SQueue *)cameraQueue
{
    static dispatch_once_t onceToken;
    static SQueue *queue = nil;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] init];
    });
    
    return queue;
}

+ (AVCaptureVideoOrientation)_videoOrientationForInterfaceOrientation:(UIInterfaceOrientation)deviceOrientation mirrored:(bool)mirrored
{
    switch (deviceOrientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
            
        case UIInterfaceOrientationLandscapeLeft:
            return mirrored ? AVCaptureVideoOrientationLandscapeRight : AVCaptureVideoOrientationLandscapeLeft;
            
        case UIInterfaceOrientationLandscapeRight:
            return mirrored ? AVCaptureVideoOrientationLandscapeLeft : AVCaptureVideoOrientationLandscapeRight;
            
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}

+ (PGCameraAuthorizationStatus)cameraAuthorizationStatus
{
#if defined(ONEGRAM_ARMV6)
    return PGCameraAuthorizationStatusAuthorized;
#else
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
        return [PGCamera _cameraAuthorizationStatusForAuthorizationStatus:[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]];
    return PGCameraAuthorizationStatusAuthorized;
#endif
}

+ (PGMicrophoneAuthorizationStatus)microphoneAuthorizationStatus
{
#if defined(ONEGRAM_ARMV6)
    return PGMicrophoneAuthorizationStatusAuthorized;
#else
    if ([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)])
        return [PGCamera _microphoneAuthorizationStatusForAuthorizationStatus:[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]];
    return PGMicrophoneAuthorizationStatusAuthorized;
#endif
}

+ (PGCameraAuthorizationStatus)_cameraAuthorizationStatusForAuthorizationStatus:(AVAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus)
    {
        case AVAuthorizationStatusRestricted:
            return PGCameraAuthorizationStatusRestricted;
            
        case AVAuthorizationStatusDenied:
            return PGCameraAuthorizationStatusDenied;
            
        case AVAuthorizationStatusAuthorized:
            return PGCameraAuthorizationStatusAuthorized;
            
        default:
            return PGCameraAuthorizationStatusNotDetermined;
    }
}

+ (PGMicrophoneAuthorizationStatus)_microphoneAuthorizationStatusForAuthorizationStatus:(AVAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus)
    {
        case AVAuthorizationStatusRestricted:
            return PGMicrophoneAuthorizationStatusRestricted;
            
        case AVAuthorizationStatusDenied:
            return PGMicrophoneAuthorizationStatusDenied;
            
        case AVAuthorizationStatusAuthorized:
            return PGMicrophoneAuthorizationStatusAuthorized;
            
        default:
            return PGMicrophoneAuthorizationStatusNotDetermined;
    }
}

@end
