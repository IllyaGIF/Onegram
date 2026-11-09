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
#import "../OnegramPlatform/OGPlatformGraphics.h"
#import "../OnegramRuntime/OGRuntime.h"
#import <libkern/OSAtomic.h>

static volatile int32_t TGPhotoThumbnailPendingCacheWrites = 0;

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

static bool TGPhotoThumbnailJPEGBytesAreStructurallyValid(const uint8_t *bytes, NSUInteger length)
{
    if (length < 4)
        return false;
    if (bytes[0] != 0xff || bytes[1] != 0xd8)
        return true;
    bool hasSof = false;
    bool hasScan = false;
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
            return hasSof && hasScan;
        if (marker == 0x01)
            continue;
        if (marker == 0x00 || marker == 0xd8 || (marker >= 0xd0 && marker <= 0xd7))
            return false;
        if (offset + 2 > length)
            return false;
        NSUInteger segmentLength = ((NSUInteger)bytes[offset] << 8) | bytes[offset + 1];
        if (segmentLength < 2 || segmentLength > length - offset)
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
            if (width == 0 || height == 0 || components == 0 || segmentLength != 8 + components * 3)
                return false;
            hasSof = true;
        }
        if (marker == 0xda)
        {
            if (!hasSof || segmentLength < 6 || segmentLength != 6u + bytes[offset + 2] * 2u)
                return false;
            hasScan = true;
            offset += segmentLength;
            bool foundMarker = false;
            while (offset < length)
            {
                if (bytes[offset++] != 0xff)
                    continue;
                NSUInteger markerOffset = offset - 1;
                while (offset < length && bytes[offset] == 0xff)
                    offset++;
                if (offset >= length)
                    return false;
                uint8_t scanMarker = bytes[offset];
                if (scanMarker == 0x00 || (scanMarker >= 0xd0 && scanMarker <= 0xd7))
                {
                    offset++;
                    continue;
                }
                offset = markerOffset;
                foundMarker = true;
                break;
            }
            if (!foundMarker)
                return false;
        }
        else
            offset += segmentLength;
    }
    return false;
}

static bool TGPhotoThumbnailJPEGDataIsStructurallyValid(NSData *data)
{
    return TGPhotoThumbnailJPEGBytesAreStructurallyValid(data.bytes, data.length);
}

