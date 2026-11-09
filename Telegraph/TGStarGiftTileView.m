#import "TGStarGiftTileView.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGLetteredAvatarView.h"

#import "TGStarGift.h"
#import "TGStarGiftCoverView.h"
#import "TGAnimatedStickerView.h"
#import "TGPresentation.h"
#import "TGDatabase.h"
#import "TGTLDynamic.h"
#import <math.h>
#import <objc/message.h>

static const CGFloat TGStarGiftTileCornerRadius = 12.0f;
static const CGFloat TGStarGiftProfileCornerRadius = 16.0f;
static const CGFloat TGStarGiftRibbonSide = 58.0f;
static const CGFloat TGStarGiftRibbonOutlineSide = 66.0f;

static CGPathRef TGStarGiftCreateRoundedPath(CGRect rect, CGFloat radius)
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMidY(rect));
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMinY(rect), CGRectGetMidX(rect), CGRectGetMinY(rect), radius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMinY(rect), CGRectGetMaxX(rect), CGRectGetMidY(rect), radius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMaxX(rect), CGRectGetMaxY(rect), CGRectGetMidX(rect), CGRectGetMaxY(rect), radius);
    CGPathAddArcToPoint(path, NULL, CGRectGetMinX(rect), CGRectGetMaxY(rect), CGRectGetMinX(rect), CGRectGetMidY(rect), radius);
    CGPathCloseSubpath(path);
    return path;
}

static void TGStarGiftColorComponents(CGColorRef color, CGFloat *red, CGFloat *green, CGFloat *blue)
{
    size_t count = CGColorGetNumberOfComponents(color);
    const CGFloat *components = CGColorGetComponents(color);
    if (components == NULL || count < 2)
        return;
    if (count < 4)
    {
        *red = *green = *blue = components[0];
        return;
    }
    *red = components[0];
    *green = components[1];
    *blue = components[2];
}

static CGFloat TGStarGiftColorBrightness(CGColorRef color)
{
    size_t count = CGColorGetNumberOfComponents(color);
    const CGFloat *components = CGColorGetComponents(color);
    if (components == NULL || count < 2)
        return 0.0f;
    if (count < 4)
        return components[0];
    return components[0] * 0.30f + components[1] * 0.59f + components[2] * 0.11f;
}

static UIImage *TGStarGiftRenderBackdrop(CGSize size, CGFloat scale, UIColor *centerColor, UIColor *edgeColor, CGFloat cornerRadius)
{
    if (size.width < 1.0f || size.height < 1.0f)
        return nil;
    scale = MAX(1.0f, MIN(2.0f, scale));
    size.width = ceil(size.width);
    size.height = ceil(size.height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, (size_t)(size.width * scale), (size_t)(size.height * scale), 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    if (context == NULL)
    {
        CGColorSpaceRelease(colorSpace);
        return nil;
    }
    CGContextScaleCTM(context, scale, scale);
    CGRect rect = CGRectMake(0.0f, 0.0f, size.width, size.height);
    CGFloat radius = MIN(cornerRadius, MIN(size.width, size.height) / 2.0f);
    CGPathRef clipPath = TGStarGiftCreateRoundedPath(rect, radius);
    CGContextAddPath(context, clipPath);
    CGContextClip(context);
    CGPathRelease(clipPath);

    NSArray *colors = @[(__bridge id)centerColor.CGColor, (__bridge id)edgeColor.CGColor];
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
    CGPoint center = CGPointMake(size.width / 2.0f, size.height * 0.58f);
    CGFloat endRadius = MAX(size.width, size.height) * 0.75f;
    CGContextDrawRadialGradient(context, gradient, center, 0.0f, center, endRadius, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGFloat stroke = TGStarGiftColorBrightness((__bridge CGColorRef)colors[0]) > 0.65f ? 0.0f : 1.0f;
    CGContextSetRGBStrokeColor(context, stroke, stroke, stroke, 0.13f);
    CGContextSetLineWidth(context, 1.0f);
    CGPathRef strokePath = TGStarGiftCreateRoundedPath(CGRectInset(rect, 0.5f, 0.5f), MAX(0.0f, radius - 0.5f));
    CGContextAddPath(context, strokePath);
    CGContextStrokePath(context);
    CGPathRelease(strokePath);
    CGImageRef output = CGBitmapContextCreateImage(context);
    UIImage *image = output != NULL ? [UIImage imageWithCGImage:output scale:scale orientation:UIImageOrientationUp] : nil;
    if (output != NULL)
        CGImageRelease(output);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    return image;
}

UIImage *TGStarGiftBackdropImage(CGSize size, UIColor *centerColor, UIColor *edgeColor, CGFloat cornerRadius)
{
    return TGStarGiftRenderBackdrop(size, [UIScreen mainScreen].scale, centerColor, edgeColor, cornerRadius);
}

static NSCache *TGStarGiftBackdropCache(void)
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSCache alloc] init];
        cache.totalCostLimit = 4 * 1024 * 1024;
    });
    return cache;
}

