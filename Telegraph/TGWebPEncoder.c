#include "TGWebPEncoder.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

#define TGWebPMaxCodeLength 15
#define TGWebPMaxCodeLengthCodeLength 7
#define TGWebPCodeLengthCodes 19
#define TGWebPGreenAlphabet 280
#define TGWebPDistanceAlphabet 40

typedef struct
{
    uint8_t *data;
    size_t size;
    size_t capacity;
    uint64_t accumulator;
    int used;
    int failed;
} TGWebPBitWriter;

typedef struct
{
    int alphabetSize;
    uint8_t lengths[TGWebPGreenAlphabet];
    uint16_t codes[TGWebPGreenAlphabet];
    int singleSymbol;
} TGWebPHuffmanCode;

static const int TGWebPCodeLengthCodeOrder[TGWebPCodeLengthCodes] = { 17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

static void TGWebPWriterReserve(TGWebPBitWriter *writer, size_t extra)
{
    if (writer->failed || writer->size + extra <= writer->capacity)
        return;
    size_t capacity = writer->capacity == 0 ? 4096 : writer->capacity;
    while (capacity < writer->size + extra)
        capacity *= 2;
    uint8_t *data = (uint8_t *)realloc(writer->data, capacity);
    if (data == NULL)
    {
        writer->failed = 1;
        return;
    }
    writer->data = data;
    writer->capacity = capacity;
}

static void TGWebPWriteBits(TGWebPBitWriter *writer, uint32_t value, int count)
{
    if (count == 0)
        return;
    writer->accumulator |= ((uint64_t)(value & ((count == 32) ? 0xffffffffu : ((1u << count) - 1u)))) << writer->used;
    writer->used += count;
    while (writer->used >= 8)
    {
        TGWebPWriterReserve(writer, 1);
        if (writer->failed)
            return;
        writer->data[writer->size++] = (uint8_t)(writer->accumulator & 0xff);
        writer->accumulator >>= 8;
        writer->used -= 8;
    }
}

static void TGWebPFlushBits(TGWebPBitWriter *writer)
{
    if (writer->used > 0)
        TGWebPWriteBits(writer, 0, 8 - writer->used);
}

typedef struct
{
    uint32_t count;
    int left;
    int right;
    int symbol;
} TGWebPHuffmanNode;

static int TGWebPCompareNodes(const void *lhs, const void *rhs)
{
    const TGWebPHuffmanNode *a = (const TGWebPHuffmanNode *)lhs;
    const TGWebPHuffmanNode *b = (const TGWebPHuffmanNode *)rhs;
    if (a->count != b->count)
        return a->count < b->count ? -1 : 1;
    return a->symbol - b->symbol;
}

static void TGWebPAssignDepths(TGWebPHuffmanNode *nodes, int index, int depth, uint8_t *lengths, int *maxDepth)
{
    if (nodes[index].symbol >= 0)
    {
        lengths[nodes[index].symbol] = (uint8_t)(depth == 0 ? 1 : depth);
        if (depth > *maxDepth)
            *maxDepth = depth;
        return;
    }
    TGWebPAssignDepths(nodes, nodes[index].left, depth + 1, lengths, maxDepth);
    TGWebPAssignDepths(nodes, nodes[index].right, depth + 1, lengths, maxDepth);
}

static int TGWebPBuildLengths(const uint32_t *histogram, int alphabetSize, int limit, uint8_t *lengths)
{
    memset(lengths, 0, (size_t)alphabetSize);
    int used = 0;
    for (int i = 0; i < alphabetSize; i++)
    {
        if (histogram[i] != 0)
            used++;
    }
    if (used == 0)
        return 0;
    if (used == 1)
    {
        for (int i = 0; i < alphabetSize; i++)
        {
            if (histogram[i] != 0)
                lengths[i] = 1;
        }
        return 1;
    }

    TGWebPHuffmanNode *nodes = (TGWebPHuffmanNode *)malloc(sizeof(TGWebPHuffmanNode) * (size_t)used * 2);
    if (nodes == NULL)
        return -1;
    uint32_t countMin = 1;
    for (;;)
    {
        int count = 0;
        for (int i = 0; i < alphabetSize; i++)
        {
            if (histogram[i] != 0)
            {
                nodes[count].count = histogram[i] < countMin ? countMin : histogram[i];
                nodes[count].left = -1;
                nodes[count].right = -1;
                nodes[count].symbol = i;
                count++;
            }
        }
        qsort(nodes, (size_t)count, sizeof(TGWebPHuffmanNode), TGWebPCompareNodes);
        int total = count;
        int queueStart = 0;
        int mergedStart = count;
        int mergedEnd = count;
        while ((count - queueStart) + (mergedEnd - mergedStart) > 1)
        {
            int picks[2];
            for (int p = 0; p < 2; p++)
            {
                if (queueStart < count && (mergedStart >= mergedEnd || nodes[queueStart].count <= nodes[mergedStart].count))
                    picks[p] = queueStart++;
                else
                    picks[p] = mergedStart++;
            }
            nodes[total].count = nodes[picks[0]].count + nodes[picks[1]].count;
            nodes[total].left = picks[0];
            nodes[total].right = picks[1];
            nodes[total].symbol = -1;
            total++;
            mergedEnd = total;
        }
        int maxDepth = 0;
        memset(lengths, 0, (size_t)alphabetSize);
        TGWebPAssignDepths(nodes, total - 1, 0, lengths, &maxDepth);
        if (maxDepth <= limit)
            break;
        countMin *= 2;
    }
    free(nodes);
    return used;
}

static void TGWebPBuildCodes(TGWebPHuffmanCode *code)
{
    int blCount[TGWebPMaxCodeLength + 1];
    int nextCode[TGWebPMaxCodeLength + 1];
    memset(blCount, 0, sizeof(blCount));
    int used = 0;
    for (int i = 0; i < code->alphabetSize; i++)
    {
        if (code->lengths[i] != 0)
        {
            blCount[code->lengths[i]]++;
            used++;
        }
    }
    code->singleSymbol = used <= 1;
    int value = 0;
    blCount[0] = 0;
    for (int bits = 1; bits <= TGWebPMaxCodeLength; bits++)
    {
        value = (value + blCount[bits - 1]) << 1;
        nextCode[bits] = value;
    }
    for (int i = 0; i < code->alphabetSize; i++)
    {
        int length = code->lengths[i];
        if (length == 0)
        {
            code->codes[i] = 0;
            continue;
        }
        int canonical = nextCode[length]++;
        int reversed = 0;
        for (int b = 0; b < length; b++)
            reversed |= ((canonical >> b) & 1) << (length - 1 - b);
        code->codes[i] = (uint16_t)reversed;
    }
}

static void TGWebPWriteSymbol(TGWebPBitWriter *writer, const TGWebPHuffmanCode *code, int symbol)
{
    if (code->singleSymbol)
        return;
    TGWebPWriteBits(writer, code->codes[symbol], code->lengths[symbol]);
}

static int TGWebPPrepareCode(TGWebPHuffmanCode *code, const uint32_t *histogram, int alphabetSize)
{
    code->alphabetSize = alphabetSize;
    int used = TGWebPBuildLengths(histogram, alphabetSize, TGWebPMaxCodeLength, code->lengths);
    if (used < 0)
        return 0;
    if (used == 0)
        code->lengths[0] = 1;
    TGWebPBuildCodes(code);
    return 1;
}

static void TGWebPWriteCode(TGWebPBitWriter *writer, const TGWebPHuffmanCode *code)
{
    int symbols[2] = { -1, -1 };
    int used = 0;
    for (int i = 0; i < code->alphabetSize; i++)
    {
        if (code->lengths[i] != 0)
        {
            if (used < 2)
                symbols[used] = i;
            used++;
        }
    }

    if (used <= 2 && symbols[0] < 256 && (used < 2 || symbols[1] < 256))
    {
        TGWebPWriteBits(writer, 1, 1);
        TGWebPWriteBits(writer, (uint32_t)(used - 1), 1);
        if (symbols[0] <= 1)
        {
            TGWebPWriteBits(writer, 0, 1);
            TGWebPWriteBits(writer, (uint32_t)symbols[0], 1);
        }
        else
        {
            TGWebPWriteBits(writer, 1, 1);
            TGWebPWriteBits(writer, (uint32_t)symbols[0], 8);
        }
        if (used == 2)
            TGWebPWriteBits(writer, (uint32_t)symbols[1], 8);
        return;
    }

    uint32_t lengthHistogram[TGWebPCodeLengthCodes];
    memset(lengthHistogram, 0, sizeof(lengthHistogram));
    for (int i = 0; i < code->alphabetSize; i++)
        lengthHistogram[code->lengths[i]]++;

    TGWebPHuffmanCode lengthCode;
    memset(&lengthCode, 0, sizeof(lengthCode));
    lengthCode.alphabetSize = TGWebPCodeLengthCodes;
    TGWebPBuildLengths(lengthHistogram, TGWebPCodeLengthCodes, TGWebPMaxCodeLengthCodeLength, lengthCode.lengths);
    TGWebPBuildCodes(&lengthCode);

    int codeCount = TGWebPCodeLengthCodes;
    while (codeCount > 4 && lengthCode.lengths[TGWebPCodeLengthCodeOrder[codeCount - 1]] == 0)
        codeCount--;

    TGWebPWriteBits(writer, 0, 1);
    TGWebPWriteBits(writer, (uint32_t)(codeCount - 4), 4);
    for (int i = 0; i < codeCount; i++)
        TGWebPWriteBits(writer, lengthCode.lengths[TGWebPCodeLengthCodeOrder[i]], 3);
    TGWebPWriteBits(writer, 0, 1);
    for (int i = 0; i < code->alphabetSize; i++)
        TGWebPWriteSymbol(writer, &lengthCode, code->lengths[i]);
}

static inline uint32_t TGWebPAverage2(uint32_t a, uint32_t b)
{
    return (((a ^ b) & 0xfefefefeu) >> 1) + (a & b);
}

static inline uint32_t TGWebPClampAddSubtractFull(uint32_t a, uint32_t b, uint32_t c)
{
    uint32_t result = 0;
    for (int shift = 0; shift < 32; shift += 8)
    {
        int value = (int)((a >> shift) & 0xff) + (int)((b >> shift) & 0xff) - (int)((c >> shift) & 0xff);
        if (value < 0)
            value = 0;
        else if (value > 255)
            value = 255;
        result |= (uint32_t)value << shift;
    }
    return result;
}

static inline uint32_t TGWebPSubtractPixels(uint32_t a, uint32_t b)
{
    uint32_t alphaGreen = 0x00ff00ffu + (a & 0xff00ff00u) - (b & 0xff00ff00u);
    uint32_t redBlue = 0xff00ff00u + (a & 0x00ff00ffu) - (b & 0x00ff00ffu);
    return (alphaGreen & 0xff00ff00u) | (redBlue & 0x00ff00ffu);
}

static uint32_t TGWebPPredict(const uint32_t *argb, int width, int x, int y, int mode)
{
    if (x == 0 && y == 0)
        return 0xff000000u;
    if (y == 0)
        return argb[x - 1];
    if (x == 0)
        return argb[(y - 1) * width];
    uint32_t left = argb[y * width + x - 1];
    uint32_t top = argb[(y - 1) * width + x];
    uint32_t topLeft = argb[(y - 1) * width + x - 1];
    switch (mode)
    {
        case 1:
            return left;
        case 2:
            return top;
        case 7:
            return TGWebPAverage2(left, top);
        default:
            return TGWebPClampAddSubtractFull(left, top, topLeft);
    }
}

static double TGWebPEntropy(const uint32_t *histogram, int size, uint32_t total)
{
    double result = 0.0;
    for (int i = 0; i < size; i++)
    {
        if (histogram[i] != 0)
        {
            double p = (double)histogram[i] / (double)total;
            result -= (double)histogram[i] * log2(p);
        }
    }
    return result;
}

static void TGWebPResiduals(const uint32_t *argb, int width, int height, int mode, uint32_t *residuals)
{
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            int index = y * width + x;
            residuals[index] = TGWebPSubtractPixels(argb[index], TGWebPPredict(argb, width, x, y, mode));
        }
    }
}

