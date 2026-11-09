#import "TGModernViewModel.h"

@class TGDocumentMediaAttachment;

@interface TGAnimatedStickerViewModel : TGModernViewModel

@property (nonatomic, copy) void (^readyBlock)(void);
@property (nonatomic) bool loops;
@property (nonatomic) bool autoplay;
@property (nonatomic, readonly) bool playing;

- (instancetype)initWithDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri;
- (void)setDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri;
- (void)restart;

@end
