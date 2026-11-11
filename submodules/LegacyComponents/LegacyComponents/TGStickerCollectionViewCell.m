#import "TGStickerCollectionViewCell.h"

#import "LegacyComponentsInternal.h"
#import "TGDocumentMediaAttachment.h"
#import "TGImageUtils.h"
#import "TGStringUtils.h"

#import "TGImageView.h"
#import <QuartzCore/QuartzCore.h>

@interface TGStickerCollectionViewCell ()
{
    UIView *_stickerView;
    TGImageView *_imageView;
    CFAbsoluteTime _disableTime;
    bool _highlighted;
}

@end

@implementation TGStickerCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _stickerView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 62.0f, 62.0f)];
        [self.contentView addSubview:_stickerView];
        
        _imageView = [[TGImageView alloc] initWithFrame:_stickerView.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_stickerView addSubview:_imageView];
        
        if (iosMajorVersion() >= 11)
            _imageView.accessibilityIgnoresInvertColors = true;
    }
    return self;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    [_imageView reset];
    
    [_stickerView.layer removeAllAnimations];
    _stickerView.alpha = 1.0f;
    _highlighted = false;
    _stickerView.transform = CGAffineTransformIdentity;
}

- (UIView *)stickerView
{
    return _stickerView;
}

- (UIImageView *)thumbnailView
{
    return _imageView;
}

- (void)setDocumentMedia:(TGDocumentMediaAttachment *)documentMedia
{
    _documentMedia = documentMedia;
    if (documentMedia == nil)
    {
        [_imageView reset];
        return;
    }

    NSMutableString *uri = [[NSMutableString alloc] initWithString:@"sticker-preview://?"];
    if (documentMedia.documentId != 0)
    {
        [uri appendFormat:@"documentId=%" PRId64 "", documentMedia.documentId];
        
        TGMediaOriginInfo *originInfo = documentMedia.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:documentMedia];
        if (originInfo != nil)
            [uri appendFormat:@"&origin_info=%@", [originInfo stringRepresentation]];
    }
    else
        [uri appendFormat:@"localDocumentId=%" PRId64 "", documentMedia.localDocumentId];
    [uri appendFormat:@"&accessHash=%" PRId64 "", documentMedia.accessHash];
    [uri appendFormat:@"&datacenterId=%" PRId32 "", (int32_t)documentMedia.datacenterId];
    
    NSString *legacyThumbnailUri = [documentMedia.thumbnailInfo imageUrlForLargestSize:NULL];
    if (legacyThumbnailUri != nil)
        [uri appendFormat:@"&legacyThumbnailUri=%@", [TGStringUtils stringByEscapingForURL:legacyThumbnailUri]];
    NSString *mimeComponent = documentMedia.mimeType.length != 0 ? [NSString stringWithFormat:@"&mimeType=%@", [TGStringUtils stringByEscapingForURL:documentMedia.mimeType]] : @"";
    [uri appendFormat:@"&fileName=%@&size=%d%@", [TGStringUtils stringByEscapingForURL:[documentMedia safeFileName]], documentMedia.size, mimeComponent];
    
    [uri appendFormat:@"&width=124&height=124"];
    [uri appendFormat:@"&dimwidth=%d&dimheight=%d", (int)[documentMedia pictureSize].width, (int)[documentMedia pictureSize].height];
    [uri appendFormat:@"&highQuality=1"];
    
    [_imageView loadUri:uri withOptions:nil];
}

- (void)setDisabledTimeout
{
    [UIView animateWithDuration:0.1 animations:^{
        _stickerView.alpha = 0.3f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            [UIView animateWithDuration:1.0 animations:^{
                _stickerView.alpha = 1.0f;
            }];
        }
    }];
    _disableTime = CFAbsoluteTimeGetCurrent();
}

- (bool)isEnabled
{
    return CFAbsoluteTimeGetCurrent() > _disableTime + 1.1;
}

- (void)setHighlightedWithBounce:(bool)highlighted
{
    if (_highlighted != highlighted)
    {
        _highlighted = highlighted;
        
        if (iosMajorVersion() >= 8)
        {
            [UIView animateWithDuration:0.6 delay:0.0 usingSpringWithDamping:0.43f initialSpringVelocity:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                if (_highlighted)
                    _stickerView.transform = CGAffineTransformMakeScale(0.8f, 0.8f);
                else
                    _stickerView.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
}

@end
