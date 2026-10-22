#import "../OnegramPlatform/OGPlatformMedia.h"
#import "TGPhotoThumbnailDataSource.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"

#import "TGWorkerPool.h"
#import "TGWorkerTask.h"
#import "TGMediaPreviewTask.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMemoryImageCache.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageBlur.h"
#import "../submodules/LegacyComponents/LegacyComponents/UIImage+TG.h"

#import "TGMediaStoreContext.h"

#import "TGAppDelegate.h"

#import "TGPresentation.h"

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
        queue = [[ASQueue alloc] initWithName:"org.telegram.photoThumbnailTaskManagementQueue"];
    });
    
    return queue;
}

static bool TGPhotoThumbnailJPEGDataIsStructurallyValid(NSData *data)
{
    if (data.length < 4)
        return false;

    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger length = data.length;
    if (bytes[0] != 0xff || bytes[1] != 0xd8)
        return true;

    bool hasSof = false;
    NSUInteger offset = 2;
    while (offset + 1 < length)
    {
        if (bytes[offset] != 0xff)
            return false;

        while (offset < length && bytes[offset] == 0xff)
            offset++;
        if (offset >= length)
            return false;

        uint8_t marker = bytes[offset++];
        if (marker == 0xd9)
            return hasSof;
        if (marker == 0xda)
            return hasSof;
        if (marker == 0xd8 || marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7))
            continue;

        if (offset + 2 > length)
            return false;

        NSUInteger segmentLength = ((NSUInteger)bytes[offset] << 8) | bytes[offset + 1];
        if (segmentLength < 2 || offset + segmentLength > length)
            return false;

        bool isSof = (marker >= 0xc0 && marker <= 0xc3) ||
            (marker >= 0xc5 && marker <= 0xc7) ||
            (marker >= 0xc9 && marker <= 0xcb) ||
            (marker >= 0xcd && marker <= 0xcf);
        if (isSof)
        {
            if (segmentLength < 8)
                return false;

            NSUInteger height = ((NSUInteger)bytes[offset + 3] << 8) | bytes[offset + 4];
            NSUInteger width = ((NSUInteger)bytes[offset + 5] << 8) | bytes[offset + 6];
            NSUInteger components = bytes[offset + 7];
            if (width == 0 || height == 0 || components == 0 || segmentLength < 8 + components * 3)
                return false;
            hasSof = true;
        }

        offset += segmentLength;
    }

    return false;
}

static UIImage *TGPhotoThumbnailImageFromData(NSData *data)
{
    if (data.length == 0 || !TGPhotoThumbnailJPEGDataIsStructurallyValid(data))
        return nil;
    TGImageRenderingLock();
    @try
    {
        UIImage *image = [[UIImage alloc] initWithData:data];
        if (image == nil || image.CGImage == NULL)
            return nil;
        return image;
    }
    @finally
    {
        TGImageRenderingUnlock();
    }
}

static UIImage *TGPhotoThumbnailImageFromFile(NSString *path)
{
    if (path.length == 0)
        return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    return TGPhotoThumbnailImageFromData(data);
}

static bool TGPhotoThumbnailImageFileIsValid(NSString *path)
{
    return TGPhotoThumbnailImageFromFile(path) != nil;
}

static UIImage *TGPhotoThumbnailStrippedImage(NSDictionary *args)
{
    NSString *strippedCacheUrl = args[@"legacy-stripped-cache-url"];
    if (![strippedCacheUrl respondsToSelector:@selector(characterAtIndex:)] || strippedCacheUrl.length == 0)
        return nil;
    return TGPhotoThumbnailImageFromFile([[TGRemoteImageView sharedCache] pathForCachedData:strippedCacheUrl]);
}

@interface TGPhotoThumbnailDataSource ()
{
}

@end

@implementation TGPhotoThumbnailDataSource

+ (void)load
{
    @autoreleasepool
    {
        [TGImageDataSource registerDataSource:[[self alloc] init]];
    }
}

- (bool)canHandleUri:(NSString *)uri
{
    return [uri hasPrefix:@"photo-thumbnail://"];
}

- (bool)canHandleAttributeUri:(NSString *)uri
{
    return [uri hasPrefix:@"photo-thumbnail://"];
}

