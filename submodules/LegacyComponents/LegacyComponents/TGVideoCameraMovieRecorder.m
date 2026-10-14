#import "TGVideoCameraMovieRecorder.h"
#import <AVFoundation/AVFoundation.h>

typedef enum {
	TGMovieRecorderStatusIdle = 0,
	TGMovieRecorderStatusPreparingToRecord,
	TGMovieRecorderStatusRecording,
	TGMovieRecorderStatusFinishingWaiting,
	TGMovieRecorderStatusFinishingCommiting,
	TGMovieRecorderStatusFinished,
	TGMovieRecorderStatusFailed
} TGMovieRecorderStatus;


@interface TGVideoCameraMovieRecorder ()
{
	TGMovieRecorderStatus _status;
	
	dispatch_queue_t _writingQueue;
	
	NSURL *_url;
	
	AVAssetWriter *_assetWriter;
	bool _haveStartedSession;
	
	CMFormatDescriptionRef _audioTrackSourceFormatDescription;
	NSDictionary *_audioTrackSettings;
	AVAssetWriterInput *_audioInput;
	
	CMFormatDescriptionRef _videoTrackSourceFormatDescription;
	CGAffineTransform _videoTrackTransform;
	NSDictionary *_videoTrackSettings;
	AVAssetWriterInput *_videoInput;

	__weak id<TGVideoCameraMovieRecorderDelegate> _delegate;
	dispatch_queue_t _delegateCallbackQueue;
    
    CMTime _startTimeStamp;
    CMTime _lastAudioTimeStamp;
    
    CMTime _timeOffset;
    
    bool _wasPaused;
    NSUInteger _pendingVideoBufferCount;
    NSUInteger _pendingAudioBufferCount;
}
@end


@implementation TGVideoCameraMovieRecorder

- (instancetype)initWithURL:(NSURL *)URL delegate:(id<TGVideoCameraMovieRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)queue
{
	self = [super init];
	if (self != nil)
	{
		_writingQueue = dispatch_queue_create("org.telegram.movierecorder.writing", DISPATCH_QUEUE_SERIAL);
		_videoTrackTransform = CGAffineTransformIdentity;
		_url = URL;
		_delegate = delegate;
		_delegateCallbackQueue = queue;
#if !OS_OBJECT_USE_OBJC
        dispatch_retain(_delegateCallbackQueue);
#endif
	}
	return self;
}

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings
{
	if (formatDescription == NULL)
		return;
	
	@synchronized (self)
	{
		if (_status != TGMovieRecorderStatusIdle)
			return;
		
		if (_videoTrackSourceFormatDescription)
			return;
		
		_videoTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
		_videoTrackTransform = transform;
		_videoTrackSettings = [videoSettings copy];
	}
}

- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings
{
	if (formatDescription == NULL)
		return;

	@synchronized (self)
	{
		if (_status != TGMovieRecorderStatusIdle)
			return;
		
		if (_audioTrackSourceFormatDescription)
			return;
		
		_audioTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
		_audioTrackSettings = [audioSettings copy];
	}
}

- (void)prepareToRecord
{
	@synchronized( self )
	{
		if (_status != TGMovieRecorderStatusIdle)
			return;
		
		[self transitionToStatus:TGMovieRecorderStatusPreparingToRecord error:nil];
	}
	
	dispatch_async(_writingQueue, ^
    {
		@autoreleasepool
		{
			NSError *error = nil;
    
			[[NSFileManager defaultManager] removeItemAtURL:_url error:NULL];
			
			_assetWriter = [[AVAssetWriter alloc] initWithURL:_url fileType:AVFileTypeMPEG4 error:&error];
			
            bool succeed = false;
			if (error == nil && _videoTrackSourceFormatDescription)
            {
				succeed = [self setupAssetWriterVideoInputWithSourceFormatDescription:_videoTrackSourceFormatDescription transform:_videoTrackTransform settings:_videoTrackSettings];
			}
			
			if (error == nil && succeed && _audioTrackSourceFormatDescription)
            {
				succeed = [self setupAssetWriterAudioInputWithSourceFormatDescription:_audioTrackSourceFormatDescription settings:_audioTrackSettings];
			}
			
			if (error == nil && succeed)
            {
				if (![_assetWriter startWriting])
					error = _assetWriter.error ?: [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:nil];
			}
			
			@synchronized (self)
			{
				if (error || !succeed)
					[self transitionToStatus:TGMovieRecorderStatusFailed error:error ?: [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:@{NSLocalizedFailureReasonErrorKey: @"The capture encoder rejected its output settings."}]];
				else
					[self transitionToStatus:TGMovieRecorderStatusRecording error:nil];
			}
		}
	} );
}

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime
{
	CMSampleBufferRef sampleBuffer = NULL;
	
    CMSampleTimingInfo timingInfo;
	timingInfo.duration = kCMTimeInvalid;
	timingInfo.decodeTimeStamp = kCMTimeInvalid;
	timingInfo.presentationTimeStamp = presentationTime;
	
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, _videoTrackSourceFormatDescription, &timingInfo, &sampleBuffer);
        
	if (sampleBuffer)
    {
		[self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
        CFRelease(sampleBuffer);
    }
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	[self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeAudio];
}

