#import "OGCPUProfiler.h"

#if defined(ONEGRAM_DIAGNOSTICS)

#import "../OnegramPlatform/OGPlatformDispatch.h"
#include <dlfcn.h>
#include <pthread.h>
#include <sched.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <mach/thread_policy.h>
#include <libkern/OSAtomic.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

enum {
    OGCPUProfilerMaximumThreads = 64,
    OGCPUProfilerMaximumFrames = 32,
    OGCPUProfilerFrameSlots = 64,
    OGCPUProfilerReportedThreads = 4,
    OGCPUProfilerReportedFrames = 6,
    OGCPUProfilerReportedImages = 5
};

static const useconds_t OGCPUProfilerSampleInterval = 100000;
static const double OGCPUProfilerWindow = 5.0;
static const double OGCPUProfilerReportLoad = 0.3;

typedef int (*OGCPUProfilerGetNameFunction)(pthread_t, char *, size_t);
typedef pthread_t (*OGCPUProfilerFromMachThreadFunction)(mach_port_t);

typedef struct {
    uintptr_t address;
    uint32_t count;
} OGCPUProfilerFrameSlot;

typedef struct {
    thread_act_t port;
    bool used;
    bool present;
    uintptr_t stackLow;
    uintptr_t stackHigh;
    double baseline;
    double current;
    uint32_t samples;
    uint32_t overflow;
    OGCPUProfilerFrameSlot codeFrames[OGCPUProfilerFrameSlots];
    OGCPUProfilerFrameSlot callerFrames[OGCPUProfilerFrameSlots];
    OGCPUProfilerFrameSlot leafFrames[OGCPUProfilerFrameSlots];
} OGCPUProfilerThread;

static OGCPUProfilerThread OGCPUProfilerThreads[OGCPUProfilerMaximumThreads];
static thread_act_t OGCPUProfilerMainThread = MACH_PORT_NULL;
static thread_act_t OGCPUProfilerSelfThread = MACH_PORT_NULL;
static uintptr_t OGCPUProfilerTextStart = 0;
static uintptr_t OGCPUProfilerTextEnd = 0;
static uintptr_t OGCPUProfilerSlide = 0;
static OGCPUProfilerGetNameFunction OGCPUProfilerGetName = NULL;
static OGCPUProfilerFromMachThreadFunction OGCPUProfilerFromMachThread = NULL;
static double OGCPUProfilerTickSeconds = 0.0;
#if defined(ONEGRAM_ARMV6)
static OSSpinLock OGCPUProfilerGraphicsLock = OS_SPINLOCK_INIT;
static OGCPUProfilerFrameSlot OGCPUProfilerGraphicsCallers[OGCPUProfilerFrameSlots];
static uint32_t OGCPUProfilerGraphicsCount = 0;
#endif

static double OGCPUProfilerNow(void)
{
    return (double)mach_absolute_time() * OGCPUProfilerTickSeconds;
}

static void OGCPUProfilerResolveExecutable(void)
{
    const struct mach_header *header = _dyld_get_image_header(0);
    if (header == NULL)
        return;
    uintptr_t slide = (uintptr_t)_dyld_get_image_vmaddr_slide(0);
#if defined(__LP64__)
    const uint8_t *command = (const uint8_t *)header + sizeof(struct mach_header_64);
    uint32_t segmentCommand = LC_SEGMENT_64;
#else
    const uint8_t *command = (const uint8_t *)header + sizeof(struct mach_header);
    uint32_t segmentCommand = LC_SEGMENT;
#endif
    for (uint32_t index = 0; index < header->ncmds; index++)
    {
        const struct load_command *loadCommand = (const struct load_command *)command;
        if (loadCommand->cmd == segmentCommand)
        {
#if defined(__LP64__)
            const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
#else
            const struct segment_command *segment = (const struct segment_command *)command;
#endif
            if (strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) == 0)
            {
                OGCPUProfilerSlide = slide;
                OGCPUProfilerTextStart = (uintptr_t)segment->vmaddr + slide;
                OGCPUProfilerTextEnd = OGCPUProfilerTextStart + (uintptr_t)segment->vmsize;
                return;
            }
        }
        command += loadCommand->cmdsize;
    }
}

