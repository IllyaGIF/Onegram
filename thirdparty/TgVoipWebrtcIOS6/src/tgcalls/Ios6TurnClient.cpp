#include "Ios6TurnClient.h"

#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonHMAC.h>

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <syslog.h>
#include <unistd.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <string>
#include <vector>

#include "Ios6DiagnosticLog.h"

namespace tgcalls {

namespace {

static const uint32_t kStunMagicCookie = 0x2112A442U;

static const uint16_t kTurnAllocateRequest = 0x0003;
static const uint16_t kTurnAllocateSuccess = 0x0103;
static const uint16_t kTurnAllocateError = 0x0113;

static const uint16_t kTurnRefreshRequest = 0x0004;
static const uint16_t kTurnRefreshSuccess = 0x0104;
static const uint16_t kTurnRefreshError = 0x0114;

static const uint16_t kTurnCreatePermissionRequest = 0x0008;
static const uint16_t kTurnCreatePermissionSuccess = 0x0108;
static const uint16_t kTurnCreatePermissionError = 0x0118;

static const uint16_t kAttrXorPeerAddress = 0x0012;

static const uint16_t kAttrUsername = 0x0006;
static const uint16_t kAttrMessageIntegrity = 0x0008;
static const uint16_t kAttrErrorCode = 0x0009;
static const uint16_t kAttrLifetime = 0x000D;
static const uint16_t kAttrRealm = 0x0014;
static const uint16_t kAttrNonce = 0x0015;
static const uint16_t kAttrXorRelayedAddress = 0x0016;
static const uint16_t kAttrRequestedTransport = 0x0019;

static uint16_t ReadU16(const uint8_t *p) {
    return (uint16_t)(((uint16_t)p[0] << 8) |
                      ((uint16_t)p[1]));
}

static uint32_t ReadU32(const uint8_t *p) {
    return
        ((uint32_t)p[0] << 24) |
        ((uint32_t)p[1] << 16) |
        ((uint32_t)p[2] << 8) |
        ((uint32_t)p[3]);
}

static void AppendU16(std::vector<uint8_t> &out, uint16_t value) {
    out.push_back((uint8_t)((value >> 8) & 0xff));
    out.push_back((uint8_t)(value & 0xff));
}

static void AppendU32(std::vector<uint8_t> &out, uint32_t value) {
    out.push_back((uint8_t)((value >> 24) & 0xff));
    out.push_back((uint8_t)((value >> 16) & 0xff));
    out.push_back((uint8_t)((value >> 8) & 0xff));
    out.push_back((uint8_t)(value & 0xff));
}

static void SetU16(std::vector<uint8_t> &out, size_t offset, uint16_t value) {
    if (offset + 1 >= out.size()) {
        return;
    }

    out[offset] = (uint8_t)((value >> 8) & 0xff);
    out[offset + 1] = (uint8_t)(value & 0xff);
}

static void MakeTransactionId(uint8_t txid[12]) {
    uint32_t a = arc4random();
    uint32_t b = arc4random();
    uint32_t c = arc4random();

    memcpy(txid + 0, &a, 4);
    memcpy(txid + 4, &b, 4);
    memcpy(txid + 8, &c, 4);
}

static std::vector<uint8_t> MakeMessage(
    uint16_t type,
    const uint8_t txid[12]
) {
    std::vector<uint8_t> result;

    result.reserve(512);

    AppendU16(result, type);
    AppendU16(result, 0);
    AppendU32(result, kStunMagicCookie);

    result.insert(
        result.end(),
        txid,
        txid + 12
    );

    return result;
}

static void UpdateMessageLength(std::vector<uint8_t> &message) {
    if (message.size() < 20) {
        return;
    }

    const size_t payloadSize = message.size() - 20;

    SetU16(
        message,
        2,
        (uint16_t)payloadSize
    );
}

static void AddAttribute(
    std::vector<uint8_t> &message,
    uint16_t type,
    const void *data,
    size_t size
) {
    AppendU16(message, type);
    AppendU16(message, (uint16_t)size);

    const uint8_t *bytes =
        reinterpret_cast<const uint8_t *>(data);

    if (bytes != NULL && size != 0) {
        message.insert(
            message.end(),
            bytes,
            bytes + size
        );
    }

    while ((message.size() & 3) != 0) {
        message.push_back(0);
    }
}

static void AddStringAttribute(
    std::vector<uint8_t> &message,
    uint16_t type,
    const std::string &value
) {
    AddAttribute(
        message,
        type,
        value.data(),
        value.size()
    );
}

static bool FindAttribute(
    const std::vector<uint8_t> &message,
    uint16_t wantedType,
    std::vector<uint8_t> *value
) {
    if (message.size() < 20) {
        return false;
    }

    const size_t declaredLength = ReadU16(&message[2]);

    if (20 + declaredLength > message.size()) {
        return false;
    }

    size_t offset = 20;
    const size_t end = 20 + declaredLength;

    while (offset + 4 <= end) {
        const uint16_t type =
            ReadU16(&message[offset]);

        const uint16_t length =
            ReadU16(&message[offset + 2]);

        offset += 4;

        if (offset + length > end) {
            return false;
        }

        if (type == wantedType) {
            if (value != NULL) {
                value->assign(
                    message.begin() + offset,
                    message.begin() + offset + length
                );
            }

            return true;
        }

        offset += length;
        offset = (offset + 3) & ~(size_t)3;
    }

    return false;
}

static std::string AttributeToString(
    const std::vector<uint8_t> &value
) {
    if (value.empty()) {
        return std::string();
    }

    return std::string(
        reinterpret_cast<const char *>(&value[0]),
        value.size()
    );
}

static int ParseErrorCode(const std::vector<uint8_t> &message) {
    std::vector<uint8_t> value;

    if (!FindAttribute(
            message,
            kAttrErrorCode,
            &value
        )) {
        return 0;
    }

    if (value.size() < 4) {
        return 0;
    }

    const int errorClass = value[2] & 0x07;
    const int errorNumber = value[3];

    return errorClass * 100 + errorNumber;
}

static uint32_t ParseLifetimeSeconds(
    const std::vector<uint8_t> &message
) {
    std::vector<uint8_t> value;

    if (!FindAttribute(message, kAttrLifetime, &value) ||
        value.size() < 4) {
        return 0;
    }

    return ReadU32(&value[0]);
}

static bool ParseXorRelayedAddress(
    const std::vector<uint8_t> &message,
    std::string *host,
    uint16_t *port
) {
    std::vector<uint8_t> value;

    if (!FindAttribute(
            message,
            kAttrXorRelayedAddress,
            &value
        )) {
        return false;
    }

    if (value.size() < 8) {
        return false;
    }

    if (value[1] != 0x01) {
        return false;
    }

    const uint16_t xPort =
        ReadU16(&value[2]);

    const uint16_t decodedPort =
        (uint16_t)(xPort ^ 0x2112U);

    const uint32_t xAddress =
        ReadU32(&value[4]);

    const uint32_t decodedAddress =
        xAddress ^ kStunMagicCookie;

    struct in_addr address;
    address.s_addr = htonl(decodedAddress);

    char buffer[INET_ADDRSTRLEN];
    memset(buffer, 0, sizeof(buffer));

    if (inet_ntop(
            AF_INET,
            &address,
            buffer,
            sizeof(buffer)
        ) == NULL) {
        return false;
    }

    if (host != NULL) {
        *host = buffer;
    }

    if (port != NULL) {
        *port = decodedPort;
    }

    return true;
}

static std::vector<uint8_t> MakeAllocateRequest(
    const uint8_t txid[12]
) {
    std::vector<uint8_t> message =
        MakeMessage(
            kTurnAllocateRequest,
            txid
        );

    const uint8_t requestedTransport[4] = {
        17, 0, 0, 0
    };

    AddAttribute(
        message,
        kAttrRequestedTransport,
        requestedTransport,
        sizeof(requestedTransport)
    );

    UpdateMessageLength(message);

    return message;
}

static void MakeLongTermKey(
    const std::string &username,
    const std::string &realm,
    const std::string &password,
    uint8_t key[CC_MD5_DIGEST_LENGTH]
) {
    const std::string a1 =
        username + ":" +
        realm + ":" +
        password;

    CC_MD5(
        a1.data(),
        (CC_LONG)a1.size(),
        key
    );
}

static std::vector<uint8_t> MakeAuthenticatedAllocateRequest(
    const uint8_t txid[12],
    const std::string &username,
    const std::string &password,
    const std::string &realm,
    const std::string &nonce
) {
    std::vector<uint8_t> message =
        MakeMessage(
            kTurnAllocateRequest,
            txid
        );

    AddStringAttribute(
        message,
        kAttrUsername,
        username
    );

    AddStringAttribute(
        message,
        kAttrRealm,
        realm
    );

    AddStringAttribute(
        message,
        kAttrNonce,
        nonce
    );

    const uint8_t requestedTransport[4] = {
        17, 0, 0, 0
    };

    AddAttribute(
        message,
        kAttrRequestedTransport,
        requestedTransport,
        sizeof(requestedTransport)
    );

    const size_t lengthWithIntegrity =
        (message.size() - 20) + 24;

    SetU16(
        message,
        2,
        (uint16_t)lengthWithIntegrity
    );

    uint8_t key[CC_MD5_DIGEST_LENGTH];

    MakeLongTermKey(
        username,
        realm,
        password,
        key
    );

    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CCHmac(
        kCCHmacAlgSHA1,
        key,
        sizeof(key),
        &message[0],
        message.size(),
        digest
    );

    AddAttribute(
        message,
        kAttrMessageIntegrity,
        digest,
        sizeof(digest)
    );

    UpdateMessageLength(message);

    return message;
}

static bool OpenConnectedUdpSocket(
    const std::string &host,
    uint16_t port,
    int *fdOut,
    std::string *error
) {
    char portString[16];
    snprintf(
        portString,
        sizeof(portString),
        "%u",
        (unsigned int)port
    );

    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));

    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = IPPROTO_UDP;

