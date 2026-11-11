#import "TGDialogFilterCategoryCollectionItem.h"

#import "TGDialogFilter.h"
#import "TGDialogFilterIcons.h"
#import "TGDialogFilterCategoryCollectionItemView.h"

@implementation TGDialogFilterCategoryCollectionItem

- (instancetype)initWithCategory:(int32_t)category
{
    self = [super init];
    if (self != nil)
    {
        _category = category;
        self.deselectAutomatically = true;
        self.highlightable = true;
        self.selectable = true;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGDialogFilterCategoryCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, 48.0f);
}

- (void)bindView:(TGDialogFilterCategoryCollectionItemView *)view
{
    [super bindView:view];

    [view setTitle:[TGDialogFilter titleForCategory:(TGDialogFilterCategory)_category] icon:TGDialogFilterCategoryIcon(_category)];
    [view setDisplayCheck:_displayCheck checkIsOn:_checkIsOn];
    [view setEnableEditing:_canDelete animated:false];
    view.deletePressed = _deletePressed;
}

- (void)unbindView
{
    ((TGDialogFilterCategoryCollectionItemView *)[self boundView]).deletePressed = nil;
    [super unbindView];
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed)
        _pressed();
}

- (void)setCheckIsOn:(bool)checkIsOn
{
    _checkIsOn = checkIsOn;
    [(TGDialogFilterCategoryCollectionItemView *)[self boundView] setDisplayCheck:_displayCheck checkIsOn:_checkIsOn];
}

@end
