#import "../OnegramRuntime/OGStartupDiagnostics.h"
#import "TGTelegraphDialogListCompanion.h"
#import "TGDialogListRequestBuilder.h"
#import "TGCommon.h"
#import "../OnegramPlatform/OGPlatformUIKit.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"
#import "TGModernConversationController.h"
#import "TGGenericModernConversationCompanion.h"

#import "TGDialogListController.h"
#import "TGDialogListCell.h"

#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphListNode.h"

#import "TGDatabase.h"
#import "TGDialogListItem.h"

#import "TGInterfaceManager.h"
#import "TGInterfaceAssets.h"

#import "TGSelectContactController.h"

#import "TGTelegramNetworking.h"
#import "TGTelegraph.h"

#import "TGForwardTargetController.h"

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGModernConversationCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGProgressWindow.h"

#include <map>
#include <set>

#import <libkern/OSAtomic.h>

#import "TGCustomAlertView.h"

#import "TGChannelManagementSignals.h"
#import "TGFeedManagementSignals.h"

#import "TGCreateGroupController.h"

#import "TGLiveLocationSignals.h"
#import "TGLiveLocationManager.h"

#import "TGLegacyComponentsContext.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMenuSheetController.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLocationLiveSessionItemView.h"
#import "TGLiveLocationTitlePanel.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLocationViewController.h"

#import "TGPresentation.h"

#import "TGAdSignals.h"
#import "../OnegramRuntime/OGRemoteClock.h"

static void OGCompatPruneItems(NSMutableArray *items, bool (^shouldRemove)(id<TGDialogListItem> item))
{
    for (NSInteger index = (NSInteger)items.count - 1; index >= 0; index--)
    {
        if (shouldRemove(items[(NSUInteger)index]))
            [items removeObjectAtIndex:(NSUInteger)index];
    }
}

static void OGCompatDropConversation(NSMutableArray *list, int64_t conversationId)
{
    OGCompatPruneItems(list, ^bool(id<TGDialogListItem> item) { return item.conversationId == conversationId; });
}

static int32_t OGCompatItemPinnedDate(id<TGDialogListItem> item)
{
    return [item isKindOfClass:[TGConversation class]] ? ((TGConversation *)item).pinnedDate : 0;
}

static NSComparisonResult OGCompatDialogOrderPinnedFirst(id<TGDialogListItem> obj1, id<TGDialogListItem> obj2)
{
    if (TGPeerIdIsAd(obj1.conversationId))
        return NSOrderedAscending;
    if (TGPeerIdIsAd(obj2.conversationId))
        return NSOrderedDescending;
    
    int32_t pinnedDate1 = OGCompatItemPinnedDate(obj1);
    int32_t pinnedDate2 = OGCompatItemPinnedDate(obj2);
    if (pinnedDate1 != pinnedDate2 && (pinnedDate1 == 0 || pinnedDate2 == 0))
        return pinnedDate1 == 0 ? NSOrderedDescending : NSOrderedAscending;
    if (pinnedDate1 != pinnedDate2)
        return pinnedDate1 > pinnedDate2 ? NSOrderedAscending : NSOrderedDescending;
    
    int recencyA = (int)obj1.date;
    int recencyB = (int)obj2.date;
    if (recencyA != recencyB)
        return recencyA > recencyB ? NSOrderedAscending : NSOrderedDescending;
    if (obj1.conversationId != obj2.conversationId)
        return obj1.conversationId < obj2.conversationId ? NSOrderedDescending : NSOrderedAscending;
    return NSOrderedSame;
}

@interface TGTelegraphDialogListCompanion ()
{
    volatile int32_t _conversationsUpdateTaskId;
    
    TGProgressWindow *_progressWindow;
    
    SMetaDisposable *_stateDisposable;
    
    bool _canLoadMore;
    NSMutableSet *_pagedConversationIds;
    SMetaDisposable *_liveLocationDisposable;
    TGLiveLocationTitlePanel *_liveLocationPanel;
    
    SMetaDisposable *_adItemDisposable;
    bool _loadedAd;
    
    SMetaDisposable *_unreadDialogsDisposable;

    TGDialogListSynchronizationNode *_lastSynchronizationNode;
    bool _ogCompatFolderPreloadActive;
    bool _ogCompatFolderPreloadRequestInFlight;
    bool _ogCompatFolderPreloadResumeScheduled;
    bool _ogCompatFolderPreloadRetryScheduled;
    bool _ogCompatFolderPreloadArchiveStage;
    int _ogCompatFolderPreloadRetryCount;
    bool _ogCompatEagerDialogPageScheduled;
    NSMutableSet *_ogCompatFolderOnlyHydrationPeerIds;
    bool _ogCompatInitialWatchersDeferred;
}

@property (nonatomic, strong) NSMutableArray *conversationList;
@property (nonatomic, strong) NSMutableArray *archivedConversations;
@property (nonatomic, strong) TGConversation *adConversation;

@property (nonatomic, strong) NSString *searchString;

@property (nonatomic) TGDialogListState state;

@end

@implementation TGTelegraphDialogListCompanion

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _conversationList = [[NSMutableArray alloc] init];
        _pagedConversationIds = [[NSMutableSet alloc] init];
        _archivedConversations = [[NSMutableArray alloc] init];
        _ogCompatFolderOnlyHydrationPeerIds = [[NSMutableSet alloc] init];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        
        self.showSecretInForwardMode = true;
        self.showListEditingControl = true;

        if (devicePerformanceClass() == TGPerformanceClassConstrained)
        {
            _ogCompatInitialWatchersDeferred = true;
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                [ActionStageInstance() watchForGenericPath:@"/tg/dialoglist/@" watcher:self];
            }];
        }
        else
            [self resetWatchedNodePaths];
        
        _stateDisposable = [[SMetaDisposable alloc] init];
        _liveLocationDisposable = [[SMetaDisposable alloc] init];
        _adItemDisposable = [[SMetaDisposable alloc] init];
        _unreadDialogsDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
    [_liveLocationDisposable dispose];
    [_stateDisposable dispose];
    [_adItemDisposable dispose];
    
    TGProgressWindow *progressWindow = _progressWindow;
    TGDispatchOnMainThread(^
    {
        [progressWindow dismiss:false];
    });
}

- (id<TGDialogListCellAssetsSource>)dialogListCellAssetsSource
{
    return [TGInterfaceAssets instance];
}

- (void)dialogListReady
{
    [[TGInterfaceManager instance] preload];
    
    SSignal *liveLocationsSignal = [[TGTelegraphInstance.liveLocationManager sessions] map:^id(NSArray *sessions)
    {
        NSMutableArray *liveLocations = [[NSMutableArray alloc] init];
        
        for (TGLiveLocationSession *session in sessions)
        {
            id peer = nil;
            if (TGPeerIdIsUser(session.peerId))
                peer = [TGDatabaseInstance() loadUser:session.peerId];
            else
                peer = [TGDatabaseInstance() loadConversationWithId:session.peerId];
            
            TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:session.messageId peerId:session.peerId];
            [liveLocations addObject:[[TGLiveLocation alloc] initWithMessage:message peer:peer]];
        }
        
        return liveLocations;
    }];
    
    __weak TGTelegraphDialogListCompanion *weakSelf = self;
    [_liveLocationDisposable setDisposable:[[liveLocationsSignal deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
    {
        __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf setLiveLocations:next];
    }]];
    
}

- (void)setLiveLocations:(NSArray *)liveLocations
{
    __weak TGTelegraphDialogListCompanion *weakSelf = self;
    if (liveLocations.count > 0)
    {
        if (_liveLocationPanel == nil)
            _liveLocationPanel = [[TGLiveLocationTitlePanel alloc] init];
        
        _liveLocationPanel.tapped = ^
        {
            __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf presentLiveLocationsMenu:liveLocations];
        };
        _liveLocationPanel.closed = ^
        {
            __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf presentLiveLocationsMenu:liveLocations];
        };
    
        [_liveLocationPanel setSessions:liveLocations];
        [self.dialogListController setCurrentTitlePanel:_liveLocationPanel];
    }
    else
    {
        [self.dialogListController setCurrentTitlePanel:nil];
    }
}

- (void)resetWatchedNodePaths
{
    
    [ActionStageInstance() dispatchOnStageQueue:^
     {
         
         
         [ActionStageInstance() removeWatcher:self];

        [ActionStageInstance() watchForPath:@"/tg/conversations" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/broadcastConversations" watcher:self];
        [ActionStageInstance() watchForGenericPath:@"/tg/dialoglist/@" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/userdatachanges" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/unreadChatsCount" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/peerUnseenMentionCounts" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/conversation/*/typing" watcher:self];
        [ActionStageInstance() watchForPath:@"/tg/contactlist" watcher:self];
        [ActionStageInstance() watchForPath:@"/databasePasswordChanged" watcher:self];
        [ActionStageInstance() watchForGenericPath:@"/tg/conversationsGrouped/@" watcher:self];
        
        [ActionStageInstance() watchForGenericPath:@"/tg/peerSettings/@" watcher:self];
        
        [ActionStageInstance() watchForPath:@"/tg/service/synchronizationstate" watcher:self];
        [ActionStageInstance() requestActor:@"/tg/service/synchronizationstate" options:nil watcher:self];
         
         
         [TGDatabaseInstance() transactionCalculateUnreadChats];
        
        [_adItemDisposable setDisposable:nil];
        _loadedAd = false;
    }];
}

- (void)clearData
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [_conversationList removeAllObjects];
        [_archivedConversations removeAllObjects];
        _adConversation = nil;
        
        [self resetWatchedNodePaths];
        
        _canLoadMore = false;
        
        TGDispatchOnMainThread(^
        {
            TGDialogListController *controller = self.dialogListController;
            if (controller != nil)
            {
                controller.canLoadMore = false;
                [controller dialogListFullyReloaded:[[NSArray alloc] init]];
                [controller resetState];
            }
        });
    }];
}

- (void)composeMessageAndOpenSearch:(bool)openSearch
{
    if ([TGAppDelegateInstance isDisplayingPasscodeWindow])
        return;
    
    TGDialogListController *controller = self.dialogListController;
    [controller selectConversationWithId:0];
    
    TGSelectContactController *selectController = [[TGSelectContactController alloc] initWithCreateGroup:false createEncrypted:false createBroadcast:false createChannel:false inviteToChannel:false showLink:false];
    selectController.shouldOpenSearch = openSearch;
    [TGAppDelegateInstance.rootController pushContentController:selectController];
}

- (void)navigateToBroadcastLists
{
    TGCreateGroupController *controller = [[TGCreateGroupController alloc] initWithCreateChannel:true createChannelGroup:false];
    [TGAppDelegateInstance.rootController pushContentController:controller];
}

- (void)navigateToNewGroup
{
    __autoreleasing NSString *disabledMessage = nil;
    if (![TGApplicationFeatures isGroupCreationEnabled:&disabledMessage])
    {
        [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"FeatureDisabled.Oops") message:disabledMessage cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
        return;
    }
    
    TGDialogListController *controller = self.dialogListController;
    [controller selectConversationWithId:0];
    
    TGSelectContactController *selectController = [[TGSelectContactController alloc] initWithCreateGroup:true createEncrypted:false createBroadcast:false createChannel:false inviteToChannel:false showLink:false];
    [TGAppDelegateInstance.rootController pushContentController:selectController];
}

- (void)conversationSelected:(TGConversation *)conversation
{    
    if (self.forwardMode || self.privacyMode || self.showPrivateOnly || self.showGroupsAndChannelsOnly)
    {
        [_conversatioSelectedWatcher requestAction:@"conversationSelected" options:[[NSDictionary alloc] initWithObjectsAndKeys:conversation, @"conversation", nil]];
    }
    else
    {
        if ([conversation isKindOfClass:[TGFeed class]])
        {
            [[TGInterfaceManager instance] navigateToChannelsFeed:((TGFeed *)conversation).fid animated:true];
        }
        else
        {
            if (!conversation.isBroadcast)
            {
                int64_t conversationId = conversation.conversationId;
                if (TGPeerIdIsChannel(conversationId) && conversation.kind == TGConversationKindTemporaryChannel) {
                    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
                    [progressWindow showWithDelay:0.1];
                    [[[[TGChannelManagementSignals preloadedChannel:conversationId] deliverOn:[SQueue mainQueue]] onDispose:^{
                        TGDispatchOnMainThread(^{
                            [progressWindow dismiss:true];
                        });
                    }] startWithNext:nil completed:^{
                        [[TGInterfaceManager instance] navigateToConversationWithId:conversationId conversation:conversation performActions:nil atMessage:nil clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:true animated:true];
                    }];
                } else {
                    [[TGInterfaceManager instance] navigateToConversationWithId:conversationId conversation:conversation performActions:nil atMessage:nil clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:true animated:true];
                }
            }
        }
    }
}

- (void)searchResultSelectedConversation:(TGConversation *)conversation
{
    [self conversationSelected:conversation];
}

