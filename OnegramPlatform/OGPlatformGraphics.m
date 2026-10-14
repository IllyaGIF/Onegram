#import "OGPlatformGraphics.h"
#import "OGPlatformVersion.h"
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <ImageIO/ImageIO.h>
#endif
#import <math.h>
#include <float.h>
#include <stdint.h>
#include <stdlib.h>

@interface OGPlatformLegacyShadowView : UIView
{
    UIColor *_shadowColor;
    CGFloat _shadowOpacity;
    CGFloat _shadowRadius;
    CGSize _shadowOffset;
    CGFloat _cornerRadius;
}
- (instancetype)initWithFrame:(CGRect)frame color:(UIColor *)color opacity:(CGFloat)opacity radius:(CGFloat)radius offset:(CGSize)offset cornerRadius:(CGFloat)cornerRadius;
- (void)updateWithFrame:(CGRect)frame color:(UIColor *)color opacity:(CGFloat)opacity radius:(CGFloat)radius offset:(CGSize)offset cornerRadius:(CGFloat)cornerRadius;
- (void)refreshContents;
@end

static void OGPlatformColorComponents(UIColor *color, CGFloat components[4]);

@implementation OGPlatformLegacyShadowView

- (instancetype)initWithFrame:(CGRect)frame color:(UIColor *)color opacity:(CGFloat)opacity radius:(CGFloat)radius offset:(CGSize)offset cornerRadius:(CGFloat)cornerRadius
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _shadowColor = color;
        _shadowOpacity = opacity;
        _shadowRadius = radius;
        _shadowOffset = offset;
        _cornerRadius = cornerRadius;
        [self refreshContents];
    }
    return self;
}

- (void)refreshContents
{
    CGSize size = self.bounds.size;
    if (_shadowColor == nil || _shadowOpacity <= 0.0f || size.width < 1.0f || size.height < 1.0f)
    {
        self.layer.contents = nil;
        return;
    }

    CGFloat scale = OGPlatformScreenScale();
    CGFloat components[4];
    OGPlatformColorComponents(_shadowColor, components);
    NSString *key = [[NSString alloc] initWithFormat:@"%.2f:%.2f:%.1f:%.3f:%.3f:%.3f:%.3f:%.3f:%.2f:%.2f:%.2f:%.2f", size.width, size.height, scale, components[0], components[1], components[2], components[3], _shadowOpacity, _shadowRadius, _shadowOffset.width, _shadowOffset.height, _cornerRadius];

    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 64;
    });
    UIImage *image = [cache objectForKey:key];
    if (image == nil)
    {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
        UIGraphicsBeginImageContextWithOptions(size, NO, scale);
#else
        UIGraphicsBeginImageContext(size);
#endif
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (context != NULL)
        {
            CGFloat margin = ceilf(_shadowRadius * 2.0f + MAX(fabsf(_shadowOffset.width), fabsf(_shadowOffset.height)) + 2.0f);
            CGRect body = CGRectInset(CGRectMake(0.0f, 0.0f, size.width, size.height), margin, margin);
            CGContextSaveGState(context);
            CGContextSetShadowWithColor(context, _shadowOffset, _shadowRadius, [[_shadowColor colorWithAlphaComponent:_shadowOpacity] CGColor]);
            CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
            OGPlatformAddRoundedRectPath(context, body, _cornerRadius);
            CGContextFillPath(context);
            CGContextRestoreGState(context);
            CGContextSetBlendMode(context, kCGBlendModeClear);
            OGPlatformAddRoundedRectPath(context, body, _cornerRadius);
            CGContextFillPath(context);
            image = UIGraphicsGetImageFromCurrentImageContext();
        }
        UIGraphicsEndImageContext();
        if (image != nil)
            [cache setObject:image forKey:key];
    }

    SEL contentsScaleSelector = NSSelectorFromString(@"setContentsScale:");
    if ([self.layer respondsToSelector:contentsScaleSelector])
    {
        void (*setContentsScale)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[self.layer methodForSelector:contentsScaleSelector];
        setContentsScale(self.layer, contentsScaleSelector, image.scale);
    }
    self.layer.contents = (__bridge id)image.CGImage;
}

