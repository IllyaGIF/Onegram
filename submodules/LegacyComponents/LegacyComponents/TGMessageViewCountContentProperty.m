#import "TGMessageViewCountContentProperty.h"

#import "PSKeyValueCoder.h"

@implementation TGMessageViewCountContentProperty

- (instancetype)initWithViewCount:(int32_t)viewCount {
    self = [super init];
    if (self != nil) {
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
    self = [super init];
    if (self != nil) {
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
    self = [super init];
    if (self != nil) {
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

- (instancetype)initWithSummary:(NSString *)summary {
    return [self initWithSummary:summary chosenReaction:nil];
}

- (instancetype)initWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction {
    self = [super init];
    if (self != nil) {
        _summary = [summary copy];
        _chosenReaction = [chosenReaction copy];
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithSummary:[coder decodeStringForCKey:"rs"] chosenReaction:[coder decodeStringForCKey:"rc"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeString:_summary ?: @"" forCKey:"rs"];
    [coder encodeString:_chosenReaction ?: @"" forCKey:"rc"];
}

@end

@implementation TGMessageForumTopicContentProperty

- (instancetype)initWithTopicId:(int32_t)topicId {
    self = [super init];
    if (self != nil) {
        _topicId = topicId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    return [self initWithTopicId:[coder decodeInt32ForCKey:"ft"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:_topicId forCKey:"ft"];
}

@end


@implementation TGMessageDiscussionContentProperty

- (instancetype)initWithComments:(bool)comments
                         replies:(int32_t)replies
                       channelId:(int64_t)channelId
                           maxId:(int32_t)maxId
                       readMaxId:(int32_t)readMaxId
{
    self = [super init];
    if (self != nil)
    {
        _comments = comments;
        _replies = replies;
        _channelId = channelId;
        _maxId = maxId;
        _readMaxId = readMaxId;
    }
    return self;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    return [self initWithComments:[coder decodeInt32ForCKey:"dc"] != 0
                          replies:[coder decodeInt32ForCKey:"dr"]
                        channelId:[coder decodeInt64ForCKey:"di"]
                            maxId:[coder decodeInt32ForCKey:"dm"]
                        readMaxId:[coder decodeInt32ForCKey:"dd"]];
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder
{
    [coder encodeInt32:_comments ? 1 : 0 forCKey:"dc"];
    [coder encodeInt32:_replies forCKey:"dr"];
    [coder encodeInt64:_channelId forCKey:"di"];
    [coder encodeInt32:_maxId forCKey:"dm"];
    [coder encodeInt32:_readMaxId forCKey:"dd"];
}

@end
