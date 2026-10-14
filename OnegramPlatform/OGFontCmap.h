#ifndef OG_FONT_CMAP_H
#define OG_FONT_CMAP_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static inline uint16_t OGFontRead16(const uint8_t *bytes)
{
    return (uint16_t)(((uint16_t)bytes[0] << 8) | bytes[1]);
}

static inline uint32_t OGFontRead32(const uint8_t *bytes)
{
    return ((uint32_t)OGFontRead16(bytes) << 16) | OGFontRead16(bytes + 2);
}

static inline uint32_t OGFontCmapSubtableGlyph(const uint8_t *table, size_t length, uint32_t character)
{
    if (length < 2)
        return 0;
    uint16_t format = OGFontRead16(table);
    if (format == 0)
        return length >= 262 && character < 256 ? table[6 + character] : 0;
    if (format == 4)
    {
        if (length < 16 || character > 0xffff)
            return 0;
        size_t count = OGFontRead16(table + 6) / 2;
        if (count == 0 || count > (length - 16) / 8)
            return 0;
        const uint8_t *ends = table + 14;
        const uint8_t *starts = table + 16 + count * 2;
        const uint8_t *deltas = starts + count * 2;
        const uint8_t *offsets = deltas + count * 2;
        size_t low = 0, high = count;
        while (low < high)
        {
            size_t middle = low + (high - low) / 2;
            if (OGFontRead16(ends + middle * 2) < character)
                low = middle + 1;
            else
                high = middle;
        }
        if (low == count || character < OGFontRead16(starts + low * 2))
            return 0;
        uint16_t delta = OGFontRead16(deltas + low * 2);
        uint16_t offset = OGFontRead16(offsets + low * 2);
        if (offset == 0)
            return (uint16_t)(character + delta);
        size_t address = (size_t)(offsets - table) + low * 2 + offset + (character - OGFontRead16(starts + low * 2)) * 2;
        if (address > length - 2)
            return 0;
        uint16_t glyph = OGFontRead16(table + address);
        return glyph == 0 ? 0 : (uint16_t)(glyph + delta);
    }
    if (format == 6 || format == 10)
    {
        size_t header = format == 6 ? 10 : 20;
        if (length < header)
            return 0;
        uint32_t start = format == 6 ? OGFontRead16(table + 6) : OGFontRead32(table + 12);
        uint32_t count = format == 6 ? OGFontRead16(table + 8) : OGFontRead32(table + 16);
        if (count > (length - header) / 2 || character < start || character - start >= count)
            return 0;
        return OGFontRead16(table + header + (character - start) * 2);
    }
    if (format == 12 || format == 13)
    {
        if (length < 16)
            return 0;
        uint32_t count = OGFontRead32(table + 12);
        if (count > (length - 16) / 12)
            return 0;
        size_t low = 0, high = count;
        while (low < high)
        {
            size_t middle = low + (high - low) / 2;
            const uint8_t *group = table + 16 + middle * 12;
            uint32_t start = OGFontRead32(group), end = OGFontRead32(group + 4);
            if (character < start)
                high = middle;
            else if (character > end)
                low = middle + 1;
            else
            {
                uint32_t glyph = OGFontRead32(group + 8);
                return format == 13 ? glyph : glyph + character - start;
            }
        }
    }
    return 0;
}

static inline uint32_t OGFontCmapGlyph(const uint8_t *bytes, size_t length, uint32_t character)
{
    if (bytes == NULL || length < 4 || character > 0x10ffff)
        return 0;
    size_t count = OGFontRead16(bytes + 2);
    if (count > (length - 4) / 8)
        return 0;
    for (size_t i = 0; i < count; i++)
    {
        const uint8_t *record = bytes + 4 + i * 8;
        uint16_t platform = OGFontRead16(record), encoding = OGFontRead16(record + 2);
        if (platform != 0 && !(platform == 3 && (encoding == 1 || encoding == 10)))
            continue;
        size_t offset = OGFontRead32(record + 4);
        if (offset > length || length - offset < 4)
            continue;
        const uint8_t *table = bytes + offset;
        uint16_t format = OGFontRead16(table);
        bool longLength = format == 10 || format == 12 || format == 13;
        if (longLength && length - offset < 8)
            continue;
        size_t tableLength = longLength ? OGFontRead32(table + 4) : OGFontRead16(table + 2);
        if (tableLength > length - offset || tableLength < 4)
            continue;
        uint32_t glyph = OGFontCmapSubtableGlyph(table, tableLength, character);
        if (glyph != 0)
            return glyph;
    }
    return 0;
}

#endif
