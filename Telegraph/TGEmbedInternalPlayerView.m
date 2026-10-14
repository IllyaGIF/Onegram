#import "TGEmbedInternalPlayerView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGEmbedPlayerState.h"

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "TGDatabase.h"
#import "TGDownloadManager.h"
#import "TGPreparedLocalDocumentMessage.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGModernGalleryVideoView.h"

#import "TGSharedMediaSignals.h"
#import "TGSharedMediaUtils.h"

@interface TGEmbedInternalPlayerView () <ASWatcher>
{
    NSString *_url;
    TGDocumentMediaAttachment *_document;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    AVPlayer *_player;
#else
    MPMoviePlayerController *_player;
    NSTimeInterval _legacyPlaybackPosition;
    NSDate *_legacyPlaybackStartDate;
    bool _legacyIgnoringFinish;
#endif
    TGObserverProxy *_didPlayToEndObserver;
    
    NSTimer *_positionTimer;
    
    bool _mediaAvailable;
    bool _downloading;
    bool _downloaded;
    NSTimeInterval _duration;
    
    TGModernGalleryVideoView *_videoView;
    
    SMetaDisposable *_downloadDisposable;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGEmbedInternalPlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal
{
    self = [super initWithWebPageAttachment:nil thumbnailSignal:thumbnailSignal];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _url = webPage.url;
        
        NSTimeInterval duration = 0.0;
        _duration = duration;
    }
    return self;
}

- (instancetype)initWithDocumentAttachment:(TGDocumentMediaAttachment *)document thumbnailSignal:(SSignal *)thumbnailSignal
{
    self = [super initWithWebPageAttachment:nil thumbnailSignal:thumbnailSignal];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _document = document;
        
        NSTimeInterval duration = 0.0;
        for (id attribute in document.attributes)
        {
            if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]])
                duration = ((TGDocumentAttributeVideo *)attribute).duration;
        }
        _duration = duration;
    }
    return self;
}

- (void)dealloc
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    _legacyIgnoringFinish = true;
    [_player stop];
#endif
    
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    
}

- (void)setupWithEmbedSize:(CGSize)embedSize
{
    [super setupWithEmbedSize:embedSize];
    
    [self setDimmed:true animated:false shouldDelay:false];
    [self initializePlayer];
    [self _cleanWebView];
}

- (void)initializePlayer
{
    NSString *videoPath = [self videoPath];
    if (videoPath == nil)
        return;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath isDirectory:NULL])
        {
            _mediaAvailable = true;
            TGDispatchOnMainThread(^
            {
                [self updateState:[TGEmbedPlayerState stateWithPlaying:false duration:_duration position:0.0 downloadProgress:0.0f buffering:false]];
                [self _startAutoPlay];
            });
        }
        else
        {
            TGDispatchOnMainThread(^
            {
                [self updateState:[TGEmbedPlayerState stateWithPlaying:false duration:_duration position:0.0 downloadProgress:0.0f buffering:false]];
                [self _requestDownload];
            });
        }
    });
}

- (void)playVideo
{
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true duration:self.state.duration position:self.state.position downloadProgress:1.0f buffering:false];
    [self updateState:state];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    _legacyIgnoringFinish = false;
    _player.initialPlaybackTime = _legacyPlaybackPosition;
    _legacyPlaybackStartDate = [NSDate date];
#endif
    [_player play];
    [self _startPositionTimer];
}

- (void)pauseVideo
{
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:false duration:self.state.duration position:self.state.position downloadProgress:self.state.downloadProgress buffering:false];
    [self updateState:state];
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    [_player pause];
#else
    _legacyPlaybackPosition = [self legacyPlaybackPosition];
    _legacyPlaybackStartDate = nil;
    _legacyIgnoringFinish = true;
    [_player stop];
#endif
    [self _invalidatePositionTimer];
}

- (void)seekToPosition:(NSTimeInterval)position
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    [_player.currentItem seekToTime:CMTimeMake((int64_t)(position * 1000.0), 1000.0)];
#else
    _legacyPlaybackPosition = MAX(0.0, MIN(position, _duration));
    bool resume = self.state.playing;
    _legacyIgnoringFinish = true;
    [_player stop];
    _player.initialPlaybackTime = _legacyPlaybackPosition;
    if (resume)
    {
        _legacyIgnoringFinish = false;
        _legacyPlaybackStartDate = [NSDate date];
        [_player play];
    }
#endif
}

- (void)_onPageReady
{
    
}

