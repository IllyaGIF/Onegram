#ifndef ONEGRAM_IOS3_COMMONKEYDERIVATION_H
#define ONEGRAM_IOS3_COMMONKEYDERIVATION_H

#include <openssl/evp.h>
#include <stddef.h>
#include <stdint.h>
#include "CommonCryptor.h"

typedef unsigned int CCPBKDFAlgorithm;
typedef unsigned int CCPseudoRandomAlgorithm;

enum {
    kCCPBKDF2 = 2
};

enum {
    kCCPRFHmacAlgSHA1 = 1,
    kCCPRFHmacAlgSHA224 = 2,
    kCCPRFHmacAlgSHA256 = 3,
    kCCPRFHmacAlgSHA384 = 4,
    kCCPRFHmacAlgSHA512 = 5
};

static inline const EVP_MD *OnegramCCPBKDFDigest(CCPseudoRandomAlgorithm algorithm)
{
    switch (algorithm)
    {
        case kCCPRFHmacAlgSHA1:
            return EVP_sha1();
        case kCCPRFHmacAlgSHA224:
            return EVP_sha224();
        case kCCPRFHmacAlgSHA256:
            return EVP_sha256();
        case kCCPRFHmacAlgSHA384:
            return EVP_sha384();
        case kCCPRFHmacAlgSHA512:
            return EVP_sha512();
    }
    return 0;
}

static inline int CCKeyDerivationPBKDF(CCPBKDFAlgorithm algorithm, const char *password, size_t passwordLength, const uint8_t *salt, size_t saltLength, CCPseudoRandomAlgorithm pseudoRandomAlgorithm, uint32_t rounds, uint8_t *derivedKey, size_t derivedKeyLength)
{
    const EVP_MD *digest = OnegramCCPBKDFDigest(pseudoRandomAlgorithm);
    if (algorithm != kCCPBKDF2 || digest == 0 || password == 0 || derivedKey == 0 || rounds == 0)
        return kCCParamError;

    int result = PKCS5_PBKDF2_HMAC(password, (int)passwordLength, salt, (int)saltLength, (int)rounds, digest, (int)derivedKeyLength, derivedKey);
    return result == 1 ? kCCSuccess : kCCParamError;
}

#endif
