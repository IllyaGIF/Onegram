#import "OGProfileHeader.h"
#import "../Core/OGTheme.h"
#import "../Core/OGAssets.h"
#import "../Core/OGProfileAppearance.h"
#import "../../OnegramPlatform/OGPlatformVersion.h"
#import "../../OnegramPlatform/OGPlatformGraphics.h"
#import "../Core/OGSurfaceStyle.h"
#import "../Core/OGSurfaceRenderer.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static char OGProfileHeaderMusicCardStyleKey;
static char OGProfileHeaderMusicPlayImageKey;

static UIEdgeInsets OGProfileHeaderStyleOutsets(OGSurfaceStyle *style)
{
    if (style == nil)
        return UIEdgeInsetsZero;
    UIEdgeInsets outsets = [style dropShadowOutsets];
    return UIEdgeInsetsMake(ceilf(outsets.top), ceilf(outsets.left), ceilf(outsets.bottom), ceilf(outsets.right));
}

static UIImage *OGProfileHeaderSurfaceImage(OGTheme *theme, OGSurfaceStyle *style, CGSize size, UIEdgeInsets *outsets)
{
    UIEdgeInsets styleOutsets = OGProfileHeaderStyleOutsets(style);
    if (outsets != NULL)
        *outsets = styleOutsets;
    if (style == nil || size.width < 1.0f || size.height < 1.0f)
        return nil;
    CGSize imageSize = CGSizeMake(styleOutsets.left + size.width + styleOutsets.right, styleOutsets.top + size.height + styleOutsets.bottom);
    return [theme.surfaceRenderer imageWithStyle:style size:imageSize bodyFrame:CGRectMake(styleOutsets.left, styleOutsets.top, size.width, size.height)];
}

@implementation OGProfileHeader

+ (OGSurfaceStyle *)legacyMusicCardStyleWithTheme:(OGTheme *)theme
{
    OGSurfaceStyle *cachedStyle = objc_getAssociatedObject(theme, &OGProfileHeaderMusicCardStyleKey);
    if (cachedStyle != nil)
        return cachedStyle;
    OGProfileAppearance *appearance = theme.profileAppearance;
    OGSurfaceStyle *style = [appearance.cardSurfaceStyle copy];
    if (appearance.cardMusicLayer != nil)
        style.layers = [(style.layers ?: @[]) arrayByAddingObject:appearance.cardMusicLayer];
    objc_setAssociatedObject(theme, &OGProfileHeaderMusicCardStyleKey, style, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return style;
}

+ (UIImage *)legacyCardImageWithTheme:(OGTheme *)theme size:(CGSize)size hasMusic:(BOOL)hasMusic outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [OGTheme brandedTheme];
    OGSurfaceStyle *style = hasMusic ? [self legacyMusicCardStyleWithTheme:theme] : theme.profileAppearance.cardSurfaceStyle;
    return OGProfileHeaderSurfaceImage(theme, style, size, outsets);
}

+ (UIImage *)legacyAvatarOverlayImageWithTheme:(OGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [OGTheme brandedTheme];
    return OGProfileHeaderSurfaceImage(theme, theme.profileAppearance.avatarOverlaySurfaceStyle, size, outsets);
}

+ (UIImage *)legacyStatusBackgroundImageWithTheme:(OGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [OGTheme brandedTheme];
    return OGProfileHeaderSurfaceImage(theme, theme.profileAppearance.statusSurfaceStyle, size, outsets);
}

