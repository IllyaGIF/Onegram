#import "../submodules/LegacyComponents/LegacyComponents/TGViewController.h"

@interface TGStarGiftsGridController : TGViewController

@property (nonatomic, copy) void (^giftsChanged)(void);

- (instancetype)initWithPeerId:(int64_t)peerId canManage:(bool)canManage;

@end