static UIImage *TGStarGiftPillImage(CGFloat alpha, CGFloat height)
{
    static NSMutableDictionary *images = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        images = [[NSMutableDictionary alloc] init];
    });
    NSString *key = [[NSString alloc] initWithFormat:@"%.2f:%.0f", alpha, height];
    UIImage *image = images[key];
    if (image == nil)
    {
        CGFloat radius = height / 2.0f;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(height + 1.0f, height), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.0f alpha:alpha].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, height, height));
        CGContextFillEllipseInRect(context, CGRectMake(1.0f, 0.0f, height, height));
        CGContextFillRect(context, CGRectMake(radius, 0.0f, 1.0f, height));
        image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:(NSInteger)radius topCapHeight:0];
        UIGraphicsEndImageContext();
        images[key] = image;
    }
    return image;
}

static void TGStarGiftAddRibbonPath(CGContextRef context)
{
    CGContextMoveToPoint(context, 52.376f, 24.376f);
    CGContextAddLineToPoint(context, 33.624f, 5.624f);
    CGContextAddCurveToPoint(context, 31.548f, 3.548f, 30.510f, 2.510f, 29.299f, 1.768f);
    CGContextAddCurveToPoint(context, 28.226f, 1.110f, 27.055f, 0.626f, 25.831f, 0.332f);
    CGContextAddCurveToPoint(context, 24.450f, 0.0f, 22.982f, 0.0f, 20.047f, 0.0f);
    CGContextAddLineToPoint(context, 7.725f, 0.0f);
    CGContextAddCurveToPoint(context, 5.302f, 0.0f, 4.091f, 0.0f, 3.530f, 0.479f);
    CGContextAddCurveToPoint(context, 3.043f, 0.895f, 2.784f, 1.519f, 2.835f, 2.157f);
    CGContextAddCurveToPoint(context, 2.892f, 2.892f, 3.749f, 3.749f, 5.463f, 5.463f);
    CGContextAddLineToPoint(context, 52.537f, 52.537f);
    CGContextAddCurveToPoint(context, 54.251f, 54.251f, 55.108f, 55.108f, 55.843f, 55.165f);
    CGContextAddCurveToPoint(context, 56.481f, 55.216f, 57.105f, 54.957f, 57.521f, 54.470f);
    CGContextAddCurveToPoint(context, 58.0f, 53.909f, 58.0f, 52.698f, 58.0f, 50.275f);
    CGContextAddLineToPoint(context, 58.0f, 37.953f);
    CGContextAddCurveToPoint(context, 58.0f, 35.018f, 58.0f, 33.550f, 57.668f, 32.169f);
    CGContextAddCurveToPoint(context, 57.374f, 30.945f, 56.890f, 29.774f, 56.232f, 28.701f);
    CGContextAddCurveToPoint(context, 55.490f, 27.490f, 54.452f, 26.452f, 52.376f, 24.376f);
    CGContextClosePath(context);
}

UIImage *TGStarGiftRibbonImage(UIColor *bottomRightColor, UIColor *topLeftColor)
{
    static NSMutableDictionary *images = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        images = [[NSMutableDictionary alloc] init];
    });
    NSString *key = [[NSString alloc] initWithFormat:@"%08x:%08x", TGColorHexCodeWithAlpha(bottomRightColor), TGColorHexCodeWithAlpha(topLeftColor)];
    UIImage *image = images[key];
    if (image == nil)
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(TGStarGiftRibbonSide, TGStarGiftRibbonSide), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        TGStarGiftAddRibbonPath(context);
        CGContextClip(context);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(__bridge id)bottomRightColor.CGColor, (__bridge id)topLeftColor.CGColor];
        CGFloat locations[] = {0.0f, 1.0f};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
        CGContextDrawLinearGradient(context, gradient, CGPointMake(TGStarGiftRibbonSide, TGStarGiftRibbonSide), CGPointZero, 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        images[key] = image;
    }
    return image;
}

static UIImage *TGStarGiftRibbonOutlineImage(UIColor *color)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(TGStarGiftRibbonOutlineSide, TGStarGiftRibbonOutlineSide), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, TGStarGiftRibbonOutlineSide / TGStarGiftRibbonSide, TGStarGiftRibbonOutlineSide / TGStarGiftRibbonSide);
    TGStarGiftAddRibbonPath(context);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillPath(context);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIFont *TGStarGiftMonospacedFont(CGFloat size)
{
    SEL selector = NSSelectorFromString(@"monospacedSystemFontOfSize:weight:");
    if ([UIFont respondsToSelector:selector])
        return ((UIFont *(*)(id, SEL, CGFloat, CGFloat))objc_msgSend)([UIFont class], selector, size, 0.3f);
    UIFont *font = [UIFont fontWithName:@"Menlo-Bold" size:size - 1.0f];
    return font ?: [UIFont fontWithName:@"Courier-Bold" size:size - 1.0f];
}

