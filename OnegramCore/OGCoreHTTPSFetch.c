#include "OGCoreHTTPSFetch.h"
#include "OGCoreGitHubTLSRoots.h"
#include "../submodules/MtProtoKit/MTProtoKit/MTOnegramCoreTLSRoots.h"
#include "../submodules/MtProtoKit/thirdparty/AsyncSocket/GCDAsyncSocketOpenSSL.h"

#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/x509v3.h>

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <netdb.h>
#include <poll.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

enum {
    OGCoreFetchBufferCapacity = 16384,
    OGCoreFetchLineCapacity = 8192,
    OGCoreFetchHeadLimit = 65536,
    OGCoreFetchPollSliceMilliseconds = 250,
    OGCoreFetchDefaultIdleTimeoutSeconds = 30
};

typedef struct {
    const OGCoreFetchRequest *request;
    int fd;
    SSL *ssl;
    double deadline;
    double headDeadline;
    size_t start;
    size_t end;
    int finished;
    uint64_t delivered;
    uint8_t buffer[OGCoreFetchBufferCapacity];
} OGCoreFetchConnection;

static SSL_CTX *OGCoreFetchSharedContext = NULL;
static pthread_once_t OGCoreFetchContextOnce = PTHREAD_ONCE_INIT;

static void OGCoreFetchAddRoots(X509_STORE *store, const char *pem)
{
    BIO *bio = BIO_new_mem_buf((void *)pem, -1);
    X509 *certificate = NULL;
    if (bio == NULL)
        return;
    while ((certificate = PEM_read_bio_X509(bio, NULL, NULL, NULL)) != NULL)
    {
        X509_STORE_add_cert(store, certificate);
        X509_free(certificate);
    }
    BIO_free(bio);
    ERR_clear_error();
}

static void OGCoreFetchCreateContext(void)
{
    SSL_CTX *context = NULL;
    X509_STORE *store = NULL;

    GCDAsyncSocketInitializeOpenSSL();
    context = SSL_CTX_new(SSLv23_client_method());
    if (context == NULL)
        return;

    SSL_CTX_set_options(context, SSL_OP_ALL | SSL_OP_NO_SSLv2 | SSL_OP_NO_SSLv3 | SSL_OP_NO_TLSv1 | SSL_OP_NO_TLSv1_1 | SSL_OP_NO_COMPRESSION);
#ifdef SSL_OP_IGNORE_UNEXPECTED_EOF
    SSL_CTX_set_options(context, SSL_OP_IGNORE_UNEXPECTED_EOF);
#endif
    SSL_CTX_set_mode(context, SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER);
    if (SSL_CTX_set_cipher_list(context, "ECDHE+AESGCM:ECDHE+AES:DHE+AESGCM:DHE+AES:!aNULL:!eNULL:!MD5:!RC4:!3DES:!DES") != 1)
    {
        SSL_CTX_free(context);
        ERR_clear_error();
        return;
    }
#ifdef SSL_CTX_set_ecdh_auto
    SSL_CTX_set_ecdh_auto(context, 1);
#endif
    SSL_CTX_set_verify(context, SSL_VERIFY_PEER, NULL);
    SSL_CTX_set_verify_depth(context, 8);

    store = SSL_CTX_get_cert_store(context);
    X509_STORE_set_flags(store, X509_V_FLAG_TRUSTED_FIRST);
    OGCoreFetchAddRoots(store, OGCoreGitHubTLSRoots);
    OGCoreFetchAddRoots(store, MTOnegramCoreTLSRoots);

    OGCoreFetchSharedContext = context;
}

static double OGCoreFetchNow(void)
{
    struct timeval now;
    gettimeofday(&now, NULL);
    return (double)now.tv_sec + (double)now.tv_usec / 1000000.0;
}

static double OGCoreFetchIdleTimeout(const OGCoreFetchConnection *connection)
{
    return (double)(connection->request->idleTimeoutSeconds > 0 ? connection->request->idleTimeoutSeconds : OGCoreFetchDefaultIdleTimeoutSeconds);
}

