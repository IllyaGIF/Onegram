#ifndef TGCALLS_IOS6_TURN_CLIENT_H
#define TGCALLS_IOS6_TURN_CLIENT_H

#include "Instance.h"

#include <stdint.h>
#include <string>
#include <vector>

namespace tgcalls {

struct Ios6TurnProbeResult {
    bool ok;
    int errorCode;

    std::string error;
    std::string realm;
    std::string nonce;

    std::string relayHost;
    uint16_t relayPort;
    uint32_t lifetimeSeconds;

    Ios6TurnProbeResult()
    : ok(false),
      errorCode(0),
      relayPort(0),
      lifetimeSeconds(0) {
    }
};

Ios6TurnProbeResult Ios6TurnAllocateProbe(
    const RtcServer &server,
    bool keepSocket = false,
    int *outSocketFd = 0
);

bool Ios6TurnRefreshAllocationNoWait(
    int fd,
    const RtcServer &server,
    const std::string &realm,
    const std::string &nonce,
    uint32_t requestedLifetimeSeconds,
    std::string *error
);

bool Ios6TurnRefreshPermissionNoWait(
    int fd,
    const RtcServer &server,
    const std::string &realm,
    const std::string &nonce,
    const std::string &peerHost,
    uint16_t peerPort,
    std::string *error
);

bool Ios6TurnCreatePermission(
    int fd,
    const RtcServer &server,
    const std::string &realm,
    std::string *nonce,
    const std::string &peerHost,
    uint16_t peerPort,
    std::string *error
);



struct Ios6TurnReceiveResult {
    enum Kind {
        KindNone = 0,
        KindTransport = 1,
        KindInnerStun = 2,
        KindOther = 3
    };

    Kind kind;
    bool timeout;

    std::string error;
    std::string peerHost;
    uint16_t peerPort;

    uint16_t innerStunType;

    std::vector<uint8_t> data;

    Ios6TurnReceiveResult()
    : kind(KindNone),
      timeout(false),
      peerPort(0),
      innerStunType(0) {
    }
};

Ios6TurnReceiveResult Ios6TurnReceivePacket(
    int fd,
    const std::string &selectedPeerHost,
    uint16_t selectedPeerPort,
    const std::string &localUfrag,
    const std::string &localPassword,
    const std::string &remoteUfrag
);

bool Ios6TurnSendData(
    int fd,
    const std::string &peerHost,
    uint16_t peerPort,
    const uint8_t *data,
    size_t size,
    std::string *error
);

bool Ios6TurnIceBindingProbe(
    int fd,
    const std::string &peerHost,
    uint16_t peerPort,
    const std::string &localUfrag,
    const std::string &localPassword,
    const std::string &remoteUfrag,
    const std::string &remotePassword,
    uint64_t tieBreaker,
    bool controlling,
    bool useCandidate,
    std::string *selectedPeerHost,
    uint16_t *selectedPeerPort,
    std::string *error
);

}

#endif
