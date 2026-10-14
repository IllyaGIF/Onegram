#import "TGOpusAudioPlayerAU.h"
#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"
#import "TGPCMBuffer.h"
#import "opusfile.h"
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AUGraph.h>
#import <AudioToolbox/AudioServices.h>
#include <pthread.h>
#include <math.h>

static const int TGOpusAudioPlayerSampleRate = 48000;
static const uint32_t TGOpusAudioPlayerDecodeFrames = 5760;

@interface TGOpusAudioPlayerReference : NSObject
@property (nonatomic, weak) TGOpusAudioPlayerAU *value;
@end

@implementation TGOpusAudioPlayerReference
@end

@interface TGOpusAudioPlayerAU ()
{
    NSString *_filePath;
    CGFloat _rate;
    bool _isPaused;
    bool _isSeekable;
    bool _finished;
    OggOpusFile *_opusFile;
    AUGraph _graph;
    AudioComponentInstance _timePitchAudioUnit;
    AudioComponentInstance _converterAudioUnit;
    AudioComponentInstance _outputAudioUnit;
    TGPCMBuffer *_pcmBuffer;
    dispatch_source_t _decodeTimer;
    TGOpusAudioPlayerReference *_timerReference;
    int64_t _bufferStartPcmOffset;
    int64_t _renderedPcmOffset;
    uint32_t _lastReadOffset;
    int64_t _currentPcmOffset;
    int64_t _totalPcmDuration;
    pthread_mutex_t _positionMutex;
    NSTimeInterval _outputLatency;
    CFTimeInterval _drainDeadline;
}
- (bool)fillAvailablePCM;
- (void)updatePosition;
- (void)servicePlayback;
- (bool)setupGraph;
@end

static OSStatus TGOpusAudioPlayerCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *__unused inTimeStamp, UInt32 __unused inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    TGPCMBuffer *pcmBuffer = (TGPCMBuffer *)inRefCon;
    if (ioData == NULL || ioData->mNumberBuffers != 1 || ioData->mBuffers[0].mData == NULL)
        return kAudioUnitErr_InvalidParameter;
    AudioBuffer *buffer = &ioData->mBuffers[0];
    uint32_t frames = buffer->mDataByteSize / (2 * sizeof(int16_t));
    if (frames > inNumberFrames)
        frames = inNumberFrames;
    uint32_t readFrames = TGPCMBufferRead(pcmBuffer, (int16_t *)buffer->mData, frames);
    size_t readBytes = (size_t)readFrames * 2 * sizeof(int16_t);
    size_t requiredBytes = (size_t)frames * 2 * sizeof(int16_t);
    if (readBytes < requiredBytes)
        memset((uint8_t *)buffer->mData + readBytes, 0, requiredBytes - readBytes);
    buffer->mNumberChannels = 2;
    buffer->mDataByteSize = frames * 2 * sizeof(int16_t);
    if (readFrames == 0 && ioActionFlags != NULL)
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
    else if (ioActionFlags != NULL)
        *ioActionFlags &= ~kAudioUnitRenderAction_OutputIsSilence;
    return noErr;
}

@implementation TGOpusAudioPlayerAU

+ (bool)canPlayFile:(NSString *)path
{
    int error = OPUS_OK;
    OggOpusFile *file = op_test_file([path fileSystemRepresentation], &error);
    if (file == NULL)
        return false;
    error = op_test_open(file);
    op_free(file);
    return error == OPUS_OK;
}

- (instancetype)initWithPath:(NSString *)path music:(bool)music controlAudioSession:(bool)controlAudioSession
{
    self = [super initWithMusic:music controlAudioSession:controlAudioSession];
    if (self != nil)
    {
        _filePath = [path copy];
        _rate = 1.0f;
        _isPaused = true;
        pthread_mutex_init(&_positionMutex, NULL);
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];
    pthread_mutex_destroy(&_positionMutex);
}

- (void)cancelDecodeTimer
{
    @synchronized (_timerReference)
    {
        _timerReference.value = nil;
    }
    _timerReference = nil;
    if (_decodeTimer != NULL)
    {
        dispatch_source_cancel(_decodeTimer);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_decodeTimer);
#endif
        _decodeTimer = NULL;
    }
}

