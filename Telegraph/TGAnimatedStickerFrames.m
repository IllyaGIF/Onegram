#import "TGAnimatedStickerFrames.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../legacy/TelegraphKit/TGCommon.h"
#import "../thirdparty/lz4/lz4.h"

#import "TGLottieCore.h"
#import "OGStickerFrameSource.h"
#import "OGWebMStickerSource.h"
#import "../OnegramRuntime/OGPluginAvailability.h"
#import "../OnegramRuntime/OGDeviceTier.h"
#import "../OnegramRuntime/OGCPUProfiler.h"
#if OG_PLUGINS_AVAILABLE
#import "../OnegramPlugins/OGSceneAnimatedSource.h"
#endif

#import <sys/sysctl.h>
#import <libkern/OSAtomic.h>
#import <pthread.h>
#import <mach/mach.h>

#import "../OnegramPlatform/OGPlatformDispatch.h"

static const uint32_t TGAnimatedStickerCacheMagic = 0x53414754;
static const uint32_t TGAnimatedStickerCacheVersion = 1;
static const NSUInteger TGAnimatedStickerMaximumFrameCount = 600;

typedef struct
{
    uint32_t magic;
    uint32_t version;
    uint32_t width;
    uint32_t height;
    uint32_t frameCount;
    uint32_t framesPerSecond;
} TGAnimatedStickerCacheHeader;

typedef enum
{
    TGAnimatedStickerHardwareClassARM11 = 0,
    TGAnimatedStickerHardwareClassSingleCore = 1,
    TGAnimatedStickerHardwareClassDualCore = 2,
    TGAnimatedStickerHardwareClassModern = 3
} TGAnimatedStickerHardwareClass;

static NSString *TGAnimatedStickerMachineIdentifier(void)
{
    size_t size = 0;
    if (sysctlbyname("hw.machine", NULL, &size, NULL, 0) != 0 || size == 0 || size > 256)
        return nil;
    char buffer[256];
    if (sysctlbyname("hw.machine", buffer, &size, NULL, 0) != 0)
        return nil;
    buffer[size < sizeof(buffer) ? size : sizeof(buffer) - 1] = 0;
    return [[NSString alloc] initWithUTF8String:buffer];
}

static bool TGAnimatedStickerMachineFamily(NSString *machine, NSString *family, int *major, int *minor)
{
    if (![machine hasPrefix:family])
        return false;
    NSArray *components = [[machine substringFromIndex:family.length] componentsSeparatedByString:@","];
    if (components.count != 2)
        return false;
    *major = [components[0] intValue];
    *minor = [components[1] intValue];
    return *major > 0;
}

static TGAnimatedStickerHardwareClass TGAnimatedStickerHardwareClassForMachine(NSString *machine, bool *known)
{
    int major = 0;
    int minor = 0;
    *known = true;
    if (TGAnimatedStickerMachineFamily(machine, @"iPhone", &major, &minor))
    {
        if (major == 1)
            return TGAnimatedStickerHardwareClassARM11;
        if (major <= 3)
            return TGAnimatedStickerHardwareClassSingleCore;
        if (major == 4)
            return TGAnimatedStickerHardwareClassDualCore;
        return TGAnimatedStickerHardwareClassModern;
    }
    if (TGAnimatedStickerMachineFamily(machine, @"iPod", &major, &minor))
    {
        if (major <= 2)
            return TGAnimatedStickerHardwareClassARM11;
        if (major <= 4)
            return TGAnimatedStickerHardwareClassSingleCore;
        if (major == 5)
            return TGAnimatedStickerHardwareClassDualCore;
        return TGAnimatedStickerHardwareClassModern;
    }
    if (TGAnimatedStickerMachineFamily(machine, @"iPad", &major, &minor))
    {
        if (major == 1)
            return TGAnimatedStickerHardwareClassSingleCore;
        if (major == 2 || (major == 3 && minor <= 3))
            return TGAnimatedStickerHardwareClassDualCore;
        return TGAnimatedStickerHardwareClassModern;
    }
    if (TGAnimatedStickerMachineFamily(machine, @"AppleTV", &major, &minor))
        return major <= 2 ? TGAnimatedStickerHardwareClassSingleCore : TGAnimatedStickerHardwareClassDualCore;
    *known = false;
    return TGAnimatedStickerHardwareClassSingleCore;
}

static TGAnimatedStickerHardwareClass TGAnimatedStickerCurrentHardwareClass(void)
{
    bool known = false;
    TGAnimatedStickerHardwareClass hardwareClass = TGAnimatedStickerHardwareClassForMachine(TGAnimatedStickerMachineIdentifier(), &known);
    OGDeviceTier deviceTier = OGDeviceTierCurrent();
    if (known && hardwareClass != TGAnimatedStickerHardwareClassModern)
        return hardwareClass;
    if (deviceTier != OGDeviceTierLow)
        return TGAnimatedStickerHardwareClassModern;
    unsigned long long memory = OGDevicePhysicalMemory();
    int cores = cpuCoreCount();
    if (cores >= 2)
        return TGAnimatedStickerHardwareClassDualCore;
    if (memory >= 200ULL * 1024ULL * 1024ULL)
        return TGAnimatedStickerHardwareClassSingleCore;
    return TGAnimatedStickerHardwareClassARM11;
}

@class TGAnimatedStickerFrames;

@interface TGAnimatedStickerFrames (OGMemoryInspection)
- (uint64_t)memoryBytes;
- (void)trimForMemoryPressure:(BOOL)critical;
@end

@interface TGAnimatedStickerMemoryObserver : NSObject
- (void)memoryWarning:(NSNotification *)notification;
- (void)applicationBackground:(NSNotification *)notification;
@end

static id TGAnimatedStickerTrackedFrames(void)
{
    static id frames;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ frames = TGWeakObjectHashTable(); });
    return frames;
}

static NSArray *TGAnimatedStickerLiveFrames(void)
{
    id frames = TGAnimatedStickerTrackedFrames();
    @synchronized (frames)
    {
        return [frames allObjects];
    }
}

static volatile uint32_t TGAnimatedStickerDecodedFrames = 0;

