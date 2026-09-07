#include "Ios6DtlsTransport.h"

#include <openssl/aes.h>
#include <openssl/hmac.h>
#include <openssl/evp.h>

#include <string.h>

#include <algorithm>
#include <cctype>
#include <cstring>
#include <sstream>
#include <iomanip>
#include <cstdio>

#include <syslog.h>

#include <openssl/err.h>
#include <openssl/ec.h>
#include <openssl/obj_mac.h>

#include "Ios6DiagnosticLog.h"

namespace tgcalls {

namespace {

class Ios6DtlsScopedLock {
public:
    explicit Ios6DtlsScopedLock(
        pthread_mutex_t *mutex
    )
    :
        _mutex(mutex)
    {
        pthread_mutex_lock(_mutex);
    }

    ~Ios6DtlsScopedLock() {
        pthread_mutex_unlock(_mutex);
    }

private:
    Ios6DtlsScopedLock(
        const Ios6DtlsScopedLock &
    );

    Ios6DtlsScopedLock &operator=(
        const Ios6DtlsScopedLock &
    );

private:
    pthread_mutex_t *_mutex;
};

static int ios6DtlsVerifyPeerCertificate(
    int preverifyOk,
    X509_STORE_CTX *store
) {
    int errorCode = 0;
    int depth = -1;

    if (store != NULL) {
        errorCode =
            X509_STORE_CTX_get_error(
                store
            );

        depth =
            X509_STORE_CTX_get_error_depth(
                store
            );
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.verify.callback preverify=%d error=%d depth=%d",
        preverifyOk,
        errorCode,
        depth
    );

    return 1;
}

}

static uint16_t ios6DtlsRead16(const uint8_t *p) {
    return
        ((uint16_t)p[0] << 8) |
        ((uint16_t)p[1]);
}

static uint32_t ios6DtlsRead24(const uint8_t *p) {
    return
        ((uint32_t)p[0] << 16) |
        ((uint32_t)p[1] << 8) |
        ((uint32_t)p[2]);
}

static const char *ios6DtlsHandshakeName(
    uint8_t type
) {
    switch (type) {
        case 0:  return "HelloRequest";
        case 1:  return "ClientHello";
        case 2:  return "ServerHello";
        case 3:  return "HelloVerifyRequest";
        case 11: return "Certificate";
        case 12: return "ServerKeyExchange";
        case 13: return "CertificateRequest";
        case 14: return "ServerHelloDone";
        case 15: return "CertificateVerify";
        case 16: return "ClientKeyExchange";
        case 20: return "Finished";
        default: return "Unknown";
    }
}

static void ios6DtlsLogFlight(
    const char *direction,
    const uint8_t *data,
    size_t size
) {
    if (data == NULL || size == 0) {
        return;
    }

    size_t offset = 0;
    unsigned int recordIndex = 0;

    while (offset + 13 <= size) {
        const uint8_t contentType =
            data[offset];

        const uint8_t versionMajor =
            data[offset + 1];

        const uint8_t versionMinor =
            data[offset + 2];

        const uint16_t epoch =
            ios6DtlsRead16(
                data + offset + 3
            );

        const uint16_t recordLength =
            ios6DtlsRead16(
                data + offset + 11
            );

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC dtls.flight dir=%s record=%u type=%u version=%02x%02x epoch=%u len=%u total=%lu",
            direction,
            recordIndex,
            (unsigned int)contentType,
            (unsigned int)versionMajor,
            (unsigned int)versionMinor,
            (unsigned int)epoch,
            (unsigned int)recordLength,
            (unsigned long)size
        );

        const size_t recordStart =
            offset + 13;

        const size_t recordEnd =
            recordStart +
            (size_t)recordLength;

        if (recordEnd > size) {
            syslog(
                LOG_ERR,
                "IOS6WEBRTC dtls.flight.truncated dir=%s record=%u need=%lu have=%lu",
                direction,
                recordIndex,
                (unsigned long)recordEnd,
                (unsigned long)size
            );

            break;
        }

        if (contentType == 22) {
            size_t p =
                recordStart;

            unsigned int handshakeIndex = 0;

            while (p + 12 <= recordEnd) {
                const uint8_t handshakeType =
                    data[p];

                const uint32_t messageLength =
                    ios6DtlsRead24(
                        data + p + 1
                    );

                const uint16_t messageSeq =
                    ios6DtlsRead16(
                        data + p + 4
                    );

                const uint32_t fragmentOffset =
                    ios6DtlsRead24(
                        data + p + 6
                    );

                const uint32_t fragmentLength =
                    ios6DtlsRead24(
                        data + p + 9
                    );

                syslog(
                    LOG_NOTICE,
                    "IOS6WEBRTC dtls.flight.hs dir=%s record=%u hs=%u type=%u name=%s msgLen=%lu seq=%u fragOff=%lu fragLen=%lu",
                    direction,
                    recordIndex,
                    handshakeIndex,
                    (unsigned int)handshakeType,
                    ios6DtlsHandshakeName(
                        handshakeType
                    ),
                    (unsigned long)messageLength,
                    (unsigned int)messageSeq,
                    (unsigned long)fragmentOffset,
                    (unsigned long)fragmentLength
                );


                const uint8_t *body =
                    data + p + 12;

                if (handshakeType == 2 &&
                    fragmentLength >= 38) {

                    const uint8_t sessionIdLength =
                        body[34];

                    const size_t cipherOffset =
                        35 +
                        (size_t)sessionIdLength;

                    if (cipherOffset + 3 <=
                        (size_t)fragmentLength) {

                        const uint16_t cipherSuite =
                            ios6DtlsRead16(
                                body + cipherOffset
                            );

                        const uint8_t compression =
                            body[cipherOffset + 2];

                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC dtls.serverHello version=%02x%02x sessionIdLen=%u cipher=0x%04x compression=%u",
                            (unsigned int)body[0],
                            (unsigned int)body[1],
                            (unsigned int)sessionIdLength,
                            (unsigned int)cipherSuite,
                            (unsigned int)compression
                        );
                    }
                }

                if (handshakeType == 12 &&
                    fragmentLength >= 4) {

                    const uint8_t curveType =
                        body[0];

                    const uint16_t namedCurve =
                        ios6DtlsRead16(
                            body + 1
                        );

                    const uint8_t publicKeyLength =
                        body[3];

                    const size_t pointEnd =
                        4 +
                        (size_t)publicKeyLength;

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC dtls.ske curveType=%u namedCurve=%u publicKeyLen=%u firstPointByte=0x%02x fragmentLen=%lu pointEnd=%lu",
                        (unsigned int)curveType,
                        (unsigned int)namedCurve,
                        (unsigned int)publicKeyLength,
                        publicKeyLength != 0 &&
                        fragmentLength >= 5
                            ? (unsigned int)body[4]
                            : 0,
                        (unsigned long)fragmentLength,
                        (unsigned long)pointEnd
                    );

                    if (pointEnd <=
                        (size_t)fragmentLength &&
                        pointEnd + 4 <=
                        (size_t)fragmentLength) {

                        const uint8_t hashAlgorithm =
                            body[pointEnd];

                        const uint8_t signatureAlgorithm =
                            body[pointEnd + 1];

                        const uint16_t signatureLength =
                            ios6DtlsRead16(
                                body + pointEnd + 2
                            );

                        syslog(
                            LOG_NOTICE,
                            "IOS6WEBRTC dtls.ske.signature hash=%u signature=%u signatureLen=%u bytesAfterHeader=%lu",
                            (unsigned int)hashAlgorithm,
                            (unsigned int)signatureAlgorithm,
                            (unsigned int)signatureLength,
                            (unsigned long)(
                                fragmentLength -
                                pointEnd -
                                4
                            )
                        );
                    } else {
                        syslog(
                            LOG_ERR,
                            "IOS6WEBRTC dtls.ske.invalidPointLength publicKeyLen=%u fragmentLen=%lu",
                            (unsigned int)publicKeyLength,
                            (unsigned long)fragmentLength
                        );
                    }

                    char hex[512];
                    size_t hexPos = 0;

                    const size_t dumpLength =
                        std::min(
                            (size_t)80,
                            (size_t)fragmentLength
                        );

                    for (size_t j = 0;
                         j < dumpLength &&
                         hexPos + 3 < sizeof(hex);
                         ++j) {

                        const int written =
                            snprintf(
                                hex + hexPos,
                                sizeof(hex) - hexPos,
                                "%02X",
                                (unsigned int)body[j]
                            );

                        if (written <= 0) {
                            break;
                        }

                        hexPos +=
                            (size_t)written;
                    }

                    hex[hexPos] =
                        '\0';

                    syslog(
                        LOG_NOTICE,
                        "IOS6WEBRTC dtls.ske.hex bytes=%lu data=%s",
                        (unsigned long)dumpLength,
                        hex
                    );
                }

                const size_t consumed =
                    12 +
                    (size_t)fragmentLength;

                if (consumed <= 12 ||
                    p + consumed > recordEnd) {

                    break;
                }

                p += consumed;
                ++handshakeIndex;
            }
        }

        offset =
            recordEnd;

        ++recordIndex;
    }

    if (offset != size) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC dtls.flight.trailing dir=%s offset=%lu total=%lu trailing=%lu",
            direction,
            (unsigned long)offset,
            (unsigned long)size,
            (unsigned long)(size - offset)
        );
    }
}

