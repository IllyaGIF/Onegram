#import "TGModernFlatteningViewModel.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGModernFlatteningView.h"

#import "TGReusableLabel.h"

#import "../OnegramRuntime/OGRuntime.h"

#include <pthread.h>
#include <sched.h>
#import "../OnegramPlatform/OGPlatformDispatch.h"

CGFloat TGModernFlatteningViewModelTilingLimit = 512.0f;

static const CGFloat TGModernFlatteningTileHeight = 256.0f;
static const CGFloat TGModernFlatteningRequiredTileInset = 24.0f;
static const CGFloat TGModernFlatteningPrefetchTileInset = 384.0f;
static const NSUInteger TGModernFlatteningPrerenderTileCount = 2;
static const CGFloat TGModernFlatteningVisibleTaskPriority = -1.0f;
static const CGFloat TGModernFlatteningUnboundTaskPriority = 200000.0f;
static const double TGModernFlatteningVisibleThreadPriority = 0.55;
static const double TGModernFlatteningPrerenderThreadPriority = 0.5;
static const NSUInteger TGModernFlatteningSingleCorePendingTaskLimit = 24;
static const NSUInteger TGModernFlatteningMultiCorePendingTaskLimit = 96;
static NSString *const TGModernFlatteningTileViewIdentifier = @"TGModernFlatteningView";

enum {
    TGModernFlatteningRenderTaskQueued = 0,
    TGModernFlatteningRenderTaskRunning = 1,
    TGModernFlatteningRenderTaskFinished = 2
};

@class TGModernFlatteningViewModel;

@interface TGModernFlatteningRenderTask : NSObject
{
@public
    TGModernDrawingRecording *_recording;
    CGRect _rect;
    CGFloat _priority;
    int _state;
    bool _cancelled;
    CGImageRef _image;
    __weak TGModernFlatteningViewModel *_model;
}

@end

@implementation TGModernFlatteningRenderTask

- (void)dealloc
{
    if (_image != NULL)
        CGImageRelease(_image);
}

@end

@interface TGModernFlatteningTile : NSObject
{
@public
    CGRect _rect;
    id _image;
    NSUInteger _bytes;
    TGModernFlatteningRenderTask *_task;
    TGModernFlatteningView *_view;
}

@end

@implementation TGModernFlatteningTile

@end

@interface TGModernFlatteningViewModel ()
{
    TGModernViewContext *_context;
    TGModernViewStorage *_viewStorage;

    bool _tiledMode;
    bool _needsContentUpdate;

    NSMutableArray *_tiles;
    bool _tilesValid;
    bool _contentsRetryScheduled;
    NSTimeInterval _contentsRetryDelay;
    TGModernDrawingRecording *_recording;
    CGSize _contentSize;

    CGRect _lastVisibleRect;
    bool _hasLastVisibleRect;

    NSUInteger _cachedBytes;
    bool _inCacheList;
}

- (void)_renderTaskCompleted:(TGModernFlatteningRenderTask *)task;
- (void)_dropCachedContents;

@end

static pthread_mutex_t TGModernFlatteningTaskLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t TGModernFlatteningWorkCondition = PTHREAD_COND_INITIALIZER;
static NSMutableArray *TGModernFlatteningTasks = nil;
static bool TGModernFlatteningWorkerStarted = false;

static CFMutableArrayRef TGModernFlatteningCacheList = NULL;
static NSUInteger TGModernFlatteningCacheBytes = 0;
static pthread_mutex_t TGModernFlatteningCacheLock;
static pthread_once_t TGModernFlatteningCacheLockOnce = PTHREAD_ONCE_INIT;

static void TGModernFlatteningCacheLockInitialize(void)
{
    pthread_mutexattr_t attributes;
    pthread_mutexattr_init(&attributes);
    pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&TGModernFlatteningCacheLock, &attributes);
    pthread_mutexattr_destroy(&attributes);
}

static void TGModernFlatteningCacheLockAcquire(void)
{
    pthread_once(&TGModernFlatteningCacheLockOnce, TGModernFlatteningCacheLockInitialize);
    pthread_mutex_lock(&TGModernFlatteningCacheLock);
}

static void TGModernFlatteningCacheLockRelease(void)
{
    pthread_mutex_unlock(&TGModernFlatteningCacheLock);
}

#if defined(ONEGRAM_DIAGNOSTICS)
static NSUInteger TGModernFlatteningStatsCacheHits = 0;
static NSUInteger TGModernFlatteningStatsAsyncHits = 0;
static NSUInteger TGModernFlatteningStatsWaits = 0;
static NSUInteger TGModernFlatteningStatsSteals = 0;
static NSUInteger TGModernFlatteningStatsSyncRenders = 0;
static double TGModernFlatteningStatsSyncDuration = 0.0;
static double TGModernFlatteningStatsWaitDuration = 0.0;
static NSUInteger TGModernFlatteningStatsScheduled = 0;
static NSUInteger TGModernFlatteningStatsRendered = 0;
static NSUInteger TGModernFlatteningStatsRejected = 0;
#endif

