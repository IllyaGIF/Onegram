#ifndef ONEGRAM_IOS3_COMMONCRYPTOR_H
#define ONEGRAM_IOS3_COMMONCRYPTOR_H

#include <openssl/aes.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned int CCOperation;
typedef unsigned int CCAlgorithm;
typedef unsigned int CCOptions;
typedef int CCCryptorStatus;

enum {
    kCCEncrypt = 0,
    kCCDecrypt = 1
};

enum {
    kCCAlgorithmAES128 = 0
};

enum {
    kCCOptionPKCS7Padding = 0x0001,
    kCCOptionECBMode = 0x0002
};

enum {
    kCCSuccess = 0,
    kCCParamError = -4300,
    kCCBufferTooSmall = -4301
};

enum {
    kCCBlockSizeAES128 = 16,
    kCCKeySizeAES128 = 16,
    kCCKeySizeAES192 = 24,
    kCCKeySizeAES256 = 32
};

typedef struct OnegramCCCryptor {
    CCOperation operation;
    CCOptions options;
    AES_KEY key;
    unsigned char iv[kCCBlockSizeAES128];
} *CCCryptorRef;

static inline CCCryptorStatus CCCryptorCreate(CCOperation operation, CCAlgorithm algorithm, CCOptions options, const void *key, size_t keyLength, const void *iv, CCCryptorRef *cryptorRef)
{
    if (cryptorRef == 0 || key == 0 || algorithm != kCCAlgorithmAES128)
        return kCCParamError;
    if (operation != kCCEncrypt && operation != kCCDecrypt)
        return kCCParamError;
    if (keyLength != kCCKeySizeAES128 && keyLength != kCCKeySizeAES192 && keyLength != kCCKeySizeAES256)
        return kCCParamError;
    if ((options & kCCOptionPKCS7Padding) != 0)
        return kCCParamError;

    CCCryptorRef cryptor = (CCCryptorRef)calloc(1, sizeof(*cryptor));
    if (cryptor == 0)
        return kCCParamError;

    cryptor->operation = operation;
    cryptor->options = options;
    if (iv != 0)
        memcpy(cryptor->iv, iv, kCCBlockSizeAES128);

    int result;
    if (operation == kCCEncrypt)
        result = AES_set_encrypt_key((const unsigned char *)key, (int)(keyLength * 8), &cryptor->key);
    else
        result = AES_set_decrypt_key((const unsigned char *)key, (int)(keyLength * 8), &cryptor->key);

    if (result != 0)
    {
        free(cryptor);
        return kCCParamError;
    }

    *cryptorRef = cryptor;
    return kCCSuccess;
}

static inline CCCryptorStatus CCCryptorUpdate(CCCryptorRef cryptor, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved)
{
    if (dataOutMoved != 0)
        *dataOutMoved = 0;
    if (cryptor == 0 || dataIn == 0 || dataOut == 0)
        return kCCParamError;
    if ((dataInLength % kCCBlockSizeAES128) != 0)
        return kCCParamError;
    if (dataOutAvailable < dataInLength)
        return kCCBufferTooSmall;

    if ((cryptor->options & kCCOptionECBMode) != 0)
    {
        const unsigned char *input = (const unsigned char *)dataIn;
        unsigned char *output = (unsigned char *)dataOut;
        size_t offset = 0;
        while (offset < dataInLength)
        {
            if (cryptor->operation == kCCEncrypt)
                AES_encrypt(input + offset, output + offset, &cryptor->key);
            else
                AES_decrypt(input + offset, output + offset, &cryptor->key);
            offset += kCCBlockSizeAES128;
        }
    }
    else
    {
        AES_cbc_encrypt((const unsigned char *)dataIn, (unsigned char *)dataOut, dataInLength, &cryptor->key, cryptor->iv, cryptor->operation == kCCEncrypt ? AES_ENCRYPT : AES_DECRYPT);
    }

    if (dataOutMoved != 0)
        *dataOutMoved = dataInLength;
    return kCCSuccess;
}

static inline CCCryptorStatus CCCryptorFinal(CCCryptorRef cryptor, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved)
{
    (void)dataOut;
    (void)dataOutAvailable;
    if (dataOutMoved != 0)
        *dataOutMoved = 0;
    return cryptor == 0 ? kCCParamError : kCCSuccess;
}

static inline CCCryptorStatus CCCryptorRelease(CCCryptorRef cryptor)
{
    if (cryptor == 0)
        return kCCParamError;
    memset(cryptor, 0, sizeof(*cryptor));
    free(cryptor);
    return kCCSuccess;
}

static inline CCCryptorStatus CCCrypt(CCOperation operation, CCAlgorithm algorithm, CCOptions options, const void *key, size_t keyLength, const void *iv, const void *dataIn, size_t dataInLength, void *dataOut, size_t dataOutAvailable, size_t *dataOutMoved)
{
    CCCryptorRef cryptor = 0;
    CCCryptorStatus result = CCCryptorCreate(operation, algorithm, options, key, keyLength, iv, &cryptor);
    if (result != kCCSuccess)
        return result;

    size_t moved = 0;
    result = CCCryptorUpdate(cryptor, dataIn, dataInLength, dataOut, dataOutAvailable, &moved);
    CCCryptorRelease(cryptor);

    if (dataOutMoved != 0)
        *dataOutMoved = moved;
    return result;
}

#endif
