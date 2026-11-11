#import "TGMessageViewCountContentProperty.h"

#import "PSKeyValueCoder.h"

@implementation TGMessageViewCountContentProperty

- (instancetype)initWithViewCount:(int32_t)viewCount {
    if ((self = [super init]) != nil) {
        _viewCount = viewCount;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithViewCount:[coder decodeInt32ForCKey:"vc"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:_viewCount forCKey:"vc"];
}

@end


@implementation TGMessageEditDateContentProperty

- (instancetype)initWithEditDate:(NSTimeInterval)editDate {
    if ((self = [super init]) != nil) {
        _editDate = editDate;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithEditDate:[coder decodeDoubleForCKey:"ed"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeDouble:_editDate forCKey:"ed"];
}

@end

@implementation TGMessageGroupedIdContentProperty

- (instancetype)initWithGroupedId:(int64_t)groupedId {
    if ((self = [super init]) != nil) {
        _groupedId = groupedId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithGroupedId:[coder decodeInt64ForCKey:"gi"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt64:_groupedId forCKey:"gi"];
}

@end

@implementation TGMessageReactionSummaryContentProperty

- (instancetype)initWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction {
    if ((self = [super init]) != nil) {
        _summary = summary.copy;
        _chosenReaction = chosenReaction.copy;
    }
    return self;
}

- (instancetype)initWithSummary:(NSString *)summary {
    return [self initWithSummary:summary chosenReaction:nil];
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    NSString *summary = [coder decodeStringForCKey:"rs"];
    NSString *chosen = [coder decodeStringForCKey:"rc"];
    return [self initWithSummary:summary chosenReaction:chosen];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    NSString *summary = _summary != nil ? _summary : @"";
    NSString *chosen = _chosenReaction != nil ? _chosenReaction : @"";
    [coder encodeString:summary forCKey:"rs"];
    [coder encodeString:chosen forCKey:"rc"];
}

@end

@implementation TGMessageForumTopicContentProperty

- (instancetype)initWithTopicId:(int32_t)topicId {
    if ((self = [super init]) != nil) {
        _topicId = topicId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    int32_t topic = [coder decodeInt32ForCKey:"ft"];
    return [self initWithTopicId:topic];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:_topicId forCKey:"ft"];
}

@end

@implementation TGMessageStoryReplyContentProperty

- (instancetype)initWithPeerId:(int64_t)peerId storyId:(int32_t)storyId {
    if ((self = [super init]) != nil) {
        _peerId = peerId;
        _storyId = storyId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    int64_t peer = [coder decodeInt64ForCKey:"srp"];
    int32_t story = [coder decodeInt32ForCKey:"srs"];
    return [self initWithPeerId:peer storyId:story];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt64:_peerId forCKey:"srp"];
    [coder encodeInt32:_storyId forCKey:"srs"];
}

@end

@implementation TGMessageSavedPeerContentProperty

- (instancetype)initWithPeerId:(int64_t)peerId {
    if ((self = [super init]) != nil) {
        _peerId = peerId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    int64_t peer = [coder decodeInt64ForCKey:"sp"];
    return [self initWithPeerId:peer];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt64:_peerId forCKey:"sp"];
}

@end


@implementation TGMessageDiscussionContentProperty

- (instancetype)initWithComments:(bool)comments
                         replies:(int32_t)replies
                       channelId:(int64_t)channelId
                           maxId:(int32_t)maxId
                       readMaxId:(int32_t)readMaxId
                  recentRepliers:(NSArray *)recentRepliers
{
    if ((self = [super init]) != nil)
    {
        _comments = comments;
        _replies = replies;
        _channelId = channelId;
        _maxId = maxId;
        _readMaxId = readMaxId;
        _recentRepliers = [recentRepliers copy] ?: @[];
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    NSData *repliersData = [coder decodeDataCorCKey:"rr"];
    NSMutableArray *recentRepliers = [[NSMutableArray alloc] init];
    NSUInteger count = repliersData.length / sizeof(int64_t);
    int64_t const *peerIds = (int64_t const *)repliersData.bytes;
    for (NSUInteger i = 0; i < count; i++)
        [recentRepliers addObject:@(peerIds[i])];

    return [self initWithComments:[coder decodeInt32ForCKey:"dc"] != 0
                          replies:[coder decodeInt32ForCKey:"dr"]
                        channelId:[coder decodeInt64ForCKey:"di"]
                            maxId:[coder decodeInt32ForCKey:"dm"]
                        readMaxId:[coder decodeInt32ForCKey:"dd"]
                   recentRepliers:recentRepliers];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:_comments ? 1 : 0 forCKey:"dc"];
    [coder encodeInt32:_replies forCKey:"dr"];
    [coder encodeInt64:_channelId forCKey:"di"];
    [coder encodeInt32:_maxId forCKey:"dm"];
    [coder encodeInt32:_readMaxId forCKey:"dd"];
    NSMutableData *repliersData = [[NSMutableData alloc] initWithCapacity:_recentRepliers.count * sizeof(int64_t)];
    for (NSNumber *peerId in _recentRepliers)
    {
        int64_t value = [peerId longLongValue];
        [repliersData appendBytes:&value length:sizeof(value)];
    }
    [coder encodeData:repliersData forCKey:"rr"];
}

@end
