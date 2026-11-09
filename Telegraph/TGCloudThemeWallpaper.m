#import "TGCloudThemeWallpaper.h"
#import <zlib.h>
#import <math.h>
#import <stdlib.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageUtils.h"

@interface TGGradientWallpaperInfo ()
{
    int64_t _wallpaperId;
    NSArray *_colors;
    int32_t _rotation;
    UIImage *_thumbnailImage;
}

@end

@implementation TGGradientWallpaperInfo

- (instancetype)initWithWallpaperId:(int64_t)wallpaperId colors:(NSArray *)colors rotation:(int32_t)rotation
{
    self = [super init];
    if (self != nil)
    {
        _wallpaperId = wallpaperId;
        _colors = [colors copy];
        _rotation = rotation;
    }
    return self;
}

- (UIImage *)thumbnailImage
{
    if (_thumbnailImage == nil)
        _thumbnailImage = TGCloudThemeWallpaperImage(_colors, _rotation, nil, 0, CGSizeMake(120.0f, 200.0f));
    return _thumbnailImage;
}

- (UIImage *)image
{
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    return TGCloudThemeWallpaperImage(_colors, _rotation, nil, 0, CGSizeMake(MIN(screenSize.width, screenSize.height), MAX(screenSize.width, screenSize.height)));
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[TGGradientWallpaperInfo class]])
        return false;
    TGGradientWallpaperInfo *other = object;
    return _wallpaperId == other->_wallpaperId && _rotation == other->_rotation && [_colors isEqualToArray:other->_colors];
}

- (NSUInteger)hash
{
    return (NSUInteger)_wallpaperId ^ (NSUInteger)(_wallpaperId >> 32) ^ (NSUInteger)_rotation ^ [_colors hash];
}

- (NSDictionary *)infoDictionary
{
    return @{ @"_className": NSStringFromClass([self class]), @"wallpaperId": @(_wallpaperId), @"colors": _colors, @"rotation": @(_rotation) };
}

+ (TGWallpaperInfo *)infoWithDictionary:(NSDictionary *)dict
{
    NSArray *colors = dict[@"colors"];
    if (![colors isKindOfClass:[NSArray class]] || colors.count < 2 || colors.count > 4)
        return nil;
    return [[TGGradientWallpaperInfo alloc] initWithWallpaperId:[dict[@"wallpaperId"] longLongValue] colors:colors rotation:[dict[@"rotation"] intValue]];
}

@end

typedef struct {
    CGFloat r;
    CGFloat g;
    CGFloat b;
} TGCloudThemeRGB;

typedef struct {
    CGAffineTransform transform;
    CGFloat alpha;
    bool fill;
    bool stroke;
    bool evenOdd;
    bool hidden;
    CGFloat strokeWidth;
} TGCloudThemeSvgStyle;

static TGCloudThemeRGB TGCloudThemeRGBFromHex(uint32_t rgb)
{
    TGCloudThemeRGB color;
    color.r = ((rgb >> 16) & 0xff) / 255.0f;
    color.g = ((rgb >> 8) & 0xff) / 255.0f;
    color.b = (rgb & 0xff) / 255.0f;
    return color;
}

static CGContextRef TGCloudThemeCreateContext(size_t width, size_t height)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return NULL;
    CGContextTranslateCTM(context, 0.0f, (CGFloat)height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    return context;
}

static CGImageRef TGCloudThemeCreateFreeformGradient(NSArray *colors)
{
    static const CGFloat positions[4][2] = {{0.80f, 0.10f}, {0.35f, 0.25f}, {0.20f, 0.90f}, {0.65f, 0.75f}};
    const size_t width = 48;
    const size_t height = 64;
    NSUInteger count = MIN((NSUInteger)4, colors.count);
    TGCloudThemeRGB rgb[4];
    for (NSUInteger i = 0; i < count; i++)
        rgb[i] = TGCloudThemeRGBFromHex([colors[i] unsignedIntValue]);

    CGContextRef context = TGCloudThemeCreateContext(width, height);
    if (context == NULL)
        return NULL;
    uint8_t *pixels = CGBitmapContextGetData(context);
    size_t bytesPerRow = CGBitmapContextGetBytesPerRow(context);
    for (size_t y = 0; y < height; y++)
    {
        CGFloat centerDistanceY = (CGFloat)y / (CGFloat)height - 0.5f;
        for (size_t x = 0; x < width; x++)
        {
            CGFloat centerDistanceX = (CGFloat)x / (CGFloat)width - 0.5f;
            CGFloat centerDistance = sqrt(centerDistanceX * centerDistanceX + centerDistanceY * centerDistanceY);
            CGFloat swirl = 0.35f * centerDistance;
            CGFloat theta = swirl * swirl * 0.8f * 8.0f;
            CGFloat sinTheta = sin(theta);
            CGFloat cosTheta = cos(theta);
            CGFloat pixelX = MAX(0.0f, MIN(1.0f, 0.5f + centerDistanceX * cosTheta - centerDistanceY * sinTheta));
            CGFloat pixelY = MAX(0.0f, MIN(1.0f, 0.5f + centerDistanceX * sinTheta + centerDistanceY * cosTheta));
            CGFloat sum = 0.0f, r = 0.0f, g = 0.0f, b = 0.0f;
            for (NSUInteger i = 0; i < count; i++)
            {
                CGFloat dx = pixelX - positions[i][0];
                CGFloat dy = pixelY - positions[i][1];
                CGFloat distance = MAX(0.0f, 0.9f - sqrt(dx * dx + dy * dy));
                distance = distance * distance * distance * distance;
                sum += distance;
                r += distance * rgb[i].r;
                g += distance * rgb[i].g;
                b += distance * rgb[i].b;
            }
            if (sum <= 0.0f)
                sum = 1.0f;
            uint8_t *pixel = pixels + y * bytesPerRow + x * 4;
            pixel[0] = (uint8_t)(MIN(1.0f, b / sum) * 255.0f);
            pixel[1] = (uint8_t)(MIN(1.0f, g / sum) * 255.0f);
            pixel[2] = (uint8_t)(MIN(1.0f, r / sum) * 255.0f);
            pixel[3] = 255;
        }
    }
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}

