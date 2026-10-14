#import "OGView.h"

@interface OGIconView : OGView
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, copy) NSString *assetName;
@property (nonatomic) CGSize preferredSize;
@property (nonatomic) BOOL drawsShadow;
- (void)reloadAsset;
@end
