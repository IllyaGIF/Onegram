#import "TGAnimatedStickerView.h"

#import <QuartzCore/QuartzCore.h>
#import <libkern/OSAtomic.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"
#import "../OnegramPlatform/OGPlatformMedia.h"

#import "TGAnimatedStickerFrames.h"
#import "OGStickerWorker.h"
#import "TGMediaPreviewTask.h"
#import "TGAppDelegate.h"

static const CGFloat TGAnimatedStickerPixelSideQuantum = 32.0f;

@interface TGAnimatedStickerTicker : NSObject

+ (TGAnimatedStickerTicker *)sharedTicker;
- (void)addView:(TGAnimatedStickerView *)view;
- (void)removeView:(TGAnimatedStickerView *)view;
- (void)updateDisplayLink;

@end

@interface TGAnimatedStickerView ()

- (void)tick;
- (NSInteger)effectiveFramesPerSecond;

@end

@interface TGAnimatedStickerTicker ()
{
    CFMutableArrayRef _views;
    CADisplayLink *_displayLink;
    bool _suspended;
}

@end

@implementation TGAnimatedStickerTicker

+ (TGAnimatedStickerTicker *)sharedTicker
{
    static TGAnimatedStickerTicker *ticker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        ticker = [[TGAnimatedStickerTicker alloc] init];
    });
    return ticker;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _views = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(applicationSuspended:) name:UIApplicationWillResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(applicationResumed:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)applicationSuspended:(NSNotification *)__unused notification
{
    _suspended = true;
    [self updateDisplayLink];
}

- (void)applicationResumed:(NSNotification *)__unused notification
{
    _suspended = false;
    [self updateDisplayLink];
}

- (void)addView:(TGAnimatedStickerView *)view
{
    CFIndex count = CFArrayGetCount(_views);
    if (CFArrayContainsValue(_views, CFRangeMake(0, count), (__bridge const void *)view))
        return;
    CFArrayAppendValue(_views, (__bridge const void *)view);
    [self updateDisplayLink];
}

- (void)removeView:(TGAnimatedStickerView *)view
{
    CFIndex count = CFArrayGetCount(_views);
    CFIndex index = CFArrayGetFirstIndexOfValue(_views, CFRangeMake(0, count), (__bridge const void *)view);
    if (index == kCFNotFound)
        return;
    CFArrayRemoveValueAtIndex(_views, index);
    [self updateDisplayLink];
}

- (NSInteger)preferredFrameInterval
{
    NSInteger framesPerSecond = TGAnimatedStickerCurrentTier().framesPerSecond;
    CFIndex count = CFArrayGetCount(_views);
    for (CFIndex index = 0; index < count; index++)
        framesPerSecond = MAX(framesPerSecond, [(__bridge TGAnimatedStickerView *)CFArrayGetValueAtIndex(_views, index) effectiveFramesPerSecond]);
    return MAX((NSInteger)1, 60 / MAX((NSInteger)1, framesPerSecond));
}

- (void)updateDisplayLink
{
    bool active = !_suspended && CFArrayGetCount(_views) != 0;
    if (active && _displayLink == nil)
    {
        TGAnimatedStickerTier tier = TGAnimatedStickerCurrentTier();
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired)];
        _displayLink.frameInterval = [self preferredFrameInterval];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:tier.animatesWhileScrolling ? NSRunLoopCommonModes : NSDefaultRunLoopMode];
    }
    else if (!active && _displayLink != nil)
    {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    else if (active)
    {
        NSInteger frameInterval = [self preferredFrameInterval];
        if (_displayLink.frameInterval != frameInterval)
            _displayLink.frameInterval = frameInterval;
    }
}

- (void)displayLinkFired
{
    NSUInteger limit = TGAnimatedStickerCurrentTier().maximumPlayingCount;
    CFIndex count = CFArrayGetCount(_views);
    if (count == 0)
        return;
    NSMutableArray *views = [[NSMutableArray alloc] initWithCapacity:MIN((NSUInteger)count, limit)];
    for (CFIndex index = count - 1; index >= 0 && views.count < limit; index--)
        [views addObject:(__bridge TGAnimatedStickerView *)CFArrayGetValueAtIndex(_views, index)];
    for (TGAnimatedStickerView *view in views)
        [view tick];
}