- (void)updateWithFrame:(CGRect)frame color:(UIColor *)color opacity:(CGFloat)opacity radius:(CGFloat)radius offset:(CGSize)offset cornerRadius:(CGFloat)cornerRadius
{
    BOOL colorChanged = _shadowColor != color && ![_shadowColor isEqual:color];
    BOOL changed = !CGRectEqualToRect(self.frame, frame) || colorChanged || fabsf(_shadowOpacity - opacity) > FLT_EPSILON || fabsf(_shadowRadius - radius) > FLT_EPSILON || !CGSizeEqualToSize(_shadowOffset, offset) || fabsf(_cornerRadius - cornerRadius) > FLT_EPSILON;
    if (!changed)
        return;
    self.frame = frame;
    _shadowColor = color;
    _shadowOpacity = opacity;
    _shadowRadius = radius;
    _shadowOffset = offset;
    _cornerRadius = cornerRadius;
    [self refreshContents];
}

@end

static void OGPlatformColorComponents(UIColor *color, CGFloat components[4])
{
    components[0] = 0.0f;
    components[1] = 0.0f;
    components[2] = 0.0f;
    components[3] = 1.0f;
    if (color == nil)
        return;
    CGColorRef cgColor = [color CGColor];
    if (cgColor == NULL)
        return;
    size_t count = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *values = CGColorGetComponents(cgColor);
    if (values == NULL)
        return;
    if (count == 2)
    {
        components[0] = values[0];
        components[1] = values[0];
        components[2] = values[0];
        components[3] = values[1];
    }
    else if (count >= 4)
    {
        components[0] = values[0];
        components[1] = values[1];
        components[2] = values[2];
        components[3] = values[3];
    }
}

CGFloat OGPlatformPixelFloor(CGFloat value)
{
    CGFloat scale = OGPlatformScreenScale();
    return floorf(value * scale) / scale;
}

CGFloat OGPlatformPixelCeil(CGFloat value)
{
    CGFloat scale = OGPlatformScreenScale();
    return ceilf(value * scale) / scale;
}

CGFloat OGPlatformPixelRound(CGFloat value)
{
    CGFloat scale = OGPlatformScreenScale();
    return roundf(value * scale) / scale;
}

BOOL OGPlatformLayerSupportsShadow(CALayer *layer)
{
    if (layer == nil)
        return NO;
    return [layer respondsToSelector:NSSelectorFromString(@"setShadowColor:")] && [layer respondsToSelector:NSSelectorFromString(@"setShadowOpacity:")] && [layer respondsToSelector:NSSelectorFromString(@"setShadowRadius:")] && [layer respondsToSelector:NSSelectorFromString(@"setShadowOffset:")];
}

void OGPlatformSetLayerShadow(CALayer *layer, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset)
{
    if (!OGPlatformLayerSupportsShadow(layer))
        return;

    SEL colorSelector = NSSelectorFromString(@"setShadowColor:");
    SEL opacitySelector = NSSelectorFromString(@"setShadowOpacity:");
    SEL radiusSelector = NSSelectorFromString(@"setShadowRadius:");
    SEL offsetSelector = NSSelectorFromString(@"setShadowOffset:");

    void (*setColor)(id, SEL, CGColorRef) = (void (*)(id, SEL, CGColorRef))[layer methodForSelector:colorSelector];
    void (*setOpacity)(id, SEL, float) = (void (*)(id, SEL, float))[layer methodForSelector:opacitySelector];
    void (*setRadius)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[layer methodForSelector:radiusSelector];
    void (*setOffset)(id, SEL, CGSize) = (void (*)(id, SEL, CGSize))[layer methodForSelector:offsetSelector];

    if (setColor != NULL)
        setColor(layer, colorSelector, color == nil ? NULL : [color CGColor]);
    if (setOpacity != NULL)
        setOpacity(layer, opacitySelector, (float)opacity);
    if (setRadius != NULL)
        setRadius(layer, radiusSelector, radius);
    if (setOffset != NULL)
        setOffset(layer, offsetSelector, offset);
}

