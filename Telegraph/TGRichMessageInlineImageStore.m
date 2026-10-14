#import "TGRichMessageInlineImageStore.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageManager.h"

extern void TGIOS6LoadCustomEmojiThumbnail(int64_t documentId, void (^completion)(NSString *thumbnailUri));

static NSUInteger TGRichMessagePreparationDepth = 0;

NSString *const TGRichMessageInlineImageLoadedNotification = @"TGRichMessageInlineImageLoadedNotification";

static NSCache *TGRichMessageInlineImageCache(void)
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.countLimit = 256;
    });
    return cache;
}

static NSMutableDictionary *TGRichMessageInlineImageRequests(void)
{
    static NSMutableDictionary *requests = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        requests = [[NSMutableDictionary alloc] init];
    });
    return requests;
}

@implementation TGRichMessageInlineImageStore

+ (void)performWithoutStartingRequests:(dispatch_block_t)block
{
    if (block == nil) return;
    if (![NSThread isMainThread]) { block(); return; }
    TGRichMessagePreparationDepth++;
    @try { block(); }
    @finally { TGRichMessagePreparationDepth--; }
}

+ (UIImage *)imageForKey:(NSString *)key
{
    if (key == nil)
        return nil;
    return [TGRichMessageInlineImageCache() objectForKey:key];
}

+ (void)requestImageForKey:(NSString *)key signalGenerator:(SSignal *(^)(void))signalGenerator
{
    if (key == nil || signalGenerator == nil || [self imageForKey:key] != nil)
        return;
    if ([NSThread isMainThread] && TGRichMessagePreparationDepth != 0)
        return;

    NSMutableDictionary *requests = TGRichMessageInlineImageRequests();
    SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
    @synchronized(requests)
    {
        if (requests[key] != nil)
            return;
        requests[key] = disposable;
    }

    [disposable setDisposable:[signalGenerator() startWithNext:^(id next)
    {
        if (![next isKindOfClass:[UIImage class]])
            return;
        [TGRichMessageInlineImageCache() setObject:next forKey:key];
        @synchronized(requests)
        {
            [requests removeObjectForKey:key];
        }
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:TGRichMessageInlineImageLoadedNotification object:nil userInfo:@{@"key": key}];
        });
    } error:^(__unused id error)
    {
        @synchronized(requests)
        {
            [requests removeObjectForKey:key];
        }
    } completed:^
    {
        @synchronized(requests)
        {
            [requests removeObjectForKey:key];
        }
    }]];
}

+ (NSString *)customEmojiKey:(int64_t)documentId
{
    return [[NSString alloc] initWithFormat:@"custom-emoji-%lld", documentId];
}

+ (SSignal *)imageSignalForUri:(NSString *)uri
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        if (uri.length == 0)
        {
            [subscriber putCompletion];
            return nil;
        }
        id taskId = [[TGImageManager instance] beginLoadingImageAsyncWithUri:uri decode:true progress:nil partialCompletion:nil completion:^(UIImage *image)
        {
            if (image != nil)
                [subscriber putNext:image];
            [subscriber putCompletion];
        }];
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            if (taskId != nil)
                [[TGImageManager instance] cancelTaskWithId:taskId];
        }];
    }];
}

+ (SSignal *)customEmojiImageSignal:(int64_t)documentId
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SMetaDisposable *imageDisposable = [[SMetaDisposable alloc] init];
        TGIOS6LoadCustomEmojiThumbnail(documentId, ^(NSString *thumbnailUri)
        {
            if (thumbnailUri.length == 0)
            {
                [subscriber putCompletion];
                return;
            }
            [imageDisposable setDisposable:[[TGRichMessageInlineImageStore imageSignalForUri:thumbnailUri] startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        });
        return imageDisposable;
    }];
}

@end
