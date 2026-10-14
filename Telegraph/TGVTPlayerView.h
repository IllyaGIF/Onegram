#import <UIKit/UIKit.h>

#if !defined(ONEGRAM_ARMV6)
#import <CoreVideo/CoreVideo.h>

@interface TGVTPlayerView : UIView

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
#endif
