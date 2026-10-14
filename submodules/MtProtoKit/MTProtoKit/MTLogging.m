#define ONEGRAM_LOG_IMPLEMENTATION 1


#import "MTLogging.h"

static void (*loggingFunction)(NSString *, va_list args) = NULL;
static BOOL MTLogEnabledValue = true;

#undef MTLogEnabled
#undef MTLog
BOOL MTLogEnabled() {
#if defined(ONEGRAM_DIAGNOSTICS)
    return loggingFunction != NULL && MTLogEnabledValue;
#else
    return NO;
#endif
}

void MTLog(NSString *format, ...) {
#if !defined(ONEGRAM_DIAGNOSTICS)
    (void)format;
    return;
#endif
    va_list L;
    va_start(L, format);
    if (loggingFunction != NULL) {
        loggingFunction(format, L);
    }
    va_end(L);
}

void MTLogSetLoggingFunction(void (*function)(NSString *, va_list args)) {
    loggingFunction = function;
}

void MTLogSetEnabled(BOOL enabled) {
    MTLogEnabledValue = enabled;
}
