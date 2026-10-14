#import <UIKit/UIKit.h>
#if __has_include(<CoreVideo/CoreVideo.h>)
#import <CoreVideo/CoreVideo.h>
#endif

@interface TGVideoCameraGLView : UIView

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)flushPixelBufferCache;
- (void)reset;

@end