static void TGCloudThemeDrawBackground(CGContextRef context, CGRect rect, NSArray *colors, int32_t rotation)
{
    if (colors.count == 0)
        return;
    if (colors.count == 1)
    {
        CGContextSetFillColorWithColor(context, UIColorRGB([colors[0] unsignedIntValue]).CGColor);
        CGContextFillRect(context, rect);
        return;
    }
    if (colors.count == 2)
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        TGCloudThemeRGB top = TGCloudThemeRGBFromHex([colors[0] unsignedIntValue]);
        TGCloudThemeRGB bottom = TGCloudThemeRGBFromHex([colors[1] unsignedIntValue]);
        CGFloat components[8] = {top.r, top.g, top.b, 1.0f, bottom.r, bottom.g, bottom.b, 1.0f};
        CGFloat locations[2] = {0.0f, 1.0f};
        CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
        CGColorSpaceRelease(colorSpace);
        CGFloat angle = (CGFloat)(rotation % 360) * (CGFloat)M_PI / 180.0f;
        CGPoint direction = CGPointMake(-sin(angle), cos(angle));
        CGFloat length = (fabs(direction.x) * rect.size.width + fabs(direction.y) * rect.size.height) / 2.0f;
        CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
        CGContextSaveGState(context);
        CGContextClipToRect(context, rect);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(center.x - direction.x * length, center.y - direction.y * length), CGPointMake(center.x + direction.x * length, center.y + direction.y * length), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CGContextRestoreGState(context);
        CGGradientRelease(gradient);
        return;
    }
    CGImageRef gradientImage = TGCloudThemeCreateFreeformGradient(colors);
    if (gradientImage == NULL)
        return;
    CGContextSaveGState(context);
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y + rect.size.height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, rect.size.width, rect.size.height), gradientImage);
    CGContextRestoreGState(context);
    CGImageRelease(gradientImage);
}

static NSData *TGCloudThemeInflate(NSData *data)
{
    const uint8_t *bytes = data.bytes;
    if (data.length < 2 || bytes[0] != 0x1f || bytes[1] != 0x8b)
        return data;
    z_stream stream;
    memset(&stream, 0, sizeof(stream));
    stream.next_in = (Bytef *)bytes;
    stream.avail_in = (uInt)data.length;
    if (inflateInit2(&stream, 15 + 32) != Z_OK)
        return nil;
    NSMutableData *result = [[NSMutableData alloc] initWithLength:MAX((NSUInteger)65536, data.length * 6)];
    int status = Z_OK;
    while (status == Z_OK)
    {
        if (stream.total_out >= result.length)
            [result increaseLengthBy:result.length];
        stream.next_out = (Bytef *)result.mutableBytes + stream.total_out;
        stream.avail_out = (uInt)(result.length - stream.total_out);
        status = inflate(&stream, Z_NO_FLUSH);
    }
    uLong total = stream.total_out;
    inflateEnd(&stream);
    if (status != Z_STREAM_END)
        return nil;
    [result setLength:total];
    return result;
}

static bool TGCloudThemeSvgIsSeparator(char c)
{
    return c == ' ' || c == ',' || c == '\n' || c == '\r' || c == '\t';
}

static void TGCloudThemeSvgSkipSeparators(const char **cursor)
{
    while (**cursor != 0 && TGCloudThemeSvgIsSeparator(**cursor))
        (*cursor)++;
}

