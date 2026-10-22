#ifndef TGCALLS_IOS6_TURN_SOCKET_H
#define TGCALLS_IOS6_TURN_SOCKET_H

#include <memory>
#include <pthread.h>
#include <stdint.h>
#include <string>
#include <sys/types.h>
#include <vector>

namespace tgcalls {

class Ios6TurnSocket {
public:
    enum Framing { FramingStun, FramingReflector };
    static std::shared_ptr<Ios6TurnSocket> connect(const std::string &host, uint16_t port, bool tcp, std::string *error, Framing framing = FramingStun);
    static std::shared_ptr<Ios6TurnSocket> adopt(int fd, bool tcp, std::string *error, Framing framing = FramingStun);
    ~Ios6TurnSocket();
    int descriptor() const;
    bool isTcp() const;
    void stop();
    ssize_t sendPacket(const void *data, size_t size);
    ssize_t receivePacket(void *data, size_t capacity, int timeoutMs = 3000);

private:
    Ios6TurnSocket(int fd, bool tcp, Framing framing);
    Ios6TurnSocket(const Ios6TurnSocket &) = delete;
    Ios6TurnSocket &operator=(const Ios6TurnSocket &) = delete;
    const int _fd;
    const bool _tcp;
    const Framing _framing;
    bool _sentPrologue = false;
    pthread_mutex_t _sendMutex;
    pthread_mutex_t _receiveMutex;
    std::vector<uint8_t> _pending;
};

}

#endif
