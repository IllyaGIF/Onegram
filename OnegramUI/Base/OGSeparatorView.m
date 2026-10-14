#import "OGSeparatorView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGMetrics.h"

@implementation OGSeparatorView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.backgroundColor = [UIColor clearColor];
    return self;
}

- (void)setInsets:(UIEdgeInsets)insets
{
    _insets = insets;
    [self setNeedsDisplay];
}

- (void)applyTheme
{
    self.backgroundColor = [UIColor clearColor];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGRect line = CGRectMake(_insets.left, MAX(0.0f, self.bounds.size.height - self.theme.metrics.separatorHeight - _insets.bottom), MAX(0.0f, self.bounds.size.width - _insets.left - _insets.right), self.theme.metrics.separatorHeight);
    [self.theme.palette.separatorColor setFill];
    UIRectFill(line);
}
@end
