#ifndef TGCALLS_MEDIA_BANDWIDTH_ESTIMATOR_H
#define TGCALLS_MEDIA_BANDWIDTH_ESTIMATOR_H

#include "rtp/Rtcp.h"

#include <deque>
#include <pthread.h>
#include <stdint.h>
#include <vector>

namespace tgcalls {

class BandwidthEstimator {
public:
    struct Configuration {
        int minBitrate = 40000;
        int startBitrate = 300000;
        int maxBitrate = 1500000;
    };

    explicit BandwidthEstimator(const Configuration &configuration);
    ~BandwidthEstimator();

    void setMaxBitrate(int bitrate);
    void onPacketSent(uint16_t transportSequenceNumber, int64_t sendMicros, size_t size);
    void onTransportFeedback(const rtp::TransportFeedback &feedback, int64_t nowMicros);
    void onReceiverEstimate(uint64_t bitrate, int64_t nowMicros);
    void onRtt(int64_t rttMicros);
    void process(int64_t nowMicros);

    int targetBitrate();
    float lossRate();

private:
    enum Usage {
        UsageNormal,
        UsageOverusing,
        UsageUnderusing
    };

    struct SentPacket {
        bool valid;
        uint16_t sequenceNumber;
        int64_t sendMicros;
        uint32_t size;
    };

    struct PacketGroup {
        bool valid;
        int64_t firstSendMicros;
        int64_t lastSendMicros;
        int64_t lastArrivalMicros;
        int64_t firstArrivalMicros;
    };

    void onReceivedPacket(int64_t sendMicros, int64_t arrivalMicros, uint32_t size, int64_t nowMicros);
    void updateTrendline(double deltaMillis, int64_t arrivalMicros);
    void detectUsage(double trend, double deltaMillis, int64_t nowMicros);
    void applyUsage(int64_t nowMicros);
    void clamp();
    int64_t unwrapReference(int64_t referenceMicros);

    pthread_mutex_t _mutex;
    Configuration _configuration;
    std::vector<SentPacket> _history;

    bool _hasReference;
    int32_t _lastReferenceTicks;
    int64_t _unwrappedReferenceTicks;

    PacketGroup _current;
    PacketGroup _previous;

    std::deque<std::pair<double, double> > _delayHistory;
    double _accumulatedDelay;
    double _smoothedDelay;
    int _numDeltas;
    double _firstArrivalMillis;
    bool _hasFirstArrival;
    double _threshold;
    int64_t _lastThresholdUpdateMicros;
    double _previousTrend;
    double _timeOverUsingMillis;
    int _overuseCounter;
    Usage _usage;

    double _target;
    double _rembLimit;
    int64_t _rttMicros;
    int64_t _lastIncreaseMicros;
    int64_t _lastDecreaseMicros;

    std::deque<std::pair<int64_t, uint32_t> > _ackedWindow;
    uint64_t _ackedBytes;
    std::deque<std::pair<int64_t, bool> > _lossWindow;
    uint32_t _lossLost;
    float _lossRate;
};

}

#endif
