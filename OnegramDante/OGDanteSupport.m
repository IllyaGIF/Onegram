#import "OGDanteSupport.h"
#include <stdarg.h>

void OGDanteLog(NSString *format, ...)
{
#if ONEGRAM_DIAGNOSTICS
    va_list arguments;
    va_start(arguments, format);
    NSLogv(format, arguments);
    va_end(arguments);
#endif
}
