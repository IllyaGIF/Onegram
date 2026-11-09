#include "media/BandwidthEstimator.h"

#include <math.h>

namespace tgcalls {

namespace {

const size_t kHistorySize = 4096;
const int64_t kBurstMicros = 5000;
const size_t kTrendlineWindow = 20;
const double kSmoothing = 0.9;
const double kThresholdGain = 4.0;
const double kUpGain = 0.0087;
const double kDownGain = 0.039;
const double kOveruseTimeMillis = 10.0;
const int64_t kAckedWindowMicros = 500000;
const int64_t kLossWindowMicros = 1000000;
const int64_t kReferenceWrap = 1 << 24;

class Lock {
public:
    explicit Lock(pthread_mutex_t *mutex) : _mutex(mutex) { pthread_mutex_lock(_mutex); }
    ~Lock() { pthread_mutex_unlock(_mutex); }

private:
    pthread_mutex_t *_mutex;
};

}

BandwidthEstimator::BandwidthEstimator(const Configuration &configuration) :
_configuration(configuration),
_history(kHistorySize),
_hasReference(false),
_lastReferenceTicks(0),
_unwrappedReferenceTicks(0),
_accumulatedDelay(0.0),
_smoothedDelay(0.0),
_numDeltas(0),
_firstArrivalMillis(0.0),
_hasFirstArrival(false),
_threshold(12.5),
_lastThresholdUpdateMicros(0),
_previousTrend(0.0),
_timeOverUsingMillis(-1.0),
_overuseCounter(0),
_usage(UsageNormal),
_target(configuration.startBitrate),
_rembLimit(0.0),
_rttMicros(200000),
_lastIncreaseMicros(0),
_lastDecreaseMicros(0),
_ackedBytes(0),
_lossLost(0),
_lossRate(0.0f) {
    pthread_mutex_init(&_mutex, 0);
    _current.valid = false;
    _previous.valid = false;
    for (size_t i = 0; i < _history.size(); ++i) {
        _history[i].valid = false;
    }
}

BandwidthEstimator::~BandwidthEstimator() {
    pthread_mutex_destroy(&_mutex);
}

void BandwidthEstimator::setMaxBitrate(int bitrate) {
    Lock lock(&_mutex);
    _configuration.maxBitrate = bitrate < _configuration.minBitrate ? _configuration.minBitrate : bitrate;
    clamp();
}

void BandwidthEstimator::onPacketSent(uint16_t transportSequenceNumber, int64_t sendMicros, size_t size) {
    Lock lock(&_mutex);
    SentPacket &packet = _history[transportSequenceNumber & (kHistorySize - 1)];
    packet.valid = true;
    packet.sequenceNumber = transportSequenceNumber;
    packet.sendMicros = sendMicros;
    packet.size = (uint32_t)size;
}

void BandwidthEstimator::onReceiverEstimate(uint64_t bitrate, int64_t) {
    Lock lock(&_mutex);
    _rembLimit = (double)bitrate;
    clamp();
}

void BandwidthEstimator::onRtt(int64_t rttMicros) {
    Lock lock(&_mutex);
    if (rttMicros > 0) {
        _rttMicros = rttMicros;
    }
}

int64_t BandwidthEstimator::unwrapReference(int64_t referenceMicros) {
    const int32_t ticks = (int32_t)(referenceMicros / rtp::TransportFeedback::kReferenceTickMicros);
    if (!_hasReference) {
        _hasReference = true;
        _lastReferenceTicks = ticks;
        _unwrappedReferenceTicks = ticks;
    } else {
        int64_t delta = ((int64_t)ticks - (int64_t)_lastReferenceTicks) % kReferenceWrap;
        if (delta < 0) {
            delta += kReferenceWrap;
        }
        if (delta >= kReferenceWrap / 2) {
            delta -= kReferenceWrap;
        }
        _unwrappedReferenceTicks += delta;
        _lastReferenceTicks = ticks;
    }
    return _unwrappedReferenceTicks * rtp::TransportFeedback::kReferenceTickMicros;
}

void BandwidthEstimator::onTransportFeedback(const rtp::TransportFeedback &feedback, int64_t nowMicros) {
    Lock lock(&_mutex);
    const int64_t reference = unwrapReference(feedback.referenceMicros());
    const std::vector<rtp::TransportFeedback::PacketStatus> &packets = feedback.packets();
    for (size_t i = 0; i < packets.size(); ++i) {
        const rtp::TransportFeedback::PacketStatus &status = packets[i];
        SentPacket &sent = _history[status.sequenceNumber & (kHistorySize - 1)];
        if (!sent.valid || sent.sequenceNumber != status.sequenceNumber) {
            continue;
        }
        _lossWindow.push_back(std::make_pair(nowMicros, !status.received));
        if (!status.received) {
            ++_lossLost;
            continue;
        }
        sent.valid = false;
        const int64_t arrival = reference + (status.arrivalMicros - feedback.referenceMicros());
        onReceivedPacket(sent.sendMicros, arrival, sent.size, nowMicros);
    }
    while (!_lossWindow.empty() && nowMicros - _lossWindow.front().first > kLossWindowMicros) {
        if (_lossWindow.front().second) {
            --_lossLost;
        }
        _lossWindow.pop_front();
    }
    if (_lossWindow.size() >= 20) {
        _lossRate = (float)_lossLost / (float)_lossWindow.size();
        if (_lossRate > 0.10f && nowMicros - _lastDecreaseMicros > _rttMicros + 100000) {
            _target *= 1.0 - 0.5 * (double)_lossRate;
            _lastDecreaseMicros = nowMicros;
        }
    }
    applyUsage(nowMicros);
    clamp();
}

void BandwidthEstimator::onReceivedPacket(int64_t sendMicros, int64_t arrivalMicros, uint32_t size, int64_t nowMicros) {
    _ackedWindow.push_back(std::make_pair(arrivalMicros, size));
    _ackedBytes += size;
    while (!_ackedWindow.empty() && arrivalMicros - _ackedWindow.front().first > kAckedWindowMicros) {
        _ackedBytes -= _ackedWindow.front().second;
        _ackedWindow.pop_front();
    }
    if (!_current.valid) {
        _current.valid = true;
        _current.firstSendMicros = sendMicros;
        _current.lastSendMicros = sendMicros;
        _current.firstArrivalMicros = arrivalMicros;
        _current.lastArrivalMicros = arrivalMicros;
        return;
    }
    if (sendMicros < _current.firstSendMicros) {
        return;
    }
    if (sendMicros - _current.firstSendMicros <= kBurstMicros) {
        if (sendMicros > _current.lastSendMicros) {
            _current.lastSendMicros = sendMicros;
        }
        if (arrivalMicros > _current.lastArrivalMicros) {
            _current.lastArrivalMicros = arrivalMicros;
        }
        return;
    }
    if (_previous.valid) {
        const double sendDelta = (double)(_current.lastSendMicros - _previous.lastSendMicros) / 1000.0;
        const double arrivalDelta = (double)(_current.lastArrivalMicros - _previous.lastArrivalMicros) / 1000.0;
        const double delta = arrivalDelta - sendDelta;
        if (fabs(delta) < 1000.0) {
            updateTrendline(delta, _current.lastArrivalMicros);
            const double trend = _delayHistory.size() >= kTrendlineWindow ? _previousTrend : 0.0;
            detectUsage(trend, sendDelta, nowMicros);
        }
    }
    _previous = _current;
    _current.firstSendMicros = sendMicros;
    _current.lastSendMicros = sendMicros;
    _current.firstArrivalMicros = arrivalMicros;
    _current.lastArrivalMicros = arrivalMicros;
}

void BandwidthEstimator::updateTrendline(double deltaMillis, int64_t arrivalMicros) {
    const double arrivalMillis = (double)arrivalMicros / 1000.0;
    if (!_hasFirstArrival) {
        _hasFirstArrival = true;
        _firstArrivalMillis = arrivalMillis;
    }
    ++_numDeltas;
    if (_numDeltas > 1000) {
        _numDeltas = 1000;
    }
    _accumulatedDelay += deltaMillis;
    _smoothedDelay = kSmoothing * _smoothedDelay + (1.0 - kSmoothing) * _accumulatedDelay;
    _delayHistory.push_back(std::make_pair(arrivalMillis - _firstArrivalMillis, _smoothedDelay));
    if (_delayHistory.size() > kTrendlineWindow) {
        _delayHistory.pop_front();
    }
    if (_delayHistory.size() < kTrendlineWindow) {
        return;
    }
    double sumX = 0.0;
    double sumY = 0.0;
    for (size_t i = 0; i < _delayHistory.size(); ++i) {
        sumX += _delayHistory[i].first;
        sumY += _delayHistory[i].second;
    }
    const double meanX = sumX / (double)_delayHistory.size();
    const double meanY = sumY / (double)_delayHistory.size();
    double numerator = 0.0;
    double denominator = 0.0;
    for (size_t i = 0; i < _delayHistory.size(); ++i) {
        const double x = _delayHistory[i].first - meanX;
        numerator += x * (_delayHistory[i].second - meanY);
        denominator += x * x;
    }
    if (denominator != 0.0) {
        const double slope = numerator / denominator;
        const int deltas = _numDeltas < 60 ? _numDeltas : 60;
        _previousTrend = slope * (double)deltas * kThresholdGain;
    }
}

void BandwidthEstimator::detectUsage(double trend, double deltaMillis, int64_t nowMicros) {
    if (trend > _threshold) {
        if (_timeOverUsingMillis < 0.0) {
            _timeOverUsingMillis = deltaMillis / 2.0;
        } else {
            _timeOverUsingMillis += deltaMillis;
        }
        ++_overuseCounter;
        if (_timeOverUsingMillis > kOveruseTimeMillis && _overuseCounter > 1) {
            _timeOverUsingMillis = 0.0;
            _overuseCounter = 0;
            _usage = UsageOverusing;
        }
    } else if (trend < -_threshold) {
        _timeOverUsingMillis = -1.0;
        _overuseCounter = 0;
        _usage = UsageUnderusing;
    } else {
        _timeOverUsingMillis = -1.0;
        _overuseCounter = 0;
        _usage = UsageNormal;
    }
    if (_lastThresholdUpdateMicros == 0) {
        _lastThresholdUpdateMicros = nowMicros;
    }
    const double magnitude = fabs(trend);
    if (magnitude <= _threshold + 15.0) {
        const double gain = magnitude < _threshold ? kDownGain : kUpGain;
        double elapsed = (double)(nowMicros - _lastThresholdUpdateMicros) / 1000.0;
        if (elapsed > 100.0) {
            elapsed = 100.0;
        }
        _threshold += gain * (magnitude - _threshold) * elapsed;
        if (_threshold < 6.0) {
            _threshold = 6.0;
        } else if (_threshold > 600.0) {
            _threshold = 600.0;
        }
    }
    _lastThresholdUpdateMicros = nowMicros;
}

void BandwidthEstimator::applyUsage(int64_t nowMicros) {
    if (_usage == UsageOverusing) {
        const double acked = _ackedWindow.size() >= 2 ? (double)_ackedBytes * 8.0 * 1000000.0 / (double)kAckedWindowMicros : 0.0;
        if (nowMicros - _lastDecreaseMicros > _rttMicros) {
            const double basis = acked > 0.0 ? acked : _target;
            const double decreased = 0.85 * basis;
            if (decreased < _target) {
                _target = decreased;
            }
            _lastDecreaseMicros = nowMicros;
        }
        _usage = UsageNormal;
    }
}

void BandwidthEstimator::process(int64_t nowMicros) {
    Lock lock(&_mutex);
    if (_lastIncreaseMicros == 0) {
        _lastIncreaseMicros = nowMicros;
        return;
    }
    const double elapsed = (double)(nowMicros - _lastIncreaseMicros) / 1000000.0;
    _lastIncreaseMicros = nowMicros;
    if (_usage == UsageUnderusing || nowMicros - _lastDecreaseMicros < _rttMicros + 200000 || _lossRate > 0.05f) {
        return;
    }
    const double acked = _ackedWindow.size() >= 2 ? (double)_ackedBytes * 8.0 * 1000000.0 / (double)kAckedWindowMicros : 0.0;
    double increased = _target * pow(1.08, elapsed > 1.0 ? 1.0 : elapsed);
    if (acked > 0.0) {
        const double ceiling = acked * 1.5 + 10000.0;
        if (increased > ceiling) {
            increased = ceiling > _target ? ceiling : _target;
        }
    }
    _target = increased;
    clamp();
}

void BandwidthEstimator::clamp() {
    if (_rembLimit > 0.0 && _target > _rembLimit) {
        _target = _rembLimit;
    }
    if (_target > _configuration.maxBitrate) {
        _target = _configuration.maxBitrate;
    }
    if (_target < _configuration.minBitrate) {
        _target = _configuration.minBitrate;
    }
}

int BandwidthEstimator::targetBitrate() {
    Lock lock(&_mutex);
    return (int)_target;
}

float BandwidthEstimator::lossRate() {
    Lock lock(&_mutex);
    return _lossRate;
}

}
