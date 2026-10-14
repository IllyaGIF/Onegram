#import "TGCameraCapturedVideo.h"
#import <AVFoundation/AVFoundation.h>
#import "TGMediaAssetImageSignals.h"
#import "TGPhotoEditorUtils.h"
#import "../../../OnegramPlatform/OGPlatformMedia.h"

@interface TGCameraCapturedVideo ()
{
    CGSize _cachedSize;
    NSTimeInterval _cachedDuration;
#if defined(ONEGRAM_ARMV6)
    NSURL *_legacyURL;
#endif
}
@end

@implementation TGCameraCapturedVideo

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
#if defined(ONEGRAM_ARMV6)
        _legacyURL = url;
#else
        _avAsset = [[AVURLAsset alloc] initWithURL:url options:nil];
#endif
        _cachedSize = CGSizeZero;
        _cachedDuration = 0.0;
    }
    return self;
}

- (void)_cleanUp
{
#if defined(ONEGRAM_ARMV6)
    [[NSFileManager defaultManager] removeItemAtPath:_legacyURL.path error:nil];
#else
    [[NSFileManager defaultManager] removeItemAtPath:_avAsset.URL.path error:nil];
#endif
}

- (bool)isVideo
{
    return true;
}

- (NSString *)uniqueIdentifier
{
#if defined(ONEGRAM_ARMV6)
    return _legacyURL.absoluteString;
#else
    return _avAsset.URL.absoluteString;
#endif
}

- (CGSize)originalSize
{
    if (!CGSizeEqualToSize(_cachedSize, CGSizeZero))
        return _cachedSize;
    
#if defined(ONEGRAM_ARMV6)
    OGPlatformReadVideoMetadataAtURL(_legacyURL, &_cachedDuration, &_cachedSize);
#else
    AVAssetTrack *track = _avAsset.tracks.firstObject;
    _cachedSize = CGRectApplyAffineTransform((CGRect){ CGPointZero, track.naturalSize }, track.preferredTransform).size;
#endif
    return _cachedSize;
}

- (NSTimeInterval)videoDuration
{
    return [self originalDuration];
}

- (NSTimeInterval)originalDuration
{
    if (_cachedDuration > DBL_EPSILON)
        return _cachedDuration;
    
#if defined(ONEGRAM_ARMV6)
    OGPlatformReadVideoMetadataAtURL(_legacyURL, &_cachedDuration, &_cachedSize);
#else
    _cachedDuration = CMTimeGetSeconds(_avAsset.duration);
#endif
    return _cachedDuration;
}

- (SSignal *)thumbnailImageSignal
{
    CGFloat thumbnailImageSide = TGPhotoEditorScreenImageMaxSize().width;
    CGSize size = TGScaleToSize(self.originalSize, CGSizeMake(thumbnailImageSide, thumbnailImageSide));
    
#if defined(ONEGRAM_ARMV6)
    return [SSignal single:OGPlatformVideoThumbnailAtURL(_legacyURL, 0.0, size)];
#else
    return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_avAsset size:size timestamp:kCMTimeZero];
#endif
}

- (SSignal *)screenImageSignal:(NSTimeInterval)__unused position
{
    CGFloat imageSide = 1280.0f;
    CGSize size = TGScaleToSize(self.originalSize, CGSizeMake(imageSide, imageSide));
    
#if defined(ONEGRAM_ARMV6)
    return [SSignal single:OGPlatformVideoThumbnailAtURL(_legacyURL, position, size)];
#else
    return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_avAsset size:size timestamp:kCMTimeZero];
#endif
}

- (SSignal *)originalImageSignal:(NSTimeInterval)position
{
#if defined(ONEGRAM_ARMV6)
    return [SSignal single:OGPlatformVideoThumbnailAtURL(_legacyURL, position, self.originalSize)];
#else
    return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_avAsset size:self.originalSize timestamp:CMTimeMakeWithSeconds(position, NSEC_PER_SEC)];
#endif
}

@end