static bool TGCloudThemeSvgScanNumber(const char **cursor, CGFloat *value)
{
    TGCloudThemeSvgSkipSeparators(cursor);
    const char *start = *cursor;
    const char *p = start;
    if (*p == '+' || *p == '-')
        p++;
    bool digits = false;
    while (*p >= '0' && *p <= '9') { p++; digits = true; }
    if (*p == '.')
    {
        p++;
        while (*p >= '0' && *p <= '9') { p++; digits = true; }
    }
    if (!digits)
        return false;
    if (*p == 'e' || *p == 'E')
    {
        const char *exponent = p + 1;
        if (*exponent == '+' || *exponent == '-')
            exponent++;
        if (*exponent >= '0' && *exponent <= '9')
        {
            p = exponent;
            while (*p >= '0' && *p <= '9')
                p++;
        }
    }
    *value = (CGFloat)strtod(start, NULL);
    *cursor = p;
    return true;
}

static bool TGCloudThemeSvgScanFlag(const char **cursor, bool *flag)
{
    TGCloudThemeSvgSkipSeparators(cursor);
    if (**cursor != '0' && **cursor != '1')
        return false;
    *flag = **cursor == '1';
    (*cursor)++;
    return true;
}

static void TGCloudThemeSvgAddArc(CGMutablePathRef path, const CGAffineTransform *transform, CGPoint from, CGFloat rx, CGFloat ry, CGFloat angle, bool largeArc, bool sweep, CGPoint to)
{
    rx = fabs(rx);
    ry = fabs(ry);
    if (rx < FLT_EPSILON || ry < FLT_EPSILON || (fabs(from.x - to.x) < FLT_EPSILON && fabs(from.y - to.y) < FLT_EPSILON))
    {
        CGPathAddLineToPoint(path, transform, to.x, to.y);
        return;
    }
    CGFloat phi = angle * (CGFloat)M_PI / 180.0f;
    CGFloat cosPhi = cos(phi), sinPhi = sin(phi);
    CGFloat dx = (from.x - to.x) / 2.0f, dy = (from.y - to.y) / 2.0f;
    CGFloat x1 = cosPhi * dx + sinPhi * dy;
    CGFloat y1 = -sinPhi * dx + cosPhi * dy;
    CGFloat lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry);
    if (lambda > 1.0f)
    {
        CGFloat scale = sqrt(lambda);
        rx *= scale;
        ry *= scale;
    }
    CGFloat numerator = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1;
    CGFloat denominator = rx * rx * y1 * y1 + ry * ry * x1 * x1;
    CGFloat coefficient = denominator > 0.0f ? sqrt(MAX(0.0f, numerator / denominator)) : 0.0f;
    if (largeArc == sweep)
        coefficient = -coefficient;
    CGFloat cx1 = coefficient * rx * y1 / ry;
    CGFloat cy1 = -coefficient * ry * x1 / rx;
    CGFloat cx = cosPhi * cx1 - sinPhi * cy1 + (from.x + to.x) / 2.0f;
    CGFloat cy = sinPhi * cx1 + cosPhi * cy1 + (from.y + to.y) / 2.0f;
    CGFloat startAngle = atan2((y1 - cy1) / ry, (x1 - cx1) / rx);
    CGFloat endAngle = atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx);
    CGFloat delta = endAngle - startAngle;
    if (sweep && delta < 0.0f)
        delta += 2.0f * (CGFloat)M_PI;
    else if (!sweep && delta > 0.0f)
        delta -= 2.0f * (CGFloat)M_PI;
    int segments = (int)ceil(fabs(delta) / ((CGFloat)M_PI / 2.0f) - 0.001f);
    if (segments < 1)
        segments = 1;
    CGFloat step = delta / (CGFloat)segments;
    CGFloat k = 4.0f / 3.0f * tan(step / 4.0f);
    CGFloat theta = startAngle;
    for (int i = 0; i < segments; i++)
    {
        CGFloat cos1 = cos(theta), sin1 = sin(theta);
        CGFloat cos2 = cos(theta + step), sin2 = sin(theta + step);
        CGPoint p1 = CGPointMake(cos1 - k * sin1, sin1 + k * cos1);
        CGPoint p2 = CGPointMake(cos2 + k * sin2, sin2 - k * cos2);
        CGPoint p3 = CGPointMake(cos2, sin2);
        CGPoint points[3] = {p1, p2, p3};
        for (int j = 0; j < 3; j++)
        {
            CGFloat px = points[j].x * rx, py = points[j].y * ry;
            points[j] = CGPointMake(cosPhi * px - sinPhi * py + cx, sinPhi * px + cosPhi * py + cy);
        }
        CGPathAddCurveToPoint(path, transform, points[0].x, points[0].y, points[1].x, points[1].y, points[2].x, points[2].y);
        theta += step;
    }
}

