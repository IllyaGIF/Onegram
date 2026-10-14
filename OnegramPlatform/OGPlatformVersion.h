#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSInteger OGPlatformMajorVersion(void);
FOUNDATION_EXPORT BOOL OGPlatformSupportsBackgroundVoipTransport(void);
FOUNDATION_EXPORT BOOL OGPlatformSystemVersionAtLeast(CGFloat version);
FOUNDATION_EXPORT NSTimeInterval OGPlatformSystemUptime(void);
FOUNDATION_EXPORT CGFloat OGPlatformScreenScale(void);
FOUNDATION_EXPORT CGFloat OGPlatformScreenBrightness(void);
FOUNDATION_EXPORT void OGPlatformSetScreenBrightness(CGFloat brightness);
FOUNDATION_EXPORT NSString *OGPlatformScreenBrightnessDidChangeNotification(void);
FOUNDATION_EXPORT BOOL OGPlatformClassAvailable(NSString *className);
FOUNDATION_EXPORT BOOL OGPlatformObjectResponds(id object, NSString *selectorName);
FOUNDATION_EXPORT BOOL OGPlatformSupportsRegionalIndicatorEmoji(void);
FOUNDATION_EXPORT BOOL OGPlatformCachedBoolDefault(NSString *key);
FOUNDATION_EXPORT NSInteger OGPlatformCachedIntegerDefault(NSString *key, NSInteger missingValue);
