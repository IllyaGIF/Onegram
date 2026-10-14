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
    AVPlayerItem *_queuedItem;
    TGObserverProxy *_queuedDidPlayToEndObserver;
#else
    AVAudioPlayer *_queuedItem;
#endif
    NSString *_currentPath;
    NSString *_queuedPath;
}

@end

static NSString *TGNativeAudioPlayerRealPath(NSString *path)
{
    if (path.length == 0)
        return nil;
    NSString *realPath = path;
    NSArray *audioExtensions = @[@"mp3", @"aac", @"m4a", @"mov", @"mp4"];
    if (![audioExtensions containsObject:realPath.pathExtension.lowercaseString])
    {
        realPath = [path stringByAppendingPathExtension:@"mp3"];
        [[NSFileManager defaultManager] createSymbolicLinkAtPath:realPath withDestinationPath:path error:nil];
    }
    return realPath;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
static void TGNativeAudioPlayerSetLegacyRate(AVAudioPlayer *player, CGFloat rate)
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
        NSString *realPath = TGNativeAudioPlayerRealPath(path);
        _currentPath = [realPath copy];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        _currentItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:realPath]];
        if (_currentItem != nil) {
            _player = [[AVQueuePlayer alloc] initWithItems:@[_currentItem]];
            _didPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:_currentItem];
        }
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

- (bool)replaceWithPath:(NSString *)path
{
    NSString *realPath = TGNativeAudioPlayerRealPath(path);
    if (realPath.length == 0 || _player == nil)
        return false;

    __block bool replaced = false;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        if (_queuedItem != nil && [_queuedPath isEqualToString:realPath] && ((AVQueuePlayer *)_player).currentItem == _queuedItem)
        {
            _currentItem = _queuedItem;
            _currentPath = _queuedPath;
            _didPlayToEndObserver = _queuedDidPlayToEndObserver;
            _queuedItem = nil;
            _queuedPath = nil;
            _queuedDidPlayToEndObserver = nil;
            replaced = true;
            return;
        }

        AVPlayerItem *nextItem = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:realPath]];
        if (nextItem != nil)
        {
            _didPlayToEndObserver = nil;
            _queuedDidPlayToEndObserver = nil;
            _queuedItem = nil;
            _queuedPath = nil;
            _currentItem = nextItem;
            _currentPath = [realPath copy];
            [(AVQueuePlayer *)_player removeAllItems];
            [(AVQueuePlayer *)_player insertItem:nextItem afterItem:nil];
            _didPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:nextItem];
            replaced = true;
        }
#else
        if ([_currentPath isEqualToString:realPath])
        {
            replaced = true;
            return;
        }

        NSError *error = nil;
        AVAudioPlayer *nextPlayer = nil;
        if (_queuedItem != nil && [_queuedPath isEqualToString:realPath])
            nextPlayer = _queuedItem;
        else
            nextPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:realPath] error:&error];
        if (nextPlayer != nil && error == nil)
        {
            [_player stop];
            [_player setDelegate:nil];
            _player = nextPlayer;
            [_player setDelegate:self];
            [_player prepareToPlay];
            TGNativeAudioPlayerSetLegacyRate(_player, _rate);
            _currentPath = [realPath copy];
            _queuedItem = nil;
            _queuedPath = nil;
            replaced = true;
        }
#endif
    } synchronous:true];
    return replaced;
}

- (bool)prepareNextPath:(NSString *)path
{
    NSString *realPath = TGNativeAudioPlayerRealPath(path);
    if (realPath.length == 0 || _player == nil)
        return false;

    __block bool prepared = false;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        if ([_currentPath isEqualToString:realPath] || [_queuedPath isEqualToString:realPath])
        {
            prepared = true;
            return;
        }

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        AVQueuePlayer *queuePlayer = (AVQueuePlayer *)_player;
        if (_queuedItem != nil)
        {
            [queuePlayer removeItem:_queuedItem];
            _queuedDidPlayToEndObserver = nil;
            _queuedItem = nil;
            _queuedPath = nil;
        }

        AVPlayerItem *item = [[AVPlayerItem alloc] initWithURL:[NSURL fileURLWithPath:realPath]];
        if (item != nil && [queuePlayer canInsertItem:item afterItem:_currentItem])
        {
            [queuePlayer insertItem:item afterItem:_currentItem];
            _queuedItem = item;
            _queuedPath = [realPath copy];
            _queuedDidPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
            prepared = true;
        }
#else
        NSError *error = nil;
        AVAudioPlayer *item = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:realPath] error:&error];
        if (item != nil && error == nil)
        {
            [item setDelegate:self];
            [item prepareToPlay];
            TGNativeAudioPlayerSetLegacyRate(item, _rate);
            _queuedItem = item;
            _queuedPath = [realPath copy];
            prepared = true;
        }
#endif
    } synchronous:true];
    return prepared;
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
    [_queuedItem setDelegate:nil];
    _queuedItem = nil;
    _queuedPath = nil;
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
        TGNativeAudioPlayerSetLegacyRate(_player, _rate);
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
        TGNativeAudioPlayerSetLegacyRate(_player, rate);
        TGNativeAudioPlayerSetLegacyRate(_queuedItem, rate);
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
        if (_queuedItem != nil)
        {
            [_player setDelegate:nil];
            _player = _queuedItem;
            _currentPath = _queuedPath;
            _queuedItem = nil;
            _queuedPath = nil;
            [_player setDelegate:self];
            TGNativeAudioPlayerSetLegacyRate(_player, _rate);
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
    if (_queuedItem == nil)
    {
        [_player pause];
        [self _endAudioSession];
    }
    
    [self _notifyFinished];
}
#endif

@end
