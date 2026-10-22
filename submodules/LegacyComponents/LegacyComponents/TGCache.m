#import "TGCache.h"

#import "LegacyComponentsInternal.h"
#import "../../../OnegramPlatform/OGPlatformDispatch.h"

#import "TGImageUtils.h"
#import "../../../OnegramPlatform/OGMemoryCache.h"

#import <objc/runtime.h>
#include <stdio.h>
#include <unistd.h>
#import <CommonCrypto/CommonDigest.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <ImageIO/ImageIO.h>
#endif

static char TGCacheDiskQueueKey;

static void TGCacheExecuteMemoryBlock(id owner, dispatch_block_t block)
{
    @synchronized (owner)
    {
        block();
    }
}

static NSUInteger TGCacheImageCost(UIImage *image)
{
    CGImageRef cgImage = image.CGImage;
    uint64_t size = cgImage != NULL ? (uint64_t)CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage) : 0;
    if (size == 0)
        size = (uint64_t)ceil(image.size.width * image.scale) * (uint64_t)ceil(image.size.height * image.scale) * 4;
    return size > NSUIntegerMax ? NSUIntegerMax : (NSUInteger)size;
}

static NSString *md5String(NSString *string)
{
    
    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[16];
    CC_MD5(ptr, (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], md5Buffer);
    NSString *output = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
    return output;
}

static NSFileManager *cacheFileManager = nil;

static NSString *TGCacheNormalizedKey(NSString *url)
{
    if (url.length < 10)
        return url;
    NSUInteger bodyLocation = 0;
    if ([url hasPrefix:@"{filter:"])
    {
        NSRange closeRange = [url rangeOfString:@"}"];
        if (closeRange.location == NSNotFound)
            return url;
        bodyLocation = closeRange.location + 1;
        if ([url rangeOfString:@"peerphoto:" options:NSAnchoredSearch range:NSMakeRange(bodyLocation, url.length - bodyLocation)].location == NSNotFound)
            return url;
    }
    else if (![url hasPrefix:@"peerphoto:"])
        return url;

    NSUInteger length = url.length;
    NSUInteger separators[6];
    NSUInteger separatorCount = 0;
    CFStringInlineBuffer buffer;
    CFStringInitInlineBuffer((__bridge CFStringRef)url, &buffer, CFRangeMake((CFIndex)bodyLocation, (CFIndex)(length - bodyLocation)));
    for (NSUInteger index = 0; index < length - bodyLocation; index++)
    {
        if (CFStringGetCharacterFromInlineBuffer(&buffer, (CFIndex)index) != ':')
            continue;
        if (separatorCount == 6)
            return url;
        separators[separatorCount++] = bodyLocation + index;
    }
    if (separatorCount != 6)
        return url;

    NSMutableString *normalized = [[NSMutableString alloc] initWithCapacity:length];
    if (bodyLocation != 0)
        [normalized appendString:[url substringToIndex:bodyLocation]];
    [normalized appendString:@"peerphoto"];
    [normalized appendString:[url substringWithRange:NSMakeRange(separators[1], separators[3] - separators[1])]];
    [normalized appendString:[url substringWithRange:NSMakeRange(separators[4], length - separators[4])]];
    return normalized;
}

static bool TGCacheIsAvatarKey(NSString *key)
{
    return [key hasPrefix:@"{filter:"] && [key rangeOfString:@"}peerphoto:"].location != NSNotFound;
}

typedef struct
{
    uint32_t magic;
    uint32_t width;
    uint32_t height;
    uint32_t bytesPerRow;
    float scale;
    uint32_t reserved[3];
} TGCacheRenderedImageHeader;

static const uint32_t TGCacheRenderedImageMagic = 0x4f474131;
static const size_t TGCacheRenderedImageMaximumSide = 512;

