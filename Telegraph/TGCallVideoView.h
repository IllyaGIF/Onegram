#import <UIKit/UIKit.h>

@interface TGCallVideoView : UIView

@property (nonatomic, assign) bool fillsBounds;
@property (nonatomic, assign) bool mirrored;
@property (nonatomic, readonly) CGSize videoSize;
@property (nonatomic, copy) void (^firstFrameRendered)(void);
@property (nonatomic, copy) void (^videoSizeChanged)(CGSize size);

- (void)resetFrames;

@end
