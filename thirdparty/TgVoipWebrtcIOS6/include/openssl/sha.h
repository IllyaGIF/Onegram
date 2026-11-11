#ifndef OG_COMPAT_OPENSSL_SHA_H
#define OG_COMPAT_OPENSSL_SHA_H

#include <CommonCrypto/CommonDigest.h>

#define SHA256_DIGEST_LENGTH CC_SHA256_DIGEST_LENGTH

typedef CC_SHA256_CTX SHA256_CTX;

static inline int SHA256_Init(SHA256_CTX *ctx) {
	return CC_SHA256_Init(ctx);
}

static inline int SHA256_Update(SHA256_CTX *ctx, const void *bytes, size_t count) {
	return CC_SHA256_Update(ctx, bytes, (CC_LONG)count);
}

static inline int SHA256_Final(unsigned char *out, SHA256_CTX *ctx) {
	return CC_SHA256_Final(out, ctx);
}

#endif