static NSData *TGCacheRenderedImageData(UIImage *image)
{
    CGImageRef cgImage = image.CGImage;
    if (cgImage == NULL || image.imageOrientation != UIImageOrientationUp)
        return nil;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    if (width == 0 || height == 0 || width > TGCacheRenderedImageMaximumSide || height > TGCacheRenderedImageMaximumSide)
        return nil;
    size_t bytesPerRow = (width * 4 + 15) & ~(size_t)15;

    TGCacheRenderedImageHeader header;
    memset(&header, 0, sizeof(header));
    header.magic = TGCacheRenderedImageMagic;
    header.width = (uint32_t)width;
    header.height = (uint32_t)height;
    header.bytesPerRow = (uint32_t)bytesPerRow;
    header.scale = image.scale > 0.0f ? (float)image.scale : 1.0f;

    NSMutableData *data = [[NSMutableData alloc] initWithLength:sizeof(header) + bytesPerRow * height];
    uint8_t *bytes = (uint8_t *)data.mutableBytes;
    if (bytes == NULL)
        return nil;
    memcpy(bytes, &header, sizeof(header));

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bytes + sizeof(header), width, height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return nil;
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height), cgImage);
    CGContextRelease(context);
    return data;
}

static void TGCacheReleaseRenderedImageData(void *info, const void *__unused data, size_t __unused size)
{
    if (info != NULL)
        CFRelease(info);
}

static UIImage *TGCacheImageFromRenderedData(NSData *data)
{
    if (data.length < sizeof(TGCacheRenderedImageHeader))
        return nil;
    TGCacheRenderedImageHeader header;
    memcpy(&header, data.bytes, sizeof(header));
    if (header.magic != TGCacheRenderedImageMagic || header.width == 0 || header.height == 0 || header.width > TGCacheRenderedImageMaximumSide || header.height > TGCacheRenderedImageMaximumSide)
        return nil;
    if (header.bytesPerRow < header.width * 4 || !(header.scale >= 1.0f && header.scale <= 4.0f))
        return nil;
    size_t pixelLength = (size_t)header.bytesPerRow * header.height;
    if (data.length != sizeof(header) + pixelLength)
        return nil;

    CGDataProviderRef provider = CGDataProviderCreateWithData((__bridge_retained void *)data, (const uint8_t *)data.bytes + sizeof(header), pixelLength, TGCacheReleaseRenderedImageData);
    if (provider == NULL)
        return nil;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(header.width, header.height, 8, 32, header.bytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    if (cgImage == NULL)
        return nil;
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:header.scale orientation:UIImageOrientationUp];
    CGImageRelease(cgImage);
    return image;
}

static dispatch_queue_t TGCacheRenderedAvatarQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("org.onegram.cache.avatar", 0);
    });
    return queue;
}

static dispatch_queue_t TGCacheRenderedAvatarPrefetchQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("org.onegram.cache.avatar-prefetch", 0);
    });
    return queue;
}

@interface TGCache ()

@property (nonatomic, strong) NSMutableArray *temporaryCachedImagesSources;
@property (nonatomic, strong) OGMemoryCache *memoryCache;
@property (nonatomic, strong) OGMemoryCache *thumbnailCache;
@property (nonatomic, strong) OGMemoryCache *dataMemoryCache;
@property (nonatomic, strong) OGMemoryCache *avatarMemoryCache;
@property (nonatomic, strong) NSMutableSet *renderedAvatarStoredKeys;
@property (nonatomic, strong) NSMutableSet *renderedAvatarMissingKeys;
@property (nonatomic, strong) NSMutableSet *renderedAvatarPendingPrefetchKeys;

@end

@implementation TGCache

+ (dispatch_queue_t)diskCacheQueue
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.telegraph.diskcache", 0);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        dispatch_queue_set_specific(queue, &TGCacheDiskQueueKey, &TGCacheDiskQueueKey, NULL);
        
        if (cacheFileManager == nil)
            cacheFileManager = [[NSFileManager alloc] init];
    });
    return queue;
}

