#ifndef POWER_SHA256_H
#define POWER_SHA256_H

#include <stddef.h>
#include <stdint.h>

#define PW_SHA256_LEN 32

typedef struct {
    uint32_t state[8];
    uint64_t length;        
    uint8_t  block[64];
    size_t   filled;
} PWSHA256;

void PWSHA256Init(PWSHA256 *ctx);
void PWSHA256Update(PWSHA256 *ctx, const uint8_t *data, size_t length);
void PWSHA256Final(PWSHA256 *ctx, uint8_t out[PW_SHA256_LEN]);
void PWSHA256Hash(const uint8_t *data, size_t length, uint8_t out[PW_SHA256_LEN]);

void PWHMACSHA256(const uint8_t *key, size_t keyLength,
                  const uint8_t *data, size_t dataLength,
                  uint8_t out[PW_SHA256_LEN]);

void PWHKDFExtract(const uint8_t *salt, size_t saltLength,
                   const uint8_t *secret, size_t secretLength,
                   uint8_t out[PW_SHA256_LEN]);
void PWHKDFExpand(const uint8_t prk[PW_SHA256_LEN],
                  const uint8_t *info, size_t infoLength,
                  uint8_t *out, size_t outLength);

void PWHKDFExpandLabel(const uint8_t secret[PW_SHA256_LEN],
                       const char *label,
                       const uint8_t *context, size_t contextLength,
                       uint8_t *out, size_t outLength);

#endif