+ (UIImage *)legacyMusicPlayImageWithTheme:(OGTheme *)theme outsets:(UIEdgeInsets *)outsets
{
    if (theme == nil)
        theme = [OGTheme brandedTheme];
    OGProfileAppearance *appearance = theme.profileAppearance;
    UIEdgeInsets circleOutsets = UIEdgeInsetsZero;
    CGSize circleSize = CGSizeMake(appearance.musicArrowSize, appearance.musicArrowSize);
    UIImage *circleImage = OGProfileHeaderSurfaceImage(theme, appearance.musicPlaySurfaceStyle, circleSize, &circleOutsets);
    if (outsets != NULL)
        *outsets = circleOutsets;

    UIImage *cachedImage = objc_getAssociatedObject(theme, &OGProfileHeaderMusicPlayImageKey);
    if (cachedImage != nil)
        return cachedImage;
    if (circleImage == nil)
        return nil;

    UIImage *glyphTemplate = [theme.assets imageNamed:appearance.musicPlayGlyphAssetName inDirectory:appearance.musicPlayGlyphResourceDirectory];
    UIEdgeInsets glyphOutsets = [appearance.musicPlayGlyphShadow outsets];
    glyphOutsets = UIEdgeInsetsMake(ceilf(glyphOutsets.top), ceilf(glyphOutsets.left), ceilf(glyphOutsets.bottom), ceilf(glyphOutsets.right));
    UIImage *glyphImage = glyphTemplate != nil ? [theme.surfaceRenderer iconImageWithTemplate:glyphTemplate gradientColors:appearance.musicPlayGlyphColors locations:appearance.musicPlayGlyphLocations shadow:appearance.musicPlayGlyphShadow outsets:glyphOutsets] : nil;

    UIGraphicsBeginImageContextWithOptions(circleImage.size, false, circleImage.scale);
    [circleImage drawAtPoint:CGPointZero];
    [glyphImage drawAtPoint:CGPointMake(circleOutsets.left + appearance.musicPlayGlyphOrigin.x - glyphOutsets.left, circleOutsets.top + appearance.musicPlayGlyphOrigin.y - glyphOutsets.top)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (image != nil)
        objc_setAssociatedObject(theme, &OGProfileHeaderMusicPlayImageKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return image;
}

+ (UIFont *)legacyNameFontWithTheme:(OGTheme *)theme size:(CGFloat)size
{
    if (theme == nil)
        theme = [OGTheme brandedTheme];
    NSString *fontName = theme.profileAppearance.nameFontName;
    UIFont *font = fontName.length != 0 ? [UIFont fontWithName:fontName size:size] : nil;
    return font != nil ? font : [UIFont boldSystemFontOfSize:size];
}

+ (void)applyLegacyAvatarStyleWithTheme:(OGTheme *)theme view:(UIView *)view
{
    if (view == nil)
        return;
    if (theme == nil)
        theme = [OGTheme brandedTheme];
    OGProfileAppearance *appearance = theme.profileAppearance;
    view.clipsToBounds = true;
    view.layer.cornerRadius = appearance.avatarCornerRadius;
    view.layer.borderWidth = 0.0f;
}

+ (void)applyLegacyReflectionStyleWithTheme:(OGTheme *)theme imageView:(UIImageView *)imageView
{
    if (imageView == nil)
        return;
    if (theme == nil)
        theme = [OGTheme brandedTheme];
    OGProfileAppearance *appearance = theme.profileAppearance;
    imageView.alpha = appearance.reflectionAlpha;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = true;
    imageView.layer.cornerRadius = appearance.avatarCornerRadius;
    CAGradientLayer *mask = [imageView.layer.mask isKindOfClass:[CAGradientLayer class]] ? (CAGradientLayer *)imageView.layer.mask : [CAGradientLayer layer];
    mask.colors = @[(id)[UIColor colorWithWhite:1.0f alpha:0.0f].CGColor, (id)[UIColor colorWithWhite:1.0f alpha:0.0f].CGColor, (id)[UIColor colorWithWhite:1.0f alpha:appearance.reflectionMaskAlpha].CGColor];
    mask.locations = @[@0.0f, @(1.0f - appearance.reflectionMaskLength), @1.0f];
    imageView.layer.mask = mask;
    OGPlatformSetLayerRasterization(imageView.layer, YES, OGPlatformScreenScale());
}

@end
