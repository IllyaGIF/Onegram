#import "LegacyComponentsGlobals.h"
#import "TGNavigationBar.h"
#import "OGPlatformVersion.h"

#import "LegacyComponents.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"

#import "TGViewController.h"
#import "TGNavigationController.h"

#import "TGHacks.h"
#import "../../../OnegramPlatform/OGPlatformUIKit.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>


@interface TGNavigationBarLayer : CALayer

@end

@implementation TGNavigationBarLayer

@end

#pragma mark -

@interface TGFixView : UIActivityIndicatorView

@end

@implementation TGFixView

- (void)setAlpha:(CGFloat)__unused alpha
{
    [super setAlpha:0.02f];
}

@end

@implementation TGBlackNavigationBar

@end

@implementation TGWhiteNavigationBar

@end

@implementation TGTransparentNavigationBar

@end

static id<TGNavigationBarMusicPlayerProvider> _musicPlayerProvider;

static bool TGNavigationBarClassicIOS6Style(void)
{
    return (TGCurrentInterfaceStyle() != 0);
}

static bool TGNavigationBarBrandedIOS6Style(void)
{
    return TGCurrentInterfaceStyle() == 2;
}

static bool TGNavigationBarClassicDarkPalette(TGNavigationBarPallete *pallete)
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

static UIColor *TGNavigationBarColorWithBrightnessMultiplier(UIColor *color, CGFloat multiplier)
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

static void TGNavigationBarApplyTitleStyle(TGNavigationBar *navigationBar, TGNavigationBarPallete *pallete)
{
    if (navigationBar == nil || pallete == nil)
        return;

    bool classicIOS6Style = TGNavigationBarClassicIOS6Style();
    bool classicDarkStyle = classicIOS6Style && TGNavigationBarClassicDarkPalette(pallete);
    id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
    if (classicIOS6Style && TGNavigationBarBrandedIOS6Style() && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTitleFont)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTitleShadowColor)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTitleColor)])
        OGPlatformApplyNavigationBarTitleStyle(navigationBar, [provider brandedIOS6NavigationBarTitleColor], [provider brandedIOS6NavigationBarTitleShadowColor], CGSizeMake(0.0f, -1.0f), [provider brandedIOS6NavigationBarTitleFont]);
    else if (classicIOS6Style)
        OGPlatformApplyNavigationBarTitleStyle(navigationBar, [UIColor whiteColor], classicDarkStyle ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f), CGSizeMake(0.0f, -1.0f), TGBoldSystemFontOfSize(17.0f));
    else
        OGPlatformApplyNavigationBarTitleStyle(navigationBar, pallete.titleColor, [UIColor clearColor], CGSizeZero, iosMajorVersion() < 7 ? TGBoldSystemFontOfSize(17.0f) : nil);
}

static void TGNavigationBarApplyClassicFontToLabels(UIView *view, UIFont *font, UIColor *textColor, UIColor *shadowColor)
{
    if ([view isKindOfClass:[UILabel class]])
    {
        UILabel *label = (UILabel *)view;
        label.font = font;
        label.textColor = textColor;
        label.shadowColor = shadowColor;
        label.shadowOffset = CGSizeMake(0.0f, -1.0f);
    }

    for (UIView *subview in view.subviews)
        TGNavigationBarApplyClassicFontToLabels(subview, font, textColor, shadowColor);
}

static void TGNavigationBarApplyClassicEdgeButtonFontsWithStyle(UINavigationBar *navigationBar, UIView *view, UIFont *font, UIColor *textColor, UIColor *shadowColor)
{
    for (UIView *subview in view.subviews)
    {
        if ([subview isKindOfClass:[UIControl class]])
        {
            CGRect frame = [subview convertRect:subview.bounds toView:navigationBar];
            CGFloat centerX = CGRectGetMidX(frame);
            CGFloat width = navigationBar.bounds.size.width;
            if (frame.size.width < width * 0.48f && (centerX < width * 0.36f || centerX > width * 0.64f))
                TGNavigationBarApplyClassicFontToLabels(subview, font, textColor, shadowColor);
        }

        TGNavigationBarApplyClassicEdgeButtonFontsWithStyle(navigationBar, subview, font, textColor, shadowColor);
    }
}

