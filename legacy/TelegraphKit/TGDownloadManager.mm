#import "TGDownloadManager.h"

#import "../../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#include <set>
#include <vector>
#import <libkern/OSAtomic.h>
#import <QuartzCore/QuartzCore.h>
#import "../../OnegramRuntime/OGAutomaticDownloadPolicy.h"

#import "TGDatabase.h"

@implementation TGDownloadItem

- (id)copyWithZone:(NSZone *)__unused zone
{
    TGDownloadItem *newItem = [[TGDownloadItem alloc] init];
    
    newItem.itemId = _itemId;
    newItem.messageId = _messageId;
    newItem.path = _path;
    newItem.requestDate = _requestDate;
    newItem.progress = _progress;
    newItem.groupId = _groupId;
    newItem.automatic = _automatic;
    
    return newItem;
}

@end

#pragma mark -

@interface TGAutomaticDownloadRequest : NSObject
@property (nonatomic, strong) NSDictionary *options;
@property (nonatomic) int64_t estimatedSize;
@property (nonatomic) bool highPriority;
@property (nonatomic) bool latencySensitive;
@property (nonatomic) bool retained;
@property (nonatomic) NSUInteger retryCount;
@property (nonatomic) NSTimeInterval retryAt;
@property (nonatomic) NSTimeInterval startedAt;
@property (nonatomic, strong) NSMutableDictionary *messagePrioritiesByGroup;
- (void)setMessageId:(int32_t)messageId groupId:(int64_t)groupId highPriority:(bool)highPriority;
- (void)retainMessageIds:(NSSet *)messageIds groupId:(int64_t)groupId;
- (void)removeMessageIds:(NSSet *)messageIds groupId:(int64_t)groupId;
- (void)updatePriority;
@end

@implementation TGAutomaticDownloadRequest

- (void)setMessageId:(int32_t)messageId groupId:(int64_t)groupId highPriority:(bool)highPriority
{
    if (_messagePrioritiesByGroup == nil)
        _messagePrioritiesByGroup = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *priorities = _messagePrioritiesByGroup[@(groupId)];
    if (priorities == nil)
    {
        priorities = [[NSMutableDictionary alloc] init];
        _messagePrioritiesByGroup[@(groupId)] = priorities;
    }
    priorities[@(messageId)] = @(highPriority);
    [self updatePriority];
}

- (void)retainMessageIds:(NSSet *)messageIds groupId:(int64_t)groupId
{
    NSMutableDictionary *priorities = _messagePrioritiesByGroup[@(groupId)];
    for (NSNumber *messageId in [priorities allKeys])
    {
        if (![messageIds containsObject:messageId])
            [priorities removeObjectForKey:messageId];
    }
    if (priorities.count == 0)
        [_messagePrioritiesByGroup removeObjectForKey:@(groupId)];
    [self updatePriority];
}

- (void)removeMessageIds:(NSSet *)messageIds groupId:(int64_t)groupId
{
    NSMutableDictionary *priorities = _messagePrioritiesByGroup[@(groupId)];
    for (NSNumber *messageId in messageIds)
        [priorities removeObjectForKey:messageId];
    if (priorities.count == 0)
        [_messagePrioritiesByGroup removeObjectForKey:@(groupId)];
    [self updatePriority];
}

- (void)updatePriority
{
    _retained = _messagePrioritiesByGroup.count != 0;
    _highPriority = false;
    for (NSDictionary *priorities in [_messagePrioritiesByGroup allValues])
    {
        for (NSNumber *priority in [priorities allValues])
            _highPriority = _highPriority || [priority boolValue];
    }
}
@end

