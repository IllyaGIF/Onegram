#import "OGTabBarItem.h"
#import "../Common/OGBadgeView.h"
#import "../Core/OGTheme.h"
#import "../Core/OGMetrics.h"
#import "../Core/OGGeometry.h"

@implementation OGTabBarItem
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _badgeView = [[OGBadgeView alloc] initWithFrame:CGRectZero];
        [self addSubview:_badgeView];
    }
    return self;
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    _badgeView.theme = self.theme;
}

- (void)setBadgeCount:(NSInteger)badgeCount
{
    _badgeCount = badgeCount;
    _badgeView.count = badgeCount;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (_badgeCount <= 0)
        return;
    CGSize size = [_badgeView sizeThatFits:CGSizeMake(80.0f, self.theme.metrics.badgeHeight)];
    CGFloat x = OGPixelFloor(self.bounds.size.width * 0.5f + 7.0f);
    _badgeView.frame = CGRectMake(x, 2.0f, size.width, size.height);
}
@end
