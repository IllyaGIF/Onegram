#include "OGWebM.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>

enum
{
    OGEBML = 0x1a45dfa3,
    OGSegment = 0x18538067,
    OGInfo = 0x1549a966,
    OGTracks = 0x1654ae6b,
    OGCluster = 0x1f43b675,
    OGTimecodeScale = 0x2ad7b1,
    OGDuration = 0x4489,
    OGTrackEntry = 0xae,
    OGTrackNumber = 0xd7,
    OGTrackType = 0x83,
    OGCodecID = 0x86,
    OGVideo = 0xe0,
    OGPixelWidth = 0xb0,
    OGPixelHeight = 0xba,
    OGAlphaMode = 0x53c0,
    OGTimecode = 0xe7,
    OGSimpleBlock = 0xa3,
    OGBlockGroup = 0xa0,
    OGBlock = 0xa1,
    OGBlockAdditions = 0x75a1,
    OGBlockMore = 0xa6,
    OGBlockAddID = 0xee,
    OGBlockAdditional = 0xa5
};

typedef struct
{
    uint64_t id;
    size_t start;
    size_t end;
    int unknown;
} OGElement;

typedef struct
{
    const uint8_t *data;
    size_t length;
    uint64_t scale;
    uint64_t track;
    uint64_t durationNs;
    OGWebM *webm;
} OGParser;

static int OGReadVint(const uint8_t *data, size_t end, size_t *cursor, int identifier, uint64_t *value, int *unknown)
{
    if (*cursor >= end)
        return 0;
    uint8_t first = data[*cursor];
    if (first == 0)
        return 0;
    unsigned int bytes = 1;
    uint8_t marker = 0x80;
    while ((first & marker) == 0)
    {
        marker >>= 1;
        bytes++;
    }
    if (bytes > (identifier ? 4U : 8U) || bytes > end - *cursor)
        return 0;
    uint64_t number = identifier ? first : (first & (marker - 1));
    for (unsigned int i = 1; i < bytes; i++)
        number = (number << 8) | data[*cursor + i];
    *cursor += bytes;
    *value = number;
    if (unknown != NULL)
        *unknown = !identifier && number == ((UINT64_C(1) << (7 * bytes)) - 1);
    return 1;
}

static int OGNext(const uint8_t *data, size_t end, size_t *cursor, OGElement *element)
{
    uint64_t size = 0;
    if (!OGReadVint(data, end, cursor, 1, &element->id, NULL) || !OGReadVint(data, end, cursor, 0, &size, &element->unknown))
        return 0;
    element->start = *cursor;
    if (!element->unknown && size > end - *cursor)
        return 0;
    element->end = element->unknown ? end : *cursor + (size_t)size;
    return 1;
}

static int OGUnsigned(const OGParser *parser, OGElement element, uint64_t *value)
{
    size_t size = element.end - element.start;
    if (element.unknown || size == 0 || size > 8)
        return 0;
    uint64_t result = 0;
    for (size_t i = element.start; i < element.end; i++)
        result = (result << 8) | parser->data[i];
    *value = result;
    return 1;
}

static int OGFloat(const OGParser *parser, OGElement element, double *value)
{
    uint64_t bits = 0;
    size_t size = element.end - element.start;
    if (element.unknown || (size != 4 && size != 8))
        return 0;
    for (size_t i = element.start; i < element.end; i++)
        bits = (bits << 8) | parser->data[i];
    if (size == 4)
    {
        uint32_t raw = (uint32_t)bits;
        float number;
        memcpy(&number, &raw, sizeof(number));
        *value = number;
    }
    else
        memcpy(value, &bits, sizeof(bits));
    return isfinite(*value) && *value >= 0 && *value <= 30 * 1000000000.0;
}

static int OGInfoParse(OGParser *parser, OGElement parent)
{
    size_t cursor = parent.start;
    double duration = 0;
    while (cursor < parent.end)
    {
        OGElement item;
        if (!OGNext(parser->data, parent.end, &cursor, &item) || item.unknown)
            return 0;
        if (item.id == OGTimecodeScale && (!OGUnsigned(parser, item, &parser->scale) || parser->scale == 0 || parser->scale > 1000000000))
            return 0;
        if (item.id == OGDuration && !OGFloat(parser, item, &duration))
            return 0;
        cursor = item.end;
    }
    if (duration > 0)
        parser->durationNs = (uint64_t)(duration * (double)parser->scale);
    return 1;
}