- (void)_didBeginPlayback
{
    [super _didBeginPlayback];
    
    [self setDimmed:false animated:true shouldDelay:false];
}

#pragma mark -

- (NSString *)videoPath
{
    NSString *videoPath = nil;
    if (_url != nil)
    {
        videoPath = [[TGSharedMediaUtils sharedMediaTemporaryPersistentCache] _filePathForKey:[_url dataUsingEncoding:NSUTF8StringEncoding]];
        if (videoPath.pathExtension.length == 0)
        {
            [[NSFileManager defaultManager] createSymbolicLinkAtPath:[videoPath stringByAppendingString:@".mov"] withDestinationPath:[videoPath lastPathComponent] error:nil];
            videoPath = [videoPath stringByAppendingString:@".mov"];
        }
    }
    else
    {
        NSString *documentPath = _document.localDocumentId != 0 ? [TGPreparedLocalDocumentMessage localDocumentDirectoryForLocalDocumentId:_document.localDocumentId version:_document.version] : [TGPreparedLocalDocumentMessage localDocumentDirectoryForDocumentId:_document.documentId version:_document.version];
        NSString *legacyVideoFilePath = [documentPath stringByAppendingPathComponent:[_document safeFileName]];
        videoPath = legacyVideoFilePath;
        if (![videoPath.pathExtension isEqualToString:@"mp4"] && ![videoPath.pathExtension isEqualToString:@"mp4"])
        {
            NSString *movPath = [videoPath stringByAppendingString:@".mov"];
            [[NSFileManager defaultManager] linkItemAtPath:movPath toPath:[_document safeFileName] error:NULL];
            videoPath = movPath;
        }
    }
    return videoPath;
}

- (void)_startAutoPlay
{
    if (!_mediaAvailable)
        return;
    
    if (!_downloaded)
        _overlayView.hidden = true;
    
    NSString *videoPath = [self videoPath];
    if (_player == nil)
    {
        if (videoPath == nil)
            return;
    
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        _player = [[AVPlayer alloc] initWithURL:[NSURL fileURLWithPath:videoPath]];
        _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
        
        _didPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:[_player currentItem]];
        
        _videoView = [[TGModernGalleryVideoView alloc] initWithFrame:self.bounds player:_player];
        _videoView.playerLayer.videoGravity = AVLayerVideoGravityResize;
        _videoView.playerLayer.opaque = false;
        _videoView.playerLayer.backgroundColor = nil;
        
        if (self.controlsView != nil)
            [self insertSubview:_videoView belowSubview:self.controlsView];
        else
            [self insertSubview:_videoView belowSubview:self.dimWrapperView];
#else
        _legacyPlaybackPosition = 0.0;
        _legacyPlaybackStartDate = nil;
        _legacyIgnoringFinish = false;
        _player = [[MPMoviePlayerController alloc] initWithContentURL:[NSURL fileURLWithPath:videoPath]];
        _player.movieControlMode = MPMovieControlModeDefault;
        _player.scalingMode = MPMovieScalingModeFill;
        _didPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:MPMoviePlayerPlaybackDidFinishNotification object:_player];
#endif
    
        [self playVideo];
        [self _didBeginPlayback];
    }
    else
    {
        [self playVideo];
    }
}

- (void)_startPositionTimer
{
    _positionTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(positionTimerEvent) interval:0.25 repeat:true];
    [self positionTimerEvent];
}

- (void)_invalidatePositionTimer
{
    [_positionTimer invalidate];
    _positionTimer = nil;
}

- (void)positionTimerEvent
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:self.state.playing duration:self.state.duration position:CMTimeGetSeconds(_player.currentItem.currentTime) downloadProgress:self.state.downloadProgress buffering:false];
#else
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:self.state.playing duration:self.state.duration position:[self legacyPlaybackPosition] downloadProgress:self.state.downloadProgress buffering:false];
#endif
    [self updateState:state];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
- (NSTimeInterval)legacyPlaybackPosition
{
    NSTimeInterval position = _legacyPlaybackPosition;
    if (_legacyPlaybackStartDate != nil && self.state.playing)
        position += -[_legacyPlaybackStartDate timeIntervalSinceNow];
    return MAX(0.0, MIN(position, _duration));
}
#endif

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    [_player pause];
    
    AVPlayerItem *p = [notification object];
    [p seekToTime:kCMTimeZero];
#else
    if (_legacyIgnoringFinish)
        return;
    _legacyPlaybackPosition = 0.0;
    _legacyPlaybackStartDate = nil;
