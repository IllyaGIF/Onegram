#import "OGCoreSupport.h"
#import "VLESSConfig.h"

@interface VLESSSelector : NSObject

- (NSString *)networkKey;

- (VLESSConfig *)chooseWorkingFrom:(NSArray *)configs
                           timeout:(NSTimeInterval)timeoutPerConfig;

@property (nonatomic, readonly) NSString *lastReport;

@property (atomic, readonly) NSUInteger progressDone;
@property (atomic, readonly) NSUInteger progressTotal;

- (void)cancelSearch;

@end