static void OGCoreFetchResetDeadline(OGCoreFetchConnection *connection)
{
    connection->deadline = OGCoreFetchNow() + OGCoreFetchIdleTimeout(connection);
}

static int OGCoreFetchIsCancelled(const OGCoreFetchConnection *connection)
{
    const OGCoreFetchRequest *request = connection->request;
    return request->isCancelled != NULL && request->isCancelled(request->context) != 0;
}

static OGCoreFetchStatus OGCoreFetchWait(OGCoreFetchConnection *connection, short events)
{
    for (;;)
    {
        struct pollfd descriptor;
        double remaining = 0.0;
        int milliseconds = 0;
        int result = 0;

        if (OGCoreFetchIsCancelled(connection))
            return OGCoreFetchStatusCancelled;

        remaining = (connection->headDeadline > 0.0 && connection->headDeadline < connection->deadline ? connection->headDeadline : connection->deadline) - OGCoreFetchNow();
        if (remaining <= 0.0)
            return OGCoreFetchStatusTimeout;

        milliseconds = remaining * 1000.0 < (double)OGCoreFetchPollSliceMilliseconds ? (int)(remaining * 1000.0) + 1 : OGCoreFetchPollSliceMilliseconds;
        descriptor.fd = connection->fd;
        descriptor.events = events;
        descriptor.revents = 0;
        result = poll(&descriptor, 1, milliseconds);
        if (result > 0)
            return OGCoreFetchStatusOK;
        if (result < 0 && errno != EINTR)
            return OGCoreFetchStatusIO;
    }
}

static short OGCoreFetchEventsForSSLError(int error)
{
    if (error == SSL_ERROR_WANT_READ)
        return POLLIN;
    if (error == SSL_ERROR_WANT_WRITE)
        return POLLOUT;
    return 0;
}

static OGCoreFetchStatus OGCoreFetchConnect(OGCoreFetchConnection *connection)
{
    const OGCoreFetchRequest *request = connection->request;
    struct addrinfo hints;
    struct addrinfo *addresses = NULL;
    struct addrinfo *address = NULL;
    char service[8];
    OGCoreFetchStatus status = OGCoreFetchStatusConnect;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    snprintf(service, sizeof(service), "%u", (unsigned int)(request->port != 0 ? request->port : 443));

    if (getaddrinfo(request->host, service, &hints, &addresses) != 0 || addresses == NULL)
        return OGCoreFetchStatusResolve;

    for (address = addresses; address != NULL; address = address->ai_next)
    {
        int fd = socket(address->ai_family, address->ai_socktype, address->ai_protocol);
        int flags = 0;
        if (fd < 0)
            continue;
#ifdef SO_NOSIGPIPE
        {
            int enabled = 1;
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled));
        }
#endif
        flags = fcntl(fd, F_GETFL, 0);
        if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0)
        {
            close(fd);
            continue;
        }

        connection->fd = fd;
        OGCoreFetchResetDeadline(connection);
        if (connect(fd, address->ai_addr, address->ai_addrlen) == 0)
        {
            status = OGCoreFetchStatusOK;
            break;
        }
        if (errno == EINPROGRESS)
        {
            OGCoreFetchStatus waitStatus = OGCoreFetchWait(connection, POLLOUT);
            if (waitStatus == OGCoreFetchStatusOK)
            {
                int socketError = 0;
                socklen_t length = sizeof(socketError);
                if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &length) == 0 && socketError == 0)
                {
                    status = OGCoreFetchStatusOK;
                    break;
                }
            }
            else if (waitStatus == OGCoreFetchStatusCancelled)
            {
                close(fd);
                connection->fd = -1;
                status = OGCoreFetchStatusCancelled;
                break;
            }
            else if (waitStatus == OGCoreFetchStatusTimeout)
            {
                status = OGCoreFetchStatusTimeout;
            }
        }
        close(fd);
        connection->fd = -1;
    }

    freeaddrinfo(addresses);
    return status;
}