static void TGCloudThemeSvgAddPath(CGMutablePathRef path, const CGAffineTransform *transform, const char *data)
{
    const char *cursor = data;
    char command = 0;
    CGPoint current = CGPointZero, start = CGPointZero, control = CGPointZero;
    char previous = 0;
    bool open = false;
    while (true)
    {
        TGCloudThemeSvgSkipSeparators(&cursor);
        if (*cursor == 0)
            break;
        char c = *cursor;
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'))
        {
            command = c;
            cursor++;
            if (command == 'Z' || command == 'z')
            {
                if (open)
                    CGPathCloseSubpath(path);
                open = false;
                current = start;
                previous = command;
                continue;
            }
        }
        else if (command == 0)
            break;

        bool relative = command >= 'a' && command <= 'z';
        CGFloat ox = relative ? current.x : 0.0f, oy = relative ? current.y : 0.0f;
        CGFloat v[6];
        char upper = relative ? (char)(command - 32) : command;
        bool parsed = true;
        switch (upper)
        {
            case 'M':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0]) && TGCloudThemeSvgScanNumber(&cursor, &v[1])))
                {
                    current = CGPointMake(ox + v[0], oy + v[1]);
                    start = current;
                    CGPathMoveToPoint(path, transform, current.x, current.y);
                    open = true;
                    command = relative ? 'l' : 'L';
                }
                break;
            case 'L':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0]) && TGCloudThemeSvgScanNumber(&cursor, &v[1])))
                {
                    current = CGPointMake(ox + v[0], oy + v[1]);
                    CGPathAddLineToPoint(path, transform, current.x, current.y);
                }
                break;
            case 'H':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0])))
                {
                    current.x = ox + v[0];
                    CGPathAddLineToPoint(path, transform, current.x, current.y);
                }
                break;
            case 'V':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0])))
                {
                    current.y = oy + v[0];
                    CGPathAddLineToPoint(path, transform, current.x, current.y);
                }
                break;
            case 'C':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0]) && TGCloudThemeSvgScanNumber(&cursor, &v[1]) && TGCloudThemeSvgScanNumber(&cursor, &v[2]) && TGCloudThemeSvgScanNumber(&cursor, &v[3]) && TGCloudThemeSvgScanNumber(&cursor, &v[4]) && TGCloudThemeSvgScanNumber(&cursor, &v[5])))
                {
                    control = CGPointMake(ox + v[2], oy + v[3]);
                    current = CGPointMake(ox + v[4], oy + v[5]);
                    CGPathAddCurveToPoint(path, transform, ox + v[0], oy + v[1], control.x, control.y, current.x, current.y);
                }
                break;
            case 'S':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0]) && TGCloudThemeSvgScanNumber(&cursor, &v[1]) && TGCloudThemeSvgScanNumber(&cursor, &v[2]) && TGCloudThemeSvgScanNumber(&cursor, &v[3])))
                {
                    bool smooth = previous == 'C' || previous == 'c' || previous == 'S' || previous == 's';
                    CGPoint first = smooth ? CGPointMake(2.0f * current.x - control.x, 2.0f * current.y - control.y) : current;
                    control = CGPointMake(ox + v[0], oy + v[1]);
                    current = CGPointMake(ox + v[2], oy + v[3]);
                    CGPathAddCurveToPoint(path, transform, first.x, first.y, control.x, control.y, current.x, current.y);
                }
                break;
            case 'Q':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0]) && TGCloudThemeSvgScanNumber(&cursor, &v[1]) && TGCloudThemeSvgScanNumber(&cursor, &v[2]) && TGCloudThemeSvgScanNumber(&cursor, &v[3])))
                {
                    control = CGPointMake(ox + v[0], oy + v[1]);
                    current = CGPointMake(ox + v[2], oy + v[3]);
                    CGPathAddQuadCurveToPoint(path, transform, control.x, control.y, current.x, current.y);
                }
                break;
            case 'T':
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0]) && TGCloudThemeSvgScanNumber(&cursor, &v[1])))
                {
                    bool smooth = previous == 'Q' || previous == 'q' || previous == 'T' || previous == 't';
                    control = smooth ? CGPointMake(2.0f * current.x - control.x, 2.0f * current.y - control.y) : current;
                    current = CGPointMake(ox + v[0], oy + v[1]);
                    CGPathAddQuadCurveToPoint(path, transform, control.x, control.y, current.x, current.y);
                }
                break;
            case 'A':
            {
                bool largeArc = false, sweep = false;
                if ((parsed = TGCloudThemeSvgScanNumber(&cursor, &v[0]) && TGCloudThemeSvgScanNumber(&cursor, &v[1]) && TGCloudThemeSvgScanNumber(&cursor, &v[2]) && TGCloudThemeSvgScanFlag(&cursor, &largeArc) && TGCloudThemeSvgScanFlag(&cursor, &sweep) && TGCloudThemeSvgScanNumber(&cursor, &v[3]) && TGCloudThemeSvgScanNumber(&cursor, &v[4])))
                {
                    CGPoint target = CGPointMake(ox + v[3], oy + v[4]);
                    TGCloudThemeSvgAddArc(path, transform, current, v[0], v[1], v[2], largeArc, sweep, target);
                    current = target;
                }
                break;
            }
            default:
                parsed = false;
                break;
        }
        if (!parsed)
            break;
        previous = upper == 'M' ? 'M' : command;
    }
}

static NSArray *TGCloudThemeSvgNumbers(NSString *string)
{
    NSMutableArray *numbers = [[NSMutableArray alloc] init];
    const char *cursor = [string UTF8String];
    CGFloat value = 0.0f;
    while (cursor != NULL && TGCloudThemeSvgScanNumber(&cursor, &value))
        [numbers addObject:@(value)];
    return numbers;
}

