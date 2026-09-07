#ifndef TGCALLS_IOS6_DIAGNOSTIC_LOG_H
#define TGCALLS_IOS6_DIAGNOSTIC_LOG_H

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <syslog.h>

#ifdef __cplusplus
extern "C" {
#endif
void TGIOS6NativeDiagnosticWrite(const char *bytes, size_t length);
#ifdef __cplusplus
}
#endif

static inline void TGIOS6DiagnosticSyslog(int priority, const char *format, ...)
{
    if (format == NULL)
        return;

    char buffer[4096];
    va_list args;
    va_start(args, format);
    int length = vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    if (length < 0)
        return;
    size_t safeLength = (size_t)length;
    if (safeLength >= sizeof(buffer))
        safeLength = sizeof(buffer) - 1;
    buffer[safeLength] = 0;

    // Preserve the old device syslog while also feeding the in-app crash
    // breadcrumbs. This makes one shared Onegram log sufficient.
    syslog(priority, "%s", buffer);
    TGIOS6NativeDiagnosticWrite(buffer, safeLength);
}

// Source files in the legacy tgcalls port already use syslog() extensively.
// Route those calls through the diagnostic mirror without touching hundreds
// of individual log call sites.
#define syslog TGIOS6DiagnosticSyslog

#endif
