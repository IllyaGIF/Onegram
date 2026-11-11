#include "NetworkManager.h"
#include "Ios6TurnClient.h"
#include "Ios6DtlsTransport.h"
#include "MediaTransport.h"

#include "Message.h"
#include "rtp/RtpTime.h"
#include "rtp/SrtpSession.h"
#include "rtc_base/logging.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <errno.h>
#include <sstream>
#include <syslog.h>
#include <sys/time.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>

#ifdef TGCALLS_IOS6_AUDIO_ONLY
#include <dispatch/dispatch.h>

#include "Ios6DiagnosticLog.h"

namespace tgcalls {

static const double kIos6ConnectTimeoutMs = 20000.0;
static const double kIos6IceCheckWindowMs = 7000.0;
static const double kIos6ReceiverTransientErrorGraceMs = 10000.0;
static const useconds_t kIos6ReceiverRetryDelayUs = 50000;

static double Ios6LatencyNowMs() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return ((double)tv.tv_sec * 1000.0) + ((double)tv.tv_usec / 1000.0);
}

template <typename StateType>
static StateType OGCompatTransportState(bool ready) {
    StateType result;
    result.isReadyToSendData = ready;
    result.isFailed = !ready;
    return result;
}

static Message OGCompatSignalingMessage(const CandidatesListMessage &payload) {
    Message result;
    result.data = payload;
    return result;
}

static cricket::Candidate OGCompatRelayCandidate(const char *sdp) {
    cricket::Candidate result;
    result.FromString(sdp);
    return result;
}

static unsigned long OGCompatCount(size_t value) {
    return (unsigned long)value;
}

static int OGCompatFlag(bool value) {
    return value ? 1 : 0;
}

static bool Ios6ReceiveErrorIsTransient(int errorCode) {
    switch (errorCode) {
        case ECONNREFUSED:
        case ENETDOWN:
        case ENETUNREACH:
        case ENETRESET:
        case EHOSTDOWN:
        case EHOSTUNREACH:
        case ENOBUFS:
            return true;
        default:
            return false;
    }
}

NetworkManager::NetworkManager(
    rtc::Thread *thread,
    EncryptionKey encryptionKey,
    bool isOutgoing,
    bool enableP2P,
    bool enableTCP,
    bool enableStunMarking,
    std::vector<RtcServer> const &rtcServers,
    std::unique_ptr<Proxy> proxy,
    std::shared_ptr<MediaTransport> mediaTransport,
    std::function<void(const NetworkManager::State &)> stateUpdated,
    DecryptedMessageCallback transportMessageReceived,
    MessageCallback sendSignalingMessage,
    std::function<void(int delayMs, int cause)> sendTransportServiceAsync) :
_thread(thread),
_mediaTransport(std::move(mediaTransport)),
_enableP2P(enableP2P),
_enableTCP(enableTCP),
_enableStunMarking(enableStunMarking),
_rtcServers(rtcServers),
_proxy(std::move(proxy)),
_transport(
    EncryptedConnection::Type::Transport,
    encryptionKey,
    &NetworkManager::ios56TransportServiceThunk,
    this),
_isOutgoing(isOutgoing),
_stateUpdated(std::move(stateUpdated)),
_transportMessageReceived(std::move(transportMessageReceived)),
_sendSignalingMessage(std::move(sendSignalingMessage)) {
    (void)sendTransportServiceAsync;
}

void NetworkManager::ios56TransportServiceThunk(
        void *context,
        int delayMs,
        int cause) {
    NetworkManager *manager =
        static_cast<NetworkManager *>(context);

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC transport.service.thunk context=%p delay=%d cause=%d",
        context,
        delayMs,
        cause
    );

    if (manager != NULL) {
        manager->ios56ScheduleTransportService(delayMs, cause);
    }
}

void NetworkManager::ios56ScheduleTransportService(
        int delayMs,
        int cause) {
    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC transport.service.schedule delay=%d cause=%d ready=%d",
        delayMs,
        cause,
        _ios6TransportReady ? 1 : 0
    );

    const std::weak_ptr<NetworkManager> weak(shared_from_this());
    rtc::Thread *thread = _thread;

    if (delayMs > 0) {
        const int64_t ns =
            (int64_t)delayMs * 1000000LL;

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, ns),
            dispatch_get_global_queue(
                DISPATCH_QUEUE_PRIORITY_DEFAULT,
                0
            ),
            ^{
                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC transport.service.delay.fire delay=%d cause=%d",
                    delayMs,
                    cause
                );

                thread->PostTask([weak, cause]() {
                    const std::shared_ptr<NetworkManager> strong =
                        weak.lock();

                    if (!strong) {
                        return;
                    }

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC transport.service.fire cause=%d ready=%d",
                        cause,
                        strong->_ios6TransportReady ? 1 : 0
                    );

                    strong->sendTransportService(cause);
                });
            }
        );

        return;
    }

    thread->PostTask([weak, cause]() {
        const std::shared_ptr<NetworkManager> strong =
            weak.lock();

        if (!strong) {
            return;
        }

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.service.fire cause=%d ready=%d",
            cause,
            strong->_ios6TransportReady ? 1 : 0
        );

        strong->sendTransportService(cause);
    });
}



void NetworkManager::ios56ScheduleTurnMaintenance() {
    if (_ios6TurnFd < 0) {
        return;
    }

    uint32_t lifetime = _ios6TurnLifetimeSeconds;
    if (lifetime < 30) lifetime = 60;

    uint32_t delaySeconds = lifetime / 3;
    if (delaySeconds < 15) delaySeconds = 15;
    if (delaySeconds > 30) delaySeconds = 30;
    if (_ios6Relay && _ios6Relay->isReflector()) delaySeconds = 10;

    const int64_t ns = (int64_t)delaySeconds * 1000000000LL;
    const std::weak_ptr<NetworkManager> weak(shared_from_this());
    rtc::Thread *thread = _thread;

    syslog(
        LOG_NOTICE,
        "IOS6LAT turn.maintenance.schedule lifetime=%u delay=%u",
        (unsigned int)_ios6TurnLifetimeSeconds,
        (unsigned int)delaySeconds
    );

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, ns),
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            thread->PostTask([weak]() {
                const std::shared_ptr<NetworkManager> strong = weak.lock();
                if (!strong) return;
                strong->ios56PerformTurnMaintenance();
            });
        }
    );
}

