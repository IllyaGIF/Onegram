#import "TGModernGalleryVideoPlayerView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../OnegramPlatform/OGPlatformMedia.h"
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <AVFoundation/AVFoundation.h>
#endif
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#import <AVKit/AVKit.h>
#endif

#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryVideoView.h"

#import "TGAudioSessionManager.h"
#import "TGEmbedPIPController.h"

#import "TransformImageView.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
@interface TGModernGalleryVideoPlayerView () <AVPictureInPictureControllerDelegate>
#else
@interface TGModernGalleryVideoPlayerView ()
#endif
{
    TGImageView *_legacyImageView;
    TransformImageView *_transformImageView;
    
    NSString *_videoPath;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    OGPlatformMoviePlayer *_player;
    UIView *_legacyVideoView;
#else
    AVPlayer *_player;
#endif
    TGModernGalleryVideoView *_videoView;
    NSUInteger _currentLoopCount;
    
    NSTimer *_positionTimer;
    NSTimer *_videoFlickerTimer;
    
    TGObserverProxy *_didPlayToEndObserver;
    
    SPipe *_statePipe;
    
    bool _pausedManually;
    bool _shouldResumePIPPlayback;
    
    SMetaDisposable *_currentAudioSession;
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    AVPictureInPictureController *_systemPIPController;
#endif
}
@end

@implementation TGModernGalleryVideoPlayerView

@synthesize requestPictureInPicture = _requestPictureInPicture;
@synthesize disallowPIP = _disallowPIP;
@synthesize initialFrame = _initialFrame;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _statePipe = [[SPipe alloc] init];
        _state = [TGModernGalleryVideoPlayerState stateWithPlaying:false duration:0.0 position:0.0];
        
        _legacyImageView = [[TGImageView alloc] init];
        _legacyImageView.contentMode = UIViewContentModeScaleToFill;
        [self addSubview:_legacyImageView];
        
        _transformImageView = [[TransformImageView alloc] init];
        _transformImageView.contentMode = UIViewContentModeScaleToFill;
        [_transformImageView setArguments:[[TransformImageArguments alloc] initWithImageSize:CGSizeZero boundingSize:CGSizeZero cornerRadius:0.0 scaleToFit:true]];
        [self addSubview:_transformImageView];
    }
    return self;
}

- (void)dealloc
{
    [_currentAudioSession dispose];
    
    [TGEmbedPIPController resumePictureInPicturePlayback];
}

- (void)loadImageWithUri:(NSString *)uri update:(bool)update synchronously:(bool)synchronously
{
    NSDictionary *options = @{};
    if (update)
        options = @{TGImageViewOptionKeepCurrentImageAsPlaceholder: @true};
    else
        options = @{TGImageViewOptionSynchronous: @(synchronously)};
    
    [_legacyImageView loadUri:uri withOptions:options];
}

- (void)loadImageWithSignal:(SSignal *)signal {
    [_transformImageView setSignal:signal];
}

- (void)setVideoPath:(NSString *)videoPath duration:(NSTimeInterval)duration
{
    _videoPath = videoPath;
    [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:false duration:duration position:0.0]];
}

- (bool)isLoaded
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    return (_player != nil);
#else
    return (_videoView != nil);
#endif
}

- (SSignal *)stateSignal
{
    return _statePipe.signalProducer();
}

- (void)updateState:(TGModernGalleryVideoPlayerState *)state
{
    _state = state;
    _statePipe.sink(state);
}

- (void)reset
{
    [_legacyImageView reset];
    [_transformImageView setSignal:[SSignal never]];
    [self stop];
}

