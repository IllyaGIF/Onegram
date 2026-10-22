#ifndef ONEGRAM_IOS3_COMPATIBILITY_H
#define ONEGRAM_IOS3_COMPATIBILITY_H

#include <stddef.h>
#include <stdint.h>
#ifndef __STDC_FORMAT_MACROS
#define __STDC_FORMAT_MACROS
#endif
#include <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif

void arc4random_buf(void *buffer, size_t length);
uint32_t arc4random_uniform(uint32_t upper_bound);

#ifdef __cplusplus
}
#endif

#ifdef __OBJC__

#import <Foundation/Foundation.h>
#if defined(ONEGRAM_ARMV6)
id OnegramIOS3LoadStrongIvar(const void *location);
void OnegramIOS3StoreStrongIvar(void *location, id value);
#endif
#ifndef __AVAILABILITY_INTERNAL__IPHONE_4_0
#define __AVAILABILITY_INTERNAL__IPHONE_4_0
#endif
#ifndef __AVAILABILITY_INTERNAL__IPHONE_4_3
#define __AVAILABILITY_INTERNAL__IPHONE_4_3
#endif
#ifndef __AVAILABILITY_INTERNAL__IPHONE_5_0
#define __AVAILABILITY_INTERNAL__IPHONE_5_0
#endif
#ifndef CF_RETURNS_RETAINED
#define CF_RETURNS_RETAINED __attribute__((cf_returns_retained))
#endif
#ifndef NS_UNAVAILABLE
#define NS_UNAVAILABLE __attribute__((unavailable))
#endif
#ifndef NS_RETURNS_RETAINED
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#endif
#import <CoreGraphics/CGGeometry.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIImage.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UILabel.h>
#import <UIKit/UIButton.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UINavigationBar.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIDataDetectors.h>
#import <UIKit/UITextView.h>
#import <UIKit/UIWindow.h>

#ifndef UI_APPEARANCE_SELECTOR
#define UI_APPEARANCE_SELECTOR
#endif

#ifndef UIViewNoIntrinsicMetric
#define UIViewNoIntrinsicMetric ((CGFloat)-1.0)
#endif

#ifndef UIViewAnimationOptionTransitionFlipFromRight
#define UIViewAnimationOptionTransitionFlipFromRight (2UL << 20)
#endif

#ifndef UITableViewRowAnimationAutomatic
#define UITableViewRowAnimationAutomatic UITableViewRowAnimationFade
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
#define CLPlacemark OnegramIOS3Placemark
@interface CLPlacemark : NSObject
{
    CLLocation *_location;
    NSDictionary *_addressDictionary;
}
- (instancetype)initWithLocation:(CLLocation *)location addressDictionary:(NSDictionary *)addressDictionary;
@property (nonatomic, readonly, retain) CLLocation *location;
@property (nonatomic, readonly, copy) NSDictionary *addressDictionary;
@property (nonatomic, readonly, copy) NSString *locality;
@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
void CFRunLoopPerformBlock(CFRunLoopRef runLoop, CFTypeRef mode, void (^block)(void));

#define kCGInterpolationMedium kCGInterpolationHigh

static inline CGRect AVMakeRectWithAspectRatioInsideRect(CGSize aspectRatio, CGRect boundingRect)
{
    if (aspectRatio.width <= 0.0f || aspectRatio.height <= 0.0f || boundingRect.size.width <= 0.0f || boundingRect.size.height <= 0.0f)
        return CGRectMake(CGRectGetMidX(boundingRect), CGRectGetMidY(boundingRect), 0.0f, 0.0f);

    CGFloat scale = MIN(boundingRect.size.width / aspectRatio.width, boundingRect.size.height / aspectRatio.height);
    CGSize size = CGSizeMake(aspectRatio.width * scale, aspectRatio.height * scale);
    return CGRectMake(boundingRect.origin.x + (boundingRect.size.width - size.width) * 0.5f,
                      boundingRect.origin.y + (boundingRect.size.height - size.height) * 0.5f,
                      size.width, size.height);
}
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
typedef NSInteger UIApplicationState;
enum
{
    UIApplicationStateActive = 0,
    UIApplicationStateInactive = 1,
    UIApplicationStateBackground = 2
};

@interface UIWindow (OnegramIOS3RootViewControllerCompatibility)
@property (nonatomic, retain) UIViewController *rootViewController;
@end

@interface UIApplication (OnegramIOS3ApplicationStateCompatibility)
- (UIApplicationState)applicationState;
@end

@interface UITextField (OnegramIOS3DeleteBackwardDeclaration)
- (void)deleteBackward;
@end

@protocol UIKeyInput <NSObject>
- (BOOL)hasText;
- (void)insertText:(NSString *)text;
- (void)deleteBackward;
@end