static NSUInteger TGModernFlatteningCacheBudget(void)
{
    static NSUInteger budget = 0;
    if (budget == 0)
    {
        unsigned long long value = [NSProcessInfo processInfo].physicalMemory / 48;
        if (value < 2 * 1024 * 1024)
            value = 2 * 1024 * 1024;
        if (value > 16 * 1024 * 1024)
            value = 16 * 1024 * 1024;
        budget = (NSUInteger)value;
    }
    return budget;
}

static NSUInteger TGModernFlatteningEstimatedBytesForSize(CGSize size)
{
    if (size.width < FLT_EPSILON || size.height < FLT_EPSILON)
        return 0;
    CGFloat scaling = TGScreenScaling();
    NSUInteger bytesPerRow = ((NSUInteger)(size.width * scaling) * 4 + 15) & ~((NSUInteger)15);
    return bytesPerRow * (NSUInteger)(size.height * scaling);
}

static void TGModernFlatteningReleaseInBackground(id object)
{
    if (object == nil)
        return;
    CFTypeRef reference = (__bridge_retained CFTypeRef)object;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        CFRelease(reference);
    });
}

static CGContextRef TGModernFlatteningCreateContext(CGSize size)
{
    CGFloat scaling = TGScreenScaling();
    int width = (int)(size.width * scaling);
    int height = (int)(size.height * scaling);
    if (width <= 0 || height <= 0)
        return NULL;

    size_t bytesPerRow = ((size_t)width * 4 + 15) & ~((size_t)15);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, (size_t)width, (size_t)height, 8, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return NULL;

    CGContextScaleCTM(context, scaling, scaling);
    CGContextTranslateCTM(context, size.width / 2.0f, size.height / 2.0f);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextTranslateCTM(context, -size.width / 2.0f, -size.height / 2.0f);
    return context;
}

static CGImageRef TGModernFlatteningCreateRecordedImage(TGModernDrawingRecording *recording, CGRect rect)
{
    if (recording == nil)
        return NULL;
    CGContextRef context = TGModernFlatteningCreateContext(rect.size);
    if (context == NULL)
        return NULL;

    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);

    UIGraphicsPushContext(context);
    [recording drawInContext:context];
    UIGraphicsPopContext();

    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static void TGModernFlatteningSetWorkerPriority(double priority)
{
    static double currentPriority = -1.0;
    if (currentPriority != priority)
    {
        [NSThread setThreadPriority:priority];
        currentPriority = priority;
    }
}

static void TGModernFlatteningWorkerLock(void)
{
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
}

static void TGModernFlatteningWorkerUnlock(double priority)
{
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);
    TGModernFlatteningSetWorkerPriority(priority);
}

static void TGModernFlatteningPurgeCancelledTasksLocked(void)
{
    for (NSInteger index = (NSInteger)TGModernFlatteningTasks.count - 1; index >= 0; index--)
    {
        TGModernFlatteningRenderTask *task = TGModernFlatteningTasks[(NSUInteger)index];
        if (task->_cancelled)
            [TGModernFlatteningTasks removeObjectAtIndex:(NSUInteger)index];
    }
}

static TGModernFlatteningRenderTask *TGModernFlatteningWaitForTaskLocked(void)
{
    for (;;)
    {
        TGModernFlatteningPurgeCancelledTasksLocked();
        TGModernFlatteningRenderTask *best = nil;
        NSUInteger bestIndex = NSNotFound;
        NSUInteger count = TGModernFlatteningTasks.count;
        for (NSUInteger index = 0; index < count; index++)
        {
            TGModernFlatteningRenderTask *task = TGModernFlatteningTasks[index];
            if (best == nil || task->_priority < best->_priority)
            {
                best = task;
                bestIndex = index;
            }
        }
        if (best != nil)
        {
            [TGModernFlatteningTasks removeObjectAtIndex:bestIndex];
            best->_state = TGModernFlatteningRenderTaskRunning;
            return best;
        }
        pthread_cond_wait(&TGModernFlatteningWorkCondition, &TGModernFlatteningTaskLock);
    }
}

@interface TGModernFlatteningRenderThread : NSObject

+ (void)renderThreadMain:(id)object;

@end

@implementation TGModernFlatteningRenderThread

