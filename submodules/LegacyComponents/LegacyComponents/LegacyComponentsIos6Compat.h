#ifndef OG_LEGACY_COMPONENTS_COMPAT_H
#define OG_LEGACY_COMPONENTS_COMPAT_H
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <math.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#define NSAttributedString TGIOS3AttributedString
#define NSMutableAttributedString TGIOS3MutableAttributedString

@class AVAsset;
@class AVAudioSession;
@class AVCaptureConnection;
@class AVCaptureDevice;
@class AVCaptureInputPort;
@class AVCaptureOutput;
@class AVPlayer;
@class UIGestureRecognizer;
@class UIPopoverController;

typedef NSInteger UIUserInterfaceLayoutDirection;
typedef NSUInteger UIViewAnimationOptions;
typedef NSUInteger NSStringDrawingOptions;
typedef NSInteger UIStatusBarAnimation;
typedef NSInteger AVCaptureVideoOrientation;

#ifndef UIUserInterfaceLayoutDirectionLeftToRight
#define UIUserInterfaceLayoutDirectionLeftToRight 0
#define UIUserInterfaceLayoutDirectionRightToLeft 1
#endif

#define UIViewAnimationOptionLayoutSubviews (1 << 0)
#define UIViewAnimationOptionAllowUserInteraction (1 << 1)
#define UIViewAnimationOptionBeginFromCurrentState (1 << 2)
#define UIViewAnimationOptionRepeat (1 << 3)
#define UIViewAnimationOptionAutoreverse (1 << 4)
#define UIViewAnimationOptionAllowAnimatedContent (1 << 7)
#define UIViewAnimationOptionCurveEaseInOut (0 << 16)
#define UIViewAnimationOptionCurveEaseIn (1 << 16)
#define UIViewAnimationOptionCurveEaseOut (2 << 16)
#define UIViewAnimationOptionCurveLinear (3 << 16)
#define UIViewAnimationOptionTransitionFlipFromLeft (1 << 20)
#define UIViewAnimationOptionTransitionCrossDissolve (5 << 20)

#ifndef UIStatusBarAnimationNone
#define UIStatusBarAnimationNone 0
#define UIStatusBarAnimationFade 1
#define UIStatusBarAnimationSlide 2
#endif

#ifndef AVCaptureVideoOrientationPortrait
#define AVCaptureVideoOrientationPortrait 1
#define AVCaptureVideoOrientationPortraitUpsideDown 2
#define AVCaptureVideoOrientationLandscapeRight 3
#define AVCaptureVideoOrientationLandscapeLeft 4
#endif
#endif

#if __has_include(<CoreVideo/CoreVideo.h>)
#import <CoreVideo/CoreVideo.h>
#else
#include <stdint.h>
#include <stdbool.h>
typedef int32_t CVReturn;
typedef uint64_t CVOptionFlags;
typedef struct __CVBuffer *CVBufferRef;
typedef CVBufferRef CVImageBufferRef;
typedef CVImageBufferRef CVPixelBufferRef;
typedef CVImageBufferRef CVOpenGLESTextureRef;
typedef struct __CVOpenGLESTextureCache *CVOpenGLESTextureCacheRef;
#endif

#if !__has_include(<CoreMedia/CoreMedia.h>)
typedef int64_t CMTimeValue;
typedef int32_t CMTimeScale;
typedef uint32_t CMTimeFlags;
typedef int64_t CMTimeEpoch;

typedef struct
{
    CMTimeValue value;
    CMTimeScale timescale;
    CMTimeFlags flags;
    CMTimeEpoch epoch;
} CMTime;

typedef struct
{
    CMTime start;
    CMTime duration;
} CMTimeRange;

typedef struct opaqueCMSampleBuffer *CMSampleBufferRef;
typedef const struct opaqueCMFormatDescription *CMFormatDescriptionRef;

#ifndef kCMTimeFlags_Valid
#define kCMTimeFlags_Valid (1U << 0)
#define kCMTimeFlags_HasBeenRounded (1U << 1)
#define kCMTimeFlags_PositiveInfinity (1U << 2)
#define kCMTimeFlags_NegativeInfinity (1U << 3)
#define kCMTimeFlags_Indefinite (1U << 4)
#endif

#define OG_COMPAT_CMTIME_HAS_FLAG(time, flag) (((time).flags & (flag)) != 0)

#ifndef CMTIME_IS_VALID
#define CMTIME_IS_VALID(time) OG_COMPAT_CMTIME_HAS_FLAG(time, kCMTimeFlags_Valid)
#endif
#ifndef CMTIME_IS_POSITIVE_INFINITY
#define CMTIME_IS_POSITIVE_INFINITY(time) (CMTIME_IS_VALID(time) && OG_COMPAT_CMTIME_HAS_FLAG(time, kCMTimeFlags_PositiveInfinity))
#endif
#ifndef CMTIME_IS_NEGATIVE_INFINITY
#define CMTIME_IS_NEGATIVE_INFINITY(time) (CMTIME_IS_VALID(time) && OG_COMPAT_CMTIME_HAS_FLAG(time, kCMTimeFlags_NegativeInfinity))
#endif
#ifndef CMTIME_IS_INDEFINITE
#define CMTIME_IS_INDEFINITE(time) (CMTIME_IS_VALID(time) && OG_COMPAT_CMTIME_HAS_FLAG(time, kCMTimeFlags_Indefinite))
#endif
#ifndef CMTIME_IS_NUMERIC
#define CMTIME_IS_NUMERIC(time) (CMTIME_IS_VALID(time) && !CMTIME_IS_POSITIVE_INFINITY(time) && !CMTIME_IS_NEGATIVE_INFINITY(time) && !CMTIME_IS_INDEFINITE(time) && (time).timescale != 0)
#endif

static const CMTime kCMTimeZero = { 0, 1, kCMTimeFlags_Valid, 0 };
static const CMTime kCMTimeInvalid = { 0, 0, 0, 0 };
static const CMTime kCMTimeIndefinite = { 0, 0, kCMTimeFlags_Valid | kCMTimeFlags_Indefinite, 0 };

static inline CMTime CMTimeMake(CMTimeValue value, CMTimeScale timescale)
{
    CMTime result;
    result.value = value;
    result.timescale = timescale;
    result.flags = kCMTimeFlags_Valid;
    result.epoch = 0;
    return result;
}

static inline CMTime CMTimeMakeWithSeconds(double seconds, int32_t preferredTimescale)
{
    return CMTimeMake((CMTimeValue)(seconds * preferredTimescale), preferredTimescale);
}

static inline double CMTimeGetSeconds(CMTime time)
{
    if (time.timescale == 0)
        return 0.0;
    return (double)time.value / (double)time.timescale;
}

static inline CMTimeScale OGCompatFirstNonZeroTimescale(CMTimeScale first, CMTimeScale second, CMTimeScale fallback)
{
    if (first != 0)
        return first;
    if (second != 0)
        return second;
    return fallback;
}

static inline CMTimeRange CMTimeRangeMake(CMTime start, CMTime duration)
{
    CMTimeRange result;
    result.start = start;
    result.duration = duration;
    return result;
}