- (void)stop
{
    if (_player != nil)
    {
        _didPlayToEndObserver = nil;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
        _player.playbackFinished = nil;
        [_player stop];
#else
        [_player pause];
        [_player replaceCurrentItemWithPlayerItem:nil];
#endif
        _player = nil;
    }

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    if (_legacyVideoView != nil)
    {
        [_legacyVideoView removeFromSuperview];
        _legacyVideoView = nil;
    }
    SMetaDisposable *currentAudioSession = _currentAudioSession;
    if (currentAudioSession != nil)
    {
        [[SQueue concurrentDefaultQueue] dispatch:^
        {
            [currentAudioSession setDisposable:nil];
        }];
    }
#else
    if (_videoView != nil)
    {
        SMetaDisposable *currentAudioSession = _currentAudioSession;
        if (currentAudioSession)
        {
            _videoView.deallocBlock = ^
            {
                [[SQueue concurrentDefaultQueue] dispatch:^
                {
                    [currentAudioSession setDisposable:nil];
                }];
            };
        }
        [_videoView cleanupPlayer];
        [_videoView removeFromSuperview];
        _videoView = nil;
    }
#endif
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    _systemPIPController = nil;
#endif
    
    [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:false duration:self.state.duration position:self.state.position]];
    
    [_videoFlickerTimer invalidate];
    _videoFlickerTimer = nil;
    
    [_positionTimer invalidate];
    _positionTimer = nil;
}

- (void)disposeAudioSession
{
    [_currentAudioSession dispose];
}

- (void)playVideo
{
    if (_videoPath == nil)
        return;

    if (_player == nil)
    {
        _currentAudioSession = [[SMetaDisposable alloc] init];

        __weak TGModernGalleryVideoPlayerView *weakSelf = self;
        [[SQueue concurrentDefaultQueue] dispatch:^
        {
            [_currentAudioSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypePlayVideo interrupted:^
            {
                TGDispatchOnMainThread(^
                {
                    __strong TGModernGalleryVideoPlayerView *strongSelf = weakSelf;
                    if (strongSelf != nil)
                        [strongSelf pauseVideo:false];
                });
            }]];
        }];

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
        _player = [[OGPlatformMoviePlayer alloc] initWithURL:[NSURL fileURLWithPath:_videoPath]];
        if (_player == nil)
            return;

        _player.playbackFinished = ^
        {
            __strong TGModernGalleryVideoPlayerView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf legacyPlayerDidPlayToEnd];
        };

        _legacyVideoView = _player.view;
        if (_legacyVideoView != nil)
        {
            _legacyVideoView.frame = self.bounds;
            _legacyVideoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:_legacyVideoView];
            _legacyVideoView.alpha = 0.0f;
            _videoFlickerTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(videoFlickerTimerEvent) interval:0.1 repeat:false];
        }

        NSTimeInterval actualDuration = _player.duration;
        if (actualDuration > 0.1f)
            [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:false duration:actualDuration position:0.0]];
#else
        _player = [[AVPlayer alloc] initWithURL:[NSURL fileURLWithPath:_videoPath]];
        _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

        _didPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:[_player currentItem]];

        _videoView = [[TGModernGalleryVideoView alloc] initWithFrame:self.bounds player:_player];
        _videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _videoView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

        _videoView.playerLayer.opaque = false;
        _videoView.playerLayer.backgroundColor = nil;
        [self addSubview:_videoView];

        _videoView.alpha = 0.0f;
        _videoFlickerTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(videoFlickerTimerEvent) interval:0.1 repeat:false];
#endif

        [self _setupSystemPIP];

        [self _didBeginPlayback];

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
        [_player seekToTime:0.0];
#else
        Float64 seconds = 0.0f;
        CMTime targetTime = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
        [_player seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
#endif
    }

    [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:true duration:self.state.duration position:self.state.position]];

    [_player play];

    _positionTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(positionTimerEvent) interval:0.25 repeat:true];
    [self positionTimerEvent];
}

- (void)pauseVideo
{
    [self pauseVideo:true];
}

- (void)pauseVideo:(bool)manually
{
    _pausedManually = manually;
    
    [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:false duration:self.state.duration position:self.state.position]];
    
    [_player pause];

    [_positionTimer invalidate];
    _positionTimer = nil;
}

- (void)videoFlickerTimerEvent
{
    [_videoFlickerTimer invalidate];
    _videoFlickerTimer = nil;
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    _legacyVideoView.alpha = 1.0f;
#else
    _videoView.alpha = 1.0f;
#endif
}

- (void)positionTimerEvent
{
    NSTimeInterval duration = self.state.duration;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    NSTimeInterval actualDuration = _player.duration;
    NSTimeInterval position = _player.currentTime;
#else
    NSTimeInterval actualDuration = CMTimeGetSeconds(_player.currentItem.duration);
    NSTimeInterval position = CMTimeGetSeconds(_player.currentItem.currentTime);
#endif
    if (actualDuration > 0.1f)
        duration = actualDuration;

    [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:self.state.isPlaying duration:duration position:position]];
}

