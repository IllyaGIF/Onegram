

#ifndef MTLogging_H
#define MTLogging_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

#undef MTLogEnabled
#undef MTLog
BOOL MTLogEnabled();
void MTLog(NSString *format, ...);
#if !defined(ONEGRAM_LOG_IMPLEMENTATION)
#define MTLog(...) (MTLogEnabled() ? MTLog(__VA_ARGS__) : (void)0)
#endif
void MTLogSetLoggingFunction(void (*function)(NSString *, va_list args));
void MTLogSetEnabled(BOOL);

#ifdef __cplusplus
}
#endif

#endif
