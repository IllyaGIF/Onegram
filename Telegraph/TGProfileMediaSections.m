#import "TGProfileMediaSections.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGCollectionMenuController.h"
#import "TGCollectionMenuSection.h"
#import "TGProfileMediaTabsCollectionItem.h"
#import "TGStoriesSignals.h"
#import "TGStoriesStore.h"
#import "TGStoryItem.h"
#import "TGStoryViewerController.h"
#import "TGStoryComposerController.h"
#import "TGStoriesGridController.h"
#import "TGStarGiftsSignals.h"
#import "TGStarGift.h"
#import "TGStarGiftSheetView.h"
#import "TGStarGiftsGridController.h"
#import "TGStarGiftCatalogController.h"
#import "TGTelegraph.h"

static const int32_t TGProfileMediaPreviewLimit = 12;

@interface TGProfileMediaSections ()
{
    __weak TGCollectionMenuController *_parentController;
    TGProfileMediaTabsCollectionItem *_mediaItem;
    SMetaDisposable *_storiesDisposable;
    SMetaDisposable *_giftsDisposable;
    SMetaDisposable *_peerStoriesDisposable;
    bool _requested;
    bool _storiesLoaded;
    bool _giftsLoaded;
    TGStoryRingState _ringState;
}

@end

static const CGFloat TGProfileMediaSectionSpacing = 22.0f;

@implementation TGProfileMediaSections

- (instancetype)initWithPeerId:(int64_t)peerId parentController:(TGCollectionMenuController *)parentController
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _parentController = parentController;
        _loadsActiveStories = true;
        _storiesDisposable = [[SMetaDisposable alloc] init];
        _giftsDisposable = [[SMetaDisposable alloc] init];
        _peerStoriesDisposable = [[SMetaDisposable alloc] init];

        __weak TGProfileMediaSections *weakSelf = self;
        _mediaItem = [[TGProfileMediaTabsCollectionItem alloc] init];
        _mediaItem.storySelected = ^(NSUInteger index)
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            [strongSelf openPinnedStoryAtIndex:index];
        };
        _mediaItem.showAllStoriesPressed = ^
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            [strongSelf showAllStories];
        };
        _mediaItem.addStoryPressed = ^
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            [strongSelf postStory];
        };
        _mediaItem.giftSelected = ^(NSUInteger index)
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            [strongSelf openGiftAtIndex:index];
        };
        _mediaItem.showAllGiftsPressed = ^
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            [strongSelf showAllGifts];
        };
        _mediaItem.sendGiftPressed = ^
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            if (strongSelf != nil)
                [TGStarGiftCatalogController presentForPeerId:strongSelf->_peerId fromController:strongSelf->_parentController];
        };
        _mediaItem.mediaPressed = ^
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.mediaPressed != nil)
                strongSelf.mediaPressed();
        };
        _mediaItem.heightChanged = ^
        {
            __strong TGProfileMediaSections *strongSelf = weakSelf;
            [strongSelf notifyHeightChanged];
        };
        _mediaSection = [[TGCollectionMenuSection alloc] initWithItems:@[_mediaItem]];
        _mediaSection.insets = UIEdgeInsetsMake(TGProfileMediaSectionSpacing, 0.0f, TGProfileMediaSectionSpacing, 0.0f);

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storiesStoreChanged:) name:TGStoriesStoreDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:TGStoriesStoreDidChangeNotification object:nil];
    [_storiesDisposable dispose];
    [_giftsDisposable dispose];
    [_peerStoriesDisposable dispose];
}

- (void)notifyContentChanged
{
    [_mediaItem reloadContent];
    if (_contentChanged != nil)
        _contentChanged();
    [self notifyHeightChanged];
}

- (void)notifyHeightChanged
{
    if (_heightChanged != nil)
        _heightChanged();
}

