#import "TGMediaAsset.h"
#import "TGMediaAssetImageSignals.h"
#import "TGImageUtils.h"

#import "LegacyComponentsInternal.h"

#import <MobileCoreServices/MobileCoreServices.h>


static UIImageOrientation TGMediaAssetUIImageOrientationForALAssetOrientation(ALAssetOrientation orientation)
{
    switch (orientation)
    {
        case ALAssetOrientationDown:
            return UIImageOrientationDown;
        case ALAssetOrientationLeft:
            return UIImageOrientationLeft;
        case ALAssetOrientationRight:
            return UIImageOrientationRight;
        case ALAssetOrientationUpMirrored:
            return UIImageOrientationUpMirrored;
        case ALAssetOrientationDownMirrored:
            return UIImageOrientationDownMirrored;
        case ALAssetOrientationLeftMirrored:
            return UIImageOrientationLeftMirrored;
        case ALAssetOrientationRightMirrored:
            return UIImageOrientationRightMirrored;
        case ALAssetOrientationUp:
        default:
            return UIImageOrientationUp;
    }
}

CGSize TGMediaAssetLegacyRepresentationDimensions(ALAssetRepresentation *representation)
{
    if (representation == nil)
        return CGSizeZero;

    if (iosMajorVersion() >= 5)
        return representation.dimensions;

    CGImageRef imageRef = representation.fullResolutionImage;
    if (imageRef == NULL)
        imageRef = representation.fullScreenImage;
    if (imageRef == NULL)
        return CGSizeZero;

    return CGSizeMake((CGFloat)CGImageGetWidth(imageRef), (CGFloat)CGImageGetHeight(imageRef));
}

NSString *TGMediaAssetLegacyRepresentationFileName(ALAssetRepresentation *representation)
{
    if (representation == nil)
        return nil;

    if (iosMajorVersion() >= 5)
        return representation.filename;

    NSString *lastPathComponent = representation.url.absoluteString.lastPathComponent;
    NSArray *components = [lastPathComponent componentsSeparatedByString:@"?"];
    return components.count == 0 ? lastPathComponent : components[0];
}

UIImage *TGMediaAssetLegacyAspectRatioThumbnailImage(ALAsset *asset)
{
    if (asset == nil)
        return nil;

    if (iosMajorVersion() >= 5)
    {
        CGImageRef imageRef = asset.aspectRatioThumbnail;
        return imageRef == NULL ? nil : [UIImage imageWithCGImage:imageRef];
    }

    ALAssetRepresentation *representation = asset.defaultRepresentation;
    if (representation == nil)
        return nil;

    CGImageRef imageRef = representation.fullScreenImage;
    if (imageRef == NULL)
    {
        imageRef = asset.thumbnail;
        return imageRef == NULL ? nil : [UIImage imageWithCGImage:imageRef];
    }

    ALAssetOrientation orientation = representation.orientation;
    UIImage *sourceImage = [UIImage imageWithCGImage:imageRef scale:1.0f orientation:TGMediaAssetUIImageOrientationForALAssetOrientation(orientation)];
    CGSize dimensions = TGMediaAssetLegacyRepresentationDimensions(representation);
    if (orientation == ALAssetOrientationLeft || orientation == ALAssetOrientationRight || orientation == ALAssetOrientationLeftMirrored || orientation == ALAssetOrientationRightMirrored)
        dimensions = CGSizeMake(dimensions.height, dimensions.width);

    CGImageRef squareThumbnail = asset.thumbnail;
    CGFloat maximumDimension = 150.0f;
    if (squareThumbnail != NULL)
        maximumDimension = MAX((CGFloat)CGImageGetWidth(squareThumbnail), (CGFloat)CGImageGetHeight(squareThumbnail));

    if (dimensions.width < 1.0f || dimensions.height < 1.0f)
        return sourceImage;

    CGFloat scale = MIN(1.0f, maximumDimension / MAX(dimensions.width, dimensions.height));
    if (scale >= 1.0f)
        return sourceImage;

    CGSize targetSize = CGSizeMake(MAX(1.0f, dimensions.width * scale), MAX(1.0f, dimensions.height * scale));
    return TGScaleImageToPixelSize(sourceImage, targetSize);
}

