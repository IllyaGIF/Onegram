#ifndef TG_PCM_BUFFER_H
#define TG_PCM_BUFFER_H

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct
{
    uint32_t capacity;
    uint32_t channels;
    volatile uint32_t readOffset;
    volatile uint32_t writeOffset;
    int16_t *samples;
} TGPCMBuffer;

static inline uint32_t TGPCMBufferLoad(volatile uint32_t *value)
{
    return __sync_fetch_and_add(value, 0);
}

static inline void TGPCMBufferStore(volatile uint32_t *value, uint32_t updated)
{
    __sync_synchronize();
    __sync_lock_test_and_set(value, updated);
}

static inline TGPCMBuffer *TGPCMBufferCreate(uint32_t capacity, uint32_t channels)
{
    if (capacity == 0 || (capacity & (capacity - 1)) != 0 || capacity > UINT32_MAX / 2 || channels == 0 || channels > 2 || capacity > SIZE_MAX / channels / sizeof(int16_t))
        return NULL;
    TGPCMBuffer *buffer = (TGPCMBuffer *)calloc(1, sizeof(TGPCMBuffer));
    if (buffer == NULL)
        return NULL;
    buffer->samples = (int16_t *)malloc((size_t)capacity * channels * sizeof(int16_t));
    if (buffer->samples == NULL)
    {
        free(buffer);
        return NULL;
    }
    buffer->capacity = capacity;
    buffer->channels = channels;
    return buffer;
}

static inline void TGPCMBufferDestroy(TGPCMBuffer *buffer)
{
    if (buffer != NULL)
    {
        free(buffer->samples);
        free(buffer);
    }
}

static inline uint32_t TGPCMBufferReadable(TGPCMBuffer *buffer)
{
    return TGPCMBufferLoad(&buffer->writeOffset) - TGPCMBufferLoad(&buffer->readOffset);
}

static inline uint32_t TGPCMBufferWritable(TGPCMBuffer *buffer)
{
    return buffer->capacity - TGPCMBufferReadable(buffer);
}

static inline uint32_t TGPCMBufferWrite(TGPCMBuffer *buffer, const int16_t *samples, uint32_t frames)
{
    uint32_t writeOffset = TGPCMBufferLoad(&buffer->writeOffset);
    uint32_t available = buffer->capacity - (writeOffset - TGPCMBufferLoad(&buffer->readOffset));
    if (frames > available)
        frames = available;
    uint32_t position = writeOffset % buffer->capacity;
    uint32_t first = frames < buffer->capacity - position ? frames : buffer->capacity - position;
    size_t frameBytes = buffer->channels * sizeof(int16_t);
    if (first != 0)
        memcpy(buffer->samples + (size_t)position * buffer->channels, samples, first * frameBytes);
    if (frames != first)
        memcpy(buffer->samples, samples + (size_t)first * buffer->channels, (frames - first) * frameBytes);
    TGPCMBufferStore(&buffer->writeOffset, writeOffset + frames);
    return frames;
}

static inline uint32_t TGPCMBufferRead(TGPCMBuffer *buffer, int16_t *samples, uint32_t frames)
{
    uint32_t readOffset = TGPCMBufferLoad(&buffer->readOffset);
    uint32_t available = TGPCMBufferLoad(&buffer->writeOffset) - readOffset;
    if (frames > available)
        frames = available;
    uint32_t position = readOffset % buffer->capacity;
    uint32_t first = frames < buffer->capacity - position ? frames : buffer->capacity - position;
    size_t frameBytes = buffer->channels * sizeof(int16_t);
    if (first != 0)
        memcpy(samples, buffer->samples + (size_t)position * buffer->channels, first * frameBytes);
    if (frames != first)
        memcpy(samples + (size_t)first * buffer->channels, buffer->samples, (frames - first) * frameBytes);
    TGPCMBufferStore(&buffer->readOffset, readOffset + frames);
    return frames;
}

static inline void TGPCMBufferReset(TGPCMBuffer *buffer)
{
    TGPCMBufferStore(&buffer->readOffset, 0);
    TGPCMBufferStore(&buffer->writeOffset, 0);
}

#endif