@interface TGDownloadManager ()
{
    NSMutableDictionary *_automaticRequests;
    NSMutableArray *_automaticPendingPaths;
    NSMutableSet *_automaticActivePaths;
    volatile int32_t _automaticGeneration;
    bool _automaticEnabled;
    bool _drainingAutomaticDownloads;
    int32_t _automaticPolicyGeneration;
    NSUInteger _automaticMaximumCount;
    NSUInteger (^_automaticConcurrencyLimit)(void);
    int64_t _automaticByteBudget;
    NSMutableDictionary *_automaticRetainedMessageIds;
    bool _automaticDrainScheduled;
    NSTimeInterval _automaticWakeupTime;
    uint64_t _automaticWakeupToken;
    bool _stateNotificationScheduled;
}
@property (nonatomic, strong) NSMutableDictionary *itemsQueue;
- (void)drainAutomaticDownloads;
- (void)removeAutomaticRequestForPath:(NSString *)path;
- (void)performAutomaticDownloads;
- (void)scheduleAutomaticDownloadsAtTime:(NSTimeInterval)time;
- (void)scheduleStateNotification;
@end

@implementation TGDownloadManager

+ (TGDownloadManager *)instance
{
    static TGDownloadManager *singleton = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        singleton = [[TGDownloadManager alloc] init];
    });
    
    return singleton;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:false];
        
        _itemsQueue = [[NSMutableDictionary alloc] init];
        _automaticRequests = [[NSMutableDictionary alloc] init];
        _automaticPendingPaths = [[NSMutableArray alloc] init];
        _automaticActivePaths = [[NSMutableSet alloc] init];
        _automaticRetainedMessageIds = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
}

- (void)requestItem:(NSString *)path options:(NSDictionary *)options changePriority:(bool)changePriority messageId:(int)messageId itemId:(id)itemId groupId:(int64_t)groupId itemClass:(TGDownloadItemClass)itemClass
{
    [self _requestOrJoinItem:path options:options changePriority:changePriority messageId:messageId itemId:itemId groupId:(int64_t)groupId itemClass:itemClass requestIfNotRunning:true];
}

- (void)enqueueItem:(NSString *)path messageId:(int)messageId itemId:(id)itemId groupId:(int64_t)groupId itemClass:(TGDownloadItemClass)itemClass
{
    [self _requestOrJoinItem:path options:nil changePriority:false messageId:messageId itemId:itemId groupId:(int64_t)groupId itemClass:itemClass requestIfNotRunning:false];
}

- (void)_requestOrJoinItem:(NSString *)path options:(NSDictionary *)options changePriority:(bool)changePriority messageId:(int)messageId itemId:(id)itemId groupId:(int64_t)groupId itemClass:(TGDownloadItemClass)__unused itemClass requestIfNotRunning:(bool)requestIfNotRunning
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        bool actorRunning = [ActionStageInstance() requestActorStateNow:path];
        TGDownloadItem *existingItem = _itemsQueue[path];
        if (existingItem.automatic && requestIfNotRunning)
        {
            [self removeAutomaticRequestForPath:path];
            existingItem = [existingItem copy];
            existingItem.automatic = false;
            existingItem.messageId = messageId;
            existingItem.groupId = groupId;
            _itemsQueue[path] = existingItem;
            [ActionStageInstance() requestActor:path options:options flags:(changePriority ? TGActorRequestChangePriority : 0) watcher:self];
            [self _notifyWatcher:nil failedItemIds:nil];
            [self drainAutomaticDownloads];
            return;
        }
        if (actorRunning || requestIfNotRunning)
        {   
            if ([_itemsQueue objectForKey:path] == nil)
            {
                TGDownloadItem *item = [[TGDownloadItem alloc] init];
                item.itemId = itemId;
                item.messageId = messageId;
                item.groupId = groupId;
                item.path = path;
                item.requestDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
                
                [_itemsQueue setObject:item forKey:path];
                [self _notifyWatcher:nil failedItemIds:nil];
                
                [ActionStageInstance() requestActor:path options:options flags:(changePriority ? TGActorRequestChangePriority : 0) watcher:self];
            }
            else if (actorRunning && changePriority)
            {
                [ActionStageInstance() changeActorPriority:path];
            }
        }
        else
        {
            TGLog(@"***** Download Manager: being asked to join nonexistent request");
        }
    }];
}