static double TGWebPResidualCost(const uint32_t *residuals, size_t count)
{
    uint32_t histograms[4][256];
    memset(histograms, 0, sizeof(histograms));
    for (size_t i = 0; i < count; i++)
    {
        uint32_t pixel = residuals[i];
        histograms[0][(pixel >> 8) & 0xff]++;
        histograms[1][(pixel >> 16) & 0xff]++;
        histograms[2][pixel & 0xff]++;
        histograms[3][(pixel >> 24) & 0xff]++;
    }
    double cost = 0.0;
    for (int c = 0; c < 4; c++)
        cost += TGWebPEntropy(histograms[c], 256, (uint32_t)count);
    return cost;
}

typedef struct
{
    uint32_t value;
    uint16_t length;
    uint8_t distanceCode;
} TGWebPToken;

static void TGWebPPrefixEncode(int value, int *symbol, int *extraBits, int *extraValue)
{
    int n = value - 1;
    if (n < 4)
    {
        *symbol = n;
        *extraBits = 0;
        *extraValue = 0;
        return;
    }
    int highest = 31;
    while (((n >> highest) & 1) == 0)
        highest--;
    int second = (n >> (highest - 1)) & 1;
    *symbol = 2 * highest + second;
    *extraBits = highest - 1;
    *extraValue = n & ((1 << *extraBits) - 1);
}