- (id)loadDataAsyncWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *resource))partialCompletion completion:(void (^)(TGDataResource *))completion
{
    TGMediaPreviewTask *previewTask = [[TGMediaPreviewTask alloc] init];
    __weak TGMediaPreviewTask *weakPreviewTask = previewTask;
    
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
    bool isFlat = [args[@"flat"] boolValue];
    int cornerRadius = [args[@"cornerRadius"] intValue];
    int position = [args[@"position"] intValue];
    
    [taskManagementQueue() dispatchOnQueue:^
    {
        TGWorkerTask *workerTask = [[TGWorkerTask alloc] initWithBlock:^(bool (^isCancelled)())
        {
            TGDataResource *result = [TGPhotoThumbnailDataSource _performLoad:uri isCancelled:isCancelled];
            
            if (result != nil && progress != nil)
                progress(1.0f);
            
            if (isCancelled != nil && isCancelled())
                return;
            
            if (completion != nil)
                completion(result != nil ? result : [TGPhotoThumbnailDataSource resultForUnavailableImage:isFlat cornerRadius:cornerRadius position:position]);
        }];

        if ([TGPhotoThumbnailDataSource _isDataLocallyAvailableForUri:uri])
        {
            [weakPreviewTask executeWithWorkerTask:workerTask workerPool:workerPool()];
        }
        else
        {
            NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
            
            TGDataResource *strippedResult = TGPhotoThumbnailStrippedImage(args) != nil ? [TGPhotoThumbnailDataSource _performLoad:uri isCancelled:nil] : nil;
            if (strippedResult != nil && partialCompletion != nil)
                partialCompletion(strippedResult);
            
            if ([args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)] || ([args[@"cid"] longLongValue] != 0 && [args[@"mid"] intValue] != 0))
            {
                static NSString *filesDirectory = nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^
                {
                    filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
                });
                
                NSString *photoDirectoryName = nil;
                if (args[@"id"] != nil)
                {
                    photoDirectoryName = [[NSString alloc] initWithFormat:@"image-remote-%" PRIx64 "", (int64_t)[args[@"id"] longLongValue]];
                }
                else
                {
                    photoDirectoryName = [[NSString alloc] initWithFormat:@"image-local-%" PRIx64 "", (int64_t)[args[@"local-id"] longLongValue]];
                }
                NSString *photoDirectory = [filesDirectory stringByAppendingPathComponent:photoDirectoryName];
                
                [[NSFileManager defaultManager] createDirectoryAtPath:photoDirectory withIntermediateDirectories:true attributes:nil error:nil];
                
                NSString *temporaryThumbnailImagePath = [photoDirectory stringByAppendingPathComponent:@"image-thumb.jpg"];
                
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
                        TGLog(@"PHOTO_THUMB unavailable id=%@ url=%@ stripped=%d", args[@"id"], args[@"legacy-thumbnail-cache-url"], strippedResult != nil ? 1 : 0);
                        if (completion != nil)
                            completion(strippedResult ?: [TGPhotoThumbnailDataSource resultForUnavailableImage:isFlat cornerRadius:cornerRadius position:position]);
                    }
                } workerTask:workerTask];
            }
            else
            {
                if (completion != nil)
                    completion(strippedResult ?: [TGPhotoThumbnailDataSource resultForUnavailableImage:isFlat cornerRadius:cornerRadius position:position]);
            }
        }
    }];
    
    return previewTask;
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

+ (TGDataResource *)resultForUnavailableImage:(bool)isFlat cornerRadius:(int)cornerRadius position:(int)position
{
    static NSMutableDictionary *normalDatas = nil;
    static NSMutableDictionary *flatDatas = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        normalDatas = [[NSMutableDictionary alloc] init];
        flatDatas = [[NSMutableDictionary alloc] init];
    });
    
    TGPresentation *presentation = TGPresentation.current;
    UIColor *color = presentation.pallete.backgroundColor;
    if (position == 0)
    {
        if (isFlat)
        {
            NSNumber *key = @(cornerRadius + presentation.currentId);
            TGDataResource *flatData = flatDatas[key];
            if (flatData == nil)
            {
                if (cornerRadius == 0)
                {
                    flatData = [[TGDataResource alloc] initWithImage:TGAverageColorAttachmentImage(color, false, 0) decoded:true];
                }
                else
                {
                    flatData = [[TGDataResource alloc] initWithImage:TGAverageColorAttachmentWithCornerRadiusImage(color, false, cornerRadius, 0) decoded:true];
                }
                
                flatDatas[key] = flatData;
            }
            return flatData;
        }
        else
        {
            NSNumber *key = @(presentation.currentId);
            TGDataResource *normalData = normalDatas[key];
            if (normalData == nil)
            {
                normalData = [[TGDataResource alloc] initWithImage:TGAverageColorAttachmentImage(color, true, 0) decoded:true];
                normalDatas[key] = normalData;
            }
            return normalData;
        }
    }
    else
    {
        if (isFlat)
        {
            if (cornerRadius == 0)
            {
                return [[TGDataResource alloc] initWithImage:TGAverageColorAttachmentImage(color, false, position) decoded:true];
            }
            else
            {
                return [[TGDataResource alloc] initWithImage:TGAverageColorAttachmentWithCornerRadiusImage(color, false, cornerRadius, position) decoded:true];
            }
        }
        else
        {
            return [[TGDataResource alloc] initWithImage:TGAverageColorAttachmentImage(color, true, position) decoded:true];
        }
    }
}

