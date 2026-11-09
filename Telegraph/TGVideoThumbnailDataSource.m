#import "TGVideoThumbnailDataSource.h"
#import "../OnegramPlatform/OGPlatformMedia.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGWorkerPool.h"
#import "TGWorkerTask.h"
#import "TGMediaPreviewTask.h"

#import "TGPhotoThumbnailDataSource.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGMemoryImageCache.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageBlur.h"
#import "../submodules/LegacyComponents/LegacyComponents/UIImage+TG.h"

#import "TGMediaStoreContext.h"

#import <AVFoundation/AVFoundation.h>

#import "TGAppDelegate.h"
#import "../OnegramPlatform/OGPlatformGraphics.h"

#include <string.h>

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
        queue = [[ASQueue alloc] initWithName:"org.telegram.videoThumbnailTaskManagementQueue"];
    });
    
    return queue;
}

static NSString *TGVideoThumbnailDirectory(NSDictionary *args)
{
    NSString *name = args[@"id"] != nil ?
        [NSString stringWithFormat:@"video-remote-%" PRIx64, (int64_t)[args[@"id"] longLongValue]] :
        [NSString stringWithFormat:@"video-local-%" PRIx64, (int64_t)[args[@"local-id"] longLongValue]];
    return [[[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"] stringByAppendingPathComponent:name];
}

static NSString *TGVideoThumbnailSourcePath(NSString *url)
{
    if (url.length == 0)
        return nil;
    return [url hasPrefix:@"file://"] ? [url substringFromIndex:7] : [[TGRemoteImageView sharedCache] pathForCachedData:url];
}

static bool TGVideoThumbnailFileExists(NSString *path)
{
    if (path.length == 0)
        return false;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return [attributes[NSFileType] isEqual:NSFileTypeRegular] && [attributes[NSFileSize] unsignedLongLongValue] != 0;
}

static NSArray *TGVideoThumbnailSourceState(NSDictionary *args)
{
    NSString *directory = TGVideoThumbnailDirectory(args);
    NSMutableArray *paths = [[NSMutableArray alloc] initWithObjects:
        [directory stringByAppendingPathComponent:@"video.mov"],
        [directory stringByAppendingPathComponent:@"video-thumb.jpg"], nil];
    if ([args[@"legacy-video-file-path"] isKindOfClass:[NSString class]])
        [paths addObject:args[@"legacy-video-file-path"]];
    for (NSString *key in @[@"legacy-thumbnail-cache-url", @"legacy-stripped-cache-url"])
    {
        NSString *path = TGVideoThumbnailSourcePath(args[key]);
        if (path != nil)
            [paths addObject:path];
    }
    NSMutableArray *state = [[NSMutableArray alloc] init];
    for (NSString *path in paths)
    {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
        [state addObject:@[path, attributes[NSFileSize] ?: @0,
            @([attributes[NSFileModificationDate] timeIntervalSince1970]),
            attributes[NSFileSystemFileNumber] ?: @0]];
    }
    return state;
}

static UIImage *TGVideoThumbnailImageAtPath(NSString *path, CGFloat maximumSide, UIImage *videoPoster, NSInteger priority, bool (^isCancelled)())
{
    if (path.length == 0 || (isCancelled != nil && isCancelled()))
        return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length >= 12 && memcmp((const uint8_t *)data.bytes + 4, "ftyp", 4) == 0)
    {
        if (videoPoster != nil && MAX(videoPoster.pixelSize.width, videoPoster.pixelSize.height) >= 70.0f)
            return videoPoster;
        return OGPlatformDecodeImageWithBlock(^UIImage *
        {
            return OGPlatformVideoThumbnailAtURL([NSURL fileURLWithPath:path], 0.0, CGSizeMake(maximumSide, maximumSide));
        }, CGSizeMake(maximumSide, maximumSide), priority, isCancelled);
    }
        return OGPlatformDecodeImageData(data, CGSizeMake(maximumSide, maximumSide), priority, isCancelled);
}

@interface TGVideoThumbnailDataSource ()
+ (TGDataResource *)_performLoad:(NSString *)uri priority:(NSInteger)priority isCancelled:(bool (^)())isCancelled;
+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri;
+ (bool)_hasCompleteImageForUri:(NSString *)uri;
@end

@interface TGVideoThumbnailLoadTask : TGMediaPreviewTask
{
    NSString *_imageUri;
    NSDictionary *_imageArgs;
    void (^_imageProgress)(float);
    void (^_partialCompletion)(TGDataResource *);
    void (^_imageCompletion)(TGDataResource *);
    bool _networkStarted;
    bool _finalRenderScheduled;
    bool _didFinish;
}
- (instancetype)initWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *))partialCompletion completion:(void (^)(TGDataResource *))completion;
- (void)start;
- (void)renderFinal:(bool)final mayFetch:(bool)mayFetch;
- (void)fetchThumbnail;
- (void)finish:(TGDataResource *)resource;
@end

