#import "OGTabBar.h"
#import "OGTabBarItem.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGGeometry.h"

@implementation OGTabBar
- (void)setItems:(NSArray *)items
{
    for (UIView *view in _items)
        [view removeFromSuperview];
    _items = [items copy];
    for (id item in _items)
    {
        if ([item isKindOfClass:[OGTabBarItem class]])
        {
            OGTabBarItem *tab = item;
            tab.theme = self.theme;
            [self addSubview:tab];
        }
    }
    [self setNeedsLayout];
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    for (OGTabBarItem *item in _items)
        item.theme = self.theme;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    _selectedIndex = selectedIndex;
    NSInteger index = 0;
    for (OGTabBarItem *item in _items)
    {
        item.selected = index == selectedIndex;
        index++;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    NSUInteger count = [_items count];
    if (count == 0)
        return;
    CGFloat width = self.bounds.size.width / (CGFloat)count;
    NSUInteger index = 0;
    for (OGTabBarItem *item in _items)
    {
        CGFloat x = OGPixelFloor(width * index);
        CGFloat next = index + 1 == count ? self.bounds.size.width : OGPixelFloor(width * (index + 1));
        item.frame = CGRectMake(x, 0.0f, MAX(0.0f, next - x), self.bounds.size.height);
        index++;
    }
}
@end
