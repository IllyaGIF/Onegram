#import "TGHacks.h"

#import "LegacyComponentsInternal.h"
#import "TGAnimationBlockDelegate.h"

#import "FreedomUIKit.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import <objc/runtime.h>
#import <objc/message.h>

#import "TGViewController.h"
#import "TGNavigationBar.h"
#import <QuartzCore/QuartzCore.h>

#import <dlfcn.h>
static float animationDurationFactor = 1.0f;
static float secondaryAnimationDurationFactor = 1.0f;
static bool forceSystemCurve = false;

static bool forceMovieAnimatedScaleMode = false;

static bool forcePerformWithAnimationFlag = false;

static UIScrollView *TGFindScrollViewInView(UIView *view)
{
    if ([view isKindOfClass:[UIScrollView class]])
        return (UIScrollView *)view;

    for (UIView *subview in view.subviews)
    {
        UIScrollView *scrollView = TGFindScrollViewInView(subview);
        if (scrollView != nil)
            return scrollView;
    }

    return nil;
}

UIScrollView *TGUIWebViewScrollView(UIWebView *webView)
{
    if (webView == nil)
        return nil;

    return TGFindScrollViewInView(webView);
}

bool TGShareItemsViaLegacyPasteboard(NSArray *items)
{
    if (iosMajorVersion() >= 6)
        return false;

    NSMutableArray *strings = [[NSMutableArray alloc] init];
    UIImage *image = nil;
    for (id item in items)
    {
        if ([item isKindOfClass:[NSString class]])
            [strings addObject:item];
        else if ([item isKindOfClass:[NSURL class]])
            [strings addObject:[item absoluteString]];
        else if (image == nil && [item isKindOfClass:[UIImage class]])
            image = item;
    }

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (strings.count != 0)
        pasteboard.string = [strings componentsJoinedByString:@"\n"];
    else if (image != nil)
        pasteboard.image = image;

    NSString *message = TGLocalized(@"Username.LinkCopied");
    if (message.length == 0 || [message isEqualToString:@"Username.LinkCopied"])
        message = @"Copied to Clipboard";
    [[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:TGLocalized(@"Common.OK") otherButtonTitles:nil] show];
    return true;
}

@interface TGWeakObjectReference : NSObject
{
    __weak id _object;
}

- (instancetype)initWithObject:(id)object;
- (id)object;

@end

@implementation TGWeakObjectReference

- (instancetype)initWithObject:(id)object
{
    self = [super init];
    if (self != nil)
        _object = object;
    return self;
}

- (id)object
{
    return _object;
}

@end

@interface TGWeakObjectSet : NSObject
{
    NSMutableArray *_entries;
}

@end

@implementation TGWeakObjectSet

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _entries = [[NSMutableArray alloc] init];
    return self;
}

- (void)purge
{
    for (NSInteger i = (NSInteger)_entries.count - 1; i >= 0; i--)
    {
        TGWeakObjectReference *entry = [_entries objectAtIndex:(NSUInteger)i];
        if ([entry object] == nil)
            [_entries removeObjectAtIndex:(NSUInteger)i];
    }
}

- (void)addObject:(id)object
{
    if (object == nil)
        return;
    @synchronized (self)
    {
        [self purge];
        for (TGWeakObjectReference *entry in _entries)
        {
            if ([entry object] == object)
                return;
        }
        [_entries addObject:[[TGWeakObjectReference alloc] initWithObject:object]];
    }
}

- (void)removeObject:(id)object
{
    @synchronized (self)
    {
        for (NSInteger i = (NSInteger)_entries.count - 1; i >= 0; i--)
        {
            TGWeakObjectReference *entry = [_entries objectAtIndex:(NSUInteger)i];
            id value = [entry object];
            if (value == nil || value == object)
                [_entries removeObjectAtIndex:(NSUInteger)i];
        }
    }
}

- (NSArray *)allObjects
{
    @synchronized (self)
    {
        [self purge];
        NSMutableArray *objects = [[NSMutableArray alloc] initWithCapacity:_entries.count];
        for (TGWeakObjectReference *entry in _entries)
        {
            id object = [entry object];
            if (object != nil)
                [objects addObject:object];
        }
        return objects;
    }
}

- (id)anyObject
{
    @synchronized (self)
    {
        [self purge];
        for (TGWeakObjectReference *entry in _entries)
        {
            id object = [entry object];
            if (object != nil)
                return object;
        }
        return nil;
    }
}

- (NSUInteger)count
{
    @synchronized (self)
    {
        [self purge];
        return _entries.count;
    }
}

@end

@interface TGWeakValueMap : NSObject
{
    NSMutableDictionary *_entries;
}

@end

@implementation TGWeakValueMap

- (instancetype)init
{
    self = [super init];
    if (self != nil)
        _entries = [[NSMutableDictionary alloc] init];
    return self;
}

- (id)objectForKey:(id)key
{
    if (key == nil)
        return nil;
    @synchronized (self)
    {
        TGWeakObjectReference *entry = [_entries objectForKey:key];
        id object = [entry object];
        if (entry != nil && object == nil)
            [_entries removeObjectForKey:key];
        return object;
    }
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key
{
    if (key == nil)
        return;
    @synchronized (self)
    {
        if (object == nil)
            [_entries removeObjectForKey:key];
        else
            [_entries setObject:[[TGWeakObjectReference alloc] initWithObject:object] forKey:key];
    }
}

- (void)removeObjectForKey:(id)key
{
    if (key == nil)
        return;
    @synchronized (self)
    {
        [_entries removeObjectForKey:key];
    }
}

- (NSDictionary *)dictionaryRepresentation
{
    @synchronized (self)
    {
        NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:_entries.count];
        NSMutableArray *deadKeys = [[NSMutableArray alloc] init];
        for (id key in _entries)
        {
            TGWeakObjectReference *entry = [_entries objectForKey:key];
            id object = [entry object];
            if (object != nil)
                [dictionary setObject:object forKey:key];
            else
                [deadKeys addObject:key];
        }
        [_entries removeObjectsForKeys:deadKeys];
        return dictionary;
    }
}

@end

id TGWeakValueMapTable(void)
{
    if (iosMajorVersion() < 6)
        return [[TGWeakValueMap alloc] init];

    Class mapTableClass = NSClassFromString(@"NSMapTable");
    SEL mapSelector = NSSelectorFromString(@"strongToWeakObjectsMapTable");
    if (mapTableClass != Nil && [mapTableClass respondsToSelector:mapSelector])
    {
        id (*function)(id, SEL) = (id (*)(id, SEL))[mapTableClass methodForSelector:mapSelector];
        if (function != NULL)
            return function(mapTableClass, mapSelector);
    }

    return [[TGWeakValueMap alloc] init];
}

id TGWeakObjectHashTable(void)
{
    if (iosMajorVersion() < 6)
        return [[TGWeakObjectSet alloc] init];

    Class hashTableClass = NSClassFromString(@"NSHashTable");
    SEL hashSelector = NSSelectorFromString(@"weakObjectsHashTable");
    if (hashTableClass != Nil && [hashTableClass respondsToSelector:hashSelector])
    {
        id (*function)(id, SEL) = (id (*)(id, SEL))[hashTableClass methodForSelector:hashSelector];
        if (function != NULL)
            return function(hashTableClass, hashSelector);
    }

    return [[TGWeakObjectSet alloc] init];
}

typedef struct
{
    __unsafe_unretained Class target;
    SEL selector;
    __unsafe_unretained Class source;
    SEL fallback;
    bool isClassMethod;
} OGCompatEntry;