static CGAffineTransform TGCloudThemeSvgParseTransform(NSString *string)
{
    CGAffineTransform result = CGAffineTransformIdentity;
    NSArray *parts = [string componentsSeparatedByString:@")"];
    for (NSString *part in parts)
    {
        NSRange open = [part rangeOfString:@"("];
        if (open.location == NSNotFound)
            continue;
        NSString *name = [[part substringToIndex:open.location] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,\t\r\n"]];
        NSArray *v = TGCloudThemeSvgNumbers([part substringFromIndex:open.location + 1]);
        CGAffineTransform transform = CGAffineTransformIdentity;
        if ([name isEqualToString:@"matrix"] && v.count == 6)
            transform = CGAffineTransformMake([v[0] floatValue], [v[1] floatValue], [v[2] floatValue], [v[3] floatValue], [v[4] floatValue], [v[5] floatValue]);
        else if ([name isEqualToString:@"translate"] && v.count >= 1)
            transform = CGAffineTransformMakeTranslation([v[0] floatValue], v.count > 1 ? [v[1] floatValue] : 0.0f);
        else if ([name isEqualToString:@"scale"] && v.count >= 1)
            transform = CGAffineTransformMakeScale([v[0] floatValue], v.count > 1 ? [v[1] floatValue] : [v[0] floatValue]);
        else if ([name isEqualToString:@"rotate"] && v.count >= 1)
        {
            CGFloat angle = [v[0] floatValue] * (CGFloat)M_PI / 180.0f;
            if (v.count >= 3)
            {
                CGFloat cx = [v[1] floatValue], cy = [v[2] floatValue];
                transform = CGAffineTransformTranslate(CGAffineTransformRotate(CGAffineTransformMakeTranslation(cx, cy), angle), -cx, -cy);
            }
            else
                transform = CGAffineTransformMakeRotation(angle);
        }
        else if ([name isEqualToString:@"skewX"] && v.count >= 1)
            transform = CGAffineTransformMake(1.0f, 0.0f, tan([v[0] floatValue] * (CGFloat)M_PI / 180.0f), 1.0f, 0.0f, 0.0f);
        else if ([name isEqualToString:@"skewY"] && v.count >= 1)
            transform = CGAffineTransformMake(1.0f, tan([v[0] floatValue] * (CGFloat)M_PI / 180.0f), 0.0f, 1.0f, 0.0f, 0.0f);
        result = CGAffineTransformConcat(transform, result);
    }
    return result;
}

static CGFloat TGCloudThemeSvgFloat(NSDictionary *attributes, NSString *name)
{
    NSString *value = attributes[name];
    if (value == nil)
        return 0.0f;
    CGFloat result = 0.0f;
    const char *cursor = [value UTF8String];
    return TGCloudThemeSvgScanNumber(&cursor, &result) ? result : 0.0f;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
@interface TGCloudThemeSvgRenderer : NSObject <NSXMLParserDelegate>
#else
@interface TGCloudThemeSvgRenderer : NSObject
#endif
{
    CGContextRef _context;
    CGSize _size;
    NSMutableArray *_styles;
    NSUInteger _skipDepth;
    bool _hasViewport;
}

- (instancetype)initWithContext:(CGContextRef)context size:(CGSize)size;
- (bool)hasViewport;

@end

@implementation TGCloudThemeSvgRenderer

- (instancetype)initWithContext:(CGContextRef)context size:(CGSize)size
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        _size = size;
        _styles = [[NSMutableArray alloc] init];
        TGCloudThemeSvgStyle style;
        style.transform = CGAffineTransformIdentity;
        style.alpha = 1.0f;
        style.fill = true;
        style.stroke = false;
        style.evenOdd = false;
        style.hidden = false;
        style.strokeWidth = 1.0f;
        [_styles addObject:[NSValue valueWithBytes:&style objCType:@encode(TGCloudThemeSvgStyle)]];
    }
    return self;
}

- (bool)hasViewport
{
    return _hasViewport;
}

- (TGCloudThemeSvgStyle)currentStyle
{
    TGCloudThemeSvgStyle style;
    [(NSValue *)_styles.lastObject getValue:&style];
    return style;
}

- (void)applyStyleValue:(NSString *)value forName:(NSString *)name style:(TGCloudThemeSvgStyle *)style
{
    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([name isEqualToString:@"fill"])
        style->fill = ![value isEqualToString:@"none"];
    else if ([name isEqualToString:@"stroke"])
        style->stroke = ![value isEqualToString:@"none"];
    else if ([name isEqualToString:@"stroke-width"])
        style->strokeWidth = [value floatValue];
    else if ([name isEqualToString:@"fill-rule"])
        style->evenOdd = [value isEqualToString:@"evenodd"];
    else if ([name isEqualToString:@"opacity"] || [name isEqualToString:@"fill-opacity"])
        style->alpha *= MAX(0.0f, MIN(1.0f, [value floatValue]));
    else if ([name isEqualToString:@"display"])
        style->hidden = style->hidden || [value isEqualToString:@"none"];
    else if ([name isEqualToString:@"visibility"])
        style->hidden = [value isEqualToString:@"hidden"];
}

