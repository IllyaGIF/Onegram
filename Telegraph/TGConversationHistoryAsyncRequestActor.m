#import "TGConversationHistoryAsyncRequestActor.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGSchema.h"

#import "TGTelegraph.h"

#import "TGUserDataRequestBuilder.h"

#import "TGConversation+Telegraph.h"
#import "TGMessage+Telegraph.h"

#import "TGConversationAddMessagesActor.h"
#import "TGDatabase.h"
#import "TGDatabaseUpdateMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessageViewCountContentProperty.h"

@class TGDatabase;
@class TGBotReplyMarkup;

@interface TGDatabase (IOS6BotReplyMarkupStore)
- (void)storeBotReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup hideMarkupAuthorId:(int32_t)hideMarkupAuthorId forPeerId:(int64_t)peerId messageId:(int32_t)messageId;
@end

@interface TGConversationHistoryAsyncRequestActor ()
{
    int32_t _fromMid;
    int32_t _requestedMaxMid;
    int64_t _conversationId;
    int32_t _currentMaxMid;
    int32_t _currentLimit;
    int32_t _currentOffset;
    int32_t _timeoutGeneration;
    int32_t _skipAttempts;
    bool _down;
    bool _completed;
    
    id<SDisposable> _disposable;
}

@end

static NSString *TGIOS6HistoryReactionSummary(TGMessage *message)
{
    id value = [message.contentProperties objectForKey:@"ios6ReactionSummary"];
    if ([value isKindOfClass:[TGMessageReactionSummaryContentProperty class]])
        return ((TGMessageReactionSummaryContentProperty *)value).summary;
    if ([value isKindOfClass:[NSString class]])
        return value;
    return nil;
}

static NSString *TGIOS6HistoryChosenReaction(TGMessage *message)
{
    id value = [message.contentProperties objectForKey:@"ios6ReactionSummary"];
    if ([value isKindOfClass:[TGMessageReactionSummaryContentProperty class]])
        return ((TGMessageReactionSummaryContentProperty *)value).chosenReaction;
    return nil;
}

@implementation TGConversationHistoryAsyncRequestActor

+ (NSString *)genericPath
{
    return @"/tg/conversations/@/asyncHistory/@";
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        self.requestQueueName = @"messages";
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (void)_startHistoryRequest
{
    if (self.cancelToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:self.cancelToken];
        self.cancelToken = nil;
    }
    
    int32_t generation = ++_timeoutGeneration;
    self.cancelToken = [TGTelegraphInstance doRequestConversationHistory:_conversationId accessHash:0 maxMid:_currentMaxMid orOffset:_currentOffset limit:_currentLimit actor:self];
    
    TGConversationHistoryAsyncRequestActor *strongSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^
    {
        if (strongSelf->_completed || generation != strongSelf->_timeoutGeneration)
            return;
        
        
        if (!strongSelf->_down)
        {
            if (strongSelf->_currentLimit > 10)
            {
                strongSelf->_currentLimit = 10;
                [strongSelf _startHistoryRequest];
                return;
            }
            else if (strongSelf->_currentLimit > 1)
            {
                strongSelf->_currentLimit = 1;
                [strongSelf _startHistoryRequest];
                return;
            }
            else if (strongSelf->_currentMaxMid > 1 && strongSelf->_skipAttempts < 20)
            {
                strongSelf->_skipAttempts++;
                strongSelf->_currentMaxMid--;
                strongSelf->_currentLimit = 30;
                [strongSelf _startHistoryRequest];
                return;
            }
        }
        
        strongSelf->_completed = true;
        [ActionStageInstance() nodeRetrieveFailed:strongSelf.path];
    });
}

- (void)execute:(NSDictionary *)options
{
    NSRange range;
    range.location = [@"/tg/conversations/(" length];
    range.length = self.path.length - [@")/asyncHistory" length] - range.location;
    int64_t conversationId = [[self.path substringWithRange:range] longLongValue];
    _conversationId = conversationId;
    
    {
        range = [self.path rangeOfString:@"/asyncHistory/("];
        int maxMid = [[self.path substringWithRange:NSMakeRange(range.location + range.length, self.path.length - 1 - range.location - range.length)] intValue];
        int limit = 100;
        if ([options objectForKey:@"limit"] != nil)
            limit = [TGSchema intFromObject:[options objectForKey:@"limit"]];
        
        _fromMid = maxMid;
        _requestedMaxMid = [options[@"maxMid"] intValue];
        _currentMaxMid = maxMid;
        _currentLimit = limit;
        
        int offset = 0;
        
        _down = [options[@"down"] boolValue];
        if (_down)
            offset = -limit;
        _currentOffset = offset;
        
        
        [self _startHistoryRequest];
    }
}

