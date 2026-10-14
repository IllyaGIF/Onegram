#import "OGActivityView.h"
#import "../Core/OGTheme.h"

@implementation OGActivityView
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
