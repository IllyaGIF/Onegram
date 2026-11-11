#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGMusicPlayer.h"
#import "TGTelegraph.h"
#import "OGFeatureProbe.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>

#import "TGPreparedLocalDocumentMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"
#import "TGMusicPlayerPlaylist.h"

#import "TGAudioSessionManager.h"
#import "TGRemoteControlsManager.h"

#import "TGMusicPlayerItemSignals.h"

#import "TGModernConversationAudioPlayer.h"
#import "TGNativeAudioPlayer.h"
#import "OGMediaStreamServer.h"
#import "OGMediaFetchDescriptor+Telegraph.h"

#import "TGAppDelegate.h"

#import "../OnegramRuntime/OGPluginAvailability.h"
#if OG_PLUGINS_AVAILABLE
#import "../OnegramPlugins/OGPluginMusicAudioTap.h"
#endif

NSString *TGMusicPlayerCurrentLocalAudioPath(TGMusicPlayerStatus *status)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    if (![status.player isKindOfClass:[TGNativeAudioPlayer class]])
        return nil;
    AVPlayerItem *item = ((TGNativeAudioPlayer *)status.player).player.currentItem;
    if (![item.asset isKindOfClass:[AVURLAsset class]])
        return nil;
    NSURL *url = ((AVURLAsset *)item.asset).URL;
    if (![url isFileURL])
        return nil;
    NSString *path = [url path];
    return [[NSFileManager defaultManager] fileExistsAtPath:path] ? path : nil;
#else
    return nil;
#endif
}


static TGMusicPlayerDownloadingStatus TGMusicPlayerDownloadingStatusMake(bool downloaded, bool downloading, CGFloat progress)
{
    return (TGMusicPlayerDownloadingStatus){.downloaded = downloaded, .downloading = downloading, .progress = progress, .playable = downloaded};
}

static TGMusicPlayerDownloadingStatus TGMusicPlayerDownloadingStatusMakeStreaming(CGFloat progress)
{
    return (TGMusicPlayerDownloadingStatus){.downloaded = false, .downloading = true, .progress = progress, .playable = true};
}

static bool OGCompatNowPlayingAvailable(void)
{
    return iosMajorVersion() >= 5 && NSClassFromString(@"MPNowPlayingInfoCenter") != nil;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
static void OGCompatFillPlaybackProgress(NSMutableDictionary *info, TGMusicPlayerStatus *status)
{
    [info setObject:@(status.paused ? 0.0f : status.rate) forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [info setObject:@(status.offset * status.duration) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [info setObject:@(status.duration) forKey:MPMediaItemPropertyPlaybackDuration];
}
#endif

@interface TGMusicPlayerStatus ()

@end

@implementation TGMusicPlayerStatus

- (instancetype)initWithItem:(TGMusicPlayerItem *)item player:(TGAudioPlayer *)player position:(TGMusicPlayerItemPosition)position paused:(bool)paused offset:(CGFloat)offset duration:(CGFloat)duration rate:(CGFloat)rate albumArt:(SSignal *)albumArt albumArtSync:(SSignal *)albumArtSync downloadedStatus:(TGMusicPlayerDownloadingStatus)downloadedStatus isVoice:(bool)isVoice orderType:(TGMusicPlayerOrderType)orderType repeatType:(TGMusicPlayerRepeatType)repeatType
{
    self = [super init];
    if (self != nil)
    {
        _item = item;
        _player = player;
        _position = position;
        _paused = paused;
        _offset = offset;
        _duration = duration;
        _rate = rate;
        _timestamp = CACurrentMediaTime();
        _albumArt = albumArt;
        _albumArtSync = albumArtSync;
        _downloadedStatus = downloadedStatus;
        _isVoice = isVoice;
        _orderType = orderType;
        _repeatType = repeatType;
    }
    return self;
}

@end

@class TGMusicPlayer;

@interface OGCompatMusicPlayerRef : NSObject
@property (nonatomic, weak) TGMusicPlayer *value;
@end

@implementation OGCompatMusicPlayerRef
@end

static TGMusicPlayer *OGCompatResolveMusicPlayer(OGCompatMusicPlayerRef *reference)
{
    TGMusicPlayer *result = nil;
    @synchronized (reference)
    {
        result = reference.value;
    }
    return result;
}

static void OGCompatRunOnMainSync(dispatch_block_t block)
{
    if ([NSThread isMainThread])
        block();
    else
        dispatch_sync(dispatch_get_main_queue(), block);
}

@interface TGMusicPlayer () <TGModernConversationAudioPlayerDelegate>
{
    bool _initialized;
    SQueue *_queue;
    
    TGModernConversationAudioPlayer *_player;
    
    STimer *_updateTimer;
    
    SPipe *_playingStatusPipe;
    SPipe *_playlistFinishedPipe;
    SPipe *_playlistPipe;
    TGMusicPlayerStatus *_currentStatus;
    SMetaDisposable *_currentItemDisposable;
    TGMusicPlayerItem *_currentNextItem;
    SMetaDisposable *_nextItemDisposable;
    
    SMetaDisposable *_currentAudioSession;
    id<SDisposable> _compatSessionLease;
    SMetaDisposable *_currentRemoteControls;
    
    SMetaDisposable *_currentAlbumArtDisposable;
    
    SMulticastSignalManager *_albumArtMulticastManager;
    
    SMetaDisposable *_currentPlaylistDisposable;
    TGMusicPlayerPlaylist *_currentPlaylist;
    
    TGMusicPlayerPlaylist *_currentTemporaryPlaylist;
    
    CGFloat _rate;
    
    id<SDisposable> _routeChangeDisposable;
    TGHolder *_proximityChangeHolder;
    TGObserverProxy *_proximityChangedNotification;
    bool _proximityState;
    bool _changingProximity;
    OGPlatformBackgroundTaskIdentifier _trackTransitionTask;
    OGCompatMusicPlayerRef *_compatSelfRef;
}

@property (atomic, strong) OGMediaStream *activeStream;

@end

@implementation TGMusicPlayer

+ (BOOL)pluginControlForTrack:(NSString *)track action:(NSString *)action position:(double)position
{
    TGMusicPlayer *player = [TGTelegraphInstance musicPlayer];
    if (player == nil || track.length == 0 || action.length == 0)
        return NO;
    if (![action isEqualToString:@"toggle"] && ![action isEqualToString:@"play"] &&
        ![action isEqualToString:@"pause"] && ![action isEqualToString:@"previous"] &&
        ![action isEqualToString:@"next"] && ![action isEqualToString:@"seek"])
        return NO;
    if ([action isEqualToString:@"seek"] && (!isfinite(position) || position < 0 || position > 1))
        return NO;
    [player->_queue dispatch:^{
        TGMusicPlayerStatus *status = player->_currentStatus;
        if (status.item == nil || ![[status.item.key description] isEqualToString:track] || status.isVoice)
            return;
        if ([action isEqualToString:@"toggle"])
            [player controlPlayPause];
        else if ([action isEqualToString:@"play"])
            [player controlPlay];
        else if ([action isEqualToString:@"pause"])
            [player controlPause];
        else if ([action isEqualToString:@"previous"])
            [player controlPrevious];
        else if ([action isEqualToString:@"next"])
            [player controlNext];
        else if ([action isEqualToString:@"seek"])
            [player controlSeekToPosition:(CGFloat)position];
    }];
    return YES;
}

@synthesize playlistMetadata = _playlistMetadata;

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _rate = 1.0f;
        _trackTransitionTask = OGPlatformBackgroundTaskInvalid;
        _compatSelfRef = [[OGCompatMusicPlayerRef alloc] init];
        _compatSelfRef.value = self;
        
        _playingStatusPipe = [[SPipe alloc] init];
        _playlistFinishedPipe = [[SPipe alloc] init];
        _playlistPipe = [[SPipe alloc] init];
        _queue = [[SQueue alloc] init];
        _albumArtMulticastManager = [[SMulticastSignalManager alloc] init];
        _currentAudioSession = [[SMetaDisposable alloc] init];
        _currentRemoteControls = [[SMetaDisposable alloc] init];
        _currentPlaylistDisposable = [[SMetaDisposable alloc] init];
        
        OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
        _routeChangeDisposable = [[[TGAudioSessionManager routeChange] deliverOn:_queue] startWithNext:^(id next)
        {
            TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
            if (strongSelf != nil)
            {
                [strongSelf->_queue dispatch:^
                {
                    if (!strongSelf->_changingProximity) {
                        if ([next intValue] == TGAudioSessionRouteChangePause)
                            [strongSelf controlPause];
                        else
                        {
                            if (strongSelf->_currentStatus.item != nil && !strongSelf->_currentStatus.paused)
                            {
                                [strongSelf->_player pause];
                                [strongSelf->_player play];
                            }
                        }
                    }
                }];
            }
        }];
        
        _proximityChangedNotification = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(proximityChanged:) name:TGDeviceProximityStateChangedNotification object:nil];
        _proximityChangeHolder = [[TGHolder alloc] init];
    }
    return self;
}

