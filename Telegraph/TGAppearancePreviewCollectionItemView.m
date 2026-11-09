#import "TGAppearancePreviewCollectionItemView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGUser.h"

#import "TGModernConversationViewLayout.h"
#import "TGModernConversationCollectionView.h"
#import "TGModernCollectionCell.h"

#import "TGModernViewStorage.h"
#import "TGModernConversationItem.h"
#import "TGMessageModernConversationItem.h"
#import "TGModernConversationViewContext.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponentsGlobals.h"

@interface TGAppearancePreviewCollectionItemView () <PSUICollectionViewDataSource, PSUICollectionViewDelegate>
{
    UIImageView *_backgroundView;
    TGModernConversationViewLayout *_collectionLayout;
    TGModernConversationCollectionView *_collectionView;
    NSMutableSet *_collectionRegisteredIdentifiers;
    
    NSArray *_items;
    CGFloat _itemsContainerWidth;
    bool _itemsBuiltOutsideWindow;
    TGModernViewStorage *_viewStorage;
    TGModernConversationViewContext *_viewContext;
}
@end

@implementation TGAppearancePreviewCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        _backgroundView = [[UIImageView alloc] init];
        _backgroundView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_backgroundView];
        
        _viewContext = [[TGModernConversationViewContext alloc] init];
        
        [self _reset];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    [self updateMessageContextPresentation];
}

- (void)setMessagePresentation:(TGPresentation *)messagePresentation
{
    if (_messagePresentation == messagePresentation)
        return;
    _messagePresentation = messagePresentation;
    [self updateMessageContextPresentation];
}

- (void)updateMessageContextPresentation
{
    TGPresentation *presentation = _messagePresentation ?: self.presentation;
    if (_viewContext.presentation == presentation)
        return;
    _viewContext.presentation = presentation;
    if (presentation != nil)
        [self reset];
}

- (void)setStickerScale:(CGFloat)stickerScale
{
    if (fabs(_viewContext.stickerScale - stickerScale) < FLT_EPSILON)
        return;
    _viewContext.stickerScale = stickerScale;
    [self setMessages:_messages];
}

- (CGFloat)stickerScale
{
    return _viewContext.stickerScale;
}

- (void)reset
{
    [self _reset];
    [self setMessages:_messages];
    
    [_collectionView reloadData];
    [_collectionView layoutSubviews];
}

- (void)unbindItems
{
    for (TGModernConversationItem *item in _items)
    {
        if (item.boundCell != nil)
            [item unbindCell:_viewStorage];
    }
}

- (void)_reset
{
    [self unbindItems];
    [_collectionView removeFromSuperview];
    _collectionView = nil;
 
    _collectionRegisteredIdentifiers = [[NSMutableSet alloc] init];
    _viewStorage = [[TGModernViewStorage alloc] init];
    
    _collectionLayout = [[TGModernConversationViewLayout alloc] init];
    _collectionLayout.inhibitDateHeaders = true;
    _collectionLayout.viewStorage = _viewStorage;
    _collectionView = [[TGModernConversationCollectionView alloc] initWithFrame:[self collectionFrame] collectionViewLayout:_collectionLayout];
    if (iosMajorVersion() >= 11)
        _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _collectionView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI);
    _collectionView.backgroundColor = nil;
    _collectionView.opaque = false;
    _collectionView.scrollsToTop = false;
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.userInteractionEnabled = false;
    [_collectionView registerClass:[TGModernCollectionCell class] forCellWithReuseIdentifier:@"_empty"];
    [self addSubview:_collectionView];
}

- (void)refreshMetrics
{
    for (TGMessageModernConversationItem *item in _items)
    {
        [item refreshMetrics];
    }
    
    [_collectionLayout invalidateLayout];
    [_collectionView layoutSubviews];
    [_collectionView updateRelativeBounds];
}

- (CGFloat)contentHeight
{
    return _collectionView.contentSize.height;
}

