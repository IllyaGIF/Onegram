#ifndef OG_COMPAT_RTC_BASE_LOGGING_H
#define OG_COMPAT_RTC_BASE_LOGGING_H

#include "rtc_base/checks.h"

namespace rtc {

enum LoggingSeverity {
	LS_VERBOSE = 0,
	LS_INFO = 1,
	LS_WARNING = 2,
	LS_ERROR = 3
};

struct LogSink {
	virtual ~LogSink() = default;
	virtual void OnLogMessage(const std::string &message) {
	}
	virtual void OnLogMessage(const std::string &message, LoggingSeverity severity) {
	}
	virtual void OnLogMessage(const std::string &message, LoggingSeverity severity, const char *tag) {
	}
};

struct LogMessage {
	static void AddLogToStream(LogSink *sink, LoggingSeverity minimum) {
	}
	static void RemoveLogToStream(LogSink *sink) {
	}
	static void SetLogToStderr(bool enabled) {
	}
	static void LogToDebug(LoggingSeverity minimum) {
	}
};

} // namespace rtc

static const rtc::LoggingSeverity LS_INFO = rtc::LS_INFO;
static const rtc::LoggingSeverity LS_ERROR = rtc::LS_ERROR;
#define RTC_LOG(severity) og_compat_rtc::LogSink()

#endif