void NetworkManager::ios56PerformTurnMaintenance() {
    if (_ios6Relay && _ios6Relay->isReflector()) {
        std::string error;
        if (!_ios6Relay->sendHello(&error)) {
            syslog(LOG_NOTICE, "IOS6WEBRTC reflector.keepalive.fail error=%s", error.c_str());
        }
        ios56ScheduleTurnMaintenance();
        return;
    }

    if (_ios6TurnFd < 0 ||
        _ios6TurnRealm.empty() ||
        _ios6TurnNonce.empty()) {
        return;
    }

    ++_ios6TurnMaintenanceTick;

    std::string refreshError;
    const bool refreshSent = Ios6TurnRefreshAllocationNoWait(
        *_ios6TurnSocket,
        _ios6TurnServer,
        _ios6TurnRealm,
        _ios6TurnNonce,
        600,
        &refreshError
    );

    bool permissionSent = true;
    std::string permissionError;

    if ((_ios6TurnMaintenanceTick % 4U) == 0U &&
        !_ios6SelectedPeerHost.empty() &&
        _ios6SelectedPeerPort != 0) {
        permissionSent = Ios6TurnRefreshPermissionNoWait(
            *_ios6TurnSocket,
            _ios6TurnServer,
            _ios6TurnRealm,
            _ios6TurnNonce,
            _ios6SelectedPeerHost,
            _ios6SelectedPeerPort,
            &permissionError
        );
    }

    syslog(
        LOG_NOTICE,
        "IOS6LAT turn.maintenance tick=%u allocation=%d permission=%d allocErr=%s permErr=%s",
        _ios6TurnMaintenanceTick,
        refreshSent ? 1 : 0,
        permissionSent ? 1 : 0,
        refreshError.c_str(),
        permissionError.c_str()
    );

    ios56ScheduleTurnMaintenance();
}

void NetworkManager::setIos6DtlsParameters(
    X509 *certificate,
    EVP_PKEY *privateKey,
    const std::string &remoteHash,
    const std::string &remoteFingerprint,
    const std::string &remoteSetup
) {
    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.network.params hash=%s setup=%s fingerprint=%s",
        remoteHash.c_str(),
        remoteSetup.c_str(),
        remoteFingerprint.c_str()
    );

    if (!_ios6DtlsTransport) {
        _ios6DtlsTransport.reset(
            new Ios6DtlsTransport(
                [this](
                    const uint8_t *data,
                    size_t size
                ) -> bool {

                    if (!_ios6TransportReady ||
                        _ios6TurnFd < 0 ||
                        _ios6SelectedPeerHost.empty() ||
                        _ios6SelectedPeerPort == 0 ||
                        data == NULL ||
                        size == 0) {

                        syslog(
                            LOG_ERR,
                            "IOS6WEBRTC dtls.tx.notReady fd=%d ready=%d bytes=%lu",
                            _ios6TurnFd,
                            _ios6TransportReady ? 1 : 0,
                            (unsigned long)size
                        );

                        return false;
                    }

                    std::string error;

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC dtls.tx contentType=%u bytes=%lu peer=%s:%u",
                        (unsigned int)data[0],
                        (unsigned long)size,
                        _ios6SelectedPeerHost.c_str(),
                        (unsigned int)_ios6SelectedPeerPort
                    );

                    const bool sent =
                        Ios6RelaySendData(
                            *_ios6Relay,
                            _ios6SelectedPeerHost,
                            _ios6SelectedPeerPort,
                            data,
                            size,
                            &error
                        );

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC dtls.tx.result ok=%d bytes=%lu error=%s",
                        sent ? 1 : 0,
                        (unsigned long)size,
                        error.c_str()
                    );

                    if (sent) {
                        addTrafficStats(
                            size,
                            false
                        );
                    }

                    return sent;
                }
            )
        );
    }

    if (!_ios6DtlsTransport->configure(
            certificate,
            privateKey,
            remoteHash,
            remoteFingerprint,
            remoteSetup,
            _isOutgoing
        )) {

        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.network.configure.failed"
        );

        return;
    }

    ios56MaybeStartDtls();
}

void NetworkManager::ios56MaybeStartDtls() {
    if (!_ios6TransportReady ||
        !_ios6DtlsTransport ||
        !_ios6DtlsTransport->isConfigured() ||
        _ios6DtlsTransport->isStarted() ||
        _ios6DtlsTransport->isFailed() ||
        _ios6DtlsTransport->isReady()) {

        return;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.network.start transportReady=%d role=%s",
        _ios6TransportReady ? 1 : 0,
        _ios6DtlsTransport->isClient()
            ? "client"
            : "server"
    );

    if (!_ios6DtlsTransport->start()) {
        ios56ApplyDtlsState();
        return;
    }

    ios56ApplyDtlsState();
    ios56ScheduleDtlsTimer();
}

void NetworkManager::ios56ApplyDtlsState() {
    if (!_ios6DtlsTransport) {
        return;
    }

    if (_ios6DtlsTransport->isFailed()) {
        if (_ios6DtlsStateAnnounced) {
            return;
        }

        _ios6DtlsStateAnnounced = true;
        _mediaTransport->clearPath();

        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.network.failed"
        );

        if (_stateUpdated) {
            _stateUpdated(OGCompatTransportState<State>(false));
        }

        return;
    }

    if (!_ios6DtlsTransport->isReady() ||
        _ios6DtlsStateAnnounced) {

        return;
    }

    _ios6DtlsStateAnnounced = true;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.network.ready exporter=%lu",
        (unsigned long)
            _ios6DtlsTransport
                ->srtpKeyMaterial()
                .size()
    );

    const std::shared_ptr<rtp::SrtpSession> srtp = rtp::SrtpSession::createFromDtlsKeyingMaterial(
        _ios6DtlsTransport->srtpKeyMaterial(),
        _ios6DtlsTransport->isClient()
    );

    if (!srtp) {
        syslog(
            LOG_ERR,
            "IOS6WEBRTC srtp.session.create.failed"
        );

        if (_stateUpdated) {
            _stateUpdated(OGCompatTransportState<State>(false));
        }

        return;
    }

    _mediaTransport->setPath(
        _ios6Relay,
        _ios6SelectedPeerHost,
        _ios6SelectedPeerPort,
        srtp
    );

    if (_stateUpdated) {
        _stateUpdated(OGCompatTransportState<State>(true));
    }
}