#define OG_COMPAT_INSTANCE(cls, sel, fallbackSel) { (cls), (sel), (cls), (fallbackSel), false }
#define OG_COMPAT_INSTANCE_FROM(cls, sourceCls, sel, fallbackSel) { (cls), (sel), (sourceCls), (fallbackSel), false }
#define OG_COMPAT_CLASS(cls, sel, fallbackSel) { (cls), (sel), (cls), (fallbackSel), true }

static void OGCompatInstallEntries(const OGCompatEntry *entries, NSUInteger count)
{
    for (NSUInteger i = 0; i < count; i++)
    {
        const OGCompatEntry *entry = &entries[i];
        if (entry->target == Nil)
            continue;
        
        Method existing = NULL;
        Method fallback = NULL;
        Class destination = entry->target;
        if (entry->isClassMethod)
        {
            existing = class_getClassMethod(entry->target, entry->selector);
            fallback = class_getClassMethod(entry->source, entry->fallback);
            destination = object_getClass((id)entry->target);
        }
        else
        {
            existing = class_getInstanceMethod(entry->target, entry->selector);
            fallback = class_getInstanceMethod(entry->source, entry->fallback);
        }
        
        if (existing == NULL && fallback != NULL)
            class_addMethod(destination, entry->selector, method_getImplementation(fallback), method_getTypeEncoding(fallback));
    }
}

static void OGCompatInstallTextView(Class cls)
{
    Class source = [UITextView class];
    const OGCompatEntry entries[] =
    {
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(layoutManager), @selector(og_compat_layoutManager)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(attributedText), @selector(tg_ios5_attributedText)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(setAttributedText:), @selector(tg_ios5_setAttributedText:)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(typingAttributes), @selector(tg_ios5_typingAttributes)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(setTypingAttributes:), @selector(tg_ios5_setTypingAttributes:)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(textContainer), @selector(og_compat_textContainer)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(textStorage), @selector(og_compat_textStorage)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(textContainerInset), @selector(og_compat_textContainerInset)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(setTextContainerInset:), @selector(og_compat_setTextContainerInset:)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(isSelectable), @selector(og_compat_isSelectable)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(setSelectable:), @selector(og_compat_setSelectable:)),
        OG_COMPAT_INSTANCE_FROM(cls, source, @selector(initWithFrame:textContainer:), @selector(og_compat_initWithFrame:textContainer:))
    };
    OGCompatInstallEntries(entries, sizeof(entries) / sizeof(entries[0]));
}

static id TGIOS5ArrayObjectAtIndexedSubscript(id self, SEL __unused _cmd, NSUInteger index)
{
    return [self objectAtIndex:index];
}

static void TGIOS5MutableArraySetObjectAtIndexedSubscript(id self, SEL __unused _cmd, id object, NSUInteger index)
{
    NSUInteger count = [self count];
    
    if (index < count)
        [self replaceObjectAtIndex:index withObject:object];
    else if (index == count)
        [self addObject:object];
}

static id TGIOS5DictionaryObjectForKeyedSubscript(id self, SEL __unused _cmd, id key)
{
    return [self objectForKey:key];
}

static void TGIOS5MutableDictionarySetObjectForKeyedSubscript(id self, SEL __unused _cmd, id object, id key)
{
    if (object != nil)
        [self setObject:object forKey:key];
    else
        [self removeObjectForKey:key];
}

static void TGIOS5InstallMethod(Class cls, SEL selector, IMP implementation, const char *types)
{
    if (cls == Nil)
        return;
    
    if (class_getInstanceMethod(cls, selector) == NULL)
        class_addMethod(cls, selector, implementation, types);
}

static void TGInstallIOS5SubscriptingCompatibility(void)
{
    Method arraySourceMethod = class_getInstanceMethod([NSArray class], @selector(objectAtIndex:));
    Method dictionarySourceMethod = class_getInstanceMethod([NSDictionary class], @selector(objectForKey:));
    Method dictionarySetterSourceMethod = class_getInstanceMethod([NSMutableDictionary class], @selector(setObject:forKey:));
    
    const char *arrayGetterTypes =
    arraySourceMethod != NULL
    ? method_getTypeEncoding(arraySourceMethod)
    : "@@:I";
    
    const char *dictionaryGetterTypes =
    dictionarySourceMethod != NULL
    ? method_getTypeEncoding(dictionarySourceMethod)
    : "@@:@";
    
    const char *dictionarySetterTypes =
    dictionarySetterSourceMethod != NULL
    ? method_getTypeEncoding(dictionarySetterSourceMethod)
    : "v@:@@";
    
    TGIOS5InstallMethod(
                        [NSArray class],
                        @selector(objectAtIndexedSubscript:),
                        (IMP)TGIOS5ArrayObjectAtIndexedSubscript,
                        arrayGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSArrayI"),
                        @selector(objectAtIndexedSubscript:),
                        (IMP)TGIOS5ArrayObjectAtIndexedSubscript,
                        arrayGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSArrayM"),
                        @selector(objectAtIndexedSubscript:),
                        (IMP)TGIOS5ArrayObjectAtIndexedSubscript,
                        arrayGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSArray0"),
                        @selector(objectAtIndexedSubscript:),
                        (IMP)TGIOS5ArrayObjectAtIndexedSubscript,
                        arrayGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSSingleObjectArrayI"),
                        @selector(objectAtIndexedSubscript:),
                        (IMP)TGIOS5ArrayObjectAtIndexedSubscript,
                        arrayGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        [NSMutableArray class],
                        @selector(setObject:atIndexedSubscript:),
                        (IMP)TGIOS5MutableArraySetObjectAtIndexedSubscript,
                        "v@:@I"
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSArrayM"),
                        @selector(setObject:atIndexedSubscript:),
                        (IMP)TGIOS5MutableArraySetObjectAtIndexedSubscript,
                        "v@:@I"
                        );
    
    TGIOS5InstallMethod(
                        [NSDictionary class],
                        @selector(objectForKeyedSubscript:),
                        (IMP)TGIOS5DictionaryObjectForKeyedSubscript,
                        dictionaryGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSDictionaryI"),
                        @selector(objectForKeyedSubscript:),
                        (IMP)TGIOS5DictionaryObjectForKeyedSubscript,
                        dictionaryGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSDictionaryM"),
                        @selector(objectForKeyedSubscript:),
                        (IMP)TGIOS5DictionaryObjectForKeyedSubscript,
                        dictionaryGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSDictionary0"),
                        @selector(objectForKeyedSubscript:),
                        (IMP)TGIOS5DictionaryObjectForKeyedSubscript,
                        dictionaryGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSSingleEntryDictionaryI"),
                        @selector(objectForKeyedSubscript:),
                        (IMP)TGIOS5DictionaryObjectForKeyedSubscript,
                        dictionaryGetterTypes
                        );
    
    TGIOS5InstallMethod(
                        [NSMutableDictionary class],
                        @selector(setObject:forKeyedSubscript:),
                        (IMP)TGIOS5MutableDictionarySetObjectForKeyedSubscript,
                        dictionarySetterTypes
                        );
    
    TGIOS5InstallMethod(
                        objc_getClass("__NSDictionaryM"),
                        @selector(setObject:forKeyedSubscript:),
                        (IMP)TGIOS5MutableDictionarySetObjectForKeyedSubscript,
                        dictionarySetterTypes
                        );
}

void SwizzleClassMethod(Class c, SEL orig, SEL new)
{
    Method origMethod = class_getClassMethod(c, orig);
    Method newMethod = class_getClassMethod(c, new);
    
    if (origMethod == nil || newMethod == nil)
    {
        NSLog(@"Attempt to swizzle nonexistent class methods!");
        return;
    }
    
    c = object_getClass((id)c);
    
    if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else
        method_exchangeImplementations(origMethod, newMethod);
}

