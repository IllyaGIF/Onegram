#import "TGDialogFilterIconsCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGDialogFilterIcons.h"

static const CGFloat TGDialogFilterIconCellSide = 44.0f;
static const CGFloat TGDialogFilterIconsHorizontalInset = 10.0f;
static const CGFloat TGDialogFilterIconsVerticalInset = 6.0f;

static NSUInteger TGDialogFilterIconsColumns(CGFloat width)
{
    return MAX((NSUInteger)1, (NSUInteger)floor((width - TGDialogFilterIconsHorizontalInset * 2.0f) / TGDialogFilterIconCellSide));
}

@interface TGDialogFilterIconsCollectionItemView ()
{
    NSArray *_emoticons;
    NSString *_selectedEmoticon;
    NSMutableArray *_buttons;
    UIView *_selectionView;
}

@end

@implementation TGDialogFilterIconsCollectionItemView

+ (CGFloat)heightForWidth:(CGFloat)width count:(NSUInteger)count
{
    NSUInteger columns = TGDialogFilterIconsColumns(width);
    NSUInteger rows = (count + columns - 1) / columns;
    return rows * TGDialogFilterIconCellSide + TGDialogFilterIconsVerticalInset * 2.0f;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _buttons = [[NSMutableArray alloc] init];
        _selectionView = [[UIView alloc] init];
        _selectionView.layer.cornerRadius = 10.0f;
        _selectionView.userInteractionEnabled = false;
        [self addSubview:_selectionView];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _selectionView.backgroundColor = [presentation.pallete.collectionMenuAccentColor colorWithAlphaComponent:0.16f];
    [self rebuildButtons];
}

- (void)setEmoticons:(NSArray *)emoticons selectedEmoticon:(NSString *)selectedEmoticon
{
    bool changedSet = ![_emoticons isEqualToArray:emoticons];
    _emoticons = emoticons;
    _selectedEmoticon = selectedEmoticon;
    if (changedSet || _buttons.count != emoticons.count + 1)
        [self rebuildButtons];
    [self setNeedsLayout];
}

- (void)rebuildButtons
{
    for (UIButton *button in _buttons)
        [button removeFromSuperview];
    [_buttons removeAllObjects];
    if (_emoticons == nil)
        return;

    UIColor *folderColor = self.presentation.pallete.collectionMenuVariantColor ?: [UIColor grayColor];
    NSUInteger index = 0;
    for (NSString *emoticon in [@[@""] arrayByAddingObjectsFromArray:_emoticons])
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = (NSInteger)index;
        UIImage *image = emoticon.length == 0 ? TGDialogFilterFolderIcon(folderColor, 26.0f) : TGDialogFilterEmoticonIcon(emoticon, 30.0f);
        [button setImage:image forState:UIControlStateNormal];
        button.adjustsImageWhenHighlighted = true;
        [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        [_buttons addObject:button];
        index++;
    }
    [self setNeedsLayout];
}

- (void)buttonPressed:(UIButton *)button
{
    NSInteger index = button.tag;
    NSString *emoticon = index <= 0 || index > (NSInteger)_emoticons.count ? nil : _emoticons[(NSUInteger)index - 1];
    _selectedEmoticon = emoticon;
    [self setNeedsLayout];
    if (_emoticonSelected)
        _emoticonSelected(emoticon);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat width = self.bounds.size.width - self.safeAreaInset.left - self.safeAreaInset.right;
    NSUInteger columns = TGDialogFilterIconsColumns(width);
    CGFloat spacing = columns > 1 ? (width - TGDialogFilterIconsHorizontalInset * 2.0f - columns * TGDialogFilterIconCellSide) / (columns - 1) : 0.0f;
    CGFloat originX = self.safeAreaInset.left + TGDialogFilterIconsHorizontalInset;
    NSUInteger selectedIndex = 0;
    if (_selectedEmoticon.length != 0)
    {
        NSUInteger found = [_emoticons indexOfObject:_selectedEmoticon];
        selectedIndex = found == NSNotFound ? NSNotFound : found + 1;
    }

    _selectionView.hidden = true;
    for (NSUInteger index = 0; index < _buttons.count; index++)
    {
        NSUInteger row = index / columns;
        NSUInteger column = index % columns;
        CGRect frame = CGRectMake(originX + column * (TGDialogFilterIconCellSide + spacing), TGDialogFilterIconsVerticalInset + row * TGDialogFilterIconCellSide, TGDialogFilterIconCellSide, TGDialogFilterIconCellSide);
        ((UIButton *)_buttons[index]).frame = frame;
        if (index == selectedIndex)
        {
            _selectionView.hidden = false;
            _selectionView.frame = CGRectInset(frame, 2.0f, 2.0f);
        }
    }
}

@end