void NetworkManager::ios56ScheduleDtlsTimer() {
    const std::weak_ptr<NetworkManager> weak(
        shared_from_this()
    );

    const int64_t delay =
        (int64_t)250 *
        (int64_t)NSEC_PER_MSEC;

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            delay
        ),
        dispatch_get_global_queue(
            DISPATCH_QUEUE_PRIORITY_DEFAULT,
            0
        ),
        ^{
            const std::shared_ptr<NetworkManager> strong =
                weak.lock();

            if (!strong ||
                !strong->_ios6DtlsTransport ||
                strong->_ios6DtlsTransport->isReady() ||
                strong->_ios6DtlsTransport->isFailed()) {

                return;
            }

            strong->_thread->PostTask(
                [weak]() {
                    const std::shared_ptr<NetworkManager> inner =
                        weak.lock();

                    if (!inner ||
                        !inner->_ios6DtlsTransport ||
                        inner->_ios6DtlsTransport->isReady() ||
                        inner->_ios6DtlsTransport->isFailed()) {

                        return;
                    }

                    inner->_ios6DtlsTransport
                        ->handleTimeout();

                    inner->ios56ApplyDtlsState();

                    if (!inner->_ios6DtlsTransport->isReady() &&
                        !inner->_ios6DtlsTransport->isFailed()) {

                        inner->ios56ScheduleDtlsTimer();
                    }
                }
            );
        }
    );
}

void NetworkManager::ios56StartTransportReceiver() {
    if (_ios6ReceiverStarted ||
        !_ios6TransportReady ||
        _ios6TurnFd < 0 ||
        _ios6SelectedPeerHost.empty() ||
        _ios6SelectedPeerPort == 0) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.receiver.skip started=%d ready=%d fd=%d peer=%s:%u",
            _ios6ReceiverStarted ? 1 : 0,
            _ios6TransportReady ? 1 : 0,
            _ios6TurnFd,
            _ios6SelectedPeerHost.c_str(),
            (unsigned int)_ios6SelectedPeerPort
        );

        return;
    }

    _ios6ReceiverStarted = true;

    const std::shared_ptr<Ios6RelayConnection> connection = _ios6Relay;
    const std::shared_ptr<MediaTransport> mediaTransport = _mediaTransport;
    const int fd = connection->socket().descriptor();

    const std::string selectedPeerHost =
        _ios6SelectedPeerHost;

    const uint16_t selectedPeerPort =
        _ios6SelectedPeerPort;

    const std::string localUfrag =
        _localIceParameters.ufrag;

    const std::string localPassword =
        _localIceParameters.pwd;

    const std::string remoteUfrag =
        _remoteIceParameters.has_value()
            ? _remoteIceParameters->ufrag
            : std::string();

    const std::weak_ptr<NetworkManager> weak(
        shared_from_this()
    );

    rtc::Thread *thread =
        _thread;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC transport.receiver.start fd=%d peer=%s:%u",
        fd,
        selectedPeerHost.c_str(),
        (unsigned int)selectedPeerPort
    );

    dispatch_async(
        dispatch_get_global_queue(
            DISPATCH_QUEUE_PRIORITY_DEFAULT,
            0
        ),
        ^{
            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC transport.receiver.loop.enter fd=%d",
                fd
            );

            const bool isTcp = connection->socket().isTcp();
            double transientErrorStartMs = 0.0;

            for (;;) {
                if (weak.expired()) {
                    break;
                }

                Ios6RelayReceiveResult received =
                    Ios6RelayReceivePacket(
                        *connection,
                        selectedPeerHost,
                        selectedPeerPort,
                        localUfrag,
                        localPassword,
                        remoteUfrag
                    );

                if (received.timeout) {
                    continue;
                }

                if (!received.error.empty()) {
                    if (weak.expired()) {
                        break;
                    }

                    if (!isTcp && Ios6ReceiveErrorIsTransient(received.errorCode)) {
                        const double nowMs = Ios6LatencyNowMs();
                        if (transientErrorStartMs <= 0.0) {
                            transientErrorStartMs = nowMs;
                            syslog(
                                LOG_NOTICE,
                                "IOS6WEBRTC transport.receiver.transientError fd=%d errno=%d error=%s",
                                fd,
                                received.errorCode,
                                received.error.c_str()
                            );
                        }
                        if (nowMs - transientErrorStartMs < kIos6ReceiverTransientErrorGraceMs) {
                            usleep(kIos6ReceiverRetryDelayUs);
                            continue;
                        }
                    }

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC transport.receiver.recvError fd=%d errno=%d error=%s",
                        fd,
                        received.errorCode,
                        received.error.c_str()
                    );

                    thread->PostTask([weak]() {
                        const std::shared_ptr<NetworkManager> strong = weak.lock();
                        if (strong) {
                            strong->ios56HandleReceiverFailure();
                        }
                    });

                    break;
                }

                transientErrorStartMs = 0.0;

                if (received.kind ==
                    Ios6RelayReceiveResult::KindInnerStun) {

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC transport.receiver.innerStun type=0x%04x peer=%s:%u",
                        (unsigned int)received.innerStunType,
                        received.peerHost.c_str(),
                        (unsigned int)received.peerPort
                    );

                    continue;
                }

                if (received.kind !=
                        Ios6RelayReceiveResult::KindTransport ||
                    received.data.empty()) {

                    continue;
                }

                if (mediaTransport->handleIncomingDatagram(&received.data[0], received.data.size(), rtp::MonotonicMicros())) {
                    continue;
                }

                std::shared_ptr<std::vector<uint8_t> > payload(
                    new std::vector<uint8_t>(
                        received.data
                    )
                );

                const std::string sourcePeerHost =
                    received.peerHost;
                const uint16_t sourcePeerPort =
                    received.peerPort;

                thread->PostTask(
                    [weak, payload, sourcePeerHost, sourcePeerPort]() {
                        const std::shared_ptr<NetworkManager> strong =
                            weak.lock();

                        if (!strong) {
                            return;
                        }

                        if (!strong->_ios6TransportReady) {
                            syslog(
                                LOG_NOTICE,
                                "IOS6WEBRTC transport.recv.dropNotReady bytes=%lu",
                                (unsigned long)payload->size()
                            );

                            return;
                        }

                        if (payload->empty()) {
                            return;
                        }

                        strong->addTrafficStats(
                            payload->size(),
                            true
                        );

                        if (strong->_ios6DtlsTransport &&
                            strong->_ios6DtlsTransport->isConfigured()) {

                            if (Ios6DtlsTransport::looksLikeDtls(
                                    &(*payload)[0],
                                    payload->size()
                                )) {

                                if (!strong->_ios6MediaPeerLocked) {
                                    const bool changed =
                                        strong->_ios6SelectedPeerHost != sourcePeerHost ||
                                        strong->_ios6SelectedPeerPort != sourcePeerPort;

                                    if (changed) {
                                        syslog(
                                            LOG_NOTICE,
                                            "IOS6WEBRTC transport.mediaPeer.switch old=%s:%u new=%s:%u reason=firstDtls",
                                            strong->_ios6SelectedPeerHost.c_str(),
                                            (unsigned int)strong->_ios6SelectedPeerPort,
                                            sourcePeerHost.c_str(),
                                            (unsigned int)sourcePeerPort
                                        );
                                        strong->_ios6SelectedPeerHost = sourcePeerHost;
                                        strong->_ios6SelectedPeerPort = sourcePeerPort;
                                    }

                                    strong->_ios6MediaPeerLocked = true;
                                    syslog(
                                        LOG_NOTICE,
                                        "IOS6WEBRTC transport.mediaPeer.lock peer=%s:%u",
                                        strong->_ios6SelectedPeerHost.c_str(),
                                        (unsigned int)strong->_ios6SelectedPeerPort
                                    );
                                } else if (strong->_ios6SelectedPeerHost != sourcePeerHost ||
                                           strong->_ios6SelectedPeerPort != sourcePeerPort) {
                                    syslog(
                                        LOG_NOTICE,
                                        "IOS6WEBRTC transport.recv.dtls.dropAlternate peer=%s:%u locked=%s:%u bytes=%lu",
                                        sourcePeerHost.c_str(),
                                        (unsigned int)sourcePeerPort,
                                        strong->_ios6SelectedPeerHost.c_str(),
                                        (unsigned int)strong->_ios6SelectedPeerPort,
                                        (unsigned long)payload->size()
                                    );
                                    return;
                                }

                                syslog(
                                    LOG_NOTICE,
                                    "IOS6WEBRTC transport.recv.dtls bytes=%lu first=0x%02x peer=%s:%u",
                                    (unsigned long)payload->size(),
                                    (unsigned int)(*payload)[0],
                                    sourcePeerHost.c_str(),
                                    (unsigned int)sourcePeerPort
                                );

                                strong->_ios6DtlsTransport
                                    ->receiveDatagram(
                                        &(*payload)[0],
                                        payload->size()
                                    );

                                strong->ios56ApplyDtlsState();

                                return;
                            }

                            if (!strong->_ios6DtlsTransport
                                    ->isReady()) {

                                syslog(
                                    LOG_NOTICE,
                                    "IOS6WEBRTC transport.recv.srtp.notReady first=0x%02x bytes=%lu",
                                    (unsigned int)(*payload)[0],
                                    (unsigned long)payload->size()
                                );

                                return;
                            }

                            return;
                        }

                        auto decrypted =
                            strong->_transport.handleIncomingPacket(
                                (const char *)&(*payload)[0],
                                payload->size()
                            );

                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC transport.recv.decrypt has=%d additional=%lu",
                            decrypted ? 1 : 0,
                            decrypted
                                ? (unsigned long)decrypted->additional.size()
                                : 0UL
                        );

                        if (decrypted &&
                            strong->_transportMessageReceived) {

                            strong->_transportMessageReceived(
                                std::move(
                                    decrypted->main
                                )
                            );

                            for (auto &message :
                                 decrypted->additional) {

                                strong->_transportMessageReceived(
                                    std::move(message)
                                );
                            }

                            syslog(
                                LOG_NOTICE,
                                "IOS6WEBRTC transport.recv.dispatch.done"
                            );
                        }
                    }
                );
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC transport.receiver.loop.exit fd=%d",
                fd
            );
        }
    );
}