void SwizzleInstanceMethod(Class c, SEL orig, SEL new)
{
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getInstanceMethod(c, orig);
    newMethod = class_getInstanceMethod(c, new);
    
    if ((origMethod != nil) && (newMethod != nil))
    {
        if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        else
            method_exchangeImplementations(origMethod, newMethod);
    }
    else
    {
        NSLog(@"Attempt to swizzle nonexistent methods!");
    }
}

void SwizzleInstanceMethodWithAnotherClass(Class c1, SEL orig, Class c2, SEL new)
{
    Method origMethod = nil, newMethod = nil;
    
    origMethod = class_getInstanceMethod(c1, orig);
    newMethod = class_getInstanceMethod(c2, new);
    
    if ((origMethod != nil) && (newMethod != nil))
    {
        if (class_addMethod(c1, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
            class_replaceMethod(c1, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
        else
            method_exchangeImplementations(origMethod, newMethod);
    }
    else
    {
        NSLog(@"Attempt to swizzle nonexistent methods!");
    }
}

void InjectClassMethodFromAnotherClass(Class toClass, Class fromClass, SEL fromSelector, SEL toSeletor)
{
    if (class_getClassMethod(toClass, toSeletor) != nil)
        return;

    Method method = class_getClassMethod(fromClass, fromSelector);
    
    if (method != nil)
    {
        Class metaClass = object_getClass((id)toClass);
        if (metaClass == Nil || !class_addMethod(metaClass, toSeletor, method_getImplementation(method), method_getTypeEncoding(method)))
            NSLog(@"Attempt to add method failed");
    }
    else
    {
        NSLog(@"Attempt to add nonexistent method");
    }
}

void InjectInstanceMethodFromAnotherClass(Class toClass, Class fromClass, SEL fromSelector, SEL toSeletor)
{
    Method method = class_getInstanceMethod(fromClass, fromSelector);
    
    if (method != nil)
    {
        if (!class_addMethod(toClass, toSeletor, method_getImplementation(method), method_getTypeEncoding(method)))
            NSLog(@"Attempt to add method failed");
    }
    else
    {
        NSLog(@"Attempt to add nonexistent method");
    }
}

@interface UIView (TGHacks)

+ (void)telegraph_setAnimationDuration:(NSTimeInterval)duration;
+ (void)TG_performWithoutAnimation:(void (^)(void))actionsWithoutAnimation;

- (UIView *)TG_snapshotViewAfterScreenUpdates:(BOOL)afterUpdates;
- (UIView *)og_compat_resizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)afterUpdates withCapInsets:(UIEdgeInsets)capInsets;

@end

static UIImage *OGCompatLayerImage(CALayer *layer, CGRect rect, BOOL opaque)
{
    UIGraphicsBeginImageContextWithOptions(rect.size, opaque, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
    [layer renderInContext:context];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@implementation UIView (TGHacks)

+ (void)telegraph_setAnimationDuration:(NSTimeInterval)duration
{
    [self telegraph_setAnimationDuration:(duration * animationDurationFactor)];
}

+ (void)telegraph_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    if (forceSystemCurve)
        options |= (7 << 16);
    
    [self telegraph_animateWithDuration:duration * secondaryAnimationDurationFactor delay:delay options:options animations:animations completion:completion];
}

+ (void)TG_performWithoutAnimation:(void (^)(void))actionsWithoutAnimation
{
    float lastDurationFactor = animationDurationFactor;
    animationDurationFactor = 0.0f;
    
    bool animationsWereEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:false];
    
    @try
    {
        if (actionsWithoutAnimation)
            actionsWithoutAnimation();
    }
    @finally
    {
        [UIView setAnimationsEnabled:animationsWereEnabled];
        animationDurationFactor = lastDurationFactor;
    }
}

+ (void)TG_performWithoutAnimation_maybeNot:(void (^)(void))actionsWithoutAnimation
{
    if (actionsWithoutAnimation)
    {
        if (forcePerformWithAnimationFlag)
            actionsWithoutAnimation();
        else
            [self TG_performWithoutAnimation_maybeNot:actionsWithoutAnimation];
    }
}

- (UIView *)TG_snapshotViewAfterScreenUpdates:(BOOL)__unused afterUpdates
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, 0.0f);
    
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (image != nil)
        return [[UIImageView alloc] initWithImage:image];
    
    return nil;
}

- (UIView *)og_compat_resizableSnapshotViewFromRect:(CGRect)rect afterScreenUpdates:(BOOL)__unused afterUpdates withCapInsets:(UIEdgeInsets)capInsets
{
    UIImage *image = OGCompatLayerImage(self.layer, rect, self.opaque);
    if (image == nil)
        return nil;
    
    BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(capInsets, UIEdgeInsetsZero);
    UIImageView *imageView = [[UIImageView alloc] initWithImage:stretchable ? [image resizableImageWithCapInsets:capInsets] : image];
    imageView.frame = CGRectMake(0.0f, 0.0f, rect.size.width, rect.size.height);
    
    return imageView;
}

@end


typedef struct
{
    NSInteger count;
    CGFloat sourceStart[3];
    CGFloat sourceLength[3];
    CGFloat targetStart[3];
    CGFloat length;
    NSInteger cap;
    bool identity;
} TGIOS4ResizableAxis;

static TGIOS4ResizableAxis TGIOS4ResizableAxisMake(CGFloat leading, CGFloat trailing, CGFloat length)
{
    TGIOS4ResizableAxis axis;
    memset(&axis, 0, sizeof(axis));

    CGFloat leadingCap = length >= 1.0f ? MIN(CGCeil(MAX(0.0f, leading)), length - 1.0f) : 0.0f;
    CGFloat trailingCap = length >= 1.0f ? MIN(CGCeil(MAX(0.0f, trailing)), length - 1.0f - leadingCap) : 0.0f;

    if (leadingCap < 1.0f && trailingCap < 1.0f)
    {
        axis.count = 1;
        axis.sourceStart[0] = 0.0f;
        axis.sourceLength[0] = length;
        axis.targetStart[0] = 0.0f;
        axis.length = length;
        axis.cap = 0;
        axis.identity = true;
        return axis;
    }

    CGFloat leadingTarget = leadingCap >= 1.0f ? leadingCap : 1.0f;

    axis.count = 3;
    axis.sourceStart[0] = leadingCap >= 1.0f ? 0.0f : leadingCap;
    axis.sourceLength[0] = leadingCap >= 1.0f ? leadingCap : 1.0f;
    axis.targetStart[0] = 0.0f;
    axis.sourceStart[1] = leadingCap;
    axis.sourceLength[1] = 1.0f;
    axis.targetStart[1] = leadingTarget;
    axis.sourceStart[2] = length - trailingCap;
    axis.sourceLength[2] = trailingCap;
    axis.targetStart[2] = leadingTarget + 1.0f;
    axis.length = leadingTarget + 1.0f + trailingCap;
    axis.cap = (NSInteger)leadingTarget;
    axis.identity = leadingCap >= 1.0f && ABS(axis.length - length) < FLT_EPSILON;
    return axis;
}

@interface UIImage (TGIOS4ResizableImageCompatibility)
- (UIImage *)tg_ios4_resizableImageWithCapInsets:(UIEdgeInsets)capInsets;
@end

@implementation UIImage (TGIOS4ResizableImageCompatibility)

