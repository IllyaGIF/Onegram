#ifndef OG_COMPAT_RTC_BASE_TIME_UTILS_H
#define OG_COMPAT_RTC_BASE_TIME_UTILS_H

#include <stdint.h>

namespace rtc {

static inline uint32_t HostToNetwork32(uint32_t host) {
	const uint32_t lowByte = (host & 0xffU) << 24;
	const uint32_t secondByte = (host & 0xff00U) << 8;
	const uint32_t thirdByte = (host >> 8) & 0xff00U;
	const uint32_t highByte = host >> 24;
	return lowByte | secondByte | thirdByte | highByte;
}

static inline uint32_t NetworkToHost32(uint32_t network) {
	return HostToNetwork32(network);
}

} // namespace rtc

#endif
