#import "LegacyComponentsGlobals.h"
#import "TGNavigationController.h"
#import "OGPlatformVersion.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <UIKit/UIGestureRecognizerSubclass.h>
#endif
#endif

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGStringUtils.h"
#import "TGColor.h"
#import "Freedom.h"

#import "TGNavigationBar.h"
#import "TGViewController.h"

#import "TGHacks.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 50000
@interface UINavigationController (TGNavigationControllerModernInitializerDeclaration)
- (instancetype)initWithNavigationBarClass:(Class)navigationBarClass toolbarClass:(Class)toolbarClass;
@end
#endif

@interface TGDelegateProxy : NSObject

@property(nonatomic, weak) id delegate;

@end

@interface TGNavigationFullScreenPanMethods : UIPanGestureRecognizer
@end

@implementation TGNavigationFullScreenPanMethods
- (id)recognizerTouchesToIgnoreForEvent:(id)event
{
    return nil;
}
@end

static char TGNavigationFullScreenPanClassKey;

@interface TGNavigationGestureDelegateProxy : TGDelegateProxy <UIGestureRecognizerDelegate>

@property (nonatomic, copy) bool (^shouldBegin)(UIPanGestureRecognizer *);
@property (nonatomic, copy) bool (^shouldRecognizeWith)(UIPanGestureRecognizer *, UIGestureRecognizer *);

@end

@interface TGNavigationPercentTransition : UIPercentDrivenInteractiveTransition

@end

@interface TGNavigationController () <UINavigationControllerDelegate, UIGestureRecognizerDelegate, UINavigationBarDelegate>
{
    UITapGestureRecognizer *_dimmingTapRecognizer;
    CGSize _preferredContentSize;
    
    id<SDisposable> _playerStatusDisposable;
    CGFloat _currentAdditionalStatusBarHeight;
    
    TGNavigationGestureDelegateProxy *_gestureDelegate;
    bool _animatingControllerPush;
    bool _fixNextInteractiveTransition;
    
    id _enterBackgroundObserver;
    id _becomeActiveObserver;
    
    bool _didFirstLayout;
    bool _legacyBackTransitionInProgress;
    Class _requestedNavigationBarClass;
    UINavigationBar *_legacyNavigationBar;
    TGNavigationBarPallete *_legacyNavigationBarPallete;
    UIView *_legacyMusicPlayerContainer;
    UIView<TGNavigationBarMusicPlayerView> *_legacyMusicPlayerView;
    Class _originalInteractivePopGestureRecognizerClass;
    Class _fullScreenInteractivePopGestureRecognizerClass;
}

@property (nonatomic) bool wasShowingNavigationBar;

@property (nonatomic, strong) TGAutorotationLock *autorotationLock;

- (void)layoutNavigationContentView;
- (void)tgLegacyBackButtonPressed;
- (void)tgLegacyNavigationBarWillLayout;
- (void)tgLegacyNavigationBarDidLayout;
- (void)layoutLegacyMusicPlayer;
- (void)configureInteractivePopGestureForControllers:(NSArray *)controllers;

@end

static char TGNavigationControllerLegacyOwnerKey;
static char TGNavigationControllerLegacyOriginalBarClassKey;
static char TGNavigationControllerLegacyBarClassKey;

@interface TGNavigationControllerLegacyNavigationBar : UINavigationBar
@end

@implementation TGNavigationControllerLegacyNavigationBar
- (void)layoutSubviews
{
    TGNavigationController *owner = objc_getAssociatedObject(self, &TGNavigationControllerLegacyOwnerKey);
    [owner tgLegacyNavigationBarWillLayout];
    Class originalClass = objc_getAssociatedObject(self, &TGNavigationControllerLegacyOriginalBarClassKey);
    if (originalClass != Nil)
    {
        void (*layout)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation(originalClass, @selector(layoutSubviews));
        layout(self, @selector(layoutSubviews));
    }
    else
        [super layoutSubviews];
    [owner tgLegacyNavigationBarDidLayout];
}
@end

@interface TGNavigationControllerLegacyTitleLabel : UILabel
@end
@implementation TGNavigationControllerLegacyTitleLabel
@end

static void TGNavigationControllerStyleLegacyItem(UIBarButtonItem *item, TGNavigationBarPallete *pallete);

@interface TGNavigationControllerLegacyItemButton : UIButton
@property (nonatomic, unsafe_unretained) UIBarButtonItem *item;
@property (nonatomic, strong) TGNavigationBarPallete *pallete;
- (void)refresh;
@end
@implementation TGNavigationControllerLegacyItemButton
- (void)refresh
{
    TGNavigationControllerStyleLegacyItem(self.item, self.pallete);
}

- (void)pressed
{
    UIBarButtonItem *item = self.item;
    if (item != nil && item.enabled && item.action != NULL)
        [[UIApplication sharedApplication] sendAction:item.action to:item.target from:item forEvent:nil];
}
@end

@interface TGNavigationControllerLegacyGradientView : UIView
@end

@implementation TGNavigationControllerLegacyGradientView

+ (Class)layerClass
{
    return [CAGradientLayer class];
}

@end

@interface TGNavigationControllerLegacyBrandedBackgroundView : UIImageView
{
    CGSize _renderedSize;
    TGNavigationBarBackgroundVariant _renderedVariant;
}

@property (nonatomic) TGNavigationBarBackgroundVariant backgroundVariant;

- (void)updateImage;

@end

@implementation TGNavigationControllerLegacyBrandedBackgroundView

- (void)updateImage
{
    CGSize size = self.superview.bounds.size;
    UIView *navigationBar = self.superview.superview;
    TGNavigationBarBackgroundVariant variant = [navigationBar isKindOfClass:[TGNavigationBar class]] ? ((TGNavigationBar *)navigationBar).backgroundVariant : _backgroundVariant;
    if (CGSizeEqualToSize(size, _renderedSize) && variant == _renderedVariant)
        return;

    _renderedSize = size;
    _renderedVariant = variant;
    id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
    UIImage *image = [provider respondsToSelector:@selector(brandedIOS6NavigationBarBackgroundImageForSize:overflow:variant:)] ? [provider brandedIOS6NavigationBarBackgroundImageForSize:size overflow:0.0f variant:variant] : nil;
    self.image = image;
    self.frame = CGRectMake(0.0f, 0.0f, size.width, image != nil ? image.size.height : size.height);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateImage];
}

@end

static bool TGNavigationControllerClassicIOS6Style(void)
{
    return (TGCurrentInterfaceStyle() != 0);
}

static bool TGNavigationControllerBrandedIOS6Style(void)
{
    return TGCurrentInterfaceStyle() == 2;
}

static bool TGNavigationControllerClassicDarkPalette(TGNavigationBarPallete *pallete)
{
    if (pallete == nil || pallete.backgroundColor == nil)
        return false;

    CGColorRef color = pallete.backgroundColor.CGColor;
    size_t count = CGColorGetNumberOfComponents(color);
    const CGFloat *components = CGColorGetComponents(color);
    if (components == NULL || count == 0)
        return false;

    CGFloat luminance = 1.0f;
    if (count == 2)
        luminance = components[0];
    else if (count >= 3)
        luminance = components[0] * 0.299f + components[1] * 0.587f + components[2] * 0.114f;

    return luminance < 0.5f;
}

static UIColor *TGNavigationControllerColorWithBrightnessMultiplier(UIColor *color, CGFloat multiplier)
{
    if (color == nil)
        return nil;

    CGColorRef cgColor = color.CGColor;
    size_t count = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *components = CGColorGetComponents(cgColor);
    if (components == NULL)
        return color;

    if (count == 2)
    {
        CGFloat value = MIN(1.0f, MAX(0.0f, components[0] * multiplier));
        return [UIColor colorWithWhite:value alpha:components[1]];
    }

    if (count >= 3)
    {
        CGFloat red = MIN(1.0f, MAX(0.0f, components[0] * multiplier));
        CGFloat green = MIN(1.0f, MAX(0.0f, components[1] * multiplier));
        CGFloat blue = MIN(1.0f, MAX(0.0f, components[2] * multiplier));
        CGFloat alpha = count >= 4 ? components[3] : 1.0f;
        return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
    }

    return color;
}

static UIImage *TGNavigationControllerClassicIOS6ResourceImage(NSString *name)
{
    CGFloat scale = [UIScreen mainScreen].scale;
    bool retinaResource = scale > 1.5f;
    NSString *resourceName = retinaResource ? [name stringByAppendingString:@"@2x"] : name;
    NSString *path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ClassicIOS6"];
    if (path.length == 0)
    {
        retinaResource = !retinaResource;
        resourceName = retinaResource ? [name stringByAppendingString:@"@2x"] : name;
        path = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"png" inDirectory:@"ClassicIOS6"];
    }

    UIImage *image = path.length == 0 ? nil : [UIImage imageWithContentsOfFile:path];
    if (image != nil && retinaResource && image.CGImage != NULL)
        image = [UIImage imageWithCGImage:image.CGImage scale:2.0f orientation:UIImageOrientationUp];
    return image;
}