- (UIImage *)tg_ios4_resizableImageWithCapInsets:(UIEdgeInsets)capInsets
{
    CGImageRef cgImage = self.CGImage;
    CGSize size = self.size;
    if (cgImage == NULL || size.width <= 0.0f || size.height <= 0.0f)
        return self;

    TGIOS4ResizableAxis horizontal = TGIOS4ResizableAxisMake(capInsets.left, capInsets.right, size.width);
    TGIOS4ResizableAxis vertical = TGIOS4ResizableAxisMake(capInsets.top, capInsets.bottom, size.height);
    if (horizontal.identity && vertical.identity)
        return [self stretchableImageWithLeftCapWidth:horizontal.cap topCapHeight:vertical.cap];

    CGFloat scale = self.scale > FLT_EPSILON ? self.scale : 1.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(horizontal.length, vertical.length), false, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    for (NSInteger y = 0; y < vertical.count; y++)
    {
        for (NSInteger x = 0; x < horizontal.count; x++)
        {
            CGRect pixelRect = CGRectMake(CGFloor(horizontal.sourceStart[x] * scale + 0.5f), CGFloor(vertical.sourceStart[y] * scale + 0.5f), CGFloor(horizontal.sourceLength[x] * scale + 0.5f), CGFloor(vertical.sourceLength[y] * scale + 0.5f));
            if (pixelRect.size.width < 1.0f || pixelRect.size.height < 1.0f)
                continue;

            CGImageRef sliceRef = CGImageCreateWithImageInRect(cgImage, pixelRect);
            if (sliceRef == NULL)
                continue;

            UIImage *slice = [UIImage imageWithCGImage:sliceRef scale:scale orientation:UIImageOrientationUp];
            [slice drawInRect:CGRectMake(horizontal.targetStart[x], vertical.targetStart[y], pixelRect.size.width / scale, pixelRect.size.height / scale) blendMode:kCGBlendModeCopy alpha:1.0f];
            CGImageRelease(sliceRef);
        }
    }
    UIImage *templateImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (templateImage == nil)
        return [self stretchableImageWithLeftCapWidth:horizontal.cap topCapHeight:vertical.cap];
    return [templateImage stretchableImageWithLeftCapWidth:horizontal.cap topCapHeight:vertical.cap];
}

@end

@implementation TGHacks

+ (void)load
{
    @autoreleasepool
    {
        TGInstallIOS5SubscriptingCompatibility();
    
        const OGCompatEntry entries[] =
        {
            OG_COMPAT_INSTANCE([UIImage class], @selector(resizableImageWithCapInsets:), @selector(tg_ios4_resizableImageWithCapInsets:)),
            OG_COMPAT_INSTANCE([UIView class], @selector(setAccessibilityIgnoresInvertColors:), @selector(og_compat_setAccessibilityIgnoresInvertColors:)),
            OG_COMPAT_INSTANCE([UIView class], @selector(accessibilityIgnoresInvertColors), @selector(og_compat_accessibilityIgnoresInvertColors)),
            OG_COMPAT_CLASS([UIView class], @selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:), @selector(og_compat_animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)),
    
#if !defined(ONEGRAM_ARMV6)
            OG_COMPAT_INSTANCE([AVPlayer class], @selector(setMuted:), @selector(og_compat_setMuted:)),
            OG_COMPAT_INSTANCE([AVPlayer class], @selector(isMuted), @selector(og_compat_isMuted)),
            OG_COMPAT_CLASS([AVCaptureDevice class], @selector(authorizationStatusForMediaType:), @selector(og_compat_authorizationStatusForMediaType:)),
            OG_COMPAT_CLASS([AVCaptureDevice class], @selector(requestAccessForMediaType:completionHandler:), @selector(og_compat_requestAccessForMediaType:completionHandler:)),
#endif
            OG_COMPAT_INSTANCE([AVAudioSession class], @selector(requestRecordPermission:), @selector(og_compat_requestRecordPermission:)),
    
            OG_COMPAT_INSTANCE([NSString class], @selector(sizeWithAttributes:), @selector(og_compat_sizeWithAttributes:)),
            OG_COMPAT_INSTANCE([NSString class], @selector(drawAtPoint:withAttributes:), @selector(og_compat_drawAtPoint:withAttributes:)),
            OG_COMPAT_INSTANCE([NSString class], @selector(boundingRectWithSize:options:attributes:context:), @selector(og_compat_boundingRectWithSize:options:attributes:context:)),
    
            OG_COMPAT_INSTANCE([NSAttributedString class], @selector(boundingRectWithSize:options:context:), @selector(og_compat_boundingRectWithSize:options:context:)),
            OG_COMPAT_INSTANCE([NSAttributedString class], @selector(boundingRectWithSize:options:attributes:context:), @selector(og_compat_boundingRectWithSize:options:attributes:context:)),

            OG_COMPAT_INSTANCE([UILabel class], @selector(attributedText), @selector(tg_ios5_attributedText)),
            OG_COMPAT_INSTANCE([UILabel class], @selector(setAttributedText:), @selector(tg_ios5_setAttributedText:)),
            OG_COMPAT_INSTANCE([UILabel class], @selector(minimumScaleFactor), @selector(tg_ios5_minimumScaleFactor)),
            OG_COMPAT_INSTANCE([UILabel class], @selector(setMinimumScaleFactor:), @selector(tg_ios5_setMinimumScaleFactor:)),
            OG_COMPAT_INSTANCE([UITextField class], @selector(attributedPlaceholder), @selector(tg_ios5_attributedPlaceholder)),
            OG_COMPAT_INSTANCE([UITextField class], @selector(setAttributedPlaceholder:), @selector(tg_ios5_setAttributedPlaceholder:)),
    
            OG_COMPAT_INSTANCE([UIScrollView class], @selector(setContentInsetAdjustmentBehavior:), @selector(og_compat_setContentInsetAdjustmentBehavior:)),
            OG_COMPAT_INSTANCE([UIScrollView class], @selector(contentInsetAdjustmentBehavior), @selector(og_compat_contentInsetAdjustmentBehavior)),

            OG_COMPAT_INSTANCE([UITableView class], @selector(separatorInset), @selector(og_compat_separatorInset)),
            OG_COMPAT_INSTANCE([UITableView class], @selector(setSeparatorInset:), @selector(og_compat_setSeparatorInset:)),
            OG_COMPAT_INSTANCE([UITableViewCell class], @selector(separatorInset), @selector(og_compat_separatorInset)),
            OG_COMPAT_INSTANCE([UITableViewCell class], @selector(setSeparatorInset:), @selector(og_compat_setSeparatorInset:)),
    
            OG_COMPAT_INSTANCE([UIView class], @selector(setSemanticContentAttribute:), @selector(og_compat_setSemanticContentAttribute:)),
            OG_COMPAT_INSTANCE([UIView class], @selector(semanticContentAttribute), @selector(og_compat_semanticContentAttribute)),
            OG_COMPAT_INSTANCE([UIView class], @selector(tintColor), @selector(og_compat_tintColor)),
            OG_COMPAT_INSTANCE([UIView class], @selector(setTintColor:), @selector(og_compat_setTintColor:)),
            OG_COMPAT_INSTANCE([UIView class], @selector(layoutMargins), @selector(og_compat_layoutMargins)),
            OG_COMPAT_INSTANCE([UIView class], @selector(setLayoutMargins:), @selector(og_compat_setLayoutMargins:)),
            OG_COMPAT_INSTANCE([UINavigationBar class], @selector(barTintColor), @selector(og_compat_barTintColor)),
            OG_COMPAT_INSTANCE([UINavigationBar class], @selector(setBarTintColor:), @selector(og_compat_setBarTintColor:)),
    
            OG_COMPAT_INSTANCE([UIViewController class], @selector(prefersStatusBarHidden), @selector(og_compat_prefersStatusBarHidden)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(preferredStatusBarStyle), @selector(og_compat_preferredStatusBarStyle)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(preferredScreenEdgesDeferringSystemGestures), @selector(og_compat_preferredScreenEdgesDeferringSystemGestures)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(setNeedsStatusBarAppearanceUpdate), @selector(og_compat_setNeedsStatusBarAppearanceUpdate)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(setNeedsUpdateOfHomeIndicatorAutoHidden), @selector(og_compat_setNeedsUpdateOfHomeIndicatorAutoHidden)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(automaticallyAdjustsScrollViewInsets), @selector(og_compat_automaticallyAdjustsScrollViewInsets)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(setAutomaticallyAdjustsScrollViewInsets:), @selector(og_compat_setAutomaticallyAdjustsScrollViewInsets:)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(preferredContentSize), @selector(og_compat_preferredContentSize)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(setPreferredContentSize:), @selector(og_compat_setPreferredContentSize:)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(traitCollection), @selector(og_compat_traitCollection)),
            OG_COMPAT_INSTANCE([UIViewController class], @selector(transitionCoordinator), @selector(og_compat_transitionCoordinator)),
    
            OG_COMPAT_INSTANCE([NSData class], @selector(initWithBase64EncodedString:options:), @selector(og_compat_initWithBase64EncodedString:options:)),
            OG_COMPAT_INSTANCE([NSData class], @selector(initWithBase64Encoding:), @selector(og_compat_initWithBase64Encoding:)),
            OG_COMPAT_INSTANCE([NSData class], @selector(base64Encoding), @selector(og_compat_base64Encoding))
        };
        OGCompatInstallEntries(entries, sizeof(entries) / sizeof(entries[0]));
    
        OGCompatInstallTextView([UITextView class]);
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000
        OGCompatInstallTextView(NSClassFromString(@"_UICompatibilityTextView"));
#endif
    }
}