@implementation TGVideoThumbnailDataSource

+ (void)load
{
    @autoreleasepool
    {
        [TGImageDataSource registerDataSource:[[self alloc] init]];
    }
}

- (bool)canHandleUri:(NSString *)uri
{
    return [uri hasPrefix:@"video-thumbnail://"];
}

- (bool)canHandleAttributeUri:(NSString *)uri
{
    return [uri hasPrefix:@"video-thumbnail://"];
}

- (id)loadDataAsyncWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *resource))partialCompletion completion:(void (^)(TGDataResource *))completion
{
    TGVideoThumbnailLoadTask *task = [[TGVideoThumbnailLoadTask alloc] initWithUri:uri progress:progress partialCompletion:partialCompletion completion:completion];
    [taskManagementQueue() dispatchOnQueue:^{ [task start]; }];
    return task;
}

+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri
{
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"video-thumbnail://?".length]];
    NSString *directory = TGVideoThumbnailDirectory(args);
    NSString *url = args[@"legacy-thumbnail-cache-url"];
    if (url.length != 0)
        return TGVideoThumbnailFileExists(TGVideoThumbnailSourcePath(url));
    if (TGVideoThumbnailFileExists([directory stringByAppendingPathComponent:@"video-thumb.jpg"]))
        return true;
    return args[@"id"] == nil &&
        (TGVideoThumbnailFileExists([directory stringByAppendingPathComponent:@"video.mov"]) ||
        TGVideoThumbnailFileExists(args[@"legacy-video-file-path"]));
}

+ (bool)_hasCompleteImageForUri:(NSString *)uri
{
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"video-thumbnail://?".length]];
    NSDictionary *attributes = nil;
    UIImage *image = [[TGMediaStoreContext instance] mediaImage:uri attributes:&attributes];
    return image != nil && [attributes[@"complete"] boolValue] && [attributes[@"sourceState"] isEqual:TGVideoThumbnailSourceState(args)];
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
    return [TGPhotoThumbnailDataSource resultForUnavailableImage:isFlat cornerRadius:cornerRadius position:position];
}

