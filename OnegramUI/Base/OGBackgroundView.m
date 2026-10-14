#import "OGBackgroundView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGAssets.h"

@implementation OGBackgroundView
- (void)setAssetName:(NSString *)assetName
{
    _assetName = [assetName copy];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    UIImage *image = [self.theme.assets imageNamed:_assetName];
    if (image != nil)
        [image drawInRect:self.bounds];
    else
        [super drawRect:rect];
}
@end