static int OGVideoParse(OGParser *parser, OGElement parent, OGWebM *track)
{
    size_t cursor = parent.start;
    while (cursor < parent.end)
    {
        OGElement item;
        uint64_t number = 0;
        if (!OGNext(parser->data, parent.end, &cursor, &item) || item.unknown)
            return 0;
        if (item.id == OGPixelWidth || item.id == OGPixelHeight || item.id == OGAlphaMode)
        {
            if (!OGUnsigned(parser, item, &number) || number > 4096)
                return 0;
            if (item.id == OGPixelWidth)
                track->width = (uint32_t)number;
            else if (item.id == OGPixelHeight)
                track->height = (uint32_t)number;
            else
                track->alphaMode = (uint32_t)number;
        }
        cursor = item.end;
    }
    return 1;
}

static int OGTracksParse(OGParser *parser, OGElement parent)
{
    size_t cursor = parent.start;
    while (cursor < parent.end)
    {
        OGElement entry;
        if (!OGNext(parser->data, parent.end, &cursor, &entry) || entry.unknown)
            return 0;
        if (entry.id == OGTrackEntry)
        {
            OGWebM track = {0};
            uint64_t number = 0;
            uint64_t type = 0;
            int vp9 = 0;
            size_t inner = entry.start;
            while (inner < entry.end)
            {
                OGElement item;
                if (!OGNext(parser->data, entry.end, &inner, &item) || item.unknown)
                    return 0;
                if (item.id == OGTrackNumber && !OGUnsigned(parser, item, &number))
                    return 0;
                if (item.id == OGTrackType && !OGUnsigned(parser, item, &type))
                    return 0;
                if (item.id == OGCodecID)
                    vp9 = item.end - item.start == 5 && memcmp(parser->data + item.start, "V_VP9", 5) == 0;
                if (item.id == OGVideo && !OGVideoParse(parser, item, &track))
                    return 0;
                inner = item.end;
            }
            if (type == 1 && vp9 && number != 0 && track.width > 0 && track.height > 0 && track.width <= 1024 && track.height <= 1024 && parser->track == 0)
            {
                parser->track = number;
                parser->webm->width = track.width;
                parser->webm->height = track.height;
                parser->webm->alphaMode = track.alphaMode;
            }
        }
        cursor = entry.end;
    }
    return 1;
}

static int OGAppendFrame(OGParser *parser, OGElement block, OGElement additional, uint64_t clusterTimecode)
{
    size_t cursor = block.start;
    uint64_t track = 0;
    if (!OGReadVint(parser->data, block.end, &cursor, 0, &track, NULL) || block.end - cursor < 3)
        return 0;
    int16_t offset = (int16_t)(((uint16_t)parser->data[cursor] << 8) | parser->data[cursor + 1]);
    unsigned int flags = parser->data[cursor + 2];
    cursor += 3;
    if (track != parser->track)
        return 1;
    if ((flags & 0x06) != 0 || block.end - cursor == 0 || block.end - cursor > 4 * 1024 * 1024 || parser->webm->frameCount >= 1200)
        return 0;
    if (additional.end - additional.start > 4 * 1024 * 1024)
        return 0;
    if (offset < 0 && (uint64_t)(-(int64_t)offset) > clusterTimecode)
        return 0;
    uint64_t ticks = offset < 0 ? clusterTimecode - (uint64_t)(-(int64_t)offset) : clusterTimecode + (uint64_t)offset;
    if (ticks > UINT64_C(30000000000) / parser->scale)
        return 0;
    OGWebMFrame *frames = parser->webm->frames;
    uint32_t count = parser->webm->frameCount;
    if (count != 0 && ticks * parser->scale < frames[count - 1].timestampNs)
        return 0;
    if (count % 64 == 0)
    {
        OGWebMFrame *grown = realloc(frames, (count + 64) * sizeof(*grown));
        if (grown == NULL)
            return 0;
        parser->webm->frames = frames = grown;
    }
    OGWebMFrame *frame = &frames[count];
    frame->offset = cursor;
    frame->length = block.end - cursor;
    frame->alphaOffset = additional.start;
    frame->alphaLength = additional.end - additional.start;
    frame->timestampNs = ticks * parser->scale;
    parser->webm->frameCount++;
    if (frame->alphaLength)
        parser->webm->alphaMode = 1;
    return 1;
}

static int OGAdditionsParse(OGParser *parser, OGElement parent, OGElement *additional)
{
    size_t cursor = parent.start;
    while (cursor < parent.end)
    {
        OGElement more;
        if (!OGNext(parser->data, parent.end, &cursor, &more) || more.unknown)
            return 0;
        if (more.id == OGBlockMore)
        {
            uint64_t id = 1;
            OGElement payload = {0};
            size_t inner = more.start;
            while (inner < more.end)
            {
                OGElement item;
                if (!OGNext(parser->data, more.end, &inner, &item) || item.unknown)
                    return 0;
                if (item.id == OGBlockAddID && !OGUnsigned(parser, item, &id))
                    return 0;
                if (item.id == OGBlockAdditional)
                    payload = item;
                inner = item.end;
            }
            if (id == 1 && payload.end > payload.start)
                *additional = payload;
        }
        cursor = more.end;
    }
    return 1;
}

