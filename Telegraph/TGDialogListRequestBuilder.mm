#import "TGDialogListRequestBuilder.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTelegraph.h"

#import "TGMessage+Telegraph.h"
#import "TGConversation+Telegraph.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphListNode.h"

#import "TGUserDataRequestBuilder.h"

#import "TGDatabase.h"
#import "TGTelegramNetworking.h"
#import "TGTimer.h"
#import "TLPeerNotifySettings$peerNotifySettings.h"
#import "TLChat$chat.h"
#import "TLInputChannel.h"
#import "TLmessages_Dialogs.h"

#include <set>

#import "TGDownloadMessagesSignal.h"

#import "TLUser$modernUser.h"

#import "TGFeedPosition.h"
#import "TGCommunitySignals.h"
#import "../OnegramRuntime/OGRemoteClock.h"

static const int32_t OGCompatDialogListCacheRevision = 14;

static int32_t OGCompatReadInt32Property(NSString *name)
{
    NSData *data = [TGDatabaseInstance() customProperty:name];
    int32_t value = 0;
    if (data.length == sizeof(value))
        [data getBytes:&value length:sizeof(value)];
    return value;
}

static void OGCompatWriteInt32Property(NSString *name, int32_t value)
{
    [TGDatabaseInstance() setCustomProperty:name value:[NSData dataWithBytes:&value length:sizeof(value)]];
}

static void OGCompatClearProperty(NSString *name)
{
    [TGDatabaseInstance() setCustomProperty:name value:nil];
}

static void OGCompatSetEmptyProperty(NSString *name)
{
    [TGDatabaseInstance() setCustomProperty:name value:[NSData data]];
}

static void OGCompatLoadDialogListHead(void (^completion)(NSArray *))
{
    [TGDatabaseInstance() loadConversationListFromDate:INT_MAX limit:50 excludeConversationIds:@[] folderId:0 completion:^(NSArray *result, __unused bool loadedAllRegular)
    {
        completion(result);
    }];
}

static void OGCompatSetFlagProperty(NSString *name)
{
    uint8_t flag = 1;
    [TGDatabaseInstance() setCustomProperty:name value:[NSData dataWithBytes:&flag length:1]];
}

static void OGCompatPrepareDialogListCache()
{
    if (OGCompatReadInt32Property(@"ios6DialogListCacheVersion") == OGCompatDialogListCacheRevision)
        return;

    if (OGCompatReadInt32Property(@"ios6DialogListCachePendingVersion") == OGCompatDialogListCacheRevision)
        return;

    for (NSString *name in @[@"dialogListLoaded", @"dialogListRemoteOffset", @"dialogListHash", @"ios6ArchivePeerIds", @"ios6ArchivePeerIdsComplete"])
        [TGDatabaseInstance() setCustomProperty:name value:nil];
    OGCompatWriteInt32Property(@"ios6DialogListCachePendingVersion", OGCompatDialogListCacheRevision);
    OGCompatSetFlagProperty(@"ios6DialogListNeedsRemoteRefresh");
    [TGDatabaseInstance() removeLegacyContactRegisteredMessages];
}

static void OGCompatCommitDialogListCache()
{
    OGCompatWriteInt32Property(@"ios6DialogListCacheVersion", OGCompatDialogListCacheRevision);
    [TGDatabaseInstance() setCustomProperty:@"ios6DialogListCachePendingVersion" value:nil];
}

static void OGCompatStoreHydratedDialogMessages(NSArray *messages, NSSet *pendingHydrationMessageKeys)
{
    NSMutableArray *regularMessages = [[NSMutableArray alloc] init];
    NSMutableDictionary *channelMessages = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *feedMessages = [[NSMutableDictionary alloc] init];

    for (TGMessage *message in messages)
    {
        if (![message isKindOfClass:[TGMessage class]] || message.cid == 0 || message.mid == 0)
            continue;

        NSString *messageKey = [[NSString alloc] initWithFormat:@"%lld:%d", message.cid, message.mid];
        if (![pendingHydrationMessageKeys containsObject:messageKey])
            continue;

        bool hasHydratedReply = false;
        for (id attachment in message.mediaAttachments)
        {
            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]] && ((TGReplyMessageMediaAttachment *)attachment).replyMessage != nil)
            {
                hasHydratedReply = true;
                break;
            }
        }
        if (!hasHydratedReply)
            continue;

        NSNumber *peerKey = @(message.cid);
        if (TGPeerIdIsFeed(message.cid))
        {
            NSNumber *feedKey = @(TGFeedIdFromPeerId(message.cid));
            NSMutableArray *peerMessages = feedMessages[feedKey];
            if (peerMessages == nil)
            {
                peerMessages = [[NSMutableArray alloc] init];
                feedMessages[feedKey] = peerMessages;
            }
            [peerMessages addObject:message];
        }
        else if (TGPeerIdIsChannel(message.cid))
        {
            NSMutableArray *peerMessages = channelMessages[peerKey];
            if (peerMessages == nil)
            {
                peerMessages = [[NSMutableArray alloc] init];
                channelMessages[peerKey] = peerMessages;
            }
            [peerMessages addObject:message];
        }
        else
        {
            [regularMessages addObject:message];
        }
    }

    if (regularMessages.count == 0 && channelMessages.count == 0 && feedMessages.count == 0)
        return;

    [TGDatabaseInstance() performStorageBatch:^
    {
        if (regularMessages.count != 0)
            [TGDatabaseInstance() transactionAddMessages:regularMessages updateConversationDatas:nil notifyAdded:false];

        [channelMessages enumerateKeysAndObjectsUsingBlock:^(NSNumber *peerKey, NSArray *peerMessages, __unused BOOL *stop)
        {
            [TGDatabaseInstance() addMessagesToChannel:[peerKey longLongValue] messages:peerMessages deleteMessages:nil unimportantGroups:nil addedHoles:nil removedHoles:nil removedUnimportantHoles:nil updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:true skipFeedUpdate:true changedMessages:nil];
        }];

        [feedMessages enumerateKeysAndObjectsUsingBlock:^(NSNumber *feedKey, NSArray *peerMessages, __unused BOOL *stop)
        {
            [TGDatabaseInstance() addMessagesToFeed:[feedKey intValue] messages:peerMessages deleteMessages:nil addedHoles:nil removedHoles:nil keepUnreadCounters:true changedMessages:nil];
        }];
    }];
}

