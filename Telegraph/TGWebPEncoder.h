#ifndef TG_WEBP_ENCODER_H
#define TG_WEBP_ENCODER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint8_t *TGWebPEncodeLosslessRGBA(const uint8_t *rgba, int width, int height, int stride, size_t *outSize);
uint8_t *TGWebPEncodeRGBAWithSizeLimit(const uint8_t *rgba, int width, int height, int stride, size_t maxSize, size_t *outSize);

#ifdef __cplusplus
}
#endif

#endif