static inline CMTime CMTimeRangeGetEnd(CMTimeRange range)
{
    CMTimeScale timescale = OGCompatFirstNonZeroTimescale(range.start.timescale, range.duration.timescale, range.duration.timescale);
    return CMTimeMakeWithSeconds(CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration), timescale);
}

static inline int32_t CMTimeCompare(CMTime first, CMTime second)
{
    double firstSeconds = CMTimeGetSeconds(first);
    double secondSeconds = CMTimeGetSeconds(second);
    if (firstSeconds < secondSeconds)
        return -1;
    if (firstSeconds > secondSeconds)
        return 1;
    return 0;
}

static inline CMTime CMTimeAdd(CMTime first, CMTime second)
{
    CMTimeScale timescale = OGCompatFirstNonZeroTimescale(first.timescale, second.timescale, 1);
    return CMTimeMakeWithSeconds(CMTimeGetSeconds(first) + CMTimeGetSeconds(second), timescale);
}

static inline CMTime CMTimeSubtract(CMTime first, CMTime second)
{
    CMTimeScale timescale = OGCompatFirstNonZeroTimescale(first.timescale, second.timescale, 1);
    return CMTimeMakeWithSeconds(CMTimeGetSeconds(first) - CMTimeGetSeconds(second), timescale);
}
#endif

#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <dlfcn.h>
#include <dispatch/dispatch.h>

typedef struct
{
    CVReturn (*createCache)(CFAllocatorRef, CFDictionaryRef, EAGLContext *, CFDictionaryRef, CVOpenGLESTextureCacheRef *);
    CVReturn (*createTexture)(CFAllocatorRef, CVOpenGLESTextureCacheRef, CVImageBufferRef, CFDictionaryRef, GLenum, GLint, GLsizei, GLsizei, GLenum, GLenum, size_t, CVOpenGLESTextureRef *);
    void (*flushCache)(CVOpenGLESTextureCacheRef, CVOptionFlags);
    GLenum (*textureTarget)(CVOpenGLESTextureRef);
    GLuint (*textureName)(CVOpenGLESTextureRef);
} OGCompatTextureCacheSymbols;

#define OG_COMPAT_RESOLVE_SYMBOL(field, name) (symbols.field = (__typeof__(symbols.field))dlsym(RTLD_DEFAULT, name))

static inline const OGCompatTextureCacheSymbols *OGCompatTextureCache(void)
{
    static OGCompatTextureCacheSymbols symbols;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        OG_COMPAT_RESOLVE_SYMBOL(createCache, "CVOpenGLESTextureCacheCreate");
        OG_COMPAT_RESOLVE_SYMBOL(createTexture, "CVOpenGLESTextureCacheCreateTextureFromImage");
        OG_COMPAT_RESOLVE_SYMBOL(flushCache, "CVOpenGLESTextureCacheFlush");
        OG_COMPAT_RESOLVE_SYMBOL(textureTarget, "CVOpenGLESTextureGetTarget");
        OG_COMPAT_RESOLVE_SYMBOL(textureName, "CVOpenGLESTextureGetName");
    });
    return &symbols;
}

#undef OG_COMPAT_RESOLVE_SYMBOL

static inline bool OGCompatTextureCacheAvailable(void)
{
    const OGCompatTextureCacheSymbols *symbols = OGCompatTextureCache();
    return symbols->createCache != NULL && symbols->createTexture != NULL && symbols->flushCache != NULL && symbols->textureTarget != NULL && symbols->textureName != NULL;
}

static inline CVReturn OGCompatTextureCacheCreate(CFAllocatorRef allocator, CFDictionaryRef cacheAttributes, EAGLContext *context, CFDictionaryRef textureAttributes, CVOpenGLESTextureCacheRef *cacheOut)
{
    const OGCompatTextureCacheSymbols *symbols = OGCompatTextureCache();
    if (symbols->createCache != NULL)
        return symbols->createCache(allocator, cacheAttributes, context, textureAttributes, cacheOut);
    if (cacheOut != NULL)
        *cacheOut = NULL;
    return -1;
}

static inline CVReturn OGCompatTextureCacheCreateTexture(CFAllocatorRef allocator, CVOpenGLESTextureCacheRef textureCache, CVImageBufferRef sourceImage, CFDictionaryRef textureAttributes, GLenum target, GLint internalFormat, GLsizei width, GLsizei height, GLenum format, GLenum type, size_t planeIndex, CVOpenGLESTextureRef *textureOut)
{
    const OGCompatTextureCacheSymbols *symbols = OGCompatTextureCache();
    if (symbols->createTexture != NULL)
        return symbols->createTexture(allocator, textureCache, sourceImage, textureAttributes, target, internalFormat, width, height, format, type, planeIndex, textureOut);
    if (textureOut != NULL)
        *textureOut = NULL;
    return -1;
}

static inline void OGCompatTextureCacheFlush(CVOpenGLESTextureCacheRef textureCache, CVOptionFlags options)
{
    const OGCompatTextureCacheSymbols *symbols = OGCompatTextureCache();
    if (symbols->flushCache != NULL)
        symbols->flushCache(textureCache, options);
}

static inline GLenum OGCompatTextureTarget(CVOpenGLESTextureRef texture)
{
    const OGCompatTextureCacheSymbols *symbols = OGCompatTextureCache();
    if (symbols->textureTarget == NULL)
        return GL_TEXTURE_2D;
    return symbols->textureTarget(texture);
}

static inline GLuint OGCompatTextureName(CVOpenGLESTextureRef texture)
{
    const OGCompatTextureCacheSymbols *symbols = OGCompatTextureCache();
    if (symbols->textureName == NULL)
        return 0;
    return symbols->textureName(texture);
}

#define CVOpenGLESTextureCacheCreate OGCompatTextureCacheCreate
#define CVOpenGLESTextureCacheCreateTextureFromImage OGCompatTextureCacheCreateTexture
#define CVOpenGLESTextureCacheFlush OGCompatTextureCacheFlush
#define CVOpenGLESTextureGetTarget OGCompatTextureTarget
#define CVOpenGLESTextureGetName OGCompatTextureName

#if defined(__cplusplus) && __IPHONE_OS_VERSION_MAX_ALLOWED <= 60100
#ifdef isinf
#undef isinf
#endif
static inline int isinf(double value)
{
    return __builtin_isinf(value);
}
#endif

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED < 50000
#ifdef __cplusplus
extern "C" {
#endif
void TGDispatchQueueSetSpecificCompat(dispatch_queue_t queue, const void *key, void *context, dispatch_function_t destructor);
void *TGDispatchGetSpecificCompat(const void *key);
#ifdef __cplusplus
}
#endif
#define dispatch_queue_set_specific(queue, key, context, destructor) TGDispatchQueueSetSpecificCompat((queue), (key), (context), (destructor))
#define dispatch_get_specific(key) TGDispatchGetSpecificCompat((key))
#endif

#import "../../../thirdparty/PSTCollectionView/PSTCollectionView/PSTCollectionView.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
#import "../../../thirdparty/PSTCollectionView/PSTCollectionView/PSTCollectionViewFlowLayout.h"

typedef PSTCollectionViewScrollDirection UICollectionViewScrollDirection;
typedef PSTCollectionViewScrollPosition UICollectionViewScrollPosition;
typedef PSTCollectionElementCategory UICollectionElementCategory;

