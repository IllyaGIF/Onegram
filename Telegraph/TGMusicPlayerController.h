#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@class TGPresentation;

@interface TGMusicPlayerController : TGViewController

@property (nonatomic, strong) TGPresentation *presentation;
- (void)presentFromController:(UIViewController *)controller;
- (void)dismissAnimated:(bool)animated;

+ (void)presentActionsInController:(TGViewController *)controller statusDisposable:(SMetaDisposable *)statusDisposable sourceView:(UIView *)sourceView sourceRect:(CGRect (^)(void))sourceRect dismiss:(void (^)(void))dismiss;

@end
