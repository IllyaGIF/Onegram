#import <UIKit/UIKit.h>
@class OGTheme;

@interface OGView : UIView
@property (nonatomic, retain) OGTheme *theme;
- (void)applyTheme;
@end