static void TGNavigationBarApplyClassicEdgeButtonFonts(UINavigationBar *navigationBar, UIView *view, bool darkStyle)
{
    id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
    if (TGNavigationBarBrandedIOS6Style() && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonFont)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonShadowColor)] && [provider respondsToSelector:@selector(brandedIOS6NavigationBarButtonTitleColor)])
        TGNavigationBarApplyClassicEdgeButtonFontsWithStyle(navigationBar, view, [provider brandedIOS6NavigationBarButtonFont], [provider brandedIOS6NavigationBarButtonTitleColor], [provider brandedIOS6NavigationBarButtonShadowColor]);
    else
        TGNavigationBarApplyClassicEdgeButtonFontsWithStyle(navigationBar, view, [UIFont boldSystemFontOfSize:12.0f], [UIColor whiteColor], darkStyle ? UIColorRGBA(0x000000, 0.9f) : UIColorRGBA(0x1f3446, 0.9f));
}

@interface TGNavigationBar () <UIGestureRecognizerDelegate>
{
    bool _shouldAddBackgdropBackgroundInitialized;
    bool _shouldAddBackgdropBackground;
    
    UIView *_musicPlayerContainer;
    CAGradientLayer *_classicIOS6GradientLayer;
    UIImageView *_classicIOS6BackgroundImageView;
    CGSize _classicIOS6BackgroundImageSize;
    TGNavigationBarPallete *_pallete;
    
    bool _showMusicPlayerView;
    
    SPipe *_hiddenPipe;
}

@property (nonatomic, strong) UIView *backgroundContainerView;
@property (nonatomic, strong) UIView *statusBarBackgroundView;

@property (nonatomic, strong) TGBackdropView *barBackgroundView;
@property (nonatomic, strong) UIView *stripeView;

@property (nonatomic) bool hiddenState;

@property (nonatomic) bool contractBackgroundContainer;

@end

@implementation TGNavigationBar

+ (void)setMusicPlayerProvider:(id<TGNavigationBarMusicPlayerProvider>)provider {
    _musicPlayerProvider = provider;
}

+ (id<TGNavigationBarMusicPlayerProvider>)musicPlayerProvider {
    return _musicPlayerProvider;
}

+ (Class)layerClass
{
    return [TGNavigationBarLayer class];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self != nil)
    {
        [self commonInit:UIBarStyleDefault];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self commonInit:[self isKindOfClass:[TGBlackNavigationBar class]] ? UIBarStyleBlackTranslucent : UIBarStyleDefault];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame barStyle:(UIBarStyle)barStyle
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self commonInit:barStyle];
    }
    return self;
}

- (SSignal *)hiddenSignal
{
    return _hiddenPipe.signalProducer();
}

