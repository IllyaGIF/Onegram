//
//  FLAnimatedImage.m
//  Flipboard
//
//  Created by Raphael Schaad on 7/8/13.
//  Copyright (c) 2013-2014 Flipboard. All rights reserved.
//


#import "FLAnimatedImage.h"
#if !defined(ONEGRAM_ARMV6)
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#endif
#import <CoreGraphics/CoreGraphics.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>


// From vm_param.h, define for iOS 8.0 or higher to build on device.
#ifndef BYTE_SIZE
#define BYTE_SIZE 8 // byte size in bits
#endif

#define MEGABYTE (1024 * 1024)

static void FLAnimatedImageEnumerateRanges(NSIndexSet *indexSet, NSRange enumerationRange, void (^block)(NSRange range, BOOL *stop))
{
    if (indexSet == nil || block == nil || enumerationRange.length == 0)
        return;

    NSUInteger rangeEnd = enumerationRange.location + enumerationRange.length;
    NSUInteger index = [indexSet firstIndex];
    while (index != NSNotFound && index < enumerationRange.location)
        index = [indexSet indexGreaterThanIndex:index];

    BOOL stop = NO;
    while (index != NSNotFound && index < rangeEnd && !stop)
    {
        NSUInteger rangeStart = index;
        NSUInteger rangeLast = index;
        NSUInteger next = [indexSet indexGreaterThanIndex:index];
        while (next != NSNotFound && next < rangeEnd && next == rangeLast + 1)
        {
            rangeLast = next;
            next = [indexSet indexGreaterThanIndex:next];
        }

        block(NSMakeRange(rangeStart, rangeLast - rangeStart + 1), &stop);
        index = next;
    }
}


// An animated image's data size (dimensions * frameCount) category; its value is the max allowed memory (in MB).
// E.g.: A 100x200px GIF with 30 frames is ~2.3MB in our pixel format and would fall into the `FLAnimatedImageDataSizeCategoryAll` category.
typedef NS_ENUM(NSUInteger, FLAnimatedImageDataSizeCategory) {
    FLAnimatedImageDataSizeCategoryAll = 10,       // All frames permanently in memory (be nice to the CPU)
    FLAnimatedImageDataSizeCategoryDefault = 75,   // A frame cache of default size in memory (usually real-time performance and keeping low memory profile)
    FLAnimatedImageDataSizeCategoryOnDemand = 250, // Only keep one frame at the time in memory (easier on memory, slowest performance)
    FLAnimatedImageDataSizeCategoryUnsupported     // Even for one frame too large, computer says no.
};

typedef NS_ENUM(NSUInteger, FLAnimatedImageFrameCacheSize) {
    FLAnimatedImageFrameCacheSizeNoLimit = 0,                // 0 means no specific limit
    FLAnimatedImageFrameCacheSizeLowMemory = 1,              // The minimum frame cache size; this will produce frames on-demand.
    FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning = 2, // If we can produce the frames faster than we consume, one frame ahead will already result in a stutter-free playback.
    FLAnimatedImageFrameCacheSizeDefault = 5                 // Build up a comfy buffer window to cope with CPU hiccups etc.
};


#if defined(ONEGRAM_ARMV6)

typedef struct
{
    const uint8_t *bytes;
    NSUInteger length;
    NSUInteger offset;
} OnegramGIFCursor;

@interface OnegramGIFFrame : NSObject
{
@public
    NSUInteger _left;
    NSUInteger _top;
    NSUInteger _width;
    NSUInteger _height;
    NSUInteger _disposal;
    NSTimeInterval _delay;
    NSInteger _transparentIndex;
    bool _interlaced;
    uint8_t _minimumCodeSize;
    NSData *_palette;
    NSData *_compressedData;
}
@end

@implementation OnegramGIFFrame
@end

static bool OnegramGIFReadByte(OnegramGIFCursor *cursor, uint8_t *value)
{
    if (cursor->offset >= cursor->length)
        return false;
    *value = cursor->bytes[cursor->offset++];
    return true;
}

static bool OnegramGIFReadUInt16(OnegramGIFCursor *cursor, NSUInteger *value)
{
    if (cursor->offset + 2 > cursor->length)
        return false;
    *value = (NSUInteger)cursor->bytes[cursor->offset] | ((NSUInteger)cursor->bytes[cursor->offset + 1] << 8);
    cursor->offset += 2;
    return true;
}

static NSData *OnegramGIFReadBytes(OnegramGIFCursor *cursor, NSUInteger length)
{
    if (cursor->offset + length > cursor->length)
        return nil;
    NSData *result = [NSData dataWithBytes:cursor->bytes + cursor->offset length:length];
    cursor->offset += length;
    return result;
}

static NSData *OnegramGIFReadSubBlocks(OnegramGIFCursor *cursor)
{
    NSMutableData *result = [[NSMutableData alloc] init];
    while (true)
    {
        uint8_t length = 0;
        if (!OnegramGIFReadByte(cursor, &length))
            return nil;
        if (length == 0)
            break;
        if (cursor->offset + length > cursor->length)
            return nil;
        [result appendBytes:cursor->bytes + cursor->offset length:length];
        cursor->offset += length;
    }
    return result;
}

static NSInteger OnegramGIFReadCode(const uint8_t *bytes, NSUInteger length, NSUInteger *bitOffset, NSUInteger codeSize)
{
    if (*bitOffset + codeSize > length * 8)
        return -1;
    NSUInteger value = 0;
    for (NSUInteger bit = 0; bit < codeSize; bit++)
    {
        NSUInteger position = *bitOffset + bit;
        value |= (NSUInteger)((bytes[position >> 3] >> (position & 7)) & 1) << bit;
    }
    *bitOffset += codeSize;
    return (NSInteger)value;
}