@interface TGMediaAsset ()
{
    NSNumber *_cachedType;
    
    NSString *_cachedUniqueId;
    NSURL *_cachedLegacyAssetUrl;
    NSNumber *_cachedLegacyVideoRotated;
    
    NSNumber *_cachedDuration;
}
@end

@implementation TGMediaAsset

- (instancetype)initWithPHAsset:(PHAsset *)asset
{
    self = [super init];
    if (self != nil)
    {
        _backingAsset = asset;
    }
    return self;
}

- (instancetype)initWithALAsset:(ALAsset *)asset
{
    self = [super init];
    if (self != nil)
    {
        _backingLegacyAsset = asset;
    }
    return self;
}

- (NSString *)identifier
{
    if (_cachedUniqueId == nil)
    {
        if (self.backingAsset != nil)
            _cachedUniqueId = self.backingAsset.localIdentifier;
        else
            _cachedUniqueId = self.url.absoluteString;
    }
    
    return _cachedUniqueId;
}

- (NSURL *)url
{
    if (self.backingLegacyAsset != nil)
    {
        if (!_cachedLegacyAssetUrl)
            _cachedLegacyAssetUrl = [self.backingLegacyAsset defaultRepresentation].url;
        
        return _cachedLegacyAssetUrl;
    }
    
    return nil;
}

- (CGSize)dimensions
{
    if (self.backingAsset != nil)
    {
        return CGSizeMake(self.backingAsset.pixelWidth, self.backingAsset.pixelHeight);
    }
    else if (self.backingLegacyAsset != nil)
    {
        CGSize dimensions = TGMediaAssetLegacyRepresentationDimensions(self.backingLegacyAsset.defaultRepresentation);
        
        if (self.isVideo)
        {
            bool videoRotated = false;
            if (_cachedLegacyVideoRotated == nil)
            {
                ALAssetOrientation orientation = self.backingLegacyAsset.defaultRepresentation.orientation;
                videoRotated = orientation == ALAssetOrientationLeft || orientation == ALAssetOrientationRight || orientation == ALAssetOrientationLeftMirrored || orientation == ALAssetOrientationRightMirrored;
                _cachedLegacyVideoRotated = @(videoRotated);
            }
            else
            {
                videoRotated = _cachedLegacyVideoRotated.boolValue;
            }
            
            if (videoRotated)
                dimensions = CGSizeMake(dimensions.height, dimensions.width);
        }
        
        return dimensions;
    }
    
    return CGSizeZero;
}

- (NSDate *)date
{
    if (self.backingAsset != nil)
        return self.backingAsset.creationDate;
    else if (self.backingLegacyAsset != nil)
        return [self.backingLegacyAsset valueForProperty:ALAssetPropertyDate];
    
    return nil;
}

- (bool)isVideo
{
    return self.type == TGMediaAssetVideoType;
}

- (bool)representsBurst
{
    return self.backingAsset.representsBurst;
}

- (NSString *)uniformTypeIdentifier
{
    if (self.backingAsset != nil)
        return [self.backingAsset valueForKey:@"uniformTypeIdentifier"];
    else if (self.backingLegacyAsset != nil)
        return self.backingLegacyAsset.defaultRepresentation.UTI;
    
    return nil;
}

- (NSString *)fileName
{
    if (self.backingAsset != nil)
        return [self.backingAsset valueForKey:@"filename"];
    else if (self.backingLegacyAsset != nil)
        return TGMediaAssetLegacyRepresentationFileName(self.backingLegacyAsset.defaultRepresentation);
    
    return nil;
}

- (bool)_isGif
{
    return [self.uniformTypeIdentifier isEqualToString:(NSString *)kUTTypeGIF];
}

