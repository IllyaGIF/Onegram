#import "OGSettingsAppearance.h"
#import "OGSurfaceStyle.h"

static OGSurfaceStyle *OGSettingsAppearancePaperStyleWithSeparator(OGSurfaceShape shape, CGFloat cornerRadius, BOOL leadingRow, OGSurfaceShadow *separator)
{
    OGSurfaceStyle *style = [[OGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = @"whitepaper.jpg";
    style.textureReferenceWidth = 0.0f;
    style.shape = shape;
    style.cornerRadius = cornerRadius;
    style.shadows = leadingRow ? @[[OGSurfaceShadow dropShadowWithColor:[UIColor whiteColor] offset:CGSizeMake(0.0f, 2.0f) blur:1.0f], separator] : @[separator];
    return style;
}

static OGSurfaceStyle *OGSettingsAppearancePaperStyle(OGSurfaceShape shape, CGFloat cornerRadius, BOOL leadingRow)
{
    OGSurfaceShadow *separator = [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f];
    return OGSettingsAppearancePaperStyleWithSeparator(shape, cornerRadius, leadingRow, separator);
}

@implementation OGSettingsAppearance

+ (OGSettingsAppearance *)baseAppearance
{
    OGSettingsAppearance *appearance = [[OGSettingsAppearance alloc] init];
    appearance.rowHeight = 44.0f;
    appearance.groupedHorizontalInset = 9.0f;
    appearance.iconX = 17.0f;
    appearance.iconSize = 16.0f;
    appearance.titleX = 43.0f;
    appearance.titleY = 7.0f;
    appearance.titleHeight = 22.0f;
    appearance.disclosureRight = 23.0f;
    appearance.controlRight = 14.0f;
    appearance.verticalOffset = 1.0f;
    appearance.disclosureVerticalOffset = 1.0f;
    appearance.accessorySpacing = 8.0f;
    appearance.titleTrailingSpacing = 8.0f;
    appearance.variantVerticalOffset = 1.0f;
    appearance.iconShadowOpacity = 0.10f;
    appearance.iconShadowRadius = 0.5f;
    appearance.iconShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.controlRowHeight = 44.0f;
    appearance.controlRowContentOffset = 0.0f;
    appearance.titleFont = [UIFont systemFontOfSize:17.0f];
    appearance.variantFont = [UIFont systemFontOfSize:17.0f];
    appearance.titleColor = [UIColor colorWithWhite:0.07f alpha:1.0f];
    appearance.variantColor = [UIColor colorWithWhite:0.45f alpha:1.0f];
    appearance.destructiveColor = [UIColor colorWithRed:0.86f green:0.20f blue:0.18f alpha:1.0f];
    appearance.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.20f];
    appearance.titleShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.collectionBackgroundColor = [UIColor colorWithRed:0.79f green:0.84f blue:0.87f alpha:1.0f];
    appearance.hidesInlineSeparator = NO;
    appearance.blockButtonTitleCentered = NO;
    appearance.blockButtonShowsDisclosure = YES;
    appearance.iconResourceDirectory = @"ios6style";
    appearance.disclosureResourceDirectory = @"ClassicIOS6";
    appearance.disclosureAssetName = @"MenuDisclosureIndicator";
    appearance.groupedResourceDirectory = @"ClassicIOS6";
    appearance.groupedSingleAssetName = @"GroupedCellSingle";
    appearance.groupedTopAssetName = @"GroupedCellTop";
    appearance.groupedMiddleAssetName = @"GroupedCellMiddle";
    appearance.groupedBottomAssetName = @"GroupedCellBottom";
    appearance.groupedSelectedSuffix = @"_Selected";
    return appearance;
}

+ (OGSettingsAppearance *)modernAppearance
{
    return [self baseAppearance];
}

+ (OGSettingsAppearance *)classicAppearance
{
    return [self baseAppearance];
}

+ (OGSettingsAppearance *)brandedAppearanceDark:(BOOL)dark
{
    OGSettingsAppearance *appearance = [self baseAppearance];
    appearance.rowHeight = 35.0f;
    appearance.controlRowHeight = 35.0f;
    appearance.titleFont = [UIFont boldSystemFontOfSize:18.0f];
    appearance.variantFont = [UIFont systemFontOfSize:14.0f];
    appearance.titleColor = [UIColor blackColor];
    appearance.variantColor = [UIColor colorWithWhite:0.50f alpha:1.0f];
    appearance.destructiveColor = [UIColor colorWithRed:0.91f green:0.22f blue:0.19f alpha:1.0f];
    appearance.collectionBackgroundColor = [UIColor whiteColor];
    appearance.hidesInlineSeparator = YES;
    appearance.blockButtonTitleCentered = YES;
    appearance.blockButtonShowsDisclosure = NO;
    if (dark)
    {
        UIFont *titleFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:18.0f];
        appearance.titleFont = titleFont != nil ? titleFont : [UIFont boldSystemFontOfSize:18.0f];
        appearance.titleX = 44.0f;
        appearance.disclosureVerticalOffset = 0.0f;
        appearance.disclosureResourceDirectory = @"ios6style";
        appearance.disclosureAssetName = @"drill-in";
        UIColor *disclosureColor = [UIColor colorWithRed:100.0f / 255.0f green:100.0f / 255.0f blue:102.0f / 255.0f alpha:1.0f];
        appearance.disclosureColors = @[disclosureColor, disclosureColor];
        appearance.disclosureLocations = @[@0.0f, @1.0f];
        appearance.groupedSingleSurfaceStyle = OGSettingsAppearancePaperStyle(OGSurfaceShapeRoundedRect, 10.0f, YES);
        appearance.groupedTopSurfaceStyle = OGSettingsAppearancePaperStyle(OGSurfaceShapeSheet, 10.0f, YES);
        appearance.groupedMiddleSurfaceStyle = OGSettingsAppearancePaperStyle(OGSurfaceShapeRoundedRect, 0.0f, NO);
        appearance.groupedBottomSurfaceStyle = OGSettingsAppearancePaperStyle(OGSurfaceShapeSheetBottom, 10.0f, NO);
        appearance.groupedSelectedOverlayColor = [UIColor colorWithWhite:0.0f alpha:0.12f];

        OGSurfaceStyle *screenBackground = [[OGSurfaceStyle alloc] init];
        screenBackground.textureResourceDirectory = @"ios6style";
        screenBackground.textureAssetName = @"alcantara.png";
        screenBackground.textureReferenceWidth = 153.6f;
        screenBackground.textureTiled = YES;
        screenBackground.shape = OGSurfaceShapeRoundedRect;
        appearance.screenBackgroundSurfaceStyle = screenBackground;
        appearance.collectionBackgroundColor = [UIColor colorWithWhite:52.0f / 255.0f alpha:1.0f];
        appearance.navigationButtonOffset = UIOffsetMake(-8.0f, 2.0f);
        appearance.groupedFillColor = [UIColor colorWithWhite:240.0f / 255.0f alpha:1.0f];
        appearance.groupedSelectedFillColor = [UIColor colorWithWhite:211.0f / 255.0f alpha:1.0f];
        appearance.accentColor = [UIColor colorWithRed:56.0f / 255.0f green:84.0f / 255.0f blue:135.0f / 255.0f alpha:1.0f];
        appearance.switchColor = [UIColor colorWithWhite:38.0f / 255.0f alpha:1.0f];
        appearance.commentColor = [UIColor colorWithWhite:160.0f / 255.0f alpha:1.0f];
        UIFont *headerFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:15.0f];
        appearance.headerFont = headerFont != nil ? headerFont : [UIFont boldSystemFontOfSize:15.0f];
        appearance.headerColor = [UIColor colorWithWhite:206.0f / 255.0f alpha:1.0f];
        appearance.headerShadowColor = [UIColor colorWithWhite:0.0f alpha:0.8f];
        appearance.headerShadowOffset = CGSizeMake(0.0f, -1.0f);
        appearance.headerX = 20.0f;
    }
    return appearance;
}