- (void)setPallete:(TGNavigationBarPallete *)pallete
{
    _pallete = pallete;
    bool classicIOS6Style = TGNavigationBarClassicIOS6Style();
    bool classicDarkStyle = classicIOS6Style && TGNavigationBarClassicDarkPalette(pallete);

    if (classicIOS6Style)
    {
        bool brandedIOS6Style = TGNavigationBarBrandedIOS6Style();
        if (brandedIOS6Style)
        {
            if (_classicIOS6BackgroundImageView == nil && _backgroundContainerView != nil)
            {
                _classicIOS6BackgroundImageView = [[UIImageView alloc] initWithFrame:_backgroundContainerView.bounds];
                _classicIOS6BackgroundImageView.userInteractionEnabled = false;
                _classicIOS6BackgroundImageView.contentMode = UIViewContentModeScaleToFill;
                [_backgroundContainerView insertSubview:_classicIOS6BackgroundImageView atIndex:0];
            }
            _classicIOS6BackgroundImageView.hidden = false;
            _classicIOS6BackgroundImageSize = CGSizeZero;
            [self updateBrandedBackgroundImage];
            if (_classicIOS6GradientLayer != nil)
                _classicIOS6GradientLayer.hidden = true;
        }
        else
        {
            if (_classicIOS6GradientLayer == nil && _backgroundContainerView != nil)
            {
                _classicIOS6GradientLayer = [CAGradientLayer layer];
                _classicIOS6GradientLayer.locations = @[@0.0f, @0.52f, @1.0f];
                [_backgroundContainerView.layer insertSublayer:_classicIOS6GradientLayer atIndex:0];
            }
            if (_classicIOS6BackgroundImageView != nil)
                _classicIOS6BackgroundImageView.hidden = true;

            _classicIOS6GradientLayer.hidden = false;
            if (classicDarkStyle)
            {
                UIColor *topColor = TGNavigationBarColorWithBrightnessMultiplier(pallete.backgroundColor, 1.30f);
                UIColor *middleColor = TGNavigationBarColorWithBrightnessMultiplier(pallete.backgroundColor, 1.00f);
                UIColor *bottomColor = TGNavigationBarColorWithBrightnessMultiplier(pallete.backgroundColor, 0.68f);
                _classicIOS6GradientLayer.colors = @[(id)topColor.CGColor, (id)middleColor.CGColor, (id)bottomColor.CGColor];
            }
            else
                _classicIOS6GradientLayer.colors = @[(id)UIColorRGB(0x91b7d5).CGColor, (id)UIColorRGB(0x6f99bc).CGColor, (id)UIColorRGB(0x4d7293).CGColor];
        }
        _barBackgroundView.hidden = true;
        id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
        bool hidesBottomStripe = brandedIOS6Style;
        UIColor *barTintColor = [UIColor whiteColor];
        if (brandedIOS6Style && [provider respondsToSelector:@selector(brandedIOS6NavigationBarHidesBottomStripe)])
            hidesBottomStripe = [provider brandedIOS6NavigationBarHidesBottomStripe];
        if (brandedIOS6Style && [provider respondsToSelector:@selector(brandedIOS6NavigationBarTintColor)])
        {
            UIColor *providedTintColor = [provider brandedIOS6NavigationBarTintColor];
            if (providedTintColor != nil)
                barTintColor = providedTintColor;
        }
        _stripeView.hidden = hidesBottomStripe;
        _stripeView.backgroundColor = classicDarkStyle ? pallete.separatorColor : UIColorRGB(0x36546d);
        self.tintColor = barTintColor;

    }
    else
    {
        if (_classicIOS6GradientLayer != nil)
            _classicIOS6GradientLayer.hidden = true;
        if (_classicIOS6BackgroundImageView != nil)
            _classicIOS6BackgroundImageView.hidden = true;

        _barBackgroundView.hidden = false;
        _barBackgroundView.backgroundColor = pallete.backgroundColor;
        _stripeView.hidden = false;
        _stripeView.backgroundColor = pallete.separatorColor;
        self.tintColor = pallete.tintColor;

    }

    TGNavigationBarApplyTitleStyle(self, pallete);
}

- (void)commonInit:(UIBarStyle)barStyle
{
    _hiddenPipe = [[SPipe alloc] init];
    
    if (iosMajorVersion() >= 7 && iosMajorVersion() < 10 && [TGViewController isWidescreen] && false)
    {
        TGFixView *activityIndicator = [[TGFixView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityIndicator.alpha = 0.02f;
        [self addSubview:activityIndicator];
        [activityIndicator startAnimating];
    }
    
    CGFloat backgroundOverflow = iosMajorVersion() >= 7 ? 20.0f : 0.0f;
    if (![self isKindOfClass:[TGTransparentNavigationBar class]])
    {
        _backgroundContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, -backgroundOverflow, self.bounds.size.width, backgroundOverflow + self.bounds.size.height)];
        _backgroundContainerView.userInteractionEnabled = false;
        [super insertSubview:_backgroundContainerView atIndex:0];
        
        _barBackgroundView = [TGBackdropView viewWithLightNavigationBarStyle];
        if ([self isKindOfClass:[TGWhiteNavigationBar class]])
            _barBackgroundView.backgroundColor = [UIColor whiteColor];
        _barBackgroundView.frame = _backgroundContainerView.bounds;
        [_backgroundContainerView addSubview:_barBackgroundView];
        
        if (barStyle == UIBarStyleDefault)
        {
            _stripeView = [[UIView alloc] init];
            _stripeView.backgroundColor = UIColorRGB(0xb2b2b2);
            [_backgroundContainerView addSubview:_stripeView];
        }
    }
    
    if (barStyle == UIBarStyleDefault)
    {
        self.tintColor = TGAccentColor();
    }
    
    if (iosMajorVersion() < 7)
    {
        _contractBackgroundContainer = true;
        _progressView = [[UIView alloc] init];
    }

    self.translucent = true;
    
    [self setBackgroundColor:[UIColor clearColor]];
}

- (void)setBackgroundColor:(UIColor *)__unused backgroundColor
{
    static UIColor *clearColor = nil;
    if (clearColor == nil)
        clearColor = [UIColor clearColor];
    [super setBackgroundColor:clearColor];
}

