#ifndef TG_LEGACY_IOS6_COMPAT_OBJC_GUARD
#define TG_LEGACY_IOS6_COMPAT_OBJC_GUARD
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <math.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#define NSAttributedString TGIOS3AttributedString
#define NSMutableAttributedString TGIOS3MutableAttributedString
@class AVCaptureConnection;
@class AVCaptureOutput;
@class AVCaptureInputPort;
@class AVCaptureDevice;
@class AVPlayer;
@class AVAsset;
@class AVAudioSession;
@class UIGestureRecognizer;
@class UIPopoverController;
typedef NSInteger UIUserInterfaceLayoutDirection;
#ifndef UIUserInterfaceLayoutDirectionLeftToRight
#define UIUserInterfaceLayoutDirectionLeftToRight 0
#define UIUserInterfaceLayoutDirectionRightToLeft 1
#endif
typedef NSUInteger UIViewAnimationOptions;
typedef NSUInteger NSStringDrawingOptions;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
typedef NSUInteger UIPopoverArrowDirection;
#endif
typedef NSInteger UIStatusBarAnimation;
typedef NSInteger AVCaptureVideoOrientation;
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
typedef struct {
    CMTimeValue value;
    CMTimeScale timescale;
    CMTimeFlags flags;
    CMTimeEpoch epoch;
} CMTime;
typedef struct {
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
#ifndef CMTIME_IS_VALID
#define CMTIME_IS_VALID(time) (((time).flags & kCMTimeFlags_Valid) != 0)
#endif
#ifndef CMTIME_IS_POSITIVE_INFINITY
#define CMTIME_IS_POSITIVE_INFINITY(time) (CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_PositiveInfinity) != 0))
#endif
#ifndef CMTIME_IS_NEGATIVE_INFINITY
#define CMTIME_IS_NEGATIVE_INFINITY(time) (CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_NegativeInfinity) != 0))
#endif
#ifndef CMTIME_IS_INDEFINITE
#define CMTIME_IS_INDEFINITE(time) (CMTIME_IS_VALID(time) && (((time).flags & kCMTimeFlags_Indefinite) != 0))
#endif
#ifndef CMTIME_IS_NUMERIC
#define CMTIME_IS_NUMERIC(time) (CMTIME_IS_VALID(time) && !CMTIME_IS_POSITIVE_INFINITY(time) && !CMTIME_IS_NEGATIVE_INFINITY(time) && !CMTIME_IS_INDEFINITE(time) && (time).timescale != 0)
#endif
static const CMTime kCMTimeZero = {0, 1, kCMTimeFlags_Valid, 0};
static const CMTime kCMTimeInvalid = {0, 0, 0, 0};
static const CMTime kCMTimeIndefinite = {0, 0, kCMTimeFlags_Valid | kCMTimeFlags_Indefinite, 0};
static inline CMTime CMTimeMake(CMTimeValue value, CMTimeScale timescale) { CMTime t = {value, timescale, kCMTimeFlags_Valid, 0}; return t; }
static inline CMTime CMTimeMakeWithSeconds(double seconds, int32_t preferredTimescale) { return CMTimeMake((CMTimeValue)(seconds * preferredTimescale), preferredTimescale); }
static inline double CMTimeGetSeconds(CMTime time) { return time.timescale == 0 ? 0.0 : (double)time.value / (double)time.timescale; }
static inline CMTimeRange CMTimeRangeMake(CMTime start, CMTime duration) { CMTimeRange range = {start, duration}; return range; }
static inline CMTime CMTimeRangeGetEnd(CMTimeRange range) { return CMTimeMakeWithSeconds(CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration), range.start.timescale != 0 ? range.start.timescale : range.duration.timescale); }
static inline int32_t CMTimeCompare(CMTime a, CMTime b) { double av = CMTimeGetSeconds(a), bv = CMTimeGetSeconds(b); return av < bv ? -1 : (av > bv ? 1 : 0); }
static inline CMTime CMTimeAdd(CMTime a, CMTime b) { CMTimeScale scale = a.timescale != 0 ? a.timescale : (b.timescale != 0 ? b.timescale : 1); return CMTimeMakeWithSeconds(CMTimeGetSeconds(a) + CMTimeGetSeconds(b), scale); }
static inline CMTime CMTimeSubtract(CMTime a, CMTime b) { CMTimeScale scale = a.timescale != 0 ? a.timescale : (b.timescale != 0 ? b.timescale : 1); return CMTimeMakeWithSeconds(CMTimeGetSeconds(a) - CMTimeGetSeconds(b), scale); }
#endif
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <dlfcn.h>

static inline void *TGIOS4CoreVideoSymbol(const char *name)
{
    return dlsym(RTLD_DEFAULT, name);
}

static inline bool TGIOS4CVOpenGLESTextureCacheAvailable(void)
{
    return TGIOS4CoreVideoSymbol("CVOpenGLESTextureCacheCreate") != NULL && TGIOS4CoreVideoSymbol("CVOpenGLESTextureCacheCreateTextureFromImage") != NULL && TGIOS4CoreVideoSymbol("CVOpenGLESTextureCacheFlush") != NULL && TGIOS4CoreVideoSymbol("CVOpenGLESTextureGetTarget") != NULL && TGIOS4CoreVideoSymbol("CVOpenGLESTextureGetName") != NULL;
}

static inline CVReturn TGIOS4CVOpenGLESTextureCacheCreate(CFAllocatorRef allocator, CFDictionaryRef cacheAttributes, EAGLContext *context, CFDictionaryRef textureAttributes, CVOpenGLESTextureCacheRef *cacheOut)
{
    typedef CVReturn (*Function)(CFAllocatorRef, CFDictionaryRef, EAGLContext *, CFDictionaryRef, CVOpenGLESTextureCacheRef *);
    Function function = (Function)TGIOS4CoreVideoSymbol("CVOpenGLESTextureCacheCreate");
    if (function == NULL)
    {
        if (cacheOut != NULL)
            *cacheOut = NULL;
        return -1;
    }
    return function(allocator, cacheAttributes, context, textureAttributes, cacheOut);
}

