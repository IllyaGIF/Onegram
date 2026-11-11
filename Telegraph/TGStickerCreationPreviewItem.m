#import "TGStickerCreationPreviewItem.h"

#import "TGStickerCreationPreviewItemView.h"

static const CGFloat TGStickerCreationPreviewHeight = 236.0f;

@implementation TGStickerCreationPreviewItem

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        self.transparent = true;
        self.highlightable = false;
        self.selectable = false;
    }
    return self;
}

- (Class)itemViewClass
{
    return [TGStickerCreationPreviewItemView class];
}

- (CGSize)itemSizeForContainerSize:(CGSize)containerSize
{
    return CGSizeMake(containerSize.width, TGStickerCreationPreviewHeight);
}

- (void)bindView:(TGStickerCreationPreviewItemView *)view
{
    [super bindView:view];
    [view setImage:_image];
    [view setProcessing:_processing];
}

- (void)setImage:(UIImage *)image
{
    _image = image;
    [(TGStickerCreationPreviewItemView *)self.boundView setImage:image];
}

- (void)setProcessing:(bool)processing
{
    _processing = processing;
    [(TGStickerCreationPreviewItemView *)self.boundView setProcessing:processing];
}

@end
