#ifndef OG_DANTE_SOCKS_H
#define OG_DANTE_SOCKS_H
#include <stdint.h>
#include <sys/types.h>

typedef struct {
    char host[256];
    uint16_t port;
} OGDanteSOCKSRequest;

typedef struct {
    void *context;
    ssize_t (*read)(void *context, void *bytes, size_t size);
    ssize_t (*write)(void *context, const void *bytes, size_t size);
} OGDanteSOCKSIO;

int OGDanteReadSOCKSRequest(int fd, OGDanteSOCKSRequest *request);
int OGDanteReadSOCKSRequestWithIO(const OGDanteSOCKSIO *io, OGDanteSOCKSRequest *request);
#endif
