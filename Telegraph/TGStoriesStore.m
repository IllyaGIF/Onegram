#import "TGStoriesStore.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGStoryItem.h"
#import "TGStoriesSignals.h"
#import "TGTelegraph.h"
#import "../OnegramRuntime/OGRemoteClock.h"

NSString *const TGStoriesStoreDidChangeNotification = @"TGStoriesStoreDidChangeNotification";

static const NSTimeInterval TGStoriesStoreRefreshInterval = 60.0;
static const NSUInteger TGStoriesStoreMaxPages = 5;

@interface TGStoriesStore ()
{
    NSMutableDictionary *_peerStories;
    NSArray *_peerOrder;
    NSString *_state;
    NSTimeInterval _lastRefreshTime;
    SMetaDisposable *_refreshDisposable;
    SMetaDisposable *_readDisposable;
    NSMutableDictionary *_pendingReadMaxIds;
    bool _refreshing;
    int64_t _accountUserId;
}

@end

@implementation TGStoriesStore

+ (TGStoriesStore *)instance
{
    static TGStoriesStore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        instance = [[TGStoriesStore alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _peerStories = [[NSMutableDictionary alloc] init];
        _peerOrder = @[];
        _refreshDisposable = [[SMetaDisposable alloc] init];
        _readDisposable = [[SMetaDisposable alloc] init];
        _pendingReadMaxIds = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)resetIfAccountChanged
{
    int64_t userId = TGTelegraphInstance.clientUserId;
    if (userId == _accountUserId)
        return;
    _accountUserId = userId;
    [_peerStories removeAllObjects];
    _peerOrder = @[];
    _state = nil;
    _lastRefreshTime = 0.0;
    [_refreshDisposable setDisposable:nil];
    [_pendingReadMaxIds removeAllObjects];
    _refreshing = false;
}

- (void)notifyChanged
{
    [[NSNotificationCenter defaultCenter] postNotificationName:TGStoriesStoreDidChangeNotification object:self];
}

- (NSArray *)orderedPeerStories
{
    NSTimeInterval now = OGRemoteClockTime();
    NSMutableArray *result = [[NSMutableArray alloc] init];
    TGPeerStories *own = [_peerStories objectForKey:@(TGTelegraphInstance.clientUserId)];
    if ([self hasActiveStories:own atTime:now])
        [result addObject:own];
    NSMutableArray *unread = [[NSMutableArray alloc] init];
    NSMutableArray *read = [[NSMutableArray alloc] init];
    for (NSNumber *peerId in _peerOrder)
    {
        if ([peerId longLongValue] == TGTelegraphInstance.clientUserId)
            continue;
        TGPeerStories *peerStories = [_peerStories objectForKey:peerId];
        if (![self hasActiveStories:peerStories atTime:now])
            continue;
        [([peerStories hasUnread] ? unread : read) addObject:peerStories];
    }
    [result addObjectsFromArray:unread];
    [result addObjectsFromArray:read];
    return result;
}

- (bool)hasActiveStories:(TGPeerStories *)peerStories atTime:(NSTimeInterval)time
{
    for (TGStoryItem *item in peerStories.stories)
    {
        if ([item isActiveAtTime:time])
            return true;
    }
    return false;
}

- (TGPeerStories *)peerStoriesForPeerId:(int64_t)peerId
{
    TGPeerStories *peerStories = [_peerStories objectForKey:@(peerId)];
    return [self hasActiveStories:peerStories atTime:OGRemoteClockTime()] ? peerStories : nil;
}

- (void)refreshIfNeeded
{
    [self resetIfAccountChanged];
    if (_refreshing || TGTelegraphInstance.clientUserId == 0)
        return;
    if (_lastRefreshTime > DBL_EPSILON && CFAbsoluteTimeGetCurrent() - _lastRefreshTime < TGStoriesStoreRefreshInterval)
        return;
    [self refresh];
}

- (void)refresh
{
    [self resetIfAccountChanged];
    if (TGTelegraphInstance.clientUserId == 0)
        return;
    _refreshing = true;
    _lastRefreshTime = CFAbsoluteTimeGetCurrent();
    __weak TGStoriesStore *weakSelf = self;
    [_refreshDisposable setDisposable:[[[self pagesSignalWithState:nil next:false collected:@[] pageIndex:0] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *result)
    {
        __strong TGStoriesStore *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf applyRefreshResult:result];
    } error:^(__unused id error)
    {
        __strong TGStoriesStore *strongSelf = weakSelf;
        if (strongSelf != nil)
            strongSelf->_refreshing = false;
    } completed:nil]];
}

- (SSignal *)pagesSignalWithState:(NSString *)state next:(bool)next collected:(NSArray *)collected pageIndex:(NSUInteger)pageIndex
{
    return [[TGStoriesSignals allStoriesWithState:state next:next hidden:false] mapToSignal:^SSignal *(TGAllStoriesResult *result)
    {
        NSArray *items = [collected arrayByAddingObjectsFromArray:result.peerStories];
        if (result.hasMore && result.state.length != 0 && pageIndex + 1 < TGStoriesStoreMaxPages)
            return [self pagesSignalWithState:result.state next:true collected:items pageIndex:pageIndex + 1];
        NSMutableDictionary *output = [[NSMutableDictionary alloc] init];
        output[@"peerStories"] = items;
        if (result.state != nil)
            output[@"state"] = result.state;
        return [SSignal single:output];
    }];
}

- (void)applyRefreshResult:(NSDictionary *)result
{
    _refreshing = false;
    _state = result[@"state"];
    NSMutableArray *order = [[NSMutableArray alloc] init];
    NSMutableDictionary *peerStories = [[NSMutableDictionary alloc] init];
    for (TGPeerStories *item in result[@"peerStories"])
    {
        NSNumber *key = @(item.peerId);
        TGPeerStories *existing = [_peerStories objectForKey:key];
        TGPeerStories *merged = existing == nil ? item : [item peerStoriesWithMaxReadId:existing.maxReadId];
        NSNumber *pendingRead = [_pendingReadMaxIds objectForKey:key];
        if (pendingRead != nil)
            merged = [merged peerStoriesWithMaxReadId:[pendingRead intValue]];
        [peerStories setObject:merged forKey:key];
        [order addObject:key];
    }
    TGPeerStories *own = [_peerStories objectForKey:@(TGTelegraphInstance.clientUserId)];
    if (own != nil && [peerStories objectForKey:@(own.peerId)] == nil)
        [peerStories setObject:own forKey:@(own.peerId)];
    _peerStories = peerStories;
    _peerOrder = order;
    [self notifyChanged];
}

- (SSignal *)peerStoriesSignal:(int64_t)peerId
{
    __weak TGStoriesStore *weakSelf = self;
    return [[[TGStoriesSignals peerStories:peerId] deliverOn:[SQueue mainQueue]] onNext:^(TGPeerStories *peerStories)
    {
        __strong TGStoriesStore *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf setPeerStories:peerStories];
    }];
}

