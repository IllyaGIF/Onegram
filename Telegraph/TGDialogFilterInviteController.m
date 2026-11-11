#import "TGDialogFilterInviteController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGHacks.h"

#import "TGPresentation.h"
#import "TGDialogFilter.h"
#import "TGDialogFilterSignals.h"
#import "TGDialogFiltersController.h"
#import "TGDialogFilterPeersController.h"
#import "TGDialogFilterCollectionItem.h"
#import "TGGroupInfoUserCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGButtonCollectionItem.h"
#import "TGVariantCollectionItem.h"
#import "TGCustomAlertView.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"

@interface TGDialogFilterInviteController ()
{
    TGDialogFilterInvite *_invite;
    TGDialogFilter *_filter;
    NSDictionary *_conversations;
    NSArray *_availablePeerIds;
    NSMutableArray *_selectedPeerIds;

    TGDialogFilterCollectionItem *_linkItem;
    TGButtonCollectionItem *_shareItem;
    TGVariantCollectionItem *_nameItem;
    TGCollectionMenuSection *_peersSection;
    NSMutableDictionary *_peerItems;

    SMetaDisposable *_actionDisposable;
}

@end

@implementation TGDialogFilterInviteController

- (instancetype)initWithInvite:(TGDialogFilterInvite *)invite filter:(TGDialogFilter *)filter
{
    self = [super init];
    if (self != nil)
    {
        _invite = invite;
        _filter = [filter copy];
        _conversations = [TGDialogFilterPeersController conversationsById];
        _selectedPeerIds = [[NSMutableArray alloc] initWithArray:invite.peerIds ?: @[]];
        _peerItems = [[NSMutableDictionary alloc] init];
        _actionDisposable = [[SMetaDisposable alloc] init];

        NSMutableArray *available = [[NSMutableArray alloc] init];
        for (NSNumber *peerId in [[filter includedPeerIds] arrayByAddingObjectsFromArray:invite.peerIds ?: @[]])
        {
            if (![available containsObject:peerId] && [TGDialogFilterPeersController peerIdIsShareable:peerId.longLongValue conversations:_conversations])
                [available addObject:peerId];
        }
        _availablePeerIds = available;

        self.title = TGLocalized(@"DialogFilters.InviteTitle");

        _linkItem = [[TGDialogFilterCollectionItem alloc] initWithTitle:@"" subtitle:nil icon:nil];
        __weak TGDialogFilterInviteController *weakSelf = self;
        _linkItem.pressed = ^
        {
            __strong TGDialogFilterInviteController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf copyPressed];
        };
        TGButtonCollectionItem *copyItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.CopyLink") action:@selector(copyPressed)];
        copyItem.deselectAutomatically = true;
        _shareItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.ShareLink") action:@selector(sharePressed)];
        _shareItem.deselectAutomatically = true;
        TGCollectionMenuSection *linkSection = [[TGCollectionMenuSection alloc] initWithItems:@[[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.InviteLink")], _linkItem, copyItem, _shareItem]];
        linkSection.insets = UIEdgeInsetsMake(24.0f, 0.0f, 16.0f, 0.0f);
        [self.menuSections addSection:linkSection];

        _nameItem = [[TGVariantCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.InviteName") action:@selector(namePressed)];
        _nameItem.deselectAutomatically = true;
        [self.menuSections addSection:[[TGCollectionMenuSection alloc] initWithItems:@[_nameItem, [[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"DialogFilters.InviteNameInfo")]]]];

        _peersSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_peersSection];

        TGButtonCollectionItem *deleteItem = [[TGButtonCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.DeleteInvite") action:@selector(deletePressed)];
        deleteItem.titleColor = self.presentation.pallete.collectionMenuDestructiveColor;
        deleteItem.deselectAutomatically = true;
        TGCollectionMenuSection *deleteSection = [[TGCollectionMenuSection alloc] initWithItems:@[deleteItem]];
        deleteSection.insets = UIEdgeInsetsMake(8.0f, 0.0f, 32.0f, 0.0f);
        [self.menuSections addSection:deleteSection];

        [self updateInvite];
        [self rebuildPeers];
    }
    return self;
}

- (void)dealloc
{
    [_actionDisposable dispose];
}

- (void)updateInvite
{
    _linkItem.title = [_invite.url stringByReplacingOccurrencesOfString:@"https://" withString:@""];
    _nameItem.variant = _invite.title.length != 0 ? _invite.title : TGLocalized(@"DialogFilters.InviteNameEmpty");
    [self updateSaveButton];
}

- (bool)selectionChanged
{
    return ![[NSSet setWithArray:_selectedPeerIds] isEqualToSet:[NSSet setWithArray:_invite.peerIds ?: @[]]];
}

- (void)updateSaveButton
{
    if ([self selectionChanged])
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"DialogFilters.Save") style:UIBarButtonItemStyleDone target:self action:@selector(savePressed)] animated:true];
    else
        [self setRightBarButtonItem:nil animated:true];
}

- (void)rebuildPeers
{
    __weak TGDialogFilterInviteController *weakSelf = self;
    NSMutableArray *items = [[NSMutableArray alloc] init];
    [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:[effectiveLocalization() getPluralized:@"DialogFilters.InviteChatsHeader" count:(int32_t)_selectedPeerIds.count]]];
    for (NSNumber *peerId in _availablePeerIds)
    {
        TGGroupInfoUserCollectionItem *item = _peerItems[peerId];
        if (item == nil)
        {
            item = [TGDialogFilterPeersController itemForPeerId:peerId.longLongValue conversations:_conversations];
            if (item == nil)
                continue;
            item.displayCheck = true;
            int64_t value = peerId.longLongValue;
            item.pressed = ^
            {
                __strong TGDialogFilterInviteController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf togglePeerId:value];
            };
            _peerItems[peerId] = item;
        }
        item.checkIsOn = [_selectedPeerIds containsObject:peerId];
        [items addObject:item];
    }
    [items addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"DialogFilters.InviteChatsInfo")]];
    [_peersSection replaceItems:items];
    [self.collectionView reloadData];
}

