#import "TGLocationSignals.h"

#import "LegacyComponentsInternal.h"
#import "TGStringUtils.h"

#import <UIKit/UIKit.h>

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "OGPlatformLocation.h"

#import "TGLocationVenue.h"
#import "TGLocationReverseGeocodeResult.h"

NSString *const TGLocationGoogleGeocodeLocale = @"en";

@interface TGLocationHelper : NSObject <CLLocationManagerDelegate> {
    CLLocationManager *_locationManager;
    void (^_locationDetermined)(CLLocation *);
    bool _startedUpdating;
}

@end

@implementation TGLocationHelper

- (instancetype)initWithLocationDetermined:(void (^)(CLLocation *))locationDetermined {
    self = [super init];
    if (self != nil) {
        _locationDetermined = [locationDetermined copy];
        
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        
        if (OGPlatformLocationAuthorizationAllowsWhenInUse())
            [self startUpdating];
    }
    return self;
}

- (void)dealloc {
    [_locationManager stopUpdatingLocation];
}

- (void)startUpdating {
    if (!_startedUpdating) {
        _startedUpdating = true;
        OGPlatformRequestWhenInUseLocationAuthorization(_locationManager);
        [_locationManager startUpdatingLocation];
    }
}

- (void)applyLocation:(CLLocation *)location {
    if (location != nil && _locationDetermined)
        _locationDetermined(location);
}

- (void)locationManager:(CLLocationManager *)__unused manager didUpdateLocations:(NSArray *)locations {
    [self applyLocation:[locations lastObject]];
}

- (void)locationManager:(CLLocationManager *)__unused manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)__unused oldLocation {
    [self applyLocation:newLocation];
}

@end

static NSDictionary *TGLocationAddressDictionaryFromGoogleResult(NSDictionary *result)
{
    NSMutableDictionary *address = [[NSMutableDictionary alloc] init];
    NSString *streetNumber = nil;
    NSString *route = nil;

    for (NSDictionary *component in result[@"address_components"])
    {
        NSArray *types = component[@"types"];
        NSString *longName = component[@"long_name"];
        if (![longName isKindOfClass:[NSString class]])
            continue;

        if ([types containsObject:@"street_number"])
            streetNumber = longName;
        else if ([types containsObject:@"route"])
            route = longName;
        else if ([types containsObject:@"locality"])
            address[@"City"] = longName;
        else if ([types containsObject:@"administrative_area_level_1"])
            address[@"State"] = longName;
        else if ([types containsObject:@"postal_code"])
            address[@"ZIP"] = longName;
        else if ([types containsObject:@"country"])
            address[@"Country"] = longName;
    }

    if (route.length != 0 && streetNumber.length != 0)
        address[@"Street"] = [NSString stringWithFormat:@"%@ %@", route, streetNumber];
    else if (route.length != 0)
        address[@"Street"] = route;

    return address;
}

static SSignal *TGLocationGeocodeAddressSignal(NSString *address)
{
    if (address.length == 0)
        return [SSignal single:nil];

#if defined(ONEGRAM_ARMV6)
    NSString *escapedAddress = [address stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *url = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?address=%@&sensor=true&language=%@", escapedAddress, TGLocationGoogleGeocodeLocale];
    return [[[LegacyComponentsGlobals provider] jsonForHttpLocation:url] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;

        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)] || results.count == 0)
            return nil;

        NSDictionary *result = results.firstObject;
        if (![result isKindOfClass:[NSDictionary class]])
            return nil;

        NSDictionary *location = result[@"geometry"][@"location"];
        NSNumber *latitude = location[@"lat"];
        NSNumber *longitude = location[@"lng"];
        if (![latitude respondsToSelector:@selector(doubleValue)] || ![longitude respondsToSelector:@selector(doubleValue)])
            return nil;

        CLLocation *resolvedLocation = [[CLLocation alloc] initWithLatitude:[latitude doubleValue] longitude:[longitude doubleValue]];
        return [[CLPlacemark alloc] initWithLocation:resolvedLocation addressDictionary:TGLocationAddressDictionaryFromGoogleResult(result)];
    }];
#else
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder geocodeAddressString:address completionHandler:^(NSArray *placemarks, NSError *error)
        {
            if (error != nil)
                [subscriber putError:error];
            else
            {
                [subscriber putNext:placemarks.firstObject];
                [subscriber putCompletion];
            }
        }];

        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [geocoder cancelGeocode];
        }];
    }];