static inline CVReturn TGIOS4CVOpenGLESTextureCacheCreateTextureFromImage(CFAllocatorRef allocator, CVOpenGLESTextureCacheRef textureCache, CVImageBufferRef sourceImage, CFDictionaryRef textureAttributes, GLenum target, GLint internalFormat, GLsizei width, GLsizei height, GLenum format, GLenum type, size_t planeIndex, CVOpenGLESTextureRef *textureOut)
{
    typedef CVReturn (*Function)(CFAllocatorRef, CVOpenGLESTextureCacheRef, CVImageBufferRef, CFDictionaryRef, GLenum, GLint, GLsizei, GLsizei, GLenum, GLenum, size_t, CVOpenGLESTextureRef *);
    Function function = (Function)TGIOS4CoreVideoSymbol("CVOpenGLESTextureCacheCreateTextureFromImage");
    if (function == NULL)
    {
        if (textureOut != NULL)
            *textureOut = NULL;
        return -1;
    }
    return function(allocator, textureCache, sourceImage, textureAttributes, target, internalFormat, width, height, format, type, planeIndex, textureOut);
}

static inline void TGIOS4CVOpenGLESTextureCacheFlush(CVOpenGLESTextureCacheRef textureCache, CVOptionFlags options)
{
    typedef void (*Function)(CVOpenGLESTextureCacheRef, CVOptionFlags);
    Function function = (Function)TGIOS4CoreVideoSymbol("CVOpenGLESTextureCacheFlush");
    if (function != NULL)
        function(textureCache, options);
}

static inline GLenum TGIOS4CVOpenGLESTextureGetTarget(CVOpenGLESTextureRef texture)
{
    typedef GLenum (*Function)(CVOpenGLESTextureRef);
    Function function = (Function)TGIOS4CoreVideoSymbol("CVOpenGLESTextureGetTarget");
    return function != NULL ? function(texture) : GL_TEXTURE_2D;
}

static inline GLuint TGIOS4CVOpenGLESTextureGetName(CVOpenGLESTextureRef texture)
{
    typedef GLuint (*Function)(CVOpenGLESTextureRef);
    Function function = (Function)TGIOS4CoreVideoSymbol("CVOpenGLESTextureGetName");
    return function != NULL ? function(texture) : 0;
}

#define CVOpenGLESTextureCacheCreate TGIOS4CVOpenGLESTextureCacheCreate
#define CVOpenGLESTextureCacheCreateTextureFromImage TGIOS4CVOpenGLESTextureCacheCreateTextureFromImage
#define CVOpenGLESTextureCacheFlush TGIOS4CVOpenGLESTextureCacheFlush
#define CVOpenGLESTextureGetTarget TGIOS4CVOpenGLESTextureGetTarget
#define CVOpenGLESTextureGetName TGIOS4CVOpenGLESTextureGetName
#include <math.h>
#if defined(__cplusplus) && __IPHONE_OS_VERSION_MAX_ALLOWED <= 60100
#ifdef isinf
#undef isinf
#endif
static inline int isinf(double value) { return __builtin_isinf(value); }
#endif
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED < 50000
#include <dispatch/dispatch.h>
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
#define UIPercentDrivenInteractiveTransition TGIOS6PercentDrivenInteractiveTransition
#define NSURLSessionConfiguration TGIOS6URLSessionConfiguration
#define NSURLSession TGIOS6URLSession
#define NSURLSessionTask TGIOS6URLSessionTask
#define NSURLSessionDataTask TGIOS6URLSessionDataTask
#define UIKeyCommand TGIOS6KeyCommand
#define UICollectionViewTransitionLayout TGIOS6CollectionViewTransitionLayout
#define NSTextAttachment TGIOS6TextAttachment
#define NSLayoutManager TGIOS6LayoutManager
#define NSTextStorage TGIOS6TextStorage
#define NSTextContainer TGIOS6TextContainer
#define NSFontAttributeName @"NSFont"
#define NSForegroundColorAttributeName @"NSColor"
#define NSKernAttributeName @"NSKern"
#define NSParagraphStyleAttributeName @"NSParagraphStyle"
#define NSStrikethroughStyleAttributeName @"NSStrikethrough"
#define NSUnderlineStyleAttributeName @"NSUnderline"
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
#define UIAlertController TGIOS6AlertController
#define UIDocumentPickerViewController TGIOS6DocumentPickerViewController
#define PHObject TGIOS6PHObject
#define PHAsset TGIOS6PHAsset
#define PHAssetChangeRequest TGIOS6PHAssetChangeRequest
#define PHAssetCollection TGIOS6PHAssetCollection
#define PHCachingImageManager TGIOS6PHCachingImageManager
#define PHFetchOptions TGIOS6PHFetchOptions
#define PHImageManager TGIOS6PHImageManager
#define PHImageRequestOptions TGIOS6PHImageRequestOptions
#define PHPhotoLibrary TGIOS6PHPhotoLibrary
#define PHVideoRequestOptions TGIOS6PHVideoRequestOptions
#define WKFrameInfo TGIOS6WKFrameInfo
#define WKNavigation TGIOS6WKNavigation
#define WKNavigationAction TGIOS6WKNavigationAction
#define WKUserScript TGIOS6WKUserScript
#define WKPreferences TGIOS6WKPreferences
#define WKUserContentController TGIOS6WKUserContentController
#define WKWebViewConfiguration TGIOS6WKWebViewConfiguration
#define WKWebView TGIOS6WKWebView
#define WKNavigationDelegate TGIOS6WKNavigationDelegate
#define WKScriptMessageHandler TGIOS6WKScriptMessageHandler
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 90000
#define PHAssetResource TGIOS6PHAssetResource
#define PHAssetResourceManager TGIOS6PHAssetResourceManager
#define PHLivePhotoRequestOptions TGIOS6PHLivePhotoRequestOptions
#define CNContactFormatter TGIOS6ContactFormatter
#define CNContactVCardSerialization TGIOS6ContactVCardSerialization
#define CNLabeledValue TGIOS6LabeledValue
#define CNMutableContact TGIOS6MutableContact
#define CNPhoneNumber TGIOS6PhoneNumber
#define WCSession TGIOS6WCSession
#define SFSafariViewController TGIOS6SafariViewController
#define SFSafariViewControllerDelegate TGIOS6SafariViewControllerDelegate
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000
#define UIImpactFeedbackGenerator TGIOS6ImpactFeedbackGenerator
#endif

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
typedef struct {
    double x;
    double y;
} MKMapPoint;

typedef struct {
    double width;
    double height;
} MKMapSize;

typedef struct {
    MKMapPoint origin;
    MKMapSize size;
} MKMapRect;

typedef NSInteger MKUserTrackingMode;
enum {
    MKUserTrackingModeNone = 0,
    MKUserTrackingModeFollow = 1,
    MKUserTrackingModeFollowWithHeading = 2
};

