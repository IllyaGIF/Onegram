#import "OGSurfaceRenderer.h"
#import "OGSurfaceStyle.h"
#import "OGAssets.h"
#import "../../OnegramPlatform/OGPlatformVersion.h"
#import "../../OnegramPlatform/OGPlatformGraphics.h"
#import "../../OnegramPlatform/OGMemoryCache.h"

#import <math.h>
#import <CommonCrypto/CommonDigest.h>
#import <stdlib.h>
#import <string.h>

typedef struct
{
    float red;
    float green;
    float blue;
    float alpha;
} OGSurfaceColor;

typedef struct
{
    NSInteger first;
    NSInteger count;
    float *weights;
} OGSurfaceKernel;

static const NSInteger OGSurfaceTextureDecodeOversampling = 2;

static OGSurfaceColor OGSurfaceColorFromUIColor(UIColor *color)
{
    OGSurfaceColor result = {0.0f, 0.0f, 0.0f, 0.0f};
    if (color == nil)
        return result;

    CGColorRef cgColor = color.CGColor;
    size_t count = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *components = CGColorGetComponents(cgColor);
    if (components == NULL)
        return result;

    if (count == 2)
    {
        result.red = (float)components[0];
        result.green = (float)components[0];
        result.blue = (float)components[0];
        result.alpha = (float)components[1];
    }
    else if (count >= 3)
    {
        result.red = (float)components[0];
        result.green = (float)components[1];
        result.blue = (float)components[2];
        result.alpha = count >= 4 ? (float)components[3] : 1.0f;
    }
    return result;
}

static float OGSurfaceClamp(float value)
{
    return value < 0.0f ? 0.0f : (value > 1.0f ? 1.0f : value);
}

static float OGSurfaceNormalCDF(float value)
{
    return 0.5f * erfcf(-value * 0.70710678f);
}

static OGSurfaceKernel OGSurfaceKernelMake(float displacement, float sigma)
{
    OGSurfaceKernel kernel;
    float reach = sigma * 3.0f + 1.0f;
    kernel.first = (NSInteger)floorf(displacement - reach);
    kernel.count = (NSInteger)ceilf(displacement + reach) - kernel.first + 1;
    kernel.weights = calloc((size_t)kernel.count, sizeof(float));

    float total = 0.0f;
    for (NSInteger index = 0; index < kernel.count; index++)
    {
        float position = (float)(kernel.first + index);
        float weight = 0.0f;
        if (sigma < 0.01f)
            weight = MAX(0.0f, 1.0f - fabsf(position - displacement));
        else
            weight = OGSurfaceNormalCDF((position + 0.5f - displacement) / sigma) - OGSurfaceNormalCDF((position - 0.5f - displacement) / sigma);
        kernel.weights[index] = weight;
        total += weight;
    }

    if (total > 0.0f)
    {
        for (NSInteger index = 0; index < kernel.count; index++)
            kernel.weights[index] /= total;
    }
    return kernel;
}

static void OGSurfaceConvolve(const float *source, NSInteger sourceStride, float *destination, NSInteger destinationStride, NSInteger length, float outside, OGSurfaceKernel kernel)
{
    for (NSInteger position = 0; position < length; position++)
    {
        float sum = 0.0f;
        for (NSInteger index = 0; index < kernel.count; index++)
        {
            NSInteger sourcePosition = position - (kernel.first + index);
            float value = (sourcePosition >= 0 && sourcePosition < length) ? source[sourcePosition * sourceStride] : outside;
            sum += kernel.weights[index] * value;
        }
        destination[position * destinationStride] = sum;
    }
}

static void OGSurfaceErode(float *values, NSInteger width, NSInteger height, BOOL horizontallyBounded, NSInteger radius)
{
    if (radius <= 0)
        return;

    NSInteger count = width * height;
    float *temporary = malloc((size_t)count * sizeof(float));
    for (NSInteger y = 0; y < height; y++)
    {
        for (NSInteger x = 0; x < width; x++)
        {
            float minimum = values[y * width + x];
            if (horizontallyBounded)
            {
                for (NSInteger offset = -radius; offset <= radius; offset++)
                {
                    NSInteger sampleX = x + offset;
                    minimum = MIN(minimum, (sampleX >= 0 && sampleX < width) ? values[y * width + sampleX] : 0.0f);
                }
            }
            temporary[y * width + x] = minimum;
        }
    }
    for (NSInteger y = 0; y < height; y++)
    {
        for (NSInteger x = 0; x < width; x++)
        {
            float minimum = temporary[y * width + x];
            for (NSInteger offset = -radius; offset <= radius; offset++)
            {
                NSInteger sampleY = y + offset;
                minimum = MIN(minimum, (sampleY >= 0 && sampleY < height) ? temporary[sampleY * width + x] : 0.0f);
            }
            values[y * width + x] = minimum;
        }
    }
    free(temporary);
}

static float *OGSurfaceShadowField(const float *mask, NSInteger width, NSInteger height, BOOL horizontallyBounded, OGSurfaceShadow *shadow, CGFloat scale)
{
    NSInteger count = width * height;
    float outside = shadow.inset ? 1.0f : 0.0f;
    float *source = malloc((size_t)count * sizeof(float));
    for (NSInteger index = 0; index < count; index++)
        source[index] = mask[index];
    if (shadow.inset)
        OGSurfaceErode(source, width, height, horizontallyBounded, (NSInteger)lroundf((float)(shadow.spread * scale)));
    for (NSInteger index = 0; index < count; index++)
        source[index] = shadow.inset ? 1.0f - source[index] : source[index];

    float sigma = (float)(shadow.blur * 0.5f * scale);
    float *horizontal = source;
    if (horizontallyBounded)
    {
        horizontal = malloc((size_t)count * sizeof(float));
        OGSurfaceKernel kernel = OGSurfaceKernelMake((float)(shadow.offset.width * scale), sigma);
        for (NSInteger row = 0; row < height; row++)
            OGSurfaceConvolve(source + row * width, 1, horizontal + row * width, 1, width, outside, kernel);
        free(kernel.weights);
        free(source);
    }

    float *field = malloc((size_t)count * sizeof(float));
    OGSurfaceKernel kernel = OGSurfaceKernelMake((float)(shadow.offset.height * scale), sigma);
    for (NSInteger column = 0; column < width; column++)
        OGSurfaceConvolve(horizontal + column, width, field + column, width, height, outside, kernel);
    free(kernel.weights);
    free(horizontal);
    return field;
}

static void OGSurfaceAddRoundedPolygon(CGContextRef context, const CGPoint *points, const CGFloat *radii, NSInteger count)
{
    CGPoint last = points[count - 1];
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, (last.x + points[0].x) * 0.5f, (last.y + points[0].y) * 0.5f);
    for (NSInteger index = 0; index < count; index++)
    {
        CGPoint point = points[index];
        CGPoint next = points[(index + 1) % count];
        CGContextAddArcToPoint(context, point.x, point.y, next.x, next.y, radii[index]);
    }
    CGContextClosePath(context);
}

static void OGSurfaceAddShapePath(CGContextRef context, OGSurfaceStyle *style, CGRect rect, CGFloat scale)
{
    CGFloat maximumRadius = MIN(rect.size.width, rect.size.height) * 0.5f;
    CGFloat cornerRadius = MIN(maximumRadius, style.cornerRadius * scale);
    if (style.shape == OGSurfaceShapeBackArrow)
    {
        CGFloat arrowWidth = MIN(rect.size.width - cornerRadius * 2.0f, style.arrowWidth * scale);
        CGPoint points[5] = {
            CGPointMake(CGRectGetMinX(rect), CGRectGetMidY(rect)),
            CGPointMake(CGRectGetMinX(rect) + arrowWidth, CGRectGetMinY(rect)),
            CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)),
            CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)),
            CGPointMake(CGRectGetMinX(rect) + arrowWidth, CGRectGetMaxY(rect))
        };
        CGFloat tipRadius = MIN(cornerRadius, style.arrowTipRadius * scale);
        CGFloat radii[5] = {tipRadius, cornerRadius, cornerRadius, cornerRadius, cornerRadius};
        OGSurfaceAddRoundedPolygon(context, points, radii, 5);
    }
    else if (style.shape == OGSurfaceShapeSheet || style.shape == OGSurfaceShapeSheetBottom)
    {
        CGPoint points[4] = {
            CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
            CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)),
            CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)),
            CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect))
        };
        CGFloat topRadius = style.shape == OGSurfaceShapeSheet ? cornerRadius : 0.0f;
        CGFloat bottomRadius = style.shape == OGSurfaceShapeSheetBottom ? cornerRadius : 0.0f;
        CGFloat radii[4] = {topRadius, topRadius, bottomRadius, bottomRadius};
        OGSurfaceAddRoundedPolygon(context, points, radii, 4);
    }
    else
        OGPlatformAddRoundedRectPath(context, rect, cornerRadius);
}

