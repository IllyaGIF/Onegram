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

@class TGBotReplyMarkup;

@interface TGDatabase (OGCompatBotReplyMarkupStore)
- (void)storeBotReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup hideMarkupAuthorId:(int64_t)hideMarkupAuthorId forPeerId:(int64_t)peerId messageId:(int32_t)messageId;
@end

@interface TGConversationHistoryAsyncRequestActor ()
{
    int64_t _peerId;
    int32_t _fromMid;
    int32_t _upperBoundMid;
    int32_t _pageMaxMid;
    int32_t _pageLimit;
    int32_t _pageOffset;
    int32_t _watchdogEpoch;
    int32_t _retreatCount;
    bool _down;
    bool _finished;
    
    id<SDisposable> _disposable;
}

@end

static NSString *const OGCompatReactionSummaryKey = @"ios6ReactionSummary";

static void OGCompatReadReactions(TGMessage *message, NSString **summary, NSString **chosen)
{
    id stored = message.contentProperties[OGCompatReactionSummaryKey];
    NSString *summaryText = nil;
    NSString *chosenText = nil;
    if ([stored isKindOfClass:[TGMessageReactionSummaryContentProperty class]])
    {
        summaryText = ((TGMessageReactionSummaryContentProperty *)stored).summary;
        chosenText = ((TGMessageReactionSummaryContentProperty *)stored).chosenReaction;
    }
    else if ([stored isKindOfClass:[NSString class]])
        summaryText = stored;
    *summary = summaryText;
    *chosen = chosenText;
}

static bool OGCompatStringsMatch(NSString *a, NSString *b)
{
    return a == b || [a isEqualToString:b];
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

- (void)_dispatchHistoryRequest
{
    id previousToken = self.cancelToken;
    if (previousToken != nil)
    {
        [TGTelegraphInstance cancelRequestByToken:previousToken];
        self.cancelToken = nil;
    }
    
    int32_t epoch = ++_watchdogEpoch;
    self.cancelToken = [TGTelegraphInstance doRequestConversationHistory:_peerId accessHash:0 maxMid:_pageMaxMid orOffset:_pageOffset limit:_pageLimit actor:self];
    
    TGConversationHistoryAsyncRequestActor *strongSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10ll * NSEC_PER_SEC), dispatch_get_main_queue(), ^
    {
        if (strongSelf->_finished || epoch != strongSelf->_watchdogEpoch)
            return;
        
        if ([strongSelf _shrinkPageAfterTimeout])
        {
            [strongSelf _dispatchHistoryRequest];
            return;
        }
        
        strongSelf->_finished = true;
        NSString *timedOutPath = strongSelf.path;
        [ActionStageInstance() nodeRetrieveFailed:timedOutPath];
    });
}

- (bool)_shrinkPageAfterTimeout
{
    if (_down)
        return false;
    
    if (_pageLimit > 10)
        _pageLimit = 10;
    else if (_pageLimit > 1)
        _pageLimit = 1;
    else if (_pageMaxMid > 1 && _retreatCount < 20)
    {
        _retreatCount++;
        _pageMaxMid--;
        _pageLimit = 30;
    }
    else
        return false;
    
    return true;
}

- (void)execute:(NSDictionary *)options
{
    NSRange range;
    range.location = [@"/tg/conversations/(" length];
    range.length = self.path.length - [@")/asyncHistory" length] - range.location;
    int64_t conversationId = [[self.path substringWithRange:range] longLongValue];
    _peerId = conversationId;
    
    {
        range = [self.path rangeOfString:@"/asyncHistory/("];
        int maxMid = [[self.path substringWithRange:NSMakeRange(range.location + range.length, self.path.length - 1 - range.location - range.length)] intValue];
        int limit = 100;
        if ([options objectForKey:@"limit"] != nil)
            limit = [TGSchema intFromObject:[options objectForKey:@"limit"]];
        
        _fromMid = maxMid;
        _upperBoundMid = [options[@"maxMid"] intValue];
        _pageMaxMid = maxMid;
        _pageLimit = limit;
        
        int offset = 0;
        
        _down = [options[@"down"] boolValue];
        if (_down)
            offset = -limit;
        _pageOffset = offset;
        
        [self _dispatchHistoryRequest];
    }
}

- (bool)_claimCompletion
{
    if (_finished)
        return false;
    _finished = true;
    return true;
}

- (void)conversationHistoryRequestFailed
{
    if (![self _claimCompletion])
        return;
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)conversationHistoryRequestInvalidPeer:(NSString *)reason
{
    if ([self _claimCompletion] == false)
    {
        return;
    }
    TGLog(@"TRACE asyncHistory invalidPeer path=%@ reason=%@", self.path, reason);
    [ActionStageInstance() nodeRetrieveFailed:self.path];
}