+ (void)renderThreadMain:(id)__unused object
{
    double currentPriority = TGModernFlatteningPrerenderThreadPriority;
    TGModernFlatteningSetWorkerPriority(currentPriority);

    for (;;)
    {
        @autoreleasepool
        {
            TGModernFlatteningWorkerLock();
            TGModernFlatteningRenderTask *task = TGModernFlatteningWaitForTaskLocked();
            currentPriority = task->_priority < 0.0f ? TGModernFlatteningVisibleThreadPriority : TGModernFlatteningPrerenderThreadPriority;
            TGModernDrawingRecording *recording = task->_recording;
            CGRect rect = task->_rect;
            TGModernFlatteningWorkerUnlock(currentPriority);

            CGImageRef image = TGModernFlatteningCreateRecordedImage(recording, rect);
            task->_recording = nil;
            recording = nil;

            TGModernFlatteningWorkerLock();
            bool deliver = false;
            task->_state = TGModernFlatteningRenderTaskFinished;
            if (task->_cancelled)
            {
                if (image != NULL)
                    CGImageRelease(image);
            }
            else
            {
                task->_image = image;
                deliver = true;
            }
#if defined(ONEGRAM_DIAGNOSTICS)
            TGModernFlatteningStatsRendered++;
#endif
            TGModernFlatteningWorkerUnlock(currentPriority);

            if (deliver)
            {
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    TGModernFlatteningViewModel *model = task->_model;
                    [model _renderTaskCompleted:task];
                });
            }
        }
    }
}

@end

static void TGModernFlatteningEnqueueTask(TGModernFlatteningRenderTask *task)
{
    bool startWorker = false;
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
    if (TGModernFlatteningTasks == nil)
        TGModernFlatteningTasks = [[NSMutableArray alloc] init];
    TGModernFlatteningPurgeCancelledTasksLocked();
    NSUInteger limit = OGRuntimeSingleCoreDevice() ? TGModernFlatteningSingleCorePendingTaskLimit : TGModernFlatteningMultiCorePendingTaskLimit;
    if (TGModernFlatteningTasks.count >= limit && task->_priority >= 0.0f)
    {
        NSUInteger worstIndex = NSNotFound;
        CGFloat worstPriority = task->_priority;
        NSUInteger count = TGModernFlatteningTasks.count;
        for (NSUInteger index = 0; index < count; index++)
        {
            TGModernFlatteningRenderTask *queued = TGModernFlatteningTasks[index];
            if (queued->_priority > worstPriority)
            {
                worstIndex = index;
                worstPriority = queued->_priority;
            }
        }
        if (worstIndex != NSNotFound)
        {
            TGModernFlatteningRenderTask *removed = TGModernFlatteningTasks[worstIndex];
            removed->_cancelled = true;
            [TGModernFlatteningTasks removeObjectAtIndex:worstIndex];
        }
        else
        {
            task->_cancelled = true;
#if defined(ONEGRAM_DIAGNOSTICS)
            TGModernFlatteningStatsRejected++;
#endif
        }
    }
    if (!task->_cancelled)
    {
        task->_state = TGModernFlatteningRenderTaskQueued;
        [TGModernFlatteningTasks addObject:task];
#if defined(ONEGRAM_DIAGNOSTICS)
        TGModernFlatteningStatsScheduled++;
#endif
        if (!TGModernFlatteningWorkerStarted)
        {
            TGModernFlatteningWorkerStarted = true;
            startWorker = true;
        }
        pthread_cond_signal(&TGModernFlatteningWorkCondition);
    }
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);

    if (startWorker)
    {
        NSThread *thread = [[NSThread alloc] initWithTarget:[TGModernFlatteningRenderThread class] selector:@selector(renderThreadMain:) object:nil];
        [thread setName:@"org.telegram.TGModernFlatteningViewModel.render"];
        [thread start];
    }
}

static bool TGModernFlatteningTaskIsAlive(TGModernFlatteningRenderTask *task)
{
    if (task == nil)
        return false;
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
    bool alive = !task->_cancelled;
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);
    return alive;
}

static void TGModernFlatteningSetTaskPriority(TGModernFlatteningRenderTask *task, CGFloat priority)
{
    if (task == nil)
        return;
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
    task->_priority = priority;
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);
}

static void TGModernFlatteningCancelTask(TGModernFlatteningRenderTask *task)
{
    if (task == nil)
        return;
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
    task->_cancelled = true;
    if (task->_state == TGModernFlatteningRenderTaskQueued)
        [TGModernFlatteningTasks removeObjectIdenticalTo:task];
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);
}

static bool TGModernFlatteningCancelQueuedTask(TGModernFlatteningRenderTask *task)
{
    if (task == nil)
        return false;
    bool cancelled = false;
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
    if (task->_state == TGModernFlatteningRenderTaskQueued && !task->_cancelled)
    {
        task->_cancelled = true;
        [TGModernFlatteningTasks removeObjectIdenticalTo:task];
        cancelled = true;
    }
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);
    return cancelled;
}

