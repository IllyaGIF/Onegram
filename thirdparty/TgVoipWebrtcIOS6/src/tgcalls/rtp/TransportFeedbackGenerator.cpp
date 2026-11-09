#include "rtp/TransportFeedbackGenerator.h"

#include "rtp/Rtcp.h"

namespace tgcalls {
namespace rtp {

namespace {

const size_t kMaxPending = 4096;
const size_t kMaxFeedbackSize = 1100;

}

TransportFeedbackGenerator::TransportFeedbackGenerator() :
_hasLast(false),
_last(0),
_hasNextToReport(false),
_nextToReport(0),
_feedbackCount(0) {
    pthread_mutex_init(&_mutex, 0);
}

TransportFeedbackGenerator::~TransportFeedbackGenerator() {
    pthread_mutex_destroy(&_mutex);
}

int64_t TransportFeedbackGenerator::unwrap(uint16_t value) {
    if (!_hasLast) {
        _hasLast = true;
        _last = value;
        return _last;
    }
    const int16_t delta = (int16_t)(value - (uint16_t)_last);
    const int64_t unwrapped = _last + delta;
    if (delta > 0) {
        _last = unwrapped;
    }
    return unwrapped;
}

void TransportFeedbackGenerator::onPacket(uint16_t transportSequenceNumber, int64_t arrivalMicros) {
    pthread_mutex_lock(&_mutex);
    const int64_t sequence = unwrap(transportSequenceNumber);
    if (!_hasNextToReport || sequence >= _nextToReport) {
        if (_arrivals.size() >= kMaxPending) {
            _arrivals.erase(_arrivals.begin());
        }
        _arrivals[sequence] = arrivalMicros;
    }
    pthread_mutex_unlock(&_mutex);
}

bool TransportFeedbackGenerator::hasPending() {
    pthread_mutex_lock(&_mutex);
    const bool result = !_arrivals.empty();
    pthread_mutex_unlock(&_mutex);
    return result;
}

MediaPacketRef TransportFeedbackGenerator::buildPacket(uint32_t senderSsrc, uint32_t mediaSsrc) {
    pthread_mutex_lock(&_mutex);
    if (_arrivals.empty()) {
        pthread_mutex_unlock(&_mutex);
        return MediaPacketRef();
    }
    TransportFeedbackBuilder builder;
    builder.reset(_feedbackCount);
    std::map<int64_t, int64_t>::iterator it = _arrivals.begin();
    int64_t lastIncluded = 0;
    bool included = false;
    while (it != _arrivals.end()) {
        if (builder.estimatedSize() + 4 > kMaxFeedbackSize) {
            break;
        }
        if (!builder.addReceivedPacket((uint16_t)it->first, it->second)) {
            break;
        }
        lastIncluded = it->first;
        included = true;
        ++it;
    }
    if (!included) {
        _arrivals.erase(_arrivals.begin());
        pthread_mutex_unlock(&_mutex);
        return MediaPacketRef();
    }
    _arrivals.erase(_arrivals.begin(), it);
    _nextToReport = lastIncluded + 1;
    _hasNextToReport = true;
    ++_feedbackCount;
    pthread_mutex_unlock(&_mutex);

    MediaPacketRef packet = AllocateMediaPacket();
    RtcpWriter writer(packet->data(), packet->capacity() - MediaPacket::kTailroom);
    if (!writer.addTransportFeedback(senderSsrc, mediaSsrc, builder)) {
        return MediaPacketRef();
    }
    packet->setSize(writer.size());
    packet->kind = MediaPacketRtcp;
    packet->ssrc = senderSsrc;
    return packet;
}

}
}
