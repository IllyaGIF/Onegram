#ifndef OG_COMPAT_API_CANDIDATE_H
#define OG_COMPAT_API_CANDIDATE_H

#include <string>

namespace cricket {

class Candidate {
	std::string _sdp;

public:
	Candidate() = default;

	void FromString(const std::string &sdp) {
		_sdp = sdp;
	}

	std::string ToString() const {
		return _sdp;
	}
};

} // namespace cricket

#endif
