#ifndef ONEGRAM_IOS3_COMMONHMAC_H
#define ONEGRAM_IOS3_COMMONHMAC_H

#include <openssl/evp.h>
#include <openssl/hmac.h>
#include <stddef.h>

typedef enum {
    kCCHmacAlgSHA1 = 0,
    kCCHmacAlgMD5 = 1,
    kCCHmacAlgSHA256 = 2,
    kCCHmacAlgSHA384 = 3,
    kCCHmacAlgSHA512 = 4,
    kCCHmacAlgSHA224 = 5
} CCHmacAlgorithm;

typedef HMAC_CTX CCHmacContext;

static inline const EVP_MD *OnegramCCHmacDigest(CCHmacAlgorithm algorithm)
{
    switch (algorithm)
    {
        case kCCHmacAlgSHA1:
            return EVP_sha1();
        case kCCHmacAlgMD5:
            return EVP_md5();
        case kCCHmacAlgSHA256:
            return EVP_sha256();
        case kCCHmacAlgSHA384:
            return EVP_sha384();
        case kCCHmacAlgSHA512:
            return EVP_sha512();
        case kCCHmacAlgSHA224:
            return EVP_sha224();
    }
    return 0;
}

static inline void CCHmacInit(CCHmacContext *context, CCHmacAlgorithm algorithm, const void *key, size_t keyLength)
{
    HMAC_CTX_init(context);
    HMAC_Init_ex(context, key, (int)keyLength, OnegramCCHmacDigest(algorithm), 0);
}

static inline void CCHmacUpdate(CCHmacContext *context, const void *data, size_t dataLength)
{
    HMAC_Update(context, (const unsigned char *)data, dataLength);
}

static inline void CCHmacFinal(CCHmacContext *context, void *macOut)
{
    unsigned int length = 0;
    HMAC_Final(context, (unsigned char *)macOut, &length);
    HMAC_CTX_cleanup(context);
}

static inline void CCHmac(CCHmacAlgorithm algorithm, const void *key, size_t keyLength, const void *data, size_t dataLength, void *macOut)
{
    unsigned int length = 0;
    HMAC(OnegramCCHmacDigest(algorithm), key, (int)keyLength, (const unsigned char *)data, dataLength, (unsigned char *)macOut, &length);
}

#endif
