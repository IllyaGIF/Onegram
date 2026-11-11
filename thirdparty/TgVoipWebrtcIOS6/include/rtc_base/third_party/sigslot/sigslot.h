#ifndef OG_COMPAT_RTC_BASE_THIRD_PARTY_SIGSLOT_SIGSLOT_H
#define OG_COMPAT_RTC_BASE_THIRD_PARTY_SIGSLOT_SIGSLOT_H

namespace sigslot {

template <class mt_policy = void>
struct has_slots {
	virtual ~has_slots() = default;
};

} // namespace sigslot

#endif
