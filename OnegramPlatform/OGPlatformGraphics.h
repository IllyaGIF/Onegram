#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <stdint.h>

FOUNDATION_EXPORT CGFloat OGPlatformPixelFloor(CGFloat value);
FOUNDATION_EXPORT CGFloat OGPlatformPixelCeil(CGFloat value);
FOUNDATION_EXPORT CGFloat OGPlatformPixelRound(CGFloat value);
FOUNDATION_EXPORT BOOL OGPlatformLayerSupportsShadow(CALayer *layer);
FOUNDATION_EXPORT void OGPlatformSetLayerShadow(CALayer *layer, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset);
FOUNDATION_EXPORT BOOL OGPlatformGetLayerShadow(CALayer *layer, CGColorRef *color, CGFloat *opacity, CGFloat *radius, CGSize *offset);
FOUNDATION_EXPORT void OGPlatformSetLayerRasterization(CALayer *layer, BOOL rasterize, CGFloat scale);
FOUNDATION_EXPORT void OGPlatformApplyViewShadow(UIView *view, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset);
FOUNDATION_EXPORT void OGPlatformApplyRoundedViewShadow(UIView *view, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset, CGFloat cornerRadius);
FOUNDATION_EXPORT UIImage *OGPlatformImageWithShadow(UIImage *image, UIColor *color, CGFloat opacity, CGFloat radius, CGSize offset);
FOUNDATION_EXPORT void OGPlatformAddRoundedRectPath(CGContextRef context, CGRect rect, CGFloat radius);
FOUNDATION_EXPORT UIImage *OGPlatformRenderImage(CGSize size, CGFloat scale, BOOL opaque, void (^drawing)(CGContextRef context));
FOUNDATION_EXPORT void OGPlatformDrawImageInRect(CGContextRef context, UIImage *image, CGRect rect);
FOUNDATION_EXPORT void OGPlatformDrawVerticalGradient(CGContextRef context, CGRect rect, UIColor *topColor, UIColor *bottomColor);
FOUNDATION_EXPORT UIImage *OGPlatformImageFromData(NSData *data);
FOUNDATION_EXPORT UIImage *OGPlatformThumbnailFromImageData(NSData *data, CGSize maximumSize);
FOUNDATION_EXPORT UIImage *OGPlatformDecodeImageData(NSData *data, CGSize maximumPixelSize, NSInteger priority, bool (^isCancelled)(void));
FOUNDATION_EXPORT UIImage *OGPlatformDecodeImageWithBlock(UIImage *(^decode)(void), CGSize maximumPixelSize, NSInteger priority, bool (^isCancelled)(void));
FOUNDATION_EXPORT uint64_t OGPlatformActiveImageDecodes(void);
FOUNDATION_EXPORT uint64_t OGPlatformCachedGraphicsBytes(void);
FOUNDATION_EXPORT void OGPlatformTrimGraphicsCacheToCost(NSUInteger bytes);
FOUNDATION_EXPORT UIImage *OGPlatformThumbnailFromImageFile(NSString *path, size_t maximumPixelSize);
FOUNDATION_EXPORT CGSize OGPlatformImagePixelSizeFromData(NSData *data);
FOUNDATION_EXPORT NSData *OGPlatformJPEGRepresentation(UIImage *image, CGFloat quality);
FOUNDATION_EXPORT BOOL OGPlatformWriteJPEGRepresentationToFile(UIImage *image, CGFloat quality, NSString *path);

typedef struct
{
    void *data;
    size_t width;
    size_t height;
    size_t rowBytes;
} OGPlatformARGB8888Buffer;

FOUNDATION_EXPORT BOOL OGPlatformBoxConvolveARGB8888(const OGPlatformARGB8888Buffer *source, OGPlatformARGB8888Buffer *destination, size_t kernelWidth, size_t kernelHeight);
FOUNDATION_EXPORT BOOL OGPlatformSaturateBGRA8888(const OGPlatformARGB8888Buffer *source, OGPlatformARGB8888Buffer *destination, CGFloat saturation);
