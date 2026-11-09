#import "TGChannelDirectMessagesSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TL/TLMetaScheme.h"
#import "TGTelegramNetworking.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGUserDataRequestBuilder.h"
#import "TGChannelManagementSignals.h"
#import "TGConversation+Telegraph.h"
#import "TGMessage+Telegraph.h"

@interface TGChannelDirectMessagesThreadsPage ()

- (instancetype)initWithThreads:(NSArray *)threads hasMore:(bool)hasMore;

@end

static int64_t TGChannelDirectMessagesPeerIdForPeer(TLPeer *peer)
{
    if ([peer isKindOfClass:[TLPeer$peerUser class]])
        return TGPeerIdFromUserId(((TLPeer$peerUser *)peer).user_id);
    if ([peer isKindOfClass:[TLPeer$peerChannel class]])
        return TGPeerIdFromChannelId(((TLPeer$peerChannel *)peer).channel_id);
    if ([peer isKindOfClass:[TLPeer$peerChat class]])
        return TGPeerIdFromGroupId(((TLPeer$peerChat *)peer).chat_id);
    return 0;
}

static NSArray *TGChannelDirectMessagesParseMessages(NSArray *descriptions, int64_t monoforumPeerId)
{
    NSMutableArray *messages = [[NSMutableArray alloc] init];
    for (TLMessage *description in descriptions)
    {
        TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:description];
        if (message == nil || message.mid == 0 || message.cid != monoforumPeerId)
            continue;
        [messages addObject:message];
    }
    [messages sortUsingComparator:^NSComparisonResult(TGMessage *lhs, TGMessage *rhs)
    {
        if (lhs.date != rhs.date)
            return lhs.date > rhs.date ? NSOrderedAscending : NSOrderedDescending;
        if (lhs.mid != rhs.mid)
            return lhs.mid > rhs.mid ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    return messages;
}

@implementation TGChannelDirectMessagesThread

- (instancetype)initWithPeerId:(int64_t)peerId topMessageId:(int32_t)topMessageId topMessage:(TGMessage *)topMessage readInboxMaxId:(int32_t)readInboxMaxId readOutboxMaxId:(int32_t)readOutboxMaxId unreadCount:(int32_t)unreadCount unreadMark:(bool)unreadMark
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _topMessageId = topMessageId;
        _topMessage = topMessage;
        _readInboxMaxId = readInboxMaxId;
        _readOutboxMaxId = readOutboxMaxId;
        _unreadCount = MAX(0, unreadCount);
        _unreadMark = unreadMark;
    }
    return self;
}

- (instancetype)threadByApplyingMessage:(TGMessage *)message
{
    if (message.mid < _topMessageId)
        return self;
    if (message.mid == _topMessageId)
        return [[TGChannelDirectMessagesThread alloc] initWithPeerId:_peerId topMessageId:_topMessageId topMessage:message readInboxMaxId:_readInboxMaxId readOutboxMaxId:_readOutboxMaxId unreadCount:_unreadCount unreadMark:_unreadMark];
    bool incomingUnread = !message.outgoing && message.mid > _readInboxMaxId;
    return [[TGChannelDirectMessagesThread alloc] initWithPeerId:_peerId topMessageId:message.mid topMessage:message readInboxMaxId:_readInboxMaxId readOutboxMaxId:_readOutboxMaxId unreadCount:_unreadCount + (incomingUnread ? 1 : 0) unreadMark:_unreadMark];
}

- (instancetype)threadByReadingInboxUpTo:(int32_t)maxId
{
    if (maxId <= _readInboxMaxId && _unreadCount == 0 && !_unreadMark)
        return self;
    int32_t readInboxMaxId = MAX(_readInboxMaxId, maxId);
    int32_t unreadCount = readInboxMaxId >= _topMessageId ? 0 : _unreadCount;
    return [[TGChannelDirectMessagesThread alloc] initWithPeerId:_peerId topMessageId:_topMessageId topMessage:_topMessage readInboxMaxId:readInboxMaxId readOutboxMaxId:_readOutboxMaxId unreadCount:unreadCount unreadMark:false];
}

@end

@implementation TGChannelDirectMessagesThreadsPage

- (instancetype)initWithThreads:(NSArray *)threads hasMore:(bool)hasMore
{
    self = [super init];
    if (self != nil)
    {
        _threads = threads;
        _hasMore = hasMore;
    }
    return self;
}

@end

@implementation TGChannelDirectMessagesSignals

