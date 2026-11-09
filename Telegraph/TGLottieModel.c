#include "TGLottieInternal.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <zlib.h>

static const size_t TGLottieMaxUncompressedSize = 8 * 1024 * 1024;
static const size_t TGLottieJSONArenaLimit = 48 * 1024 * 1024;
static const size_t TGLottieModelArenaLimit = 24 * 1024 * 1024;
static const int TGLottieMaxShapeDepth = 32;
static const int TGLottieSpatialSampleCount = 24;

typedef struct
{
    TGLottieArena *arena;
    int failed;
} TGLottieModelBuilder;

static void *TGLottieBuilderAlloc(TGLottieModelBuilder *builder, size_t size)
{
    void *result = TGLottieArenaAllocZeroed(builder->arena, size);
    if (result == NULL)
        builder->failed = 1;
    return result;
}

static float *TGLottieBuilderFloats(TGLottieModelBuilder *builder, int count)
{
    return (float *)TGLottieBuilderAlloc(builder, sizeof(float) * (size_t)(count > 0 ? count : 1));
}

static const char *TGLottieBuilderString(TGLottieModelBuilder *builder, const char *string)
{
    if (string == NULL)
        return NULL;
    size_t length = strlen(string);
    char *copy = (char *)TGLottieBuilderAlloc(builder, length + 1);
    if (copy != NULL)
        memcpy(copy, string, length + 1);
    return copy;
}

static int TGLottieJSONIsKeyframeArray(const TGLottieJSON *value)
{
    return value != NULL && value->type == TGLottieJSONArray && value->count != 0 && value->items[0]->type == TGLottieJSONObject && TGLottieJSONMember(value->items[0], "t") != NULL;
}

static int TGLottieJSONReadNumbers(const TGLottieJSON *value, float *output, int capacity)
{
    if (value == NULL)
        return 0;
    if (value->type == TGLottieJSONNumber)
    {
        if (capacity > 0)
            output[0] = (float)value->number;
        return 1;
    }
    if (value->type != TGLottieJSONArray)
        return 0;
    int count = 0;
    for (int index = 0; index < value->count && count < capacity; index++)
    {
        if (value->items[index]->type == TGLottieJSONNumber)
            output[count++] = (float)value->items[index]->number;
    }
    return count;
}

static int TGLottieJSONNumberCount(const TGLottieJSON *value)
{
    if (value == NULL)
        return 0;
    if (value->type == TGLottieJSONNumber)
        return 1;
    if (value->type != TGLottieJSONArray)
        return 0;
    int count = 0;
    for (int index = 0; index < value->count; index++)
    {
        if (value->items[index]->type == TGLottieJSONNumber)
            count++;
    }
    return count;
}

static int TGLottieReadEasing(const TGLottieJSON *easing, float *x, float *y, float defaultX, float defaultY)
{
    for (int index = 0; index < 4; index++)
    {
        x[index] = defaultX;
        y[index] = defaultY;
    }
    if (easing == NULL)
        return 1;
    float xValues[4];
    float yValues[4];
    int xCount = TGLottieJSONReadNumbers(TGLottieJSONMember(easing, "x"), xValues, 4);
    int yCount = TGLottieJSONReadNumbers(TGLottieJSONMember(easing, "y"), yValues, 4);
    int count = xCount > yCount ? xCount : yCount;
    if (count == 0)
        return 1;
    for (int index = 0; index < 4; index++)
    {
        x[index] = xCount == 0 ? defaultX : xValues[index < xCount ? index : xCount - 1];
        y[index] = yCount == 0 ? defaultY : yValues[index < yCount ? index : yCount - 1];
    }
    return count;
}

static void TGLottieCubicPoint(const float *p0, const float *c0, const float *c1, const float *p1, float t, float *output)
{
    float u = 1.0f - t;
    float a = u * u * u;
    float b = 3.0f * u * u * t;
    float c = 3.0f * u * t * t;
    float d = t * t * t;
    output[0] = a * p0[0] + b * c0[0] + c * c1[0] + d * p1[0];
    output[1] = a * p0[1] + b * c0[1] + c * c1[1] + d * p1[1];
}