void NetworkManager::ios56HandleReceiverFailure() {
    if (_ios6ConnectionFailed) {
        return;
    }

    _ios6ConnectionFailed = true;
    _ios6TransportReady = false;
    _mediaTransport->clearPath();

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC transport.receiver.failed"
    );

    if (_stateUpdated) {
        _stateUpdated(OGCompatTransportState<State>(false));
    }
}

NetworkManager::~NetworkManager() {
    _ios6TransportReady = false;
    _mediaTransport->clearPath();
    if (_ios6TurnFd >= 0) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC turn.live.close fd=%d relay=%s:%u",
            _ios6TurnFd,
            _ios6TurnRelayHost.c_str(),
            (unsigned int)_ios6TurnRelayPort
        );

        _ios6TurnSocket->stop();
        _ios6TurnSocket.reset();
        _ios6TurnFd = -1;
    }
}

void NetworkManager::start() {
    _ios6ConnectStartMs = Ios6LatencyNowMs();
    _ios6RelayRetryDelayMs = 1000;

    static const char iceAlphabet[] =
        "abcdefghijklmnopqrstuvwxyz"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        "0123456789";

    _localIceParameters.ufrag.clear();
    _localIceParameters.pwd.clear();

    for (size_t i = 0; i < 8; ++i) {
        _localIceParameters.ufrag.push_back(
            iceAlphabet[arc4random() % (sizeof(iceAlphabet) - 1)]
        );
    }

    for (size_t i = 0; i < 24; ++i) {
        _localIceParameters.pwd.push_back(
            iceAlphabet[arc4random() % (sizeof(iceAlphabet) - 1)]
        );
    }

    _localIceParameters.supportsRenomination = true;
    _ios6IceTieBreaker =
        ((uint64_t)arc4random() << 32) |
        (uint64_t)arc4random();

    syslog(LOG_NOTICE, "IOS6WEBRTC core.revision ice=2 audio=2");

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC cxx.network.localIce ufragLen=%lu pwdLen=%lu controlling=%d tie=%llu",
        OGCompatCount(_localIceParameters.ufrag.size()),
        OGCompatCount(_localIceParameters.pwd.size()),
        OGCompatFlag(_isOutgoing),
        (unsigned long long)_ios6IceTieBreaker
    );

    ios56ScheduleConnectionTimeout();
    ios56AttemptRelayAllocation();
}

