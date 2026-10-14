#import <AVFoundation/AVFoundation.h>

#import "PGCamera.h"

@class PGCameraMovieWriter;

#if defined(ONEGRAM_ARMV6)
@interface PGCameraCaptureSession : NSObject
{
    PGCameraMode _currentMode;
    PGCameraFlashMode _currentFlashMode;
    PGCameraPosition _preferredCameraPosition;
    PGCameraPosition _currentCameraPosition;
    CGFloat _zoomLevel;
    CGPoint _focusPoint;
    bool _running;
    bool _alwaysSetFlash;
    bool _compressVideo;
}
#else
@interface PGCameraCaptureSession : AVCaptureSession
#endif

@property (nonatomic, readonly) AVCaptureDevice *videoDevice;
@property (nonatomic, readonly) AVCaptureStillImageOutput *imageOutput;
@property (nonatomic, readonly) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, readonly) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, readonly) PGCameraMovieWriter *movieWriter;

@property (nonatomic, assign) bool alwaysSetFlash;
@property (nonatomic, assign) PGCameraMode currentMode;
@property (nonatomic, assign) PGCameraFlashMode currentFlashMode;

@property (nonatomic, assign) PGCameraPosition currentCameraPosition;
@property (nonatomic, readonly) PGCameraPosition preferredCameraPosition;

@property (nonatomic, readonly) bool isZoomAvailable;
@property (nonatomic, assign) CGFloat zoomLevel;

@property (nonatomic, readonly) CGPoint focusPoint;

@property (nonatomic, copy) void(^outputSampleBuffer)(CMSampleBufferRef sampleBuffer, AVCaptureConnection *connection);

@property (nonatomic, copy) void(^changingPosition)(void);
@property (nonatomic, copy) bool(^requestPreviewIsMirrored)(void);

@property (nonatomic, assign) bool compressVideo;

- (instancetype)initWithMode:(PGCameraMode)mode position:(PGCameraPosition)position;

#if defined(ONEGRAM_ARMV6)
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, readonly) NSArray *inputs;
@property (nonatomic, readonly) NSArray *outputs;
- (void)beginConfiguration;
- (void)commitConfiguration;
- (void)removeInput:(id)input;
- (void)removeOutput:(id)output;
- (void)startRunning;
- (void)stopRunning;
#endif

- (void)performInitialConfigurationWithCompletion:(void (^)(void))completion;

- (void)setFocusPoint:(CGPoint)point focusMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode monitorSubjectAreaChange:(bool)monitorSubjectAreaChange;
- (void)setExposureTargetBias:(CGFloat)bias;

- (bool)isResetNeeded;
- (void)reset;
- (void)resetFlashMode;

- (void)startVideoRecordingWithOrientation:(AVCaptureVideoOrientation)orientation mirrored:(bool)mirrored completion:(void (^)(NSURL *outputURL, CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success))completion;
- (void)stopVideoRecording;

- (void)captureNextFrameCompletion:(void (^)(UIImage * image))completion;

+ (AVCaptureDevice *)_deviceWithCameraPosition:(PGCameraPosition)position;

+ (bool)_isZoomAvailableForDevice:(AVCaptureDevice *)device;

@end
