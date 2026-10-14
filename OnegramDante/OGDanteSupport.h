#include <stdint.h>
#include <stdlib.h>

static inline uint32_t DanteRandomUniform(uint32_t upper)
{
    if (upper < 2U) return 0U;
    uint32_t minimum = (uint32_t)(-upper % upper);
    uint32_t value;
    do { value = arc4random(); } while (value < minimum);
    return value % upper;
}

#ifdef __OBJC__
#import <Foundation/Foundation.h>
#ifndef NS_ENUM
#define NS_ENUM(type, name) enum name : type name; enum name : type
#endif
void OGDanteLog(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));
#define DLog OGDanteLog
#define DLogVerbose OGDanteLog
#endif
