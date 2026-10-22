#ifndef TGCALLS_IOS6_RELAY_CONNECTION_H
#define TGCALLS_IOS6_RELAY_CONNECTION_H

#include "Ios6TurnSocket.h"
#include <array>

namespace tgcalls {

class Ios6RelayConnection {
public:
    static std::shared_ptr<Ios6RelayConnection> turn(std::shared_ptr<Ios6TurnSocket> socket);
    static std::shared_ptr<Ios6RelayConnection> reflector(std::shared_ptr<Ios6TurnSocket> socket, uint8_t serverId, const std::string &serverHost, uint16_t serverPort, const std::string &peerTag, uint32_t localTag, std::string *error);
    Ios6TurnSocket &socket() const;
    bool isReflector() const;
    std::string localHost() const;
    uint16_t localPort() const;
    std::string mappedHost(const std::string &peerHost) const;
    bool acceptsPeer(const std::string &host, uint16_t port) const;
    std::vector<uint8_t> encodePacket(const std::string &host, uint16_t port, const std::vector<uint8_t> &data) const;
    bool decodePacket(const uint8_t *packet, size_t size, std::string *host, uint16_t *port, const uint8_t **data, size_t *dataSize) const;
    bool sendHello(std::string *error) const;
    bool probe(std::string *error) const;

private:
    explicit Ios6RelayConnection(std::shared_ptr<Ios6TurnSocket> socket);
    bool parsePeer(const std::string &host, uint16_t port, uint32_t *tag) const;
    std::shared_ptr<Ios6TurnSocket> _socket;
    bool _reflector = false;
    uint8_t _serverId = 0;
    std::string _serverHost;
    uint16_t _serverPort = 0;
    std::array<uint8_t, 16> _peerTag;
    uint32_t _localTag = 0;
};

}

#endif
