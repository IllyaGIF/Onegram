#ifndef OG_CORE_SOCKS_H
#define OG_CORE_SOCKS_H
#include <stdint.h>
#include <sys/types.h>

typedef struct {
    char host[256];
    uint16_t port;
} OGCoreSOCKSRequest;

typedef struct {
    void *context;
    ssize_t (*read)(void *context, void *bytes, size_t size);
    ssize_t (*write)(void *context, const void *bytes, size_t size);
} OGCoreSOCKSIO;

int OGCoreReadSOCKSRequest(int fd, OGCoreSOCKSRequest *request);
int OGCoreReadSOCKSRequestAfterVersion(int fd, uint8_t version, OGCoreSOCKSRequest *request);
int OGCoreReadSOCKSRequestWithIO(const OGCoreSOCKSIO *io, OGCoreSOCKSRequest *request);
#endif
