#ifndef POWER_VLESS_H
#define POWER_VLESS_H

#include <stddef.h>
#include <stdint.h>

#define PW_VLESS_VERSION 0x00
#define PW_UUID_LEN      16

typedef enum {
    PWAddrIPv4   = 0x01,
    PWAddrDomain = 0x02,
    PWAddrIPv6   = 0x03
} PWAddrType;

typedef enum {
    PWCmdTCP = 0x01,
    PWCmdUDP = 0x02
} PWCommand;

typedef enum {
    PWVLESSOk            =  0,
    PWVLESSBadArgument   = -1,
    PWVLESSBufferTooSmall = -2,
    PWVLESSBadUUID       = -3,
    PWVLESSBadAddress    = -4,
    PWVLESSNeedMoreData  = -5,   
    PWVLESSBadVersion    = -6
} PWVLESSStatus;

typedef struct {
    PWAddrType type;
    uint8_t    ip[16];      
    char       domain[256];
    uint16_t   port;        
} PWDestination;

typedef struct {
    uint8_t       uuid[PW_UUID_LEN];
    PWCommand     command;
    PWDestination destination;
    const char   *flow;      
} PWVLESSRequest;

PWVLESSStatus PWParseUUID(const char *text, uint8_t out[PW_UUID_LEN]);

PWVLESSStatus PWBuildRequest(const PWVLESSRequest *request,
                             uint8_t *buffer, size_t capacity, size_t *written);

PWVLESSStatus PWParseResponse(const uint8_t *buffer, size_t length,
                              size_t *headerLength);

#endif
