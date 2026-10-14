#import <UIKit/UIKit.h>
@class OGTheme;
@interface OGComposerTextView : UITextView
@property (nonatomic, retain) OGTheme *theme;
- (void)applyTheme;
@end