static uintptr_t OGCPUProfilerCodeAddress(uintptr_t address)
{
#if defined(__LP64__)
    return address & 0x0000000FFFFFFFFFULL;
#else
    return address & ~(uintptr_t)1;
#endif
}

static bool OGCPUProfilerIsExecutableAddress(uintptr_t address)
{
    return address >= OGCPUProfilerTextStart && address < OGCPUProfilerTextEnd;
}

static void OGCPUProfilerResolveStack(OGCPUProfilerThread *thread)
{
    thread->stackLow = 0;
    thread->stackHigh = 0;
    if (OGCPUProfilerFromMachThread == NULL)
        return;
    pthread_t pthread = OGCPUProfilerFromMachThread(thread->port);
    if (pthread == NULL)
        return;
    uintptr_t high = (uintptr_t)pthread_get_stackaddr_np(pthread);
    size_t size = pthread_get_stacksize_np(pthread);
    if (high == 0 || size == 0 || size > high)
        return;
    thread->stackHigh = high;
    thread->stackLow = high - size;
}

static int OGCPUProfilerCaptureFrames(const OGCPUProfilerThread *thread, uintptr_t *frames, int capacity)
{
    int count = 0;
    uintptr_t pointer = 0;
#if defined(__arm64__)
    arm_thread_state64_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    if (thread_get_state(thread->port, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount) != KERN_SUCCESS)
        return 0;
    frames[count++] = OGCPUProfilerCodeAddress((uintptr_t)state.__pc);
    frames[count++] = OGCPUProfilerCodeAddress((uintptr_t)state.__lr);
    pointer = (uintptr_t)state.__fp;
#elif defined(__arm__)
    arm_thread_state_t state;
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE_COUNT;
    if (thread_get_state(thread->port, ARM_THREAD_STATE, (thread_state_t)&state, &stateCount) != KERN_SUCCESS)
        return 0;
    frames[count++] = OGCPUProfilerCodeAddress((uintptr_t)state.__pc);
    frames[count++] = OGCPUProfilerCodeAddress((uintptr_t)state.__lr);
    pointer = (uintptr_t)state.__r[7];
#else
    return 0;
#endif
    while (count < capacity && thread->stackHigh != 0 && pointer >= thread->stackLow && pointer <= thread->stackHigh - 2 * sizeof(uintptr_t) && (pointer & (sizeof(uintptr_t) - 1)) == 0)
    {
        uintptr_t next = ((const uintptr_t *)pointer)[0];
        uintptr_t address = OGCPUProfilerCodeAddress(((const uintptr_t *)pointer)[1]);
        if (address == 0 || next <= pointer)
            break;
        frames[count++] = address;
        pointer = next;
    }
    return count;
}

static void OGCPUProfilerCount(OGCPUProfilerThread *thread, OGCPUProfilerFrameSlot *slots, uintptr_t address)
{
    uintptr_t index = (address >> 2) % OGCPUProfilerFrameSlots;
    for (int probe = 0; probe < OGCPUProfilerFrameSlots; probe++)
    {
        OGCPUProfilerFrameSlot *slot = &slots[(index + probe) % OGCPUProfilerFrameSlots];
        if (slot->count == 0)
        {
            slot->address = address;
            slot->count = 1;
            return;
        }
        if (slot->address == address)
        {
            slot->count++;
            return;
        }
    }
    thread->overflow++;
}

