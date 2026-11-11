#ifndef OG_COMPAT_API_RTP_PARAMETERS_H
#define OG_COMPAT_API_RTP_PARAMETERS_H

#include <string>

namespace webrtc {

struct RtpExtension {
	static const char *kAbsSendTimeUri;
	static const char *kTransportSequenceNumberUri;
	static const char *kVideoRotationUri;

	std::string uri;
	int id = 0;

	RtpExtension() = default;

	RtpExtension(const std::string &uri_, int id_) : uri(uri_), id(id_) {
	}

	bool operator!=(const RtpExtension &other) const {
		return !(*this == other);
	}

	bool operator==(const RtpExtension &other) const {
		return id == other.id && uri == other.uri;
	}
};

} // namespace webrtc

#endif
