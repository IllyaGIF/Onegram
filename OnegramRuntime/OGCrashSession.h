#ifndef OGCrashSession_h
#define OGCrashSession_h

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stddef.h>

#define OG_CRASH_SESSION_SIGNATURE UINT32_C(0x4f474353)
#define OG_CRASH_SESSION_HISTORY_CAPACITY 16

typedef struct {
    uint64_t sampledAt;
    uint64_t residentBytes;
    uint64_t heapBytes;
    uint64_t systemFreeBytes;
    char screen[48];
} OGCrashSessionSample;

typedef struct {
    uint32_t signature;
    uint32_t memoryWarnings;
    uint64_t startedAt;
    uint64_t lastActiveAt;
    uint64_t lastWarningAt;
    uint64_t residentBytes;
    char appVersion[64];
    char appBuild[64];
    char architecture[16];
    char systemVersion[32];
    char machine[32];
    uint64_t sampledAt;
    uint64_t virtualBytes;
    uint64_t peakResidentBytes;
    uint64_t mainThreadDelayMilliseconds;
    uint64_t maximumMainThreadDelayMilliseconds;
    uint64_t sampleCount;
    uint64_t processId;
    int32_t memorySampleResult;
    char executableUUID[37];
    char systemBuild[64];
    char visibleController[128];
    char lifecycle[32];
    uint64_t heapBytes;
    uint64_t peakHeapBytes;
    uint64_t physicalMemoryBytes;
    uint64_t systemFreeBytes;
    uint64_t systemInactiveBytes;
    uint64_t systemWiredBytes;
    int32_t systemSampleResult;
    uint32_t historyCount;
    uint32_t historyNext;
    OGCrashSessionSample history[OG_CRASH_SESSION_HISTORY_CAPACITY];
} OGCrashSessionRecord;

static inline bool OGCrashSessionHistoryValid(const OGCrashSessionRecord *record)
{
    if (record->historyCount > OG_CRASH_SESSION_HISTORY_CAPACITY || record->historyNext >= OG_CRASH_SESSION_HISTORY_CAPACITY)
        return false;
    for (uint32_t index = 0; index < OG_CRASH_SESSION_HISTORY_CAPACITY; index++)
    {
        if (memchr(record->history[index].screen, 0, sizeof(record->history[index].screen)) == NULL)
            return false;
    }
    return true;
}

static inline bool OGCrashSessionWrite(const char *path, const OGCrashSessionRecord *record)
{
    int fd = open(path, O_WRONLY | O_CREAT, 0600);
    if (fd < 0)
        return false;
    const unsigned char *bytes = (const unsigned char *)record;
    size_t remaining = sizeof(*record);
    bool success = true;
    while (remaining != 0)
    {
        ssize_t count = write(fd, bytes, remaining);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
        {
            success = false;
            break;
        }
        bytes += count;
        remaining -= count;
    }
    if (success)
        success = ftruncate(fd, sizeof(*record)) == 0 && fsync(fd) == 0;
    close(fd);
    return success;
}

static inline bool OGCrashSessionRead(const char *path, OGCrashSessionRecord *record)
{
    memset(record, 0, sizeof(*record));
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return false;
    unsigned char *bytes = (unsigned char *)record;
    size_t remaining = sizeof(*record);
    while (remaining != 0)
    {
        ssize_t count = read(fd, bytes, remaining);
        if (count < 0 && errno == EINTR)
            continue;
        if (count <= 0)
            break;
        bytes += count;
        remaining -= count;
    }
    unsigned char extra;
    ssize_t trailing;
    do {
        trailing = read(fd, &extra, 1);
    } while (trailing < 0 && errno == EINTR);
    close(fd);
    size_t bytesRead = sizeof(*record) - remaining;
    bool complete = bytesRead == sizeof(*record) && OGCrashSessionHistoryValid(record);
    bool previousLayout = bytesRead == offsetof(OGCrashSessionRecord, sampledAt) || bytesRead == offsetof(OGCrashSessionRecord, heapBytes);
    return (complete || previousLayout) && trailing == 0 && record->signature == OG_CRASH_SESSION_SIGNATURE &&
        record->startedAt != 0 && record->lastActiveAt != 0 &&
        memchr(record->appVersion, 0, sizeof(record->appVersion)) != NULL &&
        memchr(record->appBuild, 0, sizeof(record->appBuild)) != NULL &&
        memchr(record->architecture, 0, sizeof(record->architecture)) != NULL &&
        memchr(record->systemVersion, 0, sizeof(record->systemVersion)) != NULL &&
        memchr(record->machine, 0, sizeof(record->machine)) != NULL &&
        memchr(record->executableUUID, 0, sizeof(record->executableUUID)) != NULL &&
        memchr(record->systemBuild, 0, sizeof(record->systemBuild)) != NULL &&
        memchr(record->visibleController, 0, sizeof(record->visibleController)) != NULL &&
        memchr(record->lifecycle, 0, sizeof(record->lifecycle)) != NULL;
}

#endif