static UIImage *TGNavigationControllerRecoloredImage(UIImage *image, UIColor *tintColor, CGFloat intensity)
{
    if (image == nil || tintColor == nil)
        return image;

    CGFloat scale = image.scale > FLT_EPSILON ? image.scale : 0.0f;
    CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    UIGraphicsBeginImageContextWithOptions(image.size, false, scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [image drawInRect:rect];
    CGContextSetBlendMode(context, kCGBlendModeColor);
    CGContextSetFillColorWithColor(context, tintColor.CGColor);
    CGContextFillRect(context, rect);
    if (intensity > FLT_EPSILON)
    {
        CGContextSetBlendMode(context, kCGBlendModeMultiply);
        CGContextSetFillColorWithColor(context, [tintColor colorWithAlphaComponent:MIN(1.0f, MAX(0.0f, intensity))].CGColor);
        CGContextFillRect(context, rect);
    }
    [image drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0f];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result == nil ? image : result;
}

static UIImage *TGNavigationControllerClassicIOS6BackImage(bool highlighted, TGNavigationBarPallete *pallete)
{
    UIImage *image = TGNavigationControllerClassicIOS6ResourceImage(highlighted ? @"BackButton_Pressed" : @"BackButton");
    if (image == nil)
        return nil;

    if (TGNavigationControllerClassicDarkPalette(pallete))
        image = TGNavigationControllerRecoloredImage(image, pallete.backgroundColor, 0.85f);

    CGFloat leftCap = MIN(15.0f, image.size.width - 1.0f);
    return [image stretchableImageWithLeftCapWidth:(NSInteger)leftCap topCapHeight:0];
}

static const NSInteger TGNavigationControllerLegacyBackgroundTag = 0x54474e41;
static const NSInteger TGNavigationControllerLegacySeparatorTag = 0x54474e42;
static const NSInteger TGNavigationControllerLegacyGradientTag = 0x54474e43;
static const NSInteger TGNavigationControllerLegacyBrandedTag = 0x54474e44;

static void TGNavigationControllerUpdateLegacyBrandedBackground(UINavigationBar *navigationBar, TGNavigationBarBackgroundVariant variant)
{
    UIView *backgroundView = [navigationBar viewWithTag:TGNavigationControllerLegacyBackgroundTag];
    TGNavigationControllerLegacyBrandedBackgroundView *brandedView = (TGNavigationControllerLegacyBrandedBackgroundView *)[backgroundView viewWithTag:TGNavigationControllerLegacyBrandedTag];
    brandedView.backgroundVariant = variant;
    if (!brandedView.hidden)
        [brandedView updateImage];
}

static void TGNavigationControllerApplyNavigationBar(UINavigationBar *navigationBar, Class navigationBarClass, TGNavigationBarPallete *pallete)
{
    if ([navigationBar isKindOfClass:[TGNavigationBar class]])
    {
        if (pallete != nil)
            [(TGNavigationBar *)navigationBar setPallete:pallete];
        return;
    }

    if (navigationBarClass == [TGBlackNavigationBar class])
    {
        navigationBar.barStyle = UIBarStyleBlackTranslucent;
        navigationBar.translucent = true;
    }
    else if (navigationBarClass == [TGTransparentNavigationBar class] || navigationBarClass == [TGWhiteNavigationBar class])
    {
        navigationBar.barStyle = UIBarStyleDefault;
        navigationBar.translucent = false;
        navigationBar.tintColor = [UIColor whiteColor];
    }
    else
    {
        navigationBar.barStyle = UIBarStyleDefault;
        navigationBar.translucent = false;
        if (pallete != nil)
            navigationBar.tintColor = pallete.tintColor;
    }

    if (iosMajorVersion() < 5)
    {
        UIView *backgroundView = [navigationBar viewWithTag:TGNavigationControllerLegacyBackgroundTag];
        if (backgroundView == nil)
        {
            backgroundView = [[UIView alloc] initWithFrame:navigationBar.bounds];
            backgroundView.tag = TGNavigationControllerLegacyBackgroundTag;
            backgroundView.userInteractionEnabled = false;
            backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [navigationBar insertSubview:backgroundView atIndex:0];

            TGNavigationControllerLegacyGradientView *gradientView = [[TGNavigationControllerLegacyGradientView alloc] initWithFrame:backgroundView.bounds];
            gradientView.tag = TGNavigationControllerLegacyGradientTag;
            gradientView.userInteractionEnabled = false;
            gradientView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [backgroundView addSubview:gradientView];

            TGNavigationControllerLegacyBrandedBackgroundView *brandedView = [[TGNavigationControllerLegacyBrandedBackgroundView alloc] initWithFrame:backgroundView.bounds];
            brandedView.tag = TGNavigationControllerLegacyBrandedTag;
            brandedView.userInteractionEnabled = false;
            brandedView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            brandedView.hidden = true;
            [backgroundView addSubview:brandedView];

            UIView *separatorView = [[UIView alloc] initWithFrame:CGRectZero];
            separatorView.tag = TGNavigationControllerLegacySeparatorTag;
            separatorView.userInteractionEnabled = false;
            separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
            [backgroundView addSubview:separatorView];
        }

        backgroundView.frame = navigationBar.bounds;
        UIView *separatorView = [backgroundView viewWithTag:TGNavigationControllerLegacySeparatorTag];
        TGNavigationControllerLegacyGradientView *gradientView = (TGNavigationControllerLegacyGradientView *)[backgroundView viewWithTag:TGNavigationControllerLegacyGradientTag];
        TGNavigationControllerLegacyBrandedBackgroundView *brandedView = (TGNavigationControllerLegacyBrandedBackgroundView *)[backgroundView viewWithTag:TGNavigationControllerLegacyBrandedTag];
        brandedView.hidden = true;
        gradientView.frame = backgroundView.bounds;
        CGFloat separatorHeight = TGScreenPixel;
        separatorView.frame = CGRectMake(0.0f, MAX(0.0f, backgroundView.bounds.size.height - separatorHeight), backgroundView.bounds.size.width, separatorHeight);

        if (navigationBarClass == [TGTransparentNavigationBar class])
        {
            backgroundView.hidden = false;
            backgroundView.backgroundColor = [UIColor clearColor];
            gradientView.hidden = true;
            separatorView.hidden = false;
            separatorView.backgroundColor = [UIColor clearColor];
        }
        else if (navigationBarClass == [TGBlackNavigationBar class])
        {
            backgroundView.hidden = true;
            gradientView.hidden = true;
        }
        else
        {
            bool classicIOS6Style = TGNavigationControllerClassicIOS6Style() && navigationBarClass != [TGWhiteNavigationBar class];
            bool classicDarkStyle = classicIOS6Style && TGNavigationControllerClassicDarkPalette(pallete);
            backgroundView.hidden = false;
            if (classicIOS6Style)
            {
                bool useBrandedImage = TGNavigationControllerBrandedIOS6Style() && [[LegacyComponentsGlobals provider] respondsToSelector:@selector(brandedIOS6NavigationBarBackgroundImageForSize:overflow:variant:)];
                backgroundView.backgroundColor = [UIColor clearColor];
                brandedView.hidden = !useBrandedImage;
                if (useBrandedImage)
                    [brandedView updateImage];
                gradientView.hidden = useBrandedImage;
                separatorView.hidden = useBrandedImage;
                CAGradientLayer *gradientLayer = (CAGradientLayer *)gradientView.layer;
                gradientLayer.locations = @[@0.0f, @0.52f, @1.0f];
                if (classicDarkStyle)
                {
                    UIColor *topColor = TGNavigationControllerColorWithBrightnessMultiplier(pallete.backgroundColor, 1.30f);
                    UIColor *middleColor = TGNavigationControllerColorWithBrightnessMultiplier(pallete.backgroundColor, 1.00f);
                    UIColor *bottomColor = TGNavigationControllerColorWithBrightnessMultiplier(pallete.backgroundColor, 0.68f);
                    gradientLayer.colors = @[(id)topColor.CGColor, (id)middleColor.CGColor, (id)bottomColor.CGColor];
                }
                else
                {
                    gradientLayer.colors = @[(id)UIColorRGB(0x91b7d5).CGColor, (id)UIColorRGB(0x6f99bc).CGColor, (id)UIColorRGB(0x4d7293).CGColor];
                }
                separatorView.backgroundColor = classicDarkStyle && pallete != nil ? pallete.separatorColor : UIColorRGB(0x36546d);
                navigationBar.tintColor = classicDarkStyle && pallete != nil ? pallete.backgroundColor : UIColorRGB(0x5f89ad);
            }
            else
            {
                backgroundView.backgroundColor = navigationBarClass == [TGWhiteNavigationBar class] ? [UIColor whiteColor] : (pallete != nil ? pallete.backgroundColor : [UIColor whiteColor]);
                gradientView.hidden = true;
                separatorView.hidden = false;
                separatorView.backgroundColor = pallete != nil ? pallete.separatorColor : UIColorRGB(0xb2b2b2);
            }
        }

        [navigationBar sendSubviewToBack:backgroundView];
    }
}

static const NSInteger TGNavigationControllerLegacyBackButtonTag = 0x5447424b;

static void TGNavigationControllerApplyLegacyTextStyle(UINavigationBar *navigationBar, UIView *view, TGNavigationBarPallete *pallete)
{
    if (pallete == nil)
        return;

    UIView *titleView = navigationBar.topItem.titleView;
    if (titleView != nil && (view == titleView || [view isDescendantOfView:titleView]))
        return;

    UIView *leftView = navigationBar.topItem.leftBarButtonItem.customView;
    UIView *rightView = navigationBar.topItem.rightBarButtonItem.customView;
    if ((leftView != nil && (view == leftView || [view isDescendantOfView:leftView])) || (rightView != nil && (view == rightView || [view isDescendantOfView:rightView])))
        return;

    if ([view isKindOfClass:[UILabel class]])
    {
        UILabel *label = (UILabel *)view;
        CGRect frame = [label convertRect:label.bounds toView:navigationBar];
        CGFloat centerX = CGRectGetMidX(frame);
        CGFloat width = navigationBar.bounds.size.width;
        bool centered = centerX > width * 0.30f && centerX < width * 0.70f;
        id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
        if (TGNavigationControllerClassicIOS6Style() && TGNavigationControllerBrandedIOS6Style() && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTitleFont)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTitleShadowColor)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonFont)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonShadowColor)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTitleColor)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonTitleColor)])
        {
            label.textColor = centered ? [provider brandedIOS6NavigationBarTitleColor] : [provider brandedIOS6NavigationBarButtonTitleColor];
            label.shadowColor = centered ? [provider brandedIOS6NavigationBarTitleShadowColor] : [provider brandedIOS6NavigationBarButtonShadowColor];
            label.shadowOffset = CGSizeMake(0.0f, -1.0f);
            label.font = centered ? [provider brandedIOS6NavigationBarTitleFont] : [provider brandedIOS6NavigationBarButtonFont];
        }
        else if (TGNavigationControllerClassicIOS6Style())
        {
            label.textColor = [UIColor whiteColor];
            label.shadowColor = TGNavigationControllerClassicDarkPalette(pallete) ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f);
            label.shadowOffset = CGSizeMake(0.0f, -1.0f);
            label.font = centered ? [UIFont boldSystemFontOfSize:17.0f] : [UIFont boldSystemFontOfSize:12.0f];
        }
        else
        {
            label.textColor = centered ? pallete.titleColor : pallete.tintColor;
            label.shadowColor = [UIColor clearColor];
            label.shadowOffset = CGSizeZero;
            label.font = centered ? [UIFont boldSystemFontOfSize:17.0f] : [UIFont systemFontOfSize:16.0f];
        }
    }

    for (UIView *subview in view.subviews)
        TGNavigationControllerApplyLegacyTextStyle(navigationBar, subview, pallete);
}

