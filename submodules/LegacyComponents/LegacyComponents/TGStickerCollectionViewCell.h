#import <UIKit/UIKit.h>

@class TGDocumentMediaAttachment;

@interface TGStickerCollectionViewCell : PSUICollectionViewCell

@property (nonatomic, strong) TGDocumentMediaAttachment *documentMedia;
@property (nonatomic, readonly) UIView *stickerView;
@property (nonatomic, readonly) UIImageView *thumbnailView;

- (void)setDisabledTimeout;
- (bool)isEnabled;
- (void)setHighlightedWithBounce:(bool)highlighted;

@end