TGAnimatedStickerTier TGAnimatedStickerCurrentTier(void)
{
    static TGAnimatedStickerTier tier;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        switch (TGAnimatedStickerCurrentHardwareClass())
        {
            case TGAnimatedStickerHardwareClassARM11:
                tier.framesPerSecond = 15;
                tier.maximumPixelSide = 160.0f;
                tier.maximumPlayingCount = 1;
                tier.memoryCacheBytes = 3 * 1024 * 1024;
                tier.animatesWhileScrolling = false;
                break;
            case TGAnimatedStickerHardwareClassSingleCore:
                tier.framesPerSecond = 20;
                tier.maximumPixelSide = 240.0f;
                tier.maximumPlayingCount = 2;
                tier.memoryCacheBytes = 8 * 1024 * 1024;
                tier.animatesWhileScrolling = false;
                break;
            case TGAnimatedStickerHardwareClassDualCore:
                tier.framesPerSecond = 20;
                tier.maximumPixelSide = 240.0f;
                tier.maximumPlayingCount = 4;
                tier.memoryCacheBytes = 12 * 1024 * 1024;
                tier.animatesWhileScrolling = false;
                break;
            default:
                tier.framesPerSecond = 30;
                tier.maximumPixelSide = 400.0f;
                tier.maximumPlayingCount = 8;
                tier.memoryCacheBytes = 32 * 1024 * 1024;
                tier.animatesWhileScrolling = true;
                break;
        }
    });
    return tier;
}

dispatch_queue_t TGAnimatedStickerRenderQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("org.onegram.animated-stickers", NULL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    });
    return queue;
}

static NSCache *TGAnimatedStickerFramesCache(void)
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.totalCostLimit = TGAnimatedStickerCurrentTier().memoryCacheBytes;
        OGCPUProfilerRegisterMemoryCounter(@"stickers", ^uint64_t
        {
            uint64_t cost = 0;
            for (TGAnimatedStickerFrames *frames in TGAnimatedStickerLiveFrames())
                cost += [frames memoryBytes];
            return cost;
        });
        OGCPUProfilerRegisterMemoryCounter(@"count.sticker_decodes", ^uint64_t
        {
            return (uint64_t)__sync_fetch_and_add(&TGAnimatedStickerDecodedFrames, 0);
        });
        static TGAnimatedStickerMemoryObserver *observer;
        observer = [[TGAnimatedStickerMemoryObserver alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(memoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(applicationBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification object:nil];
    });
    return cache;
}

static NSString *TGAnimatedStickerCacheDirectory(void)
{
    static NSString *directory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true);
        NSString *caches = paths.count != 0 ? paths[0] : NSTemporaryDirectory();
        directory = [caches stringByAppendingPathComponent:@"animated-stickers"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:true attributes:nil error:nil];
    });
    return directory;
}

typedef struct
{
    CGContextRef context;
    int groupDepth;
    bool transparencyLayers[32];
} TGAnimatedStickerDrawingContext;

static void TGAnimatedStickerAddPath(CGContextRef context, const TGLottiePath *path)
{
    const float *points = path->points;
    for (int index = 0; index < path->commandCount; index++)
    {
        switch (path->commands[index])
        {
            case TGLottiePathMove:
                CGContextMoveToPoint(context, points[0], points[1]);
                points += 2;
                break;
            case TGLottiePathLine:
                CGContextAddLineToPoint(context, points[0], points[1]);
                points += 2;
                break;
            case TGLottiePathCubic:
                CGContextAddCurveToPoint(context, points[0], points[1], points[2], points[3], points[4], points[5]);
                points += 6;
                break;
            case TGLottiePathClose:
                CGContextClosePath(context);
                break;
            default:
                break;
        }
    }
}

static CGAffineTransform TGAnimatedStickerAffine(const TGLottieAffine *matrix)
{
    return CGAffineTransformMake(matrix->a, matrix->b, matrix->c, matrix->d, matrix->tx, matrix->ty);
}

static void TGAnimatedStickerApplyStrokeStyle(CGContextRef context, const TGLottieStrokeStyle *style)
{
    CGContextSetLineWidth(context, style->width);
    CGContextSetLineCap(context, style->lineCap == 1 ? kCGLineCapButt : (style->lineCap == 3 ? kCGLineCapSquare : kCGLineCapRound));
    CGContextSetLineJoin(context, style->lineJoin == 1 ? kCGLineJoinMiter : (style->lineJoin == 3 ? kCGLineJoinBevel : kCGLineJoinRound));
    CGContextSetMiterLimit(context, style->miterLimit);
    if (style->dashCount > 0)
    {
        CGFloat dashes[16];
        int count = style->dashCount < 16 ? style->dashCount : 16;
        for (int index = 0; index < count; index++)
            dashes[index] = style->dashes[index];
        CGContextSetLineDash(context, style->dashPhase, dashes, (size_t)count);
    }
}

static void TGAnimatedStickerDrawGradient(CGContextRef context, const TGLottieGradient *gradient)
{
    CGFloat components[32 * 4];
    CGFloat locations[32];
    int count = gradient->stopCount < 32 ? gradient->stopCount : 32;
    for (int index = 0; index < count; index++)
    {
        components[index * 4] = gradient->stops[index].r;
        components[index * 4 + 1] = gradient->stops[index].g;
        components[index * 4 + 2] = gradient->stops[index].b;
        components[index * 4 + 3] = gradient->stops[index].a;
        locations[index] = gradient->stops[index].offset;
    }
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef cgGradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, (size_t)count);
    CGColorSpaceRelease(colorSpace);
    if (cgGradient == NULL)
        return;
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    if (gradient->radial)
    {
        CGFloat dx = gradient->endX - gradient->startX;
        CGFloat dy = gradient->endY - gradient->startY;
        CGFloat radius = (CGFloat)sqrt(dx * dx + dy * dy);
        CGContextDrawRadialGradient(context, cgGradient, CGPointMake(gradient->focalX, gradient->focalY), 0.0f, CGPointMake(gradient->startX, gradient->startY), radius, options);
    }
    else
        CGContextDrawLinearGradient(context, cgGradient, CGPointMake(gradient->startX, gradient->startY), CGPointMake(gradient->endX, gradient->endY), options);
    CGGradientRelease(cgGradient);
}

static void TGAnimatedStickerFillColor(void *context, const TGLottiePath *path, int evenOdd, float r, float g, float b, float a)
{
    CGContextRef cg = ((TGAnimatedStickerDrawingContext *)context)->context;
    CGContextSetRGBFillColor(cg, r, g, b, a);
    CGContextBeginPath(cg);
    TGAnimatedStickerAddPath(cg, path);
    if (evenOdd)
        CGContextEOFillPath(cg);
    else
        CGContextFillPath(cg);
}

