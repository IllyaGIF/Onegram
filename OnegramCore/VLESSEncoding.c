#include "VLESSEncoding.h"

static int VLHexDigit(unsigned char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

int VLDecodeHexBytes(const char *text, size_t length, uint8_t *out, size_t capacity) {
    if (!text || !out || length % 2 || length / 2 > capacity) return 0;
    for (size_t i = 0; i < length; i += 2) {
        int high = VLHexDigit((unsigned char)text[i]);
        int low = VLHexDigit((unsigned char)text[i + 1]);
        if (high < 0 || low < 0) return 0;
        out[i / 2] = (uint8_t)((high << 4) | low);
    }
    return 1;
}

int VLDecodeBase64Bytes(const char *text, size_t length, uint8_t *out, size_t capacity, size_t *written) {
    if (!text || !out || !written) return 0;
    *written = 0;
    uint32_t value = 0;
    unsigned bits = 0, digits = 0, padding = 0;
    size_t count = 0;
    for (size_t i = 0; i < length; i++) {
        unsigned char c = (unsigned char)text[i];
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') continue;
        if (c == '=') {
            if (++padding > 2) return 0;
            continue;
        }
        if (padding) return 0;
        int digit;
        if (c >= 'A' && c <= 'Z') digit = c - 'A';
        else if (c >= 'a' && c <= 'z') digit = c - 'a' + 26;
        else if (c >= '0' && c <= '9') digit = c - '0' + 52;
        else if (c == '+' || c == '-') digit = 62;
        else if (c == '/' || c == '_') digit = 63;
        else return 0;
        value = (value << 6) | (uint32_t)digit;
        digits = (digits + 1) % 4;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            if (count == capacity) return 0;
            out[count++] = (uint8_t)(value >> bits);
        }
    }
    if (digits == 1 || (bits && (value & ((1u << bits) - 1))) ||
        (padding && !((digits == 2 && padding == 2) || (digits == 3 && padding == 1)))) return 0;
    *written = count;
    return 1;
}
