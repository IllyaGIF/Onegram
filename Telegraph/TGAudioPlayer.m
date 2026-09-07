/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGAudioPlayer.h"

#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"

#import "TGOpusAudioPlayerAU.h"
#import "TGNativeAudioPlayer.h"
#import "TGFlacDecoder.h"

#import <AudioToolbox/AudioToolbox.h>
#import <math.h>
#import <pthread.h>

#import "../submodules/LegacyComponents/LegacyComponents/TGObserverProxy.h"
#import "TGAppDelegate.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

#import <AVFoundation/AVFoundation.h>

#import "TGAudioSessionManager.h"


static const int TGFlacAudioPlayerBufferCount = 3;

@class TGFlacAudioPlayer;

@interface TGAudioPlayerReference : NSObject
{
    NSCondition *_condition;
    __weak TGAudioPlayer *_value;
    NSUInteger _activeCallbacks;
}

- (void)setValue:(TGAudioPlayer *)value;
- (void)withValue:(void (^)(void *value))block;
- (void)invalidate;

@end

@implementation TGAudioPlayerReference

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _condition = [[NSCondition alloc] init];
    return self;
}

- (void)setValue:(TGAudioPlayer *)value
{
    [_condition lock];
    _value = value;
    [_condition unlock];
}

- (void)withValue:(void (^)(void *value))block
{
    if (block == nil)
        return;

    void *value = NULL;
    [_condition lock];
    __attribute__((objc_precise_lifetime)) __strong TGAudioPlayer *currentValue = _value;
    if (currentValue != nil)
    {
        _activeCallbacks++;
        value = (__bridge void *)currentValue;
    }
    [_condition unlock];

    if (value != NULL)
    {
        @try
        {
            block(value);
        }
        @finally
        {
            [_condition lock];
            if (_activeCallbacks != 0)
                _activeCallbacks--;
            if (_activeCallbacks == 0)
                [_condition broadcast];
            [_condition unlock];
        }
    }
}

- (void)invalidate
{
    [_condition lock];
    _value = nil;
    while (_activeCallbacks != 0)
        [_condition wait];
    [_condition unlock];
}

@end

@interface TGFlacAudioPlayerQueueReference : NSObject

@property (nonatomic, strong) TGFlacAudioPlayer *value;

@end

@implementation TGFlacAudioPlayerQueueReference

@end

static TGFlacAudioPlayer *TGFlacAudioPlayerResolveQueueReference(TGFlacAudioPlayerQueueReference *reference)
{
    TGFlacAudioPlayer *player = nil;
    @synchronized (reference)
    {
        player = reference.value;
    }
    return player;
}

@interface TGFlacAudioPlayer : TGAudioPlayer
{
    NSString *_filePath;
    TGFLACDecoder *_decoder;
    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _audioBuffers[TGFlacAudioPlayerBufferCount];
    UInt32 _bytesPerFrame;
    UInt32 _bufferByteSize;
    uint64_t _playedFrames;
    int _queuedBufferCount;
    bool _paused;
    bool _finished;
    bool _didNotifyFinished;
    uint32_t _queueGeneration;
    pthread_mutex_t _lock;
    TGFlacAudioPlayerQueueReference *_queueReference;
    void *_audioQueueCallbackContext;
}

+ (bool)canPlayFile:(NSString *)path;
- (instancetype)initWithPath:(NSString *)path music:(bool)music controlAudioSession:(bool)controlAudioSession;
- (void)_audioQueueBufferCompleted:(AudioQueueBufferRef)buffer;
- (void)_retryGrowingBuffer:(AudioQueueBufferRef)buffer generation:(uint32_t)generation;

@end

static void TGFlacAudioQueueCallback(void *userData, AudioQueueRef __unused queue, AudioQueueBufferRef buffer)
{
    TGFlacAudioPlayerQueueReference *reference = (__bridge TGFlacAudioPlayerQueueReference *)userData;
    TGFlacAudioPlayer *player = TGFlacAudioPlayerResolveQueueReference(reference);
    if (player != nil)
        [player _audioQueueBufferCompleted:buffer];
}

@implementation TGFlacAudioPlayer

