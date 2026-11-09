#include "TGLottieInternal.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <limits.h>

struct TGLottieArenaChunk
{
    TGLottieArenaChunk *next;
    size_t capacity;
    size_t used;
};

void TGLottieArenaInit(TGLottieArena *arena, size_t chunkSize, size_t limit)
{
    arena->chunks = NULL;
    arena->chunkSize = chunkSize;
    arena->allocated = 0;
    arena->limit = limit;
}

void *TGLottieArenaAlloc(TGLottieArena *arena, size_t size)
{
    size = (size + 7) & ~(size_t)7;
    if (size == 0)
        size = 8;
    TGLottieArenaChunk *chunk = arena->chunks;
    if (chunk == NULL || chunk->capacity - chunk->used < size)
    {
        size_t capacity = size > arena->chunkSize ? size : arena->chunkSize;
        if (arena->limit != 0 && arena->allocated + capacity > arena->limit)
            return NULL;
        TGLottieArenaChunk *created = (TGLottieArenaChunk *)malloc(sizeof(TGLottieArenaChunk) + capacity);
        if (created == NULL)
            return NULL;
        created->capacity = capacity;
        created->used = 0;
        arena->allocated += capacity;
        if (chunk != NULL && size > arena->chunkSize)
        {
            created->next = chunk->next;
            chunk->next = created;
        }
        else
        {
            created->next = chunk;
            arena->chunks = created;
        }
        chunk = created;
    }
    void *result = (uint8_t *)(chunk + 1) + chunk->used;
    chunk->used += size;
    return result;
}

void *TGLottieArenaAllocZeroed(TGLottieArena *arena, size_t size)
{
    void *result = TGLottieArenaAlloc(arena, size);
    if (result != NULL)
        memset(result, 0, size);
    return result;
}

void TGLottieArenaReset(TGLottieArena *arena)
{
    TGLottieArenaChunk *chunk = arena->chunks;
    if (chunk == NULL)
        return;
    TGLottieArenaChunk *next = chunk->next;
    while (next != NULL)
    {
        TGLottieArenaChunk *following = next->next;
        free(next);
        next = following;
    }
    chunk->next = NULL;
    chunk->used = 0;
    arena->allocated = chunk->capacity;
}

void TGLottieArenaDestroy(TGLottieArena *arena)
{
    TGLottieArenaChunk *chunk = arena->chunks;
    while (chunk != NULL)
    {
        TGLottieArenaChunk *next = chunk->next;
        free(chunk);
        chunk = next;
    }
    arena->chunks = NULL;
    arena->allocated = 0;
}

typedef struct
{
    TGLottieArena *arena;
    const char *cursor;
    const char *end;
    int depth;
    int failed;
} TGLottieJSONParser;

static const int TGLottieJSONMaxDepth = 96;

static void TGLottieJSONSkipWhitespace(TGLottieJSONParser *parser)
{
    while (parser->cursor < parser->end)
    {
        char c = *parser->cursor;
        if (c != ' ' && c != '\n' && c != '\r' && c != '\t')
            break;
        parser->cursor++;
    }
}

static TGLottieJSON *TGLottieJSONAllocValue(TGLottieJSONParser *parser, TGLottieJSONType type)
{
    TGLottieJSON *value = (TGLottieJSON *)TGLottieArenaAllocZeroed(parser->arena, sizeof(TGLottieJSON));
    if (value == NULL)
    {
        parser->failed = 1;
        return NULL;
    }
    value->type = type;
    return value;
}

static void TGLottieJSONAppendUTF8(char *buffer, size_t *length, uint32_t codepoint)
{
    if (codepoint < 0x80)
        buffer[(*length)++] = (char)codepoint;
    else if (codepoint < 0x800)
    {
        buffer[(*length)++] = (char)(0xc0 | (codepoint >> 6));
        buffer[(*length)++] = (char)(0x80 | (codepoint & 0x3f));
    }
    else if (codepoint < 0x10000)
    {
        buffer[(*length)++] = (char)(0xe0 | (codepoint >> 12));
        buffer[(*length)++] = (char)(0x80 | ((codepoint >> 6) & 0x3f));
        buffer[(*length)++] = (char)(0x80 | (codepoint & 0x3f));
    }
    else
    {
        buffer[(*length)++] = (char)(0xf0 | (codepoint >> 18));
        buffer[(*length)++] = (char)(0x80 | ((codepoint >> 12) & 0x3f));
        buffer[(*length)++] = (char)(0x80 | ((codepoint >> 6) & 0x3f));
        buffer[(*length)++] = (char)(0x80 | (codepoint & 0x3f));
    }
}

