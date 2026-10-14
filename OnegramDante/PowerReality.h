#ifndef POWER_REALITY_H
#define POWER_REALITY_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

typedef enum {
    PWR_OK = 0,       
    PWR_IO,           
    PWR_PROTOCOL,     
    PWR_AUTH          
} PWRealityResult;

typedef struct {
    int      fd;
    int      cipher;          
    uint8_t  sendKey[32];
    uint8_t  sendIV[12];
    uint8_t  recvKey[32];
    uint8_t  recvIV[12];
    uint64_t sendSeq;
    uint64_t recvSeq;
    uint8_t readBuffer[18432];
    size_t readOffset;
    size_t readLength;
} PWReality;

PWRealityResult pwRealityConnect(PWReality *r, int fd,
                                 const char *sni,
                                 const uint8_t pbk[32], const uint8_t sid[8],
                                 const char *const *alpn, size_t alpnCount,
                                 long timeoutSec);

size_t pwRealityPending(const PWReality *r);

ssize_t pwRealityRead(PWReality *r, uint8_t *buf, size_t capacity);

int pwRealityWrite(PWReality *r, const uint8_t *buf, size_t length);

void pwRealityClose(PWReality *r);

extern volatile int gPWRealityTrace;

#endif