    struct addrinfo *result = NULL;

    const int gaiResult =
        getaddrinfo(
            host.c_str(),
            portString,
            &hints,
            &result
        );

    if (gaiResult != 0 || result == NULL) {
        if (error != NULL) {
            *error = "getaddrinfo failed";
        }

        if (result != NULL) {
            freeaddrinfo(result);
        }

        return false;
    }

    int fd = socket(
        result->ai_family,
        result->ai_socktype,
        result->ai_protocol
    );

    if (fd < 0) {
        if (error != NULL) {
            *error = strerror(errno);
        }

        freeaddrinfo(result);
        return false;
    }

    struct timeval timeout;
    timeout.tv_sec = 3;
    timeout.tv_usec = 0;

    setsockopt(
        fd,
        SOL_SOCKET,
        SO_RCVTIMEO,
        &timeout,
        sizeof(timeout)
    );

    setsockopt(
        fd,
        SOL_SOCKET,
        SO_SNDTIMEO,
        &timeout,
        sizeof(timeout)
    );

    if (connect(
            fd,
            result->ai_addr,
            result->ai_addrlen
        ) != 0) {
        if (error != NULL) {
            *error = strerror(errno);
        }

        close(fd);
        freeaddrinfo(result);
        return false;
    }

    freeaddrinfo(result);

    *fdOut = fd;
    return true;
}

static bool SendAndReceive(
    int fd,
    const std::vector<uint8_t> &request,
    const uint8_t expectedTxid[12],
    std::vector<uint8_t> *response,
    std::string *error
) {
    if (response == NULL) {
        if (error != NULL) {
            *error = "response pointer is null";
        }

        return false;
    }

    for (int sendAttempt = 0;
         sendAttempt < 3;
         ++sendAttempt) {

        if (sendAttempt != 0) {
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.tx.retry attempt=%d bytes=%lu",
                sendAttempt + 1,
                (unsigned long)request.size()
            );
        }

        ssize_t sent;

        do {
            sent = send(
                fd,
                request.empty() ? NULL : &request[0],
                request.size(),
                0
            );
        } while (sent < 0 && errno == EINTR);

        if (sent < 0) {
            if (error != NULL) {
                *error = strerror(errno);
            }

            return false;
        }

        if ((size_t)sent != request.size()) {
            if (error != NULL) {
                *error = "short TURN send";
            }

            return false;
        }

        for (int receiveAttempt = 0;
             receiveAttempt < 8;
             ++receiveAttempt) {

            uint8_t buffer[4096];

            ssize_t received;

            do {
                received = recv(
                    fd,
                    buffer,
                    sizeof(buffer),
                    0
                );
            } while (received < 0 && errno == EINTR);

            if (received < 0) {
                if (errno == EAGAIN ||
                    errno == EWOULDBLOCK) {

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC turn.rx.timeout sendAttempt=%d",
                        sendAttempt + 1
                    );

                    break;
                }

                if (error != NULL) {
                    *error = strerror(errno);
                }

                return false;
            }

            if (received < 20) {
                continue;
            }

            if (ReadU32(buffer + 4) !=
                kStunMagicCookie) {
                continue;
            }

            if (memcmp(
                    buffer + 8,
                    expectedTxid,
                    12
                ) != 0) {

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC turn.rx.otherTransaction bytes=%ld",
                    (long)received
                );

                continue;
            }

            const uint16_t declaredLength =
                ReadU16(buffer + 2);

            if ((size_t)received <
                20 + declaredLength) {
                continue;
            }

            response->assign(
                buffer,
                buffer + received
            );

            return true;
        }
    }

    if (error != NULL) {
        *error = "TURN response timeout after retries";
    }

    return false;
}

static void LogLocalSocket(int fd) {
    struct sockaddr_in localAddress;
    socklen_t localLength =
        sizeof(localAddress);

    memset(
        &localAddress,
        0,
        sizeof(localAddress)
    );

    if (getsockname(
            fd,
            reinterpret_cast<struct sockaddr *>(&localAddress),
            &localLength
        ) != 0) {
        return;
    }

    char ip[INET_ADDRSTRLEN];
    memset(ip, 0, sizeof(ip));

    if (inet_ntop(
            AF_INET,
            &localAddress.sin_addr,
            ip,
            sizeof(ip)
        ) == NULL) {
        return;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC turn.socket.local ip=%s port=%u",
        ip,
        (unsigned int)ntohs(localAddress.sin_port)
    );
}


static bool MakeXorPeerAddress(
    const std::string &host,
    uint16_t port,
    uint8_t value[8]
) {
    struct in_addr address;

    memset(&address, 0, sizeof(address));

    if (inet_pton(
            AF_INET,
            host.c_str(),
            &address
        ) != 1) {
        return false;
    }

    const uint16_t xorPort =
        (uint16_t)(port ^ (uint16_t)(kStunMagicCookie >> 16));

    const uint32_t ip =
        ntohl(address.s_addr);

    const uint32_t xorIp =
        ip ^ kStunMagicCookie;

    value[0] = 0;
    value[1] = 0x01;

    value[2] = (uint8_t)((xorPort >> 8) & 0xff);
    value[3] = (uint8_t)(xorPort & 0xff);

    value[4] = (uint8_t)((xorIp >> 24) & 0xff);
    value[5] = (uint8_t)((xorIp >> 16) & 0xff);
    value[6] = (uint8_t)((xorIp >> 8) & 0xff);
    value[7] = (uint8_t)(xorIp & 0xff);

    return true;
}

static void AddLongTermMessageIntegrity(
    std::vector<uint8_t> &message,
    const std::string &username,
    const std::string &password,
    const std::string &realm
) {
    const std::string keyInput =
        username + ":" + realm + ":" + password;

    uint8_t key[CC_MD5_DIGEST_LENGTH];

    CC_MD5(
        keyInput.data(),
        (CC_LONG)keyInput.size(),
        key
    );

    std::vector<uint8_t> hmacInput = message;

    const size_t payloadWithIntegrity =
        (hmacInput.size() - 20) +
        4 +
        CC_SHA1_DIGEST_LENGTH;

    SetU16(
        hmacInput,
        2,
        (uint16_t)payloadWithIntegrity
    );

    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CCHmac(
        kCCHmacAlgSHA1,
        key,
        sizeof(key),
        hmacInput.empty() ? NULL : &hmacInput[0],
        hmacInput.size(),
        digest
    );

    AddAttribute(
        message,
        kAttrMessageIntegrity,
        digest,
        sizeof(digest)
    );

    UpdateMessageLength(message);
}

static std::vector<uint8_t> MakeRefreshRequest(
    const uint8_t txid[12],
    const RtcServer &server,
    const std::string &realm,
    const std::string &nonce,
    uint32_t requestedLifetimeSeconds
) {
    std::vector<uint8_t> request =
        MakeMessage(kTurnRefreshRequest, txid);

    AddStringAttribute(request, kAttrUsername, server.login);
    AddStringAttribute(request, kAttrRealm, realm);
    AddStringAttribute(request, kAttrNonce, nonce);

    uint8_t lifetime[4];
    lifetime[0] = (uint8_t)((requestedLifetimeSeconds >> 24) & 0xff);
    lifetime[1] = (uint8_t)((requestedLifetimeSeconds >> 16) & 0xff);
    lifetime[2] = (uint8_t)((requestedLifetimeSeconds >> 8) & 0xff);
    lifetime[3] = (uint8_t)(requestedLifetimeSeconds & 0xff);
    AddAttribute(request, kAttrLifetime, lifetime, sizeof(lifetime));

    AddLongTermMessageIntegrity(
        request, server.login, server.password, realm);

    return request;
}

static std::vector<uint8_t> MakeCreatePermissionRequest(
    const uint8_t txid[12],
    const RtcServer &server,
    const std::string &realm,
    const std::string &nonce,
    const std::string &peerHost,
    uint16_t peerPort
) {
    std::vector<uint8_t> request =
        MakeMessage(
            kTurnCreatePermissionRequest,
            txid
        );

    AddStringAttribute(
        request,
        kAttrUsername,
        server.login
    );

    AddStringAttribute(
        request,
        kAttrRealm,
        realm
    );

    AddStringAttribute(
        request,
        kAttrNonce,
        nonce
    );

    uint8_t peerAddress[8];

    memset(
        peerAddress,
        0,
        sizeof(peerAddress)
    );

    if (MakeXorPeerAddress(
            peerHost,
            peerPort,
            peerAddress
        )) {
        AddAttribute(
            request,
            kAttrXorPeerAddress,
            peerAddress,
            sizeof(peerAddress)
        );
    }

    AddLongTermMessageIntegrity(
        request,
        server.login,
        server.password,
        realm
    );

    return request;
}


}

