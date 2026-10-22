#import "TGImageDownloadActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGRemoteImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGImageInfo+Telegraph.h"
#import "TGTelegraph.h"
#import "TGTelegraphProtocols.h"

#import "TGFileDownloadActor.h"

#import "TGGenericModernConversationCompanion.h"

#import "TGDownloadManager.h"

#import "TGDatabase.h"
#import "TGCommon.h"

#import "TGInterfaceAssets.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageManager.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImagePickerController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMediaAsset.h"

#import "TGTelegramNetworking.h"

#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"


static bool TGImageDownloadUsesPeerAvatarPipeline(void)
{
    static int value = -1;
    if (value < 0)
        value = (OGPlatformUsesConstrainedBackgroundExecution() || cpuCoreCount() <= 1) ? 1 : 0;
    return value != 0;
}

static bool OnegramPeerAvatarProcessorSize(NSString *name, CGSize *size, bool *circle)
{
    if (name.length == 0)
        return false;
    NSString *value = nil;
    bool isCircle = false;
    if ([name hasPrefix:@"circle:"])
    {
        value = [name substringFromIndex:7];
        isCircle = true;
    }
    else if ([name hasPrefix:@"scale:"])
        value = [name substringFromIndex:6];
    else
        return false;

    NSRange separator = [value rangeOfString:@"x"];
    if (separator.location == NSNotFound)
        return false;
    int width = [[value substringToIndex:separator.location] intValue];
    int height = [[value substringFromIndex:separator.location + 1] intValue];
    if (width <= 0 || height <= 0 || width > 256 || height > 256)
        return false;
    if (size != NULL)
        *size = CGSizeMake(width, height);
    if (circle != NULL)
        *circle = isCircle;
    return true;
}

static UIImage *OnegramProcessPeerAvatar(UIImage *source, NSString *processorName)
{
    if (source == nil || source.CGImage == NULL)
        return nil;
    CGSize targetSize = CGSizeZero;
    bool circle = false;
    if (!OnegramPeerAvatarProcessorSize(processorName, &targetSize, &circle))
        return nil;

    if (circle)
        return TGScaleAndRoundCornersWithOffsetAndFlags(source, targetSize, CGPointZero, targetSize, (int)targetSize.width / 2, nil, false, nil, TGScaleImageScaleSharper);
    return TGScaleImage(source, targetSize);
}

static UIImage *OnegramApplyImageProcessor(UIImage *source, TGImageProcessor processor, NSString *processorName, NSString *url)
{
    UIImage *result = nil;
    if ([url hasPrefix:@"peerphoto:"] && TGImageDownloadUsesPeerAvatarPipeline())
        result = OnegramProcessPeerAvatar(source, processorName);
    if (result == nil)
        result = processor != nil ? processor(source) : source;
    if (!OGPlatformUsesConstrainedBackgroundExecution() && ([processorName isEqualToString:@"scale:50x50"] || [processorName isEqualToString:@"scale:52x52"]))
    {
        CGFloat size = [processorName isEqualToString:@"scale:50x50"] ? 50.0f : 52.0f;
        [TGLetteredAvatarView prewarmImage:result cornerRadius:size == 50.0f ? 8.0f : 7.0f boundsSize:CGSizeMake(size, size)];
    }
    return result;
}

static NSMutableDictionary *urlRewrites()
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

static NSMutableDictionary *serverAssetData()
{
    static NSMutableDictionary *dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dict = [[NSMutableDictionary alloc] init];
    });
    return dict;
}

static TLInputFileLocation *IOS6ModernInputLocationFromImageUrl(NSString *url, TGMediaOriginInfo *originInfo, int *datacenterId, int64_t *identifier)
{
    if ([url hasPrefix:@"peerphoto:"])
    {
        NSArray *components = [url componentsSeparatedByString:@":"];
        if (components.count >= 7)
        {
            if (datacenterId != NULL)
                *datacenterId = [[components objectAtIndex:1] intValue];
            int32_t peerType = [[components objectAtIndex:2] intValue];
            int64_t peerId = [[components objectAtIndex:3] longLongValue];
            int64_t accessHash = [[components objectAtIndex:4] longLongValue];
            int64_t photoId = [[components objectAtIndex:5] longLongValue];
            bool big = [[components objectAtIndex:6] intValue] != 0;
            if (identifier != NULL)
                *identifier = photoId != 0 ? photoId : peerId;
            
            TLInputFileLocation$inputPeerPhotoFileLocation *location = [[TLInputFileLocation$inputPeerPhotoFileLocation alloc] init];
            location.peer_id = peerId;
            location.access_hash = accessHash;
            location.photo_id = photoId;
            location.peer_type = peerType;
            location.big = big;
            return location;
        }
    }
    else if ([url hasPrefix:@"photo:"])
    {
        NSArray *components = [url componentsSeparatedByString:@":"];
        if (components.count >= 7)
        {
            if (datacenterId != NULL)
                *datacenterId = [[components objectAtIndex:1] intValue];
            int64_t fileId = [[components objectAtIndex:2] longLongValue];
            int64_t accessHash = [[components objectAtIndex:3] longLongValue];
            NSString *thumbSize = [components objectAtIndex:5];
            NSData *fileReference = [NSData dataWithHexString:[components objectAtIndex:6]];
            if (identifier != NULL)
                *identifier = fileId;
            
            TLInputFileLocation$inputPhotoFileLocation *location = [[TLInputFileLocation$inputPhotoFileLocation alloc] init];
            location.n_id = fileId;
            location.access_hash = accessHash;
            NSData *originFileReference = [originInfo fileReference];
            location.file_reference = originFileReference.length != 0 ? originFileReference : (fileReference ?: [NSData data]);
            location.thumb_size = thumbSize ?: @"";
            return location;
        }
    }
    else if ([url hasPrefix:@"documentthumb:"])
    {
        NSArray *components = [url componentsSeparatedByString:@":"];
        if (components.count >= 7)
        {
            if (datacenterId != NULL)
                *datacenterId = [[components objectAtIndex:1] intValue];
            int64_t fileId = [[components objectAtIndex:2] longLongValue];
            int64_t accessHash = [[components objectAtIndex:3] longLongValue];
            NSString *thumbSize = [components objectAtIndex:5];
            NSData *fileReference = [NSData dataWithHexString:[components objectAtIndex:6]];
            if (identifier != NULL)
                *identifier = fileId;

            TLInputFileLocation$inputDocumentFileLocation *location = [[TLInputFileLocation$inputDocumentFileLocation alloc] init];
            location.n_id = fileId;
            location.access_hash = accessHash;
            NSData *originFileReference = [originInfo fileReference];
            location.file_reference = originFileReference.length != 0 ? originFileReference : (fileReference ?: [NSData data]);
            location.thumb_size = thumbSize ?: @"";
            return location;
        }
    }
    
    return nil;
}

