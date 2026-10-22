#include "tgcalls/TGIOS6CxxCompat.h"
#include <assert.h>
#include <limits>
#include "rtc_base/logging.h"
#include "rtc_base/third_party/sigslot/sigslot.h"

namespace webrtc {
class TimeDelta {
public:
    static TimeDelta Millis(int64_t value) { return TimeDelta(value); }
    int64_t ms() const { return _milliseconds; }
private:
    explicit TimeDelta(int64_t value) : _milliseconds(value) { }
    int64_t _milliseconds;
};

class TurnCustomizer {
public:
	virtual ~TurnCustomizer() {
	}
};
}

namespace rtc {
class BasicPacketSocketFactory {
public:
	virtual ~BasicPacketSocketFactory() {
	}
};

class BasicNetworkManager {
public:
	virtual ~BasicNetworkManager() {
	}
};
}

namespace cricket {
class RelayPortFactoryInterface {
public:
	virtual ~RelayPortFactoryInterface() {
	}
};

class BasicPortAllocator {
public:
	virtual ~BasicPortAllocator() {
	}
};

class P2PTransportChannel {
public:
	virtual ~P2PTransportChannel() {
	}
};
}
