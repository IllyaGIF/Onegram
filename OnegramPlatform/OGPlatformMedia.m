#import "OGPlatformMedia.h"
#import "OGPlatformVersion.h"
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <dispatch/dispatch.h>
#include <math.h>
#include <stdlib.h>

BOOL OGPlatformMediaDownloadsRequireUserAction(void)
{
#if defined(ONEGRAM_ARMV6)
    return YES;
#else
    return NO;
#endif
}

BOOL OGPlatformCameraAvailable(void)
{
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

BOOL OGPlatformVideoPlaybackAvailable(void)
{
    return OGPlatformClassAvailable(@"MPMoviePlayerController") || OGPlatformClassAvailable(@"AVPlayer");
}

BOOL OGPlatformAVPlayerAvailable(void)
{
    return OGPlatformClassAvailable(@"AVPlayer") && OGPlatformClassAvailable(@"AVPlayerItem");
}

BOOL OGPlatformAVCaptureAvailable(void)
{
    return OGPlatformClassAvailable(@"AVCaptureSession") && OGPlatformClassAvailable(@"AVCaptureDevice");
}

BOOL OGPlatformCoreImageAvailable(void)
{
    return OGPlatformClassAvailable(@"CIContext") && OGPlatformClassAvailable(@"CIImage");
}

BOOL OGPlatformCaptureConnectionIsVideoMirrored(id connection)
{
    SEL selector = NSSelectorFromString(@"isVideoMirrored");
    if (connection == nil || ![connection respondsToSelector:selector])
    {
        selector = NSSelectorFromString(@"videoMirrored");
        if (connection == nil || ![connection respondsToSelector:selector])
            return NO;
    }
    BOOL (*function)(id, SEL) = (BOOL (*)(id, SEL))[connection methodForSelector:selector];
    return function != NULL && function(connection, selector);
}

void OGPlatformSetCaptureConnectionVideoMirrored(id connection, BOOL mirrored)
{
    SEL selector = NSSelectorFromString(@"setVideoMirrored:");
    if (connection == nil || ![connection respondsToSelector:selector])
        return;
    void (*function)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[connection methodForSelector:selector];
    if (function != NULL)
        function(connection, selector, mirrored);
}

static UISlider *OGPlatformFindSlider(UIView *view)
{
    if ([view isKindOfClass:[UISlider class]])
        return (UISlider *)view;
    for (UIView *subview in view.subviews)
    {
        UISlider *slider = OGPlatformFindSlider(subview);
        if (slider != nil)
            return slider;
    }
    return nil;
}

void OGPlatformConfigureVolumeView(UIView *volumeView, UIImage *minimumTrackImage, UIImage *maximumTrackImage, UIImage *thumbImage, BOOL showsRouteButton)
{
    if (volumeView == nil)
        return;

    SEL minimumSelector = NSSelectorFromString(@"setMinimumVolumeSliderImage:forState:");
    SEL maximumSelector = NSSelectorFromString(@"setMaximumVolumeSliderImage:forState:");
    SEL thumbSelector = NSSelectorFromString(@"setVolumeThumbImage:forState:");
    SEL routeSelector = NSSelectorFromString(@"setShowsRouteButton:");
    void (*setImage)(id, SEL, UIImage *, UIControlState) = NULL;

    if ([volumeView respondsToSelector:minimumSelector])
    {
        setImage = (void (*)(id, SEL, UIImage *, UIControlState))[volumeView methodForSelector:minimumSelector];
        if (setImage != NULL)
            setImage(volumeView, minimumSelector, minimumTrackImage, UIControlStateNormal);
    }
    if ([volumeView respondsToSelector:maximumSelector])
    {
        setImage = (void (*)(id, SEL, UIImage *, UIControlState))[volumeView methodForSelector:maximumSelector];
        if (setImage != NULL)
            setImage(volumeView, maximumSelector, maximumTrackImage, UIControlStateNormal);
    }
    if ([volumeView respondsToSelector:thumbSelector])
    {
        setImage = (void (*)(id, SEL, UIImage *, UIControlState))[volumeView methodForSelector:thumbSelector];
        if (setImage != NULL)
            setImage(volumeView, thumbSelector, thumbImage, UIControlStateNormal);
    }
    if ([volumeView respondsToSelector:routeSelector])
    {
        void (*setRouteButton)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[volumeView methodForSelector:routeSelector];
        if (setRouteButton != NULL)
            setRouteButton(volumeView, routeSelector, showsRouteButton);
    }

    UISlider *slider = OGPlatformFindSlider(volumeView);
    if (slider != nil)
    {
        [slider setMinimumTrackImage:minimumTrackImage forState:UIControlStateNormal];
        [slider setMaximumTrackImage:maximumTrackImage forState:UIControlStateNormal];
        [slider setThumbImage:thumbImage forState:UIControlStateNormal];
    }

    if (![volumeView respondsToSelector:routeSelector] && !showsRouteButton)
    {
        for (UIView *subview in volumeView.subviews)
        {
            if ([subview isKindOfClass:[UIButton class]])
                subview.hidden = YES;
        }
    }
}


static UIImage *OGPlatformScaleVideoThumbnail(UIImage *image, CGSize maximumSize)
{
    if (image == nil || maximumSize.width <= 0.0f || maximumSize.height <= 0.0f)
        return image;

    CGSize sourceSize = image.size;
    if (sourceSize.width <= maximumSize.width && sourceSize.height <= maximumSize.height)
        return image;

    CGFloat scale = MIN(maximumSize.width / sourceSize.width, maximumSize.height / sourceSize.height);
    CGSize targetSize = CGSizeMake(MAX(1.0f, floor(sourceSize.width * scale)), MAX(1.0f, floor(sourceSize.height * scale)));
    UIGraphicsBeginImageContext(targetSize);
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

UIImage *OGPlatformVideoThumbnailAtURL(NSURL *url, NSTimeInterval time, CGSize maximumSize)
{
    if (url == nil)
        return nil;

    Class playerClass = NSClassFromString(@"MPMoviePlayerController");
    SEL selector = NSSelectorFromString(@"thumbnailImageAtTime:timeOption:");
    if (playerClass == Nil || ![playerClass instancesRespondToSelector:selector])
        return nil;

    if (![NSThread isMainThread])
    {
        __block UIImage *image = nil;
        dispatch_sync(dispatch_get_main_queue(), ^
        {
            @autoreleasepool
            {
                image = OGPlatformVideoThumbnailAtURL(url, time, maximumSize);
            }
        });
        return image;
    }

    id player = [[playerClass alloc] initWithContentURL:url];
    if (player == nil)
        return nil;

    UIImage *image = nil;
    if ([player respondsToSelector:selector])
    {
        UIImage *(*function)(id, SEL, NSTimeInterval, NSInteger) = (UIImage *(*)(id, SEL, NSTimeInterval, NSInteger))[player methodForSelector:selector];
        if (function != NULL)
            image = function(player, selector, MAX(0.0, time), 0);
    }

    SEL stopSelector = NSSelectorFromString(@"stop");
    if ([player respondsToSelector:stopSelector])
    {
        void (*stopFunction)(id, SEL) = (void (*)(id, SEL))[player methodForSelector:stopSelector];
        if (stopFunction != NULL)
            stopFunction(player, stopSelector);
    }

    return OGPlatformScaleVideoThumbnail(image, maximumSize);
}


static uint32_t OGPlatformReadBE32(const uint8_t *bytes)
{
    return ((uint32_t)bytes[0] << 24) | ((uint32_t)bytes[1] << 16) | ((uint32_t)bytes[2] << 8) | (uint32_t)bytes[3];
}

static uint64_t OGPlatformReadBE64(const uint8_t *bytes)
{
    return ((uint64_t)OGPlatformReadBE32(bytes) << 32) | OGPlatformReadBE32(bytes + 4);
}

static int32_t OGPlatformReadBEFixed16(const uint8_t *bytes)
{
    return (int32_t)OGPlatformReadBE32(bytes);
}

static BOOL OGPlatformAtomRange(NSData *data, NSUInteger offset, NSUInteger limit, uint32_t *type, NSUInteger *payloadOffset, NSUInteger *payloadLength, NSUInteger *nextOffset)
{
    if (offset > limit || limit - offset < 8)
        return NO;

    const uint8_t *bytes = (const uint8_t *)[data bytes];
    uint64_t atomSize = OGPlatformReadBE32(bytes + offset);
    uint32_t atomType = OGPlatformReadBE32(bytes + offset + 4);
    NSUInteger headerSize = 8;

    if (atomSize == 1)
    {
        if (limit - offset < 16)
            return NO;
        atomSize = OGPlatformReadBE64(bytes + offset + 8);
        headerSize = 16;
    }
    else if (atomSize == 0)
    {
        atomSize = limit - offset;
    }

    if (atomSize < headerSize || atomSize > limit - offset)
        return NO;

    if (type != NULL)
        *type = atomType;
    if (payloadOffset != NULL)
        *payloadOffset = offset + headerSize;
    if (payloadLength != NULL)
        *payloadLength = (NSUInteger)atomSize - headerSize;
    if (nextOffset != NULL)
        *nextOffset = offset + (NSUInteger)atomSize;
    return YES;
}

static BOOL OGPlatformFindChildAtom(NSData *data, NSUInteger offset, NSUInteger length, uint32_t wantedType, NSUInteger *payloadOffset, NSUInteger *payloadLength)
{
    NSUInteger limit = offset + length;
    NSUInteger cursor = offset;
    while (cursor < limit)
    {
        uint32_t type = 0;
        NSUInteger childOffset = 0;
        NSUInteger childLength = 0;
        NSUInteger next = 0;
        if (!OGPlatformAtomRange(data, cursor, limit, &type, &childOffset, &childLength, &next))
            return NO;
        if (type == wantedType)
        {
            if (payloadOffset != NULL)
                *payloadOffset = childOffset;
            if (payloadLength != NULL)
                *payloadLength = childLength;
            return YES;
        }
        if (next <= cursor)
            return NO;
        cursor = next;
    }
    return NO;
}

static BOOL OGPlatformMovieHeader(NSData *moovData, NSTimeInterval *duration)
{
    NSUInteger offset = 0;
    NSUInteger length = 0;
    if (!OGPlatformFindChildAtom(moovData, 0, [moovData length], 0x6d766864, &offset, &length) || length < 20)
        return NO;

    const uint8_t *bytes = (const uint8_t *)[moovData bytes] + offset;
    uint8_t version = bytes[0];
    uint32_t timescale = 0;
    uint64_t rawDuration = 0;
    if (version == 1)
    {
        if (length < 32)
            return NO;
        timescale = OGPlatformReadBE32(bytes + 20);
        rawDuration = OGPlatformReadBE64(bytes + 24);
    }
    else
    {
        timescale = OGPlatformReadBE32(bytes + 12);
        rawDuration = OGPlatformReadBE32(bytes + 16);
    }

    if (timescale == 0)
        return NO;
    if (duration != NULL)
        *duration = (NSTimeInterval)((double)rawDuration / (double)timescale);
    return YES;
}

static BOOL OGPlatformTrackIsVideo(NSData *moovData, NSUInteger trakOffset, NSUInteger trakLength)
{
    NSUInteger mdiaOffset = 0;
    NSUInteger mdiaLength = 0;
    if (!OGPlatformFindChildAtom(moovData, trakOffset, trakLength, 0x6d646961, &mdiaOffset, &mdiaLength))
        return NO;

    NSUInteger hdlrOffset = 0;
    NSUInteger hdlrLength = 0;
    if (!OGPlatformFindChildAtom(moovData, mdiaOffset, mdiaLength, 0x68646c72, &hdlrOffset, &hdlrLength) || hdlrLength < 12)
        return NO;

    const uint8_t *bytes = (const uint8_t *)[moovData bytes] + hdlrOffset;
    return OGPlatformReadBE32(bytes + 8) == 0x76696465;
}

static BOOL OGPlatformVideoTrackSize(NSData *moovData, CGSize *dimensions)
{
    NSUInteger limit = [moovData length];
    NSUInteger cursor = 0;
    while (cursor < limit)
    {
        uint32_t type = 0;
        NSUInteger payloadOffset = 0;
        NSUInteger payloadLength = 0;
        NSUInteger next = 0;
        if (!OGPlatformAtomRange(moovData, cursor, limit, &type, &payloadOffset, &payloadLength, &next))
            return NO;

        if (type == 0x7472616b && OGPlatformTrackIsVideo(moovData, payloadOffset, payloadLength))
        {
            NSUInteger tkhdOffset = 0;
            NSUInteger tkhdLength = 0;
            if (!OGPlatformFindChildAtom(moovData, payloadOffset, payloadLength, 0x746b6864, &tkhdOffset, &tkhdLength) || tkhdLength < 84)
                return NO;

            const uint8_t *bytes = (const uint8_t *)[moovData bytes] + tkhdOffset;
            uint8_t version = bytes[0];
            NSUInteger matrixOffset = version == 1 ? 52 : 40;
            NSUInteger sizeOffset = version == 1 ? 88 : 76;
            if (tkhdLength < sizeOffset + 8 || tkhdLength < matrixOffset + 20)
                return NO;

            CGFloat width = (CGFloat)OGPlatformReadBE32(bytes + sizeOffset) / 65536.0f;
            CGFloat height = (CGFloat)OGPlatformReadBE32(bytes + sizeOffset + 4) / 65536.0f;
            int32_t a = OGPlatformReadBEFixed16(bytes + matrixOffset);
            int32_t b = OGPlatformReadBEFixed16(bytes + matrixOffset + 4);
            int32_t c = OGPlatformReadBEFixed16(bytes + matrixOffset + 12);
            int32_t d = OGPlatformReadBEFixed16(bytes + matrixOffset + 16);
            int64_t diagonal = llabs((long long)a) + llabs((long long)d);
            int64_t offDiagonal = llabs((long long)b) + llabs((long long)c);
            if (offDiagonal > diagonal)
            {
                CGFloat temporary = width;
                width = height;
                height = temporary;
            }

            if (width <= 0.0f || height <= 0.0f)
                return NO;
            if (dimensions != NULL)
                *dimensions = CGSizeMake(width, height);
            return YES;
        }

        if (next <= cursor)
            return NO;
        cursor = next;
    }
    return NO;
}

static NSData *OGPlatformMovieAtomAtPath(NSString *path)
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (handle == nil)
        return nil;

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    uint64_t fileSize = [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
    uint64_t offset = 0;
    while (offset + 8 <= fileSize)
    {
        [handle seekToFileOffset:offset];
        NSData *header = [handle readDataOfLength:16];
        if ([header length] < 8)
            break;
        const uint8_t *bytes = (const uint8_t *)[header bytes];
        uint64_t atomSize = OGPlatformReadBE32(bytes);
        uint32_t atomType = OGPlatformReadBE32(bytes + 4);
        uint64_t headerSize = 8;
        if (atomSize == 1)
        {
            if ([header length] < 16)
                break;
            atomSize = OGPlatformReadBE64(bytes + 8);
            headerSize = 16;
        }
        else if (atomSize == 0)
        {
            atomSize = fileSize - offset;
        }

        if (atomSize < headerSize || atomSize > fileSize - offset)
            break;
        if (atomType == 0x6d6f6f76)
        {
            uint64_t payloadSize = atomSize - headerSize;
            if (payloadSize > (uint64_t)((NSUInteger)-1))
                return nil;
            [handle seekToFileOffset:offset + headerSize];
            return [handle readDataOfLength:(NSUInteger)payloadSize];
        }
        offset += atomSize;
    }
    return nil;
}

BOOL OGPlatformReadVideoMetadataAtURL(NSURL *url, NSTimeInterval *duration, CGSize *dimensions)
{
    if (duration != NULL)
        *duration = 0.0;
    if (dimensions != NULL)
        *dimensions = CGSizeZero;
    if (url == nil || ![[url scheme] isEqualToString:@"file"])
        return NO;

    NSData *moovData = OGPlatformMovieAtomAtPath([url path]);
    if (moovData == nil)
        return NO;

    NSTimeInterval parsedDuration = 0.0;
    CGSize parsedDimensions = CGSizeZero;
    BOOL hasDuration = OGPlatformMovieHeader(moovData, &parsedDuration);
    BOOL hasDimensions = OGPlatformVideoTrackSize(moovData, &parsedDimensions);
    if (duration != NULL && hasDuration)
        *duration = parsedDuration;
    if (dimensions != NULL && hasDimensions)
        *dimensions = parsedDimensions;
    return hasDuration && hasDimensions;
}

@interface OGPlatformMoviePlayer ()
{
    id _player;
    NSURL *_url;
    UIView *_view;
    NSTimeInterval _metadataDuration;
    NSTimeInterval _trackedPosition;
    CFAbsoluteTime _playStartedAt;
    BOOL _playing;
}
@end

@implementation OGPlatformMoviePlayer

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
        _url = [url copy];
        OGPlatformReadVideoMetadataAtURL(url, &_metadataDuration, NULL);
        Class playerClass = NSClassFromString(@"MPMoviePlayerController");
        if (playerClass != Nil)
            _player = [[playerClass alloc] initWithContentURL:url];
        if (_player == nil)
            return nil;

        SEL viewSelector = NSSelectorFromString(@"view");
        if ([_player respondsToSelector:viewSelector])
        {
            id (*viewFunction)(id, SEL) = (id (*)(id, SEL))[_player methodForSelector:viewSelector];
            if (viewFunction != NULL)
                _view = viewFunction(_player, viewSelector);
        }

        if (_view != nil)
        {
            SEL controlStyleSelector = NSSelectorFromString(@"setControlStyle:");
            if ([_player respondsToSelector:controlStyleSelector])
            {
                void (*controlStyleFunction)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))[_player methodForSelector:controlStyleSelector];
                if (controlStyleFunction != NULL)
                    controlStyleFunction(_player, controlStyleSelector, 0);
            }

            SEL scalingSelector = NSSelectorFromString(@"setScalingMode:");
            if ([_player respondsToSelector:scalingSelector])
            {
                void (*scalingFunction)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))[_player methodForSelector:scalingSelector];
                if (scalingFunction != NULL)
                    scalingFunction(_player, scalingSelector, 2);
            }
        }

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_playbackDidFinish:) name:@"MPMoviePlayerPlaybackDidFinishNotification" object:_player];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stop];
}