static void OGCompatStoreNotifySettings(int64_t peerId, TLPeerNotifySettings *settings)
{
    if (![settings isKindOfClass:[TLPeerNotifySettings$peerNotifySettings class]])
        return;

    TLPeerNotifySettings$peerNotifySettings *concreteSettings = (TLPeerNotifySettings$peerNotifySettings *)settings;
    NSNumber *peerSoundId = nil;
    NSNumber *peerMuteUntil = nil;
    NSNumber *peerPreviewText = nil;
    NSNumber *messagesMuted = nil;

    if (concreteSettings.flags & (1 << 0))
        peerPreviewText = @(concreteSettings.showPreviews);
    if (concreteSettings.flags & (1 << 1))
        messagesMuted = @(concreteSettings.silent);
    if (concreteSettings.flags & (1 << 2))
        peerMuteUntil = concreteSettings.mute_until > OGRemoteClockTime() ? @(concreteSettings.mute_until) : @0;
    if (concreteSettings.flags & (1 << 3))
    {
        NSString *sound = concreteSettings.sound;
        if (sound.length == 0)
            peerSoundId = @(0);
        else if ([sound isEqualToString:@"default"])
            peerSoundId = @(1);
        else
            peerSoundId = @([sound intValue]);
    }

    [TGDatabaseInstance() storePeerNotificationSettings:peerId soundId:peerSoundId muteUntil:peerMuteUntil previewText:peerPreviewText messagesMuted:messagesMuted writeToActionQueue:false completion:nil];
}

static NSArray *OGCompatMessagesByAscendingSortKey(NSArray *messages)
{
    return [messages sortedArrayUsingComparator:^NSComparisonResult(TGMessage *lhs, TGMessage *rhs) {
        int result = TGMessageTransparentSortKeyCompare(lhs.transparentSortKey, rhs.transparentSortKey);
        return result > 0 ? NSOrderedAscending : (result < 0 ? NSOrderedDescending : NSOrderedSame);
    }];
}

static const int TGDialogListSynchronizationPageLimit = 50;

@interface TGDialogListRequestBuilder ()
{
    std::set<int64_t> _ignoreConversationIds;
    NSArray *_cutoffConversations;
    int _remotePageLimit;
    int32_t _dialogFolderId;
    bool _fullSync;
    bool _streaming;
    bool _synchronizationFinished;
    bool _synchronizationFinalPage;
    bool _synchronizationPinnedPage;
    bool _synchronizationRequestPinnedPage;
    NSUInteger _synchronizationRetryCount;
    TGTimer *_synchronizationRetryTimer;
    int64_t _synchronizationUserId;
    int32_t _synchronizationStartDate;
    NSSet *_synchronizationInitialPeerIds;
    NSMutableSet *_synchronizationPeerIds;
    NSMutableArray *_synchronizationPinnedPeerIds;
    TGDialogListRemoteOffset *_synchronizationOffset;
    TLInputPeer *_synchronizationInputPeer;
    TGDialogListSynchronizationNode *_synchronizationPageNode;
}

@property (nonatomic) bool replaceList;

- (void)processSynchronizationPage:(TLmessages_Dialogs *)dialogs complete:(bool)complete pinned:(bool)pinned;
- (void)requestNextSynchronizationPage;
- (void)retrySynchronizationPageAfterError:(NSError *)error;

@end

@implementation TGDialogListSynchronizationNode
@end

@implementation TGDialogListRequestBuilder

- (bool)synchronizationIsActive
{
    return _streaming && !_synchronizationFinished && !self.cancelled && TGTelegraphInstance.clientUserId == _synchronizationUserId && TGTelegraphInstance.clientIsActivated;
}

- (void)retrySynchronizationPageAfterError:(NSError *)error
{
    if (![self synchronizationIsActive])
        return;
    self.cancelToken = nil;
    bool transient = [error.domain isEqualToString:@"TGDialogListRPC"] && (error.code < 0 || error.code == 420 || error.code >= 500);
    if (!transient || _synchronizationRetryCount >= 5)
    {
        TGLog(@"DIALOGS synchronization failed folder=%d code=%ld reason=%@", _dialogFolderId, (long)error.code, error.localizedDescription);
        [self dialogListRequestFailed];
        return;
    }
    NSTimeInterval delay = MAX(2.0 * (1 << _synchronizationRetryCount), [error.userInfo[@"retryAfter"] doubleValue]);
    _synchronizationRetryCount++;
    [_synchronizationRetryTimer invalidate];
    __weak TGDialogListRequestBuilder *weakSelf = self;
    _synchronizationRetryTimer = [[TGTimer alloc] initWithTimeout:delay repeat:false completion:^
    {
        __strong TGDialogListRequestBuilder *strongSelf = weakSelf;
        if (strongSelf != nil && [strongSelf synchronizationIsActive])
        {
            strongSelf->_synchronizationRetryTimer = nil;
            [strongSelf requestNextSynchronizationPage];
        }
    } queue:[ActionStageInstance() globalStageDispatchQueue]];
    OGPlatformDiagnosticLog(@"DIALOGS page retry folder=%d pinned=%d attempt=%u delay=%.0f code=%ld", _dialogFolderId, _synchronizationRequestPinnedPage ? 1 : 0, (unsigned int)_synchronizationRetryCount, delay, (long)error.code);
    [_synchronizationRetryTimer start];
}

- (void)requestNextSynchronizationPage
{
    if (![self synchronizationIsActive])
        return;
    void (^failure)(NSError *) = ^(NSError *error)
    {
        [ActionStageInstance() dispatchOnStageQueue:^{ [self retrySynchronizationPageAfterError:error]; }];
    };
    if (_synchronizationRequestPinnedPage)
    {
        self.cancelToken = [TGTelegraphInstance ios6RequestPinnedDialogsForFolderId:_dialogFolderId completion:^(TLmessages_PeerDialogs *pinnedDialogs)
        {
            [ActionStageInstance() dispatchOnStageQueue:^
            {
                if (![self synchronizationIsActive])
                    return;
                _synchronizationRetryCount = 0;
                TLmessages_Dialogs$messages_dialogsSlice *page = [[TLmessages_Dialogs$messages_dialogsSlice alloc] init];
                page.dialogs = pinnedDialogs.dialogs;
                page.messages = pinnedDialogs.messages;
                page.chats = pinnedDialogs.chats;
                page.users = pinnedDialogs.users;
                _synchronizationRequestPinnedPage = false;
                [self requestNextSynchronizationPage];
                [self processSynchronizationPage:page complete:false pinned:true];
            }];
        } failure:failure];
        return;
    }
    self.cancelToken = [TGTelegraphInstance requestDialogsPageWithOffset:_synchronizationOffset inputPeer:_synchronizationInputPeer limit:_remotePageLimit folderId:_dialogFolderId completion:^(TLmessages_Dialogs *dialogs, TGDialogListRemoteOffset *nextOffset, TLInputPeer *nextPeer, bool hasMore)
    {
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (![self synchronizationIsActive])
                return;
            _synchronizationRetryCount = 0;
            _synchronizationOffset = nextOffset;
            _synchronizationInputPeer = nextPeer;
            if (hasMore)
            {
                _remotePageLimit = MAX(_remotePageLimit, TGDialogListSynchronizationPageLimit);
                [self requestNextSynchronizationPage];
            }
            [self processSynchronizationPage:dialogs complete:!hasMore pinned:false];
        }];
    } failure:failure];
}

