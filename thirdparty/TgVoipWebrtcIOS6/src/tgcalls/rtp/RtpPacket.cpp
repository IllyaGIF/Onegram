#include "rtp/RtpPacket.h"

#include "rtp/RtpByteIO.h"

#include <string.h>

namespace tgcalls {
namespace rtp {

namespace {

const uint16_t kOneByteExtensionProfile = 0xBEDE;
const uint16_t kTwoByteExtensionProfileMask = 0xFFF0;
const uint16_t kTwoByteExtensionProfile = 0x1000;
const size_t kFixedHeaderSize = 12;

struct ExtensionDescriptor {
    RtpExtensionType type;
    const char *uri;
    size_t valueSize;
};

const ExtensionDescriptor kExtensionDescriptors[] = {
    { RtpExtensionAbsSendTime, "http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time", 3 },
    { RtpExtensionTransportSequenceNumber, "http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01", 2 },
    { RtpExtensionVideoOrientation, "urn:3gpp:video-orientation", 1 },
    { RtpExtensionAudioLevel, "urn:ietf:params:rtp-hdrext:ssrc-audio-level", 1 }
};

const size_t kExtensionDescriptorCount = sizeof(kExtensionDescriptors) / sizeof(kExtensionDescriptors[0]);

}

RtpExtensionMap::RtpExtensionMap() {
    clear();
}

RtpExtensionType RtpExtensionMap::typeForUri(const std::string &uri) {
    for (size_t i = 0; i < kExtensionDescriptorCount; ++i) {
        if (uri == kExtensionDescriptors[i].uri) {
            return kExtensionDescriptors[i].type;
        }
    }
    return RtpExtensionNone;
}

const char *RtpExtensionMap::uriForType(RtpExtensionType type) {
    for (size_t i = 0; i < kExtensionDescriptorCount; ++i) {
        if (kExtensionDescriptors[i].type == type) {
            return kExtensionDescriptors[i].uri;
        }
    }
    return "";
}

size_t RtpExtensionMap::valueSizeForType(RtpExtensionType type) {
    for (size_t i = 0; i < kExtensionDescriptorCount; ++i) {
        if (kExtensionDescriptors[i].type == type) {
            return kExtensionDescriptors[i].valueSize;
        }
    }
    return 0;
}

bool RtpExtensionMap::registerExtension(RtpExtensionType type, int id) {
    if (type <= RtpExtensionNone || type >= RtpExtensionTypeCount || id <= 0 || id > 255 || id == 15) {
        return false;
    }
    if (_types[id] != RtpExtensionNone && _types[id] != type) {
        return false;
    }
    if (_ids[type] != 0) {
        _types[_ids[type]] = RtpExtensionNone;
    }
    _ids[type] = (uint8_t)id;
    _types[id] = (uint8_t)type;
    return true;
}

bool RtpExtensionMap::registerUri(const std::string &uri, int id) {
    const RtpExtensionType type = typeForUri(uri);
    if (type == RtpExtensionNone) {
        return false;
    }
    return registerExtension(type, id);
}

void RtpExtensionMap::clear() {
    memset(_ids, 0, sizeof(_ids));
    memset(_types, 0, sizeof(_types));
}

int RtpExtensionMap::idOf(RtpExtensionType type) const {
    if (type <= RtpExtensionNone || type >= RtpExtensionTypeCount) {
        return 0;
    }
    return _ids[type];
}

RtpExtensionType RtpExtensionMap::typeOf(int id) const {
    if (id <= 0 || id > 255) {
        return RtpExtensionNone;
    }
    return (RtpExtensionType)_types[id];
}

bool RtpExtensionMap::isRegistered(RtpExtensionType type) const {
    return idOf(type) != 0;
}

bool RtpExtensionMap::readTransportSequenceNumber(const RtpPacketView &packet, uint16_t *value) const {
    size_t offset = 0;
    size_t length = 0;
    const int id = idOf(RtpExtensionTransportSequenceNumber);
    if (id == 0 || !packet.findExtension(id, &offset, &length) || length < 2) {
        return false;
    }
    *value = ReadU16(packet.data() + offset);
    return true;
}

bool RtpExtensionMap::readAbsSendTime(const RtpPacketView &packet, uint32_t *value) const {
    size_t offset = 0;
    size_t length = 0;
    const int id = idOf(RtpExtensionAbsSendTime);
    if (id == 0 || !packet.findExtension(id, &offset, &length) || length < 3) {
        return false;
    }
    *value = ReadU24(packet.data() + offset);
    return true;
}

bool RtpExtensionMap::readVideoRotation(const RtpPacketView &packet, int *degrees) const {
    size_t offset = 0;
    size_t length = 0;
    const int id = idOf(RtpExtensionVideoOrientation);
    if (id == 0 || !packet.findExtension(id, &offset, &length) || length < 1) {
        return false;
    }
    static const int kRotations[4] = { 0, 90, 180, 270 };
    *degrees = kRotations[packet.data()[offset] & 0x03];
    return true;
}

bool RtpExtensionMap::readAudioLevel(const RtpPacketView &packet, bool *voiceActivity, uint8_t *level) const {
    size_t offset = 0;
    size_t length = 0;
    const int id = idOf(RtpExtensionAudioLevel);
    if (id == 0 || !packet.findExtension(id, &offset, &length) || length < 1) {
        return false;
    }
    const uint8_t value = packet.data()[offset];
    *voiceActivity = (value & 0x80) != 0;
    *level = value & 0x7F;
    return true;
}

RtpPacketView::RtpPacketView() :
_data(0),
_size(0),
_marker(false),
_payloadType(0),
_sequenceNumber(0),
_timestamp(0),
_ssrc(0),
_csrcCount(0),
_headerSize(0),
_payloadSize(0),
_paddingSize(0),
_extensionOffset(0),
_extensionSize(0),
_extensionProfile(0) {
}

bool RtpPacketView::parse(const uint8_t *data, size_t size) {
    _data = data;
    _size = size;
    _extensionOffset = 0;
    _extensionSize = 0;
    _extensionProfile = 0;
    if (data == 0 || size < kFixedHeaderSize || (data[0] >> 6) != 2) {
        return false;
    }
    const bool hasPadding = (data[0] & 0x20) != 0;
    const bool hasExtension = (data[0] & 0x10) != 0;
    _csrcCount = data[0] & 0x0F;
    _marker = (data[1] & 0x80) != 0;
    _payloadType = data[1] & 0x7F;
    _sequenceNumber = ReadU16(data + 2);
    _timestamp = ReadU32(data + 4);
    _ssrc = ReadU32(data + 8);
    size_t headerSize = kFixedHeaderSize + (size_t)_csrcCount * 4;
    if (headerSize > size) {
        return false;
    }
    if (hasExtension) {
        if (headerSize + 4 > size) {
            return false;
        }
        _extensionProfile = ReadU16(data + headerSize);
        const size_t extensionSize = (size_t)ReadU16(data + headerSize + 2) * 4;
        if (headerSize + 4 + extensionSize > size) {
            return false;
        }
        _extensionOffset = headerSize + 4;
        _extensionSize = extensionSize;
        headerSize += 4 + extensionSize;
    }
    size_t paddingSize = 0;
    if (hasPadding) {
        paddingSize = data[size - 1];
        if (paddingSize == 0 || headerSize + paddingSize > size) {
            return false;
        }
    }
    _headerSize = headerSize;
    _paddingSize = paddingSize;
    _payloadSize = size - headerSize - paddingSize;
    return true;
}

bool RtpPacketView::findExtension(int id, size_t *offset, size_t *length) const {
    if (_extensionSize == 0 || id <= 0) {
        return false;
    }
    const uint8_t *begin = _data + _extensionOffset;
    const size_t end = _extensionSize;
    size_t position = 0;
    if (_extensionProfile == kOneByteExtensionProfile) {
        while (position < end) {
            const uint8_t header = begin[position];
            if (header == 0) {
                ++position;
                continue;
            }
            const int elementId = header >> 4;
            if (elementId == 15) {
                return false;
            }
            const size_t elementLength = (size_t)(header & 0x0F) + 1;
            ++position;
            if (position + elementLength > end) {
                return false;
            }
            if (elementId == id) {
                *offset = _extensionOffset + position;
                *length = elementLength;
                return true;
            }
            position += elementLength;
        }
        return false;
    }
    if ((_extensionProfile & kTwoByteExtensionProfileMask) == kTwoByteExtensionProfile) {
        while (position < end) {
            const uint8_t elementId = begin[position];
            if (elementId == 0) {
                ++position;
                continue;
            }
            if (position + 2 > end) {
                return false;
            }
            const size_t elementLength = begin[position + 1];
            position += 2;
            if (position + elementLength > end) {
                return false;
            }
            if (elementId == id) {
                *offset = _extensionOffset + position;
                *length = elementLength;
                return true;
            }
            position += elementLength;
        }
    }
    return false;
}

RtpPacketWriter::RtpPacketWriter(uint8_t *buffer, size_t capacity) :
_buffer(buffer),
_capacity(capacity),
_position(0),
_extensionHeaderOffset(0),
_hasExtensions(false),
_sealed(false),
_failed(capacity < kFixedHeaderSize) {
}

void RtpPacketWriter::setHeader(uint8_t payloadType, bool marker, uint16_t sequenceNumber, uint32_t timestamp, uint32_t ssrc) {
    if (_failed) {
        return;
    }
    _buffer[0] = 0x80;
    _buffer[1] = (uint8_t)((payloadType & 0x7F) | (marker ? 0x80 : 0x00));
    WriteU16(_buffer + 2, sequenceNumber);
    WriteU32(_buffer + 4, timestamp);
    WriteU32(_buffer + 8, ssrc);
    _position = kFixedHeaderSize;
    _hasExtensions = false;
    _sealed = false;
}

uint8_t *RtpPacketWriter::addExtension(int id, size_t length, size_t *offset) {
    if (_failed || _sealed || id <= 0 || id >= 15 || length == 0 || length > 16) {
        _failed = true;
        return 0;
    }
    if (!_hasExtensions) {
        if (_position + 4 > _capacity) {
            _failed = true;
            return 0;
        }
        _buffer[0] |= 0x10;
        _extensionHeaderOffset = _position;
        WriteU16(_buffer + _position, kOneByteExtensionProfile);
        WriteU16(_buffer + _position + 2, 0);
        _position += 4;
        _hasExtensions = true;
    }
    if (_position + 1 + length > _capacity) {
        _failed = true;
        return 0;
    }
    _buffer[_position] = (uint8_t)((id << 4) | (int)(length - 1));
    ++_position;
    uint8_t *value = _buffer + _position;
    if (offset != 0) {
        *offset = _position;
    }
    memset(value, 0, length);
    _position += length;
    return value;
}

bool RtpPacketWriter::addTransportSequenceNumber(const RtpExtensionMap &map, size_t *offset) {
    const int id = map.idOf(RtpExtensionTransportSequenceNumber);
    return id != 0 && addExtension(id, 2, offset) != 0;
}

bool RtpPacketWriter::addAbsSendTime(const RtpExtensionMap &map, size_t *offset) {
    const int id = map.idOf(RtpExtensionAbsSendTime);
    return id != 0 && addExtension(id, 3, offset) != 0;
}

bool RtpPacketWriter::addVideoRotation(const RtpExtensionMap &map, int degrees) {
    const int id = map.idOf(RtpExtensionVideoOrientation);
    if (id == 0) {
        return false;
    }
    uint8_t *value = addExtension(id, 1, 0);
    if (value == 0) {
        return false;
    }
    uint8_t rotation = 0;
    switch (degrees) {
        case 90:
            rotation = 1;
            break;
        case 180:
            rotation = 2;
            break;
        case 270:
            rotation = 3;
            break;
        default:
            rotation = 0;
            break;
    }
    *value = rotation;
    return true;
}

bool RtpPacketWriter::addAudioLevel(const RtpExtensionMap &map, bool voiceActivity, uint8_t level) {
    const int id = map.idOf(RtpExtensionAudioLevel);
    if (id == 0) {
        return false;
    }
    uint8_t *value = addExtension(id, 1, 0);
    if (value == 0) {
        return false;
    }
    *value = (uint8_t)((voiceActivity ? 0x80 : 0x00) | (level & 0x7F));
    return true;
}

void RtpPacketWriter::sealExtensions() {
    if (_sealed) {
        return;
    }
    _sealed = true;
    if (!_hasExtensions || _failed) {
        return;
    }
    while (((_position - _extensionHeaderOffset - 4) & 3) != 0) {
        if (_position >= _capacity) {
            _failed = true;
            return;
        }
        _buffer[_position++] = 0;
    }
    WriteU16(_buffer + _extensionHeaderOffset + 2, (uint16_t)((_position - _extensionHeaderOffset - 4) / 4));
}

uint8_t *RtpPacketWriter::payload() {
    sealExtensions();
    return _failed ? 0 : _buffer + _position;
}

size_t RtpPacketWriter::payloadCapacity() {
    sealExtensions();
    return _failed || _position > _capacity ? 0 : _capacity - _position;
}

size_t RtpPacketWriter::finish(size_t payloadSize) {
    sealExtensions();
    if (_failed || _position + payloadSize > _capacity) {
        _failed = true;
        return 0;
    }
    return _position + payloadSize;
}

void WriteTransportSequenceNumber(uint8_t *packet, size_t offset, uint16_t value) {
    WriteU16(packet + offset, value);
}

void WriteAbsSendTime(uint8_t *packet, size_t offset, int64_t sendTimeMicros) {
    const uint64_t value = (((uint64_t)sendTimeMicros << 18) / 1000000ULL) & 0x00FFFFFFULL;
    WriteU24(packet + offset, (uint32_t)value);
}

}
}
