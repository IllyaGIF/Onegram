#import "OGPlatformQRCode.h"
#include "../thirdparty/quirc/quirc.h"
#include <math.h>

NSString *OGPlatformReadQRCode(UIImage *image)
{
    CGImageRef source = image.CGImage;
    if (source == NULL)
        return nil;
    size_t sourceWidth = CGImageGetWidth(source);
    size_t sourceHeight = CGImageGetHeight(source);
    if (sourceWidth == 0 || sourceHeight == 0)
        return nil;
    double scale = MIN(1.0, 1280.0 / MAX(sourceWidth, sourceHeight));
    int width = MAX(1, (int)floor(sourceWidth * scale));
    int height = MAX(1, (int)floor(sourceHeight * scale));
    struct quirc *decoder = quirc_new();
    if (decoder == NULL)
        return nil;
    if (quirc_resize(decoder, width, height) < 0)
    {
        quirc_destroy(decoder);
        return nil;
    }
    uint8_t *pixels = quirc_begin(decoder, NULL, NULL);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width, colorSpace, kCGImageAlphaNone);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
    {
        quirc_destroy(decoder);
        return nil;
    }
    CGContextSetGrayFillColor(context, 1.0, 1.0);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), source);
    CGContextRelease(context);
    quirc_end(decoder);
    NSString *result = nil;
    for (int index = 0; index < quirc_count(decoder); index++)
    {
        struct quirc_code code;
        struct quirc_data data;
        quirc_extract(decoder, index, &code);
        quirc_decode_error_t error = quirc_decode(&code, &data);
        if (error == QUIRC_ERROR_DATA_ECC)
        {
            quirc_flip(&code);
            error = quirc_decode(&code, &data);
        }
        if (error == QUIRC_SUCCESS)
        {
            NSString *value = [[NSString alloc] initWithBytes:data.payload length:data.payload_len encoding:NSUTF8StringEncoding];
            if ([value hasPrefix:@"tg://login?token="])
            {
                result = value;
                break;
            }
        }
    }
    quirc_destroy(decoder);
    return result;
}