- (void)dealloc
{
}

- (void)layoutSubviews
{
    [self updateLayout];
    
    [super layoutSubviews];
    [self layoutMusicPlayerContainer];

    TGNavigationBarApplyTitleStyle(self, _pallete);

    if (TGNavigationBarClassicIOS6Style())
        TGNavigationBarApplyClassicEdgeButtonFonts(self, self, TGNavigationBarClassicDarkPalette(_pallete));
}

- (void)updateLayout
{
    if (_backgroundContainerView != nil)
    {
        CGFloat backgroundOverflow = iosMajorVersion() >= 7 ? 20.0f : 0.0f;
        if (iosMajorVersion() >= 11 && [self.superview respondsToSelector:@selector(safeAreaInsets)])
        {
            UIEdgeInsets (*safeAreaInsetsImp)(id, SEL) = (UIEdgeInsets (*)(id, SEL))[self.superview methodForSelector:@selector(safeAreaInsets)];
            UIEdgeInsets safeAreaInsets = safeAreaInsetsImp(self.superview, @selector(safeAreaInsets));
            if (safeAreaInsets.top > FLT_EPSILON)
                backgroundOverflow = safeAreaInsets.top;
        }
        
        _backgroundContainerView.frame = CGRectMake(0, -backgroundOverflow, self.bounds.size.width, backgroundOverflow + self.bounds.size.height);
        
        if (_barBackgroundView != nil)
            _barBackgroundView.frame = _backgroundContainerView.bounds;
        if (_classicIOS6BackgroundImageView != nil)
            [self updateBrandedBackgroundImage];

        if (_classicIOS6GradientLayer != nil)
            _classicIOS6GradientLayer.frame = _backgroundContainerView.bounds;
    }
    
    if (_stripeView != nil)
    {
        CGFloat stripeHeight = TGScreenPixel;
        _stripeView.frame = CGRectMake(0, _backgroundContainerView.bounds.size.height - stripeHeight, _backgroundContainerView.bounds.size.width, stripeHeight);
    }
}

- (void)setBackgroundVariant:(TGNavigationBarBackgroundVariant)backgroundVariant
{
    if (_backgroundVariant == backgroundVariant)
        return;
    _backgroundVariant = backgroundVariant;
    _classicIOS6BackgroundImageSize = CGSizeZero;
    [self updateBrandedBackgroundImage];
}

- (void)updateBrandedBackgroundImage
{
    if (_classicIOS6BackgroundImageView == nil || _classicIOS6BackgroundImageView.hidden)
        return;

    CGSize size = _backgroundContainerView.bounds.size;
    if (!CGSizeEqualToSize(size, _classicIOS6BackgroundImageSize))
    {
        _classicIOS6BackgroundImageSize = size;
        CGFloat barHeight = MIN(size.height, self.bounds.size.height);
        id<LegacyComponentsGlobalsProvider> provider = [LegacyComponentsGlobals provider];
        _classicIOS6BackgroundImageView.image = [provider respondsToSelector:@selector(brandedIOS6NavigationBarBackgroundImageForSize:overflow:variant:)] ? [provider brandedIOS6NavigationBarBackgroundImageForSize:CGSizeMake(size.width, barHeight) overflow:size.height - barHeight variant:_backgroundVariant] : nil;
    }

    UIImage *image = _classicIOS6BackgroundImageView.image;
    _classicIOS6BackgroundImageView.frame = CGRectMake(0.0f, 0.0f, size.width, image != nil ? image.size.height : size.height);
}

- (void)setBarStyle:(UIBarStyle)barStyle
{
    [self setBarStyle:barStyle animated:false];
}

- (void)setBarStyle:(UIBarStyle)__unused barStyle animated:(bool)__unused animated
{
    if (iosMajorVersion() < 7)
    {
        if (self.barStyle != UIBarStyleBlackTranslucent || barStyle != UIBarStyleBlackTranslucent)
            barStyle = UIBarStyleBlackTranslucent;
    }
    
    [super setBarStyle:barStyle];
}

- (void)setBarStyle:(UIBarStyle)barStyle animated:(bool)animated duration:(NSTimeInterval)duration
{
    UIBarStyle previousBarStyle = self.barStyle;
    
    if (previousBarStyle != barStyle)
        [self updateBarStyle:barStyle previousBarStyle:previousBarStyle animated:animated duration:duration];
    
    [super setBarStyle:barStyle];
}

