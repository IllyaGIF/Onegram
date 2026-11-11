#import "TGPeerAvatarImageDataSource.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGAppDelegate.h"
#import "TGWorkerPool.h"
#import "TGWorkerTask.h"
#import "TGMediaPreviewTask.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMemoryImageCache.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageBlur.h"
#import "../submodules/LegacyComponents/LegacyComponents/UIImage+TG.h"

#import "TGMediaStoreContext.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMediaOriginInfo.h"

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
        queue = [[ASQueue alloc] initWithName:"org.telegram.peerAvatarTaskManagementQueue"];
    });
    
    return queue;
}

static NSString *OGAvatarLegacyCacheKey(NSString *url)
{
    NSArray *segments = [url componentsSeparatedByString:@"_"];
    if (segments.count < 5)
        return url;
    return [[segments subarrayWithRange:NSMakeRange(0, 4)] componentsJoinedByString:@"_"];
}

static CGSize OGAvatarRequestedSize(NSDictionary *args)
{
    return CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
}

static UIImage *OGAvatarNonDegenerateImage(UIImage *image)
{
    if (image == nil)
        return nil;
    CGSize extent = image.size;
    return (extent.width < FLT_EPSILON || extent.height < FLT_EPSILON) ? nil : image;
}

static bool OGAvatarPathIsThumbnail(NSString *path)
{
    NSString *name = [path lastPathComponent];
    return [name hasPrefix:@"thumbnail-"] || [name isEqualToString:@"image-thumb.jpg"];
}

static NSString *OGAvatarBestModernImagePath(NSString *photoDirectoryPath, CGSize size)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *preferredName in @[@"image.jpg", @"image-thumb.jpg"])
    {
        NSString *preferredPath = [photoDirectoryPath stringByAppendingPathComponent:preferredName];
        if ([fileManager fileExistsAtPath:preferredPath isDirectory:NULL])
            return preferredPath;
    }
    
    NSString *closestPath = nil;
    int closestDistance = INT_MAX;
    for (NSString *item in [fileManager contentsOfDirectoryAtPath:photoDirectoryPath error:nil])
    {
        bool isThumbnailFile = [item hasPrefix:@"thumbnail-"] && [item hasSuffix:@".jpg"];
        if (!isThumbnailFile)
            continue;
        
        NSString *candidatePath = [photoDirectoryPath stringByAppendingPathComponent:item];
        UIImage *candidate = [[UIImage alloc] initWithContentsOfFile:candidatePath];
        if (OGAvatarNonDegenerateImage(candidate) == nil)
            continue;
        
        int widthGap = (int)candidate.size.width - (int)size.width;
        int heightGap = (int)candidate.size.height - (int)size.height;
        int distance = ABS(widthGap) + ABS(heightGap);
        if (closestPath == nil || distance < closestDistance)
        {
            closestPath = candidatePath;
            closestDistance = distance;
        }
    }
    
    return closestPath;
}

@interface TGPeerAvatarImageDataSource ()

@end

@implementation TGPeerAvatarImageDataSource

+ (NSString *)uriPrefix
{
    return @"peer-avatar";
}

+ (void)load
{
    @autoreleasepool
    {
        [TGImageDataSource registerDataSource:[[self alloc] init]];
    }
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
    }
    return self;
}

- (bool)canHandleUri:(NSString *)uri
{
    return [uri hasPrefix:[[NSString alloc] initWithFormat:@"%@://", [TGPeerAvatarImageDataSource uriPrefix]]];
}

- (bool)canHandleAttributeUri:(NSString *)uri
{
    return [uri hasPrefix:[[NSString alloc] initWithFormat:@"%@://", [TGPeerAvatarImageDataSource uriPrefix]]];
}