+ (NSFileManager *)diskFileManager
{
    [self diskCacheQueue];
    return cacheFileManager;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        int memorySize = deviceMemorySize();
        if (memorySize <= 512)
        {
            _imageMemoryLimit = 12 * 1024 * 1024;
            _thumbnailMemoryLimit = 1536 * 1024;
            _dataMemoryLimit = 1024 * 1024;
            _avatarMemoryLimit = 6 * 1024 * 1024;
            _diskLimit = 64 * 1024 * 1024;
            _memoryWarningBaseline = 1536 * 1024;
            _backgroundBaseline = 4 * 1024 * 1024;
        }
        else if (memorySize <= 1024)
        {
            _imageMemoryLimit = 20 * 1024 * 1024;
            _thumbnailMemoryLimit = 3 * 1024 * 1024;
            _dataMemoryLimit = 2 * 1024 * 1024;
            _avatarMemoryLimit = 10 * 1024 * 1024;
            _diskLimit = 96 * 1024 * 1024;
            _memoryWarningBaseline = 2 * 1024 * 1024;
            _backgroundBaseline = 8 * 1024 * 1024;
        }
        else if (memorySize <= 2048)
        {
            _imageMemoryLimit = 32 * 1024 * 1024;
            _thumbnailMemoryLimit = 5 * 1024 * 1024;
            _dataMemoryLimit = 3 * 1024 * 1024;
            _avatarMemoryLimit = 16 * 1024 * 1024;
            _diskLimit = 128 * 1024 * 1024;
            _memoryWarningBaseline = 3 * 1024 * 1024;
            _backgroundBaseline = 12 * 1024 * 1024;
        }
        else if (memorySize <= 4096)
        {
            _imageMemoryLimit = 64 * 1024 * 1024;
            _thumbnailMemoryLimit = 8 * 1024 * 1024;
            _dataMemoryLimit = 6 * 1024 * 1024;
            _avatarMemoryLimit = 24 * 1024 * 1024;
            _diskLimit = 192 * 1024 * 1024;
            _memoryWarningBaseline = 4 * 1024 * 1024;
            _backgroundBaseline = 20 * 1024 * 1024;
        }
        else
        {
            _imageMemoryLimit = 96 * 1024 * 1024;
            _thumbnailMemoryLimit = 12 * 1024 * 1024;
            _dataMemoryLimit = 8 * 1024 * 1024;
            _avatarMemoryLimit = 32 * 1024 * 1024;
            _diskLimit = 256 * 1024 * 1024;
            _memoryWarningBaseline = 6 * 1024 * 1024;
            _backgroundBaseline = 32 * 1024 * 1024;
        }
#if defined(ONEGRAM_ARMV6)
        _imageMemoryLimit = 6 * 1024 * 1024;
        _thumbnailMemoryLimit = 1536 * 1024;
        _dataMemoryLimit = 512 * 1024;
        _avatarMemoryLimit = 3 * 1024 * 1024;
        _diskLimit = 48 * 1024 * 1024;
        _memoryWarningBaseline = 512 * 1024;
        _backgroundBaseline = 2 * 1024 * 1024;
#endif
        _imageMemoryEvictionInterval = MAX(512 * 1024, _imageMemoryLimit / 8);
        _thumbnailEvictionInterval = MAX(256 * 1024, _thumbnailMemoryLimit / 8);
        _dataMemoryEvictionInterval = MAX(256 * 1024, _dataMemoryLimit / 8);
        _diskEvictionInterval = MAX(8 * 1024 * 1024, _diskLimit / 8);
        
        _temporaryCachedImagesSources = [[NSMutableArray alloc] init];
        
        _memoryCache = [[OGMemoryCache alloc] initWithCountLimit:0 costLimit:(NSUInteger)_imageMemoryLimit];
        _thumbnailCache = [[OGMemoryCache alloc] initWithCountLimit:0 costLimit:(NSUInteger)_thumbnailMemoryLimit];
        _dataMemoryCache = [[OGMemoryCache alloc] initWithCountLimit:0 costLimit:(NSUInteger)_dataMemoryLimit];
        _avatarMemoryCache = [[OGMemoryCache alloc] initWithCountLimit:0 costLimit:(NSUInteger)_avatarMemoryLimit];
        _renderedAvatarStoredKeys = [[NSMutableSet alloc] init];
        _renderedAvatarMissingKeys = [[NSMutableSet alloc] init];
        _renderedAvatarPendingPrefetchKeys = [[NSMutableSet alloc] init];

        NSString *cachesPath = [[LegacyComponentsGlobals provider] dataCachePath];
        
        _diskCachePath = cachesPath;
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if (![fileManager fileExistsAtPath:_diskCachePath])
            [fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning:(NSNotification *)__unused notification
{
    [self freeMemoryCache:_memoryWarningBaseline];
    [_avatarMemoryCache trimToCost:(NSUInteger)MAX(0, _avatarMemoryLimit / 4)];
}

- (void)didEnterBackground:(NSNotification *)__unused notification
{
    [self freeMemoryCache:_backgroundBaseline];
    [_avatarMemoryCache trimToCost:(NSUInteger)MAX(0, _avatarMemoryLimit / 2)];
}

- (NSString *)diskPathForUrl:(NSString *)url
{
    NSString *key = TGCacheNormalizedKey(url);
    NSString *path = [_diskCachePath stringByAppendingPathComponent:md5String(key)];
    if (key != url)
    {
        const char *targetPath = [path fileSystemRepresentation];
        if (targetPath != NULL && access(targetPath, F_OK) != 0)
        {
            const char *legacyPath = [[_diskCachePath stringByAppendingPathComponent:md5String(url)] fileSystemRepresentation];
            if (legacyPath != NULL)
                rename(legacyPath, targetPath);
        }
    }
    return path;
}

- (NSString *)renderedAvatarPathForKey:(NSString *)key
{
    return [_diskCachePath stringByAppendingPathComponent:[@"rendered-" stringByAppendingString:md5String(key)]];
}

- (OGMemoryCache *)memoryCacheForKey:(NSString *)key
{
    return TGCacheIsAvatarKey(key) ? _avatarMemoryCache : _memoryCache;
}

- (bool)isRenderedAvatarKey:(NSString *)url
{
    return TGCacheIsAvatarKey(TGCacheNormalizedKey(url));
}

- (void)storeRenderedAvatarImage:(UIImage *)image key:(NSString *)key
{
    if (image == nil || key.length == 0)
        return;
    @synchronized (_renderedAvatarStoredKeys)
    {
        if ([_renderedAvatarStoredKeys containsObject:key])
            return;
        [_renderedAvatarStoredKeys addObject:key];
        [_renderedAvatarMissingKeys removeObject:key];
    }
    dispatch_async(TGCacheRenderedAvatarQueue(), ^
    {
        @autoreleasepool
        {
            NSString *path = [self renderedAvatarPathForKey:key];
            const char *filePath = [path fileSystemRepresentation];
            if (filePath != NULL && access(filePath, F_OK) == 0)
                return;
            NSData *data = TGCacheRenderedImageData(image);
            if (data == nil || ![data writeToFile:path atomically:true])
            {
                @synchronized (_renderedAvatarStoredKeys)
                {
                    [_renderedAvatarStoredKeys removeObject:key];
                }
            }
        }
    });
}

- (UIImage *)readRenderedAvatarForKey:(NSString *)key storeInMemory:(bool)storeInMemory
{
    UIImage *image = [_avatarMemoryCache objectForKey:key];
    if (image != nil)
        return image;
    @synchronized (_renderedAvatarStoredKeys)
    {
        if ([_renderedAvatarMissingKeys containsObject:key])
            return nil;
    }

    NSString *path = [self renderedAvatarPathForKey:key];
    NSData *data = [[NSData alloc] initWithContentsOfFile:path];
    image = TGCacheImageFromRenderedData(data);
    @synchronized (_renderedAvatarStoredKeys)
    {
        if (image != nil)
            [_renderedAvatarStoredKeys addObject:key];
        else if (![_renderedAvatarStoredKeys containsObject:key])
            [_renderedAvatarMissingKeys addObject:key];
    }
    if (image == nil)
    {
        if (data != nil)
            unlink([path fileSystemRepresentation]);
        return nil;
    }

    NSUInteger cost = TGCacheImageCost(image);
    if (storeInMemory && _avatarMemoryLimit > 0)
    {
        _avatarMemoryCache.costLimit = (NSUInteger)_avatarMemoryLimit;
        [_avatarMemoryCache setObject:image forKey:key cost:cost];
    }
    else if (!storeInMemory && _avatarMemoryLimit > 0 && _avatarMemoryCache.totalCost + cost <= (uint64_t)_avatarMemoryLimit * 9 / 10)
    {
        _avatarMemoryCache.costLimit = (NSUInteger)_avatarMemoryLimit;
        [_avatarMemoryCache setObject:image forKey:key cost:cost];
    }
    return image;
}

- (void)loadRenderedAvatar:(NSString *)url completion:(void (^)(UIImage *image))completion
{
    if (completion == nil)
        return;
    NSString *key = TGCacheNormalizedKey(url);
    if (!TGCacheIsAvatarKey(key))
    {
        completion(nil);
        return;
    }
    UIImage *memoryImage = [_avatarMemoryCache objectForKey:key];
    if (memoryImage != nil)
    {
        completion(memoryImage);
        return;
    }
    @synchronized (_renderedAvatarStoredKeys)
    {
        if ([_renderedAvatarMissingKeys containsObject:key])
        {
            completion(nil);
            return;
        }
    }
    dispatch_async(TGCacheRenderedAvatarQueue(), ^
    {
        UIImage *image = nil;
        @autoreleasepool
        {
            image = [self readRenderedAvatarForKey:key storeInMemory:true];
        }
        completion(image);
    });
}

- (void)prefetchRenderedAvatar:(NSString *)url completion:(void (^)(UIImage *image))completion
{
    NSString *key = TGCacheNormalizedKey(url);
    if (!TGCacheIsAvatarKey(key))
    {
        if (completion != nil)
            completion(nil);
        return;
    }
    UIImage *memoryImage = [_avatarMemoryCache objectForKey:key];
    if (memoryImage != nil)
    {
        if (completion != nil)
            completion(memoryImage);
        return;
    }
    @synchronized (_renderedAvatarStoredKeys)
    {
        if ([_renderedAvatarMissingKeys containsObject:key])
        {
            if (completion != nil)
                completion(nil);
            return;
        }
        if (completion == nil)
        {
            if ([_renderedAvatarPendingPrefetchKeys containsObject:key])
                return;
            [_renderedAvatarPendingPrefetchKeys addObject:key];
        }
    }
    dispatch_async(TGCacheRenderedAvatarPrefetchQueue(), ^
    {
        UIImage *image = nil;
        @autoreleasepool
        {
            image = [self readRenderedAvatarForKey:key storeInMemory:false];
        }
        if (completion == nil)
        {
            @synchronized (_renderedAvatarStoredKeys)
            {
                [_renderedAvatarPendingPrefetchKeys removeObject:key];
            }
        }
        else
            completion(image);
    });
}

- (void)addTemporaryCachedImagesSource:(NSDictionary *)source autoremove:(bool)autoremove
{
    dispatch_block_t block = ^
    {
        [_temporaryCachedImagesSources addObject:source];
        if (autoremove)
        {
            OGPlatformDispatchAfterCurrentMainRunLoop(^{
                [self removeTemporaryCachedImageSource:source];
            });
        }
    };
    
    TGCacheExecuteMemoryBlock(self, block);
}

- (void)removeTemporaryCachedImageSource:(NSDictionary *)source
{
    dispatch_block_t block = ^
    {
        [_temporaryCachedImagesSources removeObject:source];
    };
    
    TGCacheExecuteMemoryBlock(self, block);
}

- (void)freeMemoryCache:(NSUInteger)targetSize
{
    [_memoryCache trimToCost:targetSize];
}

- (void)freeThumbnailCache:(NSUInteger)targetSize
{
    [_thumbnailCache trimToCost:targetSize];
}

- (void)cacheCompressedObject:(NSData *)data url:(NSString *)url
{
    url = TGCacheNormalizedKey(url);
    if (_dataMemoryLimit <= 0)
    {
        [_dataMemoryCache removeAllObjects];
        return;
    }
    _dataMemoryCache.costLimit = (NSUInteger)_dataMemoryLimit;
    [_dataMemoryCache setObject:data forKey:url cost:data.length];
}

- (void)cacheImage:(UIImage *)image withData:(NSData *)data url:(NSString *)url availability:(int)availability
{
    [self cacheImage:image withData:data url:url availability:availability completion:nil];
}

- (void)cacheImage:(UIImage *)image withData:(NSData *)data url:(NSString *)rawUrl availability:(int)availability completion:(void (^)(void))completion
{
    NSString *url = TGCacheNormalizedKey(rawUrl);
    if (image != nil && (availability & TGCacheMemory) && url != nil)
    {
        if (TGCacheIsAvatarKey(url))
        {
            if (_avatarMemoryLimit <= 0)
                [_avatarMemoryCache removeAllObjects];
            else
            {
                _avatarMemoryCache.costLimit = (NSUInteger)_avatarMemoryLimit;
                [_avatarMemoryCache setObject:image forKey:url cost:TGCacheImageCost(image)];
            }
            [self storeRenderedAvatarImage:image key:url];
        }
        else if (_imageMemoryLimit <= 0)
            [_memoryCache removeAllObjects];
        else
        {
            _memoryCache.costLimit = (NSUInteger)_imageMemoryLimit;
            [_memoryCache setObject:image forKey:url cost:TGCacheImageCost(image)];
        }
    }
    
    if ((data != nil || image != nil) && (availability & TGCacheDisk) && url != nil)
    {
        dispatch_async([TGCache diskCacheQueue], ^
        {   
            if (data != nil)
            {
                [self cacheCompressedObject:data url:url];

                [data writeToFile:[self diskPathForUrl:url] atomically:true];
                
                if (completion != nil)
                    completion();
            }
        });
    }
}

- (UIImage *)cachedImage:(NSString *)rawUrl availability:(int)availability
{
    if (rawUrl.length == 0)
        return nil;
    NSString *url = TGCacheNormalizedKey(rawUrl);
    UIImage *image = nil;
    
    if (availability & TGCacheMemory)
    {
        image = [[self memoryCacheForKey:url] objectForKey:url];
        if (image == nil)
        {
            @synchronized (self)
            {
                for (NSDictionary *source in _temporaryCachedImagesSources)
                {
                    image = [source objectForKey:url];
                    if (image == nil && url != rawUrl)
                        image = [source objectForKey:rawUrl];
                    if (image != nil)
                        break;
                }
            }
        }
    }

    if (image != nil)
        return image;
    
    if (availability & TGCacheDisk)
    {
        UIImage *dataImage = nil;
        
        NSData *data = [_dataMemoryCache objectForKey:url];
        if (data != nil)
        {
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
            dataImage = [[UIImage alloc] initWithData:data];
#else
            NSDictionary *options = @{ (__bridge NSString *)kCGImageSourceShouldCache: @YES };
            CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
            if (source != NULL)
            {
                CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)options);
                if (cgImage != NULL)
                {
                    dataImage = [[UIImage alloc] initWithCGImage:cgImage];
                    CGImageRelease(cgImage);
                }
                CFRelease(source);
            }
#endif
            if (dataImage != nil && (availability & TGCacheMemory))
                [self cacheImage:dataImage withData:nil url:url availability:TGCacheMemory];
        }

        if (dataImage != nil)
            return dataImage;
        
        __block UIImage *diskImageResult = nil;
        dispatch_block_t readDisk = ^
        {
            NSURL *realUrl = [[NSURL alloc] initFileURLWithPath:[self diskPathForUrl:rawUrl]];
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
            UIImage *diskImage = [UIImage imageWithContentsOfFile:[realUrl path]];
#else
            NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:true] forKey:(id)kCGImageSourceShouldCache];
            CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)realUrl, NULL);
            UIImage *diskImage = nil;
            if (source != nil)
            {
                CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)dict);
                if (cgImage != NULL)
                {
                    diskImage = [UIImage imageWithCGImage:cgImage];
                    CGImageRelease(cgImage);
                }
                CFRelease(source);
            }