Ios6DtlsTransport::Ios6DtlsTransport(
    SendCallback sendCallback
) :
    _sendCallback(sendCallback),
    _ctx(NULL),
    _ssl(NULL),
    _configured(false),
    _started(false),
    _ready(false),
    _failed(false),
    _isClient(false),
    _mtu(1200) {

    pthread_mutexattr_t ios6MutexAttr;

    pthread_mutexattr_init(
        &ios6MutexAttr
    );

    pthread_mutexattr_settype(
        &ios6MutexAttr,
        PTHREAD_MUTEX_RECURSIVE
    );

    const int ios6MutexResult =
        pthread_mutex_init(
            &_mutex,
            &ios6MutexAttr
        );

    pthread_mutexattr_destroy(
        &ios6MutexAttr
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.mutex.ready result=%d",
        ios6MutexResult
    );

}

Ios6DtlsTransport::~Ios6DtlsTransport() {
    if (_ssl != NULL) {
        SSL_free(_ssl);
        _ssl = NULL;
    }

    if (_ctx != NULL) {
        SSL_CTX_free(_ctx);
        _ctx = NULL;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.mutex.destroy"
    );

    pthread_mutex_destroy(
        &_mutex
    );

}

BIO_METHOD *Ios6DtlsTransport::bioMethod() {
    static BIO_METHOD method = {
        BIO_TYPE_DGRAM,
        "Onegram DTLS TURN BIO",
        &Ios6DtlsTransport::bioWrite,
        &Ios6DtlsTransport::bioRead,
        &Ios6DtlsTransport::bioPuts,
        NULL,
        &Ios6DtlsTransport::bioCtrl,
        &Ios6DtlsTransport::bioCreate,
        &Ios6DtlsTransport::bioDestroy,
        NULL
    };

    return &method;
}

