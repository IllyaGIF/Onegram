#import "TGApplyUpdatesActor.h"
#include <inttypes.h>
#import "../OnegramPlatform/OGPlatformUIKit.h"
#import "../OnegramPlatform/OGPlatformVersion.h"
#import "../OnegramPlatform/OGPlatformDispatch.h"
#import "../OnegramRuntime/OGRuntime.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTimer.h"

#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"
#import "../submodules/LegacyComponents/LegacyComponents/SGraphObjectNode.h"

#import "TGDatabase.h"
#import "TGTelegraph.h"
#import "TGTelegramNetworking.h"
#import "TGAppDelegate.h"

#import "TGUser+Telegraph.h"
#import "TGMessage+Telegraph.h"
#import "TGConversation+Telegraph.h"
#import "TGUserDataRequestBuilder.h"

#import "TGUser+Telegraph.h"

#import "TGTimelineItem.h"

#import "TGConversationAddMessagesActor.h"
#import "TGApplyStateRequestBuilder.h"

#import "TGUpdateStateRequestBuilder.h"

#import "TGUpdate.h"
#import "TGDatabaseUpdateMessage.h"

#import "TLUpdate$updateChangePts.h"

#import "TGUpdatesWithSeq.h"
#import "TGUpdatesWithPts.h"
#import "TGUpdatesWithQts.h"
#import "TGUpdatesWithDate.h"

#import "TLMessage$modernMessage.h"
#import "TLMessage$modernMessageService.h"

#import "TLUser$modernUser.h"
#import "TLChat$channel.h"
#import "TLChat$channelForbidden.h"
#import "TLUpdates+TG.h"

#import "TLMessageFwdHeader$messageFwdHeader.h"

#import "TGCurrencyFormatter.h"

#import <set>
#import <map>
#import "../OnegramRuntime/OGRemoteClock.h"

@protocol TGSyntheticUpdateWithPts <NSObject>

- (int32_t)pts;
- (int32_t)pts_count;

@end

@protocol TGSyntheticUpdateWithQts <NSObject>

- (int32_t)qts;

@end

@interface TGWrappedUpdate : NSObject

@property (nonatomic, strong, readonly) id update;
@property (nonatomic, readonly) int32_t date;

@end

@implementation TGWrappedUpdate

- (instancetype)initWithUpdate:(id)update date:(int32_t)date
{
    self = [super init];
    if (self != nil)
    {
        _update = update;
        _date = date;
    }
    return self;
}

@end

static inline void maybeProcessUser(TLUser *user, std::map<int64_t, TLUser *> &processedUsers)
{
    if (((TLUser$modernUser *)user).n_id != 0)
        processedUsers[((TLUser$modernUser *)user).n_id] = user;
}

static inline void maybeProcessChat(TLChat *chat, std::map<int64_t, TLChat *> &processedChats)
{
    if (chat.n_id == 0)
        return;
    
    bool isChannel = [chat isKindOfClass:[TLChat$channel class]] || [chat isKindOfClass:[TLChat$channelForbidden class]];
    processedChats[isChannel ? TGPeerIdFromChannelId(chat.n_id) : TGPeerIdFromGroupId(chat.n_id)] = chat;
}

static NSString *const OGCompatReactionSummaryKey = @"ios6ReactionSummary";
static NSString *const OGCompatAggregateFlagKey = @"ios6Aggregate";

static int64_t OGCompatPeerIdOfPeer(TLPeer *peer)
{
    int64_t resolved = 0;
    if ([peer isKindOfClass:[TLPeer$peerChannel class]])
        resolved = TGPeerIdFromChannelId(((TLPeer$peerChannel *)peer).channel_id);
    else if ([peer isKindOfClass:[TLPeer$peerChat class]])
        resolved = TGPeerIdFromGroupId(((TLPeer$peerChat *)peer).chat_id);
    else if ([peer isKindOfClass:[TLPeer$peerUser class]])
        resolved = ((TLPeer$peerUser *)peer).user_id;
    return resolved;
}

static int64_t OGCompatReadMarkPeerId(TLPeer *peer)
{
    if ([peer isKindOfClass:[TLPeer$peerChat class]])
        return -((TLPeer$peerChat *)peer).chat_id;
    return OGCompatPeerIdOfPeer(peer);
}

static NSString *OGCompatChatTitleForPeer(int64_t peerId)
{
    TGConversation *cached = [TGDatabaseInstance() loadConversationWithIdCached:peerId];
    return cached != nil ? cached.chatTitle : [TGDatabaseInstance() loadConversationWithId:peerId].chatTitle;
}

static void OGCompatApplyReactionSummary(TGMessage *message, NSString *summary, NSString *chosenReaction)
{
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] initWithDictionary:message.contentProperties ?: @{}];
    if (summary.length > 0)
        properties[OGCompatReactionSummaryKey] = [[TGMessageReactionSummaryContentProperty alloc] initWithSummary:summary chosenReaction:chosenReaction];
    else
        [properties removeObjectForKey:OGCompatReactionSummaryKey];
    message.contentProperties = properties;
}

static NSMutableArray *delayedNotifications()
{
    static NSMutableArray *array = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        array = [[NSMutableArray alloc] init];
    });
    return array;
}

static bool OGCompatTakeNotificationSlot()
{
    static CFAbsoluteTime windowOpenedAt = 0.0;
    static NSUInteger slotsTaken = 0;

    CFAbsoluteTime current = CFAbsoluteTimeGetCurrent();
    bool windowExpired = windowOpenedAt == 0.0 || current - windowOpenedAt >= 10.0;
    if (windowExpired)
    {
        windowOpenedAt = current;
        slotsTaken = 0;
    }

    bool hasFreeSlot = slotsTaken < 5;
    if (hasFreeSlot)
        slotsTaken++;
    return hasFreeSlot;
}

static NSString *OGCompatAggregateNotificationText(NSUInteger count)
{
    static NSDictionary *templates = nil;
    static NSArray *prefixOrder = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        templates = @{@"ru": @"%lu новых сообщений", @"uk": @"%lu нових повідомлень", @"de": @"%lu neue Nachrichten"};
        prefixOrder = @[@"ru", @"uk", @"de"];
    });

    NSArray *languages = [NSLocale preferredLanguages];
    NSString *language = languages.count == 0 ? @"en" : languages[0];
    NSString *format = @"%lu new messages";
    for (NSString *prefix in prefixOrder)
    {
        if ([language hasPrefix:prefix])
        {
            format = templates[prefix];
            break;
        }
    }
    return [NSString stringWithFormat:format, (unsigned long)count];
}

static bool OGCompatIsHighSurrogate(unichar ch)
{
    return ch >= 0xd800 && ch <= 0xdbff;
}

static bool OGCompatIsLowSurrogate(unichar ch)
{
    return ch >= 0xdc00 && ch <= 0xdfff;
}

static bool OGCompatIsNotificationSpace(unichar ch)
{
    return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r';
}

static bool OGCompatIsUnprintableUnit(unichar ch)
{
    return ch < 0x20 || (ch >= 0x7f && ch <= 0x9f) ||
        (ch >= 0x200b && ch <= 0x200f) || (ch >= 0x202a && ch <= 0x202e) || (ch >= 0x2060 && ch <= 0x206f) ||
        ch == 0xfffc || ch == 0xfffe || ch == 0xffff || ch == 0xfeff;
}

static NSString *OGCompatFlattenNotificationText(NSString *text, NSUInteger limit, bool *cutShort)
{
    NSMutableString *flat = [[NSMutableString alloc] initWithCapacity:MIN(text.length, limit)];
    bool afterSpace = false;

    NSUInteger position = 0;
    while (position < text.length)
    {
        unichar unit = [text characterAtIndex:position];
        NSUInteger span = 1;
        bool skip = false;
        bool collapsible = false;

        if (OGCompatIsHighSurrogate(unit))
        {
            bool paired = position + 1 < text.length && OGCompatIsLowSurrogate([text characterAtIndex:position + 1]);
            if (paired)
                span = 2;
            else
                skip = true;
        }
        else if (OGCompatIsLowSurrogate(unit))
            skip = true;
        else if (OGCompatIsNotificationSpace(unit))
            collapsible = true;
        else if (OGCompatIsUnprintableUnit(unit))
            skip = true;

        if (skip)
        {
            position++;
            continue;
        }

        if (collapsible)
        {
            if (!afterSpace && flat.length != 0)
                [flat appendString:@" "];
            afterSpace = true;
            position++;
            continue;
        }

        if (flat.length + span > limit - 1)
        {
            *cutShort = true;
            break;
        }

        [flat appendString:[text substringWithRange:NSMakeRange(position, span)]];
        afterSpace = false;
        position += span;
    }

    return flat;
}

@interface TGApplyUpdatesActor ()

@property (nonatomic, strong) NSMutableArray *updateList;

@property (nonatomic) bool waitingForApplyUpdates;
@property (nonatomic, strong) NSMutableArray *waitingForApplyUpdatesQueue;

@property (nonatomic, strong) TGTimer *timeoutTimer;
@property (nonatomic) NSTimeInterval overallTimeout;

@property (nonatomic) NSMutableSet *notifiedGroups;

+ (void)applyDelayedNotificationsInApplicationState:(UIApplicationState)applicationState maxMid:(int)maxMid mids:(NSArray *)mids midsWithoutSound:(NSSet *)midsWithoutSound maxQts:(int)maxQts randomIds:(NSArray *)randomIds;

@end

@implementation TGApplyUpdatesActor

+ (NSString *)genericPath
{
    return @"/tg/service/tryupdates/@";
}

+ (void)clearState
{
    [TGApplyUpdatesActor clearDelayedNotifications];
}

+ (void)clearDelayedNotifications
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [delayedNotifications() removeAllObjects];
    }];
}

+ (NSString *)og_compat_sanitizedNotificationText:(NSString *)text
{
    if (![text isKindOfClass:[NSString class]])
        return nil;
    if (text.length == 0)
        return nil;

    const NSUInteger characterLimit = 160;
    bool cutShort = false;
    NSString *flattened = OGCompatFlattenNotificationText(text, characterLimit, &cutShort);

    NSString *trimmed = [flattened stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0)
        return nil;
    bool needsEllipsis = cutShort || text.length > characterLimit;
    return needsEllipsis ? [trimmed stringByAppendingString:@"\u2026"] : trimmed;
}