+ (bool)canPlayFile:(NSString *)path
{
    return path.length != 0 && tgflac_is_file([path fileSystemRepresentation]);
}

- (instancetype)initWithPath:(NSString *)path music:(bool)music controlAudioSession:(bool)controlAudioSession
{
    self = [super initWithMusic:music controlAudioSession:controlAudioSession];
    if (self != nil)
    {
        _filePath = [path copy];
        pthread_mutex_init(&_lock, NULL);
        _queueReference = [[TGFlacAudioPlayerQueueReference alloc] init];
        _paused = true;
        _decoder = tgflac_open([_filePath fileSystemRepresentation]);
        if (_decoder == NULL)
        {
            TGLog(@"FLAC open failed path=%@", _filePath);
        }
        else
        {
            TGLog(@"FLAC open rate=%u channels=%u bits=%u frames=%llu", _decoder->sampleRate, _decoder->channels, _decoder->bitsPerSample, _decoder->totalFrames);
        }
    }
    return self;
}

- (void)dealloc
{
    [self _cleanup];
    pthread_mutex_destroy(&_lock);
}

- (bool)_setupAudioQueue
{
    if (_decoder == NULL)
        return false;
    if (_audioQueue != NULL)
        return true;

    uint32_t channels = tgflac_output_channels(_decoder);
    if (channels == 0 || _decoder->sampleRate == 0)
        return false;

    AudioStreamBasicDescription format;
    memset(&format, 0, sizeof(format));
    format.mSampleRate = _decoder->sampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mFramesPerPacket = 1;
    format.mChannelsPerFrame = channels;
    format.mBitsPerChannel = 16;
    format.mBytesPerFrame = channels * sizeof(int16_t);
    format.mBytesPerPacket = format.mBytesPerFrame;
    _bytesPerFrame = format.mBytesPerFrame;

    void *callbackContext = (void *)CFRetain((__bridge CFTypeRef)_queueReference);
    OSStatus status = AudioQueueNewOutput(&format, TGFlacAudioQueueCallback, callbackContext, NULL, NULL, 0, &_audioQueue);
    if (status != noErr || _audioQueue == NULL)
    {
        CFRelease((CFTypeRef)callbackContext);
        TGLog(@"FLAC AudioQueueNewOutput failed status=%d", (int)status);
        _audioQueue = NULL;
        return false;
    }
    _audioQueueCallbackContext = callbackContext;

    _queueGeneration++;

    UInt32 framesPerBuffer = MAX((UInt32)2048, MIN((UInt32)16384, (UInt32)(_decoder->sampleRate / 4)));
    _bufferByteSize = framesPerBuffer * _bytesPerFrame;

    int i;
    for (i = 0; i < TGFlacAudioPlayerBufferCount; i++)
    {
        status = AudioQueueAllocateBuffer(_audioQueue, _bufferByteSize, &_audioBuffers[i]);
        if (status != noErr || _audioBuffers[i] == NULL)
        {
            TGLog(@"FLAC AudioQueueAllocateBuffer failed index=%d status=%d", i, (int)status);
            [self _cleanupQueueOnly];
            return false;
        }
    }
    return true;
}

- (bool)_fillAndEnqueueBuffer:(AudioQueueBufferRef)buffer
{
    if (_decoder == NULL || _audioQueue == NULL || buffer == NULL)
        return false;

    uint64_t capacityFrames = buffer->mAudioDataBytesCapacity / _bytesPerFrame;
    uint64_t frames = tgflac_read_s16(_decoder, capacityFrames, (int16_t *)buffer->mAudioData);
    if (frames == 0)
    {
        buffer->mAudioDataByteSize = 0;
        if (_decoder->needMoreData && (_decoder->totalFrames == 0 || _decoder->decodedFramePosition < _decoder->totalFrames))
        {
            TGLog(@"FLAC buffer underrun waiting for download frame=%llu/%llu", _decoder->decodedFramePosition, _decoder->totalFrames);
            return false;
        }
        _finished = true;
        return false;
    }

    buffer->mAudioDataByteSize = (UInt32)(frames * _bytesPerFrame);
    OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
    if (status != noErr)
    {
        TGLog(@"FLAC AudioQueueEnqueueBuffer failed status=%d", (int)status);
        _finished = true;
        return false;
    }
    _queuedBufferCount++;
    return true;
}

