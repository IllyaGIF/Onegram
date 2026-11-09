#import "TGStarGiftsGridController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGProfileGridView.h"
#import "TGStarGiftTileView.h"
#import "TGStarGiftSheetView.h"
#import "TGStarGiftsSignals.h"
#import "TGStarGift.h"
#import "TGPresentation.h"

static const int32_t TGStarGiftsGridPageSize = 30;

@interface TGStarGiftsGridController ()
{
    int64_t _peerId;
    bool _canManage;
    NSMutableArray *_gifts;
    NSString *_nextOffset;
    bool _loading;
    bool _reachedEnd;
    TGProfileGridView *_gridView;
    UILabel *_emptyLabel;
    UIActivityIndicatorView *_activityIndicator;
    SMetaDisposable *_loadDisposable;
}

@end

@implementation TGStarGiftsGridController

- (instancetype)initWithPeerId:(int64_t)peerId canManage:(bool)canManage
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _canManage = canManage;
        _gifts = [[NSMutableArray alloc] init];
        _loadDisposable = [[SMetaDisposable alloc] init];
        [self setTitleText:TGLocalized(@"OnegramGifts.Title")];
    }
    return self;
}

- (void)dealloc
{
    [_loadDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    TGPresentation *presentation = [TGPresentation current];
    self.view.backgroundColor = presentation.pallete.collectionMenuBackgroundColor;

    _gridView = [[TGProfileGridView alloc] initWithFrame:self.view.bounds];
    _gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _gridView.columns = 3;
    _gridView.tileAspect = 1.0f;
    _gridView.spacing = 10.0f;
    _gridView.gridInsets = UIEdgeInsetsMake(16.0f, 16.0f, 16.0f, 16.0f);
    _gridView.backgroundColor = presentation.pallete.collectionMenuBackgroundColor;
    __weak TGStarGiftsGridController *weakSelf = self;
    _gridView.tileFactory = ^UIView *
    {
        TGStarGiftTileView *tile = [[TGStarGiftTileView alloc] init];
        tile.presentation = [TGPresentation current];
        tile.profileStyle = true;
        tile.animated = true;
        return tile;
    };
    _gridView.configureTile = ^(UIView *tile, NSUInteger index)
    {
        __strong TGStarGiftsGridController *strongSelf = weakSelf;
        if (strongSelf == nil || index >= strongSelf->_gifts.count)
            return;
        TGSavedStarGift *savedGift = [strongSelf->_gifts objectAtIndex:index];
        [(TGStarGiftTileView *)tile setSavedGift:savedGift];
    };
    _gridView.tileSelected = ^(NSUInteger index)
    {
        __strong TGStarGiftsGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf openGiftAtIndex:index];
    };
    _gridView.nearEnd = ^
    {
        __strong TGStarGiftsGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf loadMore];
    };
    [self.view addSubview:_gridView];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.backgroundColor = [UIColor clearColor];
    _emptyLabel.textColor = presentation.pallete.collectionMenuCommentColor;
    _emptyLabel.font = TGSystemFontOfSize(15.0f);
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.text = TGLocalized(@"OnegramGifts.Empty");
    _emptyLabel.hidden = true;
    [self.view addSubview:_emptyLabel];

    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityIndicator.hidesWhenStopped = true;
    [self.view addSubview:_activityIndicator];

    self.scrollViewsForAutomaticInsetsAdjustment = @[_gridView];
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
    [self loadMore];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    CGRect bounds = self.view.bounds;
    _emptyLabel.frame = CGRectMake(20.0f, CGFloor(bounds.size.height / 2.0f) - 12.0f, bounds.size.width - 40.0f, 24.0f);
    _activityIndicator.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

- (void)loadMore
{
    if (_loading || _reachedEnd)
        return;
    _loading = true;
    if (_gifts.count == 0)
        [_activityIndicator startAnimating];
    __weak TGStarGiftsGridController *weakSelf = self;
    [_loadDisposable setDisposable:[[[TGStarGiftsSignals savedGifts:_peerId offset:_nextOffset limit:TGStarGiftsGridPageSize] deliverOn:[SQueue mainQueue]] startWithNext:^(TGSavedStarGiftsPage *page)
    {
        __strong TGStarGiftsGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf appendPage:page];
    } error:^(__unused id error)
    {
        __strong TGStarGiftsGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_loading = false;
            [strongSelf->_activityIndicator stopAnimating];
            [strongSelf updateEmptyState];
        }
    } completed:nil]];
}

- (void)appendPage:(TGSavedStarGiftsPage *)page
{
    _loading = false;
    [_activityIndicator stopAnimating];
    [_gifts addObjectsFromArray:page.gifts];
    _nextOffset = page.nextOffset;
    if (_nextOffset.length == 0 || page.gifts.count == 0)
        _reachedEnd = true;
    _gridView.itemCount = _gifts.count;
    [_gridView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState
{
    _emptyLabel.hidden = _gifts.count != 0 || _loading;
}

- (void)openGiftAtIndex:(NSUInteger)index
{
    if (index >= _gifts.count)
        return;
    __block TGSavedStarGift *gift = [_gifts objectAtIndex:index];
    TGStarGiftSheetView *sheet = [[TGStarGiftSheetView alloc] initWithSavedGift:gift canManage:_canManage];
    __weak TGStarGiftsGridController *weakSelf = self;
    sheet.giftUpdated = ^(TGSavedStarGift *updatedGift)
    {
        __strong TGStarGiftsGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf replaceGift:gift withGift:updatedGift];
        gift = updatedGift;
    };
    sheet.giftRemoved = ^(__unused TGSavedStarGift *removedGift)
    {
        __strong TGStarGiftsGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf replaceGift:gift withGift:nil];
    };
    [sheet presentFromController:self];
}

- (void)replaceGift:(TGSavedStarGift *)gift withGift:(TGSavedStarGift *)updatedGift
{
    NSUInteger index = [_gifts indexOfObjectIdenticalTo:gift];
    if (index == NSNotFound)
        return;
    if (updatedGift == nil)
        [_gifts removeObjectAtIndex:index];
    else
        [_gifts replaceObjectAtIndex:index withObject:updatedGift];
    _gridView.itemCount = _gifts.count;
    [_gridView reloadData];
    [self updateEmptyState];
    if (_giftsChanged != nil)
        _giftsChanged();
}

@end
