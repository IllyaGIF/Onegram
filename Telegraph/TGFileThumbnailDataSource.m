#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGFileThumbnailDataSource.h"
#import "../OnegramPlatform/OGPlatformMedia.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGWorkerPool.h"
#import "TGWorkerTask.h"
#import "TGMediaPreviewTask.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMemoryImageCache.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageBlur.h"
#import "../submodules/LegacyComponents/LegacyComponents/UIImage+TG.h"

#import "TGMediaStoreContext.h"

#import <AVFoundation/AVFoundation.h>
#import <math.h>

#import "TGAppDelegate.h"


#if defined(ONEGRAM_ARMV6)
typedef struct
{
    CGContextRef context;
    void *data;
    size_t width;
    size_t height;
    size_t rowBytes;
} TGFileThumbnailArmv6Bitmap;

static bool TGFileThumbnailArmv6CreateBitmap(CGSize size, TGFileThumbnailArmv6Bitmap *bitmap)
{
    if (bitmap == NULL || !isfinite(size.width) || !isfinite(size.height) || size.width < 1.0f || size.height < 1.0f)
        return false;
    memset(bitmap, 0, sizeof(TGFileThumbnailArmv6Bitmap));
    size_t width = (size_t)MAX(1.0f, ceilf(size.width));
    size_t height = (size_t)MAX(1.0f, ceilf(size.height));
    if (width > 2048 || height > 2048 || width > ((size_t)-1) / 4)
        return false;
    size_t rowBytes = ((width * 4) + 15) & ~((size_t)15);
    if (height > ((size_t)-1) / rowBytes)
        return false;
    void *data = calloc(height, rowBytes);
    if (data == NULL)
        return false;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL)
    {
        free(data);
        return false;
    }
    CGContextRef context = CGBitmapContextCreate(data, width, height, 8, rowBytes, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
    {
        free(data);
        return false;
    }
    CGContextTranslateCTM(context, 0.0f, (CGFloat)height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
    bitmap->context = context;
    bitmap->data = data;
    bitmap->width = width;
    bitmap->height = height;
    bitmap->rowBytes = rowBytes;
    return true;
}

static void TGFileThumbnailArmv6ReleaseBitmap(void *info, __unused const void *data, __unused size_t size)
{
    if (info != NULL)
        free(info);
}

static UIImage *TGFileThumbnailArmv6FinishBitmap(TGFileThumbnailArmv6Bitmap *bitmap)
{
    if (bitmap == NULL || bitmap->context == NULL || bitmap->data == NULL)
        return nil;
    CGContextFlush(bitmap->context);
    CGContextRelease(bitmap->context);
    bitmap->context = NULL;
    size_t length = bitmap->rowBytes * bitmap->height;
    void *data = bitmap->data;
    CGDataProviderRef provider = CGDataProviderCreateWithData(data, data, length, TGFileThumbnailArmv6ReleaseBitmap);
    if (provider == NULL)
    {
        free(data);
        memset(bitmap, 0, sizeof(TGFileThumbnailArmv6Bitmap));
        return nil;
    }
    bitmap->data = NULL;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef imageRef = colorSpace == NULL ? NULL : CGImageCreate(bitmap->width, bitmap->height, 8, 32, bitmap->rowBytes, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host, provider, NULL, false, kCGRenderingIntentDefault);
    if (colorSpace != NULL)
        CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    UIImage *image = imageRef == NULL ? nil : [[UIImage alloc] initWithCGImage:imageRef];
    if (imageRef != NULL)
        CGImageRelease(imageRef);
    memset(bitmap, 0, sizeof(TGFileThumbnailArmv6Bitmap));
    return image;
}

static void TGFileThumbnailArmv6DrawImage(CGContextRef context, UIImage *image, CGRect rect)
{
    if (context == NULL || image == nil || image.CGImage == NULL || CGRectIsEmpty(rect))
        return;
    CGContextSaveGState(context);
    CGFloat width = rect.size.width;
    CGFloat height = rect.size.height;
    CGContextTranslateCTM(context, CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGRect drawRect = CGRectMake(-width * 0.5f, -height * 0.5f, width, height);
    switch (image.imageOrientation)
    {
        case UIImageOrientationDown:
            CGContextRotateCTM(context, (CGFloat)M_PI);
            break;
        case UIImageOrientationLeft:
            CGContextRotateCTM(context, -(CGFloat)M_PI_2);
            drawRect = CGRectMake(-height * 0.5f, -width * 0.5f, height, width);
            break;
        case UIImageOrientationRight:
            CGContextRotateCTM(context, (CGFloat)M_PI_2);
            drawRect = CGRectMake(-height * 0.5f, -width * 0.5f, height, width);
            break;
        case UIImageOrientationUpMirrored:
            CGContextScaleCTM(context, -1.0f, 1.0f);
            break;
        case UIImageOrientationDownMirrored:
            CGContextScaleCTM(context, 1.0f, -1.0f);
            break;
        case UIImageOrientationLeftMirrored:
            CGContextRotateCTM(context, -(CGFloat)M_PI_2);
            CGContextScaleCTM(context, -1.0f, 1.0f);
            drawRect = CGRectMake(-height * 0.5f, -width * 0.5f, height, width);
            break;
        case UIImageOrientationRightMirrored:
            CGContextRotateCTM(context, (CGFloat)M_PI_2);
            CGContextScaleCTM(context, -1.0f, 1.0f);
            drawRect = CGRectMake(-height * 0.5f, -width * 0.5f, height, width);
            break;
        case UIImageOrientationUp:
        default:
            break;
    }
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextDrawImage(context, drawRect, image.CGImage);
    CGContextRestoreGState(context);
}

static UIImage *TGFileThumbnailArmv6Render(UIImage *image, CGSize size, CGRect imageRect, bool whiteBackground)
{
    TGFileThumbnailArmv6Bitmap bitmap;
    if (!TGFileThumbnailArmv6CreateBitmap(size, &bitmap))
        return nil;
    if (whiteBackground)
    {
        CGContextSetRGBFillColor(bitmap.context, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextFillRect(bitmap.context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    }
    TGFileThumbnailArmv6DrawImage(bitmap.context, image, imageRect);
    return TGFileThumbnailArmv6FinishBitmap(&bitmap);
}
#endif

static TGWorkerPool *workerPool()
{
    static TGWorkerPool *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = [[TGWorkerPool alloc] init];
    });
    
    return instance;
}

static ASQueue *taskManagementQueue()
{
    static ASQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ASQueue alloc] initWithName:"org.telegram.fileThumbnailTaskManagementQueue"];
    });
    
    return queue;
}

