#ifndef VLESS_PROTOCOL_H
#define VLESS_PROTOCOL_H

#include <stddef.h>
#include <stdint.h>

#define VLESS_VERSION 0x00
#define VL_UUID_LEN      16

typedef enum {
    VLAddrIPv4   = 0x01,
    VLAddrDomain = 0x02,
    VLAddrIPv6   = 0x03
} VLAddrType;

typedef enum {
    VLCmdTCP = 0x01,
    VLCmdUDP = 0x02
} VLCommand;

typedef enum {
    VLESSOk            =  0,
    VLESSBadArgument   = -1,
    VLESSBufferTooSmall = -2,
    VLESSBadUUID       = -3,
    VLESSBadAddress    = -4,
    VLESSNeedMoreData  = -5,   
    VLESSBadVersion    = -6
} VLESSStatus;

typedef struct {
    VLAddrType type;
    uint8_t    ip[16];      
    char       domain[256];
    uint16_t   port;        
} VLDestination;

typedef struct {
    uint8_t       uuid[VL_UUID_LEN];
    VLCommand     command;
    VLDestination destination;
    const char   *flow;      
} VLESSRequest;

VLESSStatus VLParseUUID(const char *text, uint8_t out[VL_UUID_LEN]);

VLESSStatus VLBuildRequest(const VLESSRequest *request,
                             uint8_t *buffer, size_t capacity, size_t *written);

VLESSStatus VLParseResponse(const uint8_t *buffer, size_t length,
                              size_t *headerLength);

#endif