static void TGLottieBuildSpatialTable(TGLottieModelBuilder *builder, TGLottieKeyframe *keyframe)
{
    float c0[2] = { keyframe->start[0] + keyframe->spatialOut[0], keyframe->start[1] + keyframe->spatialOut[1] };
    float c1[2] = { keyframe->end[0] + keyframe->spatialIn[0], keyframe->end[1] + keyframe->spatialIn[1] };
    keyframe->arcLengths = TGLottieBuilderFloats(builder, TGLottieSpatialSampleCount + 1);
    if (keyframe->arcLengths == NULL)
        return;
    float previous[2] = { keyframe->start[0], keyframe->start[1] };
    float length = 0.0f;
    keyframe->arcLengths[0] = 0.0f;
    for (int index = 1; index <= TGLottieSpatialSampleCount; index++)
    {
        float point[2];
        TGLottieCubicPoint(keyframe->start, c0, c1, keyframe->end, (float)index / (float)TGLottieSpatialSampleCount, point);
        float dx = point[0] - previous[0];
        float dy = point[1] - previous[1];
        length += sqrtf(dx * dx + dy * dy);
        keyframe->arcLengths[index] = length;
        previous[0] = point[0];
        previous[1] = point[1];
    }
}

static void TGLottieParseProperty(TGLottieModelBuilder *builder, const TGLottieJSON *json, int defaultDimension, const float *defaults, TGLottieProperty *property)
{
    memset(property, 0, sizeof(TGLottieProperty));
    const TGLottieJSON *k = json != NULL && json->type == TGLottieJSONObject ? TGLottieJSONMember(json, "k") : json;
    if (TGLottieJSONIsKeyframeArray(k))
    {
        int dimension = 0;
        for (int index = 0; index < k->count && dimension == 0; index++)
        {
            dimension = TGLottieJSONNumberCount(TGLottieJSONMember(k->items[index], "s"));
        }
        if (dimension == 0)
            dimension = defaultDimension;
        property->dimension = dimension;
        property->value = TGLottieBuilderFloats(builder, dimension);
        property->keyframes = (TGLottieKeyframe *)TGLottieBuilderAlloc(builder, sizeof(TGLottieKeyframe) * (size_t)k->count);
        if (builder->failed)
            return;
        float *previousEnd = NULL;
        for (int index = 0; index < dimension && defaults != NULL; index++)
            property->value[index] = defaults[index < defaultDimension ? index : defaultDimension - 1];
        for (int index = 0; index < k->count; index++)
        {
            const TGLottieJSON *item = k->items[index];
            TGLottieKeyframe *keyframe = &property->keyframes[index];
            keyframe->t = (float)TGLottieJSONNumberMember(item, "t", 0.0);
            keyframe->start = TGLottieBuilderFloats(builder, dimension);
            keyframe->end = TGLottieBuilderFloats(builder, dimension);
            if (builder->failed)
                return;
            const TGLottieJSON *startJSON = TGLottieJSONMember(item, "s");
            if (TGLottieJSONReadNumbers(startJSON, keyframe->start, dimension) == 0)
            {
                if (previousEnd != NULL)
                    memcpy(keyframe->start, previousEnd, sizeof(float) * (size_t)dimension);
                else
                    memcpy(keyframe->start, property->value, sizeof(float) * (size_t)dimension);
            }
            const TGLottieJSON *endJSON = TGLottieJSONMember(item, "e");
            const TGLottieJSON *nextStartJSON = index + 1 < k->count ? TGLottieJSONMember(k->items[index + 1], "s") : NULL;
            if (TGLottieJSONReadNumbers(endJSON, keyframe->end, dimension) == 0 && TGLottieJSONReadNumbers(nextStartJSON, keyframe->end, dimension) == 0)
                memcpy(keyframe->end, keyframe->start, sizeof(float) * (size_t)dimension);
            previousEnd = keyframe->end;
            keyframe->hold = TGLottieJSONIntMember(item, "h", 0) == 1;
            int outCount = TGLottieReadEasing(TGLottieJSONMember(item, "o"), keyframe->outX, keyframe->outY, 0.0f, 0.0f);
            int inCount = TGLottieReadEasing(TGLottieJSONMember(item, "i"), keyframe->inX, keyframe->inY, 1.0f, 1.0f);
            keyframe->easingCount = outCount > inCount ? outCount : inCount;
            float spatialOut[2] = { 0.0f, 0.0f };
            float spatialIn[2] = { 0.0f, 0.0f };
            int hasOut = TGLottieJSONReadNumbers(TGLottieJSONMember(item, "to"), spatialOut, 2) >= 2;
            int hasIn = TGLottieJSONReadNumbers(TGLottieJSONMember(item, "ti"), spatialIn, 2) >= 2;
            if (dimension >= 2 && hasOut && hasIn && (spatialOut[0] != 0.0f || spatialOut[1] != 0.0f || spatialIn[0] != 0.0f || spatialIn[1] != 0.0f))
            {
                keyframe->spatial = 1;
                keyframe->spatialOut[0] = spatialOut[0];
                keyframe->spatialOut[1] = spatialOut[1];
                keyframe->spatialIn[0] = spatialIn[0];
                keyframe->spatialIn[1] = spatialIn[1];
                TGLottieBuildSpatialTable(builder, keyframe);
            }
        }
        property->keyframeCount = k->count;
        memcpy(property->value, property->keyframes[0].start, sizeof(float) * (size_t)dimension);
        return;
    }
    int count = TGLottieJSONNumberCount(k);
    int dimension = count > 0 ? count : defaultDimension;
    property->dimension = dimension;
    property->value = TGLottieBuilderFloats(builder, dimension);
    if (builder->failed)
        return;
    if (count > 0)
        TGLottieJSONReadNumbers(k, property->value, dimension);
    else
    {
        for (int index = 0; index < dimension && defaults != NULL; index++)
            property->value[index] = defaults[index < defaultDimension ? index : defaultDimension - 1];
    }
}

