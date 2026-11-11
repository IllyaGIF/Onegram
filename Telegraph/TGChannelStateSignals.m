#import "TGChannelStateSignals.h"
#import "../OnegramRuntime/OGRuntime.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramPlatform/OGPlatformVersion.h"

#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGDatabase.h"
#import "TGTelegramNetworking.h"

#import "TL/TLMetaScheme.h"
#import "TLUpdates_ChannelDifference_manual.h"

#import "TGConversation+Telegraph.h"
#import "TGMessage+Telegraph.h"
#import "TGUserDataRequestBuilder.h"
#import "TGUpdateStateRequestBuilder.h"
#import "TGApplyUpdatesActor.h"
#import "TGTelegraph.h"

#import "TGDownloadMessagesSignal.h"
#import "TGConversationAddMessagesActor.h"

#import "TGChannelManagementSignals.h"

#import "TGModernSendCommonMessageActor.h"

#import "TGPreparedMessage.h"

#import "TLUpdate$updateChannelTooLong.h"
#import "TLchannelDifferenceTooLong.h"
#import "TGPollSignals.h"

@interface TGDatabase (OnegramChannelPreparation)
- (void)onegramPrepareChannelMessagesForInsertion:(NSArray *)messages;
- (void)onegramAddMessagesToChannelAndDispatchChunked:(int64_t)peerId messages:(NSArray *)messages deletedMessages:(NSArray *)deletedMessages holes:(NSArray *)holes pts:(int32_t)pts skipFeedUpdate:(bool)skipFeedUpdate completion:(dispatch_block_t)completion;
- (void)onegramAddTrailingHoleToChannelAndDispatch:(int64_t)peerId messages:(NSArray *)messages pts:(int32_t)pts importantUnreadCount:(int32_t)importantUnreadCount unimportantUnreadCount:(int32_t)unimportantUnreadCount unreadMentionsCount:(int32_t)unreadMentionsCount maxReadId:(int32_t)maxReadId topMessageId:(int32_t)topMessageId completion:(dispatch_block_t)completion;
@end

static const int32_t TGChannelDifferenceBackgroundLimit = 10;
static const int32_t TGChannelDifferenceOpenedLimit = 100;

static SQueue *OGChannelStateStorageQueue(void)
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [SQueue wrapConcurrentNativeQueue:OGRuntimeQueueForPriority(OGRuntimePriorityUserInitiated)];
    });
    return queue;
}

static SQueue *OGChannelStatePreparationQueue(void)
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [SQueue wrapConcurrentNativeQueue:OGRuntimeQueueForPriority(OGRuntimePriorityUserInitiated)];
    });
    return queue;
}

static SSignal *OGChannelStateDatabaseSignal(const char *file, int line, id (^block)(void))
{
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
#ifdef DEBUG_DATABASE_INVOKATIONS
        [TGDatabaseInstance() dispatchOnDatabaseThreadDebug:file line:line block:^
#else
        (void)file;
        (void)line;
        [TGDatabaseInstance() dispatchOnDatabaseThread:^
#endif
        {
            id result = block();
            [subscriber putNext:result];
            [subscriber putCompletion];
        } synchronous:false];
        return nil;
    }] startOn:OGChannelStateStorageQueue()];
}

static dispatch_block_t recursiveBlock(void (^block)(dispatch_block_t recurse)) {
    return ^ {
        block(recursiveBlock(block));
    };
}

static NSMutableDictionary *OGCompatChannelDiffSuppressions()
{
    static NSMutableDictionary *table = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        table = [[NSMutableDictionary alloc] init];
    });
    return table;
}

static NSString *OGCompatChannelDiffSuppressionKey(int64_t peerId, int64_t channelId, int64_t accessHash)
{
    return [NSString stringWithFormat:@"%lld:%lld:%lld", peerId, channelId, accessHash];
}

static NSNumber *OGCompatChannelDiffSuppressedUntil(NSString *key, NSTimeInterval now)
{
    NSMutableDictionary *table = OGCompatChannelDiffSuppressions();
    @synchronized(table)
    {
        NSNumber *until = table[key];
        if (until != nil && until.doubleValue <= now)
        {
            [table removeObjectForKey:key];
            return nil;
        }
        return until;
    }
}

static void OGCompatSuppressChannelDiff(NSString *key, NSTimeInterval duration)
{
    NSMutableDictionary *table = OGCompatChannelDiffSuppressions();
    @synchronized(table)
    {
        table[key] = @([[NSDate date] timeIntervalSince1970] + duration);
    }
}

static TLUpdates_ChannelDifference$empty *OGCompatEmptyChannelDifference(int32_t pts, int32_t flags, int32_t timeout)
{
    TLUpdates_ChannelDifference$empty *empty = [[TLUpdates_ChannelDifference$empty alloc] init];
    empty.pts = MAX(pts, 1);
    empty.flags = flags;
    empty.timeout = timeout;
    return empty;
}

static void OGCompatMarkInviterStored(int64_t peerId)
{
    uint8_t flag = 1;
    [TGDatabaseInstance() setConversationCustomProperty:peerId name:murMurHash32(@"inviterStored") value:[NSData dataWithBytes:&flag length:1]];
}

static NSString *const OGCompatMinAccessHashPropertyName = @"ios6MinChannelAccessHash";
static NSString *const OGCompatReactionSummaryPropertyName = @"ios6ReactionSummary";

static int64_t OGCompatStoredMinChannelAccessHash(int64_t peerId)
{
    NSData *stored = [TGDatabaseInstance() conversationCustomPropertySync:peerId name:murMurHash32(OGCompatMinAccessHashPropertyName)];
    if (stored.length != sizeof(int64_t))
        return 0;
    int64_t restored = 0;
    [stored getBytes:&restored length:sizeof(restored)];
    return restored;
}

static int64_t OGCompatPollAccessHash(int64_t peerId, TGConversation *conversation)
{
    TGConversation *fresh = [TGDatabaseInstance() loadChannels:@[@(peerId)]][@(peerId)];
    bool freshIsUsable = fresh != nil && fresh.accessHash != 0 && !fresh.isMin;
    int64_t accessHash = freshIsUsable ? fresh.accessHash : conversation.accessHash;
    bool isTrusted = freshIsUsable || (conversation.accessHash != 0 && !conversation.isMin);
    int64_t stored = OGCompatStoredMinChannelAccessHash(peerId);
    if (!isTrusted && stored != 0 && accessHash == 0)
        accessHash = stored;
    return accessHash;
}

static void OGCompatApplyReactionSummary(TGMessage *message, NSString *summary, NSString *chosenReaction)
{
    NSMutableDictionary *updatedProperties = [NSMutableDictionary dictionaryWithDictionary:message.contentProperties ?: @{}];
    if (summary.length != 0)
        [updatedProperties setObject:[[TGMessageReactionSummaryContentProperty alloc] initWithSummary:summary chosenReaction:chosenReaction] forKey:OGCompatReactionSummaryPropertyName];
    else
        [updatedProperties removeObjectForKey:OGCompatReactionSummaryPropertyName];
    message.contentProperties = updatedProperties;
}

