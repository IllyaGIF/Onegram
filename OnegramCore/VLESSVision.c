#include "VLESSVision.h"
#include <string.h>

ssize_t VLVisionUnpad(VLVision *v, uint8_t *bytes, size_t length) {
    if (!v || (!bytes && length)) return -1;
    if (v->inDone) return (ssize_t)length;
    size_t at = 0, put = 0;
    while (at < length) {
        if (v->prefixLength < 16) {
            if (bytes[at++] != v->uuid[v->prefixLength++]) return -1;
            continue;
        }
        if (v->commandLength < 5) {
            v->command[v->commandLength++] = bytes[at++];
            if (v->commandLength < 5) continue;
            if (v->command[0] > 2) return -1;
            v->remainingContent = ((size_t)v->command[1] << 8) | v->command[2];
            v->remainingPadding = ((size_t)v->command[3] << 8) | v->command[4];
        } else if (v->remainingContent) {
            size_t count = length - at;
            if (count > v->remainingContent) count = v->remainingContent;
            memmove(bytes + put, bytes + at, count);
            at += count;
            put += count;
            v->remainingContent -= count;
        } else if (v->remainingPadding) {
            size_t count = length - at;
            if (count > v->remainingPadding) count = v->remainingPadding;
            at += count;
            v->remainingPadding -= count;
        }
        if (v->commandLength == 5 && !v->remainingContent && !v->remainingPadding) {
            if (v->command[0] == 0) v->commandLength = 0;
            else {
                v->inDone = 1;
                v->directIn = v->command[0] == 2;
                memmove(bytes + put, bytes + at, length - at);
                return (ssize_t)(put + length - at);
            }
        }
    }
    return (ssize_t)put;
}
