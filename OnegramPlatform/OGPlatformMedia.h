#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT BOOL OGPlatformMediaDownloadsRequireUserAction(void);
FOUNDATION_EXPORT BOOL OGPlatformCameraAvailable(void);
FOUNDATION_EXPORT BOOL OGPlatformVideoPlaybackAvailable(void);
FOUNDATION_EXPORT BOOL OGPlatformAVPlayerAvailable(void);
FOUNDATION_EXPORT BOOL OGPlatformAVCaptureAvailable(void);
FOUNDATION_EXPORT BOOL OGPlatformCoreImageAvailable(void);
FOUNDATION_EXPORT BOOL OGPlatformCaptureConnectionIsVideoMirrored(id connection);
FOUNDATION_EXPORT void OGPlatformSetCaptureConnectionVideoMirrored(id connection, BOOL mirrored);
FOUNDATION_EXPORT void OGPlatformConfigureVolumeView(UIView *volumeView, UIImage *minimumTrackImage, UIImage *maximumTrackImage, UIImage *thumbImage, BOOL showsRouteButton);

FOUNDATION_EXPORT UIImage *OGPlatformVideoThumbnailAtURL(NSURL *url, NSTimeInterval time, CGSize maximumSize);
FOUNDATION_EXPORT BOOL OGPlatformReadVideoMetadataAtURL(NSURL *url, NSTimeInterval *duration, CGSize *dimensions);

@interface OGPlatformMoviePlayer : NSObject

@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval currentTime;
@property (nonatomic, readonly, getter=isPlaying) BOOL playing;
@property (nonatomic, readonly) BOOL supportsInlinePlayback;
@property (nonatomic, readonly) BOOL supportsSeeking;
@property (nonatomic, copy) void (^playbackFinished)(void);

- (instancetype)initWithURL:(NSURL *)url;
- (void)play;
- (void)pause;
- (void)stop;
- (BOOL)seekToTime:(NSTimeInterval)time;

@end
