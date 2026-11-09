#include "TGLottieInternal.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>

#define TGLottieMaxPropertyDimension 64
#define TGLottieMaxGradientStops 32
#define TGLottieMaxDashes 16
#define TGLottieSegmentSamples 8

static const float TGLottieKappa = 0.5519150244935105707435627f;
static const float TGLottieDegrees = 0.017453292519943295769f;
static const int TGLottieMaxPrecompDepth = 8;

typedef struct
{
    float startX;
    float startY;
    int segmentCount;
    float *segments;
    int closed;
} TGLottieContour;

typedef struct
{
    int contourCount;
    TGLottieContour *contours;
    TGLottieAffine transform;
} TGLottiePathEntry;

typedef struct
{
    int count;
    int capacity;
    TGLottiePathEntry **entries;
} TGLottieEntryList;

typedef struct
{
    const TGLottieShape *style;
    TGLottieAffine transform;
    float opacity;
    TGLottieEntryList entries;
} TGLottieDrawOperation;

typedef struct
{
    int count;
    int capacity;
    TGLottieDrawOperation *operations;
} TGLottieOperationList;

struct TGLottieRenderContext
{
    TGLottieArena arena;
    const TGLottieRenderer *renderer;
    int failed;
};

static void *TGLottieScratch(TGLottieRenderContext *context, size_t size)
{
    void *result = TGLottieArenaAlloc(&context->arena, size);
    if (result == NULL)
        context->failed = 1;
    return result;
}

static float TGLottieClamp(float value, float minimum, float maximum)
{
    return value < minimum ? minimum : (value > maximum ? maximum : value);
}

static float TGLottieBezierCoordinate(float t, float p1, float p2)
{
    float u = 1.0f - t;
    return 3.0f * u * u * t * p1 + 3.0f * u * t * t * p2 + t * t * t;
}

static float TGLottieBezierSlope(float t, float p1, float p2)
{
    float u = 1.0f - t;
    return 3.0f * u * u * p1 + 6.0f * u * t * (p2 - p1) + 3.0f * t * t * (1.0f - p2);
}

static float TGLottieEase(float x1, float y1, float x2, float y2, float progress)
{
    if (progress <= 0.0f)
        return 0.0f;
    if (progress >= 1.0f)
        return 1.0f;
    if (x1 == y1 && x2 == y2)
        return progress;
    x1 = TGLottieClamp(x1, 0.0f, 1.0f);
    x2 = TGLottieClamp(x2, 0.0f, 1.0f);
    float t = progress;
    for (int iteration = 0; iteration < 8; iteration++)
    {
        float slope = TGLottieBezierSlope(t, x1, x2);
        if (fabsf(slope) < 1e-6f)
            break;
        float error = TGLottieBezierCoordinate(t, x1, x2) - progress;
        if (fabsf(error) < 1e-5f)
            return TGLottieBezierCoordinate(t, y1, y2);
        t -= error / slope;
        if (t < 0.0f || t > 1.0f)
            break;
    }
    float low = 0.0f;
    float high = 1.0f;
    t = progress;
    for (int iteration = 0; iteration < 24; iteration++)
    {
        float value = TGLottieBezierCoordinate(t, x1, x2);
        if (fabsf(value - progress) < 1e-5f)
            break;
        if (value < progress)
            low = t;
        else
            high = t;
        t = (low + high) * 0.5f;
    }
    return TGLottieBezierCoordinate(t, y1, y2);
}

static int TGLottieKeyframeIndex(const float *times, size_t stride, int count, float frame)
{
    int low = 0;
    int high = count - 1;
    while (low < high)
    {
        int middle = (low + high + 1) / 2;
        float t = *(const float *)((const uint8_t *)times + stride * (size_t)middle);
        if (t <= frame)
            low = middle;
        else
            high = middle - 1;
    }
    return low;
}

static void TGLottieSpatialPoint(const TGLottieKeyframe *keyframe, float progress, float *output)
{
    float c0[2] = { keyframe->start[0] + keyframe->spatialOut[0], keyframe->start[1] + keyframe->spatialOut[1] };
    float c1[2] = { keyframe->end[0] + keyframe->spatialIn[0], keyframe->end[1] + keyframe->spatialIn[1] };
    float t = progress;
    if (keyframe->arcLengths != NULL)
    {
        const int samples = 24;
        float total = keyframe->arcLengths[samples];
        if (total > 0.0f)
        {
            float target = progress * total;
            int index = 1;
            while (index < samples && keyframe->arcLengths[index] < target)
                index++;
            float previous = keyframe->arcLengths[index - 1];
            float next = keyframe->arcLengths[index];
            float fraction = next > previous ? (target - previous) / (next - previous) : 0.0f;
            t = ((float)(index - 1) + fraction) / (float)samples;
        }
    }
    float u = 1.0f - t;
    float a = u * u * u;
    float b = 3.0f * u * u * t;
    float c = 3.0f * u * t * t;
    float d = t * t * t;
    output[0] = a * keyframe->start[0] + b * c0[0] + c * c1[0] + d * keyframe->end[0];
    output[1] = a * keyframe->start[1] + b * c0[1] + c * c1[1] + d * keyframe->end[1];
}

static void TGLottieEvaluate(const TGLottieProperty *property, float frame, float *output, int capacity)
{
    int dimension = property->dimension < capacity ? property->dimension : capacity;
    if (property->keyframeCount == 0)
    {
        if (property->value != NULL)
            memcpy(output, property->value, sizeof(float) * (size_t)dimension);
        return;
    }
    const TGLottieKeyframe *keyframes = property->keyframes;
    int count = property->keyframeCount;
    if (frame <= keyframes[0].t)
    {
        memcpy(output, keyframes[0].start, sizeof(float) * (size_t)dimension);
        return;
    }
    int index = TGLottieKeyframeIndex(&keyframes[0].t, sizeof(TGLottieKeyframe), count, frame);
    const TGLottieKeyframe *keyframe = &keyframes[index];
    if (index >= count - 1)
    {
        memcpy(output, keyframe->start, sizeof(float) * (size_t)dimension);
        return;
    }
    float nextTime = keyframes[index + 1].t;
    if (keyframe->hold || nextTime <= keyframe->t)
    {
        memcpy(output, keyframe->start, sizeof(float) * (size_t)dimension);
        return;
    }
    float progress = (frame - keyframe->t) / (nextTime - keyframe->t);
    if (keyframe->spatial && dimension >= 2)
    {
        float eased = TGLottieEase(keyframe->outX[0], keyframe->outY[0], keyframe->inX[0], keyframe->inY[0], progress);
        TGLottieSpatialPoint(keyframe, eased, output);
        for (int component = 2; component < dimension; component++)
            output[component] = keyframe->start[component] + (keyframe->end[component] - keyframe->start[component]) * eased;
        return;
    }
    int easingCount = keyframe->easingCount > 0 ? keyframe->easingCount : 1;
    float lastEased = 0.0f;
    int lastEasing = -1;
    for (int component = 0; component < dimension; component++)
    {
        int easing = component < easingCount ? component : easingCount - 1;
        if (easing != lastEasing)
        {
            lastEased = TGLottieEase(keyframe->outX[easing], keyframe->outY[easing], keyframe->inX[easing], keyframe->inY[easing], progress);
            lastEasing = easing;
        }
        output[component] = keyframe->start[component] + (keyframe->end[component] - keyframe->start[component]) * lastEased;
    }
}