static const MKMapRect MKMapRectWorld = {{0.0, 0.0}, {268435456.0, 268435456.0}};
static const MKMapRect MKMapRectNull = {{INFINITY, INFINITY}, {0.0, 0.0}};

static inline CLLocationCoordinate2D CLLocationCoordinate2DMake(CLLocationDegrees latitude, CLLocationDegrees longitude)
{
    CLLocationCoordinate2D coordinate;
    coordinate.latitude = latitude;
    coordinate.longitude = longitude;
    return coordinate;
}

static inline MKMapPoint MKMapPointMake(double x, double y)
{
    MKMapPoint point = {x, y};
    return point;
}

static inline MKMapSize MKMapSizeMake(double width, double height)
{
    MKMapSize size = {width, height};
    return size;
}

static inline MKMapRect MKMapRectMake(double x, double y, double width, double height)
{
    MKMapRect rect = {{x, y}, {width, height}};
    return rect;
}

static inline BOOL MKMapRectIsNull(MKMapRect rect)
{
    return isinf(rect.origin.x) || isinf(rect.origin.y);
}

static inline MKMapRect MKMapRectUnion(MKMapRect rect1, MKMapRect rect2)
{
    if (MKMapRectIsNull(rect1))
        return rect2;
    if (MKMapRectIsNull(rect2))
        return rect1;
    double minX = MIN(rect1.origin.x, rect2.origin.x);
    double minY = MIN(rect1.origin.y, rect2.origin.y);
    double maxX = MAX(rect1.origin.x + rect1.size.width, rect2.origin.x + rect2.size.width);
    double maxY = MAX(rect1.origin.y + rect1.size.height, rect2.origin.y + rect2.size.height);
    return MKMapRectMake(minX, minY, maxX - minX, maxY - minY);
}

static inline BOOL MKMapRectContainsPoint(MKMapRect rect, MKMapPoint point)
{
    if (MKMapRectIsNull(rect))
        return NO;
    return point.x >= rect.origin.x && point.x <= rect.origin.x + rect.size.width && point.y >= rect.origin.y && point.y <= rect.origin.y + rect.size.height;
}

static inline MKMapPoint MKMapPointForCoordinate(CLLocationCoordinate2D coordinate)
{
    const double world = 268435456.0;
    double latitude = MAX(-85.05112877980659, MIN(85.05112877980659, coordinate.latitude));
    double longitude = coordinate.longitude;
    double x = (longitude + 180.0) / 360.0 * world;
    double sinLatitude = sin(latitude * M_PI / 180.0);
    double y = (0.5 - log((1.0 + sinLatitude) / (1.0 - sinLatitude)) / (4.0 * M_PI)) * world;
    return MKMapPointMake(x, y);
}

static inline CLLocationCoordinate2D MKCoordinateForMapPoint(MKMapPoint point)
{
    const double world = 268435456.0;
    double longitude = point.x / world * 360.0 - 180.0;
    double mercator = M_PI - 2.0 * M_PI * point.y / world;
    double latitude = 180.0 / M_PI * atan(sinh(mercator));
    CLLocationCoordinate2D coordinate;
    coordinate.latitude = latitude;
    coordinate.longitude = longitude;
    return coordinate;
}

@interface MKMapView (TGIOS3MapKitCompatibility)
@property (nonatomic) MKUserTrackingMode userTrackingMode;
@property (nonatomic, readonly) MKMapRect visibleMapRect;
- (void)setUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated;
- (NSSet *)annotationsInMapRect:(MKMapRect)mapRect;
- (MKMapRect)mapRectThatFits:(MKMapRect)mapRect edgePadding:(UIEdgeInsets)insets;
- (void)setVisibleMapRect:(MKMapRect)mapRect animated:(BOOL)animated;
- (void)setVisibleMapRect:(MKMapRect)mapRect edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated;
@end

@interface CLLocation (TGIOS3DistanceCompatibility)
- (CLLocationDistance)distanceFromLocation:(const CLLocation *)location;
@end
#endif
#if __has_include(<CoreText/CoreText.h>)
#import <CoreText/CoreText.h>
#define TG_LEGACY_HAS_CORETEXT 1
#else
#import "OGPlatformText.h"
#define TG_LEGACY_HAS_CORETEXT OG_PLATFORM_HAS_CORETEXT
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
@class AVCaptureInput;
@class AVCaptureDeviceInput;
@class AVCaptureOutput;
@class AVCaptureConnection;
@class AVCaptureStillImageOutput;
@class AVCaptureVideoDataOutput;
@class AVCaptureAudioDataOutput;
@class AVCaptureDeviceFormat;
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
static inline AVCaptureConnection *TGAVCaptureConnectionWithMediaType(AVCaptureOutput *output, NSString *mediaType)
{
    for (AVCaptureConnection *connection in output.connections)
    {
        for (AVCaptureInputPort *inputPort in connection.inputPorts)
        {
            if ([inputPort.mediaType isEqualToString:mediaType])
                return connection;
        }
    }
    return nil;
}
#endif
#ifndef TG_LEGACY_NSARRAY_OBJECT_ACCESS_DECLS
#define TG_LEGACY_NSARRAY_OBJECT_ACCESS_DECLS
@interface NSArray (LegacyComponentsObjectAccessDeclarations)
@property (nonatomic, readonly) id firstObject;
@property (nonatomic, readonly) id lastObject;
@end
#endif

#import <UIKit/UIKit.h>
#import "../../../thirdparty/PSTCollectionView/PSTCollectionView/PSTCollectionView.h"
#import <QuartzCore/QuartzCore.h>
#import "../WebKit/WebKit.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@interface CALayer (TGLegacyRasterizationDeclarations)
- (void)setShouldRasterize:(BOOL)shouldRasterize;
- (void)setRasterizationScale:(CGFloat)rasterizationScale;
- (void)setContentsScale:(CGFloat)contentsScale;
@end
#endif

static inline void TGSetLayerShouldRasterize(CALayer *layer, BOOL shouldRasterize)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    SEL selector = @selector(setShouldRasterize:);
    if ([layer respondsToSelector:selector])
    {
        void (*setter)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[layer methodForSelector:selector];
        setter(layer, selector, shouldRasterize);
    }
#else
    layer.shouldRasterize = shouldRasterize;
#endif
}

static inline void TGSetLayerRasterizationScale(CALayer *layer, CGFloat rasterizationScale)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    SEL selector = @selector(setRasterizationScale:);
    if ([layer respondsToSelector:selector])
    {
        void (*setter)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[layer methodForSelector:selector];
        setter(layer, selector, rasterizationScale);
    }
