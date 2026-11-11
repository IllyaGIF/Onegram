#import "TGPaintFaceDetector.h"
#import "TGPhotoEditorUtils.h"
#import "TGPaintUtils.h"

#if !defined(ONEGRAM_ARMV6)
@interface CIFaceFeature (OGCompatFaceAttributes)
@property (readonly) BOOL leftEyeClosed;
@property (readonly) BOOL rightEyeClosed;
@property (readonly) BOOL hasSmile;
@property (readonly) float faceAngle;
@end

@interface CIImage (OGCompatOrientation)
- (CIImage *)imageByApplyingOrientation:(int)orientation;
@end
#endif

@interface TGPaintFace ()

+ (instancetype)faceWithBounds:(CGRect)bounds angle:(CGFloat)angle leftEye:(TGPaintFaceEye *)leftEye rightEye:(TGPaintFaceEye *)rightEye mouth:(TGPaintFaceMouth *)mouth;

@end


@interface TGPaintFaceEye ()

+ (instancetype)eyeWithPosition:(CGPoint)position closed:(bool)closed;

@end


@interface TGPaintFaceMouth ()

+ (instancetype)mouthWithPosition:(CGPoint)position smiling:(bool)smiling;

@end


@implementation TGPaintFaceDetector

+ (SSignal *)detectFacesInImage:(UIImage *)image originalSize:(CGSize)originalSize
{
#if defined(ONEGRAM_ARMV6)
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [subscriber putNext:@[]];
        [subscriber putCompletion];
        return nil;
    }];
#else
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        if (NSClassFromString(@"CIDetector") == Nil || NSClassFromString(@"CIImage") == Nil)
        {
            [subscriber putNext:@[]];
            [subscriber putCompletion];
            return nil;
        }

        NSDictionary *options = @
        {
            CIDetectorAccuracy: CIDetectorAccuracyHigh,
            @"CIDetectorMinFeatureSize" : @(0.175)
        };
        
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:options];
        
        CIImage *ciImage = [CIImage imageWithCGImage:image.CGImage];
        if ([ciImage respondsToSelector:@selector(imageByApplyingOrientation:)])
        {
            int tiffOrientation = [self tiffOrientationFromImageOrientation:image.imageOrientation];
            ciImage = [ciImage imageByApplyingOrientation:tiffOrientation];
        }
        
        NSMutableArray *result = [[NSMutableArray alloc] init];
        NSArray *features = [detector featuresInImage:ciImage];
        for (CIFaceFeature *feature in features)
        {
            if (![feature isKindOfClass:[CIFaceFeature class]])
                continue;
            
            TGPaintFace *face = [self _paintFaceForFaceFeature:feature initialSize:image.size targetSize:originalSize];
            if (face != nil)
                [result addObject:face];
        }
        
        [subscriber putNext:result];
        [subscriber putCompletion];
        
        return nil;
    }];
#endif
}

+ (int)tiffOrientationFromImageOrientation:(UIImageOrientation)orientation
{
    switch (orientation)
    {
        case UIImageOrientationUp:
            return 1;
            
        case UIImageOrientationDown:
            return 3;
            
        case UIImageOrientationLeft:
            return 8;
            
        case UIImageOrientationRight:
            return 6;
            
        case UIImageOrientationUpMirrored:
            return 2;
            
        case UIImageOrientationDownMirrored:
            return 4;
            
        case UIImageOrientationLeftMirrored:
            return 5;
            
        case UIImageOrientationRightMirrored:
            return 7;
            
        default:
            return 0;
    }
}

#if !defined(ONEGRAM_ARMV6)
+ (TGPaintFace *)_paintFaceForFaceFeature:(CIFaceFeature *)faceFeature initialSize:(CGSize)initialSize targetSize:(CGSize)targetSize
{
    if (faceFeature == nil)
        return nil;
    
    if (!faceFeature.hasLeftEyePosition || !faceFeature.hasRightEyePosition)
        return nil;
    
    CGPoint (^transpose)(CGPoint) = ^CGPoint(CGPoint point)
    {
        return [self _transposedPoint:point initialSize:initialSize targetSize:targetSize];
    };
    
    bool closedLeft = false;
    bool closedRight = false;
    bool smiles = false;
    CGFloat angle = 0.0f;
    if ([faceFeature respondsToSelector:@selector(leftEyeClosed)])
        closedLeft = faceFeature.leftEyeClosed;
    if ([faceFeature respondsToSelector:@selector(rightEyeClosed)])
        closedRight = faceFeature.rightEyeClosed;
    if ([faceFeature respondsToSelector:@selector(hasSmile)])
        smiles = faceFeature.hasSmile;
    if ([faceFeature respondsToSelector:@selector(faceAngle)])
        angle = faceFeature.faceAngle;
    
    TGPaintFaceMouth *mouth = nil;
    if (faceFeature.hasMouthPosition)
        mouth = [TGPaintFaceMouth mouthWithPosition:transpose(faceFeature.mouthPosition) smiling:smiles];
    
    TGPaintFaceEye *rightEye = [TGPaintFaceEye eyeWithPosition:transpose(faceFeature.rightEyePosition) closed:closedRight];
    TGPaintFaceEye *leftEye = [TGPaintFaceEye eyeWithPosition:transpose(faceFeature.leftEyePosition) closed:closedLeft];
    CGRect bounds = [self _transposedRect:faceFeature.bounds initialSize:initialSize targetSize:targetSize];
    
    return [TGPaintFace faceWithBounds:bounds angle:[self _transposedAngle:TGDegreesToRadians(angle)] leftEye:leftEye rightEye:rightEye mouth:mouth];
}

