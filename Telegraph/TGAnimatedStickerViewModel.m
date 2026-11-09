#import "TGAnimatedStickerViewModel.h"

#import "TGAnimatedStickerView.h"

@interface TGAnimatedStickerViewModel ()
{
    TGDocumentMediaAttachment *_document;
    NSString *_placeholderUri;
}

@end

@implementation TGAnimatedStickerViewModel

- (instancetype)initWithDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri
{
    self = [super init];
    if (self != nil)
    {
        _document = document;
        _placeholderUri = placeholderUri;
        _loops = true;
        _autoplay = true;
        self.viewStateIdentifier = [TGAnimatedStickerView viewStateIdentifierForAnimationKey:[TGAnimatedStickerView animationKeyForDocument:document]];
        self.skipDrawInContext = true;
        self.viewUserInteractionDisabled = true;
    }
    return self;
}

- (Class)viewClass
{
    return [TGAnimatedStickerView class];
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    [super bindViewToContainer:container viewStorage:viewStorage];
    TGAnimatedStickerView *view = (TGAnimatedStickerView *)[self boundView];
    view.playing = _autoplay;
    view.loops = _loops;
    __weak TGAnimatedStickerViewModel *weakSelf = self;
    view.readyBlock = ^
    {
        __strong TGAnimatedStickerViewModel *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_readyBlock != nil)
            strongSelf->_readyBlock();
    };
    [view setDocument:_document placeholderUri:_placeholderUri];
    if (view.contentReady && _readyBlock != nil)
        _readyBlock();
}

- (void)setDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri
{
    _document = document;
    _placeholderUri = placeholderUri;
    self.viewStateIdentifier = [TGAnimatedStickerView viewStateIdentifierForAnimationKey:[TGAnimatedStickerView animationKeyForDocument:document]];
    [(TGAnimatedStickerView *)[self boundView] setDocument:document placeholderUri:placeholderUri];
}

- (bool)playing
{
    return ((TGAnimatedStickerView *)[self boundView]).playing;
}

- (void)restart
{
    [(TGAnimatedStickerView *)[self boundView] restart];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    TGAnimatedStickerView *view = (TGAnimatedStickerView *)[self boundView];
    view.readyBlock = nil;
    [super unbindView:viewStorage];
}

@end