int Ios6DtlsTransport::bioCreate(BIO *bio) {
    if (bio == NULL) {
        return 0;
    }

    bio->init = 1;
    bio->num = 0;
    bio->ptr = NULL;
    bio->flags = 0;

    return 1;
}

int Ios6DtlsTransport::bioDestroy(BIO *bio) {
    if (bio == NULL) {
        return 0;
    }

    bio->ptr = NULL;
    bio->init = 0;
    bio->flags = 0;

    return 1;
}

int Ios6DtlsTransport::bioRead(
    BIO *bio,
    char *out,
    int outl
) {
    if (bio == NULL ||
        out == NULL ||
        outl <= 0) {
        return 0;
    }

    Ios6DtlsTransport *owner =
        static_cast<Ios6DtlsTransport *>(bio->ptr);

    if (owner == NULL) {
        return 0;
    }

    BIO_clear_retry_flags(bio);

    if (owner->_incoming.empty()) {
        BIO_set_retry_read(bio);
        return -1;
    }

    std::vector<uint8_t> datagram =
        owner->_incoming.front();

    owner->_incoming.pop_front();

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.bio.read request=%d datagram=%lu queued=%lu",
        outl,
        (unsigned long)datagram.size(),
        (unsigned long)owner->_incoming.size()
    );

    const size_t amount =
        std::min(
            (size_t)outl,
            datagram.size()
        );

    if (amount < datagram.size()) {
        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.bio.read.TRUNCATED request=%d datagram=%lu returned=%lu dropped=%lu",
            outl,
            (unsigned long)datagram.size(),
            (unsigned long)amount,
            (unsigned long)(
                datagram.size() -
                amount
            )
        );
    }

    if (amount != 0) {
        memcpy(
            out,
            &datagram[0],
            amount
        );
    }

    return (int)amount;
}

int Ios6DtlsTransport::bioWrite(
    BIO *bio,
    const char *in,
    int inl
) {
    if (bio == NULL ||
        in == NULL ||
        inl <= 0) {
        return 0;
    }

    Ios6DtlsTransport *owner =
        static_cast<Ios6DtlsTransport *>(bio->ptr);

    if (owner == NULL) {
        return 0;
    }

    BIO_clear_retry_flags(bio);

    ios6DtlsLogFlight(
        "out",
        reinterpret_cast<const uint8_t *>(in),
        (size_t)inl
    );
    
    const bool sent =
        owner->_sendCallback(
            reinterpret_cast<const uint8_t *>(in),
            (size_t)inl
        );

    if (!sent) {
        BIO_set_retry_write(bio);
        return -1;
    }

    return inl;
}

int Ios6DtlsTransport::bioPuts(
    BIO *bio,
    const char *str
) {
    if (str == NULL) {
        return 0;
    }

    return bioWrite(
        bio,
        str,
        (int)strlen(str)
    );
}

long Ios6DtlsTransport::bioCtrl(
    BIO *bio,
    int cmd,
    long num,
    void *ptr
) {
    Ios6DtlsTransport *owner =
        bio != NULL
            ? static_cast<Ios6DtlsTransport *>(bio->ptr)
            : NULL;

    (void)ptr;

    switch (cmd) {
        case BIO_CTRL_FLUSH:
            return 1;

        case BIO_CTRL_EOF:
            return 0;

        case BIO_CTRL_PENDING:
            if (owner != NULL &&
                !owner->_incoming.empty()) {
                return
                    (long)owner->_incoming.front().size();
            }
            return 0;

        case BIO_CTRL_WPENDING:
            return 0;

#ifdef BIO_CTRL_DGRAM_QUERY_MTU
        case BIO_CTRL_DGRAM_QUERY_MTU:
            return owner != NULL
                ? owner->_mtu
                : 1200;
#endif

#ifdef BIO_CTRL_DGRAM_GET_MTU
        case BIO_CTRL_DGRAM_GET_MTU:
            return owner != NULL
                ? owner->_mtu
                : 1200;
#endif

#ifdef BIO_CTRL_DGRAM_SET_MTU
        case BIO_CTRL_DGRAM_SET_MTU:
            if (owner != NULL &&
                num > 0) {
                owner->_mtu = (int)num;
            }
            return num;
#endif

#ifdef BIO_CTRL_DGRAM_GET_FALLBACK_MTU
        case BIO_CTRL_DGRAM_GET_FALLBACK_MTU:
            return 1200;
#endif

#ifdef BIO_CTRL_DGRAM_GET_MTU_OVERHEAD
        case BIO_CTRL_DGRAM_GET_MTU_OVERHEAD:
            return 28;
#endif

#ifdef BIO_CTRL_DGRAM_MTU_EXCEEDED
        case BIO_CTRL_DGRAM_MTU_EXCEEDED:
            return 0;
#endif

#ifdef BIO_CTRL_DGRAM_SET_NEXT_TIMEOUT
        case BIO_CTRL_DGRAM_SET_NEXT_TIMEOUT:
            return 1;
#endif

#ifdef BIO_CTRL_DGRAM_SET_RECV_TIMEOUT
        case BIO_CTRL_DGRAM_SET_RECV_TIMEOUT:
            return 1;
#endif

#ifdef BIO_CTRL_DGRAM_SET_SEND_TIMEOUT
        case BIO_CTRL_DGRAM_SET_SEND_TIMEOUT:
            return 1;
#endif

#ifdef BIO_CTRL_DGRAM_GET_RECV_TIMER_EXP
        case BIO_CTRL_DGRAM_GET_RECV_TIMER_EXP:
            return 0;
#endif

#ifdef BIO_CTRL_DGRAM_GET_SEND_TIMER_EXP
        case BIO_CTRL_DGRAM_GET_SEND_TIMER_EXP:
            return 0;
#endif

        default:
            break;
    }

    return 1;
}