- (void)dealloc
{
    @synchronized (_compatSelfRef)
    {
        _compatSelfRef.value = nil;
    }
    if (_trackTransitionTask != OGPlatformBackgroundTaskInvalid)
    {
        OGPlatformBackgroundTaskIdentifier task = _trackTransitionTask;
        TGDispatchOnMainThread(^{
            OGPlatformEndBackgroundTask([UIApplication sharedApplication], task);
        });
    }
    [_currentAudioSession dispose];
    [_compatSessionLease dispose];
    [_currentRemoteControls dispose];
    [_routeChangeDisposable dispose];
}

- (void)og_compat_dropSessionLease
{
    [_compatSessionLease dispose];
    _compatSessionLease = nil;
}

- (void)og_compat_beginTransitionTask
{
    if (_trackTransitionTask != OGPlatformBackgroundTaskInvalid || [UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        return;

    OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
    __block OGPlatformBackgroundTaskIdentifier task = OGPlatformBackgroundTaskInvalid;
    OGCompatRunOnMainSync(^
    {
        task = OGPlatformBeginBackgroundTask([UIApplication sharedApplication], ^
        {
            OGPlatformEndBackgroundTask([UIApplication sharedApplication], task);
            TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
            if (strongSelf == nil)
                return;
            [strongSelf->_queue dispatch:^
            {
                if (strongSelf->_trackTransitionTask == task)
                    strongSelf->_trackTransitionTask = OGPlatformBackgroundTaskInvalid;
            }];
        });
    });
    _trackTransitionTask = task;
}

- (void)og_compat_endTransitionTask
{
    OGPlatformBackgroundTaskIdentifier task = _trackTransitionTask;
    _trackTransitionTask = OGPlatformBackgroundTaskInvalid;
    if (task != OGPlatformBackgroundTaskInvalid)
    {
        TGDispatchOnMainThread(^{
            OGPlatformEndBackgroundTask([UIApplication sharedApplication], task);
        });
    }
}

- (SSignal *)currentPlaylistAsync
{
    OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
        if (strongSelf != nil)
        {
            [strongSelf->_queue dispatch:^
            {
                [subscriber putNext:strongSelf->_currentPlaylist];
                [subscriber putCompletion];
            }];
        }
        return nil;
    }];
}


- (SSignal *)playlist
{
    return [[[self currentPlaylistAsync] then:_playlistPipe.signalProducer()] deliverOn:[SQueue mainQueue]];
}

- (SSignal *)currentStatusAsync
{
    OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
        if (strongSelf != nil)
        {
            [strongSelf->_queue dispatch:^
            {
                [subscriber putNext:strongSelf->_currentStatus];
                [subscriber putCompletion];
            }];
        }
        return nil;
    }];
}

- (SSignal *)playingStatus
{
    return [[[self currentStatusAsync] then:_playingStatusPipe.signalProducer()] deliverOn:[SQueue mainQueue]];
}

- (SSignal *)playlistFinished {
    return _playlistFinishedPipe.signalProducer();
}

- (void)updateAudioSession {
    [_queue dispatch:^{
        if (_currentPlaylist == nil) {
            [TGAppDelegateInstance.deviceProximityListeners removeHolder:_proximityChangeHolder];
            [_currentAudioSession setDisposable:nil];
        } else if (!_currentPlaylist.voice) {
            [TGAppDelegateInstance.deviceProximityListeners removeHolder:_proximityChangeHolder];
            [_currentAudioSession setDisposable:nil];
            if (_currentStatus != nil && !_currentStatus.paused && _compatSessionLease == nil) {
                TGMusicPlayer *player = self;
                _compatSessionLease = [[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypePlayMusic interrupted:^{
                    [player pauseMedia];
                }];
            }
        } else {
            TGMusicPlayer *player = self;
            bool headset = [TGMusicPlayer isHeadsetPluggedIn];
            bool overridePort = _proximityState && !headset;
            if (!headset) {
                [TGAppDelegateInstance.deviceProximityListeners addHolder:_proximityChangeHolder];
            } else {
                [TGAppDelegateInstance.deviceProximityListeners removeHolder:_proximityChangeHolder];
            }
            [_currentAudioSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:overridePort ? TGAudioSessionTypePlayAndRecordHeadphones : (!headset ? TGAudioSessionTypePlayAndRecord : TGAudioSessionTypePlayMusic) interrupted:^{
                if (!player->_changingProximity) {
                    [player pauseMedia];
                }
            }]];
        }
    }];
}

