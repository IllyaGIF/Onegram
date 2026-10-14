/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGOpusAudioRecorder.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"

#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGLiveUploadActor.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/ExtendedAudioFile.h>
#import <AudioUnit/AudioUnit.h>

#import "opus.h"
#import "opusenc.h"
#import "TGPCMBuffer.h"

#import "TGDataItem.h"

#import "TGAudioSessionManager.h"

#import "TGTelegramNetworking.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

#define kOutputBus 0
#define kInputBus 1
static const int TGOpusAudioPlayerSampleRate = 48000;

static const int TGOpusAudioRecorderSampleRate = 24000;

typedef struct
{
    AudioComponentInstance audioUnit;
    bool audioUnitStarted;
    bool audioUnitInitialized;
    
    AudioComponentInstance playbackUnit;
    bool playbackUnitStarted;
    bool playbackUnitInitialized;
    
    int64_t toneOffset;
    TGPCMBuffer *pcmBuffer;
    int16_t *inputSamples;
    UInt32 maximumFrames;
    volatile uint32_t acceptingSamples;
    volatile uint32_t captureFailed;
} TGOpusAudioRecorderContext;

static NSData *toneAudioBuffer;

@class TGOpusAudioRecorder;

@interface TGOpusAudioRecorderReference : NSObject
@property (nonatomic, weak) TGOpusAudioRecorder *value;
@property (nonatomic) int recorderId;
@end

@implementation TGOpusAudioRecorderReference
@end

static TGOpusAudioRecorder *TGOpusAudioRecorderResolveReference(TGOpusAudioRecorderReference *reference)
{
    TGOpusAudioRecorder *result = nil;
    @synchronized (reference)
    {
        result = reference.value;
    }
    return result;
}

static dispatch_semaphore_t playSoundSemaphore = nil;

@interface TGOpusAudioRecorder () <ASWatcher>
{
    TGDataItem *_tempFileItem;
    TGOpusAudioRecorderContext *_recorderContext;
    TGOpusAudioRecorderReference *_lifetimeReference;
    
    TGOggOpusWriter *_oggWriter;
    
    NSMutableData *_audioBuffer;
    
    NSString *_liveUploadPath;
    
    SMetaDisposable *_currentAudioSession;
    
    bool _recording;
    bool _waitForTone;
    NSTimeInterval _waitForToneStart;
    bool _stopped;
    bool _captureFailed;
    bool _captureFailureReported;
    dispatch_source_t _captureTimer;
    
    NSMutableData *_waveformSamples;
    int16_t _waveformPeak;
    int _waveformPeakCount;
    
    int16_t _micLevelPeak;
    int _micLevelPeakCount;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic) int recorderId;
- (void)drainCapturedPCM;
- (void)reportCaptureFailure;

@end

@implementation TGOpusAudioRecorder

- (instancetype)initWithFileEncryption:(bool)fileEncryption
{
    self = [super init];
    if (self != nil)
    {
        _recorderContext = calloc(1, sizeof(TGOpusAudioRecorderContext));
        if (_recorderContext == NULL)
            return nil;
        _lifetimeReference = [[TGOpusAudioRecorderReference alloc] init];
        _lifetimeReference.value = self;
        _actionHandle = [[ASHandle alloc] initWithDelegate:self];
        
        _tempFileItem = [[TGDataItem alloc] initWithTempFile];
        
        _currentAudioSession = [[SMetaDisposable alloc] init];
        
        _waveformSamples = [[NSMutableData alloc] init];
        
        [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
        {
            static int nextRecorderId = 1;
            _recorderId = nextRecorderId++;
            TGOpusAudioRecorderReference *reference = _lifetimeReference;
            @synchronized (reference)
            {
                reference.value = self;
                reference.recorderId = _recorderId;
            }
            
            static int nextActionId = 0;
            int actionId = nextActionId++;
            _liveUploadPath = [[NSString alloc] initWithFormat:@"/tg/liveUpload/(%d)", actionId];
            
            [ActionStageInstance() requestActor:_liveUploadPath options:@{
                @"fileItem": _tempFileItem,
                @"encryptFile": @(fileEncryption),
                @"mediaTypeTag": @(TGNetworkMediaTypeTagAudio)
            } flags:0 watcher:self];
        }];
    }
    return self;
}

