

#ifndef MTLogging_H
#define MTLogging_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(ONEGRAM_DIAGNOSTICS) || defined(ONEGRAM_LOG_IMPLEMENTATION)
#undef MTLogEnabled
#undef MTLog
BOOL MTLogEnabled();
void MTLog(NSString *format, ...);
#else
#define MTLogEnabled() NO
#define MTLog(...) ((void)0)
#endif
void MTLogSetLoggingFunction(void (*function)(NSString *, va_list args));
void MTLogSetEnabled(BOOL);

#ifdef __cplusplus
}
#endif

#endif
