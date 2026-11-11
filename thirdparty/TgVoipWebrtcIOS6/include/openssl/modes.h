#ifndef OG_COMPAT_OPENSSL_MODES_H
#define OG_COMPAT_OPENSSL_MODES_H

#include "openssl/aes.h"
#include <stddef.h>
#include <stdint.h>

typedef void (*block128_f)(const unsigned char in[16], unsigned char out[16], const void *key);

static inline void og_compat_bump_counter(unsigned char counter[16]) {
	int position = 16;
	while (position-- > 0) {
		if (++counter[position] != 0) {
			return;
		}
	}
}

static inline void CRYPTO_ctr128_encrypt(
	const unsigned char *in,
	unsigned char *out,
	size_t len,
	const void *key,
	unsigned char ivec[16],
	unsigned char ecount_buf[16],
	unsigned int *num,
	block128_f block) {
	unsigned int offset = num ? *num : 0;
	for (size_t i = 0; i < len; i++) {
		if (!offset) {
			block(ivec, ecount_buf, key);
			og_compat_bump_counter(ivec);
		}
		out[i] = in[i] ^ ecount_buf[offset];
		offset = (offset + 1) % 16;
	}
	if (num) {
		*num = offset;
	}
}

#endif
