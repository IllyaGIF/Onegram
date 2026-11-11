#import "TGDialogFilterIconsCollectionItem.h"

#import "TGDialogFilter.h"
#import "TGDialogFilterIconsCollectionItemView.h"

@implementation TGDialogFilterIconsCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.highlightable = false;
        self.selectable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGDialogFilterIconsCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, [TGDialogFilterIconsCollectionItemView heightForWidth:containerSize.width count:[TGDialogFilter availableEmoticons].count + 1]);
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize safeAreaInset:(UIEdgeInsets)safeAreaInset
{
    return CGSizeMake(containerSize.width, [TGDialogFilterIconsCollectionItemView heightForWidth:containerSize.width - safeAreaInset.left - safeAreaInset.right count:[TGDialogFilter availableEmoticons].count + 1]);
}

- (void)bindView:(TGDialogFilterIconsCollectionItemView *)view
{
    [super bindView:view];

    __weak TGDialogFilterIconsCollectionItem *weakSelf = self;
    view.emoticonSelected = ^(NSString *emoticon)
    {
        __strong TGDialogFilterIconsCollectionItem *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf.selectedEmoticon = emoticon;
        if (strongSelf->_emoticonSelected)
            strongSelf->_emoticonSelected(emoticon);
    };
    [view setEmoticons:[TGDialogFilter availableEmoticons] selectedEmoticon:_selectedEmoticon];
}

- (void)unbindView
{
    ((TGDialogFilterIconsCollectionItemView *)[self boundView]).emoticonSelected = nil;
    [super unbindView];
}

- (void)setSelectedEmoticon:(NSString *)selectedEmoticon
{
    _selectedEmoticon = selectedEmoticon;
    [(TGDialogFilterIconsCollectionItemView *)[self boundView] setEmoticons:[TGDialogFilter availableEmoticons] selectedEmoticon:_selectedEmoticon];
}

@end