- (id)loadAttributeSyncForUri:(NSString *)uri attribute:(NSString *)attribute
{
    if ([attribute isEqualToString:@"placeholder"])
    {
        NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"video-thumbnail://?".length]];
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
        
        static UIImage *normalPlaceholder = nil;
        static NSMutableDictionary *flatPlaceholders = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            normalPlaceholder = TGAverageColorAttachmentImage([UIColor whiteColor], true, 0);
            flatPlaceholders = [[NSMutableDictionary alloc] init];
        });
        
        if (position == 0)
        {
            if (isFlat)
            {
                UIImage *flatPlaceholder = flatPlaceholders[@(cornerRadius)];
                if (flatPlaceholder == nil)
                {
                    if (cornerRadius == 0)
                        flatPlaceholder = TGAverageColorAttachmentImage([UIColor whiteColor], false, 0);
                    else
                        flatPlaceholder = TGAverageColorAttachmentWithCornerRadiusImage([UIColor whiteColor], false, cornerRadius, 0);
                    
                    flatPlaceholders[@(cornerRadius)] = flatPlaceholder;
                }
                return flatPlaceholder;
            }
            else
            {
                return normalPlaceholder;
            }
        }
        else
        {
            if (isFlat)
            {
                if (cornerRadius == 0)
                    return TGAverageColorAttachmentImage([UIColor whiteColor], false, position);
                else
                    return TGAverageColorAttachmentWithCornerRadiusImage([UIColor whiteColor], false, cornerRadius, position);
            }
            else
            {
                return TGAverageColorAttachmentImage([UIColor whiteColor], true, position);
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
    if (cachedImage != nil && [TGVideoThumbnailDataSource _hasCompleteImageForUri:uri])
        return [[TGDataResource alloc] initWithImage:cachedImage decoded:true];

    if (!canWait)
        return nil;
    
    return [TGVideoThumbnailDataSource _performLoad:uri priority:2 isCancelled:nil];
}

+ (TGDataResource *)_performLoad:(NSString *)uri priority:(NSInteger)priority isCancelled:(bool (^)())isCancelled
{
    if (isCancelled && isCancelled())
    {
        return nil;
    }
    
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"video-thumbnail://?".length]];
    
    if ((![args[@"id"] respondsToSelector:@selector(longLongValue)] && ![args[@"local-id"] respondsToSelector:@selector(longLongValue)]) || ![args[@"width"] respondsToSelector:@selector(intValue)] || ![args[@"height"] respondsToSelector:@selector(intValue)] || ![args[@"renderWidth"] respondsToSelector:@selector(intValue)] || ![args[@"renderHeight"] respondsToSelector:@selector(intValue)])
    {
        return nil;
    }
    
    NSString *videoDirectory = TGVideoThumbnailDirectory(args);
    CGSize size = CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
    CGSize renderSize = CGSizeMake([args[@"renderWidth"] intValue], [args[@"renderHeight"] intValue]);
    if (size.width < 1 || size.height < 1 || renderSize.width < 1 || renderSize.height < 1)
        return nil;
    CGFloat decodeScale = MIN(1.0f, MAX(renderSize.width * TGScreenScaling() / size.width, renderSize.height * TGScreenScaling() / size.height));
    CGFloat maximumSide = MIN(4096.0f, ceil(MAX(size.width, size.height) * decodeScale));
    NSArray *sourceState = TGVideoThumbnailSourceState(args);
    NSDictionary *cachedAttributes = nil;
    UIImage *cachedImage = [[TGMediaStoreContext instance] mediaImage:uri attributes:&cachedAttributes];
    if (cachedImage != nil && [cachedAttributes[@"sourceState"] isEqual:sourceState])
        return [[TGDataResource alloc] initWithImage:cachedImage decoded:true];
    NSString *sourceKey = [TGStringUtils md5:[sourceState description]];
    NSString *thumbnailPath = [videoDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"thumbnail-%dx%d-%dx%d-%g-%@.jpg", (int)size.width, (int)size.height, (int)renderSize.width, (int)renderSize.height, TGScreenScaling(), sourceKey]];
    UIImage *thumbnailSourceImage = TGVideoThumbnailImageAtPath(thumbnailPath, maximumSide, nil, priority, isCancelled);
    bool lowQualityThumbnail = false;
    if (thumbnailSourceImage == nil)
    {
        NSString *sourcePath = TGVideoThumbnailSourcePath(args[@"legacy-thumbnail-cache-url"]);
        NSString *temporaryPath = [videoDirectory stringByAppendingPathComponent:@"video-thumb.jpg"];
        UIImage *temporaryImage = TGVideoThumbnailImageAtPath(temporaryPath, maximumSide, nil, priority, isCancelled);
        UIImage *image = TGVideoThumbnailImageAtPath(sourcePath, maximumSide, temporaryImage, priority, isCancelled);
        if (temporaryImage != nil && (image == nil ||
            temporaryImage.pixelSize.width * temporaryImage.pixelSize.height > image.pixelSize.width * image.pixelSize.height))
            image = temporaryImage;
        lowQualityThumbnail = image != nil && MAX(image.pixelSize.width, image.pixelSize.height) < 70.0f;
        if ((image == nil || lowQualityThumbnail) && ![args[@"secret"] boolValue])
        {
            NSString *videoPath = [videoDirectory stringByAppendingPathComponent:@"video.mov"];
            if (!TGVideoThumbnailFileExists(videoPath))
                videoPath = args[@"legacy-video-file-path"];
            if (TGVideoThumbnailFileExists(videoPath))
            {
                UIImage *frame = OGPlatformDecodeImageWithBlock(^UIImage *
                {
                    return OGPlatformVideoThumbnailAtURL([NSURL fileURLWithPath:videoPath], 0.0, CGSizeMake(maximumSide, maximumSide));
                }, CGSizeMake(maximumSide, maximumSide), priority, isCancelled);
                if (frame != nil)
                {
                    image = frame;
                    lowQualityThumbnail = false;
                }
            }
        }
        if (image == nil)
        {
            image = TGVideoThumbnailImageAtPath(TGVideoThumbnailSourcePath(args[@"legacy-stripped-cache-url"]), maximumSide, nil, priority, isCancelled);
            lowQualityThumbnail = true;
        }
        if (isCancelled != nil && isCancelled())
            return nil;
        if (image != nil)
        {
            TGImageRenderingLock();
            @try
            {
                thumbnailSourceImage = TGScaleAndRoundCornersWithOffset(image, renderSize, CGPointZero, size, 0, nil, true, nil);
            }
            @finally
            {
                TGImageRenderingUnlock();
            }
            if (thumbnailSourceImage != nil && !lowQualityThumbnail && [sourceState isEqual:TGVideoThumbnailSourceState(args)])
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:videoDirectory withIntermediateDirectories:true attributes:nil error:nil];
                [UIImageJPEGRepresentation(thumbnailSourceImage, 0.85f) writeToFile:thumbnailPath atomically:true];
            }
        }
    }

    bool isFlat = [args[@"flat"] boolValue];
    int cornerRadius = [args[@"cornerRadius"] intValue];
    int inset = [args[@"inset"] intValue];
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
                if (isFlat && cornerRadius > 0)
                    thumbnailImage = TGSecretBlurredAttachmentWithCornerRadiusImage(thumbnailSourceImage, size, needsAverageColor ? &averageColorValue : NULL, ![args[@"flat"] boolValue], cornerRadius, position);
                else
                    thumbnailImage = TGSecretBlurredAttachmentImage(thumbnailSourceImage, size, needsAverageColor ? &averageColorValue : NULL, ![args[@"flat"] boolValue], position);
            }
            else if (lowQualityThumbnail)
            {
                if (isFlat && cornerRadius > 0)
                    thumbnailImage = TGBlurredAttachmentWithCornerRadiusImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, cornerRadius, position);
                else
                    thumbnailImage = TGBlurredAttachmentImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, position);
            }
            else
            {
                if (isFlat && cornerRadius > 0)
                    thumbnailImage = TGLoadedAttachmentWithCornerRadiusImage(thumbnailSourceImage, size, averageColorPtr, !isFlat, cornerRadius, inset, position);
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
            if (!lowQualityThumbnail && [sourceState isEqual:TGVideoThumbnailSourceState(args)])
                [[TGMediaStoreContext instance] setMediaImageForKey:uri image:thumbnailImage attributes:@{@"sourceState": sourceState, @"complete": @([self _isDataLocallyAvailableForUri:uri])}];
            
            NSDictionary *imageAttachments = [thumbnailImage attachmentsDictionary];
            
            [[TGMediaStoreContext instance] inMediaReducedImageCacheGenerationQueue:^
            {
                if (![sourceState isEqual:TGVideoThumbnailSourceState(args)])
                    return;
                __autoreleasing NSDictionary *attributes = nil;
                UIImage *existingReducedImage = [[TGMediaStoreContext instance] mediaReducedImage:uri attributes:&attributes];
                bool alreadyCached = existingReducedImage != nil;
                bool cachedLowQualityThumbnail = [attributes isKindOfClass:[NSDictionary class]] && [[attributes objectForKey:@"lowQuality"] boolValue];
                
                if (!alreadyCached || ![attributes[@"sourceState"] isEqual:sourceState] || (cachedLowQualityThumbnail && !lowQualityThumbnail))
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
                        [[TGMediaStoreContext instance] setMediaReducedImageForKey:uri reducedImage:cachedImage attributes:@{@"lowQuality": @(lowQualityThumbnail), @"sourceState": sourceState}];
                    }
                }
            }];
            
            return [[TGDataResource alloc] initWithImage:thumbnailImage decoded:true];
        }
    }
    
    return nil;
}

