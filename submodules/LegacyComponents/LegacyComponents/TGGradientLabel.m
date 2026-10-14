#import "TGGradientLabel.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "../../../OnegramPlatform/OGMemoryCache.h"

@interface TGGradientLabelImageKey : NSObject <NSCopying>
{
@public
    NSString *_text;
    NSString *_fontName;
    CGFloat _pointSize;
    UIColor *_textColor;
    int _topColor;
    int _bottomColor;
    int _width;
    int _height;
    NSUInteger _hash;
}

@end

@implementation TGGradientLabelImageKey

- (id)copyWithZone:(NSZone *)__unused zone
{
    return self;
}

- (NSUInteger)hash
{
    return _hash;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[TGGradientLabelImageKey class]])
        return NO;
    TGGradientLabelImageKey *other = object;
    if (_hash != other->_hash || _width != other->_width || _height != other->_height || _topColor != other->_topColor || _bottomColor != other->_bottomColor || ABS(_pointSize - other->_pointSize) > FLT_EPSILON)
        return NO;
    if (!(_textColor == other->_textColor || (_textColor != nil && other->_textColor != nil && [_textColor isEqual:other->_textColor])))
        return NO;
    if (!(_fontName == other->_fontName || [_fontName isEqualToString:other->_fontName]))
        return NO;
    return [_text isEqualToString:other->_text];
}

@end

static OGMemoryCache *TGGradientLabelImageCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:256 costLimit:2 * 1024 * 1024];
    });
    return cache;
}

static OGMemoryCache *TGGradientLabelSizeCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:1024 costLimit:1024];
    });
    return cache;
}

static TGGradientLabelImageKey *TGGradientLabelMakeKey(NSString *text, UIFont *font, UIColor *textColor, int topColor, int bottomColor, int width, int height)
{
    TGGradientLabelImageKey *key = [[TGGradientLabelImageKey alloc] init];
    key->_text = text;
    key->_fontName = font.fontName;
    key->_pointSize = font.pointSize;
    key->_textColor = textColor;
    key->_topColor = textColor == nil ? topColor : 0;
    key->_bottomColor = textColor == nil ? bottomColor : 0;
    key->_width = width;
    key->_height = height;
    key->_hash = text.hash ^ ((NSUInteger)width << 12) ^ ((NSUInteger)height << 22) ^ (NSUInteger)lrintf((float)(font.pointSize * 8.0f));
    return key;
}

static NSString *TGGradientLabelNormalizedText(NSString *text)
{
    if (text.length == 1)
    {
        unichar c = [text characterAtIndex:0];
        if (c >= 'a' && c <= 'z')
        {
            c += 'A' - 'a';
            return [[NSString alloc] initWithCharacters:&c length:1];
        }
    }
    else if (text.length == 3)
    {
        unichar c[3] = {[text characterAtIndex:0], [text characterAtIndex:1], [text characterAtIndex:2]};
        if (c[0] >= 'a' && c[0] <= 'z')
            c[0] += 'A' - 'a';
        if (c[2] >= 'a' && c[2] <= 'z')
            c[2] += 'A' - 'a';
        return [[NSString alloc] initWithCharacters:c length:3];
    }
    return text;
}

static bool TGGradientLabelHasVisibleText(NSString *text, UIFont *font)
{
    if (text.length == 0 || font == nil)
        return false;
    for (NSInteger i = (NSInteger)text.length - 1; i >= 0; i--)
    {
        if ([text characterAtIndex:(NSUInteger)i] != ' ')
            return true;
    }
    return false;
}

static CGSize TGGradientLabelMeasureText(NSString *text, UIFont *font)
{
    TGGradientLabelImageKey *key = TGGradientLabelMakeKey(text, font, nil, 0, 0, 0, 0);
    OGMemoryCache *cache = TGGradientLabelSizeCache();
    NSValue *value = [cache objectForKey:key];
    if (value != nil)
        return [value CGSizeValue];
    
    CGSize size = CGSizeZero;
    if (iosMajorVersion() >= 7)
        size = [text boundingRectWithSize:CGSizeMake(1000.0f, 1000.0f) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: font} context:nil].size;
    else
        size = [text sizeWithFont:font];
    
    [cache setObject:[NSValue valueWithCGSize:size] forKey:key cost:1];
    return size;
}