Ios6TurnProbeResult Ios6TurnAllocateProbe(
    const RtcServer &server,
    bool keepSocket,
    int *outSocketFd
) {
    Ios6TurnProbeResult result;

    if (outSocketFd != NULL) {
        *outSocketFd = -1;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC turn.probe.begin id=%u host=%s port=%u login=%s passLen=%lu tcp=%d",
        (unsigned int)server.id,
        server.host.c_str(),
        (unsigned int)server.port,
        server.login.c_str(),
        (unsigned long)server.password.size(),
        server.isTcp ? 1 : 0
    );

    if (!server.isTurn) {
        result.error = "server is not TURN";
        return result;
    }

    if (server.isTcp) {
        result.error = "TCP TURN not supported by probe";
        return result;
    }

    if (server.login == "reflector") {
        result.error = "custom reflector endpoint";
        return result;
    }

    int fd = -1;

    if (!OpenConnectedUdpSocket(
            server.host,
            server.port,
            &fd,
            &result.error
        )) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.socket.fail error=%s",
            result.error.c_str()
        );

        return result;
    }

    LogLocalSocket(fd);

    uint8_t tx1[12];
    MakeTransactionId(tx1);

    std::vector<uint8_t> request1 =
        MakeAllocateRequest(tx1);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC turn.allocate.initial.send bytes=%lu",
        (unsigned long)request1.size()
    );

    std::vector<uint8_t> response1;

    if (!SendAndReceive(
            fd,
            request1,
            tx1,
            &response1,
            &result.error
        )) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.allocate.initial.fail error=%s",
            result.error.c_str()
        );

        close(fd);
        return result;
    }

    const uint16_t responseType1 =
        ReadU16(&response1[0]);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC turn.allocate.initial.response type=0x%04x bytes=%lu",
        (unsigned int)responseType1,
        (unsigned long)response1.size()
    );

    if (responseType1 == kTurnAllocateSuccess) {
        if (ParseXorRelayedAddress(
                response1,
                &result.relayHost,
                &result.relayPort
            )) {
            result.ok = true;
            result.lifetimeSeconds = ParseLifetimeSeconds(response1);

            syslog(
                LOG_NOTICE,
                "IOS6LAT turn.allocate lifetime=%u auth=0",
                (unsigned int)result.lifetimeSeconds
            );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.allocate.success relay=%s:%u auth=0",
                result.relayHost.c_str(),
                (unsigned int)result.relayPort
            );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.allocate.postsuccess keep=%d fd=%d outNull=%d",
                keepSocket ? 1 : 0,
                fd,
                outSocketFd == NULL ? 1 : 0
            );

            if (keepSocket) {
                if (outSocketFd != NULL) {
                    *outSocketFd = fd;
                }

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC turn.socket.keep fd=%d",
                    fd
                );
            }
        } else {
            result.error =
                "success without IPv4 XOR-RELAYED-ADDRESS";
        }

        if (!keepSocket || !result.ok) {
            close(fd);
        }

        return result;
    }

    if (responseType1 != kTurnAllocateError) {
        result.error =
            "unexpected initial TURN response";

        close(fd);
        return result;
    }

    result.errorCode =
        ParseErrorCode(response1);

    std::vector<uint8_t> realmBytes;
    std::vector<uint8_t> nonceBytes;

    FindAttribute(
        response1,
        kAttrRealm,
        &realmBytes
    );

    FindAttribute(
        response1,
        kAttrNonce,
        &nonceBytes
    );

    result.realm =
        AttributeToString(realmBytes);

    result.nonce =
        AttributeToString(nonceBytes);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC turn.allocate.challenge code=%d realmLen=%lu nonceLen=%lu",
        result.errorCode,
        (unsigned long)result.realm.size(),
        (unsigned long)result.nonce.size()
    );

    if (result.errorCode != 401) {
        result.error =
            "initial Allocate did not return 401";

        close(fd);
        return result;
    }

    if (result.realm.empty() ||
        result.nonce.empty()) {
        result.error =
            "401 missing REALM/NONCE";

        close(fd);
        return result;
    }

    for (int authAttempt = 0;
         authAttempt < 2;
         ++authAttempt) {
        uint8_t tx2[12];
        MakeTransactionId(tx2);

        std::vector<uint8_t> request2 =
            MakeAuthenticatedAllocateRequest(
                tx2,
                server.login,
                server.password,
                result.realm,
                result.nonce
            );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.allocate.auth.send attempt=%d bytes=%lu",
            authAttempt + 1,
            (unsigned long)request2.size()
        );

        std::vector<uint8_t> response2;

        if (!SendAndReceive(
                fd,
                request2,
                tx2,
                &response2,
                &result.error
            )) {
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.allocate.auth.fail attempt=%d error=%s",
                authAttempt + 1,
                result.error.c_str()
            );

            close(fd);
            return result;
        }

        const uint16_t responseType2 =
            ReadU16(&response2[0]);

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.allocate.auth.response attempt=%d type=0x%04x bytes=%lu",
            authAttempt + 1,
            (unsigned int)responseType2,
            (unsigned long)response2.size()
        );

        if (responseType2 ==
            kTurnAllocateSuccess) {
            if (!ParseXorRelayedAddress(
                    response2,
                    &result.relayHost,
                    &result.relayPort
                )) {
                result.error =
                    "Allocate success missing IPv4 XOR-RELAYED-ADDRESS";

                close(fd);
                return result;
            }

            result.ok = true;
            result.errorCode = 0;
            result.error.clear();
            result.lifetimeSeconds = ParseLifetimeSeconds(response2);

            syslog(
                LOG_NOTICE,
                "IOS6LAT turn.allocate lifetime=%u auth=1",
                (unsigned int)result.lifetimeSeconds
            );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.allocate.success relay=%s:%u auth=1",
                result.relayHost.c_str(),
                (unsigned int)result.relayPort
            );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.allocate.postsuccess keep=%d fd=%d outNull=%d",
                keepSocket ? 1 : 0,
                fd,
                outSocketFd == NULL ? 1 : 0
            );

            if (keepSocket) {
                if (outSocketFd != NULL) {
                    *outSocketFd = fd;
                }

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC turn.socket.keep fd=%d",
                    fd
                );
            } else {
                close(fd);
            }

            return result;
        }

        if (responseType2 !=
            kTurnAllocateError) {
            result.error =
                "unexpected authenticated TURN response";

            close(fd);
            return result;
        }

        const int errorCode =
            ParseErrorCode(response2);

        result.errorCode = errorCode;

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.allocate.auth.error attempt=%d code=%d",
            authAttempt + 1,
            errorCode
        );

        if (errorCode == 438 &&
            authAttempt == 0) {
            std::vector<uint8_t> newNonce;

            if (FindAttribute(
                    response2,
                    kAttrNonce,
                    &newNonce
                )) {
                result.nonce =
                    AttributeToString(newNonce);

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC turn.allocate.staleNonce newLen=%lu",
                    (unsigned long)result.nonce.size()
                );

                continue;
            }
        }

        result.error =
            "authenticated Allocate rejected";

        close(fd);
        return result;
    }

    result.error =
        "TURN Allocate attempts exhausted";

    close(fd);
    return result;
}



static const uint16_t kIos6StunBindingRequest = 0x0001;
static const uint16_t kIos6StunBindingSuccess = 0x0101;
static const uint16_t kIos6StunBindingError = 0x0111;

static const uint16_t kIos6TurnSendIndication = 0x0016;
static const uint16_t kIos6TurnDataIndication = 0x0017;

static const uint16_t kIos6AttrUsername = 0x0006;
static const uint16_t kIos6AttrMessageIntegrity = 0x0008;
static const uint16_t kIos6AttrErrorCode = 0x0009;
static const uint16_t kIos6AttrXorPeerAddress = 0x0012;
static const uint16_t kIos6AttrData = 0x0013;

static const uint16_t kIos6AttrXorMappedAddress = 0x0020;
static const uint16_t kIos6AttrPriority = 0x0024;
static const uint16_t kIos6AttrUseCandidate = 0x0025;
static const uint16_t kIos6AttrFingerprint = 0x8028;
static const uint16_t kIos6AttrIceControlled = 0x8029;
static const uint16_t kIos6AttrIceControlling = 0x802A;

static const uint32_t kIos6StunCookie = 0x2112A442U;


static uint16_t Ios6Read16(const uint8_t *p) {
    return (uint16_t)(
        ((uint16_t)p[0] << 8) |
        ((uint16_t)p[1])
    );
}


static uint32_t Ios6Read32(const uint8_t *p) {
    return
        ((uint32_t)p[0] << 24) |
        ((uint32_t)p[1] << 16) |
        ((uint32_t)p[2] << 8) |
        ((uint32_t)p[3]);
}


static void Ios6Write16(
    std::vector<uint8_t> *message,
    size_t offset,
    uint16_t value
) {
    (*message)[offset + 0] =
        (uint8_t)((value >> 8) & 0xff);

    (*message)[offset + 1] =
        (uint8_t)(value & 0xff);
}


static void Ios6Write32(
    std::vector<uint8_t> *message,
    size_t offset,
    uint32_t value
) {
    (*message)[offset + 0] =
        (uint8_t)((value >> 24) & 0xff);

    (*message)[offset + 1] =
        (uint8_t)((value >> 16) & 0xff);

    (*message)[offset + 2] =
        (uint8_t)((value >> 8) & 0xff);

    (*message)[offset + 3] =
        (uint8_t)(value & 0xff);
}


static void Ios6SetStunLength(
    std::vector<uint8_t> *message,
    size_t bodySize
) {
    Ios6Write16(
        message,
        2,
        (uint16_t)bodySize
    );
}


static std::vector<uint8_t> Ios6MakeStunHeader(
    uint16_t type,
    const uint8_t txid[12]
) {
    std::vector<uint8_t> result(20, 0);

    Ios6Write16(
        &result,
        0,
        type
    );

    Ios6Write32(
        &result,
        4,
        kIos6StunCookie
    );

    memcpy(
        &result[8],
        txid,
        12
    );

    return result;
}