typedef NSInteger UIUserInterfaceIdiom;
enum
{
    UIUserInterfaceIdiomPhone = 0,
    UIUserInterfaceIdiomPad = 1
};

#ifndef UI_USER_INTERFACE_IDIOM
#define UI_USER_INTERFACE_IDIOM() ([[UIDevice currentDevice] userInterfaceIdiom])
#endif

typedef NSInteger UIModalPresentationStyle;
enum
{
    UIModalPresentationFullScreen = 0,
    UIModalPresentationPageSheet = 1,
    UIModalPresentationFormSheet = 2,
    UIModalPresentationCurrentContext = 3
};

typedef NSUInteger UIRectCorner;
enum
{
    UIRectCornerTopLeft = 1 << 0,
    UIRectCornerTopRight = 1 << 1,
    UIRectCornerBottomLeft = 1 << 2,
    UIRectCornerBottomRight = 1 << 3,
    UIRectCornerAllCorners = ~0UL
};

typedef NSUInteger UIInterfaceOrientationMask;
enum
{
    UIInterfaceOrientationMaskPortrait = (1 << 1),
    UIInterfaceOrientationMaskLandscapeLeft = (1 << 3),
    UIInterfaceOrientationMaskLandscapeRight = (1 << 4),
    UIInterfaceOrientationMaskPortraitUpsideDown = (1 << 2),
    UIInterfaceOrientationMaskLandscape = UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight,
    UIInterfaceOrientationMaskAll = UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight | UIInterfaceOrientationMaskPortraitUpsideDown,
    UIInterfaceOrientationMaskAllButUpsideDown = UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight
};

#define UIBezierPath OnegramIOS3BezierPath
@interface UIBezierPath : NSObject
{
    CGMutablePathRef _onegramPath;
    CGFloat _onegramLineWidth;
    CGLineCap _onegramLineCapStyle;
    CGLineJoin _onegramLineJoinStyle;
    BOOL _onegramUsesEvenOddFillRule;
}
+ (UIBezierPath *)bezierPath;
+ (UIBezierPath *)bezierPathWithRect:(CGRect)rect;
+ (UIBezierPath *)bezierPathWithOvalInRect:(CGRect)rect;
+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect cornerRadius:(CGFloat)cornerRadius;
+ (UIBezierPath *)bezierPathWithRoundedRect:(CGRect)rect byRoundingCorners:(UIRectCorner)corners cornerRadii:(CGSize)cornerRadii;
+ (UIBezierPath *)bezierPathWithArcCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGLineCap lineCapStyle;
@property (nonatomic) CGLineJoin lineJoinStyle;
@property (nonatomic) BOOL usesEvenOddFillRule;
@property (nonatomic, readonly) CGPathRef CGPath;
- (void)moveToPoint:(CGPoint)point;
- (void)addLineToPoint:(CGPoint)point;
- (void)addArcWithCenter:(CGPoint)center radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(BOOL)clockwise;
- (void)closePath;
- (void)appendPath:(UIBezierPath *)bezierPath;
- (void)fill;
- (void)fillWithBlendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
- (void)stroke;
- (void)addClip;
@end
#endif

#ifdef ONEGRAM_IOS3_APPLICATION_BUILD
#include <dispatch/dispatch.h>
#ifndef NSURLErrorFailingURLErrorKey
#define NSURLErrorFailingURLErrorKey @"NSErrorFailingURLKey"
#endif
#endif

#ifdef NSAssert
#undef NSAssert
#endif

#ifdef NSCAssert
#undef NSCAssert
#endif

#ifdef NS_BLOCK_ASSERTIONS
#define NSAssert(condition, desc, ...) do { } while (0)
#define NSCAssert(condition, desc, ...) do { } while (0)
#else
#define NSAssert(condition, desc, ...) do { if (!(condition)) { [[NSAssertionHandler currentHandler] handleFailureInMethod:_cmd object:self file:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__ description:(desc), ##__VA_ARGS__]; } } while (0)
#define NSCAssert(condition, desc, ...) do { if (!(condition)) { [[NSAssertionHandler currentHandler] handleFailureInFunction:[NSString stringWithUTF8String:__PRETTY_FUNCTION__] file:[NSString stringWithUTF8String:__FILE__] lineNumber:__LINE__ description:(desc), ##__VA_ARGS__]; } } while (0)
#endif

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#ifndef NS_OPTIONS
#define NS_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#ifndef instancetype
#define instancetype id
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#ifndef NSLineBreakMode
#define NSLineBreakMode UILineBreakMode
#endif
#ifndef NSLineBreakByWordWrapping
#define NSLineBreakByWordWrapping UILineBreakModeWordWrap
#define NSLineBreakByCharWrapping UILineBreakModeCharacterWrap
#define NSLineBreakByClipping UILineBreakModeClip
#define NSLineBreakByTruncatingHead UILineBreakModeHeadTruncation
#define NSLineBreakByTruncatingTail UILineBreakModeTailTruncation
#define NSLineBreakByTruncatingMiddle UILineBreakModeMiddleTruncation
#endif

