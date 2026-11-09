#import "TGStarGiftCatalogController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGProfileGridView.h"
#import "TGStarGiftTileView.h"
#import "TGStarGiftSendController.h"
#import "TGStarGiftsSignals.h"
#import "TGStarGift.h"
#import "TGPresentation.h"

@interface TGStarGiftCatalogController ()
{
    int64_t _peerId;
    NSArray *_gifts;
    NSNumber *_balance;
    TGProfileGridView *_gridView;
    UILabel *_balanceLabel;
    UILabel *_emptyLabel;
    UIActivityIndicatorView *_activityIndicator;
    SMetaDisposable *_giftsDisposable;
    SMetaDisposable *_balanceDisposable;
}

@end

@implementation TGStarGiftCatalogController

+ (void)presentForPeerId:(int64_t)peerId fromController:(UIViewController *)controller
{
    if (controller == nil || peerId == 0)
        return;
    TGStarGiftCatalogController *catalog = [[TGStarGiftCatalogController alloc] initWithPeerId:peerId];
    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[catalog]];
    [controller presentViewController:navigationController animated:true completion:nil];
}

- (instancetype)initWithPeerId:(int64_t)peerId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _gifts = @[];
        _giftsDisposable = [[SMetaDisposable alloc] init];
        _balanceDisposable = [[SMetaDisposable alloc] init];
        [self setTitleText:TGLocalized(@"OnegramGifts.SendTitle")];
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Close") style:UIBarButtonItemStylePlain target:self action:@selector(closePressed)] animated:false];
    }
    return self;
}

- (void)dealloc
{
    [_giftsDisposable dispose];
    [_balanceDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    TGPresentation *presentation = [TGPresentation current];
    self.view.backgroundColor = presentation.pallete.collectionMenuBackgroundColor;

    _gridView = [[TGProfileGridView alloc] initWithFrame:self.view.bounds];
    _gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _gridView.columns = 3;
    _gridView.tileAspect = 1.18f;
    _gridView.spacing = 8.0f;
    _gridView.gridInsets = UIEdgeInsetsMake(44.0f, 12.0f, 12.0f, 12.0f);
    _gridView.backgroundColor = presentation.pallete.collectionMenuBackgroundColor;
    __weak TGStarGiftCatalogController *weakSelf = self;
    _gridView.tileFactory = ^UIView *
    {
        TGStarGiftTileView *tile = [[TGStarGiftTileView alloc] init];
        tile.presentation = [TGPresentation current];
        tile.animated = false;
        return tile;
    };
    _gridView.configureTile = ^(UIView *tile, NSUInteger index)
    {
        __strong TGStarGiftCatalogController *strongSelf = weakSelf;
        if (strongSelf == nil || index >= strongSelf->_gifts.count)
            return;
        TGStarGift *gift = [strongSelf->_gifts objectAtIndex:index];
        [(TGStarGiftTileView *)tile setGift:gift caption:TGStarGiftStarsString(gift.stars)];
    };
    _gridView.tileSelected = ^(NSUInteger index)
    {
        __strong TGStarGiftCatalogController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf giftSelectedAtIndex:index];
    };
    [self.view addSubview:_gridView];

    _balanceLabel = [[UILabel alloc] init];
    _balanceLabel.backgroundColor = [UIColor clearColor];
    _balanceLabel.textColor = presentation.pallete.collectionMenuCommentColor;
    _balanceLabel.font = TGSystemFontOfSize(14.0f);
    _balanceLabel.textAlignment = NSTextAlignmentCenter;
    [_gridView addSubview:_balanceLabel];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.backgroundColor = [UIColor clearColor];
    _emptyLabel.textColor = presentation.pallete.collectionMenuCommentColor;
    _emptyLabel.font = TGSystemFontOfSize(15.0f);
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.text = TGLocalized(@"OnegramGifts.CatalogEmpty");
    _emptyLabel.hidden = true;
    [self.view addSubview:_emptyLabel];

    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityIndicator.hidesWhenStopped = true;
    [self.view addSubview:_activityIndicator];

    self.scrollViewsForAutomaticInsetsAdjustment = @[_gridView];
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
    [self updateBalanceLabel];
    [self loadData];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    CGRect bounds = self.view.bounds;
    _balanceLabel.frame = CGRectMake(12.0f, 12.0f, bounds.size.width - 24.0f, 20.0f);
    _emptyLabel.frame = CGRectMake(20.0f, CGFloor(bounds.size.height / 2.0f) - 12.0f, bounds.size.width - 40.0f, 24.0f);
    _activityIndicator.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

- (void)loadData
{
    [_activityIndicator startAnimating];
    __weak TGStarGiftCatalogController *weakSelf = self;
    [_giftsDisposable setDisposable:[[[TGStarGiftsSignals availableGifts] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *gifts)
    {
        __strong TGStarGiftCatalogController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        [strongSelf->_activityIndicator stopAnimating];
        strongSelf->_gifts = [gifts sortedArrayUsingComparator:^NSComparisonResult(TGStarGift *lhs, TGStarGift *rhs)
        {
            if (lhs.stars == rhs.stars)
                return NSOrderedSame;
            return lhs.stars < rhs.stars ? NSOrderedAscending : NSOrderedDescending;
        }];
        strongSelf->_gridView.itemCount = strongSelf->_gifts.count;
        [strongSelf->_gridView reloadData];
        strongSelf->_emptyLabel.hidden = strongSelf->_gifts.count != 0;
    } error:^(__unused id error)
    {
        __strong TGStarGiftCatalogController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        [strongSelf->_activityIndicator stopAnimating];
        strongSelf->_emptyLabel.hidden = false;
    } completed:nil]];

    [_balanceDisposable setDisposable:[[[TGStarGiftsSignals starsBalance] deliverOn:[SQueue mainQueue]] startWithNext:^(NSNumber *balance)
    {
        __strong TGStarGiftCatalogController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_balance = balance;
        [strongSelf updateBalanceLabel];
    } error:nil completed:nil]];
}

- (void)updateBalanceLabel
{
    _balanceLabel.text = _balance == nil ? TGLocalized(@"OnegramGifts.BalanceLoading") : [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.Balance"), TGStarGiftStarsString([_balance longLongValue])];
}

- (void)giftSelectedAtIndex:(NSUInteger)index
{
    if (index >= _gifts.count)
        return;
    TGStarGiftSendController *sendController = [[TGStarGiftSendController alloc] initWithGift:[_gifts objectAtIndex:index] peerId:_peerId balance:_balance];
    [self.navigationController pushViewController:sendController animated:true];
}

- (void)closePressed
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

@end
