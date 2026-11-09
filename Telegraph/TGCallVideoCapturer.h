#import <UIKit/UIKit.h>

@class SQueue;
@class TGCallVideoView;

@interface TGCallVideoCapturer : NSObject

+ (bool)isAvailable;
+ (bool)hasFrontAndBackCameras;

- (instancetype)initWithMediaQueue:(SQueue *)mediaQueue;

@property (nonatomic, readonly) bool usesFrontCamera;

- (void)setPreviewView:(TGCallVideoView *)view;

- (void)start;
- (void)stop;
- (void)switchCamera;

@end