static NSData *OnegramGIFDecodeLZW(NSData *data, NSUInteger minimumCodeSize, NSUInteger pixelCount)
{
    if (minimumCodeSize > 11 || pixelCount == 0)
        return nil;

    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    uint16_t prefix[4096];
    uint8_t suffix[4096];
    uint8_t stack[4096];
    uint8_t *output = malloc(pixelCount);
    if (output == NULL)
        return nil;

    NSUInteger clearCode = (NSUInteger)1 << minimumCodeSize;
    NSUInteger endCode = clearCode + 1;
    NSUInteger nextCode = endCode + 1;
    NSUInteger codeSize = minimumCodeSize + 1;
    NSUInteger bitOffset = 0;
    NSUInteger outputOffset = 0;
    NSInteger previousCode = -1;
    uint8_t firstValue = 0;

    for (NSUInteger i = 0; i < clearCode; i++)
    {
        prefix[i] = 0;
        suffix[i] = (uint8_t)i;
    }

    while (outputOffset < pixelCount)
    {
        NSInteger readCode = OnegramGIFReadCode(bytes, length, &bitOffset, codeSize);
        if (readCode < 0)
            break;
        NSUInteger code = (NSUInteger)readCode;

        if (code == clearCode)
        {
            nextCode = endCode + 1;
            codeSize = minimumCodeSize + 1;
            previousCode = -1;
            continue;
        }
        if (code == endCode)
            break;
        if (code >= 4096)
            break;

        if (previousCode < 0)
        {
            if (code >= clearCode)
                break;
            firstValue = suffix[code];
            output[outputOffset++] = firstValue;
            previousCode = (NSInteger)code;
            continue;
        }

        NSUInteger inputCode = code;
        NSUInteger stackCount = 0;
        if (code >= nextCode)
        {
            if (code != nextCode || stackCount >= 4096)
                break;
            stack[stackCount++] = firstValue;
            code = (NSUInteger)previousCode;
        }

        while (code >= clearCode)
        {
            if (code >= nextCode || stackCount >= 4096)
            {
                free(output);
                return nil;
            }
            stack[stackCount++] = suffix[code];
            code = prefix[code];
        }

        firstValue = suffix[code];
        if (stackCount >= 4096)
        {
            free(output);
            return nil;
        }
        stack[stackCount++] = firstValue;

        while (stackCount != 0 && outputOffset < pixelCount)
            output[outputOffset++] = stack[--stackCount];

        if (nextCode < 4096)
        {
            prefix[nextCode] = (uint16_t)previousCode;
            suffix[nextCode] = firstValue;
            nextCode++;
            if (nextCode == ((NSUInteger)1 << codeSize) && codeSize < 12)
                codeSize++;
        }

        previousCode = (NSInteger)inputCode;
    }

    if (outputOffset != pixelCount)
    {
        free(output);
        return nil;
    }

    return [NSData dataWithBytesNoCopy:output length:pixelCount freeWhenDone:YES];
}

static void OnegramGIFReleaseImageData(void *info, const void *data, size_t size)
{
    (void)info;
    (void)size;
    free((void *)data);
}

@interface OnegramGIFSource : NSObject
{
    NSUInteger _width;
    NSUInteger _height;
    NSUInteger _loopCount;
    NSData *_globalPalette;
    NSArray *_frames;
    NSMutableData *_canvas;
    NSData *_restoreCanvas;
    NSInteger _renderedIndex;
    OnegramGIFFrame *_renderedFrame;
}

@property (nonatomic, readonly) NSUInteger frameCount;
@property (nonatomic, readonly) NSUInteger loopCount;

- (instancetype)initWithData:(NSData *)data;
- (NSTimeInterval)delayAtIndex:(NSUInteger)index;
- (UIImage *)imageAtIndex:(NSUInteger)index;

@end

@implementation OnegramGIFSource

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self == nil || data.length < 13)
        return nil;

    OnegramGIFCursor cursor = { data.bytes, data.length, 0 };
    NSData *signature = OnegramGIFReadBytes(&cursor, 6);
    if (signature == nil)
        return nil;
    const uint8_t *signatureBytes = signature.bytes;
    if (memcmp(signatureBytes, "GIF87a", 6) != 0 && memcmp(signatureBytes, "GIF89a", 6) != 0)
        return nil;

    if (!OnegramGIFReadUInt16(&cursor, &_width) || !OnegramGIFReadUInt16(&cursor, &_height) || _width == 0 || _height == 0)
        return nil;

    uint8_t packed = 0;
    uint8_t background = 0;
    uint8_t aspect = 0;
    if (!OnegramGIFReadByte(&cursor, &packed) || !OnegramGIFReadByte(&cursor, &background) || !OnegramGIFReadByte(&cursor, &aspect))
        return nil;
    (void)background;
    (void)aspect;

    if ((packed & 0x80) != 0)
    {
        NSUInteger paletteSize = (NSUInteger)1 << ((packed & 0x07) + 1);
        _globalPalette = OnegramGIFReadBytes(&cursor, paletteSize * 3);
        if (_globalPalette == nil)
            return nil;
    }

    NSMutableArray *frames = [[NSMutableArray alloc] init];
    NSUInteger disposal = 0;
    NSTimeInterval delay = 0.0;
    NSInteger transparentIndex = -1;

    while (cursor.offset < cursor.length)
    {
        uint8_t marker = 0;
        if (!OnegramGIFReadByte(&cursor, &marker))
            return nil;

        if (marker == 0x3b)
            break;

        if (marker == 0x21)
        {
            uint8_t label = 0;
            if (!OnegramGIFReadByte(&cursor, &label))
                return nil;

            if (label == 0xf9)
            {
                uint8_t blockSize = 0;
                uint8_t gcePacked = 0;
                uint8_t transparent = 0;
                NSUInteger delayValue = 0;
                if (!OnegramGIFReadByte(&cursor, &blockSize) || blockSize != 4 || !OnegramGIFReadByte(&cursor, &gcePacked) || !OnegramGIFReadUInt16(&cursor, &delayValue) || !OnegramGIFReadByte(&cursor, &transparent))
                    return nil;
                uint8_t terminator = 0;
                if (!OnegramGIFReadByte(&cursor, &terminator) || terminator != 0)
                    return nil;
                disposal = (gcePacked >> 2) & 0x07;
                delay = (NSTimeInterval)delayValue / 100.0;
                transparentIndex = (gcePacked & 0x01) != 0 ? transparent : -1;
            }
            else if (label == 0xff)
            {
                uint8_t applicationLength = 0;
                if (!OnegramGIFReadByte(&cursor, &applicationLength))
                    return nil;
                NSData *application = OnegramGIFReadBytes(&cursor, applicationLength);
                if (application == nil)
                    return nil;
                NSData *blocks = OnegramGIFReadSubBlocks(&cursor);
                if (blocks == nil)
                    return nil;
                if (application.length == 11 && blocks.length >= 3)
                {
                    const uint8_t *applicationBytes = application.bytes;
                    const uint8_t *blockBytes = blocks.bytes;
                    if ((memcmp(applicationBytes, "NETSCAPE2.0", 11) == 0 || memcmp(applicationBytes, "ANIMEXTS1.0", 11) == 0) && blockBytes[0] == 1)
                        _loopCount = (NSUInteger)blockBytes[1] | ((NSUInteger)blockBytes[2] << 8);
                }
            }
            else
            {
                if (OnegramGIFReadSubBlocks(&cursor) == nil)
                    return nil;
            }
            continue;
        }

        if (marker != 0x2c)
            return nil;

        OnegramGIFFrame *frame = [[OnegramGIFFrame alloc] init];
        if (!OnegramGIFReadUInt16(&cursor, &frame->_left) || !OnegramGIFReadUInt16(&cursor, &frame->_top) || !OnegramGIFReadUInt16(&cursor, &frame->_width) || !OnegramGIFReadUInt16(&cursor, &frame->_height) || frame->_width == 0 || frame->_height == 0)
            return nil;

        uint8_t imagePacked = 0;
        if (!OnegramGIFReadByte(&cursor, &imagePacked))
            return nil;
        frame->_interlaced = (imagePacked & 0x40) != 0;
        if ((imagePacked & 0x80) != 0)
        {
            NSUInteger paletteSize = (NSUInteger)1 << ((imagePacked & 0x07) + 1);
            frame->_palette = OnegramGIFReadBytes(&cursor, paletteSize * 3);
            if (frame->_palette == nil)
                return nil;
        }

        if (!OnegramGIFReadByte(&cursor, &frame->_minimumCodeSize))
            return nil;
        frame->_compressedData = OnegramGIFReadSubBlocks(&cursor);
        if (frame->_compressedData == nil)
            return nil;
        frame->_disposal = disposal;
        frame->_delay = delay;
        frame->_transparentIndex = transparentIndex;
        [frames addObject:frame];

        disposal = 0;
        delay = 0.0;
        transparentIndex = -1;
    }

    if (frames.count == 0)
        return nil;

    _frames = [frames copy];
    _canvas = [[NSMutableData alloc] initWithLength:_width * _height * 4];
    _renderedIndex = -1;
    return self;
}

