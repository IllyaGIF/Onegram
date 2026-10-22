
#import "TGNetworkWorker.h"

#import "../submodules/LegacyComponents/LegacyComponents/ASQueue.h"
#import "../submodules/LegacyComponents/LegacyComponents/ActionStage.h"

#import "TGTelegraph.h"

#import "TGTimer.h"

#import "../submodules/MtProtoKit/MTProtoKit/MTContext.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTProto.h"
#import "../submodules/MtProtoKit/MTProtoKit/MTRequestMessageService.h"
#import "../submodules/MtProtoKit/MTProtoKit/MtProtoKit.h"

#import "TGTelegramNetworking.h"

static int workerCount = 0;

@interface TGNetworkWorker () <MTRequestMessageServiceDelegate>
{
    MTContext *_context;
    MTProto *_mtProto;
    ASQueue *_stateQueue;
    MTRequestMessageService *_requestService;

    TGTimer *_timeoutTimer;

    bool _isReadyToBeRemoved;
    bool _isBusy;
}

@end

@implementation TGNetworkWorker

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId masterDatacenterId:(NSInteger)masterDatacenterId isCdn:(bool)isCdn networkQueue:(MTQueue *)networkQueue stateQueue:(ASQueue *)stateQueue
{
    self = [super init];
    if (self != nil)
    {
        _isCdn = isCdn;
        workerCount++;

        _context = context;
        _datacenterId = datacenterId;
        _stateQueue = stateQueue;

        _mtProto = [[MTProto alloc] initWithContext:_context datacenterId:_datacenterId usageCalculationInfo:[[TGTelegramNetworking instance] mediaUsageInfoForType:TGNetworkMediaTypeTagGeneric] queue:networkQueue];
        _mtProto.cdn = isCdn;
        if (!isCdn) {
            _mtProto.requiredAuthToken = @(TGTelegraphInstance.clientUserId);
            _mtProto.authTokenMasterDatacenterId = masterDatacenterId;
        }

        _requestService = [[MTRequestMessageService alloc] initWithContext:_context];
        _requestService.delegate = self;
        [_mtProto addMessageService:_requestService];

        [self startTimer];
    }
    return self;
}

- (void)dealloc
{
    workerCount--;

    _delegate = nil;
    _requestService.delegate = nil;

    if (_timeoutTimer != nil)
    {
        [_timeoutTimer invalidate];
        _timeoutTimer = nil;
    }

    [_mtProto stop];
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo {
    _usageCalculationInfo = usageCalculationInfo;
    [_mtProto setUsageCalculationInfo:usageCalculationInfo];
}

- (void)dispatchOnStateQueue:(dispatch_block_t)block
{
    if (_stateQueue != nil)
        [_stateQueue dispatchOnQueue:block];
    else
        [ActionStageInstance() dispatchOnStageQueue:block];
}

- (dispatch_queue_t)nativeStateQueue
{
    return _stateQueue != nil ? _stateQueue.nativeQueue : [ActionStageInstance() globalStageDispatchQueue];
}

- (void)startTimer
{
    [self dispatchOnStateQueue:^
    {
        [self clearTimer];

        __weak TGNetworkWorker *weakSelf = self;
        _timeoutTimer = [[TGTimer alloc] initWithTimeout:30 repeat:false completion:^
        {
            __strong TGNetworkWorker *strongSelf = weakSelf;
            [strongSelf timerTimeout];
        } queue:[self nativeStateQueue]];
        [_timeoutTimer start];
    }];
}

- (void)clearTimer
{
    [self dispatchOnStateQueue:^
    {
        if (_timeoutTimer != nil)
        {
            [_timeoutTimer invalidate];
            _timeoutTimer = nil;
        }
    }];
}

- (void)timerTimeout
{
    [self dispatchOnStateQueue:^
    {
        if (_isBusy)
            return;

        _isReadyToBeRemoved = true;

        id<TGNetworkWorkerDelegate> delegate = _delegate;
        if ([delegate respondsToSelector:@selector(networkWorkerReadyToBeRemoved:)])
            [delegate networkWorkerReadyToBeRemoved:self];
    }];
}

- (bool)isBusy
{
    return _isBusy;
}

- (void)setIsBusy:(bool)isBusy
{
    [self dispatchOnStateQueue:^
    {
        if (_isBusy != isBusy)
        {
            _isBusy = isBusy;
            if (isBusy)
            {
                _isReadyToBeRemoved = false;
                [self clearTimer];
            }
            else
                [self startTimer];

            if (!_isBusy)
            {
                id<TGNetworkWorkerDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(networkWorkerDidBecomeAvailable:)])
                    [delegate networkWorkerDidBecomeAvailable:self];
            }
        }
    }];
}

- (void)updateReadyToBeRemoved
{
    [self dispatchOnStateQueue:^
    {
        if (_isReadyToBeRemoved)
        {
            id<TGNetworkWorkerDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(networkWorkerReadyToBeRemoved:)])
                [delegate networkWorkerReadyToBeRemoved:self];
        }
    }];
}

- (void)addRequest:(MTRequest *)request
{
    [_requestService addRequest:request];
}

- (void)shutdown
{
    [self dispatchOnStateQueue:^
    {
        _delegate = nil;
        _isReadyToBeRemoved = true;
        if (_timeoutTimer != nil)
        {
            [_timeoutTimer invalidate];
            _timeoutTimer = nil;
        }
    }];
    _requestService.delegate = nil;
    [_mtProto stop];
}

- (void)cancelRequestById:(id)requestId
{
    [_requestService removeRequestByInternalId:requestId askForReconnectionOnDrop:true];
}

- (void)cancelRequestByIdSoft:(id)requestId
{
    [_requestService removeRequestByInternalId:requestId askForReconnectionOnDrop:false];
}

- (void)ensureConnection
{
    [_mtProto requestTransportTransaction];
}

- (void)requestMessageServiceDidCompleteAllRequests:(MTRequestMessageService *)__unused requestMessageService
{
}

- (void)requestMessageServiceAuthorizationRequired:(MTRequestMessageService *)__unused requestMessageService
{
    [_context updateAuthTokenForDatacenterWithId:_datacenterId authToken:nil];
    [_context authTokenForDatacenterWithIdRequired:_datacenterId authToken:_mtProto.requiredAuthToken masterDatacenterId:_mtProto.authTokenMasterDatacenterId];
}

@end

@implementation TGNetworkWorkerGuard

- (instancetype)initWithWorker:(TGNetworkWorker *)worker
{
    self = [super init];
    if (self != nil)
    {
        _worker = worker;
    }
    return self;
}

- (void)dealloc
{
    [self releaseWorker];
}

- (TGNetworkWorker *)strongWorker
{
    return _worker;
}

- (void)releaseWorker
{
    TGNetworkWorker *worker = _worker;
    _worker = nil;
    [worker setIsBusy:false];
    worker = nil;
}

@end
