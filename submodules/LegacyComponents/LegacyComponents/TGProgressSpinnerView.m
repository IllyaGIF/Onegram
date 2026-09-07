#import "TGProgressSpinnerView.h"

#import "LegacyComponentsInternal.h"
#import <QuartzCore/QuartzCore.h>

@interface TGProgressSpinnerViewInternal : UIView

@property (nonatomic, copy) void (^onDraw)(void);
@property (nonatomic, copy) void (^onSuccess)(void);

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light;

- (void)setProgress;
- (void)setSucceed:(bool)fromRotation progress:(CGFloat)progress;

@end

@interface TGProgressSpinnerView ()
{
    UIImageView *_arcView;
    TGProgressSpinnerViewInternal *_internalView;
    
    bool _progressing;
}
@end

@implementation TGProgressSpinnerView

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = false;
        self.userInteractionEnabled = false;
        
        //static dispatch_once_t onceToken;
        UIImage *arcImage = nil;
        //dispatch_once(&onceToken, ^{
            CGRect rect = CGRectMake(0.0f, 0.0f, 48.0f, 48.0f);
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGPoint centerPoint = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
            CGFloat lineWidth = 4.0f;
            CGFloat inset = 3.0f;
            
            UIColor *foregroundColor = light ? UIColorRGB(0x5a5a5a) : [UIColor whiteColor];
            CGContextSetFillColorWithColor(context, foregroundColor.CGColor);
            CGContextSetStrokeColorWithColor(context, foregroundColor.CGColor);
            
            CGMutablePathRef path = CGPathCreateMutable();
            CGFloat offset = -2.0f * M_PI;
            CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, (rect.size.width - inset * 2.0f - lineWidth) / 2.0f, offset, offset + (3.0f * M_PI_2), false);
            CGContextAddPath(context, path);
            CGPathRelease(path);
            CGContextSetLineWidth(context, lineWidth);
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineJoin(context, kCGLineJoinMiter);
            CGContextSetMiterLimit(context, 10.0f);
            CGContextReplacePathWithStrokedPath(context);
            CGContextFillPath(context);
            
            arcImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        //});
        
        _arcView = [[UIImageView alloc] initWithFrame:self.bounds];
        _arcView.image = arcImage;
        _arcView.hidden = true;
        [self addSubview:_arcView];
        
        _internalView = [[TGProgressSpinnerViewInternal alloc] initWithFrame:self.bounds light:light];
        _internalView.hidden = true;
        [self addSubview:_internalView];
    }
    return self;
}

- (void)setProgress {
    _arcView.hidden = false;
    _progressing = true;
    
    CABasicAnimation *rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = @(-M_PI * 2.0f);
    rotationAnimation.duration = 0.75;
    rotationAnimation.cumulative = true;
    rotationAnimation.repeatCount = HUGE_VALF;
    
    [_arcView.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
}

- (void)setSucceed {
    _internalView.hidden = false;
    
    if (_progressing)
    {
        CGFloat value = [[_arcView.layer.presentationLayer valueForKeyPath:@"transform.rotation.z"] doubleValue] / (-2 * M_PI);
        [_internalView setSucceed:_progressing progress:value];
        
        __weak TGProgressSpinnerView *weakSelf = self;
        _internalView.onDraw = ^{
            __strong TGProgressSpinnerView *strongSelf = weakSelf;
            if (strongSelf != nil)
                strongSelf->_arcView.hidden = true;
        };
        _internalView.onSuccess = ^{
            __strong TGProgressSpinnerView *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.onSuccess != nil)
                strongSelf.onSuccess();
        };
    }
    else
    {
        [_internalView setSucceed:false progress:0.0f];
    }
}

@end

@interface TGProgressSpinnerViewInternal ()
{
    CADisplayLink *_displayLink;
    
    bool _light;
    
    bool _isProgressing;
    CGFloat _rotationValue;
    bool _isRotating;
    
    CGFloat _checkValue;
    bool _delay;
    bool _isSucceed;
    bool _isChecking;
    
    NSTimeInterval _previousTime;
}
@end