static void Ios6AppendAttribute(
    std::vector<uint8_t> *message,
    uint16_t type,
    const void *value,
    size_t valueSize
) {
    message->push_back(
        (uint8_t)((type >> 8) & 0xff)
    );

    message->push_back(
        (uint8_t)(type & 0xff)
    );

    message->push_back(
        (uint8_t)((valueSize >> 8) & 0xff)
    );

    message->push_back(
        (uint8_t)(valueSize & 0xff)
    );

    if (valueSize != 0 &&
        value != NULL) {

        const uint8_t *bytes =
            reinterpret_cast<const uint8_t *>(value);

        message->insert(
            message->end(),
            bytes,
            bytes + valueSize
        );
    }

    while ((message->size() & 3) != 0) {
        message->push_back(0);
    }
}


static bool Ios6MakeXorPeerAddressValue(
    const std::string &peerHost,
    uint16_t peerPort,
    uint8_t value[8]
) {
    struct in_addr address;

    if (inet_pton(
            AF_INET,
            peerHost.c_str(),
            &address
        ) != 1) {

        return false;
    }

    value[0] = 0;
    value[1] = 1;

    const uint16_t xorPort =
        (uint16_t)(
            peerPort ^
            (uint16_t)(kIos6StunCookie >> 16)
        );

    value[2] =
        (uint8_t)((xorPort >> 8) & 0xff);

    value[3] =
        (uint8_t)(xorPort & 0xff);

    const uint8_t *addressBytes =
        reinterpret_cast<const uint8_t *>(
            &address.s_addr
        );

    value[4] =
        addressBytes[0] ^ 0x21;

    value[5] =
        addressBytes[1] ^ 0x12;

    value[6] =
        addressBytes[2] ^ 0xa4;

    value[7] =
        addressBytes[3] ^ 0x42;

    return true;
}


static uint32_t Ios6Crc32(
    const uint8_t *data,
    size_t size
) {
    uint32_t crc = 0xffffffffU;

    for (size_t i = 0;
         i < size;
         ++i) {

        crc ^= data[i];

        for (int bit = 0;
             bit < 8;
             ++bit) {

            if (crc & 1U) {
                crc =
                    (crc >> 1) ^
                    0xedb88320U;
            } else {
                crc >>= 1;
            }
        }
    }

    return crc ^ 0xffffffffU;
}


static bool Ios6FindAttribute(
    const uint8_t *message,
    size_t messageSize,
    uint16_t wantedType,
    const uint8_t **value,
    size_t *valueSize
) {
    if (messageSize < 20) {
        return false;
    }

    const size_t declared =
        (size_t)Ios6Read16(message + 2);

    size_t end =
        20 + declared;

    if (end > messageSize) {
        end = messageSize;
    }

    size_t offset = 20;

    while (offset + 4 <= end) {
        const uint16_t type =
            Ios6Read16(message + offset);

        const uint16_t length =
            Ios6Read16(message + offset + 2);

        offset += 4;

        if (offset + length > end) {
            return false;
        }

        if (type == wantedType) {
            if (value != NULL) {
                *value =
                    message + offset;
            }

            if (valueSize != NULL) {
                *valueSize =
                    length;
            }

            return true;
        }

        offset += length;

        while ((offset & 3) != 0) {
            ++offset;
        }
    }

    return false;
}


static int Ios6ParseStunErrorCode(
    const uint8_t *message,
    size_t messageSize
) {
    const uint8_t *value = NULL;
    size_t valueSize = 0;

    if (!Ios6FindAttribute(
            message,
            messageSize,
            kIos6AttrErrorCode,
            &value,
            &valueSize
        )) {

        return 0;
    }

    if (valueSize < 4) {
        return 0;
    }

    return
        ((int)(value[2] & 0x07) * 100) +
        (int)value[3];
}


static std::vector<uint8_t> Ios6MakeIceBindingRequest(
    const uint8_t txid[12],
    const std::string &localUfrag,
    const std::string &remoteUfrag,
    const std::string &remotePassword,
    uint64_t tieBreakerValue,
    bool controlling,
    bool useCandidate
) {
    std::vector<uint8_t> message =
        Ios6MakeStunHeader(
            kIos6StunBindingRequest,
            txid
        );

    const std::string username =
        remoteUfrag +
        ":" +
        localUfrag;

    Ios6AppendAttribute(
        &message,
        kIos6AttrUsername,
        username.data(),
        username.size()
    );

    const uint32_t priority =
        1862270975U;

    uint8_t priorityBytes[4];

    priorityBytes[0] =
        (uint8_t)((priority >> 24) & 0xff);

    priorityBytes[1] =
        (uint8_t)((priority >> 16) & 0xff);

    priorityBytes[2] =
        (uint8_t)((priority >> 8) & 0xff);

    priorityBytes[3] =
        (uint8_t)(priority & 0xff);

    Ios6AppendAttribute(
        &message,
        kIos6AttrPriority,
        priorityBytes,
        sizeof(priorityBytes)
    );

    uint8_t tieBreaker[8];

    for (int i = 0; i < 8; ++i) {
        tieBreaker[i] =
            (uint8_t)(
                (tieBreakerValue >>
                    ((7 - i) * 8)) &
                0xff
            );
    }

    Ios6AppendAttribute(
        &message,
        controlling
            ? kIos6AttrIceControlling
            : kIos6AttrIceControlled,
        tieBreaker,
        sizeof(tieBreaker)
    );

    if (useCandidate) {
        const uint8_t emptyUseCandidateValue = 0;

        Ios6AppendAttribute(
            &message,
            kIos6AttrUseCandidate,
            &emptyUseCandidateValue,
            0
        );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC ice.request.useCandidate"
        );
    }


    const size_t lengthThroughMi =
        (message.size() - 20) +
        4 +
        20;


    Ios6SetStunLength(
        &message,
        lengthThroughMi
    );

    unsigned char hmac[CC_SHA1_DIGEST_LENGTH];

    memset(
        hmac,
        0,
        sizeof(hmac)
    );

    CCHmac(
        kCCHmacAlgSHA1,
        remotePassword.data(),
        remotePassword.size(),
        &message[0],
        message.size(),
        hmac
    );


    Ios6AppendAttribute(
        &message,
        kIos6AttrMessageIntegrity,
        hmac,
        sizeof(hmac)
    );

    const size_t finalBodyLength =
        (message.size() - 20) +
        8;

    Ios6SetStunLength(
        &message,
        finalBodyLength
    );

    const uint32_t fingerprint =
        Ios6Crc32(
            &message[0],
            message.size()
        ) ^
        0x5354554eU;

    uint8_t fingerprintBytes[4];

    fingerprintBytes[0] =
        (uint8_t)((fingerprint >> 24) & 0xff);

    fingerprintBytes[1] =
        (uint8_t)((fingerprint >> 16) & 0xff);

    fingerprintBytes[2] =
        (uint8_t)((fingerprint >> 8) & 0xff);

    fingerprintBytes[3] =
        (uint8_t)(fingerprint & 0xff);

    Ios6AppendAttribute(
        &message,
        kIos6AttrFingerprint,
        fingerprintBytes,
        sizeof(fingerprintBytes)
    );

    Ios6SetStunLength(
        &message,
        message.size() - 20
    );

    return message;
}


static std::vector<uint8_t> Ios6MakeTurnSendIndication(
    const std::string &peerHost,
    uint16_t peerPort,
    const std::vector<uint8_t> &payload
) {
    uint8_t txid[12];
    MakeTransactionId(txid);

    std::vector<uint8_t> message =
        Ios6MakeStunHeader(
            kIos6TurnSendIndication,
            txid
        );

    uint8_t peerValue[8];

    if (!Ios6MakeXorPeerAddressValue(
            peerHost,
            peerPort,
            peerValue
        )) {

        return std::vector<uint8_t>();
    }

    Ios6AppendAttribute(
        &message,
        kIos6AttrXorPeerAddress,
        peerValue,
        sizeof(peerValue)
    );

    Ios6AppendAttribute(
        &message,
        kIos6AttrData,
        payload.empty()
            ? NULL
            : &payload[0],
        payload.size()
    );

    Ios6SetStunLength(
        &message,
        message.size() - 20
    );

    return message;
}



static bool Ios6ParseXorAddressValue(
    const uint8_t *value,
    size_t valueSize,
    std::string *host,
    uint16_t *port
) {
    if (value == NULL ||
        valueSize < 8 ||
        value[1] != 1) {

        return false;
    }

    const uint16_t encodedPort =
        Ios6Read16(value + 2);

    const uint16_t decodedPort =
        (uint16_t)(
            encodedPort ^
            (uint16_t)(kIos6StunCookie >> 16)
        );

    uint8_t addressBytes[4];

    addressBytes[0] =
        value[4] ^ 0x21;

    addressBytes[1] =
        value[5] ^ 0x12;

    addressBytes[2] =
        value[6] ^ 0xa4;

    addressBytes[3] =
        value[7] ^ 0x42;

    struct in_addr address;

    memcpy(
        &address.s_addr,
        addressBytes,
        4
    );

    char addressString[INET_ADDRSTRLEN];

    memset(
        addressString,
        0,
        sizeof(addressString)
    );

    if (inet_ntop(
            AF_INET,
            &address,
            addressString,
            sizeof(addressString)
        ) == NULL) {

        return false;
    }

    if (host != NULL) {
        *host =
            addressString;
    }

    if (port != NULL) {
        *port =
            decodedPort;
    }

    return true;
}