#ifndef UICollectionViewScrollDirectionVertical
#define UICollectionViewScrollDirectionVertical PSTCollectionViewScrollDirectionVertical
#define UICollectionViewScrollDirectionHorizontal PSTCollectionViewScrollDirectionHorizontal
#endif
#ifndef UICollectionElementCategoryCell
#define UICollectionElementCategoryCell PSTCollectionElementCategoryCell
#define UICollectionElementCategorySupplementaryView PSTCollectionElementCategorySupplementaryView
#define UICollectionElementCategoryDecorationView PSTCollectionElementCategoryDecorationView
#endif
#ifndef UICollectionViewScrollPositionNone
#define UICollectionViewScrollPositionNone PSTCollectionViewScrollPositionNone
#define UICollectionViewScrollPositionTop PSTCollectionViewScrollPositionTop
#define UICollectionViewScrollPositionCenteredVertically PSTCollectionViewScrollPositionCenteredVertically
#define UICollectionViewScrollPositionBottom PSTCollectionViewScrollPositionBottom
#define UICollectionViewScrollPositionLeft PSTCollectionViewScrollPositionLeft
#define UICollectionViewScrollPositionCenteredHorizontally PSTCollectionViewScrollPositionCenteredHorizontally
#define UICollectionViewScrollPositionRight PSTCollectionViewScrollPositionRight
#endif
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
#define NSLayoutManager OGCompatLayoutManager
#define NSTextAttachment OGCompatTextAttachment
#define NSTextContainer OGCompatTextContainer
#define NSTextStorage OGCompatTextStorage
#define NSURLSession OGCompatURLSession
#define NSURLSessionConfiguration OGCompatURLSessionConfiguration
#define NSURLSessionDataTask OGCompatURLSessionDataTask
#define NSURLSessionTask OGCompatURLSessionTask
#define UIKeyCommand OGCompatKeyCommand
#define UIPercentDrivenInteractiveTransition OGCompatPercentDrivenInteractiveTransition

#define NSFontAttributeName @"NSFont"
#define NSForegroundColorAttributeName @"NSColor"
#define NSKernAttributeName @"NSKern"
#define NSParagraphStyleAttributeName @"NSParagraphStyle"
#define NSStrikethroughStyleAttributeName @"NSStrikethrough"
#define NSUnderlineStyleAttributeName @"NSUnderline"
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
#define PHAsset OGCompatPHAsset
#define PHAssetChangeRequest OGCompatPHAssetChangeRequest
#define PHAssetCollection OGCompatPHAssetCollection
#define PHCachingImageManager OGCompatPHCachingImageManager
#define PHFetchOptions OGCompatPHFetchOptions
#define PHImageManager OGCompatPHImageManager
#define PHImageRequestOptions OGCompatPHImageRequestOptions
#define PHObject OGCompatPHObject
#define PHPhotoLibrary OGCompatPHPhotoLibrary
#define PHVideoRequestOptions OGCompatPHVideoRequestOptions
#define UIAlertController OGCompatAlertController
#define UIDocumentPickerViewController OGCompatDocumentPickerViewController
#define WKFrameInfo OGCompatWKFrameInfo
#define WKNavigation OGCompatWKNavigation
#define WKNavigationAction OGCompatWKNavigationAction
#define WKNavigationDelegate OGCompatWKNavigationDelegate
#define WKPreferences OGCompatWKPreferences
#define WKScriptMessageHandler OGCompatWKScriptMessageHandler
#define WKUserContentController OGCompatWKUserContentController
#define WKUserScript OGCompatWKUserScript
#define WKWebView OGCompatWKWebView
#define WKWebViewConfiguration OGCompatWKWebViewConfiguration
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
#define CNContactFormatter OGCompatContactFormatter
#define CNContactVCardSerialization OGCompatContactVCardSerialization
#define CNLabeledValue OGCompatLabeledValue
#define CNMutableContact OGCompatMutableContact
#define CNPhoneNumber OGCompatPhoneNumber
#define PHAssetResource OGCompatPHAssetResource
#define PHAssetResourceManager OGCompatPHAssetResourceManager
#define PHLivePhotoRequestOptions OGCompatPHLivePhotoRequestOptions
#define SFSafariViewController OGCompatSafariViewController
#define SFSafariViewControllerDelegate OGCompatSafariViewControllerDelegate
#define WCSession OGCompatWCSession
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000
#define UIImpactFeedbackGenerator OGCompatImpactFeedbackGenerator
#endif

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
typedef struct
{
    double x;
    double y;
} MKMapPoint;

typedef struct
{
    double width;
    double height;
} MKMapSize;

typedef struct
{
    MKMapPoint origin;
    MKMapSize size;
} MKMapRect;

typedef NSInteger MKUserTrackingMode;
enum
{
    MKUserTrackingModeNone = 0,
    MKUserTrackingModeFollow = 1,
    MKUserTrackingModeFollowWithHeading = 2
};

#define OG_COMPAT_MAP_WORLD_SIZE 268435456.0
#define OG_COMPAT_MAP_MAX_LATITUDE 85.05112877980659

static const MKMapRect MKMapRectWorld = { { 0.0, 0.0 }, { OG_COMPAT_MAP_WORLD_SIZE, OG_COMPAT_MAP_WORLD_SIZE } };
static const MKMapRect MKMapRectNull = { { INFINITY, INFINITY }, { 0.0, 0.0 } };

static inline CLLocationCoordinate2D CLLocationCoordinate2DMake(CLLocationDegrees latitude, CLLocationDegrees longitude)
{
    CLLocationCoordinate2D result;
    result.latitude = latitude;
    result.longitude = longitude;
    return result;
}

static inline MKMapPoint MKMapPointMake(double x, double y)
{
    MKMapPoint result;
    result.x = x;
    result.y = y;
    return result;
}

static inline MKMapSize MKMapSizeMake(double width, double height)
{
    MKMapSize result;
    result.width = width;
    result.height = height;
    return result;
}

static inline MKMapRect MKMapRectMake(double x, double y, double width, double height)
{
    MKMapRect result;
    result.origin = MKMapPointMake(x, y);
    result.size = MKMapSizeMake(width, height);
    return result;
}

static inline BOOL MKMapRectIsNull(MKMapRect rect)
{
    return isinf(rect.origin.x) || isinf(rect.origin.y);
}

static inline MKMapRect MKMapRectUnion(MKMapRect first, MKMapRect second)
{
    if (MKMapRectIsNull(first))
        return second;
    if (MKMapRectIsNull(second))
        return first;

    double left = MIN(first.origin.x, second.origin.x);
    double top = MIN(first.origin.y, second.origin.y);
    double right = MAX(first.origin.x + first.size.width, second.origin.x + second.size.width);
    double bottom = MAX(first.origin.y + first.size.height, second.origin.y + second.size.height);
    return MKMapRectMake(left, top, right - left, bottom - top);
}