@end

@interface TGAnimatedStickerFrameRequest : NSObject
{
    volatile int32_t _cancelled;
}

- (void)cancel;
- (bool)isCancelled;

@end

@implementation TGAnimatedStickerFrameRequest

- (void)cancel
{
    OSAtomicCompareAndSwap32Barrier(0, 1, &_cancelled);
}

- (bool)isCancelled
{
    return OSAtomicAdd32Barrier(0, &_cancelled) != 0;
}

@end

@interface TGAnimatedStickerPendingDownload : NSObject

@property (nonatomic, strong) TGMediaPreviewTask *task;
@property (nonatomic, strong) NSMutableArray *completions;

@end

@implementation TGAnimatedStickerPendingDownload

@end

@interface TGAnimatedStickerDownloads : NSObject

+ (void)ensureFileForDocument:(TGDocumentMediaAttachment *)document path:(NSString *)path completion:(void (^)(bool success))completion;

@end

@implementation TGAnimatedStickerDownloads

+ (NSMutableDictionary *)pendingDownloads
{
    static NSMutableDictionary *pendingDownloads = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        pendingDownloads = [[NSMutableDictionary alloc] init];
    });
    return pendingDownloads;
}

+ (void)ensureFileForDocument:(TGDocumentMediaAttachment *)document path:(NSString *)path completion:(void (^)(bool success))completion
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
    {
        completion(true);
        return;
    }
    NSMutableDictionary *pendingDownloads = [self pendingDownloads];
    TGAnimatedStickerPendingDownload *download = pendingDownloads[path];
    if (download != nil)
    {
        [download.completions addObject:[completion copy]];
        return;
    }
    download = [[TGAnimatedStickerPendingDownload alloc] init];
    download.completions = [[NSMutableArray alloc] initWithObjects:[completion copy], nil];
    download.task = [[TGMediaPreviewTask alloc] init];
    pendingDownloads[path] = download;
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:true attributes:nil error:nil];
    [download.task executeWithTargetFilePath:path document:document progress:nil completion:^(bool success)
    {
        TGDispatchOnMainThread(^
        {
            TGAnimatedStickerPendingDownload *finished = [self pendingDownloads][path];
            [[self pendingDownloads] removeObjectForKey:path];
            bool available = success && [[NSFileManager defaultManager] fileExistsAtPath:path];
            for (void (^block)(bool) in finished.completions)
                block(available);
        });
    } workerTask:nil];
}

@end

@interface TGAnimatedStickerView ()
{
    TGImageView *_placeholderView;
    CALayer *_frameLayer;
    TGDocumentMediaAttachment *_document;
    NSString *_placeholderUri;
    NSString *_filePath;
    NSString *_key;
    TGAnimatedStickerFrames *_frames;
    CGSize _framesPixelSize;
    NSUInteger _frameIndex;
    NSUInteger _frameCount;
    NSInteger _framesPerSecond;
    CFTimeInterval _playbackStartTime;
    bool _bufferingSatisfied;
    bool _restartPending;
    bool _requestInFlight;
    TGAnimatedStickerFrameRequest *_currentRequest;
    bool _waitingForFile;
    bool _registered;
    NSUInteger _generation;
    bool _framesReady;
    TGAnimatedStickerFrameRequest *_prepareRequest;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

@end

@implementation TGAnimatedStickerView

+ (NSString *)animationKeyForDocument:(TGDocumentMediaAttachment *)document
{
    if (document.documentId != 0)
        return [[NSString alloc] initWithFormat:@"d%" PRIx64, document.documentId];
    return [[NSString alloc] initWithFormat:@"l%" PRIx64, document.localDocumentId];
}

+ (NSString *)viewStateIdentifierForAnimationKey:(NSString *)key
{
    return key.length == 0 ? nil : [[NSString alloc] initWithFormat:@"TGAnimatedStickerView/%@", key];
}

+ (bool)isAnimatedStickerDocument:(TGDocumentMediaAttachment *)document
{
    NSString *mimeType = [document.mimeType lowercaseString];
    NSString *extension = [[document.fileName pathExtension] lowercaseString];
    return [mimeType isEqualToString:@"application/x-tgsticker"] || [extension isEqualToString:@"tgs"] || [self isWebMStickerDocument:document];
}

+ (bool)isWebMStickerDocument:(TGDocumentMediaAttachment *)document
{
    return [[document.mimeType lowercaseString] isEqualToString:@"video/webm"] || [[[document.fileName pathExtension] lowercaseString] isEqualToString:@"webm"];
}

+ (NSString *)filePathForDocument:(TGDocumentMediaAttachment *)document
{
    if ([document.documentUri hasPrefix:@"file://"])
        return [[NSURL URLWithString:document.documentUri] path];
    static NSString *filesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        filesDirectory = [[TGAppDelegate documentsPath] stringByAppendingPathComponent:@"files"];
    });
    NSString *directoryName = nil;
    if (document.documentId != 0)
        directoryName = [[NSString alloc] initWithFormat:@"%" PRIx64 "", document.documentId];
    else if (document.localDocumentId != 0)
        directoryName = [[NSString alloc] initWithFormat:@"local%" PRIx64 "", document.localDocumentId];
    if (directoryName == nil)
        return nil;
    return [[filesDirectory stringByAppendingPathComponent:directoryName] stringByAppendingPathComponent:[document safeFileName]];
}