+ (void)hackSetAnimationDuration
{
    SwizzleClassMethod([UIView class], @selector(setAnimationDuration:), @selector(telegraph_setAnimationDuration:));
    SwizzleClassMethod([UIView class], @selector(animateWithDuration:delay:options:animations:completion:), @selector(telegraph_animateWithDuration:delay:options:animations:completion:));
    
    if (iosMajorVersion() >= 7)
    {
        if (iosMajorVersion() >= 8)
        {
            SwizzleClassMethod([UIView class], @selector(performWithoutAnimation:), @selector(TG_performWithoutAnimation_maybeNot:));
        }
    }
    else
    {
        InjectClassMethodFromAnotherClass([UIView class], [UIView class], @selector(TG_performWithoutAnimation:), @selector(performWithoutAnimation:));
        InjectInstanceMethodFromAnotherClass([UIView class], [UIView class], @selector(TG_snapshotViewAfterScreenUpdates:), @selector(snapshotViewAfterScreenUpdates:));
        InjectInstanceMethodFromAnotherClass([UIView class], [UIView class], @selector(og_compat_resizableSnapshotViewFromRect:afterScreenUpdates:withCapInsets:), @selector(resizableSnapshotViewFromRect:afterScreenUpdates:withCapInsets:));
    }
}

+ (void)setAnimationDurationFactor:(float)factor
{
    animationDurationFactor = factor;
}

+ (void)setSecondaryAnimationDurationFactor:(float)factor
{
    secondaryAnimationDurationFactor = factor;
}

+ (void)setForceSystemCurve:(bool)force
{
    forceSystemCurve = force;
}

+ (CGFloat)applicationStatusBarAlpha
{
    CGFloat alpha = 1.0f;
    
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    
    if (window != nil)
        alpha = window.alpha;
    
    return alpha;
}

+ (void)setApplicationStatusBarAlpha:(CGFloat)alpha
{
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    window.alpha = alpha;
}

+ (CGFloat)applicationStatusBarOffset
{
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    return window.bounds.origin.y;
}

+ (void)setApplicationStatusBarOffset:(CGFloat)offset
{
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    
    CGRect bounds = window.bounds;
    bounds.origin = CGPointMake(0.0f, -offset);
    window.bounds = bounds;
}

static UIView *findStatusBarView()
{
    static Class viewClass = nil;
    static SEL selector = NULL;
    
    if (selector == NULL)
    {
        NSString *str1 = @"rs`str";
        NSString *str2 = @"A`qVhmcnv";
        
        selector = NSSelectorFromString([[NSString alloc] initWithFormat:@"%@%@", TGEncodeText(str1, 1), TGEncodeText(str2, 1)]);
        viewClass = NSClassFromString(TGEncodeText(@"VJTubuvtCbs", -1));
    }
    
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    
    for (UIView *subview in window.subviews)
    {
        if ([subview isKindOfClass:viewClass])
            return subview;
    }
    
    return nil;
}

+ (void)animateApplicationStatusBarAppearance:(int)statusBarAnimation duration:(NSTimeInterval)duration completion:(void (^)())completion
{
    [self animateApplicationStatusBarAppearance:statusBarAnimation delay:0.0 duration:duration completion:completion];
}

+ (void)animateApplicationStatusBarAppearance:(int)statusBarAnimation delay:(NSTimeInterval)delay duration:(NSTimeInterval)duration completion:(void (^)())completion
{
    UIView *view = findStatusBarView();
    
    if (view != nil)
    {
        if ((statusBarAnimation & TGStatusBarAppearanceAnimationSlideDown) || (statusBarAnimation & TGStatusBarAppearanceAnimationSlideUp))
        {
            CGPoint startPosition = view.layer.position;
            CGPoint position = view.layer.position;
            
            CGPoint normalPosition = CGPointMake(CGFloor(view.frame.size.width / 2), CGFloor(view.frame.size.height / 2));
            
            CGFloat viewHeight = view.frame.size.height;
            
            if (statusBarAnimation & TGStatusBarAppearanceAnimationSlideDown)
            {
                startPosition = CGPointMake(CGFloor(view.frame.size.width / 2), CGFloor(view.frame.size.height / 2) - viewHeight);
                position = CGPointMake(CGFloor(view.frame.size.width / 2), CGFloor(view.frame.size.height / 2));
            }
            else if (statusBarAnimation & TGStatusBarAppearanceAnimationSlideUp)
            {
                startPosition = CGPointMake(CGFloor(view.frame.size.width / 2), CGFloor(view.frame.size.height / 2));
                position = CGPointMake(CGFloor(view.frame.size.width / 2), CGFloor(view.frame.size.height / 2) - viewHeight);
            }
            
            CABasicAnimation *animation = [[CABasicAnimation alloc] init];
            animation.duration = duration;
            animation.fromValue = [NSValue valueWithCGPoint:startPosition];
            animation.toValue = [NSValue valueWithCGPoint:position];
            animation.removedOnCompletion = true;
            animation.fillMode = kCAFillModeForwards;
            animation.beginTime = delay;
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            
            TGAnimationBlockDelegate *delegate = [[TGAnimationBlockDelegate alloc] initWithLayer:view.layer];
            
            delegate.completion = ^(BOOL finished)
            {
                if (finished)
                    view.layer.position = normalPosition;
                
                if (completion)
                    completion();
            };
            
            animation.delegate = delegate;
            
            [view.layer addAnimation:animation forKey:@"position"];
            
            view.layer.position = position;
        }
        else if ((statusBarAnimation & TGStatusBarAppearanceAnimationFadeIn) || (statusBarAnimation & TGStatusBarAppearanceAnimationFadeOut))
        {
            float startOpacity = view.layer.opacity;
            float opacity = view.layer.opacity;
            
            if (statusBarAnimation & TGStatusBarAppearanceAnimationFadeIn)
            {
                startOpacity = 0.0f;
                opacity = 1.0f;
            }
            else if (statusBarAnimation & TGStatusBarAppearanceAnimationFadeOut)
            {
                startOpacity = 1.0f;
                opacity = 0.0f;
            }
            
            CABasicAnimation *animation = [[CABasicAnimation alloc] init];
            
            animation.duration = duration;
            animation.fromValue = @(startOpacity);
            animation.toValue = @(opacity);
            animation.removedOnCompletion = true;
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            
            TGAnimationBlockDelegate *delegate = [[TGAnimationBlockDelegate alloc] initWithLayer:view.layer];
            
            delegate.completion = ^(__unused BOOL finished)
            {
                if (completion)
                    completion();
            };
            
            animation.delegate = delegate;
            
            [view.layer addAnimation:animation forKey:@"opacity"];
        }
    }
    else
    {
        if (completion)
            completion();
    }
}

