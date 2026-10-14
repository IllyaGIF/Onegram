#import "OGGroupedCard.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../../OnegramPlatform/OGPlatformGraphics.h"

@implementation OGGroupedCard
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _cornerRadius = 9.0f;
    }
    return self;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = MAX(0.0f, cornerRadius);
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.backgroundColor = [UIColor clearColor];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    OGPlatformAddRoundedRectPath(context, CGRectInset(self.bounds, 0.5f, 0.5f), _cornerRadius);
    CGContextSetFillColorWithColor(context, [self.theme.palette.cardColor CGColor]);
    CGContextFillPath(context);
}
@end
