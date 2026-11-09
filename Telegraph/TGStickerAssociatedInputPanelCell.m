#import "TGStickerAssociatedInputPanelCell.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "TGAnimatedStickerView.h"

@interface TGStickerAssociatedInputPanelCell ()
{
    TGImageView *_imageView;
    TGAnimatedStickerView *_animatedView;
    NSString *_previousUri;
    
    bool _highlighted;
}

@end

@implementation TGStickerAssociatedInputPanelCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _imageView = [[TGImageView alloc] initWithFrame:CGRectMake(3.0f - TGRetinaPixel, 3.0f, 64.0f, 64.0f)];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_imageView];
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    _previousUri = nil;
    [_imageView reset];
    [_animatedView reset];
}

- (void)setDocument:(TGDocumentMediaAttachment *)document
{
    _document = document;
    
    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
    if (document.documentId != 0)
    {
        [uri appendFormat:@"documentId=%" PRId64 "", document.documentId];
        
        TGMediaOriginInfo *originInfo = document.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:document];
        if (originInfo != nil)
            [uri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
    }
    else
    {
        [uri appendFormat:@"localDocumentId=%" PRId64 "", document.localDocumentId];
    }
    [uri appendFormat:@"&accessHash=%" PRId64 "", document.accessHash];
    [uri appendFormat:@"&datacenterId=%" PRId32 "", (int32_t)document.datacenterId];
    
    NSString *legacyThumbnailUri = [document.thumbnailInfo imageUrlForLargestSize:NULL];
    if (legacyThumbnailUri != nil)
        [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailUri]];
    [uri appendFormat:@"&fileName=%@", [TGStringUtils stringByEscapingForURL:[document safeFileName]]];
    [uri appendFormat:@"&size=%d", document.size];
    if (document.mimeType.length != 0)
        [uri appendFormat:@"&mimeType=%@", [TGStringUtils stringByEscapingForURL:document.mimeType]];
    
    [uri appendFormat:@"&width=128&height=128"];
    [uri appendFormat:@"&highQuality=1"];
    
    if ([_previousUri isEqualToString:uri])
        return;
    
    _previousUri = uri;
    if ([TGAnimatedStickerView isAnimatedStickerDocument:document])
    {
        [_imageView reset];
        _imageView.hidden = true;
        if (_animatedView == nil)
        {
            _animatedView = [[TGAnimatedStickerView alloc] initWithFrame:_imageView.frame];
            _animatedView.playing = false;
            [self.contentView addSubview:_animatedView];
        }
        _animatedView.hidden = false;
        [_animatedView setDocument:document placeholderUri:uri];
    }
    else
    {
        [_animatedView reset];
        _animatedView.hidden = true;
        _imageView.hidden = false;
        [_imageView loadUri:uri withOptions:nil];
    }
}

- (void)setHighlighted:(bool)highlighted animated:(bool)__unused animated
{
    if (_highlighted != highlighted)
    {
        _highlighted = highlighted;
        
        if (iosMajorVersion() >= 8)
        {
            [UIView animateWithDuration:0.6 delay:0.0 usingSpringWithDamping:0.6f initialSpringVelocity:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                CGAffineTransform transform = _highlighted ? CGAffineTransformMakeScale(0.8f, 0.8f) : CGAffineTransformIdentity;
                _imageView.transform = transform;
                _animatedView.transform = transform;
            } completion:nil];
        }
    }
}

@end
