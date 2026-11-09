#ifndef TGLottieCore_h
#define TGLottieCore_h

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct TGLottieAnimation TGLottieAnimation;
typedef struct TGLottieRenderContext TGLottieRenderContext;

typedef struct
{
    float a, b, c, d, tx, ty;
} TGLottieAffine;

typedef enum
{
    TGLottiePathMove = 0,
    TGLottiePathLine = 1,
    TGLottiePathCubic = 2,
    TGLottiePathClose = 3
} TGLottiePathCommand;

typedef struct
{
    int commandCount;
    const uint8_t *commands;
    const float *points;
} TGLottiePath;

typedef struct
{
    float offset;
    float r, g, b, a;
} TGLottieGradientStop;

typedef struct
{
    int radial;
    float startX, startY;
    float endX, endY;
    float focalX, focalY;
    int stopCount;
    const TGLottieGradientStop *stops;
} TGLottieGradient;

typedef struct
{
    float width;
    int lineCap;
    int lineJoin;
    float miterLimit;
    int dashCount;
    const float *dashes;
    float dashPhase;
} TGLottieStrokeStyle;

typedef struct
{
    void *context;
    void (*fillColor)(void *context, const TGLottiePath *path, int evenOdd, float r, float g, float b, float a);
    void (*fillGradient)(void *context, const TGLottiePath *path, int evenOdd, const TGLottieGradient *gradient, const TGLottieAffine *gradientTransform, float alpha);
    void (*strokeColor)(void *context, const TGLottiePath *path, const TGLottieAffine *pathTransform, const TGLottieStrokeStyle *style, float r, float g, float b, float a);
    void (*strokeGradient)(void *context, const TGLottiePath *path, const TGLottieAffine *pathTransform, const TGLottieStrokeStyle *style, const TGLottieGradient *gradient, float alpha);
    void (*beginGroup)(void *context, float opacity, const TGLottiePath *clipPath, int clipEvenOdd);
    void (*endGroup)(void *context);
} TGLottieRenderer;

TGLottieAnimation *TGLottieAnimationCreate(const void *data, size_t length);
void TGLottieAnimationDestroy(TGLottieAnimation *animation);
float TGLottieAnimationWidth(const TGLottieAnimation *animation);
float TGLottieAnimationHeight(const TGLottieAnimation *animation);
float TGLottieAnimationFrameRate(const TGLottieAnimation *animation);
float TGLottieAnimationStartFrame(const TGLottieAnimation *animation);
float TGLottieAnimationEndFrame(const TGLottieAnimation *animation);

TGLottieRenderContext *TGLottieRenderContextCreate(void);
void TGLottieRenderContextDestroy(TGLottieRenderContext *context);
void TGLottieRender(TGLottieRenderContext *context, const TGLottieAnimation *animation, float frame, TGLottieAffine rootTransform, const TGLottieRenderer *renderer);

#ifdef __cplusplus
}
#endif

#endif