- (void)requestControlsWithPlay:(bool)play
{
    [_queue dispatch:^
    {
        if (_currentPlaylist.voice || _currentPlaylist == nil) {
            [_currentRemoteControls setDisposable:nil];
        } else {
            OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
            [_currentRemoteControls setDisposable:[[TGRemoteControlsManager instance] requestControlsWithPrevious:^
            {
                TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                if (strongSelf != nil)
                    [strongSelf controlPrevious];
            } next:^
            {
                TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                if (strongSelf != nil)
                    [strongSelf controlNext];
            } play:play ? ^
            {
                TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                if (strongSelf != nil)
                    [strongSelf controlPlayPause];
            } : nil pause: !play ? ^
            {
                TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                if (strongSelf != nil)
                    [strongSelf controlPlayPause];
            } : nil
            position:^(NSTimeInterval position)
            {
                TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                if (strongSelf != nil)
                {
                    NSTimeInterval fracPosition = strongSelf->_player.duration > FLT_EPSILON ? position / strongSelf->_player.duration : 0.0f;
                    [strongSelf controlSeekToPosition:fracPosition];
                }
            }]];
        }
    }];
}

- (void)cancelAudioSessionRequest
{
    [_queue dispatch:^
    {
        [_currentAudioSession setDisposable:nil];
        [_currentRemoteControls setDisposable:nil];
    }];
}

- (void)pauseMedia
{
    [self pauseMedia:nil];
}

- (void)pauseMedia:(void (^)(void))completion
{
    [_queue dispatch:^
    {
        if (_currentStatus != nil && !_currentStatus.paused)
        {
            [_updateTimer invalidate];
            _updateTimer = nil;
            
            CGFloat duration = _player.duration;
            CGFloat position = _player.playbackPosition;
            CGFloat offset = 0.0f;
            if (duration != duration || duration < FLT_EPSILON)
                duration = [[TGMusicPlayer attributesForItem:_currentStatus.item][@"duration"] intValue];
            if (!isnan(duration) && duration > FLT_EPSILON)
            {
                if (!isnan(position) && position > FLT_EPSILON)
                    offset = position / duration;
                else
                    offset = 0.0f;
            }
            else
                duration = 0.0f;
            
            [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:true offset:offset duration:duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
        }
        
        void (^paused)(void) = ^{
            [_queue dispatch:^{
                if (_currentStatus == nil || _currentStatus.paused)
                {
                    [_currentAudioSession setDisposable:nil];
                    [self og_compat_dropSessionLease];
                    [self requestControlsWithPlay:true];
                }
                if (completion != nil)
                    completion();
            }];
        };
        if (_player != nil)
            [_player pause:paused];
        else
            paused();
    }];
}

- (CGFloat)updatePositionTimerTimeout
{
    return 10.0 / 60.0f;
}

- (void)startUpdatePositionTimer
{
    [_updateTimer invalidate];
    
    OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
    _updateTimer = [[STimer alloc] initWithTimeout:[self updatePositionTimerTimeout] repeat:true completion:^
    {
        TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
        if (strongSelf != nil)
            [strongSelf updateScrubbingPosition];
    } queue:_queue];
    [self updateScrubbingPosition];
    [_updateTimer start];
}

- (void)playMediaFromItem:(TGMusicPlayerItem *)item
{
    [self playMediaFromItem:item force:false];
}

- (void)playMediaFromItem:(TGMusicPlayerItem *)item force:(bool)force
{
    [_queue dispatch:^
    {
        if (_currentStatus != nil && [_currentStatus.item.key isEqual:item.key] && !force)
        {
            if (_currentStatus.downloadedStatus.playable)
            {
                if (_currentStatus.paused)
                {
                    CGFloat duration = _player.duration;
                    CGFloat position = _player.absolutePlaybackPosition;
                    CGFloat offset = 0.0f;
                    if (duration != duration || duration < FLT_EPSILON)
                        duration = [[TGMusicPlayer attributesForItem:item][@"duration"] intValue];
                    if (!isnan(duration) && duration > FLT_EPSILON)
                    {
                        if (!isnan(position) && position > FLT_EPSILON)
                            offset = position / duration;
                        else
                            offset = 0.0f;
                    }
                    else
                        duration = 0.0f;
                    
                    [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:false offset:offset duration:duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
                    
                    [self requestControlsWithPlay:false];
                    [self updateAudioSession];
                    [_player play];
                    
                    [self startUpdatePositionTimer];
                }
                else
                {
                    [_updateTimer invalidate];
                    _updateTimer = nil;
                    
                    CGFloat duration = _player.duration;
                    CGFloat position = (CGFloat)_player.absolutePlaybackPosition;
                    CGFloat offset = 0.0f;
                    if (duration != duration || duration < FLT_EPSILON)
                        duration = [[TGMusicPlayer attributesForItem:item][@"duration"] intValue];
                    if (!isnan(duration) && duration > FLT_EPSILON)
                    {
                        if (!isnan(position) && position > FLT_EPSILON)
                            offset = position / duration;
                        else
                            offset = 0.0f;
                    }
                    else
                        duration = 0.0f;
                    
                    [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:true offset:offset duration:duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
                    
                    if (_player != nil) {
                        [_player pause:^{
                            [self requestControlsWithPlay:true];
                        }];
                    } else {
                        [self requestControlsWithPlay:true];
                    }
                }
            }
        }
        else
        {
            [_updateTimer invalidate];
            _updateTimer = nil;
            
            if (item == nil)
            {
                [_currentItemDisposable setDisposable:nil];
                [self setCurrentStatus:nil];
                
                if (_player != nil) {
                    [_player pause:^{
                        [self cancelAudioSessionRequest];
                    }];
                } else {
                    [self cancelAudioSessionRequest];
                }
                _player = nil;
                
                [self updateNextItemAvailability];
            }
        else
        {
            bool keepFinishedPlayer = !_currentPlaylist.voice && [_player isFinished];
            if (!keepFinishedPlayer)
            {
                [_player stop];
                _player = nil;
            }
                
                OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
                
                CGFloat duration = [[TGMusicPlayer attributesForItem:item][@"duration"] intValue];
                TGMusicPlayerItemPosition itemPosition = [TGMusicPlayer itemPosition:item inArray:_currentPlaylist.items];
                
                [_nextItemDisposable setDisposable:nil];
                
                if (_currentItemDisposable == nil)
                    _currentItemDisposable = [[SMetaDisposable alloc] init];
                __block bool streaming = false;
                if (![[NSFileManager defaultManager] fileExistsAtPath:[TGMusicPlayerItemSignals pathForItem:item]] && (_player == nil || [_player isFinished]))
                    streaming = [self playItemStreaming:item];
                bool allowDownload = !(streaming && [(NSNumber *)item.key intValue] == 0);
                [_currentItemDisposable setDisposable:[[[TGMusicPlayerItemSignals itemAvailability:item priority:true allowDownload:allowDownload] deliverOn:_queue] startWithNext:^(id next)
                {
                    TGMusicPlayerItemAvailability availability = TGMusicPlayerItemAvailabilityUnpack([next longLongValue]);
                    TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                    if (strongSelf != nil)
                    {
                        if (!availability.downloaded && !streaming && (strongSelf->_player == nil || [strongSelf->_player isFinished]))
                            streaming = [strongSelf playItemStreaming:item];
                        if (availability.downloaded || streaming)
                        {
                            if (!streaming && (strongSelf->_player == nil || [strongSelf->_player isFinished]))
                            {
                                [strongSelf playItem:item];
                            }
                            if (streaming && strongSelf->_currentStatus != nil)
                            {
                                [strongSelf setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:item player:strongSelf->_player.audioPlayer position:itemPosition paused:strongSelf->_currentStatus.paused offset:strongSelf->_currentStatus.offset duration:duration rate:strongSelf->_currentStatus.rate albumArt:strongSelf->_currentStatus.albumArt albumArtSync:strongSelf->_currentStatus.albumArtSync downloadedStatus:availability.downloaded ? TGMusicPlayerDownloadingStatusMake(true, false, 1.0f) : TGMusicPlayerDownloadingStatusMakeStreaming(availability.progress) isVoice:item.isVoice orderType:strongSelf->_currentStatus.orderType repeatType:strongSelf->_currentStatus.repeatType]];
                            }
                        }
                        else
                        {
                            [strongSelf setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:item player:strongSelf->_player.audioPlayer position:itemPosition paused:true offset:0.0f duration:duration rate:strongSelf->_currentStatus.rate albumArt:nil albumArtSync:nil downloadedStatus:TGMusicPlayerDownloadingStatusMake(false, availability.downloading, availability.progress) isVoice:item.isVoice orderType:!item.isVoice ? [strongSelf storedOrderTypeValue] : TGMusicPlayerOrderTypeOldestFirst repeatType:!item.isVoice ? [strongSelf storedRepeatTypeValue] : TGMusicPlayerRepeatTypeNone]];
                        }
                    }
                }]];
                
                [self updateNextItemAvailability];
            }
        }
    }];
}

- (TGMusicPlayerOrderType)storedOrderTypeValue
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSNumber *storedOrderType = [defaults objectForKey:@"musicPlayerOrderType_v2"];
    if (storedOrderType != nil)
        return (TGMusicPlayerOrderType)[storedOrderType integerValue];
    
    bool shuffle = [[defaults objectForKey:@"musicPlayerShuffle_v1"] boolValue] || [[defaults objectForKey:@"musicPlayerOrderType_v1"] integerValue] == TGMusicPlayerOrderTypeShuffle;
    TGMusicPlayerOrderType orderType = shuffle ? TGMusicPlayerOrderTypeShuffle : TGMusicPlayerOrderTypeOldestFirst;
    [defaults removeObjectForKey:@"musicPlayerShuffle_v1"];
    [defaults removeObjectForKey:@"musicPlayerOrderType_v1"];
    [defaults setObject:@(orderType) forKey:@"musicPlayerOrderType_v2"];
    return orderType;
}

