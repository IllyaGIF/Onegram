#import <UIKit/UIKit.h>

@protocol TGSwitchControl <NSObject>

@property (nonatomic, getter=isOn) BOOL on;

- (void)setOn:(BOOL)on animated:(BOOL)animated;
- (bool)setSwitchOnColor:(UIColor *)onColor offColor:(UIColor *)offColor;

@end

@interface UISwitch (TGSwitchControl) <TGSwitchControl>

@end

@interface TGFlatSwitch : UIControl <TGSwitchControl>

@end

#ifdef __cplusplus
extern "C" {
#endif

bool TGFlatControlsEnabled(void);
UIControl<TGSwitchControl> *TGSwitchControlCreate(void);
void TGFlatControlsApplySliderStyle(UISlider *slider, UIColor *accentColor, UIColor *trackColor);

#ifdef __cplusplus
}
#endif