- (void)processSynchronizationPage:(TLmessages_Dialogs *)dialogs complete:(bool)complete pinned:(bool)pinned
{
    if (![self synchronizationIsActive])
        return;
    [TGDatabaseInstance() dispatchOnDatabaseThread:^
    {
        if (![self synchronizationIsActive])
            return;
        _synchronizationFinalPage = complete;
        _synchronizationPinnedPage = pinned;
        [TGDatabaseInstance() performStorageBatch:^
        {
            [self dialogListRequestSuccess:dialogs];
        }];
        TGDialogListSynchronizationNode *node = _synchronizationPageNode;
        _synchronizationPageNode = nil;
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (![self synchronizationIsActive])
                return;
            [ActionStageInstance() dispatchResource:@"/dialogListReloaded" resource:@true];
            TGLog(@"DIALOGS page committed folder=%d items=%d complete=%d", _dialogFolderId, (int)node.items.count, complete ? 1 : 0);
            if (complete)
            {
                _synchronizationFinished = true;
                [_synchronizationRetryTimer invalidate];
                _synchronizationRetryTimer = nil;
                self.cancelToken = nil;
                [ActionStageInstance() dispatchResource:self.path resource:node];
                [ActionStageInstance() nodeRetrieved:self.path node:node];
            }
            else
            {
                [ActionStageInstance() dispatchResource:self.path resource:node];
            }
        }];
    } synchronous:false];
}

- (void)startDialogListSynchronizationWithLimit:(int)limit folderId:(int32_t)folderId
{
    if (_streaming || self.cancelled)
        return;
    _streaming = true;
    _synchronizationPinnedPage = true;
    _synchronizationRequestPinnedPage = true;
    _replaceList = false;
    _dialogFolderId = folderId;
    _remotePageLimit = MAX(1, limit);
    _synchronizationUserId = TGTelegraphInstance.clientUserId;
    _synchronizationStartDate = (int32_t)OGRemoteClockTime();
    _synchronizationPeerIds = [[NSMutableSet alloc] init];
    _synchronizationPinnedPeerIds = [[NSMutableArray alloc] init];
    _synchronizationOffset = [[TGDialogListRemoteOffset alloc] initWithDate:0 peerId:0 accessHash:0 messageId:0];
    [TGDatabaseInstance() loadDialogListSynchronizationPeerIdsForFolder:folderId completion:^(NSSet *peerIds)
    {
        if (![self synchronizationIsActive])
            return;
        if (folderId == 0)
        {
            OGCompatClearProperty(@"dialogListLoaded");
            OGCompatSetFlagProperty(@"ios6DialogListNeedsRemoteRefresh");
        }
        else
            OGCompatClearProperty(@"ios6ArchivePeerIdsComplete");
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            if (![self synchronizationIsActive])
                return;
            _synchronizationInitialPeerIds = peerIds;
            [self requestNextSynchronizationPage];
        }];
    }];
}

- (void)cancel
{
    [_synchronizationRetryTimer invalidate];
    _synchronizationRetryTimer = nil;
    [super cancel];
    if (self.cancelToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        self.cancelToken = nil;
    }
}

+ (NSString *)genericPath
{
    return @"/tg/dialoglist/@";
}

- (void)prepare:(NSDictionary *)options
{
    if (![[options objectForKey:@"inline"] boolValue] && ![[options objectForKey:@"fullSync"] boolValue] && [options objectForKey:@"date"] == nil)
    {
        self.requestQueueName = @"messages";
    }
}

static int OGCompatDialogLimit(NSNumber *limitOption, int fallback)
{
    return limitOption == nil ? fallback : MAX(1, [limitOption intValue]);
}

- (void)_requestRemotePageFromOffset:(TGDialogListRemoteOffset *)offset limit:(int)limit
{
    _remotePageLimit = limit;
    self.cancelToken = [TGTelegraphInstance doRequestDialogsListWithOffset:offset limit:_remotePageLimit folderId:_dialogFolderId requestArchive:(_dialogFolderId == 0) requestBuilder:self];
}

- (void)_restartFromListHead
{
    _replaceList = true;
    [self _requestRemotePageFromOffset:nil limit:50];
}

- (TGDialogListRemoteOffset *)_storedRemoteOffset
{
    NSData *data = [TGDatabaseInstance() customProperty:@"dialogListRemoteOffset"];
    TGDialogListRemoteOffset *remoteOffset = data.length == 0 ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (remoteOffset == nil)
        remoteOffset = [[TGDialogListRemoteOffset alloc] initWithDate:[TGDatabaseInstance() loadConversationListRemoteOffsetDate] peerId:0 accessHash:0 messageId:0];
    return remoteOffset;
}