void OGPlatformSetLayerRasterization(CALayer *layer, BOOL rasterize, CGFloat scale)
{
    if (layer == nil)
        return;

    SEL scaleSelector = NSSelectorFromString(@"setRasterizationScale:");
    SEL rasterizeSelector = NSSelectorFromString(@"setShouldRasterize:");
    if (![layer respondsToSelector:scaleSelector] || ![layer respondsToSelector:rasterizeSelector])
        return;

    void (*setScale)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[layer methodForSelector:scaleSelector];
    void (*setRasterize)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[layer methodForSelector:rasterizeSelector];
    if (setScale != NULL)
        setScale(layer, scaleSelector, scale);
    if (setRasterize != NULL)
        setRasterize(layer, rasterizeSelector, rasterize);
}

BOOL OGPlatformGetLayerShadow(CALayer *layer, CGColorRef *color, CGFloat *opacity, CGFloat *radius, CGSize *offset)
{
    if (layer == nil)
        return NO;

    SEL colorSelector = NSSelectorFromString(@"shadowColor");
    SEL opacitySelector = NSSelectorFromString(@"shadowOpacity");
    SEL radiusSelector = NSSelectorFromString(@"shadowRadius");
    SEL offsetSelector = NSSelectorFromString(@"shadowOffset");
    if (![layer respondsToSelector:colorSelector] || ![layer respondsToSelector:opacitySelector] || ![layer respondsToSelector:radiusSelector] || ![layer respondsToSelector:offsetSelector])
        return NO;

    CGColorRef (*getColor)(id, SEL) = (CGColorRef (*)(id, SEL))[layer methodForSelector:colorSelector];
    float (*getOpacity)(id, SEL) = (float (*)(id, SEL))[layer methodForSelector:opacitySelector];
    CGFloat (*getRadius)(id, SEL) = (CGFloat (*)(id, SEL))[layer methodForSelector:radiusSelector];
    CGSize (*getOffset)(id, SEL) = (CGSize (*)(id, SEL))[layer methodForSelector:offsetSelector];
    if (getColor == NULL || getOpacity == NULL || getRadius == NULL || getOffset == NULL)
        return NO;

    if (color != NULL)
        *color = getColor(layer, colorSelector);
    if (opacity != NULL)
        *opacity = (CGFloat)getOpacity(layer, opacitySelector);
    if (radius != NULL)
        *radius = getRadius(layer, radiusSelector);
    if (offset != NULL)
        *offset = getOffset(layer, offsetSelector);
    return YES;
}

void OGPlatformApplyViewShadow(UIView *view, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset)
{
    OGPlatformApplyRoundedViewShadow(view, color, opacity, radius, offset, 0.0f);
}

void OGPlatformApplyRoundedViewShadow(UIView *view, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset, CGFloat cornerRadius)
{
    if (view == nil)
        return;
    if (OGPlatformLayerSupportsShadow(view.layer))
    {
        OGPlatformSetLayerShadow(view.layer, color, opacity, radius, offset);
        SEL shadowPathSelector = NSSelectorFromString(@"setShadowPath:");
        if ([view.layer respondsToSelector:shadowPathSelector])
        {
            void (*setShadowPath)(id, SEL, CGPathRef) = (void (*)(id, SEL, CGPathRef))[view.layer methodForSelector:shadowPathSelector];
            if (cornerRadius > 0.0f && color != nil && opacity > 0.0f && view.bounds.size.width > 0.0f && view.bounds.size.height > 0.0f)
                setShadowPath(view.layer, shadowPathSelector, [UIBezierPath bezierPathWithRoundedRect:view.bounds cornerRadius:cornerRadius].CGPath);
            else
                setShadowPath(view.layer, shadowPathSelector, NULL);
        }
        return;
    }
    NSInteger tag = 0x4f475348;
    UIView *existing = [view viewWithTag:tag];
    if (color == nil || opacity <= 0.0f)
    {
        [existing removeFromSuperview];
        return;
    }
    CGFloat margin = ceilf(radius * 2.0f + MAX(fabsf(offset.width), fabsf(offset.height)) + 2.0f);
    CGRect frame = CGRectMake(-margin, -margin, view.bounds.size.width + margin * 2.0f, view.bounds.size.height + margin * 2.0f);
    if ([existing isKindOfClass:[OGPlatformLegacyShadowView class]])
    {
        [(OGPlatformLegacyShadowView *)existing updateWithFrame:frame color:color opacity:opacity radius:radius offset:offset cornerRadius:cornerRadius];
        return;
    }
    [existing removeFromSuperview];
    OGPlatformLegacyShadowView *shadowView = [[OGPlatformLegacyShadowView alloc] initWithFrame:frame color:color opacity:opacity radius:radius offset:offset cornerRadius:cornerRadius];
    shadowView.tag = tag;
    [view insertSubview:shadowView atIndex:0];
}

