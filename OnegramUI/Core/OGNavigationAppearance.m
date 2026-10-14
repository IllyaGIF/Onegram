#import "OGNavigationAppearance.h"
#import "OGSurfaceStyle.h"
#import <math.h>

static UIFont *OGNavigationAppearanceBrandedFont(CGFloat size)
{
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:size];
    return font != nil ? font : [UIFont boldSystemFontOfSize:size];
}

static UIColor *OGNavigationAppearanceRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static OGSurfaceStyle *OGNavigationAppearanceDenimStyle(CGFloat contrast, UIColor *tintColor)
{
    OGSurfaceStyle *style = [[OGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = @"jeans.jpg";
    style.textureReferenceWidth = 320.0f;
    style.textureContrast = contrast;
    style.textureTintColor = tintColor;
    return style;
}

static OGSurfaceStyle *OGNavigationAppearanceLeatherStyle(void)
{
    OGSurfaceStyle *style = [[OGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = @"alcantara.png";
    style.textureReferenceWidth = 153.6f;
    style.textureTiled = YES;
    return style;
}

static OGSurfaceLayer *OGNavigationAppearanceLinearLayer(NSArray *colors)
{
    OGSurfaceLayer *layer = [[OGSurfaceLayer alloc] init];
    layer.colors = colors;
    layer.locations = @[@0.0f, @1.0f];
    return layer;
}

@implementation OGNavigationAppearance

+ (OGNavigationAppearance *)baseAppearance
{
    OGNavigationAppearance *appearance = [[OGNavigationAppearance alloc] init];
    appearance.titleFont = [UIFont boldSystemFontOfSize:17.0f];
    appearance.titleColor = [UIColor whiteColor];
    appearance.titleShadowColor = [UIColor colorWithRed:31.0f / 255.0f green:52.0f / 255.0f blue:70.0f / 255.0f alpha:0.9f];
    appearance.titleShadowOffset = UIOffsetMake(0.0f, -1.0f);
    appearance.buttonFont = [UIFont boldSystemFontOfSize:12.0f];
    appearance.buttonTitleColor = [UIColor whiteColor];
    appearance.buttonShadowColor = [UIColor colorWithRed:31.0f / 255.0f green:52.0f / 255.0f blue:70.0f / 255.0f alpha:0.9f];
    appearance.buttonShadowOffset = UIOffsetMake(0.0f, -1.0f);
    appearance.buttonHighlightedAlpha = 0.75f;
    appearance.backButtonTitleOffset = UIOffsetMake(1.0f, 0.0f);
    appearance.backButtonLandscapeTitleOffset = UIOffsetMake(1.0f, -1.0f);
    appearance.buttonTitleOffset = UIOffsetMake(0.0f, 0.0f);
    appearance.titleVerticalOffset = 0.0f;
    appearance.titleRetinaVerticalOffset = 0.5f;
    appearance.titleLandscapeVerticalOffset = -1.0f;
    appearance.titleViewVerticalOffset = 0.0f;
    appearance.tintColor = [UIColor whiteColor];
    appearance.hidesBottomStripe = YES;
    appearance.backgroundResourceDirectory = @"ios6style";
    appearance.backgroundAssetName = @"navigation_top_bg";
    appearance.buttonHeight = 29.0f;
    appearance.buttonImageHeight = 30.0f;
    appearance.buttonLandscapeHeight = 24.0f;
    appearance.buttonLandscapeImageHeight = 25.0f;
    appearance.buttonImageWidth = 120.0f;
    appearance.buttonMinimumWidth = 0.0f;
    appearance.buttonHorizontalPadding = 0.0f;
    return appearance;
}

+ (OGNavigationAppearance *)modernAppearance
{
    return [self baseAppearance];
}

+ (OGNavigationAppearance *)classicAppearance
{
    return [self baseAppearance];
}

+ (OGNavigationAppearance *)brandedAppearanceDark:(BOOL)dark
{
    OGNavigationAppearance *appearance = [self baseAppearance];
    appearance.titleFont = OGNavigationAppearanceBrandedFont(20.0f);
    appearance.titleColor = dark ? OGNavigationAppearanceRGB(241.0f, 241.0f, 241.0f, 1.0f) : [UIColor whiteColor];
    appearance.titleShadowColor = [UIColor colorWithWhite:0.0f alpha:0.4f];
    appearance.titleViewVerticalOffset = -2.5f;
    appearance.buttonFont = OGNavigationAppearanceBrandedFont(12.0f);
    appearance.buttonTitleColor = dark ? OGNavigationAppearanceRGB(206.0f, 206.0f, 206.0f, 1.0f) : [UIColor whiteColor];
    appearance.buttonShadowColor = [UIColor colorWithWhite:0.0f alpha:0.8f];
    appearance.buttonHighlightedAlpha = 1.0f;
    appearance.buttonMinimumWidth = 55.0f;
    appearance.buttonHorizontalPadding = 10.0f;

    OGSurfaceStyle *background = nil;
    OGSurfaceStyle *button = nil;
    if (dark)
    {
        background = OGNavigationAppearanceLeatherStyle();
        background.shape = OGSurfaceShapeSheet;
        background.cornerRadius = 10.0f;
        background.shadows = @[
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.2f] offset:CGSizeMake(0.0f, 0.5f) blur:0.5f]
        ];

        OGSurfaceLayer *gloss = OGNavigationAppearanceLinearLayer(@[[UIColor colorWithWhite:1.0f alpha:0.1f], [UIColor colorWithWhite:1.0f alpha:0.0f]]);
        OGSurfaceStyle *glossBackground = [background copy];
        glossBackground.layers = @[gloss];
        appearance.glossBackgroundSurfaceStyle = glossBackground;

        button = OGNavigationAppearanceLeatherStyle();
        button.layers = @[OGNavigationAppearanceLinearLayer(@[[UIColor colorWithWhite:1.0f alpha:0.1f], [UIColor colorWithWhite:0.0f alpha:0.1f]])];
        button.shadows = @[
            [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.1f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor blackColor] offset:CGSizeZero blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeZero blur:5.0f]
        ];
    }
    else
    {
        background = OGNavigationAppearanceDenimStyle(1.3f, OGNavigationAppearanceRGB(9.0f, 49.0f, 87.0f, 1.0f));
        background.shape = OGSurfaceShapeBand;
        background.shadows = @[
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.3f] offset:CGSizeMake(0.0f, 2.0f) blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, -3.0f) blur:2.0f],
            [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
        ];

        button = OGNavigationAppearanceDenimStyle(0.75f, OGNavigationAppearanceRGB(20.0f, 46.0f, 74.0f, 1.0f));
        button.shadows = @[
            [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.1f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.5f] offset:CGSizeMake(0.0f, -0.5f) blur:0.0f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor blackColor] offset:CGSizeZero blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
            [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeZero blur:5.0f]
        ];
    }
    appearance.backgroundSurfaceStyle = background;

    OGSurfaceStyle *statusBackground = [[OGSurfaceStyle alloc] init];
    statusBackground.shape = OGSurfaceShapeBand;
    statusBackground.fillColor = [UIColor blackColor];
    appearance.statusBackgroundSurfaceStyle = statusBackground;

    button.shape = OGSurfaceShapeRoundedRect;
    button.cornerRadius = 5.0f;
    button.arrowWidth = 12.0f;
    button.arrowTipRadius = 2.0f;
    appearance.buttonSurfaceStyle = button;

    OGSurfaceStyle *pressedButton = [button copy];
    pressedButton.overlayColor = [UIColor colorWithWhite:0.0f alpha:0.25f];
    appearance.buttonPressedSurfaceStyle = pressedButton;

    OGSurfaceStyle *backButton = [button copy];
    backButton.shape = OGSurfaceShapeBackArrow;
    backButton.arrowWidth = 13.0f;
    backButton.shadows = @[
        [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.1f] offset:CGSizeMake(0.0f, 0.5f) blur:0.5f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeZero blur:5.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor blackColor] offset:CGSizeZero blur:1.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];
    appearance.backButtonSurfaceStyle = backButton;
    appearance.backButtonBadgeTitleShift = roundf(backButton.arrowWidth * 0.25f);
    appearance.backButtonTitleOffset = UIOffsetMake(1.0f - appearance.backButtonBadgeTitleShift, -1.0f);
    appearance.backButtonLandscapeTitleOffset = UIOffsetMake(1.0f - appearance.backButtonBadgeTitleShift, -2.0f);

    OGSurfaceStyle *pressedBackButton = [backButton copy];
    pressedBackButton.overlayColor = pressedButton.overlayColor;
    appearance.backButtonPressedSurfaceStyle = pressedBackButton;

    return appearance;
}

@end