- (void)cleanup
{
    [self cancelDecodeTimer];
    AUGraph graph = _graph;
    OggOpusFile *opusFile = _opusFile;
    TGPCMBuffer *pcmBuffer = _pcmBuffer;
    _graph = NULL;
    _opusFile = NULL;
    _pcmBuffer = NULL;
    _timePitchAudioUnit = NULL;
    _converterAudioUnit = NULL;
    _outputAudioUnit = NULL;
    _isPaused = true;
    _drainDeadline = 0.0;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        if (graph != NULL)
        {
            AUGraphStop(graph);
            AUGraphUninitialize(graph);
            AUGraphClose(graph);
            DisposeAUGraph(graph);
        }
        if (opusFile != NULL)
            op_free(opusFile);
        TGPCMBufferDestroy(pcmBuffer);
    }];
    [self _endAudioSessionFinal];
}

- (void)cleanupAndReportError
{
    [self cleanup];
    [self _notifyPaused];
}

- (bool)perform:(OSStatus)status error:(NSString *)operation
{
    if (status == noErr)
        return true;
    TGLog(@"[TGOpusAudioPlayer#%p %@ failed: %d]", self, operation, (int)status);
    [self cleanupAndReportError];
    return false;
}

- (bool)setupGraph
{
    if (![self perform:NewAUGraph(&_graph) error:@"NewAUGraph"])
        return false;
    AUNode converterNode, timePitchNode, outputNode;
    AudioComponentDescription converterDescription = {};
    converterDescription.componentType = kAudioUnitType_FormatConverter;
    converterDescription.componentSubType = kAudioUnitSubType_AUConverter;
    converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponentDescription timePitchDescription = converterDescription;
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
    timePitchDescription.componentSubType = kAudioUnitSubType_AUiPodTime;
#else
    timePitchDescription.componentSubType = iosMajorVersion() >= 5 ? kAudioUnitSubType_AUiPodTimeOther : kAudioUnitSubType_AUiPodTime;
#endif
    AudioComponentDescription outputDescription = {};
    outputDescription.componentType = kAudioUnitType_Output;
    outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    if (![self perform:AUGraphAddNode(_graph, &converterDescription, &converterNode) error:@"converter node"] ||
        ![self perform:AUGraphAddNode(_graph, &timePitchDescription, &timePitchNode) error:@"time pitch node"] ||
        ![self perform:AUGraphAddNode(_graph, &outputDescription, &outputNode) error:@"output node"] ||
        ![self perform:AUGraphOpen(_graph) error:@"AUGraphOpen"])
        return false;
    AudioComponentInstance converterUnit, outputUnit;
    if (![self perform:AUGraphNodeInfo(_graph, converterNode, NULL, &converterUnit) error:@"converter info"] ||
        ![self perform:AUGraphNodeInfo(_graph, timePitchNode, NULL, &_timePitchAudioUnit) error:@"time pitch info"] ||
        ![self perform:AUGraphNodeInfo(_graph, outputNode, NULL, &outputUnit) error:@"output info"])
        return false;
    _converterAudioUnit = converterUnit;
    _outputAudioUnit = outputUnit;
    AudioStreamBasicDescription inputFormat = {};
    inputFormat.mSampleRate = TGOpusAudioPlayerSampleRate;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mChannelsPerFrame = 2;
    inputFormat.mBitsPerChannel = 16;
    inputFormat.mBytesPerFrame = 2 * sizeof(int16_t);
    inputFormat.mBytesPerPacket = inputFormat.mBytesPerFrame;
    AudioStreamBasicDescription processingFormat = {};
    UInt32 formatSize = sizeof(processingFormat);
    if (![self perform:AudioUnitGetProperty(_timePitchAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &processingFormat, &formatSize) error:@"time pitch format"])
        return false;
    processingFormat.mSampleRate = TGOpusAudioPlayerSampleRate;
    if (![self perform:AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &inputFormat, sizeof(inputFormat)) error:@"PCM input format"] ||
        ![self perform:AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &processingFormat, sizeof(processingFormat)) error:@"converter output format"] ||
        ![self perform:AudioUnitSetProperty(_timePitchAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &processingFormat, sizeof(processingFormat)) error:@"time pitch input format"] ||
        ![self perform:AudioUnitSetProperty(_timePitchAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &processingFormat, sizeof(processingFormat)) error:@"time pitch output format"] ||
        ![self perform:AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &processingFormat, sizeof(processingFormat)) error:@"hardware input format"])
        return false;
    UInt32 maximumFrames = 4096;
    AudioComponentInstance units[] = {converterUnit, _timePitchAudioUnit, outputUnit};
    for (NSUInteger i = 0; i < sizeof(units) / sizeof(units[0]); i++)
    {
        if (![self perform:AudioUnitSetProperty(units[i], kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFrames, sizeof(maximumFrames)) error:@"maximum frames"])
            return false;
    }
    AURenderCallbackStruct callback = {};
    callback.inputProc = TGOpusAudioPlayerCallback;
    callback.inputProcRefCon = _pcmBuffer;
    if (![self perform:AUGraphSetNodeInputCallback(_graph, converterNode, 0, &callback) error:@"PCM callback"] ||
        ![self perform:AUGraphConnectNodeInput(_graph, converterNode, 0, timePitchNode, 0) error:@"converter connection"] ||
        ![self perform:AUGraphConnectNodeInput(_graph, timePitchNode, 0, outputNode, 0) error:@"output connection"] ||
        ![self perform:AudioUnitSetParameter(_timePitchAudioUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, (Float32)_rate, 0) error:@"playback rate"] ||
        ![self perform:AUGraphInitialize(_graph) error:@"AUGraphInitialize"])
        return false;
    Float32 hardwareLatency = 0.0f, bufferDuration = 0.0f;
    UInt32 size = sizeof(hardwareLatency);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputLatency, &size, &hardwareLatency);
    size = sizeof(bufferDuration);
    AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration, &size, &bufferDuration);
    Float64 pitchLatency = 0.0;
    size = sizeof(pitchLatency);
    AudioUnitGetProperty(_timePitchAudioUnit, kAudioUnitProperty_Latency, kAudioUnitScope_Global, 0, &pitchLatency, &size);
    _outputLatency = MAX(0.1, hardwareLatency + 2.0 * bufferDuration + pitchLatency);
    return true;
}