+ (NSString *)placeholderUriForDocument:(TGDocumentMediaAttachment *)document size:(CGSize)size
{
    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
    if (document.documentId != 0)
    {
        [uri appendFormat:@"documentId=%" PRId64 "", document.documentId];
        TGMediaOriginInfo *originInfo = document.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:document];
        if (originInfo != nil)
            [uri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
    }
    else
        [uri appendFormat:@"localDocumentId=%" PRId64 "", document.localDocumentId];
    [uri appendFormat:@"&accessHash=%" PRId64 "", document.accessHash];
    [uri appendFormat:@"&datacenterId=%d", (int)document.datacenterId];
    NSString *legacyThumbnailUri = [document.thumbnailInfo imageUrlForLargestSize:NULL];
    if (legacyThumbnailUri.length != 0)
        [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailUri]];
    [uri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:[document safeFileName]]];
    [uri appendFormat:@"&size=%d", (int)document.size];
    if (document.mimeType.length != 0)
        [uri appendFormat:@"&mimeType=%@", [TGStringUtils stringByEscapingForURL:document.mimeType]];
    [uri appendFormat:@"&width=%d&height=%d&highQuality=1", (int)size.width, (int)size.height];
    if (OGPlatformMediaDownloadsRequireUserAction())
        [uri appendString:@"&cacheOnly=1"];
    return uri;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        self.backgroundColor = [UIColor clearColor];
        _playing = true;
        _loops = true;

        _placeholderView = [[TGImageView alloc] initWithFrame:self.bounds];
        _placeholderView.contentMode = UIViewContentModeScaleAspectFit;
        _placeholderView.expectExtendedEdges = true;
        [self addSubview:_placeholderView];

        _frameLayer = [[CALayer alloc] init];
        _frameLayer.contentsGravity = kCAGravityResizeAspect;
        _frameLayer.hidden = true;
        _frameLayer.actions = @{ @"contents": [NSNull null], @"hidden": [NSNull null], @"bounds": [NSNull null], @"position": [NSNull null] };
        [self.layer addSublayer:_frameLayer];
    }
    return self;
}

- (void)dealloc
{
    if (_registered)
        [[TGAnimatedStickerTicker sharedTicker] removeView:self];
}

- (void)willBecomeRecycled
{
    [self suspend];
}

- (void)cancelFramePreparation
{
    [_prepareRequest cancel];
    _prepareRequest = nil;
    _framesReady = false;
}

- (void)prepareFramesIfNeeded
{
    if (!_playing || _frames == nil || _framesReady || _prepareRequest != nil || self.window == nil)
        return;
    TGAnimatedStickerFrames *frames = _frames;
    if ([frames isComplete])
    {
        _framesReady = true;
        [self updateRegistration];
        return;
    }
    TGAnimatedStickerFrameRequest *request = [[TGAnimatedStickerFrameRequest alloc] init];
    _prepareRequest = request;
    NSUInteger generation = _generation;
    __weak TGAnimatedStickerView *weakSelf = self;
    [[OGStickerWorker preparationWorker] perform:^
    {
        if ([request isCancelled])
            return;
        bool complete = [frames renderRemainingFramesCancelled:^bool
        {
            return [request isCancelled];
        }];
        dispatch_async(dispatch_get_main_queue(), ^
        {
            __strong TGAnimatedStickerView *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_generation != generation || strongSelf->_prepareRequest != request)
                return;
            strongSelf->_prepareRequest = nil;
            strongSelf->_framesReady = complete;
            [strongSelf updateRegistration];
        });
    }];
}

