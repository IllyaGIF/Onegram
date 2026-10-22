#import "TGModernConversationTitleActivityIndicator.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "OGMemoryCache.h"

#import <QuartzCore/QuartzCore.h>

#import <math.h>

typedef enum {
    TGModernConversationTitleActivityIndicatorTypeNone = 0,
    TGModernConversationTitleActivityIndicatorTypeTyping = 1,
    TGModernConversationTitleActivityIndicatorTypeAudioRecording = 2,
    TGModernConversationTitleActivityIndicatorTypeVideoRecording = 3,
    TGModernConversationTitleActivityIndicatorTypeUploading = 4,
    TGModernConversationTitleActivityIndicatorTypePlaying = 5
} TGModernConversationTitleActivityIndicatorType;

static NSString *const TGTitleActivityAnimationKey = @"frames";
static const CGFloat TGTitleActivityFramesPerSecond = 20.0f;
static const CGFloat TGTitleActivityMinDiameter = 3.0f;
static const CGFloat TGTitleActivityMaxDiameter = 4.5f;

static CGFloat TGTitleActivityInterpolate(CGFloat from, CGFloat to, CGFloat value)
{
    return (1.0f - value) * from + value * to;
}

static CGFloat TGTitleActivityRadius(CGFloat value, CGFloat timeOffset)
{
    CGFloat clampedValue = value + timeOffset;
    if (clampedValue > 1.0f)
        clampedValue = clampedValue - CGFloor(clampedValue);
    if (clampedValue < 0.4f)
        return TGTitleActivityInterpolate(TGTitleActivityMinDiameter, TGTitleActivityMaxDiameter, clampedValue / 0.4f);
    else if (clampedValue < 0.8f)
        return TGTitleActivityInterpolate(TGTitleActivityMaxDiameter, TGTitleActivityMinDiameter, (clampedValue - 0.4f) / 0.4f);
    return TGTitleActivityMinDiameter;
}

static void TGTitleActivityFillRoundedRect(CGContextRef context, CGRect rect, CGFloat radius, CGBlendMode blendMode)
{
    CGFloat minX = CGRectGetMinX(rect);
    CGFloat midX = CGRectGetMidX(rect);
    CGFloat maxX = CGRectGetMaxX(rect);
    CGFloat minY = CGRectGetMinY(rect);
    CGFloat midY = CGRectGetMidY(rect);
    CGFloat maxY = CGRectGetMaxY(rect);
    CGContextSaveGState(context);
    CGContextSetBlendMode(context, blendMode);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, minX, midY);
    CGContextAddArcToPoint(context, minX, minY, midX, minY, radius);
    CGContextAddArcToPoint(context, maxX, minY, maxX, midY, radius);
    CGContextAddArcToPoint(context, maxX, maxY, midX, maxY, radius);
    CGContextAddArcToPoint(context, minX, maxY, minX, midY, radius);
    CGContextClosePath(context);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
}

