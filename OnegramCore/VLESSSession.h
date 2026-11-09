#import "OGCoreSupport.h"
#import "VLESSConfig.h"

typedef NS_ENUM(NSInteger, VLProbeResult) {
    VLProbeOK = 0,           
    VLProbeNoRoute,          
    VLProbeTLSFailed,        
    VLProbeRejected,         
    VLProbeUnsupported       
};

@interface VLESSSession : NSObject

- (instancetype)initWithConfig:(VLESSConfig *)config;
@property (nonatomic, readonly) VLESSConfig *config;
- (void)cancel;

- (VLProbeResult)probeThroughHost:(NSString *)host
                             port:(uint16_t)port
                          timeout:(NSTimeInterval)timeout
                     latencyMillis:(int *)latencyMillis;

- (BOOL)relayClient:(int)clientFd host:(NSString *)host port:(uint16_t)port
            okReply:(NSData *)okReply initialData:(NSData *)initialData;

@end
