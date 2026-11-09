#ifndef OG_DIAGNOSTICS_LOGGING_H
#define OG_DIAGNOSTICS_LOGGING_H

#if !defined(__ASSEMBLER__)
#include "OGDiagnostics.h"

#if defined(__OBJC__)
#import <Foundation/NSObjCRuntime.h>
@class UIView;
FOUNDATION_EXPORT NSString *const OGDiagnosticsFirstDialogFrameNotification;
FOUNDATION_EXPORT void OGDiagnosticsTimingBegin(const char *scenario);
FOUNDATION_EXPORT void OGDiagnosticsTimingBeginOnce(const char *scenario);
FOUNDATION_EXPORT void OGDiagnosticsTimingEnd(const char *scenario);
FOUNDATION_EXPORT void OGDiagnosticsTimingRecordOnce(const char *scenario, double milliseconds);
FOUNDATION_EXPORT void OGDiagnosticsTimingAfterFrame(const char *scenario, UIView *view, bool firstDialogFrame, bool once);
#define NSLog(...) do { if (OGDiagnosticsEnabled()) NSLog(__VA_ARGS__); } while (0)
#endif
#endif

#endif
