#import "TGCustomEmojiKeyboardView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGCustomEmojiSignals.h"
#import "TGStickerCollectionHeader.h"

static NSString *const TGCustomEmojiKeyboardCellIdentifier = @"TGCustomEmojiKeyboardCell";
static NSString *const TGCustomEmojiKeyboardHeaderIdentifier = @"TGCustomEmojiKeyboardHeader";
static NSString *const TGCustomEmojiKeyboardHintIdentifier = @"TGCustomEmojiKeyboardHint";
static const CGFloat TGCustomEmojiKeyboardItemSide = 40.0f;
static const CGFloat TGCustomEmojiKeyboardHeaderHeight = 32.0f;

@interface TGCustomEmojiKeyboardCell : PSUICollectionViewCell
{
    UIImageView *_imageView;
    SMetaDisposable *_disposable;
    int64_t _documentId;
}

@property (nonatomic, readonly) UIImage *image;

- (void)setItem:(TGCustomEmojiItem *)item;

@end

@implementation TGCustomEmojiKeyboardCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[UIImageView alloc] initWithFrame:CGRectInset(self.bounds, 4.0f, 4.0f)];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_imageView];
        _disposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (UIImage *)image
{
    return _imageView.image;
}

- (void)setItem:(TGCustomEmojiItem *)item
{
    if (_documentId == item.documentId && _imageView.image != nil)
        return;
    _documentId = item.documentId;
    _imageView.image = nil;
    int64_t documentId = item.documentId;
    __weak TGCustomEmojiKeyboardCell *weakSelf = self;
    [_disposable setDisposable:[[[TGCustomEmojiSignals imageSignalForItem:item] deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
    {
        __strong TGCustomEmojiKeyboardCell *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_documentId == documentId && [image isKindOfClass:[UIImage class]])
            strongSelf->_imageView.image = image;
    }]];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    _imageView.alpha = highlighted ? 0.5f : 1.0f;
}

@end

@interface TGCustomEmojiKeyboardHint : PSUICollectionReusableView
{
    UILabel *_label;
}

- (void)setText:(NSString *)text color:(UIColor *)color;
+ (CGFloat)heightForText:(NSString *)text width:(CGFloat)width;

@end

@implementation TGCustomEmojiKeyboardHint

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _label = [[UILabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = TGSystemFontOfSize(13.0f);
        _label.numberOfLines = 0;
        _label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_label];
    }
    return self;
}

+ (UIFont *)font
{
    return TGSystemFontOfSize(13.0f);
}

