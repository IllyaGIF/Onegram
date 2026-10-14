/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryZoomableItemView.h"

@class TGImageView;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@class MPMoviePlayerController;
#else
@class AVPlayer;
#endif

@interface TGModernGalleryVideoItemView : TGModernGalleryItemView

@property (nonatomic, strong) TGImageView *imageView;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@property (nonatomic, strong) MPMoviePlayerController *player;
#else
@property (nonatomic, strong) AVPlayer *player;
#endif
@property (nonatomic) CGSize videoDimensions;

- (bool)shouldLoopVideo:(NSUInteger)currentLoopCount;

- (void)play;
- (void)loadAndPlay;
- (void)hidePlayButton;
- (void)stop;
- (void)stopForOutTransition;

- (void)_willPlay;

@end
