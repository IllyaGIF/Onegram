#ifndef OG_COMPAT_API_TRANSPORT_FIELD_TRIAL_BASED_CONFIG_H
#define OG_COMPAT_API_TRANSPORT_FIELD_TRIAL_BASED_CONFIG_H

namespace webrtc {

struct FieldTrialsView {
	virtual ~FieldTrialsView() = default;
};

struct FieldTrialBasedConfig : FieldTrialsView {
};

} // namespace webrtc

#endif
