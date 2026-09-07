#ifndef TGCALLS_IOS6_DTLS_TRANSPORT_H
#define TGCALLS_IOS6_DTLS_TRANSPORT_H

#include <pthread.h>
#include <deque>
#include <functional>
#include <string>
#include <vector>
#include <stdint.h>
#include <stddef.h>

#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <openssl/evp.h>

namespace tgcalls {

class Ios6DtlsTransport {
public:
    typedef std::function<bool(const uint8_t *, size_t)> SendCallback;

    explicit Ios6DtlsTransport(SendCallback sendCallback);
    ~Ios6DtlsTransport();

    bool configure(
        X509 *certificate,
        EVP_PKEY *privateKey,
        const std::string &remoteHash,
        const std::string &remoteFingerprint,
        const std::string &remoteSetup,
        bool isOutgoing
    );

    bool start();

    void receiveDatagram(
        const uint8_t *data,
        size_t size
    );

    void handleTimeout();

    bool isConfigured() const;
    bool isStarted() const;
    bool isReady() const;
    bool isFailed() const;
    bool isClient() const;

    const std::vector<uint8_t> &srtpKeyMaterial() const;

    bool protectRtp(
        std::vector<uint8_t> &packet
    );

    bool unprotectRtp(
        std::vector<uint8_t> &packet
    );

    static bool looksLikeDtls(
        const uint8_t *data,
        size_t size
    );

private:
    Ios6DtlsTransport(const Ios6DtlsTransport &);
    Ios6DtlsTransport &operator=(const Ios6DtlsTransport &);

    static BIO_METHOD *bioMethod();

    static int bioCreate(BIO *bio);
    static int bioDestroy(BIO *bio);
    static int bioRead(BIO *bio, char *out, int outl);
    static int bioWrite(BIO *bio, const char *in, int inl);
    static int bioPuts(BIO *bio, const char *str);
    static long bioCtrl(BIO *bio, int cmd, long num, void *ptr);

    bool driveHandshake();
    bool finishHandshake();

    bool prepareSrtpKeys(
        bool sending
    );

    void fail(const char *where);

    static std::string normalizeFingerprint(
        const std::string &value
    );

    static std::string fingerprintForCertificate(
        X509 *certificate
    );

private:
    SendCallback _sendCallback;

    SSL_CTX *_ctx;
    SSL *_ssl;

    std::deque<std::vector<uint8_t> > _incoming;

    // Serializes all access to the OpenSSL SSL object and DTLS input queue.
    // Recursive because start()/receiveDatagram()/handleTimeout() call
    // driveHandshake() while already holding this mutex.
    pthread_mutex_t _mutex;

    bool _configured;
    bool _started;
    bool _ready;
    bool _failed;
    bool _isClient;

    int _mtu;

    std::string _remoteHash;
    std::string _remoteFingerprint;
    std::string _remoteSetup;

    std::vector<uint8_t> _srtpSendEncryptionKey;
    std::vector<uint8_t> _srtpSendAuthenticationKey;
    std::vector<uint8_t> _srtpSendSalt;

    std::vector<uint8_t> _srtpRecvEncryptionKey;
    std::vector<uint8_t> _srtpRecvAuthenticationKey;
    std::vector<uint8_t> _srtpRecvSalt;

    uint32_t _srtpSendRoc;
    uint32_t _srtpRecvRoc;

    uint32_t _srtpSendSsrc;
    uint32_t _srtpRecvSsrc;

    uint16_t _srtpSendLastSequence;
    uint16_t _srtpRecvLastSequence;

    bool _srtpSendInitialized;
    bool _srtpRecvInitialized;

    std::vector<uint8_t> _srtpKeyMaterial;
};

} // namespace tgcalls

#endif