static void TGAnimatedStickerFillGradient(void *context, const TGLottiePath *path, int evenOdd, const TGLottieGradient *gradient, const TGLottieAffine *gradientTransform, float alpha)
{
    CGContextRef cg = ((TGAnimatedStickerDrawingContext *)context)->context;
    CGContextSaveGState(cg);
    CGContextBeginPath(cg);
    TGAnimatedStickerAddPath(cg, path);
    if (evenOdd)
        CGContextEOClip(cg);
    else
        CGContextClip(cg);
    CGContextConcatCTM(cg, TGAnimatedStickerAffine(gradientTransform));
    CGContextSetAlpha(cg, alpha);
    TGAnimatedStickerDrawGradient(cg, gradient);
    CGContextRestoreGState(cg);
}

static void TGAnimatedStickerStrokeColor(void *context, const TGLottiePath *path, const TGLottieAffine *pathTransform, const TGLottieStrokeStyle *style, float r, float g, float b, float a)
{
    CGContextRef cg = ((TGAnimatedStickerDrawingContext *)context)->context;
    CGContextSaveGState(cg);
    CGContextConcatCTM(cg, TGAnimatedStickerAffine(pathTransform));
    CGContextBeginPath(cg);
    TGAnimatedStickerAddPath(cg, path);
    TGAnimatedStickerApplyStrokeStyle(cg, style);
    CGContextSetRGBStrokeColor(cg, r, g, b, a);
    CGContextStrokePath(cg);
    CGContextRestoreGState(cg);
}

static void TGAnimatedStickerStrokeGradient(void *context, const TGLottiePath *path, const TGLottieAffine *pathTransform, const TGLottieStrokeStyle *style, const TGLottieGradient *gradient, float alpha)
{
    CGContextRef cg = ((TGAnimatedStickerDrawingContext *)context)->context;
    CGContextSaveGState(cg);
    CGContextConcatCTM(cg, TGAnimatedStickerAffine(pathTransform));
    CGContextBeginPath(cg);
    TGAnimatedStickerAddPath(cg, path);
    TGAnimatedStickerApplyStrokeStyle(cg, style);
    CGContextReplacePathWithStrokedPath(cg);
    CGContextClip(cg);
    CGContextSetAlpha(cg, alpha);
    TGAnimatedStickerDrawGradient(cg, gradient);
    CGContextRestoreGState(cg);
}

static void TGAnimatedStickerBeginGroup(void *context, float opacity, const TGLottiePath *clipPath, int clipEvenOdd)
{
    TGAnimatedStickerDrawingContext *drawing = (TGAnimatedStickerDrawingContext *)context;
    CGContextRef cg = drawing->context;
    CGContextSaveGState(cg);
    if (clipPath != NULL && clipPath->commandCount != 0)
    {
        CGContextBeginPath(cg);
        TGAnimatedStickerAddPath(cg, clipPath);
        if (clipEvenOdd)
            CGContextEOClip(cg);
        else
            CGContextClip(cg);
    }
    bool transparency = opacity < 0.999f;
    if (transparency)
    {
        CGContextSetAlpha(cg, opacity);
        CGContextBeginTransparencyLayer(cg, NULL);
    }
    if (drawing->groupDepth < 32)
        drawing->transparencyLayers[drawing->groupDepth] = transparency;
    drawing->groupDepth++;
}

static void TGAnimatedStickerEndGroup(void *context)
{
    TGAnimatedStickerDrawingContext *drawing = (TGAnimatedStickerDrawingContext *)context;
    if (drawing->groupDepth == 0)
        return;
    drawing->groupDepth--;
    if (drawing->groupDepth < 32 && drawing->transparencyLayers[drawing->groupDepth])
        CGContextEndTransparencyLayer(drawing->context);
    CGContextRestoreGState(drawing->context);
}

@interface OGLottieStickerSource : NSObject <OGStickerFrameSource>
{
    TGLottieAnimation *_animation;
    TGLottieRenderContext *_renderContext;
    CGContextRef _context;
    size_t _width;
    size_t _height;
    float _rate;
    float _start;
    float _end;
    NSUInteger _dataLength;
}

- (instancetype)initWithData:(NSData *)data width:(size_t)width height:(size_t)height pixels:(void *)pixels;

@end

@implementation OGLottieStickerSource