- (void)suspend
{
    _playbackStartTime = 0.0;
    [self cancelFramePreparation];
    [_currentRequest cancel];
    _currentRequest = nil;
    _generation++;
    _frames = nil;
    _framesPixelSize = CGSizeZero;
    _requestInFlight = false;
    _waitingForFile = false;
    [self updateRegistration];
}

- (void)reset
{
    [self cancelFramePreparation];
    [_currentRequest cancel];
    _currentRequest = nil;
    _generation++;
    _document = nil;
    _placeholderUri = nil;
    _filePath = nil;
    _key = nil;
    self.viewStateIdentifier = nil;
    _frames = nil;
    _framesPixelSize = CGSizeZero;
    _frameIndex = 0;
    _frameCount = 0;
    _framesPerSecond = 0;
    _playbackStartTime = 0.0;
    _requestInFlight = false;
    _waitingForFile = false;
    _contentReady = false;
    _frameLayer.contents = nil;
    _frameLayer.hidden = true;
    _placeholderView.hidden = false;
    [_placeholderView reset];
    [self updateRegistration];
}

- (void)setDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri
{
    if (document != nil)
        OGDiagnosticsTimingBeginOnce("video_sticker_first_frame");
    if (_document != nil && document != nil && _document.documentId == document.documentId && _document.localDocumentId == document.localDocumentId)
    {
        [self setNeedsLayout];
        [self loadIfNeeded];
        return;
    }
    [self reset];
    _document = document;
    _placeholderUri = placeholderUri;
    _filePath = [TGAnimatedStickerView filePathForDocument:document];
    _key = [TGAnimatedStickerView animationKeyForDocument:document];
    self.viewStateIdentifier = [TGAnimatedStickerView viewStateIdentifierForAnimationKey:_key];
    if (placeholderUri.length != 0 && ![[NSFileManager defaultManager] fileExistsAtPath:_filePath])
        [_placeholderView loadUri:placeholderUri withOptions:@{}];
    [self setNeedsLayout];
    [self loadIfNeeded];
}

- (void)setAnimationFilePath:(NSString *)filePath key:(NSString *)key placeholderImage:(UIImage *)placeholderImage
{
    if (filePath.length != 0)
        OGDiagnosticsTimingBeginOnce("video_sticker_first_frame");
    if ([_key isEqualToString:key])
    {
        [self setNeedsLayout];
        [self loadIfNeeded];
        return;
    }
    [self reset];
    _filePath = filePath;
    _key = key;
    self.viewStateIdentifier = [TGAnimatedStickerView viewStateIdentifierForAnimationKey:key];
    _placeholderView.image = placeholderImage;
    [self setNeedsLayout];
    [self loadIfNeeded];
}

- (void)restart
{
    _playing = true;
    _playbackStartTime = 0.0;
    _bufferingSatisfied = false;
    _restartPending = true;
    [self prepareFramesIfNeeded];
    [self updateRegistration];
}

- (void)setPlaying:(bool)playing
{
    if (_playing != playing)
    {
        _playbackStartTime = 0.0;
        _bufferingSatisfied = false;
    }
    if (!playing)
        _restartPending = false;
    _playing = playing;
    if (playing)
        [self prepareFramesIfNeeded];
    else if (_prepareRequest != nil)
        [self cancelFramePreparation];
    [self updateRegistration];
}

