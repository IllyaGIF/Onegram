#include "OGVideoColor.h"

#include <stdlib.h>

typedef struct
{
    uint16_t lumaX0;
    uint16_t lumaX1;
    uint16_t chromaX0;
    uint16_t chromaX1;
    uint16_t lumaFraction;
    uint16_t chromaFraction;
} OGVideoColumn;

static inline int OGClamp(int value)
{
    return value < 0 ? 0 : (value > 255 ? 255 : value);
}

static inline unsigned int OGPremultiply(unsigned int value, unsigned int alpha)
{
    unsigned int product = value * alpha + 128;
    return (product + (product >> 8)) >> 8;
}

static inline void OGVideoAxis(unsigned int position, unsigned int size, uint16_t *first, uint16_t *second, uint16_t *fraction)
{
    unsigned int index = position >> 8;
    if (index >= size)
        index = size - 1;
    *first = (uint16_t)index;
    *second = (uint16_t)(index + 1 < size ? index + 1 : index);
    *fraction = (uint16_t)(position & 255);
}

static inline unsigned int OGVideoBlend(const uint8_t *row0, const uint8_t *row1, unsigned int x0, unsigned int x1, unsigned int fx, unsigned int fy)
{
    unsigned int top = row0[x0] * (256 - fx) + row0[x1] * fx;
    unsigned int bottom = row1[x0] * (256 - fx) + row1[x1] * fx;
    return (top * (256 - fy) + bottom * fy + 32768) >> 16;
}

int OGVideoConvertBGRA(const OGVideoI420 *color, const OGVideoI420 *alpha, uint8_t *output, unsigned int width, unsigned int height)
{
    if (color == 0 || output == 0 || width == 0 || height == 0 || width > 1024 || height > 1024 || color->width == 0 || color->height == 0 || color->width > 1024 || color->height > 1024)
        return 0;
    unsigned int uvWidth = (color->width + 1) / 2;
    for (int i = 0; i < 3; i++)
    {
        if (color->planes[i] == 0 || color->strides[i] < (int)(i == 0 ? color->width : uvWidth))
            return 0;
    }
    if (alpha != 0 && (alpha->planes[0] == 0 || alpha->strides[0] < (int)color->width || alpha->width != color->width || alpha->height != color->height))
        return 0;
    unsigned int uvHeight = (color->height + 1) / 2;
    OGVideoColumn *columns = malloc(width * sizeof(OGVideoColumn));
    if (columns == 0)
        return 0;
    unsigned int stepX = (color->width << 8) / width;
    unsigned int remainderX = (color->width << 8) % width;
    unsigned int positionX = 0;
    unsigned int errorX = 0;
    for (unsigned int x = 0; x < width; x++)
    {
        OGVideoAxis(positionX, color->width, &columns[x].lumaX0, &columns[x].lumaX1, &columns[x].lumaFraction);
        OGVideoAxis(positionX / 2, uvWidth, &columns[x].chromaX0, &columns[x].chromaX1, &columns[x].chromaFraction);
        positionX += stepX;
        errorX += remainderX;
        if (errorX >= width)
        {
            errorX -= width;
            positionX++;
        }
    }
    const uint8_t *lumaPlane = color->planes[0];
    const uint8_t *uPlane = color->planes[1];
    const uint8_t *vPlane = color->planes[2];
    const uint8_t *alphaPlane = alpha != 0 ? alpha->planes[0] : 0;
    unsigned int stepY = (color->height << 8) / height;
    unsigned int remainderY = (color->height << 8) % height;
    unsigned int positionY = 0;
    unsigned int errorY = 0;
    for (unsigned int y = 0; y < height; y++)
    {
        uint16_t lumaY0, lumaY1, lumaFraction, chromaY0, chromaY1, chromaFraction;
        OGVideoAxis(positionY, color->height, &lumaY0, &lumaY1, &lumaFraction);
        OGVideoAxis(positionY / 2, uvHeight, &chromaY0, &chromaY1, &chromaFraction);
        positionY += stepY;
        errorY += remainderY;
        if (errorY >= height)
        {
            errorY -= height;
            positionY++;
        }
        const uint8_t *luma0 = lumaPlane + (size_t)lumaY0 * color->strides[0];
        const uint8_t *luma1 = lumaPlane + (size_t)lumaY1 * color->strides[0];
        const uint8_t *u0 = uPlane + (size_t)chromaY0 * color->strides[1];
        const uint8_t *u1 = uPlane + (size_t)chromaY1 * color->strides[1];
        const uint8_t *v0 = vPlane + (size_t)chromaY0 * color->strides[2];
        const uint8_t *v1 = vPlane + (size_t)chromaY1 * color->strides[2];
        const uint8_t *alpha0 = alphaPlane != 0 ? alphaPlane + (size_t)lumaY0 * alpha->strides[0] : 0;
        const uint8_t *alpha1 = alphaPlane != 0 ? alphaPlane + (size_t)lumaY1 * alpha->strides[0] : 0;
        uint8_t *row = output + (size_t)y * width * 4;
        for (unsigned int x = 0; x < width; x++)
        {
            const OGVideoColumn *column = &columns[x];
            int c = (int)OGVideoBlend(luma0, luma1, column->lumaX0, column->lumaX1, column->lumaFraction, lumaFraction) - 16;
            int u = (int)OGVideoBlend(u0, u1, column->chromaX0, column->chromaX1, column->chromaFraction, chromaFraction) - 128;
            int v = (int)OGVideoBlend(v0, v1, column->chromaX0, column->chromaX1, column->chromaFraction, chromaFraction) - 128;
            if (c < 0)
                c = 0;
            int luminance = 298 * c + 128;
            unsigned int r = (unsigned int)OGClamp((luminance + 409 * v) >> 8);
            unsigned int g = (unsigned int)OGClamp((luminance - 100 * u - 208 * v) >> 8);
            unsigned int b = (unsigned int)OGClamp((luminance + 516 * u) >> 8);
            uint8_t *pixel = row + x * 4;
            if (alpha0 != 0)
            {
                unsigned int a = OGVideoBlend(alpha0, alpha1, column->lumaX0, column->lumaX1, column->lumaFraction, lumaFraction);
                pixel[0] = (uint8_t)OGPremultiply(b, a);
                pixel[1] = (uint8_t)OGPremultiply(g, a);
                pixel[2] = (uint8_t)OGPremultiply(r, a);
                pixel[3] = (uint8_t)a;
            }
            else
            {
                pixel[0] = (uint8_t)b;
                pixel[1] = (uint8_t)g;
                pixel[2] = (uint8_t)r;
                pixel[3] = 255;
            }
        }
    }
    free(columns);
    return 1;
}
