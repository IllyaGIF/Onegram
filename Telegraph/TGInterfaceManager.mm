#import "TGInterfaceManager.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGAppDelegate.h"
#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"

#import "TGTelegraph.h"

#import "TGDatabase.h"

#import "TGLinearProgressView.h"

#import "TGModernConversationController.h"
#import "TGModernViewContext.h"
#import "TGGroupModernConversationCompanion.h"
#import "TGPrivateModernConversationCompanion.h"
#import "TGSecretModernConversationCompanion.h"
#import "TGChannelConversationCompanion.h"

#import "TGTelegraphUserInfoController.h"
#import "TGSecretChatUserInfoController.h"
#import "TGPhonebookUserInfoController.h"
#import "TGBotUserInfoController.h"

#import "TGGenericPeerMediaListModel.h"
#import "TGModernMediaListController.h"

#import "TGNotificationController.h"

#import "TGSharedMediaController.h"
#import "TGEmbedPIPController.h"

#import "TGHashtagOverviewController.h"

#import "TGCustomAlertView.h"

#import "TGCallSession.h"
#import "TGCallController.h"
#import "TGCallStatusBarView.h"
#import "TGCallAlertView.h"
#import "TGCallUtils.h"

#import "TGCallRatingView.h"

#import "TGMusicPlayerController.h"

#import "TGAdminLogConversationCompanion.h"
#import "TGFeedConversationCompanion.h"

#import "TGLegacyComponentsContext.h"

#import "TGPresentation.h"

#import "TLMetaClassStore.h"
#import "TLMetaRpc.h"
#import "TLInputPeer.h"
#import "TLInputChannel.h"
#import "TLmessages_Messages.h"
#import "TLmessages_Chats.h"
#import "TGConversation+Telegraph.h"
#import "TGMessage+Telegraph.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "TGMessageModernConversationItem.h"
#import "TGPreparedForwardedMessage.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGMessageViewCountContentProperty.h"
#import "TGUserDataRequestBuilder.h"
#import "TLDocument.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"
#import "NSOutputStream+TL.h"


#pragma mark - iOS 6 Forum Topics

@interface TGIOS6GetForumTopicsRpc : TLMetaRpc
@property (nonatomic) int32_t flags;
@property (nonatomic, strong) TLInputChannel *channel;
@property (nonatomic, strong) NSString *query;
@property (nonatomic) int32_t offsetDate;
@property (nonatomic) int32_t offsetId;
@property (nonatomic) int32_t offsetTopic;
@property (nonatomic) int32_t limit;
@end

@implementation TGIOS6GetForumTopicsRpc
- (int32_t)TLconstructorSignature { return (int32_t)0x0de560d1; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLmessages_Messages class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:self.flags];
    TLMetaClassStore::serializeObject(os, self.channel, true);
    if (self.flags & (1 << 0))
        [os writeString:self.query == nil ? @"" : self.query];
    [os writeInt32:self.offsetDate];
    [os writeInt32:self.offsetId];
    [os writeInt32:self.offsetTopic];
    [os writeInt32:self.limit];
}
@end

@interface TGIOS6GetChannelsRpc : TLMetaRpc
@property (nonatomic, strong) NSArray *channels;
@end

@implementation TGIOS6GetChannelsRpc
- (int32_t)TLconstructorSignature { return (int32_t)0x0a7f6bbb; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLmessages_Chats class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:(int32_t)0x1cb5c415];
    [os writeInt32:(int32_t)self.channels.count];
    for (TLInputChannel *channel in self.channels)
        TLMetaClassStore::serializeObject(os, channel, true);
}
@end

@interface TGIOS6GetCustomEmojiDocumentsRpc : TLMetaRpc
@property (nonatomic, strong) NSArray *documentIds;
@end

@implementation TGIOS6GetCustomEmojiDocumentsRpc
- (int32_t)TLconstructorSignature { return (int32_t)0xd9ab0f54; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLDocument class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)os
{
    [os writeInt32:(int32_t)0x1cb5c415];
    [os writeInt32:(int32_t)self.documentIds.count];
    for (NSNumber *documentId in self.documentIds)
        [os writeInt64:[documentId longLongValue]];
}
@end

@interface TGIOS6GetDiscussionMessageRpc : TLMetaRpc
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t messageId;
@end

@implementation TGIOS6GetDiscussionMessageRpc
- (int32_t)TLconstructorSignature { return (int32_t)0x446972fd; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [NSDictionary class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)os
{
    TLMetaClassStore::serializeObject(os, self.peer, true);
    [os writeInt32:self.messageId];
}
@end

@interface TGIOS6GetRepliesRpc : TLMetaRpc
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t messageId;
@property (nonatomic) int32_t offsetId;
@property (nonatomic) int32_t offsetDate;
@property (nonatomic) int32_t addOffset;
@property (nonatomic) int32_t limit;
@property (nonatomic) int32_t maxId;
@property (nonatomic) int32_t minId;
@property (nonatomic) int64_t hashValue;
@end

@implementation TGIOS6GetRepliesRpc
- (int32_t)TLconstructorSignature { return (int32_t)0x22ddd30c; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [TLmessages_Messages class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)os
{
    TLMetaClassStore::serializeObject(os, self.peer, true);
    [os writeInt32:self.messageId];
    [os writeInt32:self.offsetId];
    [os writeInt32:self.offsetDate];
    [os writeInt32:self.addOffset];
    [os writeInt32:self.limit];
    [os writeInt32:self.maxId];
    [os writeInt32:self.minId];
    [os writeInt64:self.hashValue];
}
@end

@interface TGIOS6ReadDiscussionRpc : TLMetaRpc
@property (nonatomic, strong) TLInputPeer *peer;
@property (nonatomic) int32_t messageId;
@property (nonatomic) int32_t readMaxId;
@end

@implementation TGIOS6ReadDiscussionRpc
- (int32_t)TLconstructorSignature { return (int32_t)0xf731a9f4; }
- (int32_t)TLconstructorName { return -1; }
- (Class)responseClass { return [NSNumber class]; }
- (int)impliedResponseSignature { return 0; }
- (int)layerVersion { return 181; }
- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject { return nil; }
- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values { }
- (void)TLserialize:(NSOutputStream *)os
{
    TLMetaClassStore::serializeObject(os, self.peer, true);
    [os writeInt32:self.messageId];
    [os writeInt32:self.readMaxId];
}
@end

#pragma mark - Native forum topic conversation

@interface TGGenericModernConversationCompanion (TGIOS6ForumForwardingPrivate)
- (NSArray *)_createPreparedMessagesFromFiles:(NSArray *)files asReplyToMessageId:(int32_t)replyMessageId;
- (NSArray *)_createPreparedForwardMessagesFromMessages:(NSArray *)messages;
@end

@interface TGChannelConversationCompanion (TGIOS6DiscussionInputPrivate)
- (TGModernConversationInputPanel *)_conversationGenericInputPanel;
- (SSignal *)_requestPinnedMessages;
@end

@class TGIOS6ForumTopicConversationCompanion;

@interface TGIOS6ForumTopicConversationCompanionReference : NSObject
@property (nonatomic, weak) TGIOS6ForumTopicConversationCompanion *value;
@end

@implementation TGIOS6ForumTopicConversationCompanionReference
@end

static TGIOS6ForumTopicConversationCompanion *TGIOS6ResolveForumTopicConversationCompanion(TGIOS6ForumTopicConversationCompanionReference *reference)
{
    TGIOS6ForumTopicConversationCompanion *result = nil;
    @synchronized (reference)
    {
        result = reference.value;
    }
    return result;
}

@interface TGIOS6ForumTopicConversationCompanion : TGChannelConversationCompanion
{
    TGConversation *_ios6TopicConversation;
    int32_t _ios6TopicId;
    int32_t _ios6TopicTopMessageId;
    NSString *_ios6TopicTitle;
    bool _ios6TopicLoadingAbove;
    bool _ios6TopicHasMoreAbove;
    id<SDisposable> _ios6TopicHistoryDisposable;
    id<SDisposable> _ios6TopicReadDisposable;
    int32_t _ios6TopicRequestedReadMaxId;
    int32_t _ios6TopicLastReadMaxId;
    bool _ios6DiscussionThread;
    TGMessage *_ios6DiscussionRootMessage;
    TGIOS6ForumTopicConversationCompanionReference *_ios6LifetimeReference;
    int _ios6TopicHistoryGeneration;
    int _ios6TopicReadGeneration;
}
- (instancetype)initWithConversation:(TGConversation *)conversation
                      userActivities:(NSDictionary *)userActivities
                             topicId:(int32_t)topicId
                        topMessageId:(int32_t)topMessageId
                               title:(NSString *)title;
- (int32_t)forumTopicId;
- (void)setDiscussionThread:(bool)discussionThread;
- (void)setDiscussionRootMessage:(TGMessage *)rootMessage;
@end

@implementation TGIOS6ForumTopicConversationCompanion

- (instancetype)initWithConversation:(TGConversation *)conversation
                      userActivities:(NSDictionary *)userActivities
                             topicId:(int32_t)topicId
                        topMessageId:(int32_t)topMessageId
                               title:(NSString *)title
{
    self = [super initWithConversation:conversation userActivities:userActivities];
    if (self != nil)
    {
        _ios6TopicConversation = conversation;
        _ios6TopicId = topicId;
        _ios6TopicTopMessageId = topMessageId;
        _ios6TopicTitle = title.length != 0 ? [title copy] : [conversation.chatTitle copy];
        _ios6TopicHasMoreAbove = true;
        _ios6TopicLoadingAbove = false;
        _ios6LifetimeReference = [[TGIOS6ForumTopicConversationCompanionReference alloc] init];
        _ios6LifetimeReference.value = self;
    }
    return self;
}

- (void)dealloc
{
    @synchronized (_ios6LifetimeReference)
    {
        _ios6LifetimeReference.value = nil;
    }
    [_ios6TopicHistoryDisposable dispose];
    [_ios6TopicReadDisposable dispose];
}

- (int32_t)forumTopicId
{
    return _ios6TopicId;
}

- (void)setDiscussionThread:(bool)discussionThread
{
    _ios6DiscussionThread = discussionThread;
}

- (void)setDiscussionRootMessage:(TGMessage *)rootMessage
{
    _ios6DiscussionRootMessage = [rootMessage copy];
    if (_ios6DiscussionRootMessage != nil)
    {
        _ios6DiscussionRootMessage.cid = _ios6TopicConversation.conversationId;
        NSMutableDictionary *properties = _ios6DiscussionRootMessage.contentProperties != nil ? [_ios6DiscussionRootMessage.contentProperties mutableCopy] : [[NSMutableDictionary alloc] init];
        properties[@"ios6ForumTopicId"] = [[TGMessageForumTopicContentProperty alloc] initWithTopicId:_ios6TopicId];
        _ios6DiscussionRootMessage.contentProperties = properties;
    }
}

- (TGModernConversationInputPanel *)_conversationGenericInputPanel
{
    if (_ios6DiscussionThread)
        return nil;
    return [super _conversationGenericInputPanel];
}

- (bool)allowReplies
{
    return _ios6DiscussionThread ? true : [super allowReplies];
}

- (NSString *)title
{
    return _ios6TopicTitle.length != 0 ? _ios6TopicTitle : [super title];
}

- (SSignal *)primaryTitlePanel
{
    return [super primaryTitlePanel];
}

- (SSignal *)_requestPinnedMessages
{
    int32_t topicId = _ios6TopicId;
    return [[super _requestPinnedMessages] map:^id(id value)
    {
        if (![value isKindOfClass:[NSArray class]])
            return value;

        NSMutableArray *result = [[NSMutableArray alloc] init];
        for (TGMessage *message in (NSArray *)value)
        {
            if (message == nil)
                continue;
            if (message.mid == topicId)
            {
                [result addObject:message];
                continue;
            }

            id topicProperty = message.contentProperties[@"ios6ForumTopicId"];
            int32_t messageTopicId = 0;
            if ([topicProperty isKindOfClass:[TGMessageForumTopicContentProperty class]])
                messageTopicId = ((TGMessageForumTopicContentProperty *)topicProperty).topicId;
            else if ([topicProperty respondsToSelector:@selector(intValue)])
                messageTopicId = [topicProperty intValue];

            if (messageTopicId == topicId || (topicId == 1 && messageTopicId == 0))
                [result addObject:message];
        }
        return result;
    }];
}

- (void)_ios6ApplyTopicIdentity
{
    [self _setTitle:_ios6TopicTitle];
    [self _setAvatarConversationId:_ios6TopicConversation.conversationId
                              title:_ios6TopicConversation.chatTitle
                               icon:nil];
    [self _setAvatarUrl:_ios6TopicConversation.chatPhotoFullSmall];
}

- (void)_ios6ReadDiscussionUpTo:(int32_t)readMaxId reason:(NSString *)reason
{
    if (_ios6TopicId == 0 || readMaxId <= 0 || _ios6TopicConversation == nil)
        return;
    if (readMaxId <= _ios6TopicRequestedReadMaxId)
        return;

    TLInputPeer *peer = [TGTelegraphInstance createInputPeerForConversation:_ios6TopicConversation.conversationId
                                                                 accessHash:_ios6TopicConversation.accessHash];
    if (peer == nil)
    {
        NSLog(@"FORUM thread.read.invalidPeer peer=%lld topic=%d max=%d reason=%@",
              _ios6TopicConversation.conversationId, _ios6TopicId, readMaxId, reason);
        return;
    }

    TGIOS6ReadDiscussionRpc *rpc = [[TGIOS6ReadDiscussionRpc alloc] init];
    rpc.peer = peer;
    rpc.messageId = _ios6TopicId;
    rpc.readMaxId = readMaxId;

    _ios6TopicRequestedReadMaxId = readMaxId;
    NSLog(@"FORUM thread.read.request peer=%lld topic=%d max=%d reason=%@",
          _ios6TopicConversation.conversationId, _ios6TopicId, readMaxId, reason);

    [_ios6TopicReadDisposable dispose];
    int generation = ++_ios6TopicReadGeneration;
    TGIOS6ForumTopicConversationCompanionReference *reference = _ios6LifetimeReference;
    _ios6TopicReadDisposable = [[[[TGTelegramNetworking instance] requestSignal:rpc]
        deliverOn:[SQueue mainQueue]]
        startWithNext:^(__unused id result)
        {
            TGIOS6ForumTopicConversationCompanion *strongSelf = TGIOS6ResolveForumTopicConversationCompanion(reference);
            if (strongSelf == nil || strongSelf->_ios6TopicReadGeneration != generation)
                return;

            strongSelf->_ios6TopicLastReadMaxId = MAX(strongSelf->_ios6TopicLastReadMaxId, readMaxId);
            NSLog(@"FORUM thread.read.ok peer=%lld topic=%d max=%d",
                  strongSelf->_ios6TopicConversation.conversationId, strongSelf->_ios6TopicId, readMaxId);
        }
        error:^(id error)
        {
            TGIOS6ForumTopicConversationCompanion *strongSelf = TGIOS6ResolveForumTopicConversationCompanion(reference);
            if (strongSelf == nil || strongSelf->_ios6TopicReadGeneration != generation)
                return;

            if (strongSelf->_ios6TopicRequestedReadMaxId == readMaxId)
                strongSelf->_ios6TopicRequestedReadMaxId = strongSelf->_ios6TopicLastReadMaxId;

            NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
            NSLog(@"FORUM thread.read.error peer=%lld topic=%d max=%d error=%@",
                  strongSelf->_ios6TopicConversation.conversationId, strongSelf->_ios6TopicId, readMaxId, errorType);
        }
        completed:nil];
}

- (void)loadInitialState
{
    TGModernConversationController *controller = self.controller;

    [controller setConversationHeader:[self _conversationHeader]];
    self.viewContext.isPublicGroup = _ios6TopicConversation.isChannelGroup && _ios6TopicConversation.username.length != 0;
    self.viewContext.conversation = _ios6TopicConversation;
    [controller setBannedStickers:_ios6TopicConversation.channelBannedRights.banSendStickers];
    [controller setBannedMedia:_ios6TopicConversation.channelBannedRights.banSendMedia];
    [self _updateInputPanel];
    [self _ios6ApplyTopicIdentity];

    [controller setEnableBelowHistoryRequests:false];
    [controller setEnableAboveHistoryRequests:false];
    [controller setLoadingMessages:true];

    NSLog(@"FORUM thread.native.init peer=%lld topic=%d top=%d title=%@",
          _ios6TopicConversation.conversationId, _ios6TopicId,
          _ios6TopicTopMessageId, _ios6TopicTitle);

    [self _ios6ReadDiscussionUpTo:_ios6TopicTopMessageId reason:@"open"];
    [self _ios6LoadRepliesWithOffsetId:0 initial:true];
}

- (NSArray *)_ios6ParsedTopicMessages:(TLmessages_Messages *)result
{
    if ([result.users isKindOfClass:[NSArray class]] && result.users.count != 0)
        [TGUserDataRequestBuilder executeUserDataUpdate:result.users];

    NSMutableArray *messages = [[NSMutableArray alloc] init];
    for (TLMessage *desc in result.messages)
    {
        TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:desc];
        if (message == nil)
            continue;

        NSMutableDictionary *properties = message.contentProperties != nil ? [message.contentProperties mutableCopy] : [[NSMutableDictionary alloc] init];
        properties[@"ios6ForumTopicId"] = [[TGMessageForumTopicContentProperty alloc] initWithTopicId:_ios6TopicId];
        message.contentProperties = properties;
        [messages addObject:message];
    }

    [messages sortUsingComparator:^NSComparisonResult(TGMessage *a, TGMessage *b)
    {
        if (a.date != b.date)
            return a.date > b.date ? NSOrderedAscending : NSOrderedDescending;
        if (a.mid != b.mid)
            return a.mid > b.mid ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    return messages;
}

- (void)_ios6LoadRepliesWithOffsetId:(int32_t)offsetId initial:(bool)initial
{
    if (_ios6TopicId == 0 || _ios6TopicConversation == nil)
        return;

    TLInputPeer *peer = [TGTelegraphInstance createInputPeerForConversation:_ios6TopicConversation.conversationId
                                                                 accessHash:_ios6TopicConversation.accessHash];
    if (peer == nil)
    {
        NSLog(@"FORUM thread.history.invalidPeer peer=%lld topic=%d",
              _ios6TopicConversation.conversationId, _ios6TopicId);
        TGModernConversationController *controller = self.controller;
        TGDispatchOnMainThread(^{
            [controller setLoadingMessages:false];
        });
        return;
    }

    const int32_t pageSize = 64;
    TGIOS6GetRepliesRpc *rpc = [[TGIOS6GetRepliesRpc alloc] init];
    rpc.peer = peer;
    rpc.messageId = _ios6TopicId;
    rpc.offsetId = offsetId;
    rpc.offsetDate = 0;
    rpc.addOffset = 0;
    rpc.limit = pageSize;
    rpc.maxId = 0;
    rpc.minId = 0;
    rpc.hashValue = 0;

    [_ios6TopicHistoryDisposable dispose];
    int generation = ++_ios6TopicHistoryGeneration;
    TGIOS6ForumTopicConversationCompanionReference *reference = _ios6LifetimeReference;
    _ios6TopicHistoryDisposable = [[[[TGTelegramNetworking instance] requestSignal:rpc]
        deliverOn:[SQueue mainQueue]]
        startWithNext:^(TLmessages_Messages *result)
        {
            TGIOS6ForumTopicConversationCompanion *strongSelf = TGIOS6ResolveForumTopicConversationCompanion(reference);
            if (strongSelf == nil || strongSelf->_ios6TopicHistoryGeneration != generation)
                return;

            NSArray *parsedMessages = [strongSelf _ios6ParsedTopicMessages:result];
            NSUInteger serverMessageCount = parsedMessages.count;
            NSMutableArray *messages = [parsedMessages mutableCopy];

            if (initial && strongSelf->_ios6DiscussionThread && strongSelf->_ios6DiscussionRootMessage != nil)
            {
                bool containsRoot = false;
                for (TGMessage *message in messages)
                {
                    if (message.mid == strongSelf->_ios6TopicId)
                    {
                        containsRoot = true;
                        break;
                    }
                }

                if (!containsRoot)
                    [messages addObject:[strongSelf->_ios6DiscussionRootMessage copy]];

                [messages sortUsingComparator:^NSComparisonResult(TGMessage *a, TGMessage *b)
                {
                    if (a.date != b.date)
                        return a.date > b.date ? NSOrderedAscending : NSOrderedDescending;
                    if (a.mid != b.mid)
                        return a.mid > b.mid ? NSOrderedAscending : NSOrderedDescending;
                    return NSOrderedSame;
                }];
            }

            bool hasMore = serverMessageCount >= (NSUInteger)pageSize;

            [TGModernConversationCompanion dispatchOnMessageQueue:^{
                if (initial)
                    [strongSelf _replaceMessages:messages];
                else
                    [strongSelf _addMessages:messages animated:false intent:TGModernConversationAddMessageIntentLoadMoreMessagesAbove];

                strongSelf->_ios6TopicHasMoreAbove = hasMore;
                strongSelf->_ios6TopicLoadingAbove = false;

                TGDispatchOnMainThread(^{
                    TGModernConversationController *controller = strongSelf.controller;
                    [controller setLoadingMessages:false];
                    [controller setEnableBelowHistoryRequests:false];
                    [controller setEnableAboveHistoryRequests:hasMore];
                    [strongSelf _ios6ApplyTopicIdentity];
                    [strongSelf scheduleReadHistory];
                });
            }];
        }
        error:^(id error)
        {
            TGIOS6ForumTopicConversationCompanion *strongSelf = TGIOS6ResolveForumTopicConversationCompanion(reference);
            if (strongSelf == nil || strongSelf->_ios6TopicHistoryGeneration != generation)
                return;

            NSLog(@"FORUM thread.history.error peer=%lld topic=%d offset=%d error=%@",
                  strongSelf->_ios6TopicConversation.conversationId,
                  strongSelf->_ios6TopicId, offsetId, error);
            strongSelf->_ios6TopicLoadingAbove = false;
            TGModernConversationController *controller = strongSelf.controller;
            TGDispatchOnMainThread(^{
                [controller setLoadingMessages:false];
                [controller setEnableAboveHistoryRequests:false];
            });
        }
        completed:nil];
}

- (void)loadMoreMessagesAbove
{
    if (_ios6TopicLoadingAbove || !_ios6TopicHasMoreAbove)
        return;

    _ios6TopicLoadingAbove = true;
    [TGModernConversationCompanion dispatchOnMessageQueue:^{
        int32_t oldestMessageId = 0;
        for (TGMessageModernConversationItem *item in _items)
        {
            if (![item isKindOfClass:[TGMessageModernConversationItem class]] || item->_message == nil)
                continue;
            int32_t mid = item->_message.mid;
            if (mid > 0 && (oldestMessageId == 0 || mid < oldestMessageId))
                oldestMessageId = mid;
        }

        TGDispatchOnMainThread(^{
            if (oldestMessageId == 0)
            {
                _ios6TopicLoadingAbove = false;
                _ios6TopicHasMoreAbove = false;
                TGModernConversationController *controller = self.controller;
                [controller setEnableAboveHistoryRequests:false];
            }
            else
            {
                [self _ios6LoadRepliesWithOffsetId:oldestMessageId initial:false];
            }
        });
    }];
}

- (void)loadMoreMessagesBelow
{
}

- (void)unloadMessagesAbove
{
}

- (void)unloadMessagesBelow
{
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
                if (![item isKindOfClass:[TGMessageModernConversationItem class]] || item->_message == nil)
                    continue;
                if (item->_message.mid > 0)
                    maxMessageId = MAX(maxMessageId, item->_message.mid);
            }

            TGDispatchOnMainThread(^
            {
                [self _ios6ReadDiscussionUpTo:maxMessageId reason:@"visible"];
            });
        }];
    });
}

