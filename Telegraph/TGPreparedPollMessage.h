#import "TGPreparedMessage.h"

@class TGPollMediaAttachment;
@class TLInputMedia;

@interface TGPreparedPollMessage : TGPreparedMessage

@property (nonatomic, strong, readonly) NSString *question;
@property (nonatomic, strong, readonly) NSArray *answers;
@property (nonatomic, readonly) bool publicVoters;
@property (nonatomic, readonly) bool multipleChoice;
@property (nonatomic, readonly) bool quiz;
@property (nonatomic, strong, readonly) NSArray *correctAnswerIndices;
@property (nonatomic, strong, readonly) NSString *solution;

- (instancetype)initWithQuestion:(NSString *)question answers:(NSArray *)answers publicVoters:(bool)publicVoters multipleChoice:(bool)multipleChoice quiz:(bool)quiz correctAnswerIndices:(NSArray *)correctAnswerIndices solution:(NSString *)solution replyMessage:(TGMessage *)replyMessage replyMarkup:(TGReplyMarkupAttachment *)replyMarkup;
- (instancetype)initWithPoll:(TGPollMediaAttachment *)poll replyMessage:(TGMessage *)replyMessage replyMarkup:(TGReplyMarkupAttachment *)replyMarkup;

- (TLInputMedia *)inputMedia;

@end
