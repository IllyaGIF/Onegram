#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#ifndef LOT_XCODE46_COMPAT_H
#define LOT_XCODE46_COMPAT_H

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000
@protocol CAAnimationDelegate <NSObject>
@end
#endif

#endif
