#import "TGStoryItem.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGTLDynamic.h"
#import "TGImageMediaAttachment+Telegraph.h"
#import "TGDocumentMediaAttachment+Telegraph.h"
#import "TGMediaOriginInfo+Telegraph.h"
#import "TL/TLMetaScheme.h"

int64_t TGStoryPeerIdFromObject(TGTLDynamicObject *peer)
{
    if ([peer isConstructor:@"peerUser"])
        return TGPeerIdFromUserId([peer int64Field:@"user_id"]);
    if ([peer isConstructor:@"peerChat"])
        return TGPeerIdFromGroupId([peer int64Field:@"chat_id"]);
    if ([peer isConstructor:@"peerChannel"])
        return TGPeerIdFromChannelId([peer int64Field:@"channel_id"]);
    return 0;
}

@interface TGStoryItem ()

@property (nonatomic) TGStoryItemKind kind;
@property (nonatomic) int64_t peerId;
@property (nonatomic) int32_t storyId;
@property (nonatomic) int32_t date;
@property (nonatomic) int32_t expireDate;
@property (nonatomic) bool pinned;
@property (nonatomic) bool isPublic;
@property (nonatomic) bool closeFriends;
@property (nonatomic) bool contacts;
@property (nonatomic) bool selectedContacts;
@property (nonatomic) bool outgoing;
@property (nonatomic) bool noforwards;
@property (nonatomic) bool edited;
@property (nonatomic) bool min;
@property (nonatomic, strong) NSString *caption;
@property (nonatomic, strong) TGImageMediaAttachment *image;
@property (nonatomic, strong) TGVideoMediaAttachment *video;
@property (nonatomic, strong) TGDocumentMediaAttachment *videoDocument;
@property (nonatomic) int32_t viewsCount;
@property (nonatomic) bool hasViewsCount;
@property (nonatomic) NSTimeInterval videoDuration;

@end

@implementation TGStoryItem

+ (TGStoryItem *)storyItemWithObject:(TGTLDynamicObject *)object peerId:(int64_t)peerId
{
    if (![object isKindOfClass:[TGTLDynamicObject class]])
        return nil;

    TGStoryItem *item = [[TGStoryItem alloc] init];
    item.peerId = peerId;
    item.storyId = [object int32Field:@"id"];

    if ([object isConstructor:@"storyItemDeleted"])
    {
        item.kind = TGStoryItemKindDeleted;
        return item;
    }
    if ([object isConstructor:@"storyItemSkipped"])
    {
        item.kind = TGStoryItemKindSkipped;
        item.date = [object int32Field:@"date"];
        item.expireDate = [object int32Field:@"expire_date"];
        item.closeFriends = [object flag:@"close_friends"];
        return item;
    }
    if (![object isConstructor:@"storyItem"])
        return nil;

    item.kind = TGStoryItemKindStory;
    item.date = [object int32Field:@"date"];
    item.expireDate = [object int32Field:@"expire_date"];
    item.pinned = [object flag:@"pinned"];
    item.isPublic = [object flag:@"public"];
    item.closeFriends = [object flag:@"close_friends"];
    item.contacts = [object flag:@"contacts"];
    item.selectedContacts = [object flag:@"selected_contacts"];
    item.outgoing = [object flag:@"out"];
    item.noforwards = [object flag:@"noforwards"];
    item.edited = [object flag:@"edited"];
    item.min = [object flag:@"min"];
    item.caption = [object stringField:@"caption"];

    TGTLDynamicObject *views = [object objectField:@"views"];
    if (views != nil)
    {
        item.hasViewsCount = true;
        item.viewsCount = [views int32Field:@"views_count"];
    }

    TGTLDynamicObject *media = [object objectField:@"media"];
    if ([media isConstructor:@"messageMediaPhoto"])
    {
        TLPhoto *photo = [media field:@"photo"];
        if ([photo isKindOfClass:[TLPhoto class]])
        {
            TGImageMediaAttachment *image = [[TGImageMediaAttachment alloc] initWithTelegraphDesc:photo];
            image.originInfo = [TGMediaOriginInfo mediaOriginInfoForPhoto:photo];
            if (image.imageId != 0)
                item.image = image;
        }
    }
    else if ([media isConstructor:@"messageMediaDocument"])
    {
        TLDocument *document = [media field:@"document"];
        if ([document isKindOfClass:[TLDocument class]])
            [item applyVideoDocument:document alternativeDocuments:[media arrayField:@"alt_documents"]];
    }
    return item;
}

