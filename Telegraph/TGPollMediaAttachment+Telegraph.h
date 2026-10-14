#import "TGPollMediaAttachment.h"

#import "TL/TLMetaScheme.h"

@interface TGPollMediaAttachment (Telegraph)
+ (int64_t)peerIdWithTelegraphPeer:(TLPeer *)peer;

+ (TGPollMediaAttachment *)pollWithTelegraphPoll:(TLCodexPollValue *)poll results:(TLCodexPollResultsValue *)results;
+ (TGPollResults *)pollResultsWithTelegraphResults:(TLCodexPollResultsValue *)results;

- (TLCodexPollValue *)telegraphPollForClosing;

@end
