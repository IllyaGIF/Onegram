#ifndef TGFlacDecoder_h
#define TGFlacDecoder_h

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/*
 * Small FLAC decoder used by Onegram on iOS versions where AVFoundation
 * cannot decode FLAC. It implements the FLAC stream format needed for normal
 * music files: STREAMINFO, constant/verbatim/fixed/LPC subframes, Rice/Rice2
 * residuals and independent/left-side/right-side/mid-side channel coding.
 */

typedef struct TGFLACBitReader {
    FILE *file;
    uint8_t byte;
    int bitsLeft;
    int failed;
} TGFLACBitReader;

typedef struct TGFLACDecoder {
    FILE *file;
    long dataOffset;
    uint32_t sampleRate;
    uint32_t channels;
    uint32_t bitsPerSample;
    uint32_t maxBlockSize;
    uint64_t totalFrames;
    uint64_t decodedFramePosition;
    uint32_t frameBlockSize;
    uint32_t frameReadOffset;
    int32_t *sampleStorage;
    int32_t *samples[8];
    int failed;
    int needMoreData;
} TGFLACDecoder;

static uint16_t tgflac_be16(const uint8_t *p)
{
    return (uint16_t)(((uint16_t)p[0] << 8) | p[1]);
}

static uint32_t tgflac_be24(const uint8_t *p)
{
    return ((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | p[2];
}

static uint64_t tgflac_be64(const uint8_t *p)
{
    uint64_t v = 0;
    int i;
    for (i = 0; i < 8; i++)
        v = (v << 8) | p[i];
    return v;
}

static void tgflac_br_init(TGFLACBitReader *br, FILE *file)
{
    br->file = file;
    br->byte = 0;
    br->bitsLeft = 0;
    br->failed = 0;
}

static uint32_t tgflac_br_bits(TGFLACBitReader *br, int count)
{
    uint32_t value = 0;
    while (count > 0 && !br->failed)
    {
        int take;
        if (br->bitsLeft == 0)
        {
            int c = fgetc(br->file);
            if (c == EOF)
            {
                br->failed = 1;
                return 0;
            }
            br->byte = (uint8_t)c;
            br->bitsLeft = 8;
        }
        take = count < br->bitsLeft ? count : br->bitsLeft;
        value = (value << take) | ((br->byte >> (br->bitsLeft - take)) & ((1u << take) - 1u));
        br->bitsLeft -= take;
        count -= take;
    }
    return value;
}

static int32_t tgflac_br_sbits(TGFLACBitReader *br, int count)
{
    uint32_t value;
    if (count <= 0)
        return 0;
    value = tgflac_br_bits(br, count);
    if (count < 32 && (value & (1u << (count - 1))))
        value |= ~((1u << count) - 1u);
    return (int32_t)value;
}

static void tgflac_br_align(TGFLACBitReader *br)
{
    br->bitsLeft = 0;
}

static int tgflac_br_unary(TGFLACBitReader *br)
{
    int value = 0;
    while (!br->failed)
    {
        if (tgflac_br_bits(br, 1) != 0)
            return value;
        value++;
        if (value > 0x7fffffff / 2)
        {
            br->failed = 1;
            return 0;
        }
    }
    return 0;
}

static uint64_t tgflac_read_utf8_uint(TGFLACBitReader *br)
{
    uint8_t first = (uint8_t)tgflac_br_bits(br, 8);
    int bytes = 0;
    uint64_t value;
    int i;
    if ((first & 0x80) == 0)
        return first;
    while (bytes < 7 && (first & (0x80 >> bytes)) != 0)
        bytes++;
    if (bytes < 2 || bytes > 7)
    {
        br->failed = 1;
        return 0;
    }
    value = first & ((1u << (7 - bytes)) - 1u);
    for (i = 1; i < bytes; i++)
    {
        uint8_t c = (uint8_t)tgflac_br_bits(br, 8);
        if ((c & 0xC0) != 0x80)
        {
            br->failed = 1;
            return 0;
        }
        value = (value << 6) | (c & 0x3F);
    }
    return value;
}

static int32_t tgflac_rice_signed(TGFLACBitReader *br, int parameter)
{
    uint64_t quotient = (uint64_t)tgflac_br_unary(br);
    uint64_t remainder = parameter == 0 ? 0 : tgflac_br_bits(br, parameter);
    uint64_t folded = (quotient << parameter) | remainder;
    return (int32_t)((folded >> 1) ^ (uint64_t)-(int64_t)(folded & 1));
}

static int tgflac_decode_residual(TGFLACBitReader *br, int32_t *samples, uint32_t blockSize, int predictorOrder)
{
    uint32_t method = tgflac_br_bits(br, 2);
    uint32_t partitionOrder;
    uint32_t partitions;
    uint32_t partition;
    int parameterBits;
    uint32_t out = (uint32_t)predictorOrder;
    if (method > 1)
        return 0;
    parameterBits = method == 0 ? 4 : 5;
    partitionOrder = tgflac_br_bits(br, 4);
    if (partitionOrder > 15 || (blockSize >> partitionOrder) == 0)
        return 0;
    partitions = 1u << partitionOrder;
    for (partition = 0; partition < partitions; partition++)
    {
        uint32_t count = blockSize >> partitionOrder;
        uint32_t parameter;
        uint32_t i;
        if (partition == 0)
        {
            if (count < (uint32_t)predictorOrder)
                return 0;
            count -= (uint32_t)predictorOrder;
        }
        parameter = tgflac_br_bits(br, parameterBits);
        if (parameter == ((1u << parameterBits) - 1u))
        {
            uint32_t rawBits = tgflac_br_bits(br, 5);
            for (i = 0; i < count; i++)
                samples[out++] = rawBits == 0 ? 0 : tgflac_br_sbits(br, (int)rawBits);
        }
        else
        {
            for (i = 0; i < count; i++)
                samples[out++] = tgflac_rice_signed(br, (int)parameter);
        }
        if (br->failed)
            return 0;
    }
    return out == blockSize;
}

static int tgflac_decode_subframe(TGFLACBitReader *br, int32_t *samples, uint32_t blockSize, int bps)
{
    uint32_t zero = tgflac_br_bits(br, 1);
    uint32_t type = tgflac_br_bits(br, 6);
    uint32_t wastedFlag = tgflac_br_bits(br, 1);
    int wasted = 0;
    uint32_t i;
    if (zero != 0)
        return 0;
    if (wastedFlag)
    {
        wasted = tgflac_br_unary(br) + 1;
        bps -= wasted;
    }
    if (bps <= 0 || bps > 32)
        return 0;

    if (type == 0)
    {
        int32_t value = tgflac_br_sbits(br, bps);
        for (i = 0; i < blockSize; i++)
            samples[i] = value;
    }
    else if (type == 1)
    {
        for (i = 0; i < blockSize; i++)
            samples[i] = tgflac_br_sbits(br, bps);
    }
    else if (type >= 8 && type <= 12)
    {
        int order = (int)type - 8;
        for (i = 0; i < (uint32_t)order; i++)
            samples[i] = tgflac_br_sbits(br, bps);
        if (!tgflac_decode_residual(br, samples, blockSize, order))
            return 0;
        for (i = (uint32_t)order; i < blockSize; i++)
        {
            int64_t prediction = 0;
            switch (order)
            {
                case 0: prediction = 0; break;
                case 1: prediction = samples[i - 1]; break;
                case 2: prediction = 2LL * samples[i - 1] - samples[i - 2]; break;
                case 3: prediction = 3LL * samples[i - 1] - 3LL * samples[i - 2] + samples[i - 3]; break;
                case 4: prediction = 4LL * samples[i - 1] - 6LL * samples[i - 2] + 4LL * samples[i - 3] - samples[i - 4]; break;
            }
            samples[i] = (int32_t)(prediction + samples[i]);
        }
    }
    else if (type >= 32)
    {
        int order = (int)(type & 31) + 1;
        uint32_t precision;
        int shift;
        int32_t coeffs[32];
        int j;
        if (order > 32 || (uint32_t)order > blockSize)
            return 0;
        for (i = 0; i < (uint32_t)order; i++)
            samples[i] = tgflac_br_sbits(br, bps);
        precision = tgflac_br_bits(br, 4);
        if (precision == 15)
            return 0;
        precision += 1;
        shift = tgflac_br_sbits(br, 5);
        for (j = 0; j < order; j++)
            coeffs[j] = tgflac_br_sbits(br, (int)precision);
        if (!tgflac_decode_residual(br, samples, blockSize, order))
            return 0;
        for (i = (uint32_t)order; i < blockSize; i++)
        {
            int64_t sum = 0;
            int64_t prediction;
            for (j = 0; j < order; j++)
                sum += (int64_t)coeffs[j] * samples[i - (uint32_t)j - 1];
            prediction = shift >= 0 ? (sum >> shift) : (sum << (-shift));
            samples[i] = (int32_t)(prediction + samples[i]);
        }
    }
    else
    {
        return 0;
    }

    if (wasted > 0)
    {
        for (i = 0; i < blockSize; i++)
            samples[i] <<= wasted;
    }
    return !br->failed;
}

static int tgflac_frame_block_size(TGFLACBitReader *br, uint32_t code)
{
    if (code == 0)
        return 0;
    if (code == 1)
        return 192;
    if (code >= 2 && code <= 5)
        return 576 << (code - 2);
    if (code == 6)
        return (int)tgflac_br_bits(br, 8) + 1;
    if (code == 7)
        return (int)tgflac_br_bits(br, 16) + 1;
    return 256 << (code - 8);
}

static void tgflac_consume_sample_rate_extra(TGFLACBitReader *br, uint32_t code)
{
    if (code == 12)
        (void)tgflac_br_bits(br, 8);
    else if (code == 13 || code == 14)
        (void)tgflac_br_bits(br, 16);
}

static int tgflac_decode_frame(TGFLACDecoder *d)
{
    TGFLACBitReader br;
    uint32_t sync;
    uint32_t reserved;
    uint32_t blockCode;
    uint32_t sampleRateCode;
    uint32_t channelAssignment;
    uint32_t sampleSizeCode;
    uint32_t blockSize;
    uint32_t channels;
    uint32_t channel;
    int bps;
    long frameStart = ftell(d->file);
    d->needMoreData = 0;

    tgflac_br_init(&br, d->file);
    sync = tgflac_br_bits(&br, 14);
    reserved = tgflac_br_bits(&br, 1);
    (void)tgflac_br_bits(&br, 1); /* blocking strategy */
    blockCode = tgflac_br_bits(&br, 4);
    sampleRateCode = tgflac_br_bits(&br, 4);
    channelAssignment = tgflac_br_bits(&br, 4);
    sampleSizeCode = tgflac_br_bits(&br, 3);
    if (br.failed)
    {
        clearerr(d->file);
        fseek(d->file, frameStart, SEEK_SET);
        d->needMoreData = 1;
        return 0;
    }
    if (sync != 0x3FFE || reserved != 0 || tgflac_br_bits(&br, 1) != 0 || sampleRateCode == 15 || sampleSizeCode == 3 || sampleSizeCode == 7)
        return 0;

    (void)tgflac_read_utf8_uint(&br);
    blockSize = (uint32_t)tgflac_frame_block_size(&br, blockCode);
    tgflac_consume_sample_rate_extra(&br, sampleRateCode);
    (void)tgflac_br_bits(&br, 8); /* header CRC-8 */
    if (br.failed)
    {
        clearerr(d->file);
        fseek(d->file, frameStart, SEEK_SET);
        d->needMoreData = 1;
        return 0;
    }
    if (blockSize == 0 || blockSize > d->maxBlockSize)
        return 0;

    if (sampleSizeCode == 0)
        bps = (int)d->bitsPerSample;
    else if (sampleSizeCode == 1)
        bps = 8;
    else if (sampleSizeCode == 2)
        bps = 12;
    else if (sampleSizeCode == 4)
        bps = 16;
    else if (sampleSizeCode == 5)
        bps = 20;
    else
        bps = 24;

    channels = channelAssignment <= 7 ? channelAssignment + 1 : 2;
    if (channels != d->channels || channels > 8)
        return 0;

    for (channel = 0; channel < channels; channel++)
    {
        int channelBps = bps;
        if ((channelAssignment == 8 && channel == 1) ||
            (channelAssignment == 9 && channel == 0) ||
            (channelAssignment == 10 && channel == 1))
            channelBps++;
        if (!tgflac_decode_subframe(&br, d->samples[channel], blockSize, channelBps))
        {
            if (br.failed)
            {
                clearerr(d->file);
                fseek(d->file, frameStart, SEEK_SET);
                d->needMoreData = 1;
            }
            return 0;
        }
    }

    if (channelAssignment == 8)
    {
        uint32_t i;
        for (i = 0; i < blockSize; i++)
            d->samples[1][i] = d->samples[0][i] - d->samples[1][i];
    }
    else if (channelAssignment == 9)
    {
        uint32_t i;
        for (i = 0; i < blockSize; i++)
            d->samples[0][i] = d->samples[0][i] + d->samples[1][i];
    }
    else if (channelAssignment == 10)
    {
        uint32_t i;
        for (i = 0; i < blockSize; i++)
        {
            int64_t mid = d->samples[0][i];
            int64_t side = d->samples[1][i];
            mid = (mid << 1) | (side & 1);
            d->samples[0][i] = (int32_t)((mid + side) >> 1);
            d->samples[1][i] = (int32_t)((mid - side) >> 1);
        }
    }

    tgflac_br_align(&br);
    (void)tgflac_br_bits(&br, 16); /* frame CRC-16 */
    if (br.failed)
    {
        clearerr(d->file);
        fseek(d->file, frameStart, SEEK_SET);
        d->needMoreData = 1;
        return 0;
    }

    d->needMoreData = 0;
    d->frameBlockSize = blockSize;
    d->frameReadOffset = 0;
    return 1;
}

static int16_t tgflac_to_s16(int32_t value, uint32_t bps)
{
    int64_t v = value;
    if (bps > 16)
        v >>= (bps - 16);
    else if (bps < 16)
        v <<= (16 - bps);
    if (v > 32767)
        v = 32767;
    if (v < -32768)
        v = -32768;
    return (int16_t)v;
}

static TGFLACDecoder *tgflac_open(const char *path)
{
    TGFLACDecoder *d;
    uint8_t magic[4];
    int last = 0;
    uint32_t maxBlock = 0;
    if (path == NULL)
        return NULL;
    d = (TGFLACDecoder *)calloc(1, sizeof(TGFLACDecoder));
    if (d == NULL)
        return NULL;
    d->file = fopen(path, "rb");
    if (d->file == NULL)
    {
        free(d);
        return NULL;
    }
    if (fread(magic, 1, 4, d->file) != 4 || memcmp(magic, "fLaC", 4) != 0)
        goto fail;

    while (!last)
    {
        uint8_t header[4];
        uint32_t type;
        uint32_t length;
        if (fread(header, 1, 4, d->file) != 4)
            goto fail;
        last = (header[0] & 0x80) != 0;
        type = header[0] & 0x7F;
        length = tgflac_be24(header + 1);
        if (type == 0)
        {
            uint8_t info[34];
            uint64_t packed;
            if (length != 34 || fread(info, 1, 34, d->file) != 34)
                goto fail;
            maxBlock = tgflac_be16(info + 2);
            packed = tgflac_be64(info + 10);
            d->sampleRate = (uint32_t)((packed >> 44) & 0xFFFFF);
            d->channels = (uint32_t)(((packed >> 41) & 7) + 1);
            d->bitsPerSample = (uint32_t)(((packed >> 36) & 31) + 1);
            d->totalFrames = packed & UINT64_C(0xFFFFFFFFF);
        }
        else
        {
            if (fseek(d->file, (long)length, SEEK_CUR) != 0)
                goto fail;
        }
    }
    d->dataOffset = ftell(d->file);
    d->maxBlockSize = maxBlock != 0 ? maxBlock : 65535;
    if (d->sampleRate == 0 || d->channels == 0 || d->channels > 8 || d->bitsPerSample == 0 || d->bitsPerSample > 32)
        goto fail;
    d->sampleStorage = (int32_t *)calloc((size_t)d->maxBlockSize * d->channels, sizeof(int32_t));
    if (d->sampleStorage == NULL)
        goto fail;
    {
        uint32_t c;
        for (c = 0; c < d->channels; c++)
            d->samples[c] = d->sampleStorage + (size_t)c * d->maxBlockSize;
    }
    return d;

fail:
    if (d->file != NULL)
        fclose(d->file);
    free(d->sampleStorage);
    free(d);
    return NULL;
}

static void tgflac_close(TGFLACDecoder *d)
{
    if (d == NULL)
        return;
    if (d->file != NULL)
        fclose(d->file);
    free(d->sampleStorage);
    free(d);
}

static uint32_t tgflac_output_channels(TGFLACDecoder *d)
{
    if (d == NULL)
        return 0;
    return d->channels == 1 ? 1 : 2;
}

static uint64_t tgflac_read_s16(TGFLACDecoder *d, uint64_t requestedFrames, int16_t *output)
{
    uint64_t written = 0;
    uint32_t outputChannels;
    if (d == NULL || output == NULL || requestedFrames == 0 || d->failed)
        return 0;
    outputChannels = tgflac_output_channels(d);
    while (written < requestedFrames)
    {
        uint32_t available;
        uint32_t take;
        uint32_t i;
        if (d->frameReadOffset >= d->frameBlockSize)
        {
            if (!tgflac_decode_frame(d))
                break;
        }
        available = d->frameBlockSize - d->frameReadOffset;
        take = (uint32_t)((requestedFrames - written) < available ? (requestedFrames - written) : available);
        for (i = 0; i < take; i++)
        {
            uint32_t sourceIndex = d->frameReadOffset + i;
            output[(written + i) * outputChannels] = tgflac_to_s16(d->samples[0][sourceIndex], d->bitsPerSample);
            if (outputChannels == 2)
                output[(written + i) * 2 + 1] = tgflac_to_s16(d->samples[1][sourceIndex], d->bitsPerSample);
        }
        d->frameReadOffset += take;
        d->decodedFramePosition += take;
        written += take;
    }
    return written;
}

static int tgflac_seek(TGFLACDecoder *d, uint64_t targetFrame)
{
    int16_t *scratch;
    uint32_t outputChannels;
    const uint32_t chunk = 4096;
    if (d == NULL)
        return 0;
    if (targetFrame > d->totalFrames && d->totalFrames != 0)
        targetFrame = d->totalFrames;
    if (fseek(d->file, d->dataOffset, SEEK_SET) != 0)
        return 0;
    d->decodedFramePosition = 0;
    d->frameBlockSize = 0;
    d->frameReadOffset = 0;
    d->failed = 0;
    if (targetFrame == 0)
        return 1;
    outputChannels = tgflac_output_channels(d);
    scratch = (int16_t *)malloc(sizeof(int16_t) * chunk * outputChannels);
    if (scratch == NULL)
        return 0;
    while (d->decodedFramePosition < targetFrame)
    {
        uint64_t remaining = targetFrame - d->decodedFramePosition;
        uint64_t request = remaining < chunk ? remaining : chunk;
        uint64_t got = tgflac_read_s16(d, request, scratch);
        if (got == 0)
            break;
    }
    free(scratch);
    return d->decodedFramePosition >= targetFrame;
}

static int tgflac_is_file(const char *path)
{
    FILE *f;
    uint8_t magic[4];
    int result = 0;
    if (path == NULL)
        return 0;
    f = fopen(path, "rb");
    if (f == NULL)
        return 0;
    if (fread(magic, 1, 4, f) == 4 && memcmp(magic, "fLaC", 4) == 0)
        result = 1;
    fclose(f);
    return result;
}

#endif
