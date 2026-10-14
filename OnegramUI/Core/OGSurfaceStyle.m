#import "OGSurfaceStyle.h"

static void OGSurfaceAppendColorIdentity(NSMutableString *identity, UIColor *color)
{
    if (color == nil)
    {
        [identity appendString:@"~;"];
        return;
    }
    CGColorRef cgColor = color.CGColor;
    size_t count = CGColorGetNumberOfComponents(cgColor);
    const CGFloat *components = CGColorGetComponents(cgColor);
    [identity appendString:@"c("];
    for (size_t index = 0; components != NULL && index < count; index++)
        [identity appendFormat:@"%.4f,", (double)components[index]];
    [identity appendString:@");"];
}

static void OGSurfaceAppendColorsIdentity(NSMutableString *identity, NSArray *colors)
{
    [identity appendString:@"["];
    for (UIColor *color in colors)
        OGSurfaceAppendColorIdentity(identity, color);
    [identity appendString:@"];"];
}

static void OGSurfaceAppendNumbersIdentity(NSMutableString *identity, NSArray *numbers)
{
    [identity appendString:@"["];
    for (NSNumber *number in numbers)
        [identity appendFormat:@"%.4f,", [number doubleValue]];
    [identity appendString:@"];"];
}

static void OGSurfaceAppendShadowsIdentity(NSMutableString *identity, NSArray *shadows)
{
    [identity appendString:@"["];
    for (OGSurfaceShadow *shadow in shadows)
        [identity appendString:[shadow renderIdentity]];
    [identity appendString:@"];"];
}

@interface OGSurfaceShadow ()
{
    NSString *_renderIdentity;
}
@property (nonatomic, retain, readwrite) UIColor *color;
@property (nonatomic, readwrite) CGSize offset;
@property (nonatomic, readwrite) CGFloat blur;
@property (nonatomic, readwrite) BOOL inset;
@property (nonatomic, readwrite) CGFloat spread;
@end

@implementation OGSurfaceShadow

+ (OGSurfaceShadow *)shadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur inset:(BOOL)inset
{
    OGSurfaceShadow *shadow = [[OGSurfaceShadow alloc] init];
    shadow.color = color;
    shadow.offset = offset;
    shadow.blur = MAX(0.0f, blur);
    shadow.inset = inset;
    return shadow;
}

+ (OGSurfaceShadow *)dropShadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur
{
    return [self shadowWithColor:color offset:offset blur:blur inset:NO];
}

+ (OGSurfaceShadow *)insetShadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur
{
    return [self shadowWithColor:color offset:offset blur:blur inset:YES];
}

+ (OGSurfaceShadow *)insetShadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur spread:(CGFloat)spread
{
    OGSurfaceShadow *shadow = [self shadowWithColor:color offset:offset blur:blur inset:YES];
    shadow.spread = MAX(0.0f, spread);
    return shadow;
}

- (UIEdgeInsets)outsets
{
    if (_inset)
        return UIEdgeInsetsZero;
    CGFloat reach = _blur * 1.5f;
    return UIEdgeInsetsMake(ceilf(MAX(0.0f, reach - _offset.height)), ceilf(MAX(0.0f, reach - _offset.width)), ceilf(MAX(0.0f, reach + _offset.height)), ceilf(MAX(0.0f, reach + _offset.width)));
}

- (NSString *)renderIdentity
{
    @synchronized (self)
    {
        if (_renderIdentity == nil)
        {
            NSMutableString *identity = [[NSMutableString alloc] initWithFormat:@"s(%d,%.4f,%.4f,%.4f,%.4f,", _inset ? 1 : 0, (double)_offset.width, (double)_offset.height, (double)_blur, (double)_spread];
            OGSurfaceAppendColorIdentity(identity, _color);
            [identity appendString:@")"];
            _renderIdentity = [identity copy];
        }
        return _renderIdentity;
    }
}

@end

@implementation OGSurfaceLayer

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _gradientAngle = 180.0f;
        _colors = @[];
        _locations = @[];
        _shadows = @[];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    OGSurfaceLayer *layer = [[[self class] allocWithZone:zone] init];
    layer.insets = _insets;
    layer.width = _width;
    layer.height = _height;
    layer.anchoredToRight = _anchoredToRight;
    layer.anchoredToBottom = _anchoredToBottom;
    layer.cornerRadius = _cornerRadius;
    layer.elliptical = _elliptical;
    layer.colors = _colors;
    layer.locations = _locations;
    layer.gradientAngle = _gradientAngle;
    layer.conicGradient = _conicGradient;
    layer.blendMode = _blendMode;
    layer.shadows = _shadows;
    return layer;
}