bool NetworkManager::ios56AllocateRelay() {
    std::vector<RtcServer> endpoints;
    for (int tcp = 0; tcp <= (_enableTCP ? 1 : 0); ++tcp) {
        for (size_t i = 0; i < _rtcServers.size(); ++i) {
            const RtcServer &configured = _rtcServers[i];
            if (!configured.isTurn || configured.isTcp != (tcp != 0)) continue;
            endpoints.push_back(configured);
        }
    }
    for (size_t i = 0; i < endpoints.size(); ++i) {
        const RtcServer &server = endpoints[i];
        syslog(LOG_NOTICE, "IOS6WEBRTC relay.server index=%lu id=%u host=%s port=%u reflector=%d tcp=%d", (unsigned long)i, (unsigned int)server.id, server.host.c_str(), (unsigned int)server.port, server.login == "reflector" ? 1 : 0, server.isTcp ? 1 : 0);
        std::shared_ptr<Ios6TurnSocket> connection;
        if (server.login == "reflector") {
            std::string error;
            connection = Ios6TurnSocket::connect(server.host, server.port, server.isTcp, &error, Ios6TurnSocket::FramingReflector);
            if (connection) {
                uint32_t tag = 0;
                while (tag == 0) tag = arc4random();
                std::shared_ptr<Ios6RelayConnection> relay = Ios6RelayConnection::reflector(connection, server.id, server.host, server.port, server.password, tag, &error);
                if (relay && relay->probe(&error)) {
                    _ios6Relay = relay;
                    _ios6TurnRelayHost = relay->localHost();
                    _ios6TurnRelayPort = relay->localPort();
                }
            }
            if (!_ios6Relay) {
                syslog(LOG_NOTICE, "IOS6WEBRTC reflector.open.fail tcp=%d error=%s", server.isTcp ? 1 : 0, error.c_str());
                continue;
            }
        } else {
            const Ios6TurnProbeResult probe = Ios6TurnAllocateProbe(server, true, &connection);
            syslog(LOG_NOTICE, "IOS6WEBRTC turn.allocate.result tcp=%d ok=%d relay=%s:%u error=%s", server.isTcp ? 1 : 0, probe.ok ? 1 : 0, probe.relayHost.c_str(), (unsigned int)probe.relayPort, probe.error.c_str());
            if (!probe.ok || !connection) continue;
            _ios6Relay = Ios6RelayConnection::turn(connection);
            _ios6TurnRealm = probe.realm;
            _ios6TurnNonce = probe.nonce;
            _ios6TurnRelayHost = probe.relayHost;
            _ios6TurnRelayPort = probe.relayPort;
            _ios6TurnLifetimeSeconds = probe.lifetimeSeconds != 0 ? probe.lifetimeSeconds : 60;
        }
        _ios6TurnSocket = connection;
        _ios6TurnFd = connection->descriptor();
        _ios6TurnServer = server;
        syslog(LOG_NOTICE, "IOS6WEBRTC relay.ready fd=%d reflector=%d tcp=%d candidate=%s:%u", _ios6TurnFd, _ios6Relay->isReflector() ? 1 : 0, server.isTcp ? 1 : 0, _ios6TurnRelayHost.c_str(), (unsigned int)_ios6TurnRelayPort);
        break;
    }

    if (!_ios6TurnSocket) {
        syslog(LOG_NOTICE, "IOS6WEBRTC turn.allocate.exhausted endpoints=%lu tcpAllowed=%d retryMs=%d", (unsigned long)endpoints.size(), _enableTCP ? 1 : 0, _ios6RelayRetryDelayMs);
        return false;
    }
    return true;
}

void NetworkManager::ios56AttemptRelayAllocation() {
    if (_ios6Relay || _ios6ConnectionFailed) {
        return;
    }
    if (ios56AllocateRelay()) {
        ios56RelayDidBecomeReady();
        return;
    }

    const int delayMs = _ios6RelayRetryDelayMs;
    _ios6RelayRetryDelayMs = std::min(_ios6RelayRetryDelayMs * 2, 8000);
    const std::weak_ptr<NetworkManager> weak(shared_from_this());
    rtc::Thread *thread = _thread;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)delayMs * 1000000LL),
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            thread->PostTask([weak]() {
                const std::shared_ptr<NetworkManager> strong = weak.lock();
                if (!strong) return;
                strong->ios56AttemptRelayAllocation();
            });
        }
    );
}

void NetworkManager::ios56RelayDidBecomeReady() {
    if (_ios6Relay && (_ios6Relay->isReflector() || (!_ios6TurnRealm.empty() && !_ios6TurnNonce.empty()))) {
        syslog(
            LOG_NOTICE,
            "IOS6LAT turn.lifecycle.start lifetime=%u relay=%s:%u",
            (unsigned int)_ios6TurnLifetimeSeconds,
            _ios6TurnRelayHost.c_str(),
            (unsigned int)_ios6TurnRelayPort
        );
        ios56ScheduleTurnMaintenance();
    }

    if (_sendSignalingMessage) {
        CandidatesListMessage candidates;
        candidates.iceParameters =
            _localIceParameters;

        if (_ios6TurnFd >= 0 &&
            !_ios6TurnRelayHost.empty() &&
            _ios6TurnRelayPort != 0) {
            char sdp[512];

            const unsigned int foundation =
                _ios6TurnServer.id != 0
                    ? (unsigned int)_ios6TurnServer.id
                    : 1U;

            snprintf(
                sdp,
                sizeof(sdp),
                "candidate:%u 1 udp 2130706430 %s %u typ relay raddr 0.0.0.0 rport 0 generation 0 ufrag %s network-id 1",
                foundation,
                _ios6TurnRelayHost.c_str(),
                (unsigned int)_ios6TurnRelayPort,
                _localIceParameters.ufrag.c_str()
            );

            candidates.candidates.push_back(OGCompatRelayCandidate(sdp));

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC cxx.network.localRelayCandidate host=%s port=%u sdp=%s",
                _ios6TurnRelayHost.c_str(),
                (unsigned int)_ios6TurnRelayPort,
                sdp
            );
        }

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC cxx.network.start candidates=%lu servers=%lu",
            OGCompatCount(candidates.candidates.size()),
            OGCompatCount(_rtcServers.size())
        );

        _sendSignalingMessage(OGCompatSignalingMessage(candidates));
    }

    if (_ios6RemoteCandidates) {
        ios56ProcessRemoteCandidates();
    }
}

bool NetworkManager::ios56IsConnected() const {
    if (!_ios6TransportReady) {
        return false;
    }
    if (_ios6DtlsTransport && _ios6DtlsTransport->isConfigured()) {
        return _ios6DtlsTransport->isReady();
    }
    return true;
}

void NetworkManager::ios56ScheduleConnectionTimeout() {
    const std::weak_ptr<NetworkManager> weak(shared_from_this());
    rtc::Thread *thread = _thread;
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, 1000000000LL),
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            thread->PostTask([weak]() {
                const std::shared_ptr<NetworkManager> strong = weak.lock();
                if (!strong) return;
                strong->checkConnectionTimeout();
            });
        }
    );
}