static float TGLottieEvaluateScalar(const TGLottieProperty *property, float frame)
{
    float value[TGLottieMaxPropertyDimension];
    value[0] = 0.0f;
    if (property->dimension == 0)
        return 0.0f;
    TGLottieEvaluate(property, frame, value, TGLottieMaxPropertyDimension);
    return value[0];
}

static void TGLottieEvaluatePoint(const TGLottieProperty *property, float frame, float *x, float *y)
{
    float value[TGLottieMaxPropertyDimension];
    value[0] = 0.0f;
    value[1] = 0.0f;
    if (property->dimension != 0)
        TGLottieEvaluate(property, frame, value, TGLottieMaxPropertyDimension);
    *x = value[0];
    *y = property->dimension >= 2 ? value[1] : value[0];
}

static TGLottieBezier TGLottieEvaluatePath(TGLottieRenderContext *context, const TGLottiePathProperty *property, float frame)
{
    if (property->keyframeCount == 0)
        return property->value;
    const TGLottiePathKeyframe *keyframes = property->keyframes;
    int count = property->keyframeCount;
    if (frame <= keyframes[0].t)
        return keyframes[0].start;
    int index = TGLottieKeyframeIndex(&keyframes[0].t, sizeof(TGLottiePathKeyframe), count, frame);
    const TGLottiePathKeyframe *keyframe = &keyframes[index];
    if (index >= count - 1)
        return keyframe->start;
    float nextTime = keyframes[index + 1].t;
    if (keyframe->hold || nextTime <= keyframe->t || keyframe->start.count != keyframe->end.count || keyframe->start.points == NULL || keyframe->end.points == NULL)
        return keyframe->start;
    float progress = TGLottieEase(keyframe->outX, keyframe->outY, keyframe->inX, keyframe->inY, (frame - keyframe->t) / (nextTime - keyframe->t));
    TGLottieBezier result;
    result.count = keyframe->start.count;
    result.closed = keyframe->start.closed;
    result.points = (float *)TGLottieScratch(context, sizeof(float) * (size_t)(result.count * 6 + 1));
    if (result.points == NULL)
        return keyframe->start;
    int total = result.count * 6;
    for (int index = 0; index < total; index++)
        result.points[index] = keyframe->start.points[index] + (keyframe->end.points[index] - keyframe->start.points[index]) * progress;
    return result;
}

static TGLottieAffine TGLottieTranslation(float x, float y)
{
    TGLottieAffine matrix = { 1.0f, 0.0f, 0.0f, 1.0f, x, y };
    return matrix;
}

static TGLottieAffine TGLottieRotation(float radians)
{
    float cosine = cosf(radians);
    float sine = sinf(radians);
    TGLottieAffine matrix = { cosine, sine, -sine, cosine, 0.0f, 0.0f };
    return matrix;
}

static TGLottieAffine TGLottieTransformMatrix(const TGLottieTransform *transform, float frame, float *opacity)
{
    float anchorX, anchorY, positionX, positionY, scaleX, scaleY;
    TGLottieEvaluatePoint(&transform->anchor, frame, &anchorX, &anchorY);
    if (transform->splitPosition)
    {
        positionX = TGLottieEvaluateScalar(&transform->positionX, frame);
        positionY = TGLottieEvaluateScalar(&transform->positionY, frame);
    }
    else
        TGLottieEvaluatePoint(&transform->position, frame, &positionX, &positionY);
    TGLottieEvaluatePoint(&transform->scale, frame, &scaleX, &scaleY);
    float rotation = TGLottieEvaluateScalar(&transform->rotation, frame);
    float skew = TGLottieEvaluateScalar(&transform->skew, frame);
    if (opacity != NULL)
        *opacity = TGLottieClamp(TGLottieEvaluateScalar(&transform->opacity, frame) / 100.0f, 0.0f, 1.0f);

    TGLottieAffine matrix = TGLottieTranslation(positionX, positionY);
    if (rotation != 0.0f)
        matrix = TGLottieAffineMultiply(matrix, TGLottieRotation(rotation * TGLottieDegrees));
    if (skew != 0.0f)
    {
        float axis = TGLottieEvaluateScalar(&transform->skewAxis, frame) * TGLottieDegrees;
        TGLottieAffine shear = { 1.0f, 0.0f, tanf(-skew * TGLottieDegrees), 1.0f, 0.0f, 0.0f };
        matrix = TGLottieAffineMultiply(matrix, TGLottieAffineMultiply(TGLottieRotation(-axis), TGLottieAffineMultiply(shear, TGLottieRotation(axis))));
    }
    TGLottieAffine scale = { scaleX / 100.0f, 0.0f, 0.0f, scaleY / 100.0f, 0.0f, 0.0f };
    matrix = TGLottieAffineMultiply(matrix, scale);
    return TGLottieAffineMultiply(matrix, TGLottieTranslation(-anchorX, -anchorY));
}

static float TGLottieLayerFrame(const TGLottieLayer *layer, float frame)
{
    return (frame - layer->startTime) / layer->timeStretch;
}

static TGLottieAffine TGLottieLayerMatrix(const TGLottieLayer *layer, float frame, float *opacity)
{
    TGLottieAffine matrix = TGLottieTransformMatrix(&layer->transform, TGLottieLayerFrame(layer, frame), opacity);
    const TGLottieLayer *parent = layer->parent;
    int depth = 0;
    while (parent != NULL && depth < 64)
    {
        matrix = TGLottieAffineMultiply(TGLottieTransformMatrix(&parent->transform, TGLottieLayerFrame(parent, frame), NULL), matrix);
        parent = parent->parent;
        depth++;
    }
    return matrix;
}

static TGLottieContour *TGLottieNewContours(TGLottieRenderContext *context, int count)
{
    TGLottieContour *contours = (TGLottieContour *)TGLottieScratch(context, sizeof(TGLottieContour) * (size_t)(count > 0 ? count : 1));
    if (contours != NULL)
        memset(contours, 0, sizeof(TGLottieContour) * (size_t)(count > 0 ? count : 1));
    return contours;
}

static TGLottiePathEntry *TGLottieNewEntry(TGLottieRenderContext *context, TGLottieAffine transform)
{
    TGLottiePathEntry *entry = (TGLottiePathEntry *)TGLottieScratch(context, sizeof(TGLottiePathEntry));
    if (entry != NULL)
    {
        entry->contourCount = 0;
        entry->contours = NULL;
        entry->transform = transform;
    }
    return entry;
}

static void TGLottieEntryListAppend(TGLottieRenderContext *context, TGLottieEntryList *list, TGLottiePathEntry *entry)
{
    if (entry == NULL)
        return;
    if (list->count == list->capacity)
    {
        int capacity = list->capacity == 0 ? 8 : list->capacity * 2;
        TGLottiePathEntry **entries = (TGLottiePathEntry **)TGLottieScratch(context, sizeof(TGLottiePathEntry *) * (size_t)capacity);
        if (entries == NULL)
            return;
        if (list->count != 0)
            memcpy(entries, list->entries, sizeof(TGLottiePathEntry *) * (size_t)list->count);
        list->entries = entries;
        list->capacity = capacity;
    }
    list->entries[list->count++] = entry;
}

static TGLottieDrawOperation *TGLottieOperationListAppend(TGLottieRenderContext *context, TGLottieOperationList *list)
{
    if (list->count == list->capacity)
    {
        int capacity = list->capacity == 0 ? 16 : list->capacity * 2;
        TGLottieDrawOperation *operations = (TGLottieDrawOperation *)TGLottieScratch(context, sizeof(TGLottieDrawOperation) * (size_t)capacity);
        if (operations == NULL)
            return NULL;
        if (list->count != 0)
            memcpy(operations, list->operations, sizeof(TGLottieDrawOperation) * (size_t)list->count);
        list->operations = operations;
        list->capacity = capacity;
    }
    return &list->operations[list->count++];
}

