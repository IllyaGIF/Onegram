#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#ifndef OG_COMPAT_STRIPE_H
#define OG_COMPAT_STRIPE_H

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 90000
#define OG_COMPAT_GENERIC(Class, ...) Class<__VA_ARGS__>
#define OG_COMPAT_TYPE_PARAMETERS(...) <__VA_ARGS__>
#define OG_COMPAT_TYPE_PARAMETER(Name, Bound) Name
#else
#define OG_COMPAT_GENERIC(Class, ...) Class
#define OG_COMPAT_TYPE_PARAMETERS(...)
#define OG_COMPAT_TYPE_PARAMETER(Name, Bound) Bound
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#define OG_COMPAT_STRIPE_HAS_TEXT_KIT 1
#define OG_COMPAT_STRIPE_BUTTON_TYPE UIButtonTypeSystem
#else
#define OG_COMPAT_STRIPE_HAS_TEXT_KIT 0
#define OG_COMPAT_STRIPE_BUTTON_TYPE UIButtonTypeRoundedRect
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
#define OG_COMPAT_STRIPE_HAS_PASSKIT 1
#define OG_COMPAT_STRIPE_SINCE_IOS8 NS_AVAILABLE_IOS(8_0)
#else
#define OG_COMPAT_STRIPE_HAS_PASSKIT 0
#define OG_COMPAT_STRIPE_SINCE_IOS8
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 100000
#define OG_COMPAT_STRIPE_HAS_CONTENT_TYPE 1
#else
#define OG_COMPAT_STRIPE_HAS_CONTENT_TYPE 0
#endif

#ifndef NSLinkAttributeName
#define NSLinkAttributeName @"NSLink"
#endif
#ifndef NSBaselineOffsetAttributeName
#define NSBaselineOffsetAttributeName @"NSBaselineOffset"
#endif

typedef id OGStripeURLSession;
typedef id OGStripeURLTask;

static inline void OGCompatApplyTint(id target, UIColor *color) {
    if ([target respondsToSelector:@selector(setTintColor:)]) {
        [target setTintColor:color];
    }
}

static inline void OGCompatRefreshStatusBar(UIViewController *controller) {
    if ([controller respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [controller setNeedsStatusBarAppearanceUpdate];
    }
}

static inline void OGCompatShowAlert(NSString *title, NSString *message, NSString *cancelTitle) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelTitle otherButtonTitles:nil];
    [alert show];
}

static inline UIImage *OGCompatTemplateImage(UIImage *image) {
#if OG_COMPAT_STRIPE_HAS_TEXT_KIT
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
#else
    return image;
#endif
}

static inline NSDictionary *OGCompatBaseTextAttributes(UITextField *field) {
#if OG_COMPAT_STRIPE_HAS_TEXT_KIT
    return field.defaultTextAttributes;
#else
    return @{ NSFontAttributeName: field.font ?: [UIFont systemFontOfSize:17.0f], NSForegroundColorAttributeName: field.textColor ?: [UIColor blackColor] };
#endif
}

static inline NSDictionary *OGCompatTextAttributes(UITextField *field) {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (field.font != nil) {
        attributes[NSFontAttributeName] = field.font;
    }
    if (field.textColor != nil) {
        attributes[NSForegroundColorAttributeName] = field.textColor;
    }
    return attributes;
}

static inline void OGCompatAppendPercentEscaped(NSMutableString *target, NSString *piece) {
    CFStringRef encoded = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)piece, NULL, CFSTR(":/?#[]@!$&'()*+,;="), kCFStringEncodingUTF8);
    if (encoded != NULL) {
        [target appendString:(__bridge_transfer NSString *)encoded];
    }
}

#endif