static NSString *TGPhotoThumbnailDirectory(NSDictionary *args)
{
    NSString *name = args[@"id"] != nil ?
        [[NSString alloc] initWithFormat:@"image-remote-%" PRIx64, (int64_t)[args[@"id"] longLongValue]] :
        [[NSString alloc] initWithFormat:@"image-local-%" PRIx64, (int64_t)[args[@"local-id"] longLongValue]];
    return [[[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"] stringByAppendingPathComponent:name];
}

static NSArray *TGPhotoThumbnailSourceState(NSDictionary *args)
{
    NSString *directory = TGPhotoThumbnailDirectory(args);
    NSMutableArray *paths = [[NSMutableArray alloc] initWithObjects:
        [directory stringByAppendingPathComponent:@"image.jpg"],
        [directory stringByAppendingPathComponent:@"image-thumb.jpg"], nil];
    if ([args[@"legacy-file-path"] isKindOfClass:[NSString class]])
        [paths addObject:args[@"legacy-file-path"]];
    for (NSString *key in @[@"legacy-thumbnail-cache-url", @"legacy-stripped-cache-url"])
    {
        NSString *url = args[key];
        if ([url isKindOfClass:[NSString class]] && url.length != 0)
            [paths addObject:[[TGRemoteImageView sharedCache] pathForCachedData:url]];
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

static void TGPhotoThumbnailWriteCacheData(NSData *data, NSString *path, NSString *directory, NSDictionary *args, NSArray *sourceState)
{
    if (data.length == 0 || ![sourceState isEqual:TGPhotoThumbnailSourceState(args)])
        return;
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:nil];
    [data writeToFile:path atomically:true];
}

static void TGPhotoThumbnailCacheImage(UIImage *image, NSString *path, NSString *directory, NSDictionary *args, NSArray *sourceState)
{
    if (OSAtomicIncrement32Barrier(&TGPhotoThumbnailPendingCacheWrites) > 2)
    {
        OSAtomicDecrement32Barrier(&TGPhotoThumbnailPendingCacheWrites);
        NSData *data = UIImageJPEGRepresentation(image, 0.85f);
        if (data.length != 0)
        {
            OGRuntimeDispatch(OGRuntimePriorityStorage, ^
            {
                @autoreleasepool
                {
                    TGPhotoThumbnailWriteCacheData(data, path, directory, args, sourceState);
                }
            });
        }
        return;
    }
    OGRuntimeDispatch(OGRuntimePriorityStorage, ^
    {
        @try
        {
            @autoreleasepool
            {
                if (![sourceState isEqual:TGPhotoThumbnailSourceState(args)])
                    return;
                NSData *data = UIImageJPEGRepresentation(image, 0.85f);
                TGPhotoThumbnailWriteCacheData(data, path, directory, args, sourceState);
            }
        }
        @finally
        {
            OSAtomicDecrement32Barrier(&TGPhotoThumbnailPendingCacheWrites);
        }
    });
}

static UIImage *TGPhotoThumbnailImageFromDataWithMaximumSide(NSData *data, CGFloat maximumSide, NSInteger priority, bool (^isCancelled)())
{
    if (data.length == 0 || !TGPhotoThumbnailJPEGDataIsStructurallyValid(data))
        return nil;
    UIImage *image = OGPlatformDecodeImageData(data, maximumSide > 0.0f ? CGSizeMake(maximumSide, maximumSide) : CGSizeZero, priority, isCancelled);
    if (image == nil || image.CGImage == NULL)
        return nil;
    return image;
}

static UIImage *TGPhotoThumbnailImageFromData(NSData *data)
{
    return TGPhotoThumbnailImageFromDataWithMaximumSide(data, 0.0f, 1, nil);
}

static UIImage *TGPhotoThumbnailImageFromFileWithMaximumSide(NSString *path, CGFloat maximumSide, NSInteger priority, bool (^isCancelled)())
{
    if (path.length == 0 || (isCancelled != nil && isCancelled()))
        return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    UIImage *image = TGPhotoThumbnailImageFromDataWithMaximumSide(data, maximumSide, priority, isCancelled);
    if (image == nil && data.length != 0 && !TGPhotoThumbnailJPEGDataIsStructurallyValid(data))
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    return image;
}

static UIImage *TGPhotoThumbnailImageFromFile(NSString *path)
{
    if (path.length == 0)
        return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    return TGPhotoThumbnailImageFromData(data);
}

static bool TGPhotoThumbnailFileExists(NSString *path)
{
    if (path.length == 0)
        return false;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return [attributes[NSFileType] isEqual:NSFileTypeRegular] && [attributes[NSFileSize] unsignedLongLongValue] != 0;
}

static UIImage *TGPhotoThumbnailStrippedImage(NSDictionary *args)
{
    NSString *strippedCacheUrl = args[@"legacy-stripped-cache-url"];
    if (![strippedCacheUrl respondsToSelector:@selector(characterAtIndex:)] || strippedCacheUrl.length == 0)
        return nil;
    return TGPhotoThumbnailImageFromFile([[TGRemoteImageView sharedCache] pathForCachedData:strippedCacheUrl]);
}

@interface TGPhotoThumbnailDataSource ()
+ (TGDataResource *)_performLoad:(NSString *)uri priority:(NSInteger)priority isCancelled:(bool (^)())isCancelled;
+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri;
@end

@interface TGPhotoThumbnailLoadTask : TGMediaPreviewTask
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
- (void)fetchThumbnail;
- (void)renderFinal:(bool)final mayFetch:(bool)mayFetch;
- (void)finish:(TGDataResource *)resource;
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
    TGPhotoThumbnailLoadTask *task = [[TGPhotoThumbnailLoadTask alloc] initWithUri:uri progress:progress partialCompletion:partialCompletion completion:completion];
    [taskManagementQueue() dispatchOnQueue:^{ [task start]; }];
    return task;
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
    
    NSDictionary *attributes = nil;
    UIImage *cachedImage = [[TGMediaStoreContext instance] mediaImage:uri attributes:&attributes];
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
    if (cachedImage != nil && [attributes[@"complete"] boolValue] && [attributes[@"sourceState"] isEqual:TGPhotoThumbnailSourceState(args)])
        return [[TGDataResource alloc] initWithImage:cachedImage decoded:true];
    
    if (!canWait)
        return nil;
    
    return [TGPhotoThumbnailDataSource _performLoad:uri priority:2 isCancelled:nil];
}

+ (bool)_isDataLocallyAvailableForUri:(NSString *)uri
{
    NSDictionary *args = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
    NSString *directory = TGPhotoThumbnailDirectory(args);
    if (TGPhotoThumbnailFileExists([directory stringByAppendingPathComponent:@"image.jpg"]) ||
        TGPhotoThumbnailFileExists(args[@"legacy-file-path"]))
        return true;
    NSString *url = args[@"legacy-thumbnail-cache-url"];
    if (url.length == 0)
        return TGPhotoThumbnailFileExists([directory stringByAppendingPathComponent:@"image-thumb.jpg"]);
    if (TGPhotoThumbnailFileExists([[TGRemoteImageView sharedCache] pathForCachedData:url]))
        return true;
    if ([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
        return [[[TGMediaStoreContext instance] temporaryFilesCache] containsValueForKey:[url dataUsingEncoding:NSUTF8StringEncoding]];
    return false;
}

+ (TGDataResource *)_performLoad:(NSString *)uri priority:(NSInteger)priority isCancelled:(bool (^)())isCancelled
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

    NSString *photoDirectory = TGPhotoThumbnailDirectory(args);
    
    CGSize size = CGSizeMake([args[@"width"] intValue], [args[@"height"] intValue]);
    CGSize renderSize = CGSizeMake([args[@"renderWidth"] intValue], [args[@"renderHeight"] intValue]);
    
    if (size.width < 1.0f || size.height < 1.0f || renderSize.width < 1.0f || renderSize.height < 1.0f)
        return nil;
    CGFloat decodeScale = MIN(1.0f, MAX(renderSize.width * TGScreenScaling() / size.width, renderSize.height * TGScreenScaling() / size.height));
    CGFloat maximumSide = MIN(4096.0f, ceil(MAX(size.width, size.height) * decodeScale));
    NSArray *sourceState = TGPhotoThumbnailSourceState(args);
    NSDictionary *cachedAttributes = nil;
    UIImage *cachedImage = [[TGMediaStoreContext instance] mediaImage:uri attributes:&cachedAttributes];
    if (cachedImage != nil && [cachedAttributes[@"sourceState"] isEqual:sourceState])
        return [[TGDataResource alloc] initWithImage:cachedImage decoded:true];
    NSString *sourceKey = [TGStringUtils md5:[sourceState description]];
    NSString *thumbnailPath = [photoDirectory stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"thumbnail-%dx%d-%dx%d-%g-%@.jpg", (int)size.width, (int)size.height, (int)renderSize.width, (int)renderSize.height, TGScreenScaling(), sourceKey]];

    UIImage *thumbnailSourceImage = TGPhotoThumbnailImageFromFileWithMaximumSide(thumbnailPath, maximumSide, priority, isCancelled);
    bool lowQualityThumbnail = false;
    bool placeholderThumbnail = false;
    if (thumbnailSourceImage == nil)
    {
        NSString *imagePath = [photoDirectory stringByAppendingPathComponent:@"image.jpg"];
        UIImage *image = TGPhotoThumbnailImageFromFileWithMaximumSide(imagePath, maximumSide, priority, isCancelled);
        NSString *legacyCacheFilePath = args[@"legacy-file-path"];
        if ([legacyCacheFilePath isKindOfClass:[NSString class]] && ![legacyCacheFilePath isEqualToString:imagePath])
        {
            UIImage *legacyImage = TGPhotoThumbnailImageFromFileWithMaximumSide(legacyCacheFilePath, maximumSide, priority, isCancelled);
            if (legacyImage != nil && (image == nil ||
                legacyImage.size.width * legacyImage.scale * legacyImage.size.height * legacyImage.scale >
                image.size.width * image.scale * image.size.height * image.scale))
                image = legacyImage;
        }
        UIImage *originalImage = image;
        if (image == nil || MAX(image.size.width * image.scale, image.size.height * image.scale) < 70.0f)
        {
            NSString *temporaryThumbnailImagePath = [photoDirectory stringByAppendingPathComponent:@"image-thumb.jpg"];
            image = TGPhotoThumbnailImageFromFileWithMaximumSide(temporaryThumbnailImagePath, maximumSide, priority, isCancelled);
            NSString *legacyThumbnailCacheUrl = args[@"legacy-thumbnail-cache-url"];
            if ([legacyThumbnailCacheUrl isKindOfClass:[NSString class]] && legacyThumbnailCacheUrl.length != 0)
            {
                TGCache *cache = [TGRemoteImageView sharedCache];
                UIImage *legacyImage = TGPhotoThumbnailImageFromFileWithMaximumSide([cache pathForCachedData:legacyThumbnailCacheUrl], maximumSide, priority, isCancelled);
                if (legacyImage != nil && (image == nil ||
                    legacyImage.size.width * legacyImage.scale * legacyImage.size.height * legacyImage.scale >
                    image.size.width * image.scale * image.size.height * image.scale))
                    image = legacyImage;
                if (image == nil && ([legacyThumbnailCacheUrl hasPrefix:@"http://"] || [legacyThumbnailCacheUrl hasPrefix:@"https://"]))
                {
                    NSData *imageData = [[[TGMediaStoreContext instance] temporaryFilesCache] getValueForKey:[legacyThumbnailCacheUrl dataUsingEncoding:NSUTF8StringEncoding]];
                    image = TGPhotoThumbnailImageFromDataWithMaximumSide(imageData, maximumSide, priority, isCancelled);
                }
            }
        }
        if (image == nil)
            image = originalImage;
        if (isCancelled != nil && isCancelled())
            return nil;
        if (image == nil)
        {
            image = TGPhotoThumbnailStrippedImage(args);
            placeholderThumbnail = image != nil;
            lowQualityThumbnail = true;
        }
        if (image != nil)
        {
            placeholderThumbnail = placeholderThumbnail ||
                MAX(image.size.width * image.scale, image.size.height * image.scale) < 70.0f;
            lowQualityThumbnail = lowQualityThumbnail || placeholderThumbnail;
            thumbnailSourceImage = TGScaleAndRoundCornersWithOffset(image, renderSize, CGPointZero, size, 0, nil, true, nil);
            if (thumbnailSourceImage != nil && !lowQualityThumbnail &&
                [sourceState isEqual:TGPhotoThumbnailSourceState(args)])
            {
                TGPhotoThumbnailCacheImage(thumbnailSourceImage, thumbnailPath, photoDirectory, args, sourceState);
            }
        }
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
            else if (placeholderThumbnail)
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
            if (!lowQualityThumbnail &&
                [sourceState isEqual:TGPhotoThumbnailSourceState(args)])
                [[TGMediaStoreContext instance] setMediaImageForKey:uri image:thumbnailImage attributes:@{@"sourceState": sourceState, @"complete": @([self _isDataLocallyAvailableForUri:uri])}];
            
            
            NSDictionary *imageAttachments = [thumbnailImage attachmentsDictionary];
            
            [[TGMediaStoreContext instance] inMediaReducedImageCacheGenerationQueue:^
            {
                if (![sourceState isEqual:TGPhotoThumbnailSourceState(args)])
                    return;
                __autoreleasing NSDictionary *attributes = nil;
                UIImage *alreadyCachedImage = [[TGMediaStoreContext instance] mediaReducedImage:uri attributes:&attributes];
                bool alreadyCached = alreadyCachedImage != nil;
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
    } else {
        TGLog(@"Couldn't generate thumbnail");
    }
    
    return nil;
}

@end

@implementation TGPhotoThumbnailLoadTask

- (instancetype)initWithUri:(NSString *)uri progress:(void (^)(float))progress partialCompletion:(void (^)(TGDataResource *))partialCompletion completion:(void (^)(TGDataResource *))completion
{
    self = [super init];
    if (self != nil)
    {
        _imageUri = [uri copy];
        _imageArgs = [TGStringUtils argumentDictionaryInUrlString:[uri substringFromIndex:@"photo-thumbnail://?".length]];
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
    if ([TGPhotoThumbnailDataSource _isDataLocallyAvailableForUri:_imageUri])
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
    __weak TGPhotoThumbnailLoadTask *weakSelf = self;
    TGWorkerTask *worker = [[TGWorkerTask alloc] initWithBlock:^(bool (^isCancelled)())
    {
        TGPhotoThumbnailLoadTask *strongSelf = weakSelf;
        if (strongSelf == nil || [strongSelf isCancelled] || isCancelled())
            return;
        TGDataResource *result = [TGPhotoThumbnailDataSource _performLoad:strongSelf->_imageUri priority:(final ? 2 : 0) isCancelled:isCancelled];
        [taskManagementQueue() dispatchOnQueue:^
        {
            if ([strongSelf isCancelled] || strongSelf->_didFinish)
                return;
            if (final && mayFetch && (result == nil || ![TGPhotoThumbnailDataSource _isDataLocallyAvailableForUri:strongSelf->_imageUri]))
            {
                strongSelf->_finalRenderScheduled = false;
                if (result != nil && strongSelf->_partialCompletion != nil)
                    strongSelf->_partialCompletion(result);
                if (result == nil)
                {
                    NSString *url = strongSelf->_imageArgs[@"legacy-thumbnail-cache-url"];
                    if (url.length != 0)
                    {
                        TGCache *cache = [TGRemoteImageView sharedCache];
                        [cache removeFromMemoryCache:url matchEnd:false];
                        [cache removeFromDiskCache:url];
                        dispatch_async([TGCache diskCacheQueue], ^
                        {
                            [taskManagementQueue() dispatchOnQueue:^{ [strongSelf fetchThumbnail]; }];
                        });
                        return;
                    }
                }
                [strongSelf fetchThumbnail];
            }
            else if (final)
                [strongSelf finish:result];
            else if (result != nil && strongSelf->_partialCompletion != nil)
                strongSelf->_partialCompletion(result);
        }];
    }];
    worker.queuePriority = final ? NSOperationQueuePriorityHigh : NSOperationQueuePriorityLow;
    [self executeWithWorkerTask:worker workerPool:workerPool()];
}

- (void)fetchThumbnail
{
    if ([self isCancelled] || _didFinish || _networkStarted)
        return;
    _networkStarted = true;
    NSString *url = _imageArgs[@"legacy-thumbnail-cache-url"];
    if (url.length == 0 && ([_imageArgs[@"cid"] longLongValue] == 0 || [_imageArgs[@"mid"] intValue] == 0))
    {
        [self renderFinal:true mayFetch:false];
        return;
    }
    NSString *directory = TGPhotoThumbnailDirectory(_imageArgs);
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:nil];
    NSString *thumbnailPath = [directory stringByAppendingPathComponent:@"image-thumb.jpg"];
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    options[@"thumbnailContext"] = _imageArgs;
    TGMediaOriginInfo *origin = nil;
    if (_imageArgs[@"origin_info"] != nil)
        origin = [TGMediaOriginInfo mediaOriginInfoWithStringRepresentation:_imageArgs[@"origin_info"]];
    else if (_imageArgs[@"cid"] != nil)
        origin = [TGMediaOriginInfo mediaOriginInfoWithFileReference:nil fileReferences:nil cid:[_imageArgs[@"cid"] longLongValue] mid:[_imageArgs[@"mid"] intValue]];
    if (origin != nil)
        options[@"originInfo"] = origin;
    __weak TGPhotoThumbnailLoadTask *weakSelf = self;
    [self executeThumbnailWithTargetFilePath:thumbnailPath uri:url options:options completion:^(__unused bool success)
    {
        [taskManagementQueue() dispatchOnQueue:^
        {
            TGPhotoThumbnailLoadTask *strongSelf = weakSelf;
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
        completion(resource ?: [TGPhotoThumbnailDataSource resultForUnavailableImage:[_imageArgs[@"flat"] boolValue] cornerRadius:[_imageArgs[@"cornerRadius"] intValue] position:[_imageArgs[@"position"] intValue]]);
}

@end