static void OGSurfaceAddBubbleTailPath(CGContextRef context, OGSurfaceStyle *style, CGRect bodyRect, CGFloat scale)
{
    BOOL right = style.shape == OGSurfaceShapeBubbleRight;
    CGFloat tailWidth = style.tailSize.width * scale;
    CGFloat tailHeight = style.tailSize.height * scale;
    CGFloat edgeX = right ? CGRectGetMaxX(bodyRect) : CGRectGetMinX(bodyRect);
    CGFloat direction = right ? 1.0f : -1.0f;
    CGFloat bottom = CGRectGetMaxY(bodyRect) - style.tailBottomInset * scale;
    CGFloat top = bottom - tailHeight;
    CGFloat half = tailWidth * 0.5f;

    CGContextBeginPath(context);
    CGContextMoveToPoint(context, edgeX, top);
    CGContextAddQuadCurveToPoint(context, edgeX, bottom - tailHeight * 0.15f, edgeX + direction * half, bottom);
    CGContextAddQuadCurveToPoint(context, edgeX + direction * half * 0.1f, bottom - tailHeight * 0.02f, edgeX - direction * half, bottom - tailHeight * 0.08f);
    CGContextAddLineToPoint(context, edgeX - direction * half, top);
    CGContextClosePath(context);
}

static float *OGSurfaceBoundedMask(OGSurfaceStyle *style, NSInteger width, NSInteger height, CGRect bodyRect, CGFloat scale)
{
    uint8_t *coverage = calloc((size_t)(width * height), 1);
    CGContextRef context = CGBitmapContextCreate(coverage, (size_t)width, (size_t)height, 8, (size_t)width, NULL, kCGImageAlphaOnly);
    float *mask = calloc((size_t)(width * height), sizeof(float));
    if (context != NULL)
    {
        CGContextTranslateCTM(context, 0.0f, (CGFloat)height);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        CGContextSetShouldAntialias(context, true);
        CGContextSetGrayFillColor(context, 1.0f, 1.0f);
        OGSurfaceAddShapePath(context, style, bodyRect, scale);
        CGContextFillPath(context);
        if (style.shape == OGSurfaceShapeBubbleLeft || style.shape == OGSurfaceShapeBubbleRight)
        {
            OGSurfaceAddBubbleTailPath(context, style, bodyRect, scale);
            CGContextFillPath(context);
        }
        CGContextRelease(context);
        for (NSInteger index = 0; index < width * height; index++)
            mask[index] = (float)coverage[index] / 255.0f;
    }
    free(coverage);
    return mask;
}

static float *OGSurfaceStrokeMask(OGSurfaceStyle *style, const float *mask, NSInteger width, NSInteger height, CGRect bodyRect, CGFloat scale)
{
    OGSurfaceStyle *innerStyle = [style copy];
    innerStyle.cornerRadius = MAX(0.0f, style.cornerRadius - style.strokeWidth);
    CGFloat inset = style.strokeWidth * scale;
    float *innerMask = OGSurfaceBoundedMask(innerStyle, width, height, CGRectInset(bodyRect, inset, inset), scale);
    float *strokeMask = calloc((size_t)(width * height), sizeof(float));
    for (NSInteger index = 0; index < width * height; index++)
        strokeMask[index] = MAX(0.0f, mask[index] - innerMask[index]);
    free(innerMask);
    return strokeMask;
}

static float *OGSurfaceBandMask(NSInteger height, CGRect bodyRect)
{
    float *mask = calloc((size_t)height, sizeof(float));
    float top = (float)CGRectGetMinY(bodyRect);
    float bottom = (float)CGRectGetMaxY(bodyRect);
    for (NSInteger row = 0; row < height; row++)
    {
        float rowTop = (float)row;
        mask[row] = MAX(0.0f, MIN(rowTop + 1.0f, bottom) - MAX(rowTop, top));
    }
    return mask;
}


static const int OGSurfaceRendererRevision = 3;
static const uint32_t OGSurfaceDiskImageMagic = 0x3253474fu;
static const size_t OGSurfaceDiskImageHeaderLength = 32;
static const uint32_t OGSurfaceDiskImageOpaqueFlag = 1u;

static NSString *OGSurfaceDiskCacheDirectory(void)
{
    static NSString *directory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *build = [NSString stringWithFormat:@"r%d-%@", OGSurfaceRendererRevision, [info objectForKey:@"CFBundleShortVersionString"] ?: @"0"];
        NSString *root = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"OGSurfaceCache"];
        directory = [root stringByAppendingPathComponent:[build description]];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *current = [build description];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
        {
            for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:NULL])
            {
                if (![name isEqualToString:current])
                    [[NSFileManager defaultManager] removeItemAtPath:[root stringByAppendingPathComponent:name] error:NULL];
            }
        });
    });
    return directory;
}

static NSString *OGSurfaceDiskCachePath(NSString *identity)
{
    NSData *data = [identity dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *name = [[NSMutableString alloc] initWithCapacity:CC_SHA1_DIGEST_LENGTH * 2 + 4];
    for (int index = 0; index < CC_SHA1_DIGEST_LENGTH; index++)
        [name appendFormat:@"%02x", digest[index]];
    [name appendString:@".px"];
    return [OGSurfaceDiskCacheDirectory() stringByAppendingPathComponent:name];
}

static void OGSurfaceReleaseMappedData(void *info, __unused const void *data, __unused size_t size)
{
    if (info != NULL)
        CFRelease(info);
}

static CGBitmapInfo OGSurfaceBitmapInfo(BOOL opaque)
{
    return (opaque ? kCGImageAlphaNoneSkipFirst : kCGImageAlphaPremultipliedFirst) | kCGBitmapByteOrder32Little;
}

static UIImage *OGSurfaceLoadDiskImage(NSString *path)
{
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
    if (data.length < OGSurfaceDiskImageHeaderLength)
        return nil;
    const uint32_t *header = (const uint32_t *)data.bytes;
    if (header[0] != OGSurfaceDiskImageMagic)
        return nil;
    size_t width = header[1];
    size_t height = header[2];
    CGFloat scale = (CGFloat)header[3] / 100.0f;
    BOOL opaque = (header[4] & OGSurfaceDiskImageOpaqueFlag) != 0;
    if (width == 0 || height == 0 || scale <= 0.0f || data.length != OGSurfaceDiskImageHeaderLength + width * height * 4)
        return nil;
    CGDataProviderRef provider = CGDataProviderCreateWithData((__bridge_retained void *)data, (const uint8_t *)data.bytes + OGSurfaceDiskImageHeaderLength, width * height * 4, OGSurfaceReleaseMappedData);
    if (provider == NULL)
        return nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(width, height, 8, 32, width * 4, colorSpace, OGSurfaceBitmapInfo(opaque), provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    if (cgImage == NULL)
        return nil;
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return image;
}

static void OGSurfaceStoreDiskImage(UIImage *image, NSString *path)
{
    CGImageRef cgImage = image.CGImage;
    if (cgImage == NULL)
        return;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0)
        return;
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgImage);
    BOOL opaque = alphaInfo == kCGImageAlphaNone || alphaInfo == kCGImageAlphaNoneSkipFirst || alphaInfo == kCGImageAlphaNoneSkipLast;
    NSMutableData *data = [[NSMutableData alloc] initWithLength:OGSurfaceDiskImageHeaderLength + width * height * 4];
    uint32_t *header = (uint32_t *)data.mutableBytes;
    header[0] = OGSurfaceDiskImageMagic;
    header[1] = (uint32_t)width;
    header[2] = (uint32_t)height;
    header[3] = (uint32_t)lroundf((float)image.scale * 100.0f);
    header[4] = opaque ? OGSurfaceDiskImageOpaqueFlag : 0u;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate((uint8_t *)data.mutableBytes + OGSurfaceDiskImageHeaderLength, width, height, 8, width * 4, colorSpace, OGSurfaceBitmapInfo(opaque));
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return;
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height), cgImage);
    CGContextRelease(context);
    [data writeToFile:path atomically:YES];
}

static dispatch_queue_t OGSurfaceDiskQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.surface-disk", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    });
    return queue;
}