static void TGLottieContourFromBezier(TGLottieRenderContext *context, const TGLottieBezier *bezier, TGLottieContour *contour)
{
    memset(contour, 0, sizeof(TGLottieContour));
    if (bezier->count == 0 || bezier->points == NULL)
        return;
    int segmentCount = bezier->count - 1 + (bezier->closed ? 1 : 0);
    contour->startX = bezier->points[0];
    contour->startY = bezier->points[1];
    contour->closed = bezier->closed;
    if (segmentCount <= 0)
        return;
    contour->segments = (float *)TGLottieScratch(context, sizeof(float) * 6 * (size_t)segmentCount);
    if (contour->segments == NULL)
        return;
    contour->segmentCount = segmentCount;
    for (int index = 0; index < segmentCount; index++)
    {
        const float *from = bezier->points + index * 6;
        const float *to = bezier->points + ((index + 1) % bezier->count) * 6;
        float *segment = contour->segments + index * 6;
        segment[0] = from[0] + from[4];
        segment[1] = from[1] + from[5];
        segment[2] = to[0] + to[2];
        segment[3] = to[1] + to[3];
        segment[4] = to[0];
        segment[5] = to[1];
    }
}

static void TGLottieEllipseContour(TGLottieRenderContext *context, float centerX, float centerY, float width, float height, int reversed, TGLottieContour *contour)
{
    memset(contour, 0, sizeof(TGLottieContour));
    float rx = width * 0.5f;
    float ry = height * 0.5f;
    float kx = rx * TGLottieKappa;
    float ky = ry * TGLottieKappa;
    contour->segments = (float *)TGLottieScratch(context, sizeof(float) * 24);
    if (contour->segments == NULL)
        return;
    contour->segmentCount = 4;
    contour->closed = 1;
    contour->startX = centerX;
    contour->startY = centerY - ry;
    float clockwise[24] = {
        centerX + kx, centerY - ry, centerX + rx, centerY - ky, centerX + rx, centerY,
        centerX + rx, centerY + ky, centerX + kx, centerY + ry, centerX, centerY + ry,
        centerX - kx, centerY + ry, centerX - rx, centerY + ky, centerX - rx, centerY,
        centerX - rx, centerY - ky, centerX - kx, centerY - ry, centerX, centerY - ry
    };
    float counterClockwise[24] = {
        centerX - kx, centerY - ry, centerX - rx, centerY - ky, centerX - rx, centerY,
        centerX - rx, centerY + ky, centerX - kx, centerY + ry, centerX, centerY + ry,
        centerX + kx, centerY + ry, centerX + rx, centerY + ky, centerX + rx, centerY,
        centerX + rx, centerY - ky, centerX + kx, centerY - ry, centerX, centerY - ry
    };
    memcpy(contour->segments, reversed ? counterClockwise : clockwise, sizeof(float) * 24);
}

static void TGLottieContourAppendLine(float *segment, float fromX, float fromY, float toX, float toY)
{
    segment[0] = fromX + (toX - fromX) / 3.0f;
    segment[1] = fromY + (toY - fromY) / 3.0f;
    segment[2] = fromX + (toX - fromX) * 2.0f / 3.0f;
    segment[3] = fromY + (toY - fromY) * 2.0f / 3.0f;
    segment[4] = toX;
    segment[5] = toY;
}

static void TGLottieReverseContour(TGLottieRenderContext *context, TGLottieContour *contour)
{
    if (contour->segmentCount == 0)
        return;
    float *reversed = (float *)TGLottieScratch(context, sizeof(float) * 6 * (size_t)contour->segmentCount);
    if (reversed == NULL)
        return;
    int count = contour->segmentCount;
    const float *last = contour->segments + (count - 1) * 6;
    float newStartX = last[4];
    float newStartY = last[5];
    for (int index = 0; index < count; index++)
    {
        const float *source = contour->segments + (count - 1 - index) * 6;
        float *target = reversed + index * 6;
        int previous = count - 2 - index;
        target[0] = source[2];
        target[1] = source[3];
        target[2] = source[0];
        target[3] = source[1];
        target[4] = previous >= 0 ? contour->segments[previous * 6 + 4] : contour->startX;
        target[5] = previous >= 0 ? contour->segments[previous * 6 + 5] : contour->startY;
    }
    contour->segments = reversed;
    contour->startX = newStartX;
    contour->startY = newStartY;
}

static void TGLottieRectContour(TGLottieRenderContext *context, float centerX, float centerY, float width, float height, float roundness, int reversed, TGLottieContour *contour)
{
    memset(contour, 0, sizeof(TGLottieContour));
    float halfWidth = width * 0.5f;
    float halfHeight = height * 0.5f;
    float maximumRadius = halfWidth < halfHeight ? halfWidth : halfHeight;
    float radius = TGLottieClamp(roundness, 0.0f, maximumRadius);
    float left = centerX - halfWidth;
    float right = centerX + halfWidth;
    float top = centerY - halfHeight;
    float bottom = centerY + halfHeight;
    float k = radius * (1.0f - TGLottieKappa);
    float points[8][2] = {
        { right, top + radius }, { right, bottom - radius },
        { right - radius, bottom }, { left + radius, bottom },
        { left, bottom - radius }, { left, top + radius },
        { left + radius, top }, { right - radius, top }
    };
    float corners[4][4] = {
        { right, bottom - k, right - k, bottom },
        { left + k, bottom, left, bottom - k },
        { left, top + k, left + k, top },
        { right - k, top, right, top + k }
    };
    contour->segments = (float *)TGLottieScratch(context, sizeof(float) * 48);
    if (contour->segments == NULL)
        return;
    contour->closed = 1;
    contour->segmentCount = 8;
    contour->startX = points[0][0];
    contour->startY = points[0][1];
    for (int side = 0; side < 4; side++)
    {
        float *line = contour->segments + side * 12;
        float *corner = line + 6;
        TGLottieContourAppendLine(line, points[side * 2][0], points[side * 2][1], points[side * 2 + 1][0], points[side * 2 + 1][1]);
        corner[0] = corners[side][0];
        corner[1] = corners[side][1];
        corner[2] = corners[side][2];
        corner[3] = corners[side][3];
        corner[4] = points[(side * 2 + 2) % 8][0];
        corner[5] = points[(side * 2 + 2) % 8][1];
    }
    if (reversed)
        TGLottieReverseContour(context, contour);
}