static char TGNavigationControllerLegacySystemItemKey;

@interface UIBarButtonItem (TGNavigationControllerLegacySystemItem)
- (id)tgLegacy_initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem target:(id)target action:(SEL)action __attribute__((objc_method_family(init)));
@end

@implementation UIBarButtonItem (TGNavigationControllerLegacySystemItem)
+ (void)load
{
    if (iosMajorVersion() >= 5)
        return;
    Method original = class_getInstanceMethod(self, @selector(initWithBarButtonSystemItem:target:action:));
    Method replacement = class_getInstanceMethod(self, @selector(tgLegacy_initWithBarButtonSystemItem:target:action:));
    if (original != NULL && replacement != NULL)
        method_exchangeImplementations(original, replacement);
    SEL selectors[] = { @selector(setTitle:), @selector(setImage:), @selector(setEnabled:), @selector(setStyle:), @selector(setWidth:) };
    SEL replacements[] = { @selector(tgLegacy_setTitle:), @selector(tgLegacy_setImage:), @selector(tgLegacy_setEnabled:), @selector(tgLegacy_setStyle:), @selector(tgLegacy_setWidth:) };
    for (NSUInteger i = 0; i < sizeof(selectors) / sizeof(selectors[0]); i++)
    {
        Method method = class_getInstanceMethod(self, selectors[i]);
        Method replacementMethod = class_getInstanceMethod(self, replacements[i]);
        if (method != NULL && replacementMethod != NULL)
            method_exchangeImplementations(method, replacementMethod);
    }
}

- (id)tgLegacy_initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem target:(id)target action:(SEL)action
{
    UIBarButtonItem *item = [self tgLegacy_initWithBarButtonSystemItem:systemItem target:target action:action];
    if (item != nil)
        objc_setAssociatedObject(item, &TGNavigationControllerLegacySystemItemKey, @(systemItem), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return item;
}

- (void)tgLegacy_refreshCustomButton
{
    if ([self.customView isKindOfClass:[TGNavigationControllerLegacyItemButton class]])
        [(TGNavigationControllerLegacyItemButton *)self.customView refresh];
}

- (void)tgLegacy_setTitle:(NSString *)value
{
    [self tgLegacy_setTitle:value];
    [self tgLegacy_refreshCustomButton];
}

- (void)tgLegacy_setImage:(UIImage *)value
{
    [self tgLegacy_setImage:value];
    [self tgLegacy_refreshCustomButton];
}

- (void)tgLegacy_setEnabled:(BOOL)value
{
    [self tgLegacy_setEnabled:value];
    [self tgLegacy_refreshCustomButton];
}

- (void)tgLegacy_setStyle:(UIBarButtonItemStyle)value
{
    [self tgLegacy_setStyle:value];
    [self tgLegacy_refreshCustomButton];
}

- (void)tgLegacy_setWidth:(CGFloat)value
{
    [self tgLegacy_setWidth:value];
    [self tgLegacy_refreshCustomButton];
}
@end

static NSString *TGNavigationControllerLegacySystemTitle(UIBarButtonItem *item)
{
    NSNumber *systemItem = objc_getAssociatedObject(item, &TGNavigationControllerLegacySystemItemKey);
    if (systemItem == nil)
        return nil;
    switch ([systemItem intValue])
    {
        case UIBarButtonSystemItemDone: return TGLocalized(@"Common.Done");
        case UIBarButtonSystemItemCancel: return TGLocalized(@"Common.Cancel");
        case UIBarButtonSystemItemEdit: return TGLocalized(@"Common.Edit");
        case UIBarButtonSystemItemSave: return TGLocalized(@"Common.Save");
        case UIBarButtonSystemItemAdd: return @"+";
        default: return nil;
    }
}

static UIImage *TGNavigationControllerLegacySystemImage(UIBarButtonItem *item)
{
    NSNumber *systemItem = objc_getAssociatedObject(item, &TGNavigationControllerLegacySystemItemKey);
    if (systemItem == nil)
        return nil;
    switch ([systemItem intValue])
    {
        case UIBarButtonSystemItemAdd: return TGImageNamed(@"ModernNavigationAddButtonIcon.png");
        case UIBarButtonSystemItemSearch: return TGImageNamed(@"NavigationSearchIcon.png");
        case UIBarButtonSystemItemAction: return TGImageNamed(@"ActionsWhiteIcon.png");
        case UIBarButtonSystemItemCompose: return TGImageNamed(@"ModernNavigationComposeButtonIcon.png");
        case UIBarButtonSystemItemTrash: return TGImageNamed(@"ModernConversationActionDelete.png");
        case UIBarButtonSystemItemPlay: return TGImageNamed(@"MusicPlayerMinimizedPlay.png");
        case UIBarButtonSystemItemPause: return TGImageNamed(@"MusicPlayerMinimizedPause.png");
        default: return nil;
    }
}

static void TGNavigationControllerStyleLegacyItem(UIBarButtonItem *item, TGNavigationBarPallete *pallete)
{
    if (item == nil || pallete == nil)
        return;
    if (item.customView != nil && ![item.customView isKindOfClass:[TGNavigationControllerLegacyItemButton class]])
        return;
    UIImage *image = item.image ?: TGNavigationControllerLegacySystemImage(item);
    NSString *title = item.title ?: (image == nil ? TGNavigationControllerLegacySystemTitle(item) : nil);
    if (item.customView == nil && title.length == 0 && image == nil)
        return;

    TGNavigationControllerLegacyItemButton *button = (TGNavigationControllerLegacyItemButton *)item.customView;
    if (button == nil)
    {
        button = [[TGNavigationControllerLegacyItemButton alloc] initWithFrame:CGRectZero];
        button.item = item;
        [button addTarget:button action:@selector(pressed) forControlEvents:UIControlEventTouchUpInside];
        item.customView = button;
    }
    button.pallete = pallete;
    button.titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    UIFont *font = item.style == UIBarButtonItemStyleDone ? [UIFont boldSystemFontOfSize:16.0f] : [UIFont systemFontOfSize:16.0f];
    button.titleLabel.font = font;
    button.titleLabel.shadowColor = nil;
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:pallete.tintColor forState:UIControlStateNormal];
    [button setTitleColor:[pallete.tintColor colorWithAlphaComponent:0.55f] forState:UIControlStateHighlighted];
    [button setTitleColor:[pallete.tintColor colorWithAlphaComponent:0.35f] forState:UIControlStateDisabled];
    [button setImage:image != nil ? TGTintedImage(image, pallete.tintColor) : nil forState:UIControlStateNormal];
    button.enabled = item.enabled;
    CGFloat width = item.width > 0.0f ? item.width : MAX(32.0f, [title sizeWithFont:font].width + (image != nil ? image.size.width + 6.0f : 0.0f));
    button.frame = CGRectMake(0.0f, 0.0f, MIN(150.0f, width), 44.0f);
}

