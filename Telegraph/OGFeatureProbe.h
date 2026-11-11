#import <Foundation/Foundation.h>
#import <stdarg.h>

#ifndef OG_COMPAT_FEATURE_PROBE_ENABLED
#define OG_COMPAT_FEATURE_PROBE_ENABLED 0
#endif

static inline void OGFeatureProbe(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));

static inline void OGFeatureProbe(NSString *format, ...)
{
#if OG_COMPAT_FEATURE_PROBE_ENABLED
    if (format != nil)
    {
        va_list arguments;
        va_start(arguments, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
        va_end(arguments);
    }
#else
    (void)format;
#endif
}
