#import "TGSnowflakesView.h"

#import <QuartzCore/QuartzCore.h>

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGOnegramSettings.h"
#import "TGPresentationPallete.h"

static const NSUInteger TGSnowflakesMaxCountLimit = 300;
static const CGFloat TGSnowflakesAndroidDensity = 3.0f;
static const CGFloat TGSnowflakesSpawnBottomInset = 20.0f;
static const CGFloat TGSnowflakesFadeInDuration = 200.0f;
static const CGFloat TGSnowflakesFadeOutDuration = 2000.0f;
static const CGFloat TGSnowflakesFrameDuration = 17.0f;
static const CGFloat TGSnowflakesThinDiameter = 1.0f;
static const CGFloat TGSnowflakesThickDiameter = 2.5f;

typedef struct {
    CGFloat x;
    CGFloat y;
    CGFloat vx;
    CGFloat vy;
    CGFloat velocity;
    CGFloat alpha;
    CGFloat lifeTime;
    CGFloat currentTime;
    bool thin;
} TGSnowflake;

bool TGSnowfallSettingEnabled(void)
{
    NSInteger value = [TGOnegramSettings integerForKey:TGOnegramSettingAppearanceSnowfall];
    if (value >= 0)
        return value != 0;
    NSDateComponents *components = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] components:NSMonthCalendarUnit fromDate:[NSDate date]];
    NSInteger month = components.month;
    return month == 12 || month == 1 || month == 2;
}

bool TGSnowflakesVisibleForPallete(TGPresentationPallete *pallete)
{
    if (pallete == nil || !TGSnowfallSettingEnabled())
        return false;
    CGFloat red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f;
    UIColor *titleColor = pallete.navigationTitleColor;
    const CGFloat *components = CGColorGetComponents(titleColor.CGColor);
    size_t count = CGColorGetNumberOfComponents(titleColor.CGColor);
    if (components == NULL || count < 2)
        return false;
    if (count >= 4)
    {
        red = components[0];
        green = components[1];
        blue = components[2];
        alpha = components[3];
    }
    else
    {
        red = green = blue = components[0];
        alpha = components[1];
    }
    return alpha > 0.5f && 0.299f * red + 0.587f * green + 0.114f * blue >= 0.5f;
}

static CGFloat TGSnowflakesRandom(void)
{
    return (CGFloat)arc4random_uniform(1 << 24) / (CGFloat)(1 << 24);
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
static Class TGSnowflakesEmitterLayerClass(void)
{
    static Class emitterLayerClass = Nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (NSClassFromString(@"CAEmitterCell") != Nil)
            emitterLayerClass = NSClassFromString(@"CAEmitterLayer");
    });
    return emitterLayerClass;
}

static CGImageRef TGSnowflakesParticleImage(CGFloat diameter, CGFloat scale)
{
    size_t side = (size_t)MAX(1.0f, ceil(diameter * scale));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, side, side, 8, side * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return NULL;
    CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, (CGFloat)side, (CGFloat)side));
    CGImageRef image = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return image;
}
#endif

@interface TGSnowflakesView ()
{
    TGSnowflakesStyle _style;
    TGSnowflake _flakes[TGSnowflakesMaxCountLimit];
    NSUInteger _count;
    NSMutableArray *_layers;
    NSTimer *_timer;
    CFAbsoluteTime _lastTime;
    CGColorRef _flakeColor;
    bool _active;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    CAEmitterLayer *_emitterLayer;
#endif
}

@end

@implementation TGSnowflakesView

- (instancetype)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame style:TGSnowflakesStyleHeader];
}

- (instancetype)initWithFrame:(CGRect)frame style:(TGSnowflakesStyle)style
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _style = style;
        _layers = [[NSMutableArray alloc] init];
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = false;
        self.clipsToBounds = true;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
        Class emitterLayerClass = TGSnowflakesEmitterLayerClass();
        if (emitterLayerClass != Nil)
        {
            _emitterLayer = [emitterLayerClass layer];
            _emitterLayer.emitterShape = @"rectangle";
            _emitterLayer.emitterMode = @"surface";
            _emitterLayer.birthRate = 0.0f;
            [self.layer addSublayer:_emitterLayer];
        }