static void TGNavigationControllerStyleLegacyNavigationItem(UINavigationItem *item, TGNavigationBarPallete *pallete)
{
    if (item == nil || pallete == nil)
        return;
    if (item.titleView == nil || [item.titleView isKindOfClass:[TGNavigationControllerLegacyTitleLabel class]])
    {
        TGNavigationControllerLegacyTitleLabel *label = (TGNavigationControllerLegacyTitleLabel *)item.titleView;
        if (label == nil && item.title.length != 0)
        {
            label = [[TGNavigationControllerLegacyTitleLabel alloc] initWithFrame:CGRectZero];
            label.backgroundColor = [UIColor clearColor];
            label.textAlignment = UITextAlignmentCenter;
            item.titleView = label;
        }
        if (label != nil)
        {
            id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
            bool classic = TGNavigationControllerClassicIOS6Style();
            bool branded = classic && TGNavigationControllerBrandedIOS6Style() && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTitleColor)];
            label.text = item.title;
            label.font = branded ? [provider brandedIOS6NavigationBarTitleFont] : [UIFont boldSystemFontOfSize:17.0f];
            label.textColor = branded ? [provider brandedIOS6NavigationBarTitleColor] : (classic ? [UIColor whiteColor] : pallete.titleColor);
            label.shadowColor = branded ? [provider brandedIOS6NavigationBarTitleShadowColor] : (classic ? UIColorRGBA(0x1f3446, 0.9f) : nil);
            label.shadowOffset = classic ? CGSizeMake(0.0f, -1.0f) : CGSizeZero;
            [label sizeToFit];
        }
    }
    if (!TGNavigationControllerClassicIOS6Style())
    {
        TGNavigationControllerStyleLegacyItem(item.leftBarButtonItem, pallete);
        TGNavigationControllerStyleLegacyItem(item.rightBarButtonItem, pallete);
    }
    else
    {
        if ([item.leftBarButtonItem.customView isKindOfClass:[TGNavigationControllerLegacyItemButton class]])
            item.leftBarButtonItem.customView = nil;
        if ([item.rightBarButtonItem.customView isKindOfClass:[TGNavigationControllerLegacyItemButton class]])
            item.rightBarButtonItem.customView = nil;
    }
}

static NSString *TGNavigationControllerLegacyBackTitle(TGNavigationController *navigationController, UIViewController *viewController)
{
    NSArray *controllers = navigationController.viewControllers;
    NSUInteger index = [controllers indexOfObjectIdenticalTo:viewController];
    if (index == NSNotFound || index == 0)
        return nil;

    UIViewController *previousController = [controllers objectAtIndex:index - 1];
    NSString *title = previousController.navigationItem.backBarButtonItem.title;
    if (title.length == 0)
        title = previousController.navigationItem.title;
    if (title.length == 0)
        title = previousController.title;
    if (title.length == 0)
        title = TGLocalized(@"Common.Back");
    return title;
}

static UIBarButtonItem *TGNavigationControllerLegacyBackItem(TGNavigationController *navigationController, UIViewController *viewController, TGNavigationBarPallete *pallete)
{
    NSString *title = TGNavigationControllerLegacyBackTitle(navigationController, viewController);
    if (title == nil)
        return nil;

    UIColor *tintColor = pallete != nil ? pallete.tintColor : TGAccentColor();
    bool classicIOS6Style = TGNavigationControllerClassicIOS6Style();
    id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
    bool brandedIOS6Style = classicIOS6Style && TGNavigationControllerBrandedIOS6Style() && [provider respondsToSelector:@selector(brandedIOS6NavigationBarBackButtonImageForWidth:highlighted:)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonFont)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonShadowColor)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonTitleColor)];
    UIFont *font = brandedIOS6Style ? [provider brandedIOS6NavigationBarButtonFont] : (classicIOS6Style ? [UIFont boldSystemFontOfSize:12.0f] : [UIFont systemFontOfSize:16.0f]);
    CGSize titleSize = [title sizeWithFont:font];
    UIImage *normalImage = nil;
    UIImage *highlightedImage = nil;
    CGFloat width = 0.0f;
    if (classicIOS6Style)
    {
        width = MIN(150.0f, MAX(44.0f, titleSize.width + 25.0f));
        normalImage = brandedIOS6Style ? [provider brandedIOS6NavigationBarBackButtonImageForWidth:width highlighted:false] : TGNavigationControllerClassicIOS6BackImage(false, pallete);
        highlightedImage = brandedIOS6Style ? [provider brandedIOS6NavigationBarBackButtonImageForWidth:width highlighted:true] : TGNavigationControllerClassicIOS6BackImage(true, pallete);
    }
    else
    {
        normalImage = TGTintedImage(TGImageNamed(@"NavigationBackButton.png"), tintColor);
        highlightedImage = TGTintedImage(TGImageNamed(@"NavigationBackButton_Highlighted.png"), [tintColor colorWithAlphaComponent:0.55f]);
        width = MIN(150.0f, MAX(32.0f, normalImage.size.width + 5.0f + titleSize.width));
    }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = TGNavigationControllerLegacyBackButtonTag;
    button.frame = CGRectMake(0.0f, 0.0f, width, classicIOS6Style ? 30.0f : 44.0f);
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.titleLabel.font = font;
    button.titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    if (classicIOS6Style)
    {
        [button setBackgroundImage:normalImage forState:UIControlStateNormal];
        [button setBackgroundImage:highlightedImage ?: normalImage forState:UIControlStateHighlighted];
        UIColor *titleColor = brandedIOS6Style ? [provider brandedIOS6NavigationBarButtonTitleColor] : [UIColor whiteColor];
        [button setTitleColor:titleColor forState:UIControlStateNormal];
        [button setTitleColor:titleColor forState:UIControlStateHighlighted];
        button.titleLabel.shadowColor = brandedIOS6Style ? [provider brandedIOS6NavigationBarButtonShadowColor] : (TGNavigationControllerClassicDarkPalette(pallete) ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f));
        button.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        button.contentEdgeInsets = UIEdgeInsetsMake(0.0f, 14.0f, 0.0f, 8.0f);
    }
    else
    {
        [button setImage:normalImage forState:UIControlStateNormal];
        [button setImage:highlightedImage ?: normalImage forState:UIControlStateHighlighted];
        [button setTitleColor:tintColor forState:UIControlStateNormal];
        [button setTitleColor:[tintColor colorWithAlphaComponent:0.55f] forState:UIControlStateHighlighted];
        button.titleEdgeInsets = UIEdgeInsetsMake(0.0f, 4.0f, 0.0f, 0.0f);
    }
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:navigationController action:@selector(tgLegacyBackButtonPressed) forControlEvents:UIControlEventTouchUpInside];

    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

static void TGNavigationControllerInstallLegacyBackItem(TGNavigationController *navigationController, UIViewController *viewController, TGNavigationBarPallete *pallete)
{
    NSArray *controllers = navigationController.viewControllers;
    NSUInteger index = [controllers indexOfObjectIdenticalTo:viewController];
    if (index == NSNotFound || index == 0 || viewController.navigationItem.hidesBackButton)
        return;

    UIBarButtonItem *leftItem = viewController.navigationItem.leftBarButtonItem;
    if (leftItem == nil || leftItem.customView.tag == TGNavigationControllerLegacyBackButtonTag)
        viewController.navigationItem.leftBarButtonItem = TGNavigationControllerLegacyBackItem(navigationController, viewController, pallete);
}

@implementation TGNavigationController

