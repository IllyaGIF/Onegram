#import "FreedomUIKit.h"

#import "LegacyComponentsInternal.h"
#import "Freedom.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import "TGHacks.h"
#import "TGNavigationController.h"

#if defined(ONEGRAM_ARMV6)
static char TGIOS3MapUserTrackingModeKey;

static MKMapRect TGIOS3MapRectForRegion(MKCoordinateRegion region)
{
    MKMapPoint topLeft = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude + region.span.latitudeDelta * 0.5, region.center.longitude - region.span.longitudeDelta * 0.5));
    MKMapPoint bottomRight = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude - region.span.latitudeDelta * 0.5, region.center.longitude + region.span.longitudeDelta * 0.5));
    return MKMapRectMake(MIN(topLeft.x, bottomRight.x), MIN(topLeft.y, bottomRight.y), fabs(bottomRight.x - topLeft.x), fabs(bottomRight.y - topLeft.y));
}

static MKCoordinateRegion TGIOS3RegionForMapRect(MKMapRect rect)
{
    if (MKMapRectIsNull(rect))
        return MKCoordinateRegionMake(CLLocationCoordinate2DMake(0.0, 0.0), MKCoordinateSpanMake(180.0, 360.0));

    MKMapPoint centerPoint = MKMapPointMake(rect.origin.x + rect.size.width * 0.5, rect.origin.y + rect.size.height * 0.5);
    CLLocationCoordinate2D center = MKCoordinateForMapPoint(centerPoint);
    CLLocationCoordinate2D topLeft = MKCoordinateForMapPoint(rect.origin);
    CLLocationCoordinate2D bottomRight = MKCoordinateForMapPoint(MKMapPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height));
    return MKCoordinateRegionMake(center, MKCoordinateSpanMake(fabs(topLeft.latitude - bottomRight.latitude), fabs(bottomRight.longitude - topLeft.longitude)));
}

@implementation MKMapView (TGIOS3MapKitCompatibility)

- (MKUserTrackingMode)userTrackingMode
{
    NSNumber *value = objc_getAssociatedObject(self, &TGIOS3MapUserTrackingModeKey);
    return value == nil ? MKUserTrackingModeNone : (MKUserTrackingMode)[value integerValue];
}

- (void)setUserTrackingMode:(MKUserTrackingMode)mode
{
    [self setUserTrackingMode:mode animated:NO];
}

- (void)setUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated
{
    MKUserTrackingMode previousMode = self.userTrackingMode;
    if (previousMode == mode)
        return;

    objc_setAssociatedObject(self, &TGIOS3MapUserTrackingModeKey, [NSNumber numberWithInteger:mode], OBJC_ASSOCIATION_RETAIN);

    if (mode != MKUserTrackingModeNone && self.userLocation.location != nil)
        [self setCenterCoordinate:self.userLocation.location.coordinate animated:animated];

    id<MKMapViewDelegate> delegate = self.delegate;
    SEL selector = @selector(mapView:didChangeUserTrackingMode:animated:);
    if ([delegate respondsToSelector:selector])
        ((void (*)(id, SEL, MKMapView *, MKUserTrackingMode, BOOL))objc_msgSend)(delegate, selector, self, mode, animated);
}

- (MKMapRect)visibleMapRect
{
    return TGIOS3MapRectForRegion(self.region);
}

- (NSSet *)annotationsInMapRect:(MKMapRect)mapRect
{
    NSMutableSet *result = [NSMutableSet set];
    for (id<MKAnnotation> annotation in self.annotations)
    {
        if (MKMapRectContainsPoint(mapRect, MKMapPointForCoordinate(annotation.coordinate)))
            [result addObject:annotation];
    }
    return result;
}