static bool Ios6VerifyShortTermIntegrity(
    const uint8_t *message,
    size_t messageSize,
    const std::string &password
) {
    const uint8_t *integrityValue = NULL;
    size_t integritySize = 0;

    if (!Ios6FindAttribute(
            message,
            messageSize,
            kIos6AttrMessageIntegrity,
            &integrityValue,
            &integritySize
        )) {

        return false;
    }

    if (integritySize !=
        CC_SHA1_DIGEST_LENGTH) {

        return false;
    }

    const size_t valueOffset =
        (size_t)(
            integrityValue -
            message
        );

    if (valueOffset < 24 ||
        valueOffset > messageSize) {

        return false;
    }

    const size_t attributeOffset =
        valueOffset - 4;

    if (attributeOffset < 20) {
        return false;
    }

    std::vector<uint8_t> authenticatedPart(
        message,
        message + attributeOffset
    );

    const size_t lengthThroughIntegrity =
        (attributeOffset - 20) +
        4 +
        CC_SHA1_DIGEST_LENGTH;

    if (lengthThroughIntegrity >
        65535) {

        return false;
    }

    Ios6SetStunLength(
        &authenticatedPart,
        lengthThroughIntegrity
    );

    unsigned char calculated[
        CC_SHA1_DIGEST_LENGTH
    ];

    memset(
        calculated,
        0,
        sizeof(calculated)
    );

    CCHmac(
        kCCHmacAlgSHA1,
        password.data(),
        password.size(),
        authenticatedPart.empty()
            ? NULL
            : &authenticatedPart[0],
        authenticatedPart.size(),
        calculated
    );

    return memcmp(
        calculated,
        integrityValue,
        CC_SHA1_DIGEST_LENGTH
    ) == 0;
}


static std::vector<uint8_t>
Ios6MakeIceBindingSuccessResponse(
    const uint8_t txid[12],
    const std::string &mappedHost,
    uint16_t mappedPort,
    const std::string &localPassword
) {
    std::vector<uint8_t> message =
        Ios6MakeStunHeader(
            kIos6StunBindingSuccess,
            txid
        );

    uint8_t mappedValue[8];

    if (!Ios6MakeXorPeerAddressValue(
            mappedHost,
            mappedPort,
            mappedValue
        )) {

        return std::vector<uint8_t>();
    }

    Ios6AppendAttribute(
        &message,
        kIos6AttrXorMappedAddress,
        mappedValue,
        sizeof(mappedValue)
    );

    const size_t lengthThroughIntegrity =
        (message.size() - 20) +
        4 +
        CC_SHA1_DIGEST_LENGTH;

    Ios6SetStunLength(
        &message,
        lengthThroughIntegrity
    );

    unsigned char integrity[
        CC_SHA1_DIGEST_LENGTH
    ];

    memset(
        integrity,
        0,
        sizeof(integrity)
    );

    CCHmac(
        kCCHmacAlgSHA1,
        localPassword.data(),
        localPassword.size(),
        &message[0],
        message.size(),
        integrity
    );

    Ios6AppendAttribute(
        &message,
        kIos6AttrMessageIntegrity,
        integrity,
        sizeof(integrity)
    );

    const size_t finalLength =
        (message.size() - 20) +
        8;

    Ios6SetStunLength(
        &message,
        finalLength
    );

    const uint32_t fingerprint =
        Ios6Crc32(
            &message[0],
            message.size()
        ) ^
        0x5354554eU;

    uint8_t fingerprintBytes[4];

    fingerprintBytes[0] =
        (uint8_t)(
            (fingerprint >> 24) &
            0xff
        );

    fingerprintBytes[1] =
        (uint8_t)(
            (fingerprint >> 16) &
            0xff
        );

    fingerprintBytes[2] =
        (uint8_t)(
            (fingerprint >> 8) &
            0xff
        );

    fingerprintBytes[3] =
        (uint8_t)(
            fingerprint &
            0xff
        );

    Ios6AppendAttribute(
        &message,
        kIos6AttrFingerprint,
        fingerprintBytes,
        sizeof(fingerprintBytes)
    );

    Ios6SetStunLength(
        &message,
        message.size() - 20
    );

    return message;
}




bool Ios6TurnSendData(
    int fd,
    const std::string &peerHost,
    uint16_t peerPort,
    const uint8_t *data,
    size_t size,
    std::string *error
) {
    if (error != NULL) {
        error->clear();
    }

    if (fd < 0) {
        if (error != NULL) {
            *error = "TURN socket is not open";
        }
        return false;
    }

    if (peerHost.empty() ||
        peerPort == 0) {

        if (error != NULL) {
            *error = "TURN peer missing";
        }
        return false;
    }

    if (data == NULL &&
        size != 0) {

        if (error != NULL) {
            *error = "transport data is null";
        }
        return false;
    }

    std::vector<uint8_t> payload;

    if (size != 0) {
        payload.assign(
            data,
            data + size
        );
    }

    const std::vector<uint8_t> indication =
        Ios6MakeTurnSendIndication(
            peerHost,
            peerPort,
            payload
        );

    if (indication.empty()) {
        if (error != NULL) {
            *error =
                "failed to build TURN transport Send Indication";
        }

        return false;
    }

    ssize_t sent;

    do {
        sent = send(
            fd,
            &indication[0],
            indication.size(),
            0
        );
    } while (
        sent < 0 &&
        errno == EINTR
    );

    if (sent < 0) {
        if (error != NULL) {
            *error = strerror(errno);
        }

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.send.fail errno=%d error=%s",
            errno,
            strerror(errno)
        );

        return false;
    }

    if ((size_t)sent != indication.size()) {
        if (error != NULL) {
            *error = "short TURN transport send";
        }

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.send.short sent=%ld expected=%lu",
            (long)sent,
            (unsigned long)indication.size()
        );

        return false;
    }

    return true;
}