- (void)applyVideoDocument:(TLDocument *)document alternativeDocuments:(NSArray *)alternativeDocuments
{
    TGDocumentMediaAttachment *documentAttachment = [[TGDocumentMediaAttachment alloc] initWithTelegraphDocumentDesc:document];
    if (documentAttachment.documentId == 0)
        return;
    TGMediaOriginInfo *origin = [TGMediaOriginInfo mediaOriginInfoForDocument:document];
    NSDictionary *alternativeReferences = nil;
    TGVideoInfo *videoInfo = [TGDocumentMediaAttachment videoInfoForTelegraphDocumentDesc:document alternativeDocuments:alternativeDocuments alternativeFileReferences:&alternativeReferences];
    if (alternativeReferences != nil)
    {
        NSMutableDictionary *fileReferences = [[NSMutableDictionary alloc] initWithDictionary:origin.fileReferences != nil ? origin.fileReferences : @{}];
        [fileReferences addEntriesFromDictionary:alternativeReferences];
        origin = [TGMediaOriginInfo mediaOriginInfoWithFileReference:origin.fileReference fileReferences:fileReferences];
    }
    documentAttachment.originInfo = origin;

    for (id attribute in documentAttachment.attributes)
    {
        if (![attribute isKindOfClass:[TGDocumentAttributeVideo class]])
            continue;
        TGDocumentAttributeVideo *videoAttribute = attribute;
        TGVideoMediaAttachment *video = [[TGVideoMediaAttachment alloc] init];
        video.videoId = documentAttachment.documentId;
        video.accessHash = documentAttachment.accessHash;
        video.duration = videoAttribute.duration;
        video.dimensions = videoAttribute.size;
        video.thumbnailInfo = documentAttachment.thumbnailInfo;
        video.strippedThumbnailUrl = [TGDocumentMediaAttachment strippedThumbnailUrlForTelegraphDocumentDesc:document];
        video.originInfo = origin;
        video.videoInfo = videoInfo;
        _video = video;
        _videoDocument = documentAttachment;
        _videoDuration = videoAttribute.duration;
        break;
    }
}

- (bool)hasMedia
{
    return _image != nil || _video != nil;
}

- (bool)isActiveAtTime:(NSTimeInterval)time
{
    return _kind != TGStoryItemKindDeleted && _expireDate > (int32_t)time;
}

@end

@implementation TGPeerStories

- (instancetype)initWithPeerId:(int64_t)peerId maxReadId:(int32_t)maxReadId stories:(NSArray *)stories
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _maxReadId = maxReadId;
        _stories = stories == nil ? @[] : stories;
    }
    return self;
}

+ (TGPeerStories *)peerStoriesWithObject:(TGTLDynamicObject *)object
{
    if (![object isConstructor:@"peerStories"])
        return nil;
    int64_t peerId = TGStoryPeerIdFromObject([object objectField:@"peer"]);
    if (peerId == 0)
        return nil;
    NSMutableArray *stories = [[NSMutableArray alloc] init];
    for (TGTLDynamicObject *storyObject in [object arrayField:@"stories"])
    {
        TGStoryItem *item = [TGStoryItem storyItemWithObject:storyObject peerId:peerId];
        if (item != nil && item.kind != TGStoryItemKindDeleted)
            [stories addObject:item];
    }
    [stories sortUsingComparator:^NSComparisonResult(TGStoryItem *lhs, TGStoryItem *rhs)
    {
        if (lhs.storyId == rhs.storyId)
            return NSOrderedSame;
        return lhs.storyId < rhs.storyId ? NSOrderedAscending : NSOrderedDescending;
    }];
    return [[TGPeerStories alloc] initWithPeerId:peerId maxReadId:[object int32Field:@"max_read_id"] stories:stories];
}

- (bool)hasUnread
{
    for (TGStoryItem *item in _stories)
    {
        if (item.storyId > _maxReadId)
            return true;
    }
    return false;
}

- (NSUInteger)firstUnreadIndex
{
    for (NSUInteger i = 0; i < _stories.count; i++)
    {
        if (((TGStoryItem *)[_stories objectAtIndex:i]).storyId > _maxReadId)
            return i;
    }
    return 0;
}

- (TGPeerStories *)peerStoriesWithMaxReadId:(int32_t)maxReadId
{
    return [[TGPeerStories alloc] initWithPeerId:_peerId maxReadId:MAX(_maxReadId, maxReadId) stories:_stories];
}

- (TGPeerStories *)peerStoriesByMergingStories:(NSArray *)stories
{
    NSMutableDictionary *storiesById = [[NSMutableDictionary alloc] init];
    for (TGStoryItem *item in _stories)
        [storiesById setObject:item forKey:[[NSNumber alloc] initWithInt:item.storyId]];
    for (TGStoryItem *item in stories)
    {
        NSNumber *key = [[NSNumber alloc] initWithInt:item.storyId];
        if (item.kind == TGStoryItemKindDeleted)
            [storiesById removeObjectForKey:key];
        else
            [storiesById setObject:item forKey:key];
    }
    NSArray *merged = [[storiesById allValues] sortedArrayUsingComparator:^NSComparisonResult(TGStoryItem *lhs, TGStoryItem *rhs)
    {
        if (lhs.storyId == rhs.storyId)
            return NSOrderedSame;
        return lhs.storyId < rhs.storyId ? NSOrderedAscending : NSOrderedDescending;
    }];
    return [[TGPeerStories alloc] initWithPeerId:_peerId maxReadId:_maxReadId stories:merged];
}

@end