- (TGMusicPlayerRepeatType)storedRepeatTypeValue
{
    return (TGMusicPlayerRepeatType)[[[NSUserDefaults standardUserDefaults] objectForKey:@"musicPlayerRepeatType_v1"] integerValue];
}

- (bool)playItemStreaming:(TGMusicPlayerItem *)item
{
    NSString *publishPath = nil;
    NSString *pathExtension = nil;
    NSString *mimeType = nil;
    OGMediaFetchDescriptor *descriptor = nil;
    if ([item.media isKindOfClass:[TGVideoMediaAttachment class]])
    {
        if (![OGMediaFetchDescriptor isStreamableVideoAttachment:item.media])
            return false;
        descriptor = [OGMediaFetchDescriptor descriptorForVideoAttachment:item.media publishPath:&publishPath];
        mimeType = @"video/mp4";
        pathExtension = @"mp4";
    }
    else if ([item.media isKindOfClass:[TGDocumentMediaAttachment class]])
    {
        TGDocumentMediaAttachment *document = item.media;
        if (![OGMediaFetchDescriptor isStreamableDocument:document])
            return false;
        descriptor = [OGMediaFetchDescriptor descriptorForDocument:document publishPath:&publishPath];
        mimeType = [OGMediaFetchDescriptor streamMimeTypeForDocument:document pathExtension:&pathExtension];
    }
    if (descriptor == nil || mimeType == nil)
        return false;
    if ([(NSNumber *)item.key intValue] == 0)
    {
        publishPath = [TGMusicPlayerItemSignals pathForItem:item];
        if (publishPath.length == 0)
            return false;
        descriptor.storePath = [publishPath stringByAppendingString:@".parts"];
    }
    OGMediaStream *stream = [[OGMediaStreamServer sharedServer] streamWithDescriptor:descriptor publishPath:publishPath mimeType:mimeType pathExtension:pathExtension];
    if (stream == nil)
        return false;
    NSTimeInterval duration = [[TGMusicPlayer attributesForItem:item][@"duration"] doubleValue];
    TGModernConversationAudioPlayer *player = [[TGModernConversationAudioPlayer alloc] initWithStream:stream pathExtension:pathExtension duration:duration music:!_currentPlaylist.voice controlAudioSession:false];
    if (player.audioPlayer == nil)
    {
        [stream invalidate];
        return false;
    }
    [_player stop];
    _player = player;
    self.activeStream = stream;
    [self startPlayer:item path:publishPath];
    return true;
}

- (void)playItem:(TGMusicPlayerItem *)item
{
    NSString *path = [TGMusicPlayerItemSignals pathForItem:item];
    if ([path pathExtension].length == 0 && item.isVideo)
    {
        [[NSFileManager defaultManager] createSymbolicLinkAtPath:[path stringByAppendingString:@".mov"] withDestinationPath:[path lastPathComponent] error:nil];
        path = [path stringByAppendingString:@".mov"];
    }
    if (!([_player isFinished] && [_player replaceWithFilePath:path]))
    {
        [_player stop];
        _player = [[TGModernConversationAudioPlayer alloc] initWithFilePath:path music:!_currentPlaylist.voice controlAudioSession:false];
    }
    self.activeStream = nil;
    [self startPlayer:item path:path];
}