typedef NSInteger UIBarMetrics;
enum
{
    UIBarMetricsDefault = 0,
    UIBarMetricsLandscapePhone = 1,
    UIBarMetricsDefaultPrompt = 101,
    UIBarMetricsLandscapePhonePrompt = 102
};

typedef NSUInteger NSDataWritingOptions;
enum
{
    NSDataWritingAtomic = 1UL << 0
};

typedef NSUInteger NSDataReadingOptions;
enum
{
    NSDataReadingMappedIfSafe = 1UL << 0,
    NSDataReadingUncached = 1UL << 1,
    NSDataReadingMappedAlways = 1UL << 3
};

typedef NSUInteger NSJSONWritingOptions;
enum
{
    NSJSONWritingPrettyPrinted = 1UL << 0
};

typedef NSUInteger NSJSONReadingOptions;
enum
{
    NSJSONReadingMutableContainers = 1UL << 0,
    NSJSONReadingMutableLeaves = 1UL << 1,
    NSJSONReadingAllowFragments = 1UL << 2
};

#ifndef UITextAttributeFont
#define UITextAttributeFont @"UITextAttributeFont"
#define UITextAttributeTextColor @"UITextAttributeTextColor"
#define UITextAttributeTextShadowColor @"UITextAttributeTextShadowColor"
#define UITextAttributeTextShadowOffset @"UITextAttributeTextShadowOffset"
#endif

typedef NSUInteger NSEnumerationOptions;
enum
{
    NSEnumerationConcurrent = (1UL << 0),
    NSEnumerationReverse = (1UL << 1)
};

typedef struct {
    CGFloat horizontal;
    CGFloat vertical;
} UIOffset;

static inline UIOffset UIOffsetMake(CGFloat horizontal, CGFloat vertical)
{
    UIOffset offset;
    offset.horizontal = horizontal;
    offset.vertical = vertical;
    return offset;
}

@interface NSValue (OnegramIOS3UIOffsetCompatibility)
+ (NSValue *)valueWithUIOffset:(UIOffset)offset;
- (UIOffset)UIOffsetValue;
@end

@interface NSIndexSet (OnegramIOS3EnumerationCompatibility)
- (void)enumerateIndexesUsingBlock:(void (^)(NSUInteger idx, BOOL *stop))block;
- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(NSUInteger idx, BOOL *stop))block;
@end

@interface NSSortDescriptor (OnegramIOS3Compatibility)
+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending;
+ (id)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)ascending selector:(SEL)selector;
@end

#define NSCache OnegramIOS3Cache
@class OnegramIOS3CacheEntry;
@interface OnegramIOS3Cache : NSObject
{
    CFMutableDictionaryRef _onegramEntriesByKey;
    OnegramIOS3CacheEntry *_onegramOldestEntry;
    OnegramIOS3CacheEntry *_onegramNewestEntry;
    NSRecursiveLock *_onegramLock;
    NSUInteger _onegramCountLimit;
    NSUInteger _onegramTotalCostLimit;
    NSUInteger _onegramTotalCost;
}
@property (nonatomic) NSUInteger countLimit;
@property (nonatomic) NSUInteger totalCostLimit;
- (id)objectForKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;
- (void)setObject:(id)object forKey:(id)key cost:(NSUInteger)cost;
- (void)removeObjectForKey:(id)key;
- (void)removeAllObjects;
@end

@interface NSNotificationCenter (OnegramIOS3BlockObserverDeclarations)
- (id)addObserverForName:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *notification))block;
@end

@interface NSOperationQueue (OnegramIOS3MainQueueCompatibility)
+ (NSOperationQueue *)mainQueue;
@end

@interface NSOperation (OnegramIOS3ThreadPriorityCompatibility)
@property double threadPriority;
@end

#define NSBlockOperation OnegramIOS3BlockOperation
@interface NSBlockOperation : NSOperation
{
    NSMutableArray *_onegramExecutionBlocks;
    BOOL _onegramStarted;
}
+ (instancetype)blockOperationWithBlock:(void (^)(void))block;
- (void)addExecutionBlock:(void (^)(void))block;
- (NSArray *)executionBlocks;
@end

@interface NSURLConnection (OnegramIOS3AsyncCompatibility)
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))handler;
@end

#define NSUUID OnegramIOS3UUID
@interface NSUUID : NSObject <NSCopying>
{
    NSString *_onegramUUIDString;
}
+ (NSUUID *)UUID;
- (instancetype)initWithUUIDString:(NSString *)string;
- (NSString *)UUIDString;
@end