- (void)execute:(NSDictionary *)__unused options
{
    NSNumber *date = [options objectForKey:@"date"];
    NSNumber *force = [options objectForKey:@"force"];
    NSNumber *limitOption = [options objectForKey:@"limit"];
    _dialogFolderId = [[options objectForKey:@"folderId"] intValue];
    TGLog(@"DIALOGS execute path=%@ folder=%d date=%@ limit=%@ force=%d fullSync=%d", self.path, _dialogFolderId, date, limitOption, [force boolValue], [[options objectForKey:@"fullSync"] boolValue]);
    if (TGTelegraphInstance.clientUserId == 0 || !TGTelegraphInstance.clientIsActivated)
    {
        int localLimit = OGCompatDialogLimit(limitOption, 50);
        NSArray *excludeConversationIds = options[@"excludeConversationIds"];
        if (excludeConversationIds == nil)
            excludeConversationIds = @[];
        [TGDatabaseInstance() loadConversationListFromDate:INT_MAX limit:localLimit excludeConversationIds:excludeConversationIds folderId:_dialogFolderId completion:^(NSArray *result, __unused bool loadedAllRegular)
        {
            [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphListNode alloc] initWithItems:result ?: @[]]];
        }];
        return;
    }
    if (_dialogFolderId == 0)
        OGCompatPrepareDialogListCache();
    bool fullSyncRequested = [[options objectForKey:@"fullSync"] boolValue];
    _fullSync = _dialogFolderId == 0 && fullSyncRequested;

    if (_fullSync)
    {
        _replaceList = true;
        _remotePageLimit = OGCompatDialogLimit(limitOption, 100);
        self.cancelToken = [TGTelegraphInstance doRequestCompleteDialogsListWithLimit:_remotePageLimit folderId:0 requestArchive:true requestBuilder:self];
    }
    else if (date == nil)
    {
        _replaceList = true;
        [self _requestRemotePageFromOffset:nil limit:OGCompatDialogLimit(limitOption, 50)];
    }
    else if (force != nil)
    {
        TGDialogListRemoteOffset *remoteOffset = [self _storedRemoteOffset];
        
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [self _requestRemotePageFromOffset:remoteOffset limit:50];
        }];
    }
    else
    {        
        int localLimit = OGCompatDialogLimit(limitOption, 50);
        [TGDatabaseInstance() loadConversationListFromDate:[date intValue] limit:localLimit excludeConversationIds:options[@"excludeConversationIds"] folderId:_dialogFolderId background:[options[@"background"] boolValue] completion:^(NSArray *result, bool loadedAllRegular)
        {
            bool dialogListLoaded = [TGDatabaseInstance() customProperty:@"dialogListLoaded"].length != 0;
            bool needsRemoteRefresh = _dialogFolderId == 0 && [TGDatabaseInstance() customProperty:@"ios6DialogListNeedsRemoteRefresh"].length != 0;
            TGLog(@"DIALOGS local path=%@ count=%d loadedAll=%d listLoaded=%d needsRefresh=%d", self.path, (int)result.count, loadedAllRegular ? 1 : 0, dialogListLoaded ? 1 : 0, needsRemoteRefresh ? 1 : 0);
            
            NSMutableArray *filteredResult = [[NSMutableArray alloc] initWithArray:result];
            [filteredResult sortUsingComparator:^NSComparisonResult(TGConversation *lhs, TGConversation *rhs) {
                if (lhs.date > rhs.date) {
                    return NSOrderedAscending;
                } else if (lhs.date < rhs.date) {
                    return NSOrderedDescending;
                } else {
                    if (lhs.conversationId < rhs.conversationId) {
                        return NSOrderedDescending;
                    } else {
                        return NSOrderedAscending;
                    }
                }
            }];
            
            _cutoffConversations = nil;
            
            const bool forced = [force boolValue];
            if (filteredResult.count != 0 && (!forced || dialogListLoaded)) {
                [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphListNode alloc] initWithItems:filteredResult]];
                
                int32_t dateValue = date != nil ? [date intValue] : 0;
                if ((dateValue <= 0 || dateValue == INT_MAX) && (dialogListLoaded || needsRemoteRefresh))
                {
                    [ActionStageInstance() dispatchOnStageQueue:^
                    {
                        [self _restartFromListHead];
                    }];
                }
            } else {
                if (_dialogFolderId == 0 && dialogListLoaded && loadedAllRegular)
                {
                    [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphListNode alloc] initWithItems:@[]]];
                    int32_t dateValue = [date intValue];
                    if (dateValue <= 0 || dateValue == INT_MAX)
                    {
                        [ActionStageInstance() dispatchOnStageQueue:^
                        {
                            [self _restartFromListHead];
                        }];
                    }
                    return;
                }
                TGDialogListRemoteOffset *remoteOffset = [self _storedRemoteOffset];
                
                [ActionStageInstance() dispatchOnStageQueue:^
                {
                    for (NSNumber *nConversationId in options[@"excludeConversationIds"])
                    {
                        _ignoreConversationIds.insert([nConversationId longLongValue]);
                    }
                    
                    [self _requestRemotePageFromOffset:remoteOffset limit:localLimit];
                }];
            }
        }];
    }
}

