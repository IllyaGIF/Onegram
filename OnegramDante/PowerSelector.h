#import "OGDanteSupport.h"
#import "PowerConfig.h"

@interface PowerSelector : NSObject

- (NSString *)networkKey;

- (PowerConfig *)chooseWorkingFrom:(NSArray *)configs
                           timeout:(NSTimeInterval)timeoutPerConfig;

@property (nonatomic, readonly) NSString *lastReport;

@property (atomic, readonly) NSUInteger progressDone;
@property (atomic, readonly) NSUInteger progressTotal;

- (void)cancelSearch;

@end