static void OGCPUProfilerRecord(OGCPUProfilerThread *thread, const uintptr_t *frames, int count)
{
    if (count == 0)
        return;
    thread->samples++;
    OGCPUProfilerCount(thread, thread->leafFrames, frames[0]);
    int first = OGCPUProfilerIsExecutableAddress(frames[0]) ? 0 : 1;
    bool foundCode = false;
    for (int index = first; index < count; index++)
    {
        if (!OGCPUProfilerIsExecutableAddress(frames[index]))
            continue;
        if (!foundCode)
        {
            OGCPUProfilerCount(thread, thread->codeFrames, frames[index] - OGCPUProfilerSlide);
            foundCode = true;
            continue;
        }
        OGCPUProfilerCount(thread, thread->callerFrames, frames[index] - OGCPUProfilerSlide);
        return;
    }
}

static void OGCPUProfilerAppendTopFrames(NSMutableString *line, OGCPUProfilerFrameSlot *slots);

#if defined(ONEGRAM_ARMV6)
static void OGCPUProfilerRecordOffMainGraphics(const void *caller)
{
    uintptr_t address = OGCPUProfilerCodeAddress((uintptr_t)caller);
    if (OGCPUProfilerIsExecutableAddress(address))
        address -= OGCPUProfilerSlide;
    OSSpinLockLock(&OGCPUProfilerGraphicsLock);
    OGCPUProfilerGraphicsCount++;
    uintptr_t index = (address >> 2) % OGCPUProfilerFrameSlots;
    for (int probe = 0; probe < OGCPUProfilerFrameSlots; probe++)
    {
        OGCPUProfilerFrameSlot *slot = &OGCPUProfilerGraphicsCallers[(index + probe) % OGCPUProfilerFrameSlots];
        if (slot->count == 0 || slot->address == address)
        {
            slot->address = address;
            slot->count++;
            break;
        }
    }
    OSSpinLockUnlock(&OGCPUProfilerGraphicsLock);
}

static void OGCPUProfilerReportOffMainGraphics(void)
{
    OGCPUProfilerFrameSlot callers[OGCPUProfilerFrameSlots];
    OSSpinLockLock(&OGCPUProfilerGraphicsLock);
    uint32_t count = OGCPUProfilerGraphicsCount;
    memcpy(callers, OGCPUProfilerGraphicsCallers, sizeof(callers));
    memset(OGCPUProfilerGraphicsCallers, 0, sizeof(OGCPUProfilerGraphicsCallers));
    OGCPUProfilerGraphicsCount = 0;
    OSSpinLockUnlock(&OGCPUProfilerGraphicsLock);
    if (count == 0)
        return;
    NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"UIKITBG count=%u callers=", (unsigned int)count];
    OGCPUProfilerAppendTopFrames(line, callers);
    OGPlatformDiagnosticLog(@"%@", line);
}
#endif

static double OGCPUProfilerThreadTime(const thread_basic_info_data_t *info)
{
    return (double)info->user_time.seconds + (double)info->user_time.microseconds / 1000000.0 + (double)info->system_time.seconds + (double)info->system_time.microseconds / 1000000.0;
}

static OGCPUProfilerThread *OGCPUProfilerThreadForPort(thread_act_t port, bool *created)
{
    OGCPUProfilerThread *available = NULL;
    for (int index = 0; index < OGCPUProfilerMaximumThreads; index++)
    {
        OGCPUProfilerThread *thread = &OGCPUProfilerThreads[index];
        if (thread->used && thread->port == port)
        {
            *created = false;
            return thread;
        }
        if (!thread->used && available == NULL)
            available = thread;
    }
    if (available == NULL)
        return NULL;
    memset(available, 0, sizeof(*available));
    available->used = true;
    available->port = port;
    *created = true;
    return available;
}

