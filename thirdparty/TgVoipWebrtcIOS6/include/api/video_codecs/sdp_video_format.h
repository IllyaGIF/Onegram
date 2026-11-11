#ifndef OG_COMPAT_API_VIDEO_CODECS_SDP_VIDEO_FORMAT_H
#define OG_COMPAT_API_VIDEO_CODECS_SDP_VIDEO_FORMAT_H

#include <map>
#include <string>

namespace webrtc {

struct SdpVideoFormat {
	std::map<std::string, std::string> parameters;
	std::string name;

	SdpVideoFormat() = default;

	explicit SdpVideoFormat(const std::string &codecName) : name(codecName) {
	}
};

} // namespace webrtc

#endif