- (void)searchResultSelectedConversation:(TGConversation *)conversation atMessageId:(int)messageId
{
    if (!self.forwardMode && !self.privacyMode)
    {
        if ([TGDatabaseInstance() loadMessageWithMid:messageId peerId:conversation.conversationId] != nil)
        {
            int64_t conversationId = conversation.conversationId;
            [[TGInterfaceManager instance] navigateToConversationWithId:conversationId conversation:conversation performActions:nil atMessage:@{@"mid": @(messageId)} clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
        }
        else
        {
            _progressWindow = [[TGProgressWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            [_progressWindow show:true];
            
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/loadConversationAndMessageForSearch/(%" PRId64 ", %" PRId32 ")", conversation.conversationId, messageId] options:@{@"peerId": @(conversation.conversationId), @"accessHash": @(conversation.accessHash), @"messageId": @(messageId)} flags:0 watcher:self];
        }
    }
}

- (void)searchResultSelectedMessage:(TGMessage *)__unused message
{
    
}

- (bool)shouldDisplayEmptyListPlaceholder
{
    return TGTelegraphInstance.clientUserId != 0;
}

- (void)wakeUp
{
}

- (void)resetLocalization
{
    
}

- (int64_t)openedConversationId
{
    UIViewController *topViewController = [TGAppDelegateInstance.rootController.viewControllers lastObject];

    if ([topViewController isKindOfClass:[TGModernConversationController class]])
    {
        return ((TGGenericModernConversationCompanion *)((TGModernConversationController *)(topViewController)).companion).conversationId;
    }
    
    return 0;
}

- (void)scrollToNextUnreadChat {
    [[self.dialogListController.atTopSignal take:1] startWithNext:^(NSNumber *atTop)
    {
        if (atTop.boolValue)
        {
            const int unreadScanLimit = 400;
            [TGDatabaseInstance() loadUnreadConversationListFromDate:0 limit:unreadScanLimit completion:^(NSArray *result) {
                TGDispatchOnMainThread(^{
                    TGConversation *firstUnread = [result firstObject];
                    int64_t firstUnreadId = firstUnread.conversationId;
                    if (firstUnreadId != 0) {
                        [self.dialogListController scrollToConversationWithId:firstUnreadId];
                    }
                    else {
                        [self.dialogListController scrollToTop];
                        
                        int unreadCount = [TGDatabaseInstance() unreadChatsCount] + [TGDatabaseInstance() unreadChannelsCount];
                        if (unreadCount > 0)
                            [TGDatabaseInstance() transactionCalculateUnreadChats];
                    }
                });
            }];
        }
        else
        {
            int64_t anchorConversationId = self.dialogListController.currentVisibleUnreadConversation;
            
            TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:anchorConversationId];
            const int followingScanLimit = 1;
            [TGDatabaseInstance() loadUnreadConversationListFromDate:conversation.date limit:followingScanLimit completion:^(NSArray *result) {
                TGDispatchOnMainThread(^{
                    TGConversation *followingUnread = [result firstObject];
                    int64_t followingUnreadId = followingUnread.conversationId;
                    if (followingUnreadId != 0)
                        [self.dialogListController scrollToConversationWithId:followingUnreadId];
                    else
                        [self.dialogListController scrollToTop];
                });
            }];
        }
    }];
}

- (void)hintMoveConversationAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    [ActionStageInstance() dispatchOnStageQueue:^{
        NSMutableArray *previousConversationIds = [[NSMutableArray alloc] init];
        for (TGConversation *conversation in _conversationList) {
            [previousConversationIds addObject:@(conversation.conversationId)];
        }
        
        id object = [_conversationList objectAtIndex:fromIndex];
        [_conversationList removeObjectAtIndex:fromIndex];
        [_conversationList insertObject:object atIndex:toIndex];
        
        NSMutableArray *conversationIds = [[NSMutableArray alloc] init];
        int32_t nextPinnedDate = TGConversationPinnedDateBase;
        for (NSUInteger i = 0; i < _conversationList.count; i++) {
            TGConversation *conversation = _conversationList[i];
            if (conversation.pinnedDate != 0) {
                nextPinnedDate += 1;
            }
        }
        for (NSUInteger i = 0; i < _conversationList.count; i++) {
            TGConversation *conversation = _conversationList[i];
            if (conversation.pinnedDate != 0) {
                nextPinnedDate -= 1;
                
                conversation = [conversation copy];
                conversation.pinnedDate = nextPinnedDate;
                [_conversationList replaceObjectAtIndex:i withObject:conversation];
            }
            [conversationIds addObject:@(conversation.conversationId)];
        }
        
    }];
}

- (bool)isConversationOpened:(int64_t)conversationId
{
    UIViewController *topViewController = [TGAppDelegateInstance.rootController.viewControllers lastObject];
    
    if ([topViewController isKindOfClass:[TGModernConversationController class]])
    {
        return ((TGGenericModernConversationCompanion *)((TGModernConversationController *)(topViewController)).companion).conversationId == conversationId;
    }
    
    return false;
}

- (void)deleteItem:(TGConversation *)conversation animated:(bool)animated
{
    [self deleteItem:conversation animated:animated interfaceOnly:false];
}

- (void)deleteItem:(TGConversation *)conversation animated:(bool)animated interfaceOnly:(bool)interfaceOnly
{
    TGDispatchOnMainThread(^
    {
        if ([self isConversationOpened:conversation.conversationId]) {
            [TGAppDelegateInstance.rootController clearContentControllers];
        }
    });
    
    int64_t conversationId = conversation.conversationId;
    [TGTelegraphInstance.liveLocationManager stopWithPeerId:conversationId];
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        bool found = false;
        for (int i = 0; i < (int)self.conversationList.count; i++)
        {
            TGConversation *conversation = [self.conversationList objectAtIndex:i];
            if (TGPeerIdIsAd(conversation.conversationId)) {
                continue;
            }
            if (conversation.conversationId == conversationId)
            {
                found = true;
                [self.conversationList removeObjectAtIndex:i];
                
                NSNumber *removedIndex = [[NSNumber alloc] initWithInt:i];
                
                if (!interfaceOnly)
                {
                    if ([conversation isKindOfClass:[TGConversation class]])
                    {
                        [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/delete", conversationId] options:@{@"conversationId": @(conversationId), @"block": @true} watcher:self];
                    }
                    else
                    {
                        TGFeed *feed = (TGFeed *)conversation;
                        [[TGFeedManagementSignals updateFeedChannels:feed.fid peerIds:[NSSet set] alsoNewlyJoined:false] startWithNext:nil];
                    }
                }
                
                TGDispatchOnMainThread(^
                {
                    if (!animated)
                        [UIView setAnimationsEnabled:false];
                    TGDialogListController *dialogListController = self.dialogListController;
                    [dialogListController dialogListItemsChanged:nil insertedItems:nil updatedIndices:nil updatedItems:nil removedIndices:[NSArray arrayWithObject:removedIndex]];
                    if (!animated)
                        [UIView setAnimationsEnabled:true];
                });
                
                break;
            }
        }
        
        if (!found && !interfaceOnly)
        {
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/delete", conversationId] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:conversationId] forKey:@"conversationId"] watcher:self];
        }
    }];
}

- (void)clearItem:(TGConversation *)conversation animated:(bool)animated
{
    int64_t conversationId = conversation.conversationId;
 
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        for (int i = 0; i < (int)self.conversationList.count; i++)
        {
            TGConversation *conversation = [self.conversationList objectAtIndex:i];
            if (conversation.conversationId == conversationId && !TGPeerIdIsAd(conversation.conversationId))
            {
                [self.conversationList removeObjectAtIndex:i];
                
                TGUser *user = conversation.conversationId > 0 ? [TGDatabaseInstance() loadUser:conversation.conversationId] : nil;
                if (user != nil && (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot))
                {
                    NSNumber *removedIndex = [[NSNumber alloc] initWithInt:i];
                    
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/delete", conversationId] options:@{@"conversationId": @(conversationId), @"block": @false} watcher:self];
                    
                    TGDispatchOnMainThread(^
                    {
                        if (!animated)
                            [UIView setAnimationsEnabled:false];
                        TGDialogListController *dialogListController = self.dialogListController;
                        [dialogListController dialogListItemsChanged:nil insertedItems:nil updatedIndices:nil updatedItems:nil removedIndices:[NSArray arrayWithObject:removedIndex]];
                        if (!animated)
                            [UIView setAnimationsEnabled:true];
                    });
                }
                else
                {
                    int actionId = 0;
                    [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/conversation/(%lld)/clearHistory/(dialogList%d)", conversationId, actionId++] options:[NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:conversationId] forKey:@"conversationId"] watcher:self];
                    
                    conversation = [conversation copy];

                    conversation.outgoing = false;
                    conversation.text = nil;
                    conversation.media = nil;
                    conversation.unread = false;
                    conversation.unreadCount = 0;
                    conversation.fromUid = 0;
                    conversation.deliveryError = false;
                    conversation.deliveryState = TGMessageDeliveryStateDelivered;
                    
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:conversation.dialogListData];
                    dict[@"authorName"] = @"";
                    
                    TGDispatchOnMainThread(^
                    {
                        if (!animated)
                            [UIView setAnimationsEnabled:false];
                        TGDialogListController *dialogListController = self.dialogListController;
                        [dialogListController dialogListItemsChanged:nil insertedItems:nil updatedIndices:@[@(i)] updatedItems:@[conversation] removedIndices:nil];
                        if (!animated)
                            [UIView setAnimationsEnabled:true];
                    });
                }
                
                break;
            }
        }
    }];
}

- (void)maybeLoadAd:(SAtomic *)syncResult {
    if (!_loadedAd && TGTelegraphInstance.clientUserId != 0) {
        _loadedAd = true;
        __weak TGTelegraphDialogListCompanion *weakSelf = self;
        [_adItemDisposable setDisposable:[[TGAdSignals adChatListConversation] startWithNext:^(TGConversation *conversation) {
            conversation = [conversation copy];
            conversation.conversationId = TGPeerIdFromAdId(TGChannelIdFromPeerId(conversation.conversationId));
            [ActionStageInstance() dispatchOnStageQueue:^{
                __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                
                if (_adConversation != nil) {
                    for (NSUInteger i = 0; i < _conversationList.count; i++) {
                        if (((TGConversation *)_conversationList[i]).conversationId == _adConversation.conversationId) {
                            [_conversationList removeObjectAtIndex:i];
                            break;
                        }
                    }
                }
                [self initializeDialogListData:conversation customUser:nil selfUser:nil];
                _adConversation = conversation;
                if (_adConversation != nil) {
                    [_conversationList insertObject:conversation atIndex:0];
                }
                NSNumber *isSync = [syncResult swap:@false];
                if (isSync == nil || ![isSync boolValue]) {
                    NSArray *items = [self og_compat_dialogListItems];
                    TGDispatchOnMainThread(^{
                        TGDialogListController *controller = self.dialogListController;
                        if (controller != nil) {
                            [controller dialogListFullyReloaded:items];
                        }
                    });
                }
            }];
        }]];
    }
}

- (void)og_compat_continueFolderDialogPreload
{
    if (!_ogCompatFolderPreloadActive || _ogCompatFolderPreloadRequestInFlight)
        return;
    if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
    {
        _ogCompatFolderPreloadRequestInFlight = false;
        return;
    }

    TGDialogListController *controller = self.dialogListController;
    bool deferredForForeground = controller != nil && ![controller dialogListOnScreen];
    if ([controller dialogListIsFastScrolling] || deferredForForeground)
    {
        if (!_ogCompatFolderPreloadResumeScheduled)
        {
            _ogCompatFolderPreloadResumeScheduled = true;
            __weak TGTelegraphDialogListCompanion *weakSelf = self;
            OGPlatformDispatchOnMainThreadAfter(deferredForForeground ? 1.0 : 0.25, ^
            {
                __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    strongSelf->_ogCompatFolderPreloadResumeScheduled = false;
                    [strongSelf og_compat_continueFolderDialogPreload];
                }
            });
        }
        return;
    }

    if (_ogCompatFolderPreloadArchiveStage)
    {
        _ogCompatFolderPreloadRequestInFlight = true;
        [self loadArchiveItems];
        return;
    }

    if ([TGDatabaseInstance() customProperty:@"dialogListLoaded"].length != 0)
    {
        _ogCompatFolderPreloadArchiveStage = true;
        _ogCompatFolderPreloadRequestInFlight = true;
        [self loadArchiveItems];
        return;
    }

    _ogCompatFolderPreloadRequestInFlight = true;
    [ActionStageInstance() requestActor:@"/tg/dialoglist/(sync)" options:@{@"fullSync": @true, @"limit": @20} watcher:self];
}

- (bool)ios6FolderPreloadActive
{
    return _ogCompatFolderPreloadActive;
}

- (void)ios6PreloadAllDialogsForFolders
{
    if (_ogCompatFolderPreloadActive)
        return;
    if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
        return;

    bool mainComplete = [TGDatabaseInstance() customProperty:@"dialogListLoaded"].length != 0;
    bool archiveComplete = [TGDatabaseInstance() customProperty:@"ios6ArchivePeerIdsComplete"].length == 1;
    if (mainComplete && archiveComplete)
        return;

    [self og_compat_resetFolderPreloadState:true archiveStage:mainComplete];
    [self og_compat_continueFolderDialogPreload];
}

- (void)og_compat_resetFolderPreloadState:(bool)active archiveStage:(bool)archiveStage
{
    _ogCompatFolderPreloadActive = active;
    _ogCompatFolderPreloadRequestInFlight = false;
    _ogCompatFolderPreloadResumeScheduled = false;
    _ogCompatFolderPreloadRetryScheduled = false;
    _ogCompatFolderPreloadArchiveStage = archiveStage;
    _ogCompatFolderPreloadRetryCount = 0;
}