static size_t TGWebPMatchLength(const uint32_t *pixels, size_t index, size_t distance, size_t count)
{
    size_t length = 0;
    size_t limit = count - index;
    if (limit > 4096)
        limit = 4096;
    while (length < limit && pixels[index + length] == pixels[index + length - distance])
        length++;
    return length;
}

static size_t TGWebPBuildTokens(const uint32_t *pixels, size_t count, int width, int useBackwardReferences, TGWebPToken *tokens)
{
    size_t tokenCount = 0;
    size_t index = 0;
    while (index < count)
    {
        size_t bestLength = 0;
        uint8_t bestCode = 0;
        if (useBackwardReferences)
        {
            if (index >= (size_t)width)
            {
                size_t length = TGWebPMatchLength(pixels, index, (size_t)width, count);
                if (length > bestLength)
                {
                    bestLength = length;
                    bestCode = 1;
                }
            }
            if (index >= 1)
            {
                size_t length = TGWebPMatchLength(pixels, index, 1, count);
                if (length > bestLength)
                {
                    bestLength = length;
                    bestCode = 2;
                }
            }
        }
        if (bestLength >= 3)
        {
            tokens[tokenCount].value = 0;
            tokens[tokenCount].length = (uint16_t)bestLength;
            tokens[tokenCount].distanceCode = bestCode;
            index += bestLength;
        }
        else
        {
            tokens[tokenCount].value = pixels[index];
            tokens[tokenCount].length = 0;
            tokens[tokenCount].distanceCode = 0;
            index++;
        }
        tokenCount++;
    }
    return tokenCount;
}

