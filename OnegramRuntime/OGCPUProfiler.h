#import <Foundation/Foundation.h>

typedef struct
{
    size_t inUse;
    size_t reserved;
    uint64_t ticks;
} OGMemoryGrowthSample;

FOUNDATION_EXPORT void OGCPUProfilerStart(void);
FOUNDATION_EXPORT void OGCPUProfilerRegisterMemoryCounter(NSString *name, uint64_t (^bytes)(void));
FOUNDATION_EXPORT OGMemoryGrowthSample OGMemoryGrowthBegin(void);
FOUNDATION_EXPORT void OGMemoryGrowthEnd(OGMemoryGrowthSample sample, const char *queue, const char *file, int line);
