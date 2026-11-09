#ifndef VLESS_REALITY_H
#define VLESS_REALITY_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

typedef enum {
    VLR_OK = 0,       
    VLR_IO,           
    VLR_PROTOCOL,     
    VLR_AUTH          
} VLRealityResult;

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
} VLReality;

VLRealityResult vlRealityConnect(VLReality *r, int fd,
                                 const char *sni,
                                 const uint8_t pbk[32], const uint8_t sid[8],
                                 const char *const *alpn, size_t alpnCount,
                                 long timeoutSec);

size_t vlRealityPending(const VLReality *r);

ssize_t vlRealityRead(VLReality *r, uint8_t *buf, size_t capacity);

int vlRealityWrite(VLReality *r, const uint8_t *buf, size_t length);

void vlRealityClose(VLReality *r);

extern volatile int gVLRealityTrace;

#endif
