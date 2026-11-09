#import "../submodules/LegacyComponents/LegacyComponents/TGViewController.h"

@class SSignal;
@class TGCloudTheme;

@interface TGCloudThemePreviewController : TGViewController

- (instancetype)initWithTheme:(TGCloudTheme *)theme;

+ (void)presentThemeWithSignal:(SSignal *)signal;

@end
