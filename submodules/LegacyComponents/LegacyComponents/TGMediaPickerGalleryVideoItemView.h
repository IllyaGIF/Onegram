#import "TGModernGalleryItemView.h"
#import "TGModernGalleryEditableItemView.h"
#import "TGModernGalleryImageItemImageView.h"
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#import <MediaPlayer/MediaPlayer.h>
#else
#import <AVFoundation/AVFoundation.h>
#endif

@interface TGMediaPickerGalleryVideoItemView : TGModernGalleryItemView <TGModernGalleryEditableItemView>

@property (nonatomic, strong) TGModernGalleryImageItemImageView *imageView;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@property (nonatomic, strong) MPMoviePlayerController *player;
#else
@property (nonatomic, strong) AVPlayer *player;
#endif

@property (nonatomic, readonly) bool isPlaying;

@property (nonatomic, readonly) bool hasTrimming;
@property (nonatomic, readonly) CMTimeRange trimRange;

- (void)play;
- (void)stop;

- (void)playIfAvailable;

- (void)setPlayButtonHidden:(bool)hidden animated:(bool)animated;
- (void)toggleSendAsGif;

- (void)setScrubbingPanelApperanceLocked:(bool)locked;
- (void)setScrubbingPanelHidden:(bool)hidden animated:(bool)animated;
- (void)presentScrubbingPanelAfterReload:(bool)afterReload;

- (void)prepareForEditing;
- (void)returnFromEditing;

- (UIImage *)screenImage;
- (UIImage *)transitionImage;
- (CGRect)editorTransitionViewRect;

@end