static void TGTitleActivityDrawFrame(CGContextRef context, TGModernConversationTitleActivityIndicatorType type, CGFloat animationValue, UIColor *color, CGSize size)
{
    const CGFloat minDiameter = TGTitleActivityMinDiameter;
    const CGFloat maxDiameter = TGTitleActivityMaxDiameter;

    switch (type)
    {
        case TGModernConversationTitleActivityIndicatorTypeTyping:
        {
            CGFloat leftPadding = 6.0f;
            CGFloat topPadding = 9.0f;
            CGFloat distance = 11.0f / 2.0f;
            
            CGFloat minAlpha = 0.75f;
            CGFloat deltaAlpha = 1.0f - minAlpha;
            
            CGFloat radius = 0.0f;
            
            radius = TGTitleActivityRadius(animationValue, 0.4f);
            radius = (MAX(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter);
            radius = radius * 1.5f;
            
            UIColor *dotsColor = nil;
            
            dotsColor = [color colorWithAlphaComponent:(radius * deltaAlpha + minAlpha)];
            
            CGContextSetFillColorWithColor(context, dotsColor.CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(leftPadding-minDiameter / 2.0f - radius / 2.0f, topPadding -minDiameter / 2.0f - radius / 2.0f, minDiameter + radius, minDiameter + radius));
            
            radius = TGTitleActivityRadius(animationValue, 0.2f);
            radius = (MAX(minDiameter, radius) - minDiameter) / (maxDiameter - minDiameter);
            radius = radius * 1.5f;
            
            dotsColor = [color colorWithAlphaComponent:(radius * deltaAlpha + minAlpha)];
            CGContextSetFillColorWithColor(context, dotsColor.CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(leftPadding + distance - minDiameter / 2.0f - radius / 2.0f, topPadding - minDiameter / 2.0f - radius / 2.0f, minDiameter + radius, minDiameter + radius));
            
            radius = TGTitleActivityRadius(animationValue, 0.0f);
            radius = (MAX(minDiameter, radius) - minDiameter)/(maxDiameter-minDiameter);
            radius = radius * 1.5f;
            
            dotsColor = [color colorWithAlphaComponent:(radius * deltaAlpha + minAlpha)];
            CGContextSetFillColorWithColor(context, dotsColor.CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(leftPadding + distance * 2.0f - minDiameter / 2.0f - radius / 2.0f, topPadding - minDiameter / 2.0f - radius / 2.0f, minDiameter + radius, minDiameter + radius));
            
            break;
        }
        case TGModernConversationTitleActivityIndicatorTypeAudioRecording:
        {
            CGContextSetStrokeColorWithColor(context, color.CGColor);
            CGContextSetLineCap(context, kCGLineCapRound);
            
            CGContextSetLineWidth(context, 2);
            
            CGFloat delta = 5.0f;
            CGFloat x = 3.0f;
            CGFloat y = size.height / 2.0f + 1.0f;
            CGFloat angle = (CGFloat)(18.0f * M_PI / 180.0);
            
            CGFloat scaledValue = animationValue * delta;
            
            CGFloat radius;
            CGFloat alpha;
            
            radius = scaledValue;
            
            alpha = radius/(3*delta);
            alpha = 1.0f - (CGFloat)pow(cos(alpha * M_PI), 50);
            CGContextSetAlpha(context, alpha);
            
            CGContextBeginPath(context);
            CGContextAddArc(context, x, y, radius, -angle, angle, 0);
            CGContextStrokePath(context);
            
            radius = scaledValue + delta;
            
            alpha = radius / (3.0f * delta);
            alpha = 1.0f - (CGFloat)pow(cos(alpha * M_PI), 10);
            CGContextSetAlpha(context, alpha);
            
            CGContextBeginPath(context);
            CGContextAddArc(context, x, y, radius, -angle, angle, 0);
            CGContextStrokePath(context);
            
            radius = scaledValue + delta*2;
            
            alpha = radius / (3.0f * delta);
            alpha = 1.0f - (CGFloat)pow(cos(alpha * M_PI), 10);
            CGContextSetAlpha(context, alpha);
            
            CGContextBeginPath(context);
            CGContextAddArc(context, x, y, radius, -angle, angle, 0);
            CGContextStrokePath(context);
            
            break;
        }
        case TGModernConversationTitleActivityIndicatorTypeVideoRecording:
        {
            CGContextSetFillColorWithColor(context, color.CGColor);
            
            CGFloat animValue = animationValue;
            if (animValue < 0.5f)
                animValue /= 0.5f;
            else
                animValue = (1 - animValue) / 0.5f;
            
            CGFloat alpha = 1.0f - animValue * 0.6;
            CGFloat radius = 3.5f - animValue * 0.66f;
            
            CGContextSetAlpha(context, alpha);
            CGContextFillEllipseInRect(context, CGRectMake(16.0f - radius, 9.0 - radius, radius * 2.0f, radius * 2.0f));
            
            break;
        }
        case TGModernConversationTitleActivityIndicatorTypeUploading:
        {
            CGFloat leftPadding = 11.0f / 2.0f - 1.0f;
            CGFloat topPadding = 12.0f / 2.0f + 1.0f;
            
            CGFloat progressWidth = 26.0f / 2.0f;
            CGFloat progressHeight = 8.0f / 2.0f;
            
            CGFloat progress;
            CGFloat round = 1.25;
            
            UIColor *dotsColor = color;
            CGContextSetFillColorWithColor(context, dotsColor.CGColor);
            
            TGTitleActivityFillRoundedRect(context, CGRectMake(leftPadding, topPadding, progressWidth, progressHeight), round, kCGBlendModeNormal);
            
            dotsColor = [color colorWithAlphaComponent:0.3f];
            CGContextSetFillColorWithColor(context, dotsColor.CGColor);
            
            TGTitleActivityFillRoundedRect(context, CGRectMake(leftPadding, topPadding, progressWidth, progressHeight), round, kCGBlendModeNormal);
            
            progress = TGTitleActivityInterpolate(0.0f, progressWidth * 2.0f, animationValue);
            
            dotsColor = color;
            CGContextSetFillColorWithColor(context, dotsColor.CGColor);
            
            TGTitleActivityFillRoundedRect(context, CGRectMake(leftPadding - progressWidth + progress, topPadding, progressWidth, progressHeight), round, kCGBlendModeSourceIn);
            
            break;
        }
        case TGModernConversationTitleActivityIndicatorTypePlaying:
        {
            UIColor *mainColor = color;
            
            UIColor *dotsColor = [mainColor colorWithAlphaComponent:0.5f];
            CGContextSetFillColorWithColor(context, dotsColor.CGColor);
            
            CGFloat distance = 4.0f;
            CGFloat x = (size.width - distance * 2) / 2.0f + 4.0f;
            CGFloat y = size.height / 2.0f + 1.0f;
            CGFloat radius = 1.0f;
            
            CGFloat dotsProgress = ((int)(animationValue * 100) % 50) / 50.0f;
            CGFloat dotsX = 1.5f + x - distance * dotsProgress;
            
            CGContextFillEllipseInRect(context, CGRectMake(dotsX - radius, y - radius, radius * 2.0f, radius * 2.0f));
            CGContextFillEllipseInRect(context, CGRectMake(dotsX - radius + distance, y - radius, radius * 2.0f, radius * 2.0f));
            
            CGContextSetAlpha(context, dotsProgress);
            CGContextFillEllipseInRect(context, CGRectMake(dotsX - radius + distance * 2, y - radius, radius * 2.0f, radius * 2.0f));
            CGContextSetAlpha(context, 1.0f);
            
            CGFloat angle = 42.0f * M_PI / 180.0;
            radius = 3.5f;
            
            bool closing = (int)(animationValue * 4) % 2;
            CGFloat bite = ((int)(animationValue * 100.0f) % 25) / 25.0f;
            if (closing)
                bite = 1.0f - bite;
            
            CGFloat startAngle = TGTitleActivityInterpolate(0.0f, -angle, bite);
            CGFloat endAngle = TGTitleActivityInterpolate(0.0f, angle, bite);
            
            if (bite < FLT_EPSILON)
            {
                startAngle = M_PI * 2;
                endAngle = 0;
            }
            
            x = radius + 4.5f;
            CGContextSetAlpha(context, 1.0f);
            CGContextSetFillColorWithColor(context, mainColor.CGColor);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, x, y);
            CGContextAddArc(context, x, y, radius, startAngle, endAngle, true);
            CGContextFillPath(context);
            
            break;
        }
        default:
            break;
    }
}

