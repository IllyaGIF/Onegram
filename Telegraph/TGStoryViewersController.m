#import "TGStoryViewersController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGDatabase.h"
#import "TGStoryItem.h"
#import "TGStoriesSignals.h"
#import "TGStoryViewerCollectionItem.h"
#import "TGCommentCollectionItem.h"

static const int32_t TGStoryViewersPageLimit = 50;

@interface TGStoryViewersController ()
{
    TGStoryItem *_story;
    NSMutableArray *_viewers;
    NSMutableSet *_viewerIds;
    NSString *_nextOffset;
    bool _loading;
    bool _loadedOnce;
    int32_t _viewsCount;
    int32_t _reactionsCount;

    TGCommentCollectionItem *_summaryItem;
    TGCollectionMenuSection *_viewersSection;
    SMetaDisposable *_loadDisposable;
}

@end

@implementation TGStoryViewersController

- (instancetype)initWithStory:(TGStoryItem *)story
{
    self = [super init];
    if (self != nil)
    {
        _story = story;
        _viewers = [[NSMutableArray alloc] init];
        _viewerIds = [[NSMutableSet alloc] init];
        _viewsCount = story.viewsCount;
        _reactionsCount = story.reactionsCount;
        _loadDisposable = [[SMetaDisposable alloc] init];

        self.title = TGLocalized(@"StoryViewers.Title");
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)] animated:false];

        _summaryItem = [[TGCommentCollectionItem alloc] initWithText:@""];
        _summaryItem.showProgress = true;
        TGCollectionMenuSection *summarySection = [[TGCollectionMenuSection alloc] initWithItems:@[_summaryItem]];
        summarySection.insets = UIEdgeInsetsMake(16.0f, 0.0f, 8.0f, 0.0f);
        [self.menuSections addSection:summarySection];

        _viewersSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_viewersSection];

        [self updateSummary];
        [self loadNextPage];
    }
    return self;
}

- (void)dealloc
{
    [_loadDisposable dispose];
}

- (void)donePressed
{
    void (^dismissed)(void) = _dismissed;
    [self.presentingViewController dismissViewControllerAnimated:true completion:^
    {
        if (dismissed != nil)
            dismissed();
    }];
}

- (void)updateSummary
{
    NSString *text = [[NSString alloc] initWithFormat:TGLocalized(@"StoryViewers.Summary"), (int)_viewsCount, (int)_reactionsCount];
    if (_loadedOnce && _viewers.count == 0)
        text = TGLocalized(@"StoryViewers.Empty");
    _summaryItem.text = text;
    _summaryItem.showProgress = _loading && !_loadedOnce;
}

- (void)loadMore
{
    if (_nextOffset != nil)
        [self loadNextPage];
}

- (void)loadNextPage
{
    if (_loading || (_loadedOnce && _nextOffset == nil))
        return;
    _loading = true;
    [self updateSummary];

    __weak TGStoryViewersController *weakSelf = self;
    [_loadDisposable setDisposable:[[[TGStoriesSignals viewersForStory:_story offset:_nextOffset limit:TGStoryViewersPageLimit] deliverOn:[SQueue mainQueue]] startWithNext:^(TGStoryViewersPage *page)
    {
        __strong TGStoryViewersController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf applyPage:page];
    } error:^(__unused id error)
    {
        __strong TGStoryViewersController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_loading = false;
        strongSelf->_loadedOnce = true;
        strongSelf->_nextOffset = nil;
        [strongSelf updateSummary];
        if (strongSelf->_viewers.count == 0)
            strongSelf->_summaryItem.text = TGLocalized(@"StoryViewers.LoadFailed");
        [strongSelf.collectionLayout invalidateLayout];
    } completed:nil]];
}

- (void)applyPage:(TGStoryViewersPage *)page
{
    _loading = false;
    _loadedOnce = true;
    _nextOffset = page.nextOffset;
    if (page.viewsCount > 0)
        _viewsCount = page.viewsCount;
    _reactionsCount = page.reactionsCount;

    for (TGStoryViewer *viewer in page.viewers)
    {
        if ([_viewerIds containsObject:@(viewer.userId)])
            continue;
        TGUser *user = [TGDatabaseInstance() loadUser:viewer.userId];
        if (user == nil)
            continue;
        [_viewerIds addObject:@(viewer.userId)];
        [_viewers addObject:viewer];

        TGStoryViewerCollectionItem *item = [[TGStoryViewerCollectionItem alloc] init];
        item.user = user;
        item.date = viewer.date;
        item.hasReaction = viewer.hasReaction;
        item.reaction = viewer.reaction;
        item.blocked = viewer.blocked;
        [_viewersSection addItem:item];
    }

    [self updateSummary];
    [self.collectionView reloadData];
}

@end
