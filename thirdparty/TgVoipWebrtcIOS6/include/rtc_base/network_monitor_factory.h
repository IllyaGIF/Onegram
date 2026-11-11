#ifndef OG_COMPAT_RTC_BASE_NETWORK_MONITOR_FACTORY_H
#define OG_COMPAT_RTC_BASE_NETWORK_MONITOR_FACTORY_H

namespace rtc {

struct NetworkMonitorFactory {
	virtual ~NetworkMonitorFactory() = default;
};

struct NetworkRoute {
	bool connected = false;
};

} // namespace rtc

#endif
