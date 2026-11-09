#import "TGOnegramCardOverlay.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGOverlayControllerWindow.h"
#import "TGLegacyComponentsContext.h"
#import "TGAppDelegate.h"

static const CGFloat TGOnegramCardCornerRadius = 16.0f;
static const CGFloat TGOnegramCardMargin = 16.0f;
static const CGFloat TGOnegramCardBottomOverscroll = 40.0f;
static const CGFloat TGOnegramCardSheetInset = 6.0f;
static const CGFloat TGOnegramCardSheetTopCornerRadius = 38.0f;
static const CGFloat TGOnegramCardSheetRoundedScreenBottomCornerRadius = 37.0f;

static CGPathRef TGOnegramCardCreateSheetPath(CGRect rect, CGFloat topRadius, CGFloat bottomRadius)
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMinY(rect) + topRadius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMinX(rect) + topRadius, CGRectGetMinY(rect), topRadius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMinY(rect) + topRadius, topRadius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMaxY(rect), CGRectGetMaxX(rect) - bottomRadius, CGRectGetMaxY(rect), bottomRadius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMaxY(rect) - bottomRadius, bottomRadius);
    CGPathCloseSubpath(path);
    return path;
}

@interface TGOnegramCardView ()

@property (nonatomic, weak) TGOnegramCardOverlay *overlay;

@end

@implementation TGOnegramCardView

- (CGFloat)heightForWidth:(CGFloat)__unused width
{
    return 0.0f;
}

- (CGFloat)heightForWidth:(CGFloat)width availableHeight:(CGFloat)__unused availableHeight
{
    return [self heightForWidth:width];
}

- (void)cardWillAppear
{
}

- (void)cardDidDisappear
{
}

@end

@interface TGOnegramCardOverlayRootView : UIView

@property (nonatomic, copy) void (^layoutBlock)(void);

@end

@implementation TGOnegramCardOverlayRootView

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_layoutBlock != nil)
        _layoutBlock();
}

@end

@interface TGOnegramCardScrollView : UIScrollView

@end

@implementation TGOnegramCardScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)__unused view
{
    return true;
}

@end

@interface TGOnegramCardOverlay () <UIGestureRecognizerDelegate>
{
    UIButton *_dimView;
    UIView *_containerView;
    CAShapeLayer *_containerMaskLayer;
    TGOnegramCardScrollView *_scrollView;
    UIPanGestureRecognizer *_panRecognizer;
    bool _presented;
    bool _dismissing;
    bool _dragging;
    CGFloat _dragOffset;
}

@end

@implementation TGOnegramCardOverlay

+ (TGOnegramCardOverlay *)presentCardView:(TGOnegramCardView *)cardView placement:(TGOnegramCardPlacement)placement
{
    return [self presentCardView:cardView placement:placement parentController:nil];
}

+ (TGOnegramCardOverlay *)presentCardView:(TGOnegramCardView *)cardView placement:(TGOnegramCardPlacement)placement parentController:(UIViewController *)parentController
{
    TGViewController *parent = [parentController isKindOfClass:[TGViewController class]] ? (TGViewController *)parentController : TGAppDelegateInstance.rootController;
    TGOnegramCardOverlay *overlay = [[TGOnegramCardOverlay alloc] initWithCardView:cardView placement:placement];
    overlay->_parentController = parentController ?: TGAppDelegateInstance.rootController;
    TGOverlayControllerWindow *window = [[TGOverlayControllerWindow alloc] initWithManager:[[TGLegacyComponentsContext shared] makeOverlayWindowManager] parentController:parent contentController:overlay];
    window.hidden = false;
    return overlay;
}

- (instancetype)initWithCardView:(TGOnegramCardView *)cardView placement:(TGOnegramCardPlacement)placement
{
    self = [super init];
    if (self != nil)
    {
        _cardView = cardView;
        _cardView.overlay = self;
        _placement = placement;
        _dismissesOnDimTap = true;
    }
    return self;
}