- (NSUInteger)frameCount
{
    return _frames.count;
}

- (NSUInteger)loopCount
{
    return _loopCount;
}

- (NSTimeInterval)delayAtIndex:(NSUInteger)index
{
    if (index >= _frames.count)
        return 0.0;
    return ((OnegramGIFFrame *)[_frames objectAtIndex:index])->_delay;
}

- (void)resetRendering
{
    memset(_canvas.mutableBytes, 0, _canvas.length);
    _restoreCanvas = nil;
    _renderedFrame = nil;
    _renderedIndex = -1;
}

- (void)clearFrameRect:(OnegramGIFFrame *)frame
{
    uint8_t *canvas = _canvas.mutableBytes;
    NSUInteger startX = MIN(frame->_left, _width);
    NSUInteger startY = MIN(frame->_top, _height);
    NSUInteger endX = MIN(frame->_left + frame->_width, _width);
    NSUInteger endY = MIN(frame->_top + frame->_height, _height);
    for (NSUInteger y = startY; y < endY; y++)
        memset(canvas + (y * _width + startX) * 4, 0, (endX - startX) * 4);
}

- (bool)drawFrame:(OnegramGIFFrame *)frame
{
    NSData *decoded = OnegramGIFDecodeLZW(frame->_compressedData, frame->_minimumCodeSize, frame->_width * frame->_height);
    if (decoded == nil)
        return false;

    NSData *palette = frame->_palette != nil ? frame->_palette : _globalPalette;
    if (palette.length < 3)
        return false;

    if (frame->_disposal == 3)
        _restoreCanvas = [_canvas copy];
    else
        _restoreCanvas = nil;

    const uint8_t *indices = decoded.bytes;
    const uint8_t *colors = palette.bytes;
    NSUInteger colorCount = palette.length / 3;
    uint8_t *canvas = _canvas.mutableBytes;
    NSUInteger sourceOffset = 0;

    if (frame->_interlaced)
    {
        const NSUInteger starts[4] = { 0, 4, 2, 1 };
        const NSUInteger steps[4] = { 8, 8, 4, 2 };
        for (NSUInteger pass = 0; pass < 4; pass++)
        {
            for (NSUInteger row = starts[pass]; row < frame->_height; row += steps[pass])
            {
                for (NSUInteger column = 0; column < frame->_width; column++, sourceOffset++)
                {
                    uint8_t colorIndex = indices[sourceOffset];
                    if ((NSInteger)colorIndex == frame->_transparentIndex || colorIndex >= colorCount)
                        continue;
                    NSUInteger x = frame->_left + column;
                    NSUInteger y = frame->_top + row;
                    if (x >= _width || y >= _height)
                        continue;
                    uint8_t *pixel = canvas + (y * _width + x) * 4;
                    pixel[0] = colors[colorIndex * 3];
                    pixel[1] = colors[colorIndex * 3 + 1];
                    pixel[2] = colors[colorIndex * 3 + 2];
                    pixel[3] = 255;
                }
            }
        }
    }
    else
    {
        for (NSUInteger row = 0; row < frame->_height; row++)
        {
            for (NSUInteger column = 0; column < frame->_width; column++, sourceOffset++)
            {
                uint8_t colorIndex = indices[sourceOffset];
                if ((NSInteger)colorIndex == frame->_transparentIndex || colorIndex >= colorCount)
                    continue;
                NSUInteger x = frame->_left + column;
                NSUInteger y = frame->_top + row;
                if (x >= _width || y >= _height)
                    continue;
                uint8_t *pixel = canvas + (y * _width + x) * 4;
                pixel[0] = colors[colorIndex * 3];
                pixel[1] = colors[colorIndex * 3 + 1];
                pixel[2] = colors[colorIndex * 3 + 2];
                pixel[3] = 255;
            }
        }
    }

    return true;
}