- (void)startPlayer:(TGMusicPlayerItem *)item path:(NSString *)path
{
    if (_currentPlaylist.markItemAsViewed) {
        _currentPlaylist.markItemAsViewed(item);
    }
    
    [_player setRate:_rate];
    _player.delegate = self;

    if (!_currentPlaylist.voice && _compatSessionLease == nil)
    {
        TGMusicPlayer *player = self;
        _compatSessionLease = [[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypePlayMusic interrupted:^
        {
            [player pauseMedia];
        }];
    }
    
    CGFloat duration = _player.duration;
    CGFloat position = (CGFloat)_player.absolutePlaybackPosition;
    CGFloat offset = 0.0f;
    
    if (isnan(duration) || duration < FLT_EPSILON)
        duration = [[TGMusicPlayer attributesForItem:item][@"duration"] intValue];
    
    if (!isnan(duration) && duration > FLT_EPSILON)
    {
        if (!isnan(position) && position > FLT_EPSILON)
            offset = position / duration;
        else
            offset = 0.0f;
    }
    else
        duration = 0.0f;
    
    TGMusicPlayerOrderType orderType = [self storedOrderTypeValue];
    TGMusicPlayerRepeatType repeatType = [self storedRepeatTypeValue];
    
    NSURL *itemUrl = [NSURL fileURLWithPath:path];
    TGMusicPlayerItemPosition itemPosition = [TGMusicPlayer itemPosition:item inArray:_currentPlaylist.items];
    [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:item player:_player.audioPlayer position:itemPosition paused:false offset:offset duration:duration rate:_rate albumArt:[TGMusicPlayerItemSignals _albumArtForUrl:itemUrl multicastManager:_albumArtMulticastManager] albumArtSync:[TGMusicPlayerItemSignals _albumArtSyncForUrl:itemUrl] downloadedStatus:[_player isStreaming] ? TGMusicPlayerDownloadingStatusMakeStreaming(0.0f) : TGMusicPlayerDownloadingStatusMake(true, false, 1.0f) isVoice:item.isVoice orderType:!item.isVoice ? orderType : TGMusicPlayerOrderTypeOldestFirst repeatType:!item.isVoice ? repeatType : TGMusicPlayerRepeatTypeNone]];
    
    [self requestControlsWithPlay:false];
    [_player play];
    [self og_compat_endTransitionTask];
    
    [self startUpdatePositionTimer];
}

- (void)updateNextItemAvailability
{
    TGMusicPlayerItem *nextItem = nil;
    
    NSArray *items = (_currentStatus.orderType == TGMusicPlayerOrderTypeShuffle  ? _currentPlaylist.shuffledItems : _currentPlaylist.items);
    
    if (_currentStatus.item != nil)
    {
        NSInteger index = -1;
        for (TGMusicPlayerItem *item in items)
        {
            index++;
            if (TGObjectCompare(_currentStatus.item.key, item.key))
            {
                NSInteger nextIndex = [self nextIndexWithIndex:index items:items forward:true isVoice:item.isVoice allowReturn:_currentStatus.repeatType == TGMusicPlayerRepeatTypeAll orderType:_currentStatus.orderType];
                if (nextIndex >= 0 && nextIndex < (NSInteger)items.count)
                    nextItem = items[nextIndex];
                break;
            }
        }
    }
    
    if (!TGObjectCompare(nextItem.key, _currentNextItem.key))
    {
        _currentNextItem = nextItem;
        
        if (_currentNextItem != nil)
        {
            if (_nextItemDisposable == nil)
                _nextItemDisposable = [[SMetaDisposable alloc] init];
            
            [_nextItemDisposable setDisposable:nil];
            [_nextItemDisposable setDisposable:[[[TGMusicPlayerItemSignals itemAvailability:_currentNextItem priority:true allowDownload:!OGPlatformMediaDownloadsRequireUserAction()] deliverOn:_queue] startWithNext:^(id next)
            {
                TGMusicPlayerItemAvailability availability = TGMusicPlayerItemAvailabilityUnpack([next longLongValue]);
                if (availability.downloaded && _player != nil && _currentNextItem != nil)
                {
                    [_player prepareNextFilePath:[TGMusicPlayerItemSignals pathForItem:_currentNextItem]];
                }
            }]];
        }
        else {
            [_nextItemDisposable setDisposable:nil];
        }
    }
}

+ (TGMusicPlayerItemPosition)itemPosition:(TGMusicPlayerItem *)item inArray:(NSArray *)array
{
    NSInteger index = -1;
    for (TGMusicPlayerItem *listItem in array)
    {
        index++;
        if (TGObjectCompare(listItem.key, item.key))
            return (TGMusicPlayerItemPosition){.index = (NSUInteger)index, .count = array.count};
    }
    return (TGMusicPlayerItemPosition){.index = 0, .count = 1};
}

- (id)playlistMetadata {
    id result = nil;
    @synchronized(self) {
        result = _playlistMetadata;
    }
    return result;
}

- (void)setPlaylist:(SSignal *)playlist initialItemKey:(id<NSCopying>)initialItemKey metadata:(id)metadata {
    @synchronized(self) {
        _playlistMetadata = metadata;
    }
    
    [_queue dispatch:^{
        [_currentPlaylistDisposable setDisposable:nil];
        
        if (playlist == nil) {
            _rate = 1.0f;
            [self _setPlaylist:nil initialItemKey:nil forceRestart:true];
        }
        else
        {
            OGCompatMusicPlayerRef *selfRef = _compatSelfRef;
            id<SDisposable> delayedSwitchItemDisposable = [[[[SSignal complete] onStart:^
            {
                TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                if (strongSelf != nil)
                    [strongSelf playMediaFromItem:nil];
            }] delay:1.0 onQueue:_queue] startWithNext:nil];
            __block bool firstValue = true;
            [_currentPlaylistDisposable setDisposable:[[playlist deliverOn:_queue] startWithNext:^(TGMusicPlayerPlaylist *value)
            {
                [delayedSwitchItemDisposable dispose];
                
                TGMusicPlayer *strongSelf = OGCompatResolveMusicPlayer(selfRef);
                if (strongSelf != nil)
                {
                    [strongSelf _setPlaylist:value initialItemKey:initialItemKey forceRestart:firstValue];
                    firstValue = false;
                }
            }]];
        }
    }];
}