Ios6TurnReceiveResult Ios6TurnReceivePacket(
    int fd,
    const std::string &selectedPeerHost,
    uint16_t selectedPeerPort,
    const std::string &localUfrag,
    const std::string &localPassword,
    const std::string &remoteUfrag
) {
    Ios6TurnReceiveResult result;

    if (fd < 0) {
        result.error = "TURN socket is not open";
        return result;
    }

    uint8_t buffer[4096];

    ssize_t received;

    do {
        received = recv(
            fd,
            buffer,
            sizeof(buffer),
            0
        );
    } while (received < 0 &&
             errno == EINTR);

    if (received < 0) {
        if (errno == EAGAIN ||
            errno == EWOULDBLOCK) {

            result.timeout = true;
            return result;
        }

        result.error = strerror(errno);
        return result;
    }

    if (received == 0) {
        result.kind =
            Ios6TurnReceiveResult::KindOther;
        return result;
    }

    if (received < 20) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.recv.short bytes=%ld",
            (long)received
        );

        result.kind =
            Ios6TurnReceiveResult::KindOther;

        return result;
    }

    if (Ios6Read32(buffer + 4) !=
        kIos6StunCookie) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.recv.nonStunOuter bytes=%ld",
            (long)received
        );

        result.kind =
            Ios6TurnReceiveResult::KindOther;

        return result;
    }

    const uint16_t outerType =
        Ios6Read16(buffer);

    if (outerType !=
        kIos6TurnDataIndication) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.recv.otherOuter type=0x%04x bytes=%ld",
            (unsigned int)outerType,
            (long)received
        );

        result.kind =
            Ios6TurnReceiveResult::KindOther;

        return result;
    }

    result.peerHost =
        selectedPeerHost;

    result.peerPort =
        selectedPeerPort;

    const uint8_t *peerValue = NULL;
    size_t peerValueSize = 0;

    if (Ios6FindAttribute(
            buffer,
            (size_t)received,
            kIos6AttrXorPeerAddress,
            &peerValue,
            &peerValueSize
        )) {

        std::string parsedHost;
        uint16_t parsedPort = 0;

        if (Ios6ParseXorAddressValue(
                peerValue,
                peerValueSize,
                &parsedHost,
                &parsedPort
            )) {

            result.peerHost =
                parsedHost;

            result.peerPort =
                parsedPort;
        }
    }

    const uint8_t *dataValue = NULL;
    size_t dataSize = 0;

    if (!Ios6FindAttribute(
            buffer,
            (size_t)received,
            kIos6AttrData,
            &dataValue,
            &dataSize
        )) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.recv.missingData bytes=%ld",
            (long)received
        );

        result.kind =
            Ios6TurnReceiveResult::KindOther;

        return result;
    }

    const bool looksLikeStun =
        dataSize >= 20 &&
        (dataValue[0] & 0xC0) == 0 &&
        Ios6Read32(dataValue + 4) ==
            kIos6StunCookie;

    if (looksLikeStun) {
        result.kind =
            Ios6TurnReceiveResult::KindInnerStun;

        result.innerStunType =
            Ios6Read16(dataValue);

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.recv.innerStun peer=%s:%u type=0x%04x bytes=%lu",
            result.peerHost.c_str(),
            (unsigned int)result.peerPort,
            (unsigned int)result.innerStunType,
            (unsigned long)dataSize
        );

        if (result.innerStunType ==
            kIos6StunBindingRequest) {

            const uint8_t *usernameValue = NULL;
            size_t usernameSize = 0;

            const bool hasUsername =
                Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrUsername,
                    &usernameValue,
                    &usernameSize
                );

            std::string username;

            if (hasUsername &&
                usernameValue != NULL) {

                username.assign(
                    (const char *)usernameValue,
                    usernameSize
                );
            }

            const std::string expectedUsername =
                localUfrag +
                ":" +
                remoteUfrag;

            const bool usernameOk =
                hasUsername &&
                username ==
                    expectedUsername;

            const bool integrityOk =
                !localPassword.empty() &&
                Ios6VerifyShortTermIntegrity(
                    dataValue,
                    dataSize,
                    localPassword
                );

            const uint8_t *ignoredValue = NULL;
            size_t ignoredSize = 0;

            const bool hasUseCandidate =
                Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrUseCandidate,
                    &ignoredValue,
                    &ignoredSize
                );

            ignoredValue = NULL;
            ignoredSize = 0;

            const bool hasControlling =
                Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrIceControlling,
                    &ignoredValue,
                    &ignoredSize
                );

            ignoredValue = NULL;
            ignoredSize = 0;

            const bool hasControlled =
                Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrIceControlled,
                    &ignoredValue,
                    &ignoredSize
                );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.persistent.request peer=%s:%u bytes=%lu username=%s expected=%s usernameOk=%d integrityOk=%d useCandidate=%d controlling=%d controlled=%d",
                result.peerHost.c_str(),
                (unsigned int)result.peerPort,
                (unsigned long)dataSize,
                username.c_str(),
                expectedUsername.c_str(),
                usernameOk ? 1 : 0,
                integrityOk ? 1 : 0,
                hasUseCandidate ? 1 : 0,
                hasControlling ? 1 : 0,
                hasControlled ? 1 : 0
            );

            if (!usernameOk ||
                !integrityOk) {

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.persistent.reject peer=%s:%u usernameOk=%d integrityOk=%d",
                    result.peerHost.c_str(),
                    (unsigned int)result.peerPort,
                    usernameOk ? 1 : 0,
                    integrityOk ? 1 : 0
                );

                return result;
            }


            const std::vector<uint8_t> response =
                Ios6MakeIceBindingSuccessResponse(
                    dataValue + 8,
                    result.peerHost,
                    result.peerPort,
                    localPassword
                );

            if (response.empty()) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.persistent.response.buildFailed peer=%s:%u",
                    result.peerHost.c_str(),
                    (unsigned int)result.peerPort
                );

                return result;
            }

            const std::vector<uint8_t> indication =
                Ios6MakeTurnSendIndication(
                    result.peerHost,
                    result.peerPort,
                    response
                );

            if (indication.empty()) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.persistent.turn.buildFailed peer=%s:%u",
                    result.peerHost.c_str(),
                    (unsigned int)result.peerPort
                );

                return result;
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.persistent.response.send peer=%s:%u bindingBytes=%lu turnBytes=%lu",
                result.peerHost.c_str(),
                (unsigned int)result.peerPort,
                (unsigned long)response.size(),
                (unsigned long)indication.size()
            );

            ssize_t sent;

            do {
                sent = send(
                    fd,
                    &indication[0],
                    indication.size(),
                    0
                );
            } while (sent < 0 &&
                     errno == EINTR);

            if (sent < 0) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.persistent.response.error peer=%s:%u error=%s",
                    result.peerHost.c_str(),
                    (unsigned int)result.peerPort,
                    strerror(errno)
                );

                return result;
            }

            if ((size_t)sent !=
                indication.size()) {

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.persistent.response.short peer=%s:%u sent=%ld expected=%lu",
                    result.peerHost.c_str(),
                    (unsigned int)result.peerPort,
                    (long)sent,
                    (unsigned long)indication.size()
                );

                return result;
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.persistent.response.sent peer=%s:%u",
                result.peerHost.c_str(),
                (unsigned int)result.peerPort
            );
        }

        return result;
    }

    const bool alternatePeer =
        !selectedPeerHost.empty() &&
        selectedPeerPort != 0 &&
        (result.peerHost != selectedPeerHost ||
         result.peerPort != selectedPeerPort);

    const bool looksLikeDtlsRecord =
        dataSize >= 13 &&
        dataValue[0] >= 20 && dataValue[0] <= 23 &&
        dataValue[1] == 0xfe &&
        (dataValue[2] == 0xff || dataValue[2] == 0xfd);

    if (alternatePeer && !looksLikeDtlsRecord) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.recv.dropPeer peer=%s:%u selected=%s:%u bytes=%lu first=0x%02x",
            result.peerHost.c_str(),
            (unsigned int)result.peerPort,
            selectedPeerHost.c_str(),
            (unsigned int)selectedPeerPort,
            (unsigned long)dataSize,
            dataSize != 0 ? (unsigned int)dataValue[0] : 0U
        );

        result.kind =
            Ios6TurnReceiveResult::KindOther;

        return result;
    }

    if (alternatePeer && looksLikeDtlsRecord) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.transport.recv.allowAlternateDtls peer=%s:%u selected=%s:%u bytes=%lu first=0x%02x",
            result.peerHost.c_str(),
            (unsigned int)result.peerPort,
            selectedPeerHost.c_str(),
            (unsigned int)selectedPeerPort,
            (unsigned long)dataSize,
            (unsigned int)dataValue[0]
        );
    }

    if (dataSize == 0) {
        result.kind =
            Ios6TurnReceiveResult::KindOther;

        return result;
    }

    result.kind =
        Ios6TurnReceiveResult::KindTransport;

    result.data.assign(
        dataValue,
        dataValue + dataSize
    );

    return result;
}


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
) {
    if (selectedPeerHost != NULL) {
        selectedPeerHost->clear();
    }

    if (selectedPeerPort != NULL) {
        *selectedPeerPort = 0;
    }

    if (error != NULL) {
        error->clear();
    }

    if (fd < 0) {
        if (error != NULL) {
            *error = "TURN socket is not open";
        }

        return false;
    }

    if (peerHost.empty() ||
        peerPort == 0) {

        if (error != NULL) {
            *error = "peer address missing";
        }

        return false;
    }

    if (localUfrag.empty() ||
        localPassword.empty() ||
        remoteUfrag.empty() ||
        remotePassword.empty()) {

        if (error != NULL) {
            *error = "ICE credentials missing";
        }

        return false;
    }

    struct in_addr initialAddress;

    if (inet_pton(
            AF_INET,
            peerHost.c_str(),
            &initialAddress
        ) != 1) {

        if (error != NULL) {
            *error = "ICE peer is not numeric IPv4";
        }

        return false;
    }

    struct Ios6IceProbeTransaction {
        std::string host;
        uint16_t port;
        uint8_t txid[12];
        std::vector<uint8_t> binding;
        std::vector<uint8_t> indication;
        double nextSendMs;
        double retransmitMs;
        int sendAttempt;
        bool succeeded;
    };

    struct timeval startedTv;
    gettimeofday(&startedTv, NULL);

    const double startedMs =
        ((double)startedTv.tv_sec * 1000.0) +
        ((double)startedTv.tv_usec / 1000.0);

    const double deadlineMs =
        startedMs + 7000.0;

    std::vector<Ios6IceProbeTransaction>
        transactions;

    Ios6IceProbeTransaction initial;
    initial.host = peerHost;
    initial.port = peerPort;
    MakeTransactionId(initial.txid);
    initial.binding =
        Ios6MakeIceBindingRequest(
            initial.txid,
            localUfrag,
            remoteUfrag,
            remotePassword,
            tieBreaker,
            controlling,
            useCandidate
        );
    initial.indication =
        Ios6MakeTurnSendIndication(
            initial.host,
            initial.port,
            initial.binding
        );
    initial.nextSendMs = startedMs;
    initial.retransmitMs = 500.0;
    initial.sendAttempt = 0;
    initial.succeeded = false;

    if (initial.indication.empty()) {
        if (error != NULL) {
            *error = "failed to build TURN Send Indication";
        }

        return false;
    }

    transactions.push_back(initial);

    const std::string requestUsername =
        remoteUfrag +
        ":" +
        localUfrag;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC ice.binding.begin peer=%s:%u username=%s controlling=%d useCandidate=%d requestBytes=%lu tie=%llu",
        peerHost.c_str(),
        (unsigned int)peerPort,
        requestUsername.c_str(),
        controlling ? 1 : 0,
        useCandidate ? 1 : 0,
        (unsigned long)initial.binding.size(),
        (unsigned long long)tieBreaker
    );

    bool ownCheckSucceeded = false;

    while (true) {
        struct timeval nowTv;
        gettimeofday(&nowTv, NULL);

        const double nowMs =
            ((double)nowTv.tv_sec * 1000.0) +
            ((double)nowTv.tv_usec / 1000.0);

        if (nowMs >= deadlineMs) {
            break;
        }

        for (size_t transactionIndex = 0;
             transactionIndex < transactions.size();
             ++transactionIndex) {

            Ios6IceProbeTransaction &transaction =
                transactions[transactionIndex];

            if (transaction.succeeded ||
                transaction.sendAttempt >= 5 ||
                nowMs < transaction.nextSendMs) {
                continue;
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.send attempt=%d peer=%s:%u bytes=%lu dataBytes=%lu triggered=%d",
                transaction.sendAttempt + 1,
                transaction.host.c_str(),
                (unsigned int)transaction.port,
                (unsigned long)transaction.indication.size(),
                (unsigned long)transaction.binding.size(),
                transactionIndex == 0 ? 0 : 1
            );

            ssize_t sent;

            do {
                sent = send(
                    fd,
                    &transaction.indication[0],
                    transaction.indication.size(),
                    0
                );
            } while (sent < 0 &&
                     errno == EINTR);

            if (sent < 0) {
                if (error != NULL) {
                    *error = strerror(errno);
                }

                return false;
            }

            if ((size_t)sent !=
                transaction.indication.size()) {

                if (error != NULL) {
                    *error =
                        "short TURN Send Indication send";
                }

                return false;
            }

            ++transaction.sendAttempt;
            transaction.nextSendMs =
                nowMs + transaction.retransmitMs;
            transaction.retransmitMs *= 2.0;

            if (transaction.retransmitMs > 1600.0) {
                transaction.retransmitMs = 1600.0;
            }
        }

        gettimeofday(&nowTv, NULL);

        const double beforeWaitMs =
            ((double)nowTv.tv_sec * 1000.0) +
            ((double)nowTv.tv_usec / 1000.0);

        double wakeMs = deadlineMs;

        for (size_t transactionIndex = 0;
             transactionIndex < transactions.size();
             ++transactionIndex) {

            const Ios6IceProbeTransaction &transaction =
                transactions[transactionIndex];

            if (!transaction.succeeded &&
                transaction.sendAttempt < 5 &&
                transaction.nextSendMs < wakeMs) {

                wakeMs = transaction.nextSendMs;
            }
        }

        double waitMs = wakeMs - beforeWaitMs;

        if (waitMs < 0.0) {
            waitMs = 0.0;
        }

        struct timeval waitTv;
        waitTv.tv_sec =
            (long)(waitMs / 1000.0);
        waitTv.tv_usec =
            (long)((waitMs -
                ((double)waitTv.tv_sec * 1000.0)) *
                1000.0);

        fd_set readSet;
        FD_ZERO(&readSet);
        FD_SET(fd, &readSet);

        int ready;

        do {
            ready = select(
                fd + 1,
                &readSet,
                NULL,
                NULL,
                &waitTv
            );
        } while (ready < 0 &&
                 errno == EINTR);

        if (ready < 0) {
            if (error != NULL) {
                *error = strerror(errno);
            }

            return false;
        }

        if (ready == 0) {
            continue;
        }

        uint8_t buffer[4096];

        ssize_t received;

        do {
            received = recv(
                fd,
                buffer,
                sizeof(buffer),
                0
            );
        } while (received < 0 &&
                 errno == EINTR);

        if (received < 0) {
            if (errno == EAGAIN ||
                errno == EWOULDBLOCK) {
                continue;
            }

            if (error != NULL) {
                *error = strerror(errno);
            }

            return false;
        }

        if (received < 20) {
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.data.short bytes=%ld",
                (long)received
            );

            continue;
        }

        if (Ios6Read32(buffer + 4) !=
            kIos6StunCookie) {

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.data.nonStun bytes=%ld",
                (long)received
            );

            continue;
        }

        const uint16_t outerType =
            Ios6Read16(buffer);

        if (outerType !=
            kIos6TurnDataIndication) {

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.data.otherOuter type=0x%04x bytes=%ld",
                (unsigned int)outerType,
                (long)received
            );

            continue;
        }

        std::string indicationPeerHost =
            peerHost;

        uint16_t indicationPeerPort =
            peerPort;

        const uint8_t *outerPeerValue = NULL;
        size_t outerPeerSize = 0;

        if (Ios6FindAttribute(
                buffer,
                (size_t)received,
                kIos6AttrXorPeerAddress,
                &outerPeerValue,
                &outerPeerSize
            )) {

            std::string parsedPeerHost;
            uint16_t parsedPeerPort = 0;

            if (Ios6ParseXorAddressValue(
                    outerPeerValue,
                    outerPeerSize,
                    &parsedPeerHost,
                    &parsedPeerPort
                )) {

                indicationPeerHost =
                    parsedPeerHost;

                indicationPeerPort =
                    parsedPeerPort;
            }
        }

        const uint8_t *dataValue = NULL;
        size_t dataSize = 0;

        if (!Ios6FindAttribute(
                buffer,
                (size_t)received,
                kIos6AttrData,
                &dataValue,
                &dataSize
            )) {

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.dataIndication.missingData bytes=%ld",
                (long)received
            );

            continue;
        }

        if (dataSize < 20) {
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.dataIndication.shortData bytes=%lu",
                (unsigned long)dataSize
            );

            continue;
        }

        if (Ios6Read32(dataValue + 4) !=
            kIos6StunCookie) {

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.dataIndication.payloadNonStun bytes=%lu",
                (unsigned long)dataSize
            );

            continue;
        }

        const uint16_t innerType =
            Ios6Read16(dataValue);

        int matchingTransactionIndex = -1;

        for (size_t transactionIndex = 0;
             transactionIndex < transactions.size();
             ++transactionIndex) {

            if (memcmp(
                    dataValue + 8,
                    transactions[transactionIndex].txid,
                    12
                ) == 0) {

                matchingTransactionIndex =
                    (int)transactionIndex;
                break;
            }
        }

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.dataIndication innerType=0x%04x dataBytes=%lu txIndex=%d peer=%s:%u",
            (unsigned int)innerType,
            (unsigned long)dataSize,
            matchingTransactionIndex,
            indicationPeerHost.c_str(),
            (unsigned int)indicationPeerPort
        );

        if (innerType ==
            kIos6StunBindingRequest) {

            const uint8_t *usernameValue = NULL;
            size_t usernameSize = 0;

            std::string incomingUsername;

            if (Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrUsername,
                    &usernameValue,
                    &usernameSize
                )) {

                incomingUsername.assign(
                    reinterpret_cast<const char *>(
                        usernameValue
                    ),
                    usernameSize
                );
            }

            const std::string expectedUsername =
                localUfrag +
                ":" +
                remoteUfrag;

            const bool usernameOk =
                incomingUsername ==
                expectedUsername;

            const bool integrityOk =
                usernameOk &&
                Ios6VerifyShortTermIntegrity(
                    dataValue,
                    dataSize,
                    localPassword
                );

            const uint8_t *unusedValue = NULL;
            size_t unusedSize = 0;

            const bool hasUseCandidate =
                Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrUseCandidate,
                    &unusedValue,
                    &unusedSize
                );

            unusedValue = NULL;
            unusedSize = 0;

            const bool peerControlling =
                Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrIceControlling,
                    &unusedValue,
                    &unusedSize
                );

            unusedValue = NULL;
            unusedSize = 0;

            const bool peerControlled =
                Ios6FindAttribute(
                    dataValue,
                    dataSize,
                    kIos6AttrIceControlled,
                    &unusedValue,
                    &unusedSize
                );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.incomingRequest peer=%s:%u bytes=%lu username=%s expected=%s usernameOk=%d integrityOk=%d useCandidate=%d controlling=%d controlled=%d",
                indicationPeerHost.c_str(),
                (unsigned int)indicationPeerPort,
                (unsigned long)dataSize,
                incomingUsername.c_str(),
                expectedUsername.c_str(),
                usernameOk ? 1 : 0,
                integrityOk ? 1 : 0,
                hasUseCandidate ? 1 : 0,
                peerControlling ? 1 : 0,
                peerControlled ? 1 : 0
            );

            if (!usernameOk ||
                !integrityOk) {

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.incomingRequest.reject usernameOk=%d integrityOk=%d",
                    usernameOk ? 1 : 0,
                    integrityOk ? 1 : 0
                );

                continue;
            }

            std::vector<uint8_t> bindingResponse =
                Ios6MakeIceBindingSuccessResponse(
                    dataValue + 8,
                    indicationPeerHost,
                    indicationPeerPort,
                    localPassword
                );

            if (bindingResponse.empty()) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.incomingResponse.buildFail"
                );

                continue;
            }

            std::vector<uint8_t> turnResponse =
                Ios6MakeTurnSendIndication(
                    indicationPeerHost,
                    indicationPeerPort,
                    bindingResponse
                );

            if (turnResponse.empty()) {
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.incomingResponse.turnBuildFail"
                );

                continue;
            }

            ssize_t responseSent;

            do {
                responseSent = send(
                    fd,
                    &turnResponse[0],
                    turnResponse.size(),
                    0
                );
            } while (responseSent < 0 &&
                     errno == EINTR);

            if (responseSent !=
                (ssize_t)turnResponse.size()) {

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.incomingResponse.sendFail sent=%ld expected=%lu errno=%d",
                    (long)responseSent,
                    (unsigned long)turnResponse.size(),
                    errno
                );

                continue;
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.incomingResponse.sent peer=%s:%u useCandidate=%d",
                indicationPeerHost.c_str(),
                (unsigned int)indicationPeerPort,
                hasUseCandidate ? 1 : 0
            );

            if (!controlling &&
                peerControlling &&
                hasUseCandidate) {

                if (selectedPeerHost != NULL) {
                    *selectedPeerHost =
                        indicationPeerHost;
                }

                if (selectedPeerPort != NULL) {
                    *selectedPeerPort =
                        indicationPeerPort;
                }

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.remoteNomination peer=%s:%u",
                    indicationPeerHost.c_str(),
                    (unsigned int)indicationPeerPort
                );

                return true;
            }

            bool hasTriggeredTransaction = false;

            for (size_t transactionIndex = 0;
                 transactionIndex < transactions.size();
                 ++transactionIndex) {

                if (transactions[transactionIndex].host ==
                        indicationPeerHost &&
                    transactions[transactionIndex].port ==
                        indicationPeerPort) {

                    hasTriggeredTransaction = true;

                    if (!transactions[transactionIndex].succeeded) {
                        struct timeval triggerTv;
                        gettimeofday(&triggerTv, NULL);

                        transactions[transactionIndex].nextSendMs =
                            ((double)triggerTv.tv_sec * 1000.0) +
                            ((double)triggerTv.tv_usec / 1000.0);
                    }

                    break;
                }
            }

            if (!hasTriggeredTransaction) {
                struct in_addr triggeredAddress;

                if (inet_pton(
                        AF_INET,
                        indicationPeerHost.c_str(),
                        &triggeredAddress
                    ) == 1 &&
                    indicationPeerPort != 0) {

                    Ios6IceProbeTransaction triggered;
                    triggered.host = indicationPeerHost;
                    triggered.port = indicationPeerPort;
                    MakeTransactionId(triggered.txid);
                    triggered.binding =
                        Ios6MakeIceBindingRequest(
                            triggered.txid,
                            localUfrag,
                            remoteUfrag,
                            remotePassword,
                            tieBreaker,
                            controlling,
                            useCandidate
                        );
                    triggered.indication =
                        Ios6MakeTurnSendIndication(
                            triggered.host,
                            triggered.port,
                            triggered.binding
                        );

                    struct timeval triggerTv;
                    gettimeofday(&triggerTv, NULL);

                    triggered.nextSendMs =
                        ((double)triggerTv.tv_sec * 1000.0) +
                        ((double)triggerTv.tv_usec / 1000.0);
                    triggered.retransmitMs = 500.0;
                    triggered.sendAttempt = 0;
                    triggered.succeeded = false;

                    if (!triggered.indication.empty()) {
                        transactions.push_back(triggered);

                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC ice.binding.triggered.add peer=%s:%u useCandidate=%d",
                            indicationPeerHost.c_str(),
                            (unsigned int)indicationPeerPort,
                            useCandidate ? 1 : 0
                        );
                    }
                }
            }

            continue;
        }

        if (matchingTransactionIndex < 0) {
            continue;
        }

        Ios6IceProbeTransaction &matching =
            transactions[(size_t)matchingTransactionIndex];

        if (indicationPeerHost != matching.host ||
            indicationPeerPort != matching.port) {

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.response.wrongPeer peer=%s:%u expected=%s:%u",
                indicationPeerHost.c_str(),
                (unsigned int)indicationPeerPort,
                matching.host.c_str(),
                (unsigned int)matching.port
            );

            continue;
        }

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC ice.binding.response type=0x%04x bytes=%lu peer=%s:%u",
            (unsigned int)innerType,
            (unsigned long)dataSize,
            matching.host.c_str(),
            (unsigned int)matching.port
        );

        if (innerType ==
            kIos6StunBindingSuccess) {

            const bool integrityOk =
                Ios6VerifyShortTermIntegrity(
                    dataValue,
                    dataSize,
                    remotePassword
                );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.success.integrity ok=%d peer=%s:%u triggered=%d",
                integrityOk ? 1 : 0,
                matching.host.c_str(),
                (unsigned int)matching.port,
                matchingTransactionIndex == 0 ? 0 : 1
            );

            if (!integrityOk) {
                continue;
            }

            matching.succeeded = true;
            ownCheckSucceeded = true;

            if (controlling) {
                if (selectedPeerHost != NULL) {
                    *selectedPeerHost =
                        matching.host;
                }

                if (selectedPeerPort != NULL) {
                    *selectedPeerPort =
                        matching.port;
                }

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC ice.binding.success peer=%s:%u useCandidate=%d attempts=%d triggered=%d",
                    matching.host.c_str(),
                    (unsigned int)matching.port,
                    useCandidate ? 1 : 0,
                    matching.sendAttempt,
                    matchingTransactionIndex == 0 ? 0 : 1
                );

                return true;
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.checkSucceeded.waitNomination peer=%s:%u attempts=%d triggered=%d",
                matching.host.c_str(),
                (unsigned int)matching.port,
                matching.sendAttempt,
                matchingTransactionIndex == 0 ? 0 : 1
            );

            continue;
        }

        if (innerType ==
            kIos6StunBindingError) {

            const int stunError =
                Ios6ParseStunErrorCode(
                    dataValue,
                    dataSize
                );

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC ice.binding.error code=%d peer=%s:%u",
                stunError,
                matching.host.c_str(),
                (unsigned int)matching.port
            );

            if (error != NULL) {
                char temp[96];

                snprintf(
                    temp,
                    sizeof(temp),
                    "ICE Binding error %d",
                    stunError
                );

                *error = temp;
            }

            return false;
        }
    }

    if (error != NULL) {
        if (!controlling &&
            ownCheckSucceeded) {

            *error =
                "ICE connectivity succeeded but nomination timed out";
        } else {
            *error =
                "ICE Binding transaction timed out";
        }
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC ice.binding.timeout peer=%s:%u controlling=%d useCandidate=%d pairs=%lu ownCheck=%d",
        peerHost.c_str(),
        (unsigned int)peerPort,
        controlling ? 1 : 0,
        useCandidate ? 1 : 0,
        (unsigned long)transactions.size(),
        ownCheckSucceeded ? 1 : 0
    );

    return false;
}


