#import "../submodules/LegacyComponents/LegacyComponents/TGViewController.h"

@interface TGStarGiftCatalogController : TGViewController

- (instancetype)initWithPeerId:(int64_t)peerId;

+ (void)presentForPeerId:(int64_t)peerId fromController:(UIViewController *)controller;

@end