- (id)loadAttributeSyncForUri:(NSString *)uri attribute:(NSString *)attribute
{
    if ([attribute isEqualToString:@"placeholder"])
    {
        NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
        bool isFlat = [args[@"flat"] boolValue];
        int cornerRadius = [args[@"cornerRadius"] intValue];
        int position = [args[@"position"] intValue];
        
        UIImage *reducedImage = [[TGMediaStoreContext instance] mediaReducedImage:uri attributes:NULL];
        
        if (reducedImage != nil)
            return reducedImage;
        
        NSNumber *averageColor = [[TGMediaStoreContext instance] mediaImageAverageColor:uri];
        if (averageColor != nil)
        {
            UIImage *image = nil;
            if (isFlat && cornerRadius > 0)
                image = TGAverageColorAttachmentWithCornerRadiusImage(UIColorRGB([averageColor intValue]), !isFlat, cornerRadius, position);
            else
                image = TGAverageColorAttachmentImage(UIColorRGB([averageColor intValue]), !isFlat, position);
            return image;
        }
        
        static NSMutableDictionary *normalPlaceholders = nil;
        static NSMutableDictionary *flatPlaceholders = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            normalPlaceholders = [[NSMutableDictionary alloc] init];
            flatPlaceholders = [[NSMutableDictionary alloc] init];
        });
        
        TGPresentation *presentation = TGPresentation.current;
        UIColor *color = presentation.pallete.backgroundColor;
        if (position == 0)
        {
            if (isFlat)
            {
                NSNumber *key = @(presentation.currentId + cornerRadius);
                UIImage *flatPlaceholder = flatPlaceholders[key];
                if (flatPlaceholder == nil)
                {
                    if (cornerRadius == 0)
                        flatPlaceholder = TGAverageColorAttachmentImage(color, false, 0);
                    else
                        flatPlaceholder = TGAverageColorAttachmentWithCornerRadiusImage(color, false, cornerRadius, 0);
                    
                    flatPlaceholders[key] = flatPlaceholder;
                }
                return flatPlaceholder;
            }
            else
            {
                NSNumber *key = @(presentation.currentId);
                UIImage *normalPlaceholder = normalPlaceholders[key];
                if (normalPlaceholder == nil)
                {
                    normalPlaceholder = TGAverageColorAttachmentImage(color, true, 0);
                    normalPlaceholders[key] = normalPlaceholder;
                }
                return normalPlaceholder;
            }
        }
        else
        {
            if (isFlat)
            {
                if (cornerRadius == 0)
                    return TGAverageColorAttachmentImage(color, false, position);
                else
                    return TGAverageColorAttachmentWithCornerRadiusImage(color, false, cornerRadius, position);
            }
            else
            {
                return TGAverageColorAttachmentImage(color, true, position);
            }
        }
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
    
    return [TGPhotoThumbnailDataSource _performLoad:uri isCancelled:nil];
}

