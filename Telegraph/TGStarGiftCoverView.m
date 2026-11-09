#import "TGStarGiftCoverView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"

#import "TGStarGift.h"
#import "TGAnimatedStickerView.h"
#import <math.h>

static const NSUInteger TGStarGiftCoverPatternRows = 5;
static const NSUInteger TGStarGiftCoverPatternColumns = 6;

static const CGFloat TGStarGiftCoverPatternScales[30] = {
    0.959379f, 0.719917f, 0.953793f, 0.750404f, 0.968893f, 0.875341f,
    0.797602f, 0.781136f, 0.788561f, 0.965283f, 0.732150f, 0.703365f,
    0.720738f, 0.728911f, 0.775958f, 0.718606f, 0.867522f, 0.716817f,
    0.870926f, 0.933013f, 0.821709f, 0.718877f, 0.857198f, 0.921786f,
    0.803113f, 0.703793f, 0.885282f, 0.780545f, 0.761981f, 0.874736f
};

static CGRect TGStarGiftCoverFlippedRect(CGRect rect, CGFloat height)
{
    return CGRectMake(rect.origin.x, height - rect.origin.y - rect.size.height, rect.size.width, rect.size.height);
}

static void TGStarGiftCoverDrawEllipticalGradient(CGContextRef context, CGGradientRef gradient, CGPoint center, CGSize radii, bool extend)
{
    if (radii.width <= 0.0f || radii.height <= 0.0f)
        return;
    CGContextSaveGState(context);
    CGContextTranslateCTM(context, center.x, center.y);
    CGContextScaleCTM(context, 1.0f, radii.height / radii.width);
    CGContextDrawRadialGradient(context, gradient, CGPointZero, 0.0f, CGPointZero, radii.width, extend ? kCGGradientDrawsAfterEndLocation : 0);
    CGContextRestoreGState(context);
}