- (void)_notifyFinishedIfNeeded
{
    bool notify = false;
    pthread_mutex_lock(&_lock);
    if (_finished && _queuedBufferCount == 0 && !_didNotifyFinished)
    {
        _didNotifyFinished = true;
        _paused = true;
        notify = true;
    }
    pthread_mutex_unlock(&_lock);

    if (notify)
    {
        TGFlacAudioPlayerQueueReference *reference = _queueReference;
        [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
        {
            TGFlacAudioPlayer *player = TGFlacAudioPlayerResolveQueueReference(reference);
            if (player != nil)
            {
                TGLog(@"FLAC finished path=%@", player->_filePath);
                [player _cleanupQueueOnly];
                [player _endAudioSession];
                [player _notifyFinished];
            }
        }];
    }
}

- (void)_audioQueueBufferCompleted:(AudioQueueBufferRef)buffer
{
    bool shouldRefill = false;
    pthread_mutex_lock(&_lock);
    if (_bytesPerFrame != 0 && buffer->mAudioDataByteSize != 0)
        _playedFrames += buffer->mAudioDataByteSize / _bytesPerFrame;
    if (_queuedBufferCount > 0)
        _queuedBufferCount--;
    shouldRefill = !_paused && !_finished;
    bool refilled = false;
    bool waitingForData = false;
    if (shouldRefill)
    {
        refilled = [self _fillAndEnqueueBuffer:buffer];
        waitingForData = !refilled && _decoder != NULL && _decoder->needMoreData && !_paused && !_finished;
    }
    uint32_t generation = _queueGeneration;
    pthread_mutex_unlock(&_lock);

    if (waitingForData)
        [self _retryGrowingBuffer:buffer generation:generation];
    [self _notifyFinishedIfNeeded];
}

- (void)_retryGrowingBuffer:(AudioQueueBufferRef)buffer generation:(uint32_t)generation
{
    TGFlacAudioPlayerQueueReference *reference = _queueReference;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
    {
        [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
        {
            TGFlacAudioPlayer *player = TGFlacAudioPlayerResolveQueueReference(reference);
            if (player == nil)
                return;
            pthread_mutex_lock(&player->_lock);
            bool currentBuffer = false;
            int i;
            for (i = 0; i < TGFlacAudioPlayerBufferCount; i++)
            {
                if (player->_audioBuffers[i] == buffer)
                {
                    currentBuffer = true;
                    break;
                }
            }
            bool canRetry = generation == player->_queueGeneration && currentBuffer && !player->_paused && !player->_finished && player->_audioQueue != NULL;
            bool queued = false;
            if (canRetry)
                queued = [player _fillAndEnqueueBuffer:buffer];
            bool waitAgain = canRetry && !queued && player->_decoder != NULL && player->_decoder->needMoreData;
            AudioQueueRef queue = queued ? player->_audioQueue : NULL;
            pthread_mutex_unlock(&player->_lock);
            if (queue != NULL)
                AudioQueueStart(queue, NULL);
            else if (waitAgain)
                [player _retryGrowingBuffer:buffer generation:generation];
            [player _notifyFinishedIfNeeded];
        }];
    });
}

- (void)_cleanupQueueOnly
{
    TGFlacAudioPlayerQueueReference *queueReference = _queueReference;
    pthread_mutex_lock(&_lock);
    AudioQueueRef queue = _audioQueue;
    void *callbackContext = _audioQueueCallbackContext;
    _audioQueue = NULL;
    _audioQueueCallbackContext = NULL;
    _queueGeneration++;
    memset(_audioBuffers, 0, sizeof(_audioBuffers));
    _queuedBufferCount = 0;
    pthread_mutex_unlock(&_lock);
    @synchronized (queueReference)
    {
        queueReference.value = nil;
    }
    if (queue != NULL)
    {
        AudioQueueStop(queue, true);
        AudioQueueDispose(queue, true);
    }
    if (callbackContext != NULL)
        CFRelease((CFTypeRef)callbackContext);
}

