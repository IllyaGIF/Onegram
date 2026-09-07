#import "TGVolumeBarView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import <MediaPlayer/MediaPlayer.h>

#import "TGTelegraph.h"
#import "TGInterfaceManager.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGTimerTarget.h"

#import "TGEmbedPIPController.h"

#import "TGLegacyComponentsContext.h"

#import "TGPresentation.h"
#import "TGPresentationAssets.h"

@interface TGVolumeIndicatorView : UIView

@property (nonatomic, strong) TGPresentation *presentation;
@property (nonatomic, assign) CGFloat value;

@end

@interface TGVolumeBarView ()
{
    id _notificationObserver;
    
    UIView *_wrapperView;
    UIImageView *_iconView;
    TGVolumeIndicatorView *_progressView;
    UIWindow *_volumeWindow;
    
    NSTimer *_timer;
    
    CGFloat _initialStatusBarAlpha;
}
@end

@implementation TGVolumeBarView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = false;
        
        if (false && [TGViewController hasTallScreen])
        {
            _iconView = [[UIImageView alloc] init];
            [_wrapperView addSubview:_iconView];
        }
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectOffset(self.bounds, 0.0f, _iconView == nil ? -self.bounds.size.height : 0.0f)];
        _wrapperView.alpha = _iconView != nil ? 0.0f : 1.0f;
        _wrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _wrapperView.backgroundColor = UIColorRGB(0xf7f7f7);
        [self addSubview:_wrapperView];
        
        _progressView = [[TGVolumeIndicatorView alloc] initWithFrame:CGRectMake(5.0f, self.frame.size.height - 2.0f - 7.0f, frame.size.width - 10.0f, 2.0f)];
        _progressView.value = 0.4f;
        [_wrapperView addSubview:_progressView];
        
        [self subscribe];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    
    _wrapperView.backgroundColor = _iconView == nil ? presentation.pallete.barBackgroundColor : [UIColor clearColor];
    _progressView.presentation = presentation;
}

- (void)setVolume:(CGFloat)volume
{
    [self _setVolume:volume];
    [self show];
}

- (void)subscribe
{
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIView *rootView = keyWindow.rootViewController.view;
    
    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(10000, 10000, 20, 20)];
    [rootView addSubview:volumeView];
    
    __weak TGVolumeBarView *weakSelf = self;
    _notificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil queue:nil usingBlock:^(NSNotification *notification)
    {
        __strong TGVolumeBarView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        NSNumber *volume = notification.userInfo[@"AVSystemController_AudioVolumeNotificationParameter"];
        NSString *reason = notification.userInfo[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"];
        if (volume != nil && [reason isEqualToString:@"ExplicitVolumeChange"])
        {
            [[TGTelegraphInstance.musicPlayer.playingStatus take:1] startWithNext:^(TGMusicPlayerStatus *next)
            {
                if (![TGInterfaceManager instance].hasCallControllerInForeground && (next != nil || [TGEmbedPIPController hasPlayerViews] || [strongSelf hasVolumeOverlayInhibitor]))
                {
                    [strongSelf setVolume:(CGFloat)volume.doubleValue];
                }
            }];
        }
    }];

    [volumeView removeFromSuperview];
}

- (bool)hasVolumeOverlayInhibitor
{
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIView *rootView = keyWindow.rootViewController.view;
    
    for (UIView *view in rootView.subviews)
    {
        if ([view isKindOfClass:[MPVolumeView class]])
            return true;
    }
    
    __block bool found = false;
    [[UIApplication sharedApplication].windows enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UIWindow *window, __unused NSUInteger index, BOOL *stop)
    {
        if ([window isKindOfClass:[TGOverlayControllerWindow class]])
        {
            UIView *rootView = window.rootViewController.view;
            for (UIView *view in rootView.subviews)
            {
                if ([view isKindOfClass:[MPVolumeView class]])
                {
                    found = true;
                    break;
                }
            }
            
            *stop = true;
        }
    }];
    
    return found;
}

