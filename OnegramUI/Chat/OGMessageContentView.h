#import "../Base/OGView.h"
@interface OGMessageContentView : OGView
@property (nonatomic, retain) id item;
- (CGSize)contentSizeThatFits:(CGSize)size;
@end
