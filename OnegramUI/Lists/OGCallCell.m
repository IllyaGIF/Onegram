#import "OGCallCell.h"
@implementation OGCallCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.showsAvatar = YES;
        self.showsAccessory = YES;
    }
    return self;
}
@end