static void TGLottieParsePropertyScalar(TGLottieModelBuilder *builder, const TGLottieJSON *json, float defaultValue, TGLottieProperty *property)
{
    TGLottieParseProperty(builder, json, 1, &defaultValue, property);
}

static int TGLottieParseBezier(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieBezier *bezier)
{
    memset(bezier, 0, sizeof(TGLottieBezier));
    if (json != NULL && json->type == TGLottieJSONArray && json->count != 0)
        json = json->items[0];
    if (json == NULL || json->type != TGLottieJSONObject)
        return 0;
    const TGLottieJSON *vertices = TGLottieJSONMember(json, "v");
    const TGLottieJSON *inTangents = TGLottieJSONMember(json, "i");
    const TGLottieJSON *outTangents = TGLottieJSONMember(json, "o");
    if (vertices == NULL || vertices->type != TGLottieJSONArray)
        return 0;
    int count = vertices->count;
    bezier->count = count;
    bezier->closed = TGLottieJSONBoolMember(json, "c", 0);
    bezier->points = TGLottieBuilderFloats(builder, count * 6);
    if (builder->failed)
        return 0;
    for (int index = 0; index < count; index++)
    {
        float *point = bezier->points + index * 6;
        TGLottieJSONReadNumbers(vertices->items[index], point, 2);
        if (inTangents != NULL && inTangents->type == TGLottieJSONArray && index < inTangents->count)
            TGLottieJSONReadNumbers(inTangents->items[index], point + 2, 2);
        if (outTangents != NULL && outTangents->type == TGLottieJSONArray && index < outTangents->count)
            TGLottieJSONReadNumbers(outTangents->items[index], point + 4, 2);
    }
    return 1;
}

static void TGLottieParsePathProperty(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottiePathProperty *property)
{
    memset(property, 0, sizeof(TGLottiePathProperty));
    const TGLottieJSON *k = json != NULL && json->type == TGLottieJSONObject ? TGLottieJSONMember(json, "k") : NULL;
    if (TGLottieJSONIsKeyframeArray(k))
    {
        property->keyframes = (TGLottiePathKeyframe *)TGLottieBuilderAlloc(builder, sizeof(TGLottiePathKeyframe) * (size_t)k->count);
        if (builder->failed)
            return;
        TGLottieBezier *previousEnd = NULL;
        for (int index = 0; index < k->count; index++)
        {
            const TGLottieJSON *item = k->items[index];
            TGLottiePathKeyframe *keyframe = &property->keyframes[index];
            keyframe->t = (float)TGLottieJSONNumberMember(item, "t", 0.0);
            if (!TGLottieParseBezier(builder, TGLottieJSONMember(item, "s"), &keyframe->start) && previousEnd != NULL)
                keyframe->start = *previousEnd;
            if (!TGLottieParseBezier(builder, TGLottieJSONMember(item, "e"), &keyframe->end))
            {
                if (index + 1 >= k->count || !TGLottieParseBezier(builder, TGLottieJSONMember(k->items[index + 1], "s"), &keyframe->end))
                    keyframe->end = keyframe->start;
            }
            previousEnd = &keyframe->end;
            keyframe->hold = TGLottieJSONIntMember(item, "h", 0) == 1;
            float x[4], y[4];
            TGLottieReadEasing(TGLottieJSONMember(item, "o"), x, y, 0.0f, 0.0f);
            keyframe->outX = x[0];
            keyframe->outY = y[0];
            TGLottieReadEasing(TGLottieJSONMember(item, "i"), x, y, 1.0f, 1.0f);
            keyframe->inX = x[0];
            keyframe->inY = y[0];
            if (builder->failed)
                return;
        }
        property->keyframeCount = k->count;
        property->value = property->keyframes[0].start;
        return;
    }
    TGLottieParseBezier(builder, k, &property->value);
}