#else
    layer.rasterizationScale = rasterizationScale;
#endif
}

static inline void TGSetLayerContentsScale(CALayer *layer, CGFloat contentsScale)
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
    SEL selector = @selector(setContentsScale:);
    if ([layer respondsToSelector:selector])
    {
        void (*setter)(id, SEL, CGFloat) = (void (*)(id, SEL, CGFloat))[layer methodForSelector:selector];
        setter(layer, selector, contentsScale);
    }
#else
    layer.contentsScale = contentsScale;
#endif
}


#ifndef TG_ENABLE_AUDIO_NOTES
#define TG_ENABLE_AUDIO_NOTES 1
#endif
#ifndef TG_LEGACY_FOUNDATION_MODERN_NAMES
#define TG_LEGACY_FOUNDATION_MODERN_NAMES
#ifndef NSCalendarIdentifierGregorian
#define NSCalendarIdentifierGregorian NSGregorianCalendar
#endif
#ifndef NSCalendarUnitEra
#define NSCalendarUnitEra NSEraCalendarUnit
#define NSCalendarUnitYear NSYearCalendarUnit
#define NSCalendarUnitMonth NSMonthCalendarUnit
#define NSCalendarUnitDay NSDayCalendarUnit
#define NSCalendarUnitHour NSHourCalendarUnit
#define NSCalendarUnitMinute NSMinuteCalendarUnit
#define NSCalendarUnitSecond NSSecondCalendarUnit
#define NSCalendarUnitWeekday NSWeekdayCalendarUnit
#define NSCalendarUnitWeekdayOrdinal NSWeekdayOrdinalCalendarUnit
#define NSCalendarUnitQuarter NSQuarterCalendarUnit
#define NSCalendarUnitWeekOfMonth NSWeekOfMonthCalendarUnit
#define NSCalendarUnitWeekOfYear NSWeekOfYearCalendarUnit
#define NSCalendarUnitYearForWeekOfYear NSYearForWeekOfYearCalendarUnit
#define NSCalendarUnitNanosecond NSNanosecondCalendarUnit
#define NSCalendarUnitCalendar NSCalendarCalendarUnit
#define NSCalendarUnitTimeZone NSTimeZoneCalendarUnit
#endif
#endif

#ifndef TG_LEGACY_FOUNDATION_MODERN_NAMES
#define TG_LEGACY_FOUNDATION_MODERN_NAMES
#ifndef NSCalendarIdentifierGregorian
#define NSCalendarIdentifierGregorian NSGregorianCalendar
#endif
#ifndef NSCalendarUnitEra
#define NSCalendarUnitEra NSEraCalendarUnit
#define NSCalendarUnitYear NSYearCalendarUnit
#define NSCalendarUnitMonth NSMonthCalendarUnit
#define NSCalendarUnitDay NSDayCalendarUnit
#define NSCalendarUnitHour NSHourCalendarUnit
#define NSCalendarUnitMinute NSMinuteCalendarUnit
#define NSCalendarUnitSecond NSSecondCalendarUnit
#define NSCalendarUnitWeekday NSWeekdayCalendarUnit
#define NSCalendarUnitWeekdayOrdinal NSWeekdayOrdinalCalendarUnit
#define NSCalendarUnitQuarter NSQuarterCalendarUnit
#define NSCalendarUnitWeekOfMonth NSWeekOfMonthCalendarUnit
#define NSCalendarUnitWeekOfYear NSWeekOfYearCalendarUnit
#define NSCalendarUnitYearForWeekOfYear NSYearForWeekOfYearCalendarUnit
#define NSCalendarUnitNanosecond NSNanosecondCalendarUnit
#define NSCalendarUnitCalendar NSCalendarCalendarUnit
#define NSCalendarUnitTimeZone NSTimeZoneCalendarUnit
#endif
#endif






#ifndef NSUnderlinePatternSolid
#define NSUnderlinePatternSolid 0x0000
#define NSUnderlinePatternDot 0x0100
#define NSUnderlinePatternDash 0x0200
#define NSUnderlinePatternDashDot 0x0300
#define NSUnderlinePatternDashDotDot 0x0400
#endif

#ifndef TG_LEGACY_COMMON_DECLS
#define TG_LEGACY_COMMON_DECLS
@class TGLocalization;
@class NSUserActivity;
@class UIApplicationShortcutItem;
#ifdef __cplusplus
extern "C" {
#endif
TGLocalization *legacyEffectiveLocalization();
NSString *TGLocalized(NSString *s);
NSString *TGEncodeText(NSString *string, int key);
NSString *TGStringMD5(NSString *string);
NSArray *TGGetLogFilePaths(int count);
NSURL *TGFileURLWithPathRelativeToURL(NSString *path, NSURL *baseURL);
int cpuCoreCount();
extern int TGLocalizedStaticVersion;
TGLocalization *currentNativeLocalization();
NSString *currentNativeLocalizationCode();
TGLocalization *nativeEnglishLocalization(void);
TGLocalization *currentCustomLocalization();
void setCurrentCustomLocalization(TGLocalization *localization);
TGLocalization *effectiveLocalization();
#if defined(ONEGRAM_DIAGNOSTICS) || defined(ONEGRAM_LOG_IMPLEMENTATION)
#undef TGLog
#undef TGLogv
void TGLog(NSString *format, ...);
void TGLogv(NSString *format, va_list args);
#else
#undef TGLog
#define TGLog(...) ((void)0)
#define TGLogv(...) ((void)0)
#endif
bool TGObjectCompare(id obj1, id obj2);
bool TGStringCompare(NSString *s1, NSString *s2);
#if defined(ONEGRAM_DIAGNOSTICS) || defined(ONEGRAM_LOG_IMPLEMENTATION)
#undef TGLegacyLog
void TGLegacyLog(NSString *format, ...);
#else
#define TGLegacyLog(...) ((void)0)
#endif
int iosMajorVersion();
int iosMinorVersion();
void TGDispatchOnMainThread(dispatch_block_t block);
void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block);
UIColor *TGSelectionColor();
UIColor *TGAccentColor(void);
UIColor *TGDestructiveAccentColor(void);
UIColor *TGSeparatorColor();
#ifdef __cplusplus
}
#endif
#ifndef UIColorRGB
#define UIColorRGB(rgb) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:1.0f])
#endif
#ifndef UIColorRGBA
#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])
#endif
#ifndef CGFloor
#ifdef __LP64__
#define CGFloor floor
#define CGRound round
#define CGCeil ceil
#define CGPow pow
#define CGSin sin
#define CGCos cos
#define CGSqrt sqrt
#else
#define CGFloor floorf
#define CGRound roundf
#define CGCeil ceilf
#define CGPow powf
#define CGSin sinf
#define CGCos cosf
#define CGSqrt sqrtf
#endif
#endif
#ifndef CGEven
#define CGEven(x) ((((int)x) & 1) ? (x + 1) : x)
#endif
#ifndef CGOdd
#define CGOdd(x) ((((int)x) & 1) ? x : (x + 1))
#endif
#endif