static void TGLottieStarContour(TGLottieRenderContext *context, const TGLottieShape *shape, float frame, TGLottieContour *contour)
{
    memset(contour, 0, sizeof(TGLottieContour));
    float centerX, centerY;
    TGLottieEvaluatePoint(&shape->position, frame, &centerX, &centerY);
    float pointCount = floorf(TGLottieEvaluateScalar(&shape->points, frame));
    if (pointCount < 2.0f || pointCount > 256.0f)
        return;
    int polygon = shape->starType == 2;
    int vertexCount = polygon ? (int)pointCount : (int)pointCount * 2;
    float outerRadius = TGLottieEvaluateScalar(&shape->outerRadius, frame);
    float innerRadius = polygon ? outerRadius : TGLottieEvaluateScalar(&shape->innerRadius, frame);
    float outerRoundness = TGLottieEvaluateScalar(&shape->outerRoundness, frame) / 100.0f;
    float innerRoundness = polygon ? outerRoundness : TGLottieEvaluateScalar(&shape->innerRoundness, frame) / 100.0f;
    float angleStep = 6.283185307179586f / (float)vertexCount;
    float outerSegment = polygon ? 6.283185307179586f * outerRadius / ((float)vertexCount * 4.0f) : 6.283185307179586f * outerRadius / ((float)vertexCount * 2.0f);
    float innerSegment = 6.283185307179586f * innerRadius / ((float)vertexCount * 2.0f);
    float direction = shape->reversed ? -1.0f : 1.0f;
    float angle = -1.5707963267948966f + TGLottieEvaluateScalar(&shape->rotation, frame) * TGLottieDegrees;
    TGLottieBezier bezier;
    bezier.count = vertexCount;
    bezier.closed = 1;
    bezier.points = (float *)TGLottieScratch(context, sizeof(float) * 6 * (size_t)vertexCount);
    if (bezier.points == NULL)
        return;
    int outer = 1;
    for (int index = 0; index < vertexCount; index++)
    {
        float radius = outer ? outerRadius : innerRadius;
        float roundness = outer ? outerRoundness : innerRoundness;
        float segment = outer || polygon ? outerSegment : innerSegment;
        float x = radius * cosf(angle);
        float y = radius * sinf(angle);
        float length = sqrtf(x * x + y * y);
        float ox = length > 0.0f ? y / length : 0.0f;
        float oy = length > 0.0f ? -x / length : 0.0f;
        float *point = bezier.points + index * 6;
        point[0] = x + centerX;
        point[1] = y + centerY;
        point[2] = ox * segment * roundness * direction;
        point[3] = oy * segment * roundness * direction;
        point[4] = -ox * segment * roundness * direction;
        point[5] = -oy * segment * roundness * direction;
        if (!polygon)
            outer = !outer;
        angle += angleStep * direction;
    }
    TGLottieContourFromBezier(context, &bezier, contour);
}

static float TGLottieSegmentLength(float fromX, float fromY, const float *segment, float *samples)
{
    float previousX = fromX;
    float previousY = fromY;
    float length = 0.0f;
    for (int index = 1; index <= TGLottieSegmentSamples; index++)
    {
        float t = (float)index / (float)TGLottieSegmentSamples;
        float u = 1.0f - t;
        float a = u * u * u, b = 3.0f * u * u * t, c = 3.0f * u * t * t, d = t * t * t;
        float x = a * fromX + b * segment[0] + c * segment[2] + d * segment[4];
        float y = a * fromY + b * segment[1] + c * segment[3] + d * segment[5];
        float dx = x - previousX;
        float dy = y - previousY;
        length += sqrtf(dx * dx + dy * dy);
        if (samples != NULL)
            samples[index] = length;
        previousX = x;
        previousY = y;
    }
    if (samples != NULL)
        samples[0] = 0.0f;
    return length;
}

static float TGLottieSegmentParameter(const float *samples, float length)
{
    float total = samples[TGLottieSegmentSamples];
    if (total <= 0.0f)
        return 0.0f;
    if (length <= 0.0f)
        return 0.0f;
    if (length >= total)
        return 1.0f;
    int index = 1;
    while (index < TGLottieSegmentSamples && samples[index] < length)
        index++;
    float previous = samples[index - 1];
    float next = samples[index];
    float fraction = next > previous ? (length - previous) / (next - previous) : 0.0f;
    return ((float)(index - 1) + fraction) / (float)TGLottieSegmentSamples;
}

static void TGLottieSplitSegment(float fromX, float fromY, const float *segment, float t0, float t1, float *outStartX, float *outStartY, float *output)
{
    float p[4][2] = { { fromX, fromY }, { segment[0], segment[1] }, { segment[2], segment[3] }, { segment[4], segment[5] } };
    float q[4][2];
    if (t1 < 1.0f)
    {
        float t = t1;
        float a[2] = { p[0][0] + (p[1][0] - p[0][0]) * t, p[0][1] + (p[1][1] - p[0][1]) * t };
        float b[2] = { p[1][0] + (p[2][0] - p[1][0]) * t, p[1][1] + (p[2][1] - p[1][1]) * t };
        float c[2] = { p[2][0] + (p[3][0] - p[2][0]) * t, p[2][1] + (p[3][1] - p[2][1]) * t };
        float d[2] = { a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t };
        float e[2] = { b[0] + (c[0] - b[0]) * t, b[1] + (c[1] - b[1]) * t };
        float f[2] = { d[0] + (e[0] - d[0]) * t, d[1] + (e[1] - d[1]) * t };
        q[0][0] = p[0][0]; q[0][1] = p[0][1];
        q[1][0] = a[0]; q[1][1] = a[1];
        q[2][0] = d[0]; q[2][1] = d[1];
        q[3][0] = f[0]; q[3][1] = f[1];
        memcpy(p, q, sizeof(p));
        if (t1 > 0.0f)
            t0 = t0 / t1;
        else
            t0 = 0.0f;
    }
    if (t0 > 0.0f)
    {
        float t = t0;
        float a[2] = { p[0][0] + (p[1][0] - p[0][0]) * t, p[0][1] + (p[1][1] - p[0][1]) * t };
        float b[2] = { p[1][0] + (p[2][0] - p[1][0]) * t, p[1][1] + (p[2][1] - p[1][1]) * t };
        float c[2] = { p[2][0] + (p[3][0] - p[2][0]) * t, p[2][1] + (p[3][1] - p[2][1]) * t };
        float d[2] = { a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t };
        float e[2] = { b[0] + (c[0] - b[0]) * t, b[1] + (c[1] - b[1]) * t };
        float f[2] = { d[0] + (e[0] - d[0]) * t, d[1] + (e[1] - d[1]) * t };
        q[0][0] = f[0]; q[0][1] = f[1];
        q[1][0] = e[0]; q[1][1] = e[1];
        q[2][0] = c[0]; q[2][1] = c[1];
        q[3][0] = p[3][0]; q[3][1] = p[3][1];
        memcpy(p, q, sizeof(p));
    }
    *outStartX = p[0][0];
    *outStartY = p[0][1];
    output[0] = p[1][0];
    output[1] = p[1][1];
    output[2] = p[2][0];
    output[3] = p[2][1];
    output[4] = p[3][0];
    output[5] = p[3][1];
}

static float TGLottieContourLength(const TGLottieContour *contour)
{
    float length = 0.0f;
    float x = contour->startX;
    float y = contour->startY;
    for (int index = 0; index < contour->segmentCount; index++)
    {
        const float *segment = contour->segments + index * 6;
        length += TGLottieSegmentLength(x, y, segment, NULL);
        x = segment[4];
        y = segment[5];
    }
    return length;
}

static int TGLottieExtractRange(TGLottieRenderContext *context, const TGLottieContour *contour, float from, float to, TGLottieContour *output, int append)
{
    if (to <= from)
        return 0;
    if (!append)
    {
        memset(output, 0, sizeof(TGLottieContour));
        output->segments = (float *)TGLottieScratch(context, sizeof(float) * 6 * (size_t)(contour->segmentCount * 2 + 1));
        if (output->segments == NULL)
            return 0;
    }
    float samples[TGLottieSegmentSamples + 1];
    float position = 0.0f;
    float x = contour->startX;
    float y = contour->startY;
    int started = append && output->segmentCount > 0;
    for (int index = 0; index < contour->segmentCount; index++)
    {
        const float *segment = contour->segments + index * 6;
        float length = TGLottieSegmentLength(x, y, segment, samples);
        float segmentStart = position;
        float segmentEnd = position + length;
        if (segmentEnd > from && segmentStart < to && length > 0.0f)
        {
            float t0 = TGLottieSegmentParameter(samples, from - segmentStart);
            float t1 = TGLottieSegmentParameter(samples, to - segmentStart);
            float startX, startY;
            float *target = output->segments + output->segmentCount * 6;
            TGLottieSplitSegment(x, y, segment, from > segmentStart ? t0 : 0.0f, to < segmentEnd ? t1 : 1.0f, &startX, &startY, target);
            if (!started)
            {
                output->startX = startX;
                output->startY = startY;
                started = 1;
            }
            output->segmentCount++;
        }
        position = segmentEnd;
        x = segment[4];
        y = segment[5];
    }
    return started;
}

