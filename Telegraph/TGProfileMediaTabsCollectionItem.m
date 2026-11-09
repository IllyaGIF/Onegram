#import "TGProfileMediaTabsCollectionItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGCollectionItemView.h"
#import "TGPresentation.h"
#import "TGStoryItem.h"
#import "TGStarGift.h"
#import "TGStarGiftTileView.h"
#import "TGStoryThumbnailTileView.h"
#import "TGProfileActionsCollectionItemView.h"

static const CGFloat TGProfileMediaTabsHeight = 44.0f;
static const CGFloat TGProfileMediaInset = 12.0f;
static const CGFloat TGProfileMediaSpacing = 6.0f;
static const CGFloat TGProfileGiftsInset = 16.0f;
static const CGFloat TGProfileGiftsSpacing = 10.0f;
static const CGFloat TGProfileMediaFooterHeight = 44.0f;
static const CGFloat TGProfileMediaEmptyHeight = 72.0f;
static const NSUInteger TGProfileMediaMaxTiles = 9;
static const NSUInteger TGProfileMediaColumns = 3;

static CGFloat TGProfileMediaTileAspect(TGProfileMediaTab tab)
{
    return tab == TGProfileMediaTabPosts ? (4.0f / 3.0f) : 1.0f;
}

static CGFloat TGProfileMediaTabInset(TGProfileMediaTab tab)
{
    return tab == TGProfileMediaTabPosts ? TGProfileMediaInset : TGProfileGiftsInset;
}

static CGFloat TGProfileMediaTabSpacing(TGProfileMediaTab tab)
{
    return tab == TGProfileMediaTabPosts ? TGProfileMediaSpacing : TGProfileGiftsSpacing;
}

static CGFloat TGProfileMediaTileWidth(CGFloat width, TGProfileMediaTab tab)
{
    return CGFloor((width - TGProfileMediaTabInset(tab) * 2.0f - TGProfileMediaTabSpacing(tab) * (TGProfileMediaColumns - 1)) / TGProfileMediaColumns);
}

@interface TGProfileMediaTabsCollectionItem ()

- (NSUInteger)visibleTileCount;
- (bool)showsFooter;

@end

@interface TGProfileMediaTabsCollectionItemView : TGCollectionItemView
{
    NSMutableArray *_tabButtons;
    UIView *_tabIndicator;
    UIView *_tabSeparator;
    UIView *_giftsBackgroundView;
    NSMutableArray *_storyTiles;
    NSMutableArray *_giftTiles;
    UILabel *_emptyLabel;
    UIActivityIndicatorView *_activityIndicator;
    UIButton *_footerButton;
    __weak TGProfileMediaTabsCollectionItem *_item;
}

- (void)updateWithItem:(TGProfileMediaTabsCollectionItem *)item;

@end

@implementation TGProfileMediaTabsCollectionItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _tabButtons = [[NSMutableArray alloc] init];
        _storyTiles = [[NSMutableArray alloc] init];
        _giftTiles = [[NSMutableArray alloc] init];

        _giftsBackgroundView = [[UIView alloc] init];
        [self.contentView addSubview:_giftsBackgroundView];

        _tabSeparator = [[UIView alloc] init];
        [self.contentView addSubview:_tabSeparator];
        _tabIndicator = [[UIView alloc] init];
        _tabIndicator.layer.cornerRadius = 1.5f;
        [self.contentView addSubview:_tabIndicator];

        _emptyLabel = [[UILabel alloc] init];
        _emptyLabel.backgroundColor = [UIColor clearColor];
        _emptyLabel.font = TGSystemFontOfSize(15.0f);
        _emptyLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_emptyLabel];

        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.hidesWhenStopped = true;
        [self.contentView addSubview:_activityIndicator];

        _footerButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _footerButton.titleLabel.font = TGSystemFontOfSize(16.0f);
        [_footerButton addTarget:self action:@selector(footerPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_footerButton];
    }
    return self;
}

- (UIColor *)cellBackgroundColor
{
    TGPresentationPallete *pallete = self.presentation.pallete;
    return pallete.isDark ? pallete.collectionMenuBackgroundColor : [super cellBackgroundColor];
}

