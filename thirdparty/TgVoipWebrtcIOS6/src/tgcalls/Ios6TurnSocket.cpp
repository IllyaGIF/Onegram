#include "Ios6TurnSocket.h"

#include <algorithm>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#ifdef __APPLE__
#include <mach/mach_time.h>
#else
#include <time.h>
#endif

namespace tgcalls {
namespace {

class SocketLock {
public:
    explicit SocketLock(pthread_mutex_t &mutex) : _mutex(mutex) { pthread_mutex_lock(&_mutex); }
    ~SocketLock() { pthread_mutex_unlock(&_mutex); }
private:
    pthread_mutex_t &_mutex;
};

static double NowMs() {
#ifdef __APPLE__
    mach_timebase_info_data_t scale;
    mach_timebase_info(&scale);
    return static_cast<double>(mach_absolute_time()) * scale.numer / scale.denom / 1000000.0;
#else
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return static_cast<double>(now.tv_sec) * 1000.0 + now.tv_nsec / 1000000.0;
#endif
}

static bool WaitForSocket(int fd, short events, double deadline) {
    for (;;) {
        const double remaining = deadline - NowMs();
        if (remaining <= 0.0) {
            errno = EAGAIN;
            return false;
        }
        struct pollfd item;
        item.fd = fd;
        item.events = events;
        item.revents = 0;
        const int ready = poll(&item, 1, static_cast<int>(remaining) + 1);
        if (ready > 0) {
            if (item.revents & POLLNVAL) {
                errno = EBADF;
                return false;
            }
            return true;
        }
        if (ready == 0) {
            errno = EAGAIN;
            return false;
        }
        if (errno != EINTR)
            return false;
    }
}

}

Ios6TurnSocket::Ios6TurnSocket(int fd, bool tcp, Framing framing) : _fd(fd), _tcp(tcp), _framing(framing) {
    pthread_mutex_init(&_sendMutex, NULL);
    pthread_mutex_init(&_receiveMutex, NULL);
}

Ios6TurnSocket::~Ios6TurnSocket() {
    stop();
    close(_fd);
    pthread_mutex_destroy(&_sendMutex);
    pthread_mutex_destroy(&_receiveMutex);
}

std::shared_ptr<Ios6TurnSocket> Ios6TurnSocket::adopt(int fd, bool tcp, std::string *error, Framing framing) {
    if (fd < 0) {
        if (error != NULL) *error = "TURN socket is not open";
        return std::shared_ptr<Ios6TurnSocket>();
    }
    const int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0 || fcntl(fd, F_SETFL, flags | O_NONBLOCK) != 0) {
        if (error != NULL) *error = strerror(errno);
        close(fd);
        return std::shared_ptr<Ios6TurnSocket>();
    }
#ifdef SO_NOSIGPIPE
    const int enabled = 1;
    if (setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof(enabled)) != 0) {
        if (error != NULL) *error = strerror(errno);
        close(fd);
        return std::shared_ptr<Ios6TurnSocket>();
    }
#endif
    return std::shared_ptr<Ios6TurnSocket>(new Ios6TurnSocket(fd, tcp, framing));
}

std::shared_ptr<Ios6TurnSocket> Ios6TurnSocket::connect(const std::string &host, uint16_t port, bool tcp, std::string *error, Framing framing) {
    char service[16];
    snprintf(service, sizeof(service), "%u", static_cast<unsigned int>(port));
    struct addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = tcp ? SOCK_STREAM : SOCK_DGRAM;
    hints.ai_protocol = tcp ? IPPROTO_TCP : IPPROTO_UDP;
    struct addrinfo *addresses = NULL;
    const int resolved = getaddrinfo(host.c_str(), service, &hints, &addresses);
    if (resolved != 0) {
        if (error != NULL) *error = gai_strerror(resolved);
        return std::shared_ptr<Ios6TurnSocket>();
    }
    std::shared_ptr<Ios6TurnSocket> connection;
    for (struct addrinfo *address = addresses; address != NULL; address = address->ai_next) {
        connection = adopt(socket(address->ai_family, address->ai_socktype, address->ai_protocol), tcp, error, framing);
        if (!connection) continue;
        int connected = ::connect(connection->_fd, address->ai_addr, address->ai_addrlen);
        if (connected != 0 && (errno == EINPROGRESS || errno == EINTR)) {
            if (WaitForSocket(connection->_fd, POLLOUT, NowMs() + 3000.0)) {
                int socketError = 0;
                socklen_t length = sizeof(socketError);
                if (getsockopt(connection->_fd, SOL_SOCKET, SO_ERROR, &socketError, &length) == 0) {
                    connected = socketError == 0 ? 0 : -1;
                    if (socketError != 0) errno = socketError;
                }
            }
        }
        if (connected == 0) {
            if (tcp) {
                const int enabled = 1;
                setsockopt(connection->_fd, IPPROTO_TCP, TCP_NODELAY, &enabled, sizeof(enabled));
            }
            break;
        }
        if (error != NULL) *error = strerror(errno);
        connection.reset();
    }
    freeaddrinfo(addresses);
    if (connection && error != NULL) error->clear();
    return connection;
}