static UIImage *OGSurfaceImageFromPixels(uint8_t *pixels, NSInteger width, NSInteger height, CGFloat scale, BOOL opaque)
{
    if (pixels == NULL || width <= 0 || height <= 0)
        return nil;

    size_t bytesPerRow = (size_t)width * 4;
    NSData *pixelData = [[NSData alloc] initWithBytes:pixels length:bytesPerRow * (size_t)height];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixelData);
    if (provider == NULL)
        return nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate((size_t)width, (size_t)height, 8, 32, bytesPerRow, colorSpace, kCGBitmapByteOrderDefault | (opaque ? kCGImageAlphaNoneSkipLast : kCGImageAlphaPremultipliedLast), provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    if (cgImage == NULL)
        return nil;

    UIImage *image = [UIImage imageWithCGImage:cgImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return image;
}

static OGSurfaceColor OGSurfaceGradientColor(const OGSurfaceColor *colors, const float *locations, NSInteger count, float position)
{
    if (count == 0)
    {
        OGSurfaceColor empty = {0.0f, 0.0f, 0.0f, 0.0f};
        return empty;
    }
    if (position <= locations[0])
        return colors[0];
    for (NSInteger index = 1; index < count; index++)
    {
        if (position <= locations[index])
        {
            float span = locations[index] - locations[index - 1];
            float fraction = span > 0.0f ? (position - locations[index - 1]) / span : 1.0f;
            OGSurfaceColor color;
            color.red = colors[index - 1].red + (colors[index].red - colors[index - 1].red) * fraction;
            color.green = colors[index - 1].green + (colors[index].green - colors[index - 1].green) * fraction;
            color.blue = colors[index - 1].blue + (colors[index].blue - colors[index - 1].blue) * fraction;
            color.alpha = colors[index - 1].alpha + (colors[index].alpha - colors[index - 1].alpha) * fraction;
            return color;
        }
    }
    return colors[count - 1];
}

typedef struct
{
    float red;
    float green;
    float blue;
    float alpha;
} OGSurfacePremultipliedColor;

typedef struct
{
    float *mask;
    NSInteger shadowCount;
    float **shadowFields;
    OGSurfaceColor *shadowColors;
    NSInteger stopCount;
    OGSurfaceColor *stopColors;
    float *stopLocations;
    float originX;
    float originY;
    float directionX;
    float directionY;
    float length;
    BOOL conic;
    float conicStart;
    OGSurfaceBlendMode blendMode;
} OGSurfaceRenderedLayer;

static float OGSurfaceBlendChannel(float backdrop, float source, OGSurfaceBlendMode blendMode)
{
    switch (blendMode)
    {
        case OGSurfaceBlendModeHardLight:
            if (source <= 0.5f)
                return backdrop * 2.0f * source;
            return 1.0f - (1.0f - backdrop) * (1.0f - (2.0f * source - 1.0f));
        case OGSurfaceBlendModeSoftLight:
        {
            if (source <= 0.5f)
                return backdrop - (1.0f - 2.0f * source) * backdrop * (1.0f - backdrop);
            float d = backdrop <= 0.25f ? ((16.0f * backdrop - 12.0f) * backdrop + 4.0f) * backdrop : sqrtf(backdrop);
            return backdrop + (2.0f * source - 1.0f) * (d - backdrop);
        }
        default:
            return source;
    }
}

static OGSurfacePremultipliedColor OGSurfaceComposite(OGSurfacePremultipliedColor backdrop, OGSurfaceColor source, float sourceAlpha, OGSurfaceBlendMode blendMode)
{
    if (sourceAlpha <= 0.0f)
        return backdrop;

    float red = source.red;
    float green = source.green;
    float blue = source.blue;
    if (blendMode != OGSurfaceBlendModeNormal && backdrop.alpha > 0.0f)
    {
        float backdropRed = backdrop.red / backdrop.alpha;
        float backdropGreen = backdrop.green / backdrop.alpha;
        float backdropBlue = backdrop.blue / backdrop.alpha;
        red = (1.0f - backdrop.alpha) * red + backdrop.alpha * OGSurfaceBlendChannel(backdropRed, red, blendMode);
        green = (1.0f - backdrop.alpha) * green + backdrop.alpha * OGSurfaceBlendChannel(backdropGreen, green, blendMode);
        blue = (1.0f - backdrop.alpha) * blue + backdrop.alpha * OGSurfaceBlendChannel(backdropBlue, blue, blendMode);
    }

    OGSurfacePremultipliedColor result;
    result.red = red * sourceAlpha + backdrop.red * (1.0f - sourceAlpha);
    result.green = green * sourceAlpha + backdrop.green * (1.0f - sourceAlpha);
    result.blue = blue * sourceAlpha + backdrop.blue * (1.0f - sourceAlpha);
    result.alpha = sourceAlpha + backdrop.alpha * (1.0f - sourceAlpha);
    return result;
}

static float *OGSurfaceRoundedRectMask(NSInteger width, NSInteger height, CGRect rect, CGFloat radius, BOOL elliptical)
{
    uint8_t *coverage = calloc((size_t)(width * height), 1);
    float *mask = calloc((size_t)(width * height), sizeof(float));
    CGContextRef context = CGBitmapContextCreate(coverage, (size_t)width, (size_t)height, 8, (size_t)width, NULL, kCGImageAlphaOnly);
    if (context != NULL)
    {
        CGContextTranslateCTM(context, 0.0f, (CGFloat)height);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        CGContextSetShouldAntialias(context, true);
        CGContextSetGrayFillColor(context, 1.0f, 1.0f);
        if (elliptical)
            CGContextAddEllipseInRect(context, rect);
        else
            OGPlatformAddRoundedRectPath(context, rect, MIN(radius, MIN(rect.size.width, rect.size.height) * 0.5f));
        CGContextFillPath(context);
        CGContextRelease(context);
        for (NSInteger index = 0; index < width * height; index++)
            mask[index] = (float)coverage[index] / 255.0f;
    }
    free(coverage);
    return mask;
}

static OGSurfaceRenderedLayer OGSurfaceRenderLayer(OGSurfaceLayer *layer, CGSize bodySize, CGPoint bodyOrigin, NSInteger width, NSInteger height, CGFloat scale)
{
    OGSurfaceRenderedLayer rendered;
    memset(&rendered, 0, sizeof(rendered));

    CGRect frame = [layer frameInBodySize:bodySize];
    CGRect rect = CGRectMake(bodyOrigin.x + frame.origin.x * scale, bodyOrigin.y + frame.origin.y * scale, frame.size.width * scale, frame.size.height * scale);
    rendered.mask = OGSurfaceRoundedRectMask(width, height, rect, layer.cornerRadius * scale, layer.elliptical);
    rendered.blendMode = layer.blendMode;

    NSArray *colors = layer.colors;
    NSArray *locations = layer.locations;
    rendered.stopCount = (NSInteger)MIN([colors count], [locations count]);
    rendered.stopColors = calloc((size_t)MAX(1, rendered.stopCount), sizeof(OGSurfaceColor));
    rendered.stopLocations = calloc((size_t)MAX(1, rendered.stopCount), sizeof(float));
    for (NSInteger index = 0; index < rendered.stopCount; index++)
    {
        rendered.stopColors[index] = OGSurfaceColorFromUIColor(colors[(NSUInteger)index]);
        rendered.stopLocations[index] = [locations[(NSUInteger)index] floatValue];
    }

    float angle = (float)layer.gradientAngle * (float)M_PI / 180.0f;
    rendered.directionX = sinf(angle);
    rendered.directionY = -cosf(angle);
    rendered.length = MAX(1.0f, fabsf((float)rect.size.width * rendered.directionX) + fabsf((float)rect.size.height * rendered.directionY));
    rendered.originX = (float)CGRectGetMidX(rect);
    rendered.originY = (float)CGRectGetMidY(rect);
    rendered.conic = layer.conicGradient;
    rendered.conicStart = angle;

    NSArray *shadows = layer.shadows;
    rendered.shadowCount = (NSInteger)[shadows count];
    rendered.shadowFields = calloc((size_t)MAX(1, rendered.shadowCount), sizeof(float *));
    rendered.shadowColors = calloc((size_t)MAX(1, rendered.shadowCount), sizeof(OGSurfaceColor));
    for (NSInteger index = 0; index < rendered.shadowCount; index++)
    {
        OGSurfaceShadow *shadow = shadows[(NSUInteger)index];
        rendered.shadowFields[index] = OGSurfaceShadowField(rendered.mask, width, height, YES, shadow, scale);
        rendered.shadowColors[index] = OGSurfaceColorFromUIColor(shadow.color);
    }
    return rendered;
}

static void OGSurfaceReleaseRenderedLayer(OGSurfaceRenderedLayer *rendered)
{
    for (NSInteger index = 0; index < rendered->shadowCount; index++)
        free(rendered->shadowFields[index]);
    free(rendered->shadowFields);
    free(rendered->shadowColors);
    free(rendered->stopColors);
    free(rendered->stopLocations);
    free(rendered->mask);
}

static OGSurfacePremultipliedColor OGSurfaceApplyLayer(OGSurfacePremultipliedColor body, const OGSurfaceRenderedLayer *layer, NSInteger x, NSInteger y, NSInteger pixelIndex)
{
    float coverage = layer->mask[pixelIndex];
    if (coverage <= 0.0f)
        return body;

    if (layer->stopCount > 0)
    {
        float position = 0.0f;
        if (layer->conic)
        {
            float sweep = atan2f((float)x + 0.5f - layer->originX, layer->originY - ((float)y + 0.5f)) - layer->conicStart;
            float turn = 2.0f * (float)M_PI;
            position = fmodf(fmodf(sweep, turn) + turn, turn) / turn;
        }
        else
            position = (((float)x + 0.5f - layer->originX) * layer->directionX + ((float)y + 0.5f - layer->originY) * layer->directionY) / layer->length + 0.5f;
        OGSurfaceColor color = OGSurfaceGradientColor(layer->stopColors, layer->stopLocations, layer->stopCount, OGSurfaceClamp(position));
        body = OGSurfaceComposite(body, color, OGSurfaceClamp(color.alpha * coverage), layer->blendMode);
    }

    for (NSInteger index = layer->shadowCount - 1; index >= 0; index--)
    {
        OGSurfaceColor shadowColor = layer->shadowColors[index];
        body = OGSurfaceComposite(body, shadowColor, OGSurfaceClamp(shadowColor.alpha * layer->shadowFields[index][pixelIndex] * coverage), OGSurfaceBlendModeNormal);
    }
    return body;
}

static uint8_t OGSurfaceByte(float value)
{
    return (uint8_t)(OGSurfaceClamp(value) * 255.0f + 0.5f);
}

typedef struct
{
    BOOL bounded;
    NSInteger width;
    const float *mask;
    NSInteger shadowCount;
    float **fields;
    const OGSurfaceColor *shadowColors;
    const BOOL *shadowInsets;
    const float *strokeMask;
    const OGSurfaceColor *strokeColors;
    const float *strokeLocations;
    NSInteger strokeStopCount;
    float bodyTop;
    float bodyHeight;
    NSInteger layerCount;
    const OGSurfaceRenderedLayer *layers;
    BOOL textured;
    float textureCurve[3][256];
    OGSurfaceColor fill;
    OGSurfaceColor overlay;
    float opacity;
} OGSurfaceShading;

typedef struct
{
    BOOL valid;
    float scale;
    float offsets[3];
    uint8_t values[3][256];
} OGSurfaceBandLookup;

static void OGSurfaceShadePixel(const OGSurfaceShading *shading, NSInteger x, NSInteger y, const uint8_t *texel, uint8_t *pixel)
{
    NSInteger pixelIndex = y * shading->width + x;
    NSInteger fieldIndex = shading->bounded ? pixelIndex : y;
    float coverage = shading->mask[fieldIndex];
    NSInteger shadowCount = shading->shadowCount;

    OGSurfacePremultipliedColor body = {0.0f, 0.0f, 0.0f, 0.0f};
    if (coverage > 0.0f)
    {
        if (shading->textured && texel != NULL)
        {
            body.red = shading->textureCurve[0][texel[0]];
            body.green = shading->textureCurve[1][texel[1]];
            body.blue = shading->textureCurve[2][texel[2]];
            body.alpha = 1.0f;
        }
        else
        {
            body.red = shading->fill.red * shading->fill.alpha;
            body.green = shading->fill.green * shading->fill.alpha;
            body.blue = shading->fill.blue * shading->fill.alpha;
            body.alpha = shading->fill.alpha;
        }

        body = OGSurfaceComposite(body, shading->overlay, shading->overlay.alpha, OGSurfaceBlendModeNormal);

        for (NSInteger index = 0; index < shading->layerCount; index++)
            body = OGSurfaceApplyLayer(body, &shading->layers[index], x, y, pixelIndex);

        for (NSInteger index = shadowCount - 1; index >= 0; index--)
        {
            if (!shading->shadowInsets[index])
                continue;
            body = OGSurfaceComposite(body, shading->shadowColors[index], OGSurfaceClamp(shading->shadowColors[index].alpha * shading->fields[index][fieldIndex]), OGSurfaceBlendModeNormal);
        }

        if (shading->strokeMask != NULL && shading->strokeMask[pixelIndex] > 0.0f)
        {
            float position = shading->bodyHeight > 0.0f ? ((float)y + 0.5f - shading->bodyTop) / shading->bodyHeight : 0.0f;
            OGSurfaceColor strokeColor = OGSurfaceGradientColor(shading->strokeColors, shading->strokeLocations, shading->strokeStopCount, OGSurfaceClamp(position));
            body = OGSurfaceComposite(body, strokeColor, OGSurfaceClamp(strokeColor.alpha * shading->strokeMask[pixelIndex] / coverage), OGSurfaceBlendModeNormal);
        }
    }

    OGSurfacePremultipliedColor under = {0.0f, 0.0f, 0.0f, 0.0f};
    float bodyAlpha = coverage * body.alpha;
    if (coverage < 1.0f)
    {
        for (NSInteger index = shadowCount - 1; index >= 0; index--)
        {
            if (shading->shadowInsets[index])
                continue;
            under = OGSurfaceComposite(under, shading->shadowColors[index], OGSurfaceClamp(shading->shadowColors[index].alpha * shading->fields[index][fieldIndex]), OGSurfaceBlendModeNormal);
        }
    }

    float outside = 1.0f - coverage;
    float opacity = shading->opacity;
    pixel[0] = OGSurfaceByte((body.red * coverage + under.red * outside) * opacity);
    pixel[1] = OGSurfaceByte((body.green * coverage + under.green * outside) * opacity);
    pixel[2] = OGSurfaceByte((body.blue * coverage + under.blue * outside) * opacity);
    pixel[3] = OGSurfaceByte((bodyAlpha + under.alpha * outside) * opacity);
}

static BOOL OGSurfaceShadeBandRow(const OGSurfaceShading *shading, OGSurfaceBandLookup *lookup, NSInteger y, const uint8_t *textureRow, NSInteger textureStartX, NSInteger textureWidth, uint8_t *row)
{
    NSInteger width = shading->width;
    float coverage = shading->mask[y];
    if (textureRow == NULL || coverage <= 0.0f)
    {
        OGSurfaceShadePixel(shading, 0, y, textureRow != NULL ? textureRow + textureStartX * 4 : NULL, row);
        uint32_t value;
        memcpy(&value, row, 4);
        for (NSInteger x = 1; x < width; x++)
            memcpy(row + x * 4, &value, 4);
        return row[3] == 255;
    }

    float scale = 1.0f;
    float offsets[3] = {0.0f, 0.0f, 0.0f};
    OGSurfaceColor overlay = shading->overlay;
    if (overlay.alpha > 0.0f)
    {
        scale *= 1.0f - overlay.alpha;
        offsets[0] = overlay.red * overlay.alpha;
        offsets[1] = overlay.green * overlay.alpha;
        offsets[2] = overlay.blue * overlay.alpha;
    }
    for (NSInteger index = shading->shadowCount - 1; index >= 0; index--)
    {
        if (!shading->shadowInsets[index])
            continue;
        OGSurfaceColor color = shading->shadowColors[index];
        float alpha = OGSurfaceClamp(color.alpha * shading->fields[index][y]);
        if (alpha <= 0.0f)
            continue;
        scale *= 1.0f - alpha;
        offsets[0] = color.red * alpha + offsets[0] * (1.0f - alpha);
        offsets[1] = color.green * alpha + offsets[1] * (1.0f - alpha);
        offsets[2] = color.blue * alpha + offsets[2] * (1.0f - alpha);
    }

    OGSurfacePremultipliedColor under = {0.0f, 0.0f, 0.0f, 0.0f};
    if (coverage < 1.0f)
    {
        for (NSInteger index = shading->shadowCount - 1; index >= 0; index--)
        {
            if (shading->shadowInsets[index])
                continue;
            under = OGSurfaceComposite(under, shading->shadowColors[index], OGSurfaceClamp(shading->shadowColors[index].alpha * shading->fields[index][y]), OGSurfaceBlendModeNormal);
        }
    }

    float outside = 1.0f - coverage;
    float opacity = shading->opacity;
    float rowScale = scale * coverage * opacity;
    float rowOffsets[3] = {
        (offsets[0] * coverage + under.red * outside) * opacity,
        (offsets[1] * coverage + under.green * outside) * opacity,
        (offsets[2] * coverage + under.blue * outside) * opacity
    };
    if (!lookup->valid || lookup->scale != rowScale || lookup->offsets[0] != rowOffsets[0] || lookup->offsets[1] != rowOffsets[1] || lookup->offsets[2] != rowOffsets[2])
    {
        for (NSInteger channel = 0; channel < 3; channel++)
        {
            for (NSInteger value = 0; value < 256; value++)
                lookup->values[channel][value] = OGSurfaceByte(shading->textureCurve[channel][value] * rowScale + rowOffsets[channel]);
        }
        lookup->scale = rowScale;
        lookup->offsets[0] = rowOffsets[0];
        lookup->offsets[1] = rowOffsets[1];
        lookup->offsets[2] = rowOffsets[2];
        lookup->valid = YES;
    }

    uint8_t alpha = OGSurfaceByte((coverage + under.alpha * outside) * opacity);
    const uint8_t *redValues = lookup->values[0];
    const uint8_t *greenValues = lookup->values[1];
    const uint8_t *blueValues = lookup->values[2];
    NSInteger textureX = textureStartX;
    for (NSInteger x = 0; x < width; x++)
    {
        const uint8_t *texel = textureRow + textureX * 4;
        uint8_t *pixel = row + x * 4;
        pixel[0] = redValues[texel[0]];
        pixel[1] = greenValues[texel[1]];
        pixel[2] = blueValues[texel[2]];
        pixel[3] = alpha;
        if (++textureX == textureWidth)
            textureX = 0;
    }
    return alpha == 255;
}

@interface OGSurfaceTexture : NSObject
@property (nonatomic, retain) NSData *pixels;
@property (nonatomic) NSInteger width;
@property (nonatomic) NSInteger height;
@end

@implementation OGSurfaceTexture
@end

@interface OGAssets (OGSurfaceTexturePath)
- (NSString *)pathForImageNamed:(NSString *)name inDirectory:(NSString *)directory scale:(CGFloat *)scale;
@end

static OGSurfaceTexture *OGSurfaceLoadDiskTexture(NSString *path, NSInteger pixelWidth)
{
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
    if (data.length < 16)
        return nil;
    uint32_t trailer[4];
    memcpy(trailer, (const uint8_t *)data.bytes + data.length - 16, 16);
    if (trailer[0] != 0x3154474fu || (NSInteger)trailer[1] != pixelWidth || trailer[2] == 0)
        return nil;
    if ((NSUInteger)trailer[1] * (NSUInteger)trailer[2] * 4 + 16 != data.length)
        return nil;
    OGSurfaceTexture *texture = [[OGSurfaceTexture alloc] init];
    texture.pixels = data;
    texture.width = (NSInteger)trailer[1];
    texture.height = (NSInteger)trailer[2];
    return texture;
}

static void OGSurfaceStoreDiskTexture(OGSurfaceTexture *texture, NSString *path)
{
    NSUInteger length = (NSUInteger)(texture.width * texture.height * 4);
    if (texture.pixels.length < length || length == 0)
        return;
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:length + 16];
    [data appendBytes:texture.pixels.bytes length:length];
    uint32_t trailer[4] = { 0x3154474fu, (uint32_t)texture.width, (uint32_t)texture.height, 0 };
    [data appendBytes:trailer length:sizeof(trailer)];
    [data writeToFile:path atomically:true];
}