static void TGLottieParseTransform(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieTransform *transform)
{
    static const float zero[3] = { 0.0f, 0.0f, 0.0f };
    static const float hundred[3] = { 100.0f, 100.0f, 100.0f };
    TGLottieParseProperty(builder, TGLottieJSONMember(json, "a"), 2, zero, &transform->anchor);
    const TGLottieJSON *position = TGLottieJSONMember(json, "p");
    transform->splitPosition = position != NULL && TGLottieJSONBoolMember(position, "s", 0);
    if (transform->splitPosition)
    {
        TGLottieParsePropertyScalar(builder, TGLottieJSONMember(position, "x"), 0.0f, &transform->positionX);
        TGLottieParsePropertyScalar(builder, TGLottieJSONMember(position, "y"), 0.0f, &transform->positionY);
    }
    else
        TGLottieParseProperty(builder, position, 2, zero, &transform->position);
    TGLottieParseProperty(builder, TGLottieJSONMember(json, "s"), 2, hundred, &transform->scale);
    const TGLottieJSON *rotation = TGLottieJSONMember(json, "r");
    if (rotation == NULL)
        rotation = TGLottieJSONMember(json, "rz");
    TGLottieParsePropertyScalar(builder, rotation, 0.0f, &transform->rotation);
    TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "o"), 100.0f, &transform->opacity);
    TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "sk"), 0.0f, &transform->skew);
    TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "sa"), 0.0f, &transform->skewAxis);
}

static TGLottieShapeType TGLottieShapeTypeForString(const char *type)
{
    if (type == NULL)
        return TGLottieShapeUnknown;
    if (strcmp(type, "gr") == 0) return TGLottieShapeGroup;
    if (strcmp(type, "sh") == 0) return TGLottieShapePath;
    if (strcmp(type, "el") == 0) return TGLottieShapeEllipse;
    if (strcmp(type, "rc") == 0) return TGLottieShapeRect;
    if (strcmp(type, "sr") == 0) return TGLottieShapeStar;
    if (strcmp(type, "fl") == 0) return TGLottieShapeFill;
    if (strcmp(type, "st") == 0) return TGLottieShapeStroke;
    if (strcmp(type, "gf") == 0) return TGLottieShapeGradientFill;
    if (strcmp(type, "gs") == 0) return TGLottieShapeGradientStroke;
    if (strcmp(type, "tm") == 0) return TGLottieShapeTrim;
    if (strcmp(type, "tr") == 0) return TGLottieShapeTransform;
    return TGLottieShapeUnknown;
}

static void TGLottieParseStrokeStyle(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieShape *shape)
{
    TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "w"), 1.0f, &shape->width);
    shape->lineCap = TGLottieJSONIntMember(json, "lc", 2);
    shape->lineJoin = TGLottieJSONIntMember(json, "lj", 2);
    shape->miterLimit = (float)TGLottieJSONNumberMember(json, "ml", 4.0);
    const TGLottieJSON *dashes = TGLottieJSONMember(json, "d");
    if (dashes != NULL && dashes->type == TGLottieJSONArray && dashes->count != 0)
    {
        shape->dashes = (TGLottieDash *)TGLottieBuilderAlloc(builder, sizeof(TGLottieDash) * (size_t)dashes->count);
        if (builder->failed)
            return;
        for (int index = 0; index < dashes->count; index++)
        {
            const char *name = TGLottieJSONStringMember(dashes->items[index], "n");
            TGLottieDash *dash = &shape->dashes[shape->dashCount];
            dash->type = name != NULL && strcmp(name, "o") == 0 ? 2 : (name != NULL && strcmp(name, "g") == 0 ? 1 : 0);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(dashes->items[index], "v"), 0.0f, &dash->value);
            shape->dashCount++;
        }
    }
}