- (void)requestIfNeeded
{
    if (_requested || _peerId == 0)
        return;
    _requested = true;
    [self reloadStories];
    [self reloadGifts];
    if (_loadsActiveStories)
        [_peerStoriesDisposable setDisposable:[[[TGStoriesStore instance] peerStoriesSignal:_peerId] startWithNext:nil]];
    [self updateRingState];
}

- (void)reloadStories
{
    __weak TGProfileMediaSections *weakSelf = self;
    [_storiesDisposable setDisposable:[[[TGStoriesSignals pinnedStories:_peerId offsetId:0 limit:TGProfileMediaPreviewLimit] deliverOn:[SQueue mainQueue]] startWithNext:^(TGStoriesPage *page)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        NSMutableArray *stories = [[NSMutableArray alloc] init];
        for (TGStoryItem *item in page.stories)
        {
            if (item.kind != TGStoryItemKindDeleted)
                [stories addObject:item];
        }
        strongSelf->_storiesLoaded = true;
        strongSelf->_mediaItem.stories = stories;
        strongSelf->_mediaItem.storiesTotal = page.totalCount;
        strongSelf->_mediaItem.storiesLoaded = true;
        strongSelf->_mediaItem.storiesFailed = false;
        [strongSelf notifyContentChanged];
    } error:^(__unused id error)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_mediaItem.storiesLoaded = true;
        strongSelf->_mediaItem.storiesFailed = true;
        [strongSelf notifyContentChanged];
    } completed:nil]];
}

- (void)reloadGifts
{
    __weak TGProfileMediaSections *weakSelf = self;
    [_giftsDisposable setDisposable:[[[TGStarGiftsSignals savedGifts:_peerId offset:nil limit:TGProfileMediaPreviewLimit] deliverOn:[SQueue mainQueue]] startWithNext:^(TGSavedStarGiftsPage *page)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_giftsLoaded = true;
        strongSelf->_mediaItem.gifts = page.gifts;
        strongSelf->_mediaItem.giftsTotal = page.totalCount;
        strongSelf->_mediaItem.giftsLoaded = true;
        strongSelf->_mediaItem.giftsFailed = false;
        [strongSelf notifyContentChanged];
    } error:^(__unused id error)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_mediaItem.giftsLoaded = true;
        strongSelf->_mediaItem.giftsFailed = true;
        [strongSelf notifyContentChanged];
    } completed:nil]];
}

- (bool)updateSectionsEnabled:(bool)enabled afterSectionIndex:(NSUInteger)anchorIndex
{
    TGCollectionMenuController *parentController = _parentController;
    if (parentController == nil)
        return false;
    if (enabled)
        [self requestIfNeeded];
    _mediaItem.showsAddTile = _canPostStories;
    _mediaItem.showsSendTile = _canReceiveGifts;
    _mediaItem.showsMediaTab = _showsMediaTab;

    bool changed = false;
    NSUInteger sectionIndex = [parentController indexForSection:_mediaSection];
    if (enabled && sectionIndex == NSNotFound)
    {
        [parentController.menuSections insertSection:_mediaSection atIndex:MIN(anchorIndex + 1, parentController.menuSections.sections.count)];
        changed = true;
    }
    else if (!enabled && sectionIndex != NSNotFound)
    {
        [parentController.menuSections deleteSection:sectionIndex];
        changed = true;
    }
    sectionIndex = [parentController indexForSection:_mediaSection];
    if (sectionIndex != NSNotFound)
    {
        CGFloat precedingSpacing = 0.0f;
        NSArray *sections = parentController.menuSections.sections;
        for (NSInteger index = (NSInteger)sectionIndex - 1; index >= 0; index--)
        {
            TGCollectionMenuSection *section = sections[(NSUInteger)index];
            precedingSpacing += section.insets.bottom;
            if (section.items.count != 0)
                break;
            precedingSpacing += section.insets.top;
        }
        UIEdgeInsets insets = _mediaSection.insets;
        insets.top = MAX(0.0f, TGProfileMediaSectionSpacing - precedingSpacing);
        _mediaSection.insets = insets;
    }
    [_mediaItem reloadContent];
    return changed;
}

