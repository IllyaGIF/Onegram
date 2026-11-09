#ifndef OG_CORE_HTTPS_FETCH_H
#define OG_CORE_HTTPS_FETCH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    OGCoreFetchStatusOK = 0,
    OGCoreFetchStatusInvalidArgument,
    OGCoreFetchStatusResolve,
    OGCoreFetchStatusConnect,
    OGCoreFetchStatusTLS,
    OGCoreFetchStatusCertificate,
    OGCoreFetchStatusIO,
    OGCoreFetchStatusProtocol,
    OGCoreFetchStatusTooLarge,
    OGCoreFetchStatusTimeout,
    OGCoreFetchStatusCancelled,
    OGCoreFetchStatusRejected
} OGCoreFetchStatus;

enum {
    OGCoreFetchLocationCapacity = 4096
};

typedef struct {
    int statusCode;
    int64_t contentLength;
    char location[OGCoreFetchLocationCapacity];
} OGCoreFetchHead;

typedef struct {
    const char *host;
    uint16_t port;
    const char *path;
    const char *const *headers;
    int idleTimeoutSeconds;
    uint64_t maximumBodyLength;
    int (*isCancelled)(void *context);
    int (*receiveBody)(void *context, const uint8_t *bytes, size_t length, int64_t expectedLength);
    void *context;
} OGCoreFetchRequest;

OGCoreFetchStatus OGCoreHTTPSFetch(const OGCoreFetchRequest *request, OGCoreFetchHead *head);

#ifdef __cplusplus
}
#endif

#endif
