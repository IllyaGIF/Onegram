#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#ifndef OG_COMPAT_LOTTIE_H
#define OG_COMPAT_LOTTIE_H

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 100000
@protocol CAAnimationDelegate <NSObject> @end
#endif

#if !__has_feature(nullability)
#ifndef _Nullable
#define _Nullable
#endif
#ifndef _Nonnull
#define _Nonnull
#endif
#ifndef _Null_unspecified
#define _Null_unspecified
#endif
#ifndef NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_BEGIN
#define NS_ASSUME_NONNULL_END
#endif
#endif

#ifndef NS_SWIFT_NAME
#define NS_SWIFT_NAME(name)
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#define OG_COMPAT_GENERIC(Class, ...) Class<__VA_ARGS__>
#else
#define OG_COMPAT_GENERIC(Class, ...) Class
#endif

#endif
