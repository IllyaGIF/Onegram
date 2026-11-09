#import "TGCloudThemeCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGEditableCollectionItemView.h"

static const CGFloat TGCloudThemeCollectionItemHeight = 44.0f;
static const CGFloat TGCloudThemeCollectionItemCheckInset = 15.0f;
static const CGFloat TGCloudThemeCollectionItemTitleInset = 44.0f;

@interface TGCloudThemeCollectionItemView : TGEditableCollectionItemView
{
    UILabel *_titleLabel;
    UIImageView *_checkView;
}

@property (nonatomic, copy) void (^removeRequested)(void);

- (void)setTitle:(NSString *)title;
- (void)setIsChecked:(bool)isChecked;

@end

@implementation TGCloudThemeCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = TGSystemFontOfSize(17.0f);
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.editingContentView addSubview:_titleLabel];

        _checkView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 14.0f, 11.0f)];
        [self.editingContentView addSubview:_checkView];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        self.separatorInset = TGCloudThemeCollectionItemTitleInset;
#endif
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _titleLabel.textColor = presentation.pallete.collectionMenuTextColor;
    _checkView.image = presentation.images.collectionMenuCheckImage;
}

- (void)setTitle:(NSString *)title
{
    _titleLabel.text = title;
    [self setNeedsLayout];
}

- (void)setIsChecked:(bool)isChecked
{
    _checkView.hidden = !isChecked;
}

- (void)deleteAction
{
    [super deleteAction];
    if (_removeRequested != nil)
        _removeRequested();
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGSize size = self.editingContentView.frame.size;
    CGFloat classicInset = [TGPresentation classicIOS6Style] ? 10.0f : 0.0f;
    CGFloat editingInset = self.enableEditing && self.showsDeleteIndicator ? 38.0f : 0.0f;
    CGFloat leftInset = TGCloudThemeCollectionItemTitleInset + classicInset + editingInset + self.safeAreaInset.left;
    _titleLabel.frame = CGRectMake(leftInset, CGFloor((size.height - 26.0f) / 2.0f), MAX(0.0f, size.width - leftInset - 16.0f - classicInset - self.safeAreaInset.right), 26.0f);
    CGSize checkSize = _checkView.frame.size;
    _checkView.frame = CGRectMake(TGCloudThemeCollectionItemCheckInset + classicInset + editingInset + self.safeAreaInset.left, CGFloor((size.height - checkSize.height) / 2.0f), checkSize.width, checkSize.height);
}

@end

@implementation TGCloudThemeCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.deselectAutomatically = true;
        self.selectable = true;
        self.highlightable = true;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGCloudThemeCollectionItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGCloudThemeCollectionItemHeight);
}

- (void)itemSelected:(id)__unused actionTarget
{
    if (_pressed != nil)
        _pressed();
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    [(TGCloudThemeCollectionItemView *)[self boundView] setTitle:title];
}

- (void)setIsChecked:(bool)isChecked
{
    _isChecked = isChecked;
    [(TGCloudThemeCollectionItemView *)[self boundView] setIsChecked:isChecked];
}

- (void)bindView:(TGCollectionItemView *)view
{
    [super bindView:view];
    TGCloudThemeCollectionItemView *itemView = (TGCloudThemeCollectionItemView *)view;
    [itemView setTitle:_title];
    [itemView setIsChecked:_isChecked];
    itemView.enableEditing = _removeRequested != nil;
    __weak TGCloudThemeCollectionItem *weakSelf = self;
    itemView.removeRequested = ^
    {
        __strong TGCloudThemeCollectionItem *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_removeRequested != nil)
            strongSelf->_removeRequested();
    };
}

- (void)unbindView
{
    ((TGCloudThemeCollectionItemView *)[self boundView]).removeRequested = nil;
    [super unbindView];
}

@end