static CGImageRef TGModernFlatteningClaimFinishedTaskImage(TGModernFlatteningRenderTask *task)
{
    CGImageRef image = NULL;
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
    if (!task->_cancelled && task->_state == TGModernFlatteningRenderTaskFinished)
    {
        image = task->_image;
        task->_image = NULL;
        task->_cancelled = true;
    }
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);
    return image;
}

@interface TGModernFlatteningCacheObserver : NSObject

@end

@implementation TGModernFlatteningCacheObserver

- (void)memoryWarning:(NSNotification *)__unused notification
{
    TGModernFlatteningCacheLockAcquire();
    while (TGModernFlatteningCacheList != NULL && CFArrayGetCount(TGModernFlatteningCacheList) != 0)
    {
        __unsafe_unretained TGModernFlatteningViewModel *model = (__bridge TGModernFlatteningViewModel *)CFArrayGetValueAtIndex(TGModernFlatteningCacheList, 0);
        [model _dropCachedContents];
    }
    TGModernFlatteningCacheLockRelease();
}

@end

static void TGModernFlatteningCacheListEnsure(void)
{
    if (TGModernFlatteningCacheList == NULL)
    {
        TGModernFlatteningCacheList = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
        static TGModernFlatteningCacheObserver *observer = nil;
        observer = [[TGModernFlatteningCacheObserver alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(memoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
}

@implementation TGModernFlatteningViewModel

- (instancetype)init
{
    return [self initWithContext:nil];
}

- (id)initWithContext:(TGModernViewContext *)context
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _tiles = [[NSMutableArray alloc] init];
        self.disableSubmodelAutomaticBinding = 1;
    }
    return self;
}

- (void)dealloc
{
    [self _removeFromCacheList];
    for (TGModernFlatteningTile *tile in _tiles)
        TGModernFlatteningCancelTask(tile->_task);
}

- (Class)viewClass
{
    return [TGModernFlatteningView class];
}

- (bool)_contentUpdatesAllowed
{
    return _context == nil || !_context.contentUpdatesDisabled;
}

- (TGModernDrawingRecording *)_contentRecording
{
    if (![self drawsInContextWithImplementationOfClass:[TGModernViewModel class]])
        return nil;
    TGModernDrawingRecording *recording = [[TGModernDrawingRecording alloc] init];
    if (![self recordSubmodelsDrawing:recording])
        return nil;
    return recording;
}

- (void)_detachTileView:(TGModernFlatteningTile *)tile
{
    if (tile->_view != nil)
    {
        TGModernFlatteningView *view = tile->_view;
        tile->_view = nil;
        [view removeFromSuperview];
        if (_viewStorage != nil)
            [_viewStorage enqueueView:view];
        else
            view.layer.contents = nil;
    }
}

- (void)_detachTileViews
{
    for (TGModernFlatteningTile *tile in _tiles)
        [self _detachTileView:tile];
}

- (void)_setTile:(TGModernFlatteningTile *)tile image:(id)image
{
    if (tile->_image == image)
        return;
    NSUInteger previousBytes = tile->_bytes;
    TGModernFlatteningReleaseInBackground(tile->_image);
    tile->_image = image;
    CGImageRef imageRef = (__bridge CGImageRef)image;
    tile->_bytes = imageRef == NULL ? 0 : CGImageGetBytesPerRow(imageRef) * CGImageGetHeight(imageRef);

    bool wasInCacheList = _inCacheList;
    if (wasInCacheList)
        [self _removeFromCacheList];
    _cachedBytes = _cachedBytes - MIN(_cachedBytes, previousBytes) + tile->_bytes;
    if (wasInCacheList || ([self boundView] == nil && _recording != nil))
        [self _addToCacheList];
}

- (void)_resetTiles
{
    if (_inCacheList)
        [self _removeFromCacheList];
    for (TGModernFlatteningTile *tile in _tiles)
    {
        TGModernFlatteningCancelTask(tile->_task);
        tile->_task = nil;
        [self _detachTileView:tile];
        TGModernFlatteningReleaseInBackground(tile->_image);
        tile->_image = nil;
        tile->_bytes = 0;
    }
    [_tiles removeAllObjects];
    _cachedBytes = 0;
    _tilesValid = false;
    _recording = nil;
    _contentSize = CGSizeZero;
}

- (bool)_synchronizeTiles
{
    CGSize size = self.frame.size;
    if (size.width < FLT_EPSILON || size.height < FLT_EPSILON)
    {
        [self _resetTiles];
        return false;
    }

    if (_tilesValid && !_needsContentUpdate && CGSizeEqualToSize(size, _contentSize))
        return true;
    TGModernDrawingRecording *recording = [self _contentRecording];
    [self _resetTiles];
    _recording = recording;
    _contentSize = size;
    _tilesValid = true;

    if (!_tiledMode)
    {
        TGModernFlatteningTile *tile = [[TGModernFlatteningTile alloc] init];
        tile->_rect = CGRectMake(0.0f, 0.0f, size.width, size.height);
        [_tiles addObject:tile];
    }
    else
    {
        CGFloat originY = 0.0f;
        while (originY < size.height - FLT_EPSILON)
        {
            TGModernFlatteningTile *tile = [[TGModernFlatteningTile alloc] init];
            tile->_rect = CGRectMake(0.0f, originY, size.width, MIN(TGModernFlatteningTileHeight, size.height - originY));
            [_tiles addObject:tile];
            originY += TGModernFlatteningTileHeight;
        }
    }
    return true;
}

- (CGImageRef)_createDirectImageForRect:(CGRect)rect
{
    CGContextRef context = TGModernFlatteningCreateContext(rect.size);
    if (context == NULL)
        return NULL;

    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);

    UIGraphicsPushContext(context);
    [self drawSubmodelsInContext:context];
    UIGraphicsPopContext();

    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

- (void)_scheduleContentsRetry
{
    if (_contentsRetryScheduled || [self boundView] == nil) return;
    _contentsRetryScheduled = true;
    _contentsRetryDelay = MIN(1.0, MAX(0.05, _contentsRetryDelay * 2.0));
    __weak TGModernFlatteningViewModel *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_contentsRetryDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        __strong TGModernFlatteningViewModel *model = weakSelf;
        if (model == nil) return;
        model->_contentsRetryScheduled = false;
        if ([model boundView] == nil) return;
        model->_needsContentUpdate = true;
        [model _updateSubmodelContents];
    });
}

