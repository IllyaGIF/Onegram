#import "OGCoreSupport.h"

@interface OGVLESSTunnel : NSObject
- (BOOL)startWithError:(NSError **)error;
- (void)stop;
- (BOOL)checkHealth;
- (void)handleSOCKSClient:(int)fd;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) NSString *serverName;
@end