- (void)dealloc
{
    [ActionStageInstance() removeWatcher:self];
    
    [self cleanup];
}

+ (ASQueue *)processingQueue
{
    static ASQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ASQueue alloc] initWithName:"org.telegram.opusAudioRecorderQueue"];
    });
    
    return queue;
}

- (void)cleanup
{
    [self cleanup:true];
}

- (void)cleanup:(bool)endAudioSession
{
    intptr_t objectId = (intptr_t)self;
    int recorderId = _recorderId;
    TGOpusAudioRecorderContext *context = _recorderContext;
    _recorderContext = NULL;
    
    TGOpusAudioRecorderReference *reference = _lifetimeReference;
    @synchronized (reference)
    {
        if (reference.value == self && reference.recorderId == recorderId)
        {
            reference.value = nil;
            reference.recorderId = -1;
        }
    }
    
    _oggWriter = nil;
    if (_captureTimer != NULL)
    {
        dispatch_source_cancel(_captureTimer);
#if !OS_OBJECT_USE_OBJC
        dispatch_release(_captureTimer);
#endif
        _captureTimer = NULL;
    }
    
    [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
    {
        if (context != NULL)
        {
            
            if (context->audioUnitStarted && context->audioUnit != NULL)
            {
                OSStatus status = noErr;
                status = AudioOutputUnitStop(context->audioUnit);
                if (status != noErr)
                    TGLog(@"[TGOpusAudioRecorder#%x AudioOutputUnitStop failed: %d]", objectId, (int)status);
                
                context->audioUnitStarted = false;
            }
            
            if (context->audioUnit != NULL)
            {
                if (context->audioUnitInitialized)
                    AudioUnitUninitialize(context->audioUnit);
                OSStatus status = noErr;
                status = AudioComponentInstanceDispose(context->audioUnit);
                if (status != noErr)
                    TGLog(@"[TGOpusAudioRecorder#%x AudioComponentInstanceDispose failed: %d]", objectId, (int)status);
                
                context->audioUnit = NULL;
            }
            
            if (context->playbackUnitStarted && context->playbackUnit != NULL)
            {
                OSStatus status = noErr;
                status = AudioOutputUnitStop(context->playbackUnit);
                if (status != noErr)
                    TGLog(@"[TGOpusAudioRecorder#%x playback AudioOutputUnitStop failed: %d]", objectId, (int)status);
                
                context->playbackUnitStarted = false;
            }
            
            if (context->playbackUnit != NULL)
            {
                if (context->playbackUnitInitialized)
                    AudioUnitUninitialize(context->playbackUnit);
                OSStatus status = noErr;
                status = AudioComponentInstanceDispose(context->playbackUnit);
                if (status != noErr)
                    TGLog(@"[TGOpusAudioRecorder#%x playback AudioComponentInstanceDispose failed: %d]", objectId, (int)status);
                
                context->playbackUnit = NULL;
            }
            TGPCMBufferDestroy(context->pcmBuffer);
            context->pcmBuffer = NULL;
            free(context->inputSamples);
            context->inputSamples = NULL;
            context->maximumFrames = 0;
            free(context);
        }
    }];
    
    if (endAudioSession)
        [self _endAudioSession];
}

- (void)_beginAudioSession:(bool)speaker
{
    [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
    {
        TGOpusAudioRecorderReference *reference = _lifetimeReference;
        [_currentAudioSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:speaker ? TGAudioSessionTypePlayAndRecordHeadphones : TGAudioSessionTypePlayAndRecord interrupted:^
        {
            TGOpusAudioRecorder *strongSelf = TGOpusAudioRecorderResolveReference(reference);
            if (strongSelf != nil)
            {
                if (strongSelf->_pauseRecording) {
                    strongSelf->_pauseRecording();
                }
            }
        }]];
    } synchronous:true];
}

- (void)_endAudioSession
{
    id<SDisposable> currentAudioSession = _currentAudioSession;
    [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
    {
        [currentAudioSession dispose];
    }];
}