int Ios6TurnSocket::descriptor() const { return _fd; }
bool Ios6TurnSocket::isTcp() const { return _tcp; }
void Ios6TurnSocket::stop() { shutdown(_fd, SHUT_RDWR); }

ssize_t Ios6TurnSocket::sendPacket(const void *data, size_t size) {
    SocketLock lock(_sendMutex);
    const uint8_t *bytes = static_cast<const uint8_t *>(data);
    const size_t payloadSize = size;
    std::vector<uint8_t> framed;
    if (_tcp && _framing == FramingReflector) {
        if (size > 65536 || (size != 0 && bytes == NULL)) {
            errno = EMSGSIZE;
            return -1;
        }
        if (!_sentPrologue) framed.assign(4, 0xee);
        for (unsigned int i = 0; i < 4; ++i) framed.push_back(static_cast<uint8_t>(size >> (i * 8)));
        if (size != 0) framed.insert(framed.end(), bytes, bytes + size);
        bytes = &framed[0];
        size = framed.size();
    }
    const double deadline = NowMs() + 3000.0;
    size_t offset = 0;
    do {
#ifdef MSG_NOSIGNAL
        const int flags = MSG_NOSIGNAL;
#else
        const int flags = 0;
#endif
        const ssize_t sent = send(_fd, bytes == NULL ? NULL : bytes + offset, size - offset, flags);
        if (sent < 0 && errno == EINTR) continue;
        if (sent < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            if (WaitForSocket(_fd, POLLOUT, deadline)) continue;
        } else if (sent > 0 || (sent == 0 && size == 0)) {
            if (!_tcp) return sent;
            offset += static_cast<size_t>(sent);
            if (offset == size) {
                _sentPrologue = true;
                return static_cast<ssize_t>(payloadSize);
            }
            if (NowMs() < deadline) continue;
            errno = EAGAIN;
        } else if (sent == 0) {
            errno = EPIPE;
        }
        const int failure = errno;
        if (_tcp && offset != 0) stop();
        errno = failure;
        return -1;
    } while (true);
}

ssize_t Ios6TurnSocket::receivePacket(void *data, size_t capacity, int timeoutMs) {
    SocketLock lock(_receiveMutex);
    const double deadline = NowMs() + std::max(0, timeoutMs);
    size_t expected = 4;
    for (;;) {
        if (_tcp && _pending.size() >= 4) {
            const size_t length = (static_cast<size_t>(_pending[2]) << 8) | _pending[3];
            const uint8_t kind = _pending[0] & 0xc0;
            if (_framing == FramingReflector) {
                const uint32_t payloadSize = static_cast<uint32_t>(_pending[0]) | (static_cast<uint32_t>(_pending[1]) << 8) | (static_cast<uint32_t>(_pending[2]) << 16) | (static_cast<uint32_t>(_pending[3]) << 24);
                if (payloadSize > 65536) {
                    stop();
                    errno = EMSGSIZE;
                    return -1;
                }
                expected = 4 + payloadSize;
            } else if (kind == 0) {
                if ((length & 3) != 0) {
                    stop();
                    errno = EPROTO;
                    return -1;
                }
                expected = 20 + length;
            } else if (kind == 0x40) {
                expected = 4 + ((length + 3) & ~static_cast<size_t>(3));
            } else {
                stop();
                errno = EPROTO;
                return -1;
            }
            if (_pending.size() == expected) {
                const size_t headerSize = _framing == FramingReflector ? 4 : 0;
                const size_t payloadSize = expected - headerSize;
                if (payloadSize > capacity) {
                    _pending.clear();
                    errno = EMSGSIZE;
                    return -1;
                }
                memcpy(data, _pending.data() + headerSize, payloadSize);
                _pending.clear();
                return static_cast<ssize_t>(payloadSize);
            }
        }
        uint8_t buffer[4096];
        void *target = _tcp ? buffer : data;
        const size_t size = _tcp ? std::min(sizeof(buffer), expected - _pending.size()) : capacity;
        const ssize_t received = recv(_fd, target, size, 0);
        if (received < 0 && errno == EINTR) continue;
        if (received < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
            if (WaitForSocket(_fd, POLLIN, deadline)) continue;
            return -1;
        }
        if (!_tcp || received < 0) return received;
        if (received == 0) {
            errno = ECONNRESET;
            return -1;
        }
        _pending.insert(_pending.end(), buffer, buffer + received);
        if (_pending.size() < expected && NowMs() >= deadline) {
            errno = EAGAIN;
            return -1;
        }
    }
}

}