- (TGCloudThemeSvgStyle)styleWithAttributes:(NSDictionary *)attributes
{
    TGCloudThemeSvgStyle style = [self currentStyle];
    NSString *transform = attributes[@"transform"];
    if (transform != nil)
        style.transform = CGAffineTransformConcat(TGCloudThemeSvgParseTransform(transform), style.transform);
    for (NSString *name in @[@"fill", @"stroke", @"stroke-width", @"fill-rule", @"opacity", @"fill-opacity", @"display", @"visibility"])
    {
        NSString *value = attributes[name];
        if (value != nil)
            [self applyStyleValue:value forName:name style:&style];
    }
    NSString *inlineStyle = attributes[@"style"];
    if (inlineStyle != nil)
    {
        for (NSString *declaration in [inlineStyle componentsSeparatedByString:@";"])
        {
            NSRange colon = [declaration rangeOfString:@":"];
            if (colon.location == NSNotFound)
                continue;
            NSString *name = [[declaration substringToIndex:colon.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [self applyStyleValue:[declaration substringFromIndex:colon.location + 1] forName:name style:&style];
        }
    }
    return style;
}

- (void)setupViewportWithAttributes:(NSDictionary *)attributes
{
    NSArray *viewBox = TGCloudThemeSvgNumbers(attributes[@"viewBox"]);
    CGRect box = CGRectZero;
    if (viewBox.count == 4)
        box = CGRectMake([viewBox[0] floatValue], [viewBox[1] floatValue], [viewBox[2] floatValue], [viewBox[3] floatValue]);
    else
        box = CGRectMake(0.0f, 0.0f, TGCloudThemeSvgFloat(attributes, @"width"), TGCloudThemeSvgFloat(attributes, @"height"));
    if (box.size.width <= 0.0f || box.size.height <= 0.0f)
        return;
    CGFloat scale = MAX(_size.width / box.size.width, _size.height / box.size.height);
    CGContextTranslateCTM(_context, (_size.width - box.size.width * scale) / 2.0f - box.origin.x * scale, (_size.height - box.size.height * scale) / 2.0f - box.origin.y * scale);
    CGContextScaleCTM(_context, scale, scale);
    _hasViewport = true;
}

- (void)drawPath:(CGPathRef)path style:(TGCloudThemeSvgStyle)style
{
    if (path == NULL || style.hidden || CGPathIsEmpty(path))
        return;
    CGContextSaveGState(_context);
    CGContextAddPath(_context, path);
    if (style.fill)
    {
        CGContextSetRGBFillColor(_context, 0.0f, 0.0f, 0.0f, style.alpha);
        if (style.stroke)
        {
            CGContextSetRGBStrokeColor(_context, 0.0f, 0.0f, 0.0f, style.alpha);
            CGContextSetLineWidth(_context, style.strokeWidth);
            CGContextDrawPath(_context, style.evenOdd ? kCGPathEOFillStroke : kCGPathFillStroke);
        }
        else
            CGContextDrawPath(_context, style.evenOdd ? kCGPathEOFill : kCGPathFill);
    }
    else if (style.stroke)
    {
        CGContextSetRGBStrokeColor(_context, 0.0f, 0.0f, 0.0f, style.alpha);
        CGContextSetLineWidth(_context, style.strokeWidth);
        CGContextStrokePath(_context);
    }
    CGContextRestoreGState(_context);
}

- (void)parser:(NSXMLParser *)__unused parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)__unused namespaceURI qualifiedName:(NSString *)__unused qualifiedName attributes:(NSDictionary *)attributes
{
    if (_skipDepth != 0 || [elementName isEqualToString:@"defs"] || [elementName isEqualToString:@"clipPath"] || [elementName isEqualToString:@"mask"] || [elementName isEqualToString:@"symbol"] || [elementName isEqualToString:@"linearGradient"] || [elementName isEqualToString:@"radialGradient"] || [elementName isEqualToString:@"pattern"])
    {
        _skipDepth++;
        return;
    }

    if ([elementName isEqualToString:@"svg"] && !_hasViewport)
        [self setupViewportWithAttributes:attributes];

    TGCloudThemeSvgStyle style = [self styleWithAttributes:attributes];
    [_styles addObject:[NSValue valueWithBytes:&style objCType:@encode(TGCloudThemeSvgStyle)]];

    CGMutablePathRef path = NULL;
    const CGAffineTransform *transform = &style.transform;
    if ([elementName isEqualToString:@"path"])
    {
        NSString *data = attributes[@"d"];
        if (data.length != 0)
        {
            path = CGPathCreateMutable();
            TGCloudThemeSvgAddPath(path, transform, [data UTF8String]);
        }
    }
    else if ([elementName isEqualToString:@"rect"])
    {
        CGRect rect = CGRectMake(TGCloudThemeSvgFloat(attributes, @"x"), TGCloudThemeSvgFloat(attributes, @"y"), TGCloudThemeSvgFloat(attributes, @"width"), TGCloudThemeSvgFloat(attributes, @"height"));
        CGFloat rx = TGCloudThemeSvgFloat(attributes, @"rx");
        CGFloat ry = attributes[@"ry"] != nil ? TGCloudThemeSvgFloat(attributes, @"ry") : rx;
        if (attributes[@"rx"] == nil)
            rx = ry;
        rx = MIN(rx, rect.size.width / 2.0f);
        ry = MIN(ry, rect.size.height / 2.0f);
        path = CGPathCreateMutable();
        if (rx > 0.0f && ry > 0.0f)
        {
            CGFloat minX = CGRectGetMinX(rect), maxX = CGRectGetMaxX(rect), minY = CGRectGetMinY(rect), maxY = CGRectGetMaxY(rect);
            CGPathMoveToPoint(path, transform, minX + rx, minY);
            CGPathAddLineToPoint(path, transform, maxX - rx, minY);
            TGCloudThemeSvgAddArc(path, transform, CGPointMake(maxX - rx, minY), rx, ry, 0.0f, false, true, CGPointMake(maxX, minY + ry));
            CGPathAddLineToPoint(path, transform, maxX, maxY - ry);
            TGCloudThemeSvgAddArc(path, transform, CGPointMake(maxX, maxY - ry), rx, ry, 0.0f, false, true, CGPointMake(maxX - rx, maxY));
            CGPathAddLineToPoint(path, transform, minX + rx, maxY);
            TGCloudThemeSvgAddArc(path, transform, CGPointMake(minX + rx, maxY), rx, ry, 0.0f, false, true, CGPointMake(minX, maxY - ry));
            CGPathAddLineToPoint(path, transform, minX, minY + ry);
            TGCloudThemeSvgAddArc(path, transform, CGPointMake(minX, minY + ry), rx, ry, 0.0f, false, true, CGPointMake(minX + rx, minY));
            CGPathCloseSubpath(path);
        }
        else
            CGPathAddRect(path, transform, rect);
    }
    else if ([elementName isEqualToString:@"circle"] || [elementName isEqualToString:@"ellipse"])
    {
        CGFloat cx = TGCloudThemeSvgFloat(attributes, @"cx"), cy = TGCloudThemeSvgFloat(attributes, @"cy");
        CGFloat rx = [elementName isEqualToString:@"circle"] ? TGCloudThemeSvgFloat(attributes, @"r") : TGCloudThemeSvgFloat(attributes, @"rx");
        CGFloat ry = [elementName isEqualToString:@"circle"] ? rx : TGCloudThemeSvgFloat(attributes, @"ry");
        if (rx > 0.0f && ry > 0.0f)
        {
            path = CGPathCreateMutable();
            CGPathAddEllipseInRect(path, transform, CGRectMake(cx - rx, cy - ry, rx * 2.0f, ry * 2.0f));
        }
    }
    else if ([elementName isEqualToString:@"polygon"] || [elementName isEqualToString:@"polyline"] || [elementName isEqualToString:@"line"])
    {
        NSArray *points = nil;
        if ([elementName isEqualToString:@"line"])
            points = @[@(TGCloudThemeSvgFloat(attributes, @"x1")), @(TGCloudThemeSvgFloat(attributes, @"y1")), @(TGCloudThemeSvgFloat(attributes, @"x2")), @(TGCloudThemeSvgFloat(attributes, @"y2"))];
        else
            points = TGCloudThemeSvgNumbers(attributes[@"points"]);
        if (points.count >= 4)
        {
            path = CGPathCreateMutable();
            CGPathMoveToPoint(path, transform, [points[0] floatValue], [points[1] floatValue]);
            for (NSUInteger i = 2; i + 1 < points.count; i += 2)
                CGPathAddLineToPoint(path, transform, [points[i] floatValue], [points[i + 1] floatValue]);
            if ([elementName isEqualToString:@"polygon"])
                CGPathCloseSubpath(path);
        }
        if ([elementName isEqualToString:@"line"])
        {
            style.fill = false;
            style.stroke = true;
        }
    }

    if (path != NULL)
    {
        [self drawPath:path style:style];
        CGPathRelease(path);
    }
}

- (void)parser:(NSXMLParser *)__unused parser didEndElement:(NSString *)__unused elementName namespaceURI:(NSString *)__unused namespaceURI qualifiedName:(NSString *)__unused qualifiedName
{
    if (_skipDepth != 0)
    {
        _skipDepth--;
        return;
    }
    if (_styles.count > 1)
        [_styles removeLastObject];
}

@end

static CGImageRef TGCloudThemeCreatePatternImage(NSData *data, size_t width, size_t height, CGFloat scale)
{
    NSData *source = TGCloudThemeInflate(data);
    if (source.length == 0)
        return NULL;

    CGContextRef context = TGCloudThemeCreateContext(width, height);
    if (context == NULL)
        return NULL;
    CGContextScaleCTM(context, scale, scale);
    CGSize size = CGSizeMake((CGFloat)width / scale, (CGFloat)height / scale);

    bool rendered = false;
    const char *bytes = source.bytes;
    bool isSvg = false;
    for (NSUInteger i = 0; i + 4 <= MIN(source.length, (NSUInteger)1024); i++)
    {
        if (strncmp(bytes + i, "<svg", 4) == 0)
        {
            isSvg = true;
            break;
        }
    }
    if (isSvg)
    {
        @autoreleasepool
        {
            NSXMLParser *parser = [[NSXMLParser alloc] initWithData:source];
            TGCloudThemeSvgRenderer *renderer = [[TGCloudThemeSvgRenderer alloc] initWithContext:context size:size];
            parser.delegate = renderer;
            [parser parse];
            rendered = [renderer hasViewport];
        }
    }
    else
    {
        UIImage *image = [[UIImage alloc] initWithData:source];
        if (image.CGImage != NULL && image.size.width > 0.0f && image.size.height > 0.0f)
        {
            CGFloat fill = MAX(size.width / image.size.width, size.height / image.size.height);
            CGSize drawSize = CGSizeMake(image.size.width * fill, image.size.height * fill);
            CGContextTranslateCTM(context, (size.width - drawSize.width) / 2.0f, (size.height + drawSize.height) / 2.0f);
            CGContextScaleCTM(context, 1.0f, -1.0f);
            CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, drawSize.width, drawSize.height), image.CGImage);
            rendered = true;
        }
    }

    CGImageRef image = rendered ? CGBitmapContextCreateImage(context) : NULL;
    CGContextRelease(context);
    return image;
}

