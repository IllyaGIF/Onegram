#import "TGPollSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPollMediaAttachment+Telegraph.h"
#import "TGTelegramNetworking.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGDatabaseUpdateMessage.h"
#import "TLRPCmessages_sendMessage_manual.h"
#import "TLUpdates+TG.h"

static NSMutableDictionary *TGPollMessageIndex(void)
{
    static NSMutableDictionary *index = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        index = [[NSMutableDictionary alloc] init];
    });
    return index;
}

static NSString *TGPollMessageKey(int64_t peerId, int32_t messageId)
{
    return [[NSString alloc] initWithFormat:@"%lld:%d", peerId, messageId];
}

@interface TGPollSignals ()

+ (NSArray *)registeredMessageKeysForPollId:(int64_t)pollId;
+ (NSArray *)databaseUpdatesForMessages:(NSArray *)messages;

@end

@implementation TGPollSignals

+ (SSignal *)updatesSignalForRequest:(TLMetaRpc *)request
{
    return [[[TGTelegramNetworking instance] requestSignal:request] mapToSignal:^SSignal *(TLUpdates *updates)
    {
        if (![updates isKindOfClass:[TLUpdates class]])
            return [SSignal single:@[]];
        return [TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id
        {
            NSArray *messages = [self messagesByApplyingPollUpdates:[updates updatesList] baseMessages:nil];
            if (messages.count != 0)
                [TGDatabaseInstance() transactionUpdateMessages:[self databaseUpdatesForMessages:messages] updateConversationDatas:nil];
            [[TGTelegramNetworking instance] addUpdates:updates];
            return messages;
        }];
    }];
}

+ (SSignal *)voteWithPeerId:(int64_t)peerId accessHash:(int64_t)accessHash messageId:(int32_t)messageId options:(NSArray *)options
{
    TLRPCmessages_sendVote_manual *request = [[TLRPCmessages_sendVote_manual alloc] init];
    request.peer = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:accessHash];
    request.msg_id = messageId;
    request.options = options ?: @[];
    return [self updatesSignalForRequest:request];
}

+ (SSignal *)pollResultsWithPeerId:(int64_t)peerId accessHash:(int64_t)accessHash messageId:(int32_t)messageId pollHash:(int64_t)pollHash
{
    TLRPCmessages_getPollResults_manual *request = [[TLRPCmessages_getPollResults_manual alloc] init];
    request.peer = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:accessHash];
    request.msg_id = messageId;
    request.poll_hash = pollHash;
    return [self updatesSignalForRequest:request];
}

+ (SSignal *)closePoll:(TGPollMediaAttachment *)poll peerId:(int64_t)peerId accessHash:(int64_t)accessHash messageId:(int32_t)messageId
{
    TLRPCmessages_editMessagePoll_manual *request = [[TLRPCmessages_editMessagePoll_manual alloc] init];
    request.peer = [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:accessHash];
    request.msg_id = messageId;
    request.poll = [poll telegraphPollForClosing];
    request.correct_answers = [poll quiz] ? [poll correctAnswerIndices] : nil;
    return [self updatesSignalForRequest:request];
}

+ (void)reloadForAccountSwitch
{
    NSMutableDictionary *index = TGPollMessageIndex();
    @synchronized (index)
    {
        [index removeAllObjects];
    }
}

+ (void)registerPollId:(int64_t)pollId peerId:(int64_t)peerId messageId:(int32_t)messageId
{
    if (pollId == 0 || peerId == 0 || messageId <= 0)
        return;
    NSMutableDictionary *index = TGPollMessageIndex();
    @synchronized (index)
    {
        NSMutableSet *keys = index[@(pollId)];
        if (keys == nil)
        {
            keys = [[NSMutableSet alloc] init];
            index[@(pollId)] = keys;
        }
        [keys addObject:TGPollMessageKey(peerId, messageId)];
    }
}

+ (NSArray *)registeredMessageKeysForPollId:(int64_t)pollId
{
    NSMutableDictionary *index = TGPollMessageIndex();
    @synchronized (index)
    {
        return [index[@(pollId)] allObjects] ?: @[];
    }
}

