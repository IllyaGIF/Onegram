#import "OGBubbleView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../../OnegramPlatform/OGPlatformGraphics.h"

@implementation OGBubbleView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _cornerRadius = 12.0f;
        _drawsTail = YES;
    }
    return self;
}

- (void)setAlignment:(OGMessageAlignment)alignment
{
    _alignment = alignment;
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
    UIColor *color = _alignment == OGMessageAlignmentOutgoing ? self.theme.palette.outgoingBubbleColor : self.theme.palette.incomingBubbleColor;
    CGRect bubbleRect = self.bounds;
    if (_drawsTail)
    {
        if (_alignment == OGMessageAlignmentOutgoing)
            bubbleRect.size.width = MAX(0.0f, bubbleRect.size.width - 5.0f);
        else
        {
            bubbleRect.origin.x += 5.0f;
            bubbleRect.size.width = MAX(0.0f, bubbleRect.size.width - 5.0f);
        }
    }
    OGPlatformAddRoundedRectPath(context, CGRectInset(bubbleRect, 0.5f, 0.5f), _cornerRadius);
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillPath(context);

    if (_drawsTail)
    {
        CGContextBeginPath(context);
        if (_alignment == OGMessageAlignmentOutgoing)
        {
            CGFloat x = CGRectGetMaxX(bubbleRect) - 1.0f;
            CGFloat y = CGRectGetMaxY(bubbleRect) - 10.0f;
            CGContextMoveToPoint(context, x, y);
            CGContextAddLineToPoint(context, self.bounds.size.width, self.bounds.size.height - 2.0f);
            CGContextAddLineToPoint(context, x - 2.0f, self.bounds.size.height - 3.0f);
        }
        else
        {
            CGFloat x = CGRectGetMinX(bubbleRect) + 1.0f;
            CGFloat y = CGRectGetMaxY(bubbleRect) - 10.0f;
            CGContextMoveToPoint(context, x, y);
            CGContextAddLineToPoint(context, 0.0f, self.bounds.size.height - 2.0f);
            CGContextAddLineToPoint(context, x + 2.0f, self.bounds.size.height - 3.0f);
        }
        CGContextClosePath(context);
        CGContextSetFillColorWithColor(context, [color CGColor]);
        CGContextFillPath(context);
    }
}
@end
