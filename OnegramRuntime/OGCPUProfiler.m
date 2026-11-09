#import "OGCPUProfiler.h"


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
#include <malloc/malloc.h>

enum {
    OGCPUProfilerMaximumThreads = 64,
    OGCPUProfilerMaximumFrames = 32,
    OGCPUProfilerFrameSlots = 64,
    OGCPUProfilerReportedThreads = 4,
    OGCPUProfilerReportedFrames = 6,
    OGCPUProfilerReportedImages = 5,
    OGCPUProfilerMainInclusiveSlots = 512,
    OGCPUProfilerMainReportedFrames = 24
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
static pthread_mutex_t OGCPUProfilerMemoryCountersLock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary *OGCPUProfilerMemoryCounters = nil;

void OGCPUProfilerRegisterMemoryCounter(NSString *name, uint64_t (^bytes)(void))
{
    if (![name isKindOfClass:[NSString class]] || name.length == 0 || name.length > 48 || bytes == nil)
        return;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_."];
    if ([name rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound)
        return;
    pthread_mutex_lock(&OGCPUProfilerMemoryCountersLock);
    if (OGCPUProfilerMemoryCounters == nil)
        OGCPUProfilerMemoryCounters = [[NSMutableDictionary alloc] init];
    if (OGCPUProfilerMemoryCounters[name] != nil || OGCPUProfilerMemoryCounters.count < 32)
        OGCPUProfilerMemoryCounters[name] = [bytes copy];
    pthread_mutex_unlock(&OGCPUProfilerMemoryCountersLock);
}

static NSDictionary *OGCPUProfilerMemoryCounterSnapshot(void)
{
    pthread_mutex_lock(&OGCPUProfilerMemoryCountersLock);
    NSDictionary *snapshot = [OGCPUProfilerMemoryCounters copy];
    pthread_mutex_unlock(&OGCPUProfilerMemoryCountersLock);
    return snapshot;
}
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
        uintptr_t record[2];
        vm_size_t bytesRead = 0;
        if (vm_read_overwrite(mach_task_self(), (vm_address_t)pointer, sizeof(record), (vm_address_t)record, &bytesRead) != KERN_SUCCESS || bytesRead != sizeof(record))
            break;
        uintptr_t next = record[0];
        uintptr_t address = OGCPUProfilerCodeAddress(record[1]);
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

static OGCPUProfilerFrameSlot OGCPUProfilerMainInclusive[OGCPUProfilerMainInclusiveSlots];
static uint32_t OGCPUProfilerMainInclusiveOverflow = 0;

static void OGCPUProfilerRecordMainInclusive(const uintptr_t *frames, int count)
{
    for (int index = 0; index < count; index++)
    {
        uintptr_t frame = frames[index];
        if (!OGCPUProfilerIsExecutableAddress(frame))
            continue;
        bool repeated = false;
        for (int previous = 0; previous < index; previous++)
        {
            if (frames[previous] == frame)
            {
                repeated = true;
                break;
            }
        }
        if (repeated)
            continue;
        uintptr_t address = frame - OGCPUProfilerSlide;
        uintptr_t slotIndex = (address >> 1) % OGCPUProfilerMainInclusiveSlots;
        bool stored = false;
        for (int probe = 0; probe < OGCPUProfilerMainInclusiveSlots; probe++)
        {
            OGCPUProfilerFrameSlot *slot = &OGCPUProfilerMainInclusive[(slotIndex + probe) % OGCPUProfilerMainInclusiveSlots];
            if (slot->count == 0)
            {
                slot->address = address;
                slot->count = 1;
                stored = true;
                break;
            }
            if (slot->address == address)
            {
                slot->count++;
                stored = true;
                break;
            }
        }
        if (!stored)
            OGCPUProfilerMainInclusiveOverflow++;
    }
}

static void OGCPUProfilerRecord(OGCPUProfilerThread *thread, const uintptr_t *frames, int count)
{
    if (count == 0)
        return;
    thread->samples++;
    if (thread->port == OGCPUProfilerMainThread)
        OGCPUProfilerRecordMainInclusive(frames, count);
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

static NSString *OGCPUProfilerThreadPriority(const OGCPUProfilerThread *thread)
{
    if (!thread->present)
        return @"-";
    policy_rr_info_data_t fixedInfo;
    mach_msg_type_number_t count = POLICY_RR_INFO_COUNT;
    if (thread_info(thread->port, THREAD_SCHED_RR_INFO, (thread_info_t)&fixedInfo, &count) == KERN_SUCCESS)
        return [[NSString alloc] initWithFormat:@"%df", fixedInfo.base_priority];
    policy_timeshare_info_data_t timeshareInfo;
    count = POLICY_TIMESHARE_INFO_COUNT;
    if (thread_info(thread->port, THREAD_SCHED_TIMESHARE_INFO, (thread_info_t)&timeshareInfo, &count) == KERN_SUCCESS)
        return [[NSString alloc] initWithFormat:@"%d/%d", timeshareInfo.cur_priority, timeshareInfo.base_priority];
    return @"?";
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

extern long long sqlite3_memory_used(void);
extern long long sqlite3_memory_highwater(int resetFlag);

static const size_t OGMemoryGrowthReportThreshold = 768 * 1024;

OGMemoryGrowthSample OGMemoryGrowthBegin(void)
{
    malloc_statistics_t heap;
    memset(&heap, 0, sizeof(heap));
    malloc_zone_statistics(NULL, &heap);
    OGMemoryGrowthSample sample = { heap.size_in_use, heap.size_allocated, mach_absolute_time() };
    return sample;
}

void OGMemoryGrowthEnd(OGMemoryGrowthSample sample, const char *queue, const char *file, int line)
{
    malloc_statistics_t heap;
    memset(&heap, 0, sizeof(heap));
    malloc_zone_statistics(NULL, &heap);
    long long reservedDelta = (long long)heap.size_allocated - (long long)sample.reserved;
    long long inUseDelta = (long long)heap.size_in_use - (long long)sample.inUse;
    if (reservedDelta < (long long)OGMemoryGrowthReportThreshold && inUseDelta < (long long)OGMemoryGrowthReportThreshold)
        return;
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    double milliseconds = (double)(mach_absolute_time() - sample.ticks) * (double)timebase.numer / (double)timebase.denom / 1000000.0;
    const char *fileName = file == NULL ? "?" : (strrchr(file, '/') != NULL ? strrchr(file, '/') + 1 : file);
    OGPlatformDiagnosticLog(@"MEMGROW queue=%s site=%s:%d reserved_kb=%+lld inuse_kb=%+lld heap_kb=%u reserved_total_kb=%u ms=%.0f", queue, fileName, line, reservedDelta / 1024, inUseDelta / 1024, (unsigned int)(heap.size_in_use / 1024), (unsigned int)(heap.size_allocated / 1024), milliseconds);
}

typedef void (OGHeapProfilerLoggerFunction)(uint32_t type, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t result, uint32_t skippedFrames);

enum
{
    OGHeapProfilerLiveCapacity = 16384,
    OGHeapProfilerSiteCapacity = 1024,
    OGHeapProfilerSiteSlots = 2048,
    OGHeapProfilerReportedSites = 20,
    OGHeapProfilerFrameDepth = 24,
    OGHeapProfilerTypeAllocate = 2,
    OGHeapProfilerTypeDeallocate = 4,
    OGHeapProfilerTypeHasZone = 8,
    OGHeapProfilerSmallSampleShift = 6,
    OGHeapProfilerSampledFlag = 0x80000000u
};

static const uintptr_t OGHeapProfilerThreshold = 16 * 1024;

typedef struct
{
    uintptr_t pointer;
    uint32_t size;
    uint32_t site;
} OGHeapProfilerLiveEntry;

typedef struct
{
    uintptr_t address;
    uint64_t liveBytes;
    uint64_t peakBytes;
    uint32_t liveCount;
    uint32_t allocations;
} OGHeapProfilerSite;

static OGHeapProfilerLiveEntry OGHeapProfilerLive[OGHeapProfilerLiveCapacity];
static OGHeapProfilerSite OGHeapProfilerSites[OGHeapProfilerSiteCapacity];
static OGHeapProfilerSite OGHeapProfilerSnapshot[OGHeapProfilerSiteCapacity];
static uint32_t OGHeapProfilerSiteIndices[OGHeapProfilerSiteSlots];
static uint32_t OGHeapProfilerSiteCount = 0;
static uint32_t OGHeapProfilerLiveCount = 0;
static uint64_t OGHeapProfilerLiveBytes = 0;
static uint64_t OGHeapProfilerPeakBytes = 0;
static uint32_t OGHeapProfilerDropped = 0;
static uint64_t OGHeapProfilerSmallSampledBytes = 0;
static OSSpinLock OGHeapProfilerLock = OS_SPINLOCK_INIT;
static OGHeapProfilerLoggerFunction *OGHeapProfilerPreviousLogger = NULL;

static inline bool OGHeapProfilerSampledPointer(uintptr_t pointer)
{
    return ((uint32_t)((pointer >> 4) * 2654435761u) >> (32 - OGHeapProfilerSmallSampleShift)) == 0;
}

static inline uint32_t OGHeapProfilerPointerSlot(uintptr_t pointer)
{
    return (uint32_t)((pointer >> 12) * 2654435761u) & (OGHeapProfilerLiveCapacity - 1);
}

static uint32_t OGHeapProfilerSiteForAddressLocked(uintptr_t address)
{
    uint32_t slot = (uint32_t)((address >> 2) * 2654435761u) & (OGHeapProfilerSiteSlots - 1);
    for (uint32_t probe = 0; probe < OGHeapProfilerSiteSlots; probe++)
    {
        uint32_t stored = OGHeapProfilerSiteIndices[slot];
        if (stored == 0)
        {
            if (OGHeapProfilerSiteCount >= OGHeapProfilerSiteCapacity)
                return 0;
            OGHeapProfilerSites[OGHeapProfilerSiteCount].address = address;
            OGHeapProfilerSiteCount++;
            OGHeapProfilerSiteIndices[slot] = OGHeapProfilerSiteCount;
            return OGHeapProfilerSiteCount;
        }
        if (OGHeapProfilerSites[stored - 1].address == address)
            return stored;
        slot = (slot + 1) & (OGHeapProfilerSiteSlots - 1);
    }
    return 0;
}

static void OGHeapProfilerRemoveLocked(uintptr_t pointer)
{
    uint32_t index = OGHeapProfilerPointerSlot(pointer);
    for (uint32_t probe = 0; probe < OGHeapProfilerLiveCapacity; probe++)
    {
        uintptr_t stored = OGHeapProfilerLive[index].pointer;
        if (stored == 0)
            return;
        if (stored == pointer)
            break;
        index = (index + 1) & (OGHeapProfilerLiveCapacity - 1);
    }
    if (OGHeapProfilerLive[index].pointer != pointer)
        return;

    OGHeapProfilerLiveEntry entry = OGHeapProfilerLive[index];
    bool sampled = (entry.site & OGHeapProfilerSampledFlag) != 0;
    uint32_t siteIndex = entry.site & ~OGHeapProfilerSampledFlag;
    uint64_t weightedSize = sampled ? ((uint64_t)entry.size << OGHeapProfilerSmallSampleShift) : entry.size;
    if (siteIndex != 0)
    {
        OGHeapProfilerSite *site = &OGHeapProfilerSites[siteIndex - 1];
        site->liveBytes -= weightedSize;
        site->liveCount--;
    }
    if (sampled)
        OGHeapProfilerSmallSampledBytes -= entry.size;
    else
        OGHeapProfilerLiveBytes -= entry.size;
    OGHeapProfilerLiveCount--;

    uint32_t hole = index;
    uint32_t next = index;
    for (;;)
    {
        next = (next + 1) & (OGHeapProfilerLiveCapacity - 1);
        uintptr_t candidate = OGHeapProfilerLive[next].pointer;
        if (candidate == 0)
            break;
        uint32_t home = OGHeapProfilerPointerSlot(candidate);
        bool movable = hole <= next ? (home <= hole || home > next) : (home <= hole && home > next);
        if (movable)
        {
            OGHeapProfilerLive[hole] = OGHeapProfilerLive[next];
            hole = next;
        }
    }
    OGHeapProfilerLive[hole].pointer = 0;
}

static void OGHeapProfilerInsertLocked(uintptr_t pointer, uintptr_t size, uintptr_t address, bool sampled)
{
    if (OGHeapProfilerLiveCount >= OGHeapProfilerLiveCapacity / 2)
    {
        OGHeapProfilerDropped++;
        return;
    }
    uint32_t index = OGHeapProfilerPointerSlot(pointer);
    while (OGHeapProfilerLive[index].pointer != 0)
        index = (index + 1) & (OGHeapProfilerLiveCapacity - 1);

    uint32_t site = address == 0 ? 0 : OGHeapProfilerSiteForAddressLocked(address);
    uint64_t weightedSize = sampled ? ((uint64_t)size << OGHeapProfilerSmallSampleShift) : size;
    OGHeapProfilerLive[index].pointer = pointer;
    OGHeapProfilerLive[index].size = (uint32_t)size;
    OGHeapProfilerLive[index].site = site | (sampled ? OGHeapProfilerSampledFlag : 0);
    OGHeapProfilerLiveCount++;
    if (sampled)
        OGHeapProfilerSmallSampledBytes += size;
    else
        OGHeapProfilerLiveBytes += size;
    if (OGHeapProfilerLiveBytes > OGHeapProfilerPeakBytes)
        OGHeapProfilerPeakBytes = OGHeapProfilerLiveBytes;
    if (site != 0)
    {
        OGHeapProfilerSite *entry = &OGHeapProfilerSites[site - 1];
        entry->liveBytes += weightedSize;
        entry->liveCount++;
        entry->allocations++;
        if (entry->liveBytes > entry->peakBytes)
            entry->peakBytes = entry->liveBytes;
    }
}

__attribute__((noinline)) static uintptr_t OGHeapProfilerCallSite(void)
{
    uintptr_t *frame = (uintptr_t *)__builtin_frame_address(0);
    for (int depth = 0; depth < OGHeapProfilerFrameDepth && frame != NULL; depth++)
    {
        uintptr_t *next = (uintptr_t *)frame[0];
        uintptr_t returnAddress = frame[1];
        if (depth >= 2 && OGCPUProfilerIsExecutableAddress(returnAddress))
            return returnAddress;
        if (next <= frame || (uintptr_t)next - (uintptr_t)frame > 1024 * 1024 || ((uintptr_t)next & (sizeof(uintptr_t) - 1)) != 0)
            break;
        frame = next;
    }
    return 0;
}

static void OGHeapProfilerLogger(uint32_t type, uintptr_t arg1, uintptr_t arg2, uintptr_t arg3, uintptr_t result, uint32_t skippedFrames)
{
    if (OGHeapProfilerPreviousLogger != NULL)
        OGHeapProfilerPreviousLogger(type, arg1, arg2, arg3, result, skippedFrames + 1);

    bool allocate = (type & OGHeapProfilerTypeAllocate) != 0;
    bool deallocate = (type & OGHeapProfilerTypeDeallocate) != 0;
    if (!allocate && !deallocate)
        return;
    bool hasZone = (type & OGHeapProfilerTypeHasZone) != 0;
    uintptr_t freed = deallocate ? (hasZone ? arg2 : arg1) : 0;
    uintptr_t size = allocate ? (deallocate ? (hasZone ? arg3 : arg2) : (hasZone ? arg2 : arg1)) : 0;
    bool trackFree = freed != 0 && ((freed & 0xfff) == 0 || OGHeapProfilerSampledPointer(freed));
    bool large = size >= OGHeapProfilerThreshold;
    bool trackAllocation = allocate && result != 0 && size != 0 && (large || OGHeapProfilerSampledPointer(result));
    if (!trackFree && !trackAllocation)
        return;

    uintptr_t address = trackAllocation ? OGHeapProfilerCallSite() : 0;
    OSSpinLockLock(&OGHeapProfilerLock);
    if (trackFree)
        OGHeapProfilerRemoveLocked(freed);
    if (trackAllocation)
        OGHeapProfilerInsertLocked(result, size, address, !large);
    OSSpinLockUnlock(&OGHeapProfilerLock);
}

static void OGHeapProfilerInstall(void)
{
    OGHeapProfilerLoggerFunction **logger = (OGHeapProfilerLoggerFunction **)dlsym(RTLD_DEFAULT, "malloc_logger");
    if (logger == NULL)
    {
        OGPlatformDiagnosticLog(@"HEAPTOP unavailable");
        return;
    }
    OGHeapProfilerPreviousLogger = *logger;
    *logger = OGHeapProfilerLogger;
}

static void OGHeapProfilerReport(const char *reason)
{
    OSSpinLockLock(&OGHeapProfilerLock);
    uint32_t siteCount = OGHeapProfilerSiteCount;
    memcpy(OGHeapProfilerSnapshot, OGHeapProfilerSites, sizeof(OGHeapProfilerSite) * siteCount);
    uint64_t liveBytes = OGHeapProfilerLiveBytes;
    uint64_t peakBytes = OGHeapProfilerPeakBytes;
    uint32_t liveCount = OGHeapProfilerLiveCount;
    uint32_t dropped = OGHeapProfilerDropped;
    uint64_t smallEstimate = OGHeapProfilerSmallSampledBytes << OGHeapProfilerSmallSampleShift;
    OSSpinLockUnlock(&OGHeapProfilerLock);

    NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"HEAPTOP reason=%s live_kb=%llu peak_kb=%llu small_estimate_kb=%llu blocks=%u dropped=%u sites=", reason, liveBytes / 1024, peakBytes / 1024, smallEstimate / 1024, liveCount, dropped];
    for (int rank = 0; rank < OGHeapProfilerReportedSites; rank++)
    {
        uint32_t best = UINT32_MAX;
        for (uint32_t index = 0; index < siteCount; index++)
        {
            if (OGHeapProfilerSnapshot[index].peakBytes == 0)
                continue;
            if (best == UINT32_MAX || OGHeapProfilerSnapshot[index].liveBytes > OGHeapProfilerSnapshot[best].liveBytes || (OGHeapProfilerSnapshot[index].liveBytes == OGHeapProfilerSnapshot[best].liveBytes && OGHeapProfilerSnapshot[index].peakBytes > OGHeapProfilerSnapshot[best].peakBytes))
                best = index;
        }
        if (best == UINT32_MAX)
            break;
        OGHeapProfilerSite *site = &OGHeapProfilerSnapshot[best];
        [line appendFormat:@"%s0x%lx:%llu/%u/%llu/%u", rank == 0 ? "" : ",", (unsigned long)(site->address - OGCPUProfilerSlide), site->liveBytes / 1024, site->liveCount, site->peakBytes / 1024, site->allocations];
        site->peakBytes = 0;
        site->liveBytes = 0;
    }
    OGPlatformDiagnosticLog(@"%@", line);
}

static void OGCPUProfilerReportMemory(double window)
{
    static bool initialized = false;
    static integer_t previousFaults = 0;
    static integer_t previousPageins = 0;
    task_basic_info_data_t basic;
    mach_msg_type_number_t basicCount = TASK_BASIC_INFO_COUNT;
    task_events_info_data_t events;
    mach_msg_type_number_t eventsCount = TASK_EVENTS_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&basic, &basicCount) != KERN_SUCCESS || task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&events, &eventsCount) != KERN_SUCCESS)
        return;
    malloc_statistics_t heap;
    memset(&heap, 0, sizeof(heap));
    malloc_zone_statistics(NULL, &heap);
    int threads = 0;
    for (int index = 0; index < OGCPUProfilerMaximumThreads; index++)
    {
        if (OGCPUProfilerThreads[index].used && OGCPUProfilerThreads[index].present)
            threads++;
    }
    static uint32_t reports = 0;
    if (initialized && (++reports % 6) == 0)
        OGHeapProfilerReport("periodic");
    if (initialized)
    {
        NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"MEMSTAT window_ms=%.0f resident_kb=%u virtual_kb=%u heap_kb=%u heap_allocated_kb=%u sqlite_kb=%lld sqlite_peak_kb=%lld faults=%d pageins=%d threads=%d", window * 1000.0, (unsigned int)(basic.resident_size / 1024), (unsigned int)(basic.virtual_size / 1024), (unsigned int)(heap.size_in_use / 1024), (unsigned int)(heap.size_allocated / 1024), sqlite3_memory_used() / 1024, sqlite3_memory_highwater(0) / 1024, (int)(events.faults - previousFaults), (int)(events.pageins - previousPageins), threads];
        NSDictionary *counters = OGCPUProfilerMemoryCounterSnapshot();
        NSArray *names = [[counters allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *name in names)
        {
            uint64_t (^counter)(void) = counters[name];
            uint64_t value = counter();
            if ([name hasPrefix:@"count."])
                [line appendFormat:@" %@=%llu", name, (unsigned long long)value];
            else
                [line appendFormat:@" %@_kb=%llu", name, (unsigned long long)(value / 1024)];
        }
        OGPlatformDiagnosticLog(@"%@", line);
    }
    initialized = true;
    previousFaults = events.faults;
    previousPageins = events.pageins;
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
            [summary appendFormat:@"%s%@:%.0f@%@", index == 0 ? "" : ",", OGCPUProfilerThreadLabel(ranked[index]), (ranked[index]->current - ranked[index]->baseline) * 1000.0, OGCPUProfilerThreadPriority(ranked[index])];
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
        if (!thread->used || thread->port != OGCPUProfilerMainThread || thread->samples == 0)
            continue;
        NSMutableString *line = [[NSMutableString alloc] initWithFormat:@"CPUMAIN cpu_ms=%.0f samples=%u overflow=%u inclusive=", (thread->current - thread->baseline) * 1000.0, (unsigned int)thread->samples, (unsigned int)OGCPUProfilerMainInclusiveOverflow];
        for (int rank = 0; rank < OGCPUProfilerMainReportedFrames; rank++)
        {
            OGCPUProfilerFrameSlot *best = NULL;
            for (int slot = 0; slot < OGCPUProfilerMainInclusiveSlots; slot++)
            {
                if (OGCPUProfilerMainInclusive[slot].count != 0 && (best == NULL || OGCPUProfilerMainInclusive[slot].count > best->count))
                    best = &OGCPUProfilerMainInclusive[slot];
            }
            if (best == NULL)
                break;
            [line appendFormat:@"%s0x%lx:%u", rank == 0 ? "" : ",", (unsigned long)best->address, (unsigned int)best->count];
            best->count = 0;
        }
        OGPlatformDiagnosticLog(@"%@", line);
    }
    memset(OGCPUProfilerMainInclusive, 0, sizeof(OGCPUProfilerMainInclusive));
    OGCPUProfilerMainInclusiveOverflow = 0;
    OGCPUProfilerReportMemory(window);

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
    OGHeapProfilerInstall();
    [[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidReceiveMemoryWarningNotification" object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
    {
        OGHeapProfilerReport("memory_warning");
    }];
#if defined(ONEGRAM_ARMV6)
    OnegramIOS3OffMainGraphicsHandler = OGCPUProfilerRecordOffMainGraphics;
#endif

    pthread_t profiler;
    if (pthread_create(&profiler, NULL, OGCPUProfilerThreadMain, NULL) == 0)
        pthread_detach(profiler);
}
