#if __has_include(<CoreMedia/CoreMedia.h>)
#import <CoreMedia/CoreMedia.h>
#endif
#if __has_include(<CoreVideo/CoreVideo.h>)
#import <CoreVideo/CoreVideo.h>
#endif
#import <AVFoundation/AVFoundation.h>

@interface TGVideoCameraGLRenderer : NSObject

@property (nonatomic, readonly) __attribute__((NSObject)) CMFormatDescriptionRef outputFormatDescription;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
@property (nonatomic, assign) bool mirror;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, readonly) bool hasPreviousPixelbuffer;

- (void)prepareForInputWithFormatDescription:(CMFormatDescriptionRef)inputFormatDescription outputRetainedBufferCountHint:(size_t)outputRetainedBufferCountHint maximumOutputSide:(CGFloat)maximumOutputSide;
- (void)reset;

- (CVPixelBufferRef)copyRenderedPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)setPreviousPixelBuffer:(CVPixelBufferRef)previousPixelBuffer;

@end