- (instancetype)initWithData:(NSData *)data width:(size_t)width height:(size_t)height pixels:(void *)pixels
{
    self = [super init];
    if (self != nil)
    {
        _animation = TGLottieAnimationCreate(data.bytes, data.length);
        if (_animation == NULL)
            return nil;
        _dataLength = data.length;
        _renderContext = TGLottieRenderContextCreate();
        _rate = TGLottieAnimationFrameRate(_animation);
        _start = TGLottieAnimationStartFrame(_animation);
        _end = TGLottieAnimationEndFrame(_animation);
        _width = width;
        _height = height;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        _context = CGBitmapContextCreate(pixels, width, height, 8, width * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        CGColorSpaceRelease(colorSpace);
        if (_context == NULL || _renderContext == NULL || _rate <= 0 || _end <= _start)
            return nil;
        CGContextTranslateCTM(_context, 0.0f, (CGFloat)height);
        CGContextScaleCTM(_context, 1.0f, -1.0f);
        CGContextSetInterpolationQuality(_context, kCGInterpolationMedium);
    }
    return self;
}

- (void)dealloc
{
    if (_context != NULL)
        CGContextRelease(_context);
    if (_renderContext != NULL)
        TGLottieRenderContextDestroy(_renderContext);
    if (_animation != NULL)
        TGLottieAnimationDestroy(_animation);
}

- (NSTimeInterval)duration
{
    return (_end - _start) / _rate;
}

- (bool)hasAlpha
{
    return true;
}

- (NSUInteger)memoryCost
{
    return _dataLength * 4;
}

- (double)frameRate
{
    return _rate;
}

- (bool)renderAtTime:(NSTimeInterval)time intoBGRA:(uint8_t *)pixels cancelled:(bool (^)(void))cancelled
{
    if (pixels == NULL || _context == NULL || (cancelled != nil && cancelled()))
        return false;
    memset(pixels, 0, _width * _height * 4);
    float width = TGLottieAnimationWidth(_animation);
    float height = TGLottieAnimationHeight(_animation);
    if (width <= 0 || height <= 0)
        return false;
    float scale = MIN((float)_width / width, (float)_height / height);
    TGLottieAffine root = { scale, 0.0f, 0.0f, scale, ((float)_width - width * scale) * 0.5f, ((float)_height - height * scale) * 0.5f };
    TGAnimatedStickerDrawingContext drawing;
    memset(&drawing, 0, sizeof(drawing));
    drawing.context = _context;
    TGLottieRenderer renderer = {
        &drawing,
        TGAnimatedStickerFillColor,
        TGAnimatedStickerFillGradient,
        TGAnimatedStickerStrokeColor,
        TGAnimatedStickerStrokeGradient,
        TGAnimatedStickerBeginGroup,
        TGAnimatedStickerEndGroup
    };
    CGContextSaveGState(_context);
    TGLottieRender(_renderContext, _animation, MIN(_end - 0.001f, _start + (float)time * _rate), root, &renderer);
    while (drawing.groupDepth > 0)
        TGAnimatedStickerEndGroup(&drawing);
    CGContextRestoreGState(_context);
    return true;
}

@end

@interface TGAnimatedStickerFrames ()
{
    NSString *_filePath;
    NSString *_cachePath;
    NSString *_posterPath;
    bool _playbackActive;
    size_t _width;
    size_t _height;
    NSInteger _framesPerSecond;
    NSUInteger _frameCount;
    bool _prepared;
    bool _failed;

    id<OGStickerFrameSource> _source;
    void *_bitmapData;
    bool _webm;
    bool _sceneAnimation;
    bool _failureLogged;

    NSMutableArray *_compressedFrames;
    NSUInteger _compressedFrameCount;
    volatile NSUInteger _availableFrameCount;
    volatile float _preparationFramesPerSecond;
    pthread_mutex_t _storageLock;
    NSUInteger _compressedBytes;

    NSData *_cacheData;
    const uint32_t *_cacheOffsets;

    pthread_mutex_t _lock;
    volatile bool _complete;
    uint64_t _pressureGeneration;
}

@end

@implementation TGAnimatedStickerFrames

+ (TGAnimatedStickerFrames *)framesWithKey:(NSString *)key filePath:(NSString *)filePath pixelSize:(CGSize)pixelSize
{
    return [self framesWithKey:key filePath:filePath pixelSize:pixelSize sourceFrameRate:false];
}

+ (TGAnimatedStickerFrames *)framesWithKey:(NSString *)key filePath:(NSString *)filePath pixelSize:(CGSize)pixelSize sourceFrameRate:(bool)sourceFrameRate
{
    if (key.length == 0 || filePath.length == 0)
        return nil;
    NSInteger framesPerSecond = sourceFrameRate ? 0 : TGAnimatedStickerCurrentTier().framesPerSecond;
    CGFloat scale = MIN(1.0f, TGAnimatedStickerCurrentTier().maximumPixelSide / MAX(pixelSize.width, pixelSize.height));
    size_t width = (size_t)MAX(1.0f, CGFloor(pixelSize.width * scale));
    size_t height = (size_t)MAX(1.0f, CGFloor(pixelSize.height * scale));
    NSString *cacheKey = sourceFrameRate ? [[NSString alloc] initWithFormat:@"%@_%dx%d_source", key, (int)width, (int)height] : [[NSString alloc] initWithFormat:@"%@_%dx%d_%d", key, (int)width, (int)height, (int)framesPerSecond];
    NSCache *cache = TGAnimatedStickerFramesCache();
    TGAnimatedStickerFrames *frames = [cache objectForKey:cacheKey];
    if (frames != nil)
        return frames;
    frames = [[TGAnimatedStickerFrames alloc] initWithKey:cacheKey filePath:filePath width:width height:height framesPerSecond:framesPerSecond];
    [cache setObject:frames forKey:cacheKey cost:width * height * 4];
    return frames;
}

- (instancetype)initWithKey:(NSString *)key filePath:(NSString *)filePath width:(size_t)width height:(size_t)height framesPerSecond:(NSInteger)framesPerSecond
{
    self = [super init];
    if (self != nil)
    {
        _key = key;
        _filePath = filePath;
        _width = width;
        _height = height;
        _pixelSize = CGSizeMake(width, height);
        _framesPerSecond = framesPerSecond;
        _frameDuration = framesPerSecond > 0 ? 1.0 / (NSTimeInterval)framesPerSecond : 0.0;
        _webm = [[filePath.pathExtension lowercaseString] isEqualToString:@"webm"];
        _sceneAnimation = [@[@"webp", @"apng", @"gif"] containsObject:[filePath.pathExtension lowercaseString]];
        NSString *safeKey = [[key stringByReplacingOccurrencesOfString:@"/" withString:@"_"] stringByReplacingOccurrencesOfString:@":" withString:@"_"];
        _cachePath = [TGAnimatedStickerCacheDirectory() stringByAppendingPathComponent:[safeKey stringByAppendingString:@".frames"]];
        _posterPath = [TGAnimatedStickerCacheDirectory() stringByAppendingPathComponent:[safeKey stringByAppendingString:@".poster"]];
        pthread_mutexattr_t attributes;
        pthread_mutexattr_init(&attributes);
        pthread_mutexattr_settype(&attributes, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&_lock, &attributes);
        pthread_mutexattr_destroy(&attributes);
        pthread_mutex_init(&_storageLock, NULL);
        id tracked = TGAnimatedStickerTrackedFrames();
        @synchronized (tracked)
        {
            [tracked addObject:self];
        }
    }
    return self;
}

- (void)dealloc
{
    _source = nil;
    if (_bitmapData != NULL)
        free(_bitmapData);
    pthread_mutex_destroy(&_lock);
    pthread_mutex_destroy(&_storageLock);
}

- (void)releaseRenderer
{
    _source = nil;
    if (_bitmapData != NULL)
    {
        free(_bitmapData);
        _bitmapData = NULL;
    }
    [self updateCacheCost];
}

- (uint64_t)memoryBytes
{
    if (pthread_mutex_trylock(&_lock) != 0)
        return 0;
    uint64_t result = _compressedBytes;
    if (_cacheData != nil)
        result += _cacheData.length;
    if (_bitmapData != NULL)
        result += _width * _height * 4;
    if (_source != nil)
        result += [_source memoryCost];
    pthread_mutex_unlock(&_lock);
    return result;
}

- (void)trimForMemoryPressure:(BOOL)critical
{
    pthread_mutex_lock(&_lock);
    [self releaseRenderer];
    if (critical)
    {
        pthread_mutex_lock(&_storageLock);
        BOOL hadDiskCache = _cacheData != nil;
        _compressedFrames = nil;
        _compressedFrameCount = 0;
        _availableFrameCount = 0;
        _compressedBytes = 0;
        _cacheData = nil;
        _cacheOffsets = NULL;
        _prepared = !hadDiskCache && _prepared;
        if (_prepared && _frameCount != 0)
        {
            _compressedFrames = [[NSMutableArray alloc] initWithCapacity:_frameCount];
            for (NSUInteger index = 0; index < _frameCount; index++)
                [_compressedFrames addObject:[NSNull null]];
        }
        _failed = false;
        _complete = false;
        _pressureGeneration++;
        pthread_mutex_unlock(&_storageLock);
    }
    [self updateCacheCost];
    pthread_mutex_unlock(&_lock);
}

- (void)updateCacheCost
{
    NSCache *cache = TGAnimatedStickerFramesCache();
    if ([cache objectForKey:_key] != self)
        return;
    NSUInteger cost = _cacheData != nil ? _width * _height * 4 : _compressedBytes;
    if (_source != nil)
        cost += [_source memoryCost] + _width * _height * 4;
    [cache setObject:self forKey:_key cost:cost];
}

- (NSUInteger)frameCount
{
    pthread_mutex_lock(&_lock);
    NSUInteger frameCount = _frameCount;
    pthread_mutex_unlock(&_lock);
    return frameCount;
}

- (NSInteger)framesPerSecond
{
    pthread_mutex_lock(&_lock);
    NSInteger framesPerSecond = _framesPerSecond;
    pthread_mutex_unlock(&_lock);
    return framesPerSecond;
}

- (NSUInteger)availableFrameCount
{
    return _availableFrameCount;
}

- (float)preparationFramesPerSecond
{
    return _preparationFramesPerSecond;
}

- (uint64_t)storagePressureGeneration
{
    pthread_mutex_lock(&_storageLock);
    uint64_t generation = _pressureGeneration;
    pthread_mutex_unlock(&_storageLock);
    return generation;
}

- (bool)hasStoredFrame:(NSUInteger)index
{
    pthread_mutex_lock(&_storageLock);
    bool stored = _cacheData != nil || (index < _compressedFrames.count && [_compressedFrames[index] isKindOfClass:[NSData class]]);
    pthread_mutex_unlock(&_storageLock);
    return stored;
}

- (CGImageRef)copyStoredImageForFrame:(NSUInteger)index
{
    NSData *data = nil;
    NSRange range = NSMakeRange(0, 0);
    pthread_mutex_lock(&_storageLock);
    if (_frameCount != 0)
    {
        index %= _frameCount;
        if (_cacheData != nil)
        {
            data = _cacheData;
            range = NSMakeRange(_cacheOffsets[index], _cacheOffsets[index + 1] - _cacheOffsets[index]);
        }
        else if (index < _compressedFrames.count && [_compressedFrames[index] isKindOfClass:[NSData class]])
        {
            data = _compressedFrames[index];
            range = NSMakeRange(0, data.length);
        }
    }
    pthread_mutex_unlock(&_storageLock);
    if (data == nil || range.length == 0)
        return NULL;
    return [self decompressedImageFromBytes:(const uint8_t *)data.bytes + range.location length:range.length];
}

static NSData *TGAnimatedStickerCompressFrame(const void *pixels, size_t pixelLength)
{
    NSMutableData *compressed = [[NSMutableData alloc] initWithLength:(NSUInteger)LZ4_compressBound((int)pixelLength)];
    int length = LZ4_compress((const char *)pixels, (char *)compressed.mutableBytes, (int)pixelLength);
    if (length <= 0)
        return nil;
    [compressed setLength:(NSUInteger)length];
    return compressed;
}

static dispatch_queue_t TGAnimatedStickerPreparationHelperQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("org.onegram.animated-stickers.preparation", NULL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    });
    return queue;
}