- (void)prepareRecord:(bool)playTone completion:(void (^)())completion
{
    [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
    {
        if (_stopped || _recorderContext == NULL) {
            if (completion) {
                completion();
            }
            return;
        }
        
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
        OSStatus status = inputComponent == NULL ? kAudioUnitErr_InvalidParameter : AudioComponentInstanceNew(inputComponent, &_recorderContext->audioUnit);
        if (status != noErr)
        {
            [self cleanup];
            return;
        }
        
        static const UInt32 one = 1;
        status = AudioUnitSetProperty(_recorderContext->audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
        if (status != noErr)
        {
            TGLog(@"[TGOpusAudioRecorder#%x AudioUnitSetProperty kAudioOutputUnitProperty_EnableIO failed: %d]", self, (int)status);
            [self cleanup];
            
            return;
        }
        
        AudioStreamBasicDescription inputAudioFormat = {0};
        inputAudioFormat.mSampleRate = TGOpusAudioRecorderSampleRate;
        inputAudioFormat.mFormatID = kAudioFormatLinearPCM;
        inputAudioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        inputAudioFormat.mFramesPerPacket = 1;
        inputAudioFormat.mChannelsPerFrame = 1;
        inputAudioFormat.mBitsPerChannel = 16;
        inputAudioFormat.mBytesPerPacket = 2;
        inputAudioFormat.mBytesPerFrame = 2;
        status = AudioUnitSetProperty(_recorderContext->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &inputAudioFormat, sizeof(inputAudioFormat));
        if (status != noErr)
        {
            TGLog(@"[TGOpusAudioRecorder#%x AudioUnitSetProperty kAudioUnitProperty_StreamFormat failed: %d]", self, (int)status);
            [self cleanup];
            
            return;
        }
        
        AudioStreamBasicDescription audioFormat = {0};
        audioFormat.mSampleRate = TGOpusAudioRecorderSampleRate;
        audioFormat.mFormatID = kAudioFormatLinearPCM;
        audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioFormat.mFramesPerPacket = 1;
        audioFormat.mChannelsPerFrame = 1;
        audioFormat.mBitsPerChannel = 16;
        audioFormat.mBytesPerPacket = 2;
        audioFormat.mBytesPerFrame = 2;
        status = AudioUnitSetProperty(_recorderContext->audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(audioFormat));
        if (status != noErr)
        {
            TGLog(@"[TGOpusAudioRecorder#%x AudioUnitSetProperty kAudioUnitProperty_StreamFormat failed: %d]", self, (int)status);
            [self cleanup];
            
            return;
        }
        
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = &TGOpusRecordingCallback;
        callbackStruct.inputProcRefCon = _recorderContext;
        if (AudioUnitSetProperty(_recorderContext->audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, sizeof(callbackStruct)) != noErr)
        {
            TGLog(@"[TGOpusAudioRecorder#%x AudioUnitSetProperty kAudioOutputUnitProperty_SetInputCallback failed]", self);
            [self cleanup];
            
            return;
        }
        
        static const UInt32 zero = 0;
        if (AudioUnitSetProperty(_recorderContext->audioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, kInputBus, &zero, sizeof(zero)) != noErr)
        {
            TGLog(@"[TGOpusAudioRecorder#%x AudioUnitSetProperty kAudioUnitProperty_ShouldAllocateBuffer failed]", self);
            [self cleanup];
            
            return;
        }
        
        UInt32 maximumFrames = 4096;
        status = AudioUnitSetProperty(_recorderContext->audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFrames, sizeof(maximumFrames));
        UInt32 maximumFramesSize = sizeof(maximumFrames);
        if (status == noErr)
            status = AudioUnitGetProperty(_recorderContext->audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFrames, &maximumFramesSize);
        if (status != noErr || maximumFrames == 0 || maximumFrames > 65536)
        {
            [self cleanup];
            return;
        }
        _recorderContext->maximumFrames = maximumFrames;
        _recorderContext->inputSamples = malloc((size_t)maximumFrames * sizeof(int16_t));
        _recorderContext->pcmBuffer = TGPCMBufferCreate(65536, 1);
        TGPCMBufferStore(&_recorderContext->acceptingSamples, 0);
        TGPCMBufferStore(&_recorderContext->captureFailed, 0);
        if (_recorderContext->inputSamples == NULL || _recorderContext->pcmBuffer == NULL)
        {
            [self cleanup];
            return;
        }
        _oggWriter = [[TGOggOpusWriter alloc] init];
        if (![_oggWriter beginWithDataItem:_tempFileItem sampleRate:TGOpusAudioRecorderSampleRate bitrate:32000])
        {
            TGLog(@"[TGOpusAudioRecorder#%x error initializing ogg opus writer]", self);
            [self cleanup];
            
            return;
        }
        
        
        status = AudioUnitInitialize(_recorderContext->audioUnit);
        if (status == noErr)
            _recorderContext->audioUnitInitialized = true;
        else
        {
            TGLog(@"[TGOpusAudioRecorder#%x AudioUnitInitialize failed: %d]", self, (int)status);
            [self cleanup];
            
            return;
        }
        
        
        status = AudioOutputUnitStart(_recorderContext->audioUnit);
        if (status == noErr)
        {
            _recorderContext->audioUnitStarted = true;
        }
        else
        {
            TGLog(@"[TGOpusAudioRecorder#%x AudioOutputUnitStart failed: %d]", self, (int)status);
            [self cleanup];
            
            return;
        }
        
        if (playTone) {
            [self loadToneBuffer];
            _waitForTone = true;
            _recorderContext->toneOffset = 0;
            
            AudioComponentDescription desc;
            desc.componentType = kAudioUnitType_Output;
            desc.componentSubType = kAudioUnitSubType_RemoteIO;
            desc.componentFlags = 0;
            desc.componentFlagsMask = 0;
            desc.componentManufacturer = kAudioUnitManufacturer_Apple;
            AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
            AudioComponentInstanceNew(inputComponent, &_recorderContext->playbackUnit);
            
            OSStatus status = noErr;
            
            static const UInt32 one = 1;
            status = AudioUnitSetProperty(_recorderContext->playbackUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &one, sizeof(one));
            if (status != noErr)
            {
                TGLog(@"[TGOpusAudioPlayer#%x AudioUnitSetProperty kAudioOutputUnitProperty_EnableIO failed: %d]", self, (int)status);
                [self cleanup];
                
                return;
            }
            
            AudioStreamBasicDescription outputAudioFormat = {0};
            outputAudioFormat.mSampleRate = TGOpusAudioPlayerSampleRate;
            outputAudioFormat.mFormatID = kAudioFormatLinearPCM;
            outputAudioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
            outputAudioFormat.mFramesPerPacket = 1;
            outputAudioFormat.mChannelsPerFrame = 1;
            outputAudioFormat.mBitsPerChannel = 16;
            outputAudioFormat.mBytesPerPacket = 2;
            outputAudioFormat.mBytesPerFrame = 2;
            status = AudioUnitSetProperty(_recorderContext->playbackUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &outputAudioFormat, sizeof(outputAudioFormat));
            if (status != noErr)
            {
                TGLog(@"[TGOpusAudioPlayer#%x playback AudioUnitSetProperty kAudioUnitProperty_StreamFormat failed: %d]", self, (int)status);
                [self cleanup];
                
                return;
            }
            
            AURenderCallbackStruct callbackStruct;
            callbackStruct.inputProc = &TGOpusAudioPlayerCallback;
            callbackStruct.inputProcRefCon = _recorderContext;
            if (AudioUnitSetProperty(_recorderContext->playbackUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus, &callbackStruct, sizeof(callbackStruct)) != noErr)
            {
                TGLog(@"[TGOpusAudioPlayer#%x playback AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback failed]", self);
                [self cleanup];
                
                return;
            }
            
            status = AudioUnitInitialize(_recorderContext->playbackUnit);
            if (status == noErr)
            {
                _recorderContext->playbackUnitInitialized = true;
                status = AudioOutputUnitStart(_recorderContext->playbackUnit);
                if (status != noErr)
                {
                    TGLog(@"[TGOpusAudioRecorder#%x playback AudioOutputUnitStart failed: %d]", self, (int)status);
                    [self cleanup];
                    return;
                }
                _recorderContext->playbackUnitStarted = true;
            } else {
                TGLog(@"[TGOpusAudioRecorder#%x playback AudioUnitInitialize failed: %d]", self, (int)status);
                [self cleanup];
                return;
            }
            
            _waitForToneStart = CACurrentMediaTime();
        }
        
        TGOpusAudioRecorderReference *reference = _lifetimeReference;
        _captureTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, [TGOpusAudioRecorder processingQueue].nativeQueue);
        dispatch_source_set_timer(_captureTimer, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), 20 * NSEC_PER_MSEC, 2 * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(_captureTimer, ^
        {
            TGOpusAudioRecorder *recorder = TGOpusAudioRecorderResolveReference(reference);
            if (recorder != nil && recorder->_recording)
                [recorder drainCapturedPCM];
        });
        dispatch_resume(_captureTimer);
        dispatch_block_t ready = ^
        {
            if (_stopped || _recorderContext == NULL)
                return;
            _waitForTone = false;
            if (completion != nil)
                completion();
        };
        if (_waitForTone)
        {
            NSTimeInterval toneDuration = MAX(0.44, toneAudioBuffer.length / (2.0 * TGOpusAudioPlayerSampleRate));
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(toneDuration * NSEC_PER_SEC)), [TGOpusAudioRecorder processingQueue].nativeQueue, ready);
        }
        else
            ready();
    }];
}