- (UIView *)view
{
    return _view;
}

- (BOOL)supportsInlinePlayback
{
    return _view != nil;
}

- (BOOL)supportsSeeking
{
    return _player != nil && [_player respondsToSelector:NSSelectorFromString(@"setCurrentPlaybackTime:")];
}

- (NSTimeInterval)duration
{
    if (_player != nil)
    {
        SEL selector = NSSelectorFromString(@"duration");
        if ([_player respondsToSelector:selector])
        {
            NSTimeInterval (*function)(id, SEL) = (NSTimeInterval (*)(id, SEL))[_player methodForSelector:selector];
            if (function != NULL)
            {
                NSTimeInterval value = function(_player, selector);
                if (value > 0.0)
                    return value;
            }
        }
    }
    return _metadataDuration;
}

- (NSTimeInterval)currentTime
{
    if (_player != nil)
    {
        SEL selector = NSSelectorFromString(@"currentPlaybackTime");
        if ([_player respondsToSelector:selector])
        {
            NSTimeInterval (*function)(id, SEL) = (NSTimeInterval (*)(id, SEL))[_player methodForSelector:selector];
            if (function != NULL)
            {
                NSTimeInterval value = function(_player, selector);
                if (value >= 0.0)
                    return value;
            }
        }
    }

    NSTimeInterval value = _trackedPosition;
    if (_playing)
        value += CFAbsoluteTimeGetCurrent() - _playStartedAt;
    NSTimeInterval duration = self.duration;
    if (duration > 0.0)
        value = MIN(value, duration);
    return MAX(0.0, value);
}

