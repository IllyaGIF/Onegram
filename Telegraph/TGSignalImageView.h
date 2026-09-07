#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"

#import "TGModernView.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@class TGModernGalleryVideoView;

@interface TGSignalImageView : TGImageView <TGModernView>

@property (nonatomic) CGRect transitionContentRect;

@property (nonatomic) UIEdgeInsets inlineVideoInsets;
@property (nonatomic) CGSize inlineVideoSize;
@property (nonatomic) CGFloat inlineVideoCornerRadius;

- (void)setVideoPathSignal:(SSignal *)videoPathSignal;
- (void)showVideo;
- (void)hideVideo;

- (void)setVideoView:(TGModernGalleryVideoView *)videoView;

@end
