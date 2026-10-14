#import "OGMediaCell.h"
@implementation OGMediaCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.showsAvatar = YES;
    return self;
}
@end