+ (TGMessage *)message:(TGMessage *)message byApplyingPoll:(TGPollMediaAttachment *)poll pollId:(int64_t)pollId results:(TGPollResults *)results
{
    if (message == nil)
        return nil;
    bool changed = false;
    NSMutableArray *attachments = [[NSMutableArray alloc] initWithCapacity:message.mediaAttachments.count];
    for (id attachment in message.mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGPollMediaAttachment class]] && ((TGPollMediaAttachment *)attachment).pollId == pollId)
        {
            [attachments addObject:[(TGPollMediaAttachment *)attachment pollByApplyingPoll:poll results:results]];
            changed = true;
        }
        else
            [attachments addObject:attachment];
    }
    if (!changed)
        return nil;
    TGMessage *updatedMessage = [message copy];
    updatedMessage.mediaAttachments = attachments;
    return updatedMessage;
}

+ (NSArray *)messageUpdatesForPollUpdates:(NSArray *)updates baseMessages:(NSArray *)baseMessages
{
    return [self databaseUpdatesForMessages:[self messagesByApplyingPollUpdates:updates baseMessages:baseMessages]];
}

+ (NSArray *)databaseUpdatesForMessages:(NSArray *)messages
{
    NSMutableArray *messageUpdates = [[NSMutableArray alloc] initWithCapacity:messages.count];
    for (TGMessage *message in messages)
        [messageUpdates addObject:[[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:message.cid messageId:message.mid message:message dispatchEdited:true]];
    return messageUpdates;
}

+ (NSArray *)messagesByApplyingPollUpdates:(NSArray *)updates baseMessages:(NSArray *)baseMessages
{
    NSMutableDictionary *updatedMessages = [[NSMutableDictionary alloc] init];
    NSMutableArray *updatedKeys = [[NSMutableArray alloc] init];
    NSMutableDictionary *messagesByKey = [[NSMutableDictionary alloc] init];
    for (TGMessage *message in baseMessages)
        messagesByKey[TGPollMessageKey(message.cid, message.mid)] = message;

    for (TLUpdate$updateMessagePollCodex *update in updates)
    {
        if (![update isKindOfClass:[TLUpdate$updateMessagePollCodex class]] || update.poll_id == 0)
            continue;

        TGPollMediaAttachment *poll = update.poll != nil ? [TGPollMediaAttachment pollWithTelegraphPoll:update.poll results:nil] : nil;
        TGPollResults *results = [TGPollMediaAttachment pollResultsWithTelegraphResults:update.results];

        NSMutableArray *keys = [[NSMutableArray alloc] initWithArray:[self registeredMessageKeysForPollId:update.poll_id]];
        int64_t updatePeerId = [TGPollMediaAttachment peerIdWithTelegraphPeer:update.peer];
        if (updatePeerId != 0 && update.msg_id > 0)
        {
            NSString *key = TGPollMessageKey(updatePeerId, update.msg_id);
            if (![keys containsObject:key])
                [keys addObject:key];
        }

        for (NSString *key in keys)
        {
            NSArray *components = [key componentsSeparatedByString:@":"];
            if (components.count != 2)
                continue;
            int64_t peerId = [components[0] longLongValue];
            int32_t messageId = [components[1] intValue];

            TGMessage *message = updatedMessages[key];
            if (message == nil)
                message = messagesByKey[key];
            if (message == nil)
                message = [TGDatabaseInstance() loadMessageWithMid:messageId peerId:peerId];
            TGMessage *updatedMessage = [self message:message byApplyingPoll:poll pollId:update.poll_id results:results];
            if (updatedMessage == nil)
                continue;
            if (updatedMessages[key] == nil)
                [updatedKeys addObject:key];
            updatedMessages[key] = updatedMessage;
            [self registerPollId:update.poll_id peerId:peerId messageId:messageId];
        }
    }

    NSMutableArray *messages = [[NSMutableArray alloc] initWithCapacity:updatedKeys.count];
    for (NSString *key in updatedKeys)
        [messages addObject:updatedMessages[key]];
    return messages;
}

@end