- (void)setPresentation:(TGPresentation *)presentation
{
    [super setPresentation:presentation];
    _tabSeparator.backgroundColor = presentation.pallete.collectionMenuSeparatorColor;
    _giftsBackgroundView.backgroundColor = presentation.pallete.collectionMenuBackgroundColor;
    _tabIndicator.backgroundColor = presentation.pallete.collectionMenuAccentColor;
    _emptyLabel.textColor = presentation.pallete.collectionMenuCommentColor;
    [_footerButton setTitleColor:presentation.pallete.collectionMenuAccentColor forState:UIControlStateNormal];
    for (TGStarGiftTileView *tile in _giftTiles)
        tile.presentation = presentation;
    [self updateTabColors];
}

- (NSArray *)tabTitles
{
    NSMutableArray *titles = [[NSMutableArray alloc] initWithObjects:TGLocalized(@"OnegramProfile.TabPosts"), TGLocalized(@"OnegramProfile.TabGifts"), nil];
    if (_item.showsMediaTab)
        [titles addObject:TGLocalized(@"OnegramProfile.TabMedia")];
    return titles;
}

- (void)updateTabButtons
{
    NSArray *titles = [self tabTitles];
    while (_tabButtons.count > titles.count)
    {
        [[_tabButtons lastObject] removeFromSuperview];
        [_tabButtons removeLastObject];
    }
    while (_tabButtons.count < titles.count)
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.titleLabel.font = TGMediumSystemFontOfSize(15.0f);
        [button addTarget:self action:@selector(tabPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:button];
        [_tabButtons addObject:button];
    }
    for (NSUInteger i = 0; i < titles.count; i++)
        [[_tabButtons objectAtIndex:i] setTitle:[titles objectAtIndex:i] forState:UIControlStateNormal];
    [self updateTabColors];
}

- (void)updateTabColors
{
    for (NSUInteger i = 0; i < _tabButtons.count; i++)
    {
        UIButton *button = [_tabButtons objectAtIndex:i];
        bool selected = (NSInteger)i == (NSInteger)_item.selectedTab;
        [button setTitleColor:selected ? self.presentation.pallete.collectionMenuAccentColor : self.presentation.pallete.collectionMenuVariantColor forState:UIControlStateNormal];
    }
}

- (void)tabPressed:(UIButton *)button
{
    NSUInteger index = [_tabButtons indexOfObject:button];
    TGProfileMediaTabsCollectionItem *item = _item;
    if (index == NSNotFound || item == nil)
        return;
    if (index == 2)
    {
        if (item.mediaPressed != nil)
            item.mediaPressed();
        return;
    }
    if ((TGProfileMediaTab)index == item.selectedTab)
        return;
    item.selectedTab = (TGProfileMediaTab)index;
    if (item.heightChanged != nil)
        item.heightChanged();
}

- (void)footerPressed
{
    TGProfileMediaTabsCollectionItem *item = _item;
    void (^action)(void) = item.selectedTab == TGProfileMediaTabPosts ? item.showAllStoriesPressed : item.showAllGiftsPressed;
    if (action != nil)
        action();
}

- (void)storyTilePressed:(UIView *)tile
{
    TGProfileMediaTabsCollectionItem *item = _item;
    NSUInteger index = [_storyTiles indexOfObject:tile];
    if (index == NSNotFound || item == nil)
        return;
    if (item.showsAddTile)
    {
        if (index == 0)
        {
            if (item.addStoryPressed != nil)
                item.addStoryPressed();
            return;
        }
        index--;
    }
    if (item.storySelected != nil)
        item.storySelected(index);
}

- (void)giftTilePressed:(UIView *)tile
{
    TGProfileMediaTabsCollectionItem *item = _item;
    NSUInteger index = [_giftTiles indexOfObject:tile];
    if (index == NSNotFound || item == nil)
        return;
    if (item.showsSendTile)
    {
        if (index == 0)
        {
            if (item.sendGiftPressed != nil)
                item.sendGiftPressed();
            return;
        }
        index--;
    }
    if (item.giftSelected != nil)
        item.giftSelected(index);
}

