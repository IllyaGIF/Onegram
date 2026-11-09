#import "TGStreamingAudioPlayer.h"

#import <pthread.h>

#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"
#import "OGMediaStreamReader.h"

#define TGStreamingAudioBufferCount 4
#define TGStreamingAudioMaximumPackets 512

static const UInt32 TGStreamingAudioDefaultBufferSize = 24 * 1024;
static const size_t TGStreamingAudioReadSize = 8 * 1024;
static const NSUInteger TGStreamingAudioStartBuffers = 2;

@interface TGStreamingAudioPlayer ()
{
    OGMediaStreamReader *_reader;
    AudioFileTypeID _fileType;
    pthread_mutex_t _lock;
    pthread_cond_t _condition;
    NSThread *_thread;

    AudioFileStreamID _parser;
    AudioQueueRef _queue;
    AudioStreamBasicDescription _format;
    AudioQueueBufferRef _buffers[TGStreamingAudioBufferCount];
    bool _inUse[TGStreamingAudioBufferCount];
    AudioStreamPacketDescription _descriptions[TGStreamingAudioBufferCount][TGStreamingAudioMaximumPackets];
    UInt32 _bufferSize;
    NSUInteger _fillIndex;
    UInt32 _bytesFilled;
    UInt32 _packetsFilled;
    NSUInteger _queuedBuffers;

    bool _queueRunning;
    bool _paused;
    bool _stopped;
    bool _endOfStream;
    bool _finished;
    bool _seekRequested;
    bool _discontinuity;
    NSTimeInterval _seekTime;
    NSTimeInterval _timeBase;
    NSTimeInterval _lastPosition;

    SInt64 _dataOffset;
    UInt64 _audioDataByteCount;
    UInt64 _audioDataPacketCount;
    UInt32 _bitRate;
    UInt64 _parsedPacketBytes;
    UInt64 _parsedPackets;
}

- (void)handlePropertyChange:(AudioFileStreamPropertyID)propertyID;
- (void)handlePackets:(const void *)data bytes:(UInt32)numberBytes packets:(UInt32)numberPackets descriptions:(AudioStreamPacketDescription *)descriptions;
- (void)handleBufferCompleted:(AudioQueueBufferRef)buffer;

@end

static void TGStreamingAudioPropertyListener(void *clientData, AudioFileStreamID __unused stream, AudioFileStreamPropertyID propertyID, UInt32 *__unused flags)
{
    [(__bridge TGStreamingAudioPlayer *)clientData handlePropertyChange:propertyID];
}

static void TGStreamingAudioPacketsCallback(void *clientData, UInt32 numberBytes, UInt32 numberPackets, const void *data, AudioStreamPacketDescription *descriptions)
{
    [(__bridge TGStreamingAudioPlayer *)clientData handlePackets:data bytes:numberBytes packets:numberPackets descriptions:descriptions];
}

static void TGStreamingAudioOutputCallback(void *clientData, AudioQueueRef __unused queue, AudioQueueBufferRef buffer)
{
    [(__bridge TGStreamingAudioPlayer *)clientData handleBufferCompleted:buffer];
}

@implementation TGStreamingAudioPlayer

+ (AudioFileTypeID)fileTypeForPathExtension:(NSString *)pathExtension
{
    NSString *extension = [pathExtension lowercaseString];
    if ([extension isEqualToString:@"mp3"])
        return kAudioFileMP3Type;
    if ([extension isEqualToString:@"m4a"] || [extension isEqualToString:@"mp4"])
        return kAudioFileM4AType;
    if ([extension isEqualToString:@"aac"])
        return kAudioFileAAC_ADTSType;
    if ([extension isEqualToString:@"wav"])
        return kAudioFileWAVEType;
    if ([extension isEqualToString:@"caf"])
        return kAudioFileCAFType;
    if ([extension isEqualToString:@"aif"] || [extension isEqualToString:@"aiff"])
        return kAudioFileAIFFType;
    return 0;
}

- (instancetype)initWithReader:(OGMediaStreamReader *)reader fileType:(AudioFileTypeID)fileType music:(bool)music controlAudioSession:(bool)controlAudioSession
{
    self = [super initWithMusic:music controlAudioSession:controlAudioSession];
    if (self != nil)
    {
        _reader = reader;
        _reader.blocking = true;
        _fileType = fileType;
        _paused = true;
        pthread_mutex_init(&_lock, NULL);
        pthread_cond_init(&_condition, NULL);
    }
    return self;
}