static int TGLottieTrimContourInto(TGLottieRenderContext *context, const TGLottieContour *contour, float start, float end, TGLottieContour *results)
{
    float length = TGLottieContourLength(contour);
    if (length <= 0.0f)
        return 0;
    if (end <= 1.0f)
    {
        if (!TGLottieExtractRange(context, contour, start * length, end * length, &results[0], 0))
            return 0;
        results[0].closed = 0;
        return 1;
    }
    int count = 0;
    if (TGLottieExtractRange(context, contour, start * length, length, &results[0], 0))
        count = 1;
    if (count == 1 && contour->closed)
    {
        TGLottieExtractRange(context, contour, 0.0f, (end - 1.0f) * length, &results[0], 1);
        results[0].closed = 0;
        return 1;
    }
    if (TGLottieExtractRange(context, contour, 0.0f, (end - 1.0f) * length, &results[count], 0))
        count++;
    for (int index = 0; index < count; index++)
        results[index].closed = 0;
    return count;
}

static int TGLottieTrimBounds(float start, float end, float offset, float *outStart, float *outEnd)
{
    float s = TGLottieClamp(start / 100.0f, 0.0f, 1.0f);
    float e = TGLottieClamp(end / 100.0f, 0.0f, 1.0f);
    float o = offset / 360.0f;
    o -= floorf(o);
    if (s > e)
    {
        float swap = s;
        s = e;
        e = swap;
    }
    if (e - s <= 1e-5f)
        return 0;
    if (e - s >= 1.0f - 1e-5f)
        return 2;
    s += o;
    e += o;
    if (s >= 1.0f)
    {
        s -= 1.0f;
        e -= 1.0f;
    }
    *outStart = s;
    *outEnd = e;
    return 1;
}

static void TGLottieApplyTrim(TGLottieRenderContext *context, const TGLottieShape *trim, float frame, TGLottieEntryList *entries)
{
    float start = 0.0f;
    float end = 1.0f;
    int mode = TGLottieTrimBounds(TGLottieEvaluateScalar(&trim->trimStart, frame), TGLottieEvaluateScalar(&trim->trimEnd, frame), TGLottieEvaluateScalar(&trim->trimOffset, frame), &start, &end);
    if (mode == 2)
        return;
    if (mode == 0)
    {
        for (int index = 0; index < entries->count; index++)
            entries->entries[index]->contourCount = 0;
        return;
    }
    float total = 0.0f;
    float ranges[2][2];
    int rangeCount = 0;
    if (trim->trimIndividually)
    {
        for (int index = 0; index < entries->count; index++)
        {
            TGLottiePathEntry *entry = entries->entries[index];
            for (int contour = 0; contour < entry->contourCount; contour++)
                total += TGLottieContourLength(&entry->contours[contour]);
        }
        if (total <= 0.0f)
            return;
        ranges[0][0] = start * total;
        ranges[0][1] = (end > 1.0f ? 1.0f : end) * total;
        rangeCount = 1;
        if (end > 1.0f)
        {
            ranges[1][0] = 0.0f;
            ranges[1][1] = (end - 1.0f) * total;
            rangeCount = 2;
        }
    }
    float position = 0.0f;
    for (int index = 0; index < entries->count; index++)
    {
        TGLottiePathEntry *entry = entries->entries[index];
        if (entry->contourCount == 0)
            continue;
        TGLottieContour *results = TGLottieNewContours(context, entry->contourCount * 2);
        if (results == NULL)
            return;
        int resultCount = 0;
        for (int contourIndex = 0; contourIndex < entry->contourCount; contourIndex++)
        {
            const TGLottieContour *contour = &entry->contours[contourIndex];
            if (!trim->trimIndividually)
            {
                resultCount += TGLottieTrimContourInto(context, contour, start, end, results + resultCount);
                continue;
            }
            float length = TGLottieContourLength(contour);
            float contourStart = position;
            float contourEnd = position + length;
            position = contourEnd;
            for (int range = 0; range < rangeCount && length > 0.0f; range++)
            {
                float from = ranges[range][0] > contourStart ? ranges[range][0] : contourStart;
                float to = ranges[range][1] < contourEnd ? ranges[range][1] : contourEnd;
                if (to > from && TGLottieExtractRange(context, contour, from - contourStart, to - contourStart, &results[resultCount], 0))
                {
                    results[resultCount].closed = 0;
                    resultCount++;
                }
            }
        }
        entry->contours = results;
        entry->contourCount = resultCount;
    }
}

typedef struct
{
    int commandCount;
    int commandCapacity;
    uint8_t *commands;
    int pointCount;
    int pointCapacity;
    float *points;
} TGLottiePathBuffer;

static int TGLottiePathBufferReserve(TGLottieRenderContext *context, TGLottiePathBuffer *buffer, int commands, int points)
{
    if (buffer->commandCount + commands > buffer->commandCapacity)
    {
        int capacity = buffer->commandCapacity * 2 + commands + 16;
        uint8_t *grown = (uint8_t *)TGLottieScratch(context, (size_t)capacity);
        if (grown == NULL)
            return 0;
        if (buffer->commandCount != 0)
            memcpy(grown, buffer->commands, (size_t)buffer->commandCount);
        buffer->commands = grown;
        buffer->commandCapacity = capacity;
    }
    if (buffer->pointCount + points > buffer->pointCapacity)
    {
        int capacity = buffer->pointCapacity * 2 + points + 32;
        float *grown = (float *)TGLottieScratch(context, sizeof(float) * (size_t)capacity);
        if (grown == NULL)
            return 0;
        if (buffer->pointCount != 0)
            memcpy(grown, buffer->points, sizeof(float) * (size_t)buffer->pointCount);
        buffer->points = grown;
        buffer->pointCapacity = capacity;
    }
    return 1;
}

static void TGLottiePathBufferAppendEntry(TGLottieRenderContext *context, TGLottiePathBuffer *buffer, const TGLottiePathEntry *entry, const TGLottieAffine *matrix)
{
    for (int contourIndex = 0; contourIndex < entry->contourCount; contourIndex++)
    {
        const TGLottieContour *contour = &entry->contours[contourIndex];
        if (contour->segmentCount == 0)
            continue;
        if (!TGLottiePathBufferReserve(context, buffer, contour->segmentCount + 2, contour->segmentCount * 6 + 2))
            return;
        buffer->commands[buffer->commandCount++] = TGLottiePathMove;
        TGLottieAffineApply(matrix, contour->startX, contour->startY, &buffer->points[buffer->pointCount], &buffer->points[buffer->pointCount + 1]);
        buffer->pointCount += 2;
        for (int index = 0; index < contour->segmentCount; index++)
        {
            const float *segment = contour->segments + index * 6;
            buffer->commands[buffer->commandCount++] = TGLottiePathCubic;
            float *target = &buffer->points[buffer->pointCount];
            TGLottieAffineApply(matrix, segment[0], segment[1], &target[0], &target[1]);
            TGLottieAffineApply(matrix, segment[2], segment[3], &target[2], &target[3]);
            TGLottieAffineApply(matrix, segment[4], segment[5], &target[4], &target[5]);
            buffer->pointCount += 6;
        }
        if (contour->closed)
            buffer->commands[buffer->commandCount++] = TGLottiePathClose;
    }
}