static NSTimeInterval TGTitleActivityDuration(TGModernConversationTitleActivityIndicatorType type)
{
    switch (type)
    {
        case TGModernConversationTitleActivityIndicatorTypeVideoRecording:
        case TGModernConversationTitleActivityIndicatorTypePlaying:
            return 0.9;
        case TGModernConversationTitleActivityIndicatorTypeUploading:
            return 1.75;
        default:
            return 0.7;
    }
}

static bool TGTitleActivityLinear(TGModernConversationTitleActivityIndicatorType type)
{
    return type != TGModernConversationTitleActivityIndicatorTypeVideoRecording && type != TGModernConversationTitleActivityIndicatorTypeUploading;
}

static NSArray *TGTitleActivityRenderFrames(TGModernConversationTitleActivityIndicatorType type, UIColor *color, CGSize size, CGFloat scale)
{
    size_t pixelWidth = (size_t)CGCeil(size.width * scale);
    size_t pixelHeight = (size_t)CGCeil(size.height * scale);
    if (pixelWidth == 0 || pixelHeight == 0 || color == nil)
        return nil;

    NSUInteger frameCount = (NSUInteger)MAX(8.0, round(TGTitleActivityDuration(type) * TGTitleActivityFramesPerSecond));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, pixelWidth, pixelHeight, 8, pixelWidth * 4, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    CGColorSpaceRelease(colorSpace);
    if (context == NULL)
        return nil;

    NSMutableArray *frames = [[NSMutableArray alloc] initWithCapacity:frameCount];
    for (NSUInteger index = 0; index < frameCount; index++)
    {
        CGContextClearRect(context, CGRectMake(0.0f, 0.0f, pixelWidth, pixelHeight));
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, 0.0f, pixelHeight);
        CGContextScaleCTM(context, scale, -scale);
        TGTitleActivityDrawFrame(context, type, (CGFloat)index / (CGFloat)frameCount, color, size);
        CGContextRestoreGState(context);
        CGImageRef image = CGBitmapContextCreateImage(context);
        if (image == NULL)
            break;
        [frames addObject:(__bridge id)image];
        CGImageRelease(image);
    }
    CGContextRelease(context);
    return frames.count == frameCount ? frames : nil;
}