- (void)dealloc
{
    pthread_cond_destroy(&_condition);
    pthread_mutex_destroy(&_lock);
}

#pragma mark - Control

- (void)playFromPosition:(NSTimeInterval)position
{
    pthread_mutex_lock(&_lock);
    if (_stopped)
    {
        pthread_mutex_unlock(&_lock);
        return;
    }
    if (position < 0.0 && _finished)
        position = 0.0;
    if (position >= 0.0)
    {
        _seekRequested = true;
        _seekTime = position;
    }
    _paused = false;
    if (_thread == nil)
    {
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(run) object:nil];
        [_thread start];
    }
    else if (!_seekRequested)
        [self startQueueIfNeededLocked];
    pthread_cond_broadcast(&_condition);
    pthread_mutex_unlock(&_lock);

    if (position >= 0.0)
        [_reader interrupt];

    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [self _beginAudioSession];
    }];
}

- (void)pause:(void (^)())completion
{
    pthread_mutex_lock(&_lock);
    _paused = true;
    if (_queue != NULL && _queueRunning)
    {
        AudioQueuePause(_queue);
        _queueRunning = false;
    }
    pthread_mutex_unlock(&_lock);

    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [self _endAudioSession];
        if (completion)
            completion();
    }];
}

- (void)stop
{
    pthread_mutex_lock(&_lock);
    _stopped = true;
    _paused = true;
    pthread_cond_broadcast(&_condition);
    pthread_mutex_unlock(&_lock);
    [_reader cancel];

    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [self _endAudioSessionFinal];
    }];
}

- (NSTimeInterval)currentPositionSync:(bool)__unused sync
{
    pthread_mutex_lock(&_lock);
    NSTimeInterval position = _lastPosition;
    if (_finished)
        position = [self durationLocked];
    else if (_queue != NULL && _format.mSampleRate > 0.0 && !_seekRequested)
    {
        AudioTimeStamp timeStamp;
        memset(&timeStamp, 0, sizeof(timeStamp));
        if (AudioQueueGetCurrentTime(_queue, NULL, &timeStamp, NULL) == noErr && (timeStamp.mFlags & kAudioTimeStampSampleTimeValid) != 0)
            position = _timeBase + timeStamp.mSampleTime / _format.mSampleRate;
    }
    else if (_seekRequested)
        position = _seekTime;
    _lastPosition = position;
    pthread_mutex_unlock(&_lock);
    return MAX(0.0, position);
}

- (double)bitRateLocked
{
    if (_bitRate > 0)
        return _bitRate;
    if (_parsedPackets > 0 && _format.mFramesPerPacket > 0 && _format.mSampleRate > 0.0)
        return (double)_parsedPacketBytes * 8.0 / ((double)_parsedPackets * _format.mFramesPerPacket / _format.mSampleRate);
    return 0.0;
}

- (NSTimeInterval)durationLocked
{
    if (_audioDataPacketCount > 0 && _format.mFramesPerPacket > 0 && _format.mSampleRate > 0.0)
        return (double)_audioDataPacketCount * _format.mFramesPerPacket / _format.mSampleRate;
    double bitRate = [self bitRateLocked];
    if (bitRate <= 0.0)
        return 0.0;
    int64_t bytes = _audioDataByteCount > 0 ? (int64_t)_audioDataByteCount : [_reader size] - _dataOffset;
    return bytes > 0 ? (double)bytes * 8.0 / bitRate : 0.0;
}

- (NSTimeInterval)duration
{
    pthread_mutex_lock(&_lock);
    NSTimeInterval duration = [self durationLocked];
    pthread_mutex_unlock(&_lock);
    return duration;
}

#pragma mark - Producer

