#ifndef OG_CORE_SOCKET_H
#define OG_CORE_SOCKET_H

#include <sys/types.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int OGCoreSocketPrepare(int fd);
int OGCoreSocketDuplicate(int fd);
ssize_t OGCoreSocketSend(int fd, const void *bytes, size_t size);
const char *OGCoreSocketRevision(void);

#ifdef __cplusplus
}
#endif

#endif
