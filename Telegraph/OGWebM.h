#ifndef OG_WEBM_H
#define OG_WEBM_H

#include <stddef.h>
#include <stdint.h>

typedef struct
{
    size_t offset;
    size_t length;
    size_t alphaOffset;
    size_t alphaLength;
    uint64_t timestampNs;
} OGWebMFrame;

typedef struct
{
    uint32_t width;
    uint32_t height;
    uint32_t alphaMode;
    uint32_t frameCount;
    uint64_t durationNs;
    OGWebMFrame *frames;
} OGWebM;

int OGWebMParse(const uint8_t *data, size_t length, OGWebM *result);
void OGWebMFree(OGWebM *webm);

#endif
