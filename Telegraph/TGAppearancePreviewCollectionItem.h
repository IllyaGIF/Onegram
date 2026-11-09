#import "TGCollectionItem.h"

@class TGWallpaperInfo;
@class TGPresentation;

@interface TGAppearancePreviewCollectionItem : TGCollectionItem

@property (nonatomic, assign) int32_t fontSize;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) TGPresentation *messagePresentation;
@property (nonatomic) CGFloat stickerScale;
@property (nonatomic, copy) void (^heightChanged)();

- (void)updateWallpaper;
- (void)refreshMetrics;
- (void)reset;

@end