- (void)resetBarStyle
{
}

- (void)setCenter:(CGPoint)center
{    
    bool shouldFix = (iosMajorVersion() >= 7);
    if (shouldFix)
    {
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            static Class fixClassName = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                fixClassName = NSClassFromString(@"TGTabletMainView");
            });
            if (fixClassName != nil) {
                shouldFix = [[[[self superview] superview] superview] isKindOfClass:[fixClassName class]];
            }
        }
        else if (iosMajorVersion() >= 11)
        {
            shouldFix = false;
        }
    }
    
    if (shouldFix && center.y <= self.frame.size.height / 2)
        center.y = center.y + 20.0f;
    
    center.y += self.verticalOffset;
    
    [super setCenter:center];
    
    if (_statusBarBackgroundView != nil && _statusBarBackgroundView.superview != nil)
    {
        _statusBarBackgroundView.frame = CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20);
    }
    
    _musicPlayerContainer.alpha = _musicPlayerHostView != nil || center.y >= 0.0f ? 1.0f : 0.0f;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (_statusBarBackgroundView != nil && _statusBarBackgroundView.superview != nil)
    {
        _statusBarBackgroundView.frame = CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20);
    }
    
    _musicPlayerContainer.alpha = _musicPlayerHostView != nil || frame.origin.y >= 0.0f ? 1.0f : 0.0f;
    [self layoutMusicPlayerContainer];
    
    [self updateLayout];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    
    [self layoutMusicPlayerContainer];
}

- (void)setHiddenState:(bool)hidden animated:(bool)animated
{
    _hiddenPipe.sink(@(hidden));
    
    if (animated)
    {
        if (_hiddenState != hidden)
        {
            if (iosMajorVersion() < 7)
            {
                _hiddenState = hidden;
                
                if (_statusBarBackgroundView == nil)
                {
                    _statusBarBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20)];
                    _statusBarBackgroundView.backgroundColor = [UIColor blackColor];
                }
                else
                    _statusBarBackgroundView.frame = CGRectMake(0, -self.frame.origin.y, self.frame.size.width, 20);
                
                [self addSubview:_statusBarBackgroundView];
                
                [UIView animateWithDuration:0.3 animations:^
                 {
                     _progressView.alpha = hidden ? 0.0f : 1.0f;
                 } completion:^(BOOL finished)
                 {
                     if (finished)
                         [_statusBarBackgroundView removeFromSuperview];
                 }];
            }
        }
        else
        {
            _progressView.alpha = hidden ? 0.0f : 1.0f;
        }
    }
    else
    {
        _hiddenState = hidden;
        
        _progressView.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (bool)isBackgroundView:(UIView *)view {
    NSString *viewClass = NSStringFromClass([view class]);
    if ([viewClass isEqualToString:@"_UINavigationBarBackground"] || [viewClass isEqualToString:@"_UIBarBackground"]) {
        return true;
    }
    return false;
}

- (UIView *)findBackground:(UIView *)view
{
    if (view == nil)
        return nil;
    
    if ([self isBackgroundView:view]) {
        return view;
    }
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = [self findBackground:subview];
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];
    
    if (!hidden)
    {
        UIView *backgroundView = [self findBackground:self];
        backgroundView.hidden = true;
        [backgroundView removeFromSuperview];
    }
}

- (void)addSubview:(UIView *)view {
    if ([self isBackgroundView:view]) {
        view.hidden = true;
        return;
    }
    [super addSubview:view];
}

- (void)insertSubview:(UIView *)view atIndex:(NSInteger)index
{
    if ([self isBackgroundView:view]) {
        view.hidden = true;
        return;
    }
    if (view != self.additionalView)
        [super insertSubview:view atIndex:MIN((int)self.subviews.count, MAX(index, 2))];
    else
        [super insertSubview:view atIndex:index];
}

- (bool)shouldAddBackdropBackground
{
    if (!_shouldAddBackgdropBackgroundInitialized)
    {
        _shouldAddBackgdropBackground = false;
        _shouldAddBackgdropBackgroundInitialized = true;
    }
    
    return _shouldAddBackgdropBackground;
}

