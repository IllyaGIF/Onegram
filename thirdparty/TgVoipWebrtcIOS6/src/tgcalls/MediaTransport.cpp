#include "MediaTransport.h"

#include "rtp/Rtcp.h"
#include "rtp/RtpByteIO.h"
#include "rtp/RtpPacket.h"
#include "rtp/RtpTime.h"

#include <errno.h>
#include <string.h>
#include <sys/time.h>

namespace tgcalls {

namespace {

const size_t kQueueLimits[rtp::MediaPacketKindCount] = { 16, 64, 256, 512, 64 };

class ScopedLock {
public:
    explicit ScopedLock(pthread_mutex_t *mutex) : _mutex(mutex) { pthread_mutex_lock(_mutex); }
    ~ScopedLock() { pthread_mutex_unlock(_mutex); }

private:
    pthread_mutex_t *_mutex;
};

bool IsRtpOrRtcp(const uint8_t *data, size_t size) {
    return size >= 12 && data[0] >= 128 && data[0] <= 191;
}

}

MediaTransport::MediaTransport() :
_threadStarted(false),
_stopping(false),
_pacingRate(0),
_budgetBytes(0.0),
_budgetUpdatedMicros(0),
_nextTransportSequenceNumber((uint16_t)arc4random()),
_transactionSeed(arc4random()) {
    memset(&_statistics, 0, sizeof(_statistics));
    pthread_mutex_init(&_mutex, 0);
    pthread_cond_init(&_condition, 0);
    _threadStarted = pthread_create(&_thread, 0, &MediaTransport::threadEntry, this) == 0;
}

MediaTransport::~MediaTransport() {
    shutdown();
    for (size_t kind = 0; kind < rtp::MediaPacketKindCount; ++kind) {
        while (!_queues[kind].empty()) {
            rtp::MediaPacketRef dropped(_queues[kind].front());
            _queues[kind].pop_front();
        }
    }
    pthread_cond_destroy(&_condition);
    pthread_mutex_destroy(&_mutex);
}

void MediaTransport::shutdown() {
    bool join = false;
    {
        ScopedLock lock(&_mutex);
        if (!_stopping) {
            _stopping = true;
            join = _threadStarted;
            pthread_cond_signal(&_condition);
        }
        _path.reset();
    }
    if (join && !pthread_equal(pthread_self(), _thread)) {
        pthread_join(_thread, 0);
    }
}

void MediaTransport::setReceiver(const std::shared_ptr<Receiver> &receiver) {
    ScopedLock lock(&_mutex);
    _receiver = receiver;
}

void MediaTransport::setSendObserver(const std::shared_ptr<SendObserver> &observer) {
    ScopedLock lock(&_mutex);
    _sendObserver = observer;
}

void MediaTransport::setPath(const std::shared_ptr<Ios6RelayConnection> &relay, const std::string &peerHost, uint16_t peerPort, const std::shared_ptr<rtp::SrtpSession> &srtp) {
    std::shared_ptr<Path> path(new Path());
    path->relay = relay;
    path->srtp = srtp;
    if (!relay || !srtp || !relay->resolvePeer(peerHost, peerPort, &path->peer)) {
        clearPath();
        return;
    }
    ScopedLock lock(&_mutex);
    _path = path;
    pthread_cond_signal(&_condition);
}

void MediaTransport::clearPath() {
    ScopedLock lock(&_mutex);
    _path.reset();
}

void MediaTransport::setPacingRate(int bitsPerSecond) {
    ScopedLock lock(&_mutex);
    refillBudget(rtp::MonotonicMicros());
    _pacingRate = bitsPerSecond < 0 ? 0 : bitsPerSecond;
    pthread_cond_signal(&_condition);
}

void MediaTransport::refillBudget(int64_t nowMicros) {
    if (_budgetUpdatedMicros == 0 || _pacingRate <= 0) {
        _budgetUpdatedMicros = nowMicros;
        return;
    }
    const int64_t elapsed = nowMicros - _budgetUpdatedMicros;
    _budgetUpdatedMicros = nowMicros;
    if (elapsed <= 0) {
        return;
    }
    _budgetBytes += (double)_pacingRate * (double)elapsed / 8000000.0;
    double maximum = (double)_pacingRate * 0.02 / 8.0;
    if (maximum < 3000.0) {
        maximum = 3000.0;
    }
    if (_budgetBytes > maximum) {
        _budgetBytes = maximum;
    }
}

bool MediaTransport::isReady() const {
    ScopedLock lock(&_mutex);
    return (bool)_path;
}

std::shared_ptr<MediaTransport::Path> MediaTransport::currentPath() const {
    ScopedLock lock(&_mutex);
    return _path;
}

MediaTransport::Statistics MediaTransport::statistics() const {
    ScopedLock lock(&_mutex);
    return _statistics;
}

bool MediaTransport::handleIncomingDatagram(const uint8_t *data, size_t size, int64_t arrivalMicros) {
    if (data == 0 || !IsRtpOrRtcp(data, size)) {
        return false;
    }
    std::shared_ptr<Path> path;
    std::shared_ptr<Receiver> receiver;
    {
        ScopedLock lock(&_mutex);
        path = _path;
        receiver = _receiver.lock();
    }
    if (!path) {
        return false;
    }
    rtp::MediaPacketRef packet = rtp::AllocateMediaPacket();
    if (!packet->assign(data, size)) {
        ScopedLock lock(&_mutex);
        ++_statistics.droppedPackets;
        return true;
    }
    packet->timeMicros = arrivalMicros;
    const bool isRtcp = rtp::LooksLikeRtcp(data, size);
    size_t plainSize = 0;
    const bool decrypted = isRtcp
        ? path->srtp->inbound().unprotectRtcp(packet->data(), packet->size(), &plainSize)
        : path->srtp->inbound().unprotectRtp(packet->data(), packet->size(), &plainSize);
    {
        ScopedLock lock(&_mutex);
        _statistics.bytesReceived += size;
        ++_statistics.packetsReceived;
        _statistics.lastReceiveMicros = arrivalMicros;
        if (!decrypted) {
            ++_statistics.decryptFailures;
        }
    }
    if (!decrypted || !receiver) {
        return true;
    }
    packet->setSize(plainSize);
    if (isRtcp) {
        packet->kind = rtp::MediaPacketRtcp;
        receiver->onIncomingRtcp(std::move(packet));
    } else {
        packet->ssrc = rtp::ReadU32(packet->data() + 8);
        packet->sequenceNumber = rtp::ReadU16(packet->data() + 2);
        receiver->onIncomingRtp(std::move(packet));
    }
    return true;
}

void MediaTransport::sendMediaPacket(rtp::MediaPacketRef &&packet) {
    if (!packet || packet->size() == 0 || packet->kind >= rtp::MediaPacketKindCount) {
        return;
    }
    rtp::MediaPacketRef dropped;
    ScopedLock lock(&_mutex);
    if (_stopping) {
        return;
    }
    std::deque<rtp::MediaPacket *> &queue = _queues[packet->kind];
    if (queue.size() >= kQueueLimits[packet->kind]) {
        dropped = rtp::MediaPacketRef(queue.front());
        queue.pop_front();
        ++_statistics.droppedPackets;
    }
    queue.push_back(packet.release());
    pthread_cond_signal(&_condition);
}

void *MediaTransport::threadEntry(void *context) {
    static_cast<MediaTransport *>(context)->run();
    return 0;
}

void MediaTransport::run() {
    struct sched_param parameters;
    int policy = SCHED_OTHER;
    if (pthread_getschedparam(pthread_self(), &policy, &parameters) == 0) {
        parameters.sched_priority = sched_get_priority_max(policy);
        pthread_setschedparam(pthread_self(), policy, &parameters);
    }
    for (;;) {
        rtp::MediaPacketRef packet;
        std::shared_ptr<Path> path;
        std::shared_ptr<SendObserver> observer;
        {
            ScopedLock lock(&_mutex);
            for (;;) {
                if (_stopping) {
                    return;
                }
                int64_t waitMicros = -1;
                if (_path) {
                    for (size_t kind = 0; kind <= rtp::MediaPacketRtcp; ++kind) {
                        if (!_queues[kind].empty()) {
                            packet = rtp::MediaPacketRef(_queues[kind].front());
                            _queues[kind].pop_front();
                            break;
                        }
                    }
                    if (!packet) {
                        const int64_t now = rtp::MonotonicMicros();
                        refillBudget(now);
                        for (size_t kind = rtp::MediaPacketRetransmission; kind < rtp::MediaPacketKindCount; ++kind) {
                            if (_queues[kind].empty()) {
                                continue;
                            }
                            if (_pacingRate <= 0 || _budgetBytes > 0.0) {
                                packet = rtp::MediaPacketRef(_queues[kind].front());
                                _queues[kind].pop_front();
                                if (_pacingRate > 0) {
                                    _budgetBytes -= (double)packet->size();
                                }
                            } else {
                                waitMicros = (int64_t)((-_budgetBytes + 1.0) * 8000000.0 / (double)_pacingRate);
                                if (waitMicros < 1000) {
                                    waitMicros = 1000;
                                }
                            }
                            break;
                        }
                    }
                }
                if (packet) {
                    break;
                }
                if (waitMicros > 0) {
                    struct timeval current;
                    gettimeofday(&current, 0);
                    const int64_t target = (int64_t)current.tv_sec * 1000000 + current.tv_usec + waitMicros;
                    struct timespec deadline;
                    deadline.tv_sec = (time_t)(target / 1000000);
                    deadline.tv_nsec = (long)((target % 1000000) * 1000);
                    pthread_cond_timedwait(&_condition, &_mutex, &deadline);
                } else {
                    pthread_cond_wait(&_condition, &_mutex);
                }
            }
            path = _path;
            observer = _sendObserver;
        }
        const bool sent = transmit(*packet, path, observer);
        ScopedLock lock(&_mutex);
        if (sent) {
            ++_statistics.packetsSent;
        } else {
            ++_statistics.sendFailures;
        }
    }
}

bool MediaTransport::transmit(rtp::MediaPacket &packet, const std::shared_ptr<Path> &path, const std::shared_ptr<SendObserver> &observer) {
    const int64_t now = rtp::MonotonicMicros();
    SentPacketInfo info;
    info.hasTransportSequenceNumber = false;
    info.transportSequenceNumber = 0;
    info.sendTimeMicros = now;
    info.size = (uint32_t)packet.size();
    info.kind = packet.kind;
    size_t protectedSize = 0;
    if (packet.kind == rtp::MediaPacketRtcp) {
        if (!path->srtp->outbound().protectRtcp(packet.data(), packet.size(), packet.capacity(), &protectedSize)) {
            return false;
        }
    } else {
        if (packet.transportSequenceOffset != 0 && packet.transportSequenceOffset + 2 <= packet.size()) {
            info.hasTransportSequenceNumber = true;
            info.transportSequenceNumber = _nextTransportSequenceNumber++;
            packet.transportSequenceNumber = info.transportSequenceNumber;
            rtp::WriteTransportSequenceNumber(packet.data(), packet.transportSequenceOffset, info.transportSequenceNumber);
        }
        if (packet.absSendTimeOffset != 0 && packet.absSendTimeOffset + 3 <= packet.size()) {
            rtp::WriteAbsSendTime(packet.data(), packet.absSendTimeOffset, now);
        }
        if (!path->srtp->outbound().protectRtp(packet.data(), packet.size(), packet.capacity(), &protectedSize)) {
            return false;
        }
    }
    const size_t paddedSize = (protectedSize + 3) & ~(size_t)3;
    if (paddedSize > packet.capacity()) {
        return false;
    }
    memset(packet.data() + protectedSize, 0, paddedSize - protectedSize);
    const size_t framing = path->relay->framingHeaderSize();
    packet.setSize(protectedSize);
    if (!packet.prepend(framing)) {
        return false;
    }
    path->relay->writeFraming(path->peer, protectedSize, _transactionSeed++, packet.data());
    const size_t datagramSize = framing + paddedSize;
    ssize_t sent = 0;
    do {
        sent = path->relay->socket().sendPacket(packet.data(), datagramSize);
    } while (sent < 0 && errno == EINTR);
    if (sent != (ssize_t)datagramSize) {
        return false;
    }
    info.size = (uint32_t)protectedSize;
    if (observer) {
        observer->onPacketSent(info);
    }
    ScopedLock lock(&_mutex);
    _statistics.bytesSent += datagramSize;
    return true;
}

}