static int OGBlockGroupParse(OGParser *parser, OGElement group, uint64_t timecode)
{
    size_t cursor = group.start;
    OGElement block = {0};
    OGElement additional = {0};
    while (cursor < group.end)
    {
        OGElement item;
        if (!OGNext(parser->data, group.end, &cursor, &item) || item.unknown)
            return 0;
        if (item.id == OGBlock)
            block = item;
        if (item.id == OGBlockAdditions && !OGAdditionsParse(parser, item, &additional))
            return 0;
        cursor = item.end;
    }
    return block.end > block.start ? OGAppendFrame(parser, block, additional, timecode) : 1;
}

static int OGClusterParse(OGParser *parser, OGElement cluster, size_t *next)
{
    size_t cursor = cluster.start;
    uint64_t timecode = 0;
    while (cursor < cluster.end)
    {
        size_t itemStart = cursor;
        OGElement item;
        if (!OGNext(parser->data, cluster.end, &cursor, &item))
            return 0;
        if (cluster.unknown && (item.id == OGCluster || item.id == OGInfo || item.id == OGTracks || item.id == 0x1c53bb6b || item.id == 0x114d9b74))
        {
            *next = itemStart;
            return 1;
        }
        if (item.unknown)
            return 0;
        if (item.id == OGTimecode && !OGUnsigned(parser, item, &timecode))
            return 0;
        if (item.id == OGSimpleBlock && !OGAppendFrame(parser, item, (OGElement){0}, timecode))
            return 0;
        if (item.id == OGBlockGroup && !OGBlockGroupParse(parser, item, timecode))
            return 0;
        cursor = item.end;
    }
    *next = cursor;
    return 1;
}

static int OGSegmentParse(OGParser *parser, OGElement segment)
{
    size_t cursor = segment.start;
    while (cursor < segment.end)
    {
        OGElement item;
        if (!OGNext(parser->data, segment.end, &cursor, &item))
            return 0;
        if (item.unknown && item.id != OGCluster)
            return 0;
        if (item.id == OGInfo && !OGInfoParse(parser, item))
            return 0;
        if (item.id == OGTracks && !OGTracksParse(parser, item))
            return 0;
        if (item.id == OGCluster && !OGClusterParse(parser, item, &cursor))
            return 0;
        if (item.id != OGCluster)
            cursor = item.end;
    }
    return 1;
}

int OGWebMParse(const uint8_t *data, size_t length, OGWebM *result)
{
    if (result == NULL)
        return 0;
    memset(result, 0, sizeof(*result));
    if (data == NULL || length < 16 || length > 48 * 1024 * 1024)
        return 0;
    OGParser parser = {0};
    parser.data = data;
    parser.length = length;
    parser.scale = 1000000;
    parser.webm = result;
    size_t cursor = 0;
    OGElement header;
    if (!OGNext(data, length, &cursor, &header) || header.id != OGEBML || header.unknown)
        return 0;
    cursor = header.end;
    int found = 0;
    while (cursor < length)
    {
        OGElement item;
        if (!OGNext(data, length, &cursor, &item))
            break;
        if (item.id == OGSegment)
        {
            found = OGSegmentParse(&parser, item);
            break;
        }
        if (item.unknown)
            break;
        cursor = item.end;
    }
    if (!found || parser.track == 0 || result->frameCount == 0)
    {
        OGWebMFree(result);
        return 0;
    }
    uint64_t last = result->frames[result->frameCount - 1].timestampNs;
    uint64_t finalFrameDuration = UINT64_C(33333334);
    if (result->frameCount > 1)
    {
        uint64_t interval = last - result->frames[result->frameCount - 2].timestampNs;
        if (interval > 0 && interval <= UINT64_C(1000000000))
            finalFrameDuration = interval;
    }
    uint64_t ending = last + finalFrameDuration;
    if (parser.durationNs > 0 && parser.durationNs >= last && parser.durationNs <= UINT64_C(30000000000))
        ending = parser.durationNs;
    if (ending == 0 || ending > UINT64_C(30000000000))
    {
        OGWebMFree(result);
        return 0;
    }
    result->durationNs = ending;
    return 1;
}

void OGWebMFree(OGWebM *webm)
{
    if (webm == NULL)
        return;
    free(webm->frames);
    memset(webm, 0, sizeof(*webm));
}