- (void)_setPlaylist:(TGMusicPlayerPlaylist *)playlist initialItemKey:(id<NSCopying>)initialItemKey forceRestart:(bool)forceRestart
{
    [_queue dispatch:^
    {
        if (!TGObjectCompare(_currentPlaylist, playlist))
        {
            TGMusicPlayerPlaylist *previousPlaylist = _currentPlaylist;
            bool shuffle = [self storedOrderTypeValue] == TGMusicPlayerOrderTypeShuffle;
            
            _currentPlaylist = (previousPlaylist.items.count == 0 && shuffle) ? [playlist playlistWithShuffledItems] : playlist;
            if (_currentPlaylist.voice)
                [self og_compat_dropSessionLease];
            if (playlist != nil) {
                [self updateAudioSession];
            }
            
            if (_currentPlaylist == nil || _currentPlaylist.items.count == 0)
                [self playMediaFromItem:nil];
            else
            {
                bool currentItemFound = false;
                id<NSObject> nextItemKey = nil;
                if (!forceRestart && _currentStatus != nil)
                {
                    bool match = false;
                    bool found = false;
                    for (TGMusicPlayerItem *previousItem in previousPlaylist.items)
                    {
                        if ([previousItem.key isEqual:_currentStatus.item.key]) {
                            match = true;
                        }
                        
                        if (match) {
                            for (TGMusicPlayerItem *item in _currentPlaylist.items)
                            {
                                if ([item.key isEqual:_currentStatus.item.key])
                                {
                                    if (shuffle)
                                        _currentPlaylist = [_currentPlaylist playlistWithShuffleFromPlaylist:previousPlaylist currentItem:item];
                                    
                                    TGMusicPlayerItemPosition itemPosition = [TGMusicPlayer itemPosition:item inArray:_currentPlaylist.items];
                                    
                                    [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:item player:_player.audioPlayer position:itemPosition paused:_currentStatus.paused offset:_currentStatus.offset duration:_currentStatus.duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
                                    
                                    currentItemFound = true;
                                    found = true;
                                    break;
                                } else if ([item.key isEqual:previousItem.key]) {
                                    nextItemKey = item.key;
                                    found = true;
                                    break;
                                }
                            }
                        }
                        
                        if (found) {
                            break;
                        }
                    }
                    
                    if (!currentItemFound)
                    {
                        id<NSObject, NSCopying> aliasKey = _currentPlaylist.itemKeyAliases[_currentStatus.item.key];
                        if (aliasKey != nil)
                        {
                            for (TGMusicPlayerItem *item in _currentPlaylist.items)
                            {
                                if ([aliasKey isEqual:_currentStatus.item.key])
                                {
                                    if (shuffle)
                                        _currentPlaylist = [_currentPlaylist playlistWithShuffleFromPlaylist:previousPlaylist currentItem:item];
                                    
                                    TGMusicPlayerItemPosition itemPosition = [TGMusicPlayer itemPosition:item inArray:_currentPlaylist.items];
                                    
                                    [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:item player:_player.audioPlayer position:itemPosition paused:_currentStatus.paused offset:_currentStatus.offset duration:_currentStatus.duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
                                    
                                    currentItemFound = true;
                                    break;
                                }
                            }
                        }
                    }
                }
                
                if (!currentItemFound) {
                    if (shuffle)
                        _currentPlaylist = [_currentPlaylist playlistWithShuffledItems];
                    
                    if (nextItemKey != nil) {
                        for (TGMusicPlayerItem *item in _currentPlaylist.items)
                        {
                            if ([item.key isEqual:nextItemKey])
                            {
                                [self playMediaFromItem:item];
                                currentItemFound = true;
                                break;
                            }
                        }
                    } else if (initialItemKey != nil) {
                        for (TGMusicPlayerItem *item in _currentPlaylist.items)
                        {
                            if ([item.key isEqual:initialItemKey])
                            {
                                [self playMediaFromItem:item];
                                currentItemFound = true;
                                break;
                            }
                        }
                    }
                }
                
                NSArray *items = shuffle ? _currentPlaylist.shuffledItems : _currentPlaylist.items;
                
                if (!currentItemFound)
                    [self playMediaFromItem:items.firstObject];
            }
            
            [self updateNextItemAvailability];
            
            if (playlist == nil) {
                [self og_compat_dropSessionLease];
                [self updateAudioSession];
                [_currentRemoteControls setDisposable:nil];
            }
            
            _playlistPipe.sink(_currentPlaylist);
        }
    }];
}

- (void)controlPlay
{
    [_queue dispatch:^
    {
        TGMusicPlayerStatus *status = _currentStatus;
        if (status != nil && status.paused)
            [self playMediaFromItem:status.item force:_player == nil];
    }];
}

- (void)controlPlayPause {
    [_queue dispatch:^ {
        if (_currentStatus != nil) {
            if (_currentStatus.paused) {
                [self playMediaFromItem:_currentStatus.item force:_player == nil];
            } else {
                [self playMediaFromItem:_currentStatus.item];
            }
        }
    }];
}

- (void)controlPause {
    [self controlPause:nil];
}

- (void)controlPause:(void (^)())completion
{
    [self pauseMedia:completion];
}

- (NSInteger)nextIndexWithIndex:(NSInteger)index items:(NSArray *)items forward:(bool)forward isVoice:(bool)isVoice allowReturn:(bool)allowReturn orderType:(TGMusicPlayerOrderType)orderType
{
    if (isVoice)
        orderType = TGMusicPlayerOrderTypeOldestFirst;
    
    NSInteger nextIndex = 0;
    if (orderType == TGMusicPlayerOrderTypeOldestFirst)
    {
        if (forward)
        {
            nextIndex = index + 1;
            if (allowReturn && nextIndex >= (NSInteger)items.count)
                nextIndex = 0;
        }
        else
        {
            if (_currentStatus.duration == _currentStatus.duration && _currentStatus.duration > FLT_EPSILON && _currentStatus.offset * _currentStatus.duration > 5.0)
            {
                nextIndex = index;
            }
            else
            {
                nextIndex = index - 1;
                if (allowReturn && nextIndex < 0)
                    nextIndex = items.count - 1;
            }
        }
    }
    else
    {
        if (forward)
        {
            nextIndex = index - 1;
            if (allowReturn && nextIndex < 0)
                nextIndex = items.count - 1;
        }
        else
        {
            if (_currentStatus.duration == _currentStatus.duration && _currentStatus.duration > FLT_EPSILON && _currentStatus.offset * _currentStatus.duration > 5.0)
            {
                nextIndex = index;
            }
            else
            {
                nextIndex = index + 1;
                if (allowReturn && nextIndex >= (NSInteger)items.count)
                    nextIndex = 0;
            }
        }
    }
    return nextIndex;
}

- (void)controlAdvance:(bool)forward
{
    [_queue dispatch:^
    {
        NSArray *items = _currentStatus.orderType == TGMusicPlayerOrderTypeShuffle ? _currentPlaylist.shuffledItems : _currentPlaylist.items;
        
        if (items.count != 0)
        {
            if (_currentStatus.item != nil)
            {
                NSInteger index = -1;
                for (TGMusicPlayerItem *item in items)
                {
                    index++;
                    
                    if (TGObjectCompare(item.key, _currentStatus.item.key))
                    {
                        NSInteger nextIndex = [self nextIndexWithIndex:index items:items forward:forward isVoice:_currentStatus.isVoice allowReturn:true orderType:_currentStatus.orderType];
                        if (nextIndex == index)
                        {
                            [self _seekToPosition:0.0];
                            [self controlPlay];
                        }
                        else
                            [self playMediaFromItem:items[nextIndex]];
                        break;
                    }
                }
            }
            else
                [self playMediaFromItem:items.firstObject];
        }
    }];
}

- (void)controlNext
{
    [self controlAdvance:true];
}

- (void)controlPrevious
{
    [self controlAdvance:false];
}

- (void)controlSeekToPosition:(CGFloat)position
{
    [_queue dispatch:^
    {
        CGFloat duration = _player.duration;
        if (!isnan(duration) && duration > FLT_EPSILON)
            [self _seekToPosition:duration * position];
    }];
}

- (void)controlSetRate:(CGFloat)rate
{
    _rate = rate;
    
    [_queue dispatch:^
    {
        [_player setRate:rate];
        [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:_currentStatus.paused offset:_currentStatus.offset duration:_currentStatus.duration rate:rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
    }];
}

- (void)controlToggleRate
{
    CGFloat targetRate = 1.0f;
    
    if (_rate < 1.75f)
        targetRate = 1.8f;
    else
        targetRate = 1.0f;
    
    [self controlSetRate:targetRate];
}

- (void)_dispatch:(dispatch_block_t)block {
    [_queue dispatch:^{
        if (block) {
            block();
        }
    }];
}

- (void)controlOrder {
    [_queue dispatch:^{
        TGMusicPlayerOrderType orderType = _currentStatus.orderType;
        
        switch (orderType) {
            case TGMusicPlayerOrderTypeOldestFirst:
                orderType = TGMusicPlayerOrderTypeNewestFirst;
                break;
                
            case TGMusicPlayerOrderTypeNewestFirst:
                orderType = TGMusicPlayerOrderTypeShuffle;
                break;
                
            default:
                orderType = TGMusicPlayerOrderTypeOldestFirst;
                break;
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:@(orderType) forKey:@"musicPlayerOrderType_v2"];
        
        if (orderType == TGMusicPlayerOrderTypeShuffle && ![_currentPlaylist hasShuffle])
            [self _setPlaylist:[_currentPlaylist playlistWithShuffledItems] initialItemKey:nil forceRestart:false];
        
        [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:_currentStatus.paused offset:_currentStatus.offset duration:_currentStatus.duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:orderType repeatType:_currentStatus.repeatType]];
    }];
}

- (void)controlRepeat {
    [_queue dispatch:^ {
        TGMusicPlayerRepeatType repeatType = _currentStatus.repeatType;
        switch (repeatType) {
            case TGMusicPlayerRepeatTypeNone:
                repeatType = TGMusicPlayerRepeatTypeAll;
                break;
                 
            case TGMusicPlayerRepeatTypeAll:
                repeatType = TGMusicPlayerRepeatTypeOne;
                break;
                 
            default:
                repeatType = TGMusicPlayerRepeatTypeNone;
                break;
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:@(repeatType) forKey:@"musicPlayerRepeatType_v1"];
         
        [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:_currentStatus.paused offset:_currentStatus.offset duration:_currentStatus.duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:repeatType]];
    }];
}

- (void)setCurrentStatus:(TGMusicPlayerStatus *)currentStatus
{
    TGMusicPlayerStatus *previousStatus = _currentStatus;
    _currentStatus = currentStatus;
#if OG_PLUGINS_AVAILABLE && __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    if (!currentStatus.paused && [currentStatus.player isKindOfClass:[TGNativeAudioPlayer class]])
        OGPluginMusicAudioTapAttach(((TGNativeAudioPlayer *)currentStatus.player).player.currentItem);
#endif
    _playingStatusPipe.sink(currentStatus);
    
    if (!TGObjectCompare(currentStatus.item.key, previousStatus.item.key))
    {
        if (currentStatus.item == nil)
        {
            [_currentAlbumArtDisposable dispose];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
            if (OGCompatNowPlayingAvailable())
            {
                TGDispatchOnMainThread(^{
                    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nil];
                });
            }
#endif
        }
        else
        {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
            NSDictionary *attributes = [TGMusicPlayer attributesForItem:currentStatus.item];

            if (OGCompatNowPlayingAvailable())
            {
                if (_currentAlbumArtDisposable == nil)
                    _currentAlbumArtDisposable = [[SMetaDisposable alloc] init];

                [_currentAlbumArtDisposable setDisposable:[[[[SSignal single:nil] then:[TGMusicPlayerItemSignals albumArtForItem:currentStatus.item thumbnail:false]] deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
                {
                NSMutableDictionary *songInfo = [[NSMutableDictionary alloc] init];
                
                if (image != nil)
                {
                    MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:image];
                    [songInfo setObject:albumArt forKey:MPMediaItemPropertyArtwork];
                }
                
                NSString *title = @"";
                NSString *performer = @"";
                
                if (attributes[@"title"] != nil)
                    title = attributes[@"title"];
                if (attributes[@"performer"] != nil)
                    performer = attributes[@"performer"];
                
                if (title.length == 0)
                {
                    if ([currentStatus.item.media isKindOfClass:[TGDocumentMediaAttachment class]]) {
                        title = ((TGDocumentMediaAttachment *)currentStatus.item.media).fileName;
                        
                        for (id attribute in ((TGDocumentMediaAttachment *)currentStatus.item.media).attributes) {
                            if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                                if (((TGDocumentAttributeAudio *)attribute).isVoice) {
                                    title = TGLocalized(@"MusicPlayer.VoiceNote");
                                    performer = @"Telegram";
                                }
                                break;
                            }
                        }
                    }
                }
                
                if (title.length == 0)
                    title = @"Unknown Track";
                
                if (performer.length == 0)
                    performer = @"Unknown Artist";
                
                [songInfo setObject:title forKey:MPMediaItemPropertyTitle];
                [songInfo setObject:performer forKey:MPMediaItemPropertyArtist];
                OGCompatFillPlaybackProgress(songInfo, currentStatus);
                
                    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:songInfo];
                }]];
            }
            else
            {
                [_currentAlbumArtDisposable setDisposable:nil];
            }
#else
            [_currentAlbumArtDisposable setDisposable:nil];
#endif
        }
    }

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    bool itemChanged = !TGObjectCompare(currentStatus.item.key, previousStatus.item.key);
    bool playbackStateChanged = currentStatus != nil && previousStatus != nil && currentStatus.paused != previousStatus.paused;
    if (currentStatus.item != nil && (itemChanged || playbackStateChanged) && OGCompatNowPlayingAvailable())
    {
        TGDispatchOnMainThread(^{
            MPNowPlayingInfoCenter *infoCenter = [MPNowPlayingInfoCenter defaultCenter];
            NSMutableDictionary *songInfo = [[infoCenter nowPlayingInfo] mutableCopy];
            if (songInfo != nil)
            {
                OGCompatFillPlaybackProgress(songInfo, currentStatus);
                [infoCenter setNowPlayingInfo:songInfo];
            }
        });
    }
