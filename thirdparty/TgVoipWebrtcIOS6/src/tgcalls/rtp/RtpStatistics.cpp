#include "rtp/RtpStatistics.h"

#include "rtp/RtpTime.h"

#include <math.h>

namespace tgcalls {
namespace rtp {

namespace {

const uint16_t kMaxDropout = 3000;
const uint16_t kMaxMisorder = 100;

}

RtpReceiveStatistics::RtpReceiveStatistics() {
    reset(0, 90000);
}

void RtpReceiveStatistics::reset(uint32_t ssrc, uint32_t clockRate) {
    _ssrc = ssrc;
    _clockRate = clockRate == 0 ? 90000 : clockRate;
    _started = false;
    _maxSequence = 0;
    _cycles = 0;
    _baseSequence = 0;
    _received = 0;
    _bytes = 0;
    _expectedPrior = 0;
    _receivedPrior = 0;
    _jitter = 0.0;
    _hasTransit = false;
    _lastTransit = 0;
    _lastArrivalMicros = 0;
    _lastSenderReportCompact = 0;
    _lastSenderReportArrivalMicros = 0;
    _recentLossRate = 0.0f;
}

void RtpReceiveStatistics::onPacket(uint16_t sequenceNumber, uint32_t rtpTimestamp, int64_t arrivalMicros, size_t size, bool retransmitted) {
    if (!_started) {
        _started = true;
        _maxSequence = sequenceNumber;
        _baseSequence = sequenceNumber;
        _cycles = 0;
    } else {
        const uint16_t delta = (uint16_t)(sequenceNumber - _maxSequence);
        if (delta != 0 && delta < kMaxDropout) {
            if (sequenceNumber < _maxSequence) {
                _cycles += 65536;
            }
            _maxSequence = sequenceNumber;
        } else if (delta != 0 && delta <= (uint16_t)(65535 - kMaxMisorder)) {
            _maxSequence = sequenceNumber;
            _baseSequence = sequenceNumber;
            _cycles = 0;
            _expectedPrior = 0;
            _receivedPrior = 0;
            _received = 0;
        }
    }
    ++_received;
    _bytes += size;
    _lastArrivalMicros = arrivalMicros;
    if (!retransmitted) {
        const int64_t arrivalUnits = (int64_t)((double)arrivalMicros * (double)_clockRate / 1000000.0);
        const int64_t transit = arrivalUnits - (int64_t)rtpTimestamp;
        if (_hasTransit) {
            int64_t difference = transit - _lastTransit;
            if (difference < 0) {
                difference = -difference;
            }
            if (difference < (int64_t)_clockRate * 10) {
                _jitter += ((double)difference - _jitter) / 16.0;
            }
        }
        _lastTransit = transit;
        _hasTransit = true;
    }
}

void RtpReceiveStatistics::onSenderReport(const RtcpSenderInfo &info, int64_t arrivalMicros) {
    _lastSenderReportCompact = NtpCompact(info.ntpTimestamp);
    _lastSenderReportArrivalMicros = arrivalMicros;
}

bool RtpReceiveStatistics::makeReportBlock(int64_t nowMicros, RtcpReportBlock *block) {
    if (!_started) {
        return false;
    }
    const uint32_t extendedMax = _cycles + _maxSequence;
    const uint32_t expected = extendedMax - _baseSequence + 1;
    const int64_t lost = (int64_t)expected - (int64_t)_received;
    const uint32_t expectedInterval = expected - _expectedPrior;
    const int64_t receivedInterval = (int64_t)(_received - _receivedPrior);
    const int64_t lostInterval = (int64_t)expectedInterval - receivedInterval;
    _expectedPrior = expected;
    _receivedPrior = _received;
    uint8_t fraction = 0;
    if (expectedInterval != 0 && lostInterval > 0) {
        fraction = (uint8_t)((lostInterval << 8) / expectedInterval);
    }
    _recentLossRate = expectedInterval == 0 || lostInterval <= 0 ? 0.0f : (float)lostInterval / (float)expectedInterval;
    block->sourceSsrc = _ssrc;
    block->fractionLost = fraction;
    block->cumulativeLost = (int32_t)lost;
    block->extendedHighestSequence = extendedMax;
    block->jitter = (uint32_t)_jitter;
    block->lastSenderReport = _lastSenderReportCompact;
    block->delaySinceLastSenderReport = 0;
    if (_lastSenderReportCompact != 0) {
        const int64_t delay = nowMicros - _lastSenderReportArrivalMicros;
        block->delaySinceLastSenderReport = delay <= 0 ? 0 : (uint32_t)(((uint64_t)delay << 16) / 1000000ULL);
    }
    return true;
}

float RtpReceiveStatistics::jitterMillis() const {
    return (float)(_jitter * 1000.0 / (double)_clockRate);
}

RtpSendStatistics::RtpSendStatistics() {
    reset(0, 90000);
}

void RtpSendStatistics::reset(uint32_t ssrc, uint32_t clockRate) {
    _ssrc = ssrc;
    _clockRate = clockRate == 0 ? 90000 : clockRate;
    _hasPackets = false;
    _packets = 0;
    _octets = 0;
    _lastRtpTimestamp = 0;
    _lastCaptureMicros = 0;
}

void RtpSendStatistics::onPacketSent(uint32_t rtpTimestamp, int64_t captureMicros, size_t payloadSize) {
    _hasPackets = true;
    ++_packets;
    _octets += (uint32_t)payloadSize;
    _lastRtpTimestamp = rtpTimestamp;
    _lastCaptureMicros = captureMicros;
}

bool RtpSendStatistics::makeSenderInfo(int64_t nowMicros, uint64_t ntpNow, RtcpSenderInfo *info) const {
    if (!_hasPackets) {
        return false;
    }
    const int64_t elapsed = nowMicros - _lastCaptureMicros;
    info->ntpTimestamp = ntpNow;
    info->rtpTimestamp = _lastRtpTimestamp + (uint32_t)((elapsed * (int64_t)_clockRate) / 1000000);
    info->packetCount = _packets;
    info->octetCount = _octets;
    return true;
}

RttEstimator::RttEstimator() :
_hasValue(false),
_smoothedMicros(0),
_lastMicros(0) {
}

void RttEstimator::onReportBlock(const RtcpReportBlock &block, uint64_t ntpNow) {
    if (block.lastSenderReport == 0) {
        return;
    }
    const uint32_t now = NtpCompact(ntpNow);
    const uint32_t rtt = now - block.lastSenderReport - block.delaySinceLastSenderReport;
    if (rtt > 0x7FFFFFFFU) {
        return;
    }
    onSample(CompactNtpToMicros(rtt));
}

void RttEstimator::onSample(int64_t rttMicros) {
    if (rttMicros <= 0 || rttMicros > 10000000) {
        return;
    }
    _lastMicros = rttMicros;
    if (!_hasValue) {
        _hasValue = true;
        _smoothedMicros = rttMicros;
    } else {
        _smoothedMicros = (_smoothedMicros * 7 + rttMicros) / 8;
    }
}

}
}