#endif

    [self _invalidatePositionTimer];
    
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:false duration:self.state.duration position:0.0 downloadProgress:self.state.downloadProgress buffering:false];
    [self updateState:state];
}

#pragma mark -

- (void)_cancelDownload
{
    [ActionStageInstance() removeWatcher:self];
    
    TGDocumentMediaAttachment *document = _document;
    if (document.documentId != 0)
    {
        id itemId = [[TGMediaId alloc] initWithType:3 itemId:document.documentId];
        [[TGDownloadManager instance] cancelItem:itemId];
    }
    else if (document.localDocumentId != 0 && document.documentUri.length != 0)
    {
        id itemId = [[TGMediaId alloc] initWithType:3 itemId:document.localDocumentId];
        [[TGDownloadManager instance] cancelItem:itemId];
    }
    
    TGDispatchOnMainThread(^
    {
        _downloading = false;
        TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:self.state.playing duration:self.state.duration position:self.state.duration downloadProgress:0.0f buffering:false];
        [self updateState:state];
    });
}

- (void)_requestDownload
{
    [self setLoadProgress:0.0f duration:0.3];
    
    if (_url != nil)
    {
        if (_downloadDisposable == nil)
            _downloadDisposable = [[SMetaDisposable alloc] init];
        
        __weak TGEmbedInternalPlayerView *weakSelf = self;
        
        NSInteger datacenterId = 0;
        
        int32_t webFileDatacenterId = 0;
        NSData *data = [TGDatabaseInstance() customProperty:@"webFileDatacenterId"];
        if (data.length == 4)
            [data getBytes:&webFileDatacenterId length:4];
        
        TLInputWebFileLocation *webLocation = [TGSharedMediaSignals inputWebFileLocationForImageUrl:_url datacenterId:&datacenterId];
        if (datacenterId == -1)
            datacenterId = webFileDatacenterId;
        
        [_downloadDisposable setDisposable:[[[TGSharedMediaSignals memoizedDataSignalForRemoteWebLocation:webLocation datacenterId:datacenterId reportProgress:true mediaTypeTag:TGNetworkMediaTypeTagVideo] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
        {
            __strong TGEmbedInternalPlayerView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if ([next isKindOfClass:[NSData class]])
            {
                strongSelf->_downloading = false;
                strongSelf->_mediaAvailable = true;
                
                TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:strongSelf.state.playing duration:strongSelf.state.duration position:strongSelf.state.duration downloadProgress:1.0f buffering:false];
                [strongSelf updateState:state];
                
                strongSelf->_downloaded = true;
                [strongSelf _startAutoPlay];
                [[TGSharedMediaUtils sharedMediaTemporaryPersistentCache] setValue:next forKey:[_url dataUsingEncoding:NSUTF8StringEncoding]];
            }
            else if ([next isKindOfClass:[NSNumber class]])
            {
                [strongSelf updateProgress:next];
            }
        }]];
    }
    else
    {
        TGDocumentMediaAttachment *document = _document;
        NSString *path = [NSString stringWithFormat:@"/tg/media/document/(%d:%" PRId64 ":%@)", document.datacenterId, document.documentId, document.documentUri.length != 0 ? document.documentUri : @""];
        [ActionStageInstance() requestActor:path options:@{@"documentAttachment": document} watcher:self];
    }
    TGDispatchOnMainThread(^
    {
        _downloading = true;
    });
}

#pragma mark -

- (bool)_scaleViewToMaxSize
{
    return false;
}

- (bool)_useFakeLoadingProgress
{
    return false;
}

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeFull;
}

#pragma mark -

- (void)updateProgress:(NSNumber *)progressValue
{
    float progress = [progressValue floatValue];
    TGDispatchOnMainThread(^
    {
        TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:self.state.playing duration:self.state.duration position:self.state.duration downloadProgress:progress buffering:false];
        [self updateState:state];
        
        [self setLoadProgress:progress duration:0.3];
    });
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([path hasPrefix:@"/tg/media/document/"])
    {
        if ([messageType isEqualToString:@"progress"])
        {
            [self updateProgress:message];
        }
    }
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)__unused result
{
    if ([path hasPrefix:@"/tg/media/document/"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (status == ASStatusSuccess)
            {
                _downloading = false;
                _mediaAvailable = true;
                
                TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:self.state.playing duration:self.state.duration position:self.state.duration downloadProgress:1.0f buffering:false];
                [self updateState:state];
                
                _downloaded = true;
                [self _startAutoPlay];
            }
        });
    }
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    return [webPage.url hasPrefix:@"webdoc"];
}

@end
