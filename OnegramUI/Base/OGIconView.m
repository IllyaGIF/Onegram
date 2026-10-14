#import "OGIconView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGAssets.h"
#import "../Core/OGPalette.h"
#import "../Core/OGMetrics.h"

static CGRect OGIconImageRect(CGRect bounds, CGSize imageSize, UIViewContentMode contentMode)
{
    if (imageSize.width <= 0.0f || imageSize.height <= 0.0f)
        return CGRectZero;
    if (contentMode == UIViewContentModeScaleAspectFit || contentMode == UIViewContentModeScaleAspectFill)
    {
        CGFloat sx = bounds.size.width / imageSize.width;
        CGFloat sy = bounds.size.height / imageSize.height;
        CGFloat scale = contentMode == UIViewContentModeScaleAspectFit ? MIN(sx, sy) : MAX(sx, sy);
        CGSize size = CGSizeMake(imageSize.width * scale, imageSize.height * scale);
        return CGRectMake(CGRectGetMidX(bounds) - size.width * 0.5f, CGRectGetMidY(bounds) - size.height * 0.5f, size.width, size.height);
    }
    if (contentMode == UIViewContentModeCenter)
        return CGRectMake(CGRectGetMidX(bounds) - imageSize.width * 0.5f, CGRectGetMidY(bounds) - imageSize.height * 0.5f, imageSize.width, imageSize.height);
    return bounds;
}

@implementation OGIconView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeScaleAspectFit;
        _drawsShadow = YES;
    }
    return self;
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    [self setNeedsDisplay];
}

- (void)setAssetName:(NSString *)assetName
{
    _assetName = [assetName copy];
    [self reloadAsset];
}

- (void)reloadAsset
{
    self.image = [self.theme.assets imageNamed:_assetName];
}

- (void)applyTheme
{
    self.backgroundColor = [UIColor clearColor];
    [self reloadAsset];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (_image == nil)
        return;
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGRect imageRect = OGIconImageRect(self.bounds, _image.size, self.contentMode);
    if (_drawsShadow)
    {
        UIColor *shadowColor = [self.theme.palette.shadowColor colorWithAlphaComponent:self.theme.metrics.iconShadowOpacity];
        CGContextSetShadowWithColor(context, self.theme.metrics.iconShadowOffset, self.theme.metrics.iconShadowRadius, [shadowColor CGColor]);
    }
    [_image drawInRect:imageRect];
    CGContextRestoreGState(context);
}
@end
