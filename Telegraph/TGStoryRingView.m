#import "TGStoryRingView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

UIImage *TGStoryRingImage(CGFloat diameter, CGFloat lineWidth, TGStoryRingState state)
{
    if (state == TGStoryRingStateNone || diameter < 1.0f)
        return nil;
    CGSize size = CGSizeMake(diameter, diameter);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect ringRect = CGRectInset(CGRectMake(0.0f, 0.0f, diameter, diameter), lineWidth / 2.0f, lineWidth / 2.0f);
    CGContextSetLineWidth(context, lineWidth);
    if (state == TGStoryRingStateRead)
    {
        CGContextSetStrokeColorWithColor(context, UIColorRGB(0xbcbcc0).CGColor);
        CGContextStrokeEllipseInRect(context, ringRect);
    }
    else
    {
        CGContextAddEllipseInRect(context, ringRect);
        CGContextReplacePathWithStrokedPath(context);
        CGContextClip(context);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {
            0.204f, 0.780f, 0.349f, 1.0f,
            0.0f, 0.478f, 1.0f, 1.0f
        };
        CGFloat locations[] = {0.0f, 1.0f};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, diameter), CGPointMake(diameter, 0.0f), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface TGStoryRingView ()
{
    UIImageView *_imageView;
    CGFloat _renderedDiameter;
    TGStoryRingState _renderedState;
}

@end

@implementation TGStoryRingView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        self.backgroundColor = [UIColor clearColor];
        _lineWidth = 2.5f;
        _imageView = [[UIImageView alloc] init];
        [self addSubview:_imageView];
        self.hidden = true;
    }
    return self;
}

- (void)setState:(TGStoryRingState)state
{
    _state = state;
    self.hidden = state == TGStoryRingStateNone;
    [self setNeedsLayout];
}

- (void)layoutAroundFrame:(CGRect)frame spacing:(CGFloat)spacing
{
    CGFloat inset = -(spacing + _lineWidth);
    self.frame = CGRectInset(frame, inset, inset);
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat diameter = MIN(self.bounds.size.width, self.bounds.size.height);
    _imageView.frame = self.bounds;
    if (fabs(diameter - _renderedDiameter) > FLT_EPSILON || _renderedState != _state)
    {
        _renderedDiameter = diameter;
        _renderedState = _state;
        _imageView.image = TGStoryRingImage(diameter, _lineWidth, _state);
    }
}

@end
