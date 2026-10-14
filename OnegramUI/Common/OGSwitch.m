#import "OGSwitch.h"
#import "../Core/OGTheme.h"

@implementation OGSwitch
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
        _theme = [OGTheme currentTheme];
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    _theme = theme == nil ? [OGTheme currentTheme] : theme;
}
@end
