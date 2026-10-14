#import "TGEmbedVideoPlayerView.h"
#import "TGEmbedPlayerState.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#import <MediaPlayer/MediaPlayer.h>
#else
#import <AVFoundation/AVFoundation.h>
#import "TGModernGalleryVideoView.h"
#endif

#import "TGTimerTarget.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
static NSTimeInterval TGEmbedLegacyMoviePlayerTime(MPMoviePlayerController *player, NSString *selectorName, NSTimeInterval fallback)
{
    SEL selector = NSSelectorFromString(selectorName);
    if (![player respondsToSelector:selector])
        return fallback;
    NSTimeInterval (*implementation)(id, SEL) = (NSTimeInterval (*)(id, SEL))[player methodForSelector:selector];
    if (implementation == NULL)
        return fallback;
    return implementation(player, selector);
}

static void TGEmbedLegacyMoviePlayerSetTime(MPMoviePlayerController *player, NSTimeInterval position)
{
    SEL selector = NSSelectorFromString(@"setCurrentPlaybackTime:");
    if (![player respondsToSelector:selector])
        return;
    void (*implementation)(id, SEL, NSTimeInterval) = (void (*)(id, SEL, NSTimeInterval))[player methodForSelector:selector];
    if (implementation != NULL)
        implementation(player, selector, position);
}

static void TGEmbedLegacyMoviePlayerPause(MPMoviePlayerController *player)
{
    SEL selector = NSSelectorFromString(@"pause");
    if ([player respondsToSelector:selector])
    {
        void (*implementation)(id, SEL) = (void (*)(id, SEL))[player methodForSelector:selector];
        if (implementation != NULL)
        {
            implementation(player, selector);
            return;
        }
    }
    [player stop];
}
#endif

@interface TGEmbedVideoPlayerView ()
{
    NSString *_url;
    bool _started;

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    MPMoviePlayerController *_player;
#else
    AVPlayer *_player;
    TGModernGalleryVideoView *_videoView;
#endif
    UIImageView *_watermarkView;

    NSInteger _playbackTicks;
    bool _playingStarted;
}
@end

@implementation TGEmbedVideoPlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)alternateCachePathSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal alternateCachePathSignal:alternateCachePathSignal];
    if (self != nil)
    {
        _url = webPage.embedUrl;
    }
    return self;
}

- (void)dealloc
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:_player];
    [_player stop];
#else
    [_player.currentItem removeObserver:self forKeyPath:@"status"];
    [_player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
#endif
}

- (void)playVideo
{
    [_player play];
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    if (self.state.position > DBL_EPSILON)
        TGEmbedLegacyMoviePlayerSetTime(_player, self.state.position);
#endif

    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true duration:self.state.duration position:self.state.position downloadProgress:self.state.downloadProgress buffering:self.state.buffering];
    [self updateState:state];
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    NSTimeInterval position = TGEmbedLegacyMoviePlayerTime(_player, @"currentPlaybackTime", self.state.position);
    TGEmbedLegacyMoviePlayerPause(_player);
#else
    [_player pause];
    NSTimeInterval position = self.state.position;
#endif

    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:false duration:self.state.duration position:position downloadProgress:self.state.downloadProgress buffering:self.state.buffering];
    [self updateState:state];
}

- (void)seekToPosition:(NSTimeInterval)position
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    TGEmbedLegacyMoviePlayerSetTime(_player, position);
#else
    [_player.currentItem seekToTime:CMTimeMake((int64_t)(position * 1000.0), 1000.0)];
#endif

    TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:self.state.isPlaying duration:self.state.duration position:position downloadProgress:self.state.downloadProgress buffering:self.state.buffering];
    [self updateState:newState];
}

- (void)setupWithEmbedSize:(CGSize)embedSize
{
    [super setupWithEmbedSize:embedSize];
    [self _setupCustomPlayerWithURL:[NSURL URLWithString:_url]];
}

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeFull;
}

- (void)_onPageReady
{

}