- (void)run
{
    @autoreleasepool
    {
        if (AudioFileStreamOpen((__bridge void *)self, TGStreamingAudioPropertyListener, TGStreamingAudioPacketsCallback, _fileType, &_parser) != noErr)
        {
            _parser = NULL;
            [self reportFailure];
            return;
        }

        uint8_t chunk[TGStreamingAudioReadSize];
        while (true)
        {
            @autoreleasepool
            {
                pthread_mutex_lock(&_lock);
                if (_stopped)
                {
                    pthread_mutex_unlock(&_lock);
                    break;
                }
                if (_seekRequested)
                    [self performSeekLocked];
                pthread_mutex_unlock(&_lock);

                ssize_t length = [_reader read:chunk length:sizeof(chunk)];
                if (length == OGMediaStreamReaderInterrupted)
                    continue;
                if (length < 0)
                {
                    pthread_mutex_lock(&_lock);
                    bool stopped = _stopped;
                    pthread_mutex_unlock(&_lock);
                    if (!stopped)
                        [self reportFailure];
                    break;
                }
                if (length == 0)
                {
                    [self drainToEnd];
                    continue;
                }

                pthread_mutex_lock(&_lock);
                bool skip = _seekRequested || _stopped;
                UInt32 flags = _discontinuity ? kAudioFileStreamParseFlag_Discontinuity : 0;
                _discontinuity = false;
                pthread_mutex_unlock(&_lock);
                if (!skip && AudioFileStreamParseBytes(_parser, (UInt32)length, chunk, flags) != noErr)
                {
                    [self reportFailure];
                    break;
                }
            }
        }

        AudioQueueRef queue = NULL;
        pthread_mutex_lock(&_lock);
        queue = _queue;
        _queue = NULL;
        _queueRunning = false;
        pthread_mutex_unlock(&_lock);
        if (queue != NULL)
        {
            AudioQueueStop(queue, true);
            AudioQueueDispose(queue, true);
        }
        if (_parser != NULL)
        {
            AudioFileStreamClose(_parser);
            _parser = NULL;
        }
    }
}

- (void)reportFailure
{
    pthread_mutex_lock(&_lock);
    _paused = true;
    _stopped = true;
    pthread_mutex_unlock(&_lock);
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [self _endAudioSession];
        [self _notifyPaused];
    }];
}

- (void)performSeekLocked
{
    _seekRequested = false;
    _finished = false;
    _endOfStream = false;
    NSTimeInterval time = MAX(0.0, _seekTime);

    if (_queue != NULL)
    {
        AudioQueueRef queue = _queue;
        pthread_mutex_unlock(&_lock);
        AudioQueueStop(queue, true);
        pthread_mutex_lock(&_lock);
        for (NSUInteger i = 0; i < TGStreamingAudioBufferCount; i++)
            _inUse[i] = false;
        _queuedBuffers = 0;
        _queueRunning = false;
    }
    _fillIndex = 0;
    _bytesFilled = 0;
    _packetsFilled = 0;

    int64_t offset = 0;
    if (time > 0.0)
    {
        offset = -1;
        if (_parser != NULL && _format.mSampleRate > 0.0 && _format.mFramesPerPacket > 0)
        {
            SInt64 packet = (SInt64)(time * _format.mSampleRate / _format.mFramesPerPacket);
            SInt64 byteOffset = 0;
            UInt32 flags = 0;
            if (AudioFileStreamSeek(_parser, packet, &byteOffset, &flags) == noErr)
                offset = _dataOffset + byteOffset;
        }
        if (offset < 0)
        {
            double bitRate = [self bitRateLocked];
            offset = bitRate > 0.0 ? _dataOffset + (int64_t)(time * bitRate / 8.0) : 0;
            if (bitRate <= 0.0)
                time = 0.0;
        }
        int64_t size = [_reader size];
        if (size > 0 && offset >= size)
            offset = MAX(_dataOffset, size - 1);
        _discontinuity = true;
    }

    if (offset == 0 && _parser != NULL)
    {
        AudioFileStreamClose(_parser);
        _parser = NULL;
        if (AudioFileStreamOpen((__bridge void *)self, TGStreamingAudioPropertyListener, TGStreamingAudioPacketsCallback, _fileType, &_parser) != noErr)
            _parser = NULL;
        _discontinuity = false;
        time = 0.0;
    }

    _timeBase = time;
    _lastPosition = time;
    [_reader seekToOffset:offset];
}

- (void)drainToEnd
{
    [self enqueueCurrentBuffer];

    pthread_mutex_lock(&_lock);
    if (_stopped || _seekRequested)
    {
        pthread_mutex_unlock(&_lock);
        return;
    }
    _endOfStream = true;
    if (_queue != NULL)
    {
        AudioQueueFlush(_queue);
        [self startQueueIfNeededLocked];
    }
    while (_queuedBuffers > 0 && !_stopped && !_seekRequested)
        pthread_cond_wait(&_condition, &_lock);
    bool finished = !_stopped && !_seekRequested;
    if (finished)
    {
        _finished = true;
        _paused = true;
        if (_queue != NULL)
        {
            AudioQueueRef queue = _queue;
            pthread_mutex_unlock(&_lock);
            AudioQueueStop(queue, true);
            pthread_mutex_lock(&_lock);
            _queueRunning = false;
        }
    }
    pthread_mutex_unlock(&_lock);

    if (finished)
    {
        [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
        {
            [self _endAudioSession];
            [self _notifyFinished];
        }];
    }

    pthread_mutex_lock(&_lock);
    while (!_stopped && !_seekRequested)
        pthread_cond_wait(&_condition, &_lock);
    pthread_mutex_unlock(&_lock);
}

