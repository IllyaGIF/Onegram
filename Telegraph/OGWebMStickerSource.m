#import "OGWebMStickerSource.h"

#import "OGWebM.h"
#import "OGVideoColor.h"
#import "OGStickerWorker.h"

#import <vpx/vpx_decoder.h>
#import <vpx/vp8dx.h>
#import <limits.h>
#import <stdlib.h>
#import <string.h>

@interface OGWebMStickerSource ()
{
    NSData *_data;
    OGWebM _webm;
    vpx_codec_ctx_t _colorDecoder;
    vpx_codec_ctx_t _alphaDecoder;
    bool _colorInitialized;
    bool _alphaInitialized;
    size_t _width;
    size_t _height;
    size_t _renderWidth;
    size_t _renderHeight;
    uint8_t *_renderPixels;
    NSUInteger _nextFrame;
    bool _hasFrame;
    vpx_image_t *_colorImage;
    vpx_image_t *_alphaImage;
    bool _converted;
    dispatch_semaphore_t _alphaSemaphore;
    CFAbsoluteTime _decodeTime;
    CFAbsoluteTime _alphaWaitTime;
    CFAbsoluteTime _convertTime;
    NSUInteger _decodedFrames;
    uint8_t *_lastPixels;
    NSString *_failureReason;
}

- (bool)initializeDecoders;

@end

@implementation OGWebMStickerSource


- (instancetype)initWithData:(NSData *)data width:(size_t)width height:(size_t)height
{
    self = [super init];
    if (self != nil)
    {
        _data = data;
        _width = width;
        _height = height;
        if (width == 0 || height == 0 || width > 1024 || height > 1024 || !OGWebMParse(data.bytes, data.length, &_webm))
        {
            _failureReason = @"invalid WebM";
            return nil;
        }
        _lastPixels = malloc(width * height * 4);
        if (_lastPixels == NULL)
        {
            _failureReason = @"out of memory";
            return nil;
        }
        if ((uint64_t)_webm.width * height > (uint64_t)_webm.height * width)
        {
            _renderWidth = width;
            _renderHeight = MAX(1, (size_t)((uint64_t)_webm.height * width / _webm.width));
        }
        else
        {
            _renderHeight = height;
            _renderWidth = MAX(1, (size_t)((uint64_t)_webm.width * height / _webm.height));
        }
        if (_renderWidth != width || _renderHeight != height)
        {
            _renderPixels = malloc(_renderWidth * _renderHeight * 4);
            if (_renderPixels == NULL)
            {
                _failureReason = @"out of memory";
                return nil;
            }
        }
        if (![self initializeDecoders])
            return nil;
    }
    return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
    if (_alphaSemaphore != NULL)
        dispatch_release(_alphaSemaphore);
#endif
    if (_colorInitialized)
        vpx_codec_destroy(&_colorDecoder);
    if (_alphaInitialized)
        vpx_codec_destroy(&_alphaDecoder);
    free(_lastPixels);
    free(_renderPixels);
    OGWebMFree(&_webm);
}

- (NSString *)failureReason
{
    return _failureReason;
}

- (NSString *)statistics
{
    return [[NSString alloc] initWithFormat:@"decoded=%d decodeMs=%d alphaWaitMs=%d convertMs=%d", (int)_decodedFrames, (int)(_decodeTime * 1000.0), (int)(_alphaWaitTime * 1000.0), (int)(_convertTime * 1000.0)];
}

- (bool)initializeDecoders
{
    if (_colorInitialized)
        vpx_codec_destroy(&_colorDecoder);
    if (_alphaInitialized)
        vpx_codec_destroy(&_alphaDecoder);
    _colorInitialized = false;
    _alphaInitialized = false;
    _hasFrame = false;
    _nextFrame = 0;
    _colorImage = NULL;
    _alphaImage = NULL;
    _converted = false;
    vpx_codec_dec_cfg_t config;
    config.threads = _webm.alphaMode != 0 ? 1 : 2;
    config.w = _webm.width;
    config.h = _webm.height;
    if (vpx_codec_dec_init(&_colorDecoder, vpx_codec_vp9_dx(), &config, 0) != VPX_CODEC_OK)
    {
        _failureReason = @"VP9 decoder initialization";
        return false;
    }
    _colorInitialized = true;
    if (_webm.alphaMode != 0)
    {
        if (vpx_codec_dec_init(&_alphaDecoder, vpx_codec_vp9_dx(), &config, 0) != VPX_CODEC_OK)
        {
            _failureReason = @"VP9 alpha decoder initialization";
            return false;
        }
        _alphaInitialized = true;
        if (_alphaSemaphore == NULL)
            _alphaSemaphore = dispatch_semaphore_create(0);
    }
    return true;
}

- (bool)hasAlpha
{
    return _webm.alphaMode != 0;
}

- (NSUInteger)memoryCost
{
    size_t decoderFrame = (size_t)_webm.width * _webm.height * 3 / 2;
    size_t decoders = decoderFrame * 10 * (_alphaInitialized ? 2 : 1);
    size_t pixels = _width * _height * 4 + (_renderPixels != NULL ? _renderWidth * _renderHeight * 4 : 0);
    return (NSUInteger)(decoders + pixels + (size_t)_webm.frameCount * sizeof(OGWebMFrame));
}

- (NSTimeInterval)duration
{
    return (NSTimeInterval)_webm.durationNs / 1000000000.0;
}

