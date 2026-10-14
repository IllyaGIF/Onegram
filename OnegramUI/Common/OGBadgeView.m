#import "OGBadgeView.h"
#import "../Base/OGLabel.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGTypography.h"
#import "../Core/OGMetrics.h"
#import "../../OnegramPlatform/OGPlatformGraphics.h"

@implementation OGBadgeView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _textLabel = [[OGLabel alloc] initWithFrame:self.bounds];
        _textLabel.textAlignment = NSTextAlignmentCenter;
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_textLabel];
        [self applyTheme];
    }
    return self;
}

- (void)setCount:(NSInteger)count
{
    _count = count;
    if (count <= 0)
        self.displayText = @"";
    else if (count > 99)
        self.displayText = @"99+";
    else
        self.displayText = [NSString stringWithFormat:@"%ld", (long)count];
}

- (void)setDisplayText:(NSString *)displayText
{
    _displayText = [displayText copy];
    _textLabel.text = _displayText;
    self.hidden = [_displayText length] == 0;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    _textLabel.theme = self.theme;
    [self applyTheme];
}

- (void)applyTheme
{
    self.backgroundColor = [UIColor clearColor];
    _textLabel.textColor = self.theme.palette.badgeTextColor;
    _textLabel.font = self.theme.typography.badgeFont;
    [self setNeedsDisplay];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGSize textSize = [_textLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, self.theme.metrics.badgeHeight)];
    CGFloat width = MAX(self.theme.metrics.badgeMinimumWidth, textSize.width + self.theme.metrics.badgeHorizontalPadding * 2.0f);
    return CGSizeMake(ceilf(width), self.theme.metrics.badgeHeight);
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect frame = self.bounds;
    frame.origin.y += self.theme.metrics.badgeTextVerticalOffset;
    _textLabel.frame = frame;
}

- (void)drawRect:(CGRect)rect
{
    if ([_displayText length] == 0)
        return;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGFloat pixel = self.theme.metrics.pixel;
    CGRect badgeRect = CGRectInset(self.bounds, pixel, pixel);
    badgeRect.size.height = MAX(0.0f, badgeRect.size.height - self.theme.metrics.badgeShadowOffset);
    CGFloat radius = badgeRect.size.height * 0.5f;

    CGRect shadowRect = badgeRect;
    shadowRect.origin.y += self.theme.metrics.badgeShadowOffset;
    OGPlatformAddRoundedRectPath(context, shadowRect, radius);
    [self.theme.palette.badgeShadowColor setFill];
    CGContextFillPath(context);

    CGContextSaveGState(context);
    OGPlatformAddRoundedRectPath(context, badgeRect, radius);
    CGContextClip(context);
    OGPlatformDrawVerticalGradient(context, badgeRect, self.theme.palette.badgeTopColor, self.theme.palette.badgeBottomColor);

    CGRect glossRect = badgeRect;
    glossRect.size.height = floorf(badgeRect.size.height * 0.52f);
    CGFloat glossTop[4] = {1.0f, 1.0f, 1.0f, 0.36f};
    CGFloat glossBottom[4] = {1.0f, 1.0f, 1.0f, 0.04f};
    CGFloat components[8] = {glossTop[0], glossTop[1], glossTop[2], glossTop[3], glossBottom[0], glossBottom[1], glossBottom[2], glossBottom[3]};
    CGFloat locations[2] = {0.0f, 1.0f};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(CGRectGetMidX(glossRect), CGRectGetMinY(glossRect)), CGPointMake(CGRectGetMidX(glossRect), CGRectGetMaxY(glossRect)), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(context);

    CGFloat border = self.theme.metrics.badgeBorderWidth;
    CGRect borderRect = CGRectInset(badgeRect, border * 0.5f, border * 0.5f);
    OGPlatformAddRoundedRectPath(context, borderRect, MAX(0.0f, radius - border * 0.5f));
    CGContextSetStrokeColorWithColor(context, [self.theme.palette.badgeBorderColor CGColor]);
    CGContextSetLineWidth(context, border);
    CGContextStrokePath(context);
}
@end