#ifndef TG_LEGACY_CTFONT_FROM_UIFONT
#define TG_LEGACY_CTFONT_FROM_UIFONT
static inline CTFontRef TGIos6CreateCTFontFromUIFont(UIFont *font)
{
    return CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
}
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
#ifndef TG_LEGACY_UIIMPACT_FEEDBACK_DECLS
#define TG_LEGACY_UIIMPACT_FEEDBACK_DECLS
typedef NSInteger UIImpactFeedbackStyle;
#ifndef UIImpactFeedbackStyleLight
#define UIImpactFeedbackStyleLight 0
#define UIImpactFeedbackStyleMedium 1
#define UIImpactFeedbackStyleHeavy 2
#endif
@interface UIImpactFeedbackGenerator : NSObject
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)impactOccurred;
- (void)prepare;
@end
@interface UISelectionFeedbackGenerator : NSObject
- (void)selectionChanged;
- (void)prepare;
@end
typedef NSInteger UINotificationFeedbackType;
#ifndef UINotificationFeedbackTypeSuccess
#define UINotificationFeedbackTypeSuccess 0
#define UINotificationFeedbackTypeWarning 1
#define UINotificationFeedbackTypeError 2
#endif
@interface UINotificationFeedbackGenerator : NSObject
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType;
- (void)prepare;
@end
#endif

#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
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

#ifndef PKAddressFieldNone
typedef NSUInteger PKAddressField;
#define PKAddressFieldNone 0
#define PKAddressFieldPostalAddress 1
#define PKAddressFieldPhone 2
#define PKAddressFieldEmail 4
#define PKAddressFieldName 8
#endif

#ifndef TG_LEGACY_UIIMPACT_FEEDBACK_DECLS
#define TG_LEGACY_UIIMPACT_FEEDBACK_DECLS
typedef NSInteger UIImpactFeedbackStyle;
#ifndef UIImpactFeedbackStyleLight
#define UIImpactFeedbackStyleLight 0
#define UIImpactFeedbackStyleMedium 1
#define UIImpactFeedbackStyleHeavy 2
#endif
@interface UIImpactFeedbackGenerator : NSObject
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)impactOccurred;
- (void)prepare;
@end
typedef NSInteger UIScrollViewKeyboardDismissMode;
#ifndef UIScrollViewKeyboardDismissModeNone
#define UIScrollViewKeyboardDismissModeNone 0
#define UIScrollViewKeyboardDismissModeOnDrag 1
#define UIScrollViewKeyboardDismissModeInteractive 2
#endif
@interface UIScrollView (LegacyComponentsKeyboardDismissMode)
@property (nonatomic) UIScrollViewKeyboardDismissMode keyboardDismissMode;
@end
#endif

#ifndef TG_LEGACY_KEYBOARD_DISMISS_MODE_DECLS
#define TG_LEGACY_KEYBOARD_DISMISS_MODE_DECLS
typedef NSInteger UIScrollViewKeyboardDismissMode;
#ifndef UIScrollViewKeyboardDismissModeNone
#define UIScrollViewKeyboardDismissModeNone 0
#define UIScrollViewKeyboardDismissModeOnDrag 1
#define UIScrollViewKeyboardDismissModeInteractive 2
#endif
@interface UIScrollView (LegacyComponentsKeyboardDismissMode)
@property (nonatomic) UIScrollViewKeyboardDismissMode keyboardDismissMode;
@end
#endif

#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
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
#ifndef TG_LEGACY_PASSKIT_APPLE_PAY_DECLS
#define TG_LEGACY_PASSKIT_APPLE_PAY_DECLS
static NSString *const PKPaymentNetworkAmex = @"AmEx";
static NSString *const PKPaymentNetworkMasterCard = @"MasterCard";
static NSString *const PKPaymentNetworkVisa = @"Visa";
static NSString *const PKPaymentNetworkDiscover = @"Discover";
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
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)supportedNetworks;
- (instancetype)initWithPaymentRequest:(PKPaymentRequest *)paymentRequest;
@property (nonatomic, assign) id<PKPaymentAuthorizationViewControllerDelegate> delegate;
@end
@protocol PKPaymentAuthorizationViewControllerDelegate <NSObject>
@optional
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment completion:(void (^)(PKPaymentAuthorizationStatus status))completion;
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller;
@end
#endif

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
#ifndef TG_LEGACY_PASSKIT_APPLE_PAY_DECLS
#define TG_LEGACY_PASSKIT_APPLE_PAY_DECLS
static NSString *const PKPaymentNetworkAmex = @"AmEx";
static NSString *const PKPaymentNetworkMasterCard = @"MasterCard";
static NSString *const PKPaymentNetworkVisa = @"Visa";
static NSString *const PKPaymentNetworkDiscover = @"Discover";
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
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)supportedNetworks;
- (instancetype)initWithPaymentRequest:(PKPaymentRequest *)paymentRequest;
@property (nonatomic, assign) id<PKPaymentAuthorizationViewControllerDelegate> delegate;
@end
@protocol PKPaymentAuthorizationViewControllerDelegate <NSObject>
@optional
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment completion:(void (^)(PKPaymentAuthorizationStatus status))completion;
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller;
@end
#endif
#ifndef TG_LEGACY_URLSESSION_DECLS
#define TG_LEGACY_URLSESSION_DECLS
typedef void (^NSURLSessionDataTaskCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);
@interface NSURLSessionTask : NSObject
- (void)resume;
- (void)cancel;
@end
@interface NSURLSessionDataTask : NSURLSessionTask
@end
@interface NSURLSessionConfiguration : NSObject
+ (instancetype)defaultSessionConfiguration;
@property (nonatomic, copy) NSDictionary *HTTPAdditionalHeaders;
@end
@interface NSURLSession : NSObject
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(id)delegate delegateQueue:(NSOperationQueue *)queue;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(NSURLSessionDataTaskCompletionHandler)completionHandler;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(NSURLSessionDataTaskCompletionHandler)completionHandler;
- (void)invalidateAndCancel;
@end
#endif