- (CGRect)frameInBodySize:(CGSize)bodySize
{
    CGFloat x = _insets.left;
    CGFloat width = bodySize.width - _insets.left - _insets.right;
    if (_width > 0.0f)
    {
        width = _width;
        x = _anchoredToRight ? bodySize.width - _insets.right - _width : _insets.left;
    }
    CGFloat y = _insets.top;
    CGFloat height = bodySize.height - _insets.top - _insets.bottom;
    if (_height > 0.0f)
    {
        height = _height;
        y = _anchoredToBottom ? bodySize.height - _insets.bottom - _height : _insets.top;
    }
    return CGRectMake(x, y, MAX(0.0f, width), MAX(0.0f, height));
}

- (NSString *)renderIdentity
{
    NSMutableString *identity = [[NSMutableString alloc] initWithFormat:@"l(%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%d,%.4f,%.4f,%d,%d,%d,", (double)_insets.top, (double)_insets.left, (double)_insets.bottom, (double)_insets.right, (double)_width, (double)_height, _anchoredToRight ? 1 : 0, _anchoredToBottom ? 1 : 0, (double)_cornerRadius, (double)_gradientAngle, (int)_blendMode, _conicGradient ? 1 : 0, _elliptical ? 1 : 0];
    OGSurfaceAppendColorsIdentity(identity, _colors);
    OGSurfaceAppendNumbersIdentity(identity, _locations);
    OGSurfaceAppendShadowsIdentity(identity, _shadows);
    [identity appendString:@")"];
    return identity;
}

@end

@interface OGSurfaceStyle ()
{
    NSString *_renderIdentity;
}
@end

@implementation OGSurfaceStyle

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _textureReferenceWidth = 320.0f;
        _textureContentsRect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
        _textureContrast = 1.0f;
        _opacity = 1.0f;
        _layers = @[];
        _shadows = @[];
        _strokeColors = @[];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    OGSurfaceStyle *style = [[[self class] allocWithZone:zone] init];
    style.textureResourceDirectory = _textureResourceDirectory;
    style.textureAssetName = _textureAssetName;
    style.textureReferenceWidth = _textureReferenceWidth;
    style.textureTiled = _textureTiled;
    style.textureContentsRect = _textureContentsRect;
    style.textureContrast = _textureContrast;
    style.textureBias = _textureBias;
    style.textureTintColor = _textureTintColor;
    style.fillColor = _fillColor;
    style.overlayColor = _overlayColor;
    style.shape = _shape;
    style.cornerRadius = _cornerRadius;
    style.arrowWidth = _arrowWidth;
    style.arrowTipRadius = _arrowTipRadius;
    style.tailSize = _tailSize;
    style.tailBottomInset = _tailBottomInset;
    style.layers = _layers;
    style.opacity = _opacity;
    style.shadows = _shadows;
    style.strokeWidth = _strokeWidth;
    style.strokeColors = _strokeColors;
    return style;
}

- (void)invalidateRenderIdentity
{
    @synchronized (self)
    {
        _renderIdentity = nil;
    }
}

- (void)setTextureResourceDirectory:(NSString *)textureResourceDirectory
{
    _textureResourceDirectory = [textureResourceDirectory copy];
    [self invalidateRenderIdentity];
}

- (void)setTextureAssetName:(NSString *)textureAssetName
{
    _textureAssetName = [textureAssetName copy];
    [self invalidateRenderIdentity];
}

- (void)setTextureReferenceWidth:(CGFloat)textureReferenceWidth
{
    _textureReferenceWidth = textureReferenceWidth;
    [self invalidateRenderIdentity];
}

- (void)setTextureTiled:(BOOL)textureTiled
{
    _textureTiled = textureTiled;
    [self invalidateRenderIdentity];
}

- (void)setTextureContentsRect:(CGRect)textureContentsRect
{
    _textureContentsRect = textureContentsRect;
    [self invalidateRenderIdentity];
}

- (void)setTextureContrast:(CGFloat)textureContrast
{
    _textureContrast = textureContrast;
    [self invalidateRenderIdentity];
}

- (void)setTextureBias:(CGFloat)textureBias
{
    _textureBias = textureBias;
    [self invalidateRenderIdentity];
}

- (void)setTextureTintColor:(UIColor *)textureTintColor
{
    _textureTintColor = textureTintColor;
    [self invalidateRenderIdentity];
}

- (void)setFillColor:(UIColor *)fillColor
{
    _fillColor = fillColor;
    [self invalidateRenderIdentity];
}

- (void)setOverlayColor:(UIColor *)overlayColor
{
    _overlayColor = overlayColor;
    [self invalidateRenderIdentity];
}