@implementation TGFileThumbnailDataSource

+ (void)load
{
    @autoreleasepool
    {
        [TGImageDataSource registerDataSource:[[self alloc] init]];
    }
}

- (bool)canHandleUri:(NSString *)uri
{
    return [uri hasPrefix:@"file-thumbnail://"];
}

- (bool)canHandleAttributeUri:(NSString *)uri
{
    return [uri hasPrefix:@"file-thumbnail://"];
}

- (id)loadDataAsyncWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *resource))__unused partialCompletion completion:(void (^)(TGDataResource *))completion
{
    TGMediaPreviewTask *previewTask = [[TGMediaPreviewTask alloc] init];
    __weak TGMediaPreviewTask *weakPreviewTask = previewTask;
    
    [taskManagementQueue() dispatchOnQueue:^
    {
        TGWorkerTask *workerTask = [[TGWorkerTask alloc] initWithBlock:^(bool (^isCancelled)())
        {
            TGDataResource *result = [TGFileThumbnailDataSource _performLoad:uri isCancelled:isCancelled];
            
            if (result != nil && progress != nil)
                progress(1.0f);
            
            if (isCancelled != nil && isCancelled())
                return;
            
            if (completion != nil)
                completion(result != nil ? result : [TGFileThumbnailDataSource resultForUnavailableImage]);
        }];
        
        if ([TGFileThumbnailDataSource _isDataLocallyAvailableForUri:uri])
        {
            [weakPreviewTask executeWithWorkerTask:workerTask workerPool:workerPool()];
        }
        else
        {
            NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"file-thumbnail://?".length]];
            
            if ([args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)] || ([args[@"cid"] longLongValue] != 0 && [args[@"mid"] intValue] != 0))
            {
                static NSString *filesDirectory = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^
                {
                    filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
                });
                
                NSString *fileDirectoryName = nil;
                if (args[@"id"] != nil)
                    fileDirectoryName = [[NSString alloc] initWithFormat:@"%" PRIx64 "", (int64_t)[args[@"id"] longLongValue]];
                else
                    fileDirectoryName = [[NSString alloc] initWithFormat:@"local%" PRIx64 "", (int64_t)[args[@"local-id"] longLongValue]];
                NSString *fileDirectory = [filesDirectory stringByAppendingPathComponent:fileDirectoryName];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:fileDirectory withIntermediateDirectories:true attributes:nil error:nil];
                
                NSString *temporaryThumbnailImagePath = [fileDirectory stringByAppendingPathComponent:@"file-thumb.jpg"];
                
                NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                options[@"thumbnailContext"] = args;
                TGMediaOriginInfo *originInfo = nil;
                if (args[@"origin_info"] != nil)
                {
                    originInfo = [TGMediaOriginInfo mediaOriginInfoWithStringRepresentation:args[@"origin_info"]];
                }
                else if (args[@"cid"] != nil)
                {
                    int64_t cid = [args[@"cid"] longLongValue];
                    int32_t mid = [args[@"mid"] intValue];
                    originInfo = [TGMediaOriginInfo mediaOriginInfoWithFileReference:nil fileReferences:nil cid:cid mid:mid];
                }
                
                if (originInfo != nil)
                    options[@"originInfo"] = originInfo;
                
                [previewTask executeThumbnailWithTargetFilePath:temporaryThumbnailImagePath uri:args[@"legacy-thumbnail-cache-url"] options:options completion:^(bool success)
                {
                    if (success)
                    {
                        dispatch_async([TGCache diskCacheQueue], ^
                        {
                            [weakPreviewTask executeWithWorkerTask:workerTask workerPool:workerPool()];
                        });
                    }
                    else
                    {
                        if (completion != nil)
                            completion([TGFileThumbnailDataSource resultForUnavailableImage]);
                    }
                } workerTask:workerTask];
            }
            else
            {
                if (completion != nil)
                    completion([TGFileThumbnailDataSource resultForUnavailableImage]);
            }
        }
    }];
    
    return previewTask;
}

