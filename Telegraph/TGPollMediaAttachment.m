#import "TGPollMediaAttachment.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/NSInputStream+TL.h"

static id TGPollDecodedObject(NSCoder *coder, NSString *key, Class objectClass)
{
    id object = [coder decodeObjectForKey:key];
    return [object isKindOfClass:objectClass] ? object : nil;
}

static NSArray *TGPollDecodedArray(NSCoder *coder, NSString *key, Class itemClass)
{
    NSArray *array = TGPollDecodedObject(coder, key, [NSArray class]);
    if (array == nil)
        return nil;
    for (id item in array)
    {
        if (![item isKindOfClass:itemClass])
            return nil;
    }
    return array;
}

@implementation TGPollAnswer

- (instancetype)initWithText:(NSString *)text option:(NSData *)option
{
    self = [super init];
    if (self != nil)
    {
        _text = [text copy] ?: @"";
        _option = [option copy] ?: [NSData data];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithText:TGPollDecodedObject(aDecoder, @"text", [NSString class]) option:TGPollDecodedObject(aDecoder, @"option", [NSData class])];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_text forKey:@"text"];
    [aCoder encodeObject:_option forKey:@"option"];
}

@end

@implementation TGPollAnswerVoters

- (instancetype)initWithOption:(NSData *)option chosen:(bool)chosen correct:(bool)correct voters:(int32_t)voters
{
    self = [super init];
    if (self != nil)
    {
        _option = [option copy] ?: [NSData data];
        _chosen = chosen;
        _correct = correct;
        _voters = MAX(0, voters);
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithOption:TGPollDecodedObject(aDecoder, @"option", [NSData class]) chosen:[aDecoder decodeBoolForKey:@"chosen"] correct:[aDecoder decodeBoolForKey:@"correct"] voters:[aDecoder decodeInt32ForKey:@"voters"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_option forKey:@"option"];
    [aCoder encodeBool:_chosen forKey:@"chosen"];
    [aCoder encodeBool:_correct forKey:@"correct"];
    [aCoder encodeInt32:_voters forKey:@"voters"];
}

@end

@implementation TGPollResults

- (instancetype)initWithMin:(bool)min voters:(NSArray *)voters hasTotalVoters:(bool)hasTotalVoters totalVoters:(int32_t)totalVoters recentVoterIds:(NSArray *)recentVoterIds solution:(NSString *)solution
{
    self = [super init];
    if (self != nil)
    {
        _min = min;
        _voters = [voters copy];
        _hasTotalVoters = hasTotalVoters;
        _totalVoters = hasTotalVoters ? MAX(0, totalVoters) : 0;
        _recentVoterIds = [recentVoterIds copy];
        _solution = [solution copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithMin:[aDecoder decodeBoolForKey:@"min"] voters:TGPollDecodedArray(aDecoder, @"voters", [TGPollAnswerVoters class]) hasTotalVoters:[aDecoder decodeBoolForKey:@"hasTotalVoters"] totalVoters:[aDecoder decodeInt32ForKey:@"totalVoters"] recentVoterIds:TGPollDecodedArray(aDecoder, @"recentVoterIds", [NSNumber class]) solution:TGPollDecodedObject(aDecoder, @"solution", [NSString class])];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeBool:_min forKey:@"min"];
    if (_voters != nil)
        [aCoder encodeObject:_voters forKey:@"voters"];
    [aCoder encodeBool:_hasTotalVoters forKey:@"hasTotalVoters"];
    [aCoder encodeInt32:_totalVoters forKey:@"totalVoters"];
    if (_recentVoterIds != nil)
        [aCoder encodeObject:_recentVoterIds forKey:@"recentVoterIds"];
    if (_solution != nil)
        [aCoder encodeObject:_solution forKey:@"solution"];
}

- (TGPollAnswerVoters *)votersForOption:(NSData *)option
{
    for (TGPollAnswerVoters *voters in _voters)
    {
        if ([voters.option isEqualToData:option])
            return voters;
    }
    return nil;
}

- (TGPollResults *)resultsByApplyingResults:(TGPollResults *)results
{
    if (results == nil)
        return self;

    NSArray *voters = _voters;
    bool min = _min;
    if (results.voters != nil)
    {
        if (results.min && _voters != nil)
        {
            NSMutableArray *mergedVoters = [[NSMutableArray alloc] initWithCapacity:results.voters.count];
            for (TGPollAnswerVoters *answerVoters in results.voters)
            {
                TGPollAnswerVoters *previous = [self votersForOption:answerVoters.option];
                [mergedVoters addObject:[[TGPollAnswerVoters alloc] initWithOption:answerVoters.option chosen:previous.chosen correct:previous.correct || answerVoters.correct voters:answerVoters.voters]];
            }
            voters = mergedVoters;
        }
        else
        {
            voters = results.voters;
            min = results.min;
        }
    }

    return [[TGPollResults alloc] initWithMin:min voters:voters hasTotalVoters:results.hasTotalVoters || _hasTotalVoters totalVoters:results.hasTotalVoters ? results.totalVoters : _totalVoters recentVoterIds:results.recentVoterIds ?: _recentVoterIds solution:results.solution ?: _solution];
}

@end

@implementation TGPollMediaAttachment

- (instancetype)init
{
    return [self initWithPollId:0 flags:0 question:nil answers:nil closePeriod:0 closeDate:0 countries:nil pollHash:0 results:nil];
}

- (instancetype)initWithPollId:(int64_t)pollId flags:(int32_t)flags question:(NSString *)question answers:(NSArray *)answers closePeriod:(int32_t)closePeriod closeDate:(int32_t)closeDate countries:(NSArray *)countries pollHash:(int64_t)pollHash results:(TGPollResults *)results
{
    self = [super init];
    if (self != nil)
    {
        self.type = TGPollMediaAttachmentType;
        _pollId = pollId;
        _flags = flags;
        _question = [question copy] ?: @"";
        _answers = [answers copy] ?: @[];
        _closePeriod = closePeriod;
        _closeDate = closeDate;
        _countries = [countries copy];
        _pollHash = pollHash;
        _results = results;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    return [self initWithPollId:[aDecoder decodeInt64ForKey:@"pollId"] flags:[aDecoder decodeInt32ForKey:@"flags"] question:TGPollDecodedObject(aDecoder, @"question", [NSString class]) answers:TGPollDecodedArray(aDecoder, @"answers", [TGPollAnswer class]) closePeriod:[aDecoder decodeInt32ForKey:@"closePeriod"] closeDate:[aDecoder decodeInt32ForKey:@"closeDate"] countries:TGPollDecodedArray(aDecoder, @"countries", [NSString class]) pollHash:[aDecoder decodeInt64ForKey:@"pollHash"] results:TGPollDecodedObject(aDecoder, @"results", [TGPollResults class])];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:_pollId forKey:@"pollId"];
    [aCoder encodeInt32:_flags forKey:@"flags"];
    [aCoder encodeObject:_question forKey:@"question"];
    [aCoder encodeObject:_answers forKey:@"answers"];
    [aCoder encodeInt32:_closePeriod forKey:@"closePeriod"];
    [aCoder encodeInt32:_closeDate forKey:@"closeDate"];
    if (_countries != nil)
        [aCoder encodeObject:_countries forKey:@"countries"];
    [aCoder encodeInt64:_pollHash forKey:@"pollHash"];
    if (_results != nil)
        [aCoder encodeObject:_results forKey:@"results"];
}

- (void)serialize:(NSMutableData *)data
{
    NSData *serializedData = [NSKeyedArchiver archivedDataWithRootObject:self];
    int32_t length = (int32_t)serializedData.length;
    [data appendBytes:&length length:4];
    [data appendData:serializedData];
}

- (TGMediaAttachment *)parseMediaAttachment:(NSInputStream *)is
{
    int32_t length = [is readInt32];
    NSData *data = [is readData:length];
    @try
    {
        id attachment = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if ([attachment isKindOfClass:[TGPollMediaAttachment class]] && ((TGPollMediaAttachment *)attachment).pollId != 0)
            return attachment;
    }
    @catch (__unused NSException *e)
    {
    }
    return nil;
}

- (bool)closed
{
    return (_flags & TGPollFlagClosed) != 0;
}

- (bool)publicVoters
{
    return (_flags & TGPollFlagPublicVoters) != 0;
}

- (bool)multipleChoice
{
    return (_flags & TGPollFlagMultipleChoice) != 0;
}

- (bool)quiz
{
    return (_flags & TGPollFlagQuiz) != 0;
}

- (bool)revotingDisabled
{
    return (_flags & TGPollFlagRevotingDisabled) != 0;
}

- (bool)hideResultsUntilClose
{
    return (_flags & TGPollFlagHideResultsUntilClose) != 0;
}

- (bool)isClosedAtTime:(int32_t)time
{
    return [self closed] || (_closeDate != 0 && time >= _closeDate);
}

- (bool)hasVoted
{
    for (TGPollAnswerVoters *voters in _results.voters)
    {
        if (voters.chosen)
            return true;
    }
    return false;
}

- (NSArray *)chosenOptions
{
    NSMutableArray *options = [[NSMutableArray alloc] init];
    for (TGPollAnswerVoters *voters in _results.voters)
    {
        if (voters.chosen)
            [options addObject:voters.option];
    }
    return options;
}

- (NSArray *)correctAnswerIndices
{
    NSMutableArray *indices = [[NSMutableArray alloc] init];
    [_answers enumerateObjectsUsingBlock:^(TGPollAnswer *answer, NSUInteger index, __unused BOOL *stop)
    {
        if ([_results votersForOption:answer.option].correct)
            [indices addObject:@((int32_t)index)];
    }];
    return indices;
}

- (TGPollMediaAttachment *)pollByApplyingPoll:(TGPollMediaAttachment *)poll results:(TGPollResults *)results
{
    TGPollMediaAttachment *definition = poll != nil ? poll : self;
    TGPollResults *mergedResults = _results;
    if (results != nil)
        mergedResults = mergedResults != nil ? [mergedResults resultsByApplyingResults:results] : results;
    return [[TGPollMediaAttachment alloc] initWithPollId:_pollId flags:definition.flags question:definition.question answers:definition.answers closePeriod:definition.closePeriod closeDate:definition.closeDate countries:definition.countries pollHash:definition.pollHash results:mergedResults];
}

- (TGPollMediaAttachment *)closedPoll
{
    return [[TGPollMediaAttachment alloc] initWithPollId:_pollId flags:_flags | TGPollFlagClosed question:_question answers:_answers closePeriod:_closePeriod closeDate:_closeDate countries:_countries pollHash:_pollHash results:_results];
}

- (NSString *)previewText
{
    NSString *text = _question.length != 0 ? _question : TGLocalized(@"Message.Poll");
    if (iosMajorVersion() >= 5)
        return [@"📊 " stringByAppendingString:text];
    return text;
}

+ (TGPollMediaAttachment *)pollInMediaAttachments:(NSArray *)mediaAttachments
{
    for (id attachment in mediaAttachments)
    {
        if ([attachment isKindOfClass:[TGPollMediaAttachment class]])
            return attachment;
    }
    return nil;
}

@end
