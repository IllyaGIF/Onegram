#include "tgcalls/TGIOS6CxxCompat.h"
#include <assert.h>
#include <limits>
#include "rtc_base/logging.h"
#include "rtc_base/third_party/sigslot/sigslot.h"

struct OGCompatInert {
    virtual ~OGCompatInert() = default;
};

namespace webrtc {
struct TimeDelta {
    static TimeDelta Millis(int64_t value) { return TimeDelta(value); }
    int64_t ms() const { return _milliseconds; }

private:
    explicit TimeDelta(int64_t value) : _milliseconds(value) { }
    int64_t _milliseconds;
};

class TurnCustomizer : public OGCompatInert {
};
}

namespace rtc {
class BasicPacketSocketFactory : public OGCompatInert {
};

class BasicNetworkManager : public OGCompatInert {
};
}

namespace cricket {
class RelayPortFactoryInterface : public OGCompatInert {
};

class BasicPortAllocator : public OGCompatInert {
};

class P2PTransportChannel : public OGCompatInert {
};
}
