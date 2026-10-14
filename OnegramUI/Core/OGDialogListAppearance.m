#import "OGDialogListAppearance.h"
#import "OGSurfaceStyle.h"

static UIColor *OGDialogListRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    return [UIColor colorWithRed:red / 255.0f green:green / 255.0f blue:blue / 255.0f alpha:alpha];
}

static UIFont *OGDialogListBoldFont(CGFloat size)
{
    UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:size];
    return font != nil ? font : [UIFont boldSystemFontOfSize:size];
}

static OGSurfaceStyle *OGDialogListTextureStyle(NSString *assetName, CGFloat referenceWidth)
{
    OGSurfaceStyle *style = [[OGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = assetName;
    style.textureReferenceWidth = referenceWidth;
    return style;
}

static OGSurfaceStyle *OGDialogListLeatherStyle(void)
{
    OGSurfaceStyle *style = OGDialogListTextureStyle(@"alcantara.png", 153.6f);
    style.textureTiled = YES;
    return style;
}

static OGSurfaceLayer *OGDialogListLinearLayer(UIEdgeInsets insets, NSArray *colors, CGFloat angle)
{
    OGSurfaceLayer *layer = [[OGSurfaceLayer alloc] init];
    layer.insets = insets;
    layer.colors = colors;
    layer.locations = @[@0.0f, @1.0f];
    layer.gradientAngle = angle;
    return layer;
}

@implementation OGDialogListAppearance

+ (OGDialogListAppearance *)brandedAppearanceDark:(BOOL)dark
{
    OGDialogListAppearance *appearance = [[OGDialogListAppearance alloc] init];
    UIColor *white = [UIColor whiteColor];
    UIColor *black = [UIColor blackColor];
    appearance.rowHeight = 65.0f;

    OGSurfaceStyle *avatarOverlay = [[OGSurfaceStyle alloc] init];
    avatarOverlay.shape = OGSurfaceShapeRoundedRect;
    avatarOverlay.cornerRadius = 8.0f;
    avatarOverlay.fillColor = [UIColor clearColor];
    appearance.avatarOverlaySurfaceStyle = avatarOverlay;

    appearance.actionFallbackColor = OGDialogListRGB(48.0f, 49.0f, 55.0f, 1.0f);
    UIFont *mentionFont = [UIFont fontWithName:@"HelveticaNeue" size:13.0f];
    appearance.mentionFont = mentionFont != nil ? mentionFont : [UIFont systemFontOfSize:13.0f];
    appearance.mentionOpticalSize = 11.27f;
    OGSurfaceShadow *mentionDropShadow = [OGSurfaceShadow dropShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f];
    appearance.folderButtonFont = OGDialogListBoldFont(12.0f);

    if (dark)
    {
        avatarOverlay.shadows = @[
            [OGSurfaceShadow insetShadowWithColor:OGDialogListRGB(255.0f, 253.0f, 253.0f, 0.3f) offset:CGSizeMake(0.0f, -1.0f) blur:0.5f],
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
        ];

        OGSurfaceStyle *cellBackground = [[OGSurfaceStyle alloc] init];
        cellBackground.shape = OGSurfaceShapeBand;
        cellBackground.fillColor = OGDialogListRGB(43.0f, 43.0f, 43.0f, 1.0f);
        cellBackground.shadows = @[[OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f]];
        appearance.cellBackgroundSurfaceStyle = cellBackground;

        appearance.messageColor = OGDialogListRGB(190.0f, 190.0f, 190.0f, 1.0f);
        appearance.messageUnreadColor = white;
        appearance.dateColor = OGDialogListRGB(185.0f, 185.0f, 185.0f, 1.0f);
        appearance.statusColor = OGDialogListRGB(185.0f, 185.0f, 185.0f, 1.0f);
        appearance.disclosureColor = OGDialogListRGB(185.0f, 185.0f, 185.0f, 1.0f);
        appearance.disclosureUnreadColor = white;
        appearance.pinGradientColors = @[white, OGDialogListRGB(197.0f, 197.0f, 197.0f, 1.0f)];
        appearance.mentionGradientColors = @[white, white];
        appearance.mentionGradientLocations = @[@0.0f, @1.0f];
        appearance.mentionShadows = @[mentionDropShadow];

        OGSurfaceStyle *action = OGDialogListTextureStyle(@"blackpaper.jpg", 320.0f);
        action.shape = OGSurfaceShapeBand;
        action.layers = @[OGDialogListLinearLayer(UIEdgeInsetsMake(0.0f, 74.0f, 0.0f, -74.0f), @[OGDialogListRGB(113.0f, 108.0f, 108.0f, 0.08f), OGDialogListRGB(11.0f, 10.0f, 10.0f, 0.64f)], 90.0f)];
        appearance.actionSurfaceStyle = action;

        OGSurfaceStyle *header = OGDialogListLeatherStyle();
        header.shape = OGSurfaceShapeBand;
        appearance.headerSurfaceStyle = header;
        appearance.folderTabsSeparatorColor = [UIColor clearColor];
        appearance.folderEmptyColor = OGDialogListRGB(155.0f, 155.0f, 155.0f, 1.0f);

        OGSurfaceStyle *folderButton = OGDialogListLeatherStyle();
        folderButton.shape = OGSurfaceShapeRoundedRect;
        folderButton.cornerRadius = 5.0f;
        folderButton.layers = @[OGDialogListLinearLayer(UIEdgeInsetsZero, @[[white colorWithAlphaComponent:0.1f], [black colorWithAlphaComponent:0.1f]], 180.0f)];
        folderButton.shadows = @[
            [OGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.1f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeZero blur:5.0f]
        ];
        appearance.folderButtonSurfaceStyle = folderButton;
        OGSurfaceStyle *pressedFolderButton = [folderButton copy];
        pressedFolderButton.overlayColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonPressedSurfaceStyle = pressedFolderButton;
        appearance.folderButtonTitleColor = OGDialogListRGB(206.0f, 206.0f, 206.0f, 1.0f);
        appearance.folderButtonHighlightedTitleColor = OGDialogListRGB(206.0f, 206.0f, 206.0f, 1.0f);
        appearance.folderButtonShadowColor = [black colorWithAlphaComponent:0.8f];
        appearance.folderButtonHighlightedShadowColor = [black colorWithAlphaComponent:0.8f];
        appearance.folderButtonShadowOffset = CGSizeMake(0.0f, -1.0f);
        appearance.folderButtonHeight = 29.0f;
        appearance.folderButtonMinimumWidth = 55.0f;
        appearance.folderButtonHorizontalPadding = 10.0f;
        appearance.folderButtonTitleBottomInset = 0.0f;
        appearance.folderTabsInset = 12.0f;
        appearance.folderTabsTrailingInset = 12.0f;
        appearance.folderTabsHeight = 36.0f;
        appearance.folderButtonTopInset = 0.0f;
        appearance.folderTabsSpacing = 6.0f;
        appearance.searchBarHeight = 41.0f;
        appearance.searchFieldInsets = UIEdgeInsetsMake(4.0f, 12.0f, 10.0f, 12.0f);
        appearance.navigationButtonHorizontalInset = 7.0f;
        appearance.navigationButtonVerticalOffset = 2.0f;
        appearance.navigationTitleVerticalOffset = 2.0f;

        OGSurfaceStyle *selectedFolderButton = [folderButton copy];
        selectedFolderButton.layers = @[OGDialogListLinearLayer(UIEdgeInsetsZero, @[[black colorWithAlphaComponent:0.3f], [black colorWithAlphaComponent:0.3f]], 180.0f)];
        appearance.folderButtonSelectedSurfaceStyle = selectedFolderButton;
    }
    else
    {
        avatarOverlay.shadows = @[
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f],
            [OGSurfaceShadow insetShadowWithColor:[white colorWithAlphaComponent:0.6f] offset:CGSizeMake(0.0f, -1.0f) blur:1.0f]
        ];

        appearance.messageColor = black;
        appearance.messageUnreadColor = OGDialogListRGB(134.0f, 130.0f, 130.0f, 1.0f);
        appearance.dateColor = OGDialogListRGB(89.0f, 89.0f, 89.0f, 1.0f);
        appearance.statusColor = OGDialogListRGB(90.0f, 90.0f, 90.0f, 1.0f);
        appearance.disclosureColor = black;
        appearance.disclosureUnreadColor = OGDialogListRGB(134.0f, 130.0f, 130.0f, 1.0f);
        appearance.pinGradientColors = @[[UIColor colorWithWhite:0.714f alpha:1.0f], [UIColor colorWithWhite:0.537f alpha:1.0f]];
        appearance.mentionGradientColors = @[OGDialogListRGB(163.0f, 163.0f, 163.0f, 1.0f), OGDialogListRGB(61.0f, 61.0f, 61.0f, 1.0f)];
        appearance.mentionGradientLocations = @[@0.0f, @1.6925f];
        appearance.mentionShadows = @[
            mentionDropShadow,
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
        ];
        appearance.actionPatternAssetName = @"cloth";

        OGSurfaceStyle *folderTabsHeader = [[OGSurfaceStyle alloc] init];
        folderTabsHeader.shape = OGSurfaceShapeBand;
        folderTabsHeader.fillColor = OGDialogListRGB(224.0f, 224.0f, 224.0f, 1.0f);
        folderTabsHeader.shadows = @[[OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f]];
        appearance.headerSurfaceStyle = folderTabsHeader;
        appearance.headerColor = OGDialogListRGB(224.0f, 224.0f, 224.0f, 1.0f);
        appearance.folderTabsSeparatorColor = [UIColor clearColor];
        appearance.folderEmptyColor = OGDialogListRGB(122.0f, 122.0f, 122.0f, 1.0f);

        NSArray *folderButtonShadows = @[
            [OGSurfaceShadow dropShadowWithColor:[white colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 0.5f) blur:0.5f],
            [OGSurfaceShadow insetShadowWithColor:black offset:CGSizeZero blur:1.0f],
            [OGSurfaceShadow insetShadowWithColor:[black colorWithAlphaComponent:0.4f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
        ];
        OGSurfaceStyle *folderButton = [[OGSurfaceStyle alloc] init];
        folderButton.shape = OGSurfaceShapeRoundedRect;
        folderButton.cornerRadius = 12.0f;
        folderButton.fillColor = [black colorWithAlphaComponent:0.3f];
        folderButton.shadows = folderButtonShadows;
        appearance.folderButtonSurfaceStyle = folderButton;
        OGSurfaceStyle *pressedFolderButton = [folderButton copy];
        pressedFolderButton.overlayColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonPressedSurfaceStyle = pressedFolderButton;
        appearance.folderButtonTitleColor = white;
        appearance.folderButtonHighlightedTitleColor = white;
        appearance.folderButtonShadowColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonHighlightedShadowColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonShadowOffset = CGSizeMake(0.0f, -1.0f);
        appearance.folderButtonHeight = 23.0f;
        appearance.folderButtonMinimumWidth = 41.0f;
        appearance.folderButtonHorizontalPadding = 10.0f;
        appearance.folderButtonTitleBottomInset = 0.0f;
        appearance.folderTabsInset = 12.0f;
        appearance.folderTabsTrailingInset = 14.0f;
        appearance.folderTabsHeight = 32.0f;
        appearance.folderButtonTopInset = 5.0f;
        appearance.folderTabsSpacing = 18.0f;
        appearance.searchBarHeight = 40.0f;
        appearance.searchFieldInsets = UIEdgeInsetsZero;

        OGSurfaceStyle *selectedFolderButton = [folderButton copy];
        selectedFolderButton.fillColor = [black colorWithAlphaComponent:0.6f];
        appearance.folderButtonSelectedSurfaceStyle = selectedFolderButton;
    }
    if (appearance.folderButtonSelectedSurfaceStyle != nil)
    {
        OGSurfaceStyle *pressedSelectedFolderButton = [appearance.folderButtonSelectedSurfaceStyle copy];
        pressedSelectedFolderButton.overlayColor = [black colorWithAlphaComponent:0.25f];
        appearance.folderButtonSelectedPressedSurfaceStyle = pressedSelectedFolderButton;
    }
    return appearance;
}

@end