+ (CGFloat)heightForText:(NSString *)text width:(CGFloat)width
{
    CGSize size = [text sizeWithFont:[self font] constrainedToSize:CGSizeMake(MAX(1.0f, width - 32.0f), CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    return CGCeil(size.height) + 20.0f;
}

- (void)setText:(NSString *)text color:(UIColor *)color
{
    _label.text = text;
    _label.textColor = color;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _label.frame = CGRectMake(16.0f, 10.0f, MAX(0.0f, self.bounds.size.width - 32.0f), MAX(0.0f, self.bounds.size.height - 20.0f));
}

@end

@interface TGCustomEmojiKeyboardView () <PSUICollectionViewDataSource, PSUICollectionViewDelegateFlowLayout>
{
    PSUICollectionView *_collectionView;
    PSUICollectionViewFlowLayout *_collectionLayout;
    UILabel *_emptyLabel;
    NSArray *_recentItems;
    NSArray *_packs;
    bool _loaded;
    SMetaDisposable *_packsDisposable;
}

@end

@implementation TGCustomEmojiKeyboardView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _collectionLayout = [[PSUICollectionViewFlowLayout alloc] init];
        _collectionLayout.itemSize = CGSizeMake(TGCustomEmojiKeyboardItemSide, TGCustomEmojiKeyboardItemSide);
        _collectionLayout.minimumInteritemSpacing = 0.0f;
        _collectionLayout.minimumLineSpacing = 0.0f;
        _collectionView = [[PSUICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:_collectionLayout];
        if (iosMajorVersion() >= 11)
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.opaque = false;
        _collectionView.alwaysBounceVertical = true;
        _collectionView.showsHorizontalScrollIndicator = false;
        _collectionView.delaysContentTouches = false;
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView registerClass:[TGCustomEmojiKeyboardCell class] forCellWithReuseIdentifier:TGCustomEmojiKeyboardCellIdentifier];
        [_collectionView registerClass:[TGStickerCollectionHeader class] forSupplementaryViewOfKind:PSTCollectionElementKindSectionHeader withReuseIdentifier:TGCustomEmojiKeyboardHeaderIdentifier];
        [_collectionView registerClass:[TGCustomEmojiKeyboardHint class] forSupplementaryViewOfKind:PSTCollectionElementKindSectionHeader withReuseIdentifier:TGCustomEmojiKeyboardHintIdentifier];
        [self addSubview:_collectionView];

        _emptyLabel = [[UILabel alloc] init];
        _emptyLabel.backgroundColor = [UIColor clearColor];
        _emptyLabel.font = TGSystemFontOfSize(15.0f);
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        _emptyLabel.numberOfLines = 0;
        _emptyLabel.text = TGLocalized(@"CustomEmoji.Empty");
        _emptyLabel.hidden = true;
        [self addSubview:_emptyLabel];

        _packsDisposable = [[SMetaDisposable alloc] init];
        _recentItems = @[];
        _packs = @[];
    }
    return self;
}

- (void)dealloc
{
    [_packsDisposable dispose];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    _emptyLabel.textColor = presentation.pallete.chatInputKeyboardHeaderColor ?: UIColorRGB(0x949599);
    [_collectionView reloadData];
}

- (void)setContentInset:(UIEdgeInsets)contentInset
{
    _contentInset = contentInset;
    _collectionView.contentInset = contentInset;
    _collectionView.scrollIndicatorInsets = contentInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _collectionView.frame = self.bounds;
    CGFloat top = _contentInset.top;
    _emptyLabel.frame = CGRectMake(20.0f, top + 20.0f, MAX(0.0f, self.bounds.size.width - 40.0f), MAX(0.0f, self.bounds.size.height - top - _contentInset.bottom - 40.0f));
    [_collectionLayout invalidateLayout];
}

- (void)loadIfNeeded
{
    _recentItems = [TGCustomEmojiSignals recentItems];
    [_collectionView reloadData];
    [self updateEmpty];
    if (_loaded)
        return;
    _loaded = true;
    __weak TGCustomEmojiKeyboardView *weakSelf = self;
    [_packsDisposable setDisposable:[[[TGCustomEmojiSignals installedPacks] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *packs)
    {
        __strong TGCustomEmojiKeyboardView *strongSelf = weakSelf;
        if (strongSelf == nil || ![packs isKindOfClass:[NSArray class]])
            return;
        strongSelf->_packs = packs;
        [strongSelf->_collectionView reloadData];
        [strongSelf updateEmpty];
    } error:^(__unused id error)
    {
        __strong TGCustomEmojiKeyboardView *strongSelf = weakSelf;
        if (strongSelf != nil)
            strongSelf->_loaded = false;
    } completed:nil]];
}

- (void)updateEmpty
{
    _emptyLabel.hidden = _recentItems.count != 0 || _packs.count != 0;
}

- (bool)showsHint
{
    return ![TGCustomEmojiSignals canSendCustomEmoji];
}

- (NSInteger)hintSection
{
    return [self showsHint] ? 0 : -1;
}

- (NSInteger)recentSection
{
    if (_recentItems.count == 0)
        return -1;
    return [self showsHint] ? 1 : 0;
}

- (NSInteger)firstPackSection
{
    return ([self showsHint] ? 1 : 0) + (_recentItems.count != 0 ? 1 : 0);
}

