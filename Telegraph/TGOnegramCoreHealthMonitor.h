#import <Foundation/Foundation.h>

typedef enum {
    TGOnegramCoreHealthChecking,
    TGOnegramCoreHealthGood,
    TGOnegramCoreHealthFair,
    TGOnegramCoreHealthPoor,
    TGOnegramCoreHealthNoResponse
} TGOnegramCoreHealth;

@interface TGOnegramCoreHealthMonitor : NSObject

@property (nonatomic, readonly) TGOnegramCoreHealth health;
@property (nonatomic, readonly) NSInteger pingMilliseconds;
@property (nonatomic, readonly) double incomingBytesPerSecond;
@property (nonatomic, readonly) double outgoingBytesPerSecond;
@property (nonatomic, copy) void (^updated)(void);

- (void)start;
- (void)stop;
- (void)restart;

@end
