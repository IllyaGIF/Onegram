#ifndef OG_COMPAT_OPENSSL_RAND_H
#define OG_COMPAT_OPENSSL_RAND_H

#include <Security/SecRandom.h>

static inline int RAND_bytes(unsigned char *buf, int num) {
	const int status = SecRandomCopyBytes(kSecRandomDefault, (size_t)num, buf);
	return status == 0 ? 1 : 0;
}

#endif
