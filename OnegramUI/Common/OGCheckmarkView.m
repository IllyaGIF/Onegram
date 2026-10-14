#import "OGCheckmarkView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"

@implementation OGCheckmarkView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.drawsShadow = NO;
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
    CGContextSetStrokeColorWithColor(context, [self.theme.palette.accentColor CGColor]);
    CGContextSetLineWidth(context, 2.0f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextMoveToPoint(context, self.bounds.size.width * 0.18f, self.bounds.size.height * 0.52f);
    CGContextAddLineToPoint(context, self.bounds.size.width * 0.42f, self.bounds.size.height * 0.74f);
    CGContextAddLineToPoint(context, self.bounds.size.width * 0.84f, self.bounds.size.height * 0.24f);
    CGContextStrokePath(context);
}
@end