- (void)cancelItem:(id)itemId
{
    if (itemId == nil)
        return;
    
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSMutableArray *removeKeys = [[NSMutableArray alloc] init];
        
        [_itemsQueue enumerateKeysAndObjectsUsingBlock:^(NSString *path, TGDownloadItem *item, __unused BOOL *stop)
        {
            if (item.itemId != nil && [item.itemId isEqual:itemId])
            {
                [removeKeys addObject:path];
                
                if ([item.itemId isKindOfClass:[TGMediaId class]])
                {
                    TGMediaId *mediaId = item.itemId;
                    if (mediaId.itemId != 0)
                    {
                        [TGDatabaseInstance() updateLastUseDateForMediaType:mediaId.type mediaId:mediaId.itemId messageId:item.messageId];
                    }
                }
            }
        }];
        
        for (NSString *path in removeKeys)
        {
            [self removeAutomaticRequestForPath:path];
            [_itemsQueue removeObjectForKey:path];
            [ActionStageInstance() removeWatcher:self fromPath:path];
        }
        
        if (removeKeys.count != 0)
            [self _notifyWatcher:nil failedItemIds:[[NSArray alloc] initWithObjects:itemId, nil]];
        [self drainAutomaticDownloads];
    }];
}

- (void)cancelItemsWithMessageIdsInArray:(NSArray *)messageIds groupId:(int64_t)groupId
{
    if (messageIds.count == 0)
        return;
    NSSet *messageIdsToRemove = [NSSet setWithArray:messageIds];
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        NSSet *retainedIds = _automaticRetainedMessageIds[@(groupId)];
        if (retainedIds != nil)
        {
            NSMutableSet *remainingIds = [retainedIds mutableCopy];
            [remainingIds minusSet:messageIdsToRemove];
            _automaticRetainedMessageIds[@(groupId)] = [remainingIds copy];
        }
        if (_itemsQueue.count == 0)
            return;
        
        std::set<int> messageIdsSet;
        for (NSNumber *nMessageId in messageIds)
        {
            messageIdsSet.insert([nMessageId intValue]);
        }
        
        NSMutableArray *removeKeys = [[NSMutableArray alloc] init];
        NSMutableArray *removeMediaIds = [[NSMutableArray alloc] init];
        
        [_itemsQueue enumerateKeysAndObjectsUsingBlock:^(NSString *path, TGDownloadItem *item, __unused BOOL *stop)
        {
            TGAutomaticDownloadRequest *request = _automaticRequests[path];
            bool removeItem = messageIdsSet.find(item.messageId) != messageIdsSet.end() && item.groupId == groupId;
            if (request != nil)
            {
                bool hadReferences = request.messagePrioritiesByGroup[@(groupId)] != nil;
                [request removeMessageIds:messageIdsToRemove groupId:groupId];
                removeItem = !request.retained && (hadReferences || removeItem);
            }
            if (removeItem)
            {
                if (item.itemId != nil)
                    [removeMediaIds addObject:item.itemId];
                [removeKeys addObject:path];
                
                if ([item.itemId isKindOfClass:[TGMediaId class]])
                {
                    TGMediaId *mediaId = item.itemId;
                    if (mediaId.itemId != 0)
                    {
                        [TGDatabaseInstance() updateLastUseDateForMediaType:mediaId.type mediaId:mediaId.itemId messageId:item.messageId];
                    }
                }
            }
        }];
        
        for (NSString *path in removeKeys)
        {
            [self removeAutomaticRequestForPath:path];
            [_itemsQueue removeObjectForKey:path];
            [ActionStageInstance() removeWatcher:self fromPath:path];
        }
        
        [self _notifyWatcher:nil failedItemIds:removeMediaIds];
        [self drainAutomaticDownloads];
    }];
}

