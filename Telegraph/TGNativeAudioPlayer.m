/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGNativeAudioPlayer.h"

#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"

@interface TGNativeAudioPlayer () <AVAudioPlayerDelegate>
{
    CGFloat _rate;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    AVPlayerItem *_currentItem;
    TGObserverProxy *_didPlayToEndObserver;
    AVPlayerItem *_upcomingItem;
    TGObserverProxy *_upcomingEndObserver;
#else
    AVAudioPlayer *_upcomingItem;
#endif
    NSString *_activePath;
    NSString *_upcomingPath;
}

@end

static NSString *OGCompatPlayablePath(NSString *path)
{
    if (path.length == 0)
        return nil;

    NSArray *playable = @[@"mp3", @"aac", @"m4a", @"mov", @"mp4"];
    if ([playable containsObject:path.pathExtension.lowercaseString])
        return path;

    NSString *linkedPath = [path stringByAppendingPathExtension:@"mp3"];
    [[NSFileManager defaultManager] createSymbolicLinkAtPath:linkedPath withDestinationPath:path error:nil];
    return linkedPath;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
static void OGCompatApplyLegacyRate(AVAudioPlayer *player, CGFloat rate)
{
    SEL enableRateSelector = NSSelectorFromString(@"setEnableRate:");
    if ([player respondsToSelector:enableRateSelector])
    {
        void (*setEnabled)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[player methodForSelector:enableRateSelector];
        if (setEnabled != NULL)
            setEnabled(player, enableRateSelector, YES);
    }
    SEL rateSelector = NSSelectorFromString(@"setRate:");
    if ([player respondsToSelector:rateSelector])
    {
        void (*setRate)(id, SEL, float) = (void (*)(id, SEL, float))[player methodForSelector:rateSelector];
        if (setRate != NULL)
            setRate(player, rateSelector, (float)rate);
    }
}
#endif

@implementation TGNativeAudioPlayer

- (instancetype)initWithPath:(NSString *)path music:(bool)music controlAudioSession:(bool)controlAudioSession
{
    self = [super initWithMusic:music controlAudioSession:controlAudioSession];
    if (self != nil)
    {
        _rate = 1.0f;
        
        __autoreleasing NSError *error = nil;
        NSString *realPath = OGCompatPlayablePath(path);
        _activePath = [realPath copy];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        [self og_compat_beginWithItem:[self og_compat_itemForPath:realPath]];
#else
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:realPath] error:&error];
        [_player setDelegate:self];
        [_player prepareToPlay];
#endif
        
        if (_player == nil || error != nil)
        {
            [self cleanupWithError];
        }
    }
    return self;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
- (instancetype)initWithURL:(NSURL *)url music:(bool)music controlAudioSession:(bool)controlAudioSession
{
    self = [super initWithMusic:music controlAudioSession:controlAudioSession];
    if (self != nil)
    {
        _rate = 1.0f;
        [self og_compat_beginWithItem:[[AVPlayerItem alloc] initWithURL:url]];
        if (_player == nil)
            [self cleanupWithError];
    }
    return self;
}
#endif

- (void)og_compat_forgetUpcoming
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    _upcomingEndObserver = nil;
#endif
    _upcomingItem = nil;
    _upcomingPath = nil;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
- (AVPlayerItem *)og_compat_itemForPath:(NSString *)path
{
    return [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:path]];
}

- (TGObserverProxy *)og_compat_endObserverForItem:(AVPlayerItem *)item
{
    return [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
}

- (void)og_compat_beginWithItem:(AVPlayerItem *)item
{
    _currentItem = item;
    if (item == nil)
        return;

    _player = [[AVQueuePlayer alloc] initWithItems:@[item]];
    _didPlayToEndObserver = [self og_compat_endObserverForItem:item];
}
#endif

- (bool)replaceWithPath:(NSString *)path
{
    NSString *resolvedPath = OGCompatPlayablePath(path);
    if (_player == nil || resolvedPath.length == 0)
        return false;

    __block bool swapped = false;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        if (_upcomingItem != nil && [_upcomingPath isEqualToString:resolvedPath] && ((AVQueuePlayer *)_player).currentItem == _upcomingItem)
        {
            _currentItem = _upcomingItem;
            _activePath = _upcomingPath;
            _didPlayToEndObserver = _upcomingEndObserver;
            [self og_compat_forgetUpcoming];
            swapped = true;
            return;
        }

        AVPlayerItem *nextItem = [self og_compat_itemForPath:resolvedPath];
        if (nextItem)
        {
            _didPlayToEndObserver = nil;
            [self og_compat_forgetUpcoming];
            _currentItem = nextItem;
            _activePath = [resolvedPath copy];
            AVQueuePlayer *replacementPlayer = (AVQueuePlayer *)_player;
            [replacementPlayer removeAllItems];
            [replacementPlayer insertItem:nextItem afterItem:nil];
            _didPlayToEndObserver = [self og_compat_endObserverForItem:nextItem];
            swapped = true;
        }
#else
        if ([_activePath isEqualToString:resolvedPath])
        {
            swapped = true;
            return;
        }

        NSError *error = nil;
        AVAudioPlayer *nextPlayer = nil;
        if (_upcomingItem != nil && [_upcomingPath isEqualToString:resolvedPath])
            nextPlayer = _upcomingItem;
        else
            nextPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:resolvedPath] error:&error];
        if (nextPlayer != nil && error == nil)
        {
            [_player stop];
            [_player setDelegate:nil];
            _player = nextPlayer;
            [_player setDelegate:self];
            [_player prepareToPlay];
            OGCompatApplyLegacyRate(_player, _rate);
            _activePath = [resolvedPath copy];
            [self og_compat_forgetUpcoming];
            swapped = true;
        }
