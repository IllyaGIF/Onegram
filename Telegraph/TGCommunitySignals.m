#import "TGCommunitySignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TL/TLMetaScheme.h"
#import "TGTelegramNetworking.h"
#import "TGDatabase.h"
#import "TGUserDataRequestBuilder.h"
#import "TGChannelManagementSignals.h"
#import "TGConversation+Telegraph.h"

#import "TLChat$channel.h"
#import "TLChat$community.h"
#import "TLChat$communityForbidden.h"
#import "TLChatFull$communityFull.h"
#import "TLCommunityPeer.h"
#import "TLRPCcommunities_getJoinedCommunities.h"

static NSString *const TGCommunityLinksSynchronizationVersionKey = @"communityLinksSynchronizationVersion";
static const int32_t TGCommunityLinksSynchronizationVersion = 1;
static const NSUInteger TGCommunityLinksBatchSize = 100;

static NSMutableDictionary *TGCommunityCache(void)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });
    return cache;
}

static NSString *TGCommunityStorageKey(int64_t communityId)
{
    return [[NSString alloc] initWithFormat:@"community.%lld", communityId];
}

static TGCommunity *TGCommunityFromChat(TLChat *chat)
{
    if ([chat isKindOfClass:[TLChat$community class]])
    {
        TLChat$community *community = (TLChat$community *)chat;
        if (community.community_id == 0)
            return nil;
        return [[TGCommunity alloc] initWithCommunityId:community.community_id accessHash:community.access_hash title:community.title];
    }
    if ([chat isKindOfClass:[TLChat$communityForbidden class]])
    {
        TLChat$communityForbidden *community = (TLChat$communityForbidden *)chat;
        if (community.community_id == 0)
            return nil;
        return [[TGCommunity alloc] initWithCommunityId:community.community_id accessHash:community.access_hash title:community.title];
    }
    return nil;
}

@implementation TGCommunitySignals

+ (TGCommunity *)cachedCommunityWithId:(int64_t)communityId
{
    if (communityId == 0)
        return nil;

    NSMutableDictionary *cache = TGCommunityCache();
    @synchronized (cache)
    {
        id cached = cache[@(communityId)];
        if ([cached isKindOfClass:[TGCommunity class]])
            return cached;
        if (cached != nil)
            return nil;
    }

    TGCommunity *community = nil;
    NSData *data = [TGDatabaseInstance() customProperty:TGCommunityStorageKey(communityId)];
    if (data.length != 0)
        community = [[TGCommunity alloc] initWithKeyValueCoder:[[PSKeyValueDecoder alloc] initWithData:data]];

    @synchronized (cache)
    {
        id current = cache[@(communityId)];
        if ([current isKindOfClass:[TGCommunity class]])
            return current;
        cache[@(communityId)] = community != nil ? community : [NSNull null];
    }
    return community;
}

+ (void)storeCommunity:(TGCommunity *)community
{
    TGCommunity *existing = [self cachedCommunityWithId:community.communityId];
    TGCommunity *merged = existing != nil ? [existing communityByMergingCommunity:community] : community;
    if ([merged isEqual:existing])
        return;

    NSMutableDictionary *cache = TGCommunityCache();
    @synchronized (cache)
    {
        cache[@(merged.communityId)] = merged;
    }

    PSKeyValueEncoder *encoder = [[PSKeyValueEncoder alloc] init];
    [merged encodeWithKeyValueCoder:encoder];
    [TGDatabaseInstance() setCustomProperty:TGCommunityStorageKey(merged.communityId) value:[encoder data]];
}

+ (void)storeCommunitiesFromChats:(NSArray *)chats
{
    for (TLChat *chat in chats)
    {
        TGCommunity *community = TGCommunityFromChat(chat);
        if (community != nil)
            [self storeCommunity:community];
    }
}

+ (SSignal *)joinedCommunitiesSignal
{
    TLRPCcommunities_getJoinedCommunities *request = [[TLRPCcommunities_getJoinedCommunities alloc] init];
    return [[[TGTelegramNetworking instance] requestSignal:request] map:^id(TLmessages_Chats *result)
    {
        [self storeCommunitiesFromChats:result.chats];
        return @true;
    }];
}