+ (void)presentSafeLocalNotification:(UILocalNotification *)notification text:(NSString *)text
{
    if (notification == nil)
        return;
    if (!OGBackgroundNotificationsEnabled())
        return;

    NSString *safeText = [self og_compat_sanitizedNotificationText:text];
    if (safeText.length == 0)
        return;

    static CFAbsoluteTime lastPresentationTime = 0.0;
    static CFAbsoluteTime lastSoundTime = 0.0;
    static CFAbsoluteTime aggregateBlockUntil = 0.0;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime presentationTime = now;
    NSDictionary *notificationUserInfo = OGPlatformLocalNotificationUserInfo(notification);
    bool isAggregate = [[notificationUserInfo objectForKey:OGCompatAggregateFlagKey] boolValue];

    @synchronized(self)
    {
        if (now < aggregateBlockUntil)
        {
            OGPlatformDiagnosticLog(@"NOTIFY coalesced into aggregate");
            return;
        }

        if (lastPresentationTime != 0.0)
            presentationTime = MAX(now, lastPresentationTime + 1.0);
        lastPresentationTime = presentationTime;
        aggregateBlockUntil = isAggregate ? presentationTime + 10.0 : aggregateBlockUntil;

        NSString *soundName = OGPlatformLocalNotificationSoundName(notification);
        if (soundName.length != 0)
        {
            if (lastSoundTime != 0.0 && presentationTime - lastSoundTime < 3.0)
                OGPlatformSetLocalNotificationSoundName(notification, nil);
            else
                lastSoundTime = presentationTime;
        }
    }

    OGPlatformSetLocalNotificationAlertBody(notification, safeText);
    bool deferred = presentationTime > now;
    if (deferred)
        OGPlatformSetLocalNotificationFireDate(notification, [NSDate dateWithTimeIntervalSinceReferenceDate:presentationTime]);
    OGPlatformDiagnosticLog(@"NOTIFY present delay=%.1f aggregate=%d", presentationTime - now, isAggregate ? 1 : 0);

    dispatch_async(dispatch_get_main_queue(), ^
    {
        UIApplication *application = [UIApplication sharedApplication];
        if (application.applicationState == UIApplicationStateActive)
            return;
        if (deferred)
            OGPlatformScheduleLocalNotification(application, notification);
        else
            OGPlatformPresentLocalNotificationNow(application, notification);
    });
}

+ (bool)claimNotificationForPeerId:(int64_t)peerId messageId:(int32_t)messageId
{
    return [self claimNotificationForPeerId:peerId messageId:messageId accountId:TGTelegraphInstance.clientUserId];
}

+ (bool)claimNotificationForPeerId:(int64_t)peerId messageId:(int32_t)messageId accountId:(int64_t)accountId
{
    if (peerId == 0 || messageId == 0)
        return false;
    static NSMutableSet *recentKeys = nil;
    static NSMutableArray *recentOrder = nil;
    @synchronized(self)
    {
        if (recentKeys == nil)
        {
            recentKeys = [[NSMutableSet alloc] init];
            recentOrder = [[NSMutableArray alloc] init];
        }
        NSString *key = [NSString stringWithFormat:@"%lld:%lld:%d", accountId, peerId, messageId];
        if ([recentKeys containsObject:key])
            return false;
        [recentKeys addObject:key];
        [recentOrder addObject:key];
        while (recentOrder.count > 256)
        {
            [recentKeys removeObject:recentOrder[0]];
            [recentOrder removeObjectAtIndex:0];
        }
        return true;
    }
}

+ (void)presentLocalNotificationsForMessageDescriptions:(NSArray *)messageDescriptions
{
    if (messageDescriptions.count == 0 || !OGBackgroundNotificationsEnabled())
        return;

    NSArray *descriptions = [messageDescriptions copy];
    TGDispatchOnMainThread(^
    {
        UIApplicationState applicationState = [UIApplication sharedApplication].applicationState;
        if (applicationState == UIApplicationStateActive)
            return;

        [ActionStageInstance() dispatchOnStageQueue:^
        {
            NSMutableArray *accepted = [[NSMutableArray alloc] init];
            NSMutableArray *mids = [[NSMutableArray alloc] init];
            NSMutableSet *midsWithoutSound = [[NSMutableSet alloc] init];
            int32_t maxMid = 0;

            for (id candidate in descriptions)
            {
                if ([candidate isKindOfClass:[TLMessage class]] == false)
                    continue;

                TGMessage *message = [[TGMessage alloc] initWithTelegraphMessageDesc:candidate];
                if (message.mid == 0 || message.cid == 0 || message.outgoing || message.cid == TGTelegraphInstance.clientUserId || message.fromUid == TGTelegraphInstance.clientUserId) {
                    continue;
                }

                TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:message.cid];
                if (TGPeerIdIsChannel(message.cid) && !conversation.isChannelMember)
                    continue;

                if (message.mid <= MAX(conversation.maxReadMessageId, conversation.maxLocallyReadMessageId)) {
                    continue;
                }

                if (![self claimNotificationForPeerId:message.cid messageId:message.mid]) {
                    continue;
                }

                NSNumber *midNumber = @(message.mid);
                [accepted addObject:candidate];
                [mids addObject:midNumber];
                if (message.isSilent)
                    [midsWithoutSound addObject:midNumber];
                maxMid = MAX(maxMid, message.mid);
            }

            OGPlatformDiagnosticLog(@"NOTIFY candidates=%d accepted=%d", (int)descriptions.count, (int)accepted.count);

            if (accepted.count > 0)
            {
                [delayedNotifications() addObjectsFromArray:accepted];
                [TGApplyUpdatesActor applyDelayedNotificationsInApplicationState:applicationState maxMid:maxMid mids:mids midsWithoutSound:midsWithoutSound maxQts:0 randomIds:nil];
            }
        }];
    });
}

- (id)initWithPath:(NSString *)path
{
    self = [super initWithPath:path];
    if (self != nil)
    {
        _updateList = [[NSMutableArray alloc] init];
        _waitingForApplyUpdatesQueue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self cancelTimeoutTimer];
}

- (void)prepare:(NSDictionary *)__unused options
{
    bool messagesQueue = false;
    
    if ([self.path isEqualToString:@"/tg/service/tryupdates/(withPts)"])
        messagesQueue = true;
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withSeq)"])
        messagesQueue = true;
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withQts)"])
        messagesQueue = true;
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withDate)"])
        messagesQueue = true;
    else
        NSAssert(false, ([NSString stringWithFormat:@"Invalid actor path %@", self.path]));
    
    if (messagesQueue)
        self.requestQueueName = @"messages";
}

- (void)execute:(NSDictionary *)options
{
    if ([TGDatabaseInstance() databaseError] != nil && ![TGDatabaseInstance() isDatabaseAvailable])
    {
        [ActionStageInstance() actionFailed:self.path reason:-1];
        return;
    }

    
    [_updateList addObjectsFromArray:[options objectForKey:@"updates"]];
    
    if ([self.path isEqualToString:@"/tg/service/tryupdates/(withPts)"])
        [self checkPtsUpdates];
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withSeq)"])
        [self checkSeqUpdates];
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withQts)"])
        [self checkQtsUpdates];
    else
        [self checkDateUpdates];
}

- (void)completeAction
{
    [ActionStageInstance() actionCompleted:self.path result:nil];
}

- (void)checkDateUpdates
{
    if (_waitingForApplyUpdates)
        return;

    if (_updateList.count == 0)
    {
        [self completeAction];
        return;
    }

    NSArray *pendingDateUpdates = [_updateList copy];
    [_updateList removeAllObjects];

    NSArray *sortedDateUpdates = [pendingDateUpdates sortedArrayUsingComparator:^NSComparisonResult(TGUpdatesWithDate *updates1, TGUpdatesWithDate *updates2)
    {
        if (updates1.date == updates2.date)
            return NSOrderedSame;
        return updates1.date < updates2.date ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *users = [[NSMutableArray alloc] init];
    NSMutableArray *chats = [[NSMutableArray alloc] init];
    NSMutableArray *wrappedUpdates = [[NSMutableArray alloc] init];

    for (TGUpdatesWithDate *updates in sortedDateUpdates)
    {
        for (id update in updates.updates)
            [wrappedUpdates addObject:[[TGWrappedUpdate alloc] initWithUpdate:update date:updates.date]];
        if (updates.users != nil)
            [users addObjectsFromArray:updates.users];
        if (updates.chats != nil)
            [chats addObjectsFromArray:updates.chats];
    }

    int32_t finalDate = ((TGUpdatesWithDate *)sortedDateUpdates.lastObject).date;
    TGDatabaseState databaseState = [[TGDatabase instance] databaseState];
    if (wrappedUpdates.count == 0 && users.count == 0 && chats.count == 0)
    {
        if (finalDate > databaseState.date)
            [[TGDatabase instance] applyPts:0 date:finalDate seq:0 qts:0 unreadCount:-1];
        [self checkDateUpdates];
        return;
    }

    [self _tryApplyingUpdates:wrappedUpdates users:users chats:chats optionalFinalSeq:0 optionalFinalDate:finalDate completion:^(bool success)
    {
        if (success)
        {
            [self checkDateUpdates];
        }
        else
        {
            [TGTelegraphInstance stateUpdateRequired];
            [self completeAction];
        }
    }];
}

- (void)watcherJoined:(ASHandle *)watcherHandle options:(NSDictionary *)options waitingInActorQueue:(bool)waitingInActorQueue
{
    
    if (_waitingForApplyUpdates)
        [_waitingForApplyUpdatesQueue addObjectsFromArray:[options objectForKey:@"updates"]];
    else
        [_updateList addObjectsFromArray:[options objectForKey:@"updates"]];
    
    if ([self.path isEqualToString:@"/tg/service/tryupdates/(withPts)"])
    {
        if (!waitingInActorQueue && !_waitingForApplyUpdates)
            [self checkPtsUpdates];
    }
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withSeq)"])
    {
        if (!waitingInActorQueue && !_waitingForApplyUpdates)
            [self checkSeqUpdates];
    }
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withQts)"])
    {
        if (!waitingInActorQueue && !_waitingForApplyUpdates)
            [self checkQtsUpdates];
    }
    else if (!waitingInActorQueue && !_waitingForApplyUpdates)
    {
        [self checkDateUpdates];
    }
    
    [super watcherJoined:watcherHandle options:options waitingInActorQueue:waitingInActorQueue];
}

- (void)cancelTimeoutTimer
{
    if (_timeoutTimer != nil)
    {
        [_timeoutTimer invalidate];
        _timeoutTimer = nil;
    }
}

- (void)startTimeoutTimer
{
    if (_timeoutTimer != nil)
        return;
    
    __weak TGApplyUpdatesActor *weakSelf = self;
    NSTimeInterval timeout = 0.5;
    _timeoutTimer = [[TGTimer alloc] initWithTimeout:timeout repeat:false completion:^
    {
        __strong TGApplyUpdatesActor *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_timeoutTimer = nil;
            [strongSelf timeoutReached];
        }
    } queue:[ActionStageInstance() globalStageDispatchQueue]];
    [_timeoutTimer start];
}