#pragma mark - Parser

- (void)handlePropertyChange:(AudioFileStreamPropertyID)propertyID
{
    UInt32 size = 0;
    switch (propertyID)
    {
        case kAudioFileStreamProperty_DataOffset:
        {
            SInt64 offset = 0;
            size = sizeof(offset);
            if (AudioFileStreamGetProperty(_parser, propertyID, &size, &offset) == noErr)
            {
                pthread_mutex_lock(&_lock);
                _dataOffset = offset;
                pthread_mutex_unlock(&_lock);
            }
            break;
        }
        case kAudioFileStreamProperty_AudioDataByteCount:
        {
            UInt64 count = 0;
            size = sizeof(count);
            if (AudioFileStreamGetProperty(_parser, propertyID, &size, &count) == noErr)
            {
                pthread_mutex_lock(&_lock);
                _audioDataByteCount = count;
                pthread_mutex_unlock(&_lock);
            }
            break;
        }
        case kAudioFileStreamProperty_AudioDataPacketCount:
        {
            UInt64 count = 0;
            size = sizeof(count);
            if (AudioFileStreamGetProperty(_parser, propertyID, &size, &count) == noErr)
            {
                pthread_mutex_lock(&_lock);
                _audioDataPacketCount = count;
                pthread_mutex_unlock(&_lock);
            }
            break;
        }
        case kAudioFileStreamProperty_BitRate:
        {
            UInt32 bitRate = 0;
            size = sizeof(bitRate);
            if (AudioFileStreamGetProperty(_parser, propertyID, &size, &bitRate) == noErr)
            {
                pthread_mutex_lock(&_lock);
                _bitRate = bitRate;
                pthread_mutex_unlock(&_lock);
            }
            break;
        }
        case kAudioFileStreamProperty_ReadyToProducePackets:
            [self createQueue];
            break;
        default:
            break;
    }
}

- (void)createQueue
{
    if (_queue != NULL)
        return;

    AudioStreamBasicDescription format;
    UInt32 size = sizeof(format);
    if (AudioFileStreamGetProperty(_parser, kAudioFileStreamProperty_DataFormat, &size, &format) != noErr)
        return;

    AudioQueueRef queue = NULL;
    if (AudioQueueNewOutput(&format, TGStreamingAudioOutputCallback, (__bridge void *)self, NULL, NULL, 0, &queue) != noErr || queue == NULL)
    {
        TGLog(@"[TGStreamingAudioPlayer AudioQueueNewOutput failed]");
        return;
    }

    UInt32 packetSize = 0;
    size = sizeof(packetSize);
    if (AudioFileStreamGetProperty(_parser, kAudioFileStreamProperty_PacketSizeUpperBound, &size, &packetSize) != noErr || packetSize == 0)
    {
        size = sizeof(packetSize);
        AudioFileStreamGetProperty(_parser, kAudioFileStreamProperty_MaximumPacketSize, &size, &packetSize);
    }
    UInt32 bufferSize = MAX(TGStreamingAudioDefaultBufferSize, packetSize * 4);

    for (NSUInteger i = 0; i < TGStreamingAudioBufferCount; i++)
    {
        if (AudioQueueAllocateBuffer(queue, bufferSize, &_buffers[i]) != noErr)
        {
            AudioQueueDispose(queue, true);
            return;
        }
    }

    UInt32 cookieSize = 0;
    Boolean writable = false;
    if (AudioFileStreamGetPropertyInfo(_parser, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable) == noErr && cookieSize > 0)
    {
        void *cookie = malloc(cookieSize);
        if (cookie != NULL)
        {
            if (AudioFileStreamGetProperty(_parser, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookie) == noErr)
                AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, cookie, cookieSize);
            free(cookie);
        }
    }

    pthread_mutex_lock(&_lock);
    _format = format;
    _bufferSize = bufferSize;
    _queue = queue;
    _fillIndex = 0;
    _bytesFilled = 0;
    _packetsFilled = 0;
    _queuedBuffers = 0;
    for (NSUInteger i = 0; i < TGStreamingAudioBufferCount; i++)
        _inUse[i] = false;
    pthread_mutex_unlock(&_lock);
}

