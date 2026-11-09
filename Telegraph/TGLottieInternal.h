#ifndef TGLottieInternal_h
#define TGLottieInternal_h

#include <stddef.h>
#include <stdint.h>

#include "TGLottieCore.h"

typedef struct TGLottieArenaChunk TGLottieArenaChunk;

typedef struct
{
    TGLottieArenaChunk *chunks;
    size_t chunkSize;
    size_t allocated;
    size_t limit;
} TGLottieArena;

void TGLottieArenaInit(TGLottieArena *arena, size_t chunkSize, size_t limit);
void *TGLottieArenaAlloc(TGLottieArena *arena, size_t size);
void *TGLottieArenaAllocZeroed(TGLottieArena *arena, size_t size);
void TGLottieArenaReset(TGLottieArena *arena);
void TGLottieArenaDestroy(TGLottieArena *arena);

typedef enum
{
    TGLottieJSONNull = 0,
    TGLottieJSONBool,
    TGLottieJSONNumber,
    TGLottieJSONString,
    TGLottieJSONArray,
    TGLottieJSONObject
} TGLottieJSONType;

typedef struct TGLottieJSON TGLottieJSON;

struct TGLottieJSON
{
    TGLottieJSONType type;
    int count;
    double number;
    const char *string;
    const char **keys;
    TGLottieJSON **items;
};

TGLottieJSON *TGLottieJSONParse(TGLottieArena *arena, const char *text, size_t length);
const TGLottieJSON *TGLottieJSONMember(const TGLottieJSON *object, const char *key);
double TGLottieJSONNumberValue(const TGLottieJSON *value, double fallback);
int TGLottieJSONIntMember(const TGLottieJSON *object, const char *key, int fallback);
double TGLottieJSONNumberMember(const TGLottieJSON *object, const char *key, double fallback);
const char *TGLottieJSONStringMember(const TGLottieJSON *object, const char *key);
int TGLottieJSONBoolMember(const TGLottieJSON *object, const char *key, int fallback);

TGLottieAffine TGLottieAffineIdentity(void);
TGLottieAffine TGLottieAffineMultiply(TGLottieAffine left, TGLottieAffine right);
int TGLottieAffineInvert(TGLottieAffine matrix, TGLottieAffine *result);
void TGLottieAffineApply(const TGLottieAffine *matrix, float x, float y, float *outX, float *outY);

typedef struct
{
    float t;
    float *start;
    float *end;
    int easingCount;
    float outX[4];
    float outY[4];
    float inX[4];
    float inY[4];
    int hold;
    int spatial;
    float spatialOut[2];
    float spatialIn[2];
    float *arcLengths;
} TGLottieKeyframe;

typedef struct
{
    int dimension;
    int keyframeCount;
    float *value;
    TGLottieKeyframe *keyframes;
} TGLottieProperty;

typedef struct
{
    int count;
    int closed;
    float *points;
} TGLottieBezier;

typedef struct
{
    float t;
    TGLottieBezier start;
    TGLottieBezier end;
    float outX, outY, inX, inY;
    int hold;
} TGLottiePathKeyframe;

typedef struct
{
    int keyframeCount;
    TGLottieBezier value;
    TGLottiePathKeyframe *keyframes;
} TGLottiePathProperty;

typedef struct
{
    TGLottieProperty anchor;
    TGLottieProperty position;
    TGLottieProperty positionX;
    TGLottieProperty positionY;
    int splitPosition;
    TGLottieProperty scale;
    TGLottieProperty rotation;
    TGLottieProperty opacity;
    TGLottieProperty skew;
    TGLottieProperty skewAxis;
} TGLottieTransform;

typedef enum
{
    TGLottieShapeUnknown = 0,
    TGLottieShapeGroup,
    TGLottieShapePath,
    TGLottieShapeEllipse,
    TGLottieShapeRect,
    TGLottieShapeStar,
    TGLottieShapeFill,
    TGLottieShapeStroke,
    TGLottieShapeGradientFill,
    TGLottieShapeGradientStroke,
    TGLottieShapeTrim,
    TGLottieShapeTransform
} TGLottieShapeType;

typedef struct
{
    int type;
    TGLottieProperty value;
} TGLottieDash;

typedef struct TGLottieShape TGLottieShape;

struct TGLottieShape
{
    TGLottieShapeType type;
    int hidden;
    int reversed;

    int itemCount;
    TGLottieShape *items;
    TGLottieTransform transform;
    int hasTransform;

    TGLottiePathProperty path;
    TGLottieProperty position;
    TGLottieProperty size;
    TGLottieProperty roundness;

    int starType;
    TGLottieProperty points;
    TGLottieProperty rotation;
    TGLottieProperty innerRadius;
    TGLottieProperty outerRadius;
    TGLottieProperty innerRoundness;
    TGLottieProperty outerRoundness;

    TGLottieProperty color;
    TGLottieProperty opacity;
    int evenOdd;
    TGLottieProperty width;
    int lineCap;
    int lineJoin;
    float miterLimit;
    int dashCount;
    TGLottieDash *dashes;

    int gradientType;
    int gradientStopCount;
    TGLottieProperty gradientColors;
    TGLottieProperty gradientStart;
    TGLottieProperty gradientEnd;
    TGLottieProperty highlightLength;
    TGLottieProperty highlightAngle;

    TGLottieProperty trimStart;
    TGLottieProperty trimEnd;
    TGLottieProperty trimOffset;
    int trimIndividually;
};

typedef enum
{
    TGLottieLayerPrecomp = 0,
    TGLottieLayerSolid = 1,
    TGLottieLayerImage = 2,
    TGLottieLayerNull = 3,
    TGLottieLayerShape = 4,
    TGLottieLayerText = 5
} TGLottieLayerType;

typedef struct TGLottieComposition TGLottieComposition;
typedef struct TGLottieLayer TGLottieLayer;

typedef struct
{
    int mode;
    int inverted;
    TGLottiePathProperty path;
    TGLottieProperty opacity;
} TGLottieMask;

struct TGLottieLayer
{
    TGLottieLayerType type;
    int index;
    int parentIndex;
    TGLottieLayer *parent;
    int hidden;
    int isMatteSource;
    int matteMode;
    float inPoint;
    float outPoint;
    float startTime;
    float timeStretch;
    TGLottieTransform transform;
    int shapeCount;
    TGLottieShape *shapes;
    const char *referenceId;
    TGLottieComposition *precomp;
    float width;
    float height;
    float solidColor[4];
    int maskCount;
    TGLottieMask *masks;
};

struct TGLottieComposition
{
    const char *identifier;
    int layerCount;
    TGLottieLayer *layers;
};

struct TGLottieAnimation
{
    TGLottieArena arena;
    float width;
    float height;
    float frameRate;
    float inPoint;
    float outPoint;
    TGLottieComposition root;
    int assetCount;
    TGLottieComposition *assets;
};

#endif
