#import "TGCollectionMenuController.h"

@class TGDocumentMediaAttachment;

@interface TGStickerCreationController : TGCollectionMenuController

@property (nonatomic, copy) void (^sendSticker)(TGDocumentMediaAttachment *document);

- (instancetype)initWithImage:(UIImage *)image;

+ (void)presentFromController:(UIViewController *)parentController sourceView:(UIView *)sourceView sendSticker:(void (^)(TGDocumentMediaAttachment *document))sendSticker;

@end
