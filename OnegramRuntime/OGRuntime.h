#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

typedef enum {
    OGRuntimePriorityInteractive = 0,
    OGRuntimePriorityUserInitiated = 1,
    OGRuntimePriorityStorage = 2,
    OGRuntimePriorityUtility = 3,
    OGRuntimePriorityMaintenance = 4
} OGRuntimePriority;

#ifdef __cplusplus
extern "C" {
#endif

void OGRuntimeBeginInteraction(void);
void OGRuntimeEndInteraction(void);
BOOL OGRuntimeInteractionActive(void);
dispatch_queue_t OGRuntimeQueueForPriority(OGRuntimePriority priority);
void OGRuntimeDispatch(OGRuntimePriority priority, dispatch_block_t block);
void OGRuntimeDispatchAfter(OGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block);
void OGRuntimeDispatchCoalesced(NSString *key, OGRuntimePriority priority, NSTimeInterval delay, dispatch_block_t block);
void OGRuntimeCancelCoalesced(NSString *key);

#ifdef __cplusplus
}
#endif