#endif
    } synchronous:true];
    return swapped;
}

- (bool)prepareNextPath:(NSString *)path
{
    NSString *resolvedPath = OGCompatPlayablePath(path);
    if (_player == nil || resolvedPath.length == 0)
        return false;

    __block bool queued = false;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        if ([_activePath isEqualToString:resolvedPath] || [_upcomingPath isEqualToString:resolvedPath])
        {
            queued = true;
            return;
        }

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        AVQueuePlayer *queuePlayer = (AVQueuePlayer *)_player;
        if (_upcomingItem != nil)
        {
            [queuePlayer removeItem:_upcomingItem];
            [self og_compat_forgetUpcoming];
        }

        AVPlayerItem *item = [self og_compat_itemForPath:resolvedPath];
        if (item != nil && [queuePlayer canInsertItem:item afterItem:_currentItem])
        {
            AVPlayerItem *anchorItem = _currentItem;
            [queuePlayer insertItem:item afterItem:anchorItem];
            _upcomingItem = item;
            _upcomingPath = [resolvedPath copy];
            _upcomingEndObserver = [self og_compat_endObserverForItem:item];
            queued = true;
        }
#else
        NSError *error = nil;
        AVAudioPlayer *item = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:resolvedPath] error:&error];
        if (item != nil && error == nil)
        {
            [item setDelegate:self];
            [item prepareToPlay];
            OGCompatApplyLegacyRate(item, _rate);
            _upcomingItem = item;
            _upcomingPath = [resolvedPath copy];
            queued = true;
        }
#endif
    } synchronous:true];
    return queued;
}

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanupWithError
{
    [self cleanup];
}

- (void)cleanup
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    AVPlayer *player = _player;
#else
    AVAudioPlayer *player = _player;
    [player setDelegate:nil];
    [_upcomingItem setDelegate:nil];
    [self og_compat_forgetUpcoming];
#endif
    _player = nil;
    
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [player pause];
    }];
    
    [self _endAudioSessionFinal];
}

- (void)playFromPosition:(NSTimeInterval)position
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [self _beginAudioSession];
        
        if (position >= 0.0) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
            CMTime targetTime = CMTimeMakeWithSeconds(position, NSEC_PER_SEC);
            [_currentItem seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
#else
            [_player setCurrentTime:MAX(0.0, MIN(position, [_player duration]))];
#endif
        }
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        if (iosMajorVersion() >= 7)
            _currentItem.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmTimeDomain;
#endif
        [_player play];
        _player.rate = (float)_rate;
#else
        OGCompatApplyLegacyRate(_player, _rate);
        [_player play];
#endif
    }];
}

- (void)pause:(void (^)())completion
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [_player pause];
        [self _endAudioSession];
        if (completion) {
            completion();
        }
    }];
}

- (void)stop
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [_player pause];
        [self _endAudioSession];
    }];
}

- (void)setRate:(CGFloat)rate
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        _rate = rate;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        [_player setRate:(float)rate];
#else
        OGCompatApplyLegacyRate(_player, rate);
        OGCompatApplyLegacyRate(_upcomingItem, rate);
#endif
    }];
}

- (NSTimeInterval)currentPositionSync:(bool)sync
{
    __block NSTimeInterval result = 0.0;
    
    dispatch_block_t block = ^
    {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        result = CMTimeGetSeconds(_currentItem.currentTime);
#else
        result = [_player currentTime];
#endif
    };
    
    if (sync)
        [[TGAudioPlayer _playerQueue] dispatchOnQueue:block synchronous:true];
    else
        block();
    
    return result;
}

- (NSTimeInterval)duration
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    return CMTimeGetSeconds(_currentItem.duration);
#else
    return [_player duration];
#endif
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)__unused flag
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        if (player != _player)
            return;
        if (_upcomingItem != nil)
        {
            [_player setDelegate:nil];
            _player = _upcomingItem;
            _activePath = _upcomingPath;
            [self og_compat_forgetUpcoming];
            [_player setDelegate:self];
            OGCompatApplyLegacyRate(_player, _rate);
            [_player play];
        }
        else
            [self _endAudioSession];
        [self _notifyFinished];
    }];
#endif
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
- (void)playerItemDidPlayToEndTime:(NSNotification *)__unused notification
{
    if (_upcomingItem == nil)
    {
        [_player pause];
        [self _endAudioSession];
    }
    
    [self _notifyFinished];
}
#endif

@end
