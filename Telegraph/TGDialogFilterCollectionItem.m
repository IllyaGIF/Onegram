#import "TGDialogFilterCollectionItem.h"

#import "TGDialogFilterCollectionItemView.h"

@implementation TGDialogFilterCollectionItem

- (instancetype)initWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon
{
    self = [super init];
    if (self != nil)
    {
        _title = title;
        _subtitle = subtitle;
        _icon = icon;
        self.deselectAutomatically = true;
        self.highlightable = true;
        self.selectable = true;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGDialogFilterCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, _subtitle.length != 0 ? 56.0f : 46.0f);
}

- (void)bindView:(TGDialogFilterCollectionItemView *)view
{
    [super bindView:view];

    [view setTitle:_title subtitle:_subtitle icon:_icon];
    [view setShowsDisclosure:_showsDisclosure];
    [view setAddButtonTitle:_addButtonTitle];
    [view setEnableEditing:_enableEditing animated:false];
    view.deletePressed = _deletePressed;
    view.addPressed = _addPressed;
}

- (void)unbindView
{
    TGDialogFilterCollectionItemView *view = (TGDialogFilterCollectionItemView *)[self boundView];
    view.deletePressed = nil;
    view.addPressed = nil;
    [super unbindView];
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed)
        _pressed();
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    [(TGDialogFilterCollectionItemView *)[self boundView] setTitle:_title subtitle:_subtitle icon:_icon];
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = subtitle;
    [(TGDialogFilterCollectionItemView *)[self boundView] setTitle:_title subtitle:_subtitle icon:_icon];
}

- (void)setIcon:(UIImage *)icon
{
    _icon = icon;
    [(TGDialogFilterCollectionItemView *)[self boundView] setTitle:_title subtitle:_subtitle icon:_icon];
}

- (void)setEnableEditing:(bool)enableEditing
{
    _enableEditing = enableEditing;
    [(TGDialogFilterCollectionItemView *)[self boundView] setEnableEditing:enableEditing animated:true];
}

@end