typedef enum {
    OGSurfaceRenderKeyKindStyle = 0,
    OGSurfaceRenderKeyKindGlyph = 1,
    OGSurfaceRenderKeyKindIcon = 2,
    OGSurfaceRenderKeyKindTextGlyph = 3
} OGSurfaceRenderKeyKind;

@interface OGSurfaceRenderKey : NSObject <NSCopying>
{
    OGSurfaceRenderKeyKind _kind;
    NSArray *_objects;
    CGFloat _values[8];
    NSUInteger _valueCount;
    NSUInteger _hash;
}
- (instancetype)initWithKind:(OGSurfaceRenderKeyKind)kind objects:(NSArray *)objects values:(const CGFloat *)values count:(NSUInteger)count;
@end

@implementation OGSurfaceRenderKey

- (instancetype)initWithKind:(OGSurfaceRenderKeyKind)kind objects:(NSArray *)objects values:(const CGFloat *)values count:(NSUInteger)count
{
    self = [super init];
    if (self != nil)
    {
        _kind = kind;
        _objects = [objects copy];
        _valueCount = MIN(count, (NSUInteger)8);
        NSUInteger hash = (NSUInteger)kind;
        for (id object in objects)
            hash = hash * 31u + [object hash];
        for (NSUInteger index = 0; index < _valueCount; index++)
        {
            _values[index] = values[index];
            hash = hash * 31u + (NSUInteger)(NSInteger)lroundf((float)values[index] * 100.0f);
        }
        _hash = hash;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSUInteger)hash
{
    return _hash;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[OGSurfaceRenderKey class]])
        return NO;
    OGSurfaceRenderKey *other = object;
    if (other->_hash != _hash || other->_kind != _kind || other->_valueCount != _valueCount)
        return NO;
    for (NSUInteger index = 0; index < _valueCount; index++)
    {
        if (other->_values[index] != _values[index])
            return NO;
    }
    return [other->_objects isEqualToArray:_objects];
}