- (UIImage *)currentImage
{
    size_t length = _canvas.length;
    void *copy = malloc(length);
    if (copy == NULL)
        return nil;
    memcpy(copy, _canvas.bytes, length);

    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, copy, length, OnegramGIFReleaseImageData);
    if (provider == NULL)
    {
        free(copy);
        return nil;
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = CGImageCreate(_width, _height, 8, 32, _width * 4, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    if (imageRef == NULL)
        return nil;
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return image;
}

- (UIImage *)imageAtIndex:(NSUInteger)index
{
    if (index >= _frames.count)
        return nil;

    @synchronized(self)
    {
        if ((NSInteger)index < _renderedIndex)
            [self resetRendering];

        while (_renderedIndex < (NSInteger)index)
        {
            if (_renderedFrame != nil)
            {
                if (_renderedFrame->_disposal == 2)
                    [self clearFrameRect:_renderedFrame];
                else if (_renderedFrame->_disposal == 3 && _restoreCanvas != nil)
                    [_canvas replaceBytesInRange:NSMakeRange(0, _canvas.length) withBytes:_restoreCanvas.bytes];
            }

            OnegramGIFFrame *frame = [_frames objectAtIndex:(NSUInteger)(_renderedIndex + 1)];
            if (![self drawFrame:frame])
                return nil;
            _renderedFrame = frame;
            _renderedIndex++;
        }

        return [self currentImage];
    }
}

@end

#endif

@interface FLAnimatedImage ()
{
    // Use old school ivar instead of property for retained non-object types (CF type, dispatch "object") to avoid ARC confusion: http://stackoverflow.com/questions/9684972/strong-property-with-attribute-nsobject-for-a-cf-type-doesnt-retain/9690656#9690656
#if defined(ONEGRAM_ARMV6)
    OnegramGIFSource *_imageSource;
#else
    CGImageSourceRef _imageSource;
#endif
    // Note: Only if the deployment target is iOS 6.0 or higher, dispatch objects are declared as "true objects" and participate in ARC, etc.; See <os/object.h> or https://github.com/AFNetworking/AFNetworking/pull/517 for details.
    dispatch_queue_t _serialQueue;
}

@property (nonatomic, assign, readonly) NSUInteger frameCacheSizeOptimal; // The optimal number of frames to cache based on image size & number of frames; never changes
@property (nonatomic, assign) NSUInteger frameCacheSizeMaxInternal; // Allow to cap the cache size e.g. when memory warnings occur; 0 means no specific limit (default)
@property (nonatomic, assign) NSUInteger requestedFrameIndex; // Most recently requested frame index
@property (nonatomic, assign, readonly) NSUInteger posterImageFrameIndex; // Index of non-purgable poster image; never changes
@property (nonatomic, strong, readonly) NSMutableArray *cachedFrames; // Uncached frame indexes hold `NSNull`
@property (nonatomic, strong, readonly) NSMutableIndexSet *cachedFrameIndexes; // Indexes of cached frames
@property (nonatomic, strong, readonly) NSMutableIndexSet *requestedFrameIndexes; // Indexes of frames that are currently produced in the background
@property (nonatomic, strong, readonly) NSIndexSet *allFramesIndexSet; // Default index set with the full range of indexes; never changes
@property (nonatomic, assign) NSUInteger memoryWarningCount;

// The weak proxy is used to break retain cycles with delayed actions from memory warnings.
// We are lying about the actual type here to gain static type checking and eliminate casts.
// The actual type of the object is `FLWeakProxy`. Lazily instantiated since it is not typically needed.
@property (nonatomic, strong, readonly) FLAnimatedImage *weakProxy;

@end


@implementation FLAnimatedImage

#pragma mark - Accessors
#pragma mark Public

// This is the definite value the frame cache needs to size itself to.
- (NSUInteger)frameCacheSizeCurrent
{
    NSUInteger frameCacheSizeCurrent = self.frameCacheSizeOptimal;
    
    // If set, respect the caps.
    if (self.frameCacheSizeMax > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, self.frameCacheSizeMax);
    }
    
    if (self.frameCacheSizeMaxInternal > FLAnimatedImageFrameCacheSizeNoLimit) {
        frameCacheSizeCurrent = MIN(frameCacheSizeCurrent, self.frameCacheSizeMaxInternal);
    }
    
    return frameCacheSizeCurrent;
}


- (void)setFrameCacheSizeMax:(NSUInteger)frameCacheSizeMax
{
    if (_frameCacheSizeMax != frameCacheSizeMax) {
        
        // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
        BOOL willFrameCacheSizeShrink = (frameCacheSizeMax < self.frameCacheSizeCurrent);
        
        // Update the value
        _frameCacheSizeMax = frameCacheSizeMax;
        
        if (willFrameCacheSizeShrink) {
            [self purgeFrameCacheIfNeeded];
        }
    }
}


#pragma mark Private

- (void)setFrameCacheSizeMaxInternal:(NSUInteger)frameCacheSizeMaxInternal
{
    if (_frameCacheSizeMaxInternal != frameCacheSizeMaxInternal) {
        
        // Remember whether the new cap will cause the current cache size to shrink; then we'll make sure to purge from the cache if needed.
        BOOL willFrameCacheSizeShrink = (frameCacheSizeMaxInternal < self.frameCacheSizeCurrent);
        
        // Update the value
        _frameCacheSizeMaxInternal = frameCacheSizeMaxInternal;
        
        if (willFrameCacheSizeShrink) {
            [self purgeFrameCacheIfNeeded];
        }
    }
}


// Explicit synthesizing for `readonly` property with overridden getter.
@synthesize weakProxy = _weakProxy;

- (FLAnimatedImage *)weakProxy
{
    if (!_weakProxy) {
        _weakProxy = (id)[FLWeakProxy weakProxyForObject:self];
    }
    
    return _weakProxy;
}


#pragma mark - Life Cycle

- (id)init
{
    NSLog(@"Error: Use `-initWithAnimatedGIFData:` and supply the animated GIF data as an argument to initialize an object of type `FLAnimatedImage`.");
    return nil;
}


