#import "TGDialogFilterPeersController.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"
#import "TGAppDelegate.h"
#import "TGRootController.h"
#import "TGDialogListController.h"
#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGDialogFilter.h"
#import "TGDialogFilterSignals.h"
#import "TGDialogFiltersController.h"
#import "TGDialogFilterCategoryCollectionItem.h"
#import "TGGroupInfoUserCollectionItem.h"
#import "TGHeaderCollectionItem.h"
#import "TGCommentCollectionItem.h"
#import "TGCollectionMultilineInputItem.h"

@interface TGDialogFilterPeersController ()
{
    TGDialogFilterPeersMode _mode;
    int32_t _categories;
    NSMutableArray *_selectedPeerIds;
    NSUInteger _limit;
    NSString *_query;

    NSDictionary *_conversations;
    NSArray *_allPeerIds;

    TGCollectionMenuSection *_searchSection;
    TGCollectionMenuSection *_categoriesSection;
    TGCollectionMenuSection *_peersSection;
    NSMutableDictionary *_peerItems;
    NSMutableDictionary *_categoryItems;
}

@end

@implementation TGDialogFilterPeersController

+ (NSDictionary *)conversationsById
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    for (TGConversation *conversation in [TGAppDelegateInstance.rootController.dialogListController dialogFilterConversations])
    {
        if ([conversation isKindOfClass:[TGConversation class]] && conversation.conversationId != 0)
            result[@(conversation.conversationId)] = conversation;
    }
    return result;
}

+ (TGConversation *)conversationForPeerId:(int64_t)peerId conversations:(NSDictionary *)conversations
{
    TGConversation *conversation = conversations[@(peerId)];
    if (conversation == nil && !TGPeerIdIsUser(peerId))
        conversation = [TGDatabaseInstance() loadConversationWithId:peerId];
    return conversation;
}

+ (NSString *)titleForPeerId:(int64_t)peerId conversations:(NSDictionary *)conversations
{
    if (peerId == TGTelegraphInstance.clientUserId)
        return TGLocalized(@"DialogList.SavedMessages");
    if (TGPeerIdIsUser(peerId))
        return [TGDatabaseInstance() loadUser:peerId].displayName ?: @"";
    return [self conversationForPeerId:peerId conversations:conversations].chatTitle ?: @"";
}

+ (bool)peerIdIsShareable:(int64_t)peerId conversations:(NSDictionary *)conversations
{
    if (TGPeerIdIsUser(peerId) || peerId == 0)
        return false;
    TGConversation *conversation = [self conversationForPeerId:peerId conversations:conversations];
    if (conversation == nil)
        return TGPeerIdIsChannel(peerId);
    return !conversation.isEncrypted && !conversation.leftChat && !conversation.kickedFromChat && !conversation.isDeleted;
}

+ (TGGroupInfoUserCollectionItem *)itemForPeerId:(int64_t)peerId conversations:(NSDictionary *)conversations
{
    TGGroupInfoUserCollectionItem *item = [[TGGroupInfoUserCollectionItem alloc] init];
    item.deselectAutomatically = true;
    item.requiresFullSeparator = false;
    if (TGPeerIdIsUser(peerId))
    {
        TGUser *user = [TGDatabaseInstance() loadUser:peerId];
        if (user == nil)
            return nil;
        item.user = user;
        if (peerId == TGTelegraphInstance.clientUserId)
            item.customStatus = TGLocalized(@"DialogList.SavedMessages");
        else if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
            item.customStatus = TGLocalized(@"DialogFilters.PeerBot");
        return item;
    }
    TGConversation *conversation = [self conversationForPeerId:peerId conversations:conversations];
    if (conversation == nil)
        return nil;
    item.conversation = conversation;
    if (conversation.chatParticipantCount <= 0)
        item.customStatus = (conversation.isChannel && !conversation.isChannelGroup) ? TGLocalized(@"DialogFilters.PeerChannel") : TGLocalized(@"DialogFilters.PeerGroup");
    return item;
}

