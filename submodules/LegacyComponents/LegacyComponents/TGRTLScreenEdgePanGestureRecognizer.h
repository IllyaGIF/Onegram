#import <UIKit/UIKit.h>
#import "LegacyComponentsIos6Compat.h"

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
#import <UIKit/UIGestureRecognizerSubclass.h>
#endif
#endif

@interface TGRTLScreenEdgePanGestureRecognizer : UIScreenEdgePanGestureRecognizer

@end