UIImage *OGPlatformImageWithShadow(UIImage *image, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset)
{
    if (image == nil || color == nil || opacity <= 0.0f)
        return image;

    CGSize size = image.size;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    UIGraphicsBeginImageContextWithOptions(size, NO, OGPlatformScreenScale());
#else
    UIGraphicsBeginImageContext(size);
#endif
    CGContextRef context = UIGraphicsGetCurrentContext();
    UIColor *shadowColor = [color colorWithAlphaComponent:opacity];
    CGContextSetShadowWithColor(context, offset, radius, [shadowColor CGColor]);
    [image drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (result != nil)
        return result;
    return image;
}

void OGPlatformAddRoundedRectPath(CGContextRef context, CGRect rect, CGFloat radius)
{
    if (context == NULL)
        return;
    CGFloat maximum = MIN(rect.size.width, rect.size.height) * 0.5f;
    CGFloat r = MAX(0.0f, MIN(radius, maximum));
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, minX + r, minY);
    CGContextAddLineToPoint(context, maxX - r, minY);
    CGContextAddArcToPoint(context, maxX, minY, maxX, minY + r, r);
    CGContextAddLineToPoint(context, maxX, maxY - r);
    CGContextAddArcToPoint(context, maxX, maxY, maxX - r, maxY, r);
    CGContextAddLineToPoint(context, minX + r, maxY);
    CGContextAddArcToPoint(context, minX, maxY, minX, maxY - r, r);
    CGContextAddLineToPoint(context, minX, minY + r);
    CGContextAddArcToPoint(context, minX, minY, minX + r, minY, r);
    CGContextClosePath(context);
}

UIImage *OGPlatformImageFromData(NSData *data)
{
    if (data == nil || [data length] == 0)
        return nil;
    return [[UIImage alloc] initWithData:data];
}

CGSize OGPlatformImagePixelSizeFromData(NSData *data)
{
    UIImage *image = OGPlatformImageFromData(data);
    if (image == nil || image.CGImage == NULL)
        return CGSizeZero;
    return CGSizeMake((CGFloat)CGImageGetWidth(image.CGImage), (CGFloat)CGImageGetHeight(image.CGImage));
}

UIImage *OGPlatformThumbnailFromImageData(NSData *data, CGSize maximumSize)
{
    UIImage *image = OGPlatformImageFromData(data);
    if (image == nil || maximumSize.width <= 0.0f || maximumSize.height <= 0.0f)
        return image;
    CGSize sourceSize = image.size;
    if (sourceSize.width <= maximumSize.width && sourceSize.height <= maximumSize.height)
        return image;
    CGFloat scale = MIN(maximumSize.width / sourceSize.width, maximumSize.height / sourceSize.height);
    CGSize targetSize = CGSizeMake(MAX(1.0f, floorf(sourceSize.width * scale)), MAX(1.0f, floorf(sourceSize.height * scale)));
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0f);
#else
    UIGraphicsBeginImageContext(targetSize);
#endif
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result != nil ? result : image;
}

UIImage *OGPlatformThumbnailFromImageFile(NSString *path, size_t maximumPixelSize)
{
    if (path.length == 0)
        return nil;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    if (maximumPixelSize != 0)
    {
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
        if (source != NULL)
        {
            NSDictionary *options = @{
                (__bridge id)kCGImageSourceCreateThumbnailFromImageAlways: @true,
                (__bridge id)kCGImageSourceCreateThumbnailWithTransform: @true,
                (__bridge id)kCGImageSourceThumbnailMaxPixelSize: @(maximumPixelSize)
            };
            CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
            CFRelease(source);
            if (thumbnail != NULL)
            {
                UIImage *thumbnailImage = [UIImage imageWithCGImage:thumbnail];
                CGImageRelease(thumbnail);
                return thumbnailImage;
            }
        }
    }
#endif

    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (image == nil || image.CGImage == NULL || maximumPixelSize == 0)
        return image;

    size_t sourceWidth = CGImageGetWidth(image.CGImage);
    size_t sourceHeight = CGImageGetHeight(image.CGImage);
    size_t sourceMaximum = MAX(sourceWidth, sourceHeight);
    if (sourceMaximum <= maximumPixelSize)
        return image;

    CGFloat scale = (CGFloat)maximumPixelSize / (CGFloat)sourceMaximum;
    CGSize targetSize = CGSizeMake(MAX(1.0f, floorf((CGFloat)sourceWidth * scale)), MAX(1.0f, floorf((CGFloat)sourceHeight * scale)));
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0f);
#else
    UIGraphicsBeginImageContext(targetSize);