- (void)ios6MergeCompleteLocalDialogList:(NSArray *)items
{
    if (items.count == 0)
        return;

    NSArray *snapshot = [items copy];
    __weak TGTelegraphDialogListCompanion *weakSelf = self;
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        __strong TGTelegraphDialogListCompanion *stageSelf = weakSelf;
        if (stageSelf == nil)
            return;

        NSMutableSet *existingPeerIds = [[NSMutableSet alloc] init];
        for (id<TGDialogListItem> item in stageSelf->_conversationList)
        {
            if ([item isKindOfClass:[TGConversation class]])
                [existingPeerIds addObject:@(item.conversationId)];
        }
        for (id<TGDialogListItem> item in stageSelf->_archivedConversations)
        {
            if ([item isKindOfClass:[TGConversation class]])
                [existingPeerIds addObject:@(item.conversationId)];
        }

        int added = 0;
        for (id item in snapshot)
        {
            TGConversation *conversation = [item isKindOfClass:[TGConversation class]] ? item : nil;
            if (conversation == nil || conversation.isArchived)
                continue;
            NSNumber *peerKey = @(conversation.conversationId);
            if ([existingPeerIds containsObject:peerKey])
                continue;
            [existingPeerIds addObject:peerKey];
            [stageSelf->_conversationList addObject:conversation];
            added++;
        }

        if (added == 0)
            return;

        [stageSelf->_conversationList sortUsingComparator:^NSComparisonResult(id<TGDialogListItem> lhs, id<TGDialogListItem> rhs)
        {
            return OGCompatDialogOrderPinnedFirst(lhs, rhs);
        }];

        NSArray *mergedItems = [stageSelf og_compat_dialogListItems];
        stageSelf->_canLoadMore = false;

        TGDispatchOnMainThread(^
        {
            TGDialogListController *controller = stageSelf.dialogListController;
            if (controller != nil)
            {
                controller.canLoadMore = false;
                [controller dialogListFullyReloaded:mergedItems];
            }
        });
    }];
}

- (void)loadMoreItems
{
    [self loadMoreItems:0];
}

- (void)og_compat_scheduleEagerDialogPageAfter:(NSTimeInterval)delay
{
    if (_ogCompatEagerDialogPageScheduled)
        return;
    _ogCompatEagerDialogPageScheduled = true;
    __weak TGTelegraphDialogListCompanion *weakSelf = self;
    TGDispatchAfter(delay, dispatch_get_main_queue(), ^
    {
        __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        TGDialogListController *controller = strongSelf.dialogListController;
        bool fastScrolling = [controller dialogListIsFastScrolling];
        bool deferredForForeground = controller != nil && ![controller dialogListOnScreen];
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            strongSelf->_ogCompatEagerDialogPageScheduled = false;
            if (!strongSelf->_canLoadMore)
                return;
            if (fastScrolling || deferredForForeground)
            {
                [strongSelf og_compat_scheduleEagerDialogPageAfter:deferredForForeground ? 1.0 : 0.3];
                return;
            }
            [strongSelf og_compat_loadMoreItems:50 background:true];
        }];
    });
}

- (void)clearChatListCacheAndReload
{
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [_conversationList removeAllObjects];
        [_archivedConversations removeAllObjects];
        [_pagedConversationIds removeAllObjects];
        _loadedAd = false;
        _canLoadMore = true;
        [self og_compat_resetFolderPreloadState:false archiveStage:false];
        
        TGDispatchOnMainThread(^
        {
            TGDialogListController *controller = self.dialogListController;
            if (controller != nil)
            {
                controller.canLoadMore = true;
                [controller dialogListFullyReloaded:[NSArray array]];
            }
        });
        
        [ActionStageInstance() requestActor:@"/tg/dialoglist/(sync)" options:@{@"force": @true, @"limit": @100, @"fullSync": @true} watcher:self];
    }];
}

- (void)loadMoreItems:(int)limit
{
    [self og_compat_loadMoreItems:limit background:false];
}

- (void)og_compat_loadMoreItems:(int)limit background:(bool)background
{
    limit = limit != 0 ? limit : 30;
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        if (_ogCompatFolderPreloadActive && !_ogCompatFolderPreloadArchiveStage && _ogCompatFolderPreloadRequestInFlight)
            return;
        NSMutableArray *currentConversationIds = [[NSMutableArray alloc] initWithCapacity:_conversationList.count];
        
        [self maybeLoadAd:nil];
        
        int minDate = INT_MAX;
        for (TGConversation *conversation in _conversationList)
        {
            if (TGPeerIdIsAd(conversation.conversationId)) {
                continue;
            }
            if (![conversation isKindOfClass:[TGConversation class]])
                continue;
            
            if (conversation.date < minDate && !conversation.isBroadcast)
                minDate = conversation.date;
            
            [currentConversationIds addObject:[[NSNumber alloc] initWithLongLong:conversation.conversationId]];
        }
        
        NSMutableSet *excludedConversationIds = [[NSMutableSet alloc] initWithSet:_pagedConversationIds];
        [excludedConversationIds addObjectsFromArray:currentConversationIds];
        for (id<TGDialogListItem> conversation in _archivedConversations)
            [excludedConversationIds addObject:@(conversation.conversationId)];
        
        if (minDate != INT_MAX)
        {
            [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/dialoglist/(%d)", minDate] options:[NSDictionary dictionaryWithObjectsAndKeys:@(limit), @"limit", [NSNumber numberWithInt:minDate], @"date", excludedConversationIds.allObjects, @"excludeConversationIds", @(background), @"background", nil] watcher:self];
        }
        else
        {
            _canLoadMore = false;
            
            TGDispatchOnMainThread(^
            {
                TGDialogListController *dialogListController = self.dialogListController;
                
                dialogListController.canLoadMore = false;
                [dialogListController dialogListFullyReloaded:[NSArray array]];
            });
        }
    }];
}

- (void)loadArchiveItems
{
    if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
    {
        _ogCompatFolderPreloadRequestInFlight = false;
        return;
    }
    int archiveLimit = 200;
#if defined(ONEGRAM_ARMV6)
    archiveLimit = 40;
#endif
    __weak TGTelegraphDialogListCompanion *weakSelf = self;
    [TGDatabaseInstance() loadConversationListFromDate:INT_MAX limit:archiveLimit excludeConversationIds:@[] folderId:1 completion:^(NSArray *result, __unused bool loadedAllRegular)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            [strongSelf og_compat_mergeLocalArchiveItems:result];
            [ActionStageInstance() requestActor:@"/tg/dialoglist/(archive)" options:@{@"folderId": @1, @"limit": @(archiveLimit)} watcher:strongSelf];
        }];
    }];
}

- (void)og_compat_mergeLocalArchiveItems:(NSArray *)localItems
{
    TGUser *selfUser = [TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId];
    NSMutableSet *knownPeerIds = [[NSMutableSet alloc] init];
    for (id<TGDialogListItem> item in _archivedConversations)
        [knownPeerIds addObject:@(item.conversationId)];

    bool added = false;
    for (TGConversation *conversation in localItems)
    {
        if (![conversation isKindOfClass:[TGConversation class]] || !conversation.isArchived || conversation.isDeleted || conversation.isDeactivated)
            continue;
        NSNumber *peerId = @(conversation.conversationId);
        if ([knownPeerIds containsObject:peerId])
            continue;
        [knownPeerIds addObject:peerId];
        TGConversation *archivedConversation = [conversation copy];
        [self initializeDialogListData:archivedConversation customUser:nil selfUser:selfUser];
        [_archivedConversations addObject:archivedConversation];
        added = true;
    }
    if (!added)
        return;

    [_archivedConversations sortUsingComparator:^NSComparisonResult(id<TGDialogListItem> lhs, id<TGDialogListItem> rhs)
    {
        return OGCompatDialogOrderPinnedFirst(lhs, rhs);
    }];

    NSArray *items = [self og_compat_dialogListItems];
    bool canLoadMore = _canLoadMore;
    TGDispatchOnMainThread(^
    {
        TGDialogListController *controller = self.dialogListController;
        if (controller != nil)
        {
            controller.canLoadMore = canLoadMore;
            [controller dialogListFullyReloaded:items];
        }
    });
}

- (void)beginSearch:(NSString *)queryString inMessages:(bool)inMessages
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [self resetWatchedNodePaths];

        self.searchString = [[[NSRegularExpression regularExpressionWithPattern:@" +" options:0 error:NULL] stringByReplacingMatchesInString:queryString options:0 range:NSMakeRange(0, queryString.length) withTemplate:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (self.searchString.length == 0)
        {
            TGDispatchOnMainThread(^
            {
                TGDialogListController *dialogListController = self.dialogListController;
                [dialogListController searchResultsReloaded:nil searchString:nil];
            });
        } 
        else
        {
            if (inMessages)
            {
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/search/messages/(%lu)", (unsigned long)[self.searchString hash]] options:[NSDictionary dictionaryWithObject:self.searchString forKey:@"query"] watcher:self];
            }
            else
            {
                [ActionStageInstance() requestActor:[NSString stringWithFormat:@"/tg/search/dialogs/(%lu)", (unsigned long)[self.searchString hash]] options:[NSDictionary dictionaryWithObject:self.searchString forKey:@"query"] watcher:self];
            }
        }
    }];
}

- (void)searchResultSelectedUser:(TGUser *)user
{
    if (self.forwardMode || self.privacyMode || self.showPrivateOnly || self.showGroupsAndChannelsOnly)
    {
        [_conversatioSelectedWatcher requestAction:@"userSelected" options:[[NSDictionary alloc] initWithObjectsAndKeys:user, @"user", nil]];
    }
    else
    {
        int64_t conversationId = user.uid;
        [[TGInterfaceManager instance] navigateToConversationWithId:conversationId conversation:nil];
    }
}

- (NSString *)stringForMemberCount:(int)memberCount
{
    return [effectiveLocalization() getPluralized:@"Conversation.StatusRecipients" count:(int32_t)memberCount];
}

