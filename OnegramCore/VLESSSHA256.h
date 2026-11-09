#ifndef VLESS_SHA256_H
#define VLESS_SHA256_H

#include <stddef.h>
#include <stdint.h>

#define VL_SHA256_LEN 32

typedef struct {
    uint32_t state[8];
    uint64_t length;        
    uint8_t  block[64];
    size_t   filled;
} VLSHA256;

void VLSHA256Init(VLSHA256 *ctx);
void VLSHA256Update(VLSHA256 *ctx, const uint8_t *data, size_t length);
void VLSHA256Final(VLSHA256 *ctx, uint8_t out[VL_SHA256_LEN]);
void VLSHA256Hash(const uint8_t *data, size_t length, uint8_t out[VL_SHA256_LEN]);

void VLHMACSHA256(const uint8_t *key, size_t keyLength,
                  const uint8_t *data, size_t dataLength,
                  uint8_t out[VL_SHA256_LEN]);

void VLHKDFExtract(const uint8_t *salt, size_t saltLength,
                   const uint8_t *secret, size_t secretLength,
                   uint8_t out[VL_SHA256_LEN]);
void VLHKDFExpand(const uint8_t prk[VL_SHA256_LEN],
                  const uint8_t *info, size_t infoLength,
                  uint8_t *out, size_t outLength);

void VLHKDFExpandLabel(const uint8_t secret[VL_SHA256_LEN],
                       const char *label,
                       const uint8_t *context, size_t contextLength,
                       uint8_t *out, size_t outLength);

#endif
