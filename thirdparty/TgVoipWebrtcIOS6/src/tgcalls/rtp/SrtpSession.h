#ifndef TGCALLS_RTP_SRTP_SESSION_H
#define TGCALLS_RTP_SRTP_SESSION_H

#include <stddef.h>
#include <stdint.h>
#include <memory>
#include <vector>

#include <openssl/aes.h>
#include <openssl/sha.h>

namespace tgcalls {
namespace rtp {

class SrtpCryptoContext {
public:
    enum {
        kMasterKeySize = 16,
        kMasterSaltSize = 14,
        kAuthTagSize = 10,
        kRtcpIndexSize = 4,
        kMaxOverhead = kAuthTagSize + kRtcpIndexSize
    };

    struct Statistics {
        uint32_t authenticationFailures;
        uint32_t replayedPackets;
        uint32_t malformedPackets;
    };

    SrtpCryptoContext();

    bool initialize(const uint8_t *masterKey, const uint8_t *masterSalt);
    bool isInitialized() const { return _initialized; }

    bool protectRtp(uint8_t *packet, size_t size, size_t capacity, size_t *outSize);
    bool unprotectRtp(uint8_t *packet, size_t size, size_t *outSize);
    bool protectRtcp(uint8_t *packet, size_t size, size_t capacity, size_t *outSize);
    bool unprotectRtcp(uint8_t *packet, size_t size, size_t *outSize);

    Statistics statistics() const { return _statistics; }

private:
    struct SessionKeys {
        AES_KEY cipher;
        uint8_t salt[14];
        SHA_CTX innerHash;
        SHA_CTX outerHash;
    };

    struct StreamState {
        uint32_t ssrc;
        uint32_t lastUse;
        bool rtpInitialized;
        uint32_t roc;
        uint16_t highestSequence;
        uint64_t rtpReplayWindow;
        bool rtcpInitialized;
        uint32_t rtcpOutgoingIndex;
        uint32_t rtcpHighestIndex;
        uint64_t rtcpReplayWindow;
    };

    static bool deriveKeys(const uint8_t *masterKey, const uint8_t *masterSalt, uint8_t cipherLabel, SessionKeys *keys);
    static void crypt(const SessionKeys &keys, uint32_t ssrc, uint64_t index, uint8_t *data, size_t size);
    static void authenticate(const SessionKeys &keys, const uint8_t *data, size_t size, const uint8_t *suffix, size_t suffixSize, uint8_t *tag);

    StreamState *stream(uint32_t ssrc);

    bool _initialized;
    SessionKeys _rtpKeys;
    SessionKeys _rtcpKeys;
    std::vector<StreamState> _streams;
    uint32_t _useCounter;
    Statistics _statistics;
};

class SrtpSession {
public:
    static std::shared_ptr<SrtpSession> createFromDtlsKeyingMaterial(const std::vector<uint8_t> &material, bool isClient);

    SrtpCryptoContext &outbound() { return _outbound; }
    SrtpCryptoContext &inbound() { return _inbound; }

private:
    SrtpSession() {}

    SrtpCryptoContext _outbound;
    SrtpCryptoContext _inbound;
};

}
}

#endif