- (void)cancelItemsWithGroupId:(int64_t)groupId
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        _automaticRetainedMessageIds[@(groupId)] = [NSSet set];
        if (_itemsQueue.count == 0)
            return;
        
        NSMutableArray *removeKeys = [[NSMutableArray alloc] init];
        NSMutableArray *removeMediaIds = [[NSMutableArray alloc] init];
        
        [_itemsQueue enumerateKeysAndObjectsUsingBlock:^(NSString *path, TGDownloadItem *item, __unused BOOL *stop)
        {
            TGAutomaticDownloadRequest *request = _automaticRequests[path];
            bool removeItem = item.groupId == groupId;
            if (request != nil)
            {
                bool hadReferences = request.messagePrioritiesByGroup[@(groupId)] != nil;
                [request retainMessageIds:nil groupId:groupId];
                removeItem = !request.retained && (hadReferences || removeItem);
            }
            if (removeItem)
            {
                if (item.itemId != nil)
                    [removeMediaIds addObject:item.itemId];
                [removeKeys addObject:path];
                
                if ([item.itemId isKindOfClass:[TGMediaId class]])
                {
                    TGMediaId *mediaId = item.itemId;
                    if (mediaId.itemId != 0)
                    {
                        [TGDatabaseInstance() updateLastUseDateForMediaType:mediaId.type mediaId:mediaId.itemId messageId:item.messageId];
                    }
                }
            }
        }];
        
        for (NSString *path in removeKeys)
        {
            [self removeAutomaticRequestForPath:path];
            [_itemsQueue removeObjectForKey:path];
            [ActionStageInstance() removeWatcher:self fromPath:path];
        }
        
        [self _notifyWatcher:nil failedItemIds:removeMediaIds];
        [self drainAutomaticDownloads];
    }];
}

- (int32_t)automaticDownloadGeneration
{
    return OSAtomicAdd32Barrier(0, &_automaticGeneration);
}

- (void)configureAutomaticDownloadsEnabled:(bool)enabled maximumCount:(NSUInteger)maximumCount concurrencyLimit:(NSUInteger (^)(void))concurrencyLimit byteBudget:(int64_t)byteBudget
{
    int32_t generation = OSAtomicIncrement32Barrier(&_automaticGeneration);
    [ActionStageInstance() dispatchOnStageQueue:^{
        _automaticPolicyGeneration = generation;
        _automaticEnabled = enabled;
        _automaticMaximumCount = MAX((NSUInteger)1, maximumCount);
        _automaticConcurrencyLimit = [concurrencyLimit copy];
        _automaticByteBudget = MAX((int64_t)1, byteBudget);
        _automaticWakeupTime = 0.0;
        _automaticWakeupToken++;
        NSMutableArray *cancelledIds = [[NSMutableArray alloc] init];
        for (NSString *path in [_automaticRequests allKeys])
        {
            TGDownloadItem *item = _itemsQueue[path];
            if (item.automatic)
            {
                if (item.itemId != nil)
                    [cancelledIds addObject:item.itemId];
                [_itemsQueue removeObjectForKey:path];
                [ActionStageInstance() removeWatcher:self fromPath:path];
            }
        }
        [_automaticRequests removeAllObjects];
        [_automaticPendingPaths removeAllObjects];
        [_automaticActivePaths removeAllObjects];
        if (cancelledIds.count != 0)
            [self _notifyWatcher:nil failedItemIds:cancelledIds];
    }];
}

- (void)removeAutomaticRequestForPath:(NSString *)path
{
    [_automaticRequests removeObjectForKey:path];
    [_automaticPendingPaths removeObject:path];
    [_automaticActivePaths removeObject:path];
}