+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller
{
    return [self navigationControllerWithControllers:[NSArray arrayWithObject:controller]];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers
{
    return [self navigationControllerWithControllers:controllers navigationBarClass:[TGNavigationBar class]];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers navigationBarClass:(Class)navigationBarClass
{
    return [self navigationControllerWithControllers:controllers navigationBarClass:navigationBarClass inhibitPresentation:false];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers navigationBarClass:(Class)navigationBarClass inhibitPresentation:(bool)inhibitPresentation
{
    TGNavigationController *navigationController = [[TGNavigationController alloc] initWithNavigationBarClass:navigationBarClass toolbarClass:[UIToolbar class]];
    
    TGNavigationBarPallete *pallete = nil;
    if (!inhibitPresentation && [[LegacyComponentsGlobals provider] respondsToSelector:@selector(navigationBarPallete)])
        pallete = [[LegacyComponentsGlobals provider] navigationBarPallete];
    [navigationController setNavigationBarPallete:pallete];
    
    bool first = true;
    for (id controller in controllers) {
        if ([controller isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)controller setIsFirstInStack:first];
        }
        first = false;
    }
    [navigationController setViewControllers:controllers];
    
    if ([navigationController.navigationBar isKindOfClass:[TGNavigationBar class]])
        ((TGNavigationBar *)navigationController.navigationBar).navigationController = navigationController;
    
    return navigationController;
}

+ (TGNavigationController *)makeWithRootController:(UIViewController *)controller {
    return [self navigationControllerWithControllers:[NSArray arrayWithObject:controller]];
}

- (instancetype)initWithNavigationBarClass:(Class)navigationBarClass toolbarClass:(Class)toolbarClass
{
    if (iosMajorVersion() >= 5 && [UINavigationController instancesRespondToSelector:@selector(initWithNavigationBarClass:toolbarClass:)])
        self = [super initWithNavigationBarClass:navigationBarClass toolbarClass:toolbarClass];
    else
        self = [super init];
    if (self != nil)
    {
        _requestedNavigationBarClass = navigationBarClass;
        if (iosMajorVersion() < 5)
        {
            UINavigationBar *bar = self.navigationBar;
            _legacyNavigationBar = bar;
            Class originalClass = object_getClass(bar);
            Class legacyClass = objc_getAssociatedObject(originalClass, &TGNavigationControllerLegacyBarClassKey);
            if (legacyClass == Nil)
            {
                legacyClass = freedomMakeClass(originalClass, [TGNavigationControllerLegacyNavigationBar class]);
                objc_setAssociatedObject(originalClass, &TGNavigationControllerLegacyBarClassKey, legacyClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            objc_setAssociatedObject(bar, &TGNavigationControllerLegacyOriginalBarClassKey, originalClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (class_getInstanceSize(originalClass) == class_getInstanceSize(legacyClass))
                object_setClass(bar, legacyClass);
            objc_setAssociatedObject(bar, &TGNavigationControllerLegacyOwnerKey, self, OBJC_ASSOCIATION_ASSIGN);
            TGNavigationControllerApplyNavigationBar(bar, _requestedNavigationBarClass, nil);
        }
    }
    return self;
}

- (void)setNavigationBarPallete:(TGNavigationBarPallete *)pallete
{
    _legacyNavigationBarPallete = pallete;
    TGNavigationControllerApplyNavigationBar(self.navigationBar, _requestedNavigationBarClass, pallete);
    [self.navigationBar setNeedsLayout];
}

- (void)dealloc
{
    if (_legacyNavigationBar != nil)
        objc_setAssociatedObject(_legacyNavigationBar, &TGNavigationControllerLegacyOwnerKey, nil, OBJC_ASSOCIATION_ASSIGN);
    [_playerStatusDisposable dispose];
    self.delegate = nil;
    [_dimmingTapRecognizer.view removeGestureRecognizer:_dimmingTapRecognizer];
    
    if (_becomeActiveObserver != nil)
        [[NSNotificationCenter defaultCenter] removeObserver:_becomeActiveObserver];
}

- (void)loadView
{
    [super loadView];
    
    if (iosMajorVersion() >= 11) {
        self.navigationBar.prefersLargeTitles = false;
    }
    
    if (iosMajorVersion() >= 8 && !TGIsRTL())
    {
        _originalInteractivePopGestureRecognizerClass = object_getClass(self.interactivePopGestureRecognizer);
        _fullScreenInteractivePopGestureRecognizerClass = objc_getAssociatedObject(_originalInteractivePopGestureRecognizerClass, &TGNavigationFullScreenPanClassKey);
        if (_fullScreenInteractivePopGestureRecognizerClass == Nil)
        {
            _fullScreenInteractivePopGestureRecognizerClass = freedomMakeClass(_originalInteractivePopGestureRecognizerClass, [TGNavigationFullScreenPanMethods class]);
            objc_setAssociatedObject(_originalInteractivePopGestureRecognizerClass, &TGNavigationFullScreenPanClassKey, _fullScreenInteractivePopGestureRecognizerClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [self configureInteractivePopGestureForControllers:self.viewControllers];
        self.interactivePopGestureRecognizer.delaysTouchesBegan = false;
        self.interactivePopGestureRecognizer.delaysTouchesEnded = true;
        self.interactivePopGestureRecognizer.cancelsTouchesInView = true;
        
        _gestureDelegate = [[TGNavigationGestureDelegateProxy alloc] init];
        _gestureDelegate.delegate = self.interactivePopGestureRecognizer.delegate;
        
        __weak TGNavigationController *weakSelf = self;
        _gestureDelegate.shouldBegin = ^bool(UIPanGestureRecognizer *gestureRecognizer)
        {
            __strong TGNavigationController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                bool shouldBegin = [strongSelf _gestureRecognizerShouldBegin:gestureRecognizer];
                if (shouldBegin)
                {
                    CGPoint location = [gestureRecognizer locationInView:nil];
                    CGPoint velocity = [gestureRecognizer velocityInView:nil];
                    if (strongSelf->_fixNextInteractiveTransition)
                    {
                        bool fixableLocation = (!TGIsRTL() && location.x > 44.0f) || (TGIsRTL() && location.x < gestureRecognizer.view.frame.size.width - 44.0f);
                        bool fixableVelovity = TGIsRTL() ? velocity.x <= -150 : velocity.x >= 150;

                        if (fixableLocation && fixableVelovity)
                        {
                            [strongSelf popViewControllerAnimated:true];
                            shouldBegin = false;
                        }
                    }
                    strongSelf->_fixNextInteractiveTransition = false;
                }
                return shouldBegin;
            }
            return false;
        };
        _gestureDelegate.shouldRecognizeWith = ^bool(UIPanGestureRecognizer *gestureRecognizer, UIGestureRecognizer *otherGestureRecognizer)
        {
            __strong TGNavigationController *strongSelf = weakSelf;
            if (strongSelf != nil)
                return [strongSelf _gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
            return false;
        };
        self.interactivePopGestureRecognizer.delegate = _gestureDelegate;
        
        if ([TGViewController hasTallScreen] && _becomeActiveObserver == nil && _enterBackgroundObserver == nil)
        {
            __weak TGNavigationController *weakSelf = self;
            _enterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *  note)
            {
                __strong TGNavigationController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [[NSNotificationCenter defaultCenter] removeObserver:strongSelf->_enterBackgroundObserver];
                    strongSelf->_enterBackgroundObserver = nil;
                    
                    if (strongSelf->_becomeActiveObserver == nil)
                    {
                        strongSelf->_becomeActiveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *  note) {
                            __strong TGNavigationController *strongSelf = weakSelf;
                            if (strongSelf != nil) {
                                if ([TGViewController hasTallScreen])
                                    strongSelf->_fixNextInteractiveTransition = true;
                            }
                        }];
                    }
                }
            }];
        }
    }
}

- (bool)_gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (_animatingControllerPush)
        return false;
        
    CGPoint velocity = [gestureRecognizer velocityInView:gestureRecognizer.view];
    if (fabs(velocity.y) > fabs(velocity.x))
        return false;
    
    if ((!TGIsRTL() && velocity.x < FLT_EPSILON) || (TGIsRTL() && velocity.x > FLT_EPSILON))
        return false;
    
    CGPoint location = [gestureRecognizer locationInView:gestureRecognizer.view];
    if (location.y < CGRectGetMaxY([self.navigationBar convertRect:self.navigationBar.bounds toView:gestureRecognizer.view]))
        return false;
    
    UIView *view = [gestureRecognizer.view hitTest:location withEvent:nil];
    if (view.tag == 0xdead || ([view isKindOfClass:[UIControl class]] && ![view isKindOfClass:[UIButton class]]))
        return false;
    
    return self.viewControllers.count > 1;
}

- (bool)_gestureRecognizer:(UIPanGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (_animatingControllerPush)
        return false;
    
    CGPoint location = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    if (self.viewControllers.count == 1)
        return false;
    
    bool (^isEdgePan)(void) = ^bool
    {
        if ((!TGIsRTL() && location.x < 44.0f) || (TGIsRTL() && location.x > gestureRecognizer.view.frame.size.width - 44.0f))
        {
            CGPoint velocity = [gestureRecognizer velocityInView:gestureRecognizer.view];
            if (fabs(velocity.x) >= fabs(velocity.y))
            {
                otherGestureRecognizer.enabled = false;
                otherGestureRecognizer.enabled = true;
                return true;
            }
        }
        return false;
    };
    
    if (otherGestureRecognizer.view.tag == 0xdead)
    {
        return false;
    }
    else if ([otherGestureRecognizer.view isKindOfClass:[UIScrollView class]])
    {
        UIScrollView *scrollView = (UIScrollView *)otherGestureRecognizer.view;
        bool viewIsHorizontalScrollView = !TGIsRTL() && scrollView.contentSize.height > FLT_EPSILON && scrollView.contentSize.width > scrollView.contentSize.height && fabs(scrollView.contentOffset.x + scrollView.contentInset.left) < FLT_EPSILON && scrollView.tag != 0xbeef;
        bool viewIsDeceleratingScrollView = scrollView.contentSize.height > scrollView.contentSize.width && scrollView.isDecelerating;
        if (viewIsHorizontalScrollView || viewIsDeceleratingScrollView)
        {
            if (viewIsHorizontalScrollView)
            {
                CGPoint velocity = [gestureRecognizer velocityInView:gestureRecognizer.view];
                if ((!TGIsRTL() && velocity.x < FLT_EPSILON) || (TGIsRTL() && velocity.x > FLT_EPSILON))
                    return false;
                
                otherGestureRecognizer.enabled = false;
                otherGestureRecognizer.enabled = true;
            }
            return true;
        }
        else
        {
            if (isEdgePan())
                return true;
        }
    }
    else
    {
        if (isEdgePan())
            return true;
    }
    return false;
}

- (void)tgLegacyBackButtonPressed
{
    if (self.viewControllers.count <= 1)
        return;

    if (iosMajorVersion() < 5)
    {
        if (_legacyBackTransitionInProgress)
            return;

        _legacyBackTransitionInProgress = true;
        UIBarButtonItem *leftItem = self.topViewController.navigationItem.leftBarButtonItem;
        if (leftItem.customView.tag == TGNavigationControllerLegacyBackButtonTag && [leftItem.customView isKindOfClass:[UIControl class]])
            ((UIControl *)leftItem.customView).enabled = false;

        if ([self popViewControllerAnimated:true] == nil)
        {
            _legacyBackTransitionInProgress = false;
            if ([leftItem.customView isKindOfClass:[UIControl class]])
                ((UIControl *)leftItem.customView).enabled = true;
        }
        return;
    }

    [self popViewControllerAnimated:true];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)__unused animated
{
    if (iosMajorVersion() < 5)
    {
        TGNavigationBarPallete *pallete = [[LegacyComponentsGlobals provider] respondsToSelector:@selector(navigationBarPallete)] ? [[LegacyComponentsGlobals provider] navigationBarPallete] : nil;
        TGNavigationControllerApplyNavigationBar(navigationController.navigationBar, _requestedNavigationBarClass, pallete);

        TGNavigationControllerInstallLegacyBackItem(self, viewController, pallete);
    }
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    _animatingControllerPush = false;
    _legacyBackTransitionInProgress = false;
    [self configureInteractivePopGestureForControllers:self.viewControllers];

    if (iosMajorVersion() < 5)
    {
        TGNavigationBarPallete *pallete = [[LegacyComponentsGlobals provider] respondsToSelector:@selector(navigationBarPallete)] ? [[LegacyComponentsGlobals provider] navigationBarPallete] : nil;
        TGNavigationControllerApplyNavigationBar(navigationController.navigationBar, _requestedNavigationBarClass, pallete);
        TGNavigationControllerInstallLegacyBackItem(self, viewController, pallete);
        TGNavigationControllerApplyLegacyTextStyle(navigationController.navigationBar, navigationController.navigationBar, pallete);
    }
}

- (void)setDisplayPlayer:(bool)displayPlayer
{
    _displayPlayer = displayPlayer;
    if (iosMajorVersion() < 5)
    {
        [_playerStatusDisposable dispose];
        _playerStatusDisposable = nil;
        if (displayPlayer)
        {
            __weak TGNavigationController *weakSelf = self;
            _playerStatusDisposable = [[[TGNavigationBar musicPlayerProvider].musicPlayerIsActive deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *active)
            {
                TGNavigationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                bool isActive = [active boolValue];
                if (isActive && strongSelf->_currentAdditionalNavigationBarHeight < FLT_EPSILON)
                    strongSelf->_minimizePlayer = false;
                if (isActive && strongSelf->_legacyMusicPlayerView == nil)
                {
                    strongSelf->_legacyMusicPlayerView = [[TGNavigationBar musicPlayerProvider] makeMusicPlayerView:strongSelf];
                    strongSelf->_legacyMusicPlayerContainer = [[UIView alloc] init];
                    strongSelf->_legacyMusicPlayerContainer.clipsToBounds = true;
                    [strongSelf->_legacyMusicPlayerContainer addSubview:strongSelf->_legacyMusicPlayerView];
                    [strongSelf.view addSubview:strongSelf->_legacyMusicPlayerContainer];
                }
                id<TGNavigationBarMusicPlayerProvider> provider = [TGNavigationBar musicPlayerProvider];
                CGFloat height = [provider respondsToSelector:@selector(musicPlayerHeight)] ? [provider musicPlayerHeight] : 37.0f;
                strongSelf->_currentAdditionalNavigationBarHeight = isActive ? (strongSelf->_minimizePlayer ? 2.0f : height) : 0.0f;
                [strongSelf layoutLegacyMusicPlayer];
                [strongSelf updatePlayerOnControllers];
            }];
        }
        else
        {
            _currentAdditionalNavigationBarHeight = 0.0f;
            [self layoutLegacyMusicPlayer];
            [self updatePlayerOnControllers];
        }
        return;
    }
    
    if (_displayPlayer && [self.navigationBar isKindOfClass:[TGNavigationBar class]])
    {
        __weak TGNavigationController *weakSelf = self;
        [_playerStatusDisposable dispose];
        _playerStatusDisposable = [[[TGNavigationBar musicPlayerProvider].musicPlayerIsActive deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *nIsActive)
        {
            __strong TGNavigationController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                bool isActive = [nIsActive boolValue];
                
                if (isActive && strongSelf->_currentAdditionalNavigationBarHeight < FLT_EPSILON)
                {
                    strongSelf->_minimizePlayer = false;
                    [(TGNavigationBar *)self.navigationBar setMinimizedMusicPlayer:_minimizePlayer];
                }
                
                CGFloat currentAdditionalNavigationBarHeight = !isActive ? 0.0f : (strongSelf->_minimizePlayer ? 2.0f : ((TGNavigationBar *)strongSelf.navigationBar).musicPlayerHeight);
                if (ABS(strongSelf->_currentAdditionalNavigationBarHeight - currentAdditionalNavigationBarHeight) > FLT_EPSILON)
                {
                    strongSelf->_currentAdditionalNavigationBarHeight = currentAdditionalNavigationBarHeight;
                    [((TGNavigationBar *)strongSelf.navigationBar) showMusicPlayerView:isActive animation:^
                    {
                        [strongSelf updatePlayerOnControllers];
                    }];
                }
            }
        }];
    }
    else
    {
        [_playerStatusDisposable dispose];
    }
}

