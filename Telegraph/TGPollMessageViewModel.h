#import "TGContentBubbleViewModel.h"

@class TGPollMediaAttachment;

@interface TGPollMessageViewModel : TGContentBubbleViewModel

- (instancetype)initWithMessage:(TGMessage *)message poll:(TGPollMediaAttachment *)poll authorPeer:(id)authorPeer viaUser:(TGUser *)viaUser context:(TGModernViewContext *)context;

@end