- (void)dialogListRequestSuccess:(TLmessages_Dialogs *)dialogs
{
    TGLog(@"DIALOGS remote path=%@ dialogs=%d messages=%d chats=%d users=%d", self.path, (int)dialogs.dialogs.count, (int)dialogs.messages.count, (int)dialogs.chats.count, (int)dialogs.users.count);
    [TGUserDataRequestBuilder executeUserDataUpdate:dialogs.users];
    
    [TGCommunitySignals storeCommunitiesFromChats:dialogs.chats];

    NSMutableDictionary *chatItems = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *channelItems = [[NSMutableDictionary alloc] init];
    
    for (TLChat *chatDesc in dialogs.chats)
    {
        TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chatDesc];
        if (TGPeerIdIsChannel(conversation.conversationId) || TGPeerIdIsGroup(conversation.conversationId))
            [TGDatabaseInstance() setConversationCustomProperty:conversation.conversationId name:murMurHash32(@"ios6InvalidPeer") value:nil];
        if (conversation.conversationId != 0) {
            if (conversation.isChannel) {
                channelItems[@(conversation.conversationId)] = conversation;
            } else {
                [chatItems setObject:conversation forKey:[NSNumber numberWithLongLong:conversation.conversationId]];
            }
        }
    }
    
    NSMutableArray *parsedMessages = [[NSMutableArray alloc] init];
    
    NSMutableDictionary *messagesDict = [[NSMutableDictionary alloc] init];
    id replyPreload = [TGMessage beginReplyPreloadForTelegraphMessageDescs:dialogs.messages];
    for (TLMessage *messageDesc in dialogs.messages)
    {
        TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:messageDesc];
        if (message.mid != 0)
        {
            [parsedMessages addObject:message];
        }
    }
    [TGMessage endReplyPreload:replyPreload];
    
    void (^processDialogs)(NSArray *) = ^(NSArray *completeMessages)
    {
        NSMutableDictionary *multipleMessagesByConversation = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *resetPeerUnseenMentionsStates = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *updatePeerDrafts = [[NSMutableDictionary alloc] init];
        
        for (TGMessage *message in completeMessages)
        {
            if (!TGPeerIdIsChannel(message.cid)) {
                [messagesDict setObject:message forKey:[NSNumber numberWithInt:message.mid]];
            } else {
                NSMutableArray *array = multipleMessagesByConversation[@(message.cid)];
                if (array == nil) {
                    array = [[NSMutableArray alloc] init];
                    multipleMessagesByConversation[@(message.cid)] = array;
                }
                [array addObject:message];
            }
        }
        
        NSMutableArray *conversations = [[NSMutableArray alloc] init];
        NSMutableArray *channels = [[NSMutableArray alloc] init];
        NSMutableArray *feeds = [[NSMutableArray alloc] init];
        
        NSMutableArray *pinnedPeerIds = [[NSMutableArray alloc] init];
        

        NSMutableSet *preloadPeerIds = [[NSMutableSet alloc] init];
        for (TLDialog *baseDialog in dialogs.dialogs)
        {
            if (![baseDialog isKindOfClass:[TLDialog$dialogMeta class]])
                continue;

            TLDialog$dialogMeta *dialog = (TLDialog$dialogMeta *)baseDialog;
            if ([dialog.peer isKindOfClass:[TLPeer$peerUser class]])
                [preloadPeerIds addObject:@(((TLPeer$peerUser *)dialog.peer).user_id)];
            else if ([dialog.peer isKindOfClass:[TLPeer$peerChat class]])
                [preloadPeerIds addObject:@(-((TLPeer$peerChat *)dialog.peer).chat_id)];
            else if ([dialog.peer isKindOfClass:[TLPeer$peerChannel class]])
                [preloadPeerIds addObject:@(TGPeerIdFromChannelId(((TLPeer$peerChannel *)dialog.peer).channel_id))];
        }

        [TGDatabaseInstance() preloadConversationCustomProperties:preloadPeerIds.allObjects];
        [TGDatabaseInstance() beginStorageBatch];

        for (TLDialog *baseDialog in dialogs.dialogs)
        {
            if ([baseDialog isKindOfClass:[TLDialog$dialogMeta class]])
            {
                TLDialog$dialogMeta *dialog = (TLDialog$dialogMeta *)baseDialog;
                int64_t peerId = 0;
                if ([dialog.peer isKindOfClass:[TLPeer$peerUser class]])
                {
                    if (_ignoreConversationIds.find(((TLPeer$peerUser *)dialog.peer).user_id) == _ignoreConversationIds.end())
                    {
                        TGConversation *conversation = [[TGConversation alloc] initWithConversationId:((TLPeer$peerUser *)dialog.peer).user_id unreadCount:dialog.unread_count serviceUnreadCount:0];
                        peerId = conversation.conversationId;
                        
                        conversation.unreadMark = dialog.flags & (1 << 3);
                        conversation.maxReadMessageId = dialog.read_inbox_max_id;
                        conversation.maxOutgoingReadMessageId = dialog.read_outbox_max_id;
                        conversation.maxKnownMessageId = dialog.top_message;
                        conversation.isArchived = _dialogFolderId == 1 || dialog.folder_id == 1;
                        
                        TGMessage *message = [messagesDict objectForKey:[NSNumber numberWithInt:dialog.top_message]];
                        if (message != nil)
                            [conversation mergeMessage:message];
                        
                        if (conversation.conversationId != 0)
                        {
                            
                            [conversations addObject:conversation];
                            
                            if (message != nil) {
                                NSMutableArray *array = multipleMessagesByConversation[@(conversation.conversationId)];
                                if (array == nil) {
                                    array = [[NSMutableArray alloc] init];
                                    multipleMessagesByConversation[@(conversation.conversationId)] = array;
                                }
                                [array addObject:message];
                            }
                        }
                        
                        OGCompatStoreNotifySettings(conversation.conversationId, dialog.notify_settings);
                        
                    }
                }
                else if ([dialog.peer isKindOfClass:[TLPeer$peerChat class]])
                {
                    if (_ignoreConversationIds.find(-((TLPeer$peerChat *)dialog.peer).chat_id) == _ignoreConversationIds.end())
                    {
                        TGConversation *conversation = [chatItems objectForKey:[[NSNumber alloc] initWithLongLong:-((TLPeer$peerChat *)dialog.peer).chat_id]];
                        if (conversation == nil)
                            continue;
                        peerId = conversation.conversationId;
                        conversation.unreadMark = dialog.flags & (1 << 3);
                        conversation.unreadCount = dialog.unread_count;
                        conversation.maxReadMessageId = dialog.read_inbox_max_id;
                        conversation.maxOutgoingReadMessageId = dialog.read_outbox_max_id;
                        conversation.maxKnownMessageId = dialog.top_message;
                        conversation.isArchived = _dialogFolderId == 1 || dialog.folder_id == 1;
                        
                        TGMessage *message = [messagesDict objectForKey:[NSNumber numberWithInt:dialog.top_message]];
                        if (message != nil)
                            [conversation mergeMessage:message];
                        
                        if (conversation.conversationId != 0)
                        {
                            
                            [conversations addObject:conversation];
                            
                            if (message != nil) {
                                NSMutableArray *array = multipleMessagesByConversation[@(conversation.conversationId)];
                                if (array == nil) {
                                    array = [[NSMutableArray alloc] init];
                                    multipleMessagesByConversation[@(conversation.conversationId)] = array;
                                }
                                [array addObject:message];
                            }
                        }
                        
                        OGCompatStoreNotifySettings(conversation.conversationId, dialog.notify_settings);
                        
                    }
                }
                else if ([dialog.peer isKindOfClass:[TLPeer$peerChannel class]]) {
                    TGConversation *conversation = channelItems[@(TGPeerIdFromChannelId(((TLPeer$peerChannel *)dialog.peer).channel_id))];
                    if (conversation != nil) {
                        peerId = conversation.conversationId;
                        if (conversation.isMonoforum && !conversation.kickedFromChat)
                            conversation.kind = TGConversationKindPersistentChannel;
                        conversation.unreadMark = dialog.flags & (1 << 3);
                        conversation.unreadCount = dialog.unread_count;
                        conversation.maxReadMessageId = dialog.read_inbox_max_id;
                        conversation.maxOutgoingReadMessageId = dialog.read_outbox_max_id;
                        conversation.maxKnownMessageId = dialog.top_message;
                        conversation.isArchived = _dialogFolderId == 1 || dialog.folder_id == 1;
                        
                        NSArray *messages = multipleMessagesByConversation[@(peerId)];
                        TGMessage *message = nil;
                        if (messages.count != 0) {
                            NSArray *sortedMessages = OGCompatMessagesByAscendingSortKey(messages);
                            message = sortedMessages.lastObject;
                        }
                        if (message != nil)
                            [conversation mergeMessage:message];
                        
                        [channels addObject:conversation];
                        
                        OGCompatStoreNotifySettings(conversation.conversationId, dialog.notify_settings);
                        
                    }
                }
                else
                {
                    TGLog(@"DIALOGS unknown dialog peer class=%@ top=%d flags=%d", NSStringFromClass([dialog.peer class]), dialog.top_message, dialog.flags);
                }
                
                if (peerId != 0) {
                    TGDatabaseMessageDraft *draft = nil;
                    if ([dialog.draft isKindOfClass:[TLDraftMessage$draftMessageMeta class]]) {
                        TLDraftMessage$draftMessageMeta *concreteDraft = (TLDraftMessage$draftMessageMeta *)dialog.draft;
                        draft = [[TGDatabaseMessageDraft alloc] initWithText:concreteDraft.message entities:[TGMessage parseTelegraphEntities:concreteDraft.entities] disableLinkPreview:concreteDraft.flags & (1 << 1) replyToMessageId:concreteDraft.reply_to_msg_id date:concreteDraft.date];
                    }
                    
                    if (draft != nil) {
                        updatePeerDrafts[@(peerId)] = draft == nil ? (id)[NSNull null] : draft;
                    }
                    
                    if ((_streaming && _synchronizationPinnedPage) || (dialog.flags & (1 << 2))) {
                        [pinnedPeerIds addObject:@(peerId)];
                    }
                    
                    if (dialog.unread_mentions_count != 0) {
                        resetPeerUnseenMentionsStates[@(peerId)] = [[TGUnseenPeerMentionsState alloc] initWithVersion:0 count:dialog.unread_mentions_count maxIdWithPrecalculatedCount:dialog.top_message];
                    }
                }
            } else if ([baseDialog isKindOfClass:[TLDialog$dialogFeedMeta class]]) {
                TLDialog$dialogFeedMeta *dialog = (TLDialog$dialogFeedMeta *)baseDialog;
                
                NSMutableArray *chatIds = [[NSMutableArray alloc] init];
                NSMutableArray *chatTitles = [[NSMutableArray alloc] init];
                NSMutableArray *chatPhotosSmall = [[NSMutableArray alloc] init];
                for (NSNumber *channelId in dialog.feed_other_channels)
                {
                    
                    TGConversation *conversation = channelItems[@(TGPeerIdFromChannelId([channelId longLongValue]))];
                    if (conversation == nil)
                    {
                        continue;
                    }
                    [chatIds addObject:@(conversation.conversationId)];
                    [chatTitles addObject:conversation.chatTitle ?: @""];
                    [chatPhotosSmall addObject:conversation.chatPhotoSmall ?: @""];
                }
                
                TGFeed *feed = [[TGFeed alloc] init];
                feed.fid = dialog.feed_id;
                feed.chatIds = chatIds;
                feed.chatTitles = chatTitles;
                feed.chatPhotosSmall = chatPhotosSmall;
                feed.maxReadPosition = [[TGFeedPosition alloc] initWithTelegraphDesc:dialog.read_max_position];
                feed.unreadCount = dialog.unread_count + dialog.unread_muted_count;
                
                TGMessage *message = [messagesDict objectForKey:[NSNumber numberWithInt:dialog.top_message]];
                if (message != nil)
                {
                    feed.messageDate = (int32_t)message.date;
                    feed.text = message.text;
                    feed.media = message.mediaAttachments;
                }
                
                [feeds addObject:feed];
            }
            else
            {
                TGLog(@"DIALOGS unknown base dialog class=%@", NSStringFromClass([baseDialog class]));
            }
        }
        if (_streaming)
        {
            for (TGConversation *conversation in [conversations arrayByAddingObjectsFromArray:channels])
                [_synchronizationPeerIds addObject:@(conversation.conversationId)];
            if (_synchronizationPinnedPage)
            {
                for (NSNumber *peerId in pinnedPeerIds)
                {
                    if (![_synchronizationPinnedPeerIds containsObject:peerId])
                        [_synchronizationPinnedPeerIds addObject:peerId];
                }
            }
        }
        bool reachedFolderEnd = !_streaming && [dialogs isKindOfClass:[TLmessages_Dialogs$messages_dialogs class]];
        [TGDatabaseInstance() storeConversationList:conversations replace:(_replaceList && reachedFolderEnd) folderId:_dialogFolderId];
        [TGDatabaseInstance() storeSynchronizedChannels:channels replace:(_replaceList && reachedFolderEnd) folderId:_dialogFolderId];
        [TGDatabaseInstance() updateFeeds:feeds replace:false];
        
        TGDialogListRemoteOffset *remoteOffset = nil;
        
        for (TLDialog *baseDialog in dialogs.dialogs) {
            if ([baseDialog isKindOfClass:[TLDialog$dialogMeta class]]) {
                TLDialog$dialogMeta *dialog = (TLDialog$dialogMeta *)baseDialog;
                int64_t peerId = 0;
                int64_t accessHash = 0;
                TGMessage *message = nil;
                if ([dialog.peer isKindOfClass:[TLPeer$peerChat class]]) {
                    peerId = TGPeerIdFromGroupId(((TLPeer$peerChat *)dialog.peer).chat_id);
                    message = [messagesDict objectForKey:[NSNumber numberWithInt:dialog.top_message]];
                } else if ([dialog.peer isKindOfClass:[TLPeer$peerUser class]]) {
                    peerId = ((TLPeer$peerUser *)dialog.peer).user_id;
                    message = [messagesDict objectForKey:[NSNumber numberWithInt:dialog.top_message]];
                    for (TLUser *user in dialogs.users) {
                        if ([user isKindOfClass:[TLUser$modernUser class]] && ((TLUser$modernUser *)user).n_id == peerId) {
                            accessHash = ((TLUser$modernUser *)user).access_hash;
                            break;
                        }
                    }
                } else if ([dialog.peer isKindOfClass:[TLPeer$peerChannel class]]) {
                    peerId = TGPeerIdFromChannelId(((TLPeer$peerChannel *)dialog.peer).channel_id);
                    for (TGConversation *conversation in channels) {
                        if (conversation.conversationId == peerId) {
                            accessHash = conversation.accessHash;
                            conversation.pts = dialog.pts;
                            break;
                        }
                    }
                    NSArray *messages = multipleMessagesByConversation[@(peerId)];
                    if (messages != nil) {
                        NSArray *sortedMessages = OGCompatMessagesByAscendingSortKey(messages);
                        
                        message = sortedMessages.lastObject;
                    }
                }
                
                if (message != nil && (dialog.flags & (1 << 2)) == 0) {
                    remoteOffset = [[TGDialogListRemoteOffset alloc] initWithDate:(int32_t)message.date peerId:peerId accessHash:accessHash messageId:message.mid];
                }
            } else if ([baseDialog isKindOfClass:[TLDialog$dialogFeedMeta class]]) {
                TLDialog$dialogFeedMeta *dialog = (TLDialog$dialogFeedMeta *)baseDialog;
                int64_t conversationId = TGPeerIdFromFeedId(dialog.feed_id);
                TGMessage *message = [messagesDict objectForKey:[NSNumber numberWithInt:dialog.top_message]];
                
                if (message != nil) {
                    NSMutableArray *array = multipleMessagesByConversation[@(conversationId)];
                    if (array == nil) {
                        array = [[NSMutableArray alloc] init];
                        multipleMessagesByConversation[@(conversationId)] = array;
                    }
                    [array addObject:message];
                }
            }
        }
        
        if (remoteOffset != nil) {
            if (_dialogFolderId == 0)
                [TGDatabaseInstance() setCustomProperty:@"dialogListRemoteOffset" value:[NSKeyedArchiver archivedDataWithRootObject:remoteOffset]];
        }
        
        NSMutableArray *regularMessages = [[NSMutableArray alloc] init];
        NSMutableDictionary *filledHistoryMessageIds = [[NSMutableDictionary alloc] init];
        [multipleMessagesByConversation enumerateKeysAndObjectsUsingBlock:^(NSNumber *nConversationId, NSArray *messages, __unused  BOOL *stop)
        {
            int64_t conversationId = [nConversationId longLongValue];
            if (TGPeerIdIsFeed(conversationId)) {
                NSMutableArray *addedHoles = [[NSMutableArray alloc] init];
                
                NSArray *sortedMessages = OGCompatMessagesByAscendingSortKey(messages);
                
                for (NSUInteger i = 0; i < sortedMessages.count; i++) {
                    TGMessage *message = sortedMessages[i];
                    TGMessage *earlierMessage = i == sortedMessages.count - 1 ? nil : sortedMessages[i + 1];
                    if (earlierMessage == nil) {
                        [addedHoles addObject:[[TGMessageHole alloc] initWithMinId:1 minTimestamp:1 minPeerId:0 maxId:message.mid maxTimestamp:(int32_t)message.date maxPeerId:message.fromUid]];
                    } else {
                        [addedHoles addObject:[[TGMessageHole alloc] initWithMinId:earlierMessage.mid minTimestamp:(int32_t)earlierMessage.date maxId:message.mid maxTimestamp:(int32_t)message.date]];
                    }
                }
                
                [TGDatabaseInstance() addMessagesToFeed:TGFeedIdFromPeerId(conversationId) messages:messages deleteMessages:nil addedHoles:addedHoles removedHoles:nil keepUnreadCounters:true changedMessages:nil];
            }
            else if (TGPeerIdIsChannel(conversationId)) {
                NSMutableArray *addedHoles = [[NSMutableArray alloc] init];
                
                NSArray *sortedMessages = OGCompatMessagesByAscendingSortKey(messages);
                
                for (NSUInteger i = 0; i < sortedMessages.count; i++) {
                    TGMessage *message = sortedMessages[i];
                    TGMessage *earlierMessage = i == sortedMessages.count - 1 ? nil : sortedMessages[i + 1];
                    if (earlierMessage == nil) {
                        if (message.mid != 1) {
                            [addedHoles addObject:[[TGMessageHole alloc] initWithMinId:1 minTimestamp:1 maxId:message.mid - 1 maxTimestamp:(int32_t)message.date]];
                        }
                    } else if (earlierMessage.mid != message.mid - 1) {
                        [addedHoles addObject:[[TGMessageHole alloc] initWithMinId:earlierMessage.mid + 1 minTimestamp:(int32_t)earlierMessage.date + 1 maxId:message.mid - 1 maxTimestamp:(int32_t)message.date]];
                    }
                }
                
                [TGDatabaseInstance() addMessagesToChannel:[nConversationId longLongValue] messages:messages deleteMessages:nil unimportantGroups:nil addedHoles:addedHoles removedHoles:nil removedUnimportantHoles:nil updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:true skipFeedUpdate:true changedMessages:nil];
            } else if (messages.count != 0) {
                [regularMessages addObjectsFromArray:messages];
                filledHistoryMessageIds[nConversationId] = @(((TGMessage *)messages.firstObject).mid);
            }
        }];
        
        if (regularMessages.count != 0)
            [TGDatabaseInstance() transactionAddMessages:regularMessages updateConversationDatas:nil notifyAdded:false];
        [filledHistoryMessageIds enumerateKeysAndObjectsUsingBlock:^(NSNumber *nConversationId, NSNumber *nMessageId, __unused BOOL *stop)
        {
            [TGDatabaseInstance() fillConversationHistoryHole:[nConversationId longLongValue] indexSet:[NSIndexSet indexSetWithIndex:[nMessageId intValue]]];
        }];
        
        NSSet *removedPeerIds = nil;
        if (_streaming && _synchronizationFinalPage)
            removedPeerIds = [TGDatabaseInstance() reconcileDialogListForFolder:_dialogFolderId initialPeerIds:_synchronizationInitialPeerIds receivedPeerIds:_synchronizationPeerIds beforeDate:_synchronizationStartDate];
        if (!_streaming || _synchronizationFinalPage)
            [TGDatabaseInstance() transactionCalculateUnreadChats];
        
        [TGDatabaseInstance() transactionAddMessages:nil notifyAddedMessages:false removeMessages:nil updateMessages:nil updatePeerDrafts:updatePeerDrafts removeMessagesInteractive:nil keepDates:false removeMessagesInteractiveForEveryone:false updateConversationDatas:nil applyMaxIncomingReadIds:nil applyMaxOutgoingReadIds:nil applyMaxOutgoingReadDates:nil applyUnreadMarks:nil readHistoryForPeerIds:nil resetPeerReadStates:nil resetPeerUnseenMentionsStates:resetPeerUnseenMentionsStates clearConversationsWithPeerIds:nil clearConversationsInteractive:false removeConversationsWithPeerIds:nil updatePinnedConversations:(_dialogFolderId == 0 && _streaming && _synchronizationPinnedPage) ? _synchronizationPinnedPeerIds : ((!_streaming && _replaceList && _dialogFolderId == 0) ? pinnedPeerIds : nil) synchronizePinnedConversations:false forceReplacePinnedConversations:false readMessageContentsInteractive:nil deleteEarlierHistory:nil updateFeededChannels:nil newlyJoinedFeedId:nil synchronizeFeededChannels:false calculateUnreadChats:false];
        
        [TGDatabaseInstance() endStorageBatch];
        
        if (!_streaming)
            [ActionStageInstance() dispatchResource:@"/dialogListReloaded" resource:@true];
        
        bool remoteListFullyLoaded = _streaming ? _synchronizationFinalPage : ([dialogs isKindOfClass:[TLmessages_Dialogs$messages_dialogs class]] || dialogs.dialogs.count == 0);
        if (_dialogFolderId == 0)
        {
            if ((_replaceList && !_streaming) || (_streaming && _synchronizationFinalPage))
                OGCompatClearProperty(@"ios6DialogListNeedsRemoteRefresh");
            if (remoteListFullyLoaded)
            {
                OGCompatSetFlagProperty(@"dialogListLoaded");
                OGCompatCommitDialogListCache();
            }
            else if (_replaceList)
            {
                OGCompatSetEmptyProperty(@"dialogListLoaded");
            }
        }
        
        NSArray *dialogListItems = [conversations arrayByAddingObjectsFromArray:channels];
        NSDictionary *pinnedDates = [TGDatabaseInstance() _getPinnedConversationDates];
        for (TGConversation *conversation in dialogListItems)
            conversation.pinnedDate = [pinnedDates[@(conversation.conversationId)] intValue];
        SGraphListNode *dialogListNode = [[SGraphListNode alloc] initWithItems:dialogListItems];
        TGLog(@"DIALOGS remote stored path=%@ items=%d", self.path, (int)dialogListItems.count);
        if (_streaming)
        {
            TGDialogListSynchronizationNode *pageNode = [[TGDialogListSynchronizationNode alloc] initWithItems:dialogListItems];
            pageNode.folderId = _dialogFolderId;
            pageNode.complete = _synchronizationFinalPage;
            pageNode.removedPeerIds = removedPeerIds;
            _synchronizationPageNode = pageNode;
            if (_dialogFolderId == 1 && _synchronizationFinalPage)
            {
                OGCompatSetFlagProperty(@"ios6ArchivePeerIdsComplete");
            }
        }
        else
            [ActionStageInstance() nodeRetrieved:self.path node:dialogListNode];
    };

    processDialogs(parsedMessages);

    NSMutableSet *pendingHydrationMessageKeys = [[NSMutableSet alloc] init];
    for (TGMessage *message in parsedMessages)
    {
        for (id attachment in message.mediaAttachments)
        {
            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]] && ((TGReplyMessageMediaAttachment *)attachment).replyMessage == nil)
            {
                [pendingHydrationMessageKeys addObject:[[NSString alloc] initWithFormat:@"%lld:%d", message.cid, message.mid]];
                break;
            }
        }
    }

    SSignal *replyHydrationSignal = [[TGDialogListRequestBuilder signalForCompleteMessages:parsedMessages channels:channelItems] catch:^SSignal *(__unused id error)
    {
        return [SSignal complete];
    }];
    [[[replyHydrationSignal timeout:15.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal complete]] take:1] startWithNext:^(NSArray *completeMessages)
    {
        OGCompatStoreHydratedDialogMessages(completeMessages, pendingHydrationMessageKeys);
        [ActionStageInstance() dispatchResource:@"/dialogListReloaded" resource:@true];
    }];
}

