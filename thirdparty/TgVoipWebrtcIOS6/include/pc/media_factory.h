#ifndef OG_COMPAT_PC_MEDIA_FACTORY_H
#define OG_COMPAT_PC_MEDIA_FACTORY_H

#include <memory>

namespace webrtc {

struct MediaFactory {
	virtual ~MediaFactory() = default;
};

} // namespace webrtc

#endif