#endif
}

- (void)_seekToPosition:(NSTimeInterval)position
{
    [_queue dispatch:^
    {
        NSTimeInterval duration = _player.duration;
        
        if (duration > DBL_EPSILON) {
            [_player play:(float)(position / duration)];
            
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
            if (OGCompatNowPlayingAvailable())
            {
                NSMutableDictionary *info = [[[MPNowPlayingInfoCenter defaultCenter] nowPlayingInfo] mutableCopy];
                if (info != nil)
                {
                    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(position);
                    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:info];
                }
            }
#endif
        }
    }];
}

- (void)updateScrubbingPosition
{
    if (_player != nil)
    {
        CGFloat duration = _player.duration;
        CGFloat position = _player.absolutePlaybackPosition;
        CGFloat offset = 0.0f;
        if (duration != duration || duration < FLT_EPSILON)
            duration = [[TGMusicPlayer attributesForItem:_currentStatus.item][@"duration"] intValue];
        if (!isnan(duration) && duration > FLT_EPSILON)
        {
            if (!isnan(position) && position > FLT_EPSILON)
                offset = position / duration;
            else
                offset = 0.0f;

            NSTimeInterval remaining = duration - position;
            if (0.0 < remaining && remaining <= 8.0)
                [self og_compat_beginTransitionTask];
        }
        
        [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:false offset:offset duration:duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
    }
}

- (void)audioPlayerDidFinish
{
    [_queue dispatch:^
    {
        if (OGPlatformMediaDownloadsRequireUserAction() && _currentNextItem != nil && _currentStatus.repeatType != TGMusicPlayerRepeatTypeOne)
        {
            NSString *nextPath = [TGMusicPlayerItemSignals pathForItem:_currentNextItem];
            if (nextPath.length == 0 || ![[NSFileManager defaultManager] fileExistsAtPath:nextPath])
            {
                [self controlPause];
                return;
            }
        }
        [self og_compat_beginTransitionTask];
        if (_currentStatus.item != nil)
        {
            if (_currentStatus.repeatType == TGMusicPlayerRepeatTypeOne)
            {
                [self playMediaFromItem:_currentStatus.item force:true];
            }
            else
            {
                NSInteger index = -1;
                for (TGMusicPlayerItem *item in _currentPlaylist.items)
                {
                    index++;
                    if (TGObjectCompare(item.key, _currentStatus.item.key))
                    {
                        NSInteger lastIndex = item.isVoice || _currentStatus.orderType == TGMusicPlayerOrderTypeOldestFirst ? (NSInteger)_currentPlaylist.items.count - 1 : 0;
                        if (index == lastIndex)
                        {
                            if (_currentPlaylist.voice) {
                                id metadata = [self playlistMetadata];
                                [self setPlaylist:nil initialItemKey:nil metadata:nil];
								[self requestControlsWithPlay:true];
                                
                                _playlistFinishedPipe.sink(metadata);
                            } else {
                                if (_currentStatus.repeatType == TGMusicPlayerRepeatTypeNone)
                                {
                                    [self _seekToPosition:0.0f];
                                    
                                    if (_player != nil) {
                                        [_player pause:^{
                                            [self requestControlsWithPlay:true];
                                        }];
                            		} else {
                                		[self requestControlsWithPlay:true];
                            		}
                                    
                                    [_updateTimer invalidate];
                                    _updateTimer = nil;
                                    
                                    CGFloat duration = _player.duration;
                                    if (isnan(duration) || duration < FLT_EPSILON)
                                        duration = 0.0f;
                                    
                                    [self setCurrentStatus:[[TGMusicPlayerStatus alloc] initWithItem:_currentStatus.item player:_player.audioPlayer position:_currentStatus.position paused:true offset:0.0f duration:duration rate:_currentStatus.rate albumArt:_currentStatus.albumArt albumArtSync:_currentStatus.albumArtSync downloadedStatus:_currentStatus.downloadedStatus isVoice:_currentStatus.isVoice orderType:_currentStatus.orderType repeatType:_currentStatus.repeatType]];
                                }
                                else
                                {
                                    bool force = !_currentPlaylist.voice && _currentPlaylist.items.count == 1;
                                    [self playMediaFromItem:_currentPlaylist.voice || _currentStatus.orderType == TGMusicPlayerOrderTypeOldestFirst ? _currentPlaylist.items.firstObject : _currentPlaylist.items.lastObject force:force];
                                }
                            }
                            _rate = 1.0f;
                        }
                        else
                        {
                            TGModernConversationAudioPlayer *retired = _player;
                            _player = nil;
                            [retired pause:^{}];
                            [self controlAdvance:true];
                        }
                        break;
                    }
                }
            }
        }
    }];
}

+ (double)mediaBitrateForItem:(TGMusicPlayerItem *)item
{
    double duration = [[self attributesForItem:item][@"duration"] doubleValue];
    if (![item.media isKindOfClass:[TGDocumentMediaAttachment class]] || duration <= 0.0)
        return 0.0;
    return (double)((TGDocumentMediaAttachment *)item.media).size * 8.0 / duration;
}

- (double)currentStreamDownloadRate
{
    OGMediaStream *stream = self.activeStream;
    if (stream == nil || [stream isComplete])
        return -1.0;
    return [stream downloadRate];
}

+ (NSDictionary *)attributesForItem:(TGMusicPlayerItem *)item
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    if (item.performer.length != 0) {
        dict[@"performer"] = item.performer;
    }
    
    if (item.title.length != 0) {
        dict[@"title"] = item.title;
    }
    
    dict[@"duration"] = @(item.duration);
    
    return dict;
}

