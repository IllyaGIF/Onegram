#import <Foundation/Foundation.h>
#import "PSCoding.h"

@interface TGMessageViewCountContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) int32_t viewCount;

- (instancetype)initWithViewCount:(int32_t)viewCount;

@end


@interface TGMessageEditDateContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) NSTimeInterval editDate;

- (instancetype)initWithEditDate:(NSTimeInterval)editDate;

@end


@interface TGMessageGroupedIdContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) int64_t groupedId;

- (instancetype)initWithGroupedId:(int64_t)groupedId;

@end

@interface TGMessageReactionSummaryContentProperty : NSObject <PSCoding>

@property (readonly, nonatomic, copy) NSString *chosenReaction;
@property (readonly, nonatomic, copy) NSString *summary;

- (instancetype)initWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction;
- (instancetype)initWithSummary:(NSString *)summary;

@end

@interface TGMessageForumTopicContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) int32_t topicId;

- (instancetype)initWithTopicId:(int32_t)topicId;

@end

@interface TGMessageStoryReplyContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t storyId;

- (instancetype)initWithPeerId:(int64_t)peerId storyId:(int32_t)storyId;

@end

@interface TGMessageSavedPeerContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) int64_t peerId;

- (instancetype)initWithPeerId:(int64_t)peerId;

@end


@interface TGMessageDiscussionContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) bool comments;
@property (nonatomic, readonly) int32_t replies;
@property (nonatomic, readonly) int64_t channelId;
@property (nonatomic, readonly) int32_t maxId;
@property (nonatomic, readonly) int32_t readMaxId;
@property (nonatomic, copy, readonly) NSArray *recentRepliers;

- (instancetype)initWithComments:(bool)comments
                         replies:(int32_t)replies
                       channelId:(int64_t)channelId
                           maxId:(int32_t)maxId
                       readMaxId:(int32_t)readMaxId
                  recentRepliers:(NSArray *)recentRepliers;

@end