static TGLottiePath TGLottiePathFromBuffer(const TGLottiePathBuffer *buffer)
{
    TGLottiePath path;
    path.commandCount = buffer->commandCount;
    path.commands = buffer->commands;
    path.points = buffer->points;
    return path;
}

static void TGLottieEvaluateGroup(TGLottieRenderContext *context, const TGLottieShape *items, int itemCount, float frame, TGLottieAffine matrix, float opacity, TGLottieEntryList *entries, TGLottieOperationList *operations)
{
    for (int index = 0; index < itemCount && !context->failed; index++)
    {
        const TGLottieShape *item = &items[index];
        if (item->hidden)
            continue;
        switch (item->type)
        {
            case TGLottieShapeGroup:
            {
                float groupOpacity = 1.0f;
                TGLottieAffine groupMatrix = item->hasTransform ? TGLottieAffineMultiply(matrix, TGLottieTransformMatrix(&item->transform, frame, &groupOpacity)) : matrix;
                if (groupOpacity <= 0.0f)
                    break;
                TGLottieEntryList childEntries;
                memset(&childEntries, 0, sizeof(childEntries));
                TGLottieEvaluateGroup(context, item->items, item->itemCount, frame, groupMatrix, opacity * groupOpacity, &childEntries, operations);
                for (int child = 0; child < childEntries.count; child++)
                    TGLottieEntryListAppend(context, entries, childEntries.entries[child]);
                break;
            }
            case TGLottieShapePath:
            case TGLottieShapeEllipse:
            case TGLottieShapeRect:
            case TGLottieShapeStar:
            {
                TGLottiePathEntry *entry = TGLottieNewEntry(context, matrix);
                if (entry == NULL)
                    break;
                entry->contours = TGLottieNewContours(context, 1);
                if (entry->contours == NULL)
                    break;
                entry->contourCount = 1;
                if (item->type == TGLottieShapePath)
                {
                    TGLottieBezier bezier = TGLottieEvaluatePath(context, &item->path, frame);
                    TGLottieContourFromBezier(context, &bezier, &entry->contours[0]);
                }
                else if (item->type == TGLottieShapeEllipse)
                {
                    float x, y, width, height;
                    TGLottieEvaluatePoint(&item->position, frame, &x, &y);
                    TGLottieEvaluatePoint(&item->size, frame, &width, &height);
                    TGLottieEllipseContour(context, x, y, width, height, item->reversed, &entry->contours[0]);
                }
                else if (item->type == TGLottieShapeRect)
                {
                    float x, y, width, height;
                    TGLottieEvaluatePoint(&item->position, frame, &x, &y);
                    TGLottieEvaluatePoint(&item->size, frame, &width, &height);
                    TGLottieRectContour(context, x, y, width, height, TGLottieEvaluateScalar(&item->roundness, frame), item->reversed, &entry->contours[0]);
                }
                else
                    TGLottieStarContour(context, item, frame, &entry->contours[0]);
                TGLottieEntryListAppend(context, entries, entry);
                break;
            }
            case TGLottieShapeTrim:
                TGLottieApplyTrim(context, item, frame, entries);
                break;
            case TGLottieShapeFill:
            case TGLottieShapeStroke:
            case TGLottieShapeGradientFill:
            case TGLottieShapeGradientStroke:
            {
                if (entries->count == 0)
                    break;
                TGLottieDrawOperation *operation = TGLottieOperationListAppend(context, operations);
                if (operation == NULL)
                    break;
                operation->style = item;
                operation->transform = matrix;
                operation->opacity = opacity;
                operation->entries.count = entries->count;
                operation->entries.capacity = entries->count;
                operation->entries.entries = (TGLottiePathEntry **)TGLottieScratch(context, sizeof(TGLottiePathEntry *) * (size_t)entries->count);
                if (operation->entries.entries != NULL)
                    memcpy(operation->entries.entries, entries->entries, sizeof(TGLottiePathEntry *) * (size_t)entries->count);
                else
                    operation->entries.count = 0;
                break;
            }
            default:
                break;
        }
    }
}

static int TGLottieGradientStops(const TGLottieShape *style, float frame, TGLottieGradientStop *stops)
{
    float values[TGLottieMaxPropertyDimension];
    int dimension = style->gradientColors.dimension < TGLottieMaxPropertyDimension ? style->gradientColors.dimension : TGLottieMaxPropertyDimension;
    if (dimension < 4)
        return 0;
    TGLottieEvaluate(&style->gradientColors, frame, values, TGLottieMaxPropertyDimension);
    int colorCount = style->gradientStopCount;
    if (colorCount > dimension / 4)
        colorCount = dimension / 4;
    if (colorCount <= 0)
        return 0;
    const float *colors = values;
    const float *alphas = values + colorCount * 4;
    int alphaCount = (dimension - colorCount * 4) / 2;
    float offsets[TGLottieMaxGradientStops];
    int offsetCount = 0;
    for (int index = 0; index < colorCount && offsetCount < TGLottieMaxGradientStops; index++)
        offsets[offsetCount++] = colors[index * 4];
    for (int index = 0; index < alphaCount && offsetCount < TGLottieMaxGradientStops; index++)
    {
        float offset = alphas[index * 2];
        int exists = 0;
        for (int existing = 0; existing < offsetCount; existing++)
        {
            if (fabsf(offsets[existing] - offset) < 1e-4f)
                exists = 1;
        }
        if (!exists)
            offsets[offsetCount++] = offset;
    }
    for (int i = 1; i < offsetCount; i++)
    {
        float value = offsets[i];
        int j = i - 1;
        while (j >= 0 && offsets[j] > value)
        {
            offsets[j + 1] = offsets[j];
            j--;
        }
        offsets[j + 1] = value;
    }
    for (int index = 0; index < offsetCount; index++)
    {
        float offset = offsets[index];
        TGLottieGradientStop *stop = &stops[index];
        stop->offset = TGLottieClamp(offset, 0.0f, 1.0f);
        int upper = 0;
        while (upper < colorCount && colors[upper * 4] < offset)
            upper++;
        if (upper == 0 || upper == colorCount)
        {
            int source = upper == 0 ? 0 : colorCount - 1;
            stop->r = colors[source * 4 + 1];
            stop->g = colors[source * 4 + 2];
            stop->b = colors[source * 4 + 3];
        }
        else
        {
            const float *lower = colors + (upper - 1) * 4;
            const float *higher = colors + upper * 4;
            float span = higher[0] - lower[0];
            float fraction = span > 0.0f ? (offset - lower[0]) / span : 0.0f;
            stop->r = lower[1] + (higher[1] - lower[1]) * fraction;
            stop->g = lower[2] + (higher[2] - lower[2]) * fraction;
            stop->b = lower[3] + (higher[3] - lower[3]) * fraction;
        }
        stop->a = 1.0f;
        if (alphaCount > 0)
        {
            int alphaUpper = 0;
            while (alphaUpper < alphaCount && alphas[alphaUpper * 2] < offset)
                alphaUpper++;
            if (alphaUpper == 0 || alphaUpper == alphaCount)
                stop->a = alphas[(alphaUpper == 0 ? 0 : alphaCount - 1) * 2 + 1];
            else
            {
                const float *lower = alphas + (alphaUpper - 1) * 2;
                const float *higher = alphas + alphaUpper * 2;
                float span = higher[0] - lower[0];
                float fraction = span > 0.0f ? (offset - lower[0]) / span : 0.0f;
                stop->a = lower[1] + (higher[1] - lower[1]) * fraction;
            }
        }
    }
    return offsetCount;
}

