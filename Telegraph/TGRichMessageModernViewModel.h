#import "TGContentBubbleViewModel.h"

@class TGRichMessage;

@interface TGRichMessageModernViewModel : TGContentBubbleViewModel

- (instancetype)initWithMessage:(TGMessage *)message richMessage:(TGRichMessage *)richMessage authorPeer:(id)authorPeer viaUser:(TGUser *)viaUser context:(TGModernViewContext *)context;

@end