- (void)requestAutomaticItem:(NSString *)path options:(NSDictionary *)options highPriority:(bool)highPriority messageId:(int32_t)messageId itemId:(id)itemId groupId:(int64_t)groupId itemClass:(TGDownloadItemClass)itemClass estimatedSize:(int64_t)estimatedSize generation:(int32_t)generation
{
    if (path.length == 0)
        return;
    [ActionStageInstance() dispatchOnStageQueue:^{
        if (!_automaticEnabled || generation != [self automaticDownloadGeneration])
            return;
        NSSet *retainedIds = _automaticRetainedMessageIds[@(groupId)];
        if (retainedIds != nil && ![retainedIds containsObject:@(messageId)])
            return;
        TGDownloadItem *existingItem = _itemsQueue[path];
        if (existingItem != nil)
        {
            TGAutomaticDownloadRequest *request = _automaticRequests[path];
            if (request != nil)
            {
                bool raisedPriority = highPriority && !request.highPriority;
                [request setMessageId:messageId groupId:groupId highPriority:highPriority];
                request.options = [options copy];
                if (raisedPriority && [_automaticActivePaths containsObject:path])
                    [ActionStageInstance() changeActorPriority:path];
            }
            [self drainAutomaticDownloads];
            return;
        }
        if ([ActionStageInstance() requestActorStateNow:path])
        {
            [self enqueueItem:path messageId:messageId itemId:itemId groupId:groupId itemClass:itemClass];
            return;
        }
        TGDownloadItem *item = [[TGDownloadItem alloc] init];
        item.itemId = itemId;
        item.messageId = messageId;
        item.groupId = groupId;
        item.path = path;
        item.requestDate = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970;
        item.automatic = true;
        TGAutomaticDownloadRequest *request = [[TGAutomaticDownloadRequest alloc] init];
        request.options = [options copy];
        request.estimatedSize = estimatedSize > 0 ? estimatedSize : 2 * 1024 * 1024;
        request.latencySensitive = itemClass == TGDownloadItemClassImage && request.estimatedSize <= 2 * 1024 * 1024;
        [request setMessageId:messageId groupId:groupId highPriority:highPriority];
        _itemsQueue[path] = item;
        _automaticRequests[path] = request;
        [_automaticPendingPaths addObject:path];
        [self scheduleStateNotification];
        [self drainAutomaticDownloads];
    }];
}

- (void)drainAutomaticDownloads
{
    if (_automaticDrainScheduled)
        return;
    _automaticDrainScheduled = true;
    dispatch_async([ActionStageInstance() globalStageDispatchQueue], ^
    {
        _automaticDrainScheduled = false;
        [self performAutomaticDownloads];
    });
}

- (void)scheduleAutomaticDownloadsAtTime:(NSTimeInterval)time
{
    if (_automaticWakeupTime != 0.0 && _automaticWakeupTime <= time)
        return;
    _automaticWakeupTime = time;
    uint64_t token = ++_automaticWakeupToken;
    NSTimeInterval delay = MAX(0.0, time - CACurrentMediaTime());
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), [ActionStageInstance() globalStageDispatchQueue], ^
    {
        if (token != _automaticWakeupToken)
            return;
        _automaticWakeupTime = 0.0;
        [self drainAutomaticDownloads];
    });
}

