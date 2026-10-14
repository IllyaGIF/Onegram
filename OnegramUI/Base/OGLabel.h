#import <UIKit/UIKit.h>
@class OGTheme;

@interface OGLabel : UILabel
@property (nonatomic, retain) OGTheme *theme;
- (void)applyTheme;
@end