#endif
            if (diskImage != nil && (availability & TGCacheMemory))
                [self cacheImage:diskImage withData:nil url:url availability:TGCacheMemory];
            if (diskImage != nil)
            {
                diskImageResult = diskImage;
                dispatch_async([TGCache diskCacheQueue], ^
                {
                    NSData *data = [[NSData alloc] initWithContentsOfURL:realUrl];
                    if (data != nil)
                        [self cacheCompressedObject:data url:url];
                });
            }
        };
        [TGCache diskCacheQueue];
        if (dispatch_get_specific(&TGCacheDiskQueueKey) != NULL)
            readDisk();
        else
            dispatch_sync([TGCache diskCacheQueue], readDisk);
        image = diskImageResult;
        return image;
    }
    
    return nil;
}

- (NSData *)cachedDataForUrl:(NSString *)rawUrl
{
    if (rawUrl.length == 0)
        return nil;
    NSString *url = TGCacheNormalizedKey(rawUrl);

    NSData *data = [_dataMemoryCache objectForKey:url];

    if (data != nil)
        return data;

    data = [[NSData alloc] initWithContentsOfFile:[self diskPathForUrl:rawUrl]];
    if (data != nil)
        [self cacheCompressedObject:data url:url];
    return data;
}

- (void)removeFromMemoryCache:(NSString *)rawUrl matchEnd:(bool)matchEnd
{
    if (rawUrl == nil)
        return;
    NSString *url = TGCacheNormalizedKey(rawUrl);
    
    if (matchEnd)
    {
        BOOL (^predicate)(NSString *) = ^BOOL(NSString *key)
        {
            return [key hasSuffix:url];
        };
        [_memoryCache removeObjectsMatchingKeyPredicate:predicate];
        [_avatarMemoryCache removeObjectsMatchingKeyPredicate:predicate];
    }
    else
        [[self memoryCacheForKey:url] removeObjectForKey:url];
    [_dataMemoryCache removeObjectForKey:url];
}

