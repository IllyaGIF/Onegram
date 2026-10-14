#import "../Base/OGView.h"
@class OGLabel;
@interface OGBadgeView : OGView
@property (nonatomic) NSInteger count;
@property (nonatomic, copy) NSString *displayText;
@property (nonatomic, retain, readonly) OGLabel *textLabel;
@end
