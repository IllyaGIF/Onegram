#import "OGDisclosureView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGMetrics.h"

@implementation OGDisclosureView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.drawsShadow = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    if (self.image != nil)
    {
        [super drawRect:rect];
        return;
    }
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGFloat pixel = self.theme.metrics.pixel;
    CGContextSetStrokeColorWithColor(context, [self.theme.palette.accessoryColor CGColor]);
    CGContextSetLineWidth(context, MAX(pixel, 1.5f));
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGFloat x = floorf(self.bounds.size.width * 0.38f);
    CGFloat y = floorf(self.bounds.size.height * 0.24f);
    CGFloat bottom = ceilf(self.bounds.size.height * 0.76f);
    CGFloat right = ceilf(self.bounds.size.width * 0.68f);
    CGContextMoveToPoint(context, x, y);
    CGContextAddLineToPoint(context, right, CGRectGetMidY(self.bounds));
    CGContextAddLineToPoint(context, x, bottom);
    CGContextStrokePath(context);
}
@end
