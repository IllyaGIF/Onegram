#ifndef OGDANTE_SOCKET_H
#define OGDANTE_SOCKET_H

#include <sys/types.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int OGDanteSocketPrepare(int fd);
int OGDanteSocketDuplicate(int fd);
ssize_t OGDanteSocketSend(int fd, const void *bytes, size_t size);
const char *OGDanteSocketRevision(void);

#ifdef __cplusplus
}
#endif

#endif