- (unsigned int)indexAboveBackdropBackground
{
    if ([self shouldAddBackdropBackground])
    {
        static unsigned int (*nativeImpl)(id, SEL) = NULL;
        static SEL nativeSelector = NULL;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            freedomImpl(self, 0xc6dda86U, &nativeSelector);
            if (nativeSelector != NULL)
                nativeImpl = (unsigned int (*)(id, SEL))freedomNativeImpl(object_getClass(self), nativeSelector);
        });
        
        if (nativeImpl != NULL)
            return nativeImpl(self, nativeSelector);
    }

    return 1;
}

- (void)updateBarStyle:(UIBarStyle)__unused barStyle previousBarStyle:(UIBarStyle)__unused previousBarStyle animated:(bool)__unused animated duration:(NSTimeInterval)__unused duration
{
}

#pragma mark -

- (void)tapGestureRecognized:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        CGPoint point = [recognizer locationInView:self];
        
        if (point.x >= 100 && point.x < self.frame.size.width - 100)
        {
            __strong UINavigationController *navigationController = _navigationController;
            UIViewController *viewController = navigationController.topViewController;
            if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)] && [viewController respondsToSelector:@selector(navigationBarAction)])
            {
                [(id<TGViewControllerNavigationBarAppearance>)viewController navigationBarAction];
            }
        }
    }
}

- (void)swipeGestureRecognized:(UISwipeGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        __strong UINavigationController *navigationController = _navigationController;
        UIViewController *viewController = navigationController.topViewController;
        if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)] && [viewController respondsToSelector:@selector(navigationBarSwipeDownAction)])
        {
            [(id<TGViewControllerNavigationBarAppearance>)viewController navigationBarSwipeDownAction];
        }
    }
}

- (CGFloat)musicPlayerHeight
{
    if ([_musicPlayerView respondsToSelector:@selector(preferredHeight)])
        return [_musicPlayerView preferredHeight];
    if ([_musicPlayerProvider respondsToSelector:@selector(musicPlayerHeight)])
        return [_musicPlayerProvider musicPlayerHeight];
    return 37.0f;
}

- (void)setMusicPlayerHostView:(UIView *)musicPlayerHostView
{
    if (_musicPlayerHostView != musicPlayerHostView)
    {
        _musicPlayerHostView = musicPlayerHostView;
        if (_musicPlayerContainer != nil)
            [(musicPlayerHostView ?: self) addSubview:_musicPlayerContainer];
    }
    [self layoutMusicPlayerContainer];
}

- (void)setMusicPlayerCompactHeaderActivated:(void (^)(void))musicPlayerCompactHeaderActivated
{
    _musicPlayerCompactHeaderActivated = [musicPlayerCompactHeaderActivated copy];
    if ([_musicPlayerView respondsToSelector:@selector(setCompactHeaderActivated:)])
        [_musicPlayerView setCompactHeaderActivated:_musicPlayerCompactHeaderActivated];
}

- (void)setMusicPlayerLayout:(TGNavigationBarMusicPlayerLayout)musicPlayerLayout
{
    if (_musicPlayerLayout != musicPlayerLayout)
    {
        _musicPlayerLayout = musicPlayerLayout;
        if ([_musicPlayerView respondsToSelector:@selector(setPlayerLayout:)])
            [_musicPlayerView setPlayerLayout:musicPlayerLayout];
    }
}

- (void)layoutMusicPlayerContainer
{
    CGFloat width = _musicPlayerHostView != nil ? _musicPlayerHostView.bounds.size.width : self.bounds.size.width;
    CGFloat top = _musicPlayerHostView != nil ? 0.0f : self.bounds.size.height + self.musicPlayerOffset;
    CGFloat height = _musicPlayerHostView != nil && _musicPlayerLayout == TGNavigationBarMusicPlayerLayoutCompactConversation ? MAX(2.0f, _musicPlayerHostView.bounds.size.height) : self.musicPlayerHeight;
    _musicPlayerContainer.frame = CGRectMake(0.0f, top, width, height);
    _musicPlayerContainer.alpha = _musicPlayerHostView != nil || self.frame.origin.y >= 0.0f ? 1.0f : 0.0f;
    _musicPlayerView.frame = _showMusicPlayerView ? [self musicPlayerFrameForContainerSize:_musicPlayerContainer.bounds.size] : CGRectOffset(_musicPlayerContainer.bounds, 0.0f, -_musicPlayerContainer.bounds.size.height);
}

- (CGRect)musicPlayerFrameForContainerSize:(CGSize)containerSize
{
    return CGRectMake(0.0f, _minimizedMusicPlayer ? -(containerSize.height - 2.0f) : 0.0f, containerSize.width, containerSize.height);
}

