#import "OGMediaBitrateIndicatorView.h"

#import <QuartzCore/QuartzCore.h>
#import <math.h>

#import "../OnegramPlatform/OGPlatformVersion.h"

static const NSTimeInterval OGMediaBitrateSmoothing = 0.35;
static const double OGMediaBitrateStallRatio = 0.6;
static const double OGMediaBitrateComfortRatio = 1.3;
static const CGFloat OGMediaBitrateGreenHue = 0.33f;

@interface OGMediaBitrateFrameProxy : NSObject

@property (nonatomic, weak) OGMediaBitrateIndicatorView *target;

@end

@interface OGMediaBitrateIndicatorView ()
{
    UILabel *_label;
    id _displayLink;
    NSTimer *_timer;
    OGMediaBitrateFrameProxy *_proxy;
    NSTimeInterval _lastFrameTime;
    double _displayedBitrate;
    bool _hasDisplayedBitrate;
    CGFloat _displayedHue;
}

- (void)frameTick;

@end

@implementation OGMediaBitrateFrameProxy

- (void)tick
{
    [_target frameTick];
}

@end

@implementation OGMediaBitrateIndicatorView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        self.backgroundColor = [UIColor clearColor];
        _label = [[UILabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.font = [UIFont systemFontOfSize:12.0f];
        _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_label];
        _displayedHue = -1.0f;
        _proxy = [[OGMediaBitrateFrameProxy alloc] init];
        _proxy.target = self;
    }
    return self;
}

- (void)dealloc
{
    [self stopUpdates];
}

- (void)setFont:(UIFont *)font
{
    _font = font;
    _label.font = font;
}

- (bool)hasContent
{
    return _rateProvider != nil || _mediaBitrate > 0.0;
}

- (void)setRateProvider:(double (^)(void))rateProvider
{
    _rateProvider = [rateProvider copy];
    _hasDisplayedBitrate = false;
    [self updateActivity];
}

- (void)setMediaBitrate:(double)mediaBitrate
{
    _mediaBitrate = mediaBitrate;
    [self updateActivity];
}

- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];
    [self updateActivity];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self updateActivity];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _label.frame = self.bounds;
}

- (void)updateActivity
{
    if (self.window != nil && !self.hidden && [self hasContent])
        [self startUpdates];
    else
        [self stopUpdates];
    _label.hidden = ![self hasContent];
}

- (void)startUpdates
{
    if (_displayLink != nil || _timer != nil)
        return;
    _lastFrameTime = 0.0;
    Class displayLinkClass = NSClassFromString(@"CADisplayLink");
    if (displayLinkClass != Nil)
    {
        CADisplayLink *displayLink = [displayLinkClass displayLinkWithTarget:_proxy selector:@selector(tick)];
        displayLink.frameInterval = OGPlatformMajorVersion() <= 4 ? 2 : 1;
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        _displayLink = displayLink;
    }
    else
    {
        _timer = [NSTimer timerWithTimeInterval:1.0 / 30.0 target:_proxy selector:@selector(tick) userInfo:nil repeats:true];
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
    [self frameTick];
}

- (void)stopUpdates
{
    [(CADisplayLink *)_displayLink invalidate];
    _displayLink = nil;
    [_timer invalidate];
    _timer = nil;
}

- (NSString *)formattedBitrate:(double)bitsPerSecond
{
    if (bitsPerSecond < 1000.0 * 1000.0)
        return [[NSString alloc] initWithFormat:@"%.0f kbps", bitsPerSecond / 1000.0];
    if (bitsPerSecond < 10.0 * 1000.0 * 1000.0)
        return [[NSString alloc] initWithFormat:@"%.2f Mbps", bitsPerSecond / (1000.0 * 1000.0)];
    return [[NSString alloc] initWithFormat:@"%.1f Mbps", bitsPerSecond / (1000.0 * 1000.0)];
}

- (void)frameTick
{
    NSTimeInterval now = CACurrentMediaTime();
    NSTimeInterval elapsed = _lastFrameTime > 0.0 ? now - _lastFrameTime : 0.0;
    _lastFrameTime = now;

    bool local = true;
    double target = _mediaBitrate;
    if (_rateProvider != nil)
    {
        double rate = _rateProvider();
        if (rate >= 0.0)
        {
            local = false;
            target = rate * 8.0;
        }
    }

    if (!_hasDisplayedBitrate)
    {
        _displayedBitrate = target;
        _hasDisplayedBitrate = true;
    }
    else
        _displayedBitrate += (target - _displayedBitrate) * (1.0 - exp(-elapsed / OGMediaBitrateSmoothing));

    NSString *text = [self formattedBitrate:MAX(0.0, _displayedBitrate)];
    if (![text isEqualToString:_label.text])
        _label.text = text;

    CGFloat hue = OGMediaBitrateGreenHue;
    if (!local && _mediaBitrate > 0.0)
    {
        double ratio = _displayedBitrate / _mediaBitrate;
        double position = (ratio - OGMediaBitrateStallRatio) / (OGMediaBitrateComfortRatio - OGMediaBitrateStallRatio);
        hue = (CGFloat)(MAX(0.0, MIN(1.0, position))) * OGMediaBitrateGreenHue;
    }
    else if (!local)
        hue = -1.0f;

    if (fabs(hue - _displayedHue) > 0.004f)
    {
        _displayedHue = hue;
        _label.textColor = hue < 0.0f ? [UIColor whiteColor] : [UIColor colorWithHue:hue saturation:0.8f brightness:1.0f alpha:1.0f];
    }
}

@end
