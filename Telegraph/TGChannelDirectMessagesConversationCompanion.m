#import "TGChannelDirectMessagesConversationCompanion.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGDatabase.h"
#import "TGInterfaceManager.h"
#import "TGModernConversationController.h"
#import "TGMessageModernConversationItem.h"
#import "TGModernViewContext.h"
#import "TGPreparedMessage.h"
#import "TGChannelDirectMessagesSignals.h"

@class TGVisibleMessageHole;

static const int32_t TGChannelDirectMessagesHistoryPageSize = 64;

static NSUInteger TGChannelDirectMessagesInitialBatchCount(void)
{
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone ? 12 : 18;
}

@interface TGChannelDirectMessagesConversationCompanionReference : NSObject

@property (nonatomic, weak) TGChannelDirectMessagesConversationCompanion *value;

@end

@implementation TGChannelDirectMessagesConversationCompanionReference

@end

static TGChannelDirectMessagesConversationCompanion *TGChannelDirectMessagesResolveCompanion(TGChannelDirectMessagesConversationCompanionReference *reference)
{
    TGChannelDirectMessagesConversationCompanion *result = nil;
    @synchronized (reference)
    {
        result = reference.value;
    }
    return result;
}

@interface TGChannelDirectMessagesConversationCompanion ()
{
    TGChannelDirectMessagesConversationCompanionReference *_lifetimeReference;
    SMetaDisposable *_historyDisposable;
    SMetaDisposable *_readDisposable;
    volatile int _historyGeneration;
    bool _loadingAbove;
    bool _hasMoreAbove;
    int32_t _requestedReadMaxId;
    int32_t _confirmedReadMaxId;
}

@end

@implementation TGChannelDirectMessagesConversationCompanion

- (instancetype)initWithMonoforum:(TGConversation *)monoforum threadPeerId:(int64_t)threadPeerId
{
    self = [super initWithConversation:monoforum userActivities:nil];
    if (self != nil)
    {
        _threadPeerId = threadPeerId;
        _hasMoreAbove = true;
        _historyDisposable = [[SMetaDisposable alloc] init];
        _readDisposable = [[SMetaDisposable alloc] init];
        _lifetimeReference = [[TGChannelDirectMessagesConversationCompanionReference alloc] init];
        _lifetimeReference.value = self;
    }
    return self;
}

- (void)dealloc
{
    @synchronized (_lifetimeReference)
    {
        _lifetimeReference.value = nil;
    }
    [_historyDisposable dispose];
    [_readDisposable dispose];
}

- (bool)allowPollSending
{
    return false;
}

- (bool)_threadContainsMessage:(TGMessage *)message
{
    return [message isKindOfClass:[TGMessage class]] && message.savedPeerId == _threadPeerId;
}

- (NSArray *)_threadMessages:(NSArray *)messages
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (TGMessage *message in messages)
    {
        if ([self _threadContainsMessage:message])
            [result addObject:message];
    }
    return result;
}

- (NSDictionary *)_threadChange:(NSDictionary *)change
{
    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:change];
    NSArray *added = change[@"added"];
    if ([added isKindOfClass:[NSArray class]])
        result[@"added"] = [self _threadMessages:added];

    NSDictionary *updated = change[@"updated"];
    if ([updated isKindOfClass:[NSDictionary class]])
    {
        NSMutableDictionary *threadUpdated = [[NSMutableDictionary alloc] init];
        [updated enumerateKeysAndObjectsUsingBlock:^(id key, id message, __unused BOOL *stop)
        {
            if ([self _threadContainsMessage:message])
                threadUpdated[key] = message;
        }];
        result[@"updated"] = threadUpdated;
    }
    return result;
}

- (NSString *)titleForConversation:(TGConversation *)__unused conversation
{
    if (TGPeerIdIsUser(_threadPeerId))
        return [TGDatabaseInstance() loadUser:_threadPeerId].displayName ?: @"";
    return [TGDatabaseInstance() loadConversationWithId:_threadPeerId].chatTitle ?: @"";
}