- (MKMapRect)mapRectThatFits:(MKMapRect)mapRect edgePadding:(UIEdgeInsets)insets
{
    if (MKMapRectIsNull(mapRect))
        return mapRect;

    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    CGFloat availableWidth = MAX(1.0f, width - insets.left - insets.right);
    CGFloat availableHeight = MAX(1.0f, height - insets.top - insets.bottom);
    double expandedWidth = mapRect.size.width * width / availableWidth;
    double expandedHeight = mapRect.size.height * height / availableHeight;
    double horizontalShift = ((insets.left - insets.right) * 0.5 / availableWidth) * mapRect.size.width;
    double verticalShift = ((insets.top - insets.bottom) * 0.5 / availableHeight) * mapRect.size.height;
    MKMapRect expanded = MKMapRectMake(mapRect.origin.x - (expandedWidth - mapRect.size.width) * 0.5 - horizontalShift,
                                       mapRect.origin.y - (expandedHeight - mapRect.size.height) * 0.5 - verticalShift,
                                       expandedWidth, expandedHeight);
    MKCoordinateRegion fittedRegion = [self regionThatFits:TGIOS3RegionForMapRect(expanded)];
    return TGIOS3MapRectForRegion(fittedRegion);
}

- (void)setVisibleMapRect:(MKMapRect)mapRect animated:(BOOL)animated
{
    if (MKMapRectIsNull(mapRect))
        return;
    [self setRegion:[self regionThatFits:TGIOS3RegionForMapRect(mapRect)] animated:animated];
}

- (void)setVisibleMapRect:(MKMapRect)mapRect edgePadding:(UIEdgeInsets)insets animated:(BOOL)animated
{
    [self setVisibleMapRect:[self mapRectThatFits:mapRect edgePadding:insets] animated:animated];
}

@end

@implementation CLLocation (TGIOS3DistanceCompatibility)

- (CLLocationDistance)distanceFromLocation:(const CLLocation *)location
{
    return [self getDistanceFrom:location];
}

@end
#endif

#define DEBUG_KEYBOARD_QUEUE false

void freedomUIKitInit2();
void freedomUIKitInit3();

#if defined(DEBUG) && DEBUG_KEYBOARD_QUEUE
void freedomUIKitInit4();
#endif

void freedomUIKitInit()
{   
    freedomUIKitInit2();
    freedomUIKitInit3();
    
#if defined(DEBUG) && DEBUG_KEYBOARD_QUEUE
    freedomUIKitInit4();
#endif
}

#pragma mark -

static int freedomUIKit_decorated2(__unused id self, __unused SEL _cmd)
{
    return 0;
}

void freedomUIKitInit2()
{
    if (iosMajorVersion() == 6)
    {
        FreedomDecoration instanceDecorations[] = {
            { .name = 0,
              .imp = (IMP)&freedomUIKit_decorated2,
              .newIdentifier = (FreedomIdentifier){ .string = "3066a13b3e6b", .key = 0x52d50551U },
              .newEncoding = (FreedomIdentifier){ .string = "1a7291", .key = 0x3ab3273U }
            }
        };
        
        freedomClassAutoDecorate(0x1468e61aU, NULL, 0, instanceDecorations, sizeof(instanceDecorations) / sizeof(instanceDecorations[0]));
    }
}

#pragma mark -

static bool test3 = false;
static bool test3_1 = false;

@implementation FFNotificationCenter

static bool (^shouldRotateBlock)() = nil;

+ (void)setShouldRotateBlock:(bool (^)())block
{
    shouldRotateBlock = [block copy];
}

- (void)postNotificationName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    bool clearFlag = false;
    if ([aName isEqualToString:UIDeviceOrientationDidChangeNotification])
    {
        clearFlag = true;
        test3 = true;
        test3_1 = true;
    }
    
    if ([aName isEqualToString:UIDeviceOrientationDidChangeNotification])
    {
        if (shouldRotateBlock == nil || shouldRotateBlock())
            [super postNotificationName:aName object:anObject userInfo:aUserInfo];
    }
    else
        [super postNotificationName:aName object:anObject userInfo:aUserInfo];
    
    if (clearFlag)
        test3 = false;
}

@end

bool freedomUIKitTest3()
{
    return test3;
}

bool freedomUIKitTest3_1()
{
    bool value = test3_1;
    test3_1 = false;
    return value;
}

void freedomUIKitInit3()
{
    object_setClass([NSNotificationCenter defaultCenter], [FFNotificationCenter class]);
}

#pragma mark -

static bool test4 = false;
static bool test4_1 = false;

@interface TGHelperQueue : NSProxy
{
    id _target;
}

@end

@implementation TGHelperQueue