- (id)loadDataAsyncWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *resource))__unused partialCompletion completion:(void (^)(TGDataResource *))completion
{
    TGMediaPreviewTask *previewTask = [[TGMediaPreviewTask alloc] init];
    
    [taskManagementQueue() dispatchOnQueue:^
    {
        TGWorkerTask *workerTask = [[TGWorkerTask alloc] initWithBlock:^(bool (^isCancelled)())
        {
            TGDataResource *result = [TGPeerAvatarImageDataSource _performLoad:uri isCancelled:isCancelled];
            
            if (result != nil && progress != nil)
                progress(1.0f);
            
            if (isCancelled != nil && isCancelled())
                return;
            
            if (completion != nil)
                completion(result != nil ? result : [TGPeerAvatarImageDataSource resultForUnavailableImage]);
        }];
        
        bool isThumbnail = false;
        bool completed = false;
        if ([TGPeerAvatarImageDataSource _isDataLocallyAvailableForUri:uri outIsThumbnail:&isThumbnail])
        {
            TGDataResource *result = [TGPeerAvatarImageDataSource _performLoad:uri isCancelled:nil];
            if (isThumbnail)
            {
                if (partialCompletion)
                    partialCompletion(result);
            }
            else
            {
                if (completion)
                    completion(result);
            }
            
            completed = !isThumbnail;
        }
        
        if (!completed)
        {
            NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:[[NSString alloc] initWithFormat:@"%@://?", [TGPeerAvatarImageDataSource uriPrefix]].length]];
            TGMediaOriginInfo *originInfo = [TGMediaOriginInfo mediaOriginInfoWithStringRepresentation:args[@"origin_info"]];
            NSString *legacyUrl = [args objectForKey:@"legacy-cache-url"];
            NSString *thumbnailUrl = [args objectForKey:@"legacy-thumbnail-cache-url"];
            
            void (^completeWithUnavailable)(void) = ^
            {
                TGDataResource *fallbackResult = [TGPeerAvatarImageDataSource _performLoad:uri isCancelled:nil];
                if (completion != nil)
                    completion(fallbackResult ?: [TGPeerAvatarImageDataSource resultForUnavailableImage]);
            };
            
            void (^renderOnDiskQueue)(void) = ^
            {
                dispatch_async([TGCache diskCacheQueue], ^
                {
                    [previewTask executeWithWorkerTask:workerTask workerPool:workerPool()];
                });
            };
            
            void (^recheckAfterDelay)(void (^)(void)) = ^(void (^onMiss)(void))
            {
                const int64_t recheckDelay = (int64_t)(0.35 * NSEC_PER_SEC);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, recheckDelay), [TGCache diskCacheQueue], ^
                {
                    if ([TGPeerAvatarImageDataSource _performLoad:uri isCancelled:nil] != nil)
                        [previewTask executeWithWorkerTask:workerTask workerPool:workerPool()];
                    else if (onMiss != nil)
                        onMiss();
                });
            };
            
            void (^fetchThenRender)(NSString *, void (^)(float), void (^)(void)) = ^(NSString *remoteUrl, void (^fetchProgress)(float), void (^onMiss)(void))
            {
                NSDictionary *fetchOptions = originInfo == nil ? nil : @{@"originInfo": originInfo};
                [previewTask executeWithTargetFilePath:nil uri:remoteUrl options:fetchOptions progress:fetchProgress completion:^(bool __unused fetched)
                {
                    if ([TGPeerAvatarImageDataSource _performLoad:uri isCancelled:nil] != nil)
                        renderOnDiskQueue();
                    else
                        recheckAfterDelay(onMiss);
                } workerTask:workerTask];
            };
            
            bool (^isUsableUrl)(id) = ^bool(id candidate)
            {
                return [candidate respondsToSelector:@selector(characterAtIndex:)] && [candidate length] != 0;
            };
            
            void (^fetchThumbnail)(void) = ^
            {
                if (!isUsableUrl(thumbnailUrl))
                {
                    completeWithUnavailable();
                    return;
                }
                fetchThenRender(thumbnailUrl, nil, completeWithUnavailable);
            };
            
            if (!isUsableUrl(legacyUrl))
            {
                fetchThumbnail();
            }
            else
            {
                if (progress)
                    progress(0.0);
                fetchThenRender(legacyUrl, ^(float value)
                {
                    if (progress)
                        progress(value);
                }, fetchThumbnail);
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

+ (TGDataResource *)resultForUnavailableImage
{
    static TGDataResource *imageData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        imageData = [[TGDataResource alloc] initWithImage:TGAverageColorImage([UIColor blackColor]) decoded:true];
    });
    
    return imageData;
}

- (id)loadAttributeSyncForUri:(NSString *)uri attribute:(NSString *)attribute
{
    if ([attribute isEqualToString:@"placeholder"])
    {
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
            placeholder = TGAverageColorImage([UIColor blackColor]);
        });
        
        return placeholder;
    }
    
    return nil;
}

- (TGDataResource *)loadDataSyncWithUri:(NSString *)uri canWait:(bool)canWait acceptPartialData:(bool)__unused acceptPartialData asyncTaskId:(__autoreleasing id *)__unused asyncTaskId progress:(void (^)(float))__unused progress partialCompletion:(void (^)(TGDataResource *))__unused partialCompletion completion:(void (^)(TGDataResource *))__unused completion
{
    if (uri == nil)
        return nil;
    
    if (!canWait)
        return nil;
    
    bool isThumbnail = false;
    if ([TGPeerAvatarImageDataSource _isDataLocallyAvailableForUri:uri outIsThumbnail:&isThumbnail])
    {
        TGDataResource *partialData = [TGPeerAvatarImageDataSource _performLoad:uri isCancelled:nil];
        
        if (isThumbnail && acceptPartialData && asyncTaskId != NULL)
        {
            *asyncTaskId = [self loadDataAsyncWithUri:uri progress:progress partialCompletion:partialCompletion completion:completion];
        }
        
        return partialData;
    }
    
    return [TGPeerAvatarImageDataSource _performLoad:uri isCancelled:nil];
}