- (void)_cleanup
{
    pthread_mutex_lock(&_lock);
    _paused = true;
    pthread_mutex_unlock(&_lock);

    [self _cleanupQueueOnly];

    TGFLACDecoder *decoder = _decoder;
    _decoder = NULL;
    if (decoder != NULL)
        tgflac_close(decoder);

    [self _endAudioSessionFinal];
}

- (void)playFromPosition:(NSTimeInterval)position
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        if (_decoder == NULL)
            return;
        if (![self _setupAudioQueue])
            return;

        [self _beginAudioSession];

        bool needPrime = false;
        pthread_mutex_lock(&_lock);
        if (position >= 0.0)
        {
            pthread_mutex_unlock(&_lock);
            AudioQueueStop(_audioQueue, true);
            AudioQueueReset(_audioQueue);
            pthread_mutex_lock(&_lock);
            uint64_t target = (uint64_t)(MAX(0.0, position) * _decoder->sampleRate);
            if (_decoder->totalFrames != 0 && target > _decoder->totalFrames)
                target = _decoder->totalFrames;
            if (!tgflac_seek(_decoder, target))
                TGLog(@"FLAC seek failed target=%llu", target);
            _playedFrames = _decoder->decodedFramePosition;
            _queuedBufferCount = 0;
            _finished = false;
            _didNotifyFinished = false;
            needPrime = true;
        }
        else if (_finished)
        {
            pthread_mutex_unlock(&_lock);
            AudioQueueStop(_audioQueue, true);
            AudioQueueReset(_audioQueue);
            pthread_mutex_lock(&_lock);
            tgflac_seek(_decoder, 0);
            _playedFrames = 0;
            _queuedBufferCount = 0;
            _finished = false;
            _didNotifyFinished = false;
            needPrime = true;
        }
        else if (_queuedBufferCount == 0)
        {
            needPrime = true;
        }

        _paused = false;
        if (needPrime)
        {
            int i;
            for (i = 0; i < TGFlacAudioPlayerBufferCount; i++)
            {
                if (![self _fillAndEnqueueBuffer:_audioBuffers[i]])
                {
                    if (_decoder != NULL && _decoder->needMoreData && !_finished)
                        [self _retryGrowingBuffer:_audioBuffers[i] generation:_queueGeneration];
                    break;
                }
            }
        }
        pthread_mutex_unlock(&_lock);

        @synchronized (_queueReference)
        {
            _queueReference.value = self;
        }
        OSStatus status = AudioQueueStart(_audioQueue, NULL);
        if (status != noErr)
        {
            @synchronized (_queueReference)
            {
                _queueReference.value = nil;
            }
            [self _endAudioSession];
            TGLog(@"FLAC AudioQueueStart failed status=%d", (int)status);
        }
        else
            TGLog(@"FLAC play position=%.3f", position);

        [self _notifyFinishedIfNeeded];
    }];
}

- (void)pause:(void (^)())completion
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        pthread_mutex_lock(&_lock);
        _paused = true;
        pthread_mutex_unlock(&_lock);
        if (_audioQueue != NULL)
            AudioQueuePause(_audioQueue);
        @synchronized (_queueReference)
        {
            _queueReference.value = nil;
        }
        [self _endAudioSession];
        if (completion)
            completion();
    }];
}

- (void)stop
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [self _cleanup];
    }];
}

- (void)setRate:(CGFloat)rate
{
    if (fabs(rate - 1.0f) > 0.01f)
        TGLog(@"FLAC playback rate %.2f requested; using 1.0 on legacy AudioQueue", rate);
}

- (bool)replaceWithPath:(NSString *)__unused path
{
    return false;
}

- (bool)prepareNextPath:(NSString *)__unused path
{
    return false;
}

- (NSTimeInterval)currentPositionSync:(bool)__unused sync
{
    pthread_mutex_lock(&_lock);
    uint64_t frame = _playedFrames;
    uint32_t rate = _decoder != NULL ? _decoder->sampleRate : 0;
    pthread_mutex_unlock(&_lock);
    return rate == 0 ? 0.0 : frame / (NSTimeInterval)rate;
}