- (void)applyAvatarForConversation:(TGConversation *)__unused conversation
{
    if (TGPeerIdIsUser(_threadPeerId))
    {
        TGUser *user = [TGDatabaseInstance() loadUser:_threadPeerId];
        [self _setAvatarConversationId:_threadPeerId firstName:user.firstName lastName:user.lastName];
        [self _setAvatarUrl:user.photoFullUrlSmall];
    }
    else
    {
        TGConversation *peer = [TGDatabaseInstance() loadConversationWithId:_threadPeerId];
        [self _setAvatarConversationId:_threadPeerId title:peer.chatTitle icon:nil];
        [self _setAvatarUrl:peer.chatPhotoFullSmall];
    }
}

- (void)_controllerAvatarPressed
{
    if (TGPeerIdIsUser(_threadPeerId))
        [[TGInterfaceManager instance] navigateToProfileOfUser:_threadPeerId];
    else
        [super _controllerAvatarPressed];
}

- (void)loadInitialState
{
    TGModernConversationController *controller = self.controller;
    [controller setConversationHeader:[self _conversationHeader]];
    self.viewContext.conversation = self.conversation;
    [self _updateInputPanel];

    [self _setTitle:[self title] andStatus:TGLocalized(@"Channel.DirectMessages.Status") accentColored:false allowAnimatioon:false toggleMode:TGModernConversationControllerTitleToggleNone];
    [self applyAvatarForConversation:self.conversation];

    [controller setEnableBelowHistoryRequests:false];
    [controller setEnableAboveHistoryRequests:false];
    [controller setLoadingMessages:true];

    [self _loadHistoryWithOffsetId:0 initial:true];
}

- (void)_loadHistoryWithOffsetId:(int32_t)offsetId initial:(bool)initial
{
    int generation = ++_historyGeneration;
    TGChannelDirectMessagesConversationCompanionReference *reference = _lifetimeReference;
    SSignal *history = [TGChannelDirectMessagesSignals historyForMonoforum:self.conversation peerId:_threadPeerId offsetId:offsetId limit:TGChannelDirectMessagesHistoryPageSize];
    [_historyDisposable setDisposable:[history startWithNext:^(NSArray *messages)
    {
        [TGModernConversationCompanion dispatchOnMessageQueue:^
        {
            TGChannelDirectMessagesConversationCompanion *strongSelf = TGChannelDirectMessagesResolveCompanion(reference);
            if (strongSelf != nil)
                [strongSelf _applyHistoryMessages:messages initial:initial generation:generation];
        }];
    } error:^(__unused id error)
    {
        TGDispatchOnMainThread(^
        {
            TGChannelDirectMessagesConversationCompanion *strongSelf = TGChannelDirectMessagesResolveCompanion(reference);
            if (strongSelf == nil || strongSelf->_historyGeneration != generation)
                return;
            strongSelf->_loadingAbove = false;
            TGModernConversationController *controller = strongSelf.controller;
            [controller setLoadingMessages:false];
            [controller setEnableAboveHistoryRequests:strongSelf->_hasMoreAbove];
        });
    } completed:nil]];
}

- (void)_applyHistoryMessages:(NSArray *)messages initial:(bool)initial generation:(int)generation
{
    if (_historyGeneration != generation)
        return;

    bool hasMore = messages.count >= (NSUInteger)TGChannelDirectMessagesHistoryPageSize;

    if (initial)
    {
        NSUInteger visibleCount = MIN(messages.count, TGChannelDirectMessagesInitialBatchCount());
        [self _replaceMessages:[messages subarrayWithRange:NSMakeRange(0, visibleCount)]];
        if (visibleCount < messages.count)
            [self _addMessages:[messages subarrayWithRange:NSMakeRange(visibleCount, messages.count - visibleCount)] animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesAbove];
    }
    else if (messages.count != 0)
        [self _addMessages:messages animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesAbove];

    TGDispatchOnMainThread(^
    {
        if (_historyGeneration != generation)
            return;
        _hasMoreAbove = hasMore;
        _loadingAbove = false;
        TGModernConversationController *controller = self.controller;
        [controller setLoadingMessages:false];
        [controller setEnableAboveHistoryRequests:hasMore];
        [self scheduleReadHistory];
    });
}