void NetworkManager::receiveSignalingMessage(
        DecryptedMessage &&message) {
    if (const CandidatesListMessage *candidates =
            absl::get_if<CandidatesListMessage>(
                &message.message.data
            )) {
        _ios6RemoteCandidates = *candidates;
        ios56ProcessRemoteCandidates();
        return;
    }

    RTC_LOG(LS_INFO)
        << "IOS6WEBRTC network.stub.unexpectedSignaling";
}

void NetworkManager::ios56RunIceProbe() {
    if (_ios6TransportReady) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC cxx.network.iceProbe.skipSelected selected=%s:%u",
            _ios6SelectedPeerHost.c_str(),
            (unsigned int)_ios6SelectedPeerPort
        );
        return;
    }

    const bool hasPeer =
        !_ios6TurnPeerHost.empty() &&
        _ios6TurnPeerPort != 0;

    const bool hasLocalIce =
        !_localIceParameters.ufrag.empty() &&
        !_localIceParameters.pwd.empty();

    const bool hasRemoteIce =
        _remoteIceParameters.has_value() &&
        !_remoteIceParameters->ufrag.empty() &&
        !_remoteIceParameters->pwd.empty();

    if (_ios6TurnFd < 0 ||
        !_ios6TurnPermissionReady ||
        !hasPeer ||
        !hasLocalIce ||
        !hasRemoteIce) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC cxx.network.iceProbe.defer fd=%d permission=%d peer=%d localIce=%d remoteIce=%d",
            _ios6TurnFd,
            _ios6TurnPermissionReady ? 1 : 0,
            hasPeer ? 1 : 0,
            hasLocalIce ? 1 : 0,
            hasRemoteIce ? 1 : 0
        );
        return;
    }

    if (_ios6IceProbeDone) {
        return;
    }

    const double iceCheckWindowMs =
        std::min(
            kIos6IceCheckWindowMs,
            kIos6ConnectTimeoutMs - (Ios6LatencyNowMs() - _ios6ConnectStartMs)
        );

    if (iceCheckWindowMs <= 0.0) {
        return;
    }

    _ios6IceProbeDone = true;

    std::string iceProbeError;
    std::string selectedPeerHost;
    uint16_t selectedPeerPort = 0;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC cxx.network.iceProbe.begin peer=%s:%u localUfrag=%s remoteUfrag=%s controlling=%d",
        _ios6TurnPeerHost.c_str(),
        (unsigned int)_ios6TurnPeerPort,
        _localIceParameters.ufrag.c_str(),
        _remoteIceParameters->ufrag.c_str(),
        _isOutgoing ? 1 : 0
    );

    const double iceProbeStartMs = Ios6LatencyNowMs();
    const bool iceProbeOk =
        Ios6RelayIceBindingProbe(
            *_ios6Relay,
            _ios6TurnPeerHost,
            _ios6TurnPeerPort,
            _localIceParameters.ufrag,
            _localIceParameters.pwd,
            _remoteIceParameters->ufrag,
            _remoteIceParameters->pwd,
            _ios6IceTieBreaker,
            _isOutgoing,
            false,
            iceCheckWindowMs,
            &selectedPeerHost,
            &selectedPeerPort,
            &iceProbeError
        );
    const double iceProbeRttMs = Ios6LatencyNowMs() - iceProbeStartMs;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC cxx.network.iceProbe ok=%d peer=%s:%u selected=%s:%u localUfrag=%s remoteUfrag=%s controlling=%d error=%s",
        iceProbeOk ? 1 : 0,
        _ios6TurnPeerHost.c_str(),
        (unsigned int)_ios6TurnPeerPort,
        selectedPeerHost.c_str(),
        (unsigned int)selectedPeerPort,
        _localIceParameters.ufrag.c_str(),
        _remoteIceParameters->ufrag.c_str(),
        _isOutgoing ? 1 : 0,
        iceProbeError.c_str()
    );
    syslog(
        LOG_NOTICE,
        "IOS6LAT ice probeRttMs=%.1f peer=%s:%u ok=%d",
        iceProbeRttMs,
        _ios6TurnPeerHost.c_str(),
        (unsigned int)_ios6TurnPeerPort,
        iceProbeOk ? 1 : 0
    );

    if (!iceProbeOk) {
        _ios6IceProbeDone = false;
        return;
    }

    if (_isOutgoing) {
        std::string iceNominateError;
        std::string nominatedPeerHost;
        uint16_t nominatedPeerPort = 0;

        const std::string nominationHost =
            selectedPeerHost.empty()
                ? _ios6TurnPeerHost
                : selectedPeerHost;

        const uint16_t nominationPort =
            selectedPeerPort == 0
                ? _ios6TurnPeerPort
                : selectedPeerPort;

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC cxx.network.iceNominate.begin peer=%s:%u",
            nominationHost.c_str(),
            (unsigned int)nominationPort
        );

        const double iceNominateStartMs = Ios6LatencyNowMs();
        const bool iceNominateOk =
            Ios6RelayIceBindingProbe(
                *_ios6Relay,
                nominationHost,
                nominationPort,
                _localIceParameters.ufrag,
                _localIceParameters.pwd,
                _remoteIceParameters->ufrag,
                _remoteIceParameters->pwd,
                _ios6IceTieBreaker,
                true,
                true,
                iceCheckWindowMs,
                &nominatedPeerHost,
                &nominatedPeerPort,
                &iceNominateError
            );
        const double iceNominateRttMs = Ios6LatencyNowMs() - iceNominateStartMs;

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC cxx.network.iceNominate ok=%d peer=%s:%u selected=%s:%u error=%s",
            iceNominateOk ? 1 : 0,
            nominationHost.c_str(),
            (unsigned int)nominationPort,
            nominatedPeerHost.c_str(),
            (unsigned int)nominatedPeerPort,
            iceNominateError.c_str()
        );
        syslog(
            LOG_NOTICE,
            "IOS6LAT ice nominateRttMs=%.1f peer=%s:%u ok=%d",
            iceNominateRttMs,
            nominationHost.c_str(),
            (unsigned int)nominationPort,
            iceNominateOk ? 1 : 0
        );

        if (!iceNominateOk) {
            _ios6IceProbeDone = false;
            return;
        }

        selectedPeerHost = nominatedPeerHost.empty()
            ? nominationHost
            : nominatedPeerHost;
        selectedPeerPort = nominatedPeerPort == 0
            ? nominationPort
            : nominatedPeerPort;
    }

    if (selectedPeerHost.empty() ||
        selectedPeerPort == 0) {
        _ios6IceProbeDone = false;
        return;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC cxx.network.iceSelected peer=%s:%u nominated=1 controlling=%d",
        selectedPeerHost.c_str(),
        (unsigned int)selectedPeerPort,
        _isOutgoing ? 1 : 0
    );

    _ios6SelectedPeerHost =
        selectedPeerHost;

    _ios6SelectedPeerPort =
        selectedPeerPort;

    _ios6TransportReady = true;

    ios56StartTransportReceiver();

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC transport.ready fd=%d peer=%s:%u",
        _ios6TurnFd,
        _ios6SelectedPeerHost.c_str(),
        (unsigned int)_ios6SelectedPeerPort
    );
    if (_ios6DtlsTransport &&
        _ios6DtlsTransport->isConfigured()) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.iceReady.waitDtls"
        );

        ios56MaybeStartDtls();
    } else if (_stateUpdated) {
        _stateUpdated(OGCompatTransportState<State>(true));
    }
}