- (void)conversationHistoryRequestSuccess:(TLmessages_Messages *)messages
{
    if (![self _claimCompletion])
        return;
    
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
    TGMessage *botKeyboardMessage = nil;
    
    NSArray *sourceMessages = [messages.messages copy];
    if (conversationId == -682867406LL && _upperBoundMid > 0)
    {
        NSMutableArray *withinBound = [[NSMutableArray alloc] init];
        for (NSUInteger index = 0; index < sourceMessages.count; index++)
        {
            TLMessage *candidate = sourceMessages[index];
            if (candidate.n_id < _upperBoundMid)
                [withinBound addObject:candidate];
        }
        sourceMessages = withinBound;
    }
    
    id replyPreload = [TGMessage beginReplyPreloadForTelegraphMessageDescs:sourceMessages];
    for (TLMessage *remoteDesc in sourceMessages)
    {
        TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:remoteDesc];
        if (!message.outgoing && message.mid > maxMid)
            maxMid = message.mid;
        bool carriesBotKeyboard = conversationId < 0 && !message.outgoing && message.fromUid == conversationId && message.replyMarkup != nil && !message.replyMarkup.isInline && message.replyMarkup.rows.count != 0;
        if (carriesBotKeyboard && (botKeyboardMessage == nil || message.mid > botKeyboardMessage.mid))
            botKeyboardMessage = message;
        minRemoteMid = MIN(minRemoteMid, message.mid);
        maxRemoteMid = MAX(maxRemoteMid, message.mid);
        [messageItems addObject:message];
    }
    [TGMessage endReplyPreload:replyPreload];
    if (botKeyboardMessage != nil)
    {
        [TGDatabaseInstance() storeBotReplyMarkup:botKeyboardMessage.replyMarkup hideMarkupAuthorId:botKeyboardMessage.fromUid forPeerId:conversationId messageId:botKeyboardMessage.mid];
    }
    
    [TGDatabaseInstance() storePeerMinMid:conversationId minMid:messageItems.count == 0 || minRemoteMid <= 1 ? 1 : 0];
    
    dispatch_block_t continueBlock = ^
    {
        [TGDatabaseInstance() transactionAddMessages:messageItems updateConversationDatas:otherConversations notifyAdded:false];

        NSMutableArray *refreshedReactions = [[NSMutableArray alloc] init];
        for (NSUInteger itemIndex = 0; itemIndex < messageItems.count; itemIndex++)
        {
            TGMessage *remoteMessage = messageItems[itemIndex];
            int32_t remoteMid = remoteMessage.mid;
            if (remoteMid == 0)
                continue;
            TGMessage *storedMessage = [TGDatabaseInstance() loadMessageWithMid:remoteMid peerId:conversationId];
            if (!storedMessage)
                continue;

            NSString *remoteSummary = nil;
            NSString *remoteChosen = nil;
            NSString *storedSummary = nil;
            NSString *storedChosen = nil;
            OGCompatReadReactions(remoteMessage, &remoteSummary, &remoteChosen);
            OGCompatReadReactions(storedMessage, &storedSummary, &storedChosen);
            if (OGCompatStringsMatch(remoteSummary, storedSummary) && OGCompatStringsMatch(remoteChosen, storedChosen))
                continue;

            NSMutableDictionary *mergedProperties = [NSMutableDictionary dictionaryWithDictionary:storedMessage.contentProperties ?: @{}];
            if (remoteSummary.length > 0)
                mergedProperties[OGCompatReactionSummaryKey] = [[TGMessageReactionSummaryContentProperty alloc] initWithSummary:remoteSummary chosenReaction:remoteChosen];
            else
                [mergedProperties removeObjectForKey:OGCompatReactionSummaryKey];
            storedMessage.contentProperties = mergedProperties;
            TGDatabaseUpdateMessageWithMessage *refresh = [[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:conversationId messageId:remoteMessage.mid message:storedMessage dispatchEdited:true];
            [refreshedReactions addObject:refresh];
        }
        if (refreshedReactions.count > 0)
            [TGDatabaseInstance() transactionUpdateMessages:refreshedReactions updateConversationDatas:nil];
        
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
    NSMutableDictionary *messagesById = [[NSMutableDictionary alloc] initWithCapacity:completeMessages.count];
    for (TGMessage *message in completeMessages)
    {
        if (message.mid != 0)
            messagesById[@(message.mid)] = message;
    }

    for (TGMessage *message in completeMessages)
    {
        for (id attachment in message.mediaAttachments)
        {
            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
            {
                TGReplyMessageMediaAttachment *replyAttachment = attachment;
                if (replyAttachment.replyMessage != nil || replyAttachment.replyMessageId == 0)
                    continue;
                
                TGMessage *replyMessage = messagesById[@(replyAttachment.replyMessageId)];
                if (replyMessage != nil)
                    replyAttachment.replyMessage = replyMessage;
            }
        }
    }

    return [SSignal single:completeMessages];
}

@end