+ (SSignal *)linkedChannelSignalForConversation:(TGConversation *)conversation
{
    TLInputChannel *inputChannel = [TGChannelManagementSignals inputChannelForPeerId:conversation.conversationId accessHash:conversation.accessHash];
    if (inputChannel == nil)
        return [SSignal fail:nil];

    TLRPCchannels_getChannels$channels_getChannels *request = [[TLRPCchannels_getChannels$channels_getChannels alloc] init];
    request.n_id = @[inputChannel];
    return [[[TGTelegramNetworking instance] requestSignal:request] map:^id(TLmessages_Chats *result)
    {
        [self storeCommunitiesFromChats:result.chats];
        [TGChannelManagementSignals storeChannelChats:result.chats];
        return @true;
    }];
}

+ (SSignal *)resolvedCommunityWithId:(int64_t)communityId conversation:(TGConversation *)conversation
{
    SSignal *(^cachedSignal)(void) = ^SSignal *
    {
        TGCommunity *community = [self cachedCommunityWithId:communityId];
        if (community.accessHash == 0)
            return nil;
        return [SSignal single:community];
    };

    SSignal *cached = cachedSignal();
    if (cached != nil)
        return cached;

    return [[self joinedCommunitiesSignal] mapToSignal:^SSignal *(__unused id next)
    {
        SSignal *joined = cachedSignal();
        if (joined != nil)
            return joined;

        return [[self linkedChannelSignalForConversation:conversation] mapToSignal:^SSignal *(__unused id channelNext)
        {
            SSignal *linked = cachedSignal();
            return linked != nil ? linked : [SSignal fail:nil];
        }];
    }];
}

+ (SSignal *)chatsForCommunity:(TGCommunity *)community
{
    TLInputChannel$inputChannel *inputChannel = [[TLInputChannel$inputChannel alloc] init];
    inputChannel.channel_id = community.communityId;
    inputChannel.access_hash = community.accessHash;

    TLRPCchannels_getFullChannel$channels_getFullChannel *request = [[TLRPCchannels_getFullChannel$channels_getFullChannel alloc] init];
    request.channel = inputChannel;

    return [[[TGTelegramNetworking instance] requestSignal:request] mapToSignal:^SSignal *(TLmessages_ChatFull *result)
    {
        if (![result.full_chat isKindOfClass:[TLChatFull$communityFull class]])
            return [SSignal fail:nil];

        TLChatFull$communityFull *communityFull = (TLChatFull$communityFull *)result.full_chat;

        [TGUserDataRequestBuilder executeUserDataUpdate:result.users];
        [self storeCommunitiesFromChats:result.chats];
        [TGChannelManagementSignals storeChannelChats:result.chats];

        NSMutableDictionary *channelsById = [[NSMutableDictionary alloc] init];
        for (TLChat *chat in result.chats)
        {
            if ([chat isKindOfClass:[TLChat$channel class]])
                channelsById[@(chat.n_id)] = chat;
        }

        NSMutableArray *joinedConversations = [[NSMutableArray alloc] init];
        NSMutableArray *viewableConversations = [[NSMutableArray alloc] init];
        for (TLCommunityPeer *linkedPeer in communityFull.linked_peers)
        {
            if (![linkedPeer isKindOfClass:[TLCommunityPeer class]] || ![linkedPeer.peer isKindOfClass:[TLPeer$peerChannel class]])
                continue;

            TLChat *chat = channelsById[@(((TLPeer$peerChannel *)linkedPeer.peer).channel_id)];
            if (chat == nil)
                continue;

            TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chat];
            if (conversation.conversationId == 0)
                continue;

            if (!conversation.leftChat && !conversation.kickedFromChat)
                [joinedConversations addObject:conversation];
            else if (linkedPeer.can_view_history)
                [viewableConversations addObject:conversation];
        }

        TGCommunity *resolved = [self cachedCommunityWithId:community.communityId];
        return [SSignal single:[[TGCommunityChats alloc] initWithCommunity:resolved != nil ? resolved : community joinedConversations:joinedConversations viewableConversations:viewableConversations]];
    }];
}