static inline BOOL MKMapRectContainsPoint(MKMapRect rect, MKMapPoint point)
{
    if (MKMapRectIsNull(rect))
        return NO;
    BOOL insideHorizontally = point.x >= rect.origin.x && point.x <= rect.origin.x + rect.size.width;
    BOOL insideVertically = point.y >= rect.origin.y && point.y <= rect.origin.y + rect.size.height;
    return insideHorizontally && insideVertically;
}

static inline MKMapPoint MKMapPointForCoordinate(CLLocationCoordinate2D coordinate)
{
    double latitude = MAX(-OG_COMPAT_MAP_MAX_LATITUDE, MIN(OG_COMPAT_MAP_MAX_LATITUDE, coordinate.latitude));
    double latitudeSine = sin(latitude * M_PI / 180.0);
    double mercator = log((1.0 + latitudeSine) / (1.0 - latitudeSine)) / (4.0 * M_PI);
    return MKMapPointMake((coordinate.longitude + 180.0) / 360.0 * OG_COMPAT_MAP_WORLD_SIZE, (0.5 - mercator) * OG_COMPAT_MAP_WORLD_SIZE);
}

static inline CLLocationCoordinate2D MKCoordinateForMapPoint(MKMapPoint point)
{
    double mercator = M_PI - 2.0 * M_PI * point.y / OG_COMPAT_MAP_WORLD_SIZE;
    return CLLocationCoordinate2DMake(180.0 / M_PI * atan(sinh(mercator)), point.x / OG_COMPAT_MAP_WORLD_SIZE * 360.0 - 180.0);
}

@interface MKMapView (OGCompatMapRect)

@property (nonatomic) MKUserTrackingMode userTrackingMode;
@property (nonatomic, readonly) MKMapRect visibleMapRect;

- (void)setUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated;
- (NSSet *)annotationsInMapRect:(MKMapRect)mapRect;
- (MKMapRect)mapRectThatFits:(MKMapRect)mapRect edgePadding:(UIEdgeInsets)insets;
- (void)setVisibleMapRect:(MKMapRect)mapRect animated:(BOOL)animated;
- (void)setVisibleMapRect:(MKMapRect)mapRect edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated;

@end

@interface CLLocation (OGCompatDistance)

- (CLLocationDistance)distanceFromLocation:(const CLLocation *)location;

@end
#endif

#if __has_include(<CoreText/CoreText.h>)
#import <CoreText/CoreText.h>
#else
#import "OGPlatformText.h"
#endif

#import <AVFoundation/AVFoundation.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#ifndef AVLayerVideoGravityResize
#define AVLayerVideoGravityResize kCAGravityResize
#define AVLayerVideoGravityResizeAspect kCAGravityResizeAspect
#define AVLayerVideoGravityResizeAspectFill kCAGravityResizeAspectFill
#endif

#if !__has_include(<AVFoundation/AVAsset.h>)
@interface AVAssetTrack : NSObject

@property (nonatomic, readonly) CGSize naturalSize;
@property (nonatomic, readonly) CGAffineTransform preferredTransform;
@property (nonatomic, readonly) CMTimeRange timeRange;
@property (nonatomic, readonly) float nominalFrameRate;

@end

@interface AVAsset : NSObject

@property (nonatomic, readonly) NSArray *tracks;
@property (nonatomic, readonly) CMTime duration;

+ (instancetype)assetWithURL:(NSURL *)URL;
- (NSArray *)tracksWithMediaType:(NSString *)mediaType;

@end

@interface AVURLAsset : AVAsset

@property (nonatomic, readonly, copy) NSURL *URL;

+ (instancetype)URLAssetWithURL:(NSURL *)URL options:(NSDictionary *)options;
- (instancetype)initWithURL:(NSURL *)URL options:(NSDictionary *)options;

@end
#endif

#if !__has_include(<AVFoundation/AVCaptureSession.h>)
typedef NSInteger AVCaptureFocusMode;
typedef NSInteger AVCaptureExposureMode;
typedef NSInteger AVCaptureDevicePosition;
typedef NSInteger AVCaptureFlashMode;
typedef NSInteger AVCaptureTorchMode;

#ifndef AVCaptureFocusModeLocked
#define AVCaptureFocusModeLocked 0
#define AVCaptureFocusModeAutoFocus 1
#define AVCaptureFocusModeContinuousAutoFocus 2
#endif
#ifndef AVCaptureExposureModeLocked
#define AVCaptureExposureModeLocked 0
#define AVCaptureExposureModeAutoExpose 1
#define AVCaptureExposureModeContinuousAutoExposure 2
#endif
#ifndef AVCaptureDevicePositionUnspecified
#define AVCaptureDevicePositionUnspecified 0
#define AVCaptureDevicePositionBack 1
#define AVCaptureDevicePositionFront 2
#endif
#ifndef AVCaptureFlashModeOff
#define AVCaptureFlashModeOff 0
#define AVCaptureFlashModeOn 1
#define AVCaptureFlashModeAuto 2
#endif
#ifndef AVCaptureTorchModeOff
#define AVCaptureTorchModeOff 0
#define AVCaptureTorchModeOn 1
#define AVCaptureTorchModeAuto 2
#endif

@class AVCaptureAudioDataOutput;
@class AVCaptureConnection;
@class AVCaptureDeviceFormat;
@class AVCaptureDeviceInput;
@class AVCaptureInput;
@class AVCaptureOutput;
@class AVCaptureStillImageOutput;
@class AVCaptureVideoDataOutput;
@class AVCaptureVideoPreviewLayer;
@class AVFrameRateRange;

@protocol AVCaptureVideoDataOutputSampleBufferDelegate <NSObject>
@end

@protocol AVCaptureAudioDataOutputSampleBufferDelegate <NSObject>
@end

@interface AVCaptureSession : NSObject

@property (nonatomic, copy) NSString *sessionPreset;
@property (nonatomic, readonly, getter=isRunning) BOOL running;

- (void)beginConfiguration;
- (void)commitConfiguration;
- (BOOL)canAddInput:(AVCaptureInput *)input;
- (void)addInput:(AVCaptureInput *)input;
- (void)removeInput:(AVCaptureInput *)input;
- (BOOL)canAddOutput:(AVCaptureOutput *)output;
- (void)addOutput:(AVCaptureOutput *)output;
- (void)removeOutput:(AVCaptureOutput *)output;
- (void)startRunning;
- (void)stopRunning;

@end
#endif
#endif

#if __has_include(<AVFoundation/AVCaptureOutput.h>)
static inline AVCaptureConnection *OGCompatCaptureConnection(AVCaptureOutput *output, NSString *mediaType)
{
    for (AVCaptureConnection *connection in output.connections)
    {
        for (AVCaptureInputPort *port in connection.inputPorts)
        {
            if ([port.mediaType isEqualToString:mediaType])
                return connection;
        }
    }
    return nil;
}
#endif

@interface NSArray (OGCompatBoundaryObjects)

@property (nonatomic, readonly) id firstObject;
@property (nonatomic, readonly) id lastObject;

@end

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../WebKit/WebKit.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@interface CALayer (OGCompatRasterization)

- (void)setShouldRasterize:(BOOL)shouldRasterize;
- (void)setRasterizationScale:(CGFloat)rasterizationScale;
- (void)setContentsScale:(CGFloat)contentsScale;

@end