+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri
{
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"file-thumbnail://?".length]];
    
    if ((![args[@"id"] respondsToSelector:@selector(longLongValue)] && ![args[@"local-id"] respondsToSelector:@selector(longLongValue)]) || ![args[@"width"] respondsToSelector:@selector(intValue)] || ![args[@"height"] respondsToSelector:@selector(intValue)] || ![args[@"renderWidth"] respondsToSelector:@selector(intValue)] || ![args[@"renderHeight"] respondsToSelector:@selector(intValue)] || ![args[@"file-name"] respondsToSelector:@selector(characterAtIndex:)])
    {
        return false;
    }
    
    static NSString *filesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });
    
    NSString *fileDirectoryName = nil;
    if (args[@"id"] != nil)
        fileDirectoryName = [[NSString alloc] initWithFormat:@"%" PRIx64 "", (int64_t)[args[@"id"] longLongValue]];
    else
        fileDirectoryName = [[NSString alloc] initWithFormat:@"local%" PRIx64 "", (int64_t)[args[@"local-id"] longLongValue]];
    NSString *fileDirectory = [filesDirectory stringByAppendingPathComponent:fileDirectoryName];
    
    CGSize size = CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
    CGSize renderSize = CGSizeMake([args[@"renderWidth"] intValue], [args[@"renderHeight"] intValue]);
    
    NSString *thumbnailPath = [fileDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"thumbnail-%dx%d-%dx%d.jpg", (int)size.width, (int)size.height, (int)renderSize.width, (int)renderSize.height]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath isDirectory:NULL])
        return true;
    
    NSString *temporaryThumbnailImagePath = [fileDirectory stringByAppendingPathComponent:@"file-thumb.jpg"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:temporaryThumbnailImagePath])
        return true;
    
    NSString *filePath = [fileDirectory stringByAppendingPathComponent:args[@"file-name"]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:NULL])
        return true;
    
    if ([args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
    {
        NSString *legacyThumbnailImagePath = nil;
        NSString *legacyThumbnailUrl = args[@"legacy-thumbnail-cache-url"];
        
        if ([legacyThumbnailUrl hasPrefix:@"file://"])
            legacyThumbnailImagePath = [legacyThumbnailUrl substringFromIndex:@"file://".length];
        else
            legacyThumbnailImagePath = [[TGRemoteImageView sharedCache] pathForCachedData:args[@"legacy-thumbnail-cache-url"]];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:legacyThumbnailImagePath isDirectory:NULL])
            return true;
        
        NSString *imageUrl = args[@"legacy-thumbnail-cache-url"];
        if ([imageUrl hasPrefix:@"http://"] || [imageUrl hasPrefix:@"https://"])
        {
            return [[[TGMediaStoreContext instance] temporaryFilesCache] containsValueForKey:[imageUrl dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    return false;
}

- (void)cancelTaskById:(id)taskId
{
    [taskManagementQueue() dispatchOnQueue:^
    {
        if ([taskId isKindOfClass:[TGMediaPreviewTask class]])
        {
            TGMediaPreviewTask *previewTask = taskId;
            [previewTask cancel];
        }
    }];
}

+ (TGDataResource *)resultForUnavailableImage
{
    static TGDataResource *imageData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        imageData = [[TGDataResource alloc] initWithImage:TGAverageColorImage([UIColor whiteColor]) decoded:true];
    });
    
    return imageData;
}

- (id)loadAttributeSyncForUri:(NSString *)uri attribute:(NSString *)attribute
{
    if ([attribute isEqualToString:@"placeholder"])
    {
        UIImage *reducedImage = [[TGMediaStoreContext instance] mediaImage:uri attributes:nil];
        
        if (reducedImage != nil)
            return reducedImage;
        
        NSNumber *averageColor = [[TGMediaStoreContext instance] mediaImageAverageColor:uri];
        if (averageColor != nil)
        {
            UIImage *image = TGAverageColorImage(UIColorRGB([averageColor intValue]));
            return image;
        }
        
        static UIImage *placeholder = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            placeholder = TGAverageColorImage([UIColor whiteColor]);
        });
        
        return placeholder;
    }
    
    return nil;
}

