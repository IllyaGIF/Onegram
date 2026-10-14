#import "OGActionCell.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Base/OGLabel.h"

@implementation OGActionCell
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.showsAvatar = NO;
        self.showsIcon = NO;
        self.showsAccessory = NO;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return self;
}

- (void)applyTheme
{
    [super applyTheme];
    self.titleLabel.textColor = self.theme.palette.accentColor;
}
@end