- (void)timeoutReached
{
    if ([self.path isEqualToString:@"/tg/service/tryupdates/(withPts)"])
        [self _failPts];
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withSeq)"])
        [self _failSeq];
    else if ([self.path isEqualToString:@"/tg/service/tryupdates/(withQts)"])
        [self _failQts];
}

- (void)checkPtsUpdates
{
    if (_updateList.count == 0)
    {
        [self cancelTimeoutTimer];
        [self completeAction];
        return;
    }

    NSMutableArray *ptsUpdates = [[NSMutableArray alloc] init];
    for (TGUpdatesWithPts *updates in _updateList)
        [ptsUpdates addObjectsFromArray:updates.updates];

    [ptsUpdates sortUsingComparator:^NSComparisonResult(id<TGSyntheticUpdateWithPts> update1, id<TGSyntheticUpdateWithPts> update2)
    {
        if ([update1 pts] == [update2 pts])
        {
            if ([update1 pts_count] == [update2 pts_count])
                return NSOrderedSame;
            return [update1 pts_count] > [update2 pts_count] ? NSOrderedAscending : NSOrderedDescending;
        }
        return [update1 pts] < [update2 pts] ? NSOrderedAscending : NSOrderedDescending;
    }];

    int32_t currentPts = [[TGDatabase instance] databaseState].pts;
    NSMutableArray *inOrderUpdates = [[NSMutableArray alloc] init];
    NSMutableArray *expiredUpdates = [[NSMutableArray alloc] init];

    for (id<TGSyntheticUpdateWithPts> update in ptsUpdates)
    {
        int32_t nextPts = currentPts + [update pts_count];
        if (nextPts == [update pts])
        {
            [inOrderUpdates addObject:update];
            currentPts = [update pts];
        }
        else if (nextPts > [update pts])
        {
            [expiredUpdates addObject:update];
        }
        else
        {
            TGLog(@"***** Missing updates: %d + %d != %d", (int)currentPts, (int)[update pts_count], (int)[update pts]);
            [self startTimeoutTimer];
            break;
        }
    }

    if (expiredUpdates.count != 0)
    {
        NSArray *groups = [_updateList copy];
        for (TGUpdatesWithPts *updates in groups)
        {
            NSMutableArray *filteredUpdates = [[NSMutableArray alloc] initWithArray:updates.updates];
            [filteredUpdates removeObjectsInArray:expiredUpdates];
            if (filteredUpdates.count != updates.updates.count)
            {
                NSUInteger index = [_updateList indexOfObjectIdenticalTo:updates];
                if (index != NSNotFound)
                {
                    if (filteredUpdates.count == 0)
                        [_updateList removeObjectAtIndex:index];
                    else
                        _updateList[index] = [[TGUpdatesWithPts alloc] initWithUpdates:filteredUpdates users:updates.users chats:updates.chats];
                }
            }
        }
    }

    if (inOrderUpdates.count != 0)
    {
        NSMutableArray *users = [[NSMutableArray alloc] init];
        NSMutableArray *chats = [[NSMutableArray alloc] init];
        NSArray *groups = [_updateList copy];
        for (TGUpdatesWithPts *updates in groups)
        {
            NSMutableArray *filteredUpdates = [[NSMutableArray alloc] initWithArray:updates.updates];
            [filteredUpdates removeObjectsInArray:inOrderUpdates];
            if (filteredUpdates.count != updates.updates.count)
            {
                if (updates.users != nil)
                    [users addObjectsFromArray:updates.users];
                if (updates.chats != nil)
                    [chats addObjectsFromArray:updates.chats];
                NSUInteger index = [_updateList indexOfObjectIdenticalTo:updates];
                if (index != NSNotFound)
                {
                    if (filteredUpdates.count == 0)
                        [_updateList removeObjectAtIndex:index];
                    else
                        _updateList[index] = [[TGUpdatesWithPts alloc] initWithUpdates:filteredUpdates users:updates.users chats:updates.chats];
                }
            }
        }

        NSMutableArray *wrappedUpdates = [[NSMutableArray alloc] init];
        for (id update in inOrderUpdates)
            [wrappedUpdates addObject:[[TGWrappedUpdate alloc] initWithUpdate:update date:0]];

        [self _tryApplyingUpdates:wrappedUpdates users:users chats:chats optionalFinalSeq:0 optionalFinalDate:0 completion:^(bool success)
        {
            if (!success)
                [self _failPts];
            else
                [self checkPtsUpdates];
        }];
    }
    else if (_updateList.count == 0)
    {
        [self cancelTimeoutTimer];
        [self completeAction];
    }
}

- (void)checkQtsUpdates
{
    if (_updateList.count == 0)
    {
        [self cancelTimeoutTimer];
        [self completeAction];
        return;
    }

    NSMutableArray *qtsUpdates = [[NSMutableArray alloc] init];
    for (TGUpdatesWithQts *updates in _updateList)
        [qtsUpdates addObjectsFromArray:updates.updates];

    [qtsUpdates sortUsingComparator:^NSComparisonResult(id<TGSyntheticUpdateWithQts> update1, id<TGSyntheticUpdateWithQts> update2)
    {
        if ([update1 qts] == [update2 qts])
            return NSOrderedSame;
        return [update1 qts] < [update2 qts] ? NSOrderedAscending : NSOrderedDescending;
    }];

    int32_t currentQts = [[TGDatabase instance] databaseState].qts;
    NSMutableArray *inOrderUpdates = [[NSMutableArray alloc] init];
    NSMutableArray *expiredUpdates = [[NSMutableArray alloc] init];

    for (id<TGSyntheticUpdateWithQts> update in qtsUpdates)
    {
        int32_t nextQts = currentQts + 1;
        if (nextQts == [update qts])
        {
            [inOrderUpdates addObject:update];
            currentQts = [update qts];
        }
        else if (nextQts > [update qts])
        {
            [expiredUpdates addObject:update];
        }
        else
        {
            TGLog(@"***** Missing updates: qts %d + 1 != %d", (int)currentQts, (int)[update qts]);
            [self startTimeoutTimer];
            break;
        }
    }

    if (expiredUpdates.count != 0)
    {
        NSArray *groups = [_updateList copy];
        for (TGUpdatesWithQts *updates in groups)
        {
            NSMutableArray *filteredUpdates = [[NSMutableArray alloc] initWithArray:updates.updates];
            [filteredUpdates removeObjectsInArray:expiredUpdates];
            if (filteredUpdates.count != updates.updates.count)
            {
                NSUInteger index = [_updateList indexOfObjectIdenticalTo:updates];
                if (index != NSNotFound)
                {
                    if (filteredUpdates.count == 0)
                        [_updateList removeObjectAtIndex:index];
                    else
                        _updateList[index] = [[TGUpdatesWithQts alloc] initWithUpdates:filteredUpdates users:updates.users chats:updates.chats];
                }
            }
        }
    }

    if (inOrderUpdates.count != 0)
    {
        NSMutableArray *users = [[NSMutableArray alloc] init];
        NSMutableArray *chats = [[NSMutableArray alloc] init];
        NSArray *groups = [_updateList copy];
        for (TGUpdatesWithQts *updates in groups)
        {
            NSMutableArray *filteredUpdates = [[NSMutableArray alloc] initWithArray:updates.updates];
            [filteredUpdates removeObjectsInArray:inOrderUpdates];
            if (filteredUpdates.count != updates.updates.count)
            {
                if (updates.users != nil)
                    [users addObjectsFromArray:updates.users];
                if (updates.chats != nil)
                    [chats addObjectsFromArray:updates.chats];
                NSUInteger index = [_updateList indexOfObjectIdenticalTo:updates];
                if (index != NSNotFound)
                {
                    if (filteredUpdates.count == 0)
                        [_updateList removeObjectAtIndex:index];
                    else
                        _updateList[index] = [[TGUpdatesWithQts alloc] initWithUpdates:filteredUpdates users:updates.users chats:updates.chats];
                }
            }
        }

        NSMutableArray *wrappedUpdates = [[NSMutableArray alloc] init];
        for (id update in inOrderUpdates)
            [wrappedUpdates addObject:[[TGWrappedUpdate alloc] initWithUpdate:update date:0]];

        [self _tryApplyingUpdates:wrappedUpdates users:users chats:chats optionalFinalSeq:0 optionalFinalDate:0 completion:^(bool success)
        {
            if (!success)
                [self _failQts];
            else
                [self checkQtsUpdates];
        }];
    }
    else if (_updateList.count == 0)
    {
        [self cancelTimeoutTimer];
        [self completeAction];
    }
}

- (void)checkSeqUpdates
{
    if (_updateList.count == 0)
    {
        [self cancelTimeoutTimer];
        [self completeAction];
        return;
    }

    NSArray *seqUpdates = [_updateList sortedArrayUsingComparator:^NSComparisonResult(TGUpdatesWithSeq *updates1, TGUpdatesWithSeq *updates2)
    {
        if (updates1.seqStart == updates2.seqStart)
        {
            if (updates1.seqEnd == updates2.seqEnd)
                return NSOrderedSame;
            return updates1.seqEnd < updates2.seqEnd ? NSOrderedAscending : NSOrderedDescending;
        }
        return updates1.seqStart < updates2.seqStart ? NSOrderedAscending : NSOrderedDescending;
    }];

    int32_t currentSeq = [[TGDatabase instance] databaseState].seq;
    NSMutableArray *inOrderUpdates = [[NSMutableArray alloc] init];
    NSMutableArray *expiredUpdates = [[NSMutableArray alloc] init];

    for (TGUpdatesWithSeq *updates in seqUpdates)
    {
        if (updates.seqStart <= currentSeq)
        {
            [expiredUpdates addObject:updates];
        }
        else if (updates.seqStart == currentSeq + 1)
        {
            [inOrderUpdates addObject:updates];
            currentSeq = updates.seqEnd;
        }
        else
        {
            TGLog(@"***** Missing updates: seq %d", (int)currentSeq + 1);
            [self startTimeoutTimer];
            break;
        }
    }

    if (expiredUpdates.count != 0)
        [_updateList removeObjectsInArray:expiredUpdates];

    if (inOrderUpdates.count != 0)
    {
        NSMutableArray *wrappedUpdates = [[NSMutableArray alloc] init];
        NSMutableArray *users = [[NSMutableArray alloc] init];
        NSMutableArray *chats = [[NSMutableArray alloc] init];

        for (TGUpdatesWithSeq *updates in inOrderUpdates)
        {
            for (id update in updates.updates)
                [wrappedUpdates addObject:[[TGWrappedUpdate alloc] initWithUpdate:update date:updates.date]];
            if (updates.users != nil)
                [users addObjectsFromArray:updates.users];
            if (updates.chats != nil)
                [chats addObjectsFromArray:updates.chats];
            [_updateList removeObject:updates];
        }

        TGUpdatesWithSeq *finalUpdates = (TGUpdatesWithSeq *)inOrderUpdates.lastObject;
        [self _tryApplyingUpdates:wrappedUpdates users:users chats:chats optionalFinalSeq:finalUpdates.seqEnd optionalFinalDate:finalUpdates.date completion:^(bool success)
        {
            if (!success)
                [self _failSeq];
            else
                [self checkSeqUpdates];
        }];
    }
    else if (_updateList.count == 0)
    {
        [self cancelTimeoutTimer];
        [self completeAction];
    }
}