- (void)setMinimizePlayer:(bool)minimizePlayer
{
    if (_minimizePlayer != minimizePlayer)
    {
        _minimizePlayer = minimizePlayer;
        
        if (_currentAdditionalNavigationBarHeight > FLT_EPSILON)
        {
            id<TGNavigationBarMusicPlayerProvider> provider = [TGNavigationBar musicPlayerProvider];
            CGFloat legacyHeight = [provider respondsToSelector:@selector(musicPlayerHeight)] ? [provider musicPlayerHeight] : 37.0f;
            _currentAdditionalNavigationBarHeight = _minimizePlayer ? 2.0f : ([self.navigationBar isKindOfClass:[TGNavigationBar class]] ? ((TGNavigationBar *)self.navigationBar).musicPlayerHeight : legacyHeight);
        }
        if ([self.navigationBar isKindOfClass:[TGNavigationBar class]])
            [(TGNavigationBar *)self.navigationBar setMinimizedMusicPlayer:_minimizePlayer];
        
        [UIView animateWithDuration:0.25 animations:^
        {
            [self layoutLegacyMusicPlayer];
            [self updatePlayerOnControllers];
        }];
    }
}

- (void)setShowCallStatusBar:(bool)showCallStatusBar
{
    if (_showCallStatusBar == showCallStatusBar)
        return;
    
    _showCallStatusBar = showCallStatusBar;
    
    
    CGFloat statusBarHeight = (int)TGScreenSize().height == 812 ? 0.0f : 20.0f;
    
    _currentAdditionalStatusBarHeight = _showCallStatusBar ? statusBarHeight : 0.0f;
    if ([self.navigationBar isKindOfClass:[TGNavigationBar class]])
        [(TGNavigationBar *)self.navigationBar setVerticalOffset:_currentAdditionalStatusBarHeight];
    
    [UIView animateWithDuration:0.25 animations:^
    {
        static SEL selector = NULL;
        static void (*impl)(id, SEL) = NULL;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            selector = NSSelectorFromString(TGEncodeText(@"`vqebufCbstGpsDvssfouJoufsgbdfPsjfoubujpo", -1));
            Method method = class_getInstanceMethod([UINavigationController class], selector);
            impl = (void (*)(id, SEL))method_getImplementation(method);
        });
        
        if (impl != NULL)
            impl(self, selector);

        [self updateStatusBarOnControllers];
    }];
}


- (void)setupStatusBarOnControllers:(NSArray *)controllers
{
    if ([[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in controllers)
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *controller = maybeController;
                [controller setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
            }
            else if ([maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                [self setupPlayerOnControllers:((UITabBarController *)maybeController).viewControllers];
            }
        }
    }
}

- (void)updateStatusBarOnControllers
{
    if ([[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in [self viewControllers])
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *viewController = (TGViewController *)maybeController;
                [viewController setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
                [viewController setNeedsStatusBarAppearanceUpdate];
                
                if ([viewController.presentedViewController isKindOfClass:[TGNavigationController class]] && viewController.presentedViewController.modalPresentationStyle != UIModalPresentationPopover)
                {
                    [(TGNavigationController *)viewController.presentedViewController setShowCallStatusBar:_showCallStatusBar];
                }
            }
            else if ([maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                for (id controller in ((UITabBarController *)maybeController).viewControllers)
                {
                    if ([controller isKindOfClass:[TGViewController class]])
                    {
                        [((TGViewController *)controller) setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
                    }
                }
                if (iosMajorVersion() >= 7)
                    [((UIViewController *)maybeController) setNeedsStatusBarAppearanceUpdate];
            }
        }
    }
}

static UIView *findDimmingView(UIView *view)
{
    static NSString *encodedString = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        encodedString = TGEncodeText(@"VJEjnnjohWjfx", -1);
    });
    
    if ([NSStringFromClass(view.class) isEqualToString:encodedString])
        return view;
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = findDimmingView(subview);
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self layoutNavigationContentView];

    if (self.modalPresentationStyle == UIModalPresentationFormSheet)
    {
        UIView *dimmingView = findDimmingView(self.view.window);
        bool tapSetup = false;
        if (_dimmingTapRecognizer != nil)
        {
            for (UIGestureRecognizer *recognizer in dimmingView.gestureRecognizers)
            {
                if (recognizer == _dimmingTapRecognizer)
                {
                    tapSetup = true;
                    break;
                }
            }
        }
        
        if (!tapSetup)
        {
            _dimmingTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimmingViewTapped:)];
            [dimmingView addGestureRecognizer:_dimmingTapRecognizer];
        }
    }
}

- (void)dimmingViewTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
    }
}

- (void)tgLegacyNavigationBarWillLayout
{
    TGNavigationBarPallete *pallete = _legacyNavigationBarPallete ?: ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(navigationBarPallete)] ? [[LegacyComponentsGlobals provider] navigationBarPallete] : nil);
    for (UINavigationItem *item in self.navigationBar.items)
        TGNavigationControllerStyleLegacyNavigationItem(item, pallete);
}