- (bool)isComplete
{
    return _complete;
}

- (void)updateCompletion
{
    _complete = _cacheData != nil || (_frameCount != 0 && _compressedFrameCount == _frameCount);
}

static double TGAnimatedStickerThreadCPUTime(void)
{
    thread_basic_info_data_t info;
    mach_msg_type_number_t count = THREAD_BASIC_INFO_COUNT;
    if (thread_info(pthread_mach_thread_np(pthread_self()), THREAD_BASIC_INFO, (thread_info_t)&info, &count) != KERN_SUCCESS)
        return 0.0;
    return (double)(info.user_time.seconds + info.system_time.seconds) + (double)(info.user_time.microseconds + info.system_time.microseconds) / 1000000.0;
}

- (bool)renderRemainingFramesCancelled:(bool (^)(void))cancelled
{
    pthread_mutex_lock(&_lock);
    bool prepared = [self prepare] && _frameCount != 0;
    [self updateCompletion];
    bool complete = _complete;
    bool parallel = prepared && !complete && !_webm && !_sceneAnimation && cpuCoreCount() > 1;
    pthread_mutex_unlock(&_lock);
    if (!prepared)
        return false;
    if (complete)
        return true;
    if (parallel)
        return [self renderRemainingFramesInParallelCancelled:cancelled];
    return [self renderRemainingFramesSeriallyCancelled:cancelled];
}

- (bool)renderRemainingFramesInParallelCancelled:(bool (^)(void))cancelled
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    pthread_mutex_lock(&_lock);
    NSUInteger frameCount = _frameCount;
    NSInteger framesPerSecond = _framesPerSecond;
    size_t width = _width;
    size_t height = _height;
    [self releaseRenderer];
    pthread_mutex_unlock(&_lock);
    uint64_t generation = [self storagePressureGeneration];
    NSData *fileData = [[NSData alloc] initWithContentsOfFile:_filePath options:NSDataReadingMappedIfSafe error:nil];
    if (fileData.length == 0 || framesPerSecond <= 0)
        return false;

    _preparationFramesPerSecond = 0.0f;
    __block volatile int32_t nextIndex = 0;
    __block volatile int32_t renderedCount = 0;
    __block volatile int32_t failed = 0;
    bool (^stopped)(void) = ^bool
    {
        return failed != 0 || (cancelled != nil && cancelled()) || [self storagePressureGeneration] != generation;
    };
    dispatch_block_t work = ^
    {
        @autoreleasepool
        {
            size_t pixelLength = width * height * 4;
            void *pixels = calloc(width * height, 4);
            OGLottieStickerSource *source = pixels != NULL ? [[OGLottieStickerSource alloc] initWithData:fileData width:width height:height pixels:pixels] : nil;
            if (source == nil)
                OSAtomicIncrement32Barrier(&failed);
            while (source != nil && !stopped())
            {
                int32_t index = OSAtomicIncrement32Barrier(&nextIndex) - 1;
                if (index < 0 || (NSUInteger)index >= frameCount)
                    break;
                if ([self hasStoredFrame:(NSUInteger)index])
                    continue;
                if (![source renderAtTime:(NSTimeInterval)index / (NSTimeInterval)framesPerSecond intoBGRA:pixels cancelled:stopped])
                {
                    if (!stopped())
                        OSAtomicIncrement32Barrier(&failed);
                    break;
                }
                NSData *compressed = TGAnimatedStickerCompressFrame(pixels, pixelLength);
                if (compressed == nil)
                {
                    OSAtomicIncrement32Barrier(&failed);
                    break;
                }
                if (![self insertCompressedFrame:compressed index:(NSUInteger)index generation:generation])
                    break;
                __sync_fetch_and_add(&TGAnimatedStickerDecodedFrames, 1);
                int32_t rendered = OSAtomicIncrement32Barrier(&renderedCount);
                _preparationFramesPerSecond = (float)((double)rendered / MAX(0.001, CFAbsoluteTimeGetCurrent() - start));
            }
            source = nil;
            if (pixels != NULL)
                free(pixels);
        }
    };
    dispatch_semaphore_t helperFinished = dispatch_semaphore_create(0);
    dispatch_async(TGAnimatedStickerPreparationHelperQueue(), ^
    {
        work();
        dispatch_semaphore_signal(helperFinished);
    });
    work();
    dispatch_semaphore_wait(helperFinished, DISPATCH_TIME_FOREVER);