- (void)performAutomaticDownloads
{
    if (!_automaticEnabled || _drainingAutomaticDownloads || _automaticPolicyGeneration != [self automaticDownloadGeneration])
        return;
    NSUInteger maximumCount = _automaticMaximumCount;
    if (_automaticConcurrencyLimit != nil)
        maximumCount = MIN(maximumCount, MAX((NSUInteger)1, _automaticConcurrencyLimit()));
    for (TGDownloadItem *item in [_itemsQueue allValues])
    {
        if (!item.automatic)
        {
            maximumCount = 1;
            break;
        }
    }
    _drainingAutomaticDownloads = true;
    @try
    {
        while (_automaticPendingPaths.count != 0 && _automaticPolicyGeneration == [self automaticDownloadGeneration])
        {
            NSTimeInterval now = CACurrentMediaTime();
            int64_t activeBytes = 0;
            int64_t activeLatencyBytes = 0;
            for (NSString *activePath in _automaticActivePaths)
            {
                TGAutomaticDownloadRequest *active = _automaticRequests[activePath];
                activeBytes += active.estimatedSize;
                if (active.latencySensitive)
                    activeLatencyBytes += active.estimatedSize;
            }

            std::vector<OGAutomaticDownloadCandidate> candidates;
            candidates.reserve(_automaticPendingPaths.count);
            bool visibleWaiting = false;
            bool visibleLatencyWaiting = false;
            for (NSString *pendingPath in _automaticPendingPaths)
            {
                TGAutomaticDownloadRequest *pending = _automaticRequests[pendingPath];
                OGAutomaticDownloadCandidate candidate = {pending.estimatedSize, pending.retryAt, pending.highPriority, pending.latencySensitive};
                candidates.push_back(candidate);
                visibleWaiting = visibleWaiting || (pending.highPriority && pending.retryAt <= now);
                visibleLatencyWaiting = visibleLatencyWaiting || (pending.highPriority && pending.latencySensitive && pending.retryAt <= now);
                if (pending.retryAt > now)
                    [self scheduleAutomaticDownloadsAtTime:pending.retryAt];
            }
            size_t selected = _automaticActivePaths.count < maximumCount ?
                OGAutomaticDownloadSelect(candidates.data(), candidates.size(), _automaticActivePaths.count, activeBytes, activeLatencyBytes, _automaticByteBudget, now) : SIZE_MAX;
            if (selected == SIZE_MAX && visibleWaiting)
            {
                NSString *preemptedPath = nil;
                float leastProgress = 1.0f;
                for (NSString *activePath in _automaticActivePaths)
                {
                    TGAutomaticDownloadRequest *active = _automaticRequests[activePath];
                    TGDownloadItem *item = _itemsQueue[activePath];
                    bool protectedPriority = active.highPriority && (!visibleLatencyWaiting || active.latencySensitive);
                    if (OGAutomaticDownloadCanPreempt(protectedPriority, active.startedAt, now, item.progress) && item.progress < leastProgress)
                    {
                        preemptedPath = activePath;
                        leastProgress = item.progress;
                    }
                    else if (!protectedPriority && item.progress < 0.9f && active.startedAt + 1.0 > now)
                        [self scheduleAutomaticDownloadsAtTime:active.startedAt + 1.0];
                }
                if (preemptedPath != nil)
                {
                    TGAutomaticDownloadRequest *preempted = _automaticRequests[preemptedPath];
                    [_automaticActivePaths removeObject:preemptedPath];
                    [ActionStageInstance() removeWatcher:self fromPath:preemptedPath];
                    if (preempted.retained)
                        [_automaticPendingPaths addObject:preemptedPath];
                    else
                    {
                        TGDownloadItem *item = _itemsQueue[preemptedPath];
                        [self removeAutomaticRequestForPath:preemptedPath];
                        [_itemsQueue removeObjectForKey:preemptedPath];
                        [self _notifyWatcher:nil failedItemIds:item.itemId != nil ? @[item.itemId] : nil];
                    }
                    continue;
                }
            }
            if (selected == SIZE_MAX)
                break;
            NSString *path = _automaticPendingPaths[selected];
            TGAutomaticDownloadRequest *request = _automaticRequests[path];
            [_automaticPendingPaths removeObjectAtIndex:selected];
            [_automaticActivePaths addObject:path];
            request.startedAt = now;
            [ActionStageInstance() requestActor:path options:request.options flags:(request.highPriority ? TGActorRequestChangePriority : 0) watcher:self];
        }
    }
    @finally
    {
        _drainingAutomaticDownloads = false;
    }
}

- (void)retainAutomaticItemsWithMessageIds:(NSArray *)messageIds groupId:(int64_t)groupId
{
    NSSet *retainedIds = messageIds == nil ? nil : [NSSet setWithArray:messageIds];
    [ActionStageInstance() dispatchOnStageQueue:^{
        _automaticRetainedMessageIds[@(groupId)] = retainedIds ?: [NSSet set];
        NSMutableArray *cancelledIds = [[NSMutableArray alloc] init];
        for (NSString *path in [_automaticRequests allKeys])
        {
            TGDownloadItem *item = _itemsQueue[path];
            TGAutomaticDownloadRequest *request = _automaticRequests[path];
            bool ownsGroup = request.messagePrioritiesByGroup[@(groupId)] != nil;
            bool abandonedGroup = retainedIds == nil && !request.retained && item.groupId == groupId;
            if (!item.automatic || (!ownsGroup && !abandonedGroup))
                continue;
            [request retainMessageIds:retainedIds groupId:groupId];
            if (request.retained)
                continue;
            if (retainedIds != nil && [_automaticActivePaths containsObject:path])
                continue;
            if (item.itemId != nil)
                [cancelledIds addObject:item.itemId];
            [self removeAutomaticRequestForPath:path];
            [_itemsQueue removeObjectForKey:path];
            [ActionStageInstance() removeWatcher:self fromPath:path];
        }
        if (cancelledIds.count != 0)
            [self _notifyWatcher:nil failedItemIds:cancelledIds];
        [self drainAutomaticDownloads];
    }];
}

