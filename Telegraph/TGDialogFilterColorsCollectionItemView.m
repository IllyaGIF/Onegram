#import "TGDialogFilterColorsCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGDialogFilter.h"
#import "TGDialogFilterIcons.h"

static const CGFloat TGDialogFilterColorSide = 32.0f;

@interface TGDialogFilterTagPreviewView : UIView

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) UIColor *placeholderColor;

@end

@implementation TGDialogFilterTagPreviewView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)drawRect:(CGRect)__unused rect
{
    UIFont *font = TGBoldSystemFontOfSize(13.0f);
    NSString *title = _title.length == 0 ? TGLocalized(@"DialogFilters.NamePlaceholder") : _title;
    UIColor *color = _color ?: _placeholderColor;
    CGSize size = TGDialogFilterTagSize(title, font);
    size.width = MIN(size.width, self.bounds.size.width);
    CGRect tagRect = CGRectMake(CGFloor((self.bounds.size.width - size.width) / 2.0f), CGFloor((self.bounds.size.height - size.height) / 2.0f), size.width, size.height);
    TGDialogFilterDrawTag(title, color, font, tagRect);
}

@end

@interface TGDialogFilterColorsCollectionItemView ()
{
    TGDialogFilterTagPreviewView *_previewView;
    NSMutableArray *_buttons;
    int32_t _selectedColor;
}

@end

@implementation TGDialogFilterColorsCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _selectedColor = TGDialogFilterNoColor;
        _previewView = [[TGDialogFilterTagPreviewView alloc] init];
        [self addSubview:_previewView];
        _buttons = [[NSMutableArray alloc] init];
        for (int32_t index = -1; index < TGDialogFilterColorCount; index++)
        {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = index;
            [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:button];
            [_buttons addObject:button];
        }
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _previewView.placeholderColor = presentation.pallete.collectionMenuVariantColor;
    [_previewView setNeedsDisplay];
    [self updateButtonImages];
}

- (void)setSelectedColor:(int32_t)selectedColor previewTitle:(NSString *)previewTitle
{
    _selectedColor = selectedColor;
    _previewView.title = previewTitle;
    _previewView.color = [TGDialogFilter colorForIndex:selectedColor];
    [_previewView setNeedsDisplay];
    [self updateButtonImages];
}

- (void)updateButtonImages
{
    UIColor *strokeColor = self.presentation.pallete.collectionMenuVariantColor ?: [UIColor grayColor];
    UIColor *ringColor = self.presentation.pallete.collectionMenuCellBackgroundColor;
    for (UIButton *button in _buttons)
    {
        int32_t index = (int32_t)button.tag;
        bool selected = index == _selectedColor || (index < 0 && (_selectedColor < 0 || _selectedColor >= TGDialogFilterColorCount));
        UIImage *image = index < 0 ? TGDialogFilterNoColorImage(strokeColor, TGDialogFilterColorSide, selected, self.presentation.pallete.collectionMenuAccentColor) : TGDialogFilterColorDotImage([TGDialogFilter colorForIndex:index], TGDialogFilterColorSide, selected, ringColor);
        [button setImage:image forState:UIControlStateNormal];
    }
}

- (void)buttonPressed:(UIButton *)button
{
    int32_t color = (int32_t)button.tag;
    if (color < 0)
        color = TGDialogFilterNoColor;
    _selectedColor = color;
    _previewView.color = [TGDialogFilter colorForIndex:color];
    [_previewView setNeedsDisplay];
    [self updateButtonImages];
    if (_colorSelected)
        _colorSelected(color);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat left = self.safeAreaInset.left + 15.0f;
    CGFloat width = self.bounds.size.width - left - self.safeAreaInset.right - 15.0f;
    _previewView.frame = CGRectMake(left, 8.0f, width, 30.0f);
    NSUInteger count = _buttons.count;
    CGFloat cellWidth = MIN(44.0f, width / count);
    CGFloat totalWidth = cellWidth * count;
    CGFloat originX = left + CGFloor((width - totalWidth) / 2.0f);
    for (NSUInteger index = 0; index < count; index++)
        ((UIButton *)_buttons[index]).frame = CGRectMake(originX + index * cellWidth, 46.0f, cellWidth, 44.0f);
}

@end