#endif
        self.color = [UIColor whiteColor];
    }
    return self;
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
- (CAEmitterCell *)emitterCellWithName:(NSString *)name diameter:(CGFloat)diameter birthRate:(float)birthRate
{
    CAEmitterCell *cell = [NSClassFromString(@"CAEmitterCell") emitterCell];
    CGFloat scale = [UIScreen mainScreen].scale;
    CGImageRef image = TGSnowflakesParticleImage(diameter, scale);
    cell.name = name;
    cell.contents = (__bridge id)image;
    if (image != NULL)
        CGImageRelease(image);
    cell.scale = 1.0f / scale;
    cell.color = _flakeColor;
    cell.birthRate = birthRate;
    cell.velocity = 14.67f;
    cell.velocityRange = 1.33f;
    cell.emissionLongitude = (CGFloat)M_PI_2;
    cell.emissionRange = (CGFloat)(20.0 * M_PI / 180.0);
    if (_style == TGSnowflakesStyleHeader)
    {
        cell.lifetime = 2.05f;
        cell.lifetimeRange = 0.05f;
        cell.alphaSpeed = -1.0f / 2.05f;
    }
    else
    {
        cell.lifetime = 4.0f;
        cell.lifetimeRange = 1.0f;
        cell.alphaSpeed = -0.25f;
    }
    return cell;
}

#endif

- (void)updateEmitterCells
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    if (_emitterLayer == nil)
        return;
    float birthRate = _style == TGSnowflakesStyleHeader ? 9.0f : 37.5f;
    _emitterLayer.emitterCells = @[
        [self emitterCellWithName:@"thin" diameter:TGSnowflakesThinDiameter birthRate:birthRate],
        [self emitterCellWithName:@"thick" diameter:TGSnowflakesThickDiameter birthRate:birthRate]
    ];
#endif
}

- (void)layoutSubviews
{
    [super layoutSubviews];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    if (_emitterLayer == nil)
        return;
    CGSize size = self.bounds.size;
    CGFloat spawnHeight = MAX(0.0f, size.height - TGSnowflakesSpawnBottomInset);
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    _emitterLayer.frame = self.bounds;
    _emitterLayer.emitterPosition = CGPointMake(size.width / 2.0f, spawnHeight / 2.0f);
    _emitterLayer.emitterSize = CGSizeMake(size.width, spawnHeight);
    [CATransaction commit];
#endif
}

- (void)dealloc
{
    [_timer invalidate];
    if (_flakeColor != NULL)
        CGColorRelease(_flakeColor);
}

- (NSUInteger)maxCount
{
    return _style == TGSnowflakesStyleHeader ? 100 : TGSnowflakesMaxCountLimit;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    CGFloat red = 1.0f, green = 1.0f, blue = 1.0f;
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    size_t count = CGColorGetNumberOfComponents(color.CGColor);
    if (components != NULL && count >= 3)
    {
        red = components[0];
        green = components[1];
        blue = components[2];
    }
    else if (components != NULL && count >= 1)
        red = green = blue = components[0];
    uint32_t rgb = ((uint32_t)(red * 255.0f + 0.5f) << 16) | ((uint32_t)(green * 255.0f + 0.5f) << 8) | (uint32_t)(blue * 255.0f + 0.5f);
    rgb &= 0xe6e6e6;
    UIColor *flakeColor = UIColorRGB(rgb);
    if (_flakeColor != NULL)
        CGColorRelease(_flakeColor);
    _flakeColor = CGColorRetain(flakeColor.CGColor);
    [self updateEmitterCells];
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    for (CALayer *layer in _layers)
        layer.backgroundColor = _flakeColor;
    [CATransaction commit];
}

- (void)setActive:(bool)active animated:(bool)animated
{
    if (active)
    {
        _active = true;
        self.hidden = false;
        if (animated && self.alpha < 1.0f)
        {
            [UIView animateWithDuration:0.2 animations:^
            {
                self.alpha = 1.0f;
            }];
        }
        else
            self.alpha = 1.0f;
        [self updateTimer];
        return;
    }

    if (!_active)
        return;
    _active = false;
    void (^completion)(BOOL) = ^(__unused BOOL finished)
    {
        if (_active)
            return;
        [self stopTimer];
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
        _emitterLayer.birthRate = 0.0f;
#endif
        _count = 0;
        [self syncLayers];
        [self removeFromSuperview];
    };
    if (animated && self.window != nil)
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            self.alpha = 0.0f;
        } completion:completion];
    }
    else
    {
        self.alpha = 0.0f;
        completion(true);
    }
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self updateTimer];
}

- (void)updateTimer
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 50000
    if (_emitterLayer != nil)
    {
        _emitterLayer.birthRate = _active && self.window != nil ? 1.0f : 0.0f;
        return;
    }
