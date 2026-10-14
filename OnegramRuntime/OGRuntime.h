#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

typedef enum {
    OGRuntimePriorityInteractive = 0,
    OGRuntimePriorityUserInitiated = 1,
    OGRuntimePriorityStorage = 2,
    OGRuntimePriorityUtility = 3,
    OGRuntimePriorityMaintenance = 4
} OGRuntimePriority;

typedef enum {
    OGRuntimeLatencyLaneLayout = 0,
    OGRuntimeLatencyLaneStorage = 1
} OGRuntimeLatencyLane;

#ifdef __cplusplus
extern "C" {
#endif

void OGRuntimeConfigureMainThread(void);
void OGRuntimeBeginInteraction(void);
void OGRuntimeEndInteraction(void);
BOOL OGRuntimeInteractionActive(void);
BOOL OGRuntimeInteractionActiveFast(void);
BOOL OGRuntimeSingleCoreDevice(void);
void OGRuntimeCooperateWithInteraction(void);
void OGRuntimePerformLatencyCritical(dispatch_block_t block);
dispatch_block_t OGRuntimeLatencyCriticalBlock(dispatch_block_t block);
void OGRuntimePerformOnLatencyLane(OGRuntimeLatencyLane lane, dispatch_block_t block);
BOOL OGRuntimeCurrentThreadLatencyCritical(void);
void OGRuntimeLatencyYield(void);
dispatch_queue_t OGRuntimeTransferQueue(void);
dispatch_queue_t OGRuntimeQueueForPriority(OGRuntimePriority priority);
void OGRuntimeDispatch(OGRuntimePriority priority, dispatch_block_t block);
void OGRuntimeDispatchPreload(id<NSCopying> key, dispatch_block_t block);
void OGRuntimeDispatchAfter(OGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block);
void OGRuntimeDispatchCoalesced(NSString *key, OGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block);
void OGRuntimeCancelCoalesced(NSString *key);
void OGRuntimeDispatchAfterStartupPhase(OGRuntimePriority priority, dispatch_block_t block);
void OGRuntimeCompleteStartupPhase(NSString *reason);
void OGRuntimeExtendStartupPhase(void);
BOOL OGRuntimeStartupPhaseCompleted(void);

#ifdef __cplusplus
}
#endif
