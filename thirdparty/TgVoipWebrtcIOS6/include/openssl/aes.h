#ifndef OG_COMPAT_OPENSSL_AES_H
#define OG_COMPAT_OPENSSL_AES_H

#include <CommonCrypto/CommonCryptor.h>
#include <stdint.h>
#include <string.h>

#define AES_BLOCK_SIZE 16

typedef struct AES_KEY {
	unsigned char key[32];
	size_t keyLength;
} AES_KEY;

static inline int AES_set_encrypt_key(const unsigned char *userKey, const int bits, AES_KEY *schedule) {
	if (!schedule || !userKey || bits < 1 || bits > 256) {
		return -1;
	}
	schedule->keyLength = (size_t)(bits / 8);
	memcpy(schedule->key, userKey, schedule->keyLength);
	return 0;
}

static inline void AES_encrypt(const unsigned char *in, unsigned char *out, const AES_KEY *schedule) {
	size_t produced = 0;
	CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionECBMode,
		schedule->key, schedule->keyLength,
		0,
		in, AES_BLOCK_SIZE,
		out, AES_BLOCK_SIZE,
		&produced);
}

#endif