static OGCoreFetchStatus OGCoreFetchHandshake(OGCoreFetchConnection *connection)
{
    const char *host = connection->request->host;
    X509_VERIFY_PARAM *parameters = NULL;

    pthread_once(&OGCoreFetchContextOnce, OGCoreFetchCreateContext);
    if (OGCoreFetchSharedContext == NULL)
        return OGCoreFetchStatusTLS;

    connection->ssl = SSL_new(OGCoreFetchSharedContext);
    if (connection->ssl == NULL)
        return OGCoreFetchStatusTLS;
    if (SSL_set_fd(connection->ssl, connection->fd) != 1 || SSL_set_tlsext_host_name(connection->ssl, host) != 1)
        return OGCoreFetchStatusTLS;

    parameters = SSL_get0_param(connection->ssl);
    X509_VERIFY_PARAM_set_hostflags(parameters, X509_CHECK_FLAG_NO_PARTIAL_WILDCARDS);
    if (X509_VERIFY_PARAM_set1_host(parameters, host, 0) != 1)
        return OGCoreFetchStatusTLS;

    OGCoreFetchResetDeadline(connection);
    for (;;)
    {
        int result = 0;
        short events = 0;
        OGCoreFetchStatus status = OGCoreFetchStatusOK;

        ERR_clear_error();
        result = SSL_connect(connection->ssl);
        if (result == 1)
            break;

        events = OGCoreFetchEventsForSSLError(SSL_get_error(connection->ssl, result));
        if (events == 0)
            return SSL_get_verify_result(connection->ssl) != X509_V_OK ? OGCoreFetchStatusCertificate : OGCoreFetchStatusTLS;

        status = OGCoreFetchWait(connection, events);
        if (status != OGCoreFetchStatusOK)
            return status;
    }

    return SSL_get_verify_result(connection->ssl) == X509_V_OK ? OGCoreFetchStatusOK : OGCoreFetchStatusCertificate;
}

static OGCoreFetchStatus OGCoreFetchWrite(OGCoreFetchConnection *connection, const char *bytes, size_t length)
{
    while (length > 0)
    {
        int chunk = length > (size_t)INT_MAX ? INT_MAX : (int)length;
        int written = 0;
        short events = 0;
        OGCoreFetchStatus status = OGCoreFetchStatusOK;

        ERR_clear_error();
        written = SSL_write(connection->ssl, bytes, chunk);
        if (written > 0)
        {
            bytes += written;
            length -= (size_t)written;
            OGCoreFetchResetDeadline(connection);
            continue;
        }

        events = OGCoreFetchEventsForSSLError(SSL_get_error(connection->ssl, written));
        if (events == 0)
            return OGCoreFetchStatusIO;
        status = OGCoreFetchWait(connection, events);
        if (status != OGCoreFetchStatusOK)
            return status;
    }
    return OGCoreFetchStatusOK;
}

static OGCoreFetchStatus OGCoreFetchFill(OGCoreFetchConnection *connection)
{
    if (connection->start == connection->end)
    {
        connection->start = 0;
        connection->end = 0;
    }
    else if (connection->start > 0 && connection->end == OGCoreFetchBufferCapacity)
    {
        memmove(connection->buffer, connection->buffer + connection->start, connection->end - connection->start);
        connection->end -= connection->start;
        connection->start = 0;
    }
    if (connection->end == OGCoreFetchBufferCapacity)
        return OGCoreFetchStatusProtocol;

    for (;;)
    {
        int result = 0;
        int error = 0;
        short events = 0;
        OGCoreFetchStatus status = OGCoreFetchStatusOK;

        if (OGCoreFetchIsCancelled(connection))
            return OGCoreFetchStatusCancelled;

        ERR_clear_error();
        result = SSL_read(connection->ssl, connection->buffer + connection->end, (int)(OGCoreFetchBufferCapacity - connection->end));
        if (result > 0)
        {
            connection->end += (size_t)result;
            OGCoreFetchResetDeadline(connection);
            return OGCoreFetchStatusOK;
        }

        error = SSL_get_error(connection->ssl, result);
        if (error == SSL_ERROR_ZERO_RETURN || (error == SSL_ERROR_SYSCALL && result == 0 && ERR_peek_error() == 0))
        {
            connection->finished = 1;
            return OGCoreFetchStatusOK;
        }

        events = OGCoreFetchEventsForSSLError(error);
        if (events == 0)
            return OGCoreFetchStatusIO;
        status = OGCoreFetchWait(connection, events);
        if (status != OGCoreFetchStatusOK)
            return status;
    }
}