std::string Ios6DtlsTransport::normalizeFingerprint(
    const std::string &value
) {
    std::string result;

    for (size_t i = 0;
         i < value.size();
         ++i) {

        const unsigned char c =
            (unsigned char)value[i];

        if (std::isxdigit(c)) {
            result.push_back(
                (char)std::toupper(c)
            );
        }
    }

    return result;
}

std::string Ios6DtlsTransport::fingerprintForCertificate(
    X509 *certificate
) {
    if (certificate == NULL) {
        return std::string();
    }

    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digestLength = 0;

    if (X509_digest(
            certificate,
            EVP_sha256(),
            digest,
            &digestLength
        ) != 1) {

        return std::string();
    }

    std::ostringstream result;

    result
        << std::uppercase
        << std::hex
        << std::setfill('0');

    for (unsigned int i = 0;
         i < digestLength;
         ++i) {

        if (i != 0) {
            result << ':';
        }

        result
            << std::setw(2)
            << (unsigned int)digest[i];
    }

    return result.str();
}

void Ios6DtlsTransport::fail(
    const char *where
) {
    _failed = true;
    _ready = false;

    unsigned int errorIndex = 0;

    for (;;) {
        const unsigned long error =
            ERR_get_error();

        if (error == 0) {
            break;
        }

        char buffer[256];
        buffer[0] = '\0';

        ERR_error_string_n(
            error,
            buffer,
            sizeof(buffer)
        );

        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.openssl.error where=%s index=%u code=0x%08lx value=%s",
            where != NULL ? where : "",
            errorIndex,
            error,
            buffer
        );

        ++errorIndex;
    }

    syslog(
        LOG_ERR,
        "IOS6WEBRTC dtls.fail where=%s errors=%u",
        where != NULL ? where : "",
        errorIndex
    );
}

bool Ios6DtlsTransport::configure(
    X509 *certificate,
    EVP_PKEY *privateKey,
    const std::string &remoteHash,
    const std::string &remoteFingerprint,
    const std::string &remoteSetup,
    bool isOutgoing
) {

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.lock.configure thread=%p",
        (void *)pthread_self()
    );

    Ios6DtlsScopedLock ios6Lock(
        &_mutex
    );

    if (_started) {
        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.configure.afterStart"
        );
        return false;
    }

    if (certificate == NULL ||
        privateKey == NULL) {
        fail("missingLocalCertificate");
        return false;
    }

    std::string hash = remoteHash;

    std::transform(
        hash.begin(),
        hash.end(),
        hash.begin(),
        ::tolower
    );

    if (hash != "sha-256") {
        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.remote.unsupportedHash hash=%s",
            remoteHash.c_str()
        );

        fail("remoteHash");
        return false;
    }

    _remoteHash =
        remoteHash;

    _remoteFingerprint =
        remoteFingerprint;

    _remoteSetup =
        remoteSetup;

    if (remoteSetup == "active") {
        _isClient = false;
    } else if (remoteSetup == "passive") {
        _isClient = true;
    } else {
        _isClient = isOutgoing;
    }

    SSL_library_init();
    SSL_load_error_strings();
    OpenSSL_add_all_algorithms();

    _ctx =
        SSL_CTX_new(
            DTLS_method()
        );

    if (_ctx == NULL) {
        fail("SSL_CTX_new");
        return false;
    }

    int verifyMode =
        SSL_VERIFY_NONE;

    int (*verifyCallback)(int, X509_STORE_CTX *) =
        NULL;

    if (!_isClient) {
        verifyMode =
            SSL_VERIFY_PEER |
            SSL_VERIFY_FAIL_IF_NO_PEER_CERT;

        verifyCallback =
            ios6DtlsVerifyPeerCertificate;
    }

    SSL_CTX_set_verify(
        _ctx,
        verifyMode,
        verifyCallback
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.verify.configure role=%s mode=0x%x fingerprintAuth=1",
        _isClient ? "client" : "server",
        verifyMode
    );

    SSL_CTX_set_read_ahead(
        _ctx,
        1
    );

    if (SSL_CTX_set_cipher_list(
            _ctx,
            "ECDHE-ECDSA-AES128-GCM-SHA256:"
            "ECDHE-ECDSA-AES128-SHA:"
            "ECDHE-ECDSA-AES256-SHA"
        ) != 1) {

        fail("SSL_CTX_set_cipher_list");
        return false;
    }

    if (SSL_CTX_use_certificate(
            _ctx,
            certificate
        ) != 1) {

        fail("SSL_CTX_use_certificate");
        return false;
    }

    if (SSL_CTX_use_PrivateKey(
            _ctx,
            privateKey
        ) != 1) {

        fail("SSL_CTX_use_PrivateKey");
        return false;
    }

    if (SSL_CTX_check_private_key(
            _ctx
        ) != 1) {

        fail("SSL_CTX_check_private_key");
        return false;
    }

    EC_KEY *ecdh =
        EC_KEY_new_by_curve_name(
            NID_X9_62_prime256v1
        );

    if (ecdh == NULL) {
        fail("EC_KEY_new_by_curve_name");
        return false;
    }

    const int ecdhOk =
        SSL_CTX_set_tmp_ecdh(
            _ctx,
            ecdh
        );

    EC_KEY_free(ecdh);

    if (ecdhOk != 1) {
        fail("SSL_CTX_set_tmp_ecdh");
        return false;
    }

    if (SSL_CTX_set_tlsext_use_srtp(
            _ctx,
            "SRTP_AES128_CM_SHA1_80"
        ) != 0) {

        fail("SSL_CTX_set_tlsext_use_srtp");
        return false;
    }

    _ssl =
        SSL_new(
            _ctx
        );

    if (_ssl == NULL) {
        fail("SSL_new");
        return false;
    }

