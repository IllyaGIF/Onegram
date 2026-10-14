#ifndef OG_UNICODE_H
#define OG_UNICODE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static inline bool OGUnicodeIsHighSurrogate(uint16_t value)
{
    return value >= 0xd800 && value <= 0xdbff;
}

static inline bool OGUnicodeIsLowSurrogate(uint16_t value)
{
    return value >= 0xdc00 && value <= 0xdfff;
}

static inline uint32_t OGUnicodeScalarForSurrogatePair(uint16_t high, uint16_t low)
{
    return 0x10000u + (((uint32_t)high - 0xd800u) << 10) + ((uint32_t)low - 0xdc00u);
}

static inline bool OGUnicodeSurrogatePairForScalar(uint32_t value, uint16_t pair[2])
{
    if (value < 0x10000 || value > 0x10ffff || pair == NULL)
        return false;
    value -= 0x10000;
    pair[0] = (uint16_t)(0xd800u + (value >> 10));
    pair[1] = (uint16_t)(0xdc00u + (value & 0x3ffu));
    return true;
}

#endif