- (void)controllerCanReadHistoryUpdated
{
    [self scheduleReadHistory];
}

- (bool)_ios6MessageBelongsToTopic:(TGMessage *)message
{
    if (message == nil)
        return false;
    if (message.mid == _ios6TopicId)
        return true;

    id topicProperty = message.contentProperties[@"ios6ForumTopicId"];
    int32_t topicId = 0;
    if ([topicProperty isKindOfClass:[TGMessageForumTopicContentProperty class]])
        topicId = ((TGMessageForumTopicContentProperty *)topicProperty).topicId;
    else if ([topicProperty respondsToSelector:@selector(intValue)])
        topicId = [topicProperty intValue];
    if (topicId == _ios6TopicId)
        return true;

    if (_ios6TopicId == 1 && topicId == 0)
        return true;

    return false;
}

- (NSArray *)_ios6FilterMessages:(NSArray *)messages
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (TGMessage *message in messages)
    {
        if ([self _ios6MessageBelongsToTopic:message])
            [result addObject:message];
    }
    return result;
}

- (void)actionStageResourceDispatched:(NSString *)path resource:(id)resource arguments:(id)arguments
{
    NSString *messagesPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/messages", _conversationId];
    NSString *importantPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/importantMessages", _conversationId];
    NSString *unimportantPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/unimportantMessages", _conversationId];
    NSString *conversationPath = [[NSString alloc] initWithFormat:@"/tg/conversation/(%lld)/conversation", _conversationId];

    if ([path isEqualToString:messagesPath])
    {
        id object = [resource isKindOfClass:[SGraphObjectNode class]] ? ((SGraphObjectNode *)resource).object : resource;
        if ([object isKindOfClass:[NSArray class]])
        {
            NSArray *filtered = [self _ios6FilterMessages:object];
            if (filtered.count == 0)
                return;
            NSLog(@"FORUM thread.live peer=%lld topic=%d in=%d out=%d",
                  _conversationId, _ios6TopicId, (int)[(NSArray *)object count], (int)filtered.count);
            [super actionStageResourceDispatched:path
                                        resource:[[SGraphObjectNode alloc] initWithObject:filtered]
                                       arguments:arguments];
            [self scheduleReadHistory];
            return;
        }
    }
    else if ([path isEqualToString:importantPath] || [path isEqualToString:unimportantPath])
    {
        id object = [resource isKindOfClass:[SGraphObjectNode class]] ? ((SGraphObjectNode *)resource).object : resource;
        if ([object isKindOfClass:[NSDictionary class]])
        {
            NSArray *added = object[@"added"];
            NSArray *filtered = [added isKindOfClass:[NSArray class]] ? [self _ios6FilterMessages:added] : @[];
            if (filtered.count != 0)
            {
                NSLog(@"FORUM thread.live.channel peer=%lld topic=%d in=%d out=%d",
                      _conversationId, _ios6TopicId, (int)added.count, (int)filtered.count);
                [super actionStageResourceDispatched:messagesPath
                                            resource:[[SGraphObjectNode alloc] initWithObject:filtered]
                                           arguments:@{ @"treatIncomingAsUnread": @true }];
                [self scheduleReadHistory];
            }
        }
        return;
    }

    [super actionStageResourceDispatched:path resource:resource arguments:arguments];

    if ([path isEqualToString:conversationPath])
    {
        TGDispatchOnMainThread(^{
            [self _ios6ApplyTopicIdentity];
        });
    }
}

- (void)_setupOutgoingMessage:(TGMessage *)message
{
    [super _setupOutgoingMessage:message];
    NSMutableDictionary *properties = message.contentProperties != nil ? [message.contentProperties mutableCopy] : [[NSMutableDictionary alloc] init];
    properties[@"ios6ForumTopicId"] = [[TGMessageForumTopicContentProperty alloc] initWithTopicId:_ios6TopicId];
    message.contentProperties = properties;

    if (_ios6TopicId != 1 && message.mediaAttachments.count != 0)
    {
        NSMutableArray *filteredAttachments = [[NSMutableArray alloc] init];
        for (id attachment in message.mediaAttachments)
        {
            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]] &&
                ((TGReplyMessageMediaAttachment *)attachment).replyMessageId == _ios6TopicId)
                continue;
            [filteredAttachments addObject:attachment];
        }
        message.mediaAttachments = filteredAttachments;
    }
}

- (int32_t)_ios6EffectiveReplyMessageId:(int32_t)replyMessageId
{
    if (replyMessageId != 0)
        return replyMessageId;
    return _ios6TopicId == 1 ? 0 : _ios6TopicId;
}

- (NSArray *)_createPreparedMessagesFromFiles:(NSArray *)files asReplyToMessageId:(int32_t)replyMessageId
{
    return [super _createPreparedMessagesFromFiles:files asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId]];
}

- (NSArray *)_createPreparedForwardMessagesFromMessages:(NSArray *)messages
{
    NSArray *prepared = [super _createPreparedForwardMessagesFromMessages:messages];
    int32_t topMessageId = [self _ios6EffectiveReplyMessageId:0];
    if (topMessageId == 0)
        return prepared;

    TGMessage *topicRoot = [TGDatabaseInstance() loadMessageWithMid:topMessageId peerId:_conversationId];
    if (topicRoot == nil)
    {
        topicRoot = [[TGMessage alloc] init];
        topicRoot.mid = topMessageId;
        topicRoot.cid = _conversationId;
    }

    for (id item in prepared)
    {
        if ([item isKindOfClass:[TGPreparedForwardedMessage class]])
            ((TGPreparedForwardedMessage *)item).replyMessage = topicRoot;
    }
    return prepared;
}

- (void)controllerWantsToSendTextMessage:(NSString *)text entities:(NSArray *)entities asReplyToMessageId:(int32_t)replyMessageId withAttachedMessages:(NSArray *)withAttachedMessages completeGroups:(NSSet *)completeGroups disableLinkPreviews:(bool)disableLinkPreviews botContextResult:(TGBotContextResultAttachment *)botContextResult botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    int32_t effectiveReply = [self _ios6EffectiveReplyMessageId:replyMessageId];
    NSLog(@"FORUM thread.send.text peer=%lld topic=%d reply=%d effective=%d", _conversationId, _ios6TopicId, replyMessageId, effectiveReply);
    NSSet *effectiveCompleteGroups = effectiveReply != 0 ? nil : completeGroups;
    [super controllerWantsToSendTextMessage:text entities:entities asReplyToMessageId:effectiveReply withAttachedMessages:withAttachedMessages completeGroups:effectiveCompleteGroups disableLinkPreviews:disableLinkPreviews botContextResult:botContextResult botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendMapWithLatitude:(double)latitude longitude:(double)longitude venue:(TGVenueAttachment *)venue period:(int32_t)period asReplyToMessageId:(int32_t)replyMessageId botContextResult:(TGBotContextResultAttachment *)botContextResult botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendMapWithLatitude:latitude longitude:longitude venue:venue period:period asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] botContextResult:botContextResult botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendImagesWithDescriptions:(NSArray *)imageDescriptions asReplyToMessageId:(int32_t)replyMessageId botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendImagesWithDescriptions:imageDescriptions asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendLocalVideoWithTempFilePath:(NSString *)tempVideoFilePath fileSize:(int32_t)fileSize previewImage:(UIImage *)previewImage duration:(NSTimeInterval)duration dimensions:(CGSize)dimensions caption:(NSString *)caption entities:(NSArray *)entities assetUrl:(NSString *)assetUrl liveUploadData:(TGLiveUploadActorData *)liveUploadData asReplyToMessageId:(int32_t)replyMessageId botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendLocalVideoWithTempFilePath:tempVideoFilePath fileSize:fileSize previewImage:previewImage duration:duration dimensions:dimensions caption:caption entities:entities assetUrl:assetUrl liveUploadData:liveUploadData asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendDocumentWithTempFileUrl:(NSURL *)tempFileUrl fileName:(NSString *)fileName mimeType:(NSString *)mimeType asReplyToMessageId:(int32_t)replyMessageId
{
    [super controllerWantsToSendDocumentWithTempFileUrl:tempFileUrl fileName:fileName mimeType:mimeType asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId]];
}

- (void)controllerWantsToSendDocumentsWithDescriptions:(NSArray *)descriptions asReplyToMessageId:(int32_t)replyMessageId
{
    [super controllerWantsToSendDocumentsWithDescriptions:descriptions asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId]];
}

- (void)controllerWantsToSendRemoteDocument:(TGDocumentMediaAttachment *)document asReplyToMessageId:(int32_t)replyMessageId text:(NSString *)text entities:(NSArray *)entities botContextResult:(TGBotContextResultAttachment *)botContextResult botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendRemoteDocument:document asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] text:text entities:entities botContextResult:botContextResult botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendRemoteImage:(TGImageMediaAttachment *)image text:(NSString *)text entities:(NSArray *)entities asReplyToMessageId:(int32_t)replyMessageId botContextResult:(TGBotContextResultAttachment *)botContextResult botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendRemoteImage:image text:text entities:entities asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] botContextResult:botContextResult botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendCloudDocumentsWithDescriptions:(NSArray *)descriptions asReplyToMessageId:(int32_t)replyMessageId
{
    [super controllerWantsToSendCloudDocumentsWithDescriptions:descriptions asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId]];
}