static OGMemoryCache *TGTitleActivityFrameCache(void)
{
    static OGMemoryCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[OGMemoryCache alloc] initWithCountLimit:12 costLimit:512 * 1024];
    });
    return cache;
}

@interface TGModernConversationTitleActivityIndicator ()
{
    TGModernConversationTitleActivityIndicatorType _type;
    UIColor *_color;
    CGSize _framesSize;
}

@end

@implementation TGModernConversationTitleActivityIndicator

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = false;
        _color = TGAccentColor();
    }
    return self;
}

- (void)setColor:(UIColor *)color
{
    if (color == _color || [color isEqual:_color])
        return;
    _color = color;
    [self updateFrames];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (!CGSizeEqualToSize(_framesSize, self.bounds.size))
        [self updateFrames];
}

- (void)setNone
{
    _type = TGModernConversationTitleActivityIndicatorTypeNone;
    [self updateFrames];
}

- (void)setType:(TGModernConversationTitleActivityIndicatorType)type
{
    if (_type == type)
        return;
    _type = type;
    [self updateFrames];
}

- (void)setTyping
{
    [self setType:TGModernConversationTitleActivityIndicatorTypeTyping];
}

- (void)setAudioRecording
{
    [self setType:TGModernConversationTitleActivityIndicatorTypeAudioRecording];
}

- (void)setVideoRecording
{
    [self setType:TGModernConversationTitleActivityIndicatorTypeVideoRecording];
}

- (void)setUploading
{
    [self setType:TGModernConversationTitleActivityIndicatorTypeUploading];
}

- (void)setPlaying
{
    [self setType:TGModernConversationTitleActivityIndicatorTypePlaying];
}

- (void)updateFrames
{
    CALayer *layer = self.layer;
    [layer removeAnimationForKey:TGTitleActivityAnimationKey];
    CGSize size = self.bounds.size;
    _framesSize = size;

    NSArray *frames = nil;
    if (_type != TGModernConversationTitleActivityIndicatorTypeNone && _color != nil && size.width > 0.0f && size.height > 0.0f)
    {
        CGFloat scale = TGScreenScaling();
        NSArray *key = @[@(_type), _color, @(size.width), @(size.height), @(scale)];
        OGMemoryCache *cache = TGTitleActivityFrameCache();
        frames = [cache objectForKey:key];
        if (frames == nil)
        {
            frames = TGTitleActivityRenderFrames(_type, _color, size, scale);
            if (frames != nil)
                [cache setObject:frames forKey:key cost:(NSUInteger)(frames.count * CGCeil(size.width * scale) * CGCeil(size.height * scale) * 4.0f)];
        }
    }

    [CATransaction begin];
    [CATransaction setDisableActions:true];
    if (frames.count != 0)
        TGSetLayerContentsScale(layer, TGScreenScaling());
    layer.contents = frames.count != 0 ? frames[0] : nil;
    [CATransaction commit];

    if (frames.count == 0)
        return;

    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"contents"];
    animation.values = frames;
    animation.calculationMode = kCAAnimationDiscrete;
    animation.duration = TGTitleActivityDuration(_type);
    animation.repeatCount = HUGE_VALF;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:TGTitleActivityLinear(_type) ? kCAMediaTimingFunctionLinear : kCAMediaTimingFunctionEaseInEaseOut];
    animation.removedOnCompletion = false;
    [layer addAnimation:animation forKey:TGTitleActivityAnimationKey];
}

@end