- (instancetype)initWithAnimatedGIFData:(NSData *)data imageDrawingBlock:(UIImage *(^)(UIImage *))imageDrawingBlock
{
    BOOL hasData = ([data length] > 0);
    if (!hasData) {
        NSLog(@"Error: No animated GIF data supplied.");
        return nil;
    }

    self = [super init];
    if (self) {
        self.imageDrawingBlock = imageDrawingBlock;
        _data = data;
        _cachedFrames = [[NSMutableArray alloc] init];
        _cachedFrameIndexes = [[NSMutableIndexSet alloc] init];
        _requestedFrameIndexes = [[NSMutableIndexSet alloc] init];

#if defined(ONEGRAM_ARMV6)
        _imageSource = [[OnegramGIFSource alloc] initWithData:data];
        if (_imageSource == nil) {
            NSLog(@"Error: Failed to decode animated GIF data %@", data);
            return nil;
        }
        _loopCount = _imageSource.loopCount;
        size_t imageCount = _imageSource.frameCount;
#else
        _imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
        if (!_imageSource) {
            NSLog(@"Error: Failed to `CGImageSourceCreateWithData` for animated GIF data %@", data);
            return nil;
        }

        CFStringRef imageSourceContainerType = CGImageSourceGetType(_imageSource);
        BOOL isGIFData = UTTypeConformsTo(imageSourceContainerType, kUTTypeGIF);
        if (!isGIFData) {
            NSLog(@"Error: Supplied data is of type %@ and doesn't seem to be GIF data %@", imageSourceContainerType, data);
            return nil;
        }

        NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(_imageSource, NULL);
        _loopCount = [[[imageProperties objectForKey:(id)kCGImagePropertyGIFDictionary] objectForKey:(id)kCGImagePropertyGIFLoopCount] unsignedIntegerValue];
        size_t imageCount = CGImageSourceGetCount(_imageSource);
#endif

        NSMutableArray *delayTimesMutable = [NSMutableArray arrayWithCapacity:imageCount];
        for (size_t i = 0; i < imageCount; i++) {
#if defined(ONEGRAM_ARMV6)
            UIImage *frameImage = [_imageSource imageAtIndex:i];
            CGImageRef frameImageRef = frameImage.CGImage;
#else
            CGImageRef frameImageRef = CGImageSourceCreateImageAtIndex(_imageSource, i, NULL);
            UIImage *frameImage = frameImageRef != NULL ? [UIImage imageWithCGImage:frameImageRef] : nil;
#endif
            if (frameImageRef && frameImage) {
                if (!self.posterImage) {
                    if (_imageDrawingBlock)
                        _posterImage = _imageDrawingBlock(frameImage);
                    else
                        _posterImage = frameImage;
                    _size = _posterImage.size;
                    _posterImageFrameIndex = i;
                    self.cachedFrames[self.posterImageFrameIndex] = self.posterImage;
                    [self.cachedFrameIndexes addIndex:self.posterImageFrameIndex];
                } else {
                    self.cachedFrames[i] = [NSNull null];
                }

#if defined(ONEGRAM_ARMV6)
                NSNumber *delayTime = @([_imageSource delayAtIndex:i]);
#else
                NSDictionary *frameProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(_imageSource, i, NULL);
                NSDictionary *framePropertiesGIF = [frameProperties objectForKey:(id)kCGImagePropertyGIFDictionary];
                NSNumber *delayTime = [framePropertiesGIF objectForKey:(id)kCGImagePropertyGIFUnclampedDelayTime];
                if (!delayTime)
                    delayTime = [framePropertiesGIF objectForKey:(id)kCGImagePropertyGIFDelayTime];
#endif
                const NSTimeInterval kDelayTimeIntervalDefault = 0.1;
                if (!delayTime || [delayTime doubleValue] <= 0.0) {
                    if (i == 0)
                        delayTime = @(kDelayTimeIntervalDefault);
                    else
                        delayTime = delayTimesMutable[i - 1];
                }
                const NSTimeInterval kDelayTimeIntervalMinimum = 0.02;
                if ([delayTime floatValue] < ((float)kDelayTimeIntervalMinimum - FLT_EPSILON))
                    delayTime = @(kDelayTimeIntervalDefault);
                delayTimesMutable[i] = delayTime;
#ifndef ONEGRAM_ARMV6
                CFRelease(frameImageRef);
#endif
            } else {
#ifndef ONEGRAM_ARMV6
                if (frameImageRef != NULL)
                    CFRelease(frameImageRef);
#endif
                NSLog(@"Verbose: Dropping frame %zu because it could not be decoded.", i);
            }
        }
        _delayTimes = [delayTimesMutable copy];
        _frameCount = [_delayTimes count];

        if (self.frameCount == 0) {
            NSLog(@"Error: Failed to create any valid frames for GIF.");
            return nil;
        } else if (self.frameCount == 1) {
            NSLog(@"Verbose: Created valid GIF but with only a single frame.");
        }

        CGFloat animatedImageDataSize = CGImageGetBytesPerRow(self.posterImage.CGImage) * self.size.height * self.frameCount / MEGABYTE;
        if (animatedImageDataSize <= FLAnimatedImageDataSizeCategoryAll) {
            _frameCacheSizeOptimal = self.frameCount;
        } else if (animatedImageDataSize <= FLAnimatedImageDataSizeCategoryDefault) {
            _frameCacheSizeOptimal = FLAnimatedImageFrameCacheSizeDefault;
        } else {
            _frameCacheSizeOptimal = FLAnimatedImageFrameCacheSizeLowMemory;
        }
        _frameCacheSizeOptimal = MIN(_frameCacheSizeOptimal, self.frameCount);
        _allFramesIndexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, self.frameCount)];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_weakProxy) {
        [NSObject cancelPreviousPerformRequestsWithTarget:_weakProxy];
    }
    
#if !defined(ONEGRAM_ARMV6)
    if (_imageSource) {
        CFRelease(_imageSource);
    }
#endif
    
    // Needed for deployment target iOS 5.0
#if ((__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0) || (!defined(__IPHONE_6_0)))
    if (_serialQueue) {
        dispatch_release(_serialQueue);
    }
#endif
}


#pragma mark - Public Methods

// See header for more details.
// Note: both consumer and producer are throttled: consumer by frame timings and producer by the available memory (max buffer window size).
- (UIImage *)imageLazilyCachedAtIndex:(NSUInteger)index
{
    // Early return if the requested index is beyond bounds.
    // Note: We're comparing an index with a count and need to bail on greater than or equal to.
    if (index >= self.frameCount) {
        NSLog(@"Error: Skipping requested frame %lu beyond bounds (total frame count: %lu) for animated image: %@", (unsigned long)index,  (unsigned long)self.frameCount, self);
        return nil;
    }
    
    // Remember requested frame index, this influences what we should cache next.
    self.requestedFrameIndex = index;
    
    // Quick check to avoid doing any work if we already have all possible frames cached, a common case.
    if ([self.cachedFrameIndexes count] < self.frameCount) {
        // If we have frames that should be cached but aren't and aren't requested yet, request them.
        // Exclude existing cached frames, frames already requested, and specially cached poster image.
        NSMutableIndexSet *frameIndexesToAddToCacheMutable = [[self frameIndexesToCache] mutableCopy];
        [frameIndexesToAddToCacheMutable removeIndexes:self.cachedFrameIndexes];
        [frameIndexesToAddToCacheMutable removeIndexes:self.requestedFrameIndexes];
        [frameIndexesToAddToCacheMutable removeIndex:self.posterImageFrameIndex];
        NSIndexSet *frameIndexesToAddToCache = [frameIndexesToAddToCacheMutable copy];
        
        // Asynchronously add frames to our cache.
        if ([frameIndexesToAddToCache count] > 0) {
            [self addFrameIndexesToCache:frameIndexesToAddToCache];
        }
    }
    
    // Get the specified image. Watch out for `NSNull` placeholders.
    UIImage *image = nil;
    id tryImage = self.cachedFrames[index];
    if ([tryImage isKindOfClass:[UIImage class]]) {
        image = tryImage;
    }
    
    // Purge if needed based on the current playhead position.
    [self purgeFrameCacheIfNeeded];
    
    return image;
}