- (instancetype)initWithMode:(TGDialogFilterPeersMode)mode categories:(int32_t)categories peerIds:(NSArray *)peerIds limit:(NSUInteger)limit
{
    self = [super init];
    if (self != nil)
    {
        _mode = mode;
        _categories = categories;
        _selectedPeerIds = [[NSMutableArray alloc] initWithArray:peerIds ?: @[]];
        _limit = limit == 0 ? NSUIntegerMax : limit;
        _peerItems = [[NSMutableDictionary alloc] init];
        _categoryItems = [[NSMutableDictionary alloc] init];

        self.title = mode == TGDialogFilterPeersModeExclude ? TGLocalized(@"DialogFilters.ExcludeChatsTitle") : TGLocalized(@"DialogFilters.IncludeChatsTitle");
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelPressed)] animated:false];
        [self setRightBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(donePressed)] animated:false];

        __weak TGDialogFilterPeersController *weakSelf = self;
        TGCollectionMultilineInputItem *searchItem = [[TGCollectionMultilineInputItem alloc] init];
        searchItem.placeholder = TGLocalized(@"Common.Search");
        searchItem.disallowNewLines = true;
        searchItem.maxLength = 64;
        searchItem.returnKeyType = UIReturnKeySearch;
        searchItem.textChanged = ^(NSString *text)
        {
            __strong TGDialogFilterPeersController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setQuery:text];
        };
        _searchSection = [[TGCollectionMenuSection alloc] initWithItems:@[searchItem]];
        _searchSection.insets = UIEdgeInsetsMake(16.0f, 0.0f, 0.0f, 0.0f);
        [self.menuSections addSection:_searchSection];

        if (mode != TGDialogFilterPeersModeChatlist)
        {
            NSMutableArray *items = [[NSMutableArray alloc] init];
            [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.ChatTypes")]];
            NSArray *categories = mode == TGDialogFilterPeersModeExclude ? [TGDialogFilter excludeCategories] : [TGDialogFilter includeCategories];
            for (NSNumber *category in categories)
            {
                TGDialogFilterCategoryCollectionItem *item = [[TGDialogFilterCategoryCollectionItem alloc] initWithCategory:category.intValue];
                item.displayCheck = true;
                item.checkIsOn = (_categories & category.intValue) != 0;
                item.pressed = ^
                {
                    __strong TGDialogFilterPeersController *strongSelf = weakSelf;
                    if (strongSelf != nil)
                        [strongSelf toggleCategory:category.intValue];
                };
                _categoryItems[category] = item;
                [items addObject:item];
            }
            _categoriesSection = [[TGCollectionMenuSection alloc] initWithItems:items];
            [self.menuSections addSection:_categoriesSection];
        }

        _peersSection = [[TGCollectionMenuSection alloc] initWithItems:@[]];
        [self.menuSections addSection:_peersSection];

        [self loadPeers];
    }
    return self;
}

- (void)loadPeers
{
    _conversations = [TGDialogFilterPeersController conversationsById];
    NSMutableArray *peerIds = [[NSMutableArray alloc] init];
    NSMutableSet *seen = [[NSMutableSet alloc] init];
    for (NSNumber *peerId in _selectedPeerIds)
    {
        if (![seen containsObject:peerId])
        {
            [seen addObject:peerId];
            [peerIds addObject:peerId];
        }
    }
    for (TGConversation *conversation in [TGAppDelegateInstance.rootController.dialogListController dialogFilterConversations])
    {
        if (![conversation isKindOfClass:[TGConversation class]] || conversation.isEncrypted || conversation.isBroadcast || TGPeerIdIsAd(conversation.conversationId) || conversation.conversationId == 0)
            continue;
        NSNumber *peerId = @(conversation.conversationId);
        if ([seen containsObject:peerId])
            continue;
        if (_mode == TGDialogFilterPeersModeChatlist && TGPeerIdIsUser(conversation.conversationId))
            continue;
        [seen addObject:peerId];
        [peerIds addObject:peerId];
    }
    _allPeerIds = peerIds;
    [self rebuildPeers];
}

