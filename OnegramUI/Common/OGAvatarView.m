#import "OGAvatarView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"

static CGRect OGAvatarImageRect(CGRect bounds, CGSize imageSize)
{
    if (imageSize.width <= 0.0f || imageSize.height <= 0.0f)
        return CGRectZero;
    CGFloat scale = MAX(bounds.size.width / imageSize.width, bounds.size.height / imageSize.height);
    CGSize size = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
    return CGRectMake(CGRectGetMidX(bounds) - size.width * 0.5f, CGRectGetMidY(bounds) - size.height * 0.5f, size.width, size.height);
}

@implementation OGAvatarView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        _circular = YES;
    }
    return self;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    [self setNeedsDisplay];
}

- (void)setCircular:(BOOL)circular
{
    _circular = circular;
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
    CGContextSaveGState(context);
    if (_circular)
    {
        CGContextAddEllipseInRect(context, self.bounds);
        CGContextClip(context);
    }
    [self.theme.palette.accentColor setFill];
    UIRectFill(self.bounds);
    if (_image != nil)
        [_image drawInRect:OGAvatarImageRect(self.bounds, _image.size)];
    CGContextRestoreGState(context);
}
@end
