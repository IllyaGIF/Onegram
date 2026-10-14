#import "OGSettingsController.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
@implementation OGSettingsController
- (void)loadView { UIView *view = [[UIView alloc] initWithFrame:CGRectZero]; view.backgroundColor = [OGTheme currentTheme].palette.backgroundColor; self.view = view; }
@end