+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri outIsThumbnail:(bool *)outIsThumbnail
{
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:[[NSString alloc] initWithFormat:@"%@://?", [TGPeerAvatarImageDataSource uriPrefix]].length]];
    
    if (![args[@"width"] respondsToSelector:@selector(intValue)] || ![args[@"height"] respondsToSelector:@selector(intValue)])
    {
        return false;
    }
    
    if ([args[@"legacy-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
    {
        NSString *trimmedUrl = OGAvatarLegacyCacheKey(args[@"legacy-cache-url"]);
        NSString *legacyCacheFilePath = [[TGRemoteImageView sharedCache] pathForCachedData:trimmedUrl];
        if ([[NSFileManager defaultManager] fileExistsAtPath:legacyCacheFilePath isDirectory:NULL])
            return true;
    }
    
    if ([args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
    {
        NSString *trimmedUrl = OGAvatarLegacyCacheKey(args[@"legacy-thumbnail-cache-url"]);
        NSString *legacyThumbnailFilePath = [[TGRemoteImageView sharedCache] pathForCachedData:trimmedUrl];
        if ([[NSFileManager defaultManager] fileExistsAtPath:legacyThumbnailFilePath isDirectory:NULL])
        {
            if (outIsThumbnail)
                *outIsThumbnail = true;
            return true;
        }
    }
    
    if ([args[@"imageId"] respondsToSelector:@selector(longLongValue)])
    {
        int64_t imageId = [args[@"imageId"] longLongValue];
        CGSize size = OGAvatarRequestedSize(args);
        NSString *photoDirectoryPath = [self pathForModernPhotoDirectory:imageId];
        NSString *modernPath = OGAvatarBestModernImagePath(photoDirectoryPath, size);
        if (modernPath != nil)
        {
            if (outIsThumbnail)
                *outIsThumbnail = OGAvatarPathIsThumbnail(modernPath);
            return true;
        }
    }
    
    return false;
}

+ (NSString *)pathForModernPhotoDirectory:(int64_t)imageId
{
    static NSString *filesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });
    
    NSString *photoDirectoryName = [[NSString alloc] initWithFormat:@"image-remote-%" PRIx64 "", imageId];
    return [filesDirectory stringByAppendingPathComponent:photoDirectoryName];
}

+ (TGDataResource *)_performLoad:(NSString *)uri isCancelled:(bool (^)())isCancelled
{
    if (isCancelled && isCancelled())
        return nil;
    
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:[[NSString alloc] initWithFormat:@"%@://?", [TGPeerAvatarImageDataSource uriPrefix]].length]];
    
    if (![args[@"width"] respondsToSelector:@selector(intValue)] || ![args[@"height"] respondsToSelector:@selector(intValue)])
    {
        return nil;
    }
    
    CGSize size = OGAvatarRequestedSize(args);
    if (size.width < FLT_EPSILON || size.height < FLT_EPSILON)
        return nil;
    
    UIImage *image = nil;
    bool lowQualityThumbnail = false;
    bool decoded = false;
    
    if ([args[@"legacy-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
    {
        NSString *trimmedUrl = OGAvatarLegacyCacheKey(args[@"legacy-cache-url"]);
        image = OGAvatarNonDegenerateImage([[TGRemoteImageView sharedCache] cachedImage:trimmedUrl availability:TGCacheDisk]);
    }
    if (image == nil && [args[@"legacy-thumbnail-cache-url"] respondsToSelector:@selector(characterAtIndex:)])
    {
        NSString *trimmedUrl = OGAvatarLegacyCacheKey(args[@"legacy-thumbnail-cache-url"]);
        image = OGAvatarNonDegenerateImage([[TGRemoteImageView sharedCache] cachedImage:trimmedUrl availability:TGCacheDisk]);
        lowQualityThumbnail = true;
    }
    
    if (image == nil && [args[@"imageId"] respondsToSelector:@selector(longLongValue)])
    {
        int64_t imageId = [args[@"imageId"] longLongValue];
        NSString *photoDirectoryPath = [self pathForModernPhotoDirectory:imageId];
        NSString *modernPath = OGAvatarBestModernImagePath(photoDirectoryPath, size);
        
        image = OGAvatarNonDegenerateImage(modernPath == nil ? nil : [[UIImage alloc] initWithContentsOfFile:modernPath]);
        lowQualityThumbnail = modernPath != nil && OGAvatarPathIsThumbnail(modernPath);
    }
    
    if (image != nil)
    {
        NSNumber *averageColor = [[TGMediaStoreContext instance] mediaImageAverageColor:uri];
        bool needsAverageColor = averageColor == nil;
        uint32_t averageColorValue = [averageColor intValue];
        
        if (lowQualityThumbnail)
        {
            UIImage *softened = TGBlurredFileImage(image, size, needsAverageColor ? &averageColorValue : NULL, 0);
            if (softened != nil)
            {
                decoded = true;
                image = softened;
            }
        }
        
        if (image != nil)
        {
            if (needsAverageColor)
                [[TGMediaStoreContext instance] setMediaImageAverageColorForKey:uri averageColor:@(averageColorValue)];
            
            return [[TGDataResource alloc] initWithImage:image decoded:decoded];
        }
    }
    
    return nil;
}

@end