static int TGLottieBuildGradient(const TGLottieShape *style, float frame, TGLottieGradient *gradient, TGLottieGradientStop *stops)
{
    gradient->stopCount = TGLottieGradientStops(style, frame, stops);
    if (gradient->stopCount == 0)
        return 0;
    gradient->stops = stops;
    gradient->radial = style->gradientType == 2;
    TGLottieEvaluatePoint(&style->gradientStart, frame, &gradient->startX, &gradient->startY);
    TGLottieEvaluatePoint(&style->gradientEnd, frame, &gradient->endX, &gradient->endY);
    gradient->focalX = gradient->startX;
    gradient->focalY = gradient->startY;
    if (gradient->radial)
    {
        float dx = gradient->endX - gradient->startX;
        float dy = gradient->endY - gradient->startY;
        float radius = sqrtf(dx * dx + dy * dy);
        float highlight = TGLottieClamp(TGLottieEvaluateScalar(&style->highlightLength, frame) / 100.0f, -0.99f, 0.99f);
        float angle = atan2f(dy, dx) + TGLottieEvaluateScalar(&style->highlightAngle, frame) * TGLottieDegrees;
        gradient->focalX = gradient->startX + cosf(angle) * radius * highlight;
        gradient->focalY = gradient->startY + sinf(angle) * radius * highlight;
    }
    return 1;
}

static void TGLottieBuildStrokeStyle(const TGLottieShape *style, float frame, TGLottieStrokeStyle *stroke, float *dashes)
{
    stroke->width = TGLottieEvaluateScalar(&style->width, frame);
    stroke->lineCap = style->lineCap;
    stroke->lineJoin = style->lineJoin;
    stroke->miterLimit = style->miterLimit;
    stroke->dashCount = 0;
    stroke->dashes = dashes;
    stroke->dashPhase = 0.0f;
    float total = 0.0f;
    for (int index = 0; index < style->dashCount; index++)
    {
        float value = TGLottieEvaluateScalar(&style->dashes[index].value, frame);
        if (style->dashes[index].type == 2)
            stroke->dashPhase = value;
        else if (stroke->dashCount < TGLottieMaxDashes)
        {
            dashes[stroke->dashCount++] = value < 0.0f ? 0.0f : value;
            total += value;
        }
    }
    if (stroke->dashCount % 2 == 1 && stroke->dashCount < TGLottieMaxDashes)
    {
        dashes[stroke->dashCount] = dashes[stroke->dashCount - 1];
        stroke->dashCount++;
    }
    if (total <= 0.0f)
        stroke->dashCount = 0;
}

static void TGLottiePaintOperation(TGLottieRenderContext *context, const TGLottieDrawOperation *operation, float frame)
{
    const TGLottieRenderer *renderer = context->renderer;
    const TGLottieShape *style = operation->style;
    float opacity = operation->opacity * TGLottieClamp(TGLottieEvaluateScalar(&style->opacity, frame) / 100.0f, 0.0f, 1.0f);
    if (opacity <= 0.0f)
        return;
    int isStroke = style->type == TGLottieShapeStroke || style->type == TGLottieShapeGradientStroke;
    TGLottiePathBuffer buffer;
    memset(&buffer, 0, sizeof(buffer));
    TGLottieAffine inverse = TGLottieAffineIdentity();
    if (isStroke && !TGLottieAffineInvert(operation->transform, &inverse))
        return;
    for (int index = 0; index < operation->entries.count; index++)
    {
        const TGLottiePathEntry *entry = operation->entries.entries[index];
        TGLottieAffine matrix = isStroke ? TGLottieAffineMultiply(inverse, entry->transform) : entry->transform;
        TGLottiePathBufferAppendEntry(context, &buffer, entry, &matrix);
    }
    if (buffer.commandCount == 0 || context->failed)
        return;
    TGLottiePath path = TGLottiePathFromBuffer(&buffer);
    switch (style->type)
    {
        case TGLottieShapeFill:
        {
            float color[TGLottieMaxPropertyDimension] = { 1.0f, 1.0f, 1.0f, 1.0f };
            TGLottieEvaluate(&style->color, frame, color, TGLottieMaxPropertyDimension);
            if (renderer->fillColor != NULL)
                renderer->fillColor(renderer->context, &path, style->evenOdd, TGLottieClamp(color[0], 0.0f, 1.0f), TGLottieClamp(color[1], 0.0f, 1.0f), TGLottieClamp(color[2], 0.0f, 1.0f), opacity);
            break;
        }
        case TGLottieShapeStroke:
        {
            float color[TGLottieMaxPropertyDimension] = { 1.0f, 1.0f, 1.0f, 1.0f };
            TGLottieEvaluate(&style->color, frame, color, TGLottieMaxPropertyDimension);
            float dashes[TGLottieMaxDashes];
            TGLottieStrokeStyle stroke;
            TGLottieBuildStrokeStyle(style, frame, &stroke, dashes);
            if (stroke.width > 0.0f && renderer->strokeColor != NULL)
                renderer->strokeColor(renderer->context, &path, &operation->transform, &stroke, TGLottieClamp(color[0], 0.0f, 1.0f), TGLottieClamp(color[1], 0.0f, 1.0f), TGLottieClamp(color[2], 0.0f, 1.0f), opacity);
            break;
        }
        case TGLottieShapeGradientFill:
        {
            TGLottieGradientStop stops[TGLottieMaxGradientStops];
            TGLottieGradient gradient;
            if (TGLottieBuildGradient(style, frame, &gradient, stops) && renderer->fillGradient != NULL)
                renderer->fillGradient(renderer->context, &path, style->evenOdd, &gradient, &operation->transform, opacity);
            break;
        }
        case TGLottieShapeGradientStroke:
        {
            TGLottieGradientStop stops[TGLottieMaxGradientStops];
            TGLottieGradient gradient;
            float dashes[TGLottieMaxDashes];
            TGLottieStrokeStyle stroke;
            TGLottieBuildStrokeStyle(style, frame, &stroke, dashes);
            if (stroke.width > 0.0f && TGLottieBuildGradient(style, frame, &gradient, stops) && renderer->strokeGradient != NULL)
                renderer->strokeGradient(renderer->context, &path, &operation->transform, &stroke, &gradient, opacity);
            break;
        }
        default:
            break;
    }
}

static void TGLottieRenderShapeLayer(TGLottieRenderContext *context, const TGLottieLayer *layer, float frame, TGLottieAffine matrix, float opacity)
{
    TGLottieEntryList entries;
    memset(&entries, 0, sizeof(entries));
    TGLottieOperationList operations;
    memset(&operations, 0, sizeof(operations));
    TGLottieEvaluateGroup(context, layer->shapes, layer->shapeCount, frame, matrix, opacity, &entries, &operations);
    for (int index = operations.count - 1; index >= 0 && !context->failed; index--)
        TGLottiePaintOperation(context, &operations.operations[index], frame);
}

