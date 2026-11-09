#ifndef TGCALLS_MEDIA_NACK_TRACKER_H
#define TGCALLS_MEDIA_NACK_TRACKER_H

#include <stdint.h>
#include <vector>

namespace tgcalls {

class NackTracker {
public:
    NackTracker();

    void reset();
    bool onPacket(uint16_t sequenceNumber, int64_t nowMicros);
    void collect(int64_t nowMicros, int64_t rttMicros, std::vector<uint16_t> &requests, std::vector<uint16_t> &abandoned);
    void dropOlderThan(uint16_t sequenceNumber);
    size_t pendingCount() const { return _entries.size(); }

private:
    struct Entry {
        uint16_t sequenceNumber;
        int64_t createdMicros;
        int64_t lastSentMicros;
        int retries;
    };

    std::vector<Entry> _entries;
    bool _started;
    uint16_t _highest;
};

}

#endif
