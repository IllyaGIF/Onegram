#ifndef TGCALLS_RTP_TIME_H
#define TGCALLS_RTP_TIME_H

#include <stdint.h>

namespace tgcalls {
namespace rtp {

int64_t MonotonicMicros();

inline int64_t MonotonicMillis() {
    return MonotonicMicros() / 1000;
}

uint64_t NtpNow();

inline uint32_t NtpCompact(uint64_t ntp) {
    return (uint32_t)(ntp >> 16);
}

int64_t CompactNtpToMicros(uint32_t compact);

}
}

#endif
