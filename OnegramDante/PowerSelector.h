#import "OGDanteSupport.h"
#import "PowerConfig.h"

typedef NS_ENUM(NSInteger, PWNetworkKind) {
    PWNetworkOpen = 0,     
    PWNetworkRestricted,   
    PWNetworkOffline       
};

@interface PowerSelector : NSObject

+ (instancetype)sharedSelector;

- (PWNetworkKind)fingerprintNetwork;

- (NSString *)networkKey;

- (PowerConfig *)chooseWorkingFrom:(NSArray *)configs
                           timeout:(NSTimeInterval)timeoutPerConfig;

@property (nonatomic, readonly) NSString *lastReport;

@property (atomic, readonly) NSUInteger progressDone;
@property (atomic, readonly) NSUInteger progressTotal;

- (void)cancelSearch;

@end
