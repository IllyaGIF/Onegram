#ifndef OG_COMPAT_RTC_BASE_SSL_FINGERPRINT_H
#define OG_COMPAT_RTC_BASE_SSL_FINGERPRINT_H

#include <memory>
#include <string>

namespace rtc {

struct SSLFingerprint {
	std::string algorithm;
	std::string digest;

	SSLFingerprint() = default;

	explicit SSLFingerprint(const std::string &algorithmName) : algorithm(algorithmName) {
	}
};

} // namespace rtc

#endif
