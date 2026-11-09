#ifndef VLESS_AES_GCM_H
#define VLESS_AES_GCM_H

#include <stddef.h>
#include <stdint.h>

void VLAESGCMSeal(const uint8_t *key, size_t keyLen,
                  const uint8_t iv[12],
                  const uint8_t *aad, size_t aadLen,
                  const uint8_t *plain, size_t plainLen,
                  uint8_t *out);

int VLAESGCMOpen(const uint8_t *key, size_t keyLen,
                 const uint8_t iv[12],
                 const uint8_t *aad, size_t aadLen,
                 const uint8_t *input, size_t inputLen,
                 uint8_t *out, size_t outCap);

#endif