- (void)finishRecording
{
	@synchronized (self)
	{
		bool shouldFinishRecording = false;
		switch (_status)
		{
			case TGMovieRecorderStatusIdle:
			case TGMovieRecorderStatusPreparingToRecord:
			case TGMovieRecorderStatusFinishingWaiting:
			case TGMovieRecorderStatusFinishingCommiting:
			case TGMovieRecorderStatusFinished:
			case TGMovieRecorderStatusFailed:
				break;
                
			case TGMovieRecorderStatusRecording:
				shouldFinishRecording = true;
				break;
		}
		
		if (shouldFinishRecording)
			[self transitionToStatus:TGMovieRecorderStatusFinishingWaiting error:nil];
		else
			return;
	}
	
	dispatch_async(_writingQueue, ^
    {
		@autoreleasepool
		{
			@synchronized (self)
			{
				if (_status != TGMovieRecorderStatusFinishingWaiting)
					return;
				
				[self transitionToStatus:TGMovieRecorderStatusFinishingCommiting error:nil];
			}

			void (^finishCompletion)(void) = ^
            {
				@synchronized (self)
				{
					NSError *error = _assetWriter.error;
					if (error)
						[self transitionToStatus:TGMovieRecorderStatusFailed error:error];
					else
						[self transitionToStatus:TGMovieRecorderStatusFinished error:nil];
				}
			};

            if ([_assetWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)])
                [_assetWriter finishWritingWithCompletionHandler:finishCompletion];
            else
            {
                [_assetWriter finishWriting];
                finishCompletion();
            }
		}
	} );
}

- (void)dealloc
{    
#if !OS_OBJECT_USE_OBJC
    dispatch_release(_writingQueue);
    dispatch_release(_delegateCallbackQueue);
#endif
	if (_audioTrackSourceFormatDescription)
		CFRelease(_audioTrackSourceFormatDescription);
	
	if (_videoTrackSourceFormatDescription)
		CFRelease(_videoTrackSourceFormatDescription);
}

- (void)setPaused:(bool)paused
{
    @synchronized (self)
    {
        _paused = paused;
        if (_paused)
            _wasPaused = true;
    }
    if (paused)
        dispatch_sync(_writingQueue, ^{});
}

- (CMSampleBufferRef)adjustTimeOfSample:(CMSampleBufferRef)sample byOffset:(CMTime)offset
{
    CMItemCount count = 0;
    if (CMSampleBufferGetSampleTimingInfoArray(sample, 0, NULL, &count) != noErr || count <= 0)
        return NULL;
    CMSampleTimingInfo *timings = malloc(sizeof(CMSampleTimingInfo) * count);
    if (timings == NULL)
        return NULL;
    OSStatus result = CMSampleBufferGetSampleTimingInfoArray(sample, count, timings, &count);
    if (result == noErr)
    {
        for (CMItemCount i = 0; i < count; i++)
        {
            timings[i].decodeTimeStamp = CMTimeSubtract(timings[i].decodeTimeStamp, offset);
            timings[i].presentationTimeStamp = CMTimeSubtract(timings[i].presentationTimeStamp, offset);
        }
    }
    CMSampleBufferRef adjusted = NULL;
    if (result == noErr)
        CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sample, count, timings, &adjusted);
    free(timings);
    return adjusted;
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(NSString *)mediaType
{
    if (sampleBuffer == NULL)
        return;
    bool video = [mediaType isEqualToString:AVMediaTypeVideo];
    @synchronized (self)
    {
        if (_status != TGMovieRecorderStatusRecording || _paused || (!video && !_haveStartedSession))
            return;
        if (video)
        {
            if (_pendingVideoBufferCount >= 4)
                return;
            _pendingVideoBufferCount++;
        }
        else
        {
            if (_pendingAudioBufferCount >= 64)
            {
                [self transitionToStatus:TGMovieRecorderStatusFailed error:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorOutOfMemory userInfo:nil]];
                return;
            }
            _pendingAudioBufferCount++;
        }
        CFRetain(sampleBuffer);
        dispatch_async(_writingQueue, ^
        {
            @autoreleasepool
            {
                CMSampleBufferRef buffer = sampleBuffer;
                @try
                {
                    @synchronized (self)
                    {
                        if (_status > TGMovieRecorderStatusFinishingWaiting || _paused)
                            return;
                        if (_wasPaused)
                        {
                            if (video)
                                return;
                            CMTime pts = CMSampleBufferGetPresentationTimeStamp(buffer);
                            if (_lastAudioTimeStamp.flags & kCMTimeFlags_Valid)
                            {
                                CMTime previousTimestamp = _timeOffset.flags & kCMTimeFlags_Valid ? CMTimeAdd(_lastAudioTimeStamp, _timeOffset) : _lastAudioTimeStamp;
                                CMTime gap = CMTimeSubtract(pts, previousTimestamp);
                                if (CMTimeGetSeconds(gap) > 0.0)
                                    _timeOffset = _timeOffset.flags & kCMTimeFlags_Valid ? CMTimeAdd(_timeOffset, gap) : gap;
                            }
                            _wasPaused = false;
                        }
                    }
                    if (_timeOffset.flags & kCMTimeFlags_Valid)
                    {
                        CMSampleBufferRef adjusted = [self adjustTimeOfSample:buffer byOffset:_timeOffset];
                        if (adjusted == NULL)
                        {
                            @synchronized (self)
                            {
                                [self transitionToStatus:TGMovieRecorderStatusFailed error:[NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorInvalidSourceMedia userInfo:nil]];
                            }
                            return;
                        }
                        CFRelease(buffer);
                        buffer = adjusted;
                    }
                    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(buffer);
                    if (!_haveStartedSession)
                    {
                        [_assetWriter startSessionAtSourceTime:timestamp];
                        @synchronized (self)
                        {
                            _startTimeStamp = timestamp;
                            _haveStartedSession = true;
                        }
                    }
                    AVAssetWriterInput *input = video ? _videoInput : _audioInput;
                    if (input.readyForMoreMediaData)
                    {
                        if (![input appendSampleBuffer:buffer])
                        {
                            @synchronized (self)
                            {
                                [self transitionToStatus:TGMovieRecorderStatusFailed error:_assetWriter.error ?: [NSError errorWithDomain:AVFoundationErrorDomain code:AVErrorUnknown userInfo:nil]];
                            }
                        }
                        else if (!video)
                        {
                            CMTime duration = CMSampleBufferGetDuration(buffer);
                            @synchronized (self)
                            {
                                _lastAudioTimeStamp = duration.value > 0 ? CMTimeAdd(timestamp, duration) : timestamp;
                            }
                        }
                    }
                }
                @finally
                {
                    CFRelease(buffer);
                    @synchronized (self)
                    {
                        if (video)
                            _pendingVideoBufferCount--;
                        else
                            _pendingAudioBufferCount--;
                    }
                }
            }
        });
    }
}