@end

@implementation TGVideoThumbnailLoadTask

- (instancetype)initWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *))partialCompletion completion:(void (^)(TGDataResource *))completion
{
    self = [super init];
    if (self != nil)
    {
        _imageUri = [uri copy];
        _imageArgs = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"video-thumbnail://?".length]];
        _imageProgress = [progress copy];
        _partialCompletion = [partialCompletion copy];
        _imageCompletion = [completion copy];
    }
    return self;
}

- (void)start
{
    if ([self isCancelled])
        return;
    if ([TGVideoThumbnailDataSource _isDataLocallyAvailableForUri:_imageUri])
        [self renderFinal:true mayFetch:true];
    else
    {
        [self fetchThumbnail];
        if (!_finalRenderScheduled)
            [self renderFinal:false mayFetch:false];
    }
}

- (void)renderFinal:(bool)final mayFetch:(bool)mayFetch
{
    if ([self isCancelled] || _didFinish || (final && _finalRenderScheduled))
        return;
    if (final)
        _finalRenderScheduled = true;
    __weak TGVideoThumbnailLoadTask *weakSelf = self;
    TGWorkerTask *worker = [[TGWorkerTask alloc] initWithBlock:^(bool (^isCancelled)())
    {
        TGVideoThumbnailLoadTask *strongSelf = weakSelf;
        if (strongSelf == nil || [strongSelf isCancelled] || isCancelled())
            return;
        TGDataResource *result = [TGVideoThumbnailDataSource _performLoad:strongSelf->_imageUri priority:(final ? 2 : 0) isCancelled:isCancelled];
        [taskManagementQueue() dispatchOnQueue:^
        {
            if ([strongSelf isCancelled] || strongSelf->_didFinish)
                return;
            if (final && mayFetch && ![TGVideoThumbnailDataSource _hasCompleteImageForUri:strongSelf->_imageUri])
            {
                strongSelf->_finalRenderScheduled = false;
                if (result != nil && strongSelf->_partialCompletion != nil)
                    strongSelf->_partialCompletion(result);
                [strongSelf fetchThumbnail];
            }
            else if (final)
                [strongSelf finish:result];
            else if (result != nil && strongSelf->_partialCompletion != nil)
                strongSelf->_partialCompletion(result);
        }];
    }];
    [self executeWithWorkerTask:worker workerPool:workerPool()];
}