- (bool)fillAvailablePCM
{
    opus_int16 samples[TGOpusAudioPlayerDecodeFrames * 2];
    int holes = 0;
    while (!_finished && TGPCMBufferWritable(_pcmBuffer) >= TGOpusAudioPlayerDecodeFrames)
    {
        int frames = op_read_stereo(_opusFile, samples, TGOpusAudioPlayerDecodeFrames * 2);
        if (frames == OP_HOLE && holes++ < 16)
            continue;
        if (frames < 0)
        {
            TGLog(@"[TGOpusAudioPlayer#%p decode failed: %d]", self, frames);
            [self cleanupAndReportError];
            return false;
        }
        if (frames == 0)
        {
            _finished = true;
            break;
        }
        holes = 0;
        TGPCMBufferWrite(_pcmBuffer, samples, (uint32_t)frames);
    }
    return true;
}

- (void)updatePosition
{
    if (_pcmBuffer == NULL)
        return;
    uint32_t readOffset = TGPCMBufferLoad(&_pcmBuffer->readOffset);
    _renderedPcmOffset += (uint32_t)(readOffset - _lastReadOffset);
    _lastReadOffset = readOffset;
    pthread_mutex_lock(&_positionMutex);
    _currentPcmOffset = _renderedPcmOffset;
    pthread_mutex_unlock(&_positionMutex);
}

- (void)servicePlayback
{
    if (_isPaused || _opusFile == NULL || _pcmBuffer == NULL)
        return;
    @autoreleasepool
    {
        if (![self fillAvailablePCM])
            return;
        [self updatePosition];
        if (_finished && TGPCMBufferReadable(_pcmBuffer) == 0)
        {
            CFTimeInterval now = CACurrentMediaTime();
            if (_drainDeadline == 0.0)
                _drainDeadline = now + _outputLatency;
            else if (now >= _drainDeadline)
            {
                [self pause:nil];
                [self _notifyFinished];
            }
        }
    }
}

- (void)startDecodeTimer
{
    [self cancelDecodeTimer];
    TGOpusAudioPlayerReference *reference = [[TGOpusAudioPlayerReference alloc] init];
    reference.value = self;
    _timerReference = reference;
    _decodeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [TGAudioPlayer _playerQueue].nativeQueue);
    dispatch_source_set_timer(_decodeTimer, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), 20 * NSEC_PER_MSEC, 2 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_decodeTimer, ^
    {
        TGOpusAudioPlayerAU *player = nil;
        @synchronized (reference)
        {
            player = reference.value;
        }
        [player servicePlayback];
    });
    dispatch_resume(_decodeTimer);
}

