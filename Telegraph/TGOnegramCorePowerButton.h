#import <UIKit/UIKit.h>

typedef enum {
    TGOnegramCorePowerStateOff,
    TGOnegramCorePowerStateConnecting,
    TGOnegramCorePowerStateConnected,
    TGOnegramCorePowerStateFailed
} TGOnegramCorePowerState;

@interface TGOnegramCorePowerButton : UIControl

@property (nonatomic, readonly) TGOnegramCorePowerState powerState;

@property (nonatomic, strong) UIColor *accentColor;
@property (nonatomic, strong) UIColor *contrastColor;
@property (nonatomic, strong) UIColor *surfaceColor;
@property (nonatomic, strong) UIColor *trackColor;
@property (nonatomic, strong) UIColor *secondaryColor;
@property (nonatomic, strong) UIColor *destructiveColor;

- (void)setPowerState:(TGOnegramCorePowerState)powerState animated:(bool)animated;
- (void)resumeAnimations;

@end