// Only called once from `-imageLazilyCachedAtIndex` but factored into its own method for logical grouping.
- (void)addFrameIndexesToCache:(NSIndexSet *)frameIndexesToAddToCache
{
    // Order matters. First, iterate over the indexes starting from the requested frame index.
    // Then, if there are any indexes before the requested frame index, do those.
    NSRange firstRange = NSMakeRange(self.requestedFrameIndex, self.frameCount - self.requestedFrameIndex);
    NSRange secondRange = NSMakeRange(0, self.requestedFrameIndex);
    if (firstRange.length + secondRange.length != self.frameCount) {
        NSLog(@"Error: Two-part frame cache range doesn't equal full range.");
    }
    
    // Add to the requested list before we actually kick them off, so they don't get into the queue twice.
    [self.requestedFrameIndexes addIndexes:frameIndexesToAddToCache];
    
    // Lazily create dedicated isolation queue.
    if (!_serialQueue) {
        _serialQueue = dispatch_queue_create("com.flipboard.framecachingqueue", DISPATCH_QUEUE_SERIAL);
    }
    
    // Start streaming requested frames in the background into the cache.
    // Avoid capturing self in the block as there's no reason to keep doing work if the animated image went away.
    FLAnimatedImage * __weak weakSelf = self;
    dispatch_async(_serialQueue, ^{
        // Produce and cache next needed frame.
        void (^frameRangeBlock)(NSRange, BOOL *) = ^(NSRange range, __unused BOOL *stop) {
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            __strong FLAnimatedImage *strongSelf = weakSelf;
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
                UIImage *image = [strongSelf predrawnImageAtIndex:i];
                // The results get returned one by one as soon as they're ready (and not in batch).
                // The benefits of having the first frames as quick as possible outweigh building up a buffer to cope with potential hiccups when the CPU suddenly gets busy.
                if (image && strongSelf) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        strongSelf.cachedFrames[i] = image;
                        [strongSelf.cachedFrameIndexes addIndex:i];
                        [strongSelf.requestedFrameIndexes removeIndex:i];
                    });
                }
            }
        };
        
        // Guard against crashing on 0-length ranges with an 'NSRangeException' "last range index (-1) beyond bounds" (Apple's error message is bogus here).
        // This is only needed on iOS 5, iPad only, running on device and only for the range {0,0} but regardless of whether the index set is mutable or immutable or what the indexes in the set are (can even be empty).
        if (firstRange.length > 0) {
            FLAnimatedImageEnumerateRanges(frameIndexesToAddToCache, firstRange, frameRangeBlock);
        }
        if (secondRange.length > 0) {
            FLAnimatedImageEnumerateRanges(frameIndexesToAddToCache, secondRange, frameRangeBlock);
        }
    });
}


+ (CGSize)sizeForImage:(id)image
{
    CGSize imageSize = CGSizeZero;
    
    // Early return for nil
    if (!image) {
        return imageSize;
    }
    
    if ([image isKindOfClass:[UIImage class]]) {
        UIImage *uiImage = (UIImage *)image;
        imageSize = uiImage.size;
    } else if ([image isKindOfClass:[FLAnimatedImage class]]) {
        FLAnimatedImage *animatedImage = (FLAnimatedImage *)image;
        imageSize = animatedImage.size;
    } else {
        // Bear trap to capture bad images; we have seen crashers cropping up on iOS 7.
        NSLog(@"Error: `image` isn't of expected types `UIImage` or `FLAnimatedImage`: %@", image);
    }
    
    return imageSize;
}


#pragma mark - Private Methods
#pragma mark Frame Loading

- (UIImage *)predrawnImageAtIndex:(NSUInteger)index
{
#if defined(ONEGRAM_ARMV6)
    UIImage *image = [_imageSource imageAtIndex:index];
#else
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(_imageSource, index, NULL);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CFRelease(imageRef);
#endif
    
    if (_imageDrawingBlock)
        image = _imageDrawingBlock(image);
    else
        image = [[self class] predrawnImageFromImage:image];
    
    return image;
}


#pragma mark Frame Caching

- (NSIndexSet *)frameIndexesToCache
{
    NSIndexSet *indexesToCache = nil;
    // Quick check to avoid building the index set if the number of frames to cache equals the total frame count.
    if (self.frameCacheSizeCurrent == self.frameCount) {
        indexesToCache = self.allFramesIndexSet;
    } else {
        NSMutableIndexSet *indexesToCacheMutable = [[NSMutableIndexSet alloc] init];
        
        // Add indexes to the set in two separate blocks- the first starting from the requested frame index, up to the limit or the end.
        // The second, if needed, the remaining number of frames beginning at index zero.
        NSUInteger firstLength = MIN(self.frameCacheSizeCurrent, self.frameCount - self.requestedFrameIndex);
        NSRange firstRange = NSMakeRange(self.requestedFrameIndex, firstLength);
        [indexesToCacheMutable addIndexesInRange:firstRange];
        NSUInteger secondLength = self.frameCacheSizeCurrent - firstLength;
        if (secondLength > 0) {
            NSRange secondRange = NSMakeRange(0, secondLength);
            [indexesToCacheMutable addIndexesInRange:secondRange];
        }
        // Double check our math, before we add the poster image index which may increase it by one.
        if ([indexesToCacheMutable count] != self.frameCacheSizeCurrent) {
            NSLog(@"Error: Number of frames to cache doesn't equal expected cache size.");
        }
        
        [indexesToCacheMutable addIndex:self.posterImageFrameIndex];
        
        indexesToCache = [indexesToCacheMutable copy];
    }
    
    return indexesToCache;
}


