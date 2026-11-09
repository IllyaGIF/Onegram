#ifndef OG_VIDEO_COLOR_H
#define OG_VIDEO_COLOR_H

#include <stddef.h>
#include <stdint.h>

typedef struct
{
    const uint8_t *planes[3];
    int strides[3];
    unsigned int width;
    unsigned int height;
} OGVideoI420;

int OGVideoConvertBGRA(const OGVideoI420 *color, const OGVideoI420 *alpha, uint8_t *output, unsigned int width, unsigned int height);

#endif