- (void)cancelAutomaticItemsWithGroupId:(int64_t)groupId
{
    [self retainAutomaticItemsWithMessageIds:nil groupId:groupId];
}

- (void)requestState:(ASHandle *)watcherHandle
{
    [ActionStageInstance() dispatchOnStageQueue:^
    {
        [watcherHandle notifyResourceDispatched:@"downloadManagerStateChanged" resource:[_itemsQueue copy] arguments:@{@"requested": @true}];
    }];
}

#pragma mark -

- (void)_notifyWatcher:(NSArray *)completedItemIds failedItemIds:(NSArray *)failedItemIds
{
    _stateNotificationScheduled = false;
    NSDictionary *arguments = nil;
    if (completedItemIds != nil || failedItemIds != nil)
    {
        if (failedItemIds == nil)
            arguments = [[NSDictionary alloc] initWithObjectsAndKeys:completedItemIds, @"completedItemIds", nil];
        else if (completedItemIds == nil)
            arguments = [[NSDictionary alloc] initWithObjectsAndKeys:failedItemIds, @"failedItemIds", nil];
        else
            arguments = [[NSDictionary alloc] initWithObjectsAndKeys:completedItemIds, @"completedItemIds", failedItemIds, @"failedItemIds", nil];
    }
    [ActionStageInstance() dispatchResource:@"downloadManagerStateChanged" resource:[_itemsQueue copy] arguments:arguments];
}

- (void)scheduleStateNotification
{
    if (_stateNotificationScheduled)
        return;
    _stateNotificationScheduled = true;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), [ActionStageInstance() globalStageDispatchQueue], ^
    {
        if (!_stateNotificationScheduled)
            return;
        [self _notifyWatcher:nil failedItemIds:nil];
    });
}

#pragma mark -

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    TGDownloadItem *item = [_itemsQueue objectForKey:path];
    if (item != nil)
    {
        if ([messageType isEqualToString:@"progress"])
        {
            item = [item copy];
            item.progress = [message floatValue];
            [_itemsQueue setObject:item forKey:path];
            [self scheduleStateNotification];
        }
    }
}

- (void)actorReportedProgress:(NSString *)path progress:(float)progress
{
    TGDownloadItem *item = [_itemsQueue objectForKey:path];
    if (item != nil)
    {
        item = [item copy];
        item.progress = progress;
        [_itemsQueue setObject:item forKey:path];
        [self scheduleStateNotification];
    }
}

- (void)actorCompleted:(int)status path:(NSString *)path result:(id)__unused result
{
    TGDownloadItem *item = [_itemsQueue objectForKey:path];
    if (item != nil)
    {
        TGAutomaticDownloadRequest *request = _automaticRequests[path];
        if (status != ASStatusSuccess && request.retained && _automaticEnabled)
        {
            NSTimeInterval delay = OGAutomaticDownloadRetryDelay(request.retryCount);
            if (delay > 0.0)
            {
                request.retryCount++;
                request.retryAt = CACurrentMediaTime() + delay;
                [_automaticActivePaths removeObject:path];
                if (![_automaticPendingPaths containsObject:path])
                    [_automaticPendingPaths addObject:path];
                [self scheduleStateNotification];
                [self drainAutomaticDownloads];
                return;
            }
        }
        [self removeAutomaticRequestForPath:path];
        [_itemsQueue removeObjectForKey:path];
        NSArray *itemIds = item.itemId != nil ? @[item.itemId] : nil;
        [self _notifyWatcher:status == ASStatusSuccess ? itemIds : nil failedItemIds:status == ASStatusSuccess ? nil : itemIds];
        
        if ([item.itemId isKindOfClass:[TGMediaId class]])
        {
            TGMediaId *mediaId = item.itemId;
            if (mediaId.itemId != 0)
            {
                [TGDatabaseInstance() updateLastUseDateForMediaType:mediaId.type mediaId:mediaId.itemId messageId:item.messageId];
            }
        }
        [self drainAutomaticDownloads];
    }
}

@end
