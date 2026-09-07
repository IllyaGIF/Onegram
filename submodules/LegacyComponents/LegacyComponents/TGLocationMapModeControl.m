#import "TGLocationMapModeControl.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "TGColor.h"

@interface TGLocationMapModeControl ()
{
    NSArray *_titles;
    UISegmentedControl *_nativeControl;
    UIImageView *_backgroundView;
    NSMutableArray *_buttons;
    NSMutableArray *_dividerViews;
    NSMutableDictionary *_titleColors;
    NSMutableDictionary *_titleShadowColors;
    NSMutableDictionary *_titleFonts;
    UIImage *_dividerImage;
}

@end

@implementation TGLocationMapModeControl

- (instancetype)init
{
    self = [super initWithFrame:CGRectMake(0.0f, 0.0f, 240.0f, 29.0f)];
    if (self != nil)
    {
        _titles = @[TGLocalized(@"Map.Map"), TGLocalized(@"Map.Satellite"), TGLocalized(@"Map.Hybrid")];
        _titleColors = [[NSMutableDictionary alloc] init];
        _titleShadowColors = [[NSMutableDictionary alloc] init];
        _titleFonts = [[NSMutableDictionary alloc] init];
        _selectedSegmentIndex = UISegmentedControlNoSegment;

        if (iosMajorVersion() >= 5)
        {
            _nativeControl = [[UISegmentedControl alloc] initWithItems:_titles];
            _nativeControl.frame = self.bounds;
            _nativeControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_nativeControl addTarget:self action:@selector(nativeValueChanged:) forControlEvents:UIControlEventValueChanged];
            [self addSubview:_nativeControl];
        }
        else
        {
            _buttons = [[NSMutableArray alloc] init];
            _dividerViews = [[NSMutableArray alloc] init];

            _backgroundView = [[UIImageView alloc] initWithFrame:self.bounds];
            _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _backgroundView.userInteractionEnabled = false;
            [self addSubview:_backgroundView];

            for (NSUInteger i = 0; i < _titles.count; i++)
            {
                UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.tag = (NSInteger)i;
                button.clipsToBounds = true;
                button.adjustsImageWhenHighlighted = false;
                [button setTitle:[_titles objectAtIndex:i] forState:UIControlStateNormal];
                [button addTarget:self action:@selector(segmentPressed:) forControlEvents:UIControlEventTouchUpInside];
                [_buttons addObject:button];
                [self addSubview:button];

                if (i + 1 < _titles.count)
                {
                    UIImageView *dividerView = [[UIImageView alloc] init];
                    dividerView.userInteractionEnabled = false;
                    [_dividerViews addObject:dividerView];
                    [self addSubview:dividerView];
                }
            }
        }

        [self setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlBackground.png") forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlSelected.png") forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlSelected.png") forState:UIControlStateSelected | UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:TGComponentsImageNamed(@"ModernSegmentedControlHighlighted.png") forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [self setDividerImage:TGComponentsImageNamed(@"ModernSegmentedControlDivider.png") forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [self setTitleColor:TGAccentColor() forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [self setTitleShadowColor:[UIColor clearColor] forState:UIControlStateNormal];
        [self setTitleShadowColor:[UIColor clearColor] forState:UIControlStateSelected];
        [self setTitleFont:TGSystemFontOfSize(13) forState:UIControlStateNormal];
        [self setTitleFont:TGSystemFontOfSize(13) forState:UIControlStateSelected];
    }
    return self;
}

- (UIImage *)stretchableImage:(UIImage *)image
{
    if (image == nil)
        return nil;

    NSInteger leftCap = MAX(0, (NSInteger)CGFloor(image.size.width / 2.0f));
    NSInteger topCap = MAX(0, (NSInteger)CGFloor(image.size.height / 2.0f));
    return [image stretchableImageWithLeftCapWidth:leftCap topCapHeight:topCap];
}