+ (TGConversation *)broadcastChannelForMonoforum:(TGConversation *)monoforum
{
    if (!monoforum.isMonoforum)
        return nil;
    int64_t peerId = TGPeerIdFromChannelId(monoforum.linkedMonoforumId);
    if (peerId == 0)
        return nil;
    return [TGDatabaseInstance() loadChannels:@[@(peerId)]][@(peerId)];
}

+ (bool)channelAcceptsDirectMessages:(TGConversation *)channel
{
    return channel.isChannel && !channel.isMonoforum && channel.directMessagesEnabled && TGPeerIdFromChannelId(channel.linkedMonoforumId) != 0;
}

+ (bool)canManageDirectMessagesInChannel:(TGConversation *)channel
{
    return channel.channelRole == TGChannelRoleCreator || channel.channelAdminRights.canManageDirectMessages;
}

+ (bool)canManageDirectMessagesInMonoforum:(TGConversation *)monoforum
{
    TGConversation *broadcast = [self broadcastChannelForMonoforum:monoforum];
    return [self canManageDirectMessagesInChannel:broadcast != nil ? broadcast : monoforum];
}

+ (SSignal *)monoforumForChannel:(TGConversation *)channel
{
    int64_t monoforumPeerId = TGPeerIdFromChannelId(channel.linkedMonoforumId);
    if (monoforumPeerId == 0)
        return [SSignal fail:nil];

    int64_t channelPeerId = channel.conversationId;
    int64_t channelAccessHash = channel.accessHash;
    return [SSignal defer:^SSignal *
    {
        TGConversation *cached = [TGDatabaseInstance() loadChannels:@[@(monoforumPeerId)]][@(monoforumPeerId)];
        if (cached.accessHash != 0 && !cached.isMin)
            return [SSignal single:cached];

        TLInputChannel *inputChannel = [TGChannelManagementSignals inputChannelForPeerId:channelPeerId accessHash:channelAccessHash];
        if (inputChannel == nil)
            return [SSignal fail:nil];

        TLRPCchannels_getFullChannel$channels_getFullChannel *request = [[TLRPCchannels_getFullChannel$channels_getFullChannel alloc] init];
        request.channel = inputChannel;
        return [[[TGTelegramNetworking instance] requestSignal:request] mapToSignal:^SSignal *(TLmessages_ChatFull *result)
        {
            [TGUserDataRequestBuilder executeUserDataUpdate:result.users];
            [TGChannelManagementSignals storeChannelChats:result.chats];

            for (TLChat *chat in result.chats)
            {
                TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chat];
                if (conversation.conversationId == monoforumPeerId && conversation.accessHash != 0 && !conversation.isMin)
                    return [SSignal single:conversation];
            }
            return [SSignal fail:nil];
        }];
    }];
}