#ifdef SSL_OP_NO_QUERY_MTU
    SSL_set_options(
        _ssl,
        SSL_OP_NO_QUERY_MTU
    );
#endif

#ifdef SSL_CTRL_SET_MTU
    SSL_ctrl(
        _ssl,
        SSL_CTRL_SET_MTU,
        _mtu,
        NULL
    );
#endif

    BIO *readBio =
        BIO_new(
            bioMethod()
        );

    BIO *writeBio =
        BIO_new(
            bioMethod()
        );

    if (readBio == NULL ||
        writeBio == NULL) {

        if (readBio != NULL) {
            BIO_free(readBio);
        }

        if (writeBio != NULL) {
            BIO_free(writeBio);
        }

        fail("BIO_new");
        return false;
    }

    readBio->ptr = this;
    writeBio->ptr = this;

    SSL_set_bio(
        _ssl,
        readBio,
        writeBio
    );

    if (_isClient) {
        SSL_set_connect_state(
            _ssl
        );
    } else {
        SSL_set_accept_state(
            _ssl
        );
    }

    _configured = true;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.configure.ok role=%s remoteHash=%s setup=%s remoteFingerprint=%s",
        _isClient ? "client" : "server",
        _remoteHash.c_str(),
        _remoteSetup.c_str(),
        _remoteFingerprint.c_str()
    );

    return true;
}

bool Ios6DtlsTransport::start() {

    // IOS6_DTLS_LOCK_START
    Ios6DtlsScopedLock ios6Lock(
        &_mutex
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.lock.start thread=%p",
        (void *)pthread_self()
    );

    if (!_configured ||
        _ssl == NULL ||
        _failed) {
        return false;
    }

    if (_started) {
        return true;
    }

    _started = true;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.handshake.begin role=%s",
        _isClient ? "client" : "server"
    );

    return driveHandshake();
}

bool Ios6DtlsTransport::driveHandshake() {

    Ios6DtlsScopedLock ios6Lock(
        &_mutex
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.lock.drive thread=%p",
        (void *)pthread_self()
    );

    if (_ssl == NULL ||
        _failed ||
        _ready) {
        return !_failed;
    }

    ERR_clear_error();

    const int result =
        SSL_do_handshake(
            _ssl
        );

    if (result == 1) {
        return finishHandshake();
    }

    const int error =
        SSL_get_error(
            _ssl,
            result
        );

    if (error == SSL_ERROR_WANT_READ ||
        error == SSL_ERROR_WANT_WRITE) {

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC dtls.handshake.progress want=%s",
            error == SSL_ERROR_WANT_READ
                ? "read"
                : "write"
        );

        return true;
    }

    const SSL_CIPHER *currentCipher =
        SSL_get_current_cipher(
            _ssl
        );
    
    syslog(
        LOG_ERR,
        "IOS6WEBRTC dtls.handshake.error sslError=%d result=%d state=%s version=%s cipher=%s",
        error,
        result,
        SSL_state_string_long(_ssl),
        SSL_get_version(_ssl),
        currentCipher != NULL
           ? SSL_CIPHER_get_name(currentCipher)
           : "none"
    );

    fail("SSL_do_handshake");

    return false;
}

bool Ios6DtlsTransport::finishHandshake() {
    X509 *peer =
        SSL_get_peer_certificate(
            _ssl
        );

    if (peer == NULL) {
        fail("SSL_get_peer_certificate");
        return false;
    }

    const std::string actualFingerprint =
        fingerprintForCertificate(
            peer
        );

    X509_free(peer);

    const std::string expectedNormalized =
        normalizeFingerprint(
            _remoteFingerprint
        );

    const std::string actualNormalized =
        normalizeFingerprint(
            actualFingerprint
        );

    if (expectedNormalized.empty() ||
        actualNormalized.empty() ||
        expectedNormalized != actualNormalized) {

        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.peerFingerprint.mismatch expected=%s actual=%s",
            _remoteFingerprint.c_str(),
            actualFingerprint.c_str()
        );

        fail("peerFingerprint");
        return false;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.peerFingerprint.ok fingerprint=%s",
        actualFingerprint.c_str()
    );

    const SRTP_PROTECTION_PROFILE *profile =
        SSL_get_selected_srtp_profile(
            _ssl
        );

    if (profile == NULL ||
        profile->name == NULL) {

        fail("SSL_get_selected_srtp_profile");
        return false;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.srtp.profile name=%s",
        profile->name
    );

    if (strcmp(
            profile->name,
            "SRTP_AES128_CM_SHA1_80"
        ) != 0) {

        fail("unexpectedSrtpProfile");
        return false;
    }

    static const char label[] =
        "EXTRACTOR-dtls_srtp";

    _srtpKeyMaterial.resize(
        60
    );

    if (SSL_export_keying_material(
            _ssl,
            &_srtpKeyMaterial[0],
            _srtpKeyMaterial.size(),
            label,
            sizeof(label) - 1,
            NULL,
            0,
            0
        ) != 1) {

        _srtpKeyMaterial.clear();

        fail("SSL_export_keying_material");
        return false;
    }

    _ready = true;

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.handshake.complete role=%s version=%s cipher=%s",
        _isClient ? "client" : "server",
        SSL_get_version(_ssl),
        SSL_get_cipher(_ssl)
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.exporter.ok bytes=%lu",
        (unsigned long)_srtpKeyMaterial.size()
    );

    return true;
}