static void TGLottieParseGradient(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieShape *shape)
{
    static const float zero[2] = { 0.0f, 0.0f };
    shape->gradientType = TGLottieJSONIntMember(json, "t", 1);
    TGLottieParseProperty(builder, TGLottieJSONMember(json, "s"), 2, zero, &shape->gradientStart);
    TGLottieParseProperty(builder, TGLottieJSONMember(json, "e"), 2, zero, &shape->gradientEnd);
    TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "h"), 0.0f, &shape->highlightLength);
    TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "a"), 0.0f, &shape->highlightAngle);
    TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "o"), 100.0f, &shape->opacity);
    const TGLottieJSON *gradient = TGLottieJSONMember(json, "g");
    shape->gradientStopCount = TGLottieJSONIntMember(gradient, "p", 0);
    static const float black[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
    TGLottieParseProperty(builder, TGLottieJSONMember(gradient, "k"), 4, black, &shape->gradientColors);
    if (shape->gradientStopCount < 0 || shape->gradientStopCount > shape->gradientColors.dimension / 4)
        shape->gradientStopCount = shape->gradientColors.dimension / 4;
}

static int TGLottieParseShapes(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieShape **outShapes, int depth);

static void TGLottieParseShape(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieShape *shape, int depth)
{
    static const float zero[2] = { 0.0f, 0.0f };
    static const float white[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    shape->type = TGLottieShapeTypeForString(TGLottieJSONStringMember(json, "ty"));
    shape->hidden = TGLottieJSONBoolMember(json, "hd", 0);
    shape->reversed = TGLottieJSONIntMember(json, "d", 1) == 3;
    switch (shape->type)
    {
        case TGLottieShapeGroup:
        {
            if (depth >= TGLottieMaxShapeDepth)
            {
                shape->type = TGLottieShapeUnknown;
                break;
            }
            shape->itemCount = TGLottieParseShapes(builder, TGLottieJSONMember(json, "it"), &shape->items, depth + 1);
            for (int index = 0; index < shape->itemCount; index++)
            {
                if (shape->items[index].type == TGLottieShapeTransform)
                {
                    shape->transform = shape->items[index].transform;
                    shape->hasTransform = 1;
                }
            }
            break;
        }
        case TGLottieShapePath:
            TGLottieParsePathProperty(builder, TGLottieJSONMember(json, "ks"), &shape->path);
            break;
        case TGLottieShapeEllipse:
            TGLottieParseProperty(builder, TGLottieJSONMember(json, "p"), 2, zero, &shape->position);
            TGLottieParseProperty(builder, TGLottieJSONMember(json, "s"), 2, zero, &shape->size);
            break;
        case TGLottieShapeRect:
            TGLottieParseProperty(builder, TGLottieJSONMember(json, "p"), 2, zero, &shape->position);
            TGLottieParseProperty(builder, TGLottieJSONMember(json, "s"), 2, zero, &shape->size);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "r"), 0.0f, &shape->roundness);
            break;
        case TGLottieShapeStar:
            shape->starType = TGLottieJSONIntMember(json, "sy", 1);
            TGLottieParseProperty(builder, TGLottieJSONMember(json, "p"), 2, zero, &shape->position);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "pt"), 5.0f, &shape->points);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "r"), 0.0f, &shape->rotation);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "ir"), 0.0f, &shape->innerRadius);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "or"), 0.0f, &shape->outerRadius);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "is"), 0.0f, &shape->innerRoundness);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "os"), 0.0f, &shape->outerRoundness);
            break;
        case TGLottieShapeFill:
            TGLottieParseProperty(builder, TGLottieJSONMember(json, "c"), 4, white, &shape->color);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "o"), 100.0f, &shape->opacity);
            shape->evenOdd = TGLottieJSONIntMember(json, "r", 1) == 2;
            break;
        case TGLottieShapeStroke:
            TGLottieParseProperty(builder, TGLottieJSONMember(json, "c"), 4, white, &shape->color);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "o"), 100.0f, &shape->opacity);
            TGLottieParseStrokeStyle(builder, json, shape);
            break;
        case TGLottieShapeGradientFill:
            TGLottieParseGradient(builder, json, shape);
            shape->evenOdd = TGLottieJSONIntMember(json, "r", 1) == 2;
            break;
        case TGLottieShapeGradientStroke:
            TGLottieParseGradient(builder, json, shape);
            TGLottieParseStrokeStyle(builder, json, shape);
            break;
        case TGLottieShapeTrim:
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "s"), 0.0f, &shape->trimStart);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "e"), 100.0f, &shape->trimEnd);
            TGLottieParsePropertyScalar(builder, TGLottieJSONMember(json, "o"), 0.0f, &shape->trimOffset);
            shape->trimIndividually = TGLottieJSONIntMember(json, "m", 1) == 2;
            break;
        case TGLottieShapeTransform:
            TGLottieParseTransform(builder, json, &shape->transform);
            shape->hasTransform = 1;
            break;
        default:
            break;
    }
}