@end

static NSUInteger OGSurfaceCacheBudget(unsigned long long divisor, NSUInteger minimum, NSUInteger maximum)
{
    unsigned long long budget = [[NSProcessInfo processInfo] physicalMemory] / divisor;
    if (budget < minimum)
        return minimum;
    if (budget > maximum)
        return maximum;
    return (NSUInteger)budget;
}

static NSUInteger OGSurfaceImageCost(UIImage *image)
{
    CGImageRef cgImage = image.CGImage;
    if (cgImage == NULL)
        return 1;
    return MAX((NSUInteger)1, (NSUInteger)(CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage)));
}

static NSString *OGSurfaceImageContentIdentity(UIImage *image)
{
    CGImageRef cgImage = image.CGImage;
    if (cgImage == NULL)
        return nil;
    CGDataProviderRef provider = CGImageGetDataProvider(cgImage);
    if (provider == NULL)
        return nil;
    CFDataRef data = CGDataProviderCopyData(provider);
    if (data == NULL)
        return nil;
    CC_SHA1_CTX context;
    CC_SHA1_Init(&context);
    CC_SHA1_Update(&context, CFDataGetBytePtr(data), (CC_LONG)CFDataGetLength(data));
    uint32_t geometry[6] = {(uint32_t)CGImageGetWidth(cgImage), (uint32_t)CGImageGetHeight(cgImage), (uint32_t)CGImageGetBitsPerPixel(cgImage), (uint32_t)CGImageGetBytesPerRow(cgImage), (uint32_t)CGImageGetBitmapInfo(cgImage), (uint32_t)lroundf((float)image.scale * 100.0f)};
    CC_SHA1_Update(&context, geometry, (CC_LONG)sizeof(geometry));
    CFRelease(data);
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_Final(digest, &context);
    NSMutableString *identity = [[NSMutableString alloc] initWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int index = 0; index < CC_SHA1_DIGEST_LENGTH; index++)
        [identity appendFormat:@"%02x", digest[index]];
    return identity;
}

@interface OGSurfaceRenderer ()
{
    OGAssets *_assets;
    OGMemoryCache *_imageCache;
    OGMemoryCache *_textureCache;
    OGMemoryCache *_textureAspects;
    NSCondition *_renderCondition;
    NSMutableSet *_renderingKeys;
}
@end

@implementation OGSurfaceRenderer

- (instancetype)initWithAssets:(OGAssets *)assets
{
    self = [super init];
    if (self != nil)
    {
        _assets = assets;
        _imageCache = [[OGMemoryCache alloc] initWithCountLimit:512 costLimit:OGSurfaceCacheBudget(24, 6u * 1024u * 1024u, 40u * 1024u * 1024u)];
        _textureCache = [[OGMemoryCache alloc] initWithCountLimit:128 costLimit:OGSurfaceCacheBudget(64, 2u * 1024u * 1024u, 16u * 1024u * 1024u)];
        _textureAspects = [[OGMemoryCache alloc] initWithCountLimit:128 costLimit:64 * 1024];
        _renderCondition = [[NSCondition alloc] init];
        _renderingKeys = [[NSMutableSet alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)didReceiveMemoryWarning:(NSNotification *)__unused notification
{
    [_imageCache removeAllObjects];
    [_textureCache removeAllObjects];
}

static NSString *OGSurfaceTextureContentsRectIdentity(CGRect rect)
{
    return [NSString stringWithFormat:@"%.4f,%.4f,%.4f,%.4f", (double)rect.origin.x, (double)rect.origin.y, (double)rect.size.width, (double)rect.size.height];
}

static CGRect OGSurfaceTextureContentsRect(OGSurfaceStyle *style)
{
    CGRect rect = CGRectIntersection(style.textureContentsRect, CGRectMake(0.0f, 0.0f, 1.0f, 1.0f));
    if (CGRectIsNull(rect) || rect.size.width <= 0.0f || rect.size.height <= 0.0f)
        return CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    return rect;
}

- (CGFloat)textureAspectForStyle:(OGSurfaceStyle *)style
{
    if ([style.textureAssetName length] == 0)
        return 0.0f;

    CGRect contentsRect = OGSurfaceTextureContentsRect(style);
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@", style.textureResourceDirectory ?: @"", style.textureAssetName, OGSurfaceTextureContentsRectIdentity(contentsRect)];
    NSNumber *aspect = [_textureAspects objectForKey:key];
    if (aspect == nil)
    {
        UIImage *image = [_assets uncachedImageNamed:style.textureAssetName inDirectory:style.textureResourceDirectory];
        CGImageRef cgImage = image.CGImage;
        CGFloat value = (cgImage != NULL && CGImageGetHeight(cgImage) != 0) ? ((CGFloat)CGImageGetWidth(cgImage) * contentsRect.size.width) / ((CGFloat)CGImageGetHeight(cgImage) * contentsRect.size.height) : 0.0f;
        aspect = @(value);
        [_textureAspects setObject:aspect forKey:key cost:64];
    }
    return (CGFloat)[aspect doubleValue];
}

- (OGSurfaceTexture *)textureForStyle:(OGSurfaceStyle *)style pixelWidth:(NSInteger)pixelWidth
{
    if ([style.textureAssetName length] == 0 || pixelWidth <= 0)
        return nil;

    CGRect contentsRect = OGSurfaceTextureContentsRect(style);
    NSString *contentsIdentity = OGSurfaceTextureContentsRectIdentity(contentsRect);
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@|%ld", style.textureResourceDirectory ?: @"", style.textureAssetName, contentsIdentity, (long)pixelWidth];
    OGSurfaceTexture *texture = [_textureCache objectForKey:key];
    if (texture != nil)
        return texture;

    NSString *assetPath = [_assets pathForImageNamed:style.textureAssetName inDirectory:style.textureResourceDirectory scale:NULL];
    NSString *texturePath = nil;
    if ([assetPath length] != 0)
    {
        unsigned long long assetSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:assetPath error:NULL] fileSize];
        texturePath = OGSurfaceDiskCachePath([NSString stringWithFormat:@"texture|%@|%@|%llu|%@|%ld", style.textureResourceDirectory ?: @"", [assetPath lastPathComponent], assetSize, contentsIdentity, (long)pixelWidth]);
        texture = OGSurfaceLoadDiskTexture(texturePath, pixelWidth);
        if (texture != nil)
        {
            [self rememberTexture:texture forKey:key];
            return texture;
        }
    }

    CGFloat aspect = [self textureAspectForStyle:style];
    if (aspect <= 0.0f)
        return nil;
    NSInteger expectedHeight = MAX(1, (NSInteger)lroundf((float)pixelWidth / (float)aspect));
    CGFloat sourceExtent = MAX((CGFloat)pixelWidth / contentsRect.size.width, (CGFloat)expectedHeight / contentsRect.size.height);
    size_t decodePixelSize = (size_t)(ceilf((float)sourceExtent) * OGSurfaceTextureDecodeOversampling);
    UIImage *image = [_assets uncachedImageNamed:style.textureAssetName inDirectory:style.textureResourceDirectory maximumPixelSize:decodePixelSize];
    CGImageRef sourceImage = image.CGImage;
    if (sourceImage == NULL || CGImageGetWidth(sourceImage) == 0 || CGImageGetHeight(sourceImage) == 0)
        return nil;

    CGFloat sourceWidth = (CGFloat)CGImageGetWidth(sourceImage);
    CGFloat sourceHeight = (CGFloat)CGImageGetHeight(sourceImage);
    CGImageRef cgImage = CGImageCreateWithImageInRect(sourceImage, CGRectIntegral(CGRectMake(contentsRect.origin.x * sourceWidth, contentsRect.origin.y * sourceHeight, contentsRect.size.width * sourceWidth, contentsRect.size.height * sourceHeight)));
    if (cgImage == NULL || CGImageGetWidth(cgImage) == 0 || CGImageGetHeight(cgImage) == 0)
    {
        if (cgImage != NULL)
            CGImageRelease(cgImage);
        return nil;
    }

    NSInteger pixelHeight = MAX(1, (NSInteger)lroundf((float)pixelWidth * (float)CGImageGetHeight(cgImage) / (float)CGImageGetWidth(cgImage)));
    NSMutableData *pixels = [[NSMutableData alloc] initWithLength:(NSUInteger)(pixelWidth * pixelHeight * 4)];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate([pixels mutableBytes], (size_t)pixelWidth, (size_t)pixelHeight, 8, (size_t)(pixelWidth * 4), colorSpace, kCGImageAlphaNoneSkipLast);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
    {
        CGImageRelease(cgImage);
        return nil;
    }
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, (CGFloat)pixelWidth, (CGFloat)pixelHeight), cgImage);
    CGContextRelease(context);
    CGImageRelease(cgImage);

    texture = [[OGSurfaceTexture alloc] init];
    texture.pixels = pixels;
    texture.width = pixelWidth;
    texture.height = pixelHeight;

    if (texturePath != nil)
    {
        OGSurfaceTexture *storedTexture = texture;
        dispatch_async(OGSurfaceDiskQueue(), ^
        {
            @autoreleasepool
            {
                OGSurfaceStoreDiskTexture(storedTexture, texturePath);
            }
        });
    }

    [self rememberTexture:texture forKey:key];
    return texture;
}