- (void)_failPts
{
    TGLog(@"***** Inconsistent state by (pts, pts_count)! Synchronization required.");
    
    [self cancelTimeoutTimer];
    
    [TGTelegraphInstance stateUpdateRequired];
    
    [self completeAction];
}

- (void)_failSeq
{
    TGLog(@"***** Inconsistent state by seq! Synchronization required.");
    
    [self cancelTimeoutTimer];
    
    [TGTelegraphInstance stateUpdateRequired];
    
    [self completeAction];
}

- (void)_failQts
{
    TGLog(@"***** Inconsistent state by qts! Synchronization required.");
    
    [self cancelTimeoutTimer];
    
    [TGTelegraphInstance stateUpdateRequired];
    
    [self completeAction];
}

template<typename T>
static int64_t extractMessageConversationId(T concreteMessage, int64_t &outFromUid)
{
    int64_t fromUid = concreteMessage.from_id;
    bool outgoing = concreteMessage.flags & 2;
    
    if (!outgoing)
        outFromUid = fromUid;
    
    if ([concreteMessage.to_id isKindOfClass:[TLPeer$peerUser class]])
    {
        TLPeer$peerUser *toUser = (TLPeer$peerUser *)concreteMessage.to_id;
        int64_t toUid = toUser.user_id;
        if (toUid == fromUid && !outgoing)
            outgoing = true;
        return outgoing ? toUid : fromUid;
    }
    else if ([concreteMessage.to_id isKindOfClass:[TLPeer$peerChat class]])
    {
        TLPeer$peerChat *toChat = (TLPeer$peerChat *)concreteMessage.to_id;
        int64_t toUid = -toChat.chat_id;
        return toUid;
    }
    else if ([concreteMessage.to_id isKindOfClass:[TLPeer$peerChannel class]])
    {
        TLPeer$peerChannel *toChannel = (TLPeer$peerChannel *)concreteMessage.to_id;
        int64_t toUid = TGPeerIdFromChannelId(toChannel.channel_id);
        return toUid;
    }
    
    return 0;
}