- (void)controllerWantsToSendLocalAudioWithDataItem:(TGDataItem *)dataItem duration:(NSTimeInterval)duration liveData:(TGLiveUploadActorData *)liveData waveform:(TGAudioWaveform *)waveform asReplyToMessageId:(int32_t)replyMessageId botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendLocalAudioWithDataItem:dataItem duration:duration liveData:liveData waveform:waveform asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendRemoteVideoWithMedia:(TGVideoMediaAttachment *)media asReplyToMessageId:(int32_t)replyMessageId text:(NSString *)text entities:(NSArray *)entities botContextResult:(TGBotContextResultAttachment *)botContextResult botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendRemoteVideoWithMedia:media asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] text:text entities:entities botContextResult:botContextResult botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendContact:(TGUser *)contactUser asReplyToMessageId:(int32_t)replyMessageId botContextResult:(TGBotContextResultAttachment *)botContextResult botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendContact:contactUser asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] botContextResult:botContextResult botReplyMarkup:botReplyMarkup];
}

- (void)controllerWantsToSendGame:(TGGameMediaAttachment *)gameMedia asReplyToMessageId:(int32_t)replyMessageId botContextResult:(TGBotContextResultAttachment *)botContextResult botReplyMarkup:(TGBotReplyMarkup *)botReplyMarkup
{
    [super controllerWantsToSendGame:gameMedia asReplyToMessageId:[self _ios6EffectiveReplyMessageId:replyMessageId] botContextResult:botContextResult botReplyMarkup:botReplyMarkup];
}

@end

static int32_t TGIOS6ForumTopicInt(id topic, NSString *key)
{
    id value = nil;
    @try { value = [topic valueForKey:key]; } @catch (__unused NSException *exception) { }
    return [value intValue];
}

static int64_t TGIOS6ForumTopicLong(id topic, NSString *key)
{
    id value = nil;
    @try { value = [topic valueForKey:key]; } @catch (__unused NSException *exception) { }
    return [value longLongValue];
}

static NSString *TGIOS6ForumTopicString(id topic, NSString *key)
{
    id value = nil;
    @try { value = [topic valueForKey:key]; } @catch (__unused NSException *exception) { }
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static UIColor *TGIOS6ForumTopicColor(int32_t rgb)
{
    if (rgb == 0)
        rgb = 0x6FB9F0;
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f
                           green:((rgb >> 8) & 0xff) / 255.0f
                            blue:(rgb & 0xff) / 255.0f
                           alpha:1.0f];
}

static UIImage *TGIOS6ForumDefaultTopicIcon(int32_t rgb)
{
    if (rgb == 0)
        rgb = 0x6FB9F0;

    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });

    NSNumber *cacheKey = @(rgb);
    UIImage *cachedImage = [cache objectForKey:cacheKey];
    if (cachedImage != nil)
        return cachedImage;

    CGSize size = CGSizeMake(40.0f, 40.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIColor *color = TGIOS6ForumTopicColor(rgb);
    CGContextSetFillColorWithColor(context, color.CGColor);

    CGRect bubble = CGRectMake(4.0f, 5.0f, 32.0f, 27.0f);
    UIBezierPath *bubblePath = [UIBezierPath bezierPathWithRoundedRect:bubble cornerRadius:13.5f];
    [bubblePath fill];

    UIBezierPath *tail = [UIBezierPath bezierPath];
    [tail moveToPoint:CGPointMake(11.0f, 28.0f)];
    [tail addLineToPoint:CGPointMake(7.0f, 36.0f)];
    [tail addLineToPoint:CGPointMake(18.0f, 31.0f)];
    [tail closePath];
    [tail fill];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (image != nil)
        [cache setObject:image forKey:cacheKey];
    return image;
}

@interface TGIOS6ForumTopicCell : UITableViewCell
{
    TGImageView *_topicIconView;
    UIImageView *_unreadBadgeView;
    UILabel *_unreadBadgeLabel;
    UIImageView *_mentionBadgeView;
    UILabel *_dateLabel;
}
@property (nonatomic, strong, readonly) TGImageView *topicIconView;
- (void)setTopicIconDocument:(TGDocumentMediaAttachment *)document fallbackColor:(int32_t)color;
- (void)setUnreadCount:(int32_t)unreadCount unreadMentionCount:(int32_t)unreadMentionCount presentation:(TGPresentation *)presentation;
- (void)setDate:(NSTimeInterval)date presentation:(TGPresentation *)presentation;
@end

@implementation TGIOS6ForumTopicCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        _topicIconView = [[TGImageView alloc] initWithFrame:CGRectMake(11.0f, 11.0f, 40.0f, 40.0f)];
        _topicIconView.contentMode = UIViewContentModeScaleAspectFit;
        _topicIconView.clipsToBounds = NO;
        [self.contentView addSubview:_topicIconView];

        _unreadBadgeView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _unreadBadgeView.hidden = YES;
        [self.contentView addSubview:_unreadBadgeView];

        _unreadBadgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _unreadBadgeLabel.backgroundColor = [UIColor clearColor];
        _unreadBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _unreadBadgeLabel.font = [UIFont systemFontOfSize:14.0f];
        _unreadBadgeLabel.hidden = YES;
        [self.contentView addSubview:_unreadBadgeLabel];

        _mentionBadgeView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _mentionBadgeView.hidden = YES;
        [self.contentView addSubview:_mentionBadgeView];

        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.backgroundColor = [UIColor clearColor];
        _dateLabel.textAlignment = NSTextAlignmentRight;
        _dateLabel.font = [UIFont systemFontOfSize:13.0f];
        _dateLabel.hidden = YES;
        [self.contentView addSubview:_dateLabel];
    }
    return self;
}

- (TGImageView *)topicIconView
{
    return _topicIconView;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_topicIconView reset];
    _topicIconView.image = nil;
    _unreadBadgeView.hidden = YES;
    _unreadBadgeLabel.hidden = YES;
    _unreadBadgeLabel.text = nil;
    _mentionBadgeView.hidden = YES;
    _dateLabel.hidden = YES;
    _dateLabel.text = nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    _topicIconView.frame = CGRectMake(11.0f, 11.0f, 40.0f, 40.0f);

    CGFloat left = 63.0f;
    CGFloat right = 11.0f;
    CGFloat cellRight = self.bounds.size.width - right;

    CGFloat titleRight = cellRight;
    if (!_dateLabel.hidden && _dateLabel.text.length != 0)
    {
        CGSize dateSize = [_dateLabel.text sizeWithFont:_dateLabel.font];
        CGFloat dateWidth = ceilf(dateSize.width);
        _dateLabel.frame = CGRectMake(cellRight - dateWidth, 7.0f, dateWidth, 20.0f);
        titleRight = _dateLabel.frame.origin.x - 6.0f;
    }
    else
    {
        _dateLabel.frame = CGRectZero;
    }

    CGFloat badgeRight = cellRight;
    const CGFloat badgeY = 34.0f;

    if (!_unreadBadgeView.hidden)
    {
        CGFloat countTextWidth = [_unreadBadgeLabel.text sizeWithFont:_unreadBadgeLabel.font].width;
        CGFloat badgeWidth = MAX(20.0f, ceilf(countTextWidth) + 11.0f);
        _unreadBadgeView.frame = CGRectMake(badgeRight - badgeWidth, badgeY, badgeWidth, 20.0f);
        _unreadBadgeLabel.frame = CGRectMake(_unreadBadgeView.frame.origin.x, badgeY + 1.0f, badgeWidth, 18.0f);
        badgeRight = _unreadBadgeView.frame.origin.x - 6.0f;
    }

    if (!_mentionBadgeView.hidden)
    {
        _mentionBadgeView.frame = CGRectMake(badgeRight - 20.0f, badgeY, 20.0f, 20.0f);
        badgeRight = _mentionBadgeView.frame.origin.x - 6.0f;
    }

    CGFloat titleWidth = MAX(10.0f, titleRight - left);
    CGFloat previewWidth = MAX(10.0f, badgeRight - left);
    self.textLabel.frame = CGRectMake(left, 7.0f, titleWidth, 23.0f);
    self.detailTextLabel.frame = CGRectMake(left, 30.0f, previewWidth, 24.0f);
}

- (void)setUnreadCount:(int32_t)unreadCount unreadMentionCount:(int32_t)unreadMentionCount presentation:(TGPresentation *)presentation
{
    if (presentation == nil)
        presentation = [TGPresentation current];

    if (unreadCount > 0)
    {
        NSString *text = nil;
        if (TGIsLocaleArabic())
            text = [TGStringUtils stringWithLocalizedNumberCharacters:[NSString stringWithFormat:@"%d", unreadCount]];
        else if (unreadCount < 1000)
            text = [NSString stringWithFormat:@"%d", unreadCount];
        else
            text = [NSString stringWithFormat:@"%dK", unreadCount / 1000];

        _unreadBadgeLabel.text = text;
        [_unreadBadgeLabel sizeToFit];
        _unreadBadgeLabel.textColor = presentation.pallete.dialogBadgeTextColor;
        _unreadBadgeView.image = presentation.images.dialogBadgeImage;
        _unreadBadgeView.hidden = NO;
        _unreadBadgeLabel.hidden = NO;
    }
    else
    {
        _unreadBadgeView.hidden = YES;
        _unreadBadgeLabel.hidden = YES;
        _unreadBadgeLabel.text = nil;
    }

    if (unreadMentionCount > 0)
    {
        _mentionBadgeView.image = presentation.images.dialogMentionedIcon;
        _mentionBadgeView.hidden = NO;
    }
    else
    {
        _mentionBadgeView.hidden = YES;
    }

    [self setNeedsLayout];
}


- (void)setDate:(NSTimeInterval)date presentation:(TGPresentation *)presentation
{
    if (presentation == nil)
        presentation = [TGPresentation current];

    if (date > 0.0)
    {
        _dateLabel.text = [TGDateUtils stringForMessageListDate:(int)date];
        _dateLabel.textColor = presentation.pallete.secondaryTextColor;
        _dateLabel.hidden = NO;
    }
    else
    {
        _dateLabel.text = nil;
        _dateLabel.hidden = YES;
    }

    [self setNeedsLayout];
}

- (void)setTopicIconDocument:(TGDocumentMediaAttachment *)document fallbackColor:(int32_t)color
{
    [_topicIconView reset];
    _topicIconView.image = TGIOS6ForumDefaultTopicIcon(color);

    if (document == nil)
        return;

    NSString *thumbnailUri = [document.thumbnailInfo imageUrlForLargestSize:NULL];
    if (thumbnailUri.length == 0)
        return;

    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
    [uri appendFormat:@"documentId=%lld", (long long)document.documentId];

    TGMediaOriginInfo *originInfo = document.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:document];
    if (originInfo != nil)
        [uri appendFormat:@"&origin_info=%@", [TGStringUtils stringByEscapingForURL:[originInfo stringRepresentation]]];

    [uri appendFormat:@"&accessHash=%lld", (long long)document.accessHash];
    [uri appendFormat:@"&datacenterId=%d", (int)document.datacenterId];
    [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:thumbnailUri]];
    [uri appendString:@"&width=80&height=80&highQuality=0"];

    [_topicIconView loadUri:uri withOptions:@{ TGImageViewOptionKeepCurrentImageAsPlaceholder: @YES }];
}

@end

@class TGIOS6ForumTopicThreadController;

@interface TGIOS6ForumTopicThreadControllerReference : NSObject
@property (nonatomic, weak) TGIOS6ForumTopicThreadController *value;
@end

@implementation TGIOS6ForumTopicThreadControllerReference
@end

@interface TGIOS6ForumTopicThreadController : TGViewController <UITableViewDelegate, UITableViewDataSource>
{
    TGConversation *_conversation;
    id _topic;
    UITableView *_tableView;
    NSArray *_messages;
    UILabel *_placeholderLabel;
    id<SDisposable> _requestDisposable;
    TGIOS6ForumTopicThreadControllerReference *_lifetimeReference;
}
- (instancetype)initWithConversation:(TGConversation *)conversation topic:(id)topic;
@end

@implementation TGIOS6ForumTopicThreadController

- (instancetype)initWithConversation:(TGConversation *)conversation topic:(id)topic
{
    self = [super init];
    if (self != nil)
    {
        _conversation = conversation;
        _topic = topic;
        _messages = @[];
        _lifetimeReference = [[TGIOS6ForumTopicThreadControllerReference alloc] init];
        _lifetimeReference.value = self;
        self.title = TGIOS6ForumTopicString(topic, @"title");
    }
    return self;
}

- (void)dealloc
{
    @synchronized(_lifetimeReference)
    {
        _lifetimeReference.value = nil;
    }
    [_requestDisposable dispose];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (iosMajorVersion() <= 4 && self.navigationController != nil && ![self.navigationController.viewControllers containsObject:self])
    {
        @synchronized(_lifetimeReference)
        {
            _lifetimeReference.value = nil;
        }
        [_requestDisposable dispose];
    }
    [super viewWillDisappear:animated];
}

- (void)loadView
{
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:_tableView];

    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 90.0f, self.view.bounds.size.width - 40.0f, 60.0f)];
    _placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _placeholderLabel.backgroundColor = [UIColor clearColor];
    _placeholderLabel.textAlignment = NSTextAlignmentCenter;
    _placeholderLabel.textColor = [UIColor grayColor];
    _placeholderLabel.font = [UIFont systemFontOfSize:14.0f];
    _placeholderLabel.numberOfLines = 2;
    _placeholderLabel.text = @"Загрузка сообщений…";
    [self.view addSubview:_placeholderLabel];

    [self _loadMessages];
}