- (void)initializeDialogListData:(TGConversation *)conversation customUser:(TGUser *)customUser selfUser:(TGUser *)selfUser
{
    if (![conversation isKindOfClass:[TGConversation class]])
        return;
    
    bool conversationArchived = conversation.isArchived;
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    int64_t mutePeerId = conversation.conversationId;
    
    dict[@"authorIsSelf"] = @(conversation.fromUid == TGTelegraphInstance.clientUserId);
    dict[@"isSavedMessages"] = conversation.conversationId == TGTelegraphInstance.clientUserId ? (self.forwardMode ? @2 : @1) : @0;
    
    if (conversation.isChannel) {
        dict[@"isChannel"] = @true;
        dict[@"isChannelGroup"] = @(conversation.isChannelGroup);
        
        [dict setObject:(conversation.chatTitle == nil ? @"" : conversation.chatTitle) forKey:@"title"];
        
        if (conversation.chatPhotoSmall.length != 0)
            [dict setObject:conversation.chatPhotoFullSmall forKey:@"avatarUrl"];
        
        [dict setObject:[NSNumber numberWithBool:true] forKey:@"isChat"];
        [dict setObject:[NSNumber numberWithBool:conversation.isVerified] forKey:@"isVerified"];
        
        NSString *authorName = nil;
        NSString *authorAvatarUrl = nil;
        if (conversation.fromUid == selfUser.uid)
        {
            authorAvatarUrl = selfUser.photoUrlSmall;
            
            static NSString *youString = nil;
            if (youString == nil)
                youString = authorNameYou;
            
            if (conversation.text.length != 0 || conversation.media.count != 0)
                authorName = youString;
        }
        else
        {
            if (conversation.fromUid != 0)
            {
                TGUser *authorUser = [[TGDatabase instance] loadUser:conversation.fromUid];
                if (authorUser != nil)
                {
                    authorAvatarUrl = authorUser.photoUrlSmall;
                    authorName = authorUser.displayName;
                }
            }
        }
        
        if (authorAvatarUrl != nil)
            [dict setObject:authorAvatarUrl forKey:@"authorAvatarUrl"];
        if (authorName != nil)
            [dict setObject:authorName forKey:@"authorName"];
    }
    else if (!conversation.isChat || conversation.isEncrypted)
    {
        int64_t userId = 0;
        if (conversation.isEncrypted)
        {
            if (conversation.chatParticipants.chatParticipantUids.count != 0)
                userId = [conversation.chatParticipants.chatParticipantUids[0] longLongValue];
        }
        else
            userId = conversation.conversationId;
        mutePeerId = userId;
        
        TGUser *user = nil;
        if (customUser != nil && customUser.uid == userId)
            user = customUser;
        else
            user = [[TGDatabase instance] loadUser:(int64_t)userId];
        
        dict[@"isVerified"] = @(user.isVerified);
        dict[@"isPremium"] = @(user.isPremium);
        dict[@"emojiStatusDocumentId"] = @(user.emojiStatusDocumentId);
        bool isRemoteContact = user.uid != 0 && [TGDatabaseInstance() uidIsRemoteContact:user.uid];
        dict[@"isContact"] = @(isRemoteContact);
        
        NSString *title = [user displayName];
        NSArray *titleLetters = nil;
        
        if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot) {
            dict[@"isBot"] = @true;
        }
        dict[@"presenceOnline"] = @(user.presence.online);
        dict[@"presenceLastSeen"] = @(user.presence.lastSeen);
        
        if (user.firstName.length != 0 && user.lastName.length != 0)
            titleLetters = [[NSArray alloc] initWithObjects:user.firstName, user.lastName, nil];
        else if (user.firstName.length != 0)
            titleLetters = [[NSArray alloc] initWithObjects:user.firstName, nil];
        else if (user.lastName.length != 0)
            titleLetters = [[NSArray alloc] initWithObjects:user.lastName, nil];
        
        if (title != nil)
            [dict setObject:title forKey:@"title"];
        
        if (titleLetters != nil)
            dict[@"titleLetters"] = titleLetters;
        
        dict[@"isEncrypted"] = [[NSNumber alloc] initWithBool:conversation.isEncrypted];
        if (conversation.isEncrypted)
        {
            dict[@"encryptionStatus"] = [[NSNumber alloc] initWithInt:conversation.encryptedData.handshakeState];
            dict[@"encryptionOutgoing"] = [[NSNumber alloc] initWithBool:conversation.chatParticipants.chatAdminId == TGTelegraphInstance.clientUserId];
            NSString *firstName = user.displayFirstName;
            dict[@"encryptionFirstName"] = firstName != nil ? firstName : @"";

            if (user.firstName != nil)
                dict[@"firstName"] = user.firstName;
            if (user.lastName != nil)
                dict[@"lastName"] = user.lastName;
        }
        dict[@"encryptedUserId"] = [[NSNumber alloc] initWithLongLong:userId];
        
        if (user.photoUrlSmall != nil)
            [dict setObject:user.photoFullUrlSmall forKey:@"avatarUrl"];
        [dict setObject:[NSNumber numberWithBool:false] forKey:@"isChat"];
        
        NSString *authorAvatarUrl = nil;
        if (selfUser != nil)
            authorAvatarUrl = selfUser.photoUrlSmall;
        
        if (authorAvatarUrl != nil)
            [dict setObject:authorAvatarUrl forKey:@"authorAvatarUrl"];
        
        if (conversation.media.count != 0)
        {
            NSString *authorName = nil;
            if (conversation.fromUid == selfUser.uid)
            {
                static NSString *youString = nil;
                if (youString == nil)
                    youString = authorNameYou;
                
                authorName = youString;
            }
            else
            {
                if (conversation.fromUid != 0)
                {
                    TGUser *authorUser = [[TGDatabase instance] loadUser:conversation.fromUid];
                    if (authorUser != nil)
                    {
                        authorName = authorUser.displayName;
                    }
                }
            }
            
            if (authorName != nil)
                [dict setObject:authorName forKey:@"authorName"];
        }
    }
    else
    {
        dict[@"isBroadcast"] = @(conversation.isBroadcast);
        
        if (conversation.isBroadcast && conversation.chatTitle.length == 0)
            dict[@"title"] = [self stringForMemberCount:conversation.chatParticipantCount];
        else
            [dict setObject:(conversation.chatTitle == nil ? @"" : conversation.chatTitle) forKey:@"title"];
        
        if (conversation.chatPhotoSmall.length != 0)
            [dict setObject:conversation.chatPhotoFullSmall forKey:@"avatarUrl"];
        
        [dict setObject:[NSNumber numberWithBool:true] forKey:@"isChat"];
        
        NSString *authorName = nil;
        NSString *authorAvatarUrl = nil;
        if (conversation.fromUid == selfUser.uid)
        {
            authorAvatarUrl = selfUser.photoUrlSmall;
            
            static NSString *youString = nil;
            if (youString == nil)
                youString = authorNameYou;
            
            if (conversation.text.length != 0 || conversation.media.count != 0)
                authorName = youString;
        }
        else
        {
            if (conversation.fromUid != 0)
            {
                TGUser *authorUser = [[TGDatabase instance] loadUser:conversation.fromUid];
                if (authorUser != nil)
                {
                    authorAvatarUrl = authorUser.photoUrlSmall;
                    authorName = authorUser.displayName;
                }
            }
        }
        
        if (authorAvatarUrl != nil)
            [dict setObject:authorAvatarUrl forKey:@"authorAvatarUrl"];
        if (authorName != nil)
            [dict setObject:authorName forKey:@"authorName"];
    }
    
    if (conversation.draft != nil) {
        dict[@"draft"] = conversation.draft;
    }
    
    NSMutableDictionary *messageUsers = [[NSMutableDictionary alloc] init];
    for (TGMediaAttachment *attachment in conversation.media)
    {
        if (attachment.type == TGActionMediaAttachmentType)
        {
            TGActionMediaAttachment *actionAttachment = (TGActionMediaAttachment *)attachment;
            if (actionAttachment.actionType == TGMessageActionChatAddMember || actionAttachment.actionType == TGMessageActionChatDeleteMember || actionAttachment.actionType == TGMessageActionChannelInviter)
            {
                NSArray *uids = actionAttachment.actionData[@"uids"];
                if (uids != nil) {
                    for (NSNumber *nUid in uids) {
                        TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
                        if (user != nil)
                            [messageUsers setObject:user forKey:nUid];
                    }
                } else {
                    NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                    if (nUid != nil)
                    {
                        TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
                        if (user != nil)
                            [messageUsers setObject:user forKey:nUid];
                    }
                }
            }
            if (actionAttachment.actionType == TGMessageActionSecureValuesSent)
            {
                TGUser *user = [TGDatabaseInstance() loadUser:conversation.conversationId];
                if (user != nil)
                    [messageUsers setObject:user forKey:@(conversation.conversationId)];
            }
            TGUser *user = conversation.fromUid == selfUser.uid ? selfUser : [TGDatabaseInstance() loadUser:conversation.fromUid];
            if (user != nil)
            {
                [messageUsers setObject:user forKey:[[NSNumber alloc] initWithLongLong:user.uid]];
                [messageUsers setObject:user forKey:@"author"];
            }
        }
    }
    
    
    [dict setObject:[[NSNumber alloc] initWithBool:[TGDatabaseInstance() isPeerMuted:mutePeerId]] forKey:@"mute"];
    
    [dict setObject:messageUsers forKey:@"users"];
    NSDictionary *preparedPreview = [TGDialogListCell preparedPreviewForConversationId:conversation.conversationId messageText:conversation.text attachments:conversation.media isSavedMessages:[dict[@"isSavedMessages"] intValue] isGroupChat:[dict[@"isChat"] boolValue] isChannel:conversation.isChannel isChannelGroup:conversation.isChannelGroup isEncrypted:[dict[@"isEncrypted"] boolValue] encryptionStatus:[dict[@"encryptionStatus"] intValue] encryptionOutgoing:[dict[@"encryptionOutgoing"] boolValue] encryptionFirstName:dict[@"encryptionFirstName"]];
    if (preparedPreview != nil)
        dict[@"preparedPreview"] = preparedPreview;
    if (conversationArchived)
        dict[@"ogCompatArchived"] = @true;
    
    conversation.dialogListData = dict;
}

- (void)presentLiveLocationsMenu:(NSArray *)liveLocations
{
    if (liveLocations.count == 1)
    {
        [self openLiveLocation:liveLocations.firstObject];
        return;
    }
    
    TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:[TGLegacyComponentsContext shared] dark:false];
    controller.dismissesByOutsideTap = true;
    controller.narrowInLandscape = true;
    controller.hasSwipeGesture = true;
    
    __weak TGTelegraphDialogListCompanion *weakSelf = self;
    __weak TGMenuSheetController *weakController = controller;
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    NSString *formatPrefix = [TGStringUtils integerValueFormat:@"LiveLocation.MenuChatsCount_" value:liveLocations.count];
    NSString *title = [[NSString alloc] initWithFormat:TGLocalized(formatPrefix), [[NSString alloc] initWithFormat:@"%ld", liveLocations.count]];
    [items addObject:[[TGMenuSheetTitleItemView alloc] initWithTitle:nil subtitle:title]];
    for (TGLiveLocation *liveLocation in liveLocations)
    {
        [items addObject:[[TGLocationLiveSessionItemView alloc] initWithMessage:liveLocation.message peer:liveLocation.peer remaining:[TGLiveLocationSignals remainingTimeForMessage:liveLocation.message] action:^
        {
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            [strongController dismissAnimated:true];
            
            __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf openLiveLocation:liveLocation];
        }]];
    }
    [items addObject:[[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"LiveLocation.MenuStopAll") type:TGMenuSheetButtonTypeDestructive action:^
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController == nil)
            return;
        
        [strongController dismissAnimated:true];
        
        for (TGLiveLocation *liveLocation in liveLocations)
        {
            [TGTelegraphInstance.liveLocationManager stopWithPeerId:[liveLocation peerId]];
        }
    }]];
    
    [items addObject:[[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel action:^
    {
        __strong TGMenuSheetController *strongController = weakController;
        if (strongController != nil)
            [strongController dismissAnimated:true];
    }]];

    
    [controller setItemViews:items];
    controller.sourceRect = ^CGRect
    {
        __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
        if (strongSelf == nil)
            return CGRectZero;
        
        return [strongSelf->_liveLocationPanel convertRect:strongSelf->_liveLocationPanel.bounds toView:strongSelf.dialogListController.view];
    };
    controller.permittedArrowDirections = UIPopoverArrowDirectionUp;
    [controller presentInViewController:self.dialogListController sourceView:self.dialogListController.view animated:true];
}

- (void)openLiveLocation:(TGLiveLocation *)liveLocationToOpen
{
    liveLocationToOpen = [[TGLiveLocation alloc] initWithMessage:[TGDatabaseInstance() loadMessageWithMid:liveLocationToOpen.message.mid peerId:liveLocationToOpen.message.cid] peer:[TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId] hasOwnSession:true isOwnLocation:true isExpired:false];
    
    TGConversation *chat = [TGDatabaseInstance() loadConversationWithId:liveLocationToOpen.message.cid];
    bool isChannel = chat.isChannel && !chat.isChannelGroup;
    
    TGLocationViewController *controller = [[TGLocationViewController alloc] initWithContext:[TGLegacyComponentsContext shared] liveLocation:liveLocationToOpen];
    controller.pallete = self.dialogListController.presentation.locationPallete;
    [controller setFrequentUpdatesHandle:[TGTelegraphInstance.liveLocationManager subscribeForFrequentLocationUpdatesWithPeerId:liveLocationToOpen.message.cid]];
    controller.modalMode = true;
    controller.allowLiveLocationSharing = true;
    controller.zoomToFitAllLocationsOnScreen = true;
    __weak TGLocationViewController *weakLocationController = controller;
    controller.liveLocationStopped = ^
    {
        __strong TGLocationViewController *strongLocationController = weakLocationController;
        if (strongLocationController != nil)
            [strongLocationController.presentingViewController dismissViewControllerAnimated:true completion:nil];
        [TGTelegraphInstance.liveLocationManager stopWithPeerId:liveLocationToOpen.message.cid];
    };
    controller.remainingTimeForMessage = ^SSignal *(TGMessage *message)
    {
        return [TGLiveLocationSignals remainingTimeForMessage:message];
    };
    [controller setLiveLocationsSignal:[[TGLiveLocationSignals liveLocationsForPeerId:liveLocationToOpen.message.cid includeExpired:true onlyLocal:isChannel] map:^id(NSArray *messages)
    {
        int32_t currentTime = (int32_t)OGRemoteClockTime();
        
        NSMutableArray *liveLocations = [[NSMutableArray alloc] init];
        for (TGMessage *message in messages)
        {
            int32_t expires = (int32_t)message.date;
            for (TGMediaAttachment *attachment in message.mediaAttachments)
            {
                if (attachment.type == TGLocationMediaAttachmentType)
                {
                    expires += ((TGLocationMediaAttachment *)attachment).period;
                    break;
                }
            }
            
            id peer = nil;
            int64_t peerId = message.fromUid;
            if (TGPeerIdIsChannel(peerId))
                peer = [TGDatabaseInstance() loadChannels:@[@(peerId)]][@(peerId)];
            else
                peer = [TGDatabaseInstance() loadUser:peerId];
            
            TGLiveLocation *liveLocation = [[TGLiveLocation alloc] initWithMessage:message peer:peer hasOwnSession:liveLocationToOpen.message.mid == message.mid isOwnLocation:[liveLocationToOpen peerId] == message.fromUid isExpired:currentTime > expires];
            [liveLocations addObject:liveLocation];
        }
        return liveLocations;
    }]];
    controller.receivingPeer = TGPeerIdIsUser(liveLocationToOpen.message.cid) ? [TGDatabaseInstance() loadUser:liveLocationToOpen.message.cid] : [TGDatabaseInstance() loadConversationWithId:liveLocationToOpen.message.cid];
    
    __weak TGTelegraphDialogListCompanion *weakSelf = self;
    controller.openLocation = ^(TGMessage *message)
    {
        __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.dialogListController dismissViewControllerAnimated:true completion:^
        {
            TGLiveLocation *liveLocation = [[TGLiveLocation alloc] initWithMessage:message peer:[TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId] hasOwnSession:true isOwnLocation:true isExpired:false];
            [strongSelf openLiveLocation:liveLocation];
        }];
    };

    TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[controller]];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        navigationController.presentationStyle = TGNavigationControllerPresentationStyleInFormSheet;
        navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [self.dialogListController presentViewController:navigationController animated:true completion:nil];
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/search/messages/(%lu)", (unsigned long)[_searchString hash]]])
    {
        if ([messageType isEqualToString:@"searchResultsUpdated"])
        {
            NSArray *conversations = [((SGraphObjectNode *)message[@"dialogs"]).object sortedArrayUsingComparator:^NSComparisonResult(TGConversation *conversation1, TGConversation *conversation2)
            {
                return conversation1.date > conversation2.date ? NSOrderedAscending : NSOrderedDescending;
            }];
            
            NSMutableArray *result = [[NSMutableArray alloc] init];
            
            TGUser *selfUser = [[TGDatabase instance] loadUser:TGTelegraphInstance.clientUserId];
            
            
            for (TGConversation *conversation in conversations)
            {
                [self initializeDialogListData:conversation customUser:nil selfUser:selfUser];
                [result addObject:conversation];
            }
            
            NSString *searchString = _searchString;
            
            
            TGDispatchOnMainThread(^
            {
                TGDialogListController *dialogListController = self.dialogListController;
                [dialogListController searchResultsReloaded:@{@"dialogs": result} searchString:searchString];
            });
        }
    }
}