static int TGLottieMaskPath(TGLottieRenderContext *context, const TGLottieLayer *layer, float frame, TGLottieAffine matrix, TGLottiePath *output, int *evenOdd)
{
    TGLottiePathBuffer buffer;
    memset(&buffer, 0, sizeof(buffer));
    int hasSubtract = 0;
    int hasAdd = 0;
    for (int index = 0; index < layer->maskCount; index++)
    {
        const TGLottieMask *mask = &layer->masks[index];
        if (mask->mode == 's' || mask->inverted)
            hasSubtract = 1;
        else
            hasAdd = 1;
    }
    if (hasSubtract && !hasAdd)
    {
        if (!TGLottiePathBufferReserve(context, &buffer, 6, 10))
            return 0;
        float corners[4][2] = { { -100000.0f, -100000.0f }, { 100000.0f, -100000.0f }, { 100000.0f, 100000.0f }, { -100000.0f, 100000.0f } };
        buffer.commands[buffer.commandCount++] = TGLottiePathMove;
        buffer.points[buffer.pointCount++] = corners[0][0];
        buffer.points[buffer.pointCount++] = corners[0][1];
        for (int corner = 1; corner < 4; corner++)
        {
            buffer.commands[buffer.commandCount++] = TGLottiePathLine;
            buffer.points[buffer.pointCount++] = corners[corner][0];
            buffer.points[buffer.pointCount++] = corners[corner][1];
        }
        buffer.commands[buffer.commandCount++] = TGLottiePathClose;
    }
    for (int index = 0; index < layer->maskCount; index++)
    {
        const TGLottieMask *mask = &layer->masks[index];
        TGLottieBezier bezier = TGLottieEvaluatePath(context, &mask->path, frame);
        TGLottiePathEntry entry;
        TGLottieContour contour;
        TGLottieContourFromBezier(context, &bezier, &contour);
        contour.closed = 1;
        entry.contourCount = 1;
        entry.contours = &contour;
        entry.transform = matrix;
        TGLottiePathBufferAppendEntry(context, &buffer, &entry, &matrix);
    }
    if (buffer.commandCount == 0)
        return 0;
    *output = TGLottiePathFromBuffer(&buffer);
    *evenOdd = hasSubtract;
    return 1;
}

static void TGLottieRenderComposition(TGLottieRenderContext *context, const TGLottieComposition *composition, float frame, TGLottieAffine rootMatrix, float opacity, int depth);

static void TGLottieRenderLayer(TGLottieRenderContext *context, const TGLottieLayer *layer, float frame, TGLottieAffine rootMatrix, float opacity, int depth)
{
    if (layer->hidden || layer->isMatteSource || layer->type == TGLottieLayerNull)
        return;
    if (frame < layer->inPoint || frame >= layer->outPoint)
        return;
    float layerOpacity = 1.0f;
    TGLottieAffine matrix = TGLottieAffineMultiply(rootMatrix, TGLottieLayerMatrix(layer, frame, &layerOpacity));
    layerOpacity *= opacity;
    if (layerOpacity <= 0.0f)
        return;
    float localFrame = TGLottieLayerFrame(layer, frame);
    const TGLottieRenderer *renderer = context->renderer;
    TGLottiePath maskPath;
    int maskEvenOdd = 0;
    int masked = layer->maskCount > 0 && renderer->beginGroup != NULL && TGLottieMaskPath(context, layer, localFrame, matrix, &maskPath, &maskEvenOdd);
    if (masked)
        renderer->beginGroup(renderer->context, 1.0f, &maskPath, maskEvenOdd);
    switch (layer->type)
    {
        case TGLottieLayerShape:
            TGLottieRenderShapeLayer(context, layer, localFrame, matrix, layerOpacity);
            break;
        case TGLottieLayerPrecomp:
        {
            if (layer->precomp == NULL || depth >= TGLottieMaxPrecompDepth)
                break;
            int grouped = renderer->beginGroup != NULL;
            float childOpacity = grouped ? 1.0f : layerOpacity;
            if (grouped)
            {
                TGLottiePathBuffer buffer;
                memset(&buffer, 0, sizeof(buffer));
                TGLottiePath clipPath;
                const TGLottiePath *clip = NULL;
                if (layer->width > 0.0f && layer->height > 0.0f)
                {
                    TGLottiePathEntry entry;
                    TGLottieContour contour;
                    TGLottieRectContour(context, layer->width * 0.5f, layer->height * 0.5f, layer->width, layer->height, 0.0f, 0, &contour);
                    entry.contourCount = 1;
                    entry.contours = &contour;
                    entry.transform = matrix;
                    TGLottiePathBufferAppendEntry(context, &buffer, &entry, &matrix);
                    if (buffer.commandCount != 0)
                    {
                        clipPath = TGLottiePathFromBuffer(&buffer);
                        clip = &clipPath;
                    }
                }
                renderer->beginGroup(renderer->context, layerOpacity, clip, 0);
            }
            TGLottieRenderComposition(context, layer->precomp, localFrame, matrix, childOpacity, depth + 1);
            if (grouped)
                renderer->endGroup(renderer->context);
            break;
        }
        case TGLottieLayerSolid:
        {
            if (layer->width <= 0.0f || layer->height <= 0.0f || renderer->fillColor == NULL)
                break;
            TGLottiePathBuffer buffer;
            memset(&buffer, 0, sizeof(buffer));
            TGLottiePathEntry entry;
            TGLottieContour contour;
            TGLottieRectContour(context, layer->width * 0.5f, layer->height * 0.5f, layer->width, layer->height, 0.0f, 0, &contour);
            entry.contourCount = 1;
            entry.contours = &contour;
            entry.transform = matrix;
            TGLottiePathBufferAppendEntry(context, &buffer, &entry, &matrix);
            if (buffer.commandCount != 0)
            {
                TGLottiePath path = TGLottiePathFromBuffer(&buffer);
                renderer->fillColor(renderer->context, &path, 0, layer->solidColor[0], layer->solidColor[1], layer->solidColor[2], layerOpacity);
            }
            break;
        }
        default:
            break;
    }
    if (masked)
        renderer->endGroup(renderer->context);
}

static void TGLottieRenderComposition(TGLottieRenderContext *context, const TGLottieComposition *composition, float frame, TGLottieAffine rootMatrix, float opacity, int depth)
{
    for (int index = composition->layerCount - 1; index >= 0 && !context->failed; index--)
        TGLottieRenderLayer(context, &composition->layers[index], frame, rootMatrix, opacity, depth);
}

TGLottieRenderContext *TGLottieRenderContextCreate(void)
{
    TGLottieRenderContext *context = (TGLottieRenderContext *)calloc(1, sizeof(TGLottieRenderContext));
    if (context != NULL)
        TGLottieArenaInit(&context->arena, 128 * 1024, 16 * 1024 * 1024);
    return context;
}

void TGLottieRenderContextDestroy(TGLottieRenderContext *context)
{
    if (context == NULL)
        return;
    TGLottieArenaDestroy(&context->arena);
    free(context);
}

void TGLottieRender(TGLottieRenderContext *context, const TGLottieAnimation *animation, float frame, TGLottieAffine rootTransform, const TGLottieRenderer *renderer)
{
    if (context == NULL || animation == NULL || renderer == NULL)
        return;
    TGLottieArenaReset(&context->arena);
    context->renderer = renderer;
    context->failed = 0;
    if (frame < animation->inPoint)
        frame = animation->inPoint;
    if (frame >= animation->outPoint)
        frame = animation->outPoint - 1.0f;
    TGLottieRenderComposition(context, &animation->root, frame, rootTransform, 1.0f, 0);
}