#ifndef TG_LEGACY_SSREADINGLIST_DECLS
#define TG_LEGACY_SSREADINGLIST_DECLS
@interface SSReadingList : NSObject
+ (instancetype)defaultReadingList;
- (BOOL)addReadingListItemWithURL:(NSURL *)URL title:(NSString *)title previewText:(NSString *)previewText error:(NSError **)error;
@end
#endif

#ifndef TG_LEGACY_OPTIONAL_SYSTEM_SELECTOR_DECLS
#define TG_LEGACY_OPTIONAL_SYSTEM_SELECTOR_DECLS
@interface NSObject (TGLegacyOptionalSystemSelectorDeclarations)
- (id)defaultReadingList;
- (BOOL)addReadingListItemWithURL:(NSURL *)url title:(NSString *)title previewText:(NSString *)previewText error:(NSError **)error;
- (void)setEffect:(id)effect;
- (id)effectWithStyle:(NSInteger)style;
- (id)summaryItemWithLabel:(NSString *)label amount:(NSDecimalNumber *)amount;
- (NSDecimalNumber *)amount;
- (BOOL)canMakePaymentsUsingNetworks:(NSArray *)supportedNetworks;
@end
#endif



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
#ifndef TG_LEGACY_PASSKIT_APPLE_PAY_DECLS
#define TG_LEGACY_PASSKIT_APPLE_PAY_DECLS
static NSString *const PKPaymentNetworkAmex = @"AmEx";
static NSString *const PKPaymentNetworkMasterCard = @"MasterCard";
static NSString *const PKPaymentNetworkVisa = @"Visa";
static NSString *const PKPaymentNetworkDiscover = @"Discover";
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
+ (BOOL)canMakePayments;
+ (BOOL)canMakePaymentsUsingNetworks:(NSArray *)supportedNetworks;
- (instancetype)initWithPaymentRequest:(PKPaymentRequest *)paymentRequest;
@property (nonatomic, assign) id<PKPaymentAuthorizationViewControllerDelegate> delegate;
@end
@protocol PKPaymentAuthorizationViewControllerDelegate <NSObject>
@optional
- (void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didAuthorizePayment:(PKPayment *)payment completion:(void (^)(PKPaymentAuthorizationStatus status))completion;
- (void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller;
@end
#endif
#ifndef TG_LEGACY_URLSESSION_DECLS
#define TG_LEGACY_URLSESSION_DECLS
typedef void (^NSURLSessionDataTaskCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);
@interface NSURLSessionTask : NSObject
- (void)resume;
- (void)cancel;
@end
@interface NSURLSessionDataTask : NSURLSessionTask
@end
@interface NSURLSessionConfiguration : NSObject
+ (instancetype)defaultSessionConfiguration;
@property (nonatomic, copy) NSDictionary *HTTPAdditionalHeaders;
@end
@interface NSURLSession : NSObject
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(NSURLSessionDataTaskCompletionHandler)completionHandler;
@end
#endif

#ifndef TG_LEGACY_TRANSITION_COORDINATOR_DECLS
#define TG_LEGACY_TRANSITION_COORDINATOR_DECLS
@protocol UIViewControllerTransitionCoordinatorContext <NSObject>
@end
@protocol UIViewControllerTransitionCoordinator <NSObject>
- (BOOL)isCancelled;
- (void)animateAlongsideTransition:(void (^)(id<UIViewControllerTransitionCoordinatorContext> context))animation completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext> context))completion;
@end
@interface UIViewController (LegacyTransitionCoordinatorDeclarations)
@property (nonatomic, readonly) id<UIViewControllerTransitionCoordinator> transitionCoordinator;
@end
#endif

#ifndef TG_LEGACY_SEMANTIC_CONTENT_DECLS
#define TG_LEGACY_SEMANTIC_CONTENT_DECLS
typedef NSInteger UISemanticContentAttribute;
#ifndef UISemanticContentAttributeUnspecified
#define UISemanticContentAttributeUnspecified 0
#define UISemanticContentAttributePlayback 1
#define UISemanticContentAttributeSpatial 2
#define UISemanticContentAttributeForceLeftToRight 3
#define UISemanticContentAttributeForceRightToLeft 4
#endif
@interface UIView (LegacySemanticContentDeclarations)
@property (nonatomic) UISemanticContentAttribute semanticContentAttribute;
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)attribute;
@end
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

#ifndef UIKeyInputUpArrow
#define UIKeyInputUpArrow @"\uF700"
#define UIKeyInputDownArrow @"\uF701"
#define UIKeyInputLeftArrow @"\uF702"
#define UIKeyInputRightArrow @"\uF703"
#define UIKeyInputEscape @"\033"
#endif

#ifndef UIKeyInputEscape
#define UIKeyInputEscape @"\033"
#endif

#ifndef UIKeyModifierAlphaShift
typedef NSUInteger UIKeyModifierFlags;
@interface UIKeyCommand : NSObject
@property (nonatomic, readonly) NSString *input;
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags;
+ (instancetype)keyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action;
@end
#define UIKeyModifierAlphaShift (1 << 16)
#define UIKeyModifierShift (1 << 17)
#define UIKeyModifierControl (1 << 18)
#define UIKeyModifierAlternate (1 << 19)
#define UIKeyModifierCommand (1 << 20)
#define UIKeyModifierNumericPad (1 << 21)
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
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
@interface UITextView (LegacyComponentsTextKitDeclarations)
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
@interface UINavigationController (LegacyComponentsInteractivePopDeclarations)
@property (nonatomic, readonly) UIGestureRecognizer *interactivePopGestureRecognizer;
@end
@interface UINavigationBar (LegacyComponentsLargeTitleDeclarations)
@property (nonatomic) BOOL prefersLargeTitles;
@end
@interface UIPercentDrivenInteractiveTransition : NSObject
@property (nonatomic, readonly) CGFloat percentComplete;
- (void)updateInteractiveTransition:(CGFloat)percentComplete;
- (void)cancelInteractiveTransition;
- (void)finishInteractiveTransition;
@end
#endif

