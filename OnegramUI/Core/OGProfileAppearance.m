#import "OGProfileAppearance.h"
#import "OGSurfaceStyle.h"
#import "OGSettingsAppearance.h"

static OGSurfaceStyle *OGProfileAppearanceBlackPaperStyle(CGFloat cornerRadius)
{
    OGSurfaceStyle *style = [[OGSurfaceStyle alloc] init];
    style.textureResourceDirectory = @"ios6style";
    style.textureAssetName = @"blackpaper.jpg";
    style.textureReferenceWidth = 0.0f;
    style.textureContrast = 2.4f;
    style.textureBias = 0.204f;
    style.shape = OGSurfaceShapeRoundedRect;
    style.cornerRadius = cornerRadius;
    style.shadows = @[
        [OGSurfaceShadow dropShadowWithColor:[UIColor whiteColor] offset:CGSizeMake(0.0f, 0.5f) blur:1.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor blackColor] offset:CGSizeMake(0.0f, 0.5f) blur:0.5f]
    ];
    return style;
}

@implementation OGProfileAppearance

+ (OGProfileAppearance *)baseAppearance
{
    OGProfileAppearance *appearance = [[OGProfileAppearance alloc] init];
    appearance.detailsTextScale = 1.0f;
    appearance.itemHeight = 97.0f;
    appearance.itemHeightWithAbout = 97.0f;
    appearance.itemMusicHeight = 44.0f;
    appearance.cardTop = 10.0f;
    appearance.cardLeft = 13.0f;
    appearance.cardRight = 14.0f;
    appearance.cardInnerHeight = 74.0f;
    appearance.cardInnerHeightWithAbout = 122.0f;
    appearance.cardCornerRadius = 10.0f;

    OGSurfaceStyle *card = [[OGSurfaceStyle alloc] init];
    card.textureResourceDirectory = @"ios6style";
    card.textureAssetName = @"metal1.jpg";
    card.textureReferenceWidth = 0.0f;
    card.shape = OGSurfaceShapeRoundedRect;
    card.cornerRadius = 10.0f;
    card.shadows = @[
        [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithRed:1.0f green:249.0f / 255.0f blue:249.0f / 255.0f alpha:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
        [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.5f] offset:CGSizeMake(0.0f, -1.0f) blur:1.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, -1.0f) blur:1.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:1.0f alpha:0.3f] offset:CGSizeMake(0.0f, -1.0f) blur:1.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.25f] offset:CGSizeZero blur:1.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f]
    ];
    appearance.cardSurfaceStyle = card;

    OGSurfaceLayer *musicLayer = [[OGSurfaceLayer alloc] init];
    musicLayer.height = 40.0f;
    musicLayer.anchoredToBottom = YES;
    musicLayer.insets = UIEdgeInsetsMake(0.0f, 0.0f, -1.0f, 0.0f);
    musicLayer.colors = @[[UIColor colorWithWhite:1.0f alpha:0.6f], [UIColor colorWithWhite:1.0f alpha:0.0f]];
    musicLayer.locations = @[@0.0f, @0.7212f];
    musicLayer.shadows = @[[OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 0.5f) blur:1.0f]];
    appearance.cardMusicLayer = musicLayer;
    appearance.avatarInset = 9.0f;
    appearance.avatarTop = 6.0f;
    appearance.avatarSize = 68.0f;
    appearance.avatarCornerRadius = 10.0f;

    OGSurfaceStyle *avatarOverlay = [[OGSurfaceStyle alloc] init];
    avatarOverlay.shape = OGSurfaceShapeRoundedRect;
    avatarOverlay.cornerRadius = 10.0f;
    avatarOverlay.fillColor = [UIColor clearColor];
    avatarOverlay.shadows = @[
        [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.25f] offset:CGSizeMake(0.0f, 2.0f) blur:2.0f],
        [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 2.0f) blur:2.0f],
        [OGSurfaceShadow dropShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.25f] offset:CGSizeMake(0.0f, 2.0f) blur:2.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.3f] offset:CGSizeMake(0.0f, 1.0f) blur:1.0f],
        [OGSurfaceShadow insetShadowWithColor:[UIColor colorWithWhite:0.0f alpha:0.25f] offset:CGSizeMake(0.0f, 1.0f) blur:0.5f]
    ];
    appearance.avatarOverlaySurfaceStyle = avatarOverlay;
    appearance.avatarPlaceholderFontSize = 34.0f;
    appearance.reflectionAlpha = 0.6f;
    appearance.reflectionMaskAlpha = 0.9f;
    appearance.reflectionMaskLength = 0.5962f;
    appearance.reflectionTop = 74.0f;
    appearance.textGap = 4.0f;
    appearance.textRightInset = 13.0f;
    appearance.nameTop = 4.0f;
    appearance.nameFrameHeight = 24.0f;
    appearance.nameMeasureHeight = 29.0f;
    appearance.nameMaximumFontSize = 20.0f;
    appearance.nameMinimumFontSize = 17.0f;
    appearance.nameColor = [UIColor blackColor];
    appearance.nameFontName = @"HelveticaNeue-Bold";
    appearance.nameShadowColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
    appearance.nameShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.statusFontSize = 8.0f;
    appearance.statusMinimumWidth = 33.0f;
    appearance.statusMaximumWidth = 90.0f;
    appearance.statusHorizontalPadding = 8.0f;
    appearance.statusHeight = 13.0f;
    appearance.statusTop = 10.0f;
    appearance.statusCornerRadius = 6.5f;
    appearance.statusRightInset = 7.0f;
    appearance.statusNameGap = 4.0f;
    appearance.statusTextTop = 1.0f;
    appearance.statusTextHeight = 10.0f;
    appearance.statusTextColor = [UIColor whiteColor];
    appearance.statusTextShadowColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
    appearance.statusTextShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.statusSurfaceStyle = OGProfileAppearanceBlackPaperStyle(6.5f);
    appearance.phoneFontSize = 10.0f;
    appearance.phoneTop = 31.0f;
    appearance.secondaryLineHeight = 14.0f;
    appearance.phoneColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
    appearance.usernameFontSize = 10.0f;
    appearance.usernameTop = 31.0f;
    appearance.usernameTopWithPhone = 46.0f;
    appearance.usernameColor = [UIColor colorWithRed:0.27f green:0.49f blue:0.64f alpha:1.0f];
    appearance.aboutTitleFontSize = 12.0f;
    appearance.aboutTitleTop = 79.0f;
    appearance.aboutTitleHeight = 17.0f;
    appearance.aboutTitleColor = [UIColor colorWithWhite:0.35f alpha:1.0f];
    appearance.aboutFontSize = 10.0f;
    appearance.aboutTop = 96.0f;
    appearance.aboutHeight = 18.0f;
    appearance.aboutColor = [UIColor colorWithWhite:0.41f alpha:1.0f];
    appearance.musicHeight = 39.0f;
    appearance.musicArrowRight = 7.0f;
    appearance.musicArrowTop = 9.0f;
    appearance.musicArrowSize = 19.0f;
    appearance.musicTextLeft = 6.5f;
    appearance.musicTextRight = 30.0f;
    appearance.musicTextTop = 9.0f;
    appearance.musicTextHeight = 18.0f;
    appearance.musicFontSize = 15.0f;
    appearance.musicTextColor = [UIColor blackColor];
    appearance.musicTextShadowColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
    appearance.musicTextShadowOffset = CGSizeMake(0.0f, 1.0f);
    appearance.musicIconColor = [UIColor colorWithWhite:0.49f alpha:1.0f];
    appearance.musicPlaySurfaceStyle = OGProfileAppearanceBlackPaperStyle(9.5f);
    appearance.musicPlayGlyphResourceDirectory = @"ios6style";
    appearance.musicPlayGlyphAssetName = @"play";
    appearance.musicPlayGlyphOrigin = CGPointMake(2.0f, 1.0f);
    appearance.musicPlayGlyphColors = @[[UIColor whiteColor], [UIColor colorWithRed:163.0f / 255.0f green:163.0f / 255.0f blue:163.0f / 255.0f alpha:1.0f]];
    appearance.musicPlayGlyphLocations = @[@0.1874f, @0.8126f];
    appearance.musicPlayGlyphShadow = [OGSurfaceShadow dropShadowWithColor:[UIColor blackColor] offset:CGSizeMake(0.0f, 0.5f) blur:0.5f];
    appearance.actionsSectionInsets = UIEdgeInsetsMake(10.0f, 3.0f, 44.0f, 6.0f);
    appearance.blockSectionInsets = UIEdgeInsetsMake(22.0f, 0.0f, 44.0f, 0.0f);
    appearance.sharedMediaSectionInsets = UIEdgeInsetsMake(22.0f, 0.0f, 0.0f, 0.0f);
    appearance.compactSectionInsets = UIEdgeInsetsZero;
    appearance.withoutActionsBottomInset = 44.0f;
    appearance.editingPhonesTopOffset = 32.0f;
    appearance.detailRowHeight = 44.0f;
    appearance.detailTitleFontSize = 14.0f;
    appearance.detailTitleColor = [UIColor colorWithRed:0.16f green:0.47f blue:0.72f alpha:1.0f];
    appearance.detailVariantFontSize = 17.0f;
    appearance.detailVariantColor = [UIColor colorWithWhite:0.55f alpha:1.0f];
    appearance.detailLeft = 15.0f;
    appearance.detailTitleTop = 14.0f;
    appearance.detailTitleMaximumWidth = 70.0f;
    appearance.detailVariantTop = 12.0f;
    appearance.detailVariantRight = 35.0f;
    appearance.detailVariantReservedWidth = 122.0f;
    appearance.detailDisclosureRight = 15.0f;
    appearance.detailSeparatorInset = 15.0f;
    appearance.detailSeparatorColor = [UIColor colorWithWhite:0.44f alpha:0.28f];
    return appearance;
}

+ (OGProfileAppearance *)modernAppearance
{
    return [self baseAppearance];
}

+ (OGProfileAppearance *)classicAppearance
{
    return [self baseAppearance];
}

+ (OGProfileAppearance *)brandedAppearanceDark:(BOOL)dark
{
    OGProfileAppearance *appearance = [self baseAppearance];
    appearance.detailsTextScale = 1.2f;
    appearance.itemHeight = 132.0f;
    appearance.itemHeightWithAbout = 132.0f;
    appearance.itemMusicHeight = 39.0f;
    appearance.cardInnerHeight = appearance.cardInnerHeightWithAbout;
    appearance.actionRowAppearance = [OGSettingsAppearance brandedProfileActionAppearanceDark:dark];
    if (dark)
    {
        appearance.infoSectionTopInset = -2.5f;
        appearance.actionsSectionInsets = UIEdgeInsetsMake(14.5f, 0.0f, 44.0f, 0.0f);
    }
    return appearance;
}

@end