- (void)_scheduleTile:(TGModernFlatteningTile *)tile priority:(CGFloat)priority
{
    if (_recording == nil)
        return;
    if (tile->_task != nil)
    {
        if (TGModernFlatteningTaskIsAlive(tile->_task))
        {
            TGModernFlatteningSetTaskPriority(tile->_task, priority);
            return;
        }
        tile->_task = nil;
    }
    if (tile->_image != nil)
        return;

    TGModernDrawingRecording *recording = [_recording recordingForDrawingRect:tile->_rect];
    if (recording == nil)
    {
        [self _scheduleContentsRetry];
        return;
    }
    TGModernFlatteningRenderTask *task = [[TGModernFlatteningRenderTask alloc] init];
    task->_recording = recording;
    task->_rect = tile->_rect;
    task->_priority = priority;
    task->_model = self;
    tile->_task = task;
    TGModernFlatteningEnqueueTask(task);
}

- (void)_renderTileSynchronously:(TGModernFlatteningTile *)tile
{
#if defined(ONEGRAM_DIAGNOSTICS)
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
#endif
    TGReusableLabelResetMissedEmoji();
    TGModernDrawingRecording *recording = [_recording recordingForDrawingRect:tile->_rect];
    CGImageRef image = recording != nil ? TGModernFlatteningCreateRecordedImage(recording, tile->_rect) : [self _createDirectImageForRect:tile->_rect];
    bool missedEmoji = TGReusableLabelMissedEmoji();
#if defined(ONEGRAM_DIAGNOSTICS)
    TGModernFlatteningStatsSyncRenders++;
    TGModernFlatteningStatsSyncDuration += CFAbsoluteTimeGetCurrent() - startTime;
#endif
    [self _setTile:tile image:(__bridge_transfer id)image];

    if (missedEmoji && _recording != nil)
    {
        TGModernFlatteningRenderTask *task = [[TGModernFlatteningRenderTask alloc] init];
        task->_recording = [_recording recordingForDrawingRect:tile->_rect];
        task->_rect = tile->_rect;
        task->_priority = TGModernFlatteningVisibleTaskPriority;
        task->_model = self;
        tile->_task = task;
        TGModernFlatteningEnqueueTask(task);
    }
}

- (void)_ensureTileImage:(TGModernFlatteningTile *)tile
{
    if (tile->_image != nil)
    {
#if defined(ONEGRAM_DIAGNOSTICS)
        TGModernFlatteningStatsCacheHits++;
#endif
        return;
    }
    if (tile->_task != nil)
    {
        CGImageRef image = TGModernFlatteningClaimFinishedTaskImage(tile->_task);
        if (image != NULL)
        {
            tile->_task = nil;
#if defined(ONEGRAM_DIAGNOSTICS)
            TGModernFlatteningStatsAsyncHits++;
#endif
            [self _setTile:tile image:(__bridge_transfer id)image];
            return;
        }
    }
    if (_recording != nil)
        [self _scheduleTile:tile priority:TGModernFlatteningVisibleTaskPriority];
    else
        [self _renderTileSynchronously:tile];
}