#if !OS_OBJECT_USE_OBJC
    dispatch_release(helperFinished);
#endif

    pthread_mutex_lock(&_lock);
    [self updateCompletion];
    bool complete = _complete;
    pthread_mutex_unlock(&_lock);
    if (complete && renderedCount != 0)
        OGPlatformDiagnosticLog(@"STICKERFRAMES ready kind=tgs-parallel key=%@ frames=%d rendered=%d size=%dx%d ms=%d", _key, (int)frameCount, (int)renderedCount, (int)width, (int)height, (int)((CFAbsoluteTimeGetCurrent() - start) * 1000.0));
    return complete && failed == 0;
}

- (bool)renderRemainingFramesSeriallyCancelled:(bool (^)(void))cancelled
{
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    _preparationFramesPerSecond = 0.0f;
    double cpuStart = TGAnimatedStickerThreadCPUTime();
    CFAbsoluteTime lockWaitTime = 0.0;
    CFAbsoluteTime renderTime = 0.0;
    CFAbsoluteTime compressTime = 0.0;
    NSString *sourceStatistics = nil;
    NSUInteger rendered = 0;
    NSUInteger index = 0;
    uint64_t observedGeneration = 0;
    while (true)
    {
        if (cancelled != nil && cancelled())
            return false;
        CFAbsoluteTime lockStart = CFAbsoluteTimeGetCurrent();
        pthread_mutex_lock(&_lock);
        lockWaitTime += CFAbsoluteTimeGetCurrent() - lockStart;
        if (observedGeneration != _pressureGeneration)
        {
            index = 0;
            observedGeneration = _pressureGeneration;
        }
        bool finished = false;
        bool succeeded = true;
        if (![self prepare] || _frameCount == 0)
        {
            finished = true;
            succeeded = false;
        }
        else
        {
            [self updateCompletion];
            if (_complete)
                finished = true;
            else
            {
                while (index < _frameCount && [_compressedFrames[index] isKindOfClass:[NSData class]])
                    index++;
                CFAbsoluteTime renderStart = CFAbsoluteTimeGetCurrent();
                if (index >= _frameCount)
                    finished = true;
                else if (![self prepareRenderer] || ![self renderFrame:index cancelled:cancelled])
                {
                    finished = true;
                    succeeded = false;
                }
                else
                {
                    renderTime += CFAbsoluteTimeGetCurrent() - renderStart;
                    if ([(id)_source isKindOfClass:[OGWebMStickerSource class]])
                        sourceStatistics = [(OGWebMStickerSource *)_source statistics];
                    CFAbsoluteTime compressStart = CFAbsoluteTimeGetCurrent();
                    [self storeCompressedFrame:index];
                    compressTime += CFAbsoluteTimeGetCurrent() - compressStart;
                    index++;
                    rendered++;
                    _preparationFramesPerSecond = (float)((double)rendered / MAX(0.001, CFAbsoluteTimeGetCurrent() - start));
                    [self updateCompletion];
                }
            }
        }
        bool complete = _complete;
        NSUInteger frameCount = _frameCount;
        bool webm = _webm;
        pthread_mutex_unlock(&_lock);
        if (finished)
        {
            if (complete && rendered != 0)
                OGPlatformDiagnosticLog(@"STICKERFRAMES ready kind=%@ key=%@ frames=%d rendered=%d size=%dx%d ms=%d cpuMs=%d lockWaitMs=%d renderMs=%d compressMs=%d %@", webm ? @"webm" : @"tgs", _key, (int)frameCount, (int)rendered, (int)_width, (int)_height, (int)((CFAbsoluteTimeGetCurrent() - start) * 1000.0), (int)((TGAnimatedStickerThreadCPUTime() - cpuStart) * 1000.0), (int)(lockWaitTime * 1000.0), (int)(renderTime * 1000.0), (int)(compressTime * 1000.0), sourceStatistics ?: @"");
            return succeeded && complete;
        }
    }
}

- (bool)loadDiskCache
{
    NSData *data = [[NSData alloc] initWithContentsOfFile:_cachePath options:NSDataReadingMappedIfSafe error:nil];
    if (data.length < sizeof(TGAnimatedStickerCacheHeader))
        return false;
    const TGAnimatedStickerCacheHeader *header = (const TGAnimatedStickerCacheHeader *)data.bytes;
    bool framesPerSecondMatches = _framesPerSecond > 0 ? header->framesPerSecond == (uint32_t)_framesPerSecond : (header->framesPerSecond != 0 && header->framesPerSecond <= 60);
    if (header->magic != TGAnimatedStickerCacheMagic || header->version != TGAnimatedStickerCacheVersion || header->width != _width || header->height != _height || !framesPerSecondMatches || header->frameCount == 0 || header->frameCount > TGAnimatedStickerMaximumFrameCount)
        return false;
    size_t tableSize = sizeof(uint32_t) * (header->frameCount + 1);
    if (data.length < sizeof(TGAnimatedStickerCacheHeader) + tableSize)
        return false;
    const uint32_t *offsets = (const uint32_t *)((const uint8_t *)data.bytes + sizeof(TGAnimatedStickerCacheHeader));
    for (uint32_t index = 0; index < header->frameCount; index++)
    {
        if (offsets[index] > offsets[index + 1] || offsets[index + 1] > data.length)
            return false;
    }
    pthread_mutex_lock(&_storageLock);
    _cacheData = data;
    _cacheOffsets = offsets;
    _frameCount = header->frameCount;
    if (_framesPerSecond <= 0)
    {
        _framesPerSecond = (NSInteger)header->framesPerSecond;
        _frameDuration = 1.0 / (NSTimeInterval)_framesPerSecond;
    }
    _availableFrameCount = _frameCount;
    pthread_mutex_unlock(&_storageLock);
    _complete = true;
    return true;
}