- (void)tgLegacyNavigationBarDidLayout
{
    TGNavigationBarPallete *pallete = _legacyNavigationBarPallete ?: ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(navigationBarPallete)] ? [[LegacyComponentsGlobals provider] navigationBarPallete] : nil);
    TGNavigationControllerApplyNavigationBar(self.navigationBar, _requestedNavigationBarClass, pallete);
    TGNavigationControllerApplyLegacyTextStyle(self.navigationBar, self.navigationBar, pallete);
    [self layoutLegacyMusicPlayer];
    [self updatePlayerOnControllers];
}

- (void)layoutLegacyMusicPlayer
{
    if (_legacyMusicPlayerContainer == nil)
        return;
    CGRect barFrame = [self.navigationBar convertRect:self.navigationBar.bounds toView:self.view];
    id<TGNavigationBarMusicPlayerProvider> provider = [TGNavigationBar musicPlayerProvider];
    CGFloat height = [provider respondsToSelector:@selector(musicPlayerHeight)] ? [provider musicPlayerHeight] : 37.0f;
    _legacyMusicPlayerContainer.frame = CGRectMake(CGRectGetMinX(barFrame), CGRectGetMaxY(barFrame), barFrame.size.width, _currentAdditionalNavigationBarHeight);
    _legacyMusicPlayerContainer.hidden = !_displayPlayer || _currentAdditionalNavigationBarHeight < FLT_EPSILON || self.navigationBarHidden;
    _legacyMusicPlayerView.frame = CGRectMake(0.0f, _minimizePlayer ? 2.0f - height : 0.0f, barFrame.size.width, height);
    [self.view bringSubviewToFront:_legacyMusicPlayerContainer];
}

- (void)layoutNavigationContentView
{
    CGSize screenSize = TGScreenSize();

    static Class containerClass = nil;

    if (freedomInitialized())
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            containerClass = freedomClass(0xf045e5dfU);
        });
    }

    for (UIView *view in self.view.subviews)
    {
        bool isContainerView = false;
        if (freedomInitialized())
            isContainerView = [view isKindOfClass:containerClass];
        else
            isContainerView = [NSStringFromClass(view.class) rangeOfString:@"TransitionView"].location != NSNotFound;

        if (isContainerView)
        {
            CGRect frame = view.frame;

            if (ABS(frame.size.width - screenSize.width) < FLT_EPSILON)
            {
                if (ABS(frame.size.height - screenSize.height + 20) < FLT_EPSILON)
                {
                    frame.origin.y = frame.size.height - screenSize.height;
                    frame.size.height = screenSize.height;
                }
                else if (frame.size.height > screenSize.height + FLT_EPSILON)
                {
                    frame.origin.y = 0;
                    frame.size.height = screenSize.height;
                }
            }
            else if (ABS(frame.size.width - screenSize.height) < FLT_EPSILON)
            {
                if (frame.size.height > screenSize.width + FLT_EPSILON)
                {
                    frame.origin.y = 0;
                    frame.size.height = screenSize.width;
                }
            }

            if (ABS(frame.size.height) < FLT_EPSILON)
                frame.size.height = screenSize.height;

            if (!CGRectEqualToRect(view.frame, frame))
                view.frame = frame;

            break;
        }
    }

    if (iosMajorVersion() < 5)
    {
        TGNavigationBarPallete *pallete = [[LegacyComponentsGlobals provider] respondsToSelector:@selector(navigationBarPallete)] ? [[LegacyComponentsGlobals provider] navigationBarPallete] : nil;
        TGNavigationControllerApplyNavigationBar(self.navigationBar, _requestedNavigationBarClass, pallete);
        TGNavigationControllerApplyLegacyTextStyle(self.navigationBar, self.navigationBar, pallete);
        [self tgLegacyNavigationBarWillLayout];
        [self layoutLegacyMusicPlayer];
    }

    _didFirstLayout = true;
}

- (void)viewDidLayoutSubviews
{
    if (iosMajorVersion() >= 5)
        [super viewDidLayoutSubviews];
    [self layoutNavigationContentView];
}

- (void)viewDidLoad
{   
    self.delegate = self;
    
    [super viewDidLoad];
}

- (void)updateControllerLayout:(bool)__unused animated
{
}

- (void)updateNavigationBarBackgroundForController:(UIViewController *)viewController
{
    TGNavigationBarBackgroundVariant backgroundVariant = TGNavigationBarBackgroundVariantDefault;
    if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)] && [viewController respondsToSelector:@selector(navigationBarBackgroundVariant)])
        backgroundVariant = [(id<TGViewControllerNavigationBarAppearance>)viewController navigationBarBackgroundVariant];

    if (![self.navigationBar isKindOfClass:[TGNavigationBar class]])
    {
        TGNavigationControllerUpdateLegacyBrandedBackground(self.navigationBar, backgroundVariant);
        return;
    }

    TGNavigationBar *navigationBar = (TGNavigationBar *)self.navigationBar;
    if (navigationBar.backgroundVariant == backgroundVariant)
        return;
    navigationBar.backgroundVariant = backgroundVariant;
    TGNavigationControllerUpdateLegacyBrandedBackground(navigationBar, backgroundVariant);
}

- (void)setupNavigationBarForController:(UIViewController *)viewController animated:(bool)animated
{
    UIBarStyle barStyle = UIBarStyleDefault;
    bool navigationBarShouldBeHidden = false;
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleBlackOpaque;
    bool statusBarShouldBeHidden = false;
    
    if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        id<TGViewControllerNavigationBarAppearance> appearance = (id<TGViewControllerNavigationBarAppearance>)viewController;
        
        barStyle = [appearance requiredNavigationBarStyle];
        navigationBarShouldBeHidden = [appearance navigationBarShouldBeHidden];
        if ([appearance respondsToSelector:@selector(preferredStatusBarStyle)])
            statusBarStyle = [appearance preferredStatusBarStyle];
        if ([appearance respondsToSelector:@selector(statusBarShouldBeHidden)])
            statusBarShouldBeHidden = [appearance statusBarShouldBeHidden];
    }

    if (iosMajorVersion() < 5 && TGNavigationControllerClassicIOS6Style() && !statusBarShouldBeHidden)
        statusBarStyle = UIStatusBarStyleBlackOpaque;
    
    if (navigationBarShouldBeHidden != self.navigationBarHidden)
    {
        [self setNavigationBarHidden:navigationBarShouldBeHidden animated:animated];
    }

    [self updateNavigationBarBackgroundForController:viewController];
    
    if ([[LegacyComponentsGlobals provider] isStatusBarHidden] != statusBarShouldBeHidden)
        [[LegacyComponentsGlobals provider] setStatusBarHidden:statusBarShouldBeHidden withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    if ([[LegacyComponentsGlobals provider] statusBarStyle] != statusBarStyle)
        [[LegacyComponentsGlobals provider] setStatusBarStyle:statusBarStyle animated:animated];
}

- (UIInterfaceOrientation)interfaceOrientation
{
    if (iosMajorVersion() <= 4)
        return [UIApplication sharedApplication].statusBarOrientation;
    return [super interfaceOrientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (_restrictLandscape)
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    
    if (self.topViewController != nil)
        return [self.topViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    if (iosMajorVersion() < 6)
        return [self shouldAutorotateToInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];

    if (_restrictLandscape)
        return false;
    
    if (self.topViewController != nil)
    {
        if ([self.topViewController respondsToSelector:@selector(shouldAutorotate)])
        {
            if (![self.topViewController shouldAutorotate])
                return false;
        }
    }
    
    bool result = [super shouldAutorotate];
    if (!result)
        return false;
    
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)])
    {
        UIGestureRecognizerState state = self.interactivePopGestureRecognizer.state;
        if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
            return false;
    }
    
    return true;
}

- (void)acquireRotationLock
{
    if (_autorotationLock == nil)
        _autorotationLock = [[TGAutorotationLock alloc] init];
}

- (void)releaseRotationLock
{
    _autorotationLock = nil;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (_restrictLandscape)
        return UIInterfaceOrientationMaskPortrait;
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (!hidden)
        self.navigationBar.alpha = 1.0f;
    
    if ([self.navigationBar isKindOfClass:[TGNavigationBar class]])
        [(TGNavigationBar *)self.navigationBar setHiddenState:hidden animated:animated];
    
    [super setNavigationBarHidden:hidden animated:animated];
    [self layoutLegacyMusicPlayer];
}

- (void)setupPlayerOnControllers:(NSArray *)controllers
{
    if (iosMajorVersion() < 5 || ((_displayPlayer || _forceAdditionalNavigationBarHeight) && [[self navigationBar] isKindOfClass:[TGNavigationBar class]]))
    {
        for (id maybeController in controllers)
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *controller = maybeController;
                [controller setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
            }
            else if ((_displayPlayer || iosMajorVersion() < 5) && [maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                [self setupPlayerOnControllers:((UITabBarController *)maybeController).viewControllers];
            }
        }
    }
}

