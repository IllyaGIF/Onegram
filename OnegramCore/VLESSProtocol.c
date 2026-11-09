#include "VLESSProtocol.h"
#include <string.h>

static int hexDigit(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

VLESSStatus VLParseUUID(const char *text, uint8_t out[VL_UUID_LEN]) {
    if (!text || !out) return VLESSBadArgument;
    size_t got = 0;
    int high = -1;
    for (const char *p = text; *p; p++) {
        if (*p == '-') continue;          
        int d = hexDigit(*p);
        if (d < 0) return VLESSBadUUID;
        if (high < 0) { high = d; continue; }
        if (got >= VL_UUID_LEN) return VLESSBadUUID;   
        out[got++] = (uint8_t)((high << 4) | d);
        high = -1;
    }
    if (high >= 0) return VLESSBadUUID;                 
    return got == VL_UUID_LEN ? VLESSOk : VLESSBadUUID;
}

static long addressWireLength(const VLDestination *d) {
    switch (d->type) {
        case VLAddrIPv4: return 4;
        case VLAddrIPv6: return 16;
        case VLAddrDomain: {
            const char *end = memchr(d->domain, 0, sizeof(d->domain));
            if (!end) return -1;
            size_t n = (size_t)(end - d->domain);
            if (n == 0 || n > 255) return -1;             
            return (long)(1 + n);
        }
    }
    return -1;
}

VLESSStatus VLBuildRequest(const VLESSRequest *request,
                             uint8_t *buffer, size_t capacity, size_t *written) {
    if (!request || !buffer || !written) return VLESSBadArgument;

    *written = 0;
    if ((request->command != VLCmdTCP && request->command != VLCmdUDP) || !request->destination.port) return VLESSBadArgument;
    long addressLength = addressWireLength(&request->destination);
    if (addressLength < 0) return VLESSBadAddress;

    size_t flowLength = (request->flow && request->flow[0]) ? strlen(request->flow) : 0;
    if (flowLength > 252) return VLESSBadArgument;
    size_t addonsLength = flowLength ? (1 + (flowLength >= 128 ? 2 : 1) + flowLength) : 0;

    size_t need = 1 + VL_UUID_LEN + 1 + addonsLength + 1 + 2 + 1 + (size_t)addressLength;
    if (capacity < need) return VLESSBufferTooSmall;

    uint8_t *p = buffer;
    *p++ = VLESS_VERSION;
    memcpy(p, request->uuid, VL_UUID_LEN);
    p += VL_UUID_LEN;

    *p++ = (uint8_t)addonsLength;
    if (addonsLength) {
        
        *p++ = 0x0a;
        if (flowLength >= 128) {
            *p++ = (uint8_t)((flowLength & 127) | 128);
            *p++ = (uint8_t)(flowLength >> 7);
        } else *p++ = (uint8_t)flowLength;
        memcpy(p, request->flow, flowLength);
        p += flowLength;
    }

    *p++ = (uint8_t)request->command;
    *p++ = (uint8_t)(request->destination.port >> 8);
    *p++ = (uint8_t)(request->destination.port & 0xff);
    *p++ = (uint8_t)request->destination.type;

    switch (request->destination.type) {
        case VLAddrIPv4:
            memcpy(p, request->destination.ip, 4);
            p += 4;
            break;
        case VLAddrIPv6:
            memcpy(p, request->destination.ip, 16);
            p += 16;
            break;
        case VLAddrDomain: {
            size_t n = (size_t)addressLength - 1;
            *p++ = (uint8_t)n;
            memcpy(p, request->destination.domain, n);
            p += n;
            break;
        }
    }

    *written = (size_t)(p - buffer);
    return VLESSOk;
}

VLESSStatus VLParseResponse(const uint8_t *buffer, size_t length,
                              size_t *headerLength) {
    if (!buffer || !headerLength) return VLESSBadArgument;
    if (length < 2) return VLESSNeedMoreData;
    if (buffer[0] != VLESS_VERSION) return VLESSBadVersion;

    size_t header = (size_t)2 + buffer[1];   
    if (length < header) return VLESSNeedMoreData;

    *headerLength = header;
    return VLESSOk;
}