- (void)loadMoreMessagesAbove
{
    if (_loadingAbove || !_hasMoreAbove)
        return;

    _loadingAbove = true;
    [self.controller setEnableAboveHistoryRequests:false];

    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        int32_t oldestMessageId = 0;
        for (TGMessageModernConversationItem *item in _items)
        {
            if (![item isKindOfClass:[TGMessageModernConversationItem class]])
                continue;
            int32_t mid = item->_message.mid;
            if (mid > 0 && mid < TGMessageLocalMidBaseline && (oldestMessageId == 0 || mid < oldestMessageId))
                oldestMessageId = mid;
        }

        TGDispatchOnMainThread(^
        {
            if (oldestMessageId == 0)
            {
                _loadingAbove = false;
                _hasMoreAbove = false;
                return;
            }
            [self _loadHistoryWithOffsetId:oldestMessageId initial:false];
        });
    }];
}

- (void)loadMoreMessagesBelow
{
}

- (void)_requestHole:(TGVisibleMessageHole *)__unused hole
{
}

- (void)_updateControllerHistoryRequestsFlags
{
    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        [controller setEnableBelowHistoryRequests:false];
        [controller setEnableAboveHistoryRequests:_hasMoreAbove && !_loadingAbove];
    });
}

- (void)unloadMessagesAroundMessageId:(int32_t)__unused messageId conversationId:(int64_t)__unused conversationId date:(int32_t)__unused date
{
}

- (void)_validatePts
{
}

- (void)navigateToMessageId:(int32_t)messageId scrollBackMessageId:(int32_t)scrollBackMessageId forceUnseenMention:(bool)forceUnseenMention animated:(bool)animated
{
    [TGModernConversationCompanion dispatchOnMessageQueue:^
    {
        bool loaded = false;
        for (TGMessageModernConversationItem *item in _items)
        {
            if ([item isKindOfClass:[TGMessageModernConversationItem class]] && item->_message.mid == messageId)
            {
                loaded = true;
                break;
            }
        }

        if (loaded)
        {
            TGDispatchOnMainThread(^
            {
                [super navigateToMessageId:messageId scrollBackMessageId:scrollBackMessageId forceUnseenMention:forceUnseenMention animated:animated];
            });
        }
    }];
}

- (void)scheduleReadHistory
{
    if (self.previewMode)
        return;

    TGDispatchOnMainThread(^
    {
        TGModernConversationController *controller = self.controller;
        if (![controller canReadHistory])
            return;

        [TGModernConversationCompanion dispatchOnMessageQueue:^
        {
            int32_t maxMessageId = 0;
            for (TGMessageModernConversationItem *item in _items)
            {
                if (![item isKindOfClass:[TGMessageModernConversationItem class]])
                    continue;
                int32_t mid = item->_message.mid;
                if (mid > 0 && mid < TGMessageLocalMidBaseline)
                    maxMessageId = MAX(maxMessageId, mid);
            }

            TGDispatchOnMainThread(^
            {
                [self _readHistoryUpTo:maxMessageId];
            });
        }];
    });
}

- (void)controllerCanReadHistoryUpdated
{
    [self scheduleReadHistory];
}