- (void)rememberTexture:(OGSurfaceTexture *)texture forKey:(NSString *)key
{
    [_textureCache setObject:texture forKey:key cost:MAX((NSUInteger)1, texture.pixels.length)];
}

- (UIImage *)imageWithStyle:(OGSurfaceStyle *)style size:(CGSize)size bodyFrame:(CGRect)bodyFrame
{
    if (style == nil || size.width <= 0.0f || size.height <= 0.0f)
        return nil;

    CGFloat scale = OGPlatformScreenScale();
    NSString *identity = [style renderIdentity];
    CGFloat values[7] = {size.width, size.height, bodyFrame.origin.x, bodyFrame.origin.y, bodyFrame.size.width, bodyFrame.size.height, scale};
    OGSurfaceRenderKey *key = [[OGSurfaceRenderKey alloc] initWithKind:OGSurfaceRenderKeyKindStyle objects:@[identity] values:values count:7];
    NSString *diskIdentity = [NSString stringWithFormat:@"%@|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f|%.1f", identity, size.width, size.height, bodyFrame.origin.x, bodyFrame.origin.y, bodyFrame.size.width, bodyFrame.size.height, scale];
    return [self cachedImageForKey:key diskIdentity:diskIdentity render:^UIImage *
    {
        return [self renderImageWithStyle:style size:size bodyFrame:bodyFrame scale:scale];
    }];
}

- (UIImage *)cachedImageForKey:(OGSurfaceRenderKey *)key diskIdentity:(NSString *)diskIdentity render:(UIImage *(^)(void))render
{
    UIImage *cachedImage = [_imageCache objectForKey:key];
    if (cachedImage != nil)
        return cachedImage;

    [_renderCondition lock];
    while ([_renderingKeys containsObject:key])
        [_renderCondition wait];
    cachedImage = [_imageCache objectForKey:key];
    if (cachedImage == nil)
        [_renderingKeys addObject:key];
    [_renderCondition unlock];
    if (cachedImage != nil)
        return cachedImage;

    UIImage *image = nil;
    @autoreleasepool
    {
        NSString *diskPath = diskIdentity != nil ? OGSurfaceDiskCachePath(diskIdentity) : nil;
        image = diskPath != nil ? OGSurfaceLoadDiskImage(diskPath) : nil;
        if (image == nil)
        {
            image = render();
            if (image != nil && diskPath != nil)
            {
                UIImage *storedImage = image;
                dispatch_async(OGSurfaceDiskQueue(), ^
                {
                    @autoreleasepool
                    {
                        OGSurfaceStoreDiskImage(storedImage, diskPath);
                    }
                });
            }
        }
        if (image != nil)
            [_imageCache setObject:image forKey:key cost:OGSurfaceImageCost(image)];
    }

    [_renderCondition lock];
    [_renderingKeys removeObject:key];
    [_renderCondition broadcast];
    [_renderCondition unlock];
    return image;
}

