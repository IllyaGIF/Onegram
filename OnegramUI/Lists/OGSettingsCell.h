#import "OGListCell.h"

@class OGTheme;
@class OGSettingsAppearance;

typedef enum {
    OGSettingsCellAccessoryNone = 0,
    OGSettingsCellAccessoryDisclosure = 1,
    OGSettingsCellAccessoryControl = 2
} OGSettingsCellAccessoryKind;

typedef enum {
    OGGroupedCellPositionSingle = 0,
    OGGroupedCellPositionTop = 1,
    OGGroupedCellPositionMiddle = 2,
    OGGroupedCellPositionBottom = 3
} OGGroupedCellPosition;

typedef struct {
    CGRect iconFrame;
    CGRect titleFrame;
    CGRect accessoryFrame;
    CGRect trailingFrame;
} OGSettingsCellLegacyLayout;

FOUNDATION_EXPORT void OGSettingsCellGetLegacyLayout(OGSettingsAppearance *appearance, CGRect bounds, UIEdgeInsets safeAreaInsets, CGSize accessorySize, OGSettingsCellAccessoryKind accessoryKind, CGSize trailingSize, CGFloat trailingVerticalOffset, CGFloat titleTrailingSpacing, OGSettingsCellLegacyLayout *layout);
FOUNDATION_EXPORT void OGSettingsCellGetLegacyBrandedLayout(OGTheme *theme, CGRect bounds, UIEdgeInsets safeAreaInsets, CGSize accessorySize, OGSettingsCellAccessoryKind accessoryKind, CGSize trailingSize, CGFloat trailingVerticalOffset, CGFloat titleTrailingSpacing, OGSettingsCellLegacyLayout *layout);

@interface OGSettingsCell : OGListCell
+ (UIImage *)legacyBrandedIconNamed:(NSString *)name theme:(OGTheme *)theme;
+ (UIImage *)legacyBrandedIconNamed:(NSString *)name appearance:(OGSettingsAppearance *)appearance theme:(OGTheme *)theme;
+ (UIImage *)legacyBrandedDisclosureImageWithTheme:(OGTheme *)theme;
+ (UIImage *)legacyGroupedBackgroundImageForPosition:(OGGroupedCellPosition)position selected:(BOOL)selected theme:(OGTheme *)theme;
+ (BOOL)legacyGroupedBackgroundUsesSurfaceWithTheme:(OGTheme *)theme;
+ (UIImage *)legacyGroupedSurfaceImageForPosition:(OGGroupedCellPosition)position selected:(BOOL)selected size:(CGSize)size theme:(OGTheme *)theme outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyGroupedSurfaceImageForPosition:(OGGroupedCellPosition)position selected:(BOOL)selected size:(CGSize)size appearance:(OGSettingsAppearance *)appearance theme:(OGTheme *)theme outsets:(UIEdgeInsets *)outsets;
+ (UIColor *)legacyScreenBackgroundColorWithTheme:(OGTheme *)theme;
+ (UIColor *)legacyCollectionBackgroundColorWithTheme:(OGTheme *)theme;
+ (void)applyLegacyBrandedTitleStyleWithTheme:(OGTheme *)theme titleLabel:(UILabel *)titleLabel;
+ (void)applyLegacyBrandedTitleStyleWithAppearance:(OGSettingsAppearance *)appearance titleLabel:(UILabel *)titleLabel;
+ (BOOL)applyLegacyBrandedHeaderStyleWithTheme:(OGTheme *)theme headerLabel:(UILabel *)headerLabel;
+ (void)applyLegacyBrandedVariantStyleWithTheme:(OGTheme *)theme variantLabel:(UILabel *)variantLabel;
+ (void)applyLegacyBrandedIconStyleWithTheme:(OGTheme *)theme iconView:(UIImageView *)iconView;
+ (void)applyLegacyBrandedIconStyleWithAppearance:(OGSettingsAppearance *)appearance iconView:(UIImageView *)iconView;
+ (void)applyLegacyBrandedStyleWithTheme:(OGTheme *)theme titleLabel:(UILabel *)titleLabel iconView:(UIImageView *)iconView disclosureView:(UIImageView *)disclosureView bounds:(CGRect)bounds safeAreaInsets:(UIEdgeInsets)safeAreaInsets;
@end
