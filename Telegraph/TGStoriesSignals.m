#import "TGStoriesSignals.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGStoryItem.h"
#import "TGTelegraph.h"
#import "TGDatabase.h"
#import "TGUserDataRequestBuilder.h"
#import "TGConversation+Telegraph.h"
#import "TL/TLMetaScheme.h"
#import "TGSharedPhotoSignals.h"
#import "TGSharedVideoSignals.h"
#import "TGSharedMediaUtils.h"

@implementation TGStoriesPage

- (instancetype)initWithTotalCount:(int32_t)totalCount stories:(NSArray *)stories pinnedToTopIds:(NSArray *)pinnedToTopIds
{
    self = [super init];
    if (self != nil)
    {
        _totalCount = totalCount;
        _stories = stories == nil ? @[] : stories;
        _pinnedToTopIds = pinnedToTopIds == nil ? @[] : pinnedToTopIds;
    }
    return self;
}

@end

@implementation TGAllStoriesResult

- (instancetype)initWithNotModified:(bool)notModified hasMore:(bool)hasMore state:(NSString *)state peerStories:(NSArray *)peerStories
{
    self = [super init];
    if (self != nil)
    {
        _notModified = notModified;
        _hasMore = hasMore;
        _state = state;
        _peerStories = peerStories == nil ? @[] : peerStories;
    }
    return self;
}

@end

static NSArray *TGStoriesNumberArray(NSArray *values)
{
    NSMutableArray *numbers = [[NSMutableArray alloc] initWithCapacity:values.count];
    for (id value in values)
    {
        if ([value isKindOfClass:[NSNumber class]])
            [numbers addObject:value];
    }
    return numbers;
}

static NSArray *TGStoriesPrivacyRules(TGStoryPrivacy privacy)
{
    switch (privacy)
    {
        case TGStoryPrivacyContacts:
            return @[[TGTLDynamicObject objectWithConstructor:@"inputPrivacyValueAllowContacts" fields:nil]];
        case TGStoryPrivacyCloseFriends:
            return @[[TGTLDynamicObject objectWithConstructor:@"inputPrivacyValueAllowCloseFriends" fields:nil]];
        default:
            return @[[TGTLDynamicObject objectWithConstructor:@"inputPrivacyValueAllowAll" fields:nil]];
    }
}

static int64_t TGStoriesRandomId(void)
{
    return (int64_t)(((uint64_t)arc4random() << 32) | (uint64_t)arc4random());
}

@implementation TGStoriesSignals

+ (id)inputPeerForPeerId:(int64_t)peerId
{
    if (peerId == TGTelegraphInstance.clientUserId)
        return [TGTLDynamicObject objectWithConstructor:@"inputPeerSelf" fields:nil];
    int64_t accessHash = 0;
    if (TGPeerIdIsChannel(peerId))
        accessHash = [TGDatabaseInstance() loadConversationWithId:peerId].accessHash;
    return [TGTelegraphInstance createInputPeerForConversation:peerId accessHash:accessHash];
}

+ (id)inputUserForUserId:(int64_t)userId
{
    if (userId == TGTelegraphInstance.clientUserId)
        return [TGTLDynamicObject objectWithConstructor:@"inputUserSelf" fields:nil];
    TGUser *user = [TGDatabaseInstance() loadUser:userId];
    if (user == nil)
        return nil;
    return [TGTLDynamicObject objectWithConstructor:@"inputUser" fields:@{@"user_id": @(TGUserIdFromPeerId(userId)), @"access_hash": @(user.phoneNumberHash)}];
}

+ (SSignal *)thumbnailForStory:(TGStoryItem *)story size:(CGSize)size
{
    if (story.image != nil)
        return [TGSharedPhotoSignals squarePhotoThumbnail:story.image ofSize:size threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool] memoryCache:[TGSharedMediaUtils sharedMediaMemoryImageCache] pixelProcessingBlock:nil downloadLargeImage:true placeholder:nil];
    if (story.video != nil)
        return [TGSharedVideoSignals squareVideoThumbnail:story.video ofSize:size threadPool:[TGSharedMediaUtils sharedMediaImageProcessingThreadPool] memoryCache:[TGSharedMediaUtils sharedMediaMemoryImageCache] pixelProcessingBlock:nil downloadLargeThumbnail:true];
    return [SSignal single:nil];
}

+ (void)processUsers:(NSArray *)users chats:(NSArray *)chats
{
    NSMutableArray *nativeUsers = [[NSMutableArray alloc] init];
    for (id user in users)
    {
        if ([user isKindOfClass:[TLUser class]])
            [nativeUsers addObject:user];
    }
    if (nativeUsers.count != 0)
        [TGUserDataRequestBuilder executeUserDataUpdate:nativeUsers];

    NSMutableArray *channels = [[NSMutableArray alloc] init];
    for (id chat in chats)
    {
        if (![chat isKindOfClass:[TLChat class]])
            continue;
        TGConversation *conversation = [[TGConversation alloc] initWithTelegraphChatDesc:chat];
        if (conversation != nil && TGPeerIdIsChannel(conversation.conversationId))
            [channels addObject:conversation];
    }
    if (channels.count != 0)
        [TGDatabaseInstance() updateChannels:channels];
}

