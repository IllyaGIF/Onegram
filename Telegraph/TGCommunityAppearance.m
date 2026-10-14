#import "TGCommunityAppearance.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "TGPresentation.h"

static const CGFloat TGCommunityIndicatorReferenceWidth = 4.0f;
static const CGFloat TGCommunityIndicatorReferenceScreenWidth = 320.0f;

static void TGCommunityGradientColors(TGPresentation *presentation, uint32_t *leftColor, uint32_t *rightColor)
{
    bool dark = presentation.pallete.isDark;
    if ([TGPresentation interfaceStyle] == TGInterfaceStyleModern)
    {
        uint32_t color = dark ? 0xb45924 : 0x2f9622;
        *leftColor = color;
        *rightColor = color;
    }
    else
    {
        *leftColor = dark ? 0xbe6b3c : 0x3cbe3c;
        *rightColor = dark ? 0xab470d : 0x226f08;
    }
}

static UIImage *TGCommunityHorizontalGradientImage(uint32_t leftColor, uint32_t rightColor, CGFloat width)
{
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        cache = [[NSMutableDictionary alloc] init];
    });

    width = MAX(1.0f, width);
    NSString *key = [[NSString alloc] initWithFormat:@"%06x:%06x:%.2f", leftColor, rightColor, width];
    @synchronized (cache)
    {
        UIImage *cached = cache[key];
        if (cached != nil)
            return cached;
    }

    CGSize size = CGSizeMake(width, 1.0f);
    UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {
        ((leftColor >> 16) & 0xff) / 255.0f, ((leftColor >> 8) & 0xff) / 255.0f, (leftColor & 0xff) / 255.0f, 1.0f,
        ((rightColor >> 16) & 0xff) / 255.0f, ((rightColor >> 8) & 0xff) / 255.0f, (rightColor & 0xff) / 255.0f, 1.0f
    };
    CGFloat locations[] = {0.0f, 1.0f};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(size.width, 0.0f), kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (image != nil)
    {
        @synchronized (cache)
        {
            cache[key] = image;
        }
    }
    return image;
}

@implementation TGCommunityAppearance

+ (CGFloat)indicatorWidthForContainerWidth:(CGFloat)containerWidth
{
    return MAX(1.0f, CGRound(TGCommunityIndicatorReferenceWidth * containerWidth / TGCommunityIndicatorReferenceScreenWidth));
}

+ (CGFloat)contentInsetForContainerWidth:(CGFloat)containerWidth avatarInset:(CGFloat)avatarInset
{
    CGFloat width = [self indicatorWidthForContainerWidth:containerWidth];
    CGFloat inset = MAX(width / 2.0f, width * 2.0f - avatarInset);
    return TGScreenPixelFloor(inset + TGScreenPixel / 2.0f);
}

+ (UIImage *)indicatorImageWithWidth:(CGFloat)width presentation:(TGPresentation *)presentation
{
    uint32_t leftColor = 0;
    uint32_t rightColor = 0;
    TGCommunityGradientColors(presentation, &leftColor, &rightColor);
    return TGCommunityHorizontalGradientImage(leftColor, rightColor, width);
}

+ (UIColor *)swipeButtonColorWithWidth:(CGFloat)width presentation:(TGPresentation *)presentation
{
    uint32_t leftColor = 0;
    uint32_t rightColor = 0;
    TGCommunityGradientColors(presentation, &leftColor, &rightColor);
    if (leftColor == rightColor)
        return UIColorRGB(leftColor);

    UIImage *image = TGCommunityHorizontalGradientImage(leftColor, rightColor, width);
    return image != nil ? [UIColor colorWithPatternImage:image] : UIColorRGB(leftColor);
}

@end
