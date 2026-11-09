#include "OGCoreSocket.h"
#include <sys/socket.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

const char *OGCoreSocketRevision(void)
{
    return "socket-lease-2";
}

int OGCoreSocketPrepare(int fd)
{
#if defined(SO_NOSIGPIPE)
    int one = 1;
    return setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#elif defined(MSG_NOSIGNAL)
    return fcntl(fd, F_GETFD) < 0 ? -1 : 0;
#else
#error Socket writes require SO_NOSIGPIPE or MSG_NOSIGNAL
#endif
}

int OGCoreSocketDuplicate(int fd)
{
    int duplicate;
    do {
        duplicate = dup(fd);
    } while (duplicate < 0 && errno == EINTR);
    if (duplicate < 0) return -1;
    if (fcntl(duplicate, F_SETFD, FD_CLOEXEC) < 0 || OGCoreSocketPrepare(duplicate) < 0) {
        int failure = errno;
        close(duplicate);
        errno = failure;
        return -1;
    }
    return duplicate;
}

ssize_t OGCoreSocketSend(int fd, const void *bytes, size_t size)
{
#if defined(MSG_NOSIGNAL)
    return send(fd, bytes, size, MSG_NOSIGNAL);
#else
    if (OGCoreSocketPrepare(fd) < 0) return -1;
    return send(fd, bytes, size, 0);
#endif
}
