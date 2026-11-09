#include "rtp/SrtpSession.h"

#include "rtp/RtpByteIO.h"

#include <string.h>

namespace tgcalls {
namespace rtp {

namespace {

const size_t kMaxStreams = 32;
const uint64_t kReplayWindowSize = 64;
const size_t kHmacBlockSize = 64;
const size_t kAuthKeySize = 20;

size_t RtpHeaderSize(const uint8_t *packet, size_t size) {
    if (size < 12 || (packet[0] >> 6) != 2) {
        return 0;
    }
    size_t header = 12 + (size_t)(packet[0] & 0x0F) * 4;
    if (header > size) {
        return 0;
    }
    if ((packet[0] & 0x10) != 0) {
        if (header + 4 > size) {
            return 0;
        }
        header += 4 + (size_t)ReadU16(packet + header + 2) * 4;
        if (header > size) {
            return 0;
        }
    }
    return header;
}

bool Kdf(const uint8_t *masterKey, const uint8_t *masterSalt, uint8_t label, uint8_t *output, size_t outputSize) {
    AES_KEY key;
    if (AES_set_encrypt_key(masterKey, 128, &key) != 0) {
        return false;
    }
    uint8_t iv[16];
    memset(iv, 0, sizeof(iv));
    memcpy(iv, masterSalt, SrtpCryptoContext::kMasterSaltSize);
    iv[7] ^= label;
    uint8_t zeros[32];
    memset(zeros, 0, sizeof(zeros));
    uint8_t ecount[16];
    unsigned int num = 0;
    AES_ctr128_encrypt(zeros, output, outputSize, &key, iv, ecount, &num);
    return true;
}

bool TagsEqual(const uint8_t *a, const uint8_t *b, size_t size) {
    uint8_t difference = 0;
    for (size_t i = 0; i < size; ++i) {
        difference |= (uint8_t)(a[i] ^ b[i]);
    }
    return difference == 0;
}

bool CheckReplay(uint64_t highest, uint64_t window, uint64_t index) {
    if (index > highest) {
        return true;
    }
    const uint64_t delta = highest - index;
    if (delta >= kReplayWindowSize) {
        return false;
    }
    return (window & (1ULL << delta)) == 0;
}

void UpdateReplay(uint64_t *highest, uint64_t *window, uint64_t index) {
    if (index > *highest) {
        const uint64_t shift = index - *highest;
        *window = shift >= kReplayWindowSize ? 1ULL : ((*window << shift) | 1ULL);
        *highest = index;
    } else {
        *window |= 1ULL << (*highest - index);
    }
}

}

SrtpCryptoContext::SrtpCryptoContext() :
_initialized(false),
_useCounter(0) {
    memset(&_rtpKeys, 0, sizeof(_rtpKeys));
    memset(&_rtcpKeys, 0, sizeof(_rtcpKeys));
    memset(&_statistics, 0, sizeof(_statistics));
}

bool SrtpCryptoContext::deriveKeys(const uint8_t *masterKey, const uint8_t *masterSalt, uint8_t cipherLabel, SessionKeys *keys) {
    uint8_t cipherKey[16];
    uint8_t authKey[kAuthKeySize];
    if (!Kdf(masterKey, masterSalt, cipherLabel, cipherKey, sizeof(cipherKey)) ||
        !Kdf(masterKey, masterSalt, (uint8_t)(cipherLabel + 1), authKey, sizeof(authKey)) ||
        !Kdf(masterKey, masterSalt, (uint8_t)(cipherLabel + 2), keys->salt, sizeof(keys->salt))) {
        return false;
    }
    if (AES_set_encrypt_key(cipherKey, 128, &keys->cipher) != 0) {
        return false;
    }
    uint8_t pad[kHmacBlockSize];
    memset(pad, 0x36, sizeof(pad));
    for (size_t i = 0; i < kAuthKeySize; ++i) {
        pad[i] ^= authKey[i];
    }
    SHA1_Init(&keys->innerHash);
    SHA1_Update(&keys->innerHash, pad, sizeof(pad));
    memset(pad, 0x5c, sizeof(pad));
    for (size_t i = 0; i < kAuthKeySize; ++i) {
        pad[i] ^= authKey[i];
    }
    SHA1_Init(&keys->outerHash);
    SHA1_Update(&keys->outerHash, pad, sizeof(pad));
    memset(cipherKey, 0, sizeof(cipherKey));
    memset(authKey, 0, sizeof(authKey));
    memset(pad, 0, sizeof(pad));
    return true;
}

bool SrtpCryptoContext::initialize(const uint8_t *masterKey, const uint8_t *masterSalt) {
    _initialized = false;
    _streams.clear();
    if (masterKey == 0 || masterSalt == 0) {
        return false;
    }
    if (!deriveKeys(masterKey, masterSalt, 0x00, &_rtpKeys) || !deriveKeys(masterKey, masterSalt, 0x03, &_rtcpKeys)) {
        return false;
    }
    _streams.reserve(kMaxStreams);
    _initialized = true;
    return true;
}

void SrtpCryptoContext::crypt(const SessionKeys &keys, uint32_t ssrc, uint64_t index, uint8_t *data, size_t size) {
    if (size == 0) {
        return;
    }
    uint8_t iv[16];
    memcpy(iv, keys.salt, 14);
    iv[14] = 0;
    iv[15] = 0;
    iv[4] ^= (uint8_t)(ssrc >> 24);
    iv[5] ^= (uint8_t)(ssrc >> 16);
    iv[6] ^= (uint8_t)(ssrc >> 8);
    iv[7] ^= (uint8_t)ssrc;
    iv[8] ^= (uint8_t)(index >> 40);
    iv[9] ^= (uint8_t)(index >> 32);
    iv[10] ^= (uint8_t)(index >> 24);
    iv[11] ^= (uint8_t)(index >> 16);
    iv[12] ^= (uint8_t)(index >> 8);
    iv[13] ^= (uint8_t)index;
    uint8_t ecount[16];
    unsigned int num = 0;
    AES_ctr128_encrypt(data, data, size, &keys.cipher, iv, ecount, &num);
}

void SrtpCryptoContext::authenticate(const SessionKeys &keys, const uint8_t *data, size_t size, const uint8_t *suffix, size_t suffixSize, uint8_t *tag) {
    uint8_t digest[SHA_DIGEST_LENGTH];
    SHA_CTX context = keys.innerHash;
    SHA1_Update(&context, data, size);
    if (suffixSize != 0) {
        SHA1_Update(&context, suffix, suffixSize);
    }
    SHA1_Final(digest, &context);
    context = keys.outerHash;
    SHA1_Update(&context, digest, sizeof(digest));
    SHA1_Final(digest, &context);
    memcpy(tag, digest, kAuthTagSize);
}

SrtpCryptoContext::StreamState *SrtpCryptoContext::stream(uint32_t ssrc) {
    ++_useCounter;
    for (size_t i = 0; i < _streams.size(); ++i) {
        if (_streams[i].ssrc == ssrc) {
            _streams[i].lastUse = _useCounter;
            return &_streams[i];
        }
    }
    StreamState state;
    memset(&state, 0, sizeof(state));
    state.ssrc = ssrc;
    state.lastUse = _useCounter;
    if (_streams.size() < kMaxStreams) {
        _streams.push_back(state);
        return &_streams.back();
    }
    size_t oldest = 0;
    for (size_t i = 1; i < _streams.size(); ++i) {
        if ((uint32_t)(_useCounter - _streams[i].lastUse) > (uint32_t)(_useCounter - _streams[oldest].lastUse)) {
            oldest = i;
        }
    }
    _streams[oldest] = state;
    return &_streams[oldest];
}

bool SrtpCryptoContext::protectRtp(uint8_t *packet, size_t size, size_t capacity, size_t *outSize) {
    const size_t header = _initialized ? RtpHeaderSize(packet, size) : 0;
    if (header == 0 || size + kAuthTagSize > capacity) {
        return false;
    }
    const uint32_t ssrc = ReadU32(packet + 8);
    const uint16_t sequence = ReadU16(packet + 2);
    StreamState *state = stream(ssrc);
    if (!state->rtpInitialized) {
        state->rtpInitialized = true;
        state->roc = 0;
        state->highestSequence = sequence;
    } else if (IsNewerSequence(sequence, state->highestSequence)) {
        if (sequence < state->highestSequence) {
            ++state->roc;
        }
        state->highestSequence = sequence;
    }
    uint32_t roc = state->roc;
    if (sequence > state->highestSequence && !IsNewerSequence(sequence, state->highestSequence)) {
        roc -= 1;
    }
    crypt(_rtpKeys, ssrc, ((uint64_t)roc << 16) | sequence, packet + header, size - header);
    uint8_t rocBytes[4];
    WriteU32(rocBytes, roc);
    authenticate(_rtpKeys, packet, size, rocBytes, sizeof(rocBytes), packet + size);
    *outSize = size + kAuthTagSize;
    return true;
}

bool SrtpCryptoContext::unprotectRtp(uint8_t *packet, size_t size, size_t *outSize) {
    if (!_initialized || size < 12 + kAuthTagSize) {
        ++_statistics.malformedPackets;
        return false;
    }
    const size_t authenticatedSize = size - kAuthTagSize;
    const size_t header = RtpHeaderSize(packet, authenticatedSize);
    if (header == 0) {
        ++_statistics.malformedPackets;
        return false;
    }
    const uint32_t ssrc = ReadU32(packet + 8);
    const uint16_t sequence = ReadU16(packet + 2);
    StreamState *state = stream(ssrc);
    uint32_t roc = 0;
    if (state->rtpInitialized) {
        roc = state->roc;
        if (state->highestSequence < 32768) {
            if ((int32_t)sequence - (int32_t)state->highestSequence > 32768) {
                roc = state->roc - 1;
            }
        } else if ((int32_t)state->highestSequence - 32768 > (int32_t)sequence) {
            roc = state->roc + 1;
        }
    }
    const uint64_t index = ((uint64_t)roc << 16) | sequence;
    const uint64_t highest = ((uint64_t)state->roc << 16) | state->highestSequence;
    if (state->rtpInitialized && !CheckReplay(highest, state->rtpReplayWindow, index)) {
        ++_statistics.replayedPackets;
        return false;
    }
    uint8_t rocBytes[4];
    WriteU32(rocBytes, roc);
    uint8_t tag[kAuthTagSize];
    authenticate(_rtpKeys, packet, authenticatedSize, rocBytes, sizeof(rocBytes), tag);
    if (!TagsEqual(tag, packet + authenticatedSize, kAuthTagSize)) {
        ++_statistics.authenticationFailures;
        return false;
    }
    crypt(_rtpKeys, ssrc, index, packet + header, authenticatedSize - header);
    if (!state->rtpInitialized) {
        state->rtpInitialized = true;
        state->roc = roc;
        state->highestSequence = sequence;
        state->rtpReplayWindow = 1;
    } else {
        uint64_t updatedHighest = highest;
        UpdateReplay(&updatedHighest, &state->rtpReplayWindow, index);
        state->roc = (uint32_t)(updatedHighest >> 16);
        state->highestSequence = (uint16_t)updatedHighest;
    }
    *outSize = authenticatedSize;
    return true;
}

bool SrtpCryptoContext::protectRtcp(uint8_t *packet, size_t size, size_t capacity, size_t *outSize) {
    if (!_initialized || size < 8 || (packet[0] >> 6) != 2 || size + kRtcpIndexSize + kAuthTagSize > capacity) {
        return false;
    }
    const uint32_t ssrc = ReadU32(packet + 4);
    StreamState *state = stream(ssrc);
    const uint32_t index = state->rtcpOutgoingIndex & 0x7FFFFFFFU;
    state->rtcpOutgoingIndex = (index + 1) & 0x7FFFFFFFU;
    crypt(_rtcpKeys, ssrc, index, packet + 8, size - 8);
    WriteU32(packet + size, 0x80000000U | index);
    authenticate(_rtcpKeys, packet, size + kRtcpIndexSize, 0, 0, packet + size + kRtcpIndexSize);
    *outSize = size + kRtcpIndexSize + kAuthTagSize;
    return true;
}

bool SrtpCryptoContext::unprotectRtcp(uint8_t *packet, size_t size, size_t *outSize) {
    if (!_initialized || size < 8 + kRtcpIndexSize + kAuthTagSize || (packet[0] >> 6) != 2) {
        ++_statistics.malformedPackets;
        return false;
    }
    const size_t authenticatedSize = size - kAuthTagSize;
    uint8_t tag[kAuthTagSize];
    authenticate(_rtcpKeys, packet, authenticatedSize, 0, 0, tag);
    if (!TagsEqual(tag, packet + authenticatedSize, kAuthTagSize)) {
        ++_statistics.authenticationFailures;
        return false;
    }
    const uint32_t trailer = ReadU32(packet + authenticatedSize - kRtcpIndexSize);
    const bool encrypted = (trailer & 0x80000000U) != 0;
    const uint32_t index = trailer & 0x7FFFFFFFU;
    const uint32_t ssrc = ReadU32(packet + 4);
    StreamState *state = stream(ssrc);
    if (state->rtcpInitialized && !CheckReplay(state->rtcpHighestIndex, state->rtcpReplayWindow, index)) {
        ++_statistics.replayedPackets;
        return false;
    }
    const size_t payloadSize = authenticatedSize - kRtcpIndexSize;
    if (encrypted) {
        crypt(_rtcpKeys, ssrc, index, packet + 8, payloadSize - 8);
    }
    if (!state->rtcpInitialized) {
        state->rtcpInitialized = true;
        state->rtcpHighestIndex = index;
        state->rtcpReplayWindow = 1;
    } else {
        uint64_t highest = state->rtcpHighestIndex;
        UpdateReplay(&highest, &state->rtcpReplayWindow, index);
        state->rtcpHighestIndex = (uint32_t)highest;
    }
    *outSize = payloadSize;
    return true;
}

std::shared_ptr<SrtpSession> SrtpSession::createFromDtlsKeyingMaterial(const std::vector<uint8_t> &material, bool isClient) {
    const size_t keys = SrtpCryptoContext::kMasterKeySize;
    const size_t salts = SrtpCryptoContext::kMasterSaltSize;
    if (material.size() != 2 * (keys + salts)) {
        return std::shared_ptr<SrtpSession>();
    }
    const uint8_t *clientKey = &material[0];
    const uint8_t *serverKey = &material[keys];
    const uint8_t *clientSalt = &material[2 * keys];
    const uint8_t *serverSalt = &material[2 * keys + salts];
    std::shared_ptr<SrtpSession> session(new SrtpSession());
    const bool outboundReady = session->_outbound.initialize(isClient ? clientKey : serverKey, isClient ? clientSalt : serverSalt);
    const bool inboundReady = session->_inbound.initialize(isClient ? serverKey : clientKey, isClient ? serverSalt : clientSalt);
    if (!outboundReady || !inboundReady) {
        return std::shared_ptr<SrtpSession>();
    }
    return session;
}

}
}