- (bool)prepareRenderer
{
    if (_source != nil)
        return true;
    NSData *fileData = [[NSData alloc] initWithContentsOfFile:_filePath options:NSDataReadingMappedIfSafe error:nil];
    if (fileData.length == 0)
        return false;
    if (fileData.length >= 4)
    {
        const uint8_t *bytes = fileData.bytes;
        if (bytes[0] == 0x1a && bytes[1] == 0x45 && bytes[2] == 0xdf && bytes[3] == 0xa3)
            _webm = true;
    }
    _bitmapData = calloc(_width * _height, 4);
    if (_bitmapData == NULL)
        return false;
    if (_sceneAnimation)
    {
#if OG_PLUGINS_AVAILABLE
        Class sourceClass = NSClassFromString(@"OGSceneAnimatedSource");
        if (sourceClass != Nil)
            _source = [(OGSceneAnimatedSource *)[sourceClass alloc] initWithData:fileData width:_width height:_height format:[_filePath.pathExtension lowercaseString]];
#endif
    }
    else if (_webm)
        _source = [[OGWebMStickerSource alloc] initWithData:fileData width:_width height:_height];
    else
        _source = [[OGLottieStickerSource alloc] initWithData:fileData width:_width height:_height pixels:_bitmapData];
    if (_source == nil)
    {
        if (_sceneAnimation)
            OGPlatformDiagnosticLog(@"SCENEFRAMES failed key=%@ reason=%@", _key, @"invalid animation or memory budget exceeded");
        [self releaseRenderer];
        return false;
    }
    [self updateCacheCost];
    return true;
}

- (bool)prepare
{
    if (_prepared)
        return !_failed;
    _prepared = true;
    if ([self loadDiskCache])
        return true;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    if (![self prepareRenderer])
    {
        _failed = true;
        if (_webm && !_failureLogged)
        {
            OGPlatformDiagnosticLog(@"VSTICKER failed key=%@ reason=%@", _key, @"invalid WebM or decoder initialization");
            _failureLogged = true;
        }
        return false;
    }
    if (_framesPerSecond <= 0)
    {
        double sourceFrameRate = [_source respondsToSelector:@selector(frameRate)] ? [_source frameRate] : 0.0;
        NSInteger framesPerSecond = sourceFrameRate > 0.0 ? (NSInteger)lround(sourceFrameRate) : TGAnimatedStickerCurrentTier().framesPerSecond;
        _framesPerSecond = MAX((NSInteger)1, MIN((NSInteger)60, framesPerSecond));
        _frameDuration = 1.0 / (NSTimeInterval)_framesPerSecond;
    }
    NSTimeInterval duration = [_source duration];
    NSUInteger frameCount = (NSUInteger)ceil(duration * (double)_framesPerSecond);
    if (frameCount == 0 || frameCount > TGAnimatedStickerMaximumFrameCount)
    {
        _failed = true;
        if (_webm && !_failureLogged)
        {
            OGPlatformDiagnosticLog(@"VSTICKER failed key=%@ reason=%@", _key, @"invalid duration");
            _failureLogged = true;
        }
        [self releaseRenderer];
        return false;
    }
    pthread_mutex_lock(&_storageLock);
    _frameCount = frameCount;
    _compressedFrames = [[NSMutableArray alloc] initWithCapacity:frameCount];
    for (NSUInteger index = 0; index < frameCount; index++)
        [_compressedFrames addObject:[NSNull null]];
    pthread_mutex_unlock(&_storageLock);
    if (_sceneAnimation)
        OGPlatformDiagnosticLog(@"SCENEFRAMES prepared key=%@ frames=%d size=%dx%d ms=%d", _key, (int)frameCount, (int)_width, (int)_height, (int)((CFAbsoluteTimeGetCurrent() - start) * 1000.0));
    if (_webm)
        OGPlatformDiagnosticLog(@"VSTICKER prepared key=%@ frames=%d size=%dx%d alpha=%d ms=%d", _key, (int)frameCount, (int)_width, (int)_height, [_source hasAlpha] ? 1 : 0, (int)((CFAbsoluteTimeGetCurrent() - start) * 1000.0));
    return true;
}

