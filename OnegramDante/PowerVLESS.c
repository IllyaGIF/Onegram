#include "PowerVLESS.h"
#include <string.h>

static int hexDigit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

PWVLESSStatus PWParseUUID(const char *text, uint8_t out[PW_UUID_LEN]) {
    if (!text || !out) return PWVLESSBadArgument;
    size_t got = 0;
    int high = -1;
    for (const char *p = text; *p; p++) {
        if (*p == '-') continue;          
        int d = hexDigit(*p);
        if (d < 0) return PWVLESSBadUUID;
        if (high < 0) { high = d; continue; }
        if (got >= PW_UUID_LEN) return PWVLESSBadUUID;   
        out[got++] = (uint8_t)((high << 4) | d);
        high = -1;
    }
    if (high >= 0) return PWVLESSBadUUID;                 
    return got == PW_UUID_LEN ? PWVLESSOk : PWVLESSBadUUID;
}

static long addressWireLength(const PWDestination *d) {
    switch (d->type) {
        case PWAddrIPv4: return 4;
        case PWAddrIPv6: return 16;
        case PWAddrDomain: {
            const char *end = memchr(d->domain, 0, sizeof(d->domain));
            if (!end) return -1;
            size_t n = (size_t)(end - d->domain);
            if (n == 0 || n > 255) return -1;             
            return (long)(1 + n);
        }
    }
    return -1;
}

PWVLESSStatus PWBuildRequest(const PWVLESSRequest *request,
                             uint8_t *buffer, size_t capacity, size_t *written) {
    if (!request || !buffer || !written) return PWVLESSBadArgument;

    long addressLength = addressWireLength(&request->destination);
    if (addressLength < 0) return PWVLESSBadAddress;

    size_t flowLength = (request->flow && request->flow[0]) ? strlen(request->flow) : 0;
    if (flowLength > 250) return PWVLESSBadArgument;
    size_t addonsLength = flowLength ? (2 + flowLength) : 0;

    size_t need = 1 + PW_UUID_LEN + 1 + addonsLength + 1 + 2 + 1 + (size_t)addressLength;
    if (capacity < need) return PWVLESSBufferTooSmall;

    uint8_t *p = buffer;
    *p++ = PW_VLESS_VERSION;
    memcpy(p, request->uuid, PW_UUID_LEN);
    p += PW_UUID_LEN;

    *p++ = (uint8_t)addonsLength;
    if (addonsLength) {
        
        *p++ = 0x0a;
        *p++ = (uint8_t)flowLength;
        memcpy(p, request->flow, flowLength);
        p += flowLength;
    }

    *p++ = (uint8_t)request->command;
    *p++ = (uint8_t)(request->destination.port >> 8);
    *p++ = (uint8_t)(request->destination.port & 0xff);
    *p++ = (uint8_t)request->destination.type;

    switch (request->destination.type) {
        case PWAddrIPv4:
            memcpy(p, request->destination.ip, 4);
            p += 4;
            break;
        case PWAddrIPv6:
            memcpy(p, request->destination.ip, 16);
            p += 16;
            break;
        case PWAddrDomain: {
            size_t n = (size_t)addressLength - 1;
            *p++ = (uint8_t)n;
            memcpy(p, request->destination.domain, n);
            p += n;
            break;
        }
    }

    *written = (size_t)(p - buffer);
    return PWVLESSOk;
}

PWVLESSStatus PWParseResponse(const uint8_t *buffer, size_t length,
                              size_t *headerLength) {
    if (!buffer || !headerLength) return PWVLESSBadArgument;
    if (length < 2) return PWVLESSNeedMoreData;
    if (buffer[0] != PW_VLESS_VERSION) return PWVLESSBadVersion;

    size_t header = (size_t)2 + buffer[1];   
    if (length < header) return PWVLESSNeedMoreData;

    *headerLength = header;
    return PWVLESSOk;
}