- (void)_readHistoryUpTo:(int32_t)maxId
{
    if (maxId <= 0 || maxId <= _requestedReadMaxId)
        return;

    _requestedReadMaxId = maxId;
    TGChannelDirectMessagesConversationCompanionReference *reference = _lifetimeReference;
    [_readDisposable setDisposable:[[[TGChannelDirectMessagesSignals readHistoryForMonoforum:self.conversation peerId:_threadPeerId maxId:maxId] deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next)
    {
        TGChannelDirectMessagesConversationCompanion *strongSelf = TGChannelDirectMessagesResolveCompanion(reference);
        if (strongSelf != nil)
            strongSelf->_confirmedReadMaxId = MAX(strongSelf->_confirmedReadMaxId, maxId);
    } error:^(__unused id error)
    {
        TGChannelDirectMessagesConversationCompanion *strongSelf = TGChannelDirectMessagesResolveCompanion(reference);
        if (strongSelf != nil && strongSelf->_requestedReadMaxId == maxId)
            strongSelf->_requestedReadMaxId = strongSelf->_confirmedReadMaxId;
    } completed:nil]];
}

- (void)_setupPreparedMessage:(TGPreparedMessage *)message
{
    [super _setupPreparedMessage:message];
    message.monoforumPeerId = _threadPeerId;
}

- (bool)_paidMessagesExemptForConversation:(TGConversation *)monoforum
{
    return [TGChannelDirectMessagesSignals canManageDirectMessagesInMonoforum:monoforum];
}

- (int64_t)_paidMessagesPriceForConversation:(TGConversation *)monoforum
{
    if (monoforum == nil || [self _paidMessagesExemptForConversation:monoforum])
        return 0;
    if (monoforum.sendPaidMessagesStars > 0)
        return monoforum.sendPaidMessagesStars;
    return [TGChannelDirectMessagesSignals broadcastChannelForMonoforum:monoforum].sendPaidMessagesStars;
}

- (SSignal *)_requestPinnedMessages
{
    int64_t threadPeerId = _threadPeerId;
    return [[super _requestPinnedMessages] map:^id(id value)
    {
        if (![value isKindOfClass:[NSArray class]])
            return value;

        NSMutableArray *result = [[NSMutableArray alloc] init];
        for (TGMessage *message in (NSArray *)value)
        {
            if (message.savedPeerId == threadPeerId)
                [result addObject:message];
        }
        return result;
    }];
}

- (void)controllerDidUpdateTypingActivity
{
}

- (void)updateControllerInputText:(NSString *)__unused inputText entities:(NSArray *)__unused entities messageEditingContext:(TGMessageEditingContext *)__unused messageEditingContext
{
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)arguments
{
    NSString *messagesPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messages", _conversationId];
    NSString *importantPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/importantMessages", _conversationId];
    NSString *unimportantPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/unimportantMessages", _conversationId];
    NSString *typingPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/typing", _conversationId];

    if ([path isEqualToString:messagesPath])
    {
        id object = [resource isKindOfClass:[SGraphObjectNode class]] ? ((SGraphObjectNode *)resource).object : resource;
        if ([object isKindOfClass:[NSArray class]])
        {
            NSArray *threadMessages = [self _threadMessages:object];
            if (threadMessages.count != 0)
                [super actionStageResourceDispatched:path resource:[[SGraphObjectNode alloc] initWithObject:threadMessages] arguments:arguments];
            return;
        }
    }
    else if ([path isEqualToString:importantPath] || [path isEqualToString:unimportantPath])
    {
        if ([resource isKindOfClass:[NSDictionary class]])
        {
            [super actionStageResourceDispatched:path resource:[self _threadChange:resource] arguments:arguments];
            return;
        }
    }
    else if ([path isEqualToString:typingPath])
    {
        NSDictionary *activities = [resource isKindOfClass:[SGraphObjectNode class]] ? ((SGraphObjectNode *)resource).object : nil;
        id activity = [activities isKindOfClass:[NSDictionary class]] ? activities[@(_threadPeerId)] : nil;
        [super actionStageResourceDispatched:path resource:[[SGraphObjectNode alloc] initWithObject:activity != nil ? @{@(_threadPeerId): activity} : @{}] arguments:arguments];
        return;
    }

    [super actionStageResourceDispatched:path resource:resource arguments:arguments];
}

@end