- (bool)interruptedLocked
{
    return _stopped || _seekRequested;
}

- (void)startQueueIfNeededLocked
{
    if (_queue == NULL || _queueRunning || _paused || _seekRequested)
        return;
    if (_queuedBuffers >= TGStreamingAudioStartBuffers || (_endOfStream && _queuedBuffers > 0))
    {
        if (AudioQueueStart(_queue, NULL) == noErr)
            _queueRunning = true;
    }
}

- (bool)enqueueCurrentBuffer
{
    pthread_mutex_lock(&_lock);
    if (_queue == NULL || _bytesFilled == 0 || [self interruptedLocked])
    {
        bool result = ![self interruptedLocked];
        pthread_mutex_unlock(&_lock);
        return result;
    }
    NSUInteger index = _fillIndex;
    AudioQueueBufferRef buffer = _buffers[index];
    buffer->mAudioDataByteSize = _bytesFilled;
    OSStatus status = AudioQueueEnqueueBuffer(_queue, buffer, _packetsFilled, _packetsFilled != 0 ? _descriptions[index] : NULL);
    if (status == noErr)
    {
        _inUse[index] = true;
        _queuedBuffers++;
    }
    _fillIndex = (index + 1) % TGStreamingAudioBufferCount;
    _bytesFilled = 0;
    _packetsFilled = 0;
    [self startQueueIfNeededLocked];
    while (_inUse[_fillIndex] && ![self interruptedLocked])
        pthread_cond_wait(&_condition, &_lock);
    bool result = ![self interruptedLocked];
    pthread_mutex_unlock(&_lock);
    return result;
}

- (void)handlePackets:(const void *)data bytes:(UInt32)numberBytes packets:(UInt32)numberPackets descriptions:(AudioStreamPacketDescription *)descriptions
{
    if (_queue == NULL)
        return;

    if (descriptions != NULL)
    {
        for (UInt32 i = 0; i < numberPackets; i++)
        {
            UInt32 packetSize = descriptions[i].mDataByteSize;
            SInt64 packetOffset = descriptions[i].mStartOffset;
            if (packetSize > _bufferSize || packetOffset < 0 || (UInt64)packetOffset + packetSize > numberBytes)
                continue;
            if (_bytesFilled + packetSize > _bufferSize || _packetsFilled >= TGStreamingAudioMaximumPackets)
            {
                if (![self enqueueCurrentBuffer])
                    return;
            }
            pthread_mutex_lock(&_lock);
            bool interrupted = [self interruptedLocked];
            pthread_mutex_unlock(&_lock);
            if (interrupted)
                return;
            memcpy((uint8_t *)_buffers[_fillIndex]->mAudioData + _bytesFilled, (const uint8_t *)data + packetOffset, packetSize);
            AudioStreamPacketDescription description = descriptions[i];
            description.mStartOffset = _bytesFilled;
            _descriptions[_fillIndex][_packetsFilled] = description;
            _packetsFilled++;
            _bytesFilled += packetSize;
            _parsedPacketBytes += packetSize;
            _parsedPackets++;
        }
    }
    else
    {
        UInt32 offset = 0;
        while (offset < numberBytes)
        {
            if (_bytesFilled >= _bufferSize)
            {
                if (![self enqueueCurrentBuffer])
                    return;
            }
            UInt32 chunk = MIN(numberBytes - offset, _bufferSize - _bytesFilled);
            memcpy((uint8_t *)_buffers[_fillIndex]->mAudioData + _bytesFilled, (const uint8_t *)data + offset, chunk);
            _bytesFilled += chunk;
            offset += chunk;
        }
    }
}

- (void)handleBufferCompleted:(AudioQueueBufferRef)buffer
{
    pthread_mutex_lock(&_lock);
    for (NSUInteger i = 0; i < TGStreamingAudioBufferCount; i++)
    {
        if (_buffers[i] == buffer && _inUse[i])
        {
            _inUse[i] = false;
            if (_queuedBuffers > 0)
                _queuedBuffers--;
            break;
        }
    }
    if (_queuedBuffers == 0 && _queueRunning && !_endOfStream && _queue != NULL)
    {
        AudioQueuePause(_queue);
        _queueRunning = false;
    }
    pthread_cond_broadcast(&_condition);
    pthread_mutex_unlock(&_lock);
}

@end