- (void)loadToneBuffer {
    if (toneAudioBuffer != nil) {
        return;
    }

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    NSURL *url = OGPlatformBundleResourceURL([NSBundle mainBundle], @"begin_record", @"caf");
    if (url == nil)
        return;

    ExtAudioFileRef audioFile = NULL;
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)url, &audioFile);
    if (status != noErr || audioFile == NULL)
        return;

    AudioStreamBasicDescription outputFormat = {0};
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate = TGOpusAudioPlayerSampleRate;
    outputFormat.mFormatID = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    outputFormat.mFramesPerPacket = 1;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel = 16;
    outputFormat.mBytesPerPacket = 2;
    outputFormat.mBytesPerFrame = 2;

    UInt32 formatSize = sizeof(outputFormat);
    status = ExtAudioFileSetProperty(audioFile, kExtAudioFileProperty_ClientDataFormat, formatSize, &outputFormat);
    if (status != noErr)
    {
        ExtAudioFileDispose(audioFile);
        return;
    }

    NSMutableData *data = [[NSMutableData alloc] init];
    int16_t samples[4096];
    while (true)
    {
        UInt32 frameCount = 4096;
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0].mNumberChannels = 1;
        bufferList.mBuffers[0].mDataByteSize = sizeof(samples);
        bufferList.mBuffers[0].mData = samples;
        status = ExtAudioFileRead(audioFile, &frameCount, &bufferList);
        if (status != noErr || frameCount == 0)
            break;
        [data appendBytes:samples length:(NSUInteger)frameCount * sizeof(int16_t)];
    }
    ExtAudioFileDispose(audioFile);
    if (status == noErr)
        toneAudioBuffer = data;