+ (void)animateApplicationStatusBarStyleTransitionWithDuration:(NSTimeInterval)duration
{
    UIView *view = findStatusBarView();
    
    if (view != nil)
    {
        UIView *snapshotView = [view snapshotViewAfterScreenUpdates:false];
        
        [view addSubview:snapshotView];
        
        [UIView animateWithDuration:duration animations:^
         {
             snapshotView.alpha = 0.0f;
         } completion:^(__unused BOOL finished)
         {
             [snapshotView removeFromSuperview];
         }];
    }
}

+ (CGFloat)statusBarHeightForOrientation:(UIInterfaceOrientation)orientation
{
    UIWindow *window = [[LegacyComponentsGlobals provider] applicationStatusBarWindow];
    
    Class statusBarClass = NSClassFromString(TGEncodeText(@"VJTubuvtCbs", -1));
    
    for (UIView *view in window.subviews)
    {
        if ([view isKindOfClass:statusBarClass])
        {
            SEL selector = NSSelectorFromString(TGEncodeText(@"dvssfouTuzmf", -1));
            
            NSMethodSignature *signature = [statusBarClass instanceMethodSignatureForSelector:selector];
            
            if (signature == nil)
            {
                TGLegacyLog(@"Method not found");
                return 20.0f;
            }
            
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
            
            [inv setSelector:selector];
            [inv setTarget:view];
            [inv invoke];
            
            NSInteger result = 0;
            
            [inv getReturnValue:&result];
            
            SEL selector2 = NSSelectorFromString(TGEncodeText(@"ifjhiuGpsTuzmf;psjfoubujpo;", -1));
            
            NSMethodSignature *signature2 = [statusBarClass methodSignatureForSelector:selector2];
            
            if (signature2 == nil)
            {
                TGLegacyLog(@"Method not found");
                return 20.0f;
            }
            
            NSInvocation *inv2 = [NSInvocation invocationWithMethodSignature:signature2];
            
            [inv2 setSelector:selector2];
            [inv2 setTarget:[view class]];
            [inv2 setArgument:&result atIndex:2];
            
            NSInteger argOrientation = orientation;
            
            [inv2 setArgument:&argOrientation atIndex:3];
            [inv2 invoke];
            
            CGFloat result2 = 0;
            
            [inv2 getReturnValue:&result2];
            
            return result2;
        }
    }
    
    return 20.0f;
}

+ (bool)isKeyboardVisible
{
    return [self isKeyboardVisibleAlt];
}

static bool keyboardHidden = true;

+ (bool)isKeyboardVisibleAlt
{
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
#if defined(ONEGRAM_ARMV6)
                      NSOperationQueue *notificationQueue = nil;
#else
                      NSOperationQueue *notificationQueue = [NSOperationQueue mainQueue];
#endif
                      [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification object:nil queue:notificationQueue usingBlock:^(__unused NSNotification *notification)
                       {
                           if (!freedomUIKitTest3())
                               keyboardHidden = true;
                       }];
                      
                      [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification object:nil queue:notificationQueue usingBlock:^(__unused NSNotification *notification)
                       {
                           keyboardHidden = false;
                       }];
                  });
    
    return !keyboardHidden;
}

+ (CGFloat)keyboardHeightForOrientation:(UIInterfaceOrientation)orientation
{
    static NSInvocation *invocation = nil;
    static Class keyboardClass = NULL;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      keyboardClass = NSClassFromString(TGEncodeText(@"VJLfzcpbse", -1));
                      
                      SEL selector = NSSelectorFromString(TGEncodeText(@"tj{fGpsJoufsgbdfPsjfoubujpo;", -1));
                      
                      NSMethodSignature *signature = [keyboardClass methodSignatureForSelector:selector];
                      
                      if (signature == nil)
                      {
                          TGLegacyLog(@"Method not found");
                      }
                      else
                      {
                          invocation = [NSInvocation invocationWithMethodSignature:signature];
                          [invocation setSelector:selector];
                      }
                  });
    
    if (invocation != nil)
    {
        [invocation setTarget:[keyboardClass class]];
        [invocation setArgument:&orientation atIndex:2];
        [invocation invoke];
        
        CGSize result = CGSizeZero;
        
        [invocation getReturnValue:&result];
        
        return MIN(result.width, result.height);
    }
    
    return 0.0f;
}

+ (void)applyCurrentKeyboardAutocorrectionVariant
{
    static Class keyboardClass = NULL;
    static SEL currentInstanceSelector = NULL;
    static SEL applyVariantSelector = NULL;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      keyboardClass = NSClassFromString(TGEncodeText(@"VJLfzcpbse", -1));
                      
                      currentInstanceSelector = NSSelectorFromString(TGEncodeText(@"bdujwfLfzcpbse", -1));
                      applyVariantSelector = NSSelectorFromString(TGEncodeText(@"bddfquBvupdpssfdujpo", -1));
                  });
    
    if ([keyboardClass respondsToSelector:currentInstanceSelector])
    {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        
        id currentInstance = [keyboardClass performSelector:currentInstanceSelector];
        
        if ([currentInstance respondsToSelector:applyVariantSelector])
            [currentInstance performSelector:applyVariantSelector];
        
#pragma clang diagnostic pop
    }
}

+ (UIWindow *)applicationKeyboardWindow
{
    return [[LegacyComponentsGlobals provider] applicationKeyboardWindow];
}

+ (void)setApplicationKeyboardOffset:(CGFloat)offset
{
    UIWindow *keyboardWindow = [self applicationKeyboardWindow];
    
    keyboardWindow.frame = CGRectOffset(keyboardWindow.bounds, 0.0f, offset);
}

+ (UIView *)applicationKeyboardView
{
    static Class keyboardViewClass = Nil;
    static Class keyboardViewContainerClass = Nil;
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
                  {
                      keyboardViewClass = NSClassFromString(TGEncodeText(@"VJJoqvuTfuIptuWjfx", -1));
                      keyboardViewContainerClass = NSClassFromString(TGEncodeText(@"VJJoqvuTfuDpoubjofsWjfx", -1));
                  });
    
    for (UIView *view in [self applicationKeyboardWindow].subviews)
    {
        if ([view isKindOfClass:keyboardViewContainerClass])
        {
            for (UIView *subview in view.subviews)
            {
                if ([subview isKindOfClass:keyboardViewClass])
                    return subview;
            }
        }
    }
    
    return nil;
}

+ (void)setForceMovieAnimatedScaleMode:(bool)force
{
    forceMovieAnimatedScaleMode = force;
}

+ (void)forcePerformWithAnimation:(dispatch_block_t)block
{
    if (block)
    {
        bool flag = forcePerformWithAnimationFlag;
        
        forcePerformWithAnimationFlag = true;
        
        block();
        
        forcePerformWithAnimationFlag = flag;
    }
}

@end

#if TARGET_IPHONE_SIMULATOR
extern float UIAnimationDragCoefficient(void);
#endif