+ (SSignal *)communityChatsForConversation:(TGConversation *)conversation
{
    int64_t communityId = conversation.linkedCommunityId;
    if (communityId == 0)
        return [SSignal fail:nil];

    return [[self resolvedCommunityWithId:communityId conversation:conversation] mapToSignal:^SSignal *(TGCommunity *community)
    {
        return [self chatsForCommunity:community];
    }];
}

+ (SSignal *)refreshChannelsSignal:(NSArray *)inputChannels
{
    TLRPCchannels_getChannels$channels_getChannels *request = [[TLRPCchannels_getChannels$channels_getChannels alloc] init];
    request.n_id = inputChannels;
    return [[[TGTelegramNetworking instance] requestSignal:request] map:^id(TLmessages_Chats *result)
    {
        [self storeCommunitiesFromChats:result.chats];
        [TGChannelManagementSignals storeChannelChats:result.chats];
        return @true;
    }];
}

+ (SSignal *)synchronizeLinkedCommunities
{
    NSData *storedVersionData = [TGDatabaseInstance() customProperty:TGCommunityLinksSynchronizationVersionKey];
    int32_t storedVersion = 0;
    if (storedVersionData.length == sizeof(storedVersion))
        [storedVersionData getBytes:&storedVersion length:sizeof(storedVersion)];
    if (storedVersion >= TGCommunityLinksSynchronizationVersion)
        return [SSignal complete];

    return [[[TGDatabaseInstance() channelList] deliverOn:[SQueue concurrentDefaultQueue]] mapToSignal:^SSignal *(NSArray *channels)
    {
        NSMutableArray *inputChannels = [[NSMutableArray alloc] init];
        for (TGConversation *conversation in channels)
        {
            if (![conversation isKindOfClass:[TGConversation class]] || conversation.leftChat || conversation.kickedFromChat || conversation.accessHash == 0)
                continue;

            TLInputChannel *inputChannel = [TGChannelManagementSignals inputChannelForPeerId:conversation.conversationId accessHash:conversation.accessHash];
            if (inputChannel != nil)
                [inputChannels addObject:inputChannel];
        }

        if (inputChannels.count == 0)
            return [SSignal complete];

        SSignal *signal = [SSignal complete];
        for (NSUInteger offset = 0; offset < inputChannels.count; offset += TGCommunityLinksBatchSize)
        {
            NSArray *batch = [inputChannels subarrayWithRange:NSMakeRange(offset, MIN(TGCommunityLinksBatchSize, inputChannels.count - offset))];
            signal = [signal then:[self refreshChannelsSignal:batch]];
        }

        return [signal then:[SSignal defer:^SSignal *
        {
            int32_t version = TGCommunityLinksSynchronizationVersion;
            [TGDatabaseInstance() setCustomProperty:TGCommunityLinksSynchronizationVersionKey value:[NSData dataWithBytes:&version length:sizeof(version)]];
            return [SSignal complete];
        }]];
    }];
}

+ (NSString *)serviceTextForCommunityAction:(TGActionMediaAttachment *)action isChannel:(bool)isChannel authorName:(NSString *)authorName
{
    int64_t communityId = [action.actionData[@"communityId"] longLongValue];
    bool fromChatItself = authorName.length == 0;

    if (communityId == 0)
    {
        if (!fromChatItself)
            return [[NSString alloc] initWithFormat:TGLocalized(@"Notification.CommunityRemovedGroup"), authorName];
        return TGLocalized(isChannel ? @"Notification.CommunityRemovedChannel" : @"Notification.CommunityRemovedChat");
    }

    NSString *title = [self cachedCommunityWithId:communityId].title;
    if (title.length != 0)
    {
        if (!fromChatItself)
            return [[NSString alloc] initWithFormat:TGLocalized(@"Notification.CommunityAddedGroup"), authorName, title];
        return [[NSString alloc] initWithFormat:TGLocalized(isChannel ? @"Notification.CommunityAddedChannel" : @"Notification.CommunityAddedChat"), title];
    }

    if (!fromChatItself)
        return [[NSString alloc] initWithFormat:TGLocalized(@"Notification.CommunityAddedGroupUnknown"), authorName];
    return TGLocalized(isChannel ? @"Notification.CommunityAddedChannelUnknown" : @"Notification.CommunityAddedChatUnknown");
}

@end
