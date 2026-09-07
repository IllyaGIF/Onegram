#import <UIKit/UIKit.h>

@class TGStickerPack;
@class TGMenuSheetPallete;

@interface TGMultipleStickerPacksCell : PSUICollectionViewCell

@property (nonatomic) bool installed;
@property (nonatomic, strong) TGMenuSheetPallete *pallete;

@property (nonatomic, copy) void (^install)();
@property (nonatomic, strong) TGStickerPack *stickerPack;

@end