typedef NSUInteger NSStringEnumerationOptions;
enum
{
    NSStringEnumerationByLines = 0,
    NSStringEnumerationByParagraphs = 1,
    NSStringEnumerationByComposedCharacterSequences = 2,
    NSStringEnumerationByWords = 3,
    NSStringEnumerationBySentences = 4,
    NSStringEnumerationReverse = (1UL << 8),
    NSStringEnumerationSubstringNotRequired = (1UL << 9),
    NSStringEnumerationLocalized = (1UL << 10)
};

typedef uint64_t NSTextCheckingType;
enum
{
    NSTextCheckingTypeOrthography = 1ULL << 0,
    NSTextCheckingTypeSpelling = 1ULL << 1,
    NSTextCheckingTypeGrammar = 1ULL << 2,
    NSTextCheckingTypeDate = 1ULL << 3,
    NSTextCheckingTypeAddress = 1ULL << 4,
    NSTextCheckingTypeLink = 1ULL << 5,
    NSTextCheckingTypeQuote = 1ULL << 6,
    NSTextCheckingTypeDash = 1ULL << 7,
    NSTextCheckingTypeReplacement = 1ULL << 8,
    NSTextCheckingTypeCorrection = 1ULL << 9,
    NSTextCheckingTypeRegularExpression = 1ULL << 10,
    NSTextCheckingTypePhoneNumber = 1ULL << 11,
    NSTextCheckingTypeTransitInformation = 1ULL << 12
};

typedef NSUInteger NSMatchingOptions;
typedef NSUInteger NSMatchingFlags;

#define NSTextCheckingResult OnegramIOS3TextCheckingResult
#define NSDataDetector OnegramIOS3DataDetector

@interface OnegramIOS3TextCheckingResult : NSObject
{
    NSTextCheckingType _onegramResultType;
    NSRange _onegramRange;
    NSURL *_onegramURL;
    NSString *_onegramPhoneNumber;
    NSArray *_onegramRanges;
}
+ (OnegramIOS3TextCheckingResult *)linkCheckingResultWithRange:(NSRange)range URL:(NSURL *)url;
+ (OnegramIOS3TextCheckingResult *)phoneNumberCheckingResultWithRange:(NSRange)range phoneNumber:(NSString *)phoneNumber;
+ (OnegramIOS3TextCheckingResult *)regularExpressionCheckingResultWithRanges:(NSArray *)ranges;
- (instancetype)initWithResultType:(NSTextCheckingType)resultType range:(NSRange)range URL:(NSURL *)url phoneNumber:(NSString *)phoneNumber;
- (instancetype)initWithRanges:(NSArray *)ranges;
@property (nonatomic, readonly) NSTextCheckingType resultType;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly, retain) NSURL *URL;
@property (nonatomic, readonly, copy) NSString *phoneNumber;
- (OnegramIOS3TextCheckingResult *)resultByAdjustingRangesWithOffset:(NSInteger)offset;
- (NSUInteger)numberOfRanges;
- (NSRange)rangeAtIndex:(NSUInteger)idx;
- (void)setIsTelegramHiddenLink:(bool)value;
- (bool)isTelegramHiddenLink;
@end

typedef NSUInteger NSRegularExpressionOptions;
enum
{
    NSRegularExpressionCaseInsensitive = 1UL << 0
};

#define NSRegularExpression OnegramIOS3RegularExpression
@interface OnegramIOS3RegularExpression : NSObject
{
    NSString *_onegramPattern;
    NSRegularExpressionOptions _onegramOptions;
    void *_onegramCompiledExpression;
    NSUInteger _onegramCaptureCount;
}
+ (OnegramIOS3RegularExpression *)regularExpressionWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error;
- (instancetype)initWithPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options error:(NSError **)error;
@property (nonatomic, readonly, copy) NSString *pattern;
@property (nonatomic, readonly) NSRegularExpressionOptions options;
@property (nonatomic, readonly) NSUInteger numberOfCaptureGroups;
- (OnegramIOS3TextCheckingResult *)firstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSArray *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSUInteger)numberOfMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSRange)rangeOfFirstMatchInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (NSString *)stringByReplacingMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range withTemplate:(NSString *)templ;
@end

@interface OnegramIOS3DataDetector : NSObject
{
    NSTextCheckingType _onegramCheckingTypes;
}
+ (OnegramIOS3DataDetector *)dataDetectorWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error;
- (instancetype)initWithTypes:(NSTextCheckingType)checkingTypes error:(NSError **)error;
- (NSArray *)matchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range;
- (void)enumerateMatchesInString:(NSString *)string options:(NSMatchingOptions)options range:(NSRange)range usingBlock:(void (^)(OnegramIOS3TextCheckingResult *result, NSMatchingFlags flags, BOOL *stop))block;
@end