- (TGMediaAssetType)type
{
    if (_cachedType == nil)
    {
        if (self.backingAsset != nil)
        {
            if ([self _isGif])
                _cachedType = @(TGMediaAssetGifType);
            else
                _cachedType = @([TGMediaAsset assetTypeForPHAssetMediaType:self.backingAsset.mediaType]);
        }
        else if (self.backingLegacyAsset != nil)
        {
            if ([[self.backingLegacyAsset valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo])
                _cachedType = @(TGMediaAssetVideoType);
            else if ([self _isGif])
                _cachedType = @(TGMediaAssetGifType);
            else
                _cachedType = @(TGMediaAssetPhotoType);
        }
    }
    
    return _cachedType.intValue;
}

- (TGMediaAssetSubtype)subtypes
{
    TGMediaAssetSubtype subtypes = TGMediaAssetSubtypeNone;
    
    if (self.backingAsset != nil)
        subtypes = [TGMediaAsset assetSubtypesForPHAssetMediaSubtypes:self.backingAsset.mediaSubtypes];
    
    return subtypes;
}

- (NSTimeInterval)videoDuration
{
    if (self.backingAsset != nil)
        return self.backingAsset.duration;
    else if (self.backingLegacyAsset != nil)
        return [[self.backingLegacyAsset valueForProperty:ALAssetPropertyDuration] doubleValue];
    
    return 0;
}

- (SSignal *)actualVideoDuration
{
    if (!self.isVideo)
        return [SSignal fail:nil];
    
    if (_cachedDuration == nil)
    {
        return [[TGMediaAssetImageSignals avAssetForVideoAsset:self] map:^id(AVAsset *asset)
        {
            NSTimeInterval duration = CMTimeGetSeconds(asset.duration);
            _cachedDuration = @(duration);
            return _cachedDuration;
        }];
    }
    
    return [SSignal single:_cachedDuration];
}

+ (PHAssetMediaType)assetMediaTypeForAssetType:(TGMediaAssetType)assetType
{
    switch (assetType)
    {
        case TGMediaAssetPhotoType:
            return PHAssetMediaTypeImage;
            
        case TGMediaAssetVideoType:
            return PHAssetMediaTypeVideo;
            
        default:
            return PHAssetMediaTypeUnknown;
    }
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    return [self.identifier isEqual:((TGMediaAsset *)object).identifier];
}

+ (TGMediaAssetType)assetTypeForPHAssetMediaType:(PHAssetMediaType)type
{
    switch (type)
    {
        case PHAssetMediaTypeImage:
            return TGMediaAssetPhotoType;
            
        case PHAssetMediaTypeVideo:
            return TGMediaAssetVideoType;
            
        default:
            return TGMediaAssetAnyType;
    }
}

+ (TGMediaAssetSubtype)assetSubtypesForPHAssetMediaSubtypes:(PHAssetMediaSubtype) subtypes
{
    TGMediaAssetSubtype result = TGMediaAssetSubtypeNone;
    
    if (subtypes & PHAssetMediaSubtypePhotoPanorama)
        result |= TGMediaAssetSubtypePhotoPanorama;
    
    if (subtypes & PHAssetMediaSubtypePhotoHDR)
        result |= TGMediaAssetSubtypePhotoHDR;
    
    if (iosMajorVersion() >= 9 && subtypes & PHAssetMediaSubtypePhotoScreenshot)
        result |= TGMediaAssetSubtypePhotoScreenshot;
    
    if (subtypes & PHAssetMediaSubtypeVideoStreamed)
        result |= TGMediaAssetSubtypeVideoStreamed;
    
    if (subtypes & PHAssetMediaSubtypeVideoHighFrameRate)
        result |= TGMediaAssetSubtypeVideoHighFrameRate;
    
    if (subtypes & PHAssetMediaSubtypeVideoTimelapse)
        result |= TGMediaAssetSubtypeVideoTimelapse;
    
    if (subtypes & PHAssetMediaSubtypePhotoLive)
        result |= TGMediaAssetSubtypePhotoLive;
    
    return result;
}

- (NSString *)uniqueIdentifier
{
    return self.identifier;
}

@end