+ (bool)isHeadsetPluggedIn
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if ([session respondsToSelector:@selector(currentRoute)])
    {
        AVAudioSessionRouteDescription *route = [session currentRoute];
        for (AVAudioSessionPortDescription *desc in [route outputs])
        {
            if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones])
                return true;
            if ([[desc portType] isEqualToString:AVAudioSessionPortBluetoothA2DP])
                return true;
        }
        return false;
    }
#endif
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
    CFStringRef route = NULL;
    UInt32 routeSize = sizeof(route);
    if (AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &routeSize, &route) != noErr || route == NULL)
        return false;
    bool pluggedIn = CFStringFind(route, CFSTR("Headphone"), 0).location != kCFNotFound ||
        CFStringFind(route, CFSTR("Headset"), 0).location != kCFNotFound ||
        CFStringFind(route, CFSTR("Bluetooth"), 0).location != kCFNotFound;
    CFRelease(route);
    return pluggedIn;
#else
    return false;
#endif
}

- (void)proximityChanged:(NSNotification *)__unused notification
{
    bool proximityState = TGAppDelegateInstance.deviceProximityState;
    [_queue dispatch:^{
        _proximityState = proximityState;
        if (_currentPlaylist.voice && _currentStatus != nil && ![TGMusicPlayer isHeadsetPluggedIn]) {
            _changingProximity = true;
            [self updateAudioSession];
            _changingProximity = false;
            
            if (_proximityState) {
                if (_currentStatus.paused) {
                    [self controlPlay];
                }
            } else {
                [self controlPause];
            }
        }
    }];
}

@end
