#ifndef ONEGRAM_IOS3_COMMONDIGEST_H
#define ONEGRAM_IOS3_COMMONDIGEST_H

#include <openssl/md5.h>
#include <openssl/sha.h>

typedef unsigned int CC_LONG;

typedef MD5_CTX CC_MD5_CTX;
typedef SHA_CTX CC_SHA1_CTX;
typedef SHA256_CTX CC_SHA256_CTX;
typedef SHA512_CTX CC_SHA512_CTX;

#define CC_MD5_DIGEST_LENGTH MD5_DIGEST_LENGTH
#define CC_SHA1_DIGEST_LENGTH SHA_DIGEST_LENGTH
#define CC_SHA256_DIGEST_LENGTH SHA256_DIGEST_LENGTH
#define CC_SHA512_DIGEST_LENGTH SHA512_DIGEST_LENGTH

static inline unsigned char *CC_MD5(const void *data, CC_LONG len, unsigned char *md)
{
    return MD5((const unsigned char *)data, (size_t)len, md);
}

static inline int CC_MD5_Init(CC_MD5_CTX *context)
{
    return MD5_Init(context);
}

static inline int CC_MD5_Update(CC_MD5_CTX *context, const void *data, CC_LONG len)
{
    return MD5_Update(context, data, (size_t)len);
}

static inline int CC_MD5_Final(unsigned char *md, CC_MD5_CTX *context)
{
    return MD5_Final(md, context);
}

static inline unsigned char *CC_SHA1(const void *data, CC_LONG len, unsigned char *md)
{
    return SHA1((const unsigned char *)data, (size_t)len, md);
}

static inline int CC_SHA1_Init(CC_SHA1_CTX *context)
{
    return SHA1_Init(context);
}

static inline int CC_SHA1_Update(CC_SHA1_CTX *context, const void *data, CC_LONG len)
{
    return SHA1_Update(context, data, (size_t)len);
}

static inline int CC_SHA1_Final(unsigned char *md, CC_SHA1_CTX *context)
{
    return SHA1_Final(md, context);
}

static inline unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md)
{
    return SHA256((const unsigned char *)data, (size_t)len, md);
}

static inline int CC_SHA256_Init(CC_SHA256_CTX *context)
{
    return SHA256_Init(context);
}

static inline int CC_SHA256_Update(CC_SHA256_CTX *context, const void *data, CC_LONG len)
{
    return SHA256_Update(context, data, (size_t)len);
}

static inline int CC_SHA256_Final(unsigned char *md, CC_SHA256_CTX *context)
{
    return SHA256_Final(md, context);
}

static inline unsigned char *CC_SHA512(const void *data, CC_LONG len, unsigned char *md)
{
    return SHA512((const unsigned char *)data, (size_t)len, md);
}

#endif
