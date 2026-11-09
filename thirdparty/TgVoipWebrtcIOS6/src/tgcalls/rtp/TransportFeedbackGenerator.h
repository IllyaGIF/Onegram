#ifndef TGCALLS_RTP_TRANSPORT_FEEDBACK_GENERATOR_H
#define TGCALLS_RTP_TRANSPORT_FEEDBACK_GENERATOR_H

#include "rtp/MediaPacket.h"

#include <map>
#include <pthread.h>
#include <stdint.h>

namespace tgcalls {
namespace rtp {

class TransportFeedbackGenerator {
public:
    TransportFeedbackGenerator();
    ~TransportFeedbackGenerator();

    void onPacket(uint16_t transportSequenceNumber, int64_t arrivalMicros);
    MediaPacketRef buildPacket(uint32_t senderSsrc, uint32_t mediaSsrc);
    bool hasPending();

private:
    int64_t unwrap(uint16_t value);

    pthread_mutex_t _mutex;
    std::map<int64_t, int64_t> _arrivals;
    bool _hasLast;
    int64_t _last;
    bool _hasNextToReport;
    int64_t _nextToReport;
    uint8_t _feedbackCount;
};

}
}

#endif