NSString *TGStarGiftCompactCount(int32_t count)
{
    NSString *separator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator] ?: @".";
    if (count >= 1000000)
    {
        int32_t remainder = (count % 1000000) / 100000;
        if (remainder != 0)
            return [[NSString alloc] initWithFormat:@"%d%@%dM", (int)(count / 1000000), separator, (int)remainder];
        return [[NSString alloc] initWithFormat:@"%dM", (int)(count / 1000000)];
    }
    if (count >= 1000)
    {
        int32_t remainder = (count % 1000) / 100;
        if (remainder != 0)
            return [[NSString alloc] initWithFormat:@"%d%@%dK", (int)(count / 1000), separator, (int)remainder];
        return [[NSString alloc] initWithFormat:@"%dK", (int)(count / 1000)];
    }
    return [[NSString alloc] initWithFormat:@"%d", (int)count];
}

NSString *TGStarGiftStarsString(int64_t stars)
{
    return [[NSString alloc] initWithFormat:@"★ %lld", stars];
}

NSString *TGStarGiftFormattedNumber(int64_t number)
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.usesGroupingSeparator = true;
    });
    return [formatter stringFromNumber:@(number)] ?: [[NSString alloc] initWithFormat:@"%lld", number];
}

int64_t TGStarGiftResaleStars(TGStarGift *gift)
{
    for (TGTLDynamicObject *amount in gift.resellAmounts)
    {
        if ([amount isKindOfClass:[TGTLDynamicObject class]] && [amount isConstructor:@"starsAmount"] && [amount int64Field:@"amount"] > 0)
            return [amount int64Field:@"amount"];
    }
    return 0;
}

UIColor *TGStarGiftMixedColor(UIColor *color, UIColor *other, CGFloat fraction)
{
    CGFloat r = 0.0f, g = 0.0f, b = 0.0f, a = 0.0f;
    CGFloat otherR = 0.0f, otherG = 0.0f, otherB = 0.0f, otherA = 0.0f;
    if (!TGColorGetRGBA(color, &r, &g, &b, &a) || !TGColorGetRGBA(other, &otherR, &otherG, &otherB, &otherA))
        return color;
    CGFloat keep = 1.0f - fraction;
    return [UIColor colorWithRed:r * keep + otherR * fraction green:g * keep + otherG * fraction blue:b * keep + otherB * fraction alpha:a * keep + otherA * fraction];
}

UIColor *TGStarGiftMultipliedColor(UIColor *color, CGFloat hue, CGFloat saturation, CGFloat brightness)
{
    CGFloat h = 0.0f, s = 0.0f, v = 0.0f, a = 0.0f;
    if (!TGColorGetHSBA(color, &h, &s, &v, &a))
        return color;
    return [UIColor colorWithHue:MAX(0.0f, MIN(1.0f, h * hue)) saturation:MAX(0.0f, MIN(1.0f, s * saturation)) brightness:MAX(0.0f, MIN(1.0f, v * brightness)) alpha:a];
}

UIImage *TGStarGiftAnonymousAvatarImage(CGFloat diameter)
{
    static NSMutableDictionary *images = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        images = [[NSMutableDictionary alloc] init];
    });
    NSNumber *key = @(diameter);
    UIImage *image = images[key];
    if (image == nil)
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter, diameter), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
        CGContextClip(context);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[(__bridge id)UIColorRGB(0x72d5fd).CGColor, (__bridge id)UIColorRGB(0x2a9ef1).CGColor];
        CGFloat locations[] = {0.0f, 1.0f};
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
        CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(0.0f, diameter), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
        UIImage *icon = TGTintedImage(TGImageNamed(@"StarGiftAnonymousIcon"), [UIColor whiteColor]);
        CGFloat iconSide = diameter * 0.8f;
        [icon drawInRect:CGRectMake(CGFloor((diameter - iconSide) / 2.0f), CGFloor((diameter - iconSide) / 2.0f), iconSide, iconSide)];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        if (image != nil)
            images[key] = image;
    }
    return image;
}

