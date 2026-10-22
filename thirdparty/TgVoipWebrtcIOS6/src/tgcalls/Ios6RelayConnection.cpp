#include "Ios6RelayConnection.h"

#include <arpa/inet.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

namespace tgcalls {
namespace {

static uint16_t Read16(const uint8_t *p) { return static_cast<uint16_t>((p[0] << 8) | p[1]); }
static uint32_t Read32(const uint8_t *p) { return (static_cast<uint32_t>(p[0]) << 24) | (static_cast<uint32_t>(p[1]) << 16) | (static_cast<uint32_t>(p[2]) << 8) | p[3]; }
static uint32_t ReadLE32(const uint8_t *p) { return (static_cast<uint32_t>(p[3]) << 24) | (static_cast<uint32_t>(p[2]) << 16) | (static_cast<uint32_t>(p[1]) << 8) | p[0]; }
static void Append16(std::vector<uint8_t> &out, uint16_t value) { out.push_back(value >> 8); out.push_back(value & 255); }
static void Append32(std::vector<uint8_t> &out, uint32_t value) { for (int i = 3; i >= 0; --i) out.push_back(static_cast<uint8_t>(value >> (i * 8))); }
static void AppendLE32(std::vector<uint8_t> &out, uint32_t value) { for (int i = 0; i < 4; ++i) out.push_back(static_cast<uint8_t>(value >> (i * 8))); }
static int HexDigit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}
static std::string CandidateHost(uint8_t serverId, uint32_t tag) {
    char host[80];
    snprintf(host, sizeof(host), "reflector-%u-%u.reflector", static_cast<unsigned int>(serverId), static_cast<unsigned int>(tag));
    return host;
}

}

Ios6RelayConnection::Ios6RelayConnection(std::shared_ptr<Ios6TurnSocket> socket) : _socket(socket) { memset(_peerTag.data(), 0, _peerTag.size()); }
std::shared_ptr<Ios6RelayConnection> Ios6RelayConnection::turn(std::shared_ptr<Ios6TurnSocket> socket) {
    return std::shared_ptr<Ios6RelayConnection>(new Ios6RelayConnection(socket));
}
std::shared_ptr<Ios6RelayConnection> Ios6RelayConnection::reflector(std::shared_ptr<Ios6TurnSocket> socket, uint8_t serverId, const std::string &serverHost, uint16_t serverPort, const std::string &peerTag, uint32_t localTag, std::string *error) {
    if (!socket || serverId == 0 || serverPort == 0 || peerTag.size() != 32 || localTag == 0) {
        if (error != NULL) *error = "Invalid Telegram reflector parameters";
        return std::shared_ptr<Ios6RelayConnection>();
    }
    std::shared_ptr<Ios6RelayConnection> result(new Ios6RelayConnection(socket));
    for (size_t i = 0; i < 16; ++i) {
        const int high = HexDigit(peerTag[i * 2]);
        const int low = HexDigit(peerTag[i * 2 + 1]);
        if (high < 0 || low < 0) {
            if (error != NULL) *error = "Invalid Telegram reflector peer tag";
            return std::shared_ptr<Ios6RelayConnection>();
        }
        result->_peerTag[i] = static_cast<uint8_t>((high << 4) | low);
    }
    for (unsigned int i = 0; i < 4; ++i) result->_peerTag[12 + i] = static_cast<uint8_t>(localTag >> (8 * i));
    result->_reflector = true;
    result->_serverId = serverId;
    result->_serverHost = serverHost;
    result->_serverPort = serverPort;
    result->_localTag = localTag;
    return result;
}
Ios6TurnSocket &Ios6RelayConnection::socket() const { return *_socket; }
bool Ios6RelayConnection::isReflector() const { return _reflector; }
std::string Ios6RelayConnection::localHost() const { return CandidateHost(_serverId, _localTag); }
uint16_t Ios6RelayConnection::localPort() const { return _serverPort; }
std::string Ios6RelayConnection::mappedHost(const std::string &peerHost) const { return _reflector ? _serverHost : peerHost; }

