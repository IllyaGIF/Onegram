#ifndef VLESS_VISION_H
#define VLESS_VISION_H
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
typedef struct {
    int active, padOut;
    uint8_t uuid[16];
    int uuidSent, headerDone, inStarted, inDone, directIn;
    unsigned prefixLength, commandLength;
    uint8_t command[5];
    size_t remainingContent, remainingPadding;
} VLVision;
ssize_t VLVisionUnpad(VLVision *vision, uint8_t *bytes, size_t length);
#endif
