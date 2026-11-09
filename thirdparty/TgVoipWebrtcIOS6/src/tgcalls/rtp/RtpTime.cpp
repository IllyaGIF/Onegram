#include "rtp/RtpTime.h"

#include <mach/mach_time.h>
#include <pthread.h>
#include <sys/time.h>

namespace tgcalls {
namespace rtp {

namespace {

pthread_once_t timebaseOnce = PTHREAD_ONCE_INIT;
uint32_t timebaseNumer = 1;
uint32_t timebaseDenom = 1;

void InitializeTimebase() {
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) == KERN_SUCCESS && info.denom != 0) {
        timebaseNumer = info.numer;
        timebaseDenom = info.denom;
    }
}

const uint64_t kNtpEpochOffsetSeconds = 2208988800ULL;

}

int64_t MonotonicMicros() {
    pthread_once(&timebaseOnce, &InitializeTimebase);
    const uint64_t ticks = mach_absolute_time();
    const uint64_t denom = (uint64_t)timebaseDenom * 1000ULL;
    const uint64_t whole = ticks / denom;
    const uint64_t rest = ticks % denom;
    return (int64_t)(whole * timebaseNumer + (rest * timebaseNumer) / denom);
}

uint64_t NtpNow() {
    struct timeval now;
    gettimeofday(&now, 0);
    const uint64_t seconds = (uint64_t)now.tv_sec + kNtpEpochOffsetSeconds;
    const uint64_t fraction = ((uint64_t)now.tv_usec << 32) / 1000000ULL;
    return (seconds << 32) | (fraction & 0xFFFFFFFFULL);
}

int64_t CompactNtpToMicros(uint32_t compact) {
    return (int64_t)(((uint64_t)compact * 1000000ULL) >> 16);
}

}
}
