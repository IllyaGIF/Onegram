#import "TGDialogFilterColorsCollectionItem.h"

#import "TGDialogFilter.h"
#import "TGDialogFilterColorsCollectionItemView.h"

@implementation TGDialogFilterColorsCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _selectedColor = TGDialogFilterNoColor;
        self.highlightable = false;
        self.selectable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGDialogFilterColorsCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 96.0f);
}

- (void)bindView:(TGDialogFilterColorsCollectionItemView *)view
{
    [super bindView:view];

    __weak TGDialogFilterColorsCollectionItem *weakSelf = self;
    view.colorSelected = ^(int32_t color)
    {
        __strong TGDialogFilterColorsCollectionItem *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf.selectedColor = color;
        if (strongSelf->_colorSelected)
            strongSelf->_colorSelected(color);
    };
    [view setSelectedColor:_selectedColor previewTitle:_previewTitle];
}

- (void)unbindView
{
    ((TGDialogFilterColorsCollectionItemView *)[self boundView]).colorSelected = nil;
    [super unbindView];
}

- (void)setSelectedColor:(int32_t)selectedColor
{
    _selectedColor = selectedColor;
    [(TGDialogFilterColorsCollectionItemView *)[self boundView] setSelectedColor:_selectedColor previewTitle:_previewTitle];
}

- (void)setPreviewTitle:(NSString *)previewTitle
{
    _previewTitle = previewTitle;
    [(TGDialogFilterColorsCollectionItemView *)[self boundView] setSelectedColor:_selectedColor previewTitle:_previewTitle];
}

@end
