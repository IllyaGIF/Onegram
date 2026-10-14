#ifndef POWER_AES_GCM_H
#define POWER_AES_GCM_H

#include <stddef.h>
#include <stdint.h>

void PWAESGCMSeal(const uint8_t *key, size_t keyLen,
                  const uint8_t iv[12],
                  const uint8_t *aad, size_t aadLen,
                  const uint8_t *plain, size_t plainLen,
                  uint8_t *out);

int PWAESGCMOpen(const uint8_t *key, size_t keyLen,
                 const uint8_t iv[12],
                 const uint8_t *aad, size_t aadLen,
                 const uint8_t *input, size_t inputLen,
                 uint8_t *out, size_t outCap);

#endif