- (instancetype)initWithTargetQueue:(id)target
{
    if (self != nil)
    {
        _target = target;
    }
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [_target methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)__unused invocation
{
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    static char *name = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        name = copyFreedomIdentifierValue((FreedomIdentifier){ .string = "536772a971686fb4484777b1706768b6574769b8626f75b4576e7eb9", .key = 0xdd1b0624U });
    });
    
    if (!strcmp(sel_getName(selector), name))
    {
        if (test4 || test4_1)
        {
            return nil;
        }
    }

    return _target;
}

- (void)doWork
{
}

@end

static UIView *freedomUIKitFindView(UIView *view)
{
    if (view == nil)
        return nil;
    
    if (object_getClass(view) == freedomClass(0x9cb128e7U))
        return view;
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = freedomUIKitFindView(subview);
        if (result != nil)
            return result;
    }
    
    return nil;
}

void freedomUIKitTest4(dispatch_block_t block)
{
    if (iosMajorVersion() < 7 || iosMajorVersion() > 7 || (iosMajorVersion() == 7 && iosMinorVersion() >= 1))
    {
        if (block != nil)
            block();
    }
    else
    {
        UIView *view = freedomUIKitFindView([TGHacks applicationKeyboardWindow]);
        if (view != nil)
        {
            static ptrdiff_t queueOffset = -1;
            static bool queueInitialized = false;
            if (!queueInitialized)
            {
                queueInitialized = true;
                queueOffset = freedomIvarOffset(object_getClass(view), 0xba913cbU);
            }
            
            if (queueOffset >= 0)
            {
#if defined(ONEGRAM_ARMV6)
                void *queueStorage = (void *)(((uint8_t *)(__bridge void *)view) + queueOffset);
                NSObject *queue = OnegramIOS3LoadStrongIvar(queueStorage);
                if (queue != nil)
                {
                    if (object_getClass(queue) != [TGHelperQueue class])
                    {
                        TGHelperQueue *helper = [[TGHelperQueue alloc] initWithTargetQueue:queue];
                        OnegramIOS3StoreStrongIvar(queueStorage, helper);
                    }
                }
#else
                __strong NSObject **queue = (__strong NSObject **)(void *)(((uint8_t *)(__bridge void *)view) + queueOffset);
                if (*queue != nil)
                {
                    if (object_getClass(*queue) != [TGHelperQueue class])
                    {
                        TGHelperQueue *helper = [[TGHelperQueue alloc] initWithTargetQueue:*queue];
                        *queue = (NSObject *)helper;
                    }
                }
#endif
            }
        }
        
        bool previousTest4 = test4;
        test4 = true;
        
        if (block != nil)
            block();
        
        test4 = previousTest4;
    }
}

void freedomUIKitTest4_1()
{
    test4_1 = true;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        test4_1 = false;
    });
}

#if defined(DEBUG) && DEBUG_KEYBOARD_QUEUE
void freedomUIKit_decorated4_1(id self, SEL _cmd, id arg1)
{
    static void (*nativeImpl)(id, SEL, id) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        nativeImpl = (void *)freedomNativeImpl([self class], _cmd);
    });
    
    if (nativeImpl != NULL)
        nativeImpl(self, _cmd, arg1);
    
}


void freedomUIKit_decorated4_2(id self, SEL _cmd)
{
    static void (*nativeImpl)(id, SEL) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        nativeImpl = (void *)freedomNativeImpl([self class], _cmd);
    });
    
    if (nativeImpl != NULL)
        nativeImpl(self, _cmd);
    
}

void freedomUIKitInit4()
{
    FreedomDecoration instanceDecorations[] = {
        { .name = 0xbb6dbb9eU,
            .imp = (IMP)&freedomUIKit_decorated4_1,
            .newIdentifier = FreedomIdentifierEmpty,
            .newEncoding = FreedomIdentifierEmpty
        },
        { .name = 0x757d9b1cU,
            .imp = (IMP)&freedomUIKit_decorated4_2,
            .newIdentifier = FreedomIdentifierEmpty,
            .newEncoding = FreedomIdentifierEmpty
        }
    };
    
    freedomClassAutoDecorate(0xfed2643dU, NULL, 0, instanceDecorations, sizeof(instanceDecorations) / sizeof(instanceDecorations[0]));
}
#endif
