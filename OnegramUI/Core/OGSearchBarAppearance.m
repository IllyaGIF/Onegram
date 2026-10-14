#import "OGSearchBarAppearance.h"
#import "OGSurfaceStyle.h"

static UIColor *OGSearchBarRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static OGSurfaceStyle *OGSearchBarTextureStyle(NSString *assetName, CGFloat referenceWidth)
{
    OGSurfaceStyle *style = [[OGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = assetName;
    style.textureReferenceWidth = referenceWidth;
    return style;
}

@implementation OGSearchBarAppearance

+ (OGSearchBarAppearance *)contactAppearanceDark:(BOOL)dark
{
    OGSearchBarAppearance *appearance = [self brandedAppearanceDark:NO];
    UIColor *bandColor = dark ? OGSearchBarRGB(53.0f, 53.0f, 53.0f, 1.0f) : appearance.backdropColor;
    appearance.backgroundSurfaceStyle.fillColor = bandColor;
    appearance.backgroundSurfaceStyle.shadows = @[
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.2f] offset:CGSizeMake(0.0f, 0.5f) blur:0.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:dark ? 0.7f : 0.1f] offset:CGSizeMake(0.0f, -1.0f) blur:0.0f]
    ];
    appearance.backdropColor = bandColor;
    appearance.textColor = [UIColor blackColor];
    return appearance;
}

+ (OGSearchBarAppearance *)brandedAppearanceDark:(BOOL)dark
{
    OGSearchBarAppearance *appearance = [[OGSearchBarAppearance alloc] init];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];

    OGSurfaceStyle *background = nil;
    OGSurfaceStyle *field = nil;
    if (dark)
    {
        background = OGSearchBarTextureStyle(@"alcantara.png", 165.0f);
        background.textureTiled = YES;

        field = OGSearchBarTextureStyle(@"list", 320.0f);
        field.textureContrast = 2.0f;
        field.textureBias = -1.0094f;
        field.shadows = @[
            [OGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.5f) blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.2f] offset:CGSizeZero blur:0.0f spread:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:3.0f spread:2.0f]
        ];

        appearance.textColor = black;
        appearance.placeholderColor = OGSearchBarRGB(162.0f, 162.0f, 162.0f, 1.0f);
        appearance.iconColor = OGSearchBarRGB(115.0f, 115.0f, 115.0f, 1.0f);
        appearance.iconSize = 14.0f;
        appearance.iconCircleDiameter = 12.0f;
        appearance.iconLineWidth = 2.0f;
        appearance.iconOffset = UIOffsetMake(10.0f, 0.0f);
        appearance.placeholderOffset = UIOffsetMake(31.0f, 0.0f);
    }
    else
    {
        UIColor *bandColor = OGSearchBarRGB(224.0f, 224.0f, 224.0f, 1.0f);
        background = [[OGSurfaceStyle alloc] init];
        background.fillColor = bandColor;
        background.shadows = @[
            [OGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 0.5f) blur:0.0f],
            [OGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.2f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f],
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, -1.0f) blur:0.0f]
        ];

        field = [[OGSurfaceStyle alloc] init];
        field.fillColor = white;
        field.shadows = @[
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.5f] offset:CGSizeMake(0.0f, 2.0f) blur:3.0f]
        ];
        field.strokeWidth = 1.0f;
        field.strokeColors = @[OGSearchBarRGB(125.0f, 143.0f, 164.0f, 1.0f), OGSearchBarRGB(161.0f, 174.0f, 185.0f, 1.0f)];

        appearance.backdropColor = bandColor;
        appearance.placeholderColor = OGSearchBarRGB(178.0f, 178.0f, 178.0f, 1.0f);
        appearance.iconColor = OGSearchBarRGB(147.0f, 152.0f, 158.0f, 1.0f);
        appearance.iconSize = 14.0f;
        appearance.iconCircleDiameter = 12.0f;
        appearance.iconLineWidth = 2.0f;
        appearance.iconOffset = UIOffsetMake(10.0f, 0.0f);
        appearance.placeholderOffset = UIOffsetMake(31.0f, 1.0f);
    }
    background.shape = OGSurfaceShapeBand;
    field.shape = OGSurfaceShapeRoundedRect;
    field.cornerRadius = 15.0f;
    appearance.backgroundSurfaceStyle = background;
    appearance.fieldSurfaceStyle = field;
    return appearance;
}

@end
