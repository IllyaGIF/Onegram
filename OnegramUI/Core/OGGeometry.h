#import <UIKit/UIKit.h>

FOUNDATION_EXPORT CGFloat OGPixelFloor(CGFloat value);
FOUNDATION_EXPORT CGFloat OGPixelCeil(CGFloat value);
FOUNDATION_EXPORT CGFloat OGPixelRound(CGFloat value);
FOUNDATION_EXPORT CGRect OGRectInsetEdges(CGRect rect, UIEdgeInsets insets);
FOUNDATION_EXPORT CGRect OGRectCenterSize(CGRect bounds, CGSize size);
FOUNDATION_EXPORT CGFloat OGClamp(CGFloat value, CGFloat minimum, CGFloat maximum);
