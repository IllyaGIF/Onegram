#import "TGStoriesGridController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGProfileGridView.h"
#import "TGStoryThumbnailTileView.h"
#import "TGStoryViewerController.h"
#import "TGStoriesSignals.h"
#import "TGStoryItem.h"
#import "TGTelegraph.h"
#import "TGPresentation.h"

static const int32_t TGStoriesGridPageSize = 30;

@interface TGStoriesGridController ()
{
    int64_t _peerId;
    bool _archive;
    NSMutableArray *_stories;
    int32_t _totalCount;
    bool _loading;
    bool _reachedEnd;
    TGProfileGridView *_gridView;
    UILabel *_emptyLabel;
    UIActivityIndicatorView *_activityIndicator;
    SMetaDisposable *_loadDisposable;
}

@end

@implementation TGStoriesGridController

- (instancetype)initWithPeerId:(int64_t)peerId archive:(bool)archive
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _archive = archive;
        _stories = [[NSMutableArray alloc] init];
        _loadDisposable = [[SMetaDisposable alloc] init];
        [self setTitleText:archive ? TGLocalized(@"OnegramStories.Archive") : TGLocalized(@"OnegramStories.Title")];
        if (!archive && peerId == TGTelegraphInstance.clientUserId)
            [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"OnegramStories.ArchiveButton") style:UIBarButtonItemStylePlain target:self action:@selector(archivePressed)] animated:false];
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
    self.view.backgroundColor = [TGPresentation current].pallete.backgroundColor;

    _gridView = [[TGProfileGridView alloc] initWithFrame:self.view.bounds];
    _gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _gridView.columns = 3;
    _gridView.tileAspect = 16.0f / 9.0f;
    _gridView.spacing = 2.0f;
    _gridView.backgroundColor = [TGPresentation current].pallete.backgroundColor;
    __weak TGStoriesGridController *weakSelf = self;
    _gridView.tileFactory = ^UIView *
    {
        TGStoryThumbnailTileView *tile = [[TGStoryThumbnailTileView alloc] init];
        tile.layer.cornerRadius = 0.0f;
        return tile;
    };
    _gridView.configureTile = ^(UIView *tile, NSUInteger index)
    {
        __strong TGStoriesGridController *strongSelf = weakSelf;
        if (strongSelf != nil && index < strongSelf->_stories.count)
            [(TGStoryThumbnailTileView *)tile setStory:[strongSelf->_stories objectAtIndex:index]];
    };
    _gridView.tileSelected = ^(NSUInteger index)
    {
        __strong TGStoriesGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf openStoryAtIndex:index];
    };
    _gridView.nearEnd = ^
    {
        __strong TGStoriesGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf loadMore];
    };
    [self.view addSubview:_gridView];

    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.backgroundColor = [UIColor clearColor];
    _emptyLabel.textColor = [TGPresentation current].pallete.collectionMenuCommentColor;
    _emptyLabel.font = TGSystemFontOfSize(15.0f);
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.text = TGLocalized(@"OnegramStories.Empty");
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
    if (_stories.count == 0)
        [_activityIndicator startAnimating];
    int32_t offsetId = _stories.count == 0 ? 0 : ((TGStoryItem *)[_stories lastObject]).storyId;
    SSignal *signal = _archive ? [TGStoriesSignals storiesArchiveWithOffsetId:offsetId limit:TGStoriesGridPageSize] : [TGStoriesSignals pinnedStories:_peerId offsetId:offsetId limit:TGStoriesGridPageSize];
    __weak TGStoriesGridController *weakSelf = self;
    [_loadDisposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(TGStoriesPage *page)
    {
        __strong TGStoriesGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf appendPage:page];
    } error:^(__unused id error)
    {
        __strong TGStoriesGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_loading = false;
            [strongSelf->_activityIndicator stopAnimating];
            [strongSelf updateEmptyState];
        }
    } completed:nil]];
}

- (void)appendPage:(TGStoriesPage *)page
{
    _loading = false;
    [_activityIndicator stopAnimating];
    _totalCount = page.totalCount;
    NSUInteger before = _stories.count;
    for (TGStoryItem *item in page.stories)
    {
        if (item.kind != TGStoryItemKindDeleted)
            [_stories addObject:item];
    }
    if (_stories.count == before || (_totalCount > 0 && (int32_t)_stories.count >= _totalCount))
        _reachedEnd = true;
    _gridView.itemCount = _stories.count;
    [_gridView reloadData];
    [self updateEmptyState];
}

- (void)updateEmptyState
{
    _emptyLabel.hidden = _stories.count != 0 || _loading;
}

- (void)openStoryAtIndex:(NSUInteger)index
{
    if (index >= _stories.count)
        return;
    TGPeerStories *peerStories = [[TGPeerStories alloc] initWithPeerId:_peerId maxReadId:INT32_MAX stories:_stories];
    TGStoryViewerController *viewer = [[TGStoryViewerController alloc] initWithPeerStories:@[peerStories] peerIndex:0 storyIndex:index];
    viewer.marksStoriesAsRead = false;
    __weak TGStoriesGridController *weakSelf = self;
    viewer.storiesDeleted = ^(__unused int64_t peerId, NSArray *storyIds)
    {
        __strong TGStoriesGridController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf removeStoryIds:storyIds];
    };
    viewer.storyPinnedChanged = ^(__unused int64_t peerId, int32_t storyId, bool pinned)
    {
        __strong TGStoriesGridController *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_archive && !pinned)
            [strongSelf removeStoryIds:@[@(storyId)]];
        else if (strongSelf.storiesChanged != nil)
            strongSelf.storiesChanged();
    };
    [self presentViewController:viewer animated:true completion:nil];
}

- (void)removeStoryIds:(NSArray *)storyIds
{
    NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init];
    for (NSUInteger index = 0; index < _stories.count; index++)
    {
        if ([storyIds containsObject:@(((TGStoryItem *)[_stories objectAtIndex:index]).storyId)])
            [indexes addIndex:index];
    }
    if (indexes.count == 0)
        return;
    [_stories removeObjectsAtIndexes:indexes];
    _totalCount = MAX(0, _totalCount - (int32_t)indexes.count);
    _gridView.itemCount = _stories.count;
    [_gridView reloadData];
    [self updateEmptyState];
    if (_storiesChanged != nil)
        _storiesChanged();
}

- (void)archivePressed
{
    TGStoriesGridController *archiveController = [[TGStoriesGridController alloc] initWithPeerId:_peerId archive:true];
    archiveController.storiesChanged = _storiesChanged;
    [self.navigationController pushViewController:archiveController animated:true];
}

@end