#endif
    [image drawInRect:CGRectMake(0.0f, 0.0f, targetSize.width, targetSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result != nil ? result : image;
}

NSData *OGPlatformJPEGRepresentation(UIImage *image, CGFloat quality)
{
    if (image == nil || image.CGImage == NULL)
        return nil;
    CGFloat value = MAX(0.0f, MIN(1.0f, quality));
    return UIImageJPEGRepresentation(image, value);
}

BOOL OGPlatformWriteJPEGRepresentationToFile(UIImage *image, CGFloat quality, NSString *path)
{
    if (path == nil)
        return NO;
    NSData *data = OGPlatformJPEGRepresentation(image, quality);
    return data != nil && [data writeToFile:path atomically:YES];
}

void OGPlatformDrawVerticalGradient(CGContextRef context, CGRect rect, UIColor *topColor, UIColor *bottomColor)
{
    if (context == NULL || CGRectIsEmpty(rect))
        return;
    CGFloat top[4];
    CGFloat bottom[4];
    OGPlatformColorComponents(topColor, top);
    OGPlatformColorComponents(bottomColor, bottom);
    CGFloat components[8] = {top[0], top[1], top[2], top[3], bottom[0], bottom[1], bottom[2], bottom[3]};
    CGFloat locations[2] = {0.0f, 1.0f};
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect)), CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

static size_t OGPlatformClampedIndex(NSInteger value, size_t limit)
{
    if (value < 0)
        return 0;
    if ((size_t)value >= limit)
        return limit - 1;
    return (size_t)value;
}