static UIImage *TGStarGiftRenderCover(CGSize size, CGFloat scale, CGColorRef outerColor, CGColorRef innerColor, CGColorRef patternColor, CGImageRef pattern, CGPoint avatarCenter, CGRect gradientFrame, CGFloat defaultHeight)
{
    size.width = ceil(size.width);
    size.height = ceil(size.height);
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    size_t pixelWidth = (size_t)(size.width * scale);
    size_t pixelHeight = (size_t)(size.height * scale);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, pixelWidth, pixelHeight, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    if (context == NULL)
    {
        CGColorSpaceRelease(colorSpace);
        return nil;
    }
    CGContextScaleCTM(context, scale, scale);
    CGRect bounds = CGRectMake(0.0f, 0.0f, size.width, size.height);
    CGContextSetFillColorWithColor(context, outerColor);
    CGContextFillRect(context, bounds);

    CGColorRef gradientColors[2] = {innerColor, outerColor};
    CFArrayRef gradientColorArray = CFArrayCreate(kCFAllocatorDefault, (const void **)gradientColors, 2, NULL);
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, gradientColorArray, locations);
    CFRelease(gradientColorArray);
    CGContextSaveGState(context);
    CGContextClipToRect(context, TGStarGiftCoverFlippedRect(gradientFrame, size.height));
    CGPoint gradientCenter = CGPointMake(CGRectGetMidX(gradientFrame), size.height - avatarCenter.y);
    TGStarGiftCoverDrawEllipticalGradient(context, gradient, gradientCenter, CGSizeMake(gradientFrame.size.width / 2.0f, CGRectGetMaxY(gradientFrame) - avatarCenter.y), true);
    CGContextRestoreGState(context);
    CGGradientRelease(gradient);

    if (pattern != NULL && patternColor != NULL)
    {
        CGContextRef maskContext = CGBitmapContextCreate(NULL, pixelWidth, pixelHeight, 8, 0, NULL, kCGImageAlphaOnly);
        if (maskContext != NULL)
        {
            CGContextScaleCTM(maskContext, scale, scale);
            CGContextSetAlpha(maskContext, 0.8f);
            CGFloat baseDistance = 72.0f;
            CGFloat baseRowDistance = 28.0f;
            CGFloat baseItemSize = 26.0f;
            if (size.width <= 60.0f)
            {
                baseDistance *= 0.35f;
                baseRowDistance *= 0.3f;
                baseItemSize *= 0.4f;
            }
            else if (size.width < 150.0f)
            {
                baseDistance *= 0.6f;
                baseRowDistance *= 0.6f;
                baseItemSize *= 0.83f;
            }
            CGFloat angleSpan = (CGFloat)M_PI * 2.0f / TGStarGiftCoverPatternColumns;
            NSUInteger index = 0;
            for (NSUInteger row = 0; row < TGStarGiftCoverPatternRows; row++)
            {
                CGFloat distance = baseDistance + row * baseRowDistance;
                for (NSUInteger column = 0; column < TGStarGiftCoverPatternColumns; column++)
                {
                    CGFloat angle = -(CGFloat)M_PI * 0.5f + column * angleSpan;
                    if (row % 2 != 0)
                        angle += angleSpan * 0.5f;
                    CGFloat itemSize = CGFloor(baseItemSize * TGStarGiftCoverPatternScales[index]);
                    index++;
                    CGRect itemFrame = CGRectMake(avatarCenter.x + cos(angle) * distance - itemSize / 2.0f, avatarCenter.y + sin(angle) * distance - itemSize / 2.0f, itemSize, itemSize);
                    CGContextDrawImage(maskContext, TGStarGiftCoverFlippedRect(itemFrame, size.height), pattern);
                }
            }
            CGImageRef mask = CGBitmapContextCreateImage(maskContext);
            CGContextRelease(maskContext);
            if (mask != NULL)
            {
                CGColorRef patternColors[2] = {CGColorCreateCopyWithAlpha(patternColor, 0.6f), CGColorCreateCopyWithAlpha(patternColor, 0.0f)};
                CFArrayRef patternColorArray = CFArrayCreate(kCFAllocatorDefault, (const void **)patternColors, 2, NULL);
                CGGradientRef patternGradient = CGGradientCreateWithColors(colorSpace, patternColorArray, locations);
                CFRelease(patternColorArray);
                CGColorRelease(patternColors[0]);
                CGColorRelease(patternColors[1]);
                CGContextSaveGState(context);
                CGContextClipToMask(context, bounds, mask);
                TGStarGiftCoverDrawEllipticalGradient(context, patternGradient, CGPointMake(avatarCenter.x, size.height - avatarCenter.y), CGSizeMake(190.0f, CGFloor(defaultHeight) / 2.0f), false);
                CGContextRestoreGState(context);
                CGGradientRelease(patternGradient);
                CGImageRelease(mask);
            }
        }
    }

    CGImageRef output = CGBitmapContextCreateImage(context);
    UIImage *image = output != NULL ? [UIImage imageWithCGImage:output scale:scale orientation:UIImageOrientationUp] : nil;
    if (output != NULL)
        CGImageRelease(output);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    return image;
}

static NSCache *TGStarGiftCoverCache(void)
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.totalCostLimit = 8 * 1024 * 1024;
    });
    return cache;
}

static dispatch_queue_t TGStarGiftCoverQueue(void)
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("onegram.gifts.cover", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@interface OGStarGiftPatternImageView : TGImageView

@property (nonatomic, copy) void (^imageChanged)(UIImage *);

@end

@implementation OGStarGiftPatternImageView

- (void)performTransitionToImage:(UIImage *)image partial:(bool)partial duration:(NSTimeInterval)duration
{
    [super performTransitionToImage:image partial:partial duration:duration];
    if (!partial && image != nil && _imageChanged != nil)
        _imageChanged(image);
}

@end

@interface TGStarGiftCoverView ()
{
    UIImageView *_imageView;
    OGStarGiftPatternImageView *_patternView;
    TGStarGift *_gift;
    NSString *_renderKey;
}

- (void)updateImage;

@end

@implementation TGStarGiftCoverView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        _imageView = [[UIImageView alloc] init];
        [self addSubview:_imageView];

        _patternView = [[OGStarGiftPatternImageView alloc] init];
        _patternView.hidden = true;
        [self addSubview:_patternView];
        __weak TGStarGiftCoverView *weakSelf = self;
        _patternView.imageChanged = ^(__unused UIImage *image)
        {
            __strong TGStarGiftCoverView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf updateImage];
        };
    }
    return self;
}