- (void)dialogListRequestNotModified:(int32_t)count
{
    
    OGCompatLoadDialogListHead(^(NSArray *result)
    {
        if (result.count != 0)
            [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphListNode alloc] initWithItems:result]];
        [ActionStageInstance() dispatchResource:@"/dialogListReloaded" resource:@true];
    });
}

- (void)dialogListRequestFailed
{
    TGLog(@"DIALOGS builder failed path=%@", self.path);
    if (_streaming)
    {
        _synchronizationFinished = true;
        [_synchronizationRetryTimer invalidate];
        _synchronizationRetryTimer = nil;
        self.cancelToken = nil;
        [ActionStageInstance() nodeRetrieveFailed:self.path];
        return;
    }
    if (_dialogFolderId != 0)
    {
        TGLog(@"ARCHIVE archive builder failed path=%@", self.path);
        [ActionStageInstance() nodeRetrieveFailed:self.path];
        return;
    }
    
    OGCompatLoadDialogListHead(^(NSArray *result)
    {
        if (result.count != 0 || _replaceList)
        {
            if (_dialogFolderId == 0)
                OGCompatSetEmptyProperty(@"dialogListLoaded");
            [ActionStageInstance() nodeRetrieved:self.path node:[[SGraphListNode alloc] initWithItems:result]];
        }
        else
        {
            [ActionStageInstance() nodeRetrieveFailed:self.path];
        }
    });
}