- (void)setRate:(CGFloat)rate
{
    if (!isfinite(rate) || rate <= 0.0f)
        return;
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        _rate = rate;
        if (_timePitchAudioUnit != NULL)
            [self perform:AudioUnitSetParameter(_timePitchAudioUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, (Float32)rate, 0) error:@"playback rate"];
    }];
}

- (void)playFromPosition:(NSTimeInterval)position
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        if (!_isPaused)
            return;
        [self _beginAudioSession];
        if (_opusFile == NULL)
        {
            int error = OPUS_OK;
            _opusFile = op_open_file([_filePath fileSystemRepresentation], &error);
            if (_opusFile == NULL)
            {
                TGLog(@"[TGOpusAudioPlayer#%p open failed: %d]", self, error);
                [self cleanupAndReportError];
                return;
            }
            _isSeekable = op_seekable(_opusFile);
            pthread_mutex_lock(&_positionMutex);
            _totalPcmDuration = MAX((int64_t)0, op_pcm_total(_opusFile, -1));
            pthread_mutex_unlock(&_positionMutex);
            _pcmBuffer = TGPCMBufferCreate(32768, 2);
            if (_pcmBuffer == NULL)
            {
                [self cleanupAndReportError];
                return;
            }
            if (![self setupGraph])
                return;
        }
        if (![self perform:AUGraphInitialize(_graph) error:@"resume initialization"])
            return;
        if (_isSeekable)
        {
            pthread_mutex_lock(&_positionMutex);
            int64_t target = position >= 0.0 && isfinite(position) ? (int64_t)(MIN(position, _totalPcmDuration / (double)TGOpusAudioPlayerSampleRate) * TGOpusAudioPlayerSampleRate) : _currentPcmOffset;
            if (position < 0.0 && _finished && TGPCMBufferReadable(_pcmBuffer) == 0)
                target = 0;
            pthread_mutex_unlock(&_positionMutex);
            int result = op_pcm_seek(_opusFile, target);
            if (result != OPUS_OK)
            {
                [self cleanupAndReportError];
                return;
            }
            TGPCMBufferReset(_pcmBuffer);
            AudioComponentInstance units[] = {_converterAudioUnit, _timePitchAudioUnit, _outputAudioUnit};
            for (NSUInteger i = 0; i < sizeof(units) / sizeof(units[0]); i++)
            {
                if (![self perform:AudioUnitReset(units[i], kAudioUnitScope_Global, 0) error:@"seek reset"])
                    return;
            }
            _bufferStartPcmOffset = MAX((ogg_int64_t)0, op_pcm_tell(_opusFile));
            _renderedPcmOffset = _bufferStartPcmOffset;
            _lastReadOffset = 0;
            _finished = false;
        }
        if (![self fillAvailablePCM])
            return;
        _drainDeadline = 0.0;
        [self updatePosition];
        _isPaused = false;
        [self startDecodeTimer];
        [self perform:AUGraphStart(_graph) error:@"AUGraphStart"];
    }];
}

- (void)pause:(void (^)())completion
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        if (_graph != NULL)
        {
            AUGraphStop(_graph);
            OSStatus status = AUGraphUninitialize(_graph);
            if (status != noErr)
                TGLog(@"[TGOpusAudioPlayer#%p pause uninitialize failed: %d]", self, (int)status);
        }
        [self updatePosition];
        _isPaused = true;
        [self cancelDecodeTimer];
        [self _endAudioSession];
        if (completion != nil)
            completion();
    }];
}

- (void)stop
{
    [[TGAudioPlayer _playerQueue] dispatchOnQueue:^
    {
        [self cleanup];
    }];
}

- (NSTimeInterval)currentPositionSync:(bool)sync
{
    if (sync)
        [[TGAudioPlayer _playerQueue] dispatchOnQueue:^{ [self updatePosition]; } synchronous:true];
    pthread_mutex_lock(&_positionMutex);
    NSTimeInterval position = _currentPcmOffset / (NSTimeInterval)TGOpusAudioPlayerSampleRate;
    pthread_mutex_unlock(&_positionMutex);
    return position;
}

- (NSTimeInterval)duration
{
    pthread_mutex_lock(&_positionMutex);
    NSTimeInterval duration = _totalPcmDuration / (NSTimeInterval)TGOpusAudioPlayerSampleRate;
    pthread_mutex_unlock(&_positionMutex);
    return duration;
}

@end