- (void)setGift:(TGStarGift *)gift
{
    if (_gift == gift)
        return;
    bool patternChanged = _gift.patternSticker.documentId != gift.patternSticker.documentId;
    _gift = gift;
    _renderKey = nil;
    _imageView.image = nil;
    self.backgroundColor = gift.hasBackdrop ? TGStarGiftColor(gift.backdropEdgeColor) : nil;
    if (patternChanged)
    {
        [_patternView reset];
        if (gift.patternSticker != nil)
            [_patternView loadUri:[TGAnimatedStickerView placeholderUriForDocument:gift.patternSticker size:CGSizeMake(96.0f, 96.0f)] withOptions:@{}];
    }
    [self updateImage];
}

- (void)setAvatarCenter:(CGPoint)avatarCenter
{
    _avatarCenter = avatarCenter;
    [self setNeedsLayout];
}

- (void)setDefaultHeight:(CGFloat)defaultHeight
{
    _defaultHeight = defaultHeight;
    [self setNeedsLayout];
}

- (void)setGradientFrame:(CGRect)gradientFrame
{
    _gradientFrame = gradientFrame;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _imageView.frame = self.bounds;
    [self updateImage];
}

- (void)updateImage
{
    CGSize size = self.bounds.size;
    if (!_gift.hasBackdrop || size.width < 1.0f || size.height < 1.0f)
    {
        _renderKey = nil;
        _imageView.image = nil;
        return;
    }
    CGImageRef pattern = [_patternView currentImage].CGImage;
    CGFloat scale = MAX(1.0f, [UIScreen mainScreen].scale);
    CGPoint avatarCenter = _avatarCenter;
    CGRect gradientFrame = _gradientFrame;
    CGFloat defaultHeight = _defaultHeight;
    NSString *key = [[NSString alloc] initWithFormat:@"%dx%d:%.1f:%x:%x:%x:%lld:%d:%.1f,%.1f:%@:%.1f", (int)ceil(size.width), (int)ceil(size.height), scale, (int)_gift.backdropEdgeColor, (int)_gift.backdropCenterColor, (int)_gift.backdropPatternColor, _gift.patternSticker.documentId, pattern != NULL ? 1 : 0, avatarCenter.x, avatarCenter.y, NSStringFromCGRect(gradientFrame), defaultHeight];
    if ([_renderKey isEqualToString:key])
        return;
    _renderKey = key;
    UIImage *cached = [TGStarGiftCoverCache() objectForKey:key];
    if (cached != nil)
    {
        _imageView.image = cached;
        return;
    }
    CGColorRef outer = CGColorRetain(TGStarGiftColor(_gift.backdropEdgeColor).CGColor);
    CGColorRef inner = CGColorRetain(TGStarGiftColor(_gift.backdropCenterColor).CGColor);
    CGColorRef tint = CGColorRetain(TGStarGiftColor(_gift.backdropPatternColor).CGColor);
    CGImageRef patternCopy = pattern != NULL ? CGImageRetain(pattern) : NULL;
    __weak TGStarGiftCoverView *weakSelf = self;
    dispatch_async(TGStarGiftCoverQueue(), ^
    {
        @autoreleasepool
        {
            UIImage *rendered = [TGStarGiftCoverCache() objectForKey:key];
            if (rendered == nil)
            {
                rendered = TGStarGiftRenderCover(size, scale, outer, inner, tint, patternCopy, avatarCenter, gradientFrame, defaultHeight);
                if (rendered != nil)
                    [TGStarGiftCoverCache() setObject:rendered forKey:key cost:(NSUInteger)(ceil(size.width) * ceil(size.height) * scale * scale * 4.0f)];
            }
            CGColorRelease(outer);
            CGColorRelease(inner);
            CGColorRelease(tint);
            if (patternCopy != NULL)
                CGImageRelease(patternCopy);
            dispatch_async(dispatch_get_main_queue(), ^
            {
                __strong TGStarGiftCoverView *strongSelf = weakSelf;
                if (strongSelf != nil && [strongSelf->_renderKey isEqualToString:key])
                    strongSelf->_imageView.image = rendered;
            });
        }
    });
}

@end