- (void)cacheThumbnail:(UIImage *)image url:(NSString *)rawUrl
{
    NSString *url = TGCacheNormalizedKey(rawUrl);
    if ([self cachedThumbnail:url] != nil)
        return;
    
    if (image != nil)
    {
        int side = 32;
        if (!TGIsRetina())
            side *= 2;
        if (image.size.width > side || image.size.height > side)
        {
            image = TGScaleImage(image, CGSizeMake(side, side));
        }
        else
            return;
        
        if (_thumbnailMemoryLimit <= 0)
            [_thumbnailCache removeAllObjects];
        else
        {
            _thumbnailCache.costLimit = (NSUInteger)_thumbnailMemoryLimit;
            [_thumbnailCache setObject:image forKey:url cost:TGCacheImageCost(image)];
        }
    }
}

- (UIImage *)cachedThumbnail:(NSString *)url
{
    if (url.length == 0)
        return nil;
    return [_thumbnailCache objectForKey:TGCacheNormalizedKey(url)];
}

- (void)diskCacheContains:(NSString *)url1 orUrl:(NSString *)url2 completion:(void (^)(bool containsFirst, bool containsSecond))completion
{   
    dispatch_async([TGCache diskCacheQueue], ^
    {
        bool cached = url1 != nil && [cacheFileManager fileExistsAtPath:[self diskPathForUrl:url1]];
        if (cached)
        {
            if (completion)
                completion(true, false);
        }
        else if (url2 != nil)
        {
            cached = [cacheFileManager fileExistsAtPath:[self diskPathForUrl:url2]];
            if (completion)
                completion(false, cached);
        }
        else
        {
            if (completion)
                completion(false, false);
        }
    });
}