- (BOOL)isPlaying
{
    return _playing;
}

- (void)play
{
    if (_player == nil)
        return;

    SEL pauseSelector = NSSelectorFromString(@"pause");
    if (![_player respondsToSelector:pauseSelector] && _trackedPosition > 0.0)
        _trackedPosition = 0.0;

    [_player play];
    _playStartedAt = CFAbsoluteTimeGetCurrent();
    _playing = YES;
}

- (void)pause
{
    if (_player == nil)
        return;

    _trackedPosition = self.currentTime;
    SEL selector = NSSelectorFromString(@"pause");
    if ([_player respondsToSelector:selector])
    {
        void (*function)(id, SEL) = (void (*)(id, SEL))[_player methodForSelector:selector];
        if (function != NULL)
            function(_player, selector);
    }
    else
    {
        [_player stop];
    }
    _playing = NO;
}

- (void)stop
{
    if (_player != nil)
        [_player stop];
    _playing = NO;
    _trackedPosition = 0.0;
}

- (BOOL)seekToTime:(NSTimeInterval)time
{
    if (_player == nil)
        return NO;

    time = MAX(0.0, time);
    SEL selector = NSSelectorFromString(@"setCurrentPlaybackTime:");
    if ([_player respondsToSelector:selector])
    {
        void (*function)(id, SEL, NSTimeInterval) = (void (*)(id, SEL, NSTimeInterval))[_player methodForSelector:selector];
        if (function != NULL)
        {
            function(_player, selector, time);
            _trackedPosition = time;
            _playStartedAt = CFAbsoluteTimeGetCurrent();
            return YES;
        }
    }

    if (time <= 0.01)
    {
        BOOL wasPlaying = _playing;
        [_player stop];
        _playing = NO;
        _trackedPosition = 0.0;
        if (wasPlaying)
            [self play];
        return YES;
    }
    return NO;
}

- (void)_playbackDidFinish:(NSNotification *)notification
{
    if ([notification object] != _player)
        return;

    _playing = NO;
    NSTimeInterval duration = self.duration;
    _trackedPosition = duration > 0.0 ? duration : 0.0;
    void (^completion)(void) = self.playbackFinished;
    if (completion != nil)
        completion();
}

@end
