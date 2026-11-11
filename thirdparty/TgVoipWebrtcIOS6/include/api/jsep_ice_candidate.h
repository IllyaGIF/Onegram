#ifndef OG_COMPAT_API_JSEP_ICE_CANDIDATE_H
#define OG_COMPAT_API_JSEP_ICE_CANDIDATE_H

#include "api/candidate.h"

namespace webrtc {

class JsepIceCandidate {
	cricket::Candidate _candidate;

public:
	JsepIceCandidate(const std::string &, int) {
	}

	const cricket::Candidate &candidate() const {
		return _candidate;
	}

	void SetCandidate(const cricket::Candidate &source) {
		_candidate = source;
	}

	bool Initialize(const std::string &sdp, void *) {
		_candidate.FromString(sdp);
		return true;
	}

	bool ToString(std::string *out) const {
		if (out != nullptr) {
			*out = _candidate.ToString();
		}
		return true;
	}
};

} // namespace webrtc

#endif