- (void)purgeFrameCacheIfNeeded
{
    // Purge frames that are currently cached but don't need to be.
    // But not if we're still under the number of frames to cache.
    // This way, if all frames are allowed to be cached (the common case), we can skip all the `NSIndexSet` math below.
    if ([self.cachedFrameIndexes count] > self.frameCacheSizeCurrent) {
        NSMutableIndexSet *indexesToPurge = [self.cachedFrameIndexes mutableCopy];
        [indexesToPurge removeIndexes:[self frameIndexesToCache]];
        FLAnimatedImageEnumerateRanges(indexesToPurge, NSMakeRange(0, self.frameCount), ^(NSRange range, __unused BOOL *stop) {
            // Iterate through contiguous indexes; can be faster than `enumerateIndexesInRange:options:usingBlock:`.
            for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
                [self.cachedFrameIndexes removeIndex:i];
                self.cachedFrames[i] = [NSNull null];
                // Note: Don't `CGImageSourceRemoveCacheAtIndex` on the image source for frames that we don't want cached any longer to maintain O(1) time access.
            }
        });
    }
}


- (void)growFrameCacheSizeAfterMemoryWarning:(NSNumber *)frameCacheSize
{
    self.frameCacheSizeMaxInternal = [frameCacheSize unsignedIntegerValue];
    NSLog(@"Verbose: Grew frame cache size max to %lu after memory warning for animated image: %@", (unsigned long)self.frameCacheSizeMaxInternal, self);
    
    // Schedule resetting the frame cache size max completely after a while.
    const NSTimeInterval kResetDelay = 3.0;
    [self.weakProxy performSelector:@selector(resetFrameCacheSizeMaxInternal) withObject:nil afterDelay:kResetDelay];
}


- (void)resetFrameCacheSizeMaxInternal
{
    self.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeNoLimit;
    NSLog(@"Verbose: Reset frame cache size max (current frame cache size: %lu) for animated image: %@", (unsigned long)self.frameCacheSizeCurrent, self);
}


#pragma mark System Memory Warnings Notification Handler

- (void)didReceiveMemoryWarning:(NSNotification *)__unused notification
{
    // Hold (and use!) a strong reference to self, since `NSNotificationCenter` no longer strongly references the observer.
    // This is another example of the lame fallout from the LLVM change in Xcode 5.1.
    FLAnimatedImage *strongSelf = self;
    
    strongSelf.memoryWarningCount++;
    
    // If we were about to grow larger, but got rapped on our knuckles by the system again, cancel.
    [NSObject cancelPreviousPerformRequestsWithTarget:strongSelf.weakProxy selector:@selector(growFrameCacheSizeAfterMemoryWarning:) object:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning)];
    [NSObject cancelPreviousPerformRequestsWithTarget:strongSelf.weakProxy selector:@selector(resetFrameCacheSizeMaxInternal) object:nil];
    
    // Go down to the minimum and by that implicitly immediately purge from the cache if needed to not get jettisoned by the system and start producing frames on-demand.
    NSLog(@"Verbose: Attempt setting frame cache size max to %lu (previous was %lu) after memory warning #%lu for animated image: %@", (unsigned long)FLAnimatedImageFrameCacheSizeLowMemory, (unsigned long)strongSelf.frameCacheSizeMaxInternal, (unsigned long)strongSelf.memoryWarningCount, strongSelf);
    strongSelf.frameCacheSizeMaxInternal = FLAnimatedImageFrameCacheSizeLowMemory;
    
    // Schedule growing larger again after a while, but cap our attempts to prevent a periodic sawtooth wave (ramps upward and then sharply drops) of memory usage.
    //
    // [mem]^     (2)   (5)  (6)        1) Loading frames for the first time
    //   (*)|      ,     ,    ,         2) Mem warning #1; purge cache
    //      |     /| (4)/|   /|         3) Grow cache size a bit after a while, if no mem warning occurs
    //      |    / |  _/ | _/ |         4) Try to grow cache size back to optimum after a while, if no mem warning occurs
    //      |(1)/  |_/   |/   |__(7)    5) Mem warning #2; purge cache
    //      |__/   (3)                  6) After repetition of (3) and (4), mem warning #3; purge cache
    //      +---------------------->    7) After 3 mem warnings, stay at minimum cache size
    //                            [t]
    //                                  *) The mem high water mark before we get warned might change for every cycle.
    //
    const NSUInteger kGrowAttemptsMax = 2;
    const NSTimeInterval kGrowDelay = 2.0;
    if ((strongSelf.memoryWarningCount - 1) <= kGrowAttemptsMax) {
        [strongSelf.weakProxy performSelector:@selector(growFrameCacheSizeAfterMemoryWarning:) withObject:@(FLAnimatedImageFrameCacheSizeGrowAfterMemoryWarning) afterDelay:kGrowDelay];
    }
    
    // Note: It's not possible to get the level of a memory warning with a public API: http://stackoverflow.com/questions/2915247/iphone-os-memory-warnings-what-do-the-different-levels-mean/2915477#2915477
}


#pragma mark Image Decoding