- (void)show
{
    [self invalidateTimer];
    
    _timer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(hide) interval:1.0 repeat:false];
    
    if (_volumeWindow == nil)
        [self _setupWindow];
    
    [UIView animateWithDuration:0.25 animations:^
    {
        if (_iconView == nil)
            _wrapperView.frame = self.bounds;
        else
            _wrapperView.alpha = 1.0f;
        [[TGLegacyComponentsContext shared] setApplicationStatusBarAlpha:0.0f];
    }];
}

- (void)hide
{
    [UIView animateWithDuration:0.25 animations:^
     {
         if (_iconView == nil)
             _wrapperView.frame = CGRectOffset(self.bounds, 0.0f, -self.bounds.size.height);
         else
             _wrapperView.alpha = 0.0f;
         
         if ([[TGLegacyComponentsContext shared] applicationStatusBarAlpha] < FLT_EPSILON)
             [[TGLegacyComponentsContext shared] setApplicationStatusBarAlpha:_initialStatusBarAlpha];
     } completion:^(BOOL finished)
     {
         if (finished && _wrapperView.layer.animationKeys.count == 0)
             [self _destroyWindow];
     }];
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_iconView == nil)
    {
        _progressView.frame = CGRectMake(5.0f + _safeAreaInset.left, self.frame.size.height - 2.0f - 7.0f, self.frame.size.width - 10.0f - _safeAreaInset.left - _safeAreaInset.right, _progressView.frame.size.height);
    }
    else
    {
        _progressView.frame = CGRectMake(38.0f, 22.0f, 38.0f, _progressView.frame.size.height);
    }
}

- (void)_setupWindow
{
    _initialStatusBarAlpha = [[TGLegacyComponentsContext shared] applicationStatusBarAlpha];
    
    _volumeWindow = [[UIWindow alloc] init];
    _volumeWindow.backgroundColor = [UIColor clearColor];
    _volumeWindow.userInteractionEnabled = false;
    _volumeWindow.frame = [UIApplication sharedApplication].keyWindow.frame;
    _volumeWindow.windowLevel = UIWindowLevelStatusBar + 0.00001;
    _volumeWindow.rootViewController = [[TGOverlayWindowViewController alloc] init];
    _volumeWindow.hidden = false;
    [_volumeWindow addSubview:self];
    
    self.frame = CGRectMake(0.0f, 0.0f, _volumeWindow.frame.size.width, self.frame.size.height);
}

- (void)_destroyWindow
{
    [self removeFromSuperview];
    _volumeWindow = nil;
}

- (void)invalidateTimer
{
    if (_timer == nil)
        return;
    
    [_timer invalidate];
    _timer = nil;
}

- (void)_setVolume:(CGFloat)volume
{
    _progressView.value = volume;
}

@end


@implementation TGVolumeIndicatorView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = false;
        _value = 0.0f;
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    if (_presentation == presentation)
        return;

    _presentation = presentation;
    [self setNeedsDisplay];
}

- (void)setValue:(CGFloat)value
{
    value = MAX(0.0f, MIN(1.0f, value));
    if (ABS(_value - value) < FLT_EPSILON)
        return;

    _value = value;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;

    UIColor *backgroundColor = _presentation == nil ? UIColorRGB(0xededed) : _presentation.pallete.volumeIndicatorBackgroundColor;
    UIColor *foregroundColor = _presentation == nil ? [UIColor blackColor] : _presentation.pallete.volumeIndicatorForegroundColor;

    CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
    CGContextFillRect(context, self.bounds);

    CGRect foregroundRect = self.bounds;
    foregroundRect.size.width = foregroundRect.size.width * _value;
    if (foregroundRect.size.width > 0.0f)
    {
        CGContextSetFillColorWithColor(context, foregroundColor.CGColor);
        CGContextFillRect(context, foregroundRect);
    }
}

@end
