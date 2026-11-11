#ifndef OG_COMPAT_RTC_BASE_CHECKS_H
#define OG_COMPAT_RTC_BASE_CHECKS_H

#include <sstream>

namespace og_compat_rtc {

struct LogSink {
	template <class Anything>
	LogSink &operator<<(const Anything &) {
		return *this;
	}
};

} // namespace og_compat_rtc

#define RTC_FATAL() og_compat_rtc::LogSink()

#endif
