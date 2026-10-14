#import "TGMediaAssetImageSignals.h"

#import "../Photos/Photos.h"
#import <AssetsLibrary/AssetsLibrary.h>

#import "TGMediaAssetModernImageSignals.h"
#import "TGMediaAssetLegacyImageSignals.h"

#import "TGPhotoEditorUtils.h"

#import "TGMediaAssetsLibrary.h"
#import "../../../OnegramPlatform/OGPlatformMedia.h"

const CGSize TGMediaAssetImageLegacySizeLimit = { 2048, 2048 };

@implementation TGMediaAssetImageData

@end

@implementation TGMediaAssetImageFileAttributes

@end


@implementation TGMediaAssetImageSignals

static Class TGMediaAssetImageSignalsClass = nil;

+ (void)load
{
    @autoreleasepool
    {
#if defined(ONEGRAM_ARMV6)
        TGMediaAssetImageSignalsClass = [TGMediaAssetLegacyImageSignals class];
#else
        if ([TGMediaAssetsLibrary usesPhotoFramework])
            TGMediaAssetImageSignalsClass = [TGMediaAssetModernImageSignals class];
        else
            TGMediaAssetImageSignalsClass = [TGMediaAssetLegacyImageSignals class];
#endif
    }
}

+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    return [self imageForAsset:asset imageType:imageType size:size allowNetworkAccess:true];
}

+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size allowNetworkAccess:(bool)allowNetworkAccess
{
    return [TGMediaAssetImageSignalsClass imageForAsset:asset imageType:imageType size:size allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)livePhotoForAsset:(TGMediaAsset *)asset
{
    return [self livePhotoForAsset:asset allowNetworkAccess:true];
}

+ (SSignal *)livePhotoForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    return [TGMediaAssetImageSignalsClass livePhotoForAsset:asset allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset
{
    return [self imageDataForAsset:asset allowNetworkAccess:true];
}

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    return [TGMediaAssetImageSignalsClass imageDataForAsset:asset allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)imageMetadataForAsset:(TGMediaAsset *)asset
{
    return [TGMediaAssetImageSignalsClass imageMetadataForAsset:asset];
}

+ (SSignal *)fileAttributesForAsset:(TGMediaAsset *)asset
{
    return [TGMediaAssetImageSignalsClass fileAttributesForAsset:asset];
}

+ (void)startCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    return [TGMediaAssetImageSignalsClass startCachingImagesForAssets:assets imageType:imageType size:size];
}

+ (void)stopCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    return [TGMediaAssetImageSignalsClass stopCachingImagesForAssets:assets imageType:imageType size:size];
}

+ (void)stopCachingImagesForAllAssets
{
    [TGMediaAssetImageSignalsClass stopCachingImagesForAllAssets];
}

+ (SQueue *)_thumbnailQueue
{
    static dispatch_once_t onceToken;
    static SQueue *queue;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] init];
    });
    return queue;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
+ (SSignal *)videoThumbnailsForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamps:(NSArray *)timestamps
{
    if (asset == nil || timestamps.count == 0)
        return [SSignal fail:nil];

    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:timestamps.count];
        UIImage *fallbackImage = nil;
        CGImageRef fallbackImageRef = asset.backingLegacyAsset.thumbnail;
        if (fallbackImageRef != NULL)
            fallbackImage = [UIImage imageWithCGImage:fallbackImageRef];

        for (id value in timestamps)
        {
            NSTimeInterval seconds = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0.0;
            UIImage *image = OGPlatformVideoThumbnailAtURL(asset.url, seconds, size);
            if (image == nil)
                image = fallbackImage;
            if (image == nil)
            {
                [subscriber putError:nil];
                return nil;
            }
            [images addObject:image];
        }

        [subscriber putNext:images];
        [subscriber putCompletion];
        return nil;
    }] startOn:[self _thumbnailQueue]];
}

static NSURL *TGMediaAssetLegacyURLFromAVAsset(id avAsset)
{
    if (avAsset == nil)
        return nil;
    SEL selector = NSSelectorFromString(@"URL");
    if (![avAsset respondsToSelector:selector])
        return nil;
    id (*function)(id, SEL) = (id (*)(id, SEL))[avAsset methodForSelector:selector];
    return function != NULL ? function(avAsset, selector) : nil;
}

+ (SSignal *)videoThumbnailsForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamps:(NSArray *)timestamps
{
    NSURL *url = TGMediaAssetLegacyURLFromAVAsset(avAsset);
    if (url == nil || timestamps.count == 0)
        return [SSignal fail:nil];

    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:timestamps.count];
        for (id value in timestamps)
        {
            NSTimeInterval seconds = [value respondsToSelector:@selector(doubleValue)] ? [value doubleValue] : 0.0;
            UIImage *image = OGPlatformVideoThumbnailAtURL(url, seconds, size);
            if (image == nil)
            {
                [subscriber putError:nil];
                return nil;
            }
            [images addObject:image];
        }
        [subscriber putNext:images];
        [subscriber putCompletion];
        return nil;
    }] startOn:[self _thumbnailQueue]];
}

+ (SSignal *)videoThumbnailForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamp:(CMTime)timestamp
{
    if (asset == nil)
        return [SSignal fail:nil];

    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        UIImage *image = OGPlatformVideoThumbnailAtURL(asset.url, CMTimeGetSeconds(timestamp), size);
        if (image == nil)
        {
            CGImageRef fallbackImageRef = asset.backingLegacyAsset.thumbnail;
            if (fallbackImageRef != NULL)
                image = [UIImage imageWithCGImage:fallbackImageRef];
        }
        if (image == nil)
            [subscriber putError:nil];
        else
        {
            [subscriber putNext:image];
            [subscriber putCompletion];
        }
        return nil;
    }] startOn:[self _thumbnailQueue]];
}