- (UIImage *)renderImageWithStyle:(OGSurfaceStyle *)style size:(CGSize)size bodyFrame:(CGRect)bodyFrame scale:(CGFloat)scale
{
    NSInteger width = MAX(1, (NSInteger)ceilf(size.width * scale));
    NSInteger height = MAX(1, (NSInteger)ceilf(size.height * scale));
    BOOL bounded = style.shape != OGSurfaceShapeBand;
    CGRect bodyRect = CGRectMake(bodyFrame.origin.x * scale, bodyFrame.origin.y * scale, bodyFrame.size.width * scale, bodyFrame.size.height * scale);
    if (!bounded)
    {
        bodyRect.origin.x = 0.0f;
        bodyRect.size.width = (CGFloat)width;
    }

    NSInteger fieldWidth = bounded ? width : 1;
    float *mask = bounded ? OGSurfaceBoundedMask(style, width, height, bodyRect, scale) : OGSurfaceBandMask(height, bodyRect);

    NSArray *shadows = style.shadows;
    NSInteger shadowCount = (NSInteger)[shadows count];
    float **fields = calloc((size_t)MAX(1, shadowCount), sizeof(float *));
    OGSurfaceColor *shadowColors = calloc((size_t)MAX(1, shadowCount), sizeof(OGSurfaceColor));
    BOOL *shadowInsets = calloc((size_t)MAX(1, shadowCount), sizeof(BOOL));
    for (NSInteger index = 0; index < shadowCount; index++)
    {
        OGSurfaceShadow *shadow = shadows[(NSUInteger)index];
        fields[index] = OGSurfaceShadowField(mask, fieldWidth, height, bounded, shadow, scale);
        shadowColors[index] = OGSurfaceColorFromUIColor(shadow.color);
        shadowInsets[index] = shadow.inset;
    }

    NSInteger strokeStopCount = bounded && style.strokeWidth > 0.0f ? (NSInteger)[style.strokeColors count] : 0;
    float *strokeMask = strokeStopCount > 0 ? OGSurfaceStrokeMask(style, mask, width, height, bodyRect, scale) : NULL;
    OGSurfaceColor *strokeColors = calloc((size_t)MAX(1, strokeStopCount), sizeof(OGSurfaceColor));
    float *strokeLocations = calloc((size_t)MAX(1, strokeStopCount), sizeof(float));
    for (NSInteger index = 0; index < strokeStopCount; index++)
    {
        strokeColors[index] = OGSurfaceColorFromUIColor(style.strokeColors[(NSUInteger)index]);
        strokeLocations[index] = strokeStopCount > 1 ? (float)index / (float)(strokeStopCount - 1) : 0.0f;
    }

    NSArray *layers = style.layers;
    NSInteger layerCount = (NSInteger)[layers count];
    OGSurfaceRenderedLayer *renderedLayers = calloc((size_t)MAX(1, layerCount), sizeof(OGSurfaceRenderedLayer));
    for (NSInteger index = 0; index < layerCount; index++)
        renderedLayers[index] = OGSurfaceRenderLayer(layers[(NSUInteger)index], bodyFrame.size, bodyRect.origin, width, height, scale);

    CGFloat textureWidth = MAX(style.textureReferenceWidth, bodyFrame.size.width) * scale;
    if (!bounded)
        textureWidth = MAX(style.textureReferenceWidth * scale, (CGFloat)width);
    textureWidth = MAX(textureWidth, bodyRect.size.height * [self textureAspectForStyle:style]);
    if (style.textureTiled)
        textureWidth = style.textureReferenceWidth * scale;
    OGSurfaceTexture *texture = [self textureForStyle:style pixelWidth:(NSInteger)ceilf(textureWidth)];
    const uint8_t *texturePixels = (const uint8_t *)[texture.pixels bytes];
    NSInteger textureOriginX = (NSInteger)floorf(style.textureTiled ? bodyRect.origin.x : bodyRect.origin.x + (bodyRect.size.width - (CGFloat)texture.width) * 0.5f);
    NSInteger textureOriginY = (NSInteger)floorf(style.textureTiled ? bodyRect.origin.y : bodyRect.origin.y + (bodyRect.size.height - (CGFloat)texture.height) * 0.5f);
    NSInteger texturePixelWidth = texture.width;
    NSInteger texturePixelHeight = texture.height;
    if (texturePixelWidth <= 0 || texturePixelHeight <= 0)
        texturePixels = NULL;

    float contrast = (float)style.textureContrast;
    float bias = (float)style.textureBias;
    OGSurfaceColor tint = OGSurfaceColorFromUIColor(style.textureTintColor);

    OGSurfaceShading shading;
    memset(&shading, 0, sizeof(shading));
    shading.bounded = bounded;
    shading.width = width;
    shading.mask = mask;
    shading.shadowCount = shadowCount;
    shading.fields = fields;
    shading.shadowColors = shadowColors;
    shading.shadowInsets = shadowInsets;
    shading.strokeMask = strokeMask;
    shading.strokeColors = strokeColors;
    shading.strokeLocations = strokeLocations;
    shading.strokeStopCount = strokeStopCount;
    shading.bodyTop = (float)bodyRect.origin.y;
    shading.bodyHeight = (float)bodyRect.size.height;
    shading.layerCount = layerCount;
    shading.layers = renderedLayers;
    shading.fill = OGSurfaceColorFromUIColor(style.fillColor);
    shading.overlay = OGSurfaceColorFromUIColor(style.overlayColor);
    shading.opacity = OGSurfaceClamp((float)style.opacity);
    if (texturePixels != NULL)
    {
        for (NSInteger value = 0; value < 256; value++)
        {
            float normalized = (float)value / 255.0f;
            shading.textureCurve[0][value] = OGSurfaceClamp(normalized * contrast + tint.red + bias);
            shading.textureCurve[1][value] = OGSurfaceClamp(normalized * contrast + tint.green + bias);
            shading.textureCurve[2][value] = OGSurfaceClamp(normalized * contrast + tint.blue + bias);
        }
        shading.textured = YES;
    }

    OGSurfaceBandLookup lookup;
    lookup.valid = NO;
    uint8_t *pixels = calloc((size_t)(width * height * 4), 1);
    BOOL opaque = YES;
    for (NSInteger y = 0; y < height; y++)
    {
        uint8_t *row = pixels + (size_t)y * (size_t)width * 4;
        const uint8_t *textureRow = NULL;
        NSInteger textureStartX = 0;
        if (texturePixels != NULL)
        {
            NSInteger textureY = (y - textureOriginY) % texturePixelHeight;
            if (textureY < 0)
                textureY += texturePixelHeight;
            textureRow = texturePixels + textureY * texturePixelWidth * 4;
            textureStartX = (0 - textureOriginX) % texturePixelWidth;
            if (textureStartX < 0)
                textureStartX += texturePixelWidth;
        }

        if (!bounded && layerCount == 0)
        {
            if (!OGSurfaceShadeBandRow(&shading, &lookup, y, textureRow, textureStartX, texturePixelWidth, row))
                opaque = NO;
            continue;
        }

        NSInteger textureX = textureStartX;
        for (NSInteger x = 0; x < width; x++)
        {
            uint8_t *pixel = row + x * 4;
            OGSurfaceShadePixel(&shading, x, y, textureRow != NULL ? textureRow + textureX * 4 : NULL, pixel);
            if (pixel[3] != 255)
                opaque = NO;
            if (textureRow != NULL && ++textureX == texturePixelWidth)
                textureX = 0;
        }
    }

    for (NSInteger index = 0; index < shadowCount; index++)
        free(fields[index]);
    for (NSInteger index = 0; index < layerCount; index++)
        OGSurfaceReleaseRenderedLayer(&renderedLayers[index]);
    free(renderedLayers);
    free(fields);
    free(shadowColors);
    free(shadowInsets);
    free(strokeMask);
    free(strokeColors);
    free(strokeLocations);
    free(mask);

    UIImage *image = OGSurfaceImageFromPixels(pixels, width, height, scale, opaque);
    free(pixels);
    return image;
}

- (UIImage *)glyphImageWithTemplate:(UIImage *)image opticalSize:(CGFloat)opticalSize
{
    if (image == nil || image.CGImage == NULL || opticalSize <= 0.0f)
        return image;

    CGFloat values[1] = {opticalSize};
    OGSurfaceRenderKey *key = [[OGSurfaceRenderKey alloc] initWithKind:OGSurfaceRenderKeyKindGlyph objects:@[image] values:values count:1];
    UIImage *cachedImage = [_imageCache objectForKey:key];
    if (cachedImage != nil)
        return cachedImage;

    NSString *templateIdentity = OGSurfaceImageContentIdentity(image);
    NSString *diskIdentity = templateIdentity != nil ? [NSString stringWithFormat:@"glyph|%@|%.4f|%.1f", templateIdentity, (double)opticalSize, (double)OGPlatformScreenScale()] : nil;
    UIImage *result = [self cachedImageForKey:key diskIdentity:diskIdentity render:^UIImage *
    {
        return [self renderGlyphImageWithTemplate:image opticalSize:opticalSize];
    }];
    return result != nil ? result : image;
}

- (UIImage *)glyphImageWithText:(NSString *)text font:(UIFont *)font opticalSize:(CGFloat)opticalSize
{
    if ([text length] == 0 || font == nil || opticalSize <= 0.0f)
        return nil;

    CGFloat values[2] = {font.pointSize, opticalSize};
    OGSurfaceRenderKey *key = [[OGSurfaceRenderKey alloc] initWithKind:OGSurfaceRenderKeyKindTextGlyph objects:@[text, font.fontName] values:values count:2];
    UIImage *cachedImage = [_imageCache objectForKey:key];
    if (cachedImage != nil)
        return cachedImage;

    NSString *diskIdentity = [NSString stringWithFormat:@"text|%@|%@|%.4f|%.4f|%.1f", text, font.fontName, (double)font.pointSize, (double)opticalSize, (double)OGPlatformScreenScale()];
    return [self cachedImageForKey:key diskIdentity:diskIdentity render:^UIImage *
    {
        return [self renderGlyphImageWithText:text font:font opticalSize:opticalSize];
    }];
}

- (UIImage *)renderGlyphImageWithText:(NSString *)text font:(UIFont *)font opticalSize:(CGFloat)opticalSize
{
    CGFloat scale = OGPlatformScreenScale();
    CGSize textSize = [text sizeWithFont:font];
    NSInteger width = MAX(1, (NSInteger)ceilf(textSize.width * scale));
    NSInteger height = MAX(1, (NSInteger)ceilf(textSize.height * scale));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, (size_t)width, (size_t)height, 8, (size_t)(width * 4), colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return nil;

    CGContextTranslateCTM(context, 0.0f, (CGFloat)height);
    CGContextScaleCTM(context, scale, -scale);
    UIGraphicsPushContext(context);
    [[UIColor blackColor] set];
    [text drawAtPoint:CGPointZero withFont:font];
    UIGraphicsPopContext();
    CGImageRef textImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (textImage == NULL)
        return nil;

    UIImage *textTemplate = [UIImage imageWithCGImage:textImage scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(textImage);
    return [self renderGlyphImageWithTemplate:textTemplate opticalSize:opticalSize];
}

- (UIImage *)renderGlyphImageWithTemplate:(UIImage *)image opticalSize:(CGFloat)opticalSize
{
    CGImageRef cgImage = image.CGImage;
    NSInteger sourceWidth = (NSInteger)CGImageGetWidth(cgImage);
    NSInteger sourceHeight = (NSInteger)CGImageGetHeight(cgImage);
    if (sourceWidth <= 0 || sourceHeight <= 0)
        return image;

    uint8_t *coverage = calloc((size_t)(sourceWidth * sourceHeight), 1);
    CGContextRef maskContext = CGBitmapContextCreate(coverage, (size_t)sourceWidth, (size_t)sourceHeight, 8, (size_t)sourceWidth, NULL, kCGImageAlphaOnly);
    if (maskContext == NULL)
    {
        free(coverage);
        return image;
    }
    CGContextDrawImage(maskContext, CGRectMake(0.0f, 0.0f, (CGFloat)sourceWidth, (CGFloat)sourceHeight), cgImage);
    CGContextRelease(maskContext);

    NSInteger minX = sourceWidth;
    NSInteger minY = sourceHeight;
    NSInteger maxX = -1;
    NSInteger maxY = -1;
    for (NSInteger y = 0; y < sourceHeight; y++)
    {
        for (NSInteger x = 0; x < sourceWidth; x++)
        {
            if (coverage[y * sourceWidth + x] == 0)
                continue;
            minX = MIN(minX, x);
            maxX = MAX(maxX, x);
            minY = MIN(minY, y);
            maxY = MAX(maxY, y);
        }
    }
    free(coverage);
    if (maxX < minX || maxY < minY)
        return image;

    CGImageRef croppedImage = CGImageCreateWithImageInRect(cgImage, CGRectMake((CGFloat)minX, (CGFloat)minY, (CGFloat)(maxX - minX + 1), (CGFloat)(maxY - minY + 1)));
    if (croppedImage == NULL)
        return image;

    CGFloat sourceScale = image.scale > 0.0f ? image.scale : 1.0f;
    CGFloat glyphWidth = (CGFloat)(maxX - minX + 1) / sourceScale;
    CGFloat glyphHeight = (CGFloat)(maxY - minY + 1) / sourceScale;
    CGFloat factor = opticalSize / sqrtf(glyphWidth * glyphHeight);
    CGFloat scale = OGPlatformScreenScale();
    NSInteger width = MAX(1, (NSInteger)lroundf(glyphWidth * factor * scale));
    NSInteger height = MAX(1, (NSInteger)lroundf(glyphHeight * factor * scale));

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, (size_t)width, (size_t)height, 8, (size_t)(width * 4), colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    UIImage *result = nil;
    if (context != NULL)
    {
        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height), croppedImage);
        CGImageRef resultImage = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        if (resultImage != NULL)
        {
            result = [UIImage imageWithCGImage:resultImage scale:scale orientation:UIImageOrientationUp];
            CGImageRelease(resultImage);
        }
    }
    CGImageRelease(croppedImage);
    return result != nil ? result : image;
}