void NetworkManager::ios56ProcessRemoteCandidates() {
    if (!_ios6RemoteCandidates) {
        return;
    }

    {
        const CandidatesListMessage *candidates = &*_ios6RemoteCandidates;
        if (!candidates->iceParameters.ufrag.empty() &&
            !candidates->iceParameters.pwd.empty()) {
            _remoteIceParameters =
                candidates->iceParameters;

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC cxx.network.remoteIce.readyForProbe ufrag=%s pwdLen=%lu",
                _remoteIceParameters->ufrag.c_str(),
                (unsigned long)_remoteIceParameters->pwd.size()
            );

            ios56RunIceProbe();
        }

        RTC_LOG(LS_INFO)
            << "IOS6WEBRTC network.remoteCandidates count="
            << candidates->candidates.size()
            << " ufragLen="
            << candidates->iceParameters.ufrag.size()
            << " pwdLen="
            << candidates->iceParameters.pwd.size();

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC cxx.network.remoteIce ufrag=%s pwdLen=%lu candidates=%lu",
            candidates->iceParameters.ufrag.c_str(),
            (unsigned long)candidates->iceParameters.pwd.size(),
            (unsigned long)candidates->candidates.size()
        );

        for (size_t i = 0;
             i < candidates->candidates.size();
             ++i) {
            const std::string sdp =
                candidates->candidates[i].ToString();

            std::istringstream stream(sdp);
            std::vector<std::string> fields;
            std::string field;

            while (stream >> field) {
                fields.push_back(field);
            }

            if (fields.size() >= 6 && fields[1] == "1" && fields[2] == "udp") {
                const std::string peerHost =
                    fields[4];

                const unsigned long parsedPort =
                    strtoul(
                        fields[5].c_str(),
                        NULL,
                        10
                    );

                if (parsedPort > 0 && parsedPort <= 65535UL && _ios6Relay && _ios6Relay->acceptsPeer(peerHost, static_cast<uint16_t>(parsedPort))) {
                    const uint16_t peerPort =
                        (uint16_t)parsedPort;

                    if (_ios6TransportReady) {
                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC cxx.network.candidate.ignoreSelected candidate=%s:%u selected=%s:%u",
                            peerHost.c_str(),
                            (unsigned int)peerPort,
                            _ios6SelectedPeerHost.c_str(),
                            (unsigned int)_ios6SelectedPeerPort
                        );

                        continue;
                    }

                    const bool peerChanged =
                        _ios6TurnPeerHost != peerHost ||
                        _ios6TurnPeerPort != peerPort;

                    if (peerChanged) {
                        _ios6TurnPermissionReady = false;
                        _ios6IceProbeDone = false;
                        _ios6TransportReady = false;
                    }

                    _ios6TurnPeerHost = peerHost;
                    _ios6TurnPeerPort = peerPort;

                    if (_ios6TurnFd >= 0 &&
                        !_ios6TurnPermissionReady) {
                        std::string permissionError;

                        const bool permissionOk = _ios6Relay->isReflector() ||
                            Ios6TurnCreatePermission(
                                *_ios6TurnSocket,
                                _ios6TurnServer,
                                _ios6TurnRealm,
                                &_ios6TurnNonce,
                                _ios6TurnPeerHost,
                                _ios6TurnPeerPort,
                                &permissionError
                            );

                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC cxx.network.turnPermission ok=%d peer=%s:%u error=%s",
                            permissionOk ? 1 : 0,
                            _ios6TurnPeerHost.c_str(),
                            (unsigned int)_ios6TurnPeerPort,
                            permissionError.c_str()
                        );

                        if (permissionOk) {
                            _ios6TurnPermissionReady = true;

                            syslog(
                                LOG_NOTICE,
                                "IOS6WEBRTC cxx.network.turnPermission.ready peer=%s:%u",
                                _ios6TurnPeerHost.c_str(),
                                (unsigned int)_ios6TurnPeerPort
                            );

                            ios56RunIceProbe();
                        }
                    } else if (_ios6TurnPermissionReady) {
                        ios56RunIceProbe();
                    }
                } else {
                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC cxx.network.turnPermission.skip host=%s port=%s",
                        peerHost.c_str(),
                        fields[5].c_str()
                    );
                }
            }

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC cxx.network.remoteCandidate index=%lu sdp=%s",
                (unsigned long)i,
                sdp.c_str()
            );
        }

        if (_ios6DtlsTransport &&
            _ios6DtlsTransport->isConfigured()) {

            syslog(
                LOG_NOTICE,
                "IOS6WEBRTC transport.state.waitDtls"
            );

            ios56MaybeStartDtls();
            ios56ApplyDtlsState();

        } else if (_stateUpdated &&
                   _ios6TransportReady) {

            _stateUpdated(OGCompatTransportState<State>(true));
        }

        return;
    }
}

