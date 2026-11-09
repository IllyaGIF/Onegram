#import "TGOnegramCardOverlay.h"

@class TGSavedStarGift;

@interface TGStarGiftSheetView : TGOnegramCardView

@property (nonatomic, copy) void (^giftUpdated)(TGSavedStarGift *gift);
@property (nonatomic, copy) void (^giftRemoved)(TGSavedStarGift *gift);

- (instancetype)initWithSavedGift:(TGSavedStarGift *)gift canManage:(bool)canManage;

- (void)presentFromController:(UIViewController *)controller;

@end
