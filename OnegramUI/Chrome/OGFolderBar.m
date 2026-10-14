#import "OGFolderBar.h"
#import "../Base/OGButton.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
#import "../Core/OGGeometry.h"

@interface OGFolderBar ()
@property (nonatomic, retain) UIScrollView *scrollView;
@property (nonatomic, retain) NSMutableArray *buttons;
@end

@implementation OGFolderBar
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.showsHorizontalScrollIndicator = NO;
        _buttons = [[NSMutableArray alloc] init];
        [self addSubview:_scrollView];
    }
    return self;
}

- (void)setTitles:(NSArray *)titles
{
    for (UIView *button in _buttons)
        [button removeFromSuperview];
    [_buttons removeAllObjects];
    _titles = [titles copy];
    for (NSString *title in _titles)
    {
        OGButton *button = [[OGButton alloc] initWithFrame:CGRectZero];
        button.theme = self.theme;
        [button setTitle:title forState:UIControlStateNormal];
        [_scrollView addSubview:button];
        [_buttons addObject:button];
    }
    [self setSelectedIndex:_selectedIndex];
    [self setNeedsLayout];
}

- (void)setTheme:(OGTheme *)theme
{
    [super setTheme:theme];
    for (OGButton *button in _buttons)
        button.theme = self.theme;
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    _selectedIndex = selectedIndex;
    NSInteger index = 0;
    for (OGButton *button in _buttons)
    {
        button.selected = index == selectedIndex;
        button.alpha = button.selected ? 1.0f : 0.62f;
        index++;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _scrollView.frame = self.bounds;
    CGFloat x = 8.0f;
    NSUInteger index = 0;
    for (OGButton *button in _buttons)
    {
        NSString *title = index < [_titles count] ? [_titles objectAtIndex:index] : @"";
        CGSize text = [title sizeWithFont:button.titleLabel.font];
        CGFloat width = MAX(54.0f, ceilf(text.width) + 20.0f);
        button.frame = CGRectMake(x, 0.0f, width, self.bounds.size.height);
        x += width + 4.0f;
        index++;
    }
    _scrollView.contentSize = CGSizeMake(MAX(self.bounds.size.width, x + 4.0f), self.bounds.size.height);
}
@end