typedef void (^TGRemoteImageDownloadCompletionBlock)(NSData *data);

@interface TGImageDownloadActor ()
{
    bool _updateMediaAccessTimeOnRelease;
    int32_t _messageId;
    int64_t _imageId;
    TGMediaOriginInfo *_originInfo;
    bool _multipart;
    bool _thumbnailOnly;
    NSString *_multipartFilePath;
}

@property (nonatomic, copy) TGRemoteImageDownloadCompletionBlock downloadCompletionBlock;

@property (nonatomic) float progress;
@property (nonatomic) bool requestedActors;
@property (atomic) NSInteger onegramImagePriority;

- (void)onegramCompletePeerAvatarData:(NSData *)imageData path:(NSString *)path cache:(TGCache *)cache storeUrl:(NSString *)storeUrl processorName:(NSString *)processorName allowMemoryCache:(bool)allowMemoryCache forceMemoryCache:(bool)forceMemoryCache allowThumbnailCache:(bool)allowThumbnailCache priority:(NSInteger)priority;

@end

@interface OnegramPeerAvatarRenderTask : NSObject

@property (nonatomic, weak) TGImageDownloadActor *actor;
@property (nonatomic, copy) dispatch_block_t block;
@property (nonatomic) NSInteger priority;

@end

@implementation OnegramPeerAvatarRenderTask
@end

@implementation TGImageDownloadActor

@synthesize actionHandle = _actionHandle;

@synthesize downloadCompletionBlock = _downloadCompletionBlock;

@synthesize progress = _progress;
@synthesize requestedActors = _requestedActors;

+ (NSString *)genericPath
{
    return @"/img/@";
}

+ (void)reloadForAccountSwitch
{
    [urlRewrites() removeAllObjects];
    [serverAssetData() removeAllObjects];
}

+ (void)addUrlRewrite:(NSString *)currentUrl newUrl:(NSString *)newUrl
{
    [urlRewrites() setObject:newUrl forKey:currentUrl];
}

+ (NSString *)possiblyRewrittenUrl:(NSString *)url
{
    NSString *newUrl = [urlRewrites() objectForKey:url];
    if (newUrl != nil)
        return newUrl;
    return url;
}

+ (NSDictionary *)serverMediaDataForAssetUrl:(NSString *)assetUrl
{
    if (assetUrl.length == 0)
        return nil;
    
    id object = [serverAssetData() objectForKey:assetUrl];
    if ([object isKindOfClass:[NSNull class]])
        return nil;
    
    if ([object isKindOfClass:[NSDictionary class]])
        return object;
    
    TGMediaAttachment *attachment = [TGDatabaseInstance() loadServerAssetData:assetUrl];
    if (attachment == nil)
    {
        [serverAssetData() setObject:[NSNull null] forKey:assetUrl];
        return nil;
    }
    
    NSDictionary *dict = nil;
    
    if (attachment.type == TGImageMediaAttachmentType)
    {
        TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
        imageAttachment.caption = nil;
        dict = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:imageAttachment.imageId], @"imageId", [[NSNumber alloc] initWithLongLong:imageAttachment.accessHash], @"accessHash", imageAttachment, @"imageAttachment", nil];
        [serverAssetData() setObject:dict forKey:assetUrl];
        return dict;
    }
    else if (attachment.type == TGVideoMediaAttachmentType)
    {
        TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
        videoAttachment.caption = nil;
        dict = [[NSDictionary alloc] initWithObjectsAndKeys:videoAttachment, @"videoAttachment", nil];
        [serverAssetData() setObject:dict forKey:assetUrl];
        return dict;
    }
    
    return nil;
}

+ (void)addServerMediaDataForAssetUrl:(NSString *)assetUrl attachment:(TGMediaAttachment *)attachment
{
    if (assetUrl.length == 0 || attachment == nil)
        return;
    
    [TGDatabaseInstance() storeServerAssetData:assetUrl attachment:attachment];
    
    if (attachment.type == TGImageMediaAttachmentType)
    {
        TGImageMediaAttachment *imageAttachment = (TGImageMediaAttachment *)attachment;
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:imageAttachment.imageId], @"imageId", [[NSNumber alloc] initWithLongLong:imageAttachment.accessHash], @"accessHash", imageAttachment, @"imageAttachment", nil];
        [serverAssetData() setObject:dict forKey:assetUrl];
    }
    else if (attachment.type == TGVideoMediaAttachmentType)
    {
        TGVideoMediaAttachment *videoAttachment = (TGVideoMediaAttachment *)attachment;
        NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:videoAttachment, @"videoAttachment", nil];
        [serverAssetData() setObject:dict forKey:assetUrl];
    }
}

+ (void)clearServerMediaSataForAssetUrl:(NSString *)assetUrl
{
    if (assetUrl.length == 0)
        return;
    
    [serverAssetData() removeObjectForKey:assetUrl];
    [TGDatabaseInstance() removeServerAssetData:assetUrl];
}

+ (NSOperationQueue *)operationQueue
{
    static NSOperationQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:performanceBackgroundWorkerCount()];
    });
    return queue;
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {   
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
    }
    return self;
}