+ (TGStoriesPage *)pageWithStoriesObject:(TGTLDynamicObject *)object peerId:(int64_t)peerId
{
    if (![object isConstructor:@"stories.stories"])
        return nil;
    [self processUsers:[object arrayField:@"users"] chats:[object arrayField:@"chats"]];
    NSMutableArray *stories = [[NSMutableArray alloc] init];
    for (TGTLDynamicObject *storyObject in [object arrayField:@"stories"])
    {
        TGStoryItem *item = [TGStoryItem storyItemWithObject:storyObject peerId:peerId];
        if (item != nil)
            [stories addObject:item];
    }
    return [[TGStoriesPage alloc] initWithTotalCount:[object int32Field:@"count"] stories:stories pinnedToTopIds:TGStoriesNumberArray([object arrayField:@"pinned_to_top"])];
}

+ (SSignal *)storiesPageWithMethod:(NSString *)method peerId:(int64_t)peerId parameters:(NSDictionary *)parameters
{
    return [[TGTLDynamicRpc requestSignalWithMethod:method parameters:parameters] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        TGStoriesPage *page = [self pageWithStoriesObject:result peerId:peerId];
        if (page == nil)
            return [SSignal fail:nil];
        return [SSignal single:page];
    }];
}

+ (SSignal *)peerStories:(int64_t)peerId
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stories.getPeerStories" parameters:@{@"peer": inputPeer}] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if (![result isConstructor:@"stories.peerStories"])
            return [SSignal fail:nil];
        [self processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        TGPeerStories *peerStories = [TGPeerStories peerStoriesWithObject:[result objectField:@"stories"]];
        if (peerStories == nil)
            peerStories = [[TGPeerStories alloc] initWithPeerId:peerId maxReadId:0 stories:@[]];
        return [SSignal single:peerStories];
    }];
}

+ (SSignal *)pinnedStories:(int64_t)peerId offsetId:(int32_t)offsetId limit:(int32_t)limit
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    return [self storiesPageWithMethod:@"stories.getPinnedStories" peerId:peerId parameters:@{@"peer": inputPeer, @"offset_id": @(offsetId), @"limit": @(limit)}];
}

+ (SSignal *)storiesArchiveWithOffsetId:(int32_t)offsetId limit:(int32_t)limit
{
    int64_t peerId = TGTelegraphInstance.clientUserId;
    return [self storiesPageWithMethod:@"stories.getStoriesArchive" peerId:peerId parameters:@{@"peer": [self inputPeerForPeerId:peerId], @"offset_id": @(offsetId), @"limit": @(limit)}];
}

+ (SSignal *)storiesWithPeerId:(int64_t)peerId storyIds:(NSArray *)storyIds
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil || storyIds.count == 0)
        return [SSignal fail:nil];
    return [self storiesPageWithMethod:@"stories.getStoriesByID" peerId:peerId parameters:@{@"peer": inputPeer, @"id": storyIds}];
}

+ (SSignal *)allStoriesWithState:(NSString *)state next:(bool)next hidden:(bool)hidden
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    if (state.length != 0)
        parameters[@"state"] = state;
    if (next)
        parameters[@"next"] = @true;
    if (hidden)
        parameters[@"hidden"] = @true;
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stories.getAllStories" parameters:parameters] mapToSignal:^SSignal *(TGTLDynamicObject *result)
    {
        if ([result isConstructor:@"stories.allStoriesNotModified"])
            return [SSignal single:[[TGAllStoriesResult alloc] initWithNotModified:true hasMore:false state:[result stringField:@"state"] peerStories:nil]];
        if (![result isConstructor:@"stories.allStories"])
            return [SSignal fail:nil];
        [self processUsers:[result arrayField:@"users"] chats:[result arrayField:@"chats"]];
        NSMutableArray *peerStories = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *peerStoriesObject in [result arrayField:@"peer_stories"])
        {
            TGPeerStories *item = [TGPeerStories peerStoriesWithObject:peerStoriesObject];
            if (item != nil && item.stories.count != 0)
                [peerStories addObject:item];
        }
        return [SSignal single:[[TGAllStoriesResult alloc] initWithNotModified:false hasMore:[result flag:@"has_more"] state:[result stringField:@"state"] peerStories:peerStories]];
    }];
}

+ (SSignal *)readStories:(int64_t)peerId maxId:(int32_t)maxId
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    return [TGTLDynamicRpc requestSignalWithMethod:@"stories.readStories" parameters:@{@"peer": inputPeer, @"max_id": @(maxId)}];
}

+ (SSignal *)incrementViews:(int64_t)peerId storyIds:(NSArray *)storyIds
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil || storyIds.count == 0)
        return [SSignal complete];
    return [TGTLDynamicRpc requestSignalWithMethod:@"stories.incrementStoryViews" parameters:@{@"peer": inputPeer, @"id": storyIds}];
}