#endif
}

@implementation TGLocationSignals

+ (SSignal *)geocodeAddress:(NSString *)address
{
    return TGLocationGeocodeAddressSignal(address);
}

+ (SSignal *)geocodeAddressDictionary:(NSDictionary *)dictionary
{
#if defined(ONEGRAM_ARMV6)
    NSMutableArray *components = [[NSMutableArray alloc] init];
    for (NSString *key in @[ @"Street", @"City", @"State", @"ZIP", @"Country" ])
    {
        NSString *value = dictionary[key];
        if ([value isKindOfClass:[NSString class]] && value.length != 0)
            [components addObject:value];
    }
    return TGLocationGeocodeAddressSignal([components componentsJoinedByString:@", "]);
#else
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder geocodeAddressDictionary:dictionary completionHandler:^(NSArray *placemarks, NSError *error)
        {
            if (error != nil)
                [subscriber putError:error];
            else
            {
                [subscriber putNext:placemarks.firstObject];
                [subscriber putCompletion];
            }
        }];

        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [geocoder cancelGeocode];
        }];
    }];
#endif
}

+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
{
    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true&language=%@", coordinate.latitude, coordinate.longitude, TGLocationGoogleGeocodeLocale]];
    
    return [[[LegacyComponentsGlobals provider] jsonForHttpLocation:url.absoluteString] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;
        
        if (![results.firstObject isKindOfClass:[NSDictionary class]])
            return nil;
        
        return [TGLocationReverseGeocodeResult reverseGeocodeResultWithDictionary:results.firstObject];
    }];
}

+ (SSignal *)cityForCoordinate:(CLLocationCoordinate2D)coordinate
{
#if defined(ONEGRAM_ARMV6)
    return [[self reverseGeocodeCoordinate:coordinate] map:^id(TGLocationReverseGeocodeResult *result)
    {
        if (result.city.length != 0)
            return result.city;
        if (result.state.length != 0)
            return result.state;
        return result.country;
    }];
#else
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder reverseGeocodeLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude] completionHandler:^(NSArray *placemarks, NSError *error)
         {
             if (error != nil)
                 [subscriber putError:error];
             else
             {
                 [subscriber putNext:[placemarks.firstObject locality]];
                 [subscriber putCompletion];
             }
         }];

        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [geocoder cancelGeocode];
        }];
    }];
#endif
}

+ (SSignal *)driveEta:(CLLocationCoordinate2D)destinationCoordinate
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
    if (iosMajorVersion() < 7)
        return [SSignal single:@0];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        MKPlacemark *destinationPlacemark = [[MKPlacemark alloc] initWithCoordinate:destinationCoordinate addressDictionary:nil];
        MKMapItem *destinationMapItem = [[MKMapItem alloc] initWithPlacemark:destinationPlacemark];
        
        MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
        request.source = [MKMapItem mapItemForCurrentLocation];
        request.destination = destinationMapItem;
        request.transportType = MKDirectionsTransportTypeAutomobile;
        request.requestsAlternateRoutes = false;

        MKDirections *directions = [[MKDirections alloc] initWithRequest:request];
        [directions calculateETAWithCompletionHandler:^(MKETAResponse *response, NSError *error)
        {
             if (error != nil)
             {
                 [subscriber putError:error];
                 return;
             }
            
            [subscriber putNext:@(response.expectedTravelTime)];
            [subscriber putCompletion];
        }];
        
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [directions cancel];
        }];
    }];
#else
    (void)destinationCoordinate;
    return [SSignal single:@0];
#endif
}

#pragma mark -

static CLLocation *lastKnownUserLocation;

+ (void)storeLastKnownUserLocation:(CLLocation *)location
{
    lastKnownUserLocation = location;
}

+ (CLLocation *)lastKnownUserLocation
{
    NSTimeInterval locationAge = -[lastKnownUserLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 600)
        lastKnownUserLocation = nil;
    
    return lastKnownUserLocation;
}

+ (SSignal *)userLocation:(SVariable *)locationRequired {
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        TGLocationHelper *helper = [[TGLocationHelper alloc] initWithLocationDetermined:^(CLLocation *location) {
            [subscriber putNext:location];
        }];
        
        id<SDisposable> requiredDisposable = [[[[locationRequired signal] take:1] deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next) {
            [helper startUpdating];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            [helper description];
            [requiredDisposable dispose];
        }];
    }] startOn:[SQueue mainQueue]];
}

@end