- (CGSize)targetPixelSize
{
    CGSize size = self.bounds.size;
    if (size.width < 1.0f || size.height < 1.0f)
        return CGSizeZero;
    CGFloat pointSide = MAX(size.width, size.height);
    CGFloat pixelSide = CGCeil(pointSide * TGScreenScaling() / TGAnimatedStickerPixelSideQuantum) * TGAnimatedStickerPixelSideQuantum;
    pixelSide = MIN(pixelSide, (CGFloat)TGAnimatedStickerCurrentTier().maximumPixelSide);
    CGFloat factor = pixelSide / pointSide;
    return CGSizeMake(MAX(1.0f, CGFloor(size.width * factor)), MAX(1.0f, CGFloor(size.height * factor)));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _placeholderView.frame = self.bounds;
    _frameLayer.frame = self.bounds;
    CGSize pixelSize = [self targetPixelSize];
    if (_frames != nil && !CGSizeEqualToSize(pixelSize, _framesPixelSize))
    {
        [self cancelFramePreparation];
        [_currentRequest cancel];
        _currentRequest = nil;
        _frames = nil;
        _requestInFlight = false;
        _generation++;
    }
    [self loadIfNeeded];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window == nil)
        [self suspend];
    [self loadIfNeeded];
    [self updateRegistration];
}

- (void)setUsesSourceFrameRate:(bool)usesSourceFrameRate
{
    if (_usesSourceFrameRate == usesSourceFrameRate)
        return;
    _usesSourceFrameRate = usesSourceFrameRate;
    if (_frames != nil)
    {
        [self cancelFramePreparation];
        [_currentRequest cancel];
        _currentRequest = nil;
        _frames = nil;
        _requestInFlight = false;
        _playbackStartTime = 0.0;
        _generation++;
        [self loadIfNeeded];
    }
}

- (NSInteger)effectiveFramesPerSecond
{
    return _framesPerSecond > 0 ? _framesPerSecond : TGAnimatedStickerCurrentTier().framesPerSecond;
}

- (void)updateRegistration
{
    bool shouldRegister = self.window != nil && _playing && _frames != nil && _contentReady;
    if (shouldRegister == _registered)
        return;
    _registered = shouldRegister;
    if (shouldRegister)
        [[TGAnimatedStickerTicker sharedTicker] addView:self];
    else
        [[TGAnimatedStickerTicker sharedTicker] removeView:self];
}

- (void)loadIfNeeded
{
    if (self.window == nil || _filePath == nil || _frames != nil || _waitingForFile)
        return;
    CGSize pixelSize = [self targetPixelSize];
    if (CGSizeEqualToSize(pixelSize, CGSizeZero))
        return;
    if (![[NSFileManager defaultManager] fileExistsAtPath:_filePath])
    {
        if (_document == nil || OGPlatformMediaDownloadsRequireUserAction())
            return;
        _waitingForFile = true;
        NSUInteger generation = _generation;
        __weak TGAnimatedStickerView *weakSelf = self;
        [TGAnimatedStickerDownloads ensureFileForDocument:_document path:_filePath completion:^(bool success)
        {
            __strong TGAnimatedStickerView *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_generation != generation)
                return;
            strongSelf->_waitingForFile = false;
            if (success)
                [strongSelf loadIfNeeded];
        }];
        return;
    }
    _framesPixelSize = pixelSize;
    _frames = [TGAnimatedStickerFrames framesWithKey:_key filePath:_filePath pixelSize:pixelSize sourceFrameRate:_usesSourceFrameRate];
    _playbackStartTime = 0.0;
    _bufferingSatisfied = false;
    _frameIndex = _contentReady && _frameCount != 0 ? _frameIndex % _frameCount : 0;
    bool resting = !_playing || _restartPending;
    [self requestFrame:resting && _restsOnLastFrame && !_contentReady ? NSNotFound : _frameIndex];
    [self prepareFramesIfNeeded];
    [self updateRegistration];
}