#ifndef __IPHONE_9_0
@protocol UIViewControllerPreviewingDelegate <NSObject>
@end
typedef NSInteger UIDocumentPickerMode;
#ifndef UIDocumentPickerModeOpen
#define UIDocumentPickerModeImport 0
#define UIDocumentPickerModeOpen 1
#define UIDocumentPickerModeExportToService 2
#define UIDocumentPickerModeMoveToService 3
#endif
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
typedef NSInteger UIPreviewActionStyle;
#ifndef UIPreviewActionStyleDefault
#define UIPreviewActionStyleDefault 0
#define UIPreviewActionStyleSelected 1
#define UIPreviewActionStyleDestructive 2
#endif
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
@interface UIViewController (LegacyComponentsPreviewingDeclarations)
- (UIStatusBarStyle)preferredStatusBarStyle;
- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)value;
@property (nonatomic, readonly) id topLayoutGuide;
@property (nonatomic, readonly) id bottomLayoutGuide;
@property (nonatomic) CGSize preferredContentSize;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (id)registerForPreviewingWithDelegate:(id)delegate sourceView:(UIView *)sourceView;
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection;
@end

#endif


#ifndef TG_LEGACY_AVAUDIOSESSION_INPUT_DECLS
#define TG_LEGACY_AVAUDIOSESSION_INPUT_DECLS
@interface AVAudioSession (LegacyComponentsInputsDeclarations)
@property (nonatomic, readonly) NSArray *availableInputs;
- (void)requestRecordPermission:(void (^)(BOOL granted))response;
@end
#endif

#ifndef TG_LEGACY_LOCATION_MANAGER_DECLS
#define TG_LEGACY_LOCATION_MANAGER_DECLS
@interface CLLocationManager (LegacyLocationDeclarations)
@property (nonatomic) BOOL allowsBackgroundLocationUpdates;
- (void)requestAlwaysAuthorization;
- (void)requestWhenInUseAuthorization;
- (void)requestLocation;
@end
#endif

#ifndef TG_LEGACY_SNAPSHOT_DECLS
#define TG_LEGACY_SNAPSHOT_DECLS
@interface UIView (LegacyComponentsSnapshotDeclarations)
- (UIView *)snapshotViewAfterScreenUpdates:(BOOL)afterUpdates;
- (UIView *)resizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates withCapInsets:(UIEdgeInsets)capInsets;
- (BOOL)drawViewHierarchyInRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates;
@end
#endif

#ifndef TG_LEGACY_ACCESSIBILITY_INVERT_COLORS_DECLS
#define TG_LEGACY_ACCESSIBILITY_INVERT_COLORS_DECLS
#ifndef UIViewKeyframeAnimationOptionCalculationModeLinear
typedef NSUInteger UIViewKeyframeAnimationOptions;
#define UIViewKeyframeAnimationOptionCalculationModeLinear 0
#endif
@interface UIView (LegacyComponentsInvertColorsDeclarations)
@property (nonatomic) BOOL accessibilityIgnoresInvertColors;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)performWithoutAnimation:(void (^)(void))actionsWithoutAnimation;
+ (void)animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewKeyframeAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)addKeyframeWithRelativeStartTime:(double)frameStartTime relativeDuration:(double)frameDuration animations:(void (^)(void))animations;
@end
#endif


#ifndef TG_LEGACY_NSARRAY_FIRST_LAST_DECLS
#define TG_LEGACY_NSARRAY_FIRST_LAST_DECLS
@interface NSArray (LegacyComponentsFirstLastDeclarations)
@property (nonatomic, readonly) id firstObject;
@property (nonatomic, readonly) id lastObject;
@end
#endif





#ifndef TG_LEGACY_NSData_BASE64_DECLS
#define TG_LEGACY_NSData_BASE64_DECLS
typedef NSUInteger NSDataBase64DecodingOptions;
typedef NSUInteger NSDataBase64EncodingOptions;
#ifndef NSDataBase64DecodingIgnoreUnknownCharacters
#define NSDataBase64DecodingIgnoreUnknownCharacters 1
#endif
@interface NSData (LegacyComponentsBase64Declarations)
- (instancetype)initWithBase64EncodedString:(NSString *)base64String options:(NSDataBase64DecodingOptions)options;
- (instancetype)initWithBase64Encoding:(NSString *)base64String;
- (NSString *)base64Encoding;
@end
#endif

#ifndef TG_LEGACY_GALLERY_CONTROLLER_DECLS
#define TG_LEGACY_GALLERY_CONTROLLER_DECLS
typedef NSUInteger UIRectEdge;
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
#ifndef UIKeyInputLeftArrow
#define UIKeyInputLeftArrow @"UIKeyInputLeftArrow"
#define UIKeyInputRightArrow @"UIKeyInputRightArrow"
#define UIKeyInputEscape @"UIKeyInputEscape"
#endif
@interface UIAlertController : UIViewController
@end
typedef NSInteger UIAlertActionStyle;
#ifndef UIAlertActionStyleDefault
#define UIAlertActionStyleDefault 0
#define UIAlertActionStyleCancel 1
#define UIAlertActionStyleDestructive 2
#endif
@interface UIAlertAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *action))handler;
@end

@interface UIViewController (LegacyComponentsStatusBarDeclarations)
- (BOOL)prefersStatusBarHidden;
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures;
- (void)setNeedsStatusBarAppearanceUpdate;
- (void)setNeedsUpdateOfHomeIndicatorAutoHidden;
- (NSArray *)previewActionItems;
- (void)loadViewIfNeeded;
@end
#endif

#ifndef TG_LEGACY_COLLECTION_TRANSITION_DECLS
#define TG_LEGACY_COLLECTION_TRANSITION_DECLS
typedef void (^UICollectionViewLayoutInteractiveTransitionCompletion)(BOOL completed, BOOL finish);
typedef NSInteger UIScrollViewContentInsetAdjustmentBehavior;
#ifndef UIScrollViewContentInsetAdjustmentNever
#define UIScrollViewContentInsetAdjustmentNever 2
#endif
#ifndef UISemanticContentAttributeForceLeftToRight
#define UISemanticContentAttributeForceLeftToRight 3
#define UISemanticContentAttributeForceRightToLeft 4
#endif
@interface UICollectionViewTransitionLayout : PSUICollectionViewLayout
@property (nonatomic, readonly) PSUICollectionViewLayout *currentLayout;
@property (nonatomic, readonly) PSUICollectionViewLayout *nextLayout;
@property (nonatomic) CGFloat transitionProgress;
- (instancetype)initWithCurrentLayout:(PSUICollectionViewLayout *)currentLayout nextLayout:(PSUICollectionViewLayout *)newLayout;
@end