+ (SSignal *)deleteStories:(int64_t)peerId storyIds:(NSArray *)storyIds
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil || storyIds.count == 0)
        return [SSignal fail:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stories.deleteStories" parameters:@{@"peer": inputPeer, @"id": storyIds}] map:^id(NSArray *result)
    {
        return TGStoriesNumberArray([result isKindOfClass:[NSArray class]] ? result : nil);
    }];
}

+ (SSignal *)setStories:(int64_t)peerId storyIds:(NSArray *)storyIds pinned:(bool)pinned
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil || storyIds.count == 0)
        return [SSignal fail:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stories.togglePinned" parameters:@{@"peer": inputPeer, @"id": storyIds, @"pinned": @(pinned)}] map:^id(NSArray *result)
    {
        return TGStoriesNumberArray([result isKindOfClass:[NSArray class]] ? result : nil);
    }];
}

+ (SSignal *)canSendStory:(int64_t)peerId
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil)
        return [SSignal fail:nil];
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stories.canSendStory" parameters:@{@"peer": inputPeer}] map:^id(TGTLDynamicObject *result)
    {
        return @([result isConstructor:@"stories.canSendStoryCount"] ? [result int32Field:@"count_remains"] : 0);
    }];
}

+ (SSignal *)sendStoryWithMedia:(TGTLDynamicObject *)media peerId:(int64_t)peerId caption:(NSString *)caption privacy:(TGStoryPrivacy)privacy period:(int32_t)period pinned:(bool)pinned
{
    id inputPeer = [self inputPeerForPeerId:peerId];
    if (inputPeer == nil || media == nil)
        return [SSignal fail:nil];
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"peer"] = inputPeer;
    parameters[@"media"] = media;
    parameters[@"privacy_rules"] = TGStoriesPrivacyRules(privacy);
    parameters[@"random_id"] = @(TGStoriesRandomId());
    if (caption.length != 0)
    {
        parameters[@"caption"] = caption;
        parameters[@"entities"] = @[];
    }
    if (period > 0)
        parameters[@"period"] = @(period);
    if (pinned)
        parameters[@"pinned"] = @true;
    return [[TGTLDynamicRpc requestSignalWithMethod:@"stories.sendStory" parameters:parameters] map:^id(TGTLDynamicObject *updates)
    {
        if ([updates isKindOfClass:[TGTLDynamicObject class]])
            [self processUsers:[updates arrayField:@"users"] chats:[updates arrayField:@"chats"]];
        NSMutableArray *stories = [[NSMutableArray alloc] init];
        for (TGTLDynamicObject *update in [updates arrayField:@"updates"])
        {
            if (![update isConstructor:@"updateStory"])
                continue;
            int64_t storyPeerId = TGStoryPeerIdFromObject([update objectField:@"peer"]);
            TGStoryItem *item = [TGStoryItem storyItemWithObject:[update objectField:@"story"] peerId:storyPeerId == 0 ? peerId : storyPeerId];
            if (item != nil)
                [stories addObject:item];
        }
        return stories;
    }];
}

+ (SSignal *)sendPhotoStoryWithFile:(TLInputFile *)file peerId:(int64_t)peerId caption:(NSString *)caption privacy:(TGStoryPrivacy)privacy period:(int32_t)period pinned:(bool)pinned
{
    if (file == nil)
        return [SSignal fail:nil];
    TGTLDynamicObject *media = [TGTLDynamicObject objectWithConstructor:@"inputMediaUploadedPhoto" fields:@{@"file": file}];
    return [self sendStoryWithMedia:media peerId:peerId caption:caption privacy:privacy period:period pinned:pinned];
}

+ (SSignal *)sendVideoStoryWithFile:(TLInputFile *)file thumbnail:(TLInputFile *)thumbnail duration:(NSTimeInterval)duration dimensions:(CGSize)dimensions peerId:(int64_t)peerId caption:(NSString *)caption privacy:(TGStoryPrivacy)privacy period:(int32_t)period pinned:(bool)pinned
{
    if (file == nil)
        return [SSignal fail:nil];
    TGTLDynamicObject *videoAttribute = [TGTLDynamicObject objectWithConstructor:@"documentAttributeVideo" fields:@{
        @"supports_streaming": @true,
        @"duration": @(duration),
        @"w": @((int32_t)dimensions.width),
        @"h": @((int32_t)dimensions.height)
    }];
    TGTLDynamicObject *filenameAttribute = [TGTLDynamicObject objectWithConstructor:@"documentAttributeFilename" fields:@{@"file_name": @"story.mp4"}];
    NSMutableDictionary *fields = [[NSMutableDictionary alloc] init];
    fields[@"file"] = file;
    if (thumbnail != nil)
        fields[@"thumb"] = thumbnail;
    fields[@"mime_type"] = @"video/mp4";
    fields[@"attributes"] = @[videoAttribute, filenameAttribute];
    TGTLDynamicObject *media = [TGTLDynamicObject objectWithConstructor:@"inputMediaUploadedDocument" fields:fields];
    return [self sendStoryWithMedia:media peerId:peerId caption:caption privacy:privacy period:period pinned:pinned];
}

@end