- (bool)_tryApplyingUpdates:(NSArray *)updates users:(NSArray *)users chats:(NSArray *)chats optionalFinalSeq:(int32_t)optionalFinalSeq optionalFinalDate:(int32_t)optionalFinalDate completion:(void (^)(bool))completion
{
    OGRuntimeCooperateWithInteraction();
    static Class updateNewMessageClass = nil;
    static Class updateNewEncryptedMessageClass = nil;
    static Class updateDeleteMessagesClass = nil;
    static Class updateRestoreMessagesClass = nil;
    static Class updateChangePtsClass = nil;
    static Class updateUserTypingClass = nil;
    static Class updateChatUserTypingClass = nil;
    static Class updateChatParticipantsClass = nil;
    static Class updateChatParticipantAddClass = nil;
    static Class updateChatParticipantDeleteClass = nil;
    static Class updateContactLocatedClass = nil;
    
    static Class messageClass = nil;
    static Class messageServiceClass = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        updateNewMessageClass = [TLUpdate$updateNewMessage class];
        updateNewEncryptedMessageClass = [TLUpdate$updateNewEncryptedMessage class];
        updateDeleteMessagesClass = [TLUpdate$updateDeleteMessages class];
        updateRestoreMessagesClass = [TLUpdate$updateRestoreMessages class];
        updateChangePtsClass = [TLUpdate$updateChangePts class];
        updateUserTypingClass = [TLUpdate$updateUserTyping class];
        updateChatUserTypingClass = [TLUpdate$updateChatUserTyping class];
        updateChatParticipantsClass = [TLUpdate$updateChatParticipants class];
        updateChatParticipantAddClass = [TLUpdate$updateChatParticipantAdd class];
        updateChatParticipantDeleteClass = [TLUpdate$updateChatParticipantDelete class];
        updateContactLocatedClass = [TLUpdate$updateContactLocated class];
        
        messageClass = [TLMessage$modernMessage class];
        messageServiceClass = [TLMessage$modernMessageService class];
    });
    
    int32_t statePts = 0;
    int32_t stateQts = 0;
    
    TGDatabaseState databaseState = [[TGDatabase instance] databaseState];
    
    for (TGWrappedUpdate *update in updates)
    {
        OGRuntimeCooperateWithInteraction();
        if ([update.update hasPts])
            statePts = MAX(statePts, [(id<TGSyntheticUpdateWithPts>)update.update pts]);
        if ([update.update respondsToSelector:@selector(qts)])
            stateQts = MAX(stateQts, [(id<TGSyntheticUpdateWithQts>)update.update qts]);
    }
    
    std::map<int64_t, TLUser *> processedUsers;
    std::map<int64_t, TLChat *> processedChats;
    
    NSMutableArray *updatesWithDates = [[NSMutableArray alloc] init];
    
    std::set<int64_t> knownUsers;
    std::set<int64_t> knownChats;
    
    NSMutableArray *addedMessages = [[NSMutableArray alloc] init];
    NSMutableArray *messagesForLocalNotification = [[NSMutableArray alloc] init];
    
    NSMutableArray *allUpdates = [[NSMutableArray alloc] init];
    NSMutableArray *reactionEdits = [[NSMutableArray alloc] init];
    NSMutableDictionary *archiveStateByPeerId = [[NSMutableDictionary alloc] init];
    
    int currentTime = (int)OGRemoteClockTime();
    
    bool failedProcessing = false;
    bool updatesTooLong = false;
    
    for (TLUser *userDesc in users)
    {
        OGRuntimeCooperateWithInteraction();
        maybeProcessUser(userDesc, processedUsers);
    }
    
    for (TLChat *chatDesc in chats)
    {
        OGRuntimeCooperateWithInteraction();
        maybeProcessChat(chatDesc, processedChats);
    }
    
    std::map<int64_t, int32_t> maxInboxReadMessageIdByPeerId;
    std::map<int64_t, int32_t> maxOutboxReadMessageIdByPeerId;

    for (TGWrappedUpdate *wrappedUpdate in updates)
    {
        OGRuntimeCooperateWithInteraction();
        if ([wrappedUpdate.update isKindOfClass:[TLUpdate$updateReadHistoryInbox class]])
        {
            TLUpdate$updateReadHistoryInbox *concreteUpdate = wrappedUpdate.update;
            
            int64_t peerId = OGCompatReadMarkPeerId(concreteUpdate.peer);
            
            auto it = maxInboxReadMessageIdByPeerId.find(peerId);
            maxInboxReadMessageIdByPeerId[peerId] = it == maxInboxReadMessageIdByPeerId.end() ? concreteUpdate.max_id : MAX(it->second, concreteUpdate.max_id);
        }
        else if ([wrappedUpdate.update isKindOfClass:[TLUpdate$updateReadHistoryOutbox class]])
        {
            TLUpdate$updateReadHistoryOutbox *concreteUpdate = wrappedUpdate.update;
            
            int64_t peerId = OGCompatReadMarkPeerId(concreteUpdate.peer);
            
            auto it = maxOutboxReadMessageIdByPeerId.find(peerId);
            maxOutboxReadMessageIdByPeerId[peerId] = it == maxOutboxReadMessageIdByPeerId.end() ? concreteUpdate.max_id : MAX(it->second, concreteUpdate.max_id);
        }
    }
    
    for (TGWrappedUpdate *wrappedUpdate in updates)
    {
        OGRuntimeCooperateWithInteraction();
        id update = wrappedUpdate.update;
        int32_t date = wrappedUpdate.date;
        
        if ([update isKindOfClass:[TLUpdate$updateMessageReactionsSummary class]])
        {
            TLUpdate$updateMessageReactionsSummary *reaction = update;
            int64_t reactionPeerId = OGCompatPeerIdOfPeer(reaction.peer);
            int32_t reactionMid = reaction.msg_id;
            TGMessage *reactedMessage = nil;
            if (reactionPeerId != 0 && reactionMid != 0)
                reactedMessage = [TGDatabaseInstance() loadMessageWithMid:reactionMid peerId:reactionPeerId];
            if (reactedMessage != nil)
            {
                OGCompatApplyReactionSummary(reactedMessage, reaction.reactionSummary, reaction.chosenReaction);
                TGDatabaseUpdateMessageWithMessage *edit = [[TGDatabaseUpdateMessageWithMessage alloc] initWithPeerId:reactionPeerId messageId:reactionMid message:reactedMessage dispatchEdited:true];
                [reactionEdits addObject:edit];
            }
        }
        else if ([update isKindOfClass:[TLUpdate$updateFolderPeers class]])
        {
            NSArray *folderPeers = ((TLUpdate$updateFolderPeers *)update).folder_peers;
            for (TLFolderPeerEntry *entry in folderPeers)
            {
                if (![entry isKindOfClass:[TLFolderPeerEntry class]])
                    continue;
                int64_t archivedPeerId = OGCompatPeerIdOfPeer(entry.peer);
                if (archivedPeerId == 0)
                    continue;
                archiveStateByPeerId[@(archivedPeerId)] = @(entry.folder_id == 1);
            }
        }
        else if ([update isKindOfClass:updateNewMessageClass])
        {
            TLUpdate$updateNewMessage *newMessage = (TLUpdate$updateNewMessage *)update;
            
            TLMessage *message = newMessage.message;
            
            if (([message isKindOfClass:[TLMessage$modernMessage class]] || [message isKindOfClass:[TLMessage$modernMessageService class]]) && !(((TLMessage$modernMessage *)message).flags & 2))
            {
                TGMessage *parsedMessage = [[TGMessage alloc] initWithTelegraphMessageDesc:message];
                if (!parsedMessage.outgoing && !parsedMessage.isSilent)
                {
                    auto maxIt = maxInboxReadMessageIdByPeerId.find(parsedMessage.cid);
                    if (maxIt == maxInboxReadMessageIdByPeerId.end()) {
                        TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:parsedMessage.cid];
                        maxInboxReadMessageIdByPeerId[parsedMessage.cid] = conversation.maxReadMessageId;
                    }
                    
                    if (!(maxIt != maxInboxReadMessageIdByPeerId.end() && parsedMessage.mid <= maxIt->second))
                        [messagesForLocalNotification addObject:newMessage.message];
                }
                
            }
            else
                TGLog(@"Message %d does not match for local notification", (int)message.n_id);
            
            int64_t conversationId = 0;
            int64_t fromUid = 0;
            
            if ([message isKindOfClass:messageClass])
                conversationId = extractMessageConversationId((TLMessage$message *)message, fromUid);
            else if ([message isKindOfClass:messageServiceClass])
                conversationId = extractMessageConversationId((TLMessage$modernMessageService *)message, fromUid);
            
            if (conversationId != 0)
            {
                if (conversationId < 0)
                {
                    if (knownChats.find(conversationId) == knownChats.end() && processedChats.find(conversationId) == processedChats.end())
                    {
                        bool contains = [TGDatabaseInstance() containsConversationWithId:conversationId];
                        if (contains)
                            knownChats.insert(conversationId);
                        else
                        {
                            TGLog(@"Unknown chat %" PRId64 "", conversationId);
                            failedProcessing = true;
                        }
                    }
                }
                else
                {
                    if (knownUsers.find(conversationId) == knownUsers.end() && processedUsers.find(conversationId) == processedUsers.end())
                    {
                        bool contains = [TGDatabaseInstance() loadUser:conversationId];
                        if (contains)
                            knownUsers.insert(conversationId);
                        else
                        {
                            TGLog(@"Unknown user %" PRId64 "", conversationId);
                            failedProcessing = true;
                        }
                    }
                }
            }
            
            if (!failedProcessing && fromUid != 0 && fromUid != conversationId)
            {
                if (knownUsers.find(fromUid) == knownUsers.end() && processedUsers.find(fromUid) == processedUsers.end())
                {
                    bool contains = [TGDatabaseInstance() loadUser:fromUid];
                    if (contains)
                        knownUsers.insert(fromUid);
                    else
                    {
                        TGLog(@"Unknown user %" PRId64 "", fromUid);
                        failedProcessing = true;
                    }
                }
            }
            
            if (!failedProcessing)
            {
                if ([message isKindOfClass:[TLMessage$modernMessage class]])
                {
                    TLMessageFwdHeader$messageFwdHeader *fwd_header = (TLMessageFwdHeader$messageFwdHeader *)((TLMessage$modernMessage *)message).fwd_from;
                    if (fwd_header != nil) {
                        if (fwd_header.from_id != 0) {
                            if (knownUsers.find(fwd_header.from_id) == knownUsers.end() && processedUsers.find(fwd_header.from_id) == processedUsers.end())
                            {
                                bool contains = [TGDatabaseInstance() loadUser:fwd_header.from_id];
                                if (contains)
                                    knownUsers.insert(fwd_header.from_id);
                                else
                                {
                                    TGLog(@"Unknown user %" PRId64 "", fwd_header.from_id);
                                    failedProcessing = true;
                                }
                            }
                        }
                        if (fwd_header.channel_id != 0) {
                            int64_t peerId = TGPeerIdFromChannelId(fwd_header.channel_id);
                            if (peerId != 0) {
                                if (knownChats.find(peerId) == knownChats.end() && processedChats.find(peerId) == processedChats.end()) {
                                    bool contains = [TGDatabaseInstance() _channelExists:peerId];
                                    if (contains)
                                        knownChats.insert(peerId);
                                    else
                                    {
                                        TGLog(@"Unknown channel %" PRId64 "", peerId);
                                        failedProcessing = true;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if (failedProcessing)
                break;
            
            [addedMessages addObject:message];
        }
        else if ([update isKindOfClass:updateUserTypingClass])
        {
            if (date > currentTime - 20)
                [allUpdates addObject:update];
        }
        else if ([update isKindOfClass:updateChatUserTypingClass])
        {
            if (date > currentTime - 20)
                [allUpdates addObject:update];
        }
        else if ([update isKindOfClass:[TLUpdate$updateEncryptedChatTyping class]])
        {
            if (date > currentTime - 20)
                [allUpdates addObject:update];
        }
        else if ([update isKindOfClass:updateContactLocatedClass])
        {   
            if (date > currentTime - 5 * 60)
                [allUpdates addObject:update];
        }
        else if ([update isKindOfClass:updateChatParticipantsClass])
        {
            TLUpdate$updateChatParticipants *updateChatParticipants = (TLUpdate$updateChatParticipants *)update;
            
            int64_t conversationId = -updateChatParticipants.participants.chat_id;
            
            if (conversationId < 0)
            {
                if (knownChats.find(conversationId) == knownChats.end() && processedChats.find(conversationId) == processedChats.end())
                {
                    bool contains = [TGDatabaseInstance() containsConversationWithId:conversationId];
                    if (contains)
                        knownChats.insert(conversationId);
                    else
                        failedProcessing = true;
                }
            }
            
            [allUpdates addObject:update];
        }
        else if ([update isKindOfClass:updateChatParticipantAddClass] || [update isKindOfClass:updateChatParticipantDeleteClass])
        {
            int64_t conversationId = 0;
            int64_t userId = 0;
            if ([update isKindOfClass:updateChatParticipantAddClass])
            {
                conversationId = -((TLUpdate$updateChatParticipantAdd *)update).chat_id;
                userId = ((TLUpdate$updateChatParticipantAdd *)update).user_id;
            }
            if ([update isKindOfClass:updateChatParticipantDeleteClass])
            {
                conversationId = -((TLUpdate$updateChatParticipantDelete *)update).chat_id;
                userId = ((TLUpdate$updateChatParticipantDelete *)update).user_id;
            }
            
            if (conversationId < 0)
            {
                if (knownChats.find(conversationId) == knownChats.end() && processedChats.find(conversationId) == processedChats.end())
                {
                    bool contains = [TGDatabaseInstance() containsConversationWithId:conversationId];
                    if (contains)
                        knownChats.insert(conversationId);
                    else
                        failedProcessing = true;
                }
            }
            
            if (userId != 0)
            {
                if (knownUsers.find(userId) == knownUsers.end() && processedUsers.find(userId) == processedUsers.end())
                {
                    bool contains = [TGDatabaseInstance() loadUser:userId];
                    if (contains)
                        knownUsers.insert(userId);
                    else
                    {
                        TGLog(@"Unknown user %" PRId64 "", userId);
                        failedProcessing = true;
                    }
                }
            }
            
            [updatesWithDates addObject:@[update, @(date)]];
            [allUpdates addObject:update];
        }
        else if ([update isKindOfClass:[TLUpdate$updateEncryption class]])
        {
            TLUpdate$updateEncryption *updateEncryption = (TLUpdate$updateEncryption *)update;
            
            TGConversation *conversation = [[TGConversation alloc] initWithTelegraphEncryptedChatDesc:updateEncryption.chat];
            
            if (conversation.conversationId != 0)
            {
                if (conversation.chatParticipants.chatParticipantUids.count != 0)
                {
                    int64_t userId = [conversation.chatParticipants.chatParticipantUids[0] longLongValue];
                    if ([TGDatabaseInstance() loadUser:userId] != nil)
                        [allUpdates addObject:update];
                    else
                        failedProcessing = true;
                }
                else
                    failedProcessing = true;
            }
            else
                failedProcessing = true;
        }
        else if ([update isKindOfClass:updateNewEncryptedMessageClass])
        {
            TLUpdate$updateNewEncryptedMessage *updateNewEncryptedMessage = (TLUpdate$updateNewEncryptedMessage *)update;
            
            if (![updateNewEncryptedMessage.message isKindOfClass:[TLEncryptedMessage$encryptedMessageService class]] && updateNewEncryptedMessage.message != nil && stateQts != 0)
            {
                [messagesForLocalNotification addObject:@{@"message": updateNewEncryptedMessage.message, @"qts": @(stateQts)}];
            }
            
            [allUpdates addObject:update];
        }
        else if ([update isKindOfClass:[TLUpdates$updatesTooLong class]])
        {
            failedProcessing = true;
            updatesTooLong = true;
            
            break;
        }
        else
        {
            [allUpdates addObject:update];
        }
    }

    
    [TGDatabaseInstance() setConversationsArchiveState:archiveStateByPeerId];
    
    if (!failedProcessing)
    {
        NSMutableArray *usersToProcess = [[NSMutableArray alloc] initWithCapacity:processedUsers.size()];
        
        for (std::map<int64_t, TLUser *>::iterator it = processedUsers.begin(); it != processedUsers.end(); it++)
        {
            [usersToProcess addObject:it->second];
        }
        
        NSMutableArray *chatsToProcess = [[NSMutableArray alloc] initWithCapacity:processedChats.size()];
        
        for (std::map<int64_t, TLChat *>::iterator it = processedChats.begin(); it != processedChats.end(); it++)
        {
            [chatsToProcess addObject:it->second];
        }
        
        _waitingForApplyUpdates = true;
        [TGUpdateStateRequestBuilder applyUpdates:addedMessages otherUpdates:allUpdates usersDesc:usersToProcess chatsDesc:chatsToProcess chatParticipantsDesc:nil updatesWithDates:updatesWithDates addedEncryptedActionsByPeerId:nil addedEncryptedUnparsedActionsByPeerId:nil completion:^(__unused bool applied)
        {
            if (reactionEdits.count > 0)
            {
                [TGDatabaseInstance() transactionUpdateMessages:reactionEdits updateConversationDatas:nil];
            }
            _waitingForApplyUpdates = false;
            [_updateList addObjectsFromArray:_waitingForApplyUpdatesQueue];
            [_waitingForApplyUpdatesQueue removeAllObjects];
            
            [delayedNotifications() addObjectsFromArray:messagesForLocalNotification];

            if (OGPlatformSupportsBackgroundVoipTransport() &&
                messagesForLocalNotification.count != 0 &&
                [UIApplication sharedApplication].applicationState != UIApplicationStateActive)
            {
                NSMutableArray *immediateMids = [[NSMutableArray alloc] init];
                int32_t immediateMaxMid = 0;
                for (id pendingDesc in messagesForLocalNotification)
                {
                    int32_t pendingMid = [pendingDesc isKindOfClass:[TLMessage class]] ? ((TLMessage *)pendingDesc).n_id : 0;
                    if (pendingMid == 0)
                        continue;
                    [immediateMids addObject:@(pendingMid)];
                    immediateMaxMid = MAX(immediateMaxMid, pendingMid);
                }

                if (immediateMids.count > 0)
                {
                    [TGApplyUpdatesActor applyDelayedNotifications:immediateMaxMid mids:immediateMids midsWithoutSound:[NSSet set] maxQts:stateQts randomIds:nil];
                }
            }
            
            if (stateQts != 0)
            {
                [TGDatabaseInstance() updateLatestQts:stateQts applied:false completion:^(int greaterQtsForSynchronization)
                 {
                     if (greaterQtsForSynchronization > 0)
                     {
                         [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/messages/reportDelivery/(qts)"] options:[[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithInt:stateQts], @"qts", nil] watcher:TGTelegraphInstance];
                     }
                 }];
            }
            
            if ([self.path isEqualToString:@"/tg/service/tryupdates/(withPts)"] || [self.path isEqualToString:@"/tg/service/tryupdates/(withSeq)"] || [self.path isEqualToString:@"/tg/service/tryupdates/(withQts)"])
            {
                
                [[TGDatabase instance] applyPts:statePts date:optionalFinalDate seq:optionalFinalSeq qts:stateQts unreadCount:-1];
            }
            else if (optionalFinalDate > databaseState.date)
            {
                [[TGDatabase instance] applyPts:0 date:optionalFinalDate seq:0 qts:0 unreadCount:-1];
            }
            
            if (completion)
                completion(true);
        }];
    }
    else
    {
        if (updatesTooLong)
            TGLog(@"Udates too long, requesting complete difference");
        else
            TGLog(@"Unknown chat or user found, requesting complete difference");
        
        if (completion)
            completion(false);
    }
    
    return !failedProcessing;
}

- (void)cancel
{
    [self cancelTimeoutTimer];
    
    [super cancel];
}

+ (void)applyDelayedNotifications:(int)maxMid mids:(NSArray *)mids midsWithoutSound:(NSSet *)midsWithoutSound maxQts:(int)maxQts randomIds:(NSArray *)randomIds
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        UIApplication *application = [UIApplication sharedApplication];
        UIApplicationState applicationState = application == nil ? UIApplicationStateBackground : application.applicationState;
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [TGApplyUpdatesActor applyDelayedNotificationsInApplicationState:applicationState maxMid:maxMid mids:mids midsWithoutSound:midsWithoutSound maxQts:maxQts randomIds:randomIds];
        }];
    });
}

+ (void)applyDelayedNotificationsInApplicationState:(UIApplicationState)applicationState maxMid:(int)maxMid mids:(NSArray *)mids midsWithoutSound:(NSSet *)midsWithoutSound maxQts:(int)maxQts randomIds:(NSArray *)randomIds
{
    if (applicationState == UIApplicationStateActive)
    {
        [TGApplyUpdatesActor clearDelayedNotifications];
        return;
    }

    NSNumber *globalMessageSoundIdVal = nil;
    NSNumber *globalMessagePreviewTextVal = nil;
    NSNumber *globalMessageMuteUntilVal = nil;

    int globalMessageSoundId = 1;
    bool globalMessagePreviewText = true;
    int globalMessageMuteUntil = 0;
    bool notFound = false;
    [TGDatabaseInstance() loadPeerNotificationSettings:TGPeerIdNotificationDefaultsPrivate soundId:&globalMessageSoundIdVal muteUntil:&globalMessageMuteUntilVal previewText:&globalMessagePreviewTextVal messagesMuted:NULL notFound:&notFound];
    if (notFound) {
        globalMessageSoundId = 1;
        globalMessagePreviewText = true;
    }
    else {
        globalMessageSoundId = globalMessageSoundIdVal ? globalMessageSoundIdVal.intValue : 1;
        globalMessagePreviewText = globalMessagePreviewTextVal ? globalMessagePreviewTextVal.boolValue : true;
        globalMessageMuteUntil = globalMessageMuteUntilVal ? globalMessageMuteUntilVal.intValue : 0;
    }

    NSNumber *globalGroupSoundIdVal = nil;
    NSNumber *globalGroupPreviewTextVal = nil;
    NSNumber *globalGroupMuteUntilVal = nil;

    int globalGroupSoundId = 1;
    bool globalGroupPreviewText = true;
    int globalGroupMuteUntil = 0;
    notFound = false;
    [TGDatabaseInstance() loadPeerNotificationSettings:TGPeerIdNotificationDefaultsGroup soundId:&globalGroupSoundIdVal muteUntil:&globalGroupMuteUntilVal previewText:&globalGroupPreviewTextVal messagesMuted:NULL notFound:&notFound];
    if (notFound) {
        globalGroupSoundId = 1;
        globalGroupPreviewText = true;
    } else {
        globalGroupSoundId = globalGroupSoundIdVal ? globalGroupSoundIdVal.intValue : 1;
        globalGroupPreviewText = globalGroupPreviewTextVal ? globalGroupPreviewTextVal.boolValue : true;
        globalGroupMuteUntil = globalGroupMuteUntilVal ? globalGroupMuteUntilVal.intValue : 0;
    }

    @try
    {
        std::set<int> midsSet;
        for (NSNumber *nMid in mids)
        {
            midsSet.insert([nMid intValue]);
        }

        std::set<int> processedMidsSet;

        std::set<int64_t> randomIdsSet;
        for (NSNumber *nRandomId in randomIds)
        {
            randomIdsSet.insert([nRandomId longLongValue]);
        }

        int count = (int)delayedNotifications().count;
        for (int i = 0; i < count; i++)
        {
            TGMessage *message = nil;
            NSUInteger multiforwardCount = 0;

            int messageQts = 0;

            id abstractDesc = delayedNotifications()[i];
            if ([abstractDesc respondsToSelector:@selector(allKeys)])
            {
                messageQts = [abstractDesc[@"qts"] intValue];
                abstractDesc = abstractDesc[@"message"];
            }

            if ([abstractDesc isKindOfClass:[TLMessage class]])
            {
                if (mids == nil)
                    continue;

                TLMessage *messageDesc = abstractDesc;
                int mid = messageDesc.n_id;

                if (mid == 0 || mid > maxMid)
                    continue;

                [delayedNotifications() removeObjectAtIndex:i];
                i--;
                count--;

                if (midsSet.find(mid) == midsSet.end())
                    continue;

                if (processedMidsSet.find(mid) != processedMidsSet.end())
                    continue;
                processedMidsSet.insert(mid);

                if (!OGCompatTakeNotificationSlot())
                    continue;

                message = [[TGMessage alloc] initWithTelegraphMessageDesc:messageDesc];
                bool foundForward = false;

                for (id media in message.mediaAttachments)
                {
                    if ([media isKindOfClass:[TGForwardedMessageMediaAttachment class]])
                    {
                        foundForward = true;
                        break;
                    }
                }

                if (foundForward)
                {
                    for (int j = i + 1; j >= 0 && j < count; j++)
                    {
                        if ([delayedNotifications()[j] isKindOfClass:[TLMessage class]])
                        {
                            TGMessage *nextMessage = [[TGMessage alloc] initWithTelegraphMessageDesc:delayedNotifications()[j]];

                            if (processedMidsSet.find(nextMessage.mid) != processedMidsSet.end())
                                continue;
                            processedMidsSet.insert(nextMessage.mid);

                            bool nextIsForward = false;
                            for (id media in nextMessage.mediaAttachments)
                            {
                                if ([media isKindOfClass:[TGForwardedMessageMediaAttachment class]])
                                {
                                    nextIsForward = true;
                                    break;
                                }
                            }

                            if (nextIsForward)
                            {
                                if (multiforwardCount == 0)
                                    multiforwardCount = 1;
                                multiforwardCount++;
                                [delayedNotifications() removeObjectAtIndex:j];
                                j--;
                                count--;
                            }
                        }
                    }
                }
            }
            else if ([abstractDesc isKindOfClass:[TLEncryptedMessage class]])
            {
                if (randomIds == nil)
                    continue;

                TLEncryptedMessage *encryptedMessage = abstractDesc;

                if (messageQts > maxQts)
                    continue;

                [delayedNotifications() removeObjectAtIndex:i];
                i--;
                count--;

                if (randomIdsSet.find(encryptedMessage.random_id) == randomIdsSet.end())
                    continue;

                if (!OGCompatTakeNotificationSlot())
                    continue;

                message = [[TGMessage alloc] init];
                message.randomId = encryptedMessage.random_id;
                message.cid = [TGDatabaseInstance() peerIdForEncryptedConversationId:encryptedMessage.chat_id];
            }
            else
            {
                TGLog(@"***** unknown notification message type %@", abstractDesc);
                continue;
            }

            bool fromChannel = TGPeerIdIsChannel(message.cid);

            if (fromChannel && ![TGDatabaseInstance() loadConversationWithId:message.cid].isChannelMember)
                continue;

            if (message.cid == TGTelegraphInstance.clientUserId || message.fromUid == TGTelegraphInstance.clientUserId)
                continue;

            int64_t mutedCheckPeerId = message.containsMention ? message.fromUid : message.cid;
            if ([TGDatabaseInstance() isPeerMuted:mutedCheckPeerId]) {
                continue;
            }

            id localNotification = OGPlatformCreateLocalNotification();
            if (localNotification == nil)
                continue;

            TGUser *user = nil;
            NSString *chatName = nil;

            int64_t notificationPeerId = 0;

            if (fromChannel)
            {
                notificationPeerId = message.cid;
                if (message.fromUid != 0)
                    user = [TGDatabaseInstance() loadUser:message.fromUid];
                chatName = OGCompatChatTitleForPeer(message.cid);
            }
            else if (TGPeerIdIsSecretChat(message.cid))
            {
                notificationPeerId = [TGDatabaseInstance() encryptedParticipantIdForConversationId:message.cid];
            }
            else if (message.cid > 0)
            {
                user = [TGDatabaseInstance() loadUser:message.cid];
                notificationPeerId = message.cid;
            }
            else
            {
                notificationPeerId = message.containsMention ? message.fromUid : message.cid;
                user = [TGDatabaseInstance() loadUser:message.fromUid];
                chatName = OGCompatChatTitleForPeer(message.cid);
            }

            if ([TGDatabaseInstance() isPeerMuted:notificationPeerId]) {
                continue;
            }

            NSString *authorName = user.displayName;
            if (authorName.length == 0 && message.fromUid != 0)
            {
                if (TGPeerIdIsUser(message.fromUid))
                {
                    TGUser *authorUser = [TGDatabaseInstance() loadUser:message.fromUid];
                    if (user == nil)
                        user = authorUser;
                    authorName = authorUser.displayName;
                }
                else if (TGPeerIdIsGroup(message.fromUid) || TGPeerIdIsChannel(message.fromUid))
                {
                    TGConversation *authorConversation = [TGDatabaseInstance() loadConversationWithIdCached:message.fromUid];
                    if (authorConversation == nil)
                        authorConversation = [TGDatabaseInstance() loadConversationWithId:message.fromUid];
                    authorName = authorConversation.chatTitle;
                }
            }
            if (authorName.length == 0 && fromChannel && message.fromUid == message.cid)
                authorName = chatName;
            if (authorName.length == 0 && message.cid > 0)
            {
                TGUser *peerUser = [TGDatabaseInstance() loadUser:message.cid];
                if (user == nil)
                    user = peerUser;
                authorName = peerUser.displayName;
            }
            if (authorName.length == 0)
                authorName = chatName;
            if (authorName.length == 0)
                continue;

            NSNumber *soundIdVal = nil;
            int soundId = 1;
            [TGDatabaseInstance() loadPeerNotificationSettings:notificationPeerId soundId:&soundIdVal muteUntil:NULL previewText:NULL messagesMuted:NULL notFound:NULL];

            if (soundIdVal != nil) {
                soundId = soundIdVal.intValue;
            } else {
                soundId = (message.cid > 0 || (message.cid <= INT_MIN && !fromChannel)) ? globalMessageSoundId : globalGroupSoundId;
            }

            NSString *text = nil;

            bool attachmentFound = false;
            bool migrationFound = false;
            bool skipMessage = false;
            bool phoneCall = false;

            for (TGMediaAttachment *attachment in message.mediaAttachments)
            {
                if (attachment.type == TGActionMediaAttachmentType)
                {
                    TGActionMediaAttachment *actionAttachment = (TGActionMediaAttachment *)attachment;
                    switch (actionAttachment.actionType)
                    {
                        case TGMessageActionChatEditTitle:
                        {
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_TITLE_EDITED"), authorName, [((TGActionMediaAttachment *)attachment).actionData objectForKey:@"title"]];
                            attachmentFound = true;

                            break;
                        }
                        case TGMessageActionChatEditPhoto:
                        {
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_PHOTO_EDITED"), authorName, chatName];
                            attachmentFound = true;

                            break;
                        }
                        case TGMessageActionChatAddMember:
                        {
                            NSArray *uids = actionAttachment.actionData[@"uids"];
                            if (uids != nil) {
                                TGUser *authorUser = user;
                                NSMutableArray *subjectUsers = [[NSMutableArray alloc] init];
                                for (NSNumber *nUid in uids) {
                                    TGUser *subjectUser = [TGDatabaseInstance() loadUser:[nUid longLongValue]];
                                    if (user != nil) {
                                        [subjectUsers addObject:subjectUser];
                                    }
                                }

                                if (subjectUsers.count == 1 && authorUser.uid == ((TGUser *)subjectUsers[0]).uid) {
                                    text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_RETURNED"), authorName, chatName];
                                } else {
                                    NSMutableString *subjectNames = [[NSMutableString alloc] init];
                                    for (TGUser *subjectUser in subjectUsers) {
                                        if (subjectNames.length != 0) {
                                            [subjectNames appendString:@", "];
                                        }
                                        [subjectNames appendString:subjectUser.displayName];
                                    }
                                    text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_ADD_MEMBER"), authorName, chatName, subjectNames];
                                }
                                attachmentFound = true;
                            } else {
                                NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                                if (nUid != nil)
                                {
                                    TGUser *subjectUser = [TGDatabaseInstance() loadUser:[nUid longLongValue]];

                                    if (subjectUser.uid == user.uid)
                                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_RETURNED"), authorName, chatName];
                                    else if (subjectUser.uid == TGTelegraphInstance.clientUserId)
                                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_ADD_YOU"), authorName, chatName];
                                    else
                                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_ADD_MEMBER"), authorName, chatName, subjectUser.displayName];
                                    attachmentFound = true;
                                }
                            }

                            break;
                        }
                        case TGMessageActionChatDeleteMember:
                        {
                            NSNumber *nUid = [actionAttachment.actionData objectForKey:@"uid"];
                            if (nUid != nil)
                            {
                                TGUser *subjectUser = [TGDatabaseInstance() loadUser:[nUid longLongValue]];

                                if (subjectUser.uid == user.uid)
                                    text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_LEFT"), authorName, chatName];
                                else if (subjectUser.uid == TGTelegraphInstance.clientUserId)
                                    text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_DELETE_YOU"), authorName, chatName];
                                else
                                    text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_DELETE_MEMBER"), authorName, chatName, subjectUser.displayName];
                                attachmentFound = true;
                            }

                            break;
                        }
                        case TGMessageActionCreateChat:
                        {
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_ADD_YOU"), authorName, chatName];
                            attachmentFound = true;

                            break;
                        }
                        case TGMessageActionChannelCreated:
                        {
                            text = @"";
                            attachmentFound = true;

                            break;
                        }
                        case TGMessageActionChannelCommentsStatusChanged:
                        {
                            text = [actionAttachment.actionData[@"enabled"] boolValue] ? TGLocalized(@"Channel.NotificationCommentsEnabled") : TGLocalized(@"Channel.NotificationCommentsDisabled");
                            attachmentFound = true;

                            break;
                        }
                        case TGMessageActionJoinedByLink:
                        {
                            bool joinedByRequest = [actionAttachment.actionData[@"joinedByRequest"] boolValue];
                            NSString *formatString = TGLocalized(joinedByRequest ? @"Notification.JoinedChat" : @"Notification.JoinedGroupByLink");
                            text = [[NSString alloc] initWithFormat:formatString, authorName];
                            attachmentFound = true;

                            break;
                        }
                        case TGMessageActionGroupMigratedTo:
                        {
                            migrationFound = true;
                            break;
                        }
                        case TGMessageActionGameScore:
                        {
                            TGMessage *replyMessage = nil;
                            for (id attachment in message.mediaAttachments) {
                                if ([attachment isKindOfClass:[TGReplyMessageMediaAttachment class]]) {
                                    replyMessage = ((TGReplyMessageMediaAttachment *)attachment).replyMessage;
                                    break;
                                }
                            }

                            NSString *gameTitle = nil;
                            for (id attachment in replyMessage.mediaAttachments) {
                                if ([attachment isKindOfClass:[TGGameMediaAttachment class]]) {
                                    gameTitle = ((TGGameMediaAttachment *)attachment).title;
                                    break;
                                }
                            }

                            int scoreCount = (int)[actionAttachment.actionData[@"score"] intValue];

                            NSString *formatStringBase = @"";
                            if (gameTitle != nil) {
                                if (user.uid == TGTelegraphInstance.clientUserId) {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreSelfExtended_" value:scoreCount];
                                } else {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreExtended_" value:scoreCount];
                                }
                            } else {
                                if (user.uid == TGTelegraphInstance.clientUserId) {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreSelfSimple_" value:scoreCount];
                                } else {
                                    formatStringBase = [TGStringUtils integerValueFormat:@"ServiceMessage.GameScoreSimple_" value:scoreCount];
                                }
                            }

                            NSString *baseString = TGLocalized(formatStringBase);
                            baseString = [baseString stringByReplacingOccurrencesOfString:@"%@" withString:@"{game}"];

                            NSMutableString *formatString = [[NSMutableString alloc] initWithString:baseString];

                            NSString *scoreAuthorName = user.displayFirstName;
                            if (scoreAuthorName.length == 0)
                                scoreAuthorName = authorName;

                            for (int i = 0; i < 3; i++) {
                                NSRange nameRange = [formatString rangeOfString:@"{name}"];
                                NSRange scoreRange = [formatString rangeOfString:@"{score}"];
                                NSRange gameTitleRange = [formatString rangeOfString:@"{game}"];

                                if (nameRange.location != NSNotFound) {
                                    if (scoreRange.location == NSNotFound || scoreRange.location > nameRange.location) {
                                        scoreRange.location = NSNotFound;
                                    }
                                    if (gameTitleRange.location == NSNotFound || gameTitleRange.location > nameRange.location) {
                                        gameTitleRange.location = NSNotFound;
                                    }
                                }

                                if (scoreRange.location != NSNotFound) {
                                    if (nameRange.location == NSNotFound || nameRange.location > scoreRange.location) {
                                        nameRange.location = NSNotFound;
                                    }
                                    if (gameTitleRange.location == NSNotFound || gameTitleRange.location > scoreRange.location) {
                                        gameTitleRange.location = NSNotFound;
                                    }
                                }

                                if (gameTitleRange.location != NSNotFound) {
                                    if (scoreRange.location == NSNotFound || scoreRange.location > gameTitleRange.location) {
                                        scoreRange.location = NSNotFound;
                                    }
                                    if (nameRange.location == NSNotFound || nameRange.location > gameTitleRange.location) {
                                        nameRange.location = NSNotFound;
                                    }
                                }

                                if (nameRange.location != NSNotFound) {
                                    [formatString replaceCharactersInRange:nameRange withString:scoreAuthorName];
                                }

                                if (scoreRange.location != NSNotFound) {
                                    [formatString replaceCharactersInRange:scoreRange withString:[NSString stringWithFormat:@"%d", scoreCount]];
                                }

                                if (gameTitleRange.location != NSNotFound) {
                                    [formatString replaceCharactersInRange:gameTitleRange withString:gameTitle];
                                }
                            }

                            text = formatString;
                            attachmentFound = true;

                            break;
                        }
                        case TGMessageActionPhoneCall:
                        {
                            TGCallDiscardReason reason = (TGCallDiscardReason)[actionAttachment.actionData[@"reason"] intValue];
                            if (reason == TGCallDiscardReasonMissed) {
                                text = [NSString stringWithFormat:TGLocalized(@"PHONE_CALL_MISSED"), authorName];
                                phoneCall = true;
                            }
                            else {
                                skipMessage = true;
                            }

                            attachmentFound = true;
                            break;
                        }
                        case TGMessageActionEncryptedChatMessageScreenshot:
                        {
                            text = [NSString stringWithFormat:TGLocalized(@"MESSAGE_SCREENSHOT"), authorName];
                            attachmentFound = true;

                            break;
                        }
                        default:
                            break;
                    }
                }
                else if (attachment.type == TGImageMediaAttachmentType)
                {
                    if (((globalMessagePreviewText && TGPeerIdIsUser(message.cid)) || (globalGroupPreviewText && !TGPeerIdIsUser(message.cid))) && ((TGImageMediaAttachment *)attachment).caption.length != 0) {
                        if (message.cid > 0) {
                            text = [[NSString alloc] initWithFormat:@"%@: 🖼 %@", authorName, ((TGImageMediaAttachment *)attachment).caption];
                        } else {
                            text = [[NSString alloc] initWithFormat:@"%@@%@: 🖼 %@", authorName, chatName, ((TGImageMediaAttachment *)attachment).caption];
                        }
                    } else {
                        if (message.cid > 0) {
                            if (message.messageLifetime > 0 && message.messageLifetime <= 60) {
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_PHOTO_SECRET"), authorName];
                            } else {
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_PHOTO"), authorName];
                            }
                        }
                        else
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_PHOTO"), authorName, chatName];
                    }

                    attachmentFound = true;

                    break;
                }
                else if (attachment.type == TGVideoMediaAttachmentType)
                {
                    bool isRoundMessage = ((TGVideoMediaAttachment *)attachment).roundMessage;

                    if (((globalMessagePreviewText && TGPeerIdIsUser(message.cid)) || (globalGroupPreviewText && !TGPeerIdIsUser(message.cid))) && ((TGVideoMediaAttachment *)attachment).caption.length != 0) {
                        if (message.cid > 0) {
                            text = [[NSString alloc] initWithFormat:@"%@: 📹 %@", authorName, ((TGVideoMediaAttachment *)attachment).caption];
                        } else {
                            text = [[NSString alloc] initWithFormat:@"%@@%@: 📹 %@", authorName, chatName, ((TGVideoMediaAttachment *)attachment).caption];
                        }
                    } else {
                        if (isRoundMessage) {
                            if (message.cid > 0)
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_ROUND"), authorName];
                            else
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_ROUND"), authorName, chatName];
                        }
                        else {
                            if (message.cid > 0)
                                if (message.messageLifetime > 0 && message.messageLifetime <= 60) {
                                    text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_VIDEO_SECRET"), authorName];
                                } else {
                                    text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_VIDEO"), authorName];
                                }
                            else
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_VIDEO"), authorName, chatName];
                        }
                    }

                    attachmentFound = true;

                    break;
                }
                else if (attachment.type == TGLocationMediaAttachmentType)
                {
                    TGLocationMediaAttachment *attachment = (TGLocationMediaAttachment *)attachment;
                    if (attachment.period > 0)
                    {
                        if (message.cid > 0)
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_GEOLIVE"), authorName];
                        else
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_GEOLIVE"), authorName, chatName];
                    }
                    else
                    {
                        if (message.cid > 0)
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_GEO"), authorName];
                        else
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_GEO"), authorName, chatName];
                    }

                    attachmentFound = true;

                    break;
                }
                else if (attachment.type == TGContactMediaAttachmentType)
                {
                    if (message.cid > 0)
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_CONTACT"), authorName];
                    else
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_CONTACT"), authorName, chatName];

                    attachmentFound = true;

                    break;
                }
                else if (attachment.type == TGDocumentMediaAttachmentType)
                {
                    bool isAnimated = false;
                    bool isVoice = false;
                    CGSize imageSize = CGSizeZero;
                    bool isSticker = false;
                    NSString *stickerRepresentation = @"";
                    for (id attribute in ((TGDocumentMediaAttachment *)attachment).attributes)
                    {
                        if ([attribute isKindOfClass:[TGDocumentAttributeAnimated class]])
                        {
                            isAnimated = true;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeImageSize class]])
                        {
                            imageSize = ((TGDocumentAttributeImageSize *)attribute).size;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeVideo class]]) {
                            imageSize = ((TGDocumentAttributeVideo *)attribute).size;
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
                        {
                            isSticker = true;
                            stickerRepresentation = [((TGDocumentAttributeSticker *)attribute).alt stringByAppendingString:@" "];
                        }
                        else if ([attribute isKindOfClass:[TGDocumentAttributeAudio class]]) {
                            isVoice = ((TGDocumentAttributeAudio *)attribute).isVoice;
                        }
                    }

                    if (isSticker)
                    {
                        if (message.cid > 0) {
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_STICKER"), authorName, stickerRepresentation];
                        } else {
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_STICKER"), authorName, chatName, stickerRepresentation];
                        }
                    }
                    else if (isAnimated) {
                        if (message.cid > 0)
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_GIF"), authorName];
                        else
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_GIF"), authorName, chatName];
                    }
                    else if (isVoice) {
                        if (message.cid > 0)
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_AUDIO"), authorName];
                        else
                            text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_AUDIO"), authorName, chatName];
                    }
                    else
                    {
                        if (globalMessagePreviewText && ((TGDocumentMediaAttachment *)attachment).caption.length != 0) {
                            if (message.cid > 0) {
                                text = [[NSString alloc] initWithFormat:@"%@: 📎 %@", authorName, ((TGDocumentMediaAttachment *)attachment).caption];
                            } else {
                                text = [[NSString alloc] initWithFormat:@"%@@%@: 📎 %@", authorName, chatName, ((TGDocumentMediaAttachment *)attachment).caption];
                            }
                        } else {
                            if (message.cid > 0)
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_DOC"), authorName];
                            else
                                text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_DOC"), authorName, chatName];
                        }
                    }

                    attachmentFound = true;

                    break;
                }
                else if (attachment.type == TGAudioMediaAttachmentType)
                {
                    if (message.cid > 0)
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_AUDIO"), authorName];
                    else
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_AUDIO"), authorName, chatName];

                    attachmentFound = true;

                    break;
                }
                else if (attachment.type == TGGameAttachmentType) {
                    NSString *gameTitle = ((TGGameMediaAttachment *)attachment).title;

                    if (message.cid > 0) {
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_GAME"), authorName, gameTitle];
                    } else {
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_GAME"), authorName, chatName, gameTitle];
                    }

                    attachmentFound = true;
                    break;
                }
                else if (attachment.type == TGInvoiceMediaAttachmentType) {
                    TGInvoiceMediaAttachment *invoice = (TGInvoiceMediaAttachment *)attachment;

                    NSString *priceString = [[TGCurrencyFormatter shared] formatAmount:invoice.totalAmount currency:invoice.currency];

                    if (message.cid > 0) {
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_INVOICE"), authorName, priceString];
                    } else {
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_INVOICE"), authorName, chatName, priceString];
                    }

                    attachmentFound = true;
                    break;
                }
            }

            if (migrationFound || skipMessage) {
                continue;
            }

            bool soundSuppressed = [midsWithoutSound containsObject:@(message.mid)];
            if (iosMajorVersion() <= 6 && !soundSuppressed)
            {
                OGPlatformSetLocalNotificationSoundName(localNotification, @"notification.caf");
            }
            else if (soundId > 0 && !soundSuppressed)
            {
                OGPlatformSetLocalNotificationSoundName(localNotification, [[NSString alloc] initWithFormat:@"%d.m4a", soundId]);

            }

            if (multiforwardCount != 0)
            {
                if (message.cid > 0)
                {
                    text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_FWDS"), authorName, [[NSString alloc] initWithFormat:@"%d", (int)multiforwardCount]];
                }
                else
                {
                    text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_FWDS"), authorName, chatName, [[NSString alloc] initWithFormat:@"%d", (int)multiforwardCount]];
                }
            }
            else
            {
                if (fromChannel)
                {
                    if (globalGroupPreviewText && !attachmentFound)
                    {
                        NSString *speaker = authorName.length != 0 ? [[NSString alloc] initWithFormat:@"%@@%@", authorName, chatName] : [[NSString alloc] initWithFormat:@"%@", chatName];
                        text = [[NSString alloc] initWithFormat:@"%@: %@", speaker, message.text];
                    }
                    else if (!attachmentFound)
                    {
                        text = [[NSString alloc] initWithFormat:@"%@", chatName];
                    }
                }
                else if (TGPeerIdIsSecretChat(message.cid))
                {
                    text = [[NSString alloc] initWithFormat:TGLocalized(@"ENCRYPTED_MESSAGE"), @""];
                }
                else if (message.cid > 0)
                {
                    if (globalMessagePreviewText && !attachmentFound)
                        text = [[NSString alloc] initWithFormat:@"%@: %@", authorName, message.text];
                    else if (!attachmentFound)
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"MESSAGE_NOTEXT"), authorName];
                }
                else
                {
                    if (globalGroupPreviewText && !attachmentFound)
                        text = [[NSString alloc] initWithFormat:@"%@@%@: %@", authorName, chatName, message.text];
                    else if (!attachmentFound)
                        text = [[NSString alloc] initWithFormat:TGLocalized(@"CHAT_MESSAGE_NOTEXT"), authorName, chatName];
                }
            }

            bool isLocked = [TGAppDelegateInstance isCurrentlyLocked];
            if (isLocked)
            {
                text = [[NSString alloc] initWithFormat:TGLocalized(@"LOCKED_MESSAGE"), @""];
            }

            OGPlatformSetLocalNotificationUserInfo(localNotification, [[NSDictionary alloc] initWithObjectsAndKeys:[[NSNumber alloc] initWithLongLong:message.cid], @"cid", @(message.mid), @"mid", nil]);

            NSString *notificationTitle = chatName.length != 0 ? chatName : authorName;
            if (notificationTitle.length != 0)
                OGPlatformSetLocalNotificationAlertTitle(localNotification, notificationTitle);

            if (iosMajorVersion() >= 8 && !isLocked)
            {
                if (phoneCall)
                    OGPlatformSetLocalNotificationCategory(localNotification, @"p");
                else if (TGPeerIdIsGroup(message.cid))
                    OGPlatformSetLocalNotificationCategory(localNotification, @"m");
                else if (TGPeerIdIsChannel(message.cid))
                    OGPlatformSetLocalNotificationCategory(localNotification, @"c");
                else if (!TGPeerIdIsSecretChat(message.cid))
                    OGPlatformSetLocalNotificationCategory(localNotification, @"r");
            }

            NSUInteger batchSize = mids.count != 0 ? mids.count : randomIds.count;
            if (batchSize >= 5)
            {
                text = OGCompatAggregateNotificationText(batchSize);
                NSMutableDictionary *aggregateInfo = [OGPlatformLocalNotificationUserInfo(localNotification) mutableCopy];
                if (aggregateInfo == nil)
                    aggregateInfo = [[NSMutableDictionary alloc] init];
                aggregateInfo[OGCompatAggregateFlagKey] = @true;
                OGPlatformSetLocalNotificationUserInfo(localNotification, aggregateInfo);
            }
            [TGApplyUpdatesActor presentSafeLocalNotification:(UILocalNotification *)localNotification text:text];
        }
    }
    @catch (NSException *e)
    {
    }
}

@end