static void TGWebPWriteCodesAndPixels(TGWebPBitWriter *writer, const uint32_t *pixels, size_t count, int width, int isMainImage)
{
    TGWebPToken *tokens = (TGWebPToken *)malloc(count * sizeof(TGWebPToken));
    uint32_t *greenHistogram = (uint32_t *)calloc(TGWebPGreenAlphabet, sizeof(uint32_t));
    TGWebPHuffmanCode *codes = (TGWebPHuffmanCode *)calloc(5, sizeof(TGWebPHuffmanCode));
    if (tokens == NULL || greenHistogram == NULL || codes == NULL)
    {
        free(tokens);
        free(greenHistogram);
        free(codes);
        writer->failed = 1;
        return;
    }

    size_t tokenCount = TGWebPBuildTokens(pixels, count, width, isMainImage, tokens);

    uint32_t histograms[3][256];
    uint32_t distanceHistogram[TGWebPDistanceAlphabet];
    memset(histograms, 0, sizeof(histograms));
    memset(distanceHistogram, 0, sizeof(distanceHistogram));
    for (size_t i = 0; i < tokenCount; i++)
    {
        if (tokens[i].length != 0)
        {
            int symbol, extraBits, extraValue;
            TGWebPPrefixEncode(tokens[i].length, &symbol, &extraBits, &extraValue);
            greenHistogram[256 + symbol]++;
            TGWebPPrefixEncode(tokens[i].distanceCode, &symbol, &extraBits, &extraValue);
            distanceHistogram[symbol]++;
        }
        else
        {
            uint32_t pixel = tokens[i].value;
            greenHistogram[(pixel >> 8) & 0xff]++;
            histograms[0][(pixel >> 16) & 0xff]++;
            histograms[1][pixel & 0xff]++;
            histograms[2][(pixel >> 24) & 0xff]++;
        }
    }

    TGWebPPrepareCode(&codes[0], greenHistogram, TGWebPGreenAlphabet);
    TGWebPPrepareCode(&codes[1], histograms[0], 256);
    TGWebPPrepareCode(&codes[2], histograms[1], 256);
    TGWebPPrepareCode(&codes[3], histograms[2], 256);
    TGWebPPrepareCode(&codes[4], distanceHistogram, TGWebPDistanceAlphabet);

    TGWebPWriteBits(writer, 0, 1);
    if (isMainImage)
        TGWebPWriteBits(writer, 0, 1);
    for (int i = 0; i < 5; i++)
        TGWebPWriteCode(writer, &codes[i]);
    for (size_t i = 0; i < tokenCount && !writer->failed; i++)
    {
        if (tokens[i].length != 0)
        {
            int symbol, extraBits, extraValue;
            TGWebPPrefixEncode(tokens[i].length, &symbol, &extraBits, &extraValue);
            TGWebPWriteSymbol(writer, &codes[0], 256 + symbol);
            TGWebPWriteBits(writer, (uint32_t)extraValue, extraBits);
            TGWebPPrefixEncode(tokens[i].distanceCode, &symbol, &extraBits, &extraValue);
            TGWebPWriteSymbol(writer, &codes[4], symbol);
            TGWebPWriteBits(writer, (uint32_t)extraValue, extraBits);
        }
        else
        {
            uint32_t pixel = tokens[i].value;
            TGWebPWriteSymbol(writer, &codes[0], (int)((pixel >> 8) & 0xff));
            TGWebPWriteSymbol(writer, &codes[1], (int)((pixel >> 16) & 0xff));
            TGWebPWriteSymbol(writer, &codes[2], (int)(pixel & 0xff));
            TGWebPWriteSymbol(writer, &codes[3], (int)((pixel >> 24) & 0xff));
        }
    }
    free(codes);
    free(greenHistogram);
    free(tokens);
}