- (void)setShape:(OGSurfaceShape)shape
{
    _shape = shape;
    [self invalidateRenderIdentity];
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
    [self invalidateRenderIdentity];
}

- (void)setArrowWidth:(CGFloat)arrowWidth
{
    _arrowWidth = arrowWidth;
    [self invalidateRenderIdentity];
}

- (void)setArrowTipRadius:(CGFloat)arrowTipRadius
{
    _arrowTipRadius = arrowTipRadius;
    [self invalidateRenderIdentity];
}

- (void)setTailSize:(CGSize)tailSize
{
    _tailSize = tailSize;
    [self invalidateRenderIdentity];
}

- (void)setTailBottomInset:(CGFloat)tailBottomInset
{
    _tailBottomInset = tailBottomInset;
    [self invalidateRenderIdentity];
}

- (void)setLayers:(NSArray *)layers
{
    NSMutableArray *ownedLayers = [[NSMutableArray alloc] initWithCapacity:[layers count]];
    for (OGSurfaceLayer *layer in layers)
        [ownedLayers addObject:[layer copy]];
    _layers = [ownedLayers copy];
    [self invalidateRenderIdentity];
}

- (void)setOpacity:(CGFloat)opacity
{
    _opacity = opacity;
    [self invalidateRenderIdentity];
}

- (void)setShadows:(NSArray *)shadows
{
    _shadows = [shadows copy];
    [self invalidateRenderIdentity];
}

- (void)setStrokeWidth:(CGFloat)strokeWidth
{
    _strokeWidth = strokeWidth;
    [self invalidateRenderIdentity];
}

- (void)setStrokeColors:(NSArray *)strokeColors
{
    _strokeColors = [strokeColors copy];
    [self invalidateRenderIdentity];
}

- (NSString *)renderIdentity
{
    @synchronized (self)
    {
        if (_renderIdentity != nil)
            return _renderIdentity;

        NSMutableString *identity = [[NSMutableString alloc] initWithFormat:@"%@|%@|%.4f|%d|%.4f,%.4f,%.4f,%.4f|%.4f|%.4f|", _textureResourceDirectory ?: @"~", _textureAssetName ?: @"~", (double)_textureReferenceWidth, _textureTiled ? 1 : 0, (double)_textureContentsRect.origin.x, (double)_textureContentsRect.origin.y, (double)_textureContentsRect.size.width, (double)_textureContentsRect.size.height, (double)_textureContrast, (double)_textureBias];
        OGSurfaceAppendColorIdentity(identity, _textureTintColor);
        OGSurfaceAppendColorIdentity(identity, _fillColor);
        OGSurfaceAppendColorIdentity(identity, _overlayColor);
        [identity appendFormat:@"%d|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|%.4f|", (int)_shape, (double)_cornerRadius, (double)_arrowWidth, (double)_arrowTipRadius, (double)_tailSize.width, (double)_tailSize.height, (double)_tailBottomInset, (double)_opacity, (double)_strokeWidth];
        [identity appendString:@"["];
        for (OGSurfaceLayer *layer in _layers)
            [identity appendString:[layer renderIdentity]];
        [identity appendString:@"];"];
        OGSurfaceAppendShadowsIdentity(identity, _shadows);
        OGSurfaceAppendColorsIdentity(identity, _strokeColors);
        _renderIdentity = [identity copy];
        return _renderIdentity;
    }
}

- (UIEdgeInsets)dropShadowOutsets
{
    UIEdgeInsets outsets = UIEdgeInsetsZero;
    for (OGSurfaceShadow *shadow in _shadows)
    {
        UIEdgeInsets shadowOutsets = [shadow outsets];
        outsets.top = MAX(outsets.top, shadowOutsets.top);
        outsets.left = MAX(outsets.left, shadowOutsets.left);
        outsets.bottom = MAX(outsets.bottom, shadowOutsets.bottom);
        outsets.right = MAX(outsets.right, shadowOutsets.right);
    }
    return outsets;
}

- (UIEdgeInsets)horizontalCapInsets
{
    CGFloat influence = _cornerRadius;
    for (OGSurfaceShadow *shadow in _shadows)
    {
        if (!shadow.inset)
            continue;
        influence = MAX(influence, shadow.blur * 1.5f + MAX(ABS(shadow.offset.width), ABS(shadow.offset.height)));
    }
    influence = ceilf(influence);
    CGFloat leading = _shape == OGSurfaceShapeBackArrow ? influence + ceilf(_arrowWidth) : influence;
    return UIEdgeInsetsMake(0.0f, leading, 0.0f, influence);
}

@end
