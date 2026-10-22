#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <OpenGLES/ES2/gl.h>
#import <UIKit/UIKit.h>

void TGPaintHasGLError_(const char *file, int line);
#define TGPaintHasGLError() TGPaintHasGLError_(__FILE__, __LINE__)

void TGSetupColorUniform(GLint location, UIColor *color);

bool TGPaintVertexArrayObjectsSupported(void);

UIImage *TGPaintCombineImages(UIImage *background, UIImage *foreground, bool opaque);
UIImage *TGPaintCombineCroppedImages(UIImage *background, UIImage *foreground, bool opaque, CGSize originalSize, CGRect cropRect, UIImageOrientation cropOrientation, CGFloat rotation, bool mirrored);

NSData *TGPaintGZipInflate(NSData *data);
NSData *TGPaintGZipDeflate(NSData *data);

static inline CGPoint TGPaintAddPoints(CGPoint a, CGPoint b)
{
    return CGPointMake(a.x + b.x, a.y + b.y);
}

static inline CGPoint TGPaintSubtractPoints(CGPoint a, CGPoint b)
{
    return CGPointMake(a.x - b.x, a.y - b.y);
}

static inline CGPoint TGPaintMultiplyPoint(CGPoint p, CGFloat s)
{
    return CGPointMake(p.x * s, p.y * s);
}

static inline CGFloat TGPaintDistance(CGPoint a, CGPoint b)
{
    CGFloat xd = (a.x - b.x);
    CGFloat yd = (a.y - b.y);
    
    return (CGFloat)(sqrt(xd * xd + yd * yd));
}

static inline CGPoint TGPaintCenterOfRect(CGRect rect)
{
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

static inline CGRect TGPaintUnionRect(CGRect a, CGRect b)
{
    if (CGRectEqualToRect(a, CGRectZero))
        return b;
    else if (CGRectEqualToRect(b, CGRectZero))
        return a;
    
    return CGRectUnion(a, b);
}

static inline CGRect TGPaintMultiplyRectScalar(CGRect rect, CGFloat scale)
{
    return CGRectMake(rect.origin.x * scale, rect.origin.y * scale, rect.size.width * scale, rect.size.height * scale);
}

static inline CGSize TGPaintMultiplySizeScalar(CGSize size, CGFloat scale)
{
    return CGSizeMake(size.width * scale, size.height * scale);
}

static inline CGFloat TGPaintSineCurve(CGFloat input)
{
    input *= M_PI;
    input -= M_PI_2;
    
    CGFloat result = CGSin(input) + 1.0f;
    result /= 2.0f;
    
    return result;
}