static void TGWebPWriteLE32(uint8_t *data, uint32_t value)
{
    data[0] = (uint8_t)(value & 0xff);
    data[1] = (uint8_t)((value >> 8) & 0xff);
    data[2] = (uint8_t)((value >> 16) & 0xff);
    data[3] = (uint8_t)((value >> 24) & 0xff);
}

uint8_t *TGWebPEncodeLosslessRGBA(const uint8_t *rgba, int width, int height, int stride, size_t *outSize)
{
    if (outSize != NULL)
        *outSize = 0;
    if (rgba == NULL || width <= 0 || height <= 0 || width > 16384 || height > 16384 || stride < width * 4)
        return NULL;

    size_t count = (size_t)width * (size_t)height;
    uint32_t *argb = (uint32_t *)malloc(count * sizeof(uint32_t));
    uint32_t *residuals = (uint32_t *)malloc(count * sizeof(uint32_t));
    uint32_t *best = (uint32_t *)malloc(count * sizeof(uint32_t));
    if (argb == NULL || residuals == NULL || best == NULL)
    {
        free(argb);
        free(residuals);
        free(best);
        return NULL;
    }

    for (int y = 0; y < height; y++)
    {
        const uint8_t *row = rgba + (size_t)y * (size_t)stride;
        for (int x = 0; x < width; x++)
        {
            uint32_t r = row[x * 4 + 0];
            uint32_t g = row[x * 4 + 1];
            uint32_t b = row[x * 4 + 2];
            uint32_t a = row[x * 4 + 3];
            if (a == 0)
                r = g = b = 0;
            uint32_t red = (r - g) & 0xff;
            uint32_t blue = (b - g) & 0xff;
            argb[(size_t)y * (size_t)width + (size_t)x] = (a << 24) | (red << 16) | (g << 8) | blue;
        }
    }

    static const int modes[] = { 12, 1, 2, 7 };
    int bestMode = modes[0];
    double bestCost = -1.0;
    for (size_t m = 0; m < sizeof(modes) / sizeof(modes[0]); m++)
    {
        TGWebPResiduals(argb, width, height, modes[m], residuals);
        double cost = TGWebPResidualCost(residuals, count);
        if (bestCost < 0.0 || cost < bestCost)
        {
            bestCost = cost;
            bestMode = modes[m];
            memcpy(best, residuals, count * sizeof(uint32_t));
        }
    }

    TGWebPBitWriter writer;
    memset(&writer, 0, sizeof(writer));
    TGWebPWriterReserve(&writer, 64);

    TGWebPWriteBits(&writer, 0x2f, 8);
    TGWebPWriteBits(&writer, (uint32_t)(width - 1), 14);
    TGWebPWriteBits(&writer, (uint32_t)(height - 1), 14);
    TGWebPWriteBits(&writer, 1, 1);
    TGWebPWriteBits(&writer, 0, 3);

    TGWebPWriteBits(&writer, 1, 1);
    TGWebPWriteBits(&writer, 2, 2);

    int sizeBits = 2;
    while ((1 << (sizeBits + 2)) < width || (1 << (sizeBits + 2)) < height)
    {
        if (sizeBits == 7)
            break;
        sizeBits++;
    }
    int blockSize = 1 << (sizeBits + 2);
    int subWidth = (width + blockSize - 1) / blockSize;
    int subHeight = (height + blockSize - 1) / blockSize;
    size_t subCount = (size_t)subWidth * (size_t)subHeight;
    uint32_t *subImage = (uint32_t *)malloc(subCount * sizeof(uint32_t));
    if (subImage == NULL)
    {
        free(argb);
        free(residuals);
        free(best);
        free(writer.data);
        return NULL;
    }
    for (size_t i = 0; i < subCount; i++)
        subImage[i] = 0xff000000u | ((uint32_t)bestMode << 8);

    TGWebPWriteBits(&writer, 1, 1);
    TGWebPWriteBits(&writer, 0, 2);
    TGWebPWriteBits(&writer, (uint32_t)sizeBits, 3);
    TGWebPWriteCodesAndPixels(&writer, subImage, subCount, subWidth, 0);
    free(subImage);

    TGWebPWriteBits(&writer, 0, 1);
    TGWebPWriteCodesAndPixels(&writer, best, count, width, 1);
    TGWebPFlushBits(&writer);

    free(argb);
    free(residuals);
    free(best);

    if (writer.failed)
    {
        free(writer.data);
        return NULL;
    }

    size_t chunkSize = writer.size;
    size_t padding = chunkSize & 1;
    size_t total = 12 + 8 + chunkSize + padding;
    uint8_t *output = (uint8_t *)malloc(total);
    if (output == NULL)
    {
        free(writer.data);
        return NULL;
    }
    memcpy(output, "RIFF", 4);
    TGWebPWriteLE32(output + 4, (uint32_t)(total - 8));
    memcpy(output + 8, "WEBP", 4);
    memcpy(output + 12, "VP8L", 4);
    TGWebPWriteLE32(output + 16, (uint32_t)chunkSize);
    memcpy(output + 20, writer.data, chunkSize);
    if (padding)
        output[20 + chunkSize] = 0;
    free(writer.data);
    if (outSize != NULL)
        *outSize = total;
    return output;
}

