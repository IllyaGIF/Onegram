#ifndef TGCALLS_MEDIA_TRANSPORT_H
#define TGCALLS_MEDIA_TRANSPORT_H

#include "rtp/MediaPacket.h"
#include "rtp/SrtpSession.h"
#include "Ios6RelayConnection.h"

#include <deque>
#include <memory>
#include <pthread.h>
#include <stdint.h>
#include <string>

namespace tgcalls {

class MediaTransport : public rtp::MediaPacketSink {
public:
    class Receiver {
    public:
        virtual ~Receiver() {}
        virtual void onIncomingRtp(rtp::MediaPacketRef &&packet) = 0;
        virtual void onIncomingRtcp(rtp::MediaPacketRef &&packet) = 0;
    };

    struct SentPacketInfo {
        uint16_t transportSequenceNumber;
        bool hasTransportSequenceNumber;
        int64_t sendTimeMicros;
        uint32_t size;
        rtp::MediaPacketKind kind;
    };

    class SendObserver {
    public:
        virtual ~SendObserver() {}
        virtual void onPacketSent(const SentPacketInfo &info) = 0;
    };

    struct Statistics {
        uint64_t bytesSent;
        uint64_t bytesReceived;
        uint64_t packetsSent;
        uint64_t packetsReceived;
        uint32_t sendFailures;
        uint32_t droppedPackets;
        uint32_t decryptFailures;
        int64_t lastReceiveMicros;
    };

    MediaTransport();
    ~MediaTransport();

    void setReceiver(const std::shared_ptr<Receiver> &receiver);
    void setSendObserver(const std::shared_ptr<SendObserver> &observer);

    void setPath(const std::shared_ptr<Ios6RelayConnection> &relay, const std::string &peerHost, uint16_t peerPort, const std::shared_ptr<rtp::SrtpSession> &srtp);
    void clearPath();
    bool isReady() const;

    bool handleIncomingDatagram(const uint8_t *data, size_t size, int64_t arrivalMicros);

    void sendMediaPacket(rtp::MediaPacketRef &&packet) override;

    void setPacingRate(int bitsPerSecond);
    Statistics statistics() const;
    void shutdown();

private:
    struct Path {
        std::shared_ptr<Ios6RelayConnection> relay;
        Ios6RelayPeerAddress peer;
        std::shared_ptr<rtp::SrtpSession> srtp;
    };

    MediaTransport(const MediaTransport &) = delete;
    MediaTransport &operator=(const MediaTransport &) = delete;

    static void *threadEntry(void *context);
    void run();
    bool transmit(rtp::MediaPacket &packet, const std::shared_ptr<Path> &path, const std::shared_ptr<SendObserver> &observer);
    std::shared_ptr<Path> currentPath() const;
    void refillBudget(int64_t nowMicros);

    mutable pthread_mutex_t _mutex;
    pthread_cond_t _condition;
    pthread_t _thread;
    bool _threadStarted;
    bool _stopping;
    std::shared_ptr<Path> _path;
    std::weak_ptr<Receiver> _receiver;
    std::shared_ptr<SendObserver> _sendObserver;
    std::deque<rtp::MediaPacket *> _queues[rtp::MediaPacketKindCount];
    int _pacingRate;
    double _budgetBytes;
    int64_t _budgetUpdatedMicros;
    uint16_t _nextTransportSequenceNumber;
    uint32_t _transactionSeed;
    Statistics _statistics;
};

}

#endif
