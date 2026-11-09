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
int TGIOS6NativeDiagnosticsEnabled(void);
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

    syslog(priority, "%s", buffer);
    TGIOS6NativeDiagnosticWrite(buffer, safeLength);
}

#define syslog(...) do { if (TGIOS6NativeDiagnosticsEnabled()) TGIOS6DiagnosticSyslog(__VA_ARGS__); } while (0)

#endif