- (vpx_image_t *)decodeBytesAt:(size_t)offset length:(size_t)length decoder:(vpx_codec_ctx_t *)decoder
{
    if (length == 0 || length > UINT_MAX || offset > _data.length || length > _data.length - offset)
        return NULL;
    if (vpx_codec_decode(decoder, (const uint8_t *)_data.bytes + offset, (unsigned int)length, NULL, 0) != VPX_CODEC_OK)
        return NULL;
    vpx_codec_iter_t iterator = NULL;
    vpx_image_t *image = NULL;
    vpx_image_t *next = NULL;
    while ((next = vpx_codec_get_frame(decoder, &iterator)) != NULL)
        image = next;
    if (image == NULL || image->fmt != VPX_IMG_FMT_I420 || image->d_w == 0 || image->d_h == 0 || image->d_w > 1024 || image->d_h > 1024)
        return NULL;
    return image;
}

- (bool)decodeFrame:(OGWebMFrame)frame
{
    bool decodeAlpha = frame.alphaLength != 0;
    if (decodeAlpha && !_alphaInitialized)
    {
        _failureReason = @"VP9 alpha frame";
        return false;
    }
    __block vpx_image_t *alpha = NULL;
    if (decodeAlpha)
    {
        vpx_codec_ctx_t *alphaDecoder = &_alphaDecoder;
        size_t alphaOffset = frame.alphaOffset;
        size_t alphaLength = frame.alphaLength;
        dispatch_semaphore_t alphaSemaphore = _alphaSemaphore;
        [[OGStickerWorker auxiliaryWorker] perform:^
        {
            alpha = [self decodeBytesAt:alphaOffset length:alphaLength decoder:alphaDecoder];
            dispatch_semaphore_signal(alphaSemaphore);
        }];
    }
    CFAbsoluteTime decodeStart = CFAbsoluteTimeGetCurrent();
    vpx_image_t *color = [self decodeBytesAt:frame.offset length:frame.length decoder:&_colorDecoder];
    CFAbsoluteTime decodeEnd = CFAbsoluteTimeGetCurrent();
    if (decodeAlpha)
        dispatch_semaphore_wait(_alphaSemaphore, DISPATCH_TIME_FOREVER);
    _decodeTime += decodeEnd - decodeStart;
    _alphaWaitTime += CFAbsoluteTimeGetCurrent() - decodeEnd;
    _decodedFrames++;
    if (color == NULL)
    {
        _failureReason = @"VP9 color frame";
        return false;
    }
    if (decodeAlpha && alpha == NULL)
    {
        _failureReason = @"VP9 alpha frame";
        return false;
    }
    _colorImage = color;
    _alphaImage = alpha;
    _converted = false;
    return true;
}

- (bool)convertCurrentFrame
{
    if (_converted)
        return true;
    vpx_image_t *color = _colorImage;
    vpx_image_t *alpha = _alphaImage;
    if (color == NULL)
    {
        _failureReason = @"no decoded frame";
        return false;
    }
    OGVideoI420 colorPlanes = {0};
    colorPlanes.width = color->d_w;
    colorPlanes.height = color->d_h;
    for (int i = 0; i < 3; i++)
    {
        colorPlanes.planes[i] = color->planes[i];
        colorPlanes.strides[i] = color->stride[i];
    }
    OGVideoI420 alphaPlanes = {0};
    if (alpha != NULL)
    {
        alphaPlanes.width = alpha->d_w;
        alphaPlanes.height = alpha->d_h;
        alphaPlanes.planes[0] = alpha->planes[0];
        alphaPlanes.strides[0] = alpha->stride[0];
    }
    CFAbsoluteTime convertStart = CFAbsoluteTimeGetCurrent();
    bool converted = OGVideoConvertBGRA(&colorPlanes, alpha == NULL ? NULL : &alphaPlanes, _renderPixels ?: _lastPixels, (unsigned int)_renderWidth, (unsigned int)_renderHeight);
    _convertTime += CFAbsoluteTimeGetCurrent() - convertStart;
    if (!converted)
    {
        _failureReason = @"I420 conversion";
        return false;
    }
    if (_renderPixels != NULL)
    {
        memset(_lastPixels, 0, _width * _height * 4);
        size_t x = (_width - _renderWidth) / 2;
        size_t y = (_height - _renderHeight) / 2;
        for (size_t row = 0; row < _renderHeight; row++)
            memcpy(_lastPixels + ((y + row) * _width + x) * 4, _renderPixels + row * _renderWidth * 4, _renderWidth * 4);
    }
    _converted = true;
    return true;
}

- (bool)renderAtTime:(NSTimeInterval)time intoBGRA:(uint8_t *)pixels cancelled:(bool (^)(void))cancelled
{
    if (pixels == NULL || time < 0 || time >= [self duration] + 1.0)
        return false;
    uint64_t timestamp = (uint64_t)(time * 1000000000.0 + 0.5);
    if (_hasFrame && timestamp < _webm.frames[_nextFrame - 1].timestampNs && ![self initializeDecoders])
        return false;
    while (_nextFrame < _webm.frameCount && (!_hasFrame || _webm.frames[_nextFrame].timestampNs <= timestamp))
    {
        if (cancelled != nil && cancelled())
            return false;
        if (![self decodeFrame:_webm.frames[_nextFrame]])
            return false;
        _nextFrame++;
        _hasFrame = true;
    }
    if (!_hasFrame)
    {
        _failureReason = @"no decoded frame";
        return false;
    }
    if (cancelled != nil && cancelled())
        return false;
    if (![self convertCurrentFrame])
        return false;
    memcpy(pixels, _lastPixels, _width * _height * 4);
    return true;
}

@end