uint8_t *TGWebPEncodeRGBAWithSizeLimit(const uint8_t *rgba, int width, int height, int stride, size_t maxSize, size_t *outSize)
{
    if (outSize != NULL)
        *outSize = 0;
    if (rgba == NULL || width <= 0 || height <= 0 || stride < width * 4)
        return NULL;

    size_t size = 0;
    uint8_t *result = TGWebPEncodeLosslessRGBA(rgba, width, height, stride, &size);
    if (result == NULL || maxSize == 0 || size <= maxSize)
    {
        if (outSize != NULL && result != NULL)
            *outSize = size;
        return result;
    }

    size_t rowBytes = (size_t)width * 4;
    uint8_t *quantized = (uint8_t *)malloc(rowBytes * (size_t)height);
    if (quantized == NULL)
    {
        free(result);
        return NULL;
    }
    for (int bits = 1; bits <= 5 && size > maxSize; bits++)
    {
        uint8_t mask = (uint8_t)(0xff << bits);
        uint8_t half = (uint8_t)(1 << (bits - 1));
        for (int y = 0; y < height; y++)
        {
            const uint8_t *source = rgba + (size_t)y * (size_t)stride;
            uint8_t *target = quantized + (size_t)y * rowBytes;
            for (size_t x = 0; x < rowBytes; x++)
            {
                int value = source[x];
                if ((x & 3) == 3 && (value == 0 || value == 255))
                {
                    target[x] = (uint8_t)value;
                    continue;
                }
                value += half;
                if (value > 255)
                    value = 255;
                target[x] = (uint8_t)(value & mask);
            }
        }
        size_t candidateSize = 0;
        uint8_t *candidate = TGWebPEncodeLosslessRGBA(quantized, width, height, (int)rowBytes, &candidateSize);
        if (candidate == NULL)
            break;
        free(result);
        result = candidate;
        size = candidateSize;
    }
    free(quantized);
    if (outSize != NULL)
        *outSize = size;
    return result;
}
