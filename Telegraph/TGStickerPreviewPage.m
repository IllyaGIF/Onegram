#import "TGStickerPreviewPage.h"

#import "../submodules/LegacyComponents/LegacyComponents/LegacyComponents.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGImageView.h"

#import "../submodules/LegacyComponents/LegacyComponents/TGStickerAssociation.h"
#import "TGAnimatedStickerView.h"

@interface TGStickerPreviewPageImageView : TGImageView
{
    TGAnimatedStickerView *_animatedView;
}

- (void)setAnimatedDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri;

@end

extern NSString *OGCompatStickerPreviewUri(TGDocumentMediaAttachment *documentMedia);

@implementation TGStickerPreviewPageImageView

- (void)setAnimatedDocument:(TGDocumentMediaAttachment *)document placeholderUri:(NSString *)placeholderUri
{
    [super reset];
    if (_animatedView == nil)
    {
        _animatedView = [[TGAnimatedStickerView alloc] initWithFrame:self.bounds];
        _animatedView.playing = false;
        [self addSubview:_animatedView];
    }
    _animatedView.hidden = false;
    [_animatedView setDocument:document placeholderUri:placeholderUri];
}

- (void)reset
{
    [super reset];
    [_animatedView reset];
    _animatedView.hidden = true;
}

- (void)loadUri:(NSString *)uri withOptions:(NSDictionary *)options
{
    [_animatedView reset];
    _animatedView.hidden = true;
    [super loadUri:uri withOptions:options];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _animatedView.frame = self.bounds;
}

@end

@interface TGStickerPreviewPage ()
{
    NSArray *_imageViews;
    NSArray *_altLabels;
    NSArray *_documents;
}

@end

@implementation TGStickerPreviewPage

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        NSMutableArray *imageViews = [[NSMutableArray alloc] init];
        NSMutableArray *altLabels = [[NSMutableArray alloc] init];
        for (int i = 0; i < 9; i++)
        {
            TGStickerPreviewPageImageView *imageView = [[TGStickerPreviewPageImageView alloc] init];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            imageView.hidden = true;
            [imageViews addObject:imageView];
            [self addSubview:imageView];
            
            UILabel *altLabel = [[UILabel alloc] init];
            altLabel.backgroundColor = [UIColor clearColor];
            altLabel.textColor = [UIColor blackColor];
            altLabel.font = [UIFont systemFontOfSize:20.0f];
            altLabel.hidden = true;
            [altLabels addObject:altLabel];
            [self addSubview:altLabel];
        }
        _imageViews = imageViews;
        _altLabels = altLabels;
    }
    return self;
}

- (void)prepareForReuse
{
    for (TGStickerPreviewPageImageView *imageView in _imageViews)
    {
        imageView.hidden = true;
        [imageView reset];
    }
    
    for (UILabel *altLabel in _altLabels)
    {
        altLabel.hidden = true;
    }
}

- (void)setDocuments:(NSArray *)documents stickerAssociations:(NSArray *)stickerAssociations
{
    _documents = documents;
    
    for (NSUInteger i = 0; i < documents.count && i < _imageViews.count; i++)
    {
        TGStickerPreviewPageImageView *imageView = _imageViews[i];
        imageView.hidden = false;

        TGDocumentMediaAttachment *documentMedia = documents[i];
        NSString *uri = OGCompatStickerPreviewUri(documentMedia);
        if ([TGAnimatedStickerView isAnimatedStickerDocument:documentMedia])
            [imageView setAnimatedDocument:documentMedia placeholderUri:uri];
        else
            [imageView loadUri:uri withOptions:@{}];
        
        NSString *alt = @"";
        for (id attribute in documentMedia.attributes)
        {
            if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
            {
                alt = ((TGDocumentAttributeSticker *)attribute).alt;
                break;
            }
        }
        
        if (alt.length == 0)
        {
            for (TGStickerAssociation *association in stickerAssociations)
            {
                for (NSNumber *nDocumentId in association.documentIds)
                {
                    if ((int64_t)[nDocumentId longLongValue] == documentMedia.documentId)
                    {
                        alt = association.key;
                        break;
                    }
                }
            }
        }
        
        UILabel *altLabel = _altLabels[i];
        altLabel.hidden = false;
        altLabel.text = alt;
        [altLabel sizeToFit];
    }
    
    for (NSUInteger i = documents.count; i < _imageViews.count; i++)
    {
        TGStickerPreviewPageImageView *imageView = _imageViews[i];
        imageView.hidden = true;
        [imageView reset];
        
        UILabel *altLabel = _altLabels[i];
        altLabel.hidden = true;
    }
    
    [self setNeedsLayout];
}

- (TGDocumentMediaAttachment *)documentAtPoint:(CGPoint)point {
    NSInteger index = -1;
    for (TGStickerPreviewPageImageView *imageView in _imageViews) {
        index++;
        if (CGRectContainsPoint(imageView.frame, point)) {
            if (index < (NSInteger)_documents.count) {
                return _documents[index];
            }
        }
    }
    return nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize imageSize = CGSizeMake(66.0f, 66.0f);
    CGFloat horizontalSpacing = 20.0f;
    CGFloat verticalSpacing = 8.0f;
    
    NSInteger index = -1;
    for (TGStickerPreviewPageImageView *imageView in _imageViews)
    {
        index++;
        
        imageView.frame = CGRectMake((index % 3) * (imageSize.width + horizontalSpacing), (index / 3) * (imageSize.height + verticalSpacing), imageSize.width, imageSize.height);
        
        UILabel *altLabel = _altLabels[index];
        altLabel.frame = CGRectMake(imageView.frame.origin.x + imageView.frame.size.width - altLabel.frame.size.width, imageView.frame.origin.y + imageView.frame.size.height - altLabel.frame.size.height, altLabel.frame.size.width, altLabel.frame.size.height);
    }
}

@end