- (bool)diskCacheContainsSync:(NSString *)url
{
    __block bool result = false;
    
    dispatch_block_t check = ^
    {
        result = [cacheFileManager fileExistsAtPath:[self diskPathForUrl:url]];
    };
    [TGCache diskCacheQueue];
    if (dispatch_get_specific(&TGCacheDiskQueueKey) != NULL)
        check();
    else
        dispatch_sync([TGCache diskCacheQueue], check);

    return result;
}

- (void)removeFromDiskCache:(NSString *)url
{
    if (url.length == 0)
        return;

    [_dataMemoryCache removeObjectForKey:TGCacheNormalizedKey(url)];

    dispatch_async([TGCache diskCacheQueue], ^
    {
        [cacheFileManager removeItemAtPath:[self diskPathForUrl:url] error:nil];
    });
}

- (NSString *)pathForCachedData:(NSString *)url
{
    return [self diskPathForUrl:url];
}

- (void)changeCacheItemUrl:(NSString *)oldUrl newUrl:(NSString *)newUrl
{
    NSString *oldKey = TGCacheNormalizedKey(oldUrl);
    NSString *newKey = TGCacheNormalizedKey(newUrl);
    OGMemoryCache *oldMemoryCache = [self memoryCacheForKey:oldKey];
    OGMemoryCache *newMemoryCache = [self memoryCacheForKey:newKey];
    if (oldMemoryCache == newMemoryCache)
        [oldMemoryCache moveObjectForKey:oldKey toKey:newKey];
    else
        [oldMemoryCache removeObjectForKey:oldKey];
    [_dataMemoryCache moveObjectForKey:oldKey toKey:newKey];

    dispatch_async([TGCache diskCacheQueue], ^
    {
        NSError *error = nil;
        [cacheFileManager moveItemAtPath:[self diskPathForUrl:oldUrl] toPath:[self diskPathForUrl:newUrl] error:&error];
        if (error != nil)
            TGLegacyLog(@"Failed to move: %@", error);
    });
}