static NSArray *OGCompatEditedMessageUpdates(NSArray *editedMessages, int64_t peerId, NSString *scope)
{
    NSMutableArray *updates = [[NSMutableArray alloc] initWithCapacity:editedMessages.count];
    for (TGMessage *message in editedMessages)
    {
        int64_t targetPeerId = message.cid == 0 ? peerId : message.cid;
        if (targetPeerId != peerId)
            TGLog(@"STATE %@.edit.peerMismatch peer=%lld msgPeer=%lld mid=%d", scope, peerId, message.cid, message.mid);
        [updates addObject:[[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:targetPeerId messageId:message.mid message:message dispatchEdited:true]];
    }
    return updates;
}

@class TGManagedChannelState;

@interface TGManagedChannelStateReference : NSObject
@property (nonatomic, weak) TGManagedChannelState *value;
@end

@implementation TGManagedChannelStateReference
@end

static TGManagedChannelState *OGCompatResolveManagedChannelState(TGManagedChannelStateReference *reference)
{
    if (reference == nil)
        return nil;
    @synchronized (reference)
    {
        return reference.value;
    }
}

@interface TGManagedChannelState : NSObject {
    int64_t _peerId;
    
    SPipe *_updatesPipe;
    SPipe *_pollsPipe;
    id<SDisposable> _disposable;
    SAtomic *_timer;
    
    SAtomic *_keepPollingBag;
    bool _recoveryPending;
    bool _pollActive;
    bool _pollAgain;
    OGRuntimeSyncActivity *_pollActivity;
    id<SDisposable> _inviterId;
    TGManagedChannelStateReference *_ogLifetimeReference;
}

- (void)requestPoll;
- (void)ensurePoll;
- (void)pollCycleCompleted;
- (bool)_hasPollKeepers;
- (void)_armPollTimerWithTimeout:(NSTimeInterval)timeout;

@end

@implementation TGManagedChannelState

- (instancetype)initWithPeerId:(int64_t)peerId {
    self = [super init];
    if (self != nil) {
        _ogLifetimeReference = [[TGManagedChannelStateReference alloc] init];
        _ogLifetimeReference.value = self;
        _peerId = peerId;
        
        _updatesPipe = [[SPipe alloc] init];
        _pollsPipe = [[SPipe alloc] init];
        
        _keepPollingBag = [[SAtomic alloc] initWithValue:[[SBag alloc] init]];
        
        TGManagedChannelStateReference *weakSelf = _ogLifetimeReference;
        
        SSignal *pollsSignal = [_pollsPipe.signalProducer() mapToQueue:^SSignal *(__unused id tick) {
            TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
            if (strongSelf != nil) {
                SSignal *pollSignal = nil;
                if (OGPlatformSupportsBackgroundVoipTransport() &&
                    [UIApplication sharedApplication].applicationState != UIApplicationStateActive &&
                    !strongSelf->_recoveryPending)
                {
                    pollSignal = [[SSignal single:@(120.0)] mapToSignal:^SSignal *(NSNumber *nextTimeout) {
                        TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
                        [strongSelf _armPollTimerWithTimeout:[nextTimeout doubleValue]];
                        return [SSignal complete];
                    }];
                } else {
                    bool channelOpened = [strongSelf _hasPollKeepers];
                    pollSignal = [[TGChannelStateSignals pollOnce:peerId limit:channelOpened ? TGChannelDifferenceOpenedLimit : TGChannelDifferenceBackgroundLimit] mapToSignal:^SSignal *(NSNumber *nextTimeout) {
                        TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
                        if (strongSelf != nil) {
                            NSTimeInterval timeout = [nextTimeout doubleValue];
                            strongSelf->_recoveryPending = timeout < 0.0;
                            [strongSelf _armPollTimerWithTimeout:ABS(timeout)];
                        }
                        return [SSignal complete];
                    }];
                }
                SSignal *trackedPollSignal = [pollSignal onCompletion:^{
                    TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
                    if (strongSelf != nil)
                        [strongSelf pollCycleCompleted];
                }];
                trackedPollSignal = [trackedPollSignal onError:^(__unused id error) {
                    TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
                    if (strongSelf != nil)
                        [strongSelf pollCycleCompleted];
                }];
                return trackedPollSignal;
            } else {
                return [SSignal complete];
            }
        }];
        
        SSignal *updatesSignal = [_updatesPipe.signalProducer() mapToSignal:^SSignal *(NSArray *updates) {
            TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
            if (strongSelf != nil) {
                return [[strongSelf applyUpdates:updates] catch:^SSignal *(__unused id error) {
                    TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
                    if (strongSelf != nil) {
                        strongSelf->_recoveryPending = true;
                        [strongSelf ensurePoll];
                    }
                    
                    return [SSignal complete];
                }];
            } else {
                return [SSignal complete];
            }
        }];
        SSignal *process = [[SSignal mergeSignals:@[updatesSignal, pollsSignal]] queue];
        
        _disposable = [process startWithNext:nil];
        
        _inviterId = [[[[[TGDatabaseInstance() existingChannel:peerId] filter:^bool(TGConversation *conversation) {
            return conversation.kind == TGConversationKindPersistentChannel;
        }] take:1] mapToSignal:^SSignal *(TGConversation *conversation) {
            return [TGChannelStateSignals addInviterMessage:peerId accessHash:conversation.accessHash];
        }] startWithNext:nil];
    }
    return self;
}

- (void)dealloc {
    @synchronized (_ogLifetimeReference) {
        _ogLifetimeReference.value = nil;
    }
    [_disposable dispose];
    STimer *timer = [_timer swap:nil];
    [timer invalidate];
    [_inviterId dispose];
}

+ (SSignal *)_channelDifference:(int64_t)peerId accessHash:(int64_t)accessHash pts:(int32_t)pts limit:(int32_t)limit {

    int64_t channelId = TGChannelIdFromPeerId(peerId);
    if (!channelId)
    {
        TGLog(@"AUTH skip state getChannelDifference peer=%lld channel=%lld accessHash=%lld pts=%d", peerId, channelId, accessHash, pts);
        return [SSignal single:OGCompatEmptyChannelDifference(pts, 1, 5)];
    }
    
    NSString *invalidChannelKey = OGCompatChannelDiffSuppressionKey(peerId, channelId, accessHash);
    NSTimeInterval now = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
    NSNumber *invalidUntil = OGCompatChannelDiffSuppressedUntil(invalidChannelKey, now);
    if (invalidUntil != nil)
    {
        TGLog(@"TRACE state getChannelDifference suppressed invalid peer=%lld channel=%lld hash=%lld until=%.0f", peerId, channelId, accessHash, invalidUntil.doubleValue);
        return [SSignal single:OGCompatEmptyChannelDifference(pts, 3, (int32_t)MAX(60, invalidUntil.doubleValue - now))];
    }
    
    TLRPCupdates_getChannelDifference$updates_getChannelDifference *getChannelDifference = [[TLRPCupdates_getChannelDifference$updates_getChannelDifference alloc] init];
    TLInputChannel$inputChannel *inputChannel = [[TLInputChannel$inputChannel alloc] init];
    inputChannel.channel_id = channelId;
    inputChannel.access_hash = accessHash;
    getChannelDifference.channel = inputChannel;
    getChannelDifference.filter = [[TLChannelMessagesFilter$channelMessagesFilterEmpty alloc] init];
    getChannelDifference.pts = MAX(pts, 1);
    getChannelDifference.limit = limit;
    
    
    SSignal *request = [[TGTelegramNetworking instance] requestSignal:getChannelDifference];
    if (OGDiagnosticsEnabled())
    {
        CFAbsoluteTime requestStart = CFAbsoluteTimeGetCurrent();
        request = [request onNext:^(id result) {
            NSUInteger messageCount = 0;
            NSUInteger updateCount = 0;
            if ([result isKindOfClass:[TLUpdates_ChannelDifference$channelDifference class]]) {
                messageCount = ((TLUpdates_ChannelDifference$channelDifference *)result).n_new_messages.count;
                updateCount = ((TLUpdates_ChannelDifference$channelDifference *)result).other_updates.count;
            } else if ([result isKindOfClass:[TLchannelDifferenceTooLong class]]) {
                messageCount = ((TLchannelDifferenceTooLong *)result).messages.count;
            }
            OGPlatformDiagnosticLog(@"SYNC channel peer=%lld limit=%d pts=%d class=%@ ms=%.0f messages=%u updates=%u", peerId, (int)limit, (int)pts, NSStringFromClass([result class]), (CFAbsoluteTimeGetCurrent() - requestStart) * 1000.0, (unsigned int)messageCount, (unsigned int)updateCount);
        }];
    }
    return [request catch:^SSignal *(id error) {
        TGLog(@"TRACE state getChannelDifference error peer=%lld channel=%lld hash=%lld error=%@", peerId, inputChannel.channel_id, inputChannel.access_hash, error);
        NSString *errorDescription = [[error description] uppercaseString];
        bool isPrivate = [errorDescription rangeOfString:@"CHANNEL_PRIVATE"].location != NSNotFound;
        bool isInvalid = [errorDescription rangeOfString:@"CHANNEL_INVALID"].location != NSNotFound || [errorDescription rangeOfString:@"PEER_ID_INVALID"].location != NSNotFound;
        if (isInvalid || isPrivate)
        {
            OGCompatSuppressChannelDiff(invalidChannelKey, isPrivate ? 60.0 : 3600.0);
            if (!isPrivate)
                [TGUpdateStateRequestBuilder requestDialogReconciliation];
        }
        return [SSignal fail:error];
    }];
}

- (SSignal *)applyUpdates:(NSArray *)updates {
    int64_t peerId = _peerId;
    
    return [[[TGDatabaseInstance() existingChannel:peerId] take:1] mapToSignal:^SSignal *(TGConversation *conversation) {
        NSMutableArray *ptsUpdates = [[NSMutableArray alloc] init];
        NSMutableSet *skipMessageIds = [[NSMutableSet alloc] init];
        NSMutableSet *readContentsMessageIds = [[NSMutableSet alloc] init];
        int32_t maxReadId = 0;
        int32_t maxReadOutgoingId = 0;
        NSNumber *pinnedMessageId = nil;
        __block bool pinnedMessagesChanged = false;
        __block bool failed = false;
        __block bool ptsGapDetected = false;
        bool hasMessageIdUpdates = false;
        int32_t maxAvailableMessageId = 0;
        
        for (id update in updates) {
            if ([update isKindOfClass:[TLUpdate$updateNewChannelMessage class]]) {
                [ptsUpdates addObject:update];
            } else if ([update isKindOfClass:[TLUpdate$updateEditChannelMessage class]]) {
                [ptsUpdates addObject:update];
            } else if ([update isKindOfClass:[TLUpdate$updateReadChannelInbox class]]) {
                maxReadId = MAX(maxReadId, ((TLUpdate$updateReadChannelInbox *)update).max_id);
            } else if ([update isKindOfClass:[TLUpdate$updateReadChannelOutbox class]]) {
                maxReadOutgoingId = MAX(maxReadOutgoingId, ((TLUpdate$updateReadChannelOutbox *)update).max_id);
            } else if ([update isKindOfClass:[TLUpdate$updateDeleteChannelMessages class]]) {
                [ptsUpdates addObject:update];
            } else if ([update isKindOfClass:[TLUpdate$updateChannelWebPage class]]) {
                [ptsUpdates addObject:update];
            } else if ([update isKindOfClass:[TLUpdate$updatePinnedChannelMessagesCodex class]]) {
                [ptsUpdates addObject:update];
            } else if ([update isKindOfClass:[TLUpdate$updateChannelTooLong class]]) {
                failed = true;
            } else if ([update isKindOfClass:[TLUpdate$updateMessageID class]]) {
                hasMessageIdUpdates = true;
            } else if ([update isKindOfClass:[TLUpdate$updateChannelPinnedMessage class]]) {
                pinnedMessageId = @(((TLUpdate$updateChannelPinnedMessage *)update).n_id);
            } else if ([update isKindOfClass:[TLUpdate$updateChannelReadMessagesContents class]]) {
                [readContentsMessageIds addObjectsFromArray:((TLUpdate$updateChannelReadMessagesContents *)update).messages];
            } else if ([update isKindOfClass:[TLUpdate$updateChannelAvailableMessages class]]) {
                maxAvailableMessageId = MAX(maxAvailableMessageId, ((TLUpdate$updateChannelAvailableMessages *)update).available_min_id + 1);
            }
        }
        
        SSignal *removeMessagesInProgressSignal = nil;
        
        if (hasMessageIdUpdates) {
            NSMutableDictionary *randomIdToMessageId = [[NSMutableDictionary alloc] init];
            
            for (id update in updates) {
                if ([update isKindOfClass:[TLUpdate$updateMessageID class]]) {
                    int64_t randomId = ((TLUpdate$updateMessageID *)update).random_id;
                    int32_t messageId = ((TLUpdate$updateMessageID *)update).n_id;
                    randomIdToMessageId[@(randomId)] = @(messageId);
                }
            }
            
            removeMessagesInProgressSignal = [[SSignal defer:^SSignal *{
                for (TGModernSendCommonMessageActor *actor in [ActionStageInstance() executingActorsWithPathPrefix:[[NSString alloc] initWithFormat:@"/tg/sendCommonMessage/(%" PRId64 ")/", peerId]]) {
                    if (actor.preparedMessage.randomId != 0) {
                        NSNumber *nMessageId = randomIdToMessageId[@(actor.preparedMessage.randomId)];
                        if (nMessageId != nil) {
                            [skipMessageIds addObject:nMessageId];
                        }
                    }
                }
                
                return [SSignal complete];
            }] startOn:[SQueue wrapConcurrentNativeQueue:[ActionStageInstance() globalStageDispatchQueue]]];
        } else {
            removeMessagesInProgressSignal = [SSignal complete];
        }
        
        return [removeMessagesInProgressSignal then:[SSignal defer:^SSignal *{
            int32_t updatedPts = conversation.pts;
            
            [ptsUpdates sortUsingComparator:^NSComparisonResult(id lhs, id rhs) {
                int32_t lhsPts = 0;
                int32_t rhsPts = 0;
                if ([lhs isKindOfClass:[TLUpdate$updateNewChannelMessage class]]) {
                    lhsPts = ((TLUpdate$updateNewChannelMessage *)lhs).pts;
                } else if ([lhs isKindOfClass:[TLUpdate$updateEditChannelMessage class]]) {
                    lhsPts = ((TLUpdate$updateEditChannelMessage *)lhs).pts;
                } else if ([lhs isKindOfClass:[TLUpdate$updateDeleteChannelMessages class]]) {
                    lhsPts = ((TLUpdate$updateDeleteChannelMessages *)lhs).pts;
                } else if ([lhs isKindOfClass:[TLUpdate$updateChannelWebPage class]]) {
                    lhsPts = ((TLUpdate$updateChannelWebPage *)lhs).pts;
                } else if ([lhs isKindOfClass:[TLUpdate$updatePinnedChannelMessagesCodex class]]) {
                    lhsPts = ((TLUpdate$updatePinnedChannelMessagesCodex *)lhs).pts;
                }
                if ([rhs isKindOfClass:[TLUpdate$updateNewChannelMessage class]]) {
                    rhsPts = ((TLUpdate$updateNewChannelMessage *)rhs).pts;
                }  else if ([rhs isKindOfClass:[TLUpdate$updateEditChannelMessage class]]) {
                    rhsPts = ((TLUpdate$updateEditChannelMessage *)rhs).pts;
                } else if ([rhs isKindOfClass:[TLUpdate$updateDeleteChannelMessages class]]) {
                    rhsPts = ((TLUpdate$updateDeleteChannelMessages *)rhs).pts;
                } else if ([rhs isKindOfClass:[TLUpdate$updateChannelWebPage class]]) {
                    rhsPts = ((TLUpdate$updateChannelWebPage *)rhs).pts;
                } else if ([rhs isKindOfClass:[TLUpdate$updatePinnedChannelMessagesCodex class]]) {
                    rhsPts = ((TLUpdate$updatePinnedChannelMessagesCodex *)rhs).pts;
                }
                return lhsPts < rhsPts ? NSOrderedAscending : NSOrderedDescending;
            }];
            
            NSMutableArray *addedMessages = [[NSMutableArray alloc] init];
            NSMutableArray *pendingNotificationDescriptions = [[NSMutableArray alloc] init];
            NSMutableArray *updatedMessages = [[NSMutableArray alloc] init];
            NSMutableArray *deletedMessageIds = [[NSMutableArray alloc] init];
            

            for (id update in ptsUpdates) {
                if ([update isKindOfClass:[TLUpdate$updateNewChannelMessage class]]) {
                    TLUpdate$updateNewChannelMessage *updateNewChannelMessage = update;
                    TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:updateNewChannelMessage.message];
                    message.pts = updateNewChannelMessage.pts;
                    
                    int32_t nextPts = updatedPts + updateNewChannelMessage.pts_count;
                    if (nextPts > updateNewChannelMessage.pts) {
                        continue;
                    }
                    else if (nextPts == updateNewChannelMessage.pts) {
                        if (message.mid != 0) {
                            if (![skipMessageIds containsObject:@(message.mid)]) {
                                [addedMessages addObject:message];
                                [pendingNotificationDescriptions addObject:updateNewChannelMessage.message];
                            }
                        }
                        updatedPts = updateNewChannelMessage.pts;
                    } else {
                        ptsGapDetected = true;
                        failed = true;
                    }
                } else if ([update isKindOfClass:[TLUpdate$updateEditChannelMessage class]]) {
                    TLUpdate$updateEditChannelMessage *updateEditMessage = update;
                    TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:updateEditMessage.message];
                    message.pts = updateEditMessage.pts;
                    
                    int32_t nextPts = updatedPts + updateEditMessage.pts_count;
                    if (nextPts > updateEditMessage.pts) {
                        continue;
                    }
                    else if (nextPts == updateEditMessage.pts) {
                        if (message.mid != 0) {
                            if (![skipMessageIds containsObject:@(message.mid)]) {
                                [updatedMessages addObject:message];
                            }
                        }
                        updatedPts = updateEditMessage.pts;
                    } else {
                        ptsGapDetected = true;
                        failed = true;
                    }
                } else if ([update isKindOfClass:[TLUpdate$updateDeleteChannelMessages class]]) {
                    TLUpdate$updateDeleteChannelMessages *updateDeleteChannelMessages = update;
                    
                    int32_t nextPts = updatedPts + updateDeleteChannelMessages.pts_count;
                    if (nextPts > updateDeleteChannelMessages.pts) {
                        continue;
                    } else if (nextPts == updateDeleteChannelMessages.pts) {
                        [deletedMessageIds addObjectsFromArray:updateDeleteChannelMessages.messages];
                        updatedPts = updateDeleteChannelMessages.pts;
                    } else {
                        ptsGapDetected = true;
                        failed = true;
                    }
                } else if ([update isKindOfClass:[TLUpdate$updateChannelWebPage class]]) {
                    TLUpdate$updateChannelWebPage *updateWebPage = (TLUpdate$updateChannelWebPage *)update;
                    
                    int32_t nextPts = updatedPts + updateWebPage.pts_count;
                    if (nextPts > updateWebPage.pts) {
                        continue;
                    } else if (nextPts == updateWebPage.pts) {
                        updatedPts = updateWebPage.pts;
                    } else {
                        ptsGapDetected = true;
                        failed = true;
                    }
                } else if ([update isKindOfClass:[TLUpdate$updatePinnedChannelMessagesCodex class]]) {
                    TLUpdate$updatePinnedChannelMessagesCodex *updatePinnedMessages = (TLUpdate$updatePinnedChannelMessagesCodex *)update;
                    int32_t nextPts = updatedPts + updatePinnedMessages.pts_count;
                    if (nextPts > updatePinnedMessages.pts) {
                        continue;
                    } else if (nextPts == updatePinnedMessages.pts) {
                        updatedPts = updatePinnedMessages.pts;
                        pinnedMessagesChanged = true;
                    } else {
                        ptsGapDetected = true;
                        failed = true;
                    }
                }
            }
            
            NSMutableArray *downloadMessages = [[NSMutableArray alloc] init];
            
            NSMutableDictionary *addedMessageIdToMessage = [[NSMutableDictionary alloc] init];
            for (TGMessage *message in addedMessages) {
                addedMessageIdToMessage[@(message.mid)] = message;
            }
            
            for (TGMessage *message in [addedMessages arrayByAddingObjectsFromArray:updatedMessages])
            {
                if (message.mediaAttachments.count != 0)
                {
                    for (id attachment in message.mediaAttachments)
                    {
                        if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
                        {
                            TGReplyMessageMediaAttachment *replyAttachment = attachment;
                            if (replyAttachment.replyMessage == nil && replyAttachment.replyMessageId != 0) {
                                TGMessage *replyMessage = addedMessageIdToMessage[@(replyAttachment.replyMessageId)];
                                if (replyMessage != nil) {
                                    replyAttachment.replyMessage = replyMessage;
                                } else {
                                    [downloadMessages addObject:[[TGDownloadMessage alloc] initWithPeerId:conversation.conversationId accessHash:conversation.accessHash messageId:replyAttachment.replyMessageId]];
                                }
                            }
                        }
                    }
                }
            }
            
            if (readContentsMessageIds.count != 0) {
                [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/readmessageContents", peerId] resource:@{@"messageIds": readContentsMessageIds}];
            }
            
            if (downloadMessages.count != 0) {
                return [[TGDownloadMessagesSignal downloadMessages:downloadMessages] mapToSignal:^SSignal *(NSArray *messages) {
                    return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
                        for (TGMessage *message in messages) {
                            addedMessageIdToMessage[@(message.mid)] = message;
                        }
                        
                        for (TGMessage *message in addedMessages)
                        {
                            if (message.mediaAttachments.count != 0)
                            {
                                for (id attachment in message.mediaAttachments)
                                {
                                    if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
                                    {
                                        TGReplyMessageMediaAttachment *replyAttachment = attachment;
                                        if (replyAttachment.replyMessage == nil && replyAttachment.replyMessageId != 0) {
                                            TGMessage *replyMessage = addedMessageIdToMessage[@(replyAttachment.replyMessageId)];
                                            if (replyMessage != nil) {
                                                replyAttachment.replyMessage = replyMessage;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        for (TGMessage *message in updatedMessages)
                        {
                            if (message.mediaAttachments.count != 0)
                            {
                                for (id attachment in message.mediaAttachments)
                                {
                                    if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
                                    {
                                        TGReplyMessageMediaAttachment *replyAttachment = attachment;
                                        if (replyAttachment.replyMessage == nil && replyAttachment.replyMessageId != 0) {
                                            TGMessage *replyMessage = addedMessageIdToMessage[@(replyAttachment.replyMessageId)];
                                            if (replyMessage != nil) {
                                                replyAttachment.replyMessage = replyMessage;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        NSMutableArray *messageUpdates = [[NSMutableArray alloc] init];
                        
                        if (readContentsMessageIds.count != 0) {
                            for (NSNumber *nMid in readContentsMessageIds) {
                                [messageUpdates addObject:[[TGDatabaseUpdateContentsRead alloc] initWithPeerId:peerId messageId:[nMid intValue]]];
                            }
                        }

                        [messageUpdates addObjectsFromArray:OGCompatEditedMessageUpdates(updatedMessages, peerId, @"channel")];
                        
                        if (messageUpdates.count != 0) {
                            [TGDatabaseInstance() transactionUpdateMessages:messageUpdates updateConversationDatas:nil];
                        }
                        
                        if (updatedPts != conversation.pts) {
                            [TGDatabaseInstance() addMessagesToChannelAndDispatch:peerId messages:addedMessages deletedMessages:deletedMessageIds holes:nil pts:updatedPts skipFeedUpdate:false];
                        }
                        
                        if (conversation.kind == TGConversationKindPersistentChannel && addedMessages.count != 0) {
                            [TGDatabaseInstance() _addedNewMessages:addedMessages];
                        }

                        [TGApplyUpdatesActor presentLocalNotificationsForMessageDescriptions:pendingNotificationDescriptions];
                        
                        if (maxReadId != 0) {
                            [TGDatabaseInstance() updateChannelRead:peerId maxReadId:maxReadId maxReadOutgoingId:0];
                        }
                        
                        if (maxReadOutgoingId != 0) {
                            [TGDatabaseInstance() transactionApplyMaxOutgoingReadIds:@{@(peerId): @(maxReadOutgoingId)}];
                        }
                        
                        if (pinnedMessageId != nil) {
                            if ([pinnedMessageId intValue] >= [TGDatabaseInstance() _channelCachedDataSync:peerId].minAvailableMessageId) {
                                [TGDatabaseInstance() updateChannelPinnedMessageId:peerId pinnedMessageId:[pinnedMessageId intValue] hidden:nil];
                            } else {
                                [TGDatabaseInstance() updateChannelPinnedMessageId:peerId pinnedMessageId:0 hidden:nil];
                            }
                        }
                        if (pinnedMessagesChanged)
                            [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", peerId] resource:@true];
                        
                        if (maxAvailableMessageId != 0) {
                            [TGDatabaseInstance() transactionAddMessages:nil notifyAddedMessages:false removeMessages:nil updateMessages:nil updatePeerDrafts:nil removeMessagesInteractive:nil keepDates:false removeMessagesInteractiveForEveryone:false updateConversationDatas:nil applyMaxIncomingReadIds:nil applyMaxOutgoingReadIds:nil applyMaxOutgoingReadDates:nil applyUnreadMarks:nil readHistoryForPeerIds:nil resetPeerReadStates:nil resetPeerUnseenMentionsStates:nil clearConversationsWithPeerIds:nil clearConversationsInteractive:false removeConversationsWithPeerIds:nil updatePinnedConversations:nil synchronizePinnedConversations:false forceReplacePinnedConversations:false readMessageContentsInteractive:nil deleteEarlierHistory:@{@(peerId): @(maxAvailableMessageId)} updateFeededChannels:nil newlyJoinedFeedId:nil synchronizeFeededChannels:false calculateUnreadChats:false];
                        }
                        
                        if (failed) {
                            if (ptsGapDetected)
                                [self requestPoll];
                            else
                                [self ensurePoll];
                            [TGDatabaseInstance() enqueueChannelPoll:peerId];
                            return [SSignal fail:nil];
                        } else {
                            return [SSignal complete];
                        }
                    }] switchToLatest];
                }];
            } else {
                NSMutableArray *messageUpdates = [[NSMutableArray alloc] init];
                
                if (readContentsMessageIds.count != 0) {
                    for (NSNumber *nMid in readContentsMessageIds) {
                        [messageUpdates addObject:[[TGDatabaseUpdateContentsRead alloc] initWithPeerId:peerId messageId:[nMid intValue]]];
                    }
                }
                
                [messageUpdates addObjectsFromArray:OGCompatEditedMessageUpdates(updatedMessages, peerId, @"channel")];
                if (messageUpdates.count != 0) {
                    [TGDatabaseInstance() transactionUpdateMessages:messageUpdates updateConversationDatas:nil];
                }
                
                if (updatedPts != conversation.pts) {
                    [TGDatabaseInstance() addMessagesToChannelAndDispatch:peerId messages:addedMessages deletedMessages:deletedMessageIds holes:nil pts:updatedPts skipFeedUpdate:false];
                }
                
                if (conversation.kind == TGConversationKindPersistentChannel && addedMessages.count != 0) {
                    [TGDatabaseInstance() _addedNewMessages:addedMessages];
                }

                [TGApplyUpdatesActor presentLocalNotificationsForMessageDescriptions:pendingNotificationDescriptions];
                
                if (maxReadId != 0) {
                    [TGDatabaseInstance() updateChannelRead:peerId maxReadId:maxReadId maxReadOutgoingId:0];
                }
                
                if (maxReadOutgoingId != 0) {
                    [TGDatabaseInstance() transactionApplyMaxOutgoingReadIds:@{@(peerId): @(maxReadOutgoingId)}];
                }
                
                if (pinnedMessageId != nil) {
                    if ([pinnedMessageId intValue] >= [TGDatabaseInstance() _channelCachedDataSync:peerId].minAvailableMessageId) {
                        [TGDatabaseInstance() updateChannelPinnedMessageId:peerId pinnedMessageId:[pinnedMessageId intValue] hidden:nil];
                    } else {
                        [TGDatabaseInstance() updateChannelPinnedMessageId:peerId pinnedMessageId:0 hidden:nil];
                    }
                }
                if (pinnedMessagesChanged)
                    [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", peerId] resource:@true];
                
                if (maxAvailableMessageId != 0) {
                    [TGDatabaseInstance() transactionAddMessages:nil notifyAddedMessages:false removeMessages:nil updateMessages:nil updatePeerDrafts:nil removeMessagesInteractive:nil keepDates:false removeMessagesInteractiveForEveryone:false updateConversationDatas:nil applyMaxIncomingReadIds:nil applyMaxOutgoingReadIds:nil applyMaxOutgoingReadDates:nil applyUnreadMarks:nil readHistoryForPeerIds:nil resetPeerReadStates:nil resetPeerUnseenMentionsStates:nil clearConversationsWithPeerIds:nil clearConversationsInteractive:false removeConversationsWithPeerIds:nil updatePinnedConversations:nil synchronizePinnedConversations:false forceReplacePinnedConversations:false readMessageContentsInteractive:nil deleteEarlierHistory:@{@(peerId): @(maxAvailableMessageId)} updateFeededChannels:nil newlyJoinedFeedId:nil synchronizeFeededChannels:false calculateUnreadChats:false];
                }
                
                if (failed) {
                    if (ptsGapDetected)
                        [self requestPoll];
                    else
                        [self ensurePoll];
                    [TGDatabaseInstance() enqueueChannelPoll:peerId];
                    return [SSignal fail:nil];
                } else {
                    return [SSignal complete];
                }
            }
        }]];
    }];
};

- (void)requestPoll {
    bool start = false;
    @synchronized(self) {
        if (_pollActive) {
            _pollAgain = true;
        } else {
            _pollActive = true;
            _pollActivity = [[OGRuntimeSyncActivity alloc] init];
            start = true;
        }
    }
    if (start)
        _pollsPipe.sink(@true);
}

- (void)ensurePoll {
    bool start = false;
    @synchronized(self) {
        if (!_pollActive) {
            _pollActive = true;
            _pollActivity = [[OGRuntimeSyncActivity alloc] init];
            start = true;
        }
    }
    if (start)
        _pollsPipe.sink(@true);
}

- (void)pollCycleCompleted {
    bool restart = false;
    OGRuntimeSyncActivity *completedActivity = nil;
    @synchronized(self) {
        if (_pollAgain) {
            _pollAgain = false;
            restart = true;
        } else {
            _pollActive = false;
            completedActivity = _pollActivity;
            _pollActivity = nil;
        }
    }
    [completedActivity end];
    if (restart)
        _pollsPipe.sink(@true);
}

- (void)addUpdates:(NSArray *)updates {
    _updatesPipe.sink(updates);
}

- (bool)_hasPollKeepers {
    return [[_keepPollingBag with:^id(SBag *bag) {
        return @(![bag isEmpty]);
    }] boolValue];
}

- (void)_armPollTimerWithTimeout:(NSTimeInterval)timeout {
    TGManagedChannelStateReference *weakSelf = _ogLifetimeReference;
    STimer *nextTimer = [[STimer alloc] initWithTimeout:timeout repeat:false completion:^{
        TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
        if (strongSelf != nil && (strongSelf->_recoveryPending || [strongSelf _hasPollKeepers]))
            [strongSelf ensurePoll];
    } queue:[SQueue concurrentDefaultQueue]];
    STimer *previousTimer = [_timer swap:nextTimer];
    [previousTimer invalidate];
    [nextTimer start];
}

- (void)resumePolling {
    bool shouldPoll = _recoveryPending || [self _hasPollKeepers];
    if (shouldPoll) {
        STimer *timer = [_timer swap:nil];
        [timer invalidate];
        [self ensurePoll];
    }
}

- (SSignal *)keepPolling {
    TGManagedChannelStateReference *weakSelf = _ogLifetimeReference;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(__unused SSubscriber *subscriber) {
        TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
        if (strongSelf != nil) {
            __block NSInteger index = -1;
            bool start = [[strongSelf->_keepPollingBag with:^id(SBag *bag) {
                bool shouldStart = [bag isEmpty];
                index = [bag addItem:@true];
                
                return @(shouldStart);
            }] boolValue];
            
            if (start) {
                [strongSelf ensurePoll];
            }
            
            return [[SBlockDisposable alloc] initWithBlock:^{
                TGManagedChannelState *strongSelf = OGCompatResolveManagedChannelState(weakSelf);
                if (strongSelf != nil) {
                    [strongSelf->_keepPollingBag with:^id(SBag *bag) {
                        [bag removeItem:index];
                        return nil;
                    }];
                }
            }];
        }
        
        return nil;
    }];
}

@end

@implementation TGChannelStateSignals

+ (SAtomic *)channelStates {
    static SAtomic *value = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        value = [[SAtomic alloc] initWithValue:[[NSMutableDictionary alloc] init]];
    });
    return value;
}

+ (void)clearChannelStates {
    [[self channelStates] swap:[[NSMutableDictionary alloc] init]];
}

+ (void)reloadForAccountSwitch {
    [self clearChannelStates];
    @synchronized(OGCompatChannelDiffSuppressions())
    {
        [OGCompatChannelDiffSuppressions() removeAllObjects];
    }
}

+ (void)resumeChannelStates {
    NSArray *states = [[self channelStates] with:^id(NSMutableDictionary *dict) {
        return [dict.allValues copy];
    }];
    for (TGManagedChannelState *state in states)
        [state resumePolling];
}

+ (void)requestChannelPoll:(int64_t)peerId {
    [[self channelState:peerId] ensurePoll];
}

+ (TGManagedChannelState *)channelState:(int64_t)peerId {
    return [[self channelStates] with:^id(NSMutableDictionary *dict) {
        TGManagedChannelState *state = dict[@(peerId)];
        if (state == nil) {
            state = [[TGManagedChannelState alloc] initWithPeerId:peerId];
            dict[@(peerId)] = state;
        }
        return state;
    }];
}

+ (SSignal *)addInviterMessage:(int64_t)peerId accessHash:(int64_t)accessHash {
    return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id {
        NSData *stored = [TGDatabaseInstance() conversationCustomPropertySync:peerId name:murMurHash32(@"inviterStored")];
        if (stored.length == 0) {
            TGConversation *conversation = [TGDatabaseInstance() loadChannels:@[@(peerId)]][@(peerId)];
            int64_t apiChannelId = TGChannelIdFromPeerId(peerId);
            bool modernLargeChannel = apiChannelId > INT32_MAX;
            if (accessHash == 0 || modernLargeChannel || (conversation != nil && !conversation.isChannelGroup)) {
                OGCompatMarkInviterStored(peerId);
                return @(true);
            }
            return @(false);
        } else {
            return @(true);
        }
    }] mapToSignal:^SSignal *(NSNumber *alreadyStored) {
        if ([alreadyStored boolValue]) {
            return [SSignal complete];
        } else {
            return [[[TGChannelManagementSignals channelInviterUser:peerId accessHash:accessHash] onNext:^(NSDictionary *dict) {
                [TGDatabaseInstance() dispatchOnDatabaseThread:^{
                    NSData *stored = [TGDatabaseInstance() conversationCustomPropertySync:peerId name:murMurHash32(@"inviterStored")];
                    if (stored.length == 0) {
                        if ([dict[@"userId"] longLongValue] != 0) {
                            TGMessage *message = [[TGMessage alloc] init];
                            message.mid = [[TGDatabaseInstance() generateLocalMids:1].firstObject intValue];
                            message.date = [dict[@"timestamp"] intValue];
                            TGActionMediaAttachment *attachment = [[TGActionMediaAttachment alloc] init];
                            attachment.actionType = TGMessageActionChannelInviter;
                            attachment.actionData = @{@"uid": dict[@"userId"]};
                            message.mediaAttachments = @[attachment];
                            message.sortKey = TGMessageSortKeyMake(peerId, TGMessageSpaceImportant, (int32_t)message.date, message.mid);
                            message.fromUid = TGTelegraphInstance.clientUserId;
                            message.toUid = peerId;
                            
                            [TGDatabaseInstance() addMessagesToChannelAndDispatch:peerId messages:@[message] deletedMessages:nil holes:nil pts:0 skipFeedUpdate:true];
                        }
                        
                        OGCompatMarkInviterStored(peerId);
                    }
                } synchronous:false];
            }] mapToSignal:^SSignal *(__unused id next) {
                return [SSignal complete];
            }];
        }
    }];
}

+ (SSignal *)validateMessageRanges:(int64_t)peerId pts:(int32_t)pts validPts:(int32_t)validPts messageRanges:(NSArray *)messageRanges {
    return [[[TGDatabaseInstance() existingChannel:peerId] take:1] mapToSignal:^SSignal *(TGConversation *conversation) {
        int64_t channelId = TGChannelIdFromPeerId(peerId);
        if (channelId == 0 || conversation.accessHash != 0)
        {
            return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
                [TGDatabaseInstance() updateMessageRangesPts:peerId messageRanges:messageRanges pts:validPts];
                return nil;
            }] mapToSignal:^SSignal *(__unused id next) {
                return [SSignal complete];
            }];
        }
        
        TLRPCupdates_getChannelDifference$updates_getChannelDifference *getChannelDifference = [[TLRPCupdates_getChannelDifference$updates_getChannelDifference alloc] init];
        TLChannelMessagesFilter$channelMessagesFilter *filter = [[TLChannelMessagesFilter$channelMessagesFilter alloc] init];
        filter.flags = 1 << 1;
        filter.ranges = messageRanges;
        getChannelDifference.filter = filter;
        getChannelDifference.pts = pts;
        getChannelDifference.limit = 1000;
        TLInputChannel$inputChannel *inputChannel = [[TLInputChannel$inputChannel alloc] init];
        inputChannel.channel_id = channelId;
        inputChannel.access_hash = conversation.accessHash;
        getChannelDifference.channel = inputChannel;
        
        return [[[TGTelegramNetworking instance] requestSignal:getChannelDifference] mapToSignal:^SSignal *(TLupdates_ChannelDifference *result) {
            NSMutableArray *deletedMessageIds = [[NSMutableArray alloc] init];
            
            if ([result isKindOfClass:[TLUpdates_ChannelDifference$channelDifference class]]) {
                for (id update in ((TLUpdates_ChannelDifference$channelDifference *)result).other_updates) {
                    if ([update isKindOfClass:[TLUpdate$updateDeleteChannelMessages class]]) {
                        [deletedMessageIds addObjectsFromArray:((TLUpdate$updateDeleteChannelMessages *)update).messages];
                    }
                }
            }
            
            return [[TGDatabaseInstance() modifyDebug:__FILE__ line:__LINE__ block:^id{
                if (deletedMessageIds.count != 0) {
                    [TGDatabaseInstance() addMessagesToChannel:peerId messages:nil deleteMessages:deletedMessageIds unimportantGroups:nil addedHoles:nil removedHoles:nil removedUnimportantHoles:nil updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:false skipFeedUpdate:false changedMessages:^(NSArray *addedMessages, NSArray *removedMessages, NSDictionary *updatedMessages, NSArray *addedUnimportantHoles, NSArray *removedUnimportantHoles) {
                        NSMutableArray *addedImportantMessages = [[NSMutableArray alloc] init];
                        NSMutableArray *addedUnimportantMessages = [[NSMutableArray alloc] init];
                        for (TGMessage *message in addedMessages) {
                            if (message.hole != nil) {
                                [addedImportantMessages addObject:message];
                                [addedUnimportantMessages addObject:message];
                            }
                            else if (message.group != nil) {
                                [addedImportantMessages addObject:message];
                            } else if (TGMessageSortKeySpace(message.sortKey) == TGMessageSpaceImportant) {
                                [addedImportantMessages addObject:message];
                                [addedUnimportantMessages addObject:message];
                            } else {
                                [addedUnimportantMessages addObject:message];
                            }
                        }
                        
                        [addedUnimportantMessages addObjectsFromArray:addedUnimportantHoles];
                        
                        NSMutableArray *removedImportantMessages = [[NSMutableArray alloc] init];
                        NSMutableArray *removedUnimportantMessages = [[NSMutableArray alloc] init];
                        
                        NSMutableDictionary *updatedImportantMessages = [[NSMutableDictionary alloc] init];
                        NSMutableDictionary *updatedUnimportantMessages = [[NSMutableDictionary alloc] init];
                        
                        [updatedImportantMessages addEntriesFromDictionary:updatedMessages];
                        [updatedUnimportantMessages addEntriesFromDictionary:updatedMessages];
                        
                        [removedImportantMessages addObjectsFromArray:removedMessages];
                        [removedUnimportantMessages addObjectsFromArray:removedMessages];
                        [removedUnimportantMessages addObjectsFromArray:removedUnimportantHoles];
                        
                        [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/importantMessages", peerId] resource:@{@"removed": removedImportantMessages, @"added": addedImportantMessages, @"updated": updatedImportantMessages}];
                        [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/unimportantMessages", peerId] resource:@{@"removed": removedUnimportantMessages, @"added": addedUnimportantMessages, @"updated": updatedUnimportantMessages}];
                    }];
                }
                
                [TGDatabaseInstance() updateMessageRangesPts:peerId messageRanges:messageRanges pts:validPts];
                
                return [SSignal complete];
            }] switchToLatest];
        }];
    }];
}

+ (SSignal *)pollOnce:(int64_t)peerId {
    return [self pollOnce:peerId limit:TGChannelDifferenceBackgroundLimit];
}

+ (SSignal *)pollOnce:(int64_t)peerId limit:(int32_t)limit {
    SSignal *poll = [self _pollOnce:peerId limit:limit];
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        OGRuntimeSyncActivity *activity = [[OGRuntimeSyncActivity alloc] init];
        id<SDisposable> disposable = [poll startWithNext:^(id next) {
            [subscriber putNext:next];
        } error:^(id error) {
            [activity end];
            [subscriber putError:error];
        } completed:^{
            [activity end];
            [subscriber putCompletion];
        }];
        return [[SBlockDisposable alloc] initWithBlock:^{
            [activity end];
            [disposable dispose];
        }];
    }];
}

+ (SSignal *)_pollOnce:(int64_t)peerId limit:(int32_t)limit {
    return [[[TGDatabaseInstance() existingChannel:peerId] take:1] mapToSignal:^SSignal *(TGConversation *conversation) {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
            SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
            
            void (^start)() = recursiveBlock(^(dispatch_block_t recurse) {
                [TGDatabaseInstance() channelPts:peerId completion:^(int32_t pts) {                    
                    int64_t accessHash = OGCompatPollAccessHash(peerId, conversation);
                    [disposable setDisposable:[[TGManagedChannelState _channelDifference:peerId accessHash:accessHash pts:pts limit:limit] startWithNext:^(TLupdates_ChannelDifference *result) {
                        OGRuntimeDispatch(OGRuntimePriorityUserInitiated, ^
                        {
                            CFAbsoluteTime processStart = CFAbsoluteTimeGetCurrent();
                            NSMutableArray *messages = [[NSMutableArray alloc] init];
                            NSMutableArray *updatedMessages = [[NSMutableArray alloc] init];
                            NSMutableArray *deletedMessageIds = [[NSMutableArray alloc] init];
                            
                            NSMutableArray *conversations = [[NSMutableArray alloc] init];
                            bool restart = false;
                            NSTimeInterval nextTimeout = 5.0;
                            bool pinnedMessagesChangedInDifference = false;
                            
                            NSArray *users = nil;
                            void (^addHole)() = nil;
                            void (^addMessages)(dispatch_block_t completion) = nil;
                            void (^loadHoles)() = nil;
                            
                            SSignal *removeMessagesInProgressSignal = [SSignal complete];
                            NSMutableSet *skipMessageIds = [[NSMutableSet alloc] init];
                            
                            if ([result isKindOfClass:[TLUpdates_ChannelDifference$empty class]]) {
                                TLUpdates_ChannelDifference$empty *concreteDifference = (TLUpdates_ChannelDifference$empty *)result;
                                if (!(concreteDifference.flags & (1 << 0)))
                                    restart = true;
                                if (concreteDifference.flags & (1 << 1))
                                    nextTimeout = concreteDifference.timeout;
                                addMessages = ^(dispatch_block_t completion) {
                                    [TGDatabaseInstance() updateHistoryPtsForPeerId:peerId pts:concreteDifference.pts];
                                    if (completion != nil)
                                        completion();
                                };
                            } else if ([result isKindOfClass:[TLchannelDifferenceTooLong class]]) {
                                TLchannelDifferenceTooLong *concreteDifference = (TLchannelDifferenceTooLong *)result;
                                if (!(concreteDifference.flags & (1 << 0)))
                                    restart = true;
                                if (concreteDifference.flags & (1 << 1))
                                    nextTimeout = concreteDifference.timeout;
                                
                                id replyPreload = [TGMessage beginReplyPreloadForTelegraphMessageDescs:concreteDifference.messages];
                                for (id messageDesc in concreteDifference.messages) {
                                    TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:messageDesc];
                                    message.pts = concreteDifference.pts;
                                    if (message.mid != 0) {
                                        [messages addObject:message];
                                    }
                                }
                                [TGMessage endReplyPreload:replyPreload];
                                
                                for (id chatDesc in concreteDifference.chats) {
                                    TGConversation *updatedConversation = [[TGConversation alloc] initWithTelegraphChatDesc:chatDesc];
                                    if (updatedConversation.conversationId == 0)
                                        continue;
                                    [conversations addObject:updatedConversation];
                                }
                                
                                users = concreteDifference.users;

                                addMessages = ^(dispatch_block_t completion) {
                                    [TGDatabaseInstance() onegramAddTrailingHoleToChannelAndDispatch:peerId messages:messages pts:concreteDifference.pts importantUnreadCount:concreteDifference.unread_count unimportantUnreadCount:0 unreadMentionsCount:concreteDifference.unread_mentions_count maxReadId:concreteDifference.read_inbox_max_id topMessageId:concreteDifference.top_message completion:^{
                                        [TGDatabaseInstance() updateHistoryPtsForPeerId:peerId pts:concreteDifference.pts];
                                        if (completion != nil)
                                            completion();
                                    }];
                                };

                                if (concreteDifference.unread_count != 0) {
                                    loadHoles = ^{
                                        SDisposableSet *metaDisposable = [[SDisposableSet alloc] init];
                                        [TGTelegraphInstance.disposeOnLogout add:metaDisposable];
                                        id<SDisposable> disposable = [[[[TGChannelManagementSignals preloadedHistoryForPeerId:peerId accessHash:conversation.accessHash aroundMessageId:concreteDifference.read_inbox_max_id] deliverOn:OGChannelStatePreparationQueue()] mapToSignal:^SSignal *(NSDictionary *dict) {
                                            if (OGPlatformUsesConstrainedBackgroundExecution())
                                                [TGDatabaseInstance() onegramPrepareChannelMessagesForInsertion:dict[@"messages"]];
                                            return [OGChannelStateDatabaseSignal(__FILE__, __LINE__, ^id {
                                                NSArray *removedImportantHoles = nil;
                                                NSArray *removedUnimportantHoles = nil;
                                                
                                                removedImportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
                                                removedUnimportantHoles = dict[@"hole"] == nil ? nil : @[dict[@"hole"]];
                                                
                                                [TGDatabaseInstance() addMessagesToChannel:peerId messages:dict[@"messages"] deleteMessages:nil unimportantGroups:dict[@"unimportantGroups"] addedHoles:nil removedHoles:removedImportantHoles removedUnimportantHoles:removedUnimportantHoles updatedMessageSortKeys:nil returnGroups:false keepUnreadCounters:false skipFeedUpdate:true changedMessages:^(NSArray *addedMessages, NSArray *removedMessages, NSDictionary *updatedMessages, NSArray *addedUnimportantHoles, NSArray *removedUnimportantHoles) {
                                                    NSMutableArray *addedImportantMessages = [[NSMutableArray alloc] init];
                                                    NSMutableArray *addedUnimportantMessages = [[NSMutableArray alloc] init];
                                                    for (TGMessage *message in addedMessages) {
                                                        if (message.hole != nil) {
                                                            [addedImportantMessages addObject:message];
                                                            [addedUnimportantMessages addObject:message];
                                                        }
                                                        else if (message.group != nil) {
                                                            [addedImportantMessages addObject:message];
                                                        } else if (TGMessageSortKeySpace(message.sortKey) == TGMessageSpaceImportant) {
                                                            [addedImportantMessages addObject:message];
                                                            [addedUnimportantMessages addObject:message];
                                                        } else {
                                                            [addedUnimportantMessages addObject:message];
                                                        }
                                                    }
                                                    
                                                    [addedUnimportantMessages addObjectsFromArray:addedUnimportantHoles];
                                                    
                                                    NSMutableArray *removedImportantMessages = [[NSMutableArray alloc] init];
                                                    NSMutableArray *removedUnimportantMessages = [[NSMutableArray alloc] init];
                                                    
                                                    NSMutableDictionary *updatedImportantMessages = [[NSMutableDictionary alloc] init];
                                                    NSMutableDictionary *updatedUnimportantMessages = [[NSMutableDictionary alloc] init];
                                                    
                                                    [updatedImportantMessages addEntriesFromDictionary:updatedMessages];
                                                    [updatedUnimportantMessages addEntriesFromDictionary:updatedMessages];
                                                    
                                                    [removedImportantMessages addObjectsFromArray:removedMessages];
                                                    [removedUnimportantMessages addObjectsFromArray:removedMessages];
                                                    [removedUnimportantMessages addObjectsFromArray:removedUnimportantHoles];
                                                    
                                                    [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/importantMessages", peerId] resource:@{@"removed": removedImportantMessages, @"added": addedImportantMessages, @"updated": updatedImportantMessages}];
                                                    [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/unimportantMessages", peerId] resource:@{@"removed": removedUnimportantMessages, @"added": addedUnimportantMessages, @"updated": updatedUnimportantMessages}];
                                                }];
                                                
                                                return [SSignal complete];
                                            }) switchToLatest];
                                        }] startWithNext:nil error:^(__unused id error) {
                                            [TGTelegraphInstance.disposeOnLogout remove:metaDisposable];
                                            [metaDisposable dispose];
                                        } completed:^{
                                            [TGTelegraphInstance.disposeOnLogout remove:metaDisposable];
                                            [metaDisposable dispose];
                                        }];
                                        [metaDisposable add:disposable];
                                    };
                                }
                            } else if ([result isKindOfClass:[TLUpdates_ChannelDifference$channelDifference class]]) {
                                TLUpdates_ChannelDifference$channelDifference *concreteDifference = (TLUpdates_ChannelDifference$channelDifference *)result;
                                if (!(concreteDifference.flags & (1 << 0)))
                                    restart = true;
                                if (concreteDifference.flags & (1 << 1))
                                    nextTimeout = concreteDifference.timeout;
                                
                                bool hasMessageIdUpdates = false;
                                
                                id replyPreload = [TGMessage beginReplyPreloadForTelegraphMessageDescs:concreteDifference.n_new_messages];
                                for (id messageDesc in concreteDifference.n_new_messages) {
                                    TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:messageDesc];
                                    message.pts = concreteDifference.pts;
                                    if (message.mid != 0 && message.cid == peerId) {
                                        [messages addObject:message];
                                    }
                                }
                                [TGMessage endReplyPreload:replyPreload];
                                
                                for (id update in concreteDifference.other_updates) {
                                    if ([update isKindOfClass:[TLUpdate$updateDeleteChannelMessages class]]) {
                                        [deletedMessageIds addObjectsFromArray:((TLUpdate$updateDeleteChannelMessages *)update).messages];
                                    } else if ([update isKindOfClass:[TLUpdate$updateMessageID class]]) {
                                        hasMessageIdUpdates = true;
                                    } else if ([update isKindOfClass:[TLUpdate$updateEditChannelMessage class]]) {
                                        TLUpdate$updateEditChannelMessage *updateEditMessage = update;
                                        TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:updateEditMessage.message];
                                        message.pts = updateEditMessage.pts;
                                        
                                        [updatedMessages addObject:message];
                                    } else if ([update isKindOfClass:[TLUpdate$updatePinnedChannelMessagesCodex class]]) {
                                        pinnedMessagesChangedInDifference = true;
                                    } else if ([update isKindOfClass:[TLUpdate$updateMessageReactionsSummary class]]) {
                                        TLUpdate$updateMessageReactionsSummary *reactionUpdate = update;
                                        TGMessage *message = [TGDatabaseInstance() loadMessageWithMid:reactionUpdate.msg_id peerId:peerId];
                                        if (message != nil) {
                                            OGCompatApplyReactionSummary(message, reactionUpdate.reactionSummary, reactionUpdate.chosenReaction);
                                            [updatedMessages addObject:message];
                                        }
                                    }
                                }
                                
                                NSMutableArray *pollUpdates = [[NSMutableArray alloc] init];
                                for (id update in concreteDifference.other_updates) {
                                    if ([update isKindOfClass:[TLUpdate$updateMessagePollCodex class]])
                                        [pollUpdates addObject:update];
                                }
                                if (pollUpdates.count != 0)
                                    [updatedMessages addObjectsFromArray:[TGPollSignals messagesByApplyingPollUpdates:pollUpdates baseMessages:updatedMessages]];
                                
                                for (id channelDesc in concreteDifference.chats) {
                                    TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:channelDesc];
                                    if (conversation.conversationId != 0) {
                                        [conversations addObject:conversation];
                                    }
                                }
                                
                                SSignal *removeMessagesInProgressSignal = nil;
                                
                                if (hasMessageIdUpdates || true) {
                                    NSMutableDictionary *randomIdToMessageId = [[NSMutableDictionary alloc] init];
                                    
                                    for (id update in concreteDifference.other_updates) {
                                        if ([update isKindOfClass:[TLUpdate$updateMessageID class]]) {
                                            int64_t randomId = ((TLUpdate$updateMessageID *)update).random_id;
                                            int32_t messageId = ((TLUpdate$updateMessageID *)update).n_id;
                                            randomIdToMessageId[@(randomId)] = @(messageId);
                                        }
                                    }
                                    
                                    removeMessagesInProgressSignal = [[SSignal defer:^SSignal *{
                                        for (TGModernSendCommonMessageActor *actor in [ActionStageInstance() executingActorsWithPathPrefix:[[NSString alloc] initWithFormat:@"/tg/sendCommonMessage/(%" PRId64 ")/", peerId]]) {
                                            if (actor.preparedMessage.randomId != 0) {
                                                NSNumber *nMessageId = randomIdToMessageId[@(actor.preparedMessage.randomId)];
                                                if (nMessageId != nil) {
                                                    [skipMessageIds addObject:nMessageId];
                                                }
                                            }
                                        }
                                        
                                        return [SSignal complete];
                                    }] startOn:[SQueue wrapConcurrentNativeQueue:[ActionStageInstance() globalStageDispatchQueue]]];
                                }
                                
                                users = concreteDifference.users;
                                
                                addMessages = ^(dispatch_block_t completion) {
                                    [TGDatabaseInstance() onegramAddMessagesToChannelAndDispatchChunked:peerId messages:messages deletedMessages:deletedMessageIds holes:nil pts:concreteDifference.pts skipFeedUpdate:false completion:^{
                                        if (updatedMessages.count != 0) {
                                            NSArray *messageUpdates = OGCompatEditedMessageUpdates(updatedMessages, peerId, @"diff");
                                            [TGDatabaseInstance() transactionUpdateMessages:messageUpdates updateConversationDatas:nil];
                                        }
                                        if (completion != nil)
                                            completion();
                                    }];
                                };
                            }
                            
                            NSMutableArray *downloadMessages = [[NSMutableArray alloc] init];
                            
                            NSMutableDictionary *addedMessageIdToMessage = [[NSMutableDictionary alloc] init];
                            for (TGMessage *message in messages) {
                                addedMessageIdToMessage[@(message.mid)] = message;
                            }
                            
                            for (NSInteger i = 0; i < (NSInteger)messages.count; i++)
                            {
                                TGMessage *message = messages[i];
                                if ([skipMessageIds containsObject:@(message.mid)]) {
                                    [messages removeObjectAtIndex:i];
                                    i--;
                                } else {
                                    if (message.mediaAttachments.count != 0)
                                    {
                                        for (id attachment in message.mediaAttachments)
                                        {
                                            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
                                            {
                                                TGReplyMessageMediaAttachment *replyAttachment = attachment;
                                                if (replyAttachment.replyMessage == nil && replyAttachment.replyMessageId != 0) {
                                                    TGMessage *replyMessage = addedMessageIdToMessage[@(replyAttachment.replyMessageId)];
                                                    if (replyMessage != nil) {
                                                        replyAttachment.replyMessage = replyMessage;
                                                    } else {
                                                        [downloadMessages addObject:[[TGDownloadMessage alloc] initWithPeerId:conversation.conversationId accessHash:conversation.accessHash messageId:replyAttachment.replyMessageId]];
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            [disposable setDisposable:[[[[removeMessagesInProgressSignal then:[TGDownloadMessagesSignal downloadMessages:downloadMessages]] deliverOn:OGChannelStatePreparationQueue()] mapToSignal:^SSignal *(NSArray *updatedMessages) {
                                for (TGMessage *message in updatedMessages) {
                                    addedMessageIdToMessage[@(message.mid)] = message;
                                }
                                    
                                for (TGMessage *message in messages)
                                {
                                    if (message.mediaAttachments.count != 0)
                                    {
                                        for (id attachment in message.mediaAttachments)
                                        {
                                            if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]])
                                            {
                                                TGReplyMessageMediaAttachment *replyAttachment = attachment;
                                                if (replyAttachment.replyMessage == nil && replyAttachment.replyMessageId != 0) {
                                                    TGMessage *replyMessage = addedMessageIdToMessage[@(replyAttachment.replyMessageId)];
                                                    if (replyMessage != nil) {
                                                        replyAttachment.replyMessage = replyMessage;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                    
                                if (OGPlatformUsesConstrainedBackgroundExecution())
                                    [TGDatabaseInstance() onegramPrepareChannelMessagesForInsertion:messages];

                                return OGChannelStateDatabaseSignal(__FILE__, __LINE__, ^id {
                                    [TGUserDataRequestBuilder executeUserDataUpdate:users];
                                    [TGDatabaseInstance() updateChannels:conversations];
                                    
                                    if (addHole) {
                                        addHole();
                                    }
                                    
                                    dispatch_block_t finish = ^{
                                        OGPlatformDiagnosticLog(@"SYNC channel.apply peer=%lld ms=%.0f messages=%u restart=%d", peerId, (CFAbsoluteTimeGetCurrent() - processStart) * 1000.0, (unsigned int)messages.count, restart ? 1 : 0);
                                        if (pinnedMessagesChangedInDifference)
                                            [ActionStageInstance() dispatchResource:[NSString stringWithFormat:@"/tg/conversation/(%lld)/pinnedMessagesChanged", peerId] resource:@true];

                                        if (loadHoles) {
                                            loadHoles();
                                        }
                                    
                                        if (restart) {
                                            if (OGPlatformUsesConstrainedBackgroundExecution())
                                                OGRuntimeDispatchAfter(OGRuntimePriorityUserInitiated, 0.10, recurse);
                                            else
                                                recurse();
                                        } else {
                                            [TGDatabaseInstance() confirmPeerPoll:[[TGQueuedPeerPoll alloc] initWithPeerId:peerId feedPosition:nil]];
                                            [subscriber putNext:@(nextTimeout)];
                                            [subscriber putCompletion];
                                        }
                                    };

                                    if (addMessages != nil)
                                        addMessages(finish);
                                    else
                                        finish();
                                    
                                    return nil;
                                });
                            }] startWithNext:nil]];
                        });
                    } error:^(__unused id error) {
                        [subscriber putNext:@(-5.0)];
                        [subscriber putCompletion];
                    } completed:nil]];
                }];
            });
            
            start();
            
            return disposable;
        }];
    }];
}

+ (void)addChannelUpdates:(int64_t)peerId updates:(NSArray *)updates {
    [[self channelState:peerId] addUpdates:updates];
}

+ (SSignal *)updatedChannel:(int64_t)peerId {
    return [[self channelState:peerId] keepPolling];
}

@end