- (void)prepare:(NSDictionary *)options
{
    _thumbnailOnly = [options[@"thumbnailOnly"] boolValue];
    if ([options[@"thumbnailOnly"] boolValue])
    {
        NSUInteger laneCount = OGPlatformUsesConstrainedBackgroundExecution() || OGRuntimeSingleCoreDevice() ? 1 : 2;
        self.requestQueueName = [NSString stringWithFormat:@"onegramMediaThumbnail-%lu", (unsigned long)([self.path hash] % laneCount)];
        return;
    }
    if (TGImageDownloadUsesPeerAvatarPipeline() && [self.path hasPrefix:@"/img/(download:"] && [self.path rangeOfString:@"peerphoto:"].location != NSNotFound)
    {
        NSUInteger lane = [self.path hash] % 4;
        self.requestQueueName = [NSString stringWithFormat:@"onegramPeerPhotoDownload-%lu", (unsigned long)lane];
        return;
    }

    if (options != nil)
    {
        int contentHints = [[options objectForKey:@"contentHints"] intValue];
        if (contentHints & TGRemoteImageContentHintLargeFile)
        {
            if ([[self.path substringFromIndex:6] hasPrefix:@"download:"]) {
                int datacenterId = 0;
                NSDictionary *userProperties = options[@"userProperties"];
                if ([userProperties respondsToSelector:@selector(objectForKey:)]) {
                    TGImageInfo *imageInfo = userProperties[@"imageInfo"];
                    if (imageInfo != nil) {
                        NSString *url = [imageInfo imageUrlForLargestSize:nil];
                        if (url != nil) {
                            if (!extractFileUrlComponents(url, &datacenterId, nil, nil, nil)) {
                                datacenterId = 0;
                            }
                        }
                    }
                }
                self.requestQueueName = [NSString stringWithFormat:@"imageDownload-%d", datacenterId];
            }
        }
    }
}

- (void)dealloc
{
    [_actionHandle reset];
    if (_requestedActors)
        [ActionStageInstance() removeWatcher:self];
}

static inline double imageProcessingPriority()
{
    if (cpuCoreCount() <= 1)
        return 0.4;
    return TGIsRetina() ? 0.4 : 0.12;
}

static NSOperationQueuePriority OnegramImageQueuePriority(NSInteger priority)
{
    if (priority >= 2)
        return NSOperationQueuePriorityVeryHigh;
    if (priority <= 0)
        return NSOperationQueuePriorityLow;
    return NSOperationQueuePriorityNormal;
}

static NSMutableArray *OnegramPeerAvatarHighRenderQueue = nil;
static NSMutableArray *OnegramPeerAvatarLowRenderQueue = nil;
static bool OnegramPeerAvatarRenderScheduled = false;

static void OnegramPumpPeerAvatarRenderQueue(void);

static dispatch_queue_t OnegramPeerAvatarRenderCoordinationQueue(void)
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.avatar-render", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

static dispatch_queue_t OnegramPeerAvatarRenderExecutionQueue(void)
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("dev.IllyaGIF.Onegram.avatar-render-execution", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    });
    return queue;
}

static void OnegramEnqueuePeerAvatarRender(TGImageDownloadActor *actor, NSInteger priority, dispatch_block_t block)
{
    if (actor == nil || block == nil)
        return;

    dispatch_async(OnegramPeerAvatarRenderCoordinationQueue(), ^
    {
        if (OnegramPeerAvatarHighRenderQueue == nil)
        {
            OnegramPeerAvatarHighRenderQueue = [[NSMutableArray alloc] init];
            OnegramPeerAvatarLowRenderQueue = [[NSMutableArray alloc] init];
        }

        OnegramPeerAvatarRenderTask *task = [[OnegramPeerAvatarRenderTask alloc] init];
        task.actor = actor;
        task.block = block;
        task.priority = priority;
        NSMutableArray *queue = priority >= 2 ? OnegramPeerAvatarHighRenderQueue : OnegramPeerAvatarLowRenderQueue;
        [queue addObject:task];
        if (!OnegramPeerAvatarRenderScheduled)
        {
            OnegramPeerAvatarRenderScheduled = true;
            OnegramPumpPeerAvatarRenderQueue();
        }
    });
}

static void OnegramPromotePeerAvatarRender(TGImageDownloadActor *actor)
{
    if (actor == nil)
        return;

    dispatch_async(OnegramPeerAvatarRenderCoordinationQueue(), ^
    {
        for (NSInteger index = (NSInteger)OnegramPeerAvatarLowRenderQueue.count - 1; index >= 0; index--)
        {
            OnegramPeerAvatarRenderTask *task = [OnegramPeerAvatarLowRenderQueue objectAtIndex:(NSUInteger)index];
            if (task.actor == actor)
            {
                task.priority = 2;
                [OnegramPeerAvatarLowRenderQueue removeObjectAtIndex:(NSUInteger)index];
                [OnegramPeerAvatarHighRenderQueue addObject:task];
            }
        }
    });
}

static void OnegramPrunePeerAvatarRenderQueue(NSMutableArray *queue)
{
    for (NSInteger index = (NSInteger)queue.count - 1; index >= 0; index--)
    {
        OnegramPeerAvatarRenderTask *task = [queue objectAtIndex:(NSUInteger)index];
        if (task.actor == nil || task.actor.cancelled)
            [queue removeObjectAtIndex:(NSUInteger)index];
    }
}

static void OnegramPeerAvatarRenderFinished(void)
{
    dispatch_async(OnegramPeerAvatarRenderCoordinationQueue(), ^
    {
        if (OnegramPeerAvatarHighRenderQueue.count != 0 || OnegramPeerAvatarLowRenderQueue.count != 0)
            OnegramPumpPeerAvatarRenderQueue();
        else
            OnegramPeerAvatarRenderScheduled = false;
    });
}

static void OnegramPumpPeerAvatarRenderQueue(void)
{
    OnegramPrunePeerAvatarRenderQueue(OnegramPeerAvatarHighRenderQueue);
    OnegramPrunePeerAvatarRenderQueue(OnegramPeerAvatarLowRenderQueue);
    bool hasHighPriorityWork = OnegramPeerAvatarHighRenderQueue.count != 0;
    if (OGRuntimeInteractionActiveFast() && !hasHighPriorityWork)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), OnegramPeerAvatarRenderCoordinationQueue(), ^
        {
            OnegramPumpPeerAvatarRenderQueue();
        });
        return;
    }

    NSMutableArray *queue = hasHighPriorityWork ? OnegramPeerAvatarHighRenderQueue : OnegramPeerAvatarLowRenderQueue;
    if (queue.count == 0)
    {
        OnegramPeerAvatarRenderScheduled = false;
        return;
    }

    OnegramPeerAvatarRenderTask *task = [queue objectAtIndex:0];
    [queue removeObjectAtIndex:0];

    dispatch_async(OnegramPeerAvatarRenderExecutionQueue(), ^
    {
        @autoreleasepool
        {
            task.block();
        }
        OnegramPeerAvatarRenderFinished();
    });
}