- (void)moveToCache:(NSString *)fileUrl cacheUrl:(NSString *)cacheUrl
{
    NSString *cacheKey = TGCacheNormalizedKey(cacheUrl);
    OGMemoryCache *targetMemoryCache = [self memoryCacheForKey:cacheKey];
    if (targetMemoryCache == _memoryCache)
        [_memoryCache moveObjectForKey:fileUrl toKey:cacheKey];
    else
        [_memoryCache removeObjectForKey:fileUrl];

    dispatch_async([TGCache diskCacheQueue], ^
    {
        NSError *error = nil;

        NSString *targetPath = [self diskPathForUrl:cacheUrl];
        if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath])
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:NULL];
        
        [cacheFileManager moveItemAtPath:fileUrl toPath:targetPath error:&error];
        if (error != nil)
            TGLegacyLog(@"Failed to move: %@", error);
    });
}

- (void)clearCache:(int)availability
{
    if (availability & TGCacheMemory)
    {
        [_memoryCache removeAllObjects];
        [_thumbnailCache removeAllObjects];
        [_dataMemoryCache removeAllObjects];
        [_avatarMemoryCache removeAllObjects];
    }
    if (availability & TGCacheDisk)
    {
        @synchronized (_renderedAvatarStoredKeys)
        {
            [_renderedAvatarStoredKeys removeAllObjects];
            [_renderedAvatarMissingKeys removeAllObjects];
        }
        dispatch_async([TGCache diskCacheQueue], ^
        {
            NSDirectoryEnumerator* en = [cacheFileManager enumeratorAtPath:_diskCachePath];
            NSError* error = nil;
            
            int removedCount = 0;
            int failedCount = 0;
            
            NSString* file;
            while (file = [en nextObject])
            {
                if ([cacheFileManager removeItemAtPath:[_diskCachePath stringByAppendingPathComponent:file] error:&error])
                    removedCount++;
                else
                    failedCount++;
            }
            
            TGLegacyLog(@"TGCache: removed %d files (%d failed)", removedCount, failedCount);
        });
    }
}

- (NSArray *)storeMemoryCache
{
    return [[_memoryCache allKeys] arrayByAddingObjectsFromArray:[_avatarMemoryCache allKeys]];
}

- (void)restoreMemoryCache:(NSArray *)array
{
    for (NSString *url in array)
    {
        [self cachedImage:url availability:TGCacheDisk];
    }
}

@end
