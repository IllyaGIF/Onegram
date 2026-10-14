#import "../Base/OGView.h"

@interface OGNavigationTitleView : OGView
@property (nonatomic, retain, readonly) UILabel *titleLabel;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) BOOL (^accessibilityActivation)(void);
@end