CGFloat TGAnimationSpeedFactor()
{
#if TARGET_IPHONE_SIMULATOR
    return UIAnimationDragCoefficient();
#endif
    
    return 1.0f;
}

@implementation UIView (OGCompatInvertColors)

- (void)og_compat_setAccessibilityIgnoresInvertColors:(BOOL)__unused accessibilityIgnoresInvertColors
{
}

- (BOOL)og_compat_accessibilityIgnoresInvertColors
{
    return false;
}

@end

@implementation UIView (OGCompatSpringAnimation)

+ (void)og_compat_animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay usingSpringWithDamping:(CGFloat)__unused dampingRatio initialSpringVelocity:(CGFloat)__unused velocity options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion
{
    [self animateWithDuration:duration delay:delay options:options animations:animations completion:completion];
}

@end

#if !defined(ONEGRAM_ARMV6)

@implementation AVPlayer (OGCompatMuted)

- (void)og_compat_setMuted:(BOOL)__unused muted
{
}

- (BOOL)og_compat_isMuted
{
    return false;
}

@end

@implementation AVCaptureDevice (OGCompatAuthorization)

+ (AVAuthorizationStatus)og_compat_authorizationStatusForMediaType:(NSString *)__unused mediaType
{
    return AVAuthorizationStatusAuthorized;
}

+ (void)og_compat_requestAccessForMediaType:(NSString *)__unused mediaType completionHandler:(void (^)(BOOL granted))handler
{
    if (handler != nil)
        handler(true);
}

@end

#endif

@implementation AVAudioSession (OGCompatRecordPermission)

- (void)og_compat_requestRecordPermission:(void (^)(BOOL granted))response
{
    if (response != nil)
        response(true);
}

@end

static UIFont *OGCompatAttributeFont(NSDictionary *attributes)
{
    UIFont *font = [attributes objectForKey:NSFontAttributeName];
    return font != nil ? font : [UIFont systemFontOfSize:[UIFont systemFontSize]];
}

@implementation NSString (OGCompatStringDrawing)

- (CGSize)og_compat_sizeWithAttributes:(NSDictionary *)attrs
{
    return [self sizeWithFont:OGCompatAttributeFont(attrs)];
}

- (void)og_compat_drawAtPoint:(CGPoint)point withAttributes:(NSDictionary *)attrs
{
    UIColor *color = [attrs objectForKey:NSForegroundColorAttributeName];
    if (color != nil)
        [color set];
    
    [self drawAtPoint:point withFont:OGCompatAttributeFont(attrs)];
}

- (CGRect)og_compat_boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)__unused options attributes:(NSDictionary *)attributes context:(id)__unused context
{
    CGSize fitted = [self sizeWithFont:OGCompatAttributeFont(attributes) constrainedToSize:size lineBreakMode:NSLineBreakByWordWrapping];
    return (CGRect){CGPointZero, fitted};
}

@end

@implementation UILabel (OGCompatAttributedText)

- (NSAttributedString *)tg_ios5_attributedText
{
    Class attributedStringClass = NSClassFromString(@"NSAttributedString");
    if (attributedStringClass == Nil)
        return nil;

    return [[attributedStringClass alloc] initWithString:self.text == nil ? @"" : self.text];
}

- (void)tg_ios5_setAttributedText:(NSAttributedString *)attributedText
{
    self.text = attributedText.string;
}

- (CGFloat)tg_ios5_minimumScaleFactor
{
    if (self.font.pointSize <= FLT_EPSILON)
        return 0.0f;

    return self.minimumFontSize / self.font.pointSize;
}

- (void)tg_ios5_setMinimumScaleFactor:(CGFloat)minimumScaleFactor
{
    self.minimumFontSize = self.font.pointSize * minimumScaleFactor;
}

@end

@implementation UITextField (OGCompatAttributedPlaceholder)

- (NSAttributedString *)tg_ios5_attributedPlaceholder
{
    return nil;
}

- (void)tg_ios5_setAttributedPlaceholder:(NSAttributedString *)attributedPlaceholder
{
    self.placeholder = attributedPlaceholder.string;
}

@end

@implementation NSAttributedString (OGCompatAttributedStringDrawing)

- (CGRect)og_compat_boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)__unused options context:(id)__unused context
{
    return [self.string og_compat_boundingRectWithSize:size options:0 attributes:nil context:nil];
}

- (CGRect)og_compat_boundingRectWithSize:(CGSize)size options:(NSStringDrawingOptions)options attributes:(NSDictionary *)attributes context:(id)context
{
    return [self.string boundingRectWithSize:size options:options attributes:attributes context:context];
}

@end

@implementation UIScrollView (OGCompatContentInsetAdjustment)

- (void)og_compat_setContentInsetAdjustmentBehavior:(UIScrollViewContentInsetAdjustmentBehavior)__unused contentInsetAdjustmentBehavior
{
}

- (UIScrollViewContentInsetAdjustmentBehavior)og_compat_contentInsetAdjustmentBehavior
{
    return UIScrollViewContentInsetAdjustmentNever;
}

@end

@implementation UITableView (OGCompatSeparatorInset)

- (UIEdgeInsets)og_compat_separatorInset
{
    return UIEdgeInsetsZero;
}

- (void)og_compat_setSeparatorInset:(UIEdgeInsets)__unused separatorInset
{
}

@end


@implementation UITableViewCell (OGCompatSeparatorInset)

- (UIEdgeInsets)og_compat_separatorInset
{
    return UIEdgeInsetsZero;
}

- (void)og_compat_setSeparatorInset:(UIEdgeInsets)__unused separatorInset
{
}

@end

@implementation UIView (OGCompatSemanticContent)

- (void)og_compat_setSemanticContentAttribute:(UISemanticContentAttribute)__unused semanticContentAttribute
{
}

- (UISemanticContentAttribute)og_compat_semanticContentAttribute
{
    return UISemanticContentAttributeForceLeftToRight;
}

- (UIColor *)og_compat_tintColor
{
    return nil;
}

- (void)og_compat_setTintColor:(UIColor *)__unused tintColor
{
}

- (UIEdgeInsets)og_compat_layoutMargins
{
    return UIEdgeInsetsZero;
}

- (void)og_compat_setLayoutMargins:(UIEdgeInsets)__unused layoutMargins
{
}

@end

@implementation UINavigationBar (OGCompatBarTint)

- (UIColor *)og_compat_barTintColor
{
    return self.tintColor;
}

- (void)og_compat_setBarTintColor:(UIColor *)barTintColor
{
    self.tintColor = barTintColor;
}

@end

@implementation UIViewController (OGCompatStatusBar)

- (BOOL)og_compat_prefersStatusBarHidden
{
    return false;
}

- (UIStatusBarStyle)og_compat_preferredStatusBarStyle
{
    return [[LegacyComponentsGlobals provider] statusBarStyle];
}

- (UIRectEdge)og_compat_preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeNone;
}

- (void)og_compat_setNeedsStatusBarAppearanceUpdate
{
}

- (void)og_compat_setNeedsUpdateOfHomeIndicatorAutoHidden
{
}

- (BOOL)og_compat_automaticallyAdjustsScrollViewInsets
{
    return false;
}

- (void)og_compat_setAutomaticallyAdjustsScrollViewInsets:(BOOL)__unused automaticallyAdjustsScrollViewInsets
{
}

- (CGSize)og_compat_preferredContentSize
{
    return CGSizeZero;
}

- (void)og_compat_setPreferredContentSize:(CGSize)__unused preferredContentSize
{
}

- (UITraitCollection *)og_compat_traitCollection
{
    return nil;
}