static OGCoreFetchStatus OGCoreFetchReadLine(OGCoreFetchConnection *connection, char *line, size_t capacity, size_t *consumed)
{
    for (;;)
    {
        size_t index = 0;
        size_t pending = 0;
        OGCoreFetchStatus status = OGCoreFetchStatusOK;

        for (index = connection->start; index < connection->end; index++)
        {
            if (connection->buffer[index] == '\n')
            {
                size_t length = index - connection->start;
                if (length > 0 && connection->buffer[index - 1] == '\r')
                    length--;
                if (length >= capacity)
                    return OGCoreFetchStatusProtocol;
                memcpy(line, connection->buffer + connection->start, length);
                line[length] = 0;
                if (consumed != NULL)
                    *consumed += index + 1 - connection->start;
                connection->start = index + 1;
                return OGCoreFetchStatusOK;
            }
        }

        pending = connection->end - connection->start;
        if (pending >= capacity)
            return OGCoreFetchStatusProtocol;
        if (connection->finished)
            return OGCoreFetchStatusIO;

        status = OGCoreFetchFill(connection);
        if (status != OGCoreFetchStatusOK)
            return status;
        if (connection->finished && connection->end - connection->start == pending)
            return OGCoreFetchStatusIO;
    }
}

static int OGCoreFetchTextIsSafe(const char *text)
{
    const unsigned char *cursor = (const unsigned char *)text;
    for (; *cursor != 0; cursor++)
    {
        if (*cursor < 0x20 || *cursor == 0x7f)
            return 0;
    }
    return 1;
}

static void OGCoreFetchTrim(char *text)
{
    size_t length = strlen(text);
    while (length > 0 && (text[length - 1] == ' ' || text[length - 1] == '\t'))
        text[--length] = 0;
}

static OGCoreFetchStatus OGCoreFetchReadHead(OGCoreFetchConnection *connection, OGCoreFetchHead *head, int *chunked)
{
    char *line = malloc(OGCoreFetchLineCapacity);
    size_t consumed = 0;
    char *code = NULL;
    char *codeEnd = NULL;
    long statusCode = 0;
    OGCoreFetchStatus status = OGCoreFetchStatusOK;

    if (line == NULL)
        return OGCoreFetchStatusIO;
    connection->headDeadline = OGCoreFetchNow() + OGCoreFetchIdleTimeout(connection);

    do
    {
        status = OGCoreFetchReadLine(connection, line, OGCoreFetchLineCapacity, &consumed);
        if (status != OGCoreFetchStatusOK)
            break;
        if (strncmp(line, "HTTP/1.", 7) != 0 || (code = strchr(line, ' ')) == NULL)
        {
            status = OGCoreFetchStatusProtocol;
            break;
        }
        statusCode = strtol(code + 1, &codeEnd, 10);
        if (codeEnd == code + 1 || statusCode < 100 || statusCode > 599)
        {
            status = OGCoreFetchStatusProtocol;
            break;
        }
        head->statusCode = (int)statusCode;

        for (;;)
        {
            char *colon = NULL;
            char *value = NULL;

            status = OGCoreFetchReadLine(connection, line, OGCoreFetchLineCapacity, &consumed);
            if (status != OGCoreFetchStatusOK)
                break;
            if (consumed > OGCoreFetchHeadLimit)
            {
                status = OGCoreFetchStatusProtocol;
                break;
            }
            if (line[0] == 0)
                break;

            colon = strchr(line, ':');
            if (colon == NULL)
                continue;
            *colon = 0;
            value = colon + 1;
            while (*value == ' ' || *value == '\t')
                value++;
            OGCoreFetchTrim(value);

            if (strcasecmp(line, "Content-Length") == 0)
            {
                char *end = NULL;
                long long length = 0;
                errno = 0;
                length = strtoll(value, &end, 10);
                if (end == value || *end != 0 || errno != 0 || length < 0)
                {
                    status = OGCoreFetchStatusProtocol;
                    break;
                }
                head->contentLength = (int64_t)length;
            }
            else if (strcasecmp(line, "Transfer-Encoding") == 0)
            {
                if (strcasestr(value, "chunked") != NULL)
                    *chunked = 1;
            }
            else if (strcasecmp(line, "Location") == 0)
            {
                size_t length = strlen(value);
                if (length >= OGCoreFetchLocationCapacity)
                {
                    status = OGCoreFetchStatusProtocol;
                    break;
                }
                memcpy(head->location, value, length + 1);
            }
        }
    }
    while (0);

    connection->headDeadline = 0.0;
    free(line);
    return status;
}