+ (SSignal *)signalForCompleteMessages:(NSArray *)completeMessages channels:(NSDictionary *)channels
{
    NSMutableArray *downloadMessages = [[NSMutableArray alloc] init];
    
    for (TGMessage *message in completeMessages)
    {
        for (id attachment in message.mediaAttachments)
        {
            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
            {
                if (((TGReplyMessageMediaAttachment *)attachment).replyMessage == nil) {
                    if (TGPeerIdIsChannel(message.cid)) {
                        TGConversation *conversation = channels[@(message.cid)];
                        if (conversation != nil) {
                            [downloadMessages addObject:[[TGDownloadMessage alloc] initWithPeerId:message.cid accessHash:conversation.accessHash messageId:((TGReplyMessageMediaAttachment *)attachment).replyMessageId]];
                        }
                    } else {
                        [downloadMessages addObject:[[TGDownloadMessage alloc] initWithPeerId:0 accessHash:0 messageId:((TGReplyMessageMediaAttachment *)attachment).replyMessageId]];
                    }
                }
            }
        }
    }
    
    if (downloadMessages.count == 0)
        return [SSignal complete];
    else
    {
        return [[TGDownloadMessagesSignal downloadMessages:downloadMessages] map:^id(NSArray *messages)
        {
            NSMutableDictionary *peerIdMessageIdToMessage = [[NSMutableDictionary alloc] init];
            for (TGMessage *message in messages)
            {
                peerIdMessageIdToMessage[[[NSString alloc] initWithFormat:@"%lld:%d", message.cid, message.mid]] = message;
            }
            
            for (TGMessage *message in completeMessages)
            {
                for (id attachment in message.mediaAttachments)
                {
                    if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
                    {
                        TGMessage *requiredMessage = peerIdMessageIdToMessage[[[NSString alloc] initWithFormat:@"%lld:%d", message.cid, ((TGReplyMessageMediaAttachment *)attachment).replyMessageId]];
                        if (requiredMessage != nil)
                            ((TGReplyMessageMediaAttachment *)attachment).replyMessage = requiredMessage;
                        
                        break;
                    }
                }
            }
            
            return completeMessages;
        }];
    }
}


@end