static int TGLottieParseShapes(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieShape **outShapes, int depth)
{
    *outShapes = NULL;
    if (json == NULL || json->type != TGLottieJSONArray || json->count == 0)
        return 0;
    TGLottieShape *shapes = (TGLottieShape *)TGLottieBuilderAlloc(builder, sizeof(TGLottieShape) * (size_t)json->count);
    if (shapes == NULL)
        return 0;
    for (int index = 0; index < json->count && !builder->failed; index++)
        TGLottieParseShape(builder, json->items[index], &shapes[index], depth);
    *outShapes = shapes;
    return json->count;
}

static int TGLottieParseHexColor(const char *string, float *color)
{
    if (string == NULL)
        return 0;
    if (*string == '#')
        string++;
    unsigned int value = 0;
    int digits = 0;
    for (; *string != 0 && digits < 6; string++, digits++)
    {
        char c = *string;
        int hex = (c >= '0' && c <= '9') ? c - '0' : (c >= 'a' && c <= 'f') ? c - 'a' + 10 : (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
        if (hex < 0)
            return 0;
        value = (value << 4) | (unsigned int)hex;
    }
    if (digits != 6)
        return 0;
    color[0] = ((value >> 16) & 0xff) / 255.0f;
    color[1] = ((value >> 8) & 0xff) / 255.0f;
    color[2] = (value & 0xff) / 255.0f;
    color[3] = 1.0f;
    return 1;
}

static void TGLottieParseMasks(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieLayer *layer)
{
    if (json == NULL || json->type != TGLottieJSONArray || json->count == 0)
        return;
    layer->masks = (TGLottieMask *)TGLottieBuilderAlloc(builder, sizeof(TGLottieMask) * (size_t)json->count);
    if (builder->failed)
        return;
    for (int index = 0; index < json->count; index++)
    {
        const TGLottieJSON *item = json->items[index];
        const char *mode = TGLottieJSONStringMember(item, "mode");
        TGLottieMask *mask = &layer->masks[layer->maskCount];
        mask->mode = mode == NULL ? 'a' : mode[0];
        if (mask->mode == 'n')
            continue;
        mask->inverted = TGLottieJSONBoolMember(item, "inv", 0);
        TGLottieParsePathProperty(builder, TGLottieJSONMember(item, "pt"), &mask->path);
        TGLottieParsePropertyScalar(builder, TGLottieJSONMember(item, "o"), 100.0f, &mask->opacity);
        layer->maskCount++;
    }
}

static void TGLottieParseLayer(TGLottieModelBuilder *builder, const TGLottieJSON *json, TGLottieLayer *layer)
{
    layer->type = (TGLottieLayerType)TGLottieJSONIntMember(json, "ty", TGLottieLayerNull);
    layer->index = TGLottieJSONIntMember(json, "ind", -1);
    layer->parentIndex = TGLottieJSONIntMember(json, "parent", -1);
    layer->hidden = TGLottieJSONBoolMember(json, "hd", 0);
    layer->isMatteSource = TGLottieJSONIntMember(json, "td", 0) != 0;
    layer->matteMode = TGLottieJSONIntMember(json, "tt", 0);
    layer->inPoint = (float)TGLottieJSONNumberMember(json, "ip", 0.0);
    layer->outPoint = (float)TGLottieJSONNumberMember(json, "op", 0.0);
    layer->startTime = (float)TGLottieJSONNumberMember(json, "st", 0.0);
    layer->timeStretch = (float)TGLottieJSONNumberMember(json, "sr", 1.0);
    if (layer->timeStretch == 0.0f)
        layer->timeStretch = 1.0f;
    TGLottieParseTransform(builder, TGLottieJSONMember(json, "ks"), &layer->transform);
    if (layer->type == TGLottieLayerShape)
        layer->shapeCount = TGLottieParseShapes(builder, TGLottieJSONMember(json, "shapes"), &layer->shapes, 0);
    layer->referenceId = TGLottieBuilderString(builder, TGLottieJSONStringMember(json, "refId"));
    layer->width = (float)TGLottieJSONNumberMember(json, "w", TGLottieJSONNumberMember(json, "sw", 0.0));
    layer->height = (float)TGLottieJSONNumberMember(json, "h", TGLottieJSONNumberMember(json, "sh", 0.0));
    if (layer->type == TGLottieLayerSolid && !TGLottieParseHexColor(TGLottieJSONStringMember(json, "sc"), layer->solidColor))
        layer->hidden = 1;
    TGLottieParseMasks(builder, TGLottieJSONMember(json, "masksProperties"), layer);
}

static void TGLottieParseComposition(TGLottieModelBuilder *builder, const TGLottieJSON *layers, TGLottieComposition *composition)
{
    if (layers == NULL || layers->type != TGLottieJSONArray || layers->count == 0)
        return;
    composition->layers = (TGLottieLayer *)TGLottieBuilderAlloc(builder, sizeof(TGLottieLayer) * (size_t)layers->count);
    if (builder->failed)
        return;
    composition->layerCount = layers->count;
    for (int index = 0; index < layers->count && !builder->failed; index++)
        TGLottieParseLayer(builder, layers->items[index], &composition->layers[index]);
    for (int index = 0; index < composition->layerCount; index++)
    {
        TGLottieLayer *layer = &composition->layers[index];
        if (layer->parentIndex < 0)
            continue;
        for (int candidate = 0; candidate < composition->layerCount; candidate++)
        {
            if (candidate != index && composition->layers[candidate].index == layer->parentIndex)
            {
                layer->parent = &composition->layers[candidate];
                break;
            }
        }
    }
    for (int index = 0; index < composition->layerCount; index++)
    {
        int steps = 0;
        TGLottieLayer *ancestor = composition->layers[index].parent;
        while (ancestor != NULL && steps <= composition->layerCount)
        {
            ancestor = ancestor->parent;
            steps++;
        }
        if (ancestor != NULL)
            composition->layers[index].parent = NULL;
    }
}

static void TGLottieResolvePrecomps(TGLottieAnimation *animation, TGLottieComposition *composition)
{
    for (int index = 0; index < composition->layerCount; index++)
    {
        TGLottieLayer *layer = &composition->layers[index];
        if (layer->type != TGLottieLayerPrecomp || layer->referenceId == NULL)
            continue;
        for (int asset = 0; asset < animation->assetCount; asset++)
        {
            if (animation->assets[asset].identifier != NULL && strcmp(animation->assets[asset].identifier, layer->referenceId) == 0)
            {
                layer->precomp = &animation->assets[asset];
                break;
            }
        }
    }
}

static uint8_t *TGLottieInflate(const uint8_t *data, size_t length, size_t *outLength)
{
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    if (inflateInit2(&stream, 16 + MAX_WBITS) != Z_OK)
        return NULL;
    size_t capacity = length * 8 + 1024;
    if (capacity > TGLottieMaxUncompressedSize)
        capacity = TGLottieMaxUncompressedSize;
    uint8_t *buffer = (uint8_t *)malloc(capacity);
    if (buffer == NULL)
    {
        inflateEnd(&stream);
        return NULL;
    }
    stream.next_in = (Bytef *)data;
    stream.avail_in = (uInt)length;
    size_t produced = 0;
    int status = Z_OK;
    while (status != Z_STREAM_END)
    {
        if (produced == capacity)
        {
            if (capacity >= TGLottieMaxUncompressedSize)
                break;
            size_t newCapacity = capacity * 2;
            if (newCapacity > TGLottieMaxUncompressedSize)
                newCapacity = TGLottieMaxUncompressedSize;
            uint8_t *grown = (uint8_t *)realloc(buffer, newCapacity);
            if (grown == NULL)
                break;
            buffer = grown;
            capacity = newCapacity;
        }
        stream.next_out = buffer + produced;
        stream.avail_out = (uInt)(capacity - produced);
        status = inflate(&stream, Z_NO_FLUSH);
        produced = capacity - stream.avail_out;
        if (status != Z_OK && status != Z_STREAM_END)
            break;
    }
    inflateEnd(&stream);
    if (status != Z_STREAM_END)
    {
        free(buffer);
        return NULL;
    }
    *outLength = produced;
    return buffer;
}

TGLottieAnimation *TGLottieAnimationCreate(const void *data, size_t length)
{
    if (data == NULL || length < 2)
        return NULL;
    const uint8_t *bytes = (const uint8_t *)data;
    uint8_t *inflated = NULL;
    const char *text = (const char *)data;
    size_t textLength = length;
    if (bytes[0] == 0x1f && bytes[1] == 0x8b)
    {
        inflated = TGLottieInflate(bytes, length, &textLength);
        if (inflated == NULL)
            return NULL;
        text = (const char *)inflated;
    }

    TGLottieArena jsonArena;
    TGLottieArenaInit(&jsonArena, 256 * 1024, TGLottieJSONArenaLimit);
    TGLottieJSON *root = TGLottieJSONParse(&jsonArena, text, textLength);
    TGLottieAnimation *animation = NULL;
    if (root != NULL && root->type == TGLottieJSONObject)
    {
        animation = (TGLottieAnimation *)calloc(1, sizeof(TGLottieAnimation));
        if (animation != NULL)
        {
            TGLottieArenaInit(&animation->arena, 64 * 1024, TGLottieModelArenaLimit);
            TGLottieModelBuilder builder;
            builder.arena = &animation->arena;
            builder.failed = 0;
            animation->width = (float)TGLottieJSONNumberMember(root, "w", 512.0);
            animation->height = (float)TGLottieJSONNumberMember(root, "h", 512.0);
            animation->frameRate = (float)TGLottieJSONNumberMember(root, "fr", 30.0);
            animation->inPoint = (float)TGLottieJSONNumberMember(root, "ip", 0.0);
            animation->outPoint = (float)TGLottieJSONNumberMember(root, "op", 0.0);
            const TGLottieJSON *assets = TGLottieJSONMember(root, "assets");
            if (assets != NULL && assets->type == TGLottieJSONArray && assets->count != 0)
            {
                animation->assets = (TGLottieComposition *)TGLottieBuilderAlloc(&builder, sizeof(TGLottieComposition) * (size_t)assets->count);
                for (int index = 0; index < assets->count && !builder.failed; index++)
                {
                    const TGLottieJSON *layers = TGLottieJSONMember(assets->items[index], "layers");
                    if (layers == NULL)
                        continue;
                    TGLottieComposition *composition = &animation->assets[animation->assetCount++];
                    composition->identifier = TGLottieBuilderString(&builder, TGLottieJSONStringMember(assets->items[index], "id"));
                    TGLottieParseComposition(&builder, layers, composition);
                }
            }
            TGLottieParseComposition(&builder, TGLottieJSONMember(root, "layers"), &animation->root);
            if (!builder.failed)
            {
                TGLottieResolvePrecomps(animation, &animation->root);
                for (int index = 0; index < animation->assetCount; index++)
                    TGLottieResolvePrecomps(animation, &animation->assets[index]);
            }
            int valid = !builder.failed && animation->width > 0.0f && animation->height > 0.0f && animation->frameRate > 0.0f && animation->outPoint > animation->inPoint;
            if (!valid)
            {
                TGLottieAnimationDestroy(animation);
                animation = NULL;
            }
        }
    }
    TGLottieArenaDestroy(&jsonArena);
    free(inflated);
    return animation;
}

void TGLottieAnimationDestroy(TGLottieAnimation *animation)
{
    if (animation == NULL)
        return;
    TGLottieArenaDestroy(&animation->arena);
    free(animation);
}

float TGLottieAnimationWidth(const TGLottieAnimation *animation)
{
    return animation->width;
}

float TGLottieAnimationHeight(const TGLottieAnimation *animation)
{
    return animation->height;
}

float TGLottieAnimationFrameRate(const TGLottieAnimation *animation)
{
    return animation->frameRate;
}

float TGLottieAnimationStartFrame(const TGLottieAnimation *animation)
{
    return animation->inPoint;
}

float TGLottieAnimationEndFrame(const TGLottieAnimation *animation)
{
    return animation->outPoint;
}