- (void)transitionToStatus:(TGMovieRecorderStatus)newStatus error:(NSError *)error
{
	bool shouldNotifyDelegate = false;
	
	if (newStatus != _status)
	{
		if ((newStatus == TGMovieRecorderStatusFinished) || (newStatus == TGMovieRecorderStatusFailed))
		{
			shouldNotifyDelegate = true;
			
			dispatch_async(_writingQueue, ^
            {
				[self teardownAssetWriterAndInputs];
				if (newStatus == TGMovieRecorderStatusFailed)
                {
					[[NSFileManager defaultManager] removeItemAtURL:_url error:NULL];
				}
			});
		}
		else if (newStatus == TGMovieRecorderStatusRecording)
		{
			shouldNotifyDelegate = true;
		}
		
		_status = newStatus;
	}

	if (shouldNotifyDelegate)
	{
		dispatch_async(_delegateCallbackQueue, ^
        {
			@autoreleasepool
			{
				switch ( newStatus )
				{
					case TGMovieRecorderStatusRecording:
						[_delegate movieRecorderDidFinishPreparing:self];
						break;
                        
					case TGMovieRecorderStatusFinished:
						[_delegate movieRecorderDidFinishRecording:self];
						break;
                        
					case TGMovieRecorderStatusFailed:
						[_delegate movieRecorder:self didFailWithError:error];
						break;
                        
					default:
						break;
				}
			}
		});
	}
}

- (bool)setupAssetWriterAudioInputWithSourceFormatDescription:(CMFormatDescriptionRef)audioFormatDescription settings:(NSDictionary *)audioSettings
{
	if ([_assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio])
	{
        if ([AVAssetWriterInput instancesRespondToSelector:@selector(initWithMediaType:outputSettings:sourceFormatHint:)])
            _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings sourceFormatHint:audioFormatDescription];
        else
            _audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
		_audioInput.expectsMediaDataInRealTime = true;
		
		if ([_assetWriter canAddInput:_audioInput])
		{
			[_assetWriter addInput:_audioInput];
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
	
	return true;
}

- (bool)setupAssetWriterVideoInputWithSourceFormatDescription:(CMFormatDescriptionRef)videoFormatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings
{
	if ([_assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo])
	{
        if ([AVAssetWriterInput instancesRespondToSelector:@selector(initWithMediaType:outputSettings:sourceFormatHint:)])
            _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings sourceFormatHint:videoFormatDescription];
        else
            _videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
		_videoInput.expectsMediaDataInRealTime = true;
		_videoInput.transform = transform;
		
		if ([_assetWriter canAddInput:_videoInput])
		{
			[_assetWriter addInput:_videoInput];
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
	
	return true;
}

- (void)teardownAssetWriterAndInputs
{
	_videoInput = nil;
	_audioInput = nil;
	_assetWriter = nil;
}

- (NSTimeInterval)videoDuration
{
    @synchronized (self)
    {
        if (!_haveStartedSession || !(_lastAudioTimeStamp.flags & kCMTimeFlags_Valid))
            return 0.0;
        return MAX(0.0, CMTimeGetSeconds(CMTimeSubtract(_lastAudioTimeStamp, _startTimeStamp)));
    }
}

@end
