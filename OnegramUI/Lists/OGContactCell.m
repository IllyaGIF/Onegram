#import "OGContactCell.h"
@implementation OGContactCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.showsAvatar = YES;
    return self;
}
@end