- (NSArray *)itemsForSection:(NSInteger)section
{
    if (section == [self recentSection])
        return _recentItems;
    NSInteger packIndex = section - [self firstPackSection];
    if (packIndex >= 0 && packIndex < (NSInteger)_packs.count)
        return ((TGCustomEmojiPack *)_packs[packIndex]).items;
    return @[];
}

- (NSString *)titleForSection:(NSInteger)section
{
    if (section == [self recentSection])
        return TGLocalized(@"CustomEmoji.Recent");
    NSInteger packIndex = section - [self firstPackSection];
    if (packIndex >= 0 && packIndex < (NSInteger)_packs.count)
        return ((TGCustomEmojiPack *)_packs[packIndex]).title;
    return nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(PSUICollectionView *)__unused collectionView
{
    return [self firstPackSection] + (NSInteger)_packs.count;
}

- (NSInteger)collectionView:(PSUICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)section
{
    return (NSInteger)[self itemsForSection:section].count;
}

- (CGSize)collectionView:(PSUICollectionView *)collectionView layout:(PSUICollectionViewLayout *)__unused collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
    if (section == [self hintSection])
        return CGSizeMake(collectionView.bounds.size.width, [TGCustomEmojiKeyboardHint heightForText:TGLocalized(@"CustomEmoji.PremiumHint") width:collectionView.bounds.size.width]);
    return CGSizeMake(collectionView.bounds.size.width, TGCustomEmojiKeyboardHeaderHeight);
}

- (UIEdgeInsets)collectionView:(PSUICollectionView *)collectionView layout:(PSUICollectionViewLayout *)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    if (section == [self hintSection])
        return UIEdgeInsetsZero;
    CGFloat width = collectionView.bounds.size.width;
    NSInteger columns = MAX(1, (NSInteger)CGFloor((width - 12.0f) / TGCustomEmojiKeyboardItemSide));
    CGFloat side = CGFloor((width - columns * TGCustomEmojiKeyboardItemSide) / 2.0f);
    return UIEdgeInsetsMake(2.0f, side, 6.0f, side);
}

- (PSUICollectionReusableView *)collectionView:(PSUICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == [self hintSection])
    {
        TGCustomEmojiKeyboardHint *hint = (TGCustomEmojiKeyboardHint *)[collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:TGCustomEmojiKeyboardHintIdentifier forIndexPath:indexPath];
        [hint setText:TGLocalized(@"CustomEmoji.PremiumHint") color:_presentation.pallete.chatInputKeyboardHeaderColor ?: UIColorRGB(0x949599)];
        return hint;
    }
    TGStickerCollectionHeader *header = (TGStickerCollectionHeader *)[collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:TGCustomEmojiKeyboardHeaderIdentifier forIndexPath:indexPath];
    header.presentation = _presentation;
    header.icon = nil;
    header.title = [self titleForSection:indexPath.section];
    return header;
}

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    TGCustomEmojiKeyboardCell *cell = (TGCustomEmojiKeyboardCell *)[collectionView dequeueReusableCellWithReuseIdentifier:TGCustomEmojiKeyboardCellIdentifier forIndexPath:indexPath];
    NSArray *items = [self itemsForSection:indexPath.section];
    if (indexPath.item < (NSInteger)items.count)
        [cell setItem:items[indexPath.item]];
    return cell;
}

- (void)collectionView:(PSUICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [collectionView deselectItemAtIndexPath:indexPath animated:false];
    NSArray *items = [self itemsForSection:indexPath.section];
    if (indexPath.item >= (NSInteger)items.count)
        return;
    TGCustomEmojiItem *item = items[indexPath.item];
    TGCustomEmojiKeyboardCell *cell = (TGCustomEmojiKeyboardCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [TGCustomEmojiSignals addRecentItem:item];
    if (_itemSelected)
        _itemSelected(item, [cell isKindOfClass:[TGCustomEmojiKeyboardCell class]] ? cell.image : nil);
}

@end
