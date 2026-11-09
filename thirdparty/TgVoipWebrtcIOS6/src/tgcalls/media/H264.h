#ifndef TGCALLS_MEDIA_H264_H
#define TGCALLS_MEDIA_H264_H

#include <stddef.h>
#include <stdint.h>
#include <vector>

namespace tgcalls {
namespace h264 {

enum NalType {
    NalSlice = 1,
    NalIdr = 5,
    NalSei = 6,
    NalSps = 7,
    NalPps = 8,
    NalAud = 9,
    NalStapA = 24,
    NalFuA = 28
};

struct NalUnit {
    const uint8_t *data;
    size_t size;
};

inline uint8_t NalTypeOf(uint8_t header) {
    return header & 0x1F;
}

void SplitAnnexB(const uint8_t *data, size_t size, std::vector<NalUnit> &units);
void AppendAnnexB(std::vector<uint8_t> &target, const uint8_t *nal, size_t size);
bool ParseSpsResolution(const uint8_t *sps, size_t size, int *width, int *height);

}
}

#endif