bool Ios6TurnRefreshAllocationNoWait(
    int fd,
    const RtcServer &server,
    const std::string &realm,
    const std::string &nonce,
    uint32_t requestedLifetimeSeconds,
    std::string *error
) {
    if (fd < 0 || realm.empty() || nonce.empty()) {
        if (error != NULL) *error = "TURN refresh auth state missing";
        return false;
    }

    uint8_t txid[12];
    MakeTransactionId(txid);
    const std::vector<uint8_t> request = MakeRefreshRequest(
        txid, server, realm, nonce, requestedLifetimeSeconds);

    ssize_t sent;
    do {
        sent = send(fd, request.empty() ? NULL : &request[0], request.size(), 0);
    } while (sent < 0 && errno == EINTR);

    const bool ok = sent >= 0 && (size_t)sent == request.size();
    if (!ok && error != NULL) {
        *error = sent < 0 ? strerror(errno) : "short TURN Refresh send";
    } else if (error != NULL) {
        error->clear();
    }

    syslog(
        LOG_NOTICE,
        "IOS6LAT turn.refresh.send ok=%d requested=%u bytes=%lu",
        ok ? 1 : 0,
        (unsigned int)requestedLifetimeSeconds,
        (unsigned long)request.size()
    );

    return ok;
}

bool Ios6TurnRefreshPermissionNoWait(
    int fd,
    const RtcServer &server,
    const std::string &realm,
    const std::string &nonce,
    const std::string &peerHost,
    uint16_t peerPort,
    std::string *error
) {
    if (fd < 0 || realm.empty() || nonce.empty() ||
        peerHost.empty() || peerPort == 0) {
        if (error != NULL) *error = "TURN permission refresh state missing";
        return false;
    }

    uint8_t txid[12];
    MakeTransactionId(txid);
    const std::vector<uint8_t> request = MakeCreatePermissionRequest(
        txid, server, realm, nonce, peerHost, peerPort);

    ssize_t sent;
    do {
        sent = send(fd, request.empty() ? NULL : &request[0], request.size(), 0);
    } while (sent < 0 && errno == EINTR);

    const bool ok = sent >= 0 && (size_t)sent == request.size();
    if (!ok && error != NULL) {
        *error = sent < 0 ? strerror(errno) : "short TURN permission refresh send";
    } else if (error != NULL) {
        error->clear();
    }

    syslog(
        LOG_NOTICE,
        "IOS6LAT turn.permission.refresh.send ok=%d peer=%s:%u bytes=%lu",
        ok ? 1 : 0,
        peerHost.c_str(),
        (unsigned int)peerPort,
        (unsigned long)request.size()
    );

    return ok;
}