- (void)updateWithItem:(TGProfileMediaTabsCollectionItem *)item
{
    _item = item;
    [self updateTabButtons];

    bool posts = item.selectedTab == TGProfileMediaTabPosts;
    NSUInteger tileCount = [item visibleTileCount];

    NSMutableArray *activeTiles = posts ? _storyTiles : _giftTiles;
    NSMutableArray *inactiveTiles = posts ? _giftTiles : _storyTiles;
    for (UIView *tile in inactiveTiles)
        tile.hidden = true;
    while (activeTiles.count < tileCount)
    {
        UIControl *tile = nil;
        if (posts)
        {
            tile = [[TGStoryThumbnailTileView alloc] init];
            [tile addTarget:self action:@selector(storyTilePressed:) forControlEvents:UIControlEventTouchUpInside];
        }
        else
        {
            TGStarGiftTileView *giftTile = [[TGStarGiftTileView alloc] init];
            giftTile.profileStyle = true;
            giftTile.presentation = self.presentation;
            giftTile.animated = true;
            [giftTile addTarget:self action:@selector(giftTilePressed:) forControlEvents:UIControlEventTouchUpInside];
            tile = giftTile;
        }
        [self.contentView addSubview:tile];
        [activeTiles addObject:tile];
    }
    for (NSUInteger i = 0; i < activeTiles.count; i++)
    {
        UIView *tile = [activeTiles objectAtIndex:i];
        tile.hidden = i >= tileCount;
        if (tile.hidden)
            continue;
        if (posts)
        {
            TGStoryThumbnailTileView *storyTile = (TGStoryThumbnailTileView *)tile;
            if (item.showsAddTile && i == 0)
                [storyTile setAddTileWithPresentation:self.presentation];
            else
                [storyTile setStory:[item.stories objectAtIndex:i - (item.showsAddTile ? 1 : 0)]];
        }
        else
        {
            TGStarGiftTileView *giftTile = (TGStarGiftTileView *)tile;
            giftTile.presentation = self.presentation;
            UIImageView *glyphView = (UIImageView *)[giftTile viewWithTag:0x51f7];
            if (item.showsSendTile && i == 0)
            {
                [giftTile setGift:nil caption:TGLocalized(@"OnegramGifts.Send")];
                if (glyphView == nil)
                {
                    glyphView = [[UIImageView alloc] init];
                    glyphView.tag = 0x51f7;
                    glyphView.userInteractionEnabled = false;
                    [giftTile addSubview:glyphView];
                }
                glyphView.image = TGProfileActionGlyphImage(TGProfileActionIconGift, self.presentation.pallete.collectionMenuAccentColor);
                glyphView.hidden = false;
            }
            else
            {
                glyphView.hidden = true;
                [giftTile setSavedGift:[item.gifts objectAtIndex:i - (item.showsSendTile ? 1 : 0)]];
            }
        }
    }

    bool loaded = posts ? item.storiesLoaded : item.giftsLoaded;
    bool empty = tileCount == 0;
    _emptyLabel.hidden = !(empty && loaded);
    bool failed = posts ? item.storiesFailed : item.giftsFailed;
    if (failed)
        _emptyLabel.text = TGLocalized(@"OnegramProfile.LoadFailed");
    else
        _emptyLabel.text = posts ? TGLocalized(@"OnegramProfile.PostsEmpty") : TGLocalized(@"OnegramGifts.Empty");
    if (empty && !loaded)
        [_activityIndicator startAnimating];
    else
        [_activityIndicator stopAnimating];

    _footerButton.hidden = ![item showsFooter];
    int32_t total = posts ? item.storiesTotal : item.giftsTotal;
    [_footerButton setTitle:[[NSString alloc] initWithFormat:TGLocalized(@"OnegramProfile.ShowAllCount"), (int)total] forState:UIControlStateNormal];

    [self updateTabColors];
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    TGProfileMediaTabsCollectionItem *item = _item;

    CGFloat left = self.safeAreaInset.left;
    CGFloat width = bounds.size.width - self.safeAreaInset.left - self.safeAreaInset.right;
    CGFloat tabWidth = _tabButtons.count == 0 ? 0.0f : CGFloor(width / _tabButtons.count);
    for (NSUInteger i = 0; i < _tabButtons.count; i++)
        ((UIButton *)[_tabButtons objectAtIndex:i]).frame = CGRectMake(left + tabWidth * i, 0.0f, tabWidth, TGProfileMediaTabsHeight);
    _tabSeparator.frame = CGRectMake(0.0f, TGProfileMediaTabsHeight - TGScreenPixel, bounds.size.width, TGScreenPixel);
    UIButton *selectedButton = (NSUInteger)item.selectedTab < _tabButtons.count ? [_tabButtons objectAtIndex:(NSUInteger)item.selectedTab] : nil;
    CGFloat indicatorWidth = MIN(tabWidth - 24.0f, CGCeil([selectedButton.titleLabel sizeThatFits:CGSizeMake(tabWidth, 20.0f)].width) + 8.0f);
    _tabIndicator.frame = CGRectMake(CGRectGetMidX(selectedButton.frame) - indicatorWidth / 2.0f, TGProfileMediaTabsHeight - 3.0f, indicatorWidth, 3.0f);

    bool posts = item.selectedTab == TGProfileMediaTabPosts;
    CGFloat inset = TGProfileMediaTabInset(item.selectedTab);
    CGFloat spacing = TGProfileMediaTabSpacing(item.selectedTab);
    CGFloat tileWidth = TGProfileMediaTileWidth(width, item.selectedTab);
    CGFloat tileHeight = CGFloor(tileWidth * TGProfileMediaTileAspect(item.selectedTab));
    NSArray *tiles = posts ? _storyTiles : _giftTiles;
    _giftsBackgroundView.hidden = posts;
    _giftsBackgroundView.frame = CGRectMake(0.0f, TGProfileMediaTabsHeight, bounds.size.width, bounds.size.height - TGProfileMediaTabsHeight - ([item showsFooter] ? TGProfileMediaFooterHeight : 0.0f));
    NSUInteger visibleIndex = 0;
    for (UIView *tile in tiles)
    {
        if (tile.hidden)
            continue;
        NSUInteger row = visibleIndex / TGProfileMediaColumns;
        NSUInteger column = visibleIndex % TGProfileMediaColumns;
        tile.frame = CGRectMake(left + inset + column * (tileWidth + spacing), TGProfileMediaTabsHeight + inset + row * (tileHeight + spacing), tileWidth, tileHeight);
        UIView *glyphView = [tile viewWithTag:0x51f7];
        if (glyphView != nil && !glyphView.hidden)
            glyphView.frame = CGRectMake(CGFloor((tileWidth - 24.0f) / 2.0f), CGFloor((tileHeight - 22.0f) / 2.0f) - 14.0f, 24.0f, 24.0f);
        visibleIndex++;
    }
    CGFloat contentTop = TGProfileMediaTabsHeight;
    _emptyLabel.frame = CGRectMake(left + 15.0f, contentTop, width - 30.0f, TGProfileMediaEmptyHeight);
    _activityIndicator.center = CGPointMake(left + width / 2.0f, contentTop + TGProfileMediaEmptyHeight / 2.0f);
    _footerButton.frame = CGRectMake(left, bounds.size.height - TGProfileMediaFooterHeight, width, TGProfileMediaFooterHeight);
}