#ifndef UIKeyboardWillChangeFrameNotification
#define UIKeyboardWillChangeFrameNotification UIKeyboardWillShowNotification
#endif
#ifndef UIKeyboardDidChangeFrameNotification
#define UIKeyboardDidChangeFrameNotification UIKeyboardDidShowNotification
#endif
#ifndef UIKeyboardFrameEndUserInfoKey
#define UIKeyboardFrameEndUserInfoKey @"UIKeyboardFrameEndUserInfoKey"
#endif

@interface UIViewController (OnegramIOS3ModernRotationDeclarations)
+ (void)attemptRotationToDeviceOrientation;
- (BOOL)shouldAutorotate;
- (BOOL)disablesAutomaticKeyboardDismissal;
@end

@interface UIViewController (OnegramIOS3LayoutLifecycleCompatibility)
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
@end

@interface UINavigationItem (OnegramIOS3ModernBarButtonDeclarations)
- (void)setRightBarButtonItems:(NSArray *)items animated:(BOOL)animated;
@end

#ifndef UIApplicationDidEnterBackgroundNotification
#define UIApplicationDidEnterBackgroundNotification UIApplicationWillResignActiveNotification
#endif
#ifndef UIApplicationWillEnterForegroundNotification
#define UIApplicationWillEnterForegroundNotification UIApplicationDidBecomeActiveNotification
#endif
#endif

@class NSBundle;
@class UIScrollView;
@class UIView;

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000

#define gestureRecognizers onegramGestureRecognizers
#define addGestureRecognizer onegramAddGestureRecognizer
#define removeGestureRecognizer onegramRemoveGestureRecognizer
#define UIGestureRecognizer OnegramIOS3GestureRecognizer
#define UIGestureRecognizerDelegate OnegramIOS3GestureRecognizerDelegate
#define UIPanGestureRecognizer OnegramIOS3PanGestureRecognizer
#define UIPinchGestureRecognizer OnegramIOS3PinchGestureRecognizer
#define UIRotationGestureRecognizer OnegramIOS3RotationGestureRecognizer
#define UISwipeGestureRecognizer OnegramIOS3SwipeGestureRecognizer
#define UITapGestureRecognizer OnegramIOS3TapGestureRecognizer
#define UILongPressGestureRecognizer OnegramIOS3LongPressGestureRecognizer
#define UINib OnegramIOS3Nib

typedef enum {
    UIGestureRecognizerStatePossible = 0,
    UIGestureRecognizerStateBegan = 1,
    UIGestureRecognizerStateChanged = 2,
    UIGestureRecognizerStateEnded = 3,
    UIGestureRecognizerStateCancelled = 4,
    UIGestureRecognizerStateFailed = 5,
    UIGestureRecognizerStateRecognized = UIGestureRecognizerStateEnded
} UIGestureRecognizerState;

@protocol UIGestureRecognizerDelegate <NSObject>
@optional
- (BOOL)gestureRecognizerShouldBegin:(id)gestureRecognizer;
- (BOOL)gestureRecognizer:(id)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;
- (BOOL)gestureRecognizer:(id)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(id)otherGestureRecognizer;
@end

@interface UIGestureRecognizer : NSObject
{
@protected
    NSMutableArray *_onegramTargetActions;
    id _onegramDelegate;
    UIGestureRecognizerState _onegramState;
    BOOL _onegramEnabled;
    BOOL _onegramCancelsTouchesInView;
    BOOL _onegramDelaysTouchesBegan;
    BOOL _onegramDelaysTouchesEnded;
    NSSet *_onegramTouches;
}
- (instancetype)initWithTarget:(id)target action:(SEL)action;
- (void)addTarget:(id)target action:(SEL)action;
- (void)removeTarget:(id)target action:(SEL)action;
@property (nonatomic, assign) id<UIGestureRecognizerDelegate> delegate;
@property (nonatomic, assign) UIGestureRecognizerState state;
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) BOOL cancelsTouchesInView;
@property (nonatomic) BOOL delaysTouchesBegan;
@property (nonatomic) BOOL delaysTouchesEnded;
- (CGPoint)locationInView:(UIView *)view;
- (NSUInteger)numberOfTouches;
- (CGPoint)locationOfTouch:(NSUInteger)touchIndex inView:(UIView *)view;
- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)otherGestureRecognizer;
- (void)reset;
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface UIPanGestureRecognizer : UIGestureRecognizer
{
    CGPoint _onegramStartLocation;
    CGPoint _onegramCurrentLocation;
    CGPoint _onegramTranslation;
    CGPoint _onegramVelocity;
    NSTimeInterval _onegramLastTimestamp;
    NSUInteger _onegramMinimumNumberOfTouches;
    NSUInteger _onegramMaximumNumberOfTouches;
}
@property (nonatomic) NSUInteger minimumNumberOfTouches;
@property (nonatomic) NSUInteger maximumNumberOfTouches;
- (CGPoint)translationInView:(UIView *)view;
- (void)setTranslation:(CGPoint)translation inView:(UIView *)view;
- (CGPoint)velocityInView:(UIView *)view;
@end