static OGCoreFetchStatus OGCoreFetchEmit(OGCoreFetchConnection *connection, const uint8_t *bytes, size_t length, int64_t expectedLength)
{
    const OGCoreFetchRequest *request = connection->request;
    if (request->maximumBodyLength != 0 && connection->delivered + length > request->maximumBodyLength)
        return OGCoreFetchStatusTooLarge;
    connection->delivered += length;
    if (request->receiveBody != NULL && request->receiveBody(request->context, bytes, length, expectedLength) != 0)
        return OGCoreFetchStatusRejected;
    return OGCoreFetchStatusOK;
}

static OGCoreFetchStatus OGCoreFetchReadExactly(OGCoreFetchConnection *connection, uint64_t count, int64_t expectedLength)
{
    while (count > 0)
    {
        size_t available = connection->end - connection->start;
        size_t take = 0;
        OGCoreFetchStatus status = OGCoreFetchStatusOK;

        if (available == 0)
        {
            if (connection->finished)
                return OGCoreFetchStatusIO;
            status = OGCoreFetchFill(connection);
            if (status != OGCoreFetchStatusOK)
                return status;
            continue;
        }

        take = (uint64_t)available < count ? available : (size_t)count;
        status = OGCoreFetchEmit(connection, connection->buffer + connection->start, take, expectedLength);
        if (status != OGCoreFetchStatusOK)
            return status;
        connection->start += take;
        count -= take;
    }
    return OGCoreFetchStatusOK;
}

static OGCoreFetchStatus OGCoreFetchReadUntilClose(OGCoreFetchConnection *connection)
{
    for (;;)
    {
        size_t available = connection->end - connection->start;
        OGCoreFetchStatus status = OGCoreFetchStatusOK;

        if (available == 0)
        {
            if (connection->finished)
                return OGCoreFetchStatusOK;
            status = OGCoreFetchFill(connection);
            if (status != OGCoreFetchStatusOK)
                return status;
            continue;
        }

        status = OGCoreFetchEmit(connection, connection->buffer + connection->start, available, -1);
        if (status != OGCoreFetchStatusOK)
            return status;
        connection->start = connection->end;
    }
}

static OGCoreFetchStatus OGCoreFetchReadChunked(OGCoreFetchConnection *connection)
{
    char line[1024];

    for (;;)
    {
        char *end = NULL;
        unsigned long long size = 0;
        OGCoreFetchStatus status = OGCoreFetchReadLine(connection, line, sizeof(line), NULL);
        if (status != OGCoreFetchStatusOK)
            return status;

        errno = 0;
        size = strtoull(line, &end, 16);
        if (end == line || errno != 0 || (*end != 0 && *end != ';' && *end != ' ' && *end != '\t'))
            return OGCoreFetchStatusProtocol;

        if (size == 0)
        {
            for (;;)
            {
                status = OGCoreFetchReadLine(connection, line, sizeof(line), NULL);
                if (status != OGCoreFetchStatusOK)
                    return status;
                if (line[0] == 0)
                    return OGCoreFetchStatusOK;
            }
        }

        status = OGCoreFetchReadExactly(connection, (uint64_t)size, -1);
        if (status != OGCoreFetchStatusOK)
            return status;
        status = OGCoreFetchReadLine(connection, line, sizeof(line), NULL);
        if (status != OGCoreFetchStatusOK)
            return status;
        if (line[0] != 0)
            return OGCoreFetchStatusProtocol;
    }
}