@implementation TGProgressSpinnerViewInternal

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _light = light;
        
        self.backgroundColor = [UIColor clearColor];
        self.opaque = false;
        self.userInteractionEnabled = false;
    }
    return self;
}

- (void)dealloc {
    _displayLink.paused = true;
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (CADisplayLink *)displayLink {
    if (_displayLink == nil) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate)];
        _displayLink.paused = true;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _displayLink;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGPoint centerPoint = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
    CGFloat lineWidth = 4.0f;
    CGFloat inset = 3.0f;
    
    UIColor *foregroundColor = _light ? UIColorRGB(0x5a5a5a) : [UIColor whiteColor];
    CGContextSetFillColorWithColor(context, foregroundColor.CGColor);
    CGContextSetStrokeColorWithColor(context, foregroundColor.CGColor);
    
    if (_isProgressing)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        CGFloat offset = -_rotationValue * 2.0f * M_PI;
        CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, (rect.size.width - inset * 2.0f - lineWidth) / 2.0f, offset, offset + (3.0f * M_PI_2) * (1.0f - _checkValue), false);
        CGContextAddPath(context, path);
        CGPathRelease(path);
        CGContextSetLineWidth(context, lineWidth);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinMiter);
        CGContextSetMiterLimit(context, 10.0f);
        CGContextReplacePathWithStrokedPath(context);
        CGContextFillPath(context);
    }
    
    if (_checkValue > FLT_EPSILON)
    {
        CGContextSetLineWidth(context, 5.0f);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSetMiterLimit(context, 10);
        
        CGFloat firstSegment = MIN(1.0f, _checkValue * 3.0f);
        CGPoint s = CGPointMake(inset + 5.0f / 2.0f, centerPoint.y);
        CGPoint p1 = CGPointMake(13.0f, 13.0f);
        CGPoint p2 = CGPointMake(27.0f, -27.0f);
        
        if (firstSegment < 1.0f)
        {
            CGContextMoveToPoint(context, s.x + p1.x * firstSegment, s.y + p1.y * firstSegment);
            CGContextAddLineToPoint(context, s.x, s.y);
        }
        else
        {
            CGFloat secondSegment = (_checkValue - 0.33f) * 1.5f;
            CGContextMoveToPoint(context, s.x + p1.x + p2.x * secondSegment, s.y + p1.y + p2.y * secondSegment);
            CGContextAddLineToPoint(context, s.x + p1.x, s.y + p1.y);
            CGContextAddLineToPoint(context, s.x, s.y);
        }
        
        CGContextStrokePath(context);
    }
}

- (void)displayLinkUpdate
{
    NSTimeInterval previousTime = _previousTime;
    NSTimeInterval currentTime = CACurrentMediaTime();
    _previousTime = currentTime;
    
    NSTimeInterval delta = previousTime > DBL_EPSILON ? currentTime - previousTime : 0.0;
    if (delta < DBL_EPSILON)
        return;
    
    if (_isRotating)
    {
        _rotationValue += delta * 1.35f;
    }
    
    if (_isSucceed && _isRotating && !_delay && _rotationValue >= 0.5f)
    {
        _rotationValue = 0.5f;
        _isRotating = false;
        _isChecking = true;
    }
    
    if (_isChecking)
        _checkValue += delta * M_PI * 1.6f;
    
    if (_rotationValue > 1.0f)
    {
        _rotationValue = 0.0f;
        _delay = false;
    }
    
    if (_checkValue > 1.0f)
    {
        _checkValue = 1.0f;
        [self displayLink].paused = true;
        
        if (self.onSuccess != nil)
        {
            void (^onSuccess)(void) = [self.onSuccess copy];
            self.onSuccess = nil;
            onSuccess();
        }
    }
    
    [self setNeedsDisplay];
    
    if (self.onDraw != nil)
    {
        void (^onDraw)(void) = [self.onDraw copy];
        self.onDraw = nil;
        onDraw();
    }
}

- (void)setProgress {
    _isRotating = true;
    _isProgressing = true;
    
    [self displayLink].paused = false;
}