void TGStarGiftSetPeerAvatar(TGLetteredAvatarView *avatarView, int64_t peerId, CGFloat diameter, TGPresentation *presentation)
{
    CGSize size = CGSizeMake(diameter, diameter);
    NSString *filter = [[NSString alloc] initWithFormat:@"circle:%dx%d", (int)diameter, (int)diameter];
    UIImage *placeholder = [presentation.images avatarPlaceholderWithDiameter:diameter];
    if (TGPeerIdIsUser(peerId))
    {
        TGUser *user = [TGDatabaseInstance() loadUser:peerId];
        if (user.photoUrlSmall.length != 0)
            [avatarView loadImage:user.photoFullUrlSmall filter:filter placeholder:placeholder];
        else
            [avatarView loadUserPlaceholderWithSize:size uid:peerId firstName:user.firstName lastName:user.lastName placeholder:placeholder];
        return;
    }
    TGConversation *conversation = [TGDatabaseInstance() loadConversationWithId:peerId];
    if (conversation.chatPhotoSmall.length != 0)
        [avatarView loadImage:conversation.chatPhotoFullSmall filter:filter placeholder:placeholder];
    else
        [avatarView loadGroupPlaceholderWithSize:size conversationId:peerId title:conversation.chatTitle placeholder:placeholder];
}

@interface TGStarGiftTileView ()
{
    UIView *_boxView;
    UIImageView *_backgroundView;
    TGStarGiftCoverView *_coverView;
    TGAnimatedStickerView *_stickerView;
    TGImageView *_staticStickerView;
    UILabel *_captionLabel;
    UIImageView *_captionBackgroundView;
    UILabel *_ribbonLabel;
    UIImageView *_ribbonBackgroundView;
    UIImageView *_ribbonView;
    UIImageView *_ribbonOutlineView;
    TGLetteredAvatarView *_avatarView;
    UIImageView *_pinView;
    UIView *_hiddenBackgroundView;
    UIImageView *_hiddenIconView;
    UILabel *_resaleLabel;
    UIImageView *_resaleBackgroundView;
    TGStarGift *_gift;
    TGSavedStarGift *_savedGift;
    NSString *_backgroundKey;
    bool _stickerPlayed;
}

@property (nonatomic, strong) NSString *viewIdentifier;
@property (nonatomic, strong) NSString *viewStateIdentifier;

- (void)updateBackground;
- (void)updateStickerPlayback;

@end

@implementation TGStarGiftTileView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _animated = true;

        _boxView = [[UIView alloc] init];
        _boxView.userInteractionEnabled = false;
        _boxView.clipsToBounds = true;
        _boxView.layer.cornerRadius = TGStarGiftTileCornerRadius;
        [self addSubview:_boxView];

        _backgroundView = [[UIImageView alloc] init];
        [_boxView addSubview:_backgroundView];

        _coverView = [[TGStarGiftCoverView alloc] init];
        _coverView.hidden = true;
        [_boxView addSubview:_coverView];

        _stickerView = [[TGAnimatedStickerView alloc] init];
        _stickerView.loops = true;
        [_boxView addSubview:_stickerView];

        _staticStickerView = [[TGImageView alloc] init];
        _staticStickerView.contentMode = UIViewContentModeScaleAspectFit;
        _staticStickerView.hidden = true;
        [_boxView addSubview:_staticStickerView];

        _captionBackgroundView = [[UIImageView alloc] init];
        [_boxView addSubview:_captionBackgroundView];

        _captionLabel = [[UILabel alloc] init];
        _captionLabel.backgroundColor = [UIColor clearColor];
        _captionLabel.font = TGBoldSystemFontOfSize(12.0f);
        _captionLabel.textAlignment = NSTextAlignmentCenter;
        _captionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [_boxView addSubview:_captionLabel];

        _ribbonBackgroundView = [[UIImageView alloc] initWithImage:TGStarGiftPillImage(0.35f, 18.0f)];
        [_boxView addSubview:_ribbonBackgroundView];

        _ribbonOutlineView = [[UIImageView alloc] init];
        _ribbonOutlineView.userInteractionEnabled = false;
        _ribbonOutlineView.hidden = true;
        [self addSubview:_ribbonOutlineView];

        _ribbonView = [[UIImageView alloc] init];
        _ribbonView.userInteractionEnabled = false;
        _ribbonView.hidden = true;
        [self addSubview:_ribbonView];

        _ribbonLabel = [[UILabel alloc] init];
        _ribbonLabel.backgroundColor = [UIColor clearColor];
        _ribbonLabel.textColor = [UIColor whiteColor];
        _ribbonLabel.font = TGBoldSystemFontOfSize(10.0f);
        _ribbonLabel.textAlignment = NSTextAlignmentCenter;
        _ribbonLabel.userInteractionEnabled = false;
        [self addSubview:_ribbonLabel];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    _backgroundKey = nil;
    if (_savedGift != nil)
        [self setSavedGift:_savedGift];
    [self setNeedsLayout];
}

