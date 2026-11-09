#include "VLESSMLKEM.h"
#include "monocypher.h"
#include <openssl/rand.h>
#define MLK_CONFIG_FILE "VLESSMLKEMConfig.h"
#include "mlkem_native.c"

int VLMLKEMKeyPair(uint8_t publicKey[VL_MLKEM_PUBLIC_BYTES], uint8_t privateKey[VL_MLKEM_PRIVATE_BYTES]) {
    uint8_t seed[64];
    if (RAND_bytes(seed, sizeof(seed)) != 1) { crypto_wipe(seed, sizeof(seed)); return 0; }
    int result = VLMLKEM768_keypair_derand(publicKey, privateKey, seed);
    crypto_wipe(seed, sizeof(seed));
    return result == 0;
}

int VLMLKEMDecapsulate(uint8_t shared[32], const uint8_t ciphertext[VL_MLKEM_CIPHER_BYTES], const uint8_t privateKey[VL_MLKEM_PRIVATE_BYTES]) {
    return VLMLKEM768_dec(shared, ciphertext, privateKey) == 0;
}