- (void)fetchThumbnail
{
    if ([self isCancelled] || _didFinish || _networkStarted)
        return;
    _networkStarted = true;
    NSString *url = _imageArgs[@"legacy-thumbnail-cache-url"];
    bool canRefresh = [_imageArgs[@"cid"] longLongValue] != 0 && [_imageArgs[@"mid"] intValue] != 0;
    if (canRefresh && ([url hasPrefix:@"file://"] || [url rangeOfString:@":i:"].location != NSNotFound))
        url = nil;
    if (url.length == 0 && !canRefresh)
    {
        [self renderFinal:true mayFetch:false];
        return;
    }
    NSString *directory = TGVideoThumbnailDirectory(_imageArgs);
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:nil];
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    options[@"thumbnailContext"] = _imageArgs;
    TGMediaOriginInfo *origin = nil;
    if (_imageArgs[@"origin_info"] != nil)
        origin = [TGMediaOriginInfo mediaOriginInfoWithStringRepresentation:_imageArgs[@"origin_info"]];
    else if (_imageArgs[@"cid"] != nil)
        origin = [TGMediaOriginInfo mediaOriginInfoWithFileReference:nil fileReferences:nil cid:[_imageArgs[@"cid"] longLongValue] mid:[_imageArgs[@"mid"] intValue]];
    if (origin != nil)
        options[@"originInfo"] = origin;
    __weak TGVideoThumbnailLoadTask *weakSelf = self;
    [self executeThumbnailWithTargetFilePath:[directory stringByAppendingPathComponent:@"video-thumb.jpg"] uri:url options:options completion:^(__unused bool success)
    {
        [taskManagementQueue() dispatchOnQueue:^
        {
            TGVideoThumbnailLoadTask *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf renderFinal:true mayFetch:false];
        }];
    } workerTask:nil];
}

- (void)finish:(TGDataResource *)resource
{
    if (_didFinish || [self isCancelled])
        return;
    _didFinish = true;
    if (resource != nil && _imageProgress != nil)
        _imageProgress(1.0f);
    void (^completion)(TGDataResource *) = _imageCompletion;
    _imageCompletion = nil;
    _partialCompletion = nil;
    _imageProgress = nil;
    if (completion != nil)
        completion(resource ?: [TGVideoThumbnailDataSource resultForUnavailableImage:[_imageArgs[@"flat"] boolValue] cornerRadius:[_imageArgs[@"cornerRadius"] intValue] position:[_imageArgs[@"position"] intValue]]);
}

@end