void Ios6DtlsTransport::receiveDatagram(
    const uint8_t *data,
    size_t size
) {

    Ios6DtlsScopedLock ios6Lock(
        &_mutex
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.lock.receive thread=%p",
        (void *)pthread_self()
    );

    if (!_started ||
        _ssl == NULL ||
        data == NULL ||
        size == 0 ||
        _failed ||
        _ready) {

        return;
    }

    ios6DtlsLogFlight(
        "in",
        data,
        size
    );
    
    _incoming.push_back(
        std::vector<uint8_t>(
            data,
            data + size
        )
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.rx contentType=%u bytes=%lu",
        (unsigned int)data[0],
        (unsigned long)size
    );

    driveHandshake();
}

void Ios6DtlsTransport::handleTimeout() {

    Ios6DtlsScopedLock ios6Lock(
        &_mutex
    );

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC dtls.lock.timeout thread=%p",
        (void *)pthread_self()
    );

    if (!_started ||
        _ssl == NULL ||
        _failed ||
        _ready) {

        return;
    }

    ERR_clear_error();

    const int result =
        DTLSv1_handle_timeout(
            _ssl
        );

    if (result < 0) {
        syslog(
            LOG_ERR,
            "IOS6WEBRTC dtls.timeout.error result=%d",
            result
        );

        fail(
            "DTLSv1_handle_timeout"
        );

        return;
    }

    if (result > 0) {
        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC dtls.timeout.retransmit result=%d",
            result
        );
    }

}

bool Ios6DtlsTransport::isConfigured() const {
    return _configured;
}

bool Ios6DtlsTransport::isStarted() const {
    return _started;
}

bool Ios6DtlsTransport::isReady() const {
    return _ready;
}

bool Ios6DtlsTransport::isFailed() const {
    return _failed;
}

bool Ios6DtlsTransport::isClient() const {
    return _isClient;
}

const std::vector<uint8_t> &
Ios6DtlsTransport::srtpKeyMaterial() const {
    return _srtpKeyMaterial;
}


static size_t ios6SrtpRtpHeaderLength(
    const uint8_t *data,
    size_t size
) {
    if (data == NULL ||
        size < 12 ||
        (data[0] >> 6) != 2) {
        return 0;
    }

    const size_t csrcCount =
        (size_t)(data[0] & 0x0f);

    size_t headerLength =
        12 + csrcCount * 4;

    if (headerLength > size) {
        return 0;
    }

    if ((data[0] & 0x10) != 0) {
        if (headerLength + 4 > size) {
            return 0;
        }

        const size_t extensionWords =
            ((size_t)data[headerLength + 2] << 8) |
            (size_t)data[headerLength + 3];

        headerLength +=
            4 + extensionWords * 4;

        if (headerLength > size) {
            return 0;
        }
    }

    return headerLength;
}

static uint16_t ios6SrtpRead16(
    const uint8_t *data
) {
    return
        ((uint16_t)data[0] << 8) |
        ((uint16_t)data[1]);
}

static uint32_t ios6SrtpRead32(
    const uint8_t *data
) {
    return
        ((uint32_t)data[0] << 24) |
        ((uint32_t)data[1] << 16) |
        ((uint32_t)data[2] << 8) |
        ((uint32_t)data[3]);
}

static bool ios6SrtpKdf(
    const uint8_t *masterKey,
    const uint8_t *masterSalt,
    uint8_t label,
    uint8_t *output,
    size_t outputSize
) {
    if (masterKey == NULL ||
        masterSalt == NULL ||
        output == NULL ||
        outputSize == 0) {
        return false;
    }

    AES_KEY aes;

    if (AES_set_encrypt_key(
            masterKey,
            128,
            &aes
        ) != 0) {
        return false;
    }

    uint8_t base[16];

    memset(
        base,
        0,
        sizeof(base)
    );

    memcpy(
        base,
        masterSalt,
        14
    );

    base[7] ^= label;

    size_t offset = 0;
    uint16_t blockIndex = 0;

    while (offset < outputSize) {
        uint8_t counter[16];
        uint8_t stream[16];

        memcpy(
            counter,
            base,
            sizeof(counter)
        );

        counter[14] =
            (uint8_t)(blockIndex >> 8);

        counter[15] =
            (uint8_t)(blockIndex & 0xff);

        AES_encrypt(
            counter,
            stream,
            &aes
        );

        size_t amount =
            outputSize - offset;

        if (amount > 16) {
            amount = 16;
        }

        memcpy(
            output + offset,
            stream,
            amount
        );

        offset += amount;
        ++blockIndex;
    }

    return true;
}