- (void)setProfileStyle:(bool)profileStyle
{
    _profileStyle = profileStyle;
    _boxView.layer.cornerRadius = profileStyle ? TGStarGiftProfileCornerRadius : TGStarGiftTileCornerRadius;
    _stickerView.loops = !profileStyle;
    _stickerView.usesSourceFrameRate = profileStyle;
    _stickerView.restsOnLastFrame = profileStyle;
    _backgroundKey = nil;
    [self setNeedsLayout];
}

- (void)updateSticker:(TGStarGift *)gift
{
    TGDocumentMediaAttachment *sticker = gift.sticker;
    bool animatedSticker = sticker != nil && [TGAnimatedStickerView isAnimatedStickerDocument:sticker];
    _stickerView.hidden = !animatedSticker;
    _staticStickerView.hidden = animatedSticker || sticker == nil;
    if (animatedSticker)
    {
        [_stickerView setDocument:sticker placeholderUri:[TGAnimatedStickerView placeholderUriForDocument:sticker size:CGSizeMake(128.0f, 128.0f)]];
        _stickerPlayed = false;
        [self updateStickerPlayback];
    }
    else
    {
        [_stickerView reset];
        if (sticker != nil)
            [_staticStickerView loadUri:[TGAnimatedStickerView placeholderUriForDocument:sticker size:CGSizeMake(128.0f, 128.0f)] withOptions:@{}];
        else
            [_staticStickerView reset];
    }
}

- (void)applyGift:(TGStarGift *)gift
{
    bool changed = _gift != gift;
    _gift = gift;
    _backgroundKey = nil;
    bool cover = gift.unique && gift.hasBackdrop;
    _coverView.hidden = !cover;
    _backgroundView.hidden = cover;
    [_coverView setGift:cover ? gift : nil];
    if (changed)
        [self updateSticker:gift];
}

- (void)setGift:(TGStarGift *)gift caption:(NSString *)caption
{
    _savedGift = nil;
    [self applyGift:gift];
    _captionLabel.text = caption;
    _captionLabel.hidden = caption.length == 0 || gift.unique;
    if (_profileStyle)
    {
        _captionLabel.font = TGMediumSystemFontOfSize(13.0f);
        _captionLabel.textColor = _presentation.pallete.collectionMenuAccentColor;
        _captionBackgroundView.hidden = true;
    }
    else
    {
        _captionLabel.font = TGBoldSystemFontOfSize(12.0f);
        _captionLabel.textColor = gift.unique ? [UIColor whiteColor] : UIColorRGB(0xffd66e);
        _captionBackgroundView.image = TGStarGiftPillImage(gift.hasBackdrop ? 0.38f : 0.10f, 20.0f);
        _captionBackgroundView.hidden = _captionLabel.hidden;
    }
    if (gift.unique)
        _ribbonLabel.text = [[NSString alloc] initWithFormat:@"#%d", (int)gift.number];
    else if (gift.soldOut)
        _ribbonLabel.text = TGLocalized(@"OnegramGifts.SoldOut");
    else if (gift.limited && gift.availabilityTotal > 0)
        _ribbonLabel.text = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.LimitedRibbon"), TGStarGiftCompactCount(gift.availabilityTotal)];
    else
        _ribbonLabel.text = nil;
    _ribbonLabel.font = TGBoldSystemFontOfSize(10.0f);
    _ribbonLabel.transform = CGAffineTransformIdentity;
    _ribbonLabel.hidden = _ribbonLabel.text.length == 0 || _profileStyle;
    _ribbonBackgroundView.hidden = _ribbonLabel.hidden;
    _ribbonView.hidden = true;
    _ribbonOutlineView.hidden = true;
    _avatarView.hidden = true;
    _pinView.hidden = true;
    _hiddenBackgroundView.hidden = true;
    _hiddenIconView.hidden = true;
    _resaleLabel.hidden = true;
    _resaleBackgroundView.hidden = true;
    [self setNeedsLayout];
}