UIImage *TGCloudThemeWallpaperImage(NSArray *colors, int32_t rotation, NSData *patternData, int32_t intensity, CGSize size)
{
    if (colors.count == 0 && patternData.length == 0)
        return nil;
    if (colors.count == 0)
        colors = @[@(0xd6e4ef)];

    CGFloat scale = TGIsRetina() ? 2.0f : 1.0f;
    size_t width = (size_t)ceil(size.width * scale);
    size_t height = (size_t)ceil(size.height * scale);
    if (width == 0 || height == 0)
        return nil;

    CGContextRef context = TGCloudThemeCreateContext(width, height);
    if (context == NULL)
        return nil;
    CGRect bounds = CGRectMake(0.0f, 0.0f, (CGFloat)width, (CGFloat)height);
    CGImageRef pattern = patternData.length != 0 ? TGCloudThemeCreatePatternImage(patternData, width, height, scale) : NULL;

    if (pattern != NULL && intensity < 0)
    {
        CGContextSetRGBFillColor(context, 0.0f, 0.0f, 0.0f, 1.0f);
        CGContextFillRect(context, bounds);
        CGContextRef maskContext = TGCloudThemeCreateContext(width, height);
        if (maskContext != NULL)
        {
            TGCloudThemeDrawBackground(maskContext, bounds, colors, rotation);
            CGImageRef background = CGBitmapContextCreateImage(maskContext);
            CGContextClearRect(maskContext, bounds);
            CGContextSaveGState(maskContext);
            CGContextTranslateCTM(maskContext, 0.0f, bounds.size.height);
            CGContextScaleCTM(maskContext, 1.0f, -1.0f);
            CGContextDrawImage(maskContext, bounds, pattern);
            CGContextSetBlendMode(maskContext, kCGBlendModeSourceIn);
            CGContextDrawImage(maskContext, bounds, background);
            CGContextRestoreGState(maskContext);
            CGImageRelease(background);
            CGImageRef masked = CGBitmapContextCreateImage(maskContext);
            CGContextRelease(maskContext);
            CGContextSaveGState(context);
            CGContextSetAlpha(context, MIN(100, -intensity) / 100.0f);
            CGContextTranslateCTM(context, 0.0f, bounds.size.height);
            CGContextScaleCTM(context, 1.0f, -1.0f);
            CGContextDrawImage(context, bounds, masked);
            CGContextRestoreGState(context);
            CGImageRelease(masked);
        }
    }
    else
    {
        TGCloudThemeDrawBackground(context, bounds, colors, rotation);
        if (pattern != NULL)
        {
            CGContextSaveGState(context);
            CGContextSetBlendMode(context, kCGBlendModeSoftLight);
            CGContextSetAlpha(context, MIN(100, MAX(0, intensity == 0 ? 50 : intensity)) / 100.0f);
            CGContextTranslateCTM(context, 0.0f, bounds.size.height);
            CGContextScaleCTM(context, 1.0f, -1.0f);
            CGContextDrawImage(context, bounds, pattern);
            CGContextRestoreGState(context);
        }
    }
    if (pattern != NULL)
        CGImageRelease(pattern);

    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (result == NULL)
        return nil;
    UIImage *image = [[UIImage alloc] initWithCGImage:result scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(result);
    return image;
}