- (void)requestFrame:(NSUInteger)index
{
    TGAnimatedStickerFrames *frames = _frames;
    if (frames == nil || _requestInFlight)
        return;
    _requestInFlight = true;
    NSUInteger generation = _generation;
    bool poster = !_playing && index == 0;
    TGAnimatedStickerFrameRequest *request = [[TGAnimatedStickerFrameRequest alloc] init];
    _currentRequest = request;
    __weak TGAnimatedStickerView *weakSelf = self;
    dispatch_async(TGAnimatedStickerRenderQueue(), ^
    {
        if ([request isCancelled])
            return;
        NSUInteger frameCount = [frames frameCount];
        NSUInteger frameIndex = index == NSNotFound ? (frameCount != 0 ? frameCount - 1 : 0) : index;
        CGImageRef image = [frames copyStoredImageForFrame:frameIndex];
        if (image == NULL)
        {
            image = poster ? [frames copyPosterImage] : [frames copyImageForFrame:frameIndex cancelled:^bool
            {
                return [request isCancelled];
            }];
        }
        NSInteger framesPerSecond = [frames framesPerSecond];
        id imageObject = (__bridge_transfer id)image;
        dispatch_async(dispatch_get_main_queue(), ^
        {
            __strong TGAnimatedStickerView *strongSelf = weakSelf;
            if (strongSelf == nil || strongSelf->_generation != generation)
                return;
            strongSelf->_requestInFlight = false;
            if (strongSelf->_currentRequest == request)
                strongSelf->_currentRequest = nil;
            if (imageObject == nil)
            {
                if (strongSelf->_placeholderUri.length != 0)
                    [strongSelf->_placeholderView loadUri:strongSelf->_placeholderUri withOptions:@{}];
                return;
            }
            [strongSelf displayFrame:imageObject index:frameIndex frameCount:frameCount framesPerSecond:framesPerSecond];
        });
    });
}

- (void)displayFrame:(id)image index:(NSUInteger)index frameCount:(NSUInteger)frameCount framesPerSecond:(NSInteger)framesPerSecond
{
    _frameLayer.contents = image;
    if (framesPerSecond > 0 && framesPerSecond != _framesPerSecond)
    {
        _framesPerSecond = framesPerSecond;
        _playbackStartTime = 0.0;
        if (_registered)
            [[TGAnimatedStickerTicker sharedTicker] updateDisplayLink];
    }
    OGDiagnosticsTimingAfterFrame("video_sticker_first_frame", self, false, true);
    _frameIndex = index;
    _frameCount = frameCount;
    if (!_contentReady)
    {
        _contentReady = true;
        _frameLayer.hidden = false;
        _placeholderView.hidden = true;
        if (_readyBlock != nil)
            _readyBlock();
    }
    bool finished = _playing && !_restartPending && !_loops && frameCount != 0 && index + 1 >= frameCount;
    if (finished)
        _playing = false;
    [self updateRegistration];
    if (finished && _playbackFinished != nil)
        _playbackFinished();
}

- (void)tick
{
    TGAnimatedStickerFrames *frames = _frames;
    if (frames == nil || _requestInFlight || _frameCount <= 1)
        return;
    NSUInteger availableFrameCount = [frames isComplete] ? _frameCount : MIN(_frameCount, [frames availableFrameCount]);
    if (availableFrameCount == 0)
        return;
    NSInteger framesPerSecond = [self effectiveFramesPerSecond];
    CFTimeInterval now = CACurrentMediaTime();
    NSUInteger startIndex = _restartPending ? 0 : _frameIndex;
    if (![frames isComplete] && !_bufferingSatisfied)
    {
        double preparationRate = [frames preparationFramesPerSecond];
        double remainingFrames = _frameCount - startIndex;
        double requiredFrames = preparationRate >= framesPerSecond ? 0.0 : remainingFrames * (1.0 - preparationRate / (double)framesPerSecond) + (double)framesPerSecond * 0.25;
        if (preparationRate <= 0.0 || (double)availableFrameCount < (double)startIndex + requiredFrames)
        {
            _playbackStartTime = 0.0;
            return;
        }
        _bufferingSatisfied = true;
    }
    if (_restartPending)
    {
        _restartPending = false;
        _playbackStartTime = now;
        [self requestFrame:0];
        return;
    }
    if (_playbackStartTime <= 0.0)
        _playbackStartTime = now - (CFTimeInterval)_frameIndex / (CFTimeInterval)framesPerSecond;
    NSUInteger elapsedFrames = (NSUInteger)MAX(0.0, floor((now - _playbackStartTime) * (CFTimeInterval)framesPerSecond));
    NSUInteger targetIndex = _loops ? elapsedFrames % _frameCount : MIN(elapsedFrames, _frameCount - 1);
    if (targetIndex >= availableFrameCount)
    {
        targetIndex = availableFrameCount - 1;
        _playbackStartTime = now - (CFTimeInterval)targetIndex / (CFTimeInterval)framesPerSecond;
    }
    if (targetIndex == _frameIndex)
        return;
    [self requestFrame:targetIndex];
}

@end