- (TGModernFlatteningView *)_attachTileView:(TGModernFlatteningTile *)tile
{
    UIView *container = [self boundView];
    if (tile->_view == nil)
    {
        TGModernFlatteningView *view = (TGModernFlatteningView *)[_viewStorage dequeueViewWithIdentifier:TGModernFlatteningTileViewIdentifier viewStateIdentifier:nil preferredSuperview:container];
        if (view == nil)
        {
            view = [[TGModernFlatteningView alloc] init];
            [view setViewIdentifier:TGModernFlatteningTileViewIdentifier];
        }
        tile->_view = view;
    }
    TGModernFlatteningView *view = tile->_view;
    if (view.superview != container)
        [container insertSubview:view atIndex:0];
    if (view.hidden)
        view.hidden = false;
    if (!CGRectEqualToRect(view.frame, tile->_rect))
        view.frame = tile->_rect;
    return view;
}

- (void)_layoutTilesForVisibleRect:(CGRect)rect
{
    if (!_tiledMode || !_tilesValid || [self boundView] == nil || ![self _contentUpdatesAllowed])
        return;

    CGRect requiredRect = CGRectInset(rect, 0.0f, -TGModernFlatteningRequiredTileInset);
    CGRect prefetchRect = CGRectInset(rect, 0.0f, -TGModernFlatteningPrefetchTileInset);
    CGFloat rectMinY = CGRectGetMinY(rect);
    CGFloat rectMaxY = CGRectGetMaxY(rect);

    for (TGModernFlatteningTile *tile in _tiles)
    {
        CGRect tileRect = tile->_rect;
        if (CGRectGetMaxY(tileRect) > CGRectGetMinY(requiredRect) && CGRectGetMinY(tileRect) < CGRectGetMaxY(requiredRect))
        {
            [self _ensureTileImage:tile];
            TGModernFlatteningView *view = [self _attachTileView:tile];
            if (view.layer.contents != tile->_image)
                view.layer.contents = tile->_image;
        }
        else if (CGRectGetMaxY(tileRect) > CGRectGetMinY(prefetchRect) && CGRectGetMinY(tileRect) < CGRectGetMaxY(prefetchRect))
        {
            if (tile->_image != nil)
            {
                TGModernFlatteningView *view = [self _attachTileView:tile];
                if (view.layer.contents != tile->_image)
                    view.layer.contents = tile->_image;
            }
            else
            {
                CGFloat distance = MAX(CGRectGetMinY(tileRect) - rectMaxY, rectMinY - CGRectGetMaxY(tileRect));
                [self _scheduleTile:tile priority:MAX(0.0f, distance)];
            }
        }
        else
        {
            [self _detachTileView:tile];
            if (tile->_image != nil)
                [self _setTile:tile image:nil];
            if (tile->_task != nil && TGModernFlatteningCancelQueuedTask(tile->_task))
                tile->_task = nil;
        }
    }
}

- (void)_displayContents
{
    UIView *view = [self boundView];
    if (view == nil)
        return;

    if (![self _synchronizeTiles])
    {
        view.layer.contents = nil;
        return;
    }

    if (!_tiledMode)
    {
        TGModernFlatteningTile *tile = _tiles[0];
        [self _ensureTileImage:tile];
        view.layer.contents = tile->_image;
    }
    else
    {
        view.layer.contents = nil;
        if (_hasLastVisibleRect)
            [self _layoutTilesForVisibleRect:_lastVisibleRect];
    }
}

- (void)_updateSubmodelContents
{
    if ([self boundView] == nil || CGRectIsEmpty(self.frame))
        return;

    if (![self _contentUpdatesAllowed])
    {
        _needsContentUpdate = true;
        return;
    }

    [UIView performWithoutAnimation:^
    {
        [self _displayContents];
    }];
    _needsContentUpdate = false;
}

- (void)_renderTaskCompleted:(TGModernFlatteningRenderTask *)task
{
    TGModernFlatteningTile *targetTile = nil;
    for (TGModernFlatteningTile *tile in _tiles)
    {
        if (tile->_task == task)
        {
            targetTile = tile;
            break;
        }
    }
    if (targetTile == nil)
        return;
    if (_needsContentUpdate)
    {
        targetTile->_task = nil;
        return;
    }

    CGImageRef image = TGModernFlatteningClaimFinishedTaskImage(task);
    targetTile->_task = nil;
    if (image == NULL)
    {
        _needsContentUpdate = true;
        [self _scheduleContentsRetry];
        return;
    }
    _contentsRetryDelay = 0.0;

    [self _setTile:targetTile image:(__bridge_transfer id)image];

    UIView *view = [self boundView];
    if (view == nil || ![self _contentUpdatesAllowed])
        return;

    [UIView performWithoutAnimation:^
    {
        if (!_tiledMode)
            view.layer.contents = targetTile->_image;
        else if (targetTile->_view != nil)
            targetTile->_view.layer.contents = targetTile->_image;
        else if (_hasLastVisibleRect)
            [self _layoutTilesForVisibleRect:_lastVisibleRect];
    }];
}

