#import "TLMessage.h"

@class TLReplyMarkup;
@class TLPeer;
@class TLMessageFwdHeader;
@class TGRichMessage;

@interface TLMessage$modernMessage : TLMessage$messageMeta

@property (nonatomic, strong) NSString *reactionSummary;
@property (nonatomic, strong) NSString *chosenReaction;
@property (nonatomic) int64_t senderPeerId;

@property (nonatomic) int32_t reply_to_top_id;
@property (nonatomic) bool forum_topic;

@property (nonatomic) bool discussion_comments;
@property (nonatomic) int32_t discussion_replies;
@property (nonatomic) int64_t discussion_channel_id;
@property (nonatomic) int32_t discussion_max_id;
@property (nonatomic) int32_t discussion_read_max_id;
@property (nonatomic, strong) NSArray *discussion_recent_repliers;

@property (nonatomic, strong) TGRichMessage *richMessage;
@property (nonatomic, strong) NSArray *richMessagePhotos;
@property (nonatomic, strong) NSArray *richMessageDocuments;

+ (NSDictionary *)readMessageRepliesFromStream:(NSInputStream *)is error:(__autoreleasing NSError **)error;

@end