- (void)updatePlayerOnControllers
{
    if (iosMajorVersion() < 5 || ((_displayPlayer || _forceAdditionalNavigationBarHeight) && [[self navigationBar] isKindOfClass:[TGNavigationBar class]]))
    {
        for (id maybeController in [self viewControllers])
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                [((TGViewController *)maybeController) setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
            }
            else if ((_displayPlayer || iosMajorVersion() < 5) && [maybeController isKindOfClass:[UITabBarController class]] && [maybeController conformsToProtocol:@protocol(TGNavigationControllerTabsController)])
            {
                for (id controller in ((UITabBarController *)maybeController).viewControllers)
                {
                    if ([controller isKindOfClass:[TGViewController class]])
                    {
                        [((TGViewController *)controller) setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
                    }
                }
            }
        }
    }
}

- (void)configureInteractivePopGestureForControllers:(NSArray *)controllers
{
    if (_originalInteractivePopGestureRecognizerClass == Nil)
        return;
    Class previewClass = NSClassFromString(@"QLPreviewController");
    bool containsPreview = false;
    for (UIViewController *controller in controllers)
    {
        if (previewClass != Nil && [controller isKindOfClass:previewClass])
        {
            containsPreview = true;
            break;
        }
    }
    Class desiredClass = containsPreview ? _originalInteractivePopGestureRecognizerClass : _fullScreenInteractivePopGestureRecognizerClass;
    UIGestureRecognizer *recognizer = self.interactivePopGestureRecognizer;
    if (desiredClass != Nil && object_getClass(recognizer) != desiredClass && class_getInstanceSize(desiredClass) == class_getInstanceSize(_originalInteractivePopGestureRecognizerClass))
        object_setClass(recognizer, desiredClass);
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (_animatingControllerPush)
        return;
    
    _fixNextInteractiveTransition = false;
    
    if (self.viewControllers.count == 0) {
        if ([viewController isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)viewController setIsFirstInStack:true];
        } else {
            [(TGViewController *)viewController setIsFirstInStack:false];
        }
    }
    _isInControllerTransition = true;
    if (viewController != nil) {
        [self setupPlayerOnControllers:@[viewController]];
        [self setupStatusBarOnControllers:@[viewController]];
    }
    [self configureInteractivePopGestureForControllers:[self.viewControllers arrayByAddingObject:viewController]];
    [super pushViewController:viewController animated:animated];
    _isInControllerTransition = false;
    
    _animatingControllerPush = animated;
    if (_animatingControllerPush)
    {
        TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
        {
            _animatingControllerPush = false;
        });
    }
    
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    bool first = true;
    for (id controller in viewControllers) {
        if ([controller isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)controller setIsFirstInStack:first];
        }
        first = false;
    }
    
    _isInControllerTransition = true;
    [self setupPlayerOnControllers:viewControllers];
    [self setupStatusBarOnControllers:viewControllers];
    [self configureInteractivePopGestureForControllers:viewControllers];
    [super setViewControllers:viewControllers animated:animated];
    _isInControllerTransition = false;
    
    _animatingControllerPush = animated;
    if (_animatingControllerPush)
    {
        TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
        {
            _animatingControllerPush = false;
        });
    }
}

- (BOOL)navigationBar:(UINavigationBar *)navigationBar shouldPopItem:(UINavigationItem *)item
{
    if (self.viewControllers.count < navigationBar.items.count)
        return true;
    
    bool shouldPop = true;
    if (self.shouldPopController != nil) {
        shouldPop = self.shouldPopController(self.topViewController);
    }
    
    if (shouldPop)
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self popViewControllerAnimated:YES];
        });
    } else
    {
        for (UIView *subview in [navigationBar subviews])
        {
            if (0.< subview.alpha && subview.alpha < 1.)
            {
                [UIView animateWithDuration:.25 animations:^
                {
                    subview.alpha = 1.;
                }];
            }
        }
    }
    
    return false;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    _fixNextInteractiveTransition = false;
    
    if (animated && iosMajorVersion() >= 5)
    {
        static ptrdiff_t controllerOffset = -1;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            controllerOffset = freedomIvarOffset([UINavigationController class], 0xb281e8fU);
        });

        if (controllerOffset != -1)
        {
            __unsafe_unretained NSObject **controller = (__unsafe_unretained NSObject **)(void *)(((uint8_t *)(__bridge void *)self) + controllerOffset);
            if (*controller != nil)
            {
                static Class decoratedClass = Nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^
                {
                   decoratedClass = freedomMakeClass([*controller class], [TGNavigationPercentTransition class]);
                });

                if (decoratedClass != Nil && ![*controller isKindOfClass:decoratedClass])
                    object_setClass(*controller, decoratedClass);
            }
        }
    }
    
    _isInPopTransition = true;
    UIViewController *result = [super popViewControllerAnimated:animated];
    _isInPopTransition = false;
    
    return result;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    NSArray *viewControllers = self.viewControllers;
    for (NSUInteger i = viewControllers.count; i > 1; i--)
    {
        UIViewController *viewController = viewControllers[i - 1];
        if (viewController.modalViewController != nil)
            TGDismissViewController(viewController, false, nil);
    }
    
    return [super popToRootViewControllerAnimated:animated];
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion
{
    if (iosMajorVersion() >= 5)
        [super presentViewController:viewControllerToPresent animated:flag completion:completion];
    else
        TGPresentViewController(self, viewControllerToPresent, flag, completion);
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
    if (iosMajorVersion() >= 5)
        [super dismissViewControllerAnimated:flag completion:completion];
    else
        TGDismissViewController(self, flag, completion);
}

TGNavigationController *findNavigationControllerInWindow(UIWindow *window)
{
    if ([window.rootViewController isKindOfClass:[TGNavigationController class]])
        return (TGNavigationController *)window.rootViewController;
    
    return nil;
}

TGNavigationController *findNavigationController()
{
    NSArray *windows = [[LegacyComponentsGlobals provider] applicationWindows];
    for (int i = (int)windows.count - 1; i >= 0; i--)
    {
        TGNavigationController *result = findNavigationControllerInWindow(windows[i]);
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (CGFloat)myNominalTransitionAnimationDuration
{
    return 0.2f;
}

- (void)setPreferredContentSize:(CGSize)preferredContentSize
{
    _preferredContentSize = preferredContentSize;
}

- (CGSize)preferredContentSize
{
    return _preferredContentSize;
}

- (BOOL)prefersStatusBarHidden
{
    if (iosMajorVersion() >= 7)
        return [super prefersStatusBarHidden];
    
    return false;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.topViewController.preferredStatusBarStyle;
}

@end

@implementation TGNavigationPercentTransition

- (void)updateInteractiveTransition:(CGFloat)percentComplete
{
    TGNavigationController *navigationController = findNavigationController();
    if (navigationController != nil)
    {
        if (!navigationController.disableInteractiveKeyboardTransition && [TGHacks applicationKeyboardWindow] != nil && ![TGHacks applicationKeyboardWindow].hidden)
        {
            CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:navigationController.interfaceOrientation];
            CGFloat keyboardOffset = MAX(0.0f, percentComplete * screenSize.width);
            
            UIView *keyboardView = [TGHacks applicationKeyboardView];
            CGRect keyboardViewFrame = keyboardView.frame;
            keyboardViewFrame.origin.x = keyboardOffset;
            
            keyboardView.frame = keyboardViewFrame;
        }
    }
    
    [super updateInteractiveTransition:percentComplete];
}

- (void)finishInteractiveTransition
{
    CGFloat value = self.percentComplete;
    UIView *keyboardView = [TGHacks applicationKeyboardView];
    CGRect keyboardViewFrame = keyboardView.frame;
    
    [super finishInteractiveTransition];
    
    TGNavigationController *navigationController = findNavigationController();
    if (navigationController != nil)
    {
        if (!navigationController.disableInteractiveKeyboardTransition)
        {
            keyboardView.frame = keyboardViewFrame;
            
            CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:navigationController.interfaceOrientation];
            CGFloat keyboardOffset = 1.0f * screenSize.width;
            
            keyboardViewFrame.origin.x = keyboardOffset;
            NSTimeInterval duration = (1.0 - value) * [navigationController myNominalTransitionAnimationDuration];
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^
             {
                 keyboardView.frame = keyboardViewFrame;
             } completion:nil];
        }
    }
}

- (void)cancelInteractiveTransition
{
    CGFloat value = self.percentComplete;
    
    TGNavigationController *navigationController = findNavigationController();
    if (navigationController != nil)
    {
        if (!navigationController.disableInteractiveKeyboardTransition && [TGHacks applicationKeyboardWindow] != nil && ![TGHacks applicationKeyboardWindow].hidden)
        {
            UIView *keyboardView = [TGHacks applicationKeyboardView];
            CGRect keyboardViewFrame = keyboardView.frame;
            keyboardViewFrame.origin.x = 0.0f;
            
            NSTimeInterval duration = value * [navigationController myNominalTransitionAnimationDuration];
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^
             {
                 keyboardView.frame = keyboardViewFrame;
             } completion:nil];
        }
    }
    
    [super cancelInteractiveTransition];
}

@end

@implementation TGDelegateProxy

@end


@implementation TGNavigationGestureDelegateProxy

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    bool result = [self.delegate respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && [self.delegate gestureRecognizerShouldBegin:gestureRecognizer];
    if (result && self.shouldBegin != nil)
        result = self.shouldBegin(gestureRecognizer);
    return result;
}

- (BOOL)gestureRecognizer:(UIPanGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    bool result = [self.delegate respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)] && [self.delegate gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
    if (!result && self.shouldRecognizeWith != nil)
        result = self.shouldRecognizeWith(gestureRecognizer, otherGestureRecognizer);
    return result;
}

@end
