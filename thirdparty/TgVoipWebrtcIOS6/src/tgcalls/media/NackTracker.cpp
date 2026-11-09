#include "media/NackTracker.h"

#include "rtp/RtpByteIO.h"

namespace tgcalls {

namespace {

const uint16_t kMaxGap = 500;
const int kMaxRetries = 10;
const int64_t kMaxAgeMicros = 1500000;
const int64_t kMinResendMicros = 20000;
const int64_t kDefaultRttMicros = 100000;
const size_t kMaxRequestsPerCollect = 256;

}

NackTracker::NackTracker() :
_started(false),
_highest(0) {
}

void NackTracker::reset() {
    _entries.clear();
    _started = false;
    _highest = 0;
}

bool NackTracker::onPacket(uint16_t sequenceNumber, int64_t nowMicros) {
    if (!_started) {
        _started = true;
        _highest = sequenceNumber;
        return true;
    }
    if (rtp::IsNewerSequence(sequenceNumber, _highest)) {
        const uint16_t gap = (uint16_t)(sequenceNumber - _highest - 1);
        if (gap > kMaxGap) {
            _entries.clear();
            _highest = sequenceNumber;
            return false;
        }
        for (uint16_t i = 1; i <= gap; ++i) {
            Entry entry;
            entry.sequenceNumber = (uint16_t)(_highest + i);
            entry.createdMicros = nowMicros;
            entry.lastSentMicros = 0;
            entry.retries = 0;
            _entries.push_back(entry);
        }
        _highest = sequenceNumber;
        return true;
    }
    for (size_t i = 0; i < _entries.size(); ++i) {
        if (_entries[i].sequenceNumber == sequenceNumber) {
            _entries.erase(_entries.begin() + i);
            break;
        }
    }
    return true;
}

void NackTracker::collect(int64_t nowMicros, int64_t rttMicros, std::vector<uint16_t> &requests, std::vector<uint16_t> &abandoned) {
    const int64_t rtt = rttMicros > 0 ? rttMicros : kDefaultRttMicros;
    int64_t resendInterval = rtt + rtt / 8;
    if (resendInterval < kMinResendMicros) {
        resendInterval = kMinResendMicros;
    }
    size_t write = 0;
    for (size_t i = 0; i < _entries.size(); ++i) {
        Entry entry = _entries[i];
        if (entry.retries >= kMaxRetries || nowMicros - entry.createdMicros > kMaxAgeMicros) {
            abandoned.push_back(entry.sequenceNumber);
            continue;
        }
        if ((entry.lastSentMicros == 0 || nowMicros - entry.lastSentMicros >= resendInterval) && requests.size() < kMaxRequestsPerCollect) {
            requests.push_back(entry.sequenceNumber);
            entry.lastSentMicros = nowMicros;
            ++entry.retries;
        }
        _entries[write++] = entry;
    }
    _entries.resize(write);
}

void NackTracker::dropOlderThan(uint16_t sequenceNumber) {
    size_t write = 0;
    for (size_t i = 0; i < _entries.size(); ++i) {
        if (!rtp::IsNewerSequence(sequenceNumber, _entries[i].sequenceNumber)) {
            _entries[write++] = _entries[i];
        }
    }
    _entries.resize(write);
}

}