BOOL OGPlatformBoxConvolveARGB8888(const OGPlatformARGB8888Buffer *source, OGPlatformARGB8888Buffer *destination, size_t kernelWidth, size_t kernelHeight)
{
    if (source == NULL || destination == NULL || source->data == NULL || destination->data == NULL)
        return NO;
    if (source->width == 0 || source->height == 0 || source->width != destination->width || source->height != destination->height)
        return NO;
    if (source->rowBytes < source->width * 4 || destination->rowBytes < destination->width * 4)
        return NO;
    if (kernelWidth == 0 || kernelHeight == 0)
        return NO;
    if ((kernelWidth & 1) == 0)
        kernelWidth++;
    if ((kernelHeight & 1) == 0)
        kernelHeight++;

    size_t width = source->width;
    size_t height = source->height;
    size_t temporaryRowBytes = width * 4;
    uint8_t *temporary = malloc(temporaryRowBytes * height);
    if (temporary == NULL)
        return NO;

    const uint8_t *sourceBytes = source->data;
    NSInteger horizontalRadius = (NSInteger)(kernelWidth / 2);
    for (size_t y = 0; y < height; y++)
    {
        const uint8_t *row = sourceBytes + y * source->rowBytes;
        uint8_t *output = temporary + y * temporaryRowBytes;
        uint64_t sums[4] = {0, 0, 0, 0};
        for (NSInteger dx = -horizontalRadius; dx <= horizontalRadius; dx++)
        {
            const uint8_t *pixel = row + OGPlatformClampedIndex(dx, width) * 4;
            sums[0] += pixel[0]; sums[1] += pixel[1]; sums[2] += pixel[2]; sums[3] += pixel[3];
        }
        for (size_t x = 0; x < width; x++)
        {
            uint8_t *pixel = output + x * 4;
            pixel[0] = (uint8_t)(sums[0] / kernelWidth);
            pixel[1] = (uint8_t)(sums[1] / kernelWidth);
            pixel[2] = (uint8_t)(sums[2] / kernelWidth);
            pixel[3] = (uint8_t)(sums[3] / kernelWidth);
            const uint8_t *removePixel = row + OGPlatformClampedIndex((NSInteger)x - horizontalRadius, width) * 4;
            const uint8_t *addPixel = row + OGPlatformClampedIndex((NSInteger)x + horizontalRadius + 1, width) * 4;
            sums[0] = sums[0] - removePixel[0] + addPixel[0];
            sums[1] = sums[1] - removePixel[1] + addPixel[1];
            sums[2] = sums[2] - removePixel[2] + addPixel[2];
            sums[3] = sums[3] - removePixel[3] + addPixel[3];
        }
    }

    uint8_t *destinationBytes = destination->data;
    NSInteger verticalRadius = (NSInteger)(kernelHeight / 2);
    for (size_t x = 0; x < width; x++)
    {
        uint64_t sums[4] = {0, 0, 0, 0};
        for (NSInteger dy = -verticalRadius; dy <= verticalRadius; dy++)
        {
            const uint8_t *pixel = temporary + OGPlatformClampedIndex(dy, height) * temporaryRowBytes + x * 4;
            sums[0] += pixel[0]; sums[1] += pixel[1]; sums[2] += pixel[2]; sums[3] += pixel[3];
        }
        for (size_t y = 0; y < height; y++)
        {
            uint8_t *pixel = destinationBytes + y * destination->rowBytes + x * 4;
            pixel[0] = (uint8_t)(sums[0] / kernelHeight);
            pixel[1] = (uint8_t)(sums[1] / kernelHeight);
            pixel[2] = (uint8_t)(sums[2] / kernelHeight);
            pixel[3] = (uint8_t)(sums[3] / kernelHeight);
            const uint8_t *removePixel = temporary + OGPlatformClampedIndex((NSInteger)y - verticalRadius, height) * temporaryRowBytes + x * 4;
            const uint8_t *addPixel = temporary + OGPlatformClampedIndex((NSInteger)y + verticalRadius + 1, height) * temporaryRowBytes + x * 4;
            sums[0] = sums[0] - removePixel[0] + addPixel[0];
            sums[1] = sums[1] - removePixel[1] + addPixel[1];
            sums[2] = sums[2] - removePixel[2] + addPixel[2];
            sums[3] = sums[3] - removePixel[3] + addPixel[3];
        }
    }

    free(temporary);
    return YES;
}

static uint8_t OGPlatformClampByte(CGFloat value)
{
    if (value <= 0.0f)
        return 0;
    if (value >= 255.0f)
        return 255;
    return (uint8_t)(value + 0.5f);
}

BOOL OGPlatformSaturateBGRA8888(const OGPlatformARGB8888Buffer *source, OGPlatformARGB8888Buffer *destination, CGFloat saturation)
{
    if (source == NULL || destination == NULL || source->data == NULL || destination->data == NULL)
        return NO;
    if (source->width == 0 || source->height == 0 || source->width != destination->width || source->height != destination->height)
        return NO;
    if (source->rowBytes < source->width * 4 || destination->rowBytes < destination->width * 4)
        return NO;

    for (size_t y = 0; y < source->height; y++)
    {
        const uint8_t *input = (const uint8_t *)source->data + y * source->rowBytes;
        uint8_t *output = (uint8_t *)destination->data + y * destination->rowBytes;
        for (size_t x = 0; x < source->width; x++)
        {
            CGFloat b = input[x * 4 + 0];
            CGFloat g = input[x * 4 + 1];
            CGFloat r = input[x * 4 + 2];
            CGFloat a = input[x * 4 + 3];
            CGFloat luminance = 0.0722f * b + 0.7152f * g + 0.2126f * r;
            output[x * 4 + 0] = OGPlatformClampByte(luminance + (b - luminance) * saturation);
            output[x * 4 + 1] = OGPlatformClampByte(luminance + (g - luminance) * saturation);
            output[x * 4 + 2] = OGPlatformClampByte(luminance + (r - luminance) * saturation);
            output[x * 4 + 3] = (uint8_t)a;
        }
    }
    return YES;
}