bool Ios6TurnCreatePermission(
    int fd,
    const RtcServer &server,
    const std::string &realm,
    std::string *nonce,
    const std::string &peerHost,
    uint16_t peerPort,
    std::string *error
) {
    if (fd < 0) {
        if (error != NULL) {
            *error = "TURN socket is not open";
        }

        return false;
    }

    if (nonce == NULL ||
        nonce->empty() ||
        realm.empty()) {
        if (error != NULL) {
            *error = "TURN auth state missing";
        }

        return false;
    }

    struct in_addr testAddress;

    if (inet_pton(
            AF_INET,
            peerHost.c_str(),
            &testAddress
        ) != 1) {
        if (error != NULL) {
            *error = "peer is not numeric IPv4";
        }

        return false;
    }

    for (int attempt = 0;
         attempt < 2;
         ++attempt) {

        uint8_t txid[12];
        MakeTransactionId(txid);

        std::vector<uint8_t> request =
            MakeCreatePermissionRequest(
                txid,
                server,
                realm,
                *nonce,
                peerHost,
                peerPort
            );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.permission.send attempt=%d peer=%s:%u bytes=%lu",
            attempt + 1,
            peerHost.c_str(),
            (unsigned int)peerPort,
            (unsigned long)request.size()
        );

        std::vector<uint8_t> response;
        std::string receiveError;

        if (!SendAndReceive(
                fd,
                request,
                txid,
                &response,
                &receiveError
            )) {
            if (error != NULL) {
                *error = receiveError;
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.permission.fail attempt=%d peer=%s:%u error=%s",
                attempt + 1,
                peerHost.c_str(),
                (unsigned int)peerPort,
                receiveError.c_str()
            );

            return false;
        }

        const uint16_t type =
            ReadU16(&response[0]);

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.permission.response attempt=%d type=0x%04x bytes=%lu",
            attempt + 1,
            (unsigned int)type,
            (unsigned long)response.size()
        );

        if (type ==
            kTurnCreatePermissionSuccess) {

            if (error != NULL) {
                error->clear();
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC turn.permission.success peer=%s:%u",
                peerHost.c_str(),
                (unsigned int)peerPort
            );

            return true;
        }

        if (type !=
            kTurnCreatePermissionError) {
            if (error != NULL) {
                *error =
                    "unexpected CreatePermission response";
            }

            return false;
        }

        const int errorCode =
            ParseErrorCode(response);

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.permission.error attempt=%d code=%d",
            attempt + 1,
            errorCode
        );

        if (errorCode == 438 &&
            attempt == 0) {

            std::vector<uint8_t> newNonce;

            if (FindAttribute(
                    response,
                    kAttrNonce,
                    &newNonce
                )) {
                *nonce =
                    AttributeToString(newNonce);

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC turn.permission.staleNonce newLen=%lu",
                    (unsigned long)nonce->size()
                );

                continue;
            }
        }

        if (error != NULL) {
            char buffer[64];

            snprintf(
                buffer,
                sizeof(buffer),
                "CreatePermission rejected: %d",
                errorCode
            );

            *error = buffer;
        }

        return false;
    }

    if (error != NULL) {
        *error =
            "CreatePermission attempts exhausted";
    }

    return false;
}


}