+ (SSignal *)threadsForMonoforum:(TGConversation *)monoforum after:(TGChannelDirectMessagesThread *)lastThread limit:(int32_t)limit
{
    int64_t monoforumPeerId = monoforum.conversationId;

    TLInputPeer *offsetPeer = [[TLInputPeer$inputPeerEmpty alloc] init];
    if (lastThread != nil)
    {
        offsetPeer = [TGTelegraphInstance createInputPeerForConversation:lastThread.peerId accessHash:0];
        if (lastThread.topMessage == nil || [offsetPeer isKindOfClass:[TLInputPeer$inputPeerEmpty class]])
            return [SSignal single:[[TGChannelDirectMessagesThreadsPage alloc] initWithThreads:@[] hasMore:false]];
    }

    TLRPCmessages_getSavedDialogs$messages_getSavedDialogs *request = [[TLRPCmessages_getSavedDialogs$messages_getSavedDialogs alloc] init];
    request.flags = (1 << 1);
    request.parent_peer = [TGTelegraphInstance createInputPeerForConversation:monoforumPeerId accessHash:monoforum.accessHash];
    request.offset_date = lastThread == nil ? 0 : (int32_t)lastThread.topMessage.date;
    request.offset_id = lastThread == nil ? 0 : lastThread.topMessageId;
    request.offset_peer = offsetPeer;
    request.limit = limit;
    request.n_hash = 0;

    return [[[TGTelegramNetworking instance] requestSignal:request] map:^id(TLmessages_SavedDialogs *result)
    {
        NSArray *dialogs = nil;
        NSArray *messageDescriptions = nil;
        NSArray *chats = nil;
        NSArray *users = nil;
        bool isSlice = false;

        if ([result isKindOfClass:[TLmessages_SavedDialogs$messages_savedDialogs class]])
        {
            TLmessages_SavedDialogs$messages_savedDialogs *concreteResult = (TLmessages_SavedDialogs$messages_savedDialogs *)result;
            dialogs = concreteResult.dialogs;
            messageDescriptions = concreteResult.messages;
            chats = concreteResult.chats;
            users = concreteResult.users;
        }
        else if ([result isKindOfClass:[TLmessages_SavedDialogs$messages_savedDialogsSlice class]])
        {
            TLmessages_SavedDialogs$messages_savedDialogsSlice *concreteResult = (TLmessages_SavedDialogs$messages_savedDialogsSlice *)result;
            dialogs = concreteResult.dialogs;
            messageDescriptions = concreteResult.messages;
            chats = concreteResult.chats;
            users = concreteResult.users;
            isSlice = true;
        }

        [TGUserDataRequestBuilder executeUserDataUpdate:users];
        [TGChannelManagementSignals storeChannelChats:chats];

        NSMutableDictionary *messagesById = [[NSMutableDictionary alloc] init];
        for (TGMessage *message in TGChannelDirectMessagesParseMessages(messageDescriptions, monoforumPeerId))
            messagesById[@(message.mid)] = message;

        NSMutableArray *threads = [[NSMutableArray alloc] init];
        for (TLSavedDialog *dialog in dialogs)
        {
            if (![dialog isKindOfClass:[TLSavedDialog$monoForumDialog class]])
                continue;

            TLSavedDialog$monoForumDialog *concreteDialog = (TLSavedDialog$monoForumDialog *)dialog;
            int64_t peerId = TGChannelDirectMessagesPeerIdForPeer(concreteDialog.peer);
            if (peerId == 0)
                continue;

            [threads addObject:[[TGChannelDirectMessagesThread alloc] initWithPeerId:peerId topMessageId:concreteDialog.top_message topMessage:messagesById[@(concreteDialog.top_message)] readInboxMaxId:concreteDialog.read_inbox_max_id readOutboxMaxId:concreteDialog.read_outbox_max_id unreadCount:concreteDialog.unread_count unreadMark:(concreteDialog.flags & (1 << 3)) != 0]];
        }

        bool hasMore = isSlice && dialogs.count != 0 && dialogs.count >= (NSUInteger)limit;
        return [[TGChannelDirectMessagesThreadsPage alloc] initWithThreads:threads hasMore:hasMore];
    }];
}

+ (SSignal *)historyForMonoforum:(TGConversation *)monoforum peerId:(int64_t)peerId offsetId:(int32_t)offsetId limit:(int32_t)limit
{
    int64_t monoforumPeerId = monoforum.conversationId;

    TLRPCmessages_getSavedHistory$messages_getSavedHistory *request = [[TLRPCmessages_getSavedHistory$messages_getSavedHistory alloc] init];
    request.flags = (1 << 0);
    request.parent_peer = [TGTelegraphInstance createInputPeerForConversation:monoforumPeerId accessHash:monoforum.accessHash];
    request.peer = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:0];
    request.offset_id = offsetId;
    request.offset_date = 0;
    request.add_offset = 0;
    request.limit = limit;
    request.max_id = 0;
    request.min_id = 0;
    request.n_hash = 0;

    return [[[TGTelegramNetworking instance] requestSignal:request] map:^id(TLmessages_Messages *result)
    {
        [TGUserDataRequestBuilder executeUserDataUpdate:result.users];
        [TGChannelManagementSignals storeChannelChats:result.chats];

        NSArray *messages = TGChannelDirectMessagesParseMessages(result.messages, monoforumPeerId);
        for (TGMessage *message in messages)
        {
            if (message.savedPeerId == 0)
                message.savedPeerId = peerId;
        }
        return messages;
    }];
}

+ (SSignal *)readHistoryForMonoforum:(TGConversation *)monoforum peerId:(int64_t)peerId maxId:(int32_t)maxId
{
    TLRPCmessages_readSavedHistory$messages_readSavedHistory *request = [[TLRPCmessages_readSavedHistory$messages_readSavedHistory alloc] init];
    request.parent_peer = [TGTelegraphInstance createInputPeerForConversation:monoforum.conversationId accessHash:monoforum.accessHash];
    request.peer = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:0];
    request.max_id = maxId;
    return [[TGTelegramNetworking instance] requestSignal:request];
}

@end