#define OG_COMPAT_LAYER_SETTER(layer, selectorName, valueType, value) \
    do \
    { \
        SEL setterSelector = @selector(selectorName); \
        if ([(layer) respondsToSelector:setterSelector]) \
            ((void (*)(id, SEL, valueType))[(layer) methodForSelector:setterSelector])((layer), setterSelector, (value)); \
    } while (0)
#endif

static inline void OGCompatLayerSetShouldRasterize(CALayer *layer, BOOL shouldRasterize)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    OG_COMPAT_LAYER_SETTER(layer, setShouldRasterize:, BOOL, shouldRasterize);
#else
    layer.shouldRasterize = shouldRasterize;
#endif
}

static inline void OGCompatLayerSetRasterizationScale(CALayer *layer, CGFloat rasterizationScale)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    OG_COMPAT_LAYER_SETTER(layer, setRasterizationScale:, CGFloat, rasterizationScale);
#else
    layer.rasterizationScale = rasterizationScale;
#endif
}

static inline void OGCompatLayerSetContentsScale(CALayer *layer, CGFloat contentsScale)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    OG_COMPAT_LAYER_SETTER(layer, setContentsScale:, CGFloat, contentsScale);
#else
    layer.contentsScale = contentsScale;
#endif
}

#ifndef TG_ENABLE_AUDIO_NOTES
#define TG_ENABLE_AUDIO_NOTES 1
#endif

#ifndef NSCalendarIdentifierGregorian
#define NSCalendarIdentifierGregorian NSGregorianCalendar
#endif

#ifndef NSCalendarUnitEra
#define NSCalendarUnitCalendar NSCalendarCalendarUnit
#define NSCalendarUnitDay NSDayCalendarUnit
#define NSCalendarUnitEra NSEraCalendarUnit
#define NSCalendarUnitHour NSHourCalendarUnit
#define NSCalendarUnitMinute NSMinuteCalendarUnit
#define NSCalendarUnitMonth NSMonthCalendarUnit
#define NSCalendarUnitNanosecond NSNanosecondCalendarUnit
#define NSCalendarUnitQuarter NSQuarterCalendarUnit
#define NSCalendarUnitSecond NSSecondCalendarUnit
#define NSCalendarUnitTimeZone NSTimeZoneCalendarUnit
#define NSCalendarUnitWeekOfMonth NSWeekOfMonthCalendarUnit
#define NSCalendarUnitWeekOfYear NSWeekOfYearCalendarUnit
#define NSCalendarUnitWeekday NSWeekdayCalendarUnit
#define NSCalendarUnitWeekdayOrdinal NSWeekdayOrdinalCalendarUnit
#define NSCalendarUnitYear NSYearCalendarUnit
#define NSCalendarUnitYearForWeekOfYear NSYearForWeekOfYearCalendarUnit
#endif

#ifndef NSUnderlinePatternSolid
#define NSUnderlinePatternSolid 0x0000
#define NSUnderlinePatternDot 0x0100
#define NSUnderlinePatternDash 0x0200
#define NSUnderlinePatternDashDot 0x0300
#define NSUnderlinePatternDashDotDot 0x0400
#endif

@class NSUserActivity;
@class TGLocalization;
@class UIApplicationShortcutItem;

#ifdef __cplusplus
extern "C" {
#endif

extern int TGLocalizedStaticVersion;

NSString *TGLocalized(NSString *s);
TGLocalization *legacyEffectiveLocalization();
TGLocalization *effectiveLocalization();
TGLocalization *currentNativeLocalization();
NSString *currentNativeLocalizationCode();
TGLocalization *nativeEnglishLocalization(void);
TGLocalization *currentCustomLocalization();
void setCurrentCustomLocalization(TGLocalization *localization);

NSString *TGEncodeText(NSString *string, int key);
NSString *TGStringMD5(NSString *string);
NSArray *TGGetLogFilePaths(int count);
NSURL *TGFileURLWithPathRelativeToURL(NSString *path, NSURL *baseURL);
bool TGObjectCompare(id obj1, id obj2);
bool TGStringCompare(NSString *s1, NSString *s2);

int cpuCoreCount();
int iosMajorVersion();
int iosMinorVersion();

void TGDispatchOnMainThread(dispatch_block_t block);
void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block);

UIColor *TGSelectionColor();
UIColor *TGAccentColor(void);
UIColor *TGDestructiveAccentColor(void);
UIColor *TGSeparatorColor();

#undef TGLog
#undef TGLogv
void TGLog(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));
void TGLogv(NSString *format, va_list args) __attribute__((format(__NSString__, 1, 0)));
#if !defined(ONEGRAM_LOG_IMPLEMENTATION)
#define TGLog(...) (OGDiagnosticsEnabled() ? TGLog(__VA_ARGS__) : (void)0)
#define TGLogv(...) (OGDiagnosticsEnabled() ? TGLogv(__VA_ARGS__) : (void)0)
#endif
void TGDiagnosticLog(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));
#undef TGLegacyLog
void TGLegacyLog(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));
#if !defined(ONEGRAM_LOG_IMPLEMENTATION)
#define TGLegacyLog(...) (OGDiagnosticsEnabled() ? TGLegacyLog(__VA_ARGS__) : (void)0)
#endif

#ifdef __cplusplus
}
#endif

#ifndef UIColorRGB
#define UIColorRGB(rgb) ([[UIColor alloc] initWithRed:((((rgb) >> 16) & 0xff) / 255.0f) green:((((rgb) >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:1.0f])
#endif
#ifndef UIColorRGBA
#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:((((rgb) >> 16) & 0xff) / 255.0f) green:((((rgb) >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:(a)])
#endif

#ifndef CGFloor
#ifdef __LP64__
#define CGCeil ceil
#define CGCos cos
#define CGFloor floor
#define CGPow pow
#define CGRound round
#define CGSin sin
#define CGSqrt sqrt
#else
#define CGCeil ceilf
#define CGCos cosf
#define CGFloor floorf
#define CGPow powf
#define CGRound roundf
#define CGSin sinf
#define CGSqrt sqrtf
#endif
#endif

#ifndef CGEven
#define CGEven(x) ((((int)x) & 1) ? (x + 1) : x)
#endif
#ifndef CGOdd
#define CGOdd(x) ((((int)x) & 1) ? x : (x + 1))
#endif

static inline CTFontRef OGCompatCreateCTFont(UIFont *font)
{
    return CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000

#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#endif
#ifndef NS_DESIGNATED_INITIALIZER
#define NS_DESIGNATED_INITIALIZER
#endif
#ifndef nullable
#define nullable
#endif
#ifndef null_unspecified
#define null_unspecified
#endif
#ifndef __nullable
#define __nullable
#endif
#ifndef __nonnull
#define __nonnull
#endif
#ifndef _Nullable
#define _Nullable
#endif
#ifndef _Nonnull
#define _Nonnull
#endif
#ifndef _Null_unspecified
#define _Null_unspecified
#endif

typedef NSInteger UIImpactFeedbackStyle;
typedef NSInteger UINotificationFeedbackType;
typedef NSInteger UIScrollViewKeyboardDismissMode;

#ifndef UIImpactFeedbackStyleLight
#define UIImpactFeedbackStyleLight 0
#define UIImpactFeedbackStyleMedium 1
#define UIImpactFeedbackStyleHeavy 2
#endif
#ifndef UINotificationFeedbackTypeSuccess
#define UINotificationFeedbackTypeSuccess 0
#define UINotificationFeedbackTypeWarning 1
#define UINotificationFeedbackTypeError 2
#endif
#ifndef UIScrollViewKeyboardDismissModeNone
#define UIScrollViewKeyboardDismissModeNone 0
#define UIScrollViewKeyboardDismissModeOnDrag 1
#define UIScrollViewKeyboardDismissModeInteractive 2
#endif

@interface UIImpactFeedbackGenerator : NSObject

- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)prepare;
- (void)impactOccurred;