#else
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,
                                    [NSNumber numberWithFloat:48000.0], AVSampleRateKey,
                                    [NSNumber numberWithInt:16], AVLinearPCMBitDepthKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsNonInterleaved,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsFloatKey,
                                    [NSNumber numberWithBool:NO], AVLinearPCMIsBigEndianKey,
                                    nil];
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:OGPlatformBundleResourceURL([NSBundle mainBundle], @"begin_record", @"caf") options:nil];
    if (asset == nil) {
        return;
    }
    
    NSError *assetError = nil;
    AVAssetReader *iPodAssetReader = [AVAssetReader assetReaderWithAsset:asset error:&assetError];
    if (assetError) {
        NSLog (@"error: %@", assetError);
        return;
    }
    
    AVAssetReaderOutput *readerOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:outputSettings];
    
    if (! [iPodAssetReader canAddOutput: readerOutput]) {
        NSLog (@"can't add reader output... die!");
        return;
    }
    
    [iPodAssetReader addOutput: readerOutput];
    
    if (! [iPodAssetReader startReading]) {
        NSLog(@"Unable to start reading!");
        return;
    }

    NSMutableData *data = [[NSMutableData alloc] init];
    while (iPodAssetReader.status == AVAssetReaderStatusReading) {
        CMSampleBufferRef nextBuffer = [readerOutput copyNextSampleBuffer];
        
        if (nextBuffer) {
            AudioBufferList abl;
            CMBlockBufferRef blockBuffer = NULL;
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer, NULL, &abl, sizeof(abl), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer);
            UInt64 size = CMSampleBufferGetTotalSampleSize(nextBuffer);
            if (size != 0) {
                [data appendBytes:abl.mBuffers[0].mData length:size];
            }
            
            CFRelease(nextBuffer);
            if (blockBuffer) {
                CFRelease(blockBuffer);
            }
        }
        else {
            break;
        }
    }
    
    toneAudioBuffer = data;