@interface UIPinchGestureRecognizer : UIGestureRecognizer
{
    CGFloat _scale;
    CGFloat _onegramPinchVelocity;
    CGFloat _onegramPreviousDistance;
    NSTimeInterval _onegramPinchLastTimestamp;
    UITouch *_onegramPinchFirstTouch;
    UITouch *_onegramPinchSecondTouch;
}
@property (nonatomic) CGFloat scale;
@property (nonatomic, readonly) CGFloat velocity;
@end

@interface UIRotationGestureRecognizer : UIGestureRecognizer
{
    CGFloat _rotation;
    CGFloat _onegramRotationVelocity;
    CGFloat _onegramPreviousAngle;
    NSTimeInterval _onegramRotationLastTimestamp;
    UITouch *_onegramRotationFirstTouch;
    UITouch *_onegramRotationSecondTouch;
}
@property (nonatomic) CGFloat rotation;
@property (nonatomic, readonly) CGFloat velocity;
@end

typedef NSUInteger UISwipeGestureRecognizerDirection;
enum
{
    UISwipeGestureRecognizerDirectionRight = 1 << 0,
    UISwipeGestureRecognizerDirectionLeft = 1 << 1,
    UISwipeGestureRecognizerDirectionUp = 1 << 2,
    UISwipeGestureRecognizerDirectionDown = 1 << 3
};

@interface UISwipeGestureRecognizer : UIGestureRecognizer
{
    UISwipeGestureRecognizerDirection _onegramDirection;
    CGPoint _onegramSwipeStartLocation;
}
@property (nonatomic) UISwipeGestureRecognizerDirection direction;
@end

@interface UITapGestureRecognizer : UIGestureRecognizer
{
    NSUInteger _numberOfTapsRequired;
    NSUInteger _numberOfTouchesRequired;
}
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end

@interface UILongPressGestureRecognizer : UIGestureRecognizer
{
    NSUInteger _numberOfTapsRequired;
    NSUInteger _numberOfTouchesRequired;
    NSTimeInterval _minimumPressDuration;
    CGFloat _allowableMovement;
}
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@property (nonatomic) NSTimeInterval minimumPressDuration;
@property (nonatomic) CGFloat allowableMovement;
@end

@interface UIView (OnegramIOS3GestureCompatibility)
@property (nonatomic, readonly, copy) NSArray *gestureRecognizers;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (void)removeGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end

@interface UIView (OnegramIOS3AnimationCompatibility)
+ (void)performWithoutAnimation:(void (^)(void))actionsWithoutAnimation;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)dampingRatio initialSpringVelocity:(CGFloat)velocity options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)animateKeyframesWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
+ (void)addKeyframeWithRelativeStartTime:(double)frameStartTime relativeDuration:(double)frameDuration animations:(void (^)(void))animations;
+ (void)transitionWithView:(UIView *)view duration:(NSTimeInterval)duration options:(NSUInteger)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion;
@end

@interface UIViewController (OnegramIOS3ContainmentCompatibility)
@property (nonatomic, readonly, copy) NSArray *childViewControllers;
- (void)addChildViewController:(UIViewController *)childController;
- (void)removeFromParentViewController;
- (void)willMoveToParentViewController:(UIViewController *)parent;
- (void)didMoveToParentViewController:(UIViewController *)parent;
- (void)beginAppearanceTransition:(BOOL)isAppearing animated:(BOOL)animated;
- (void)endAppearanceTransition;
@end

#define UIPopoverController OnegramIOS3PopoverController
#define UIPopoverControllerDelegate OnegramIOS3PopoverControllerDelegate
#define UIPopoverBackgroundView OnegramIOS3PopoverBackgroundView
@protocol UIPopoverControllerDelegate <NSObject>
@optional
- (void)popoverControllerDidDismissPopover:(id)popoverController;
- (void)popoverController:(id)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view;
@end

typedef NSUInteger UIPopoverArrowDirection;
#ifndef UIPopoverArrowDirectionUp
#define UIPopoverArrowDirectionUp 1U
#define UIPopoverArrowDirectionDown 2U
#define UIPopoverArrowDirectionLeft 4U
#define UIPopoverArrowDirectionRight 8U
#define UIPopoverArrowDirectionAny 15U
#define UIPopoverArrowDirectionUnknown ((NSUInteger)-1)
#endif