+ (OGSettingsAppearance *)brandedProfileActionAppearanceDark:(BOOL)dark
{
    OGSettingsAppearance *appearance = [self brandedAppearanceDark:dark];
    if (!dark)
        return appearance;

    appearance.rowHeight = 46.0f;
    appearance.controlRowHeight = 52.0f;
    appearance.controlRowContentOffset = 1.5f;
    appearance.groupedHorizontalInset = 14.0f;
    appearance.iconX = 23.0f;
    appearance.verticalOffset = 0.0f;
    appearance.titleX = 45.0f;
    appearance.titleY = 12.0f;
    appearance.disclosureRight = 38.5f;
    appearance.controlRight = 28.5f;
    appearance.iconColors = @[
        [UIColor colorWithWhite:137.0f / 255.0f alpha:1.0f],
        [UIColor colorWithWhite:142.0f / 255.0f alpha:1.0f],
        [UIColor colorWithWhite:188.0f / 255.0f alpha:1.0f],
        [UIColor colorWithWhite:120.0f / 255.0f alpha:1.0f]
    ];
    appearance.iconLocations = @[@0.0f, @0.06f, @0.07f, @1.0f];

    OGSurfaceShadow *separator = [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.12f] offset:CGSizeMake(0.0f, 1.0f) blur:0.0f];
    appearance.groupedMiddleSurfaceStyle = OGSettingsAppearancePaperStyleWithSeparator(OGSurfaceShapeRoundedRect, 0.0f, NO, separator);
    appearance.groupedBottomSurfaceStyle = OGSettingsAppearancePaperStyleWithSeparator(OGSurfaceShapeSheetBottom, 10.0f, NO, separator);
    return appearance;
}

@end
