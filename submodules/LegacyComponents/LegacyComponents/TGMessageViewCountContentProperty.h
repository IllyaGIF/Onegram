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

@property (nonatomic, copy, readonly) NSString *summary;
@property (nonatomic, copy, readonly) NSString *chosenReaction;

- (instancetype)initWithSummary:(NSString *)summary;
- (instancetype)initWithSummary:(NSString *)summary chosenReaction:(NSString *)chosenReaction;

@end

@interface TGMessageForumTopicContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) int32_t topicId;

- (instancetype)initWithTopicId:(int32_t)topicId;

@end


@interface TGMessageDiscussionContentProperty : NSObject <PSCoding>

@property (nonatomic, readonly) bool comments;
@property (nonatomic, readonly) int32_t replies;
@property (nonatomic, readonly) int64_t channelId;
@property (nonatomic, readonly) int32_t maxId;
@property (nonatomic, readonly) int32_t readMaxId;

- (instancetype)initWithComments:(bool)comments
                         replies:(int32_t)replies
                       channelId:(int64_t)channelId
                           maxId:(int32_t)maxId
                       readMaxId:(int32_t)readMaxId;

@end
