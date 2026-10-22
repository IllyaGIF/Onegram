
#import <Foundation/Foundation.h>

@class MTContext;
@class MTQueue;
@class ASQueue;

@class TGNetworkWorker;
@class MTRequestMessageService;
@class MTRequest;
@class TGNetworkWorkerGuard;
@class MTNetworkUsageCalculationInfo;

@protocol TGNetworkWorkerDelegate <NSObject>

@optional

- (void)networkWorkerReadyToBeRemoved:(TGNetworkWorker *)networkWorker;
- (void)networkWorkerDidBecomeAvailable:(TGNetworkWorker *)networkWorker;

@end

@interface TGNetworkWorker : NSObject

@property (nonatomic, strong) id<TGNetworkWorkerDelegate> delegate;

@property (nonatomic, readonly) NSInteger datacenterId;

@property (nonatomic, strong) MTNetworkUsageCalculationInfo *usageCalculationInfo;
    
@property (nonatomic, readonly) bool isCdn;

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId masterDatacenterId:(NSInteger)masterDatacenterId isCdn:(bool)isCdn networkQueue:(MTQueue *)networkQueue stateQueue:(ASQueue *)stateQueue;

- (bool)isBusy;
- (void)setIsBusy:(bool)isBusy;
- (void)updateReadyToBeRemoved;
- (void)addRequest:(MTRequest *)request;
- (void)cancelRequestById:(id)requestId;
- (void)cancelRequestByIdSoft:(id)requestId;
- (void)ensureConnection;
- (void)shutdown;

@end

@interface TGNetworkWorkerGuard : NSObject

@property (nonatomic, strong) TGNetworkWorker *worker;

- (instancetype)initWithWorker:(TGNetworkWorker *)worker;
- (TGNetworkWorker *)strongWorker;
- (void)releaseWorker;

@end