- (void)conversationHistoryRequestFailed
{
    if (_completed)
        return;
    _completed = true;
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)conversationHistoryRequestInvalidPeer:(NSString *)reason
{
    if (_completed)
        return;
    _completed = true;
    TGLog(@"TRACE asyncHistory invalidPeer path=%@ reason=%@", self.path, reason);
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)conversationHistoryRequestSuccess:(TLmessages_Messages *)messages
{
    if (_completed)
        return;
    _completed = true;
    
    [TGUserDataRequestBuilder executeUserDataUpdate:messages.users];
    
    NSRange range;
    range.location = [@"/tg/conversations/(" length];
    range.length = self.path.length - [@")/asyncHistory" length] - range.location;
    int64_t conversationId = [[self.path substringWithRange:range] longLongValue];
    range = [self.path rangeOfString:@"/asyncHistory/("];
    
    TGConversation *conversation = nil;
    NSMutableDictionary *otherConversations = [[NSMutableDictionary alloc] init];
    
    for (TLChat *chatDesc in messages.chats)
    {
        TGConversation *chatConversation = [[TGConversation alloc] initWithTelegraphChatDesc:chatDesc];
        if (chatConversation.conversationId == conversationId) {
            conversation = chatConversation;
        } else if (chatConversation.conversationId != 0) {
            otherConversations[@(chatConversation.conversationId)] = chatConversation;
        }
    }
    
    NSMutableArray *messageItems = [[NSMutableArray alloc] init];
    
    int maxMid = 0;
    
    int minRemoteMid = INT_MAX;
    int maxRemoteMid = 0;
    int minRemoteDate = 0;
    int maxRemoteDate = 0;
    int incomingCount = 0;
    int outgoingCount = 0;
    TGMessage *latestIncomingBotReplyMarkupMessage = nil;
    
    NSArray *sourceMessages = messages.messages;
    if (conversationId == -682867406LL && _requestedMaxMid > 0)
    {
        NSMutableArray *filteredSourceMessages = [[NSMutableArray alloc] init];
        for (TLMessage *messageDesc in sourceMessages)
        {
            if (messageDesc.n_id < _requestedMaxMid)
                [filteredSourceMessages addObject:messageDesc];
        }
        sourceMessages = filteredSourceMessages;
    }
    
    for (TLMessage *messageDesc in sourceMessages)
    {
        TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:messageDesc];
        if (message.outgoing)
            outgoingCount++;
        else
            incomingCount++;
        if (!message.outgoing && message.mid > maxMid)
            maxMid = message.mid;
        if (conversationId < 0 && !message.outgoing && message.fromUid == conversationId && message.replyMarkup != nil && !message.replyMarkup.isInline && message.replyMarkup.rows.count != 0)
        {
            if (latestIncomingBotReplyMarkupMessage == nil || message.mid > latestIncomingBotReplyMarkupMessage.mid)
                latestIncomingBotReplyMarkupMessage = message;
        }
        minRemoteMid = MIN(minRemoteMid, message.mid);
        maxRemoteMid = MAX(maxRemoteMid, message.mid);
        if (message.mid != 0)
        {
            if (minRemoteDate == 0 || minRemoteDate > (int)message.date)
                minRemoteDate = (int)message.date;
            if (maxRemoteDate == 0 || maxRemoteDate < (int)message.date)
                maxRemoteDate = (int)message.date;
        }
        [messageItems addObject:message];
    }
    if (latestIncomingBotReplyMarkupMessage != nil)
    {
        [TGDatabaseInstance() storeBotReplyMarkup:latestIncomingBotReplyMarkupMessage.replyMarkup hideMarkupAuthorId:(int32_t)latestIncomingBotReplyMarkupMessage.fromUid forPeerId:conversationId messageId:latestIncomingBotReplyMarkupMessage.mid];
    }
    
    [TGDatabaseInstance() storePeerMinMid:conversationId minMid:messageItems.count == 0 || minRemoteMid <= 1 ? 1 : 0];
    
    dispatch_block_t continueBlock = ^
    {
        [TGDatabaseInstance() transactionAddMessages:messageItems updateConversationDatas:otherConversations notifyAdded:false];

        NSMutableArray *reactionUpdates = [[NSMutableArray alloc] init];
        for (TGMessage *remoteMessage in messageItems)
        {
            if (remoteMessage.mid == 0)
                continue;

            TGMessage *storedMessage = [TGDatabaseInstance() loadMessageWithMid:remoteMessage.mid peerId:conversationId];
            if (storedMessage == nil)
                continue;

            NSString *remoteSummary = TGIOS6HistoryReactionSummary(remoteMessage);
            NSString *storedSummary = TGIOS6HistoryReactionSummary(storedMessage);
            NSString *remoteChosenReaction = TGIOS6HistoryChosenReaction(remoteMessage);
            NSString *storedChosenReaction = TGIOS6HistoryChosenReaction(storedMessage);
            bool summariesEqual = remoteSummary == storedSummary || [remoteSummary isEqualToString:storedSummary];
            bool chosenEqual = remoteChosenReaction == storedChosenReaction || [remoteChosenReaction isEqualToString:storedChosenReaction];
            if (summariesEqual && chosenEqual)
                continue;

            NSMutableDictionary *properties = [[NSMutableDictionary alloc] initWithDictionary:storedMessage.contentProperties ?: @{}];
            if (remoteSummary.length != 0)
                [properties setObject:[[TGMessageReactionSummaryContentProperty alloc] initWithSummary:remoteSummary chosenReaction:remoteChosenReaction] forKey:@"ios6ReactionSummary"];
            else
                [properties removeObjectForKey:@"ios6ReactionSummary"];
            storedMessage.contentProperties = properties;
            [reactionUpdates addObject:[[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:conversationId messageId:remoteMessage.mid message:storedMessage dispatchEdited:true]];
        }
        if (reactionUpdates.count != 0)
            [TGDatabaseInstance() transactionUpdateMessages:reactionUpdates updateConversationDatas:nil];
        
        if (_down && _fromMid > 0 && maxRemoteMid >= _fromMid)
        {
            [TGDatabaseInstance() fillConversationHistoryHole:conversationId indexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange((NSUInteger)_fromMid, (NSUInteger)((int64_t)maxRemoteMid - _fromMid + 1))]];
        }
        else if (!_down && minRemoteMid > 0 && minRemoteMid <= _fromMid)
        {
            [TGDatabaseInstance() fillConversationHistoryHole:conversationId indexSet:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange((NSUInteger)minRemoteMid, (NSUInteger)((int64_t)_fromMid - minRemoteMid + 1))]];
        }
        
        if (maxMid > 0)
        {
            [TGDatabaseInstance() updateLatestMessageId:maxMid applied:false completion:^(int greaterMidForSynchronization)
             {
                 if (greaterMidForSynchronization > 0)
                 {
                     [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/messages/reportDelivery/(messages)"] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:maxMid], @"mid", nil] watcher:TGTelegraphInstance];
                 }
             }];
        }
        
        [ActionStageInstance() actionCompleted:self.path result:messageItems];
    };
    
    [[self signalForCompleteMessages:messageItems] startWithNext:^(__unused NSArray *processedMessages)
    {
    } error:^(__unused id error)
    {
        continueBlock();
    } completed:^
    {
        continueBlock();
    }];
}

- (SSignal *)signalForCompleteMessages:(NSArray *)completeMessages
{
    NSMutableDictionary *messageIdToMessage = [[NSMutableDictionary alloc] initWithCapacity:completeMessages.count];
    for (TGMessage *message in completeMessages) {
        if (message.mid != 0)
            messageIdToMessage[@(message.mid)] = message;
    }

    NSUInteger unresolvedReplyCount = 0;
    for (TGMessage *message in completeMessages)
    {
        for (id attachment in message.mediaAttachments)
        {
            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
            {
                TGReplyMessageMediaAttachment *replyAttachment = attachment;
                if (replyAttachment.replyMessage == nil && replyAttachment.replyMessageId != 0) {
                    TGMessage *replyMessage = messageIdToMessage[@(replyAttachment.replyMessageId)];
                    if (replyMessage != nil)
                        replyAttachment.replyMessage = replyMessage;
                    else
                        unresolvedReplyCount++;
                }
            }
        }
    }

    return [SSignal single:completeMessages];
}

@end
