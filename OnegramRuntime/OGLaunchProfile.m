#if defined(ONEGRAM_LAUNCH_PROFILE)

#import <Foundation/Foundation.h>
#include <libkern/OSAtomic.h>
#include <mach-o/dyld.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdio.h>
#include <syslog.h>
#include <unistd.h>

#define OG_LAUNCH_PROFILE_FUNCTION __attribute__((no_instrument_function))

enum
{
    OGLaunchProfileTableSize = 1 << 17,
    OGLaunchProfileListCapacity = 1 << 16,
    OGLaunchProfileProbeLimit = 64,
    OGLaunchProfileAddressesPerLine = 32
};

static const uint64_t OGLaunchProfileDurationSeconds = 240;

static uintptr_t volatile OGLaunchProfileTable[OGLaunchProfileTableSize];
static uintptr_t OGLaunchProfileList[OGLaunchProfileListCapacity];
static volatile int32_t OGLaunchProfileCount = 0;
static volatile int32_t OGLaunchProfileActive = 1;

void __cyg_profile_func_enter(void *function, void *site) OG_LAUNCH_PROFILE_FUNCTION;
void __cyg_profile_func_exit(void *function, void *site) OG_LAUNCH_PROFILE_FUNCTION;

void __cyg_profile_func_enter(void *function, void *site)
{
    (void)site;
    if (OGLaunchProfileActive == 0 || function == NULL)
        return;
    uintptr_t key = (uintptr_t)function;
    uint32_t hash = (uint32_t)(key >> 1) * 2654435761u;
    for (uint32_t probe = 0; probe < OGLaunchProfileProbeLimit; probe++)
    {
        uintptr_t volatile *slot = &OGLaunchProfileTable[(hash + probe) & (OGLaunchProfileTableSize - 1)];
        uintptr_t current = *slot;
        if (current == key)
            return;
        if (current != 0)
            continue;
        if (!OSAtomicCompareAndSwapPtrBarrier(NULL, (void *)key, (void *volatile *)slot))
        {
            if (*slot == key)
                return;
            continue;
        }
        int32_t position = OSAtomicIncrement32Barrier(&OGLaunchProfileCount) - 1;
        if (position < OGLaunchProfileListCapacity)
            OGLaunchProfileList[position] = key;
        else
            OGLaunchProfileActive = 0;
        return;
    }
}

void __cyg_profile_func_exit(void *function, void *site)
{
    (void)function;
    (void)site;
}

static void OGLaunchProfileWrite(uintptr_t slide, int32_t count) OG_LAUNCH_PROFILE_FUNCTION;
static void OGLaunchProfileWrite(uintptr_t slide, int32_t count)
{
    @autoreleasepool
    {
        NSArray *directories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *path = directories.count == 0 ? nil : [[directories objectAtIndex:0] stringByAppendingPathComponent:@"launch-order.txt"];
        FILE *file = path == nil ? NULL : fopen([path fileSystemRepresentation], "w");
        char line[OGLaunchProfileAddressesPerLine * 10 + 64];
        int32_t chunk = 0;
        for (int32_t start = 0; start < count; start += OGLaunchProfileAddressesPerLine)
        {
            int length = snprintf(line, sizeof(line), "LAUNCHORDER chunk=%d", (int)chunk++);
            int32_t end = MIN(count, start + OGLaunchProfileAddressesPerLine);
            for (int32_t index = start; index < end; index++)
            {
                uintptr_t address = OGLaunchProfileList[index] - slide;
                length += snprintf(line + length, sizeof(line) - (size_t)length, " %lx", (unsigned long)address);
                if (file != NULL)
                    fprintf(file, "%lx\n", (unsigned long)address);
            }
            syslog(LOG_WARNING, "%s", line);
            usleep(2000);
        }
        if (file != NULL)
            fclose(file);
        syslog(LOG_WARNING, "LAUNCHORDER end count=%d slide=%lx", (int)count, (unsigned long)slide);
    }
}

static void *OGLaunchProfileThreadMain(void *context) OG_LAUNCH_PROFILE_FUNCTION;
static void *OGLaunchProfileThreadMain(void *context)
{
    (void)context;
    sleep((unsigned int)OGLaunchProfileDurationSeconds);
    OGLaunchProfileActive = 0;
    OSMemoryBarrier();
    int32_t count = MIN(OGLaunchProfileCount, (int32_t)OGLaunchProfileListCapacity);
    OGLaunchProfileWrite((uintptr_t)_dyld_get_image_vmaddr_slide(0), count);
    return NULL;
}

__attribute__((constructor, no_instrument_function)) static void OGLaunchProfileStart(void)
{
    pthread_t thread;
    if (pthread_create(&thread, NULL, OGLaunchProfileThreadMain, NULL) == 0)
        pthread_detach(thread);
}

#endif