- (id<UIViewControllerTransitionCoordinator>)og_compat_transitionCoordinator
{
    return nil;
}

@end

static const char OGCompatBase64Alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

@implementation NSData (OGCompatBase64)

- (instancetype)og_compat_initWithBase64EncodedString:(NSString *)base64String options:(NSDataBase64DecodingOptions)__unused options
{
    return [self og_compat_initWithBase64Encoding:base64String];
}

- (instancetype)og_compat_initWithBase64Encoding:(NSString *)base64String
{
    static unsigned char decodeTable[256];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        memset(decodeTable, 0x80, sizeof(decodeTable));
        for (int i = 0; i < 64; i++)
            decodeTable[(unsigned char)OGCompatBase64Alphabet[i]] = (unsigned char)i;
        decodeTable[(unsigned char)'='] = 0;
    });
    
    NSMutableData *decoded = [[NSMutableData alloc] init];
    uint32_t accumulator = 0;
    int bits = -8;
    
    for (const unsigned char *c = (const unsigned char *)[base64String UTF8String]; *c != 0 && *c != '='; c++)
    {
        unsigned char sextet = decodeTable[*c];
        if (sextet & 0x80)
            continue;
        
        accumulator = (accumulator << 6) | sextet;
        bits += 6;
        if (bits >= 0)
        {
            unsigned char byte = (unsigned char)((accumulator >> bits) & 0xff);
            [decoded appendBytes:&byte length:1];
            bits -= 8;
        }
    }
    
    return [self initWithData:decoded];
}

- (NSString *)og_compat_base64Encoding
{
    const unsigned char *input = (const unsigned char *)[self bytes];
    NSUInteger length = [self length];
    NSMutableString *encoded = [[NSMutableString alloc] initWithCapacity:((length + 2) / 3) * 4];
    
    for (NSUInteger offset = 0; offset < length; offset += 3)
    {
        NSUInteger remaining = length - offset;
        NSUInteger group = input[offset] << 16;
        if (remaining > 1)
            group |= input[offset + 1] << 8;
        if (remaining > 2)
            group |= input[offset + 2];
        
        [encoded appendFormat:@"%c%c%c%c",
         OGCompatBase64Alphabet[(group >> 18) & 0x3f],
         OGCompatBase64Alphabet[(group >> 12) & 0x3f],
         remaining > 1 ? OGCompatBase64Alphabet[(group >> 6) & 0x3f] : '=',
         remaining > 2 ? OGCompatBase64Alphabet[group & 0x3f] : '='];
    }
    
    return encoded;
}

@end

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 70000

@implementation NSTextAttachment

- (instancetype)initWithData:(NSData *)__unused contentData ofType:(NSString *)__unused uti
{
    return [self init];
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)__unused textContainer proposedLineFragment:(CGRect)__unused lineFrag glyphPosition:(CGPoint)__unused position characterIndex:(NSUInteger)__unused charIndex
{
    return CGRectZero;
}

@end

@implementation NSLayoutManager

- (void)addTextContainer:(NSTextContainer *)__unused container
{
}

@end

@implementation NSTextStorage

- (NSString *)string
{
    return @"";
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)__unused location effectiveRange:(NSRangePointer)__unused range
{
    return nil;
}

- (void)replaceCharactersInRange:(NSRange)__unused range withString:(NSString *)__unused str
{
}

- (void)setAttributes:(NSDictionary *)__unused attrs range:(NSRange)__unused range
{
}

- (void)addLayoutManager:(NSLayoutManager *)__unused layoutManager
{
}

@end

@implementation NSTextContainer

- (instancetype)initWithSize:(CGSize)__unused size
{
    return [self init];
}

@end

@implementation UITextView (OGCompatTextKit)

- (NSAttributedString *)tg_ios5_attributedText
{
    Class attributedStringClass = NSClassFromString(@"NSAttributedString");
    if (attributedStringClass == Nil)
        return nil;

    return [[attributedStringClass alloc] initWithString:self.text == nil ? @"" : self.text];
}

- (void)tg_ios5_setAttributedText:(NSAttributedString *)attributedText
{
    self.text = attributedText.string;
}

- (NSDictionary *)tg_ios5_typingAttributes
{
    return nil;
}

- (void)tg_ios5_setTypingAttributes:(NSDictionary *)__unused typingAttributes
{
}

- (NSLayoutManager *)og_compat_layoutManager
{
    return nil;
}

- (NSTextContainer *)og_compat_textContainer
{
    return nil;
}

- (NSTextStorage *)og_compat_textStorage
{
    return nil;
}

- (UIEdgeInsets)og_compat_textContainerInset
{
    return self.contentInset;
}

- (void)og_compat_setTextContainerInset:(UIEdgeInsets)textContainerInset
{
    self.contentInset = textContainerInset;
}

- (BOOL)og_compat_isSelectable
{
    return self.editable;
}

- (void)og_compat_setSelectable:(BOOL)__unused selectable
{
}

- (instancetype)og_compat_initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)__unused textContainer
{
    return [self initWithFrame:frame];
}

@end

#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 80000
static Class OGCompatWebKitRuntimeClass(NSString *name, Class compatibilityClass)
{
    Class systemClass = NSClassFromString(name);
    if (systemClass == Nil)
    {
        dlopen("/System/Library/Frameworks/WebKit.framework/WebKit", RTLD_LAZY | RTLD_LOCAL);
        systemClass = NSClassFromString(name);
    }
    if (systemClass == Nil || systemClass == compatibilityClass)
        return Nil;
    return systemClass;
}

#define OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS(systemName) \
+ (id)allocWithZone:(NSZone *)zone \
{ \
    Class systemClass = OGCompatWebKitRuntimeClass(@systemName, self); \
    if (systemClass != Nil) \
        return [systemClass allocWithZone:zone]; \
    return [super allocWithZone:zone]; \
} \
+ (id)forwardingTargetForSelector:(SEL)selector \
{ \
    Class systemClass = OGCompatWebKitRuntimeClass(@systemName, self); \
    if (systemClass != Nil && [systemClass respondsToSelector:selector]) \
        return systemClass; \
    return nil; \
}

@implementation WKFrameInfo
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKFrameInfo")
@end

@implementation WKNavigation
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKNavigation")
@end

@implementation WKNavigationAction
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKNavigationAction")

- (NSURLRequest *)request
{
    return nil;
}

- (WKFrameInfo *)targetFrame
{
    return nil;
}

@end

@implementation WKUserScript
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKUserScript")

- (instancetype)initWithSource:(NSString *)__unused source injectionTime:(WKUserScriptInjectionTime)__unused injectionTime forMainFrameOnly:(BOOL)__unused forMainFrameOnly
{
    return [self init];
}

@end

@implementation WKPreferences
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKPreferences")
@end

@implementation WKUserContentController
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKUserContentController")

- (void)addUserScript:(WKUserScript *)__unused userScript
{
}

- (void)addScriptMessageHandler:(id<WKScriptMessageHandler>)__unused scriptMessageHandler name:(NSString *)__unused name
{
}

@end

@implementation WKWebViewConfiguration
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKWebViewConfiguration")
@end

@implementation WKWebView
OG_COMPAT_WEBKIT_RUNTIME_PROXY_METHODS("WKWebView")

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)__unused configuration
{
    return [super initWithFrame:frame];
}

- (UIScrollView *)scrollView
{
    return nil;
}

- (double)estimatedProgress
{
    return 0.0;
}

- (WKNavigation *)loadRequest:(NSURLRequest *)__unused request
{
    return nil;
}

- (void)evaluateJavaScript:(NSString *)__unused javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
{
    if (completionHandler != nil)
        completionHandler(nil, nil);
}

@end

#endif