- (UIImage *)iconImageWithTemplate:(UIImage *)image gradientColors:(NSArray *)colors locations:(NSArray *)locations shadow:(OGSurfaceShadow *)shadow outsets:(UIEdgeInsets)outsets
{
    return [self iconImageWithTemplate:image gradientColors:colors locations:locations shadows:(shadow != nil ? @[shadow] : nil) outsets:outsets];
}

- (UIImage *)iconImageWithTemplate:(UIImage *)image gradientColors:(NSArray *)colors locations:(NSArray *)locations shadows:(NSArray *)shadows outsets:(UIEdgeInsets)outsets
{
    if (image == nil || image.CGImage == NULL || [colors count] == 0 || [colors count] != [locations count])
        return image;

    CGFloat values[4] = {outsets.top, outsets.left, outsets.bottom, outsets.right};
    NSMutableString *shadowsIdentity = [[NSMutableString alloc] init];
    for (OGSurfaceShadow *shadow in shadows)
        [shadowsIdentity appendString:[shadow renderIdentity]];
    NSArray *objects = @[image, [colors copy], [locations copy], shadowsIdentity];
    OGSurfaceRenderKey *key = [[OGSurfaceRenderKey alloc] initWithKind:OGSurfaceRenderKeyKindIcon objects:objects values:values count:4];
    UIImage *cachedImage = [_imageCache objectForKey:key];
    if (cachedImage != nil)
        return cachedImage;

    NSString *templateIdentity = OGSurfaceImageContentIdentity(image);
    NSString *diskIdentity = nil;
    if (templateIdentity != nil)
    {
        NSMutableString *identity = [[NSMutableString alloc] initWithFormat:@"icon|%@|%.4f|%.4f|%.4f|%.4f|", templateIdentity, (double)outsets.top, (double)outsets.left, (double)outsets.bottom, (double)outsets.right];
        for (UIColor *color in colors)
        {
            OGSurfaceColor components = OGSurfaceColorFromUIColor(color);
            [identity appendFormat:@"%.4f,%.4f,%.4f,%.4f;", (double)components.red, (double)components.green, (double)components.blue, (double)components.alpha];
        }
        [identity appendString:@"|"];
        for (NSNumber *location in locations)
            [identity appendFormat:@"%.4f;", (double)[location floatValue]];
        [identity appendString:@"|"];
        [identity appendString:shadowsIdentity];
        diskIdentity = identity;
    }
    UIImage *result = [self cachedImageForKey:key diskIdentity:diskIdentity render:^UIImage *
    {
        return [self renderIconImageWithTemplate:image gradientColors:colors locations:locations shadows:shadows outsets:outsets];
    }];
    return result != nil ? result : image;
}

- (UIImage *)renderIconImageWithTemplate:(UIImage *)image gradientColors:(NSArray *)colors locations:(NSArray *)locations shadows:(NSArray *)shadows outsets:(UIEdgeInsets)outsets
{
    CGFloat scale = image.scale > 0.0f ? image.scale : 1.0f;
    NSInteger glyphWidth = MAX(1, (NSInteger)lroundf(image.size.width * scale));
    NSInteger glyphHeight = MAX(1, (NSInteger)lroundf(image.size.height * scale));
    NSInteger left = (NSInteger)lroundf(outsets.left * scale);
    NSInteger top = (NSInteger)lroundf(outsets.top * scale);
    NSInteger bottom = (NSInteger)lroundf(outsets.bottom * scale);
    NSInteger width = glyphWidth + left + (NSInteger)lroundf(outsets.right * scale);
    NSInteger height = glyphHeight + top + bottom;

    uint8_t *coverage = calloc((size_t)(width * height), 1);
    CGContextRef maskContext = CGBitmapContextCreate(coverage, (size_t)width, (size_t)height, 8, (size_t)width, NULL, kCGImageAlphaOnly);
    if (maskContext == NULL)
    {
        free(coverage);
        return image;
    }
    CGContextSetInterpolationQuality(maskContext, kCGInterpolationHigh);
    CGContextDrawImage(maskContext, CGRectMake((CGFloat)left, (CGFloat)bottom, (CGFloat)glyphWidth, (CGFloat)glyphHeight), image.CGImage);
    CGContextRelease(maskContext);

    float *mask = malloc((size_t)(width * height) * sizeof(float));
    for (NSInteger index = 0; index < width * height; index++)
        mask[index] = (float)coverage[index] / 255.0f;
    free(coverage);

    NSInteger stopCount = (NSInteger)[colors count];
    OGSurfaceColor *stopColors = calloc((size_t)stopCount, sizeof(OGSurfaceColor));
    float *stopLocations = calloc((size_t)stopCount, sizeof(float));
    for (NSInteger index = 0; index < stopCount; index++)
    {
        stopColors[index] = OGSurfaceColorFromUIColor(colors[(NSUInteger)index]);
        stopLocations[index] = [locations[(NSUInteger)index] floatValue];
    }

    NSInteger shadowCount = (NSInteger)[shadows count];
    float **fields = calloc((size_t)MAX(1, shadowCount), sizeof(float *));
    OGSurfaceColor *shadowColors = calloc((size_t)MAX(1, shadowCount), sizeof(OGSurfaceColor));
    BOOL *shadowInsets = calloc((size_t)MAX(1, shadowCount), sizeof(BOOL));
    for (NSInteger index = 0; index < shadowCount; index++)
    {
        OGSurfaceShadow *shadow = shadows[(NSUInteger)index];
        fields[index] = OGSurfaceShadowField(mask, width, height, YES, shadow, scale);
        shadowColors[index] = OGSurfaceColorFromUIColor(shadow.color);
        shadowInsets[index] = shadow.inset;
    }

    uint8_t *pixels = calloc((size_t)(width * height * 4), 1);
    for (NSInteger y = 0; y < height; y++)
    {
        float position = OGSurfaceClamp(((float)(y - top) + 0.5f) / (float)glyphHeight);
        OGSurfaceColor color = OGSurfaceGradientColor(stopColors, stopLocations, stopCount, position);
        for (NSInteger x = 0; x < width; x++)
        {
            NSInteger index = y * width + x;
            float glyphCoverage = mask[index];
            OGSurfacePremultipliedColor pixel = {0.0f, 0.0f, 0.0f, 0.0f};
            for (NSInteger shadowIndex = shadowCount - 1; shadowIndex >= 0; shadowIndex--)
            {
                if (shadowInsets[shadowIndex])
                    continue;
                pixel = OGSurfaceComposite(pixel, shadowColors[shadowIndex], OGSurfaceClamp(shadowColors[shadowIndex].alpha * fields[shadowIndex][index]), OGSurfaceBlendModeNormal);
            }
            pixel = OGSurfaceComposite(pixel, color, OGSurfaceClamp(color.alpha * glyphCoverage), OGSurfaceBlendModeNormal);
            for (NSInteger shadowIndex = shadowCount - 1; shadowIndex >= 0; shadowIndex--)
            {
                if (!shadowInsets[shadowIndex])
                    continue;
                pixel = OGSurfaceComposite(pixel, shadowColors[shadowIndex], OGSurfaceClamp(shadowColors[shadowIndex].alpha * fields[shadowIndex][index] * glyphCoverage), OGSurfaceBlendModeNormal);
            }
            uint8_t *output = pixels + index * 4;
            output[0] = OGSurfaceByte(pixel.red);
            output[1] = OGSurfaceByte(pixel.green);
            output[2] = OGSurfaceByte(pixel.blue);
            output[3] = OGSurfaceByte(pixel.alpha);
        }
    }

    for (NSInteger index = 0; index < shadowCount; index++)
        free(fields[index]);
    free(fields);
    free(shadowColors);
    free(shadowInsets);
    free(stopColors);
    free(stopLocations);
    free(mask);

    UIImage *result = OGSurfaceImageFromPixels(pixels, width, height, scale, NO);
    free(pixels);
    return result != nil ? result : image;
}

@end
