#import <UIKit/UIKit.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

@class TGPresentation;

@interface TGMainTabsController : UITabBarController <TGViewControllerNavigationBarAppearance, TGNavigationControllerTabsController>

@property (nonatomic, copy) void (^debugReady)(void);
@property (nonatomic, copy) void (^onControllerInsetUpdated)(CGFloat);

- (instancetype)initWithPresentation:(TGPresentation *)presentation;
- (void)setStartupViewController:(UIViewController *)viewController logicalIndex:(NSUInteger)logicalIndex prepareControllers:(NSArray *(^)(void))prepareControllers;
- (NSUInteger)logicalSelectedIndex;
- (void)setPresentation:(TGPresentation *)presentation;

- (void)setIgnoreKeyboardFrameChange:(bool)ignore restoringFocus:(bool)restoringFocus;

- (void)setUnreadArrow:(NSNumber *)up;
- (void)setUnreadCount:(int)unreadCount;
- (void)setMissedCallsCount:(int)callsCount;

- (void)setCallsHidden:(bool)hidden animated:(bool)animated;
- (void)setContactsHidden:(bool)hidden animated:(bool)animated;

- (void)localizationUpdated;

- (CGRect)frameForRightmostTab;
- (UIView *)viewForRightmostTab;

- (void)controllerInsetUpdated:(UIEdgeInsets)newInset;

@end