@end

@interface UISelectionFeedbackGenerator : NSObject

- (void)prepare;
- (void)selectionChanged;

@end

@interface UINotificationFeedbackGenerator : NSObject

- (void)prepare;
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType;

@end

@interface UIScrollView (OGCompatKeyboardDismiss)

@property (nonatomic) UIScrollViewKeyboardDismissMode keyboardDismissMode;

@end

#ifndef PKAddressFieldNone
typedef NSUInteger PKAddressField;
#define PKAddressFieldNone 0
#define PKAddressFieldPostalAddress 1
#define PKAddressFieldPhone 2
#define PKAddressFieldEmail 4
#define PKAddressFieldName 8
#endif
#ifndef PKMerchantCapability3DS
typedef NSUInteger PKMerchantCapability;
#define PKMerchantCapability3DS 1
#define PKMerchantCapabilityEMV 2
#endif
#ifndef PKPaymentAuthorizationStatusSuccess
typedef NSInteger PKPaymentAuthorizationStatus;
#define PKPaymentAuthorizationStatusSuccess 0
#define PKPaymentAuthorizationStatusFailure 1
#endif

static NSString *const PKPaymentNetworkAmex = @"AmEx";
static NSString *const PKPaymentNetworkDiscover = @"Discover";
static NSString *const PKPaymentNetworkMasterCard = @"MasterCard";
static NSString *const PKPaymentNetworkVisa = @"Visa";

@class PKPayment;
@class PKPaymentRequest;
@class PKPaymentSummaryItem;
@class PKShippingMethod;
@protocol PKPaymentAuthorizationViewControllerDelegate;

@interface PKPayment : NSObject

@property (nonatomic, readonly) NSString *transactionIdentifier;
@property (nonatomic, readonly) id token;

@end

@interface PKPaymentRequest : NSObject

@property (nonatomic, copy) NSString *merchantIdentifier;
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, copy) NSString *currencyCode;
@property (nonatomic, copy) NSArray *supportedNetworks;
@property (nonatomic) PKMerchantCapability merchantCapabilities;
@property (nonatomic) PKAddressField requiredShippingAddressFields;
@property (nonatomic) PKAddressField requiredBillingAddressFields;
@property (nonatomic, copy) NSArray *paymentSummaryItems;
@property (nonatomic, copy) NSArray *shippingMethods;

@end

@interface PKPaymentSummaryItem : NSObject

@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSDecimalNumber *amount;

+ (instancetype)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount;

@end

@interface PKShippingMethod : PKPaymentSummaryItem
@end

@interface PKPaymentAuthorizationViewController : UIViewController

@property (nonatomic, assign) id<PKPaymentAuthorizationViewControllerDelegate> delegate;

+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)supportedNetworks;
- (instancetype)initWithPaymentRequest:(PKPaymentRequest *)paymentRequest;

@end

@protocol PKPaymentAuthorizationViewControllerDelegate <NSObject>

@optional
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment completion:(void (^)(PKPaymentAuthorizationStatus status))completion;
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller;

@end

typedef void (^NSURLSessionDataTaskCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

@interface NSURLSessionTask : NSObject

- (void)resume;
- (void)cancel;

@end

@interface NSURLSessionDataTask : NSURLSessionTask
@end

@interface NSURLSessionConfiguration : NSObject

@property (nonatomic, copy) NSDictionary *HTTPAdditionalHeaders;

+ (instancetype)defaultSessionConfiguration;

@end

@interface NSURLSession : NSObject

+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(NSURLSessionDataTaskCompletionHandler)completionHandler;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(NSURLSessionDataTaskCompletionHandler)completionHandler;
- (void)invalidateAndCancel;

@end

@interface SSReadingList : NSObject

+ (instancetype)defaultReadingList;
- (BOOL)addReadingListItemWithURL:(NSURL *)URL title:(NSString *)title previewText:(NSString *)previewText error:(NSError **)error;

@end

@interface NSObject (OGCompatOptionalSelectors)

- (id)defaultReadingList;
- (BOOL)addReadingListItemWithURL:(NSURL *)url title:(NSString *)title previewText:(NSString *)previewText error:(NSError **)error;
- (void)setEffect:(id)effect;
- (id)effectWithStyle:(NSInteger)style;
- (id)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount;
- (NSDecimalNumber *)amount;
- (BOOL)canMakePaymentsUsingNetworks:(NSArray *)supportedNetworks;
- (UIEdgeInsets)textContainerInset;
- (void)setTextContainerInset:(UIEdgeInsets)inset;

@end

@protocol UIViewControllerTransitionCoordinatorContext <NSObject>
@end

@protocol UIViewControllerTransitionCoordinator <NSObject>

- (BOOL)isCancelled;
- (void)animateAlongsideTransition:(void (^)(id<UIViewControllerTransitionCoordinatorContext> context))animation completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext> context))completion;

@end

typedef NSInteger UISemanticContentAttribute;

#ifndef UISemanticContentAttributeUnspecified
#define UISemanticContentAttributeUnspecified 0
#define UISemanticContentAttributePlayback 1
#define UISemanticContentAttributeSpatial 2
#define UISemanticContentAttributeForceLeftToRight 3
#define UISemanticContentAttributeForceRightToLeft 4
#endif

#ifndef NSAttachmentAttributeName
#define NSAttachmentAttributeName @"NSAttachment"
#endif
#ifndef NSAttachmentCharacter
#define NSAttachmentCharacter ((unichar)0xfffc)
#endif
#ifndef UIKeyboardAppearanceDark
#define UIKeyboardAppearanceDark UIKeyboardAppearanceAlert
#endif
#ifndef UIInterfaceOrientationUnknown
#define UIInterfaceOrientationUnknown ((UIInterfaceOrientation)0)
#endif

#ifndef UIUserInterfaceSizeClassUnspecified
typedef NSInteger UIUserInterfaceSizeClass;
#define UIUserInterfaceSizeClassUnspecified 0
#define UIUserInterfaceSizeClassCompact 1
#define UIUserInterfaceSizeClassRegular 2
#endif

#ifndef UIKeyInputUpArrow
#define UIKeyInputUpArrow @"\uF700"
#define UIKeyInputDownArrow @"\uF701"
#define UIKeyInputLeftArrow @"\uF702"
#define UIKeyInputRightArrow @"\uF703"
#endif
#ifndef UIKeyInputEscape
#define UIKeyInputEscape @"\033"
#endif

