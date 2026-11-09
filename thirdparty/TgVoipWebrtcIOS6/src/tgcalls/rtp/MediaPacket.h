#ifndef TGCALLS_RTP_MEDIA_PACKET_H
#define TGCALLS_RTP_MEDIA_PACKET_H

#include <stddef.h>
#include <stdint.h>

namespace tgcalls {
namespace rtp {

enum MediaPacketKind {
    MediaPacketAudio = 0,
    MediaPacketRtcp = 1,
    MediaPacketRetransmission = 2,
    MediaPacketVideo = 3,
    MediaPacketPadding = 4,
    MediaPacketKindCount = 5
};

class MediaPacket {
public:
    enum {
        kHeadroom = 64,
        kMaxDatagram = 1472,
        kTailroom = 32,
        kStorage = kHeadroom + kMaxDatagram + kTailroom
    };

    uint8_t *data() { return _storage + _offset; }
    const uint8_t *data() const { return _storage + _offset; }
    size_t size() const { return _size; }
    size_t capacity() const { return kStorage - _offset; }
    size_t headroom() const { return _offset; }

    void setSize(size_t size) { _size = size; }
    bool assign(const uint8_t *bytes, size_t size);
    bool prepend(size_t size);
    void resetLayout();

    MediaPacketKind kind;
    int64_t timeMicros;
    uint32_t ssrc;
    uint16_t sequenceNumber;
    uint16_t transportSequenceNumber;
    size_t transportSequenceOffset;
    size_t absSendTimeOffset;
    bool isKeyframe;

private:
    friend class MediaPacketPool;
    friend class MediaPacketRef;

    MediaPacket();

    MediaPacket *_next;
    size_t _offset;
    size_t _size;
    uint8_t _storage[kStorage];
};

class MediaPacketRef {
public:
    MediaPacketRef() : _packet(0) {}
    explicit MediaPacketRef(MediaPacket *packet) : _packet(packet) {}
    MediaPacketRef(MediaPacketRef &&other) : _packet(other._packet) { other._packet = 0; }
    ~MediaPacketRef() { reset(); }

    MediaPacketRef &operator=(MediaPacketRef &&other) {
        if (this != &other) {
            reset();
            _packet = other._packet;
            other._packet = 0;
        }
        return *this;
    }

    MediaPacket *get() const { return _packet; }
    MediaPacket *operator->() const { return _packet; }
    MediaPacket &operator*() const { return *_packet; }
    explicit operator bool() const { return _packet != 0; }

    void reset();
    MediaPacket *release() {
        MediaPacket *packet = _packet;
        _packet = 0;
        return packet;
    }

    MediaPacketRef clone() const;

private:
    MediaPacketRef(const MediaPacketRef &) = delete;
    MediaPacketRef &operator=(const MediaPacketRef &) = delete;

    MediaPacket *_packet;
};

MediaPacketRef AllocateMediaPacket();

class MediaPacketSink {
public:
    virtual ~MediaPacketSink() {}
    virtual void sendMediaPacket(MediaPacketRef &&packet) = 0;
};

}
}

#endif