static int TGLottieJSONHexValue(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

static const char *TGLottieJSONParseString(TGLottieJSONParser *parser)
{
    parser->cursor++;
    const char *start = parser->cursor;
    int hasEscapes = 0;
    while (parser->cursor < parser->end && *parser->cursor != '"')
    {
        if (*parser->cursor == '\\')
        {
            hasEscapes = 1;
            parser->cursor++;
        }
        parser->cursor++;
    }
    if (parser->cursor >= parser->end)
    {
        parser->failed = 1;
        return NULL;
    }
    size_t rawLength = (size_t)(parser->cursor - start);
    parser->cursor++;
    char *buffer = (char *)TGLottieArenaAlloc(parser->arena, rawLength + 1);
    if (buffer == NULL)
    {
        parser->failed = 1;
        return NULL;
    }
    if (!hasEscapes)
    {
        memcpy(buffer, start, rawLength);
        buffer[rawLength] = 0;
        return buffer;
    }
    size_t length = 0;
    for (size_t index = 0; index < rawLength; index++)
    {
        char c = start[index];
        if (c != '\\' || index + 1 >= rawLength)
        {
            buffer[length++] = c;
            continue;
        }
        char escaped = start[++index];
        switch (escaped)
        {
            case 'n': buffer[length++] = '\n'; break;
            case 't': buffer[length++] = '\t'; break;
            case 'r': buffer[length++] = '\r'; break;
            case 'b': buffer[length++] = '\b'; break;
            case 'f': buffer[length++] = '\f'; break;
            case 'u':
            {
                uint32_t codepoint = 0;
                int valid = index + 4 < rawLength;
                for (int digit = 0; valid && digit < 4; digit++)
                {
                    int hex = TGLottieJSONHexValue(start[index + 1 + digit]);
                    if (hex < 0)
                        valid = 0;
                    else
                        codepoint = (codepoint << 4) | (uint32_t)hex;
                }
                if (!valid)
                    break;
                index += 4;
                if (length + 4 <= rawLength)
                    TGLottieJSONAppendUTF8(buffer, &length, codepoint);
                break;
            }
            default:
                buffer[length++] = escaped;
                break;
        }
    }
    buffer[length] = 0;
    return buffer;
}

static TGLottieJSON *TGLottieJSONParseValue(TGLottieJSONParser *parser);

static TGLottieJSON *TGLottieJSONParseContainer(TGLottieJSONParser *parser, int object)
{
    if (++parser->depth > TGLottieJSONMaxDepth)
    {
        parser->failed = 1;
        return NULL;
    }
    TGLottieJSON *value = TGLottieJSONAllocValue(parser, object ? TGLottieJSONObject : TGLottieJSONArray);
    if (value == NULL)
        return NULL;
    parser->cursor++;
    char closing = object ? '}' : ']';
    int capacity = 0;
    TGLottieJSON **items = NULL;
    const char **keys = NULL;
    TGLottieJSONSkipWhitespace(parser);
    if (parser->cursor < parser->end && *parser->cursor == closing)
    {
        parser->cursor++;
        parser->depth--;
        return value;
    }
    while (!parser->failed)
    {
        TGLottieJSONSkipWhitespace(parser);
        const char *key = NULL;
        if (object)
        {
            if (parser->cursor >= parser->end || *parser->cursor != '"')
            {
                parser->failed = 1;
                break;
            }
            key = TGLottieJSONParseString(parser);
            TGLottieJSONSkipWhitespace(parser);
            if (parser->failed || parser->cursor >= parser->end || *parser->cursor != ':')
            {
                parser->failed = 1;
                break;
            }
            parser->cursor++;
        }
        TGLottieJSON *item = TGLottieJSONParseValue(parser);
        if (parser->failed)
            break;
        if (value->count == capacity)
        {
            int newCapacity = capacity == 0 ? 4 : capacity * 2;
            TGLottieJSON **newItems = (TGLottieJSON **)TGLottieArenaAlloc(parser->arena, sizeof(TGLottieJSON *) * (size_t)newCapacity);
            const char **newKeys = object ? (const char **)TGLottieArenaAlloc(parser->arena, sizeof(const char *) * (size_t)newCapacity) : NULL;
            if (newItems == NULL || (object && newKeys == NULL))
            {
                parser->failed = 1;
                break;
            }
            if (capacity != 0)
            {
                memcpy(newItems, items, sizeof(TGLottieJSON *) * (size_t)capacity);
                if (object)
                    memcpy(newKeys, keys, sizeof(const char *) * (size_t)capacity);
            }
            items = newItems;
            keys = newKeys;
            capacity = newCapacity;
        }
        items[value->count] = item;
        if (object)
            keys[value->count] = key;
        value->count++;
        TGLottieJSONSkipWhitespace(parser);
        if (parser->cursor >= parser->end)
        {
            parser->failed = 1;
            break;
        }
        if (*parser->cursor == ',')
        {
            parser->cursor++;
            continue;
        }
        if (*parser->cursor == closing)
        {
            parser->cursor++;
            break;
        }
        parser->failed = 1;
    }
    value->items = items;
    value->keys = keys;
    parser->depth--;
    return parser->failed ? NULL : value;
}

static int TGLottieJSONMatchLiteral(TGLottieJSONParser *parser, const char *literal)
{
    size_t length = strlen(literal);
    if ((size_t)(parser->end - parser->cursor) < length || memcmp(parser->cursor, literal, length) != 0)
        return 0;
    parser->cursor += length;
    return 1;
}

static TGLottieJSON *TGLottieJSONParseNumber(TGLottieJSONParser *parser)
{
    const char *start = parser->cursor;
    while (parser->cursor < parser->end)
    {
        char c = *parser->cursor;
        if ((c >= '0' && c <= '9') || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E')
            parser->cursor++;
        else
            break;
    }
    size_t length = (size_t)(parser->cursor - start);
    if (length == 0 || length > 63)
    {
        parser->failed = 1;
        return NULL;
    }
    char buffer[64];
    memcpy(buffer, start, length);
    buffer[length] = 0;
    char *end = NULL;
    double number = strtod(buffer, &end);
    if (end != buffer + length || !isfinite(number))
    {
        parser->failed = 1;
        return NULL;
    }
    TGLottieJSON *value = TGLottieJSONAllocValue(parser, TGLottieJSONNumber);
    if (value != NULL)
        value->number = number;
    return value;
}

static TGLottieJSON *TGLottieJSONParseValue(TGLottieJSONParser *parser)
{
    TGLottieJSONSkipWhitespace(parser);
    if (parser->cursor >= parser->end)
    {
        parser->failed = 1;
        return NULL;
    }
    char c = *parser->cursor;
    switch (c)
    {
        case '{':
            return TGLottieJSONParseContainer(parser, 1);
        case '[':
            return TGLottieJSONParseContainer(parser, 0);
        case '"':
        {
            TGLottieJSON *value = TGLottieJSONAllocValue(parser, TGLottieJSONString);
            if (value != NULL)
                value->string = TGLottieJSONParseString(parser);
            return parser->failed ? NULL : value;
        }
        case 't':
        case 'f':
        {
            TGLottieJSON *value = TGLottieJSONAllocValue(parser, TGLottieJSONBool);
            if (value == NULL)
                return NULL;
            if (TGLottieJSONMatchLiteral(parser, "true"))
                value->number = 1.0;
            else if (TGLottieJSONMatchLiteral(parser, "false"))
                value->number = 0.0;
            else
                parser->failed = 1;
            return parser->failed ? NULL : value;
        }
        case 'n':
            if (!TGLottieJSONMatchLiteral(parser, "null"))
            {
                parser->failed = 1;
                return NULL;
            }
            return TGLottieJSONAllocValue(parser, TGLottieJSONNull);
        default:
            return TGLottieJSONParseNumber(parser);
    }
}

TGLottieJSON *TGLottieJSONParse(TGLottieArena *arena, const char *text, size_t length)
{
    TGLottieJSONParser parser;
    parser.arena = arena;
    parser.cursor = text;
    parser.end = text + length;
    parser.depth = 0;
    parser.failed = 0;
    TGLottieJSON *value = TGLottieJSONParseValue(&parser);
    return parser.failed ? NULL : value;
}

const TGLottieJSON *TGLottieJSONMember(const TGLottieJSON *object, const char *key)
{
    if (object == NULL || object->type != TGLottieJSONObject)
        return NULL;
    for (int index = 0; index < object->count; index++)
    {
        if (object->keys[index] != NULL && strcmp(object->keys[index], key) == 0)
            return object->items[index];
    }
    return NULL;
}

double TGLottieJSONNumberValue(const TGLottieJSON *value, double fallback)
{
    if (value == NULL)
        return fallback;
    if (value->type == TGLottieJSONNumber || value->type == TGLottieJSONBool)
        return value->number;
    if (value->type == TGLottieJSONArray && value->count != 0)
        return TGLottieJSONNumberValue(value->items[0], fallback);
    return fallback;
}

int TGLottieJSONIntMember(const TGLottieJSON *object, const char *key, int fallback)
{
    double value = TGLottieJSONNumberValue(TGLottieJSONMember(object, key), fallback);
    if (!isfinite(value) || value < INT_MIN || value > INT_MAX)
        return fallback;
    return (int)value;
}

double TGLottieJSONNumberMember(const TGLottieJSON *object, const char *key, double fallback)
{
    return TGLottieJSONNumberValue(TGLottieJSONMember(object, key), fallback);
}

const char *TGLottieJSONStringMember(const TGLottieJSON *object, const char *key)
{
    const TGLottieJSON *value = TGLottieJSONMember(object, key);
    return value != NULL && value->type == TGLottieJSONString ? value->string : NULL;
}

int TGLottieJSONBoolMember(const TGLottieJSON *object, const char *key, int fallback)
{
    const TGLottieJSON *value = TGLottieJSONMember(object, key);
    if (value == NULL)
        return fallback;
    return value->number != 0.0;
}

TGLottieAffine TGLottieAffineIdentity(void)
{
    TGLottieAffine matrix = { 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f };
    return matrix;
}

TGLottieAffine TGLottieAffineMultiply(TGLottieAffine left, TGLottieAffine right)
{
    TGLottieAffine result;
    result.a = left.a * right.a + left.c * right.b;
    result.b = left.b * right.a + left.d * right.b;
    result.c = left.a * right.c + left.c * right.d;
    result.d = left.b * right.c + left.d * right.d;
    result.tx = left.a * right.tx + left.c * right.ty + left.tx;
    result.ty = left.b * right.tx + left.d * right.ty + left.ty;
    return result;
}

int TGLottieAffineInvert(TGLottieAffine matrix, TGLottieAffine *result)
{
    float determinant = matrix.a * matrix.d - matrix.b * matrix.c;
    if (fabsf(determinant) < 1e-12f)
        return 0;
    float inverse = 1.0f / determinant;
    result->a = matrix.d * inverse;
    result->b = -matrix.b * inverse;
    result->c = -matrix.c * inverse;
    result->d = matrix.a * inverse;
    result->tx = (matrix.c * matrix.ty - matrix.d * matrix.tx) * inverse;
    result->ty = (matrix.b * matrix.tx - matrix.a * matrix.ty) * inverse;
    return 1;
}

void TGLottieAffineApply(const TGLottieAffine *matrix, float x, float y, float *outX, float *outY)
{
    *outX = matrix->a * x + matrix->c * y + matrix->tx;
    *outY = matrix->b * x + matrix->d * y + matrix->ty;
}
