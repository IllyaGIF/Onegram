#import <Foundation/Foundation.h>
#include <stdint.h>

#if defined(ONEGRAM_DIAGNOSTICS)
FOUNDATION_EXPORT void OGStartupDiagnosticsInitialize(uint64_t ticks, NSTimeInterval unixTime);
FOUNDATION_EXPORT BOOL OGStartupDiagnosticsIsCollecting(void);
FOUNDATION_EXPORT NSTimeInterval OGStartupDiagnosticsTime(void);
FOUNDATION_EXPORT void OGStartupDiagnosticsMark(const char *stage);
FOUNDATION_EXPORT void OGStartupDiagnosticsSyncStarted(void);
FOUNDATION_EXPORT void OGStartupDiagnosticsSyncFinished(BOOL success, const char *source);
FOUNDATION_EXPORT void OGStartupDiagnosticsNetworkState(int state);
FOUNDATION_EXPORT void OGStartupDiagnosticsUIState(BOOL normal, BOOL visible);
FOUNDATION_EXPORT void OGStartupDiagnosticsUIWorkPending(BOOL pending);
FOUNDATION_EXPORT void OGStartupDiagnosticsDialogsPresented(NSUInteger count, BOOL complete);
FOUNDATION_EXPORT void OGStartupDiagnosticsRecordDatabaseTask(const char *file, int line, NSTimeInterval execution, NSTimeInterval slowCPU, NSTimeInterval queued);
FOUNDATION_EXPORT void OGStartupDiagnosticsRecordMainDatabaseWait(NSTimeInterval duration);
#endif