bool Ios6RelayConnection::parsePeer(const std::string &host, uint16_t port, uint32_t *tag) const {
    const std::string prefix = "reflector-" + std::to_string(static_cast<unsigned int>(_serverId)) + "-";
    const std::string suffix = ".reflector";
    if (port != _serverPort || host.size() <= prefix.size() + suffix.size() || host.compare(0, prefix.size(), prefix) != 0 || host.compare(host.size() - suffix.size(), suffix.size(), suffix) != 0)
        return false;
    const std::string number = host.substr(prefix.size(), host.size() - prefix.size() - suffix.size());
    uint64_t value = 0;
    for (size_t i = 0; i < number.size(); ++i) {
        if (number[i] < '0' || number[i] > '9') return false;
        value = value * 10 + static_cast<unsigned int>(number[i] - '0');
        if (value > UINT32_MAX) return false;
    }
    if (value == 0) return false;
    if (tag != NULL) *tag = static_cast<uint32_t>(value);
    return true;
}
bool Ios6RelayConnection::acceptsPeer(const std::string &host, uint16_t port) const {
    if (_reflector) return parsePeer(host, port, NULL);
    struct in_addr address;
    return port != 0 && inet_pton(AF_INET, host.c_str(), &address) == 1;
}
std::vector<uint8_t> Ios6RelayConnection::encodePacket(const std::string &host, uint16_t port, const std::vector<uint8_t> &data) const {
    std::vector<uint8_t> result;
    if (!acceptsPeer(host, port) || data.size() > 65000) return result;
    if (_reflector) {
        uint32_t tag = 0;
        if (!parsePeer(host, port, &tag)) return result;
        result.insert(result.end(), _peerTag.begin(), _peerTag.begin() + 12);
        AppendLE32(result, tag);
        AppendLE32(result, _localTag);
        Append32(result, static_cast<uint32_t>(data.size()));
        result.insert(result.end(), data.begin(), data.end());
    } else {
        Append16(result, 0x0016);
        Append16(result, 0);
        Append32(result, 0x2112a442);
        for (int i = 0; i < 3; ++i) Append32(result, arc4random());
        Append16(result, 0x0012);
        Append16(result, 8);
        Append16(result, 1);
        Append16(result, port ^ 0x2112);
        struct in_addr address;
        if (inet_pton(AF_INET, host.c_str(), &address) != 1) return std::vector<uint8_t>();
        Append32(result, ntohl(address.s_addr) ^ 0x2112a442);
        Append16(result, 0x0013);
        Append16(result, static_cast<uint16_t>(data.size()));
        result.insert(result.end(), data.begin(), data.end());
    }
    while (result.size() % 4 != 0) result.push_back(0);
    if (!_reflector) {
        result[2] = static_cast<uint8_t>((result.size() - 20) >> 8);
        result[3] = static_cast<uint8_t>((result.size() - 20) & 255);
    }
    return result;
}
bool Ios6RelayConnection::decodePacket(const uint8_t *packet, size_t size, std::string *host, uint16_t *port, const uint8_t **data, size_t *dataSize) const {
    if (packet == NULL) return false;
    if (_reflector) {
        if (size < 24 || memcmp(packet, _peerTag.data(), 12) != 0) return false;
        if (size >= 28) {
            static const uint8_t special[] = {255,255,255,255,255,255,255,255,255,255,255,255};
            if (memcmp(packet + 16, special, sizeof(special)) == 0) return false;
        }
        const uint32_t tag = ReadLE32(packet + 16);
        const size_t length = Read32(packet + 20);
        if (tag == 0 || length > size - 24) return false;
        *host = CandidateHost(_serverId, tag);
        *port = _serverPort;
        *data = packet + 24;
        *dataSize = length;
        return true;
    }
    if (size < 20 || Read16(packet) != 0x0017 || Read32(packet + 4) != 0x2112a442) return false;
    const size_t end = 20 + Read16(packet + 2);
    if (end > size) return false;
    bool hasPeer = false;
    bool hasData = false;
    for (size_t offset = 20; offset + 4 <= end;) {
        const uint16_t type = Read16(packet + offset);
        const size_t length = Read16(packet + offset + 2);
        offset += 4;
        if (length > end - offset) return false;
        if (type == 0x0012 && length == 8 && packet[offset + 1] == 1) {
            struct in_addr address;
            address.s_addr = htonl(Read32(packet + offset + 4) ^ 0x2112a442);
            char ip[INET_ADDRSTRLEN];
            if (inet_ntop(AF_INET, &address, ip, sizeof(ip)) == NULL) return false;
            *host = ip;
            *port = Read16(packet + offset + 2) ^ 0x2112;
            hasPeer = *port != 0;
        } else if (type == 0x0013) {
            *data = packet + offset;
            *dataSize = length;
            hasData = true;
        }
        offset += (length + 3) & ~static_cast<size_t>(3);
        if (offset > end) return false;
    }
    return hasPeer && hasData;
}
bool Ios6RelayConnection::sendHello(std::string *error) const {
    if (!_reflector) return true;
    std::vector<uint8_t> packet(_peerTag.begin(), _peerTag.end());
    if (_socket->isTcp()) {
        Append32(packet, 0);
    } else {
        packet.insert(packet.end(), 12, 255);
        packet.push_back(254);
        packet.insert(packet.end(), 3, 255);
        Append32(packet, 0);
        Append32(packet, 123);
    }
    if (_socket->sendPacket(packet.data(), packet.size()) != static_cast<ssize_t>(packet.size())) {
        if (error != NULL) *error = strerror(errno);
        return false;
    }
    return true;
}
bool Ios6RelayConnection::probe(std::string *error) const {
    for (int attempt = 0; attempt < 3; ++attempt) {
        if (!sendHello(error)) return false;
        if (_socket->isTcp()) return true;
        uint8_t packet[4096];
        const ssize_t received = _socket->receivePacket(packet, sizeof(packet), 500);
        if (received >= 16 && memcmp(packet, _peerTag.data(), 12) == 0) return true;
        if (received < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
            if (error != NULL) *error = strerror(errno);
            return false;
        }
    }
    if (error != NULL) *error = "Telegram reflector response timeout";
    return false;
}

}