- (id)processSearchResultItem:(id)item
{
    bool forwardMode = self.forwardMode;
    bool privacyMode = self.privacyMode;
    bool showGroupsOnly = self.showGroupsOnly;
    bool showSecretInForwardMode = self.showSecretInForwardMode;
    
    if ([item isKindOfClass:[TGConversation class]])
    {
        TGConversation *conversation = (TGConversation *)item;
        if (((forwardMode || privacyMode) && TGPeerIdIsSecretChat(conversation.conversationId)) && !showSecretInForwardMode)
            return nil;
        
        if ((forwardMode || privacyMode) && conversation.isBroadcast)
            return nil;
        
        if (showGroupsOnly && conversation.isChannel && conversation.isChannelGroup) {
            [self initializeDialogListData:conversation customUser:nil selfUser:[TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId]];
            return conversation;
        }
        
        if (showGroupsOnly && (TGPeerIdIsUser(conversation.conversationId) || TGPeerIdIsSecretChat(conversation.conversationId)))
            return nil;
        
        [self initializeDialogListData:conversation customUser:nil selfUser:[TGDatabaseInstance() loadUser:TGTelegraphInstance.clientUserId]];
        return conversation;
    }
    else if ([item isKindOfClass:[TGUser class]])
    {
        if (showGroupsOnly)
            return nil;
        
        return item;
    }
    
    return nil;
}

- (TGConversation *)selfPeer
{
    TGConversation *selfPeer = [TGDatabaseInstance() loadConversationWithId:TGTelegraphInstance.clientUserId];
    if (selfPeer == nil)
        selfPeer = [[TGConversation alloc] initWithConversationId:TGTelegraphInstance.clientUserId unreadCount:0 serviceUnreadCount:0];
    
    return selfPeer;
}

- (void)og_compat_ensureSavedMessagesPeerWithSelfUser:(TGUser *)selfUser
{
    if (selfUser.uid == 0 || self.forwardMode || self.privacyMode || self.showPrivateOnly || self.showGroupsAndChannelsOnly || self.showGroupsOnly)
        return;

    for (NSUInteger index = 0; index < _conversationList.count; index++)
    {
        id item = _conversationList[index];
        if (![item isKindOfClass:[TGConversation class]] || ((TGConversation *)item).conversationId != selfUser.uid)
            continue;

        if ([((TGConversation *)item).dialogListData[@"ogCompatSyntheticSavedMessages"] boolValue] && index != 0)
        {
            [_conversationList removeObjectAtIndex:index];
            [_conversationList insertObject:item atIndex:0];
        }
        return;
    }

    TGConversation *selfConversation = [self selfPeer];
    [self initializeDialogListData:selfConversation customUser:nil selfUser:selfUser];
    NSMutableDictionary *dialogListData = [selfConversation.dialogListData mutableCopy];
    if (dialogListData == nil)
        dialogListData = [[NSMutableDictionary alloc] init];
    dialogListData[@"ogCompatSyntheticSavedMessages"] = [NSNumber numberWithBool:YES];
    selfConversation.dialogListData = dialogListData;
    [_conversationList insertObject:selfConversation atIndex:0];
}

- (NSArray *)og_compat_dialogListItems
{
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:_conversationList.count + _archivedConversations.count];
    [items addObjectsFromArray:_conversationList];
    [items addObjectsFromArray:_archivedConversations];
    return items;
}

- (NSMutableArray *)og_compat_dialogListItemIds
{
    NSMutableArray *itemIds = [[NSMutableArray alloc] initWithCapacity:_conversationList.count + _archivedConversations.count];
    for (id<TGDialogListItem> item in _conversationList)
        [itemIds addObject:@(item.conversationId)];
    for (id<TGDialogListItem> item in _archivedConversations)
        [itemIds addObject:@(item.conversationId)];
    return itemIds;
}

- (void)og_compat_applyArchivedConversationUpdates:(NSMutableArray *)conversations selfUser:(TGUser *)selfUser
{
    bool changed = false;
    for (NSInteger i = (NSInteger)conversations.count - 1; i >= 0; i--)
    {
        TGConversation *conversation = conversations[(NSUInteger)i];
        if (![conversation isKindOfClass:[TGConversation class]] || TGPeerIdIsAd(conversation.conversationId))
            continue;

        int64_t conversationId = conversation.conversationId;
        NSUInteger archiveIndex = [_archivedConversations indexOfObjectPassingTest:^BOOL(id<TGDialogListItem> item, __unused NSUInteger index, __unused BOOL *stop)
        {
            return item.conversationId == conversationId;
        }];

        if (!conversation.isArchived || conversation.pinnedDate != 0)
        {
            if (archiveIndex != NSNotFound)
            {
                [_archivedConversations removeObjectAtIndex:archiveIndex];
                changed = true;
            }
            continue;
        }

        NSUInteger mainIndex = [_conversationList indexOfObjectPassingTest:^BOOL(id<TGDialogListItem> item, __unused NSUInteger index, __unused BOOL *stop)
        {
            return item.conversationId == conversationId;
        }];
        if (mainIndex != NSNotFound)
            [_conversationList removeObjectAtIndex:mainIndex];

        if (conversation.isDeleted || conversation.isDeactivated)
        {
            if (archiveIndex != NSNotFound)
                [_archivedConversations removeObjectAtIndex:archiveIndex];
        }
        else
        {
            TGConversation *archivedConversation = [conversation copy];
            [self initializeDialogListData:archivedConversation customUser:nil selfUser:selfUser];
            if (archiveIndex != NSNotFound)
                [_archivedConversations replaceObjectAtIndex:archiveIndex withObject:archivedConversation];
            else
                [_archivedConversations addObject:archivedConversation];
        }
        [conversations removeObjectAtIndex:(NSUInteger)i];
        changed = true;
    }

    if (changed)
    {
        [_archivedConversations sortUsingComparator:^NSComparisonResult(id<TGDialogListItem> lhs, id<TGDialogListItem> rhs)
        {
            return OGCompatDialogOrderPinnedFirst(lhs, rhs);
        }];
    }
}

