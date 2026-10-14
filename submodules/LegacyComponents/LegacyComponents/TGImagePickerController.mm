#import "TGImagePickerController.h"

#import <AssetsLibrary/AssetsLibrary.h>

#import "SSignalKitCompat/SSignalKit.h"

#import "LegacyComponentsInternal.h"

static const char *assetsProcessingQueueSpecific = "assetsProcessingQueue";

static dispatch_queue_t assetsProcessingQueue()
{
    static dispatch_queue_t queue = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.tg.assetsqueue", 0);
        dispatch_queue_set_specific(queue, assetsProcessingQueueSpecific, (void *)assetsProcessingQueueSpecific, NULL);
    });
    
    return queue;
}

void dispatchOnAssetsProcessingQueue(dispatch_block_t block)
{
    bool isCurrentQueueAssetsProcessingQueue = false;
    isCurrentQueueAssetsProcessingQueue = dispatch_get_specific(assetsProcessingQueueSpecific) != NULL;
    
    if (isCurrentQueueAssetsProcessingQueue)
        block();
    else
        dispatch_async(assetsProcessingQueue(), block);
}

static ALAssetsLibrary *sharedLibrary = nil;
static STimer *sharedLibraryReleaseTimer = nil;
static int sharedLibraryRetainCount = 0;

void sharedAssetsLibraryRetain()
{
#if defined(ONEGRAM_ARMV6)
    dispatchOnAssetsProcessingQueue(^
    {
        sharedLibraryRetainCount++;
    });
#else
    dispatchOnAssetsProcessingQueue(^
    {
        if (sharedLibraryReleaseTimer != nil)
        {
            [sharedLibraryReleaseTimer invalidate];
            sharedLibraryReleaseTimer = nil;
        }
        
        if (sharedLibrary == nil)
        {
            sharedLibraryRetainCount = 1;
            sharedLibrary = [[ALAssetsLibrary alloc] init];
            
            if (iosMajorVersion() == 5)
                [sharedLibrary writeImageToSavedPhotosAlbum:nil metadata:nil completionBlock:^(__unused NSURL *assetURL, __unused NSError *error) { }];
            
            [sharedLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop)
            {
                if (group != nil)
                {
                    if (stop != NULL)
                        *stop = true;
                    
                    [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                    [group numberOfAssets];
                }
            } failureBlock:^(__unused NSError *error)
            {
                TGLegacyLog(@"assets access error");
            }];
        }
        else
            sharedLibraryRetainCount++;
    });
#endif
}

void sharedAssetsLibraryRelease()
{
    dispatchOnAssetsProcessingQueue(^
    {
        sharedLibraryRetainCount--;
        if (sharedLibraryRetainCount <= 0)
        {
            sharedLibraryRetainCount = 0;
#if !defined(ONEGRAM_ARMV6)
            if (sharedLibraryReleaseTimer != nil)
            {
                [sharedLibraryReleaseTimer invalidate];
                sharedLibraryReleaseTimer = nil;
            }
            
            sharedLibraryReleaseTimer = [[STimer alloc] initWithTimeout:4 repeat:false completion:^
            {
                sharedLibraryReleaseTimer = nil;
                sharedLibrary = nil;
            } nativeQueue:assetsProcessingQueue()];
            [sharedLibraryReleaseTimer start];
#endif
        }
    });
}

@interface TGAssetsLibraryHolder : NSObject

@end

@implementation TGAssetsLibraryHolder

- (void)dealloc
{
    sharedAssetsLibraryRelease();
}

@end

@interface TGImagePickerController ()

@end

@implementation TGImagePickerController

+ (id)sharedAssetsLibrary
{
#if defined(ONEGRAM_ARMV6)
    return nil;
#else
    return sharedLibrary;
#endif
}

+ (id)preloadLibrary
{
#if defined(ONEGRAM_ARMV6)
    sharedAssetsLibraryRetain();
#else
    dispatchOnAssetsProcessingQueue(^
    {
        if ([(id)[ALAssetsLibrary class] respondsToSelector:@selector(authorizationStatus)])
        {
            if ([ALAssetsLibrary authorizationStatus] != ALAuthorizationStatusAuthorized)
                return;
        }
        sharedAssetsLibraryRetain();
    });
#endif
    TGAssetsLibraryHolder *libraryHolder = [[TGAssetsLibraryHolder alloc] init];
    return libraryHolder;
}

+ (void)loadAssetWithUrl:(NSURL *)url completion:(void (^)(ALAsset *asset))completion
{
#if defined(ONEGRAM_ARMV6)
    dispatchOnAssetsProcessingQueue(^
    {
        if (completion)
            completion(nil);
    });
#else
    dispatchOnAssetsProcessingQueue(^
    {
        if (sharedLibrary != nil)
        {
            [sharedLibrary assetForURL:url resultBlock:^(ALAsset *asset)
            {
                if (completion)
                    completion(asset);
            } failureBlock:^(__unused NSError *error)
            {
                if (completion)
                    completion(nil);
            }];
        }
        else
        {
            if (completion)
                completion(nil);
        }
    });
#endif
}

+ (void)storeImageAsset:(NSData *)data
{
#if defined(ONEGRAM_ARMV6)
    UIImage *image = [[UIImage alloc] initWithData:data];
    if (image != nil)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, NULL);
        });
    }
#else
    dispatchOnAssetsProcessingQueue(^
    {
        ALAssetsLibrary *library = sharedLibrary;
        if (library == nil)
            library = [[ALAssetsLibrary alloc] init];
        [library writeImageDataToSavedPhotosAlbum:data metadata:nil completionBlock:nil];
    });
#endif
}

@end