@interface UIPopoverBackgroundView : UIView
+ (CGFloat)arrowHeight;
+ (CGFloat)arrowBase;
+ (UIEdgeInsets)contentViewInsets;
@property (nonatomic) CGFloat arrowOffset;
@property (nonatomic) UIPopoverArrowDirection arrowDirection;
+ (BOOL)wantsDefaultContentAppearance;
@end

@interface UIViewController (OnegramIOS3PopoverCompatibility)
@property (nonatomic) CGSize contentSizeForViewInPopover;
@end

@interface UIPopoverController : NSObject
{
    UIViewController *_onegramContentViewController;
    CGSize _onegramPopoverContentSize;
    id<UIPopoverControllerDelegate> _onegramPopoverDelegate;
}
- (instancetype)initWithContentViewController:(UIViewController *)viewController;
@property (nonatomic, retain) UIViewController *contentViewController;
@property (nonatomic, assign) id<UIPopoverControllerDelegate> delegate;
@property (nonatomic) CGSize popoverContentSize;
@property (nonatomic, assign) Class popoverBackgroundViewClass;
- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated;
- (void)presentPopoverFromRect:(CGRect)rect inView:(UIView *)view permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated;
- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)item permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections animated:(BOOL)animated;
- (void)dismissPopoverAnimated:(BOOL)animated;
@end

#ifndef NSTextAlignmentLeft
typedef UITextAlignment NSTextAlignment;
#define NSTextAlignmentLeft UITextAlignmentLeft
#define NSTextAlignmentCenter UITextAlignmentCenter
#define NSTextAlignmentRight UITextAlignmentRight
#define NSTextAlignmentJustified ((NSTextAlignment)3)
#define NSTextAlignmentNatural ((NSTextAlignment)4)
#endif

#ifndef NSUnderlineStyleSingle
#define NSUnderlineStyleSingle 0x01
#endif

#define NSMutableParagraphStyle TGIOS3MutableParagraphStyle
@interface TGIOS3MutableParagraphStyle : NSObject <NSCopying, NSMutableCopying>
{
    CGFloat _lineSpacing;
    NSLineBreakMode _lineBreakMode;
    NSTextAlignment _alignment;
    CGFloat _paragraphSpacing;
    CGFloat _firstLineHeadIndent;
    CGFloat _lineHeightMultiple;
}
@property (nonatomic) CGFloat lineSpacing;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic) NSTextAlignment alignment;
@property (nonatomic) CGFloat paragraphSpacing;
@property (nonatomic) CGFloat firstLineHeadIndent;
@property (nonatomic) CGFloat lineHeightMultiple;
@end

#endif

#define NSOrderedSet TGIOS3OrderedSet
@interface TGIOS3OrderedSet : NSObject <NSCopying, NSFastEnumeration>
{
    NSArray *_onegramObjects;
}
- (instancetype)initWithArray:(NSArray *)array;
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly, copy) NSArray *array;
- (id)objectAtIndex:(NSUInteger)index;
- (BOOL)containsObject:(id)object;
- (NSArray *)allObjects;
@end

@interface TGIOS3AttributedString : NSObject <NSCopying, NSMutableCopying>
{
@protected
    NSMutableString *_onegramString;
}
- (instancetype)initWithString:(NSString *)string;
- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes;
- (instancetype)initWithAttributedString:(TGIOS3AttributedString *)attributedString;
@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) NSUInteger length;
- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range;
- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range;
- (NSDictionary *)attributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (id)attribute:(NSString *)attributeName atIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (TGIOS3AttributedString *)attributedSubstringFromRange:(NSRange)range;
- (BOOL)isEqualToAttributedString:(TGIOS3AttributedString *)other;
- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(NSUInteger)opts usingBlock:(void (^)(NSDictionary *attrs, NSRange range, BOOL *stop))block;
- (void)enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(NSUInteger)opts usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block;
@end

@interface TGIOS3MutableAttributedString : TGIOS3AttributedString
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string;
- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)range;
- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary *)attributes range:(NSRange)range;
- (void)removeAttribute:(NSString *)name range:(NSRange)range;
- (void)appendAttributedString:(TGIOS3AttributedString *)attributedString;
- (void)insertAttributedString:(TGIOS3AttributedString *)attributedString atIndex:(NSUInteger)index;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(TGIOS3AttributedString *)attributedString;
@end
@class UIImage;
@class UIScreen;

#ifdef __cplusplus
extern "C" {
#endif
extern void (*OnegramIOS3OffMainGraphicsHandler)(const void *caller);
void UIGraphicsBeginImageContextWithOptions(CGSize size, BOOL opaque, CGFloat scale);
#ifdef __cplusplus
}
#endif

@interface UIImage (OnegramIOS3ScaleCompatibility)
- (CGFloat)scale;
+ (UIImage *)imageWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
- (instancetype)initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)capInsets;
@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
typedef enum
{
    UIImageResizingModeTile,
    UIImageResizingModeStretch
} UIImageResizingMode;