- (void)onegramCompletePeerAvatarData:(NSData *)imageData path:(NSString *)path cache:(TGCache *)cache storeUrl:(NSString *)storeUrl processorName:(NSString *)processorName allowMemoryCache:(bool)allowMemoryCache forceMemoryCache:(bool)forceMemoryCache allowThumbnailCache:(bool)allowThumbnailCache priority:(NSInteger)priority
{
    if (imageData.length == 0 || path.length == 0 || self.cancelled)
        return;

    __weak TGImageDownloadActor *weakSelf = self;
    NSInteger effectivePriority = MAX(priority, self.onegramImagePriority);
    OnegramEnqueuePeerAvatarRender(self, effectivePriority, ^
    {
        TGImageDownloadActor *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.cancelled)
            return;

        UIImage *sourceImage = [[UIImage alloc] initWithData:imageData];
        UIImage *image = sourceImage;
        if (image != nil && processorName.length != 0)
        {
            TGImageProcessor processor = [TGRemoteImageView imageProcessorForName:processorName];
            image = OnegramApplyImageProcessor(image, processor, processorName, [path hasPrefix:@"/img/({filter:"] ? [path substringFromIndex:[path rangeOfString:@"}"].location + 1] : path);
        }
        else if (image != nil)
        {
            image = [image preloadedImage];
        }

        if (image == nil)
        {
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                [ActionStageInstance() actionFailed:path reason:-1];
            }];
            return;
        }

        if (allowMemoryCache && (!TG_CACHE_INPLACE || forceMemoryCache))
            [cache cacheImage:image withData:nil url:storeUrl availability:TGCacheMemory];
        if (allowThumbnailCache)
            [cache cacheThumbnail:image url:storeUrl];

        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() nodeRetrieved:path node:[[SGraphObjectNode alloc] initWithObject:image]];
        }];
    });
}

