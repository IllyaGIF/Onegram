#ifndef VLESS_MLKEM_H
#define VLESS_MLKEM_H
#include <stdint.h>
#define VL_MLKEM_PUBLIC_BYTES 1184
#define VL_MLKEM_PRIVATE_BYTES 2400
#define VL_MLKEM_CIPHER_BYTES 1088
int VLMLKEMKeyPair(uint8_t publicKey[VL_MLKEM_PUBLIC_BYTES], uint8_t privateKey[VL_MLKEM_PRIVATE_BYTES]);
int VLMLKEMDecapsulate(uint8_t shared[32], const uint8_t ciphertext[VL_MLKEM_CIPHER_BYTES], const uint8_t privateKey[VL_MLKEM_PRIVATE_BYTES]);
#endif
