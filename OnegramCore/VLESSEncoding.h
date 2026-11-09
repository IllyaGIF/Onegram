#ifndef VLESS_ENCODING_H
#define VLESS_ENCODING_H
#include <stddef.h>
#include <stdint.h>
int VLDecodeBase64Bytes(const char *text, size_t length, uint8_t *out, size_t capacity, size_t *written);
int VLDecodeHexBytes(const char *text, size_t length, uint8_t *out, size_t capacity);
#endif
