#import "TGCollectionItemView.h"

@class TGWallpaperInfo;
@class TGPresentation;

@interface TGAppearancePreviewCollectionItemView : TGCollectionItemView

@property (nonatomic, readonly) CGFloat contentHeight;

@property (nonatomic, assign) int32_t fontSize;
@property (nonatomic, strong) NSArray *messages;
@property (nonatomic, strong) TGPresentation *messagePresentation;
@property (nonatomic) CGFloat stickerScale;
@property (nonatomic, copy) void (^contentHeightChanged)(void);

- (void)updateWallpaper;
- (void)refreshMetrics;
- (void)reset;

@end