- (void)updateNativeTitleAttributesForState:(UIControlState)state
{
    if (_nativeControl == nil)
        return;

    NSNumber *key = [NSNumber numberWithUnsignedInteger:state];
    NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
    UIColor *color = [_titleColors objectForKey:key];
    UIColor *shadowColor = [_titleShadowColors objectForKey:key];
    UIFont *font = [_titleFonts objectForKey:key];
    if (color != nil)
        [attributes setObject:color forKey:UITextAttributeTextColor];
    if (shadowColor != nil)
        [attributes setObject:shadowColor forKey:UITextAttributeTextShadowColor];
    if (font != nil)
        [attributes setObject:font forKey:UITextAttributeFont];
    [_nativeControl setTitleTextAttributes:attributes forState:state];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage forState:(UIControlState)state barMetrics:(UIBarMetrics)barMetrics
{
    if (_nativeControl != nil)
    {
        [_nativeControl setBackgroundImage:backgroundImage forState:state barMetrics:barMetrics];
        return;
    }

    UIImage *image = [self stretchableImage:backgroundImage];
    if (state == UIControlStateNormal)
    {
        _backgroundView.image = image;
        return;
    }

    for (UIButton *button in _buttons)
        [button setBackgroundImage:image forState:state];
}

- (void)setDividerImage:(UIImage *)dividerImage forLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState barMetrics:(UIBarMetrics)barMetrics
{
    if (_nativeControl != nil)
    {
        [_nativeControl setDividerImage:dividerImage forLeftSegmentState:leftState rightSegmentState:rightState barMetrics:barMetrics];
        return;
    }

    _dividerImage = dividerImage;
    for (UIImageView *dividerView in _dividerViews)
        dividerView.image = dividerImage;
    [self setNeedsLayout];
}

- (void)setTitleColor:(UIColor *)color forState:(UIControlState)state
{
    NSNumber *key = [NSNumber numberWithUnsignedInteger:state];
    if (color != nil)
        [_titleColors setObject:color forKey:key];
    else
        [_titleColors removeObjectForKey:key];

    if (_nativeControl != nil)
        [self updateNativeTitleAttributesForState:state];
    else
    {
        for (UIButton *button in _buttons)
            [button setTitleColor:color forState:state];
    }
}

- (void)setTitleShadowColor:(UIColor *)color forState:(UIControlState)state
{
    NSNumber *key = [NSNumber numberWithUnsignedInteger:state];
    if (color != nil)
        [_titleShadowColors setObject:color forKey:key];
    else
        [_titleShadowColors removeObjectForKey:key];

    if (_nativeControl != nil)
        [self updateNativeTitleAttributesForState:state];
    else
    {
        for (UIButton *button in _buttons)
            [button setTitleShadowColor:color forState:state];
    }
}

- (void)setTitleFont:(UIFont *)font forState:(UIControlState)state
{
    NSNumber *key = [NSNumber numberWithUnsignedInteger:state];
    if (font != nil)
        [_titleFonts setObject:font forKey:key];
    else
        [_titleFonts removeObjectForKey:key];

    if (_nativeControl != nil)
        [self updateNativeTitleAttributesForState:state];
    else
    {
        for (UIButton *button in _buttons)
        {
            if (state == UIControlStateNormal || button.selected)
                button.titleLabel.font = font;
        }
    }
}

- (void)setSelectedSegmentIndex:(NSInteger)selectedSegmentIndex
{
    if (selectedSegmentIndex < 0 || selectedSegmentIndex >= (NSInteger)_titles.count)
        selectedSegmentIndex = UISegmentedControlNoSegment;

    if (_selectedSegmentIndex == selectedSegmentIndex)
        return;

    _selectedSegmentIndex = selectedSegmentIndex;
    if (_nativeControl != nil)
    {
        _nativeControl.selectedSegmentIndex = selectedSegmentIndex;
        return;
    }

    for (NSUInteger i = 0; i < _buttons.count; i++)
    {
        UIButton *button = [_buttons objectAtIndex:i];
        button.selected = (NSInteger)i == _selectedSegmentIndex;
        UIControlState state = button.selected ? UIControlStateSelected : UIControlStateNormal;
        UIFont *font = [_titleFonts objectForKey:[NSNumber numberWithUnsignedInteger:state]];
        if (font == nil)
            font = [_titleFonts objectForKey:[NSNumber numberWithUnsignedInteger:UIControlStateNormal]];
        if (font != nil)
            button.titleLabel.font = font;
    }
    [self setNeedsLayout];
}

- (void)nativeValueChanged:(UISegmentedControl *)control
{
    _selectedSegmentIndex = control.selectedSegmentIndex;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)segmentPressed:(UIButton *)button
{
    NSInteger index = button.tag;
    if (index == _selectedSegmentIndex)
        return;

    self.selectedSegmentIndex = index;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if (_nativeControl != nil)
    {
        _nativeControl.frame = self.bounds;
        return;
    }

    NSUInteger count = _buttons.count;
    if (count == 0)
        return;

    CGFloat scale = [UIScreen mainScreen].scale;
    if (scale <= 0.0f)
        scale = 1.0f;
    CGFloat dividerWidth = _dividerImage == nil ? 1.0f / scale : MAX(1.0f / scale, _dividerImage.size.width);
    CGFloat segmentWidth = self.bounds.size.width / (CGFloat)count;
    CGFloat x = 0.0f;

    for (NSUInteger i = 0; i < count; i++)
    {
        CGFloat nextX = i + 1 == count ? self.bounds.size.width : CGRound((CGFloat)(i + 1) * segmentWidth * scale) / scale;
        UIButton *button = [_buttons objectAtIndex:i];
        button.frame = CGRectMake(x, 0.0f, MAX(0.0f, nextX - x), self.bounds.size.height);
        x = nextX;

        if (i < _dividerViews.count)
        {
            UIImageView *dividerView = [_dividerViews objectAtIndex:i];
            dividerView.frame = CGRectMake(nextX - dividerWidth / 2.0f, 0.0f, dividerWidth, self.bounds.size.height);
            UIButton *nextButton = [_buttons objectAtIndex:i + 1];
            dividerView.hidden = button.selected || nextButton.selected;
            [self bringSubviewToFront:dividerView];
        }
    }
}

@end