- (void)ios6MarkFolderOnlyHydrationPeerIds:(NSArray *)peerIds
{
    @synchronized (_ogCompatFolderOnlyHydrationPeerIds)
    {
        [_ogCompatFolderOnlyHydrationPeerIds addObjectsFromArray:peerIds];
    }
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    bool hideSelf = self.forwardMode || self.showPrivateOnly || self.showGroupsAndChannelsOnly;
    
    if ([path isEqualToString:[NSString stringWithFormat:@"/tg/search/dialogs/(%lu)", (unsigned long)[_searchString hash]]])
    {
        NSDictionary *dict = ((SGraphObjectNode *)result).object;
        
        NSArray *users = [dict objectForKey:@"users"];
        NSArray *chats = [dict objectForKey:@"chats"];
        
        NSMutableArray *result = [[NSMutableArray alloc] init];
        if (chats != nil)
        {
            bool forwardMode = self.forwardMode;
            bool privacyMode = self.privacyMode;
            bool showGroupsOnly = self.showGroupsOnly;
            bool showSecretInForwardMode = self.showSecretInForwardMode;
            
            TGUser *selfUser = [[TGDatabase instance] loadUser:TGTelegraphInstance.clientUserId];
            
            for (id object in chats)
            {
                if ([object isKindOfClass:[TGConversation class]])
                {
                    TGConversation *conversation = (TGConversation *)object;
                    if (((forwardMode || privacyMode) && TGPeerIdIsSecretChat(conversation.conversationId)) && !showSecretInForwardMode)
                        continue;
                    
                    if (conversation.conversationId == selfUser.uid && hideSelf)
                        continue;
                    
                    if (conversation.isDeactivated || conversation.isDeleted) {
                        continue;
                    }
                    
                    if ((forwardMode || privacyMode) && conversation.isBroadcast)
                        continue;
                    
                    if (showGroupsOnly && (TGPeerIdIsSecretChat(conversation.conversationId) || TGPeerIdIsUser(conversation.conversationId)))
                        continue;
                    
                    [self initializeDialogListData:conversation customUser:nil selfUser:selfUser];
                    [result addObject:conversation];
                }
                else
                {
                    [result addObject:object];
                }
            }
        }
        if (users != nil)
            [result addObjectsFromArray:users];
        
        NSString *searchString = _searchString;

        TGDispatchOnMainThread(^
        {
            TGDialogListController *dialogListController = self.dialogListController;
            [dialogListController searchResultsReloaded:@{@"dialogs": result} searchString:searchString];
        });
    }
    else if ([path isEqualToString:[NSString stringWithFormat:@"/tg/search/messages/(%lu)", (unsigned long)[_searchString hash]]])
    {
        [self actorMessageReceived:path messageType:@"searchResultsUpdated" message:result];
    }
    else if ([path hasPrefix:@"/tg/dialoglist"])
    {
        TGLog(@"DIALOGS completed path=%@ status=%d items=%d", path, resultCode, [result isKindOfClass:[SGraphListNode class]] ? (int)((SGraphListNode *)result).items.count : -1);
        if (resultCode == 0)
        {
            TGDialogListSynchronizationNode *synchronizationNode = [result isKindOfClass:[TGDialogListSynchronizationNode class]] ? result : nil;
            if (synchronizationNode != nil && synchronizationNode == _lastSynchronizationNode)
                return;
            if (synchronizationNode != nil)
                _lastSynchronizationNode = synchronizationNode;
            bool synchronizationComplete = synchronizationNode == nil || synchronizationNode.complete;
            bool archiveListRequest = synchronizationNode != nil ? synchronizationNode.folderId == 1 : [path rangeOfString:@"archive"].location != NSNotFound;
            bool authoritativeMainSync = synchronizationNode == nil && [path isEqualToString:@"/tg/dialoglist/(sync)"];
            bool canLoadMoreBefore = _canLoadMore;
            
            NSMutableArray *conversationIds = [self og_compat_dialogListItemIds];
            
            if (synchronizationNode.removedPeerIds.count != 0)
            {
                for (NSMutableArray *list in @[_conversationList, _archivedConversations])
                {
                    for (NSInteger index = (NSInteger)list.count - 1; index >= 0; index--)
                    {
                        id<TGDialogListItem> item = list[(NSUInteger)index];
                        if ([synchronizationNode.removedPeerIds containsObject:@(item.conversationId)])
                            [list removeObjectAtIndex:(NSUInteger)index];
                    }
                }
                [_pagedConversationIds minusSet:synchronizationNode.removedPeerIds];
            }
            SGraphListNode *listNode = (SGraphListNode *)result;
            NSMutableArray *loadedItems = [[listNode items] mutableCopy];
            if (authoritativeMainSync)
                [_pagedConversationIds removeAllObjects];
            int newPagedItemsCount = 0;
            if (!archiveListRequest)
            {
                for (id<TGDialogListItem> loadedItem in loadedItems)
                {
                    NSNumber *conversationId = @(loadedItem.conversationId);
                    if (![_pagedConversationIds containsObject:conversationId])
                    {
                        [_pagedConversationIds addObject:conversationId];
                        newPagedItemsCount++;
                    }
                }
            }
            bool canLoadMore = false;
            bool forwardMode = self.forwardMode;
            bool privacyMode = self.privacyMode;
            bool showGroupsOnly = self.showGroupsOnly;
            bool showPrivateOnly = self.showPrivateOnly;
            bool showGroupsAndChannelsOnly = self.showGroupsAndChannelsOnly;
            bool showSecretInForwardMode = self.showSecretInForwardMode;
            
            TGUser *selfUser = [[TGDatabase instance] loadUser:TGTelegraphInstance.clientUserId];
            
            if ((forwardMode || privacyMode) && !showSecretInForwardMode)
            {
                for (int i = 0; i < (int)loadedItems.count; i++)
                {
                    id<TGDialogListItem> conversation = loadedItems[i];
                    if (conversation.isChannel && conversation.isChannelGroup && (!self.botStartMode || conversation.channelRole == TGChannelRoleCreator || conversation.channelRole == TGChannelRoleModerator || conversation.channelRole == TGChannelRolePublisher)) {
                        
                    } else if (TGPeerIdIsSecretChat(conversation.conversationId))
                    {
                        [loadedItems removeObjectAtIndex:i];
                        i--;
                    }
                }
            }
            
            if (forwardMode || privacyMode)
                OGCompatPruneItems(loadedItems, ^bool(id<TGDialogListItem> item) { return item.isBroadcast; });
            
            OGCompatPruneItems(loadedItems, ^bool(id<TGDialogListItem> item) { return item.isDeactivated; });
            OGCompatPruneItems(loadedItems, ^bool(id<TGDialogListItem> item) { return item.feedId.intValue != 0; });
            
            if (showGroupsOnly)
            {
                for (int i = 0; i < (int)loadedItems.count; i++)
                {
                    id<TGDialogListItem> conversation = loadedItems[i];
                    if (conversation.isChannel && conversation.isChannelGroup && (!self.botStartMode || conversation.channelRole == TGChannelRoleCreator || conversation.channelRole == TGChannelRoleModerator || conversation.channelRole == TGChannelRolePublisher)) {
                    } else if (TGPeerIdIsSecretChat(conversation.conversationId) || TGPeerIdIsUser(conversation.conversationId)) {
                        [loadedItems removeObjectAtIndex:i];
                        i--;
                    }
                }
            }
            
            if (showPrivateOnly)
            {
                for (int i = 0; i < (int)loadedItems.count; i++)
                {
                    id<TGDialogListItem> conversation = loadedItems[i];
                    if (!TGPeerIdIsUser(conversation.conversationId) || [self.excludedIds containsObject:@(conversation.conversationId)]) {
                        [loadedItems removeObjectAtIndex:i];
                        i--;
                    }
                }
            } else if (showGroupsAndChannelsOnly)
            {
                for (int i = 0; i < (int)loadedItems.count; i++)
                {
                    id<TGDialogListItem> conversation = loadedItems[i];
                    bool skip = false;
                    if ([conversation isKindOfClass:[TGConversation class]])
                    {
                        skip = ((TGConversation *)conversation).isDeleted || ((TGConversation *)conversation).isDeactivated || ((TGConversation *)conversation).leftChat || ((TGConversation *)conversation).kickedFromChat;
                    }
                    if ((!TGPeerIdIsGroup(conversation.conversationId) && !TGPeerIdIsChannel(conversation.conversationId)) || skip || [self.excludedIds containsObject:@(conversation.conversationId)]) {
                        [loadedItems removeObjectAtIndex:i];
                        i--;
                    }
                }
            }
            

            bool preloadConstrainedDialogUsers =
                !archiveListRequest && devicePerformanceClass() == TGPerformanceClassConstrained;

            if (preloadConstrainedDialogUsers)
            {
                [TGDatabaseInstance() preloadDialogListDependencies:loadedItems selfUserId:selfUser.uid];
                OGRuntimeDispatch(OGRuntimePriorityUtility, ^
                {
                    std::vector<int64_t> preloadContactUids;
                    [TGDatabaseInstance() loadRemoteContactUids:preloadContactUids];
                });
            }

            if (!archiveListRequest)
            {
                NSMutableArray *statePeerIds = [[NSMutableArray alloc] init];
                for (id<TGDialogListItem> item in loadedItems)
                {
                    if (statePeerIds.count >= 16)
                        break;
                    if ([item isKindOfClass:[TGConversation class]])
                        [statePeerIds addObject:@(((TGConversation *)item).conversationId)];
                }
                [TGDatabaseInstance() preloadConversationStates:statePeerIds];
            }
            
            if (archiveListRequest)
            {
                for (id<TGDialogListItem> item in loadedItems)
                {
                    if ([item isKindOfClass:[TGConversation class]])
                        ((TGConversation *)item).isArchived = true;
                }
            }
            else
            {
                CFAbsoluteTime initializeItemsStart = CFAbsoluteTimeGetCurrent();
                for (id<TGDialogListItem> conversation in loadedItems)
                {
                    [self initializeDialogListData:(TGConversation *)conversation
                                        customUser:nil
                                          selfUser:selfUser];
                }
                TGLog(@"STARTUPDIALOG initialize count=%d ms=%.1f", (int)loadedItems.count, (CFAbsoluteTimeGetCurrent() - initializeItemsStart) * 1000.0);
            }

            CFAbsoluteTime archiveStart = CFAbsoluteTimeGetCurrent();

            if (!archiveListRequest)
            {
                for (NSInteger i = (NSInteger)loadedItems.count - 1; i >= 0; i--)
                {
                    id candidate = [loadedItems objectAtIndex:(NSUInteger)i];
                    if (![candidate isKindOfClass:[TGConversation class]])
                        continue;
                    TGConversation *conversation = candidate;
                    if (conversation.pinnedDate != 0)
                        conversation.isArchived = false;
                    OGCompatDropConversation(_archivedConversations, conversation.conversationId);
                    if (conversation.isArchived)
                    {
                        [loadedItems removeObjectAtIndex:(NSUInteger)i];
                        [_archivedConversations insertObject:conversation atIndex:0];
                    }
                }
            }

            if (!archiveListRequest)
                TGLog(@"STARTUPDIALOG archive ms=%.1f", (CFAbsoluteTimeGetCurrent() - archiveStart) * 1000.0);

            if (archiveListRequest)
            {
                NSMutableSet *archivedPeerKeys = [NSMutableSet set];
                if (synchronizationNode == nil)
                    [_archivedConversations removeAllObjects];
                for (id<TGDialogListItem> item in loadedItems)
                {
                    if (![item isKindOfClass:[TGConversation class]])
                        continue;
                    TGConversation *conversation = (TGConversation *)item;
                    NSNumber *peerKey = @(conversation.conversationId);
                    if (![archivedPeerKeys containsObject:peerKey])
                    {
                        [archivedPeerKeys addObject:peerKey];
                        if (synchronizationNode != nil)
                        {
                            OGCompatDropConversation(_conversationList, conversation.conversationId);
                            OGCompatDropConversation(_archivedConversations, conversation.conversationId);
                        }
                        [_archivedConversations addObject:conversation];
                    }
                }

                NSArray *archiveSnapshot = [self og_compat_dialogListItems];
                _canLoadMore = canLoadMoreBefore;
                TGDispatchOnMainThread(^{
                    TGDialogListController *controller = self.dialogListController;
                    if (controller != nil)
                    {
                        controller.canLoadMore = canLoadMoreBefore;
                        [controller dialogListFullyReloaded:archiveSnapshot];
                    }
                });
                if (synchronizationComplete && _ogCompatFolderPreloadActive && _ogCompatFolderPreloadArchiveStage)
                {
                    [self og_compat_resetFolderPreloadState:false archiveStage:false];
                }
                return;
            }
            

            if (authoritativeMainSync)
                [_conversationList removeAllObjects];
            
            if (_conversationList.count == 0)
            {
                if (_adConversation != nil) {
                    [loadedItems addObject:_adConversation];
                }
                [_conversationList addObjectsFromArray:loadedItems];
            }
            else
            {
                std::set<int64_t> existingConversations;
                std::set<int32_t> existingFeeds;
                for (id<TGDialogListItem> conversation in _conversationList)
                {
                    existingConversations.insert(conversation.conversationId);
                }
                
                for (int i = 0; i < (int)loadedItems.count; i++)
                {
                    id<TGDialogListItem> conversation = [loadedItems objectAtIndex:i];
                    if (existingConversations.find(conversation.conversationId) != existingConversations.end())
                    {
                        if (synchronizationNode != nil)
                        {
                            for (NSUInteger index = 0; index < _conversationList.count; index++)
                            {
                                if (((id<TGDialogListItem>)_conversationList[index]).conversationId == conversation.conversationId)
                                {
                                    _conversationList[index] = conversation;
                                    break;
                                }
                            }
                        }
                        [loadedItems removeObjectAtIndex:i];
                        i--;
                    }
                }
                
                [_conversationList addObjectsFromArray:loadedItems];
            }
            if (archiveListRequest)
                canLoadMore = canLoadMoreBefore;
            else if (synchronizationNode != nil)
                canLoadMore = false;
            else if (authoritativeMainSync)
                canLoadMore = [TGDatabaseInstance() customProperty:@"dialogListLoaded"].length == 0;
            else
                canLoadMore = newPagedItemsCount != 0;
            
            [_conversationList sortUsingComparator:^NSComparisonResult(id<TGDialogListItem> conversation1, id<TGDialogListItem> conversation2)
            {
                return OGCompatDialogOrderPinnedFirst(conversation1, conversation2);
            }];
            
            
            for (int i = 0; i < (int)_conversationList.count; i++)
            {
                if ([_conversationList[i] isKindOfClass:[TGConversation class]] && ((TGConversation *)_conversationList[i]).conversationId == selfUser.uid && hideSelf)
                {
                    [_conversationList removeObjectAtIndex:i];
                    i--;
                }
            }
        
            if (forwardMode && !showGroupsOnly && !showPrivateOnly && !showGroupsAndChannelsOnly)
            {
                TGConversation *selfConversation = [self selfPeer];
                [_conversationList insertObject:selfConversation atIndex:0];
                [self initializeDialogListData:selfConversation customUser:nil selfUser:selfUser];
            }
            else
            {
                [self og_compat_ensureSavedMessagesPeerWithSelfUser:selfUser];
            }
            
            NSArray *items = [self og_compat_dialogListItems];
            
            _canLoadMore = canLoadMore;
            
            NSMutableArray *currentConversationIds = [self og_compat_dialogListItemIds];

            if (!archiveListRequest)
            {
                if (_ogCompatInitialWatchersDeferred)
                {
                    _ogCompatInitialWatchersDeferred = false;
                    [self resetWatchedNodePaths];
                    if (synchronizationNode != nil && !synchronizationNode.complete)
                        [ActionStageInstance() requestActor:path options:@{@"fullSync": @true, @"limit": @20} watcher:self];
                }
#if defined(ONEGRAM_ARMV6)
                [TGTelegraphInstance constrainedStartupDialogListReady];
#endif
            }
            
            if ([currentConversationIds isEqualToArray:conversationIds]) {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                for (id<TGDialogListItem> conversation in items) {
                    dict[@(conversation.conversationId)] = conversation;
                }
                TGDispatchOnMainThread(^{
                    TGDialogListController *controller = self.dialogListController;
                    controller.canLoadMore = canLoadMore;
                    if (currentConversationIds.count == 0) {
                        [controller dialogListFullyReloaded:items];
                    } else {
                        [controller updateConversations:dict];
                    }
                });
            } else {
                if (self.dialogListController.debugReady != nil)
                    self.dialogListController.debugReady();
                TGDispatchOnMainThread(^
                {
                    TGDialogListController *controller = self.dialogListController;
                    if (controller != nil)
                    {
                        controller.canLoadMore = canLoadMore;
                        
                        
                        [controller dialogListFullyReloaded:items];
                        

                        if (self.dialogListController.debugReady != nil)
                            self.dialogListController.debugReady();
                    }
                });
            }
            if (!archiveListRequest && !forwardMode && !privacyMode && !showGroupsOnly && !showPrivateOnly && !showGroupsAndChannelsOnly)
            {
                if (_canLoadMore)
                    [self og_compat_scheduleEagerDialogPageAfter:0.05];
                else if (canLoadMoreBefore)
                    NSLog(@"DIALOGS complete count=%d path=%@", (int)_conversationList.count, path);
            }

            if (!archiveListRequest && synchronizationComplete && _ogCompatFolderPreloadActive)
            {
                _ogCompatFolderPreloadRequestInFlight = false;
                _ogCompatFolderPreloadRetryScheduled = false;
                _ogCompatFolderPreloadRetryCount = 0;
                if (!_canLoadMore)
                    _ogCompatFolderPreloadArchiveStage = true;

                NSTimeInterval delay = 0.18;
                switch (devicePerformanceClass())
                {
                    case TGPerformanceClassConstrained: delay = 0.65; break;
                    case TGPerformanceClassBalanced: delay = 0.35; break;
                    case TGPerformanceClassFast: delay = 0.18; break;
                    case TGPerformanceClassHigh: delay = 0.10; break;
                }
                __weak TGTelegraphDialogListCompanion *weakSelf = self;
                OGPlatformDispatchOnMainThreadAfter(delay, ^
                {
                    __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
                    if (strongSelf != nil)
                        [strongSelf og_compat_continueFolderDialogPreload];
                });
            }

            if (!archiveListRequest && synchronizationComplete && !_ogCompatFolderPreloadActive && [TGDatabaseInstance() customProperty:@"ios6ArchivePeerIdsComplete"].length != 1)
                [self ios6PreloadAllDialogsForFolders];

            if (!archiveListRequest)
            {
                TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
                                {
                                    [ActionStageInstance() dispatchOnStageQueue:^
                                     {
                                         [self maybeLoadAd:nil];
                                     }];
                                });
            }
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                TGDispatchAfter(0.4, dispatch_get_main_queue(), ^
                {
                    [self dialogListReady];
                });
            });
        }
        else if (_ogCompatFolderPreloadActive)
        {
            _ogCompatFolderPreloadRequestInFlight = false;
            if (!_ogCompatFolderPreloadRetryScheduled)
            {
                _ogCompatFolderPreloadRetryScheduled = true;
                _ogCompatFolderPreloadRetryCount++;
                int retryCount = _ogCompatFolderPreloadRetryCount;
                NSTimeInterval delay = MIN(8.0, 0.5 * (1 << MIN(retryCount - 1, 4)));
                __weak TGTelegraphDialogListCompanion *weakSelf = self;
                OGPlatformDispatchOnMainThreadAfter(delay, ^
                {
                    __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
                    if (strongSelf != nil)
                    {
                        strongSelf->_ogCompatFolderPreloadRetryScheduled = false;
                        [strongSelf og_compat_continueFolderDialogPreload];
                    }
                });
            }
        }
    }
    else if ([path isEqualToString:@"/tg/service/synchronizationstate"])
    {
        int state = [((SGraphObjectNode *)result).object intValue];
        OGStartupDiagnosticsNetworkState(state);
        
        TGDialogListState newState;
        
        if (state & 2)
        {
            if (state & 4)
                newState = TGDialogListStateWaitingForNetwork;
            else {
                if (state & 16) {
                    newState = TGDialogListStateHasProxyIssues;
                }
                else if (state & 8) {
                    newState = TGDialogListStateConnectingToProxy;
                } else {
                    newState = TGDialogListStateConnecting;
                }
            }
        }
        else if (state & 1)
            newState = TGDialogListStateUpdating;
        else
            newState = TGDialogListStateNormal;

        TGDispatchOnMainThread(^
        {
            if (newState != _state)
            {
                _state = newState;
                if (newState == TGDialogListStateNormal)
                {
                    [self og_compat_continueFolderDialogPreload];
                    [self.dialogListController ios6SynchronizeDialogState];
                }
                
                __weak TGTelegraphDialogListCompanion *weakSelf = self;
                NSTimeInterval delay = newState == TGDialogListStateUpdating ? 2.0 : (newState == TGDialogListStateNormal || newState == TGDialogListStateWaitingForNetwork ? 0.0 : 1.5);
                SSignal *signal = [SSignal single:@(newState)];
                if (delay > 0.0)
                    signal = [[[SSignal complete] delay:delay onQueue:[SQueue mainQueue]] then:signal];
                [_stateDisposable setDisposable:[signal startWithNext:^(__unused id next)
                {
                    __strong TGTelegraphDialogListCompanion *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    NSString *title = nil;
                    if (newState == TGDialogListStateConnecting)
                    {
                        title = TGLocalized(@"State.Connecting");
                    }
                    else if (newState == TGDialogListStateConnectingToProxy || newState == TGDialogListStateHasProxyIssues)
                    {
                        if ((int)TGScreenSize().width == 320 || TGIsPad())
                            title = TGLocalized(@"State.Connecting");
                        else
                            title = TGLocalized(@"State.ConnectingToProxy");
                    }
                    else if (newState == TGDialogListStateUpdating)
                        title = TGLocalized(@"State.Updating");
                    else if (newState == TGDialogListStateWaitingForNetwork)
                        title = TGLocalized(@"State.WaitingForNetwork");
                    
                    TGDialogListController *dialogListController = strongSelf.dialogListController;
                    [dialogListController titleStateUpdated:title state:newState];
                }]];
            }
        });
    }
    else if ([path hasPrefix:@"/tg/loadConversationAndMessageForSearch/"])
    {
        TGDispatchOnMainThread(^
        {
            [_progressWindow dismiss:true];
            _progressWindow = nil;
            
            if (resultCode == ASStatusSuccess)
            {
                int64_t conversationId = [result[@"peerId"] longLongValue];
                TGConversation *conversation = result[@"conversation"];
                int32_t messageId = [result[@"messageId"] intValue];
                
                [[TGInterfaceManager instance] navigateToConversationWithId:conversationId conversation:conversation performActions:nil atMessage:@{@"mid": @(messageId)} clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:false animated:true];
            }
        });
    }
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)arguments
{
    bool hideSelf = self.forwardMode || self.showPrivateOnly || self.showGroupsAndChannelsOnly;
    
    if ([path hasPrefix:@"/tg/dialoglist"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path isEqualToString:@"/tg/peerUnseenMentionCounts"])
    {
        if (![resource isKindOfClass:[NSDictionary class]])
            return;
        NSMutableDictionary *updatedConversations = [[NSMutableDictionary alloc] init];
        for (NSMutableArray *list in @[_conversationList, _archivedConversations])
        {
            for (NSUInteger index = 0; index < list.count; index++)
            {
                id item = list[index];
                if (![item isKindOfClass:[TGConversation class]])
                    continue;
                TGConversation *conversation = item;
                NSNumber *count = resource[@(conversation.conversationId)];
                if (count == nil || conversation.unreadMentionCount == MAX(0, [count intValue]))
                    continue;
                TGConversation *updated = [conversation copy];
                updated.unreadMentionCount = MAX(0, [count intValue]);
                list[index] = updated;
                updatedConversations[@(updated.conversationId)] = updated;
            }
        }
        if (updatedConversations.count != 0)
        {
            TGDispatchOnMainThread(^
            {
                [self.dialogListController updateConversations:updatedConversations];
            });
        }
    }
    else if ([path hasPrefix:@"/tg/conversationsGrouped"])
    {
        NSMutableArray *conversations = ((SGraphObjectNode *)resource).object;
        bool animated = [path rangeOfString:@"(animated)"].location != NSNotFound;
        for (TGConversation *conversation in conversations)
        {
            [self deleteItem:conversation animated:animated interfaceOnly:true];
        }
    }
    else if ([path isEqualToString:@"/tg/conversations"] || [path isEqualToString:@"/tg/broadcastConversations"])
    {
        NSMutableArray *conversationIds = [self og_compat_dialogListItemIds];
        
        TGUser *selfUser = [[TGDatabase instance] loadUser:TGTelegraphInstance.clientUserId];
        
        NSMutableArray *conversations = [((SGraphObjectNode *)resource).object mutableCopy];
        
        if (_adConversation != nil) {
            NSMutableArray *additional = [[NSMutableArray alloc] init];
            for (TGConversation *conversation in conversations) {
                if (TGPeerIdIsChannel(conversation.conversationId) && TGAdIdFromPeerId(_adConversation.conversationId) == TGChannelIdFromPeerId(conversation.conversationId)) {
                    TGConversation *adConversation = [conversation copy];
                    adConversation.conversationId = TGPeerIdFromAdId(TGChannelIdFromPeerId(conversation.conversationId));
                    [additional addObject:adConversation];
                }
            }
            [conversations addObjectsFromArray:additional];
        }
        
        NSMutableDictionary *terminalConversations = [[NSMutableDictionary alloc] init];
        for (NSInteger i = 0; i < (NSInteger)conversations.count; i++) {
            TGConversation *conversation = conversations[i];
            
            if ((conversation.leftChat || conversation.kickedFromChat) && !conversation.isDeleted)
            {
                TGConversation *removedConversation = [conversation copy];
                removedConversation.isDeleted = true;
                conversations[i] = removedConversation;
                conversation = removedConversation;
            }

            if (conversation.isDeleted || conversation.isDeactivated || conversation.leftChat || conversation.kickedFromChat)
                terminalConversations[@(conversation.conversationId)] = conversation;

            bool isTemporaryChannel = conversation.isChannel && conversation.kind != TGConversationKindPersistentChannel && !conversation.isDeleted && !conversation.isDeactivated;
            bool isSavedMessages = conversation.conversationId == selfUser.uid && hideSelf;
            
            bool isAd = TGPeerIdIsAd(conversation.conversationId);
            
            if ((isTemporaryChannel || isSavedMessages) && !isAd) {
                [conversations removeObjectAtIndex:i];
                i--;
            }
        }
        
        TGDialogListController *controller = self.dialogListController;
        if (terminalConversations.count != 0)
        {
            TGDispatchOnMainThread(^
            {
                TGDialogListController *strongController = self.dialogListController;
                if (strongController != nil)
                    [strongController updateConversations:terminalConversations];
            });
        }
        if (controller.isDisplayingSearch)
        {
            NSMutableArray *searchConversations = [[NSMutableArray alloc] init];
            for (TGConversation *conversation in ((SGraphObjectNode *)resource).object)
            {
                TGConversation *copyConversation = [conversation copy];
                [self initializeDialogListData:copyConversation customUser:nil selfUser:selfUser];
                [searchConversations addObject:copyConversation];
            }
            TGDispatchOnMainThread(^
            {
                [controller updateSearchConversations:searchConversations];
            });
        }
        
        if ((self.forwardMode || self.privacyMode) && !self.showSecretInForwardMode)
        {
            for (int i = 0; i < (int)conversations.count; i++)
            {
                TGConversation *conversation = (TGConversation *)conversations[i];
                if (!(conversation.isChannel && conversation.isChannelGroup && (!self.botStartMode || conversation.channelRole == TGChannelRoleCreator || conversation.channelRole == TGChannelRoleModerator || conversation.channelRole == TGChannelRolePublisher))) {
                    if (TGPeerIdIsSecretChat(conversation.conversationId))
                    {
                        [conversations removeObjectAtIndex:i];
                        i--;
                    }
                }
            }
        }
        
        if (self.forwardMode || self.privacyMode)
        {
            for (int i = 0; i < (int)conversations.count; i++)
            {
                if (((TGConversation *)conversations[i]).isBroadcast)
                {
                    [conversations removeObjectAtIndex:i];
                    i--;
                }
            }
        }
        
        if (self.showGroupsOnly)
        {
            for (int i = 0; i < (int)conversations.count; i++)
            {
                TGConversation *conversation = conversations[i];
                if (conversation.isChannel && conversation.isChannelGroup && (!self.botStartMode || conversation.channelRole == TGChannelRoleCreator || conversation.channelRole == TGChannelRoleModerator || conversation.channelRole == TGChannelRolePublisher)) {
                    
                } else if (TGPeerIdIsSecretChat(conversation.conversationId) || TGPeerIdIsUser(conversation.conversationId)) {
                    [conversations removeObjectAtIndex:i];
                    i--;
                }
            }
        }
        
        if (conversations.count == 0)
            return;
        
        [conversations sortUsingComparator:^NSComparisonResult(id<TGDialogListItem> obj1, id<TGDialogListItem> obj2)
         {
             if (TGPeerIdIsAd(obj1.conversationId)) {
                 return NSOrderedAscending;
             } else if (TGPeerIdIsAd(obj2.conversationId)) {
                 return NSOrderedDescending;
             }
             
             int date1 = (int)((TGConversation *)obj1).date;
             int date2 = (int)((TGConversation *)obj2).date;
             
             if (date1 < date2)
                 return NSOrderedAscending;
             else if (date1 > date2)
                 return NSOrderedDescending;
             else
                 return NSOrderedSame;
         }];
        
        [self og_compat_applyArchivedConversationUpdates:conversations selfUser:selfUser];

        if (conversations.count == 1 && _conversationList.count != 0)
        {
            TGConversation *singleConversation = [conversations objectAtIndex:0];
            TGConversation *topConversation = ((TGConversation *)[_conversationList objectAtIndex:0]);
            if (!singleConversation.isDeleted && !singleConversation.isDeactivated && _conversationList.count > 0 && topConversation.conversationId == singleConversation.conversationId && (topConversation.date <= singleConversation.date || topConversation.unreadCount != singleConversation.unreadCount || (singleConversation.serviceUnreadCount != -1 && topConversation.serviceUnreadCount != singleConversation.serviceUnreadCount)))
            {
                [self initializeDialogListData:singleConversation customUser:nil selfUser:selfUser];
                [_conversationList replaceObjectAtIndex:0 withObject:singleConversation];
                
                TGDispatchOnMainThread(^
                {
                    TGDialogListController *dialogListController = self.dialogListController;
                    
                    [dialogListController dialogListItemsChanged:nil insertedItems:nil updatedIndices:[NSArray arrayWithObject:[[NSNumber alloc] initWithInt:0]] updatedItems:[NSArray arrayWithObject:singleConversation] removedIndices:nil];
                });
                
                return;
            }
        }
        
        std::map<int64_t, int> conversationIdToIndex;
        int index = -1;
        for (TGConversation *conversation in _conversationList)
        {
            index++;
            int64_t conversationId = conversation.conversationId;
            conversationIdToIndex.insert(std::pair<int64_t, int>(conversationId, index));
        }

        for (NSInteger i = (NSInteger)conversations.count - 1; i >= 0; i--)
        {
            TGConversation *conversation = conversations[(NSUInteger)i];
            if (conversationIdToIndex.find(conversation.conversationId) != conversationIdToIndex.end())
                continue;
            bool folderOnly = false;
            @synchronized (_ogCompatFolderOnlyHydrationPeerIds)
            {
                folderOnly = [_ogCompatFolderOnlyHydrationPeerIds containsObject:@(conversation.conversationId)];
            }
            if (folderOnly)
                [conversations removeObjectAtIndex:(NSUInteger)i];
        }
        
        NSMutableSet *addedPeerIds = [[NSMutableSet alloc] init];
        for (TGConversation *conversation in conversations) {
            if (conversationIdToIndex.find(conversation.conversationId) == conversationIdToIndex.end()) {
                [addedPeerIds addObject:@(conversation.conversationId)];
            }
        }
        
        NSMutableSet *candidatesForCutoff = [[NSMutableSet alloc] init];
        
        for (int i = 0; i < (int)conversations.count; i++)
        {
            TGConversation *conversation = [conversations objectAtIndex:i];
            int64_t conversationId = conversation.conversationId;
            std::map<int64_t, int>::iterator it = conversationIdToIndex.find(conversationId);
            if (it != conversationIdToIndex.end())
            {
                TGConversation *newConversation = [conversation copy];
                if (!newConversation.isDeleted && !newConversation.isDeactivated)
                    [self initializeDialogListData:newConversation customUser:nil selfUser:selfUser];
                
                TGConversation *previousConversation = _conversationList[(it->second)];
                
                if (newConversation.date < previousConversation.date) {
                    [candidatesForCutoff addObject:@(newConversation.conversationId)];
                }
                
                [_conversationList replaceObjectAtIndex:(it->second) withObject:newConversation];
                [conversations removeObjectAtIndex:i];
                i--;
            }
        }
        
        for (int i = 0; i < (int)_conversationList.count; i++)
        {
            TGConversation *conversation = [_conversationList objectAtIndex:i];
            if (TGPeerIdIsAd(conversation.conversationId)) {
                continue;
            }
            if (conversation.isDeleted || conversation.isDeactivated || conversation.feedId.intValue != 0)
            {
                [_conversationList removeObjectAtIndex:i];
                i--;
            }
        }
        
        for (TGConversation *conversation in conversations)
        {
            TGConversation *newConversation = [conversation copy];
            if (!newConversation.isDeleted && !newConversation.isDeactivated && newConversation.feedId.intValue == 0)
            {
                [self initializeDialogListData:newConversation customUser:nil selfUser:selfUser];
                
                [_conversationList addObject:newConversation];
            }
        }
        
        if (self.forwardMode)
        {
            TGConversation *conversation = [_conversationList firstObject];
            if (conversation.conversationId == selfUser.uid)
                [_conversationList removeObjectAtIndex:0];
        }
        
        [_conversationList sortUsingComparator:^NSComparisonResult(id<TGDialogListItem> obj1, id<TGDialogListItem> obj2)
         {
             return OGCompatDialogOrderPinnedFirst(obj1, obj2);
         }];

        [self og_compat_ensureSavedMessagesPeerWithSelfUser:selfUser];
        
        if ([arguments[@"filterEarliest"] boolValue] && _canLoadMore) {
            while (_conversationList.count != 0) {
                TGConversation *conversation = [_conversationList lastObject];
                if (conversation.isChannel) {
                    [_conversationList removeLastObject];
                } else {
                    break;
                }
            }
        }
        
        if (candidatesForCutoff.count != 0 && _canLoadMore) {
            for (NSInteger i = _conversationList.count - 1; i >= 0; i--) {
                TGConversation *conversation = _conversationList[i];
                if ([candidatesForCutoff containsObject:@(conversation.conversationId)]) {
                    [_conversationList removeObjectAtIndex:i];
                } else {
                    break;
                }
            }
        }
        
        if (_canLoadMore) {
            for (NSInteger i = _conversationList.count - 1; i >= 0; i--) {
                TGConversation *conversation = _conversationList[i];
                if ([addedPeerIds containsObject:@(conversation.conversationId)]) {
                    [_conversationList removeObjectAtIndex:i];
                } else {
                    break;
                }
            }
        }
        
        if (self.forwardMode && !self.showGroupsOnly && !self.showPrivateOnly && !self.showGroupsAndChannelsOnly)
        {
            TGConversation *selfConversation = [self selfPeer];
            [_conversationList insertObject:selfConversation atIndex:0];
            [self initializeDialogListData:selfConversation customUser:nil selfUser:selfUser];
        }
        
        NSMutableArray *currentConversationIds = [self og_compat_dialogListItemIds];
        NSArray *items = [self og_compat_dialogListItems];
        
        if ([currentConversationIds isEqualToArray:conversationIds]) {
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            for (TGConversation *conversation in items) {
                dict[@(conversation.conversationId)] = conversation;
            }
            TGDispatchOnMainThread(^{
                TGDialogListController *controller = self.dialogListController;
                [controller updateConversations:dict];
            });
        } else {
            TGDispatchOnMainThread(^
            {
                TGDialogListController *controller = self.dialogListController;
                if (controller != nil)
                {
                    [controller dialogListFullyReloaded:items];
                    if (!self.forwardMode && !self.privacyMode) {
                        [controller selectConversationWithId:[self openedConversationId]];
                    }
                }
            });
        }
    }
    else if ([path isEqualToString:@"/tg/userdatachanges"])
    {
        std::map<int64_t, int> userIdToIndex;
        int index = -1;
        NSArray *users = (((SGraphObjectNode *)resource).object);
        for (TGUser *user in users)
        {
            index++;
            userIdToIndex.insert(std::pair<int64_t, int>(user.uid, index));
        }
        
        TGUser *selfUser = [[TGDatabase instance] loadUser:TGTelegraphInstance.clientUserId];
        
        NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
        NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
        
        bool updateAllOutgoing = userIdToIndex.find(TGTelegraphInstance.clientUserId) != userIdToIndex.end();
        
        for (index = 0; index < (int)_conversationList.count; index++)
        {
            TGConversation *conversation = [_conversationList objectAtIndex:index];
            if (![conversation isKindOfClass:[TGConversation class]])
                continue;
            
            int64_t userId = 0;
            if (conversation.isEncrypted)
            {
                if (conversation.chatParticipants.chatParticipantUids.count != 0)
                    userId = [conversation.chatParticipants.chatParticipantUids[0] longLongValue];
            }
            else if (conversation.isChat)
                userId = conversation.outgoing ? TGTelegraphInstance.clientUserId : conversation.fromUid;
            else
                userId = conversation.conversationId;

            std::map<int64_t, int>::iterator it = userIdToIndex.find(userId);
            if (it != userIdToIndex.end() || (updateAllOutgoing && conversation.outgoing))
            {
                TGConversation *newConversation = [conversation copy];
                [self initializeDialogListData:newConversation customUser:(it != userIdToIndex.end() ? [users objectAtIndex:it->second] : nil) selfUser:selfUser];
                [_conversationList replaceObjectAtIndex:index withObject:newConversation];
                [updatedIndices addObject:[NSNumber numberWithInt:index]];
                [updatedItems addObject:newConversation];
            }
        }
        
        if (updatedIndices.count != 0)
        {
            TGDispatchOnMainThread(^
            {
                TGDialogListController *controller = self.dialogListController;
                if (controller != nil)
                    [controller dialogListItemsChanged:nil insertedItems:nil updatedIndices:updatedIndices updatedItems:updatedItems removedIndices:nil];
            });
        }
    }
    else if ([path isEqualToString:@"/tg/conversation/*/typing"])
    {
        NSDictionary *dict = ((SGraphObjectNode *)resource).object;
        int64_t conversationId = [[dict objectForKey:@"conversationId"] longLongValue];
        if (conversationId != 0)
        {
            NSDictionary *userActivities = [dict objectForKey:@"typingUsers"];
            NSString *typingString = nil;
            NSArray *typingUsers = userActivities.allKeys;
            if ((TGPeerIdIsGroup(conversationId) || TGPeerIdIsChannel(conversationId)) && typingUsers.count != 0)
            {
                NSMutableString *userNames = [[NSMutableString alloc] init];
                NSMutableArray *userNamesArray = [[NSMutableArray alloc] init];
                for (NSNumber *nUid in typingUsers)
                {
                    TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
                    if (userNames.length != 0)
                        [userNames appendString:@", "];
                    [userNames appendString:user.displayFirstName == nil ? @"" : user.displayFirstName];
                    if (user.displayFirstName != nil)
                        [userNamesArray addObject:user.displayFirstName];
                }
                
                if (userNamesArray.count == 1)
                {
                    typingString = [[NSString alloc] initWithFormat:[self formatForGroupActivity:userActivities[typingUsers[0]]], userNames];
                }
                else if (userNamesArray.count != 0)
                {
                    NSString *format = [TGStringUtils integerValueFormat:@"ForwardedAuthorsOthers_" value:userNamesArray.count - 1];
                    typingString = [[NSString alloc] initWithFormat:TGLocalized(format), userNamesArray[0], [[NSString alloc] initWithFormat:@"%d", (int)userNamesArray.count - 1]];
                }
            }
            else if (typingUsers.count != 0)
            {
                NSMutableString *userNames = [[NSMutableString alloc] init];
                for (NSNumber *nUid in typingUsers)
                {
                    TGUser *user = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
                    if (userNames.length != 0)
                        [userNames appendString:@", "];
                    [userNames appendString:user.displayFirstName == nil ? @"" : user.displayFirstName];
                }
                
                if (typingUsers.count == 1)
                {
                    typingString = [[NSString alloc] initWithFormat:[self formatForUserActivity:userActivities[typingUsers[0]]], userNames];
                }
                else
                    typingString = userNames;
            }
            
            TGDispatchOnMainThread(^
            {
                TGDialogListController *dialogListController = self.dialogListController;
                
                [dialogListController userTypingInConversationUpdated:conversationId typingString:typingString];
            });
        }
    }
    else if ([path isEqualToString:@"/tg/service/synchronizationstate"])
    {
        [self actorCompleted:ASStatusSuccess path:path result:resource];
    }
    else if ([path isEqualToString:@"/tg/unreadChatsCount"])
    {
        TGDispatchOnMainThread(^
        {
            [TGDatabaseInstance() dispatchOnDatabaseThread:^
            {
                int unreadChatsCount = [TGDatabaseInstance() unreadChatsCount];
                int unreadChannelsCount = [TGDatabaseInstance() unreadChannelsCount];
                if (unreadChatsCount == INT_MIN || unreadChannelsCount == INT_MIN)
                    return;
                int unreadCount = unreadChatsCount + unreadChannelsCount;
                TGDispatchOnMainThread(^
                {
                    if (![arguments[@"previous"] boolValue])
                        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:unreadCount];
                    if (unreadCount == 0)
                        OGPlatformCancelAllLocalNotifications([UIApplication sharedApplication]);
                    
                    self.unreadCount = unreadCount;
                    [TGAppDelegateInstance.rootController.mainTabsController setUnreadCount:unreadCount];
                    
                    TGDialogListController *dialogListController = self.dialogListController;
                    dialogListController.tabBarItem.badgeValue = unreadCount == 0 ? nil : [[NSString alloc] initWithFormat:@"%d", unreadCount];
                });
            } synchronous:false];
        });
    }
    else if ([path hasPrefix:@"/tg/peerSettings/"])
    {
        NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
        NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
        
        int64_t peerId = [[path substringWithRange:NSMakeRange(18, path.length - 1 - 18)] longLongValue];
        bool isPrivateDefault = peerId == TGPeerIdNotificationDefaultsPrivate;
        bool isGroupDefault = peerId == TGPeerIdNotificationDefaultsGroup;
        bool isChannelDefault = peerId == TGPeerIdNotificationDefaultsChannel;
        
        int count = (int)_conversationList.count;
        for (int i = 0; i < count; i++)
        {
            TGConversation *conversation = [_conversationList objectAtIndex:i];
            if (![conversation isKindOfClass:[TGConversation class]])
                continue;
            
            int64_t mutePeerId = conversation.conversationId;
            if (conversation.isEncrypted)
            {
                if (conversation.chatParticipants.chatParticipantUids.count != 0)
                    mutePeerId = [conversation.chatParticipants.chatParticipantUids[0] longLongValue];
            }
            
            bool isBroadcastChannel = TGPeerIdIsChannel(mutePeerId) && conversation.isChannel && !conversation.isChannelGroup;
            bool usesPrivateDefault = TGPeerIdIsUser(mutePeerId);
            bool usesChannelDefault = isBroadcastChannel;
            bool usesGroupDefault = !usesPrivateDefault && !usesChannelDefault;
            
            if (mutePeerId == peerId || (usesPrivateDefault && isPrivateDefault) || (usesGroupDefault && isGroupDefault) || (usesChannelDefault && isChannelDefault))
            {
                TGConversation *newConversation = [conversation copy];
                NSMutableDictionary *newData = [conversation.dialogListData mutableCopy];
                [newData setObject:[[NSNumber alloc] initWithBool:[TGDatabaseInstance() isPeerMuted:mutePeerId forceUpdate:true]] forKey:@"mute"];
                newConversation.dialogListData = newData;
                
                [_conversationList replaceObjectAtIndex:i withObject:newConversation];
                
                [updatedIndices addObject:[[NSNumber alloc] initWithInt:i]];
                [updatedItems addObject:newConversation];
                
                if (mutePeerId == peerId)
                    break;
            }
        }
        
        if (updatedItems.count != 0)
        {
            TGDispatchOnMainThread(^
            {
                TGDialogListController *dialogListController = self.dialogListController;
                [dialogListController dialogListItemsChanged:nil insertedItems:nil updatedIndices:updatedIndices updatedItems:updatedItems removedIndices:nil];
            });
        }
        [TGDatabaseInstance() transactionCalculateUnreadChats];
    }
    else if ([path isEqualToString:@"/tg/contactlist"])
    {
        NSMutableArray *updatedIndices = [[NSMutableArray alloc] init];
        NSMutableArray *updatedItems = [[NSMutableArray alloc] init];
        
        int index = -1;
        int count = (int)_conversationList.count;
        for (int i = 0; i < count; i++)
        {
            index++;
            
            TGConversation *conversation = [_conversationList objectAtIndex:i];
            if (![conversation isKindOfClass:[TGConversation class]])
                continue;
            
            if (!conversation.isChat)
            {
                TGUser *user = [TGDatabaseInstance() loadUser:conversation.conversationId];
                if (user == nil)
                    continue;
                
                NSString *title = [user displayName];
                bool isContact = [TGDatabaseInstance() uidIsRemoteContact:user.uid];
                bool titleChanged = title != nil && ![title isEqualToString:[conversation.dialogListData objectForKey:@"title"]];
                bool contactChanged = [conversation.dialogListData[@"isContact"] boolValue] != isContact;
                
                if (titleChanged || contactChanged)
                {
                    TGConversation *newConversation = [conversation copy];
                    NSMutableDictionary *newData = [conversation.dialogListData mutableCopy];
                    if (newData == nil)
                        newData = [[NSMutableDictionary alloc] init];
                    if (title != nil)
                        [newData setObject:title forKey:@"title"];
                    newData[@"isContact"] = @(isContact);
                    newConversation.dialogListData = newData;
                    
                    [_conversationList replaceObjectAtIndex:i withObject:newConversation];
                    
                    [updatedIndices addObject:[[NSNumber alloc] initWithInt:index]];
                    [updatedItems addObject:newConversation];
                }
            }
        }
        
        if (updatedItems.count != 0)
        {
            TGDispatchOnMainThread(^
            {
                TGDialogListController *dialogListController = self.dialogListController;
                [dialogListController dialogListItemsChanged:nil insertedItems:nil updatedIndices:updatedIndices updatedItems:updatedItems removedIndices:nil];
            });
        }
    }
    else if ([path isEqualToString:@"/databasePasswordChanged"])
    {
        TGDispatchOnMainThread(^
        {
            TGDialogListController *controller = self.dialogListController;
            [controller updateDatabasePassword];
        });
    }
}

