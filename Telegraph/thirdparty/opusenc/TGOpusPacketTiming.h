#ifndef TG_OPUS_PACKET_TIMING_H
#define TG_OPUS_PACKET_TIMING_H

#include <stdint.h>

static inline int64_t TGOpusFinalGranulePosition(int64_t samples, int32_t sampleRate, int32_t preskip)
{
    return (samples * 48000 + sampleRate - 1) / sampleRate + preskip;
}

static inline int TGOpusPacketNeedsPadding(int64_t encodedGranulePosition, int64_t samples, int32_t sampleRate, int32_t preskip)
{
    return encodedGranulePosition < TGOpusFinalGranulePosition(samples, sampleRate, preskip);
}

#endif
