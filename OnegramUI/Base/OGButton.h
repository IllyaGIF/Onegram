#import <UIKit/UIKit.h>
@class OGTheme;

@interface OGButton : UIButton
@property (nonatomic, retain) OGTheme *theme;
@property (nonatomic, copy) NSString *normalAssetName;
@property (nonatomic, copy) NSString *highlightedAssetName;
- (void)applyTheme;
@end