+ (SSignal *)videoThumbnailForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamp:(CMTime)timestamp
{
    NSURL *url = TGMediaAssetLegacyURLFromAVAsset(avAsset);
    if (url == nil)
        return [SSignal fail:nil];

    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        UIImage *image = OGPlatformVideoThumbnailAtURL(url, CMTimeGetSeconds(timestamp), size);
        if (image == nil)
            [subscriber putError:nil];
        else
        {
            [subscriber putNext:image];
            [subscriber putCompletion];
        }
        return nil;
    }] startOn:[self _thumbnailQueue]];
}

#else
+ (SSignal *)videoThumbnailsForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamps:(NSArray *)timestamps
{
    return [[self avAssetForVideoAsset:asset] mapToSignal:^SSignal *(AVAsset *avAsset)
    {
        return [self videoThumbnailsForAVAsset:avAsset size:size timestamps:timestamps];
    }];
}

+ (SSignal *)videoThumbnailsForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamps:(NSArray *)timestamps
{
    SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSMutableArray *images = [[NSMutableArray alloc] init];
        
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:avAsset];
        generator.appliesPreferredTrackTransform = true;
        generator.maximumSize = size;
        
        [generator generateCGImagesAsynchronouslyForTimes:timestamps completionHandler:^(__unused CMTime requestedTime, CGImageRef imageRef, __unused CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error)
        {
           if (error != nil)
           {
               [subscriber putError:error];
               return;
           }
            
            UIImage *image = [UIImage imageWithCGImage:imageRef];
            if (result == AVAssetImageGeneratorSucceeded && image != nil)
                [images addObject:image];
            
            if (images.count == timestamps.count)
            {
                [subscriber putNext:images];
                [subscriber putCompletion];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [generator cancelAllCGImageGeneration];
        }];
    }];
    
    return [signal startOn:[self _thumbnailQueue]];
}

+ (SSignal *)videoThumbnailForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamp:(CMTime)timestamp
{
    return [[self avAssetForVideoAsset:asset] mapToSignal:^SSignal *(AVAsset *avAsset)
    {
        return [self videoThumbnailForAVAsset:avAsset size:size timestamp:timestamp];
    }];
}

+ (SSignal *)videoThumbnailForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamp:(CMTime)timestamp
{
    SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:avAsset];
        generator.appliesPreferredTrackTransform = true;
        generator.maximumSize = size;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter = kCMTimeZero;
        
        [generator generateCGImagesAsynchronouslyForTimes:@[ [NSValue valueWithCMTime:timestamp] ] completionHandler:^(__unused CMTime requestedTime, CGImageRef imageRef, __unused CMTime actualTime, AVAssetImageGeneratorResult result, __unused NSError *error)
        {
            UIImage *image = [UIImage imageWithCGImage:imageRef];
            if (result == AVAssetImageGeneratorSucceeded && image != nil)
            {
                [subscriber putNext:image];
                [subscriber putCompletion];
            }
        }];
    
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [generator cancelAllCGImageGeneration];
        }];
    }];
    
    return [signal startOn:[self _thumbnailQueue]];
}

#endif

+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path
{
    return [self saveUncompressedVideoForAsset:asset toPath:path allowNetworkAccess:false];
}

+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path allowNetworkAccess:(bool)allowNetworkAccess
{
    if (!asset.isVideo)
        return [SSignal fail:nil];
    
    return [TGMediaAssetImageSignalsClass saveUncompressedVideoForAsset:asset toPath:path allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)playerItemForVideoAsset:(TGMediaAsset *)asset
{
    if (asset == nil)
        return [SSignal fail:nil];
    
    return [TGMediaAssetImageSignalsClass playerItemForVideoAsset:asset];
}

+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset
{
    return [self avAssetForVideoAsset:asset allowNetworkAccess:false];
}

+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    if (asset == nil)
        return [SSignal fail:nil];
    
    return [TGMediaAssetImageSignalsClass avAssetForVideoAsset:asset allowNetworkAccess:allowNetworkAccess];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
+ (UIImageOrientation)videoOrientationOfAVAsset:(AVAsset *)__unused avAsset
{
    return UIImageOrientationUp;
}

#else
+ (UIImageOrientation)videoOrientationOfAVAsset:(AVAsset *)avAsset
{
    NSArray *videoTracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks.firstObject;
    if (videoTrack == nil)
        return UIImageOrientationUp;
    
    CGAffineTransform transform = videoTrack.preferredTransform;
    CGFloat angle = TGRadiansToDegrees((CGFloat)atan2(transform.b, transform.a));
    
    UIImageOrientation orientation = 0;
    switch ((NSInteger)angle)
    {
        case 0:
            orientation = UIImageOrientationUp;
            break;
        case 90:
            orientation = UIImageOrientationRight;
            break;
        case 180:
            orientation = UIImageOrientationDown;
            break;
        case -90:
            orientation	= UIImageOrientationLeft;
            break;
        default:
            orientation = UIImageOrientationUp;
            break;
    }
    
    return orientation;
}

#endif

+ (bool)usesPhotoFramework
{
    return [TGMediaAssetImageSignalsClass usesPhotoFramework];
}

@end