- (CGImageRef)createImageWithBytes:(const void *)bytes
{
    NSData *pixels = [[NSData alloc] initWithBytes:bytes length:_width * _height * 4];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(_width, _height, 8, 32, _width * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    return image;
}

- (CGImageRef)decompressedImageFromBytes:(const void *)bytes length:(NSUInteger)length
{
    size_t pixelLength = _width * _height * 4;
    NSMutableData *pixels = [[NSMutableData alloc] initWithLength:pixelLength];
    if (pixels == nil)
        return NULL;
    int decoded = LZ4_decompress_safe((const char *)bytes, (char *)pixels.mutableBytes, (int)length, (int)pixelLength);
    if (decoded != (int)pixelLength)
        return NULL;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(_width, _height, 8, 32, _width * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst, provider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    return image;
}

- (bool)renderFrame:(NSUInteger)index cancelled:(bool (^)(void))cancelled
{
    if ([_source renderAtTime:(NSTimeInterval)index / _framesPerSecond intoBGRA:_bitmapData cancelled:cancelled])
    {
        __sync_fetch_and_add(&TGAnimatedStickerDecodedFrames, 1);
        return true;
    }
    if (cancelled != nil && cancelled())
        return false;
    if (_webm && !_failureLogged)
    {
        NSString *reason = [(OGWebMStickerSource *)_source failureReason] ?: @"frame rendering";
        OGPlatformDiagnosticLog(@"VSTICKER failed key=%@ reason=%@", _key, reason);
        _failureLogged = true;
    }
    _failed = true;
    [self releaseRenderer];
    return false;
}

- (void)storeCompressedFrame:(NSUInteger)index
{
    int sourceLength = (int)(_width * _height * 4);
    NSMutableData *compressed = [[NSMutableData alloc] initWithLength:(NSUInteger)LZ4_compressBound(sourceLength)];
    int length = LZ4_compress((const char *)_bitmapData, (char *)compressed.mutableBytes, sourceLength);
    if (length <= 0)
        return;
    [compressed setLength:(NSUInteger)length];
    [self storeCompressedData:compressed index:index];
}

- (bool)insertCompressedFrame:(NSData *)compressed index:(NSUInteger)index generation:(uint64_t)generation
{
    pthread_mutex_lock(&_lock);
    bool current = _pressureGeneration == generation;
    if (current && _compressedFrames != nil && index < _compressedFrames.count && ![_compressedFrames[index] isKindOfClass:[NSData class]])
        [self storeCompressedData:compressed index:index];
    pthread_mutex_unlock(&_lock);
    return current;
}

- (void)storeCompressedData:(NSData *)compressed index:(NSUInteger)index
{
    pthread_mutex_lock(&_storageLock);
    _compressedFrames[index] = compressed;
    _compressedFrameCount++;
    NSUInteger availableFrameCount = _availableFrameCount;
    while (availableFrameCount < _frameCount && [_compressedFrames[availableFrameCount] isKindOfClass:[NSData class]])
        availableFrameCount++;
    _availableFrameCount = availableFrameCount;
    pthread_mutex_unlock(&_storageLock);
    _compressedBytes += compressed.length;
    if (_compressedFrameCount == _frameCount)
        [self finishRendering];
    else if (_compressedFrameCount % 8 == 0)
        [self updateCacheCost];
}

- (void)finishRendering
{
    TGAnimatedStickerCacheHeader header;
    header.magic = TGAnimatedStickerCacheMagic;
    header.version = TGAnimatedStickerCacheVersion;
    header.width = (uint32_t)_width;
    header.height = (uint32_t)_height;
    header.frameCount = (uint32_t)_frameCount;
    header.framesPerSecond = (uint32_t)_framesPerSecond;
    size_t tableSize = sizeof(uint32_t) * (_frameCount + 1);
    NSMutableData *file = [[NSMutableData alloc] initWithCapacity:sizeof(header) + tableSize + _compressedBytes];
    [file appendBytes:&header length:sizeof(header)];
    uint32_t offset = (uint32_t)(sizeof(header) + tableSize);
    for (NSUInteger index = 0; index < _frameCount; index++)
    {
        [file appendBytes:&offset length:sizeof(offset)];
        offset += (uint32_t)((NSData *)_compressedFrames[index]).length;
    }
    [file appendBytes:&offset length:sizeof(offset)];
    for (NSData *frame in _compressedFrames)
        [file appendData:frame];
    if ([file writeToFile:_cachePath atomically:true] && [self loadDiskCache])
    {
        pthread_mutex_lock(&_storageLock);
        _compressedFrames = nil;
        pthread_mutex_unlock(&_storageLock);
        [self releaseRenderer];
    }
    else
        [self releaseRenderer];
    [self updateCompletion];
    [self updateCacheCost];
}

- (CGImageRef)copyPosterImage
{
    pthread_mutex_lock(&_lock);
    CGImageRef image = [self lockedCopyPosterImage];
    pthread_mutex_unlock(&_lock);
    return image;
}

- (CGImageRef)lockedCopyPosterImage
{
    if (_cacheData != nil || _playbackActive)
        return [self copyImageForFrame:0];
    NSData *poster = [[NSData alloc] initWithContentsOfFile:_posterPath options:NSDataReadingMappedIfSafe error:nil];
    if (poster.length != 0)
    {
        CGImageRef image = [self decompressedImageFromBytes:poster.bytes length:poster.length];
        if (image != NULL)
            return image;
    }
    if (![self prepare] || _frameCount == 0)
        return NULL;
    if (_cacheData != nil)
        return [self copyImageForFrame:0];
    id stored = _compressedFrames[0];
    if ([stored isKindOfClass:[NSData class]])
        return [self decompressedImageFromBytes:((NSData *)stored).bytes length:((NSData *)stored).length];
    if (![self prepareRenderer])
        return NULL;
    if (![self renderFrame:0 cancelled:nil])
        return NULL;
    CGImageRef image = [self createImageWithBytes:_bitmapData];
    [self storeCompressedFrame:0];
    id compressed = _compressedFrames.count != 0 ? _compressedFrames[0] : nil;
    if ([compressed isKindOfClass:[NSData class]])
        [(NSData *)compressed writeToFile:_posterPath atomically:true];
    if (!_playbackActive && _cacheData == nil)
        [self releaseRenderer];
    return image;
}

- (CGImageRef)copyImageForFrame:(NSUInteger)index
{
    return [self copyImageForFrame:index cancelled:nil];
}

- (CGImageRef)copyImageForFrame:(NSUInteger)index cancelled:(bool (^)(void))cancelled
{
    pthread_mutex_lock(&_lock);
    CGImageRef image = [self lockedCopyImageForFrame:index cancelled:cancelled];
    pthread_mutex_unlock(&_lock);
    return image;
}

- (CGImageRef)lockedCopyImageForFrame:(NSUInteger)index cancelled:(bool (^)(void))cancelled
{
    if (cancelled != nil && cancelled())
        return NULL;
    if (![self prepare] || _frameCount == 0)
        return NULL;
    index %= _frameCount;
    if (index != 0)
        _playbackActive = true;
    if (_cacheData != nil)
        return [self decompressedImageFromBytes:(const uint8_t *)_cacheData.bytes + _cacheOffsets[index] length:_cacheOffsets[index + 1] - _cacheOffsets[index]];
    id stored = _compressedFrames[index];
    if ([stored isKindOfClass:[NSData class]])
        return [self decompressedImageFromBytes:((NSData *)stored).bytes length:((NSData *)stored).length];
    if (![self prepareRenderer])
        return NULL;
    if (![self renderFrame:index cancelled:cancelled])
        return NULL;
    CGImageRef image = [self createImageWithBytes:_bitmapData];
    [self storeCompressedFrame:index];
    return image;
}

@end

@implementation TGAnimatedStickerMemoryObserver

- (void)memoryWarning:(NSNotification *)notification
{
    [TGAnimatedStickerFramesCache() removeAllObjects];
    NSArray *frames = TGAnimatedStickerLiveFrames();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        for (TGAnimatedStickerFrames *frame in frames)
            [frame trimForMemoryPressure:YES];
    });
}

- (void)applicationBackground:(NSNotification *)notification
{
    NSArray *frames = TGAnimatedStickerLiveFrames();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
        for (TGAnimatedStickerFrames *frame in frames)
            [frame trimForMemoryPressure:NO];
    });
}

@end
