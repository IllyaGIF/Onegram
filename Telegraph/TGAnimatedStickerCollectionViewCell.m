#import "TGAnimatedStickerCollectionViewCell.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"
#import "../submodules/LegacyComponents/LegacyComponents/TGDocumentMediaAttachment.h"

#import "TGAnimatedStickerView.h"

@interface TGAnimatedStickerCollectionViewCell ()
{
    TGAnimatedStickerView *_animatedView;
}

@end

@implementation TGAnimatedStickerCollectionViewCell

- (void)prepareForReuse
{
    [super prepareForReuse];
    _animatedSticker = false;
    _animationAllowed = false;
    [self stopAnimation];
}

- (void)setDocumentMedia:(TGDocumentMediaAttachment *)documentMedia
{
    TGDocumentMediaAttachment *previous = self.documentMedia;
    bool sameDocument = previous != nil && documentMedia != nil && previous.documentId == documentMedia.documentId && previous.localDocumentId == documentMedia.localDocumentId;
    [super setDocumentMedia:documentMedia];
    _animatedSticker = documentMedia != nil && [TGAnimatedStickerView isAnimatedStickerDocument:documentMedia];
    if (!sameDocument)
        [self stopAnimation];
    if (_animationAllowed)
        [self startAnimation];
}

- (void)setAnimationAllowed:(bool)animationAllowed
{
    if (_animationAllowed == animationAllowed)
        return;
    _animationAllowed = animationAllowed;
    if (animationAllowed)
        [self startAnimation];
    else
        [self stopAnimation];
}

- (void)startAnimation
{
    TGDocumentMediaAttachment *document = self.documentMedia;
    if (!_animatedSticker || document == nil)
        return;
    if (_animatedView == nil)
    {
        _animatedView = [[TGAnimatedStickerView alloc] initWithFrame:self.stickerView.bounds];
        _animatedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        __weak TGAnimatedStickerCollectionViewCell *weakSelf = self;
        _animatedView.readyBlock = ^
        {
            __strong TGAnimatedStickerCollectionViewCell *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_animationAllowed)
                strongSelf.thumbnailView.hidden = true;
        };
        [self.stickerView addSubview:_animatedView];
    }
    _animatedView.hidden = false;
    [_animatedView setDocument:document placeholderUri:nil];
    _animatedView.playing = true;
    if (_animatedView.contentReady)
        self.thumbnailView.hidden = true;
}

- (void)stopAnimation
{
    self.thumbnailView.hidden = false;
    if (_animatedView == nil)
        return;
    _animatedView.hidden = true;
    [_animatedView reset];
}

@end