static void OGCPUProfilerTick(bool initial)
{
    thread_act_array_t ports = NULL;
    mach_msg_type_number_t portCount = 0;
    if (task_threads(mach_task_self(), &ports, &portCount) != KERN_SUCCESS)
        return;

    for (int index = 0; index < OGCPUProfilerMaximumThreads; index++)
        OGCPUProfilerThreads[index].present = false;

    uintptr_t frames[OGCPUProfilerMaximumFrames];
    for (mach_msg_type_number_t index = 0; index < portCount; index++)
    {
        thread_act_t port = ports[index];
        bool retained = false;
        if (port != OGCPUProfilerSelfThread)
        {
            thread_basic_info_data_t info;
            mach_msg_type_number_t infoCount = THREAD_BASIC_INFO_COUNT;
            if (thread_info(port, THREAD_BASIC_INFO, (thread_info_t)&info, &infoCount) == KERN_SUCCESS)
            {
                bool created = false;
                OGCPUProfilerThread *thread = OGCPUProfilerThreadForPort(port, &created);
                if (thread != NULL)
                {
                    double time = OGCPUProfilerThreadTime(&info);
                    double previous = thread->current;
                    if (created)
                    {
                        retained = true;
                        thread->baseline = initial ? time : 0.0;
                        OGCPUProfilerResolveStack(thread);
                    }
                    thread->present = true;
                    thread->current = time;
                    if (!initial && !created && time > previous && info.run_state == TH_STATE_RUNNING && (info.flags & TH_FLAGS_IDLE) == 0 && thread_suspend(port) == KERN_SUCCESS)
                    {
                        int count = OGCPUProfilerCaptureFrames(thread, frames, OGCPUProfilerMaximumFrames);
                        thread_resume(port);
                        OGCPUProfilerRecord(thread, frames, count);
                    }
                }
            }
        }
        if (!retained)
            mach_port_deallocate(mach_task_self(), port);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)ports, portCount * sizeof(thread_act_t));
}

static NSString *OGCPUProfilerThreadLabel(const OGCPUProfilerThread *thread)
{
    if (thread->port == OGCPUProfilerMainThread)
        return @"main";
    if (thread->present && OGCPUProfilerGetName != NULL && OGCPUProfilerFromMachThread != NULL)
    {
        pthread_t pthread = OGCPUProfilerFromMachThread(thread->port);
        char name[64] = { 0 };
        if (pthread != NULL && OGCPUProfilerGetName(pthread, name, sizeof(name)) == 0 && name[0] != 0)
            return [[NSString alloc] initWithUTF8String:name];
    }
    return [[NSString alloc] initWithFormat:@"#%x", (unsigned int)thread->port];
}

static void OGCPUProfilerAppendTopFrames(NSMutableString *line, OGCPUProfilerFrameSlot *slots)
{
    for (int rank = 0; rank < OGCPUProfilerReportedFrames; rank++)
    {
        OGCPUProfilerFrameSlot *best = NULL;
        for (int index = 0; index < OGCPUProfilerFrameSlots; index++)
        {
            if (slots[index].count != 0 && (best == NULL || slots[index].count > best->count))
                best = &slots[index];
        }
        if (best == NULL)
            return;
        [line appendFormat:@"%s0x%lx:%u", rank == 0 ? "" : ",", (unsigned long)best->address, (unsigned int)best->count];
        best->count = 0;
    }
}