- (NSTimeInterval)duration
{
    pthread_mutex_lock(&_lock);
    uint64_t frames = _decoder != NULL ? _decoder->totalFrames : 0;
    uint32_t rate = _decoder != NULL ? _decoder->sampleRate : 0;
    pthread_mutex_unlock(&_lock);
    return rate == 0 ? 0.0 : frames / (NSTimeInterval)rate;
}

@end

@interface TGAudioPlayer ()
{
    bool _music;
    bool _controlAudioSession;
    
    bool _proximityState;
    TGObserverProxy *_proximityChangedNotification;
    TGHolder *_proximityChangeHolder;
    
    SMetaDisposable *_currentAudioSession;
    bool _changingProximity;
    
    SMetaDisposable *_routeChangeDisposable;
    TGAudioPlayerReference *_lifetimeReference;
}

@end

@implementation TGAudioPlayer

+ (TGAudioPlayer *)audioPlayerForPath:(NSString *)path music:(bool)music controlAudioSession:(bool)controlAudioSession
{
    if (path == nil)
        return nil;

    TGLog(@"AUDIO factory.begin path=%@", path);
    bool opus = [TGOpusAudioPlayerAU canPlayFile:path];
    TGLog(@"AUDIO factory.opus result=%d", opus ? 1 : 0);
    if (opus)
    {
        TGLog(@"AUDIO factory=opus path=%@", path);
        return [[TGOpusAudioPlayerAU alloc] initWithPath:path music:music controlAudioSession:controlAudioSession];
    }

    bool flac = [TGFlacAudioPlayer canPlayFile:path];
    TGLog(@"AUDIO factory.flac result=%d", flac ? 1 : 0);
    if (flac)
    {
        TGLog(@"AUDIO factory=flac path=%@", path);
        return [[TGFlacAudioPlayer alloc] initWithPath:path music:music controlAudioSession:controlAudioSession];
    }

    TGLog(@"AUDIO factory=native path=%@", path);
    return [[TGNativeAudioPlayer alloc] initWithPath:path music:music controlAudioSession:controlAudioSession];
}

- (instancetype)init {
    return [self initWithMusic:false controlAudioSession:true];
}

- (instancetype)initWithMusic:(bool)music controlAudioSession:(bool)controlAudioSession
{
    self = [super init];
    if (self != nil)
    {
        _music = music;
        _controlAudioSession = controlAudioSession;
        _lifetimeReference = [[TGAudioPlayerReference alloc] init];
        [_lifetimeReference setValue:self];
        
        _currentAudioSession = [[SMetaDisposable alloc] init];
        if (!_music && _controlAudioSession) {
            _proximityState = TGAppDelegateInstance.deviceProximityState;
            _proximityChangedNotification = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(proximityChanged:) name:TGDeviceProximityStateChangedNotification object:nil];
            _proximityChangeHolder = [[TGHolder alloc] init];
            [TGAppDelegateInstance.deviceProximityListeners addHolder:_proximityChangeHolder];
            
            TGAudioPlayerReference *reference = _lifetimeReference;
            _routeChangeDisposable = [[[TGAudioSessionManager routeChange] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *action) {
                if ([action intValue] == TGAudioSessionRouteChangePause) {
                    [reference withValue:^(void *value)
                    {
                        TGAudioPlayer *player = (__bridge TGAudioPlayer *)value;
                        [player pause:nil];
                        [player _notifyPaused];
                    }];
                }
            }];
        }
    }
    return self;
}

- (void)dealloc
{
    [_lifetimeReference invalidate];
    [_routeChangeDisposable dispose];
    [_currentAudioSession setDisposable:nil];
    if (!_music) {
        [TGAppDelegateInstance.deviceProximityListeners removeHolder:_proximityChangeHolder];
    }
}


- (void)setRate:(CGFloat)__unused rate {
    
}

- (void)play
{
    [self playFromPosition:-1.0];
}

- (void)playFromPosition:(NSTimeInterval)__unused position
{
}

- (void)pause:(void (^)())completion
{
    if (completion) {
        completion();
    }
}

- (void)stop
{
}

- (bool)replaceWithPath:(NSString *)__unused path
{
    return false;
}

- (bool)prepareNextPath:(NSString *)__unused path
{
    return false;
}

