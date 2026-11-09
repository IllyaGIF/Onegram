#import <UIKit/UIKit.h>

@class TGPresentationPallete;

FOUNDATION_EXPORT bool TGSnowfallSettingEnabled(void);
FOUNDATION_EXPORT bool TGSnowflakesVisibleForPallete(TGPresentationPallete *pallete);

typedef enum {
    TGSnowflakesStyleHeader = 0,
    TGSnowflakesStyleBackground = 1
} TGSnowflakesStyle;

@interface TGSnowflakesView : UIView

@property (nonatomic, strong) UIColor *color;

- (instancetype)initWithFrame:(CGRect)frame style:(TGSnowflakesStyle)style;

- (void)setActive:(bool)active animated:(bool)animated;

@end