static void OGCPUProfilerAppendLeafImages(NSMutableString *line, const OGCPUProfilerFrameSlot *slots)
{
    NSMutableArray *images = [[NSMutableArray alloc] init];
    uint32_t counts[OGCPUProfilerFrameSlots];
    for (int index = 0; index < OGCPUProfilerFrameSlots; index++)
    {
        if (slots[index].count == 0)
            continue;
        NSString *image = nil;
        if (OGCPUProfilerIsExecutableAddress(slots[index].address))
            image = @"app";
        else
        {
            Dl_info info;
            memset(&info, 0, sizeof(info));
            if (dladdr((const void *)slots[index].address, &info) != 0 && info.dli_fname != NULL)
            {
                const char *name = strrchr(info.dli_fname, '/');
                image = [[NSString alloc] initWithFormat:@"%s`%s", name == NULL ? info.dli_fname : name + 1, info.dli_sname == NULL ? "?" : info.dli_sname];
            }
            else
                image = @"?";
        }
        NSUInteger position = [images indexOfObject:image];
        if (position == NSNotFound)
        {
            counts[images.count] = slots[index].count;
            [images addObject:image];
        }
        else
            counts[position] += slots[index].count;
    }
    for (int rank = 0; rank < OGCPUProfilerReportedImages; rank++)
    {
        NSUInteger best = NSNotFound;
        for (NSUInteger index = 0; index < images.count; index++)
        {
            if (counts[index] != 0 && (best == NSNotFound || counts[index] > counts[best]))
                best = index;
        }
        if (best == NSNotFound)
            return;
        [line appendFormat:@"%s%@:%u", rank == 0 ? "" : ",", images[best], (unsigned int)counts[best]];
        counts[best] = 0;
    }
}

static void OGCPUProfilerReport(double window)
{
    OGCPUProfilerThread *ranked[OGCPUProfilerMaximumThreads];
    int rankedCount = 0;
    double total = 0.0;
    for (int index = 0; index < OGCPUProfilerMaximumThreads; index++)
    {
        OGCPUProfilerThread *thread = &OGCPUProfilerThreads[index];
        if (!thread->used)
            continue;
        double delta = MAX(0.0, thread->current - thread->baseline);
        total += delta;
        if (delta >= 0.02)
            ranked[rankedCount++] = thread;
    }
    for (int outer = 1; outer < rankedCount; outer++)
    {
        OGCPUProfilerThread *thread = ranked[outer];
        double delta = thread->current - thread->baseline;
        int inner = outer - 1;
        while (inner >= 0 && ranked[inner]->current - ranked[inner]->baseline < delta)
        {
            ranked[inner + 1] = ranked[inner];
            inner--;
        }
        ranked[inner + 1] = thread;
    }

    if (total >= window * OGCPUProfilerReportLoad)
    {
        NSMutableString *summary = [[NSMutableString alloc] initWithFormat:@"CPUSTAT window_ms=%.0f cpu_ms=%.0f threads=", window * 1000.0, total * 1000.0];
        for (int index = 0; index < rankedCount; index++)
            [summary appendFormat:@"%s%@:%.0f", index == 0 ? "" : ",", OGCPUProfilerThreadLabel(ranked[index]), (ranked[index]->current - ranked[index]->baseline) * 1000.0];
        OGPlatformDiagnosticLog(@"%@", summary);

        int reported = MIN(rankedCount, (int)OGCPUProfilerReportedThreads);
        for (int index = 0; index < reported; index++)
        {
            OGCPUProfilerThread *thread = ranked[index];
            if (thread->samples == 0)
                continue;
            NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"CPUHOT thread=%@ cpu_ms=%.0f samples=%u overflow=%u images=", OGCPUProfilerThreadLabel(thread), (thread->current - thread->baseline) * 1000.0, (unsigned int)thread->samples, (unsigned int)thread->overflow];
            OGCPUProfilerAppendLeafImages(line, thread->leafFrames);
            [line appendString:@" code="];
            OGCPUProfilerAppendTopFrames(line, thread->codeFrames);
            [line appendString:@" caller="];
            OGCPUProfilerAppendTopFrames(line, thread->callerFrames);
            OGPlatformDiagnosticLog(@"%@", line);
        }
    }

    for (int index = 0; index < OGCPUProfilerMaximumThreads; index++)
    {
        OGCPUProfilerThread *thread = &OGCPUProfilerThreads[index];
        if (!thread->used)
            continue;
        if (!thread->present)
        {
            mach_port_deallocate(mach_task_self(), thread->port);
            memset(thread, 0, sizeof(*thread));
            continue;
        }
        thread->baseline = thread->current;
        thread->samples = 0;
        thread->overflow = 0;
        memset(thread->codeFrames, 0, sizeof(thread->codeFrames));
        memset(thread->callerFrames, 0, sizeof(thread->callerFrames));
        memset(thread->leafFrames, 0, sizeof(thread->leafFrames));
    }
}

