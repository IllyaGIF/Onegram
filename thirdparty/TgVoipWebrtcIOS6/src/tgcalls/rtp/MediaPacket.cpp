#include "rtp/MediaPacket.h"

#include <pthread.h>
#include <string.h>

namespace tgcalls {
namespace rtp {

class MediaPacketPool {
public:
    static MediaPacketPool &shared() {
        static MediaPacketPool *pool = new MediaPacketPool();
        return *pool;
    }

    MediaPacket *acquire() {
        pthread_mutex_lock(&_mutex);
        MediaPacket *packet = _free;
        if (packet != 0) {
            _free = packet->_next;
            --_freeCount;
        }
        pthread_mutex_unlock(&_mutex);
        if (packet == 0) {
            packet = new MediaPacket();
        }
        packet->_next = 0;
        packet->resetLayout();
        return packet;
    }

    void release(MediaPacket *packet) {
        pthread_mutex_lock(&_mutex);
        if (_freeCount < kMaxFreePackets) {
            packet->_next = _free;
            _free = packet;
            ++_freeCount;
            packet = 0;
        }
        pthread_mutex_unlock(&_mutex);
        delete packet;
    }

private:
    enum { kInitialPackets = 96, kMaxFreePackets = 768 };

    MediaPacketPool() : _free(0), _freeCount(0) {
        pthread_mutex_init(&_mutex, 0);
        for (size_t i = 0; i < kInitialPackets; ++i) {
            MediaPacket *packet = new MediaPacket();
            packet->_next = _free;
            _free = packet;
            ++_freeCount;
        }
    }

    pthread_mutex_t _mutex;
    MediaPacket *_free;
    size_t _freeCount;
};

MediaPacket::MediaPacket() :
kind(MediaPacketAudio),
timeMicros(0),
ssrc(0),
sequenceNumber(0),
transportSequenceNumber(0),
transportSequenceOffset(0),
absSendTimeOffset(0),
isKeyframe(false),
_next(0),
_offset(kHeadroom),
_size(0) {
}

void MediaPacket::resetLayout() {
    kind = MediaPacketAudio;
    timeMicros = 0;
    ssrc = 0;
    sequenceNumber = 0;
    transportSequenceNumber = 0;
    transportSequenceOffset = 0;
    absSendTimeOffset = 0;
    isKeyframe = false;
    _offset = kHeadroom;
    _size = 0;
}

bool MediaPacket::assign(const uint8_t *bytes, size_t size) {
    if (size > capacity()) {
        return false;
    }
    memcpy(data(), bytes, size);
    _size = size;
    return true;
}

bool MediaPacket::prepend(size_t size) {
    if (size > _offset) {
        return false;
    }
    _offset -= size;
    _size += size;
    return true;
}

void MediaPacketRef::reset() {
    if (_packet != 0) {
        MediaPacketPool::shared().release(_packet);
        _packet = 0;
    }
}

MediaPacketRef MediaPacketRef::clone() const {
    if (_packet == 0) {
        return MediaPacketRef();
    }
    MediaPacketRef result(MediaPacketPool::shared().acquire());
    MediaPacket *target = result.get();
    target->kind = _packet->kind;
    target->timeMicros = _packet->timeMicros;
    target->ssrc = _packet->ssrc;
    target->sequenceNumber = _packet->sequenceNumber;
    target->transportSequenceNumber = _packet->transportSequenceNumber;
    target->transportSequenceOffset = _packet->transportSequenceOffset;
    target->absSendTimeOffset = _packet->absSendTimeOffset;
    target->isKeyframe = _packet->isKeyframe;
    target->_offset = _packet->_offset;
    target->_size = _packet->_size;
    memcpy(target->_storage + target->_offset, _packet->_storage + _packet->_offset, _packet->_size);
    return result;
}

MediaPacketRef AllocateMediaPacket() {
    return MediaPacketRef(MediaPacketPool::shared().acquire());
}

}
}