static bool ios6SrtpCryptPayload(
    std::vector<uint8_t> &packet,
    size_t packetSize,
    size_t headerLength,
    const std::vector<uint8_t> &encryptionKey,
    const std::vector<uint8_t> &saltKey,
    uint32_t roc,
    uint16_t sequence,
    uint32_t ssrc
) {
    if (packetSize > packet.size() ||
        headerLength > packetSize ||
        encryptionKey.size() != 16 ||
        saltKey.size() != 14) {
        return false;
    }

    AES_KEY aes;

    if (AES_set_encrypt_key(
            &encryptionKey[0],
            128,
            &aes
        ) != 0) {
        return false;
    }

    uint8_t iv[16];

    memset(
        iv,
        0,
        sizeof(iv)
    );

    memcpy(
        iv,
        &saltKey[0],
        14
    );

    iv[4] ^= (uint8_t)(ssrc >> 24);
    iv[5] ^= (uint8_t)(ssrc >> 16);
    iv[6] ^= (uint8_t)(ssrc >> 8);
    iv[7] ^= (uint8_t)(ssrc);

    const uint64_t packetIndex =
        ((uint64_t)roc << 16) |
        (uint64_t)sequence;

    iv[8] ^= (uint8_t)(packetIndex >> 40);
    iv[9] ^= (uint8_t)(packetIndex >> 32);
    iv[10] ^= (uint8_t)(packetIndex >> 24);
    iv[11] ^= (uint8_t)(packetIndex >> 16);
    iv[12] ^= (uint8_t)(packetIndex >> 8);
    iv[13] ^= (uint8_t)(packetIndex);

    size_t offset = headerLength;
    uint16_t blockIndex = 0;

    while (offset < packetSize) {
        uint8_t counter[16];
        uint8_t stream[16];

        memcpy(
            counter,
            iv,
            sizeof(counter)
        );

        counter[14] =
            (uint8_t)(blockIndex >> 8);

        counter[15] =
            (uint8_t)(blockIndex & 0xff);

        AES_encrypt(
            counter,
            stream,
            &aes
        );

        size_t amount =
            packetSize - offset;

        if (amount > 16) {
            amount = 16;
        }

        size_t i;

        for (i = 0; i < amount; ++i) {
            packet[offset + i] ^=
                stream[i];
        }

        offset += amount;
        ++blockIndex;
    }

    return true;
}

static bool ios6SrtpAuthenticationTag(
    const std::vector<uint8_t> &packet,
    size_t packetSize,
    const std::vector<uint8_t> &authenticationKey,
    uint32_t roc,
    uint8_t tag[10]
) {
    if (packetSize > packet.size() ||
        authenticationKey.size() != 20 ||
        tag == NULL) {
        return false;
    }

    std::vector<uint8_t> authenticated;

    authenticated.reserve(
        packetSize + 4
    );

    authenticated.insert(
        authenticated.end(),
        packet.begin(),
        packet.begin() + packetSize
    );

    authenticated.push_back(
        (uint8_t)(roc >> 24)
    );

    authenticated.push_back(
        (uint8_t)(roc >> 16)
    );

    authenticated.push_back(
        (uint8_t)(roc >> 8)
    );

    authenticated.push_back(
        (uint8_t)(roc)
    );

    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digestLength = 0;

    if (HMAC(
            EVP_sha1(),
            &authenticationKey[0],
            (int)authenticationKey.size(),
            &authenticated[0],
            authenticated.size(),
            digest,
            &digestLength
        ) == NULL) {
        return false;
    }

    if (digestLength < 10) {
        return false;
    }

    memcpy(
        tag,
        digest,
        10
    );

    return true;
}

static bool ios6SrtpTagsEqual(
    const uint8_t *a,
    const uint8_t *b
) {
    if (a == NULL ||
        b == NULL) {
        return false;
    }

    unsigned int difference = 0;
    size_t i;

    for (i = 0; i < 10; ++i) {
        difference |=
            (unsigned int)(a[i] ^ b[i]);
    }

    return difference == 0;
}

bool Ios6DtlsTransport::prepareSrtpKeys(
    bool sending
) {
    if (!_ready ||
        _srtpKeyMaterial.size() != 60) {
        return false;
    }

    std::vector<uint8_t> *encryptionKey =
        sending
            ? &_srtpSendEncryptionKey
            : &_srtpRecvEncryptionKey;

    std::vector<uint8_t> *authenticationKey =
        sending
            ? &_srtpSendAuthenticationKey
            : &_srtpRecvAuthenticationKey;

    std::vector<uint8_t> *saltKey =
        sending
            ? &_srtpSendSalt
            : &_srtpRecvSalt;

    if (encryptionKey->size() == 16 &&
        authenticationKey->size() == 20 &&
        saltKey->size() == 14) {
        return true;
    }

    size_t masterKeyOffset = 0;
    size_t masterSaltOffset = 0;

    if (sending) {
        if (_isClient) {
            masterKeyOffset = 0;
            masterSaltOffset = 32;
        } else {
            masterKeyOffset = 16;
            masterSaltOffset = 46;
        }
    } else {
        if (_isClient) {
            masterKeyOffset = 16;
            masterSaltOffset = 46;
        } else {
            masterKeyOffset = 0;
            masterSaltOffset = 32;
        }
    }

    const uint8_t *masterKey =
        &_srtpKeyMaterial[
            masterKeyOffset
        ];

    const uint8_t *masterSalt =
        &_srtpKeyMaterial[
            masterSaltOffset
        ];

    encryptionKey->resize(16);
    authenticationKey->resize(20);
    saltKey->resize(14);

    if (!ios6SrtpKdf(
            masterKey,
            masterSalt,
            0x00,
            &(*encryptionKey)[0],
            encryptionKey->size()
        ) ||
        !ios6SrtpKdf(
            masterKey,
            masterSalt,
            0x01,
            &(*authenticationKey)[0],
            authenticationKey->size()
        ) ||
        !ios6SrtpKdf(
            masterKey,
            masterSalt,
            0x02,
            &(*saltKey)[0],
            saltKey->size()
        )) {

        encryptionKey->clear();
        authenticationKey->clear();
        saltKey->clear();

        return false;
    }

    if (sending) {
        _srtpSendRoc = 0;
        _srtpSendSsrc = 0;
        _srtpSendLastSequence = 0;
        _srtpSendInitialized = false;
    } else {
        _srtpRecvRoc = 0;
        _srtpRecvSsrc = 0;
        _srtpRecvLastSequence = 0;
        _srtpRecvInitialized = false;
    }

    syslog(
        LOG_NOTICE,
        "IOS6WEBRTC srtp.keys.ready direction=%s role=%s",
        sending ? "send" : "recv",
        _isClient ? "client" : "server"
    );

    return true;
}

