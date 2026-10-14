#import "OGChannelInfoController.h"
#import "../Core/OGTheme.h"
#import "../Core/OGPalette.h"
@implementation OGChannelInfoController
- (void)loadView { UIView *view = [[UIView alloc] initWithFrame:CGRectZero]; view.backgroundColor = [OGTheme currentTheme].palette.backgroundColor; self.view = view; }
@end
