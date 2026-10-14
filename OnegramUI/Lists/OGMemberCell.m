#import "OGMemberCell.h"
@implementation OGMemberCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        self.showsAvatar = YES;
    return self;
}
@end