- (NSString *)formatForGroupActivity:(NSString *)activity
{
    if ([activity isEqualToString:@"recordingAudio"])
        return TGLocalized(@"DialogList.SingleRecordingAudioSuffix");
    else if ([activity isEqualToString:@"recordingVideoMessage"])
        return TGLocalized(@"DialogList.SingleRecordingVideoMessageSuffix");
    else if ([activity isEqualToString:@"uploadingPhoto"])
        return TGLocalized(@"DialogList.SingleUploadingPhotoSuffix");
    else if ([activity isEqualToString:@"uploadingVideo"])
        return TGLocalized(@"DialogList.SingleUploadingVideoSuffix");
    else if ([activity isEqualToString:@"uploadingDocument"])
        return TGLocalized(@"DialogList.SingleUploadingFileSuffix");
    else if ([activity isEqualToString:@"playingGame"])
        return TGLocalized(@"DialogList.SinglePlayingGameSuffix");
    
    return TGLocalized(@"DialogList.SingleTypingSuffix");
}

- (NSString *)formatForUserActivity:(NSString *)activity
{
    if ([activity isEqualToString:@"recordingAudio"])
        return TGLocalized(@"Activity.RecordingAudio");
    else if ([activity isEqualToString:@"recordingVideoMessage"])
        return TGLocalized(@"Activity.RecordingVideoMessage");
    else if ([activity isEqualToString:@"uploadingPhoto"])
        return TGLocalized(@"Activity.UploadingPhoto");
    else if ([activity isEqualToString:@"uploadingVideo"])
        return TGLocalized(@"Activity.UploadingVideo");
    else if ([activity isEqualToString:@"uploadingDocument"])
        return TGLocalized(@"Activity.UploadingDocument");
    else if ([activity isEqualToString:@"playingGame"])
        return TGLocalized(@"Activity.PlayingGame");
    
    return TGLocalized(@"DialogList.Typing");
}

@end
