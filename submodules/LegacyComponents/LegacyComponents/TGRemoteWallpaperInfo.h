#import "TGWallpaperInfo.h"

@interface TGRemoteWallpaperInfo : TGWallpaperInfo

- (instancetype)initWithRemoteId:(int64_t)remoteId thumbnailUri:(NSString *)thumbnailUri fullscreenUri:(NSString *)fullscreenUri tintColor:(int)tintColor;

@end
