#import <Foundation/Foundation.h>

@class CLLocationManager;

typedef NSInteger OGPlatformLocationAuthorizationStatus;

enum
{
    OGPlatformLocationAuthorizationStatusNotDetermined = 0,
    OGPlatformLocationAuthorizationStatusRestricted = 1,
    OGPlatformLocationAuthorizationStatusDenied = 2,
    OGPlatformLocationAuthorizationStatusAuthorized = 3,
    OGPlatformLocationAuthorizationStatusAuthorizedAlways = 3,
    OGPlatformLocationAuthorizationStatusAuthorizedWhenInUse = 4
};

FOUNDATION_EXPORT OGPlatformLocationAuthorizationStatus OGPlatformLocationAuthorizationStatusCurrent(void);
FOUNDATION_EXPORT BOOL OGPlatformLocationAuthorizationStatusAllowsWhenInUse(OGPlatformLocationAuthorizationStatus status);
FOUNDATION_EXPORT BOOL OGPlatformLocationAuthorizationStatusAllowsAlways(OGPlatformLocationAuthorizationStatus status);
FOUNDATION_EXPORT BOOL OGPlatformLocationAuthorizationAllowsWhenInUse(void);
FOUNDATION_EXPORT BOOL OGPlatformLocationAuthorizationAllowsAlways(void);
FOUNDATION_EXPORT BOOL OGPlatformRequestWhenInUseLocationAuthorization(CLLocationManager *manager);
FOUNDATION_EXPORT BOOL OGPlatformRequestAlwaysLocationAuthorization(CLLocationManager *manager);
FOUNDATION_EXPORT BOOL OGPlatformRequestSingleLocation(CLLocationManager *manager);
FOUNDATION_EXPORT void OGPlatformSetLocationActivityTypeOther(CLLocationManager *manager);
FOUNDATION_EXPORT void OGPlatformSetLocationPausesAutomatically(CLLocationManager *manager, BOOL enabled);
FOUNDATION_EXPORT void OGPlatformSetLocationAllowsBackgroundUpdates(CLLocationManager *manager, BOOL enabled);
FOUNDATION_EXPORT void OGPlatformOpenMaps(double latitude, double longitude, BOOL directions);