- (void)setQuery:(NSString *)query
{
    NSString *trimmed = [[query ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    if ([trimmed isEqualToString:_query ?: @""])
        return;
    _query = trimmed;
    [self rebuildPeers];
}

- (TGGroupInfoUserCollectionItem *)peerItemForPeerId:(NSNumber *)peerId
{
    TGGroupInfoUserCollectionItem *item = _peerItems[peerId];
    if (item != nil)
        return item;
    item = [TGDialogFilterPeersController itemForPeerId:peerId.longLongValue conversations:_conversations];
    if (item == nil)
        return nil;
    item.displayCheck = true;
    __weak TGDialogFilterPeersController *weakSelf = self;
    int64_t peerIdValue = peerId.longLongValue;
    item.pressed = ^
    {
        __strong TGDialogFilterPeersController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf togglePeerId:peerIdValue];
    };
    _peerItems[peerId] = item;
    return item;
}

- (void)rebuildPeers
{
    NSMutableArray *items = [[NSMutableArray alloc] init];
    [items addObject:[[TGHeaderCollectionItem alloc] initWithTitle:TGLocalized(@"DialogFilters.Chats")]];
    for (NSNumber *peerId in _allPeerIds)
    {
        if (_query.length != 0)
        {
            NSString *title = [[TGDialogFilterPeersController titleForPeerId:peerId.longLongValue conversations:_conversations] lowercaseString];
            if ([title rangeOfString:_query].location == NSNotFound)
                continue;
        }
        TGGroupInfoUserCollectionItem *item = [self peerItemForPeerId:peerId];
        if (item == nil)
            continue;
        item.checkIsOn = [_selectedPeerIds containsObject:peerId];
        [items addObject:item];
    }
    if (items.count == 1)
        [items addObject:[[TGCommentCollectionItem alloc] initWithText:TGLocalized(@"DialogFilters.NoChatsFound")]];
    [_peersSection replaceItems:items];

    NSUInteger categoriesIndex = _categoriesSection == nil ? NSNotFound : [self indexForSection:_categoriesSection];
    if (_categoriesSection != nil)
    {
        if (_query.length != 0 && categoriesIndex != NSNotFound)
            [self.menuSections deleteSectionByReference:_categoriesSection];
        else if (_query.length == 0 && categoriesIndex == NSNotFound)
            [self.menuSections insertSection:_categoriesSection atIndex:[self indexForSection:_searchSection] + 1];
    }
    [self.collectionView reloadData];
    [self updateTitle];
}

- (void)updateTitle
{
    if (_mode == TGDialogFilterPeersModeExclude || _limit == NSUIntegerMax)
        return;
    NSString *base = TGLocalized(@"DialogFilters.IncludeChatsTitle");
    self.title = _selectedPeerIds.count == 0 ? base : [NSString stringWithFormat:@"%@ (%d/%d)", base, (int)_selectedPeerIds.count, (int)_limit];
}

- (void)toggleCategory:(int32_t)category
{
    _categories ^= category;
    ((TGDialogFilterCategoryCollectionItem *)_categoryItems[@(category)]).checkIsOn = (_categories & category) != 0;
}

- (void)togglePeerId:(int64_t)peerId
{
    NSNumber *key = @(peerId);
    if ([_selectedPeerIds containsObject:key])
        [_selectedPeerIds removeObject:key];
    else
    {
        if (_selectedPeerIds.count >= _limit)
        {
            [TGDialogFiltersController presentError:_mode == TGDialogFilterPeersModeExclude ? @"FILTER_EXCLUDE_TOO_MUCH" : @"FILTER_INCLUDE_TOO_MUCH"];
            return;
        }
        [_selectedPeerIds addObject:key];
    }
    ((TGGroupInfoUserCollectionItem *)_peerItems[key]).checkIsOn = [_selectedPeerIds containsObject:key];
    [self updateTitle];
}

- (void)cancelPressed
{
    [self.view endEditing:true];
    [self.navigationController popViewControllerAnimated:true];
}

- (void)donePressed
{
    [self.view endEditing:true];
    if (_completion)
        _completion(_categories, [_selectedPeerIds copy]);
    [self.navigationController popViewControllerAnimated:true];
}

@end
