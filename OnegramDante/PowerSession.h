#import "OGDanteSupport.h"
#import "PowerConfig.h"

typedef NS_ENUM(NSInteger, PWProbeResult) {
    PWProbeOK = 0,           
    PWProbeNoRoute,          
    PWProbeTLSFailed,        
    PWProbeRejected,         
    PWProbeUnsupported       
};

void PWSetBoundInterface(unsigned ifindex);

void PWBindSocket(int fd);

@interface PowerSession : NSObject

- (instancetype)initWithConfig:(PowerConfig *)config;
@property (nonatomic, readonly) PowerConfig *config;
- (void)cancel;

- (PWProbeResult)probeThroughHost:(NSString *)host
                             port:(uint16_t)port
                          timeout:(NSTimeInterval)timeout
                     latencyMillis:(int *)latencyMillis;

- (void)relayClient:(int)clientFd host:(NSString *)host port:(uint16_t)port;

- (BOOL)relayClient:(int)clientFd host:(NSString *)host port:(uint16_t)port
            okReply:(NSData *)okReply initialData:(NSData *)initialData;

- (NSData *)resolveTCPDNSQuery:(NSData *)query
                  resolverHost:(NSString *)host
                          port:(uint16_t)port
                       timeout:(NSTimeInterval)timeout;

@end