- (TGDataResource *)loadDataSyncWithUri:(NSString *)uri canWait:(bool)canWait acceptPartialData:(bool)__unused acceptPartialData asyncTaskId:(__autoreleasing id *)__unused asyncTaskId progress:(void (^)(float))__unused progress partialCompletion:(void (^)(TGDataResource *))__unused partialCompletion completion:(void (^)(TGDataResource *))__unused completion
{
    if (uri == nil)
        return nil;
    
    UIImage *cachedImage = [[TGMediaStoreContext instance] mediaImage:uri attributes:nil];
    if (cachedImage != nil)
        return [[TGDataResource alloc] initWithImage:cachedImage decoded:true];
    
    if (!canWait)
        return nil;
    
    return [TGFileThumbnailDataSource _performLoad:uri isCancelled:nil];
}

+ (TGDataResource *)_performLoad:(NSString *)uri isCancelled:(bool (^)())isCancelled
{
    if (isCancelled && isCancelled())
        return nil;
    
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"file-thumbnail://?".length]];
    
    if ((![args[@"id"] respondsToSelector:@selector(longLongValue)] && ![args[@"local-id"] respondsToSelector:@selector(longLongValue)]) || ![args[@"width"] respondsToSelector:@selector(intValue)] || ![args[@"height"] respondsToSelector:@selector(intValue)] || ![args[@"renderWidth"] respondsToSelector:@selector(intValue)] || ![args[@"renderHeight"] respondsToSelector:@selector(intValue)] || ![args[@"file-name"] respondsToSelector:@selector(characterAtIndex:)])
    {
        return nil;
    }
    
    static NSString *filesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });
    
    NSString *fileDirectoryName = nil;
    if (args[@"id"] != nil)
        fileDirectoryName = [[NSString alloc] initWithFormat:@"%" PRIx64 "", (int64_t)[args[@"id"] longLongValue]];
    else
        fileDirectoryName = [[NSString alloc] initWithFormat:@"local%" PRIx64 "", (int64_t)[args[@"local-id"] longLongValue]];
    NSString *fileDirectory = [filesDirectory stringByAppendingPathComponent:fileDirectoryName];
    
    CGSize size = CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
    CGSize renderSize = CGSizeMake([args[@"renderWidth"] intValue], [args[@"renderHeight"] intValue]);
    
    NSString *thumbnailPath = [fileDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"thumbnail-%dx%d-%dx%d.jpg", (int)size.width, (int)size.height, (int)renderSize.width, (int)renderSize.height]];
    
    UIImage *thumbnailSourceImage = [[UIImage alloc] initWithContentsOfFile:thumbnailPath];
    bool lowQualityThumbnail = false;
    
    bool forceHighQuality = [args[@"forceHighQuality"] boolValue];
    
    if (thumbnailSourceImage == nil)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:fileDirectory withIntermediateDirectories:true attributes:nil error:nil];
        
        NSString *filePath = [fileDirectory stringByAppendingPathComponent:args[@"file-name"]];
        NSString *videoFilePath = nil;
        if (args[@"video-file-name"] != nil) {
            videoFilePath = [fileDirectory stringByAppendingPathComponent:args[@"video-file-name"]];
        }
        NSString *temporaryThumbnailImagePath = [fileDirectory stringByAppendingPathComponent:@"file-thumb.jpg"];
        
        UIImage *image = nil;
        
        if ((!OGPlatformMediaDownloadsRequireUserAction() || args[@"local-id"] != nil) && videoFilePath != nil && [[NSFileManager defaultManager] fileExistsAtPath:videoFilePath isDirectory:NULL]) {
            if ([videoFilePath pathExtension].length == 0) {
                [[NSFileManager defaultManager] createSymbolicLinkAtPath:[videoFilePath stringByAppendingPathExtension:@"mov"] withDestinationPath:[videoFilePath pathComponents].lastObject error:nil];
                videoFilePath = [videoFilePath stringByAppendingPathExtension:@"mov"];
            }
            
            image = OGPlatformVideoThumbnailAtURL([NSURL fileURLWithPath:videoFilePath], 0.0, CGSizeMake(800.0f, 800.0f));
        }
        
        if (image == nil && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:NULL])
        {
            image = [[UIImage alloc] initWithContentsOfFile:filePath];
        }
        
        if (image == nil)
        {
            image = [[UIImage alloc] initWithContentsOfFile:temporaryThumbnailImagePath];
            if (image == nil)
            {
                if ([args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
                {
                    NSString *legacyThumbnailImagePath = nil;
                    NSString *legacyThumbnailUrl = args[@"legacy-thumbnail-cache-url"];
                    
                    if ([legacyThumbnailUrl hasPrefix:@"file://"])
                        legacyThumbnailImagePath = [legacyThumbnailUrl substringFromIndex:@"file://".length];
                    else
                        legacyThumbnailImagePath = [[TGRemoteImageView sharedCache] pathForCachedData:args[@"legacy-thumbnail-cache-url"]];
                    
                    image = [[UIImage alloc] initWithContentsOfFile:legacyThumbnailImagePath];
                    
                    if (image != nil)
                    {
                        [[NSFileManager defaultManager] copyItemAtPath:legacyThumbnailImagePath toPath:temporaryThumbnailImagePath error:nil];
                    }
                }
            }
            
            lowQualityThumbnail = MAX(image.size.width, image.size.height) < 70.0f;
        }
        
        if (image == nil)
        {
            NSString *imageUrl = args[@"legacy-thumbnail-cache-url"];
            if (imageUrl.length != 0)
            {
                if ([imageUrl hasPrefix:@"http://"] || [imageUrl hasPrefix:@"https://"])
                {
                    NSData *imageData = [[[TGMediaStoreContext instance] temporaryFilesCache] getValueForKey:[imageUrl dataUsingEncoding:NSUTF8StringEncoding]];
                    if (imageData != nil)
                    {
                        image = [[UIImage alloc] initWithData:imageData];
                        if (image != nil)
                            lowQualityThumbnail = MAX(image.size.width, image.size.height) < 70.0f;
                    }
                }
            }
        }
        
        if (forceHighQuality) {
            lowQualityThumbnail = false;
        }
        
        if (image != nil)
        {
            const float cacheFactor = 0.85f;
            CGSize cachedImageSize = CGSizeMake(CGCeil(size.width * cacheFactor), CGCeil(size.height * cacheFactor));
            CGSize cachedRenderSize = CGSizeMake(CGCeil(renderSize.width * cacheFactor), CGCeil(renderSize.height * cacheFactor));
            CGRect imageRect = CGRectMake((cachedImageSize.width - cachedRenderSize.width) / 2.0f, (cachedImageSize.height - cachedRenderSize.height) / 2.0f, cachedRenderSize.width, cachedRenderSize.height);
#if defined(ONEGRAM_ARMV6)
            thumbnailSourceImage = TGFileThumbnailArmv6Render(image, cachedImageSize, imageRect, true);
#else
            UIGraphicsBeginImageContextWithOptions(cachedImageSize, true, 2.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            if (context != NULL)
            {
                CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                CGContextFillRect(context, CGRectMake(0.0f, 0.0f, cachedImageSize.width, cachedImageSize.height));
                [image drawInRect:imageRect blendMode:kCGBlendModeNormal alpha:1.0f];
                thumbnailSourceImage = UIGraphicsGetImageFromCurrentImageContext();
            }
            UIGraphicsEndImageContext();
#endif
            
            if (thumbnailSourceImage != nil && !lowQualityThumbnail)
            {
                NSData *thumbnailSourceData = UIImageJPEGRepresentation(thumbnailSourceImage, 0.8f);
                [thumbnailSourceData writeToFile:thumbnailPath atomically:true];
            }
        }
    }
    else
    {
        CGRect imageRect = CGRectMake(0.0f, 0.0f, size.width, size.height);
#if defined(ONEGRAM_ARMV6)
        thumbnailSourceImage = TGFileThumbnailArmv6Render(thumbnailSourceImage, size, imageRect, false);
#else
        UIGraphicsBeginImageContextWithOptions(size, true, 2.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (context != NULL)
        {
            [thumbnailSourceImage drawInRect:imageRect blendMode:kCGBlendModeCopy alpha:1.0f];
            thumbnailSourceImage = UIGraphicsGetImageFromCurrentImageContext();
        }
        UIGraphicsEndImageContext();
#endif
    }
    
    bool isRounded = [args[@"rounded"] boolValue];
    
    if (thumbnailSourceImage != nil)
    {
        UIImage *thumbnailImage = nil;
        
        NSNumber *averageColor = [[TGMediaStoreContext instance] mediaImageAverageColor:uri];
        bool needsAverageColor = averageColor == nil;
        uint32_t averageColorValue = [averageColor intValue];
        
        thumbnailImage = TGLoadedFileImage(thumbnailSourceImage, size, needsAverageColor ? &averageColorValue : NULL, isRounded ? 8 : 0);
        
        if (thumbnailImage != nil)
        {
            [[TGMediaStoreContext instance] setMediaImageAverageColorForKey:uri averageColor:@(averageColorValue)];
            if (!lowQualityThumbnail)
                [[TGMediaStoreContext instance] setMediaImageForKey:uri image:thumbnailImage attributes:nil];
        
            return [[TGDataResource alloc] initWithImage:thumbnailImage decoded:true];
        }
    }
    
    return nil;
}

@end
