#import <UIKit/UIKit.h>
@class OGTheme;

@interface OGImageView : UIImageView
@property (nonatomic, retain) OGTheme *theme;
@property (nonatomic, copy) NSString *assetName;
- (void)reloadAsset;
- (void)applyTheme;
@end