- (void)_addToCacheList
{
    if (_cachedBytes == 0 || _recording == nil)
        return;
    TGModernFlatteningCacheLockAcquire();
    TGModernFlatteningCacheListEnsure();
    if (_inCacheList)
        [self _removeFromCacheList];
    CFArrayAppendValue(TGModernFlatteningCacheList, (__bridge const void *)self);
    _inCacheList = true;
    TGModernFlatteningCacheBytes += _cachedBytes;

    NSUInteger budget = TGModernFlatteningCacheBudget();
    while (TGModernFlatteningCacheBytes > budget && CFArrayGetCount(TGModernFlatteningCacheList) > 1)
    {
        __unsafe_unretained TGModernFlatteningViewModel *model = (__bridge TGModernFlatteningViewModel *)CFArrayGetValueAtIndex(TGModernFlatteningCacheList, 0);
        [model _dropCachedContents];
    }
    TGModernFlatteningCacheLockRelease();
}

- (void)_removeFromCacheList
{
    TGModernFlatteningCacheLockAcquire();
    if (_inCacheList && TGModernFlatteningCacheList != NULL)
    {
        CFIndex count = CFArrayGetCount(TGModernFlatteningCacheList);
        for (CFIndex index = count - 1; index >= 0; index--)
        {
            if (CFArrayGetValueAtIndex(TGModernFlatteningCacheList, index) == (__bridge const void *)self)
            {
                CFArrayRemoveValueAtIndex(TGModernFlatteningCacheList, index);
                break;
            }
        }
        _inCacheList = false;
        TGModernFlatteningCacheBytes = TGModernFlatteningCacheBytes > _cachedBytes ? TGModernFlatteningCacheBytes - _cachedBytes : 0;
    }
    TGModernFlatteningCacheLockRelease();
}

- (void)_dropCachedContents
{
    if (_inCacheList)
        [self _removeFromCacheList];
    for (TGModernFlatteningTile *tile in _tiles)
    {
        if (tile->_task != nil && TGModernFlatteningCancelQueuedTask(tile->_task))
            tile->_task = nil;
        TGModernFlatteningReleaseInBackground(tile->_image);
        tile->_image = nil;
        tile->_bytes = 0;
    }
    _cachedBytes = 0;
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];

    TGModernFlatteningView *view = (TGModernFlatteningView *)[self boundView];
    view.specialUserInteraction = self.allowSpecialUserInteraction;

    _viewStorage = viewStorage;

    if (_inCacheList)
        [self _removeFromCacheList];

    [self _updateSubmodelContents];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    [self _detachTileViews];

    [super unbindView:viewStorage];

    _hasLastVisibleRect = false;
    _needsContentUpdate = false;

    if (_recording == nil)
    {
        [self _resetTiles];
        return;
    }

    for (TGModernFlatteningTile *tile in _tiles)
    {
        if (tile->_task != nil)
            TGModernFlatteningSetTaskPriority(tile->_task, TGModernFlatteningUnboundTaskPriority);
    }

    [self _addToCacheList];
}

- (void)setTiledMode:(bool)tiledMode
{
    if (tiledMode == _tiledMode)
        return;

    _tiledMode = tiledMode;
    [self _resetTiles];

    if ([self boundView] != nil)
    {
        _needsContentUpdate = true;
        [self _updateSubmodelContents];
    }
}

- (void)setNeedsSubmodelContentsUpdate
{
    _needsContentUpdate = true;
}

- (bool)needsSubmodelContentsUpdate
{
    return _needsContentUpdate;
}

- (void)updateSubmodelContentsIfNeeded
{
    if (_needsContentUpdate)
        [self _updateSubmodelContents];
}

- (void)updateSubmodelContentsForVisibleRect:(CGRect)rect
{
    if (!_tiledMode)
        return;

    _lastVisibleRect = rect;
    _hasLastVisibleRect = true;

    if ([self boundView] == nil || ![self _contentUpdatesAllowed])
        return;

    if (_needsContentUpdate || !_tilesValid)
    {
        [self _updateSubmodelContents];
        return;
    }

    [UIView performWithoutAnimation:^
    {
        [self _layoutTilesForVisibleRect:rect];
    }];
}

