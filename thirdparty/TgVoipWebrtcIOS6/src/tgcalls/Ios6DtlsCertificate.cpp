#include "Ios6DtlsCertificate.h"

#include <iomanip>
#include <sstream>

#include <openssl/ec.h>
#include <openssl/obj_mac.h>
#include <openssl/sha.h>

namespace tgcalls {

Ios6DtlsCertificate::Ios6DtlsCertificate()
: _certificate(0),
  _privateKey(0) {
}

Ios6DtlsCertificate::~Ios6DtlsCertificate() {
    clear();
}

void Ios6DtlsCertificate::clear() {
    if (_certificate) {
        X509_free(_certificate);
        _certificate = 0;
    }

    if (_privateKey) {
        EVP_PKEY_free(_privateKey);
        _privateKey = 0;
    }

    _fingerprint.clear();
}

bool Ios6DtlsCertificate::generate() {
    clear();

    EC_KEY *ecKey =
        EC_KEY_new_by_curve_name(NID_X9_62_prime256v1);

    if (ecKey != NULL) {
        EC_KEY_set_asn1_flag(
            ecKey,
            OPENSSL_EC_NAMED_CURVE
        );
    }

    if (!ecKey) {
        return false;
    }

    if (EC_KEY_generate_key(ecKey) != 1) {
        EC_KEY_free(ecKey);
        return false;
    }

    EVP_PKEY *privateKey = EVP_PKEY_new();

    if (!privateKey) {
        EC_KEY_free(ecKey);
        return false;
    }

    if (EVP_PKEY_assign_EC_KEY(privateKey, ecKey) != 1) {
        EC_KEY_free(ecKey);
        EVP_PKEY_free(privateKey);
        return false;
    }

    ecKey = 0;

    X509 *certificate = X509_new();

    if (!certificate) {
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (X509_set_version(certificate, 2) != 1) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (ASN1_INTEGER_set(
            X509_get_serialNumber(certificate),
            1) != 1) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (!X509_gmtime_adj(
            X509_get_notBefore(certificate),
            -3600)) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (!X509_gmtime_adj(
            X509_get_notAfter(certificate),
            365L * 24L * 60L * 60L)) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (X509_set_pubkey(
            certificate,
            privateKey) != 1) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    X509_NAME *name =
        X509_get_subject_name(certificate);

    if (!name) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    const unsigned char commonName[] =
        "Onegram WebRTC";

    if (X509_NAME_add_entry_by_txt(
            name,
            "CN",
            MBSTRING_ASC,
            commonName,
            -1,
            -1,
            0) != 1) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (X509_set_issuer_name(
            certificate,
            name) != 1) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (X509_sign(
            certificate,
            privateKey,
            EVP_sha256()) <= 0) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    unsigned char digest[SHA256_DIGEST_LENGTH];
    unsigned int digestLength = 0;

    if (X509_digest(
            certificate,
            EVP_sha256(),
            digest,
            &digestLength) != 1) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    if (digestLength != SHA256_DIGEST_LENGTH) {
        X509_free(certificate);
        EVP_PKEY_free(privateKey);
        return false;
    }

    std::ostringstream result;

    result << std::uppercase
           << std::hex
           << std::setfill('0');

    for (unsigned int i = 0;
         i < digestLength;
         ++i) {
        if (i != 0) {
            result << ":";
        }

        result << std::setw(2)
               << static_cast<unsigned int>(digest[i]);
    }

    _certificate = certificate;
    _privateKey = privateKey;
    _fingerprint = result.str();

    return true;
}

X509 *Ios6DtlsCertificate::certificate() const {
    return _certificate;
}

EVP_PKEY *Ios6DtlsCertificate::privateKey() const {
    return _privateKey;
}

const std::string &
Ios6DtlsCertificate::fingerprint() const {
    return _fingerprint;
}

} // namespace tgcalls