static void TGGradientLabelDrawText(CGContextRef context, CGRect bounds, NSString *text, UIFont *font, UIColor *textColor, int topColor, int bottomColor, CGSize textSize)
{
    CGPoint drawingOffset = CGPointMake(CGFloor((bounds.size.width - textSize.width) / 2.0f), CGFloor((bounds.size.height - textSize.height) / 2.0f));
    if (textColor != nil)
    {
        CGContextSetFillColorWithColor(context, textColor.CGColor);
        [text drawAtPoint:drawingOffset withFont:font];
    }
    else
    {
        CGContextSetTextDrawingMode(context, kCGTextClip);
        
        [text drawAtPoint:drawingOffset withFont:font];
        
        CGColorRef colors[2] = {
            CGColorRetain(UIColorRGB(topColor).CGColor),
            CGColorRetain(UIColorRGB(bottomColor).CGColor)
        };
        
        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
        CGFloat locations[2] = {0.0f, 1.0f};
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
        
        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);
        
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, bounds.size.height), 0);
        
        CFRelease(gradient);
    }
}

static UIImage *TGGradientLabelImage(NSString *text, UIFont *font, UIColor *textColor, int topColor, int bottomColor, CGSize textSize, CGSize boundsSize)
{
    CGFloat scale = TGScreenScaling();
    int width = (int)lrintf((float)(boundsSize.width * scale * 4.0f));
    int height = (int)lrintf((float)(boundsSize.height * scale * 4.0f));
    TGGradientLabelImageKey *key = TGGradientLabelMakeKey(text, font, textColor, topColor, bottomColor, width, height);
    
    OGMemoryCache *cache = TGGradientLabelImageCache();
    UIImage *image = [cache objectForKey:key];
    if (image != nil)
        return image;
    
    if (iosMajorVersion() >= 4)
        UIGraphicsBeginImageContextWithOptions(boundsSize, false, scale);
    else
        UIGraphicsBeginImageContext(boundsSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context != NULL)
    {
        TGGradientLabelDrawText(context, CGRectMake(0.0f, 0.0f, boundsSize.width, boundsSize.height), text, font, textColor, topColor, bottomColor, textSize);
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    if (image != nil && image.CGImage != NULL)
        [cache setObject:image forKey:key cost:CGImageGetBytesPerRow(image.CGImage) * CGImageGetHeight(image.CGImage)];
    return image;
}

@interface TGGradientLabel ()
{
    CGSize _textSize;
}

@end

@implementation TGGradientLabel

+ (void)prepareText:(NSString *)text font:(UIFont *)font textColor:(UIColor *)textColor height:(CGFloat)height
{
    NSString *normalizedText = TGGradientLabelNormalizedText(text);
    if (!TGGradientLabelHasVisibleText(normalizedText, font))
        return;
    
    CGSize textSize = TGGradientLabelMeasureText(normalizedText, font);
    if (textSize.width < FLT_EPSILON || height < FLT_EPSILON)
        return;
    
    TGGradientLabelImage(normalizedText, font, textColor, 0, 0, textSize, CGSizeMake(textSize.width, height));
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.opaque = false;
    }
    return self;
}

- (void)sizeToFit
{
    if (_text == nil || _font == nil)
        return;
    
    _textSize = TGGradientLabelMeasureText(_text, _font);
    
    CGRect frame = self.frame;
    frame.size = _textSize;
    self.frame = frame;
}

- (void)setText:(NSString *)text
{
    _text = TGGradientLabelNormalizedText(text);
    [self setNeedsDisplay];
}

- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    [self.layer setNeedsDisplay];
}

- (void)displayLayer:(CALayer *)layer
{
    CGRect bounds = self.bounds;
    if (!TGGradientLabelHasVisibleText(_text, _font) || bounds.size.width < FLT_EPSILON || bounds.size.height < FLT_EPSILON)
    {
        layer.contents = nil;
        return;
    }
    
    UIImage *image = TGGradientLabelImage(_text, _font, _textColor, _topColor, _bottomColor, _textSize, bounds.size);
    CGImageRef imageRef = image.CGImage;
    if (imageRef == NULL)
    {
        layer.contents = nil;
        return;
    }
    
    CGFloat imageScale = iosMajorVersion() >= 4 ? image.scale : 1.0f;
    if ([layer respondsToSelector:@selector(setContentsScale:)])
        layer.contentsScale = imageScale;
    CGFloat pixelWidth = (CGFloat)CGImageGetWidth(imageRef);
    CGFloat pixelHeight = (CGFloat)CGImageGetHeight(imageRef);
    layer.contentsRect = CGRectMake(0.0f, 0.0f, MIN(1.0f, bounds.size.width * imageScale / MAX(1.0f, pixelWidth)), MIN(1.0f, bounds.size.height * imageScale / MAX(1.0f, pixelHeight)));
    layer.contents = (__bridge id)imageRef;
}

@end
