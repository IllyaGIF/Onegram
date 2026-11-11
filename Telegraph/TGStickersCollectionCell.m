#import "TGStickersCollectionCell.h"


#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"
#import "TGAnimatedStickerView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGStickerAssociation.h"

NSString *const TGStickersCollectionCellIdentifier = @"TGStickersCollectionCell";

@interface TGStickersCollectionCell ()
{
    UIView *_wrapperView;
    TGImageView *_imageView;
    TGAnimatedStickerView *_animatedView;
    UILabel *_altLabel;
    bool _usesEmojiFallback;
    
    NSString *_uri;
    
    TGDocumentMediaAttachment *_sticker;
    NSArray *_associations;
    bool _highlighted;
    NSInteger _altTick;
}
@end

NSString *OGCompatStickerPreviewUri(TGDocumentMediaAttachment *documentMedia)
{
    NSMutableArray *query = [[NSMutableArray alloc] init];
    if (documentMedia.documentId != 0)
    {
        [query addObject:[[NSString alloc] initWithFormat:@"documentId=%" PRId64 "", documentMedia.documentId]];
        
        TGMediaOriginInfo *originInfo = documentMedia.originInfo ?: [TGMediaOriginInfo mediaOriginInfoForDocumentAttachment:documentMedia];
        if (originInfo != nil)
            [query addObject:[@"origin_info=" stringByAppendingString:[originInfo stringRepresentation]]];
    }
    else
        [query addObject:[[NSString alloc] initWithFormat:@"localDocumentId=%" PRId64 "", documentMedia.localDocumentId]];
    [query addObject:[[NSString alloc] initWithFormat:@"accessHash=%" PRId64 "", documentMedia.accessHash]];
    [query addObject:[[NSString alloc] initWithFormat:@"datacenterId=%" PRId32 "", (int32_t)documentMedia.datacenterId]];
    
    NSString *thumbnailLocation = [documentMedia.thumbnailInfo imageUrlForLargestSize:NULL];
    if (thumbnailLocation != nil)
        [query addObject:[@"legacyThumbnailUri=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:thumbnailLocation]]];
    [query addObject:[@"fileName=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:[documentMedia safeFileName]]]];
    [query addObject:[[NSString alloc] initWithFormat:@"size=%d", documentMedia.size]];
    NSString *documentMimeType = documentMedia.mimeType;
    if (documentMimeType.length != 0)
        [query addObject:[@"mimeType=" stringByAppendingString:[TGStringUtils stringByEscapingForURL:documentMimeType]]];
    [query addObject:@"width=132&height=132"];
    [query addObject:@"highQuality=1"];
    return [@"sticker-preview://?" stringByAppendingString:[query componentsJoinedByString:@"&"]];
}

@implementation TGStickersCollectionCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = true;
        self.backgroundColor = [UIColor whiteColor];
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.backgroundColor = [UIColor whiteColor];
        [self addSubview:_wrapperView];
        
        _imageView = [[TGImageView alloc] init];
        _imageView.backgroundColor = [UIColor whiteColor];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.opaque = true;
        [_wrapperView addSubview:_imageView];
        
        _altLabel = [[UILabel alloc] init];
        _altLabel.font = [UIFont systemFontOfSize:32.0f];
        _altLabel.textAlignment = NSTextAlignmentCenter;
        _altLabel.textColor = [UIColor blackColor];
        _altLabel.backgroundColor = [UIColor clearColor];
        [_wrapperView addSubview:_altLabel];
        
        OGCompatLayerSetRasterizationScale(_wrapperView.layer, TGScreenScaling());
    }
    return self;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    _wrapperView.backgroundColor = backgroundColor;
    _imageView.backgroundColor = backgroundColor;
}

- (TGDocumentMediaAttachment *)sticker
{
    return _sticker;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    _sticker = nil;
    _uri = nil;
    [_animatedView reset];
    [_imageView reset];
}

- (void)setSticker:(TGDocumentMediaAttachment *)documentMedia associations:(NSArray *)associations mask:(bool)mask
{
    _sticker = documentMedia;
    
    NSString *uri = OGCompatStickerPreviewUri(documentMedia);
    
    NSString *alt = @"";
    for (id attribute in documentMedia.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
        {
            alt = ((TGDocumentAttributeSticker *)attribute).alt;
            break;
        }
    }
    
    NSMutableArray *stickerAssociations = [[NSMutableArray alloc] init];
    for (TGStickerAssociation *association in associations)
    {
        for (NSNumber *nDocumentId in association.documentIds)
        {
            if ((int64_t)[nDocumentId longLongValue] == documentMedia.documentId)
            {
                
                if (alt.length == 0)
                {
                    alt = association.key;
                    break;
                }
            }
        }
    }
    _associations = stickerAssociations;
    
    NSString *currentAlt = alt;
    if (currentAlt.length > 0 && [currentAlt characterAtIndex:0] == 0x2639)
        currentAlt = @"\u2639\ufe0f";
    
    bool animated = !mask && [TGAnimatedStickerView isAnimatedStickerDocument:documentMedia];
    _usesEmojiFallback = !mask && !animated && currentAlt.length != 0 && [documentMedia.mimeType isEqualToString:@"video/webm"];
    _imageView.hidden = _usesEmojiFallback || animated;
    _altLabel.hidden = !_usesEmojiFallback;
    if (animated)
    {
        if (_animatedView == nil)
        {
            _animatedView = [[TGAnimatedStickerView alloc] initWithFrame:self.bounds];
            _animatedView.playing = false;
            [_wrapperView insertSubview:_animatedView aboveSubview:_imageView];
        }
        _animatedView.hidden = false;
        [_animatedView setDocument:documentMedia placeholderUri:uri];
    }
    else if (_animatedView != nil)
    {
        _animatedView.hidden = true;
        [_animatedView reset];
    }
    if (_usesEmojiFallback || animated)
    {
        [_imageView reset];
        _uri = nil;
    }
    else if (![uri isEqualToString:_uri])
    {
        _uri = uri;
        [_imageView loadUri:uri withOptions:@{}];
    }
    _altLabel.text = !mask ? currentAlt : @"";
    _altLabel.transform = CGAffineTransformIdentity;
    [_altLabel sizeToFit];
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

- (void)performTransitionIn
{
    OGCompatLayerSetShouldRasterize(_wrapperView.layer, false);
    
    CGRect targetAltFrame = _altLabel.frame;
    _altLabel.frame = CGRectOffset(_altLabel.frame, 0, 20);
    
    [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 animations:^
    {
        _altLabel.frame = targetAltFrame;
    } completion:^(__unused BOOL finished)
    {
        OGCompatLayerSetShouldRasterize(_wrapperView.layer, true);
    }];
}

- (void)setAltTick:(NSInteger)tick
{
    _altTick = tick;
    
    if (_associations.count == 0)
        return;
    
    NSInteger altIndex = _altTick % _associations.count;
    NSString *currentAlt = _associations[altIndex];
    if ([currentAlt isEqualToString:_altLabel.text])
        return;
    
    _altLabel.text = currentAlt;
    [_altLabel sizeToFit];
    _altLabel.frame = CGRectMake(self.bounds.size.width - _altLabel.frame.size.width, self.bounds.size.height - _altLabel.frame.size.height + 4.0f, _altLabel.frame.size.width, _altLabel.frame.size.height);
    
    _altLabel.transform = CGAffineTransformMakeScale(0.7f, 0.7f);
    [UIView animateWithDuration:0.36 delay:0.0 usingSpringWithDamping:0.72f initialSpringVelocity:0.0f options:0 animations:^
    {
        _altLabel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)layoutSubviews
{
    _wrapperView.frame = self.bounds;
    _imageView.frame = self.bounds;
    if (_animatedView != nil && CGAffineTransformIsIdentity(_animatedView.transform))
        _animatedView.frame = self.bounds;
    CGSize altSize = _altLabel.frame.size;
    _altLabel.frame = _usesEmojiFallback ? self.bounds : CGRectMake(self.bounds.size.width - altSize.width, self.bounds.size.height - altSize.height + 4.0f, altSize.width, altSize.height);
}

@end
