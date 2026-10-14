#import "TGPollMediaAttachment+Telegraph.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGPeerIdAdapter.h"

@implementation TGPollMediaAttachment (Telegraph)

+ (TGPollMediaAttachment *)pollWithTelegraphPoll:(TLCodexPollValue *)poll results:(TLCodexPollResultsValue *)results
{
    if (poll == nil || poll.pollId == 0)
        return nil;

    NSMutableArray *answers = [[NSMutableArray alloc] initWithCapacity:poll.answers.count];
    for (TLCodexPollAnswerValue *answer in poll.answers)
    {
        if ([answer isKindOfClass:[TLCodexPollAnswerValue class]] && answer.option != nil)
            [answers addObject:[[TGPollAnswer alloc] initWithText:answer.text option:answer.option]];
    }

    return [[TGPollMediaAttachment alloc] initWithPollId:poll.pollId flags:poll.flags question:poll.question answers:answers closePeriod:(poll.flags & (1 << 4)) ? poll.closePeriod : 0 closeDate:(poll.flags & (1 << 5)) ? poll.closeDate : 0 countries:poll.countries pollHash:poll.pollHash results:[self pollResultsWithTelegraphResults:results]];
}

+ (TGPollResults *)pollResultsWithTelegraphResults:(TLCodexPollResultsValue *)results
{
    if (results == nil)
        return nil;

    NSMutableArray *voters = nil;
    if (results.flags & (1 << 1))
    {
        voters = [[NSMutableArray alloc] initWithCapacity:results.results.count];
        for (TLCodexPollAnswerVotersValue *answerVoters in results.results)
        {
            if (![answerVoters isKindOfClass:[TLCodexPollAnswerVotersValue class]] || answerVoters.option == nil)
                continue;
            [voters addObject:[[TGPollAnswerVoters alloc] initWithOption:answerVoters.option chosen:(answerVoters.flags & (1 << 0)) != 0 correct:(answerVoters.flags & (1 << 1)) != 0 voters:(answerVoters.flags & (1 << 2)) ? answerVoters.voters : 0]];
        }
    }

    NSMutableArray *recentVoterIds = nil;
    if (results.flags & (1 << 3))
    {
        recentVoterIds = [[NSMutableArray alloc] initWithCapacity:results.recentVoters.count];
        for (id peer in results.recentVoters)
        {
            int64_t peerId = [peer isKindOfClass:[TLPeer class]] ? [self peerIdWithTelegraphPeer:peer] : 0;
            if (peerId != 0)
                [recentVoterIds addObject:@(peerId)];
        }
    }

    return [[TGPollResults alloc] initWithMin:(results.flags & (1 << 0)) != 0 voters:voters hasTotalVoters:(results.flags & (1 << 2)) != 0 totalVoters:results.totalVoters recentVoterIds:recentVoterIds solution:(results.flags & (1 << 4)) ? results.solution : nil];
}

+ (int64_t)peerIdWithTelegraphPeer:(TLPeer *)peer
{
    if ([peer isKindOfClass:[TLPeer$peerUser class]])
        return ((TLPeer$peerUser *)peer).user_id;
    if ([peer isKindOfClass:[TLPeer$peerChat class]])
        return TGPeerIdFromGroupId(((TLPeer$peerChat *)peer).chat_id);
    if ([peer isKindOfClass:[TLPeer$peerChannel class]])
        return TGPeerIdFromChannelId(((TLPeer$peerChannel *)peer).channel_id);
    return 0;
}

- (TLCodexPollValue *)telegraphPollForClosing
{
    TLCodexPollValue *poll = [[TLCodexPollValue alloc] init];
    poll.pollId = self.pollId;
    poll.flags = (self.flags | TGPollFlagClosed) & ~TGPollFlagCreator;
    poll.question = self.question;
    NSMutableArray *answers = [[NSMutableArray alloc] initWithCapacity:self.answers.count];
    for (TGPollAnswer *answer in self.answers)
    {
        TLCodexPollAnswerValue *answerValue = [[TLCodexPollAnswerValue alloc] init];
        answerValue.text = answer.text;
        answerValue.option = answer.option;
        [answers addObject:answerValue];
    }
    poll.answers = answers;
    poll.closePeriod = self.closePeriod;
    poll.closeDate = self.closeDate;
    poll.countries = self.countries;
    poll.pollHash = self.pollHash;
    return poll;
}

@end
