#import "OGDeviceTier.h"

#import <sys/sysctl.h>
#import <pthread.h>

static pthread_once_t OGDeviceTierOnce = PTHREAD_ONCE_INIT;
static OGDeviceTier OGDeviceTierValue = OGDeviceTierLow;
static uint64_t OGDeviceMemoryValue = 0;

static void OGDeviceTierInitialize(void)
{
    uint64_t memory = 0;
    size_t size = sizeof(memory);
    if (sysctlbyname("hw.memsize", &memory, &size, NULL, 0) != 0 || size == 0 || memory == 0)
        memory = [[NSProcessInfo processInfo] physicalMemory];
    OGDeviceMemoryValue = memory;

    uint32_t cores = 1;
    size = sizeof(cores);
    if (sysctlbyname("hw.ncpu", &cores, &size, NULL, 0) != 0 || cores == 0)
        cores = 1;

    if (memory <= 768ULL * 1024ULL * 1024ULL || cores <= 1)
        OGDeviceTierValue = OGDeviceTierLow;
    else if (memory <= 2ULL * 1024ULL * 1024ULL * 1024ULL || cores <= 2)
        OGDeviceTierValue = OGDeviceTierMedium;
    else
        OGDeviceTierValue = OGDeviceTierHigh;
}

OGDeviceTier OGDeviceTierCurrent(void)
{
    pthread_once(&OGDeviceTierOnce, OGDeviceTierInitialize);
    return OGDeviceTierValue;
}

uint64_t OGDevicePhysicalMemory(void)
{
    pthread_once(&OGDeviceTierOnce, OGDeviceTierInitialize);
    return OGDeviceMemoryValue;
}