@interface UIScrollView (LegacyComponentsContentInsetAdjustmentDeclarations)
@property (nonatomic) UIScrollViewContentInsetAdjustmentBehavior contentInsetAdjustmentBehavior;
@end
@interface UIView (LegacyComponentsSemanticContentDeclarations)
@property (nonatomic, retain) UIColor *tintColor;
@property (nonatomic) UISemanticContentAttribute semanticContentAttribute;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInsets;
@end
#endif

#ifndef TG_LEGACY_NSCHARACTERSET_URL_DECLS
#define TG_LEGACY_NSCHARACTERSET_URL_DECLS
@interface NSCharacterSet (TGLegacyURLCharacterSetDeclarations)
+ (NSCharacterSet *)URLQueryAllowedCharacterSet;
@end
#endif

#ifndef TG_LEGACY_NSSTRING_DRAWING_DECLS
#define TG_LEGACY_NSSTRING_DRAWING_DECLS
#ifndef NSStringDrawingUsesLineFragmentOrigin
#define NSStringDrawingUsesLineFragmentOrigin (1 << 0)
#define NSStringDrawingUsesFontLeading (1 << 1)
#define NSStringDrawingUsesDeviceMetrics (1 << 3)
#define NSStringDrawingTruncatesLastVisibleLine (1 << 5)
#endif
@interface NSString (LegacyComponentsDrawingDeclarations)
- (CGSize)sizeWithAttributes:(NSDictionary *)attrs;
- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary *)attrs;
- (void)drawWithRect:(CGRect)rect options:(NSInteger)options attributes:(NSDictionary *)attributes context:(id)context;
- (NSString *)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet *)allowedCharacters;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(id)context;
@end
@interface NSAttributedString (LegacyComponentsDrawingDeclarations)
- (void)drawWithRect:(CGRect)rect options:(NSStringDrawingOptions)options context:(id)context;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options context:(id)context;
- (CGRect)boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(id)context;
@end
#endif



#ifndef TG_LEGACY_APP_DELEGATE_IOS8_DECLS
#define TG_LEGACY_APP_DELEGATE_IOS8_DECLS
typedef NSUInteger UIBackgroundFetchResult;
#ifndef UIBackgroundFetchResultNewData
#define UIBackgroundFetchResultNewData 0
#define UIBackgroundFetchResultNoData 1
#define UIBackgroundFetchResultFailed 2
#endif
@interface UIUserNotificationSettings : NSObject
@end
@interface UIApplication (TGLegacyRemoteNotificationDeclarations)
- (void)registerForRemoteNotifications;
@end
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
@interface UILocalNotification (TGLegacyCategoryDeclarations)
@property (nonatomic, copy) NSString *category;
@end
#endif
@interface NSUserDefaults (TGLegacySuiteDeclarations)
- (instancetype)initWithSuiteName:(NSString *)suiteName;
@end
@interface NSFileManager (TGLegacySecurityApplicationGroupDeclarations)
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
@end
#ifndef UIApplicationOpenURLOptionsSourceApplicationKey
#define UIApplicationOpenURLOptionsSourceApplicationKey UIApplicationLaunchOptionsSourceApplicationKey
#endif
#endif

#ifndef TG_LEGACY_POPOVER_PRESENTATION_DECLS
#define TG_LEGACY_POPOVER_PRESENTATION_DECLS
@class UIPopoverPresentationController;
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
@interface UIViewController (LegacyComponentsPopoverPresentationDeclarations)
@property (nonatomic, readonly) UIPopoverPresentationController *popoverPresentationController;
@end
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 30200
@interface UIPopoverController (LegacyComponentsPopoverBackgroundDeclarations)
@property (nonatomic, retain) UIColor *backgroundColor;
@end
#endif
#endif


#ifndef TG_LEGACY_MORE_UIKIT_DECLS_FROM_PCH
#define TG_LEGACY_MORE_UIKIT_DECLS_FROM_PCH
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
@interface UIActivityViewController (TGLegacyPopoverDeclarations)
@property (nonatomic, readonly) UIPopoverPresentationController *popoverPresentationController;
@end
#endif
@interface UITableView (TGLegacySeparatorInsetDeclarations)
@property (nonatomic) UIEdgeInsets separatorInset;
@end
@interface UIViewController (TGLegacyScrollInsetDeclarations)
- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)value;
@end
@interface NSObject (TGLegacyTextContainerInsetDeclarations)
- (UIEdgeInsets)textContainerInset;
- (void)setTextContainerInset:(UIEdgeInsets)inset;
@end
#endif

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

#ifndef TG_LEGACY_AV_DECLS
#define TG_LEGACY_AV_DECLS
typedef NSInteger AVAuthorizationStatus;
#ifndef AVAuthorizationStatusNotDetermined
#define AVAuthorizationStatusNotDetermined 0
#define AVAuthorizationStatusRestricted 1
#define AVAuthorizationStatusDenied 2
#define AVAuthorizationStatusAuthorized 3
#endif
#if __has_include(<AVFoundation/AVPlayer.h>)
@interface AVPlayer (LegacyComponentsMutedDeclarations)
@property (nonatomic, getter=isMuted) BOOL muted;
@end
#endif
#if __has_include(<AVFoundation/AVCaptureDevice.h>)
@interface AVCaptureDevice (LegacyComponentsAuthorizationDeclarations)
+ (AVAuthorizationStatus)authorizationStatusForMediaType:(NSString *)mediaType;
+ (void)requestAccessForMediaType:(NSString *)mediaType completionHandler:(void (^)(BOOL granted))handler;
@end
#endif
#if __has_include(<AVFoundation/AVAudioSession.h>)
@interface AVAudioSession (LegacyComponentsRecordPermissionDeclarations)
- (void)requestRecordPermission:(void (^)(BOOL granted))response;
@end
#endif
#endif

#ifndef AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps
typedef NSInteger AVCaptureSessionInterruptionReason;
#define AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps 1
#define AVCaptureSessionInterruptionReasonKey @"AVCaptureSessionInterruptionReasonKey"
#endif

#endif

@interface PSUICollectionViewLayoutAttributes (LegacyComponentsBoundsDeclarations)
@property (nonatomic) CGRect bounds;
@end
@interface PSUICollectionView (LegacyComponentsTransitionDeclarations)
- (UICollectionViewTransitionLayout *)startInteractiveTransitionToCollectionViewLayout:(PSUICollectionViewLayout *)layout completion:(UICollectionViewLayoutInteractiveTransitionCompletion)completion;
- (void)finishInteractiveTransition;
- (void)cancelInteractiveTransition;
@end

#endif
#endif