- (void)execute:(NSDictionary *)options
{
    static CFAbsoluteTime lastCompletionTime = 0;
    static bool delayFastCompletion = false;
    const CFTimeInterval fastDelayThresold = 0.018;
    const CFTimeInterval minimalThreshold = 0.008;
    
    bool allowThumbnailCache = false;
    bool allowMemoryCache = true;
    
    int contentHints = 0;
    id userProperties = nil;
    
    bool forceMemoryCache = false;
    
    TGCache *cache = nil;
    if (options != nil)
    {
        NSNumber *cancelTimeout = [options objectForKey:@"cancelTimeout"];
        if (cancelTimeout != nil)
            self.cancelTimeout = [cancelTimeout intValue];
        cache = [options objectForKey:@"cache"];
        
        contentHints = [[options objectForKey:@"contentHints"] intValue];
        
        NSNumber *nAllowThumbnailCache = [options objectForKey:@"allowThumbnailCache"];
        if (nAllowThumbnailCache != nil)
            allowThumbnailCache = [nAllowThumbnailCache boolValue];
        
        NSNumber *nUseCache = [options objectForKey:@"useCache"];
        if (nUseCache != nil)
            allowMemoryCache = [nUseCache boolValue];
        
        userProperties = [options objectForKey:@"userProperties"];
        
        forceMemoryCache = [[options objectForKey:@"forceMemoryCache"] boolValue];
    }
    
    if (cache == nil)
        cache = [TGRemoteImageView sharedCache];
    
    NSString *path = self.path;
    
    NSString *actualPath = self.path;
    if ([actualPath hasPrefix:@"/img/(download:"])
        actualPath = [actualPath stringByReplacingOccurrencesOfString:@"/img/(download:" withString:@"/img/("];
    
    NSString *url = nil;
    TGImageProcessor processor = nil;
    NSString *processorName = nil;
    if ([actualPath hasPrefix:@"/img/({filter:"])
    {
        NSRange range = [actualPath rangeOfString:@"}"];
        if (range.location == NSNotFound)
        {
            [ActionStageInstance() nodeRetrieveFailed:self.path];
            return;
        }
        processorName = [actualPath substringWithRange:NSMakeRange(14, range.location - 14)];
        processor = [TGRemoteImageView imageProcessorForName:processorName];
        url = [actualPath substringWithRange:NSMakeRange(range.location + 1, actualPath.length - range.location - 1 - 1)];
    }
    else
        url = [actualPath substringWithRange:NSMakeRange(6, actualPath.length - 6 - 1)];
    
    NSString *rewrittenUrl = [TGImageDownloadActor possiblyRewrittenUrl:url];
    url = rewrittenUrl;

    bool onegramPeerPhoto = [url hasPrefix:@"peerphoto:"] && TGImageDownloadUsesPeerAvatarPipeline();
    NSNumber *onegramImagePriorityValue = [userProperties objectForKey:@"onegramImagePriority"];
    NSInteger onegramImagePriority = onegramImagePriorityValue == nil ? 2 : [onegramImagePriorityValue integerValue];
    self.onegramImagePriority = onegramImagePriority;
    
    NSString *storeUrl = [TGRemoteImageView cacheKeyForUrl:url filter:processor != nil ? processorName : nil];

    bool cacheFiltered = [processorName hasSuffix:@"+bake"];
    
    if ([url hasPrefix:@"asset-original:"] || [url hasPrefix:@"asset-thumbnail:"])
    {
        NSString *assetUrl = [url substringFromIndex:[url rangeOfString:@":"].location + 1];
        [TGImagePickerController loadAssetWithUrl:[[NSURL alloc] initWithString:assetUrl] completion:^(ALAsset *asset)
        {
            UIImage *image = nil;
            if (asset != nil)
            {
                if ([url hasPrefix:@"asset-original:"])
                {
                    UIImage *rawImage = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
                    if (processor != nil)
                        image = processor(rawImage);
                    else
                        image = [rawImage preloadedImage];
                    
                    if (image != nil && allowMemoryCache && (!TG_CACHE_INPLACE || forceMemoryCache))
                        [cache cacheImage:image withData:nil url:storeUrl availability:TGCacheMemory];
                }
                else
                {
                    image = TGMediaAssetLegacyAspectRatioThumbnailImage(asset);
                }
            }
            
            if (image != nil)
                [ActionStageInstance() nodeRetrieved:path node:[[SGraphObjectNode alloc] initWithObject:image]];
            else
                [ActionStageInstance() nodeRetrieveFailed:path];
        }];
        
        return;
    }
    
    UIImage *imageManagerImage = nil;
    if (!onegramPeerPhoto)
        imageManagerImage = [[TGImageManager instance] loadImageSyncWithUri:url canWait:true decode:processor == nil acceptPartialData:false asyncTaskId:NULL progress:nil partialCompletion:nil completion:nil];
    if (imageManagerImage != nil)
    {
        UIImage *image = processor != nil ? processor(imageManagerImage) : imageManagerImage;
        
        if (image != nil && allowMemoryCache && (!TG_CACHE_INPLACE || forceMemoryCache))
            [cache cacheImage:image withData:nil url:storeUrl availability:TGCacheMemory];
        
        if (image != nil)
            [ActionStageInstance() nodeRetrieved:path node:[[SGraphObjectNode alloc] initWithObject:image]];
        else
            [ActionStageInstance() nodeRetrieveFailed:path];
    }
    
    if ([url hasPrefix:@"dialogListPlaceholder:"])
    {
        int64_t conversationId = [[url substringFromIndex:@"dialogListPlaceholder:".length] longLongValue];
        
        UIImage *image = conversationId < 0 ? [[TGInterfaceAssets instance] groupAvatarPlaceholder:conversationId] : [[TGInterfaceAssets instance] avatarPlaceholder:(int)conversationId];
        
        if (image != nil && allowMemoryCache && (!TG_CACHE_INPLACE || forceMemoryCache))
            [cache cacheImage:image withData:nil url:storeUrl availability:TGCacheMemory];
        
        if (image != nil)
            [ActionStageInstance() nodeRetrieved:path node:[[SGraphObjectNode alloc] initWithObject:image]];
        else
            [ActionStageInstance() nodeRetrieveFailed:path];
    }
    
    NSString *url1 = url;
    NSString *url2 = nil;
    if (cacheFiltered)
    {
        url1 = storeUrl;
        url2 = url;
    }
    
    NSString *trimmedUrl1 = [TGRemoteImageView cacheKeyForUrl:url1 filter:nil];
    NSString *trimmedUrl2 = [TGRemoteImageView cacheKeyForUrl:url2 filter:nil];

    NSString *trimmedUrl = cacheFiltered ? trimmedUrl2 : trimmedUrl1;
    
    [cache diskCacheContains:trimmedUrl1 orUrl:trimmedUrl2 completion:^(bool firstInDiskCache, bool secondInDiskCache)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (firstInDiskCache || secondInDiskCache)
            {
                NSBlockOperation *operation = [[NSBlockOperation alloc] init];
                
                __weak NSOperation *blockOperation = operation;
                [operation addExecutionBlock:^
                {
                    @autoreleasepool
                    {
                        NSOperation *strongBlockOperation = blockOperation;
                        if (strongBlockOperation.isCancelled)
                            return;
                        strongBlockOperation = nil;
                        
                        NSString *cachedUrl = (firstInDiskCache ? trimmedUrl1 : trimmedUrl2);
                        if (onegramPeerPhoto)
                        {
                            NSData *avatarData = [cache cachedDataForUrl:cachedUrl];
                            if (avatarData.length != 0)
                            {
                                [self onegramCompletePeerAvatarData:avatarData path:path cache:cache storeUrl:storeUrl processorName:processorName allowMemoryCache:allowMemoryCache forceMemoryCache:forceMemoryCache allowThumbnailCache:allowThumbnailCache priority:onegramImagePriority];
                            }
                            else
                            {
                                [cache removeFromDiskCache:cachedUrl];
                                [ActionStageInstance() nodeRetrieveFailed:path];
                            }
                            return;
                        }
                        
                        UIImage *cachedImage = nil;
                        bool imageFromDisc = false;
                        if (cachedImage == nil)
                        {
                            cachedImage = [cache cachedImage:cachedUrl availability:TGCacheDisk];
                            imageFromDisc = true;
                        }
                        
                        strongBlockOperation = blockOperation;
                        if (strongBlockOperation.isCancelled)
                            return;
                        strongBlockOperation = nil;
                        
                        if (cachedImage != nil)
                        {
                            if (cacheFiltered && cachedImage != nil && processor != nil && firstInDiskCache)
                            {
                                [cachedImage tgPreload];
                            }
                            else
                            {
                                UIImage *originalImage = cachedImage;
                                if (processor != nil)
                                {
                                    cachedImage = OnegramApplyImageProcessor(cachedImage, processor, processorName, url1);
                                    
                                    if (cacheFiltered && !firstInDiskCache)
                                    {
                                        NSData *filteredData = UIImageJPEGRepresentation(cachedImage, 0.5f);
                                        [cache cacheImage:nil withData:filteredData url:storeUrl availability:TGCacheDisk];
                                    }
                                    
                                    if (cachedImage == originalImage && imageFromDisc)
                                        cachedImage = [cachedImage preloadedImage];
                                }
                                else if (imageFromDisc)
                                    cachedImage = [cachedImage preloadedImage];
                            }
                            
                            strongBlockOperation = blockOperation;
                            if (strongBlockOperation.isCancelled)
                                return;
                            strongBlockOperation = nil;
                            
                            if (imageFromDisc)
                            {
                                if (allowMemoryCache && (!TG_CACHE_INPLACE || forceMemoryCache))
                                    [cache cacheImage:cachedImage withData:nil url:storeUrl availability:TGCacheMemory];
                                
                                if (allowThumbnailCache)
                                    [cache cacheThumbnail:cachedImage url:storeUrl];
                            }
                            
                            strongBlockOperation = blockOperation;
                            if (strongBlockOperation.isCancelled)
                                return;
                            strongBlockOperation = nil;
                            
                            [ActionStageInstance() dispatchOnStageQueue:^
                            {
                                if (delayFastCompletion && cachedImage.size.width * cachedImage.size.height > 200 * 200)
                                {
                                    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                                    CFAbsoluteTime threshold = cachedImage.size.width * cachedImage.size.height <= 200 * 200 ? minimalThreshold : fastDelayThresold;
                                    if (currentTime - lastCompletionTime < threshold)
                                    {
                                        CFTimeInterval delay = threshold - (currentTime - lastCompletionTime);
                                        lastCompletionTime = currentTime;
                                        usleep((int32_t)(delay * 1000 * 1000));
                                    }
                                    else
                                        lastCompletionTime = currentTime;
                                }
                                
                                [ActionStageInstance() nodeRetrieved:path node:[[SGraphObjectNode alloc] initWithObject:cachedImage]];
                            }];
                            
                            return;
                        }
                        else
                        {
                            [cache removeFromDiskCache:cachedUrl];
                            [ActionStageInstance() nodeRetrieveFailed:path];
                        }
                    }
                }];
                operation.threadPriority = imageProcessingPriority();
                if (TGImageDownloadUsesPeerAvatarPipeline())
                    operation.queuePriority = OnegramImageQueuePriority(onegramImagePriority);
                self.cancelToken = operation;
                [[TGImageDownloadActor operationQueue] addOperation:operation];
            }
            else
            {
                if ([url1 hasPrefix:@"video-thumbnail-"])
                {
                    [ActionStageInstance() nodeRetrieveFailed:path];
                    return;
                }
                
                if ([self.path hasPrefix:@"/img/(download:"])
                {
                    _originInfo = options[@"originInfo"];
                    
                    NSBlockOperation *processingOperation = [[NSBlockOperation alloc] init];
                    __block bool processingOperationScheduled = false;
                    __weak TGImageDownloadActor *weakSelf = self;
                    self.cancelToken = processingOperation;
                    self.downloadCompletionBlock = ^(NSData *imageData)
                    {
                        @synchronized (processingOperation)
                        {
                            if (processingOperationScheduled)
                                return;
                            processingOperationScheduled = true;
                        }
                        if (imageData != nil)
                        {
                            __weak NSOperation *weakBlockOperation = processingOperation;
                            [processingOperation addExecutionBlock:^
                            {
                                @autoreleasepool
                                {
                                    NSOperation *blockOperation = weakBlockOperation;
                                    if (blockOperation.isCancelled)
                                        return;
                                    if (onegramPeerPhoto)
                                    {
                                        [cache cacheImage:nil withData:imageData url:trimmedUrl availability:TGCacheDisk];
                                        [weakSelf onegramCompletePeerAvatarData:imageData path:path cache:cache storeUrl:storeUrl processorName:processorName allowMemoryCache:allowMemoryCache forceMemoryCache:forceMemoryCache allowThumbnailCache:allowThumbnailCache priority:onegramImagePriority];
                                        return;
                                    }
                                    
                                    UIImage *image = nil;
                                    NSData *data = nil;
                                    
                                    image = [[UIImage alloc] initWithData:imageData];
                                    data = imageData;
                                    
                                    if (image == nil || data == nil)
                                    {
                                        [ActionStageInstance() actionFailed:path reason:-1];
                                    }
                                    else
                                    {
                                        UIImage *imageForThumbnail = nil;
                                        
                                        TGImageInfo *imageInfo = [userProperties objectForKey:@"imageInfo"];
                                        if (imageInfo != nil)
                                            imageForThumbnail = image;
                                        
                                        if (image != nil)
                                        {
                                            [cache cacheImage:nil withData:data url:trimmedUrl availability:TGCacheDisk];
                                            
                                            if (processor != nil)
                                            {   
                                                UIImage *originalImage = image;
                                                image = OnegramApplyImageProcessor(image, processor, processorName, trimmedUrl);
                                                if (image == originalImage)
                                                    image = [image preloadedImage];
                                                
                                                if (allowMemoryCache && (!TG_CACHE_INPLACE || forceMemoryCache))
                                                    [cache cacheImage:image withData:nil url:storeUrl availability:TGCacheMemory];
                                                
                                                if (allowThumbnailCache)
                                                    [cache cacheThumbnail:image url:storeUrl];
                                            }
                                            else
                                            {
                                                image = [image preloadedImage];
                                                
                                                if (allowMemoryCache && (!TG_CACHE_INPLACE || forceMemoryCache))
                                                    [cache cacheImage:image withData:nil url:storeUrl availability:TGCacheMemory];
                                                
                                                if (allowThumbnailCache)
                                                    [cache cacheThumbnail:image url:storeUrl];
                                            }
                                            
                                            if (delayFastCompletion)
                                            {
                                                CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                                                CFAbsoluteTime threshold = image.size.width * image.size.height <= 180 * 180 ? minimalThreshold : fastDelayThresold;
                                                if (currentTime - lastCompletionTime < threshold)
                                                {
                                                    CFTimeInterval delay = threshold - (currentTime - lastCompletionTime);
                                                    lastCompletionTime = currentTime;
                                                    usleep((int32_t)(delay * 1000 * 1000));
                                                }
                                                else
                                                    lastCompletionTime = currentTime;
                                            }
                                            
                                            [ActionStageInstance() dispatchOnStageQueue:^
                                            {
                                                [ActionStageInstance() nodeRetrieved:path node:[[SGraphObjectNode alloc] initWithObject:image]];
                                                
                                                if (imageInfo != nil && imageForThumbnail != nil && ![url hasPrefix:@"upload"])
                                                {
                                                    CGSize thumbnailSize = CGSizeZero;
                                                    NSString *thumbnailUrl = [imageInfo closestImageUrlWithSize:CGSizeMake(90, 90) resultingSize:&thumbnailSize];
                                                    if (thumbnailUrl != nil)
                                                    {
                                                        thumbnailSize = TGFitSize(CGSizeMake(imageForThumbnail.size.width * imageForThumbnail.scale, imageForThumbnail.size.height * imageForThumbnail.scale), [TGGenericModernConversationCompanion preferredInlineThumbnailSize]);
                                                        
                                                        UIImage *thumbnailImage = TGScaleImageToPixelSize(imageForThumbnail, thumbnailSize);
                                                        if (thumbnailImage != nil)
                                                        {
                                                            NSData *thumbnailData = UIImageJPEGRepresentation(thumbnailImage, 0.85f);
                                                            if (thumbnailData != nil)
                                                            {
                                                                [cache removeFromMemoryCache:thumbnailUrl matchEnd:true];
                                                                
                                                                
                                                                [cache cacheImage:nil withData:thumbnailData url:thumbnailUrl availability:TGCacheDisk];
                                                                
                                                                TGFileDownloadActor *fileActor = (TGFileDownloadActor *)[ActionStageInstance() executingActorWithPath:[[NSString alloc] initWithFormat:@"/tg/file/(%@)", thumbnailUrl]];
                                                                if (fileActor != nil)
                                                                {
                                                                    [fileActor completeWithData:thumbnailData];
                                                                }
                                                                else
                                                                {
                                                                    TGDispatchAfter(0.08, [ActionStageInstance() globalStageDispatchQueue], ^
                                                                    {
                                                                        [ActionStageInstance() dispatchResource:[[NSString alloc] initWithFormat:@"/as/media/imageThumbnailUpdated"] resource:thumbnailUrl];
                                                                    });
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                                
                                                if ([[userProperties objectForKey:@"storeAsAsset"] boolValue])
                                                {
                                                    bool shouldSave = true;
                                                    
                                                    if (![userProperties[@"forceSave"] boolValue])
                                                    {
                                                        int mid = [userProperties[@"messageId"] intValue];
                                                        int64_t conversationId = [userProperties[@"conversationId"] longLongValue];
                                                        if (mid != 0 && conversationId != 0)
                                                        {
                                                            int minAutosaveMid = [TGDatabaseInstance() minAutosaveMessageIdForConversation:conversationId];
                                                        }
                                                        
                                                        if (TGPeerIdIsChannel(conversationId)) {
                                                            shouldSave = false;
                                                        }
                                                    }
                                                    
                                                    if (shouldSave)
                                                    {
                                                        [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/checkImageStored/(%lu)", (unsigned long)[trimmedUrl hash]] options:[[NSDictionary alloc] initWithObjectsAndKeys:trimmedUrl, @"url", nil] watcher:TGTelegraphInstance];
                                                    }
                                                }
                                            }];
                                        }
                                        else
                                        {
                                            [ActionStageInstance() nodeRetrieveFailed:path];
                                        }
                                    }
                                }
                            }];
                            
                            processingOperation.threadPriority = imageProcessingPriority();
                            if (TGImageDownloadUsesPeerAvatarPipeline())
                                processingOperation.queuePriority = OnegramImageQueuePriority(onegramImagePriority);
                            [[TGImageDownloadActor operationQueue] addOperation:processingOperation];
                        }
                        else
                        {
                            [ActionStageInstance() nodeRetrieveFailed:path];
                        }
                    };
                    
                    if (contentHints & TGRemoteImageContentHintLargeFile && userProperties != nil && [[userProperties objectForKey:@"messageId"] intValue] != 0 && [userProperties objectForKey:@"mediaId"] != nil)
                    {
                        int64_t conversationId = [userProperties[@"conversationId"] longLongValue];
                        int32_t messageId = [[userProperties objectForKey:@"messageId"] intValue];
                        [[TGDownloadManager instance] enqueueItem:self.path messageId:[[userProperties objectForKey:@"messageId"] intValue] itemId:[userProperties objectForKey:@"mediaId"] groupId:conversationId itemClass:TGDownloadItemClassImage];
                        
                        _updateMediaAccessTimeOnRelease = true;
                        _messageId = messageId;
                        TGMediaId *mediaId = [userProperties objectForKey:@"mediaId"];
                        _imageId = mediaId.itemId;
                        
                        TGImageInfo *imageInfo = [userProperties objectForKey:@"imageInfo"];
                        if (imageInfo != nil)
                        {
                            int fileSize = [imageInfo fileSizeForUrl:trimmedUrl];
                            if (fileSize > 1 * 1024 * 1024)
                                _multipart = true;
                        }
                    }
                    
                    _requestedActors = true;
                    int modernDatacenterId = 0;
                    int64_t modernIdentifier = _imageId;
                    TLInputFileLocation *modernLocation = IOS6ModernInputLocationFromImageUrl(trimmedUrl, _originInfo, &modernDatacenterId, &modernIdentifier);
                    if (modernLocation != nil)
                    {
                        static NSString *filesDirectory = nil;
                        static dispatch_once_t onceToken;
                        dispatch_once(&onceToken, ^
                        {
                            filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"temp"];
                        });
                        
                        NSString *fileDirectoryName = [[NSString alloc] initWithFormat:@"modern-%lu", (unsigned long)[trimmedUrl hash]];
                        NSString *fileDirectory = [filesDirectory stringByAppendingPathComponent:fileDirectoryName];
                        
                        [[NSFileManager defaultManager] createDirectoryAtPath:fileDirectory withIntermediateDirectories:true attributes:nil error:nil];
                        
                        _multipartFilePath = [fileDirectory stringByAppendingPathComponent:@"temporary"];
                        
                        NSMutableDictionary *multiPartOptions = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                                                  @"identifier": @(modernIdentifier),
                                                                                                                  @"fileLocation": modernLocation,
                                                                                                                  @"storeFilePath": _multipartFilePath,
                                                                                                                  @"datacenterId": @(modernDatacenterId),
                                                                                                                  @"encryptionArgs": @{},
                                                                                                                  @"mediaTypeTag": @(TGNetworkMediaTypeTagImage),
                                                                                                                  @"completeWithData": @true
                                                                                                                  }];
                        TGImageInfo *imageInfo = userProperties[@"imageInfo"];
                        int expectedSize = [imageInfo fileSizeForUrl:trimmedUrl];
                        NSArray *locationParts = [trimmedUrl componentsSeparatedByString:@":"];
                        if (expectedSize <= 0 && locationParts.count >= 7 && ([trimmedUrl hasPrefix:@"photo:"] || [trimmedUrl hasPrefix:@"documentthumb:"]))
                            expectedSize = [locationParts[4] intValue];
                        if (expectedSize > 0)
                            multiPartOptions[@"encryptedSize"] = @(expectedSize);
                        if ([options[@"thumbnailOnly"] boolValue])
                            multiPartOptions[@"thumbnailOnly"] = @true;
                        if (_originInfo != nil)
                            multiPartOptions[@"originInfo"] = _originInfo;
                        
                        NSString *multipartPath = [[NSString alloc] initWithFormat:@"/tg/multipart-file/(modern-image:%lld:%d:%lu)", modernIdentifier, modernDatacenterId, (unsigned long)[trimmedUrl hash]];
                        int multipartFlags = [[userProperties objectForKey:@"changePriority"] boolValue] ? TGActorRequestChangePriority : 0;
                        [ActionStageInstance() requestActor:multipartPath options:multiPartOptions flags:multipartFlags watcher:self];
                    }
                    else if (_multipart)
                    {
                        static NSString *filesDirectory = nil;
                        static dispatch_once_t onceToken;
                        dispatch_once(&onceToken, ^
                        {
                            filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"temp"];
                        });
                        
                        NSString *fileDirectoryName = trimmedUrl;
                        NSString *fileDirectory = [filesDirectory stringByAppendingPathComponent:fileDirectoryName];
                        
                        [[NSFileManager defaultManager] createDirectoryAtPath:fileDirectory withIntermediateDirectories:true attributes:nil error:nil];
                        
                        _multipartFilePath = [fileDirectory stringByAppendingPathComponent:@"temporary"];
                        
                        int datacenterId = 0;
                        int64_t volumeId = 0;
                        int localId = 0;
                        int64_t secret = 0;
                        if (extractFileUrlComponents(trimmedUrl, &datacenterId, &volumeId, &localId, &secret))
                        {
                            TLInputFileLocation$inputFileLocation *fileLocation = [[TLInputFileLocation$inputFileLocation alloc] init];
                            fileLocation.volume_id = volumeId;
                            fileLocation.local_id = (int32_t)localId;
                            fileLocation.secret = secret;
                            if (options[@"originInfo"] != nil)
                                fileLocation.file_reference = [options[@"originInfo"] fileReferenceForVolumeId:volumeId localId:localId];

                            NSMutableDictionary *multiPartOptions = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                                                      @"identifier": @(_imageId),
                                                                                                                      @"fileLocation": fileLocation,
                                                                                                                      @"storeFilePath": _multipartFilePath,
                                                                                                                      @"datacenterId": @(datacenterId),
                                                                                                                      @"encryptionArgs": @{},
                                                                                                                      @"mediaTypeTag": @(TGNetworkMediaTypeTagImage),
                                                                                                                      @"completeWithData": @true
                                                                                                                      }];
                            
                            if (options[@"originInfo"] != nil)
                                multiPartOptions[@"originInfo"] = options[@"originInfo"];
                            if (_thumbnailOnly)
                                multiPartOptions[@"thumbnailOnly"] = @true;
                            int expectedSize = [userProperties[@"imageInfo"] fileSizeForUrl:trimmedUrl];
                            if (expectedSize > 0)
                                multiPartOptions[@"encryptedSize"] = @(expectedSize);
                            
                            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/multipart-file/(image:%" PRId64 ":%d:%d)", volumeId, localId, datacenterId] options:multiPartOptions watcher:self];
                        }
                    }
                    else
                    {
                        NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
                        options[@"mediaTypeTag"] = @(TGNetworkMediaTypeTagImage);
                        options[@"url"] = url;
                        if (_thumbnailOnly)
                            options[@"thumbnailOnly"] = @true;
                        if (_originInfo != nil)
                            options[@"originInfo"] = _originInfo;
                        
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/file/(%@)", url] options:options watcher:self];
                    }
                }
                else
                {
                    if (![url hasPrefix:@"upload"])
                        [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:@"progress" message:[[NSNumber alloc] initWithFloat:0.0f]];
                    
                    _requestedActors = true;
                    [ActionStageInstance() requestActor:[self.path stringByReplacingOccurrencesOfString:@"/img/(" withString:@"/img/(download:"] options:options flags:([[userProperties objectForKey:@"changePriority"] boolValue] ? TGActorRequestChangePriority : 0) watcher:self];
                }
            }
        }];
    }];
}

