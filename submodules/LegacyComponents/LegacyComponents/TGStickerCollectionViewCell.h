#import <UIKit/UIKit.h>

@class TGDocumentMediaAttachment;

@interface TGStickerCollectionViewCell : PSUICollectionViewCell

@property (nonatomic, strong) TGDocumentMediaAttachment *documentMedia;

- (void)setDisabledTimeout;
- (bool)isEnabled;
- (void)setHighlightedWithBounce:(bool)highlighted;

@end
