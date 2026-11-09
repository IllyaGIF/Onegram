#import "TGOnegramCorePowerButton.h"

#import <QuartzCore/QuartzCore.h>

#import "../OnegramPlatform/OGPlatformUIKit.h"

static NSString *const TGOnegramCorePowerSpinKey = @"spin";
static NSString *const TGOnegramCorePowerPulseKey = @"pulse";

@interface TGOnegramCorePowerButton ()
{
    CAShapeLayer *_haloLayer;
    CAShapeLayer *_discLayer;
    CAShapeLayer *_trackLayer;
    CAShapeLayer *_arcLayer;
    CAShapeLayer *_glyphLayer;
    CGSize _layoutSize;
}

@end

@implementation TGOnegramCorePowerButton

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.isAccessibilityElement = true;
        self.accessibilityTraits = UIAccessibilityTraitButton;

        _haloLayer = [CAShapeLayer layer];
        _discLayer = [CAShapeLayer layer];
        _trackLayer = [CAShapeLayer layer];
        _trackLayer.fillColor = [UIColor clearColor].CGColor;
        _arcLayer = [CAShapeLayer layer];
        _arcLayer.fillColor = [UIColor clearColor].CGColor;
        _arcLayer.lineCap = kCALineCapRound;
        _glyphLayer = [CAShapeLayer layer];
        _glyphLayer.fillColor = [UIColor clearColor].CGColor;
        _glyphLayer.lineCap = kCALineCapRound;
        for (CAShapeLayer *layer in @[_haloLayer, _discLayer, _trackLayer, _arcLayer, _glyphLayer])
        {
            OGPlatformSetLayerContentsScale(layer, [UIScreen mainScreen].scale);
            [self.layer addSublayer:layer];
        }
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    CGFloat radius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0f;
    CGFloat dx = point.x - CGRectGetMidX(self.bounds);
    CGFloat dy = point.y - CGRectGetMidY(self.bounds);
    return dx * dx + dy * dy <= radius * radius;
}

- (CGPathRef)newCirclePathWithCenter:(CGPoint)center radius:(CGFloat)radius
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddEllipseInRect(path, NULL, CGRectMake(center.x - radius, center.y - radius, radius * 2.0f, radius * 2.0f));
    return path;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGSize size = self.bounds.size;
    if (CGSizeEqualToSize(size, _layoutSize))
        return;
    _layoutSize = size;

    CGFloat side = MIN(size.width, size.height);
    CGPoint center = CGPointMake(size.width / 2.0f, size.height / 2.0f);
    CGFloat discRadius = side * 0.40f;
    CGFloat lineWidth = MAX(3.0f, side * 0.022f);

    [CATransaction begin];
    [CATransaction setDisableActions:true];
    for (CALayer *layer in @[_haloLayer, _discLayer, _trackLayer, _arcLayer, _glyphLayer])
        layer.frame = self.bounds;

    CGPathRef haloPath = [self newCirclePathWithCenter:center radius:side * 0.5f];
    _haloLayer.path = haloPath;
    CGPathRelease(haloPath);

    CGPathRef discPath = [self newCirclePathWithCenter:center radius:discRadius];
    _discLayer.path = discPath;
    CGPathRelease(discPath);

    CGPathRef trackPath = [self newCirclePathWithCenter:center radius:discRadius + lineWidth * 2.2f];
    _trackLayer.path = trackPath;
    _trackLayer.lineWidth = lineWidth;
    CGPathRelease(trackPath);

    CGMutablePathRef arcPath = CGPathCreateMutable();
    CGPathAddArc(arcPath, NULL, side / 2.0f, side / 2.0f, discRadius + lineWidth * 2.2f, (CGFloat)-M_PI_2, (CGFloat)(-M_PI_2 + M_PI * 0.56), false);
    _arcLayer.bounds = CGRectMake(0.0f, 0.0f, side, side);
    _arcLayer.position = center;
    _arcLayer.path = arcPath;
    _arcLayer.lineWidth = lineWidth;
    CGPathRelease(arcPath);

    CGFloat glyphRadius = discRadius * 0.42f;
    CGFloat gap = (CGFloat)(M_PI / 5.0);
    CGMutablePathRef glyphPath = CGPathCreateMutable();
    CGPathAddArc(glyphPath, NULL, center.x, center.y, glyphRadius, (CGFloat)-M_PI_2 + gap, (CGFloat)(M_PI * 1.5) - gap, false);
    CGPathMoveToPoint(glyphPath, NULL, center.x, center.y - glyphRadius * 1.18f);
    CGPathAddLineToPoint(glyphPath, NULL, center.x, center.y - glyphRadius * 0.18f);
    _glyphLayer.path = glyphPath;
    _glyphLayer.lineWidth = MAX(4.0f, discRadius * 0.1f);
    CGPathRelease(glyphPath);
    [CATransaction commit];

    [self applyColorsAnimated:false];
    [self resumeAnimations];
}

