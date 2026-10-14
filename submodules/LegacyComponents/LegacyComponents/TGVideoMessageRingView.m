#import "TGVideoMessageRingView.h"

#import <QuartzCore/QuartzCore.h>

static const CGFloat TGVideoMessageRingLineWidth = 4.0f;

static bool TGVideoMessageRingSupportsStrokeEnd(void)
{
    static int value = -1;
    if (value < 0)
        value = [CAShapeLayer instancesRespondToSelector:NSSelectorFromString(@"setStrokeEnd:")] ? 1 : 0;
    return value != 0;
}

@interface TGVideoMessageRingView ()
{
    CGFloat _progress;
}

@end

@implementation TGVideoMessageRingView

+ (Class)layerClass
{
    return [CAShapeLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = false;
        
        CAShapeLayer *shapeLayer = (CAShapeLayer *)self.layer;
        shapeLayer.fillColor = [UIColor clearColor].CGColor;
        shapeLayer.lineWidth = TGVideoMessageRingLineWidth;
        shapeLayer.lineCap = kCALineCapRound;
        if (TGVideoMessageRingSupportsStrokeEnd())
            [shapeLayer setValue:[NSNumber numberWithFloat:0.0f] forKey:@"strokeEnd"];
    }
    return self;
}

- (void)setAccentColor:(UIColor *)accentColor
{
    _accentColor = accentColor;
    ((CAShapeLayer *)self.layer).strokeColor = accentColor.CGColor;
}

- (void)_updatePath
{
    CGRect bounds = self.bounds;
    CGPoint centerPoint = CGPointMake(bounds.size.width / 2.0f, bounds.size.height / 2.0f);
    CGFloat radius = MIN(bounds.size.width, bounds.size.height) / 2.0f - TGVideoMessageRingLineWidth / 2.0f;
    CGFloat sweep = TGVideoMessageRingSupportsStrokeEnd() ? 1.0f : _progress;
    
    CGMutablePathRef path = CGPathCreateMutable();
    if (sweep > FLT_EPSILON && radius > FLT_EPSILON)
        CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, radius, (CGFloat)-M_PI_2, (CGFloat)(-M_PI_2 + 2.0 * M_PI * sweep), false);
    
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    ((CAShapeLayer *)self.layer).path = path;
    [CATransaction commit];
    
    CGPathRelease(path);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self _updatePath];
}

- (void)setValue:(CGFloat)value
{
    _progress = MAX(0.0f, MIN(1.0f, value));
    if (TGVideoMessageRingSupportsStrokeEnd())
    {
        [CATransaction begin];
        [CATransaction setDisableActions:true];
        [self.layer setValue:[NSNumber numberWithFloat:(float)_progress] forKey:@"strokeEnd"];
        [CATransaction commit];
    }
    else
    {
        [self _updatePath];
    }
}

@end