// Decodes the image's data and draws it off-screen fully in memory; it's thread-safe and hence can be called on a background thread.
// On success, the returned object is a new `UIImage` instance with the same content as the one passed in.
// On failure, the returned object is the unchanged passed in one; the data will not be predrawn in memory though and an error will be logged.
// First inspired by & good Karma to: https://gist.github.com/steipete/1144242
+ (UIImage *)predrawnImageFromImage:(UIImage *)imageToPredraw
{
    // Always use a device RGB color space for simplicity and predictability what will be going on.
    CGColorSpaceRef colorSpaceDeviceRGBRef = CGColorSpaceCreateDeviceRGB();
    // Early return on failure!
    if (!colorSpaceDeviceRGBRef) {
        NSLog(@"Error: Failed to `CGColorSpaceCreateDeviceRGB` for image %@", imageToPredraw);
        return imageToPredraw;
    }
    
    // Even when the image doesn't have transparency, we have to add the extra channel because Quartz doesn't support other pixel formats than 32 bpp/8 bpc for RGB:
    // kCGImageAlphaNoneSkipFirst, kCGImageAlphaNoneSkipLast, kCGImageAlphaPremultipliedFirst, kCGImageAlphaPremultipliedLast
    // (source: docs "Quartz 2D Programming Guide > Graphics Contexts > Table 2-1 Pixel formats supported for bitmap graphics contexts")
    size_t numberOfComponents = CGColorSpaceGetNumberOfComponents(colorSpaceDeviceRGBRef) + 1; // 4: RGB + A
    
    // "In iOS 4.0 and later, and OS X v10.6 and later, you can pass NULL if you want Quartz to allocate memory for the bitmap." (source: docs)
    void *data = NULL;
    size_t width = (size_t)imageToPredraw.size.width;
    size_t height = (size_t)imageToPredraw.size.height;
    size_t bitsPerComponent = CHAR_BIT;
    
    size_t bitsPerPixel = (bitsPerComponent * numberOfComponents);
    size_t bytesPerPixel = (bitsPerPixel / BYTE_SIZE);
    size_t bytesPerRow = (bytesPerPixel * width);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageToPredraw.CGImage);
    // If the alpha info doesn't match to one of the supported formats (see above), pick a reasonable supported one.
    // "For bitmaps created in iOS 3.2 and later, the drawing environment uses the premultiplied ARGB format to store the bitmap data." (source: docs)
    if (alphaInfo == kCGImageAlphaNone || alphaInfo == kCGImageAlphaOnly) {
        alphaInfo = kCGImageAlphaNoneSkipFirst;
    } else if (alphaInfo == kCGImageAlphaFirst) {
        alphaInfo = kCGImageAlphaPremultipliedFirst;
    } else if (alphaInfo == kCGImageAlphaLast) {
        alphaInfo = kCGImageAlphaPremultipliedLast;
    }
    // "The constants for specifying the alpha channel information are declared with the `CGImageAlphaInfo` type but can be passed to this parameter safely." (source: docs)
    bitmapInfo |= alphaInfo;
    
    // Create our own graphics context to draw to; `UIGraphicsGetCurrentContext`/`UIGraphicsBeginImageContextWithOptions` doesn't create a new context but returns the current one which isn't thread-safe (e.g. main thread could use it at the same time).
    // Note: It's not worth caching the bitmap context for multiple frames ("unique key" would be `width`, `height` and `hasAlpha`), it's ~50% slower. Time spent in libRIP's `CGSBlendBGRA8888toARGB8888` suddenly shoots up -- not sure why.
    CGContextRef bitmapContextRef = CGBitmapContextCreate(data, width, height, bitsPerComponent, bytesPerRow, colorSpaceDeviceRGBRef, bitmapInfo);
    CGColorSpaceRelease(colorSpaceDeviceRGBRef);
    // Early return on failure!
    if (!bitmapContextRef) {
        NSLog(@"Error: Failed to `CGBitmapContextCreate` with color space %@ and parameters (width: %zu height: %zu bitsPerComponent: %zu bytesPerRow: %zu) for image %@", colorSpaceDeviceRGBRef, width, height, bitsPerComponent, bytesPerRow, imageToPredraw);
        return imageToPredraw;
    }
    
    // Draw image in bitmap context and create image by preserving receiver's properties.
    CGContextDrawImage(bitmapContextRef, CGRectMake(0.0, 0.0, imageToPredraw.size.width, imageToPredraw.size.height), imageToPredraw.CGImage);
    CGImageRef predrawnImageRef = CGBitmapContextCreateImage(bitmapContextRef);
    UIImage *predrawnImage = [UIImage imageWithCGImage:predrawnImageRef scale:imageToPredraw.scale orientation:imageToPredraw.imageOrientation];
    CGImageRelease(predrawnImageRef);
    CGContextRelease(bitmapContextRef);
    
    // Early return on failure!
    if (!predrawnImage) {
        NSLog(@"Error: Failed to `imageWithCGImage:scale:orientation:` with image ref %@ created with color space %@ and bitmap context %@ and properties and properties (scale: %f orientation: %ld) for image %@", predrawnImageRef, colorSpaceDeviceRGBRef, bitmapContextRef, imageToPredraw.scale, (long)imageToPredraw.imageOrientation, imageToPredraw);
        return imageToPredraw;
    }
    
    return predrawnImage;
}


#pragma mark - Description

- (NSString *)description
{
    NSString *description = [super description];
    
    description = [description stringByAppendingFormat:@" size=%@", NSStringFromCGSize(self.size)];
    description = [description stringByAppendingFormat:@" frameCount=%lu", (unsigned long)self.frameCount];
    
    return description;
}


@end


#pragma mark - FLWeakProxy

@interface FLWeakProxy ()

@property (nonatomic, weak) id target;

@end


@implementation FLWeakProxy

#pragma mark Life Cycle

// This is the designated creation method of an `FLWeakProxy` and
// as a subclass of `NSProxy` it doesn't respond to or need `-init`.
+ (instancetype)weakProxyForObject:(id)targetObject
{
    FLWeakProxy *weakProxy = [FLWeakProxy alloc];
    weakProxy.target = targetObject;
    return weakProxy;
}


#pragma mark Forwarding Messages

- (id)forwardingTargetForSelector:(SEL)__unused selector
{
    // Keep it lightweight: access the ivar directly
    return _target;
}


#pragma mark - NSWeakProxy Method Overrides
#pragma mark Handling Unimplemented Methods

- (void)forwardInvocation:(NSInvocation *)invocation
{
    // Fallback for when target is nil. Don't do anything, just return 0/NULL/nil.
    // The method signature we've received to get here is just a dummy to keep `doesNotRecognizeSelector:` from firing.
    // We can't really handle struct return types here because we don't know the length.
    void *nullPointer = NULL;
    [invocation setReturnValue:&nullPointer];
}


- (NSMethodSignature *)methodSignatureForSelector:(SEL)__unused selector
{
    // We only get here if `forwardingTargetForSelector:` returns nil.
    // In that case, our weak target has been reclaimed. Return a dummy method signature to keep `doesNotRecognizeSelector:` from firing.
    // We'll emulate the Obj-c messaging nil behavior by setting the return value to nil in `forwardInvocation:`, but we'll assume that the return value is `sizeof(void *)`.
    // Other libraries handle this situation by making use of a global method signature cache, but that seems heavier than necessary and has issues as well.
    // See https://www.mikeash.com/pyblog/friday-qa-2010-02-26-futures.html and https://github.com/steipete/PSTDelegateProxy/issues/1 for examples of using a method signature cache.
    return [NSObject instanceMethodSignatureForSelector:@selector(init)];
}


@end