static char *OGCoreFetchCreateRequestText(const OGCoreFetchRequest *request)
{
    const char *const *header = NULL;
    size_t capacity = strlen(request->path) + strlen(request->host) + 128;
    size_t length = 0;
    char *text = NULL;
    uint16_t port = request->port != 0 ? request->port : 443;

    for (header = request->headers; header != NULL && *header != NULL; header++)
        capacity += strlen(*header) + 2;

    text = malloc(capacity);
    if (text == NULL)
        return NULL;

    if (port == 443)
        length = (size_t)snprintf(text, capacity, "GET %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nAccept-Encoding: identity\r\n", request->path, request->host);
    else
        length = (size_t)snprintf(text, capacity, "GET %s HTTP/1.1\r\nHost: %s:%u\r\nConnection: close\r\nAccept-Encoding: identity\r\n", request->path, request->host, (unsigned int)port);

    for (header = request->headers; header != NULL && *header != NULL; header++)
        length += (size_t)snprintf(text + length, capacity - length, "%s\r\n", *header);
    snprintf(text + length, capacity - length, "\r\n");
    return text;
}

OGCoreFetchStatus OGCoreHTTPSFetch(const OGCoreFetchRequest *request, OGCoreFetchHead *head)
{
    OGCoreFetchConnection *connection = NULL;
    const char *const *header = NULL;
    char *requestText = NULL;
    int chunked = 0;
    OGCoreFetchStatus status = OGCoreFetchStatusOK;

    if (head == NULL)
        return OGCoreFetchStatusInvalidArgument;
    memset(head, 0, sizeof(*head));
    head->contentLength = -1;

    if (request == NULL || request->host == NULL || request->host[0] == 0 || request->path == NULL || request->path[0] != '/')
        return OGCoreFetchStatusInvalidArgument;
    if (!OGCoreFetchTextIsSafe(request->host) || !OGCoreFetchTextIsSafe(request->path) || strchr(request->host, ' ') != NULL || strchr(request->path, ' ') != NULL)
        return OGCoreFetchStatusInvalidArgument;
    for (header = request->headers; header != NULL && *header != NULL; header++)
    {
        if (!OGCoreFetchTextIsSafe(*header))
            return OGCoreFetchStatusInvalidArgument;
    }

    connection = calloc(1, sizeof(*connection));
    if (connection == NULL)
        return OGCoreFetchStatusIO;
    connection->request = request;
    connection->fd = -1;

    status = OGCoreFetchConnect(connection);
    if (status == OGCoreFetchStatusOK)
        status = OGCoreFetchHandshake(connection);
    if (status == OGCoreFetchStatusOK)
    {
        requestText = OGCoreFetchCreateRequestText(request);
        status = requestText != NULL ? OGCoreFetchWrite(connection, requestText, strlen(requestText)) : OGCoreFetchStatusIO;
        free(requestText);
    }
    if (status == OGCoreFetchStatusOK)
        status = OGCoreFetchReadHead(connection, head, &chunked);
    if (status == OGCoreFetchStatusOK && head->statusCode == 200)
    {
        if (chunked)
            status = OGCoreFetchReadChunked(connection);
        else if (head->contentLength >= 0)
        {
            if (request->maximumBodyLength != 0 && (uint64_t)head->contentLength > request->maximumBodyLength)
                status = OGCoreFetchStatusTooLarge;
            else
                status = OGCoreFetchReadExactly(connection, (uint64_t)head->contentLength, head->contentLength);
        }
        else
            status = OGCoreFetchReadUntilClose(connection);
    }

    if (connection->ssl != NULL)
        SSL_free(connection->ssl);
    if (connection->fd >= 0)
        close(connection->fd);
    free(connection);
    ERR_clear_error();
    return status;
}