- (void)setSucceed:(bool)fromRotation progress:(CGFloat)progress {
    if (_isSucceed)
        return;
    
    if (fromRotation) {
        _isRotating = true;
        _isProgressing = true;
        _rotationValue = progress;
    }
    
    _isSucceed = true;
    
    if (!_isRotating)
        _isChecking = true;
    else if (_rotationValue > 0.5f)
        _delay = true;
    
    [self displayLink].paused = false;
}

- (bool)isSucceed
{
    return _isSucceed;
}

@end

@implementation TGActivityIndicatorView
{
    BOOL _animating;
}

- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style
{
    CGFloat side = style == UIActivityIndicatorViewStyleWhiteLarge ? 37.0f : 20.0f;
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, side, side)];
    if (self != nil)
    {
        _activityIndicatorViewStyle = style;
        _hidesWhenStopped = YES;
        _color = style == UIActivityIndicatorViewStyleGray ? [UIColor colorWithWhite:0.35f alpha:1.0f] : [UIColor whiteColor];
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        self.hidden = YES;
    }
    return self;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)activityIndicatorViewStyle
{
    _activityIndicatorViewStyle = activityIndicatorViewStyle;
    CGFloat side = activityIndicatorViewStyle == UIActivityIndicatorViewStyleWhiteLarge ? 37.0f : 20.0f;
    CGRect frame = self.frame;
    frame.size = CGSizeMake(side, side);
    self.frame = frame;
    [self setNeedsDisplay];
}

- (void)setColor:(UIColor *)color
{
    _color = color ?: (_activityIndicatorViewStyle == UIActivityIndicatorViewStyleGray ? [UIColor colorWithWhite:0.35f alpha:1.0f] : [UIColor whiteColor]);
    [self setNeedsDisplay];
}

- (BOOL)isAnimating
{
    return _animating;
}

- (CGSize)sizeThatFits:(CGSize)__unused size
{
    CGFloat side = _activityIndicatorViewStyle == UIActivityIndicatorViewStyleWhiteLarge ? 37.0f : 20.0f;
    return CGSizeMake(side, side);
}

- (void)startAnimating
{
    if (_animating)
        return;

    _animating = YES;
    self.hidden = NO;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.fromValue = @(0.0f);
    animation.toValue = @(M_PI * 2.0f);
    animation.duration = 0.8;
    animation.repeatCount = HUGE_VALF;
    animation.removedOnCompletion = NO;
    [self.layer addAnimation:animation forKey:@"TGActivityIndicatorRotation"];
}

- (void)stopAnimating
{
    if (!_animating)
    {
        if (_hidesWhenStopped)
            self.hidden = YES;
        return;
    }

    _animating = NO;
    [self.layer removeAnimationForKey:@"TGActivityIndicatorRotation"];
    if (_hidesWhenStopped)
        self.hidden = YES;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == NULL)
        return;

    CGFloat side = MIN(rect.size.width, rect.size.height);
    CGFloat scale = side / 20.0f;
    CGFloat lineWidth = MAX(1.2f, 2.0f * scale);
    CGFloat innerRadius = 4.5f * scale;
    CGFloat outerRadius = 8.0f * scale;
    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));

    CGContextSetLineWidth(context, lineWidth);
    CGContextSetLineCap(context, kCGLineCapRound);

    for (NSInteger i = 0; i < 12; i++)
    {
        CGFloat angle = (CGFloat)i * (CGFloat)(M_PI * 2.0 / 12.0) - (CGFloat)M_PI_2;
        CGFloat alpha = 0.15f + 0.85f * ((CGFloat)i / 11.0f);
        UIColor *strokeColor = [_color colorWithAlphaComponent:CGColorGetAlpha(_color.CGColor) * alpha];
        CGContextSetStrokeColorWithColor(context, strokeColor.CGColor);
        CGContextMoveToPoint(context, center.x + cosf(angle) * innerRadius, center.y + sinf(angle) * innerRadius);
        CGContextAddLineToPoint(context, center.x + cosf(angle) * outerRadius, center.y + sinf(angle) * outerRadius);
        CGContextStrokePath(context);
    }
}

@end

