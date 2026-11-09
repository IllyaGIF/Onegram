#import "../submodules/LegacyComponents/LegacyComponents/TGOverlayController.h"

typedef enum {
    TGOnegramCardPlacementCenter,
    TGOnegramCardPlacementBottom,
    TGOnegramCardPlacementSheet
} TGOnegramCardPlacement;

@class TGOnegramCardOverlay;

@interface TGOnegramCardView : UIView

@property (nonatomic, weak, readonly) TGOnegramCardOverlay *overlay;

- (CGFloat)heightForWidth:(CGFloat)width;
- (CGFloat)heightForWidth:(CGFloat)width availableHeight:(CGFloat)availableHeight;
- (void)cardWillAppear;
- (void)cardDidDisappear;

@end

@interface TGOnegramCardOverlay : TGOverlayController

@property (nonatomic, readonly) TGOnegramCardView *cardView;
@property (nonatomic, readonly) TGOnegramCardPlacement placement;
@property (nonatomic) bool dismissesOnDimTap;
@property (nonatomic, copy) void (^onDismiss)(void);

@property (nonatomic, weak, readonly) UIViewController *parentController;

+ (TGOnegramCardOverlay *)presentCardView:(TGOnegramCardView *)cardView placement:(TGOnegramCardPlacement)placement;
+ (TGOnegramCardOverlay *)presentCardView:(TGOnegramCardView *)cardView placement:(TGOnegramCardPlacement)placement parentController:(UIViewController *)parentController;

- (void)setNeedsCardLayoutAnimated:(bool)animated;
- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion;

@end