+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri
{
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
    
    if ((![args[@"id"] respondsToSelector:@selector(longLongValue)] && ![args[@"local-id"] respondsToSelector:@selector(longLongValue)]) || ![args[@"width"] respondsToSelector:@selector(intValue)] || ![args[@"height"] respondsToSelector:@selector(intValue)] || ![args[@"renderWidth"] respondsToSelector:@selector(intValue)] || ![args[@"renderHeight"] respondsToSelector:@selector(intValue)])
    {
        return false;
    }
    
    NSString *imageUrl = args[@"legacy-thumbnail-cache-url"];
    if (imageUrl.length != 0)
    {
        if ([imageUrl hasPrefix:@"http://"] || [imageUrl hasPrefix:@"https://"])
        {
            NSData *cacheKey = [imageUrl dataUsingEncoding:NSUTF8StringEncoding];
            TGModernCache *cache = [[TGMediaStoreContext instance] temporaryFilesCache];
            if ([cache containsValueForKey:cacheKey])
            {
                NSData *imageData = [cache getValueForKey:cacheKey];
                if (TGPhotoThumbnailImageFromData(imageData) != nil)
                    return true;
                [cache removeValueForKey:cacheKey];
            }
        }
    }
    
    static NSString *filesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });
    
    NSString *photoDirectoryName = nil;
    if (args[@"id"] != nil)
    {
        photoDirectoryName = [[NSString alloc] initWithFormat:@"image-remote-%" PRIx64 "", (int64_t)[args[@"id"] longLongValue]];
    }
    else
    {
        photoDirectoryName = [[NSString alloc] initWithFormat:@"image-local-%" PRIx64 "", (int64_t)[args[@"local-id"] longLongValue]];
    }
    NSString *photoDirectory = [filesDirectory stringByAppendingPathComponent:photoDirectoryName];
    
    CGSize size = CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
    CGSize renderSize = CGSizeMake([args[@"renderWidth"] intValue], [args[@"renderHeight"] intValue]);
    
    NSString *thumbnailPath = [photoDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"thumbnail-%dx%d-%dx%d.jpg", (int)size.width, (int)size.height, (int)renderSize.width, (int)renderSize.height]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath isDirectory:NULL])
    {
        if (TGPhotoThumbnailImageFileIsValid(thumbnailPath))
            return true;
        [[NSFileManager defaultManager] removeItemAtPath:thumbnailPath error:nil];
    }
    
    NSString *imagePath = [photoDirectory stringByAppendingPathComponent:@"image.jpg"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:imagePath isDirectory:NULL])
    {
        if (TGPhotoThumbnailImageFileIsValid(imagePath))
            return true;
        [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
    }
    
    if ([args[@"legacy-file-path"] respondsToSelector:@selector(characterAtIndex:)])
    {
        NSString *legacyCacheFilePath = args[@"legacy-file-path"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:legacyCacheFilePath isDirectory:NULL] && TGPhotoThumbnailImageFileIsValid(legacyCacheFilePath))
            return true;
    }
    
    NSString *temporaryThumbnailImagePath = [photoDirectory stringByAppendingPathComponent:@"image-thumb.jpg"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:temporaryThumbnailImagePath isDirectory:NULL])
    {
        if (TGPhotoThumbnailImageFileIsValid(temporaryThumbnailImagePath))
            return true;
        [[NSFileManager defaultManager] removeItemAtPath:temporaryThumbnailImagePath error:nil];
    }
    
    if ([args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
    {
        NSString *legacyThumbnailCacheUrl = args[@"legacy-thumbnail-cache-url"];
        TGCache *cache = [TGRemoteImageView sharedCache];
        NSString *legacyThumbnailFilePath = [cache pathForCachedData:legacyThumbnailCacheUrl];
        if ([[NSFileManager defaultManager] fileExistsAtPath:legacyThumbnailFilePath isDirectory:NULL])
        {
            if (TGPhotoThumbnailImageFileIsValid(legacyThumbnailFilePath))
                return true;
            [cache removeFromMemoryCache:legacyThumbnailCacheUrl matchEnd:false];
            dispatch_sync([TGCache diskCacheQueue], ^
            {
                [[NSFileManager defaultManager] removeItemAtPath:legacyThumbnailFilePath error:nil];
            });
        }
    }
    
    return false;
}

+ (TGDataResource *)_performLoad:(NSString *)uri isCancelled:(bool (^)())isCancelled
{
    if (isCancelled && isCancelled())
    {
        return nil;
    }
    
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
    
    if ((![args[@"id"] respondsToSelector:@selector(longLongValue)] && ![args[@"local-id"] respondsToSelector:@selector(longLongValue)]) || ![args[@"width"] respondsToSelector:@selector(intValue)] || ![args[@"height"] respondsToSelector:@selector(intValue)] || ![args[@"renderWidth"] respondsToSelector:@selector(intValue)] || ![args[@"renderHeight"] respondsToSelector:@selector(intValue)])
    {
        return nil;
    }

    static NSString *filesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });
    
    NSString *photoDirectoryName = nil;
    if (args[@"id"] != nil)
    {
        photoDirectoryName = [[NSString alloc] initWithFormat:@"image-remote-%" PRIx64 "", (int64_t)[args[@"id"] longLongValue]];
    }
    else
    {
        photoDirectoryName = [[NSString alloc] initWithFormat:@"image-local-%" PRIx64 "", (int64_t)[args[@"local-id"] longLongValue]];
    }
    NSString *photoDirectory = [filesDirectory stringByAppendingPathComponent:photoDirectoryName];
    
    CGSize size = CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
    CGSize renderSize = CGSizeMake([args[@"renderWidth"] intValue], [args[@"renderHeight"] intValue]);
    
    NSString *thumbnailPath = [photoDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"thumbnail-%dx%d-%dx%d.jpg", (int)size.width, (int)size.height, (int)renderSize.width, (int)renderSize.height]];
    
    UIImage *thumbnailSourceImage = TGPhotoThumbnailImageFromFile(thumbnailPath);
    bool lowQualityThumbnail = false;
    if (thumbnailSourceImage == nil && [[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath isDirectory:NULL])
        [[NSFileManager defaultManager] removeItemAtPath:thumbnailPath error:nil];
    
    if (thumbnailSourceImage == nil)
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:photoDirectory withIntermediateDirectories:true attributes:nil error:nil];
        
        NSString *imagePath = [photoDirectory stringByAppendingPathComponent:@"image.jpg"];
        NSString *temporaryThumbnailImagePath = [photoDirectory stringByAppendingPathComponent:@"image-thumb.jpg"];
        UIImage *image = TGPhotoThumbnailImageFromFile(imagePath);
        if (image == nil && [[NSFileManager defaultManager] fileExistsAtPath:imagePath isDirectory:NULL])
            [[NSFileManager defaultManager] removeItemAtPath:imagePath error:nil];
        
        if (image == nil && [args[@"legacy-file-path"] respondsToSelector:@selector(characterAtIndex:)])
        {
            NSString *legacyCacheFilePath = args[@"legacy-file-path"];
            image = TGPhotoThumbnailImageFromFile(legacyCacheFilePath);
            
            if (image != nil)
            {
                [[NSFileManager defaultManager] copyItemAtPath:legacyCacheFilePath toPath:imagePath error:nil];
            }
        }
        
        if (image == nil)
        {
            image = TGPhotoThumbnailImageFromFile(temporaryThumbnailImagePath);
            if (image != nil)
                lowQualityThumbnail = MAX(image.size.width, image.size.height) < 70.0f;
            else if ([[NSFileManager defaultManager] fileExistsAtPath:temporaryThumbnailImagePath isDirectory:NULL])
                [[NSFileManager defaultManager] removeItemAtPath:temporaryThumbnailImagePath error:nil];
        }
        
        if (image == nil && [args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
        {
            NSString *legacyThumbnailCacheUrl = args[@"legacy-thumbnail-cache-url"];
            TGCache *cache = [TGRemoteImageView sharedCache];
            NSString *legacyThumbnailFilePath = [cache pathForCachedData:legacyThumbnailCacheUrl];
            image = TGPhotoThumbnailImageFromFile(legacyThumbnailFilePath);
            if (image != nil)
            {
                [[NSFileManager defaultManager] copyItemAtPath:legacyThumbnailFilePath toPath:temporaryThumbnailImagePath error:nil];
                lowQualityThumbnail = MAX(image.size.width, image.size.height) < 70.0f;
            }
            else if ([[NSFileManager defaultManager] fileExistsAtPath:legacyThumbnailFilePath isDirectory:NULL])
            {
                [cache removeFromMemoryCache:legacyThumbnailCacheUrl matchEnd:false];
                dispatch_sync([TGCache diskCacheQueue], ^
                {
                    [[NSFileManager defaultManager] removeItemAtPath:legacyThumbnailFilePath error:nil];
                });
            }
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
                        image = TGPhotoThumbnailImageFromData(imageData);
                        if (image != nil)
                            lowQualityThumbnail = MAX(image.size.width, image.size.height) < 70.0f;
                        else
                            [[[TGMediaStoreContext instance] temporaryFilesCache] removeValueForKey:[imageUrl dataUsingEncoding:NSUTF8StringEncoding]];
                    }
                }
            }
        }
        
        if (image == nil)
        {
            image = TGPhotoThumbnailStrippedImage(args);
            if (image != nil)
                lowQualityThumbnail = true;
        }
        
        if (image != nil)
        {
            const float cacheFactor = 1.0f;
            CGSize cachedImageSize = CGSizeMake(CGCeil(size.width * cacheFactor), CGCeil(size.height * cacheFactor));
            CGSize cachedRenderSize = CGSizeMake(CGCeil(renderSize.width * cacheFactor), CGCeil(renderSize.height * cacheFactor));
            thumbnailSourceImage = TGScaleAndRoundCornersWithOffset(image, cachedRenderSize, CGPointZero, cachedImageSize, 0, nil, true, nil);
            
            if (thumbnailSourceImage != nil && !lowQualityThumbnail)
            {
                TGWriteJPEGRepresentationToFile(thumbnailSourceImage, 0.85f, thumbnailPath);
            }
        }
    }
    else
    {
        thumbnailSourceImage = TGScaleImageToPixelSize(thumbnailSourceImage, CGSizeMake(thumbnailSourceImage.size.width * thumbnailSourceImage.scale, thumbnailSourceImage.size.height * thumbnailSourceImage.scale));
    }
    
    bool isFlat = [args[@"flat"] boolValue];
    int cornerRadius = [args[@"cornerRadius"] intValue];
    int position = [args[@"position"] intValue];
    
    if (thumbnailSourceImage != nil)
    {
        UIImage *thumbnailImage = nil;
        
        NSNumber *averageColor = [[TGMediaStoreContext instance] mediaImageAverageColor:uri];
        bool needsAverageColor = averageColor == nil;
        uint32_t averageColorValue = [averageColor intValue];
        uint32_t *averageColorPtr = needsAverageColor ? &averageColorValue : NULL;
        
        TGImageRenderingLock();
        @try
        {
            if ([args[@"secret"] boolValue])
            {
                if (isFlat && cornerRadius != 0)
                    thumbnailImage = TGSecretBlurredAttachmentWithCornerRadiusImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, cornerRadius, position);
                else
                    thumbnailImage = TGSecretBlurredAttachmentImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, position);
            }
            else if (lowQualityThumbnail)
            {
                if (isFlat && cornerRadius != 0)
                    thumbnailImage = TGBlurredAttachmentWithCornerRadiusImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, cornerRadius, position);
                else
                    thumbnailImage = TGBlurredAttachmentImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, position);
            }
            else
            {
                if (isFlat && cornerRadius != 0)
                    thumbnailImage = TGLoadedAttachmentWithCornerRadiusImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, cornerRadius, 0, position);
                else
                    thumbnailImage = TGLoadedAttachmentImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, position);
            }
        }
        @finally
        {
            TGImageRenderingUnlock();
        }
        
        if (thumbnailImage != nil)
        {
            [[TGMediaStoreContext instance] setMediaImageAverageColorForKey:uri averageColor:@(averageColorValue)];
            if (!lowQualityThumbnail && TGScreenScaling() < 3.0f)
                [[TGMediaStoreContext instance] setMediaImageForKey:uri image:thumbnailImage attributes:nil];
            
            
            NSDictionary *imageAttachments = [thumbnailImage attachmentsDictionary];
            
            [[TGMediaStoreContext instance] inMediaReducedImageCacheGenerationQueue:^
            {
                __autoreleasing NSDictionary *attributes = nil;
                UIImage *alreadyCachedImage = [[TGMediaStoreContext instance] mediaReducedImage:uri attributes:&attributes];
                bool alreadyCached = alreadyCachedImage != nil;
                bool cachedLowQualityThumbnail = [attributes isKindOfClass:[NSDictionary class]] && [[attributes objectForKey:@"lowQuality"] boolValue];
                
                if (!alreadyCached || (cachedLowQualityThumbnail && !lowQualityThumbnail))
                {
                    UIImage *cachedImage = nil;
                    TGImageRenderingLock();
                    @try
                    {
                        if (isFlat && cornerRadius > 0)
                            cachedImage = TGReducedAttachmentWithCornerRadiusImage(thumbnailImage, size, !isFlat, cornerRadius, position);
                        else
                            cachedImage = TGReducedAttachmentImage(thumbnailImage, size, !isFlat, position);
                    }
                    @finally
                    {
                        TGImageRenderingUnlock();
                    }
                    [cachedImage setAttachmentsFromDictionary:imageAttachments];
                    
                    if (cachedImage != nil)
                    {
                        [[TGMediaStoreContext instance] setMediaReducedImageForKey:uri reducedImage:cachedImage attributes:@{@"lowQuality": @(lowQualityThumbnail)}];
                    }
                }
            }];
            
            return [[TGDataResource alloc] initWithImage:thumbnailImage decoded:true];
        }
    } else {
        TGLog(@"Couldn't generate thumbnail");
    }
    
    return nil;
}

@end