uint32_t NetworkManager::sendMessage(
        const Message &message) {

    if (const CandidatesListMessage *candidates =
            absl::get_if<CandidatesListMessage>(
                &message.data
            )) {
        if (_sendSignalingMessage) {
            RTC_LOG(LS_INFO)
                << "IOS6WEBRTC network.stub.forwardCandidates count="
                << candidates->candidates.size()
                << " ufragLen="
                << candidates->iceParameters.ufrag.size()
                << " pwdLen="
                << candidates->iceParameters.pwd.size();

            _sendSignalingMessage(
                OGCompatSignalingMessage(*candidates)
            );
        }

        return 0;
    }

    if (!_ios6TransportReady ||
        _ios6TurnFd < 0 ||
        _ios6SelectedPeerHost.empty() ||
        _ios6SelectedPeerPort == 0) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.send.notReady fd=%d ready=%d peer=%s:%u",
            _ios6TurnFd,
            _ios6TransportReady ? 1 : 0,
            _ios6SelectedPeerHost.c_str(),
            (unsigned int)_ios6SelectedPeerPort
        );

        return 0;
    }

    if (_ios6DtlsTransport &&
        _ios6DtlsTransport->isConfigured()) {
        return 0;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC transport.send.prepare audio=%d",
        absl::get_if<AudioDataMessage>(
            &message.data
        ) ? 1 : 0
    );

    if (const auto prepared =
            _transport.prepareForSending(
                message
            )) {
        std::string sendError;

        const bool sent =
            Ios6RelaySendData(
                *_ios6Relay,
                _ios6SelectedPeerHost,
                _ios6SelectedPeerPort,
                prepared->bytes.data(),
                prepared->bytes.size(),
                &sendError
            );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.send.result ok=%d counter=%u bytes=%lu peer=%s:%u error=%s",
            sent ? 1 : 0,
            (unsigned int)prepared->counter,
            (unsigned long)prepared->bytes.size(),
            _ios6SelectedPeerHost.c_str(),
            (unsigned int)_ios6SelectedPeerPort,
            sendError.c_str()
        );

        if (sent) {
            addTrafficStats(
                prepared->bytes.size(),
                false
            );

            return prepared->counter;
        }

        return 0;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC transport.send.prepare.none"
    );

    return 0;
}

void NetworkManager::sendTransportService(
        int cause) {

    if (_ios6DtlsTransport &&
        _ios6DtlsTransport->isConfigured()) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.service.dtlsMode.skip cause=%d",
            cause
        );

        return;
    }
    if (!_ios6TransportReady ||
        _ios6TurnFd < 0 ||
        _ios6SelectedPeerHost.empty() ||
        _ios6SelectedPeerPort == 0) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.service.skip cause=%d ready=%d fd=%d",
            cause,
            _ios6TransportReady ? 1 : 0,
            _ios6TurnFd
        );

        return;
    }

    if (const auto prepared =
            _transport.prepareForSendingService(
                cause
            )) {
        std::string sendError;

        const bool sent =
            Ios6RelaySendData(
                *_ios6Relay,
                _ios6SelectedPeerHost,
                _ios6SelectedPeerPort,
                prepared->bytes.data(),
                prepared->bytes.size(),
                &sendError
            );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.service.send cause=%d ok=%d bytes=%lu error=%s",
            cause,
            sent ? 1 : 0,
            (unsigned long)prepared->bytes.size(),
            sendError.c_str()
        );

        if (sent) {
            addTrafficStats(
                prepared->bytes.size(),
                false
            );
        }
    } else {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC transport.service.none cause=%d",
            cause
        );
    }
}

void NetworkManager::setIsLocalNetworkLowCost(
        bool isLocalNetworkLowCost) {
    _isLocalNetworkLowCost =
        isLocalNetworkLowCost;
}

TrafficStats NetworkManager::getNetworkStats() {
    const MediaTransport::Statistics media = _mediaTransport->statistics();
    if (media.bytesSent > _mediaBytesSentAccounted || media.bytesReceived > _mediaBytesReceivedAccounted) {
        addTrafficStats((int64_t)(media.bytesSent - _mediaBytesSentAccounted), false);
        addTrafficStats((int64_t)(media.bytesReceived - _mediaBytesReceivedAccounted), true);
        _mediaBytesSentAccounted = media.bytesSent;
        _mediaBytesReceivedAccounted = media.bytesReceived;
    }

    TrafficStats stats;

    stats.bytesSentWifi =
        _trafficStatsWifi.outgoing;
    stats.bytesReceivedWifi =
        _trafficStatsWifi.incoming;

    stats.bytesSentMobile =
        _trafficStatsCellular.outgoing;
    stats.bytesReceivedMobile =
        _trafficStatsCellular.incoming;

    return stats;
}

void NetworkManager::fillCallStats(
        CallStats &) {
}

void NetworkManager::logCurrentNetworkState() {
}

void NetworkManager::checkConnectionTimeout() {
    if (_ios6ConnectionFailed || ios56IsConnected()) {
        return;
    }
    const double elapsedMs = Ios6LatencyNowMs() - _ios6ConnectStartMs;
    if (elapsedMs < kIos6ConnectTimeoutMs) {
        if (!_ios6TransportReady && !_ios6IceProbeDone && _remoteIceParameters.has_value()) {
            ios56RunIceProbe();
        }
        if (!_ios6ConnectionFailed && !ios56IsConnected()) {
            ios56ScheduleConnectionTimeout();
        }
        return;
    }
    _ios6ConnectionFailed = true;
    syslog(LOG_NOTICE, "IOS6WEBRTC network.connect.timeout elapsedMs=%.0f relay=%d transport=%d", elapsedMs, _ios6Relay ? 1 : 0, _ios6TransportReady ? 1 : 0);
    if (_stateUpdated) {
        _stateUpdated(OGCompatTransportState<State>(false));
    }
}

void NetworkManager::candidateGathered(
        cricket::IceTransportInternal *,
        const cricket::Candidate &) {
}

void NetworkManager::candidateGatheringState(
        cricket::IceTransportInternal *) {
}

void NetworkManager::transportStateChanged(
        cricket::IceTransportInternal *) {
}

void NetworkManager::transportReadyToSend(
        cricket::IceTransportInternal *) {
}

void NetworkManager::transportPacketReceived(
        rtc::PacketTransportInternal *,
        const char *,
        size_t,
        const int64_t &,
        int) {
}

void NetworkManager::transportRouteChanged(
        absl::optional<rtc::NetworkRoute>) {
}

void NetworkManager::addTrafficStats(
        int64_t byteCount,
        bool isIncoming) {
    if (_isLocalNetworkLowCost) {
        if (isIncoming) {
            _trafficStatsWifi.incoming +=
                byteCount;
        } else {
            _trafficStatsWifi.outgoing +=
                byteCount;
        }
    } else {
        if (isIncoming) {
            _trafficStatsCellular.incoming +=
                byteCount;
        } else {
            _trafficStatsCellular.outgoing +=
                byteCount;
        }
    }
}

} // namespace tgcalls

#else

#error "Recovered NetworkManager.cpp currently supports only TGCALLS_IOS6_AUDIO_ONLY"

#endif