- (void)_didBeginPlayback
{
    [TGEmbedPIPController pausePictureInPicturePlayback];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
- (void)legacyPlayerDidPlayToEnd
{
    bool shouldLoop = false;
    if (self.shouldLoop != nil)
        shouldLoop = self.shouldLoop(_currentLoopCount);

    if (shouldLoop)
    {
        [_player seekToTime:0.0];
        [_player play];
    }
    else
    {
        [_player seekToTime:0.0];
        [_positionTimer invalidate];
        _positionTimer = nil;
        [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:false duration:self.state.duration position:0.0]];
    }
}
#else
- (void)playerItemDidPlayToEndTime:(NSNotification *)__unused notification
{
    bool shouldLoop = false;
    if (self.shouldLoop != nil)
        shouldLoop = self.shouldLoop(_currentLoopCount);

    if (shouldLoop)
    {
        AVPlayerItem *p = [notification object];
        [p seekToTime:kCMTimeZero];
    }
    else
    {
        [_player pause];

        AVPlayerItem *p = [notification object];
        [p seekToTime:kCMTimeZero];

        [_positionTimer invalidate];
        _positionTimer = nil;

        [self updateState:[TGModernGalleryVideoPlayerState stateWithPlaying:false duration:self.state.duration position:0.0]];
    }
}
#endif

- (void)seekToPosition:(NSTimeInterval)position
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    [_player seekToTime:position];
#else
    [_player.currentItem seekToTime:CMTimeMake((int64_t)(position * 1000.0), 1000.0)];
#endif

    if (!self.state.playing)
        [self positionTimerEvent];
}

- (void)seekToFractPosition:(CGFloat)position
{
    NSTimeInterval timePosition = self.state.duration * position;
    [self seekToPosition:timePosition];
}

- (void)switchToPictureInPicture
{
    if (self.requestPictureInPicture != nil)
        self.requestPictureInPicture(TGEmbedPIPCornerNone);
}

- (void)_setupSystemPIP
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    if (_systemPIPController != nil)
        return;
    
    AVPictureInPictureController *controller = [[AVPictureInPictureController alloc] initWithPlayerLayer:_videoView.playerLayer];
    controller.delegate = self;
    _systemPIPController = controller;
#endif
}

- (void)_requestSystemPictureInPictureMode
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
    if (iosMajorVersion() < 9 || !TGIsPad() || ![AVPictureInPictureController isPictureInPictureSupported])
        return;
    
    if ([_systemPIPController isPictureInPicturePossible])
        [_systemPIPController startPictureInPicture];
#endif
}

- (void)beginLeavingFullscreen
{
    
}

- (void)finishedLeavingFullscreen
{
    
}

- (void)_prepareToEnterFullscreen
{
    
}

- (void)_prepareToLeaveFullscreen
{
    
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
- (void)pictureInPictureController:(AVPictureInPictureController *)__unused pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler
{
    [TGEmbedPIPController _cancelSystemPIPWithCompletion:^
    {
        completionHandler(true);
    }];
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)__unused pictureInPictureController
{
    [TGEmbedPIPController _systemPictureInPictureDidStart];
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)__unused pictureInPictureController
{
    [TGEmbedPIPController _systemPictureInPictureDidStop];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)__unused pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error
{
    TGLog(@"AVPictureInPictureController error: %@", error.localizedDescription);
}

#endif

- (void)pausePIPPlayback
{
    if (_pausedManually)
        return;
    
    _shouldResumePIPPlayback = true;
    [self pauseVideo:false];
}

- (void)resumePIPPlayback
{
    
    _shouldResumePIPPlayback = false;
}

- (bool)supportsPIP
{
    CGSize screenSize = TGScreenSize();
    return !self.disallowPIP && (int)screenSize.height != 480;
}
#pragma mark - 

- (void)layoutSubviews
{
    _legacyImageView.frame = self.bounds;
    _transformImageView.frame = self.bounds;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    _legacyVideoView.frame = self.bounds;
#else
    _videoView.frame = self.bounds;
#endif
}

@end