- (NSTimeInterval)currentPositionSync:(bool)__unused sync
{
    return 0.0;
}

- (NSTimeInterval)duration
{
    return 0.0;
}

+ (ASQueue *)_playerQueue
{
    static ASQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ASQueue alloc] initWithName:"org.telegram.audioPlayerQueue"];
    });
    
    return queue;
}

- (void)proximityChanged:(NSNotification *)__unused notification
{
    if (_music) {
        return;
    }
    
    bool proximityState = TGAppDelegateInstance.deviceProximityState;
    TGAudioPlayerReference *reference = _lifetimeReference;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [reference withValue:^(void *value)
        {
            TGAudioPlayer *player = (__bridge TGAudioPlayer *)value;
            player->_proximityState = proximityState;
            bool overridePort = player->_proximityState && ![TGAudioPlayer isHeadsetPluggedIn];
            player->_changingProximity = true;
            [player->_currentAudioSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:overridePort ? TGAudioSessionTypePlayAndRecordHeadphones : TGAudioSessionTypePlayVoice interrupted:^
            {
                [reference withValue:^(void *interruptedValue)
                {
                    TGAudioPlayer *interruptedPlayer = (__bridge TGAudioPlayer *)interruptedValue;
                    if (!interruptedPlayer->_changingProximity)
                    {
                        [interruptedPlayer stop];
                        [interruptedPlayer _notifyFinished];
                    }
                }];
            }]];
            player->_changingProximity = false;
        }];
    }];
}

- (void)_beginAudioSession
{
    if (!_controlAudioSession) {
        return;
    }
    
    TGAudioPlayerReference *reference = _lifetimeReference;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [reference withValue:^(void *value)
        {
            TGAudioPlayer *player = (__bridge TGAudioPlayer *)value;
            if (player->_music) {
                [player->_currentAudioSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:TGAudioSessionTypePlayMusic interrupted:^
                {
                    [reference withValue:^(void *interruptedValue)
                    {
                        TGAudioPlayer *interruptedPlayer = (__bridge TGAudioPlayer *)interruptedValue;
                        if (!interruptedPlayer->_changingProximity)
                        {
                            [interruptedPlayer pause:nil];
                            [interruptedPlayer _notifyPaused];
                        }
                    }];
                }]];
            } else {
                bool overridePort = player->_proximityState && ![TGAudioPlayer isHeadsetPluggedIn];
                [player->_currentAudioSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:overridePort ? TGAudioSessionTypePlayAndRecordHeadphones : TGAudioSessionTypePlayVoice interrupted:^
                {
                    [reference withValue:^(void *interruptedValue)
                    {
                        TGAudioPlayer *interruptedPlayer = (__bridge TGAudioPlayer *)interruptedValue;
                        if (!interruptedPlayer->_changingProximity)
                        {
                            [interruptedPlayer stop];
                            [interruptedPlayer _notifyFinished];
                        }
                    }];
                }]];
            }
        }];
    }];
}

- (void)_endAudioSession
{
    if (!_controlAudioSession) {
        return;
    }
    
    SMetaDisposable *currentAudioSession = _currentAudioSession;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [currentAudioSession setDisposable:nil];
    }];
}

- (void)_endAudioSessionFinal
{
    if (!_controlAudioSession) {
        return;
    }
    
    SMetaDisposable *currentAudioSession = _currentAudioSession;
    
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [currentAudioSession setDisposable:nil];
    }];
}

- (void)_notifyFinished
{
    id<TGAudioPlayerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(audioPlayerDidFinishPlaying:)])
        [delegate audioPlayerDidFinishPlaying:self];
}

- (void)_notifyPaused {
    id<TGAudioPlayerDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(audioPlayerDidPause:)])
        [delegate audioPlayerDidPause:self];
}

+ (bool)isHeadsetPluggedIn
{
    if (iosMajorVersion() < 6)
        return false;
    
    AVAudioSessionRouteDescription *route = [[AVAudioSession sharedInstance] currentRoute];
    
    for (AVAudioSessionPortDescription *desc in [route outputs])
    {
        if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones])
            return true;
    }
    
    return false;
}

@end