bool Ios6DtlsTransport::protectRtp(
    std::vector<uint8_t> &packet
) {
    if (!prepareSrtpKeys(true)) {
        return false;
    }

    const size_t headerLength =
        ios6SrtpRtpHeaderLength(
            packet.empty()
                ? NULL
                : &packet[0],
            packet.size()
        );

    if (headerLength == 0 ||
        packet.size() < 12) {
        return false;
    }

    const uint16_t sequence =
        ios6SrtpRead16(
            &packet[2]
        );

    const uint32_t ssrc =
        ios6SrtpRead32(
            &packet[8]
        );

    if (!_srtpSendInitialized ||
        _srtpSendSsrc != ssrc) {

        _srtpSendSsrc = ssrc;
        _srtpSendRoc = 0;
        _srtpSendLastSequence = sequence;
        _srtpSendInitialized = true;

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC srtp.send.stream ssrc=%u seq=%u roc=0",
            (unsigned int)ssrc,
            (unsigned int)sequence
        );
    } else {
        const int32_t delta =
            (int32_t)sequence -
            (int32_t)_srtpSendLastSequence;

        if (delta < -32768) {
            ++_srtpSendRoc;
            _srtpSendLastSequence =
                sequence;
        } else if (delta > 0 &&
                   delta < 32768) {
            _srtpSendLastSequence =
                sequence;
        }
    }

    const size_t plainSize =
        packet.size();

    if (!ios6SrtpCryptPayload(
            packet,
            plainSize,
            headerLength,
            _srtpSendEncryptionKey,
            _srtpSendSalt,
            _srtpSendRoc,
            sequence,
            ssrc
        )) {
        return false;
    }

    uint8_t tag[10];

    if (!ios6SrtpAuthenticationTag(
            packet,
            plainSize,
            _srtpSendAuthenticationKey,
            _srtpSendRoc,
            tag
        )) {
        return false;
    }

    packet.insert(
        packet.end(),
        tag,
        tag + 10
    );

    return true;
}

bool Ios6DtlsTransport::unprotectRtp(
    std::vector<uint8_t> &packet
) {
    if (!prepareSrtpKeys(false)) {
        return false;
    }

    if (packet.size() < 12 + 10) {
        return false;
    }

    const size_t protectedSize =
        packet.size() - 10;

    const size_t headerLength =
        ios6SrtpRtpHeaderLength(
            &packet[0],
            protectedSize
        );

    if (headerLength == 0) {
        return false;
    }

    const uint16_t sequence =
        ios6SrtpRead16(
            &packet[2]
        );

    const uint32_t ssrc =
        ios6SrtpRead32(
            &packet[8]
        );

    bool newStream =
        !_srtpRecvInitialized ||
        _srtpRecvSsrc != ssrc;

    uint32_t guessedRoc =
        newStream
            ? 0
            : _srtpRecvRoc;

    if (!newStream) {
        if (_srtpRecvLastSequence < 32768) {
            const int32_t difference =
                (int32_t)sequence -
                (int32_t)_srtpRecvLastSequence;

            if (difference > 32768) {
                guessedRoc =
                    _srtpRecvRoc - 1;
            }
        } else {
            if ((int32_t)_srtpRecvLastSequence -
                    32768 >
                (int32_t)sequence) {

                guessedRoc =
                    _srtpRecvRoc + 1;
            }
        }
    }

    uint8_t expectedTag[10];

    if (!ios6SrtpAuthenticationTag(
            packet,
            protectedSize,
            _srtpRecvAuthenticationKey,
            guessedRoc,
            expectedTag
        )) {
        return false;
    }

    if (!ios6SrtpTagsEqual(
            expectedTag,
            &packet[protectedSize]
        )) {

        syslog(
            LOG_ERR,
            "IOS6WEBRTC srtp.recv.auth.fail ssrc=%u seq=%u guessedRoc=%u bytes=%lu",
            (unsigned int)ssrc,
            (unsigned int)sequence,
            (unsigned int)guessedRoc,
            (unsigned long)packet.size()
        );

        return false;
    }

    packet.resize(
        protectedSize
    );

    if (!ios6SrtpCryptPayload(
            packet,
            packet.size(),
            headerLength,
            _srtpRecvEncryptionKey,
            _srtpRecvSalt,
            guessedRoc,
            sequence,
            ssrc
        )) {
        return false;
    }

    if (newStream) {
        _srtpRecvSsrc = ssrc;
        _srtpRecvRoc = guessedRoc;
        _srtpRecvLastSequence =
            sequence;

        _srtpRecvInitialized = true;

        syslog(
            LOG_NOTICE,
            "IOS6WEBRTC srtp.recv.stream ssrc=%u seq=%u roc=%u",
            (unsigned int)ssrc,
            (unsigned int)sequence,
            (unsigned int)guessedRoc
        );
    } else if (guessedRoc ==
               _srtpRecvRoc + 1) {

        _srtpRecvRoc =
            guessedRoc;

        _srtpRecvLastSequence =
            sequence;
    } else if (guessedRoc ==
               _srtpRecvRoc &&
               sequence >
                   _srtpRecvLastSequence) {

        _srtpRecvLastSequence =
            sequence;
    }

    return true;
}

bool Ios6DtlsTransport::looksLikeDtls(
    const uint8_t *data,
    size_t size
) {
    if (data == NULL ||
        size < 13) {

        return false;
    }

    if (data[0] < 20 ||
        data[0] > 23) {

        return false;
    }

    if (data[1] != 0xFE) {
        return false;
    }

    return
        data[2] == 0xFF ||
        data[2] == 0xFD;
}

} // namespace tgcalls
