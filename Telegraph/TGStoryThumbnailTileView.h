#import <UIKit/UIKit.h>

@class TGStoryItem;
@class TGPresentation;

extern const CGSize TGStoryThumbnailTileSize;

@interface TGStoryThumbnailTileView : UIControl

- (void)setStory:(TGStoryItem *)story;
- (void)setAddTileWithPresentation:(TGPresentation *)presentation;

@end