- (void)setPowerState:(TGOnegramCorePowerState)powerState animated:(bool)animated
{
    if (_powerState == powerState && _layoutSize.width > 0.0f)
    {
        [self applyColorsAnimated:false];
        return;
    }
    _powerState = powerState;
    [self applyColorsAnimated:animated];
    [self resumeAnimations];
}

- (void)applyColorsAnimated:(bool)animated
{
    UIColor *disc = _surfaceColor;
    UIColor *track = _trackColor;
    UIColor *glyph = _secondaryColor;
    UIColor *halo = [UIColor clearColor];
    bool arcVisible = false;
    switch (_powerState)
    {
        case TGOnegramCorePowerStateConnecting:
            track = [_accentColor colorWithAlphaComponent:0.22f];
            glyph = _accentColor;
            arcVisible = true;
            break;
        case TGOnegramCorePowerStateConnected:
            disc = _accentColor;
            track = [_accentColor colorWithAlphaComponent:0.35f];
            glyph = _contrastColor;
            halo = [_accentColor colorWithAlphaComponent:0.14f];
            break;
        case TGOnegramCorePowerStateFailed:
            track = _destructiveColor;
            glyph = _destructiveColor;
            break;
        default:
            break;
    }

    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    [CATransaction setAnimationDuration:0.3];
    _discLayer.fillColor = disc.CGColor;
    _trackLayer.strokeColor = track.CGColor;
    _glyphLayer.strokeColor = glyph.CGColor;
    _haloLayer.fillColor = halo.CGColor;
    _arcLayer.strokeColor = _accentColor.CGColor;
    _arcLayer.opacity = arcVisible ? 1.0f : 0.0f;
    [CATransaction commit];

    switch (_powerState)
    {
        case TGOnegramCorePowerStateConnected:
            self.accessibilityValue = @"on";
            break;
        case TGOnegramCorePowerStateConnecting:
            self.accessibilityValue = @"connecting";
            break;
        default:
            self.accessibilityValue = @"off";
            break;
    }
}

- (void)resumeAnimations
{
    if (_powerState == TGOnegramCorePowerStateConnecting)
    {
        if ([_arcLayer animationForKey:TGOnegramCorePowerSpinKey] == nil)
        {
            CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
            spin.fromValue = @0.0;
            spin.toValue = @(M_PI * 2.0);
            spin.duration = 1.1;
            spin.repeatCount = HUGE_VALF;
            spin.removedOnCompletion = false;
            [_arcLayer addAnimation:spin forKey:TGOnegramCorePowerSpinKey];
        }
    }
    else
    {
        [_arcLayer removeAnimationForKey:TGOnegramCorePowerSpinKey];
    }

    if (_powerState == TGOnegramCorePowerStateConnected)
    {
        if ([_haloLayer animationForKey:TGOnegramCorePowerPulseKey] == nil)
        {
            CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
            pulse.fromValue = @1.0;
            pulse.toValue = @0.35;
            pulse.duration = 1.6;
            pulse.autoreverses = true;
            pulse.repeatCount = HUGE_VALF;
            pulse.removedOnCompletion = false;
            pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [_haloLayer addAnimation:pulse forKey:TGOnegramCorePowerPulseKey];
        }
    }
    else
    {
        [_haloLayer removeAnimationForKey:TGOnegramCorePowerPulseKey];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:highlighted ? 0.12 : 0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^
    {
        self.transform = highlighted ? CGAffineTransformMakeScale(0.93f, 0.93f) : CGAffineTransformIdentity;
    } completion:nil];
}

@end
