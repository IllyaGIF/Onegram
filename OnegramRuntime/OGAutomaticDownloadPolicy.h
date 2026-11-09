#ifndef OGAutomaticDownloadPolicy_h
#define OGAutomaticDownloadPolicy_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    int64_t estimatedSize;
    double retryAt;
    bool highPriority;
    bool latencySensitive;
} OGAutomaticDownloadCandidate;

static inline size_t OGAutomaticDownloadSelect(const OGAutomaticDownloadCandidate *candidates, size_t count, size_t activeCount, int64_t activeBytes, int64_t activeLatencyBytes, int64_t byteBudget, double now)
{
    int64_t availableBytes = activeBytes < byteBudget ? byteBudget - activeBytes : 0;
    int64_t latencyBudget = byteBudget / 4;
    int64_t availableLatencyBytes = activeLatencyBytes < latencyBudget ? latencyBudget - activeLatencyBytes : 0;
    int highestPriority = -1;
    for (size_t index = 0; index < count; index++)
    {
        OGAutomaticDownloadCandidate candidate = candidates[index];
        int priority = (candidate.highPriority ? 2 : 0) + (candidate.latencySensitive ? 1 : 0);
        if (candidate.retryAt <= now && priority > highestPriority)
            highestPriority = priority;
    }
    for (size_t index = 0; index < count; index++)
    {
        OGAutomaticDownloadCandidate candidate = candidates[index];
        int priority = (candidate.highPriority ? 2 : 0) + (candidate.latencySensitive ? 1 : 0);
        bool reserved = candidate.highPriority && candidate.latencySensitive && candidate.estimatedSize <= availableLatencyBytes;
        if (candidate.retryAt > now || priority < highestPriority ||
            (activeCount != 0 && candidate.estimatedSize > availableBytes && !reserved))
            continue;
        return index;
    }
    return SIZE_MAX;
}

static inline double OGAutomaticDownloadRetryDelay(unsigned int retryCount)
{
    return retryCount < 3 ? (double)(1u << retryCount) : 0.0;
}

static inline bool OGAutomaticDownloadCanPreempt(bool highPriority, double startedAt, double now, float progress)
{
    return !highPriority && now - startedAt >= 1.0 && progress < 0.9f;
}

#endif