#endif

+ (CGFloat)_transposedAngle:(CGFloat)angle
{
    return angle;
}

+ (CGRect)_transposedRect:(CGRect)rect initialSize:(CGSize)initialSize targetSize:(CGSize)targetSize
{
    return CGRectMake(targetSize.width * rect.origin.x / initialSize.width, targetSize.height * (initialSize.height - rect.origin.y - rect.size.height) / initialSize.height, targetSize.width * rect.size.width / initialSize.width, targetSize.height * rect.size.height / initialSize.height);
}

+ (CGPoint)_transposedPoint:(CGPoint)point initialSize:(CGSize)initialSize targetSize:(CGSize)targetSize
{
    return CGPointMake(targetSize.width * point.x / initialSize.width, targetSize.height - targetSize.height * point.y / initialSize.height);
}

@end


@implementation TGPaintFace

+ (instancetype)faceWithBounds:(CGRect)bounds angle:(CGFloat)angle leftEye:(TGPaintFaceEye *)leftEye rightEye:(TGPaintFaceEye *)rightEye mouth:(TGPaintFaceMouth *)mouth
{
    TGPaintFace *face = [[TGPaintFace alloc] init];
    arc4random_buf(&face->_uuid, sizeof(NSInteger));
    face->_bounds = bounds;
    face->_angle = angle;
    face->_leftEye = leftEye;
    face->_rightEye = rightEye;
    face->_mouth = mouth;
    return face;
}

- (CGPoint)foreheadPoint
{
    CGFloat halfFace = _bounds.size.height / 2.0f;
    CGPoint point = TGPaintCenterOfRect(_bounds);
    
    return CGPointMake(point.x + halfFace * cos(_angle - M_PI_2), point.y + halfFace * sin(_angle - M_PI_2));
}

- (CGPoint)eyesCenterPointAndDistance:(CGFloat *)distance
{
    CGPoint point = CGPointMake(0.5f * _leftEye.position.x + 0.5f * _rightEye.position.x, 0.5f * _leftEye.position.y + 0.5f * _rightEye.position.y);
    CGFloat dist = sqrt(pow(_rightEye.position.x - _leftEye.position.x, 2) + pow(_rightEye.position.y - _leftEye.position.y, 2));

    if (distance != NULL)
        *distance = dist;
    
    return point;
}

- (CGFloat)eyesAngle
{
    return atan2(_rightEye.position.y - _leftEye.position.y, _rightEye.position.x - _leftEye.position.x);
}

- (CGPoint)mouthPoint
{
    return _mouth.position;
}

- (CGPoint)chinPoint
{
    CGFloat halfFace = _bounds.size.height / 2.0f;
    CGPoint point = TGPaintCenterOfRect(_bounds);
    
    return CGPointMake(point.x + halfFace * cos(_angle + M_PI_2), point.y + halfFace * sin(_angle + M_PI_2));
}

@end


@implementation TGPaintFaceFeature

@end


@implementation TGPaintFaceEye

+ (instancetype)eyeWithPosition:(CGPoint)position closed:(bool)closed
{
    TGPaintFaceEye *eye = [[TGPaintFaceEye alloc] init];
    eye->_position = position;
    eye->_closed = closed;
    return eye;
}

@end


@implementation TGPaintFaceMouth

+ (instancetype)mouthWithPosition:(CGPoint)position smiling:(bool)smiling
{
    TGPaintFaceMouth *mouth = [[TGPaintFaceMouth alloc] init];
    mouth->_position = position;
    mouth->_smiling = smiling;
    return mouth;
}

@end


@implementation TGPaintFaceUtils

+ (CGFloat)transposeWidth:(CGFloat)width paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    return width * paintingSize.width / originalSize.width;
}

+ (CGPoint)transposePoint:(CGPoint)point paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    return CGPointMake(point.x * paintingSize.width / originalSize.width, point.y * paintingSize.height / originalSize.height);
}

+ (CGRect)transposeRect:(CGRect)rect paintingSize:(CGSize)paintingSize originalSize:(CGSize)originalSize
{
    CGPoint origin = [self transposePoint:rect.origin paintingSize:paintingSize originalSize:originalSize];
    CGSize size = CGSizeMake(rect.size.width * paintingSize.width / originalSize.width, rect.size.height * paintingSize.height / originalSize.height);
    
    return (CGRect){ origin, size };
}

@end