#endif
}

- (void)record
{
    [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
    {
        if (_stopped || _recording || _recorderContext == NULL || _recorderContext->pcmBuffer == NULL)
            return;
        TGPCMBufferReset(_recorderContext->pcmBuffer);
        _recording = true;
        TGPCMBufferStore(&_recorderContext->acceptingSamples, 1);
    } synchronous:true];
}

static OSStatus TGOpusRecordingCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, __unused AudioBufferList *ioData)
{
    TGOpusAudioRecorderContext *context = inRefCon;
    if (inNumberFrames > context->maximumFrames || context->inputSamples == NULL)
    {
        TGPCMBufferStore(&context->captureFailed, 1);
        return kAudioUnitErr_TooManyFramesToProcess;
    }
    AudioBufferList bufferList = {0};
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mNumberChannels = 1;
    bufferList.mBuffers[0].mDataByteSize = inNumberFrames * sizeof(int16_t);
    bufferList.mBuffers[0].mData = context->inputSamples;
    OSStatus status = AudioUnitRender(context->audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
    if (status != noErr)
    {
        TGPCMBufferStore(&context->captureFailed, 1);
        return status;
    }
    if (TGPCMBufferLoad(&context->acceptingSamples) != 0)
    {
        UInt32 frames = bufferList.mBuffers[0].mDataByteSize / sizeof(int16_t);
        if (TGPCMBufferWrite(context->pcmBuffer, context->inputSamples, frames) != frames)
            TGPCMBufferStore(&context->captureFailed, 1);
    }
    return noErr;
}

- (void)reportCaptureFailure
{
    _captureFailed = true;
    if (!_captureFailureReported)
    {
        _captureFailureReported = true;
        TGLog(@"[TGOpusAudioRecorder#%p capture or encoding failed]", self);
        if (_pauseRecording != nil)
            _pauseRecording();
    }
}

- (void)drainCapturedPCM
{
    if (_recorderContext == NULL || _recorderContext->pcmBuffer == NULL)
        return;
    @autoreleasepool
    {
        if (TGPCMBufferLoad(&_recorderContext->captureFailed) != 0)
            [self reportCaptureFailure];
        int16_t samples[4096];
        uint32_t frames;
        while ((frames = TGPCMBufferRead(_recorderContext->pcmBuffer, samples, 4096)) != 0)
        {
            if (!_captureFailed && (!_waitForTone || CACurrentMediaTime() - _waitForToneStart > 0.44))
            {
                AudioBuffer buffer = {1, frames * sizeof(int16_t), samples};
                [self _processBuffer:&buffer];
            }
        }
    }
}

static OSStatus TGOpusAudioPlayerCallback(void *inRefCon, __unused AudioUnitRenderActionFlags *ioActionFlags, __unused const AudioTimeStamp *inTimeStamp, __unused UInt32 inBusNumber, __unused UInt32 inNumberFrames, AudioBufferList *ioData)
{
    TGOpusAudioRecorderContext *context = inRefCon;
    
    for (int i = 0; i < (int)ioData->mNumberBuffers; i++)
    {
        AudioBuffer *buffer = &ioData->mBuffers[i];
        buffer->mNumberChannels = 1;
        
        int audioBytesToCopy = MAX(0, MIN((int)buffer->mDataByteSize, ((int)toneAudioBuffer.length) - (int)context->toneOffset));
        if (audioBytesToCopy != 0) {
            memcpy(buffer->mData, toneAudioBuffer.bytes + (int)context->toneOffset, audioBytesToCopy);
            context->toneOffset += audioBytesToCopy;
        }
        
        int remainingBytes = ((int)buffer->mDataByteSize) - audioBytesToCopy;
        if (remainingBytes > 0) {
            memset(buffer->mData + buffer->mDataByteSize - remainingBytes, 0, remainingBytes);
        }
    }
    
    return noErr;
}

- (void)processWaveformPreview:(int16_t const *)samples count:(int)count {
    for (int i = 0; i < count; i++) {
        int32_t magnitude = samples[i];
        if (magnitude < 0)
            magnitude = -magnitude;
        int16_t sample = (int16_t)MIN(magnitude, INT16_MAX);
        
        if (_waveformPeak < sample) {
            _waveformPeak = sample;
        }
        _waveformPeakCount++;
        
        if (_waveformPeakCount >= 100) {
            [_waveformSamples appendBytes:&_waveformPeak length:2];
            _waveformPeak = 0;
            _waveformPeakCount = 0;
        }
        
        if (_micLevelPeak < sample) {
            _micLevelPeak = sample;
        }
        _micLevelPeakCount++;
        
        if (_micLevelPeakCount >= 1200) {
            if (_micLevel) {
                CGFloat level = (CGFloat)_micLevelPeak / 4000.0;
                _micLevel(level);
            }
            _micLevelPeak = 0;
            _micLevelPeakCount = 0;
        }
    }
}

- (void)_processBuffer:(AudioBuffer const *)buffer
{
    @autoreleasepool
    {
        if (_oggWriter == nil)
            return;
        
        static const int millisecondsPerPacket = 60;
        static const int encoderPacketSizeInBytes = TGOpusAudioRecorderSampleRate / 1000 * millisecondsPerPacket * 2;
        
        unsigned char currentEncoderPacket[encoderPacketSizeInBytes];
        
        int bufferOffset = 0;
        
        while (true)
        {
            int currentEncoderPacketSize = 0;
            
            while (currentEncoderPacketSize < encoderPacketSizeInBytes)
            {
                if (_audioBuffer.length != 0)
                {
                    int takenBytes = MIN((int)_audioBuffer.length, encoderPacketSizeInBytes - currentEncoderPacketSize);
                    if (takenBytes != 0)
                    {
                        memcpy(currentEncoderPacket + currentEncoderPacketSize, _audioBuffer.bytes, takenBytes);
                        [_audioBuffer replaceBytesInRange:NSMakeRange(0, takenBytes) withBytes:NULL length:0];
                        currentEncoderPacketSize += takenBytes;
                    }
                }
                else if (bufferOffset < (int)buffer->mDataByteSize)
                {
                    int takenBytes = MIN((int)buffer->mDataByteSize - bufferOffset, encoderPacketSizeInBytes - currentEncoderPacketSize);
                    if (takenBytes != 0)
                    {
                        memcpy(currentEncoderPacket + currentEncoderPacketSize, ((const char *)buffer->mData) + bufferOffset, takenBytes);
                        bufferOffset += takenBytes;
                        currentEncoderPacketSize += takenBytes;
                    }
                }
                else
                    break;
            }
            
            if (currentEncoderPacketSize < encoderPacketSizeInBytes)
            {
                if (_audioBuffer == nil)
                    _audioBuffer = [[NSMutableData alloc] initWithCapacity:encoderPacketSizeInBytes];
                [_audioBuffer appendBytes:currentEncoderPacket length:currentEncoderPacketSize];
                
                break;
            }
            else
            {
                NSUInteger previousBytesWritten = [_oggWriter encodedBytes];
                [self processWaveformPreview:(int16_t const *)currentEncoderPacket count:currentEncoderPacketSize / 2];
                if (![_oggWriter writeFrame:currentEncoderPacket frameByteCount:(NSUInteger)currentEncoderPacketSize])
                {
                    [self reportCaptureFailure];
                    return;
                }
                NSUInteger currentBytesWritten = [_oggWriter encodedBytes];
                if (currentBytesWritten != previousBytesWritten)
                {
                    [TGLiveUploadActor updateSize:currentBytesWritten forActorPath:_liveUploadPath];
                }
            }
        }
    }
}

- (TGDataItem *)stopRecording:(NSTimeInterval *)recordedDuration liveData:(__autoreleasing TGLiveUploadActorData **)liveData waveform:(__autoreleasing TGAudioWaveform **)waveform
{
    _stopped = true;
    __block TGDataItem *dataItemResult = nil;
    __block NSTimeInterval durationResult = 0.0;
    
    __block NSUInteger totalBytes = 0;
    
    [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
    {
        if (_recorderContext != NULL)
        {
            if (_recorderContext->audioUnitStarted)
            {
                OSStatus status = AudioOutputUnitStop(_recorderContext->audioUnit);
                if (status == noErr)
                    _recorderContext->audioUnitStarted = false;
                else
                    [self reportCaptureFailure];
            }
            TGPCMBufferStore(&_recorderContext->acceptingSamples, 0);
            [self drainCapturedPCM];
        }
        _recording = false;
        if (_oggWriter != nil && !_captureFailed && [_oggWriter writeFrame:_audioBuffer.mutableBytes frameByteCount:_audioBuffer.length])
        {
            if (_audioBuffer.length != 0)
                [self processWaveformPreview:_audioBuffer.bytes count:(int)(_audioBuffer.length / sizeof(int16_t))];
            [_audioBuffer setLength:0];
            dataItemResult = _tempFileItem;
            durationResult = [_oggWriter encodedDuration];
            totalBytes = [_oggWriter encodedBytes];
        }
        
        [self cleanup:false];
    } synchronous:true];
    
    int16_t scaledSamples[100];
    memset(scaledSamples, 0, 100 * 2);
    int16_t *samples = _waveformSamples.mutableBytes;
    int count = (int)_waveformSamples.length / 2;
    for (int i = 0; i < count; i++) {
        int16_t sample = samples[i];
        int index = i * 100 / count;
        if (scaledSamples[index] < sample) {
            scaledSamples[index] = sample;
        }
    }
    
    int16_t peak = 0;
    int64_t sumSamples = 0;
    for (int i = 0; i < 100; i++) {
        int16_t sample = scaledSamples[i];
        if (peak < sample) {
            peak = sample;
        }
        sumSamples += sample;
    }
    uint16_t calculatedPeak = 0;
    calculatedPeak = (uint16_t)(sumSamples * 1.8f / 100);
    
    if (calculatedPeak < 2500) {
        calculatedPeak = 2500;
    }
    
    for (int i = 0; i < 100; i++) {
        uint16_t sample = (uint16_t)scaledSamples[i];
        if (sample > calculatedPeak) {
            scaledSamples[i] = calculatedPeak;
        }
    }
    
    TGAudioWaveform *resultWaveform = [[TGAudioWaveform alloc] initWithSamples:[NSData dataWithBytes:scaledSamples length:100 * 2] peak:calculatedPeak];
    NSData *bitstream = [resultWaveform bitstream];
    resultWaveform = [[TGAudioWaveform alloc] initWithBitstream:bitstream bitsPerSample:5];
    
    if (recordedDuration != NULL)
        *recordedDuration = durationResult;
    
    if (waveform != NULL) {
        *waveform = resultWaveform;
    }
    
    if (liveData != NULL)
    {
        *liveData = [TGLiveUploadActor finishRestOfFile:totalBytes forActorPath:_liveUploadPath];
    }
    
    [[TGOpusAudioRecorder processingQueue] dispatchOnQueue:^
    {
        [self _endAudioSession];
    }];
    
    return dataItemResult;
}

- (NSTimeInterval)currentDuration
{
    return [_oggWriter encodedDuration];
}

@end