- (void)loadView
{
    TGOnegramCardOverlayRootView *rootView = [[TGOnegramCardOverlayRootView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    rootView.backgroundColor = [UIColor clearColor];
    __weak TGOnegramCardOverlay *weakSelf = self;
    rootView.layoutBlock = ^
    {
        __strong TGOnegramCardOverlay *strongSelf = weakSelf;
        [strongSelf layoutCard];
    };
    self.view = rootView;

    _dimView = [[UIButton alloc] initWithFrame:rootView.bounds];
    _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dimView.backgroundColor = UIColorRGBA(0x000000, _placement == TGOnegramCardPlacementSheet ? 0.4f : 0.45f);
    _dimView.alpha = 0.0f;
    _dimView.exclusiveTouch = true;
    [_dimView addTarget:self action:@selector(dimPressed) forControlEvents:UIControlEventTouchUpInside];
    [rootView addSubview:_dimView];

    _containerView = [[UIView alloc] init];
    _containerView.clipsToBounds = true;
    _containerView.alpha = 0.0f;
    if (_placement == TGOnegramCardPlacementSheet)
    {
        _containerMaskLayer = [[CAShapeLayer alloc] init];
        _containerView.layer.mask = _containerMaskLayer;
    }
    else
    {
        _containerView.layer.cornerRadius = TGOnegramCardCornerRadius;
    }
    [rootView addSubview:_containerView];

    _scrollView = [[TGOnegramCardScrollView alloc] init];
    _scrollView.backgroundColor = [UIColor clearColor];
    _scrollView.showsHorizontalScrollIndicator = false;
    _scrollView.delaysContentTouches = false;
    _scrollView.scrollsToTop = false;
    _scrollView.bounces = _placement == TGOnegramCardPlacementCenter;
    _scrollView.scrollEnabled = false;
    [_containerView addSubview:_scrollView];
    [_scrollView addSubview:_cardView];

    if (_placement != TGOnegramCardPlacementCenter)
    {
        _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
        _panRecognizer.delegate = self;
        [_containerView addGestureRecognizer:_panRecognizer];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (_presented)
        return;
    _presented = true;
    [self layoutCard];
    [_cardView cardWillAppear];

    if (_placement == TGOnegramCardPlacementCenter)
    {
        _containerView.transform = CGAffineTransformMakeScale(1.12f, 1.12f);
        [UIView animateWithDuration:0.3 delay:0.0 options:(7 << 16) animations:^
        {
            _containerView.transform = CGAffineTransformIdentity;
            _containerView.alpha = 1.0f;
            _dimView.alpha = 1.0f;
        } completion:^(__unused BOOL finished)
        {
            [self flashScrollIndicatorsIfNeeded];
        }];
    }
    else
    {
        _containerView.alpha = 1.0f;
        _containerView.transform = CGAffineTransformMakeTranslation(0.0f, [self hiddenCardTranslation]);
        [UIView animateWithDuration:0.3 delay:0.0 options:(7 << 16) animations:^
        {
            _containerView.transform = CGAffineTransformIdentity;
            _dimView.alpha = 1.0f;
        } completion:^(__unused BOOL finished)
        {
            [self flashScrollIndicatorsIfNeeded];
        }];
    }
}

- (bool)sheetFloats
{
    return [self cardSafeInsets].bottom > 0.0f || TGIsPad();
}

- (CGFloat)hiddenCardTranslation
{
    if (_placement == TGOnegramCardPlacementSheet)
        return self.view.bounds.size.height - _containerView.center.y + _containerView.bounds.size.height / 2.0f;
    return _containerView.frame.size.height;
}

- (void)flashScrollIndicatorsIfNeeded
{
    if (_scrollView.scrollEnabled)
        [_scrollView flashScrollIndicators];
}

- (UIEdgeInsets)cardSafeInsets
{
    UIEdgeInsets insets = self.controllerSafeAreaInset;
    insets.top = MAX(insets.top, 20.0f);
    return insets;
}

- (CGRect)cardFrameForBounds:(CGRect)bounds contentHeight:(CGFloat *)contentHeight
{
    UIEdgeInsets insets = [self cardSafeInsets];
    if (_placement == TGOnegramCardPlacementCenter)
    {
        CGFloat width = MIN(bounds.size.width - TGOnegramCardMargin * 2.0f, TGIsPad() ? 360.0f : 320.0f);
        CGFloat maxHeight = bounds.size.height - insets.top - insets.bottom - TGOnegramCardMargin * 2.0f;
        CGFloat naturalHeight = CGCeil([_cardView heightForWidth:width availableHeight:maxHeight]);
        CGFloat height = MIN(naturalHeight, maxHeight);
        *contentHeight = naturalHeight;
        CGFloat x = CGFloor((bounds.size.width - width) / 2.0f);
        CGFloat y = insets.top + CGFloor((bounds.size.height - insets.top - insets.bottom - height) / 2.0f);
        return CGRectMake(x, y, width, height);
    }

    if (_placement == TGOnegramCardPlacementSheet)
    {
        bool floating = [self sheetFloats];
        CGFloat bottomInset = floating ? MAX(TGOnegramCardSheetInset, insets.bottom) : 0.0f;
        CGFloat width = MIN(bounds.size.width - (floating ? TGOnegramCardSheetInset * 2.0f : 0.0f), 430.0f);
        CGFloat maxHeight = bounds.size.height - insets.top - 10.0f - bottomInset;
        CGFloat naturalHeight = CGCeil([_cardView heightForWidth:width availableHeight:maxHeight]);
        CGFloat height = MIN(naturalHeight, maxHeight);
        *contentHeight = naturalHeight;
        CGFloat x = CGFloor((bounds.size.width - width) / 2.0f);
        return CGRectMake(x, bounds.size.height - bottomInset - height, width, height);
    }

    CGFloat width = TGIsPad() ? MIN(bounds.size.width - TGOnegramCardMargin * 2.0f, 480.0f) : bounds.size.width;
    CGFloat maxHeight = bounds.size.height - insets.top - TGOnegramCardMargin - insets.bottom;
    CGFloat naturalHeight = CGCeil([_cardView heightForWidth:width availableHeight:maxHeight]);
    CGFloat height = MIN(naturalHeight, maxHeight);
    *contentHeight = naturalHeight;
    CGFloat x = CGFloor((bounds.size.width - width) / 2.0f);
    return CGRectMake(x, bounds.size.height - insets.bottom - height, width, height);
}

- (void)layoutCard
{
    if (_containerView == nil || _dragging)
        return;
    CGRect bounds = self.view.bounds;
    CGFloat contentHeight = 0.0f;
    CGRect cardFrame = [self cardFrameForBounds:bounds contentHeight:&contentHeight];
    CGAffineTransform transform = _containerView.transform;
    _containerView.transform = CGAffineTransformIdentity;
    if (_placement == TGOnegramCardPlacementBottom || (_placement == TGOnegramCardPlacementSheet && ![self sheetFloats]))
    {
        CGFloat extra = bounds.size.height - CGRectGetMaxY(cardFrame) + TGOnegramCardBottomOverscroll;
        _containerView.frame = CGRectMake(cardFrame.origin.x, cardFrame.origin.y, cardFrame.size.width, cardFrame.size.height + extra);
    }
    else
    {
        _containerView.frame = cardFrame;
    }
    if (_containerMaskLayer != nil)
    {
        CGSize maskSize = _containerView.bounds.size;
        CGFloat bottomRadius = [self sheetFloats] ? TGOnegramCardSheetRoundedScreenBottomCornerRadius : 0.0f;
        CGPathRef path = TGOnegramCardCreateSheetPath(CGRectMake(0.0f, 0.0f, maskSize.width, maskSize.height), TGOnegramCardSheetTopCornerRadius, bottomRadius);
        _containerMaskLayer.frame = CGRectMake(0.0f, 0.0f, maskSize.width, maskSize.height);
        _containerMaskLayer.path = path;
        CGPathRelease(path);
    }
    _containerView.backgroundColor = _cardView.backgroundColor;
    _containerView.transform = transform;

    bool scrollable = contentHeight > cardFrame.size.height;
    _scrollView.frame = CGRectMake(0.0f, 0.0f, cardFrame.size.width, cardFrame.size.height);
    _scrollView.contentSize = CGSizeMake(cardFrame.size.width, contentHeight);
    _scrollView.scrollEnabled = scrollable;
    _scrollView.showsVerticalScrollIndicator = scrollable;
    if (!scrollable)
        _scrollView.contentOffset = CGPointZero;
    else if (_scrollView.contentOffset.y > contentHeight - cardFrame.size.height)
        _scrollView.contentOffset = CGPointMake(0.0f, contentHeight - cardFrame.size.height);
    _cardView.frame = CGRectMake(0.0f, 0.0f, cardFrame.size.width, contentHeight);
}

- (void)setNeedsCardLayoutAnimated:(bool)animated
{
    if (!animated || !_presented)
    {
        [self layoutCard];
        return;
    }
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionLayoutSubviews animations:^
    {
        [self layoutCard];
        [_cardView layoutIfNeeded];
    } completion:nil];
}

- (void)dimPressed
{
    if (_dismissesOnDimTap)
        [self dismissAnimated:true completion:nil];
}

- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion
{
    if (_dismissing)
        return;
    _dismissing = true;
    self.view.userInteractionEnabled = false;

    void (^finish)(void) = ^
    {
        [_cardView cardDidDisappear];
        [self dismiss];
        if (_onDismiss != nil)
            _onDismiss();
        if (completion != nil)
            completion();
    };

    if (!animated)
    {
        finish();
        return;
    }

    [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseIn animations:^
    {
        _dimView.alpha = 0.0f;
        if (_placement == TGOnegramCardPlacementCenter)
        {
            _containerView.alpha = 0.0f;
            _containerView.transform = CGAffineTransformMakeScale(0.92f, 0.92f);
        }
        else
        {
            _containerView.transform = CGAffineTransformMakeTranslation(0.0f, [self hiddenCardTranslation]);
        }
    } completion:^(__unused BOOL finished)
    {
        finish();
    }];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer != _panRecognizer)
        return true;
    if (_scrollView.scrollEnabled && _scrollView.contentOffset.y > 0.0f)
        return false;
    CGPoint velocity = [_panRecognizer velocityInView:self.view];
    return velocity.y > 0.0f && ABS(velocity.y) > ABS(velocity.x);
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return gestureRecognizer == _panRecognizer && otherGestureRecognizer.view == _scrollView;
}

- (void)panGesture:(UIPanGestureRecognizer *)recognizer
{
    CGFloat translation = MAX(0.0f, [recognizer translationInView:self.view].y);
    switch (recognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            _dragging = true;
            _dragOffset = 0.0f;
            break;
        case UIGestureRecognizerStateChanged:
        {
            if (_scrollView.scrollEnabled)
                _scrollView.contentOffset = CGPointZero;
            _dragOffset = translation;
            _containerView.transform = CGAffineTransformMakeTranslation(0.0f, translation);
            CGFloat height = MAX(1.0f, _containerView.frame.size.height);
            _dimView.alpha = MAX(0.0f, 1.0f - translation / height);
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _dragging = false;
            CGFloat velocity = [recognizer velocityInView:self.view].y;
            if (recognizer.state == UIGestureRecognizerStateEnded && (translation > 110.0f || velocity > 700.0f))
            {
                [self dismissAnimated:true completion:nil];
            }
            else
            {
                [UIView animateWithDuration:0.3 delay:0.0 options:(7 << 16) | UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    _containerView.transform = CGAffineTransformIdentity;
                    _dimView.alpha = 1.0f;
                } completion:nil];
            }
            break;
        }
        default:
            break;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    UIViewController *parentController = _parentController;
    if ([parentController respondsToSelector:@selector(preferredStatusBarStyle)])
        return [parentController preferredStatusBarStyle];
    return [UIApplication sharedApplication].statusBarStyle;
}

- (BOOL)prefersStatusBarHidden
{
    UIViewController *parentController = _parentController;
    if ([parentController respondsToSelector:@selector(prefersStatusBarHidden)])
        return [parentController prefersStatusBarHidden];
    return [UIApplication sharedApplication].statusBarHidden;
}

@end
