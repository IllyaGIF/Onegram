#import "OGProgressView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"

@implementation OGProgressView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.backgroundColor = [UIColor clearColor];
    return self;
}

- (void)setProgress:(float)progress
{
    _progress = MIN(1.0f, MAX(0.0f, progress));
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGRect track = self.bounds;
    [[self.theme.palette.separatorColor colorWithAlphaComponent:0.55f] setFill];
    UIRectFill(track);
    CGRect fill = track;
    fill.size.width = floorf(track.size.width * _progress);
    [self.theme.palette.accentColor setFill];
    UIRectFill(fill);
}
@end
