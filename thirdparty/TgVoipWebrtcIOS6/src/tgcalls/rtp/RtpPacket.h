#ifndef TGCALLS_RTP_PACKET_H
#define TGCALLS_RTP_PACKET_H

#include <stddef.h>
#include <stdint.h>
#include <string>

namespace tgcalls {
namespace rtp {

enum RtpExtensionType {
    RtpExtensionNone = 0,
    RtpExtensionAbsSendTime,
    RtpExtensionTransportSequenceNumber,
    RtpExtensionVideoOrientation,
    RtpExtensionAudioLevel,
    RtpExtensionTypeCount
};

class RtpPacketView;

class RtpExtensionMap {
public:
    RtpExtensionMap();

    static RtpExtensionType typeForUri(const std::string &uri);
    static const char *uriForType(RtpExtensionType type);
    static size_t valueSizeForType(RtpExtensionType type);

    bool registerExtension(RtpExtensionType type, int id);
    bool registerUri(const std::string &uri, int id);
    void clear();

    int idOf(RtpExtensionType type) const;
    RtpExtensionType typeOf(int id) const;
    bool isRegistered(RtpExtensionType type) const;

    bool readTransportSequenceNumber(const RtpPacketView &packet, uint16_t *value) const;
    bool readAbsSendTime(const RtpPacketView &packet, uint32_t *value) const;
    bool readVideoRotation(const RtpPacketView &packet, int *degrees) const;
    bool readAudioLevel(const RtpPacketView &packet, bool *voiceActivity, uint8_t *level) const;

private:
    uint8_t _ids[RtpExtensionTypeCount];
    uint8_t _types[256];
};

class RtpPacketView {
public:
    RtpPacketView();

    bool parse(const uint8_t *data, size_t size);

    const uint8_t *data() const { return _data; }
    size_t size() const { return _size; }

    bool marker() const { return _marker; }
    uint8_t payloadType() const { return _payloadType; }
    uint16_t sequenceNumber() const { return _sequenceNumber; }
    uint32_t timestamp() const { return _timestamp; }
    uint32_t ssrc() const { return _ssrc; }
    uint8_t csrcCount() const { return _csrcCount; }

    size_t headerSize() const { return _headerSize; }
    size_t payloadSize() const { return _payloadSize; }
    size_t paddingSize() const { return _paddingSize; }
    const uint8_t *payload() const { return _data + _headerSize; }

    bool findExtension(int id, size_t *offset, size_t *length) const;

private:
    const uint8_t *_data;
    size_t _size;
    bool _marker;
    uint8_t _payloadType;
    uint16_t _sequenceNumber;
    uint32_t _timestamp;
    uint32_t _ssrc;
    uint8_t _csrcCount;
    size_t _headerSize;
    size_t _payloadSize;
    size_t _paddingSize;
    size_t _extensionOffset;
    size_t _extensionSize;
    uint16_t _extensionProfile;
};

class RtpPacketWriter {
public:
    RtpPacketWriter(uint8_t *buffer, size_t capacity);

    void setHeader(uint8_t payloadType, bool marker, uint16_t sequenceNumber, uint32_t timestamp, uint32_t ssrc);
    uint8_t *addExtension(int id, size_t length, size_t *offset);
    bool addTransportSequenceNumber(const RtpExtensionMap &map, size_t *offset);
    bool addAbsSendTime(const RtpExtensionMap &map, size_t *offset);
    bool addVideoRotation(const RtpExtensionMap &map, int degrees);
    bool addAudioLevel(const RtpExtensionMap &map, bool voiceActivity, uint8_t level);

    uint8_t *payload();
    size_t payloadCapacity();
    size_t finish(size_t payloadSize);
    bool failed() const { return _failed; }

private:
    void sealExtensions();

    uint8_t *_buffer;
    size_t _capacity;
    size_t _position;
    size_t _extensionHeaderOffset;
    bool _hasExtensions;
    bool _sealed;
    bool _failed;
};

void WriteTransportSequenceNumber(uint8_t *packet, size_t offset, uint16_t value);
void WriteAbsSendTime(uint8_t *packet, size_t offset, int64_t sendTimeMicros);

}
}

#endif