#ifndef UIKeyModifierAlphaShift
typedef NSUInteger UIKeyModifierFlags;
#define UIKeyModifierAlphaShift (1 << 16)
#define UIKeyModifierShift (1 << 17)
#define UIKeyModifierControl (1 << 18)
#define UIKeyModifierAlternate (1 << 19)
#define UIKeyModifierCommand (1 << 20)
#define UIKeyModifierNumericPad (1 << 21)

@interface UIKeyCommand : NSObject

@property (nonatomic, readonly) NSString *input;
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags;

+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action;

@end
#endif

@protocol CAAnimationDelegate;
@class NSTextContainer;

@interface NSTextAttachment : NSObject

- (instancetype)initWithData:(NSData *)contentData ofType:(NSString *)uti;
- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)lineFrag glyphPosition:(CGPoint)position characterIndex:(NSUInteger)charIndex;

@end

@interface NSLayoutManager : NSObject

@property (nonatomic) BOOL allowsNonContiguousLayout;

- (void)addTextContainer:(NSTextContainer *)container;
- (void)showCGGlyphs:(const CGGlyph *)glyphs positions:(const CGPoint *)positions count:(NSUInteger)glyphCount font:(UIFont *)font matrix:(CGAffineTransform)textMatrix attributes:(NSDictionary *)attributes inContext:(CGContextRef)context;

@end

@interface NSTextStorage : NSMutableAttributedString

- (void)addLayoutManager:(NSLayoutManager *)layoutManager;

@end

@interface NSTextContainer : NSObject

@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic) BOOL widthTracksTextView;

- (instancetype)initWithSize:(CGSize)size;

@end

@interface UITextView (OGCompatTextKit)

@property (nonatomic, copy) NSAttributedString *attributedText;
@property (nonatomic) BOOL allowsEditingTextAttributes;
@property (nonatomic, readonly) NSLayoutManager *layoutManager;
@property (nonatomic, readonly) NSTextContainer *textContainer;
@property (nonatomic, readonly) NSTextStorage *textStorage;
@property (nonatomic, getter=isSelectable) BOOL selectable;
@property (nonatomic) UIEdgeInsets textContainerInset;

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer;

@end

#define UIScreenEdgePanGestureRecognizer UIPanGestureRecognizer

#ifndef UIModalPresentationPopover
#define UIModalPresentationPopover ((UIModalPresentationStyle)7)
#endif

@interface UINavigationController (OGCompatInteractivePop)

@property (nonatomic, readonly) UIGestureRecognizer *interactivePopGestureRecognizer;

@end

@interface UINavigationBar (OGCompatLargeTitles)

@property (nonatomic) BOOL prefersLargeTitles;

@end

@interface UIPercentDrivenInteractiveTransition : NSObject

@property (nonatomic, readonly) CGFloat percentComplete;

- (void)updateInteractiveTransition:(CGFloat)percentComplete;
- (void)cancelInteractiveTransition;
- (void)finishInteractiveTransition;

@end

#ifndef __IPHONE_9_0
typedef NSInteger UIDocumentPickerMode;
typedef NSInteger UIPreviewActionStyle;

#ifndef UIDocumentPickerModeOpen
#define UIDocumentPickerModeImport 0
#define UIDocumentPickerModeOpen 1
#define UIDocumentPickerModeExportToService 2
#define UIDocumentPickerModeMoveToService 3
#endif
#ifndef UIPreviewActionStyleDefault
#define UIPreviewActionStyleDefault 0
#define UIPreviewActionStyleSelected 1
#define UIPreviewActionStyleDestructive 2
#endif

@protocol UIViewControllerPreviewingDelegate <NSObject>
@end

@class UIDocumentPickerViewController;

@protocol UIDocumentPickerDelegate <NSObject>

@optional
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url;
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray *)urls;
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller;

@end

@interface UIDocumentPickerViewController : UIViewController

@property (nonatomic, assign) id<UIDocumentPickerDelegate> delegate;

- (instancetype)initWithDocumentTypes:(NSArray *)allowedUTIs inMode:(UIDocumentPickerMode)mode;

@end

@protocol UIPreviewActionItem <NSObject>
@end

@interface UIPreviewAction : NSObject <UIPreviewActionItem>

+ (instancetype)actionWithTitle:(NSString *)title style:(UIPreviewActionStyle)style handler:(void (^)(UIPreviewAction *action, UIViewController *previewViewController))handler;

@end
#endif

#ifndef UIForceTouchCapabilityAvailable
typedef NSInteger UIForceTouchCapability;
#define UIForceTouchCapabilityUnknown 0
#define UIForceTouchCapabilityUnavailable 1
#define UIForceTouchCapabilityAvailable 2

@interface UITraitCollection : NSObject

@property (nonatomic, readonly) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, readonly) UIUserInterfaceSizeClass horizontalSizeClass;

@end

@protocol UIViewControllerPreviewing <NSObject>

@property (nonatomic) CGRect sourceRect;
@property (nonatomic, retain) UIView *sourceView;

@end

@interface UIViewController (OGCompatTraits)

@property (nonatomic, readonly) id topLayoutGuide;
@property (nonatomic, readonly) id bottomLayoutGuide;
@property (nonatomic) CGSize preferredContentSize;
@property (nonatomic, readonly) UITraitCollection *traitCollection;

- (UIStatusBarStyle)preferredStatusBarStyle;
- (id)registerForPreviewingWithDelegate:(id)delegate sourceView:(UIView *)sourceView;
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection;

@end
#endif

@interface AVAudioSession (OGCompatInputs)

@property (nonatomic, readonly) NSArray *availableInputs;

- (void)requestRecordPermission:(void (^)(BOOL granted))response;

@end

@interface CLLocationManager (OGCompatAuthorization)

@property (nonatomic) BOOL allowsBackgroundLocationUpdates;

- (void)requestAlwaysAuthorization;
- (void)requestWhenInUseAuthorization;
- (void)requestLocation;

@end

#ifndef UIViewKeyframeAnimationOptionCalculationModeLinear
typedef NSUInteger UIViewKeyframeAnimationOptions;
#define UIViewKeyframeAnimationOptionCalculationModeLinear 0
#endif

@interface UIView (OGCompatModernView)

@property (nonatomic) BOOL accessibilityIgnoresInvertColors;
@property (nonatomic) UISemanticContentAttribute semanticContentAttribute;
@property (nonatomic, retain) UIColor *tintColor;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;

+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)performWithoutAnimation:(void (^)(void))actionsWithoutAnimation;
+ (void)animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewKeyframeAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)addKeyframeWithRelativeStartTime:(double)frameStartTime relativeDuration:(double)frameDuration animations:(void (^)(void))animations;

- (UIView *)snapshotViewAfterScreenUpdates:(BOOL)afterUpdates;
- (UIView *)resizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates withCapInsets:(UIEdgeInsets)capInsets;
- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates;

@end

typedef NSUInteger NSDataBase64DecodingOptions;
typedef NSUInteger NSDataBase64EncodingOptions;

#ifndef NSDataBase64DecodingIgnoreUnknownCharacters
#define NSDataBase64DecodingIgnoreUnknownCharacters 1
#endif

@interface NSData (OGCompatBase64)

