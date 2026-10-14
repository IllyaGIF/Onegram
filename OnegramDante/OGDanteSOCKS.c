#include "OGDanteSOCKS.h"
#include "OGDanteSocket.h"
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>

static int readBytes(const OGDanteSOCKSIO *io, uint8_t *bytes, size_t size)
{
    size_t offset = 0;
    while (offset < size) {
        ssize_t count = io->read(io->context, bytes + offset, size - offset);
        if (count > 0) offset += (size_t)count;
        else if (count < 0 && errno == EINTR) continue;
        else return 0;
    }
    return 1;
}

static int writeBytes(const OGDanteSOCKSIO *io, const uint8_t *bytes, size_t size)
{
    size_t offset = 0;
    while (offset < size) {
        ssize_t count = io->write(io->context, bytes + offset, size - offset);
        if (count > 0) offset += (size_t)count;
        else if (count < 0 && errno == EINTR) continue;
        else return 0;
    }
    return 1;
}

static int rejectRequest(const OGDanteSOCKSIO *io, uint8_t code)
{
    uint8_t reply[10] = {5, code, 0, 1, 0, 0, 0, 0, 0, 0};
    writeBytes(io, reply, sizeof(reply));
    return 0;
}

int OGDanteReadSOCKSRequestWithIO(const OGDanteSOCKSIO *io, OGDanteSOCKSRequest *request)
{
    uint8_t bytes[512];
    memset(request, 0, sizeof(*request));
    if (!readBytes(io, bytes, 1) || !bytes[0]) return 0;
    size_t methods = bytes[0];
    if (!readBytes(io, bytes, methods)) return 0;
    int noAuthentication = 0;
    for (size_t i = 0; i < methods; i++) if (bytes[i] == 0) noAuthentication = 1;
    uint8_t reply[2] = {5, noAuthentication ? 0 : 255};
    if (!writeBytes(io, reply, sizeof(reply)) || !noAuthentication) return 0;
    if (!readBytes(io, bytes, 4)) return 0;
    if (bytes[0] != 5 || bytes[2] != 0) return rejectRequest(io, 1);
    if (bytes[1] != 1) return rejectRequest(io, 7);
    if (bytes[3] == 1) {
        if (!readBytes(io, bytes, 6)) return 0;
        snprintf(request->host, sizeof(request->host), "%u.%u.%u.%u", bytes[0], bytes[1], bytes[2], bytes[3]);
        request->port = ((uint16_t)bytes[4] << 8) | bytes[5];
    } else if (bytes[3] == 3) {
        if (!readBytes(io, bytes, 1) || !bytes[0]) return rejectRequest(io, 8);
        size_t length = bytes[0];
        if (!readBytes(io, bytes, length + 2)) return 0;
        if (memchr(bytes, 0, length)) return rejectRequest(io, 8);
        memcpy(request->host, bytes, length);
        request->port = ((uint16_t)bytes[length] << 8) | bytes[length + 1];
    } else if (bytes[3] == 4) {
        if (!readBytes(io, bytes, 18)) return 0;
        if (!inet_ntop(AF_INET6, bytes, request->host, sizeof(request->host))) return rejectRequest(io, 8);
        request->port = ((uint16_t)bytes[16] << 8) | bytes[17];
    } else return rejectRequest(io, 8);
    if (!request->port) return rejectRequest(io, 1);
    return 1;
}

static ssize_t socketRead(void *context, void *bytes, size_t size)
{
    return read(*(int *)context, bytes, size);
}

static ssize_t socketWrite(void *context, const void *bytes, size_t size)
{
    return OGDanteSocketSend(*(int *)context, bytes, size);
}

int OGDanteReadSOCKSRequest(int fd, OGDanteSOCKSRequest *request)
{
    OGDanteSOCKSIO io = {&fd, socketRead, socketWrite};
    return OGDanteReadSOCKSRequestWithIO(&io, request);
}
