#import "../Base/OGView.h"

@class OGTheme;

@interface OGProfileHeader : OGView
+ (UIImage *)legacyCardImageWithTheme:(OGTheme *)theme size:(CGSize)size hasMusic:(BOOL)hasMusic outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyAvatarOverlayImageWithTheme:(OGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyStatusBackgroundImageWithTheme:(OGTheme *)theme size:(CGSize)size outsets:(UIEdgeInsets *)outsets;
+ (UIImage *)legacyMusicPlayImageWithTheme:(OGTheme *)theme outsets:(UIEdgeInsets *)outsets;
+ (UIFont *)legacyNameFontWithTheme:(OGTheme *)theme size:(CGFloat)size;
+ (void)applyLegacyAvatarStyleWithTheme:(OGTheme *)theme view:(UIView *)view;
+ (void)applyLegacyReflectionStyleWithTheme:(OGTheme *)theme imageView:(UIImageView *)imageView;
@end