@interface UIImage (OnegramIOS3ResizableImageDeclarations)
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)capInsets resizingMode:(UIImageResizingMode)resizingMode;
@end
#endif

@interface UIScreen (OnegramIOS3ScaleCompatibility)
- (CGFloat)scale;
@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@interface UIDevice (OnegramIOS3InterfaceIdiomCompatibility)
- (UIUserInterfaceIdiom)userInterfaceIdiom;
@end

@interface UIViewController (OnegramIOS3PresentationCompatibility)
@property (nonatomic) UIModalPresentationStyle modalPresentationStyle;
@property (nonatomic, readonly) UIViewController *presentedViewController;
@property (nonatomic, readonly) UIViewController *presentingViewController;
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
@end
#endif

@interface NSArray (OnegramIOS3Subscripting)
- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (id)firstObject;
- (id)lastObject;
- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block;
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block;
- (NSUInteger)indexOfObjectPassingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate;
- (NSArray *)sortedArrayUsingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr;
@end

@interface NSMutableArray (OnegramIOS3Subscripting)
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index;
@end

@interface NSSet (OnegramIOS3EnumerationCompatibility)
- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block;
@end

typedef NSUInteger NSSortOptions;
enum
{
    NSSortConcurrent = (1UL << 0),
    NSSortStable = (1UL << 4)
};

@interface NSMutableArray (OnegramIOS3SortingCompatibility)
- (void)sortUsingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr;
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr;
@end

@interface NSDictionary (OnegramIOS3Subscripting)
- (id)objectForKeyedSubscript:(id)key;
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id key, id obj, BOOL *stop))block;
- (NSArray *)keysSortedByValueUsingComparator:(NSComparisonResult (^)(id obj1, id obj2))cmptr;
@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@class TGIOS3AttributedString;

@interface NSString (OnegramIOS3EnumerationCompatibility)
- (void)enumerateSubstringsInRange:(NSRange)range options:(NSStringEnumerationOptions)opts usingBlock:(void (^)(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop))block;
- (void)enumerateLinesUsingBlock:(void (^)(NSString *line, BOOL *stop))block;
@end

@interface UILabel (OnegramIOS3AttributedTextCompatibility)
@property (nonatomic, copy) TGIOS3AttributedString *attributedText;
@end
#endif

@interface NSMutableDictionary (OnegramIOS3Subscripting)
- (void)setObject:(id)object forKeyedSubscript:(id<NSCopying>)key;
@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
#define NSJSONSerialization OnegramIOS3JSONSerialization
@interface NSJSONSerialization : NSObject
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)opt error:(NSError **)error;
+ (NSData *)dataWithJSONObject:(id)obj options:(NSJSONWritingOptions)opt error:(NSError **)error;
+ (BOOL)isValidJSONObject:(id)obj;
@end

@interface NSFileManager (OnegramIOS3URLCompatibility)
- (BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error;
- (BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
@end

@interface NSURL (OnegramIOS3PathCompatibility)
- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent;
- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent isDirectory:(BOOL)isDirectory;
- (NSString *)pathExtension;
- (NSString *)lastPathComponent;
- (NSArray *)pathComponents;
@end

@interface NSData (OnegramIOS3ReadingWritingCompatibility)
- (instancetype)initWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;
- (instancetype)initWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;
+ (NSData *)dataWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;
+ (NSData *)dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;
- (BOOL)writeToURL:(NSURL *)url options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)errorPtr;
@end

@interface UIButton (OnegramIOS3AttributedTitleCompatibility)
- (void)setAttributedTitle:(id)title forState:(UIControlState)state;
- (id)attributedTitleForState:(UIControlState)state;
@end
#endif

@interface NSIndexPath (OnegramIOS3CollectionViewCompatibility)
+ (NSIndexPath *)indexPathForItem:(NSInteger)item inSection:(NSInteger)section;
- (NSInteger)item;
@end

@interface NSObject (OnegramIOS3ScrollViewDelegateCompatibility)
- (void)scrollViewDidZoom:(UIScrollView *)scrollView;
- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(CGPoint *)targetContentOffset;
- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(UIView *)view;
@end

@interface NSBundle (OnegramIOS3NibLoading)
- (NSArray *)loadNibNamed:(NSString *)name owner:(id)owner options:(NSDictionary *)options;
@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 40000
@interface UINib : NSObject
{
    NSString *_name;
    NSBundle *_bundle;
}
+ (UINib *)nibWithNibName:(NSString *)name bundle:(NSBundle *)bundle;
- (NSArray *)instantiateWithOwner:(id)owner options:(NSDictionary *)options;
@end
#endif


#endif

#endif