- (PSUICollectionViewCell *)collectionView:(PSUICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        TGModernConversationItem *item = indexPath.row < (NSInteger)_items.count ? [_items objectAtIndex:indexPath.row] : nil;
        
        if (item != nil)
        {
            __block TGModernCollectionCell *cell = nil;
            cell = [item dequeueCollectionCell:collectionView registeredIdentifiers:_collectionRegisteredIdentifiers forIndexPath:indexPath];
            if (cell.boundItem != nil)
            {
                TGModernConversationItem *item = cell.boundItem;
                [item unbindCell:_viewStorage];
            }
                 
            [self _bindItem:item toCell:cell atIndexPath:indexPath];
        
            return cell;
        }
    }
    
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"_empty" forIndexPath:indexPath];
}

- (NSArray *)items
{
    return _items;
}

- (NSInteger)numberOfSectionsInCollectionView:(PSUICollectionView *)collectionView
{
    if (collectionView == _collectionView)
        return 1;
    
    return 0;
}

- (NSInteger)collectionView:(PSUICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    if (collectionView == _collectionView && section == 0)
        return _items.count;
    return 0;
}

#pragma mark -

- (void)_bindItem:(TGModernConversationItem *)item toCell:(TGModernCollectionCell *)cell atIndexPath:(NSIndexPath *)__unused indexPath
{
    bool movedFromTemporaryContainer = false;
    
    if (!movedFromTemporaryContainer)
    {
        if (item.boundCell != nil)
            [item unbindCell:_viewStorage];
        
        [item bindCell:cell viewStorage:_viewStorage];
    }
}

#pragma mark -

- (void)setFontSize:(int32_t)fontSize
{
    _fontSize = fontSize;
}

- (void)updateWallpaper
{
    _backgroundView.image = [[LegacyComponentsGlobals provider] currentWallpaperImage];
}

- (void)setMessages:(NSArray *)messages
{
    _messages = messages;
    [self unbindItems];
    
    CGFloat width = _collectionView.frame.size.width;
    if (_viewContext.presentation == nil || width < FLT_EPSILON)
    {
        _items = nil;
        _itemsContainerWidth = 0.0f;
        _itemsBuiltOutsideWindow = false;
        [_collectionView reloadData];
        return;
    }
    
    TGUser *replyAuthor = [[TGUser alloc] init];
    replyAuthor.firstName = TGLocalized(@"Appearance.PreviewReplyAuthor");
    replyAuthor.uid = 2;
    
    _itemsContainerWidth = width;
    _itemsBuiltOutsideWindow = self.window == nil && messages.count != 0;
    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (TGMessage *message in messages)
    {
        TGMessageModernConversationItem *messageItem = [[TGMessageModernConversationItem alloc] initWithMessage:message context:_viewContext];
        messageItem->_additionalUsers = @[replyAuthor];
        [messageItem sizeForContainerSize:CGSizeMake(_itemsContainerWidth, 0.0f) viewStorage:nil];
        
        [items addObject:messageItem];
    }
    
    _items = items;
    [_collectionView reloadData];
    [_collectionView layoutSubviews];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _backgroundView.hidden = [self usesBrandedGroupedSurface];
    _backgroundView.frame = self.bounds;
    _collectionView.frame = [self collectionFrame];
    
    CGFloat width = _collectionView.frame.size.width;
    if (_messages.count != 0 && width > FLT_EPSILON && fabs(width - _itemsContainerWidth) > FLT_EPSILON)
        [self rebuildForCurrentGeometry];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window != nil && _itemsBuiltOutsideWindow)
        [self rebuildForCurrentGeometry];
}

- (CGRect)collectionFrame
{
    if ([self usesBrandedGroupedSurface])
        return [self classicIOS6GroupedFrame];
    return CGRectMake(self.safeAreaInset.left, 0.0f, self.frame.size.width - self.safeAreaInset.left - self.safeAreaInset.right, self.frame.size.height);
}

- (void)rebuildForCurrentGeometry
{
    if (_viewContext.presentation == nil)
        return;
    CGFloat previousHeight = self.contentHeight;
    [self reset];
    if (_contentHeightChanged != nil && fabs(previousHeight - self.contentHeight) > FLT_EPSILON)
        _contentHeightChanged();
}

@end
