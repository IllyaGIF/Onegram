#ifndef TGCALLS_IOS6_DTLS_CERTIFICATE_H
#define TGCALLS_IOS6_DTLS_CERTIFICATE_H

#include <string>

#include <openssl/evp.h>
#include <openssl/x509.h>

namespace tgcalls {

class Ios6DtlsCertificate {
public:
    Ios6DtlsCertificate();
    ~Ios6DtlsCertificate();

    bool generate();

    X509 *certificate() const;
    EVP_PKEY *privateKey() const;
    const std::string &fingerprint() const;

private:
    Ios6DtlsCertificate(const Ios6DtlsCertificate &);
    Ios6DtlsCertificate &operator=(const Ios6DtlsCertificate &);

    void clear();

    X509 *_certificate;
    EVP_PKEY *_privateKey;
    std::string _fingerprint;
};

} // namespace tgcalls

#endif