- (void)showMusicPlayerView:(bool)show animation:(void (^)())animation
{
    _showMusicPlayerView = show;
    if (show)
    {
        if (_musicPlayerContainer == nil)
        {
            _musicPlayerContainer = [[UIView alloc] init];
            _musicPlayerContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            _musicPlayerContainer.clipsToBounds = true;
            [self layoutMusicPlayerContainer];
            
            _musicPlayerView = [_musicPlayerProvider makeMusicPlayerView:_navigationController];
            if ([_musicPlayerView respondsToSelector:@selector(setPlayerLayout:)])
                [_musicPlayerView setPlayerLayout:_musicPlayerLayout];
            if ([_musicPlayerView respondsToSelector:@selector(setCompactHeaderActivated:)])
                [_musicPlayerView setCompactHeaderActivated:_musicPlayerCompactHeaderActivated];
            if (_musicPlayerView != nil) {
                _musicPlayerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                _musicPlayerView.frame = CGRectOffset(_musicPlayerContainer.bounds, 0.0f, -_musicPlayerContainer.frame.size.height);
                [_musicPlayerContainer addSubview:_musicPlayerView];
                [(self.musicPlayerHostView ?: self) addSubview:_musicPlayerContainer];
            }
        }
        _musicPlayerContainer.userInteractionEnabled = true;
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
        {
            _musicPlayerView.frame = [self musicPlayerFrameForContainerSize:_musicPlayerContainer.bounds.size];
            
            if (animation)
                animation();
        } completion:nil];
    }
    else if (_musicPlayerView != nil)
    {
        _musicPlayerContainer.userInteractionEnabled = false;
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
        {
            _musicPlayerView.frame = CGRectOffset(_musicPlayerContainer.bounds, 0.0f, -_musicPlayerContainer.frame.size.height);
            if (animation)
                animation();
        } completion:nil];
    }
}

- (void)setMusicPlayerOffset:(CGFloat)musicPlayerOffset
{
    _musicPlayerOffset = musicPlayerOffset;
    [self layoutMusicPlayerContainer];
}

- (void)setMinimizedMusicPlayer:(bool)minimizedMusicPlayer
{
    if (_minimizedMusicPlayer != minimizedMusicPlayer)
    {
        _minimizedMusicPlayer = minimizedMusicPlayer;
        if (_showMusicPlayerView)
        {
            [UIView animateWithDuration:0.25 delay:0.0 options:7 << 16 animations:^
            {
                _musicPlayerView.frame = [self musicPlayerFrameForContainerSize:_musicPlayerContainer.bounds.size];
            } completion:nil];
        }
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *result = _musicPlayerHostView == nil ? [_musicPlayerContainer hitTest:CGPointMake(point.x - _musicPlayerContainer.frame.origin.x, point.y - _musicPlayerContainer.frame.origin.y) withEvent:event] : nil;
    if (result != nil && self.alpha > FLT_EPSILON)
        return result;
    
    if (self.topItem.titleView != nil)
    {
        if (CGRectContainsPoint(self.bounds, point))
        {
            UIView *result = [self.topItem.titleView hitTest:[self convertPoint:point toView:self.topItem.titleView] withEvent:event];
            if (result != nil)
                return result;
        }
    }
    
    if (self.additionalView != nil)
    {
        UIView *result = [self.additionalView hitTest:CGPointMake(point.x - self.additionalView.frame.origin.x, point.y - self.additionalView.frame.origin.y) withEvent:event];
        if (result != nil)
            return result;
    }
    
    return [super hitTest:point withEvent:event];
}

- (void)setAlpha:(CGFloat)alpha {
    if (!_keepAlpha) {
        [super setAlpha:alpha];
    }
}

@end


@implementation TGNavigationBarPallete

+ (instancetype)palleteWithBackgroundColor:(UIColor *)backgroundColor separatorColor:(UIColor *)separatorColor titleColor:(UIColor *)titleColor tintColor:(UIColor *)tintColor
{
    TGNavigationBarPallete *pallete = [[TGNavigationBarPallete alloc] init];
    pallete->_backgroundColor = backgroundColor;
    pallete->_separatorColor = separatorColor;
    pallete->_titleColor = titleColor;
    pallete->_tintColor = tintColor;
    return pallete;
}

@end
