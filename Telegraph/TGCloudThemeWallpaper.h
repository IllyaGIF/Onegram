#import <UIKit/UIKit.h>
#import "../submodules/LegacyComponents/LegacyComponents/TGWallpaperInfo.h"

FOUNDATION_EXPORT UIImage *TGCloudThemeWallpaperImage(NSArray *colors, int32_t rotation, NSData *patternData, int32_t intensity, CGSize size);

@interface TGGradientWallpaperInfo : TGWallpaperInfo

- (instancetype)initWithWallpaperId:(int64_t)wallpaperId colors:(NSArray *)colors rotation:(int32_t)rotation;

@end
