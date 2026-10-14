#import "OGPlatformLocation.h"

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
#import <MapKit/MapKit.h>
#endif

static BOOL OGPlatformLocationManagerClassBoolValue(SEL selector, BOOL fallback)
{
    Class managerClass = NSClassFromString(@"CLLocationManager");
    if (managerClass == Nil || ![(id)managerClass respondsToSelector:selector])
        return fallback;

    BOOL (*function)(id, SEL) = (BOOL (*)(id, SEL))[(id)managerClass methodForSelector:selector];
    if (function == NULL)
        return fallback;

    return function((id)managerClass, selector);
}

static NSInteger OGPlatformLocationManagerClassIntegerValue(SEL selector, NSInteger fallback)
{
    Class managerClass = NSClassFromString(@"CLLocationManager");
    if (managerClass == Nil || ![(id)managerClass respondsToSelector:selector])
        return fallback;

    int (*function)(id, SEL) = (int (*)(id, SEL))[(id)managerClass methodForSelector:selector];
    if (function == NULL)
        return fallback;

    return function((id)managerClass, selector);
}

static BOOL OGPlatformLocationManagerInvoke(CLLocationManager *manager, SEL selector)
{
    if (manager == nil || ![manager respondsToSelector:selector])
        return NO;

    void (*function)(id, SEL) = (void (*)(id, SEL))[manager methodForSelector:selector];
    if (function == NULL)
        return NO;

    function(manager, selector);
    return YES;
}

static void OGPlatformLocationManagerSetBool(CLLocationManager *manager, SEL selector, BOOL value)
{
    if (manager == nil || ![manager respondsToSelector:selector])
        return;

    void (*function)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))[manager methodForSelector:selector];
    if (function != NULL)
        function(manager, selector, value);
}

static void OGPlatformLocationManagerSetInteger(CLLocationManager *manager, SEL selector, NSInteger value)
{
    if (manager == nil || ![manager respondsToSelector:selector])
        return;

    void (*function)(id, SEL, NSInteger) = (void (*)(id, SEL, NSInteger))[manager methodForSelector:selector];
    if (function != NULL)
        function(manager, selector, value);
}

OGPlatformLocationAuthorizationStatus OGPlatformLocationAuthorizationStatusCurrent(void)
{
    Class managerClass = NSClassFromString(@"CLLocationManager");
    SEL authorizationSelector = NSSelectorFromString(@"authorizationStatus");
    if (managerClass != Nil && [(id)managerClass respondsToSelector:authorizationSelector])
        return OGPlatformLocationManagerClassIntegerValue(authorizationSelector, OGPlatformLocationAuthorizationStatusNotDetermined);

    SEL enabledSelector = NSSelectorFromString(@"locationServicesEnabled");
    if (managerClass != Nil && [(id)managerClass respondsToSelector:enabledSelector] && !OGPlatformLocationManagerClassBoolValue(enabledSelector, YES))
        return OGPlatformLocationAuthorizationStatusDenied;

    return OGPlatformLocationAuthorizationStatusAuthorized;
}

BOOL OGPlatformLocationAuthorizationStatusAllowsWhenInUse(OGPlatformLocationAuthorizationStatus status)
{
    return status == OGPlatformLocationAuthorizationStatusAuthorized || status == OGPlatformLocationAuthorizationStatusAuthorizedWhenInUse;
}

BOOL OGPlatformLocationAuthorizationStatusAllowsAlways(OGPlatformLocationAuthorizationStatus status)
{
    return status == OGPlatformLocationAuthorizationStatusAuthorizedAlways;
}

BOOL OGPlatformLocationAuthorizationAllowsWhenInUse(void)
{
    return OGPlatformLocationAuthorizationStatusAllowsWhenInUse(OGPlatformLocationAuthorizationStatusCurrent());
}

BOOL OGPlatformLocationAuthorizationAllowsAlways(void)
{
    return OGPlatformLocationAuthorizationStatusAllowsAlways(OGPlatformLocationAuthorizationStatusCurrent());
}

BOOL OGPlatformRequestWhenInUseLocationAuthorization(CLLocationManager *manager)
{
    if (manager == nil)
        return NO;

    if (OGPlatformLocationManagerInvoke(manager, NSSelectorFromString(@"requestWhenInUseAuthorization")))
        return YES;

    [manager startUpdatingLocation];
    return YES;
}

BOOL OGPlatformRequestAlwaysLocationAuthorization(CLLocationManager *manager)
{
    if (manager == nil)
        return NO;

    if (OGPlatformLocationManagerInvoke(manager, NSSelectorFromString(@"requestAlwaysAuthorization")))
        return YES;

    [manager startUpdatingLocation];
    return YES;
}

BOOL OGPlatformRequestSingleLocation(CLLocationManager *manager)
{
    if (manager == nil)
        return NO;

    if (OGPlatformLocationManagerInvoke(manager, NSSelectorFromString(@"requestLocation")))
        return YES;

    [manager startUpdatingLocation];
    return YES;
}

void OGPlatformSetLocationActivityTypeOther(CLLocationManager *manager)
{
    OGPlatformLocationManagerSetInteger(manager, NSSelectorFromString(@"setActivityType:"), 1);
}

void OGPlatformSetLocationPausesAutomatically(CLLocationManager *manager, BOOL enabled)
{
    OGPlatformLocationManagerSetBool(manager, NSSelectorFromString(@"setPausesLocationUpdatesAutomatically:"), enabled);
}

void OGPlatformSetLocationAllowsBackgroundUpdates(CLLocationManager *manager, BOOL enabled)
{
    OGPlatformLocationManagerSetBool(manager, NSSelectorFromString(@"setAllowsBackgroundLocationUpdates:"), enabled);
}

void OGPlatformOpenMaps(double latitude, double longitude, BOOL directions)
{
    CLLocationCoordinate2D coordinate = {latitude, longitude};
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 60000
    MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:nil];
    MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
    if (directions)
    {
        NSDictionary *options = @{MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving};
        [MKMapItem openMapsWithItems:@[[MKMapItem mapItemForCurrentLocation], mapItem] launchOptions:options];
    }
    else
    {
        [mapItem openInMapsWithLaunchOptions:nil];
    }
#else
    NSString *urlString = directions ? [NSString stringWithFormat:@"http://maps.google.com/maps?saddr=Current%%20Location&daddr=%f,%f", coordinate.latitude, coordinate.longitude] : [NSString stringWithFormat:@"http://maps.google.com/maps?q=%f,%f", coordinate.latitude, coordinate.longitude];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
#endif
}