#endif
    if (_active && self.window != nil)
    {
        if (_timer == nil)
        {
            _lastTime = CFAbsoluteTimeGetCurrent();
            _timer = [NSTimer timerWithTimeInterval:1.0 / 60.0 target:self selector:@selector(timerTick) userInfo:nil repeats:true];
            [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
        }
    }
    else
        [self stopTimer];
}

- (void)stopTimer
{
    [_timer invalidate];
    _timer = nil;
}

- (void)spawnFlake
{
    if (_count >= [self maxCount])
        return;
    CGSize size = self.bounds.size;
    TGSnowflake *flake = &_flakes[_count++];
    flake->x = TGSnowflakesRandom() * size.width;
    flake->y = TGSnowflakesRandom() * MAX(0.0f, size.height - TGSnowflakesSpawnBottomInset);
    CGFloat angle = (CGFloat)((int)arc4random_uniform(40) - 20 + 90) * (CGFloat)M_PI / 180.0f;
    flake->vx = (CGFloat)cos(angle);
    flake->vy = (CGFloat)sin(angle);
    flake->alpha = 0.0f;
    flake->currentTime = 0.0f;
    flake->thin = arc4random_uniform(2) == 1;
    if (_style == TGSnowflakesStyleHeader)
        flake->lifeTime = 2000.0f + (CGFloat)arc4random_uniform(100);
    else
        flake->lifeTime = 3000.0f + (CGFloat)arc4random_uniform(2000);
    flake->velocity = 20.0f + TGSnowflakesRandom() * 4.0f;
}

- (void)updateFlakes:(CGFloat)dt
{
    NSUInteger index = 0;
    while (index < _count)
    {
        TGSnowflake *flake = &_flakes[index];
        if (flake->currentTime >= flake->lifeTime)
        {
            _flakes[index] = _flakes[--_count];
            continue;
        }
        if (flake->currentTime < TGSnowflakesFadeInDuration)
        {
            CGFloat progress = flake->currentTime / TGSnowflakesFadeInDuration;
            flake->alpha = progress * progress;
        }
        else if (_style == TGSnowflakesStyleHeader)
        {
            CGFloat progress = MIN(1.0f, (flake->currentTime - TGSnowflakesFadeInDuration) / (flake->lifeTime - TGSnowflakesFadeInDuration));
            flake->alpha = (1.0f - progress) * (1.0f - progress);
        }
        else if (flake->lifeTime - flake->currentTime < TGSnowflakesFadeOutDuration)
        {
            CGFloat progress = (flake->lifeTime - flake->currentTime) / TGSnowflakesFadeOutDuration;
            flake->alpha = 1.0f - (1.0f - progress) * (1.0f - progress);
        }
        CGFloat distance = flake->velocity * dt / 500.0f / TGSnowflakesAndroidDensity;
        flake->x += flake->vx * distance;
        flake->y += flake->vy * distance;
        flake->currentTime += dt;
        index++;
    }
}

- (void)syncLayers
{
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    while (_layers.count < _count)
    {
        CALayer *layer = [[CALayer alloc] init];
        layer.backgroundColor = _flakeColor;
        [self.layer addSublayer:layer];
        [_layers addObject:layer];
    }
    for (NSUInteger i = 0; i < _layers.count; i++)
    {
        CALayer *layer = _layers[i];
        if (i >= _count)
        {
            layer.hidden = true;
            continue;
        }
        TGSnowflake *flake = &_flakes[i];
        CGFloat diameter = flake->thin ? 1.0f : 2.5f;
        layer.hidden = false;
        layer.bounds = CGRectMake(0.0f, 0.0f, diameter, diameter);
        layer.cornerRadius = diameter / 2.0f;
        layer.position = CGPointMake(flake->x, flake->y);
        layer.opacity = (float)flake->alpha;
    }
    [CATransaction commit];
}

- (void)timerTick
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CGFloat dt = MIN(TGSnowflakesFrameDuration, (CGFloat)((now - _lastTime) * 1000.0));
    _lastTime = now;
    NSUInteger spawnAttempts = _style == TGSnowflakesStyleHeader ? 1 : 10;
    for (NSUInteger i = 0; i < spawnAttempts; i++)
    {
        if (_count < [self maxCount] && TGSnowflakesRandom() > 0.7f)
            [self spawnFlake];
    }
    [self updateFlakes:dt];
    [self syncLayers];
}

@end
