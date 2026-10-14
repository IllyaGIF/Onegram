#import "../submodules/LegacyComponents/LegacyComponents/TGMediaAttachment.h"

#define TGPollMediaAttachmentType ((int)0x5f0c2b91)

typedef enum {
    TGPollFlagClosed = 1 << 0,
    TGPollFlagPublicVoters = 1 << 1,
    TGPollFlagMultipleChoice = 1 << 2,
    TGPollFlagQuiz = 1 << 3,
    TGPollFlagRevotingDisabled = 1 << 7,
    TGPollFlagHideResultsUntilClose = 1 << 9,
    TGPollFlagCreator = 1 << 10
} TGPollFlags;

@interface TGPollAnswer : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *text;
@property (nonatomic, strong, readonly) NSData *option;

- (instancetype)initWithText:(NSString *)text option:(NSData *)option;

@end

@interface TGPollAnswerVoters : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSData *option;
@property (nonatomic, readonly) bool chosen;
@property (nonatomic, readonly) bool correct;
@property (nonatomic, readonly) int32_t voters;

- (instancetype)initWithOption:(NSData *)option chosen:(bool)chosen correct:(bool)correct voters:(int32_t)voters;

@end

@interface TGPollResults : NSObject <NSCoding>

@property (nonatomic, readonly) bool min;
@property (nonatomic, strong, readonly) NSArray *voters;
@property (nonatomic, readonly) bool hasTotalVoters;
@property (nonatomic, readonly) int32_t totalVoters;
@property (nonatomic, strong, readonly) NSArray *recentVoterIds;
@property (nonatomic, strong, readonly) NSString *solution;

- (instancetype)initWithMin:(bool)min voters:(NSArray *)voters hasTotalVoters:(bool)hasTotalVoters totalVoters:(int32_t)totalVoters recentVoterIds:(NSArray *)recentVoterIds solution:(NSString *)solution;

- (TGPollResults *)resultsByApplyingResults:(TGPollResults *)results;
- (TGPollAnswerVoters *)votersForOption:(NSData *)option;

@end

@interface TGPollMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic, readonly) int64_t pollId;
@property (nonatomic, readonly) int32_t flags;
@property (nonatomic, strong, readonly) NSString *question;
@property (nonatomic, strong, readonly) NSArray *answers;
@property (nonatomic, readonly) int32_t closePeriod;
@property (nonatomic, readonly) int32_t closeDate;
@property (nonatomic, strong, readonly) NSArray *countries;
@property (nonatomic, readonly) int64_t pollHash;
@property (nonatomic, strong, readonly) TGPollResults *results;

- (instancetype)initWithPollId:(int64_t)pollId flags:(int32_t)flags question:(NSString *)question answers:(NSArray *)answers closePeriod:(int32_t)closePeriod closeDate:(int32_t)closeDate countries:(NSArray *)countries pollHash:(int64_t)pollHash results:(TGPollResults *)results;

- (bool)closed;
- (bool)publicVoters;
- (bool)multipleChoice;
- (bool)quiz;
- (bool)revotingDisabled;
- (bool)hideResultsUntilClose;

- (bool)isClosedAtTime:(int32_t)time;
- (bool)hasVoted;
- (NSArray *)chosenOptions;
- (NSArray *)correctAnswerIndices;

- (TGPollMediaAttachment *)pollByApplyingPoll:(TGPollMediaAttachment *)poll results:(TGPollResults *)results;
- (TGPollMediaAttachment *)closedPoll;

- (NSString *)previewText;

+ (TGPollMediaAttachment *)pollInMediaAttachments:(NSArray *)mediaAttachments;

@end