- (void)_didBeginPlayback
{
    [super _didBeginPlayback];
    [self setDimmed:false animated:true shouldDelay:false];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)__unused object change:(NSDictionary *)__unused change context:(void *)__unused context {
    bool playing = self.state.playing;
    NSTimeInterval position = self.state.position;
    NSTimeInterval duration = self.state.duration;
    CGFloat downloadProgress = self.state.downloadProgress;
    bool buffering = self.state.buffering;

    if ([keyPath isEqualToString:@"status"])
    {
        if (_player.currentItem.status == AVPlayerItemStatusReadyToPlay)
        {
            if (duration < DBL_EPSILON)
                duration = CMTimeGetSeconds(_player.currentItem.asset.duration);

            if (!_started) {
                _started = true;
                [self setDimmed:true animated:false];
            }
        }
    }
    else if ([keyPath isEqualToString:@"loadedTimeRanges"])
    {
        NSValue *range = _player.currentItem.loadedTimeRanges.firstObject;
        CMTime time = CMTimeRangeGetEnd(range.CMTimeRangeValue);
        NSTimeInterval availableDuration = CMTimeGetSeconds(time);
        if (duration < DBL_EPSILON)
            duration = MAX(0.01, CMTimeGetSeconds(_player.currentItem.asset.duration));
        downloadProgress = MAX(0.0, MIN(1.0, availableDuration / duration));
    }

    TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:playing duration:duration position:position downloadProgress:downloadProgress buffering:buffering];
    [self updateState:newState];
}
#endif

- (void)_setupCustomPlayerWithURL:(NSURL *)url
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    if (_player != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:_player];

    _player = [[MPMoviePlayerController alloc] initWithContentURL:url];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_legacyPlayerDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:_player];
    [_player play];

    NSTimeInterval duration = TGEmbedLegacyMoviePlayerTime(_player, @"duration", self.state.duration);
    if (!_started)
    {
        _started = true;
        [self setDimmed:true animated:false];
        [self _didBeginPlayback];
    }

    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true duration:duration position:0.0 downloadProgress:self.state.downloadProgress buffering:false];
    [self updateState:state];
#else
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    _player = player;

    [player.currentItem addObserver:self forKeyPath:@"status" options:0 context:nil];
    [player.currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:0 context:nil];

    UIView *currentView = [self _webView];
    TGModernGalleryVideoView *videoView = [[TGModernGalleryVideoView alloc] initWithFrame:currentView.frame player:player];
    [currentView.superview insertSubview:videoView aboveSubview:currentView];

    [self _cleanWebView];
    _videoView = videoView;

    __weak TGEmbedVideoPlayerView *weakSelf = self;
    [player addPeriodicTimeObserverForInterval:CMTimeMake(1, 10) queue:dispatch_get_main_queue() usingBlock:^(CMTime time)
    {
        __strong TGEmbedVideoPlayerView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            NSTimeInterval position = CMTimeGetSeconds(time);
            if (!strongSelf->_playingStarted && position > DBL_EPSILON)
            {
                strongSelf->_playbackTicks++;
                if (strongSelf->_playbackTicks > 2)
                {
                    strongSelf->_playingStarted = true;
                    [strongSelf _didBeginPlayback];

                    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true];
                    [strongSelf updateState:state];
                }
            }

            TGEmbedPlayerState *state = strongSelf.state;
            TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:state.playing duration:state.duration position:position downloadProgress:state.downloadProgress buffering:self.state.buffering];
            [strongSelf updateState:newState];
        }
    }];

    [player play];
#endif
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
- (void)_legacyPlayerDidFinish:(NSNotification *)notification
{
    NSTimeInterval duration = TGEmbedLegacyMoviePlayerTime(_player, @"duration", self.state.duration);
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:false duration:duration position:duration downloadProgress:self.state.downloadProgress buffering:false];
    [self updateState:state];
}
#endif

- (UIView *)_webView
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    if (_videoView != nil)
        return _videoView;
#endif

    return [super _webView];
}


+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    NSArray *components = [url componentsSeparatedByString:@"?"];
    if (components.count > 1)
        url = components.firstObject;

    return ([url hasSuffix:@".mp4"] || [url hasSuffix:@".mov"]);
}

@end