- (void)setSavedGift:(TGSavedStarGift *)savedGift
{
    _savedGift = savedGift;
    TGStarGift *gift = savedGift.gift;
    [self applyGift:gift];
    TGPresentationPallete *pallete = _presentation.pallete;

    _captionLabel.hidden = true;
    _captionBackgroundView.hidden = true;
    _ribbonBackgroundView.hidden = true;

    NSString *ribbonText = nil;
    UIFont *ribbonFont = TGSemiboldSystemFontOfSize(9.0f);
    UIColor *ribbonBottomColor = nil;
    UIColor *ribbonTopColor = nil;
    bool ribbonOutline = false;
    if (gift.unique)
    {
        if (gift.resellAmounts.count != 0)
        {
            ribbonText = TGLocalized(@"OnegramGifts.SaleRibbon");
            ribbonFont = TGSemiboldSystemFontOfSize(10.0f);
            ribbonBottomColor = UIColorRGB(0x4bb121);
            ribbonTopColor = UIColorRGB(0x53d654);
            ribbonOutline = true;
        }
        else
        {
            ribbonText = [[NSString alloc] initWithFormat:@"#%d", (int)gift.number];
            ribbonFont = TGStarGiftMonospacedFont(10.0f);
            UIColor *outerColor = gift.hasBackdrop ? TGStarGiftColor(gift.backdropEdgeColor) : UIColorRGB(0x34a4fc);
            ribbonBottomColor = TGStarGiftMultipliedColor(outerColor, 0.97f, 1.45f, 0.89f);
            ribbonTopColor = TGStarGiftMultipliedColor(outerColor, 1.01f, 1.22f, 1.04f);
        }
    }
    else if (gift.availabilityTotal > 0)
    {
        ribbonText = [[NSString alloc] initWithFormat:TGLocalized(@"OnegramGifts.LimitedRibbon"), TGStarGiftCompactCount(gift.availabilityTotal)];
        ribbonBottomColor = pallete.isDark ? UIColorRGB(0x142e42) : UIColorRGB(0x34a4fc);
        ribbonTopColor = pallete.isDark ? UIColorRGB(0x354f5b) : UIColorRGB(0x6fd3ff);
    }
    _ribbonLabel.transform = CGAffineTransformIdentity;
    _ribbonLabel.text = ribbonText;
    _ribbonLabel.font = ribbonFont;
    [_ribbonLabel sizeToFit];
    _ribbonLabel.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_4);
    _ribbonLabel.hidden = ribbonText.length == 0;
    _ribbonView.hidden = _ribbonLabel.hidden;
    if (!_ribbonView.hidden)
        _ribbonView.image = TGStarGiftRibbonImage(ribbonBottomColor, ribbonTopColor);
    _ribbonOutlineView.hidden = _ribbonView.hidden || !ribbonOutline;
    if (!_ribbonOutlineView.hidden)
        _ribbonOutlineView.image = TGStarGiftRibbonOutlineImage(pallete.collectionMenuBackgroundColor);

    int64_t avatarPeerId = 0;
    bool anonymous = false;
    if (!savedGift.pinnedToTop)
    {
        if (gift.unique)
        {
            if (savedGift.message.length != 0 && !savedGift.nameHidden)
                avatarPeerId = savedGift.fromPeerId;
        }
        else if (savedGift.fromPeerId != 0)
            avatarPeerId = savedGift.fromPeerId;
        else
            anonymous = true;
    }
    if (avatarPeerId != 0 || anonymous)
    {
        if (_avatarView == nil)
        {
            _avatarView = [[TGLetteredAvatarView alloc] init];
            [_avatarView setSingleFontSize:8.0f doubleFontSize:8.0f useBoldFont:true];
            _avatarView.fadeTransition = true;
            [_boxView addSubview:_avatarView];
        }
        _avatarView.hidden = false;
        if (anonymous)
            [_avatarView loadImage:TGStarGiftAnonymousAvatarImage(20.0f)];
        else
            TGStarGiftSetPeerAvatar(_avatarView, avatarPeerId, 20.0f, _presentation);
    }
    else
        _avatarView.hidden = true;

    if (savedGift.pinnedToTop)
    {
        if (_pinView == nil)
        {
            _pinView = [[UIImageView alloc] init];
            [_boxView addSubview:_pinView];
        }
        _pinView.image = TGTintedImage(TGImageNamed(@"StarGiftPinnedIcon"), gift.unique && gift.hasBackdrop ? [UIColor whiteColor] : pallete.collectionMenuVariantColor);
        _pinView.hidden = false;
    }
    else
        _pinView.hidden = true;

    if (savedGift.unsaved)
    {
        if (_hiddenBackgroundView == nil)
        {
            _hiddenBackgroundView = [[UIView alloc] init];
            _hiddenBackgroundView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.45f];
            _hiddenBackgroundView.layer.cornerRadius = 15.0f;
            [_boxView addSubview:_hiddenBackgroundView];
            _hiddenIconView = [[UIImageView alloc] initWithImage:TGTintedImage(TGImageNamed(@"StarGiftHiddenIcon"), [UIColor whiteColor])];
            [_boxView addSubview:_hiddenIconView];
        }
        _hiddenBackgroundView.hidden = false;
        _hiddenIconView.hidden = false;
    }
    else
    {
        _hiddenBackgroundView.hidden = true;
        _hiddenIconView.hidden = true;
    }

    int64_t resaleStars = gift.unique ? TGStarGiftResaleStars(gift) : 0;
    if (resaleStars > 0)
    {
        if (_resaleLabel == nil)
        {
            _resaleBackgroundView = [[UIImageView alloc] init];
            [_boxView addSubview:_resaleBackgroundView];
            _resaleLabel = [[UILabel alloc] init];
            _resaleLabel.backgroundColor = [UIColor clearColor];
            _resaleLabel.textColor = [UIColor whiteColor];
            _resaleLabel.font = TGSemiboldSystemFontOfSize(11.0f);
            [_boxView addSubview:_resaleLabel];
        }
        _resaleLabel.text = [[NSString alloc] initWithFormat:@"★ %@", TGStarGiftFormattedNumber(resaleStars)];
        [_resaleLabel sizeToFit];
        _resaleBackgroundView.image = TGStarGiftPillImage(0.3f, CGCeil(_resaleLabel.frame.size.height) + 8.0f);
        _resaleLabel.hidden = false;
        _resaleBackgroundView.hidden = false;
    }
    else
    {
        _resaleLabel.hidden = true;
        _resaleBackgroundView.hidden = true;
    }
    [self setNeedsLayout];
}

