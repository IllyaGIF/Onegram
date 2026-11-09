#import "TGCollectionMenuController.h"

@class TGStarGift;

@interface TGStarGiftSendController : TGCollectionMenuController

- (instancetype)initWithGift:(TGStarGift *)gift peerId:(int64_t)peerId balance:(NSNumber *)balance;

@end