- (void)storiesStoreChanged:(NSNotification *)__unused notification
{
    [self updateRingState];
}

- (void)updateRingState
{
    TGStoryRingState state = TGStoryRingStateNone;
    TGPeerStories *peerStories = [[TGStoriesStore instance] peerStoriesForPeerId:_peerId];
    if (peerStories.stories.count != 0)
        state = [peerStories hasUnread] && _peerId != TGTelegraphInstance.clientUserId ? TGStoryRingStateUnread : TGStoryRingStateRead;
    if (state == _ringState)
        return;
    _ringState = state;
    if (_storyRingChanged != nil)
        _storyRingChanged(state);
}

- (TGStoryRingState)storyRingState
{
    return _ringState;
}

- (bool)hasActiveStories
{
    return [[TGStoriesStore instance] peerStoriesForPeerId:_peerId].stories.count != 0;
}

- (void)openActiveStories
{
    [TGStoryViewerController presentActiveStoriesForPeerId:_peerId fromController:_parentController];
}

- (void)openPinnedStoryAtIndex:(NSUInteger)index
{
    NSArray *stories = _mediaItem.stories;
    TGCollectionMenuController *parentController = _parentController;
    if (index >= stories.count || parentController == nil)
        return;
    TGPeerStories *peerStories = [[TGPeerStories alloc] initWithPeerId:_peerId maxReadId:INT32_MAX stories:stories];
    TGStoryViewerController *viewer = [[TGStoryViewerController alloc] initWithPeerStories:@[peerStories] peerIndex:0 storyIndex:index];
    __weak TGProfileMediaSections *weakSelf = self;
    viewer.storiesDeleted = ^(__unused int64_t peerId, __unused NSArray *storyIds)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        [strongSelf reloadStories];
    };
    viewer.storyPinnedChanged = ^(__unused int64_t peerId, __unused int32_t storyId, __unused bool pinned)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        [strongSelf reloadStories];
    };
    [parentController presentViewController:viewer animated:true completion:nil];
}

- (void)showAllStories
{
    TGStoriesGridController *controller = [[TGStoriesGridController alloc] initWithPeerId:_peerId archive:false];
    __weak TGProfileMediaSections *weakSelf = self;
    controller.storiesChanged = ^
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        [strongSelf reloadStories];
    };
    [_parentController.navigationController pushViewController:controller animated:true];
}

- (void)postStory
{
    __weak TGProfileMediaSections *weakSelf = self;
    [TGStoryComposerController presentFromController:_parentController completion:^(__unused NSArray *stories)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        [strongSelf reloadStories];
    }];
}

- (void)openGiftAtIndex:(NSUInteger)index
{
    NSArray *gifts = _mediaItem.gifts;
    if (index >= gifts.count)
        return;
    TGStarGiftSheetView *sheet = [[TGStarGiftSheetView alloc] initWithSavedGift:[gifts objectAtIndex:index] canManage:_canManageGifts];
    __weak TGProfileMediaSections *weakSelf = self;
    void (^reload)(TGSavedStarGift *) = ^(__unused TGSavedStarGift *gift)
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        [strongSelf reloadGifts];
    };
    sheet.giftUpdated = reload;
    sheet.giftRemoved = reload;
    [sheet presentFromController:_parentController];
}

- (void)showAllGifts
{
    TGStarGiftsGridController *controller = [[TGStarGiftsGridController alloc] initWithPeerId:_peerId canManage:_canManageGifts];
    __weak TGProfileMediaSections *weakSelf = self;
    controller.giftsChanged = ^
    {
        __strong TGProfileMediaSections *strongSelf = weakSelf;
        [strongSelf reloadGifts];
    };
    [_parentController.navigationController pushViewController:controller animated:true];
}

@end