- (void)willBecomeRecycled
{
    [self removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    self.animated = false;
}

- (void)updateStickerPlayback
{
    bool active = _animated && !self.hidden && self.window != nil;
    if (!_profileStyle)
        _stickerView.playing = active;
    else if (!active)
        _stickerView.playing = false;
    else if (!_stickerPlayed)
    {
        _stickerPlayed = true;
        [_stickerView restart];
    }
}

- (void)setAnimated:(bool)animated
{
    _animated = animated;
    [self updateStickerPlayback];
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    if (self.window == nil)
        _stickerPlayed = false;
    [self updateStickerPlayback];
}

- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];
    [self updateStickerPlayback];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    _backgroundView.alpha = highlighted ? 0.7f : 1.0f;
    _coverView.alpha = _backgroundView.alpha;
}

- (void)updateBackground
{
    CGSize size = self.bounds.size;
    if (size.width < 1.0f || size.height < 1.0f || !_coverView.hidden)
        return;
    if (_profileStyle)
    {
        _backgroundKey = nil;
        _backgroundView.image = nil;
        _backgroundView.backgroundColor = _presentation.pallete.collectionMenuCellBackgroundColor;
        return;
    }
    _backgroundView.backgroundColor = nil;
    UIColor *centerColor = nil;
    UIColor *edgeColor = nil;
    if (_gift.hasBackdrop)
    {
        centerColor = TGStarGiftColor(_gift.backdropCenterColor);
        edgeColor = TGStarGiftColor(_gift.backdropEdgeColor);
        _captionLabel.textColor = [UIColor whiteColor];
    }
    else
    {
        UIColor *cellColor = _presentation.pallete.collectionMenuCellBackgroundColor ?: [UIColor colorWithWhite:0.22f alpha:1.0f];
        UIColor *outerColor = _presentation.pallete.collectionMenuBackgroundColor ?: [UIColor blackColor];
        CGFloat r = 0.0f, g = 0.0f, b = 0.0f;
        CGFloat outerR = 0.0f, outerG = 0.0f, outerB = 0.0f;
        TGStarGiftColorComponents(cellColor.CGColor, &r, &g, &b);
        TGStarGiftColorComponents(outerColor.CGColor, &outerR, &outerG, &outerB);
        centerColor = [UIColor colorWithRed:r * 0.78f + 0.22f * (r > 0.5f ? 0.82f : 0.36f) green:g * 0.78f + 0.22f * (g > 0.5f ? 0.83f : 0.40f) blue:b * 0.78f + 0.22f * (b > 0.5f ? 0.88f : 0.52f) alpha:1.0f];
        edgeColor = [UIColor colorWithRed:outerR * 0.35f + r * 0.65f green:outerG * 0.35f + g * 0.65f blue:outerB * 0.35f + b * 0.65f alpha:1.0f];
    }
    CGFloat scale = MAX(1.0f, MIN(2.0f, [UIScreen mainScreen].scale));
    NSString *key = [[NSString alloc] initWithFormat:@"%dx%d:%.1f:%@:%@", (int)ceil(size.width), (int)ceil(size.height), scale, centerColor, edgeColor];
    if ([_backgroundKey isEqualToString:key])
        return;
    _backgroundKey = key;
    UIImage *image = [TGStarGiftBackdropCache() objectForKey:key];
    if (image == nil)
    {
        image = TGStarGiftRenderBackdrop(size, scale, centerColor, edgeColor, TGStarGiftTileCornerRadius);
        if (image != nil)
            [TGStarGiftBackdropCache() setObject:image forKey:key cost:(NSUInteger)(ceil(size.width) * ceil(size.height) * scale * scale * 4.0f)];
    }
    _backgroundView.image = image;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    _boxView.frame = bounds;
    _backgroundView.frame = bounds;
    _coverView.frame = bounds;
    [self updateBackground];

    CGRect stickerFrame;
    if (_profileStyle)
    {
        CGFloat stickerSide = CGFloor(88.0f * bounds.size.height / 116.0f);
        stickerFrame = CGRectMake(CGFloor((bounds.size.width - stickerSide) / 2.0f), CGFloor((bounds.size.height - stickerSide) / 2.0f), stickerSide, stickerSide);
    }
    else
    {
        CGFloat bottomInset = _captionLabel.hidden ? 12.0f : 34.0f;
        CGFloat stickerSide = MAX(0.0f, MIN(bounds.size.width - 16.0f, bounds.size.height - bottomInset));
        stickerFrame = CGRectMake(CGFloor((bounds.size.width - stickerSide) / 2.0f), CGFloor((bounds.size.height - bottomInset - stickerSide) / 2.0f) + 5.0f, stickerSide, stickerSide);
    }
    _stickerView.frame = stickerFrame;
    _staticStickerView.frame = stickerFrame;
    _coverView.avatarCenter = CGPointMake(bounds.size.width / 2.0f, CGRectGetMidY(stickerFrame));
    _coverView.defaultHeight = bounds.size.height;
    _coverView.gradientFrame = CGRectMake(CGFloor((bounds.size.width - bounds.size.height) / 2.0f), 0.0f, bounds.size.height, bounds.size.height);

    if (_profileStyle)
    {
        CGFloat captionHeight = 20.0f;
        _captionLabel.frame = CGRectMake(6.0f, bounds.size.height - captionHeight - 10.0f, bounds.size.width - 12.0f, captionHeight);
    }
    else
    {
        CGSize captionSize = [_captionLabel sizeThatFits:CGSizeMake(MAX(0.0f, bounds.size.width - 12.0f), 20.0f)];
        CGFloat captionWidth = MIN(bounds.size.width - 12.0f, MAX(40.0f, captionSize.width + 16.0f));
        _captionLabel.frame = CGRectMake(CGFloor((bounds.size.width - captionWidth) / 2.0f), bounds.size.height - 26.0f, captionWidth, 20.0f);
        _captionBackgroundView.frame = _captionLabel.frame;
        CGSize ribbonSize = [_ribbonLabel sizeThatFits:CGSizeMake(bounds.size.width - 12.0f, 18.0f)];
        CGFloat ribbonWidth = MIN(bounds.size.width - 12.0f, MAX(32.0f, ribbonSize.width + 12.0f));
        _ribbonLabel.frame = CGRectMake(bounds.size.width - ribbonWidth - 6.0f, 6.0f, ribbonWidth, 18.0f);
        _ribbonBackgroundView.frame = _ribbonLabel.frame;
        return;
    }

    _ribbonView.frame = CGRectMake(bounds.size.width - TGStarGiftRibbonSide + 2.0f, -2.0f, TGStarGiftRibbonSide, TGStarGiftRibbonSide);
    CGPoint ribbonCenter = CGPointMake(CGRectGetMidX(_ribbonView.frame), CGRectGetMidY(_ribbonView.frame) + 2.0f);
    _ribbonOutlineView.frame = CGRectMake(ribbonCenter.x - TGStarGiftRibbonOutlineSide / 2.0f, ribbonCenter.y - TGStarGiftRibbonOutlineSide / 2.0f, TGStarGiftRibbonOutlineSide, TGStarGiftRibbonOutlineSide);
    _ribbonLabel.center = CGPointMake(bounds.size.width - 20.0f, 20.0f);

    _avatarView.frame = CGRectMake(5.0f, 5.0f, 20.0f, 20.0f);
    _pinView.frame = CGRectMake(3.0f, 3.0f, 24.0f, 24.0f);
    CGPoint stickerCenter = CGPointMake(CGRectGetMidX(stickerFrame), CGRectGetMidY(stickerFrame));
    _hiddenBackgroundView.frame = CGRectMake(stickerCenter.x - 15.0f, stickerCenter.y - 15.0f, 30.0f, 30.0f);
    _hiddenIconView.frame = _hiddenBackgroundView.frame;

    if (_resaleLabel != nil && !_resaleLabel.hidden)
    {
        CGSize resaleSize = _resaleLabel.frame.size;
        CGRect resaleFrame = CGRectMake(CGFloor((bounds.size.width - resaleSize.width) / 2.0f), bounds.size.height - 20.0f, resaleSize.width, resaleSize.height);
        _resaleLabel.frame = resaleFrame;
        _resaleBackgroundView.frame = CGRectInset(resaleFrame, -6.0f, -4.0f);
    }
}

@end
