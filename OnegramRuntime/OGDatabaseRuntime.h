#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

struct sqlite3;

#ifdef __cplusplus
extern "C" {
#endif

void OGDatabaseRuntimeDispatch(dispatch_queue_t queue, BOOL synchronous, dispatch_block_t block);
void OGDatabaseRuntimeDispatchContinuation(dispatch_queue_t queue, dispatch_block_t block);
BOOL OGDatabaseRuntimePriorityWorkPending(void);
void OGDatabaseRuntimeBeginStartupCritical(void);
void OGDatabaseRuntimeEndStartupCritical(void);
void OGDatabaseRuntimeInteractionStateChanged(void);
void OGDatabaseRuntimeCooperateDuringInteraction(void);
void OGDatabaseRuntimeConfigureSQLite(struct sqlite3 *database);

#ifdef __cplusplus
}
#endif