- (void)_loadMessages
{
    TGIOS6GetRepliesRpc *rpc = [[TGIOS6GetRepliesRpc alloc] init];
    rpc.peer = [TGTelegraphInstance createInputPeerForConversation:_conversation.conversationId accessHash:_conversation.accessHash];
    rpc.messageId = TGIOS6ForumTopicInt(_topic, @"topicId");
    rpc.offsetId = 0;
    rpc.offsetDate = 0;
    rpc.addOffset = 0;
    rpc.limit = 100;
    rpc.maxId = 0;
    rpc.minId = 0;
    rpc.hashValue = 0;

    TGIOS6ForumTopicThreadControllerReference *lifetimeReference = _lifetimeReference;
    _requestDisposable = [[[[TGTelegramNetworking instance] requestSignal:rpc] deliverOn:[SQueue mainQueue]] startWithNext:^(TLmessages_Messages *result) {
        TGIOS6ForumTopicThreadController *strongSelf = nil;
        @synchronized(lifetimeReference)
        {
            strongSelf = lifetimeReference.value;
        }
        if (strongSelf == nil)
            return;

        NSMutableArray *messages = [[NSMutableArray alloc] init];
        for (TLMessage *desc in result.messages)
        {
            TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:desc];
            if (message != nil)
                [messages addObject:message];
        }
        [messages sortUsingComparator:^NSComparisonResult(TGMessage *a, TGMessage *b) {
            if (a.date < b.date) return NSOrderedAscending;
            if (a.date > b.date) return NSOrderedDescending;
            if (a.mid < b.mid) return NSOrderedAscending;
            if (a.mid > b.mid) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        strongSelf->_messages = messages;
        strongSelf->_placeholderLabel.hidden = messages.count != 0;
        if (messages.count == 0)
            strongSelf->_placeholderLabel.text = @"В этом топике пока нет сообщений";
        [strongSelf->_tableView reloadData];
    } error:^(__unused id error) {
        TGIOS6ForumTopicThreadController *strongSelf = nil;
        @synchronized(lifetimeReference)
        {
            strongSelf = lifetimeReference.value;
        }
        if (strongSelf != nil)
            strongSelf->_placeholderLabel.text = @"Не удалось загрузить топик";
    } completed:nil];
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return _messages.count;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return 64.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"TGIOS6ForumMessageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

    TGMessage *message = _messages[indexPath.row];
    NSString *text = message.text;
    if (text.length == 0)
        text = @"Служебное сообщение";
    cell.textLabel.text = text;
    cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
    cell.textLabel.numberOfLines = 2;

    TGUser *user = message.fromUid > 0 ? [TGDatabaseInstance() loadUser:(int32_t)message.fromUid] : nil;
    NSString *name = nil;
    if (user != nil)
        name = user.displayName;
    if (name.length == 0)
        name = message.outgoing ? @"Вы" : @"";

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:message.date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm";
    NSString *time = [formatter stringFromDate:date];
    cell.detailTextLabel.text = name.length == 0 ? time : [NSString stringWithFormat:@"%@ · %@", name, time];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

@end

@class TGIOS6ForumTopicsController;

@interface TGIOS6ForumTopicsControllerReference : NSObject
@property (nonatomic, weak) TGIOS6ForumTopicsController *value;
@end

@implementation TGIOS6ForumTopicsControllerReference
@end

static TGIOS6ForumTopicsController *TGIOS6ResolveForumTopicsController(TGIOS6ForumTopicsControllerReference *reference)
{
    TGIOS6ForumTopicsController *result = nil;
    @synchronized (reference)
    {
        result = reference.value;
    }
    return result;
}

@interface TGIOS6ForumTopicsController : TGViewController <UITableViewDelegate, UITableViewDataSource>
{
    TGConversation *_conversation;
    UITableView *_tableView;
    NSArray *_topics;
    UILabel *_placeholderLabel;
    id<SDisposable> _requestDisposable;
    id<SDisposable> _iconRequestDisposable;
    NSMutableDictionary *_iconDocumentsById;
    NSMutableDictionary *_topMessagesById;
    NSMutableDictionary *_optimisticallyReadTopicMaxIds;
    id<SDisposable> _presentationDisposable;
    NSDictionary *_pendingActions;
    TGIOS6ForumTopicsControllerReference *_ios4LifetimeReference;
    int _ios4TopicsRequestGeneration;
    int _ios4IconRequestGeneration;
}
- (instancetype)initWithConversation:(TGConversation *)conversation;
- (instancetype)initWithConversation:(TGConversation *)conversation pendingActions:(NSDictionary *)pendingActions;
- (void)_applyPresentation:(TGPresentation *)presentation;
@end

@implementation TGIOS6ForumTopicsController

- (instancetype)initWithConversation:(TGConversation *)conversation
{
    return [self initWithConversation:conversation pendingActions:nil];
}

- (instancetype)initWithConversation:(TGConversation *)conversation pendingActions:(NSDictionary *)pendingActions
{
    self = [super init];
    if (self != nil)
    {
        _conversation = conversation;
        _pendingActions = [pendingActions copy];
        _topics = @[];
        _iconDocumentsById = [[NSMutableDictionary alloc] init];
        _topMessagesById = [[NSMutableDictionary alloc] init];
        _optimisticallyReadTopicMaxIds = [[NSMutableDictionary alloc] init];
        _ios4LifetimeReference = [[TGIOS6ForumTopicsControllerReference alloc] init];
        _ios4LifetimeReference.value = self;
        self.title = conversation.chatTitle.length == 0 ? @"Топики" : conversation.chatTitle;

        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Назад" style:UIBarButtonItemStylePlain target:nil action:nil];

        TGIOS6ForumTopicsControllerReference *reference = _ios4LifetimeReference;
        _presentationDisposable = [[TGPresentation signal] startWithNext:^(TGPresentation *presentation)
        {
            TGIOS6ForumTopicsController *strongSelf = TGIOS6ResolveForumTopicsController(reference);
            if (strongSelf != nil)
                [strongSelf _applyPresentation:presentation];
        }];
    }
    return self;
}

- (void)dealloc
{
    @synchronized (_ios4LifetimeReference)
    {
        _ios4LifetimeReference.value = nil;
    }
    _ios4TopicsRequestGeneration++;
    _ios4IconRequestGeneration++;
    [_requestDisposable dispose];
    [_iconRequestDisposable dispose];
    [_presentationDisposable dispose];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (iosMajorVersion() <= 4 && self.navigationController != nil && ![self.navigationController.viewControllers containsObject:self])
    {
        @synchronized (_ios4LifetimeReference)
        {
            _ios4LifetimeReference.value = nil;
        }
        _ios4TopicsRequestGeneration++;
        _ios4IconRequestGeneration++;
        [_requestDisposable dispose];
        [_iconRequestDisposable dispose];
        [_presentationDisposable dispose];
    }
    [super viewWillDisappear:animated];
}

- (void)loadView
{
    [super loadView];

    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.tableFooterView = [[UIView alloc] init];
    [self.view addSubview:_tableView];

    _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 90.0f, self.view.bounds.size.width - 40.0f, 60.0f)];
    _placeholderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _placeholderLabel.backgroundColor = [UIColor clearColor];
    _placeholderLabel.textAlignment = NSTextAlignmentCenter;
    _placeholderLabel.textColor = [UIColor grayColor];
    _placeholderLabel.font = [UIFont systemFontOfSize:14.0f];
    _placeholderLabel.numberOfLines = 2;
    _placeholderLabel.text = @"Загрузка топиков…";
    [self.view addSubview:_placeholderLabel];

    [self _applyPresentation:[TGPresentation current]];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];

}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [self _loadTopics];
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    [super controllerInsetUpdated:previousInset];

    if (_tableView == nil)
        return;

    CGPoint contentOffset = _tableView.contentOffset;
    UIEdgeInsets inset = self.controllerInset;
    _tableView.contentInset = inset;
    _tableView.scrollIndicatorInsets = self.controllerScrollInset;

    if (!UIEdgeInsetsEqualToEdgeInsets(previousInset, UIEdgeInsetsZero))
    {
        contentOffset.y += previousInset.top - inset.top;
        if (contentOffset.y < -inset.top)
            contentOffset.y = -inset.top;
    }
    else
    {
        contentOffset.y = -inset.top;
    }

    [_tableView setContentOffset:contentOffset animated:false];
}

- (void)_applyPresentation:(TGPresentation *)presentation
{
    if (presentation == nil || _tableView == nil)
        return;

    TGPresentationPallete *pallete = presentation.pallete;
    self.view.backgroundColor = pallete.backgroundColor;
    _tableView.backgroundColor = pallete.backgroundColor;
    _tableView.separatorColor = pallete.separatorColor;
    _placeholderLabel.textColor = pallete.secondaryTextColor;

    [_tableView reloadData];
}

- (void)_loadTopics
{
    [_requestDisposable dispose];
    int requestGeneration = ++_ios4TopicsRequestGeneration;

    if ((_conversation.flags & TGConversationFlagForumKnown) == 0 ||
        (_conversation.flags & TGConversationFlagIsForum) == 0)
    {
        NSLog(@"FORUM topics.skipNonForum peer=%lld known=%d forum=%d flags=0x%llx",
              _conversation.conversationId,
              (_conversation.flags & TGConversationFlagForumKnown) != 0 ? 1 : 0,
              (_conversation.flags & TGConversationFlagIsForum) != 0 ? 1 : 0,
              _conversation.flags);
        [[TGInterfaceManager instance]
            navigateToConversationWithId:_conversation.conversationId
            conversation:_conversation
            performActions:@{ @"ios6SkipForumTopics": @YES }
            animated:false];
        return;
    }

    TLInputPeer *peer = [TGTelegraphInstance createInputPeerForConversation:_conversation.conversationId accessHash:_conversation.accessHash];
    if (![peer isKindOfClass:[TLInputPeer$inputPeerChannel class]])
    {
        NSLog(@"FORUM topics.invalidPeer peer=%lld class=%@", _conversation.conversationId, NSStringFromClass([peer class]));
        _placeholderLabel.text = @"Не удалось определить канал";
        return;
    }

    TLInputPeer$inputPeerChannel *peerChannel = (TLInputPeer$inputPeerChannel *)peer;
    TLInputChannel$inputChannel *channel = [[TLInputChannel$inputChannel alloc] init];
    channel.channel_id = peerChannel.channel_id;
    channel.access_hash = peerChannel.access_hash;

    TGIOS6GetForumTopicsRpc *rpc = [[TGIOS6GetForumTopicsRpc alloc] init];
    rpc.flags = 0;
    rpc.channel = channel;
    rpc.offsetDate = 0;
    rpc.offsetId = 0;
    rpc.offsetTopic = 0;
    rpc.limit = 100;

    NSLog(@"FORUM topics.request peer=%lld channel=%lld hash=%lld", _conversation.conversationId, channel.channel_id, channel.access_hash);

    TGIOS6ForumTopicsControllerReference *reference = _ios4LifetimeReference;
    _requestDisposable = [[[[TGTelegramNetworking instance] requestSignal:rpc] deliverOn:[SQueue mainQueue]] startWithNext:^(id result) {
        TGIOS6ForumTopicsController *strongSelf = TGIOS6ResolveForumTopicsController(reference);
        if (strongSelf == nil || strongSelf->_ios4TopicsRequestGeneration != requestGeneration)
            return;

        NSArray *topics = nil;
        @try { topics = [result valueForKey:@"ios6_forumTopics"]; } @catch (__unused NSException *exception) { }
        if (![topics isKindOfClass:[NSArray class]])
            topics = @[];

        NSMutableArray *visibleTopics = [[NSMutableArray alloc] init];
        for (id topic in topics)
        {
            bool deleted = TGIOS6ForumTopicInt(topic, @"deleted") != 0;
            int32_t flags = TGIOS6ForumTopicInt(topic, @"flags");
            bool hidden = (flags & (1 << 6)) != 0;
            if (!deleted && !hidden)
                [visibleTopics addObject:topic];
        }

        for (id topic in visibleTopics)
        {
            int32_t topicId = TGIOS6ForumTopicInt(topic, @"topicId");
            NSNumber *localReadMax = [strongSelf->_optimisticallyReadTopicMaxIds objectForKey:@(topicId)];
            if (localReadMax == nil)
                continue;

            int32_t localMax = [localReadMax intValue];
            int32_t serverReadMax = TGIOS6ForumTopicInt(topic, @"readInboxMaxId");
            int32_t topMessage = TGIOS6ForumTopicInt(topic, @"topMessage");
            if (serverReadMax >= localMax)
            {
                [strongSelf->_optimisticallyReadTopicMaxIds removeObjectForKey:@(topicId)];
            }
            else if (topMessage <= localMax)
            {
                @try
                {
                    [topic setValue:@0 forKey:@"unreadCount"];
                    [topic setValue:@0 forKey:@"unreadMentionsCount"];
                    [topic setValue:@(localMax) forKey:@"readInboxMaxId"];
                }
                @catch (__unused NSException *exception)
                {
                }
            }
        }

        NSMutableDictionary *topMessagesById = [[NSMutableDictionary alloc] init];
        NSArray *messageDescriptions = nil;
        @try { messageDescriptions = [result valueForKey:@"messages"]; } @catch (__unused NSException *exception) { }
        if ([messageDescriptions isKindOfClass:[NSArray class]])
        {
            for (TLMessage *desc in messageDescriptions)
            {
                TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:desc];
                if (message != nil && message.mid != 0)
                    [topMessagesById setObject:message forKey:@(message.mid)];
            }
        }

        strongSelf->_topMessagesById = topMessagesById;
        strongSelf->_topics = visibleTopics;
        strongSelf->_placeholderLabel.hidden = visibleTopics.count != 0;
        if (visibleTopics.count == 0)
            strongSelf->_placeholderLabel.text = @"В этой группе нет доступных топиков";
        [strongSelf->_tableView reloadData];
        [strongSelf->_tableView layoutIfNeeded];
        [strongSelf _loadCustomEmojiIconsForTopics:visibleTopics];
    } error:^(id error) {
        TGIOS6ForumTopicsController *strongSelf = TGIOS6ResolveForumTopicsController(reference);
        if (strongSelf == nil || strongSelf->_ios4TopicsRequestGeneration != requestGeneration)
            return;

        NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
        NSLog(@"FORUM topics.error peer=%lld type=%@", strongSelf->_conversation.conversationId, errorType);

        if ([errorType isEqualToString:@"CHANNEL_FORUM_MISSING"])
        {
            [[TGInterfaceManager instance]
                navigateToConversationWithId:strongSelf->_conversation.conversationId
                conversation:strongSelf->_conversation
                performActions:@{ @"ios6SkipForumTopics": @YES }
                animated:false];
            return;
        }

        strongSelf->_placeholderLabel.text = @"Не удалось загрузить топики";
    } completed:nil];
}

- (void)_loadCustomEmojiIconsForTopics:(NSArray *)topics
{
    NSMutableArray *documentIds = [[NSMutableArray alloc] init];
    NSMutableSet *seenIds = [[NSMutableSet alloc] init];

    for (id topic in topics)
    {
        int64_t iconEmojiId = TGIOS6ForumTopicLong(topic, @"iconEmojiId");
        if (iconEmojiId == 0)
            continue;

        NSNumber *key = @(iconEmojiId);
        if ([_iconDocumentsById objectForKey:key] != nil || [seenIds containsObject:key])
            continue;

        [seenIds addObject:key];
        [documentIds addObject:key];
    }

    [_iconRequestDisposable dispose];
    int requestGeneration = ++_ios4IconRequestGeneration;
    if (documentIds.count == 0)
        return;

    TGIOS6GetCustomEmojiDocumentsRpc *rpc = [[TGIOS6GetCustomEmojiDocumentsRpc alloc] init];
    rpc.documentIds = documentIds;

    TGIOS6ForumTopicsControllerReference *reference = _ios4LifetimeReference;
    _iconRequestDisposable = [[[[TGTelegramNetworking instance] requestSignal:rpc] deliverOn:[SQueue mainQueue]] startWithNext:^(id result) {
        TGIOS6ForumTopicsController *strongSelf = TGIOS6ResolveForumTopicsController(reference);
        if (strongSelf == nil || strongSelf->_ios4IconRequestGeneration != requestGeneration)
            return;

        NSArray *documents = [result isKindOfClass:[NSArray class]] ? result : @[];
        int32_t stored = 0;
        for (id object in documents)
        {
            if (![object isKindOfClass:[TLDocument class]])
                continue;

            TLDocument *document = (TLDocument *)object;
            if (document.n_id == 0)
                continue;

            TGDocumentMediaAttachment *attachment = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:document];
            if (attachment != nil)
            {
                [strongSelf->_iconDocumentsById setObject:attachment forKey:@(document.n_id)];
                stored++;
            }
        }
        [strongSelf->_tableView reloadData];
    } error:^(id error) {
        TGIOS6ForumTopicsController *strongSelf = TGIOS6ResolveForumTopicsController(reference);
        if (strongSelf == nil || strongSelf->_ios4IconRequestGeneration != requestGeneration)
            return;
        NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
        NSLog(@"FORUM icons.error type=%@", errorType);
    } completed:nil];
}