static void OGCPUProfilerConfigureThread(void)
{
    pthread_t thread = pthread_self();
    int policy = 0;
    struct sched_param parameters;
    if (pthread_getschedparam(thread, &policy, &parameters) == 0)
    {
        int priority = sched_get_priority_max(policy);
        if (priority != -1)
        {
            parameters.sched_priority = priority;
            pthread_setschedparam(thread, policy, &parameters);
        }
    }
    thread_extended_policy_data_t extended;
    extended.timeshare = false;
    thread_policy_set(pthread_mach_thread_np(thread), THREAD_EXTENDED_POLICY, (thread_policy_t)&extended, THREAD_EXTENDED_POLICY_COUNT);

    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    double ticksPerMillisecond = 1000000.0 * (double)timebase.denom / (double)timebase.numer;
    thread_time_constraint_policy_data_t constraint;
    constraint.period = (uint32_t)((double)(OGCPUProfilerSampleInterval / 1000) * ticksPerMillisecond);
    constraint.computation = (uint32_t)(2.0 * ticksPerMillisecond);
    constraint.constraint = (uint32_t)(5.0 * ticksPerMillisecond);
    constraint.preemptible = 1;
    thread_policy_set(pthread_mach_thread_np(thread), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&constraint, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

static void *OGCPUProfilerThreadMain(void *__unused argument)
{
    OGCPUProfilerSelfThread = pthread_mach_thread_np(pthread_self());
    OGCPUProfilerConfigureThread();
    OGPlatformDiagnosticLog(@"CPUPROFILER start text=0x%lx-0x%lx slide=0x%lx interval_ms=%u", (unsigned long)(OGCPUProfilerTextStart - OGCPUProfilerSlide), (unsigned long)(OGCPUProfilerTextEnd - OGCPUProfilerSlide), (unsigned long)OGCPUProfilerSlide, (unsigned int)(OGCPUProfilerSampleInterval / 1000));

    OGCPUProfilerTick(true);
    double windowStart = OGCPUProfilerNow();
    for (;;)
    {
        usleep(OGCPUProfilerSampleInterval);
        OGCPUProfilerTick(false);
        double now = OGCPUProfilerNow();
        if (now - windowStart >= OGCPUProfilerWindow)
        {
            @autoreleasepool
            {
                OGCPUProfilerReport(now - windowStart);
#if defined(ONEGRAM_ARMV6)
                OGCPUProfilerReportOffMainGraphics();
#endif
            }
            windowStart = now;
        }
    }
    return NULL;
}

void OGCPUProfilerStart(void)
{
    static bool started = false;
    if (started)
        return;
    started = true;

    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    OGCPUProfilerTickSeconds = (double)timebase.numer / (double)timebase.denom / 1000000000.0;
    OGCPUProfilerMainThread = pthread_mach_thread_np(pthread_self());
    OGCPUProfilerGetName = (OGCPUProfilerGetNameFunction)dlsym(RTLD_DEFAULT, "pthread_getname_np");
    OGCPUProfilerFromMachThread = (OGCPUProfilerFromMachThreadFunction)dlsym(RTLD_DEFAULT, "pthread_from_mach_thread_np");
    OGCPUProfilerResolveExecutable();
#if defined(ONEGRAM_ARMV6)
    OnegramIOS3OffMainGraphicsHandler = OGCPUProfilerRecordOffMainGraphics;
#endif

    pthread_t profiler;
    if (pthread_create(&profiler, NULL, OGCPUProfilerThreadMain, NULL) == 0)
        pthread_detach(profiler);
}

#endif
