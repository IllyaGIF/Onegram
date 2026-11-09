#ifndef BLAKE2S_H
#define BLAKE2S_H

#include <stdint.h>
#include <stddef.h>

#define BLAKE2S_BLOCKBYTES 64
#define BLAKE2S_OUTBYTES   32

typedef struct {
    uint32_t h[8];
    uint32_t t[2];
    uint8_t  buf[BLAKE2S_BLOCKBYTES];
    size_t   buflen;
    size_t   outlen;
    uint8_t  finished;
} blake2s_state;

void blake2s_init(blake2s_state *S, size_t outlen);
void blake2s_init_key(blake2s_state *S, size_t outlen, const void *key, size_t keylen);
void blake2s_update(blake2s_state *S, const void *in, size_t inlen);
void blake2s_final(blake2s_state *S, void *out);

void blake2s(void *out, size_t outlen, const void *key, size_t keylen,
             const void *in, size_t inlen);

void blake2s_hmac(uint8_t out[32], const void *key, size_t keylen,
                  const void *in, size_t inlen);

#endif