static NSString *TGIOS6ForumCleanPreviewText(NSString *text)
{
    if (text.length == 0)
        return @"";

    NSString *clean = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    clean = [clean stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
    while ([clean rangeOfString:@"  "].location != NSNotFound)
        clean = [clean stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    return [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString *TGIOS6ForumMessagePreview(TGMessage *message)
{
    if (message == nil)
        return @"";

    NSString *body = TGIOS6ForumCleanPreviewText(message.text);
    if (body.length == 0)
    {
        for (id attachment in message.mediaAttachments)
        {
            if ([attachment isKindOfClass:[TGImageMediaAttachment class]])
            {
                body = @"Фотография";
                break;
            }
            else if ([attachment isKindOfClass:[TGVideoMediaAttachment class]])
            {
                body = @"Видео";
                break;
            }
            else if ([attachment isKindOfClass:[TGAudioMediaAttachment class]])
            {
                body = @"Аудио";
                break;
            }
            else if ([attachment isKindOfClass:[TGDocumentMediaAttachment class]])
            {
                TGDocumentMediaAttachment *document = (TGDocumentMediaAttachment *)attachment;
                if ([document isSticker])
                    body = @"Стикер";
                else if ([document isVoice])
                    body = @"Голосовое сообщение";
                else if ([document isRoundVideo])
                    body = @"Видеосообщение";
                else
                    body = @"Файл";
                break;
            }
            else if ([attachment isKindOfClass:[TGLocationMediaAttachment class]])
            {
                body = @"Геопозиция";
                break;
            }
            else if ([attachment isKindOfClass:[TGContactMediaAttachment class]])
            {
                body = @"Контакт";
                break;
            }
        }
    }

    if (body.length == 0)
        body = @"Сообщение";

    NSString *authorName = nil;
    if (message.outgoing)
    {
        authorName = @"Вы";
    }
    else if (message.fromUid > 0)
    {
        TGUser *user = [TGDatabaseInstance() loadUser:(int32_t)message.fromUid];
        if (user != nil)
            authorName = user.displayName;
    }

    if (authorName.length != 0)
        return [NSString stringWithFormat:@"%@: %@", authorName, body];
    return body;
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return _topics.count;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return 62.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"TGIOS6ForumTopicCell";
    TGIOS6ForumTopicCell *cell = (TGIOS6ForumTopicCell *)[tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [[TGIOS6ForumTopicCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];

    id topic = _topics[indexPath.row];
    int32_t iconColor = TGIOS6ForumTopicInt(topic, @"iconColor");
    int64_t iconEmojiId = TGIOS6ForumTopicLong(topic, @"iconEmojiId");

    NSString *title = TGIOS6ForumTopicString(topic, @"title");
    if (title.length == 0)
        title = @"Топик";
    TGPresentationPallete *pallete = [TGPresentation current].pallete;
    cell.backgroundColor = pallete.backgroundColor;
    cell.textLabel.text = title;
    cell.textLabel.textColor = pallete.textColor;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];

    if (cell.selectedBackgroundView == nil)
        cell.selectedBackgroundView = [[UIView alloc] init];
    cell.selectedBackgroundView.backgroundColor = pallete.selectionColor;

    TGDocumentMediaAttachment *iconDocument = iconEmojiId == 0 ? nil : [_iconDocumentsById objectForKey:@(iconEmojiId)];
    [cell setTopicIconDocument:iconDocument fallbackColor:iconColor];

    int32_t topMessageId = TGIOS6ForumTopicInt(topic, @"topMessage");
    TGMessage *topMessage = [_topMessagesById objectForKey:@(topMessageId)];
    NSString *preview = TGIOS6ForumMessagePreview(topMessage);
    if (preview.length == 0)
        preview = @"Нет сообщений";

    cell.detailTextLabel.text = preview;
    cell.detailTextLabel.textColor = pallete.secondaryTextColor;
    cell.detailTextLabel.numberOfLines = 1;
    cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.accessoryType = UITableViewCellAccessoryNone;

    [cell setDate:topMessage == nil ? 0.0 : topMessage.date presentation:[TGPresentation current]];

    int32_t unreadCount = TGIOS6ForumTopicInt(topic, @"unreadCount");
    int32_t unreadMentionCount = TGIOS6ForumTopicInt(topic, @"unreadMentionsCount");
    [cell setUnreadCount:unreadCount unreadMentionCount:unreadMentionCount presentation:[TGPresentation current]];

    [cell setNeedsLayout];
    return cell;
}

- (void)tableView:(UITableView *)__unused tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [_tableView deselectRowAtIndexPath:indexPath animated:true];
    if (indexPath.row >= (NSInteger)_topics.count)
        return;

    id topic = _topics[indexPath.row];
    int32_t topicId = TGIOS6ForumTopicInt(topic, @"topicId");
    int32_t topMessageId = TGIOS6ForumTopicInt(topic, @"topMessage");
    NSString *topicTitle = TGIOS6ForumTopicString(topic, @"title");

    if (topicId != 0 && topMessageId > 0)
    {
        [_optimisticallyReadTopicMaxIds setObject:@(topMessageId) forKey:@(topicId)];
        @try
        {
            [topic setValue:@0 forKey:@"unreadCount"];
            [topic setValue:@0 forKey:@"unreadMentionsCount"];
            [topic setValue:@(topMessageId) forKey:@"readInboxMaxId"];
        }
        @catch (__unused NSException *exception)
        {
        }
        [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }

    if (topicId == 0)
    {
        NSLog(@"FORUM topic.openNative.invalid peer=%lld row=%ld title=%@",
              _conversation.conversationId, (long)indexPath.row, topicTitle);
        return;
    }

    NSLog(@"FORUM topic.openNative peer=%lld topic=%d top=%d title=%@",
          _conversation.conversationId, topicId, topMessageId, topicTitle);

    NSMutableDictionary *actions = _pendingActions != nil ? [_pendingActions mutableCopy] : [[NSMutableDictionary alloc] init];
    [actions removeObjectForKey:@"ios6ForceForumTopicPicker"];
    actions[@"ios6SkipForumTopics"] = @YES;
    actions[@"ios6ForumTopicId"] = @(topicId);
    actions[@"ios6ForumTopicTopMessageId"] = @(topMessageId);
    actions[@"ios6ForumTopicTitle"] = topicTitle != nil ? topicTitle : @"";
    NSDictionary *atMessage = nil;

    if (_pendingActions != nil)
        NSLog(@"FORUM forward.topicSelected peer=%lld topic=%d actions=%@", _conversation.conversationId, topicId, [actions allKeys]);

    TGNavigationController *navigationController = nil;
    if ([self.navigationController isKindOfClass:[TGNavigationController class]])
        navigationController = (TGNavigationController *)self.navigationController;

    [[TGInterfaceManager instance]
        navigateToConversationWithId:_conversation.conversationId
        conversation:_conversation
        performActions:actions
        atMessage:atMessage
        clearStack:false
        openKeyboard:false
        canOpenKeyboardWhileInTransition:false
        navigationController:navigationController
        selectChat:true
        animated:true];
}

@end

@interface TGInterfaceManager ()
{
    TGNotificationController *_notificationController;
    SMetaDisposable *_incomingCallsDisposable;
    
    SPipe *_conversationControllerPipe;
    SPipe *_callControllerPipe;
    
    TGModernConversationController *_feedContr;
}

@property (nonatomic, strong) UIWindow *preloadWindow;

@end

@implementation TGInterfaceManager

@synthesize actionHandle = _actionHandle;

@synthesize preloadWindow = _preloadWindow;

+ (TGInterfaceManager *)instance
{
    static TGInterfaceManager *singleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        singleton = [[TGInterfaceManager alloc] init];
    });
    return singleton;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        _conversationControllerPipe = [[SPipe alloc] init];
        _callControllerPipe = [[SPipe alloc] init];
        
//        TGDispatchAfter(3.0, dispatch_get_main_queue(), ^{
//            TGModernConversationController *conversationController = [[TGModernConversationController alloc] init];
//            conversationController.presentation = TGPresentation.current;
//            
//            TGFeedConversationCompanion *companion = [[TGFeedConversationCompanion alloc] init];
//            conversationController.companion = companion;
//            
//            [conversationController.companion bindController:conversationController];
//            
//            //conversationController.shouldIgnoreAppearAnimationOnce = !animated;
//            _feedContr = conversationController;
//        });
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [ActionStageInstance() removeWatcher:self];
}

- (void)preload
{
}

- (void)navigateToCommentsForChannelConversation:(TGConversation *)conversation
                                      messageId:(int32_t)messageId
                            discussionChannelId:(int64_t)discussionChannelId
                           navigationController:(TGNavigationController *)navigationController
{
    if (conversation == nil || messageId <= 0 || !TGPeerIdIsChannel(conversation.conversationId))
        return;

    TLInputPeer *peer = [TGTelegraphInstance createInputPeerForConversation:conversation.conversationId accessHash:conversation.accessHash];
    if (peer == nil)
    {
        NSLog(@"COMMENTS open.invalidPeer source=%lld mid=%d", conversation.conversationId, messageId);
        return;
    }

    TGIOS6GetDiscussionMessageRpc *rpc = [[TGIOS6GetDiscussionMessageRpc alloc] init];
    rpc.peer = peer;
    rpc.messageId = messageId;

    NSLog(@"COMMENTS open.request source=%lld mid=%d expectedGroup=%lld",
          conversation.conversationId, messageId, discussionChannelId);

    __weak TGInterfaceManager *weakSelf = self;
    [[[[TGTelegramNetworking instance] requestSignal:rpc] deliverOn:[SQueue mainQueue]]
      startWithNext:^(NSDictionary *result)
    {
        __strong TGInterfaceManager *strongSelf = weakSelf;
        if (strongSelf == nil || ![result isKindOfClass:[NSDictionary class]])
            return;

        NSArray *users = [result[@"users"] isKindOfClass:[NSArray class]] ? result[@"users"] : @[];
        if (users.count != 0)
            [TGUserDataRequestBuilder executeUserDataUpdate:users];

        NSMutableArray *conversations = [[NSMutableArray alloc] init];
        TGConversation *discussionConversation = nil;
        int64_t expectedPeerId = discussionChannelId != 0 ? TGPeerIdFromChannelId((int32_t)discussionChannelId) : 0;

        NSArray *chats = [result[@"chats"] isKindOfClass:[NSArray class]] ? result[@"chats"] : @[];
        for (TLChat *chatDesc in chats)
        {
            TGConversation *candidate = [[TGConversation alloc] initWithTelegraphChatDesc:chatDesc];
            if (candidate == nil)
                continue;
            [conversations addObject:candidate];

            if (expectedPeerId != 0 && candidate.conversationId == expectedPeerId)
                discussionConversation = candidate;
            else if (discussionConversation == nil && candidate.isChannelGroup)
                discussionConversation = candidate;
        }

        if (conversations.count != 0)
            [TGDatabaseInstance() updateChannels:conversations];

        NSArray *messageDescs = [result[@"messages"] isKindOfClass:[NSArray class]] ? result[@"messages"] : @[];
        TGMessage *rootMessage = nil;

        for (TLMessage *messageDesc in messageDescs)
        {
            TGMessage *candidateMessage = [[TGMessage alloc] initWithTelegraphMessageDesc:messageDesc];
            if (candidateMessage == nil)
                continue;

            if (rootMessage == nil)
                rootMessage = candidateMessage;

            if (discussionConversation != nil && candidateMessage.cid == discussionConversation.conversationId)
            {
                rootMessage = candidateMessage;
                break;
            }
        }

        int32_t rootMessageId = rootMessage.mid;

        if (discussionConversation == nil || rootMessageId <= 0)
        {
            NSLog(@"COMMENTS open.invalidResult source=%lld mid=%d group=%@ root=%d chats=%d messages=%d",
                  conversation.conversationId, messageId, discussionConversation, rootMessageId,
                  (int)chats.count, (int)messageDescs.count);
            [TGCustomAlertView presentAlertWithTitle:nil
                                             message:@"Не удалось открыть комментарии этого поста."
                                   cancelButtonTitle:TGLocalized(@"Common.OK")
                                       okButtonTitle:nil
                                     completionBlock:nil];
            return;
        }

        int32_t maxId = [result[@"maxId"] intValue];
        if (maxId <= 0)
            maxId = rootMessageId;

        NSLog(@"COMMENTS open.resolved source=%lld post=%d group=%lld root=%d max=%d",
              conversation.conversationId, messageId, discussionConversation.conversationId, rootMessageId, maxId);

        NSDictionary *actions = @{
            @"ios6SkipForumTopics": @YES,
            @"ios6ForumResolved": @YES,
            @"ios6ForumResolvedIsForum": @((discussionConversation.flags & TGConversationFlagIsForum) != 0),
            @"ios6ForumTopicId": @(rootMessageId),
            @"ios6ForumTopicTopMessageId": @(maxId),
            @"ios6ForumTopicTitle": @"Комментарии",
            @"ios6DiscussionThread": @YES,
            @"ios6DiscussionRootMessage": rootMessage
        };

        [strongSelf navigateToConversationWithId:discussionConversation.conversationId
                                    conversation:discussionConversation
                                 performActions:actions
                                       atMessage:nil
                                      clearStack:false
                                    openKeyboard:false
                   canOpenKeyboardWhileInTransition:false
                           navigationController:navigationController
                                      selectChat:false
                                        animated:true];
    }
    error:^(id error)
    {
        NSString *errorType = [[TGTelegramNetworking instance] extractNetworkErrorType:error];
        NSLog(@"COMMENTS open.error source=%lld mid=%d error=%@", conversation.conversationId, messageId, errorType);
        [TGCustomAlertView presentAlertWithTitle:nil
                                         message:@"Комментарии недоступны или были отключены для этого поста."
                               cancelButtonTitle:TGLocalized(@"Common.OK")
                                   okButtonTitle:nil
                                 completionBlock:nil];
    }
    completed:nil];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation
{
    [self navigateToConversationWithId:conversationId conversation:conversation performActions:nil animated:true];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation animated:(bool)animated
{
    [self navigateToConversationWithId:conversationId conversation:conversation performActions:nil animated:animated];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation performActions:(NSDictionary *)performActions
{
    [self navigateToConversationWithId:conversationId conversation:conversation performActions:performActions animated:true];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation performActions:(NSDictionary *)performActions animated:(bool)animated
{
    [self navigateToConversationWithId:conversationId conversation:conversation performActions:performActions atMessage:nil clearStack:true openKeyboard:false canOpenKeyboardWhileInTransition:false animated:animated];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)__unused conversation performActions:(NSDictionary *)performActions atMessage:(NSDictionary *)atMessage clearStack:(bool)clearStack openKeyboard:(bool)openKeyboard canOpenKeyboardWhileInTransition:(bool)canOpenKeyboardWhileInTransition animated:(bool)animated
{
    if (TGPeerIdIsAd(conversationId)) {
        conversationId = TGPeerIdFromChannelId(TGAdIdFromPeerId(conversationId));
        
        NSData *data = [TGDatabaseInstance() customProperty:@"didDisplayProxyAdNotice"];
        if (data.length == 0) {
            int8_t one = 1;
            [TGDatabaseInstance() setCustomProperty:@"didDisplayProxyAdNotice" value:[NSData dataWithBytes:&one length:1]];
            [TGCustomAlertView presentAlertWithTitle:nil message:TGLocalized(@"DialogList.AdNoticeAlert") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:^(__unused bool okButtonPressed) {
                [[TGInterfaceManager instance] navigateToConversationWithId:conversationId conversation:conversation performActions:performActions atMessage:atMessage clearStack:clearStack openKeyboard:openKeyboard canOpenKeyboardWhileInTransition:canOpenKeyboardWhileInTransition animated:animated];
            }];
        }
    }
    
    [self navigateToConversationWithId:conversationId conversation:conversation performActions:performActions atMessage:atMessage clearStack:clearStack openKeyboard:openKeyboard canOpenKeyboardWhileInTransition:canOpenKeyboardWhileInTransition navigationController:nil selectChat:true animated:animated];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation performActions:(NSDictionary *)performActions atMessage:(NSDictionary *)atMessage clearStack:(bool)clearStack openKeyboard:(bool)openKeyboard canOpenKeyboardWhileInTransition:(bool)canOpenKeyboardWhileInTransition navigationController:(TGNavigationController *)navigationController animated:(bool)animated
{
       [self navigateToConversationWithId:conversationId conversation:conversation performActions:performActions atMessage:atMessage clearStack:clearStack openKeyboard:openKeyboard canOpenKeyboardWhileInTransition:canOpenKeyboardWhileInTransition navigationController:navigationController selectChat:true animated:animated];
}

- (void)navigateToConversationWithId:(int64_t)conversationId conversation:(TGConversation *)conversation performActions:(NSDictionary *)performActions atMessage:(NSDictionary *)atMessage clearStack:(bool)clearStack openKeyboard:(bool)openKeyboard canOpenKeyboardWhileInTransition:(bool)canOpenKeyboardWhileInTransition navigationController:(TGNavigationController *)navigationController selectChat:(bool)selectChat animated:(bool)animated
{
    TGConversation *providedConversation = conversation;
    int32_t requestedForumTopicId = [performActions[@"ios6ForumTopicId"] intValue];
    int32_t requestedForumTopicTopMessageId = [performActions[@"ios6ForumTopicTopMessageId"] intValue];
    NSString *requestedForumTopicTitle = [performActions[@"ios6ForumTopicTitle"] isKindOfClass:[NSString class]] ? performActions[@"ios6ForumTopicTitle"] : nil;
    bool forceForumTopicPicker = [performActions[@"ios6ForceForumTopicPicker"] boolValue];

    NSLog(@"NAV enter peer=%lld channel=%d actions=%@ atMessage=%d openKeyboard=%d",
          conversationId, TGPeerIdIsChannel(conversationId) ? 1 : 0,
          performActions != nil ? [performActions allKeys] : @[],
          atMessage != nil ? 1 : 0, openKeyboard ? 1 : 0);

    if (selectChat)
        [TGAppDelegateInstance.rootController.dialogListController selectConversationWithId:conversationId];
    
    [self dismissBannerForConversationId:conversationId];
    
    TGModernConversationController *conversationController = nil;
    
    NSArray *viewControllers = navigationController ? navigationController.viewControllers : TGAppDelegateInstance.rootController.viewControllers;
    for (UIViewController *viewController in viewControllers)
    {
        if ([viewController isKindOfClass:[TGModernConversationController class]])
        {
            TGModernConversationController *existingConversationController = (TGModernConversationController *)viewController;
            id companion = existingConversationController.companion;
            if ([companion isKindOfClass:[TGGenericModernConversationCompanion class]])
            {
                if (((TGGenericModernConversationCompanion *)companion).conversationId == conversationId)
                {
                    if (requestedForumTopicId != 0)
                    {
                        if ([companion isKindOfClass:[TGIOS6ForumTopicConversationCompanion class]] &&
                            [(TGIOS6ForumTopicConversationCompanion *)companion forumTopicId] == requestedForumTopicId)
                        {
                            conversationController = existingConversationController;
                            break;
                        }
                    }
                    else if (![companion isKindOfClass:[TGIOS6ForumTopicConversationCompanion class]])
                    {
                        conversationController = existingConversationController;
                        break;
                    }
                }
            }
        }
    }
    
    if (navigationController == nil && [TGAppDelegateInstance.rootController.presentedViewController isKindOfClass:[TGHashtagOverviewController class]])
    {
        navigationController = (TGHashtagOverviewController *)TGAppDelegateInstance.rootController.presentedViewController;
    }
    
    if (conversationController == nil || (atMessage[@"mid"] != nil && ![atMessage[@"openMedia"] boolValue] && ![atMessage[@"useExisting"] boolValue]))
    {
        int conversationUnreadCount = providedConversation != nil && providedConversation.conversationId == conversationId ? providedConversation.unreadCount : [TGDatabaseInstance() unreadCountForConversation:conversationId];
        int globalUnreadCount = [TGDatabaseInstance() cachedUnreadCount];
        
        conversationController = [[TGModernConversationController alloc] init];
        conversationController.presentation = TGPresentation.current;
        conversationController.shouldOpenKeyboardOnce = openKeyboard;
        conversationController.canOpenKeyboardWhileInTransition = canOpenKeyboardWhileInTransition;
        conversationController.willChangeDim = ^(bool dim, UIView *keyboardSnapshotView, bool restoringFocus)
        {
            if (TGAppDelegateInstance.rootController.currentSizeClass == UIUserInterfaceSizeClassRegular)
                [TGAppDelegateInstance.rootController.dialogListController setDimmed:dim animated:true keyboardSnapshot:keyboardSnapshotView restoringFocus:restoringFocus];
        };
        
        if (TGPeerIdIsChannel(conversationId))
        {
            bool forumResolvedOverride = [performActions[@"ios6ForumResolved"] boolValue];
            bool forumResolvedIsForum = [performActions[@"ios6ForumResolvedIsForum"] boolValue];

            TGConversation *databaseConversation = providedConversation != nil && providedConversation.conversationId == conversationId ? providedConversation : [TGDatabaseInstance() loadChannels:@[@(conversationId)]][@(conversationId)];
            if (forumResolvedOverride && providedConversation != nil && providedConversation.conversationId == conversationId)
                conversation = providedConversation;
            else
                conversation = databaseConversation;

            NSLog(@"NAV channel.loaded peer=%lld db=%d provided=%d override=%d flags=0x%llx",
                  conversationId, databaseConversation != nil ? 1 : 0,
                  providedConversation != nil ? 1 : 0, forumResolvedOverride ? 1 : 0,
                  conversation != nil ? conversation.flags : 0);

            if (conversation != nil) {
                if (conversation.hasExplicitContent) {
                    if (!navigationController)
                        [TGAppDelegateInstance.rootController.dialogListController selectConversationWithId:0];
                    
                    [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"ExplicitContent.AlertTitle") message:conversation.restrictionReason.length == 0 ? TGLocalized(@"ExplicitContent.AlertChannel") : [self explicitContentReason:conversation.restrictionReason] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                    
                    return;
                }

                bool cachedForum = forumResolvedOverride ? forumResolvedIsForum : ((conversation.flags & TGConversationFlagIsForum) != 0);
                bool forumKnown = forumResolvedOverride ? true : ((conversation.flags & TGConversationFlagForumKnown) != 0);
                bool skipForumTopics = [performActions[@"ios6SkipForumTopics"] boolValue];

                NSUInteger internalActionCount = 0;
                if (performActions[@"ios6SkipForumTopics"] != nil)
                    internalActionCount++;
                if (performActions[@"ios6ForumResolved"] != nil)
                    internalActionCount++;
                if (performActions[@"ios6ForumResolvedIsForum"] != nil)
                    internalActionCount++;
                if (performActions[@"ios6ForumTopicId"] != nil)
                    internalActionCount++;
                if (performActions[@"ios6ForumTopicTopMessageId"] != nil)
                    internalActionCount++;
                if (performActions[@"ios6ForumTopicTitle"] != nil)
                    internalActionCount++;
                if (performActions[@"ios6ForceForumTopicPicker"] != nil)
                    internalActionCount++;
                if (performActions[@"ios6DiscussionThread"] != nil)
                    internalActionCount++;
                bool hasExplicitConversationAction = atMessage != nil || openKeyboard ||
                    (performActions.count > internalActionCount);

                NSLog(@"NAV channel.route peer=%lld known=%d forum=%d skip=%d explicit=%d forceTopic=%d flags=0x%llx",
                      conversationId, forumKnown ? 1 : 0, cachedForum ? 1 : 0,
                      skipForumTopics ? 1 : 0, hasExplicitConversationAction ? 1 : 0, forceForumTopicPicker ? 1 : 0,
                      conversation.flags);

                if (!skipForumTopics && conversation.isChannelGroup && !forumKnown && (!hasExplicitConversationAction || forceForumTopicPicker))
                {
                    TLInputPeer *metadataPeer = [TGTelegraphInstance createInputPeerForConversation:conversation.conversationId accessHash:conversation.accessHash];
                    if ([metadataPeer isKindOfClass:[TLInputPeer$inputPeerChannel class]])
                    {
                        TLInputPeer$inputPeerChannel *peerChannel = (TLInputPeer$inputPeerChannel *)metadataPeer;
                        TLInputChannel$inputChannel *inputChannel = [[TLInputChannel$inputChannel alloc] init];
                        inputChannel.channel_id = peerChannel.channel_id;
                        inputChannel.access_hash = peerChannel.access_hash;

                        TGIOS6GetChannelsRpc *request = [[TGIOS6GetChannelsRpc alloc] init];
                        request.channels = @[inputChannel];

                        NSLog(@"FORUM nav.resolveForum peer=%lld channel=%lld hash=%lld", conversationId, inputChannel.channel_id, inputChannel.access_hash);

                        __weak TGInterfaceManager *weakSelf = self;
                        [[[[TGTelegramNetworking instance] requestSignal:request] deliverOn:[SQueue mainQueue]] startWithNext:^(TLmessages_Chats *result)
                        {
                            __strong TGInterfaceManager *strongSelf = weakSelf;
                            if (strongSelf == nil)
                                return;

                            TGConversation *freshConversation = nil;
                            if ([result.chats isKindOfClass:[NSArray class]] && result.chats.count != 0)
                                freshConversation = [[TGConversation alloc] initWithTelegraphChatDesc:result.chats.firstObject];

                            if (freshConversation != nil)
                            {
                                freshConversation.flags |= TGConversationFlagForumKnown;
                                [TGDatabaseInstance() updateChannels:@[freshConversation]];

                                bool freshForum = (freshConversation.flags & TGConversationFlagIsForum) != 0;
                                NSLog(@"FORUM nav.resolved peer=%lld forum=%d flags=0x%llx", conversationId, freshForum ? 1 : 0, freshConversation.flags);

                                NSMutableDictionary *resolvedActions = performActions != nil ? [performActions mutableCopy] : [[NSMutableDictionary alloc] init];
                                resolvedActions[@"ios6ForumResolved"] = @YES;
                                resolvedActions[@"ios6ForumResolvedIsForum"] = @(freshForum);

                                [strongSelf navigateToConversationWithId:conversationId
                                                            conversation:freshConversation
                                                         performActions:resolvedActions
                                                               atMessage:atMessage
                                                              clearStack:clearStack
                                                            openKeyboard:openKeyboard
                                           canOpenKeyboardWhileInTransition:canOpenKeyboardWhileInTransition
                                                   navigationController:navigationController
                                                             selectChat:selectChat
                                                               animated:animated];
                                return;
                            }

                            NSMutableDictionary *fallbackActions = performActions != nil ? [performActions mutableCopy] : [[NSMutableDictionary alloc] init];
                            fallbackActions[@"ios6SkipForumTopics"] = @YES;
                            NSLog(@"FORUM nav.resolveEmpty peer=%lld -> normal chat", conversationId);
                            [strongSelf navigateToConversationWithId:conversationId
                                                        conversation:conversation
                                                     performActions:fallbackActions
                                                           atMessage:atMessage
                                                          clearStack:clearStack
                                                        openKeyboard:openKeyboard
                                       canOpenKeyboardWhileInTransition:canOpenKeyboardWhileInTransition
                                               navigationController:navigationController
                                                         selectChat:selectChat
                                                           animated:animated];
                        } error:^(__unused id error)
                        {
                            __strong TGInterfaceManager *strongSelf = weakSelf;
                            if (strongSelf == nil)
                                return;

                            NSMutableDictionary *fallbackActions = performActions != nil ? [performActions mutableCopy] : [[NSMutableDictionary alloc] init];
                            fallbackActions[@"ios6SkipForumTopics"] = @YES;
                            NSLog(@"FORUM nav.resolveError peer=%lld -> normal chat", conversationId);
                            [strongSelf navigateToConversationWithId:conversationId
                                                        conversation:conversation
                                                     performActions:fallbackActions
                                                           atMessage:atMessage
                                                          clearStack:clearStack
                                                        openKeyboard:openKeyboard
                                       canOpenKeyboardWhileInTransition:canOpenKeyboardWhileInTransition
                                               navigationController:navigationController
                                                         selectChat:selectChat
                                                           animated:animated];
                        } completed:nil];
                        return;
                    }
                }

                if (!skipForumTopics && conversation.isChannelGroup && forumKnown && cachedForum && (!hasExplicitConversationAction || forceForumTopicPicker))
                {
                    NSLog(@"FORUM nav.openTopics peer=%lld forumKnown=%d cachedForum=%d force=%d flags=0x%llx", conversationId, forumKnown ? 1 : 0, cachedForum ? 1 : 0, forceForumTopicPicker ? 1 : 0, conversation.flags);
                    NSDictionary *pendingActions = forceForumTopicPicker ? performActions : nil;
                    TGIOS6ForumTopicsController *topicsController = [[TGIOS6ForumTopicsController alloc] initWithConversation:conversation pendingActions:pendingActions];
                    if (navigationController != nil)
                        [navigationController pushViewController:topicsController animated:animated];
                    else if (clearStack)
                        [TGAppDelegateInstance.rootController replaceContentController:topicsController];
                    else
                        [TGAppDelegateInstance.rootController pushContentController:topicsController];
                    return;
                }

                TGChannelConversationCompanion *companion = nil;
                if (requestedForumTopicId != 0)
                {
                    NSLog(@"FORUM thread.native.open peer=%lld topic=%d top=%d title=%@",
                          conversationId, requestedForumTopicId, requestedForumTopicTopMessageId, requestedForumTopicTitle);
                    companion = [[TGIOS6ForumTopicConversationCompanion alloc]
                        initWithConversation:conversation
                        userActivities:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId]
                        topicId:requestedForumTopicId
                        topMessageId:requestedForumTopicTopMessageId
                        title:requestedForumTopicTitle];
                    [(TGIOS6ForumTopicConversationCompanion *)companion setDiscussionThread:[performActions[@"ios6DiscussionThread"] boolValue]];
                    if ([performActions[@"ios6DiscussionRootMessage"] isKindOfClass:[TGMessage class]])
                        [(TGIOS6ForumTopicConversationCompanion *)companion setDiscussionRootMessage:performActions[@"ios6DiscussionRootMessage"]];
                }
                else
                {
                    NSLog(@"NAV channel.openNormal peer=%lld title=%@", conversationId, conversation.chatTitle);
                    companion = [[TGChannelConversationCompanion alloc] initWithConversation:conversation userActivities:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId]];
                    if (atMessage != nil)
                        [companion setPreferredInitialMessagePositioning:[atMessage[@"mid"] intValue] peerId:[atMessage[@"peerId"] longLongValue] groupedSingle:[atMessage[@"groupedSingle"] boolValue] pipLocation:atMessage[@"pipLocation"]];
                }
                [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
                [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
                conversationController.companion = companion;
            }
        }
        else if (conversationId <= INT_MIN)
        {
            NSLog(@"NAV secret.open peer=%lld", conversationId);
            int64_t encryptedConversationId = [TGDatabaseInstance() encryptedConversationIdForPeerId:conversationId];
            int64_t accessHash = [TGDatabaseInstance() encryptedConversationAccessHash:conversationId];
            int32_t uid = [TGDatabaseInstance() encryptedParticipantIdForConversationId:conversationId];
            TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
            TGSecretModernConversationCompanion *companion = [[TGSecretModernConversationCompanion alloc] initWithConversation:conversation encryptedConversationId:encryptedConversationId accessHash:accessHash uid:uid activity:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId][@(uid)] mayHaveUnreadMessages:conversationUnreadCount != 0];
            if (atMessage != nil)
                [companion setPreferredInitialMessagePositioning:[atMessage[@"mid"] intValue] peerId:[atMessage[@"peerId"] longLongValue] groupedSingle:[atMessage[@"groupedSingle"] boolValue] pipLocation:atMessage[@"pipLocation"]];
            [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
            [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
            conversationController.companion = companion;
        }
        else if (conversationId < 0)
        {
            NSLog(@"NAV group.open peer=%lld", conversationId);
            TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
            if (conversation == nil) {
                conversation = [[TGConversation alloc] initWithConversationId:conversationId unreadCount:0 serviceUnreadCount:0];
            }
            TGGroupModernConversationCompanion *companion = [[TGGroupModernConversationCompanion alloc] initWithConversation:conversation userActivities:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId] mayHaveUnreadMessages:conversationUnreadCount != 0];
            if (atMessage != nil)
                [companion setPreferredInitialMessagePositioning:[atMessage[@"mid"] intValue] peerId:[atMessage[@"peerId"] longLongValue] groupedSingle:[atMessage[@"groupedSingle"] boolValue] pipLocation:atMessage[@"pipLocation"]];
            [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
            [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
            conversationController.companion = companion;
        }
        else
        {
            TGUser *user = [TGDatabaseInstance() loadUser:(int32_t)conversationId];
            if (user.hasExplicitContent) {
                if (!navigationController)
                    [TGAppDelegateInstance.rootController.dialogListController selectConversationWithId:0];
                
                [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"ExplicitContent.AlertTitle") message:user.restrictionReason.length == 0 ? TGLocalized(@"ExplicitContent.AlertUser") : [self explicitContentReason:user.restrictionReason] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                
                return;
            }
            
            TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
            if (conversation == nil) {
                conversation = [[TGConversation alloc] initWithConversationId:conversationId unreadCount:0 serviceUnreadCount:0];
            }
            TGPrivateModernConversationCompanion *companion = [[TGPrivateModernConversationCompanion alloc] initWithConversation:conversation activity:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId][@((int)conversationId)] mayHaveUnreadMessages:conversationUnreadCount != 0];
            companion.botStartPayload = performActions[@"botStartPayload"];
            companion.botContextPeerId = performActions[@"contextPeerId"];
            companion.botAutostartPayload = performActions[@"botAutostartPayload"];
            if (atMessage != nil)
                [companion setPreferredInitialMessagePositioning:[atMessage[@"mid"] intValue] peerId:[atMessage[@"peerId"] longLongValue] groupedSingle:[atMessage[@"groupedSingle"] boolValue] pipLocation:atMessage[@"pipLocation"]];
            [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
            [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
            conversationController.companion = companion;
        }
        
        ((TGGenericModernConversationCompanion *)conversationController.companion).replaceInitialText = performActions[@"replaceInitialText"];
        
        [conversationController.companion bindController:conversationController];
        
        conversationController.shouldIgnoreAppearAnimationOnce = !animated;
        if (performActions[@"text"] != nil) {
            [conversationController setInputText:performActions[@"text"] replace:[performActions[@"textReplace"] boolValue] selectRange:NSMakeRange(0, 0)];
        }
        
        if (performActions[@"shareLink"] != nil && ((NSDictionary *)performActions[@"shareLink"])[@"url"] != nil) {
            NSString *url = performActions[@"shareLink"][@"url"];
            NSString *text = performActions[@"shareLink"][@"text"];
            NSString *result = @"";
            NSRange textRange = NSMakeRange(0, 0);
            if (text.length != 0) {
                result = [[url stringByAppendingString:@"\n"] stringByAppendingString:text];
                textRange = NSMakeRange(url.length + 1, result.length - url.length - 1);
            } else {
                result = url;
            }
            [conversationController setInputText:result replace:true selectRange:textRange];
            conversationController.shouldOpenKeyboardOnce = true;
        }
        
        if (navigationController)
        {
            [navigationController pushViewController:conversationController animated:true];
        }
        else
        {
            if (clearStack) {
                [TGAppDelegateInstance.rootController replaceContentController:conversationController];
            } else {
                [TGAppDelegateInstance.rootController pushContentController:conversationController];
            }
        }
    
        __weak TGModernConversationController *weakController = conversationController;
        _conversationControllerPipe.sink(weakController);
    }
    else
    {
        if ([(NSArray *)performActions[@"forwardMessages"] count] != 0)
            [(TGGenericModernConversationCompanion *)conversationController.companion standaloneForwardMessages:performActions[@"forwardMessages"] completeGroups:performActions[@"completeGroups"]];
        
        if ([(NSArray *)performActions[@"sendMessages"] count] != 0)
            [(TGGenericModernConversationCompanion *)conversationController.companion standaloneSendMessages:performActions[@"sendMessages"]];
        
        if ([(NSArray *)performActions[@"sendFiles"] count] != 0)
            [(TGGenericModernConversationCompanion *)conversationController.companion standaloneSendFiles:performActions[@"sendFiles"]];
        
        if (performActions[@"text"] != nil) {
            [conversationController setInputText:performActions[@"text"] replace:[performActions[@"textReplace"] boolValue] selectRange:NSMakeRange(0, 0)];
        }
        
        if (performActions[@"shareLink"] != nil && ((NSDictionary *)performActions[@"shareLink"])[@"url"] != nil) {
            NSString *url = performActions[@"shareLink"][@"url"];
            NSString *text = performActions[@"shareLink"][@"text"];
            NSString *result = @"";
            NSRange textRange = NSMakeRange(0, 0);
            if (text.length != 0) {
                result = [[url stringByAppendingString:@"\n"] stringByAppendingString:text];
                textRange = NSMakeRange(url.length + 1, result.length - url.length - 1);
            } else {
                result = url;
            }
            [conversationController setInputText:result replace:true selectRange:textRange];
            conversationController.shouldOpenKeyboardOnce = true;
        }
        
        if (performActions[@"replaceInitialText"] != nil) {
            [conversationController setInputText:performActions[@"replaceInitialText"] replace:true selectRange:NSMakeRange(0, 0)];
            conversationController.shouldOpenKeyboardOnce = true;
        }
        
        if (performActions[@"botStartPayload"] != nil)
        {
            if ([conversationController.companion isKindOfClass:[TGPrivateModernConversationCompanion class]])
            {
                [(TGPrivateModernConversationCompanion *)conversationController.companion standaloneSendBotStartPayload:performActions[@"botStartPayload"]];
            }
        }
        
        bool dontPop = false;
        if ([atMessage[@"mid"] intValue] != 0)
        {
            int mid = [atMessage[@"mid"] intValue];
            
            [conversationController.companion navigateToMessageId:mid scrollBackMessageId:0 forceUnseenMention:false animated:true];
        
            if ([atMessage[@"openMedia"] boolValue])
            {
                if (atMessage[@"pipLocation"])
                {
                    dontPop = [conversationController openPIPSourceLocation:atMessage[@"pipLocation"]];
                }
                else
                {
                    [conversationController openMediaFromMessage:mid peerId:0 cancelPIP:false];
                }
            }
        }
        
        if (!dontPop)
            [TGAppDelegateInstance.rootController popToContentController:conversationController];
        
        if (openKeyboard)
            [conversationController openKeyboard];
    }
}

- (void)navigateToChannelLogWithConversation:(TGConversation *)conversation animated:(bool)animated {
    TGModernConversationController *conversationController = [[TGModernConversationController alloc] init];
    conversationController.presentation = TGPresentation.current;
    
    TGAdminLogConversationCompanion *companion = [[TGAdminLogConversationCompanion alloc] initWithConversation:conversation];
    conversationController.companion = companion;
    
    [conversationController.companion bindController:conversationController];
    
    conversationController.shouldIgnoreAppearAnimationOnce = !animated;
    
    [TGAppDelegateInstance.rootController pushContentController:conversationController];
    
    __weak TGModernConversationController *weakController = conversationController;
    _conversationControllerPipe.sink(weakController);
}

- (void)navigateToChannelsFeed:(int32_t)feedId animated:(bool)animated
{
    TGModernConversationController *conversationController = [self configuredFeedControllerWithId:feedId preview:false];
    conversationController.shouldIgnoreAppearAnimationOnce = !animated;
    
    [TGAppDelegateInstance.rootController pushContentController:conversationController];
    
    __weak TGModernConversationController *weakController = conversationController;
    _conversationControllerPipe.sink(weakController);
}

- (NSString *)explicitContentReason:(NSString *)text {
    NSRange range = [text rangeOfString:@":"];
    if (range.location != NSNotFound) {
        return [text substringFromIndex:range.location + range.length];
    } else {
        return text;
    }
}

- (TGModernConversationController *)configuredPreviewConversationControlerWithId:(int64_t)conversationId {
    return [self configuredConversationControlerWithId:conversationId performActions:nil preview:true];
}

- (TGModernConversationController *)configuredPreviewFeedControllerWithId:(int32_t)feedId
{
    return [self configuredFeedControllerWithId:feedId preview:true];
}

- (TGModernConversationController *)configuredFeedControllerWithId:(int32_t)feedId preview:(bool)preview
{
    int conversationUnreadCount = 0; //[TGDatabaseInstance() unreadCountForConversation:conversationId];
    int globalUnreadCount = [TGDatabaseInstance() cachedUnreadCount];
    
    TGModernConversationController *conversationController = [[TGModernConversationController alloc] init];
    conversationController.presentation = TGPresentation.current;
    
    TGFeed *feed = [TGDatabaseInstance() loadFeed:feedId];
    TGFeedConversationCompanion *companion = [[TGFeedConversationCompanion alloc] initWithFeed:feed];
    companion.previewMode = preview;
    [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
    conversationController.companion = companion;
    [conversationController.companion bindController:conversationController];
    
    return conversationController;
}

- (TGModernConversationController *)configuredConversationControlerWithId:(int64_t)conversationId performActions:(NSDictionary *)performActions preview:(bool)preview {
    if (TGPeerIdIsAd(conversationId)) {
        conversationId = TGPeerIdFromChannelId(TGAdIdFromPeerId(conversationId));
    }
    
    NSDictionary *atMessage = nil;
    
    int conversationUnreadCount = [TGDatabaseInstance() unreadCountForConversation:conversationId];
    int globalUnreadCount = [TGDatabaseInstance() cachedUnreadCount];
    
    TGModernConversationController *conversationController = [[TGModernConversationController alloc] init];
    conversationController.presentation = TGPresentation.current;
    conversationController.shouldOpenKeyboardOnce = false;
    conversationController.willChangeDim = ^(bool dim, UIView *keyboardSnapshotView, bool restoringFocus)
    {
        if (TGAppDelegateInstance.rootController.currentSizeClass == UIUserInterfaceSizeClassRegular)
            [TGAppDelegateInstance.rootController.dialogListController setDimmed:dim animated:true keyboardSnapshot:keyboardSnapshotView restoringFocus:restoringFocus];
    };
    
    TGConversation *conversation = nil;
    if (TGPeerIdIsChannel(conversationId))
    {
        conversation = [TGDatabaseInstance() loadChannels:@[@(conversationId)]][@(conversationId)];
        if (conversation != nil) {
            if (conversation.hasExplicitContent) {
                [TGAppDelegateInstance.rootController.dialogListController selectConversationWithId:0];
                
                [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"ExplicitContent.AlertTitle") message:conversation.restrictionReason.length == 0 ? TGLocalized(@"ExplicitContent.AlertChannel") : [self explicitContentReason:conversation.restrictionReason] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
                
                return nil;
            }
            
            TGChannelConversationCompanion *companion = [[TGChannelConversationCompanion alloc] initWithConversation:conversation userActivities:nil];
            companion.previewMode = preview;
            [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
            [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
            conversationController.companion = companion;
        }
    }
    else if (conversationId <= INT_MIN)
    {
        int64_t encryptedConversationId = [TGDatabaseInstance() encryptedConversationIdForPeerId:conversationId];
        int64_t accessHash = [TGDatabaseInstance() encryptedConversationAccessHash:conversationId];
        int32_t uid = [TGDatabaseInstance() encryptedParticipantIdForConversationId:conversationId];
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
        if (conversation == nil) {
            conversation = [[TGConversation alloc] initWithConversationId:conversationId unreadCount:0 serviceUnreadCount:0];
        }
        TGSecretModernConversationCompanion *companion = [[TGSecretModernConversationCompanion alloc] initWithConversation:conversation encryptedConversationId:encryptedConversationId accessHash:accessHash uid:uid activity:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId][@(uid)] mayHaveUnreadMessages:conversationUnreadCount != 0];
        companion.previewMode = preview;
        if (atMessage != nil)
            [companion setPreferredInitialMessagePositioning:[atMessage[@"mid"] intValue] peerId:[atMessage[@"peerId"] longLongValue] groupedSingle:[atMessage[@"groupedSingle"] boolValue] pipLocation:atMessage[@"pipLocation"]];
        [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
        [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
        conversationController.companion = companion;
    }
    else if (conversationId < 0)
    {
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
        if (conversation == nil) {
            conversation = [[TGConversation alloc] initWithConversationId:conversationId unreadCount:0 serviceUnreadCount:0];
        }
        TGGroupModernConversationCompanion *companion = [[TGGroupModernConversationCompanion alloc] initWithConversation:conversation userActivities:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId] mayHaveUnreadMessages:conversationUnreadCount != 0];
        companion.previewMode = preview;
        if (atMessage != nil)
            [companion setPreferredInitialMessagePositioning:[atMessage[@"mid"] intValue] peerId:[atMessage[@"peerId"] longLongValue] groupedSingle:[atMessage[@"groupedSingle"] boolValue] pipLocation:atMessage[@"pipLocation"]];
        [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
        [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
        conversationController.companion = companion;
    }
    else
    {
        TGUser *user = [TGDatabaseInstance() loadUser:(int32_t)conversationId];
        if (user.hasExplicitContent) {
            [TGAppDelegateInstance.rootController.dialogListController selectConversationWithId:0];
            
            [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"ExplicitContent.AlertTitle") message:user.restrictionReason.length == 0 ? TGLocalized(@"ExplicitContent.AlertUser") : [self explicitContentReason:user.restrictionReason] cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            
            return nil;
        }
        
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
        if (conversation == nil) {
            conversation = [[TGConversation alloc] initWithConversationId:conversationId unreadCount:0 serviceUnreadCount:0];
        }
        TGPrivateModernConversationCompanion *companion = [[TGPrivateModernConversationCompanion alloc] initWithConversation:conversation activity:[TGTelegraphInstance typingUserActivitiesInConversationFromMainThread:conversationId][@((int)conversationId)] mayHaveUnreadMessages:conversationUnreadCount != 0];
        companion.previewMode = preview;
        companion.botStartPayload = performActions[@"botStartPayload"];
        companion.botAutostartPayload = performActions[@"botAutostartPayload"];
        companion.botContextPeerId = performActions[@"contextPeerId"];
        if (atMessage != nil)
            [companion setPreferredInitialMessagePositioning:[atMessage[@"mid"] intValue] peerId:[atMessage[@"peerId"] longLongValue] groupedSingle:[atMessage[@"groupedSingle"] boolValue] pipLocation:atMessage[@"pipLocation"]];
        [companion setInitialMessagePayloadWithForwardMessages:performActions[@"forwardMessages"] initialCompleteGroups:performActions[@"completeGroups"] sendMessages:performActions[@"sendMessages"] sendFiles:performActions[@"sendFiles"]];
        [companion setOthersUnreadCount:MAX(globalUnreadCount - conversationUnreadCount, 0)];
        conversationController.companion = companion;
    }
    
    [conversationController.companion bindController:conversationController];
    
    conversationController.shouldIgnoreAppearAnimationOnce = true;
    
    return conversationController;
}

- (TGModernConversationController *)currentControllerWithPeerId:(int64_t)peerId
{
    for (UIViewController *viewController in TGAppDelegateInstance.rootController.viewControllers)
    {
        if ([viewController isKindOfClass:[TGModernConversationController class]])
        {
            TGModernConversationController *existingConversationController = (TGModernConversationController *)viewController;
            id companion = existingConversationController.companion;
            if ([companion isKindOfClass:[TGGenericModernConversationCompanion class]])
            {
                if (((TGGenericModernConversationCompanion *)companion).conversationId == peerId)
                    return existingConversationController;
            }
        }
    }
    
    return nil;
}

- (void)dismissConversation
{
    [TGAppDelegateInstance.rootController clearContentControllers];
    [TGAppDelegateInstance.rootController.dialogListController selectConversationWithId:0];
}

- (void)navigateToProfileOfUser:(int)uid
{
    [self navigateToProfileOfUser:uid preferNativeContactId:0];
}

- (void)navigateToProfileOfUser:(int)uid shareVCard:(void (^)())shareVCard
{
    TGUser *user = [TGDatabaseInstance() loadUser:uid];
    if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
    {
        TGBotUserInfoController *userInfoController = [[TGBotUserInfoController alloc] initWithUid:uid sendCommand:nil];
        [TGAppDelegateInstance.rootController pushContentController:userInfoController];
    }
    else
    {
        TGTelegraphUserInfoController *userInfoController = [[TGTelegraphUserInfoController alloc] initWithUid:uid];
        userInfoController.shareVCard = shareVCard;
        [TGAppDelegateInstance.rootController pushContentController:userInfoController];
    }
}

- (void)navigateToProfileOfUser:(int)uid encryptedConversationId:(int64_t)encryptedConversationId
{
    [self navigateToProfileOfUser:uid preferNativeContactId:0 encryptedConversationId:encryptedConversationId callMessages:nil];
}

- (void)navigateToProfileOfUser:(int)uid callMessages:(NSArray *)callMessages
{
    [self navigateToProfileOfUser:uid preferNativeContactId:0 encryptedConversationId:0 callMessages:callMessages];
}

- (void)navigateToProfileOfUser:(int)uid preferNativeContactId:(int)preferNativeContactId
{
    [self navigateToProfileOfUser:uid preferNativeContactId:preferNativeContactId encryptedConversationId:0 callMessages:nil];
}

- (void)navigateToProfileOfUser:(int)uid preferNativeContactId:(int)__unused preferNativeContactId encryptedConversationId:(int64_t)encryptedConversationId callMessages:(NSArray *)callMessages
{
    void (^pushController)(TGViewController *) = ^(TGViewController *controller)
    {
        if ([TGAppDelegateInstance.rootController.presentedViewController isKindOfClass:[TGHashtagOverviewController class]])
        {
            [(TGHashtagOverviewController *)TGAppDelegateInstance.rootController.presentedViewController pushViewController:controller animated:true];
        }
        else
        {
            [TGAppDelegateInstance.rootController pushContentController:controller];
        }
    };
    
    if (encryptedConversationId == 0)
    {
        TGUser *user = [TGDatabaseInstance() loadUser:uid];
        
        if (user.kind == TGUserKindBot || user.kind == TGUserKindSmartBot)
        {
            TGBotUserInfoController *userInfoController = [[TGBotUserInfoController alloc] initWithUid:uid sendCommand:nil];
            pushController(userInfoController);
        }
        else
        {
            TGTelegraphUserInfoController *userInfoController = [[TGTelegraphUserInfoController alloc] initWithUid:uid callMessages:callMessages];
            pushController(userInfoController);
        }
    }
    else
    {
        TGSecretChatUserInfoController *secretChatInfoController = [[TGSecretChatUserInfoController alloc] initWithUid:uid encryptedConversationId:encryptedConversationId];
        pushController(secretChatInfoController);
    }
}

- (void)navigateToSharedMediaOfConversationWithId:(int64_t)conversationId mode:(int)mode atMessage:(NSDictionary *)__unused atMessage
{
    void (^pushController)(TGViewController *) = ^(TGViewController *controller)
    {
        if ([TGAppDelegateInstance.rootController.presentedViewController isKindOfClass:[TGHashtagOverviewController class]])
        {
            [(TGHashtagOverviewController *)TGAppDelegateInstance.rootController.presentedViewController pushViewController:controller animated:true];
        }
        else
        {
            [TGAppDelegateInstance.rootController pushContentController:controller];
        }
    };
    
    TGSharedMediaController *controller = nil;
    for (UIViewController *viewController in TGAppDelegateInstance.rootController.viewControllers)
    {
        if ([viewController isKindOfClass:[TGSharedMediaController class]])
        {
            TGSharedMediaController *existingController = (TGSharedMediaController *)viewController;
            if (existingController.peerId == conversationId)
            {
                controller = existingController;
                break;
            }
        }
    }

    if (controller != nil)
    {
        if (controller.mode != mode)
            [controller setMode:(TGSharedMediaControllerMode)mode];
    }
    else
    {
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
        controller = [[TGSharedMediaController alloc] initWithPeerId:conversation.conversationId accessHash:conversation.accessHash mode:(TGSharedMediaControllerMode)mode important:!conversation.isChannelGroup];
        pushController(controller);
    }
}

- (void)_initializeNotificationControllerIfNeeded
{
    if (_notificationController == nil)
    {
        _notificationController = [[TGNotificationController alloc] init];
        
        __weak TGInterfaceManager *weakSelf = self;
        void (^navigateBlock)(int64_t) = ^(int64_t conversationId)
        {
            __strong TGInterfaceManager *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            bool animated = true;
            if (TGAppDelegateInstance.rootController.presentedViewController != nil)
            {
                [TGAppDelegateInstance.rootController dismissViewControllerAnimated:true completion:nil];
                animated = false;
            }
            
            [self dismissMusicPlayer];
            
            for (UIWindow *window in [UIApplication sharedApplication].windows)
            {
                if ([window isKindOfClass:[TGOverlayControllerWindow class]] && window != _notificationController.window)
                {
                    TGOverlayController *controller = (TGOverlayController *)window.rootViewController;
                    if ([controller isKindOfClass:[TGCallController class]])
                    {
                        [(TGCallController *)controller minimize];
                    }
                    else
                    {
                        [controller dismiss];
                        animated = false;
                    }
                }
            }
            
            [strongSelf navigateToConversationWithId:conversationId conversation:nil animated:animated];
        };
        
        _notificationController.navigateToConversation = ^(int64_t conversationId)
        {
            __strong TGInterfaceManager *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (TGAppDelegateInstance.contentWindow != nil)
                return;
            
            if (conversationId == 0)
                return;
            
            if (conversationId < 0)
            {
                if ([TGDatabaseInstance() loadConversationWithId:conversationId] == nil)
                    return;
            }
            
            UIView<TGPIPAblePlayerView> *playerView = [TGEmbedPIPController activeNonPIPPlayerView];
            if (playerView != nil)
            {
                [playerView switchToPictureInPicture];
                TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
                {
                    navigateBlock(conversationId);
                });
            }
            else
            {
                navigateBlock(conversationId);
            }
        };
        
        _notificationController.willPlayAudioAttachment = ^
        {
            __strong TGInterfaceManager *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf dismissMusicPlayer];
        };
    }
}

- (void)displayBannerIfNeeded:(TGMessage *)message conversationId:(int64_t)conversationId
{
    if (TGAppDelegateInstance.isDisplayingPasscodeWindow || !TGAppDelegateInstance.bannerEnabled || TGAppDelegateInstance.rootController.isSplitView)
        return;
    
    TGBotReplyMarkup *replyMarkup = message.replyMarkup;
    if (replyMarkup.isInline)
    {
        for (TGBotReplyMarkupRow *row in replyMarkup.rows)
        {
            for (TGBotReplyMarkupButton *button in row.buttons)
            {
                if ([button.action isKindOfClass:[TGBotReplyMarkupButtonActionSwitchInline class]])
                    return;
            }
        }
    }
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        TGUser *user = nil;
        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:conversationId];
        
        if (!conversation.isChannel || conversation.isChannelGroup)
            user = [TGDatabaseInstance() loadUser:(int)message.fromUid];
        
        if (conversationId > 0 || conversation != nil)
        {
            TGDispatchOnMainThread(^
            {
                if ([UIApplication sharedApplication] == nil || [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
                    return;
                
                [self _initializeNotificationControllerIfNeeded];

                if ([_notificationController shouldDisplayNotificationForConversation:conversation])
                {
                    NSMutableDictionary *peers = [[NSMutableDictionary alloc] init];
                    if (user != nil)
                        peers[@"author"] = user;
                    
                    if (message.mediaAttachments.count != 0)
                    {
                        NSMutableArray *peerIds = [[NSMutableArray alloc] init];
                        for (TGMediaAttachment *attachment in message.mediaAttachments)
                        {
                            if (attachment.type == TGActionMediaAttachmentType)
                            {
                                TGActionMediaAttachment *actionAttachment = (TGActionMediaAttachment *)attachment;
                                switch (actionAttachment.actionType)
                                {
                                    case TGMessageActionChatAddMember:
                                    case TGMessageActionChatDeleteMember:
                                    {
                                        if (actionAttachment.actionData[@"uids"] != nil) {
                                            [peerIds addObjectsFromArray:actionAttachment.actionData[@"uids"]];
                                        } else if (actionAttachment.actionData[@"uid"] != nil) {
                                            NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                                            [peerIds addObject:nUid];
                                        }
                                        break;
                                    }
                                    default:
                                        break;
                                }
                            }
                            else if (attachment.type == TGReplyMessageMediaAttachmentType)
                            {
                                TGReplyMessageMediaAttachment *replyAttachment = (TGReplyMessageMediaAttachment *)attachment;
                                if (replyAttachment.replyMessage.fromUid != 0)
                                    [peerIds addObject:@(replyAttachment.replyMessage.fromUid)];
                            }
                            else if (attachment.type == TGForwardedMessageMediaAttachmentType)
                            {
                                TGForwardedMessageMediaAttachment *forwardAttachment = (TGForwardedMessageMediaAttachment *)attachment;
                                if (forwardAttachment.forwardPeerId != 0)
                                    [peerIds addObject:@(forwardAttachment.forwardPeerId)];
                            }
                            else if (attachment.type == TGContactMediaAttachmentType)
                            {
                                TGContactMediaAttachment *contactAttachment = (TGContactMediaAttachment *)attachment;
                                if (contactAttachment.uid != 0)
                                    [peerIds addObject:@(contactAttachment.uid)];
                            }
                        }
                        
                        for (NSNumber *peerIdValue in peerIds)
                        {
                            int64_t peerId = peerIdValue.longLongValue;
                            if (TGPeerIdIsChannel(peerId))
                            {
                                TGConversation *channel = [TGDatabaseInstance() loadConversationWithId:peerId];
                                if (channel != nil)
                                    peers[@(channel.conversationId)] = channel;
                            }
                            else
                            {
                                TGUser *user = [TGDatabaseInstance() loadUser:(int32_t)peerId];
                                if (user != nil)
                                    peers[@(user.uid)] = user;
                            }
                        }
                    }
                    
                    int32_t replyToMid = (TGPeerIdIsGroup(message.cid) || TGPeerIdIsChannel(message.cid)) ? message.mid : 0;
                    [_notificationController displayNotificationForConversation:conversation identifier:message.mid replyToMid:replyToMid duration:5.0 configure:^(TGNotificationContentView *view, bool *isRepliable, TGBotReplyMarkup **replyMarkup)
                    {
                       *isRepliable = (!conversation.isChannel || conversation.isChannelGroup) && (conversation.encryptedData == nil);
                       *replyMarkup = conversation.conversationId == 777000 && message.replyMarkup.isInline ? message.replyMarkup : nil;
                        [view configureWithMessage:message conversation:conversation peers:peers];
                    }];
                }
            });
        }
    }];
}

- (void)dismissBannerForConversationId:(int64_t)conversationId
{
    [_notificationController dismissNotificationsForConversationId:conversationId];
}

- (void)dismissAllBanners
{
    [_notificationController dismissAllNotifications];
}

- (void)displayHashtagOverview:(NSString *)hashtag conversationId:(int64_t)conversationId
{
    if (hashtag == nil || hashtag.length < 2)
        return;
    
    TGRootController *rootController = TGAppDelegateInstance.rootController;
    if ([rootController.presentedViewController isKindOfClass:[TGHashtagOverviewController class]])
    {
        if ([((TGHashtagOverviewController *)rootController.presentedViewController).query isEqualToString:hashtag])
        {
            return;
        }
        else
        {
            [(TGHashtagOverviewController *)rootController.presentedViewController setQuery:hashtag peerId:conversationId];
            return;
        }
    }
    
    TGHashtagOverviewController *hashtagController = [[TGHashtagOverviewController alloc] initWithQuery:hashtag peerId:conversationId];
    [TGAppDelegateInstance.rootController presentViewController:hashtagController animated:true completion:nil];
}

- (void)localizationUpdated
{
    [_notificationController localizationUpdated];
}

- (void)setupCallManager:(TGCallManager *)callManager
{
    if (_incomingCallsDisposable != nil)
        return;
    
    __weak TGInterfaceManager *weakSelf = self;
    _incomingCallsDisposable = [[SMetaDisposable alloc] init];
    [_incomingCallsDisposable setDisposable:[[[callManager incomingCallInternalIds] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
    {
        __strong TGInterfaceManager *strongSelf = weakSelf;
        if (strongSelf == nil || ![next respondsToSelector:@selector(intValue)])
            return;
        
        [strongSelf presentCallWithSessionInitializer:^TGCallSession *{
            return [TGTelegraphInstance.callManager sessionForIncomingCallWithInternalId:next];
        } completion:nil];
    }]];
}

- (void)callPeerWithId:(int64_t)peerId
{
    [self callPeerWithId:peerId completion:nil];
}

- (void)callPeerWithId:(int64_t)peerId completion:(void (^)(void))completion
{
    if (peerId == 0)
        return;
    
    if (![[[LegacyComponentsGlobals provider] accessChecker] checkMicrophoneAuthorizationStatusForIntent:TGMicrophoneAccessIntentCall alertDismissCompletion:nil])
        return;
    
    [TGCallController requestMicrophoneAccess:^(bool granted)
    {
        if (!granted)
            return;
        
        TGCallController *currentCallController = nil;
        for (TGOverlayControllerWindow *window in TGAppDelegateInstance.rootController.associatedWindowStack)
        {
            if ([window.rootViewController isKindOfClass:[TGCallController class]])
            {
                TGCallController *callController = (TGCallController *)window.rootViewController;
                if (callController.peerId == peerId)
                {
                    [callController presentController];
                    return;
                }
                
                currentCallController = callController;
            }
        }
        
        void (^actionBlock)(void) = ^
        {
            [self presentCallWithSessionInitializer:^TGCallSession *{
                return [TGTelegraphInstance.callManager sessionForOutgoingCallWithPeerId:peerId];
            } completion:completion];
        };
        
        if (currentCallController != nil)
        {
            TGUser *newUser = [TGDatabaseInstance() loadUser:(int)peerId];
            NSString *message = [NSString stringWithFormat:TGLocalized(@"Call.CallInProgressMessage"), currentCallController.peer.displayName, newUser.displayName];
           
            [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Call.CallInProgressTitle") message:message cancelButtonTitle:TGLocalized(@"Common.No") okButtonTitle:TGLocalized(@"Common.Yes") completionBlock:^(bool okButtonPressed)
            {
                if (okButtonPressed)
                {
                    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
                    [currentCallController hangUpCallWithCompletion:^
                    {
                        actionBlock();
                        TGDispatchOnMainThread(^
                        {
                            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                        });
                    }];
                }
            }];
        }
        else
        {
            if ([TGCallUtils isOnPhoneCall])
            {
                [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Call.ConnectionErrorTitle") message:TGLocalized(@"Call.PhoneCallInProgressMessage") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
            }
            else
            {
                actionBlock();
            }
        }
    }];
}

- (void)dismissAllCalls
{
    for (TGOverlayControllerWindow *window in TGAppDelegateInstance.rootController.associatedWindowStack)
    {
        if ([window.rootViewController isKindOfClass:[TGCallController class]])
        {
            TGCallController *callController = (TGCallController *)window.rootViewController;
            [callController hangUpCall];
        }
    }
}

- (bool)hasCallControllerInForeground
{
    for (TGOverlayControllerWindow *window in TGAppDelegateInstance.rootController.associatedWindowStack)
    {
        if ([window.rootViewController isKindOfClass:[TGCallController class]])
            return !window.hidden;
    }
    
    return false;
}

- (void)presentCallWithSessionInitializer:(TGCallSession *(^)(void))sessionInitializer completion:(void (^)(void))completion
{
    if (TGTelegraphInstance.musicPlayer != nil)
        [TGTelegraphInstance.musicPlayer controlPause];
    
    
    TGNetworkType networkType = TGTelegraphInstance.networkTypeManager.networkType;
    
    for (UIWindow *window in [UIApplication sharedApplication].windows)
    {
        if ([window.rootViewController isKindOfClass:[TGCallAlertViewController class]])
        {
            if ([window isKindOfClass:[TGOverlayControllerWindow class]])
                [(TGOverlayControllerWindow *)window dismiss];
        }
    }
    
    if (networkType == TGNetworkTypeNone)
    {
        [TGCustomAlertView presentAlertWithTitle:TGLocalized(@"Call.ConnectionErrorTitle") message:TGLocalized(@"Call.ConnectionErrorMessage") cancelButtonTitle:TGLocalized(@"Common.OK") okButtonTitle:nil completionBlock:nil];
    }
    else
    {
        TGCallSession *session = sessionInitializer();
        if (session == nil)
            return;
        
        TGCallController *controller = [[TGCallController alloc] initWithSession:session];
        if (completion != nil)
        {
            controller.onTransitionIn = ^
            {
                completion();
            };
        }
        
        TGCallControllerWindow *controllerWindow = [[TGCallControllerWindow alloc] initWithManager:[[TGLegacyComponentsContext shared] makeOverlayWindowManager] parentController:TGAppDelegateInstance.rootController contentController:controller];
        controllerWindow.hidden = false;
        
        if (!TGIsPad())
        {
            CGSize screenSize = TGScreenSize();
            controllerWindow.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
        }
        
        TGCallStatusBarView *statusBarView = TGAppDelegateInstance.rootController.callStatusBarView;
        [statusBarView setSignal:controller.callDuration];
        
        __weak TGCallController *weakController = controller;
        statusBarView.statusBarPressed = ^
        {
            __strong TGCallController *strongController = weakController;
            if (strongController != nil)
                [strongController presentController];
        };
        
        _callControllerPipe.sink(@true);
    }
}

- (void)maybeDisplayCallsTabAlert
{
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"CallsTabBarInfo"]];
    [TGCallAlertView presentAlertWithTitle:TGLocalized(@"Calls.CallTabTitle") message:TGLocalized(@"Calls.CallTabDescription") customView:imageView cancelButtonTitle:TGLocalized(@"Calls.NotNow") doneButtonTitle:TGLocalized(@"Calls.AddTab") completionBlock:^(bool done)
    {
        TGAppDelegateInstance.showCallsTab = done;
        if (done)
            [TGAppDelegateInstance.rootController.mainTabsController setCallsHidden:false animated:true];
    }];
}

- (SSignal *)callControllerInForeground
{
    return _callControllerPipe.signalProducer();
}

- (void)dismissMusicPlayer
{
    for (UIViewController *controller in TGAppDelegateInstance.rootController.childViewControllers)
    {
        if ([controller isKindOfClass:[TGMusicPlayerController class]])
        {
            [(TGMusicPlayerController *)controller dismissAnimated:true];
            break;
        }
    }
}

- (SSignal *)messageVisibilitySignalWithConversationId:(int64_t)conversationId messageId:(int32_t)messageId peerId:(int64_t)peerId
{
    SSignal *initialConversationSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGModernConversationController *conversationController = nil;
        for (UIViewController *viewController in TGAppDelegateInstance.rootController.viewControllers)
        {
            if ([viewController isKindOfClass:[TGModernConversationController class]])
            {
                TGModernConversationController *existingConversationController = (TGModernConversationController *)viewController;
                id companion = existingConversationController.companion;
                if ([companion isKindOfClass:[TGGenericModernConversationCompanion class]])
                {
                    if (((TGGenericModernConversationCompanion *)companion).conversationId == conversationId)
                    {
                        conversationController = existingConversationController;
                        break;
                    }
                }
            }
        }
        if (conversationController.navigationController.viewControllers.lastObject != conversationController)
            conversationController = nil;
    
        [subscriber putNext:conversationController];
        [subscriber putCompletion];
        
        return nil;
    }];
    
    return [[[initialConversationSignal then:_conversationControllerPipe.signalProducer()] mapToSignal:^SSignal *(TGModernConversationController *controller)
    {
        if (controller != nil)
        {
            id companion = controller.companion;
            if ([companion isKindOfClass:[TGGenericModernConversationCompanion class]])
            {
                if (((TGGenericModernConversationCompanion *)companion).conversationId == conversationId)
                    return [controller messageVisiblitySignalForMessageId:messageId peerId:peerId];
            }
            return [SSignal single:@false];
        }
        else
        {
            return [SSignal single:@false];
        }
    }] deliverOn:[SQueue concurrentDefaultQueue]];
}

@end