- (void)actorReportedProgress:(NSString *)path progress:(float)progress
{
    if ([path hasPrefix:@"/tg/file/"] || [path hasPrefix:@"/tg/multipart-file/"] || [path hasPrefix:@"/img/"])
    {
        _progress = progress;
        [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:@"progress" message:[[NSNumber alloc] initWithFloat:_progress]];
    }
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([path hasPrefix:@"/img/"] || [path hasPrefix:@"/tg/multipart-file/"])
    {
        if ([messageType isEqualToString:@"progress"])
        {
            _progress = [message floatValue];
            
            [ActionStageInstance() dispatchMessageToWatchers:self.path messageType:messageType message:message];
        }
    }
}

- (void)watcherJoined:(ASHandle *)watcherHandle options:(NSDictionary *)options waitingInActorQueue:(bool)waitingInActorQueue
{
    [watcherHandle receiveActorMessage:self.path messageType:@"progress" message:[[NSNumber alloc] initWithFloat:_progress]];
    NSInteger priority = [[options[@"userProperties"] objectForKey:@"onegramImagePriority"] integerValue];
    if (TGImageDownloadUsesPeerAvatarPipeline() && priority >= 2)
    {
        self.onegramImagePriority = MAX(self.onegramImagePriority, priority);
        if ([self.cancelToken isKindOfClass:[NSOperation class]])
            [(NSOperation *)self.cancelToken setQueuePriority:NSOperationQueuePriorityVeryHigh];
        OnegramPromotePeerAvatarRender(self);
    }
    
    [super watcherJoined:watcherHandle options:options waitingInActorQueue:waitingInActorQueue];
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    if ([path hasPrefix:@"/tg/file/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            if (self.downloadCompletionBlock)
                self.downloadCompletionBlock(((SGraphObjectNode *)result).object);
        }
        else
        {
            [ActionStageInstance() nodeRetrieveFailed:self.path];
            self.downloadCompletionBlock = nil;
        }
    }
    else if ([path hasPrefix:@"/tg/multipart-file/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            if (self.downloadCompletionBlock)
                self.downloadCompletionBlock(result);
            
            [[NSFileManager defaultManager] removeItemAtPath:_multipartFilePath error:nil];
        }
        else
        {
            [ActionStageInstance() nodeRetrieveFailed:self.path];
            self.downloadCompletionBlock = nil;
        }
    }
    else if ([path hasPrefix:@"/img/"])
    {
        if (resultCode == ASStatusSuccess)
        {
            [ActionStageInstance() actionCompleted:self.path result:result];
        }
        else
        {
            [ActionStageInstance() nodeRetrieveFailed:self.path];
        }
    }
}

- (void)cancel
{
    if (self.cancelToken != nil)
    {
        if ([self.cancelToken isKindOfClass:[NSOperation class]])
            [((NSOperation *)self.cancelToken) cancel];
        else
            [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        
        self.cancelToken = nil;
        self.downloadCompletionBlock = nil;
    }
    
    [ActionStageInstance() removeWatcher:self];
    
    [super cancel];
}

@end