- (void)animateWithSnapshot
{
    TGModernFlatteningView *view = (TGModernFlatteningView *)[self boundView];
    if (view != nil && !CGRectIsEmpty(self.frame) && view.layer.contents != nil)
    {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[[UIImage alloc] initWithCGImage:(__bridge CGImageRef)view.layer.contents]];
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.frame = self.frame;
        [view.superview addSubview:imageView];

        imageView.alpha = 1.0f;
        view.alpha = 0.0f;
        [UIView animateWithDuration:0.3 animations:^
        {
            view.alpha = 1.0f;
            imageView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [imageView removeFromSuperview];
        }];
    }
}

+ (NSUInteger)prerenderBudgetBytes
{
    return TGModernFlatteningCacheBudget() / 2;
}

- (NSUInteger)estimatedContentsBytes
{
    CGSize size = self.frame.size;
    if (!_tiledMode)
        return TGModernFlatteningEstimatedBytesForSize(size);
    CGFloat height = MIN(size.height, TGModernFlatteningTileHeight * TGModernFlatteningPrerenderTileCount);
    return TGModernFlatteningEstimatedBytesForSize(CGSizeMake(size.width, height));
}

- (void)prepareContentsAsynchronouslyWithPriority:(CGFloat)priority fromBottomEdge:(bool)fromBottomEdge
{
    if ([self boundView] != nil)
        return;
    bool tilesCurrent = _tilesValid && !_needsContentUpdate && CGSizeEqualToSize(self.frame.size, _contentSize);
    if (!tilesCurrent && ![self _synchronizeTiles])
        return;
    _needsContentUpdate = false;
    if (_recording == nil)
        return;

    NSUInteger count = _tiles.count;
    NSUInteger scheduled = 0;
    for (NSUInteger offset = 0; offset < count; offset++)
    {
        TGModernFlatteningTile *tile = _tiles[fromBottomEdge ? count - 1 - offset : offset];
        if (scheduled < TGModernFlatteningPrerenderTileCount)
        {
            [self _scheduleTile:tile priority:priority + (CGFloat)scheduled * TGModernFlatteningTileHeight];
            scheduled++;
        }
        else if (tile->_task != nil && TGModernFlatteningCancelQueuedTask(tile->_task))
            tile->_task = nil;
    }

    if (_inCacheList)
        [self _addToCacheList];
}

- (void)cancelAsynchronousContentsPreparation
{
    if ([self boundView] != nil)
        return;
    for (TGModernFlatteningTile *tile in _tiles)
    {
        if (tile->_task != nil && TGModernFlatteningCancelQueuedTask(tile->_task))
            tile->_task = nil;
    }
}

#if defined(ONEGRAM_DIAGNOSTICS)
+ (void)logRenderingStatistics
{
    pthread_mutex_lock(&TGModernFlatteningTaskLock);
    NSUInteger pending = TGModernFlatteningTasks.count;
    NSUInteger rendered = TGModernFlatteningStatsRendered;
    NSUInteger rejected = TGModernFlatteningStatsRejected;
    NSUInteger waits = TGModernFlatteningStatsWaits;
    NSUInteger steals = TGModernFlatteningStatsSteals;
    NSUInteger asyncHits = TGModernFlatteningStatsAsyncHits;
    double waitDuration = TGModernFlatteningStatsWaitDuration;
    TGModernFlatteningStatsRendered = 0;
    TGModernFlatteningStatsRejected = 0;
    TGModernFlatteningStatsWaits = 0;
    TGModernFlatteningStatsSteals = 0;
    TGModernFlatteningStatsAsyncHits = 0;
    TGModernFlatteningStatsWaitDuration = 0.0;
    pthread_mutex_unlock(&TGModernFlatteningTaskLock);

    OGPlatformDiagnosticLog(@"RENDERSTAT hit=%lu async=%lu wait=%lu waitMs=%.1f steal=%lu sync=%lu syncMs=%.1f scheduled=%lu rendered=%lu rejected=%lu pending=%lu cacheKB=%lu", (unsigned long)TGModernFlatteningStatsCacheHits, (unsigned long)asyncHits, (unsigned long)waits, waitDuration * 1000.0, (unsigned long)steals, (unsigned long)TGModernFlatteningStatsSyncRenders, TGModernFlatteningStatsSyncDuration * 1000.0, (unsigned long)TGModernFlatteningStatsScheduled, (unsigned long)rendered, (unsigned long)rejected, (unsigned long)pending, (unsigned long)(TGModernFlatteningCacheBytes / 1024));
    TGModernFlatteningStatsCacheHits = 0;
    TGModernFlatteningStatsSyncRenders = 0;
    TGModernFlatteningStatsSyncDuration = 0.0;
    TGModernFlatteningStatsScheduled = 0;
}
#endif

@end
