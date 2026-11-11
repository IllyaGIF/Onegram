#import "TGPreparedPollMessage.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPollMediaAttachment.h"
#import "TL/TLMessageMedia.h"
#import "TLRPCmessages_sendMessage_manual.h"

@implementation TGPreparedPollMessage

- (instancetype)initWithQuestion:(NSString *)question answers:(NSArray *)answers publicVoters:(bool)publicVoters multipleChoice:(bool)multipleChoice quiz:(bool)quiz correctAnswerIndices:(NSArray *)correctAnswerIndices solution:(NSString *)solution replyMessage:(TGMessage *)replyMessage replyMarkup:(TGReplyMarkupAttachment *)replyMarkup
{
    self = [super init];
    if (self != nil)
    {
        _question = [question copy] ?: @"";
        _answers = [answers copy] ?: @[];
        _publicVoters = publicVoters;
        _multipleChoice = multipleChoice && !quiz;
        _quiz = quiz;
        _correctAnswerIndices = quiz ? ([correctAnswerIndices copy] ?: @[]) : @[];
        _solution = quiz && solution.length != 0 ? [solution copy] : nil;
        self.replyMessage = replyMessage;
        self.replyMarkup = replyMarkup;
    }
    return self;
}

- (instancetype)initWithPoll:(TGPollMediaAttachment *)poll replyMessage:(TGMessage *)replyMessage replyMarkup:(TGReplyMarkupAttachment *)replyMarkup
{
    NSMutableArray *answers = [[NSMutableArray alloc] initWithCapacity:poll.answers.count];
    for (TGPollAnswer *answer in poll.answers)
        [answers addObject:answer.text ?: @""];
    return [self initWithQuestion:poll.question answers:answers publicVoters:[poll publicVoters] multipleChoice:[poll multipleChoice] quiz:[poll quiz] correctAnswerIndices:[poll correctAnswerIndices] solution:poll.results.solution replyMessage:replyMessage replyMarkup:replyMarkup];
}

- (int32_t)pollFlags
{
    int32_t flags = 0;
    if (_publicVoters)
        flags |= TGPollFlagPublicVoters;
    if (_multipleChoice)
        flags |= TGPollFlagMultipleChoice;
    if (_quiz)
        flags |= TGPollFlagQuiz;
    return flags;
}

+ (NSData *)optionForIndex:(NSUInteger)index
{
    uint8_t value = (uint8_t)index;
    return [NSData dataWithBytes:&value length:1];
}

- (TGPollMediaAttachment *)pollAttachment
{
    NSMutableArray *answers = [[NSMutableArray alloc] initWithCapacity:_answers.count];
    NSMutableArray *voters = [[NSMutableArray alloc] initWithCapacity:_answers.count];
    [_answers enumerateObjectsUsingBlock:^(NSString *text, NSUInteger index, __unused BOOL *stop)
    {
        NSData *option = [TGPreparedPollMessage optionForIndex:index];
        [answers addObject:[[TGPollAnswer alloc] initWithText:text option:option]];
        [voters addObject:[[TGPollAnswerVoters alloc] initWithOption:option chosen:false correct:[_correctAnswerIndices containsObject:@((int32_t)index)] voters:0]];
    }];
    TGPollResults *results = [[TGPollResults alloc] initWithMin:false voters:voters hasTotalVoters:true totalVoters:0 recentVoterIds:nil solution:_solution];
    int64_t pollId = self.randomId != 0 ? self.randomId : 1;
    return [[TGPollMediaAttachment alloc] initWithPollId:pollId flags:[self pollFlags] | TGPollFlagCreator question:_question answers:answers closePeriod:0 closeDate:0 countries:nil pollHash:0 results:results];
}

- (TLInputMedia *)inputMedia
{
    TLCodexPollValue *poll = [[TLCodexPollValue alloc] init];
    poll.pollId = 0;
    poll.flags = [self pollFlags];
    poll.question = _question;
    NSMutableArray *answers = [[NSMutableArray alloc] initWithCapacity:_answers.count];
    [_answers enumerateObjectsUsingBlock:^(NSString *text, NSUInteger index, __unused BOOL *stop)
    {
        TLCodexPollAnswerValue *answer = [[TLCodexPollAnswerValue alloc] init];
        answer.text = text;
        answer.option = [TGPreparedPollMessage optionForIndex:index];
        [answers addObject:answer];
    }];
    poll.answers = answers;
    poll.pollHash = 0;

    TLInputMedia$inputMediaPoll_manual *media = [[TLInputMedia$inputMediaPoll_manual alloc] init];
    media.poll = poll;
    media.correct_answers = _quiz ? _correctAnswerIndices : nil;
    media.solution = _solution;
    return media;
}

- (TGMessage *)message
{
    TGMessage *message = [[TGMessage alloc] init];
    message.mid = self.mid;
    message.date = self.date;
    message.isBroadcast = self.isBroadcast;
    message.messageLifetime = self.messageLifetime;

    NSMutableArray *attachments = [[NSMutableArray alloc] init];
    [attachments addObject:[self pollAttachment]];

    if (self.replyMessage != nil)
    {
        TGReplyMessageMediaAttachment *replyMedia = [[TGReplyMessageMediaAttachment alloc] init];
        replyMedia.replyMessageId = self.replyMessage.mid;
        replyMedia.replyMessage = self.replyMessage;
        [attachments addObject:replyMedia];
    }

    if (self.replyMarkup != nil)
        [attachments addObject:self.replyMarkup];

    message.mediaAttachments = attachments;
    return message;
}

@end