- (void)togglePeerId:(int64_t)peerId
{
    NSNumber *key = @(peerId);
    if ([_selectedPeerIds containsObject:key])
        [_selectedPeerIds removeObject:key];
    else
        [_selectedPeerIds addObject:key];
    [self rebuildPeers];
    [self updateSaveButton];
}

- (void)copyPressed
{
    if (_invite.url.length == 0)
        return;
    [[UIPasteboard generalPasteboard] setString:_invite.url];
    [[[TGProgressWindow alloc] init] dismissWithSuccess];
}

- (void)sharePressed
{
    if (_invite.url.length == 0)
        return;
    if (TGShareItemsViaLegacyPasteboard(@[_invite.url]))
        return;
    UIView *sourceView = nil;
    CGRect sourceRect = CGRectZero;
    if (iosMajorVersion() >= 8 && [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        sourceView = [_shareItem boundView];
        sourceRect = sourceView.bounds;
    }
    OGPlatformPresentActivityItems(self, @[_invite.url], sourceView, sourceRect, nil, UIPopoverArrowDirectionAny, nil);
}

- (void)namePressed
{
    __weak TGDialogFilterInviteController *weakSelf = self;
    [TGCustomAlertView presentTextInputAlertWithTitle:TGLocalized(@"DialogFilters.InviteName") message:nil placeholder:TGLocalized(@"DialogFilters.InviteNamePlaceholder") text:_invite.title keyboardType:UIKeyboardTypeDefault cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"DialogFilters.Save") completionBlock:^(NSString *text)
    {
        __strong TGDialogFilterInviteController *strongSelf = weakSelf;
        if (strongSelf == nil || text == nil)
            return;
        NSString *title = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (title.length > 32)
            title = [title substringToIndex:32];
        [strongSelf saveTitle:title peerIds:nil];
    }];
}

- (void)savePressed
{
    if (_selectedPeerIds.count == 0)
    {
        [TGDialogFiltersController presentError:@"PEERS_LIST_EMPTY"];
        return;
    }
    [self saveTitle:nil peerIds:[_selectedPeerIds copy]];
}

- (void)saveTitle:(NSString *)title peerIds:(NSArray *)peerIds
{
    __weak TGDialogFilterInviteController *weakSelf = self;
    [_actionDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals editInvite:_invite filter:_filter title:title peerIds:peerIds]] startWithNext:^(TGDialogFilterInvite *invite)
    {
        __strong TGDialogFilterInviteController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        strongSelf->_invite = invite;
        strongSelf->_selectedPeerIds = [[NSMutableArray alloc] initWithArray:invite.peerIds ?: @[]];
        [strongSelf updateInvite];
        [strongSelf rebuildPeers];
    } error:^(id error)
    {
        [TGDialogFiltersController presentError:error];
    } completed:nil]];
}

- (void)deletePressed
{
    __weak TGDialogFilterInviteController *weakSelf = self;
    [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"DialogFilters.DeleteInviteInfo") cancelButtonTitle:TGLocalized(@"Common.Cancel") okButtonTitle:TGLocalized(@"Common.Delete") destructive:true completionBlock:^(bool okButtonPressed)
    {
        __strong TGDialogFilterInviteController *strongSelf = weakSelf;
        if (!okButtonPressed || strongSelf == nil)
            return;
        [strongSelf->_actionDisposable setDisposable:[[TGDialogFiltersController signalWithProgress:[TGDialogFilterSignals deleteInvite:strongSelf->_invite filter:strongSelf->_filter]] startWithNext:nil error:^(id error)
        {
            [TGDialogFiltersController presentError:error];
        } completed:^
        {
            __strong TGDialogFilterInviteController *innerSelf = weakSelf;
            if (innerSelf != nil)
                [innerSelf.navigationController popViewControllerAnimated:true];
        }]];
    } disableKeyboardWorkaround:false];
}

@end