@end

@implementation TGProfileMediaTabsCollectionItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.selectable = false;
        self.highlightable = false;
        _stories = @[];
        _gifts = @[];
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGProfileMediaTabsCollectionItemView class];
}

- (NSUInteger)visibleTileCount
{
    if (_selectedTab == TGProfileMediaTabPosts)
        return MIN(TGProfileMediaMaxTiles, _stories.count + (_showsAddTile ? 1 : 0));
    return MIN(TGProfileMediaMaxTiles, _gifts.count + (_showsSendTile ? 1 : 0));
}

- (bool)showsFooter
{
    if (_selectedTab == TGProfileMediaTabPosts)
        return _storiesTotal > (int32_t)(_stories.count) || _stories.count + (_showsAddTile ? 1 : 0) > TGProfileMediaMaxTiles;
    return _giftsTotal > (int32_t)(_gifts.count) || _gifts.count + (_showsSendTile ? 1 : 0) > TGProfileMediaMaxTiles;
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    NSUInteger count = [self visibleTileCount];
    CGFloat height = TGProfileMediaTabsHeight;
    if (count == 0)
        height += TGProfileMediaEmptyHeight;
    else
    {
        CGFloat tileWidth = TGProfileMediaTileWidth(containerSize.width, _selectedTab);
        CGFloat tileHeight = CGFloor(tileWidth * TGProfileMediaTileAspect(_selectedTab));
        NSUInteger rows = (count + TGProfileMediaColumns - 1) / TGProfileMediaColumns;
        height += TGProfileMediaTabInset(_selectedTab) * 2.0f + rows * tileHeight + (rows - 1) * TGProfileMediaTabSpacing(_selectedTab);
    }
    if ([self showsFooter])
        height += TGProfileMediaFooterHeight;
    return CGSizeMake(containerSize.width, height);
}

- (void)bindView:(TGProfileMediaTabsCollectionItemView *)view
{
    [super bindView:view];
    [view updateWithItem:self];
}

- (void)reloadContent
{
    [(TGProfileMediaTabsCollectionItemView *)[self boundView] updateWithItem:self];
}

- (void)setSelectedTab:(TGProfileMediaTab)selectedTab
{
    _selectedTab = selectedTab;
    [self reloadContent];
}

@end
