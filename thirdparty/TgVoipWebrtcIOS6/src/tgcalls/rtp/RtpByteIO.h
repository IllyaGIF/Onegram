#ifndef TGCALLS_RTP_BYTE_IO_H
#define TGCALLS_RTP_BYTE_IO_H

#include <stddef.h>
#include <stdint.h>

namespace tgcalls {
namespace rtp {

inline uint16_t ReadU16(const uint8_t *p) {
    return (uint16_t)(((uint16_t)p[0] << 8) | (uint16_t)p[1]);
}

inline uint32_t ReadU24(const uint8_t *p) {
    return ((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | (uint32_t)p[2];
}

inline int32_t ReadS24(const uint8_t *p) {
    const uint32_t value = ReadU24(p);
    return (value & 0x800000U) ? (int32_t)(value | 0xFF000000U) : (int32_t)value;
}

inline uint32_t ReadU32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

inline uint64_t ReadU64(const uint8_t *p) {
    return ((uint64_t)ReadU32(p) << 32) | (uint64_t)ReadU32(p + 4);
}

inline void WriteU16(uint8_t *p, uint16_t value) {
    p[0] = (uint8_t)(value >> 8);
    p[1] = (uint8_t)value;
}

inline void WriteU24(uint8_t *p, uint32_t value) {
    p[0] = (uint8_t)(value >> 16);
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)value;
}

inline void WriteU32(uint8_t *p, uint32_t value) {
    p[0] = (uint8_t)(value >> 24);
    p[1] = (uint8_t)(value >> 16);
    p[2] = (uint8_t)(value >> 8);
    p[3] = (uint8_t)value;
}

inline void WriteU64(uint8_t *p, uint64_t value) {
    WriteU32(p, (uint32_t)(value >> 32));
    WriteU32(p + 4, (uint32_t)value);
}

inline bool IsNewerSequence(uint16_t value, uint16_t previous) {
    return value != previous && (uint16_t)(value - previous) < 0x8000;
}

inline bool IsNewerTimestamp(uint32_t value, uint32_t previous) {
    return value != previous && (uint32_t)(value - previous) < 0x80000000U;
}

}
}

#endif