- (void)setPeerStories:(TGPeerStories *)peerStories
{
    if (peerStories == nil)
        return;
    [self resetIfAccountChanged];
    NSNumber *key = @(peerStories.peerId);
    TGPeerStories *existing = [_peerStories objectForKey:key];
    TGPeerStories *value = existing == nil ? peerStories : [peerStories peerStoriesWithMaxReadId:existing.maxReadId];
    [_peerStories setObject:value forKey:key];
    if (![_peerOrder containsObject:key] && value.stories.count != 0)
        _peerOrder = [_peerOrder arrayByAddingObject:key];
    [self notifyChanged];
}

- (void)addStories:(NSArray *)stories forPeerId:(int64_t)peerId
{
    if (stories.count == 0)
        return;
    NSNumber *key = @(peerId);
    TGPeerStories *existing = [_peerStories objectForKey:key];
    if (existing == nil)
        existing = [[TGPeerStories alloc] initWithPeerId:peerId maxReadId:peerId == TGTelegraphInstance.clientUserId ? INT32_MAX : 0 stories:@[]];
    [_peerStories setObject:[existing peerStoriesByMergingStories:stories] forKey:key];
    if (![_peerOrder containsObject:key])
        _peerOrder = [@[key] arrayByAddingObjectsFromArray:_peerOrder];
    [self notifyChanged];
}

- (void)removeStoryIds:(NSArray *)storyIds forPeerId:(int64_t)peerId
{
    NSNumber *key = @(peerId);
    TGPeerStories *existing = [_peerStories objectForKey:key];
    if (existing == nil || storyIds.count == 0)
        return;
    NSMutableArray *remaining = [[NSMutableArray alloc] init];
    for (TGStoryItem *item in existing.stories)
    {
        if (![storyIds containsObject:@(item.storyId)])
            [remaining addObject:item];
    }
    [_peerStories setObject:[[TGPeerStories alloc] initWithPeerId:peerId maxReadId:existing.maxReadId stories:remaining] forKey:key];
    [self notifyChanged];
}

- (void)updateStory:(TGStoryItem *)story
{
    if (story == nil)
        return;
    NSNumber *key = @(story.peerId);
    TGPeerStories *existing = [_peerStories objectForKey:key];
    if (existing == nil)
        return;
    bool found = false;
    for (TGStoryItem *item in existing.stories)
    {
        if (item.storyId == story.storyId)
        {
            found = true;
            break;
        }
    }
    if (!found)
        return;
    [_peerStories setObject:[existing peerStoriesByMergingStories:@[story]] forKey:key];
    [self notifyChanged];
}

- (void)markStory:(TGStoryItem *)story seenForPeerId:(int64_t)peerId
{
    if (story == nil || peerId == TGTelegraphInstance.clientUserId)
        return;
    NSNumber *key = @(peerId);
    TGPeerStories *existing = [_peerStories objectForKey:key];
    if (existing != nil && story.storyId <= existing.maxReadId)
        return;
    NSNumber *pending = [_pendingReadMaxIds objectForKey:key];
    if (pending != nil && story.storyId <= [pending intValue])
        return;
    [_pendingReadMaxIds setObject:@(story.storyId) forKey:key];
    if (existing != nil)
    {
        [_peerStories setObject:[existing peerStoriesWithMaxReadId:story.storyId] forKey:key];
        [self notifyChanged];
    }
    [self flushReadsLater];
}

- (void)flushReadsLater
{
    __weak TGStoriesStore *weakSelf = self;
    [_readDisposable setDisposable:[[[SSignal complete] delay:1.0 onQueue:[SQueue mainQueue]] startWithNext:nil error:nil completed:^
    {
        __strong TGStoriesStore *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf flushReads];
    }]];
}

- (void)flushReads
{
    NSDictionary *reads = [_pendingReadMaxIds copy];
    [_pendingReadMaxIds removeAllObjects];
    for (NSNumber *peerId in reads)
    {
        int32_t maxId = [[reads objectForKey:peerId] intValue];
        [[TGStoriesSignals readStories:[peerId longLongValue] maxId:maxId] startWithNext:nil];
    }
}

@end