- (instancetype)initWithBase64EncodedString:(NSString *)base64String options:(NSDataBase64DecodingOptions)options;
- (instancetype)initWithBase64Encoding:(NSString *)base64String;
- (NSString *)base64Encoding;

@end

typedef NSUInteger UIRectEdge;
typedef NSInteger UIAlertActionStyle;

#ifndef UIRectEdgeNone
#define UIRectEdgeNone 0
#define UIRectEdgeTop (1 << 0)
#define UIRectEdgeLeft (1 << 1)
#define UIRectEdgeBottom (1 << 2)
#define UIRectEdgeRight (1 << 3)
#define UIRectEdgeAll 15
#endif
#ifndef UIStatusBarStyleLightContent
#define UIStatusBarStyleLightContent ((UIStatusBarStyle)1)
#endif
#ifndef UIAlertActionStyleDefault
#define UIAlertActionStyleDefault 0
#define UIAlertActionStyleCancel 1
#define UIAlertActionStyleDestructive 2
#endif

@interface UIAlertController : UIViewController
@end

@interface UIAlertAction : NSObject

+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler;

@end

@class UIPopoverPresentationController;

@interface UIViewController (OGCompatModernController)

@property (nonatomic, readonly) id<UIViewControllerTransitionCoordinator> transitionCoordinator;
@property (nonatomic, readonly) UIPopoverPresentationController *popoverPresentationController;

- (BOOL)prefersStatusBarHidden;
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures;
- (void)setNeedsStatusBarAppearanceUpdate;
- (void)setNeedsUpdateOfHomeIndicatorAutoHidden;
- (NSArray *)previewActionItems;
- (void)loadViewIfNeeded;
- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)value;

@end

typedef void (^UICollectionViewLayoutInteractiveTransitionCompletion)(BOOL completed, BOOL finish);
typedef NSInteger UIScrollViewContentInsetAdjustmentBehavior;

#ifndef UIScrollViewContentInsetAdjustmentNever
#define UIScrollViewContentInsetAdjustmentNever 2
#endif

@interface UIScrollView (OGCompatContentInsetAdjustment)

@property (nonatomic) UIScrollViewContentInsetAdjustmentBehavior contentInsetAdjustmentBehavior;

@end

@interface NSCharacterSet (OGCompatURLCharacters)

+ (NSCharacterSet *)URLQueryAllowedCharacterSet;

@end

#ifndef NSStringDrawingUsesLineFragmentOrigin
#define NSStringDrawingUsesLineFragmentOrigin (1 << 0)
#define NSStringDrawingUsesFontLeading (1 << 1)
#define NSStringDrawingUsesDeviceMetrics (1 << 3)
#define NSStringDrawingTruncatesLastVisibleLine (1 << 5)
#endif

@interface NSString (OGCompatAttributedDrawing)

- (CGSize)sizeWithAttributes:(NSDictionary *)attrs;
- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary *)attrs;
- (void)drawWithRect:(CGRect)rect options:(NSInteger)options attributes:(NSDictionary *)attributes context:(id)context;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(id)context;
- (NSString *)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet *)allowedCharacters;

@end

@interface NSAttributedString (OGCompatAttributedDrawing)

- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options context:(id)context;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options context:(id)context;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(id)context;

@end

typedef NSUInteger UIBackgroundFetchResult;

#ifndef UIBackgroundFetchResultNewData
#define UIBackgroundFetchResultNewData 0
#define UIBackgroundFetchResultNoData 1
#define UIBackgroundFetchResultFailed 2
#endif

@interface UIUserNotificationSettings : NSObject
@end

@interface UIApplication (OGCompatRemoteNotifications)

- (void)registerForRemoteNotifications;

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
@interface UILocalNotification (OGCompatCategory)

@property (nonatomic, copy) NSString *category;

@end
#endif

@interface NSUserDefaults (OGCompatSuite)

- (instancetype)initWithSuiteName:(NSString *)suiteName;

@end

@interface NSFileManager (OGCompatAppGroups)

- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;

@end

#ifndef UIApplicationOpenURLOptionsSourceApplicationKey
#define UIApplicationOpenURLOptionsSourceApplicationKey UIApplicationLaunchOptionsSourceApplicationKey
#endif

@protocol UIPopoverPresentationControllerDelegate <NSObject>

@optional
- (void)popoverPresentationController:(UIPopoverPresentationController *)popoverPresentationController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view;
- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController;

@end

@interface UIPopoverPresentationController : NSObject

@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, assign) id<UIPopoverPresentationControllerDelegate> delegate;
@property (nonatomic) UIPopoverArrowDirection permittedArrowDirections;
@property (nonatomic, retain) UIBarButtonItem *barButtonItem;
@property (nonatomic, retain) UIView *sourceView;
@property (nonatomic) CGRect sourceRect;

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 30200
@interface UIPopoverController (OGCompatBackgroundColor)

@property (nonatomic, retain) UIColor *backgroundColor;

@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
@interface UIActivityViewController (OGCompatPopover)

@property (nonatomic, readonly) UIPopoverPresentationController *popoverPresentationController;

@end
#endif

@interface UITableView (OGCompatSeparatorInset)

@property (nonatomic) UIEdgeInsets separatorInset;

@end

#ifndef kCLAuthorizationStatusAuthorizedWhenInUse
#define kCLAuthorizationStatusAuthorizedWhenInUse kCLAuthorizationStatusAuthorized
#endif
#ifndef kCLAuthorizationStatusAuthorizedAlways
#define kCLAuthorizationStatusAuthorizedAlways kCLAuthorizationStatusAuthorized
#endif

#ifndef UIApplicationUserDidTakeScreenshotNotification
#define UIApplicationUserDidTakeScreenshotNotification @"UIApplicationUserDidTakeScreenshotNotification"
#endif

#ifndef TG_TIMESTAMP_DEFINE
#define TG_TIMESTAMP_DEFINE(s)
#endif
#ifndef TG_TIMESTAMP_MEASURE
#define TG_TIMESTAMP_MEASURE(s)
#endif

typedef NSInteger AVAuthorizationStatus;

#ifndef AVAuthorizationStatusNotDetermined
#define AVAuthorizationStatusNotDetermined 0
#define AVAuthorizationStatusRestricted 1
#define AVAuthorizationStatusDenied 2
#define AVAuthorizationStatusAuthorized 3
#endif

#if __has_include(<AVFoundation/AVPlayer.h>)
@interface AVPlayer (OGCompatMuting)

@property (nonatomic, getter=isMuted) BOOL muted;

@end
#endif

#if __has_include(<AVFoundation/AVCaptureDevice.h>)
@interface AVCaptureDevice (OGCompatAuthorization)

+ (AVAuthorizationStatus)authorizationStatusForMediaType:(NSString *)mediaType;
+ (void)requestAccessForMediaType:(NSString *)mediaType completionHandler:(void (^)(BOOL granted))handler;

@end
#endif

#ifndef AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps
typedef NSInteger AVCaptureSessionInterruptionReason;
#define AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps 1
#define AVCaptureSessionInterruptionReasonKey @"AVCaptureSessionInterruptionReasonKey"
#endif

#endif

#endif
#endif
