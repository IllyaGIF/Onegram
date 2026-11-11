#import "TGCollectionMenuController.h"

#import "../submodules/LegacyComponents/SSignalKitCompat/SSignalKit.h"

@interface TGStickerPackCreationController : TGCollectionMenuController

@property (nonatomic, copy) SSignal *(^createPack)(NSString *title, NSString *shortName);
@property (nonatomic, copy) void (^completed)(void);

@end
